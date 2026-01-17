/**
 * MultiMode Downloads API
 * 
 * This include provides natives and forwards for other plugins
 * to interact with the MultiMode Downloads system.
 */

#if defined _multimode_downloads_included
 #endinput
#endif
#define _multimode_downloads_included

/**
 * Called when downloads are being collected for a gamemode, subgroup, or map.
 * Other plugins can hook this to add files dynamically or react to the context.
 * 
 * @param group         Gamemode name.
 * @param subgroup      Subgroup name (empty if not applicable).
 * @param map           Map name.
 * @param context       Context identifier: "current" or "gamemode".
 */
forward void MultiMode_Downloads_OnDownloadsCollect(const char[] group, const char[] subgroup, const char[] map, const char[] context);

/**
 * Checks if MultiMode Downloads plugin is registered and loaded.
 * 
 * @return              True if the plugin is loaded, false otherwise.
 */
native bool MultiMode_Downloads_IsRegistered();

/**
 * Applies/downloads all files for the specified gamemode, subgroup, or map.
 * Executes all precache and downloads that have been collected.
 * If parameters are empty, uses the current gamemode/subgroup/map.
 * 
 * @param group         Gamemode name (optional, empty to use current).
 * @param subgroup      Subgroup name (optional, empty to use current).
 * @param map           Map name (optional, empty to use current).
 * @return              True on success, false on failure.
 */
native bool MultiMode_Downloads_Apply(const char[] group = "", const char[] subgroup = "", const char[] map = "");

/**
 * Adds a file to the download table.
 * Can be called by other plugins to dynamically add files.
 * 
 * @param filePath      Path to the file to add (relative to game root).
 * @param context       Context identifier (for logging purposes, optional).
 * @param autoDownload  If true, processes auto-download logic (models/materials).
 * @return              True if the file was added, false otherwise.
 */
native bool MultiMode_Downloads_AddDownload(const char[] filePath, const char[] context = "", bool autoDownload = false);

/**
 * Adds a model to precache.
 * Can be called by other plugins to dynamically add models.
 * 
 * @param modelPath     Path to the model file (.mdl, relative to game root).
 * @param context       Context identifier (for logging purposes, optional).
 * @return              True if the model was precached, false otherwise.
 */
native bool MultiMode_Downloads_AddPrecacheModel(const char[] modelPath, const char[] context = "");

/**
 * Adds a sound to precache.
 * Can be called by other plugins to dynamically add sounds.
 * 
 * @param soundPath     Path to the sound file (relative to sound/ directory).
 * @param context       Context identifier (for logging purposes, optional).
 * @return              True if the sound was precached, false otherwise.
 */
native bool MultiMode_Downloads_AddPrecacheSound(const char[] soundPath, const char[] context = "");

/**
 * Adds a generic resource to precache.
 * Can be called by other plugins to dynamically add generic resources.
 * 
 * @param genericPath   Path to the generic resource file.
 * @param context       Context identifier (for logging purposes, optional).
 * @return              True if the generic resource was precached, false otherwise.
 */
native bool MultiMode_Downloads_AddPrecacheGeneric(const char[] genericPath, const char[] context = "");

public SharedPlugin __pl_multimode_downloads = {
    name = "multimode_downloads",
    file = "multimode_downloads.smx",
#if defined REQUIRE_PLUGIN
    required = 1,
#else
    required = 0,
#endif
};
