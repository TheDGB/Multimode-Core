/*****************************************************************************
                        Multi Mode Core English Version
******************************************************************************/

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <morecolors>
#include <adminmenu>
#include <nextmap>
#include <discord>
#include <emitsoundany>
#include <clientprefs>
#include <halflife>
#include <files>
#include <multimode/base>

#define COMMAND_KEY          "command"
#define PLUGIN_VERSION "2.1.0"

enum TimingMode
{
    TIMING_NEXTMAP = 0,
    TIMING_NEXTROUND,
    TIMING_INSTANT
};

// Convar Section
ConVar g_Cvar_CooldownEnabled;
ConVar g_Cvar_CooldownTime;
ConVar g_Cvar_CountdownEnabled;
ConVar g_Cvar_CountdownFilename;
ConVar g_Cvar_Discord;
ConVar g_Cvar_DiscordExtend;
ConVar g_Cvar_DiscordVoteResult;
ConVar g_Cvar_DiscordWebhook;
ConVar g_Cvar_Enabled;
ConVar g_Cvar_EndVoteDebug;
ConVar g_Cvar_EndVoteEnabled;
ConVar g_Cvar_EndVoteFrags;
ConVar g_Cvar_EndVoteMin;
ConVar g_Cvar_EndVoteRounds;
ConVar g_Cvar_EndVoteType;
ConVar g_Cvar_EndVoteOnRoundEnd;
ConVar g_Cvar_Extend;
ConVar g_Cvar_ExtendEveryTime;
ConVar g_Cvar_ExtendFragStep;
ConVar g_Cvar_ExtendRoundStep;
ConVar g_Cvar_ExtendSteps;
ConVar g_Cvar_ExtendVote;
ConVar g_Cvar_ExtendVoteAdmin;
ConVar g_Cvar_Logs;
ConVar g_Cvar_Method;
ConVar g_Cvar_NominateEnabled;
ConVar g_Cvar_NominateGroupExclude;
ConVar g_Cvar_NominateMapExclude;
ConVar g_Cvar_NominateOneChance;
ConVar g_Cvar_NominateSelectedGroupExclude;
ConVar g_Cvar_NominateSelectedMapExclude;
ConVar g_Cvar_NominateSorted;
ConVar g_Cvar_RandomCycleEnabled;
ConVar g_Cvar_RandomCycleType;
ConVar g_Cvar_RtvDelay;
ConVar g_Cvar_RtvEnabled;
ConVar g_Cvar_RtvFirstDelay;
ConVar g_Cvar_RtvMinPlayers;
ConVar g_Cvar_RtvRatio;
ConVar g_Cvar_RtvType;
ConVar g_Cvar_VoteAdminGroupExclude;
ConVar g_Cvar_VoteAdminMapExclude;
ConVar g_Cvar_VoteAdminRandom;
ConVar g_Cvar_VoteCloseSound;
ConVar g_Cvar_VoteGroupExclude;
ConVar g_Cvar_VoteMapExclude;
ConVar g_Cvar_VoteOpenSound;
ConVar g_Cvar_VoteRandom;
ConVar g_Cvar_VoteSounds;
ConVar g_Cvar_VoteTime;
ConVar g_hCvarTimeLimit;

// Bool
bool g_bEndVoteTriggered = false;
bool g_bRtvVoted[MAXPLAYERS+1];
bool g_bRtvInitialDelay = true;
bool g_bRtvCooldown = false;
bool g_bRtvDisabled = false;
bool g_bHasNominated[MAXPLAYERS+1];
bool change_map_round;
bool g_bVoteActive;
bool g_bCooldownActive = false;
bool g_bMapExtended = false;
bool g_bInternalChange = false;
bool g_bGameEndTriggered = false;
bool g_bVoteCompleted = false;
bool g_bEndVotePending = false;
bool g_bCurrentVoteAdmin;

// Array Section
ArrayList g_NominatedGamemodes;
ArrayList g_PlayedGamemodes;

// StringMap Section
StringMap g_NominatedMaps;
StringMap g_PlayedMaps;
StringMap g_Countdowns;
StringMap g_CountdownSounds;
StringMap g_LastCountdownValues;

// TimingMode Section
TimingMode g_eCurrentVoteTiming;
TimingMode g_eEndVoteTiming;
TimingMode g_eVoteTiming;

// Char Section
char g_sCurrentGameMode[64];
char g_sPendingCommand[256];
char g_sVoteGameMode[64];
char g_sVoteMap[PLATFORM_MAX_PATH];
char g_sClientPendingGameMode[MAXPLAYERS+1][64];
char g_sClientPendingMap[MAXPLAYERS+1][PLATFORM_MAX_PATH];
char g_sNextMap[PLATFORM_MAX_PATH];
char g_NominateGamemode[MAXPLAYERS+1][64];
char g_sNextGameMode[64];
char g_sSelectedGameMode[64] = "";

// Int Section
int g_iRtvVotes = 0;
int g_iVoteInitiator = -1;
int g_iCooldownEndTime = 0;
int g_iMapStartTime;

// Handle Section
Handle g_hRtvCooldownTimer = INVALID_HANDLE;
Handle g_hRtvFirstDelayTimer = INVALID_HANDLE;
Handle g_hEndVoteTimer = INVALID_HANDLE;
Handle g_hRtvTimers[2];
Handle g_hCookieVoteType;
Handle g_hCooldownTimer = INVALID_HANDLE;
Handle g_hHudSync;

// Float Section
float g_fRtvTimerStart[2];
float g_fRtvTimerDuration[2];

public void OnPluginStart() 
{
    LoadTranslations("multimode_voter.phrases");
    
    // Reg Console Commands
    RegConsoleCmd("sm_rtv", Command_RTV, "Vote to change map");
    RegConsoleCmd("sm_nominate", Command_Nominate, "Name a game mode and map");
    
    // Reg Admin Commands
    RegAdminCmd("multimode_reload", Command_ReloadGamemodes, ADMFLAG_CONFIG, "Reloads gamemodes configuration");
    RegAdminCmd("sm_forcemode", Command_ForceMode, ADMFLAG_CHANGEMAP, "Force game mode and map");
    RegAdminCmd("sm_testvote", Command_VoteMenu, ADMFLAG_VOTE, "Start Voting Mode/Map Testing Voting");
    RegAdminCmd("sm_votecancel", Command_CancelVote, ADMFLAG_VOTE, "Cancel the current MultiMode vote");
    RegAdminCmd("sm_mmcancelvote", Command_CancelVote, ADMFLAG_VOTE, "Cancel the current MultiMode vote");
    
    // Convars
    g_Cvar_Enabled = CreateConVar("multimode_enabled", "1", "Enable the multimode voting system");
        
    g_Cvar_RtvEnabled = CreateConVar("multimode_rtv_enabled", "1", "Enables and disables the Rock The Vote system on the server", _, true, 0.0, true, 1.0);
    g_Cvar_RtvMinPlayers = CreateConVar("multimode_rtv_min", "1", "Minimum number of players required to start RTV", _, true, 1.0);
    g_Cvar_RtvRatio = CreateConVar("multimode_rtv_ratio", "0.8", "Ratio of players needed to start RTV", _, true, 0.05, true, 1.0);
    g_Cvar_RtvFirstDelay = CreateConVar("multimode_rtvfirstdelay", "60", "Initial delay after map loads to allow RTV");
    g_Cvar_RtvDelay = CreateConVar("multimode_rtvdelay", "120", "Delay after a vote to allow new RTV");
    g_Cvar_RtvType = CreateConVar("multimode_rtvtype", "3", "Voting Type for RTV: 1 - Next Map, 2 - Next Round, 3 - Instant", _, true, 1.0, true, 3.0);
    
    g_Cvar_CooldownEnabled = CreateConVar("multimode_cooldown", "1", "Enable or disable cooldown between votes", _, true, 0.0, true, 1.0);
    g_Cvar_CooldownTime = CreateConVar("multimode_cooldown_time", "10", "Cooldown time in seconds between votes", _, true, 0.0);
	
    g_Cvar_CountdownEnabled = CreateConVar("multimode_countdown", "1", "Enable/disable the end vote countdown messages", _, true, 0.0, true, 1.0);
    g_Cvar_CountdownFilename = CreateConVar("multimode_countdown_filename", "countdown.txt", "Name of the countdown configuration file");
    
    g_Cvar_VoteTime = CreateConVar("multimode_vote_time", "20", "Vote duration in seconds");
    g_Cvar_VoteRandom = CreateConVar("multimode_vote_random", "1", "When enabled, all voting items are randomly drawn. When disabled, the map cycle order is used as normal.", _, true, 0.0, true, 1.0);
    g_Cvar_VoteAdminRandom = CreateConVar("multimode_voteadmin_random", "1", "When enabled, all admin vote items are randomly drawn. When disabled, the map cycle order is used as normal.", _, true, 0.0, true, 1.0);
    g_Cvar_VoteGroupExclude = CreateConVar("multimode_vote_groupexclude", "0", "Number of recently played gamemodes to exclude from normal votes (0= Disabled)");
    g_Cvar_VoteMapExclude = CreateConVar("multimode_vote_mapexclude", "2", "Number of recently played maps to exclude from normal votes (0= Disabled)");
    g_Cvar_VoteAdminGroupExclude = CreateConVar("multimode_voteadmin_groupexclude", "0", "Number of recently played gamemodes to exclude from admin votes (0= Disabled)");
    g_Cvar_VoteAdminMapExclude = CreateConVar("multimode_voteadmin_mapexclude", "2", "Number of recently played maps to exclude from admin votes (0= Disabled)");
    
    g_Cvar_EndVoteEnabled = CreateConVar("multimode_endvote_enabled", "1", "Enables automatic end vote when the remaining map time reaches the configured limit.");
    g_Cvar_EndVoteMin = CreateConVar("multimode_endvote_min", "6", "Specifies minutes remaining to start automatic voting. (mp_timelimit, multimode_endvote_min 0 = Disabled)");	
	g_Cvar_EndVoteRounds = CreateConVar("multimode_endvote_rounds", "3", "Specifies when to start voting based on the remaining rounds. (mp_maxrounds, mp_winlimit, multimode_endvote_rounds 0 = Disabled)", _, true, 0.0);
    g_Cvar_EndVoteFrags = CreateConVar("multimode_endvote_frags", "30", "Specifies when to start voting based on remaining frags. (mp_fraglimit, multimode_endvote_frags 0 = Disabled)", _, true, 0.0);
    g_Cvar_EndVoteType = CreateConVar("multimode_endvotetype", "1", "Voting Type for End Vote: 1 - Next Map, 2 - Next Round, 3 - Instant", _, true, 1.0, true, 3.0);
	g_Cvar_EndVoteOnRoundEnd = CreateConVar("multimode_endvote_onroundend", "0", "Wait for the end of the round to start voting for the end vote.", _, true, 0.0, true, 1.0);
    g_Cvar_EndVoteDebug = CreateConVar("multimode_endvotedebug", "0", "Enables/disables detailed End Vote logs", 0, true, 0.0, true, 1.0);
	
    g_Cvar_NominateEnabled = CreateConVar("multimode_nominate", "1", "Enables or disables the nominate system", _, true, 0.0, true, 1.0);
    g_Cvar_NominateOneChance = CreateConVar("multimode_nominate_onechance", "1", "Allows users to nominate only once per map", _, true, 0.0, true, 1.0);
    g_Cvar_NominateSelectedGroupExclude = CreateConVar("multimode_nominate_selectedgroupexclude", "0", "Removes the nominated gamemode from the nominate menu", _, true, 0.0, true, 1.0);
	g_Cvar_NominateSelectedMapExclude = CreateConVar("multimode_nominate_selectedmapexclude", "1", "Removes the nominated map from the nominate menu", _, true, 0.0, true, 1.0);
    g_Cvar_NominateGroupExclude = CreateConVar("multimode_nominate_groupexclude", "0", "Number of recently played gamemodes to exclude from the menu (0= Disabled)");
    g_Cvar_NominateMapExclude = CreateConVar("multimode_nominate_mapexclude", "2", "Number of recently played maps to exclude from the menu (0= Disabled)");
    g_Cvar_NominateSorted = CreateConVar("multimode_nominate_sorted", "2", "Sorting mode for maps: 0= Alphabetical, 1= Random, 2= Map Cycle Order", _, true, 0.0, true, 2.0);
    
    g_Cvar_Discord = CreateConVar("multimode_discord", "1", "Enable sending a message to Discord when a vote is successful.", _, true, 0.0, true, 1.0);
    
    g_Cvar_DiscordWebhook = CreateConVar("multimode_discordwebhook", "https://discord.com/api/webhooks/...", "Discord webhook URL to send messages to.", FCVAR_PROTECTED);
    g_Cvar_DiscordVoteResult = CreateConVar("multimode_discordvoteresults", "1", "Enable discord webhook vote results.", _, true, 0.0, true, 1.0);
    g_Cvar_DiscordExtend = CreateConVar("multimode_discordextend", "1", "Enable discord webhook vote extensions.", _, true, 0.0, true, 1.0);
    
    g_Cvar_VoteSounds = CreateConVar("multimode_votesounds", "1", "Enables/disables voting and automatic download sounds.", 0, true, 0.0, true, 1.0);
    g_Cvar_VoteOpenSound = CreateConVar("multimode_voteopensound", "votemap/vtst.wav", "Sound played when starting a vote");
    g_Cvar_VoteCloseSound = CreateConVar("multimode_voteclosesound", "votemap/vtend.wav", "Sound played when a vote ends");
    
    g_Cvar_Extend = CreateConVar("multimode_extend", "1", "Enables/disables the extend option to extend the map");
    g_Cvar_ExtendVote = CreateConVar("multimode_extendvote", "1", "Shows the option to extend in normal votes");
    g_Cvar_ExtendVoteAdmin = CreateConVar("multimode_extendvoteadmin", "1", "Show extend option in admin votes");
    g_Cvar_ExtendEveryTime = CreateConVar("multimode_extendeverytime", "0", "Allow extending the map multiple times in consecutive votes. 0 = only once per map.", _, true, 0.0, true, 1.0);
	
    g_Cvar_ExtendSteps = CreateConVar("multimode_extendtimestep", "6", "Number of additional minutes when map is extended", _, true, 1.0);
    g_Cvar_ExtendRoundStep = CreateConVar("multimode_extendroundstep", "3", "Number of additional rounds when map is extended", _, true, 1.0);
    g_Cvar_ExtendFragStep = CreateConVar("multimode_extendfragstep", "10", "Number of additional frags when map is extended", _, true, 1.0);
    
    g_Cvar_RandomCycleEnabled = CreateConVar("multimode_randomcycle_enabled", "1", "Enable/disable or Random Cycle", _, true, 0.0, true, 1.0);
    g_Cvar_RandomCycleType = CreateConVar("multimode_randomcycle_type", "1", "Random Cycle Type: 1-Selects at the beginning of the map, 2-Selects when there is no next map at the end of the map.", _, true, 1.0, true, 2.0);
    
    g_Cvar_Method = CreateConVar("multimode_method", "1", "Voting method: 1=Groups then maps, 2=Only groups (random map), 3=Only maps (all groups)", _, true, 1.0, true, 3.0);
    
    g_Cvar_Logs = CreateConVar("multimode_logs", "1", "Enables and disables Multimode Core logs, when enabled, a new file will be created in sourcemod/logs/multimode_logs.txt and server messages in server console.");

    g_PlayedGamemodes = new ArrayList(ByteCountToCells(64));
    g_PlayedMaps = new StringMap();
    
    g_hCookieVoteType = RegClientCookie("multimode_votetype", "Selected voting type", CookieAccess_Private);
    
    AutoExecConfig(true, "multimode_core");
    
    LoadGameModesConfig();
    g_Countdowns = new StringMap();
    g_LastCountdownValues = new StringMap();
    LoadCountdownConfig();
    
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
    
    // Others
    g_hCvarTimeLimit = FindConVar("mp_timelimit");
    g_NominatedGamemodes = new ArrayList(ByteCountToCells(64));
    g_NominatedMaps = new StringMap();
    g_hHudSync = CreateHudSynchronizer();
    
    // Hooks
    HookConVarChange(g_hCvarTimeLimit, OnTimelimitChanged);
    HookConVarChange(g_Cvar_VoteOpenSound, OnSoundConVarChanged);
    HookConVarChange(g_Cvar_VoteCloseSound, OnSoundConVarChanged);
	HookConVarChange(g_Cvar_CountdownEnabled, OnCountdownCvarChanged);
    HookConVarChange(g_Cvar_CountdownFilename, OnCountdownCvarChanged);
    
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
	
	// Listeners
	
    AddCommandListener(OnPlayerChat, "say");
    AddCommandListener(OnPlayerChat, "say2"); // For Non Valve Games
    AddCommandListener(OnPlayerChat, "say_team");
    
    HookEvent("server_spawn", Event_ServerSpawn, EventHookMode_PostNoCopy);
    
    TopMenu topmenu;
    if (LibraryExists("adminmenu") && ((topmenu = GetAdminTopMenu()) != null))
    {
        OnAdminMenuReady(topmenu);
    }
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    CreateNative("MultiMode_StartVote", NativeMMC_StartVote);
    CreateNative("MultiMode_IsVoteActive", NativeMMC_IsVoteActive);
    CreateNative("MultiMode_GetCurrentGameMode", NativeMMC_GetCurrentGameMode);
    CreateNative("MultiMode_GetNextMap", NativeMMC_GetNextMap);
    CreateNative("MultiMode_GetCurrentMap", NativeMMC_GetCurrentMap);
    CreateNative("MultiMode_Nominate", NativeMMC_Nominate);
    CreateNative("MultiMode_GetNextGameMode", NativeMMC_GetNextGameMode);
    CreateNative("MultiMode_IsRandomCycleEnabled", NativeMMC_IsRandomCycleEnabled);
    
    RegPluginLibrary("multimode_core");
    return APLRes_Success;
}

public void OnConfigsExecuted()
{
    delete g_kvGameModes;
    g_kvGameModes = new KeyValues("Mapcycle");
    
    char configPath[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, configPath, sizeof(configPath), "configs/gamemodes.cfg");
    
    if (!g_kvGameModes.ImportFromFile(configPath))
    {
        WriteToLogFile("Falha ao carregar gamemodes.cfg");
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
                            g_kvGameModes.GetString("display", displayName, sizeof(displayName), "");
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
    
    WriteToLogFile("[MultiMode Core] --------------- CURRENT MAP: %s ---------------", CurrentMap);

    if (strlen(g_sNextGameMode) > 0)
    {
        int index = FindGameModeIndex(g_sNextGameMode);
        if (index != -1)
        {
            GameModeConfig config;
            ArrayList list = GetGameModesList();
            list.GetArray(index, config);
        
            WriteToLogFile("[MultiMode Core] Using preselected gamemode: %s", config.name);
        
            if (strlen(config.command) > 0)
            {
                WriteToLogFile("[MultiMode Core] Executing group command: %s", config.command);
                ServerCommand("%s", config.command);
            }
            else
            {
                KeyValues kv = GetMapKv(config.name, CurrentMap);
                if (kv != null)
                {
                    char mapCommand[256];
                    kv.GetString("command", mapCommand, sizeof(mapCommand), "");
                    if (strlen(mapCommand) > 0)
                    {
                        WriteToLogFile("[MultiMode Core] Executing map command: %s", mapCommand);
                        ServerCommand("%s", mapCommand);
                    }
                    delete kv;
                }
            }
        }
        g_sNextGameMode[0] = '\0';
    }
    else
    {
        ArrayList gameModes = GetGameModesList();
        for (int i = 0; i < gameModes.Length; i++)
        {
            GameModeConfig config;
            gameModes.GetArray(i, config);

            if (config.maps.FindString(CurrentMap) != -1)
            {
                groupFound = true;
                WriteToLogFile("[MultiMode Core] Group found: %s", config.name);

                if (strlen(config.command) > 0)
                {
                    WriteToLogFile("[MultiMode Core] Executing group command: %s", config.command);
                    ServerCommand("%s", config.command);
                }

                if (g_kvGameModes.JumpToKey(config.name) && g_kvGameModes.JumpToKey("maps"))
                {
                    if (g_kvGameModes.JumpToKey(CurrentMap))
                    {
                        char mapCommand[256];
                        g_kvGameModes.GetString("command", mapCommand, sizeof(mapCommand), "");
                        if (strlen(mapCommand) > 0)
                        {
                            WriteToLogFile("[MultiMode Core] Executing map command: %s", mapCommand);
                            ServerCommand("%s", mapCommand);
                        }
                        g_kvGameModes.GoBack();
                    }
                    else
                    {
                        if (g_kvGameModes.GotoFirstSubKey(false))
                        {
                            do
                            {
                                char mapKey[PLATFORM_MAX_PATH];
                                g_kvGameModes.GetSectionName(mapKey, sizeof(mapKey));

                                if (IsWildcardEntry(mapKey) && StrContains(CurrentMap, mapKey) == 0)
                                {
                                    char wildcardCommand[256];
                                    g_kvGameModes.GetString("command", wildcardCommand, sizeof(wildcardCommand), "");
                                    if (strlen(wildcardCommand) > 0)
                                    {
                                        WriteToLogFile("[MultiMode Core] Executing wildcard command (%s): %s", mapKey, wildcardCommand);
                                        ServerCommand("%s", wildcardCommand);
                                    }
                                    break;
                                }
                            } while (g_kvGameModes.GotoNextKey(false));
                            g_kvGameModes.GoBack();
                        }
                    }
                    g_kvGameModes.GoBack();
                }
                g_kvGameModes.Rewind();
                break;
            }
        }
    }

    if (!groupFound)
    {
        // Cleaning...
    }
    
    g_bRtvDisabled = false;
    g_iRtvVotes = 0;
    g_bRtvCooldown = false;
    g_bMapExtended = false;
    g_bVoteCompleted = false;
	g_bEndVoteTriggered = false;
    g_bRtvInitialDelay = true;
    delete g_hRtvCooldownTimer;
    delete g_hRtvFirstDelayTimer;

    g_bCooldownActive = false;
    g_iCooldownEndTime = 0;
    delete g_hCooldownTimer;

    g_NominatedGamemodes.Clear();
    g_NominatedMaps.Clear();

    g_sNextGameMode[0] = '\0';
    g_sNextMap[0] = '\0';
    g_bVoteActive = false;
	
	g_LastCountdownValues.Clear();

    UpdateCurrentGameMode(CurrentMap);
	
    char currentMap[PLATFORM_MAX_PATH];
    GetCurrentMap(currentMap, sizeof(currentMap));

    if (strlen(g_sCurrentGameMode) > 0) {
        if (g_PlayedGamemodes.FindString(g_sCurrentGameMode) == -1) {
            g_PlayedGamemodes.PushString(g_sCurrentGameMode);
        }
    
        int maxGroups = g_Cvar_NominateGroupExclude.IntValue;
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

        int maxMaps = g_Cvar_NominateMapExclude.IntValue;
        if (maxMaps > 0 && playedMaps.Length > maxMaps) {
            playedMaps.Erase(0);
        }
    }

    for (int i = 1; i <= MaxClients; i++)
    {
        g_bRtvVoted[i] = false;
        g_bHasNominated[i] = false;
    }
    
    if (g_hEndVoteTimer != INVALID_HANDLE)
    {
        KillTimer(g_hEndVoteTimer);
        g_hEndVoteTimer = INVALID_HANDLE;
    }

    if (g_Cvar_EndVoteEnabled.BoolValue) 
    {
        g_hEndVoteTimer = CreateTimer(1.0, Timer_CheckEndVote, _, TIMER_REPEAT);
    }

    float fDelay = g_Cvar_RtvFirstDelay.FloatValue;
    if (fDelay > 0.0)
    {
        g_fRtvTimerStart[0] = GetEngineTime();
        g_fRtvTimerDuration[0] = fDelay;
        g_hRtvTimers[0] = CreateTimer(fDelay, Timer_EnableRTV, _, TIMER_FLAG_NO_MAPCHANGE);
        CPrintToChatAll("%t", "RTV Available In", RoundFloat(fDelay));
    }
    else
    {
        g_bRtvInitialDelay = false;
    }

    g_iMapStartTime = GetTime();

    if (g_Cvar_VoteSounds.BoolValue)
    {
        char sound[PLATFORM_MAX_PATH];
        char downloadPath[PLATFORM_MAX_PATH];

        g_Cvar_VoteOpenSound.GetString(sound, sizeof(sound));
        if (sound[0] != '\0')
        {
            PrecacheSoundAny(sound);
            FormatEx(downloadPath, sizeof(downloadPath), "sound/%s", sound);
            if (FileExists(downloadPath, true))
                AddFileToDownloadsTable(downloadPath);
            else
                WriteToLogFile("Opening sound file not found: %s", downloadPath);
        }

        g_Cvar_VoteCloseSound.GetString(sound, sizeof(sound));
        if (sound[0] != '\0')
        {
            PrecacheSoundAny(sound);
            FormatEx(downloadPath, sizeof(downloadPath), "sound/%s", sound);
            if (FileExists(downloadPath, true))
                AddFileToDownloadsTable(downloadPath);
            else
                WriteToLogFile("Closing sound file not found: %s", downloadPath);
        }
    }

    if (g_hEndVoteTimer != null && g_hEndVoteTimer != INVALID_HANDLE)
    {
        KillTimer(g_hEndVoteTimer);
        g_hEndVoteTimer = INVALID_HANDLE;
    }

    char sound[PLATFORM_MAX_PATH];
    g_Cvar_VoteOpenSound.GetString(sound, sizeof(sound));
    if (sound[0] != '\0') PrecacheSoundAny(sound);

    g_Cvar_VoteCloseSound.GetString(sound, sizeof(sound));
    if (sound[0] != '\0') PrecacheSoundAny(sound);

    if (g_Cvar_RandomCycleEnabled.BoolValue && g_Cvar_RandomCycleType.IntValue == 1)
    {
        SelectRandomNextMap(true);
        WriteToLogFile("[Random Cycle] Type 1: Map set at startup.");
    }

    g_bGameEndTriggered = false;
}

public void OnClientDisconnect(int client)
{
    if(g_bRtvVoted[client]) {
        g_bRtvVoted[client] = false;
        if(g_iRtvVotes > 0) {
            g_iRtvVotes--;
        }
    }
	
    if (GetRealClientCount() == 0 && g_hEndVoteTimer != INVALID_HANDLE)
    {
        KillTimer(g_hEndVoteTimer);
        g_hEndVoteTimer = INVALID_HANDLE;
    }

    int iPlayers = GetRealClientCount();
    float ratio = g_Cvar_RtvRatio.FloatValue;
    int minRequired = g_Cvar_RtvMinPlayers.IntValue;
    int iRequired = RoundToCeil(float(iPlayers) * ratio);
    if (iRequired < minRequired) {
        iRequired = minRequired;
    }
}

public void OnClientPutInServer(int client)
{
    if (GetRealClientCount() == 1 && g_Cvar_EndVoteEnabled.BoolValue && g_hEndVoteTimer == INVALID_HANDLE)
    {
        g_hEndVoteTimer = CreateTimer(1.0, Timer_CheckEndVote, _, TIMER_REPEAT);
    }
}

public void LoadGameModesConfig()
{
    delete g_kvGameModes;
    g_kvGameModes = new KeyValues("Mapcycle");
    
    char configPath[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, configPath, sizeof(configPath), "configs/gamemodes.cfg");
    
    if (!g_kvGameModes.ImportFromFile(configPath))
    {
        WriteToLogFile("Failed to load gamemodes.cfg");
        return;
    }

    ArrayList gameModes = GetGameModesList();
    gameModes.Clear();
    
    if (g_kvGameModes.GotoFirstSubKey(false))
    {
        do
        {
            GameModeConfig config;
            g_kvGameModes.GetSectionName(config.name, sizeof(config.name));
            
            config.enabled = g_kvGameModes.GetNum("enabled", 1);
            config.adminonly = g_kvGameModes.GetNum("adminonly", 0);
            config.minplayers = g_kvGameModes.GetNum("minplayers", 0);
            config.maxplayers = g_kvGameModes.GetNum("maxplayers", 0);
			
			g_kvGameModes.GetString("pre-command", config.pre_command, sizeof(config.pre_command), "");
            g_kvGameModes.GetString("vote-command", config.vote_command, sizeof(config.vote_command), "");
            
            if (g_kvGameModes.JumpToKey("serverconfig"))
            {
                g_kvGameModes.GetString("command", config.command, sizeof(config.command), "");
                g_kvGameModes.GoBack();
            }
            
            if (g_kvGameModes.JumpToKey("maps"))
            {
                config.maps = new ArrayList(ByteCountToCells(PLATFORM_MAX_PATH));
                config.maps_invote = g_kvGameModes.GetNum("maps_invote", 6);
                
                if (g_kvGameModes.GotoFirstSubKey(false))
                {
                    StringMap uniqueMaps = new StringMap();
                    
                    do
                    {
                        char mapKey[PLATFORM_MAX_PATH];
                        g_kvGameModes.GetSectionName(mapKey, sizeof(mapKey));
                        
                        if (IsWildcardEntry(mapKey))
                        {
                            ArrayList wildcardMaps = new ArrayList(ByteCountToCells(PLATFORM_MAX_PATH));
                            ExpandWildcardMaps(mapKey, wildcardMaps);
                            
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
            
            gameModes.PushArray(config);
        } while (g_kvGameModes.GotoNextKey(false));
    }
    
    g_kvGameModes.Rewind();
}

void ExpandWildcardMaps(const char[] pattern, ArrayList maplist)
{
    Handle dir = OpenDirectory("maps");
    FileType type;
    char fileName[PLATFORM_MAX_PATH];
    char mapName[PLATFORM_MAX_PATH];
    
    if (dir == null) return;

    while (ReadDirEntry(dir, fileName, sizeof(fileName), type))
    {
        if (type == FileType_File && StrContains(fileName, ".bsp") != -1)
        {
            strcopy(mapName, sizeof(mapName), fileName);
            int extpos = StrContains(mapName, ".bsp");
            if (extpos != -1) mapName[extpos] = '\0';
            
            if (StrContains(mapName, pattern) == 0 && IsMapValid(mapName))
            {
                if (maplist.FindString(mapName) == -1)
                {
                    maplist.PushString(mapName);
                }
            }
        }
    }
    
    CloseHandle(dir);
}

bool IsWildcardEntry(const char[] mapname)
{
    int len = strlen(mapname);
    return (len > 0 && mapname[len-1] == '_');
}

// //////////////////
// //              //
// //    Timers    //
// //              //
// //////////////////

// Timers

public Action Timer_EnableRTV(Handle timer)
{
    if (!g_bRtvCooldown)
    {
        g_bRtvInitialDelay = false;
        g_hRtvTimers[0] = INVALID_HANDLE;
        CPrintToChatAll("%t", "RTV Available");
    }
    return Plugin_Stop;
}

public Action Timer_ResetCooldown(Handle timer)
{
    g_bRtvCooldown = false;
    g_hRtvTimers[1] = INVALID_HANDLE;
    
    if(!g_bRtvDisabled) {
        CPrintToChatAll("%t", "RTV Available Again");
    }
    
    return Plugin_Stop;
}

public Action Timer_ForceMapChange(Handle timer)
{
    if(!StrEqual(g_sNextMap, "") && IsMapValid(g_sNextMap))
    {
        WriteToLogFile("[MultiMode Core] Forcing switch to: %s", g_sNextMap);
        ForceChangeLevel(g_sNextMap, "Voting completed");
    }
    else
    {
        WriteToLogFile("Invalid Map: %s", g_sNextMap);
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
    
    CheckRandomCycle();
    return Plugin_Stop;
}

public Action Timer_ChangeMap(Handle timer)
{
    if (strlen(g_sCurrentGameMode) == 0)
        return Plugin_Stop;

    int index = FindGameModeIndex(g_sCurrentGameMode);
    if (index == -1)
        return Plugin_Stop;

    GameModeConfig config;
    ArrayList list = GetGameModesList();
    list.GetArray(index, config);

    if (strlen(config.pre_command) > 0)
    {
        ServerCommand("%s", config.pre_command);
        WriteToLogFile("[MultiMode Core] Executed group pre-command: %s", config.pre_command);
    }

    char currentMap[PLATFORM_MAX_PATH];
    GetCurrentMap(currentMap, sizeof(currentMap));
    
    KeyValues kv = GetMapKv(g_sCurrentGameMode, currentMap);
    if (kv != null)
    {
        char mapPreCommand[256];
        kv.GetString("pre-command", mapPreCommand, sizeof(mapPreCommand), "");
        if (strlen(mapPreCommand) > 0)
        {
            ServerCommand("%s", mapPreCommand);
            WriteToLogFile("[MultiMode Core] Executed map pre-command: %s", mapPreCommand);
        }
        delete kv;
    }
	
    if (StrEqual(g_sNextMap, ""))
    {
        CheckRandomCycle();
        if (StrEqual(g_sNextMap, ""))
        {
            SelectRandomNextMap();
        }
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
    WriteToLogFile("[MultiMode Core] Map instantly set after round to: %s", g_sNextMap);
    
    CheckRandomCycle();
        
    return Plugin_Stop;
}

// //////////////////////
// //                  //
// //    Countdown     //
// //                  //
// //////////////////////

// Countdown

void LoadCountdownConfig()
{
    char path[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, path, sizeof(path), "configs/countdown.txt");

    if (!FileExists(path))
    {
        WriteToLogFile("Countdown config file not found: %s", path);
        return;
    }

    KeyValues kv = new KeyValues("Countdown");
    if (!kv.ImportFromFile(path))
    {
        WriteToLogFile("Failed to import countdown config from file: %s", path);
        delete kv;
        return;
    }

    StringMapSnapshot snapshot = g_Countdowns.Snapshot();
    for (int i = 0; i < snapshot.Length; i++)
    {
        char key[64];
        snapshot.GetKey(i, key, sizeof(key));
        StringMap typeMap;
        g_Countdowns.GetValue(key, typeMap);
        delete typeMap;
    }
    delete snapshot;
    g_Countdowns.Clear();

    delete g_CountdownSounds;
    g_CountdownSounds = new StringMap();

    if (kv.GotoFirstSubKey())
    {
        do
        {
            char type[64];
            kv.GetSectionName(type, sizeof(type));
            
            StringMap typeMap = new StringMap();
            g_Countdowns.SetValue(type, typeMap);

            if (kv.GotoFirstSubKey(false))
            {
                do
                {
                    char valueKey[32];
                    kv.GetSectionName(valueKey, sizeof(valueKey));

                    ArrayList messageList = new ArrayList(ByteCountToCells(256));
                    
                    if (kv.GotoFirstSubKey(false))
                    {
                        do
                        {
                            char messageType[16];
                            kv.GetSectionName(messageType, sizeof(messageType));

                            char message[256];
                            kv.GetString(NULL_STRING, message, sizeof(message));

                            if (StrEqual(messageType, "sound"))
                            {
                                if (!g_CountdownSounds.ContainsKey(message))
                                {
                                    g_CountdownSounds.SetValue(message, true);
                                    
                                    PrecacheSoundAny(message);
                                    char downloadPath[PLATFORM_MAX_PATH];
                                    FormatEx(downloadPath, sizeof(downloadPath), "sound/%s", message);
                                    if (FileExists(downloadPath, true))
                                        AddFileToDownloadsTable(downloadPath);
                                    else
                                        WriteToLogFile("Countdown sound file not found: %s", downloadPath);
                                }
                            }

                            char buffer[512];
                            FormatEx(buffer, sizeof(buffer), "%s;%s", messageType, message);
                            messageList.PushString(buffer);
                        } while (kv.GotoNextKey(false));
                        kv.GoBack();
                    }

                    if (StrContains(valueKey, ";") != -1)
                    {
                        char range[2][12];
                        int count = ExplodeString(valueKey, ";", range, 2, 12);
                        if (count == 2)
                        {
                            int start = StringToInt(range[0]);
                            int end = StringToInt(range[1]);
                            if (start < end)
                            {
                                int temp = start;
                                start = end;
                                end = temp;
                            }
                            for (int value = start; value >= end; value--)
                            {
                                char singleKey[12];
                                IntToString(value, singleKey, sizeof(singleKey));
                                ArrayList clonedList = view_as<ArrayList>(CloneHandle(messageList));
                                typeMap.SetValue(singleKey, clonedList);
                            }
                            delete messageList;
                        }
                        else
                        {
                            LogError("Invalid range in countdown config: %s", valueKey);
                            delete messageList;
                        }
                    }
                    else
                    {
                        int value = StringToInt(valueKey);
                        if (value >= 0)
                        {
                            typeMap.SetValue(valueKey, messageList);
                        }
                        else
                        {
                            delete messageList;
                        }
                    }
                } while (kv.GotoNextKey(false));
                kv.GoBack();
            }
        } while (kv.GotoNextKey());
    }

    delete kv;
    WriteToLogFile("[Multimode Core] Countdown configuration loaded successfully!");
}

void CountdownMessages(const char[] type, int value)
{
    int lastValue;
    char lastValueKey[64];
    Format(lastValueKey, sizeof(lastValueKey), "%s_last", type);
    
    if (!g_LastCountdownValues.GetValue(lastValueKey, lastValue) || value != lastValue)
    {
        StringMap typeMap;
        if (g_Countdowns.GetValue(type, typeMap))
        {
            char valueKey[32];
            IntToString(value, valueKey, sizeof(valueKey));
            
            ArrayList messages;
            if (typeMap.GetValue(valueKey, messages))
            {
                for (int i = 0; i < messages.Length; i++)
                {
                    char buffer[512];
                    messages.GetString(i, buffer, sizeof(buffer));

                    char parts[2][256];
                    if (ExplodeString(buffer, ";", parts, 2, 256) == 2)
                    {
                        char messageType[16];
                        strcopy(messageType, sizeof(messageType), parts[0]);
                        char message[256];
                        strcopy(message, sizeof(message), parts[1]);

                        if (StrEqual(messageType, "sound"))
                        {
                            char soundPath[PLATFORM_MAX_PATH];
                            strcopy(soundPath, sizeof(soundPath), message);

                            char formattedValue[32];
    
                            FormatTimeValue(value, formattedValue, sizeof(formattedValue));
                            ReplaceString(soundPath, sizeof(soundPath), "{TIME}", formattedValue);
    
                            Format(formattedValue, sizeof(formattedValue), "%d", value);
                            ReplaceString(soundPath, sizeof(soundPath), "{ROUNDS}", formattedValue);
                            ReplaceString(soundPath, sizeof(soundPath), "{FRAGS}", formattedValue);

                            EmitSoundToAllAny(soundPath);
                            continue;
                        }

                        char formattedValue[32];

                        FormatTimeValue(value, formattedValue, sizeof(formattedValue));
                        ReplaceString(message, sizeof(message), "{TIME}", formattedValue);

                        Format(formattedValue, sizeof(formattedValue), "%d", value);
                        ReplaceString(message, sizeof(message), "{FRAGS}", formattedValue);

                        Format(formattedValue, sizeof(formattedValue), "%d", value);
                        ReplaceString(message, sizeof(message), "{ROUNDS}", formattedValue);

                        if (StrEqual(messageType, "hint"))
                        {
                            PrintHintTextToAll(message);
                        }
                        else if (StrEqual(messageType, "center"))
                        {
                            PrintCenterTextAll(message);
                        }
                        else if (StrEqual(messageType, "chat"))
                        {
                            CPrintToChatAll(message);
                        }
                    }
                }
            }
        }
        g_LastCountdownValues.SetValue(lastValueKey, value);
    }
}


void FormatTimeValue(int timeValue, char[] buffer, int bufferSize)
{
    if (timeValue >= 60)
    {
        int minutes = timeValue / 60;
        Format(buffer, bufferSize, "%d", minutes);
    }
    else
    {
        Format(buffer, bufferSize, "%d", timeValue);
    }
}

// //////////////////////
// //                  //
// //   Random Cycle   //
// //                  //
// //////////////////////

// Random Cycle

void CheckRandomCycle()
{
    if (StrEqual(g_sNextMap, "") && 
        g_Cvar_RandomCycleEnabled.BoolValue && 
        g_Cvar_RandomCycleType.IntValue == 2 &&
        !g_bVoteCompleted)
    {
        SelectRandomNextMap(true);
        WriteToLogFile("[Random Cycle] Type 2 activated: Random map selected.");
    }
}

void SelectRandomNextMap(bool bSetNextMap = false)
{
    if(!g_Cvar_RandomCycleEnabled.BoolValue) return;

    ArrayList gameModes = GetGameModesList();
    if(gameModes.Length == 0) return;

    ArrayList validGameModes = new ArrayList(sizeof(GameModeConfig));
    for (int i = 0; i < gameModes.Length; i++)
    {
        GameModeConfig config;
        gameModes.GetArray(i, config);
        
        if (!config.enabled || config.adminonly) continue;
        
        validGameModes.PushArray(config);
    }
    
    if(validGameModes.Length == 0) return;

    int iRandomMode = GetRandomInt(0, validGameModes.Length - 1);
    GameModeConfig config;
    validGameModes.GetArray(iRandomMode, config);

    if(config.maps.Length == 0) return;

    int iRandomMap = GetRandomInt(0, config.maps.Length - 1);
    char sMap[PLATFORM_MAX_PATH];
    config.maps.GetString(iRandomMap, sMap, sizeof(sMap));

    if(IsMapValid(sMap))
    {
        if(bSetNextMap || StrEqual(g_sNextMap, "")) 
        {
            strcopy(g_sNextMap, sizeof(g_sNextMap), sMap);
            SetNextMap(sMap);
            WriteToLogFile("[Random Cycle] Selected map: %s (Mode: %s)", sMap, config.name);
        }
    }
    
    if (bSetNextMap || StrEqual(g_sNextMap, "")) 
    {
        strcopy(g_sNextMap, sizeof(g_sNextMap), sMap);
        strcopy(g_sNextGameMode, sizeof(g_sNextGameMode), config.name);
    }
    delete validGameModes;
}

public Action Timer_StartEndVote(Handle timer)
{
    if(g_Cvar_EndVoteEnabled.BoolValue) 
    {
        if (g_hEndVoteTimer == null || g_hEndVoteTimer == INVALID_HANDLE) 
        {
            g_hEndVoteTimer = CreateTimer(1.0, Timer_CheckEndVote, _, TIMER_REPEAT);
        }
    }
    return Plugin_Stop;
}

// Check End Vote fixed by RayanfhoulaBR

public Action Timer_CheckEndVote(Handle timer)
{
    if(!g_Cvar_EndVoteEnabled.BoolValue || g_bVoteActive || g_bEndVoteTriggered || g_bRtvDisabled || g_bVoteCompleted)
    {
        if(g_Cvar_EndVoteDebug.BoolValue) 
            WriteToLogFile("[End Vote] Verification skipped: System disabled/voting active/triggered/RTV blocked");
        return Plugin_Continue;
    }

    bool bMinEnabled = (g_Cvar_EndVoteMin.IntValue > 0);
    bool bRoundsEnabled = (g_Cvar_EndVoteRounds.IntValue > 0);
    bool bFragsEnabled = (g_Cvar_EndVoteFrags.IntValue > 0);
    
    if (!bMinEnabled && !bRoundsEnabled && !bFragsEnabled)
    {
        if(g_Cvar_EndVoteDebug.BoolValue) 
            WriteToLogFile("[End Vote] Verification skipped: System disabled/voting active/triggered/RTV blocked");
        return Plugin_Continue;
    }

    if (bMinEnabled)
    {
        int timeleft;
        bool bTimeLeftValid = GetMapTimeLeft(timeleft);
        int iTrigger = g_Cvar_EndVoteMin.IntValue * 60;
        
        if (bTimeLeftValid && timeleft > 0)
        {
            int timeUntilEndVote = timeleft - iTrigger;
            if (timeUntilEndVote >= 0)
            {
                CountdownMessages("TimeLeft", timeUntilEndVote);
            }

            if (timeleft <= iTrigger)
            {
                if(g_Cvar_EndVoteDebug.BoolValue) 
                    WriteToLogFile("[End Vote] Triggered! Starting vote... (Remaining: %ds <= Trigger: %ds)", timeleft, iTrigger);
					
                PerformEndVote();
                return Plugin_Stop;
            }
        }
        else
        {
            int currentTime = GetTime();
            int elapsed = currentTime - g_iMapStartTime;
            float currentTimeLimit = g_hCvarTimeLimit.FloatValue;
            int totalTimeLimit = RoundToFloor(currentTimeLimit * 60.0); 
            int iTimeLeft = totalTimeLimit - elapsed;

            if(iTimeLeft < 0) 
                iTimeLeft = 0;

            if(g_Cvar_EndVoteDebug.BoolValue)
                WriteToLogFile("[End Vote] Fallback calculation: TimeLimit=%.1fmin | Elapsed=%dmin | Remainder=%dmin", currentTimeLimit, elapsed/60, iTimeLeft/60);

            int timeUntilEndVote = iTimeLeft - iTrigger;
            if (timeUntilEndVote >= 0)
            {
                CountdownMessages("TimeLeft", timeUntilEndVote);
            }

            if(iTimeLeft <= iTrigger)
            {
                if(g_Cvar_EndVoteDebug.BoolValue) 
                    WriteToLogFile("[End Vote] Fallback triggered! Starting vote... (Remaining: %ds <= Trigger: %ds)", iTimeLeft, iTrigger);

                PerformEndVote();
                return Plugin_Stop;
            }
        }
    }
    
    if (bRoundsEnabled)
    {
        ConVar maxRounds = FindConVar("mp_maxrounds");
        ConVar winLimit = FindConVar("mp_winlimit");
        int roundsRemaining = -1;
        
        if (maxRounds != null && maxRounds.IntValue > 0)
        {
            int roundsPlayed = GetTeamScore(2) + GetTeamScore(3);
            roundsRemaining = maxRounds.IntValue - roundsPlayed;
        }
        else if (winLimit != null && winLimit.IntValue > 0)
        {
            roundsRemaining = winLimit.IntValue - GetTeamScore(winLimit.IntValue == GetTeamScore(2) ? 2 : 3);
        }
        
        if (roundsRemaining > 0)
        {
            int untilVote = roundsRemaining - g_Cvar_EndVoteRounds.IntValue;
        
            if (untilVote >= 0)
            {
                CountdownMessages("Rounds", untilVote);
            }

            if (untilVote == 0)
            {
                PerformEndVote();
                return Plugin_Stop;
            }
        }
    }
    
    if (bFragsEnabled)
    {
        ConVar fragLimit = FindConVar("mp_fraglimit");
        if (fragLimit != null && fragLimit.IntValue > 0)
        {
            int maxFrags = 0;
            for (int i = 1; i <= MaxClients; i++)
            {
                if (IsClientInGame(i) && !IsFakeClient(i))
                {
                    int frags = GetClientFrags(i);
                    if (frags > maxFrags) maxFrags = frags;
                }
            }
            int fragsRemaining = fragLimit.IntValue - maxFrags;
            
            if (fragsRemaining > 0)
            {
                int untilVoteFrags = fragsRemaining - g_Cvar_EndVoteFrags.IntValue;

                if (untilVoteFrags >= 0)
                {
                    CountdownMessages("Frags", untilVoteFrags);
                }

                if (untilVoteFrags == 0)
                {
                    PerformEndVote();
                    return Plugin_Stop;
                }
            }
        }
    }
    
    return Plugin_Continue;
}

void PerformEndVote()
{
    if(g_Cvar_EndVoteDebug.BoolValue) 
        WriteToLogFile("[End Vote] Triggered! Starting vote...");
    
    g_bEndVoteTriggered = true;
    
    if (g_hEndVoteTimer != INVALID_HANDLE)
    {
        KillTimer(g_hEndVoteTimer);
        g_hEndVoteTimer = INVALID_HANDLE;
    }
    
    if (g_Cvar_EndVoteOnRoundEnd.BoolValue)
    {
        g_bEndVotePending = true;
        return;
    }
    
    int endType = g_Cvar_EndVoteType.IntValue;
    if(endType < 1) endType = 1;
    else if(endType > 3) endType = 3;
    g_eCurrentVoteTiming = view_as<TimingMode>(endType - 1);
    g_eVoteTiming = g_eEndVoteTiming;
        
    if(g_Cvar_EndVoteDebug.BoolValue)
        WriteToLogFile("[End Vote] Vote type selected: %d (%s)", endType, 
            (g_eCurrentVoteTiming == TIMING_NEXTMAP) ? "Next Map" : 
            (g_eCurrentVoteTiming == TIMING_NEXTROUND) ? "Next Round" : "Instant");
    
    g_eEndVoteTiming = view_as<TimingMode>(endType - 1);
    StartGameModeVote(0, false);
    
    g_eVoteTiming = g_eCurrentVoteTiming;
}

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
            PrintCenterText(i, "%t", "Cooldown Hud", remaining);
        }
    }
    
    return (remaining > 0) ? Plugin_Continue : Plugin_Stop;
}

public Action Timer_EndCooldown(Handle timer)
{
    g_bCooldownActive = false;
    g_hCooldownTimer = INVALID_HANDLE;
    
    StartMapVote(g_iVoteInitiator, g_sVoteGameMode);
    return Plugin_Stop;
}

void UpdateCurrentGameMode(const char[] map)
{
    ArrayList gameModes = GetGameModesList();
    for(int i = 0; i < gameModes.Length; i++)
    {
        GameModeConfig config;
        gameModes.GetArray(i, config);
        
        if(config.maps.FindString(map) != -1)
        {
            strcopy(g_sCurrentGameMode, sizeof(g_sCurrentGameMode), config.name);
            return;
        }
    }
    
    g_sCurrentGameMode[0] = '\0';
}

// //////////////////
// //              //
// //    Events    //
// //              //
// //////////////////

// Events

public void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
    if (change_map_round)
    {
        change_map_round = false;
        CreateTimer(3.0, Timer_ChangeMap);
    }
    
    if (g_bEndVotePending)
    {
        g_bEndVotePending = false;
        
        int endType = g_Cvar_EndVoteType.IntValue;
        if(endType < 1) endType = 1;
        else if(endType > 3) endType = 3;
        g_eCurrentVoteTiming = view_as<TimingMode>(endType - 1);
        g_eVoteTiming = g_eEndVoteTiming;
        
        g_eEndVoteTiming = view_as<TimingMode>(endType - 1);
        StartGameModeVote(0, false);
        
        g_eVoteTiming = g_eCurrentVoteTiming;
    }
}

public void Event_ServerSpawn(Event event, const char[] name, bool dontBroadcast)
{
    if (strlen(g_sPendingCommand) > 0)
    {
        WriteToLogFile("[MultiMode Core] Executing pending command: %s", g_sPendingCommand);
        ServerCommand(g_sPendingCommand);
        g_sPendingCommand[0] = '\0';
    }
}

public void Event_GameOver(Event event, const char[] name, bool dontBroadcast)
{
    if (g_bGameEndTriggered) return;

    if (StrEqual(g_sNextMap, ""))
    {
        if(g_Cvar_RandomCycleEnabled.BoolValue && 
           g_Cvar_RandomCycleType.IntValue == 2 && 
           !g_bVoteCompleted)
        {
            SelectRandomNextMap(true);
            WriteToLogFile("[Random Cycle] Type 2: Map set at the end of the game.");
        }
    }
	
	ExecutePreCommands();
	
    g_bGameEndTriggered = true;
}

public Action OnPlayerChat(int client, const char[] command, int argc)
{
    if (argc == 0)
        return Plugin_Continue;

    char text[13];
    GetCmdArg(1, text, sizeof(text));

    if (StrEqual(text, "rtv", false) || StrEqual(text, "rockthevote", false))
    {
        Command_RTV(client, 0);
        return Plugin_Continue;
    }
	
    else if (StrEqual(text, "nominate", false))
    {
        Command_Nominate(client, 0);
        return Plugin_Continue;
    }

    return Plugin_Continue;
}

public void OnCountdownCvarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
    if (g_Cvar_CountdownEnabled.BoolValue)
    {
        LoadCountdownConfig();
    }
}

public void OnSoundConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
    if (g_Cvar_VoteSounds.BoolValue)
    {
        char downloadPath[PLATFORM_MAX_PATH];
        
        if (convar == g_Cvar_VoteOpenSound)
        {
            if (newValue[0] != '\0')
            {
                PrecacheSoundAny(newValue);
                FormatEx(downloadPath, sizeof(downloadPath), "sound/%s", newValue);
                if (FileExists(downloadPath, true))
                {
                    AddFileToDownloadsTable(downloadPath);
                }
                else
                {
                    WriteToLogFile("Opening sound file not found: %s", downloadPath);
                }
            }
        }
        else if (convar == g_Cvar_VoteCloseSound)
        {
            if (newValue[0] != '\0')
            {
                PrecacheSoundAny(newValue);
                FormatEx(downloadPath, sizeof(downloadPath), "sound/%s", newValue);
                if (FileExists(downloadPath, true))
                {
                    AddFileToDownloadsTable(downloadPath);
                }
                else
                {
                    WriteToLogFile("Closing sound file not found: %s", downloadPath);
                }
            }
        }
    }
}

public void OnTimelimitChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
    if(g_bInternalChange) return;
    
    g_iMapStartTime = GetTime();
    
    if(g_Cvar_EndVoteDebug.BoolValue)
    {
        WriteToLogFile("[End Vote] mp_timelimit changed externally! New value: %smin", newValue);
    }
    
    if (g_hEndVoteTimer != INVALID_HANDLE)
    {
        KillTimer(g_hEndVoteTimer);
        g_hEndVoteTimer = INVALID_HANDLE;
    }

    if (g_Cvar_EndVoteEnabled.BoolValue)
    {
        g_hEndVoteTimer = CreateTimer(1.0, Timer_CheckEndVote, _, TIMER_REPEAT);
    }
}

public void OnMapTimeLeftChanged()
{
    WriteToLogFile("[End Vote] Map time left changed. Resetting End Vote timer...");
	
    if (g_hEndVoteTimer != null)
    {
        KillTimer(g_hEndVoteTimer);
        g_hEndVoteTimer = null;
    }

    if (g_Cvar_EndVoteEnabled.BoolValue)
    {
        g_hEndVoteTimer = CreateTimer(1.0, Timer_CheckEndVote, _, TIMER_REPEAT);
    }
}

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

    int index = FindGameModeIndex(g_sCurrentGameMode);
    if (index == -1)
        return;

    GameModeConfig config;
    ArrayList list = GetGameModesList();
    list.GetArray(index, config);

    if (strlen(config.pre_command) > 0)
    {
        ServerCommand("%s", config.pre_command);
        WriteToLogFile("[MultiMode Core] Executed group pre-command: %s", config.pre_command);
    }

    char currentMap[PLATFORM_MAX_PATH];
    GetCurrentMap(currentMap, sizeof(currentMap));
    
    KeyValues kv = GetMapKv(g_sCurrentGameMode, currentMap);
    if (kv != null)
    {
        char mapPreCommand[256];
        kv.GetString("pre-command", mapPreCommand, sizeof(mapPreCommand), "");
        if (strlen(mapPreCommand) > 0)
        {
            ServerCommand("%s", mapPreCommand);
            WriteToLogFile("[MultiMode Core] Executed map pre-command: %s", mapPreCommand);
        }
        delete kv;
    }
}

void ExecuteVoteCommands(const char[] gamemode, const char[] map)
{
    int index = FindGameModeIndex(gamemode);
    if (index == -1)
        return;

    GameModeConfig config;
    ArrayList list = GetGameModesList();
    list.GetArray(index, config);
	
    if (strlen(config.vote_command) > 0)
    {
        ServerCommand("%s", config.vote_command);
        WriteToLogFile("[MultiMode Core] Executed group vote-command: %s", config.vote_command);
    }

    KeyValues kv = GetMapKv(gamemode, map);
    if (kv != null)
    {
        char mapVoteCommand[256];
        kv.GetString("vote-command", mapVoteCommand, sizeof(mapVoteCommand), "");
        if (strlen(mapVoteCommand) > 0)
        {
            ServerCommand("%s", mapVoteCommand);
            WriteToLogFile("[MultiMode Core] Executed map vote-command: %s", mapVoteCommand);
        }
        delete kv;
    }
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

    topmenu.AddItem("sm_forcemode", AdminMenu_ForceMode, category, "sm_forcemode", ADMFLAG_CHANGEMAP);
    topmenu.AddItem("sm_votemode", AdminMenu_StartVote, category, "sm_votemode", ADMFLAG_VOTE);
    topmenu.AddItem("sm_cancelvote", AdminMenu_CancelVote, category, "sm_cancelvote", ADMFLAG_VOTE);
    topmenu.AddItem("sm_extendmap", AdminMenu_ExtendMap, category, "sm_extendmap", ADMFLAG_CHANGEMAP);
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

void ShowExtendTimeMenu(int client)
{
    Menu menu = new Menu(ExtendTimeMenuHandler);
    menu.SetTitle("Extend Current Map:\nSelect a time to add:\n \n");
    
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
        ExtendMapTimeEx(client, minutes);
    }
    else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack)
    {
        RedisplayAdminMenu(GetAdminTopMenu(), client);
    }
    else if (action == MenuAction_End)
    {
        delete menu;
    }
    return 0;
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
            g_bEndVoteTriggered = false;
            g_bVoteCompleted = false;
            
            if (g_Cvar_VoteSounds.BoolValue)
            {
                char sound[PLATFORM_MAX_PATH];
                g_Cvar_VoteCloseSound.GetString(sound, sizeof(sound));
                if (sound[0] != '\0')
                {
                    EmitSoundToAllAny(sound);
                }
            }
            
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
        ShowVoteTypeMenu(client);
    }
}

void ShowVoteTypeMenu(int client)
{
    Menu menu = new Menu(VoteTypeMenuHandler);
    char buffer[128];
	
    Format(buffer, sizeof(buffer), "%T", "Vote Type Menu Title", client);
    menu.SetTitle(buffer);
	
    Format(buffer, sizeof(buffer), "%T", "Vote Type Normal", client);
    menu.AddItem("normal", buffer);

    Format(buffer, sizeof(buffer), "%T", "Vote Type Admin", client);
    menu.AddItem("normaladmin", buffer);

    Format(buffer, sizeof(buffer), "%T", "Vote Type Separated", client);
    menu.AddItem("separated", buffer);

    menu.Display(client, MENU_TIME_FOREVER);
}


public int VoteTypeMenuHandler(Menu menu, MenuAction action, int client, int param2)
{
    if (action == MenuAction_Select)
    {
        char type[16];
        menu.GetItem(param2, type, sizeof(type));

        if (StrEqual(type, "normal"))
        {
            SetClientCookie(client, g_hCookieVoteType, "normal");
            ShowTimingSelectionMenu(client);
        }
        else if (StrEqual(type, "normaladmin"))
        {
            SetClientCookie(client, g_hCookieVoteType, "normaladmin");
            ShowTimingSelectionMenu(client);
        }
        else if (StrEqual(type, "separated"))
        {
            SetClientCookie(client, g_hCookieVoteType, type);
            ShowTimingSelectionMenu(client);
        }
    }
    else if (action == MenuAction_End)
    {
        delete menu;
    }
    return 0;
}

public int TimingSelectionMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
    if (action == MenuAction_Select)
    {
        TimingMode timing = view_as<TimingMode>(param2);
        g_eVoteTiming = timing;
        
        char voteType[16];
        GetClientCookie(param1, g_hCookieVoteType, voteType, sizeof(voteType));
        
        if (StrEqual(voteType, "separated"))
        {
            StartSeparatedVote(param1);
        }
        else if (StrEqual(voteType, "normal"))
        {
            StartGameModeVote(param1, false);
        }
        else if (StrEqual(voteType, "normaladmin"))
        {
            StartGameModeVote(param1, true);
        }
    }
    else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack)
    {
        ShowVoteTypeMenu(param1);
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
    
    char voteType[16];
    GetClientCookie(client, g_hCookieVoteType, voteType, sizeof(voteType));
    
    Menu menu = new Menu(TimingSelectionMenuHandler);
    menu.SetTitle("Quando aplicar a votação?");
    
    FormatEx(buffer, sizeof(buffer), "%t", "Timing NextMap");
    menu.AddItem("nextmap", buffer);

    FormatEx(buffer, sizeof(buffer), "%t", "Timing NextRound");
    menu.AddItem("nextround", buffer);

    FormatEx(buffer, sizeof(buffer), "%t", "Timing Instant");
    menu.AddItem("instant", buffer);
    
    menu.ExitBackButton = true;
    menu.Display(client, MENU_TIME_FOREVER);
}

void StartSeparatedVote(int client)
{
    if (GetVoteMethod() == 3)
    {
        StartMapVote(client, "");
        return;
    }

    Menu menu = new Menu(SeparatedGameModeMenuHandler);
    menu.SetTitle("%t", "Show Gamemode Admin Title");
    
    ArrayList gameModes = GetGameModesList();
    for (int i = 0; i < gameModes.Length; i++)
    {
        GameModeConfig config;
        gameModes.GetArray(i, config);
        
        char display[128];
        if (config.adminonly == 1) 
            Format(display, sizeof(display), "[ADMIN] %s", config.name);
        else 
            strcopy(display, sizeof(display), config.name);
        
        menu.AddItem(config.name, display);
    }
    
    menu.Display(client, MENU_TIME_FOREVER);
}

public int SeparatedGameModeMenuHandler(Menu menu, MenuAction action, int client, int param2)
{
    if (action == MenuAction_Select)
    {
        char gamemode[64];
        menu.GetItem(param2, gamemode, sizeof(gamemode));
        
        if (GetVoteMethod() == 2)
        {
            int index = FindGameModeIndex(gamemode);
            if (index != -1)
            {
                GameModeConfig config;
                ArrayList list = GetGameModesList();
                list.GetArray(index, config);
        
                if (config.maps.Length > 0)
                {
                    int randomIndex = GetRandomInt(0, config.maps.Length - 1);
                    char map[PLATFORM_MAX_PATH];
                    config.maps.GetString(randomIndex, map, sizeof(map));
            
                    ExecuteModeChange(gamemode, map, view_as<int>(g_eVoteTiming));
                }
            }
        }
        else if (GetVoteMethod() == 3)
        {
            StartMapVote(client, "");
        }
        else
        {
            StartMapVote(client, gamemode);
        }
    }
    else if (action == MenuAction_End)
    {
        delete menu;
    }
    return 0;
}

public int SeparatedTimingMenuHandler(Menu menu, MenuAction action, int client, int param2)
{
    if (action == MenuAction_Select)
    {
        TimingMode timing = view_as<TimingMode>(param2);
        g_eCurrentVoteTiming = timing;
        StartMapVote(client, g_sVoteGameMode);
    }
    else if (action == MenuAction_End)
    {
        delete menu;
    }
    return 0;
}

public int ForceGameModeMenuHandler(Menu menu, MenuAction action, int client, int param2)
{
    if (action == MenuAction_Select)
    {
        char sGameMode[64];
        menu.GetItem(param2, sGameMode, sizeof(sGameMode));
        strcopy(g_sClientPendingGameMode[client], sizeof(g_sClientPendingGameMode[]), sGameMode);
        ShowMapMenu(client, sGameMode);
    }
    else if (action == MenuAction_End)
    {
        delete menu;
    }
    return 0;
}

public int ForceTimingMenuHandler(Menu menu, MenuAction action, int client, int param2)
{
    if (action == MenuAction_Select)
    {
        ExecuteModeChange(
            g_sClientPendingGameMode[client],
            g_sClientPendingMap[client],
            view_as<int>(view_as<TimingMode>(param2))
        );
    }
    else if (action == MenuAction_End)
    {
        delete menu;
    }
    return 0;
}

// //////////////////////////
// //                      //
// //    Rock The Vote     //
// //                      //
// //////////////////////////

// Rock The Vote

public Action Command_RTV(int client, int args)
{
    if(!g_Cvar_RtvEnabled.BoolValue) 
    {
        CPrintToChat(client, "%t", "RTV System Disabled");
        return Plugin_Handled;
    }

    if(!g_Cvar_Enabled.BoolValue || g_bVoteActive || g_bCooldownActive || g_bRtvDisabled) 
    {
        CPrintToChat(client, "%t", "RTV System Disabled");
        return Plugin_Handled;
    }
    
    if(g_bRtvInitialDelay) 
    {
        float fRemaining = GetRemainingTime(0);
        CPrintToChat(client, "%t", "RTV Wait", RoundFloat(fRemaining));
        return Plugin_Handled;
    }
    
    if(g_bRtvCooldown) 
    {
        float fRemaining = GetRemainingTime(1);
        CPrintToChat(client, "%t", "RTV Wait Again", RoundFloat(fRemaining));
        return Plugin_Handled;
    }
    
    if(g_bRtvVoted[client]) 
    {
        CPrintToChat(client, "%t", "RTV Already Voted");
        return Plugin_Handled;
    }
    
    int iPlayers = GetRealClientCount();
    float ratio = g_Cvar_RtvRatio.FloatValue;
    int minRequired = g_Cvar_RtvMinPlayers.IntValue;
    int iRequired = RoundToCeil(float(iPlayers) * ratio);
    if (iRequired < minRequired) 
    {
        iRequired = minRequired;
    }
    
    if(iPlayers < iRequired) 
    {
        CPrintToChat(client, "%t", "RTV Minimun Players", iRequired);
        return Plugin_Handled;
    }
    
    g_bRtvVoted[client] = true;
    g_iRtvVotes++;
    
    CPrintToChatAll("%t", "Wants To Vote", client, g_iRtvVotes, iRequired);
    
    if(g_iRtvVotes >= iRequired) 
    {
        int rtvType = g_Cvar_RtvType.IntValue;
        if(rtvType < 1) rtvType = 1;
        else if(rtvType > 3) rtvType = 3;
        g_eCurrentVoteTiming = view_as<TimingMode>(rtvType - 1);
		g_eVoteTiming = g_eCurrentVoteTiming;
        
        StartGameModeVote(0, false);
        ResetRTV();
    }
    
    return Plugin_Handled;
}

void ResetRTV()
{
    g_iRtvVotes = 0;
    for(int i = 1; i <= MaxClients; i++) {
        g_bRtvVoted[i] = false;
    }
}

void StartRtvCooldown()
{
    float fDelay = g_Cvar_RtvDelay.FloatValue;
    if(fDelay > 0.0) {
        g_bRtvCooldown = true;
        g_fRtvTimerStart[1] = GetEngineTime();
        g_fRtvTimerDuration[1] = fDelay;
        g_hRtvTimers[1] = CreateTimer(fDelay, Timer_ResetCooldown, _, TIMER_FLAG_NO_MAPCHANGE);
        CPrintToChatAll("%t", "RTV Next Available", RoundFloat(fDelay));
    }
}

// ////////////////////
// //                //
// //    Nominate    //
// //                //
// ////////////////////

// Nominate

public Action Command_Nominate(int client, int args)
{
    if(!g_Cvar_Enabled.BoolValue || !g_Cvar_NominateEnabled.BoolValue || g_bVoteActive || g_bCooldownActive || g_bRtvDisabled) 
	{
        CReplyToCommand(client, "%t", "Nominate Disabled");
        return Plugin_Handled;
    }
    
    if (!client || !IsClientInGame(client)) 
        return Plugin_Handled;

    if (g_Cvar_NominateOneChance.BoolValue && g_bHasNominated[client])
    {
        CPrintToChat(client, "%t", "Nominate Once Per Map");
        return Plugin_Handled;
    }

    ShowNominateGamemodeMenu(client);
    return Plugin_Handled;
}

void ShowNominateGamemodeMenu(int client)
{
    Menu menu = new Menu(NominateGamemodeMenuHandler);
    menu.SetTitle("%t", "Nominate Gamemode Group Menu Title");

    ArrayList originalList = GetGameModesList();
    ArrayList gameModes = new ArrayList(originalList.BlockSize);  // Clonar lista
    for (int i = 0; i < originalList.Length; i++)
    {
        GameModeConfig config;
        originalList.GetArray(i, config);
        gameModes.PushArray(config);
    }

    int sortMode = g_Cvar_NominateSorted.IntValue;
    if (sortMode == 0)
    {
        SortADTArray(gameModes, Sort_Ascending, Sort_String);
    }
    else if (sortMode == 1)
    {
        SortADTArray(gameModes, Sort_Random, Sort_String);
    }

    for (int i = 0; i < gameModes.Length; i++)
    {
        GameModeConfig config;
        gameModes.GetArray(i, config);

        if (g_Cvar_NominateSelectedGroupExclude.BoolValue &&
            g_NominatedGamemodes.FindString(config.name) != -1)
        {
            continue;
        }

        if (g_Cvar_NominateGroupExclude.IntValue > 0 &&
            g_PlayedGamemodes.FindString(config.name) != -1)
        {
            continue;
        }

        if (!GamemodeAvailable(config.name))
        {
            continue;
        }

        char display[128];
        if (g_NominatedGamemodes.FindString(config.name) != -1)
        {
            Format(display, sizeof(display), "%s (Nomeado)", config.name);
        }
        else
        {
            strcopy(display, sizeof(display), config.name);
        }

        menu.AddItem(config.name, display);
    }

    delete gameModes;
    menu.Display(client, MENU_TIME_FOREVER);
}

public int NominateGamemodeMenuHandler(Menu menu, MenuAction action, int client, int param2)
{
    if (action == MenuAction_Select)
    {
        char gamemode[64];
        menu.GetItem(param2, gamemode, sizeof(gamemode));
        strcopy(g_NominateGamemode[client], sizeof(g_NominateGamemode[]), gamemode);
        ShowNominateMapMenu(client, gamemode);
    }
    else if (action == MenuAction_End)
    {
        delete menu;
    }
    return 0;
}

void ShowNominateMapMenu(int client, const char[] gamemode)
{
    int index = FindGameModeIndex(gamemode);
    if (index == -1)
    {
        CPrintToChat(client, "%t", "Nominate Gamemode Not Found");
        return;
    }

    GameModeConfig config;
    ArrayList list = GetGameModesList();
    list.GetArray(index, config);

    ArrayList availableMaps = new ArrayList(ByteCountToCells(PLATFORM_MAX_PATH));

    ArrayList excludeMaps = null;
    if (g_Cvar_NominateMapExclude.IntValue > 0)
    {
        g_PlayedMaps.GetValue(gamemode, excludeMaps);
    }

    for (int i = 0; i < config.maps.Length; i++)
    {
        char map[PLATFORM_MAX_PATH];
        config.maps.GetString(i, map, sizeof(map));

        if (excludeMaps != null && excludeMaps.FindString(map) != -1)
        {
            continue;
        }

        availableMaps.PushString(map);
    }

    int sortMode = g_Cvar_NominateSorted.IntValue;
    if (sortMode == 0)
    {
        SortADTArray(availableMaps, Sort_Ascending, Sort_String);
    }
    else if (sortMode == 1)
    {
        SortADTArray(availableMaps, Sort_Random, Sort_String);
    }

    Menu menu = new Menu(NominateMapMenuHandler);
    menu.SetTitle("%t", "Nominate Map Title", config.name);

    ArrayList mapsNominated;
    g_NominatedMaps.GetValue(gamemode, mapsNominated);

    for (int i = 0; i < availableMaps.Length; i++)
    {
        char map[PLATFORM_MAX_PATH];
        availableMaps.GetString(i, map, sizeof(map));

        if (g_Cvar_NominateSelectedMapExclude.BoolValue && 
            mapsNominated != null && 
            mapsNominated.FindString(map) != -1)
        {
            continue;
        }

        char displayName[256];
        GetMapDisplayNameEx(gamemode, map, displayName, sizeof(displayName));

        if (mapsNominated != null && mapsNominated.FindString(map) != -1)
        {
            Format(displayName, sizeof(displayName), "%s (Nomeado)", displayName);
        }

        menu.AddItem(map, displayName);
    }

    delete availableMaps;

    menu.ExitBackButton = true;
    menu.Display(client, MENU_TIME_FOREVER);
}

public int NominateMapMenuHandler(Menu menu, MenuAction action, int client, int param2)
{
    if (action == MenuAction_Select)
    {
        char map[PLATFORM_MAX_PATH];
        menu.GetItem(param2, map, sizeof(map));
        RegisterNomination(client, g_NominateGamemode[client], map);
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

void RegisterNomination(int client, const char[] gamemode, const char[] map)
{
    if (g_NominatedGamemodes.FindString(gamemode) == -1)
        g_NominatedGamemodes.PushString(gamemode);

    ArrayList mapsNominated;
    if (!g_NominatedMaps.GetValue(gamemode, mapsNominated))
    {
        mapsNominated = new ArrayList(ByteCountToCells(PLATFORM_MAX_PATH));
        g_NominatedMaps.SetValue(gamemode, mapsNominated);
    }
    
    if (mapsNominated.FindString(map) == -1)
        mapsNominated.PushString(map);

    g_bHasNominated[client] = true;
    
    CPrintToChat(client, "%t", "Nominated Client", gamemode, map);
    
    char clientName[MAX_NAME_LENGTH];
    GetClientName(client, clientName, sizeof(clientName));
    
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i) && !IsFakeClient(i) && i != client)
        {
            CPrintToChat(i, "%t", "Nominated Server", clientName, gamemode, map);
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
    StartGameModeVote(client, adminVote);
    return 0;
}

public int NativeMMC_IsVoteActive(Handle plugin, int numParams)
{
    return g_bVoteActive;
}

public int NativeMMC_GetCurrentGameMode(Handle plugin, int numParams)
{
    int maxlen = GetNativeCell(2);
    SetNativeString(1, g_sCurrentGameMode, maxlen);
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

    GetMapDisplayNameEx(g_sNextGameMode, g_sNextMap, displayName, sizeof(displayName));
    SetNativeString(1, displayName, maxlen);
    return 0;
}


public int NativeMMC_Nominate(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    char gamemode[64], map[PLATFORM_MAX_PATH];
    GetNativeString(2, gamemode, sizeof(gamemode));
    GetNativeString(3, map, sizeof(map));
    
    if(FindGameModeIndex(gamemode) == -1 || !IsMapValid(map))
        return false;
    
    RegisterNomination(client, gamemode, map);
    return true;
}

public int NativeMMC_GetNextGameMode(Handle plugin, int numParams)
{
    int maxlen = GetNativeCell(2);
    
    if(strlen(g_sNextGameMode) > 0) {
        SetNativeString(1, g_sNextGameMode, maxlen);
    }
    else if(g_Cvar_RandomCycleEnabled.BoolValue && StrEqual(g_sNextMap, "")) {
        char randomGamemode[64];
        GetRandomGameMode(randomGamemode, sizeof(randomGamemode));
        SetNativeString(1, randomGamemode, maxlen);
    }
    else {
        SetNativeString(1, "", maxlen);
    }
    
    return 0;
}

public int NativeMMC_IsRandomCycleEnabled(Handle plugin, int numParams)
{
    return g_Cvar_RandomCycleEnabled.BoolValue;
}

public int NativeMMC_GetCurrentMap(Handle plugin, int numParams)
{
    int maxlen = GetNativeCell(2);
    char map[PLATFORM_MAX_PATH];
    char displayName[PLATFORM_MAX_PATH];
    
    GetCurrentMap(map, sizeof(map));
    GetMapDisplayNameEx(g_sCurrentGameMode, map, displayName, sizeof(displayName));
    
    SetNativeString(1, displayName, maxlen);
    return 0;
}

void GetRandomGameMode(char[] buffer, int maxlength)
{
    ArrayList gameModes = GetGameModesList();
    if(gameModes.Length > 0) {
        int index = GetRandomInt(0, gameModes.Length-1);
        GameModeConfig config;
        gameModes.GetArray(index, config);
        strcopy(buffer, maxlength, config.name);
    }
    else {
        buffer[0] = '\0';
    }
}

// //////////////////////////
// //                      //
// //    Commands Extra    //
// //                      //
// //////////////////////////

// Commands Extra

public Action Command_ToggleVoteSounds(int client, int args)
{
    bool newValue = !g_Cvar_VoteSounds.BoolValue;
    g_Cvar_VoteSounds.SetBool(newValue);
    
    return Plugin_Handled;
}

int GetRealClientCount()
{
    int count = 0;
    for(int i = 1; i <= MaxClients; i++) {
        if(IsClientInGame(i) && !IsFakeClient(i)) {
            count++;
        }
    }
    return count;
}

float GetRemainingTime(int timerIndex)
{
    if(timerIndex < 0 || timerIndex >= sizeof(g_hRtvTimers)) return 0.0;
    if(g_hRtvTimers[timerIndex] == INVALID_HANDLE) return 0.0;
    
    float elapsed = GetEngineTime() - g_fRtvTimerStart[timerIndex];
    float remaining = g_fRtvTimerDuration[timerIndex] - elapsed;
    return remaining > 0.0 ? remaining : 0.0;
}

public Action Command_ForceMode(int client, int args)
{
    ShowGameModeMenu(client, true);
    return Plugin_Handled;
}

public Action Command_VoteMenu(int client, int args)
{
    if (!g_Cvar_Enabled.BoolValue || g_bVoteActive || g_bCooldownActive)
    {
        return Plugin_Handled;
    }
    
    StartGameModeVote(client, false);
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
        g_bEndVoteTriggered = false;
        g_bVoteCompleted = false;
        
        if (g_Cvar_VoteSounds.BoolValue)
        {
            char sound[PLATFORM_MAX_PATH];
            g_Cvar_VoteCloseSound.GetString(sound, sizeof(sound));
            if (sound[0] != '\0')
            {
                EmitSoundToAllAny(sound);
            }
        }
        
        CPrintToChatAll("%t", "Admin Cancel Vote", client);
    }
    else
    {
        CPrintToChat(client, "%t", "Admin Cancel No Vote");
    }
    
    return Plugin_Handled;
}

void ShowGameModeMenu(int client, bool forceMode)
{
    Menu menu = new Menu(forceMode ? ForceGameModeMenuHandler : GameModeMenuHandler);
    menu.SetTitle("%t", "Show Gamemode Group Title");
    
    ArrayList gameModes = GetGameModesList();
    
    for (int i = 0; i < gameModes.Length; i++)
    {
        GameModeConfig config;
        gameModes.GetArray(i, config);
        
        char display[128];
        if (forceMode)
        {
            if (config.enabled == 0 && config.adminonly == 1)
                Format(display, sizeof(display), "[DISABLED, ADMIN] %s", config.name);
            else if (config.enabled == 0)
                Format(display, sizeof(display), "[DISABLED] %s", config.name);
            else if (config.adminonly == 1)
                Format(display, sizeof(display), "[ADMIN] %s", config.name);
            else
                strcopy(display, sizeof(display), config.name);
        }
        else
        {
            strcopy(display, sizeof(display), config.name);
        }
        
        menu.AddItem(config.name, display);
    }
    
    if (gameModes.Length > 0)
    {
        menu.Display(client, MENU_TIME_FOREVER);
    }
    else
    {
        CPrintToChat(client, "%t", "None Show Gamemode Group");
    }
}

void ShowMapMenu(int client, const char[] sGameMode)
{
    int index = FindGameModeIndex(sGameMode);
    if (index == -1)
    {
        CPrintToChat(client, "%t", "None Show Map Group");
        return;
    }

    GameModeConfig config;
    ArrayList list = GetGameModesList();
    list.GetArray(index, config);

    if (config.maps == null || config.maps.Length == 0)
    {
        CPrintToChat(client, "%t", "None Show Map Group");
        return;
    }

    Menu menu = new Menu(ForceMapMenuHandler);
    menu.SetTitle("%t", "Show Map Group Title", config.name);
    
    ArrayList maps = view_as<ArrayList>(CloneHandle(config.maps));
    maps.Sort(Sort_Random, Sort_String);
    
    char map[256];
    char display[256];
    GetMapDisplayNameEx(config.name, map, display, sizeof(display));
    
    for (int i = 0; i < maps.Length; i++)
    {
        maps.GetString(i, map, sizeof(map));
        
        KeyValues kv = GetMapKv(config.name, map);
        if (kv != null)
        {
            kv.GetString("display", display, sizeof(display), map);
            delete kv;
        }
        else
        {
            if (StrContains(map, "workshop/") == 0)
            {
                char mapParts[2][128];
                if (ExplodeString(map, "/", mapParts, 2, 128) == 2)
                {
                    strcopy(display, sizeof(display), mapParts[1]);
                }
                else
                {
                    strcopy(display, sizeof(display), map);
                }
            }
            else
            {
                strcopy(display, sizeof(display), map);
            }
        }
        
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

void ShowTimingMenu(int client, bool isForcing)
{
    char buffer[125];
    
    Menu menu = new Menu(isForcing ? ForceTimingMenuHandler : SeparatedTimingMenuHandler);
    menu.SetTitle("Quando aplicar?");
    
    FormatEx(buffer, sizeof(buffer), "%t", "Timing NextMap");
    menu.AddItem("nextmap", buffer);

    FormatEx(buffer, sizeof(buffer), "%t", "Timing NextRound");
    menu.AddItem("nextround", buffer);

    FormatEx(buffer, sizeof(buffer), "%t", "Timing Instant");
    menu.AddItem("instant", buffer);
    
    menu.ExitBackButton = true;
    menu.Display(client, MENU_TIME_FOREVER);
}

public int GameModeMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
    if (action == MenuAction_Select)
    {
        char sGameMode[64];
        menu.GetItem(param2, sGameMode, sizeof(sGameMode));
        StartMapVote(param1, sGameMode);
    }
    else if (action == MenuAction_End)
    {
        delete menu;
    }
    return 0;
}

public int TimingMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
    if (action == MenuAction_Select)
    {
        ExecuteVoteResult();
    }
    else if (action == MenuAction_End)
    {
        delete menu;
    }
    return 0;
}

void ExecuteModeChange(const char[] gamemode, const char[] map, int timing)
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

    if (IsValidHandle(g_hEndVoteTimer))
    {
        KillTimer(g_hEndVoteTimer);
        g_hEndVoteTimer = INVALID_HANDLE;
    }

    
    g_bEndVoteTriggered = false;
    g_iRtvVotes = 0;
    
    for (int i = 1; i <= MaxClients; i++)
    {
        g_bRtvVoted[i] = false;
    }

    g_bRtvDisabled = true;
    
    TimingMode mode = view_as<TimingMode>(timing);
    char command[256];
    strcopy(g_sNextGameMode, sizeof(g_sNextGameMode), gamemode);
    strcopy(g_sNextMap, sizeof(g_sNextMap), map);
    

    if (g_kvGameModes.JumpToKey(gamemode))
    {
        g_kvGameModes.GetString("command", command, sizeof(command));
        g_kvGameModes.Rewind();
    }

    switch(mode)
    {
        case TIMING_NEXTMAP:
        {
            SetNextMap(g_sNextMap);
            CPrintToChatAll("%t", "Timing NextMap Notify", g_sNextMap);
            WriteToLogFile("[MultiMode Core] Next map set (admin): %s", g_sNextMap);
        }
        
        case TIMING_NEXTROUND:
        {
            SetNextMap(g_sNextMap);
            change_map_round = true;
            CPrintToChatAll("%t", "Timing NextRound Notify", g_sNextMap);
            WriteToLogFile("[MultiMode Core] Next round map set (admin): %s", g_sNextMap);
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
            WriteToLogFile("[MultiMode Core] Map instantly set to (admin): %s", g_sNextMap);
        }
    }
	
	ExecuteVoteCommands(gamemode, map);
}

void StartGameModeVote(int client, bool adminVote = false)
{
    WriteToLogFile("[MultiMode Core] Stabilized Voting (Gamemode)");
    
    if (!g_Cvar_Enabled.BoolValue || g_bVoteActive || g_bCooldownActive)
    {
        CPrintToChat(client, "%t", "Gamemode Vote Already");
        return;
    }
    
    ArrayList gameModes = GetGameModesList();
    if (gameModes.Length == 0)
    {
        CPrintToChat(client, "%t", "None Show Gamemode Group");
        return;
    }
    
    if (GetVoteMethod() == 3)
    {
        StartMapVote(client, "");
        return;
    }
	
    if (g_hRtvTimers[1] != INVALID_HANDLE)
    {
        KillTimer(g_hRtvTimers[1]);
        g_hRtvTimers[1] = INVALID_HANDLE;
    }
    g_bRtvCooldown = false;
	
	g_eCurrentVoteTiming = g_eVoteTiming;
    
    ArrayList voteGameModes = new ArrayList(ByteCountToCells(64));
    
    int groupExclude = adminVote ? 
        g_Cvar_VoteAdminGroupExclude.IntValue : 
        g_Cvar_VoteGroupExclude.IntValue;

    for (int i = 0; i < g_NominatedGamemodes.Length; i++) 
    {
        char nominatedGM[64];
        g_NominatedGamemodes.GetString(i, nominatedGM, sizeof(nominatedGM));
    
        if (groupExclude > 0 && g_PlayedGamemodes.FindString(nominatedGM) != -1) 
        {
            continue;
        }
    
        int index = FindGameModeIndex(nominatedGM);
        if (index == -1) continue;

        GameModeConfig config;
        gameModes.GetArray(index, config);

        bool available = (adminVote) 
            ? GamemodeAvailableAdminVote(config.name) 
            : GamemodeAvailable(config.name);

        if (available && voteGameModes.FindString(nominatedGM) == -1) 
		{
            voteGameModes.PushString(nominatedGM);
		}
    }
	
    bool bUseRandom = adminVote ? g_Cvar_VoteAdminRandom.BoolValue : g_Cvar_VoteRandom.BoolValue;
    
    if (bUseRandom) 
	{
        voteGameModes.Sort(Sort_Random, Sort_String);
    }
    
    if (voteGameModes.Length > 6)
    {
        voteGameModes.Resize(6);
    }
    
    g_bCurrentVoteAdmin = adminVote;
    
    if (voteGameModes.Length < 6)
    {
        ArrayList remainingGameModes = new ArrayList(ByteCountToCells(64));
        for (int i = 0; i < gameModes.Length; i++)
        {
            GameModeConfig config;
            gameModes.GetArray(i, config);

            bool available;
            if (adminVote) {
                available = (config.enabled == 1);
            } else {
                available = GamemodeAvailable(config.name);
            }

            if (!available) continue;

            if (groupExclude > 0 && g_PlayedGamemodes.FindString(config.name) != -1)
                continue;

            if (g_NominatedGamemodes.FindString(config.name) == -1 && voteGameModes.FindString(config.name) == -1)
            {
                remainingGameModes.PushString(config.name);
            }
        }
        if (bUseRandom && remainingGameModes.Length > 0) 
		{
            remainingGameModes.Sort(Sort_Random, Sort_String);
        }
        
        int needed = 6 - voteGameModes.Length;
        for (int i = 0; i < needed && i < remainingGameModes.Length; i++)
        {
            char gm[64];
            remainingGameModes.GetString(i, gm, sizeof(gm));
            voteGameModes.PushString(gm);
        }
        delete remainingGameModes;
    }
    
    Menu menu = new Menu(GameModeVoteHandler);
    menu.SetTitle("%t", "Normal Vote Gamemode Group Title");
    menu.VoteResultCallback = GameModeVoteResultHandler;
    
    bool canExtend = (g_Cvar_ExtendEveryTime.BoolValue || !g_bMapExtended) && CanExtendMap();
    if (g_Cvar_Extend.BoolValue && canExtend && ((adminVote && g_Cvar_ExtendVoteAdmin.BoolValue) || (!adminVote && g_Cvar_ExtendVote.BoolValue)))
    {
        char extendText[128];
        int extendMinutes = g_Cvar_ExtendSteps.IntValue;
        Format(extendText, sizeof(extendText), "%t", "Extend Map Normal Vote", extendMinutes);
        menu.AddItem("extend", extendText);
    }
        
    if (g_Cvar_VoteSounds.BoolValue)
    {
        char sound[PLATFORM_MAX_PATH];
        g_Cvar_VoteOpenSound.GetString(sound, sizeof(sound));
        if (sound[0] != '\0')
        {
            EmitSoundToAllAny(sound);
        }
    }
    
    for (int i = 0; i < voteGameModes.Length; i++)
    {
        char gm[64];
        voteGameModes.GetString(i, gm, sizeof(gm));
        
        char display[128];
        int index = FindGameModeIndex(gm);
        bool isAdminMode = false;
        
        if (index != -1)
        {
            GameModeConfig config;
            ArrayList list = GetGameModesList();
            list.GetArray(index, config);
            isAdminMode = (config.adminonly == 1);
        }
        
        if (g_NominatedGamemodes.FindString(gm) != -1)
        {
            if (isAdminMode) Format(display, sizeof(display), "[ADMIN] %s (Nomeado)", gm);
            else Format(display, sizeof(display), "%s (Nomeado)", gm);
        }
        else
        {
            if (isAdminMode) Format(display, sizeof(display), "[ADMIN] %s", gm);
            else strcopy(display, sizeof(display), gm);
        }
        
        menu.AddItem(gm, display);
    }
    
    delete voteGameModes;
    
    menu.ExitButton = false;
    menu.DisplayVoteToAll(g_Cvar_VoteTime.IntValue);
    g_bVoteActive = true;
}

void WriteToLogFile(const char[] format, any ...)
{
    if (g_Cvar_Logs.BoolValue)
    {
        char buffer[512];
        VFormat(buffer, sizeof(buffer), format, 2);

        char logPath[PLATFORM_MAX_PATH];
        BuildPath(Path_SM, logPath, sizeof(logPath), "logs/multimode_logs.txt");

        File file = OpenFile(logPath, "a+");
        if (file != null)
        {
            char timeStr[64];
            FormatTime(timeStr, sizeof(timeStr), "%Y-%m-%d %H:%M:%S");
            file.WriteLine("[%s] %s", timeStr, buffer);
            LogMessage("%s", buffer);
            delete file;
        }
        else
        {
            WriteToLogFile("Failed to write to log file: %s", logPath);
        }
    }
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
    int winner = 0;
    for (int i = 1; i < num_items; i++)
    {
        if (item_info[i][VOTEINFO_ITEM_VOTES] > item_info[winner][VOTEINFO_ITEM_VOTES])
        {
            winner = i;
        }
    }

    char gamemode[64];
    menu.GetItem(item_info[winner][VOTEINFO_ITEM_INDEX], gamemode, sizeof(gamemode));
	
	g_eCurrentVoteTiming = g_eVoteTiming;

    if (StrEqual(gamemode, "extend"))
    {
        ExtendMapTime();
        g_bVoteActive = false;
        g_bVoteCompleted = false;
        StartRtvCooldown();
        if (g_Cvar_DiscordExtend.BoolValue)
        {
            NotifyDiscordExtend();
        }

        if (g_Cvar_VoteSounds.BoolValue)
        {
            char sound[PLATFORM_MAX_PATH];
            g_Cvar_VoteCloseSound.GetString(sound, sizeof(sound));
            if (sound[0] != '\0')
            {
                EmitSoundToAllAny(sound);
            }
        }
        return;
    }
    else
    {
        strcopy(g_sVoteGameMode, sizeof(g_sVoteGameMode), gamemode);
        
        if (GetVoteMethod() == 2)
        {
            int index = FindGameModeIndex(gamemode);
            if (index != -1)
            {
                GameModeConfig config;
                ArrayList list = GetGameModesList();
                list.GetArray(index, config);
                
                if (config.maps.Length > 0)
                {
                    int randomIndex = GetRandomInt(0, config.maps.Length - 1);
                    char map[PLATFORM_MAX_PATH];
                    config.maps.GetString(randomIndex, map, sizeof(map));
                    strcopy(g_sVoteMap, sizeof(g_sVoteMap), map);
                    
                    ExecuteVoteResult();
                    
                    if (g_Cvar_VoteSounds.BoolValue)
                    {
                        char sound[PLATFORM_MAX_PATH];
                        g_Cvar_VoteCloseSound.GetString(sound, sizeof(sound));
                        if (sound[0] != '\0')
                        {
                            EmitSoundToAllAny(sound);
                        }
                    }
                    return;
                }
            }
        }
        
        if (g_Cvar_VoteSounds.BoolValue)
        {
            char sound[PLATFORM_MAX_PATH];
            g_Cvar_VoteCloseSound.GetString(sound, sizeof(sound));
            if (sound[0] != '\0')
            {
                EmitSoundToAllAny(sound);
            }
        }
        
        StartCooldown();
        g_bVoteCompleted = true;
    }
    
    g_bVoteActive = false;
    g_bVoteCompleted = true;
    g_bEndVoteTriggered = true;
}

// ////////////////////////
// //                    //
// //    Limitations     //
// //                    //
// ////////////////////////

// Limitations

bool GamemodeAvailable(const char[] gamemode)
{
    int index = FindGameModeIndex(gamemode);
    if (index == -1) return false;

    GameModeConfig config;
    ArrayList list = GetGameModesList();
    list.GetArray(index, config);
    
    if (config.enabled == 0) return false;
    
    if (config.adminonly == 1) return false;
    
    int players = GetRealClientCount();
    if (config.minplayers > 0 && players < config.minplayers) return false;
    if (config.maxplayers > 0 && players > config.maxplayers) return false;
    
    return true;
}

bool GamemodeAvailableAdminVote(const char[] gamemode)
{
    int index = FindGameModeIndex(gamemode);
    if (index == -1) return false;

    GameModeConfig config;
    ArrayList list = GetGameModesList();
    list.GetArray(index, config);
    
    if (config.enabled == 0) return false;
    
    int players = GetRealClientCount();
    if (config.minplayers > 0 && players < config.minplayers) return false;
    if (config.maxplayers > 0 && players > config.maxplayers) return false;
    
    return true;
}

// //////////////////////////////////////////////
// //                                          //
// //    Extend Map for Normal/Admin Votes     //
// //                                          //
// //////////////////////////////////////////////

// Extend Map for Normal/Admin Votes

void ExtendMapTime()
{
    WriteToLogFile("[MultiMode Core] Stabilized Voting (Map Extension)");
    
    int extendMinutes = g_Cvar_ExtendSteps.IntValue; 
    int roundStep = g_Cvar_ExtendRoundStep.IntValue;
    int fragStep = g_Cvar_ExtendFragStep.IntValue;
    
    bool bExtendedRounds = false, bExtendedFrags = false;
    PerformExtension(float(extendMinutes), roundStep, fragStep, bExtendedRounds, bExtendedFrags);
    
    char hudMsg[128];
    Format(hudMsg, sizeof(hudMsg), "%t", "Map Extended", extendMinutes);
    
    SetHudTextParamsEx(-1.00, -0.75, 10.0, {0, 255, 0, 255}, {0, 0, 0, 0}, 2, 0.0, 0.1, 0.1);
    for (int i = 1; i <= MaxClients; i++) {
        if (IsClientInGame(i) && !IsFakeClient(i)) {
            ShowSyncHudText(i, g_hHudSync, hudMsg);
        }
    }
    
    char buffer[256];
    Format(buffer, sizeof(buffer), "%t", "Map Extended Time", extendMinutes);
    
    CPrintToChatAll(buffer);
    
    g_bEndVoteTriggered = false;
    
    if (g_Cvar_EndVoteEnabled.BoolValue) 
    {
        delete g_hEndVoteTimer;
        g_hEndVoteTimer = CreateTimer(1.0, Timer_CheckEndVote, _, TIMER_REPEAT);
    }

    g_bMapExtended = true;
}

void PerformExtension(float timeStep, int roundStep, int fragStep, bool &bExtendedRounds = false, bool &bExtendedFrags = false)
{
    g_bInternalChange = true;
    
    ConVar timelimit = FindConVar("mp_timelimit");
    if (timelimit != null && timelimit.FloatValue > 0.0) {
        timelimit.FloatValue += timeStep;
    }
    
    ConVar maxrounds = FindConVar("mp_maxrounds");
    if (maxrounds != null && maxrounds.IntValue > 0) {
        maxrounds.IntValue += roundStep;
        bExtendedRounds = true;
    }
    
    ConVar winlimit = FindConVar("mp_winlimit");
    if (winlimit != null && winlimit.IntValue > 0) {
        winlimit.IntValue += roundStep;
        bExtendedRounds = true;
    }
    
    ConVar fraglimit = FindConVar("mp_fraglimit");
    if (fraglimit != null && fraglimit.IntValue > 0) {
        fraglimit.IntValue += fragStep;
        bExtendedFrags = true;
    }
    
    g_bInternalChange = false;
}

bool CanExtendMap()
{
    ConVar timelimit = FindConVar("mp_timelimit");
    ConVar maxrounds = FindConVar("mp_maxrounds");
    ConVar winlimit = FindConVar("mp_winlimit");
    ConVar fraglimit = FindConVar("mp_fraglimit");
    
    return (timelimit != null && timelimit.FloatValue > 0.0) || (maxrounds != null && maxrounds.IntValue > 0) || (winlimit != null && winlimit.IntValue > 0) || (fraglimit != null && fraglimit.IntValue > 0);
}

// //////////////////////////////////////////////
// //                                          //
// //    Extend Map for Force Extend Admin     //
// //                                          //
// //////////////////////////////////////////////

// Extend Map for Force Extend Admin

void ExtendMapTimeEx(int client, float minutes)
{
    g_bInternalChange = true;
    
    float timeStep = minutes;
    int roundStep = g_Cvar_ExtendRoundStep.IntValue;
    int fragStep = g_Cvar_ExtendFragStep.IntValue;
    
    bool bExtendedRounds = false, bExtendedFrags = false;
    PerformExtension(timeStep, roundStep, fragStep, bExtendedRounds, bExtendedFrags);
    
    char hudMsg[128];
    Format(hudMsg, sizeof(hudMsg), "%t", "Admin Map Extended", minutes);
    
    SetHudTextParamsEx(-1.00, -0.75, 10.0, {0, 255, 0, 255}, {0, 0, 0, 0}, 2, 0.0, 0.1, 0.1);
    for (int i = 1; i <= MaxClients; i++) {
        if (IsClientInGame(i) && !IsFakeClient(i)) {
            ShowSyncHudText(i, g_hHudSync, hudMsg);
        }
    }
    
    char buffer[256];
    Format(buffer, sizeof(buffer), "%t", "Admin Map Extended Time", minutes);
    
    if (bExtendedRounds) {
        char temp[64];
        Format(temp, sizeof(temp), "%t", "Map Extended Rounds", roundStep);
        StrCat(buffer, sizeof(buffer), temp);
    }
    if (bExtendedFrags) {
        char temp[64];
        Format(temp, sizeof(temp), "%t", "Map Extended Frags", fragStep);
        StrCat(buffer, sizeof(buffer), temp);
    }
    
    CPrintToChatAll(buffer);
    char clientName[MAX_NAME_LENGTH];
    GetClientName(client, clientName, sizeof(clientName));
    WriteToLogFile("\"%s\" extended the map by %.1f minutes, %d rounds and %d frags.", clientName, minutes, g_Cvar_ExtendRoundStep.IntValue, g_Cvar_ExtendFragStep.IntValue);
    
    g_bInternalChange = false;
}

void NotifyDiscordExtend()
{
    if (g_Cvar_Discord.BoolValue)
    {
        char webhook[256];
        g_Cvar_DiscordWebhook.GetString(webhook, sizeof(webhook));

        if (!StrEqual(webhook, ""))
        {
            DiscordWebHook hook = new DiscordWebHook(webhook);
            MessageEmbed embed = new MessageEmbed();
            
            embed.SetTitle("Time Extension");
            char buffer[128];
            int extend = g_Cvar_ExtendSteps.IntValue;
            Format(buffer, sizeof(buffer), "Map time has been extended by %d minutes.", extend);
            embed.AddField("Extension:", buffer, false);
            embed.SetColor("#FFE000");
            
            char footer[128];
            FindConVar("hostname").GetString(footer, sizeof(footer));
            embed.SetFooter(footer);
            
            hook.SlackMode = true;
            hook.Embed(embed);
            hook.Send();
            delete hook;
        }
    }
}

public void ExecuteVoteResult()
{
    g_eCurrentVoteTiming = g_eEndVoteTiming;
	
    g_bEndVoteTriggered = false;
    g_bVoteActive = false;
    g_bVoteCompleted = true;
    
    if (g_hEndVoteTimer != INVALID_HANDLE) 
    {
        KillTimer(g_hEndVoteTimer);
        g_hEndVoteTimer = INVALID_HANDLE;
    }
    
    switch(g_eVoteTiming)
    {		
        case TIMING_NEXTMAP:
        {
            strcopy(g_sNextMap, sizeof(g_sNextMap), g_sVoteMap);
            strcopy(g_sNextGameMode, sizeof(g_sNextGameMode), g_sVoteGameMode);
            SetNextMap(g_sNextMap);
            CPrintToChatAll("%t", "Timing NextMap Notify", g_sNextMap);
            WriteToLogFile("[MultiMode Core] Next map set (vote): %s", g_sNextMap);
        }
        
        case TIMING_NEXTROUND:
        {
            change_map_round = true;
            strcopy(g_sNextMap, sizeof(g_sNextMap), g_sVoteMap);
            strcopy(g_sNextGameMode, sizeof(g_sNextGameMode), g_sVoteGameMode);
            SetNextMap(g_sNextMap);
            CPrintToChatAll("%t", "Timing NextRound Notify", g_sNextMap);
            WriteToLogFile("[MultiMode Core] Next round map set (vote): %s", g_sNextMap);
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
            WriteToLogFile("[MultiMode Core] Map instantly set to (vote): %s", g_sNextMap);
        }
    }
    
    if(g_Cvar_Discord.BoolValue && g_Cvar_DiscordVoteResult && !StrEqual(g_sVoteGameMode, ""))
    {
        char webhook[256];
        g_Cvar_DiscordWebhook.GetString(webhook, sizeof(webhook));
        
        if(!StrEqual(webhook, ""))
        {
            DiscordWebHook hook = new DiscordWebHook(webhook);
            
            MessageEmbed embed = new MessageEmbed();
            
            embed.SetTitle("Gamemodes voting successful.");
            embed.AddField("Selected gamemode:", g_sVoteGameMode, true);
            embed.AddField("Selected map:", g_sVoteMap, true);
            embed.SetColor("#00FF3C");
            
            char thumbUrl[256];
            Format(thumbUrl, sizeof(thumbUrl), "https://image.gametracker.com/images/maps/160x120/tf2/%s.jpg", g_sVoteMap);
            embed.SetThumb(thumbUrl);
            
            char footer[128];
            FindConVar("hostname").GetString(footer, sizeof(footer));
            embed.SetFooter(footer);
            
            hook.SlackMode = true;
            hook.Embed(embed);
            hook.Send();
            delete hook;
        }
    }
    
    strcopy(g_sNextGameMode, sizeof(g_sNextGameMode), g_sVoteGameMode);
    strcopy(g_sNextMap, sizeof(g_sNextMap), g_sVoteMap);
	
	ExecuteVoteCommands(g_sVoteGameMode, g_sVoteMap);
	
    g_bRtvDisabled = true;
    
}

void StartMapVote(int client, const char[] sGameMode)
{
    if (g_bVoteActive || !g_Cvar_Enabled.BoolValue)
    {
        CPrintToChat(client, "%t", "Vote Already Active");
        return;
    }
	
    if (g_hRtvTimers[1] != INVALID_HANDLE)
    {
        KillTimer(g_hRtvTimers[1]);
        g_hRtvTimers[1] = INVALID_HANDLE;
    }
    g_bRtvCooldown = false;
	
	g_eCurrentVoteTiming = g_eEndVoteTiming;

    if (GetVoteMethod() == 3)
    {
        WriteToLogFile("[MultiMode Core] Starting Global Map Voting (Method 3)");
        g_iVoteInitiator = client;

        ArrayList voteMaps = new ArrayList(ByteCountToCells(PLATFORM_MAX_PATH));
        StringMap uniqueMaps = new StringMap();

        ArrayList gameModes = GetGameModesList();
        for (int i = 0; i < gameModes.Length; i++)
        {
            GameModeConfig config;
            gameModes.GetArray(i, config);

            bool groupAvailable;
            if (g_bCurrentVoteAdmin) {
                groupAvailable = GamemodeAvailableAdminVote(config.name);
            } else {
                groupAvailable = GamemodeAvailable(config.name);
            }

            if (!groupAvailable) {
                continue;
            }

            for (int j = 0; j < config.maps.Length; j++)
            {
                char map[PLATFORM_MAX_PATH];
                config.maps.GetString(j, map, sizeof(map));
                if (!uniqueMaps.ContainsKey(map))
                {
                    voteMaps.PushString(map);
                    uniqueMaps.SetValue(map, true);
                }
            }
        }

        StringMapSnapshot snapshot = g_NominatedMaps.Snapshot();
        for (int i = 0; i < snapshot.Length; i++)
        {
            char group[64];
            snapshot.GetKey(i, group, sizeof(group));

            int groupIndex = FindGameModeIndex(group);
            if (groupIndex == -1) continue;

            GameModeConfig config;
            gameModes.GetArray(groupIndex, config);

            bool groupAvailable;
            if (g_bCurrentVoteAdmin) {
                groupAvailable = GamemodeAvailableAdminVote(group);
            } else {
                groupAvailable = GamemodeAvailable(group);
            }

            if (!groupAvailable) continue;

            ArrayList mapsNominated;
            g_NominatedMaps.GetValue(group, mapsNominated);
            for (int j = 0; j < mapsNominated.Length; j++)
            {
                char map[PLATFORM_MAX_PATH];
                mapsNominated.GetString(j, map, sizeof(map));
                if (!uniqueMaps.ContainsKey(map))
                {
                    voteMaps.PushString(map);
                    uniqueMaps.SetValue(map, true);
                }
            }
        }
        delete snapshot;
        delete uniqueMaps;

        bool bUseRandom = g_bCurrentVoteAdmin ? g_Cvar_VoteAdminRandom.BoolValue : g_Cvar_VoteRandom.BoolValue;

        if (bUseRandom) 
		{
             voteMaps.Sort(Sort_Random, Sort_String);
        }
        
        int maxItems = 6;
        bool canExtend = (g_Cvar_ExtendEveryTime.BoolValue || !g_bMapExtended) && CanExtendMap() && g_Cvar_ExtendVote.BoolValue;
        if (g_Cvar_Extend.BoolValue && canExtend && g_Cvar_ExtendVote.BoolValue)
        {
            maxItems = 6;
        }

        if (voteMaps.Length > maxItems)
        {
            voteMaps.Resize(maxItems);
        }

        Menu menu = new Menu(MapVoteHandler);
        menu.SetTitle("%t", "Start Map Vote Title");

        if (g_Cvar_Extend.BoolValue && canExtend && g_Cvar_ExtendVote.BoolValue)
        {
            char extendText[128];
            int extendMinutes = g_Cvar_ExtendSteps.IntValue;
            Format(extendText, sizeof(extendText), "%t", "Extend Map Normal Vote", extendMinutes);
            menu.AddItem("extend", extendText);
        }

        char map[PLATFORM_MAX_PATH], display[256];
        for (int i = 0; i < voteMaps.Length; i++)
        {
            voteMaps.GetString(i, map, sizeof(map));
            GetMapDisplayNameEx("", map, display, sizeof(display));
            menu.AddItem(map, display);
        }

        delete voteMaps;

        if (g_Cvar_VoteSounds.BoolValue)
        {
            char sound[PLATFORM_MAX_PATH];
            g_Cvar_VoteOpenSound.GetString(sound, sizeof(sound));
            if (sound[0] != '\0') EmitSoundToAllAny(sound);
        }

        menu.ExitButton = false;
        menu.DisplayVoteToAll(g_Cvar_VoteTime.IntValue);
        g_bVoteActive = true;
        g_sSelectedGameMode = "";
        return;
    }

    WriteToLogFile("[MultiMode Core] Starting map voting for: %s", sGameMode);

    int index = FindGameModeIndex(sGameMode);
    if (index == -1)
    {
        WriteToLogFile("Game mode not found: %s", sGameMode);
        return;
    }

    GameModeConfig config;
    ArrayList list = GetGameModesList();
    list.GetArray(index, config);

    strcopy(g_sCurrentGameMode, sizeof(g_sCurrentGameMode), config.name);
    strcopy(g_sSelectedGameMode, sizeof(g_sSelectedGameMode), sGameMode);

    if (config.maps == null || config.maps.Length == 0)
    {
        CPrintToChat(client, "%t", "Non Maps Items");
        return;
    }

    bool bUseRandom = g_bCurrentVoteAdmin ? g_Cvar_VoteAdminRandom.BoolValue : g_Cvar_VoteRandom.BoolValue;

    ArrayList voteMaps = new ArrayList(ByteCountToCells(PLATFORM_MAX_PATH));
    ArrayList mapsNominated;

    int mapExclude = g_bCurrentVoteAdmin ? 
        g_Cvar_VoteAdminMapExclude.IntValue : 
        g_Cvar_VoteMapExclude.IntValue;

    if (g_NominatedMaps.GetValue(sGameMode, mapsNominated) && mapsNominated.Length > 0)
    {
        for (int i = 0; i < mapsNominated.Length; i++)
        {
            char map[PLATFORM_MAX_PATH];
            mapsNominated.GetString(i, map, sizeof(map));
            
            if (mapExclude > 0) 
            {
                ArrayList playedMaps;
                if (g_PlayedMaps.GetValue(sGameMode, playedMaps) && 
                    playedMaps.FindString(map) != -1)
                {
                    continue;
                }
            }
	    }
		
        ArrayList nominateList = view_as<ArrayList>(CloneHandle(mapsNominated));
        if (bUseRandom)
        {
            nominateList.Sort(Sort_Random, Sort_String);
        }

        int maxNominated = (nominateList.Length > config.maps_invote) ? config.maps_invote : nominateList.Length;
        for (int i = 0; i < maxNominated; i++)
        {
            char map[PLATFORM_MAX_PATH];
            nominateList.GetString(i, map, sizeof(map));
            if (IsMapValid(map) && voteMaps.FindString(map) == -1)
            {
                voteMaps.PushString(map);
            }
        }
        delete nominateList;
    }

    int needed = config.maps_invote - voteMaps.Length;
    if (needed > 0)
    {
        ArrayList availableMaps = new ArrayList(ByteCountToCells(PLATFORM_MAX_PATH));
        for (int i = 0; i < config.maps.Length; i++)
        {
            char map[PLATFORM_MAX_PATH];
            config.maps.GetString(i, map, sizeof(map));
            if (IsMapValid(map) && voteMaps.FindString(map) == -1)
            {
                if (mapExclude > 0)
                {
                    ArrayList playedMaps;
                    if (g_PlayedMaps.GetValue(sGameMode, playedMaps) && playedMaps.FindString(map) != -1)
                        continue;
                }
                availableMaps.PushString(map);
            }
        }

        if (bUseRandom)
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

    Menu voteMenu = new Menu(MapVoteHandler);
    voteMenu.SetTitle("%t", "Show Map Group Title", config.name);

    if (g_Cvar_VoteSounds.BoolValue)
    {
        char sound[PLATFORM_MAX_PATH];
        g_Cvar_VoteOpenSound.GetString(sound, sizeof(sound));
        if (sound[0] != '\0') EmitSoundToAllAny(sound);
    }

    char map[PLATFORM_MAX_PATH], display[256];
    for (int i = 0; i < voteMaps.Length; i++)
    {
        voteMaps.GetString(i, map, sizeof(map));
        GetMapDisplayNameEx(config.name, map, display, sizeof(display));

        if (mapsNominated != null && mapsNominated.FindString(map) != -1)
        {
            Format(display, sizeof(display), "%s (Nomeado)", display);
        }
        voteMenu.AddItem(map, display);
    }

    delete voteMaps;

    if (voteMenu.ItemCount > 0)
    {
        voteMenu.ExitButton = false;
        voteMenu.DisplayVoteToAll(g_Cvar_VoteTime.IntValue);
        g_bVoteActive = true;
    }
    else
    {
        delete voteMenu;
        CPrintToChat(client, "%t", "Non Maps Items");
    }
}

public Action Timer_StartMapVote(Handle timer)
{
    StartMapVote(g_iVoteInitiator, g_sVoteGameMode);
    return Plugin_Stop;
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

void StartCooldown()
{
    if (!g_Cvar_CooldownEnabled.BoolValue) 
    {
        CreateTimer(2.0, Timer_StartMapVote, _, TIMER_FLAG_NO_MAPCHANGE);
        return;
    }

    g_bCooldownActive = true;
    g_iCooldownEndTime = GetTime() + g_Cvar_CooldownTime.IntValue;
    
    if (g_hCooldownTimer != null) {
        KillTimer(g_hCooldownTimer);
    }
    g_hCooldownTimer = CreateTimer(float(g_Cvar_CooldownTime.IntValue), Timer_EndCooldown);
    
    CPrintToChatAll("%t", "Map Voting Cooldown", g_Cvar_CooldownTime.IntValue);
    
    CreateTimer(1.0, Timer_UpdateCooldownHUD, _, TIMER_REPEAT);
}

int FindGameModeIndex(const char[] name)
{
    ArrayList list = GetGameModesList();
    for (int i = 0; i < list.Length; i++)
    {
        GameModeConfig config;
        list.GetArray(i, config);
        if (StrEqual(config.name, name))
            return i;
    }
    return -1;
}

KeyValues GetMapKv(const char[] gamemode, const char[] mapname)
{
    KeyValues kv = new KeyValues("");
    
    if (g_kvGameModes.JumpToKey(gamemode) && g_kvGameModes.JumpToKey("maps"))
    {
        if (g_kvGameModes.JumpToKey(mapname))
        {
            kv.Import(g_kvGameModes);
            g_kvGameModes.GoBack();
        }
        else
        {
            bool foundWildcard = false;
            if (g_kvGameModes.GotoFirstSubKey(false))
            {
                do
                {
                    char mapKey[PLATFORM_MAX_PATH];
                    g_kvGameModes.GetSectionName(mapKey, sizeof(mapKey));
                    
                    if (IsWildcardEntry(mapKey) && StrContains(mapname, mapKey) == 0)
                    {
                        kv.Import(g_kvGameModes);
                        foundWildcard = true;
                        break;
                    }
                } while (g_kvGameModes.GotoNextKey(false));
                g_kvGameModes.GoBack();
            }
            if (!foundWildcard && StrContains(mapname, "workshop/") == 0)
            {
                char mapParts[2][128];
                if (ExplodeString(mapname, "/", mapParts, 2, 128) == 2)
                {
                    char uid[32];
                    strcopy(uid, sizeof(uid), mapParts[1]);
                    
                    if (g_kvGameModes.GotoFirstSubKey(false))
                    {
                        do
                        {
                            char section[128];
                            g_kvGameModes.GetSectionName(section, sizeof(section));
                            
                            if (StrContains(section, uid) != -1)
                            {
                                kv.Import(g_kvGameModes);
                                break;
                            }
                        } while (g_kvGameModes.GotoNextKey(false));
                        g_kvGameModes.GoBack();
                    }
                }
            }
        }
        g_kvGameModes.GoBack();
    }
    
    g_kvGameModes.Rewind();
    return kv;
}

stock void GetMapDisplayNameEx(const char[] gamemode, const char[] map, char[] display, int displayLen)
{
    if (gamemode[0] != '\0') 
    {
        KeyValues kv = GetMapKv(gamemode, map);
        if (kv != null)
        {
            char customDisplay[256];
            kv.GetString("display", customDisplay, sizeof(customDisplay), "");
            delete kv;
            if (customDisplay[0] != '\0') 
            {
                strcopy(display, displayLen, customDisplay);
                return;
            }
        }
    }

    ArrayList gameModes = GetGameModesList();
    for (int i = 0; i < gameModes.Length; i++)
    {
        GameModeConfig config;
        gameModes.GetArray(i, config);
        if (config.maps.FindString(map) != -1)
        {
            KeyValues kv = GetMapKv(config.name, map);
            if (kv != null)
            {
                char customDisplay[256];
                kv.GetString("display", customDisplay, sizeof(customDisplay), "");
                delete kv;
                if (customDisplay[0] != '\0') 
                {
                    strcopy(display, displayLen, customDisplay);
                    return;
                }
            }
        }
    }

    char baseMap[PLATFORM_MAX_PATH];
    strcopy(baseMap, sizeof(baseMap), map);
    if (GetMapDisplayName(baseMap, display, displayLen)) 
    {
        return;
    }
    
    strcopy(display, displayLen, baseMap);
}

public int MapVoteHandler(Menu menu, MenuAction action, int param1, int param2) 
{
    if (action == MenuAction_End) 
    {
        delete menu;
        g_bVoteActive = false;
        g_bVoteCompleted = true;
    }
    else if (action == MenuAction_VoteEnd) 
    {
        char map[PLATFORM_MAX_PATH], display[256];
        menu.GetItem(param1, map, sizeof(map), _, display);
        char sound[PLATFORM_MAX_PATH];
        g_Cvar_VoteCloseSound.GetString(sound, sizeof(sound));
        if (sound[0] != '\0') EmitSoundToAllAny(sound);
    
        if(param2 == 0) 
        {
            CPrintToChatAll("%t", "No Votes Recorded");
            StartRtvCooldown();
        }
        else
        {
            strcopy(g_sVoteMap, sizeof(g_sVoteMap), map);
            TrimString(g_sVoteMap);
        
            if(!IsMapValid(g_sVoteMap)) 
            {
                WriteToLogFile("Invalid map selected: %s", g_sVoteMap);
                strcopy(g_sVoteMap, sizeof(g_sVoteMap), "");
                StartRtvCooldown();
                return 0;
            }
        
            ExecuteVoteResult();
        }
    }
    return 0;
}

public void OnGamemodeConfigLoaded()
{
    WriteToLogFile("[MultiMode Core] Gamemodes loaded successfully!");
}

public Action Command_ReloadGamemodes(int client, int args)
{
    LoadGameModesConfig();
	
    if (g_Cvar_CountdownEnabled.BoolValue)
    {
        LoadCountdownConfig();
    }
	
    CReplyToCommand(client, "%t", "Reload Gamemodes Successful");
    return Plugin_Handled;
}

public void OnPluginEnd()
{
    CloseHandle(g_hCookieVoteType);
    CloseHandle(g_hHudSync);
	
    if (g_Countdowns != null)
    {
        StringMapSnapshot snapshot = g_Countdowns.Snapshot();
        for (int i = 0; i < snapshot.Length; i++)
        {
            char key[64];
            snapshot.GetKey(i, key, sizeof(key));
            StringMap typeMap;
            if (g_Countdowns.GetValue(key, typeMap))
            {
                StringMapSnapshot typeSnapshot = typeMap.Snapshot();
                for (int j = 0; j < typeSnapshot.Length; j++)
                {
                    char valueKey[32];
                    typeSnapshot.GetKey(j, valueKey, sizeof(valueKey));
                    ArrayList messages;
                    if (typeMap.GetValue(valueKey, messages))
                    {
                        delete messages;
                    }
                }
                delete typeSnapshot;
                delete typeMap;
            }
        }
        delete snapshot;
        delete g_Countdowns;
    }
    
    if (g_LastCountdownValues != null)
    {
        delete g_LastCountdownValues;
    }
}