/*
	24-7-15
	大部分从acs插件里扣的

*/
#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>

ConVar g_hCVar_PreventEmptyServer;
Handle g_hTimer_CheckEmpty;
//native void L4D2_ChangeLevel(const char[] sMap);

public Plugin myinfo =
{
	name="empty",
	author="阿蛇",
	description="无人换C2",
	version="1.0",
	url=""
}

public void OnPluginStart() {
	
	g_hCVar_PreventEmptyServer =  CreateConVar("empty", "1", "当服务器没有玩家在服务器时自动切换到C2M1. 0=禁用, 1=启用.", FCVAR_NOTIFY);	
	

	HookConVarChange(g_hCVar_PreventEmptyServer, CVarChange_PreventEmptyServer);
	
	AutoExecConfig(true, "empty");
	
	HookEvent("player_disconnect", Event_PlayerDisconnect);

}

public void CVarChange_PreventEmptyServer(Handle hCVar, const char[] strOldValue, const char[] strNewValue) {
	//If the value was not changed, then do nothing
	if(StrEqual(strOldValue, strNewValue, false))
		return;

	CheckEmptyServer();
}

public Action Event_PlayerDisconnect(Handle hEvent, const char[] strName, bool bDontBroadcast) {
	int iClient = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	char ClientName[64];
	GetClientName(iClient, ClientName, 64);
	
	if(!iClient || IsFakeClient(iClient)) 
	{
		//LogAction(-1, -1, "FakePlayerDisconnect:%s[%d]", ClientName, iClient);
		return Plugin_Continue;
	}	
	
	LogAction(-1, -1, "TruePlayerDisconnect:%s[%d]", ClientName, iClient);

	CheckEmptyServer();
	
	return Plugin_Continue;
}



public void OnMapEnd() {
	KillEmptyCheckTimer();
}

void KillEmptyCheckTimer() {
	if (g_hTimer_CheckEmpty != null) {
		KillTimer(g_hTimer_CheckEmpty);
		g_hTimer_CheckEmpty = null;
	}
}

void CheckEmptyServer() {
	//if (IsEmptyServer()) {
		//LogAction(-1, -1, "IsEmptyServer");
		if (g_hTimer_CheckEmpty == null) {
			g_hTimer_CheckEmpty = CreateTimer(5.0, Timer_CheckEmptyServer, INVALID_HANDLE, TIMER_REPEAT);
			//LogAction(-1, -1, "CreateTimer");
		}
	//}
}

bool IsEmptyServer() {
	if (!g_hCVar_PreventEmptyServer.BoolValue)
		return false;	// Feature disabled
		
	for (int client = 1; client <= MaxClients; client++) {
		if (!IsClientInGame(client))
			continue;	// Not a valid client id

		if (!IsFakeClient(client))
			{
				LogAction(-1, -1, "return false");
				return false;	// Someone is in the server
			}
	}
	LogAction(-1, -1, "return true");
	return true;
}

public Action Timer_CheckEmptyServer(Handle timer, any param) {
	static int counter = 0;
	if (IsEmptyServer()){
		counter++;
		if (counter > 10) {	// Idle for 50s
			counter = 0;
			KillEmptyCheckTimer();
			

			LogAction(-1, -1, "Empty ChangeMap");
			
			ServerCommand("map c2m1_highway");
			//L4D2_ChangeLevel("L4D2C2");

		}
	} 
	else {
		// Some one joined
		KillEmptyCheckTimer();
	}
	return Plugin_Continue;
}
