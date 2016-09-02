#include <sourcemod>
#include <sdktools>
#include <halflife>
#include <Regex>
#include <string>

int count;
Handle hHud;
Handle timer;
Regex regex1;
Regex regex2;

public Plugin myinfo =
{
    name = "Door Tip",
    author = "まきちゃん~",
    description = "Door Tip",
    version = "1.0",
    url = "moeub.com"
};

public OnPluginStart()
{
	//HookEvent("round_freeze_end", func);
	HookEvent("round_end", Event_RoundEnd);
	HookEvent("player_say", Event_PlayerSay);
	timer = null;
	hHud = null;
	count = 0;
	regex1 = CompileRegex("[(in)(IN)] ([0-9]+) [(sec)(seconds)(SEC)(SECONDS)sS]");
	regex2 = CompileRegex("([0-9]+)");
}

public OnMapStart()
{
	TipClean();
}

/*
Action func(Event event, const char[] name, bool dontBroadcast)
{
	int t = ParseString("*** in 20 sec");
	if(t != 0)
	{
		TipCreate(t);
	}
}*/

Action Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	TipClean();
}

Action Event_PlayerSay(Event event, const char[] name, bool dontBroadcast)
{
	TipClean();
	int clientid = event.GetInt("userid");
	int client = GetClientOfUserId(clientid);
	//PrintToChatAll("matching");
	if(GetClientOfUserId(client) == 0)
	{
		//PrintToChatAll("client = 0, matching");
		char msg[255];
		event.GetString("text", msg, sizeof(msg));

		int t = ParseString(msg);
		if(t != 0)
		{
			TipCreate(t);
		}
	}
	return Plugin_Continue;
}

int ParseString(const char[] str)
{
	char buffer1[255];
	char buffer2[255];

	if(regex1.Match(str) == -1)
	{
		return 0;
	}
	if(!regex1.GetSubString(0, buffer1, sizeof(buffer1)))
	{
		return 0;
	}
	if(regex2.Match(buffer1) == -1)
	{
		return 0;
	}
	if(!regex2.GetSubString(0, buffer2, sizeof(buffer2)))
	{
		return 0;
	}
	//PrintToChatAll("buffer1 = %s, buffer2 = %s", buffer1, buffer2);
	int ret = StringToInt(buffer2, 0);
	return ret;
}

void TipCreate(int n)
{
	hHud = CreateHudSynchronizer();
	count = n;
	SetHudTextParams(-1.0, 0.4, 1.0, 255, 0, 0, 0, 0, 0.0, 0.0, 0.0);
	for(int client = 1; client < GetMaxClients(); client++)
	{
		if(IsClientInGame(client))
		{
			ShowSyncHudText(client, hHud, "%d", count);
		}
	}
	if(timer != null)
	{
		KillTimer(timer);
		timer = null;
	}
	timer = CreateTimer(1.0, TipUpdate, _, TIMER_REPEAT);
}

Action TipUpdate(Handle _timer)
{
	count--;

	//PrintToChatAll("count = %d", count);
	if(count == 0)
	{
		SetHudTextParams(-1.0, 0.4, 5.0, 0, 255, 0, 0, 0, 0.0, 0.0, 0.0);
		for(int client = 1; client < GetMaxClients(); client++)
		{
			if(IsClientInGame(client))
			{
				ClearSyncHud(client, hHud);
				ShowSyncHudText(client, hHud, "GO!");
			}
		}
		CloseHandle(hHud);
		timer = null;
		hHud = null;
		return Plugin_Stop;
	}
	else
	{
		for(int client = 1; client < GetMaxClients(); client++)
		{
			if(IsClientInGame(client))
			{
				ClearSyncHud(client, hHud);
				ShowSyncHudText(client, hHud, "%d", count);
			}
		}
		return Plugin_Continue;
	}
}

void TipClean()
{
	if(timer !=null)
	{
		KillTimer(timer);
		timer = null;
	}
	if(hHud != null)
	{
		CloseHandle(hHud);
		hHud = null;
	}
}
