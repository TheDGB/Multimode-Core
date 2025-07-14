/*****************************************************************************
                            Multi Mode Extras
******************************************************************************/

#include <multimode>
#include <morecolors>

public void OnPluginStart()
{
    LoadTranslations("multimode_extra.phrases");
	
	RegConsoleCmd("sm_nextgamemode", Command_NextGameMode, "Shows the next scheduled gamemode");
	RegConsoleCmd("sm_currentgamemode", Command_CurrentGameMode, "Shows the server's current gamemode");
}

public Action Command_NextGameMode(int client, int args)
{
    char next_gamemode[64], next_map[PLATFORM_MAX_PATH];

    MultiMode_GetNextGameMode(next_gamemode, sizeof(next_gamemode));
    MultiMode_GetNextMap(next_map, sizeof(next_map));

    if (StrEqual(next_gamemode, ""))
    {
        bool randomEnabled = MultiMode_IsRandomCycleEnabled();
        if (randomEnabled)
        {
            CPrintToChat(client, "%t", "Random Cycle Next Gamemode");
        }
        else
        {
            CPrintToChat(client, "%t", "Unknown Next Gamemode");
        }
    }
    else
    {
        CPrintToChat(client, "%t", "Next Gamemode", next_gamemode, next_map);
    }

    return Plugin_Handled;
}

public Action Command_CurrentGameMode(int client, int args)
{
    char current_gamemode[64];
    char current_map[PLATFORM_MAX_PATH];

    MultiMode_GetCurrentGameMode(current_gamemode, sizeof(current_gamemode));
    GetCurrentMap(current_map, sizeof(current_map));

    CPrintToChat(client, "%t", "Current Gamemode", current_gamemode, current_map);

    return Plugin_Handled;
}
