#include <sourcemod>
#include <multimode>
#include <multimode/base>

public void OnPluginStart()
{
    RegConsoleCmd("sm_cancelvote_test", Command_CancelVoteTest, "Cancels the current MultiMode vote (if active).");
    RegConsoleCmd("sm_randommap_test", Command_RandomMapTest, "Gets a random map from MultiMode and prints it.");
    RegConsoleCmd("sm_isgroupnominated_test", Command_IsGroupNominatedTest, "Checks if a gamemode/subgroup is nominated.");
    RegConsoleCmd("sm_ismapnominated_test", Command_IsMapNominatedTest, "Checks if a map is nominated in a gamemode/subgroup.");
    RegConsoleCmd("sm_forcenominate_test", Command_NominateTest, "Test nomination system");
	RegConsoleCmd("sm_testvote", Command_TestVote, "Test advanced vote features with sounds");
}

public Action Command_TestVote(int client, int args)
{
    if (client == 0)
    {
        PrintToServer("[TestVote] This command can only be used by players.");
        return Plugin_Handled;
    }
    
    if (!IsClientInGame(client))
    {
        ReplyToCommand(client, "[TestVote] You must be in-game to use this command.");
        return Plugin_Handled;
    }
    
    char voteId[32];
    Format(voteId, sizeof(voteId), "testvote_%d_%d", client, GetTime());
    
    char startSound[128] = "buttons/button19.wav";
    char endSound[128] = "buttons/button5.wav";
    char runoffStartSound[128] = "buttons/button19.wav";
    char runoffEndSound[128] = "buttons/button5.wav";
    
    int clients[MAXPLAYERS + 1];
    int numClients = 0;
    clients[numClients++] = client;
    
    MultimodeMethodType voteType = VOTE_TYPE_GROUPS_THEN_MAPS;
    
    TimingMode timing = TIMING_NEXTMAP;

    MultimodeVoteSorted sorted = SORTED_RANDOM;
    
    MultimodeRunoffFailAction runoffFailAction = RUNOFF_FAIL_PICK_FIRST;
    
    PrintToChat(client, "[TestVote] Iniciando votação de teste com sons...");
    PrintToServer("[TestVote] Iniciando votação ID: %s", voteId);

    bool success = Multimode_StartVote(
        voteId,
        "",
        voteType,
        30,
        timing,
        startSound,
        endSound,
        true,
        10,
        15,
        5,
        0,
        0,
        true,
        0.5,
        2,
        2,
        runoffFailAction,
        runoffStartSound,
        runoffEndSound,
        sorted,
        clients,
        numClients,
        false
    );
    
    if (success)
    {
        PrintToChat(client, "[TestVote] Votação iniciada com sucesso! ID: %s", voteId);
        PrintToServer("[TestVote] Votação iniciada: ID %s, Client %d", voteId, client);
    }
    else
    {
        PrintToChat(client, "[TestVote] Falha ao iniciar a votação!");
        PrintToServer("[TestVote] Falha ao iniciar votação para cliente %d", client);
    }
    
    return Plugin_Handled;
}

public Action Command_CancelVoteTest(int client, int args)
{
    if (MultiMode_CanStopVote())
    {
        if (MultiMode_StopVote())
        {
            PrintToChatAll("[MultiMode Test] The current vote has been cancelled!");
            PrintToServer("[MultiMode Test] Vote cancelled by command.");
        }
        else
        {
            PrintToChat(client, "[MultiMode Test] No active vote to cancel!");
        }
    }
    else
    {
        PrintToChat(client, "[MultiMode Test] No vote can be cancelled right now!");
    }

    return Plugin_Handled;
}

public Action Command_RandomMapTest(int client, int args)
{
    char group[64] = "";
    char subgroup[64] = "";
    char map[64];

    if (args >= 1)
    {
        GetCmdArg(1, group, sizeof(group));
    }
    if (args >= 2)
    {
        GetCmdArg(2, subgroup, sizeof(subgroup));
    }

    if (MultiMode_GetRandomMap(group, sizeof(group), subgroup, sizeof(subgroup), map, sizeof(map)))
    {
        if (strlen(subgroup) > 0)
        {
            PrintToChatAll("[MultiMode Test] Random map selected: %s | Gamemode: %s/%s", map, group, subgroup);
            PrintToServer("[MultiMode Test] Random map test: %s | Gamemode: %s/%s", map, group, subgroup);
        }
        else
        {
            PrintToChatAll("[MultiMode Test] Random map selected: %s | Gamemode: %s", map, group);
            PrintToServer("[MultiMode Test] Random map test: %s | Gamemode: %s", map, group);
        }
    }
    else
    {
        PrintToChat(client, "[MultiMode Test] No map could be selected!");
    }

    return Plugin_Handled;
}

public Action Command_IsGroupNominatedTest(int client, int args)
{
    if (args < 1)
    {
        PrintToChat(client, "[MultiMode Test] Usage: sm_isgroupnominated_test <group> [subgroup]");
        return Plugin_Handled;
    }

    char group[64];
    char subgroup[64] = "";
    
    GetCmdArg(1, group, sizeof(group));
    if (args >= 2)
    {
        GetCmdArg(2, subgroup, sizeof(subgroup));
    }

    if (MultiMode_IsGroupNominated(group, subgroup))
    {
        if (strlen(subgroup) > 0)
        {
            PrintToChat(client, "[MultiMode Test] Gamemode '%s/%s' IS nominated!", group, subgroup);
        }
        else
        {
            PrintToChat(client, "[MultiMode Test] Gamemode '%s' IS nominated!", group);
        }
    }
    else
    {
        if (strlen(subgroup) > 0)
        {
            PrintToChat(client, "[MultiMode Test] Gamemode '%s/%s' is NOT nominated.", group, subgroup);
        }
        else
        {
            PrintToChat(client, "[MultiMode Test] Gamemode '%s' is NOT nominated.", group);
        }
    }

    return Plugin_Handled;
}

public Action Command_IsMapNominatedTest(int client, int args)
{
    if (args < 3)
    {
        PrintToChat(client, "[MultiMode Test] Usage: sm_ismapnominated_test <group> <subgroup> <map>");
        return Plugin_Handled;
    }

    char group[64], subgroup[64], map[64];
    GetCmdArg(1, group, sizeof(group));
    GetCmdArg(2, subgroup, sizeof(subgroup));
    GetCmdArg(3, map, sizeof(map));

    if (MultiMode_IsMapNominated(group, subgroup, map))
    {
        PrintToChat(client, "[MultiMode Test] Map '%s' in gamemode '%s/%s' IS nominated!", map, group, subgroup);
    }
    else
    {
        PrintToChat(client, "[MultiMode Test] Map '%s' in gamemode '%s/%s' is NOT nominated.", map, group, subgroup);
    }

    return Plugin_Handled;
}

public Action Command_StartVoteTest(int client, int args)
{
    bool adminVote = false;
    
    if (args >= 1)
    {
        char arg[8];
        GetCmdArg(1, arg, sizeof(arg));
        adminVote = (StringToInt(arg) != 0);
    }
    
    MultiMode_StartVote(client, adminVote);
    PrintToServer("[MultiMode Test] Vote started by %d (adminVote: %s)", client, adminVote ? "true" : "false");
    
    return Plugin_Handled;
}

public Action Command_NominateTest(int client, int args)
{
    if (args < 3)
    {
        PrintToChat(client, "[MultiMode Test] Usage: sm_nominate_test <group> <subgroup> <map>");
        return Plugin_Handled;
    }

    char group[64], subgroup[64], map[64];
    GetCmdArg(1, group, sizeof(group));
    GetCmdArg(2, subgroup, sizeof(subgroup));
    GetCmdArg(3, map, sizeof(map));

    if (MultiMode_Nominate(client, group, subgroup, map))
    {
        PrintToChat(client, "[MultiMode Test] Successfully nominated %s for %s/%s", map, group, subgroup);
    }
    else
    {
        PrintToChat(client, "[MultiMode Test] Failed to nominate %s for %s/%s", map, group, subgroup);
    }

    return Plugin_Handled;
}

// Updated forwards with new parameters
public void MultiMode_OnVoteStart(int initiator)
{
    char name[64];
    if (initiator > 0 && IsClientInGame(initiator))
    {
        GetClientName(initiator, name, sizeof(name));
        PrintToServer("[MultiMode Test] Vote started by player: %s (ID: %d)", name, initiator);
    }
    else
    {
        PrintToServer("[MultiMode Test] Automatic vote started by the system.");
    }
}

public void MultiMode_OnVoteStartEx(int initiator, int voteType, bool isRunoff)
{
    char name[64];
    char voteTypeStr[32];
    
    switch(voteType)
    {
        case 0: strcopy(voteTypeStr, sizeof(voteTypeStr), "GROUP");
        case 1: strcopy(voteTypeStr, sizeof(voteTypeStr), "SUBGROUP");
        case 2: strcopy(voteTypeStr, sizeof(voteTypeStr), "MAP");
        case 3: strcopy(voteTypeStr, sizeof(voteTypeStr), "SUBGROUP_MAP");
        default: strcopy(voteTypeStr, sizeof(voteTypeStr), "UNKNOWN");
    }
    
    if (initiator > 0 && IsClientInGame(initiator))
    {
        GetClientName(initiator, name, sizeof(name));
        PrintToServer("[MultiMode Test] Vote started (EX) by: %s (ID: %d) | Type: %s | Runoff: %s", 
                     name, initiator, voteTypeStr, isRunoff ? "Yes" : "No");
    }
    else
    {
        PrintToServer("[MultiMode Test] Automatic vote started (EX) | Type: %s | Runoff: %s", 
                     voteTypeStr, isRunoff ? "Yes" : "No");
    }
}

public void MultiMode_OnVoteEnd(const char[] group, const char[] subgroup, const char[] map, VoteEndReason reason)
{
    char reasonStr[32];
    switch(reason)
    {
        case VoteEnd_Winner: strcopy(reasonStr, sizeof(reasonStr), "Winner");
        case VoteEnd_Runoff: strcopy(reasonStr, sizeof(reasonStr), "Runoff");
        case VoteEnd_Extend: strcopy(reasonStr, sizeof(reasonStr), "Extend");
        case VoteEnd_Cancelled: strcopy(reasonStr, sizeof(reasonStr), "Cancelled");
        case VoteEnd_Failed: strcopy(reasonStr, sizeof(reasonStr), "Failed");
        default: strcopy(reasonStr, sizeof(reasonStr), "Unknown");
    }
    
    if (strlen(subgroup) > 0)
    {
        PrintToServer("[MultiMode Test] Vote ended! Chosen: %s/%s | Map: %s | Reason: %s", 
                     group, subgroup, map, reasonStr);
    }
    else
    {
        PrintToServer("[MultiMode Test] Vote ended! Chosen: %s | Map: %s | Reason: %s", 
                     group, map, reasonStr);
    }
}

public void MultiMode_OnGamemodeChanged(const char[] group, const char[] subgroup, const char[] map, int timing)
{
    char timingStr[32];
    switch(timing)
    {
        case 0: strcopy(timingStr, sizeof(timingStr), "Next map");
        case 1: strcopy(timingStr, sizeof(timingStr), "Next round");
        case 2: strcopy(timingStr, sizeof(timingStr), "Instant");
        default: strcopy(timingStr, sizeof(timingStr), "Unknown");
    }
    
    if (strlen(subgroup) > 0)
    {
        PrintToServer("[MultiMode Test] Gamemode changed to: %s/%s | Map: %s | Timing: %s", 
                     group, subgroup, map, timingStr);
    }
    else
    {
        PrintToServer("[MultiMode Test] Gamemode changed to: %s | Map: %s | Timing: %s", 
                     group, map, timingStr);
    }
}

public void MultiMode_OnGamemodeChangedVote(const char[] group, const char[] subgroup, const char[] map, int timing)
{
    char timingStr[32];
    switch(timing)
    {
        case 0: strcopy(timingStr, sizeof(timingStr), "Next map");
        case 1: strcopy(timingStr, sizeof(timingStr), "Next round");
        case 2: strcopy(timingStr, sizeof(timingStr), "Instant");
        default: strcopy(timingStr, sizeof(timingStr), "Unknown");
    }
    
    if (strlen(subgroup) > 0)
    {
        PrintToServer("[MultiMode Test] Vote changed gamemode to: %s/%s | Map: %s | Timing: %s", 
                     group, subgroup, map, timingStr);
    }
    else
    {
        PrintToServer("[MultiMode Test] Vote changed gamemode to: %s | Map: %s | Timing: %s", 
                     group, map, timingStr);
    }
}