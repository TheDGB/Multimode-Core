#if defined _multimode_base_included
 #endinput
#endif
#define _multimode_base_included

#include <adt_array>

#define MAX_GAMEMODES 64
#define MAX_MAPS_PER_MODE 128
#define MAX_SUBGROUPS_PER_MODE 16

enum TimingMode
{
    TIMING_NEXTMAP = 0,
    TIMING_NEXTROUND,
    TIMING_INSTANT
};

enum VoteEndReason
{
    VoteEnd_Winner,     /**< A winner was chosen. */
    VoteEnd_Runoff,     /**< A runoff vote is starting next. */
    VoteEnd_Extend,     /**< The map was extended. */
    VoteEnd_Cancelled,  /**< The vote was cancelled by an admin or plugin. */
    VoteEnd_Failed      /**< The vote failed (e.g., no votes, tie with runoff disabled). */
};

enum struct VoteCandidate {
    char name[PLATFORM_MAX_PATH];
    char info[PLATFORM_MAX_PATH];
    int votes;
    int originalIndex;
}

enum VoteType
{
    VOTE_TYPE_GROUP = 0,
    VOTE_TYPE_SUBGROUP,
    VOTE_TYPE_MAP,
    VOTE_TYPE_SUBGROUP_MAP,
}

enum struct SubGroupConfig {
    char name[64];
    char command[256];
    char pre_command[256];
    char vote_command[256];
    int adminonly;
    int enabled;
    int maxplayers;
    int minplayers;
    ArrayList maps;
    int maps_invote;
}

enum struct GameModeConfig {
    char name[64];
    char command[256];
    char pre_command[256];
    char vote_command[256];
    int maps_invote;
    int subgroups_invote;
    int adminonly;
    int enabled;
    int maxplayers;
    int minplayers;
    ArrayList maps;
    ArrayList subGroups;
}

methodmap GameMode {
    public GameMode(const char[] name, const char[] cmd, int limit) {
        GameModeConfig config;
        strcopy(config.name, sizeof(config.name), name);
        strcopy(config.command, sizeof(config.command), cmd);
        config.maps_invote = limit;
        config.maps = new ArrayList(ByteCountToCells(256));
        config.subGroups = new ArrayList(sizeof(SubGroupConfig));
        
        ArrayList list = GetGameModesList();
        return view_as<GameMode>(list.PushArray(config));
    }
    
    property int Index {
        public get() { return view_as<int>(this); }
    }
    
    public void GetConfig(GameModeConfig config) {
        ArrayList list = GetGameModesList();
        list.GetArray(this.Index, config);
    }
    
    public bool GetDisplayName(char[] buffer, int maxlength) {
        GameModeConfig config;
        this.GetConfig(config);
        strcopy(buffer, maxlength, config.name);
        return true;
    }
}

stock ArrayList GetGameModesList() {
    static ArrayList list;
    if (list == null) {
        list = new ArrayList(sizeof(GameModeConfig));
    }
    return list;
}

forward void OnGamemodeConfigLoaded();

KeyValues g_kvGameModes;

stock void GetNominateFlags(const char[] gamemode, const char[] subgroup, const char[] map, char[] flags, int maxlen)
{
    flags[0] = '\0';

    if (strlen(subgroup) > 0) {
        if (g_kvGameModes.JumpToKey(gamemode) && g_kvGameModes.JumpToKey("subgroup") && g_kvGameModes.JumpToKey(subgroup) && g_kvGameModes.JumpToKey("maps")) {
            if (g_kvGameModes.JumpToKey(map)) {
                g_kvGameModes.GetString("nominate_flags", flags, maxlen);
                g_kvGameModes.GoBack();
            }
            g_kvGameModes.GoBack();
            g_kvGameModes.GoBack();
            g_kvGameModes.GoBack();
            g_kvGameModes.GoBack();
        }
        g_kvGameModes.Rewind();
        if (flags[0] != '\0') return;
    }

    if (g_kvGameModes.JumpToKey(gamemode) && g_kvGameModes.JumpToKey("maps")) {
        if (g_kvGameModes.JumpToKey(map)) {
            g_kvGameModes.GetString("nominate_flags", flags, maxlen);
            g_kvGameModes.GoBack();
        }
        g_kvGameModes.GoBack();
        g_kvGameModes.GoBack();
    }
    g_kvGameModes.Rewind();
    if (flags[0] != '\0') return;

    if (strlen(subgroup) > 0) {
        if (g_kvGameModes.JumpToKey(gamemode) && g_kvGameModes.JumpToKey("subgroup") && g_kvGameModes.JumpToKey(subgroup)) {
            g_kvGameModes.GetString("nominate_flags", flags, maxlen);
            g_kvGameModes.GoBack();
            g_kvGameModes.GoBack();
            g_kvGameModes.GoBack();
        }
        g_kvGameModes.Rewind();
        if (flags[0] != '\0') return;
    }

    if (g_kvGameModes.JumpToKey(gamemode)) {
        g_kvGameModes.GetString("nominate_flags", flags, maxlen);
        g_kvGameModes.GoBack();
    }
    g_kvGameModes.Rewind();
}

stock bool CanClientNominate(int client, const char[] gamemode, const char[] subgroup, const char[] map)
{
    char flags[32];
    GetNominateFlags(gamemode, subgroup, map, flags, sizeof(flags));

    // If no flags are defined, anyone can nominate.
    if (flags[0] == '\0') {
        return true;
    }

    int requiredFlags = ReadFlagString(flags);
    
    return CheckCommandAccess(client, "", requiredFlags, true);
}

stock void ParseGameModes()
{
    ArrayList list = GetGameModesList();
    list.Clear();
    
    if (g_kvGameModes.GotoFirstSubKey())
    {
        do
        {
            GameModeConfig config;
            g_kvGameModes.GetSectionName(config.name, sizeof(config.name));
            
            if (g_kvGameModes.JumpToKey("serverconfig"))
            {
                g_kvGameModes.GetString("command", config.command, sizeof(config.command), "");
                g_kvGameModes.GoBack();
            }
            
            config.maps = new ArrayList(ByteCountToCells(256));
            config.subGroups = new ArrayList(sizeof(SubGroupConfig));
            
            if (g_kvGameModes.JumpToKey("maps"))
            {
                if (g_kvGameModes.GotoFirstSubKey(false))
                {
                    do
                    {
                        char mapName[256];
                        g_kvGameModes.GetSectionName(mapName, sizeof(mapName));
                        config.maps.PushString(mapName);
                    } while (g_kvGameModes.GotoNextKey(false));
                    g_kvGameModes.GoBack();
                }
                g_kvGameModes.GoBack();
            }
            
            if (g_kvGameModes.JumpToKey("subgroup"))
            {
                if (g_kvGameModes.GotoFirstSubKey(false))
                {
                    do
                    {
                        SubGroupConfig subConfig;
                        g_kvGameModes.GetSectionName(subConfig.name, sizeof(subConfig.name));
                        
                        subConfig.enabled = g_kvGameModes.GetNum("enabled", 1);
                        subConfig.adminonly = g_kvGameModes.GetNum("adminonly", 0);
                        subConfig.minplayers = g_kvGameModes.GetNum("minplayers", 0);
                        subConfig.maxplayers = g_kvGameModes.GetNum("maxplayers", 0);
                        subConfig.maps_invote = g_kvGameModes.GetNum("maps_invote", 6);
                        
                        g_kvGameModes.GetString("command", subConfig.command, sizeof(subConfig.command), "");
                        g_kvGameModes.GetString("pre-command", subConfig.pre_command, sizeof(subConfig.pre_command), "");
                        g_kvGameModes.GetString("vote-command", subConfig.vote_command, sizeof(subConfig.vote_command), "");
                        
                        subConfig.maps = new ArrayList(ByteCountToCells(256));
                        
                        if (g_kvGameModes.JumpToKey("maps"))
                        {
                            if (g_kvGameModes.GotoFirstSubKey(false))
                            {
                                do
                                {
                                    char mapName[256];
                                    g_kvGameModes.GetSectionName(mapName, sizeof(mapName));
                                    subConfig.maps.PushString(mapName);
                                } while (g_kvGameModes.GotoNextKey(false));
                                g_kvGameModes.GoBack();
                            }
                            g_kvGameModes.GoBack();
                        }
                        
                        config.subGroups.PushArray(subConfig);
                    } while (g_kvGameModes.GotoNextKey(false));
                    g_kvGameModes.GoBack();
                }
                g_kvGameModes.GoBack();
            }
            
            config.maps_invote = g_kvGameModes.GetNum("maps_invote", 6);
            list.PushArray(config);
        } while (g_kvGameModes.GotoNextKey());
    }
    
    Call_StartFunction(null, GetFunctionByName(null, "OnGamemodeConfigLoaded"));
    Call_Finish();
}

stock bool IsSubgroupValid(const GameModeConfig config, int subIndex)
{
    SubGroupConfig subCfg;
    config.subGroups.GetArray(subIndex, subCfg);
    int players = GetRealClientCount();

    return subCfg.enabled &&
           !subCfg.adminonly &&
           (subCfg.minplayers == 0 || players >= subCfg.minplayers) &&
           (subCfg.maxplayers == 0 || players <= subCfg.maxplayers);
}

stock void SplitGamemodeString(const char[] fullString, char[] group, int groupMaxLen, char[] subgroup, int subgroupMaxLen)
{
    subgroup[0] = '\0';
    int slashPos = FindCharInString(fullString, '/');
    if (slashPos != -1)
    {
        strcopy(group, slashPos + 1, fullString);
        strcopy(subgroup, subgroupMaxLen, fullString[slashPos + 1]);
    }
    else
    {
        strcopy(group, groupMaxLen, fullString);
    }
}

public int SortByVotes(int index1, int index2, const ArrayList list, Handle hndl)
{
    VoteCandidate cand1, cand2;
    list.GetArray(index1, cand1);
    list.GetArray(index2, cand2);
    return cand2.votes - cand1.votes;
}

int GetRealClientCount()
{
    int count = 0;
    for(int i = 1; i <= MaxClients; i++) {
        if(IsClientInGame(i) && !IsFakeClient(i)) {
            count++;
        }
    }
    return count;
}

stock void ExecuteModeCommands(const char[] gamemode)
{
    char sCommand[255];
    if (g_kvGameModes.JumpToKey(gamemode))
    {
        if (g_kvGameModes.GetString("command", sCommand, sizeof(sCommand)))
        {
            ServerCommand(sCommand);
        }
        g_kvGameModes.Rewind();
    }
}