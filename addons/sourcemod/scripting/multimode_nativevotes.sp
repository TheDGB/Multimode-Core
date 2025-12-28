/*****************************************************************************
                     Multi Mode Core Native Votes Support
******************************************************************************/

#include <sourcemod>
#include <emitsoundany>
#include <multimode>
#include <multimode/base>
#include <multimode/utils>
#include <nativevotes>

#pragma semicolon 1
#pragma newdecls required

public Plugin myinfo = 
{
    name = "[MMC] MultiMode Native Votes Support",
    author = "Oppressive Territory",
    description = "NativeVotes integration for MultiMode Core",
    version = PLUGIN_VERSION,
    url = ""
}

NativeVote g_hVote;
bool g_bVoteActive = false;

ConVar g_CvVoteSounds;
ConVar g_CvVoteOpenSound;
ConVar g_CvRunoffVoteOpenSound;
ConVar g_CvNativeVotesLogs;

public void OnPluginStart()
{
    LoadTranslations("multimode_voter.phrases");
}

public void OnAllPluginsLoaded()
{
    g_CvVoteSounds = FindConVar("multimode_votesounds");
    g_CvVoteOpenSound = FindConVar("multimode_voteopensound");
    g_CvRunoffVoteOpenSound = FindConVar("multimode_runoff_voteopensound");
    g_CvNativeVotesLogs = CreateConVar("multimode_nativevotes_logs", "1", "Enable/disable logging for native votes", _, true, 0.0, true, 1.0);
}

public void OnLibraryAdded(const char[] name)
{
    if (StrEqual(name, "multimode_core"))
    {
        RegisterManager();

        g_CvVoteSounds = FindConVar("multimode_votesounds");
        g_CvVoteOpenSound = FindConVar("multimode_voteopensound");
        g_CvRunoffVoteOpenSound = FindConVar("multimode_runoff_voteopensound");
    }
}

void RegisterManager()
{
    MultiMode_RegisterVoteManager("core", NativeVotes_StartVote, NativeVotes_CancelVote);
}

public void NativeVotes_StartVote(int initiator, VoteType type, const char[] info, ArrayList items, int duration, bool adminVote, bool isRunoff, const char[] startSound, const char[] endSound, const char[] runoffstartSound, const char[] runoffendSound)
{
    if (!LibraryExists("nativevotes"))
    {
        LogError("NativeVotes library not found! Cannot start vote.");
        delete items; 
        return;
    }

    if (g_CvVoteSounds != null && g_CvVoteSounds.BoolValue)
    {
        char sound[PLATFORM_MAX_PATH];
        sound[0] = '\0';
        
        if (isRunoff)
        {
            if (runoffstartSound[0] != '\0')
            {
                strcopy(sound, sizeof(sound), runoffstartSound);
            }
            else if (g_CvRunoffVoteOpenSound != null)
        {
            g_CvRunoffVoteOpenSound.GetString(sound, sizeof(sound));
        }
        }
        else
        {
            if (startSound[0] != '\0')
            {
                strcopy(sound, sizeof(sound), startSound);
            }
        else if (g_CvVoteOpenSound != null)
        {
            g_CvVoteOpenSound.GetString(sound, sizeof(sound));
            }
        }

        if (sound[0] != '\0')
        {
            PrecacheSoundAny(sound, true);
            EmitSoundToAllAny(sound);
        }
    }

    MMC_WriteToLogFile(g_CvNativeVotesLogs, "[MultiMode NativeVotes] Starting Vote. Type: %d, Items: %d", type, items.Length);

    NativeVotesType nvType = NativeVotesType_Custom_Mult;
    
    g_hVote = NativeVotes_Create(NativeVotes_Handler, nvType);
    if (g_hVote == null)
    {
        LogError("Failed to create NativeVote!");
        delete items;
        return;
    }

    g_hVote.VoteResultCallback = NativeVotes_ResultHandler;
    
    char title[256];
    switch (type)
    {
        case VOTE_TYPE_GROUP: Format(title, sizeof(title), "%T", "Normal Vote Gamemode Group Title", LANG_SERVER);
        case VOTE_TYPE_SUBGROUP: Format(title, sizeof(title), "%T", "SubGroup Vote Title", LANG_SERVER, info);
        case VOTE_TYPE_MAP: Format(title, sizeof(title), "%T", "Start Map Vote Title", LANG_SERVER, info);
        case VOTE_TYPE_SUBGROUP_MAP: Format(title, sizeof(title), "%T", "SubGroup Map Vote Title", LANG_SERVER, info);
    }
    g_hVote.SetTitle(title);

    for (int i = 0; i < items.Length; i++)
    {
        VoteCandidate item;
        items.GetArray(i, item);
        g_hVote.AddItem(item.info, item.name);
    }

    g_hVote.DisplayVoteToAll(duration);
    g_bVoteActive = true;
    
    delete items;
}

public void NativeVotes_CancelVote()
{
    if (g_bVoteActive && g_hVote != null)
    {
        NativeVotes_Cancel();
        g_bVoteActive = false;
        g_hVote = null;
        MMC_WriteToLogFile(g_CvNativeVotesLogs, "[MultiMode NativeVotes] Vote Cancelled.");
    }
}

public int NativeVotes_Handler(NativeVote vote, MenuAction action, int param1, int param2)
{
    switch (action)
    {
        case MenuAction_End:
        {
            vote.Close();
            g_hVote = null;
            g_bVoteActive = false;
        }
        case MenuAction_VoteCancel:
        {
            if (param1 == VoteCancel_NoVotes)
            {
                vote.DisplayFail(NativeVotesFail_NotEnoughVotes);
                g_bVoteActive = false;
                
                ArrayList emptyResults = new ArrayList(sizeof(VoteCandidate));
                MultiMode_ReportVoteResults(emptyResults, 0, 0);
                delete emptyResults;
            }
            else
            {
                vote.DisplayFail(NativeVotesFail_Generic);
                g_bVoteActive = false;
                
                ArrayList emptyResults = new ArrayList(sizeof(VoteCandidate));
                MultiMode_ReportVoteResults(emptyResults, 0, 0);
                delete emptyResults;
            }
        }
    }
    return 0;
}

public void NativeVotes_ResultHandler(NativeVote vote, int num_votes, int num_clients, const int[] client_indexes, const int[] client_votes, int num_items, const int[] item_indexes, const int[] item_votes)
{
    ArrayList results = new ArrayList(sizeof(VoteCandidate));
    
    int maxVotes = -1;
    int winnerIndex = -1;

    for (int i = 0; i < num_items; i++)
    {
        VoteCandidate res;
        res.votes = item_votes[i];
        vote.GetItem(item_indexes[i], res.info, sizeof(res.info), res.name, sizeof(res.name));
        res.originalIndex = item_indexes[i];
        results.PushArray(res);

        if (res.votes > maxVotes)
        {
            maxVotes = res.votes;
            winnerIndex = i;
        }
    }
    
    if (winnerIndex != -1)
    {
        VoteCandidate winnerRes;
        results.GetArray(winnerIndex, winnerRes);
        
        char display[256];
        vote.GetItem(item_indexes[winnerIndex], "", 0, display, sizeof(display));
        vote.DisplayPass(display);
        
        bool isExtendMap = StrEqual(winnerRes.info, "Extend Map") || 
                          (StrContains(winnerRes.name, "Extend") != -1 && StrContains(winnerRes.name, "Map") != -1) ||
                          StrEqual(winnerRes.info, "Extend current Map"); // NativeVotes constant
        
        if (isExtendMap)
        {
            MMC_WriteToLogFile(g_CvNativeVotesLogs, "[MultiMode NativeVotes] Extend Map detected (info='%s', name='%s')", 
                              winnerRes.info, winnerRes.name);
            
            strcopy(winnerRes.info, sizeof(winnerRes.info), "Extend Map");
            results.SetArray(winnerIndex, winnerRes);
        }
    }
    else
    {
        vote.DisplayFail(NativeVotesFail_NotEnoughVotes);
    }
    
    MMC_WriteToLogFile(g_CvNativeVotesLogs, "[MultiMode NativeVotes] Vote Finished. Reporting %d items to Core.", results.Length);
    
    MultiMode_ReportVoteResults(results, num_votes, num_clients);
    
    delete results;
}