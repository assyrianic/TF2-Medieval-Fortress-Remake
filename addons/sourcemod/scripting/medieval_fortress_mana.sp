#include <sourcemod>
#include <sdkhooks>
#include <tf2_stocks>
#include <morecolors>

#include <libmodsys>


#pragma semicolon    1
#pragma newdecls     required

#define PLUGIN_VERSION    "1.0.0"


public Plugin myinfo = {
	name        = "Medieval Fortress Mana Module",
	author      = "Nergal",
	description = "RPG-ified Medieval Mode",
	version     = PLUGIN_VERSION,
	url         = "zzzzzzzzzzzzz"
};


public void OnLibraryAdded(const char[] name) {
	if( StrEqual(name, "LibModSys") ) {
		PawnAwait(AwaitChannel, 0.25, {0}, 0);
	}
}

public bool AwaitChannel() {
	if( !LibModSys_ChannelExists("MedievalFortressCore") ) {
		return false;
	}
	
	SharedMap shared_map = SharedMap("MedievalFortressCore");
	int empty_mana[MAXPLAYERS+1];
	shared_map.SetArr("mana data", empty_mana, sizeof(empty_mana), IntType);
	shared_map.Unfreeze("mana data");
	
	int num_fwd_tiers;
	shared_map.GetInt("fwd tiers", num_fwd_tiers);
	
	ManagerID[] priv_fwds_ids = new ManagerID[num_fwd_tiers];
	for( int i; i < num_fwd_tiers; i++ ) {
		priv_fwds_ids[i] = LibModSys_MakePrivateFwdsManager("configs/medieval_fortress/mana.cfg");
	}
	
	shared_map.SetArr("mana fwds", priv_fwds_ids, num_fwd_tiers, EnumType);
	
	CreateConVar("medieval_fortress_mana_max", "10", "How much mana cap each player gets. 0 to disable mana", FCVAR_NONE, true, 0.0);
	CreateConVar("medieval_fortress_mana_div", "5", "How mana should be divided in the HUD.", FCVAR_NONE, true, 1.0);
	CreateConVar("medieval_fortress_mana_cutoff", "10", "mana amount cutoff for the HUD to simplify the mana bar to a simple number.", FCVAR_NONE, true, 1.0);
	AutoExecConfig(true, "MedievalFortress-Mana");
	
	HookEvent("player_score_changed", ScoreChanged);
	RegAdminCmd("sm_set_mana", Cmd_SetMana, ADMFLAG_GENERIC, "sets the mana of players.");
	
	return true;
}

public Action Cmd_SetMana(int client, int args) {
	if( !LibModSys_ChannelExists("MedievalFortressCore") ) {
		return Plugin_Handled;
	}
	
	char targetname[32]; GetCmdArg(1, targetname, sizeof(targetname));
	char mana_amnt[32];  GetCmdArg(2, mana_amnt,  sizeof(mana_amnt));
	int set_mana = StringToInt(mana_amnt);
	
	char target_name[MAX_TARGET_LENGTH];
	int target_list[MAXPLAYERS];
	bool tn_is_ml;
	int target_count = ProcessTargetString(targetname, client, target_list, MAXPLAYERS, 0, target_name, sizeof(target_name), tn_is_ml);
	if( target_count <= 0 ) {
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}
	
	SharedMap shared_map = SharedMap("MedievalFortressCore");
	int mana[MAXPLAYERS+1];
	shared_map.GetArr("mana data", mana, sizeof(mana), IntType);
	for( int i=0; i < target_count; i++ ) {
		if( IsClientInGame(target_list[i]) ) {
			mana[target_list[i]] = set_mana;
		}
	}
	shared_map.SetArr("mana data", mana, sizeof(mana), IntType);
	
	CReplyToCommand(client, "set mana of players to %i", set_mana);
	return Plugin_Handled;
}

public void OnClientPutInServer(int client) {
	if( !LibModSys_ChannelExists("MedievalFortressCore") ) {
		return;
	}
	SharedMap shared_map = SharedMap("MedievalFortressCore");
	
	int mana[MAXPLAYERS+1];
	shared_map.GetArr("mana data", mana, sizeof(mana), IntType);
	
	ConVar mana_max = FindConVar("medieval_fortress_mana_max");
	mana[client] = mana_max.IntValue;
	shared_map.SetArr("mana data", mana, sizeof(mana), IntType);
}

public Action ScoreChanged(Event event, const char[] name, bool dontBroadcast) {
	if( !LibModSys_ChannelExists("MedievalFortressCore") ) {
		return Plugin_Continue;
	}
	
	int player = event.GetInt("player");
	int delta  = event.GetInt("delta");
	SharedMap shared_map = SharedMap("MedievalFortressCore");
	
	int mana[MAXPLAYERS+1];
	shared_map.GetArr("mana data", mana, sizeof(mana), IntType);
	
	ConVar mana_max = FindConVar("medieval_fortress_mana_max");
	int max_mana  = mana_max.IntValue;
	int set_delta = delta;
	bool changed, overflow;
	
	int num_fwd_tiers; shared_map.GetInt("fwd tiers", num_fwd_tiers);
	ManagerID[] priv_fwds_ids = new ManagerID[num_fwd_tiers];
	int fwd_tiers_len = shared_map.GetArr("mana fwds", priv_fwds_ids, num_fwd_tiers, EnumType);
	if( fwd_tiers_len==num_fwd_tiers ) {
		for( int i; i < num_fwd_tiers; i++ ) {
			PrivateFwd pf;
			if( !LibModSys_GetPrivateFwd(priv_fwds_ids[i], "OnGainMana", pf) || pf.pf.FunctionCount==0 ) {
				continue;
			}
			
			pf.Start();
			pf.PushCell(event);
			pf.PushCell(mana[player]);
			pf.PushCellRef(delta);
			pf.PushCell(changed);
			pf.PushCellRef(overflow);
			pf.Finish();
			if( !changed && delta != set_delta ) {
				changed = true;
			}
		}
	}
	
	/// allow mana if set by admin or from event to overflow.
	if( mana[player] < max_mana || overflow ) {
		mana[player] += delta;
	}
	
	shared_map.SetArr("mana data", mana, sizeof(mana), IntType);
	if( fwd_tiers_len==num_fwd_tiers ) {
		for( int i; i < num_fwd_tiers; i++ ) {
			PrivateFwd pf;
			if( !LibModSys_GetPrivateFwd(priv_fwds_ids[i], "OnGainManaPost", pf) || pf.pf.FunctionCount==0 ) {
				continue;
			}
			
			pf.Start();
			pf.PushCell(event);
			pf.PushCell(mana[player]);
			pf.PushCell(delta);
			pf.PushCell(changed);
			pf.PushCell(overflow);
			pf.Finish();
		}
	}
	
	return Plugin_Continue;
}