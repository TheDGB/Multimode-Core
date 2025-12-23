/*****************************************************************************
                        Multi Mode Discord Support
******************************************************************************/

#include <multimode>
#include <discord>

ConVar g_Cvar_Discord;
ConVar g_Cvar_DiscordVoteStart;
ConVar g_Cvar_DiscordExtend;
ConVar g_Cvar_DiscordVoteResult;
ConVar g_Cvar_DiscordGamemodeChanged;
ConVar g_Cvar_DiscordWebhook;
ConVar g_Cvar_DiscordRunOff;
ConVar g_Cvar_DiscordFailed;

public void OnPluginStart()
{
    g_Cvar_Discord = CreateConVar("multimode_discord", "1", "Enable sending a message to Discord when a vote is successful.", _, true, 0.0, true, 1.0);
    g_Cvar_DiscordWebhook = CreateConVar("multimode_discordwebhook", "https://discord.com/api/webhooks/...", "Discord webhook URL to send messages to.", FCVAR_PROTECTED);
	g_Cvar_DiscordVoteStart = CreateConVar("multimode_discordvotestart", "1", "Enable discord webhook vote start.", _, true, 0.0, true, 1.0);
	g_Cvar_DiscordGamemodeChanged = CreateConVar("multimode_discordgamemodechanged", "1", "Enable discord webhook gamemode changes.", _, true, 0.0, true, 1.0);
    g_Cvar_DiscordVoteResult = CreateConVar("multimode_discordvoteresults", "1", "Enable discord webhook vote results.", _, true, 0.0, true, 1.0);
    g_Cvar_DiscordExtend = CreateConVar("multimode_discordextend", "1", "Enable discord webhook vote extensions.", _, true, 0.0, true, 1.0);
	g_Cvar_DiscordRunOff = CreateConVar("multimode_discordrunoff", "1", "Enable discord webhook vote run off.", _, true, 0.0, true, 1.0);
	g_Cvar_DiscordFailed = CreateConVar("multimode_discordfailed", "1", "Enable discord webhook when a vote fails.", _, true, 0.0, true, 1.0);
	
	AutoExecConfig(true, "multimode_discord");
}

public void MultiMode_OnVoteEnd(const char[] group, const char[] subgroup, const char[] map, VoteEndReason reason)
{
    if (!g_Cvar_Discord.BoolValue) 
        return;

    if (StrEqual(group, "extend"))
    {
        if (g_Cvar_DiscordExtend.BoolValue)
        {
            NotifyDiscordExtend();
        }
        return;
    }

    switch (reason)
    {
        case VoteEnd_Runoff:
        {
		    if (g_Cvar_DiscordRunOff.BoolValue)
            {
                NotifyDiscordRunoff();
			}
        }
        case VoteEnd_Cancelled:
        {
		    if (g_Cvar_DiscordFailed.BoolValue)
            {
                NotifyDiscordCancelled();
			}
        }
        case VoteEnd_Failed:
        {
		    if (g_Cvar_DiscordFailed.BoolValue)
            {
                NotifyDiscordFailed();
			}
        }
    }
}

public void MultiMode_OnGamemodeChanged(const char[] group, const char[] subgroup, const char[] map, int timing)
{
    if (g_Cvar_Discord.BoolValue && g_Cvar_DiscordGamemodeChanged.BoolValue)
    {
        char displayName[128];
        if (strlen(subgroup) == 0)
        {
            strcopy(displayName, sizeof(displayName), group);
        }
        else
        {
            Format(displayName, sizeof(displayName), "%s (Sub Group: %s)", group, subgroup);
        }

        NotifyDiscordGamemodeChange(displayName, map, timing);
    }
}

public void MultiMode_OnGamemodeChangedVote(const char[] group, const char[] subgroup, const char[] map, int timing)
{
    if (g_Cvar_Discord.BoolValue && g_Cvar_DiscordVoteResult.BoolValue)
    {
        char displayName[128];
        if (strlen(subgroup) == 0)
        {
            strcopy(displayName, sizeof(displayName), group);
        }
        else
        {
            Format(displayName, sizeof(displayName), "%s (Sub Group: %s)", group, subgroup);
        }

        NotifyDiscordVoteResult(displayName, map, timing);
    }
}

public void MultiMode_OnVoteStartEx(int initiator, int voteType)
{
    if (!g_Cvar_Discord.BoolValue || !g_Cvar_DiscordVoteStart.BoolValue) 
        return;

    ConVar cvarMethod = FindConVar("multimode_method");
    int method = (cvarMethod != null) ? cvarMethod.IntValue : 0;
	
	// if it is a gamemodes vote, show that it has started
    // if multimode_method 3, show map vote notification as a starting vote

    if (method == 1 && voteType == 0)
    {
        NotifyDiscordVoteStart(initiator);
    }
    else if (method == 3 && voteType == 1)
    {
        NotifyDiscordVoteStart(initiator);
    }
    else if (method != 1 && method != 3)
    {
        NotifyDiscordVoteStart(initiator);
    }
}


void NotifyDiscordVoteStart(int initiator)
{
    char webhook[256];
    g_Cvar_DiscordWebhook.GetString(webhook, sizeof(webhook));
    if (StrEqual(webhook, "")) return;

    DiscordWebHook hook = new DiscordWebHook(webhook);
    MessageEmbed embed = new MessageEmbed();
	
    embed.SetTitle("Vote Started");

    if (initiator <= 0)
    {
        embed.AddField("Initiator:", "Vote started by **System**", false);
    }
    else if (initiator > 0 && initiator <= MaxClients && IsClientInGame(initiator))
    {
        char playerName[MAX_NAME_LENGTH];
        GetClientName(initiator, playerName, sizeof(playerName));

        char buffer[128];
        Format(buffer, sizeof(buffer), "Vote started by **%s**", playerName);
        embed.AddField("Initiator:", buffer, false);
    }
    else
    {
        embed.AddField("Initiator:", "Vote started by **Unknown**", false);
    }

    embed.SetColor("#0099FF");

    char footer[128];
    FindConVar("hostname").GetString(footer, sizeof(footer));
    embed.SetFooter(footer);

    hook.SlackMode = true;
    hook.Embed(embed);
    hook.Send();
    delete hook;
}

void NotifyDiscordExtend()
{
    char webhook[256];
    g_Cvar_DiscordWebhook.GetString(webhook, sizeof(webhook));

    if (StrEqual(webhook, "")) return;

    DiscordWebHook hook = new DiscordWebHook(webhook);
    MessageEmbed embed = new MessageEmbed();
    
    embed.SetTitle("Map Extended");
    embed.AddField("Extension:", "The current map has been extended.", false);
    embed.SetColor("#FFE000");
    
    char footer[128];
    FindConVar("hostname").GetString(footer, sizeof(footer));
    embed.SetFooter(footer);
    
    hook.SlackMode = true;
    hook.Embed(embed);
    hook.Send();
    delete hook;
}

void NotifyDiscordCancelled()
{
    char webhook[256];
    g_Cvar_DiscordWebhook.GetString(webhook, sizeof(webhook));

    if (StrEqual(webhook, "")) return;

    DiscordWebHook hook = new DiscordWebHook(webhook);
    MessageEmbed embed = new MessageEmbed();
    
    embed.SetTitle("The current Vote has been cancelled.");
    char buffer[128];
    Format(buffer, sizeof(buffer), "The Vote was canceled by an administrator or third-party applications.");
    embed.AddField("Reason:", buffer, false);
    embed.SetColor("#FF0000");
    
    char footer[128];
    FindConVar("hostname").GetString(footer, sizeof(footer));
    embed.SetFooter(footer);
    
    hook.SlackMode = true;
    hook.Embed(embed);
    hook.Send();
    delete hook;
}

void NotifyDiscordFailed()
{
    char webhook[256];
    g_Cvar_DiscordWebhook.GetString(webhook, sizeof(webhook));

    if (StrEqual(webhook, "")) return;

    DiscordWebHook hook = new DiscordWebHook(webhook);
    MessageEmbed embed = new MessageEmbed();
    
    embed.SetTitle("The current Vote failed.");
    char buffer[128];
    Format(buffer, sizeof(buffer), "The current Vote failed due to Run Off limits or no votes recorded.");
    embed.AddField("Reason:", buffer, false);
    embed.SetColor("#FF0000");
    
    char footer[128];
    FindConVar("hostname").GetString(footer, sizeof(footer));
    embed.SetFooter(footer);
    
    hook.SlackMode = true;
    hook.Embed(embed);
    hook.Send();
    delete hook;
}

void NotifyDiscordRunoff()
{
    char webhook[256];
    g_Cvar_DiscordWebhook.GetString(webhook, sizeof(webhook));

    if (StrEqual(webhook, "")) return;

    DiscordWebHook hook = new DiscordWebHook(webhook);
    MessageEmbed embed = new MessageEmbed();
    
    embed.SetTitle("A Run Off vote will be held.");
    char buffer[128];
    Format(buffer, sizeof(buffer), "No option reached the minimum number of votes to win, a Run Off vote will be held...");
    embed.AddField("Reason:", buffer, false);
    embed.SetColor("#FF0000");
    
    char footer[128];
    FindConVar("hostname").GetString(footer, sizeof(footer));
    embed.SetFooter(footer);
    
    hook.SlackMode = true;
    hook.Embed(embed);
    hook.Send();
    delete hook;
}

void NotifyDiscordVoteResult(const char[] gamemode, const char[] map, int timing)
{
    char webhook[256];
    g_Cvar_DiscordWebhook.GetString(webhook, sizeof(webhook));
    
    if (StrEqual(webhook, "") || StrEqual(gamemode, "")) return;

    DiscordWebHook hook = new DiscordWebHook(webhook);
    MessageEmbed embed = new MessageEmbed();
    
    embed.SetTitle("Gamemode Vote Result");
    embed.AddField("Selected Gamemode:", gamemode, true);
    embed.AddField("Selected Map:", map, true);
	
    char timingStr[32];
    switch(timing)
    {
        case 0: Format(timingStr, sizeof(timingStr), "Next Map");
        case 1: Format(timingStr, sizeof(timingStr), "Next Round");
        case 2: Format(timingStr, sizeof(timingStr), "Instant");
        default: Format(timingStr, sizeof(timingStr), "Unknown");
    }
    embed.AddField("Scheduled For:", timingStr, false);
    embed.SetColor("#00FF3C");
	
    char thumbUrl[256];
    Format(thumbUrl, sizeof(thumbUrl), "https://image.gametracker.com/images/maps/160x120/tf2/%s.jpg", map);
    embed.SetThumb(thumbUrl);
    
    char footer[128];
    FindConVar("hostname").GetString(footer, sizeof(footer));
    embed.SetFooter(footer);
    
    hook.SlackMode = true;
    hook.Embed(embed);
    hook.Send();
    delete hook;
}

void NotifyDiscordGamemodeChange(const char[] gamemode, const char[] map, int timing)
{
    char webhook[256];
    g_Cvar_DiscordWebhook.GetString(webhook, sizeof(webhook));
    
    if (StrEqual(webhook, "") || StrEqual(gamemode, "")) return;

    DiscordWebHook hook = new DiscordWebHook(webhook);
    MessageEmbed embed = new MessageEmbed();
    
    embed.SetTitle("Gamemode Changed");
    embed.AddField("New Gamemode:", gamemode, true);
    embed.AddField("New Map:", map, true);
    
    char timingStr[32];
    switch(timing)
    {
        case 0: Format(timingStr, sizeof(timingStr), "Next Map");
        case 1: Format(timingStr, sizeof(timingStr), "Next Round");
        case 2: Format(timingStr, sizeof(timingStr), "Instant");
        default: Format(timingStr, sizeof(timingStr), "Unknown");
    }
    embed.AddField("Scheduled For:", timingStr, false);
    
    embed.SetColor("#0099FF");
    
    char footer[128];
    FindConVar("hostname").GetString(footer, sizeof(footer));
    embed.SetFooter(footer);
    
    hook.SlackMode = true;
    hook.Embed(embed);
    hook.Send();
    delete hook;
}