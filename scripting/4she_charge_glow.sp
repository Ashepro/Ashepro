/* 
	24-7-30
		- 幻影不知道作者是谁 先抄了

*/
#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <left4dhooks>

ConVar cvar_nnglow;


#include <sdktools>
#define IsValidClient(%1)		(1 <= %1 <= MaxClients && IsClientInGame(%1))

int g_BeamObject[66];
int g_BeamSprite;
Handle Onoff[32];

public Plugin myinfo =
{
	name="charge_glow",
	author="阿蛇",
	description="牛牛冲锋亮轮廓,尾行光线",
	version="1.0",
	url=""
}


public void OnPluginStart()
{
	//RegConsoleCmd("sm_hy", Command_CPmenu);
	cvar_nnglow = CreateConVar("nnglow", "1", "开冲发光开关(0=关闭, 1=开启).", FCVAR_NOTIFY);
	HookEvent("charger_charge_start", Event_charge_start);//开冲.
	HookEvent("charger_charge_end", Event_charge_end);//冲完了.
}

public void Event_charge_start(Event event, const char[] name ,bool Broadcast)
{
	int Client = GetClientOfUserId(event.GetInt("userid"));
	VIPHy(Client);
	//PrintToChatAll("开冲");
	int s = GetConVarInt(cvar_nnglow);
	int entity = Client;
	//PrintToChatAll("entity = %d",entity);
	if (IsValidEntity(entity))
	{
		//PrintToChatAll("IsValidEntity");
		if (s)
		{
			//PrintToChatAll("s = 1");
			L4D2_SetEntityGlow(entity, L4D2Glow_Constant, 1000, 0, {255,215,0}, false);
		}
	}
}

public void Event_charge_end(Event event, const char[] name ,bool Broadcast)
{
	int Client = GetClientOfUserId(event.GetInt("userid"));
	VIPHy(Client);
	int s = GetConVarInt(cvar_nnglow);
	int entity = Client;
	if (IsValidEntity(entity))
	{
		if (s)
		L4D2_RemoveEntityGlow(entity);
	}
}

//-----------------------------------------尾巴--------------------------------------------------------
public void OnMapStart()
{
	g_BeamSprite = PrecacheModel("materials/sprites/laserbeam.vmt", false);
}

public Action Command_CPmenu(int client, int args)
{
	VIPHy(client);
	return Plugin_Handled;
}

public Action VIPHy(int Client)
{
	if (IsValidHandle(Onoff[Client]))
	KillTimer(Onoff[Client]); //ashe add
	else
	{
		Onoff[Client] = CreateTimer(0.5, on, Client, 3);
		TriggerTimer(Onoff[Client]);
	}
	return Plugin_Handled;
}

public Action on(Handle timer, any Client)
{
	SetUpBeamSpirit(Client, "red", 2.0, 7.0, 100);
	return Plugin_Handled;
}

void SetUpBeamSpirit(int Client, char ColoR[32], float Life, float width, int Alpha) // 
{
	if (IsClientInGame(Client))
	{
		if (IsPlayerAlive(Client))
		{
			if (IsValidClient(Client) || !IsValidClient(Client))
			{
				int mr_Noob[32];
				mr_Noob[Client] = CreateEntityByName("prop_dynamic_override", -1);
				float pos[3];
				GetClientAbsOrigin(Client, pos);
				if (IsValidEdict(mr_Noob[Client]))
				{
					float nooB[3];
					float noobAng[3];
					GetEntPropVector(Client, Prop_Send, "m_vecOrigin", nooB, 0);
					GetEntPropVector(Client, Prop_Data, "m_angRotation", noobAng, 0);
					DispatchKeyValue(mr_Noob[Client], "model", "models/editor/camera.mdl");
					SetEntPropVector(mr_Noob[Client], Prop_Send, "m_vecOrigin", nooB, 0);
					SetEntPropVector(mr_Noob[Client], Prop_Send, "m_angRotation", noobAng, 0);
					DispatchSpawn(mr_Noob[Client]);
					SetEntPropFloat(mr_Noob[Client], Prop_Send, "m_flModelScale", -0.0, 0);
					SetEntProp(mr_Noob[Client], Prop_Send, "m_nSolidType", 6, 4, 0);
					SetEntityRenderMode(mr_Noob[Client], RENDER_TRANSCOLOR);
					SetEntityRenderColor(mr_Noob[Client], 255, 255, 255, 0);
					SetVariantString("!activator");
					AcceptEntityInput(mr_Noob[Client], "SetParent", Client, -1, 0);
					TeleportEntity(mr_Noob[Client], view_as<float>({0.0, 0.0, 45.0}), NULL_VECTOR, NULL_VECTOR);//位置(前后左右上下)、角度、速度
					//SetVariantString("head");
					//AcceptEntityInput(mr_Noob[Client], "SetParentAttachment", -1, -1, 0);
					int col[4];
					col[0] = GetRandomInt(0, 255);
					col[1] = GetRandomInt(0, 255);
					col[2] = GetRandomInt(0, 255);
					col[3] = Alpha;
					int col2[4];
					col2[0] = GetRandomInt(0, 255);
					col2[1] = GetRandomInt(0, 255);
					col2[2] = GetRandomInt(0, 255);
					col2[3] = Alpha;
					
					if (StrEqual(ColoR, "red", false))
					{
						col[0] = GetRandomInt(0, 255);
						col2[1] = GetRandomInt(0, 255);
					}
					else
					{
						if (StrEqual(ColoR, "green", false))
						{
							col[1] = 255;
							col2[0] = 255;
						}
						if (StrEqual(ColoR, "blue", false))
						{
							col[2] = 255;
							col2[0] = 255;
						}
					}
					
					TE_SetupBeamFollow(mr_Noob[Client], g_BeamSprite, 100, Life, width, 5.0, 3, col);
					TE_SendToAll(0.0);
					TE_SetupBeamFollow(mr_Noob[Client], g_BeamSprite, 100, Life, 1.0, 1.0, 3, col2);
					TE_SendToAll(0.0);
					g_BeamObject[Client] = mr_Noob[Client];
					CreateTimer(1.5, DeleteParticles, mr_Noob[Client], 0);
				}
			}
		}
	}
}

public Action DeleteParticles(Handle timer, any particle)
{
	if (IsValidEntity(particle))
	{
		char classname[64];
		GetEdictClassname(particle, classname, 64);
		RemoveEdict(particle);
	}
	return Plugin_Handled;
}
