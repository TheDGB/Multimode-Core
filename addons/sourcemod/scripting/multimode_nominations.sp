/*****************************************************************************
                        Multi Mode Nominations Plugin
******************************************************************************/

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <morecolors>
#include <multimode/base>
#include <multimode/utils>
#include <multimode>

public Plugin myinfo = 
{
    name = "[MMC] MultiMode Nominations",
    author = "Oppressive Territory",
    description = "Nomination system for MultiMode Core",
    version = PLUGIN_VERSION,
    url = ""
}

// ConVars
ConVar g_Cvar_UnnominateEnabled;
ConVar g_Cvar_Nominate_NominateOneChance;
ConVar g_Cvar_Nominate_NominateSelectedGroupExclude;
ConVar g_Cvar_Nominate_NominateSelectedMapExclude;
ConVar g_Cvar_Nominate_NominateSorted;
ConVar g_Cvar_Nominate_Method;
ConVar g_Cvar_NominateGroupExclude;
ConVar g_Cvar_NominateSubGroupExclude;
ConVar g_Cvar_NominateMapExclude;

// Char Section
char g_NominateGamemode[MAXPLAYERS+1][64];
char g_NominateSubgroup[MAXPLAYERS+1][64];

// Bool Section
bool g_bHasNominated[MAXPLAYERS+1];
bool g_bNominateDisabled = false;

public void OnPluginStart() 
{
    LoadTranslations("multimode_voter.phrases");
    
    // Reg Console Commands
    RegConsoleCmd("sm_nominate", Command_Nominate, "Nominate a gamemode and map");
	RegConsoleCmd("sm_nom", Command_Nominate, "Nominate a gamemode and map (ALT)");
	
    RegConsoleCmd("sm_unnominate", Command_Unnominate, "Remove one or all of your nominations.");
	RegConsoleCmd("sm_unnom", Command_Unnominate, "Remove one or all of your nominations. (ALT)");
    RegConsoleCmd("sm_quickunnominate", Command_QuickUnnominate, "Quickly remove all your nominations.");
    RegConsoleCmd("sm_quickunnom", Command_QuickUnnominate, "Quickly remove all your nominations. (ALT)");
    
    AddCommandListener(OnPlayerChat, "say");
    AddCommandListener(OnPlayerChat, "say2");
    AddCommandListener(OnPlayerChat, "say_team");
	
    g_Cvar_UnnominateEnabled = CreateConVar("multimode_unnominate", "1", "Enables or disables the unnominate system.", _, true, 0.0, true, 1.0);
    g_Cvar_Nominate_NominateOneChance = CreateConVar("multimode_nominations_onechance", "1", "If enabled, players can only nominate once per map.", _, true, 0.0, true, 1.0);
    g_Cvar_Nominate_NominateSelectedGroupExclude = CreateConVar("multimode_nomination_selectedgroupexclude", "0", "Exclude already nominated groups from the nomination menu.", _, true, 0.0, true, 1.0);
    g_Cvar_Nominate_NominateSelectedMapExclude = CreateConVar("multimode_nomination_selectedmapexclude", "1", "Exclude already nominated maps from the nomination menu.", _, true, 0.0, true, 1.0);
    g_Cvar_Nominate_NominateSorted = CreateConVar("multimode_nomination_sorted", "2", "Sorting mode for nomination menus: 0= Alphabetical, 1= Random, 2= Map Cycle Order", _, true, 0.0, true, 2.0);
    g_Cvar_Nominate_Method = CreateConVar("multimode_nomination_method", "1", "Vote method for nominations: 1= Groups then Maps, 3= Maps Only", _, true, 1.0, true, 3.0);
    g_Cvar_NominateGroupExclude = CreateConVar("multimode_nominate_groupexclude", "2", "Number of recently played gamemodes to exclude from the menu (0= Disabled)");
    g_Cvar_NominateSubGroupExclude = CreateConVar("multimode_nominate_subgroupexclude", "1", "Number of recently played subgroups to exclude from the menu (0= Disabled)");
    g_Cvar_NominateMapExclude = CreateConVar("multimode_nominate_mapexclude", "2", "Number of recently played maps to exclude from the menu (0= Disabled)");
    
    AutoExecConfig(true, "multimode_nominations");
    
    for (int i = 1; i <= MaxClients; i++)
    {
        g_bHasNominated[i] = false;
        g_NominateGamemode[i][0] = '\0';
        g_NominateSubgroup[i][0] = '\0';
    }
}

public void OnMapStart()
{
    g_bNominateDisabled = false;
}

public void OnClientDisconnect(int client)
{
    g_bHasNominated[client] = false;
    g_NominateGamemode[client][0] = '\0';
    g_NominateSubgroup[client][0] = '\0';
}

public void MultiMode_OnVoteEnd(const char[] group, const char[] subgroup, const char[] map, VoteEndReason reason)
{
    if (reason == VoteEnd_Winner)
    {
        g_bNominateDisabled = true;
    }
}

public Action OnPlayerChat(int client, const char[] command, int argc)
{
    if (argc == 0)
        return Plugin_Continue;

    char text[13];
    GetCmdArg(1, text, sizeof(text));

    if (StrEqual(text, "nominate", false)|| StrEqual(text, "nom", false))
    {
        Command_Nominate(client, 0);
        return Plugin_Continue;
    }
	
    else if (StrEqual(text, "unnominate", false) || StrEqual(text, "unnom", false))
    {
        Command_Unnominate(client, 0);
        return Plugin_Continue;
    }
	
    else if (StrEqual(text, "quickunnominate", false) || StrEqual(text, "quickunnom", false))
    {
        Command_QuickUnnominate(client, 0);
        return Plugin_Continue;
    }

    return Plugin_Continue;
}

public Action Command_Nominate(int client, int args)
{
    if (!client || !IsClientInGame(client)) 
        return Plugin_Handled;
    
    if (MultiMode_IsVoteActive() || g_bNominateDisabled)
    {
        CReplyToCommand(client, "%t", "Nominate Disabled");
        return Plugin_Handled;
    }
    
    if (g_Cvar_Nominate_NominateOneChance.BoolValue && g_bHasNominated[client])
    {
        CPrintToChat(client, "%t", "Nominate Once Per Map");
        return Plugin_Handled;
    }

    if (g_Cvar_Nominate_Method.IntValue == 3)
    {
        ShowAllMapsNominateMenu(client);
        return Plugin_Handled;
    }

    ShowNominateGamemodeMenu(client);
    return Plugin_Handled;
}

public Action Command_Unnominate(int client, int args)
{
    if (!client || !IsClientInGame(client)) 
        return Plugin_Handled;
    
    if (MultiMode_IsVoteActive() || g_bNominateDisabled)
    {
        CReplyToCommand(client, "%t", "Nominate Disabled");
        return Plugin_Handled;
    }
    
    if (!g_Cvar_UnnominateEnabled.BoolValue)
    {
        CReplyToCommand(client, "%t", "Unnominate System Is Disabled");
        return Plugin_Handled;
    }
	
    int count = MultiMode_GetClientNominationCount(client);
    if (count == 0)
    {
        CPrintToChat(client, "%t", "Unnominate None"); 
        return Plugin_Handled;
    }

    Menu menu = new Menu(UnnominateMenuHandler);
    menu.SetTitle("%t", "Unnominate Menu Title");
	
    char buffer[125];
    FormatEx(buffer, sizeof(buffer), "%t", "Unnominate Clear All");
    menu.AddItem("cleanup", buffer);

    for (int i = 0; i < count; i++)
    {
        char group[64], subgroup[64], map[PLATFORM_MAX_PATH];
        if (MultiMode_GetClientNomination(client, i, group, sizeof(group), subgroup, sizeof(subgroup), map, sizeof(map)))
        {
        char display[256];
        char mapDisplay[256];
        MultiMode_GetMapDisplayName(group, map, subgroup, mapDisplay, sizeof(mapDisplay));
        
        if (strlen(subgroup) > 0)
        {
            Format(display, sizeof(display), "%s/%s - %s", group, subgroup, mapDisplay);
        }
        else
        {
            Format(display, sizeof(display), "%s - %s", group, mapDisplay);
        }
            
            char info[16];
            IntToString(i, info, sizeof(info));
            menu.AddItem(info, display);
        }
    }
    
    menu.ExitButton = true;
    menu.Display(client, MENU_TIME_FOREVER);
    return Plugin_Handled;
}

public int UnnominateMenuHandler(Menu menu, MenuAction action, int client, int param2)
{
    if (action == MenuAction_Select)
    {
        char info[32];
        menu.GetItem(param2, info, sizeof(info));

        if (StrEqual(info, "cleanup"))
        {
            MultiMode_RemoveAllNominations(client);
            CPrintToChat(client, "%t", "Unnominate All Removed");
        }
        else
        {
            int index = StringToInt(info);
            char group[64], subgroup[64], map[PLATFORM_MAX_PATH];
            if (MultiMode_GetClientNomination(client, index, group, sizeof(group), subgroup, sizeof(subgroup), map, sizeof(map)))
            {
                char mapDisplay[256];
                MultiMode_GetMapDisplayName(group, map, subgroup, mapDisplay, sizeof(mapDisplay));
                
                if (MultiMode_RemoveNomination(client, index))
                {
                    char displayKey[192];
                    if(strlen(subgroup) > 0)
                        Format(displayKey, sizeof(displayKey), "%s/%s", group, subgroup);
                    else
                        strcopy(displayKey, sizeof(displayKey), group);
                        
                    CPrintToChat(client, "%t", "Unnominate Single Removed", mapDisplay, displayKey);
                }
            }
        }
    }
    else if (action == MenuAction_End)
    {
        delete menu;
    }
    return 0;
}

public Action Command_QuickUnnominate(int client, int args)
{
    if (!client || !IsClientInGame(client)) 
        return Plugin_Handled;
    
    if (MultiMode_IsVoteActive() || g_bNominateDisabled)
    {
        CReplyToCommand(client, "%t", "Nominate Disabled");
        return Plugin_Handled;
    }
    
    if (!g_Cvar_UnnominateEnabled.BoolValue)
    {
        CReplyToCommand(client, "%t", "Unnominate System Is Disabled");
        return Plugin_Handled;
    }
	
    int count = MultiMode_GetClientNominationCount(client);
    if (count == 0)
    {
        CPrintToChat(client, "%t", "Unnominate None");
        return Plugin_Handled;
    }
    
    MultiMode_RemoveAllNominations(client);
    CPrintToChat(client, "%t", "Unnominate All Removed");
    return Plugin_Handled;
}

void ShowNominateGamemodeMenu(int client)
{
    Menu menu = new Menu(NominateGamemodeMenuHandler);
    menu.SetTitle("%t", "Nominate Gamemode Group Menu Title");

    ArrayList gamemodes = new ArrayList(ByteCountToCells(64));
    Multimode_GetGamemodeList(gamemodes, false, false);
    
    int sortMode = g_Cvar_Nominate_NominateSorted.IntValue;
    if (sortMode == 0) // Alphabetical
    {
        SortADTArray(gamemodes, Sort_Ascending, Sort_String);
    }
    else if (sortMode == 1) // Random
    {
        SortADTArray(gamemodes, Sort_Random, Sort_String);
    }

    int groupExclude = g_Cvar_NominateGroupExclude.IntValue;
    
    for (int i = 0; i < gamemodes.Length; i++)
    {
        char gamemode[64];
        gamemodes.GetString(i, gamemode, sizeof(gamemode));

        bool isNominated = MultiMode_IsGroupNominated(gamemode);
        if (!isNominated)
        {
            ArrayList subgroups = new ArrayList(ByteCountToCells(64));
            if (Multimode_GetSubgroupList(gamemode, subgroups, false, false) > 0)
            {
                for (int j = 0; j < subgroups.Length && !isNominated; j++)
                {
                    char subgroup[64];
                    subgroups.GetString(j, subgroup, sizeof(subgroup));
                    if (MultiMode_IsGroupNominated(gamemode, subgroup))
                    {
                        isNominated = true;
                    }
                }
            }
            delete subgroups;
        }
        
        bool isRecentlyPlayed = (groupExclude > 0 && MultiMode_IsGamemodeRecentlyPlayed(gamemode, groupExclude));
        bool canNominate = MMC_CanClientNominate(client, gamemode);
        char display[128];
        
        if (!canNominate)
        {
            Format(display, sizeof(display), "%s%s", gamemode, GESTURE_EXCLUDED);
            menu.AddItem(gamemode, display, ITEMDRAW_DISABLED);
        }
        else if (g_Cvar_Nominate_NominateSelectedGroupExclude.BoolValue && isNominated)
        {
            Format(display, sizeof(display), "%s%s", gamemode, GESTURE_SELECTEDNOMINATED);
            menu.AddItem(gamemode, display, ITEMDRAW_DISABLED);
        }
        else if (isRecentlyPlayed)
        {
            Format(display, sizeof(display), "%s%s", gamemode, GESTURE_EXCLUDED);
            menu.AddItem(gamemode, display, ITEMDRAW_DISABLED);
        }
        else
        {
            if (isNominated)
            {
                Format(display, sizeof(display), "%s%s", gamemode, GESTURE_NOMINATED);
            }
            else
            {
                strcopy(display, sizeof(display), gamemode);
            }
            menu.AddItem(gamemode, display);
        }
    }

    delete gamemodes;
    menu.Display(client, MENU_TIME_FOREVER);
}

public int NominateGamemodeMenuHandler(Menu menu, MenuAction action, int client, int param2)
{
    if (action == MenuAction_Select)
    {
        if (MultiMode_IsVoteActive() || g_bNominateDisabled)
        {
            CPrintToChat(client, "%t", "Nominate Disabled");
            return 0;
        }
        
        char gamemode[64];
        menu.GetItem(param2, gamemode, sizeof(gamemode));
        strcopy(g_NominateGamemode[client], sizeof(g_NominateGamemode[]), gamemode);
        g_NominateSubgroup[client][0] = '\0';
        
        ArrayList subgroups = new ArrayList(ByteCountToCells(64));
        if (Multimode_GetSubgroupList(gamemode, subgroups, false, false) > 0)
        {
            ShowNominateSubGroupMenu(client, gamemode);
        }
        else
        {
            ShowNominateMapMenu(client, gamemode, "");
        }
        delete subgroups;
    }
    else if (action == MenuAction_End)
    {
        delete menu;
    }
    return 0;
}

void ShowNominateSubGroupMenu(int client, const char[] gamemode)
{
    ArrayList subgroups = new ArrayList(ByteCountToCells(64));
    int count = Multimode_GetSubgroupList(gamemode, subgroups, false, false);
    
    if (count <= 0)
    {
        CPrintToChat(client, "%t", "No Available SubGroups");
        delete subgroups;
        return;
    }

    Menu menu = new Menu(NominateSubGroupMenuHandler);
    menu.SetTitle("%t", "Nominate SubGroup Menu Title", gamemode);

    int subgroupExclude = g_Cvar_NominateSubGroupExclude.IntValue;
    
    for (int i = 0; i < subgroups.Length; i++)
    {
        char subgroup[64];
        subgroups.GetString(i, subgroup, sizeof(subgroup));
        
        char fullSubgroupKey[128];
        Format(fullSubgroupKey, sizeof(fullSubgroupKey), "%s/%s", gamemode, subgroup);
        
        bool isNominated = MultiMode_IsGroupNominated(gamemode, subgroup);
        bool isRecentlyPlayed = (subgroupExclude > 0 && MultiMode_IsSubGroupRecentlyPlayed(gamemode, subgroup, subgroupExclude));
        bool canNominate = MMC_CanClientNominate(client, gamemode, subgroup);
        char display[128];

        if (!canNominate)
        {
            Format(display, sizeof(display), "%s%s", subgroup, GESTURE_EXCLUDED);
            menu.AddItem(subgroup, display, ITEMDRAW_DISABLED);
        }
        else if (g_Cvar_Nominate_NominateSelectedGroupExclude.BoolValue && isNominated)
        {
            Format(display, sizeof(display), "%s%s", subgroup, GESTURE_SELECTEDNOMINATED);
            menu.AddItem(subgroup, display, ITEMDRAW_DISABLED);
        }
        else if (isRecentlyPlayed)
        {
            Format(display, sizeof(display), "%s%s", subgroup, GESTURE_EXCLUDED);
            menu.AddItem(subgroup, display, ITEMDRAW_DISABLED);
        }
        else
        {
            if (isNominated)
            {
                Format(display, sizeof(display), "%s%s", subgroup, GESTURE_NOMINATED);
            }
            else
            {
                strcopy(display, sizeof(display), subgroup);
            }
            menu.AddItem(subgroup, display);
        }
    }

    delete subgroups;
    menu.ExitBackButton = true;
    menu.Display(client, MENU_TIME_FOREVER);
}

public int NominateSubGroupMenuHandler(Menu menu, MenuAction action, int client, int param2)
{
    if (action == MenuAction_Select)
    {
        if (MultiMode_IsVoteActive() || g_bNominateDisabled)
        {
            CPrintToChat(client, "%t", "Nominate Disabled");
            return 0;
        }
        
        char subgroup[64];
        menu.GetItem(param2, subgroup, sizeof(subgroup));
        strcopy(g_NominateSubgroup[client], sizeof(g_NominateSubgroup[]), subgroup);
        ShowNominateMapMenu(client, g_NominateGamemode[client], subgroup);
    }
    else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack)
    {
        ShowNominateGamemodeMenu(client);
    }
    else if (action == MenuAction_End)
    {
        delete menu;
    }
    return 0;
}

void ShowNominateMapMenu(int client, const char[] gamemode, const char[] subgroup)
{
    ArrayList maps = new ArrayList(ByteCountToCells(PLATFORM_MAX_PATH));
    int count = Multimode_GetMapList(gamemode, subgroup, maps);
    
    if (count <= 0)
    {
        CPrintToChat(client, "%t", "Nominate Gamemode Not Found");
        delete maps;
        return;
    }

    int sortMode = g_Cvar_Nominate_NominateSorted.IntValue;
    if (sortMode == 0) // Alphabetical
    {
        SortADTArray(maps, Sort_Ascending, Sort_String);
    }
    else if (sortMode == 1) // Random
    {
        SortADTArray(maps, Sort_Random, Sort_String);
    }

    Menu menu = new Menu(NominateMapMenuHandler);
    
    char title[128];
    if (strlen(subgroup) > 0)
    {
        Format(title, sizeof(title), "%T", "Nominate SubGroup Map Title", client, gamemode, subgroup);
    }
    else
    {
        Format(title, sizeof(title), "%T", "Nominate Map Title", client, gamemode);
    }
    menu.SetTitle(title);

    int mapExclude = g_Cvar_NominateMapExclude.IntValue;
    
    for (int i = 0; i < maps.Length; i++)
    {
        char map[PLATFORM_MAX_PATH];
        maps.GetString(i, map, sizeof(map));
        
        bool isNominated = MultiMode_IsMapNominated(gamemode, subgroup, map);
        bool isRecentlyPlayed = (mapExclude > 0 && MultiMode_IsMapRecentlyPlayed(gamemode, map, subgroup, mapExclude));
        bool canNominate = MMC_CanClientNominate(client, gamemode, subgroup, map);
        char displayName[256];
        MultiMode_GetMapDisplayName(gamemode, map, subgroup, displayName, sizeof(displayName));

        if (!canNominate)
        {
            Format(displayName, sizeof(displayName), "%s%s", displayName, GESTURE_EXCLUDED);
            menu.AddItem(map, displayName, ITEMDRAW_DISABLED);
        }
        else if (g_Cvar_Nominate_NominateSelectedMapExclude.BoolValue && isNominated)
        {
            Format(displayName, sizeof(displayName), "%s%s", displayName, GESTURE_SELECTEDNOMINATED);
            menu.AddItem(map, displayName, ITEMDRAW_DISABLED);
        }
        else if (isRecentlyPlayed)
        {
            Format(displayName, sizeof(displayName), "%s%s", displayName, GESTURE_EXCLUDED);
            menu.AddItem(map, displayName, ITEMDRAW_DISABLED);
        }
        else
        {
            if (isNominated)
            {
                Format(displayName, sizeof(displayName), "%s%s", displayName, GESTURE_NOMINATED);
            }
            menu.AddItem(map, displayName);
        }
    }

    delete maps;
    menu.ExitBackButton = true;
    menu.Display(client, MENU_TIME_FOREVER);
}

public int NominateMapMenuHandler(Menu menu, MenuAction action, int client, int param2)
{
    if (action == MenuAction_Select)
    {
        if (MultiMode_IsVoteActive() || g_bNominateDisabled)
        {
            CPrintToChat(client, "%t", "Nominate Disabled");
            return 0;
        }
        
        char map[PLATFORM_MAX_PATH];
        menu.GetItem(param2, map, sizeof(map));
        
        if (!MMC_CanClientNominate(client, g_NominateGamemode[client], g_NominateSubgroup[client], map))
        {
            CPrintToChat(client, "%t", "Nominate Disabled");
            return 0;
        }
        
        if (!g_Cvar_Nominate_NominateSelectedMapExclude.BoolValue && MultiMode_IsMapNominated(g_NominateGamemode[client], g_NominateSubgroup[client], map))
        {
            char mapDisplay[256];
            MultiMode_GetMapDisplayName(g_NominateGamemode[client], map, g_NominateSubgroup[client], mapDisplay, sizeof(mapDisplay));
            
            char displayKey[192];
            if(strlen(g_NominateSubgroup[client]) > 0)
                Format(displayKey, sizeof(displayKey), "%s/%s", g_NominateGamemode[client], g_NominateSubgroup[client]);
            else
                strcopy(displayKey, sizeof(displayKey), g_NominateGamemode[client]);
            
            char fullDisplay[512];
            Format(fullDisplay, sizeof(fullDisplay), "%s - %s", mapDisplay, displayKey);
            
            for (int i = 1; i <= MaxClients; i++)
            {
                if (IsClientInGame(i) && !IsFakeClient(i))
                {
                    char message[512];
                    Format(message, sizeof(message), "%T", "Map Already Nominated", i, fullDisplay);
                    CPrintToChat(i, message);
                }
            }
            return 0;
        }
        
        if (MultiMode_Nominate(client, g_NominateGamemode[client], g_NominateSubgroup[client], map))
        {
            g_bHasNominated[client] = true;
        }
        else
        {
            if (!g_Cvar_Nominate_NominateSelectedMapExclude.BoolValue && MultiMode_IsMapNominated(g_NominateGamemode[client], g_NominateSubgroup[client], map))
            {
                char mapDisplay[256];
                MultiMode_GetMapDisplayName(g_NominateGamemode[client], map, g_NominateSubgroup[client], mapDisplay, sizeof(mapDisplay));
                
                char displayKey[192];
                if(strlen(g_NominateSubgroup[client]) > 0)
                    Format(displayKey, sizeof(displayKey), "%s/%s", g_NominateGamemode[client], g_NominateSubgroup[client]);
                else
                    strcopy(displayKey, sizeof(displayKey), g_NominateGamemode[client]);
                
                char fullDisplay[512];
                Format(fullDisplay, sizeof(fullDisplay), "%s - %s", mapDisplay, displayKey);
                
                for (int i = 1; i <= MaxClients; i++)
                {
                    if (IsClientInGame(i) && !IsFakeClient(i))
                    {
                        char message[512];
                        Format(message, sizeof(message), "%T", "Map Already Nominated", i, fullDisplay);
                        CPrintToChat(i, message);
                    }
                }
            }
        }
    }
    else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack)
    {
        if (strlen(g_NominateSubgroup[client]) > 0)
        {
            ShowNominateSubGroupMenu(client, g_NominateGamemode[client]);
        }
        else
        {
            ShowNominateGamemodeMenu(client);
        }
    }
    else if (action == MenuAction_End)
    {
        delete menu;
    }
    return 0;
}

void ShowAllMapsNominateMenu(int client)
{
    ArrayList gamemodes = new ArrayList(ByteCountToCells(64));
    Multimode_GetGamemodeList(gamemodes, false, false);
    
    ArrayList allMaps = new ArrayList(ByteCountToCells(PLATFORM_MAX_PATH));
    StringMap uniqueMaps = new StringMap();
    
    for (int i = 0; i < gamemodes.Length; i++)
    {
        char gamemode[64];
        gamemodes.GetString(i, gamemode, sizeof(gamemode));
        
        ArrayList maps = new ArrayList(ByteCountToCells(PLATFORM_MAX_PATH));
        Multimode_GetMapList(gamemode, "", maps);
        
        for (int j = 0; j < maps.Length; j++)
        {
            char map[PLATFORM_MAX_PATH];
            maps.GetString(j, map, sizeof(map));
            
            if (!uniqueMaps.ContainsKey(map))
            {
                allMaps.PushString(map);
                uniqueMaps.SetValue(map, true);
            }
        }
        delete maps;
        
        ArrayList subgroups = new ArrayList(ByteCountToCells(64));
        Multimode_GetSubgroupList(gamemode, subgroups, false, false);
        
        for (int j = 0; j < subgroups.Length; j++)
        {
            char subgroup[64];
            subgroups.GetString(j, subgroup, sizeof(subgroup));
            
            ArrayList subMaps = new ArrayList(ByteCountToCells(PLATFORM_MAX_PATH));
            Multimode_GetMapList(gamemode, subgroup, subMaps);
            
            for (int k = 0; k < subMaps.Length; k++)
            {
                char map[PLATFORM_MAX_PATH];
                subMaps.GetString(k, map, sizeof(map));
                
                if (!uniqueMaps.ContainsKey(map))
                {
                    allMaps.PushString(map);
                    uniqueMaps.SetValue(map, true);
                }
            }
            delete subMaps;
        }
        delete subgroups;
    }
    
    delete uniqueMaps;
    delete gamemodes;

    int sortMode = g_Cvar_Nominate_NominateSorted.IntValue;
    if (sortMode == 0) // Alphabetical
    {
        SortADTArray(allMaps, Sort_Ascending, Sort_String);
    }
    else if (sortMode == 1) // Random
    {
        SortADTArray(allMaps, Sort_Random, Sort_String);
    }

    Menu menu = new Menu(AllMapsNominateMenuHandler);
    char menuTitle[128];
    Format(menuTitle, sizeof(menuTitle), "%t", "Nominate Map Title", "All Maps");
    menu.SetTitle(menuTitle);

    int mapExclude = g_Cvar_NominateMapExclude.IntValue;
    
    for (int i = 0; i < allMaps.Length; i++)
    {
        char map[PLATFORM_MAX_PATH];
        allMaps.GetString(i, map, sizeof(map));

        bool isRecentlyPlayed = false;
        if (mapExclude > 0)
        {
            ArrayList checkGamemodes = new ArrayList(ByteCountToCells(64));
            Multimode_GetGamemodeList(checkGamemodes, false, false);
            
            for (int j = 0; j < checkGamemodes.Length && !isRecentlyPlayed; j++)
            {
                char gamemode[64];
                checkGamemodes.GetString(j, gamemode, sizeof(gamemode));

                if (MultiMode_IsMapRecentlyPlayed(gamemode, map, "", mapExclude))
                {
                    isRecentlyPlayed = true;
                    break;
                }

                ArrayList subgroups = new ArrayList(ByteCountToCells(64));
                if (Multimode_GetSubgroupList(gamemode, subgroups, false, false) > 0)
                {
                    for (int k = 0; k < subgroups.Length && !isRecentlyPlayed; k++)
                    {
                        char subgroup[64];
                        subgroups.GetString(k, subgroup, sizeof(subgroup));
                        
                        if (MultiMode_IsMapRecentlyPlayed(gamemode, map, subgroup, mapExclude))
                        {
                            isRecentlyPlayed = true;
                            break;
                        }
                    }
                }
                delete subgroups;
            }
            delete checkGamemodes;
        }
        
        char display[256];
        MultiMode_GetMapDisplayName("", map, "", display, sizeof(display));
        
        if (isRecentlyPlayed)
        {
            Format(display, sizeof(display), "%s%s", display, GESTURE_EXCLUDED);
            menu.AddItem(map, display, ITEMDRAW_DISABLED);
        }
        else
        {
            menu.AddItem(map, display);
        }
    }

    delete allMaps;
    menu.ExitButton = true;
    menu.Display(client, MENU_TIME_FOREVER);
}

public int AllMapsNominateMenuHandler(Menu menu, MenuAction action, int client, int param2)
{
    if (action == MenuAction_Select)
    {
        if (MultiMode_IsVoteActive() || g_bNominateDisabled)
        {
            CPrintToChat(client, "%t", "Nominate Disabled");
            return 0;
        }
        
        char map[PLATFORM_MAX_PATH];
        menu.GetItem(param2, map, sizeof(map));
        
        ArrayList gamemodes = new ArrayList(ByteCountToCells(64));
        Multimode_GetGamemodeList(gamemodes, false, false);
        
        bool found = false;
        char foundGamemode[64];
        char foundSubgroup[64];
        foundSubgroup[0] = '\0';
        
        for (int i = 0; i < gamemodes.Length && !found; i++)
        {
            char gamemode[64];
            gamemodes.GetString(i, gamemode, sizeof(gamemode));
            
            ArrayList maps = new ArrayList(ByteCountToCells(PLATFORM_MAX_PATH));
            if (Multimode_GetMapList(gamemode, "", maps) > 0)
            {
                if (maps.FindString(map) != -1)
                {
                    strcopy(foundGamemode, sizeof(foundGamemode), gamemode);
                    found = true;
                }
            }
            delete maps;
            
            if (!found)
            {
                ArrayList subgroups = new ArrayList(ByteCountToCells(64));
                if (Multimode_GetSubgroupList(gamemode, subgroups, false, false) > 0)
                {
                    for (int j = 0; j < subgroups.Length && !found; j++)
                    {
                        char subgroup[64];
                        subgroups.GetString(j, subgroup, sizeof(subgroup));
                        
                        ArrayList subMaps = new ArrayList(ByteCountToCells(PLATFORM_MAX_PATH));
                        if (Multimode_GetMapList(gamemode, subgroup, subMaps) > 0)
                        {
                            if (subMaps.FindString(map) != -1)
                            {
                                strcopy(foundGamemode, sizeof(foundGamemode), gamemode);
                                strcopy(foundSubgroup, sizeof(foundSubgroup), subgroup);
                                found = true;
                            }
                        }
                        delete subMaps;
                    }
                }
                delete subgroups;
            }
        }
        delete gamemodes;
        
        if (found)
        {
            if (!MMC_CanClientNominate(client, foundGamemode, foundSubgroup, map))
            {
                CPrintToChat(client, "%t", "Nominate Disabled");
                return 0;
            }

            if (!g_Cvar_Nominate_NominateSelectedMapExclude.BoolValue && MultiMode_IsMapNominated(foundGamemode, foundSubgroup, map))
            {
                char mapDisplay[256];
                MultiMode_GetMapDisplayName(foundGamemode, map, foundSubgroup, mapDisplay, sizeof(mapDisplay));
                
                char displayKey[192];
                if(strlen(foundSubgroup) > 0)
                    Format(displayKey, sizeof(displayKey), "%s/%s", foundGamemode, foundSubgroup);
                else
                    strcopy(displayKey, sizeof(displayKey), foundGamemode);
                
                char fullDisplay[512];
                Format(fullDisplay, sizeof(fullDisplay), "%s - %s", mapDisplay, displayKey);

                for (int k = 1; k <= MaxClients; k++)
                {
                    if (IsClientInGame(k) && !IsFakeClient(k))
                    {
                        char message[512];
                        Format(message, sizeof(message), "%T", "Map Already Nominated", k, fullDisplay);
                        CPrintToChat(k, message);
                    }
                }
            }
            else if (MultiMode_Nominate(client, foundGamemode, foundSubgroup, map))
            {
                g_bHasNominated[client] = true;
            }
        }
        else
        {
            CPrintToChat(client, "%t", "Nominate Gamemode Not Found");
        }
    }
    else if (action == MenuAction_End)
    {
        delete menu;
    }
    return 0;
}

