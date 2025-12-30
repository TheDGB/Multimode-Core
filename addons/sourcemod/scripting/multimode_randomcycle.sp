/*****************************************************************************
                        Multi Mode Random Cycle Plugin
******************************************************************************/

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <morecolors>
#include <multimode/base>
#include <multimode>
#include <multimode/randomcycle>

public Plugin myinfo = 
{
    name = "[MMC] MultiMode Random Cycle",
    author = "Oppressive Territory",
    description = "Random map cycle system for MultiMode Core",
    version = PLUGIN_VERSION,
    url = ""
}

// ConVars
ConVar g_Cvar_RandomCycleType;
ConVar g_Cvar_RandomCycleGroupExclude;
ConVar g_Cvar_RandomCycleSubGroupExclude;
ConVar g_Cvar_RandomCycleMapExclude;

// Global Forward Section
GlobalForward g_OnRandomCycleMapSetForward;

// Bool Section
bool g_bIntermissionCalled = false;

// UserMsg Section
UserMsg g_VGuiMenuId = INVALID_MESSAGE_ID;

public void OnPluginStart() 
{
    // Convars
    g_Cvar_RandomCycleType = CreateConVar("multimode_randomcycle_type", "1", "Random Cycle Type: 1-Selects at the beginning of the map, 2-Selects when there is no next map at the end of the map.", _, true, 1.0, true, 2.0);
    g_Cvar_RandomCycleGroupExclude = CreateConVar("multimode_randomcycle_groupexclude", "0", "Number of recently played gamemodes to exclude from random cycle (0= Disabled)");
    g_Cvar_RandomCycleSubGroupExclude = CreateConVar("multimode_randomcycle_subgroupexclude", "0", "Number of recently played subgroups to exclude from random cycle (0= Disabled)");
    g_Cvar_RandomCycleMapExclude = CreateConVar("multimode_randomcycle_mapexclude", "2", "Number of recently played maps to exclude from random cycle (0= Disabled)");
    
    g_OnRandomCycleMapSetForward = CreateGlobalForward("MultiMode_OnRandomCycleMapSet", ET_Ignore, Param_String, Param_String, Param_String);
	
    HookEventEx("game_end", Event_GameOver, EventHookMode_PostNoCopy);
	HookEventEx("game_newmap", Event_GameOver, EventHookMode_PostNoCopy); //Insurgency
	HookEventEx("dod_game_over", Event_GameOver, EventHookMode_PostNoCopy); //DoD
	HookEventEx("teamplay_game_over", Event_GameOver, EventHookMode_PostNoCopy); //TF
	HookEventEx("tf_game_over", Event_GameOver, EventHookMode_PostNoCopy); //TF
    
    char game[20];
    GetGameFolderName(game, sizeof(game));
    if (!StrEqual(game, "tf", false) &&
        !StrEqual(game, "dod", false) &&
        !StrEqual(game, "insurgency", false))
    {
        g_VGuiMenuId = GetUserMessageId("VGUIMenu");
        if (g_VGuiMenuId != INVALID_MESSAGE_ID)
        {
            HookUserMessage(g_VGuiMenuId, OnVGuiMenu_BfRead);
            HookUserMessage(g_VGuiMenuId, OnVGuiMenu_Protobuf);
        }
    }
}

public void OnMapStart()
{
    g_bIntermissionCalled = false;
    
    if (g_Cvar_RandomCycleType.IntValue == 1)
    {
        SelectRandomNextMap(true);
    }
}

public void Event_GameOver(Event event, const char[] name, bool dontBroadcast)
{
    if (g_bIntermissionCalled)
    {
        return;
    }
    
    g_bIntermissionCalled = true;
    
    char nextMap[PLATFORM_MAX_PATH];
    MultiMode_GetNextMap(nextMap, sizeof(nextMap));
    
    if (StrEqual(nextMap, ""))
    {
        SelectRandomNextMap(true);
    }
}

void SelectRandomNextMap(bool bSetNextMap = false)
{
    char nextMap[PLATFORM_MAX_PATH];
    MultiMode_GetNextMap(nextMap, sizeof(nextMap));
    
    if (!StrEqual(nextMap, ""))
    {
        return;
    }
    
    int groupExclude = g_Cvar_RandomCycleGroupExclude.IntValue;
    int subgroupExclude = g_Cvar_RandomCycleSubGroupExclude.IntValue;
    int mapExclude = g_Cvar_RandomCycleMapExclude.IntValue;
    
    ArrayList gamemodes = new ArrayList(ByteCountToCells(64));
    int gamemodeCount = Multimode_GetGamemodeList(gamemodes, false, false);
    
    if (gamemodeCount == 0)
    {
        delete gamemodes;
        return;
    }
    
    char selectedGroup[64] = "";
    char selectedSubgroup[64] = "";
    char selectedMap[PLATFORM_MAX_PATH] = "";
    bool found = false;
    
    for (int attempt = 0; attempt < 50 && !found; attempt++)
    {
        int randomGamemodeIndex = GetRandomInt(0, gamemodes.Length - 1);
        char gamemode[64];
        gamemodes.GetString(randomGamemodeIndex, gamemode, sizeof(gamemode));
        
        if (groupExclude > 0 && MultiMode_IsGamemodeRecentlyPlayed(gamemode, groupExclude))
        {
            continue;
        }
        
        if (MultiMode_GetRandomMap(gamemode, sizeof(gamemode), "", 0, selectedMap, sizeof(selectedMap)))
        {
            if (mapExclude > 0 && MultiMode_IsMapRecentlyPlayed(gamemode, selectedMap, "", mapExclude))
            {
                continue;
            }
            
            strcopy(selectedGroup, sizeof(selectedGroup), gamemode);
            selectedSubgroup[0] = '\0';
            found = true;
            break;
        }
        
        ArrayList subgroups = new ArrayList(ByteCountToCells(64));
        int subgroupCount = Multimode_GetSubgroupList(gamemode, subgroups, false, false);
        
        if (subgroupCount > 0)
        {
            int randomSubgroupIndex = GetRandomInt(0, subgroups.Length - 1);
            char subgroup[64];
            subgroups.GetString(randomSubgroupIndex, subgroup, sizeof(subgroup));
            
            if (subgroupExclude > 0 && MultiMode_IsSubGroupRecentlyPlayed(gamemode, subgroup, subgroupExclude))
            {
                delete subgroups;
                continue;
            }
            
            if (MultiMode_GetRandomMap(gamemode, sizeof(gamemode), subgroup, sizeof(subgroup), selectedMap, sizeof(selectedMap)))
            {
                if (mapExclude > 0 && MultiMode_IsMapRecentlyPlayed(gamemode, selectedMap, subgroup, mapExclude))
                {
                    delete subgroups;
                    continue;
                }
                
                strcopy(selectedGroup, sizeof(selectedGroup), gamemode);
                strcopy(selectedSubgroup, sizeof(selectedSubgroup), subgroup);
                found = true;
                delete subgroups;
                break;
            }
        }
        
        delete subgroups;
    }
    
    delete gamemodes;
    
    if (!found || StrEqual(selectedMap, ""))
    {
        if (MultiMode_GetRandomMap("", 0, "", 0, selectedMap, sizeof(selectedMap)))
        {
            found = true;
        }
    }
    
    if (found && !StrEqual(selectedMap, ""))
    {
        if (IsMapValid(selectedMap))
        {
            if (bSetNextMap)
            {
                if (strlen(selectedSubgroup) > 0 && strlen(selectedGroup) > 0)
                {
                    MultiMode_SetNextMap(selectedMap, 1, selectedGroup, selectedSubgroup);
                }
                else if (strlen(selectedGroup) > 0)
                {
                    MultiMode_SetNextMap(selectedMap, 1, selectedGroup);
                }
                else
                {
                    MultiMode_SetNextMap(selectedMap, 1);
                }

                DataPack pack = new DataPack();
                pack.WriteString(selectedMap);
                pack.WriteString(selectedGroup);
                pack.WriteString(selectedSubgroup);
                CreateTimer(0.2, Timer_CallRandomCycleForward, pack);
                
                char mapDisplay[256];
                MultiMode_GetMapDisplayName(selectedGroup, selectedMap, selectedSubgroup, mapDisplay, sizeof(mapDisplay));
                
                if (strlen(selectedSubgroup) > 0)
                {
                    CPrintToChatAll("%t", "Random Cycle Map Selected With Subgroup", mapDisplay, selectedGroup, selectedSubgroup);
                }
                else if (strlen(selectedGroup) > 0)
                {
                    CPrintToChatAll("%t", "Random Cycle Map Selected With Group", mapDisplay, selectedGroup);
                }
                else
                {
                    CPrintToChatAll("%t", "Random Cycle Map Selected", mapDisplay);
                }
            }
        }
    }
}

public Action Timer_CallRandomCycleForward(Handle timer, DataPack pack)
{
    pack.Reset();
    
    char selectedMap[PLATFORM_MAX_PATH];
    char selectedGroup[64];
    char selectedSubgroup[64];
    
    pack.ReadString(selectedMap, sizeof(selectedMap));
    pack.ReadString(selectedGroup, sizeof(selectedGroup));
    pack.ReadString(selectedSubgroup, sizeof(selectedSubgroup));
    
    delete pack;
    
    Call_StartForward(g_OnRandomCycleMapSetForward);
    Call_PushString(selectedMap);
    Call_PushString(selectedGroup);
    Call_PushString(selectedSubgroup);
    Call_Finish();
    
    return Plugin_Stop;
}

public Action OnVGuiMenu_BfRead(UserMsg msg_id, BfRead msg, const int[] players, int playersNum, bool reliable, bool init)
{
    if (g_bIntermissionCalled)
    {
        return Plugin_Continue;
    }
    
    char type[10];
    msg.ReadString(type, sizeof(type));
    
    if (StrEqual(type, "scores", false))
    {
        if (msg.ReadByte() == 1 && msg.ReadByte() == 0)
        {
            g_bIntermissionCalled = true;
            Event_GameOver(null, "", false);
        }
    }
    
    return Plugin_Continue;
}

public Action OnVGuiMenu_Protobuf(UserMsg msg_id, Protobuf msg, const int[] players, int playersNum, bool reliable, bool init)
{
    if (g_bIntermissionCalled)
    {
        return Plugin_Continue;
    }
    
    char type[10];
    msg.ReadString("name", type, sizeof(type));
    
    if (StrEqual(type, "scores", false))
    {
        if (msg.ReadBool("show") && msg.GetRepeatedFieldCount("subkeys") == 0)
        {
            g_bIntermissionCalled = true;
            Event_GameOver(null, "", false);
        }
    }
    
    return Plugin_Continue;
}