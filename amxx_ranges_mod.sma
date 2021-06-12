#include < amxmodx.inc >
#include < amxmisc.inc >
#include < geoip.inc >
#include < reapi.inc >
#include < adv_vault.inc >

#define PLUGIN "Rangos + Top (Original)"
#define VERSION "1.5b"
#define AUTHOR "Alfredo."

#define is_valid_player_alive(%0) (1 <= %0 <= MAX_PLAYERS && is_user_alive(%0))

new const theme[] = { "<meta charset=UTF-8>\
	<style>\
	@import url('https://fonts.googleapis.com/css?family=Roboto')\
	body{background: url('https://i.ibb.co/92hqcgP/BsHATaR.jpg');background-size: 100%%;margin-top:5;color:white;font-family:'Roboto', sans-serif;text-align:center;}\
	table{color:#FFF;font-size:12px;}\
	th{background:#b30707;padding:10px}\
	td{padding:8px;text-align:center;}\
	td{border-bottom:1px solid #b30707;}\
	</style>" 
}
new const g_hours[] = { 20, 21, 22, 23, 00, 01, 02, 03, 04, 05, 06, 07 }

new g_playername[MAX_PLAYERS+1][32]
new g_playerauthid[MAX_PLAYERS+1][32]

new g_ranges[MAX_PLAYERS+1]
new g_frags[MAX_PLAYERS+1]

new g_hud[MAX_PLAYERS+1]

new AdminType[MAX_PLAYERS+1][30]
new cvar_adminlisten, admlisten
new g_showhud[3]
new bool:g_happyhour

enum 
{
	CAMPO_RANGO,
	CAMPO_FRAGS,
	CAMPO_HUD,
	CAMPO_MAX
}

enum _:DATAMOD
{
	RANGES_NAMES[64],
	RANGES_FRAGS,
	RANGES_URL[200]
}

new const ranges[][DATAMOD] =
{
	{ "Sin Rango", 1, "https://i.ibb.co/HHzfg5T/0.png" },
	{ "Recluta", 50, "http://goo.gl/VG3qn8" },
	{ "Novato", 150, "http://goo.gl/kEZ4We" },
	{ "Principiante", 200, "http://goo.gl/mbEVzy" },
	{ "Sargento I", 400, "http://goo.gl/m2P7ni" },
	{ "Sargento II", 600, "http://goo.gl/Bh1Z4n" },
	{ "Sargento II", 800, "http://goo.gl/djXwQD" },
	{ "Sargento Grado I", 1200, "http://goo.gl/9LtLSi" },
	{ "Sargento Grado II", 1600, "http://goo.gl/Cr2Mrp" },
	{ "Sargento Grado II", 2000, "http://goo.gl/iPP9Eq" },
	{ "Sargento Grado Mayor", 3000, "http://goo.gl/iPP9Eq" },
	{ "Teniente", 5000, "http://goo.gl/QRQWY9" },
	{ "Teniente Mayor", 8000, "http://goo.gl/dsbScN" },
	{ "Coronel", 12000, "http://goo.gl/up6TSS" },
	{ "Coronel Mayor", 16000, "http://goo.gl/cMi8YK" },
	{ "General", 20000, "http://goo.gl/wP4VhK" },
	{ "General Mayor", 30000, "http://goo.gl/mXXCF2" },
	{ "General En Jefe", 50000, "http://goo.gl/SijqTy"}
}

enum _:ADM_DATA
{
	ADMIN_TYPE[30], 
	ADMIN_FLAGS
}

new const AdminsPrefix[][ADM_DATA] =
{
	{ "Fundador", ADMIN_RCON }, 
	{ "Staff", ADMIN_LEVEL_F }, 
	{ "Encargado", ADMIN_LEVEL_G },
	{ "Socio", ADMIN_LEVEL_H },
	{ "Administrador", ADMIN_ADMIN },  
	{ "VIP", ADMIN_KICK }
}

new const funcion_Top[][] = 
{
	"say /toprangos", "say toprangos", "say .toprangos", "say /toprank", "say toprank", "say .toprank", "say /tr", "say tr", "say .tr",
	"say_team /toprangos", "say_team toprangos", "say_team .toprangos", "say_team /toprank", "say_team toprank", "say_team .toprank", "say_team /tr", "say_team tr", "say_team .tr"
}

new const funcion_Rank[][] =
{
	"say /rankrangos", "say rankrangos", "say .rankrangos", "say /rankr", "say rankr", "say .rankr", "say /rr", "say rr", "say .rr",
	"say_team /rankrangos", "say_team rankrangos", "say_team .rankrangos", "say_team /rankr", "say_team rankr", "say_team .rankr", "say_team /rr", "say_team rr", "say_team .rr"
}


new const funcion_Hud[][] =
{
	"say /hud", "say hud", "say .hud", "say /h", "say h", "say .h",
	"say_team /hud", "say_team hud", "say_team .hud", "say_team /h", "say_team h", "say_team .h"
}

new g_campo[CAMPO_MAX]
new g_vault
new g_sort


enum (+=100)
{
	TASK_SHOWHUD
}

#define ID_SHOWHUD (taskid - TASK_SHOWHUD)


public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR)

	register_clcmd("say", "clcmd_say")
	register_clcmd("say_team", "clcmd_teamsay")

	register_concmd("amxx_dar_frags", "cmd_frags", _, "<Nombre> <Frags> - Dar frags a un jugador")

	for(new top = 0; top < sizeof funcion_Top; top++)
	register_clcmd(funcion_Top[top], "handler_top")

	for(new rank = 0; rank < sizeof funcion_Rank; rank++)
	register_clcmd(funcion_Rank[rank], "handler_rank")

	for(new hud = 0; hud < sizeof funcion_Hud; hud++)   
	register_clcmd(funcion_Hud[hud], "handler_hud")


	RegisterHookChain(RG_CBasePlayer_Killed, "@Killed_OnPlayer", .post = true)

	g_vault = adv_vault_open("amxx_ranges_vault", false)
	g_campo[CAMPO_RANGO] = adv_vault_register_field(g_vault, "Rangos")
	g_campo[CAMPO_FRAGS] = adv_vault_register_field(g_vault, "Frags")
	g_campo[CAMPO_HUD] = adv_vault_register_field(g_vault, "Hud")
	adv_vault_init(g_vault)

	g_sort = adv_vault_sort_create(g_vault, ORDER_DESC, 0, 2000, g_campo[CAMPO_RANGO], g_campo[CAMPO_FRAGS])

	cvar_adminlisten = register_cvar( "amx_adminlisten", "2" )
	admlisten = get_pcvar_num(cvar_adminlisten)

	g_showhud[0] = CreateHudSyncObj()
	g_showhud[1] = CreateHudSyncObj()
	g_showhud[2] = CreateHudSyncObj()
}

public plugin_cfg()
{
	set_task(0.1, "happy_hour")
}

public client_putinserver(id)
{
	get_user_name(id, g_playername[id], charsmax(g_playername[]))
	get_user_authid(id, g_playerauthid[id], charsmax(g_playerauthid[]))
	
	g_ranges[id] = 0
	g_frags[id] = 0
	g_hud[id] = 0
	AdminType[id] = "^0"

	if(is_user_admin(id))
	{
		static i, flags; flags = get_user_flags(id)

		for(i = 0 ; i < sizeof AdminsPrefix ; i++ )
		{
			if(flags & AdminsPrefix[i][ADMIN_FLAGS])
			{
				formatex(AdminType[id], charsmax(AdminType), "%s", AdminsPrefix[i][ADMIN_TYPE])
				break;
			}
		}
	}

	set_task(1.0, "ShowHUD", id + TASK_SHOWHUD,  _, _, "b")
	set_task(10.0, "happy_hour_info", 0)

	load_rangos(id)
}

public client_disconnected(id)
{
	remove_task(id + TASK_SHOWHUD)

	if(task_exists(id))
	remove_task(id)

	save_rangos(id)
}

@Killed_OnPlayer(victim, attacker)
{
	if(attacker == victim || !is_user_connected(victim) || !is_user_connected(attacker))
	return;

	if(g_happyhour)
	check_range_levelup(attacker, 2)
	else
	check_range_levelup(attacker, 1)
}

public check_range_levelup(id, frags)
{
	g_frags[id] += frags

	set_hudmessage(0, 255, -1, 0.5, 0.3, 0, 6.0, 1.1, 0.0, 0.0)
	ShowSyncHudMsg(id, g_showhud[2], "+%d Kill", frags)

	new range_levelup = false

	while(g_frags[id] >= ranges[g_ranges[id]][RANGES_FRAGS])
	{
		g_ranges[id]++
		range_levelup = true
	}

	if(range_levelup)
	{
		client_print_color(0, print_team_default, "^4AMXX |^1 el jugador:^3 %s^1 acaba de subir su rango a:^4 %s", g_playername[id], ranges[g_ranges[id]][RANGES_NAMES])
		//show_screenfade(id, 0, 150, 0)
	}
	save_rangos(id)
}

public ShowHUD(taskid)
{
	static id
	id = ID_SHOWHUD

	if(g_hud[id]) return;

	if(!is_valid_player_alive(id))
	{
		id = get_entvar(id, var_iuser2)
		if(!is_valid_player_alive(id)) return;
	}

	if(id != ID_SHOWHUD)
	{

		set_hudmessage(255, 255, 255, 0.3, 0.80, 0, 6.0, 1.1, 0.0, 0.0)
		ShowSyncHudMsg(ID_SHOWHUD, g_showhud[0], "Observando al jugador: %s^nRango: %s - Frag's: %d", g_playername[ID_SHOWHUD], ranges[g_ranges[ID_SHOWHUD]][RANGES_NAMES], g_frags[ID_SHOWHUD])

	}
	else
	{
		new Float:porcentage = (g_frags[ID_SHOWHUD] * 100.0)/ranges[g_ranges[ID_SHOWHUD]][RANGES_FRAGS]
		set_hudmessage(255, 255, 255, 0.02, 0.17, 0, 6.0, 1.1, 0.0, 0.0)
		ShowSyncHudMsg(ID_SHOWHUD, g_showhud[0], "| Rango: %s |^n| Frag%s: %d/%d (%.2f%%) |^n| Hora Feliz: %s |", ranges[g_ranges[ID_SHOWHUD]][RANGES_NAMES], g_frags[ID_SHOWHUD] == 1? "" : "'s", g_frags[ID_SHOWHUD], (ranges[g_ranges[ID_SHOWHUD]][RANGES_FRAGS]), porcentage, g_happyhour ? "Activada" : "Desactivada")
	}
}

public clcmd_say(id)
{

	static said[191];

	read_args(said, charsmax(said));
	remove_quotes(said);
	replace_all(said, charsmax(said), "#", " ");


	if (!ValidMessage(said, 1)) return PLUGIN_CONTINUE;

	static color[11], prefix[91]
	get_user_team(id, color, charsmax(color))
	if(is_user_admin(id))
	formatex(prefix, charsmax(prefix), "%s^x01[ ^x04%s ^x01][ ^x04%s ^x01] ^x03%s:", is_user_alive(id) ? "^x01" : "^x03*MUERTO* ",  AdminType[id], ranges[g_ranges[id]][RANGES_NAMES], g_playername[id])
	else
	formatex(prefix, charsmax(prefix), "%s^x01[ ^x04Jugador ^x01][ ^x04%s ^x01] ^x03%s:", is_user_alive(id) ? "^x01" : "^x03*MUERTO* ", ranges[g_ranges[id]][RANGES_NAMES], g_playername[id])


	if(is_user_admin(id)) format(said, charsmax(said), "^x04%s", said)    

	format(said, charsmax(said), "%s^x01 %s", prefix, said)

	static i, team[11];
	for (i = 1; i <= get_maxplayers(); i++)
	{
		if (!is_user_connected(i)) continue;

		if( admlisten == 0 && ( is_user_alive(id) && is_user_alive(i) || !is_user_alive(id) && !is_user_alive(i))
		|| admlisten == 1 && (is_user_admin(i) || is_user_alive(id) && is_user_alive(i) || !is_user_alive(id) && !is_user_alive(i))
		|| admlisten == 2 )
		{
			        
			get_user_team(i, team, charsmax(team))            
			changeTeamInfo(i, color)            
			writeMessage(i, said)
			changeTeamInfo(i, team)
		}
	}

	return PLUGIN_HANDLED_MAIN;
}

public clcmd_teamsay(id)
{
	static said[191];

	read_args(said, charsmax(said));
	remove_quotes(said);
	replace_all(said, charsmax(said), "#", " ");

	if (!ValidMessage(said, 1)) return PLUGIN_CONTINUE;

	static playerTeam, teamname[19];
	playerTeam = get_user_team(id);

	switch (playerTeam)
	{
		case 1: formatex( teamname, 18, "^x01[^x03 Rojos ^x01]")
		case 2: formatex( teamname, 18, "^x01[^x03 Azules ^x01]")
		default: formatex( teamname, 18, "^x01[^x03 Espectador ^x01]")
	}

	static color[11], prefix[91]
	get_user_team(id, color, charsmax(color))

	formatex(prefix, charsmax(prefix), "%s%s^x01[^x04 %s ^x01]^x03 %s",
	is_user_alive(id) ? "^x01" : "^x01*MUERTO* ",  teamname, AdminType[id], g_playername[id])

	if(is_user_admin(id)) format(said, charsmax(said), "^x04%s", said)    

	format(said, charsmax(said), "%s^x01: %s", prefix, said)

	static i, team[11];
	for (i = 1; i <= get_maxplayers(); i++)
	{
		if (!is_user_connected(i)) continue;

		if (get_user_team(i) == playerTeam)
		{
			if( admlisten == 0 && ( is_user_alive(id) && is_user_alive(i) || !is_user_alive(id) && !is_user_alive(i))
			|| admlisten == 1 && (is_user_admin(i) || is_user_alive(id) && is_user_alive(i) || !is_user_alive(id) && !is_user_alive(i))
			|| admlisten == 2 )
			{
				        
				get_user_team(i, team, charsmax(team))            
				changeTeamInfo(i, color)            
				writeMessage(i, said)
				changeTeamInfo(i, team)
			}
		}
	}

	return PLUGIN_HANDLED_MAIN;
}

public changeTeamInfo(player, team[])
{
	message_begin(MSG_ONE, get_user_msgid( "TeamInfo" ), _, player)
	write_byte(player)
	write_string(team)
	message_end()
}

public writeMessage(player, message[])
{
	message_begin(MSG_ONE, get_user_msgid( "SayText" ), {0, 0, 0}, player)
	write_byte(player)
	write_string(message)
	message_end()
}

stock ValidMessage(text[], maxcount)
{
	static len, i, count;
	len = strlen(text);
	count = 0;

	if (!len) return false;

	for (i = 0; i < len; i++)
	{
		if (text[i] != ' ')
		{
			count++
			if (count >= maxcount)
			return true;
		}
	}

	return false;
}

public handler_top(id) 
{
	adv_vault_sort_update(g_vault, g_sort);

	static len
	len = 0

	new motd[3600], name[64], rangos, frags, keyindex

	new toploop = min(adv_vault_sort_numresult(g_vault, g_sort), 6)

	len += formatex(motd[len], sizeof motd-len, theme)
	len += formatex(motd[len], sizeof motd-len, "<table width='100%%'><tr><th width=5%%>#<th width=30%%>Jugador<th width=25%%>Rango<th width=15%%>Frags<th width=15%%><font color='yellow'>Insignia</font></tr>")

	for(new posicion = 1; posicion <= toploop; posicion++)
	{
		keyindex = adv_vault_sort_position(g_vault, g_sort, posicion)

		if(!adv_vault_get_prepare(g_vault, keyindex)) continue;

		rangos = adv_vault_get_field(g_vault, g_campo[CAMPO_RANGO])
		frags = adv_vault_get_field(g_vault, g_campo[CAMPO_FRAGS])

		adv_vault_get_keyname(g_vault, keyindex, name, charsmax(name))
		len += formatex(motd[len], sizeof motd-len, "<tr><td>%d<td>%s<td>%s<td>%d<td><img src= '%s' width=80 hight=30/></tr>", posicion, name, ranges[rangos][RANGES_NAMES], frags, ranges[rangos][RANGES_URL])
	}

	len += formatex(motd[len], sizeof motd-len, "</table>")
	show_motd(id, motd, "[Central|Gamers] | TOP - RANGOS")
}

/*public handler_top(id) 
{
	adv_vault_sort_update(g_vault, g_sort);

	static len
	len = 0

	new motd[3600], name[64], rangos, frags, keyindex

	new toploop = min(adv_vault_sort_numresult(g_vault, g_sort), 10)

	len += formatex(motd[len], sizeof motd-len, theme)
	len += formatex(motd[len], sizeof motd-len, "<table width='100%%'><tr><th width=5%%><font color='blue'>#</font><th width=50%%>Jugador<th width=15%%>Rango<th width=15%%>Frags<th width=15%%>Insignia</tr>")

	for(new posicion = 1; posicion <= toploop; posicion++)
	{
		keyindex = adv_vault_sort_position(g_vault, g_sort, posicion)

		if(!adv_vault_get_prepare(g_vault, keyindex)) continue;

		rangos = adv_vault_get_field(g_vault, g_campo[CAMPO_RANGO])
		frags = adv_vault_get_field(g_vault, g_campo[CAMPO_FRAGS])

		adv_vault_get_keyname(g_vault, keyindex, name, charsmax(name))

		//len += formatex(motd[len], sizeof motd-len, "<center><h1><font color'white'>TOP RANGOS 2021</font></h1></center>") 
		len += formatex(motd[len], sizeof motd-len, "<tr><td>%d<td>%s<td>%s<td>%d<td><img src= '%s' width=80 hight=30/></tr>", posicion, name, ranges[rangos][RANGES_NAMES], frags, ranges[rangos][RANGES_URL])
	}

	len += formatex(motd[len], sizeof motd-len, "</table>")
	show_motd(id, motd, "TOP RANGOS | CTF")
	return PLUGIN_HANDLED;
}*/

public handler_rank(id)
{
	new rank_position = adv_vault_sort_key(g_vault, g_sort, 0, g_playername[id])

	if(!rank_position) client_print_color(id, print_team_default, "^4AMXX | ^1No estÃ¡s dentrÃ³ del ranking ^4top 10")
	else client_print_color(id, print_team_default, "^4AMXX | ^1Tu ranking es: ^4%d^3/^4%d^1. Rango: ^4%s ^3| ^1Sig.Rango: ^4%s^1.", rank_position, adv_vault_sort_numresult(g_vault, g_sort), ranges[g_ranges[id]][RANGES_NAMES], ranges[g_ranges[id]+1][RANGES_NAMES])
	return PLUGIN_HANDLED;
}

public cmd_frags(id, level, cid)
{
	if (!cmd_access(id, ADMIN_LEVEL_C, cid, 2))
	return PLUGIN_HANDLED;

	static arg[32], arg2[6], g_amount

	read_argv(1, arg, sizeof arg -1)
	read_argv(2, arg2, sizeof arg2 - 1)

	new g_player = cmd_target(id, arg, CMDTARGET_NO_BOTS | CMDTARGET_ALLOW_SELF)

	if(!g_player)
	{
		client_print(id, print_console, "[AMXX - ERROR] El jugador no se encuentra en el server. [NO FUNCIONA]")
		return PLUGIN_HANDLED;
	}

	g_amount = (str_to_num(arg2))

	client_print_color(0, print_team_default, "^4AMXX | ^1 El admin:^4 %s^1 le ha dado:^3 '+%s FRAGS'^1 a:^4 %s^1.", g_playername[id], add_point(g_amount), g_playername[g_player])
	client_print_color(g_player, print_team_default, "^4AMXX |^1 El admin:^4 %s^1 te ha dado:^4 '+%s FRAGS'^1.", g_playername[id], add_point(g_amount))
	check_range_levelup(g_player, g_amount)

	save_rangos(g_player)

	return PLUGIN_HANDLED;
}

save_rangos(id)
{
	adv_vault_set_start(g_vault)

	adv_vault_set_field(g_vault, g_campo[CAMPO_RANGO], g_ranges[id])
	adv_vault_set_field(g_vault, g_campo[CAMPO_FRAGS], g_frags[id])
	adv_vault_set_field(g_vault, g_campo[CAMPO_HUD], g_hud[id])

	adv_vault_set_end(g_vault, 0, g_playername[id])
}

load_rangos(id)
{
	if(!adv_vault_get_prepare(g_vault, _, g_playername[id]))
	return;

	g_ranges[id] = adv_vault_get_field(g_vault, g_campo[CAMPO_RANGO])
	g_frags[id] = adv_vault_get_field(g_vault, g_campo[CAMPO_FRAGS])
	g_hud[id] = adv_vault_get_field(g_vault, g_campo[CAMPO_HUD], g_hud[id], sizeof g_hud[])
}

public handler_hud(id) 
{
	if(g_hud[id])
	{
		g_hud[id] = 0
		client_print_color(id, print_team_default, "^4AMXX | ^1Activaste el hud de los rangos^4.^1 Para des-activarlo usa: ^4/hud")
	}
	else 
	{
		g_hud[id] = 1
		client_print_color(id, print_team_default, "^4AMXX | ^1Des-activaste el hud de los rangos^4.^1 Para activarlo usa: ^4/hud")
	}
}

public happy_hour()
{
	new time_data[12]
	get_time("%H", time_data, 12)

	new g_time = str_to_num(time_data)

	// Time function
	for(new i = 0; i <= sizeof(g_hours)- 1; i++)
	{
			
		// Hour isn't the same?
		if(g_time != g_hours[i]) continue;

		// Enable happy time
		g_happyhour = true

		break;
	}
}

public happy_hour_info()
{
	new hour[12]
	get_time("%H:%M:%S", hour, charsmax(hour))

	if(g_happyhour)
	{
		client_print_color(0, print_team_default, "^4AMXX | ^1La hora feliz estÃ¡: ^4des-activada^1. Empieza: ^38pm ^1Termina:^3 7am^1. Hora actual: ^4%s", hour)
	}
	else
	{
		client_print_color(0, print_team_default, "^4AMXX | ^1La hora feliz estÃ¡: ^4activada^1. Termina:^3 7am^1. Hora actual: ^3%s", hour)
		client_print_color(0, print_team_default, "^4AMXX | ^1La hora feliz estÃ¡: ^4activada^1. Termina:^3 7am^1. Hora actual: ^3%s", hour)
		client_print_color(0, print_team_default, "^4AMXX | ^1La hora feliz estÃ¡: ^4activada^1. Termina:^3 7am^1. Hora actual: ^3%s", hour)
	}
}

public get_player_steam(id)
{
	if(contain(g_playerauthid[id], "STEAM_0:") != -1)
	return true;

	return false;
}

public show_screenfade(id, red, green, blue)
{
	// Screen fading
	message_begin(MSG_ONE, get_user_msgid("ScreenFade"), {0,0,0}, id)
	write_short(1<<10)
	write_short(1<<10)
	write_short(0x0000)
	write_byte(red) // rrr
	write_byte(green) // ggg
	write_byte(blue) // bbb
	write_byte(75)
	message_end()
}


stock add_point(number)
{
	 
	new count, i, str[29], str2[35], len
	num_to_str(number, str, charsmax(str))
	len = strlen(str)

	for (i = 0; i < len; i++)
	{
		if (i != 0 && ((len - i) %3 == 0))
		{
			add(str2, charsmax(str2), ".", 1)
			count++
			add(str2[i+count], 1, str[i], 1)
		}
		else
		add(str2[i+count], 1, str[i], 1)
	}

	return str2;
}


/* AMXX-Studio Notes - DO NOT MODIFY BELOW HERE
*{\\ rtf1\\ ansi\\ deff0{\\ fonttbl{\\ f0\\ fnil Tahoma;}}\n\\ viewkind4\\ uc1\\ pard\\ lang8202\\ f0\\ fs16 \n\\ par }
*/
