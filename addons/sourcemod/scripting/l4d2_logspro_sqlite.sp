#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <geoip.inc>
#include <l4d2_mission_manager>
static char chatFile[128];
Handle fileHandle = null;
ConVar sc_record_detail = null;

/*
	大部分代码来源:
	citkabuto => SaveChat
	url = "http://forums.alliedmods.net/showthread.php?t=117116"
	pan0s, Drakcol, AXIS_ASAKI => l4d2_Shop (Points and Gift System)
	url = "https://forums.alliedmods.net/showthread.php?t=332186"
*/

#define PLUGIN_NAME				"l4d2_logspro_sqlite"
#define PLUGIN_AUTHOR			"阿蛇"
#define PLUGIN_VERSION			"1.0"
#define PLUGIN_DESCRIPTION		"日志保存各种,顺便记录时长,需要安装sqlite"
#define PLUGIN_URL				"https://github.com/Ashepro/l4d2_plugins/"
#define CVAR_FLAGS				FCVAR_NOTIFY
#define DEBUG					0
#define DATABASE 		"clientprefs" //SQLITE 数据库

LMM_GAMEMODE gamemode;	
char
	logMapName[64],
	MapName[64],
	MissionName[64],
	imapName[64];
int
	missionIndex,
	mapmaxnum,
	mapnow,
	failedtime,
	playtimes[MAXPLAYERS + 1],
	staticplaytimes[MAXPLAYERS + 1];

public Plugin myinfo = 
{
	name = PLUGIN_NAME,
	author = PLUGIN_AUTHOR,
	description = PLUGIN_DESCRIPTION,
	version = PLUGIN_VERSION,
	url = PLUGIN_URL
}


public void OnPluginStart() {
	char date[21];
	char logFile[100];

	LoadTranslations("missions.phrases");//加载翻译文件
	LoadTranslations("maps.phrases");//加载翻译文件
	/* Register CVars */
	CreateConVar("sm_savechat_version", PLUGIN_VERSION, "记录STEAM32位ID插件的版本.", FCVAR_DONTRECORD|FCVAR_REPLICATED);

	sc_record_detail = CreateConVar("sc_record_detail", "1", "记录玩家的STEAM32位ID和IP地址?  0=禁用, 1=启用.", FCVAR_NOTIFY);
	
	AutoExecConfig(true, "l4d2_logspro_sqlite");
	
	/* Say commands */
	RegConsoleCmd("say", Command_Say);
	RegConsoleCmd("say_team", Command_SayTeam);

	/* Format date for log filename */
	FormatTime(date, sizeof(date), "%y%m%d", -1);

	/* Create name of logfile to use */
	Format(logFile, sizeof(logFile), "/logs/chat%s.log", date);
	BuildPath(Path_SM, chatFile, PLATFORM_MAX_PATH, logFile);
	HookEvent("player_disconnect", Event_PlayerDisconnect, EventHookMode_Pre);
	HookEvent("mission_lost", mission_lost, EventHookMode_Pre);
	HookEvent("finale_win", finale_win, EventHookMode_Pre);
	CreateDBTable();

	RegConsoleCmd("sm_sj", Command_SJ);//查服务器内时间
}


public Action Command_Say(int client, int args)
{
	LogChat(client, args, false);
	return Plugin_Continue;
}

/*
 * Capture player team chat and record to file
 */
public Action Command_SayTeam(int client, int args)
{
	LogChat(client, args, true);
	return Plugin_Continue;
}

public void OnClientPostAdminCheck(int client)
{
	if(IsFakeClient(client)) 
		return;

	char msg[2048];
	char time[21];
	char country[3];
	char steamID[128];
	char playerIP[50];

	/* Get 2 digit country code for current player */
	if(GetClientIP(client, playerIP, sizeof(playerIP), true) == false)
	{
		country   = "  ";
	}
	else
	{
		if(GeoipCode2(playerIP, country) == false)
		{
			country = "  ";
		}

	}	
	//if(StrEqual(country,"KR",false) == true )  KickClientEx(client , "g");
	
	if(!IsFakeClient(client)) //加载时长
    {
		staticplaytimes[client] = LoadTimes(client); //缓存上次基础游戏时长
    }
	int sTimehour;
	int sTimemin;
	playtimes[client] = RoundToCeil(GetClientTime(client) / 60) + staticplaytimes[client];
	sTimehour = playtimes[client] / 60;
	sTimemin = playtimes[client] % 60;

	
	GetClientAuthId(client, AuthId_Steam2, steamID, sizeof(steamID));



	FormatTime(time, sizeof(time), "%H:%M:%S", -1);
	/* Only record player detail if CVAR set */
	if(GetConVarInt(sc_record_detail) == 1)
		Format(msg, sizeof(msg), "[%s] [%s] <%-19s | %-15s>  已加入 服内时长:%d h %d m ▶▶%N◀◀", time, country, steamID, playerIP, sTimehour, sTimemin, client);
	else
		Format(msg, sizeof(msg), "[%s] [%s] <%-15s>  已加入 服内时长:%d h %d m ▶▶%N◀◀", time, country, playerIP, sTimehour, sTimemin, client);
	SaveMessage(msg);
    

	
}

public void Event_PlayerDisconnect(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));

	if(!client || IsFakeClient(client)) 
		return;

	char msg[2048];
	char time[21];
	char country[3];
	char steamID[128];
	char playerIP[50];
	char Reason[128];	
	int ConnectionTime=-1;
	int sTimehour;
	int sTimemin;
	GetEventString(event, "reason", Reason, 128);
	GetClientAuthId(client, AuthId_Steam2, steamID, sizeof(steamID));
	if (IsClientInGame(client))
			ConnectionTime = RoundToCeil(GetClientTime(client) / 60);
	staticplaytimes[client] = LoadTimes(client); //再加载一下 防止刷新插件丢失数据 （刷新插件加换到没有的图会丢失本局时长,要在换图事件插入读取数据,不加了无所谓了）
	playtimes[client] = playtimes[client] < staticplaytimes[client] + ConnectionTime ? staticplaytimes[client] + ConnectionTime : playtimes[client]; //累加时长
	SaveToDB(client); //存时长
	staticplaytimes[client] = 0; //清除玩家缓存时长 
	sTimehour = playtimes[client] / 60;
	sTimemin = playtimes[client] % 60;
	
	if(GetClientIP(client, playerIP, sizeof(playerIP), true) == false)
	{
		country   = "  ";
	}
	else
	{
		if(GeoipCode2(playerIP, country) == false)
		{
			country = "  ";
		}
	}

	FormatTime(time, sizeof(time), "%H:%M:%S", -1);
	if(GetConVarInt(sc_record_detail) != 1)
		Format(msg, sizeof(msg), "[%s] [%s] <%-19s | %-15s> <%-25s> after %-3d min. 服内时长:%d h %d m ▶▶%N◀◀", time, country, steamID, playerIP, Reason, ConnectionTime, sTimehour, sTimemin, client);
	else
		Format(msg, sizeof(msg), "[%s] [%s] <%-15s> <%-25s> after %-3d min. 服内时长:%d h %d m ▶▶%N◀◀", time, country, playerIP, Reason, ConnectionTime, sTimehour, sTimemin, client);
	SaveMessage(msg);
	playtimes[client] = 0; //清除玩家缓存时长 
	
}

/*
 * Extract all relevant information and format 
 */
public void LogChat(int client, int args, bool teamchat)
{
	char msg[2048];
	char time[21];
	char text[1024];
	char country[3];
	char playerIP[50];
	char teamName[20];

	GetCmdArgString(text, sizeof(text));
	StripQuotes(text);

	if(client == 0)
	{
		/* Don't try and obtain client country/team if this is a console message */
		Format(country, sizeof(country), "  ");
		Format(teamName, sizeof(teamName), "");
	}
	else
	{
		/* Get 2 digit country code for current player */
		if(GetClientIP(client, playerIP, sizeof(playerIP), true) == false)
		{
			country   = "  ";
		}
		else
		{
			if(GeoipCode2(playerIP, country) == false)
			{
				country = "  ";
			}
		}
		GetTeamName(GetClientTeam(client), teamName, sizeof(teamName));
	}
	FormatTime(time, sizeof(time), "%H:%M:%S", -1);

	if(GetConVarInt(sc_record_detail) == 1)
	{
		Format(msg, sizeof(msg), "[%s] [%s] [%s] <%N> :%s %s", time, country, teamName, client, teamchat == true ? " (TEAM)" : "", text);
	}
	else
	{
		Format(msg, sizeof(msg), "[%s] [%s] <%N> :%s %s", time, country, client, teamchat == true ? " (TEAM)" : "", text);
	}

	SaveMessage(msg);
}

/*
 * Log the message to file
 */
public void SaveMessage(const char[] message)
{
	fileHandle = OpenFile(chatFile, "a");  /* Append */
	WriteFileLine(fileHandle, message);
	CloseHandle(fileHandle);
}

Database ConnectDB()
{
	// if(!cvar_db_on.BoolValue) return null; //开关

	char error[255];
	Database db = SQL_Connect(DATABASE, true, error, sizeof(error)); //建连接句柄 database类
	
	if (db == null)
	{
	    LogError("[ERROR]: Could not connect: \"%s\"", error);
	}
	return db; //返回句柄
}

void CreateDBTable()
{
	Database db = ConnectDB(); //新建连接句柄 Database是连接类
	if (db != null)
	{
		DBResultSet Svtime = SQL_Query(db, "CREATE TABLE IF NOT EXISTS Servertime(steamID TEXT, '玩家ID' TEXT, '游玩时间' INTEGER, '最后游戏时间' TEXT, '首次游戏时间' TEXT, PRIMARY KEY (steamId))"); //新建查询句柄 不存在则新建 DBResultSet是查询结果类
		char isSucceed[255];
		isSucceed = Svtime.RowCount>0? "Success." : "Already existesd.";
		if(Svtime.RowCount>0)
		{
			LogMessage("[CREATE]: Create Servertime table: \"%s\"", isSucceed);  //猜测新建表是在建完1列后RowCount=1
		}
		else PrintToServer("[Servertime] Create Servertime table: %s", isSucceed);  //猜测是查到表在0就返回所以RowCount=0

		delete Svtime; //删句柄
	}
	delete db; //删句柄
}

int LoadTimes(int client) //函数 返回游戏时间
{
	int db_times = 0;
	Database db = ConnectDB();
	if (db != null)
	{
		char steamId[32];
		char error[255];

		DBStatement hTimeQuery; //预处理语句 类

		GetClientAuthId(client, AuthId_Steam2, steamId, sizeof(steamId));

		///////////////////////////////////////////////////

		///////////////////////////////////////////////////
		// Load points
		if ((hTimeQuery = SQL_PrepareQuery(db, "SELECT * FROM Servertime WHERE steamID = ?", error, sizeof(error))) == null) //新建预处理
		{
			LogError("[ERROR]: SELECT SQL_PrepareQuery: \"%s\"", error);
		}
		else
		{
			hTimeQuery.BindString(0, steamId, false); //玩家steamId绑定到0列 类似赋值
			// Find the client in the database
			if (SQL_Execute(hTimeQuery))  //执行准备好的语句。所有参数必须事先绑定。
			{
				if(SQL_FetchRow(hTimeQuery)) //以绑定的steamid获取行
				{
					// SQL_FetchString(hTimeQuery, 0, steamId, sizeof(steamId)); 好像用不着
					db_times = SQL_FetchInt(hTimeQuery, 2);
					LogAction(client, -1, "[LOAD]: \"%L\" loaded the record successfully! Times: \"%d\"", client, db_times);
				}
				else //INSERT 新玩家
				{
					// if the user is not existed in the database, insert new one.
					DBStatement hInsertStmt;
					char playerName[64];
					GetClientName(client, playerName, sizeof(playerName));
					char lasttime[32];
					FormatTime(lasttime, sizeof(lasttime), "%Y-%m-%d %H:%M:%S", -1);
					if ((hInsertStmt = SQL_PrepareQuery(db, "INSERT INTO Servertime(steamID, '玩家ID', '游玩时间', '最后游戏时间', '首次游戏时间') VALUES(?,?,?,?,?)", error, sizeof(error))) == INVALID_HANDLE)
					{
						LogError("[ERROR]: INSERT SQL_PrepareQuery: \"%s\"", error);
					}
					else
					{
						hInsertStmt.BindString(0, steamId, false);
						hInsertStmt.BindString(1, playerName, false);
						hInsertStmt.BindInt(2, 0, false); // Default time is 0
						hInsertStmt.BindString(3, lasttime, false);
						hInsertStmt.BindString(4, lasttime, false);						
						if (!SQL_Execute(hInsertStmt))
						{
							LogError("[ERROR]: INSERT error Error: \"%s\"", error);
						}
						int rs = SQL_GetAffectedRows(hInsertStmt);
						if(rs>0)
						{
							LogAction(client, -1, "[INSERT]: \"%L\" is a new user!!", client);
						}else
						{
							LogError("[ERROR]: \"%L\" made insert error \"%s\"", client, error);
						}
					}
					delete hInsertStmt;
				}
			}
		}

		delete hTimeQuery;
		////////////////////////////////
	}
	delete db;
	return db_times;
}

int SaveToDB(int client) //更新时长 返回的是影响行数没啥用 主要是更新
{
	int affectRows = 0;
	Database db = ConnectDB();
	if (db != null)
	{
		if(client && !IsFakeClient(client))
		{
			char error[255];
			// database statment
			DBStatement hUpdateTimeStmt;
			char steamId[32];
			GetClientAuthId(client, AuthId_Steam2, steamId, sizeof(steamId));
			char playerName[64];
			GetClientName(client, playerName, sizeof(playerName));
			char lasttime[32];
			FormatTime(lasttime, sizeof(lasttime), "%Y-%m-%d %H:%M:%S", -1);
			if ((hUpdateTimeStmt = SQL_PrepareQuery(db, "UPDATE Servertime SET '游玩时间' = ?, '玩家ID' = ?, '最后游戏时间' = ? WHERE steamID = ?", error, sizeof(error))) == null)
			{
				LogError("[ERROR]: UPDATE SQL_PrepareQuery: \"%s\"", error);
			}
			else
			{
				hUpdateTimeStmt.BindInt(0, playtimes[client], false);  //0(上面SQL_PrepareQuery的第1个?)=playtimes
				hUpdateTimeStmt.BindString(1, playerName, false);  //1(上面SQL_PrepareQuery的第2个?)=playerName
				hUpdateTimeStmt.BindString(2, lasttime, false);  //2(上面SQL_PrepareQuery的第3个?)=lasttime
				hUpdateTimeStmt.BindString(3, steamId, false);  //3(上面SQL_PrepareQuery的第4个?)=steamId

				if (!SQL_Execute(hUpdateTimeStmt))  //执行UPDATE Servertime SET times = ? WHERE steamId = ? （先绑定再执行）
				{
					LogError("[ERROR]: Update Servertime SQL_Execute: \"%s\"", error);
				}
				else
				{
					//char playerName[64];
					//GetClientName(client, playerName, sizeof(playerName));
					affectRows = SQL_GetAffectedRows(hUpdateTimeStmt);
					//if(affectRows>0)
					//{
					//	LogAction(client, -1,"[UPDATE]: \"%L\" saved. times: \"%d\"", client, playtimes[client]); 不用log
					//}
				}
			}
			delete hUpdateTimeStmt;

		}
	}
	delete db;
	return affectRows;
}

/*
public void SaveAll() //存全体时长 退出才记录 不用了
{
	int rs = 0;
	for(int i = 1; i <= MaxClients; i++) rs += SaveToDB(i);
	if(rs>0) PrintToServer("[Shop] Auto Update Successfully! Affected rows: %d", rs); //更新行数-等于游戏人数
}
*/

public void UPpdateAll() //更新全体时长(未存数据库)
{
	int ConnectionTime;
	for(int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i))
			if(i && !IsFakeClient(i))
			{
				ConnectionTime = RoundToCeil(GetClientTime(i) / 60);
				playtimes[i] = staticplaytimes[i] + ConnectionTime; //累加时长
			}
	}
}

//查询时长
public Action Command_SJ (int client, int args)
{
	int Playsj=0;
	int Playsj1=0;
	int PlaysjH;
	int PlaysjM;
	if (IsClientInGame(client))
		Playsj1 = RoundToCeil(GetClientTime(client) / 60);
	Playsj = playtimes[client] + Playsj1;
	PlaysjH = Playsj / 60;
	PlaysjM = Playsj % 60;
	PrintToChat(client, "\x03当前服内游玩时长：\x04%d\x03时\x04%d\x03分", PlaysjH, PlaysjM);
	return Plugin_Continue;
}

// 地图开始
public void OnMapStart() {
	failedtime = 0;
	char msg[1024];
	char date[32];
	char time[32];
	char logFile[128];
	//OnMapStartedPost();
	ChangeMapName();
	
		
	/* The date may have rolled over, so update the logfile name here */
	FormatTime(date, sizeof(date), "%y%m%d", -1);
	Format(logFile, sizeof(logFile), "/logs/chat%s.log", date);
	BuildPath(Path_SM, chatFile, PLATFORM_MAX_PATH, logFile);

	FormatTime(time, sizeof(time), "%Y-%m-%d %H:%M:%S", -1);
	Format(msg, sizeof(msg), "[%s] --- 新的地图开始: %s ---", time, logMapName);

	SaveMessage("____________________________________________________________________________________________");
	SaveMessage(msg);
	SaveMessage("¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯");
}

//团灭mission_lost
public void mission_lost(Event event, const char[] name, bool dontBroadcast)
{
	char msg[1024];
	char date[32];
	char logFile[128];	
	char restartcount[64];
	/* The date may have rolled over, so update the logfile name here */
	FormatTime(date, sizeof(date), "%y%m%d", -1);
	Format(logFile, sizeof(logFile), "/logs/chat%s.log", date);
	BuildPath(Path_SM, chatFile, PLATFORM_MAX_PATH, logFile);
	
	failedtime++;
	IntToString(failedtime, restartcount, sizeof(restartcount));
	PrintToChatAll("\x03本关第\x04%s\x03次团灭", restartcount);
	Format(msg, sizeof(msg), "--====================================团灭————%s次====================================--", restartcount);
	SaveMessage(msg);
}

//上救援finale_win
public void finale_win(Event event, const char[] name, bool dontBroadcast)
{
	SaveMessage("--==================================成功救援==================================--");
	UPpdateAll();
}

// 地图结束（有点刷屏了，不用了）
/*	
public void OnMapEnd() {
	ChangeMapName();

	char msg[1024];
	char date[32];
	char time[32];
	char logFile[128];

	FormatTime(date, sizeof(date), "%y%m%d", -1);
	Format(logFile, sizeof(logFile), "/logs/chat%s.log", date);
	BuildPath(Path_SM, chatFile, PLATFORM_MAX_PATH, logFile);

	FormatTime(time, sizeof(time), "%Y-%m-%d %H:%M:%S", -1);
	Format(msg, sizeof(msg), "[%s] --- 地图结束: %s ---", time, logMapName);

	SaveMessage("____________________________________________________________________________________________");
	SaveMessage(msg);
	SaveMessage("¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯");
}
*/

// 获取地图信息,更新地图名
void ChangeMapName() {
	// 获取地图文件名 例如:(c2m1_higtway)
	GetCurrentMap(MapName, sizeof(MapName));
	gamemode=LMM_GetCurrentGameMode();

	for (int iMission=0; iMission < LMM_GetNumberOfMissions(gamemode); iMission++) {
		for (int iMap=0; iMap<LMM_GetNumberOfMaps(gamemode, iMission); iMap++) {
			LMM_GetMapName(gamemode, iMission, iMap, imapName, sizeof(imapName));
			if(strcmp(imapName, MapName) == 0){
				missionIndex = iMission;
				mapnow = iMap + 1;
				mapmaxnum = LMM_GetNumberOfMaps(gamemode, iMission);
				break;
			}
		}
	}
	LMM_GetMissionName(gamemode, missionIndex, MissionName, sizeof(MissionName));

	Format(MapName, sizeof(MapName), "%T", MapName, 0);	// 关卡翻译名 (黑色狂欢节)
	Format(MissionName, sizeof(MissionName), "%T", MissionName, 0);	// 地图翻译名 (高速公路)
	FormatEx(logMapName, sizeof(logMapName), "%s [%s] [%d/%d]", MissionName, MapName, mapnow, mapmaxnum); // 黑色狂欢节 [高速公路] [1/5]
}
