/*****************************************************************************
                            Multi Mode Extras
******************************************************************************/

#include <multimode>
#include <multimode/base>
#include <multimode/randomcycle>
#include <morecolors>

public Plugin myinfo = 
{
    name = "[MMC] MultiMode Extras",
    author = "Oppressive Territory",
    description = "Extra features for MultiMode Core",
    version = PLUGIN_VERSION,
    url = ""
}

// Bool Section
bool g_bRandomCycleMapSet = false;

public void OnPluginStart()
{
    LoadTranslations("multimode_extra.phrases");
	
	RegConsoleCmd("sm_nextgamemode", Command_NextGameMode, "Shows the next scheduled gamemode");
	RegConsoleCmd("sm_currentgamemode", Command_CurrentGameMode, "Shows the server's current gamemode");
}

public void OnMapStart()
{
    g_bRandomCycleMapSet = false;
}

public void MultiMode_OnRandomCycleMapSet(const char[] map, const char[] group, const char[] subgroup)
{
    g_bRandomCycleMapSet = true;
}

public void MultiMode_OnVoteEnd(const char[] group, const char[] subgroup, const char[] map, VoteEndReason reason)
{
    g_bRandomCycleMapSet = false;
}

public Action Command_NextGameMode(int client, int args)
{
    char next_gamemode[64], next_subgroup[64], next_map[PLATFORM_MAX_PATH];

    MultiMode_GetNextGameMode(next_gamemode, sizeof(next_gamemode), next_subgroup, sizeof(next_subgroup));
    MultiMode_GetNextMap(next_map, sizeof(next_map));

    if (StrEqual(next_gamemode, ""))
    {
        if (g_bRandomCycleMapSet)
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
        if (strlen(next_subgroup) == 0)
        {
            strcopy(display_gamemode, sizeof(display_gamemode), next_gamemode);
        }
        else
        {
            Format(display_gamemode, sizeof(display_gamemode), "%s (%s)", next_gamemode, next_subgroup);
        }

        if (g_bRandomCycleMapSet)
        {
            CPrintToChat(client, "%t", "Next Gamemode Random Cycle Waiting", display_gamemode, next_map);
        }
        else
        {
            CPrintToChat(client, "%t", "Next Gamemode", display_gamemode, next_map);
        }
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
    if (strlen(current_subgroup) == 0)
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