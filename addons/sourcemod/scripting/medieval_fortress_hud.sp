#include <sourcemod>
#include <sdkhooks>

#include <tf2_stocks>
#include <morecolors>

#include <libmodsys>


#pragma semicolon    1
#pragma newdecls     required

#define PLUGIN_VERSION    "1.0.0"


public Plugin myinfo = {
	name        = "Medieval Fortress HUD Framework",
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
	
	Handle hud = CreateHudSynchronizer();
	shared_map.SetAny("HUD", hud, HandleType);
	
	/**
#if SOURCE_ENGINE == SE_CSGO || SOURCE_ENGINE == SE_BLADE || SOURCE_ENGINE == SE_MCV
	char message_buffer[512];
#else
	char message_buffer[255-36 == 219];
#endif
	 */
	//shared_map.SetInt("HUD text len", 219);
	//shared_map.Protect("HUD text len");
	
	//int num_fwd_tiers;
	//shared_map.GetInt("fwd tiers", num_fwd_tiers);
	
	//ManagerID[] priv_fwds_ids = new ManagerID[num_fwd_tiers];
	//for( int i; i < num_fwd_tiers; i++ ) {
	//	priv_fwds_ids[i] = LibModSys_MakePrivateFwdsManager("configs/medieval_fortress/hud.cfg");
	//}
	
	//shared_map.SetArr("hud fwds", priv_fwds_ids, num_fwd_tiers, EnumType);
	//shared_map.Protect("hud fwds");
	return true;
}

public void OnMapStart() {
	CreateTimer(0.15, TimerMedivalFortressHUD, _, TIMER_REPEAT);
}

enum{ MAX_HUD_LEN = 219 };
public Action TimerMedivalFortressHUD(Handle timer) {
	Action act = Plugin_Continue;
	if( !LibModSys_ChannelExists("MedievalFortressCore") ) {
		return act;
	}
	
	SharedMap shared_map = SharedMap("MedievalFortressCore");
	Handle hud; shared_map.GetAny("HUD", hud, HandleType);
	if( hud==null ) {
		return act;
	}
	
	char hud_text[MAXPLAYERS+1][MAX_HUD_LEN];
	
	bool has_currency = shared_map.Has("currency data");
	bool has_levels = shared_map.Has("level data") && shared_map.Has("exp data");
	bool has_mana = shared_map.Has("mana data");
	
	if( has_currency ) {
		int currency[MAXPLAYERS+1];
		shared_map.GetArr("currency data", currency, sizeof(currency), IntType);
		for( int i=1; i<=MaxClients; i++ ) {
			if( !IsClientInGame(i) ) {
				continue;
			}
			Format(hud_text[i], sizeof(hud_text[]), "Gold: %i", currency[i]);
		}
		
		if( has_levels || has_mana ) {
			for( int i=1; i<=MaxClients; i++ ) {
				if( !IsClientInGame(i) ) {
					continue;
				}
				Format(hud_text[i], sizeof(hud_text[]), "%s\n", hud_text[i]);
			}
		}
	}
	
	if( has_levels ) {
		int level[MAXPLAYERS+1], exp[MAXPLAYERS+1];
		shared_map.GetArr("level data", level, sizeof(level), IntType);
		shared_map.GetArr("exp data", exp, sizeof(exp), IntType);
		
		int exp_table_len = shared_map.GetArrLen("exp table");
		int[] exp_table = new int[exp_table_len];
		shared_map.GetArr("exp table", exp_table, exp_table_len, IntType);
		
		for( int i=1; i<=MaxClients; i++ ) {
			if( !IsClientInGame(i) ) {
				continue;
			}
			
			if( level[i] >= exp_table_len ) {
				Format(hud_text[i], sizeof(hud_text[]), "Max Level Reached", hud_text[i]);
			} else {
				Format(hud_text[i], sizeof(hud_text[]), "%sLevel: %i | Exp: %i/%i", hud_text[i], level[i], exp[i], exp_table[level[i]]);
			}
		}
		
		if( has_mana ) {
			for( int i=1; i<=MaxClients; i++ ) {
				if( !IsClientInGame(i) ) {
					continue;
				}
				Format(hud_text[i], sizeof(hud_text[]), "%s\n", hud_text[i]);
			}
		}
	}
	
	if( has_mana ) {
		int mana[MAXPLAYERS+1];
		shared_map.GetArr("mana data", mana, sizeof(mana), IntType);
		
		ConVar mana_divider = FindConVar("medieval_fortress_mana_div");
		ConVar mana_cutoff  = FindConVar("medieval_fortress_mana_cutoff");
		int div_amnt        = mana_divider.IntValue;
		int div_cutoff      = mana_cutoff.IntValue;
		if( div_amnt > div_cutoff ) {
			div_amnt = div_cutoff;
		}
		
		int bars[MAXPLAYERS+1], extra[MAXPLAYERS+1];
		char[][] mana_bar = new char[MAXPLAYERS+1][div_cutoff + 10];
		for( int i=1; i<=MaxClients; i++ ) {
			if( !IsClientInGame(i) ) {
				continue;
			}
			
			/// [#####|#####|] - 10 mana
			/// [#####|#####|#####|#####|+10] - 30 mana with 20 mana cutoff
			/// [#####|##___|] - 10 mana, 3 used. 7 left.
			bars[i]  = mana[i] / div_amnt;
			extra[i] = mana[i] % div_amnt;
			
			int num_hashes = ( mana[i] > div_cutoff )? div_cutoff / div_amnt : bars[i];
			for( int j; j < num_hashes; j++ ) {
				for( int n; n < div_amnt; n++ ) {
					Format(mana_bar[i], sizeof(hud_text[]), "%s#", mana_bar[i]);
				}
				Format(mana_bar[i], sizeof(hud_text[]), "%s|", mana_bar[i]);
			}
			
			if( mana[i] > div_cutoff ) {
				Format(mana_bar[i], sizeof(hud_text[]), "%s+%i", mana_bar[i], mana[i]-div_cutoff);
			} else {
				for( int j; j < extra[i]; j++ ) {
					Format(mana_bar[i], sizeof(hud_text[]), "%s#", mana_bar[i]);
				}
				if( extra[i] > 0 ) {
					for( int n; n < div_amnt - extra[i]; n++ ) {
						Format(mana_bar[i], sizeof(hud_text[]), "%s_", mana_bar[i]);
					}
				}
			}
		}
		
		for( int i=1; i<=MaxClients; i++ ) {
			if( !IsClientInGame(i) ) {
				continue;
			}
			Format(hud_text[i], sizeof(hud_text[]), "%sMana: [%s]", hud_text[i], mana_bar[i]);
		}
	}
	
	enum {
		SPELL_LEVEL      = (1 << 16),
		SPELL_EXP        = (1 << 17),
		//SPELL_EXP_TO_LVL = (1 << 18),
	};
	if( LibModSys_ChannelExists("MedievalFortressSpellsCore") ) {
		SharedMap spell_map = SharedMap("MedievalFortressSpellsCore");
		
		int consumable_id[MAXPLAYERS+1];
		int consumable_ammo[MAXPLAYERS+1];
		ForwardTime consumable_id_cooldown[MAXPLAYERS+1];
		
		int reusable_id[MAXPLAYERS+1];
		ForwardTime reusable_id_cooldown[MAXPLAYERS+1];
		
		spell_map.GetArr("consumable spell slot id", consumable_id, sizeof(consumable_id), IntType);
		spell_map.GetArr("consumable spell slot id ammo", consumable_ammo, sizeof(consumable_ammo), IntType);
		spell_map.GetArr("consumable spell slot id cooldown", consumable_id_cooldown, sizeof(consumable_id_cooldown));
		
		spell_map.GetArr("reusable spell slot id", reusable_id, sizeof(reusable_id), IntType);
		spell_map.GetArr("reusable spell slot id cooldown", reusable_id_cooldown, sizeof(reusable_id_cooldown));
		
		for( int i=1; i<=MaxClients; i++ ) {
			if( !IsClientInGame(i) ) {
				continue;
			}
			ConfigMap cfg = null; spell_map.IntGetAny(reusable_id[i], cfg, MethodMapType);
			if( cfg != null ) {
				char spell_name[64];
				cfg.Get("spell.name", spell_name, sizeof(spell_name));
				
				int spell_level[MAXPLAYERS+1];
				spell_map.IntGetArr(reusable_id[i] | SPELL_LEVEL, spell_level, sizeof(spell_level), IntType);
				int spell_exp[MAXPLAYERS+1];
				spell_map.IntGetArr(reusable_id[i] | SPELL_EXP, spell_exp, sizeof(spell_exp), IntType);
				float elapsed = reusable_id_cooldown[i].Elapsed();
				if( elapsed > 0 ) {
					Format(hud_text[i], sizeof(hud_text[]), "%s\n[Reusable: %s (level: %i | exp: %i)] - Ready in %0.1f", hud_text[i], spell_name, spell_level[i], spell_exp[i], elapsed);
				} else {
					Format(hud_text[i], sizeof(hud_text[]), "%s\n[Reusable: %s (level: %i | exp: %i)] - READY", hud_text[i], spell_name, spell_level[i], spell_exp[i]);
				}
			} else {
				Format(hud_text[i], sizeof(hud_text[]), "%s\n[No Reusable Spell]", hud_text[i]);
			}
		}
		
		for( int i=1; i<=MaxClients; i++ ) {
			if( !IsClientInGame(i) ) {
				continue;
			}
			ConfigMap cfg = null; spell_map.IntGetAny(consumable_id[i], cfg, MethodMapType);
			if( cfg != null ) {
				char spell_name[64];
				cfg.Get("spell.name", spell_name, sizeof(spell_name));
				
				int spell_level[MAXPLAYERS+1];
				spell_map.IntGetArr(reusable_id[i] | SPELL_LEVEL, spell_level, sizeof(spell_level), IntType);
				int spell_exp[MAXPLAYERS+1];
				spell_map.IntGetArr(reusable_id[i] | SPELL_EXP, spell_exp, sizeof(spell_exp), IntType);
				float elapsed = consumable_id_cooldown[i].Elapsed();
				if( elapsed > 0.0 ) {
					Format(hud_text[i], sizeof(hud_text[]), "%s\n[Consumable: %s - amount: %i  (level: %i | exp: %i)] - Ready in %0.1f", hud_text[i], spell_name, consumable_ammo[i], spell_level[i], spell_exp[i], elapsed);
				} else {
					Format(hud_text[i], sizeof(hud_text[]), "%s\n[Consumable: %s - amount: %i  (level: %i | exp: %i)] - READY", hud_text[i], spell_name, consumable_ammo[i], spell_level[i], spell_exp[i]);
				}
			} else {
				Format(hud_text[i], sizeof(hud_text[]), "%s\n[No Consumable Spell]", hud_text[i]);
			}
		}
	}
	
	SetHudTextParams(-1.0, 0.72, 0.35, 255, 0, 255, 255);
	for( int i=1; i<=MaxClients; i++ ) {
		if( !IsClientInGame(i) ) {
			continue;
		}
		int hud_len = strlen(hud_text[i]);
		ShowSyncHudText(i, hud, "%s | %i/%i", hud_text[i], hud_len, MAX_HUD_LEN);
	}
	return act;
}