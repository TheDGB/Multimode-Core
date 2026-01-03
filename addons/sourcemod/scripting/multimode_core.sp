/*****************************************************************************
                        Multi Mode Core English Version
******************************************************************************/

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <morecolors>
#include <adminmenu>
#include <nextmap>
#include <emitsoundany>
#include <clientprefs>
#include <multimode/base>
#include <multimode>
#include <multimode/utils>

public Plugin myinfo = 
{
    name = "[MMC] MultiMode Core",
    author = "Oppressive Territory",
    description = "Core plugin for MultiMode voting system",
    version = PLUGIN_VERSION,
    url = ""
}

// Gesture Defines
#define GESTURE_NOMINATED " (!)" // For nominated global gesture groups/maps
#define GESTURE_CURRENT " (*)"   // For Current global gesture group/map
#define GESTURE_VOTED " (#)"     // For Winning group/map global gesture from a previous vote

enum struct VoteManagerEntry {
    Function start_group;
    Function start_subgroup;
    Function start_map;
    Function cancel;
    Handle plugin;
}

// Convar Section
ConVar g_Cvar_CooldownEnabled;
ConVar g_Cvar_CooldownTime;
ConVar g_Cvar_Logs;
ConVar g_Cvar_MapCycleFile;
ConVar g_Cvar_Method;
ConVar g_Cvar_VoteGroupInVoteLimit;
ConVar g_Cvar_VoteDefaultInVoteLimit;
ConVar g_Cvar_VoteManager;
ConVar g_hCvarTimeLimit;

// Bool
bool g_bChangeMapNextRound;
bool g_bCooldownActive = false;
bool g_bCurrentVoteAdmin;
bool g_bGameEndTriggered = false;
bool g_bHasNominated[MAXPLAYERS+1];
bool g_bInternalChange = false;
bool g_bIsRunoffCooldown = false;
bool g_bIsRunoffVote = false;
bool g_bMapExtended = false;
bool g_bVoteActive;
bool g_bVoteCompleted = false;

// Array Section
ArrayList g_NominatedGamemodes;
ArrayList g_PlayedGamemodes;
ArrayList g_RunoffItems;
ArrayList g_PlayerNominations[MAXPLAYERS + 1];

// StringMap Section
StringMap g_NominatedMaps;
StringMap g_PlayedMaps;
StringMap g_VoteManagers;
StringMap g_VoteManagersBackup;
StringMap g_ActiveVoteConfigs;
AdvancedVoteConfig g_CurrentVoteConfig;

// TimingMode Section
TimingMode g_eVoteTiming;

// Vote Type
VoteType g_eCurrentNativeVoteType;
VoteType g_ePendingVoteType;

// Char Section
char g_sClientPendingSubGroup[MAXPLAYERS+1][64];
char g_sCurrentGameMode[128];
char g_sNextGameMode[128];
char g_sNextMap[PLATFORM_MAX_PATH];
char g_sNextSubGroup[64];
char g_sPendingCommand[256];
char g_sPendingVoteGamemode[64];
char g_sPendingVoteSubGroup[64];
char g_PreservedStartSound[PLATFORM_MAX_PATH];
char g_PreservedEndSound[PLATFORM_MAX_PATH];
char g_PreservedRunoffStartSound[PLATFORM_MAX_PATH];
char g_PreservedRunoffEndSound[PLATFORM_MAX_PATH];
char g_sVoteGameMode[64];
char g_sVoteMap[PLATFORM_MAX_PATH];
char g_sVoteSubGroup[64];
char g_sCurrentVoteId[64];

// Int Section
int g_iCooldownEndTime = 0;
int g_iRunoffVotesThisMap = 0;
int g_iGlobalMaxRunoffs = -1;
int g_iVoteInitiator = -1;
int g_iPendingVoteInitiator;

// Handle Section
Handle g_hCookieVoteType;
Handle g_hCooldownTimer = INVALID_HANDLE;
Handle g_hHudSync;
Handle g_OnGamemodeChangedForward;
Handle g_OnGamemodeChangedVoteForward;
Handle g_OnVoteEndForward;
Handle g_OnVoteStartExForward;
Handle g_OnVoteStartForward;

public void OnPluginStart() 
{
    LoadTranslations("multimode_voter.phrases");
    
    // Reg Console Commands
	
	RegConsoleCmd("multimode_version", Command_MultimodeVersion, "Displays the current Multimode Core version");
    
    // Reg Admin Commands
    RegAdminCmd("multimode_reload", Command_ReloadGamemodes, ADMFLAG_CONFIG, "Reloads gamemodes configuration");
    RegAdminCmd("multimode_setnextmap", Command_SetNextMap, ADMFLAG_CHANGEMAP, "Sets the next map. Usage: <map> <timing> [group] [subgroup]");
	RegAdminCmd("multimode_listrvm", Command_ListVoteManagers, ADMFLAG_GENERIC, "List of all registered vote managers.");
    RegAdminCmd("sm_setnextmap", Command_SetNextMap, ADMFLAG_CHANGEMAP, "Sets the next map. Usage: <map> <timing> [group] [subgroup]");
    RegAdminCmd("sm_votecancel", Command_CancelVote, ADMFLAG_VOTE, "Cancel the current MultiMode vote");
    RegAdminCmd("sm_mmcancelvote", Command_CancelVote, ADMFLAG_VOTE, "Cancel the current MultiMode vote");
	
    g_Cvar_MapCycleFile = CreateConVar("multimode_mapcycle", "mmc_mapcycle.txt", "Name of the map cycle file to use (search in addons/sourcemod/configs).");
    
    g_Cvar_CooldownEnabled = CreateConVar("multimode_cooldown", "1", "Enable or disable cooldown between votes", _, true, 0.0, true, 1.0);
    g_Cvar_CooldownTime = CreateConVar("multimode_cooldown_time", "10", "Cooldown time in seconds between votes", _, true, 0.0);
	
	// Old native votes cvar.
	// g_Cvar_NativeVotes = CreateConVar("multimode_nativevotes", "0", "Enable/disable NativeVotes support for votes (1 = Enabled, 0 = Disabled)", _, true, 0.0, true, 1.0);
	
    g_Cvar_VoteManager = CreateConVar("multimode_votemanager", "core", "The ID of the MM Vote Manager to use.");
    
	g_Cvar_VoteGroupInVoteLimit = CreateConVar("multimode_vote_group_invotelimit", "6", "Standard group limit in normal voting.");
	g_Cvar_VoteDefaultInVoteLimit = CreateConVar("multimode_vote_default_invotelimit", "6", "Default limit of items (maps/subgroups) if not defined in the config.");
    
    g_Cvar_Method = CreateConVar("multimode_method", "1", "Voting method: 1=Groups then maps, 2=Only groups (random map), 3=Only maps (all groups)", _, true, 1.0, true, 3.0);
    
    g_Cvar_Logs = CreateConVar("multimode_logs", "1", "Enables and disables Multimode Core logs, when enabled, a new file will be created in sourcemod/logs/MMC_YearMouthDay.txt and multimode core logs messages in server console.");

    g_PlayedGamemodes = new ArrayList(ByteCountToCells(128));
    g_PlayedMaps = new StringMap();
    g_RunoffItems = new ArrayList(ByteCountToCells(PLATFORM_MAX_PATH));
	
	g_VoteManagers = new StringMap();
	g_ActiveVoteConfigs = new StringMap();
	
    VoteManagerEntry coreEntry;
    coreEntry.start_group = Core_StartVote;
    coreEntry.start_subgroup = Core_StartVote;
    coreEntry.start_map = Core_StartVote;
    coreEntry.cancel = Core_CancelVote;
    coreEntry.plugin = GetMyHandle();
    g_VoteManagers.SetArray("core", coreEntry, sizeof(coreEntry));
    
    g_hCookieVoteType = RegClientCookie("multimode_votetype", "Selected voting type", CookieAccess_Private);
    
    AutoExecConfig(true, "multimode_core");
    
    LoadGameModesConfig();
	g_VoteManagersBackup = new StringMap();
    
    ConVar nextmap = FindConVar("sm_nextmap");
    if (nextmap != null)
    {
        char currentMap[PLATFORM_MAX_PATH];
        GetCurrentMap(currentMap, sizeof(currentMap));
        
        char nextMapValue[PLATFORM_MAX_PATH];
        nextmap.GetString(nextMapValue, sizeof(nextMapValue));
        
        if (StrEqual(nextMapValue, currentMap))
        {
            nextmap.SetString("");
        }
    }
	
	// Forwards
    g_OnVoteStartForward = CreateGlobalForward("MultiMode_OnVoteStart", ET_Ignore, Param_Cell);
    g_OnVoteStartExForward = CreateGlobalForward("MultiMode_OnVoteStartEx", ET_Ignore, Param_Cell, Param_Cell, Param_Cell);
    g_OnVoteEndForward = CreateGlobalForward("MultiMode_OnVoteEnd", ET_Ignore, Param_String, Param_String, Param_String, Param_Cell);
    g_OnGamemodeChangedForward = CreateGlobalForward("MultiMode_OnGamemodeChanged", ET_Ignore, Param_String, Param_String, Param_String, Param_Cell);
    g_OnGamemodeChangedVoteForward = CreateGlobalForward("MultiMode_OnGamemodeChangedVote", ET_Ignore, Param_String, Param_String, Param_String, Param_Cell);
    
    g_hCvarTimeLimit = FindConVar("mp_timelimit");
    g_NominatedGamemodes = new ArrayList(ByteCountToCells(128));
    g_NominatedMaps = new StringMap();
    g_hHudSync = CreateHudSynchronizer();
    
    // Hooks
    HookConVarChange(g_hCvarTimeLimit, OnTimelimitChanged);
    
    HookEvent("round_end",            Event_RoundEnd);
    HookEventEx("game_end", Event_GameOver);
    HookEventEx("round_end", Event_GameOver);
    HookEventEx("game_round_end",     Event_RoundEnd);
    HookEventEx("teamplay_win_panel", Event_RoundEnd);
    HookEventEx("arena_win_panel",    Event_RoundEnd);
    HookEventEx("game_round_win",    Event_RoundEnd);
    HookEventEx("round_win",          Event_RoundEnd);
    HookEventEx("game_end",           Event_RoundEnd);
    HookEventEx("game_round_restart", Event_RoundEnd);
    
    HookEvent("server_spawn", Event_ServerSpawn, EventHookMode_PostNoCopy);
    
    TopMenu topmenu;
    if (LibraryExists("adminmenu") && ((topmenu = GetAdminTopMenu()) != null))
    {
        OnAdminMenuReady(topmenu);
    }
	
    for (int i = 0; i <= MAXPLAYERS; i++)
    {
        g_PlayerNominations[i] = new ArrayList(sizeof(NominationInfo));
    }
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    CreateNative("Multimode_StartVote", NativeMMC_StartVoteAdvanced);
    CreateNative("MultiMode_StartVote", NativeMMC_StartVote);  // Keep old native for backwards compatibility...
    CreateNative("MultiMode_StopVote", NativeMMC_StopVote);
    CreateNative("MultiMode_CanStopVote", NativeMMC_CanStopVote);
    CreateNative("MultiMode_IsVoteActive", NativeMMC_IsVoteActive);
    CreateNative("MultiMode_IsCooldownActive", NativeMMC_IsCooldownActive);
    CreateNative("MultiMode_IsVoteCompleted", NativeMMC_IsVoteCompleted);
    CreateNative("MultiMode_GetCurrentGameMode", NativeMMC_GetCurrentGameMode);
    CreateNative("MultiMode_GetNextMap", NativeMMC_GetNextMap);
    CreateNative("MultiMode_GetCurrentMap", NativeMMC_GetCurrentMap);
    CreateNative("MultiMode_Nominate", NativeMMC_Nominate);
    CreateNative("MultiMode_GetNextGameMode", NativeMMC_GetNextGameMode);
    CreateNative("MultiMode_IsRandomCycleEnabled", NativeMMC_IsRandomCycleEnabled);
	CreateNative("MultiMode_GetRandomMap", NativeMMC_GetRandomMap);
	CreateNative("MultiMode_IsGroupNominated", NativeMMC_IsGroupNominated);
	CreateNative("MultiMode_IsMapNominated", NativeMMC_IsMapNominated);
	CreateNative("MultiMode_RegisterVoteManager", NativeMMC_RegisterVoteManager);
	CreateNative("MultiMode_RegisterVoteManagerEx", NativeMMC_RegisterVoteManagerEx);
	CreateNative("MultiMode_UnregisterVoteManager", NativeMMC_UnregisterVoteManager);
	CreateNative("MultiMode_ReportVoteResults", NativeMMC_ReportVoteResults);
	CreateNative("Multimode_GetGamemodeList", NativeMMC_GetGamemodeList);
	CreateNative("Multimode_GetSubgroupList", NativeMMC_GetSubgroupList);
	CreateNative("Multimode_GetMapList", NativeMMC_GetMapList);
	CreateNative("MultiMode_RemoveNomination", NativeMMC_RemoveNomination);
	CreateNative("MultiMode_RemoveAllNominations", NativeMMC_RemoveAllNominations);
	CreateNative("MultiMode_GetClientNominationCount", NativeMMC_GetClientNominationCount);
	CreateNative("MultiMode_GetClientNomination", NativeMMC_GetClientNomination);
	CreateNative("MultiMode_GetMapDisplayName", NativeMMC_GetMapDisplayName);
	CreateNative("MultiMode_IsGamemodeRecentlyPlayed", NativeMMC_IsGamemodeRecentlyPlayed);
	CreateNative("MultiMode_IsMapRecentlyPlayed", NativeMMC_IsMapRecentlyPlayed);
	CreateNative("MultiMode_IsSubGroupRecentlyPlayed", NativeMMC_IsSubGroupRecentlyPlayed);
	CreateNative("MultiMode_GetCurrentVoteId", NativeMMC_GetCurrentVoteId);
	CreateNative("MultiMode_SetNextMap", NativeMMC_SetNextMap);
    
    RegPluginLibrary("multimode_core");
    return APLRes_Success;
}

public void OnConfigsExecuted()
{
    delete g_kvGameModes;
    g_kvGameModes = new KeyValues("Mapcycle");
    
    char configPath[PLATFORM_MAX_PATH];
    char mapcycleFile[PLATFORM_MAX_PATH];
    
    g_Cvar_MapCycleFile.GetString(mapcycleFile, sizeof(mapcycleFile));
    BuildPath(Path_SM, configPath, sizeof(configPath), "configs/%s", mapcycleFile);
    
    if (!g_kvGameModes.ImportFromFile(configPath))
    {
        MMC_WriteToLogFile(g_Cvar_Logs, "Falha ao carregar %s", mapcycleFile);
        return;
    }
    
    g_kvGameModes.Rewind();
    
    if (g_kvGameModes.GotoFirstSubKey(false))
    {
        do
        {
            char gamemodeName[64];
            g_kvGameModes.GetSectionName(gamemodeName, sizeof(gamemodeName));
            
            if (g_kvGameModes.JumpToKey("maps"))
            {
                if (g_kvGameModes.GotoFirstSubKey(false))
                {
                    do
                    {
                        char mapName[PLATFORM_MAX_PATH];
                        g_kvGameModes.GetSectionName(mapName, sizeof(mapName));
                        
                        if (StrContains(mapName, "workshop/") == 0)
                        {
                            char displayName[128];
                            g_kvGameModes.GetString(MAPCYCLE_KEY_DISPLAY, displayName, sizeof(displayName), "");
                        }
                    } while (g_kvGameModes.GotoNextKey(false));
                    g_kvGameModes.GoBack();
                }
                g_kvGameModes.GoBack();
            }
        } while (g_kvGameModes.GotoNextKey(false));
        g_kvGameModes.GoBack();
    }
    
    g_kvGameModes.Rewind();
}

public void OnMapStart()
{
    char CurrentMap[64];
    GetCurrentMap(CurrentMap, sizeof(CurrentMap));
    bool groupFound = false;
    bool subgroupFound = false;
    char foundSubGroup[64] = "";
    
    MMC_WriteToLogFile(g_Cvar_Logs, "[MultiMode Core] --------------- CURRENT MAP: %s ---------------", CurrentMap);

    if (strlen(g_sNextGameMode) > 0)
    {
        int index = MMC_FindGameModeIndex(g_sNextGameMode);
        if (index != -1)
        {
            GameModeConfig config;
            ArrayList list = GetGameModesList();
            list.GetArray(index, config);
        
            MMC_WriteToLogFile(g_Cvar_Logs, "[MultiMode Core] Using preselected gamemode: %s", config.name);
            
            if (strlen(config.config) > 0)
            {
                MMC_WriteToLogFile(g_Cvar_Logs, "[MultiMode Core] Executing group config: %s", config.config);
                ServerCommand("exec %s", config.config);
            }
            
            if (strlen(g_sNextSubGroup) > 0)
            {
                int subgroupIndex = MMC_FindSubGroupIndex(g_sNextGameMode, g_sNextSubGroup);
                if (subgroupIndex != -1)
                {
                    SubGroupConfig subConfig;
                    config.subGroups.GetArray(subgroupIndex, subConfig);
                    
                    if (strlen(subConfig.config) > 0)
                    {
                        MMC_WriteToLogFile(g_Cvar_Logs, "[MultiMode Core] Executing subgroup config: %s", subConfig.config);
                        ServerCommand("exec %s", subConfig.config);
                    }
                    
                    KeyValues kv = GetSubGroupMapKv(config.name, g_sNextSubGroup, CurrentMap);
                    if (kv != null)
                    {
                        char mapConfig[256];
                        kv.GetString(MAPCYCLE_KEY_CONFIG, mapConfig, sizeof(mapConfig), "");
                        if (strlen(mapConfig) > 0)
                        {
                            MMC_WriteToLogFile(g_Cvar_Logs, "[MultiMode Core] Executing subgroup map config: %s", mapConfig);
                            ServerCommand("exec %s", mapConfig);
                        }
                        
                        char mapCommand[256];
                        kv.GetString(MAPCYCLE_KEY_COMMAND, mapCommand, sizeof(mapCommand), "");
                        
                        if (strlen(mapCommand) > 0)
                        {
                            MMC_WriteToLogFile(g_Cvar_Logs, "[MultiMode Core] Executing subgroup map command: %s", mapCommand);
                            ServerCommand("%s", mapCommand);
                        }
                        delete kv;
                    }
                }
            }
            
            KeyValues kv = GetMapKv(config.name, CurrentMap);
            if (kv != null)
            {
                char mapConfig[256];
                kv.GetString(MAPCYCLE_KEY_CONFIG, mapConfig, sizeof(mapConfig), "");
                if (strlen(mapConfig) > 0)
                {
                    MMC_WriteToLogFile(g_Cvar_Logs, "[MultiMode Core] Executing map config: %s", mapConfig);
                    ServerCommand("exec %s", mapConfig);
                }

                char mapCommand[256];
                kv.GetString(MAPCYCLE_KEY_COMMAND, mapCommand, sizeof(mapCommand), "");
                delete kv;
            }
            
            if (g_kvGameModes.JumpToKey(config.name) && g_kvGameModes.JumpToKey("maps"))
            {
                if (g_kvGameModes.GotoFirstSubKey(false))
                {
                    do
                    {
                        char mapKey[PLATFORM_MAX_PATH];
                        g_kvGameModes.GetSectionName(mapKey, sizeof(mapKey));

                        if (MMC_IsWildcardEntry(mapKey) && StrContains(CurrentMap, mapKey) == 0)
                        {
                            char wildcardConfig[256];
                            g_kvGameModes.GetString(MAPCYCLE_KEY_CONFIG, wildcardConfig, sizeof(wildcardConfig), "");
                            if (strlen(wildcardConfig) > 0)
                            {
                                MMC_WriteToLogFile(g_Cvar_Logs, "[MultiMode Core] Executing wildcard config (%s): %s", mapKey, wildcardConfig);
                                ServerCommand("exec %s", wildcardConfig);
                            }
                            
                            char wildcardCommand[256];
                            g_kvGameModes.GetString(MAPCYCLE_KEY_COMMAND, wildcardCommand, sizeof(wildcardCommand), "");
                            
                            if (strlen(wildcardCommand) > 0)
                            {
                                MMC_WriteToLogFile(g_Cvar_Logs, "[MultiMode Core] Executing wildcard command (%s): %s", mapKey, wildcardCommand);
                                ServerCommand("%s", wildcardCommand);
                            }
                        }
                    } while (g_kvGameModes.GotoNextKey(false));
                    g_kvGameModes.GoBack();
                }
                g_kvGameModes.GoBack();
            }
            g_kvGameModes.Rewind();
        }
        
        if (strlen(g_sNextSubGroup) > 0)
        {
            char tempGameMode[128];
            Format(tempGameMode, sizeof(tempGameMode), "%s/%s", g_sNextGameMode, g_sNextSubGroup);
            strcopy(g_sCurrentGameMode, sizeof(g_sCurrentGameMode), tempGameMode);
        }
        else
        {
            strcopy(g_sCurrentGameMode, sizeof(g_sCurrentGameMode), g_sNextGameMode);
        }
        
        g_sNextGameMode[0] = '\0';
        g_sNextSubGroup[0] = '\0';
    }
    else
    {
        ArrayList gameModes = GetGameModesList();
        
        for (int i = 0; i < gameModes.Length; i++)
        {
            GameModeConfig config;
            gameModes.GetArray(i, config);

            for (int j = 0; j < config.subGroups.Length; j++)
            {
                SubGroupConfig subConfig;
                config.subGroups.GetArray(j, subConfig);
                
                if (subConfig.maps.FindString(CurrentMap) != -1)
                {
                    groupFound = true;
                    subgroupFound = true;
                    strcopy(g_sCurrentGameMode, sizeof(g_sCurrentGameMode), config.name);
                    strcopy(foundSubGroup, sizeof(foundSubGroup), subConfig.name);
                    
                    MMC_WriteToLogFile(g_Cvar_Logs, "[MultiMode Core] Group found with subgroup: %s (SubGroup: %s)", config.name, subConfig.name);

                    if (strlen(config.config) > 0)
                    {
                        MMC_WriteToLogFile(g_Cvar_Logs, "[MultiMode Core] Executing group config: %s", config.config);
                        ServerCommand("exec %s", config.config);
                    }
                    
                    if (strlen(subConfig.config) > 0)
                    {
                        MMC_WriteToLogFile(g_Cvar_Logs, "[MultiMode Core] Executing subgroup config: %s", subConfig.config);
                        ServerCommand("exec %s", subConfig.config);
                    }

                    KeyValues kv = GetSubGroupMapKv(config.name, subConfig.name, CurrentMap);
                    if (kv != null)
                    {
                        char mapConfig[256];
                        kv.GetString(MAPCYCLE_KEY_CONFIG, mapConfig, sizeof(mapConfig), "");
                        if (strlen(mapConfig) > 0)
                        {
                            MMC_WriteToLogFile(g_Cvar_Logs, "[MultiMode Core] Executing subgroup map config: %s", mapConfig);
                            ServerCommand("exec %s", mapConfig);
                        }
                        
                        char mapCommand[256];
                        kv.GetString(MAPCYCLE_KEY_COMMAND, mapCommand, sizeof(mapCommand), "");
                        
                        if (strlen(mapCommand) > 0)
                        {
                            MMC_WriteToLogFile(g_Cvar_Logs, "[MultiMode Core] Executing subgroup map command: %s", mapCommand);
                            ServerCommand("%s", mapCommand);
                        }
                        delete kv;
                    }

                    break;
                }
            }
            
            if (subgroupFound) break;

            if (config.maps.FindString(CurrentMap) != -1)
            {
                groupFound = true;
                strcopy(g_sCurrentGameMode, sizeof(g_sCurrentGameMode), config.name);
                MMC_WriteToLogFile(g_Cvar_Logs, "[MultiMode Core] Group found: %s", config.name);

                if (strlen(config.config) > 0)
                {
                    MMC_WriteToLogFile(g_Cvar_Logs, "[MultiMode Core] Executing group config: %s", config.config);
                    ServerCommand("exec %s", config.config);
                }

                KeyValues kv = GetMapKv(config.name, CurrentMap);
                if (kv != null)
                {
                    char mapConfig[256];
                    kv.GetString(MAPCYCLE_KEY_CONFIG, mapConfig, sizeof(mapConfig), "");
                    if (strlen(mapConfig) > 0)
                    {
                        MMC_WriteToLogFile(g_Cvar_Logs, "[MultiMode Core] Executing map config: %s", mapConfig);
                        ServerCommand("exec %s", mapConfig);
                    }
                    
                    char mapCommand[256];
                    kv.GetString(MAPCYCLE_KEY_COMMAND, mapCommand, sizeof(mapCommand), "");
                    delete kv;
                }
                
                if (g_kvGameModes.JumpToKey(config.name) && g_kvGameModes.JumpToKey("maps"))
                {
                    if (g_kvGameModes.GotoFirstSubKey(false))
                    {
                        do
                        {
                            char mapKey[PLATFORM_MAX_PATH];
                            g_kvGameModes.GetSectionName(mapKey, sizeof(mapKey));

                            if (MMC_IsWildcardEntry(mapKey) && StrContains(CurrentMap, mapKey) == 0)
                            {
                                char wildcardConfig[256];
                                g_kvGameModes.GetString(MAPCYCLE_KEY_CONFIG, wildcardConfig, sizeof(wildcardConfig), "");
                                if (strlen(wildcardConfig) > 0)
                                {
                                    MMC_WriteToLogFile(g_Cvar_Logs, "[MultiMode Core] Executing wildcard config (%s): %s", mapKey, wildcardConfig);
                                    ServerCommand("exec %s", wildcardConfig);
                                }
                                
                                char wildcardCommand[256];
                                g_kvGameModes.GetString(MAPCYCLE_KEY_COMMAND, wildcardCommand, sizeof(wildcardCommand), "");
                                
                                if (strlen(wildcardCommand) > 0)
                                {
                                    MMC_WriteToLogFile(g_Cvar_Logs, "[MultiMode Core] Executing wildcard command (%s): %s", mapKey, wildcardCommand);
                                    ServerCommand("%s", wildcardCommand);
                                }
                            }
                        } while (g_kvGameModes.GotoNextKey(false));
                        g_kvGameModes.GoBack();
                    }
                    g_kvGameModes.GoBack();
                }
                g_kvGameModes.Rewind();
                
                break;
            }
        }
    }
	
    if (subgroupFound)
    {
        char tempGameMode[128];
        Format(tempGameMode, sizeof(tempGameMode), "%s/%s", g_sCurrentGameMode, foundSubGroup);
        strcopy(g_sCurrentGameMode, sizeof(g_sCurrentGameMode), tempGameMode);
    }

    if (!groupFound)
    {
        // Cleaning...
    }
    
    g_bMapExtended = false;
    g_bVoteCompleted = false;

    g_bCooldownActive = false;
    g_iCooldownEndTime = 0;
    delete g_hCooldownTimer;

    g_NominatedGamemodes.Clear();
    g_NominatedMaps.Clear();

    g_sNextGameMode[0] = '\0';
    g_sNextMap[0] = '\0';
    g_bVoteActive = false;

    g_iRunoffVotesThisMap = 0;
    g_iGlobalMaxRunoffs = -1;

    MMC_UpdateCurrentGameMode(CurrentMap, g_sCurrentGameMode, sizeof(g_sCurrentGameMode), g_sCurrentGameMode);
	
    char currentMap[PLATFORM_MAX_PATH];
    GetCurrentMap(currentMap, sizeof(currentMap));

    if (strlen(g_sCurrentGameMode) > 0) {
        if (g_PlayedGamemodes.FindString(g_sCurrentGameMode) == -1) {
            g_PlayedGamemodes.PushString(g_sCurrentGameMode);
        }
    
        int maxGroups = 0;
        if (maxGroups > 0 && g_PlayedGamemodes.Length > maxGroups) {
            g_PlayedGamemodes.Erase(0);
        }

        ArrayList playedMaps;
        if (!g_PlayedMaps.GetValue(g_sCurrentGameMode, playedMaps)) {
            playedMaps = new ArrayList(ByteCountToCells(PLATFORM_MAX_PATH));
            g_PlayedMaps.SetValue(g_sCurrentGameMode, playedMaps);
        }
    
        if (playedMaps.FindString(currentMap) == -1) {
            playedMaps.PushString(currentMap);
        }

        int maxMaps = 0;
        if (maxMaps > 0 && playedMaps.Length > maxMaps) {
            playedMaps.Erase(0);
        }
    }

    for (int i = 1; i <= MaxClients; i++)
    {
        g_bHasNominated[i] = false;
    }
	
    for (int i = 1; i <= MaxClients; i++)
    {
        g_bHasNominated[i] = false;
        if (g_PlayerNominations[i] != null)
        {
            g_PlayerNominations[i].Clear();
        }
    }

    g_bGameEndTriggered = false;
}

public void OnClientDisconnect(int client)
{
    if (g_PlayerNominations[client] != null && g_PlayerNominations[client].Length > 0)
    {
        RemoveAllClientNominations(client, false);
    }
	
	g_sClientPendingSubGroup[client][0] = '\0';
}

public void LoadGameModesConfig()
{
    delete g_kvGameModes;
    g_kvGameModes = new KeyValues("Mapcycle");
    
    char configPath[PLATFORM_MAX_PATH];
    char mapcycleFile[PLATFORM_MAX_PATH];
    
    g_Cvar_MapCycleFile.GetString(mapcycleFile, sizeof(mapcycleFile));
    BuildPath(Path_SM, configPath, sizeof(configPath), "configs/%s", mapcycleFile);
    
    if (!g_kvGameModes.ImportFromFile(configPath))
    {
        MMC_WriteToLogFile(g_Cvar_Logs, "Failed to load %s", mapcycleFile);
        return;
    }

    ArrayList gameModes = GetGameModesList();
    if (gameModes != null) {
        gameModes.Clear();
    } else {
        LogError("GameModes list handle was invalid during config load.");
        return; 
    }
    
    if (g_kvGameModes.GotoFirstSubKey(false))
    {
        do
        {
            GameModeConfig config;
            g_kvGameModes.GetSectionName(config.name, sizeof(config.name));
            
            config.enabled = g_kvGameModes.GetNum("enabled", 1);
            config.adminonly = g_kvGameModes.GetNum("adminonly", 0);
            config.minplayers = g_kvGameModes.GetNum(MAPCYCLE_KEY_MINPLAYERS, 0);
            config.maxplayers = g_kvGameModes.GetNum(MAPCYCLE_KEY_MAXPLAYERS, 0);

            char time_buffer[8];
            g_kvGameModes.GetString(MAPCYCLE_KEY_MINTIME, time_buffer, sizeof(time_buffer), "-1");
            config.mintime = StringToInt(time_buffer);
            g_kvGameModes.GetString(MAPCYCLE_KEY_MAXTIME, time_buffer, sizeof(time_buffer), "-1");
            config.maxtime = StringToInt(time_buffer);
            
            g_kvGameModes.GetString(MAPCYCLE_KEY_COMMAND, config.command, sizeof(config.command), "");
            g_kvGameModes.GetString(MAPCYCLE_KEY_PRE_COMMAND, config.pre_command, sizeof(config.pre_command), "");
            g_kvGameModes.GetString(MAPCYCLE_KEY_VOTE_COMMAND, config.vote_command, sizeof(config.vote_command), "");
            g_kvGameModes.GetString(MAPCYCLE_KEY_CONFIG, config.config, sizeof(config.config), "");
            g_kvGameModes.GetString(MAPCYCLE_KEY_NOMINATE_FLAGS, config.nominate_flags, sizeof(config.nominate_flags), "");
            
            if (strlen(config.command) == 0 && g_kvGameModes.JumpToKey("serverconfig"))
            {
                g_kvGameModes.GetString(MAPCYCLE_KEY_COMMAND, config.command, sizeof(config.command), "");
                g_kvGameModes.GoBack();
            }
            
            config.maps = new ArrayList(ByteCountToCells(PLATFORM_MAX_PATH));
            if (g_kvGameModes.JumpToKey("maps"))
            {
                config.maps_invote = g_kvGameModes.GetNum(MAPCYCLE_KEY_MAPS_INVOTE, -1);
                
                if (g_kvGameModes.GotoFirstSubKey(false))
                {
                    StringMap uniqueMaps = new StringMap();
                    
                    do
                    {
                        char mapKey[PLATFORM_MAX_PATH];
                        g_kvGameModes.GetSectionName(mapKey, sizeof(mapKey));
                        
                        if (MMC_IsWildcardEntry(mapKey))
                        {
                            ArrayList wildcardMaps = new ArrayList(ByteCountToCells(PLATFORM_MAX_PATH));
                            MMC_ExpandWildcardMaps(mapKey, wildcardMaps);
                            
                            for (int i = 0; i < wildcardMaps.Length; i++)
                            {
                                char mapName[PLATFORM_MAX_PATH];
                                wildcardMaps.GetString(i, mapName, sizeof(mapName));
                                
                                if (!uniqueMaps.ContainsKey(mapName))
                                {
                                    config.maps.PushString(mapName);
                                    uniqueMaps.SetValue(mapName, true);
                                }
                            }
                            delete wildcardMaps;
                        }
                        else if (IsMapValid(mapKey))
                        {
                            if (!uniqueMaps.ContainsKey(mapKey))
                            {
                                config.maps.PushString(mapKey);
                                uniqueMaps.SetValue(mapKey, true);
                            }
                        }
                    } while (g_kvGameModes.GotoNextKey(false));
                    
                    delete uniqueMaps;
                    g_kvGameModes.GoBack();
                }
                g_kvGameModes.GoBack();
            }
            
            config.subGroups = new ArrayList(sizeof(SubGroupConfig));
            if (g_kvGameModes.JumpToKey("subgroup"))
            {
                config.subgroups_invote = g_kvGameModes.GetNum(MAPCYCLE_KEY_SUBGROUPS_INVOTE, -1);
                
                if (g_kvGameModes.GotoFirstSubKey(false))
                {
                    do
                    {
                        char sectionName[64];
                        g_kvGameModes.GetSectionName(sectionName, sizeof(sectionName));

                        if (StrEqual(sectionName, "subgroups_invote", false))
                        {
                            continue;
                        }
						
                        SubGroupConfig subConfig;
                        g_kvGameModes.GetSectionName(subConfig.name, sizeof(subConfig.name));
                        
                        subConfig.enabled = g_kvGameModes.GetNum("enabled", 1);
                        subConfig.adminonly = g_kvGameModes.GetNum("adminonly", 0);
                        subConfig.minplayers = g_kvGameModes.GetNum(MAPCYCLE_KEY_MINPLAYERS, 0);
                        subConfig.maxplayers = g_kvGameModes.GetNum(MAPCYCLE_KEY_MAXPLAYERS, 0);
                        subConfig.maps_invote = g_kvGameModes.GetNum(MAPCYCLE_KEY_MAPS_INVOTE, -1);

                        g_kvGameModes.GetString(MAPCYCLE_KEY_MINTIME, time_buffer, sizeof(time_buffer), "-1");
                        subConfig.mintime = StringToInt(time_buffer);
                        g_kvGameModes.GetString(MAPCYCLE_KEY_MAXTIME, time_buffer, sizeof(time_buffer), "-1");
                        subConfig.maxtime = StringToInt(time_buffer);
                        
                        g_kvGameModes.GetString(MAPCYCLE_KEY_COMMAND, subConfig.command, sizeof(subConfig.command), "");
                        g_kvGameModes.GetString(MAPCYCLE_KEY_PRE_COMMAND, subConfig.pre_command, sizeof(subConfig.pre_command), "");
                        g_kvGameModes.GetString(MAPCYCLE_KEY_VOTE_COMMAND, subConfig.vote_command, sizeof(subConfig.vote_command), "");
                        g_kvGameModes.GetString(MAPCYCLE_KEY_CONFIG, subConfig.config, sizeof(subConfig.config), "");
                        g_kvGameModes.GetString(MAPCYCLE_KEY_NOMINATE_FLAGS, subConfig.nominate_flags, sizeof(subConfig.nominate_flags), "");
                        
                        subConfig.maps = new ArrayList(ByteCountToCells(PLATFORM_MAX_PATH));
                        
                        if (g_kvGameModes.JumpToKey("maps"))
                        {
                            if (g_kvGameModes.GotoFirstSubKey(false))
                            {
                                StringMap uniqueSubMaps = new StringMap();
                                
                                do
                                {
                                    char mapKey[PLATFORM_MAX_PATH];
                                    g_kvGameModes.GetSectionName(mapKey, sizeof(mapKey));
                                    
                                    if (MMC_IsWildcardEntry(mapKey))
                                    {
                                        ArrayList wildcardMaps = new ArrayList(ByteCountToCells(PLATFORM_MAX_PATH));
                                        MMC_ExpandWildcardMaps(mapKey, wildcardMaps);
                                        
                                        for (int i = 0; i < wildcardMaps.Length; i++)
                                        {
                                            char mapName[PLATFORM_MAX_PATH];
                                            wildcardMaps.GetString(i, mapName, sizeof(mapName));
                                            
                                            if (!uniqueSubMaps.ContainsKey(mapName))
                                            {
                                                subConfig.maps.PushString(mapName);
                                                uniqueSubMaps.SetValue(mapName, true);
                                            }
                                        }
                                        delete wildcardMaps;
                                    }
                                    else if (IsMapValid(mapKey))
                                    {
                                        if (!uniqueSubMaps.ContainsKey(mapKey))
                                        {
                                            subConfig.maps.PushString(mapKey);
                                            uniqueSubMaps.SetValue(mapKey, true);
                                        }
                                    }
                                } while (g_kvGameModes.GotoNextKey(false));
                                
                                delete uniqueSubMaps;
                                g_kvGameModes.GoBack();
                            }
                            g_kvGameModes.GoBack();
                        }
                        
                        config.subGroups.PushArray(subConfig);
                    } while (g_kvGameModes.GotoNextKey(false));
                    g_kvGameModes.GoBack();
                }
                g_kvGameModes.GoBack();
            }
            
            gameModes.PushArray(config);
        } while (g_kvGameModes.GotoNextKey(false));
    }
    
    OnGamemodeConfigLoaded();
    
    g_kvGameModes.Rewind();
}

// This is NOT a public API, its only used internally by the natives...
bool BuildVote(int initiator, AdvancedVoteConfig config)
{
    if (g_bVoteActive || g_bCooldownActive)
    {
        return false;
    }
    
    if (config.startSound[0] == '\0')
    {
        if (g_PreservedStartSound[0] != '\0')
        {
            strcopy(config.startSound, sizeof(config.startSound), g_PreservedStartSound);
        }
        else if (g_CurrentVoteConfig.startSound[0] != '\0')
        {
            strcopy(config.startSound, sizeof(config.startSound), g_CurrentVoteConfig.startSound);
        }
    }
    if (config.endSound[0] == '\0')
    {
        if (g_PreservedEndSound[0] != '\0')
        {
            strcopy(config.endSound, sizeof(config.endSound), g_PreservedEndSound);
        }
        else if (g_CurrentVoteConfig.endSound[0] != '\0')
        {
            strcopy(config.endSound, sizeof(config.endSound), g_CurrentVoteConfig.endSound);
        }
    }
    if (config.runoffstartSound[0] == '\0')
    {
        if (g_PreservedRunoffStartSound[0] != '\0')
        {
            strcopy(config.runoffstartSound, sizeof(config.runoffstartSound), g_PreservedRunoffStartSound);
        }
        else if (g_CurrentVoteConfig.runoffstartSound[0] != '\0')
        {
            strcopy(config.runoffstartSound, sizeof(config.runoffstartSound), g_CurrentVoteConfig.runoffstartSound);
        }
    }
    if (config.runoffendSound[0] == '\0')
    {
        if (g_PreservedRunoffEndSound[0] != '\0')
        {
            strcopy(config.runoffendSound, sizeof(config.runoffendSound), g_PreservedRunoffEndSound);
        }
        else if (g_CurrentVoteConfig.runoffendSound[0] != '\0')
        {
            strcopy(config.runoffendSound, sizeof(config.runoffendSound), g_CurrentVoteConfig.runoffendSound);
        }
    }
    
    NativeMMC_OnVoteStart(initiator);
    
    int voteTypeEx = 0;
    switch (config.voteType)
    {
        case VOTE_TYPE_GROUP: voteTypeEx = 0;
        case VOTE_TYPE_SUBGROUP: voteTypeEx = 1;
        case VOTE_TYPE_MAP: voteTypeEx = 2;
        case VOTE_TYPE_SUBGROUP_MAP: voteTypeEx = 4;
    }
    NativeMMC_OnVoteStartEx(initiator, voteTypeEx, config.runoffItems != null);
    
    g_bCurrentVoteAdmin = config.adminvote;
    g_bIsRunoffVote = (config.runoffItems != null);
    
    g_eVoteTiming = config.timing;
    
    if (config.voteType == VOTE_TYPE_GROUP && config.maxRunoffs > 0 && g_iGlobalMaxRunoffs == -1)
    {
        g_iGlobalMaxRunoffs = config.maxRunoffs;
    }
    
    g_CurrentVoteConfig = config;
    
    if (config.startSound[0] != '\0')
    {
        strcopy(g_PreservedStartSound, sizeof(g_PreservedStartSound), config.startSound);
    }
    if (config.endSound[0] != '\0')
    {
        strcopy(g_PreservedEndSound, sizeof(g_PreservedEndSound), config.endSound);
    }
    if (config.runoffstartSound[0] != '\0')
    {
        strcopy(g_PreservedRunoffStartSound, sizeof(g_PreservedRunoffStartSound), config.runoffstartSound);
    }
    if (config.runoffendSound[0] != '\0')
    {
        strcopy(g_PreservedRunoffEndSound, sizeof(g_PreservedRunoffEndSound), config.runoffendSound);
    }
    
    ArrayList voteItems = null;
    switch (config.voteType)
    {
        case VOTE_TYPE_GROUP:
        {
            voteItems = PrepareVoteItems_Group(config, config.runoffItems);
        }
        case VOTE_TYPE_SUBGROUP:
        {
            voteItems = PrepareVoteItems_SubGroup(config, config.contextInfo, config.runoffItems);
        }
        case VOTE_TYPE_MAP:
        {
            voteItems = PrepareVoteItems_Map(config, config.contextInfo, config.runoffItems);
        }
        case VOTE_TYPE_SUBGROUP_MAP:
        {
            char parts[2][64];
            ExplodeString(config.contextInfo, "/", parts, 2, 64);
            voteItems = PrepareVoteItems_SubGroupMap(config, parts[0], parts[1], config.runoffItems);
        }
    }
    
    if (voteItems == null || voteItems.Length == 0)
    {
        if (voteItems != null) delete voteItems;
        return false;
    }
    
    bool canExtend = (!g_bMapExtended) && MMC_CanExtendMap();
    bool isFirstVote = false;
    
    switch (config.type)
    {
        case VOTE_TYPE_GROUPS_THEN_MAPS, VOTE_TYPE_GROUPS_ONLY:
        {
            isFirstVote = (config.voteType == VOTE_TYPE_GROUP);
        }
        case VOTE_TYPE_MAPS_ONLY:
        {
            isFirstVote = (config.voteType == VOTE_TYPE_MAP);
        }
    }
    
    if (config.extendOption && canExtend && config.runoffItems == null && isFirstVote)
    {
        VoteCandidate item;
        strcopy(item.info, sizeof(item.info), "Extend Map");
        int timestep = (config.timestep > 0) ? config.timestep : 6;
        Format(item.name, sizeof(item.name), "%t", "Extend Map Normal Vote", timestep);
        voteItems.ShiftUp(0);
        voteItems.SetArray(0, item);
    }
    
    strcopy(g_sVoteGameMode, sizeof(g_sVoteGameMode), config.contextInfo);
    if (config.voteType == VOTE_TYPE_SUBGROUP_MAP)
    {
        char parts[2][64];
        ExplodeString(config.contextInfo, "/", parts, 2, 64);
        strcopy(g_sVoteGameMode, sizeof(g_sVoteGameMode), parts[0]);
        strcopy(g_sVoteSubGroup, sizeof(g_sVoteSubGroup), parts[1]);
    }
    else if (config.voteType == VOTE_TYPE_SUBGROUP)
    {
        strcopy(g_sVoteSubGroup, sizeof(g_sVoteSubGroup), "");
    }
    else
    {
        g_sVoteSubGroup[0] = '\0';
    }
    
    int duration = config.time;
    if (duration <= 0)
    {
        duration = 20;
    }
    
    char info[128];
    if (config.voteType == VOTE_TYPE_SUBGROUP_MAP)
    {
        Format(info, sizeof(info), "%s / %s", g_sVoteGameMode, g_sVoteSubGroup);
    }
    else
    {
        strcopy(info, sizeof(info), config.contextInfo);
    }
    
    CallActiveVoteManager(initiator, config.voteType, info, voteItems, duration, config.adminvote, config.runoffItems != null, config.startSound, config.endSound, config.runoffstartSound, config.runoffendSound);
    delete voteItems;
    
    g_bVoteActive = true;
    return true;
}

void PrecacheVoteSound(const char[] sound)
{
    if (sound[0] == '\0')
    {
        return;
    }
    
    PrecacheSoundAny(sound, true);
    
    char downloadPath[PLATFORM_MAX_PATH];
    FormatEx(downloadPath, sizeof(downloadPath), "sound/%s", sound);
    
    if (FileExists(downloadPath, true))
    {
        AddFileToDownloadsTable(downloadPath);
    }
    else
    {
        MMC_WriteToLogFile(g_Cvar_Logs, "[MultiMode Core] Vote sound file not found: %s", downloadPath);
    }
}

void PlayVoteSound(bool isStart, bool isRunoff)
{
    char soundToPlay[PLATFORM_MAX_PATH];
    soundToPlay[0] = '\0';
    
    if (isStart && isRunoff)
    {
        // Runoff start sound
        if (g_PreservedRunoffStartSound[0] != '\0')
        {
            strcopy(soundToPlay, sizeof(soundToPlay), g_PreservedRunoffStartSound);
        }
        else if (g_CurrentVoteConfig.runoffstartSound[0] != '\0')
        {
            strcopy(soundToPlay, sizeof(soundToPlay), g_CurrentVoteConfig.runoffstartSound);
        }
    }
    else if (isStart && !isRunoff)
    {
        // Normal start sound
        if (g_PreservedStartSound[0] != '\0')
        {
            strcopy(soundToPlay, sizeof(soundToPlay), g_PreservedStartSound);
        }
        else if (g_CurrentVoteConfig.startSound[0] != '\0')
        {
            strcopy(soundToPlay, sizeof(soundToPlay), g_CurrentVoteConfig.startSound);
        }
    }
    else if (!isStart && isRunoff)
    {
        // Runoff end sound
        if (g_PreservedRunoffEndSound[0] != '\0')
        {
            strcopy(soundToPlay, sizeof(soundToPlay), g_PreservedRunoffEndSound);
        }
        else if (g_CurrentVoteConfig.runoffendSound[0] != '\0')
        {
            strcopy(soundToPlay, sizeof(soundToPlay), g_CurrentVoteConfig.runoffendSound);
        }
    }
    else // !isStart && !isRunoff
    {
        // Normal end sound
        if (g_PreservedEndSound[0] != '\0')
        {
            strcopy(soundToPlay, sizeof(soundToPlay), g_PreservedEndSound);
        }
        else if (g_CurrentVoteConfig.endSound[0] != '\0')
        {
            strcopy(soundToPlay, sizeof(soundToPlay), g_CurrentVoteConfig.endSound);
        }
    }
    
    if (soundToPlay[0] != '\0')
    {
        PrecacheVoteSound(soundToPlay);
        EmitSoundToAllAny(soundToPlay);
    }
}

void CallActiveVoteManager(int initiator, VoteType type, const char[] info, ArrayList items, int duration, bool adminVote, bool isRunoff, const char[] startSound, const char[] endSound, const char[] runoffstartSound, const char[] runoffendSound)
{
    if (g_VoteManagers == null)
    {
        LogError("[MultiMode Core] g_VoteManagers is null in CallActiveVoteManager!");
        delete items;
        return;
    }
    
    char managerName[64];
    g_Cvar_VoteManager.GetString(managerName, sizeof(managerName));
    
    VoteManagerEntry entry;
    if (!g_VoteManagers.GetArray(managerName, entry, sizeof(entry)))
    {
        MMC_WriteToLogFile(g_Cvar_Logs, "[MultiMode Core] Manager '%s' not found. Fallback to 'core'.", managerName);
        if (!g_VoteManagers.GetArray("core", entry, sizeof(entry)))
        {
            LogError("FATAL: No vote managers registered!");
            delete items;
            return;
        }
    }
    
    if (entry.plugin != GetMyHandle() && !IsValidHandle(entry.plugin))
    {
        MMC_WriteToLogFile(g_Cvar_Logs, "[MultiMode Core] Vote Manager '%s' has an invalid plugin handle. Attempting restore...", managerName);
        
        VoteManagerEntry backupEntry;
        if (g_VoteManagersBackup.GetArray(managerName, backupEntry, sizeof(backupEntry)))
        {
            g_VoteManagers.SetArray(managerName, backupEntry, sizeof(backupEntry));
            entry = backupEntry; // Switch to backup
            MMC_WriteToLogFile(g_Cvar_Logs, "[MultiMode Core] Restored backup manager for '%s'.", managerName);
        }
        else
        {
            if (g_VoteManagers.GetArray("core", entry, sizeof(entry)))
            {
                MMC_WriteToLogFile(g_Cvar_Logs, "[MultiMode Core] Backup not found. Forced fallback to internal 'core'.");
            }
            else
            {
                LogError("[MultiMode Core] FATAL: Vote Manager '%s' is invalid and no backup exists.", managerName);
                delete items;
                g_bVoteActive = false;
                return;
            }
        }
    }

    g_bVoteActive = true;
    g_eCurrentNativeVoteType = type; 
    
    Handle targetPlugin = entry.plugin;
    if (targetPlugin == GetMyHandle()) targetPlugin = INVALID_HANDLE;

    Function funcToCall = INVALID_FUNCTION;
    
    switch(type)
    {
        case VOTE_TYPE_GROUP: 
            funcToCall = entry.start_group;
            
        case VOTE_TYPE_SUBGROUP: 
            funcToCall = entry.start_subgroup;
            
        case VOTE_TYPE_MAP, VOTE_TYPE_SUBGROUP_MAP: 
            funcToCall = entry.start_map;
    }

    if (funcToCall != INVALID_FUNCTION)
    {
        ArrayList sharedItems = view_as<ArrayList>(CloneHandle(items, targetPlugin));
        
        Call_StartFunction(entry.plugin, funcToCall);
        Call_PushCell(initiator);
        Call_PushCell(type);
        Call_PushString(info);
        Call_PushCell(sharedItems);
        Call_PushCell(duration);
        Call_PushCell(adminVote);
        Call_PushCell(isRunoff);
        Call_PushString(startSound);
        Call_PushString(endSound);
        Call_PushString(runoffstartSound);
        Call_PushString(runoffendSound);
        Call_Finish();
    }
    else
    {
        LogError("[MultiMode Core] Invalid callback function for vote type %d in manager '%s'", type, managerName);
        g_bVoteActive = false;
        delete items; // Prevent leak if call fails
    }
}

void ProcessVoteLogic(VoteType voteType, int num_votes, int num_clients, ArrayList results)
{
    #pragma unused num_clients

    bool runoffEnabled = (g_CurrentVoteConfig.maxRunoffs > 0);
    if (!runoffEnabled)
    {
        if (results.Length > 0)
        {
            int maxVotes = -1;
            int winner_idx = -1;
            for (int i = 0; i < results.Length; i++)
            {
                VoteCandidate res;
                results.GetArray(i, res);
                if (res.votes > maxVotes)
                {
                    maxVotes = res.votes;
                    winner_idx = i;
                }
            }
            if (winner_idx != -1)
            {
                VoteCandidate winnerRes;
                results.GetArray(winner_idx, winnerRes);
                
                HandleWinner(winnerRes.info, voteType);
            }
            else
            {
                PlayVoteSound(false, g_bIsRunoffVote);
                CPrintToChatAll("%t", "No Votes Recorded");
                g_bVoteActive = false;
                g_bVoteCompleted = false;
                NativeMMC_OnVoteEnd("", "", "", VoteEnd_Failed);
            }
        }
        else
        {
            PlayVoteSound(false, g_bIsRunoffVote);
            g_bVoteActive = false;
            g_bVoteCompleted = false;
            NativeMMC_OnVoteEnd("", "", "", VoteEnd_Failed);
        }
        return;
    }

    if (results.Length == 0 || num_votes == 0)
    {
        PlayVoteSound(false, g_bIsRunoffVote);
        CPrintToChatAll("%t", "No Votes Recorded");
        g_bVoteActive = false;
        g_bVoteCompleted = false;
        NativeMMC_OnVoteEnd("", "", "", VoteEnd_Failed);
        return;
    }

    int maxVotes = 0;
    ArrayList winners = new ArrayList(ByteCountToCells(PLATFORM_MAX_PATH));
    for (int i = 0; i < results.Length; i++)
    {
        VoteCandidate current;
        results.GetArray(i, current);

        if (current.votes > maxVotes)
        {
            maxVotes = current.votes;
            winners.Clear();
            winners.PushString(current.info);
        }
        else if (current.votes > 0 && current.votes == maxVotes)
        {
            winners.PushString(current.info);
        }
    }

    bool needsRunoff = false;
    float threshold = g_CurrentVoteConfig.threshold;

    if (winners.Length > 1)
    {
        needsRunoff = true;
        MMC_WriteToLogFile(g_Cvar_Logs, "[Runoff] Runoff triggered due to a tie between %d items with %d votes each.", winners.Length, maxVotes);
        
        if (g_RunoffItems != null) {
            g_RunoffItems.Clear();
            for(int i = 0; i < winners.Length; i++)
            {
                char winner[PLATFORM_MAX_PATH];
                winners.GetString(i, winner, sizeof(winner));
                g_RunoffItems.PushString(winner);
            }
        } else {
            LogError("[MultiMode Core] g_RunoffItems is null during ProcessVoteLogic! Runoff cancelled.");
            needsRunoff = false;
        }
    }
    else if (winners.Length == 1 && threshold > 0.0 && num_votes > 0 && (float(maxVotes) / float(num_votes)) < threshold)
    {
        needsRunoff = true;
        MMC_WriteToLogFile(g_Cvar_Logs, "[Runoff] Runoff triggered because winner did not meet threshold (%.2f%% < %.2f%%).", (float(maxVotes) / float(num_votes)) * 100.0, threshold * 100.0);
        
        results.SortCustom(SortByVotes);
        
        if (g_RunoffItems != null) {
            g_RunoffItems.Clear();
            int limit = g_CurrentVoteConfig.maxRunoffInVote > 0 ? g_CurrentVoteConfig.maxRunoffInVote : 3;
            for (int i = 0; i < results.Length && g_RunoffItems.Length < limit; i++)
            {
                VoteCandidate candidate;
                results.GetArray(i, candidate);
                if (candidate.votes > 0)
                {
                    g_RunoffItems.PushString(candidate.info);
                }
            }
        } else {
             LogError("[MultiMode Core] g_RunoffItems is null during ProcessVoteLogic! Runoff cancelled.");
             needsRunoff = false;
        }
    }
    
    delete winners;

    if (needsRunoff)
    {
        int maxRunoffs;
        if (g_iGlobalMaxRunoffs > 0)
        {
            maxRunoffs = g_iGlobalMaxRunoffs;
        }
        else if (g_CurrentVoteConfig.maxRunoffs > 0)
        {
            maxRunoffs = g_CurrentVoteConfig.maxRunoffs;
        }
        else
        {
            maxRunoffs = 3;  // Default
        }
        
        if (g_bIsRunoffVote || g_iRunoffVotesThisMap >= maxRunoffs)
        {
            if (g_bIsRunoffVote) {
                MMC_WriteToLogFile(g_Cvar_Logs, "[Runoff] A runoff vote has also failed (tie or threshold not met).");
            } else {
                MMC_WriteToLogFile(g_Cvar_Logs, "[Runoff] Runoff vote limit reached (%d).", g_iRunoffVotesThisMap);
            }

            if (g_CurrentVoteConfig.runoffFailAction == RUNOFF_FAIL_DO_NOTHING)
            {
                PlayVoteSound(false, g_bIsRunoffVote);
                CPrintToChatAll("%t", "Runoff Vote Failed (Limit)");
                NativeMMC_OnVoteEnd("", "", "", VoteEnd_Failed);
                g_bVoteActive = false;
                g_bIsRunoffVote = false;
                g_iGlobalMaxRunoffs = -1;
                return;
            }
            else
            {
                char winner[PLATFORM_MAX_PATH];
                if (g_RunoffItems != null && g_RunoffItems.Length > 0) {
                     g_RunoffItems.GetString(0, winner, sizeof(winner));
                      MMC_WriteToLogFile(g_Cvar_Logs, "[Runoff] Force-picking first item '%s' due to failed runoff/limit.", winner);
                     HandleWinner(winner, voteType);
                } else {
                     LogError("[MultiMode Core] g_RunoffItems is empty or null during force pick fallback.");
                     g_bVoteActive = false;
                }
                return;
            }
        }
        else
        {
            g_iRunoffVotesThisMap++;
            NativeMMC_OnVoteEnd(g_sVoteGameMode, g_sVoteSubGroup, g_sVoteMap, VoteEnd_Runoff);
            StartCooldown(voteType, g_sVoteGameMode, g_sVoteSubGroup, g_iVoteInitiator, true);
        }
    }
    else
    {
        int winner_idx = -1;
        maxVotes = -1;
        for (int i = 0; i < results.Length; i++)
        {
            VoteCandidate res;
            results.GetArray(i, res);
            if (res.votes > maxVotes)
            {
                maxVotes = res.votes;
                winner_idx = i;
            }
        }
        
        if (winner_idx != -1)
        {
            VoteCandidate winnerRes;
            results.GetArray(winner_idx, winnerRes);
            
            HandleWinner(winnerRes.info, voteType);
        }
        else
        {
            PlayVoteSound(false, g_bIsRunoffVote);
            
            CPrintToChatAll("%t", "No Votes Recorded");
            g_bVoteActive = false;
            g_bVoteCompleted = false;
            g_iGlobalMaxRunoffs = -1;
            NativeMMC_OnVoteEnd("", "", "", VoteEnd_Failed);
        }
    }
}

void ProcessVoteResults(Menu menu, int num_votes, int num_clients, const int[][] item_info, int num_items, VoteType voteType)
{
    ArrayList results = new ArrayList(sizeof(VoteCandidate));
    for (int i = 0; i < num_items; i++)
    {
        VoteCandidate res;
        res.votes = item_info[i][VOTEINFO_ITEM_VOTES];
        menu.GetItem(item_info[i][VOTEINFO_ITEM_INDEX], res.info, sizeof(res.info));
        results.PushArray(res);
    }
    
    ProcessVoteLogic(voteType, num_votes, num_clients, results);
    delete results;
}

void HandleWinner(const char[] winner, VoteType voteType)
{
    // Play vote end sound
    PlayVoteSound(false, g_bIsRunoffVote);
    
    if (StrEqual(winner, "Extend Map"))
    {
        NativeMMC_OnVoteEnd("Extend Map", "", "", VoteEnd_Extend);
        ExtendMapTime();
        g_bVoteActive = false;
        g_bVoteCompleted = false;
    }
    else
    {
        switch(voteType)
        {
            case VOTE_TYPE_GROUP:
            {
                strcopy(g_sVoteGameMode, sizeof(g_sVoteGameMode), winner);
                
                bool isGroupsOnlyVote = (g_CurrentVoteConfig.type == VOTE_TYPE_GROUPS_ONLY);
                
                if (isGroupsOnlyVote || GetVoteMethod() == 2)
                {
                    int index = MMC_FindGameModeIndex(winner);
                    if (index != -1)
                    {
                        GameModeConfig config;
                        GetGameModesList().GetArray(index, config);

                        ArrayList allMaps = new ArrayList(ByteCountToCells(PLATFORM_MAX_PATH));
                        
                        for (int i = 0; i < config.maps.Length; i++)
                        {
                            char map[PLATFORM_MAX_PATH];
                            config.maps.GetString(i, map, sizeof(map));
                            allMaps.PushString(map);
                        }

                        for (int i = 0; i < config.subGroups.Length; i++)
                        {
                            SubGroupConfig subConfig;
                            config.subGroups.GetArray(i, subConfig);
                            for (int j = 0; j < subConfig.maps.Length; j++)
                            {
                                char map[PLATFORM_MAX_PATH];
                                subConfig.maps.GetString(j, map, sizeof(map));
                                if (allMaps.FindString(map) == -1) {
                                     allMaps.PushString(map);
                                }
                            }
                        }

                        if (allMaps.Length > 0)
                        {
                            int randomIndex = GetRandomInt(0, allMaps.Length - 1);
                            char map[PLATFORM_MAX_PATH];
                            allMaps.GetString(randomIndex, map, sizeof(map));
                            strcopy(g_sVoteMap, sizeof(g_sVoteMap), map);

                            g_sVoteSubGroup[0] = '\0';
                            for (int i = 0; i < config.subGroups.Length; i++)
                            {
                                SubGroupConfig subConfig;
                                config.subGroups.GetArray(i, subConfig);
                                if (subConfig.maps.FindString(map) != -1)
                                {
                                    strcopy(g_sVoteSubGroup, sizeof(g_sVoteSubGroup), subConfig.name);
                                    break;
                                }
                            }

                            if (strlen(g_sVoteSubGroup) > 0) {
                                ExecuteSubGroupVoteResult();
                            } else {
                                ExecuteVoteResult();
                            }
                        }
                        delete allMaps;
                    }
                }
                else if (HasSubGroups(winner))
                {
                    g_bVoteActive = false;
                    StartCooldown(VOTE_TYPE_SUBGROUP, winner, "", g_iVoteInitiator);
                }
                else
                {
                    g_sVoteSubGroup[0] = '\0';
                    StartCooldown(VOTE_TYPE_MAP, winner, "", g_iVoteInitiator);
                }
            }
            case VOTE_TYPE_SUBGROUP:
            {
                strcopy(g_sVoteSubGroup, sizeof(g_sVoteSubGroup), winner);
                StartCooldown(VOTE_TYPE_SUBGROUP_MAP, g_sVoteGameMode, winner, g_iVoteInitiator);
            }
            case VOTE_TYPE_MAP:
            {
                strcopy(g_sVoteMap, sizeof(g_sVoteMap), winner);
                if (GetVoteMethod() == 3)
                {
                    int index = MMC_FindGameModeForMap(g_sVoteMap);
                    if (index != -1)
                    {
                        GameModeConfig config;
                        GetGameModesList().GetArray(index, config);
                        strcopy(g_sVoteGameMode, sizeof(g_sVoteGameMode), config.name);
                        
                        g_sVoteSubGroup[0] = '\0';
                        for (int i = 0; i < config.subGroups.Length; i++)
                        {
                            SubGroupConfig subConfig;
                            config.subGroups.GetArray(i, subConfig);
                            if (subConfig.maps.FindString(g_sVoteMap) != -1)
                            {
                                strcopy(g_sVoteSubGroup, sizeof(g_sVoteSubGroup), subConfig.name);
                                break;
                            }
                        }
                    }
                    else
                    {
                        g_sVoteSubGroup[0] = '\0';
                    }
                }
                else
                {
                    if (strlen(g_sVoteGameMode) > 0)
                    {
                        int index = MMC_FindGameModeIndex(g_sVoteGameMode);
                        if (index != -1)
                        {
                            GameModeConfig config;
                            GetGameModesList().GetArray(index, config);
                            
                            g_sVoteSubGroup[0] = '\0';
                            for (int i = 0; i < config.subGroups.Length; i++)
                            {
                                SubGroupConfig subConfig;
                                config.subGroups.GetArray(i, subConfig);
                                if (subConfig.maps.FindString(g_sVoteMap) != -1)
                                {
                                    strcopy(g_sVoteSubGroup, sizeof(g_sVoteSubGroup), subConfig.name);
                                    break;
                                }
                            }
                        }
                        else
                        {
                            g_sVoteSubGroup[0] = '\0';
                        }
                    }
                    else
                    {
                        g_sVoteSubGroup[0] = '\0';
                    }
                }
                ExecuteVoteResult();
            }
            case VOTE_TYPE_SUBGROUP_MAP:
            {
                strcopy(g_sVoteMap, sizeof(g_sVoteMap), winner);
                ExecuteSubGroupVoteResult();
            }
        }
    }
    
    if(!StrEqual(winner, "Extend Map"))
    {
        g_bVoteActive = false;
        g_bVoteCompleted = true;
    }
    g_bIsRunoffVote = false;
}

// //////////////////
// //              //
// //    Timers    //
// //              //
// //////////////////

// Timers

public Action Timer_ForceMapChange(Handle timer)
{
    if(!StrEqual(g_sNextMap, "") && IsMapValid(g_sNextMap))
    {
        MMC_WriteToLogFile(g_Cvar_Logs, "[MultiMode Core] Forcing switch to: %s", g_sNextMap);
        ForceChangeLevel(g_sNextMap, "Voting completed");
    }
    else
    {
        MMC_WriteToLogFile(g_Cvar_Logs, "Invalid Map: %s", g_sNextMap);
        CPrintToChatAll("%t", "Error Changing Map");
    }
    
    return Plugin_Stop;
}

public Action Timer_ForceMapInstant(Handle timer, DataPack dp)
{
    char map[PLATFORM_MAX_PATH];
    dp.Reset();
    dp.ReadString(map, sizeof(map));
    delete dp;

    if(IsMapValid(map))
    {
        ForceChangeLevel(map, "Immediate force");
    }
    
    return Plugin_Stop;
}

public Action Timer_ChangeMap(Handle timer)
{
    if (strlen(g_sCurrentGameMode) == 0)
        return Plugin_Stop;

    int index = MMC_FindGameModeIndex(g_sCurrentGameMode);
    if (index == -1)
        return Plugin_Stop;

    GameModeConfig config;
    ArrayList list = GetGameModesList();
    list.GetArray(index, config);

    char currentMap[PLATFORM_MAX_PATH];
    GetCurrentMap(currentMap, sizeof(currentMap));
    
    KeyValues kv = GetMapKv(g_sCurrentGameMode, currentMap);
    if (kv != null)
    {
        char mapPreCommand[256];
        kv.GetString(MAPCYCLE_KEY_PRE_COMMAND, mapPreCommand, sizeof(mapPreCommand), "");
        delete kv;
    }
    
    char game[20];
    GetGameFolderName(game, sizeof(game));
    ConVar mp_tournament = FindConVar("mp_tournament");

    if (mp_tournament != null && mp_tournament.BoolValue)
    {
        ForceChangeLevel(g_sNextMap, "Map changed from next round.");
    }
    else if (!StrEqual(game, "gesource", false) && !StrEqual(game, "zps", false))
    {
        int iGameEnd = FindEntityByClassname(-1, "game_end");
        if (iGameEnd == -1 && (iGameEnd = CreateEntityByName("game_end")) == -1)
        {
            ForceChangeLevel(g_sNextMap, "Map changed from next round.");
        } 
        else 
        {     
            AcceptEntityInput(iGameEnd, "EndGame");
        }
    }
    else
    {
        ForceChangeLevel(g_sNextMap, "Map changed from next round.");
    }
        
    CPrintToChatAll("%t", "Round Map Changing", g_sNextMap);
    MMC_WriteToLogFile(g_Cvar_Logs, "[MultiMode Core] Map instantly set after round to: %s", g_sNextMap);
        
    return Plugin_Stop;
}

// //////////////////////
// //                  //
// //    Countdown     //
// //                  //
// //////////////////////

// Countdown

public Action Timer_UpdateCooldownHUD(Handle timer)
{
    if (!g_bCooldownActive)
    {
        return Plugin_Stop;
    }
    
    int remaining = g_iCooldownEndTime - GetTime();
    if (remaining < 0) remaining = 0;
    
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i) && !IsFakeClient(i))
        {
            if (g_bIsRunoffCooldown)
            {
                PrintCenterText(i, "%t", "Run Off Cooldown Hud", remaining);
            }
            else
            {
                PrintCenterText(i, "%t", "Cooldown Begin Hud", remaining);
            }
        }
    }
    
    return (remaining > 0) ? Plugin_Continue : Plugin_Stop;
}

// //////////////////
// //              //
// //    Events    //
// //              //
// //////////////////

// Events

public void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
    if (g_bChangeMapNextRound)
    {
        g_bChangeMapNextRound = false;
        CreateTimer(3.0, Timer_ChangeMap);
    }
}

public void Event_ServerSpawn(Event event, const char[] name, bool dontBroadcast)
{
    if (strlen(g_sPendingCommand) > 0)
    {
        MMC_WriteToLogFile(g_Cvar_Logs, "[MultiMode Core] Executing pending command: %s", g_sPendingCommand);
        ServerCommand(g_sPendingCommand);
        g_sPendingCommand[0] = '\0';
    }
}

public void Event_GameOver(Event event, const char[] name, bool dontBroadcast)
{
    if (g_bGameEndTriggered) return;
	
	ExecutePreCommands();
	
    g_bGameEndTriggered = true;
}

public void OnTimelimitChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
    if(g_bInternalChange) return;
}

// //////////////////////////
// //                      //
// //      Commands        //
// //                      //
// //////////////////////////

// Commands

void CancelCurrentVote()
{
    if (g_bVoteActive)
    {
        if (IsVoteInProgress())
        {
            CancelVote();
        }
        g_bVoteActive = false;
    }
}

void ExecutePreCommands()
{
    if (strlen(g_sCurrentGameMode) == 0)
        return;

    int index = MMC_FindGameModeIndex(g_sCurrentGameMode);
    if (index == -1)
        return;

    GameModeConfig config;
    ArrayList list = GetGameModesList();
    list.GetArray(index, config);

    char currentMap[PLATFORM_MAX_PATH];
    GetCurrentMap(currentMap, sizeof(currentMap));
}

// //////////////////////////
// //                      //
// //    Admins Section    //
// //                      //
// //////////////////////////

// Admins Section

public void OnAdminMenuReady(Handle aTopMenu)
{
    TopMenu topmenu = TopMenu.FromHandle(aTopMenu);

    TopMenuObject category = topmenu.FindCategory("Multimode Core Administration");
    
    if (category == INVALID_TOPMENUOBJECT)
    {
        category = topmenu.AddCategory("Multimode Core Administration", CategoryHandler);
    }

    topmenu.AddItem("sm_cancelvote", AdminMenu_CancelVote, category, "sm_cancelvote", ADMFLAG_VOTE);
}


public void AdminMenu_CancelVote(TopMenu topmenu, TopMenuAction action, TopMenuObject object_id, int client, char[] buffer, int maxlength)
{
    if (action == TopMenuAction_DisplayOption)
    {
		Format(buffer, maxlength, "%T", "Cancel Current Vote", client);
    }
    else if (action == TopMenuAction_SelectOption)
    {
        bool bWasActive = false;
        
        if (g_bVoteActive)
        {
            CancelVote();
            g_bVoteActive = false;
            bWasActive = true;
        }
        
        if (g_bCooldownActive)
        {
            g_bCooldownActive = false;
            KillTimer(g_hCooldownTimer);
            g_hCooldownTimer = INVALID_HANDLE;
            bWasActive = true;
        }
        
        if (bWasActive)
        {
            g_bVoteCompleted = false;
            g_bIsRunoffVote = false;
            
            CPrintToChatAll("%t", "Admin Cancel Vote", client);
        }
        else
        {
            CPrintToChat(client, "%t", "Admin Cancel No Vote");
        }
    }
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

// ////////////////////
// //                //
// //    Nominate    //
// //                //
// ////////////////////

void RemoveAllClientNominations(int client, bool showMessage = true)
{
    if (g_PlayerNominations[client] == null || g_PlayerNominations[client].Length == 0)
    {
        return;
    }

    while (g_PlayerNominations[client].Length > 0)
    {
        RemoveClientNomination(client, 0, false);
    }
    
    if (showMessage)
    {
        CPrintToChat(client, "%t", "Unnominate All Removed");
    }
}

void RemoveClientNomination(int client, int index, bool showMessage = true)
{
    NominationInfo nInfo;
    g_PlayerNominations[client].GetArray(index, nInfo);
    
    char group[64], subgroup[64], map[PLATFORM_MAX_PATH];
    strcopy(group, sizeof(group), nInfo.group);
    strcopy(subgroup, sizeof(subgroup), nInfo.subgroup);
    strcopy(map, sizeof(map), nInfo.map);
    
    g_PlayerNominations[client].Erase(index);

    bool mapStillNominated = false;
    bool groupStillNominated = false;
    char key[128];
    if (strlen(subgroup) > 0)
    {
        Format(key, sizeof(key), "%s/%s", group, subgroup);
    }
    else
    {
        strcopy(key, sizeof(key), group);
    }

    for (int i = 1; i <= MaxClients; i++)
    {
        if (g_PlayerNominations[i] == null) continue;
        for (int j = 0; j < g_PlayerNominations[i].Length; j++)
        {
            NominationInfo otherInfo;
            g_PlayerNominations[i].GetArray(j, otherInfo);
            
            if (StrEqual(otherInfo.map, map) && StrEqual(otherInfo.group, group) && StrEqual(otherInfo.subgroup, subgroup))
            {
                mapStillNominated = true;
            }

            if (StrEqual(otherInfo.group, group) && StrEqual(otherInfo.subgroup, subgroup))
            {
                groupStillNominated = true;
            }

            if (mapStillNominated && groupStillNominated) break;
        }
        if (mapStillNominated && groupStillNominated) break;
    }

    if (!mapStillNominated)
    {
        ArrayList mapsNominated;
        if (g_NominatedMaps.GetValue(key, mapsNominated))
        {
            int mapIndex = mapsNominated.FindString(map);
            if (mapIndex != -1)
            {
                mapsNominated.Erase(mapIndex);
            }
        }
    }

    if (!groupStillNominated)
    {
        int groupIndex = g_NominatedGamemodes.FindString(key);
        if (groupIndex != -1)
        {
            g_NominatedGamemodes.Erase(groupIndex);
        }
    }

    if (g_PlayerNominations[client].Length == 0)
    {
        g_bHasNominated[client] = false;
        if (showMessage)
        {
            CPrintToChat(client, "%t", "Unnominate Can Nominate Again");
        }
    }

    if (showMessage)
    {
        char displayKey[192];
        if(strlen(subgroup) > 0)
            Format(displayKey, sizeof(displayKey), "%s/%s", group, subgroup);
        else
            strcopy(displayKey, sizeof(displayKey), group);
            
        CPrintToChat(client, "%t", "Unnominate Single Removed", map, displayKey);
    }
}

bool HasClientNominatedMap(int client, const char[] gamemode, const char[] subgroup, const char[] map)
{
    if (g_PlayerNominations[client] == null)
        return false;
    
    for (int i = 0; i < g_PlayerNominations[client].Length; i++)
    {
        NominationInfo nInfo;
        g_PlayerNominations[client].GetArray(i, nInfo);
        
        if (StrEqual(nInfo.map, map) && StrEqual(nInfo.group, gamemode) && StrEqual(nInfo.subgroup, subgroup))
        {
            return true;
        }
    }
    
    return false;
}

void RegisterNomination(int client, const char[] gamemode, const char[] subgroup, const char[] map)
{
    char key[128];
    if (strlen(subgroup) > 0)
    {
        Format(key, sizeof(key), "%s/%s", gamemode, subgroup);
    }
    else
    {
        strcopy(key, sizeof(key), gamemode);
    }

    if (g_NominatedGamemodes.FindString(key) == -1)
        g_NominatedGamemodes.PushString(key);

    ArrayList mapsNominated;
    if (!g_NominatedMaps.GetValue(key, mapsNominated))
    {
        mapsNominated = new ArrayList(ByteCountToCells(PLATFORM_MAX_PATH));
        g_NominatedMaps.SetValue(key, mapsNominated);
    }
    
    if (mapsNominated.FindString(map) == -1)
        mapsNominated.PushString(map);

    g_bHasNominated[client] = true;
    
    NominationInfo nInfo;
    strcopy(nInfo.group, sizeof(nInfo.group), gamemode);
    strcopy(nInfo.subgroup, sizeof(nInfo.subgroup), subgroup);
    strcopy(nInfo.map, sizeof(nInfo.map), map);
    g_PlayerNominations[client].PushArray(nInfo);
    
    CPrintToChat(client, "%t", "Nominated Client", key, map);
	
    char clientName[MAX_NAME_LENGTH];
    GetClientName(client, clientName, sizeof(clientName));
    
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i) && !IsFakeClient(i) && i != client)
        {
            CPrintToChat(i, "%t", "Nominated Server", clientName, key, map);
        }
    }
}

// //////////////////////////
// //                      //
// //       Natives        //
// //                      //
// //////////////////////////

// Natives

public int NativeMMC_StartVote(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    bool adminVote = GetNativeCell(2);
    
    if (g_bVoteActive || g_bCooldownActive)
    {
        return 0;
    }
    
    int method = GetVoteMethod();
    MultimodeMethodType voteMethodType;
    VoteType voteType;
    
    switch (method)
    {
        case 1:
        {
            voteMethodType = VOTE_TYPE_GROUPS_THEN_MAPS;
            voteType = VOTE_TYPE_GROUP;
        }
        case 2:
        {
            voteMethodType = VOTE_TYPE_GROUPS_ONLY;
            voteType = VOTE_TYPE_GROUP;
        }
        case 3:
        {
            voteMethodType = VOTE_TYPE_MAPS_ONLY;
            voteType = VOTE_TYPE_MAP;
        }
        default:
        {
            voteMethodType = VOTE_TYPE_GROUPS_THEN_MAPS;
            voteType = VOTE_TYPE_GROUP;
        }
    }
    
    AdvancedVoteConfig config;
    strcopy(config.id, sizeof(config.id), "gamemode");
    strcopy(config.mapcycle, sizeof(config.mapcycle), "");
    config.type = voteMethodType;
    config.time = 0;
    config.timing = TIMING_NEXTMAP;
    config.startSound[0] = '\0';
    config.endSound[0] = '\0';
    config.extendOption = true;
    config.timestep = 0;
    config.fragstep = 0;
    config.roundstep = 0;
    config.groupexclude = -1;
    config.mapexclude = -1;
    config.handlenominations = true;
    config.threshold = 0.0;
    config.maxRunoffs = 0;
    config.maxRunoffInVote = 0;
    config.runoffFailAction = RUNOFF_FAIL_PICK_FIRST;
    config.runoffstartSound[0] = '\0';
    config.runoffendSound[0] = '\0';
    config.sorted = SORTED_MAPCYCLE_ORDER;
    config.adminvote = adminVote;
    config.targetClients = null;
    config.voteType = voteType;
    config.contextInfo[0] = '\0';
    config.runoffItems = null;
    
    int voteTypeEx = 0;
    switch (voteType)
    {
        case VOTE_TYPE_GROUP: voteTypeEx = 0;
        case VOTE_TYPE_SUBGROUP: voteTypeEx = 1;
        case VOTE_TYPE_MAP: voteTypeEx = 2;
        case VOTE_TYPE_SUBGROUP_MAP: voteTypeEx = 4;
    }
    
    NativeMMC_OnVoteStart(client);
    NativeMMC_OnVoteStartEx(client, voteTypeEx, false);
    
    g_bCurrentVoteAdmin = config.adminvote;
    g_bIsRunoffVote = false;
    g_eVoteTiming = config.timing;
    g_CurrentVoteConfig = config;
    
    ArrayList voteItems = null;
    switch (voteType)
    {
        case VOTE_TYPE_GROUP:
        {
            voteItems = PrepareVoteItems_Group(config, null);
        }
        case VOTE_TYPE_MAP:
        {
            voteItems = PrepareVoteItems_Map(config, "", null);
        }
    }
    
    if (voteItems == null || voteItems.Length == 0)
    {
        if (voteItems != null) delete voteItems;
        return 0;
    }
    
    bool canExtend = (!g_bMapExtended) && MMC_CanExtendMap();
    bool isFirstVote = false;
    
    switch (config.type)
    {
        case VOTE_TYPE_GROUPS_THEN_MAPS, VOTE_TYPE_GROUPS_ONLY:
        {
            isFirstVote = (voteType == VOTE_TYPE_GROUP);
        }
        case VOTE_TYPE_MAPS_ONLY:
        {
            isFirstVote = (voteType == VOTE_TYPE_MAP);
        }
    }
    
    if (config.extendOption && canExtend && isFirstVote)
    {
        VoteCandidate item;
        strcopy(item.info, sizeof(item.info), "Extend Map");
        int timestep = (config.timestep > 0) ? config.timestep : 6;
        Format(item.name, sizeof(item.name), "%t", "Extend Map Normal Vote", timestep);
        voteItems.ShiftUp(0);
        voteItems.SetArray(0, item);
    }
    
    g_sVoteGameMode[0] = '\0';
    g_sVoteSubGroup[0] = '\0';
    
    int duration = config.time;
    if (duration <= 0)
    {
        duration = 20;
    }
	
    CallActiveVoteManager(client, voteType, "", voteItems, duration, config.adminvote, false, config.startSound, config.endSound, config.runoffstartSound, config.runoffendSound);
    delete voteItems;
    
    g_bVoteActive = true;
    return 0;
}

public int NativeMMC_StartVoteAdvanced(Handle plugin, int numParams)
{
    char id[64];
    GetNativeString(1, id, sizeof(id));
    
    if (strlen(id) == 0)
    {
        LogError("[Multimode] Vote ID cannot be empty!");
        return false;
    }
    
    if (g_bVoteActive || g_bCooldownActive)
    {
        return false;
    }
    
    char mapcycle[256];
    GetNativeString(2, mapcycle, sizeof(mapcycle));
    
    MultimodeMethodType type = view_as<MultimodeMethodType>(GetNativeCell(3));
    int time = GetNativeCell(4);
    TimingMode timing = view_as<TimingMode>(GetNativeCell(5));
    
    char startSound[PLATFORM_MAX_PATH];
    GetNativeString(6, startSound, sizeof(startSound));
    
    char endSound[PLATFORM_MAX_PATH];
    GetNativeString(7, endSound, sizeof(endSound));
    
    bool extendOption = GetNativeCell(8);
    int timestep = GetNativeCell(9);
    int fragstep = GetNativeCell(10);
    int roundstep = GetNativeCell(11);
    int groupexclude = GetNativeCell(12);
    int mapexclude = GetNativeCell(13);
    bool handlenominations = GetNativeCell(14);
    float threshold = GetNativeCell(15);
    int maxRunoffs = GetNativeCell(16);
    int maxRunoffInVote = GetNativeCell(17);
    MultimodeRunoffFailAction runoffFailAction = view_as<MultimodeRunoffFailAction>(GetNativeCell(18));
    
    char runoffstartSound[PLATFORM_MAX_PATH];
    GetNativeString(19, runoffstartSound, sizeof(runoffstartSound));
    
    char runoffendSound[PLATFORM_MAX_PATH];
    GetNativeString(20, runoffendSound, sizeof(runoffendSound));
    
    MultimodeVoteSorted sorted = view_as<MultimodeVoteSorted>(GetNativeCell(21));
    
    int numClients = GetNativeCell(23);
    bool adminvote = GetNativeCell(24);
    
    ArrayList targetClients = null;
    int initiator = 0;
    if (numClients > 0)
    {
        targetClients = new ArrayList();
        int[] clients = new int[numClients];
        GetNativeArray(22, clients, numClients);
        
        for (int i = 0; i < numClients; i++)
        {
            if (clients[i] > 0 && clients[i] <= MaxClients && IsClientInGame(clients[i]))
            {
                targetClients.Push(clients[i]);
                if (initiator == 0)
                {
                    initiator = clients[i];
                }
            }
        }
    }
    
    AdvancedVoteConfig config;
    strcopy(config.id, sizeof(config.id), id);
    strcopy(config.mapcycle, sizeof(config.mapcycle), mapcycle);
    config.type = type;
    config.time = time;
    config.timing = timing;
    strcopy(config.startSound, sizeof(config.startSound), startSound);
    strcopy(config.endSound, sizeof(config.endSound), endSound);
    
    PrecacheVoteSound(startSound);
    PrecacheVoteSound(endSound);
    PrecacheVoteSound(runoffstartSound);
    PrecacheVoteSound(runoffendSound);
    
    config.extendOption = extendOption;
    config.timestep = timestep;
    config.fragstep = fragstep;
    config.roundstep = roundstep;
    config.groupexclude = groupexclude;
    config.mapexclude = mapexclude;
    config.handlenominations = handlenominations;
    config.threshold = threshold;
    config.maxRunoffs = maxRunoffs;
    config.maxRunoffInVote = maxRunoffInVote;
    config.runoffFailAction = runoffFailAction;
    strcopy(config.runoffstartSound, sizeof(config.runoffstartSound), runoffstartSound);
    strcopy(config.runoffendSound, sizeof(config.runoffendSound), runoffendSound);
    config.sorted = sorted;
    config.adminvote = adminvote;
    config.targetClients = targetClients;
    
    g_ActiveVoteConfigs.SetArray(id, config, sizeof(config));
    g_CurrentVoteConfig = config;  // store current vote config for ProcessVoteLogic...
    strcopy(g_sCurrentVoteId, sizeof(g_sCurrentVoteId), id);  // store current vote ID...
    
    bool success = false;
    switch (type)
    {
        case VOTE_TYPE_GROUPS_THEN_MAPS:
        {
            config.voteType = VOTE_TYPE_GROUP;
            config.contextInfo[0] = '\0';
            config.runoffItems = null;
            success = BuildVote(initiator, config);
        }
        case VOTE_TYPE_GROUPS_ONLY:
        {
            config.voteType = VOTE_TYPE_GROUP;
            config.contextInfo[0] = '\0';
            config.runoffItems = null;
            success = BuildVote(initiator, config);
        }
        case VOTE_TYPE_MAPS_ONLY:
        {
            config.voteType = VOTE_TYPE_MAP;
            if (strlen(mapcycle) > 0 && StrContains(mapcycle, ".") == -1 && StrContains(mapcycle, "/") == -1 && StrContains(mapcycle, "\\") == -1)
            {
                strcopy(config.contextInfo, sizeof(config.contextInfo), mapcycle);
            }
            else
            {
                config.contextInfo[0] = '\0';
            }
            config.runoffItems = null;
            success = BuildVote(initiator, config);
        }
    }
    
    if (!success)
    {
        g_ActiveVoteConfigs.Remove(id);
        if (targetClients != null)
        {
            delete targetClients;
        }
        return false;
    }
    
    return true;
}

public int NativeMMC_IsVoteActive(Handle plugin, int numParams)
{
    return g_bVoteActive;
}

public int NativeMMC_GetCurrentGameMode(Handle plugin, int numParams)
{
    char group[64], subgroup[64];
    int groupMaxLen = GetNativeCell(2);
    int subgroupMaxLen = GetNativeCell(4);

    SplitGamemodeString(g_sCurrentGameMode, group, sizeof(group), subgroup, sizeof(subgroup));

    SetNativeString(1, group, groupMaxLen);
    SetNativeString(3, subgroup, subgroupMaxLen);
    return 0;
}

public int NativeMMC_GetNextMap(Handle plugin, int numParams)
{
    int maxlen = GetNativeCell(2);
    char displayName[PLATFORM_MAX_PATH];

    if (StrEqual(g_sNextMap, ""))
    {
        SetNativeString(1, "", maxlen);
        return 0;
    }
    
    char group[64], subgroup[64];
    SplitGamemodeString(g_sNextGameMode, group, sizeof(group), subgroup, sizeof(subgroup));

    GetMapDisplayNameEx(group, g_sNextMap, displayName, sizeof(displayName), subgroup);
    SetNativeString(1, displayName, maxlen);
    return 0;
}

public int NativeMMC_Nominate(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    char group[64], subgroup[64], map[PLATFORM_MAX_PATH];
    GetNativeString(2, group, sizeof(group));
    GetNativeString(3, subgroup, sizeof(subgroup));
    GetNativeString(4, map, sizeof(map));
    
    int groupIndex = MMC_FindGameModeIndex(group);
    if (groupIndex == -1 || !IsMapValid(map))
        return false;

    if (strlen(subgroup) > 0 && MMC_FindSubGroupIndex(group, subgroup) == -1)
        return false;
    
    if (HasClientNominatedMap(client, group, subgroup, map))
    {
        return false;
    }
    
    RegisterNomination(client, group, subgroup, map);
    return true;
}

public int NativeMMC_GetNextGameMode(Handle plugin, int numParams)
{
    char group[64], subgroup[64];
    int groupMaxLen = GetNativeCell(2);
    int subgroupMaxLen = GetNativeCell(4);

    if (strlen(g_sNextGameMode) > 0)
    {
        strcopy(group, groupMaxLen, g_sNextGameMode);
        
        if (strlen(g_sNextSubGroup) > 0)
        {
            int index = MMC_FindGameModeIndex(g_sNextGameMode);
            if (index != -1)
            {
                GameModeConfig config;
                ArrayList list = GetGameModesList();
                list.GetArray(index, config);
                
                int subgroupIndex = MMC_FindSubGroupIndex(g_sNextGameMode, g_sNextSubGroup);
                if (subgroupIndex != -1)
                {
                    strcopy(subgroup, subgroupMaxLen, g_sNextSubGroup);
                }
                else
                {
                    subgroup[0] = '\0';
                }
            }
            else
            {
                subgroup[0] = '\0';
            }
        }
        else
        {
            subgroup[0] = '\0';
        }
    }
    else
    {
        group[0] = '\0';
        subgroup[0] = '\0';
    }
    
    SetNativeString(1, group, groupMaxLen);
    SetNativeString(3, subgroup, subgroupMaxLen);
    
    return 0;
}

public int NativeMMC_IsRandomCycleEnabled(Handle plugin, int numParams)
{
    Handle randomCyclePlugin = FindPluginByFile("multimode_randomcycle.smx");
    if (randomCyclePlugin != null && GetPluginStatus(randomCyclePlugin) == Plugin_Running)
    {
        return true;
    }
    return false;
}

public int NativeMMC_GetCurrentMap(Handle plugin, int numParams)
{
    int maxlen = GetNativeCell(2);
    char map[PLATFORM_MAX_PATH];
    char displayName[PLATFORM_MAX_PATH];
    
    GetCurrentMap(map, sizeof(map));

    char group[64], subgroup[64];
    SplitGamemodeString(g_sCurrentGameMode, group, sizeof(group), subgroup, sizeof(subgroup));
    
    GetMapDisplayNameEx(group, map, displayName, sizeof(displayName), subgroup);
    
    SetNativeString(1, displayName, maxlen);
    return 0;
}

public int NativeMMC_GetMapDisplayName(Handle plugin, int numParams)
{
    char gamemode[64];
    char map[PLATFORM_MAX_PATH];
    char subgroup[64];
    int displayMaxLen = GetNativeCell(4);
    
    GetNativeString(1, gamemode, sizeof(gamemode));
    GetNativeString(2, map, sizeof(map));
    GetNativeString(3, subgroup, sizeof(subgroup));
    
    char display[PLATFORM_MAX_PATH];
    GetMapDisplayNameEx(gamemode, map, display, sizeof(display), subgroup);
    
    SetNativeString(4, display, displayMaxLen);
    return 0;
}

public int NativeMMC_IsGamemodeRecentlyPlayed(Handle plugin, int numParams)
{
    char gamemode[64];
    GetNativeString(1, gamemode, sizeof(gamemode));
    
    if (g_PlayedGamemodes == null || strlen(gamemode) == 0)
        return false;
    
    int groupExclude = GetNativeCell(2);
    if (groupExclude <= 0)
    {
        return (g_PlayedGamemodes.FindString(gamemode) != -1);
    }
    else
    {
        int index = g_PlayedGamemodes.FindString(gamemode);
        if (index == -1)
            return false;
        
        int totalGroups = g_PlayedGamemodes.Length;
        int excludeStart = totalGroups - groupExclude;
        return (index >= excludeStart && index < totalGroups);
    }
}

public int NativeMMC_IsMapRecentlyPlayed(Handle plugin, int numParams)
{
    char gamemode[64];
    char map[PLATFORM_MAX_PATH];
    char subgroup[64];
    
    GetNativeString(1, gamemode, sizeof(gamemode));
    GetNativeString(2, map, sizeof(map));
    GetNativeString(3, subgroup, sizeof(subgroup));
    
    if (g_PlayedMaps == null || strlen(gamemode) == 0 || strlen(map) == 0)
        return false;
    
    char key[128];
    if (strlen(subgroup) > 0)
    {
        Format(key, sizeof(key), "%s/%s", gamemode, subgroup);
    }
    else
    {
        strcopy(key, sizeof(key), gamemode);
    }
    
    ArrayList playedMaps;
    if (!g_PlayedMaps.GetValue(key, playedMaps) || playedMaps == null)
        return false;
    
    int mapExclude = GetNativeCell(4);
    if (mapExclude <= 0)
    {
        return (playedMaps.FindString(map) != -1);
    }
    else
    {
        int index = playedMaps.FindString(map);
        if (index == -1)
            return false;

        int totalMaps = playedMaps.Length;
        int excludeStart = totalMaps - mapExclude;
        return (index >= excludeStart && index < totalMaps);
    }
}

public int NativeMMC_IsSubGroupRecentlyPlayed(Handle plugin, int numParams)
{
    char gamemode[64];
    char subgroup[64];
    
    GetNativeString(1, gamemode, sizeof(gamemode));
    GetNativeString(2, subgroup, sizeof(subgroup));
    
    if (g_PlayedGamemodes == null || strlen(gamemode) == 0 || strlen(subgroup) == 0)
        return false;
    
    char key[128];
    Format(key, sizeof(key), "%s/%s", gamemode, subgroup);
    
    int subgroupExclude = GetNativeCell(3);
    if (subgroupExclude <= 0)
    {
        return (g_PlayedGamemodes.FindString(key) != -1);
    }
    else
    {
        int index = g_PlayedGamemodes.FindString(key);
        if (index == -1)
            return false;
        
        int totalGroups = g_PlayedGamemodes.Length;
        int excludeStart = totalGroups - subgroupExclude;
        return (index >= excludeStart && index < totalGroups);
    }
}

public int NativeMMC_GetCurrentVoteId(Handle plugin, int numParams)
{
    if (strlen(g_sCurrentVoteId) == 0)
    {
        return false;
    }
    
    int maxlen = GetNativeCell(2);
    SetNativeString(1, g_sCurrentVoteId, maxlen);
    return true;
}

public int NativeMMC_SetNextMap(Handle plugin, int numParams)
{
    char sMap[PLATFORM_MAX_PATH];
    GetNativeString(1, sMap, sizeof(sMap));
    ReplaceString(sMap, sizeof(sMap), ".bsp", "");
    
    if (strlen(sMap) == 0)
    {
        return false;
    }
    
    int iTiming = GetNativeCell(2);
    if (iTiming < 1 || iTiming > 3)
    {
        return false;
    }
    
    char sGroup[64];
    char sSubGroup[64];
    GetNativeString(3, sGroup, sizeof(sGroup));
    GetNativeString(4, sSubGroup, sizeof(sSubGroup));
    
    bool bGroupSpecified = (strlen(sGroup) > 0);
    ArrayList gameModes = GetGameModesList();
    bool bMapFound = false;
    
    if (bGroupSpecified)
    {
        int iGroupIndex = MMC_FindGameModeIndex(sGroup);
        if (iGroupIndex != -1)
        {
            GameModeConfig config;
            gameModes.GetArray(iGroupIndex, config);
            
            if (strlen(sSubGroup) > 0)
            {
                int iSubGroupIndex = MMC_FindSubGroupIndex(sGroup, sSubGroup);
                if (iSubGroupIndex != -1)
                {
                    SubGroupConfig subConfig;
                    config.subGroups.GetArray(iSubGroupIndex, subConfig);
                    if (subConfig.maps.FindString(sMap) != -1)
                    {
                        bMapFound = true;
                    }
                }
            }
            else if (config.maps.FindString(sMap) != -1)
            {
                bMapFound = true;
            }
        }
    }
    else
    {
        for (int i = 0; i < gameModes.Length; i++)
        {
            GameModeConfig config;
            gameModes.GetArray(i, config);
            
            if (config.maps.FindString(sMap) != -1)
            {
                strcopy(sGroup, sizeof(sGroup), config.name);
                sSubGroup[0] = '\0';
                bMapFound = true;
                break;
            }
            
            for (int j = 0; j < config.subGroups.Length; j++)
            {
                SubGroupConfig subConfig;
                config.subGroups.GetArray(j, subConfig);
                if (subConfig.maps.FindString(sMap) != -1)
                {
                    strcopy(sGroup, sizeof(sGroup), config.name);
                    strcopy(sSubGroup, sizeof(sSubGroup), subConfig.name);
                    bMapFound = true;
                    break;
                }
            }
            
            if (bMapFound)
                break;
        }
        
        if (!bMapFound)
        {
            strcopy(sGroup, sizeof(sGroup), "NoN");
            sSubGroup[0] = '\0';
        }
    }
    
    ExecuteModeChange(sGroup, sMap, iTiming - 1, sSubGroup);
    return true;
}

void NativeMMC_OnVoteStart(int initiator)
{
    Call_StartForward(g_OnVoteStartForward);
    Call_PushCell(initiator);
    Call_Finish();
}

void NativeMMC_OnVoteStartEx(int initiator, int voteType, bool isRunoff)
{
    Call_StartForward(g_OnVoteStartForward);
    Call_PushCell(initiator);
    Call_Finish();

    Call_StartForward(g_OnVoteStartExForward);
    Call_PushCell(initiator);
    Call_PushCell(voteType);
    Call_PushCell(isRunoff);
    Call_Finish();
}

void NativeMMC_OnVoteEnd(const char[] group, const char[] subgroup, const char[] map, VoteEndReason reason)
{
    Call_StartForward(g_OnVoteEndForward);
    Call_PushString(group);
    Call_PushString(subgroup);
    Call_PushString(map);
    Call_PushCell(view_as<int>(reason));
    Call_Finish();
}

void NativeMMC_OnGamemodeChanged(const char[] group, const char[] subgroup, const char[] map, int timing)
{
    Call_StartForward(g_OnGamemodeChangedForward);
    Call_PushString(group);
    Call_PushString(subgroup);
    Call_PushString(map);
    Call_PushCell(timing);
    Call_Finish();
}

void NativeMMC_OnGamemodeChangedVote(const char[] group, const char[] subgroup, const char[] map, int timing)
{
    Call_StartForward(g_OnGamemodeChangedVoteForward);
    Call_PushString(group);
    Call_PushString(subgroup);
    Call_PushString(map);
    Call_PushCell(timing);
    Call_Finish();
}

public int NativeMMC_StopVote(Handle plugin, int numParams)
{
    bool bWasActive = false;
    
    if (g_bVoteActive)
    {
        CancelVote();
        g_bVoteActive = false;
        bWasActive = true;
    }
    
    if (g_bCooldownActive)
    {
        g_bCooldownActive = false;
        if (g_hCooldownTimer != null)
        {
            KillTimer(g_hCooldownTimer);
            g_hCooldownTimer = INVALID_HANDLE;
        }
        bWasActive = true;
    }
    
    if (bWasActive)
    {
        g_bVoteCompleted = false;
        
        g_bIsRunoffVote = false;
        if(g_RunoffItems != null) g_RunoffItems.Clear();
        NativeMMC_OnVoteEnd("", "", "", VoteEnd_Cancelled);
    }
    
    return bWasActive;
}

public int NativeMMC_GetRandomMap(Handle plugin, int numParams)
{
    // Buffers from native call
    int groupLen = GetNativeCell(2);
    int subgroupLen = GetNativeCell(4);
    int mapLen = GetNativeCell(6);
    
    char[] groupIn = new char[groupLen];
    char[] subgroupIn = new char[subgroupLen];
    
    GetNativeString(1, groupIn, groupLen);
    GetNativeString(3, subgroupIn, subgroupLen);

    ArrayList gameModes = GetGameModesList();
    if (gameModes.Length == 0) return false;

    int groupIndex = -1;

    if (strlen(groupIn) > 0)
    {
        groupIndex = MMC_FindGameModeIndex(groupIn);
        if (groupIndex == -1) return false;
    }
    else
    {
        ArrayList validGroups = new ArrayList();
        for (int i = 0; i < gameModes.Length; i++)
        {
            GameModeConfig cfg;
            gameModes.GetArray(i, cfg);
            if (cfg.enabled && !cfg.adminonly && (cfg.maps.Length > 0 || cfg.subGroups.Length > 0))
            {
                validGroups.Push(i);
            }
        }
        if (validGroups.Length == 0) 
        {
            delete validGroups;
            return false;
        }
        
        groupIndex = validGroups.Get(GetRandomInt(0, validGroups.Length - 1));
        delete validGroups;
    }
    
    GameModeConfig config;
    gameModes.GetArray(groupIndex, config);

    char finalMap[PLATFORM_MAX_PATH];
    char finalSubgroup[64] = "";

    if (strlen(subgroupIn) > 0)
    {
        int subIndex = MMC_FindSubGroupIndex(config.name, subgroupIn);
        if (subIndex == -1 || !IsSubgroupValid(config, subIndex)) return false;
        
        SubGroupConfig subCfg;
        config.subGroups.GetArray(subIndex, subCfg);
        if (subCfg.maps.Length == 0) return false;

        subCfg.maps.GetString(GetRandomInt(0, subCfg.maps.Length - 1), finalMap, sizeof(finalMap));
        strcopy(finalSubgroup, sizeof(finalSubgroup), subCfg.name);
    }
    else
    {
        ArrayList mapPool = new ArrayList(ByteCountToCells(PLATFORM_MAX_PATH));
        StringMap mapToSubgroup = new StringMap();

        for (int i = 0; i < config.maps.Length; i++)
        {
            char mapName[PLATFORM_MAX_PATH];
            config.maps.GetString(i, mapName, sizeof(mapName));
            mapPool.PushString(mapName);
            mapToSubgroup.SetString(mapName, "");
        }

        for (int i = 0; i < config.subGroups.Length; i++)
        {
            if (!IsSubgroupValid(config, i)) continue;
            SubGroupConfig subCfg;
            config.subGroups.GetArray(i, subCfg);
            for (int j = 0; j < subCfg.maps.Length; j++)
            {
                char mapName[PLATFORM_MAX_PATH];
                subCfg.maps.GetString(j, mapName, sizeof(mapName));
                if (mapPool.FindString(mapName) == -1) // Avoid duplicates
                {
                    mapPool.PushString(mapName);
                    mapToSubgroup.SetString(mapName, subCfg.name);
                }
            }
        }

        if (mapPool.Length == 0)
        {
            delete mapPool;
            delete mapToSubgroup;
            return false;
        }

        mapPool.GetString(GetRandomInt(0, mapPool.Length - 1), finalMap, sizeof(finalMap));
        mapToSubgroup.GetString(finalMap, finalSubgroup, sizeof(finalSubgroup));

        delete mapPool;
        delete mapToSubgroup;
    }

    SetNativeString(1, config.name, groupLen);
    SetNativeString(3, finalSubgroup, subgroupLen);
    SetNativeString(5, finalMap, mapLen);
    
    return true;
}

public int NativeMMC_CanStopVote(Handle plugin, int numParams)
{
    return g_bVoteActive || g_bCooldownActive;
}

public int NativeMMC_IsCooldownActive(Handle plugin, int numParams)
{
    return g_bCooldownActive;
}

public int NativeMMC_IsVoteCompleted(Handle plugin, int numParams)
{
    return g_bVoteCompleted;
}

public int NativeMMC_IsMapNominated(Handle plugin, int numParams)
{
    char group[64], subgroup[64], map[PLATFORM_MAX_PATH];
    GetNativeString(1, group, sizeof(group));
    GetNativeString(2, subgroup, sizeof(subgroup));
    GetNativeString(3, map, sizeof(map));

    char key[128];
    if (strlen(subgroup) > 0)
    {
        Format(key, sizeof(key), "%s/%s", group, subgroup);
    }
    else
    {
        strcopy(key, sizeof(key), group);
    }

    ArrayList mapsNominated;
    if (g_NominatedMaps.GetValue(key, mapsNominated))
    {
        return (mapsNominated.FindString(map) != -1);
    }

    return false;
}

public int NativeMMC_IsGroupNominated(Handle plugin, int numParams)
{
    char group[64], subgroup[64];
    GetNativeString(1, group, sizeof(group));
    GetNativeString(2, subgroup, sizeof(subgroup));

    char key[128];
    if (strlen(subgroup) > 0)
    {
        Format(key, sizeof(key), "%s/%s", group, subgroup);
        return (g_NominatedGamemodes.FindString(key) != -1);
    }
    
    return (g_NominatedGamemodes.FindString(group) != -1);
}

public int NativeMMC_RegisterVoteManager(Handle plugin, int numParams)
{
    char name[64];
    GetNativeString(1, name, sizeof(name));
    
    Function startFn = GetNativeFunction(2);
    Function cancelFn = GetNativeFunction(3);

    if (startFn == INVALID_FUNCTION || cancelFn == INVALID_FUNCTION)
    {
        LogError("[MultiMode Core] Invalid functions provided for vote manager '%s'", name);
        return 0;
    }
    
    VoteManagerEntry entry;
    entry.start_group = startFn;
    entry.start_subgroup = startFn;
    entry.start_map = startFn;
    entry.cancel = cancelFn;
    entry.plugin = plugin;
    
    if (g_VoteManagers == null)
    {
        g_VoteManagers = new StringMap();
        MMC_WriteToLogFile(g_Cvar_Logs, "[MultiMode Core] g_VoteManagers was null, created new instance");
    }
    
    VoteManagerEntry oldEntry;
    if (g_VoteManagers.GetArray(name, oldEntry, sizeof(oldEntry)))
    {
        if (g_VoteManagersBackup == null)
        {
            g_VoteManagersBackup = new StringMap();
        }
        g_VoteManagersBackup.SetArray(name, oldEntry, sizeof(oldEntry));
        MMC_WriteToLogFile(g_Cvar_Logs, "[MultiMode Core] Vote Manager '%s' already exists, backing up the old one, ready to use.", name);
    }
    
    g_VoteManagers.SetArray(name, entry, sizeof(entry));
    MMC_WriteToLogFile(g_Cvar_Logs, "[MultiMode Core] Registered Vote Manager: %s", name);
    return 0;
}

public int NativeMMC_RegisterVoteManagerEx(Handle plugin, int numParams)
{
    char name[64];
    GetNativeString(1, name, sizeof(name));
    
    VoteManagerEntry entry;
    entry.start_group = GetNativeFunction(2);
    entry.start_subgroup = GetNativeFunction(3);
    entry.start_map = GetNativeFunction(4);
    entry.cancel = GetNativeFunction(5);
    entry.plugin = plugin;
    
    VoteManagerEntry oldEntry;
    if (g_VoteManagers.GetArray(name, oldEntry, sizeof(oldEntry)))
    {
        g_VoteManagersBackup.SetArray(name, oldEntry, sizeof(oldEntry));
        MMC_WriteToLogFile(g_Cvar_Logs, "[MultiMode Core] Vote Manager '%s' already exists, backing up the old one, ready to use.", name);
    }
    
    g_VoteManagers.SetArray(name, entry, sizeof(entry));
    MMC_WriteToLogFile(g_Cvar_Logs, "[MultiMode Core] Registered Vote Manager: %s", name);
    return 0;
}

public int NativeMMC_UnregisterVoteManager(Handle plugin, int numParams)
{
    char name[64];
    GetNativeString(1, name, sizeof(name));
    
    VoteManagerEntry backupEntry;
    if (g_VoteManagersBackup.GetArray(name, backupEntry, sizeof(backupEntry)))
    {
        g_VoteManagers.SetArray(name, backupEntry, sizeof(backupEntry));
        g_VoteManagersBackup.Remove(name); // Remove from backup since it's active now
        MMC_WriteToLogFile(g_Cvar_Logs, "[MultiMode Core] Unregistered Vote Manager '%s'. Restored backup manager.", name);
    }
    else
    {
        g_VoteManagers.Remove(name);
        MMC_WriteToLogFile(g_Cvar_Logs, "[MultiMode Core] Unregistered Vote Manager '%s'. No backup found.", name);
    }
    
    return 0;
}

public int NativeMMC_ReportVoteResults(Handle plugin, int numParams)
{
    ArrayList results = view_as<ArrayList>(GetNativeCell(1));
    int totalVotes = GetNativeCell(2);
    int totalClients = GetNativeCell(3);
    
    ProcessVoteLogic(g_eCurrentNativeVoteType, totalVotes, totalClients, results);
    return 0;
}

public int NativeMMC_GetGamemodeList(Handle plugin, int numParams)
{
    ArrayList gamemodes = view_as<ArrayList>(GetNativeCell(1));
    bool includeDisabled = GetNativeCell(2);
    bool includeAdminOnly = GetNativeCell(3);
    
    if (gamemodes == null)
    {
        LogError("[Multimode] Invalid ArrayList provided to Multimode_GetGamemodeList");
        return 0;
    }
    
    ArrayList gameModesList = GetGameModesList();
    int count = 0;
    
    for (int i = 0; i < gameModesList.Length; i++)
    {
        GameModeConfig config;
        gameModesList.GetArray(i, config);
        
        if (!includeDisabled && !config.enabled)
            continue;
            
        if (!includeAdminOnly && config.adminonly)
            continue;
        
        gamemodes.PushString(config.name);
        count++;
    }
    
    return count;
}

public int NativeMMC_GetSubgroupList(Handle plugin, int numParams)
{
    char gamemode[64];
    GetNativeString(1, gamemode, sizeof(gamemode));
    
    ArrayList subgroups = view_as<ArrayList>(GetNativeCell(2));
    bool includeDisabled = GetNativeCell(3);
    bool includeAdminOnly = GetNativeCell(4);
    
    if (subgroups == null)
    {
        LogError("[Multimode] Invalid ArrayList provided to Multimode_GetSubgroupList");
        return -1;
    }
    
    int groupIndex = MMC_FindGameModeIndex(gamemode);
    if (groupIndex == -1)
    {
        return -1;
    }
    
    ArrayList gameModesList = GetGameModesList();
    GameModeConfig config;
    gameModesList.GetArray(groupIndex, config);
    
    int count = 0;
    for (int i = 0; i < config.subGroups.Length; i++)
    {
        SubGroupConfig subConfig;
        config.subGroups.GetArray(i, subConfig);
        
        if (!includeDisabled && !subConfig.enabled)
            continue;
            
        if (!includeAdminOnly && subConfig.adminonly)
            continue;
        
        subgroups.PushString(subConfig.name);
        count++;
    }
    
    return count;
}

public int NativeMMC_GetMapList(Handle plugin, int numParams)
{
    char gamemode[64];
    GetNativeString(1, gamemode, sizeof(gamemode));
    
    char subgroup[64];
    GetNativeString(2, subgroup, sizeof(subgroup));
    
    ArrayList maps = view_as<ArrayList>(GetNativeCell(3));
    
    if (maps == null)
    {
        LogError("[Multimode] Invalid ArrayList provided to Multimode_GetMapList");
        return -1;
    }
    
    int groupIndex = MMC_FindGameModeIndex(gamemode);
    if (groupIndex == -1)
    {
        return -1;
    }
    
    ArrayList gameModesList = GetGameModesList();
    GameModeConfig config;
    gameModesList.GetArray(groupIndex, config);
    
    int count = 0;
    
    if (strlen(subgroup) > 0)
    {
        int subgroupIndex = MMC_FindSubGroupIndex(gamemode, subgroup);
        if (subgroupIndex == -1)
        {
            return -1;
        }
        
        SubGroupConfig subConfig;
        config.subGroups.GetArray(subgroupIndex, subConfig);
        
        for (int i = 0; i < subConfig.maps.Length; i++)
        {
            char map[PLATFORM_MAX_PATH];
            subConfig.maps.GetString(i, map, sizeof(map));
            maps.PushString(map);
            count++;
        }
    }
    else
    {
        for (int i = 0; i < config.maps.Length; i++)
        {
            char map[PLATFORM_MAX_PATH];
            config.maps.GetString(i, map, sizeof(map));
            maps.PushString(map);
            count++;
        }
    }
    
    return count;
}

public int NativeMMC_RemoveNomination(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    int index = GetNativeCell(2);
    
    if (client < 1 || client > MaxClients || !IsClientInGame(client))
        return false;
    
    if (g_PlayerNominations[client] == null || index < 0 || index >= g_PlayerNominations[client].Length)
        return false;
    
    RemoveClientNomination(client, index, false);
    return true;
}

public int NativeMMC_RemoveAllNominations(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    
    if (client < 1 || client > MaxClients || !IsClientInGame(client))
        return 0;
    
    if (g_PlayerNominations[client] == null)
        return 0;
    
    int count = g_PlayerNominations[client].Length;
    RemoveAllClientNominations(client, false);
    return count;
}

public int NativeMMC_GetClientNominationCount(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    
    if (client < 1 || client > MaxClients || !IsClientInGame(client))
        return 0;
    
    if (g_PlayerNominations[client] == null)
        return 0;
    
    return g_PlayerNominations[client].Length;
}

public int NativeMMC_GetClientNomination(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    int index = GetNativeCell(2);
    
    if (client < 1 || client > MaxClients || !IsClientInGame(client))
        return false;
    
    if (g_PlayerNominations[client] == null || index < 0 || index >= g_PlayerNominations[client].Length)
        return false;
    
    NominationInfo nInfo;
    g_PlayerNominations[client].GetArray(index, nInfo);
    
    int groupMaxLen = GetNativeCell(4);
    int subgroupMaxLen = GetNativeCell(6);
    int mapMaxLen = GetNativeCell(8);
    
    SetNativeString(3, nInfo.group, groupMaxLen);
    SetNativeString(5, nInfo.subgroup, subgroupMaxLen);
    SetNativeString(7, nInfo.map, mapMaxLen);
    
    return true;
}

// //////////////////////////
// //                      //
// //    Commands Extra    //
// //                      //
// //////////////////////////

// Commands Extra

public Action Command_SetNextMap(int client, int args)
{
    char sMap[PLATFORM_MAX_PATH];
    GetCmdArg(1, sMap, sizeof(sMap));
    ReplaceString(sMap, sizeof(sMap), ".bsp", "");

    char sTiming[8];
    GetCmdArg(2, sTiming, sizeof(sTiming));
    int iTiming = StringToInt(sTiming);

    if (iTiming < 1 || iTiming > 3)
    {
        ReplyToCommand(client, "[MultiMode] Error: Invalid timing. Use 1, 2 ou 3.");
        return Plugin_Handled;
    }

    char sGroup[64];
    char sSubGroup[64];
    bool bGroupSpecified = false;

    if (args >= 3)
    {
        GetCmdArg(3, sGroup, sizeof(sGroup));
        bGroupSpecified = true;
        if (args >= 4)
        {
            GetCmdArg(4, sSubGroup, sizeof(sSubGroup));
        }
        else
        {
            sSubGroup[0] = '\0';
        }
    }

    ArrayList gameModes = GetGameModesList();
    bool bMapFound = false;

    if (bGroupSpecified)
    {
        int iGroupIndex = MMC_FindGameModeIndex(sGroup);
        if (iGroupIndex != -1)
        {
            GameModeConfig config;
            gameModes.GetArray(iGroupIndex, config);

            if (strlen(sSubGroup) > 0)
            {
                int iSubGroupIndex = MMC_FindSubGroupIndex(sGroup, sSubGroup);
                if (iSubGroupIndex != -1)
                {
                    SubGroupConfig subConfig;
                    config.subGroups.GetArray(iSubGroupIndex, subConfig);
                    if (subConfig.maps.FindString(sMap) != -1)
                    {
                        bMapFound = true;
                    }
                }
            }
            else if (config.maps.FindString(sMap) != -1)
            {
                bMapFound = true;
            }
        }
    }
    else
    {
        for (int i = 0; i < gameModes.Length; i++)
        {
            GameModeConfig config;
            gameModes.GetArray(i, config);

            if (config.maps.FindString(sMap) != -1)
            {
                strcopy(sGroup, sizeof(sGroup), config.name);
                sSubGroup[0] = '\0';
                bMapFound = true;
                break;
            }

            for (int j = 0; j < config.subGroups.Length; j++)
            {
                SubGroupConfig subConfig;
                config.subGroups.GetArray(j, subConfig);
                if (subConfig.maps.FindString(sMap) != -1)
                {
                    strcopy(sGroup, sizeof(sGroup), config.name);
                    strcopy(sSubGroup, sizeof(sSubGroup), subConfig.name);
                    bMapFound = true;
                    break;
                }
            }

            if (bMapFound)
                break;
        }

        if (!bMapFound)
        {
            strcopy(sGroup, sizeof(sGroup), "NoN");
            sSubGroup[0] = '\0';
            ReplyToCommand(client, "[MultiMode] Warning: Map '%s' not found in the map cycle.", sMap);
        }
    }

    ReplyToCommand(client, "[MultiMode] Setting next map to '%s' (Group: %s, Subgroup: %s).", sMap, sGroup, strlen(sSubGroup) > 0 ? sSubGroup : "NoN");
    ExecuteModeChange(sGroup, sMap, iTiming - 1, sSubGroup);

    return Plugin_Handled;
}

public Action Command_CancelVote(int client, int args)
{
    bool bWasActive = false;
    
    if (g_bVoteActive)
    {
        CancelVote();
        g_bVoteActive = false;
        bWasActive = true;
    }
    
    if (g_bCooldownActive)
    {
        g_bCooldownActive = false;
        KillTimer(g_hCooldownTimer);
        g_hCooldownTimer = INVALID_HANDLE;
        bWasActive = true;
    }
    
    if (bWasActive)
    {
        g_bVoteCompleted = false;
        
        PlayVoteSound(false, g_bIsRunoffVote);
        g_bIsRunoffVote = false;
        
        CPrintToChatAll("%t", "Admin Cancel Vote", client);
		NativeMMC_OnVoteEnd("", "", "", VoteEnd_Cancelled);
    }
    else
    {
        CPrintToChat(client, "%t", "Admin Cancel No Vote");
    }
    
    return Plugin_Handled;
}

public Action Command_MultimodeVersion(int client, int args)
{
    CReplyToCommand(client, "%t", "Current MMC Version", PLUGIN_VERSION);
	
    return Plugin_Handled;
}

public Action Command_ListVoteManagers(int client, int args)
{
    int count = 0;
    StringMapSnapshot snapshot = g_VoteManagers.Snapshot();
    
    for (int i = 0; i < snapshot.Length; i++)
    {
        char managerName[64];
        snapshot.GetKey(i, managerName, sizeof(managerName));
        
        VoteManagerEntry entry;
        if (g_VoteManagers.GetArray(managerName, entry, sizeof(entry)))
        {
            char pluginName[64];
            GetPluginFilename(entry.plugin, pluginName, sizeof(pluginName));
            
            ReplyToCommand(client, "%d. %s (Plugin: %s)", ++count, managerName, pluginName);
        }
    }
    
    delete snapshot;
    
    if (count == 0)
    {
        ReplyToCommand(client, "No Vote Manager registered.");
    }
    else
    {
        ReplyToCommand(client, "Total: %d Vote Manager(s)", count);
    }
    
    return Plugin_Handled;
}

void ExecuteModeChange(const char[] gamemode, const char[] map, int timing, const char[] subgroup = "")
{
    CancelCurrentVote();

    if (g_bCooldownActive)
    {
        g_bCooldownActive = false;
        if (g_hCooldownTimer != null)
        {
            KillTimer(g_hCooldownTimer);
            g_hCooldownTimer = INVALID_HANDLE;
        }
    }
    
    TimingMode mode = view_as<TimingMode>(timing);
    char command[256];
    strcopy(g_sNextGameMode, sizeof(g_sNextGameMode), gamemode);
    strcopy(g_sNextMap, sizeof(g_sNextMap), map);
    strcopy(g_sNextSubGroup, sizeof(g_sNextSubGroup), subgroup);
	
	NativeMMC_OnGamemodeChanged(gamemode, subgroup, map, timing);
    
    if (g_kvGameModes.JumpToKey(gamemode))
    {
        g_kvGameModes.GetString(MAPCYCLE_KEY_COMMAND, command, sizeof(command));
        g_kvGameModes.Rewind();
    }

    switch(mode)
    {
        case TIMING_NEXTMAP:
        {
            SetNextMap(g_sNextMap);
            CPrintToChatAll("%t", "Timing NextMap Notify", g_sNextMap);
            MMC_WriteToLogFile(g_Cvar_Logs, "[MultiMode Core] Next map set (admin): %s", g_sNextMap);
        }
        
        case TIMING_NEXTROUND:
        {
            SetNextMap(g_sNextMap);
            g_bChangeMapNextRound = true;
            CPrintToChatAll("%t", "Timing NextRound Notify", g_sNextMap);
            MMC_WriteToLogFile(g_Cvar_Logs, "[MultiMode Core] Next round map set (admin): %s", g_sNextMap);
        }
        
        case TIMING_INSTANT:
        {
            char game[20];
            GetGameFolderName(game, sizeof(game));
            SetNextMap(g_sNextMap);
            ConVar mp_tournament = FindConVar("mp_tournament");
	
            if (mp_tournament != null && mp_tournament.BoolValue)
            {
                ForceChangeLevel(g_sNextMap, "Map modified by admin");
            }
            else
            {
                if (!StrEqual(game, "gesource", false) && !StrEqual(game, "zps", false))
                {
                    int iGameEnd = FindEntityByClassname(-1, "game_end");
                    if (iGameEnd == -1 && (iGameEnd = CreateEntityByName("game_end")) == -1)
                    {
                        ForceChangeLevel(g_sNextMap, "Map modified by admin");
                    } 
                    else 
                    {     
                        AcceptEntityInput(iGameEnd, "EndGame");
                    }
                }
                else
                {
                    ForceChangeLevel(g_sNextMap, "Map modified by admin");
                }
            }

            CPrintToChatAll("%t", "Timing Instant Notify", g_sNextMap);
            MMC_WriteToLogFile(g_Cvar_Logs, "[MultiMode Core] Map instantly set to (admin): %s", g_sNextMap);
        }
    }
}

// //////////////////////////////////////////////
// //                                          //
// //        Vote Menu System Manager          //
// //                                          //
// //////////////////////////////////////////////

// Vote Menu System Manager

ArrayList PrepareVoteItems_Group(AdvancedVoteConfig config, ArrayList runoffItems = null)
{
    ArrayList voteItems = new ArrayList(sizeof(VoteCandidate));
    ArrayList gameModes = GetGameModesList();
    
    if (gameModes == null || gameModes.Length == 0)
    {
        delete voteItems;
        return null;
    }
    
    if (runoffItems != null)
    {
        for (int i = 0; i < runoffItems.Length; i++)
        {
            char info[PLATFORM_MAX_PATH];
            runoffItems.GetString(i, info, sizeof(info));
            VoteCandidate item;
            strcopy(item.info, sizeof(item.info), info);
            strcopy(item.name, sizeof(item.name), info);
            voteItems.PushArray(item);
        }
        return voteItems;
    }
    
    int groupExclude = config.groupexclude;
    if (groupExclude == -1)
    {
        groupExclude = 0;
    }
    
    ArrayList voteSourceList = new ArrayList(ByteCountToCells(64));
    ArrayList nominatedItems = new ArrayList(ByteCountToCells(128));
    ArrayList otherItems = new ArrayList(ByteCountToCells(64));
    
    if (config.handlenominations && g_NominatedGamemodes != null)
    {
        for (int i = 0; i < g_NominatedGamemodes.Length; i++)
        {
            char nominatedGM[128];
            g_NominatedGamemodes.GetString(i, nominatedGM, sizeof(nominatedGM));
            
            if (groupExclude > 0 && g_PlayedGamemodes != null && g_PlayedGamemodes.FindString(nominatedGM) != -1)
                continue;
            
            char groupName[64];
            SplitGamemodeString(nominatedGM, groupName, sizeof(groupName), "", 0);
            int index = MMC_FindGameModeIndex(groupName);
            if (index == -1)
                continue;
            
            GameModeConfig gmConfig;
            gameModes.GetArray(index, gmConfig);
            
            bool available = config.adminvote ? MMC_GamemodeAvailableAdminVote(gmConfig.name) : MMC_GamemodeAvailable(gmConfig.name);
            
            if (available && nominatedItems.FindString(nominatedGM) == -1 && MMC_IsCurrentlyAvailableByTime(g_kvGameModes, groupName))
                nominatedItems.PushString(nominatedGM);
        }
    }
    
    for (int i = 0; i < gameModes.Length; i++)
    {
        GameModeConfig gmConfig;
        gameModes.GetArray(i, gmConfig);
        
        bool available = config.adminvote ? (gmConfig.enabled == 1) : MMC_GamemodeAvailable(gmConfig.name);
        if (!available)
            continue;
        
        if (groupExclude > 0 && g_PlayedGamemodes != null && g_PlayedGamemodes.FindString(gmConfig.name) != -1)
            continue;
        
        if (!config.handlenominations || (g_NominatedGamemodes != null && g_NominatedGamemodes.FindString(gmConfig.name) == -1))
        {
            if (MMC_IsCurrentlyAvailableByTime(g_kvGameModes, gmConfig.name))
                otherItems.PushString(gmConfig.name);
        }
    }
    
    // Sort items
    if (config.sorted == SORTED_RANDOM)
    {
        nominatedItems.Sort(Sort_Random, Sort_String);
        otherItems.Sort(Sort_Random, Sort_String);
    }
    else if (config.sorted == SORTED_ALPHABETICAL)
    {
        nominatedItems.Sort(Sort_Ascending, Sort_String);
        otherItems.Sort(Sort_Ascending, Sort_String);
    }
    
    int limit = g_Cvar_VoteGroupInVoteLimit.IntValue;
    
    for (int i = 0; i < nominatedItems.Length && voteSourceList.Length < limit; i++)
    {
        char gm[128];
        nominatedItems.GetString(i, gm, sizeof(gm));
        voteSourceList.PushString(gm);
    }
    
    for (int i = 0; i < otherItems.Length && voteSourceList.Length < limit; i++)
    {
        char gm[64];
        otherItems.GetString(i, gm, sizeof(gm));
        if (voteSourceList.FindString(gm) == -1)
            voteSourceList.PushString(gm);
    }
    
    delete nominatedItems;
    delete otherItems;
    
    for (int i = 0; i < voteSourceList.Length; i++)
    {
        char gm[128];
        voteSourceList.GetString(i, gm, sizeof(gm));
        
        char actualGroup[64];
        SplitGamemodeString(gm, actualGroup, sizeof(actualGroup), "", 0);
        
        char display[128], groupDisplay[64];
        if (g_kvGameModes.JumpToKey(actualGroup))
        {
            g_kvGameModes.GetString(MAPCYCLE_KEY_DISPLAY, groupDisplay, sizeof(groupDisplay), actualGroup);
            g_kvGameModes.GoBack();
        }
        else
        {
            strcopy(groupDisplay, sizeof(groupDisplay), gm);
        }
        g_kvGameModes.Rewind();
        
        if (config.handlenominations && g_NominatedGamemodes != null && g_NominatedGamemodes.FindString(gm) != -1)
            Format(display, sizeof(display), "%s%s", groupDisplay, GESTURE_NOMINATED);
        else
            strcopy(display, sizeof(display), groupDisplay);
        
        VoteCandidate item;
        strcopy(item.info, sizeof(item.info), gm);
        strcopy(item.name, sizeof(item.name), display);
        voteItems.PushArray(item);
    }
    
    delete voteSourceList;
    return voteItems;
}

ArrayList PrepareVoteItems_SubGroup(AdvancedVoteConfig config, const char[] gamemode, ArrayList runoffItems = null)
{
    ArrayList voteItems = new ArrayList(sizeof(VoteCandidate));
    
    if (runoffItems != null)
    {
        for (int i = 0; i < runoffItems.Length; i++)
        {
            char info[PLATFORM_MAX_PATH];
            runoffItems.GetString(i, info, sizeof(info));
            VoteCandidate item;
            strcopy(item.info, sizeof(item.info), info);
            strcopy(item.name, sizeof(item.name), info);
            voteItems.PushArray(item);
        }
        return voteItems;
    }
    
    int gamemodeIndex = MMC_FindGameModeIndex(gamemode);
    if (gamemodeIndex == -1)
    {
        delete voteItems;
        return null;
    }
    
    GameModeConfig gmConfig;
    ArrayList list = GetGameModesList();
    list.GetArray(gamemodeIndex, gmConfig);
    
    if (gmConfig.subGroups == null || gmConfig.subGroups.Length == 0)
    {
        delete voteItems;
        return null;
    }
    
    ArrayList allSubGroups = new ArrayList(ByteCountToCells(64));
    
    for (int i = 0; i < gmConfig.subGroups.Length; i++)
    {
        SubGroupConfig subConfig;
        gmConfig.subGroups.GetArray(i, subConfig);
        
        if (!subConfig.enabled) continue;
        
        if (subConfig.adminonly == 1 && !config.adminvote)
            continue;
        
        int players = GetRealClientCount();
        if (subConfig.minplayers > 0 && players < subConfig.minplayers) continue;
        if (subConfig.maxplayers > 0 && players > subConfig.maxplayers) continue;
        
        allSubGroups.PushString(subConfig.name);
    }
    
    MultimodeVoteSorted sortMode = (view_as<int>(config.sorted) >= 0) ? config.sorted : SORTED_MAPCYCLE_ORDER;
    if (sortMode == SORTED_RANDOM)
    {
        allSubGroups.Sort(Sort_Random, Sort_String);
    }
    else if (sortMode == SORTED_ALPHABETICAL)
    {
        allSubGroups.Sort(Sort_Ascending, Sort_String);
    }
    
    int limit = gmConfig.subgroups_invote;
    if (limit <= 0)
    {
        limit = g_Cvar_VoteDefaultInVoteLimit.IntValue;
    }
    
    int count = allSubGroups.Length < limit ? allSubGroups.Length : limit;
    
    for (int i = 0; i < count; i++)
    {
        char subGroupName[64], display[128];
        allSubGroups.GetString(i, subGroupName, sizeof(subGroupName));
        
        if (g_kvGameModes.JumpToKey(gamemode) && g_kvGameModes.JumpToKey("subgroup") && g_kvGameModes.JumpToKey(subGroupName))
        {
            g_kvGameModes.GetString(MAPCYCLE_KEY_DISPLAY, display, sizeof(display), subGroupName);
            g_kvGameModes.GoBack();
            g_kvGameModes.GoBack();
            g_kvGameModes.GoBack();
        }
        else
        {
            strcopy(display, sizeof(display), subGroupName);
        }
        g_kvGameModes.Rewind();
        
        VoteCandidate item;
        strcopy(item.info, sizeof(item.info), subGroupName);
        strcopy(item.name, sizeof(item.name), display);
        voteItems.PushArray(item);
    }
    delete allSubGroups;
    
    return voteItems;
}

ArrayList PrepareVoteItems_Map(AdvancedVoteConfig config, const char[] gamemode, ArrayList runoffItems = null)
{
    ArrayList voteItems = new ArrayList(sizeof(VoteCandidate));
    
    if (runoffItems != null)
    {
        for (int i = 0; i < runoffItems.Length; i++)
        {
            char info[PLATFORM_MAX_PATH];
            runoffItems.GetString(i, info, sizeof(info));
            VoteCandidate item;
            strcopy(item.info, sizeof(item.info), info);
            strcopy(item.name, sizeof(item.name), info);
            voteItems.PushArray(item);
        }
        return voteItems;
    }
    
    if (strlen(gamemode) == 0)
    {
        ArrayList finalVoteList = new ArrayList(ByteCountToCells(PLATFORM_MAX_PATH));
        ArrayList listNominations = new ArrayList(ByteCountToCells(PLATFORM_MAX_PATH));
        ArrayList listRandoms = new ArrayList(ByteCountToCells(PLATFORM_MAX_PATH));
        StringMap uniqueMaps = new StringMap();
        
        if (config.handlenominations && g_NominatedMaps != null)
        {
            StringMapSnapshot snapshot = g_NominatedMaps.Snapshot();
            for (int i = 0; i < snapshot.Length; i++)
            {
                char groupKey[128];
                snapshot.GetKey(i, groupKey, sizeof(groupKey));
                
                char groupName[64];
                SplitGamemodeString(groupKey, groupName, sizeof(groupName), "", 0);
                
                bool groupAvailable = config.adminvote ? MMC_GamemodeAvailableAdminVote(groupName) : MMC_GamemodeAvailable(groupName);
                if (!groupAvailable) continue;
                
                ArrayList nominatedMaps;
                g_NominatedMaps.GetValue(groupKey, nominatedMaps);
                
                for (int j = 0; j < nominatedMaps.Length; j++)
                {
                    char map[PLATFORM_MAX_PATH];
                    nominatedMaps.GetString(j, map, sizeof(map));
                    
                    char subgroup[64] = "";
                    if (StrContains(groupKey, "/") != -1)
                    {
                        char parts[2][64];
                        ExplodeString(groupKey, "/", parts, 2, 64);
                        strcopy(subgroup, sizeof(subgroup), parts[1]);
                    }
                    
                    if (!uniqueMaps.ContainsKey(map) && MMC_IsCurrentlyAvailableByTime(g_kvGameModes, groupName, subgroup, map))
                    {
                        listNominations.PushString(map);
                        uniqueMaps.SetValue(map, true);
                    }
                }
            }
            delete snapshot;
        }
        
        ArrayList gameModes = GetGameModesList();
        for (int i = 0; i < gameModes.Length; i++)
        {
            GameModeConfig gmConfig;
            gameModes.GetArray(i, gmConfig);
            
            bool groupAvailable = config.adminvote ? MMC_GamemodeAvailableAdminVote(gmConfig.name) : MMC_GamemodeAvailable(gmConfig.name);
            if (!groupAvailable) continue;
            
            for (int j = 0; j < gmConfig.maps.Length; j++)
            {
                char map[PLATFORM_MAX_PATH];
                gmConfig.maps.GetString(j, map, sizeof(map));
                
                if (!uniqueMaps.ContainsKey(map) && MMC_IsCurrentlyAvailableByTime(g_kvGameModes, gmConfig.name, "", map))
                {
                    listRandoms.PushString(map);
                    uniqueMaps.SetValue(map, true);
                }
            }
            
            for (int k = 0; k < gmConfig.subGroups.Length; k++)
            {
                SubGroupConfig subConfig;
                gmConfig.subGroups.GetArray(k, subConfig);
                
                if (!subConfig.enabled) continue;
                if (subConfig.adminonly == 1 && !config.adminvote) continue;
                
                int players = GetRealClientCount();
                if (subConfig.minplayers > 0 && players < subConfig.minplayers) continue;
                if (subConfig.maxplayers > 0 && players > subConfig.maxplayers) continue;
                
                for (int j = 0; j < subConfig.maps.Length; j++)
                {
                    char map[PLATFORM_MAX_PATH];
                    subConfig.maps.GetString(j, map, sizeof(map));
                    
                    if (!uniqueMaps.ContainsKey(map) && MMC_IsCurrentlyAvailableByTime(g_kvGameModes, gmConfig.name, subConfig.name, map))
                    {
                        listRandoms.PushString(map);
                        uniqueMaps.SetValue(map, true);
                    }
                }
            }
        }
        delete uniqueMaps;
        
        // Sort
        if (config.sorted == SORTED_RANDOM)
        {
            listNominations.Sort(Sort_Random, Sort_String);
            listRandoms.Sort(Sort_Random, Sort_String);
        }
        else if (config.sorted == SORTED_ALPHABETICAL)
        {
            listNominations.Sort(Sort_Ascending, Sort_String);
            listRandoms.Sort(Sort_Ascending, Sort_String);
        }
        
        int maxItems = g_Cvar_VoteDefaultInVoteLimit.IntValue;
        int slotsNeeded = maxItems - listNominations.Length;
        
        for (int i = 0; i < slotsNeeded && i < listRandoms.Length; i++)
        {
            char map[PLATFORM_MAX_PATH];
            listRandoms.GetString(i, map, sizeof(map));
            finalVoteList.PushString(map);
        }
        
        for (int i = 0; i < listNominations.Length; i++)
        {
            char map[PLATFORM_MAX_PATH];
            listNominations.GetString(i, map, sizeof(map));
            finalVoteList.PushString(map);
        }
        
        delete listNominations;
        delete listRandoms;
        
        for (int i = 0; i < finalVoteList.Length; i++)
        {
            char map[PLATFORM_MAX_PATH], display[256];
            finalVoteList.GetString(i, map, sizeof(map));
            GetMapDisplayNameEx("", map, display, sizeof(display));
            
            bool isNominated = false;
            if (config.handlenominations && g_NominatedMaps != null)
            {
                StringMapSnapshot snapshot = g_NominatedMaps.Snapshot();
                for (int j = 0; j < snapshot.Length; j++)
                {
                    char key[128];
                    snapshot.GetKey(j, key, sizeof(key));
                    ArrayList nominatedMaps;
                    if (g_NominatedMaps.GetValue(key, nominatedMaps) && nominatedMaps.FindString(map) != -1)
                    {
                        isNominated = true;
                        break;
                    }
                }
                delete snapshot;
            }
            
            if (isNominated)
            {
                Format(display, sizeof(display), "%s%s", display, GESTURE_NOMINATED);
            }
            
            VoteCandidate item;
            strcopy(item.info, sizeof(item.info), map);
            strcopy(item.name, sizeof(item.name), display);
            voteItems.PushArray(item);
        }
        
        delete finalVoteList;
        return voteItems;
    }
    
    int index = MMC_FindGameModeIndex(gamemode);
    if (index == -1)
    {
        delete voteItems;
        return null;
    }
    
    GameModeConfig gmConfig;
    ArrayList list = GetGameModesList();
    list.GetArray(index, gmConfig);
    
    if (gmConfig.maps == null || gmConfig.maps.Length == 0)
    {
        delete voteItems;
        return null;
    }
    
    int mapExclude = config.mapexclude;
    if (mapExclude == -1)
    {
        mapExclude = (config.mapexclude >= 0) ? config.mapexclude : 0;
    }
    
    ArrayList voteMaps = new ArrayList(ByteCountToCells(PLATFORM_MAX_PATH));
    ArrayList mapsNominated;
    
    char key[128];
    strcopy(key, sizeof(key), gamemode);
    
    if (g_NominatedMaps.GetValue(key, mapsNominated) && mapsNominated != null && mapsNominated.Length > 0)
    {
        ArrayList nominateList = view_as<ArrayList>(CloneHandle(mapsNominated));
        MultimodeVoteSorted sortMode = (view_as<int>(config.sorted) >= 0) ? config.sorted : SORTED_MAPCYCLE_ORDER;
        if (sortMode == SORTED_RANDOM)
        {
            nominateList.Sort(Sort_Random, Sort_String);
        }
        else if (sortMode == SORTED_ALPHABETICAL)
        {
            nominateList.Sort(Sort_Ascending, Sort_String);
        }
        
        for (int i = 0; i < nominateList.Length; i++)
        {
            char map[PLATFORM_MAX_PATH];
            nominateList.GetString(i, map, sizeof(map));
            
            if (mapExclude > 0)
            {
                ArrayList playedMaps;
                if (g_PlayedMaps.GetValue(key, playedMaps) && playedMaps.FindString(map) != -1)
                {
                    continue;
                }
            }
            
            if (IsMapValid(map) && voteMaps.FindString(map) == -1)
            {
                voteMaps.PushString(map);
            }
        }
        delete nominateList;
    }
    
    int limit = gmConfig.maps_invote;
    if (limit <= 0)
    {
        limit = g_Cvar_VoteDefaultInVoteLimit.IntValue;
    }
    
    int needed = limit - voteMaps.Length;
    if (needed > 0)
    {
        ArrayList availableMaps = new ArrayList(ByteCountToCells(PLATFORM_MAX_PATH));
        for (int i = 0; i < gmConfig.maps.Length; i++)
        {
            char map[PLATFORM_MAX_PATH];
            gmConfig.maps.GetString(i, map, sizeof(map));
            if (IsMapValid(map) && voteMaps.FindString(map) == -1 && (mapsNominated == null || mapsNominated.FindString(map) == -1))
            {
                if (mapExclude > 0)
                {
                    ArrayList playedMaps;
                    if (g_PlayedMaps.GetValue(key, playedMaps) && playedMaps.FindString(map) != -1)
                        continue;
                }
                availableMaps.PushString(map);
            }
        }
        
        MultimodeVoteSorted sortMode = (view_as<int>(config.sorted) >= 0) ? config.sorted : SORTED_MAPCYCLE_ORDER;
        if (sortMode == SORTED_RANDOM)
        {
            availableMaps.Sort(Sort_Random, Sort_String);
        }
        
        int count = (availableMaps.Length < needed) ? availableMaps.Length : needed;
        for (int i = 0; i < count; i++)
        {
            char map[PLATFORM_MAX_PATH];
            availableMaps.GetString(i, map, sizeof(map));
            voteMaps.PushString(map);
        }
        delete availableMaps;
    }
    
    MultimodeVoteSorted sortMode = (view_as<int>(config.sorted) >= 0) ? config.sorted : SORTED_MAPCYCLE_ORDER;
    if (sortMode == SORTED_RANDOM)
    {
        voteMaps.Sort(Sort_Random, Sort_String);
    }
    else if (sortMode == SORTED_ALPHABETICAL)
    {
        voteMaps.Sort(Sort_Ascending, Sort_String);
    }
    
    for (int i = 0; i < voteMaps.Length; i++)
    {
        char map[PLATFORM_MAX_PATH], display[256];
        voteMaps.GetString(i, map, sizeof(map));
        GetMapDisplayNameEx(gamemode, map, display, sizeof(display));
        
        if (mapsNominated != null && mapsNominated.FindString(map) != -1)
        {
            Format(display, sizeof(display), "%s%s", display, GESTURE_NOMINATED);
        }
        
        VoteCandidate item;
        strcopy(item.info, sizeof(item.info), map);
        strcopy(item.name, sizeof(item.name), display);
        voteItems.PushArray(item);
    }
    
    delete voteMaps;
    return voteItems;
}

ArrayList PrepareVoteItems_SubGroupMap(AdvancedVoteConfig config, const char[] gamemode, const char[] subgroup, ArrayList runoffItems = null)
{
    ArrayList voteItems = new ArrayList(sizeof(VoteCandidate));
    
    if (runoffItems != null)
    {
        for (int i = 0; i < runoffItems.Length; i++)
        {
            char info[PLATFORM_MAX_PATH];
            runoffItems.GetString(i, info, sizeof(info));
            VoteCandidate item;
            strcopy(item.info, sizeof(item.info), info);
            strcopy(item.name, sizeof(item.name), info);
            voteItems.PushArray(item);
        }
        return voteItems;
    }
    
    int gamemodeIndex = MMC_FindGameModeIndex(gamemode);
    if (gamemodeIndex == -1)
    {
        delete voteItems;
        return null;
    }
    
    int subgroupIndex = MMC_FindSubGroupIndex(gamemode, subgroup);
    if (subgroupIndex == -1)
    {
        delete voteItems;
        return null;
    }
    
    GameModeConfig gmConfig;
    ArrayList list = GetGameModesList();
    list.GetArray(gamemodeIndex, gmConfig);
    
    SubGroupConfig subConfig;
    gmConfig.subGroups.GetArray(subgroupIndex, subConfig);
    
    if (subConfig.maps == null || subConfig.maps.Length == 0)
    {
        delete voteItems;
        return null;
    }
    
    ArrayList voteMaps = new ArrayList(ByteCountToCells(PLATFORM_MAX_PATH));
    for (int i = 0; i < subConfig.maps.Length; i++)
    {
        char map[PLATFORM_MAX_PATH];
        subConfig.maps.GetString(i, map, sizeof(map));
        
        if (IsMapValid(map) && MMC_IsCurrentlyAvailableByTime(g_kvGameModes, gamemode, subgroup, map))
        {
            voteMaps.PushString(map);
        }
    }
    
    if (voteMaps.Length == 0)
    {
        delete voteItems;
        delete voteMaps;
        return null;
    }
    
    MultimodeVoteSorted sortMode = (view_as<int>(config.sorted) >= 0) ? config.sorted : SORTED_MAPCYCLE_ORDER;
    if (sortMode == SORTED_RANDOM)
    {
        voteMaps.Sort(Sort_Random, Sort_String);
    }
    else if (sortMode == SORTED_ALPHABETICAL)
    {
        voteMaps.Sort(Sort_Ascending, Sort_String);
    }
    
    int maxItems = 6;
    if (voteMaps.Length > maxItems)
    {
        voteMaps.Resize(maxItems);
    }
    
    for (int i = 0; i < voteMaps.Length; i++)
    {
        char map[PLATFORM_MAX_PATH], display[256];
        voteMaps.GetString(i, map, sizeof(map));
        GetMapDisplayNameEx(gamemode, map, display, sizeof(display), subgroup);
        
        VoteCandidate item;
        strcopy(item.info, sizeof(item.info), map);
        strcopy(item.name, sizeof(item.name), display);
        voteItems.PushArray(item);
    }
    
    delete voteMaps;
    return voteItems;
}


public int SubGroupVoteHandler(Menu menu, MenuAction action, int param1, int param2)
{
    if (action == MenuAction_End)
    {
        delete menu;
        g_bVoteActive = false;
    }
    return 0;
}

public void SubGroupVoteResultHandler(Menu menu, int num_votes, int num_clients, const int[][] client_info, int num_items, const int[][] item_info)
{
    ProcessVoteResults(menu, num_votes, num_clients, item_info, num_items, VOTE_TYPE_SUBGROUP);
}

public int GameModeVoteHandler(Menu menu, MenuAction action, int param1, int param2)
{
    if (action == MenuAction_End)
    {
        delete menu;
        g_bVoteActive = false;
    }
    return 0;
}

public void GameModeVoteResultHandler(Menu menu, int num_votes, int num_clients, const int[][] client_info, int num_items, const int[][] item_info)
{
    ProcessVoteResults(menu, num_votes, num_clients, item_info, num_items, VOTE_TYPE_GROUP);
}


public int MapVoteHandler(Menu menu, MenuAction action, int param1, int param2) 
{
    if (action == MenuAction_End) 
    {
        delete menu;
        g_bVoteActive = false;
    }
    return 0;
}

public void MapVoteResultHandler(Menu menu, int num_votes, int num_clients, const int[][] client_info, int num_items, const int[][] item_info)
{
    ProcessVoteResults(menu, num_votes, num_clients, item_info, num_items, VOTE_TYPE_MAP);
}


public int SubGroupMapVoteHandler(Menu menu, MenuAction action, int param1, int param2)
{
    if (action == MenuAction_End)
    {
        delete menu;
        g_bVoteActive = false;
    }
    return 0;
}

public void SubGroupMapVoteResultHandler(Menu menu, int num_votes, int num_clients, const int[][] client_info, int num_items, const int[][] item_info)
{
    ProcessVoteResults(menu, num_votes, num_clients, item_info, num_items, VOTE_TYPE_SUBGROUP_MAP);
}

// //////////////////////////////////////////////
// //                                          //
// //       Core Voting System Manager         //
// //                                          //
// //////////////////////////////////////////////

// Core Voting System Manager

public void Core_StartVote(int initiator, VoteType type, const char[] info, ArrayList items, int duration, bool adminVote, bool isRunoff, const char[] startSound, const char[] endSound, const char[] runoffstartSound, const char[] runoffendSound)
{
    Menu menu = new Menu(Core_VoteHandler);
    menu.VoteResultCallback = Core_VoteResultHandler;
    
    char title[256];
    switch(type)
    {
        case VOTE_TYPE_GROUP: Format(title, sizeof(title), "%T", "Normal Vote Gamemode Group Title", LANG_SERVER);
        case VOTE_TYPE_SUBGROUP: Format(title, sizeof(title), "%T", "SubGroup Vote Title", LANG_SERVER, info);
        case VOTE_TYPE_MAP: Format(title, sizeof(title), "%T", "Start Map Vote Title", LANG_SERVER, info);
        case VOTE_TYPE_SUBGROUP_MAP: Format(title, sizeof(title), "%T", "SubGroup Map Vote Title", LANG_SERVER, info);
    }
    menu.SetTitle(title);
    
    strcopy(g_CurrentVoteConfig.startSound, sizeof(g_CurrentVoteConfig.startSound), startSound);
    strcopy(g_CurrentVoteConfig.endSound, sizeof(g_CurrentVoteConfig.endSound), endSound);
    strcopy(g_CurrentVoteConfig.runoffstartSound, sizeof(g_CurrentVoteConfig.runoffstartSound), runoffstartSound);
    strcopy(g_CurrentVoteConfig.runoffendSound, sizeof(g_CurrentVoteConfig.runoffendSound), runoffendSound);
    
    if (startSound[0] != '\0')
    {
        strcopy(g_PreservedStartSound, sizeof(g_PreservedStartSound), startSound);
    }
    if (endSound[0] != '\0')
    {
        strcopy(g_PreservedEndSound, sizeof(g_PreservedEndSound), endSound);
    }
    if (runoffstartSound[0] != '\0')
    {
        strcopy(g_PreservedRunoffStartSound, sizeof(g_PreservedRunoffStartSound), runoffstartSound);
    }
    if (runoffendSound[0] != '\0')
    {
        strcopy(g_PreservedRunoffEndSound, sizeof(g_PreservedRunoffEndSound), runoffendSound);
    }
    
    PlayVoteSound(true, isRunoff);

    for(int i = 0; i < items.Length; i++)
    {
            
        VoteCandidate item;
        items.GetArray(i, item);
        
        if (StrContains(item.name, GESTURE_NOMINATED) == -1 && 
            StrContains(item.name, GESTURE_CURRENT) == -1 &&
            StrContains(item.name, GESTURE_VOTED) == -1)
        {
            bool isNominated = false;
            
            if (type == VOTE_TYPE_GROUP || type == VOTE_TYPE_SUBGROUP)
            {
                if (g_NominatedGamemodes != null && g_NominatedGamemodes.FindString(item.info) != -1)
                {
                    isNominated = true;
                }
            }
            else if (type == VOTE_TYPE_MAP || type == VOTE_TYPE_SUBGROUP_MAP)
            {
                if (GetVoteMethod() == 3 && strlen(g_sVoteGameMode) == 0)
                {
                    StringMapSnapshot snapshot = g_NominatedMaps.Snapshot();
                    for (int j = 0; j < snapshot.Length; j++)
                    {
                        char key[128];
                        snapshot.GetKey(j, key, sizeof(key));
                        ArrayList nominatedMaps;
                        if (g_NominatedMaps.GetValue(key, nominatedMaps) && nominatedMaps.FindString(item.info) != -1)
                        {
                            isNominated = true;
                            break;
                        }
                    }
                    delete snapshot;
                }
                else
                {
                    char key[128];
                    if (type == VOTE_TYPE_SUBGROUP_MAP && strlen(g_sVoteSubGroup) > 0)
                    {
                        Format(key, sizeof(key), "%s/%s", g_sVoteGameMode, g_sVoteSubGroup);
                    }
                    else
                    {
                        strcopy(key, sizeof(key), g_sVoteGameMode);
                    }
                    
                    ArrayList mapsNominated;
                    if (g_NominatedMaps.GetValue(key, mapsNominated) && mapsNominated.FindString(item.info) != -1)
                    {
                        isNominated = true;
                    }
                }
            }
            
            if (isNominated)
            {
                char displayName[256];
                Format(displayName, sizeof(displayName), "%s%s", item.name, GESTURE_NOMINATED);
                menu.AddItem(item.info, displayName);
            }
            else
            {
                menu.AddItem(item.info, item.name);
            }
        }
        else
        {
            menu.AddItem(item.info, item.name);
        }
    }
    
    menu.ExitButton = false;
    menu.DisplayVoteToAll(duration);
    
    delete items;
}

public void Core_CancelVote()
{
    CancelVote(); 
}

public int Core_VoteHandler(Menu menu, MenuAction action, int param1, int param2)
{
    switch (action)
    {
        case MenuAction_End:
        {
            if (g_bVoteActive)
            {
                g_bVoteActive = false;
                
                if (!g_bCooldownActive)
                {
                    PlayVoteSound(false, g_bIsRunoffVote);
                    NativeMMC_OnVoteEnd("", "", "", VoteEnd_Cancelled);
                    g_bIsRunoffVote = false;
                    if(g_RunoffItems != null) g_RunoffItems.Clear();
                }
            }
            delete menu;
        }
        
        case MenuAction_VoteCancel:
        {
            if (param1 == VoteCancel_NoVotes)
            {
                ArrayList emptyResults = new ArrayList(sizeof(VoteCandidate));
                MultiMode_ReportVoteResults(emptyResults, 0, 0);
                delete emptyResults;
            }
            else
            {
                PlayVoteSound(false, g_bIsRunoffVote);
                g_bVoteActive = false;
                NativeMMC_OnVoteEnd("", "", "", VoteEnd_Cancelled);
                g_bIsRunoffVote = false;
                if(g_RunoffItems != null) g_RunoffItems.Clear();
            }
        }
    }
    return 0;
}

public void Core_VoteResultHandler(Menu menu, int num_votes, int num_clients, const int[][] client_info, int num_items, const int[][] item_info)
{
    ArrayList results = new ArrayList(sizeof(VoteCandidate));
    for (int i = 0; i < num_items; i++)
    {
        VoteCandidate res;
        res.votes = item_info[i][VOTEINFO_ITEM_VOTES];
        menu.GetItem(item_info[i][VOTEINFO_ITEM_INDEX], res.info, sizeof(res.info));
        results.PushArray(res);
    }
	
    ProcessVoteLogic(g_eCurrentNativeVoteType, num_votes, num_clients, results);
    delete results;
}

// //////////////////////////////////////////////
// //                                          //
// //    Extend Map for Normal/Admin Votes     //
// //                                          //
// //////////////////////////////////////////////

// Extend Map for Normal/Admin Votes

void ExtendMapTime()
{
    MMC_WriteToLogFile(g_Cvar_Logs, "[MultiMode Core] Stabilized Voting (Map Extension)");
    
    int extendMinutes = (g_CurrentVoteConfig.timestep > 0) ? g_CurrentVoteConfig.timestep : 6; 
    int roundStep = (g_CurrentVoteConfig.roundstep > 0) ? g_CurrentVoteConfig.roundstep : 3;
    int fragStep = (g_CurrentVoteConfig.fragstep > 0) ? g_CurrentVoteConfig.fragstep : 10;
    
    bool bExtendedRounds = false, bExtendedFrags = false;
    PerformExtension(float(extendMinutes), roundStep, fragStep, bExtendedRounds, bExtendedFrags);
    
    MMC_WriteToLogFile(g_Cvar_Logs, "The map was extended by vote by %d minutes, %d rounds and %d frags.", extendMinutes, roundStep, fragStep);

    g_bMapExtended = true;
}

void PerformExtension(float timeStep, int roundStep, int fragStep, bool &bExtendedRounds = false, bool &bExtendedFrags = false)
{
    g_bInternalChange = true;
    
    MMC_PerformExtension(timeStep, roundStep, fragStep, bExtendedRounds, bExtendedFrags);
    
    g_bInternalChange = false;
}

public void ExecuteVoteResult()
{
    g_sCurrentVoteId[0] = '\0';
    g_iGlobalMaxRunoffs = -1;
    if (GetVoteMethod() == 3 && strlen(g_sVoteMap) > 0 && strlen(g_sVoteGameMode) == 0)
    {
        int index = MMC_FindGameModeForMap(g_sVoteMap);
        if (index != -1)
        {
            GameModeConfig config;
            ArrayList list = GetGameModesList();
            list.GetArray(index, config);
            strcopy(g_sVoteGameMode, sizeof(g_sVoteGameMode), config.name);
        }
        else
        {
            MMC_WriteToLogFile(g_Cvar_Logs, "[MultiMode Core] WARNING: Method 3: Could not find gamemode for map '%s'", g_sVoteMap);
        }
    }
	
	if (strlen(g_sVoteGameMode) > 0 && strlen(g_sVoteSubGroup) > 0)
	{
		int index = MMC_FindGameModeIndex(g_sVoteGameMode);
		if (index != -1)
		{
			GameModeConfig config;
			ArrayList list = GetGameModesList();
			list.GetArray(index, config);
			
			int subgroupIndex = MMC_FindSubGroupIndex(g_sVoteGameMode, g_sVoteSubGroup);
			if (subgroupIndex == -1)
			{
				g_sVoteSubGroup[0] = '\0';
			}
			else if (strlen(g_sVoteMap) > 0)
			{
				SubGroupConfig subConfig;
				config.subGroups.GetArray(subgroupIndex, subConfig);
				if (subConfig.maps.FindString(g_sVoteMap) == -1)
				{
					g_sVoteSubGroup[0] = '\0';
				}
			}
		}
		else
		{
			g_sVoteSubGroup[0] = '\0';
		}
	}
	
	strcopy(g_sNextSubGroup, sizeof(g_sNextSubGroup), g_sVoteSubGroup);
	
	NativeMMC_OnVoteEnd(g_sVoteGameMode, g_sVoteSubGroup, g_sVoteMap, VoteEnd_Winner);
	
    g_bVoteActive = false;
    g_bVoteCompleted = true;
    
    
    switch(g_eVoteTiming)
    {		
        case TIMING_NEXTMAP:
        {
            strcopy(g_sNextMap, sizeof(g_sNextMap), g_sVoteMap);
            strcopy(g_sNextGameMode, sizeof(g_sNextGameMode), g_sVoteGameMode);
            SetNextMap(g_sNextMap);
            CPrintToChatAll("%t", "Timing NextMap Notify", g_sNextMap);
            MMC_WriteToLogFile(g_Cvar_Logs, "[MultiMode Core] Next map set (vote): %s", g_sNextMap);
        }
        
        case TIMING_NEXTROUND:
        {
            g_bChangeMapNextRound = true;
            strcopy(g_sNextMap, sizeof(g_sNextMap), g_sVoteMap);
            strcopy(g_sNextGameMode, sizeof(g_sNextGameMode), g_sVoteGameMode);
            SetNextMap(g_sNextMap);
            CPrintToChatAll("%t", "Timing NextRound Notify", g_sNextMap);
            MMC_WriteToLogFile(g_Cvar_Logs, "[MultiMode Core] Next round map set (vote): %s", g_sNextMap);
        }
        
        case TIMING_INSTANT:
        {
            strcopy(g_sNextMap, sizeof(g_sNextMap), g_sVoteMap);
            strcopy(g_sNextGameMode, sizeof(g_sNextGameMode), g_sVoteGameMode);
            SetNextMap(g_sNextMap);

            char game[20];
            GetGameFolderName(game, sizeof(game));
            ConVar mp_tournament = FindConVar("mp_tournament");

            if (mp_tournament != null && mp_tournament.BoolValue)
            {
                ForceChangeLevel(g_sNextMap, "Map changed by vote");
            }
            else
            {
                if (!StrEqual(game, "gesource", false) && !StrEqual(game, "zps", false))
                {
                    int iGameEnd = FindEntityByClassname(-1, "game_end");
                    if (iGameEnd == -1 && (iGameEnd = CreateEntityByName("game_end")) == -1)
                    {
                        ForceChangeLevel(g_sNextMap, "Map changed by vote");
                    } 
                    else 
                    {     
                        AcceptEntityInput(iGameEnd, "EndGame");
                    }
                }
                else
                {
                    ForceChangeLevel(g_sNextMap, "Map changed by vote");
                }
            }

            CPrintToChatAll("%t", "Timing Instant Notify", g_sNextMap);
            MMC_WriteToLogFile(g_Cvar_Logs, "[MultiMode Core] Map instantly set to (vote): %s", g_sNextMap);
        }
    }
    
    strcopy(g_sNextGameMode, sizeof(g_sNextGameMode), g_sVoteGameMode);
    strcopy(g_sNextMap, sizeof(g_sNextMap), g_sVoteMap);
	
    // Execute vote-command
    bool commandExecuted = false;
    
    if (strlen(g_sVoteSubGroup) > 0)
    {
        KeyValues kv = GetSubGroupMapKv(g_sVoteGameMode, g_sVoteSubGroup, g_sVoteMap);
        if (kv != null)
        {
            char mapVoteCommand[256];
            kv.GetString(MAPCYCLE_KEY_VOTE_COMMAND, mapVoteCommand, sizeof(mapVoteCommand), "");
            if (strlen(mapVoteCommand) > 0)
            {
                ServerCommand("%s", mapVoteCommand);
                MMC_WriteToLogFile(g_Cvar_Logs, "[MultiMode Core] Executed subgroup map vote-command: %s", mapVoteCommand);
                commandExecuted = true;
            }
            delete kv;
        }
    }
    
    if (!commandExecuted)
    {
        KeyValues kv = GetMapKv(g_sVoteGameMode, g_sVoteMap);
        if (kv != null)
        {
            char mapVoteCommand[256];
            kv.GetString(MAPCYCLE_KEY_VOTE_COMMAND, mapVoteCommand, sizeof(mapVoteCommand), "");
            if (strlen(mapVoteCommand) > 0)
            {
                ServerCommand("%s", mapVoteCommand);
                MMC_WriteToLogFile(g_Cvar_Logs, "[MultiMode Core] Executed map vote-command: %s", mapVoteCommand);
                commandExecuted = true;
            }
            delete kv;
        }
    }
    
    if (!commandExecuted)
    {
        int index = MMC_FindGameModeIndex(g_sVoteGameMode);
        if (index != -1)
        {
            GameModeConfig config;
            ArrayList list = GetGameModesList();
            list.GetArray(index, config);
            
            if (strlen(config.vote_command) > 0)
            {
                ServerCommand("%s", config.vote_command);
                MMC_WriteToLogFile(g_Cvar_Logs, "[MultiMode Core] Executed group vote-command: %s", config.vote_command);
            }
        }
    }
	
    NativeMMC_OnGamemodeChangedVote(g_sVoteGameMode, g_sVoteSubGroup, g_sVoteMap, view_as<int>(g_eVoteTiming));
    
}

public void ExecuteSubGroupVoteResult()
{
    g_sCurrentVoteId[0] = '\0';
    g_iGlobalMaxRunoffs = -1;
    NativeMMC_OnVoteEnd(g_sVoteGameMode, g_sVoteSubGroup, g_sVoteMap, VoteEnd_Winner);
	
	strcopy(g_sNextSubGroup, sizeof(g_sNextSubGroup), g_sVoteSubGroup);
    
    g_bVoteActive = false;
    g_bVoteCompleted = true;
    
    int gamemodeIndex = MMC_FindGameModeIndex(g_sVoteGameMode);
    int subgroupIndex = MMC_FindSubGroupIndex(g_sVoteGameMode, g_sVoteSubGroup);
    
    if (gamemodeIndex != -1 && subgroupIndex != -1)
    {
        GameModeConfig config;
        ArrayList list = GetGameModesList();
        list.GetArray(gamemodeIndex, config);

        SubGroupConfig subConfig;
        config.subGroups.GetArray(subgroupIndex, subConfig);

        bool commandExecuted = false;

        KeyValues kv = GetSubGroupMapKv(g_sVoteGameMode, g_sVoteSubGroup, g_sVoteMap);
        if (kv != null)
        {
            char mapVoteCommand[256];
            kv.GetString(MAPCYCLE_KEY_VOTE_COMMAND, mapVoteCommand, sizeof(mapVoteCommand), "");
            if (strlen(mapVoteCommand) > 0)
            {
                ServerCommand("%s", mapVoteCommand);
                MMC_WriteToLogFile(g_Cvar_Logs, "[MultiMode Core] Executed subgroup map vote-command: %s", mapVoteCommand);
                commandExecuted = true;
            }
            delete kv;
        }
        
        if (!commandExecuted && strlen(subConfig.vote_command) > 0)
        {
            ServerCommand("%s", subConfig.vote_command);
            MMC_WriteToLogFile(g_Cvar_Logs, "[MultiMode Core] Executed subgroup vote-command: %s", subConfig.vote_command);
        }
    }
    
    switch(g_eVoteTiming)
    {		
        case TIMING_NEXTMAP:
        {
            strcopy(g_sNextMap, sizeof(g_sNextMap), g_sVoteMap);
            strcopy(g_sNextGameMode, sizeof(g_sNextGameMode), g_sVoteGameMode);
            SetNextMap(g_sNextMap);
            CPrintToChatAll("%t", "Timing NextMap Notify", g_sNextMap);
            MMC_WriteToLogFile(g_Cvar_Logs, "[MultiMode Core] Next map set (subgroup vote): %s (Group: %s, SubGroup: %s)", g_sNextMap, g_sVoteGameMode, g_sVoteSubGroup);
        }
        
        case TIMING_NEXTROUND:
        {
            g_bChangeMapNextRound = true;
            strcopy(g_sNextMap, sizeof(g_sNextMap), g_sVoteMap);
            strcopy(g_sNextGameMode, sizeof(g_sNextGameMode), g_sVoteGameMode);
            SetNextMap(g_sNextMap);
            CPrintToChatAll("%t", "Timing NextRound Notify", g_sNextMap);
            MMC_WriteToLogFile(g_Cvar_Logs, "[MultiMode Core] Next round map set (subgroup vote): %s (Group: %s, SubGroup: %s)", g_sNextMap, g_sVoteGameMode, g_sVoteSubGroup);
        }
        
        case TIMING_INSTANT:
        {
            strcopy(g_sNextMap, sizeof(g_sNextMap), g_sVoteMap);
            strcopy(g_sNextGameMode, sizeof(g_sNextGameMode), g_sVoteGameMode);
            SetNextMap(g_sNextMap);

            char game[20];
            GetGameFolderName(game, sizeof(game));
            ConVar mp_tournament = FindConVar("mp_tournament");

            if (mp_tournament != null && mp_tournament.BoolValue)
            {
                ForceChangeLevel(g_sNextMap, "Map changed by subgroup vote");
            }
            else
            {
                if (!StrEqual(game, "gesource", false) && !StrEqual(game, "zps", false))
                {
                    int iGameEnd = FindEntityByClassname(-1, "game_end");
                    if (iGameEnd == -1 && (iGameEnd = CreateEntityByName("game_end")) == -1)
                    {
                        ForceChangeLevel(g_sNextMap, "Map changed by subgroup vote");
                    } 
                    else 
                    {     
                        AcceptEntityInput(iGameEnd, "EndGame");
                    }
                }
                else
                {
                    ForceChangeLevel(g_sNextMap, "Map changed by subgroup vote");
                }
            }

            CPrintToChatAll("%t", "Timing Instant Notify", g_sNextMap);
            MMC_WriteToLogFile(g_Cvar_Logs, "[MultiMode Core] Map instantly set to (subgroup vote): %s (Group: %s, SubGroup: %s)", g_sNextMap, g_sVoteGameMode, g_sVoteSubGroup);
        }
    }
    
    NativeMMC_OnGamemodeChangedVote(g_sVoteGameMode, g_sVoteSubGroup, g_sVoteMap, view_as<int>(g_eVoteTiming));
}

int GetVoteMethod()
{
    return g_Cvar_Method.IntValue;
}

// ////////////////////
// //                //
// //    Cooldown    //
// //                //
// ////////////////////

// Cooldown

void StartCooldown(VoteType voteType = VOTE_TYPE_GROUP, const char[] gamemode = "", const char[] subgroup = "", int initiator = 0, bool isRunoff = false)
{
    int cooldownTime = g_Cvar_CooldownTime.IntValue;

    g_ePendingVoteType = voteType;
    g_iPendingVoteInitiator = initiator;
    strcopy(g_sPendingVoteGamemode, sizeof(g_sPendingVoteGamemode), gamemode);
    strcopy(g_sPendingVoteSubGroup, sizeof(g_sPendingVoteSubGroup), subgroup);
    g_bIsRunoffCooldown = isRunoff;

    if (!g_Cvar_CooldownEnabled.BoolValue) 
    {
        CreateTimer(2.0, Timer_ExecutePendingVote, _, TIMER_FLAG_NO_MAPCHANGE);
        return;
    }

    g_bCooldownActive = true;
    g_iCooldownEndTime = GetTime() + cooldownTime;
    
    if (g_hCooldownTimer != null) {
        KillTimer(g_hCooldownTimer);
    }
    
    g_hCooldownTimer = CreateTimer(float(cooldownTime), Timer_EndCooldown);

    if (isRunoff)
    {
        CPrintToChatAll("%t", "Run Off Voting Cooldown", cooldownTime);
    }
    else
    {
        CPrintToChatAll("%t", "Cooldown Begin", cooldownTime);
    }
    
    CreateTimer(1.0, Timer_UpdateCooldownHUD, _, TIMER_REPEAT);
}

void ExecutePendingVote(VoteType voteType, const char[] gamemode, const char[] subgroup, int initiator)
{
    AdvancedVoteConfig config;
    strcopy(config.id, sizeof(config.id), "pending");
    strcopy(config.mapcycle, sizeof(config.mapcycle), "");
    config.type = g_CurrentVoteConfig.type;
    config.time = 0;
    config.timing = TIMING_NEXTMAP;
    
    if (g_PreservedStartSound[0] != '\0')
    {
        strcopy(config.startSound, sizeof(config.startSound), g_PreservedStartSound);
    }
    else if (g_CurrentVoteConfig.startSound[0] != '\0')
    {
        strcopy(config.startSound, sizeof(config.startSound), g_CurrentVoteConfig.startSound);
    }
    
    if (g_PreservedEndSound[0] != '\0')
    {
        strcopy(config.endSound, sizeof(config.endSound), g_PreservedEndSound);
    }
    else if (g_CurrentVoteConfig.endSound[0] != '\0')
    {
        strcopy(config.endSound, sizeof(config.endSound), g_CurrentVoteConfig.endSound);
    }
    
    if (g_PreservedRunoffStartSound[0] != '\0')
    {
        strcopy(config.runoffstartSound, sizeof(config.runoffstartSound), g_PreservedRunoffStartSound);
    }
    else if (g_CurrentVoteConfig.runoffstartSound[0] != '\0')
    {
        strcopy(config.runoffstartSound, sizeof(config.runoffstartSound), g_CurrentVoteConfig.runoffstartSound);
    }
    
    if (g_PreservedRunoffEndSound[0] != '\0')
    {
        strcopy(config.runoffendSound, sizeof(config.runoffendSound), g_PreservedRunoffEndSound);
    }
    else if (g_CurrentVoteConfig.runoffendSound[0] != '\0')
    {
        strcopy(config.runoffendSound, sizeof(config.runoffendSound), g_CurrentVoteConfig.runoffendSound);
    }
    
    config.extendOption = true;
    config.timestep = 0;
    config.fragstep = 0;
    config.roundstep = 0;
    config.groupexclude = -1;
    config.mapexclude = -1;
    config.handlenominations = true;
    config.threshold = 0.0;
    config.maxRunoffs = 0;
    config.maxRunoffInVote = 0;
    config.runoffFailAction = RUNOFF_FAIL_PICK_FIRST;
    config.sorted = g_CurrentVoteConfig.sorted;
    config.adminvote = g_bCurrentVoteAdmin;
    config.targetClients = null;
    config.voteType = voteType;
    config.runoffItems = null;
    
    switch (voteType)
    {
        case VOTE_TYPE_GROUP:
        {
            config.contextInfo[0] = '\0';
        }
        case VOTE_TYPE_SUBGROUP:
        {
            strcopy(config.contextInfo, sizeof(config.contextInfo), gamemode);
        }
        case VOTE_TYPE_MAP:
        {
            strcopy(config.contextInfo, sizeof(config.contextInfo), gamemode);
        }
        case VOTE_TYPE_SUBGROUP_MAP:
        {
            Format(config.contextInfo, sizeof(config.contextInfo), "%s/%s", gamemode, subgroup);
        }
    }
    
    BuildVote(initiator, config);
}

void StartPendingRunoffVote()
{
    if (g_RunoffItems == null || g_RunoffItems.Length == 0)
    {
        LogError("[MultiMode Core] g_RunoffItems is null or empty in StartPendingRunoffVote. Cancelling runoff.");
        PlayVoteSound(false, g_bIsRunoffVote);
        g_bVoteActive = false;
        g_bIsRunoffVote = false;
        NativeMMC_OnVoteEnd("", "", "", VoteEnd_Failed);
        return;
    }

    AdvancedVoteConfig config;
    config = g_CurrentVoteConfig;
    
    config.runoffItems = g_RunoffItems;
    
    VoteType voteType = g_CurrentVoteConfig.voteType;
    switch (voteType)
    {
        case VOTE_TYPE_GROUP:
        {
            config.contextInfo[0] = '\0';
        }
        case VOTE_TYPE_SUBGROUP:
        {
            strcopy(config.contextInfo, sizeof(config.contextInfo), g_sVoteGameMode);
        }
        case VOTE_TYPE_MAP:
        {
            strcopy(config.contextInfo, sizeof(config.contextInfo), g_sVoteGameMode);
        }
        case VOTE_TYPE_SUBGROUP_MAP:
        {
            Format(config.contextInfo, sizeof(config.contextInfo), "%s/%s", g_sVoteGameMode, g_sVoteSubGroup);
        }
    }
    
    int initiator = (g_iVoteInitiator >= 0) ? g_iVoteInitiator : g_iPendingVoteInitiator;
    if (initiator < 0) initiator = 0;
    
    BuildVote(initiator, config);
}

public Action Timer_EndCooldown(Handle timer)
{
    g_bCooldownActive = false;
    g_hCooldownTimer = INVALID_HANDLE;
    
    if(g_bIsRunoffCooldown)
    {
        g_bIsRunoffCooldown = false;
        StartPendingRunoffVote();
    }
    else
    {
        ExecutePendingVote(g_ePendingVoteType, g_sPendingVoteGamemode, g_sPendingVoteSubGroup, g_iPendingVoteInitiator);
    }
    
    return Plugin_Stop;
}

public Action Timer_ExecutePendingVote(Handle timer)
{
    if(g_bIsRunoffCooldown)
    {
        g_bIsRunoffCooldown = false;
        StartPendingRunoffVote();
    }
    else
    {
        ExecutePendingVote(g_ePendingVoteType, g_sPendingVoteGamemode, g_sPendingVoteSubGroup, g_iPendingVoteInitiator);
    }
	
    return Plugin_Stop;
}

// //////////////////////
// //                  //
// //    KV SECTION    //
// //                  //
// //////////////////////

KeyValues GetMapKv(const char[] gamemode, const char[] mapname)
{
    return MMC_GetMapKv(g_kvGameModes, gamemode, mapname);
}

KeyValues GetSubGroupMapKv(const char[] gamemode, const char[] subgroup, const char[] mapname)
{
    return MMC_GetSubGroupMapKv(g_kvGameModes, gamemode, subgroup, mapname);
}

stock void GetMapDisplayNameEx(const char[] gamemode, const char[] map, char[] display, int displayLen, const char[] subgroup = "")
{
    if (gamemode[0] != '\0')
    {
        if (MMC_GetMapDisplayNameEx(g_kvGameModes, gamemode, map, display, displayLen, subgroup))
        {
            return;
        }
    }
    else
    {
        ArrayList gameModes = GetGameModesList();
        for (int i = 0; i < gameModes.Length; i++)
        {
            GameModeConfig config;
            gameModes.GetArray(i, config);

            if (config.maps.FindString(map) != -1)
            {
                if (MMC_GetMapDisplayNameEx(g_kvGameModes, config.name, map, display, displayLen))
                {
                    return;
                }
            }

            for (int j = 0; j < config.subGroups.Length; j++)
            {
                SubGroupConfig subConfig;
                config.subGroups.GetArray(j, subConfig);

                if (subConfig.maps.FindString(map) != -1)
                {
                    if (MMC_GetMapDisplayNameEx(g_kvGameModes, config.name, map, display, displayLen, subConfig.name))
                    {
                        return;
                    }
                }
            }
        }
    }

    // Finally: use the default map name
    char baseMap[PLATFORM_MAX_PATH];
    strcopy(baseMap, sizeof(baseMap), map);
    if (GetMapDisplayName(baseMap, display, displayLen)) 
    {
        return;
    }
    
    strcopy(display, displayLen, baseMap);
}

bool HasSubGroups(const char[] gamemode)
{
    int index = MMC_FindGameModeIndex(gamemode);
    if (index == -1) return false;

    GameModeConfig config;
    ArrayList list = GetGameModesList();
    list.GetArray(index, config);
    
    return (config.subGroups != null && config.subGroups.Length > 0);
}

public void OnGamemodeConfigLoaded()
{
    MMC_WriteToLogFile(g_Cvar_Logs, "[MultiMode Core] Gamemodes loaded successfully!");
}

public Action Command_ReloadGamemodes(int client, int args)
{
    LoadGameModesConfig();
	
    CReplyToCommand(client, "%t", "Reload Gamemodes Successful");
    return Plugin_Handled;
}

public void OnPluginEnd()
{
    CloseHandle(g_hCookieVoteType);
    CloseHandle(g_hHudSync);
	
    for (int i = 0; i <= MAXPLAYERS; i++)
    {
        if (g_PlayerNominations[i] != null)
        {
            delete g_PlayerNominations[i];
        }
    }
	
    if (g_OnVoteStartForward != null)
    {
        CloseHandle(g_OnVoteStartForward);
        g_OnVoteStartForward = null;
    }
	
    if (g_OnVoteStartExForward != null)
    {
        CloseHandle(g_OnVoteStartExForward);
        g_OnVoteStartExForward = null;
    }
	
    if (g_OnVoteEndForward != null)
    {
        CloseHandle(g_OnVoteEndForward);
        g_OnVoteEndForward = null;
    }
	
    if (g_OnGamemodeChangedForward != null)
    {
        CloseHandle(g_OnGamemodeChangedForward);
        g_OnGamemodeChangedForward = null;
    }
	
    if (g_OnGamemodeChangedVoteForward != null)
    {
        CloseHandle(g_OnGamemodeChangedVoteForward);
        g_OnGamemodeChangedVoteForward = null;
    }
}