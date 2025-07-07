#if defined _multimode_base_included
 #endinput
#endif
#define _multimode_base_included

#include <adt_array>

#define MAX_GAMEMODES 64
#define MAX_MAPS_PER_MODE 128

enum struct GameModeConfig {
    char name[64];
    char command[256];
    int maps_invote;
    ArrayList maps;
}

methodmap GameMode {
    public GameMode(const char[] name, const char[] cmd, int limit) {
        GameModeConfig config;
        strcopy(config.name, sizeof(config.name), name);
        strcopy(config.command, sizeof(config.command), cmd);
        config.maps_invote = limit;
        config.maps = new ArrayList(ByteCountToCells(256));
        
        // Armazena em uma lista global
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
            
            // Ler serverconfig
            if (g_kvGameModes.JumpToKey("serverconfig"))
            {
                g_kvGameModes.GetString("command", config.command, sizeof(config.command), "");
                g_kvGameModes.GoBack();
            }
            
            // Ler maps
            config.maps = new ArrayList(ByteCountToCells(256));
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
            
            config.maps_invote = g_kvGameModes.GetNum("maps_invote", 6);
            list.PushArray(config);
        } while (g_kvGameModes.GotoNextKey());
    }
    
    Call_StartFunction(null, GetFunctionByName(null, "OnGamemodeConfigLoaded"));
    Call_Finish();
}