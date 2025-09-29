namespace vs
{

array<string> teams(HL_MAX_TEAMS);

void hl_set_user_frags( CBaseEntity@ pEntity, float frags )
{
	CBasePlayer@ pPlayer = cast<CBasePlayer@>( pEntity );
	if( pPlayer is null or !pPlayer.IsConnected() )
		return;

	pPlayer.pev.frags = frags;

	if( vs::EXPERIMENTAL )
	{
		NetworkMessage m1( MSG_ALL, NetworkMessages::ScoreInfo );
			m1.WriteByte( pPlayer.entindex() );
			m1.WriteShort( int(frags) );
			m1.WriteShort( pPlayer.m_iDeaths );
			m1.WriteShort( 0 );
			m1.WriteShort( __get_user_team(pPlayer) ); //g_pGameRules->GetTeamIndex( pPlayer->m_szTeamName ) + 1
		m1.End();
	}
}

void hl_set_user_score( CBasePlayer@ pPlayer, int frags, int deaths )
{
	pPlayer.pev.frags = float( frags );
	pPlayer.m_iDeaths = deaths;

	if( vs::EXPERIMENTAL )
	{
		NetworkMessage m1( MSG_ALL, NetworkMessages::ScoreInfo );
			m1.WriteByte( pPlayer.entindex() );
			m1.WriteShort( frags );
			m1.WriteShort( deaths );
			m1.WriteShort( 0 );
			m1.WriteShort( __get_user_team(pPlayer) ); //g_pGameRules->GetTeamIndex( pPlayer->m_szTeamName ) + 1
		m1.End();
	}
}

string hl_get_user_model( CBasePlayer@ client )
{
	KeyValueBuffer@ pInfo = g_EngineFuncs.GetInfoKeyBuffer( client.edict() );
	return pInfo.GetValue( "model" );
}

// Returns team id. When length is greater than 0 then a name of team is set.
int hl_get_user_team( CBasePlayer@ client, string &out team = "", int len = 0 )
{
	if( hl_get_user_spectator(client) )
		return 0;

	//if( g_Engine.teamplay < 1.0 ) return 0;

	if( len <= 0 ) len = HL_MAX_TEAMNAME_LENGTH;
	team = hl_get_user_model( client );

	return __get_team_index( team );
}

// ignores if player is in spec or not
int __get_user_team( CBasePlayer@ client, string team = "", int len = 0 )
{
	/*static Float:tdm;
	global_get(glb_teamplay, tdm);
	if (tdm < 1.0) return 0;*/

	if( len == 0 ) len = HL_MAX_TEAMNAME_LENGTH;
	team = hl_get_user_model( client );

	return __get_team_index(team);
}


int __get_team_index( const string &in team )
{
	//static teamid;
	int teamid = 0;
	//static valid;
	bool valid = false; //int valid = 0;
	//static i;

	//__count_teams();


	for( uint i = 0; i < teams.length(); i++ )
	{
		teamid++;
		//if( equali(teams[i][0], team) )
		if( teams[i] == team )
		{
			valid = true;
			break;
		}
	}

	if( valid )
		return teamid;

	return 0;
}

int __count_teams()
{
	//if( !teams[0][0] )
	if( teams.isEmpty() )
	{
		/*new teamlist[HL_MAX_TEAMLIST_LENGTH];
		get_cvar_string("mp_teamlist", teamlist, charsmax(teamlist));
		__explode_teamlist(teams, charsmax(teams[]), teamlist, ';');*/
		string teamlist = g_EngineFuncs.CVarGetString( "mp_teamlist" );
		teams = teamlist.Split( ";" );
	}

	int teamcount = 0; //static

	if( teamcount == 0)
	{
		for( uint i = 0; i <= teams.length(); i++ )
		{
			if( teams[i] != "" ) //if (teams[i][0])
				teamcount++;
		}
	}

	return teamcount;
}

bool hl_get_user_spectator( CBasePlayer@ client )
{
	return client.GetObserver().IsObserver();
}

void hl_set_user_spectator( CBasePlayer@ pPlayer, bool spectator = true )
{
	if( hl_get_user_spectator(pPlayer) == spectator )
		return;

	if( spectator )
	{

		bool bAllowSpectators = g_EngineFuncs.CVarGetFloat("allow_spectators") == 1;

		if( !bAllowSpectators )
			g_EngineFuncs.CVarSetFloat( "allow_spectators", 1.0 );

        pPlayer.GetObserver().StartObserver( pPlayer.GetOrigin(), pPlayer.pev.angles, false ); //hl_set_user_spectator(id);
		pPlayer.pev.nextthink = g_Engine.time + 99999.0; //without this, players will auto-respawn when mp_respawndelay is up or 0
	}
	else
	{
		pPlayer.GetObserver().StopObserver( true );
/*
		hl_user_spawn(client);

		set_pev(client, pev_iuser1, 0);
		set_pev(client, pev_iuser2, 0);

		set_ent_data(client, "CBasePlayer", "m_iHideHUD", 0);
*/
		string szTeam;
		hl_get_user_team( pPlayer, szTeam );

		// this fix when using openag client the scoreboard user colors
		if( vs::EXPERIMENTAL )
		{
			NetworkMessage m1( MSG_ALL, NetworkMessages::Spectator ); //98
				m1.WriteByte( pPlayer.entindex() );
				m1.WriteByte( 0 );
			m1.End();

			NetworkMessage m2( MSG_ALL, NetworkMessages::TeamInfo ); //84
				m2.WriteByte( pPlayer.entindex() );
				m2.WriteString( szTeam );
			m2.End();
		}
	}
}

bool hl_get_user_longjump( CBasePlayer@ pPlayer )
{
	KeyValueBuffer@ pInfo = g_EngineFuncs.GetPhysicsKeyBuffer( pPlayer.edict() );
	string sLongJump = pInfo.GetValue( "slj" );

	return sLongJump == "1";
}

void hl_set_user_longjump( CBasePlayer@ pPlayer, bool longjump = true, bool tempicon = true )
{
	if( longjump == hl_get_user_longjump(pPlayer) )
		return;

	KeyValueBuffer@ pInfo = g_EngineFuncs.GetPhysicsKeyBuffer( pPlayer.edict() );

	if( longjump )
	{
		pInfo.SetValue( "slj", "1" ); //engfunc(EngFunc_SetPhysicsKeyValue, client, "slj", "1");

		if( tempicon )
		{
			NetworkMessage m1( MSG_ONE, NetworkMessages::ItemPickup, pPlayer.edict() ); //90
				m1.WriteString( "item_longjump" );
			m1.End();
		}
	}
	else
		pInfo.SetValue( "slj", "0" ); //engfunc(EngFunc_SetPhysicsKeyValue, client, "slj", "0");

	pPlayer.m_fLongJump = longjump;
}

// Set team names in player scoreboard. Use 0 for all clients.
//  Example: hl_set_user_teamnames(id, "Blue", "Red");
void hl_set_user_teamnames( CBasePlayer@ pPlayer, string &in s1 = "", string &in s2 = "", string &in s3 = "", string &in s4 = "", string &in s5 = "", string &in s6 = "", string &in s7 = "", string &in s8 = "", string &in s9 = "", string &in s10 = ""/*any:...*/ )
{
	if( !EXPERIMENTAL )
		return;

	array<string> args = { s1, s2, s3, s4, s5, s6, s7, s8, s9, s10 };
	array<string> arrsTeamnames; //[HL_TEAMNAME_LENGTH]

	for( uint i = 0; i < args.length(); i++ )
	{
		if( args[i].IsEmpty() )
			continue;

		arrsTeamnames.insertLast( args[i] );

		if( DEBUG )
			g_Game.AlertMessage( at_notice, "Added team %1 at index %2\n", args[i], i );
	}

	int numTeams = Math.clamp( 0, HL_MAX_TEAMS, arrsTeamnames.length() /*- 1*/ );
	if( DEBUG )
		g_Game.AlertMessage( at_notice, "numTeams %1\n", numTeams );

	if( pPlayer !is null )
	{
		NetworkMessage m1( MSG_ONE, NetworkMessages::TeamNames, pPlayer.edict() ); //123
			m1.WriteByte( numTeams );
			for( int j = 0; j < numTeams; j++ )
				m1.WriteString( arrsTeamnames[j] );
		m1.End();
	}
	else
	{
		NetworkMessage m1( MSG_ALL, NetworkMessages::TeamNames ); //123
			m1.WriteByte( numTeams );
			for( int j = 0; j < numTeams; j++ )
				m1.WriteString( arrsTeamnames[j] );
		m1.End();
	}
}

// Set team score in player scoreboard. This will override the combined player scores.
//  Use null for all clients.
//  Warning: Team score gets switched when player changes his team. Send another message to keep this updated.
void hl_set_user_teamscore( CBasePlayer@ pPlayer, const string &in teamname, int frags, int deaths = 0 )
{
	if( !vs::EXPERIMENTAL )
		return;

	if( pPlayer !is null )
	{
		NetworkMessage m1( MSG_ONE, NetworkMessages::TeamScore, pPlayer.edict() ); //85
			m1.WriteString( teamname );
			m1.WriteShort( frags );
			m1.WriteShort( deaths );
		m1.End();
	}
	else
	{
		NetworkMessage m1( MSG_ALL, NetworkMessages::TeamScore ); //85
			m1.WriteString( teamname );
			m1.WriteShort( frags );
			m1.WriteShort( deaths );
		m1.End();
	}
}

void PlayerSilentKill( CBasePlayer@ pPlayer, CBaseEntity@ pKiller, bool bIncreaseDeaths = true, int bitsDamageType = 0, bool bGib = false )
{
	if( (!HasFlags(bitsDamageType, DMG_NEVERGIB) and bGib) or HasFlags(bitsDamageType, DMG_ALWAYSGIB) )
	{
		pPlayer.GibMonster();
		pPlayer.pev.effects |= EF_NODRAW;
	}

	pPlayer.Killed( null, GIB_NOPENALTY );

	if( bIncreaseDeaths )
		pPlayer.m_iDeaths++;

	if( pKiller !is null )
		pKiller.pev.frags++;
}

HUDTextParams set_hudmessage( uint8 red = 200, uint8 green = 100, uint8 blue = 0, float x = -1.0, float y = 0.35, int effect = 0, float fxtime = 6.0, float holdtime = 12.0, float fadeintime = 0.1, float fadeouttime = 0.2, int channel = -1 )
{
	HUDTextParams textParms;
	textParms.r1 = Math.clamp( 0, 255, red );
	textParms.g1 = Math.clamp( 0, 255, green );
	textParms.b1 = Math.clamp( 0, 255, blue );
	textParms.x = Math.clamp( -1, 1.0f, x );
	textParms.y = Math.clamp( -1, 1.0f, y );
	textParms.effect = Math.clamp( 0, 2, effect );
	textParms.fxTime = fxtime;
	textParms.holdTime = holdtime;
	textParms.fadeinTime = fadeintime;
	textParms.fadeoutTime = fadeouttime;
	textParms.channel = Math.clamp( 1, 4, channel );

	return textParms;
}

void show_hudmessage( const int &in id, string sMessage, HUDTextParams textParms )
{
	if( id == 0 )
		g_PlayerFuncs.HudMessageAll( textParms, sMessage ); 
	else
	{
		if( id < 1 or id > g_Engine.maxClients )
		{
			//Log( "Invalid player id in show_hudmessage " + id );

			return;
		}

		CBasePlayer@ pPlayer = g_PlayerFuncs.FindPlayerByIndex(id);

		if( pPlayer !is null and pPlayer.IsConnected() )
			g_PlayerFuncs.HudMessage( pPlayer, textParms, sMessage );
	}
}

} //namespace vs END