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
 */
typedef VoteStartCallback = function void (
    int initiator,
    VoteType type,
    const char[] info,
    ArrayList items, 
    int duration,
    bool adminVote,
    bool isRunoff
);

/**
 * Callback signature for cancelling a vote.
 */
typedef VoteCancelCallback = function void ();

/**
 * Starts a gamemode/map vote.
 * 
 * @param client        Client who started the vote (0 for server).
 * @param adminVote     True if it's an admin vote.
 * @noreturn
 */
native void MultiMode_StartVote(int client, bool adminVote = false);

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
 * Checks if random cycle is enabled.
 * 
 * @return              True if random cycle is active.
 */
native bool MultiMode_IsRandomCycleEnabled();

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
 * Registers a new Vote Manager.
 * 
 * @param name          Unique identifier for the manager (e.g., "core", "nativevotes").
 * @param startCb       Function to call when starting a vote.
 * @param cancelCb      Function to call when cancelling a vote.
 */
native void MultiMode_RegisterVoteManager(const char[] name, VoteStartCallback startCb, VoteCancelCallback cancelCb);

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

public SharedPlugin __pl_multimode_core = {
    name = "multimode_core",
    file = "multimode_core.smx",
#if defined REQUIRE_PLUGIN
    required = 1,
#else
    required = 0,
#endif
};