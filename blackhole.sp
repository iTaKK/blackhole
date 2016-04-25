#pragma semicolon 1
#include <morecolors>
#include <tf2_stocks>
#pragma newdecls required
#include <sourcemod>
#include <sdkhooks>

#define PLUGIN_VERSION "1.1"

//	v.1.1 Changes
//	Fixed issue with multiple black holes having issue with each other
//	Fixed issue with black holes still pulling players even though the particles disapeared
//	Change the shaking effect to usermessages instead of faking client commands
//	Added !setbh which will set the blackhole teleport end location to where your standing, blackholes no longer do damage
//	Added !resetbh which will clear the blackhole teleport end location and blackholes will start doing damage
//	Added sm_blackhole_ff which if set to 1 will effect teammates
//	For consistency, sm_blackhole_damage_radius was renamed to sm_blackhole_inner_radius

ConVar ConVars[9] = {null, ...};
int gEnabled, gShake, gfValue, gCritical;
float gRadius, gForce, gDamage, gDRadius, gDuration;
int gTeleport[MAXPLAYERS+1];
float gPos[MAXPLAYERS+1][3];

int gBlackHole[MAXPLAYERS+1];

public Plugin myinfo = 
{
	name = "[TF2] Black hole Rockets",
	author = "Tak (Chaosxk)",
	description = "Creates a black hole on rocket detonation.",
	version = PLUGIN_VERSION,
	url = "https://forums.alliedmods.net/showthread.php?p=2399726"
}

public void OnPluginStart()
{
	CreateConVar("sm_blackhole_version", "1.0", PLUGIN_VERSION, FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY);
	ConVars[0] = CreateConVar("sm_blackhole_enabled", "1", "Enables/Disables Black hole rockets.");
	ConVars[1] = CreateConVar("sm_blackhole_radius", "150", "Radius of pull.");
	ConVars[2] = CreateConVar("sm_blackhole_pullforce", "200", "What should the pull force be?");
	ConVars[3] = CreateConVar("sm_blackhole_damage", "50", "How much damage should the blackholes do per second?");
	ConVars[4] = CreateConVar("sm_blackhole_inner_radius", "80", "How close player is before doing damage/teleported them?");
	ConVars[5] = CreateConVar("sm_blackhole_duration", "3.0", "How long does the black hole last?");
	ConVars[6] = CreateConVar("sm_blackhole_shake", "1", "When players are in radius of the black hole, their screens will shake.");
	ConVars[7] = CreateConVar("sm_blackhole_critical", "0", "If set to 1, black hole rockets are only created on critical shots.");
	ConVars[8] = CreateConVar("sm_blackhole_ff", "0", "If set to 1, black hole rockets will effect teammates.");
	
	RegAdminCmd("sm_blackhole", Command_BlackHole, ADMFLAG_GENERIC, "[SM] Turn on Black Hole rockets for anyone.");
	RegAdminCmd("sm_bh", 		Command_BlackHole, ADMFLAG_GENERIC, "[SM] Turn on Black Hole rockets for anyone.");
	
	RegConsoleCmd("sm_blackholeme", Command_BlackHoleMe, "Turn on black hole rockets for yourself.");
	RegConsoleCmd("sm_bhme", 		Command_BlackHoleMe, "Turn on black hole rockets for yourself.");
	
	RegConsoleCmd("sm_setbh", 		Command_SetBlackHole, "Set the end point location for blackhole, blackhole will teleport instead of doing damage.");
	RegConsoleCmd("sm_resetbh", 	Command_ResetBlackHole, "Reset the end point location for blackhole, blackhole will start doing damage.");
	
	for(int i = 0; i < 9; i++)
		ConVars[i].AddChangeHook(OnConvarChanged);
	
	AutoExecConfig(false, "blackhole");  
}

public void OnConfigsExecuted()
{
	gEnabled	= !!GetConVarInt(ConVars[0]);
	gRadius 	= GetConVarFloat(ConVars[1]);
	gForce		= GetConVarFloat(ConVars[2]);
	gDamage		= GetConVarFloat(ConVars[3])*0.1;
	gDRadius	= GetConVarFloat(ConVars[4]);
	gDuration	= GetConVarFloat(ConVars[5]);
	gShake		= !!GetConVarInt(ConVars[6]);
	gCritical	= GetConVarInt(ConVars[7]);
	gfValue 	= GetConVarInt(ConVars[8]);
}

public void OnConvarChanged(Handle convar, char[] oldValue, char[] newValue) 
{
	if (StrEqual(oldValue, newValue, true))
		return;
		
	float iNewValue = StringToFloat(newValue);
	
	if(convar == ConVars[0])
		gEnabled = !!RoundFloat(iNewValue);
	else if(convar == ConVars[1])
		gRadius = iNewValue;
	else if(convar == ConVars[2])
		gForce = iNewValue;
	else if(convar == ConVars[3])
		gDamage = iNewValue*0.1;
	else if(convar == ConVars[4])
		gDRadius = iNewValue;
	else if(convar == ConVars[5])
		gDuration = iNewValue;
	else if(convar == ConVars[6])
		gShake = !!RoundFloat(iNewValue);
	else if(convar == ConVars[7])
		gCritical = !!RoundFloat(iNewValue);
	else if(convar == ConVars[8])
		gfValue = !!RoundFloat(iNewValue);
}

public void OnClientPostAdminCheck(int client)
{
	gBlackHole[client] = 0;
}

public Action Command_BlackHole(int client, int args)
{
	if(!gEnabled)
	{
		CReplyToCommand(client, "{yellow}[SM]{default} This plugin is disabled.");
		return Plugin_Handled;
	}
	if(!IsClientInGame(client))
	{
		ReplyToCommand(client, "[SM] You must be in game to use this command.");
		return Plugin_Handled;
	}
	
	char arg1[64], arg2[64];
	
	if(args < 2)
	{
		CReplyToCommand(client, "{yellow}[SM] {default}Usage: sm_blackhole <client> <1:on 0:off>");
		return Plugin_Handled;
	}

	GetCmdArg(1, arg1, sizeof(arg1));
	GetCmdArg(2, arg2, sizeof(arg2));
	bool button = !!StringToInt(arg2);

	char target_name[MAX_TARGET_LENGTH];
	int target_list[MAXPLAYERS], target_count;
	bool tn_is_ml;
	if((target_count = ProcessTargetString(
			arg1,
			client,
			target_list,
			MAXPLAYERS,
			COMMAND_FILTER_CONNECTED,
			target_name,
			sizeof(target_name),
			tn_is_ml)) <= 0)
	{
		CReplyToCommand(client, "{yellow}[SM] {default}Can not find client");
		return Plugin_Handled;
	}

	for(int i = 0; i < target_count; i++)
	{
		if(1 <= target_list[i] <= MaxClients && IsClientInGame(target_list[i]))
		{
			gBlackHole[target_list[i]] = button;
		}
	}
		
	if (tn_is_ml)
		CShowActivity2(client, "{yellow}[SM] ", "{default}%N has %s %t black hole rockets.", client, button ? "{green}given{default}" : "{red}removed{default}", target_name);
	else
		CShowActivity2(client, "{yellow}[SM] ", "{default}%N has %s %s black hole rockets.", client, button ? "{green}given{default}" : "{red}removed{default}", target_name);

	return Plugin_Handled;
}

public Action Command_BlackHoleMe(int client, int args)
{
	if(!gEnabled)
	{
		CReplyToCommand(client, "{yellow}[SM]{default} This plugin is disabled.");
		return Plugin_Handled;
	}
	if(!IsClientInGame(client))
	{
		ReplyToCommand(client, "[SM] You must be in game to use this command.");
		return Plugin_Handled;
	}
	gBlackHole[client] = !gBlackHole[client];
	CReplyToCommand(client, "{yellow}[SM] {default}You have %s{default} black hole rockets.", gBlackHole[client] ? "{green}enabled" : "{red}disabled");
	return Plugin_Handled;
}

public Action Command_SetBlackHole(int client, int args)
{
	if(!gEnabled)
	{
		CReplyToCommand(client, "{yellow}[SM]{default} This plugin is disabled.");
		return Plugin_Handled;
	}
	if(!IsClientInGame(client))
	{
		ReplyToCommand(client, "[SM] You must be in game to use this command.");
		return Plugin_Handled;
	}
	GetClientAbsOrigin(client, gPos[client]);
	gTeleport[client] = 1;
	CReplyToCommand(client, "{yellow}[SM] {default}Your blackholes no longer do damage and will teleport to this location. \nType !resetbh to undo.");
	return Plugin_Handled;
}

public Action Command_ResetBlackHole(int client, int args)
{
	if(!gEnabled)
	{
		CReplyToCommand(client, "{yellow}[SM]{default} This plugin is disabled.");
		return Plugin_Handled;
	}
	if(!IsClientInGame(client))
	{
		ReplyToCommand(client, "[SM] You must be in game to use this command.");
		return Plugin_Handled;
	}
	gTeleport[client] = 0;
	CReplyToCommand(client, "{yellow}[SM] {default}Your blackholes will no longer teleport and will do damage. \nType !setbh to undo.");
	return Plugin_Handled;
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if(StrEqual(classname,"tf_projectile_rocket"))
	{
		SDKHook(entity, SDKHook_StartTouchPost, OnEntityTouch);
	}
}

public Action OnEntityTouch(int entity, int other)
{
	int crit = GetEntProp(entity, Prop_Send, "m_bCritical");
	if(!(crit && gCritical) && gCritical)
		return Plugin_Continue;
	int client = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");
	if(client < 1 || client > MaxClients)
		return Plugin_Continue;
	if(!IsClientInGame(client)) 
		return Plugin_Continue;
	if(!gBlackHole[client])
		return Plugin_Continue;
	
	float pos[3];
	GetEntPropVector(entity, Prop_Send, "m_vecOrigin", pos);
	
	int particle;
	
	particle = CreateEntityParticle("eb_tp_vortex01", pos);
	SetEntitySelfDestruct(particle);
	
	particle = CreateEntityParticle(TF2_GetClientTeam(client) == TFTeam_Red ? "raygun_projectile_red_crit" : "raygun_projectile_blue_crit", pos);
	SetEntitySelfDestruct(particle);
	
	particle = CreateEntityParticle(TF2_GetClientTeam(client) == TFTeam_Red ? "eyeboss_vortex_red" : "eyeboss_vortex_blue", pos);
	SetEntitySelfDestruct(particle);
	
	DataPack pPack;
	CreateDataTimer(0.1, Timer_Pull, pPack, TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT);
	pPack.WriteCell(0.0);
	pPack.WriteCell(pos[0]);
	pPack.WriteCell(pos[1]);
	pPack.WriteCell(pos[2]);
	pPack.WriteCell(GetClientUserId(client));
	
	return Plugin_Handled;
}

public Action Timer_Pull(Handle timer, DataPack pack)
{
	pack.Reset();
	float time = pack.ReadCell();
	if(time >= gDuration)
	{
		pack.Reset();
		pack.WriteCell(0.0);
		return Plugin_Stop;
	}
	pack.Reset();
	pack.WriteCell(time+0.1);
	
	float pos[3];
	pos[0] = pack.ReadCell();
	pos[1] = pack.ReadCell();
	pos[2] = pack.ReadCell();
	int attacker = GetClientOfUserId(pack.ReadCell());
	
	for(int i = 1; i <= MaxClients; i++) 
	{
		if(!IsClientInGame(i) || !IsPlayerAlive(i)) 
			continue;
		float cpos[3];
		GetClientAbsOrigin(i, cpos);
		float Distance = GetVectorDistance(pos, cpos);
		if(attacker == i)
			continue;
		if(!gfValue && TF2_GetClientTeam(i) == TF2_GetClientTeam(attacker))
			continue;
		if(Distance <= gRadius) 
		{
			float velocity[3];
			MakeVectorFromPoints(pos, cpos, velocity);
			NormalizeVector(velocity, velocity);
			ScaleVector(velocity, -gForce);
			TeleportEntity(i, NULL_VECTOR, NULL_VECTOR, velocity);
			
			if(gShake) 
				ShakeScreen(i, 20.0, 0.1, 0.7);
		}
		if(Distance <= gDRadius)
		{
			if(gTeleport[attacker])
			{
				TeleportEntity(i, gPos[attacker], NULL_VECTOR, NULL_VECTOR);
				return Plugin_Continue;
			}
			SDKHooks_TakeDamage(i, attacker, attacker, gDamage, DMG_REMOVENORAGDOLL); //dmg_removenoragdoll dont work?
			if(!IsPlayerAlive(i))
			{
				int ragdoll = GetEntPropEnt(i, Prop_Send, "m_hRagdoll");
				if(!IsValidEntity(ragdoll))
					continue;
				AcceptEntityInput(ragdoll, "kill");
			}
		}
	}
	return Plugin_Continue;
}

public int CreateEntityParticle(const char[] sParticle, const float[3] pos)
{
	int entity = CreateEntityByName("info_particle_system");
	TeleportEntity(entity, pos, NULL_VECTOR, NULL_VECTOR);
	DispatchKeyValue(entity, "effect_name", sParticle);
	DispatchSpawn(entity);
	ActivateEntity(entity);
	AcceptEntityInput(entity, "start");
	return entity;
}

public void SetEntitySelfDestruct(int entity)
{
	char output[64]; 
	Format(output, sizeof(output), "OnUser1 !self:kill::%.1f:1", gDuration);
	SetVariantString(output);
	AcceptEntityInput(entity, "AddOutput"); 
	AcceptEntityInput(entity, "FireUser1");
}

public void ShakeScreen(int client, float intensity, float duration, float frequency)
{
	Handle bf; 
	if((bf = StartMessageOne("Shake", client)) != null)
	{
		BfWriteByte(bf, 0);
		BfWriteFloat(bf, intensity);
		BfWriteFloat(bf, duration);
		BfWriteFloat(bf, frequency);
		EndMessage();
	}
}  