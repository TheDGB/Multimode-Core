// multimode_test.sp
// Test plugin for MultiMode Core

#include <sourcemod>
#include <multimode>

public Plugin myinfo = 
{
    name = "MultiMode Test",
    author = "DGB",
    description = "Test plugin for MultiMode forwards",
    version = "1.0",
    url = ""
};

public void OnPluginStart()
{
    PrintToServer("[MultiMode Test] Plugin successfully loaded!");
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
