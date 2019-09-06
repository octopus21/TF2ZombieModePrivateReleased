#pragma semicolon 1

#define DEBUG

#define PLUGIN_AUTHOR ""
#define PLUGIN_VERSION "0.00"

#include <sourcemod>
#include <sdktools>
#include <tf2>
#include <tf2_stocks>
#include <sdkhooks>

static String:KVPath[PLATFORM_MAX_PATH];
new String:IndexToReadFromNode[200][4][200];
float IndexToReadFromNodeToFloat[200][3];

public Plugin myinfo = 
{
	name = "PropNodes", 
	author = PLUGIN_AUTHOR, 
	description = "Nodes", 
	version = PLUGIN_VERSION, 
	url = "devil.co"
};

public void OnPluginStart()
{
	BuildPath(Path_SM, KVPath, sizeof(KVPath), "data/nodes.txt");
	HookEvent("teamplay_round_start", OnRound);
	//for Linux / Ubuntu OS
	if (!FileExists(KVPath)) {
		PrintToServer("\n None Data For the Nodes! Creating .txt file\n");
		Handle file = OpenFile(KVPath, "w+");
		if (file == INVALID_HANDLE) {
			PrintToServer("\n Failed at creating Node! Trying again...\n");
			file = OpenFile(KVPath, "w");
		} else {
			PrintToServer("\n Node Created!");
		}
	}
}
//This does not spawn the prop.
public OnMapStart() {
	NodeSave();
	for (new i = 1; i < 200; i++) {
		if (!StrEqual(IndexToReadFromNode[i][3], "")) {
			RegisterProps(i);
			PrecacheModel(IndexToReadFromNode[i][3], true);
		}
	}
}
//We'Ve added this thats why'
public Action:OnRound(Handle:event, const String:name[], bool:dontBroadcast) {
	for (new i = 1; i < 200; i++) {
		if (!StrEqual(IndexToReadFromNode[i][3], "")) {
			RegisterProps(i);
			PrecacheModel(IndexToReadFromNode[i][3], true);
		}
	}
}

public NodeSave() {
	Handle DB = CreateKeyValues("Nodes");
	FileToKeyValues(DB, KVPath);
	new String:MapName[64];
	decl String:IndexOfNode[6];
	decl String:buffer[200];
	GetCurrentMap(MapName, sizeof(MapName));
	if (KvJumpToKey(DB, MapName, false)) {
		for (new i = 1; i <= 200; i++) {
			Format(IndexOfNode, sizeof(IndexOfNode), "%d", i);
			KvGetString(DB, IndexOfNode, buffer, sizeof(buffer), "NULLSTRING");
			if (!StrEqual(buffer, "NULLSTRING")) {
				decl String:tempstring[4][200];
				ExplodeString(buffer, "--", tempstring, 4, 200);
				IndexToReadFromNode[i][0] = tempstring[0]; // 0 For registering the X position
				IndexToReadFromNode[i][1] = tempstring[1]; //1 For registering the Y position
				IndexToReadFromNode[i][2] = tempstring[2]; // 2 For registering the Z position
				IndexToReadFromNode[i][3] = tempstring[3]; //3 For registering the MODEL
				
				//Positions
				IndexToReadFromNodeToFloat[i][0] = StringToFloat(tempstring[0]); // 0 For registering the X position globally
				IndexToReadFromNodeToFloat[i][1] = StringToFloat(tempstring[1]); //1 For registering the Y position globally
				IndexToReadFromNodeToFloat[i][2] = StringToFloat(tempstring[2]); // 2 For registering the Z position globally
				
				PrintToServer("\n Index:%d, X:%f", i, IndexToReadFromNodeToFloat[i][0]);
				PrintToServer("\n Index:%d, Y:%f", i, IndexToReadFromNodeToFloat[i][1]);
				PrintToServer("\n Index:%d, Z:%f", i, IndexToReadFromNodeToFloat[i][2]);
				PrintToServer("\n Index:%d, Model:%s\n", i, tempstring[3]);
			}
		}
	}
	
	KvRewind(DB);
	KeyValuesToFile(DB, KVPath);
	CloseHandle(DB);
}

//THE MAP OF READING THE DATA TXT.
//PLUGIN READS LIKE THIS, OK?
//RULES, EVERY MAP HAS TO BE HAVE SAME AMOUNT OF PROP NODES!

/*
"Nodes"
{
	"zom_military_rm"
	{
		"1" "X=0.0 Y=0.0 Z=0.0 MODEL=models/blalba/blalba.mdl"
		"2" "X= 0.0 Y=0.0 Z=0.0 MODEL=models/blalba/blalba.mdl"
	}
	"anothermap"
	{
		"1"   "X=... Y=.... Z=... MODEL=models/blalba/blalba.mdl"
		"2"  "X=... Y=... Z=.. MODEL=models/blalba/blalba.mdl"
        }
}

*/

public void RegisterProps(propid) {
	int iEnt = CreateEntityByName("prop_physics_override");
	float vecPos_Ent[200][3];
	if (iEnt != -1 && IsValidEntity(iEnt)) {
		DispatchKeyValue(iEnt, "model", IndexToReadFromNode[propid][3]);
		DispatchKeyValue(iEnt, "solid", "2");
		SetEntProp(iEnt, Prop_Data, "m_iHealth", 500);
		SetEntProp(iEnt, Prop_Data, "m_takedamage", 2, 1);
		SetEntityMoveType(iEnt, MOVETYPE_NONE);
		DispatchSpawn(iEnt);
		TeleportEntity(iEnt, IndexToReadFromNodeToFloat[propid], NULL_VECTOR, NULL_VECTOR);
		TF2_CreateGlow(iEnt);
		GetEntPropVector(iEnt, Prop_Send, "m_vecOrigin", vecPos_Ent[propid]); // Testing the position from indexes.
		PrintToServer("Model is Valid:%s, for Index:%d", IndexToReadFromNode[propid][3], propid);
		PrintToServer("%f, %f, %f, for index:%d", vecPos_Ent[propid][0], vecPos_Ent[propid][1], vecPos_Ent[propid][2], propid);
	}
}
/*
decl String:m_ModelName[PLATFORM_MAX_PATH];
GetEntPropString(entity, Prop_Data, "m_ModelName", m_ModelName, sizeof(m_ModelName));
*/

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
	color[0] = 255;
	color[1] = 255;
	color[2] = 255;
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
