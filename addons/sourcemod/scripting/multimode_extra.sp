/*****************************************************************************
                            Multi Mode Extras
******************************************************************************/

#include <multimode>
#include <morecolors>

public void OnPluginStart()
{
	RegConsoleCmd("sm_nextgamemode", Command_NextGameMode, "Shows the next scheduled gamemode");
	RegConsoleCmd("sm_currentgamemode", Command_CurrentGameMode, "Shows the server's current gamemode");
}

public Action Command_NextGameMode(int client, int args)
{
    char next_gamemode[64], next_map[PLATFORM_MAX_PATH], buffer[128];
    
    MultiMode_GetNextGameMode(next_gamemode, sizeof(next_gamemode));
    MultiMode_GetNextMap(next_map, sizeof(next_map));
    
    if(StrEqual(next_gamemode, "")) 
    {
        bool randomEnabled = MultiMode_IsRandomCycleEnabled();
        char tempBuffer[64];
        Format(tempBuffer, sizeof(tempBuffer), "%t", randomEnabled ? "Random Map Enabled" : "Unknown");
        Format(buffer, sizeof(buffer), "%t", "Next Gamemode", tempBuffer);
    }
    else 
    {
        Format(buffer, sizeof(buffer), "%t", "Next Gamemode Full", next_gamemode, next_map);
    }
    
    CPrintToChat(client, buffer);
    return Plugin_Handled;
}

public Action Command_CurrentGameMode(int client, int args)
{
    char current_gamemode[64];
	char current_map[164];
    MultiMode_GetCurrentGameMode(current_gamemode, sizeof(current_gamemode));
	MultiMode_GetCurrentMap(current_map, sizeof(current_map));
    
    CPrintToChat(client, "%t", "Current Gamemode", current_gamemode, current_map);
  
    return Plugin_Handled;
}