#include <sourcemod>
#include <sdkhooks>
#include <tf2_stocks>
#include <morecolors>

#include <libmodsys>


#pragma semicolon    1
#pragma newdecls     required

#define PLUGIN_VERSION    "1.0.0"


public Plugin myinfo = {
	name        = "Medieval Fortress Spells Module",
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
	
	/// create dependency channel for core.
	/// spell maps uses integer IDs as the spell ids.
	/// see `RegisterSpell` for more.
	SharedMap spell_map = SharedMap("MedievalFortressSpellsCore");
	spell_map.SetInt("spells registered", 0);
	
	spell_map.SetFunc("void KillSpell(int spell_ref)", KillSpell, 1);
	spell_map.SetFunc("void GiveSpellBeamTrail(int spell_ref, const char[] model, const int color[4])", GiveSpellBeamTrail, 3);
	spell_map.SetFunc("int MakeSpellProj(int player, const char[] model, const char[] id_name, float gravity, float z_axis_arc, float throw_speed)", MakeSpellProj, 6);
	spell_map.SetFunc("void AttachParticle(int entref, const char[] particleType, float killtime, float offset=0.0)", AttachParticle, 4);
	spell_map.SetFunc("bool IsInRange(int entity, int target, float dist, bool trace=false)", IsInRange, 4);
	spell_map.SetFunc("int GetPlayersInRange(int entity, int targets[], float dist, bool trace=false)", GetPlayersInRange, 4);
	spell_map.SetFunc("void RegisterSpell(const char[] cfg_filename, int &id)", RegisterSpell, 2);
	spell_map.SetFunc("void PlaySpellSound(int client, const char[] snd, bool once, bool to_all)", PlaySpellSound, 4);
	
	ManagerID priv_fwds_id = LibModSys_MakePrivateFwdsManager("configs/medieval_fortress/spells.cfg");
	spell_map.SetAny("spell fwd", priv_fwds_id, EnumType);
	return true;
}


enum {
	MAX_SPELLS       = 0xffff,
	SPELL_LEVEL      = (1 << 16),
	SPELL_EXP        = (1 << 17),
	//SPELL_EXP_TO_LVL = (1 << 18),
};
public void RegisterSpell(const char[] cfg_file, int &id) {
	SharedMap spell_map = SharedMap("MedievalFortressSpellsCore");
	int i; spell_map.GetInt("spells registered", i);
	if( i >= MAX_SPELLS ) {
		return;
	}
	/// check if it exists.
	{
		int x = -1; spell_map.GetInt(cfg_file, x);
		if( x != -1 ) {
			//PrintToServer("RegisterSpell :: found preregistered spell '%s' to id: '%i'", cfg_file, x);
			id = x;
			return;
		}
	}
	
	ConfigMap cfg = new ConfigMap(cfg_file);
	if( cfg==null ) {
		return;
	}
	//LogMessage("RegisterSpell :: cfg == '%i'", cfg);
	//PrintCfg(cfg);
	spell_map.SetInt(cfg_file, i);
	spell_map.IntSetAny(i, cfg, MethodMapType);
	
	int spell_level[MAXPLAYERS+1];
	spell_map.IntSetArr(i | SPELL_LEVEL, spell_level, sizeof(spell_level), IntType);
	
	int spell_exp[MAXPLAYERS+1];
	spell_map.IntSetArr(i | SPELL_EXP, spell_exp, sizeof(spell_exp), IntType);
	
	spell_map.SetInt("spells registered", i + 1);
	PrintToServer("RegisterSpell :: registered spell '%s' to id: '%i'", cfg_file, i);
	id = i;
}


public Action RemoveEnt(Handle timer, any entid) {
	int ent = EntRefToEntIndex(entid);
	if( ent > MaxClients && IsValidEntity(ent) ) {
		AcceptEntityInput(ent, "Kill");
	}
	return Plugin_Continue;
}

public void KillSpell(int spell_ref) {
	CreateTimer(0.1, RemoveEnt, spell_ref);
}

public void GiveSpellBeamTrail(int spell_ref, const char[] model, const int color[4]) {
	int spell_idx = EntRefToEntIndex(spell_ref);
	TE_SetupBeamFollow(spell_idx, PrecacheModel(model, true), 0, 1.0, 10.0, 2.0, 5, color);
	TE_SendToAll();
}

public int MakeSpellProj(int player, const char[] model, const char[] id_name, float gravity, float z_axis_arc, float throw_speed) {
	int throwable = CreateEntityByName("tf_projectile_throwable");
	if( !IsValidEntity(throwable) ) {
		return -1;
	}
	
	SetEntPropEnt(throwable, Prop_Send, "m_hOwnerEntity", player);
	SetEntProp(throwable, Prop_Send, "m_iTeamNum", GetClientTeam(player));
	SetEntityModel(throwable, model);
	
	DispatchKeyValue(throwable, "targetname", id_name);
	
	/// gravity affects spell.
	SetEntityMoveType(throwable, MOVETYPE_FLYGRAVITY);
	
	/// set the gravity amount so it can have a glide-like flight.
	SetEntityGravity(throwable, gravity);
	SetEntProp(throwable, Prop_Send, "m_CollisionGroup", 2);
	
	/// make it solid enough but not able to stand on.
	SetEntProp(throwable, Prop_Send, "m_usSolidFlags", 13);
	SetEntPropFloat(throwable, Prop_Send, "m_flElasticity", 0.4);
	
	/// makes it easier to stop sliding and get it to where u want it.
	SetEntPropFloat(throwable, Prop_Data, "m_flFriction", 3.5);
	
	/// prevent it from being able to die from damage forces
	SetEntProp(throwable, Prop_Data, "m_takedamage", 0);
	SetEntPropFloat(throwable, Prop_Data, "m_massScale", 100.0);
	
	/// disable dmg physics & prevent it from floating midair.
	AcceptEntityInput(throwable, "DisableDamageForces");
	AcceptEntityInput(throwable, "DisableFloating");
	
	DispatchSpawn(throwable);
	
	float EyePos[3]; GetClientEyePosition(player, EyePos);
	float Angle[3];  GetClientEyeAngles(player, Angle);
	
	/// get view angle for throwing
	float Speed[3]; GetAngleVectors(Angle, Speed, NULL_VECTOR, NULL_VECTOR);
	Speed[2] += z_axis_arc;
	
	ScaleVector(Speed, throw_speed);
	TeleportEntity(throwable, EyePos, Angle, Speed);
	return EntIndexToEntRef(throwable);
}

public void AttachParticle(int entref, const char[] particleType, float killtime, float offset) {
	int particle = CreateEntityByName("info_particle_system");
	if( !IsValidEntity(particle) ) {
		LogError("AttachParticle Error:: **** Couldn't Create 'info_particle_system' ****");
		return;
	}
	
	int entidx = EntRefToEntIndex(entref);
	float pos[3]; GetEntPropVector(entidx, Prop_Send, "m_vecOrigin", pos);
	pos[2] += offset;
	TeleportEntity(particle, pos, NULL_VECTOR, NULL_VECTOR);
	
	char tName[32]; GetEntPropString(entidx, Prop_Data, "m_iName", tName, sizeof(tName));
	DispatchKeyValue(particle, "targetname", "tf_particle");
	DispatchKeyValue(particle, "parentname", tName);
	DispatchKeyValue(particle, "effect_name", particleType);
	DispatchSpawn(particle);
	
	SetVariantString(tName); AcceptEntityInput(particle, "SetParent", particle, particle, 0);
	ActivateEntity(particle);
	AcceptEntityInput(particle, "start");
	if( killtime > 0.0 ) {
		CreateTimer(killtime, RemoveEnt, EntIndexToEntRef(particle));
	}
}

public bool TraceRayDontHitSelf(int entity, int mask, any data) {
	return( entity != data );
}
public bool IsInRange(int entity, int target, float dist, bool trace) {
	float entity_pos[3]; GetEntPropVector(entity, Prop_Data, "m_vecAbsOrigin", entity_pos);
	float target_pos[3]; GetEntPropVector(target, Prop_Data, "m_vecAbsOrigin", target_pos);
	bool within_range = GetVectorDistance(entity_pos, target_pos, true) <= dist*dist;
	if( within_range && trace ) {
		TR_TraceRayFilter(entity_pos, target_pos, MASK_SHOT, RayType_EndPoint, TraceRayDontHitSelf, entity);
		return TR_GetFraction() > 0.98;
	}
	return within_range;
}

public int GetPlayersInRange(int entity, int[] targets, float dist, bool trace) {
	int k;
	for( int i=1; i<=MaxClients; i++ ) {
		if( !IsClientValid(i) || !IsPlayerAlive(i) || !IsInRange(entity, i, dist, trace) ) {
			continue;
		}
		targets[k] = GetClientUserId(i);
		k++;
	}
	return k;
}

public void PlaySpellSound(int client, const char[] snd, bool once, bool to_all) {
	float pos[3]; GetEntPropVector(client, Prop_Send, "m_vecOrigin", pos);
	EmitSoundToAll(snd, client, SNDCHAN_ITEM, SNDLEVEL_TRAFFIC, SND_NOFLAGS, SNDVOL_NORMAL, 100, client, pos, NULL_VECTOR, true, 0.0);
	if( !once ) {
		EmitSoundToAll(snd, client, SNDCHAN_ITEM, SNDLEVEL_TRAFFIC, SND_NOFLAGS, SNDVOL_NORMAL, 100, client, pos, NULL_VECTOR, true, 0.0);
	}
	
	if( to_all ) {
		for( int i=MaxClients; i; --i ) {
			if( !IsClientInGame(i) || i==client ) {
				continue;
			}
			for( int x; x < 2; x++ ) {
				EmitSoundToClient(i, snd, client, SNDCHAN_ITEM, SNDLEVEL_TRAFFIC, SND_NOFLAGS, SNDVOL_NORMAL, 100, client, pos, NULL_VECTOR, true, 0.0);
			}
		}
	}
}
