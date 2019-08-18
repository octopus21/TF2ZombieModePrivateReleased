 // ZOMBI 3
// INSAN 2
/*
// TODO:
1) Her zombi sınıfına özel hasar statusu (kimisi kör edecek kimisi slowlatacak)
-Scout vuruşlarında kör edecek 5 saniyelik + slowness. (Tek Vuruşunda) HitOnce(attacker)++, attacker öldüğünde vurduğu sayıları 0'a çek.
-Sniper vuruşlarında kör edecek 3 saniyelik + Jarate efekti verecek HitOnce + slowness.
-Pyro vuruşlarında oyuncu yanma efekti olacak 1 saniyelik +slowness
-Soldier vuruşlarında slowness verilecek + slowness
-Sentry knockbackını azaltabiliriz ya da 1 level yapabiliriz
-- Zombiler damage yerse slowness olacak

2)Boss zombi seçiminde ve özelliklerinde yeni şeyler (HasBosZombieReleased?)
-Boss zombiye +2k health
-Regen olmayacak
-Boss zombi seçildiğinde insan takımına Fade gönderelim.
-Boss zombi seçimini düzelt. (Her bir insana vuruşta  ya da damage yiyince +1 boss queue puanı ekleme sistemi)
-Quickfix
-No Knockback

3)Oyun başlarken oyuncunun ekranını karartma ve korkunç bir atmosfer eklemek. (sf2)
-Eklendi :)

4)Enable consumable items for zombies like bad milk jarate etc
-Scoutun milk vb türleri aktif hale getirilebilir
-Soldierin botu vb aktif hale getirilebilir.

5)Set boss hp to 1.5k, give speedboost with quickfix uber no knockback thing

6)Let the sandman balls do more damage
Sandman ballsı editleyelim.

7)Set engi sentry level to 1 also let him to build props that can be destroyed

8)Add 2x damage to sniper rifles
Sniper Rifle damageleri iki katına çıkarılacak ya da krit ekleriz.

9)Nerf the airblast speed of pyros
Bakarım :D

10)Zombie ratio should be 1 than 1:5 (2 zombies for 6 players)
-TAMAM

11)Ullapol caber instakills the target and client him/herself
--Yapılabilir

12)Zombies should be slightly faster than humans

13)Zombies should slow players when hit

14)Medic should start with at least 40% of uber
-Yaparız

15)Level 1 sentrys firerate should be increased 33%
- :/

16)Mark the humans with mini crit (fan o war effect) when zombies hit humans
-Yapılabilir.

17)Remove melee crits from heavies
-Heavylerden değil sadece bossa veririz.

18)Add 10% bullet resistence to zombies
-Tamam bakarız (OnSpawn if zombie)

19)Add 5% invulnerability agains fire and explosive damage to zombies
-OnSpawn if zombie

20)Medic and sniper bows should do 25% more damage with 15% slow reload time
-Krit var onlara zaten

21)Remove gunboats from soldiers
-Gunboats?

22)Rocketjumper and sticky jumper should not be allowed
-Tamam

23)Zombies should jump longer than humans
-OnSpawn if zombie

24)Zombie Escape
--Zombilerin canı x 10 // Eklendi
--Hızları fazla //Eklendi gibimsi
--Haritaları incele. //
--Zombi seçimi 15 saniye //
--Round süresini haritanın süresiyle senkronize yap.
--Zombiler kesinlikle %100 yavaşlamalı hasar alınca. //Eklendi


25)Premium Oyuncuları DataBase olarak kaydet (KvString sonra da MySQL)

*/
#pragma semicolon 1
#pragma tabsize 0
#define DEBUG
#define TIMER_FLAG_NO_MAPCHANGE (1<<1)   

#define FFADE_IN            (0x0001)        // 0'ı' geçme
#define FFADE_OUT           (0x0002)        // Fade out 
#define FFADE_MODULATE      (0x0004)        // Modulate 
#define FFADE_STAYOUT       (0x0008)        // Durationu engeller kalıcı olmasını sağlar
#define FFADE_PURGE         (0x0010)        // Yenisi ile değiştir

#define PLUGIN_AUTHOR "Devil"
#define PLUGIN_VERSION "1.03"
#define PLAYERBUILTOBJECT_ID_DISPENSER 0
#define PLAYERBUILTOBJECT_ID_TELENT    1
#define PLAYERBUILTOBJECT_ID_TELEXIT   2
#define PLAYERBUILTOBJECT_ID_SENTRY    3

#define TF_CLASS_DEMOMAN		4
#define TF_CLASS_ENGINEER		9
#define TF_CLASS_HEAVY			6
#define TF_CLASS_MEDIC			5
#define TF_CLASS_PYRO				7
#define TF_CLASS_SCOUT			1
#define TF_CLASS_SNIPER			2
#define TF_CLASS_SOLDIER		3
#define TF_CLASS_SPY				8
#define TF_CLASS_UNKNOWN		0

#include <sourcemod>
#include <sdktools>
#include <tf2>
#include <tf2_stocks>
#include <sdkhooks>
#include <clientprefs>

static String:KVPath[PLATFORM_MAX_PATH];
//ConVars
new Handle:zm_tDalgasuresi = INVALID_HANDLE;
new Handle:zm_tHazirliksuresi = INVALID_HANDLE;
new Handle:zm_hTekvurus = INVALID_HANDLE;
new Handle:MusicCookie;
new Handle:zm_hBossZombi = INVALID_HANDLE;
new Handle:zm_hBossZombiInterval = INVALID_HANDLE;
new Handle:zm_enable = INVALID_HANDLE;
new Handle:zm_hOnlyZMaps = INVALID_HANDLE;
new Handle:zm_HealthRegenEnable = INVALID_HANDLE;
new Handle:zm_HealthRegenMiktar = INVALID_HANDLE;
new Handle:zm_HealthRegenTick = INVALID_HANDLE;
new Handle:zm_StatusAyari = INVALID_HANDLE;
//Timer Handles
new Handle:g_hTimer = INVALID_HANDLE;
new Handle:g_hSTimer = INVALID_HANDLE;
new Handle:g_hAdvert = INVALID_HANDLE;
new Handle:g_hAdvert2 = INVALID_HANDLE;
new Handle:g_hAdvert3 = INVALID_HANDLE;
new Handle:g_hAdvert4 = INVALID_HANDLE;
//Global Bools
new bool:g_bOyun;
new bool:getrand = false;
new bool:g_bOnlyZMaps;
new bool:g_bEnabled;
//Global Integers
new g_iSetupCount;
new g_iDalgaSuresi;
new bool:g_bKazanan;
new g_maxHealth[10] =  { 0, 125, 125, 200, 175, 150, 300, 175, 125, 125 };
new g_iMapPrefixType = 0;
new clientRegenTime[MAXPLAYERS + 1];
new MaxHealth[MAXPLAYERS];


new bool:g_iVaultKullanicilar[MAXPLAYERS + 1];
new g_iSebep; //1 Disabled , 2 sadece zm (onlyzm)  
new bool:g_iNonPreBoss[MAXPLAYERS + 1];
new bool:g_bNotHurt[MAXPLAYERS + 1] = true;
new bool:g_bZombiEscape = false;

new g_iSpeedTimer[MAXPLAYERS + 1];



//KvStrings
//static String:KvValue[PLATFORM_MAX_PATH]; //For Next Update

public Plugin:myinfo = 
{
	name = "Zombie Escape/Survival", 
	author = PLUGIN_AUTHOR, 
	description = "", 
	version = PLUGIN_VERSION, 
	url = ""
};
public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	if (GetEngineVersion() != Engine_TF2)
	{
		Format(error, err_max, "This plug-in only works for Team Fortress 2. // Eklenti sadece Team Fortress 2 için tasarlandı.");
		return APLRes_Failure;
	}
	return APLRes_Success;
}
//Ayarların yüklenmesi.
public OnMapStart()
{
	PrecacheSound("npc/fast_zombie/fz_scream1.wav", true);
	PrecacheSound("npc/zombie_poison/pz_alert2.wav", true);
	zombimod();
	setuptime();
	ClearTimer(g_hTimer);
	ClearTimer(g_hSTimer);
	ClearTimer(g_hAdvert);
	ClearTimer(g_hAdvert2);
	ClearTimer(g_hAdvert3);
	ClearTimer(g_hAdvert4);
	KillClientTimer(_, true);
	if (GetConVarInt(zm_enable) == 1 && GetConVarInt(zm_hOnlyZMaps) == 1) {
		if (g_iMapPrefixType == 0) {
			g_bEnabled = false;
			PrintToServer("\n\n[ZM]Sadece zombi maplerinde calismaya ayarlandı bu sebebple mod kapatildi.\n\n    \n\nTekrar Acmak icin:zm_onlyzm 0 yazabilirsiniz\n\n  \n--\n Works only in z' prefixed maps for now.\n -- \n You can change this by editing zm_onlyzm 0\n'");
			g_iSebep = 2;
			ZomEnableDisable();
			
		}
		else if (g_iMapPrefixType > 0) {
			g_bEnabled = true;
			ZomEnableDisable();
		}
	}
	else if (GetConVarInt(zm_enable) == 1 && GetConVarInt(zm_hOnlyZMaps) == 0) {
		g_bEnabled = true;
		if (g_iMapPrefixType > 0) {
			g_bEnabled = true;
			ZomEnableDisable();
		}
		else if (g_iMapPrefixType == 0) {
			g_bEnabled = true;
			ZomEnableDisable();
		}
	}
	
	if (GetConVarInt(zm_enable) == 0) {
		g_bEnabled = false;
		g_iSebep = 1;
		ZomEnableDisable();
	}
	else if (GetConVarInt(zm_enable) == 1) {
		g_bEnabled = true;
		ZomEnableDisable();
	}
}
public OnMapEnd()
{
	getrand = false;
	ClearTimer(g_hTimer);
	ClearTimer(g_hSTimer);
	ClearTimer(g_hAdvert);
	ClearTimer(g_hAdvert2);
	ClearTimer(g_hAdvert3);
	ClearTimer(g_hAdvert4);
	KillClientTimer(_, true);
}
public OnClientPutInServer(id)
{
	KayitliKullanicilar(id);
	if (g_bOyun && g_bEnabled) {
		ChangeClientTeam(id, 3);
	}
	SDKHook(id, SDKHook_OnTakeDamage, OnTakeDamage);
	if (g_bEnabled) {
		SDKHook(id, SDKHook_GetMaxHealth, OnGetMaxHealth);
	}
	if (id > 0 && IsValidClient(id) && IsClientInGame(id) && g_bOyun && TakimdakiOyuncular(3) > 0)
	{
		ChangeClientTeam(id, 3);
		CreateTimer(1.0, ClassSelection, id, TIMER_FLAG_NO_MAPCHANGE);
	}
}
public OnClientAuthorized(id) {
	if (id > 0 && IsValidClient(id) && IsClientInGame(id) && g_bOyun && TakimdakiOyuncular(3) > 0)
	{
		ChangeClientTeam(id, 3);
		CreateTimer(1.0, ClassSelection, id, TIMER_FLAG_NO_MAPCHANGE);
	}
}
public OnClientPostAdminCheck(client) {
	KayitliKullanicilar(client);
}
public OnClientDisconnect(client) {
	if (clientRegenTime[client] != INVALID_HANDLE)
		KillClientTimer(client);
}
public Action:ClassSelection(Handle:timer, any:id) {
	if (id > 0 && IsClientInGame(id) && ToplamOyuncular() > 0) {
		if (g_bEnabled) {
			ShowVGUIPanel(id, TF2_GetClientTeam(id) == TFTeam_Blue ? "class_blue" : "class_red");
		} else {
			ShowVGUIPanel(id, TF2_GetClientTeam(id) == TFTeam_Red ? "class_blue" : "class_red");
		}
	} else {
		if (g_bEnabled) {
			PrintToChat(id, "Lütfen [,] e basın! -- Please press [,]!");
		}
	}
}
public OnConfigsExecuted()
{
	if (g_bEnabled) {
		for (new i = 1; i <= MaxClients; i++) {
			if (IsClientInGame(i))
				SDKHook(i, SDKHook_GetMaxHealth, OnGetMaxHealth);
		}
	}
}
public OnPluginStart()
{
	//Konsol Komutları
	RegConsoleCmd("sm_msc", msc);
	RegConsoleCmd("sm_menu", zmenu);
	//Convarlar
	zm_tHazirliksuresi = CreateConVar("zm_setup", "30", "Setup Timer/Hazirlik Suresi", FCVAR_NOTIFY, true, 30.0, true, 70.0);
	zm_tDalgasuresi = CreateConVar("zm_dalgasuresi", "225", "Round Timer/Setup bittikten sonraki round zamani", FCVAR_NOTIFY, true, 120.0, true, 300.0);
	zm_hTekvurus = CreateConVar("zm_tekvurus", "0", " 1 Damage to turn human to a zombie / Zombiler tek vurusta insanlari infekte edebilsin (1/0) 0 kapatir.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	zm_hBossZombi = CreateConVar("zm_bosszombi", "1", "Activate Boss Zombie Choosing System? /Boss zombi secimi aktif edilsin mi?(0/1)", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	zm_hBossZombiInterval = CreateConVar("zm_bossinter", "20", "Boss Zombie Choosing Interval // Boss kacinci saniye gelsin // Formula = Dalga Suresi - Boss Inter (225 - 60 = 165. saniyede)", FCVAR_NOTIFY, true, 20.0, true, 80.0);
	zm_enable = CreateConVar("zm_enable", "1", "Enable The Gamemode ? / Zombi Modu Acilsin? Not:Birdahaki map degisiminde etkin olur. (0/1)", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	zm_hOnlyZMaps = CreateConVar("zm_onlyzm", "1", "Only In Z' prefixed maps / Zombi Modu sadece zombi haritalarinda olsun? (0/1)", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	zm_HealthRegenEnable = CreateConVar("zm_healthregen", "1", "Activate Health Regen? / Health Regen olsun mu? Zombiler hasar yediginde(0/1)", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	zm_HealthRegenMiktar = CreateConVar("zm_hrmiktar", "20", "Amount of health to regen / Her belirlenen saniyede kaç HP artsın? (Zombilerin)", FCVAR_NOTIFY, true, 10.0, true, 30.0);
	zm_StatusAyari = CreateConVar("zm_status", "1", "Apply Human status(debuff) on damage, Insan hasarı aktiflestir?", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	zm_HealthRegenTick = CreateConVar("zm_hrtick", "3", "Health Regen Interval/ Kaç saniyede bir canı artsın?(Zombilerin)", FCVAR_NOTIFY, true, 3.0, true, 7.0);
	//Olaylar
	HookEvent("teamplay_round_start", OnRound);
	HookEvent("player_death", OnPlayerDeath);
	HookEvent("player_spawn", OnSpawn);
	HookEvent("teamplay_setup_finished", OnSetup);
	HookEvent("teamplay_point_captured", OnCaptured, EventHookMode_Post);
	HookEvent("player_hurt", HookPlayerHurt);
	HookEvent("post_inventory_application", Event_Resupply);
	HookEvent("round_end", Event_RoundEnd);
	HookEvent("teamplay_round_win", Event_RoundEnd);
	RegConsoleCmd("say", say);
	RegConsoleCmd("say_team", say);
	//Set
	ServerCommand("mp_autoteambalance 0");
	ServerCommand("mp_scrambleteams_auto 0");
	ServerCommand("mp_teams_unbalance_limit 0");
	ServerCommand("mp_respawnwavetime 0 ");
	ServerCommand("mp_disable_respawn_times 1 ");
	ServerCommand("sm_cvar mp_waitingforplayers_time 25");
	ServerCommand("sm_cvar tf_spy_invis_time 0.5"); // Locked 
	ServerCommand("sm_cvar tf_spy_invis_unstealth_time 0.75"); // Locked 
	ServerCommand("sm_cvar tf_spy_cloak_no_attack_time 1.0");
	//Tercihler
	MusicCookie = RegClientCookie("oyuncu_mzk_ayari", "Muzik Ayarı", CookieAccess_Public);
	//Komut takibi
	AddCommandListener(hook_JoinClass, "joinclass");
	AddCommandListener(BlockedCommands, "autoteam");
	AddCommandListener(BlockedCommandsteam, "jointeam");
	//Directories
	//CreateDirectory("/addons/sourcemod/data/zombiprops", 0, false, NULL_STRING);
	CreateDirectory("addons/sourcemod/data/ZombiVault", 3);
	BuildPath(Path_SM, KVPath, sizeof(KVPath), "data/ZombiVault/vault.txt");
	LoadTranslations("tf2zombiemodvs.phrases");
}
public Action:OnGetMaxHealth(client, &maxhealth)
{
	if (client > 0 && client <= MaxClients)
	{
		if (TF2_GetClientTeam(client) == TFTeam_Blue)
		{
			//maxhealth = 5000;
			maxhealth = g_maxHealth[TF2_GetPlayerClass(client)] * 3; // Zombi Survival Can Formülü
			MaxHealth[client] = maxhealth;
			return Plugin_Handled;
		}
	}
	return Plugin_Continue;
}

//-- "[TF2] Be The Zombie" by Master Xyon

//-- "[TF2] Be The Zombie" by Master Xyon
public Action:Event_Resupply(Handle:hEvent, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	if (client > 0 && client && IsClientInGame(client) && IsPlayerAlive(client) && TF2_GetClientTeam(client) == TFTeam_Blue)
	{
		zombi(client); //Oyuncular resupply cabinete dokunduğu zaman silahlarını tekrar silmek için. (Zombilerin)
	}
	return Plugin_Continue;
}
public HookPlayerHurt(Handle:event, const String:name[], bool:dontBroadcast)
{
	new iUserId = GetEventInt(event, "userid");
	new client = GetClientOfUserId(iUserId);
	new attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	new damagebits = GetEventInt(event, "damagebits");
	g_bNotHurt[client] = true;
	
	if (client > 0 && damagebits & DMG_FALL)
		return;
	if (client > 0 && GetEventInt(event, "death_flags") & 32)
		return;
	if (client > 0 && GetConVarInt(zm_hTekvurus) == 1)
		if (client != attacker && attacker && TF2_GetPlayerClass(attacker) != TFClass_Scout && GetClientTeam(attacker) != 2 && GetClientTeam(attacker) != 1) {
		zombi(client);
	}
	if (client > 0 && GetConVarInt(zm_StatusAyari) == 1)
	{
		if (client != attacker && attacker && GetClientTeam(attacker) == 3)
		{
			switch (TF2_GetPlayerClass(attacker)) {
				case TFClass_Scout: {
					//PerformFade(client, 5, { 0, 0, 0, 255 } );
					//PrintCenterText(client, "TEST sınıfı tarafından hasar aldın 5 saniye boyunca körsün!");
					//CreateTimer(performFade yok et);
				}
			}
		}
	}
	if (client > 0 && g_bZombiEscape && client != attacker && attacker && GetClientTeam(attacker) == 2) {
		g_bNotHurt[client] = false;
		//TF2_StunPlayer(client, 0.0, 0.0, TF_STUNFLAG_SLOWDOWN);
		SetEntPropFloat(client, Prop_Send, "m_flMaxspeed", 80.0);
		g_iSpeedTimer[client] = CreateTimer(1.0, SpeedRemoval, client, TIMER_FLAG_NO_MAPCHANGE);
	}
	if (GetConVarInt(zm_HealthRegenEnable) == 1 && client > 0 && clientRegenTime[client] == INVALID_HANDLE && GetClientTeam(client) == 3) {
		clientRegenTime[client] = CreateTimer(GetConVarFloat(zm_HealthRegenTick), RegenTick, client, TIMER_REPEAT);
	}
}
public Action:RegenTick(Handle:timer, any:client)
{
	new clientCurHealth = GetPlayerHealth(client);
	//new Float:size = GetEntPropFloat(client, Prop_Data, "m_flModelScale");
	if (GetClientTeam(client) == 3 && clientCurHealth < MaxHealth[client]) {
		SetPlayerHealth(client, clientCurHealth + GetConVarInt(zm_HealthRegenMiktar));
	}
	else if (GetClientTeam(client) == 3 && clientCurHealth > MaxHealth[client]) {
		SetPlayerHealth(client, MaxHealth[client]);
		KillClientTimer(client);
	}
}
public Action:SpeedRemoval(Handle:timer, any:client)
{
	TF2_StunPlayer(client, 0.0, 0.0, TF_STUNFLAG_SLOWDOWN);
	SetEntPropFloat(client, Prop_Send, "m_flMaxspeed", 1000.0);
}
SetPlayerHealth(entity, amount, bool:maxHealth = false, bool:ResetMax = false)
{
	if (maxHealth)
		if (ResetMax)
		SetEntData(entity, FindDataMapInfo(entity, "m_iMaxHealth"), MaxHealth[entity], 4, true);
	else
		SetEntData(entity, FindDataMapInfo(entity, "m_iMaxHealth"), amount, 4, true);
	
	SetEntityHealth(entity, amount);
}
GetPlayerHealth(entity, bool:maxHealth = false)
{
	if (maxHealth)
	{
		return GetEntData(entity, FindDataMapInfo(entity, "m_iMaxHealth"));
	}
	return GetEntData(entity, FindDataMapInfo(entity, "m_iHealth"));
}
KillClientTimer(client = 0, bool:all = false)
{
	if (all)
	{
		for (new i; i <= MAXPLAYERS; i++)
		{
			if (clientRegenTime[i] != INVALID_HANDLE)
			{
				KillTimer(clientRegenTime[client]);
				clientRegenTime[client] = INVALID_HANDLE;
			}
		}
		return;
	}
	KillTimer(clientRegenTime[client]);
	clientRegenTime[client] = INVALID_HANDLE;
}
public Action:OnCaptured(Handle:event, const String:name[], bool:dontBroadcast)
{
	new entity = GetClientOfUserId(GetEventInt(event, "userid"));
	g_bKazanan = true;
	new capT = GetEntProp(entity, Prop_Send, "m_iOwner");
	kazanantakim(capT);
	oyunuresetle(); //Control point capture edildiği zaman resetlenme gerçekleşicek
}
public Action:BlockedCommands(client, const String:command[], argc)
{
	return Plugin_Handled;
}
public Action:BlockedCommandsteam(client, const String:command[], argc)
{
	if (g_bEnabled && ToplamOyuncular() > 0 && client > 0 && g_bOyun && GetClientTeam(client) > 1) //Round başladığı halde oyuncular takım değiştirmeye çalışırsa engellensin
	{
		PrintToChat(client, "\x07696969[ \x07A9A9A9ZF \x07696969]\x07CCCCCC %t", "Players Cant Change Team Setup");
		return Plugin_Handled; // Engellemeyi uygula
	}
	return Plugin_Continue; // Eğer öyle bir olay yoksa da plugin çalışmaya devam edicek.
}
public Action:hook_JoinClass(client, const String:command[], argc)
{
	if (g_bEnabled && client > 0 && client <= MaxClients && g_bOyun && GetClientTeam(client) == 2) //Round başladığı halde oyuncular takım değiştirmeye çalışırsa engellensin
	{
		PrintToChat(client, "\x07696969[ \x07A9A9A9ZF \x07696969]\x07CCCCCC %t", "Players Cant Change Class Round");
		return Plugin_Handled; // Engellemeyi uygula
	}
	return Plugin_Continue; // Eğer öyle bir olay yoksa da plugin çalışmaya devam edicek.
}
public Action:OnSetup(Handle:event, const String:name[], bool:dontBroadcast)
{
	zombimod(); //Round timerin işlemesi için
	PrintToChatAll("\x07696969[ \x07A9A9A9ZF \x07696969]\x07CCCCCC %t", "Intermission Over");
}
public Action:OnRound(Handle:event, const String:name[], bool:dontBroadcast)
{
	g_bOyun = false; // Setup bitmeden round başlayamaz
	g_iSetupCount = GetConVarInt(zm_tHazirliksuresi); //Setup zamanlayicisinin convarın değerini alması için
	g_iDalgaSuresi = GetConVarInt(zm_tDalgasuresi); //Round zamanlayicisinin convarın değerini alması için
	g_bKazanan = false;
	getrand = false;
	setuptime();
	ClearTimer(g_hTimer);
	ClearTimer(g_hSTimer);
	ClearTimer(g_hAdvert);
	ClearTimer(g_hAdvert2);
	ClearTimer(g_hAdvert3);
	ClearTimer(g_hAdvert4);
	g_hTimer = CreateTimer(1.0, oyun1, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
	g_hSTimer = CreateTimer(1.0, hazirlik, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
	g_hAdvert = CreateTimer(200.0, yazi1, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
	g_hAdvert2 = CreateTimer(220.0, yazi2, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
	g_hAdvert3 = CreateTimer(120.0, yazi4, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
	g_hAdvert4 = CreateTimer(190.0, yazi3, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}
public Action:Event_RoundEnd(Handle:hEvent, const String:strName[], bool:bDontBroadcast)
{
	ClearTimer(g_hTimer);
	ClearTimer(g_hSTimer);
	ClearTimer(g_hAdvert);
	ClearTimer(g_hAdvert2);
	ClearTimer(g_hAdvert3);
	ClearTimer(g_hAdvert4);
	oyunuresetle();
}
public Action:OnSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	//KayitliKullanicilar();
	//new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (TF2_GetClientTeam(client) == TFTeam_Blue)
	{
		if (!g_bOyun && g_iSetupCount > 0 && g_iSetupCount <= GetConVarInt(zm_tHazirliksuresi))
		{
			SetEntProp(client, Prop_Send, "m_lifeState", 2);
			ChangeClientTeam(client, 2);
			SetEntProp(client, Prop_Send, "m_lifeState", 0);
			TF2_RespawnPlayer(client);
			PrintToChat(client, "\x07696969[ \x07A9A9A9ZF \x07696969]\x07CCCCCC %t", "Player Cant Become Zombie Intermission");
		}
		if (g_bOyun && g_iDalgaSuresi > 0 && g_iDalgaSuresi <= GetConVarInt(zm_tDalgasuresi))
		{
			SetEntityRenderColor(client, 0, 255, 0, 0);
			zombi(client);
			if (clientRegenTime[client] != INVALID_HANDLE) {
				KillClientTimer(client);
			}
		}
	} else {
		SetEntityRenderColor(client, 255, 255, 255, 0);
		if (g_iVaultKullanicilar[client]) {
			PrintToConsole(client, "Registered Vault");
		}
		switch (TF2_GetPlayerClass(client))
		{
			case TFClass_Spy:
			{
				TF2_RemoveWeaponSlot(client, 3);
				new slot = GetPlayerWeaponSlot(client, 4);
				if (IsValidEntity(slot))
				{
					decl String:classname[64];
					if (GetEntityClassname(slot, classname, sizeof(classname)) && StrContains(classname, "tf_weapon", false) != -1)
					{
						switch (GetEntProp(slot, Prop_Send, "m_iItemDefinitionIndex"))
						{
							case 30: {  }
							default:TF2_RemoveWeaponSlot(client, 4);
						}
					}
				}
			}
			case TFClass_DemoMan: {
				new slotDemo = GetPlayerWeaponSlot(client, 1);
				if (IsValidEntity(slotDemo)) {
					decl String:classNameDemo[128];
					if (GetEntityClassname(slotDemo, classNameDemo, sizeof(classNameDemo)) && StrContains(classNameDemo, "tf_weapon", false) != -1) {
						switch (GetEntProp(slotDemo, Prop_Send, "m_iItemDefinitionIndex")) {
							case 265: { TF2_RemoveWeaponSlot(client, slotDemo); } //Sticky Jumper
							default:TF2_RemoveWeaponSlot(client, slotDemo);
						}
					}
				}
			}
			case TFClass_Engineer:
			{
				if (sinifsayisi(TFClass_Engineer) > 2)
				{
					TF2_SetPlayerClass(client, TFClass_Scout);
					TF2_RespawnPlayer(client);
					PrintToChat(client, "\x07696969[ \x07A9A9A9ZF \x07696969]\x07CCCCCC Limit:2 %t", "Engineer Limit Is Reached");
				}
			}
		}
	}
}
public Action:OnPlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
	new victim = GetClientOfUserId(GetEventInt(event, "userid"));
	decl Float:flPos[3];
	GetClientAbsOrigin(victim, flPos);
	if (GetEventInt(event, "death_flags") & 32) // Sahte ölüm
	{
		return;
	}
	if (GetClientTeam(victim) == 2 && g_bOyun)
	{
		zombi(victim);
		HUD(-1.0, 0.2, 6.0, 255, 0, 0, 2, "\n☠☠☠\n%N", victim);
		EmitSoundToAll("npc/fast_zombie/fz_scream1.wav", victim, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, SNDVOL_NORMAL, 100, victim, flPos, NULL_VECTOR, true, 0.0);
	}
}
public Action:hazirlik(Handle:timer, any:client)
{
	if (ToplamOyuncular() > 0)
	{
		g_iSetupCount--;
	}
	if (g_iSetupCount <= GetConVarInt(zm_tHazirliksuresi) && g_iSetupCount > 0)
	{
		HUD(-1.0, 0.1, 6.0, 255, 255, 255, 1, " | Setup:%02d:%02d |", g_iSetupCount / 60, g_iSetupCount % 60); //-1.0 x, 0.2 y
		HUD(0.42, 0.1, 1.0, 0, 255, 0, 5, "%d", TakimdakiOyuncular(3)); //0.02 x, 0.10 y
		HUD(-0.42, 0.1, 1.0, 255, 255, 255, 6, "%d", TakimdakiOyuncular(2)); //-0.02 x, 0.10 y
		g_iDalgaSuresi = GetConVarInt(zm_tDalgasuresi);
		g_bOyun = false;
	} else {
		g_bOyun = true;
		if (TakimdakiOyuncular(3) == 0 && TakimdakiOyuncular(2) > 9 && g_bOyun && !getrand)
			zombi(rastgelezombi()), zombi(rastgelezombi());
		else if (TakimdakiOyuncular(3) == 0 && TakimdakiOyuncular(2) < 9 && !getrand)
			zombi(rastgelezombi());
		else if (TakimdakiOyuncular(3) == 0 && TakimdakiOyuncular(2) > 20 && !getrand)
			zombi(rastgelezombi()), zombi(rastgelezombi()), zombi(rastgelezombi());
	}
}
public Action:oyun1(Handle:timer, any:id)
{
	if (ToplamOyuncular() > 0)
	{
		g_iDalgaSuresi--;
	}
	if (g_iDalgaSuresi <= GetConVarInt(zm_tDalgasuresi) && g_iDalgaSuresi > 0 && g_bOyun)
	{
		izleyicikontrolu();
		//HUD(-1.0, 0.2, 6.0, 255, 255, 255, 1, "Round:%02d:%02d", g_iDalgaSuresi / 60, g_iDalgaSuresi % 60);
		//HUD(0.02, 0.10, 1.0, 0, 255, 0, 5, "☠Zombies☠:%d", TakimdakiOyuncular(3));
		//HUD(-0.02, 0.10, 1.0, 255, 255, 255, 6, "Humans:%d", TakimdakiOyuncular(2));
		HUD(-1.0, 0.1, 6.0, 255, 255, 255, 1, " | Round:%02d:%02d |", g_iDalgaSuresi / 60, g_iDalgaSuresi % 60); //-1.0 x, 0.2 y
		HUD(0.42, 0.1, 1.0, 0, 255, 0, 5, "%d", TakimdakiOyuncular(3)); //0.02 x, 0.10 y
		HUD(-0.42, 0.1, 1.0, 255, 255, 255, 6, "%d", TakimdakiOyuncular(2)); //-0.02 x, 0.10 y
		
		if (g_iDalgaSuresi == GetConVarInt(zm_tDalgasuresi) - 3) {
			setuptime();
		}
		else if (g_iDalgaSuresi == GetConVarInt(zm_tDalgasuresi) - GetConVarInt(zm_hBossZombiInterval) && GetConVarInt(zm_hBossZombi) == 1) {
			bosszombi(bosschoosing());
			//HUD(-1.0, 0.2, 6.0, 255, 0, 0, 2, "\n☠☠☠\nBoss Zombie Came:%N\n☠☠☠", g_iChoosen[id]);
		}
		if (TakimdakiOyuncular(2) == 0) //2 red 3 blue
		{
			kazanantakim(3);
			oyunuresetle();
		}
	}
	else if (g_iDalgaSuresi <= 0 && g_bOyun)
	{
		if (TakimdakiOyuncular(2) > 0)
		{
			kazanantakim(2);
			oyunuresetle();
		}
		else if (TakimdakiOyuncular(2) == 0)
		{
			kazanantakim(3);
			oyunuresetle();
		}
	}
	return Plugin_Handled;
}



//Zombie Choosing Core
stock rastgelezombi()
{
	//new volunteerlist;
	new oyuncular[MaxClients + 1], num;
	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && GetClientTeam(i) > 1 && TF2_GetPlayerClass(i) != TFClass_Engineer && g_bOyun && !g_iVaultKullanicilar[i])
		{
			oyuncular[num++] = i;
		}
	}
	//volunteerlist = oyuncular[GetRandomInt(0, num - 1)];
	
	return (num == 0) ? 0 : oyuncular[GetRandomInt(0, num - 1)];
}
stock bosschoosing()
{
	//PrintToChat(client, "Twoje punkty: %i", punkty);
	new oyuncular[MAXPLAYERS + 1], num;
	for (new i = 1; i <= MaxClients; i++) {
		if (IsClientInGame(i) && IsPlayerAlive(i) && GetClientTeam(i) == 3 && g_bOyun) {
			oyuncular[num++] = i;
		}
	}
	return (num == 0) ? 0 : oyuncular[GetRandomInt(0, num - 1)];
}
bosszombi(client)
{
	if (client > 0 && IsClientInGame(client) && IsPlayerAlive(client) && GetClientTeam(client) == 3) {
		//client = g_iChoosen[client];
		TF2_SetPlayerClass(client, TFClass_Heavy);
		TF2_RespawnPlayer(client);
		SetEntPropFloat(client, Prop_Send, "m_flModelScale", 1.5);
		SetEntProp(client, Prop_Send, "m_bGlowEnabled", 1);
		SetEntityRenderColor(client, 255, 0, 0, 0);
		
		EmitSoundToAll("npc/zombie_poison/pz_alert2.wav");
		
		if (!g_iVaultKullanicilar[client]) {
			g_iNonPreBoss[client] = false; //Donator olan boss zombi seçildi
			PrintToServer("\n\n\n Donator olmayan birisi boss zombi seçildi");
		} else if (g_iVaultKullanicilar[client]) {
			g_iNonPreBoss[client] = false; // Donator olmayan boss zombi seçildi
			PrintToChat(client, "Donator olarak boss zombi seçilme şansın arttırıldı, boss zombi seçildin.");
		}
		HUD(-1.0, 0.2, 6.0, 255, 0, 0, 2, "\n☠☠☠\nBoss Zombie Came:%N\n☠☠☠", client);
	}
}
zombi(client)
{
	if (client > 0 && IsClientInGame(client))
	{
		SetEntProp(client, Prop_Send, "m_lifeState", 2);
		ChangeClientTeam(client, 3);
		SetEntProp(client, Prop_Send, "m_lifeState", 0);
		//TF2_RespawnPlayer(client);
		SetEntityRenderColor(client, 0, 255, 0, 0);
		if (g_bZombiEscape) {
			if (g_bNotHurt[client]) {
				TF2_AddCondition(client, TFCond_SpeedBuffAlly, TFCondDuration_Infinite, 0);
			} else {
				TF2_RemoveCondition(client, TFCond_SpeedBuffAlly);
			}
			//TF2_RespawnPlayer(client);
		}
	}
	CreateTimer(0.1, silah, client, TIMER_FLAG_NO_MAPCHANGE);
}
public Action:silah(Handle:timer, any:client)
{
	if (client > 0 && IsClientInGame(client))
	{
		for (new i = 0; i <= 5; i++)
		{
			if (client > 0 && i != 2 && TF2_GetClientTeam(client) == TFTeam_Blue)
			{
				TF2_RemoveWeaponSlot(client, i);
			}
		}
		if (client > 0 && TF2_GetClientTeam(client) == TFTeam_Blue)
		{
			new silah1 = GetPlayerWeaponSlot(client, 2);
			if (IsValidEdict(silah1))
			{
				EquipPlayerWeapon(client, silah1);
			}
		}
	}
}
//------



TakimdakiOyuncular(iTakim)
{
	new iSayi;
	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsClientConnected(i) && IsClientInGame(i) && GetClientTeam(i) == iTakim)
		{
			iSayi++;
		}
	}
	return iSayi;
}
ToplamOyuncular()
{
	new iSayi2;
	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsClientConnected(i) && IsClientInGame(i) && !IsFakeClient(i))
		{
			iSayi2++;
		}
	}
	return iSayi2;
}
kazanantakim(takim)
{
	new ent = FindEntityByClassname(-1, "team_control_point_master"); //game_round_win
	if (ent == -1) // < 1  ya da == -1
	{
		ent = CreateEntityByName("team_control_point_master");
		DispatchSpawn(ent);
	} else {
		SetVariantInt(takim);
		g_bKazanan = true;
		AcceptEntityInput(ent, "SetWinner");
	}
}
HUD(Float:x, Float:y, Float:Sure, r, g, b, kanal, const String:message[], any:...)
{
	SetHudTextParams(x, y, Sure, r, g, b, 255, 0, 6.0, 0.1, 0.2);
	new String:buffer[256];
	VFormat(buffer, sizeof(buffer), message, 9);
	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i))
		{
			ShowHudText(i, kanal, buffer);
		}
	}
}
public Action:OnTakeDamage(victim, &attacker, &inflictor, &Float:damage, &damagetype)
{
	if (!IsValidClient(attacker))
	{
		return Plugin_Continue;
	}
	new weaponId;
	(attacker == inflictor) ? (weaponId = ClientWeapon(attacker)) : (weaponId = inflictor); // Karsilastirma ? IfTrue : IfFalse;
	
	if (IsValidEntity(weaponId) && GetClientTeam(attacker) == 3)
	{  // weaponId != -1
		decl String:sWeapon[80];
		sWeapon[0] = '\0';
		GetEntityClassname(weaponId, sWeapon, 32);
		if (StrEqual(sWeapon, "tf_weapon_bat") || StrEqual(sWeapon, "tf_weapon_bat_fish") || 
			StrEqual(sWeapon, "tf_weapon_shovel") || StrEqual(sWeapon, "tf_weapon_katana") || StrEqual(sWeapon, "tf_weapon_fireaxe") || 
			StrEqual(sWeapon, "tf_weapon_bottle") || StrEqual(sWeapon, "tf_weapon_sword") || StrEqual(sWeapon, "tf_weapon_fists") || 
			StrEqual(sWeapon, "tf_weapon_wrench") || StrEqual(sWeapon, "tf_weapon_robot_arm") || StrEqual(sWeapon, "tf_weapon_bonesaw") || 
			StrEqual(sWeapon, "tf_weapon_club"))
		{
			//damage = 350.0;
			//return Plugin_Changed;
		}
		return Plugin_Continue;
	}
	return Plugin_Continue;
}
setuptime()
{
	new ent1 = FindEntityByClassname(MaxClients + 1, "team_round_timer");
	if (ent1 == -1)
	{
		ent1 = CreateEntityByName("team_round_timer");
		DispatchSpawn(ent1);
	}
	CreateTimer(1.0, Timer_SetTimeSetup, ent1, TIMER_FLAG_NO_MAPCHANGE);
}
public Action:Timer_SetTimeSetup(Handle:timer, any:ent1)
{
	if (g_iSetupCount > 0) {
		SetVariantInt(GetConVarInt(zm_tHazirliksuresi));
		AcceptEntityInput(ent1, "SetSetupTime"); //SetTime
	}
	else if (g_iSetupCount < 0) {
		SetVariantInt(GetConVarInt(zm_tDalgasuresi));
		AcceptEntityInput(ent1, "SetTime");
		//g_iDalgaSuresi = GetEntPropFloat(ent
	}
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
		g_bZombiEscape = true;
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
		g_bOnlyZMaps = true;
		if (g_iMapPrefixType != 6) {
			g_bZombiEscape = false;
		}
	}
	else if (g_iMapPrefixType == 0) {
		g_bOnlyZMaps = false;
		PrintToServer("\n\n           ********WARNING!********     \n\n\n ***Zombie Map Recommended Current [MAPNAME] = [%s]***\n\n\n", mapv);
	}
	if (g_bOnlyZMaps) {
		//
	}
}
public Action:Timer_SetRoundTime(Handle:timer, any:ent1)
{
	SetVariantInt(GetConVarInt(zm_tDalgasuresi)); // 600 sec ~ 10min
	AcceptEntityInput(ent1, "SetTime");
	
}
oyunuresetle()
{
	if (g_bKazanan)
	{
		CreateTimer(15.0, res, _, TIMER_FLAG_NO_MAPCHANGE);
	}
}
public Action:res(Handle:timer, any:id)
{
	new oyuncu[MaxClients + 1], num;
	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && GetClientTeam(i) == 3)
		{
			oyuncu[num++] = i;
			SetEntProp(i, Prop_Send, "m_lifeState", 2);
			ChangeClientTeam(i, 2);
			SetEntProp(i, Prop_Send, "m_lifeState", 0);
			TF2_RespawnPlayer(i);
		}
	}
}
/*
TF2_OnWaitingForPlayersStart()
{
	for (new i = 1; i <= MaxClients; i++) {
		if (IsClientInGame(i) && IsValidClient(i) && TF2_GetClientTeam(i) == TFTeam_Blue && !g_bOyun) {
			ChangeClientTeam(i, 2);
		}
	}
}
*/
stock bool:IsValidClient(client, bool:nobots = true)
{
	if (client <= 0 || client > MaxClients || !IsClientConnected(client) || (nobots && IsFakeClient(client)))
	{
		return false;
	}
	return IsClientInGame(client);
}
ClientWeapon(client)
{
	return GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
}
sinifsayisi(siniff)
{
	new iSinifNum;
	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && TF2_GetPlayerClass(i) == siniff && TF2_GetClientTeam(i) == TFTeam_Red)
		{
			iSinifNum++;
		}
	}
	return iSinifNum;
}
izleyicikontrolu()
{
	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && GetClientTeam(i) < 1 && g_bOyun)
		{
			ChangeClientTeam(i, 3);
			TF2_SetPlayerClass(i, TFClass_Scout);
			TF2_RespawnPlayer(i);
		}
	}
}
public Action:TF2_CalcIsAttackCritical(id, weapon, String:weaponname[], &bool:result)
{
	new Float:size = GetEntPropFloat(id, Prop_Data, "m_flModelScale"); // Boss için
	if (g_iVaultKullanicilar[id]) {  //Donator -- Kaydedilen Kullanıcı
		if (GetClientTeam(id) == 2 && StrEqual(weaponname, "tf_weapon_compound_bow", false) || StrEqual(weaponname, "tf_weapon_fists", false) || StrEqual(weaponname, "tf_weapon_crossbow", false)) {
			result = true;
			return Plugin_Changed;
		}
		else if (GetClientTeam(id) == 3 && size > 1.0 && StrEqual(weaponname, "tf_weapon_fists", false)) // Boss
		{
			result = true;
			return Plugin_Changed;
		}
	}
	if (GetClientTeam(id) == 3 && size > 1.0 && StrEqual(weaponname, "tf_weapon_fists", false)) // Boss
	{
		result = true;
		return Plugin_Changed;
	}
	return Plugin_Continue;
}
stock ClearTimer(&Handle:hTimer)
{
	if (hTimer != INVALID_HANDLE)
	{
		KillTimer(hTimer);
		hTimer = INVALID_HANDLE;
	}
}
ZomEnableDisable()
{
	if (!g_bEnabled) {
		PrintToServer("\n[ZM]Disabled\n");
		//UnhookEvent("teamplay_round_start", OnRound);
		//UnhookEvent("player_death", OnPlayerDeath);
		//UnhookEvent("player_spawn", OnSpawn);
		//UnhookEvent("teamplay_setup_finished", OnSetup);
		//UnhookEvent("teamplay_point_captured", OnCaptured, EventHookMode_Post);
		//UnhookEvent("player_hurt", HookPlayerHurt);
		//UnhookEvent("post_inventory_application", Event_Resupply);
		//UnhookEvent("round_end", Event_RoundEnd);
		//UnhookEvent("teamplay_round_win", Event_RoundEnd);
		if (g_iSebep == 1) {
			PrintToServer("\n\n\n                                      **********[ZM]Disabled -- S E B E P // R E A S O N**********\n\n\n");
		}
		else if (g_iSebep == 2) {
			PrintToServer("\n\n\n                                      **********[ZM]Only ZM Maps! -- S E B E P // R E A S O N**********\n\n\n");
		}
	}
}


/* // ------------------------------                                            ------------------------------
         ------------------------------ M E N U    S E C T I O N ------------------------------
         ------------------------------                                            ------------------------------
 */
public Action:zmenu(client, args)
{
	new Handle:panel = CreatePanel();
	SetPanelTitle(panel, "ZF Esas Menü");
	DrawPanelItem(panel, "Yardim");
	DrawPanelItem(panel, "Tercihler");
	DrawPanelItem(panel, "Yapımcılar");
	DrawPanelItem(panel, "Kapat");
	SendPanelToClient(panel, client, panel_HandleMain, 10);
	CloseHandle(panel);
}
public panel_HandleMain(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_Select)
	{
		switch (param2)
		{
			case 1:
			{
				Yardim(param1);
			}
			case 2:
			{
				mzkv2(param1);
			}
			case 3:Yapimcilar(param1);
			default:return;
		}
	}
}
public mzk(Handle hMuzik, MenuAction action, client, item)
{
	if (action == MenuAction_Select)
	{
		switch (item)
		{
			case 0:
			{
				MuzikAc(client);
				OyuncuMuzikAyari(client, true);
			}
			
			case 1:
			{
				MuzikDurdurma(client);
				OyuncuMuzikAyari(client, false);
			}
		}
	}
}
public Action:msc(client, args)
{
	Menu hMuzik = new Menu(mzk);
	hMuzik.SetTitle("Müzik bölmesi");
	hMuzik.AddItem("Aç", "Aç");
	hMuzik.AddItem("Kapa", "Kapa");
	hMuzik.ExitButton = false;
	hMuzik.Display(client, 20);
	
}
MuzikDurdurma(client)
{
	PrintToChat(client, "\x07696969[ \x07A9A9A9ZF \x07696969]\x07CCCCCCMüzikler durduruldu.");
}
MuzikAc(client)
{
	PrintToChat(client, "\x07696969[ \x07A9A9A9ZF \x07696969]\x07CCCCCCMüzikler açıldı.");
}
OyuncuMuzikAyari(client, bool:acik)
{
	new String:strCookie[32];
	if (client > 0 && IsClientInGame(client) && !IsFakeClient(client))
	{
		if (acik)
		{
			strCookie = "1";
		} else {
			strCookie = "0";
			SetClientCookie(client, MusicCookie, strCookie);
		}
	}
	return bool:StringToInt(strCookie);
}
public yrd(Handle hYardim, MenuAction action, client, item)
{
	if (action == MenuAction_Select)
	{
		switch (item)
		{
			case 0:
			{
				HakkindaK(client);
			}
			case 1:
			{
				CloseHandle(hYardim);
			}
		}
	}
}
public HakkindaK(client)
{
	new Handle:panel = CreatePanel();
	
	SetPanelTitle(panel, "ZF Hakkında");
	DrawPanelText(panel, "----------------------------------------------");
	DrawPanelText(panel, "Zombie Fortress, oyuncuları zombiler ve insanlar");
	DrawPanelText(panel, "arası ölümcül bir savaşa sokan custom moddur.");
	DrawPanelText(panel, "Insanlar bu bitmek bilmeyen salgında hayatta kalmalıdır.");
	DrawPanelText(panel, "Eğer insan infekte(ölürse) zombi olur.");
	DrawPanelText(panel, "----------------------------------------------");
	DrawPanelText(panel, "Modu Kodlayan:steamId=crackersarenoice - Deniz");
	DrawPanelItem(panel, "Yardım menüsüne geri dön.");
	DrawPanelItem(panel, "Kapat");
	SendPanelToClient(panel, client, panel_HandleOverview, 10);
	CloseHandle(panel);
}
public panel_HandleOverview(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_Select)
	{
		switch (param2)
		{
			case 1:Yardim(param1);
			default:return;
		}
	}
}
public Yapimcilar(client)
{
	new Handle:panel = CreatePanel();
	
	SetPanelTitle(panel, "Yapimci");
	DrawPanelText(panel, "Kodlayan:steamId=crackersarenoice - Deniz");
	DrawPanelItem(panel, "Yardim Menüsüne Geri Dön");
	DrawPanelItem(panel, "Kapat");
	SendPanelToClient(panel, client, panel_HandleYapimci, 10);
	CloseHandle(panel);
}
public panel_HandleYapimci(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_Select)
	{
		switch (param2)
		{
			case 1:Yardim(param1);
			default:return;
		}
	}
}
public mzkv2(client)
{
	new Handle:panel = CreatePanel();
	
	SetPanelTitle(panel, "Tercihler - Müzik");
	DrawPanelItem(panel, "Aç");
	DrawPanelItem(panel, "Kapa");
	DrawPanelItem(panel, "Yardım menüsüne geri dön.");
	DrawPanelItem(panel, "Kapat");
	SendPanelToClient(panel, client, panel_HandleMuzik, 10);
	CloseHandle(panel);
}
public panel_HandleMuzik(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_Select)
	{
		switch (param2)
		{
			case 1:MuzikAc(param1), OyuncuMuzikAyari(param1, true);
			case 2:MuzikDurdurma(param1), OyuncuMuzikAyari(param1, false);
			case 3:Yardim(param1);
			default:return;
		}
	}
}
Yardim(client)
{
	Menu hYardim = new Menu(yrd);
	hYardim.SetTitle("ZF Yardım Bölmesi(bilgi)");
	hYardim.AddItem("ZF Hakkında", "ZF Hakkında");
	hYardim.AddItem("Kapat", "Kapat");
	hYardim.ExitButton = false;
	hYardim.Display(client, 20);
}
/* //------------------------------------------------------------------------------------------
         ------------------------------------------------------------------------------------------
         ------------------------------------------------------------------------------------------
*/






/* // ------------------------------                                            ------------------------------
         ------------------------------ A D V E R T    S E C T I O N ------------------------------
         ------------------------------                                            ------------------------------
 */
public Action:yazi1(Handle:timer, any:id)
{
	PrintToChatAll("\x07696969[ \x07A9A9A9ZF \x07696969]\x07CCCCCCHazırlık süresi %02d:%02d (varsayılan) saniyedir.", GetConVarInt(zm_tHazirliksuresi) / 60, GetConVarInt(zm_tHazirliksuresi) % 60);
}
public Action:yazi2(Handle:timer, any:id)
{
	PrintToChatAll("\x07696969[ \x07A9A9A9ZF \x07696969]\x07CCCCCCHayatta kalmaya çalışın!");
}
public Action:yazi3(Handle:timer, any:id)
{
	PrintToChatAll("\x07696969[ \x07A9A9A9ZF \x07696969]\x07CCCCCCOyun içi müzikleri açmak veya kapatmak için [!msc] yazabilirsiniz.");
}
public Action:yazi4(Handle:timer, any:id)
{
	PrintToChatAll("\x07696969[ \x07A9A9A9ZF \x07696969]\x07CCCCCCOyun hakkında bilgi için [!menu] yazabilirsiniz.");
}
/* //------------------------------------------------------------------------------------------
         ------------------------------------------------------------------------------------------
         ------------------------------------------------------------------------------------------
*/


stock GetWeaponIndex(iWeapon)
{
	return IsValidEntity(iWeapon) ? GetEntProp(iWeapon, Prop_Send, "m_iItemDefinitionIndex"):-1;
}

//-------------- Vault----------------------
//KAYITLI DATA

public KayitliKullanicilar(client) {
	g_iVaultKullanicilar[client] = false; //CIZZZZ
	new Handle:DB = CreateKeyValues("VaultInfo");
	FileToKeyValues(DB, KVPath);
	new String:sClientAuth[128];
	GetClientAuthId(client, AuthId_Steam2, sClientAuth, sizeof(sClientAuth));
	if (KvJumpToKey(DB, sClientAuth, true)) {
		new String:name[MAX_NAME_LENGTH], String:temp_name[MAX_NAME_LENGTH], String:temp_userid[128];
		GetClientName(client, name, sizeof(name));
		KvGetString(DB, "name", temp_name, sizeof(temp_name), " ");
		KvGetString(DB, "userid", temp_userid, sizeof(temp_userid), " ");
		new donatorStatus = KvGetNum(DB, "donator");
		KvSetString(DB, "name", name);
		KvSetString(DB, "userid", sClientAuth);
		//KvSetNum(DB, "donator", 0);
		if (StrEqual(temp_userid, sClientAuth)) {
			if (donatorStatus == 1) {
				g_iVaultKullanicilar[client] = true;
			}
		}
		if (!g_iVaultKullanicilar[client]) {
			PrintToServer("Normal:%s", sClientAuth);
		} else {
			PrintToServer("Donator:%s", sClientAuth);
		}
		KvRewind(DB);
		KeyValuesToFile(DB, KVPath);
		CloseHandle(DB);
	}
	/*
	if (StrEqual(sClientAuth, "STEAM_0:0:81591956", false)) {  // Devil
		g_iVaultKullanicilar[client] = true; //DOKUNMA!
		PrintToServer("Donator:%s", sClientAuth);
	}
	else if (StrEqual(sClientAuth, "STEAM_0:0:95142811", false)) {  // Berke
		g_iVaultKullanicilar[client] = true;
		PrintToServer("Donator:%s", sClientAuth);
	}
	else if (StrEqual(sClientAuth, "STEAM_0:0:94605939", false)) {  //STEAM_0:0:94605939 Buğrahan
		g_iVaultKullanicilar[client] = true;
		PrintToServer("Donator:%s", sClientAuth);
	}
	*/
}
public Action:say(client, args)
{
	new String:argx[512];
	GetCmdArgString(argx, sizeof(argx));
	StripQuotes(argx);
	TrimString(argx);
	new String:sClientAuth[128];
	GetClientAuthId(client, AuthId_Steam2, sClientAuth, sizeof(sClientAuth));
	if (g_iVaultKullanicilar[client]) {
		if (StrEqual(sClientAuth, "STEAM_0:0:81591956", false)) {  //STEAM_0:0:81591956 Devil
			PrintToChatAll("\x0700FF00[ A very kind Donator ]\x07FFCC00%N: %s", client, argx); //Özel Tag (Devil)
			return Plugin_Handled;
		}
		else if (StrEqual(sClientAuth, "STEAM_0:0:95142811", false)) {
			PrintToChatAll("\x0700FF00[ Gay Faggot ]\x07FFCC00%N: \x07FF0099%s", client, argx); //Özel Tag(Berke)
			return Plugin_Handled;
		}
		else if (StrEqual(sClientAuth, "STEAM_0:0:94605939", false)) {
			PrintToChatAll("\x0700FF00[ Gay Faggot ]\x07FFCC00%N: \x07FF0099%s", client, argx); //Özel Tag(Buğrahan)
			return Plugin_Handled;
		}
		return Plugin_Handled;
		//PrintToChatAll("\x0700FF00[ Donator ]\x07FFCC00%N: \x07FF0099%s", client, argx); //Kendilerine Özel Tag ayarlarız.
	} else {
		return Plugin_Continue;
	}
}
/*
--Usage for later.
	new setQueue[MAXPLAYERS + 1];
	new queuepoints[MAXPLAYERS + 1];
	new g_iActiveBoss[MAXPLAYERS + 1];
	new client = GetClientOfUserId(client);
	GetEntProp(queuepoints[client] , Prop_Data, "m_iScore");
	for (new i = 1; i <= MaxClients; i++) {
	        if (IsClientInGame(i) && GetClientTeam(i) == 3 && g_bOyun) {
			if(queuepoints[i] > 0) {
				for (new j = i; j < i; j++) {
					if(queuepoints[i] > queuepoints[j]) {
					         PrintToServer("%N", queuepoints[i]);
				                 setQueue[i] = g_iActiveBoss[i];
				                 if(g_iActiveBoss[i]) {
					                  PrintToServer("En yüksek puanla boss seçilen kişi:%N", g_iActiveBoss[i]);
			                         }
				        }
			        }
		        }
		}
         }
*/

/*
	if (StrEqual(weaponname, "tf_weapon_compound_bow", false) || StrEqual(weaponname, "tf_weapon_fists", false) || StrEqual(weaponname, "tf_weapon_crossbow", false))
	{
		result = true;
		return Plugin_Changed;
	}
*/