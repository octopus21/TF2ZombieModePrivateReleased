#pragma semicolon 1

#define DEBUG

#define PLUGIN_AUTHOR "Devil"
#define PLUGIN_VERSION "1.11"

#define TRACE_START 24.0
#define TRACE_END 64.0

#define MDL_LASER "sprites/laser.vmt"

#define SND_MINEPUT "npc/roller/blade_cut.wav" //Sound Of the Laser Mine OnPut
#define SND_MINEACT "npc/roller/mine/rmine_blades_in2.wav"//Sound Of the Laser Mine OnActivate
#define SND_ZOMBIDLE01 "npc/zombie/zombie_voice_idle1.wav"//Sound Of the Player That uses VoiceMenu
#define SND_ZOMBIDLE02 "npc/zombie/zombie_voice_idle5.wav"//Sound Of the Player That uses VoiceMenu
#define SND_BARNACLE01 "npc/barnacle/barnacle_bark1.wav"
#define MDL_ZOMBIE "models/zombie/classic.mdl"

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
//#include <vaultuser> => My Stock, probably use it later.

new Handle:clientTimer[MAXPLAYERS + 1];
new Handle:g_hTimer12 = INVALID_HANDLE;

new g_iTekSefer[MAXPLAYERS + 1] =  { 0, ... };

//Status
new bool:g_bStatusKor[MAXPLAYERS + 1]; //Status for blindness(Applies on client)
new bool:g_bStatusJarate[MAXPLAYERS + 1]; //Status for Jarated effect(Applies on client)
new bool:g_bStatusBleed[MAXPLAYERS + 1]; //Status for Bleed effect(Applies on client)
new bool:g_bStatusManOWar[MAXPLAYERS + 1]; //Status for ManOWar effect(Applies on client)
new bool:g_bSlowness[MAXPLAYERS + 1]; //Status for Slowness effect(Applies on client)

//DemiBossProgress
new g_iDemiBossProgress[MAXPLAYERS + 1] =  { 0, ... }; //Zombie Credits
new g_iHumanCreditProgress[MAXPLAYERS + 1] =  { 0, ... }; //Human Credits
new g_iKillsAsZombi[MAXPLAYERS + 1] =  { 0, ... };
new g_iKillsAsHuman[MAXPLAYERS + 1] =  { 0, ... };

new bool:g_bMine[2048] = false; //Checks if the attack done by a mine (Not used)
new g_iHumTeamIndex;
new g_iZomTeamIndex;
new g_iMapPrefixType; //Stores the integer that was given by a map prefixes For example zf = 1, szf = 2 ...
//new bool:g_bMineDamage[MAXPLAYERS + 1] = false;
new g_iNailedTimes[MAXPLAYERS + 1] =  { 0, ... };

int gCount = 1; //Do not touch this

int g_iMineCount[MAXPLAYERS + 1] =  { 0, ... }; //Mine count for client
#define COLOR_B "0 0 255"

//



#define ambience_1 "slender/intro.mp3" //lol

//new UserMsg:g_FadeUserMsgId;

public Plugin:myinfo = 
{
	name = "Secondary Stocks / Handles", 
	author = PLUGIN_AUTHOR, 
	description = "", 
	version = PLUGIN_VERSION, 
	url = ""
};
public OnMapStart() {
	PrecacheSound(ambience_1, true);
	//new client = GetClientOfUserId(client);
	//g_iTekSefer[MAXPLAYERS] = 0; // Her harita yüklendiğinde oyuncuların değerleri 0 olsun
	ClearTimer(g_hTimer12);
	PrecacheModel("models/props_lab/tpplug.mdl", true);
	//PrecacheModel("models/props_farm/wooden_barrel.mdl", true);
	PrecacheModel("models/props_c17/concrete_barrier001a.mdl", true);
	PrecacheModel(MDL_LASER, true);
	PrecacheModel(MDL_ZOMBIE, true);
	//PrecacheModel("models/props_debris/wood_board05a.mdl", true);
	
	PrecacheSound(SND_MINEPUT, true);
	PrecacheSound(SND_MINEACT, true);
	PrecacheSound(SND_ZOMBIDLE01, true);
	PrecacheSound(SND_ZOMBIDLE02, true);
	PrecacheSound(SND_BARNACLE01, true);
	//g_iMineCount[MAXPLAYERS] = 0;
	//g_iHumanCreditProgress[MAXPLAYERS] = 0;
	zombimod();
	logGameRuleTeamRegister();
	//zombimod();
}
public OnMapEnd() {
	//g_iTekSefer[MAXPLAYERS] = {0, ...};
	//g_iHumanCreditProgress[MAXPLAYERS] = {0, ...};
}
public OnClientPutInServer(client) {
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
	g_iMineCount[client] = 0; //We set mine count for the client index to 0 when client put in server
	g_iHumanCreditProgress[client] = 0; //We set Credits for the client index to 0 when client put in server
	g_iNailedTimes[client] = 0;
}
public OnPluginStart()
{
	HookEvent("player_spawn", spawn);
	HookEvent("player_death", death);
	HookEvent("teamplay_round_start", OnRound);
	HookEvent("player_hurt", HookPlayerHurt);
	//g_FadeUserMsgId = GetUserMessageId("Fade");
	AddCommandListener(Listener_Voice, "voicemenu");
	
	RegConsoleCmd("sm_shop", Test);
	RegConsoleCmd("sm_market", Test);
	RegConsoleCmd("sm_gears", Test);
	RegConsoleCmd("sm_prop", Prop);
	
	LoadTranslations("tf2zombiemodvs.phrases");
}
public OnAutoConfigsBuffered() //After the server.cfg has loaded
{
	SetConVarInt(FindConVar("tf_allow_player_use"), 1);
}
public OnClientDisconnect(client) {
	g_iTekSefer[client] = 0; //We set the spawn times for 0
	g_iDemiBossProgress[client] = 0; //We set the Zombie credits to 0
	g_iMineCount[client] = 0; //We set mine count to the 0
	g_iHumanCreditProgress[client] = 0; //Human credits are 0 now cuz you'Re disconnected, fool..
	g_iNailedTimes[client] = 0;
}
public OnClientConnected(client) {
	g_iTekSefer[client] = 0;
	g_iDemiBossProgress[client] = 0;
	g_iMineCount[client] = 0;
	g_iHumanCreditProgress[client] = 0;
	g_iNailedTimes[client] = 0;
}
public Action:Prop(client, args) {
	SetProp(client);
}
public Action:Test(client, args)
{
	//Shop
	if (GetClientTeam(client) == g_iHumTeamIndex) {  // => This one here for Human Market
		Menu shop = new Menu(zombishop);
		shop.SetTitle("Human Market! [Credits:%d]", g_iHumanCreditProgress[client]);
		shop.AddItem("1", "LaserMine => [25  Credits]");
		shop.ExitButton = true;
		shop.Display(client, 100);
	} else if (GetClientTeam(client) == g_iZomTeamIndex) {  // => This one here for Zombie Market
		Menu shopZom = new Menu(zomshop);
		shopZom.SetTitle("Zombi Market! [DemiBoss Credits: %d]", g_iDemiBossProgress[client]);
		shopZom.AddItem("1", "Speed Boost for 15 secs => [5 Credits]");
		shopZom.AddItem("2", "Crit Boost for 10 secs => [10 Credits]");
		shopZom.AddItem("3", "Be Boss! => [100 Credits]");
		shopZom.ExitButton = true;
		shopZom.Display(client, 100);
	}
}
//Human Shop
//Human Credits = g_iHumanCreditProgress
public zombishop(Handle menu, MenuAction action, client, item)
{
	if (action == MenuAction_Select)
	{
		switch (item) {
			case 0: {
				if (g_iHumanCreditProgress[client] >= 25) {
					g_iHumanCreditProgress[client] = g_iHumanCreditProgress[client] - 25;
					if (g_iMineCount[client] < 15) {
						if (GetClientTeam(client) == g_iHumTeamIndex) {
							SetMine(client);
						} else if (GetClientTeam(client) == g_iZomTeamIndex) {
							PrintToChat(client, "\x07696969[ \x07A9A9A9ZF \x07696969]\x07CCCCCC %t", "Zombies can't place mines");
						}
					} else {
						PrintToChat(client, "\x07696969[ \x07A9A9A9ZF \x07696969]\x07CCCCCC %t", "Mine limit is reached");
					}
				} else {
					PrintToChat(client, "\x07696969[ \x07A9A9A9ZF \x07696969]\x07CCCCCC %t", "Not enough credits to buy this item");
				}
			}
		}
		
	} else if (action == MenuAction_End) {
		CloseHandle(menu);
	}
}
//Zombie Shop
//Zombie Credits = g_iDemiBossProgress
public zomshop(Handle menu, MenuAction action, client, item)
{
	if (action == MenuAction_Select)
	{
		switch (item) {
			case 0: {
				if (g_iDemiBossProgress[client] >= 5) {
					g_iDemiBossProgress[client] = g_iDemiBossProgress[client] - 5;
					if (GetClientTeam(client) == g_iZomTeamIndex) {
						TF2_AddCondition(client, TFCond_SpeedBuffAlly);
						clientTimer[client] = CreateTimer(15.0, timerConditionRemover, client, TIMER_FLAG_NO_MAPCHANGE);
					} else if (GetClientTeam(client) == g_iHumTeamIndex) {
						PrintToChat(client, "\x07696969[ \x07A9A9A9ZF \x07696969]\x07CCCCCC %t", "Humans can't apply for boosts");
					}
				} else {
					PrintToChat(client, "\x07696969[ \x07A9A9A9ZF \x07696969]\x07CCCCCC %t", "Not enough zombie credits");
				}
			}
			case 1: {
				PrintToChat(client, "\x07696969[ \x07A9A9A9ZF \x07696969]\x07CCCCCC %t", "Currently in progress You're credits returned");
			}
			case 2: {
				PrintToChat(client, "\x07696969[ \x07A9A9A9ZF \x07696969]\x07CCCCCCCurrently in progress. You're credits returned.");
			}
		}
	} else if (action == MenuAction_End) {
		CloseHandle(menu);
	}
}
public Action:timerConditionRemover(Handle:timer, any:client) {
	if (TF2_IsPlayerInCondition(client, TFCond_SpeedBuffAlly)) {
		TF2_RemoveCondition(client, TFCond_SpeedBuffAlly);
	}
}
public Action:OnRound(Handle:event, const String:name[], bool:dontBroadcast)
{
	PrintToChatAll("\x07696969[ \x07A9A9A9ZF \x07696969]\x07CCCCCC %t", "Zombie picking up ratio is  11,111");
}
public Action:HookPlayerHurt(Handle:hEvent, const String:name[], bool:dontBroadcast) {
	new client = GetClientOfUserId(GetEventInt(hEvent, "userid")); //victim
	new attacker = GetClientOfUserId(GetEventInt(hEvent, "attacker"));
	if (client != attacker) {
		if (GetClientTeam(attacker) == g_iZomTeamIndex) {
			g_iDemiBossProgress[attacker] = g_iDemiBossProgress[attacker] + 10;
			PerformHudMsg(attacker, -1.0, 0.40, 3.0, "☠ Demiboss Progress ☠ + 10");
			//PrintToChat(attacker, " : %d", g_iDemiBossProgress[attacker]);
		}
		else if (GetClientTeam(attacker) == g_iHumTeamIndex) {
			TF2_StunPlayer(client, 1.0, 0.6, TF_STUNFLAG_SLOWDOWN);
			g_iHumanCreditProgress[attacker] = g_iHumanCreditProgress[attacker] + 1;
			PerformHudMsg(attacker, -1.0, 0.40, 2.0, "☠ + 1 Credits ☠"); //-1.0 x, -1.0 y
		}
	}
	
	if (g_iDemiBossProgress[attacker] > 100) {
		g_iDemiBossProgress[attacker] = 100; //100 ü geçmesin.
	}
	if (g_iHumanCreditProgress[attacker] > 300) {
		g_iHumanCreditProgress[attacker] = 300;
	}
}
public Action:Listener_Voice(client, const String:command[], argc) {
	decl String:arguments[4];
	decl Float:flPos[3];
	GetClientAbsOrigin(client, flPos);
	GetCmdArgString(arguments, sizeof(arguments));
	if (StrEqual(arguments, "0 0")) {
		if (GetClientTeam(client) == g_iZomTeamIndex) {
			SetClientOverlay(client, " "); //effects/tp_refract
			//PerformFade(client, 500, { 0, 255, 0, 50 } );
			clientTimer[client] = CreateTimer(10.0, timer_Fade, client, TIMER_FLAG_NO_MAPCHANGE);
			EmitSoundToAll(SND_ZOMBIDLE01, client, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, SNDVOL_NORMAL, 100, client, flPos, NULL_VECTOR, true, 0.0);
			return Plugin_Handled; // continue || none
		}
	} else if (StrEqual(arguments, "0 1") || StrEqual(arguments, "0 2") || StrEqual(arguments, "0 3") || StrEqual(arguments, "0 4") || StrEqual(arguments, "0 5") || StrEqual(arguments, "0 6") || StrEqual(arguments, "0 7")) {
		if (GetClientTeam(client) == g_iZomTeamIndex) {
			EmitSoundToAll(SND_ZOMBIDLE02, client, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, SNDVOL_NORMAL, 100, client, flPos, NULL_VECTOR, true, 0.0);
			SetClientOverlay(client, " ");
			return Plugin_Handled; //continue
		}
	}
	return Plugin_Continue;
}
public Action:death(Handle:event, const String:name[], bool:dontBroadcast)
{
	new killed = GetClientOfUserId(GetEventInt(event, "userid"));
	new killer = GetClientOfUserId(GetEventInt(event, "attacker"));
	g_iNailedTimes[killed] = 0;
	if (g_iKillsAsZombi[killer] > 5) {
		g_iDemiBossProgress[killer] = g_iDemiBossProgress[killer] + 15;
	}
	
	if (killed != killer) {
		if (GetClientTeam(killer) == g_iZomTeamIndex) {
			g_iKillsAsZombi[killer]++;
		} else {
			g_iKillsAsHuman[killer]++;
			PerformHudMsg(killer, -1.0, 0.40, 2.0, "☠ + 15 Credits ☠");
			g_iHumanCreditProgress[killer] = g_iHumanCreditProgress[killer] + 15;
		}
	}
	g_iMineCount[killed] = 0;
}
public Action:spawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	g_iNailedTimes[client] = 0;
	//PrintToChatAll("\x07696969[ \x07A9A9A9ZF \x07696969]\x07CCCCCCZombie picking up ratio is : 11,111");
	if (GetClientTeam(client) == g_iZomTeamIndex) {
		//Balance Update 12.08.2019
		if (ZombiSayisi() <= InsanSayisi()) {
			
		} //Zombilerin sayısı insanların sayısından küçük eşit ise status eklemesi yapabiliriz.
		PrintToChat(client, "\x07696969[ \x07A9A9A9ZF \x07696969]\x07CCCCCC %t", "Press 'e' to scream");
		//SetClientOverlay(client, "effects/tp_refract");
	}
	else if (GetClientTeam(client) == g_iHumTeamIndex && IsValidEntity(client) && client > 0) {
		g_iTekSefer[client]++;
		PrintToChat(client, "%d", g_iTekSefer[client]);
		SetClientOverlay(client, " ");
		if (g_iTekSefer[client] <= 1) {
			PerformFade(client, 500, { 0, 0, 0, 255 } );
			PerformHudMsg(client, -1.0, 0.40, 8.0, "☠ Virus is out of control! One of the humans will be Zombie! ☠");
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
	//new clientsilahId;
	if (IsValidClient(attacker)) {
		//clientsilahId = ClientWeapon(attacker);
	}
	//(attacker == inflictor) ? (silahId = clientsilahId) : (silahId = inflictor);
	
	if (IsValidEntity(silahId) && GetClientTeam(attacker) == g_iZomTeamIndex && IsValidClient(attacker)) {
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
		PerformHudMsg(victim, -1.0, 0.40, 3.0, "☠ You're targetted by Zombie Bat // You'll be blind for the next 3 secs. ☠");
		PerformFade(victim, 500, { 255, 255, 255, 0 } );
		clientTimer[victim] = CreateTimer(3.0, timer_Fade, victim, TIMER_FLAG_NO_MAPCHANGE);
	}
	if (g_bStatusJarate[victim]) {
		PerformHudMsg(victim, -1.0, 0.40, 3.0, "☠ You're targetted by Zombie Sniper // You'll be jarated for the next 6 secs. ☠");
		//SetClientOverlay(victim, "effects/tp_refract");
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

PerformHudMsg(client, Float:x, Float:y, Float:duration, const String:szMsg[]) {
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
	BfWriteFloat(hBf, duration); //holdtime
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
	
	start[0] = start[0] + end[0] * TRACE_START;
	start[1] = start[1] + end[1] * TRACE_START;
	start[2] = start[2] + end[2] * TRACE_START;
	
	end[0] = start[0] + end[0] * TRACE_END * 10;
	end[1] = start[1] + end[1] * TRACE_END * 10;
	end[2] = start[2] + end[2] * TRACE_END * 10;
	
	TR_TraceRayFilter(start, end, CONTENTS_SOLID, RayType_EndPoint, FilterAll, 0);
	//g_iMineCount[client]++;
	
	if (TR_DidHit(null))
	{
		// update client's inventory
		g_iMineCount[client]++;
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
		DispatchKeyValue(ent, "ExplodeRadius", "62");
		DispatchKeyValue(ent, "ExplodeDamage", "550");
		Format(tmp, sizeof(tmp), "%s,Break,,0,-1", beammdl);
		DispatchKeyValue(ent, "OnHealthChanged", tmp);
		Format(tmp, sizeof(tmp), "%s,Kill,,0,-1", beam);
		DispatchKeyValue(ent, "OnBreak", tmp);
		SetEntProp(ent, Prop_Data, "m_takedamage", 2);
		AcceptEntityInput(ent, "Enable");
		HookSingleEntityOutput(ent, "OnBreak", mineBreak, true);
		//HookSingleEntityOutput(ent, "OnTouchedByEntity", MineLaser_OnTouch, false);
		
		
		// Create laser beam
		int ent2 = CreateEntityByName("env_beam");
		TeleportEntity(ent2, beamend, NULL_VECTOR, NULL_VECTOR);
		SetEntityModel(ent2, MDL_LASER);
		DispatchKeyValue(ent2, "texture", MDL_LASER);
		DispatchKeyValue(ent2, "targetname", beam);
		DispatchKeyValue(ent2, "TouchType", "4"); //4
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
		HookSingleEntityOutput(ent2, "OnTouchedByEntity", MineLaser_OnTouch, false);
		
		//Create invisible wall in front of the beam
		
		
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
		PrintHintText(client, "You cant place it here.");
	}
}

public Action TurnBeamOn(Handle timer, DataPack hData)
{
	//char color[26]; // We didn't use this integer for now. That's why it's commented
	
	hData.Reset();
	int client = hData.ReadCell(); //We didn't use this integer for now.
	int ent = hData.ReadCell();
	int ent2 = hData.ReadCell();
	
	if (IsValidEntity(ent))
	{
		if (GetClientTeam(client) == g_iHumTeamIndex) {
			if (g_iHumTeamIndex == 2) {
				DispatchKeyValue(ent2, "rendercolor", "0 0 255");
			}
			else if (g_iHumTeamIndex == 3) {
				DispatchKeyValue(ent2, "rendercolor", "255 0 0");
			}
		}
		// To Do: Game-based team checks and handling.
		//DispatchKeyValue(ent2, "rendercolor", "0 0 255");
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
	AcceptEntityInput(caller, "kill");
}

public bool FilterAll(int entity, int contentsMask)
{
	return false;
}

public void MineLaser_OnTouch(const char[] output, int ent2, int iActivator, float delay)
{
	new currentHealthOfActivator = GetClientHealth(iActivator);
	AcceptEntityInput(ent2, "TurnOff");
	AcceptEntityInput(ent2, "TurnOn");
	float vOrigin[3];
	GetClientAbsOrigin(iActivator, vOrigin);
	if (GetClientTeam(iActivator) == g_iZomTeamIndex) {
		//AcceptEntityInput(ent2, "break"); //We have to add this if we want to destroy the mine and explode it.
		//AcceptEntityInput(ent2, "kill"); //We have to add this if we want to destroy the mine and explode it.
		PrintToConsole(iActivator, "touch zombie");
		SetEntityHealth(iActivator, currentHealthOfActivator - 1);
		TF2_StunPlayer(iActivator, 0.1, 0.80, TF_STUNFLAG_SLOWDOWN);
		TF2_IgnitePlayer(iActivator, iActivator);
		return Plugin_Handled; //We have to remove this if we want to destroy the mine and explode it.
	} else {
		PrintToConsole(iActivator, "touch insan");
		return Plugin_Handled;
	}
	//return Plugin_Continue;
}


stock bool:IsValidClient(client, bool:nobots = true)
{
	if (client <= 0 || client > MaxClients || !IsClientConnected(client) || (nobots && IsFakeClient(client)) || g_bMine[client])
	{
		return false;
	}
	return IsClientInGame(client);
}

logGameRuleTeamRegister() {  //Registers the Team indexes (Most likely usage for OnMapStart() )
	if (g_iMapPrefixType == 1 || g_iMapPrefixType == 2) {
		g_iZomTeamIndex = 3; //We'll set Blue team as a zombie for those maps
		g_iHumTeamIndex = 2; //We'll set Red team as a human for those maps
	} //If the map is ZF or ZM 
	else if (g_iMapPrefixType == 3 || g_iMapPrefixType == 4 || g_iMapPrefixType == 5 || g_iMapPrefixType == 6) {
		g_iZomTeamIndex = 2; //We'll set Red team as a zombie for those maps
		g_iHumTeamIndex = 3; //We'll set Blue team as a zombie for those maps
	} // If the map is ZM, ZS, ZOM, ZE
}
zombimod()
{
	g_iMapPrefixType = 0;
	decl String:mapv[32];
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
	}
}
public Action:OnPlayerRunCmd(client, &buttons) {
	int iAmount = 0;
	if ((buttons & IN_RELOAD)) {
		decl Float:VecPos_grabbed[3], Float:VecPos_client[3];
		new looking = TraceToEntity(client);
		PrintToChat(client, "%d", looking);
		if (looking > 0) {
			//PropNail(client, GetClientAimEntity(client, 50.0)); //Nailing the returned index of that stock
			decl String:Classname[32];
			GetEntityClassname(looking, Classname, sizeof(Classname));
			if (!StrEqual(Classname, "prop_physics_override", false) != -1) {
				GetEntPropVector(looking, Prop_Send, "m_vecOrigin", VecPos_grabbed);
				GetClientEyePosition(client, VecPos_client);
				GetVectorDistance(VecPos_grabbed, VecPos_client);
				PrintToConsole(client, "prop_physics_override");
				PrintToConsole(client, "%f", VecPos_grabbed);
				if (g_iNailedTimes[client] <= 1) {
					PropNail(client, looking, 10);
				}
				g_iNailedTimes[client]++;
			}
			//PrintToChat(client, "%d ", GetClientAimEntity(client, 5000000.0));
			//AcceptEntityInput(GetClientAimEntity(client, 5000000.0), "Kill");
		}
	} else if ((buttons & IN_ATTACK2)) {
		//buttons += IN_USE;
		new looking = TraceToEntity(client);
		decl Float:VecPos_grabbed[3], Float:VecPos_client[3];
		decl Float:ClientOrigin[3];
		decl Float:EyeAngles[3];
		decl Float:vecToUse[3];
		GetClientEyeAngles(client, EyeAngles);
		GetClientAbsOrigin(client, ClientOrigin);
		GetClientAbsOrigin(client, vecToUse);
		PrintToChat(client, "%d", looking);
		if (looking > 0) {
			decl String:Classname[16];
			GetEntityClassname(looking, Classname, sizeof(Classname));
			if (!StrEqual(Classname, "prop_physics_override", false) != -1) {
				GetEntPropVector(looking, Prop_Send, "m_vecOrigin", VecPos_grabbed);
				GetClientEyePosition(client, VecPos_client);
				GetVectorDistance(VecPos_grabbed, VecPos_client);
				PrintToConsole(client, "prop_physics_override");
				PrintToConsole(client, "%f", VecPos_grabbed);
				//PropNail(client, looking, iAmount++);
				Move(looking, vecToUse, ClientOrigin, EyeAngles, iAmount++);
			}
		}
		//return Plugin_Changed;
	} else if ((buttons & IN_SPEED)) {
		new looking = TraceToEntity(client);
		decl Float:VecPos_grabbed[3], Float:VecPos_client[3];
		decl Float:ClientOrigin[3];
		decl Float:EyeAngles[3];
		decl Float:vecToUse[3];
		GetClientEyeAngles(client, EyeAngles);
		GetClientAbsOrigin(client, ClientOrigin);
		GetClientAbsOrigin(client, vecToUse);
		PrintToChat(client, "%d", looking);
		if (looking > 0) {
			decl String:Classname[16];
			GetEntityClassname(looking, Classname, sizeof(Classname));
			if (!StrEqual(Classname, "prop_physics_override", false) != -1) {
				GetEntPropVector(looking, Prop_Send, "m_vecOrigin", VecPos_grabbed);
				GetClientEyePosition(client, VecPos_client);
				GetVectorDistance(VecPos_grabbed, VecPos_client);
				PrintToConsole(client, "prop_physics_override");
				PrintToConsole(client, "%f", VecPos_grabbed);
				//PropNail(client, looking, iAmount++);
				Move2(looking, vecToUse, ClientOrigin, EyeAngles, iAmount--);
			}
		}
	}
	//return Plugin_Changed;
}

//Credits to Playa for this stock
//Edited to returns if it's prop_physics_override as our prop.
stock GetClientAimEntity(client, Float:distancetoentity) {
	decl Float:cleyepos[3], Float:cleyeangle[3];
	GetClientEyePosition(client, cleyepos);
	GetClientEyeAngles(client, cleyeangle);
	new Handle:traceresulthandle = INVALID_HANDLE;
	traceresulthandle = TR_TraceRayFilterEx(cleyepos, cleyeangle, MASK_SOLID, RayType_Infinite, FilterAll, client);
	if (TR_DidHit(traceresulthandle)) {
		decl Float:endpos[3];
		decl String:className[32];
		TR_GetEndPosition(endpos, traceresulthandle);
		distancetoentity = GetVectorDistance(cleyepos, endpos);
		new entindextoreturn = TR_GetEntityIndex(traceresulthandle);
		GetEntityClassname(entindextoreturn, className, sizeof(className));
		if (FindEntityByClassname(entindextoreturn, "prop_physics_override") != -1) {
			return entindextoreturn + 1;
		}
		CloseHandle(traceresulthandle);
		return entindextoreturn;
	}
	CloseHandle(traceresulthandle);
	return -1;
}
//Normal Prop
void SetProp(client) {
	int iEnt = CreateEntityByName("prop_physics_override");
	if (iEnt != -1 && IsValidEntity(iEnt)) {
		//DispatchKeyValue(iEnt, "model", "models/props_farm/wooden_barrel.mdl");
		DispatchKeyValue(iEnt, "model", "models/props_c17/concrete_barrier001a.mdl");
		DispatchKeyValue(iEnt, "solid", "2");
		DispatchKeyValue(iEnt, "physdamagescale", "0.0");
		DispatchSpawn(iEnt);
		
		decl Float:FurnitureOrigin[3];
		decl Float:ClientOrigin[3];
		decl Float:EyeAngles[3];
		GetClientEyeAngles(client, EyeAngles);
		GetClientAbsOrigin(client, ClientOrigin);
		
		FurnitureOrigin[0] = (ClientOrigin[0] + (100 * Cosine(DegToRad(EyeAngles[1]))));
		FurnitureOrigin[1] = (ClientOrigin[1] + (100 * Sine(DegToRad(EyeAngles[1]))));
		FurnitureOrigin[2] = (ClientOrigin[2] + 50);
		
		TeleportEntity(iEnt, FurnitureOrigin, NULL_VECTOR, NULL_VECTOR);
		
		SetEntProp(iEnt, Prop_Data, "m_takedamage", 2, 1);
		SetEntProp(iEnt, Prop_Data, "m_iHealth", 100);
		SetEntityMoveType(iEnt, MOVETYPE_VPHYSICS);
	}
}
//We'Re making the prop nailed, and static.
void PropNail(int client, int iEnt, int iMoveUp) {
	decl Float:vecToUse[3];
	decl Float:ClientOrigin[3];
	decl Float:EyeAngles[3];
	GetClientEyeAngles(client, EyeAngles);
	GetClientAbsOrigin(client, ClientOrigin);
	GetClientAbsOrigin(client, vecToUse);
	if (iEnt != -1 && !IsValidClient(iEnt)) {
		AcceptEntityInput(iEnt, "Kill");
		PrintToChatAll("You have nailed! %d", iEnt);
		NailedProp(vecToUse, ClientOrigin, EyeAngles, iMoveUp);
	}
	//NailedProp(vecToUse, ClientOrigin, EyeAngles, iMoveUp);
}

void NailedProp(Float:vecToUse[3], Float:ClientOrigin[3], Float:EyeAngles[3], int iMoveUp) {
	int iEnt = CreateEntityByName("prop_physics_override");
	if (iEnt != -1 && IsValidEntity(iEnt)) {
		
		int hp = 500;
		DispatchKeyValue(iEnt, "model", "models/props_c17/concrete_barrier001a.mdl");
		//DispatchKeyValue(iEnt, "model", "models/props_farm/wooden_barrel.mdl");
		DispatchKeyValue(iEnt, "solid", "2");
		//DispatchKeyValue(iEnt, "physdamagescale", "0.0");
		DispatchSpawn(iEnt);
		SetEntProp(iEnt, Prop_Data, "m_iHealth", hp);
		SetEntProp(iEnt, Prop_Data, "m_takedamage", 2, 1);
		//DispatchKeyValue(iEnt, "health", "1000");
		//SetEntProp(iEnt, Prop_Data, "m_hGlowEnt", 0);
		SDKHook(iEnt, SDKHook_OnTakeDamage, OnPropTookDamage);
		SDKHook(iEnt, SDKHook_StartTouch, Human_Touch);
		
		if (!TF2_HasGlow(iEnt)) {
			TF2_CreateGlow(iEnt);
		}
		//SetEntityMoveType(iEnt, MOVETYPE_NONE);
		vecToUse[0] = (ClientOrigin[0] + (100 * Cosine(DegToRad(EyeAngles[1])))); //angle forward
		vecToUse[1] = (ClientOrigin[1] + (100 * Sine(DegToRad(EyeAngles[1])))); //angle right
		vecToUse[2] = (ClientOrigin[2] + iMoveUp); //angle height
		TeleportEntity(iEnt, vecToUse, NULL_VECTOR, NULL_VECTOR);
		SetEntityMoveType(iEnt, MOVETYPE_NONE);
	}
}
void Move(int iEnt, Float:vecToUse[3], Float:ClientOrigin[3], Float:EyeAngles[3], int iMoveUp) {
	if (iEnt != -1 && IsValidEntity(iEnt) && !IsValidClient(iEnt)) {
		vecToUse[0] = (ClientOrigin[0] + (100 * Cosine(DegToRad(EyeAngles[1])))); //angle forward
		vecToUse[1] = (ClientOrigin[1] + (100 * Sine(DegToRad(EyeAngles[1])))); //angle right
		vecToUse[2] = (ClientOrigin[2] + iMoveUp); //angle height
		TeleportEntity(iEnt, vecToUse, NULL_VECTOR, NULL_VECTOR);
	}
}
void Move2(int iEnt, Float:vecToUse[3], Float:ClientOrigin[3], Float:EyeAngles[3], int iMoveUp) {
	if (iEnt != -1 && IsValidEntity(iEnt) && !IsValidClient(iEnt)) {
		vecToUse[0] = (ClientOrigin[0] + (100 * Cosine(DegToRad(EyeAngles[1])))); //angle forward
		vecToUse[1] = (ClientOrigin[1] + (iMoveUp * 10 * Sine(DegToRad(EyeAngles[1])))); //angle right
		vecToUse[2] = (ClientOrigin[2] + iMoveUp); //angle height
		TeleportEntity(iEnt, vecToUse, NULL_VECTOR, NULL_VECTOR);
	}
}
TraceToEntity(client)
{
	new Float:vecClientEyePos[3], Float:vecClientEyeAng[3];
	GetClientEyePosition(client, vecClientEyePos); // Get the position of the player's eyes
	GetClientEyeAngles(client, vecClientEyeAng); // Get the angle the player is looking    
	
	//Check for colliding entities
	TR_TraceRayFilter(vecClientEyePos, vecClientEyeAng, MASK_SOLID, 
		RayType_Infinite, TraceRayDontHitSelf, client);
	
	if (TR_DidHit(INVALID_HANDLE))
	{
		new TRIndex = TR_GetEntityIndex(INVALID_HANDLE);
		
		// check max distance
		new Float:pos[3];
		GetEntPropVector(TRIndex, Prop_Send, "m_vecOrigin", pos);
		if (GetVectorDistance(vecClientEyePos, pos) > 512.0)
			return -1;
		else
			return TRIndex;
	}
	
	return -1;
}

public bool:TraceRayDontHitSelf(entity, mask, any:data)
{
	return (entity != data); // Check if the TraceRay hit the itself.
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
	//color[0] = RoundToNearest(Cosine((GetGameTime() * 1.0) + iEnt + 0) * 127.5 + 127.5);
	//color[1] = RoundToNearest(Cosine((GetGameTime() * 1.0) + iEnt + 2) * 127.5 + 127.5);
	//color[2] = RoundToNearest(Cosine((GetGameTime() * 1.0) + iEnt + 4) * 127.5 + 127.5);
	
	color[0] = 0;
	color[1] = 255;
	color[2] = 0;
	color[3] = 255;
	
	SetVariantColor(color);
	AcceptEntityInput(ent, "SetGlowColor");
	
	AcceptEntityInput(ent, "Enable");
	
	//Change name back to old name because we don't need it anymore.
	SetEntPropString(iEnt, Prop_Data, "m_iName", oldEntName);
	
	return ent;
}

stock bool TF2_HasGlow(int iEnt)
{
	int index = -1;
	while ((index = FindEntityByClassname(index, "tf_glow")) != -1)
	{
		if (GetEntPropEnt(index, Prop_Send, "m_hTarget") == iEnt)
		{
			return true;
		}
	}
	
	return false;
}
public Action:OnPropTookDamage(victim, &attacker, &inflictor, &Float:damage, &damagetype) {
	int cHP = GetEntProp(victim, Prop_Data, "m_iHealth");
	if (cHP < 500 && cHP > 0 && IsValidEntity(victim)) {
		CreateTimer(0.1, ChangeColour, victim, TIMER_FLAG_NO_MAPCHANGE);
	}
}
public Action:ChangeColour(Handle:timer, any:victim) {
	int color[4];
	if (victim != -1 && IsValidEntity(victim)) {
		int iGlow = TF2_CreateGlow(victim);
		color[0] = 255;
		color[1] = 0;
		color[2] = 0;
		color[3] = 255;
		SetVariantColor(color);
		AcceptEntityInput(iGlow, "SetGlowColor");
	}
}
public Action:Human_Touch(int iEnt, int client) {
	if (GetEntProp(client, Prop_Data, "m_nSolidType") && !(GetEntProp(client, Prop_Data, "m_usSolidFlags") & 0x0004))
	{
		if (IsValidClient(client) && IsPlayerAlive(client))
		{
			if (GetClientTeam(client) == g_iHumTeamIndex) {
				//decl Float:iEntVector[3], Float:ClientVector[3];
				CreateTimer(0.0, Teleport, client, TIMER_FLAG_NO_MAPCHANGE);
				//GetEntPropVector(iEnt, Prop_Send, "m_vecOrigin", iEntVector);
				//GetClientAbsOrigin(client, ClientVector);
				//ClientVector[0] = ClientVector[0] + iEntVector[0];
				//ClientVector[1] = ClientVector[1] + iEntVector[1];
				//ClientVector[2] = ClientVector[2] + iEntVector[2];
				//TeleportEntity(client, ClientVector, NULL_VECTOR, NULL_VECTOR);
			}
		}
	}
}
public Action:Teleport(Handle:timer, any:client) {
	decl Float:clientVector[3], Float:EyeAngles[3];
	GetClientAbsOrigin(client, clientVector);
	GetClientEyeAngles(client, EyeAngles);
	if (EyeAngles[1] > 0) {
		clientVector[0] = clientVector[0] + 30;
	} else {
		clientVector[0] = clientVector[0] - 30;
	}
	TeleportEntity(client, clientVector, NULL_VECTOR, NULL_VECTOR);
} 