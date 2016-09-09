#include <sourcemod>
#include <cURL>
#include <smjansson>

#define BUFLEN 20000
#define MENU_TIME 30

String:url[] = "http://music.163.com/api/search/get/web";
String:referer[] = "http://music.163.com/";
String:cookie[] = "appver=1.5.0.75771;";
String:playaddr[] = "http://music.163.com/outchain/player?type=2&id=%d&auto=1&height=66";

char jsonBuf[BUFLEN];
bool ready;
char song[15][32];
int id[15];
int song_len;
Handle hMOTD;
Handle hStop;

public Plugin:myinfo = {
    name = "CloudMusic",
    author = "まきちゃん~",
    description = "NetEase CloudMusic",
    version = "1.1",
    url = "moeub.com"
};

public OnPluginStart()
{
	RegConsoleCmd("sm_music", CloudMusic_Command);
	RegConsoleCmd("sm_musicstop", CloudMusic_Stop);

	hStop = CreateKeyValues("data");
	KvSetString(hStop, "title", "music");
	KvSetNum(hStop, "type", MOTDPANEL_TYPE_URL);
	KvSetString(hStop, "msg", "about:blank");

	hMOTD = null;
	ready = true;
}

public OnPluginEnd()
{
	if(hMOTD != null)
	{
		CloseHandle(hMOTD);
	}
	CloseHandle(hStop);
}

public Action CloudMusic_Command(int client, int args)
{
	if(args != 1)
	{
		PrintToChat(client, "usage: !music <music name>");
		return Plugin_Handled;
	}
	if(hMOTD != null)
	{
		PrintToChat(client, "wait");
		return Plugin_Handled;
	}

	char name[128];
	GetCmdArgString(name, sizeof(name));
	PrintToChat(client, "searching: %s", name);
	CloudMusic_SearchAsync(client, name);
	return Plugin_Handled;
}

void CloudMusic_SearchAsync(int client, const char[] name, offset = 0)
{
	Handle curl = curl_easy_init();
	if(curl == INVALID_HANDLE)
	{
		return;
	}

	char buf[256];
	Format(buf, sizeof(buf), "s=%s&offset=%d&type=1&limit=15", name, offset);
	jsonBuf[0] = 0;
	curl_easy_setopt_string(curl, CURLOPT_URL, url);
   	curl_easy_setopt_string(curl, CURLOPT_COOKIE,cookie);
   	curl_easy_setopt_string(curl, CURLOPT_REFERER, referer);
	curl_easy_setopt_string(curl, CURLOPT_POSTFIELDS, buf);
	curl_easy_setopt_function(curl, CURLOPT_WRITEFUNCTION, CloudMusic_WriteFunc)
	curl_easy_setopt_int(curl, CURLOPT_WRITEDATA, client);

	curl_easy_perform_thread(curl, CloudMusic_SearchComplete, client);
}

public CloudMusic_SearchComplete(Handle handle, CURLcode code, any client)
{
	if(code != CURLE_OK)
	{
		CloudMusic_Error(handle, code, 0, "curl error");
		return;
	}

	Handle obj = json_load(jsonBuf);
	if(json_typeof(obj) != JSON_OBJECT)
	{
		CloudMusic_Error(handle, 0, client, "json error");
		return;
	}

	CloudMusic_ProcessJSON(obj);
	CloudMusic_Menu(client);

	CloseHandle(handle);
}

int CloudMusic_WriteFunc(Handle handle, const String:buffer[], const bytes, const nmemb, any client)
{
	StrCat(jsonBuf, BUFLEN, buffer);
	return bytes * nmemb;
}

void CloudMusic_ProcessJSON(Handle obj)
{
	Handle result = json_object_get(obj, "result");
	if(!json_is_object(result))
	{
		CloudMusic_Error(null, 0, 0, "result is not object");
		return;
	}
	Handle songs = json_object_get(result, "songs");
	if(!json_is_array(songs))
	{
		CloudMusic_Error(null, 0, 0, "songs is not array");
		return;
	}

	song_len = json_array_size(songs);
	for(int i = 0; i < song_len; i++)
	{
		Handle song_obj = json_array_get(songs, i);
		if(!json_is_object(song_obj))
		{
			CloudMusic_Error(null, 0, 0, "song is not object");
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
		CloudMusic_Error(null, 0, client, "CreateMenu Error");
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
	if(action == MenuAction_Select)
	{
		char playurl[128];
		Format(playurl, sizeof(playurl), playaddr, id[param2]);

		hMOTD = CreateKeyValues("data");
		KvSetString(hMOTD, "title", "music");
		KvSetNum(hMOTD, "type", MOTDPANEL_TYPE_URL);
		KvSetString(hMOTD, "msg", playurl);

		CloudMusic_Vote(param1, param2);
	}
	else if(action == MenuAction_End)
	{
		CloseHandle(menu);
	}
}

CloudMusic_Vote(int client, int songid)
{
	Menu menu = CreateMenu(CloudMusic_VoteHandler);
	if(menu == null)
	{
		CloudMusic_Error(null, 0, 0, "Vote Error");
		return;
	}
	menu.SetTitle("%N 推荐了音乐 %s", client, song[songid]);
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
			ShowVGUIPanel(param1, "info", hMOTD, false);
		}
	}
	else if(action == MenuAction_End)
	{
		CloseHandle(hMOTD);
		hMOTD = null;
		CloseHandle(menu);
		ready = true;
	}
}

public Action CloudMusic_Stop(int client, int args)
{
	ShowVGUIPanel(client, "info", hStop, false);
}

public CloudMusic_Error(Handle handle, CURLcode code, int client, const char[] msg)
{
	if(handle != null)
	{
		CloseHandle(handle);
	}
	PrintToServer("CloudMusic Error:%s", msg);
	ready = true;
}
