#include <sourcemod>
#include <sdkhooks>

#include <tf2_stocks>
#include <morecolors>

#include <libmodsys>


#pragma semicolon    1
#pragma newdecls     required

#define PLUGIN_VERSION    "1.0.0"


public Plugin myinfo = {
	name        = "Medieval Fortress Level Module",
	author      = "Nergal",
	description = "RPG-ified Medieval Mode",
	version     = PLUGIN_VERSION,
	url         = "zzzzzzzzzzzzz"
};

/**
unsigned CalcExpCeiling(unsigned level) {
	return floor(level + (325.0 * pow(2.0, level/25.0)));
}
 */

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
	int exp_table[] = {
		0,
		335,  /// exp needed to get from lvl 1 to lvl 2.
		680,  /// exp needed to get from lvl 2 to lvl 3.
		1036, /// etc.
		1403,
		1781,
		2170,
		2571,
		2984,
		3410,
		3848,
		4299,
		4764,
		5243,
		5736,
		6243,
		6765,
		7302,
		7855,
		8424,
		9009,
		9611,
		10231,
		10868,
		11524,
		12199,
		12893,
		13607,
		14341,
		15096,
		15872,
		16670,
		17491,
		18335,
		19203,
		20095,
		21012,
		21955,
		22925,
		23922,
		24947,
		26000,
		27083,
		28196,
		29340,
		30516,
		31725,
		32968,
		34245,
		35558,
		36908,
		38295,
		39721,
		41186,
		42692,
		44240,
		45831,
		47466,
		49146,
		50873,
		52648,
		54472,
		56347,
		58274,
		60254,
		62289,
		64380,
		66529,
		68738,
		71008,
		73341,
		75739,
		78203,
		80735,
		83337,
		86012,
		88761,
		91586,
		94489,
		97472,
		100538,
		103689,
		106927,
		110255,
		113675,
		117190,
		120803,
		124516,
		128332,
		132254,
		136284,
		140426,
		144683,
		149058,
		153555,
		158176,
		162926,
		167807,
		172824,
		177980,
	};
	shared_map.SetArr("exp table", exp_table, sizeof(exp_table), IntType);
	
	int empty_level[MAXPLAYERS+1];
	shared_map.SetArr("level data", empty_level, sizeof(empty_level), IntType);
	shared_map.Unfreeze("level data");
	
	int empty_exp[MAXPLAYERS+1];
	shared_map.SetArr("exp data", empty_exp, sizeof(empty_exp), IntType);
	shared_map.Unfreeze("exp data");
	
	int num_fwd_tiers;
	shared_map.GetInt("fwd tiers", num_fwd_tiers);
	
	ManagerID[] priv_fwds_ids = new ManagerID[num_fwd_tiers];
	for( int i; i < num_fwd_tiers; i++ ) {
		priv_fwds_ids[i] = LibModSys_MakePrivateFwdsManager("configs/medieval_fortress/levels.cfg");
	}
	
	shared_map.SetArr("level fwds", priv_fwds_ids, num_fwd_tiers, EnumType);
	
	shared_map.SetFunc("int CalcExpCeiling(int level, float base_num, float multiplier, float lvl_divider)", CalcExpCeiling, 4);
	shared_map.SetFunc("void UpdateLevel(int &level, int curr_exp, const int[] exp_table, int exp_table_len)", UpdateLevel, 4);
	shared_map.SetFunc("void CalcExpCeilings(int[] exp_table, int exp_table_len, float base_num, float multiplier, float lvl_divider)", CalcExpCeilings, 5);
	
	CreateConVar("medieval_fortress_exp_mult", "1", "How much exp is multiplied when doing an action. 0 to disable", FCVAR_NONE, true, 0.0);
	
	AutoExecConfig(true, "MedievalFortress-Levels");
	HookEvent("player_hurt", PlayerHurt);
	return true;
}

public void UpdateLevel(int &level, int curr_exp, const int[] exp_table, int exp_table_len) {
	while( level < exp_table_len && curr_exp >= exp_table[level] ) {
		level++;
	}
}
public int CalcExpCeiling(int level, float base_num, float multiplier, float lvl_divider) {
	return RoundToFloor(level + (multiplier * Pow(base_num, level/lvl_divider)));
}
public void CalcExpCeilings(int[] exp_table, int exp_table_len, float base_num, float multiplier, float lvl_divider) {
	for( int i; i < exp_table_len; i++ ) {
		exp_table[i] = CalcExpCeiling(i, base_num, multiplier, lvl_divider);
	}
}


public Action Cmd_PrintExp(int client, int args) {
	if( !LibModSys_ChannelExists("MedievalFortressCore") ) {
		return Plugin_Handled;
	}
	
	CReplyToCommand(client, "printing exp of all clients");
	SharedMap shared_map = SharedMap("MedievalFortressCore");
	
	int exp[MAXPLAYERS+1];
	shared_map.GetArr("exp data", exp, sizeof(exp), IntType);
	int level[MAXPLAYERS+1];
	shared_map.GetArr("level data", level, sizeof(level), IntType);
	
	int exp_table_len = shared_map.GetArrLen("exp table");
	int[] exp_table = new int[exp_table_len];
	shared_map.GetArr("exp table", exp_table, exp_table_len, IntType);
	
	for( int i=1; i<=MaxClients; i++ ) {
		if( !IsClientInGame(i) ) {
			continue;
		}
		int lvl = level[i];
		PrintToServer("\t%N - level: %i | exp: %i / %i", i, lvl, exp[i], exp_table[lvl]);
	}
	
	CReplyToCommand(client, "done printing exp of all clients");
	return Plugin_Handled;
}

public Action PlayerHurt(Event event, const char[] name, bool dontBroadcast) {
	if( !LibModSys_ChannelExists("MedievalFortressCore") ) {
		return Plugin_Continue;
	}
	SharedMap shared_map = SharedMap("MedievalFortressCore");
	int attacker = event.GetInt("attacker");
	int hitter   = GetClientOfUserId(attacker);
	int damage   = event.GetInt("damageamount");
	
	int exp[MAXPLAYERS+1];
	shared_map.GetArr("exp data", exp, sizeof(exp), IntType);
	shared_map.Unfreeze("exp data");
	
	int num_fwd_tiers;
	shared_map.GetInt("fwd tiers", num_fwd_tiers);
	
	ConVar exp_mult = FindConVar("medieval_fortress_exp_mult");
	int mult        = exp_mult.IntValue;
	int set_mult    = mult;
	bool changed;
	
	ManagerID[] priv_fwds_ids = new ManagerID[num_fwd_tiers];
	int fwd_tiers_len = shared_map.GetArr("level fwds", priv_fwds_ids, num_fwd_tiers, EnumType);
	if( fwd_tiers_len==num_fwd_tiers ) {
		for( int i; i < num_fwd_tiers; i++ ) {
			PrivateFwd pf;
			if( !LibModSys_GetPrivateFwd(priv_fwds_ids[i], "OnGainExp", pf) || pf.pf.FunctionCount==0 ) {
				continue;
			}
			
			pf.Start();
			pf.PushCell(event);
			pf.PushCell(exp[hitter]);
			pf.PushCellRef(mult);
			pf.PushCell(changed);
			pf.Finish();
			if( !changed && mult != set_mult ) {
				changed = true;
			}
		}
	}
	
	exp[hitter] += mult * damage;
	
	shared_map.SetArr("exp data", exp, sizeof(exp), IntType);
	if( fwd_tiers_len==num_fwd_tiers ) {
		for( int i; i < num_fwd_tiers; i++ ) {
			PrivateFwd pf;
			if( !LibModSys_GetPrivateFwd(priv_fwds_ids[i], "OnGainExpPost", pf) || pf.pf.FunctionCount==0 ) {
				continue;
			}
			
			pf.Start();
			pf.PushCell(event);
			pf.PushCell(exp[hitter]);
			pf.PushCell(mult);
			pf.PushCell(changed);
			pf.Finish();
		}
	}
	
	int level[MAXPLAYERS+1];
	shared_map.GetArr("level data", level, sizeof(level), IntType);
	
	int exp_table_len = shared_map.GetArrLen("exp table");
	int[] exp_table = new int[exp_table_len];
	shared_map.GetArr("exp table", exp_table, exp_table_len, IntType);
	
	for( int i=1; i<=MaxClients; i++ ) {
		if( !IsClientInGame(i) ) {
			continue;
		}
		UpdateLevel(level[i], exp[i], exp_table, exp_table_len);
	}
	shared_map.SetArr("level data", level, sizeof(level), IntType);
	return Plugin_Continue;
}

public void OnMapStart() {
	
}

public void OnClientPutInServer(int client) {
	if( !LibModSys_ChannelExists("MedievalFortressCore") ) {
		return;
	}
	
	SharedMap shared_map = SharedMap("MedievalFortressCore");
	
	int level[MAXPLAYERS+1];
	shared_map.GetArr("level data", level, sizeof(level), IntType);
	
	int level_sum, levels;
	for( int i=1; i<=MaxClients; i++ ) {
		if( !IsClientInGame(i) ) {
			continue;
		}
		
		level_sum += level[i];
		levels++;
	}
	
	level[client] = level_sum / levels;
	shared_map.SetArr("level data", level, sizeof(level), IntType);
	
	int exp_table_len = shared_map.GetArrLen("exp table");
	int[] exp_table = new int[exp_table_len];
	shared_map.GetArr("exp table", exp_table, exp_table_len, IntType);
	
	int exp[MAXPLAYERS+1];
	shared_map.GetArr("exp data", exp, sizeof(exp), IntType);
	
	exp[client] = exp_table[level[client]];
	shared_map.SetArr("exp data", exp, sizeof(exp), IntType);
}