/*****************************************************************************
                        MultiMode Descriptions
******************************************************************************/

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <morecolors>
#include <multimode>
#include <multimode/base>
#include <multimode/utils>
#include <menus>
#include <string>
#include <convars>

public Plugin myinfo = 
{
    name = "[MMC] MultiMode Descriptions",
    author = "Oppressive Territory",
    description = "Description system for MultiMode Core gamemodes, subgroups and maps",
    version = PLUGIN_VERSION,
    url = ""
}

enum struct DescriptionLink
{
    char description[256];
    char command[128];
    bool only_ingamemode;
}

enum struct DescriptionConfig
{
    bool enabled;
    char flags[32];
    char title[128];
    char description_text[2048];
    ArrayList commands;
    ArrayList links;
    ArrayList items;
}

// Convar Section
ConVar g_Cvar_MapCycleFile;
ConVar g_Cvar_DescriptionsLogs;

// KeyValues Section
KeyValues g_kvMapcycle;

// StringMap Section
StringMap g_CommandMap;

// Char Section
char g_LastGamemode[MAXPLAYERS+1][64];
char g_LastSubgroup[MAXPLAYERS+1][64];
char g_LastMap[MAXPLAYERS+1][PLATFORM_MAX_PATH];
bool g_CameFromOptionsMenu[MAXPLAYERS+1];

public void OnPluginStart()
{
    g_Cvar_MapCycleFile = CreateConVar("multimode_descriptions_mapcycle", "mmc_mapcycle.txt", "Name of the map cycle file to use for descriptions (search in addons/sourcemod/configs).");
    g_Cvar_DescriptionsLogs = CreateConVar("multimode_descriptions_logs", "0", "Enables or disables logging for MultiMode Descriptions plugin. 0 = Disabled, 1 = Enabled.", FCVAR_NONE, true, 0.0, true, 1.0);
    
    g_CommandMap = new StringMap();
    
    // Register commands
    RegConsoleCmd("multimode_descriptions", Command_Descriptions, "Opens the gamemode descriptions menu");
    RegConsoleCmd("sm_descriptions", Command_Descriptions, "Opens the gamemode descriptions menu (ALT)");
    RegConsoleCmd("sm_mmcd", Command_Descriptions, "Opens the gamemode descriptions menu (ALT)");
    RegConsoleCmd("sm_rotation", Command_Descriptions, "Opens the gamemode descriptions menu(ALT)");
    RegConsoleCmd("sm_rotations", Command_Descriptions, "Opens the gamemode descriptions menu(ALT)");
    RegConsoleCmd("sm_gamemodes", Command_Descriptions, "Opens the gamemode descriptions menu (ALT)");
    RegConsoleCmd("sm_listmaps", Command_Descriptions, "Opens the gamemode descriptions menu (ALT)");
    
    AddCommandListener(OnPlayerChat, "say");
    AddCommandListener(OnPlayerChat, "say2");
    AddCommandListener(OnPlayerChat, "say_team");
    
    AutoExecConfig(true, "multimode_descriptions");
    
    LoadMapcycle();
    
    RegisterDescriptionCommands();
}

public void OnConfigsExecuted()
{
    LoadMapcycle();
    RegisterDescriptionCommands();
}

public Action Command_Descriptions(int client, int args)
{
    if (!client || !IsClientInGame(client))
        return Plugin_Handled;
    
    ShowGamemodeMenu(client);
    return Plugin_Handled;
}

public Action OnPlayerChat(int client, const char[] command, int argc)
{
    if (!client || !IsClientInGame(client) || !IsClientAuthorized(client))
        return Plugin_Continue;
    
    if (argc == 0)
        return Plugin_Continue;
    
    char text[256];
    GetCmdArgString(text, sizeof(text));
    
    MMC_WriteToLogFileEx("[MMC Descriptions] OnPlayerChat: client=%d, text='%s'", client, text);
    
    TrimString(text);
    int textLen = strlen(text);
    if (textLen >= 2 && text[0] == '"' && text[textLen-1] == '"')
    {
        text[textLen-1] = '\0';
        strcopy(text, sizeof(text), text[1]);
    }
    
    char cmd[64];
    strcopy(cmd, sizeof(cmd), text);
    
    int spacePos = FindCharInString(cmd, ' ');
    if (spacePos != -1)
    {
        cmd[spacePos] = '\0';
    }
    
    for (int i = 0; i < strlen(cmd); i++)
    {
        if (cmd[i] >= 'A' && cmd[i] <= 'Z')
        {
            cmd[i] = cmd[i] + ('a' - 'A');
        }
    }
    
    MMC_WriteToLogFileEx("[MMC Descriptions] Parsed command (lowercase): '%s'", cmd);
    
    char path[256];
    if (g_CommandMap.GetString(cmd, path, sizeof(path)))
    {
        MMC_WriteToLogFileEx("[MMC Descriptions] Found command '%s' in map, path='%s'", cmd, path);
        
        char gamemode[64], subgroup[64], map[PLATFORM_MAX_PATH];
        int pos1 = FindCharInString(path, '|');
        int pos2 = -1;
        
        if (pos1 != -1)
        {
            strcopy(gamemode, pos1 + 1, path);
            pos2 = FindCharInString(path[pos1 + 1], '|');
            if (pos2 != -1)
            {
                strcopy(subgroup, pos2 + 1, path[pos1 + 1]);
                strcopy(map, sizeof(map), path[pos1 + pos2 + 2]);
            }
            else
            {
                strcopy(subgroup, sizeof(subgroup), path[pos1 + 1]);
            }
        }
        else
        {
            strcopy(gamemode, sizeof(gamemode), path);
        }
        
        ShowDescriptionMenu(client, gamemode, (strlen(subgroup) > 0) ? subgroup : "", (strlen(map) > 0) ? map : "");
        
        return Plugin_Handled;
    }
    else
    {
        MMC_WriteToLogFileEx("[MMC Descriptions] Command '%s' not found in map", cmd);
    }
    
    return Plugin_Continue;
}

void LoadMapcycle()
{
    delete g_kvMapcycle;
    g_kvMapcycle = new KeyValues("Mapcycle");
    
    char filename[PLATFORM_MAX_PATH];
    g_Cvar_MapCycleFile.GetString(filename, sizeof(filename));
    
    char configPath[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, configPath, sizeof(configPath), "configs/%s", filename);
    
    if (!g_kvMapcycle.ImportFromFile(configPath))
    {
        LogError("[MultiMode Descriptions] Mapcycle failed to load: %s", configPath);
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
    
    LoadMapcycle();
    return g_kvMapcycle;
}

bool CheckDescriptionAccess(int client, KeyValues kv)
{
    if (kv == null)
        return false;
    
    int enabled = kv.GetNum("description_enabled", 1);
    if (enabled == 0)
        return false;
    
    char flags[32];
    kv.GetString("description_flags", flags, sizeof(flags), "");
    
    if (strlen(flags) > 0)
    {
        int requiredFlags = ReadFlagString(flags);
        if (!CheckCommandAccess(client, "", requiredFlags, true))
        {
            return false;
        }
    }
    
    return true;
}

bool HasDescription(KeyValues kv, const char[] gamemode, const char[] subgroup = "", const char[] map = "")
{
    if (kv == null)
        return false;
    
    KeyValues checkKv = GetMapcycle();
    if (checkKv == null)
        return false;
    
    bool result = false;
    checkKv.Rewind();
    
    if (!checkKv.GotoFirstSubKey(false))
    {
        return false;
    }
    
    do
    {
        char sectionName[64];
        checkKv.GetSectionName(sectionName, sizeof(sectionName));
        
        if (!StrEqual(sectionName, gamemode))
            continue;
        
        if (strlen(map) > 0)
        {
            if (strlen(subgroup) > 0)
            {
                if (checkKv.JumpToKey("subgroup"))
                {
                    if (checkKv.GotoFirstSubKey(false))
                    {
                        do
                        {
                            char subKey[64];
                            checkKv.GetSectionName(subKey, sizeof(subKey));
                            
                            if (StrEqual(subKey, subgroup))
                            {
                                if (checkKv.JumpToKey("maps"))
                                {
                                    if (checkKv.GotoFirstSubKey(false))
                                    {
                                        do
                                        {
                                            char mapKey[PLATFORM_MAX_PATH];
                                            checkKv.GetSectionName(mapKey, sizeof(mapKey));
                                            
                                            if (StrEqual(mapKey, map))
                                            {
                                                result = checkKv.JumpToKey("descriptions");
                                                return result;
                                            }
                                        } while (checkKv.GotoNextKey(false));
                                        checkKv.GoBack();
                                    }
                                    checkKv.GoBack();
                                }
                                return false;
                            }
                        } while (checkKv.GotoNextKey(false));
                        checkKv.GoBack();
                    }
                    checkKv.GoBack();
                }
            }
            else
            {
                if (checkKv.JumpToKey("maps"))
                {
                    if (checkKv.GotoFirstSubKey(false))
                    {
                        do
                        {
                            char mapKey[PLATFORM_MAX_PATH];
                            checkKv.GetSectionName(mapKey, sizeof(mapKey));
                            
                            if (StrEqual(mapKey, map))
                            {
                                result = checkKv.JumpToKey("descriptions");
                                return result;
                            }
                        } while (checkKv.GotoNextKey(false));
                        checkKv.GoBack();
                    }
                    checkKv.GoBack();
                }
            }
        }
        else if (strlen(subgroup) > 0)
        {
            if (checkKv.JumpToKey("subgroup"))
            {
                if (checkKv.GotoFirstSubKey(false))
                {
                    do
                    {
                        char subKey[64];
                        checkKv.GetSectionName(subKey, sizeof(subKey));
                        
                        if (StrEqual(subKey, subgroup))
                        {
                            result = checkKv.JumpToKey("descriptions");
                            return result;
                        }
                    } while (checkKv.GotoNextKey(false));
                    checkKv.GoBack();
                }
                checkKv.GoBack();
            }
        }
        else
        {
            result = checkKv.JumpToKey("descriptions");
            return result;
        }
        
        return false;
    } while (checkKv.GotoNextKey(false));
    
    return false;
}

void RegisterDescriptionCommands()
{
    g_CommandMap.Clear();
    
    KeyValues kv = GetMapcycle();
    if (kv == null)
        return;
    
    kv.Rewind();
    
    if (!kv.GotoFirstSubKey(false))
        return;
    
    do
    {
        char gamemode[64];
        kv.GetSectionName(gamemode, sizeof(gamemode));
        
        if (kv.JumpToKey("descriptions"))
        {
            LoadDescriptionCommands(kv, gamemode);
            kv.GoBack();
        }
        
        if (kv.JumpToKey("subgroup"))
        {
            if (kv.GotoFirstSubKey(false))
            {
                do
                {
                    char subgroup[64];
                    kv.GetSectionName(subgroup, sizeof(subgroup));
                    
                    if (kv.JumpToKey("descriptions"))
                    {
                        LoadDescriptionCommands(kv, gamemode, subgroup);
                        kv.GoBack();
                    }
                    
                    if (kv.JumpToKey("maps"))
                    {
                        if (kv.GotoFirstSubKey(false))
                        {
                            do
                            {
                                char map[PLATFORM_MAX_PATH];
                                kv.GetSectionName(map, sizeof(map));
                                
                                if (kv.JumpToKey("descriptions"))
                                {
                                    LoadDescriptionCommands(kv, gamemode, subgroup, map);
                                    kv.GoBack();
                                }
                            } while (kv.GotoNextKey(false));
                            kv.GoBack();
                        }
                        kv.GoBack();
                    }
                } while (kv.GotoNextKey(false));
                kv.GoBack();
            }
            kv.GoBack();
        }
        
        if (kv.JumpToKey("maps"))
        {
            if (kv.GotoFirstSubKey(false))
            {
                do
                {
                    char map[PLATFORM_MAX_PATH];
                    kv.GetSectionName(map, sizeof(map));
                    
                    if (kv.JumpToKey("descriptions"))
                    {
                        LoadDescriptionCommands(kv, gamemode, "", map);
                        kv.GoBack();
                    }
                } while (kv.GotoNextKey(false));
                kv.GoBack();
            }
            kv.GoBack();
        }
    } while (kv.GotoNextKey(false));
    
    kv.Rewind();
}

void LoadDescriptionCommands(KeyValues kv, const char[] gamemode, const char[] subgroup = "", const char[] map = "")
{
    if (kv == null)
        return;
    
    char path[256];
    if (strlen(map) > 0)
    {
        if (strlen(subgroup) > 0)
            Format(path, sizeof(path), "%s|%s|%s", gamemode, subgroup, map);
        else
            Format(path, sizeof(path), "%s||%s", gamemode, map);
    }
    else if (strlen(subgroup) > 0)
    {
        Format(path, sizeof(path), "%s|%s|", gamemode, subgroup);
    }
    else
    {
        Format(path, sizeof(path), "%s||", gamemode);
    }
    
    
    if (kv.JumpToKey("description_command"))
    {
        char command[64];
        
        kv.GetString("command", command, sizeof(command), "");
        kv.GoBack();
        
        if (strlen(command) > 0)
        {
            char commandLower[64];
            strcopy(commandLower, sizeof(commandLower), command);
            for (int i = 0; i < strlen(commandLower); i++)
            {
                if (commandLower[i] >= 'A' && commandLower[i] <= 'Z')
                {
                    commandLower[i] = commandLower[i] + ('a' - 'A');
                }
            }
            
            g_CommandMap.SetString(commandLower, path);
            MMC_WriteToLogFileEx("[MMC Descriptions] Registered command '%s' (lowercase: '%s') for path '%s'", command, commandLower, path);
        }
    }

    int copyNum = 2;
    do
    {
        char commandKey[64];
        Format(commandKey, sizeof(commandKey), "description_command_%d", copyNum);
        
        if (kv.JumpToKey(commandKey))
        {
            char command[64];
            
            kv.GetString("command", command, sizeof(command), "");
            kv.GoBack();
            
            if (strlen(command) > 0)
            {
                char commandLower[64];
                strcopy(commandLower, sizeof(commandLower), command);
                for (int i = 0; i < strlen(commandLower); i++)
                {
                    if (commandLower[i] >= 'A' && commandLower[i] <= 'Z')
                    {
                        commandLower[i] = commandLower[i] + ('a' - 'A');
                    }
                }
                
                g_CommandMap.SetString(commandLower, path);
                MMC_WriteToLogFileEx("[MMC Descriptions] Registered command '%s' (lowercase: '%s') for path '%s'", command, commandLower, path);
            }
        }
        else
        {
            break;
        }
        
        copyNum++;
    } while (copyNum < 100);
}

void ShowGamemodeMenu(int client)
{
    Menu menu = new Menu(GamemodeMenuHandler);
    menu.SetTitle("Gamemodes");
    
    KeyValues kv = GetMapcycle();
    ArrayList gameModes = GetGameModesList();
    bool useSharedList = (gameModes != null && gameModes.Length > 0);
    
    int itemCount = 0;
    
    if (useSharedList)
    {
        for (int i = 0; i < gameModes.Length; i++)
        {
            GameModeConfig config;
            gameModes.GetArray(i, config);
            
            char display[128];
            strcopy(display, sizeof(display), config.name);
            
            menu.AddItem(config.name, display);
            itemCount++;
        }
    }
    else
    {
        if (kv != null)
        {
            kv.Rewind();
            if (kv.GotoFirstSubKey(false))
            {
                do
                {
                    char gamemodeName[64];
                    kv.GetSectionName(gamemodeName, sizeof(gamemodeName));
                    
                    char display[128];
                    strcopy(display, sizeof(display), gamemodeName);
                    
                    menu.AddItem(gamemodeName, display);
                    itemCount++;
                } while (kv.GotoNextKey(false));
                kv.GoBack();
            }
            kv.Rewind();
        }
    }
    
    if (itemCount > 0)
    {
        menu.ExitButton = true;
        menu.Display(client, MENU_TIME_FOREVER);
    }
    else
    {
        CPrintToChat(client, "[MultiMode] No gamemodes available.");
        delete menu;
    }
}

public int GamemodeMenuHandler(Menu menu, MenuAction action, int client, int param2)
{
    if (action == MenuAction_Select)
    {
        char gamemode[64];
        menu.GetItem(param2, gamemode, sizeof(gamemode));
        ShowGamemodeOptionsMenu(client, gamemode);
    }
    else if (action == MenuAction_End)
    {
        delete menu;
    }
    return 0;
}

void ShowGamemodeOptionsMenu(int client, const char[] gamemode)
{
    KeyValues kv = GetMapcycle();
    bool hasDesc = HasDescription(kv, gamemode);
    
    ArrayList gameModes = GetGameModesList();
    bool hasSubgroups = false;
    bool hasMaps = false;
    
    if (gameModes != null && gameModes.Length > 0)
    {
        int index = MMC_FindGameModeIndex(gamemode);
        if (index != -1)
        {
            GameModeConfig config;
            gameModes.GetArray(index, config);
            hasSubgroups = (config.subGroups != null && config.subGroups.Length > 0);
            hasMaps = (config.maps != null && config.maps.Length > 0);
        }
    }
    else
    {
        if (kv != null)
        {
            kv.Rewind();
            if (kv.GotoFirstSubKey(false))
            {
                do
                {
                    char sectionName[64];
                    kv.GetSectionName(sectionName, sizeof(sectionName));
                    if (StrEqual(sectionName, gamemode))
                    {
                        hasSubgroups = kv.JumpToKey("subgroup");
                        if (hasSubgroups)
                        {
                            hasSubgroups = kv.GotoFirstSubKey(false);
                            if (hasSubgroups)
                            {
                                kv.GoBack();
                            }
                            kv.GoBack();
                        }
                        hasMaps = kv.JumpToKey("maps");
                        if (hasMaps)
                        {
                            hasMaps = kv.GotoFirstSubKey(false);
                            if (hasMaps)
                            {
                                kv.GoBack();
                            }
                            kv.GoBack();
                        }
                        break;
                    }
                } while (kv.GotoNextKey(false));
                kv.Rewind();
            }
        }
    }
    
    if (!hasDesc)
    {
        if (hasSubgroups && !hasMaps)
        {
            g_CameFromOptionsMenu[client] = false;
            ShowSubgroupMenu(client, gamemode);
            return;
        }
        else if (!hasSubgroups && hasMaps)
        {
            g_CameFromOptionsMenu[client] = false;
            strcopy(g_LastGamemode[client], sizeof(g_LastGamemode[]), gamemode);
            g_LastSubgroup[client][0] = '\0';
            ShowMapMenu(client, gamemode);
            return;
        }
        else if (!hasSubgroups && !hasMaps)
        {
            CPrintToChat(client, "[MultiMode] No options available for this gamemode.");
            return;
        }
    }
    else
    {
        g_CameFromOptionsMenu[client] = true;
    }
    
    Menu menu = new Menu(GamemodeOptionsMenuHandler);
    menu.SetTitle("Gamemode: %s", gamemode);
    
    if (hasDesc)
    {
        menu.AddItem("description", "View Description");
    }
    
    if (hasSubgroups)
    {
        menu.AddItem("subgroups", "View Subgroups");
    }
    
    if (hasMaps)
    {
        menu.AddItem("maps", "View Maps");
    }
    
    if (menu.ItemCount == 0)
    {
        CPrintToChat(client, "[MultiMode] No options available for this gamemode.");
        delete menu;
        return;
    }
    
    menu.ExitBackButton = true;
    menu.Display(client, MENU_TIME_FOREVER);
}

public int GamemodeOptionsMenuHandler(Menu menu, MenuAction action, int client, int param2)
{
    if (action == MenuAction_Select)
    {
        char option[32];
        menu.GetItem(param2, option, sizeof(option));
        
        char title[128];
        menu.GetTitle(title, sizeof(title));
        
        char gamemode[64];
        int colonPos = FindCharInString(title, ':');
        if (colonPos != -1)
        {
            strcopy(gamemode, sizeof(gamemode), title[colonPos + 2]);
        }
        
        if (StrEqual(option, "description"))
        {
            ShowDescriptionMenu(client, gamemode);
        }
        else if (StrEqual(option, "subgroups"))
        {
            g_CameFromOptionsMenu[client] = true;
            ShowSubgroupMenu(client, gamemode);
        }
        else if (StrEqual(option, "maps"))
        {
            g_CameFromOptionsMenu[client] = true;
            strcopy(g_LastGamemode[client], sizeof(g_LastGamemode[]), gamemode);
            g_LastSubgroup[client][0] = '\0';
            ShowMapMenu(client, gamemode);
        }
    }
    else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack)
    {
        char title[128];
        menu.GetTitle(title, sizeof(title));
        
        char gamemode[64];
        int colonPos = FindCharInString(title, ':');
        if (colonPos != -1)
        {
            strcopy(gamemode, sizeof(gamemode), title[colonPos + 2]);
        }
        
        ShowGamemodeMenu(client);
    }
    else if (action == MenuAction_End)
    {
        delete menu;
    }
    return 0;
}

void ShowSubgroupMenu(int client, const char[] gamemode)
{
    Menu menu = new Menu(SubgroupMenuHandler);
    menu.SetTitle("Subgroups: %s", gamemode);
    
    KeyValues kv = GetMapcycle();
    ArrayList gameModes = GetGameModesList();
    bool useSharedList = (gameModes != null && gameModes.Length > 0);
    
    int itemCount = 0;
    
    if (useSharedList)
    {
        int index = MMC_FindGameModeIndex(gamemode);
        if (index != -1)
        {
            GameModeConfig config;
            gameModes.GetArray(index, config);
            
            if (config.subGroups != null)
            {
                for (int i = 0; i < config.subGroups.Length; i++)
                {
                    SubGroupConfig subConfig;
                    config.subGroups.GetArray(i, subConfig);
                    
                    char display[128];
                    strcopy(display, sizeof(display), subConfig.name);
                    
                    menu.AddItem(subConfig.name, display);
                    itemCount++;
                }
            }
        }
    }
    else
    {
        if (kv != null)
        {
            kv.Rewind();
            if (kv.GotoFirstSubKey(false))
            {
                do
                {
                    char sectionName[64];
                    kv.GetSectionName(sectionName, sizeof(sectionName));
                    if (!StrEqual(sectionName, gamemode))
                        continue;
                    
                    if (kv.JumpToKey("subgroup"))
                    {
                        if (kv.GotoFirstSubKey(false))
                        {
                            do
                            {
                                char subgroupName[64];
                                kv.GetSectionName(subgroupName, sizeof(subgroupName));
                                
                                char display[128];
                                strcopy(display, sizeof(display), subgroupName);
                                
                                menu.AddItem(subgroupName, display);
                                itemCount++;
                            } while (kv.GotoNextKey(false));
                            kv.GoBack();
                        }
                        kv.GoBack();
                    }
                    break;
                } while (kv.GotoNextKey(false));
                kv.Rewind();
            }
        }
    }
    
    if (itemCount > 0)
    {
        menu.ExitBackButton = true;
        menu.Display(client, MENU_TIME_FOREVER);
    }
    else
    {
        CPrintToChat(client, "[MultiMode] No subgroups available.");
        delete menu;
    }
}

public int SubgroupMenuHandler(Menu menu, MenuAction action, int client, int param2)
{
    if (action == MenuAction_Select)
    {
        char subgroup[64];
        menu.GetItem(param2, subgroup, sizeof(subgroup));
        
        char title[128];
        menu.GetTitle(title, sizeof(title));
        
        char gamemode[64];
        int colonPos = FindCharInString(title, ':');
        if (colonPos != -1)
        {
            strcopy(gamemode, sizeof(gamemode), title[colonPos + 2]);
        }
        
        ShowSubgroupOptionsMenu(client, gamemode, subgroup);
    }
    else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack)
    {
        char title[128];
        menu.GetTitle(title, sizeof(title));
        
        char gamemode[64];
        int colonPos = FindCharInString(title, ':');
        if (colonPos != -1)
        {
            strcopy(gamemode, sizeof(gamemode), title[colonPos + 2]);
        }
        
        ShowGamemodeOptionsMenu(client, gamemode);
    }
    else if (action == MenuAction_End)
    {
        delete menu;
    }
    return 0;
}

void ShowSubgroupOptionsMenu(int client, const char[] gamemode, const char[] subgroup)
{
    KeyValues kv = GetMapcycle();
    bool hasDesc = HasDescription(kv, gamemode, subgroup);
    
    ArrayList gameModes = GetGameModesList();
    bool hasMaps = false;
    
    if (gameModes != null && gameModes.Length > 0)
    {
        int index = MMC_FindGameModeIndex(gamemode);
        if (index != -1)
        {
            GameModeConfig config;
            gameModes.GetArray(index, config);
            
            int subIndex = MMC_FindSubGroupIndex(gamemode, subgroup);
            if (subIndex != -1)
            {
                SubGroupConfig subConfig;
                config.subGroups.GetArray(subIndex, subConfig);
                hasMaps = (subConfig.maps != null && subConfig.maps.Length > 0);
            }
        }
    }
    else
    {
        if (kv != null)
        {
            kv.Rewind();
            if (kv.GotoFirstSubKey(false))
            {
                do
                {
                    char sectionName[64];
                    kv.GetSectionName(sectionName, sizeof(sectionName));
                    if (!StrEqual(sectionName, gamemode))
                        continue;
                    
                    if (kv.JumpToKey("subgroup"))
                    {
                        if (kv.GotoFirstSubKey(false))
                        {
                            do
                            {
                                char subName[64];
                                kv.GetSectionName(subName, sizeof(subName));
                                if (StrEqual(subName, subgroup))
                                {
                                    hasMaps = kv.JumpToKey("maps");
                                    if (hasMaps)
                                    {
                                        hasMaps = kv.GotoFirstSubKey(false);
                                        if (hasMaps)
                                        {
                                            kv.GoBack();
                                        }
                                        kv.GoBack();
                                    }
                                    break;
                                }
                            } while (kv.GotoNextKey(false));
                            kv.GoBack();
                        }
                        kv.GoBack();
                    }
                    break;
                } while (kv.GotoNextKey(false));
                kv.Rewind();
            }
        }
    }

    if (!hasDesc && hasMaps)
    {
        g_CameFromOptionsMenu[client] = false;
        strcopy(g_LastGamemode[client], sizeof(g_LastGamemode[]), gamemode);
        strcopy(g_LastSubgroup[client], sizeof(g_LastSubgroup[]), subgroup);
        ShowMapMenu(client, gamemode, subgroup);
        return;
    }

    if (!hasDesc && !hasMaps)
    {
        CPrintToChat(client, "[MultiMode] No options available for this subgroup.");
        return;
    }
    else
    {
        g_CameFromOptionsMenu[client] = true;
    }

    Menu menu = new Menu(SubgroupOptionsMenuHandler);
    menu.SetTitle("Subgroup: %s/%s", gamemode, subgroup);
    
    if (hasDesc)
    {
        menu.AddItem("description", "View Description");
    }
    
    if (hasMaps)
    {
        menu.AddItem("maps", "View Maps");
    }
    
    if (menu.ItemCount == 0)
    {
        CPrintToChat(client, "[MultiMode] No options available for this subgroup.");
        delete menu;
        return;
    }
    
    menu.ExitBackButton = true;
    menu.Display(client, MENU_TIME_FOREVER);
}

public int SubgroupOptionsMenuHandler(Menu menu, MenuAction action, int client, int param2)
{
    if (action == MenuAction_Select)
    {
        char option[32];
        menu.GetItem(param2, option, sizeof(option));
        
        char title[128];
        menu.GetTitle(title, sizeof(title));
        
        char gamemode[64], subgroup[64];
        int colonPos = FindCharInString(title, ':');
        int slashPos = FindCharInString(title, '/');
        if (colonPos != -1 && slashPos != -1)
        {
            int len = slashPos - colonPos - 2;
            if (len > 0 && len < sizeof(gamemode))
            {
                strcopy(gamemode, len + 1, title[colonPos + 2]);
            }
            strcopy(subgroup, sizeof(subgroup), title[slashPos + 1]);
        }
        
        if (StrEqual(option, "description"))
        {
            g_CameFromOptionsMenu[client] = true;
            ShowDescriptionMenu(client, gamemode, subgroup);
        }
        else if (StrEqual(option, "maps"))
        {
            g_CameFromOptionsMenu[client] = true;
            strcopy(g_LastGamemode[client], sizeof(g_LastGamemode[]), gamemode);
            strcopy(g_LastSubgroup[client], sizeof(g_LastSubgroup[]), subgroup);
            ShowMapMenu(client, gamemode, subgroup);
        }
    }
    else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack)
    {
        char title[128];
        menu.GetTitle(title, sizeof(title));
        
        char gamemode[64];
        int colonPos = FindCharInString(title, ':');
        int slashPos = FindCharInString(title, '/');
        if (colonPos != -1 && slashPos != -1)
        {
            int len = slashPos - colonPos - 2;
            if (len > 0 && len < sizeof(gamemode))
            {
                strcopy(gamemode, len + 1, title[colonPos + 2]);
            }
        }
        
        ShowSubgroupMenu(client, gamemode);
    }
    else if (action == MenuAction_End)
    {
        delete menu;
    }
    return 0;
}

void ShowMapMenu(int client, const char[] gamemode, const char[] subgroup = "")
{
    Menu menu = new Menu(MapMenuHandler);
    
    if (strlen(subgroup) > 0)
    {
        menu.SetTitle("Maps: %s/%s", gamemode, subgroup);
    }
    else
    {
        menu.SetTitle("Maps: %s", gamemode);
    }
    
    KeyValues kv = GetMapcycle();
    if (kv == null)
    {
        CPrintToChat(client, "[MultiMode] Failed to load mapcycle.");
        delete menu;
        return;
    }
    
    int itemCount = 0;
    
    kv.Rewind();
    if (kv.GotoFirstSubKey(false))
    {
        do
        {
            char sectionName[64];
            kv.GetSectionName(sectionName, sizeof(sectionName));
            if (!StrEqual(sectionName, gamemode))
                continue;
            
            if (strlen(subgroup) > 0)
            {
                if (kv.JumpToKey("subgroup"))
                {
                    if (kv.GotoFirstSubKey(false))
                    {
                        do
                        {
                            char subName[64];
                            kv.GetSectionName(subName, sizeof(subName));
                            if (!StrEqual(subName, subgroup))
                                continue;
                            
                            if (kv.JumpToKey("maps"))
                            {
                                if (kv.GotoFirstSubKey(false))
                                {
                                    do
                                    {
                                        char map[PLATFORM_MAX_PATH];
                                        kv.GetSectionName(map, sizeof(map));
                                        
                                        bool hasDesc = kv.JumpToKey("descriptions");
                                        if (hasDesc)
                                        {
                                            kv.GoBack();
                                        }
                                        
                                        char display[256];
                                        MultiMode_GetMapDisplayName(gamemode, map, subgroup, display, sizeof(display));
                                        
                                        if (hasDesc)
                                        {
                                            menu.AddItem(map, display);
                                        }
                                        else
                                        {
                                            menu.AddItem(map, display, ITEMDRAW_DISABLED);
                                        }
                                        
                                        itemCount++;
                                    } while (kv.GotoNextKey(false));
                                    kv.GoBack();
                                }
                                kv.GoBack();
                            }
                            break;
                        } while (kv.GotoNextKey(false));
                        kv.GoBack();
                    }
                    kv.GoBack();
                }
            }
            else
            {
                if (kv.JumpToKey("maps"))
                {
                    if (kv.GotoFirstSubKey(false))
                    {
                        do
                        {
                            char map[PLATFORM_MAX_PATH];
                            kv.GetSectionName(map, sizeof(map));
                            
                            bool hasDesc = kv.JumpToKey("descriptions");
                            if (hasDesc)
                            {
                                kv.GoBack();
                            }
                            
                            char display[256];
                            MultiMode_GetMapDisplayName(gamemode, map, "", display, sizeof(display));
                            
                            if (hasDesc)
                            {
                                menu.AddItem(map, display);
                            }
                            else
                            {
                                menu.AddItem(map, display, ITEMDRAW_DISABLED);
                            }
                            
                            itemCount++;
                        } while (kv.GotoNextKey(false));
                        kv.GoBack();
                    }
                    kv.GoBack();
                }
            }
            break;
        } while (kv.GotoNextKey(false));
        kv.Rewind();
    }
    
    if (itemCount > 0)
    {
        menu.ExitBackButton = true;
        menu.Display(client, MENU_TIME_FOREVER);
    }
    else
    {
        CPrintToChat(client, "[MultiMode] No maps available.");
        delete menu;
    }
}

public int MapMenuHandler(Menu menu, MenuAction action, int client, int param2)
{
    if (action == MenuAction_Select)
    {
        char map[PLATFORM_MAX_PATH];
        menu.GetItem(param2, map, sizeof(map));
        
        char title[128];
        menu.GetTitle(title, sizeof(title));
        
        char gamemode[64], subgroup[64];
        int colonPos = FindCharInString(title, ':');
        if (colonPos != -1)
        {
            int slashPos = FindCharInString(title[colonPos + 2], '/');
            if (slashPos != -1)
            {
                int len = slashPos;
                if (len > 0 && len < sizeof(gamemode))
                {
                    strcopy(gamemode, len + 1, title[colonPos + 2]);
                }
                strcopy(subgroup, sizeof(subgroup), title[colonPos + slashPos + 3]);
            }
            else
            {
                strcopy(gamemode, sizeof(gamemode), title[colonPos + 2]);
            }
        }
        
        ShowDescriptionMenu(client, gamemode, (strlen(subgroup) > 0) ? subgroup : "", map);
    }
    else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack)
    {
        char title[128];
        menu.GetTitle(title, sizeof(title));
        
        char gamemode[64], subgroup[64];
        int colonPos = FindCharInString(title, ':');
        if (colonPos != -1)
        {
            int slashPos = FindCharInString(title[colonPos + 2], '/');
            if (slashPos != -1)
            {
                int len = slashPos;
                if (len > 0 && len < sizeof(gamemode))
                {
                    strcopy(gamemode, len + 1, title[colonPos + 2]);
                }
                strcopy(subgroup, sizeof(subgroup), title[colonPos + slashPos + 3]);
                
                if (g_CameFromOptionsMenu[client])
                {
                    ShowSubgroupOptionsMenu(client, gamemode, subgroup);
                }
                else
                {
                    ShowSubgroupMenu(client, gamemode);
                }
            }
            else
            {
                strcopy(gamemode, sizeof(gamemode), title[colonPos + 2]);
                
                if (g_CameFromOptionsMenu[client])
                {
                    ShowGamemodeOptionsMenu(client, gamemode);
                }
                else
                {
                    ShowGamemodeMenu(client);
                }
            }
        }
        else
        {
            strcopy(gamemode, sizeof(gamemode), g_LastGamemode[client]);
            if (strlen(gamemode) > 0)
            {
                ShowGamemodeMenu(client);
            }
        }
    }
    else if (action == MenuAction_End)
    {
        delete menu;
    }
    return 0;
}

void ShowDescriptionMenu(int client, const char[] gamemode, const char[] subgroup = "", const char[] map = "")
{
    KeyValues kv = GetMapcycle();
    if (kv == null)
    {
        CPrintToChat(client, "[MultiMode] Failed to load mapcycle.");
        return;
    }
    
    kv.Rewind();
    
    if (!kv.GotoFirstSubKey(false))
    {
        CPrintToChat(client, "[MultiMode] Description not found.");
        return;
    }
    
    bool found = false;
    KeyValues descKv = null;
    do
    {
        char sectionName[64];
        kv.GetSectionName(sectionName, sizeof(sectionName));
        if (!StrEqual(sectionName, gamemode))
            continue;
        
        if (strlen(map) > 0)
        {
            if (strlen(subgroup) > 0)
            {
                if (kv.JumpToKey("subgroup"))
                {
                    if (kv.GotoFirstSubKey(false))
                    {
                        do
                        {
                            char subName[64];
                            kv.GetSectionName(subName, sizeof(subName));
                            if (!StrEqual(subName, subgroup))
                                continue;
                            
                            if (kv.JumpToKey("maps"))
                            {
                                if (kv.GotoFirstSubKey(false))
                                {
                                    do
                                    {
                                        char mapKey[PLATFORM_MAX_PATH];
                                        kv.GetSectionName(mapKey, sizeof(mapKey));
                                        if (!StrEqual(mapKey, map))
                                            continue;
                                        
                                        if (kv.JumpToKey("descriptions"))
                                        {
                                            descKv = kv;
                                            found = true;
                                            break;
                                        }
                                    } while (kv.GotoNextKey(false));
                                    if (!found)
                                        kv.GoBack();
                                }
                                if (!found)
                                    kv.GoBack();
                            }
                            break;
                        } while (kv.GotoNextKey(false));
                        if (!found)
                            kv.GoBack();
                    }
                    if (!found)
                        kv.GoBack();
                }
            }
            else
            {
                if (kv.JumpToKey("maps"))
                {
                    if (kv.GotoFirstSubKey(false))
                    {
                        do
                        {
                            char mapKey[PLATFORM_MAX_PATH];
                            kv.GetSectionName(mapKey, sizeof(mapKey));
                            if (!StrEqual(mapKey, map))
                                continue;
                            
                            if (kv.JumpToKey("descriptions"))
                            {
                                descKv = kv;
                                found = true;
                                break;
                            }
                        } while (kv.GotoNextKey(false));
                        if (!found)
                            kv.GoBack();
                    }
                    if (!found)
                        kv.GoBack();
                }
            }
        }
        else if (strlen(subgroup) > 0)
        {
            if (kv.JumpToKey("subgroup"))
            {
                if (kv.GotoFirstSubKey(false))
                {
                    do
                    {
                        char subName[64];
                        kv.GetSectionName(subName, sizeof(subName));
                        if (!StrEqual(subName, subgroup))
                            continue;
                        
                        if (kv.JumpToKey("descriptions"))
                        {
                            descKv = kv;
                            found = true;
                            break;
                        }
                    } while (kv.GotoNextKey(false));
                    if (!found)
                        kv.GoBack();
                }
                if (!found)
                    kv.GoBack();
            }
        }
        else
        {
            if (kv.JumpToKey("descriptions"))
            {
                descKv = kv;
                found = true;
            }
        }
        
        if (found)
            break;
    } while (kv.GotoNextKey(false));
    
    if (!found || descKv == null)
    {
        CPrintToChat(client, "[MultiMode] Description not found.");
        kv.Rewind();
        return;
    }

    if (!CheckDescriptionAccess(client, descKv))
    {
        LogError("[MMC Descriptions] Client %N (ID: %d) doesn't have access to description for %s/%s/%s", client, client, gamemode, subgroup, map);
        CPrintToChat(client, "[MultiMode] You don't have access to this description.");
        kv.Rewind();
        return;
    }
    
    MMC_WriteToLogFileEx("[MMC Descriptions] Showing description menu for client %N (ID: %d) - %s/%s/%s", client, client, gamemode, subgroup, map);

    Menu menu = new Menu(DescriptionMenuHandler);
    
    char title[128];
    descKv.GetString("description_title", title, sizeof(title), "Description");
    menu.SetTitle(title);
    MMC_WriteToLogFileEx("[MMC Descriptions] Menu title: '%s'", title);
    
    char description[2048];
    descKv.GetString("description", description, sizeof(description), "");
    if (strlen(description) > 0)
    {
        MMC_WriteToLogFileEx("[MMC Descriptions] Found description text (length: %d)", strlen(description));
        ProcessDescriptionText(menu, description);
    }
    else
    {
        MMC_WriteToLogFileEx("[MMC Descriptions] No description text found");
    }

    char currentServerGamemode[64];
    char currentServerSubgroup[64];
    MultiMode_GetCurrentGameMode(currentServerGamemode, sizeof(currentServerGamemode), currentServerSubgroup, sizeof(currentServerSubgroup));
    MMC_WriteToLogFileEx("[MMC Descriptions] Current server gamemode: '%s', subgroup: '%s'", currentServerGamemode, currentServerSubgroup);
    
    int linkIndex = 0;
    
    MMC_WriteToLogFileEx("[MMC Descriptions] Processing description links for %s/%s/%s", gamemode, subgroup, map);
    
    if (descKv.JumpToKey("description_link"))
    {
        MMC_WriteToLogFileEx("[MMC Descriptions] Found description_link (no number)");
        
        char linkDesc[128];
        char linkCmd[128];
        int onlyIngamemode = descKv.GetNum("only_ingamemode", 0); // Default to 0 (false)
        
        descKv.GetString("description", linkDesc, sizeof(linkDesc), "");
        descKv.GetString("command", linkCmd, sizeof(linkCmd), "");
        descKv.GoBack();
        
        MMC_WriteToLogFileEx("[MMC Descriptions] description_link values: desc='%s' cmd='%s' only_ingamemode='%d'", linkDesc, linkCmd, onlyIngamemode);
        
        if (strlen(linkDesc) > 0 && strlen(linkCmd) > 0)
        {
            int itemStyle = ITEMDRAW_DEFAULT;
            if (onlyIngamemode == 1 && !StrEqual(currentServerGamemode, gamemode))
            {
                itemStyle = ITEMDRAW_DISABLED;
                MMC_WriteToLogFileEx("[MMC Descriptions] Disabling link '%s' because 'only_ingamemode' is 1 and current gamemode ('%s') != description gamemode ('%s')", linkDesc, currentServerGamemode, gamemode);
            }

            char itemInfo[256];
            Format(itemInfo, sizeof(itemInfo), "link_%s", linkCmd);
            menu.AddItem(itemInfo, linkDesc, itemStyle);
            linkIndex++;
            MMC_WriteToLogFileEx("[MMC Descriptions] Added description_link (no number) to menu with style %d", itemStyle);
        }
        else
        {
            MMC_WriteToLogFileEx("[MMC Descriptions] description_link (no number) missing desc or cmd");
        }
    }
    else
    {
        MMC_WriteToLogFileEx("[MMC Descriptions] No description_link (no number) found");
    }
    
    int linkCopyNum = 2;
    do
    {
        char linkKey[64];
        Format(linkKey, sizeof(linkKey), "description_link_%d", linkCopyNum);
        
        if (descKv.JumpToKey(linkKey))
        {
            char linkDesc[128];
            char linkCmd[128];
            int onlyIngamemode = descKv.GetNum("only_ingamemode", 0);
            
            descKv.GetString("description", linkDesc, sizeof(linkDesc), "");
            descKv.GetString("command", linkCmd, sizeof(linkCmd), "");
            descKv.GoBack();
            
            MMC_WriteToLogFileEx("[MMC Descriptions] Found %s (subkey): desc='%s' cmd='%s' only_ingamemode='%d'", linkKey, linkDesc, linkCmd, onlyIngamemode);
            
            if (strlen(linkDesc) > 0 && strlen(linkCmd) > 0)
            {
                int itemStyle = ITEMDRAW_DEFAULT;
                if (onlyIngamemode == 1 && !StrEqual(currentServerGamemode, gamemode))
                {
                    itemStyle = ITEMDRAW_DISABLED;
                    MMC_WriteToLogFileEx("[MMC Descriptions] Disabling link '%s' because 'only_ingamemode' is 1 and current gamemode ('%s') != description gamemode ('%s')", linkDesc, currentServerGamemode, gamemode);
                }

                char itemInfo[256];
                Format(itemInfo, sizeof(itemInfo), "link_%s", linkCmd);
                menu.AddItem(itemInfo, linkDesc, itemStyle);
                linkIndex++;
                MMC_WriteToLogFileEx("[MMC Descriptions] Added %s to menu with style %d", linkKey, itemStyle);
            }
            else
            {
                MMC_WriteToLogFileEx("[MMC Descriptions] %s missing desc or cmd", linkKey);
            }
        }
        else
        {
            char linkDesc[128];
            descKv.GetString(linkKey, linkDesc, sizeof(linkDesc), "");
            
            if (strlen(linkDesc) == 0)
            {
                MMC_WriteToLogFileEx("[MMC Descriptions] %s not found, stopping copy format search", linkKey);
                break;
            }
            
            char cmdKey[64];
            Format(cmdKey, sizeof(cmdKey), "description_link_%d_command", linkCopyNum);
            char linkCmd[128];
            descKv.GetString(cmdKey, linkCmd, sizeof(linkCmd), "");

            char onlyIngamemodeKey[64];
            Format(onlyIngamemodeKey, sizeof(onlyIngamemodeKey), "description_link_%d_only_ingamemode", linkCopyNum);
            int onlyIngamemode = descKv.GetNum(onlyIngamemodeKey, 0);
            
            MMC_WriteToLogFileEx("[MMC Descriptions] Found %s (string): desc='%s' cmd='%s' only_ingamemode='%d'", linkKey, linkDesc, linkCmd, onlyIngamemode);
            
            if (strlen(linkCmd) > 0)
            {
                int itemStyle = ITEMDRAW_DEFAULT;
                if (onlyIngamemode == 1 && !StrEqual(currentServerGamemode, gamemode))
                {
                    itemStyle = ITEMDRAW_DISABLED;
                    MMC_WriteToLogFileEx("[MMC Descriptions] Disabling link '%s' because 'only_ingamemode' is 1 and current gamemode ('%s') != description gamemode ('%s')", linkDesc, currentServerGamemode, gamemode);
                }

                char itemInfo[256];
                Format(itemInfo, sizeof(itemInfo), "link_%s", linkCmd);
                menu.AddItem(itemInfo, linkDesc, itemStyle);
                linkIndex++;
                MMC_WriteToLogFileEx("[MMC Descriptions] Added %s (string) to menu with style %d", linkKey, itemStyle);
            }
            else
            {
                MMC_WriteToLogFileEx("[MMC Descriptions] %s (string) missing cmd", linkKey);
            }
        }
        
        linkCopyNum++;
    } while (linkCopyNum < 100 && linkIndex < 100);
    
    MMC_WriteToLogFileEx("[MMC Descriptions] Total description links added: %d", linkIndex);
    
    menu.ExitBackButton = true;
    
    strcopy(g_LastGamemode[client], sizeof(g_LastGamemode[]), gamemode);
    strcopy(g_LastSubgroup[client], sizeof(g_LastSubgroup[]), subgroup);
    strcopy(g_LastMap[client], sizeof(g_LastMap[]), map);
    
    menu.Display(client, MENU_TIME_FOREVER);
    
    kv.Rewind();
}

public int DescriptionMenuHandler(Menu menu, MenuAction action, int client, int param2)
{
    if (action == MenuAction_Select)
    {
        if (param2 == -1)
        {
            CPrintToChat(client, "[MultiMode] This option is currently disabled.");
        }
        else
        {
            char info[128];
            menu.GetItem(param2, info, sizeof(info));
            
            if (StrContains(info, "link_") == 0)
            {
                char command[128];
                strcopy(command, sizeof(command), info[5]);
                
                FakeClientCommand(client, command);
            }
        }
    }
    else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack)
    {
        char gamemode[64], subgroup[64], map[PLATFORM_MAX_PATH];
        strcopy(gamemode, sizeof(gamemode), g_LastGamemode[client]);
        strcopy(subgroup, sizeof(subgroup), g_LastSubgroup[client]);
        strcopy(map, sizeof(map), g_LastMap[client]);
        
        if (strlen(map) > 0)
        {
            if (strlen(subgroup) > 0)
            {
                ShowMapMenu(client, gamemode, subgroup);
            }
            else
            {
                ShowMapMenu(client, gamemode);
            }
        }
        else if (strlen(subgroup) > 0)
        {
            ShowSubgroupOptionsMenu(client, gamemode, subgroup);
        }
        else
        {
            ShowGamemodeOptionsMenu(client, gamemode);
        }
    }
    else if (action == MenuAction_End)
    {
        delete menu;
    }
    return 0;
}

void ProcessDescriptionText(Menu menu, const char[] text)
{
    if (strlen(text) == 0)
        return;
    
    char buffer[2048];
    strcopy(buffer, sizeof(buffer), text);
    
    ReplaceString(buffer, sizeof(buffer), "/n", "\n");
    
    int pos = 0;
    int lastPos = 0;
    int lineNum = 0;
    
    while ((pos = FindCharInString(buffer[lastPos], '\n')) != -1)
    {
        pos += lastPos;
        
        char line[256];
        int len = pos - lastPos;
        if (len > 255) len = 255;
        strcopy(line, len + 1, buffer[lastPos]);
        
        if (strlen(line) > 0)
        {
            char itemInfo[32];
            Format(itemInfo, sizeof(itemInfo), "desc_%d", lineNum);
            menu.AddItem(itemInfo, line, ITEMDRAW_DISABLED);
            lineNum++;
        }
        
        lastPos = pos + 1;
    }
    
    if (lastPos < strlen(buffer))
    {
        char line[256];
        strcopy(line, sizeof(line), buffer[lastPos]);
        if (strlen(line) > 0)
        {
            char itemInfo[32];
            Format(itemInfo, sizeof(itemInfo), "desc_%d", lineNum);
            menu.AddItem(itemInfo, line, ITEMDRAW_DISABLED);
        }
    }
    
    if (lineNum == 0 && strlen(buffer) > 0)
    {
        menu.AddItem("desc_0", buffer, ITEMDRAW_DISABLED);
    }
}

stock void MMC_WriteToLogFileEx(const char[] format, any ...)
{
    if (!GetConVarBool(g_Cvar_DescriptionsLogs))
    {
        return;
    }

    char buffer[512];
    VFormat(buffer, sizeof(buffer), format, 2);

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