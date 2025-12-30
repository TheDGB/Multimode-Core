/**
 * MultiMode Random Cycle Include
 * 
 * Provides forwards and natives for plugins to hook into random cycle events
 */

#if defined _multimode_randomcycle_included
    #endinput
#endif
#define _multimode_randomcycle_included

#include <multimode>

/**
 * Called when random cycle has selected and set the next map.
 * This forward is called after the random cycle plugin has successfully set a next map.
 * 
 * @param map           The map that was selected by random cycle
 * @param group         The gamemode/group name (empty if none)
 * @param subgroup      The subgroup name (empty if none)
 * @noreturn
 */
forward void MultiMode_OnRandomCycleMapSet(const char[] map, const char[] group, const char[] subgroup);

/**
 * Checks if random cycle is enabled.
 * 
 * @return              True if random cycle is active and enabled.
 */
native bool MultiMode_IsRandomCycleEnabled();

public SharedPlugin __pl_multimode_randomcycle = 
{
    name = "multimode_randomcycle",
    file = "multimode_randomcycle.smx",
#if defined REQUIRE_PLUGIN
    required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_multimode_randomcycle_SetNTVOptional()
{
    MarkNativeAsOptional("MultiMode_IsRandomCycleEnabled");
}
#endif

