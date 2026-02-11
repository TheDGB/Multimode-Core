#if defined _multimode_included
    #endinput
#endif
#define _multimode_included

#include <multimode/base>


/**
 * Callback signature for starting a vote.
 * IMPORTANT: The 'items' ArrayList is CLONED for the receiving plugin.
 * The receiver MUST delete/close 'items' when finished to prevent memory leaks.
 * 
 * @param initiator     Client index who started the vote (0 for server).
 * @param type          The type of vote (Group, Map, etc.).
 * @param info          Context info (e.g., Gamemode Name for map votes).
 * @param items         ArrayList of VoteCandidate structs. (OWNERSHIP TRANSFERRED)
 * @param duration      Duration of the vote in seconds.
 * @param adminVote     True if this is an admin-forced vote.
 * @param isRunoff      True if this is a runoff vote.
 * @param startSound    Sound to play when vote starts (empty if not specified).
 * @param endSound      Sound to play when vote ends (empty if not specified).
 * @param runoffstartSound Sound to play when runoff vote starts (empty if not specified).
 * @param runoffendSound   Sound to play when runoff vote ends (empty if not specified).
 */
typedef VoteStartCallback = function void (
    int initiator,
    VoteType type,
    const char[] info,
    ArrayList items, 
    int duration,
    bool adminVote,
    bool isRunoff,
    const char[] startSound,
    const char[] endSound,
    const char[] runoffstartSound,
    const char[] runoffendSound
);

/**
 * Callback signature for cancelling a vote.
 */
typedef VoteCancelCallback = function void ();

/**
 * Starts an Advanced Multimode Core vote.
 *
 * @param id                  Unique identifier for the vote instance.
 * @param mapcycle            The mapcycle file or section to use for the vote.
 * @param type                Type of vote being started. (Group then maps, groups only, maps only)
 * @param time                Duration the vote remains active (in seconds).
 * @param timing              Determines the timing conditions for when this vote is triggered.
 * @param startSound          Sound to be played when the vote starts.
 * @param endSound            Sound to be played when the vote ends.
 * @param extendOption        Determines whether an "Extend Map" option is displayed.
 * @param timestep            Amount of time to extend the time limit when "Extend Map" is selected.
 * @param fragstep            Amount of frag limit to extend when "Extend Map" is selected.
 * @param roundstep           Amount of round limit to extend when "Extend Map" is selected.
 * @param groupexclude        Determines if a previously played group can appear in the vote. (-1 = Use default config)
 * @param mapexclude          Determines if a previously played map can appear in the vote. (-1 = Use default config)
 * @param handlenominations   Specifies how nominations should be handled. (1 - Handle player's nominations, 0 - Do not handle player's nominations)
 * @param threshold           Percentage required for a vote to win.
 * @param maxRunoffs          Maximum number of runoff votes allowed. (0 = No limit)
 * @param maxRunoffInVote     Maximum number of items allowed in runoff votes. (0 = No limit)
 * @param runoffFailAction    Action to take if the maximum number of runoffs is reached with no winner.
 * @param runoffstartSound    Sound to be played when a runoff vote begins.
 * @param runoffendSound      Sound to be played when a runoff vote ends.
 * @param sorted              Determines how vote items are sorted. (0 = Random, 1 = Mapcycle Order)
 * @param clients             Array of client indices to show the vote to. Pass null to show to all eligible clients.
 * @param numClients          Number of clients to read from clients array. Ignored if clients is null.
 * @param adminvote           Determines whether a vote is a administrator vote or not.
 *
 * @return True on success, false on failure.
 */
native bool Multimode_StartVote(
    const char[] id,
    const char[] mapcycle,
    MultimodeMethodType type,
    int time,
    TimingMode timing,
    const char[] startSound = "",
    const char[] endSound = "",
    bool extendOption = true,
    int timestep = 6,
    int fragstep = 10,
    int roundstep = 3,
    int groupexclude = -1,
    int mapexclude = -1,
    bool handlenominations = true,
    float threshold = 0.6,
    int maxRunoffs = 3,
    int maxRunoffInVote = 3,
    MultimodeRunoffFailAction runoffFailAction = RUNOFF_FAIL_PICK_FIRST,
    const char[] runoffstartSound = "",
    const char[] runoffendSound = "",
    MultimodeVoteSorted sorted = SORTED_MAPCYCLE_ORDER,
    int clients[MAXPLAYERS + 1],
    int numClients = 0,
    bool adminvote = false
);

/**
 * Starts a simple vote (groups then maps).
 * 
 * @param client        Client who started the vote (0 for server).
 * @param adminVote     True if this is an admin-forced vote.
 * @return              True on success, false on failure.
 */
native bool MultiMode_StartVote(int client, bool adminVote);

/**
 * Stops/cancels the current active vote.
 * 
 * @return              True if a vote was active and cancelled, false otherwise.
 */
native bool MultiMode_StopVote();

/**
 * Checks if a vote can be cancelled (is active or in cooldown).
 * 
 * @return              True if a vote can be cancelled.
 */
native bool MultiMode_CanStopVote();

/**
 * Checks if a vote is active.
 * 
 * @return              True if a vote is in progress.
 */
native bool MultiMode_IsVoteActive();

/**
 * Checks if cooldown is active.
 * 
 * @return              True if cooldown is active.
 */
native bool MultiMode_IsCooldownActive();

/**
 * Checks if a vote has been completed.
 * 
 * @return              True if a vote has been completed.
 */
native bool MultiMode_IsVoteCompleted();

/**
 * Gets the current vote ID.
 * 
 * @param buffer        Buffer to store the vote ID.
 * @param maxlen        Maximum length of the buffer.
 * @return              True if a vote is active and ID was retrieved, false otherwise.
 */
native bool MultiMode_GetCurrentVoteId(char[] buffer, int maxlen);

/**
 * Sets the next map (equivalent to multimode_setnextmap command).
 * 
 * @param map           Map name to set as next map.
 * @param timing        Timing mode: 1 = Next Map, 2 = Next Round, 3 = Instant.
 * @param gamemode      Gamemode name (optional, empty string to auto-detect).
 * @param subgroup      Subgroup name (optional, empty string if not specified).
 * @return              True on success, false on failure.
 */
native bool MultiMode_SetNextMap(const char[] map, int timing, const char[] gamemode = "", const char[] subgroup = "");

/**
 * Checks if a specific gamemode or subgroup is nominated.
 * 
 * @param group         Gamemode name.
 * @param subgroup      Optional subgroup name. If empty, checks for a nomination under the main group only.
 * @return              True if the gamemode/subgroup is nominated.
 */
native bool MultiMode_IsGroupNominated(const char[] group, const char[] subgroup = "");

/**
 * Checks if a specific map from a gamemode/subgroup is nominated.
 * 
 * @param group         Gamemode name.
 * @param subgroup      Subgroup name (can be empty for base group).
 * @param map           Map name to check.
 * @return              True if the map is nominated for the gamemode/subgroup.
 */
native bool MultiMode_IsMapNominated(const char[] group, const char[] subgroup, const char[] map);

/**
 * Gets the current gamemode and subgroup.
 * The internal format "group/subgroup" is split into the two buffers.
 * 
 * @param group         Buffer to store the gamemode name.
 * @param groupMaxLen   Maximum buffer size for the group.
 * @param subgroup      Buffer to store the subgroup name. Will be empty if none.
 * @param subgroupMaxLen Maximum buffer size for the subgroup.
 * @noreturn
 */
native void MultiMode_GetCurrentGameMode(char[] group, int groupMaxLen, char[] subgroup, int subgroupMaxLen);

/**
 * Gets the next gamemode and subgroup.
 * The internal format "group/subgroup" is split into the two buffers.
 * 
 * @param group         Buffer to store the next gamemode name.
 * @param groupMaxLen   Maximum buffer size for the group.
 * @param subgroup      Buffer to store the next subgroup name. Will be empty if none.
 * @param subgroupMaxLen Maximum buffer size for the subgroup.
 * @noreturn
 */
native void MultiMode_GetNextGameMode(char[] group, int groupMaxLen, char[] subgroup, int subgroupMaxLen);

/**
 * Gets the next scheduled map.
 * 
 * @param buffer        Buffer to store the map name.
 * @param maxlength     Maximum buffer size.
 * @noreturn
 */
native void MultiMode_GetNextMap(char[] buffer, int maxlength);

/**
 * Gets the server's current map.
 * 
 * @param buffer        Buffer to store the map name.
 * @param maxlength     Maximum buffer size.
 * @noreturn
 */
native void MultiMode_GetCurrentMap(char[] buffer, int maxlength);

/**
 * Gets a random map from a specific gamemode or subgroup.
 * If group is empty, selects a random gamemode.
 * If subgroup is empty, selects from the base group or a random subgroup.
 *
 * @param group         Gamemode name. Can be empty for any gamemode.
 * @param groupLen      Length of the gamemode buffer.
 * @param subgroup      Subgroup name. Can be empty.
 * @param subgroupLen   Length of the subgroup buffer.
 * @param map           Buffer to store the map name (out).
 * @param maxlength     Maximum buffer size for the map.
 * @return              True if a map was found and stored, false otherwise.
 */
native bool MultiMode_GetRandomMap(char[] group, int groupLen, char[] subgroup, int subgroupLen, char[] map, int maxlength);

/**
 * Gets a list of all available gamemodes.
 * 
 * @param gamemodes           ArrayList to populate with gamemode names (char[64]).
 * @param includeDisabled     Include disabled gamemodes.
 * @param includeAdminOnly    Include admin-only gamemodes.
 * @return                    Number of gamemodes added.
 */
native int Multimode_GetGamemodeList(ArrayList gamemodes, bool includeDisabled = false, bool includeAdminOnly = false);

/**
 * Gets a list of subgroups for a specific gamemode.
 * 
 * @param gamemode            Gamemode name.
 * @param subgroups           ArrayList to populate with subgroup names (char[64]).
 * @param includeDisabled     Include disabled subgroups.
 * @param includeAdminOnly    Include admin-only subgroups.
 * @return                    Number of subgroups added, -1 if gamemode not found.
 */
native int Multimode_GetSubgroupList(const char[] gamemode, ArrayList subgroups, bool includeDisabled = false, bool includeAdminOnly = false);

/**
 * Gets a list of maps for a gamemode/subgroup.
 * 
 * @param gamemode            Gamemode name.
 * @param subgroup            Subgroup name (empty for base group).
 * @param maps                ArrayList to populate with map names (char[PLATFORM_MAX_PATH]).
 * @return                    Number of maps added, -1 if gamemode/subgroup not found.
 */
native int Multimode_GetMapList(const char[] gamemode, const char[] subgroup, ArrayList maps);

/**
 * Adds a player nomination for a gamemode, an optional subgroup, and a map.
 * 
 * @param client        Client who is nominating.
 * @param group         Gamemode name.
 * @param subgroup      Subgroup name (can be empty).
 * @param map           Map name.
 * @return              True if the nomination was successful.
 */
native bool MultiMode_Nominate(int client, const char[] group, const char[] subgroup, const char[] map);

/**
 * Removes a specific nomination from a client.
 * 
 * @param client        Client who owns the nomination.
 * @param index         Index of the nomination to remove (0-based).
 * @return              True if the nomination was removed successfully.
 */
native bool MultiMode_RemoveNomination(int client, int index);

/**
 * Removes all nominations from a client.
 * 
 * @param client        Client who owns the nominations.
 * @return              Number of nominations removed.
 */
native int MultiMode_RemoveAllNominations(int client);

/**
 * Gets the number of nominations a client has.
 * 
 * @param client        Client to check.
 * @return              Number of nominations.
 */
native int MultiMode_GetClientNominationCount(int client);

/**
 * Gets a client's nomination information.
 * 
 * @param client        Client to check.
 * @param index         Index of the nomination (0-based).
 * @param group         Buffer to store the gamemode name.
 * @param groupMaxLen   Maximum buffer size for the group.
 * @param subgroup      Buffer to store the subgroup name.
 * @param subgroupMaxLen Maximum buffer size for the subgroup.
 * @param map           Buffer to store the map name.
 * @param mapMaxLen     Maximum buffer size for the map.
 * @return              True if the nomination was retrieved successfully.
 */
native bool MultiMode_GetClientNomination(int client, int index, char[] group, int groupMaxLen, char[] subgroup, int subgroupMaxLen, char[] map, int mapMaxLen);

/**
 * Gets the display name for a map, using custom display names from the mapcycle if available.
 * 
 * @param gamemode      Gamemode name (can be empty to search all gamemodes).
 * @param map           Map name (technical name).
 * @param subgroup      Subgroup name (can be empty).
 * @param display       Buffer to store the display name.
 * @param maxlength     Maximum buffer size for the display name.
 * @noreturn
 */
native void MultiMode_GetMapDisplayName(const char[] gamemode, const char[] map, const char[] subgroup, char[] display, int maxlength);

/**
 * Checks if a gamemode is in the recently played list.
 * 
 * @param gamemode      Gamemode name to check.
 * @param excludeCount  Number of recently played gamemodes to check (0 = check all).
 * @return              True if the gamemode is recently played within the exclusion count, false otherwise.
 */
native bool MultiMode_IsGamemodeRecentlyPlayed(const char[] gamemode, int excludeCount = 0);

/**
 * Checks if a map is in the recently played list for a specific gamemode.
 * 
 * @param gamemode      Gamemode name.
 * @param map           Map name to check.
 * @param subgroup      Subgroup name (can be empty).
 * @param excludeCount  Number of recently played maps to check (0 = check all).
 * @return              True if the map is recently played within the exclusion count, false otherwise.
 */
native bool MultiMode_IsMapRecentlyPlayed(const char[] gamemode, const char[] map, const char[] subgroup = "", int excludeCount = 0);

/**
 * Checks if a subgroup is in the recently played list for a specific gamemode.
 * 
 * @param gamemode      Gamemode name.
 * @param subgroup      Subgroup name.
 * @param excludeCount  Number of recently played subgroups to check (0 = check all).
 * @return              True if the subgroup is recently played within the exclusion count, false otherwise.
 */
native bool MultiMode_IsSubGroupRecentlyPlayed(const char[] gamemode, const char[] subgroup, int excludeCount = 0);

/**
 * Called when a vote starts.
 * 
 * @param initiator     Client who started the vote (0 for automatic system).
 */
forward void MultiMode_OnVoteStart(int initiator);

/**
 * Called when a vote starts (extended version).
 * 
 * @param initiator     Client who started the vote (0 for automatic system).
 * @param voteType      Type of vote (see VoteType enum, EX: VOTE_TYPE_GROUP, VOTE_TYPE_SUBGROUP, VOTE_TYPE_MAP, VOTE_TYPE_SUBGROUP_MAP).
 * @param isRunoff      True if this is a runoff vote.
 */
forward void MultiMode_OnVoteStartEx(int initiator, int voteType, bool isRunoff);

/**
 * Called when a vote ends.
 * 
 * @param group         Chosen gamemode. Can be "extend".
 * @param subgroup      Chosen subgroup (if any).
 * @param map           Chosen map (if any).
 * @param reason        The reason the vote ended (e.g., VoteEnd_Winner, VoteEnd_Runoff, VoteEnd_Extend, VoteEnd_Cancelled, VoteEnd_Failed).
 */
forward void MultiMode_OnVoteEnd(const char[] group, const char[] subgroup, const char[] map, VoteEndReason reason);

/**
 * Called when the core needs to get the weight/rating for an item.
 * Plugins can implement this to provide dynamic weights based on ratings or other factors.
 * 
 * @param group          Gamemode/group name (empty for map-only queries).
 * @param subgroup       Subgroup name (empty if not applicable).
 * @param map            Map name (empty for group/subgroup queries).
 * @param itemType       Type of item: 0=GROUP, 1=SUBGROUP, 2=MAP.
 * @return               Rating value (1.0-5.0) if available, or -1.0 if not rated/available.
 */
forward float MultiMode_OnGetItemWeight(const char[] group, const char[] subgroup, const char[] map, int itemType);

/**
 * Callback signature for starting a vote.
 * 
 * @param initiator     Client index who started the vote (0 for server).
 * @param type          The type of vote (Group, Map, etc.).
 * @param items         ArrayList of VoteCandidate structs containing {info, name(display)}. 
 *                      The manager should clone this if it needs to keep it after the call.
 * @param duration      Duration of the vote in seconds.
 * @param adminVote     True if this is an admin-forced vote.
 * @param isRunoff      True if this is a runoff vote.
 */

/**
 * Registers a new Vote Manager
 * Uses the same callback for all vote types (Group, SubGroup, Map).
 * 
 * @param name          Unique identifier for the manager (e.g., "core", "nativevotes").
 * @param startCb       Function to call when starting ANY vote.
 * @param cancelCb      Function to call when cancelling a vote.
 */
native void MultiMode_RegisterVoteManager(const char[] name, VoteStartCallback startCb, VoteCancelCallback cancelCb);

/**
 * Registers a new Vote Manager (Extended Version).
 * Allows defining separate callbacks for Groups, SubGroups, and Maps.
 * 
 * @param name          Unique identifier for the manager.
 * @param cbGroup       Callback specifically for Group votes.
 * @param cbSubGroup    Callback specifically for SubGroup votes.
 * @param cbMap         Callback specifically for Map votes.
 * @param cbCancel      Function to call when cancelling a vote.
 */
native void MultiMode_RegisterVoteManagerEx(const char[] name, VoteStartCallback cbGroup, VoteStartCallback cbSubGroup, VoteStartCallback cbMap, VoteCancelCallback cbCancel);

/**
 * Unregisters a Vote Manager.
 * 
 * @param name          Unique identifier of the manager.
 */
native void MultiMode_UnregisterVoteManager(const char[] name);

/**
 * Reports the results of a vote back to the Core.
 * The Manager must call this when a vote finishes.
 * 
 * @param results       ArrayList of VoteCandidate structs with 'votes' populated.
 * @param totalVotes    Total number of votes cast.
 * @param totalClients  Total number of eligible voters.
 */
native void MultiMode_ReportVoteResults(ArrayList results, int totalVotes, int totalClients);


/**
 * Called when a new gamemode is set via force command or other non-vote mechanism.
 * 
 * @param group         New gamemode.
 * @param subgroup      New subgroup.
 * @param map           New map.
 * @param timing        Application timing (0=Next map, 1=Next round, 2=Instant).
 */
forward void MultiMode_OnGamemodeChanged(const char[] group, const char[] subgroup, const char[] map, int timing);

/**
 * Called when a new gamemode is set as the result of a vote.
 * 
 * @param group         New gamemode.
 * @param subgroup      New subgroup.
 * @param map           New map.
 * @param timing        Application timing (0=Next map, 1=Next round, 2=Instant).
 */
forward void MultiMode_OnGamemodeChangedVote(const char[] group, const char[] subgroup, const char[] map, int timing);

/**
 * Called when the core (re)loads the map cycle (e.g. LoadGameModesConfig, OnConfigsExecuted, multimode_reload).
 * Plugins that cache the map cycle KeyValues should listen to this and reload their cache (e.g. via MMC_GetMapCycle()).
 */
forward void MultiMode_OnMapCycleReloaded();

public SharedPlugin __pl_multimode_core = {
    name = "multimode_core",
    file = "multimode_core.smx",
#if defined REQUIRE_PLUGIN
    required = 1,
#else
    required = 0,
#endif
};