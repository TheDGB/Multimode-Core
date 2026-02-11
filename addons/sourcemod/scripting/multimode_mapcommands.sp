/*****************************************************************************
                        MultiMode MapCycle Commands
******************************************************************************/

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <multimode>
#include <multimode/base>
#include <multimode/utils>
#include <multimode/mapcyclecommands>

public Plugin myinfo = 
{
    name = "[MMC] MultiMode MapCycle Commands",
    author = "Oppressive Territory",
    description = "MapCycle command execution for MultiMode Core",
    version = PLUGIN_VERSION,
    url = ""
}

// Key Values Section
KeyValues g_kvMapcycle;

// Char Section
char g_sCurrentMap[PLATFORM_MAX_PATH];
char g_sCurrentGroup[64];
char g_sCurrentSubGroup[64];

// Bool Section
bool g_bPreCommandExecuted = false;

public void OnPluginStart()
{
    HookEvent("game_end", Event_GameEnd, EventHookMode_Post);
    HookEvent("round_end", Event_RoundEnd, EventHookMode_Post);
    
    GetCurrentMap(g_sCurrentMap, sizeof(g_sCurrentMap));
    MultiMode_GetCurrentGameMode(g_sCurrentGroup, sizeof(g_sCurrentGroup), g_sCurrentSubGroup, sizeof(g_sCurrentSubGroup));
}

public void OnConfigsExecuted()
{
    LoadMapcycle();
}

public void OnMapStart()
{
    g_bPreCommandExecuted = false;
    
    GetCurrentMap(g_sCurrentMap, sizeof(g_sCurrentMap));
    MultiMode_GetCurrentGameMode(g_sCurrentGroup, sizeof(g_sCurrentGroup), g_sCurrentSubGroup, sizeof(g_sCurrentSubGroup));

    ExecuteMapCommand(g_sCurrentGroup, g_sCurrentSubGroup, g_sCurrentMap);
}

public void Event_GameEnd(Event event, const char[] name, bool dontBroadcast)
{
    if (!g_bPreCommandExecuted)
    {
        ExecutePreCommand(g_sCurrentGroup, g_sCurrentSubGroup, g_sCurrentMap);
        g_bPreCommandExecuted = true;
    }
}

public void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
    if (!g_bPreCommandExecuted)
    {
        char nextMap[PLATFORM_MAX_PATH];
        MultiMode_GetNextMap(nextMap, sizeof(nextMap));
        
        if (strlen(nextMap) > 0 && !StrEqual(nextMap, g_sCurrentMap))
        {
            ExecutePreCommand(g_sCurrentGroup, g_sCurrentSubGroup, g_sCurrentMap);
            g_bPreCommandExecuted = true;
        }
    }
}

public void MultiMode_OnGamemodeChangedVote(const char[] group, const char[] subgroup, const char[] map, int timing)
{
    ExecuteVoteCommand(group, subgroup, map);
}

public void MultiMode_OnGamemodeChanged(const char[] group, const char[] subgroup, const char[] map, int timing)
{
    ExecuteVoteCommand(group, subgroup, map);
}

void LoadMapcycle()
{
    delete g_kvMapcycle;
    g_kvMapcycle = MMC_GetMapCycle();
    if (g_kvMapcycle != null)
    {
        g_kvMapcycle.Rewind();
    }
}

public void MultiMode_OnMapCycleReloaded()
{
    LoadMapcycle();
}

KeyValues GetMapcycle()
{
    if (g_kvMapcycle != null)
    {
        return g_kvMapcycle;
    }
    
    LoadMapcycle();
    return g_kvMapcycle;
}

bool GetMapCycleKeyValue(KeyValues kv, const char[] gamemode, const char[] subgroup, const char[] map, const char[] key, char[] value, int valueLen)
{
    if (kv == null)
        return false;

    value[0] = '\0';

    if (strlen(subgroup) > 0)
    {
        KeyValues kvSubMap = MMC_GetSubGroupMapKv(kv, gamemode, subgroup, map);
        if (kvSubMap != null)
        {
            kvSubMap.GetString(key, value, valueLen, "");
            delete kvSubMap;
            if (strlen(value) > 0)
                return true;
        }
    }

    KeyValues kvMap = MMC_GetMapKv(kv, gamemode, map);
    if (kvMap != null)
    {
        kvMap.GetString(key, value, valueLen, "");
        delete kvMap;
        if (strlen(value) > 0)
            return true;
    }

    if (kv.JumpToKey(gamemode))
    {
        kv.GetString(key, value, valueLen, "");
        kv.Rewind();
        if (strlen(value) > 0)
            return true;
    }
    kv.Rewind();

    return false;
}

void ExecuteMapCommand(const char[] gamemode, const char[] subgroup, const char[] map)
{
    if (g_kvMapcycle == null)
    {
        GetMapcycle();
        if (g_kvMapcycle == null)
            return;
    }

    char command[512];
    char config[PLATFORM_MAX_PATH];

    if (GetMapCycleKeyValue(g_kvMapcycle, gamemode, subgroup, map, MAPCYCLE_KEY_COMMAND, command, sizeof(command)))
    {
        ServerCommand("%s", command);
        MMC_WriteToLogFile(null, "[MultiMode MapCycle Commands] Executed command for map %s (group: %s, subgroup: %s): %s", 
                   map, gamemode, strlen(subgroup) > 0 ? subgroup : "none", command);
    }

    if (GetMapCycleKeyValue(g_kvMapcycle, gamemode, subgroup, map, MAPCYCLE_KEY_CONFIG, config, sizeof(config)))
    {
        char configPath[PLATFORM_MAX_PATH];
        Format(configPath, sizeof(configPath), "cfg/%s", config);
        ServerCommand("exec \"%s\"", configPath);
        MMC_WriteToLogFile(null, "[MultiMode MapCycle Commands] Executed config for map %s (group: %s, subgroup: %s): %s", 
                   map, gamemode, strlen(subgroup) > 0 ? subgroup : "none", config);
    }
}

void ExecutePreCommand(const char[] gamemode, const char[] subgroup, const char[] map)
{
    if (g_kvMapcycle == null)
    {
        GetMapcycle();
        if (g_kvMapcycle == null)
            return;
    }
    
    char command[512];
    bool commandFound = false;
    
    if (strlen(subgroup) > 0)
    {
        KeyValues kv = MMC_GetSubGroupMapKv(g_kvMapcycle, gamemode, subgroup, map);
        if (kv != null)
        {
            kv.GetString(MAPCYCLE_KEY_PRE_COMMAND, command, sizeof(command), "");
            delete kv;
            if (strlen(command) > 0)
            {
                commandFound = true;
            }
        }
    }

    if (!commandFound)
    {
        KeyValues kv = MMC_GetMapKv(g_kvMapcycle, gamemode, map);
        if (kv != null)
        {
            kv.GetString(MAPCYCLE_KEY_PRE_COMMAND, command, sizeof(command), "");
            delete kv;
            if (strlen(command) > 0)
            {
                commandFound = true;
            }
        }
    }

    if (!commandFound)
    {
        if (g_kvMapcycle.JumpToKey(gamemode))
        {
            g_kvMapcycle.GetString(MAPCYCLE_KEY_PRE_COMMAND, command, sizeof(command), "");
            g_kvMapcycle.Rewind();
            if (strlen(command) > 0)
            {
                commandFound = true;
            }
        }
        g_kvMapcycle.Rewind();
    }
    
    if (commandFound && strlen(command) > 0)
    {
        ServerCommand("%s", command);
        MMC_WriteToLogFile(null, "[MultiMode MapCycle Commands] Executed pre-command for map %s (group: %s, subgroup: %s): %s", 
                   map, gamemode, strlen(subgroup) > 0 ? subgroup : "none", command);
    }
}

void ExecuteVoteCommand(const char[] gamemode, const char[] subgroup, const char[] map)
{
    if (g_kvMapcycle == null)
    {
        GetMapcycle();
        if (g_kvMapcycle == null)
            return;
    }
    
    char command[512];
    bool commandFound = false;
    
    if (strlen(subgroup) > 0)
    {
        KeyValues kv = MMC_GetSubGroupMapKv(g_kvMapcycle, gamemode, subgroup, map);
        if (kv != null)
        {
            kv.GetString(MAPCYCLE_KEY_VOTE_COMMAND, command, sizeof(command), "");
            delete kv;
            if (strlen(command) > 0)
            {
                commandFound = true;
            }
        }
    }
    
    if (!commandFound)
    {
        KeyValues kv = MMC_GetMapKv(g_kvMapcycle, gamemode, map);
        if (kv != null)
        {
            kv.GetString(MAPCYCLE_KEY_VOTE_COMMAND, command, sizeof(command), "");
            delete kv;
            if (strlen(command) > 0)
            {
                commandFound = true;
            }
        }
    }
    
    if (!commandFound)
    {
        if (g_kvMapcycle.JumpToKey(gamemode))
        {
            g_kvMapcycle.GetString(MAPCYCLE_KEY_VOTE_COMMAND, command, sizeof(command), "");
            g_kvMapcycle.Rewind();
            if (strlen(command) > 0)
            {
                commandFound = true;
            }
        }
        g_kvMapcycle.Rewind();
    }
    
    if (commandFound && strlen(command) > 0)
    {
        ServerCommand("%s", command);
        MMC_WriteToLogFile(null, "[MultiMode MapCycle Commands] Executed vote-command for map %s (group: %s, subgroup: %s): %s", 
                   map, gamemode, strlen(subgroup) > 0 ? subgroup : "none", command);
    }
}