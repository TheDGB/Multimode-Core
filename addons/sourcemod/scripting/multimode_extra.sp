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
    char next_gamemode[64], next_subgroup[64], next_map[PLATFORM_MAX_PATH];

    MultiMode_GetNextGameMode(next_gamemode, sizeof(next_gamemode), next_subgroup, sizeof(next_subgroup));
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
        char display_gamemode[128];
        if (StrEqual(next_subgroup, ""))
        {
            strcopy(display_gamemode, sizeof(display_gamemode), next_gamemode);
        }
        else
        {
            Format(display_gamemode, sizeof(display_gamemode), "%s (%s)", next_gamemode, next_subgroup);
        }

        CPrintToChat(client, "%t", "Next Gamemode", display_gamemode, next_map);
    }

    return Plugin_Handled;
}

public Action Command_CurrentGameMode(int client, int args)
{
    char current_gamemode[64], current_subgroup[64];
    char current_map[PLATFORM_MAX_PATH];

    MultiMode_GetCurrentGameMode(current_gamemode, sizeof(current_gamemode), current_subgroup, sizeof(current_subgroup));
    MultiMode_GetCurrentMap(current_map, sizeof(current_map));

    char display_gamemode[128];
    if (StrEqual(current_subgroup, ""))
    {
        strcopy(display_gamemode, sizeof(display_gamemode), current_gamemode);
    }
    else
    {
        Format(display_gamemode, sizeof(display_gamemode), "%s (%s)", current_gamemode, current_subgroup);
    }

    CPrintToChat(client, "%t", "Current Gamemode", display_gamemode, current_map);

    return Plugin_Handled;
}