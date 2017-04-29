/*  TF2 Black Hole Rockets
 *
 *  Copyright (C) 2017 Calvin Lee (Chaosxk)
 * 
 * This program is free software: you can redistribute it and/or modify it
 * under the terms of the GNU General Public License as published by the Free
 * Software Foundation, either version 3 of the License, or (at your option) 
 * any later version.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT 
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS 
 * FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along with 
 * this program. If not, see http://www.gnu.org/licenses/.
 */
 
#pragma semicolon 1

#include <sourcemod>
#include <sdkhooks>
#include <morecolors>
#include <tf2_stocks>

#define PLUGIN_VERSION "1.2"
#pragma newdecls required

ConVar g_cEnabled, g_cRadius, g_cIRadius, g_cForce, g_cDamage, g_cDuration, g_cShake, g_cCritical, g_cFriendly;

int g_iBlackhole[MAXPLAYERS+1];
int g_iTeleport[MAXPLAYERS+1];
float g_fPos[MAXPLAYERS+1][3];

public Plugin myinfo = 
{
	name = "[TF2] Black hole Rockets",
	author = "Tak (Chaosxk)",
	description = "Creates a black hole on rocket detonation.",
	version = PLUGIN_VERSION,
	url = "https://github.com/xcalvinsz/blackhole"
}

public void OnPluginStart()
{
	CreateConVar("sm_blackhole_version", "1.0", PLUGIN_VERSION, FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY);
	g_cEnabled = CreateConVar("sm_blackhole_enabled", "1", "Enables/Disables Black hole rockets.");
	g_cRadius = CreateConVar("sm_blackhole_radius", "150.0", "Radius of pull.");
	g_cIRadius = CreateConVar("sm_blackhole_inner_radius", "80.0", "How close player is before doing damage/teleported them?");
	g_cForce = CreateConVar("sm_blackhole_pullforce", "200.0", "What should the pull force be?");
	g_cDamage = CreateConVar("sm_blackhole_damage", "50.0", "How much damage should the blackholes do per second?");
	g_cDuration = CreateConVar("sm_blackhole_duration", "3.0", "How long does the black hole last?");
	g_cShake = CreateConVar("sm_blackhole_shake", "1", "When players are in radius of the black hole, their screens will shake.");
	g_cCritical = CreateConVar("sm_blackhole_critical", "0", "If set to 1, black hole rockets are only created on critical shots.");
	g_cFriendly = CreateConVar("sm_blackhole_ff", "0", "If set to 1, black hole rockets will effect teammates.");
	
	RegAdminCmd("sm_blackhole", Command_BlackHole, ADMFLAG_GENERIC, "[SM] Turn on Black Hole rockets for anyone.");
	RegAdminCmd("sm_bh", Command_BlackHole, ADMFLAG_GENERIC, "[SM] Turn on Black Hole rockets for anyone.");
	
	RegConsoleCmd("sm_blackholeme", Command_BlackHoleMe, "Turn on black hole rockets for yourself.");
	RegConsoleCmd("sm_bhme", Command_BlackHoleMe, "Turn on black hole rockets for yourself.");
	
	RegConsoleCmd("sm_setbh", Command_SetBlackHole, "Set the end point location for blackhole, blackhole will teleport instead of doing damage.");
	RegConsoleCmd("sm_resetbh", Command_ResetBlackHole, "Reset the end point location for blackhole, blackhole will start doing damage.");
	
	AutoExecConfig(false, "blackhole");  
}

public void OnClientPostAdminCheck(int client)
{
	g_iBlackhole[client] = 0;
}

public Action Command_BlackHole(int client, int args)
{
	if (!g_cEnabled.BoolValue)
	{
		CReplyToCommand(client, "{yellow}[SM]{default} This plugin is disabled.");
		return Plugin_Handled;
	}
	
	char arg1[64], arg2[64];
	
	if (args < 2)
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

	for (int i = 0; i < target_count; i++)
	{
		if (1 <= target_list[i] <= MaxClients && IsClientInGame(target_list[i]))
		{
			g_iBlackhole[target_list[i]] = button;
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
	if (!g_cEnabled.BoolValue)
	{
		CReplyToCommand(client, "{yellow}[SM]{default} This plugin is disabled.");
		return Plugin_Handled;
	}
	if (!client || !IsClientInGame(client))
	{
		ReplyToCommand(client, "[SM] You must be in game to use this command.");
		return Plugin_Handled;
	}
	g_iBlackhole[client] = !g_iBlackhole[client];
	CReplyToCommand(client, "{yellow}[SM] {default}You have %s{default} black hole rockets.", g_iBlackhole[client] ? "{green}enabled" : "{red}disabled");
	return Plugin_Handled;
}

public Action Command_SetBlackHole(int client, int args)
{
	if (!g_cEnabled.BoolValue)
	{
		CReplyToCommand(client, "{yellow}[SM]{default} This plugin is disabled.");
		return Plugin_Handled;
	}
	if (!client || !IsClientInGame(client))
	{
		ReplyToCommand(client, "[SM] You must be in game to use this command.");
		return Plugin_Handled;
	}
	GetClientAbsOrigin(client, g_fPos[client]);
	g_iTeleport[client] = 1;
	CReplyToCommand(client, "{yellow}[SM] {default}Your blackholes no longer do damage and will teleport to this location. \nType !resetbh to undo.");
	return Plugin_Handled;
}

public Action Command_ResetBlackHole(int client, int args)
{
	if (!g_cEnabled.BoolValue)
	{
		CReplyToCommand(client, "{yellow}[SM]{default} This plugin is disabled.");
		return Plugin_Handled;
	}
	if (!client || !IsClientInGame(client))
	{
		ReplyToCommand(client, "[SM] You must be in game to use this command.");
		return Plugin_Handled;
	}
	g_iTeleport[client] = 0;
	CReplyToCommand(client, "{yellow}[SM] {default}Your blackholes will no longer teleport and will do damage. \nType !setbh to undo.");
	return Plugin_Handled;
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if (!g_cEnabled.BoolValue)
		return;
		
	if (StrEqual(classname,"tf_projectile_rocket"))
	{
		SDKHook(entity, SDKHook_StartTouchPost, OnEntityTouch);
	}
}

public Action OnEntityTouch(int entity, int other)
{
	if (!g_cEnabled.BoolValue)
		return Plugin_Continue;
		
	int client = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");
	
	if (!(1 <= client <= MaxClients) || !IsClientInGame(client) || !g_iBlackhole[client])
		return Plugin_Continue;
		
	if (!(GetEntProp(entity, Prop_Send, "m_bCritical") && g_cCritical.BoolValue) && g_cCritical.BoolValue)
		return Plugin_Continue;
	
	float pos[3];
	GetEntPropVector(entity, Prop_Send, "m_vecOrigin", pos);
	
	int particle;
	
	particle = CreateEntityParticle("eb_tp_vortex01", pos);
	SetEntitySelfDestruct(particle, g_cDuration.FloatValue);
	
	particle = CreateEntityParticle(TF2_GetClientTeam(client) == TFTeam_Red ? "raygun_projectile_red_crit" : "raygun_projectile_blue_crit", pos);
	SetEntitySelfDestruct(particle, g_cDuration.FloatValue);
	
	particle = CreateEntityParticle(TF2_GetClientTeam(client) == TFTeam_Red ? "eyeboss_vortex_red" : "eyeboss_vortex_blue", pos);
	SetEntitySelfDestruct(particle, g_cDuration.FloatValue);
	
	DataPack pPack;
	CreateDataTimer(0.1, Timer_Pull, pPack, TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT);
	pPack.WriteFloat(GetEngineTime() + g_cDuration.FloatValue);
	pPack.WriteFloat(pos[0]);
	pPack.WriteFloat(pos[1]);
	pPack.WriteFloat(pos[2]);
	pPack.WriteCell(GetClientUserId(client));
	
	return Plugin_Handled;
}

public Action Timer_Pull(Handle timer, DataPack pack)
{
	pack.Reset();
	
	if (GetEngineTime() >= pack.ReadFloat())
	{
		return Plugin_Stop;
	}
	
	float pos[3];
	pos[0] = pack.ReadFloat();
	pos[1] = pack.ReadFloat();
	pos[2] = pack.ReadFloat();
	
	int attacker = GetClientOfUserId(pack.ReadCell());
	
	for (int i = 1; i <= MaxClients; i++) 
	{
		if (!IsClientInGame(i) || !IsPlayerAlive(i)) 
			continue;
			
		float cpos[3];
		GetClientAbsOrigin(i, cpos);
		
		float Distance = GetVectorDistance(pos, cpos);
		
		if (attacker == i)
			continue;
			
		if (!g_cFriendly.BoolValue && TF2_GetClientTeam(i) == TF2_GetClientTeam(attacker))
			continue;
			
		if (Distance <= g_cRadius.FloatValue) 
		{
			float velocity[3];
			MakeVectorFromPoints(pos, cpos, velocity);
			NormalizeVector(velocity, velocity);
			ScaleVector(velocity, -g_cForce.FloatValue);
			TeleportEntity(i, NULL_VECTOR, NULL_VECTOR, velocity);
			
			if(g_cShake.BoolValue) 
				ShakeScreen(i, 20.0, 0.1, 0.7);
		}
		
		if (Distance <= g_cIRadius.FloatValue)
		{
			if (g_iTeleport[attacker])
			{
				TeleportEntity(i, g_fPos[attacker], NULL_VECTOR, NULL_VECTOR);
				return Plugin_Continue;
			}
			
			SDKHooks_TakeDamage(i, attacker, attacker, g_cDamage.FloatValue, DMG_REMOVENORAGDOLL); //dmg_removenoragdoll dont work?
			
			if (!IsPlayerAlive(i))
			{
				int ragdoll = GetEntPropEnt(i, Prop_Send, "m_hRagdoll");
				
				if (!IsValidEntity(ragdoll))
					continue;
					
				AcceptEntityInput(ragdoll, "kill");
			}
		}
	}
	return Plugin_Continue;
}

stock int CreateEntityParticle(const char[] sParticle, const float[3] pos)
{
	int entity = CreateEntityByName("info_particle_system");
	TeleportEntity(entity, pos, NULL_VECTOR, NULL_VECTOR);
	DispatchKeyValue(entity, "effect_name", sParticle);
	DispatchSpawn(entity);
	ActivateEntity(entity);
	AcceptEntityInput(entity, "start");
	return entity;
}

stock void SetEntitySelfDestruct(int entity, float duration)
{
	char output[64]; 
	Format(output, sizeof(output), "OnUser1 !self:kill::%.1f:1", duration);
	SetVariantString(output);
	AcceptEntityInput(entity, "AddOutput"); 
	AcceptEntityInput(entity, "FireUser1");
}

stock void ShakeScreen(int client, float intensity, float duration, float frequency)
{
	Handle bf; 
	if ((bf = StartMessageOne("Shake", client)) != null)
	{
		BfWriteByte(bf, 0);
		BfWriteFloat(bf, intensity);
		BfWriteFloat(bf, duration);
		BfWriteFloat(bf, frequency);
		EndMessage();
	}
}