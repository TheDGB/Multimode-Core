# Multimode Core
This is a utility plugin for Source Mod that recreates the mapchooser/UMC for multimode gamemode selector for multimode servers.

Inspired by Map Chooser from Source Mode and UMC (Ultimate Map Chooser).

Do you have a suggestion for the plugin? You can make a **pull request!**

> ***(Warning: Remembering that this plugin is completely in beta and you need permission from the owner to use it on your server.)***

### Multimode Core Convars

#### Convars

| **ConVars**                                   | **Default Value** | **Description**                                             |
|-----------------------------------------------|-------------------|-------------------------------------------------------------|
| `sm_multimode_enabled`                        | `1`               | Enable the multimode voting system                          |
| `sm_multimode_votetime`                       | `20`              | Vote duration in seconds                                    |
| `sm_multimode_commandsdelay`                  | `1`               | Delay to execute commands after map loading                 |

#### Rock The Vote Convars

| **ConVars**                                   | **Default Value** | **Description**                                               |
|-----------------------------------------------|-------------------|---------------------------------------------------------------|
| `sm_multimode_rtvplayers`                     | `2`               | Minimum number of players to start RTV                        |
| `sm_multimode_rtvfirstdelay`                  | `60`              | Initial delay after map loads to allow RTV                    |
| `sm_multimode_rtvdelay`                       | `120`             | Delay after a vote to allow new RTV again                     |
| `sm_multimode_rtvtype`                        | `3`               | Voting Type for RTV: 1 - Next Map, 2 - Next Round, 3 - Instant|

#### End Vote Convars

| **ConVars**                                   | **Default Value** | **Description**                                                                     |
|-----------------------------------------------|-------------------|-------------------------------------------------------------------------------------|
| `sm_multimode_endvote_enabled`                | `1`               | Enables automatic end vote when the remaining map time reaches the configured limit.|
| `sm_multimode_endvote_min`                    | `6`               | Minutes remaining to start automatic voting.                                        |
| `sm_multimode_endvote_notify`                 | `1`               | Enable countdown notifications                                                      |
| `sm_multimode_endvotetype`                    | `1`               | Voting Type for End Vote: 1 - Next Map, 2 - Next Round, 3 - Instant                 |

#### Discord Support Convars

| **ConVars**                                   | **Default Value**                     | **Description**                                                                 |
|-----------------------------------------------|---------------------------------------|---------------------------------------------------------------------------------|
| `sm_multimode_discord`                        | `1`                                   | Enable sending a message to Discord when a vote is successful.                  |
| `sm_multimode_discordwebhook`                 | `https://discord.com/api/webhooks/...`| Discord webhook URL to send messages to.                                        |

> ***(Example of a webhook link: https://discord.com/api/webhooks/...)***

#### Vote Sounds Convars

| **ConVars**                                   | **Default Value**    | **Description**                                             |
|-----------------------------------------------|----------------------|-------------------------------------------------------------|
| `sm_multimode_votesounds`                     | `1`                  | Enables/disables voting and download sounds.                |
| `sm_multimode_voteopensound`                  | `CustomDir/Sound.wav`| Sound played when starting a vote                           |
| `sm_multimode_voteclosesound`                 | `CustomDir/Sound.wav`| Sound played when a vote ends                               |

#### Extend Map Convars

| **ConVars**                                   | **Default Value**    | **Description**                                                                    |
|-----------------------------------------------|----------------------|------------------------------------------------------------------------------------|
| `sm_multimode_extend`                         | `1`                  | Enables/disables the option to extend the map                                      |
| `sm_multimode_extendvote`                     | `1`                  | Shows the option to extend in normal polls                                         |
| `sm_multimode_extendvoteadmin`                | `1`                  | Sound played when a vote ends                                                      | 
| `sm_multimode_extendsteps`                    | `1`                  | Minutes added to mp_timelimit when map is extended.                                |
| `sm_multimode_extendeverytime`                | `0`                  | Allow extending the map multiple times in consecutive votes. 0 = only once per map.|

#### Dependencies.
- [Sourcemod 1.12+](https://www.sourcemod.net/downloads.php)
- [Discord API](https://github.com/Cruze03/sourcemod-discord/tree/master)
- [More Colors](https://github.com/DoctorMcKay/sourcemod-plugins/blob/master/scripting/include/morecolors.inc)

#### Supported Games.
- Team Fortress 2

# **Enjoy the plugin!**

[![](https://dcbadge.vercel.app/api/server/xftqrvZSAw)](https://discord.gg/xftqrvZSAw)
