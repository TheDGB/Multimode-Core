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
#include <nativevotes>

#define PLUGIN_VERSION "3.0.2"

// Gesture Defines
#define GESTURE_NOMINATED " (!)" // For nominated global gesture groups/maps
#define GESTURE_CURRENT " (*)"   // For Current global gesture group/map
#define GESTURE_VOTED " (#)"     // For Winning group/map global gesture from a previous vote
#define GESTURE_SELECTEDNOMINATED " (Nominated)" // For selected nomination global gesture.
#define GESTURE_EXCLUDED " (Excluded)" // For global exclusion gesture.

// Convar Section
ConVar g_Cvar_CooldownEnabled;
ConVar g_Cvar_CooldownTime;
ConVar g_Cvar_CountdownEnabled;
ConVar g_Cvar_CountdownFilename;
ConVar g_Cvar_Enabled;
ConVar g_Cvar_EndVoteDebug;
ConVar g_Cvar_EndVoteEnabled;
ConVar g_Cvar_EndVoteFrags;
ConVar g_Cvar_EndVoteMin;
ConVar g_Cvar_EndVoteOnRoundEnd;
ConVar g_Cvar_EndVoteRounds;
ConVar g_Cvar_EndVoteType;
ConVar g_Cvar_Extend;
ConVar g_Cvar_ExtendEveryTime;
ConVar g_Cvar_ExtendFragStep;
ConVar g_Cvar_ExtendRoundStep;
ConVar g_Cvar_ExtendSteps;
ConVar g_Cvar_ExtendVote;
ConVar g_Cvar_ExtendVoteAdmin;
ConVar g_Cvar_Logs;
ConVar g_Cvar_MapCycleFile;
ConVar g_Cvar_Method;
ConVar g_Cvar_NativeVotes;
ConVar g_Cvar_NominateEnabled;
ConVar g_Cvar_NominateGroupExclude;
ConVar g_Cvar_NominateMapExclude;
ConVar g_Cvar_NominateOneChance;
ConVar g_Cvar_NominateSelectedGroupExclude;
ConVar g_Cvar_NominateSelectedMapExclude;
ConVar g_Cvar_NominateSorted;
ConVar g_Cvar_NominateOneChanceAbsolute;
ConVar g_Cvar_UnnominateEnabled;
ConVar g_Cvar_RandomCycleEnabled;
ConVar g_Cvar_RandomCycleType;
ConVar g_Cvar_Runoff;
ConVar g_Cvar_RunoffInVoteLimit;
ConVar g_Cvar_RunoffThreshold;
ConVar g_Cvar_RunoffVoteFailed;
ConVar g_Cvar_RunoffVoteLimit;
ConVar g_Cvar_RunoffVoteOpenSound;
ConVar g_Cvar_RunoffVoteCloseSound;
ConVar g_Cvar_RtvDelay;
ConVar g_Cvar_RtvEnabled;
ConVar g_Cvar_RtvFirstDelay;
ConVar g_Cvar_RtvMinPlayers;
ConVar g_Cvar_RtvRatio;
ConVar g_Cvar_RtvType;
ConVar g_Cvar_VoteAdminGroupExclude;
ConVar g_Cvar_VoteAdminMapExclude;
ConVar g_Cvar_VoteAdminSorted;
ConVar g_Cvar_VoteCloseSound;
ConVar g_Cvar_VoteGroupExclude;
ConVar g_Cvar_VoteMapExclude;
ConVar g_Cvar_VoteOpenSound;
ConVar g_Cvar_VoteSorted;
ConVar g_Cvar_VoteSounds;
ConVar g_Cvar_VoteTime;
ConVar g_hCvarTimeLimit;

// Bool
bool g_bChangeMapNextRound;
bool g_bCooldownActive = false;
bool g_bCurrentVoteAdmin;
bool g_bEndVotePending = false;
bool g_bEndVoteTriggered = false;
bool g_bGameEndTriggered = false;
bool g_bHasNominated[MAXPLAYERS+1];
bool g_bInternalChange = false;
bool g_bIsRunoffCooldown = false;
bool g_bIsRunoffVote = false;
bool g_bMapExtended = false;
bool g_bRtvCooldown = false;
bool g_bRtvDisabled = false;
bool g_bRtvInitialDelay = true;
bool g_bRtvVoted[MAXPLAYERS+1];
bool g_bVoteActive;
bool g_bVoteCompleted = false;

// Array Section
ArrayList g_NominatedGamemodes;
ArrayList g_PlayedGamemodes;
ArrayList g_RunoffItems;
ArrayList g_PlayerNominations[MAXPLAYERS + 1];

// StringMap Section
StringMap g_Countdowns;
StringMap g_CountdownSounds;
StringMap g_LastCountdownValues;
StringMap g_NominatedMaps;
StringMap g_PlayedMaps;

// TimingMode Section
TimingMode g_eCurrentVoteTiming;
TimingMode g_eEndVoteTiming;
TimingMode g_eVoteTiming;

// Vote Type
VoteType g_eCurrentNativeVoteType;
VoteType g_ePendingVoteType;

// Char Section
char g_NominateGamemode[MAXPLAYERS+1][64];
char g_NominateSubgroup[MAXPLAYERS+1][64];
char g_sClientPendingGameMode[MAXPLAYERS+1][64];
char g_sClientPendingMap[MAXPLAYERS+1][PLATFORM_MAX_PATH];
char g_sClientPendingSubGroup[MAXPLAYERS+1][64];
char g_sCurrentGameMode[128];
char g_sCurrentWinner[PLATFORM_MAX_PATH];
char g_sNextGameMode[128];
char g_sNextMap[PLATFORM_MAX_PATH];
char g_sNextSubGroup[64];
char g_sPendingCommand[256];
char g_sPendingVoteGamemode[64];
char g_sPendingVoteSubGroup[64];
char g_sSelectedGameMode[64] = "";
char g_sVoteGameMode[64];
char g_sVoteMap[PLATFORM_MAX_PATH];
char g_sVoteSubGroup[64];

// Int Section
int g_iCooldownEndTime = 0;
int g_iMapStartTime;
int g_iRtvVotes = 0;
int g_iRunoffVotesThisMap = 0;
int g_iVoteInitiator = -1;
int g_iPendingVoteInitiator;

// Handle Section
Handle g_hCookieVoteType;
Handle g_hCooldownTimer = INVALID_HANDLE;
Handle g_hEndVoteTimer = INVALID_HANDLE;
Handle g_hHudSync;
Handle g_hRtvCooldownTimer = INVALID_HANDLE;
Handle g_hRtvFirstDelayTimer = INVALID_HANDLE;
Handle g_hRtvTimers[2];
Handle g_OnGamemodeChangedForward;
Handle g_OnGamemodeChangedVoteForward;
Handle g_OnVoteEndForward;
Handle g_OnVoteStartExForward;
Handle g_OnVoteStartForward;

// Float Section
float g_fRtvTimerDuration[2];
float g_fRtvTimerStart[2];

public void OnPluginStart() 
{
    LoadTranslations("multimode_voter.phrases");
    
    // Reg Console Commands
    RegConsoleCmd("sm_rtv", Command_RTV, "Rock The Vote");
	RegConsoleCmd("sm_rockthevote", Command_RTV, "Rock The Vote (ALT)");
	
    RegConsoleCmd("sm_nominate", Command_Nominate, "Nominate a gamemode and map");
	RegConsoleCmd("sm_nom", Command_Nominate, "Nominate a gamemode and map (ALT)");
	
    RegConsoleCmd("sm_unnominate", Command_Unnominate, "Remove one or all of your nominations.");
	RegConsoleCmd("sm_unnom", Command_Unnominate, "Remove one or all of your nominations. (ALT)");
    RegConsoleCmd("sm_quickunnominate", Command_QuickUnnominate, "Quickly remove all your nominations.");
    RegConsoleCmd("sm_quickunnom", Command_QuickUnnominate, "Quickly remove all your nominations. (ALT)");
	
	RegConsoleCmd("multimode_version", Command_MultimodeVersion, "Displays the current Multimode Core version");
    
    // Reg Admin Commands
    RegAdminCmd("multimode_reload", Command_ReloadGamemodes, ADMFLAG_CONFIG, "Reloads gamemodes configuration");
    RegAdminCmd("multimode_setnextmap", Command_SetNextMap, ADMFLAG_CHANGEMAP, "Sets the next map. Usage: <map> <timing> [group] [subgroup]");
    RegAdminCmd("sm_setnextmap", Command_SetNextMap, ADMFLAG_CHANGEMAP, "Sets the next map. Usage: <map> <timing> [group] [subgroup]");
    RegAdminCmd("sm_forcemode", Command_ForceMode, ADMFLAG_CHANGEMAP, "Force game mode and map");
    RegAdminCmd("sm_testvote", Command_VoteMenu, ADMFLAG_VOTE, "Start Voting Mode/Map Testing Voting");
    RegAdminCmd("sm_votecancel", Command_CancelVote, ADMFLAG_VOTE, "Cancel the current MultiMode vote");
    RegAdminCmd("sm_mmcancelvote", Command_CancelVote, ADMFLAG_VOTE, "Cancel the current MultiMode vote");
    
    // Convars
    g_Cvar_Enabled = CreateConVar("multimode_enabled", "1", "Enable the multimode voting system");
	
	g_Cvar_MapCycleFile = CreateConVar("multimode_mapcycle", "mmc_mapcycle.txt", "Name of the map cycle file to use (search in addons/sourcemod/configs).");
        
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
	
	g_Cvar_NativeVotes = CreateConVar("multimode_nativevotes", "0", "Enable/disable NativeVotes support for votes (1 = Enabled, 0 = Disabled)", _, true, 0.0, true, 1.0);
    
    g_Cvar_VoteTime = CreateConVar("multimode_vote_time", "20", "Vote duration in seconds");
    g_Cvar_VoteSorted = CreateConVar("multimode_vote_sorted", "1", "Sorting mode for vote items: 0= Alphabetical, 1= Random, 2= Map Cycle Order", _, true, 0.0, true, 2.0);
    g_Cvar_VoteAdminSorted = CreateConVar("multimode_voteadmin_sorted", "1", "Sorting mode for admin vote items: 0= Alphabetical, 1= Random, 2= Map Cycle Order", _, true, 0.0, true, 2.0);
    g_Cvar_VoteGroupExclude = CreateConVar("multimode_vote_groupexclude", "0", "Number of recently played gamemodes to exclude from normal votes (0= Disabled)");
    g_Cvar_VoteMapExclude = CreateConVar("multimode_vote_mapexclude", "2", "Number of recently played maps to exclude from normal votes (0= Disabled)");
    g_Cvar_VoteAdminGroupExclude = CreateConVar("multimode_voteadmin_groupexclude", "0", "Number of recently played gamemodes to exclude from admin votes (0= Disabled)");
    g_Cvar_VoteAdminMapExclude = CreateConVar("multimode_voteadmin_mapexclude", "2", "Number of recently played maps to exclude from admin votes (0= Disabled)");
	
    g_Cvar_Runoff = CreateConVar("multimode_runoff", "1", "Enable runoff system, voting for ties or if no option reaches the threshold.", _, true, 0.0, true, 1.0);
    g_Cvar_RunoffVoteOpenSound = CreateConVar("multimode_runoff_voteopensound", "votemap/vtst.wav", "Sound played when starting a runoff vote.");
    g_Cvar_RunoffVoteCloseSound = CreateConVar("multimode_runoff_voteclosesound", "votemap/vtend.wav", "Sound played when a runoff vote ends.");
    g_Cvar_RunoffThreshold = CreateConVar("multimode_runoff_threshold", "0.6", "Minimum percentage of votes an option needs to win directly (0.0 to disable threshold check.).", _, true, 0.0, true, 1.0);
    g_Cvar_RunoffVoteFailed = CreateConVar("multimode_runoff_votefailed", "0", "What to do if a runoff vote also fails: 1= Do Nothing, 0= Pick the first option from the runoff.", _, true, 0.0, true, 1.0);
    g_Cvar_RunoffInVoteLimit = CreateConVar("multimode_runoff_invotelimit", "3", "Maximum number of items to include in a runoff vote.", _, true, 2.0);
    g_Cvar_RunoffVoteLimit = CreateConVar("multimode_runoff_votelimit", "3", "Maximum number of runoff votes allowed per map to prevent infinite loops.", _, true, 1.0);
    
    g_Cvar_EndVoteEnabled = CreateConVar("multimode_endvote_enabled", "1", "Enables automatic end vote when the remaining map time reaches the configured limit.");
    g_Cvar_EndVoteMin = CreateConVar("multimode_endvote_min", "6", "Specifies minutes remaining to start automatic voting. (mp_timelimit, multimode_endvote_min 0 = Disabled)");	
	g_Cvar_EndVoteRounds = CreateConVar("multimode_endvote_rounds", "3", "Specifies when to start voting based on the remaining rounds. (mp_maxrounds, mp_winlimit, multimode_endvote_rounds 0 = Disabled)", _, true, 0.0);
    g_Cvar_EndVoteFrags = CreateConVar("multimode_endvote_frags", "30", "Specifies when to start voting based on remaining frags. (mp_fraglimit, multimode_endvote_frags 0 = Disabled)", _, true, 0.0);
    g_Cvar_EndVoteType = CreateConVar("multimode_endvotetype", "1", "Voting Type for End Vote: 1 - Next Map, 2 - Next Round, 3 - Instant", _, true, 1.0, true, 3.0);
	g_Cvar_EndVoteOnRoundEnd = CreateConVar("multimode_endvote_onroundend", "0", "Wait for the end of the round to start voting for the end vote.", _, true, 0.0, true, 1.0);
    g_Cvar_EndVoteDebug = CreateConVar("multimode_endvotedebug", "0", "Enables/disables detailed End Vote logs", 0, true, 0.0, true, 1.0);
	
    g_Cvar_NominateEnabled = CreateConVar("multimode_nominate", "1", "Enables or disables the nominate system", _, true, 0.0, true, 1.0);
    g_Cvar_UnnominateEnabled = CreateConVar("multimode_unnominate", "1", "Enables or disables the unnominate system.", _, true, 0.0, true, 1.0);
    g_Cvar_NominateOneChance = CreateConVar("multimode_nominate_onechance", "1", "Allows users to nominate only once per map", _, true, 0.0, true, 1.0);
    g_Cvar_NominateOneChanceAbsolute = CreateConVar("multimode_nominate_onechance_absolute", "0", "If 1, players do not get back their only nomination chance after removing a nomination.", _, true, 0.0, true, 1.0);
    g_Cvar_NominateSelectedGroupExclude = CreateConVar("multimode_nominate_selectedgroupexclude", "0", "Removes the nominated gamemode from the nominate menu", _, true, 0.0, true, 1.0);
	g_Cvar_NominateSelectedMapExclude = CreateConVar("multimode_nominate_selectedmapexclude", "1", "Removes the nominated map from the nominate menu", _, true, 0.0, true, 1.0);
    g_Cvar_NominateGroupExclude = CreateConVar("multimode_nominate_groupexclude", "0", "Number of recently played gamemodes to exclude from the menu (0= Disabled)");
    g_Cvar_NominateMapExclude = CreateConVar("multimode_nominate_mapexclude", "2", "Number of recently played maps to exclude from the menu (0= Disabled)");
    g_Cvar_NominateSorted = CreateConVar("multimode_nominate_sorted", "2", "Sorting mode for maps: 0= Alphabetical, 1= Random, 2= Map Cycle Order", _, true, 0.0, true, 2.0);
    
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

    g_PlayedGamemodes = new ArrayList(ByteCountToCells(128));
    g_PlayedMaps = new StringMap();
    g_RunoffItems = new ArrayList(ByteCountToCells(PLATFORM_MAX_PATH));
    
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
    HookConVarChange(g_Cvar_VoteOpenSound, OnSoundConVarChanged);
    HookConVarChange(g_Cvar_VoteCloseSound, OnSoundConVarChanged);
    HookConVarChange(g_Cvar_RunoffVoteOpenSound, OnSoundConVarChanged);
    HookConVarChange(g_Cvar_RunoffVoteCloseSound, OnSoundConVarChanged);
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
	
    for (int i = 0; i <= MAXPLAYERS; i++)
    {
        g_PlayerNominations[i] = new ArrayList(sizeof(NominationInfo));
    }
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    CreateNative("MultiMode_StartVote", NativeMMC_StartVote);
    CreateNative("MultiMode_StopVote", NativeMMC_StopVote);
    CreateNative("MultiMode_CanStopVote", NativeMMC_CanStopVote);
    CreateNative("MultiMode_IsVoteActive", NativeMMC_IsVoteActive);
    CreateNative("MultiMode_GetCurrentGameMode", NativeMMC_GetCurrentGameMode);
    CreateNative("MultiMode_GetNextMap", NativeMMC_GetNextMap);
    CreateNative("MultiMode_GetCurrentMap", NativeMMC_GetCurrentMap);
    CreateNative("MultiMode_Nominate", NativeMMC_Nominate);
    CreateNative("MultiMode_GetNextGameMode", NativeMMC_GetNextGameMode);
    CreateNative("MultiMode_IsRandomCycleEnabled", NativeMMC_IsRandomCycleEnabled);
	CreateNative("MultiMode_GetRandomMap", NativeMMC_GetRandomMap);
	CreateNative("MultiMode_IsGroupNominated", NativeMMC_IsGroupNominated);
	CreateNative("MultiMode_IsMapNominated", NativeMMC_IsMapNominated);
    
    RegPluginLibrary("multimode_core");
    return APLRes_Success;
}

public void OnLibraryAdded(const char[] name)
{
    if (StrEqual(name, "nativevotes"))
    {
        // NativeVotes support available
    }
}

public void OnLibraryRemoved(const char[] name)
{
    if (StrEqual(name, "nativevotes"))
    {
        // NativeVotes support no longer available
    }
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
        WriteToLogFile("Falha ao carregar %s", mapcycleFile);
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
    bool subgroupFound = false;
    char foundSubGroup[64] = "";
    
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
            
            if (strlen(config.config) > 0)
            {
                WriteToLogFile("[MultiMode Core] Executing group config: %s", config.config);
                ServerCommand("exec %s", config.config);
            }
            
            bool subgroupProcessed = false;
            if (strlen(g_sNextSubGroup) > 0)
            {
                int subgroupIndex = FindSubGroupIndex(g_sNextGameMode, g_sNextSubGroup);
                if (subgroupIndex != -1)
                {
                    SubGroupConfig subConfig;
                    config.subGroups.GetArray(subgroupIndex, subConfig);
                    
                    if (strlen(subConfig.config) > 0)
                    {
                        WriteToLogFile("[MultiMode Core] Executing subgroup config: %s", subConfig.config);
                        ServerCommand("exec %s", subConfig.config);
                    }
                    
                    if (strlen(subConfig.command) > 0)
                    {
                        WriteToLogFile("[MultiMode Core] Executing subgroup command: %s", subConfig.command);
                        ServerCommand("%s", subConfig.command);
                        subgroupProcessed = true;
                    }
                    
                    KeyValues kv = GetSubGroupMapKv(config.name, g_sNextSubGroup, CurrentMap);
                    if (kv != null)
                    {
                        char mapConfig[256];
                        kv.GetString("config", mapConfig, sizeof(mapConfig), "");
                        if (strlen(mapConfig) > 0)
                        {
                            WriteToLogFile("[MultiMode Core] Executing subgroup map config: %s", mapConfig);
                            ServerCommand("exec %s", mapConfig);
                        }
                        
                        char mapCommand[256];
                        kv.GetString("command", mapCommand, sizeof(mapCommand), "");
                        
                        if (strlen(mapCommand) > 0)
                        {
                            WriteToLogFile("[MultiMode Core] Executing subgroup map command: %s", mapCommand);
                            ServerCommand("%s", mapCommand);
                        }
                        delete kv;
                    }
                }
            }
            
            if (!subgroupProcessed && strlen(config.command) > 0)
            {
                WriteToLogFile("[MultiMode Core] Executing group command: %s", config.command);
                ServerCommand("%s", config.command);
            }
            
            KeyValues kv = GetMapKv(config.name, CurrentMap);
            if (kv != null)
            {
                char mapConfig[256];
                kv.GetString("config", mapConfig, sizeof(mapConfig), "");
                if (strlen(mapConfig) > 0)
                {
                    WriteToLogFile("[MultiMode Core] Executing map config: %s", mapConfig);
                    ServerCommand("exec %s", mapConfig);
                }

                char mapCommand[256];
                kv.GetString("command", mapCommand, sizeof(mapCommand), "");
                
                if (strlen(mapCommand) > 0)
                {
                    WriteToLogFile("[MultiMode Core] Executing map command: %s", mapCommand);
                    ServerCommand("%s", mapCommand);
                }
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

                        if (IsWildcardEntry(mapKey) && StrContains(CurrentMap, mapKey) == 0)
                        {
                            char wildcardConfig[256];
                            g_kvGameModes.GetString("config", wildcardConfig, sizeof(wildcardConfig), "");
                            if (strlen(wildcardConfig) > 0)
                            {
                                WriteToLogFile("[MultiMode Core] Executing wildcard config (%s): %s", mapKey, wildcardConfig);
                                ServerCommand("exec %s", wildcardConfig);
                            }
                            
                            char wildcardCommand[256];
                            g_kvGameModes.GetString("command", wildcardCommand, sizeof(wildcardCommand), "");
                            
                            if (strlen(wildcardCommand) > 0)
                            {
                                WriteToLogFile("[MultiMode Core] Executing wildcard command (%s): %s", mapKey, wildcardCommand);
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
                    
                    WriteToLogFile("[MultiMode Core] Group found with subgroup: %s (SubGroup: %s)", config.name, subConfig.name);

                    if (strlen(config.config) > 0)
                    {
                        WriteToLogFile("[MultiMode Core] Executing group config: %s", config.config);
                        ServerCommand("exec %s", config.config);
                    }
                    if (strlen(config.command) > 0)
                    {
                        WriteToLogFile("[MultiMode Core] Executing group command: %s", config.command);
                        ServerCommand("%s", config.command);
                    }
                    
                    if (strlen(subConfig.config) > 0)
                    {
                        WriteToLogFile("[MultiMode Core] Executing subgroup config: %s", subConfig.config);
                        ServerCommand("exec %s", subConfig.config);
                    }

                    if (strlen(subConfig.command) > 0)
                    {
                        WriteToLogFile("[MultiMode Core] Executing subgroup command: %s", subConfig.command);
                        ServerCommand("%s", subConfig.command);
                    }

                    KeyValues kv = GetSubGroupMapKv(config.name, subConfig.name, CurrentMap);
                    if (kv != null)
                    {
                        char mapConfig[256];
                        kv.GetString("config", mapConfig, sizeof(mapConfig), "");
                        if (strlen(mapConfig) > 0)
                        {
                            WriteToLogFile("[MultiMode Core] Executing subgroup map config: %s", mapConfig);
                            ServerCommand("exec %s", mapConfig);
                        }
                        
                        char mapCommand[256];
                        kv.GetString("command", mapCommand, sizeof(mapCommand), "");
                        
                        if (strlen(mapCommand) > 0)
                        {
                            WriteToLogFile("[MultiMode Core] Executing subgroup map command: %s", mapCommand);
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
                WriteToLogFile("[MultiMode Core] Group found: %s", config.name);

                if (strlen(config.config) > 0)
                {
                    WriteToLogFile("[MultiMode Core] Executing group config: %s", config.config);
                    ServerCommand("exec %s", config.config);
                }

                if (strlen(config.command) > 0)
                {
                    WriteToLogFile("[MultiMode Core] Executing group command: %s", config.command);
                    ServerCommand("%s", config.command);
                }

                KeyValues kv = GetMapKv(config.name, CurrentMap);
                if (kv != null)
                {
                    char mapConfig[256];
                    kv.GetString("config", mapConfig, sizeof(mapConfig), "");
                    if (strlen(mapConfig) > 0)
                    {
                        WriteToLogFile("[MultiMode Core] Executing map config: %s", mapConfig);
                        ServerCommand("exec %s", mapConfig);
                    }
                    
                    char mapCommand[256];
                    kv.GetString("command", mapCommand, sizeof(mapCommand), "");
                    
                    if (strlen(mapCommand) > 0)
                    {
                        WriteToLogFile("[MultiMode Core] Executing map command: %s", mapCommand);
                        ServerCommand("%s", mapCommand);
                    }
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

                            if (IsWildcardEntry(mapKey) && StrContains(CurrentMap, mapKey) == 0)
                            {
                                char wildcardConfig[256];
                                g_kvGameModes.GetString("config", wildcardConfig, sizeof(wildcardConfig), "");
                                if (strlen(wildcardConfig) > 0)
                                {
                                    WriteToLogFile("[MultiMode Core] Executing wildcard config (%s): %s", mapKey, wildcardConfig);
                                    ServerCommand("exec %s", wildcardConfig);
                                }
                                
                                char wildcardCommand[256];
                                g_kvGameModes.GetString("command", wildcardCommand, sizeof(wildcardCommand), "");
                                
                                if (strlen(wildcardCommand) > 0)
                                {
                                    WriteToLogFile("[MultiMode Core] Executing wildcard command (%s): %s", mapKey, wildcardCommand);
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
    g_iRunoffVotesThisMap = 0;

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

        g_Cvar_RunoffVoteOpenSound.GetString(sound, sizeof(sound));
        if (sound[0] != '\0')
        {
            PrecacheSoundAny(sound);
            FormatEx(downloadPath, sizeof(downloadPath), "sound/%s", sound);
            if (FileExists(downloadPath, true))
                AddFileToDownloadsTable(downloadPath);
            else
                WriteToLogFile("Runoff opening sound file not found: %s", downloadPath);
        }

        g_Cvar_RunoffVoteCloseSound.GetString(sound, sizeof(sound));
        if (sound[0] != '\0')
        {
            PrecacheSoundAny(sound);
            FormatEx(downloadPath, sizeof(downloadPath), "sound/%s", sound);
            if (FileExists(downloadPath, true))
                AddFileToDownloadsTable(downloadPath);
            else
                WriteToLogFile("Runoff closing sound file not found: %s", downloadPath);
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
	
    for (int i = 1; i <= MaxClients; i++)
    {
        g_bRtvVoted[i] = false;
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
	
	g_sClientPendingSubGroup[client][0] = '\0';
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
    char mapcycleFile[PLATFORM_MAX_PATH];
    
    g_Cvar_MapCycleFile.GetString(mapcycleFile, sizeof(mapcycleFile));
    BuildPath(Path_SM, configPath, sizeof(configPath), "configs/%s", mapcycleFile);
    
    if (!g_kvGameModes.ImportFromFile(configPath))
    {
        WriteToLogFile("Failed to load %s", mapcycleFile);
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

            char time_buffer[8];
            g_kvGameModes.GetString("mintime", time_buffer, sizeof(time_buffer), "-1");
            config.mintime = StringToInt(time_buffer);
            g_kvGameModes.GetString("maxtime", time_buffer, sizeof(time_buffer), "-1");
            config.maxtime = StringToInt(time_buffer);
            
            g_kvGameModes.GetString("command", config.command, sizeof(config.command), "");
            g_kvGameModes.GetString("pre-command", config.pre_command, sizeof(config.pre_command), "");
            g_kvGameModes.GetString("vote-command", config.vote_command, sizeof(config.vote_command), "");
            g_kvGameModes.GetString("config", config.config, sizeof(config.config), "");
            
            if (strlen(config.command) == 0 && g_kvGameModes.JumpToKey("serverconfig"))
            {
                g_kvGameModes.GetString("command", config.command, sizeof(config.command), "");
                g_kvGameModes.GoBack();
            }
            
            config.maps = new ArrayList(ByteCountToCells(PLATFORM_MAX_PATH));
            if (g_kvGameModes.JumpToKey("maps"))
            {
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
            
            config.subGroups = new ArrayList(sizeof(SubGroupConfig));
            if (g_kvGameModes.JumpToKey("subgroup"))
            {
                config.subgroups_invote = g_kvGameModes.GetNum("subgroups_invote", 6);
                
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
                        subConfig.minplayers = g_kvGameModes.GetNum("minplayers", 0);
                        subConfig.maxplayers = g_kvGameModes.GetNum("maxplayers", 0);
                        subConfig.maps_invote = g_kvGameModes.GetNum("maps_invote", 6);

                        g_kvGameModes.GetString("mintime", time_buffer, sizeof(time_buffer), "-1");
                        subConfig.mintime = StringToInt(time_buffer);
                        g_kvGameModes.GetString("maxtime", time_buffer, sizeof(time_buffer), "-1");
                        subConfig.maxtime = StringToInt(time_buffer);
                        
                        g_kvGameModes.GetString("command", subConfig.command, sizeof(subConfig.command), "");
                        g_kvGameModes.GetString("pre-command", subConfig.pre_command, sizeof(subConfig.pre_command), "");
                        g_kvGameModes.GetString("vote-command", subConfig.vote_command, sizeof(subConfig.vote_command), "");
                        g_kvGameModes.GetString("config", subConfig.config, sizeof(subConfig.config), "");
                        
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
                                    
                                    if (IsWildcardEntry(mapKey))
                                    {
                                        ArrayList wildcardMaps = new ArrayList(ByteCountToCells(PLATFORM_MAX_PATH));
                                        ExpandWildcardMaps(mapKey, wildcardMaps);
                                        
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
    
    g_kvGameModes.Rewind();
}

void ProcessVoteLogic(VoteType voteType, int num_votes, int num_clients, ArrayList results, NativeVote vote = null)
{
    #pragma unused num_clients

    // If runoff is disabled, simply handle it.
    if (!g_Cvar_Runoff.BoolValue)
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
                
                if (vote != null && g_Cvar_NativeVotes.BoolValue && LibraryExists("nativevotes"))
                {
                    strcopy(g_sCurrentWinner, sizeof(g_sCurrentWinner), winnerRes.info);
                    NativeVotes_DisplayPass(vote, g_sCurrentWinner);
                }
                
                HandleWinner(winnerRes.info, voteType);
            }
            else
            {
                CPrintToChatAll("%t", "No Votes Recorded");
                StartRtvCooldown();
                g_bVoteActive = false;
                g_bVoteCompleted = false;
                NativeMMC_OnVoteEnd("", "", "", VoteEnd_Failed);
            }
        }
        else
        {
            g_bVoteActive = false;
            g_bVoteCompleted = false;
            NativeMMC_OnVoteEnd("", "", "", VoteEnd_Failed);
        }
        return;
    }

    if (results.Length == 0 || num_votes == 0)
    {
        CPrintToChatAll("%t", "No Votes Recorded");
        StartRtvCooldown();
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
    float threshold = g_Cvar_RunoffThreshold.FloatValue;

    if (winners.Length > 1)
    {
        needsRunoff = true;
        WriteToLogFile("[Runoff] Runoff triggered due to a tie between %d items with %d votes each.", winners.Length, maxVotes);
        g_RunoffItems.Clear();
        for(int i = 0; i < winners.Length; i++)
        {
            char winner[PLATFORM_MAX_PATH];
            winners.GetString(i, winner, sizeof(winner));
            g_RunoffItems.PushString(winner);
        }
    }
    else if (winners.Length == 1 && threshold > 0.0 && num_votes > 0 && (float(maxVotes) / float(num_votes)) < threshold)
    {
        needsRunoff = true;
        WriteToLogFile("[Runoff] Runoff triggered because winner did not meet threshold (%.2f%% < %.2f%%).", (float(maxVotes) / float(num_votes)) * 100.0, threshold * 100.0);
        
        results.SortCustom(SortByVotes);
        
        g_RunoffItems.Clear();
        int limit = g_Cvar_RunoffInVoteLimit.IntValue;
        for (int i = 0; i < results.Length && g_RunoffItems.Length < limit; i++)
        {
            VoteCandidate candidate;
            results.GetArray(i, candidate);
            if (candidate.votes > 0)
            {
                g_RunoffItems.PushString(candidate.info);
            }
        }
    }
    
    delete winners;

    if (needsRunoff)
    {
        if (g_bIsRunoffVote || g_iRunoffVotesThisMap >= g_Cvar_RunoffVoteLimit.IntValue)
        {
            if (g_bIsRunoffVote) {
                WriteToLogFile("[Runoff] A runoff vote has also failed (tie or threshold not met).");
            } else {
                WriteToLogFile("[Runoff] Runoff vote limit reached (%d).", g_iRunoffVotesThisMap);
            }

            if (g_Cvar_RunoffVoteFailed.BoolValue)
            {
                CPrintToChatAll("%t", "Runoff Vote Failed (Limit)");
                NativeMMC_OnVoteEnd("", "", "", VoteEnd_Failed);
                g_bVoteActive = false;
                g_bIsRunoffVote = false;
                return;
            }
            else
            {
                char winner[PLATFORM_MAX_PATH];
                g_RunoffItems.GetString(0, winner, sizeof(winner));
                WriteToLogFile("[Runoff] Force-picking first item '%s' due to failed runoff/limit.", winner);
                
                if (vote != null && g_Cvar_NativeVotes.BoolValue && LibraryExists("nativevotes"))
                {
                    strcopy(g_sCurrentWinner, sizeof(g_sCurrentWinner), winner);
                    NativeVotes_DisplayPass(vote, g_sCurrentWinner);
                }
                
                HandleWinner(winner, voteType);
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
            
            if (vote != null && g_Cvar_NativeVotes.BoolValue && LibraryExists("nativevotes"))
            {
                strcopy(g_sCurrentWinner, sizeof(g_sCurrentWinner), winnerRes.info);
                NativeVotes_DisplayPass(vote, g_sCurrentWinner);
            }
            
            HandleWinner(winnerRes.info, voteType);
        }
        else
        {
            CPrintToChatAll("%t", "No Votes Recorded");
            StartRtvCooldown();
            g_bVoteActive = false;
            g_bVoteCompleted = false;
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
    g_eCurrentVoteTiming = g_eVoteTiming;

    if (StrEqual(winner, "Extend Map"))
    {
        NativeMMC_OnVoteEnd("Extend Map", "", "", VoteEnd_Extend);
        ExtendMapTime();
        g_bVoteActive = false;
        g_bVoteCompleted = false;
        StartRtvCooldown();
    }
    else
    {
        switch(voteType)
        {
            case VOTE_TYPE_GROUP:
            {
                strcopy(g_sVoteGameMode, sizeof(g_sVoteGameMode), winner);
                
                if (GetVoteMethod() == 2)
                {
                    int index = FindGameModeIndex(winner);
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
                    int index = FindGameModeForMap(g_sVoteMap);
                    if (index != -1)
                    {
                        GameModeConfig config;
                        GetGameModesList().GetArray(index, config);
                        strcopy(g_sVoteGameMode, sizeof(g_sVoteGameMode), config.name);
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
    
    if (g_Cvar_VoteSounds.BoolValue)
    {
        char sound[PLATFORM_MAX_PATH];
        if (g_bIsRunoffVote)
        {
            g_Cvar_RunoffVoteCloseSound.GetString(sound, sizeof(sound));
        }
        else
        {
            g_Cvar_VoteCloseSound.GetString(sound, sizeof(sound));
        }
        if (sound[0] != '\0') EmitSoundToAllAny(sound);
    }
    
    if(!StrEqual(winner, "Extend Map"))
    {
        g_bVoteActive = false;
        g_bVoteCompleted = true;
        g_bEndVoteTriggered = true;
    }
    g_bIsRunoffVote = false;
}

// Run Off

void StartPendingRunoffVote()
{
    // The type of vote to start is stored in g_ePendingVoteType
    // The items for the vote are in g_RunoffItems
    switch (g_ePendingVoteType)
    {
        case VOTE_TYPE_GROUP:
        {
            StartGameModeVote(g_iPendingVoteInitiator, g_bCurrentVoteAdmin, g_RunoffItems);
        }
        case VOTE_TYPE_SUBGROUP:
        {
            StartSubGroupVote(g_iPendingVoteInitiator, g_sPendingVoteGamemode, g_RunoffItems);
        }
        case VOTE_TYPE_MAP:
        {
            StartMapVote(g_iPendingVoteInitiator, g_sPendingVoteGamemode, g_RunoffItems);
        }
        case VOTE_TYPE_SUBGROUP_MAP:
        {
            StartSubGroupMapVote(g_iPendingVoteInitiator, g_sPendingVoteGamemode, g_sPendingVoteSubGroup, g_RunoffItems);
        }
    }
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
									
                                    if (StrContains(message, "{TIME}") != -1 || 
                                        StrContains(message, "{ROUNDS}") != -1 || 
                                        StrContains(message, "{FRAGS}") != -1)
                                    {
                                        continue;
                                    }
                                    
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
							
                            if (!g_CountdownSounds.ContainsKey(soundPath))
                            {
                                PrecacheSoundAny(soundPath);
                                char downloadPath[PLATFORM_MAX_PATH];
                                FormatEx(downloadPath, sizeof(downloadPath), "sound/%s", soundPath);
                                if (FileExists(downloadPath, true))
                                {
                                    AddFileToDownloadsTable(downloadPath);
                                }
                                else
                                {
                                    WriteToLogFile("Countdown sound file not found: %s", downloadPath);
                                }
                                g_CountdownSounds.SetValue(soundPath, true);
                            }

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
        
        if (!config.enabled || config.adminonly || !IsCurrentlyAvailableByTime(config.name)) continue;
        
        validGameModes.PushArray(config);
    }
    
    if(validGameModes.Length == 0) return;

    int iRandomMode = GetRandomInt(0, validGameModes.Length - 1);
    GameModeConfig config;
    validGameModes.GetArray(iRandomMode, config);

    ArrayList validMaps = new ArrayList(ByteCountToCells(PLATFORM_MAX_PATH));
    for (int i = 0; i < config.maps.Length; i++)
    {
        char sMap[PLATFORM_MAX_PATH];
        config.maps.GetString(i, sMap, sizeof(sMap));
        if (IsCurrentlyAvailableByTime(config.name, "", sMap))
        {
            validMaps.PushString(sMap);
        }
    }

    if(validMaps.Length == 0) 
    {
        delete validGameModes;
        delete validMaps;
        return;
    }

    int iRandomMap = GetRandomInt(0, validMaps.Length - 1);
    char sMap[PLATFORM_MAX_PATH];
    validMaps.GetString(iRandomMap, sMap, sizeof(sMap));
    delete validMaps;

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
    int playerCount = 0;
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i) && !IsFakeClient(i))
        {
            playerCount++;
        }
    }

    if (playerCount < 1)
    {
        if (g_Cvar_EndVoteDebug.BoolValue)
            WriteToLogFile("[End Vote] No players on the server, end vote check ignored.");
        return Plugin_Continue;
    }

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
        CPrintToChatAll("%t", "End Vote Waiting For Next Round");
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
            if (g_bIsRunoffCooldown)
            {
                PrintCenterText(i, "%t", "Run Off Cooldown Hud", remaining);
            }
            else
            {
                PrintCenterText(i, "%t", "Cooldown Hud", remaining);
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
	
    else if (StrEqual(text, "nominate", false)|| StrEqual(text, "nom", false))
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
        else if (convar == g_Cvar_RunoffVoteOpenSound)
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
                    WriteToLogFile("Runoff opening sound file not found: %s", downloadPath);
                }
            }
        }
        else if (convar == g_Cvar_RunoffVoteCloseSound)
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
                    WriteToLogFile("Runoff closing sound file not found: %s", downloadPath);
                }
            }
        }
    }
}

public void OnTimelimitChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
    if(g_bInternalChange) return;
    
    g_iMapStartTime = GetTime();
	
    if (g_Cvar_EndVoteMin.IntValue == 0)
    {
        return;
    }
    
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
    if (g_Cvar_EndVoteMin.IntValue == 0)
    {
        return;
    }

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

// //////////////////////////
// //                      //
// //     Native Votes     //
// //                      //
// //////////////////////////

NativeVote CreateNativeVote(NativeVotes_Handler handler, bool isMapVote = false)
{
    if (!g_Cvar_NativeVotes.BoolValue || !LibraryExists("nativevotes"))
        return null;

    NativeVotesType voteType = NativeVotesType_Custom_Mult;
    NativeVote vote = new NativeVote(handler, voteType);

    if (vote == null)
        return null;

    char buffer[256];
    if (isMapVote)
    {
        Format(buffer, sizeof(buffer), "%T", "Show Map Group Title", LANG_SERVER, g_sSelectedGameMode);
    }
    else
    {
        Format(buffer, sizeof(buffer), "%T", "Normal Vote Gamemode Group Title", LANG_SERVER);
    }
    vote.SetTitle(buffer);

    return vote;
}

public int NativeVoteHandler(NativeVote vote, MenuAction action, int param1, int param2)
{
    switch (action)
    {
        case MenuAction_VoteStart:
        {
            if (g_Cvar_VoteSounds.BoolValue)
            {
                char sound[PLATFORM_MAX_PATH];
                if (g_bIsRunoffVote)
                {
                    g_Cvar_RunoffVoteOpenSound.GetString(sound, sizeof(sound));
                }
                else
                {
                    g_Cvar_VoteOpenSound.GetString(sound, sizeof(sound));
                }
                if (sound[0] != '\0')
                {
                    EmitSoundToAllAny(sound);
                }
            }
        }

        case MenuAction_End:
        {
            vote.Close();
            g_bVoteActive = false;
        }

        case MenuAction_VoteCancel:
        {
            if (param1 == VoteCancel_NoVotes)
            {
                vote.DisplayFail(NativeVotesFail_NotEnoughVotes);
            }
            else
            {
                vote.DisplayFail(NativeVotesFail_Generic);
            }

            if (g_Cvar_VoteSounds.BoolValue)
            {
                char sound[PLATFORM_MAX_PATH];
                if (g_bIsRunoffVote)
                {
                    g_Cvar_RunoffVoteCloseSound.GetString(sound, sizeof(sound));
                }
                else
                {
                    g_Cvar_VoteCloseSound.GetString(sound, sizeof(sound));
                }
                if (sound[0] != '\0')
                {
                    EmitSoundToAllAny(sound);
                }
            }
            g_bIsRunoffVote = false;
        }
    }

    return 0;
}

public void NativeVoteResultHandler(NativeVote vote, int num_votes, int num_clients, const int[] client_indexes, const int[] client_votes, int num_items, const int[] item_indexes, const int[] item_votes)
{
    ArrayList results = new ArrayList(sizeof(VoteCandidate));
    for (int i = 0; i < num_items; i++)
    {
        VoteCandidate res;
        res.votes = item_votes[i];
        vote.GetItem(item_indexes[i], res.info, sizeof(res.info));
        results.PushArray(res);
    }
    
    ProcessVoteLogic(g_eCurrentNativeVoteType, num_votes, num_clients, results, vote); 
    delete results;
}

public int NativeSubGroupVoteHandler(NativeVote vote, MenuAction action, int param1, int param2)
{
    switch (action)
    {
        case MenuAction_VoteStart:
        {
            if (g_Cvar_VoteSounds.BoolValue)
            {
                char sound[PLATFORM_MAX_PATH];
                if (g_bIsRunoffVote)
                {
                    g_Cvar_RunoffVoteOpenSound.GetString(sound, sizeof(sound));
                }
                else
                {
                    g_Cvar_VoteOpenSound.GetString(sound, sizeof(sound));
                }
                if (sound[0] != '\0')
                {
                    EmitSoundToAllAny(sound);
                }
            }
        }

        case MenuAction_End:
        {
            vote.Close();
            g_bVoteActive = false;
        }

        case MenuAction_VoteCancel:
        {
            if (param1 == VoteCancel_NoVotes)
            {
                vote.DisplayFail(NativeVotesFail_NotEnoughVotes);
            }
            else
            {
                vote.DisplayFail(NativeVotesFail_Generic);
            }
            g_bIsRunoffVote = false;
        }
        
        case MenuAction_VoteEnd:
        {
            if (param1 == NATIVEVOTES_VOTE_YES)
            {
                NativeVotes_DisplayPass(vote, g_sCurrentWinner);
            }
        }
    }

    return 0;
}

public int NativeMapVoteHandler(NativeVote vote, MenuAction action, int param1, int param2)
{
    switch (action)
    {
        case MenuAction_VoteStart:
        {
            if (g_Cvar_VoteSounds.BoolValue)
            {
                char sound[PLATFORM_MAX_PATH];
                if (g_bIsRunoffVote)
                {
                    g_Cvar_RunoffVoteOpenSound.GetString(sound, sizeof(sound));
                }
                else
                {
                    g_Cvar_VoteOpenSound.GetString(sound, sizeof(sound));
                }
                if (sound[0] != '\0')
                {
                    EmitSoundToAllAny(sound);
                }
            }
        }

        case MenuAction_End:
        {
            vote.Close();
            g_bVoteActive = false;
        }

        case MenuAction_VoteCancel:
        {
            if (param1 == VoteCancel_NoVotes)
            {
                vote.DisplayFail(NativeVotesFail_NotEnoughVotes);
            }
            else
            {
                vote.DisplayFail(NativeVotesFail_Generic);
            }

            if (g_Cvar_VoteSounds.BoolValue)
            {
                char sound[PLATFORM_MAX_PATH];
                if (g_bIsRunoffVote)
                {
                    g_Cvar_RunoffVoteCloseSound.GetString(sound, sizeof(sound));
                }
                else
                {
                    g_Cvar_VoteCloseSound.GetString(sound, sizeof(sound));
                }
                if (sound[0] != '\0')
                {
                    EmitSoundToAllAny(sound);
                }
            }
            g_bIsRunoffVote = false;
        }
		
        case MenuAction_VoteEnd:
        {
            if (param1 == NATIVEVOTES_VOTE_YES)
            {
                NativeVotes_DisplayPass(vote, g_sCurrentWinner);
            }
        }
    }

    return 0;
}

public int NativeSubGroupMapVoteHandler(NativeVote vote, MenuAction action, int param1, int param2)
{
    switch (action)
    {
        case MenuAction_VoteStart:
        {
            if (g_Cvar_VoteSounds.BoolValue)
            {
                char sound[PLATFORM_MAX_PATH];
                if (g_bIsRunoffVote)
                {
                    g_Cvar_RunoffVoteOpenSound.GetString(sound, sizeof(sound));
                }
                else
                {
                    g_Cvar_VoteOpenSound.GetString(sound, sizeof(sound));
                }
                if (sound[0] != '\0')
                {
                    EmitSoundToAllAny(sound);
                }
            }
        }

        case MenuAction_End:
        {
            vote.Close();
            g_bVoteActive = false;
        }

        case MenuAction_VoteCancel:
        {
            if (param1 == VoteCancel_NoVotes)
            {
                vote.DisplayFail(NativeVotesFail_NotEnoughVotes);
            }
            else
            {
                vote.DisplayFail(NativeVotesFail_Generic);
            }
            g_bIsRunoffVote = false;
        }
		
        case MenuAction_VoteEnd:
        {
            if (param1 == NATIVEVOTES_VOTE_YES)
            {
                NativeVotes_DisplayPass(vote, g_sCurrentWinner);
            }
        }
    }

    return 0;
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

    int index = FindGameModeIndex(g_sCurrentGameMode);
    if (index == -1)
        return;

    GameModeConfig config;
    ArrayList list = GetGameModesList();
    list.GetArray(index, config);

    bool commandExecuted = false;
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
            commandExecuted = true;
        }
        delete kv;
    }
    
    if (!commandExecuted && strlen(config.pre_command) > 0)
    {
        ServerCommand("%s", config.pre_command);
        WriteToLogFile("[MultiMode Core] Executed group pre-command: %s", config.pre_command);
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
    
    bool commandExecuted = false;
    
    KeyValues kv = GetMapKv(gamemode, map);
    if (kv != null)
    {
        char mapVoteCommand[256];
        kv.GetString("vote-command", mapVoteCommand, sizeof(mapVoteCommand), "");
        
        if (strlen(mapVoteCommand) > 0)
        {
            ServerCommand("%s", mapVoteCommand);
            WriteToLogFile("[MultiMode Core] Executed map vote-command: %s", mapVoteCommand);
            commandExecuted = true;
        }
        delete kv;
    }
    
    if (!commandExecuted && strlen(config.vote_command) > 0)
    {
        ServerCommand("%s", config.vote_command);
        WriteToLogFile("[MultiMode Core] Executed group vote-command: %s", config.vote_command);
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
                if (g_bIsRunoffVote)
                {
                    g_Cvar_RunoffVoteCloseSound.GetString(sound, sizeof(sound));
                }
                else
                {
                    g_Cvar_VoteCloseSound.GetString(sound, sizeof(sound));
                }
                if (sound[0] != '\0')
                {
                    EmitSoundToAllAny(sound);
                }
            }
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
        
		bool isVoted = (g_bVoteCompleted && StrEqual(config.name, g_sVoteGameMode));
        char voteIndicator[6];
        strcopy(voteIndicator, sizeof(voteIndicator), isVoted ? GESTURE_VOTED : "");
        
        if (config.adminonly == 1) 
            Format(display, sizeof(display), "[ADMIN] %s%s", config.name, voteIndicator);
        else 
            Format(display, sizeof(display), "%s%s", config.name, voteIndicator);
        
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
        
        if (HasSubGroups(gamemode))
        {
            StartSubGroupVote(client, gamemode);
        }
        else
        {
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

public int ForceTimingMenuHandler(Menu menu, MenuAction action, int client, int param2)
{
    if (action == MenuAction_Select)
    {
        ExecuteModeChange(
            g_sClientPendingGameMode[client],
            g_sClientPendingMap[client],
            view_as<int>(view_as<TimingMode>(param2)),
            g_sClientPendingSubGroup[client]
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

public Action Command_Unnominate(int client, int args)
{
    if (!g_Cvar_UnnominateEnabled.BoolValue)
    {
        CPrintToChat(client, "%t", "Unnominate System Is Disabled");
        return Plugin_Handled;
    }
	
    char buffer[125];
	
    if (g_PlayerNominations[client].Length == 0)
    {
        CPrintToChat(client, "%t", "Unnominate None"); 
        return Plugin_Handled;
    }

    Menu menu = new Menu(UnnominateMenuHandler);
    menu.SetTitle("%t", "Unnominate Menu Title");
	
    FormatEx(buffer, sizeof(buffer), "%t", "Unnominate Clear All");
    menu.AddItem("cleanup", buffer);

    for (int i = 0; i < g_PlayerNominations[client].Length; i++)
    {
        NominationInfo nInfo;
        g_PlayerNominations[client].GetArray(i, nInfo);

        char display[256];
        if (strlen(nInfo.subgroup) > 0)
        {
            Format(display, sizeof(display), "%s/%s - %s", nInfo.group, nInfo.subgroup, nInfo.map);
        }
        else
        {
            Format(display, sizeof(display), "%s - %s", nInfo.group, nInfo.map);
        }
        
        char info[16];
        IntToString(i, info, sizeof(info));
        menu.AddItem(info, display);
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
            RemoveAllClientNominations(client);
        }
        else
        {
            int index = StringToInt(info);
            if (index >= 0 && index < g_PlayerNominations[client].Length)
            {
                RemoveClientNomination(client, index);
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
    if (!g_Cvar_UnnominateEnabled.BoolValue)
    {
        CPrintToChat(client, "%t", "Unnominate System Is Disabled");
        return Plugin_Handled;
    }
	
    if (g_PlayerNominations[client].Length == 0)
    {
        CPrintToChat(client, "%t", "Unnominate None");
        return Plugin_Handled;
    }
    RemoveAllClientNominations(client);
    return Plugin_Handled;
}

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
        if (g_Cvar_NominateOneChance.BoolValue && !g_Cvar_NominateOneChanceAbsolute.BoolValue)
        {
            g_bHasNominated[client] = false;
            if (showMessage)
            {
                CPrintToChat(client, "%t", "Unnominate Can Nominate Again");
            }
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

void ShowNominateGamemodeMenu(int client)
{
    Menu menu = new Menu(NominateGamemodeMenuHandler);
    menu.SetTitle("%t", "Nominate Gamemode Group Menu Title");

    ArrayList originalList = GetGameModesList();
    ArrayList gameModes = new ArrayList(originalList.BlockSize);
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

        if (!CanClientNominate(client, config.name, "", "") || !GamemodeAvailable(config.name))
        {
            continue;
        }

        bool isExcluded = false;
        char display[128];

        bool recentlyPlayedExclude = (g_Cvar_NominateGroupExclude.IntValue > 0 && g_PlayedGamemodes.FindString(config.name) != -1);
        bool selectedGroupExclude = (g_Cvar_NominateSelectedGroupExclude.BoolValue && g_NominatedGamemodes.FindString(config.name) != -1);

        if (recentlyPlayedExclude || selectedGroupExclude)
        {
            isExcluded = true;
        }

        if (isExcluded)
        {
            if (selectedGroupExclude)
            {
                Format(display, sizeof(display), "%s%s", config.name, GESTURE_SELECTEDNOMINATED);
            }
            else
            {
                Format(display, sizeof(display), "%s%s", config.name, GESTURE_EXCLUDED);
            }
            menu.AddItem(config.name, display, ITEMDRAW_DISABLED);
        }
		
        else
        {
            if (g_NominatedGamemodes.FindString(config.name) != -1)
            {
                Format(display, sizeof(display), "%s%s", config.name, GESTURE_NOMINATED);
            }
            else
            {
                strcopy(display, sizeof(display), config.name);
            }
            menu.AddItem(config.name, display);
        }
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
        g_NominateSubgroup[client][0] = '\0';
        
        if (HasSubGroups(gamemode))
        {
            ShowNominateSubGroupMenu(client, gamemode);
        }
        else
        {
            ShowNominateMapMenu(client, gamemode, "");
        }
    }
    else if (action == MenuAction_End)
    {
        delete menu;
    }
    return 0;
}

void ShowNominateSubGroupMenu(int client, const char[] gamemode)
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

    Menu menu = new Menu(NominateSubGroupMenuHandler);
    menu.SetTitle("%t", "Nominate SubGroup Menu Title", gamemode);

    for (int i = 0; i < config.subGroups.Length; i++)
    {
        SubGroupConfig subConfig;
        config.subGroups.GetArray(i, subConfig);

        if (!subConfig.enabled) continue;
        if (!CanClientNominate(client, gamemode, subConfig.name, "")) continue;
        if (subConfig.adminonly == 1 && !CheckCommandAccess(client, "sm_admin", ADMFLAG_GENERIC, true)) continue;
        int players = GetRealClientCount();
        if (subConfig.minplayers > 0 && players < subConfig.minplayers) continue;
        if (subConfig.maxplayers > 0 && players > subConfig.maxplayers) continue;
        if (!IsCurrentlyAvailableByTime(gamemode, subConfig.name)) continue;

        bool isExcluded = false;
        char display[128];
        char fullSubgroupKey[128];
        Format(fullSubgroupKey, sizeof(fullSubgroupKey), "%s/%s", gamemode, subConfig.name);

        bool recentlyPlayedExclude = (g_Cvar_NominateGroupExclude.IntValue > 0 && g_PlayedGamemodes.FindString(fullSubgroupKey) != -1);
        bool selectedGroupExclude = (g_Cvar_NominateSelectedGroupExclude.BoolValue && g_NominatedGamemodes.FindString(fullSubgroupKey) != -1);

        if (recentlyPlayedExclude || selectedGroupExclude)
        {
            isExcluded = true;
        }

        if (isExcluded)
        {
            if (selectedGroupExclude)
            {
                Format(display, sizeof(display), "%s%s", subConfig.name, GESTURE_SELECTEDNOMINATED);
            }
            else
            {
                Format(display, sizeof(display), "%s%s", subConfig.name, GESTURE_EXCLUDED);
            }
            menu.AddItem(subConfig.name, display, ITEMDRAW_DISABLED);
        }
		
        else
        {
            if (g_NominatedGamemodes.FindString(fullSubgroupKey) != -1)
            {
                Format(display, sizeof(display), "%s%s", subConfig.name, GESTURE_NOMINATED);
            }
            else
            {
                strcopy(display, sizeof(display), subConfig.name);
            }
            menu.AddItem(subConfig.name, display);
        }
    }

    if (menu.ItemCount == 0)
    {
        CPrintToChat(client, "%t", "No Available SubGroups");
        delete menu;
        return;
    }

    menu.ExitBackButton = true;
    menu.Display(client, MENU_TIME_FOREVER);
}

public int NominateSubGroupMenuHandler(Menu menu, MenuAction action, int client, int param2)
{
    if (action == MenuAction_Select)
    {
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

    if (strlen(subgroup) > 0)
    {
        int subgroupIndex = FindSubGroupIndex(gamemode, subgroup);
        if (subgroupIndex == -1)
        {
            CPrintToChat(client, "%t", "SubGroup Not Found");
            delete availableMaps;
            return;
        }

        SubGroupConfig subConfig;
        config.subGroups.GetArray(subgroupIndex, subConfig);
        
        for (int i = 0; i < subConfig.maps.Length; i++)
        {
            char map[PLATFORM_MAX_PATH];
            subConfig.maps.GetString(i, map, sizeof(map));
            availableMaps.PushString(map);
        }
    }
    else
    {
        for (int i = 0; i < config.maps.Length; i++)
        {
            char map[PLATFORM_MAX_PATH];
            config.maps.GetString(i, map, sizeof(map));
            availableMaps.PushString(map);
        }
    }

    ArrayList filteredMaps = new ArrayList(ByteCountToCells(PLATFORM_MAX_PATH));
    for (int i = 0; i < availableMaps.Length; i++)
    {
        char map[PLATFORM_MAX_PATH];
        availableMaps.GetString(i, map, sizeof(map));

        if (!IsCurrentlyAvailableByTime(gamemode, subgroup, map))
        {
            continue;
        }

        filteredMaps.PushString(map);
    }
    delete availableMaps;

    int sortMode = g_Cvar_NominateSorted.IntValue;
    if (sortMode == 0)
    {
        SortADTArray(filteredMaps, Sort_Ascending, Sort_String);
    }
    else if (sortMode == 1)
    {
        SortADTArray(filteredMaps, Sort_Random, Sort_String);
    }

    Menu menu = new Menu(NominateMapMenuHandler);
    
    if (strlen(subgroup) > 0)
    {
        menu.SetTitle("%t", "Nominate SubGroup Map Title", config.name, subgroup);
    }
    else
    {
        menu.SetTitle("%t", "Nominate Map Title", config.name);
    }

    char key[128];
    if (strlen(subgroup) > 0)
    {
        Format(key, sizeof(key), "%s/%s", gamemode, subgroup);
    }
    else
    {
        strcopy(key, sizeof(key), gamemode);
    }
    
    ArrayList recentlyPlayedMaps;
    if (g_Cvar_NominateMapExclude.IntValue > 0)
    {
        g_PlayedMaps.GetValue(key, recentlyPlayedMaps);
    }

    ArrayList mapsNominated;
    g_NominatedMaps.GetValue(key, mapsNominated);

    for (int i = 0; i < filteredMaps.Length; i++)
    {
        char map[PLATFORM_MAX_PATH];
        filteredMaps.GetString(i, map, sizeof(map));
        if (!CanClientNominate(client, gamemode, subgroup, map))
        {
            continue;
        }

        bool isExcluded = false;
        char displayName[256];
        GetMapDisplayNameEx(gamemode, map, displayName, sizeof(displayName), subgroup);

        bool recentlyPlayedExclude = (recentlyPlayedMaps != null && recentlyPlayedMaps.FindString(map) != -1);
        bool selectedMapExclude = (g_Cvar_NominateSelectedMapExclude.BoolValue && mapsNominated != null && mapsNominated.FindString(map) != -1);

        if (recentlyPlayedExclude || selectedMapExclude)
        {
            isExcluded = true;
        }

        if (isExcluded)
        {
            if (selectedMapExclude)
            {
                Format(displayName, sizeof(displayName), "%s%s", displayName, GESTURE_SELECTEDNOMINATED);
            }
            else
            {
                Format(displayName, sizeof(displayName), "%s%s", displayName, GESTURE_EXCLUDED);
            }
            menu.AddItem(map, displayName, ITEMDRAW_DISABLED);
        }
		
        else
        {
            if (mapsNominated != null && mapsNominated.FindString(map) != -1)
            {
                Format(displayName, sizeof(displayName), "%s%s", displayName, GESTURE_NOMINATED);
            }
            menu.AddItem(map, displayName);
        }
    }

    delete filteredMaps;

    menu.ExitBackButton = true;
    menu.Display(client, MENU_TIME_FOREVER);
}

public int NominateMapMenuHandler(Menu menu, MenuAction action, int client, int param2)
{
    if (action == MenuAction_Select)
    {
        char map[PLATFORM_MAX_PATH];
        menu.GetItem(param2, map, sizeof(map));
        RegisterNomination(client, g_NominateGamemode[client], g_NominateSubgroup[client], map);
    }
    else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack)
    {
        if (HasSubGroups(g_NominateGamemode[client]))
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
    StartGameModeVote(client, adminVote);
    return 0;
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
    
    int groupIndex = FindGameModeIndex(group);
    if (groupIndex == -1 || !IsMapValid(map))
        return false;

    if (strlen(subgroup) > 0 && FindSubGroupIndex(group, subgroup) == -1)
        return false;
    
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
        strcopy(subgroup, subgroupMaxLen, g_sNextSubGroup);
    }
    else if (g_Cvar_RandomCycleEnabled.BoolValue && StrEqual(g_sNextMap, ""))
    {
        char randomGamemode[128];
        GetRandomGameMode(randomGamemode, sizeof(randomGamemode));
        SplitGamemodeString(randomGamemode, group, sizeof(group), subgroup, sizeof(subgroup));
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
    return g_Cvar_RandomCycleEnabled.BoolValue;
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
        g_bEndVoteTriggered = false;
        g_bVoteCompleted = false;
        
        if (g_Cvar_VoteSounds.BoolValue)
        {
            char sound[PLATFORM_MAX_PATH];
            if (g_bIsRunoffVote)
            {
                g_Cvar_RunoffVoteCloseSound.GetString(sound, sizeof(sound));
            }
            else
            {
                g_Cvar_VoteCloseSound.GetString(sound, sizeof(sound));
            }
            if (sound[0] != '\0')
            {
                EmitSoundToAllAny(sound);
            }
        }
        g_bIsRunoffVote = false;
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

    // Logic variables
    ArrayList gameModes = GetGameModesList();
    if (gameModes.Length == 0) return false;

    int groupIndex = -1;

    if (strlen(groupIn) > 0)
    {
        groupIndex = FindGameModeIndex(groupIn);
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
        int subIndex = FindSubGroupIndex(config.name, subgroupIn);
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
        int iGroupIndex = FindGameModeIndex(sGroup);
        if (iGroupIndex != -1)
        {
            GameModeConfig config;
            gameModes.GetArray(iGroupIndex, config);

            if (strlen(sSubGroup) > 0)
            {
                int iSubGroupIndex = FindSubGroupIndex(sGroup, sSubGroup);
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

public Action Command_ToggleVoteSounds(int client, int args)
{
    bool newValue = !g_Cvar_VoteSounds.BoolValue;
    g_Cvar_VoteSounds.SetBool(newValue);
    
    return Plugin_Handled;
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
            if (g_bIsRunoffVote)
            {
                g_Cvar_RunoffVoteCloseSound.GetString(sound, sizeof(sound));
            }
            else
            {
                g_Cvar_VoteCloseSound.GetString(sound, sizeof(sound));
            }
            if (sound[0] != '\0')
            {
                EmitSoundToAllAny(sound);
            }
        }
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


void ShowGameModeMenu(int client, bool forceMode)
{
    Menu menu = new Menu(forceMode ? ForceGameModeMenuHandler : GameModeMenuHandler);
    menu.SetTitle("%t", "Show Gamemode Group Title");
    
    ArrayList gameModes = GetGameModesList();
    
    char currentGroup[64];
    SplitGamemodeString(g_sCurrentGameMode, currentGroup, sizeof(currentGroup), "", 0);

    for (int i = 0; i < gameModes.Length; i++)
    {
        GameModeConfig config;
        gameModes.GetArray(i, config);
        
        char display[128];
        char prefix[8] = "";

        if (StrEqual(config.name, currentGroup))
        {
            strcopy(prefix, sizeof(prefix), GESTURE_CURRENT);
        }
        
        bool isVoted = (g_bVoteCompleted && StrEqual(config.name, g_sVoteGameMode));
        char voteIndicator[6];
        strcopy(voteIndicator, sizeof(voteIndicator), isVoted ? GESTURE_VOTED : "");
        
        if (forceMode)
        {
            if (config.enabled == 0 && config.adminonly == 1)
                Format(display, sizeof(display), "[DISABLED, ADMIN] %s%s%s", config.name, voteIndicator, prefix);
            else if (config.enabled == 0)
                Format(display, sizeof(display), "[DISABLED] %s%s%s", config.name, voteIndicator, prefix);
            else if (config.adminonly == 1)
                Format(display, sizeof(display), "[ADMIN] %s%s%s", config.name, voteIndicator, prefix);
            else
                Format(display, sizeof(display), "%s%s%s", config.name, voteIndicator, prefix);
        }
        else
        {
            Format(display, sizeof(display), "%s%s%s", prefix, config.name, voteIndicator);
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

void ShowMapMenu(int client, const char[] sGameMode, const char[] subgroup = "")
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

    ArrayList maps = null;

    if (strlen(subgroup) > 0)
    {
        int subgroupIndex = FindSubGroupIndex(sGameMode, subgroup);
        if (subgroupIndex == -1)
        {
            CPrintToChat(client, "%t", "No Available SubGroups");
            return;
        }

        SubGroupConfig subConfig;
        config.subGroups.GetArray(subgroupIndex, subConfig);
        maps = subConfig.maps;
    }
    else
    {
        maps = config.maps;
    }

    if (maps == null || maps.Length == 0)
    {
        CPrintToChat(client, "%t", "None Show Map Group");
        return;
    }

    Menu menu = new Menu(ForceMapMenuHandler);
    
    if (strlen(subgroup) > 0)
    {
        menu.SetTitle("%t", "SubGroup Map Selection Title", sGameMode, subgroup);
    }
    else
    {
        menu.SetTitle("%t", "Show Map Group Title", config.name);
    }
    
    ArrayList mapsClone = view_as<ArrayList>(CloneHandle(maps));
    mapsClone.Sort(Sort_Random, Sort_String);
    
    char currentMapName[PLATFORM_MAX_PATH];
    GetCurrentMap(currentMapName, sizeof(currentMapName));
    
    char map[256];
    char display[256];
    
    for (int i = 0; i < mapsClone.Length; i++)
    {
        mapsClone.GetString(i, map, sizeof(map));
        
        GetMapDisplayNameEx(config.name, map, display, sizeof(display), subgroup);
        
        char prefix[8] = "";
        if (StrEqual(map, currentMapName))
        {
            strcopy(prefix, sizeof(prefix), GESTURE_CURRENT);
        }

        bool isMapVoted = (g_bVoteCompleted && StrEqual(map, g_sVoteMap) && StrEqual(sGameMode, g_sVoteGameMode));
        char voteIndicator[6];
        strcopy(voteIndicator, sizeof(voteIndicator), isMapVoted ? GESTURE_VOTED : "");
        
        Format(display, sizeof(display), "%s%s%s", display, voteIndicator, prefix);
        
        menu.AddItem(map, display);
    }
    
    delete mapsClone;
    
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
    int index = FindGameModeIndex(gamemode);
    if (index == -1)
    {
        CPrintToChat(client, "%t", "Gamemode Not Found");
        return;
    }

    GameModeConfig config;
    ArrayList list = GetGameModesList();
    list.GetArray(index, config);

    Menu menu = new Menu(ForceSubGroupMenuHandler);
    menu.SetTitle("%t", "SubGroup Force Title", gamemode);

    char currentGroup[64], currentSubgroup[64];
    SplitGamemodeString(g_sCurrentGameMode, currentGroup, sizeof(currentGroup), currentSubgroup, sizeof(currentSubgroup));

    for (int i = 0; i < config.subGroups.Length; i++)
    {
        SubGroupConfig subConfig;
        config.subGroups.GetArray(i, subConfig);

        if (!subConfig.enabled) continue;

        char display[128];
        char prefix[8] = "";

        if (StrEqual(gamemode, currentGroup) && StrEqual(subConfig.name, currentSubgroup))
        {
            strcopy(prefix, sizeof(prefix), GESTURE_CURRENT);
        }

        Format(display, sizeof(display), "%s%s", subConfig.name, prefix);
        menu.AddItem(subConfig.name, display);
    }

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
    strcopy(g_sNextSubGroup, sizeof(g_sNextSubGroup), subgroup);
	
	NativeMMC_OnGamemodeChanged(gamemode, subgroup, map, timing);
    
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
            g_bChangeMapNextRound = true;
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

void StartGameModeVote(int client, bool adminVote = false, ArrayList runoffItems = null)
{
    g_bIsRunoffVote = (runoffItems != null);
    WriteToLogFile("[MultiMode Core] Stabilized Voting (Gamemode)");
    
    if (!g_Cvar_Enabled.BoolValue || g_bVoteActive || g_bCooldownActive)
    {
        CPrintToChat(client, "%t", "Gamemode Vote Already");
        return;
    }
	
	NativeMMC_OnVoteStart(client);
	NativeMMC_OnVoteStartEx(client, 0, runoffItems != null);
    
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
        CloseHandle(g_hRtvTimers[1]);
        g_hRtvTimers[1] = INVALID_HANDLE;
    }
	
    g_bRtvCooldown = false;
	
	g_eCurrentVoteTiming = g_eVoteTiming;
    
    ArrayList voteGameModes;

    if (runoffItems != null)
    {
        voteGameModes = runoffItems;
    }
    else
    {
        voteGameModes = new ArrayList(ByteCountToCells(64));
        ArrayList nominatedItems = new ArrayList(ByteCountToCells(128));
        ArrayList otherItems = new ArrayList(ByteCountToCells(64));

        int groupExclude = adminVote ? g_Cvar_VoteAdminGroupExclude.IntValue : g_Cvar_VoteGroupExclude.IntValue;

        for (int i = 0; i < g_NominatedGamemodes.Length; i++)
        {
            char nominatedGM[128];
            g_NominatedGamemodes.GetString(i, nominatedGM, sizeof(nominatedGM));

            if (groupExclude > 0 && g_PlayedGamemodes.FindString(nominatedGM) != -1)
            {
                continue;
            }

            char groupName[64];
            SplitGamemodeString(nominatedGM, groupName, sizeof(groupName), "", 0);
            int index = FindGameModeIndex(groupName);
            if (index == -1) continue;

            GameModeConfig config;
            gameModes.GetArray(index, config);

            bool available = adminVote ? GamemodeAvailableAdminVote(config.name) : GamemodeAvailable(config.name);

            if (available && nominatedItems.FindString(nominatedGM) == -1 && IsCurrentlyAvailableByTime(groupName))
            {
                nominatedItems.PushString(nominatedGM);
            }
        }

        for (int i = 0; i < gameModes.Length; i++)
        {
            GameModeConfig config;
            gameModes.GetArray(i, config);

            bool available = adminVote ? (config.enabled == 1) : GamemodeAvailable(config.name);
            if (!available) continue;

            if (groupExclude > 0 && g_PlayedGamemodes.FindString(config.name) != -1)
                continue;

            if (g_NominatedGamemodes.FindString(config.name) == -1 && IsCurrentlyAvailableByTime(config.name))
            {
                otherItems.PushString(config.name);
            }
        }

        int sortMode = adminVote ? g_Cvar_VoteAdminSorted.IntValue : g_Cvar_VoteSorted.IntValue;

        if (sortMode == 0) // Alphabetical
        {
            nominatedItems.Sort(Sort_Ascending, Sort_String);
            otherItems.Sort(Sort_Ascending, Sort_String);
        }
        else if (sortMode == 1) // Random
        {
            nominatedItems.Sort(Sort_Random, Sort_String);
            otherItems.Sort(Sort_Random, Sort_String);
        }
        // Case 2 (Map Cycle Order) is default, no sort needed.

        for (int i = 0; i < nominatedItems.Length && voteGameModes.Length < 6; i++)
        {
            char gm[128];
            nominatedItems.GetString(i, gm, sizeof(gm));
            voteGameModes.PushString(gm);
        }

        for (int i = 0; i < otherItems.Length && voteGameModes.Length < 6; i++)
        {
            char gm[64];
            otherItems.GetString(i, gm, sizeof(gm));
            if (voteGameModes.FindString(gm) == -1)
            {
                voteGameModes.PushString(gm);
            }
        }

        delete nominatedItems;
        delete otherItems;
    }
    
    g_bCurrentVoteAdmin = adminVote;
	
	bool canExtend = (g_Cvar_ExtendEveryTime.BoolValue || !g_bMapExtended) && CanExtendMap();
	
    if (g_Cvar_NativeVotes.BoolValue && LibraryExists("nativevotes"))
    {
        NativeVote vote = CreateNativeVote(NativeVoteHandler);
        if (vote != null)
        {
            vote.VoteResultCallback = NativeVoteResultHandler;
            g_eCurrentNativeVoteType = VOTE_TYPE_GROUP;

            if (runoffItems == null && g_Cvar_Extend.BoolValue && canExtend && ((adminVote && g_Cvar_ExtendVoteAdmin.BoolValue) || (!adminVote && g_Cvar_ExtendVote.BoolValue)))
            {
                char extendText[128];
                int extendMinutes = g_Cvar_ExtendSteps.IntValue;
                Format(extendText, sizeof(extendText), "%t", "Extend Map Normal Vote", extendMinutes);
                vote.AddItem("Extend Map", extendText);
            }

            for (int i = 0; i < voteGameModes.Length; i++)
            {
                char gm[64], display[128];
                voteGameModes.GetString(i, gm, sizeof(gm));
                
                if (g_NominatedGamemodes.FindString(gm) != -1)
                {
                    Format(display, sizeof(display), "%s%s", gm, GESTURE_NOMINATED);
                }
                else
                {
                    strcopy(display, sizeof(display), gm);
                }
                
                vote.AddItem(gm, display);
            }

            vote.DisplayVoteToAll(g_Cvar_VoteTime.IntValue);
            g_bVoteActive = true;
            if (runoffItems == null) delete voteGameModes;
            return;
        }
    }
    
    Menu menu = new Menu(GameModeVoteHandler);
    menu.SetTitle("%t", "Normal Vote Gamemode Group Title");
    menu.VoteResultCallback = GameModeVoteResultHandler;
    
    if (runoffItems == null && g_Cvar_Extend.BoolValue && canExtend && ((adminVote && g_Cvar_ExtendVoteAdmin.BoolValue) || (!adminVote && g_Cvar_ExtendVote.BoolValue)))
    {
        char extendText[128];
        int extendMinutes = g_Cvar_ExtendSteps.IntValue;
        Format(extendText, sizeof(extendText), "%t", "Extend Map Normal Vote", extendMinutes);
        menu.AddItem("Extend Map", extendText);
    }
        
    if (g_Cvar_VoteSounds.BoolValue)
    {
        char sound[PLATFORM_MAX_PATH];
        if (g_bIsRunoffVote)
        {
            g_Cvar_RunoffVoteOpenSound.GetString(sound, sizeof(sound));
        }
        else
        {
            g_Cvar_VoteOpenSound.GetString(sound, sizeof(sound));
        }
        if (sound[0] != '\0')
        {
            EmitSoundToAllAny(sound);
        }
    }
    
    for (int i = 0; i < voteGameModes.Length; i++)
    {
        char gm[128];
        voteGameModes.GetString(i, gm, sizeof(gm));
        
        char display[128];
        char groupName[64];
        SplitGamemodeString(gm, groupName, sizeof(groupName), "", 0);
        int index = FindGameModeIndex(groupName);
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
            if (isAdminMode) Format(display, sizeof(display), "[ADMIN] %s%s", gm, GESTURE_NOMINATED);
            else Format(display, sizeof(display), "%s%s", gm, GESTURE_NOMINATED);
        }
        else
        {
            if (isAdminMode) Format(display, sizeof(display), "[ADMIN] %s", gm);
            else strcopy(display, sizeof(display), gm);
        }
        
        menu.AddItem(gm, display);
    }
    
    if (runoffItems == null)
    {
        delete voteGameModes;
    }
    
    menu.ExitButton = false;
    menu.DisplayVoteToAll(g_Cvar_VoteTime.IntValue);
    g_bVoteActive = true;
}

void StartSubGroupVote(int client, const char[] gamemode, ArrayList runoffItems = null)
{
    g_bIsRunoffVote = (runoffItems != null);
    if (!g_Cvar_Enabled.BoolValue || g_bVoteActive || g_bCooldownActive)
    {
        CPrintToChatAll("%t", "Vote Already Active");
        return;
    }

    int gamemodeIndex = FindGameModeIndex(gamemode);
    if (gamemodeIndex == -1)
    {
        CPrintToChat(client, "%t", "Gamemode Not Found");
        return;
    }

    GameModeConfig config;
    ArrayList list = GetGameModesList();
    list.GetArray(gamemodeIndex, config);

    if (config.subGroups == null || config.subGroups.Length == 0)
    {
        StartMapVote(client, gamemode);
        return;
    }

    NativeMMC_OnVoteStart(client);
    NativeMMC_OnVoteStartEx(client, 1, false);

    ArrayList voteSubGroups;
    if (runoffItems != null)
    {
        voteSubGroups = runoffItems;
    }
    else
    {
        voteSubGroups = new ArrayList(ByteCountToCells(64));
        ArrayList allSubGroups = new ArrayList(ByteCountToCells(64));

        for (int i = 0; i < config.subGroups.Length; i++)
        {
            SubGroupConfig subConfig;
            config.subGroups.GetArray(i, subConfig);
            
            if (!subConfig.enabled) continue;
            
            if (subConfig.adminonly == 1 && !CheckCommandAccess(client, "sm_admin", ADMFLAG_GENERIC, true))
                continue;

            int players = GetRealClientCount();
            if (subConfig.minplayers > 0 && players < subConfig.minplayers) continue;
            if (subConfig.maxplayers > 0 && players > subConfig.maxplayers) continue;

            allSubGroups.PushString(subConfig.name);
        }

        int sortMode = g_bCurrentVoteAdmin ? g_Cvar_VoteAdminSorted.IntValue : g_Cvar_VoteSorted.IntValue;
        if (sortMode == 0) // Alphabetical
        {
            allSubGroups.Sort(Sort_Ascending, Sort_String);
        }
        else if (sortMode == 1) // Random
        {
            allSubGroups.Sort(Sort_Random, Sort_String);
        }

        int limit = config.subgroups_invote;
        int count = allSubGroups.Length < limit ? allSubGroups.Length : limit;

        for (int i = 0; i < count; i++)
        {
            char subGroupName[64];
            allSubGroups.GetString(i, subGroupName, sizeof(subGroupName));
            voteSubGroups.PushString(subGroupName);
        }
        delete allSubGroups;
    }

    if (voteSubGroups.Length == 0)
    {
        CPrintToChat(client, "%t", "No Available SubGroups");
        if (runoffItems == null) delete voteSubGroups;
        return;
    }

    if (g_Cvar_NativeVotes.BoolValue && LibraryExists("nativevotes"))
    {
        NativeVote vote = CreateNativeVote(NativeSubGroupVoteHandler);
        if (vote != null)
        {
            vote.VoteResultCallback = NativeVoteResultHandler;
            g_eCurrentNativeVoteType = VOTE_TYPE_SUBGROUP;

            char title[128];
            Format(title, sizeof(title), "%T", "SubGroup Vote Title", LANG_SERVER, gamemode);
            vote.SetTitle(title);

            for (int i = 0; i < voteSubGroups.Length; i++)
            {
                char subgroup[64];
                voteSubGroups.GetString(i, subgroup, sizeof(subgroup));
                vote.AddItem(subgroup, subgroup);
            }

            vote.DisplayVoteToAll(g_Cvar_VoteTime.IntValue);
            g_bVoteActive = true;
            strcopy(g_sVoteGameMode, sizeof(g_sVoteGameMode), gamemode);
            if (runoffItems == null) delete voteSubGroups;
            return;
        }
    }

    Menu menu = new Menu(SubGroupVoteHandler);
    menu.SetTitle("%t", "SubGroup Vote Title", gamemode);
    menu.VoteResultCallback = SubGroupVoteResultHandler;

    if (g_Cvar_VoteSounds.BoolValue)
    {
        char sound[PLATFORM_MAX_PATH];
        if (g_bIsRunoffVote)
        {
            g_Cvar_RunoffVoteOpenSound.GetString(sound, sizeof(sound));
        }
        else
        {
            g_Cvar_VoteOpenSound.GetString(sound, sizeof(sound));
        }
        if (sound[0] != '\0')
        {
            EmitSoundToAllAny(sound);
        }
    }

    for (int i = 0; i < voteSubGroups.Length; i++)
    {
        char subgroup[64];
        voteSubGroups.GetString(i, subgroup, sizeof(subgroup));
        menu.AddItem(subgroup, subgroup);
    }

    if (runoffItems == null) delete voteSubGroups;

    menu.ExitButton = false;
    menu.DisplayVoteToAll(g_Cvar_VoteTime.IntValue);
    g_bVoteActive = true;
    strcopy(g_sVoteGameMode, sizeof(g_sVoteGameMode), gamemode);
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
    
    WriteToLogFile("The map was extended by vote by %d minutes, %d rounds and %d frags.", extendMinutes, roundStep, fragStep);
    
    g_bEndVoteTriggered = false;
    
    if (g_Cvar_EndVoteEnabled.BoolValue) 
    {
        delete g_hEndVoteTimer;
        g_hEndVoteTimer = CreateTimer(1.0, Timer_CheckEndVote, _, TIMER_REPEAT);
    }
	
	NativeMMC_OnVoteEnd("Extend Map", "", "", VoteEnd_Extend);

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
    
    char clientName[MAX_NAME_LENGTH];
    GetClientName(client, clientName, sizeof(clientName));
    WriteToLogFile("\"%s\" extended the map by %.1f minutes, %d rounds and %d frags.", clientName, minutes, g_Cvar_ExtendRoundStep.IntValue, g_Cvar_ExtendFragStep.IntValue);
    
    g_bInternalChange = false;
}

public void ExecuteVoteResult()
{
    if (GetVoteMethod() == 3 && strlen(g_sVoteMap) > 0 && strlen(g_sVoteGameMode) == 0)
    {
        int index = FindGameModeForMap(g_sVoteMap);
        if (index != -1)
        {
            GameModeConfig config;
            ArrayList list = GetGameModesList();
            list.GetArray(index, config);
            strcopy(g_sVoteGameMode, sizeof(g_sVoteGameMode), config.name);
        }
        else
        {
            WriteToLogFile("[MultiMode Core] WARNING: Method 3: Could not find gamemode for map '%s'", g_sVoteMap);
        }
    }
	
	strcopy(g_sNextSubGroup, sizeof(g_sNextSubGroup), g_sVoteSubGroup);
	
    g_eCurrentVoteTiming = g_eEndVoteTiming;
	
	NativeMMC_OnVoteEnd(g_sVoteGameMode, g_sVoteSubGroup, g_sVoteMap, VoteEnd_Winner);
	
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
            g_bChangeMapNextRound = true;
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
    
    strcopy(g_sNextGameMode, sizeof(g_sNextGameMode), g_sVoteGameMode);
    strcopy(g_sNextMap, sizeof(g_sNextMap), g_sVoteMap);
	
	ExecuteVoteCommands(g_sVoteGameMode, g_sVoteMap);
	
    NativeMMC_OnGamemodeChangedVote(g_sVoteGameMode, g_sVoteSubGroup, g_sVoteMap, view_as<int>(g_eVoteTiming));
	
    g_bRtvDisabled = true;
    
}

public void ExecuteSubGroupVoteResult()
{
    NativeMMC_OnVoteEnd(g_sVoteGameMode, g_sVoteSubGroup, g_sVoteMap, VoteEnd_Winner);
	
	strcopy(g_sNextSubGroup, sizeof(g_sNextSubGroup), g_sVoteSubGroup);
    
    g_bEndVoteTriggered = false;
    g_bVoteActive = false;
    g_bVoteCompleted = true;
    
    if (g_hEndVoteTimer != INVALID_HANDLE) 
    {
        KillTimer(g_hEndVoteTimer);
        g_hEndVoteTimer = INVALID_HANDLE;
    }
    
    int gamemodeIndex = FindGameModeIndex(g_sVoteGameMode);
    int subgroupIndex = FindSubGroupIndex(g_sVoteGameMode, g_sVoteSubGroup);
    
    if (gamemodeIndex != -1 && subgroupIndex != -1)
    {
        GameModeConfig config;
        ArrayList list = GetGameModesList();
        list.GetArray(gamemodeIndex, config);

        SubGroupConfig subConfig;
        config.subGroups.GetArray(subgroupIndex, subConfig);

        if (strlen(subConfig.vote_command) > 0)
        {
            ServerCommand("%s", subConfig.vote_command);
            WriteToLogFile("[MultiMode Core] Executed subgroup vote-command: %s", subConfig.vote_command);
        }

        KeyValues kv = GetSubGroupMapKv(g_sVoteGameMode, g_sVoteSubGroup, g_sVoteMap);
        if (kv != null)
        {
            char mapVoteCommand[256];
            kv.GetString("vote-command", mapVoteCommand, sizeof(mapVoteCommand), "");
            
            if (strlen(mapVoteCommand) > 0)
            {
                ServerCommand("%s", mapVoteCommand);
                WriteToLogFile("[MultiMode Core] Executed subgroup map vote-command: %s", mapVoteCommand);
            }
            
            delete kv;
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
            WriteToLogFile("[MultiMode Core] Next map set (subgroup vote): %s (Group: %s, SubGroup: %s)", g_sNextMap, g_sVoteGameMode, g_sVoteSubGroup);
        }
        
        case TIMING_NEXTROUND:
        {
            g_bChangeMapNextRound = true;
            strcopy(g_sNextMap, sizeof(g_sNextMap), g_sVoteMap);
            strcopy(g_sNextGameMode, sizeof(g_sNextGameMode), g_sVoteGameMode);
            SetNextMap(g_sNextMap);
            CPrintToChatAll("%t", "Timing NextRound Notify", g_sNextMap);
            WriteToLogFile("[MultiMode Core] Next round map set (subgroup vote): %s (Group: %s, SubGroup: %s)", g_sNextMap, g_sVoteGameMode, g_sVoteSubGroup);
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
            WriteToLogFile("[MultiMode Core] Map instantly set to (subgroup vote): %s (Group: %s, SubGroup: %s)", g_sNextMap, g_sVoteGameMode, g_sVoteSubGroup);
        }
    }
    
    NativeMMC_OnGamemodeChangedVote(g_sVoteGameMode, g_sVoteSubGroup, g_sVoteMap, view_as<int>(g_eVoteTiming));
    g_bRtvDisabled = true;
}

void StartMapVote(int client, const char[] sGameMode, ArrayList runoffItems = null)
{
    g_bIsRunoffVote = (runoffItems != null);
    if (g_bVoteActive || !g_Cvar_Enabled.BoolValue)
    {
        CPrintToChat(client, "%t", "Vote Already Active");
        return;
    }
	
    if (GetVoteMethod() == 3 || strlen(sGameMode) > 0)
    {
        NativeMMC_OnVoteStart(client);
		NativeMMC_OnVoteStartEx(client, 2, runoffItems != null);
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
        
        g_sVoteGameMode[0] = '\0';

        ArrayList voteMaps;
        if (runoffItems != null)
        {
            voteMaps = runoffItems;
        }
        else
        {
            voteMaps = new ArrayList(ByteCountToCells(PLATFORM_MAX_PATH));
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
                    
                    if (!uniqueMaps.ContainsKey(map) && 
                        IsCurrentlyAvailableByTime(config.name, "", map))
                    {
                        voteMaps.PushString(map);
                        uniqueMaps.SetValue(map, true);
                    }
                }

                for (int k = 0; k < config.subGroups.Length; k++)
                {
                    SubGroupConfig subConfig;
                    config.subGroups.GetArray(k, subConfig);
                    
                    if (!subConfig.enabled) continue;
                    
                    if (subConfig.adminonly == 1 && !g_bCurrentVoteAdmin)
                        continue;

                    int players = GetRealClientCount();
                    if (subConfig.minplayers > 0 && players < subConfig.minplayers) continue;
                    if (subConfig.maxplayers > 0 && players > subConfig.maxplayers) continue;

                    for (int j = 0; j < subConfig.maps.Length; j++)
                    {
                        char map[PLATFORM_MAX_PATH];
                        subConfig.maps.GetString(j, map, sizeof(map));
                        
                        if (!uniqueMaps.ContainsKey(map) && 
                            IsCurrentlyAvailableByTime(config.name, subConfig.name, map))
                        {
                            voteMaps.PushString(map);
                            uniqueMaps.SetValue(map, true);
                        }
                    }
                }
            }

            StringMapSnapshot snapshot = g_NominatedMaps.Snapshot();
            for (int i = 0; i < snapshot.Length; i++)
            {
                char group[128];
                snapshot.GetKey(i, group, sizeof(group));

                char groupName[64];
                SplitGamemodeString(group, groupName, sizeof(groupName), "", 0);
                int groupIndex = FindGameModeIndex(groupName);
                if (groupIndex == -1) continue;

                GameModeConfig config;
                gameModes.GetArray(groupIndex, config);

                bool groupAvailable;
                if (g_bCurrentVoteAdmin) {
                    groupAvailable = GamemodeAvailableAdminVote(groupName);
                } else {
                    groupAvailable = GamemodeAvailable(groupName);
                }

                if (!groupAvailable) continue;

                ArrayList mapsNominated;
                g_NominatedMaps.GetValue(group, mapsNominated);
                for (int j = 0; j < mapsNominated.Length; j++)
                {
                    char map[PLATFORM_MAX_PATH];
                    mapsNominated.GetString(j, map, sizeof(map));
                    
                    char subgroup[64] = "";
                    if (StrContains(group, "/") != -1)
                    {
                        char parts[2][64];
                        ExplodeString(group, "/", parts, 2, 64);
                        strcopy(subgroup, sizeof(subgroup), parts[1]);
                    }
                    
                    if (!uniqueMaps.ContainsKey(map) && 
                        IsCurrentlyAvailableByTime(groupName, subgroup, map))
                    {
                        voteMaps.PushString(map);
                        uniqueMaps.SetValue(map, true);
                    }
                }
            }
            delete snapshot;
            delete uniqueMaps;

            int sortMode = g_bCurrentVoteAdmin ? g_Cvar_VoteAdminSorted.IntValue : g_Cvar_VoteSorted.IntValue;

            if (sortMode == 0) // Alphabetical
            {
                voteMaps.Sort(Sort_Ascending, Sort_String);
            }
            else if (sortMode == 1) // Random
            {
                voteMaps.Sort(Sort_Random, Sort_String);
            }
            // Case 2 (Map Cycle Order) is default, no sort needed.
            
            int maxItems = 6;
            
            if (voteMaps.Length > maxItems)
            {
                voteMaps.Resize(maxItems);
            }
        }

        if (g_Cvar_NativeVotes.BoolValue && LibraryExists("nativevotes"))
        {
            NativeVote vote = CreateNativeVote(NativeMapVoteHandler, true);
            if (vote != null)
            {
                vote.VoteResultCallback = NativeVoteResultHandler;
                g_eCurrentNativeVoteType = VOTE_TYPE_MAP;

                bool canExtend = (g_Cvar_ExtendEveryTime.BoolValue || !g_bMapExtended) && CanExtendMap();
                if (runoffItems == null && g_Cvar_Extend.BoolValue && canExtend && ((g_bCurrentVoteAdmin && g_Cvar_ExtendVoteAdmin.BoolValue) || (!g_bCurrentVoteAdmin && g_Cvar_ExtendVote.BoolValue)))
                {
                    char extendText[128];
                    int extendMinutes = g_Cvar_ExtendSteps.IntValue;
                    Format(extendText, sizeof(extendText), "%t", "Extend Map Normal Vote", extendMinutes);
                    vote.AddItem("Extend Map", extendText);
                }

                char map[PLATFORM_MAX_PATH], display[256];
                for (int i = 0; i < voteMaps.Length; i++)
                {
                    voteMaps.GetString(i, map, sizeof(map));
                    GetMapDisplayNameEx("", map, display, sizeof(display));
                    vote.AddItem(map, display);
                }

                if (runoffItems == null) delete voteMaps;

                vote.DisplayVoteToAll(g_Cvar_VoteTime.IntValue);
                g_bVoteActive = true;
                g_sSelectedGameMode = "";
                return;
            }
        }

        Menu menu = new Menu(MapVoteHandler);
        menu.VoteResultCallback = MapVoteResultHandler;
        menu.SetTitle("%t", "Start Map Vote Title");

        bool canExtend = (g_Cvar_ExtendEveryTime.BoolValue || !g_bMapExtended) && CanExtendMap();
		
        if (runoffItems == null && g_Cvar_Extend.BoolValue && canExtend && ((g_bCurrentVoteAdmin && g_Cvar_ExtendVoteAdmin.BoolValue) || (!g_bCurrentVoteAdmin && g_Cvar_ExtendVote.BoolValue)))
        {
            char extendText[128];
            int extendMinutes = g_Cvar_ExtendSteps.IntValue;
            Format(extendText, sizeof(extendText), "%t", "Extend Map Normal Vote", extendMinutes);
            menu.AddItem("Extend Map", extendText);
        }

        char map[PLATFORM_MAX_PATH], display[256];
        for (int i = 0; i < voteMaps.Length; i++)
        {
            voteMaps.GetString(i, map, sizeof(map));
            GetMapDisplayNameEx("", map, display, sizeof(display));
            menu.AddItem(map, display);
        }

        if (runoffItems == null) delete voteMaps;

        if (g_Cvar_VoteSounds.BoolValue)
        {
            char sound[PLATFORM_MAX_PATH];
            if (g_bIsRunoffVote)
            {
                g_Cvar_RunoffVoteOpenSound.GetString(sound, sizeof(sound));
            }
            else
            {
                g_Cvar_VoteOpenSound.GetString(sound, sizeof(sound));
            }
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

    strcopy(g_sVoteGameMode, sizeof(g_sVoteGameMode), config.name);
    strcopy(g_sSelectedGameMode, sizeof(g_sSelectedGameMode), sGameMode);

    if (config.maps == null || config.maps.Length == 0)
    {
        CPrintToChatAll("%t", "Non Maps Items");
        return;
    }

    ArrayList voteMaps;
    ArrayList mapsNominated;

    if (runoffItems != null)
    {
        voteMaps = runoffItems;
        g_NominatedMaps.GetValue(sGameMode, mapsNominated); // Still need this for display
    }
    else
    {
        voteMaps = new ArrayList(ByteCountToCells(PLATFORM_MAX_PATH));
        int sortMode = g_bCurrentVoteAdmin ? g_Cvar_VoteAdminSorted.IntValue : g_Cvar_VoteSorted.IntValue;
        int mapExclude = g_bCurrentVoteAdmin ? 
            g_Cvar_VoteAdminMapExclude.IntValue : 
            g_Cvar_VoteMapExclude.IntValue;

        char key[128];
        strcopy(key, sizeof(key), sGameMode);

        if (g_NominatedMaps.GetValue(key, mapsNominated) && mapsNominated.Length > 0)
        {
            ArrayList nominateList = view_as<ArrayList>(CloneHandle(mapsNominated));
            if (sortMode == 0) // Alphabetical
            {
                nominateList.Sort(Sort_Ascending, Sort_String);
            }
            else if (sortMode == 1) // Random
            {
                nominateList.Sort(Sort_Random, Sort_String);
            }

            for (int i = 0; i < nominateList.Length; i++)
            {
                char map[PLATFORM_MAX_PATH];
                nominateList.GetString(i, map, sizeof(map));
                
                if (mapExclude > 0) 
                {
                    ArrayList playedMaps;
                    if (g_PlayedMaps.GetValue(key, playedMaps) && 
                        playedMaps.FindString(map) != -1)
                    {
                        continue;
                    }
                }
                
                if (IsMapValid(map) && voteMaps.FindString(map) == -1)
                {
                    voteMaps.PushString(map);
                }

                if(voteMaps.Length >= config.maps_invote)
                    break;
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

            if (sortMode == 0) // Alphabetical
            {
                availableMaps.Sort(Sort_Ascending, Sort_String);
            }
            else if (sortMode == 1) // Random
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
    }

    if (g_Cvar_NativeVotes.BoolValue && LibraryExists("nativevotes")) 
    {
        NativeVote mapVote = new NativeVote(NativeMapVoteHandler, NativeVotesType_Custom_Mult);
        if (mapVote != null)
        {
            mapVote.VoteResultCallback = NativeVoteResultHandler;
            g_eCurrentNativeVoteType = VOTE_TYPE_MAP;

            char title[128];
            Format(title, sizeof(title), "%T", "Start Map Vote Title", LANG_SERVER, config.name);
            mapVote.SetTitle(title);

            for (int i = 0; i < voteMaps.Length; i++)
            {
                char map[PLATFORM_MAX_PATH], display[256];
                voteMaps.GetString(i, map, sizeof(map));
                GetMapDisplayNameEx(config.name, map, display, sizeof(display));

                if (mapsNominated != null && mapsNominated.FindString(map) != -1)
                {
                    Format(display, sizeof(display), "%s%s", display, GESTURE_NOMINATED);
                }

                mapVote.AddItem(map, display);
            }

            mapVote.DisplayVoteToAll(g_Cvar_VoteTime.IntValue);
            g_bVoteActive = true;
            if (runoffItems == null) delete voteMaps;
            return;
        }
    }

    Menu voteMenu = new Menu(MapVoteHandler);
    voteMenu.VoteResultCallback = MapVoteResultHandler;
    voteMenu.SetTitle("%t", "Show Map Group Title", config.name);

    if (g_Cvar_VoteSounds.BoolValue)
    {
        char sound[PLATFORM_MAX_PATH];
        if (g_bIsRunoffVote)
        {
            g_Cvar_RunoffVoteOpenSound.GetString(sound, sizeof(sound));
        }
        else
        {
            g_Cvar_VoteOpenSound.GetString(sound, sizeof(sound));
        }
        if (sound[0] != '\0') EmitSoundToAllAny(sound);
    }

    char map[PLATFORM_MAX_PATH], display[256];
    for (int i = 0; i < voteMaps.Length; i++)
    {
        voteMaps.GetString(i, map, sizeof(map));
        GetMapDisplayNameEx(config.name, map, display, sizeof(display));

        if (mapsNominated != null && mapsNominated.FindString(map) != -1)
        {
            Format(display, sizeof(display), "%s%s", display, GESTURE_NOMINATED);
        }
        voteMenu.AddItem(map, display);
    }

    if (runoffItems == null) delete voteMaps;

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

void StartSubGroupMapVote(int client, const char[] gamemode, const char[] subgroup, ArrayList runoffItems = null)
{
    g_bIsRunoffVote = (runoffItems != null);
    if (g_bVoteActive || !g_Cvar_Enabled.BoolValue)
    {
        CPrintToChat(client, "%t", "Vote Already Active");
        return;
    }

    int gamemodeIndex = FindGameModeIndex(gamemode);
    if (gamemodeIndex == -1)
    {
        CPrintToChat(client, "%t", "Gamemode Not Found");
        return;
    }

    int subgroupIndex = FindSubGroupIndex(gamemode, subgroup);
    if (subgroupIndex == -1)
    {
        CPrintToChat(client, "%t", "SubGroup Not Found");
        return;
    }

    GameModeConfig config;
    ArrayList list = GetGameModesList();
    list.GetArray(gamemodeIndex, config);

    SubGroupConfig subConfig;
    config.subGroups.GetArray(subgroupIndex, subConfig);

    if (subConfig.maps == null || subConfig.maps.Length == 0)
    {
        CPrintToChat(client, "%t", "No Maps In SubGroup");
        return;
    }

    NativeMMC_OnVoteStart(client);
    NativeMMC_OnVoteStartEx(client, 4, false);

    ArrayList voteMaps;
    if (runoffItems != null)
    {
        voteMaps = runoffItems;
    }
    else
    {
        voteMaps = new ArrayList(ByteCountToCells(PLATFORM_MAX_PATH));
        for (int i = 0; i < subConfig.maps.Length; i++)
        {
            char map[PLATFORM_MAX_PATH];
            subConfig.maps.GetString(i, map, sizeof(map));
            
            if (IsMapValid(map) && IsCurrentlyAvailableByTime(gamemode, subgroup, map))
            {
                voteMaps.PushString(map);
            }
        }
    }

    if (voteMaps.Length == 0)
    {
        CPrintToChat(client, "%t", "No Valid Maps In SubGroup");
        if (runoffItems == null) delete voteMaps;
        return;
    }

    if (runoffItems == null)
    {
        int sortMode = g_bCurrentVoteAdmin ? g_Cvar_VoteAdminSorted.IntValue : g_Cvar_VoteSorted.IntValue;
        if (sortMode == 0) // Alphabetical
        {
            voteMaps.Sort(Sort_Ascending, Sort_String);
        }
        else if (sortMode == 1) // Random
        {
            voteMaps.Sort(Sort_Random, Sort_String);
        }

        int maxItems = 6;
        if (voteMaps.Length > maxItems)
        {
            voteMaps.Resize(maxItems);
        }
    }

    if (g_Cvar_NativeVotes.BoolValue && LibraryExists("nativevotes"))
    {
        NativeVote vote = CreateNativeVote(NativeSubGroupMapVoteHandler, true);
        if (vote != null)
        {
            vote.VoteResultCallback = NativeVoteResultHandler;
            g_eCurrentNativeVoteType = VOTE_TYPE_SUBGROUP_MAP;

            char title[128];
            Format(title, sizeof(title), "%T", "SubGroup Map Vote Title", LANG_SERVER, gamemode, subgroup);
            vote.SetTitle(title);

            for (int i = 0; i < voteMaps.Length; i++)
            {
                char map[PLATFORM_MAX_PATH], display[256];
                voteMaps.GetString(i, map, sizeof(map));
                GetMapDisplayNameEx(gamemode, map, display, sizeof(display), subgroup);
                vote.AddItem(map, display);
            }

            vote.DisplayVoteToAll(g_Cvar_VoteTime.IntValue);
            g_bVoteActive = true;
            strcopy(g_sVoteGameMode, sizeof(g_sVoteGameMode), gamemode);
            strcopy(g_sVoteSubGroup, sizeof(g_sVoteSubGroup), subgroup);
			strcopy(g_sNextSubGroup, sizeof(g_sNextSubGroup), subgroup); 
            if (runoffItems == null) delete voteMaps;
            return;
        }
    }

    Menu menu = new Menu(SubGroupMapVoteHandler);
    menu.SetTitle("%t", "SubGroup Map Vote Title", gamemode, subgroup);
    menu.VoteResultCallback = SubGroupMapVoteResultHandler;

    if (g_Cvar_VoteSounds.BoolValue)
    {
        char sound[PLATFORM_MAX_PATH];
        g_Cvar_VoteOpenSound.GetString(sound, sizeof(sound));
        if (sound[0] != '\0')
        {
            EmitSoundToAllAny(sound);
        }
    }

    for (int i = 0; i < voteMaps.Length; i++)
    {
        char map[PLATFORM_MAX_PATH], display[256];
        voteMaps.GetString(i, map, sizeof(map));
        GetMapDisplayNameEx(gamemode, map, display, sizeof(display), subgroup);
        menu.AddItem(map, display);
    }

    if (runoffItems == null) delete voteMaps;

    menu.ExitButton = false;
    menu.DisplayVoteToAll(g_Cvar_VoteTime.IntValue);
    g_bVoteActive = true;
    strcopy(g_sVoteGameMode, sizeof(g_sVoteGameMode), gamemode);
    strcopy(g_sVoteSubGroup, sizeof(g_sVoteSubGroup), subgroup);
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
        CPrintToChatAll("%t", "Map Voting Cooldown", cooldownTime);
    }
    
    CreateTimer(1.0, Timer_UpdateCooldownHUD, _, TIMER_REPEAT);
}

void ExecutePendingVote(VoteType voteType, const char[] gamemode, const char[] subgroup, int initiator)
{
    switch (voteType)
    {
        case VOTE_TYPE_GROUP:
        {
            StartGameModeVote(initiator, false);
        }
        case VOTE_TYPE_SUBGROUP:
        {
            StartSubGroupVote(initiator, gamemode);
        }
        case VOTE_TYPE_MAP:
        {
            StartMapVote(initiator, gamemode);
        }
        case VOTE_TYPE_SUBGROUP_MAP:
        {
            StartSubGroupMapVote(initiator, gamemode, subgroup);
        }
    }
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
// //    Assistants    //
// //                  //
// //////////////////////

// Assistants

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

void UpdateCurrentGameMode(const char[] map)
{
    ArrayList gameModes = GetGameModesList();
    
    for(int i = 0; i < gameModes.Length; i++)
    {
        GameModeConfig config;
        gameModes.GetArray(i, config);
        
        for (int j = 0; j < config.subGroups.Length; j++)
        {
            SubGroupConfig subConfig;
            config.subGroups.GetArray(j, subConfig);
            
            if(subConfig.maps.FindString(map) != -1)
            {
                char temp[128];
                Format(temp, sizeof(temp), "%s/%s", config.name, subConfig.name);
                strcopy(g_sCurrentGameMode, sizeof(g_sCurrentGameMode), temp);
                return;
            }
        }
        
        if(config.maps.FindString(map) != -1)
        {
            strcopy(g_sCurrentGameMode, sizeof(g_sCurrentGameMode), config.name);
            return;
        }
    }
    
    g_sCurrentGameMode[0] = '\0';
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

int FindGameModeForMap(const char[] map)
{
    ArrayList gameModes = GetGameModesList();
    for (int i = 0; i < gameModes.Length; i++)
    {
        GameModeConfig config;
        gameModes.GetArray(i, config);
        if (config.maps.FindString(map) != -1)
        {
            return i;
        }
    }
    return -1;
}

float GetRemainingTime(int timerIndex)
{
    if(timerIndex < 0 || timerIndex >= sizeof(g_hRtvTimers)) return 0.0;
    if(g_hRtvTimers[timerIndex] == INVALID_HANDLE) return 0.0;
    
    float elapsed = GetEngineTime() - g_fRtvTimerStart[timerIndex];
    float remaining = g_fRtvTimerDuration[timerIndex] - elapsed;
    return remaining > 0.0 ? remaining : 0.0;
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
    
    if (!IsCurrentlyAvailableByTime(gamemode)) return false;
    
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
    
    if (!IsCurrentlyAvailableByTime(gamemode)) return false;
    
    return true;
}

stock bool IsTimeAllowed(int minTime, int maxTime)
{
    if (minTime == -1 && maxTime == -1)
    {
        return true;
    }

    char sCurrentTime[5];
    FormatTime(sCurrentTime, sizeof(sCurrentTime), "%H%M");
    int iCurrentTime = StringToInt(sCurrentTime);

    if (minTime != -1 && maxTime != -1)
    {
        if (minTime <= maxTime)
        {
            return iCurrentTime >= minTime && iCurrentTime <= maxTime;
        }
        else
        {
            return iCurrentTime >= minTime || iCurrentTime <= maxTime;
        }
    }
    else if (minTime != -1)
    {
        return iCurrentTime >= minTime;
    }
    else // maxTime != -1
    {
        return iCurrentTime <= maxTime;
    }
}

stock bool IsCurrentlyAvailableByTime(const char[] group, const char[] subgroup = "", const char[] map = "")
{
    char buffer[8];
    int minTime = -1, maxTime = -1;

    KeyValues kv;
    if (strlen(map) > 0)
    {
        if (strlen(subgroup) > 0)
        {
            kv = GetSubGroupMapKv(group, subgroup, map);
        }
        else
        {
            kv = GetMapKv(group, map);
        }

        if (kv != null)
        {
            kv.GetString("mintime", buffer, sizeof(buffer));
            if (buffer[0] != '\0') minTime = StringToInt(buffer);

            kv.GetString("maxtime", buffer, sizeof(buffer));
            if (buffer[0] != '\0') maxTime = StringToInt(buffer);
            
            delete kv;

            if (minTime != -1 || maxTime != -1)
            {
                return IsTimeAllowed(minTime, maxTime);
            }
        }
    }

    if (strlen(subgroup) > 0)
    {
        int groupIndex = FindGameModeIndex(group);
        if (groupIndex != -1)
        {
            int subIndex = FindSubGroupIndex(group, subgroup);
            if (subIndex != -1)
            {
                GameModeConfig config;
                GetGameModesList().GetArray(groupIndex, config);
                SubGroupConfig subConfig;
                config.subGroups.GetArray(subIndex, subConfig);
                
                if (subConfig.mintime != -1 || subConfig.maxtime != -1)
                {
                    return IsTimeAllowed(subConfig.mintime, subConfig.maxtime);
                }
            }
        }
    }

    int groupIndex = FindGameModeIndex(group);
    if (groupIndex != -1)
    {
        GameModeConfig config;
        GetGameModesList().GetArray(groupIndex, config);
        if (config.mintime != -1 || config.maxtime != -1)
        {
            return IsTimeAllowed(config.mintime, config.maxtime);
        }
    }

    return true;
}

bool CanExtendMap()
{
    ConVar timelimit = FindConVar("mp_timelimit");
    ConVar maxrounds = FindConVar("mp_maxrounds");
    ConVar winlimit = FindConVar("mp_winlimit");
    ConVar fraglimit = FindConVar("mp_fraglimit");
    
    return (timelimit != null && timelimit.FloatValue > 0.0) || (maxrounds != null && maxrounds.IntValue > 0) || (winlimit != null && winlimit.IntValue > 0) || (fraglimit != null && fraglimit.IntValue > 0);
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

int FindSubGroupIndex(const char[] gamemode, const char[] subgroup)
{
    int gamemodeIndex = FindGameModeIndex(gamemode);
    if (gamemodeIndex == -1) return -1;

    GameModeConfig config;
    ArrayList list = GetGameModesList();
    list.GetArray(gamemodeIndex, config);

    for (int i = 0; i < config.subGroups.Length; i++)
    {
        SubGroupConfig subConfig;
        config.subGroups.GetArray(i, subConfig);
        if (StrEqual(subConfig.name, subgroup))
            return i;
    }
    return -1;
}

bool HasSubGroups(const char[] gamemode)
{
    int index = FindGameModeIndex(gamemode);
    if (index == -1) return false;

    GameModeConfig config;
    ArrayList list = GetGameModesList();
    list.GetArray(index, config);
    
    return (config.subGroups != null && config.subGroups.Length > 0);
}

// //////////////////////
// //                  //
// //    KV SECTION    //
// //                  //
// //////////////////////

// KV Section

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

KeyValues GetSubGroupMapKv(const char[] gamemode, const char[] subgroup, const char[] mapname)
{
    KeyValues kv = new KeyValues("");
    
    if (g_kvGameModes.JumpToKey(gamemode) && g_kvGameModes.JumpToKey("subgroup") && g_kvGameModes.JumpToKey(subgroup) && g_kvGameModes.JumpToKey("maps"))
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
        g_kvGameModes.GoBack();
        g_kvGameModes.GoBack();
    }
    
    g_kvGameModes.Rewind();
    return kv;
}

stock void GetMapDisplayNameEx(const char[] gamemode, const char[] map, char[] display, int displayLen, const char[] subgroup = "")
{
    if (gamemode[0] != '\0')
    {
        if (subgroup[0] != '\0')
        {
            KeyValues subKv = GetSubGroupMapKv(gamemode, subgroup, map);
            if (subKv != null)
            {
                char customDisplay[256];
                subKv.GetString("display", customDisplay, sizeof(customDisplay), "");
                delete subKv;
                if (customDisplay[0] != '\0') 
                {
                    strcopy(display, displayLen, customDisplay);
                    return;
                }
            }
        }

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
    else
    {
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

            for (int j = 0; j < config.subGroups.Length; j++)
            {
                SubGroupConfig subConfig;
                config.subGroups.GetArray(j, subConfig);

                if (subConfig.maps.FindString(map) != -1)
                {
                    KeyValues subKv = GetSubGroupMapKv(config.name, subConfig.name, map);
                    if (subKv != null)
                    {
                        char customDisplay[256];
                        subKv.GetString("display", customDisplay, sizeof(customDisplay), "");
                        delete subKv;
                        if (customDisplay[0] != '\0') 
                        {
                            strcopy(display, displayLen, customDisplay);
                            return;
                        }
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
	
    for (int i = 0; i <= MAXPLAYERS; i++)
    {
        if (g_PlayerNominations[i] != null)
        {
            delete g_PlayerNominations[i];
        }
    }
    
    if (g_LastCountdownValues != null)
    {
        delete g_LastCountdownValues;
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