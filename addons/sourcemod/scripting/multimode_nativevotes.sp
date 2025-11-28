/*****************************************************************************
                     Multi Mode Core Native Votes Support
******************************************************************************/

#include <sourcemod>
#include <emitsoundany>
#include <multimode>
#include <nativevotes>

#pragma semicolon 1
#pragma newdecls required

NativeVote g_hVote;
bool g_bVoteActive = false;

ConVar g_CvVoteSounds;
ConVar g_CvVoteOpenSound;
ConVar g_CvRunoffVoteOpenSound;

public void OnPluginStart()
{
    LoadTranslations("multimode_voter.phrases");
}

public void OnAllPluginsLoaded()
{
    g_CvVoteSounds = FindConVar("multimode_votesounds");
    g_CvVoteOpenSound = FindConVar("multimode_voteopensound");
    g_CvRunoffVoteOpenSound = FindConVar("multimode_runoff_voteopensound");
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

public void NativeVotes_StartVote(int initiator, VoteType type, const char[] info, ArrayList items, int duration, bool adminVote, bool isRunoff)
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
        if (isRunoff && g_CvRunoffVoteOpenSound != null)
        {
            g_CvRunoffVoteOpenSound.GetString(sound, sizeof(sound));
        }
        else if (g_CvVoteOpenSound != null)
        {
            g_CvVoteOpenSound.GetString(sound, sizeof(sound));
        }

        if (sound[0] != '\0')
        {
            PrecacheSound(sound, true);
            EmitSoundToAllAny(sound);
        }
    }

    LogMessage("[MultiMode NativeVotes] Starting Vote. Type: %d, Items: %d", type, items.Length);

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
        LogMessage("[MultiMode NativeVotes] Vote Cancelled.");
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
        results.PushArray(res);

        if (res.votes > maxVotes)
        {
            maxVotes = res.votes;
            winnerIndex = i;
        }
    }
    
    if (winnerIndex != -1)
    {
        char display[256];
        vote.GetItem(item_indexes[winnerIndex], "", 0, display, sizeof(display));
        vote.DisplayPass(display);
    }
    else
    {
        vote.DisplayFail(NativeVotesFail_NotEnoughVotes);
    }
    
    LogMessage("[MultiMode NativeVotes] Vote Finished. Reporting %d items to Core.", results.Length);
    
    MultiMode_ReportVoteResults(results, num_votes, num_clients);
    
    delete results;
}