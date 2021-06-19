#pragma semicolon 1

#define DEBUG

#define PLUGIN_AUTHOR ""
#define PLUGIN_VERSION "0.00"
#define EF_BONEMERGE                (1 << 0)
#define EF_NOSHADOW                 (1 << 4)
#define EF_PARENT_ANIMATES          (1 << 9)
#include <sourcemod>
#include <sdktools>
#include <tf2>
#include <tf2_stocks>
#include <sdkhooks>
#include <smlib>


new g_offsCollisionGroup;

public Plugin myinfo = 
{
	name = "", 
	author = PLUGIN_AUTHOR, 
	description = "", 
	version = PLUGIN_VERSION, 
	url = ""
};


int g_iMapPrefixType = 0;
int g_iZomTeamIndex;
int g_iHumTeamIndex;
int g_bCount[2048 + 1] =  { 0, ... };
bool g_bPropNailed[2048 + 1] =  { false, ... };
int g_pGrabbedEnt[MAXPLAYERS + 1];
Handle gTimer;
Handle gTimer2;
bool g_bPropBeingHeld[2048 + 1] =  { false, ... };
public void OnPluginStart()
{
	g_offsCollisionGroup = FindSendPropInfo("CBaseEntity", "m_CollisionGroup");
	if (g_offsCollisionGroup == -1) {
		PrintToServer("\n\n\n AFADSFADSFSA \n\n\n");
	}
	HookEvent("teamplay_round_start", OnRound);
	HookEvent("player_death", PlayerDeath);
	HookEvent("player_spawn", PlayerSpawn, EventHookMode_Post);
	RegConsoleCmd("+grab", Command_Grab);
	RegConsoleCmd("-grab", Command_UnGrab);
	RegConsoleCmd("phrase", Command_Phrase);
	RegConsoleCmd("test", Command_Test);
}

public void OnMapStart() {
	zombimod();
	logGameRuleTeamRegister();
	PrecacheModel("models/crossbow_bolt.mdl", true);
	PrecacheSound("weapons/crowbar/crowbar_impact1.wav", true);
	PrecacheModel("models/props_debris/wood_board05a.mdl", true);
	for (int i = 1; i <= 2048; i++) {
		g_bCount[i] = 0;
		g_bPropNailed[i] = false;
		g_bPropBeingHeld[i] = false;
	}
	for (int i = 1; i < MAXPLAYERS; i++) {
		g_pGrabbedEnt[i] = -1;
	}
	
	gTimer = CreateTimer(0.1, UpdateObjects, INVALID_HANDLE, TIMER_REPEAT);
}
public OnMapEnd()
{
	CloseHandle(gTimer);
}


public OnClientPutInServer(client) {
	if (client && !IsFakeClient(client)) {
		g_pGrabbedEnt[client] = -1;
		g_bPropBeingHeld[client] = false;
	}
}

public Action OnRound(Handle event, const String:name[], bool dontBroadcast) {
	for (int i = 0; i <= 2048; i++) {
		g_bCount[i] = 0;
		g_bPropBeingHeld[i] = false;
		g_bPropNailed[i] = false;
	}
	for (int j = 1; j <= MAXPLAYERS; j++) {
		if (IsValidClient(j) && IsClientInGame(j)) {
			g_pGrabbedEnt[j] = -1;
		}
	}
}
public Action PlayerSpawn(Handle event, const String:name[], bool dontBroadcast)
{
	int client;
	client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (GetClientTeam(client) == g_iHumTeamIndex) {
		SetEntData(client, g_offsCollisionGroup, 2, 4, true);
	}
	else if (GetClientTeam(client) == g_iZomTeamIndex) {
		SetEntData(client, g_offsCollisionGroup, 5, 4, true);
	}
	// reset object held
	g_pGrabbedEnt[client] = -1;
	g_bPropBeingHeld[client] = false;
	return Plugin_Continue;
}
public Action PlayerDeath(Handle event, const String:name[], bool dontBroadcast) {
	int client;
	client = GetClientOfUserId(GetEventInt(event, "userid"));
	// reset object held
	g_pGrabbedEnt[client] = -1;
	g_bPropBeingHeld[client] = false;
	return Plugin_Continue;
}

public Action OnPlayerRunCmd(client, &buttons) {
	if ((buttons & IN_ATTACK2)) {
		if (GetClientTeam(client) == g_iHumTeamIndex) {
			int TracedEntity = TraceRayToEntityAndNailIt(client, 55.0, true);
			if (TracedEntity != -1) {
				UpgradeStatusOfProp(TracedEntity, client);
			}
		}
	}
}
public Action Command_Grab(client, args)
{
	// make sure client is not spectating
	if (!IsPlayerAlive(client))
		return Plugin_Handled;
	
	
	// find entity
	int ent = TraceRayToEntityAndNailIt(client, 80.0, false);
	if (ent == -1) {
		PrintToChat(client, "-1");
		return Plugin_Handled;
	}
	
	// only grab physics entities
	char edictname[128];
	GetEdictClassname(ent, edictname, 128);
	if (strncmp("prop_", edictname, 5, false) == 0 && !g_bPropNailed[ent])
	{
		gTimer2 = CreateTimer(0.1, CheckForUpdates, INVALID_HANDLE, TIMER_REPEAT || TIMER_FLAG_NO_MAPCHANGE);
		// grab entity
		g_pGrabbedEnt[client] = ent;
		SetEntProp(g_pGrabbedEnt[client], Prop_Data, "m_CollisionGroup", 2);
		SetEntityRenderMode(g_pGrabbedEnt[client], RENDER_TRANSCOLOR);
		SetEntityRenderColor(g_pGrabbedEnt[client], 255, 255, 255, 128);
		g_bPropBeingHeld[ent] = true;
	}
	return Plugin_Handled;
}
public Action:CheckForUpdates(Handle:timer, any:client) {
	int ent = g_pGrabbedEnt[client];
	UpgradeStatusOfProp(ent, client);
}
public Action Command_UnGrab(client, args)
{
	// make sure client is not spectating
	if (!IsPlayerAlive(client))
		return Plugin_Handled;
	
	//SetEntityRenderMode(g_pGrabbedEnt[client], RENDER_TRANSCOLOR);
	if (IsValidEntity(g_pGrabbedEnt[client])) {
		SetEntityRenderColor(g_pGrabbedEnt[client], 255, 255, 255, 255);
		SetEntProp(g_pGrabbedEnt[client], Prop_Data, "m_CollisionGroup", 5);
		g_bPropBeingHeld[client] = false;
		g_pGrabbedEnt[client] = -1;
	}
	
	return Plugin_Handled;
}
public Action Command_Phrase(client, args)
{
	if (!IsPlayerAlive(client))
		return Plugin_Handled;
	
	int iEnt = TraceRayToEntityAndNailIt(client, 40.0, false);
	if (IsValidClient(client) && IsStuckInEnt(client, iEnt) && GetClientTeam(client) == g_iHumTeamIndex && IsValidEntity(iEnt)) {
		CreateTimer(0.5, PhasingTimer, iEnt, TIMER_FLAG_NO_MAPCHANGE);
		SetEntProp(iEnt, Prop_Data, "m_CollisionGroup", 2);
		PrintToChat(client, "You're stuck'");
	} else {
		PrintToChat(client, "You're  not stuck'");
	}
	
	return Plugin_Handled;
}
public Action Command_Test(client, args) {
	float vecOrigin[3];
	GetClientAbsOrigin(client, vecOrigin);
	vecOrigin[0] = vecOrigin[0] + 5.0;
	int iEnt = CreateEntityByName("prop_physics_override"); //prop_physics_override
	if (iEnt != -1 && IsValidEntity(iEnt)) {
		DispatchKeyValue(iEnt, "model", "models/props_debris/wood_board05a.mdl");
		DispatchKeyValue(iEnt, "solid", "5");
		DispatchSpawn(iEnt);
		TeleportEntity(iEnt, vecOrigin, NULL_VECTOR, NULL_VECTOR);
	}
}
public Action PhasingTimer(Handle timer, any:iEnt) {
	SetEntProp(iEnt, Prop_Data, "m_CollisionGroup", 5);
}
public bool OnCollide(client, collisiongroup, contentsmask, bool:result) {
}
//This for physical entities
stock TraceRayToEntityAndNailIt(int iClient, float Distance, bool bNail) {
	float vecEyeAngle[3];
	float vecEyePos[3];
	
	GetClientEyePosition(iClient, vecEyePos); //Eyes
	GetClientEyeAngles(iClient, vecEyeAngle); //Where the client is looking at
	//vecEyePos[2] += 10;
	//vecEyeAngle[0] = 0.0;
	Handle trace2 = TR_TraceRayFilterEx(vecEyePos, vecEyeAngle, CONTENTS_SOLID, RayType_Infinite, TraceRayNoPlayers, iClient);
	
	if (TR_DidHit(trace2)) {
		float EndPos[3];
		float EndPosForEnt[3];
		float EndPosForEntSt[3];
		char ClassName0[64];
		char ClassName[64];
		vecEyePos[2] -= 10;
		//char surfaceName[128];
		int iEnt = TR_GetEntityIndex(trace2);
		TR_GetEndPosition(EndPos, trace2);
		GetEntPropVector(iEnt, Prop_Send, "m_vecOrigin", EndPosForEnt);
		char StrName[64]; Format(StrName, sizeof(StrName), "Prop%i", iEnt);
		//TR_GetSurfaceName(null, surfaceName, sizeof(surfaceName));
		float flDistance = GetVectorDistance(vecEyePos, EndPos);
		//GetEntPropVector(iEnt, Prop_Send, "m_vecOrigin", EndPos);
		GetEntityClassname(iEnt, ClassName0, sizeof(ClassName0));
		if (flDistance < Distance && StrContains(ClassName0, "physics", false) != -1) {
			PrintHintText(iClient, "Prop:%d, Distance:%f", iEnt, flDistance);
			Handle trace = TR_TraceRayFilterEx(EndPos, vecEyeAngle, CONTENTS_SOLID, RayType_Infinite, TraceRayWalls);
			if (TR_DidHit(trace)) {
				if (TR_GetEntityIndex(trace) > 0) {
					delete trace;
					//return -1;
				}
				if (bNail) {
					TR_GetEndPosition(EndPosForEntSt, trace);
					if (GetVectorDistance(EndPos, EndPosForEntSt) < Distance) {
						GetEntityClassname(iEnt, ClassName, sizeof(ClassName));
						if (StrContains(ClassName, "physics", false) != -1) {
							g_bCount[iEnt]++;
							if (g_bCount[iEnt] < 2 && !g_bPropNailed[iEnt]) {
								//GetEntPropString(iEnt, Prop_Data, "m_iName", oldEntName, sizeof(oldEntName));
								int nail = CreateEntityByName("prop_dynamic_override");
								char StrEntityName[64]; Format(StrEntityName, sizeof(StrEntityName), "prop_dynamic_%i", nail);
								DispatchKeyValue(nail, "model", "models/crossbow_bolt.mdl");
								DispatchKeyValue(nail, "targetname", StrEntityName);
								DispatchKeyValue(nail, "parentname", StrName);
								
								//DispatchKeyValue(nail, "Mode", "0");
								DispatchSpawn(nail);
								TeleportEntity(nail, EndPos, vecEyeAngle, NULL_VECTOR);
								
								SetVariantString(StrName);
								AcceptEntityInput(nail, "SetParent", nail, nail, 0);
								g_bPropNailed[nail] = true;
								g_pGrabbedEnt[iClient] = -1;
								g_bPropNailed[iEnt] = true;
								TF2_CreateGlow(nail);
								EmitSoundToAll("weapons/crowbar/crowbar_impact1.wav", iClient, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, SNDVOL_NORMAL, 100, iEnt, NULL_VECTOR, NULL_VECTOR, true, 0.0);
							}
							
						}
					}
				} else {
					return iEnt;
				}
			}
			return iEnt;
		}
		return -1;
	}
	return -1;
}

//This for walls
stock TraceRayToEntityToConfirmNail(int iClient, float Distance) {
	float vecEyeAngle[3];
	float OriginalPos[3];
	
	GetClientAbsOrigin(iClient, OriginalPos);
	//-2 means it's not a floor. Or the distance is far away than the initial distance limit
	//-1 means it's floor or wall. 
	//GetClientEyePosition(iClient, vecEyePos); //Eyes
	GetClientEyeAngles(iClient, vecEyeAngle); //Where the client is looking at
	//vecEyePos[2] += 10;
	//vecEyePos[1] -= 10;
	//TR_TraceRayFilter(vecEyePos, vecEyeAngle, MASK_SOLID, RayType_Infinite, TraceRayHitSelf, iClient);
	TR_TraceRayFilter(OriginalPos, vecEyeAngle, MASK_SOLID, RayType_Infinite, TraceRayNoPlayers, iClient);
	if (TR_DidHit(INVALID_HANDLE)) {
		float EndPos[3];
		//vecEyePos[2] -= 10;
		//OriginalPos[2] += 10;
		char surfaceName[128];
		int iEnt = TR_GetEntityIndex(INVALID_HANDLE);
		TR_GetEndPosition(EndPos, INVALID_HANDLE);
		TR_GetSurfaceName(null, surfaceName, sizeof(surfaceName));
		//PrintHintText(iClient, "%s", surfaceName);
		float flDistance = GetVectorDistance(OriginalPos, EndPos);
		//GetEntPropVector(iEnt, Prop_Send, "m_vecOrigin", EndPos);
		if (iEnt == 0 && flDistance < Distance) {
			PrintToChat(iClient, "Distance:%f, AimingAt:%d", flDistance, iEnt);
			return iEnt;
		}
		return -2;
	}
	return -2;
}
public bool TraceRayNoPlayers(entity, mask, any:data)
{
	if (entity == data || (entity >= 1 && entity <= MaxClients))
	{
		return false;
	}
	return true;
}
public bool TraceRayHitSelf(entity, mask, any:data) {
	return (entity != data);
}
public bool TraceRayWalls(entity, mask, any:data) {
	return entity == 0;
}
stock int EntityNailAttachTo(int client, int iEnt) {
	g_bCount[iEnt]++;
	char oldEntName[64];
	char classNameCheck[64];
	char classname2[64];
	GetEntityClassname(iEnt, classNameCheck, sizeof(classNameCheck));
	if (StrContains(classNameCheck, "physics", false) != -1) {
		GetEntPropString(iEnt, Prop_Data, "m_iName", oldEntName, sizeof(oldEntName));
		float end[3];
		float start[3];
		float angle[3];
		
		GetClientEyePosition(client, start);
		GetClientEyeAngles(client, angle);
		TR_TraceRayFilter(start, angle, MASK_ALL, RayType_Infinite, TraceEntityFilterPlayer, client);
		if (TR_DidHit(INVALID_HANDLE))
		{
			TR_GetEndPosition(end, INVALID_HANDLE);
		}
		char strName[126], strClass[64];
		float OriginalPos[3];
		float flAng[3];
		if (g_bCount[iEnt] < 2) {  // && g_pGrabbedEnt[client] == -1
			int ent = CreateEntityByName("prop_dynamic_override");
			DispatchKeyValue(ent, "model", "models/crossbow_bolt.mdl");
			DispatchKeyValue(ent, "target", strName);
			DispatchKeyValue(ent, "Mode", "0");
			DispatchSpawn(ent);
			TeleportEntity(ent, end, angle, NULL_VECTOR);
			GetEntityClassname(ent, classname2, sizeof(classname2));
			SetEntProp(ent, Prop_Data, "m_iHealth", 100);
			SetEntProp(ent, Prop_Data, "m_takedamage", 2);
			
			Format(strName, sizeof(strName), "%s%i", strClass, iEnt);
			DispatchKeyValue(iEnt, "targetname", strName);
			SetVariantString(strName);
			AcceptEntityInput(ent, "SetParent");
			
			TF2_CreateGlow(ent);
			SetEntPropString(iEnt, Prop_Data, "m_iName", oldEntName);
			g_bPropNailed[iEnt] = true; //Cuz it's nailed
			PrintHintText(client, "Succesfully nailed classname :%s, PropId:%d, With:%d/Classname:%s", classNameCheck, iEnt, ent, classname2);
			EmitSoundToAll("weapons/crowbar/crowbar_impact1.wav", client, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, SNDVOL_NORMAL, 100, client, end, NULL_VECTOR, true, 0.0);
			Command_UnGrab(client, 0);
			GetEntPropVector(iEnt, Prop_Send, "m_vecOrigin", OriginalPos);
			GetEntPropVector(iEnt, Prop_Data, "m_angRotation", flAng);
			
			
			SetEntityMoveType(iEnt, MOVETYPE_NONE);
			SetEntProp(iEnt, Prop_Data, "m_takedamage", 2);
			SetEntProp(iEnt, Prop_Data, "m_iHealth", 500);
			
			
			
			SDKHook(iEnt, SDKHook_OnTakeDamage, OnTakeDamage);
			return ent;
		}
		HookSingleEntityOutput(iEnt, "OnBreak", propBreak);
	} else {
		PrintHintText(client, "Failed at nailing classname:%s", classNameCheck);
	}
}

public Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	int hpVictim = GetEntProp(victim, Prop_Data, "m_iHealth");
	PrintHintTextToAll("PropHealth:%d", hpVictim);
	PrintToChatAll("%d, %d", attacker, victim);
	
	if (GetClientTeam(attacker) == g_iHumTeamIndex) {
		damage = 1.0;
		return Plugin_Changed;
	}
	return Plugin_Continue;
}
stock int TF2_CreateGlow(int iEnt)
{
	char oldEntName[64];
	GetEntPropString(iEnt, Prop_Data, "m_iName", oldEntName, sizeof(oldEntName));
	
	char strName[126], strClass[64];
	GetEntityClassname(iEnt, strClass, sizeof(strClass));
	Format(strName, sizeof(strName), "%s%i", strClass, iEnt);
	DispatchKeyValue(iEnt, "targetname", strName);
	
	int ent = CreateEntityByName("tf_glow");
	DispatchKeyValue(ent, "targetname", "RainbowGlow");
	DispatchKeyValue(ent, "target", strName);
	DispatchKeyValue(ent, "Mode", "0");
	DispatchSpawn(ent);
	
	int color[4];
	color[0] = 0;
	color[1] = 255;
	color[2] = 0;
	color[3] = 255;
	
	SetVariantColor(color);
	AcceptEntityInput(ent, "SetGlowColor");
	
	AcceptEntityInput(ent, "Enable");
	
	SetEntPropString(iEnt, Prop_Data, "m_iName", oldEntName);
	
	return ent;
}

UpgradeStatusOfProp(iEntity, client) {
	if (iEntity != -1) {
		if (g_bPropNailed[iEntity]) {
			HookSingleEntityOutput(iEntity, "OnBreak", propBreak);
			SetEntityRenderColor(iEntity, 255, 255, 255, 255);
			SetEntProp(iEntity, Prop_Data, "m_CollisionGroup", 5);
			SetEntityMoveType(iEntity, MOVETYPE_NONE);
			g_bPropBeingHeld[client] = false;
			g_pGrabbedEnt[client] = -1;
			//CloseHandle(gTimer2);
			
		}
		else if (!g_bPropNailed[iEntity]) {
			//SetEntityMoveType(iEntity, MOVETYPE_NONE);
			SetEntProp(iEntity, Prop_Data, "m_iHealth", 100);
			SetEntProp(iEntity, Prop_Data, "m_takedamage", 2);
		}
	}
}
public void propBreak(const char[] output, int caller, int activator, float delay)
{
	g_bPropNailed[caller] = false;
	//RemoveRemainNails(caller);
	UnhookSingleEntityOutput(caller, "OnBreak", propBreak);
}


public bool TraceEntityFilterPlayer(entity, contentsMask, any:data)
{
	return entity > MaxClients;
}

//Stuck and phasing here.
stock bool IsPlayerStuckInEnt(int client, int ent)
{
	float vecMin[3], vecMax[3], vecOrigin[3];
	
	GetClientMins(client, vecMin);
	GetClientMaxs(client, vecMax);
	
	GetClientEyeAngles(client, vecOrigin);
	
	TR_TraceHullFilter(vecOrigin, vecOrigin, vecMin, vecMax, MASK_ALL, TraceRayHitOnlyEnt, ent);
	return TR_DidHit();
}

public bool TraceRayHitOnlyEnt(int entity, int contentsMask, any data)
{
	return entity == data;
}
/*
stock RemoveRemainNails(int iEnt) {
	int index = -1;
	while ((index = FindEntityByClassname(index, "prop_dynamic")) != -1) {
		//PrintToChatAll("Nail spotted!");
		if (GetEntPropEnt(index, Prop_Data, "m_hMoveParent") == iEnt) {
			AcceptEntityInput(index, "Kill");
			g_bPropNailed[iEnt] = false;
			PrintToChatAll("Nail Index:%d, Nail parented to :%d", index, iEnt);
		}
		//PrintToChatAll("Nail removed!");
	}
}
*/

public bool TraceRayDontHitSelf(entity, mask, any:data)
{
	if (entity == data) // Check if the TraceRay hit the owning entity.
	{
		return false; // Don't let the entity be hit
	}
	
	return true; // It didn't hit itself
}
public Action UpdateObjects(Handle timer)

{
	float vecDir[3]; float vecPos[3]; float vecVel[3]; // vectors
	float viewang[3]; // angles
	int i;
	float distance = 80.0;
	for (i = 0; i < MAXPLAYERS; i++)
	{
		if (IsValidClient(i) && IsClientInGame(i)) {
			if (g_pGrabbedEnt[i] > 0)
			{
				if (IsValidEdict(g_pGrabbedEnt[i]) && IsValidEntity(g_pGrabbedEnt[i]))
				{
					// get client info
					GetClientEyeAngles(i, viewang);
					GetAngleVectors(viewang, vecDir, NULL_VECTOR, NULL_VECTOR);
					GetClientEyePosition(i, vecPos);
					
					// update object 
					vecPos[0] += vecDir[0] * distance;
					vecPos[1] += vecDir[1] * distance;
					vecPos[2] += vecDir[2] * distance;
					
					GetEntPropVector(g_pGrabbedEnt[i], Prop_Send, "m_vecOrigin", vecDir);
					
					SubtractVectors(vecPos, vecDir, vecVel);
					ScaleVector(vecVel, 10.0);
					
					TeleportEntity(g_pGrabbedEnt[i], NULL_VECTOR, NULL_VECTOR, vecVel);
					g_bPropBeingHeld[i] = true;
				}
				else
				{
					g_bPropBeingHeld[i] = false;
					g_pGrabbedEnt[i] = -1;
				}
				
			}
		}
	}
	
	return Plugin_Continue;
}
stock bool IsValidClient(client, bool nobots = true)
{
	if (client <= 0 || client > MaxClients || !IsClientConnected(client) || (nobots && IsFakeClient(client)))
	{
		return false;
	}
	return IsClientInGame(client);
}
zombimod()
{
	g_iMapPrefixType = 0;
	char mapv[32];
	GetCurrentMap(mapv, sizeof(mapv));
	if (!StrContains(mapv, "zf_", false)) {
		g_iMapPrefixType = 1;
	}
	else if (!StrContains(mapv, "szf_", false)) {
		g_iMapPrefixType = 2;
	}
	else if (!StrContains(mapv, "zm_", false)) {
		g_iMapPrefixType = 3;
	}
	else if (!StrContains(mapv, "zom_", false)) {
		g_iMapPrefixType = 4;
	}
	else if (!StrContains(mapv, "zs_", false)) {
		g_iMapPrefixType = 5;
	}
	else if (!StrContains(mapv, "ze_", false)) {
		g_iMapPrefixType = 6;
		PrintToServer("\n\n\n\n      ZOMBIE ESCAPE MOD ON \n\n\n");
	}
	
	if (g_iMapPrefixType == 1)
		PrintToServer("\n\n\n      Great :) Found Map Prefix == ['ZF']\n\n\n");
	else if (g_iMapPrefixType == 2)
		PrintToServer("\n\n\n      Great :) Found Map Prefix == ['SZF']\n\n\n");
	else if (g_iMapPrefixType == 3)
		PrintToServer("\n\n\n      Great :) Found Map Prefix == ['ZM']zf\n\n\n");
	else if (g_iMapPrefixType == 4)
		PrintToServer("\n\n\n      Great :) Found Map Prefix == ['ZOM']\n\n\n");
	else if (g_iMapPrefixType == 5)
		PrintToServer("\n\n\n      Great :) Found Map Prefix ['ZS']\n\n\n");
	else if (g_iMapPrefixType == 6)
		PrintToServer("\n\n\n      Great :) Found Map Prefix ['ZE']\n\n\n");
	else if (g_iMapPrefixType > 0) {
		if (g_iMapPrefixType != 6) {
		}
	}
	else if (g_iMapPrefixType == 0) {
		PrintToServer("\n\n           ********WARNING!********     \n\n\n ***Zombie Map Recommended Current [MAPNAME] = [%s]***\n\n\n", mapv);
	}
}
logGameRuleTeamRegister() {  //Registers the Team indexes (Most likely usage for OnMapStart() )
	if (g_iMapPrefixType == 1 || g_iMapPrefixType == 2) {
		g_iZomTeamIndex = 3; //We'll set Blue team as a zombie for those maps
		g_iHumTeamIndex = 2; //We'll set Red team as a human for those maps
		PrintToServer("\nGame Rules Changed, Zombie team is Blue, Human team is Red\n");
	} //If the map is ZF or ZM 
	else if (g_iMapPrefixType == 3 || g_iMapPrefixType == 4 || g_iMapPrefixType == 5 || g_iMapPrefixType == 6) {
		g_iZomTeamIndex = 2; //We'll set Red team as a zombie for those maps
		g_iHumTeamIndex = 3; //We'll set Blue team as a zombie for those maps
		PrintToServer("\nGame Rules Changed, Zombie team is Red, Human team is Blue\n");
	} // If the map is ZM, ZS, ZOM, ZE
}

stock bool IsStuckInEnt(client, ent) {
	float vecMin[3]; float vecMax[3]; float vecOrigin[3];
	
	GetClientMins(client, vecMin);
	GetClientMaxs(client, vecMax);
	
	GetClientAbsOrigin(client, vecOrigin);
	
	TR_TraceHullFilter(vecOrigin, vecOrigin, vecMin, vecMax, MASK_ALL, TraceRayDontHitPlayerAndWorld, ent);
	return TR_DidHit();
}

public bool TraceRayDontHitPlayerAndWorld(entityhit, mask) {
	return entityhit > MaxClients;
} 