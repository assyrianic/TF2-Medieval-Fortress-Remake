#include <sourcemod>
#include <sdkhooks>
#include <tf2_stocks>
#include <morecolors>

#include <libmodsys>


#pragma semicolon    1
#pragma newdecls     required

#define PLUGIN_VERSION    "1.0.0"


public Plugin myinfo = {
	name        = "Medieval Fortress Force Jump Spell",
	author      = "Nergal",
	description = "Spell for Medieval Fortress",
	version     = PLUGIN_VERSION,
	url         = "zzzzzzzzzzzzz"
};


public void OnLibraryAdded(const char[] name) {
	if( StrEqual(name, "LibModSys") ) {
		PawnAwait(AwaitChannel, 0.25, {0}, 0);
	}
}

/// no need for this to be global, can just put it into a separate SharedMap for this module.
static int g_spell_id = -1;
static ConVar cfg_filepath;

public void OnPluginStart() {
	cfg_filepath = CreateConVar("medieval_fortress_force_jump_cfgfile", "configs/medieval_fortress/spell_cfgs/force_jump.cfg", "cfgfile path", FCVAR_NONE);
	AutoExecConfig(true, "MedievalFortress-ForceJump");
}

public bool AwaitChannel() {
	if( !LibModSys_ChannelExists("MedievalFortressSpellsCore") ) {
		return false;
	}
	
	SharedMap spell_map = SharedMap("MedievalFortressSpellsCore");
	ManagerID priv_fwds_id; spell_map.GetAny("spell fwd", priv_fwds_id, EnumType);
	LibModSys_PrivateFwdHook(priv_fwds_id, "OnCastSpell", OnCastSpell_ForceJump);
	
	char cfg_file[PLATFORM_MAX_PATH];
	cfg_filepath.GetString(cfg_file, sizeof(cfg_file));
	
	spell_map.ExecFunc("void RegisterSpell(const char[] cfg_filename, int &id)", "sI", _, cfg_file, g_spell_id);
	return true;
}

public Action OnCastSpell_ForceJump(int spellcaster_userid, int spell_id, const char[] spell_name, bool consumeable, float &cooldown, int &spell_exp, int &spell_level) {
	if( g_spell_id != spell_id ) {
		return Plugin_Continue;
	}
	
	/// sometimes a spell doesn't really need a valid client to have an effect
	/// but this spell affects the spellcaster so we need it valid.
	int client = GetClientOfUserId(spellcaster_userid);
	if( !IsClientValid(client) ) {
		return Plugin_Continue;
	}
	
	PrintToServer("Spell '%s' has been casted by %N", spell_name, client);
	
	float vel[3]; GetEntPropVector(client, Prop_Data, "m_vecVelocity", vel);
	float pos[3]; GetClientAbsOrigin(client, pos);
	float power = 5.0; /// cvar, initial height power.
	
	if( !(GetEntityFlags(client) & (FL_ONGROUND|FL_INWATER)) ) {
		float ray_angle[] = { 90.0, 0.0, 0.0 };
		TR_TraceRayFilter(pos, ray_angle, MASK_PLAYERSOLID_BRUSHONLY, RayType_Infinite, TraceRayIgnoreEnts);
		if( TR_DidHit() ) {
			float end_pos[3]; TR_GetEndPosition(end_pos);
			power *= (pos[2] - end_pos[2]);
		}
	}
	
	if( power > 50 ) {
		power = 50;
	}
	
	vel[2] = 750 + (power * 13.0);
	SetEntProp(client, Prop_Send, "m_bJumping", 1);
	
	//vel[0] *= (1+Sine(FLOAT_PI / 50));
	//vel[1] *= (1+Sine(FLOAT_PI / 50));
	TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, vel);
	
	cooldown += 7.0;
	
	/**
	 * would be cool to have some extra properties to it to make it more useful then for just the mg
	 * extinguishing afterburn, maybe applying different heights based on if youre airborn or not, ect ect
	 */
	return Plugin_Continue;
}
public bool TraceRayIgnoreEnts(int entity, int mask, any data) {
	return entity==0;
}