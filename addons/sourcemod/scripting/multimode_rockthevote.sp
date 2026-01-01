/*****************************************************************************
                        Multi Mode Rock The Vote Plugin
******************************************************************************/

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <morecolors>
#include <multimode/base>
#include <multimode>

public Plugin myinfo = 
{
    name = "[MMC] MultiMode Rock The Vote",
    author = "Oppressive Territory",
    description = "Rock The Vote system for MultiMode Core",
    version = PLUGIN_VERSION,
    url = ""
}

// ConVars
ConVar g_Cvar_RtvMinPlayers;
ConVar g_Cvar_RtvRatio;
ConVar g_Cvar_RtvFirstDelay;
ConVar g_Cvar_RtvDelay;
ConVar g_Cvar_RtvType;
ConVar g_Cvar_RtvMethod;
ConVar g_Cvar_MapCycleFile;

// Vote Configuration ConVars
ConVar g_Cvar_VoteTime;
ConVar g_Cvar_VoteSorted;
ConVar g_Cvar_VoteGroupExclude;
ConVar g_Cvar_VoteMapExclude;
ConVar g_Cvar_VoteSounds;
ConVar g_Cvar_VoteOpenSound;
ConVar g_Cvar_VoteCloseSound;
ConVar g_Cvar_Runoff;
ConVar g_Cvar_RunoffThreshold;
ConVar g_Cvar_RunoffVoteFailed;
ConVar g_Cvar_RunoffInVoteLimit;
ConVar g_Cvar_RunoffVoteLimit;
ConVar g_Cvar_RunoffVoteOpenSound;
ConVar g_Cvar_RunoffVoteCloseSound;
ConVar g_Cvar_ExtendVote;
ConVar g_Cvar_ExtendTimeStep;
ConVar g_Cvar_ExtendFragStep;
ConVar g_Cvar_ExtendRoundStep;

// Bool Section
bool g_bRtvCooldown = false;
bool g_bRtvDisabled = false;
bool g_bRtvInitialDelay = true;
bool g_bRtvVoted[MAXPLAYERS+1];

// Int Section
int g_iRtvVotes = 0;

// Handle Section
Handle g_hRtvFirstDelayTimer = INVALID_HANDLE;
Handle g_hRtvTimers[2];

// Float Section
float g_fRtvTimerDuration[2];
float g_fRtvTimerStart[2];

public void OnPluginStart() 
{
    LoadTranslations("multimode_voter.phrases");
    
    // Reg Console Commands
    RegConsoleCmd("sm_rtv", Command_RTV, "Rock The Vote");
    RegConsoleCmd("sm_rockthevote", Command_RTV, "Rock The Vote (ALT)");
    
    AddCommandListener(OnPlayerChat, "say");
    AddCommandListener(OnPlayerChat, "say2");
    AddCommandListener(OnPlayerChat, "say_team");
    
    // Convars
    g_Cvar_MapCycleFile = FindConVar("multimode_mapcycle");
    g_Cvar_RtvMinPlayers = CreateConVar("multimode_rtv_min", "1", "Minimum number of players required to start RTV", _, true, 1.0);
    g_Cvar_RtvRatio = CreateConVar("multimode_rtv_ratio", "0.8", "Ratio of players needed to start RTV", _, true, 0.05, true, 1.0);
    g_Cvar_RtvFirstDelay = CreateConVar("multimode_rtvfirstdelay", "60", "Initial delay after map loads to allow RTV");
    g_Cvar_RtvDelay = CreateConVar("multimode_rtvdelay", "120", "Delay after a vote to allow new RTV");
    g_Cvar_RtvType = CreateConVar("multimode_rtvtype", "3", "Voting Type for RTV: 1 - Next Map, 2 - Next Round, 3 - Instant", _, true, 1.0, true, 3.0);
    g_Cvar_RtvMethod = CreateConVar("multimode_rtv_method", "1", "Vote method for RTV: 1 = Groups then Maps, 2 = Groups only (random map), 3 = Maps only", _, true, 1.0, true, 3.0);
    
    g_Cvar_VoteTime = CreateConVar("multimode_rtv_vote_time", "20", "Vote duration in seconds");
    g_Cvar_VoteSorted = CreateConVar("multimode_rtv_vote_sorted", "1", "Sorting mode for vote items: 0= Alphabetical, 1= Random, 2= Map Cycle Order", _, true, 0.0, true, 2.0);
    g_Cvar_VoteGroupExclude = CreateConVar("multimode_rtv_groupexclude", "0", "Number of recently played gamemodes to exclude from normal votes (0= Disabled)");
    g_Cvar_VoteMapExclude = CreateConVar("multimode_rtv_mapexclude", "2", "Number of recently played maps to exclude from normal votes (0= Disabled)");
    g_Cvar_VoteSounds = CreateConVar("multimode_rtv_votesounds", "1", "Enables/disables voting and automatic download sounds.", 0, true, 0.0, true, 1.0);
    g_Cvar_VoteOpenSound = CreateConVar("multimode_rtv_voteopensound", "votemap/vtst.wav", "Sound played when starting a vote");
    g_Cvar_VoteCloseSound = CreateConVar("multimode_rtv_voteclosesound", "votemap/vtend.wav", "Sound played when a vote ends");
    g_Cvar_Runoff = CreateConVar("multimode_rtv_runoff", "1", "Enable runoff system, voting for ties or if no option reaches the threshold.", _, true, 0.0, true, 1.0);
    g_Cvar_RunoffThreshold = CreateConVar("multimode_rtv_runoff_threshold", "0.6", "Minimum percentage of votes an option needs to win directly (0.0 to disable threshold check.).", _, true, 0.0, true, 1.0);
    g_Cvar_RunoffVoteFailed = CreateConVar("multimode_rtv_runoff_votefailed", "0", "What to do if a runoff vote also fails: 1= Do Nothing, 0= Pick the first option from the runoff.", _, true, 0.0, true, 1.0);
    g_Cvar_RunoffInVoteLimit = CreateConVar("multimode_rtv_runoff_invotelimit", "3", "Maximum number of items to include in a runoff vote.", _, true, 2.0);
    g_Cvar_RunoffVoteLimit = CreateConVar("multimode_rtv_runoff_votelimit", "3", "Maximum number of runoff votes allowed per map to prevent infinite loops.", _, true, 1.0);
    g_Cvar_RunoffVoteOpenSound = CreateConVar("multimode_rtv_runoff_voteopensound", "votemap/vtst.wav", "Sound played when starting a runoff vote.");
    g_Cvar_RunoffVoteCloseSound = CreateConVar("multimode_rtv_runoff_voteclosesound", "votemap/vtend.wav", "Sound played when a runoff vote ends.");
    g_Cvar_ExtendVote = CreateConVar("multimode_rtv_extendvote", "1", "Shows the option to extend in normal votes");
    g_Cvar_ExtendTimeStep = CreateConVar("multimode_rtv_extendtimestep", "6", "Amount of time to extend the time limit when \"Extend Map\" is selected.");
    g_Cvar_ExtendFragStep = CreateConVar("multimode_rtv_extendfragstep", "10", "Amount of frag limit to extend when \"Extend Map\" is selected.");
    g_Cvar_ExtendRoundStep = CreateConVar("multimode_rtv_extendroundstep", "3", "Amount of round limit to extend when \"Extend Map\" is selected.");
    
    AutoExecConfig(true, "multimode_rockthevote");
    
    ResetRTV();
    
    float fFirstDelay = g_Cvar_RtvFirstDelay.FloatValue;
    if (fFirstDelay > 0.0)
    {
        g_bRtvInitialDelay = true;
        g_fRtvTimerStart[0] = GetEngineTime();
        g_fRtvTimerDuration[0] = fFirstDelay;
        g_hRtvFirstDelayTimer = CreateTimer(fFirstDelay, Timer_ResetFirstDelay, _, TIMER_FLAG_NO_MAPCHANGE);
    }
    else
    {
        g_bRtvInitialDelay = false;
    }
    
    HookEvent("player_disconnect", Event_PlayerDisconnect, EventHookMode_Pre);
}

public void OnMapStart()
{
    ResetRTV();

    float fFirstDelay = g_Cvar_RtvFirstDelay.FloatValue;
    if (fFirstDelay > 0.0)
    {
        g_bRtvInitialDelay = true;
        g_fRtvTimerStart[0] = GetEngineTime();
        g_fRtvTimerDuration[0] = fFirstDelay;
        
        if (g_hRtvFirstDelayTimer != INVALID_HANDLE)
        {
            if (IsValidHandle(g_hRtvFirstDelayTimer))
            {
                KillTimer(g_hRtvFirstDelayTimer);
            }
            g_hRtvFirstDelayTimer = INVALID_HANDLE;
        }
        g_hRtvFirstDelayTimer = CreateTimer(fFirstDelay, Timer_ResetFirstDelay, _, TIMER_FLAG_NO_MAPCHANGE);
    }
    else
    {
        g_bRtvInitialDelay = false;
    }
}

public void MultiMode_OnVoteEnd(const char[] group, const char[] subgroup, const char[] map, VoteEndReason reason)
{
    if (reason == VoteEnd_Extend)
    {
        StartRtvCooldown();
    }
    else if (reason == VoteEnd_Winner)
    {
        ResetRTVVotes();
        g_bRtvDisabled = true;
    }
}

public Action Event_PlayerDisconnect(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    if (client > 0 && client <= MaxClients)
    {
        if (g_bRtvVoted[client])
        {
            g_bRtvVoted[client] = false;
            g_iRtvVotes--;
            
            if (g_iRtvVotes < 0)
                g_iRtvVotes = 0;
        }
        
        CheckRtvThreshold();
    }
    
    return Plugin_Continue;
}

public Action Timer_ResetFirstDelay(Handle timer)
{
    g_bRtvInitialDelay = false;
    g_hRtvFirstDelayTimer = INVALID_HANDLE;
    return Plugin_Stop;
}

public Action Timer_ResetCooldown(Handle timer)
{
    g_bRtvCooldown = false;
    return Plugin_Stop;
}

public Action Command_RTV(int client, int args)
{
    if(MultiMode_IsVoteActive() || MultiMode_IsCooldownActive() || g_bRtvDisabled) 
    {
        CPrintToChat(client, "%t", "RTV System Disabled");
        return Plugin_Handled;
    }
    
    if(g_bRtvInitialDelay) 
    {
        float fRemaining = GetRemainingTime(0);
        if (fRemaining <= 0.0)
        {
            g_bRtvInitialDelay = false;
        }
        else
        {
            int iRemaining = RoundToCeil(fRemaining);
            if (iRemaining < 1) iRemaining = 1;
            CPrintToChat(client, "%t", "RTV Wait", iRemaining);
            return Plugin_Handled;
        }
    }
    
    if(g_bRtvCooldown) 
    {
        float fRemaining = GetRemainingTime(1);
        if (fRemaining <= 0.0)
        {
            g_bRtvCooldown = false;
        }
        else
        {
            int iRemaining = RoundToCeil(fRemaining);
            if (iRemaining < 1) iRemaining = 1;
            CPrintToChat(client, "%t", "RTV Wait Again", iRemaining);
            return Plugin_Handled;
        }
    }
    
    if(g_bRtvVoted[client]) 
    {
        CPrintToChat(client, "%t", "RTV Already Voted");
        return Plugin_Handled;
    }
    
    int iPlayers = GetRealClientCount();
    float ratio = g_Cvar_RtvRatio.FloatValue;
    int minRequired = g_Cvar_RtvMinPlayers.IntValue;
    int iRequired = RoundToNearest(float(iPlayers) * ratio);
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
        
        TimingMode timing = view_as<TimingMode>(rtvType - 1);
        
        char mapcycle[PLATFORM_MAX_PATH];
        if (g_Cvar_MapCycleFile != null)
        {
            g_Cvar_MapCycleFile.GetString(mapcycle, sizeof(mapcycle));
        }
        else
        {
            strcopy(mapcycle, sizeof(mapcycle), "mmc_mapcycle.txt");
        }
        
        int emptyClients[MAXPLAYERS + 1];
        char startSound[256] = "";
        char endSound[256] = "";
        char runoffStartSound[256] = "";
        char runoffEndSound[256] = "";
        
        if (g_Cvar_VoteSounds.BoolValue)
        {
            g_Cvar_VoteOpenSound.GetString(startSound, sizeof(startSound));
            g_Cvar_VoteCloseSound.GetString(endSound, sizeof(endSound));
            g_Cvar_RunoffVoteOpenSound.GetString(runoffStartSound, sizeof(runoffStartSound));
            g_Cvar_RunoffVoteCloseSound.GetString(runoffEndSound, sizeof(runoffEndSound));
        }
        
        MultimodeRunoffFailAction runoffFailAction = g_Cvar_RunoffVoteFailed.IntValue == 1 ? RUNOFF_FAIL_DO_NOTHING : RUNOFF_FAIL_PICK_FIRST;
        MultimodeVoteSorted sorted = view_as<MultimodeVoteSorted>(g_Cvar_VoteSorted.IntValue);
        
        int groupexclude = g_Cvar_VoteGroupExclude.IntValue;
        int mapexclude = g_Cvar_VoteMapExclude.IntValue;
        if (groupexclude < 0) groupexclude = -1;
        if (mapexclude < 0) mapexclude = -1;
        
        int maxRunoffs = g_Cvar_Runoff.BoolValue ? g_Cvar_RunoffVoteLimit.IntValue : 0;
        int maxRunoffInVote = g_Cvar_Runoff.BoolValue ? g_Cvar_RunoffInVoteLimit.IntValue : 0;
        float threshold = g_Cvar_RunoffThreshold.FloatValue;
        
        MultimodeMethodType voteType;
        int method = g_Cvar_RtvMethod.IntValue;
        if (method == 3)
        {
            voteType = VOTE_TYPE_MAPS_ONLY;
        }
        else if (method == 2)
        {
            voteType = VOTE_TYPE_GROUPS_ONLY;
        }
        else
        {
            voteType = VOTE_TYPE_GROUPS_THEN_MAPS;
        }
        
        Multimode_StartVote(
            "rtv",
            mapcycle,
            voteType,
            g_Cvar_VoteTime.IntValue,
            timing,
            startSound,
            endSound,
            g_Cvar_ExtendVote.BoolValue,
            g_Cvar_ExtendTimeStep.IntValue,
            g_Cvar_ExtendFragStep.IntValue,
            g_Cvar_ExtendRoundStep.IntValue,
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
            emptyClients,
            0,
            false
        );
        
        ResetRTV();
    }
    
    return Plugin_Handled;
}

void ResetRTV()
{
    g_iRtvVotes = 0;
    g_bRtvDisabled = false;
    for(int i = 1; i <= MaxClients; i++) {
        g_bRtvVoted[i] = false;
    }
    
    for (int i = 0; i < sizeof(g_hRtvTimers); i++)
    {
        if (g_hRtvTimers[i] != INVALID_HANDLE)
        {
            if (IsValidHandle(g_hRtvTimers[i]))
            {
                KillTimer(g_hRtvTimers[i]);
            }
            g_hRtvTimers[i] = INVALID_HANDLE;
        }
    }
}

void ResetRTVVotes()
{
    g_iRtvVotes = 0;
    for(int i = 1; i <= MaxClients; i++) {
        g_bRtvVoted[i] = false;
    }
    
    for (int i = 0; i < sizeof(g_hRtvTimers); i++)
    {
        if (g_hRtvTimers[i] != INVALID_HANDLE)
        {
            if (IsValidHandle(g_hRtvTimers[i]))
            {
                KillTimer(g_hRtvTimers[i]);
            }
            g_hRtvTimers[i] = INVALID_HANDLE;
        }
    }
}

void StartRtvCooldown()
{
    float fDelay = g_Cvar_RtvDelay.FloatValue;
    if(fDelay > 0.0) {
        g_bRtvCooldown = true;
        g_fRtvTimerStart[1] = GetEngineTime();
        g_fRtvTimerDuration[1] = fDelay;

        if (g_hRtvTimers[1] != INVALID_HANDLE)
        {
            if (IsValidHandle(g_hRtvTimers[1]))
            {
                KillTimer(g_hRtvTimers[1]);
            }
            g_hRtvTimers[1] = INVALID_HANDLE;
        }
        
        g_hRtvTimers[1] = CreateTimer(fDelay, Timer_ResetCooldown, _, TIMER_FLAG_NO_MAPCHANGE);
        
        CPrintToChatAll("%t", "RTV Next Available", RoundFloat(fDelay));
    }
}

void CheckRtvThreshold()
{
    if (g_bRtvDisabled)
        return;
    
    int iPlayers = GetRealClientCount();
    float ratio = g_Cvar_RtvRatio.FloatValue;
    int minRequired = g_Cvar_RtvMinPlayers.IntValue;

    int iRequired = RoundToNearest(float(iPlayers) * ratio);

    if (iRequired < minRequired)
    { 
        iRequired = minRequired;
    }
    
    if (!g_bRtvDisabled && g_iRtvVotes > 0 && g_iRtvVotes >= iRequired)
    {
        CPrintToChatAll("%t", "RTV Threshold Reached", g_iRtvVotes, iRequired); 
        
        int rtvType = g_Cvar_RtvType.IntValue;
        if(rtvType < 1) rtvType = 1;
        else if(rtvType > 3) rtvType = 3;
        
        TimingMode timing = view_as<TimingMode>(rtvType - 1);
        
        char mapcycle[PLATFORM_MAX_PATH];
        if (g_Cvar_MapCycleFile != null)
        {
            g_Cvar_MapCycleFile.GetString(mapcycle, sizeof(mapcycle));
        }
        else
        {
            strcopy(mapcycle, sizeof(mapcycle), "mmc_mapcycle.txt");
        }

        int emptyClients[MAXPLAYERS + 1];
        char startSound[256] = "";
        char endSound[256] = "";
        char runoffStartSound[256] = "";
        char runoffEndSound[256] = "";
        
        if (g_Cvar_VoteSounds.BoolValue)
        {
            g_Cvar_VoteOpenSound.GetString(startSound, sizeof(startSound));
            g_Cvar_VoteCloseSound.GetString(endSound, sizeof(endSound));
            g_Cvar_RunoffVoteOpenSound.GetString(runoffStartSound, sizeof(runoffStartSound));
            g_Cvar_RunoffVoteCloseSound.GetString(runoffEndSound, sizeof(runoffEndSound));
        }
        
        MultimodeRunoffFailAction runoffFailAction = g_Cvar_RunoffVoteFailed.IntValue == 1 ? RUNOFF_FAIL_DO_NOTHING : RUNOFF_FAIL_PICK_FIRST;
        MultimodeVoteSorted sorted = view_as<MultimodeVoteSorted>(g_Cvar_VoteSorted.IntValue);
        
        int groupexclude = g_Cvar_VoteGroupExclude.IntValue;
        int mapexclude = g_Cvar_VoteMapExclude.IntValue;
        if (groupexclude < 0) groupexclude = -1;
        if (mapexclude < 0) mapexclude = -1;
        
        int maxRunoffs = g_Cvar_Runoff.BoolValue ? g_Cvar_RunoffVoteLimit.IntValue : 0;
        int maxRunoffInVote = g_Cvar_Runoff.BoolValue ? g_Cvar_RunoffInVoteLimit.IntValue : 0;
        float threshold = g_Cvar_RunoffThreshold.FloatValue;
        
        MultimodeMethodType voteType;
        int method = g_Cvar_RtvMethod.IntValue;
        if (method == 3)
        {
            voteType = VOTE_TYPE_MAPS_ONLY;
        }
        else if (method == 2)
        {
            voteType = VOTE_TYPE_GROUPS_ONLY;
        }
        else
        {
            voteType = VOTE_TYPE_GROUPS_THEN_MAPS;
        }
        
        Multimode_StartVote(
            "rtv",
            mapcycle,
            voteType,
            g_Cvar_VoteTime.IntValue,
            timing,
            startSound,
            endSound,
            g_Cvar_ExtendVote.BoolValue,
            g_Cvar_ExtendTimeStep.IntValue,
            g_Cvar_ExtendFragStep.IntValue,
            g_Cvar_ExtendRoundStep.IntValue,
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
            emptyClients,
            0,
            false
        );
        
        ResetRTV();
    }
}

float GetRemainingTime(int timerIndex)
{
    if (timerIndex < 0 || timerIndex >= sizeof(g_fRtvTimerStart))
        return 0.0;
    
    float elapsed = GetEngineTime() - g_fRtvTimerStart[timerIndex];
    float remaining = g_fRtvTimerDuration[timerIndex] - elapsed;
    
    return (remaining > 0.0) ? remaining : 0.0;
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

    return Plugin_Continue;
}