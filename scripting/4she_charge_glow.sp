#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <left4dhooks>

ConVar cvar_nnglow;

public Plugin myinfo =
{
	name="charge_glow",
	author="阿蛇",
	description="牛牛冲锋亮轮廓",
	version="1.0",
	url=""
}


public void OnPluginStart()
{
	cvar_nnglow = CreateConVar("nnglow", "1", "开冲发光开关(0=关闭, 1=开启).", FCVAR_NOTIFY);
	HookEvent("charger_charge_start", Event_charge_start);//开冲.
	HookEvent("charger_charge_end", Event_charge_end);//冲完了.
}

public void Event_charge_start(Event event, const char[] name ,bool Broadcast)
{
	//PrintToChatAll("开冲");
	int s = GetConVarInt(cvar_nnglow);
	int entity = GetClientOfUserId(event.GetInt("userid"));
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
	int s = GetConVarInt(cvar_nnglow);
	int entity = GetClientOfUserId(event.GetInt("userid"));
	if (IsValidEntity(entity))
	{
		if (s)
		L4D2_RemoveEntityGlow(entity);
	}
}