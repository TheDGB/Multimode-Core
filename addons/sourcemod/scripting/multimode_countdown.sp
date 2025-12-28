/*****************************************************************************
                        Multi Mode Countdown Plugin
******************************************************************************/

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <multimode/utils>
#include <multimode/base>
#include <morecolors>
#include <emitsoundany>

public Plugin myinfo = 
{
    name = "[MMC] MultiMode Countdown",
    author = "Oppressive Territory",
    description = "Countdown system for MultiMode Core",
    version = PLUGIN_VERSION,
    url = ""
}

// ConVars
ConVar g_Cvar_CountdownEnabled;
ConVar g_Cvar_CountdownFilename;
ConVar g_Cvar_CountdownLogs;

// StringMap Section
StringMap g_Countdowns;
StringMap g_CountdownSounds;
StringMap g_LastCountdownValues;

public void OnPluginStart() 
{
    // ConVars
    g_Cvar_CountdownEnabled = CreateConVar("multimode_countdown", "1", "Enable/disable the end vote countdown messages", _, true, 0.0, true, 1.0);
    g_Cvar_CountdownFilename = CreateConVar("multimode_countdown_filename", "countdown.txt", "Name of the countdown configuration file");
    g_Cvar_CountdownLogs = CreateConVar("multimode_countdown_logs", "1", "Enable/disable logging for countdown", _, true, 0.0, true, 1.0);

    g_Countdowns = new StringMap();
    g_CountdownSounds = new StringMap();
    g_LastCountdownValues = new StringMap();

    if (g_Cvar_CountdownEnabled.BoolValue)
    {
        LoadCountdownConfig();
    }

    HookConVarChange(g_Cvar_CountdownEnabled, OnCountdownCvarChanged);
    HookConVarChange(g_Cvar_CountdownFilename, OnCountdownCvarChanged);
    
    AutoExecConfig(true, "multimode_countdown");
}

public void OnPluginEnd()
{
    if (g_Countdowns != null)
    {
        StringMapSnapshot snapshot = g_Countdowns.Snapshot();
        for (int i = 0; i < snapshot.Length; i++)
        {
            char key[64];
            snapshot.GetKey(i, key, sizeof(key));
            StringMap typeMap;
            if (g_Countdowns.GetValue(key, typeMap))
            {
                StringMapSnapshot typeSnapshot = typeMap.Snapshot();
                for (int j = 0; j < typeSnapshot.Length; j++)
                {
                    char valueKey[32];
                    typeSnapshot.GetKey(j, valueKey, sizeof(valueKey));
                    ArrayList messages;
                    if (typeMap.GetValue(valueKey, messages))
                    {
                        delete messages;
                    }
                }
                delete typeSnapshot;
                delete typeMap;
            }
        }
        delete snapshot;
        delete g_Countdowns;
    }
    
    if (g_CountdownSounds != null)
    {
        delete g_CountdownSounds;
    }
    
    if (g_LastCountdownValues != null)
    {
        delete g_LastCountdownValues;
    }
}

public void OnCountdownCvarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
    if (g_Cvar_CountdownEnabled.BoolValue)
    {
        LoadCountdownConfig();
    }
}

void LoadCountdownConfig()
{
    char path[PLATFORM_MAX_PATH];
    char filename[PLATFORM_MAX_PATH];
    g_Cvar_CountdownFilename.GetString(filename, sizeof(filename));
    BuildPath(Path_SM, path, sizeof(path), "configs/%s", filename);

    if (!FileExists(path))
    {
        MMC_WriteToLogFile(g_Cvar_CountdownLogs, "[Multimode Countdown] Config file not found: %s", path);
        return;
    }

    KeyValues kv = new KeyValues("Countdown");
    if (!kv.ImportFromFile(path))
    {
        LogError("[Multimode Countdown] Failed to import countdown config from file: %s", path);
        delete kv;
        return;
    }

    StringMapSnapshot snapshot = g_Countdowns.Snapshot();
    for (int i = 0; i < snapshot.Length; i++)
    {
        char key[64];
        snapshot.GetKey(i, key, sizeof(key));
        StringMap typeMap;
        g_Countdowns.GetValue(key, typeMap);
        delete typeMap;
    }
    delete snapshot;
    g_Countdowns.Clear();

    delete g_CountdownSounds;
    g_CountdownSounds = new StringMap();

    if (kv.GotoFirstSubKey())
    {
        do
        {
            char type[64];
            kv.GetSectionName(type, sizeof(type));
            
            StringMap typeMap = new StringMap();
            g_Countdowns.SetValue(type, typeMap);

            if (kv.GotoFirstSubKey(false))
            {
                do
                {
                    char valueKey[32];
                    kv.GetSectionName(valueKey, sizeof(valueKey));

                    ArrayList messageList = new ArrayList(ByteCountToCells(256));
                    
                    if (kv.GotoFirstSubKey(false))
                    {
                        do
                        {
                            char messageType[16];
                            kv.GetSectionName(messageType, sizeof(messageType));

                            char message[256];
                            kv.GetString(NULL_STRING, message, sizeof(message));

                            if (StrEqual(messageType, "sound"))
                            {
                                if (!g_CountdownSounds.ContainsKey(message))
                                {
                                    g_CountdownSounds.SetValue(message, true);
									
                                    if (StrContains(message, "{TIME}") != -1 || 
                                        StrContains(message, "{ROUNDS}") != -1 || 
                                        StrContains(message, "{FRAGS}") != -1)
                                    {
                                        continue;
                                    }
                                    
                                    PrecacheSoundAny(message);
                                    char downloadPath[PLATFORM_MAX_PATH];
                                    FormatEx(downloadPath, sizeof(downloadPath), "sound/%s", message);
                                    if (FileExists(downloadPath, true))
                                        AddFileToDownloadsTable(downloadPath);
                                    else
                                        MMC_WriteToLogFile(g_Cvar_CountdownLogs, "[Multimode Countdown] Sound file not found: %s", downloadPath);
                                }
                            }

                            char buffer[512];
                            FormatEx(buffer, sizeof(buffer), "%s;%s", messageType, message);
                            messageList.PushString(buffer);
                        } while (kv.GotoNextKey(false));
                        kv.GoBack();
                    }

                    if (StrContains(valueKey, ";") != -1)
                    {
                        char range[2][12];
                        int count = ExplodeString(valueKey, ";", range, 2, 12);
                        if (count == 2)
                        {
                            int start = StringToInt(range[0]);
                            int end = StringToInt(range[1]);
                            if (start < end)
                            {
                                int temp = start;
                                start = end;
                                end = temp;
                            }
                            for (int value = start; value >= end; value--)
                            {
                                char singleKey[12];
                                IntToString(value, singleKey, sizeof(singleKey));
                                ArrayList clonedList = view_as<ArrayList>(CloneHandle(messageList));
                                typeMap.SetValue(singleKey, clonedList);
                            }
                            delete messageList;
                        }
                        else
                        {
                            LogError("[Multimode Countdown] Invalid range in countdown config: %s", valueKey);
                            delete messageList;
                        }
                    }
                    else
                    {
                        int value = StringToInt(valueKey);
                        if (value >= 0)
                        {
                            typeMap.SetValue(valueKey, messageList);
                        }
                        else
                        {
                            delete messageList;
                        }
                    }
                } while (kv.GotoNextKey(false));
                kv.GoBack();
            }
        } while (kv.GotoNextKey());
    }

    delete kv;
    MMC_WriteToLogFile(g_Cvar_CountdownLogs, "[Multimode Countdown] Countdown configuration loaded successfully!");
}

public void Countdown_ShowMessage(const char[] type, int value)
{
    CountdownMessages(type, value);
}

void CountdownMessages(const char[] type, int value)
{
    if (!g_Cvar_CountdownEnabled.BoolValue)
        return;
    
    int lastValue;
    char lastValueKey[64];
    Format(lastValueKey, sizeof(lastValueKey), "%s_last", type);
    
    if (!g_LastCountdownValues.GetValue(lastValueKey, lastValue) || value != lastValue)
    {
        StringMap typeMap;
        if (g_Countdowns.GetValue(type, typeMap))
        {
            char valueKey[32];
            IntToString(value, valueKey, sizeof(valueKey));
            
            ArrayList messages;
            if (typeMap.GetValue(valueKey, messages))
            {
                for (int i = 0; i < messages.Length; i++)
                {
                    char buffer[512];
                    messages.GetString(i, buffer, sizeof(buffer));

                    char parts[2][256];
                    if (ExplodeString(buffer, ";", parts, 2, 256) == 2)
                    {
                        char messageType[16];
                        strcopy(messageType, sizeof(messageType), parts[0]);
                        char message[256];
                        strcopy(message, sizeof(message), parts[1]);

                        if (StrEqual(messageType, "sound"))
                        {
                            char soundPath[PLATFORM_MAX_PATH];
                            strcopy(soundPath, sizeof(soundPath), message);

                            char formattedValue[32];
    
                            FormatTimeValue(value, formattedValue, sizeof(formattedValue));
                            ReplaceString(soundPath, sizeof(soundPath), "{TIME}", formattedValue);
    
                            Format(formattedValue, sizeof(formattedValue), "%d", value);
                            ReplaceString(soundPath, sizeof(soundPath), "{ROUNDS}", formattedValue);
                            ReplaceString(soundPath, sizeof(soundPath), "{FRAGS}", formattedValue);
							
                            if (!g_CountdownSounds.ContainsKey(soundPath))
                            {
                                PrecacheSoundAny(soundPath);
                                char downloadPath[PLATFORM_MAX_PATH];
                                FormatEx(downloadPath, sizeof(downloadPath), "sound/%s", soundPath);
                                if (FileExists(downloadPath, true))
                                {
                                    AddFileToDownloadsTable(downloadPath);
                                }
                                else
                                {
                                    MMC_WriteToLogFile(g_Cvar_CountdownLogs, "[Multimode Countdown] Sound file not found: %s", downloadPath);
                                }
                                g_CountdownSounds.SetValue(soundPath, true);
                            }

                            EmitSoundToAllAny(soundPath);
                            continue;
                        }

                        char formattedValue[32];

                        FormatTimeValue(value, formattedValue, sizeof(formattedValue));
                        ReplaceString(message, sizeof(message), "{TIME}", formattedValue);

                        Format(formattedValue, sizeof(formattedValue), "%d", value);
                        ReplaceString(message, sizeof(message), "{FRAGS}", formattedValue);

                        Format(formattedValue, sizeof(formattedValue), "%d", value);
                        ReplaceString(message, sizeof(message), "{ROUNDS}", formattedValue);

                        if (StrEqual(messageType, "hint"))
                        {
                            PrintHintTextToAll(message);
                        }
                        else if (StrEqual(messageType, "center"))
                        {
                            PrintCenterTextAll(message);
                        }
                        else if (StrEqual(messageType, "chat"))
                        {
                            CPrintToChatAll(message);
                        }
                    }
                }
            }
        }
        g_LastCountdownValues.SetValue(lastValueKey, value);
    }
}

void FormatTimeValue(int timeValue, char[] buffer, int bufferSize)
{
    if (timeValue >= 60)
    {
        int minutes = timeValue / 60;
        Format(buffer, bufferSize, "%d", minutes);
    }
    else
    {
        Format(buffer, bufferSize, "%d", timeValue);
    }
}

