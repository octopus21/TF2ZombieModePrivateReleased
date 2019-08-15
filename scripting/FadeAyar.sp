#pragma semicolon 1

#define DEBUG

#define PLUGIN_AUTHOR "Devil"
#define PLUGIN_VERSION "0.01"

#define TRACE_START 24.0
#define TRACE_END 64.0

#define MDL_LASER "sprites/laser.vmt"

#define SND_MINEPUT "npc/roller/blade_cut.wav"
#define SND_MINEACT "npc/roller/mine/rmine_blades_in2.wav"

#define FFADE_IN            (0x0001)        // Just here so we don't pass 0 into the function
#define FFADE_OUT           (0x0002)        // Fade out (not in)
#define FFADE_MODULATE      (0x0004)        // Modulate (don't blend)
#define FFADE_STAYOUT       (0x0008)        // ignores the duration, stays faded out until new ScreenFade message received
#define FFADE_PURGE         (0x0010)        // Purges all other fades, replacing them with this one

#include <sourcemod>
#include <sdktools>
#include <tf2>
#include <tf2_stocks>
#include <sdkhooks>

new clientTimer[MAXPLAYERS + 1];
new Handle:g_hTimer12 = INVALID_HANDLE;

new g_iTekSefer[MAXPLAYERS + 1] = 0;
new bool:g_bZombi[MAXPLAYERS + 1];

//Status
new bool:g_bStatusKor[MAXPLAYERS + 1];
new bool:g_bStatusJarate[MAXPLAYERS + 1];
new bool:g_bStatusBleed[MAXPLAYERS + 1];
new bool:g_bStatusManOWar[MAXPLAYERS + 1];
new bool:g_bSlowness[MAXPLAYERS + 1];

//DemiBossProgress 
new g_iDemiBossProgress[MAXPLAYERS + 1] = 0;
new g_iKillsAsZombi[MAXPLAYERS + 1] = 0;
new g_iKillsAsHuman[MAXPLAYERS + 1] = 0;

int gCount = 1;

#define COLOR_B "0 0 255"

//



#define ambience_1 "slender/intro.mp3" 

new UserMsg:g_FadeUserMsgId;

public Plugin:myinfo = 
{
	name = "", 
	author = PLUGIN_AUTHOR, 
	description = "", 
	version = PLUGIN_VERSION, 
	url = ""
};
public OnMapStart() {
	PrecacheSound(ambience_1, true);
	//new client = GetClientOfUserId(client);
	g_iTekSefer[MAXPLAYERS] = 0; // Her harita yüklendiğinde oyuncuların değerleri 0 olsun
	ClearTimer(g_hTimer12);
	PrecacheModel("models/props_lab/tpplug.mdl", true);
	PrecacheModel(MDL_LASER, true);
	
	PrecacheSound(SND_MINEPUT, true);
	PrecacheSound(SND_MINEACT, true);
}
public OnMapEnd() {
	g_iTekSefer[MAXPLAYERS] = 0;
}
public OnClientPutInServer(client) {
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}
public OnPluginStart()
{
	HookEvent("player_spawn", spawn);
	HookEvent("player_death", death);
	HookEvent("teamplay_round_start", OnRound);
	HookEvent("player_hurt", HookPlayerHurt);
	g_FadeUserMsgId = GetUserMessageId("Fade");
	AddCommandListener(Listener_Voice, "voicemenu");
	
	RegConsoleCmd("sm_test", Test);
}
public OnClientDisconnect(client) {
	g_iTekSefer[client] = 0;
	g_iDemiBossProgress[client] = 0;
}
public OnClientConnected(client) {
	g_iTekSefer[client] = 0;
	g_iDemiBossProgress[client] = 0;
}
public Action:Test(client, args)
{
	//g_iTekSefer[client] = 0;
	PrintToChat(client, "Slender Ambience:%d", g_iTekSefer[client]);
	PrintToChat(client, "DemiBoss: %d", g_iDemiBossProgress[client]);
	SetMine(client);
}
public Action:OnRound(Handle:event, const String:name[], bool:dontBroadcast)
{
	
}
public Action:HookPlayerHurt(Handle:hEvent, const String:name[], bool:dontBroadcast) {
	new client = GetClientOfUserId(GetEventInt(hEvent, "userid")); //victim
	new attacker = GetClientOfUserId(GetEventInt(hEvent, "attacker"));
	if (client != attacker) {
		if (g_bZombi[attacker] && !g_bZombi[client]) {
			g_iDemiBossProgress[attacker] = g_iDemiBossProgress[attacker] + 10;
			PerformHudMsg(attacker, -1.0, 0.40, "☠ Demiboss Progress ☠");
			PrintToChat(attacker, " %: %d", g_iDemiBossProgress[attacker]);
		}
	}
	
	if (g_iDemiBossProgress[attacker] > 100) {
		g_iDemiBossProgress[attacker] = 100; //100 ü geçmesin.
	}
}
public Action:Listener_Voice(client, const String:command[], argc) {
	decl String:arguments[4];
	GetCmdArgString(arguments, sizeof(arguments));
	if (StrEqual(arguments, "0 0")) {
		if (GetClientTeam(client) == 3) {
			SetClientOverlay(client, "effects/tp_refract");
		}
	} else {
		SetClientOverlay(client, " ");
		return Plugin_Continue;
	}
	return Plugin_Continue;
}
public Action:death(Handle:event, const String:name[], bool:dontBroadcast)
{
	new killed = GetClientOfUserId(GetEventInt(event, "userid"));
	new killer = GetClientOfUserId(GetEventInt(event, "attacker"));
	
	if (g_iKillsAsZombi[killer] > 5) {
		g_iDemiBossProgress[killer] = g_iDemiBossProgress[killer] + 15;
	}
	
	if (killed != killer) {
		if (g_bZombi[killer]) {
			g_iKillsAsZombi[killer]++;
		} else {
			g_iKillsAsHuman[killer]++;
		}
	}
}
public Action:spawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	GetZombiStatus(client);
	
	if (g_bZombi[client]) {
		//Balance Update 12.08.2019
		if (ZombiSayisi() <= InsanSayisi()) {
			
		} //Zombilerin sayısı insanların sayısından küçük eşit ise status eklemesi yapabiliriz.
		PrintToChat(client, "\x07696969[ \x07A9A9A9ZF \x07696969]\x07CCCCCCPress 'e' to activate zombie vision");
		//SetClientOverlay(client, "effects/tp_refract");
	}
	else if (!g_bZombi[client] && IsValidEntity(client) && client > 0) {
		g_iTekSefer[client]++;
		PrintToChat(client, "%d", g_iTekSefer[client]);
		SetClientOverlay(client, " ");
		if (g_iTekSefer[client] <= 2) {
			PerformFade(client, 500, { 0, 0, 0, 255 } );
			PerformHudMsg(client, -1.0, 0.40, "☠ Virus is out of control! One of the humans will be Zombie! ☠");
			EmitSoundToClient(client, ambience_1);
			clientTimer[client] = CreateTimer(10.0, timer_Fade, client, TIMER_FLAG_NO_MAPCHANGE);
		}
	}
}
public Action:timer_Fade(Handle:timer, any:client) {
	//PerformFade(client, 500, { 0, 0, 0, 0 } );
	//new Float:cSpeed = GetEntPropFloat(client, Prop_Send, "m_flMaxspeed");
	if (IsValidEntity(client) && client > 0) {
		PerformFade(client, 500, { 0, 0, 0, 0 } );
		SetClientOverlay(client, " ");
		TF2_StunPlayer(client, 0.0, 0.0, TF_STUNFLAG_SLOWDOWN);
	}
}
public Action:OnTakeDamage(victim, &attacker, &inflictor, &Float:damage, &damagetype)
{
	//Stats Apply
	g_bStatusKor[victim] = false;
	g_bStatusJarate[victim] = false;
	g_bStatusBleed[victim] = false;
	g_bStatusManOWar[victim] = false;
	g_bSlowness[victim] = false;
	
	if (!IsValidEntity(attacker)) {
		return Plugin_Continue;
	}
	
	if (victim == attacker) {
		return Plugin_Continue;
	}
	
	new silahId;
	(attacker == inflictor) ? (silahId = ClientWeapon(attacker)) : (silahId = inflictor);
	
	if (IsValidEntity(silahId) && g_bZombi[attacker]) {
		decl String:sWeapon[80];
		GetEntityClassname(silahId, sWeapon, 32);
		if (StrEqual(sWeapon, "tf_weapon_bat_wood") && GetWeaponIndex(silahId) == 44) {
			g_bStatusKor[victim] = true; // Kör Statüsü etkinleştir.
			g_bSlowness[victim] = true; //Slowness statüsünü etkinleştir
		}
		else if (StrEqual(sWeapon, "tf_weapon_club")) {
			g_bStatusJarate[victim] = true; // Jarate status
			g_bSlowness[victim] = true; // Slowness  status
		} // Bütün sniper meleelerinde etkinleştirelim.
	}
	
	if (g_bStatusKor[victim]) {
		PerformHudMsg(victim, -1.0, 0.40, "☠ You're targetted by Zombie Bat // You'll be blind for the next 3 secs. ☠");
		PerformFade(victim, 500, { 0, 0, 0, 255 } );
		clientTimer[victim] = CreateTimer(3.0, timer_Fade, victim, TIMER_FLAG_NO_MAPCHANGE);
	}
	if (g_bStatusJarate[victim]) {
		PerformHudMsg(victim, -1.0, 0.40, "☠ You're targetted by Zombie Sniper // You'll be jarated for the next 6 secs. ☠");
		SetClientOverlay(victim, "effects/tp_refract");
		//FakeClientCommand(victim, "addcond 23");
		TF2_AddCondition(victim, TFCond:TFCond_Jarated, 6.0, 0);
		clientTimer[victim] = CreateTimer(6.0, timer_Fade, victim, TIMER_FLAG_NO_MAPCHANGE);
	}
	if (g_bSlowness[victim]) {
		PrintToChat(victim, "\x07696969[ \x07A9A9A9ZF \x07696969]\x07CCCCCCYou're slowed due to damage intake from a zombie.");
		TF2_AddCondition(victim, TFCond_Slowed, float(3));
		//SetEntPropFloat(victim, Prop_Send, "m_flMaxspeed", 80.0);
		clientTimer[victim] = CreateTimer(1.0, timer_Fade, victim, TIMER_FLAG_NO_MAPCHANGE);
	}
	return Plugin_Continue;
}
SetClientOverlay(client, String:strOverlay[])
{
	new iFlags = GetCommandFlags("r_screenoverlay") & (~FCVAR_CHEAT);
	SetCommandFlags("r_screenoverlay", iFlags);
	
	ClientCommand(client, "r_screenoverlay \"%s\"", strOverlay);
}
BlindPlayer(client, iAmount)
{
	new iTargets[2];
	iTargets[0] = client;
	
	new Handle:message = StartMessageEx(g_FadeUserMsgId, iTargets, 1);
	BfWriteShort(message, 1536);
	BfWriteShort(message, 1536);
	
	if (iAmount == 0) {
		BfWriteShort(message, (0x0001 | 0x0010));
	} else {
		BfWriteShort(message, (0x0002 | 0x0008));
	}
	
	BfWriteByte(message, 0);
	BfWriteByte(message, 0);
	BfWriteByte(message, 0);
	BfWriteByte(message, iAmount);
	
	EndMessage();
}

PerformFade(client, duration, const color[4]) {
	new Handle:hFadeClient = StartMessageOne("Fade", client);
	BfWriteShort(hFadeClient, duration); // FIXED 16 bit, with SCREENFADE_FRACBITS fractional, milliseconds duration
	BfWriteShort(hFadeClient, 0); // FIXED 16 bit, with SCREENFADE_FRACBITS fractional, milliseconds duration until reset (fade & hold)
	BfWriteShort(hFadeClient, (FFADE_PURGE | FFADE_OUT | FFADE_STAYOUT)); // fade type (in / out)
	BfWriteByte(hFadeClient, color[0]); // fade red
	BfWriteByte(hFadeClient, color[1]); // fade green
	BfWriteByte(hFadeClient, color[2]); // fade blue
	BfWriteByte(hFadeClient, color[3]); // fade alpha
	EndMessage();
}

PerformHudMsg(client, x, y, const String:szMsg[]) {
	new Handle:hBf = StartMessageOne("HudMsg", client);
	BfWriteByte(hBf, 3); //channel
	BfWriteFloat(hBf, x); // -1.0 x ( -1 = center )
	BfWriteFloat(hBf, y); // 0.40 y ( -1 = center )
	// second color
	BfWriteByte(hBf, 255); //r1
	BfWriteByte(hBf, 0); //g1
	BfWriteByte(hBf, 0); //b1
	BfWriteByte(hBf, 255); //a1 // transparent?
	// init color
	BfWriteByte(hBf, 255); //r2
	BfWriteByte(hBf, 0); //g2
	BfWriteByte(hBf, 0); //b2
	BfWriteByte(hBf, 255); //a2
	BfWriteByte(hBf, 0); //effect (0 is fade in/fade out; 1 is flickery credits; 2 is write out)
	BfWriteFloat(hBf, 1.0); //fadeinTime (message fade in time - per character in effect 2)
	BfWriteFloat(hBf, 1.0); //fadeoutTime
	BfWriteFloat(hBf, 8.0); //holdtime
	BfWriteFloat(hBf, 5.0); //fxtime (effect type(2) used)
	BfWriteString(hBf, szMsg); //Message
	EndMessage();
}
stock ClearTimer(&Handle:hTimer)
{
	if (hTimer != INVALID_HANDLE)
	{
		KillTimer(hTimer);
		hTimer = INVALID_HANDLE;
	}
}

ZombiSayisi() {
	new client = GetClientOfUserId(client);
	new num;
	new g_iZombi[MAXPLAYERS + 1];
	for (new i = 1; i <= MaxClients; i++) {
		if (IsValidEntity(i) && IsClientConnected(i) && GetClientTeam(i) == 3) {
			g_iZombi[num++] = i;
		}
	}
	return (num == 0) ? 0 : g_iZombi[num];
}
InsanSayisi() {
	new client = GetClientOfUserId(client);
	new num;
	new g_iNsan[MAXPLAYERS + 1];
	for (new i = 1; i <= MaxClients; i++) {
		if (IsValidEntity(i) && IsClientConnected(i) && GetClientTeam(i) == 2) {
			g_iNsan[num++] = i;
		}
	}
	return (num == 0) ? 0 : g_iNsan[num];
}
GetZombiStatus(client) {
	if (GetClientTeam(client) == 3) {
		g_bZombi[client] = true;
	} else {
		g_bZombi[client] = false;
	}
}
stock GetWeaponIndex(iWeapon)
{
	return IsValidEntity(iWeapon) ? GetEntProp(iWeapon, Prop_Send, "m_iItemDefinitionIndex"):-1;
}
stock ClientWeapon(client)
{
	return GetWeaponIndex(GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon"));
	//return GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
}

/*
stock GetIndexOfWeaponSlot(iClient, iSlot)
{
    return GetWeaponIndex(GetPlayerWeaponSlot(iClient, iSlot));
}

stock GetClientCloakIndex(iClient)
{
    return GetWeaponIndex(GetPlayerWeaponSlot(iClient, TFWeaponSlot_Watch));
}

stock GetWeaponIndex(iWeapon)
{
    return IsValidEnt(iWeapon) ? GetEntProp(iWeapon, Prop_Send, "m_iItemDefinitionIndex"):-1;
}

stock GetActiveIndex(iClient)
{
    return GetWeaponIndex(GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon"));
}

stock bool:IsWeaponSlotActive(iClient, iSlot)
{
    return GetPlayerWeaponSlot(iClient, iSlot) == GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon");
}

stock bool:IsIndexActive(iClient, iIndex)
{
    return iIndex == GetWeaponIndex(GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon"));
}

stock bool:IsSlotIndex(iClient, iSlot, iIndex)
{
    return iIndex == GetIndexOfWeaponSlot(iClient, iSlot);
}

stock bool:IsValidEnt(iEnt)
{
    return iEnt > MaxClients && IsValidEntity(iEnt);
}

stock GetSlotFromPlayerWeapon(iClient, iWeapon)
{
    for (new i = 0; i <= 5; i++)
    {
        if (iWeapon == GetPlayerWeaponSlot(iClient, i))
        {
            return i;
        }
    }
    return -1;
}  
*/


void SetMine(int client)
{
	// setup unique target names for entities to be created with
	char beam[64];
	char beammdl[64];
	char tmp[128];
	
	Format(beam, sizeof(beam), "tmbeam%d", gCount);
	Format(beammdl, sizeof(beammdl), "tmbeammdl%d", gCount);
	
	gCount++;
	if (gCount > 10000)
	{
		gCount = 1;
	}
	
	// trace client view to get position and angles for tripmine
	
	float start[3];
	float angle[3];
	float end[3];
	float normal[3];
	float beamend[3];
	GetClientEyePosition(client, start);
	GetClientEyeAngles(client, angle);
	GetAngleVectors(angle, end, NULL_VECTOR, NULL_VECTOR);
	NormalizeVector(end, end);

	start[0]=start[0]+end[0]*TRACE_START;
	start[1]=start[1]+end[1]*TRACE_START;
	start[2]=start[2]+end[2]*TRACE_START;
	
	end[0]=start[0]+end[0]*TRACE_END*10;
	end[1]=start[1]+end[1]*TRACE_END*10;
	end[2]=start[2]+end[2]*TRACE_END*10;
	
	TR_TraceRayFilter(start, end, CONTENTS_SOLID, RayType_EndPoint, FilterAll, 0);
	
	if (TR_DidHit(null))
	{
		// update client's inventory
		
		// Find angles for tripmine
		TR_GetEndPosition(end, null);
		TR_GetPlaneNormal(null, normal);
		GetVectorAngles(normal, normal);
		
		// Trace laser beam
		TR_TraceRayFilter(end, normal, CONTENTS_SOLID, RayType_Infinite, FilterAll, 0);
		TR_GetEndPosition(beamend, null);
		
		// Create tripmine model
		int ent = CreateEntityByName("prop_dynamic_override");
		SetEntityModel(ent, "models/props_lab/tpplug.mdl");
		DispatchKeyValue(ent, "StartDisabled", "false");
		DispatchSpawn(ent);
		TeleportEntity(ent, end, normal, NULL_VECTOR);
		SetEntProp(ent, Prop_Data, "m_usSolidFlags", 152);
		SetEntProp(ent, Prop_Data, "m_CollisionGroup", 1);
		SetEntityMoveType(ent, MOVETYPE_NONE);
		SetEntProp(ent, Prop_Data, "m_MoveCollide", 0);
		SetEntProp(ent, Prop_Data, "m_nSolidType", 6);
		SetEntPropEnt(ent, Prop_Data, "m_hLastAttacker", client);
		DispatchKeyValue(ent, "targetname", beammdl);
		DispatchKeyValue(ent, "ExplodeRadius", "256");
		DispatchKeyValue(ent, "ExplodeDamage", "400");
		Format(tmp, sizeof(tmp), "%s,Break,,0,-1", beammdl);
		DispatchKeyValue(ent, "OnHealthChanged", tmp);
		Format(tmp, sizeof(tmp), "%s,Kill,,0,-1", beam);
		DispatchKeyValue(ent, "OnBreak", tmp);
		SetEntProp(ent, Prop_Data, "m_takedamage", 2);
		AcceptEntityInput(ent, "Enable");
		HookSingleEntityOutput(ent, "OnBreak", mineBreak, true);

		
		// Create laser beam
		int ent2 = CreateEntityByName("env_beam");
		TeleportEntity(ent2, beamend, NULL_VECTOR, NULL_VECTOR);
		SetEntityModel(ent2, MDL_LASER);
		DispatchKeyValue(ent2, "texture", MDL_LASER);
		DispatchKeyValue(ent2, "targetname", beam);
		DispatchKeyValue(ent2, "TouchType", "4");
		DispatchKeyValue(ent2, "LightningStart", beam);
		DispatchKeyValue(ent2, "BoltWidth", "4.0");
		DispatchKeyValue(ent2, "life", "0");
		DispatchKeyValue(ent2, "rendercolor", "0 0 0");
		DispatchKeyValue(ent2, "renderamt", "0");
		DispatchKeyValue(ent2, "HDRColorScale", "1.0");
		DispatchKeyValue(ent2, "decalname", "Bigshot");
		DispatchKeyValue(ent2, "StrikeTime", "0");
		DispatchKeyValue(ent2, "TextureScroll", "35");
		Format(tmp, sizeof(tmp), "%s,Break,,0,-1", beammdl);
		DispatchKeyValue(ent2, "OnTouchedByEntity", tmp);	 
		SetEntPropVector(ent2, Prop_Data, "m_vecEndPos", end);
		SetEntPropFloat(ent2, Prop_Data, "m_fWidth", 4.0);
		AcceptEntityInput(ent2, "TurnOff");

		// Create a datapack
		DataPack hData = new DataPack();
		CreateTimer(2.0, TurnBeamOn, hData);
		hData.WriteCell(client);
		hData.WriteCell(ent);
		hData.WriteCell(ent2);
		hData.WriteFloat(end[0]);
		hData.WriteFloat(end[1]);
		hData.WriteFloat(end[2]);
		
		// Play sound
		EmitSoundToAll(SND_MINEPUT, ent, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, SNDVOL_NORMAL, 100, ent, end, NULL_VECTOR, true, 0.0);
		// Update remaining tripmine count
	}
	else
	{
		PrintHintText(client, "Invalid location for Tripmine");
	}
}

public Action TurnBeamOn(Handle timer, DataPack hData)
{
	char color[26];

	hData.Reset();
	int client = hData.ReadCell();
	int ent = hData.ReadCell();
	int ent2 = hData.ReadCell();

	if (IsValidEntity(ent))
	{
		// To Do: Game-based team checks and handling.
		DispatchKeyValue(ent2, "rendercolor", "0 0 255");
		AcceptEntityInput(ent2, "TurnOn");

		float end[3];
		end[0] = hData.ReadFloat();
		end[1] = hData.ReadFloat();
		end[2] = hData.ReadFloat();
		EmitSoundToAll(SND_MINEACT, ent, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, SNDVOL_NORMAL, 100, ent, end, NULL_VECTOR, true, 0.0);

	}

	delete hData;
}

public void mineBreak(const char[] output, int caller, int activator, float delay)
{
	UnhookSingleEntityOutput(caller, "OnBreak", mineBreak);
	AcceptEntityInput(caller,"kill");
}

public bool FilterAll(int entity, int contentsMask)
{
	return false;
}