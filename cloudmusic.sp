#include <sourcemod>
#include <cURL>
#include <smjansson>

#define BUFLEN 20000
#define MENU_TIME 5

String:url[] = "http://music.163.com/api/search/get/web";
String:referer[] = "http://music.163.com/";
String:cookie[] = "appver=1.5.0.75771;";
String:playaddr[] = "http://music.163.com/outchain/player?type=2&id=%d&auto=1&height=66";

char jsonBuf[BUFLEN];
char song[20][32];
int id[20];
int song_len;
Handle hPlayer;
Handle hStop;
bool allow = true;
char playurl[512];

public Plugin:myinfo = {
    name = "CloudMusic",
    author = "まきちゃん~",
    description = "NetEase CloudMusic",
    version = "1.2",
    url = "moeub.com"
};

public OnPluginStart()
{
	RegConsoleCmd("sm_music", CloudMusic_Command);
	CloudMusic_StopInit();
	allow = true;
}

public OnPluginEnd()
{
	CloseHandle(hStop);
}

public Action CloudMusic_Command(int client, int args)
{
	if(args == 0)
	{
		PrintToChat(client, "usage: !music search <music name> or !music <url> or !music stop");
		return Plugin_Handled;
	}
	char arg1[8];
	GetCmdArg(1, arg1, sizeof(arg1));
	if(StrEqual(arg1, "search"))
	{
		if(args < 2)
		{
			PrintToChat(client, "usage: !music search <music name>");
			return Plugin_Handled;
		}
		if(!allow)
		{
			PrintToChat(client, "wait");
			return Plugin_Handled;
		}
		allow = false
		char name[64];
		GetCmdArgString(name, sizeof(name));
		for(int i = 0; i < 6; i++)
		{
			name[i] = ' ';
		}
		TrimString(name);
		PrintToChat(client, "arg1: %s, arg2: %s", arg1, name);
		CloudMusic_SearchAsync(client, name);
	}
	else if(StrEqual(arg1, "stop"))
	{
		CloudMusic_Stop(client);
	}
	else
	{
		GetCmdArgString(playurl, sizeof(playurl));
		allow = false;
		CloudMusic_PlayerInit();
		CloudMusic_Vote(client, "");
	}

	return Plugin_Handled;
}

void CloudMusic_SearchAsync(int client, const char[] name, offset = 0)
{
	Handle curl = curl_easy_init();
	if(curl == null)
	{
		return;
	}

	char buf[256];
	Format(buf, sizeof(buf), "s=%s&offset=%d&type=1&limit=20", name, offset);
	jsonBuf[0] = 0;
	curl_easy_setopt_string(curl, CURLOPT_URL, url);
   	curl_easy_setopt_string(curl, CURLOPT_COOKIE,cookie);
   	curl_easy_setopt_string(curl, CURLOPT_REFERER, referer);
	curl_easy_setopt_string(curl, CURLOPT_POSTFIELDS, buf);
	curl_easy_setopt_function(curl, CURLOPT_WRITEFUNCTION, CloudMusic_WriteFunc)

	curl_easy_perform_thread(curl, CloudMusic_SearchComplete, client);
}

public CloudMusic_SearchComplete(Handle handle, CURLcode code, any client)
{
	if(code != CURLE_OK)
	{
		CloudMusic_Error(handle, 0, "curl error", code);
		return;
	}

	Handle obj = json_load(jsonBuf);
	if(json_typeof(obj) != JSON_OBJECT)
	{
		CloudMusic_Error(handle, client, "json error");
		return;
	}

	CloudMusic_ProcessJSON(obj);
	CloudMusic_Menu(client);

	CloseHandle(handle);
}

int CloudMusic_WriteFunc(Handle handle, const String:buffer[], const bytes, const nmemb)
{
	StrCat(jsonBuf, BUFLEN, buffer);
	return bytes * nmemb;
}

void CloudMusic_ProcessJSON(Handle obj)
{
	Handle result = json_object_get(obj, "result");
	if(!json_is_object(result))
	{
		CloudMusic_Error(null, 0, "result is not object");
		return;
	}
	Handle songs = json_object_get(result, "songs");
	if(!json_is_array(songs))
	{
		CloudMusic_Error(null, 0, "songs is not array");
		return;
	}

	song_len = json_array_size(songs);
	for(int i = 0; i < song_len; i++)
	{
		Handle song_obj = json_array_get(songs, i);
		if(!json_is_object(song_obj))
		{
			CloudMusic_Error(null, 0, "song is not object");
			return;
		}
		json_object_get_string(song_obj, "name", song[i], 32);
		id[i] = json_object_get_int(song_obj, "id");
	}
}

CloudMusic_Menu(int client)
{
	Menu menu = CreateMenu(CloudMusic_MenuHandler);
	if(menu == null)
	{
		CloudMusic_Error(null, client, "CreateMenu Error");
		return;
	}

	menu.SetTitle("网易云音乐 by まきちゃん~");
	for(int i = 0; i < song_len; i++)
	{
		menu.AddItem("", song[i]);
	}
	menu.Display(client, MENU_TIME);
}

public int CloudMusic_MenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			Format(playurl, sizeof(playurl), playaddr, id[param2]);
			CloudMusic_PlayerInit();
			CloudMusic_Vote(param1, song[param2]);
		}
		case MenuAction_End:
		{
			CloseHandle(menu);
		}
		case MenuAction_Cancel:
		{
			allow = true;
		}
	}
}

CloudMusic_Vote(int client, char[] songName)
{
	Menu menu = CreateMenu(CloudMusic_VoteHandler);
	if(menu == null)
	{
		CloudMusic_Error(null, 0, "Vote Error");
		return;
	}
	menu.SetTitle("%N 推荐了音乐 %s", client, songName);
	menu.AddItem("", "yes");
	menu.AddItem("", "no");

	menu.DisplayVoteToAll(MENU_TIME);
}

public int CloudMusic_VoteHandler(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{
		if(param2 == 0)
		{
			CloudMusic_Play(param1);
		}
	}
	else if(action == MenuAction_End)
	{
		CloseHandle(hPlayer);
		CloseHandle(menu);
		allow = true;
	}
}

void CloudMusic_PlayerInit()
{
	hPlayer = CreateKeyValues("data");
	KvSetString(hPlayer, "title", "music");
	KvSetNum(hPlayer, "type", MOTDPANEL_TYPE_URL);
	KvSetString(hPlayer, "msg", playurl);
}

public Action CloudMusic_Play(int client)
{
	ShowVGUIPanel(client, "info", hPlayer, false);
}

CloudMusic_StopInit()
{
	hStop = CreateKeyValues("data");
	KvSetString(hStop, "title", "music");
	KvSetNum(hStop, "type", MOTDPANEL_TYPE_URL);
	KvSetString(hStop, "msg", "about:blank");
}

public Action CloudMusic_Stop(int client)
{
	ShowVGUIPanel(client, "info", hStop, false);
}

CloudMusic_Error(Handle handle, int client, const char[] msg, CURLcode code = CURLE_OK)
{
	if(handle != null)
	{
		CloseHandle(handle);
	}
	PrintToServer("CloudMusic Error:%s", msg);
	if(code != CURLE_OK)
	{
		PrintToServer("curl error: %d", code);
	}
	PrintToChat(client, "Error");
	allow = true;
}
