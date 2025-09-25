#if defined _multimode_included
    #endinput
#endif
#define _multimode_included

/**
 * Starts a gamemode/map vote
 * 
 * @param client        Client who started the vote (0 for server)
 * @param adminVote     True if it's an admin vote
 * @noreturn
 */
native void MultiMode_StartVote(int client, bool adminVote = false);

/**
 * Stops/cancels the current active vote
 * 
 * @return              True if a vote was active and cancelled, false otherwise
 */
native bool MultiMode_StopVote();

/**
 * Checks if a vote can be cancelled (is active or in cooldown)
 * 
 * @return              True if a vote can be cancelled
 */
native bool MultiMode_CanStopVote();

/**
 * Checks if a vote is active
 * 
 * @return              True if a vote is in progress
 */
native bool MultiMode_IsVoteActive();

/**
 * Checks if a specific gamemode is nominated
 * 
 * @param group         Gamemode name
 * @return              True if the gamemode is nominated
 */
native bool MultiMode_IsGroupNominated(const char[] group);

/**
 * Checks if a specific map from a gamemode is nominated
 * 
 * @param group         Gamemode name
 * @param map           Map name to check
 * @return              True if the map is nominated for the gamemode
 */
native bool MultiMode_IsMapNominated(const char[] group, const char[] map);

/**
 * Gets the current gamemode
 * 
 * @param buffer        Buffer to store the gamemode name
 * @param maxlength     Maximum buffer size
 * @noreturn
 */
native void MultiMode_GetCurrentGameMode(char[] buffer, int maxlength);

/**
 * Gets the next gamemode
 * 
 * @param buffer        Buffer to store the next gamemode name
 * @param maxlength     Maximum buffer size
 * @noreturn
 */
native void MultiMode_GetNextGameMode(char[] buffer, int maxlength);

/**
 * Gets the next scheduled map
 * 
 * @param buffer        Buffer to store the map name
 * @param maxlength     Maximum buffer size
 * @noreturn
 */
native void MultiMode_GetNextMap(char[] buffer, int maxlength);

/**
 * Gets the server's current map
 * 
 * @param buffer        Buffer to store the map name
 * @param maxlength     Maximum buffer size
 * @noreturn
 */
native void MultiMode_GetCurrentMap(char[] buffer, int maxlength);

/**
 * Gets a random map from a specific gamemode. If gamemode is empty, 
 * selects a random gamemode and then a random map from it.
 *
 * @param group         Gamemode name (empty for any gamemode).
 * @param groupLen      Length of the gamemode buffer.
 * @param map           Buffer to store the map name.
 * @param maxlength     Maximum buffer size for the map.
 * @return              True if a map was found and stored, false otherwise.
 */
native bool MultiMode_GetRandomMap(char[] group, int groupLen, char[] map, int maxlength);

/**
 * Checks if random cycle is enabled
 * 
 * @return              True if random cycle is active
 */
native bool MultiMode_IsRandomCycleEnabled();

/**
 * Adds a player nomination
 * 
 * @param client        Client who is nominating
 * @param group         Gamemode name
 * @param map           Map name
 * @return              True if the nomination was successful
 */
native bool MultiMode_Nominate(int client, const char[] group, const char[] map);

/**
 * Called when a vote starts
 * 
 * @param initiator     Client who started the vote (0 for automatic system)
 */
forward void MultiMode_OnVoteStart(int initiator);

/**
 * Called when a vote starts (extended version)
 * 
 * @param initiator     Client who started the vote (0 for automatic system)
 * @param voteType      Type of vote: 0 = gamemode vote, 1 = map vote
 */
forward void MultiMode_OnVoteStartEx(int initiator, int voteType);

/**
 * Called when a vote ends
 * 
 * @param group         Chosen gamemode ("extend" if extending)
 * @param map           Chosen map
 */
forward void MultiMode_OnVoteEnd(const char[] group, const char[] map);

/**
 * Called when a new gamemode is set
 * 
 * @param group        New gamemode
 * @param map           New map
 * @param timing        Application timing (0=Next map, 1=Next round, 2=Instant)
 */
forward void MultiMode_OnGamemodeChanged(const char[] group, const char[] map, int timing);

/**
 * Called when a new gamemode is set in votes
 * 
 * @param group         New gamemode
 * @param map           New map
 * @param timing        Application timing (0=Next map, 1=Next round, 2=Instant)
 */
forward void MultiMode_OnGamemodeChangedVote(const char[] group, const char[] map, int timing);

public SharedPlugin __pl_multimode_core = {
    name = "multimode_core",
    file = "multimode_core.smx",
#if defined REQUIRE_PLUGIN
    required = 1,
#else
    required = 0,
#endif
};