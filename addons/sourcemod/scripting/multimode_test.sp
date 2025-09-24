// multimode_test.sp
// Test plugin for MultiMode Core

#include <sourcemod>
#include <multimode>

public Plugin myinfo = 
{
    name = "MultiMode Test",
    author = "DGB",
    description = "Test plugin for MultiMode forwards and natives",
    version = "1.1",
    url = ""
};

public void OnPluginStart()
{
    PrintToServer("[MultiMode Test] Plugin successfully loaded!");
    RegConsoleCmd("sm_cancelvotetest", Command_CancelVote, "Cancels the current MultiMode vote (if active).");
	RegConsoleCmd("sm_randommap", Command_RandomMap, "Gets a random map from a gamemode (or any if none specified).");
}

public Action Command_CancelVote(int client, int args)
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

public Action Command_RandomMap(int client, int args)
{
    char gamemode[64];
    char map[64];

    if (args > 0)
    {
        GetCmdArgString(gamemode, sizeof(gamemode));
        TrimString(gamemode);
    }
    else
    {
        gamemode[0] = '\0';
    }

    if (MultiMode_GetRandomMap(gamemode, map, sizeof(map)))
    {
        if (gamemode[0] == '\0')
        {
            PrintToChat(client, "[MultiMode Test] Random map found: %s (from any gamemode)", map);
            PrintToServer("[MultiMode Test] Random map found: %s (from any gamemode)", map);
        }
        else
        {
            PrintToChat(client, "[MultiMode Test] Random map found for gamemode '%s': %s", gamemode, map);
            PrintToServer("[MultiMode Test] Random map found for gamemode '%s': %s", gamemode, map);
        }
    }
    else
    {
        if (gamemode[0] == '\0')
        {
            PrintToChat(client, "[MultiMode Test] No random map could be found!");
            PrintToServer("[MultiMode Test] No random map could be found!");
        }
        else
        {
            PrintToChat(client, "[MultiMode Test] No random map found for gamemode '%s'!", gamemode);
            PrintToServer("[MultiMode Test] No random map found for gamemode '%s'!", gamemode);
        }
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

public void MultiMode_OnVoteEnd(const char[] gamemode, const char[] map)
{
    PrintToServer("[MultiMode Test] Vote ended! Chosen gamemode: %s | Chosen map: %s", gamemode, map);
}

public void MultiMode_OnGamemodeChanged(const char[] gamemode, const char[] map, int timing)
{
    PrintToServer("[MultiMode Test] Gamemode changed to: %s | Map: %s | Timing: %d", gamemode, map, timing);
}