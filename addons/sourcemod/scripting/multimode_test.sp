// multimode_test.sp
// Test plugin for MultiMode Core

#include <sourcemod>
#include <multimode>

public Plugin myinfo = 
{
    name = "MultiMode Test",
    author = "DGB",
    description = "Test plugin for MultiMode forwards and natives",
    version = "1.2",
    url = ""
};

public void OnPluginStart()
{
    PrintToServer("[MultiMode Test] Plugin successfully loaded!");
    
    RegConsoleCmd("sm_cancelvote_test", Command_CancelVoteTest, "Cancels the current MultiMode vote (if active).");
    RegConsoleCmd("sm_randommap_test", Command_RandomMapTest, "Gets a random map from MultiMode and prints it.");
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
    char map[64];

    // Optional: accept a group argument
    if (args > 0)
    {
        GetCmdArgString(group, sizeof(group));
        TrimString(group);
    }

    if (MultiMode_GetRandomMap(group, sizeof(group), map, sizeof(map)))
    {
        PrintToChatAll("[MultiMode Test] Random map selected: %s | Gamemode: %s", map, group);
        PrintToServer("[MultiMode Test] Random map test: %s | Gamemode: %s", map, group);
    }
    else
    {
        PrintToChat(client, "[MultiMode Test] No map could be selected!");
    }

    return Plugin_Handled;
}

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

public void MultiMode_OnVoteEnd(const char[] group, const char[] map)
{
    PrintToServer("[MultiMode Test] Vote ended! Chosen gamemode: %s | Chosen map: %s", group, map);
}

public void MultiMode_OnGamemodeChanged(const char[] group, const char[] map, int timing)
{
    PrintToServer("[MultiMode Test] Gamemode changed to: %s | Map: %s | Timing: %d", group, map, timing);
}

public void MultiMode_OnGamemodeChangedVote(const char[] group, const char[] map, int timing)
{
    PrintToServer("[MultiMode Test] Vote changed gamemode to: %s | Map: %s | Timing: %d", group, map, timing);
}
