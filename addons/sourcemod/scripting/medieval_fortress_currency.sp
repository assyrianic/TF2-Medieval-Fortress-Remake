#include <sourcemod>
#include <sdkhooks>

#include <tf2_stocks>
#include <morecolors>

#include <libmodsys>


#pragma semicolon    1
#pragma newdecls     required

#define PLUGIN_VERSION    "1.0.0"


public Plugin myinfo = {
	name        = "Medieval Fortress Currency Module",
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
	
	int empty_currency[MAXPLAYERS+1];
	shared_map.SetArr("currency data", empty_currency, sizeof(empty_currency), IntType);
	shared_map.Unfreeze("currency data");
	
	int num_fwd_tiers;
	shared_map.GetInt("fwd tiers", num_fwd_tiers);
	
	ManagerID[] priv_fwds_ids = new ManagerID[num_fwd_tiers];
	for( int i; i < num_fwd_tiers; i++ ) {
		priv_fwds_ids[i] = LibModSys_MakePrivateFwdsManager("configs/medieval_fortress/currency.cfg");
	}
	
	shared_map.SetArr("currency fwds", priv_fwds_ids, num_fwd_tiers, EnumType);
	
	CreateConVar("medieval_fortress_gold_gain", "50", "How much gold is gained for doing an action. 0 to disable", FCVAR_NONE, true, 0.0);
	CreateConVar("medieval_fortress_gold_set",  "0", "How much gold a player is given when they first connect & when the round resets.", FCVAR_NONE);
	AutoExecConfig(true, "MedievalFortress-Currency");
	
	HookEvent("player_death",         PlayerDeath);
	HookEvent("teamplay_round_start", RoundStart);
	HookEvent("arena_round_start",    RoundStart);
	
	RegAdminCmd("sm_show_gold", Cmd_PrintGold, ADMFLAG_GENERIC, "shows the gold of all players.");
	return true;
}

public Action Cmd_PrintGold(int client, int args) {
	if( !LibModSys_ChannelExists("MedievalFortressCore") ) {
		return Plugin_Handled;
	}
	
	CReplyToCommand(client, "printing gold of all clients");
	SharedMap shared_map = SharedMap("MedievalFortressCore");
	
	int currency[MAXPLAYERS+1];
	shared_map.GetArr("currency data", currency, sizeof(currency), IntType);
	for( int i=1; i<=MaxClients; i++ ) {
		if( !IsClientInGame(i) ) {
			continue;
		}
		PrintToServer("\t%N - gold: %i", i, currency[i]);
	}
	
	CReplyToCommand(client, "done printing gold of all clients");
	return Plugin_Handled;
}


public Action RoundStart(Event event, const char[] name, bool dontBroadcast) {
	if( !LibModSys_ChannelExists("MedievalFortressCore") ) {
		return Plugin_Continue;
	}
	SharedMap shared_map = SharedMap("MedievalFortressCore");
	
	int currency[MAXPLAYERS+1];
	shared_map.GetArr("currency data", currency, sizeof(currency), IntType);
	
	ConVar gold_set = FindConVar("medieval_fortress_gold_set");
	int gold_amount = gold_set.IntValue;
	for( int i; i < sizeof(currency); i++ ) {
		currency[i] = gold_amount;
	}
	
	shared_map.SetArr("currency data", currency, sizeof(currency), IntType);
	return Plugin_Continue;
}

public Action PlayerDeath(Event event, const char[] name, bool dontBroadcast) {
	if( !LibModSys_ChannelExists("MedievalFortressCore") ) {
		return Plugin_Continue;
	}
	SharedMap shared_map = SharedMap("MedievalFortressCore");
	
	int attacker  = event.GetInt("attacker");
	int assister  = event.GetInt("assister");
	int killer    = GetClientOfUserId(attacker);
	int helper    = GetClientOfUserId(assister);
	
	int currency[MAXPLAYERS+1];
	shared_map.GetArr("currency data", currency, sizeof(currency), IntType);
	
	ConVar gold_gain = FindConVar("medieval_fortress_gold_gain");
	int gain         = gold_gain.IntValue;
	int set_gain     = gain;
	bool changed;
	
	int num_fwd_tiers; shared_map.GetInt("fwd tiers", num_fwd_tiers);
	ManagerID[] priv_fwds_ids = new ManagerID[num_fwd_tiers];
	int fwd_tiers_len = shared_map.GetArr("currency fwds", priv_fwds_ids, num_fwd_tiers, EnumType);
	if( fwd_tiers_len==num_fwd_tiers ) {
		for( int i; i < num_fwd_tiers; i++ ) {
			PrivateFwd pf;
			if( !LibModSys_GetPrivateFwd(priv_fwds_ids[i], "OnGainGold", pf) || pf.pf.FunctionCount==0 ) {
				continue;
			}
			pf.Start();
			pf.PushCell(event);
			pf.PushCell(currency[killer]);
			pf.PushCellRef(gain);
			pf.PushCell(changed);
			pf.Finish();
			if( !changed && gain != set_gain ) {
				changed = true;
			}
		}
	}
	
	currency[killer] += gain;
	
	/// give assister some gold for their help.
	if( IsClientValid(helper) ) {
		currency[helper] += (gain >> 1);
	}
	
	shared_map.SetArr("currency data", currency, sizeof(currency), IntType);
	
	if( fwd_tiers_len==num_fwd_tiers ) {
		for( int i; i < num_fwd_tiers; i++ ) {
			PrivateFwd pf;
			if( !LibModSys_GetPrivateFwd(priv_fwds_ids[i], "OnGainGoldPost", pf) || pf.pf.FunctionCount==0 ) {
				continue;
			}
			
			pf.Start();
			pf.PushCell(event);
			pf.PushCell(currency[killer]);
			pf.PushCell(gain);
			pf.PushCell(changed);
			pf.Finish();
		}
	}
	return Plugin_Continue;
}

public void OnClientPutInServer(int client) {
	if( !LibModSys_ChannelExists("MedievalFortressCore") ) {
		return;
	}
	SharedMap shared_map = SharedMap("MedievalFortressCore");
	
	int currency[MAXPLAYERS+1];
	shared_map.GetArr("currency data", currency, sizeof(currency), IntType);
	
	ConVar gold_set = FindConVar("medieval_fortress_gold_set");
	currency[client] = gold_set.IntValue;
	shared_map.SetArr("currency data", currency, sizeof(currency), IntType);
}

/**
	HookEvent("player_death",               PlayerDeath, EventHookMode_Pre);
	HookEvent("player_hurt",                PlayerHurt, EventHookMode_Pre);
	HookEvent("teamplay_round_start",       RoundStart);
	HookEvent("teamplay_round_win",         RoundEnd);
	HookEvent("player_spawn",               ReSpawn);
	HookEvent("post_inventory_application", Resupply);
	HookEvent("object_deflected",           ObjectDeflected);
	HookEvent("object_destroyed",           ObjectDestroyed, EventHookMode_Pre);
	
	/// No longer functional.
	//HookEvent("player_jarated",             PlayerJarated);
	HookUserMessage(GetUserMessageId("PlayerJarated"), PlayerJarated);
	
	HookEvent("rocket_jump",                OnExplosiveJump);
	HookEvent("rocket_jump_landed",         OnExplosiveJump);
	HookEvent("sticky_jump",                OnExplosiveJump);
	HookEvent("sticky_jump_landed",         OnExplosiveJump);
	
	HookEvent("item_pickup",                ItemPickedUp);
	HookEvent("player_chargedeployed",      UberDeployed);
	HookEvent("arena_round_start",          ArenaRoundStart);
	HookEvent("teamplay_point_captured",    PointCapture, EventHookMode_Post);
	HookEvent("rps_taunt_event",            RPSTaunt, EventHookMode_Post);
	HookEvent("deploy_buff_banner",         DeployBuffBanner);
	HookEvent("player_buff",                OnPlayerBuff);
 */
