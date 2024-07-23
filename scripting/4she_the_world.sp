/*
	- 提示抄的豆瓣酱的播报
	- 缓速抄的子弹时间插件源码找不到了
	
*/

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdkhooks>
#include <colors>
#include <sdktools>

#define PLUGIN_VERSION	"1.0"

int
	g_iPlayerImpact;
ConVar
	g_cPlayerImpact,
	g_duration,
	g_scale;
float
	duration,
	scale;
static Handle TheWorld;

public Plugin myinfo = 
{
	name 			= "the_world",
	author 			= "阿蛇",
	description 	= "牛牛撞人提示+缓速，配合光速大力牛牛食用",
	version 		= PLUGIN_VERSION,
	url 			= ""
}

public void OnPluginStart()
{
	HookEvent("charger_impact", Event_Impact);//创飞.
	HookEvent("charger_carry_start", Event_Carry);//携带.
	
	g_cPlayerImpact	= CreateConVar("l4d2_enabled_player_Impact",	"1",	"启用幸存者被创飞提示? 0=禁用, 1=启用.", FCVAR_NOTIFY);
	g_duration	    = CreateConVar("t_duration",					"1.0",	"缓速时长,服务器的时间.", FCVAR_NOTIFY);
	g_scale			= CreateConVar("t_scale",						"0.5",	"缓速倍率,意思是接下来服务器的1s在玩家电脑上以0.5倍速播放,玩家实际减速2s.", FCVAR_NOTIFY);
	g_cPlayerImpact.AddChangeHook(IsConVarChanged);
	g_duration.AddChangeHook(IsConVarChanged);
	g_scale.AddChangeHook(IsConVarChanged);

	AutoExecConfig(true, "the_world");//生成指定文件名的CFG.
}

public void OnMapStart()
{
	IsGetCvars();
}

public void IsConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	IsGetCvars();
}

void IsGetCvars()
{
	g_iPlayerImpact = g_cPlayerImpact.IntValue;
	duration = g_duration.FloatValue;
	scale = g_scale.FloatValue;
}

char[] GetTrueName(int client)
{
	char g_sName[32];
	int Bot = IsClientIdle(client);
	
	if(Bot != 0)
		Format(g_sName, sizeof(g_sName), "闲置:%N", Bot);
	else
		GetClientName(client, g_sName, sizeof(g_sName));
	return g_sName;
}

int IsClientIdle(int client) {
	if (!HasEntProp(client, Prop_Send, "m_humanSpectatorUserID"))
		return 0;

	return GetClientOfUserId(GetEntProp(client, Prop_Send, "m_humanSpectatorUserID"));
}

// ------------------------------------------------------------------------
//创飞.
int carry;
public void Event_Carry(Event event, const char[] name ,bool Broadcast)
{
	carry = 0;
	carry = GetClientOfUserId(event.GetInt("victim"));
}
public void Event_Impact(Event event, const char[] name ,bool Broadcast)
{
	ZedTime(duration, scale);
	int victim = GetClientOfUserId(event.GetInt("victim"));
	if (!g_iPlayerImpact)
		return;

	if(IsValidEntity(victim))
		switch(carry == 0)
		{
			case true:
				CPrintToChatAll("{green}★★★★★ {blue}%s{olive}被牛牛创飞咯", GetTrueName(victim));
			case false:
				CPrintToChatAll("{green}★★★★★ {olive}牛牛抓着{blue}%s{olive}把{blue}%s{olive}创飞咯", GetTrueName(carry),GetTrueName(victim));
		}
}

// ------------------------------------------------------------------------


//____________________________The World!____________________________

void ZedTime(float duration, float scale) {
	if (TheWorld)
		TriggerTimer(TheWorld);
	int entity = CreateEntityByName("func_timescale");
	char SCALE[8];
	FloatToString(scale, SCALE, sizeof(SCALE));
	DispatchKeyValue(entity, "desiredTimescale", SCALE);
	DispatchKeyValue(entity, "acceleration", "2.0");
	DispatchKeyValue(entity, "minBlendRate", "1.0");
	DispatchKeyValue(entity, "blendDeltaMultiplier", "2.0");
	DispatchSpawn(entity);
	AcceptEntityInput(entity, "Start");
	LogAction(-1, -1, "the world start");
	TheWorld = CreateTimer(duration, ZedBack, entity);
}


public Action ZedBack(Handle Timer, int entity) {

	if(IsValidEdict(entity)) {
		AcceptEntityInput(entity, "Stop");
		LogAction(-1, -1, "the world Stop");
	} else {
		int found = -1;
		while ((found = FindEntityByClassname(found, "func_timescale")) != -1)
			if (IsValidEdict(found))
				AcceptEntityInput(found, "Stop");
	}
	TheWorld = INVALID_HANDLE;
	return Plugin_Continue;
}
