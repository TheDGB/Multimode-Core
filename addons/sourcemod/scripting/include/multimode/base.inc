/**
 * MultiMode Core Base
 * 
 * Some bases for the multimode core to work...
 */

#if defined _multimode_base_included
 #endinput
#endif
#define _multimode_base_included

#define PLUGIN_VERSION "3.4.5++"

// Map Cycle Configuration Keys
#include <multimode/mapcyclecommands>

#include <adt_array>

enum MultimodeMethodType
{
    VOTE_TYPE_GROUPS_THEN_MAPS = 1,
    VOTE_TYPE_GROUPS_ONLY = 2,
    VOTE_TYPE_MAPS_ONLY = 3
}

enum TimingMode
{
    TIMING_NEXTMAP = 0,
    TIMING_NEXTROUND,
    TIMING_INSTANT
}

enum MultimodeRunoffFailAction
{
    RUNOFF_FAIL_PICK_FIRST = 0,
    RUNOFF_FAIL_DO_NOTHING = 1
}

enum MultimodeVoteSorted
{
    SORTED_ALPHABETICAL = 0,
    SORTED_RANDOM = 1,
    SORTED_MAPCYCLE_ORDER = 2
}

#define MAX_GAMEMODES 64
#define MAX_MAPS_PER_MODE 128
#define MAX_SUBGROUPS_PER_MODE 16

enum struct NominationInfo
{
    char group[64];
    char subgroup[64];
    char map[PLATFORM_MAX_PATH];
}

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

enum struct AdvancedVoteConfig {
    char id[64];
    char mapcycle[256];
    MultimodeMethodType type;
    int time;
    TimingMode timing;
    char startSound[PLATFORM_MAX_PATH];
    char endSound[PLATFORM_MAX_PATH];
    bool extendOption;
    int timestep;
    int fragstep;
    int roundstep;
    int groupexclude;
    int mapexclude;
    bool handlenominations;
    float threshold;
    int maxRunoffs;
    int maxRunoffInVote;
    MultimodeRunoffFailAction runoffFailAction;
    char runoffstartSound[PLATFORM_MAX_PATH];
    char runoffendSound[PLATFORM_MAX_PATH];
    MultimodeVoteSorted sorted;
    bool adminvote;
    ArrayList targetClients;
    VoteType voteType;
    char contextInfo[128];
    ArrayList runoffItems;
}

enum struct SubGroupConfig {
    char name[64];
    char config[256];
    char command[256];
    char pre_command[256];
    char vote_command[256];
    int adminonly;
    int enabled;
    int maxplayers;
    int minplayers;
    int mintime;
    int maxtime;
    char nominate_flags[32];
    ArrayList maps;
    int maps_invote;
}

enum struct GameModeConfig {
    char name[64];
    char config[256];
    char command[256];
    char pre_command[256];
    char vote_command[256];
    int maps_invote;
    int subgroups_invote;
    int adminonly;
    int enabled;
    int maxplayers;
    int minplayers;
    int mintime;
    int maxtime;
    char nominate_flags[32];
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

KeyValues g_kvGameModes;

stock void GetNominateFlags(const char[] gamemode, const char[] subgroup, const char[] map, char[] flags, int maxlen)
{
    flags[0] = '\0';

    if (strlen(subgroup) > 0) {
        if (g_kvGameModes.JumpToKey(gamemode) && g_kvGameModes.JumpToKey("subgroup") && g_kvGameModes.JumpToKey(subgroup) && g_kvGameModes.JumpToKey("maps")) {
            if (g_kvGameModes.JumpToKey(map)) {
                g_kvGameModes.GetString(MAPCYCLE_KEY_NOMINATE_FLAGS, flags, maxlen);
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
            g_kvGameModes.GetString(MAPCYCLE_KEY_NOMINATE_FLAGS, flags, maxlen);
            g_kvGameModes.GoBack();
        }
        g_kvGameModes.GoBack();
        g_kvGameModes.GoBack();
    }
    g_kvGameModes.Rewind();
    if (flags[0] != '\0') return;

    if (strlen(subgroup) > 0) {
        if (g_kvGameModes.JumpToKey(gamemode) && g_kvGameModes.JumpToKey("subgroup") && g_kvGameModes.JumpToKey(subgroup)) {
            g_kvGameModes.GetString(MAPCYCLE_KEY_NOMINATE_FLAGS, flags, maxlen);
            g_kvGameModes.GoBack();
            g_kvGameModes.GoBack();
            g_kvGameModes.GoBack();
        }
        g_kvGameModes.Rewind();
        if (flags[0] != '\0') return;
    }

    if (g_kvGameModes.JumpToKey(gamemode)) {
        g_kvGameModes.GetString(MAPCYCLE_KEY_NOMINATE_FLAGS, flags, maxlen);
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
        // Copy group part (up to but not including the slash)
        int copyLen = slashPos;
        if (copyLen >= groupMaxLen) copyLen = groupMaxLen - 1;
        strcopy(group, groupMaxLen, fullString);
        group[copyLen] = '\0';
        
        // Copy subgroup part (after the slash)
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