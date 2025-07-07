stock void ExecuteModeCommands(const char[] gamemode)
{
    char sCommand[255];
    if (g_kvGameModes.JumpToKey(gamemode))
    {
        if (g_kvGameModes.GetString("command", sCommand, sizeof(sCommand)))
        {
            ServerCommand(sCommand);
        }
        g_kvGameModes.Rewind();
    }
}