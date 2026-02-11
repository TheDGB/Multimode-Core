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
    
    AutoExecConfig(true, "multimode_randomcycle");
    
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
            if (GetFeatureStatus(FeatureType_Native, "Protobuf.ReadString") == FeatureStatus_Available)
            {
                HookUserMessage(g_VGuiMenuId, OnVGuiMenu_Protobuf);
            }
            else
            {
                HookUserMessage(g_VGuiMenuId, OnVGuiMenu_BfRead);
            }
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

    ArrayList candidateGroups = new ArrayList(ByteCountToCells(64));
    ArrayList candidateSubgroups = new ArrayList(ByteCountToCells(64));

    ArrayList gamemodes = new ArrayList(ByteCountToCells(64));
    int gamemodeCount = Multimode_GetGamemodeList(gamemodes, false, false);

    for (int i = 0; i < gamemodeCount; i++)
    {
        char gamemode[64];
        gamemodes.GetString(i, gamemode, sizeof(gamemode));

        if (groupExclude > 0 && MultiMode_IsGamemodeRecentlyPlayed(gamemode, groupExclude))
            continue;

        char testMap[PLATFORM_MAX_PATH];
        if (MultiMode_GetRandomMap(gamemode, sizeof(gamemode), "", 0, testMap, sizeof(testMap)))
        {
            candidateGroups.PushString(gamemode);
            candidateSubgroups.PushString("");
        }

        ArrayList subgroups = new ArrayList(ByteCountToCells(64));
        int subgroupCount = Multimode_GetSubgroupList(gamemode, subgroups, false, false);
        for (int j = 0; j < subgroupCount; j++)
        {
            char subgroup[64];
            subgroups.GetString(j, subgroup, sizeof(subgroup));
            if (subgroupExclude > 0 && MultiMode_IsSubGroupRecentlyPlayed(gamemode, subgroup, subgroupExclude))
                continue;
            if (MultiMode_GetRandomMap(gamemode, sizeof(gamemode), subgroup, sizeof(subgroup), testMap, sizeof(testMap)))
            {
                candidateGroups.PushString(gamemode);
                candidateSubgroups.PushString(subgroup);
            }
        }
        delete subgroups;
    }
    delete gamemodes;

    char selectedGroup[64] = "";
    char selectedSubgroup[64] = "";
    char selectedMap[PLATFORM_MAX_PATH] = "";
    bool found = false;

    if (candidateGroups.Length > 0)
    {
        int idx = GetRandomInt(0, candidateGroups.Length - 1);
        candidateGroups.GetString(idx, selectedGroup, sizeof(selectedGroup));
        candidateSubgroups.GetString(idx, selectedSubgroup, sizeof(selectedSubgroup));

        for (int attempt = 0; attempt < 30 && !found; attempt++)
        {
            if (MultiMode_GetRandomMap(selectedGroup, sizeof(selectedGroup), selectedSubgroup, sizeof(selectedSubgroup), selectedMap, sizeof(selectedMap)))
            {
                if (mapExclude > 0 && MultiMode_IsMapRecentlyPlayed(selectedGroup, selectedMap, selectedSubgroup, mapExclude))
                    continue;
                found = true;
                break;
            }
        }
    }

    delete candidateGroups;
    delete candidateSubgroups;

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