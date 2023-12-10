#include <sourcemod>
#include <sdkhooks>
#include <tf2_stocks>
#include <morecolors>
#include <libmodsys>
#include <ecs_helper>


#pragma semicolon    1
#pragma newdecls     required

#define PLUGIN_VERSION    "1.0.0"


public Plugin myinfo = {
	name        = "Medieval Fortress",
	author      = "Nergal",
	description = "RPG-ified Medieval Mode",
	version     = PLUGIN_VERSION,
	url         = "zzzzzzzzzzzzz"
};

/**
 * store for buyin weapons, ammo, and spells.
 * gold gained through gameplay.
 * levels to track progress.
 * spells for variety that unlock with currency + levels.
 * and mana that can only be regained by playing the game.
 * 
 * 
 * Store module     -> Framework-plugin
 * Inventory module -> Framework-plugin
 * Gold module      -> Component-plugin
 * Level module     -> Component-plugin
 * Spell module     -> Component-plugin
 * HUD module       -> System-Plugin [depends on Level & Gold components]
 * 
 * 
 * Component-plugins are plugins that implement and handle a specific functionality/data independently from other plugins.
 * 
 * Framework-plugins are plugins that are basically the skeleton of a set of behaviors/actions.
 * 
 * System-plugins are plugins that merge the data/functionality of component-plugins and the behavior of framework-plugins.
 * 
 * 
 * An example of this concept is the idea of a store plugin/mod.
 * 
 * You have Money & Item component-plugins, a Store framework-plugin, and a Menu system-plugin that connects the money & item component-plugins with the store framework-plugin.
 * 
 */
public void OnPluginStart() {
	//CreateConVar("medieval_fortress_fwd_tiers", "1", "Enables Medieval Fortress plugin", FCVAR_NONE, true, 0.0, true, 1.0);
	LoadTranslations("common.phrases");
	
	//RegConsoleCmd("sm_zzzz",  Cmd_ZZZZ);
	//RegAdminCmd  ("sm_zzzz",  Cmd_ZZZZ, ADMFLAG_GENERIC, "description here.");
}

public void OnLibraryAdded(const char[] name) {
	if( StrEqual(name, "LibModSys") ) {
		SharedMap shmap = SharedMap("MedievalFortressCore");
		
		/// add cvar?
		shmap.SetInt("fwd tiers", 2);
		//shmap.SetFunc("Action Cmd_ZZZZ(int client, int args)", Cmd_ZZZZ, 2);
		//shmap.SetFunc("int Test(int a, float& b)", Test, 2);
		//AutoExecConfig(true, "MedievalFortress-Main");
	}
}