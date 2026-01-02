/*****************************************************************************
                        Multi Mode End Vote Plugin
******************************************************************************/

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <multimode>
#include <multimode/base>
#include <multimode/utils>
#include <morecolors>
#include <sdktools>

public Plugin myinfo = 
{
    name = "[MMC] MultiMode End Vote",
    author = "Oppressive Territory",
    description = "End vote system for MultiMode Core",
    version = PLUGIN_VERSION,
    url = ""
}

// ConVars
ConVar g_Cvar_EndVoteDebug;
ConVar g_Cvar_EndVoteLogs;
ConVar g_Cvar_EndVoteMin;
ConVar g_Cvar_EndVoteRounds;
ConVar g_Cvar_EndVoteFrags;
ConVar g_Cvar_EndVoteOnRoundEnd;
ConVar g_Cvar_EndVoteMethod;
ConVar g_hCvarTimeLimit;

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
bool g_bEndVoteTriggered = false;
bool g_bEndVotePending = false;

// Handle Section
Handle g_hEndVoteTimer = INVALID_HANDLE;

// Int Section
int g_iMapStartTime;

Handle g_hCountdownPlugin = null;

public void OnPluginStart() 
{
    // ConVars
    g_Cvar_EndVoteDebug = CreateConVar("multimode_endvote_debug", "0", "Enable/disable debug logging for end vote", _, true, 0.0, true, 1.0);
    g_Cvar_EndVoteLogs = CreateConVar("multimode_endvote_logs", "1", "Enable/disable logging for end vote", _, true, 0.0, true, 1.0);
    g_Cvar_EndVoteMin = CreateConVar("multimode_endvote_min", "5", "Minutes remaining before map ends to trigger vote (0 = disabled)", _, true, 0.0);
    g_Cvar_EndVoteRounds = CreateConVar("multimode_endvote_rounds", "2", "Rounds remaining before map ends to trigger vote (0 = disabled)", _, true, 0.0);
    g_Cvar_EndVoteFrags = CreateConVar("multimode_endvote_frags", "10", "Frags remaining before map ends to trigger vote (0 = disabled)", _, true, 0.0);
    g_Cvar_EndVoteOnRoundEnd = CreateConVar("multimode_endvote_onroundend", "0", "Wait for round end before starting vote", _, true, 0.0, true, 1.0);
    g_Cvar_EndVoteMethod = CreateConVar("multimode_endvote_method", "1", "Vote method for end vote: 1 = Groups then Maps, 2 = Groups only (random map), 3 = Maps only", _, true, 1.0, true, 3.0);
    g_hCvarTimeLimit = FindConVar("mp_timelimit");
    
    g_Cvar_VoteTime = CreateConVar("multimode_endvote_vote_time", "20", "Vote duration in seconds");
    g_Cvar_VoteSorted = CreateConVar("multimode_endvote_vote_sorted", "1", "Sorting mode for vote items: 0= Alphabetical, 1= Random, 2= Map Cycle Order", _, true, 0.0, true, 2.0);
    g_Cvar_VoteGroupExclude = CreateConVar("multimode_endvote_groupexclude", "0", "Number of recently played gamemodes to exclude from normal votes (0= Disabled)");
    g_Cvar_VoteMapExclude = CreateConVar("multimode_endvote_mapexclude", "2", "Number of recently played maps to exclude from normal votes (0= Disabled)");
    g_Cvar_VoteSounds = CreateConVar("multimode_endvote_votesounds", "1", "Enables/disables voting and automatic download sounds.", 0, true, 0.0, true, 1.0);
    g_Cvar_VoteOpenSound = CreateConVar("multimode_endvote_voteopensound", "votemap/vtst.wav", "Sound played when starting a vote");
    g_Cvar_VoteCloseSound = CreateConVar("multimode_endvote_voteclosesound", "votemap/vtend.wav", "Sound played when a vote ends");
    g_Cvar_Runoff = CreateConVar("multimode_endvote_runoff", "1", "Enable runoff system, voting for ties or if no option reaches the threshold.", _, true, 0.0, true, 1.0);
    g_Cvar_RunoffThreshold = CreateConVar("multimode_endvote_runoff_threshold", "0.6", "Minimum percentage of votes an option needs to win directly (0.0 to disable threshold check.).", _, true, 0.0, true, 1.0);
    g_Cvar_RunoffVoteFailed = CreateConVar("multimode_endvote_runoff_votefailed", "0", "What to do if a runoff vote also fails: 1= Do Nothing, 0= Pick the first option from the runoff.", _, true, 0.0, true, 1.0);
    g_Cvar_RunoffInVoteLimit = CreateConVar("multimode_endvote_runoff_invotelimit", "3", "Maximum number of items to include in a runoff vote.", _, true, 2.0);
    g_Cvar_RunoffVoteLimit = CreateConVar("multimode_endvote_runoff_votelimit", "3", "Maximum number of runoff votes allowed per map to prevent infinite loops.", _, true, 1.0);
    g_Cvar_RunoffVoteOpenSound = CreateConVar("multimode_endvote_runoff_voteopensound", "votemap/vtst.wav", "Sound played when starting a runoff vote.");
    g_Cvar_RunoffVoteCloseSound = CreateConVar("multimode_endvote_runoff_voteclosesound", "votemap/vtend.wav", "Sound played when a runoff vote ends.");
    g_Cvar_ExtendVote = CreateConVar("multimode_endvote_extendvote", "1", "Shows the option to extend in normal votes");
    g_Cvar_ExtendTimeStep = CreateConVar("multimode_endvote_extendtimestep", "6", "Amount of time to extend the time limit when \"Extend Map\" is selected.");
    g_Cvar_ExtendFragStep = CreateConVar("multimode_endvote_extendfragstep", "10", "Amount of frag limit to extend when \"Extend Map\" is selected.");
    g_Cvar_ExtendRoundStep = CreateConVar("multimode_endvote_extendroundstep", "3", "Amount of round limit to extend when \"Extend Map\" is selected.");
    
    if (g_hCvarTimeLimit == null)
    {
        LogError("[Multimode End Vote] Failed to find mp_timelimit ConVar. Time-based end vote may not work correctly.");
    }
    
    HookEvent("round_end", Event_RoundEnd);
    HookEventEx("game_round_end", Event_RoundEnd);
    HookEventEx("teamplay_win_panel", Event_RoundEnd);
    HookEventEx("arena_win_panel", Event_RoundEnd);
    HookEventEx("game_round_win", Event_RoundEnd);
    HookEventEx("round_win", Event_RoundEnd);
    HookEventEx("game_end", Event_RoundEnd);
    HookEventEx("game_round_restart", Event_RoundEnd);
    
    g_hCountdownPlugin = FindPluginByFile("multimode_countdown.smx");
    
    AutoExecConfig(true, "multimode_endvote");
}

public void OnMapStart()
{
    g_iMapStartTime = GetTime();
    g_bEndVoteTriggered = false;
    g_bEndVotePending = false;
    
    if (g_hEndVoteTimer != INVALID_HANDLE)
    {
        KillTimer(g_hEndVoteTimer);
        g_hEndVoteTimer = INVALID_HANDLE;
    }
    
    CreateTimer(5.0, Timer_StartEndVote);
}

public void OnMapEnd()
{
    if (g_hEndVoteTimer != INVALID_HANDLE)
    {
        KillTimer(g_hEndVoteTimer);
        g_hEndVoteTimer = INVALID_HANDLE;
    }
}

public Action Timer_StartEndVote(Handle timer)
{
    if (g_hEndVoteTimer == INVALID_HANDLE) 
    {
        g_hEndVoteTimer = CreateTimer(1.0, Timer_CheckEndVote, _, TIMER_REPEAT);
    }
    return Plugin_Stop;
}

public Action Timer_CheckEndVote(Handle timer)
{
    int playerCount = GetRealClientCount();
    if (playerCount < 1)
    {
        if (g_Cvar_EndVoteDebug.BoolValue)
            MMC_WriteToLogFile(g_Cvar_EndVoteLogs, "[MultiMode End Vote] No players on the server, end vote check ignored.");
        return Plugin_Continue;
    }

    if (MultiMode_IsVoteActive() || g_bEndVoteTriggered || MultiMode_IsCooldownActive() || MultiMode_IsVoteCompleted())
    {
        if (g_Cvar_EndVoteDebug.BoolValue) 
            MMC_WriteToLogFile(g_Cvar_EndVoteLogs, "[MultiMode End Vote] Verification skipped: System disabled/voting active/triggered/cooldown active");
        return Plugin_Continue;
    }

    bool bMinEnabled = (g_Cvar_EndVoteMin.IntValue > 0);
    bool bRoundsEnabled = (g_Cvar_EndVoteRounds.IntValue > 0);
    bool bFragsEnabled = (g_Cvar_EndVoteFrags.IntValue > 0);
    
    if (!bMinEnabled && !bRoundsEnabled && !bFragsEnabled)
    {
        if (g_Cvar_EndVoteDebug.BoolValue) 
            MMC_WriteToLogFile(g_Cvar_EndVoteLogs, "[MultiMode End Vote] No conditions enabled, stopping timer");
        return Plugin_Stop;
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
                CallCountdown("TimeLeft", timeUntilEndVote);
            }

            if (timeleft <= iTrigger)
            {
                if (g_Cvar_EndVoteDebug.BoolValue) 
                    MMC_WriteToLogFile(g_Cvar_EndVoteLogs, "[MultiMode End Vote] Triggered! Starting vote... (Remaining: %ds <= Trigger: %ds)", timeleft, iTrigger);
					
                PerformEndVote();
                return Plugin_Stop;
            }
        }
        else
        {
            int currentTime = GetTime();
            int elapsed = currentTime - g_iMapStartTime;
            float currentTimeLimit = (g_hCvarTimeLimit != null) ? g_hCvarTimeLimit.FloatValue : 0.0;
            int totalTimeLimit = RoundToFloor(currentTimeLimit * 60.0); 
            int iTimeLeft = totalTimeLimit - elapsed;

            if (iTimeLeft < 0) 
                iTimeLeft = 0;

            if (g_Cvar_EndVoteDebug.BoolValue)
                MMC_WriteToLogFile(g_Cvar_EndVoteLogs, "[MultiMode End Vote] Fallback calculation: TimeLimit=%.1fmin | Elapsed=%dmin | Remainder=%dmin", currentTimeLimit, elapsed/60, iTimeLeft/60);

            int timeUntilEndVote = iTimeLeft - iTrigger;
            if (timeUntilEndVote >= 0)
            {
                CallCountdown("TimeLeft", timeUntilEndVote);
            }

            if (iTimeLeft <= iTrigger)
            {
                if (g_Cvar_EndVoteDebug.BoolValue) 
                    MMC_WriteToLogFile(g_Cvar_EndVoteLogs, "[MultiMode End Vote] Fallback triggered! Starting vote... (Remaining: %ds <= Trigger: %ds)", iTimeLeft, iTrigger);

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
            int team2Score = GetTeamScore(2);
            int team3Score = GetTeamScore(3);
            int highestScore = (team2Score > team3Score) ? team2Score : team3Score;
            roundsRemaining = winLimit.IntValue - highestScore;
        }
        
        if (roundsRemaining > 0)
        {
            int untilVote = roundsRemaining - g_Cvar_EndVoteRounds.IntValue;
        
            if (untilVote >= 0)
            {
                CallCountdown("Rounds", untilVote);
            }

            if (untilVote <= 0)
            {
                PerformEndVote();
                return Plugin_Stop;
            }
        }
        else if (roundsRemaining == 0)
        {
            PerformEndVote();
            return Plugin_Stop;
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
                    if (frags > maxFrags) 
                        maxFrags = frags;
                }
            }
            
            int fragsRemaining = fragLimit.IntValue - maxFrags;
            
            if (fragsRemaining > 0)
            {
                int untilVoteFrags = fragsRemaining - g_Cvar_EndVoteFrags.IntValue;

                if (untilVoteFrags >= 0)
                {
                    CallCountdown("Frags", untilVoteFrags);
                }

                if (untilVoteFrags <= 0)
                {
                    PerformEndVote();
                    return Plugin_Stop;
                }
            }
            else if (fragsRemaining <= 0)
            {
                PerformEndVote();
                return Plugin_Stop;
            }
        }
    }
    
    return Plugin_Continue;
}

void PerformEndVote()
{
    if (g_Cvar_EndVoteDebug.BoolValue) 
        MMC_WriteToLogFile(g_Cvar_EndVoteLogs, "[MultiMode End Vote] Triggered! Starting vote...");
    
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
    
    int endType = g_Cvar_EndVoteMethod.IntValue;
    if (endType < 1) endType = 1;
    else if (endType > 3) endType = 3;
    
    TimingMode timing = view_as<TimingMode>(endType - 1);
    MultimodeMethodType voteType;
    
    int method = g_Cvar_EndVoteMethod.IntValue;
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
        
    if (g_Cvar_EndVoteDebug.BoolValue)
        MMC_WriteToLogFile(g_Cvar_EndVoteLogs, "[MultiMode End Vote] Vote type selected: %d (Timing: %d)", endType, timing);
    
    char mapcycle[256];
    strcopy(mapcycle, sizeof(mapcycle), "");
    
    int emptyClients[66];
    for (int i = 0; i < 66; i++) emptyClients[i] = 0;
    
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
    
    Multimode_StartVote(
        "endvote",
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
        0
    );
}

public void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
    if (g_bEndVotePending)
    {
        g_bEndVotePending = false;
        
        int endType = g_Cvar_EndVoteMethod.IntValue;
        if (endType < 1) endType = 1;
        else if (endType > 3) endType = 3;
        
        TimingMode timing = view_as<TimingMode>(endType - 1);
        MultimodeMethodType voteType;
        
        int method = g_Cvar_EndVoteMethod.IntValue;
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
        
        char mapcycle[256];
        strcopy(mapcycle, sizeof(mapcycle), "");
        
        int emptyClients[66];
        for (int i = 0; i < 66; i++) emptyClients[i] = 0;
        
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
        
        Multimode_StartVote(
            "endvote",
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
            0
        );
    }
}

void CallCountdown(const char[] type, int value)
{
    if (g_hCountdownPlugin != null && GetPluginStatus(g_hCountdownPlugin) == Plugin_Running)
    {
        Function func = GetFunctionByName(g_hCountdownPlugin, "Countdown_ShowMessage");
        if (func != INVALID_FUNCTION)
        {
            Call_StartFunction(g_hCountdownPlugin, func);
            Call_PushString(type);
            Call_PushCell(value);
            Call_Finish();
        }
    }
}