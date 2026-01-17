/*****************************************************************************
                        MultiMode Downloads Plugin
******************************************************************************/

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <multimode>
#include <multimode/base>
#include <multimode/utils>

public Plugin myinfo = 
{
    name = "[MMC] MultiMode Downloads",
    author = "Oppressive Territory",
    description = "Download and precache support for MultiMode Core map cycle",
    version = PLUGIN_VERSION,
    url = ""
}

// KeyValues Section
KeyValues g_kvMapcycle;

// StringMap Section
StringMap g_DownloadedFiles;
StringMap g_PrecachedModels;
StringMap g_PrecachedSounds;
StringMap g_PrecachedGenerics;

// Char Section
char g_sCurrentMap[PLATFORM_MAX_PATH];
char g_sCurrentGroup[64];
char g_sCurrentSubGroup[64];

// Forward Section
Handle g_fwdOnDownloadsCollect;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    RegPluginLibrary("multimode_downloads");
    return APLRes_Success;
}

public void OnPluginStart()
{
    g_DownloadedFiles = new StringMap();
    g_PrecachedModels = new StringMap();
    g_PrecachedSounds = new StringMap();
    g_PrecachedGenerics = new StringMap();
    
    GetCurrentMap(g_sCurrentMap, sizeof(g_sCurrentMap));
    MultiMode_GetCurrentGameMode(g_sCurrentGroup, sizeof(g_sCurrentGroup), g_sCurrentSubGroup, sizeof(g_sCurrentSubGroup));

    g_fwdOnDownloadsCollect = CreateGlobalForward("MultiMode_Downloads_OnDownloadsCollect", ET_Ignore, Param_String, Param_String, Param_String, Param_String);

    CreateNative("MultiMode_Downloads_IsRegistered", Native_IsRegistered);
    CreateNative("MultiMode_Downloads_Apply", Native_Apply);
    CreateNative("MultiMode_Downloads_AddDownload", Native_AddDownload);
    CreateNative("MultiMode_Downloads_AddPrecacheModel", Native_AddPrecacheModel);
    CreateNative("MultiMode_Downloads_AddPrecacheSound", Native_AddPrecacheSound);
    CreateNative("MultiMode_Downloads_AddPrecacheGeneric", Native_AddPrecacheGeneric);
}

public void OnConfigsExecuted()
{
    LoadDownloadsConfig();
    LoadDownloadsForCurrentMap();
}

public void OnMapStart()
{
    g_DownloadedFiles.Clear();
    g_PrecachedModels.Clear();
    g_PrecachedSounds.Clear();
    g_PrecachedGenerics.Clear();
    
    GetCurrentMap(g_sCurrentMap, sizeof(g_sCurrentMap));
    MultiMode_GetCurrentGameMode(g_sCurrentGroup, sizeof(g_sCurrentGroup), g_sCurrentSubGroup, sizeof(g_sCurrentSubGroup));
    
    LoadDownloadsForCurrentMap();
}

public void MultiMode_OnGamemodeChanged(const char[] group, const char[] subgroup, const char[] map, int timing)
{
    strcopy(g_sCurrentGroup, sizeof(g_sCurrentGroup), group);
    strcopy(g_sCurrentSubGroup, sizeof(g_sCurrentSubGroup), subgroup);
    strcopy(g_sCurrentMap, sizeof(g_sCurrentMap), map);
    
    LoadDownloadsForCurrentMap();
}

public void MultiMode_OnGamemodeChangedVote(const char[] group, const char[] subgroup, const char[] map, int timing)
{
    LoadDownloadsForGamemode(group, subgroup, map);
}

public int Native_IsRegistered(Handle plugin, int numParams)
{
    return true;
}

public int Native_Apply(Handle plugin, int numParams)
{
    char group[64];
    char subgroup[64];
    char map[PLATFORM_MAX_PATH];
    
    GetNativeString(1, group, sizeof(group));
    GetNativeString(2, subgroup, sizeof(subgroup));
    GetNativeString(3, map, sizeof(map));
    
    if (strlen(group) == 0)
    {
        strcopy(group, sizeof(group), g_sCurrentGroup);
    }
    if (strlen(subgroup) == 0)
    {
        strcopy(subgroup, sizeof(subgroup), g_sCurrentSubGroup);
    }
    if (strlen(map) == 0)
    {
        strcopy(map, sizeof(map), g_sCurrentMap);
    }
    
    if (StrEqual(group, g_sCurrentGroup) && StrEqual(subgroup, g_sCurrentSubGroup) && StrEqual(map, g_sCurrentMap))
    {
        LoadDownloadsForCurrentMap();
    }
    else
    {
        LoadDownloadsForGamemode(group, subgroup, map);
    }
    
    return 1;
}

public int Native_AddDownload(Handle plugin, int numParams)
{
    char filePath[PLATFORM_MAX_PATH];
    char context[64];
    
    GetNativeString(1, filePath, sizeof(filePath));
    GetNativeString(2, context, sizeof(context));
    bool autoDownload = GetNativeCell(3);
    
    if (strlen(filePath) == 0)
        return 0;
    
    if (strlen(context) == 0)
    {
        strcopy(context, sizeof(context), "plugin");
    }
    
    if (autoDownload)
    {
        ProcessAutoDownload(filePath, context);
    }
    else
    {
        AddFileToDownloadTable(filePath, context);
    }
    
    return 1;
}

public int Native_AddPrecacheModel(Handle plugin, int numParams)
{
    char modelPath[PLATFORM_MAX_PATH];
    char context[64];
    
    GetNativeString(1, modelPath, sizeof(modelPath));
    GetNativeString(2, context, sizeof(context));
    
    if (strlen(modelPath) == 0)
        return 0;
    
    if (strlen(context) == 0)
    {
        strcopy(context, sizeof(context), "plugin");
    }
    
    if (g_PrecachedModels.ContainsKey(modelPath))
        return 1;
    
    if (PrecacheModel(modelPath, true))
    {
        g_PrecachedModels.SetValue(modelPath, true);
        MMC_WriteToLogFile(null, "[MultiMode Downloads] Precached model: %s (context: %s)", modelPath, context);
        return 1;
    }
    
    MMC_WriteToLogFile(null, "[MultiMode Downloads] Failed to precache model: %s (context: %s)", modelPath, context);
    return 0;
}

public int Native_AddPrecacheSound(Handle plugin, int numParams)
{
    char soundPath[PLATFORM_MAX_PATH];
    char context[64];
    
    GetNativeString(1, soundPath, sizeof(soundPath));
    GetNativeString(2, context, sizeof(context));
    
    if (strlen(soundPath) == 0)
        return 0;
    
    if (strlen(context) == 0)
    {
        strcopy(context, sizeof(context), "plugin");
    }
    
    if (g_PrecachedSounds.ContainsKey(soundPath))
        return 1;
    
    if (PrecacheSound(soundPath, true))
    {
        g_PrecachedSounds.SetValue(soundPath, true);
        MMC_WriteToLogFile(null, "[MultiMode Downloads] Precached sound: %s (context: %s)", soundPath, context);
        return 1;
    }
    
    MMC_WriteToLogFile(null, "[MultiMode Downloads] Failed to precache sound: %s (context: %s)", soundPath, context);
    return 0;
}

public int Native_AddPrecacheGeneric(Handle plugin, int numParams)
{
    char genericPath[PLATFORM_MAX_PATH];
    char context[64];
    
    GetNativeString(1, genericPath, sizeof(genericPath));
    GetNativeString(2, context, sizeof(context));
    
    if (strlen(genericPath) == 0)
        return 0;
    
    if (strlen(context) == 0)
    {
        strcopy(context, sizeof(context), "plugin");
    }
    
    if (g_PrecachedGenerics.ContainsKey(genericPath))
        return 1;
    
    if (PrecacheGeneric(genericPath, true))
    {
        g_PrecachedGenerics.SetValue(genericPath, true);
        MMC_WriteToLogFile(null, "[MultiMode Downloads] Precached generic: %s (context: %s)", genericPath, context);
        return 1;
    }
    
    MMC_WriteToLogFile(null, "[MultiMode Downloads] Failed to precache generic: %s (context: %s)", genericPath, context);
    return 0;
}

void LoadDownloadsConfig()
{
    delete g_kvMapcycle;
    g_kvMapcycle = new KeyValues("Mapcycle");
    
    ConVar cvar_filename = FindConVar("multimode_mapcycle");
    if (cvar_filename == null)
    {
        LogError("[MultiMode Downloads] multimode_mapcycle convar not found!");
        return;
    }
    
    char filename[PLATFORM_MAX_PATH];
    cvar_filename.GetString(filename, sizeof(filename));
    
    char configPath[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, configPath, sizeof(configPath), "configs/%s", filename);
    
    if (!g_kvMapcycle.ImportFromFile(configPath))
    {
        LogError("[MultiMode Downloads] Mapcycle failed to load: %s", configPath);
        delete g_kvMapcycle;
        g_kvMapcycle = null;
        return;
    }
    
    g_kvMapcycle.Rewind();
}

KeyValues GetMapcycle()
{
    if (g_kvMapcycle != null)
    {
        return g_kvMapcycle;
    }
    
    LoadDownloadsConfig();
    return g_kvMapcycle;
}

void LoadDownloadsForCurrentMap()
{
    if (g_kvMapcycle == null)
    {
        GetMapcycle();
        if (g_kvMapcycle == null)
            return;
    }
    
    Call_StartForward(g_fwdOnDownloadsCollect);
    Call_PushString(g_sCurrentGroup);
    Call_PushString(g_sCurrentSubGroup);
    Call_PushString(g_sCurrentMap);
    Call_PushString("current");
    Call_Finish();
    
    bool loaded = false;

    if (strlen(g_sCurrentSubGroup) > 0)
    {
        KeyValues kv = MMC_GetSubGroupMapKv(g_kvMapcycle, g_sCurrentGroup, g_sCurrentSubGroup, g_sCurrentMap);
        if (kv != null)
        {
            if (kv.JumpToKey("downloads"))
            {
                ProcessDownloads(kv, "subgroup_map");
                loaded = true;
                kv.GoBack();
            }
            delete kv;
        }
    }
    
    if (!loaded)
    {
        KeyValues kv = MMC_GetMapKv(g_kvMapcycle, g_sCurrentGroup, g_sCurrentMap);
        if (kv != null)
        {
            if (kv.JumpToKey("downloads"))
            {
                ProcessDownloads(kv, "map");
                loaded = true;
                kv.GoBack();
            }
            delete kv;
        }
    }
    
    if (strlen(g_sCurrentSubGroup) > 0)
    {
        if (g_kvMapcycle.JumpToKey(g_sCurrentGroup) && g_kvMapcycle.JumpToKey("subgroup"))
        {
            if (g_kvMapcycle.JumpToKey(g_sCurrentSubGroup))
            {
                if (g_kvMapcycle.JumpToKey("downloads"))
                {
                    ProcessDownloads(g_kvMapcycle, "subgroup");
                    g_kvMapcycle.GoBack();
                }
                g_kvMapcycle.GoBack();
            }
            g_kvMapcycle.GoBack();
        }
        g_kvMapcycle.Rewind();
    }
    
    if (g_kvMapcycle.JumpToKey(g_sCurrentGroup))
    {
        if (g_kvMapcycle.JumpToKey("downloads"))
        {
            ProcessDownloads(g_kvMapcycle, "gamemode");
            g_kvMapcycle.GoBack();
        }
        g_kvMapcycle.Rewind();
    }
    g_kvMapcycle.Rewind();
}

void LoadDownloadsForGamemode(const char[] group, const char[] subgroup, const char[] map)
{
    if (g_kvMapcycle == null)
    {
        GetMapcycle();
        if (g_kvMapcycle == null)
            return;
    }

    Call_StartForward(g_fwdOnDownloadsCollect);
    Call_PushString(group);
    Call_PushString(subgroup);
    Call_PushString(map);
    Call_PushString("gamemode");
    Call_Finish();

    if (strlen(subgroup) > 0)
    {
        KeyValues kv = MMC_GetSubGroupMapKv(g_kvMapcycle, group, subgroup, map);
        if (kv != null)
        {
            if (kv.JumpToKey("downloads"))
            {
                ProcessDownloads(kv, "subgroup_map");
                kv.GoBack();
            }
            delete kv;
        }
    }

    KeyValues kv = MMC_GetMapKv(g_kvMapcycle, group, map);
    if (kv != null)
    {
        if (kv.JumpToKey("downloads"))
        {
            ProcessDownloads(kv, "map");
            kv.GoBack();
        }
        delete kv;
    }

    if (strlen(subgroup) > 0)
    {
        if (g_kvMapcycle.JumpToKey(group) && g_kvMapcycle.JumpToKey("subgroup"))
        {
            if (g_kvMapcycle.JumpToKey(subgroup))
            {
                if (g_kvMapcycle.JumpToKey("downloads"))
                {
                    ProcessDownloads(g_kvMapcycle, "subgroup");
                    g_kvMapcycle.GoBack();
                }
                g_kvMapcycle.GoBack();
            }
            g_kvMapcycle.GoBack();
        }
        g_kvMapcycle.Rewind();
    }

    if (g_kvMapcycle.JumpToKey(group))
    {
        if (g_kvMapcycle.JumpToKey("downloads"))
        {
            ProcessDownloads(g_kvMapcycle, "gamemode");
            g_kvMapcycle.GoBack();
        }
        g_kvMapcycle.Rewind();
    }
    g_kvMapcycle.Rewind();
}

void ProcessDownloads(KeyValues kv, const char[] context)
{
    if (kv == null)
        return;

    if (kv.JumpToKey("download"))
    {
        ProcessDownloadSection(kv, context);
        kv.GoBack();
    }

    if (kv.JumpToKey("precache"))
    {
        ProcessPrecacheSection(kv, context);
        kv.GoBack();
    }
}

void ProcessDownloadSection(KeyValues kv, const char[] context)
{
    if (kv == null)
        return;
    
    if (kv.GotoFirstSubKey(false))
    {
        do
        {
            char key[32];
            kv.GetSectionName(key, sizeof(key));
            
            bool hasSubKeys = kv.GotoFirstSubKey(false);
            if (hasSubKeys)
            {
                kv.GoBack();
                
                char filePath[PLATFORM_MAX_PATH];
                kv.GetString("file", filePath, sizeof(filePath), "");
                
                if (strlen(filePath) == 0)
                {
                    kv.GetString(NULL_STRING, filePath, sizeof(filePath), "");
                }
                
                if (strlen(filePath) > 0)
                {
                    char autoDownloadValue[16];
                    kv.GetString("auto_download", autoDownloadValue, sizeof(autoDownloadValue), "");
                    bool autoDownload = (StrEqual(autoDownloadValue, "1", false) || 
                                        StrEqual(autoDownloadValue, "true", false) || 
                                        StrEqual(autoDownloadValue, "yes", false));
                    
                    if (autoDownload)
                    {
                        ProcessAutoDownload(filePath, context);
                    }
                    else
                    {
                        AddFileToDownloadTable(filePath, context);
                    }
                }
            }
            else
            {
                char filePath[PLATFORM_MAX_PATH];
                kv.GetString(NULL_STRING, filePath, sizeof(filePath), "");
                
                if (strlen(filePath) == 0)
                    continue;
                
                bool autoDownload = false;
                if (StrContains(filePath, "auto_download", false) != -1)
                {
                    char parts[2][PLATFORM_MAX_PATH];
                    if (ExplodeString(filePath, " ", parts, 2, PLATFORM_MAX_PATH) == 2)
                    {
                        strcopy(filePath, sizeof(filePath), parts[0]);
                        if (StrEqual(parts[1], "auto_download", false))
                        {
                            autoDownload = true;
                        }
                    }
                }
                
                if (!autoDownload)
                {
                    char currentKey[32];
                    strcopy(currentKey, sizeof(currentKey), key);
                    
                    kv.GoBack();
                    
                    char checkKey[64];
                    
                    FormatEx(checkKey, sizeof(checkKey), "%s_auto_download", currentKey);
                    if (kv.JumpToKey(checkKey, false))
                    {
                        char value[16];
                        kv.GetString(NULL_STRING, value, sizeof(value), "");
                        if (StrEqual(value, "1", false) || StrEqual(value, "true", false) || strlen(value) == 0)
                        {
                            autoDownload = true;
                        }
                        kv.GoBack();
                    }
                    
                    kv.JumpToKey(currentKey, false);
                }
                
                if (autoDownload)
                {
                    ProcessAutoDownload(filePath, context);
                }
                else
                {
                    AddFileToDownloadTable(filePath, context);
                }
            }
        } while (kv.GotoNextKey(false));
        kv.GoBack();
    }
}

void ProcessPrecacheSection(KeyValues kv, const char[] context)
{
    if (kv == null)
        return;
    
    if (kv.JumpToKey("model"))
    {
        ProcessPrecacheModels(kv, context);
        kv.GoBack();
    }
    
    if (kv.JumpToKey("sound"))
    {
        ProcessPrecacheSounds(kv, context);
        kv.GoBack();
    }
    
    if (kv.JumpToKey("generic"))
    {
        ProcessPrecacheGenerics(kv, context);
        kv.GoBack();
    }
}

void ProcessPrecacheModels(KeyValues kv, const char[] context)
{
    if (kv == null)
        return;
    
    if (kv.GotoFirstSubKey(false))
    {
        do
        {
            char modelPath[PLATFORM_MAX_PATH];
            kv.GetString(NULL_STRING, modelPath, sizeof(modelPath), "");
            
            if (strlen(modelPath) == 0)
                continue;

            if (g_PrecachedModels.ContainsKey(modelPath))
                continue;

            if (PrecacheModel(modelPath, true))
            {
                g_PrecachedModels.SetValue(modelPath, true);
                MMC_WriteToLogFile(null, "[MultiMode Downloads] Precached model: %s (context: %s)", modelPath, context);
            }
            else
            {
                MMC_WriteToLogFile(null, "[MultiMode Downloads] Failed to precache model: %s (context: %s)", modelPath, context);
            }
        } while (kv.GotoNextKey(false));
        kv.GoBack();
    }
}

void ProcessPrecacheSounds(KeyValues kv, const char[] context)
{
    if (kv == null)
        return;
    
    if (kv.GotoFirstSubKey(false))
    {
        do
        {
            char soundPath[PLATFORM_MAX_PATH];
            kv.GetString(NULL_STRING, soundPath, sizeof(soundPath), "");
            
            if (strlen(soundPath) == 0)
                continue;
            
            if (g_PrecachedSounds.ContainsKey(soundPath))
                continue;

            if (PrecacheSound(soundPath, true))
            {
                g_PrecachedSounds.SetValue(soundPath, true);
                MMC_WriteToLogFile(null, "[MultiMode Downloads] Precached sound: %s (context: %s)", soundPath, context);
            }
            else
            {
                MMC_WriteToLogFile(null, "[MultiMode Downloads] Failed to precache sound: %s (context: %s)", soundPath, context);
            }
        } while (kv.GotoNextKey(false));
        kv.GoBack();
    }
}

void ProcessPrecacheGenerics(KeyValues kv, const char[] context)
{
    if (kv == null)
        return;
    
    if (kv.GotoFirstSubKey(false))
    {
        do
        {
            char genericPath[PLATFORM_MAX_PATH];
            kv.GetString(NULL_STRING, genericPath, sizeof(genericPath), "");
            
            if (strlen(genericPath) == 0)
                continue;
            
            if (g_PrecachedGenerics.ContainsKey(genericPath))
                continue;

            if (PrecacheGeneric(genericPath, true))
            {
                g_PrecachedGenerics.SetValue(genericPath, true);
                MMC_WriteToLogFile(null, "[MultiMode Downloads] Precached generic: %s (context: %s)", genericPath, context);
            }
            else
            {
                MMC_WriteToLogFile(null, "[MultiMode Downloads] Failed to precache generic: %s (context: %s)", genericPath, context);
            }
        } while (kv.GotoNextKey(false));
        kv.GoBack();
    }
}

void ProcessAutoDownload(const char[] filePath, const char[] context)
{
    if (strlen(filePath) == 0)
        return;

    if (StrContains(filePath, "models/", false) == 0 && StrContains(filePath, ".mdl", false) != -1)
    {
        AddModelFiles(filePath, context);
    }
    else if (StrContains(filePath, "materials/", false) == 0)
    {
        AddMaterialFiles(filePath, context);
    }
    else
    {
        AddFileToDownloadTable(filePath, context);
    }
}

void AddModelFiles(const char[] modelPath, const char[] context)
{
    if (strlen(modelPath) == 0)
        return;

    char basePath[PLATFORM_MAX_PATH];
    strcopy(basePath, sizeof(basePath), modelPath);

    ReplaceString(basePath, sizeof(basePath), ".mdl", "", false);

    char relativePath[PLATFORM_MAX_PATH];
    if (StrContains(basePath, "models/", false) == 0)
    {
        strcopy(relativePath, sizeof(relativePath), basePath[7]);
    }
    else
    {
        strcopy(relativePath, sizeof(relativePath), basePath);
    }

    char mdlPath[PLATFORM_MAX_PATH];
    FormatEx(mdlPath, sizeof(mdlPath), "models/%s.mdl", relativePath);
    AddFileToDownloadTable(mdlPath, context);
    
    char vvdPath[PLATFORM_MAX_PATH];
    FormatEx(vvdPath, sizeof(vvdPath), "models/%s.vvd", relativePath);
    AddFileToDownloadTable(vvdPath, context);
    
    char vtxPath[PLATFORM_MAX_PATH];
    FormatEx(vtxPath, sizeof(vtxPath), "models/%s.dx90.vtx", relativePath);
    AddFileToDownloadTable(vtxPath, context);
    
    char phyPath[PLATFORM_MAX_PATH];
    FormatEx(phyPath, sizeof(phyPath), "models/%s.phy", relativePath);
    if (FileExists(phyPath, true))
    {
        AddFileToDownloadTable(phyPath, context);
    }
    
    char materialBase[PLATFORM_MAX_PATH];
    FormatEx(materialBase, sizeof(materialBase), "materials/models/%s", relativePath);
    
    char materialPath[PLATFORM_MAX_PATH];
    
    FormatEx(materialPath, sizeof(materialPath), "%s.vmt", materialBase);
    if (FileExists(materialPath, true))
    {
        AddFileToDownloadTable(materialPath, context);
        ReplaceString(materialPath, sizeof(materialPath), ".vmt", ".vtf", false);
        if (FileExists(materialPath, true))
        {
            AddFileToDownloadTable(materialPath, context);
        }
    }
    else
    {
        FormatEx(materialPath, sizeof(materialPath), "%s.vtf", materialBase);
        if (FileExists(materialPath, true))
        {
            AddFileToDownloadTable(materialPath, context);
        }
    }
}

void AddMaterialFiles(const char[] materialPath, const char[] context)
{
    if (strlen(materialPath) == 0)
        return;
    
    char basePath[PLATFORM_MAX_PATH];
    strcopy(basePath, sizeof(basePath), materialPath);
    
    bool hasVmt = ReplaceString(basePath, sizeof(basePath), ".vmt", "", false) > 0;
    bool hasVtf = ReplaceString(basePath, sizeof(basePath), ".vtf", "", false) > 0;
    
    char relativePath[PLATFORM_MAX_PATH];
    if (StrContains(basePath, "materials/", false) == 0)
    {
        strcopy(relativePath, sizeof(relativePath), basePath[10]);
    }
    else
    {
        strcopy(relativePath, sizeof(relativePath), basePath);
    }
    
    char vmtPath[PLATFORM_MAX_PATH];
    FormatEx(vmtPath, sizeof(vmtPath), "materials/%s.vmt", relativePath);
    if (FileExists(vmtPath, true) || !hasVtf)
    {
        AddFileToDownloadTable(vmtPath, context);
    }
    
    char vtfPath[PLATFORM_MAX_PATH];
    FormatEx(vtfPath, sizeof(vtfPath), "materials/%s.vtf", relativePath);
    if (FileExists(vtfPath, true) || !hasVmt)
    {
        AddFileToDownloadTable(vtfPath, context);
    }
}

void AddFileToDownloadTable(const char[] filePath, const char[] context)
{
    if (strlen(filePath) == 0)
        return;
    
    if (g_DownloadedFiles.ContainsKey(filePath))
        return;
    
    if (!FileExists(filePath, true))
    {
        MMC_WriteToLogFile(null, "[MultiMode Downloads] File not found (skipping): %s (context: %s)", filePath, context);
        return;
    }
    
    AddFileToDownloadsTable(filePath);
    g_DownloadedFiles.SetValue(filePath, true);
    
    MMC_WriteToLogFile(null, "[MultiMode Downloads] Added to download table: %s (context: %s)", filePath, context);
}

public void OnPluginEnd()
{
    if (g_fwdOnDownloadsCollect != null)
    {
        delete g_fwdOnDownloadsCollect;
    }
    if (g_DownloadedFiles != null)
    {
        delete g_DownloadedFiles;
    }
    if (g_PrecachedModels != null)
    {
        delete g_PrecachedModels;
    }
    if (g_PrecachedSounds != null)
    {
        delete g_PrecachedSounds;
    }
    if (g_PrecachedGenerics != null)
    {
        delete g_PrecachedGenerics;
    }
    if (g_kvMapcycle != null)
    {
        delete g_kvMapcycle;
    }
}