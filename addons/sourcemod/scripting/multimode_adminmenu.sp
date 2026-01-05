/*****************************************************************************
                        MultiMode Admin Menu
******************************************************************************/

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <morecolors>
#include <adminmenu>
#include <clientprefs>
#include <sdktools>
#include <multimode>
#include <multimode/base>
#include <multimode/utils>

// Gesture Defines
#define GESTURE_NOMINATED " (!)" // For nominated global gesture groups/maps
#define GESTURE_CURRENT " (*)"   // For Current global gesture group/map
#define GESTURE_VOTED " (#)"     // For Winning group/map global gesture from a previous vote

// Global Variables
// g_hCookieVoteType removed - no longer needed, all votes from admin menu are admin votes
char g_sClientPendingGameMode[MAXPLAYERS+1][64];
char g_sClientPendingMap[MAXPLAYERS+1][PLATFORM_MAX_PATH];
char g_sClientPendingSubGroup[MAXPLAYERS+1][64];
TimingMode g_eVoteTiming;

TopMenu g_topmenu;
KeyValues g_kvMapcycle;

// Vote Configuration ConVars
ConVar g_Cvar_VoteAdminTime;
ConVar g_Cvar_VoteAdminSorted;
ConVar g_Cvar_VoteAdminGroupExclude;
ConVar g_Cvar_VoteAdminMapExclude;
ConVar g_Cvar_VoteAdminSounds;
ConVar g_Cvar_VoteAdminOpenSound;
ConVar g_Cvar_VoteAdminCloseSound;
ConVar g_Cvar_VoteAdminRunoff;
ConVar g_Cvar_VoteAdminRunoffThreshold;
ConVar g_Cvar_VoteAdminRunoffVoteFailed;
ConVar g_Cvar_VoteAdminRunoffInVoteLimit;
ConVar g_Cvar_VoteAdminRunoffVoteLimit;
ConVar g_Cvar_VoteAdminRunoffVoteOpenSound;
ConVar g_Cvar_VoteAdminRunoffVoteCloseSound;
ConVar g_Cvar_VoteAdminExtendVote;
ConVar g_Cvar_VoteAdminExtendTimeStep;
ConVar g_Cvar_VoteAdminExtendFragStep;
ConVar g_Cvar_VoteAdminExtendRoundStep;
ConVar g_Cvar_VoteAdminMethod;

public Plugin myinfo = 
{
    name = "[MMC] MultiMode Admin Menu",
    author = "Oppressive Territory",
    description = "Administrative menu for MultiMode Core",
    version = PLUGIN_VERSION,
    url = ""
};

public void OnPluginStart()
{
    // Check if multimode_core is loaded by checking for a native
    if (GetFeatureStatus(FeatureType_Native, "MultiMode_GetCurrentGameMode") != FeatureStatus_Available)
    {
        SetFailState("multimode_core plugin is not loaded!");
    }
    
    LoadTranslations("multimode_voter.phrases");
    
    // Vote Configuration ConVars
    g_Cvar_VoteAdminTime = CreateConVar("multimode_voteadmin_time", "20", "Voting duration in seconds for admin votes.");
    g_Cvar_VoteAdminSorted = CreateConVar("multimode_voteadmin_sorted", "1", "Sorting mode for admin vote items: 0= Alphabetical, 1= Random, 2= Map Cycle Order", _, true, 0.0, true, 2.0);
    g_Cvar_VoteAdminGroupExclude = CreateConVar("multimode_voteadmin_groupexclude", "0", "Number of recently played gamemodes to exclude from admin votes (0= Disabled)");
    g_Cvar_VoteAdminMapExclude = CreateConVar("multimode_voteadmin_mapexclude", "2", "Number of recently played maps to exclude from admin votes (0= Disabled)");
    g_Cvar_VoteAdminSounds = CreateConVar("multimode_voteadmin_votesounds", "1", "Enables/disables voting and automatic download sounds for admin votes.", 0, true, 0.0, true, 1.0);
    g_Cvar_VoteAdminOpenSound = CreateConVar("multimode_voteadmin_voteopensound", "votemap/vtst.wav", "Sound played when starting an admin vote");
    g_Cvar_VoteAdminCloseSound = CreateConVar("multimode_voteadmin_voteclosesound", "votemap/vtend.wav", "Sound played when an admin vote ends");
    g_Cvar_VoteAdminRunoff = CreateConVar("multimode_voteadmin_runoff", "1", "Enable runoff system for admin votes, voting for ties or if no option reaches the threshold.", _, true, 0.0, true, 1.0);
    g_Cvar_VoteAdminRunoffThreshold = CreateConVar("multimode_voteadmin_runoff_threshold", "0.6", "Minimum percentage of votes an option needs to win directly in admin votes (0.0 to disable threshold check.).", _, true, 0.0, true, 1.0);
    g_Cvar_VoteAdminRunoffVoteFailed = CreateConVar("multimode_voteadmin_runoff_votefailed", "0", "What to do if an admin runoff vote also fails: 1= Do Nothing, 0= Pick the first option from the runoff.", _, true, 0.0, true, 1.0);
    g_Cvar_VoteAdminRunoffInVoteLimit = CreateConVar("multimode_voteadmin_runoff_invotelimit", "3", "Maximum number of items to include in an admin runoff vote.", _, true, 2.0);
    g_Cvar_VoteAdminRunoffVoteLimit = CreateConVar("multimode_voteadmin_runoff_votelimit", "3", "Maximum number of admin runoff votes allowed per map to prevent infinite loops.", _, true, 1.0);
    g_Cvar_VoteAdminRunoffVoteOpenSound = CreateConVar("multimode_voteadmin_runoff_voteopensound", "votemap/vtst.wav", "Sound played when starting an admin runoff vote.");
    g_Cvar_VoteAdminRunoffVoteCloseSound = CreateConVar("multimode_voteadmin_runoff_voteclosesound", "votemap/vtend.wav", "Sound played when an admin runoff vote ends.");
    g_Cvar_VoteAdminExtendVote = CreateConVar("multimode_voteadmin_extendvote", "1", "Shows the option to extend in admin votes");
    g_Cvar_VoteAdminExtendTimeStep = CreateConVar("multimode_voteadmin_extendtimestep", "6", "Amount of time to extend the time limit when \"Extend Map\" is selected in admin votes.");
    g_Cvar_VoteAdminExtendFragStep = CreateConVar("multimode_voteadmin_extendfragstep", "10", "Amount of frag limit to extend when \"Extend Map\" is selected in admin votes.");
    g_Cvar_VoteAdminExtendRoundStep = CreateConVar("multimode_voteadmin_extendroundstep", "3", "Amount of round limit to extend when \"Extend Map\" is selected in admin votes.");
    g_Cvar_VoteAdminMethod = CreateConVar("multimode_voteadmin_method", "1", "Vote method for admin votes: 1 = Groups then Maps, 2 = Groups only (random map), 3 = Maps only", _, true, 1.0, true, 3.0);
    
    AutoExecConfig(true, "multimode_adminmenu");
    
    LoadMapcycle();
    
    TopMenu topmenu;
    if (LibraryExists("adminmenu") && ((topmenu = GetAdminTopMenu()) != null))
    {
        OnAdminMenuReady(topmenu);
    }
}

public void OnConfigsExecuted()
{
    LoadMapcycle();
}

KeyValues GetMapcycle()
{
    if (g_kvMapcycle != null)
    {
        return g_kvMapcycle;
    }
    
    LoadMapcycle();
    return g_kvMapcycle;
}

void LoadMapcycle()
{
    delete g_kvMapcycle;
    g_kvMapcycle = new KeyValues("Mapcycle");
    
    ConVar cvar_filename = FindConVar("multimode_mapcycle");
    if (cvar_filename == null)
    {
        LogError("[AdminMenu] multimode_mapcycle convar not found!");
        return;
    }
    
    char filename[PLATFORM_MAX_PATH];
    cvar_filename.GetString(filename, sizeof(filename));
    
    char configPath[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, configPath, sizeof(configPath), "configs/%s", filename);

    if (!g_kvMapcycle.ImportFromFile(configPath))
    {
        LogError("[AdminMenu] Mapcycle failed to load: %s", configPath);
        delete g_kvMapcycle;
        g_kvMapcycle = null;
        return;
    }
    
    g_kvMapcycle.Rewind();
}

public void OnLibraryAdded(const char[] name)
{
    if (StrEqual(name, "adminmenu"))
    {
        TopMenu topmenu = GetAdminTopMenu();
        if (topmenu != null)
        {
            OnAdminMenuReady(topmenu);
        }
    }
}

public void OnAdminMenuReady(Handle aTopMenu)
{
    TopMenu topmenu = TopMenu.FromHandle(aTopMenu);
    g_topmenu = topmenu;

    TopMenuObject category = topmenu.FindCategory("Multimode Core Administration");
    
    if (category == INVALID_TOPMENUOBJECT)
    {
        category = topmenu.AddCategory("Multimode Core Administration", CategoryHandler);
    }

    topmenu.AddItem("sm_forcemode", AdminMenu_ForceMode, category, "sm_forcemode", ADMFLAG_CHANGEMAP);
    topmenu.AddItem("sm_votemode", AdminMenu_StartVote, category, "sm_votemode", ADMFLAG_VOTE);
    topmenu.AddItem("sm_extendmap", AdminMenu_ExtendMap, category, "sm_extendmap", ADMFLAG_CHANGEMAP);
}

public void CategoryHandler(TopMenu topmenu, TopMenuAction action, TopMenuObject object_id, int param, char[] buffer, int maxlength)
{
    if (action == TopMenuAction_DisplayTitle)
    {
        Format(buffer, maxlength, "Multimode Core Administration");
    }
    else if (action == TopMenuAction_DisplayOption)
    {
        Format(buffer, maxlength, "Multimode Core Administration");
    }
}

public void AdminMenu_ForceMode(TopMenu topmenu, TopMenuAction action, TopMenuObject object_id, int client, char[] buffer, int maxlength)
{
    if (action == TopMenuAction_DisplayOption)
    {
        Format(buffer, maxlength, "%T", "Force Gamemode", client);
    }
    else if (action == TopMenuAction_SelectOption)
    {
        ShowGameModeMenu(client, true);
    }
}

public void AdminMenu_StartVote(TopMenu topmenu, TopMenuAction action, TopMenuObject object_id, int client, char[] buffer, int maxlength)
{
    if (action == TopMenuAction_DisplayOption)
    {
        Format(buffer, maxlength, "%T", "Start Vote", client);
    }
    else if (action == TopMenuAction_SelectOption)
    {
        ShowVoteTypeSelectionMenu(client);
    }
}

public void AdminMenu_ExtendMap(TopMenu topmenu, TopMenuAction action, TopMenuObject object_id, int client, char[] buffer, int maxlength)
{
    if (action == TopMenuAction_DisplayOption)
    {
        Format(buffer, maxlength, "%T", "Extend Current Map", client);
    }
    else if (action == TopMenuAction_SelectOption)
    {
        ShowExtendTimeMenu(client);
    }
}

void ShowVoteTypeSelectionMenu(int client)
{
    char buffer[125];
    
    Menu menu = new Menu(VoteTypeSelectionMenuHandler);
    FormatEx(buffer, sizeof(buffer), "%t", "Vote Type Selection Title");
    menu.SetTitle(buffer);
    
    FormatEx(buffer, sizeof(buffer), "%t", "Vote Type Normal");
    menu.AddItem("normal", buffer);
    
    FormatEx(buffer, sizeof(buffer), "%t", "Vote Type Separated");
    menu.AddItem("separated", buffer);
    
    menu.ExitBackButton = true;
    menu.Display(client, MENU_TIME_FOREVER);
}

public int VoteTypeSelectionMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
    if (action == MenuAction_Select)
    {
        char type[16];
        menu.GetItem(param2, type, sizeof(type));
        
        if (StrEqual(type, "normal"))
        {
            ShowTimingSelectionMenu(param1);
        }
        else if (StrEqual(type, "separated"))
        {
            StartSeparatedVote(param1);
        }
    }
    else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack)
    {
        if (g_topmenu != null)
        {
            g_topmenu.DisplayCategory(g_topmenu.FindCategory("Multimode Core Administration"), param1);
        }
    }
    else if (action == MenuAction_End)
    {
        delete menu;
    }
    return 0;
}

void ShowTimingSelectionMenu(int client)
{
    char buffer[125];
    
    Menu menu = new Menu(TimingSelectionMenuHandler);
    FormatEx(buffer, sizeof(buffer), "%t", "Timing Title");
    menu.SetTitle(buffer);
    
    FormatEx(buffer, sizeof(buffer), "%t", "Timing NextMap");
    menu.AddItem("nextmap", buffer);

    FormatEx(buffer, sizeof(buffer), "%t", "Timing NextRound");
    menu.AddItem("nextround", buffer);

    FormatEx(buffer, sizeof(buffer), "%t", "Timing Instant");
    menu.AddItem("instant", buffer);
    
    menu.ExitBackButton = true;
    menu.Display(client, MENU_TIME_FOREVER);
}

public int TimingSelectionMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
    if (action == MenuAction_Select)
    {
        char timingStr[16];
        menu.GetItem(param2, timingStr, sizeof(timingStr));
        
        TimingMode timing = TIMING_NEXTMAP;
        if (StrEqual(timingStr, "nextround"))
            timing = TIMING_NEXTROUND;
        else if (StrEqual(timingStr, "instant"))
            timing = TIMING_INSTANT;
        
        g_eVoteTiming = timing;
        
        StartNormalVote(param1);
    }
    else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack)
    {
        ShowVoteTypeSelectionMenu(param1);
    }
    else if (action == MenuAction_End)
    {
        delete menu;
    }
    return 0;
}

void StartNormalVote(int client)
{
    if (client < 0) {}
    
    int method = g_Cvar_VoteAdminMethod.IntValue;
    
    char id[64];
    Format(id, sizeof(id), "normal_%d", GetTime());
    
    int emptyClients[MAXPLAYERS + 1];
    MultimodeMethodType voteType;
    
    if (method == 1)
    {
        voteType = VOTE_TYPE_GROUPS_THEN_MAPS;
    }
    else if (method == 2)
    {
        voteType = VOTE_TYPE_GROUPS_ONLY;
    }
    else // method == 3
    {
        voteType = VOTE_TYPE_MAPS_ONLY;
    }
    
    StartAdminVote(id, "", voteType, g_eVoteTiming, emptyClients, 0, true);
}

void StartSeparatedVote(int client)
{
    Menu menu = new Menu(SeparatedGameModeMenuHandler);
    menu.SetTitle("%t", "Show Gamemode Admin Title");

    KeyValues kv = GetMapcycle();
    if (kv == null)
    {
        CPrintToChat(client, "%t", "None Show Gamemode Group");
        delete menu;
        return;
    }
    
    int itemCount = 0;
    
    kv.Rewind();
    if (kv.GotoFirstSubKey(false))
    {
        do
        {
            char gamemodeName[64];
            kv.GetSectionName(gamemodeName, sizeof(gamemodeName));
            
            int adminonly = kv.GetNum("adminonly", 0);
            
            char display[128], groupDisplay[64];
            bool isNominated = MultiMode_IsGroupNominated(gamemodeName, "");
            char voteIndicator[6];
            strcopy(voteIndicator, sizeof(voteIndicator), isNominated ? GESTURE_NOMINATED : "");
            
            kv.GetString(MAPCYCLE_KEY_DISPLAY, groupDisplay, sizeof(groupDisplay), gamemodeName);
            
            if (adminonly == 1) 
                Format(display, sizeof(display), "[ADMIN] %s%s", groupDisplay, voteIndicator);
            else 
                Format(display, sizeof(display), "%s%s", groupDisplay, voteIndicator);
            
            menu.AddItem(gamemodeName, display);
            itemCount++;
        } while (kv.GotoNextKey(false));
        kv.GoBack();
    }
    kv.Rewind();
    
    if (itemCount > 0)
    {
        menu.Display(client, MENU_TIME_FOREVER);
    }
    else
    {
        CPrintToChat(client, "%t", "None Show Gamemode Group");
        delete menu;
    }
}

public int SeparatedGameModeMenuHandler(Menu menu, MenuAction action, int client, int param2)
{
    if (action == MenuAction_Select)
    {
        char gamemode[64];
        menu.GetItem(param2, gamemode, sizeof(gamemode));
        strcopy(g_sClientPendingGameMode[client], sizeof(g_sClientPendingGameMode[]), gamemode);
        ShowSeparatedTimingMenu(client);
    }
    else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack)
    {
        ShowVoteTypeSelectionMenu(client);
    }
    else if (action == MenuAction_End)
    {
        delete menu;
    }
    return 0;
}

void ShowSeparatedTimingMenu(int client)
{
    char buffer[125];
    
    Menu menu = new Menu(SeparatedTimingMenuHandler);
    FormatEx(buffer, sizeof(buffer), "%t", "Timing Title");
    menu.SetTitle(buffer);
    
    FormatEx(buffer, sizeof(buffer), "%t", "Timing NextMap");
    menu.AddItem("nextmap", buffer);

    FormatEx(buffer, sizeof(buffer), "%t", "Timing NextRound");
    menu.AddItem("nextround", buffer);

    FormatEx(buffer, sizeof(buffer), "%t", "Timing Instant");
    menu.AddItem("instant", buffer);
    
    menu.ExitBackButton = true;
    menu.Display(client, MENU_TIME_FOREVER);
}

public int SeparatedTimingMenuHandler(Menu menu, MenuAction action, int client, int param2)
{
    if (action == MenuAction_Select)
    {
        char timingStr[16];
        menu.GetItem(param2, timingStr, sizeof(timingStr));
        
        TimingMode timing = TIMING_NEXTMAP;
        if (StrEqual(timingStr, "nextround"))
            timing = TIMING_NEXTROUND;
        else if (StrEqual(timingStr, "instant"))
            timing = TIMING_INSTANT;

        char id[64];
        Format(id, sizeof(id), "separated_%d", GetTime());
        
        int emptyClients[MAXPLAYERS + 1];
        StartAdminVote(id, g_sClientPendingGameMode[client], VOTE_TYPE_MAPS_ONLY, timing, emptyClients, 0, true);
    }
    else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack)
    {
        StartSeparatedVote(client);
    }
    else if (action == MenuAction_End)
    {
        delete menu;
    }
    return 0;
}

void ShowGameModeMenu(int client, bool forceMode)
{
    Menu menu = new Menu(forceMode ? ForceGameModeMenuHandler : GameModeMenuHandler);
    menu.SetTitle("%t", "Show Gamemode Group Title");

    KeyValues kv = GetMapcycle();
    if (kv == null)
    {
        CPrintToChat(client, "%t", "None Show Gamemode Group");
        delete menu;
        return;
    }
    
    char currentGroup[64];
    char currentSubgroup[64];
    MultiMode_GetCurrentGameMode(currentGroup, sizeof(currentGroup), currentSubgroup, sizeof(currentSubgroup));

    int itemCount = 0;
    
    kv.Rewind();
    if (kv.GotoFirstSubKey(false))
    {
        do
        {
            char gamemodeName[64];
            kv.GetSectionName(gamemodeName, sizeof(gamemodeName));
            
            int enabled = kv.GetNum("enabled", 1);
            int adminonly = kv.GetNum("adminonly", 0);
            
            char display[128], groupDisplay[64];
            char prefix[8] = "";

            if (StrEqual(gamemodeName, currentGroup))
            {
                strcopy(prefix, sizeof(prefix), GESTURE_CURRENT);
            }
            
            kv.GetString(MAPCYCLE_KEY_DISPLAY, groupDisplay, sizeof(groupDisplay), gamemodeName);
            
            bool isNominated = MultiMode_IsGroupNominated(gamemodeName, "");
            char voteIndicator[6];
            strcopy(voteIndicator, sizeof(voteIndicator), isNominated ? GESTURE_NOMINATED : "");
            
            if (forceMode)
            {
                if (enabled == 0 && adminonly == 1)
                    Format(display, sizeof(display), "[DISABLED, ADMIN] %s%s%s", groupDisplay, voteIndicator, prefix);
                else if (enabled == 0)
                    Format(display, sizeof(display), "[DISABLED] %s%s%s", groupDisplay, voteIndicator, prefix);
                else if (adminonly == 1)
                    Format(display, sizeof(display), "[ADMIN] %s%s%s", groupDisplay, voteIndicator, prefix);
                else
                    Format(display, sizeof(display), "%s%s%s", groupDisplay, voteIndicator, prefix);
            }
            else
            {
                Format(display, sizeof(display), "%s%s%s", prefix, groupDisplay, voteIndicator);
            }
            
            menu.AddItem(gamemodeName, display);
            itemCount++;
        } while (kv.GotoNextKey(false));
        kv.GoBack();
    }
    kv.Rewind();
    
    if (itemCount > 0)
    {
        menu.Display(client, MENU_TIME_FOREVER);
    }
    else
    {
        CPrintToChat(client, "%t", "None Show Gamemode Group");
        delete menu;
    }
}

public int GameModeMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
    if (action == MenuAction_Select)
    {
        char sGameMode[64];
        menu.GetItem(param2, sGameMode, sizeof(sGameMode));
        
        char id[64];
        Format(id, sizeof(id), "map_%d", GetTime());
        
        int emptyClients5[MAXPLAYERS + 1];
        StartAdminVote(id, "", VOTE_TYPE_MAPS_ONLY, g_eVoteTiming, emptyClients5, 0, true);
    }
    else if (action == MenuAction_End)
    {
        delete menu;
    }
    return 0;
}

public int ForceGameModeMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
    if (action == MenuAction_Select)
    {
        char sGameMode[64];
        menu.GetItem(param2, sGameMode, sizeof(sGameMode));
        strcopy(g_sClientPendingGameMode[param1], sizeof(g_sClientPendingGameMode[]), sGameMode);

        if (HasSubGroups(sGameMode))
        {
            ShowForceSubGroupMenu(param1, sGameMode);
        }
        else
        {
            ShowMapMenu(param1, sGameMode);
        }
    }
    else if (action == MenuAction_End)
    {
        delete menu;
    }
    return 0;
}

void ShowMapMenu(int client, const char[] sGameMode, const char[] subgroup = "")
{
    Menu menu = new Menu(ForceMapMenuHandler);
    
    if (strlen(subgroup) > 0)
    {
        menu.SetTitle("%t", "SubGroup Map Selection Title", sGameMode, subgroup);
    }
    else
    {
        menu.SetTitle("%t", "Show Map Group Title", sGameMode);
    }
    
    ArrayList maps = new ArrayList(ByteCountToCells(PLATFORM_MAX_PATH));
    
    KeyValues kv = GetMapcycle();
    if (kv == null)
    {
        CPrintToChat(client, "%t", "None Show Map Group");
        delete maps;
        delete menu;
        return;
    }

    kv.Rewind();
    if (kv.JumpToKey(sGameMode))
    {
        if (strlen(subgroup) > 0)
        {
            if (kv.JumpToKey("subgroup") && kv.JumpToKey(subgroup))
            {
                if (kv.JumpToKey("maps"))
                {
                    if (kv.GotoFirstSubKey(false))
                    {
                        do
                        {
                            char mapName[PLATFORM_MAX_PATH];
                            kv.GetSectionName(mapName, sizeof(mapName));
                            maps.PushString(mapName);
                        } while (kv.GotoNextKey(false));
                        kv.GoBack();
                    }
                    kv.GoBack();
                }
                kv.GoBack();
                kv.GoBack();
            }
        }
        else
        {
            if (kv.JumpToKey("maps"))
            {
                if (kv.GotoFirstSubKey(false))
                {
                    do
                    {
                        char mapName[PLATFORM_MAX_PATH];
                        kv.GetSectionName(mapName, sizeof(mapName));
                        maps.PushString(mapName);
                    } while (kv.GotoNextKey(false));
                    kv.GoBack();
                }
                kv.GoBack();
            }
        }
        kv.GoBack();
    }
    kv.Rewind();
    
    if (maps.Length == 0)
    {
        CPrintToChat(client, "%t", "None Show Map Group");
        delete maps;
        delete menu;
        return;
    }
    
    char currentMapName[PLATFORM_MAX_PATH];
    GetCurrentMap(currentMapName, sizeof(currentMapName));
    
    char currentGroup[64], currentSubgroup[64];
    MultiMode_GetCurrentGameMode(currentGroup, sizeof(currentGroup), currentSubgroup, sizeof(currentSubgroup));
    
    char map[256];
    char display[256];
    
    for (int i = 0; i < maps.Length; i++)
    {
        maps.GetString(i, map, sizeof(map));
        
        GetMapDisplayNameEx(sGameMode, map, display, sizeof(display), subgroup);
        
        char prefix[8] = "";
        if (StrEqual(map, currentMapName))
        {
            bool isCurrentMode = false;
            
            if (strlen(subgroup) > 0)
            {
                if (StrEqual(sGameMode, currentGroup) && StrEqual(subgroup, currentSubgroup))
                {
                    isCurrentMode = true;
                }
            }
            else
            {
                if (StrEqual(sGameMode, currentGroup) && strlen(currentSubgroup) == 0)
                {
                    isCurrentMode = true;
                }
            }
            
            if (isCurrentMode)
            {
                strcopy(prefix, sizeof(prefix), GESTURE_CURRENT);
            }
        }

        bool isMapNominated = MultiMode_IsMapNominated(sGameMode, subgroup, map);
        char voteIndicator[6];
        strcopy(voteIndicator, sizeof(voteIndicator), isMapNominated ? GESTURE_NOMINATED : "");
        
        Format(display, sizeof(display), "%s%s%s", display, voteIndicator, prefix);
        
        menu.AddItem(map, display);
    }
    
    delete maps;
    menu.ExitBackButton = true;
    menu.Display(client, MENU_TIME_FOREVER);
}

public int ForceMapMenuHandler(Menu menu, MenuAction action, int client, int param2)
{
    if (action == MenuAction_Select)
    {
        char map[PLATFORM_MAX_PATH];
        menu.GetItem(param2, map, sizeof(map));
        strcopy(g_sClientPendingMap[client], sizeof(g_sClientPendingMap[]), map);
        ShowTimingMenu(client, true);
    }
    else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack)
    {
        ShowGameModeMenu(client, true);
    }
    else if (action == MenuAction_End)
    {
        delete menu;
    }
    return 0;
}

void ShowForceSubGroupMenu(int client, const char[] gamemode)
{
    Menu menu = new Menu(ForceSubGroupMenuHandler);
    menu.SetTitle("%t", "SubGroup Force Title", gamemode);

    char currentGroup[64], currentSubgroup[64];
    MultiMode_GetCurrentGameMode(currentGroup, sizeof(currentGroup), currentSubgroup, sizeof(currentSubgroup));

    KeyValues kv = GetMapcycle();
    if (kv == null)
    {
        CPrintToChat(client, "%t", "No Available SubGroups");
        delete menu;
        ShowGameModeMenu(client, true);
        return;
    }

    kv.Rewind();
    if (kv.JumpToKey(gamemode) && kv.JumpToKey("subgroup"))
    {
        if (kv.GotoFirstSubKey(false))
        {
            do
            {
                char subgroupName[64];
                kv.GetSectionName(subgroupName, sizeof(subgroupName));

                if (StrEqual(subgroupName, "subgroups_invote", false) || StrEqual(subgroupName, "maps_invote", false))
                {
                    continue;
                }
                
                int enabled = kv.GetNum("enabled", 1);
                if (enabled == 0) continue;

                char display[128], subgroupDisplay[64];
                char prefix[8] = "";

                if (StrEqual(gamemode, currentGroup) && StrEqual(subgroupName, currentSubgroup))
                {
                    strcopy(prefix, sizeof(prefix), GESTURE_CURRENT);
                }

                kv.GetString(MAPCYCLE_KEY_DISPLAY, subgroupDisplay, sizeof(subgroupDisplay), subgroupName);
                
                bool isNominated = MultiMode_IsGroupNominated(gamemode, subgroupName);
                char voteIndicator[6];
                strcopy(voteIndicator, sizeof(voteIndicator), isNominated ? GESTURE_NOMINATED : "");

                Format(display, sizeof(display), "%s%s%s", subgroupDisplay, voteIndicator, prefix);
                menu.AddItem(subgroupName, display);
            } while (kv.GotoNextKey(false));
            kv.GoBack();
        }
        kv.GoBack();
        kv.GoBack();
    }
    kv.Rewind();

    if (menu.ItemCount == 0)
    {
        CPrintToChat(client, "%t", "No Available SubGroups");
        delete menu;
        ShowGameModeMenu(client, true);
        return;
    }

    menu.ExitBackButton = true;
    menu.Display(client, MENU_TIME_FOREVER);
}

public int ForceSubGroupMenuHandler(Menu menu, MenuAction action, int client, int param2)
{
    if (action == MenuAction_Select)
    {
        char subgroup[64];
        menu.GetItem(param2, subgroup, sizeof(subgroup));
        
        strcopy(g_sClientPendingSubGroup[client], sizeof(g_sClientPendingSubGroup[]), subgroup);
        ShowMapMenu(client, g_sClientPendingGameMode[client], subgroup);
    }
    else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack)
    {
        ShowGameModeMenu(client, true);
    }
    else if (action == MenuAction_End)
    {
        delete menu;
    }
    return 0;
}

void ShowTimingMenu(int client, bool isForcing)
{
    char buffer[125];
    
    Menu menu = new Menu(isForcing ? ForceTimingMenuHandler : SeparatedTimingMenuHandler);
    FormatEx(buffer, sizeof(buffer), "%t", "Timing Title");
    menu.SetTitle(buffer);
    
    FormatEx(buffer, sizeof(buffer), "%t", "Timing NextMap");
    menu.AddItem("nextmap", buffer);

    FormatEx(buffer, sizeof(buffer), "%t", "Timing NextRound");
    menu.AddItem("nextround", buffer);

    FormatEx(buffer, sizeof(buffer), "%t", "Timing Instant");
    menu.AddItem("instant", buffer);
    
    menu.ExitBackButton = true;
    menu.Display(client, MENU_TIME_FOREVER);
}

public int ForceTimingMenuHandler(Menu menu, MenuAction action, int client, int param2)
{
    if (action == MenuAction_Select)
    {
        char timingStr[16];
        menu.GetItem(param2, timingStr, sizeof(timingStr));
        
        int timing = 0; // TIMING_NEXTMAP
        if (StrEqual(timingStr, "nextround"))
            timing = 1; // TIMING_NEXTROUND
        else if (StrEqual(timingStr, "instant"))
            timing = 2; // TIMING_INSTANT
        
        ExecuteModeChange(
            g_sClientPendingGameMode[client],
            g_sClientPendingMap[client],
            timing,
            g_sClientPendingSubGroup[client]
        );
    }
    else if (action == MenuAction_End)
    {
        delete menu;
    }
    return 0;
}

void ShowExtendTimeMenu(int client)
{
    Menu menu = new Menu(ExtendTimeMenuHandler);
    menu.SetTitle("%t", "Extend Time Title");
    
    menu.AddItem("1", "Increase 1 minute");
    menu.AddItem("2", "Increase 2 minutes");
    menu.AddItem("3", "Increase 3 minutes");
    menu.AddItem("5", "Increase 5 minutes");
    menu.AddItem("10", "Increase 10 minutes");
    menu.AddItem("20", "Increase 20 minutes");
    menu.AddItem("30", "Increase 30 minutes");
    menu.AddItem("60", "Increase 1 hour!");
    
    menu.ExitBackButton = true;
    menu.Display(client, MENU_TIME_FOREVER);
}

public int ExtendTimeMenuHandler(Menu menu, MenuAction action, int client, int param2)
{
    if (action == MenuAction_Select)
    {
        char timeStr[8];
        menu.GetItem(param2, timeStr, sizeof(timeStr));
        float minutes = StringToFloat(timeStr);
        bool bExtendedRounds = false, bExtendedFrags = false;
        int roundStep = 3;
        int fragStep = 10;
        MMC_ExtendMapTime(minutes, roundStep, fragStep, bExtendedRounds, bExtendedFrags);
        
        char clientName[MAX_NAME_LENGTH];
        GetClientName(client, clientName, sizeof(clientName));
        CPrintToChatAll("%t", "Admin Extended Map", clientName, minutes, roundStep, fragStep);
    }
    else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack)
    {
        if (g_topmenu != null)
        {
            g_topmenu.DisplayCategory(g_topmenu.FindCategory("Multimode Core Administration"), client);
        }
    }
    else if (action == MenuAction_End)
    {
        delete menu;
    }
    return 0;
}

void ExecuteModeChange(const char[] gamemode = "", const char[] map, int timing, const char[] subgroup = "")
{
    if (strlen(gamemode) > 0 || strlen(subgroup) > 0) {}

    if (MultiMode_CanStopVote())
    {
        MultiMode_StopVote();
    }
    
    TimingMode mode = view_as<TimingMode>(timing);
    
    SetNextMap(map);
    
    switch(mode)
    {
        case TIMING_NEXTMAP:
        {
            CPrintToChatAll("%t", "Timing NextMap Notify", map);
        }
        
        case TIMING_NEXTROUND:
        {
            CPrintToChatAll("%t", "Timing NextRound Notify", map);
        }
        
        case TIMING_INSTANT:
        {
            char game[20];
            GetGameFolderName(game, sizeof(game));
            ConVar mp_tournament = FindConVar("mp_tournament");
	
            if (mp_tournament != null && mp_tournament.BoolValue)
            {
                ForceChangeLevel(map, "Map modified by admin");
            }
            else
            {
                if (!StrEqual(game, "gesource", false) && !StrEqual(game, "zps", false))
                {
                    int iGameEnd = FindEntityByClassname(-1, "game_end");
                    if (iGameEnd == -1 && (iGameEnd = CreateEntityByName("game_end")) == -1)
                    {
                        ForceChangeLevel(map, "Map modified by admin");
                    } 
                    else 
                    {     
                        AcceptEntityInput(iGameEnd, "EndGame");
                    }
                }
                else
                {
                    ForceChangeLevel(map, "Map modified by admin");
                }
            }

            CPrintToChatAll("%t", "Timing Instant Notify", map);
        }
    }
}

bool HasSubGroups(const char[] gamemode)
{
    ArrayList list = GetGameModesList();
    if (list != null && list.Length > 0)
    {
        int index = MMC_FindGameModeIndex(gamemode);
        if (index != -1)
        {
            GameModeConfig config;
            list.GetArray(index, config);
            return (config.subGroups != null && config.subGroups.Length > 0);
        }
    }
    
    KeyValues kv = GetMapcycle();
    if (kv != null)
    {
        kv.Rewind();
        if (kv.GotoFirstSubKey(false))
        {
            do
            {
                char gamemodeName[64];
                kv.GetSectionName(gamemodeName, sizeof(gamemodeName));
                if (StrEqual(gamemodeName, gamemode))
                {
                    bool hasSubgroups = kv.JumpToKey("subgroup");
                    if (hasSubgroups)
                    {
                        kv.GoBack();
                        kv.Rewind();
                        return true;
                    }
                    kv.Rewind();
                    return false;
                }
            } while (kv.GotoNextKey(false));
            kv.GoBack();
        }
        kv.Rewind();
    }
    
    return false;
}

void GetMapDisplayNameEx(const char[] gamemode, const char[] map, char[] display, int maxlen, const char[] subgroup = "")
{
    KeyValues kv = GetMapcycle();
    if (kv != null)
    {
        MMC_GetMapDisplayNameEx(kv, gamemode, map, display, maxlen, subgroup);
        kv.Rewind();
    }
    else
    {
        strcopy(display, maxlen, map);
    }
}

void StartAdminVote(const char[] id, const char[] mapcycle, MultimodeMethodType voteType, TimingMode timing, int clients[MAXPLAYERS + 1], int numClients, bool adminVote)
{
    char startSound[256] = "";
    char endSound[256] = "";
    char runoffStartSound[256] = "";
    char runoffEndSound[256] = "";
    
    if (g_Cvar_VoteAdminSounds.BoolValue)
    {
        g_Cvar_VoteAdminOpenSound.GetString(startSound, sizeof(startSound));
        g_Cvar_VoteAdminCloseSound.GetString(endSound, sizeof(endSound));
        g_Cvar_VoteAdminRunoffVoteOpenSound.GetString(runoffStartSound, sizeof(runoffStartSound));
        g_Cvar_VoteAdminRunoffVoteCloseSound.GetString(runoffEndSound, sizeof(runoffEndSound));
    }
    
    MultimodeRunoffFailAction runoffFailAction = g_Cvar_VoteAdminRunoffVoteFailed.IntValue == 1 ? RUNOFF_FAIL_DO_NOTHING : RUNOFF_FAIL_PICK_FIRST;
    MultimodeVoteSorted sorted = view_as<MultimodeVoteSorted>(g_Cvar_VoteAdminSorted.IntValue);
    
    int groupexclude = g_Cvar_VoteAdminGroupExclude.IntValue;
    int mapexclude = g_Cvar_VoteAdminMapExclude.IntValue;
    if (groupexclude < 0) groupexclude = -1;
    if (mapexclude < 0) mapexclude = -1;
    
    int maxRunoffs = g_Cvar_VoteAdminRunoff.BoolValue ? g_Cvar_VoteAdminRunoffVoteLimit.IntValue : 0;
    int maxRunoffInVote = g_Cvar_VoteAdminRunoff.BoolValue ? g_Cvar_VoteAdminRunoffInVoteLimit.IntValue : 0;
    float threshold = g_Cvar_VoteAdminRunoffThreshold.FloatValue;
    
    Multimode_StartVote(
        id,
        mapcycle,
        voteType,
        g_Cvar_VoteAdminTime.IntValue,
        timing,
        startSound,
        endSound,
        g_Cvar_VoteAdminExtendVote.BoolValue,
        g_Cvar_VoteAdminExtendTimeStep.IntValue,
        g_Cvar_VoteAdminExtendFragStep.IntValue,
        g_Cvar_VoteAdminExtendRoundStep.IntValue,
        groupexclude,
        mapexclude,
        true,
        threshold,
        maxRunoffs,
        maxRunoffInVote,
        runoffFailAction,
        runoffStartSound,
        runoffEndSound,
        sorted,
        clients,
        numClients,
        adminVote
    );
}