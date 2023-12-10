#include <sourcemod>
#include <sdkhooks>
#include <tf2_stocks>
#include <morecolors>
#include <libmodsys>


#pragma semicolon    1
#pragma newdecls     required

#define PLUGIN_VERSION    "1.0.0"


public Plugin myinfo = {
	name        = "Medieval Fortress Template Module",
	author      = "Nergal",
	description = "RPG-ified Medieval Mode",
	version     = PLUGIN_VERSION,
	url         = "zzzzzzzzzzzzz"
};


enum {
	SPELL_LEVEL      = (1 << 16),
	SPELL_EXP        = (1 << 17),
	//SPELL_EXP_TO_LVL = (1 << 18),
};

public void OnLibraryAdded(const char[] name) {
	if( StrEqual(name, "LibModSys") ) {
		PawnAwait(AwaitChannel, 0.25, {0}, 0);
	}
}

public bool AwaitChannel() {
	if( !LibModSys_ChannelExists("MedievalFortressSpellsCore") ) {
		return false;
	}
	
	SharedMap spell_map = SharedMap("MedievalFortressSpellsCore");
	
	int consumable_id[MAXPLAYERS+1];
	int consumable_ammo[MAXPLAYERS+1];
	ForwardTime consumable_id_last_use[MAXPLAYERS+1];
	
	spell_map.SetArr("consumable spell slot id", consumable_id, sizeof(consumable_id), IntType);
	spell_map.SetArr("consumable spell slot id ammo", consumable_ammo, sizeof(consumable_ammo), IntType);
	spell_map.SetArr("consumable spell slot id last use", consumable_id_last_use, sizeof(consumable_id_last_use));
	
	int reusable_id[MAXPLAYERS+1];
	ForwardTime reusable_id_last_use[MAXPLAYERS+1];
	spell_map.SetArr("reusable spell slot id", reusable_id, sizeof(reusable_id), IntType);
	spell_map.SetArr("reusable spell slot id last use", reusable_id_last_use, sizeof(reusable_id_last_use));
	
	RegAdminCmd("sm_give_spell", Cmd_GiveSpell, ADMFLAG_GENERIC, "gives a spell to players.");
	RegAdminCmd("sm_give_spell_ammo", Cmd_GiveSpellAmmo, ADMFLAG_GENERIC, "gives spell ammo to players.");
	
	return true;
}

public Action Cmd_GiveSpell(int client, int args) {
	if( !LibModSys_ChannelExists("MedievalFortressSpellsCore") ) {
		return Plugin_Handled;
	}
	
	char targetname[32];   GetCmdArg(1, targetname,   sizeof(targetname));
	char spell_id_str[32]; GetCmdArg(2, spell_id_str, sizeof(spell_id_str));
	int required_spell_id = StringToInt(spell_id_str);
	
	SharedMap spell_map = SharedMap("MedievalFortressSpellsCore");
	ConfigMap cfg; spell_map.IntGetAny(required_spell_id, cfg, MethodMapType);
	if( cfg==null ) {
		CReplyToCommand(client, "invalid spell id: '%i'", required_spell_id);
		return Plugin_Handled;
	}
	
	char target_name[MAX_TARGET_LENGTH];
	int target_list[MAXPLAYERS];
	bool tn_is_ml;
	int target_count = ProcessTargetString(targetname, client, target_list, MAXPLAYERS, 0, target_name, sizeof(target_name), tn_is_ml);
	if( target_count <= 0 ) {
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}
	
	int ammo; cfg.GetInt("spell.ammo", ammo);
	
	int spell_slot_id[MAXPLAYERS+1];
	spell_map.GetArr(ammo < 0? "reusable spell slot id" : "consumable spell slot id", spell_slot_id, sizeof(spell_slot_id), IntType);
	
	for( int i=0; i < target_count; i++ ) {
		if( !IsClientInGame(target_list[i]) ) {
			continue;
		}
		spell_slot_id[target_list[i]] = required_spell_id;
	}
	spell_map.SetArr(ammo < 0? "reusable spell slot id" : "consumable spell slot id", spell_slot_id, sizeof(spell_slot_id), IntType);
	
	int len = cfg.GetSize("spell.name");
	char[] spell_name = new char[len + 1];
	cfg.Get("spell.name", spell_name, len);
	CReplyToCommand(client, "gave spell '%s'", spell_name);
	return Plugin_Handled;
}

public Action Cmd_GiveSpellAmmo(int client, int args) {
	if( !LibModSys_ChannelExists("MedievalFortressSpellsCore") ) {
		return Plugin_Handled;
	}
	
	char targetname[32]; GetCmdArg(1, targetname, sizeof(targetname));
	char ammo_str[32];   GetCmdArg(2, ammo_str,   sizeof(ammo_str));
	int ammo_given = StringToInt(ammo_str);
	
	SharedMap spell_map = SharedMap("MedievalFortressSpellsCore");
	char target_name[MAX_TARGET_LENGTH];
	int target_list[MAXPLAYERS];
	bool tn_is_ml;
	int target_count = ProcessTargetString(targetname, client, target_list, MAXPLAYERS, 0, target_name, sizeof(target_name), tn_is_ml);
	if( target_count <= 0 ) {
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}
	
	int ammo[MAXPLAYERS+1];
	spell_map.GetArr("consumable spell slot id ammo", ammo, sizeof(ammo), IntType);
	
	for( int i=0; i < target_count; i++ ) {
		if( !IsClientInGame(target_list[i]) ) {
			continue;
		}
		ammo[target_list[i]] = ammo_given;
	}
	spell_map.SetArr("consumable spell slot id ammo", ammo, sizeof(ammo), IntType);
	CReplyToCommand(client, "gave spell ammo");
	return Plugin_Handled;
}


public void OnClientPutInServer(int client) {
	if( !LibModSys_ChannelExists("MedievalFortressSpellsCore") ) {
		return;
	}
	
	SharedMap spell_map = SharedMap("MedievalFortressSpellsCore");
	
	int consumable_id[MAXPLAYERS+1];
	int consumable_ammo[MAXPLAYERS+1];
	ForwardTime consumable_id_last_use[MAXPLAYERS+1];
	
	spell_map.GetArr("consumable spell slot id", consumable_id, sizeof(consumable_id), IntType);
	spell_map.GetArr("consumable spell slot id ammo", consumable_ammo, sizeof(consumable_ammo), IntType);
	spell_map.GetArr("consumable spell slot id last use", consumable_id_last_use, sizeof(consumable_id_last_use));
	
	
	int reusable_id[MAXPLAYERS+1];
	ForwardTime reusable_id_last_use[MAXPLAYERS+1];
	
	spell_map.GetArr("reusable spell slot id", reusable_id, sizeof(reusable_id), IntType);
	spell_map.GetArr("reusable spell slot id last use", reusable_id_last_use, sizeof(reusable_id_last_use));
	
	consumable_id[client] = -1;
	consumable_ammo[client] = 0;
	consumable_id_last_use[client] = ForwardTime(0.0);
	
	reusable_id[client] = -1;
	reusable_id_last_use[client] = ForwardTime(0.0);
	
	int max_spells; spell_map.GetInt("spells registered", max_spells);
	for( int i; i < max_spells; i++ ) {
		int spell_levels[MAXPLAYERS+1];
		spell_map.IntGetArr(i | SPELL_LEVEL, spell_levels, sizeof(spell_levels), IntType);
		spell_levels[client] = 1;
		spell_map.IntSetArr(i | SPELL_LEVEL, spell_levels, sizeof(spell_levels), IntType);
		
		int spell_exp[MAXPLAYERS+1];
		spell_map.IntGetArr(i | SPELL_EXP, spell_exp, sizeof(spell_exp), IntType);
		spell_exp[client] = 0;
		spell_map.IntSetArr(i | SPELL_EXP, spell_exp, sizeof(spell_exp), IntType);
	}
	
	spell_map.SetArr("consumable spell slot id", consumable_id, sizeof(consumable_id), IntType);
	spell_map.SetArr("consumable spell slot id ammo", consumable_ammo, sizeof(consumable_ammo), IntType);
	spell_map.SetArr("consumable spell slot id last use", consumable_id_last_use, sizeof(consumable_id_last_use));
	spell_map.SetArr("reusable spell slot id", reusable_id, sizeof(reusable_id), IntType);
	spell_map.SetArr("reusable spell slot id last use", reusable_id_last_use, sizeof(reusable_id_last_use));
}

public void OnMapStart() {
	CreateTimer(0.1, RunSpellThink, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
}

public Action RunSpellThink(Handle timer) {
	if( !LibModSys_ChannelExists("MedievalFortressSpellsCore") ) {
		return Plugin_Continue;
	}
	
	SharedMap spell_map = SharedMap("MedievalFortressSpellsCore");
	SharedMap core_map  = SharedMap("MedievalFortressCore");
	
	int consumable_id[MAXPLAYERS+1];
	int consumable_ammo[MAXPLAYERS+1];
	ForwardTime consumable_id_last_use[MAXPLAYERS+1];
	
	spell_map.GetArr("consumable spell slot id", consumable_id, sizeof(consumable_id), IntType);
	spell_map.GetArr("consumable spell slot id ammo", consumable_ammo, sizeof(consumable_ammo), IntType);
	spell_map.GetArr("consumable spell slot id last use", consumable_id_last_use, sizeof(consumable_id_last_use));
	
	
	int reusable_id[MAXPLAYERS+1];
	ForwardTime reusable_id_last_use[MAXPLAYERS+1];
	
	spell_map.GetArr("reusable spell slot id", reusable_id, sizeof(reusable_id), IntType);
	spell_map.GetArr("reusable spell slot id last use", reusable_id_last_use, sizeof(reusable_id_last_use));
	
	ManagerID priv_fwds_id; spell_map.GetAny("spell fwd", priv_fwds_id, EnumType);
	
	PrivateFwd pf;
	/// void(int spellcaster_userid, int spell_id, const char[] spell_name, bool consumeable, int &ammo, float &last use);
	if( !LibModSys_GetPrivateFwd(priv_fwds_id, "OnCastSpell", pf) || pf.pf.FunctionCount==0 ) {
		return Plugin_Continue;
	}
	
	for( int i=1; i<=MaxClients; i++ ) {
		if( !IsClientValid(i) || !IsPlayerAlive(i) ) {
			continue;
		}
		
		int userid = GetClientUserId(i);
		int buttons = GetClientButtons(i);
		
		/// +alt1 IN_ALT1 for reusable   spells.
		/// +alt2 IN_ALT2 for consumable spells.
		
		/// cast reuseable spells.
		if( (buttons & IN_ALT1) && reusable_id[i] > -1 && !reusable_id_last_use[i].WithinTime() ) {
			ConfigMap cfg; spell_map.IntGetAny(reusable_id[i], cfg, MethodMapType);
			
			if( cfg==null ) {
				continue;
			}
			
			if( core_map.Has("mana data") ) {
				int mana[MAXPLAYERS+1]; core_map.GetArr("mana data", mana, sizeof(mana), IntType);
				int cost; cfg.GetInt("spell.mana cost", cost);
				if( mana[i] < cost ) {
					continue;
				}
				mana[i] -= cost;
				core_map.SetArr("mana data", mana, sizeof(mana), IntType);
			}
			
			int spell_level[MAXPLAYERS+1];
			spell_map.IntGetArr(reusable_id[i] | SPELL_LEVEL, spell_level, sizeof(spell_level), IntType);
			
			int spell_exp[MAXPLAYERS+1];
			spell_map.IntGetArr(reusable_id[i] | SPELL_EXP, spell_exp, sizeof(spell_exp), IntType);
			
			pf.Start();
			pf.PushCell(userid);
			pf.PushCell(reusable_id[i]);
			
			int spell_name_len = spell_map.IntGetStrLen(reusable_id[i]);
			char[] spell_name = new char[spell_name_len + 1];
			spell_map.IntGetStr(reusable_id[i], spell_name, spell_name_len);
			
			pf.PushString(spell_name, spell_name_len, _, false);
			pf.PushCell(false);
			
			float cooldown; cfg.GetFloat("spell.cooldown", cooldown);
			pf.PushFloatRef(cooldown);
			pf.PushCellRef(spell_exp[i]);
			pf.PushCellRef(spell_level[i]);
			pf.Finish();
			reusable_id_last_use[i] = ForwardTime.Update(cooldown);
			
			spell_map.IntSetArr(reusable_id[i] | SPELL_EXP, spell_exp, sizeof(spell_exp), IntType);
			spell_map.IntSetArr(reusable_id[i] | SPELL_LEVEL, spell_level, sizeof(spell_level), IntType);
		}
		
		/// cast consumeable spells.
		if( (buttons & IN_ALT2) && consumable_id[i] > -1 && consumable_ammo[i] > 0 && !consumable_id_last_use[i].WithinTime() ) {
			ConfigMap cfg; spell_map.IntGetAny(consumable_id[i], cfg, MethodMapType);
			if( cfg==null ) {
				continue;
			}
			
			if( core_map.Has("mana data") ) {
				int mana[MAXPLAYERS+1]; core_map.GetArr("mana data", mana, sizeof(mana), IntType);
				int cost; cfg.GetInt("spell.mana cost", cost);
				if( mana[i] < cost ) {
					continue;
				}
				mana[i] -= cost;
				core_map.SetArr("mana data", mana, sizeof(mana), IntType);
			}
			
			int spell_level[MAXPLAYERS+1];
			spell_map.IntGetArr(consumable_id[i] | SPELL_LEVEL, spell_level, sizeof(spell_level), IntType);
			
			int spell_exp[MAXPLAYERS+1];
			spell_map.IntGetArr(consumable_id[i] | SPELL_EXP, spell_exp, sizeof(spell_exp), IntType);
			
			pf.Start();
			pf.PushCell(userid);
			pf.PushCell(consumable_id[i]);
			
			int spell_name_len = spell_map.IntGetStrLen(consumable_id[i]);
			char[] spell_name = new char[spell_name_len + 1];
			spell_map.IntGetStr(consumable_id[i], spell_name, spell_name_len);
			
			pf.PushString(spell_name, spell_name_len, _, false);
			pf.PushCell(true);
			
			float cooldown; cfg.GetFloat("spell.cooldown", cooldown);
			pf.PushFloatRef(cooldown);
			pf.PushCellRef(spell_exp[i]);
			pf.PushCellRef(spell_level[i]);
			pf.Finish();
			consumable_id_last_use[i] = ForwardTime.Update(cooldown);
			consumable_ammo[i]--;
			spell_map.IntSetArr(consumable_ammo[i] | SPELL_EXP, spell_exp, sizeof(spell_exp), IntType);
			spell_map.IntSetArr(consumable_ammo[i] | SPELL_LEVEL, spell_level, sizeof(spell_level), IntType);
		}
	}
	
	spell_map.SetArr("consumable spell slot id ammo", consumable_ammo, sizeof(consumable_ammo), IntType);
	spell_map.SetArr("consumable spell slot id last use", consumable_id_last_use, sizeof(consumable_id_last_use));
	spell_map.SetArr("reusable spell slot id last use", reusable_id_last_use, sizeof(reusable_id_last_use));
	
	return Plugin_Continue;
}