/*
	-24-8-3
	-换新语言，注释	-ashe
*/
#pragma semicolon 1
#pragma newdecls required

#include <sdktools>
Handle Enabled;
int g_Unit[65];

public Plugin myinfo =
{
	name = "[L4D2]ATK_TANK",
	description = "ATK_TANK",
	author = "iCeAtao",
	version = "1.0",
	url = "http://iCeBox.net.ru"
};

public void OnPluginStart()
{
	Enabled = CreateConVar("HardTank_enabled", "1", "开启/关闭插件", 262144, false, 0.0, false, 0.0);
	HookConVarChange(Enabled, Command_Enabled);
	HookEvent("player_hurt", Event_TankHit, EventHookMode_Post);
	HookEvent("player_incapacitated_start", Event_PlayerIncapacitated, EventHookMode_Post);
	HookEvent("player_death", Event_PlayerDeath, EventHookMode_Post);
	HookEvent("tank_killed", Event_Tank_Killed, EventHookMode_Post);
	HookEvent("tank_spawn", Event_Tank_TankSpawn, EventHookMode_Post);
	HookEvent("round_start", round_start_Event, EventHookMode_Post);

}

public Action round_start_Event(Handle event, const char[] name, bool dontBroadcast)
{
	RemoveAllValue();
	return Plugin_Handled;
}

public void Command_Enabled(Handle convar, char[] oldValue, char[] newValue)
{
	if (GetConVarInt(Enabled))
	{
		PrintToChatAll("\x04鬼禽TANK模式被启用!");
	}
	else
	{
		RemoveAllValue();
		PrintToChatAll("\x04鬼禽TANK模式被禁用!");
	}
}

public Action Event_PlayerDeath(Handle event, char[] name, bool dontBroadcast)
{
	int index = GetClientOfUserId(GetEventInt(event, "userid"));
	RemoveValue(index);
	return Plugin_Handled;
}

public Action Event_Tank_Killed(Handle event, char[] name, bool dontBroadcast)
{
	int index = GetClientOfUserId(GetEventInt(event, "userid"));
	RemoveValue(index);
	return Plugin_Handled;
}

public Action Event_Tank_TankSpawn(Handle event, char[] name, bool dontBroadcast)
{
	int index = GetClientOfUserId(GetEventInt(event, "userid"));
	RemoveValue(index);
	return Plugin_Handled;
}

public void RemoveAllValue()
{
	int ix = 1;
	while (ix <= 64)
	{
		g_Unit[ix] = 0;
		ix++;
	}
}

bool GetValueBool(int index)
{
	if (g_Unit[index])
	{
		return true;
	}
	return false;
}

public void RemoveValue(int index)
{
	if (GetValueBool(index))
	{
		int i = g_Unit[index];
		g_Unit[i] = 0;
		g_Unit[index] = 0;
	}
}

public void SetValue(int index1, int index2)
{

	if (!GetValueBool(index1) && !GetValueBool(index2))
	{
		g_Unit[index1] = index2;
		g_Unit[index2] = index1;
	}

}

public Action Event_TankHit(Handle event, char[] name, bool dontBroadcast)
{
	if (GetConVarInt(Enabled))
	{
		int TarGetUnit = GetClientOfUserId(GetEventInt(event, "userid"));
		int AttackUnit = GetClientOfUserId(GetEventInt(event, "attacker"));
		char AttackWeapon[128];
		GetEventString(event, "weapon", AttackWeapon, 128);

		if (GetClientTeam(TarGetUnit) == 2 && StrEqual(AttackWeapon, "tank_claw", true))
		{
			SetTankGrab(TarGetUnit, AttackUnit);
		}
		return Plugin_Handled;
	}
	return Plugin_Handled;
}

public Action Event_PlayerIncapacitated(Handle event, char[] name, bool dontBroadcast)
{
	if (GetConVarInt(Enabled))
	{
		int TriggerUnit = GetClientOfUserId(GetEventInt(event, "userid"));
		int AttackUnit = GetClientOfUserId(GetEventInt(event, "attacker"));
		char AttackWeapon[128];
		GetEventString(event, "weapon", AttackWeapon, 128);

		if (GetClientTeam(TriggerUnit) == 2 && StrEqual(AttackWeapon, "tank_claw", true))
		{
			SetTankGrab(TriggerUnit, AttackUnit);
		}
		return Plugin_Handled;
	}
	return Plugin_Handled;
}

public void SetTankGrab(int TarGetUnit, int AttackUnit)
{

	if (!GetValueBool(TarGetUnit) && !GetValueBool(AttackUnit))
	{
		SetValue(AttackUnit, TarGetUnit);
		CreateTimer(0.01, TankGrab_timer, AttackUnit, 0);
	}
	else
	{
	
		if (GetValueBool(TarGetUnit) && GetValueBool(AttackUnit))
		{
			//if (GetEntProp(TarGetUnit, Prop_Send, "m_isIncapacitated", 1))
			//{
			TankThrow(AttackUnit, TarGetUnit, 700.0, GetRandomFloat(300.0, 450.0)); //抓住的人丢出去
			//}
			RemoveValue(AttackUnit);
		}
	}
}

public Action TankGrab_timer(Handle timer, any index)
{
	if (GetConVarInt(Enabled))
	{
		if (GetValueBool(index))
		{
			float Angle[3];
			float Location[3];
			GetClientEyePosition(index, Location); //眼睛位置 （X指向水平0度,Y指向水平90度,Z指向上）
			GetClientEyeAngles(index, Angle); //视线角度 （垂直角度,水平角度,0）
			Location[0] = Location[0] + Cosine(DegToRad(Angle[1])) * 50.0; //抓在眼前50距离
			Location[1] += Sine(DegToRad(Angle[1])) * 50.0; //抓在眼前50距离
			Location[2] += -25; //Z轴抓人在眼睛下面25
			TeleportEntity(g_Unit[index], Location, NULL_VECTOR, NULL_VECTOR);//实体传送至的位置 ，实体面向角度，XYZ三个方向弹射速度 //NULL_VECTOR
			CreateTimer(0.05, TankGrab_timer, index, 0); //0.05间隔套娃
		}
		return Plugin_Handled;
	}
	return Plugin_Handled;
}

public void TankThrow(int attack, int target, float Dist, float Height) //attack 坦克编号, target抓的人编号, Dist距离, Height高度
{
	float HeadingVector[3];
	float AimVector[3];
	GetClientEyeAngles(attack, HeadingVector);
	AimVector[0] = Cosine(DegToRad(HeadingVector[1])) * Dist;
	AimVector[1] = Sine(DegToRad(HeadingVector[1])) * Dist;
	float current[3];
	GetEntPropVector(target, Prop_Data, "m_vecVelocity", current);
	float resulting[3];
	resulting[0] = current[0] + AimVector[0];
	resulting[1] = current[1] + AimVector[1];
	resulting[2] = Height;
	TeleportEntity(target, NULL_VECTOR, NULL_VECTOR, resulting);//实体传送至的位置 ，实体面向角度，XYZ三个方向弹射速度） //NULL_VECTOR
	
}