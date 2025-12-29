/**
 * MultiMode Core Utilities
 * 
 * Utility functions for working with KeyValues, maps, and other common operations
 * across MultiMode plugins.
 */

#if defined _multimode_utils_included
    #endinput
#endif
#define _multimode_utils_included

#include <multimode/base>
#include <emitsoundany>

stock bool MMC_IsWildcardEntry(const char[] mapname)
{
    int len = strlen(mapname);
    return (len > 0 && mapname[len-1] == '_');
}

stock KeyValues MMC_GetMapKv(KeyValues kv, const char[] gamemode, const char[] mapname)
{
    if (kv == null)
        return null;
    
    KeyValues result = new KeyValues("");
    
    if (kv.JumpToKey(gamemode) && kv.JumpToKey("maps"))
    {
        if (kv.JumpToKey(mapname))
        {
            result.Import(kv);
            kv.GoBack();
        }
        else
        {
            bool foundWildcard = false;
            if (kv.GotoFirstSubKey(false))
            {
                do
                {
                    char mapKey[PLATFORM_MAX_PATH];
                    kv.GetSectionName(mapKey, sizeof(mapKey));
                    
                    if (MMC_IsWildcardEntry(mapKey) && StrContains(mapname, mapKey) == 0)
                    {
                        result.Import(kv);
                        foundWildcard = true;
                        break;
                    }
                } while (kv.GotoNextKey(false));
                kv.GoBack();
            }
            if (!foundWildcard && StrContains(mapname, "workshop/") == 0)
            {
                char mapParts[2][128];
                if (ExplodeString(mapname, "/", mapParts, 2, 128) == 2)
                {
                    char uid[32];
                    strcopy(uid, sizeof(uid), mapParts[1]);
                    
                    if (kv.GotoFirstSubKey(false))
                    {
                        do
                        {
                            char section[128];
                            kv.GetSectionName(section, sizeof(section));
                            
                            if (StrContains(section, uid) != -1)
                            {
                                result.Import(kv);
                                break;
                            }
                        } while (kv.GotoNextKey(false));
                        kv.GoBack();
                    }
                }
            }
        }
        kv.GoBack();
    }
    
    kv.Rewind();
    return result;
}

stock KeyValues MMC_GetSubGroupMapKv(KeyValues kv, const char[] gamemode, const char[] subgroup, const char[] mapname)
{
    if (kv == null)
        return null;
    
    KeyValues result = new KeyValues("");
    
    if (kv.JumpToKey(gamemode) && kv.JumpToKey("subgroup") && kv.JumpToKey(subgroup) && kv.JumpToKey("maps"))
    {
        if (kv.JumpToKey(mapname))
        {
            result.Import(kv);
            kv.GoBack();
        }
        else
        {
            bool foundWildcard = false;
            if (kv.GotoFirstSubKey(false))
            {
                do
                {
                    char mapKey[PLATFORM_MAX_PATH];
                    kv.GetSectionName(mapKey, sizeof(mapKey));
                    
                    if (MMC_IsWildcardEntry(mapKey) && StrContains(mapname, mapKey) == 0)
                    {
                        result.Import(kv);
                        foundWildcard = true;
                        break;
                    }
                } while (kv.GotoNextKey(false));
                kv.GoBack();
            }
            
            if (!foundWildcard && StrContains(mapname, "workshop/") == 0)
            {
                char mapParts[2][128];
                if (ExplodeString(mapname, "/", mapParts, 2, 128) == 2)
                {
                    char uid[32];
                    strcopy(uid, sizeof(uid), mapParts[1]);
                    
                    if (kv.GotoFirstSubKey(false))
                    {
                        do
                        {
                            char section[128];
                            kv.GetSectionName(section, sizeof(section));
                            
                            if (StrContains(section, uid) != -1)
                            {
                                result.Import(kv);
                                break;
                            }
                        } while (kv.GotoNextKey(false));
                        kv.GoBack();
                    }
                }
            }
        }
        kv.GoBack();
        kv.GoBack();
        kv.GoBack();
    }
    
    kv.Rewind();
    return result;
}

stock void MMC_ProcessDisplayTemplates(KeyValues kv, const char[] gamemode, const char[] map, const char[] subgroup, char[] customDisplay, int displayLen)
{
    if (StrContains(customDisplay, "{") == -1)
    {
        return; // No templates to process
    }
    
    // Get map display name for {MAP}
    char mapDisplay[PLATFORM_MAX_PATH];
    char baseMap[PLATFORM_MAX_PATH];
    strcopy(baseMap, sizeof(baseMap), map);
    if (GetMapDisplayName(baseMap, mapDisplay, sizeof(mapDisplay)))
    {
        // Use the formatted map name
    }
    else
    {
        strcopy(mapDisplay, sizeof(mapDisplay), map);
    }
    
    ReplaceString(customDisplay, displayLen, "{MAP}", mapDisplay, false);
    
    // Read values with priority: map > subgroup > gamemode
    int mintime = -1;
    int maxtime = -1;
    int maxplayers = 0;
    int minplayers = 0;
    char nominate_flags[32];
    nominate_flags[0] = '\0';
    
    // Try to get from map level first
    KeyValues mapKv = null;
    if (subgroup[0] != '\0')
    {
        mapKv = MMC_GetSubGroupMapKv(kv, gamemode, subgroup, map);
    }
    else
    {
        mapKv = MMC_GetMapKv(kv, gamemode, map);
    }
    
    if (mapKv != null)
    {
        char time_buffer[8];
        mapKv.GetString(MAPCYCLE_KEY_MINTIME, time_buffer, sizeof(time_buffer), "");
        if (time_buffer[0] != '\0')
        {
            int val = StringToInt(time_buffer);
            if (val >= 0) mintime = val;
        }
        
        mapKv.GetString(MAPCYCLE_KEY_MAXTIME, time_buffer, sizeof(time_buffer), "");
        if (time_buffer[0] != '\0')
        {
            int val = StringToInt(time_buffer);
            if (val >= 0) maxtime = val;
        }
        
        maxplayers = mapKv.GetNum(MAPCYCLE_KEY_MAXPLAYERS, 0);
        minplayers = mapKv.GetNum(MAPCYCLE_KEY_MINPLAYERS, 0);
        mapKv.GetString(MAPCYCLE_KEY_NOMINATE_FLAGS, nominate_flags, sizeof(nominate_flags), "");
        delete mapKv;
    }
    
    // If not found at map level, try subgroup level
    if (subgroup[0] != '\0')
    {
        if (kv.JumpToKey(gamemode) && kv.JumpToKey("subgroup") && kv.JumpToKey(subgroup))
        {
            char time_buffer[8];
            if (mintime == -1)
            {
                kv.GetString(MAPCYCLE_KEY_MINTIME, time_buffer, sizeof(time_buffer), "");
                if (time_buffer[0] != '\0')
                {
                    int val = StringToInt(time_buffer);
                    if (val >= 0) mintime = val;
                }
            }
            
            if (maxtime == -1)
            {
                kv.GetString(MAPCYCLE_KEY_MAXTIME, time_buffer, sizeof(time_buffer), "");
                if (time_buffer[0] != '\0')
                {
                    int val = StringToInt(time_buffer);
                    if (val >= 0) maxtime = val;
                }
            }
            
            if (maxplayers == 0) maxplayers = kv.GetNum(MAPCYCLE_KEY_MAXPLAYERS, 0);
            if (minplayers == 0) minplayers = kv.GetNum(MAPCYCLE_KEY_MINPLAYERS, 0);
            if (nominate_flags[0] == '\0') kv.GetString(MAPCYCLE_KEY_NOMINATE_FLAGS, nominate_flags, sizeof(nominate_flags), "");
            kv.GoBack();
            kv.GoBack();
            kv.GoBack();
        }
        kv.Rewind();
    }
    
    // If still not found, try gamemode level
    if (gamemode[0] != '\0')
    {
        if (kv.JumpToKey(gamemode))
        {
            char time_buffer[8];
            if (mintime == -1)
            {
                kv.GetString(MAPCYCLE_KEY_MINTIME, time_buffer, sizeof(time_buffer), "");
                if (time_buffer[0] != '\0')
                {
                    int val = StringToInt(time_buffer);
                    if (val >= 0) mintime = val;
                }
            }
            
            if (maxtime == -1)
            {
                kv.GetString(MAPCYCLE_KEY_MAXTIME, time_buffer, sizeof(time_buffer), "");
                if (time_buffer[0] != '\0')
                {
                    int val = StringToInt(time_buffer);
                    if (val >= 0) maxtime = val;
                }
            }
            
            if (maxplayers == 0) maxplayers = kv.GetNum(MAPCYCLE_KEY_MAXPLAYERS, 0);
            if (minplayers == 0) minplayers = kv.GetNum(MAPCYCLE_KEY_MINPLAYERS, 0);
            if (nominate_flags[0] == '\0') kv.GetString(MAPCYCLE_KEY_NOMINATE_FLAGS, nominate_flags, sizeof(nominate_flags), "");
            kv.GoBack();
        }
        kv.Rewind();
    }
    
    // Replace templates
    char buffer[32];
    
    if (mintime >= 0)
    {
        Format(buffer, sizeof(buffer), "%d", mintime);
        ReplaceString(customDisplay, displayLen, "{MIN_TIME}", buffer, false);
    }
    else
    {
        ReplaceString(customDisplay, displayLen, "{MIN_TIME}", "", false);
    }
    
    if (maxtime >= 0)
    {
        Format(buffer, sizeof(buffer), "%d", maxtime);
        ReplaceString(customDisplay, displayLen, "{MAX_TIME}", buffer, false);
    }
    else
    {
        ReplaceString(customDisplay, displayLen, "{MAX_TIME}", "", false);
    }
    
    if (maxplayers > 0)
    {
        Format(buffer, sizeof(buffer), "%d", maxplayers);
        ReplaceString(customDisplay, displayLen, "{MAX_PLAYERS}", buffer, false);
    }
    else
    {
        ReplaceString(customDisplay, displayLen, "{MAX_PLAYERS}", "", false);
    }
    
    if (minplayers > 0)
    {
        Format(buffer, sizeof(buffer), "%d", minplayers);
        ReplaceString(customDisplay, displayLen, "{MIN_PLAYERS}", buffer, false);
    }
    else
    {
        ReplaceString(customDisplay, displayLen, "{MIN_PLAYERS}", "", false);
    }
    
    if (nominate_flags[0] != '\0')
    {
        ReplaceString(customDisplay, displayLen, "{NOMINATE_FLAG}", nominate_flags, false);
    }
    else
    {
        ReplaceString(customDisplay, displayLen, "{NOMINATE_FLAG}", "", false);
    }
}

stock bool MMC_GetMapDisplayNameEx(KeyValues kv, const char[] gamemode, const char[] map, char[] display, int displayLen, const char[] subgroup = "")
{
    if (gamemode[0] != '\0')
    {
        if (subgroup[0] != '\0')
        {
            KeyValues subKv = MMC_GetSubGroupMapKv(kv, gamemode, subgroup, map);
            if (subKv != null)
            {
                char customDisplay[256];
                subKv.GetString(MAPCYCLE_KEY_DISPLAY, customDisplay, sizeof(customDisplay), "");
                delete subKv;
                if (customDisplay[0] != '\0') 
                {
                    MMC_ProcessDisplayTemplates(kv, gamemode, map, subgroup, customDisplay, sizeof(customDisplay));
                    strcopy(display, displayLen, customDisplay);
                    return true;
                }
            }
        }

        KeyValues mapKv = MMC_GetMapKv(kv, gamemode, map);
        if (mapKv != null)
        {
            char customDisplay[256];
            mapKv.GetString(MAPCYCLE_KEY_DISPLAY, customDisplay, sizeof(customDisplay), "");
            delete mapKv;
            if (customDisplay[0] != '\0') 
            {
                MMC_ProcessDisplayTemplates(kv, gamemode, map, subgroup, customDisplay, sizeof(customDisplay));
                strcopy(display, displayLen, customDisplay);
                return true;
            }
        }
    }

    // Finally: use the default map name
    char baseMap[PLATFORM_MAX_PATH];
    strcopy(baseMap, sizeof(baseMap), map);
    if (GetMapDisplayName(baseMap, display, displayLen)) 
    {
        return false; // Used default GetMapDisplayName, not custom
    }
    
    strcopy(display, displayLen, baseMap);
    return false; // Used raw map name
}

stock bool MMC_CanExtendMap()
{
    ConVar timelimit = FindConVar("mp_timelimit");
    ConVar maxrounds = FindConVar("mp_maxrounds");
    ConVar winlimit = FindConVar("mp_winlimit");
    ConVar fraglimit = FindConVar("mp_fraglimit");
    
    return (timelimit != null && timelimit.FloatValue > 0.0) || (maxrounds != null && maxrounds.IntValue > 0) || (winlimit != null && winlimit.IntValue > 0) || (fraglimit != null && fraglimit.IntValue > 0);
}

stock int MMC_FindGameModeIndex(const char[] name)
{
    ArrayList list = GetGameModesList();
    for (int i = 0; i < list.Length; i++)
    {
        GameModeConfig config;
        list.GetArray(i, config);
        if (StrEqual(config.name, name))
            return i;
    }
    return -1;
}

stock int MMC_FindSubGroupIndex(const char[] gamemode, const char[] subgroup)
{
    int gamemodeIndex = MMC_FindGameModeIndex(gamemode);
    if (gamemodeIndex == -1) return -1;

    GameModeConfig config;
    ArrayList list = GetGameModesList();
    list.GetArray(gamemodeIndex, config);

    for (int i = 0; i < config.subGroups.Length; i++)
    {
        SubGroupConfig subConfig;
        config.subGroups.GetArray(i, subConfig);
        if (StrEqual(subConfig.name, subgroup))
            return i;
    }
    return -1;
}

stock bool MMC_IsTimeAllowed(int minTime, int maxTime)
{
    if (minTime == -1 && maxTime == -1)
    {
        return true;
    }

    char sCurrentTime[5];
    FormatTime(sCurrentTime, sizeof(sCurrentTime), "%H%M");
    int iCurrentTime = StringToInt(sCurrentTime);

    if (minTime != -1 && maxTime != -1)
    {
        if (minTime <= maxTime)
        {
            return iCurrentTime >= minTime && iCurrentTime <= maxTime;
        }
        else
        {
            return iCurrentTime >= minTime || iCurrentTime <= maxTime;
        }
    }
    else if (minTime != -1)
    {
        return iCurrentTime >= minTime;
    }
    else // maxTime != -1
    {
        return iCurrentTime <= maxTime;
    }
}

stock bool MMC_IsCurrentlyAvailableByTime(KeyValues kv, const char[] group, const char[] subgroup = "", const char[] map = "")
{
    char buffer[8];
    int minTime = -1, maxTime = -1;

    if (strlen(map) > 0)
    {
        KeyValues mapKv;
        if (strlen(subgroup) > 0)
        {
            mapKv = MMC_GetSubGroupMapKv(kv, group, subgroup, map);
        }
        else
        {
            mapKv = MMC_GetMapKv(kv, group, map);
        }

        if (mapKv != null)
        {
            mapKv.GetString(MAPCYCLE_KEY_MINTIME, buffer, sizeof(buffer));
            if (buffer[0] != '\0') minTime = StringToInt(buffer);

            mapKv.GetString(MAPCYCLE_KEY_MAXTIME, buffer, sizeof(buffer));
            if (buffer[0] != '\0') maxTime = StringToInt(buffer);
            
            delete mapKv;

            if (minTime != -1 || maxTime != -1)
            {
                return MMC_IsTimeAllowed(minTime, maxTime);
            }
        }
    }

    if (strlen(subgroup) > 0)
    {
        int groupIndex = MMC_FindGameModeIndex(group);
        if (groupIndex != -1)
        {
            int subIndex = MMC_FindSubGroupIndex(group, subgroup);
            if (subIndex != -1)
            {
                GameModeConfig config;
                GetGameModesList().GetArray(groupIndex, config);
                SubGroupConfig subConfig;
                config.subGroups.GetArray(subIndex, subConfig);
                
                if (subConfig.mintime != -1 || subConfig.maxtime != -1)
                {
                    return MMC_IsTimeAllowed(subConfig.mintime, subConfig.maxtime);
                }
            }
        }
    }

    int groupIndex = MMC_FindGameModeIndex(group);
    if (groupIndex != -1)
    {
        GameModeConfig config;
        GetGameModesList().GetArray(groupIndex, config);
        if (config.mintime != -1 || config.maxtime != -1)
        {
            return MMC_IsTimeAllowed(config.mintime, config.maxtime);
        }
    }

    return true;
}

stock bool MMC_CanClientNominate(int client, const char[] gamemode, const char[] subgroup = "", const char[] map = "")
{
    if (client <= 0 || client > MaxClients || !IsClientInGame(client))
        return false;
    
    char requiredFlags[32];
    requiredFlags[0] = '\0';
    
    // Check map level first (highest priority)
    if (strlen(map) > 0)
    {
        KeyValues mapKv;
        if (strlen(subgroup) > 0)
        {
            mapKv = MMC_GetSubGroupMapKv(g_kvGameModes, gamemode, subgroup, map);
        }
        else
        {
            mapKv = MMC_GetMapKv(g_kvGameModes, gamemode, map);
        }
        
        if (mapKv != null)
        {
            mapKv.GetString(MAPCYCLE_KEY_NOMINATE_FLAGS, requiredFlags, sizeof(requiredFlags), "");
            delete mapKv;
            if (requiredFlags[0] != '\0')
            {
                return CheckCommandAccess(client, "sm_nominate", ReadFlagString(requiredFlags));
            }
        }
    }
    
    // Check subgroup level
    if (strlen(subgroup) > 0 && requiredFlags[0] == '\0')
    {
        int index = MMC_FindGameModeIndex(gamemode);
        if (index != -1)
        {
            GameModeConfig config;
            ArrayList list = GetGameModesList();
            list.GetArray(index, config);
            
            int subgroupIndex = MMC_FindSubGroupIndex(gamemode, subgroup);
            if (subgroupIndex != -1)
            {
                SubGroupConfig subConfig;
                config.subGroups.GetArray(subgroupIndex, subConfig);
                strcopy(requiredFlags, sizeof(requiredFlags), subConfig.nominate_flags);
                if (requiredFlags[0] != '\0')
                {
                    return CheckCommandAccess(client, "sm_nominate", ReadFlagString(requiredFlags));
                }
            }
        }
    }
    
    // Check gamemode level
    if (requiredFlags[0] == '\0')
    {
        int index = MMC_FindGameModeIndex(gamemode);
        if (index != -1)
        {
            GameModeConfig config;
            ArrayList list = GetGameModesList();
            list.GetArray(index, config);
            strcopy(requiredFlags, sizeof(requiredFlags), config.nominate_flags);
            if (requiredFlags[0] != '\0')
            {
                return CheckCommandAccess(client, "sm_nominate", ReadFlagString(requiredFlags));
            }
        }
    }
    
    // No restriction or requirement met
    return true;
}

stock bool MMC_GamemodeAvailable(const char[] gamemode)
{
    int index = MMC_FindGameModeIndex(gamemode);
    if (index == -1) return false;

    GameModeConfig config;
    ArrayList list = GetGameModesList();
    list.GetArray(index, config);
    
    if (config.enabled == 0) return false;
    
    if (config.adminonly == 1) return false;
    
    int players = GetRealClientCount();
    if (config.minplayers > 0 && players < config.minplayers) return false;
    if (config.maxplayers > 0 && players > config.maxplayers) return false;
    
    if (!MMC_IsCurrentlyAvailableByTime(g_kvGameModes, gamemode)) return false;
    
    return true;
}

stock bool MMC_GamemodeAvailableAdminVote(const char[] gamemode)
{
    int index = MMC_FindGameModeIndex(gamemode);
    if (index == -1) return false;

    GameModeConfig config;
    ArrayList list = GetGameModesList();
    list.GetArray(index, config);
    
    if (config.enabled == 0) return false;
    
    int players = GetRealClientCount();
    if (config.minplayers > 0 && players < config.minplayers) return false;
    if (config.maxplayers > 0 && players > config.maxplayers) return false;
    
    if (!MMC_IsCurrentlyAvailableByTime(g_kvGameModes, gamemode)) return false;
    
    return true;
}

stock void MMC_WriteToLogFile(ConVar logsCvar, const char[] format, any ...)
{
    if (logsCvar != null && !logsCvar.BoolValue)
        return;

    char buffer[512];
    VFormat(buffer, sizeof(buffer), format, 3);

    char dateStr[32];
    FormatTime(dateStr, sizeof(dateStr), "%Y%m%d");

    char logPath[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, logPath, sizeof(logPath), "logs/MMC_%s.txt", dateStr);

    File file = OpenFile(logPath, "a+");
    if (file != null)
    {
        char timeStr[64];
        FormatTime(timeStr, sizeof(timeStr), "%Y-%m-%d %H:%M:%S");

        file.WriteLine("[%s] %s", timeStr, buffer);
        LogMessage("%s", buffer);

        delete file;
    }
    else
    {
        LogError("Failed to write to log file: %s", logPath);
    }
}

stock bool MMC_FindConfigForMap(const char[] map, char[] group, int groupLen, char[] subgroup, int subgroupLen, const char[] currentGameMode = "")
{
    ArrayList gameModes = GetGameModesList();

    if (strlen(currentGameMode) > 0)
    {
        char currentGroup[64], currentSubGroup[64];
        SplitGamemodeString(currentGameMode, currentGroup, sizeof(currentGroup), currentSubGroup, sizeof(currentSubGroup));

        int i = MMC_FindGameModeIndex(currentGroup);
        if (i != -1)
        {
            GameModeConfig config;
            gameModes.GetArray(i, config);
            
            if (MMC_GamemodeAvailable(config.name))
            {
                if (config.maps.FindString(map) != -1)
                {
                    strcopy(group, groupLen, config.name);
                    subgroup[0] = '\0';
                    return true;
                }
                
                for (int j = 0; j < config.subGroups.Length; j++)
                {
                    SubGroupConfig subConfig;
                    config.subGroups.GetArray(j, subConfig);
                    if (subConfig.maps.FindString(map) != -1)
                    {
                        strcopy(group, groupLen, config.name);
                        strcopy(subgroup, subgroupLen, subConfig.name);
                        return true;
                    }
                }
            }
        }
    }

    for (int i = 0; i < gameModes.Length; i++)
    {
        GameModeConfig config;
        gameModes.GetArray(i, config);
        
        if (!MMC_GamemodeAvailable(config.name)) continue;
        
        if (config.maps.FindString(map) != -1)
        {
            strcopy(group, groupLen, config.name);
            subgroup[0] = '\0';
            return true;
        }
        
        for (int j = 0; j < config.subGroups.Length; j++)
        {
            SubGroupConfig subConfig;
            config.subGroups.GetArray(j, subConfig);
            if (subConfig.maps.FindString(map) != -1)
            {
                strcopy(group, groupLen, config.name);
                strcopy(subgroup, subgroupLen, subConfig.name);
                return true;
            }
        }
    }
    return false;
}

stock int MMC_FindGameModeForMap(const char[] map, const char[] currentGameMode = "")
{
    ArrayList gameModes = GetGameModesList();
    
    if (strlen(currentGameMode) > 0)
    {
        char currentGroup[64], currentSubGroup[64];
        SplitGamemodeString(currentGameMode, currentGroup, sizeof(currentGroup), currentSubGroup, sizeof(currentSubGroup));

        int index = MMC_FindGameModeIndex(currentGroup);
        if (index != -1)
        {
            GameModeConfig config;
            gameModes.GetArray(index, config);
            if (config.maps.FindString(map) != -1)
            {
                return index;
            }

            for (int j = 0; j < config.subGroups.Length; j++)
            {
                SubGroupConfig subConfig;
                config.subGroups.GetArray(j, subConfig);
                if (subConfig.maps.FindString(map) != -1)
                {
                    return index;
                }
            }
        }
    }

    for (int i = 0; i < gameModes.Length; i++)
    {
        GameModeConfig config;
        gameModes.GetArray(i, config);
        if (config.maps.FindString(map) != -1)
        {
            return i;
        }
        
        for (int j = 0; j < config.subGroups.Length; j++)
        {
            SubGroupConfig subConfig;
            config.subGroups.GetArray(j, subConfig);
            if (subConfig.maps.FindString(map) != -1)
            {
                return i;
            }
        }
    }
    return -1;
}

stock void MMC_UpdateCurrentGameMode(const char[] map, char[] currentGameMode, int currentGameModeLen, const char[] currentGameModeIn = "")
{
    ArrayList gameModes = GetGameModesList();
    
    // check if the map exists in the current gamemode... (if we have one)
    // this prevents issues when the same map exists in multiple gamemodes...
    if (strlen(currentGameModeIn) > 0)
    {
        char currentGroup[64], currentSubGroup[64];
        SplitGamemodeString(currentGameModeIn, currentGroup, sizeof(currentGroup), currentSubGroup, sizeof(currentSubGroup));
        
        int i = MMC_FindGameModeIndex(currentGroup);
        if (i != -1)
        {
            GameModeConfig config;
            gameModes.GetArray(i, config);
            
            if (strlen(currentSubGroup) > 0)
            {
                for (int j = 0; j < config.subGroups.Length; j++)
                {
                    SubGroupConfig subConfig;
                    config.subGroups.GetArray(j, subConfig);
                    
                    if (StrEqual(subConfig.name, currentSubGroup) && subConfig.maps.FindString(map) != -1)
                    {
                        strcopy(currentGameMode, currentGameModeLen, currentGameModeIn);
                        return;
                    }
                }
            }
            else
            {
                if (config.maps.FindString(map) != -1)
                {
                    strcopy(currentGameMode, currentGameModeLen, currentGameModeIn);
                    return;
                }
            }
        }
    }
    
    for(int i = 0; i < gameModes.Length; i++)
    {
        GameModeConfig config;
        gameModes.GetArray(i, config);
        
        for (int j = 0; j < config.subGroups.Length; j++)
        {
            SubGroupConfig subConfig;
            config.subGroups.GetArray(j, subConfig);
            
            if(subConfig.maps.FindString(map) != -1)
            {
                char temp[128];
                Format(temp, sizeof(temp), "%s/%s", config.name, subConfig.name);
                strcopy(currentGameMode, currentGameModeLen, temp);
                return;
            }
        }
        
        if(config.maps.FindString(map) != -1)
        {
            strcopy(currentGameMode, currentGameModeLen, config.name);
            return;
        }
    }
    
    // Map not found in any gamemode
    currentGameMode[0] = '\0';
}

stock void MMC_ExpandWildcardMaps(const char[] pattern, ArrayList maplist)
{
    Handle dir = OpenDirectory("maps");
    FileType type;
    char fileName[PLATFORM_MAX_PATH];
    char mapName[PLATFORM_MAX_PATH];
    
    if (dir == null) return;

    while (ReadDirEntry(dir, fileName, sizeof(fileName), type))
    {
        if (type == FileType_File && StrContains(fileName, ".bsp") != -1)
        {
            strcopy(mapName, sizeof(mapName), fileName);
            int extpos = StrContains(mapName, ".bsp");
            if (extpos != -1) mapName[extpos] = '\0';
            
            if (StrContains(mapName, pattern) == 0 && IsMapValid(mapName))
            {
                if (maplist.FindString(mapName) == -1)
                {
                    maplist.PushString(mapName);
                }
            }
        }
    }
    
    CloseHandle(dir);
}

stock void MMC_PrecacheVoteSound(const char[] sound)
{
    if (sound[0] == '\0')
    {
        return;
    }
    
    #if defined _emitsoundany_included
        PrecacheSoundAny(sound, true);
    #else
        PrecacheSound(sound, true);
    #endif
    
    char downloadPath[PLATFORM_MAX_PATH];
    FormatEx(downloadPath, sizeof(downloadPath), "sound/%s", sound);
    
    if (FileExists(downloadPath, true))
    {
        AddFileToDownloadsTable(downloadPath);
    }
}

stock void MMC_PlayVoteSound(bool isStart, bool isRunoff, const char[] startSound = "", const char[] endSound = "", const char[] runoffstartSound = "", const char[] runoffendSound = "")
{
    char soundToPlay[PLATFORM_MAX_PATH];
    soundToPlay[0] = '\0';
    
    // Decide which sound to use based on parameters
    if (isStart && isRunoff)
    {
        // Runoff start sound
        if (runoffstartSound[0] != '\0')
        {
            strcopy(soundToPlay, sizeof(soundToPlay), runoffstartSound);
        }
    }
    else if (isStart && !isRunoff)
    {
        // Normal start sound
        if (startSound[0] != '\0')
        {
            strcopy(soundToPlay, sizeof(soundToPlay), startSound);
        }
    }
    else if (!isStart && isRunoff)
    {
        // Runoff end sound
        if (runoffendSound[0] != '\0')
        {
            strcopy(soundToPlay, sizeof(soundToPlay), runoffendSound);
        }
    }
    else // !isStart && !isRunoff
    {
        // Normal end sound
        if (endSound[0] != '\0')
        {
            strcopy(soundToPlay, sizeof(soundToPlay), endSound);
        }
    }
    
    // Precache and play the sound if available
    if (soundToPlay[0] != '\0')
    {
        MMC_PrecacheVoteSound(soundToPlay);
        
        #if defined _emitsoundany_included
            EmitSoundToAllAny(soundToPlay);
        #else
            EmitSoundToAll(soundToPlay);
        #endif
    }
}

/**
 * Performs the actual map extension by modifying server convars.
 * This is the base function that extends time, rounds, and frag limits.
 * 
 * @param timeStep        Minutes to add to mp_timelimit
 * @param roundStep       Rounds to add to mp_maxrounds and mp_winlimit
 * @param fragStep        Frags to add to mp_fraglimit
 * @param bExtendedRounds Output parameter indicating if rounds were extended
 * @param bExtendedFrags  Output parameter indicating if frags were extended
 * @noreturn
 */
stock void MMC_PerformExtension(float timeStep, int roundStep, int fragStep, bool &bExtendedRounds = false, bool &bExtendedFrags = false)
{
    bExtendedRounds = false;
    bExtendedFrags = false;
    
    ConVar timelimit = FindConVar("mp_timelimit");
    if (timelimit != null && timelimit.FloatValue > 0.0)
    {
        timelimit.FloatValue += timeStep;
    }
    
    ConVar maxrounds = FindConVar("mp_maxrounds");
    if (maxrounds != null && maxrounds.IntValue > 0)
    {
        maxrounds.IntValue += roundStep;
        bExtendedRounds = true;
    }
    
    ConVar winlimit = FindConVar("mp_winlimit");
    if (winlimit != null && winlimit.IntValue > 0)
    {
        winlimit.IntValue += roundStep;
        bExtendedRounds = true;
    }
    
    ConVar fraglimit = FindConVar("mp_fraglimit");
    if (fraglimit != null && fraglimit.IntValue > 0)
    {
        fraglimit.IntValue += fragStep;
        bExtendedFrags = true;
    }
}

/**
 * Extends the map time, rounds, and frag limits with custom values.
 * 
 * @param minutes         Minutes to extend the time limit (default: 6)
 * @param roundStep       Rounds to extend round/win limits (default: 3)
 * @param fragStep        Frags to extend frag limit (default: 10)
 * @param bExtendedRounds Output parameter indicating if rounds were extended
 * @param bExtendedFrags  Output parameter indicating if frags were extended
 * @noreturn
 */
stock void MMC_ExtendMapTime(float minutes = 6.0, int roundStep = 3, int fragStep = 10, bool &bExtendedRounds = false, bool &bExtendedFrags = false)
{
    bool tempRounds = false;
    bool tempFrags = false;
    
    MMC_PerformExtension(minutes, roundStep, fragStep, tempRounds, tempFrags);
    
    bExtendedRounds = tempRounds;
    bExtendedFrags = tempFrags;
}

