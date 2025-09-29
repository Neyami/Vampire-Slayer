//based on Vampire Slayer by Routetwo and the amxx plugin MiniVS by rtxA
#include "../../ChatCommandManager" //By the svencoop team, should come with the game (svencoop\scripts\) but my version has a tiny fix to make commands case-insensitive.
#include "../../localization"
#include "../../maprestore/maprestore"
#include "enums"
#include "helperfunctions"
#include "hlstocks"
#include "entities"
#include "weapons"

void MapActivate()
{
	//do this in MapInit instead ??
	maprestore::Initialize();
}

void MapInit()
{
	g_EngineFuncs.CVarSetFloat( "sk_plr_xbow_bolt_monster", vs_crossbow::VSW_DAMAGE1 ); //make custom bolt entity ??

	lang::Initialize( "scripts/maps/data/lang/vampireslayer.txt" );

	vs::RegisterWeapons();
	vs::RegisterEntities();
	vs::BSPCompatInit();

	@vs::cvar_flRoundTime = CCVar( "vs-roundtime", 180, "Length of each round (default: 180)", ConCommandFlag::AdminOnly );
	@vs::cvar_iRoundLimit = CCVar( "vs-roundlimit", 10, "Number of rounds before map change. (default: 10)", ConCommandFlag::AdminOnly );

	g_Hooks.RegisterHook( Hooks::Player::ClientPutInServer, @vs::ClientPutInServer );
	g_Hooks.RegisterHook( Hooks::Player::ClientDisconnect, @vs::ClientDisconnect );
	g_Hooks.RegisterHook( Hooks::Player::PlayerLeftObserver, @vs::PlayerLeftObserver );
	g_Hooks.RegisterHook( Hooks::Player::PlayerCanRespawn, @vs::PlayerCanRespawn );
	g_Hooks.RegisterHook( Hooks::Player::GetPlayerSpawnSpot, @vs::GetPlayerSpawnSpot );
	g_Hooks.RegisterHook( Hooks::Player::PlayerSpawn, @vs::PlayerSpawn );
	g_Hooks.RegisterHook( Hooks::Player::PlayerPreThink, @vs::PlayerPreThink );
	g_Hooks.RegisterHook( Hooks::Player::PlayerPostThink, @vs::PlayerPostThink );
	g_Hooks.RegisterHook( Hooks::Player::PlayerTakeDamage, @vs::PlayerTakeDamage );
	g_Hooks.RegisterHook( Hooks::Player::PlayerKilled, @vs::PlayerKilled );

	g_Hooks.RegisterHook( Hooks::Player::ClientSay, @vs::ClientSay );
	@vs::g_ChatCommands = ChatCommandSystem::ChatCommandManager();

	vs::g_ChatCommands.AddCommand( ChatCommandSystem::ChatCommand("!team", @vs::SayCmdTeamMenu, false, 0, "opens the team menu.") );

	vs::Precache();

	vs::g_bRoundStarted = false;
	vs::g_iRoundNumber = 0;

	vs::RoundStart();
}

namespace vs
{

bool DEBUG = false;
bool EXPERIMENTAL = true; //trying to get the scoreboard to show separate teams :aRage: still needed for the game to work, for some reason :eheh:

const int SCORE_POINTS = 1;

const int HUD_CHAN_WIN = 1; //HUDTextParams 1-4
const int HUD_CHAN_SCORE = 2;
const int HUD_CHAN_BREAKPOINTS = 3;

const int HUD_CHAN_TIMER = 8; //HUDNumDisplayParams 0-15
//const RGBA HUD_COLOR = RGBA_SVENCOOP;
const RGBA HUD_COLOR = RGBA( 159, 95, 47, 255 );

const float VAMP_HIGHJUMP_HEIGHT = 275.0;
const int VAMP_MAXSPEED = 320;

// until I add the missing powers, use default attributes from Edgar
const float VAMP_EDGAR_WAKEUP_HEALTH = 20;
const float VAMP_EDGAR_KNOCKOUT_DURATION = 4.0;

const float VAMP_LOUIS_WAKEUP_HEALTH = 25;
const float VAMP_LOUIS_KNOCKOUT_DURATION = 4.0;

const float VAMP_NINA_WAKEUP_HEALTH = 30;
const float VAMP_NINA_KNOCKOUT_DURATION = 3.0;

const int SLAYER_MAXSPEED = 240;

const float ROUND_START_RETRY = 1.0; //how frequently to check if there are enough players with valid teams and classes selected
const float ROUND_RESTART_TIME = 5.0; //time until a new round is started
const float NEXTMAP_TIME	= 10.0; //time until changing to the next map after the round limit has been hit

const int BREAKPOINTS_TO_WIN = 100; //A team wins if their g_iBreakPoints reaches 100

enum vssounds_e
{
	SND_PLR_FALLPAIN1 = 0,
	SND_INTRO,
	SND_INTERMISSION,
	SND_ROUND_HUMANSWIN,
	SND_ROUND_VAMPSWIN,
	SND_ROUND_DRAW,
	SND_VAMP_DRINKING,
	SND_VAMP_LAUGH_MALE,
	SND_VAMP_LAUGH_FEMALE,
	SND_VAMP_LONGJUMP,
	SND_VAMP_HIGHJUMP,
	SND_VAMP_DYING_MALE,
	SND_VAMP_DYING_FEMALE,
	SND_VAMP_ATTACK1,
	SND_VAMP_ATTACK2,
	SND_VAMP_ATTACK3,
	SND_DECAPITATE,
	SND_SLAYER_BREAK,
	SND_VAMPIRE_BREAK
};

const array<string> arrsSounds =
{
	"player/pl_fallpain1.wav",
	"vs/items/intro1.wav",
	"vs/items/intermission.wav",
	"vs/items/messiah.wav",
	"vs/items/toccata.wav",
	"vs/items/draw.wav",
	"vs/items/feed.wav",
	"vs/player/evilaugh.wav",
	"vs/player/ninalaugh.wav",
	"vs/player/flap-long2.wav",
	"vs/player/flap-short1.wav",
	"vs/player/vampsc.wav",
	"vs/player/vampscf.wav",
	"vs/weapons/vattack1.wav",
	"vs/weapons/vattack2.wav",
	"vs/weapons/vattack3.wav",
	"vs/player/headshot2.wav",
	"vs/items/sdrop.wav",
	"vs/items/vdrop.wav"
};

int g_iRoundNumber;
bool g_bDisableDeathPenalty;
float g_flRoundTime;
bool g_bRoundStarted;
int g_iRoundWinner;
int g_iBreakPointsSlayer; //When breaking func_breakpoints this increases, Slayers win if this reaches 100
int g_iBreakPointsVampire; //When breaking func_breakpoints this increases, Vampires win if this reaches 100
array<int> g_iTeamScore( HL_MAX_TEAMS );

CTextMenu@ teamMenu = null;
CTextMenu@ classMenu = null;

CScheduledFunction@ schedRoundStart = null;
CScheduledFunction@ schedRoundTimer = null;

CCVar@ cvar_flRoundTime;
CCVar@ cvar_iRoundLimit;

CClientCommand vs_roundtime( "vs_roundtime", "Length of each round (default: 180)", @VSSettings, ConCommandFlag::AdminOnly );
CClientCommand vs_roundlimit( "vs_roundlimit", "Number of rounds before map change. (default: 10)", @VSSettings, ConCommandFlag::AdminOnly );
CClientCommand vs_restart( "vs_restart", "Reset scores and round number.", @CmdRestartGame, ConCommandFlag::Cheat );
CClientCommand vs_restartround( "vs_restartround", "Reset scores and round number.", @CmdRestartRound, ConCommandFlag::Cheat );
CClientCommand changeteam( "changeteam", "Opens the team select menu.", @CmdTeamMenu );

ChatCommandSystem::ChatCommandManager@ g_ChatCommands = null;

void Precache()
{
	g_Game.PrecacheModel( MDL_HUMAN_FATHER );
	g_Game.PrecacheModel( MDL_HUMAN_MOLLY );
	g_Game.PrecacheModel( MDL_HUMAN_EIGHTBALL );
	g_Game.PrecacheModel( MDL_HUMAN_FATHER_NH );
	g_Game.PrecacheModel( MDL_HUMAN_MOLLY_NH );
	g_Game.PrecacheModel( MDL_HUMAN_EIGHTBALL_NH );
	g_Game.PrecacheModel( MDL_HUMAN_FATHER_HEAD );
	g_Game.PrecacheModel( MDL_HUMAN_MOLLY_HEAD );
	g_Game.PrecacheModel( MDL_HUMAN_EIGHTBALL_HEAD );

	g_Game.PrecacheModel( MDL_VAMP_EDGAR );
	g_Game.PrecacheModel( MDL_VAMP_LOUIS );
	g_Game.PrecacheModel( MDL_VAMP_NINA );

	g_Game.PrecacheModel( MDL_BIKE_FATHER );
	g_Game.PrecacheModel( MDL_BIKE_MOLLY );
	g_Game.PrecacheModel( MDL_BIKE_EIGHTBALL );
	g_Game.PrecacheModel( MDL_BIKE_EDGAR );
	g_Game.PrecacheModel( MDL_BIKE_LOUIS );
	g_Game.PrecacheModel( MDL_BIKE_NINA );

	for( uint i = 0; i < arrsSounds.length(); ++i )
		g_SoundSystem.PrecacheSound( arrsSounds[i] );
}

HookReturnCode ClientSay( SayParameters@ pParams )
{
	if( g_ChatCommands.ExecuteCommand( pParams ) )
		return HOOK_HANDLED;

	CBasePlayer@ pPlayer = pParams.GetPlayer();
	if( !pPlayer.IsAlive() )
	{
		pParams.ShouldHide = true;

		for( int i = 1; i <= g_Engine.maxClients; i++ )
		{
			CBasePlayer@ pPlayer = g_PlayerFuncs.FindPlayerByIndex( i );

			if( pPlayer is null or !pPlayer.IsConnected() )
				continue;

			g_PlayerFuncs.ClientPrint( pPlayer,HUD_PRINTTALK, lang::getLocalizedText(pPlayer, "TAG_DEAD") + " " + pPlayer.pev.netname + ": " + pParams.GetCommand() + "\n" );
		}

		return HOOK_HANDLED;
	}

	return HOOK_CONTINUE;
}

HookReturnCode ClientPutInServer( CBasePlayer@ pPlayer )
{
	//gamedll_fixes
	if( EXPERIMENTAL )
		g_Scheduler.SetTimeout( "ShowSpecs_Fix", 0.1, EHandle(pPlayer) );

	//gamedll_sendtospec
    // bots don't initialize pev data until spawn
    //if( !IsPlayerBot(pPlayer) )
	{
        hl_set_user_spectator( pPlayer ); //pPlayer.GetObserver().StartObserver( pPlayer.GetOrigin(), pPlayer.pev.angles, false );
		pPlayer.pev.nextthink = g_Engine.time + 99999.0; //without this, players will auto-respawn when mp_respawndelay is up or 0
    }

	//minivs
	g_Scheduler.SetTimeout( "VS_PutInServer", 0.1, EHandle(pPlayer) );

	return HOOK_CONTINUE;
}

void ShowSpecs_Fix( EHandle ePlayer )
{
	CBasePlayer@ pNewPlayer = cast<CBasePlayer@>( ePlayer.GetEntity() );
	if( pNewPlayer is null or !pNewPlayer.IsConnected() )
		return;

	/*NetworkMessage m1( MSG_ONE, NetworkMessages::GameMode, pNewPlayer.edict() ); //86
		m1.WriteByte( 1 ); //game mode teamplay
	m1.End();*/

	//Set in scoreboard players in spectator mode when he enters
	for( int i = 1; i <= g_Engine.maxClients; i++ )
	{
		CBasePlayer@ pPlayer = g_PlayerFuncs.FindPlayerByIndex( i );

		if( pPlayer is null or !pPlayer.IsConnected() )
			continue;

		if( pPlayer.GetObserver().IsObserver() )
		{
			NetworkMessage m1( MSG_ONE, NetworkMessages::TeamInfo, pNewPlayer.edict() ); //84
				m1.WriteByte( i );
				m1.WriteString( "" );
			m1.End();
		}
	}

	// Message used in some clients (AG and BHL)
	/*for( int i = 1; i <= g_Engine.maxClients; i++ )
	{
		CBasePlayer@ pPlayer = g_PlayerFuncs.FindPlayerByIndex( i );

		if( pPlayer is null or !pPlayer.IsConnected() )
			continue;

		if( hl_get_user_spectator(pPlayer) )
		{
			NetworkMessage m1( MSG_ONE, NetworkMessages::Spectator, pNewPlayer.edict() ); //98
				m1.WriteByte( i );
				m1.WriteByte( 1 );
			m1.End();
		}
	}*/
}

void VS_PutInServer( EHandle ePlayer )
{
	CBasePlayer@ pPlayer = cast<CBasePlayer@>( ePlayer.GetEntity() );
	if( pPlayer is null or !pPlayer.IsConnected() )
		return;

	UpdateTeamNames( pPlayer );

	UpdateTeamScore( pPlayer );

	//increase display time for center messages (default is too low, player can barely see them)
	NetworkMessage m1( MSG_ONE, NetworkMessages::SVC_STUFFTEXT, pPlayer.edict() );
		m1.WriteString( "scr_centertime 4\n" );
	m1.End();

	SetCanOpenMenu( pPlayer, true );
	DisplayTeamMenu( pPlayer );

	SpeakSnd( pPlayer, arrsSounds[SND_INTRO] ); //find a way to stop this playing after the player has selected their class!

	// bots don't know how to select team
	if( IsPlayerBot(pPlayer) )
	{
		int id = pPlayer.entindex();

		//ChangePlayerTeam( pPlayer, (id % 2) == 1 ? TEAM_SLAYER : TEAM_VAMPIRE ); //1
		//SetPlayerTeam( pPlayer, (id % 2) == 1 ? TEAM_SLAYER : TEAM_VAMPIRE ); //1
		//SetPlayerClass( pPlayer, (id % 2) == 1 ? Math.RandomLong(CLASS_HUMAN_FATHER, CLASS_HUMAN_MOLLY) : Math.RandomLong(CLASS_VAMP_LOUIS, CLASS_VAMP_NINA) ); //1
		int iTeam = GetBalancedTeam();
		//int iTeam = TEAM_SLAYER; //TEMP
		ChangePlayerTeam( pPlayer, iTeam );
		SetPlayerTeam( pPlayer, iTeam );
		SetPlayerClass( pPlayer, (iTeam == TEAM_SLAYER) ? Math.RandomLong(CLASS_HUMAN_FATHER, CLASS_HUMAN_MOLLY) : Math.RandomLong(CLASS_VAMP_LOUIS, CLASS_VAMP_NINA) );
		SetClassAttributes( pPlayer );

		if( g_bRoundStarted and !RoundNeedsToContinue() )
			RoundEnd();
	}
	else
	{
		//set player default team, fixes player not being in the spectator column 
		ChangePlayerTeam( pPlayer, TEAM_SLAYER );
	}
}

int GetBalancedTeam()
{
	int iSlayers = vs_get_teamnum( TEAM_SLAYER );
	int iVampires = vs_get_teamnum( TEAM_VAMPIRE );

	if( iSlayers > iVampires )
		return TEAM_VAMPIRE;
	else if( iSlayers == iVampires )
	{
		if( Math.RandomLong(0, 1) == 1 )
			return TEAM_VAMPIRE;
	}

	return TEAM_SLAYER;
}

HookReturnCode ClientDisconnect( CBasePlayer@ pPlayer )
{
	if( g_bRoundStarted )
	{
		if( !RoundNeedsToContinue() )
			RoundEnd();
	}

	return HOOK_CONTINUE;
}

//PlayerSpawn doesn't always work for this :aRage:
HookReturnCode PlayerLeftObserver( CBasePlayer@ pPlayer )
{
	//PlayerSpawn_Post( EHandle(pPlayer) );
	g_Scheduler.SetTimeout( "PlayerSpawn_Post", 0.01, EHandle(pPlayer) );

	return HOOK_CONTINUE;
}

HookReturnCode GetPlayerSpawnSpot( CBasePlayer@ pPlayer, CBaseEntity@ &out ppEntSpawnSpot )
{
	if( GetPlayerTeam(pPlayer) == TEAM_SLAYER )
	{
		array<CBaseEntity@> arrpSpawnPoints;

		CBaseEntity@ pPlayerStart = null;
		while( (@pPlayerStart = g_EntityFuncs.FindEntityByClassname(pPlayerStart, "info_player_deathmatch")) !is null )
		{
			if( pPlayerStart.pev.netname == "team1" )
			{
				//g_Game.AlertMessage( at_notice, "FOUND SLAYER START AT %1\n", pPlayerStart.pev.origin.ToString() );
				arrpSpawnPoints.insertLast( pPlayerStart );
			}
		}

		if( arrpSpawnPoints.length() > 0 )
		{
			/*for( int i = 0; i < arrpSpawnPoints.length(); i++ )
			{
				if( g_PlayerFuncs.IsSpawnPointValid( arrpSpawnPoints[i], pPlayer) )
					@ppEntSpawnSpot = arrpSpawnPoints[ i ];
			}

			if( ppEntSpawnSpot is null )*/
				@ppEntSpawnSpot = arrpSpawnPoints[ Math.RandomLong(0, arrpSpawnPoints.length()-1) ];

			return HOOK_HANDLED;
		}
	}
	else if( GetPlayerTeam(pPlayer) == TEAM_VAMPIRE )
	{
		array<CBaseEntity@> arrpSpawnPoints;

		CBaseEntity@ pPlayerStart = null;
		while( (@pPlayerStart = g_EntityFuncs.FindEntityByClassname(pPlayerStart, "info_player_deathmatch")) !is null )
		{
			if( pPlayerStart.pev.netname == "team2" )
			{
				//g_Game.AlertMessage( at_notice, "FOUND VAMPIRE START AT %1\n", pPlayerStart.pev.origin.ToString() );
				arrpSpawnPoints.insertLast( pPlayerStart );
			}
		}

		if( arrpSpawnPoints.length() > 0 )
		{
			/*for( int i = 0; i < arrpSpawnPoints.length(); i++ )
			{
				if( g_PlayerFuncs.IsSpawnPointValid( arrpSpawnPoints[i], pPlayer) )
					@ppEntSpawnSpot = arrpSpawnPoints[ i ];
			}

			if( ppEntSpawnSpot is null )*/
				@ppEntSpawnSpot = arrpSpawnPoints[ Math.RandomLong(0, arrpSpawnPoints.length()-1) ];

			return HOOK_HANDLED;
		}
	}

	//g_Game.AlertMessage( at_notice, "GetPlayerSpawnSpot found for %1 at %2\n", pPlayer.pev.netname, ppEntSpawnSpot.pev.origin.ToString() );
	return HOOK_CONTINUE;
}

//OnPlayerSpawn_Pre ??
HookReturnCode PlayerCanRespawn( CBasePlayer@ pPlayer, bool &out bCanRespawn )
{
	// used in dead players
	if( GetSendToSpecVictim(pPlayer) )
		bCanRespawn = false;

	return HOOK_CONTINUE;
}
//OnPlayerSpawn_Post
HookReturnCode PlayerSpawn( CBasePlayer@ pPlayer )
{
	g_Scheduler.SetTimeout( "PlayerSpawn_Post", 0.01, EHandle(pPlayer) );

	return HOOK_CONTINUE;
}

void PlayerSpawn_Post( EHandle ePlayer )
{
	CBasePlayer@ pPlayer = cast<CBasePlayer@>( ePlayer.GetEntity() );
	if( pPlayer is null or !pPlayer.IsConnected() )
		return;

	SetFallSoundPlayed( pPlayer, 0 );
	SetHasToBeKnockOut( pPlayer, false );
	SetCanOpenMenu( pPlayer, true );

	// player is trying to spawn and is still dead, ignore...
	//if( !is_user_alive(id) )
		//return;
		
 	if( GetPlayerTeam(pPlayer) != TEAM_NONE and GetPlayerClass(pPlayer) != CLASS_NOCLASS )
		SetClassAttributes( pPlayer );
}

HookReturnCode PlayerPreThink( CBasePlayer@ pPlayer, uint& out uiFlags )
{
	// play body corpse fall sound
	if( !GetFallSoundPlayed(pPlayer) )
	{
		if( pPlayer.pev.deadflag >= DEAD_DYING and pPlayer.pev.movetype != MOVETYPE_NONE and HasFlags(pPlayer.pev.flags, FL_ONGROUND) )
		{
			g_SoundSystem.EmitSound( pPlayer.edict(), CHAN_BODY, arrsSounds[SND_PLR_FALLPAIN1], VOL_NORM, ATTN_NORM );
			SetFallSoundPlayed( pPlayer, 1 );
		}
	}

	// hack: fix player creating multiple corpses when trying to respawn
	if( GetSendToSpecVictim(pPlayer) and !hl_get_user_spectator(pPlayer) )
	{
		pPlayer.m_fDeadTime = g_Engine.time;
		pPlayer.pev.button = 0;
		pPlayer.pev.oldbuttons = 0;
	}

	if( IsKnockedOut(pPlayer) )
	{
		// hack to avoid player create a deadcorpse
		pPlayer.m_fDeadTime = g_Engine.time;
		pPlayer.pev.button = 0;
		pPlayer.pev.oldbuttons = 0;

		if( GetKnockOutEndTime(pPlayer) < g_Engine.time )
			VS_WakeUp( pPlayer );
	}

	if( GetPlayerTeam(pPlayer) == TEAM_VAMPIRE )
		pPlayer.pev.flTimeStepSound = 999;

	if( GetPlayerTeam(pPlayer) == TEAM_SLAYER )
	{
		if( pPlayer.pev.deadflag == DEAD_DEAD and GetShouldCreateCorpse(pPlayer) /*and HasFlags(pPlayer.pev.effects, EF_NODRAW)*/ )
		{
			SetShouldCreateCorpse( pPlayer, false );
			CreateCorpse( pPlayer );
		}
	}

	return HOOK_CONTINUE;
}

HookReturnCode PlayerPostThink( CBasePlayer@ pPlayer )
{
	if( pPlayer.IsConnected() and pPlayer.IsAlive() and GetPlayerTeam(pPlayer) == TEAM_VAMPIRE and !IsOnBike(pPlayer) )
	{
		VampSuperJump( pPlayer );
		VampLanding( pPlayer );
	}

	return HOOK_CONTINUE;
}

bool IsOnBike( CBasePlayer@ pPlayer )
{
	if( pPlayer.m_hActiveItem.GetEntity() !is null and pPlayer.m_hActiveItem.GetEntity().GetClassname() == "weapon_vsbike" )
		return true;

	return false;
}

void VampSuperJump( CBasePlayer@ pPlayer )
{
	if( (pPlayer.m_afButtonPressed & IN_JUMP) != 0 and pPlayer.pev.waterlevel < WATERLEVEL_WAIST )
	{
		//checking FL_ONGROUND doesn't work D:
		TraceResult tr;
		g_Utility.TraceHull( pPlayer.pev.origin, pPlayer.pev.origin + Vector(0, 0, -5), dont_ignore_monsters, human_hull, pPlayer.edict(), tr );

		if( tr.flFraction < 1.0 )
		{
			if( pPlayer.m_IdealActivity == ACT_LEAP and pPlayer.pev.frame == 0 )
				g_SoundSystem.EmitSound( pPlayer.edict(), CHAN_BODY, arrsSounds[SND_VAMP_LONGJUMP], VOL_NORM, ATTN_NORM );
			else if( !HasFlags(pPlayer.pev.oldbuttons, IN_DUCK) )
			{
				Vector vecVelocity;
				vecVelocity = pPlayer.pev.velocity;
				vecVelocity.z += VAMP_HIGHJUMP_HEIGHT;
				pPlayer.pev.velocity = vecVelocity;
				g_SoundSystem.EmitSound( pPlayer.edict(), CHAN_BODY, arrsSounds[SND_VAMP_HIGHJUMP], VOL_NORM, ATTN_NORM );
			}
		}
	}
}

void VampLanding( CBasePlayer@ pPlayer )
{
	if( HasFlags(pPlayer.pev.flags, FL_ONGROUND) )
	{
		pPlayer.m_flFallVelocity = 0; //this gets rid of fall damage, screen shake, and the gib sound, but not pl_fallpain3 :aRage:
		pPlayer.pev.flFallVelocity = 0;

		if( pPlayer.pev.punchangle != g_vecZero )
			pPlayer.pev.punchangle = g_vecZero;
	}
}

HookReturnCode PlayerTakeDamage( DamageInfo@ pDamageInfo )
{
	CBasePlayer@ pVictim = cast<CBasePlayer@>( pDamageInfo.pVictim );

	int victimTeam = GetPlayerTeam( pVictim );

	if( pDamageInfo.pInflictor.pev.classname == "trigger_hurt" and victimTeam == TEAM_SLAYER )
	{
		//slayers don't get burned, only vampires
		if( HasFlags(pDamageInfo.bitsDamageType, DMG_BURN) )
		{
			pDamageInfo.flDamage = 0.0;
			return HOOK_HANDLED; //HAM_SUPERCEDE;
		}
	}

	/*//Not needed when setting FallVelocity to 0
	if( victimTeam == TEAM_VAMPIRE )
	{
		if( pDamageInfo.pAttacker is g_EntityFuncs.Instance(0) and HasFlags(pDamageInfo.bitsDamageType, DMG_FALL) ) //0 = worldspawn
		{
			pDamageInfo.flDamage = 0.0;
			return HOOK_HANDLED; //HAM_SUPERCEDE;
		}
	}*/

	if( !pDamageInfo.pAttacker.pev.FlagBitSet(FL_CLIENT) )
		return HOOK_CONTINUE;

	float flDamage = pDamageInfo.flDamage;
	CBasePlayer@ pAttacker = cast<CBasePlayer@>( pDamageInfo.pAttacker );

	int attackerTeam = GetPlayerTeam( pAttacker );

	if( victimTeam == TEAM_SLAYER and attackerTeam == TEAM_VAMPIRE )
	{
		if( pVictim.m_hActiveItem.GetEntity() !is null )
		{
			CBasePlayerWeapon@ pWeapon = cast<CBasePlayerWeapon@>( pVictim.m_hActiveItem.GetEntity() );

			// slayer is using his cross, block any damage
			if( pWeapon.GetClassname() == "weapon_vsstake" )
			{
				vs_stake::weapon_vsstake@ pStakeWeapon = cast<vs_stake::weapon_vsstake@>( CastToScriptClass(pWeapon) );
				if( pStakeWeapon !is null and pStakeWeapon.m_bInvulOn )
				{
					pDamageInfo.flDamage = 0.0;
					return HOOK_HANDLED; //HAM_SUPERCEDE;
				}
			}
		}

		if( flDamage >= pVictim.pev.health and pVictim.m_LastHitGroup == HITGROUP_HEAD )
		{
			g_SoundSystem.EmitSound( pAttacker.edict(), CHAN_STATIC, arrsSounds[SND_DECAPITATE], VOL_NORM, ATTN_NORM );

			switch( GetPlayerClass(pVictim) )
			{
				case CLASS_HUMAN_FATHER: SetPlayerModel( pVictim, "fatherd_decap" ); break;
				case CLASS_HUMAN_MOLLY: SetPlayerModel( pVictim, "molly_decap" ); break;
				case CLASS_HUMAN_EIGHTBALL: SetPlayerModel( pVictim, "eightball_decap" ); break;
			}

			Vector vecBloodOrigin;
			g_EngineFuncs.GetBonePosition( pVictim.edict(), 15, vecBloodOrigin, void );
			g_WeaponFuncs.SpawnBlood( vecBloodOrigin, pVictim.BloodColor(), flDamage );
			LaunchHead( pVictim, pAttacker, vecBloodOrigin, flDamage);
			//g_EntityFuncs.SpawnHeadGib( pVictim.pev );

			return HOOK_CONTINUE; //HAM_IGNORED;
		}
	}

	if( victimTeam == TEAM_VAMPIRE and attackerTeam == TEAM_SLAYER )
	{
		//if( DEBUG )
			g_Game.AlertMessage( at_notice, "SLAYER ATTACKING VAMPIRE flDamage: %1, health: %2, IsKnockedOut: %3\n", flDamage, pVictim.pev.health, IsKnockedOut(pVictim) );

		// slayer has done enough damage, knockdown vampire
		if( flDamage >= pVictim.pev.health and !IsKnockedOut(pVictim) )
		{
			if( DEBUG )
				g_Game.AlertMessage( at_notice, "SLAYER KNOCKED VAMPIRE OUT\n" );

			// hack: we don't block damage so the knockback can work
			// anyway, we are going to knock him down
			//pDamageInfo.flDamage = 0.0;
			pVictim.pev.health = 10000.0;
			SetHasToBeKnockOut( pVictim, true );
			//VS_KnockOut( pVictim );
			//lang::ClientPrintAll( HUD_PRINTTALK, "NOTIF_KNOCKOUT", pAttacker.pev.netname, pVictim.pev.netname );
			//SetHasToBeKnockOut( pVictim, false );

			//call this at the top of the function maybe ??
			g_Scheduler.SetTimeout( "OnPlayerTakeDamage_Post", 0.01, EHandle(pDamageInfo.pVictim), EHandle(pDamageInfo.pInflictor), EHandle(pDamageInfo.pAttacker), pDamageInfo.flDamage, pDamageInfo.bitsDamageType );
			return HOOK_CONTINUE; //HAM_IGNORED;
		}

		// vampire is down, time to kill him
		if( IsKnockedOut(pVictim) )
		{
			if( pAttacker.m_hActiveItem.GetEntity() !is null )
			{
				string sClassname = pAttacker.m_hActiveItem.GetEntity().GetClassname();
				if( sClassname != "weapon_vsstake" and sClassname != "weapon_vscolt" and sClassname != "weapon_vscue" )
					return HOOK_CONTINUE; //HAM_SUPERCEDE;

				if( !HasFlags(pDamageInfo.bitsDamageType, DMG_SLASH) ) //colt and poolcue have other attacks
					return HOOK_CONTINUE; //HAM_SUPERCEDE;

				// don't let player kill the vampire at least one second later
				float flKnockOutStartTime = ( GetKnockOutEndTime(pVictim) - GetKnockOutTime(pVictim) );
				if( flKnockOutStartTime + 1.0 > g_Engine.time )
					return HOOK_CONTINUE; //HAM_SUPERCEDE;

				//kill vampire
				lang::ClientPrintAll( HUD_PRINTTALK, "NOTIF_STAKED", pAttacker.pev.netname, pVictim.pev.netname );
				pVictim.pev.health = 1;
				pVictim.pev.deadflag = DEAD_NO;
				pDamageInfo.flDamage = 500.0; //SetHamParamFloat( 4, 500.0 );
				pDamageInfo.bitsDamageType = DMG_ALWAYSGIB; //SetHamParamInteger( 5, DMG_ALWAYSGIB );
				SetKnockedOut( pVictim, false );
			}
		}
	}

	return HOOK_CONTINUE; //HAM_IGNORED;
}

void OnPlayerTakeDamage_Post( EHandle eVictim, EHandle eInflictor, EHandle eAttacker, float damage, int damagetype )
{
	g_Game.AlertMessage( at_notice, "OnPlayerTakeDamage_Post CALLED\n" );

	CBasePlayer@ pVictim = cast<CBasePlayer@>( eVictim.GetEntity() );
	CBasePlayer@ pAttacker = cast<CBasePlayer@>( eAttacker.GetEntity() );
	if( pVictim is null or !pVictim.IsConnected() or pAttacker is null or !pAttacker.IsConnected() )
		return;

	int victimTeam = GetPlayerTeam( pVictim );
	int attackerTeam = GetPlayerTeam( pAttacker );

	if( victimTeam == TEAM_VAMPIRE and attackerTeam == TEAM_SLAYER )
	{
		g_Game.AlertMessage( at_notice, "OnPlayerTakeDamage_Post SLAYER ATTACKING VAMPIRE\n" );
		//slayer has done enough damage, knockdown vampire
		if( GetHasToBeKnockOut(pVictim) and !IsKnockedOut(pVictim) )
		{
			g_Game.AlertMessage( at_notice, "OnPlayerTakeDamage_Post SLAYER KNOCKED VAMPIRE OUT\n" );
			VS_KnockOut( pVictim );
			lang::ClientPrintAll( HUD_PRINTTALK, "NOTIF_KNOCKOUT", pAttacker.pev.netname, pVictim.pev.netname );
			SetHasToBeKnockOut( pVictim, false );
		}
	}
}

void LaunchHead( CBasePlayer@ pVictim, CBasePlayer@ pAttacker, Vector vecOrigin, float flDamage )
{
	/*CGib@ pHead = g_EntityFuncs.CreateGib( vecOrigin, g_vecZero );

	string sHeadModel = MDL_HUMAN_FATHER_HEAD;

	if( GetPlayerClass(pVictim) == CLASS_HUMAN_MOLLY )
		sHeadModel = MDL_HUMAN_MOLLY_HEAD;
	else if( GetPlayerClass(pVictim) == CLASS_HUMAN_EIGHTBALL )
		sHeadModel = MDL_HUMAN_EIGHTBALL_HEAD;

	pHead.Spawn( sHeadModel );

	pHead.pev.gravity = 0.8;
	pHead.pev.velocity = GetVelocityForHead( pAttacker );

	pHead.pev.velocity.x += Math.RandomFloat( -0.15, 0.15 );
	pHead.pev.velocity.y += Math.RandomFloat( -0.25, 0.15 );
	pHead.pev.velocity.z += Math.RandomFloat( -0.2, 1.9 );

	pHead.pev.avelocity.x = Math.RandomFloat( 70, 200 );
	pHead.pev.avelocity.y = Math.RandomFloat( 70, 200 );

	pHead.LimitVelocity();

	pHead.m_bloodColor = BLOOD_COLOR_RED;
	pHead.m_cBloodDecals = 15;
	pHead.m_material = matFlesh;

	pHead.pev.movetype = MOVETYPE_BOUNCE;*/

	CBaseEntity@ cbeHead = g_EntityFuncs.Create( "vs_head", vecOrigin, g_vecZero, false );
	vs_head::vs_head@ pHead = cast<vs_head::vs_head@>( CastToScriptClass(cbeHead) );

	if( pHead !is null )
	{
		string sHeadModel = MDL_HUMAN_FATHER_HEAD;

		if( GetPlayerClass(pVictim) == CLASS_HUMAN_MOLLY )
			sHeadModel = MDL_HUMAN_MOLLY_HEAD;
		else if( GetPlayerClass(pVictim) == CLASS_HUMAN_EIGHTBALL )
			sHeadModel = MDL_HUMAN_EIGHTBALL_HEAD;

		if( pHead is null )
			return;

		g_EntityFuncs.SetModel( pHead.self, sHeadModel );

		pHead.pev.gravity = 0.8;
		pHead.pev.velocity = GetVelocityForHead( pAttacker );

		pHead.pev.velocity.x += Math.RandomFloat( -0.15, 0.15 );
		pHead.pev.velocity.y += Math.RandomFloat( -0.25, 0.15 );
		pHead.pev.velocity.z += Math.RandomFloat( -0.2, 1.9 );

		pHead.pev.avelocity.x = Math.RandomFloat( 70, 200 );
		pHead.pev.avelocity.y = Math.RandomFloat( 70, 200 );

		//LimitVelocity
		float length = pHead.pev.velocity.Length();

		if( length > 1500.0 )
			pHead.pev.velocity = pHead.pev.velocity.Normalize() * 1500;

		pHead.m_iBloodDecals = 15;

		g_WeaponFuncs.SpawnBlood( pHead.pev.origin, BLOOD_COLOR_RED, 400 );
	}
}

Vector GetVelocityForHead( CBasePlayer@ pAttacker )
{
	Vector v;
	float flDamage = 200;

	Math.MakeVectors( pAttacker.pev.v_angle );
	v = g_Engine.v_forward * 69.0;
	v.z = Math.RandomFloat( 150.0, 200.0 );

	if( flDamage < 50 )
		return v * 0.7;
	else
		return v * 1.2;
}

float crandom_open()
{
	float flRandom = Math.RandomFloat( 0.0, 1.0 );
	return (flRandom - 0.5) * 2.0;
}

HookReturnCode PlayerKilled( CBasePlayer@ pPlayer, CBaseEntity@ pAttacker, int iGib )
{
	//string sPlayerModel = GetPlayerModel( pPlayer );
	//g_Game.AlertMessage( at_notice, "PlayerKilled model: %1\n", sPlayerModel );

	int victimTeam = GetPlayerTeam( pPlayer );
	int attackerTeam = GetPlayerTeam( pAttacker );

	// if there aren't enough players, ignore score of this round
	if( g_bDisableDeathPenalty )
	{
		//hl_set_user_deaths(victim, hl_get_user_deaths(victim) - 1);
		if( pAttacker !is null and pAttacker.IsPlayer() )
		{
			if( victimTeam != attackerTeam and pPlayer.edict() !is pAttacker.edict() )
				hl_set_user_frags( pAttacker, pAttacker.pev.frags - 1 ); //pAttacker.pev.frags--; hl_get_user_frags(attacker)
			else
				hl_set_user_frags( pAttacker, pAttacker.pev.frags + 1 ); //pAttacker.pev.frags++; hl_get_user_frags(attacker)
		}
	}

	if( IsKnockedOut(pPlayer) )
		return HOOK_CONTINUE;

	// send victim to spec
	SetSendToSpecVictim( pPlayer, 1 );
	g_Scheduler.SetTimeout( "SendToSpec", 3.0, EHandle(pPlayer) );

	if( g_bRoundStarted and !RoundNeedsToContinue() )
		RoundEnd();

	if( victimTeam == TEAM_SLAYER )
	{
		//g_Scheduler.SetTimeout( "CreateCorpse", 0.1, EHandle(pPlayer) );
		SetShouldCreateCorpse( pPlayer, true );

		if( attackerTeam == TEAM_VAMPIRE )
		{
			switch( Math.RandomLong(1, 3) )
			{
				case 1: g_SoundSystem.EmitSound( pAttacker.edict(), CHAN_STATIC, arrsSounds[SND_VAMP_ATTACK1], VOL_NORM, ATTN_NORM );
				case 2: g_SoundSystem.EmitSound( pAttacker.edict(), CHAN_STATIC, arrsSounds[SND_VAMP_ATTACK2], VOL_NORM, ATTN_NORM );
				case 3: g_SoundSystem.EmitSound( pAttacker.edict(), CHAN_STATIC, arrsSounds[SND_VAMP_ATTACK3], VOL_NORM, ATTN_NORM );
			}
		}
	}

	// note: vampire simulates being dead when is knocked down
	if( victimTeam == TEAM_VAMPIRE )
	{
		SetSpecialPower( pPlayer, false );

		// play death sound
		if( !IsKnockedOut(pPlayer) )
		{
			if( GetPlayerClass(pPlayer) != CLASS_VAMP_NINA )
				g_SoundSystem.EmitSound( pPlayer.edict(), CHAN_BODY, arrsSounds[SND_VAMP_DYING_MALE], VOL_NORM, ATTN_NORM );
			else
				g_SoundSystem.EmitSound( pPlayer.edict(), CHAN_BODY, arrsSounds[SND_VAMP_DYING_FEMALE], VOL_NORM, ATTN_NORM );
		}
	}

	return HOOK_CONTINUE;
}

void CreateCorpse( EHandle &in ePlayer )
{
	CBasePlayer@ pPlayer = cast<CBasePlayer@>( ePlayer.GetEntity() );
	if( pPlayer is null or !pPlayer.IsConnected() )
		return;

	CBaseEntity@ pCorpse = g_EntityFuncs.Create( "vs_corpse", pPlayer.pev.origin, pPlayer.pev.angles, false, pPlayer.edict() );

	if( pCorpse !is null )
	{
		string sCorpseModel = MDL_HUMAN_FATHER;

		KeyValueBuffer@ pInfo = g_EngineFuncs.GetInfoKeyBuffer( pPlayer.edict() );
		string sModelName = pInfo.GetValue( "model" );

		if( sModelName == "molly" )
			sCorpseModel = MDL_HUMAN_MOLLY;
		else if( sModelName == "molly_decap" )
			sCorpseModel = MDL_HUMAN_MOLLY_NH;
		else if( sModelName == "eightball" )
			sCorpseModel = MDL_HUMAN_EIGHTBALL;
		else if( sModelName == "eightball_decap" )
			sCorpseModel = MDL_HUMAN_EIGHTBALL_NH;
		else if( sModelName == "fatherd_decap" )
			sCorpseModel = MDL_HUMAN_FATHER_NH;

		g_EntityFuncs.SetModel( pCorpse, sCorpseModel );
		pCorpse.pev.sequence = pPlayer.pev.sequence;
		pCorpse.pev.frame = 255;
	}
}

void SendToSpec( EHandle &in ePlayer )
{
	CBasePlayer@ pPlayer = cast<CBasePlayer@>( ePlayer.GetEntity() );
	if( pPlayer is null or !pPlayer.IsConnected() )
		return;

	if( GetSendToSpecVictim(pPlayer) )
	{
		// hack: create player corpse manually
		//set_ent_data_float(id, "CBasePlayer", "m_fDeadTime", g_Engine.time);
		//set_pev(id, pev_button, IN_ATTACK);
		//set_pev(id, pev_oldbuttons, IN_ATTACK);

		// dead player has already set CBasePlayer::PlayerDeathThink()
		//call_think(id);

		// block spawn again
		//set_pev(id, pev_button, 0);
		//set_pev(id, pev_oldbuttons, 0);

		// now that the corpse has been created, we can finally send the player to spec
		hl_set_user_spectator( pPlayer, true ); //pPlayer.GetObserver().StartObserver( pPlayer.GetOrigin(), pPlayer.pev.angles, true );
		pPlayer.pev.nextthink = g_Engine.time + 99999.0; //without this, players will auto-respawn when mp_respawndelay is up or 0
	}
}

void SetSpecialPower( CBasePlayer@ pPlayer, bool value = true )
{
	if( value )
		set_user_rendering( pPlayer, kRenderFxNone, 0, 0, 0, kRenderTransTexture, 50 );
	else
		set_user_rendering( pPlayer, kRenderFxNone, 0, 0, 0, kRenderNormal );
}

void VS_KnockOut( CBasePlayer@ pPlayer )
{
	SetFallSoundPlayed( pPlayer, 0 );
	SetKnockOutEndTime( pPlayer, g_Engine.time + GetKnockOutTime(pPlayer) );
	SetKnockedOut( pPlayer, true );

	// remove any special power
	SetSpecialPower( pPlayer, false );

	PlayerSilentKill( pPlayer, null, false );
	pPlayer.pev.solid = SOLID_SLIDEBOX; //vampires can't be staked without this

	pPlayer.m_iHideHUD = HIDEHUD_WEAPONS | HIDEHUD_HEALTH;
	pPlayer.pev.nextthink = g_Engine.time + 99999.0;
}

void VS_WakeUp( CBasePlayer@ pPlayer )
{
	pPlayer.pev.health = GetWakeUpHealth( pPlayer );

	// restore
	pPlayer.pev.deadflag = DEAD_NO;
	pPlayer.pev.solid = SOLID_SLIDEBOX;
	pPlayer.pev.effects &= ~EF_NODRAW;

	// set normal eye position again
	Vector vecViewOffset;
	vecViewOffset = pPlayer.pev.view_ofs;

	if( HasFlags(pPlayer.pev.flags, FL_DUCKING) )
		vecViewOffset.z = 12.0;
	else 
		vecViewOffset.z = 28.0;

	pPlayer.pev.view_ofs = vecViewOffset;

	//pPlayer.GiveNamedItem( "weapon_vsclaw" );
	pPlayer.m_iHideHUD = 0;

	CBasePlayerItem@ pWeapon = cast<CBasePlayerItem@>( pPlayer.m_hActiveItem.GetEntity() );
	if( pWeapon !is null )
		pWeapon.Deploy();

//void BlockWeapons({CBaseEntity}@ pSetter)   Hides active weapon and blocks weapon selection.  
//void UnblockWeapons({CBaseEntity}@ pSetter)   Shows active weapon and unblocks weapon selection.  

	// hide claw from weapons slots
	if( !IsPlayerBot(pPlayer) ) // bots need this info for select weapons
		pPlayer.pev.weapons = 1 << 31; //WEAPON_SUIT HLW_SUIT // hack: hide weapon from weapon slots making think player has no weapons

	if( GetPlayerClass(pPlayer) != CLASS_VAMP_NINA )
		g_SoundSystem.EmitSound( pPlayer.edict(), CHAN_STATIC, arrsSounds[SND_VAMP_LAUGH_MALE], VOL_NORM, ATTN_NORM );
	else
		g_SoundSystem.EmitSound( pPlayer.edict(), CHAN_STATIC, arrsSounds[SND_VAMP_LAUGH_FEMALE], VOL_NORM, ATTN_NORM );

	lang::ClientPrintAll( HUD_PRINTTALK, "NOTIF_RESURRECTED", pPlayer.pev.netname ); //print_chat

	// remove corpse when he wakeups
	SetKnockedOut( pPlayer, false );
}

void RoundStart()
{
	// todo: ignore round limit when death penalty is disabled
	if( g_iRoundNumber >= cvar_iRoundLimit.GetInt() )
	{
		string sMap = g_EngineFuncs.CVarGetString( "mp_nextmap_cycle" );
		g_PlayerFuncs.ClientPrintAll( HUD_PRINTCENTER, "[VS] Round limit hit, changing to " + sMap + " in " + int(NEXTMAP_TIME) + " seconds!\n"); 

		NetworkMessage m1( MSG_ALL, NetworkMessages::SVC_INTERMISSION );
		m1.End();

		g_Scheduler.SetTimeout("NextMap", NEXTMAP_TIME, sMap ); 
		return;
	}

	if( g_bRoundStarted )
		return;

	g_iBreakPointsSlayer = g_iBreakPointsVampire = 0;

	if( vs_get_playersnum() < 1 )
	{
		if( DEBUG )
			g_Game.AlertMessage( at_notice, "RoundStart: NOT ENOUGH PLAYERS, RETRYING IN %1\n", ROUND_START_RETRY );

		if( schedRoundStart !is null )
			g_Scheduler.RemoveTimer( schedRoundStart );

		@schedRoundStart = g_Scheduler.SetTimeout( "RoundStart", ROUND_START_RETRY );
		return;
	}

	g_bDisableDeathPenalty = false;

	// ignore score of this round if there aren't enough players in both teams
	if( vs_get_teamnum(TEAM_SLAYER) < 1 or vs_get_teamnum(TEAM_VAMPIRE) < 1 )
		g_bDisableDeathPenalty = true;

	// get players with team and class already set
	array<int> players(32);
	int numPlayers;
	vs_get_players( players, numPlayers );

	CBasePlayer@ pPlayer;

	for( int i = 0; i < numPlayers; i++ )
	{
		@pPlayer = g_PlayerFuncs.FindPlayerByIndex( players[i] );
		if( pPlayer !is null and pPlayer.IsConnected() )
		{
			// new round, reset some stuff
			SetSendToSpecVictim( pPlayer, 0 );
			SetSpecialPower( pPlayer, false );
			SetClassAttributes( pPlayer );
			HUDMessage( null, "", HUD_CHAN_WIN, 0.0, 0.0, RGBA_WHITE, 0.0, 0.0, 0.0 ); //because HudToggleElement doesn't work :aRage:
			HUDMessage( null, "", HUD_CHAN_SCORE, 0.0, 0.0, RGBA_WHITE, 0.0, 0.0, 0.0 );

			if( hl_get_user_spectator(pPlayer) )
				hl_set_user_spectator( pPlayer, false ); //pPlayer.GetObserver().StopObserver( true );
			else
				g_PlayerFuncs.RespawnPlayer( pPlayer, true, true ); //hl_user_spawn(plr);
		}
	}

	g_bRoundStarted = true;

	g_flRoundTime = cvar_flRoundTime.GetFloat();
	StartRoundTimer();

	//restore all map stuff, but not before the first round has ended
	if( g_iRoundNumber > 0 or g_PlayerFuncs.GetNumPlayers() == 1 )
	{
		maprestore::RestoreAll(); //hl_restore_all();
		RestoreVSEntities();
		RemoveItems();
	}

	if( g_PlayerFuncs.GetNumPlayers() > 1 )
		g_iRoundNumber++;

	//remove any screen fade
	g_PlayerFuncs.ScreenFadeAll( g_vecZero, 1.0, 1.0, 0, FFADE_STAYOUT );
}

bool RoundNeedsToContinue()
{
	int humans = vs_get_team_alives( TEAM_SLAYER );
	int vamps = vs_get_team_alives( TEAM_VAMPIRE );

	if( humans > 0 and vamps > 0 )
		return true;

	// the score of this round is ignored
	if( g_bDisableDeathPenalty )
	{
		g_iRoundWinner = TEAM_NONE;
		return false;
	}

	if( vamps > humans )
		g_iRoundWinner = TEAM_VAMPIRE;
	else if( humans > vamps )
		g_iRoundWinner = TEAM_SLAYER;
	else
		g_iRoundWinner = TEAM_NONE;

	return false;
}

void RoundEnd() 
{
	if( DEBUG )
		g_Game.AlertMessage( at_notice, "RoundEnd()\n" );

	if( !g_bRoundStarted )
		return;

	if( DEBUG )
		g_Game.AlertMessage( at_notice, "RoundEnd() g_bRoundStarted is true\n" );

	g_bRoundStarted = false;

	// show team winner
	switch( g_iRoundWinner )
	{
		case TEAM_SLAYER:
		{
			PlaySoundAll( arrsSounds[SND_ROUND_HUMANSWIN] );
			AddPointsToScore( g_iRoundWinner, SCORE_POINTS );

			//lang::ClientPrintAll( HUD_PRINTCENTER, "$1\n\n$2 : $3 $4 : $5", "ROUND_SLAYERSWIN", "TITLE_SLAYER", GetTeamScore(TEAM_SLAYER), "TITLE_VAMPIRE", GetTeamScore(TEAM_VAMPIRE) );
			for( int i = 1; i <= g_Engine.maxClients; i++ )
			{
				CBasePlayer@ pPlayer = g_PlayerFuncs.FindPlayerByIndex( i );

				if( pPlayer is null or !pPlayer.IsConnected() )
					continue;

				string sMessage;
				lang::FormatMessage( pPlayer, sMessage, "\n\n$1 : $2 $3 : $4", "TITLE_SLAYER", GetTeamScore(TEAM_SLAYER), "TITLE_VAMPIRE", GetTeamScore(TEAM_VAMPIRE) );
				HUDMessage( pPlayer, lang::getLocalizedText(pPlayer, "ROUND_SLAYERSWIN"), HUD_CHAN_WIN, -1.0, -1.0, RGBA_RED, 0.0, 2.0 );
				HUDMessage( pPlayer, sMessage.ToUppercase(), HUD_CHAN_SCORE, -1.0, 0.84, RGBA_LIGHT_SLATE_GRAY, 0.0, 0.0, 10.0 );

				//HUDMessage( pPlayer, lang::getLocalizedText(pPlayer, "ROUND_SLAYERSWIN"), HUD_CHAN_WIN, -1.0, -1.0, RGBA_RED, 0.0, 2.0 );
			}

			//lang::ClientPrintAll( HUD_PRINTCENTER, "\n\n$1 : $2 $3 : $4", "TITLE_SLAYER", GetTeamScore(TEAM_SLAYER), "TITLE_VAMPIRE", GetTeamScore(TEAM_VAMPIRE) );

			break;
		}

		case TEAM_VAMPIRE:
		{
			PlaySoundAll( arrsSounds[SND_ROUND_VAMPSWIN] );
			AddPointsToScore( g_iRoundWinner, SCORE_POINTS );

			//lang::ClientPrintAll( HUD_PRINTCENTER, "$1\n\n$2 : $3 $4 : $5", "ROUND_VAMPIRESWIN", "TITLE_SLAYER", GetTeamScore(TEAM_SLAYER), "TITLE_VAMPIRE", GetTeamScore(TEAM_VAMPIRE) );
			for( int i = 1; i <= g_Engine.maxClients; i++ )
			{
				CBasePlayer@ pPlayer = g_PlayerFuncs.FindPlayerByIndex( i );

				if( pPlayer is null or !pPlayer.IsConnected() )
					continue;

				string sMessage;
				lang::FormatMessage( pPlayer, sMessage, "\n\n$1 : $2 $3 : $4", "TITLE_SLAYER", GetTeamScore(TEAM_SLAYER), "TITLE_VAMPIRE", GetTeamScore(TEAM_VAMPIRE) );
				HUDMessage( pPlayer, lang::getLocalizedText(pPlayer, "ROUND_VAMPIRESWIN"), HUD_CHAN_WIN, -1.0, -1.0, RGBA_RED, 0.0, 2.0 );
				HUDMessage( pPlayer, sMessage.ToUppercase(), HUD_CHAN_SCORE, -1.0, 0.84, RGBA_LIGHT_SLATE_GRAY, 0.0, 0.0, 10.0 );

				//HUDMessage( pPlayer, lang::getLocalizedText(pPlayer, "ROUND_VAMPIRESWIN"), HUD_CHAN_WIN, -1.0, -1.0, RGBA_RED, 0.0, 2.0 );
			}

			//lang::ClientPrintAll( HUD_PRINTCENTER, "\n\n$1 : $2 $3 : $4", "TITLE_SLAYER", GetTeamScore(TEAM_SLAYER), "TITLE_VAMPIRE", GetTeamScore(TEAM_VAMPIRE) );

			break;
		}

		case TEAM_NONE:
		{
			//lang::ClientPrintAll( HUD_PRINTCENTER, "$1\n\n$2 : $3 $4 : $5", "ROUND_DRAW", "TITLE_SLAYER", GetTeamScore(TEAM_SLAYER), "TITLE_VAMPIRE", GetTeamScore(TEAM_VAMPIRE) );
			for( int i = 1; i <= g_Engine.maxClients; i++ )
			{
				CBasePlayer@ pPlayer = g_PlayerFuncs.FindPlayerByIndex( i );

				if( pPlayer is null or !pPlayer.IsConnected() )
					continue;

				string sMessage;
				lang::FormatMessage( pPlayer, sMessage, "\n\n$1 : $2 $3 : $4", "TITLE_SLAYER", GetTeamScore(TEAM_SLAYER), "TITLE_VAMPIRE", GetTeamScore(TEAM_VAMPIRE) );
				HUDMessage( pPlayer, lang::getLocalizedText(pPlayer, "ROUND_DRAW"), HUD_CHAN_WIN, -1.0, -1.0, RGBA_RED, 0.0, 2.0 );
				HUDMessage( pPlayer, sMessage.ToUppercase(), HUD_CHAN_SCORE, -1.0, 0.84, RGBA_LIGHT_SLATE_GRAY, 0.0, 0.0, 10.0 );

				//HUDMessage( pPlayer, lang::getLocalizedText(pPlayer, "ROUND_SLAYERSWIN"), HUD_CHAN_WIN, -1.0, -1.0, RGBA_RED, 0.0, 2.0 );
			}

			//lang::ClientPrintAll( HUD_PRINTCENTER, "\n\n$1 : $2 $3 : $4", "TITLE_SLAYER", GetTeamScore(TEAM_SLAYER), "TITLE_VAMPIRE", GetTeamScore(TEAM_VAMPIRE) );
			PlaySoundAll( arrsSounds[SND_ROUND_DRAW] );

			break;
		} 
	}

	UpdateTeamScore();

	g_bDisableDeathPenalty = true;

	//darken the screen a little
	g_PlayerFuncs.ScreenFadeAll( g_vecZero, 1.0, 1.0, 150, FFADE_STAYOUT );

	StopTimer();

	@schedRoundStart = g_Scheduler.SetTimeout( "RoundStart", ROUND_RESTART_TIME );

	if( DEBUG )
		g_Game.AlertMessage( at_notice, "RoundEnd restarting round: %1\n", g_iRoundNumber );
}

void NextMap( const string &in sMap )
{
	g_EngineFuncs.ChangeLevel( sMap );
}

void DisplayTimer( bool bFreeze = false )
{
	//CBasePlayer@ pPlayer = g_PlayerFuncs.FindPlayerByIndex( 1 );

	HUDNumDisplayParams hudNumParams;
	hudNumParams.channel			= HUD_CHAN_TIMER;
	hudNumParams.flags				= HUD_ELEM_SCR_CENTER_X | HUD_NUM_LEADING_ZEROS | HUD_TIME_MINUTES | HUD_TIME_SECONDS | HUD_TIME_COUNT_DOWN;
	hudNumParams.x					= 0;
	hudNumParams.y					= 1.0;
	hudNumParams.value				= g_flRoundTime;
	hudNumParams.color1			= HUD_COLOR;
	hudNumParams.defdigits		= 4;
	hudNumParams.maxdigits		= 4;

	if( bFreeze )
		hudNumParams.flags |= HUD_TIME_FREEZE;

	g_PlayerFuncs.HudTimeDisplay( null, hudNumParams );

	/*HUDTextParams textParams = set_hudmessage( 230, 64, 64, -1.0, 0.01, 2, 0.01, 600.0, 0.05, 0.01 );
	string msg;
	snprintf( msg, "%1:%2\nVampire-Slayer", g_flRoundTime / 60, g_flRoundTime % 60 );
	show_hudmessage( 0, msg, textParams );*/
	//ShowSyncHudMsg(0, g_ScoreHudSync, "%d:%02d^nVampire-Slayer", g_flRoundTime / 60, g_flRoundTime % 60);
	//native ShowSyncHudMsg(target, syncObj, const fmt[], any:...);
/*
This will check that the HUD object has its previous display on the
screen cleared before it proceeds to write another message. It will
only do this in the case of that channel not having been cleared
already.
*/
}

void StopTimer()
{
	if( schedRoundTimer !is null )
		g_Scheduler.RemoveTimer( schedRoundTimer );

	DisplayTimer( true );
}

void SayCmdTeamMenu( SayParameters@ pParams )
{
	pParams.ShouldHide = true;

	CBasePlayer@ pPlayer = pParams.GetPlayer();
	if( pPlayer.IsAlive() or pPlayer.GetObserver().IsObserver() )
	{
		//kill the player and increase deaths when opening the menu like the original does
		//PlayerSilentKill( pPlayer, null, true );

		DisplayTeamMenu( pPlayer );
	}
}

void CmdTeamMenu( const CCommand@ args )
{
	CBasePlayer@ pPlayer = g_ConCommandSystem.GetCurrentPlayer();
	if( pPlayer.IsAlive() or pPlayer.GetObserver().IsObserver() )
	{
		//kill the player and increase deaths when opening the menu like the original does
		//PlayerSilentKill( pPlayer, null, true );

		DisplayTeamMenu( pPlayer );
	}
}

void DisplayTeamMenu( CBasePlayer@ pPlayer )
{
	if( !GetCanOpenMenu(pPlayer) )
		return;

	@teamMenu = CTextMenu( TextMenuPlayerSlotCallback(teamMenuCallback) );
		teamMenu.SetTitle( lang::getLocalizedText(pPlayer, "MENU_TEAM") );
		teamMenu.AddItem( lang::getLocalizedText(pPlayer, "TITLE_SLAYER"), any("slayer") );
		teamMenu.AddItem( lang::getLocalizedText(pPlayer, "TITLE_VAMPIRE"), any("vampire") );
	teamMenu.Register();

	teamMenu.Open( 0, 0, pPlayer );
}

void teamMenuCallback( CTextMenu@ menu, CBasePlayer@ pPlayer, int iSlot, const CTextMenuItem@ pItem )
{
	//is this check necessary ??
	if( pItem !is null and pPlayer !is null )
	{
		string sTeamname;
		pItem.m_pUserData.retrieve( sTeamname );

		if( sTeamname == "slayer" )
		{
			ChangePlayerTeam( pPlayer, TEAM_SLAYER, true );
			lang::ClientPrintAll( HUD_PRINTTALK, "TEAM_CHANGE", pPlayer.pev.netname, lang::getLocalizedText(pPlayer, "TITLE_SLAYER").ToUppercase() );
			SetPlayerTeam( pPlayer, TEAM_SLAYER );
		}
		else
		{
			ChangePlayerTeam( pPlayer, TEAM_VAMPIRE, true );
			lang::ClientPrintAll( HUD_PRINTTALK, "TEAM_CHANGE", pPlayer.pev.netname, lang::getLocalizedText(pPlayer, "TITLE_VAMPIRE").ToUppercase() );
			SetPlayerTeam( pPlayer, TEAM_VAMPIRE );
		}

		SetPlayerClass( pPlayer, CLASS_NOCLASS );
		DisplayClassMenu( pPlayer );
	}
}

void SayCmdClassMenu( SayParameters@ pParams )
{
	pParams.ShouldHide = true;
	CBasePlayer@ pPlayer = pParams.GetPlayer();

	if( GetPlayerTeam(pPlayer) == TEAM_NONE )
	{
		DisplayTeamMenu( pPlayer );
		return;
	}

	DisplayClassMenu( pPlayer );
}

void DisplayClassMenu( CBasePlayer@ pPlayer )
{
	@classMenu = CTextMenu( TextMenuPlayerSlotCallback(classMenuCallback) );
		classMenu.SetTitle( lang::getLocalizedText(pPlayer, "MENU_CLASS") );

		if( GetPlayerTeam(pPlayer) == TEAM_SLAYER )
		{
			classMenu.AddItem( lang::getLocalizedText(pPlayer, "CLASS_HUMAN_FATHER"), any(CLASS_HUMAN_FATHER) );
			classMenu.AddItem( lang::getLocalizedText(pPlayer, "CLASS_HUMAN_MOLLY"), any(CLASS_HUMAN_MOLLY) );
			classMenu.AddItem( lang::getLocalizedText(pPlayer, "CLASS_HUMAN_EIGHTBALL"), any(CLASS_HUMAN_EIGHTBALL) );
		}
		else if( GetPlayerTeam(pPlayer) == TEAM_VAMPIRE )
		{
			classMenu.AddItem( lang::getLocalizedText(pPlayer, "CLASS_VAMP_LOUIS"), any(CLASS_VAMP_LOUIS) );
			classMenu.AddItem( lang::getLocalizedText(pPlayer, "CLASS_VAMP_EDGAR"), any(CLASS_VAMP_EDGAR) );
			classMenu.AddItem( lang::getLocalizedText(pPlayer, "CLASS_VAMP_NINA"), any(CLASS_VAMP_NINA) );
		}

	classMenu.Register();

	classMenu.Open( 0, 0, pPlayer );
}

void classMenuCallback( CTextMenu@ menu, CBasePlayer@ pPlayer, int iSlot, const CTextMenuItem@ pItem )
{
	//is this check necessary ??
	if( pItem !is null and pPlayer !is null )
	{
		//the player is killed when opening the menu in the original
		if( pPlayer.IsAlive() )
			PlayerSilentKill( pPlayer, null, false );

		int iClassNum;
		pItem.m_pUserData.retrieve( iClassNum );

		SetPlayerClass( pPlayer, iClassNum );

		// check if round needs to continue everytime we change class
		if( g_bRoundStarted and !RoundNeedsToContinue() )
			RoundEnd();

		//stop intro sound
		SpeakSnd( pPlayer, "_period", false );

		SetCanOpenMenu( pPlayer, false );
	}
}

void vs_get_players( array<int> &out players, int &out numPlayers )
{
	numPlayers = 0;

	for( int i = 1; i <= g_Engine.maxClients; i++ )
	{
		CBasePlayer@ pPlayer = g_PlayerFuncs.FindPlayerByIndex( i );

		if( pPlayer is null or !pPlayer.IsConnected() )
			continue;
		//else if (is_user_hltv(i))
			//continue;
		else if( GetPlayerTeam(pPlayer) == TEAM_NONE or GetPlayerClass(pPlayer) == CLASS_NOCLASS )
			continue;

		players.insertLast( i );
		numPlayers++;
	}

	if( DEBUG )
		g_Game.AlertMessage( at_notice, "vs_get_players players.length(): %1, numPlayers: %2\n", players.length(), numPlayers );
}

//returns the number of members in teamid
int vs_get_teamnum( int teamid )
{
	array<int> players(32);
	int numPlayers;
	vs_get_players( players, numPlayers );

	if( numPlayers <= 0 )
		return 0;

	int num = 0;
	CBasePlayer@ pPlayer;

	for( int i = 0; i < numPlayers; i++ )
	{
		@pPlayer = g_PlayerFuncs.FindPlayerByIndex( players[i] );
		if( pPlayer !is null and GetPlayerTeam(pPlayer) == teamid and GetPlayerClass(pPlayer) != CLASS_NOCLASS )
			num++;
	}

	return num;
}

//gets the number of valid players (has chosen a team and class)
int vs_get_playersnum()
{
	array<int> players(32);
	int numPlayers;
	vs_get_players( players, numPlayers );

	if( DEBUG )
		g_Game.AlertMessage( at_notice, "vs_get_playersnum: %1\n", numPlayers );

	return numPlayers;
}

int vs_get_team_alives( int teamid )
{
	array<int> players(32);
	int numPlayers;
	vs_get_players( players, numPlayers );

	if( DEBUG )
	{
		g_Game.AlertMessage( at_notice, "vs_get_team_alives numPlayers: %1\n", numPlayers );
		g_Game.AlertMessage( at_notice, "vs_get_team_alives players.length(): %1\n", players.length() );
	}

	if( numPlayers <= 0 )
		return 0;

	int num = 0;
	CBasePlayer@ pPlayer;

	for( int i = 0; i < numPlayers; i++ )
	{
		@pPlayer = g_PlayerFuncs.FindPlayerByIndex( players[i] );
		if( pPlayer !is null and GetPlayerTeam(pPlayer) == teamid and (pPlayer.IsAlive() or IsKnockedOut(pPlayer)) ) //hl_get_user_team
			num++;
	}

	if( DEBUG )
		g_Game.AlertMessage( at_notice, "vs_get_team_alives num: %1\n", num );

	return num;
}

//g_SendToSpecVictim
void SetSendToSpecVictim( CBasePlayer@ pPlayer, int iValue )
{
	if( pPlayer !is null and pPlayer.IsConnected() )
		SetKV( pPlayer, KVN_SENDTOSPEC, iValue );
}

bool GetSendToSpecVictim( CBasePlayer@ pPlayer )
{
	if( pPlayer !is null and pPlayer.IsConnected() )
		return GetKVInt( pPlayer, KVN_SENDTOSPEC ) == 1;

	return true;
}

//g_FallSoundPlayed
void SetFallSoundPlayed( CBasePlayer@ pPlayer, int iValue )
{
	if( pPlayer !is null and pPlayer.IsConnected() )
		SetKV( pPlayer, KVN_FALLSOUNDPLAYED, iValue );
}

bool GetFallSoundPlayed( CBasePlayer@ pPlayer )
{
	if( pPlayer !is null and pPlayer.IsConnected() )
		return GetKVInt( pPlayer, KVN_FALLSOUNDPLAYED ) == 1;

	return true;
}

//g_HasToBeKnockOut
void SetHasToBeKnockOut( CBasePlayer@ pPlayer, bool bValue )
{
	if( pPlayer !is null and pPlayer.IsConnected() )
	{
		int iValue = bValue ? 1 : 0;
		SetKV( pPlayer, KVN_KNOCKOUT, iValue );
	}
}

bool GetHasToBeKnockOut( CBasePlayer@ pPlayer )
{
	if( pPlayer !is null and pPlayer.IsConnected() )
		return GetKVInt( pPlayer, KVN_KNOCKOUT ) == 1;

	return false;
}

//g_bIsKnockOut
void SetKnockedOut( CBasePlayer@ pPlayer, bool bValue )
{
	if( pPlayer !is null and pPlayer.IsConnected() )
	{
		int iValue = bValue ? 1 : 0;
		SetKV( pPlayer, KVN_ISKNOCKEDOUT, iValue );
	}
}

bool IsKnockedOut( CBasePlayer@ pPlayer )
{
	bool bReturnValue = false;

	if( pPlayer !is null and pPlayer.IsConnected() )
		bReturnValue = ( GetKVInt(pPlayer, KVN_ISKNOCKEDOUT) == 1 );

	//g_Game.AlertMessage( at_notice, "IsKnockedOut: %1\n", bReturnValue );

	return bReturnValue;
}

//g_KnockOutTime
void SetKnockOutTime( CBasePlayer@ pPlayer, float flTime )
{
	if( pPlayer !is null and pPlayer.IsConnected() )
		SetKV( pPlayer, KVN_KNOCKOUTTIME, flTime );
}

float GetKnockOutTime( CBasePlayer@ pPlayer )
{
	if( pPlayer !is null and pPlayer.IsConnected() )
		return GetKVFloat( pPlayer, KVN_KNOCKOUTTIME );

	return 0.0;
}

//g_KnockOutEndTime
void SetKnockOutEndTime( CBasePlayer@ pPlayer, float flTime )
{
	if( pPlayer !is null and pPlayer.IsConnected() )
		SetKV( pPlayer, KVN_KNOCKOUTENDTIME, flTime );
}

float GetKnockOutEndTime( CBasePlayer@ pPlayer )
{
	if( pPlayer !is null and pPlayer.IsConnected() )
		return GetKVFloat( pPlayer, KVN_KNOCKOUTENDTIME );

	return 0.0;
}

//g_WakeUpHealth
void SetWakeUpHealth( CBasePlayer@ pPlayer, float flTime )
{
	if( pPlayer !is null and pPlayer.IsConnected() )
		SetKV( pPlayer, KVN_WAKEUPHEALTH, flTime );
}

float GetWakeUpHealth( CBasePlayer@ pPlayer )
{
	if( pPlayer !is null and pPlayer.IsConnected() )
		return GetKVFloat( pPlayer, KVN_WAKEUPHEALTH );

	return 0.0;
}

void SetShouldCreateCorpse( CBasePlayer@ pPlayer, bool bValue )
{
	if( pPlayer !is null and pPlayer.IsConnected() )
	{
		int iValue = bValue ? 1 : 0;
		SetKV( pPlayer, KVN_CREATECORPSE, iValue );
	}
}

bool GetShouldCreateCorpse( CBasePlayer@ pPlayer )
{
	bool bReturnValue = false;

	if( pPlayer !is null and pPlayer.IsConnected() )
		bReturnValue = ( GetKVInt(pPlayer, KVN_CREATECORPSE) == 1 );

	return bReturnValue;
}

//g_NextDrinkSound
void SetNextDrinkSound( CBasePlayer@ pPlayer, float flTime )
{
	if( pPlayer !is null and pPlayer.IsConnected() )
		SetKV( pPlayer, KVN_NEXTDRINKSOUND, flTime );
}

float GetNextDrinkSound( CBasePlayer@ pPlayer )
{
	if( pPlayer !is null and pPlayer.IsConnected() )
		return GetKVFloat( pPlayer, KVN_NEXTDRINKSOUND );

	return 0.0;
}

void SetNextDrinkHeal( CBasePlayer@ pPlayer, float flTime )
{
	if( pPlayer !is null and pPlayer.IsConnected() )
		SetKV( pPlayer, KVN_NEXTDRINKHEAL, flTime );
}

float GetNextDrinkHeal( CBasePlayer@ pPlayer )
{
	if( pPlayer !is null and pPlayer.IsConnected() )
		return GetKVFloat( pPlayer, KVN_NEXTDRINKHEAL );

	return 0.0;
}

void SetCanOpenMenu( CBasePlayer@ pPlayer, bool bValue )
{
	if( pPlayer !is null and pPlayer.IsConnected() )
	{
		int iValue = bValue ? 1 : 0;
		SetKV( pPlayer, KVN_CANOPENMENU, iValue );
	}
}

bool GetCanOpenMenu( CBasePlayer@ pPlayer )
{
	bool bReturnValue = false;

	if( pPlayer !is null and pPlayer.IsConnected() )
		bReturnValue = ( GetKVInt(pPlayer, KVN_CANOPENMENU) == 1 );

	return bReturnValue;
}

void SetPlayerTeam( CBasePlayer@ pPlayer, int teamid )
{
	if( pPlayer !is null and pPlayer.IsConnected() )
		SetKV( pPlayer, KVN_TEAM, teamid );
}

int GetPlayerTeam( CBaseEntity@ pEntity )
{
	CBasePlayer@ pPlayer = cast<CBasePlayer@>( pEntity );
	if( pPlayer !is null and pPlayer.IsConnected() )
		return GetKVInt( pPlayer, KVN_TEAM );

	return TEAM_NONE;
}

void SetPlayerClass( CBasePlayer@ pPlayer, int iClass )
{
	if( pPlayer !is null and pPlayer.IsConnected() )
	{
		//pPlayer.pev.playerclass = iClass;
		SetKV( pPlayer, KVN_CLASS, iClass );
	}
}

int GetPlayerClass( CBasePlayer@ pPlayer )
{
	if( pPlayer !is null and pPlayer.IsConnected() )
	{
		//return pPlayer.pev.playerclass;
		return GetKVInt( pPlayer, KVN_CLASS );
	}

	return CLASS_NOCLASS;
}

void AddPointsToScore( int team, int value )
{
	g_iTeamScore[ team - 1 ] += value;
}

int GetTeamScore( int team )
{
	return g_iTeamScore[ team - 1 ];
}

void SetClassAttributes( CBasePlayer@ pPlayer )
{
	if( DEBUG )
		g_Game.AlertMessage( at_notice, "SetClassAttributes: %1\n", GetPlayerClass(pPlayer) );

	switch( GetPlayerClass(pPlayer) )
	{
		case CLASS_HUMAN_FATHER: SetClassFather(pPlayer); break;
		case CLASS_HUMAN_MOLLY: SetClassMolly(pPlayer); break;
		case CLASS_HUMAN_EIGHTBALL: SetClassEightBall(pPlayer); break;
		case CLASS_VAMP_LOUIS: SetClassLouis(pPlayer); break;
		case CLASS_VAMP_EDGAR: SetClassEdgar(pPlayer); break;
		case CLASS_VAMP_NINA: SetClassNina(pPlayer); break;
	}
}

void SetHuman( CBasePlayer@ pPlayer )
{
	pPlayer.RemoveAllItems(); //removeSuit, removeLongJump
	pPlayer.SetItemPickupTimes( 0.0 ); //class weapons can't be added without this :aRage:

	g_EntityFuncs.DispatchKeyValue( pPlayer.edict(), "classify", string(CLASS_TEAM4) ); //green color //CLASS_PLAYER

	pPlayer.pev.health = pPlayer.pev.max_health;
	pPlayer.pev.flTimeStepSound = 400; //footsteps on
	pPlayer.SetMaxSpeedOverride( SLAYER_MAXSPEED );
}

void SetClassFather( CBasePlayer@ pPlayer )
{
	SetPlayerClass( pPlayer, CLASS_HUMAN_FATHER );
	SetPlayerModel( pPlayer, "fatherd" );

	SetHuman( pPlayer );

	pPlayer.GiveNamedItem( "weapon_vsshotgun" );
	pPlayer.GiveNamedItem( "weapon_vsdbshotgun" );
	pPlayer.GiveNamedItem( "weapon_vsstake" );

	pPlayer.GiveAmmo( 28, "vsshotgunammo", 28 );
	pPlayer.GiveAmmo( 32, "vsdbshotgunammo", 32 );
}

void SetClassMolly( CBasePlayer@ pPlayer )
{
	SetPlayerClass( pPlayer, CLASS_HUMAN_MOLLY );
	SetPlayerModel( pPlayer, "molly" );

	SetHuman( pPlayer );

	pPlayer.GiveNamedItem( "weapon_vscrossbow" ); //50 damage normal, 100(or more??) sniper
	pPlayer.GiveNamedItem( "weapon_vscolt" );
	pPlayer.GiveNamedItem( "weapon_vsmp5" );

	pPlayer.GiveAmmo( 6, "vscrossbowammo", 6 );
	pPlayer.GiveAmmo( 42, "vscoltammo", 42 );
	pPlayer.GiveAmmo( 108, "vsmp5ammo", 108 );
}

void SetClassEightBall( CBasePlayer@ pPlayer )
{
	SetPlayerClass( pPlayer, CLASS_HUMAN_EIGHTBALL );
	SetPlayerModel( pPlayer, "eightball" );

	SetHuman( pPlayer );

	pPlayer.GiveNamedItem( "weapon_vswinchester" );
	pPlayer.GiveNamedItem( "weapon_vsthunderfive");
	pPlayer.GiveNamedItem( "weapon_vscue" );

	pPlayer.GiveAmmo( 24, "vswinchesterammo", 24 );
	pPlayer.GiveAmmo( 19, "vsthunderfiveammo", 19 );
}

void SetVampire( CBasePlayer@ pPlayer )
{
	pPlayer.RemoveAllItems(); //removeSuit, removeLongJump
	pPlayer.SetItemPickupTimes( 0.0 ); //class weapons can't be added without this :aRage:

	hl_set_user_longjump( pPlayer, true, false );
	pPlayer.GiveNamedItem( "weapon_vsclaw" );
	
	//if( !IsPlayerBot(pPlayer) ) // bots need this info for select weapons
		//set_pev(id, pev_weapons, 1 << 31); // //WEAPON_SUIT HLW_SUIT // hack: hide weapon from weapon slots making think player has no weapons

	g_EntityFuncs.DispatchKeyValue( pPlayer.edict(), "classify", string(CLASS_TEAM2) ); //red color //CLASS_ALIEN_MILITARY

	pPlayer.pev.health = pPlayer.pev.max_health;
	pPlayer.pev.flTimeStepSound = 999; //silent footsteps
	pPlayer.SetMaxSpeedOverride( VAMP_MAXSPEED );
}

void SetClassEdgar( CBasePlayer@ pPlayer )
{
	SetPlayerClass( pPlayer, CLASS_VAMP_EDGAR );
	SetPlayerModel( pPlayer, "edgar" );

	SetVampire( pPlayer );

	SetKnockOutTime( pPlayer, VAMP_EDGAR_KNOCKOUT_DURATION );
	SetWakeUpHealth( pPlayer, VAMP_EDGAR_WAKEUP_HEALTH );
}

void SetClassLouis( CBasePlayer@ pPlayer )
{
	SetPlayerClass( pPlayer, CLASS_VAMP_LOUIS );
	SetPlayerModel( pPlayer, "louis" );

	SetVampire( pPlayer );

	SetKnockOutTime( pPlayer, VAMP_LOUIS_KNOCKOUT_DURATION );
	SetWakeUpHealth( pPlayer, VAMP_LOUIS_WAKEUP_HEALTH );
}

void SetClassNina( CBasePlayer@ pPlayer )
{
	SetPlayerClass( pPlayer, CLASS_VAMP_NINA );
	SetPlayerModel( pPlayer, "nina" );

	SetVampire( pPlayer );

	SetKnockOutTime( pPlayer, VAMP_NINA_KNOCKOUT_DURATION );
	SetWakeUpHealth( pPlayer, VAMP_NINA_WAKEUP_HEALTH );
}

void SetPlayerModel( CBasePlayer@ pPlayer, string sModelName )
{
	KeyValueBuffer@ pInfo = g_EngineFuncs.GetInfoKeyBuffer( pPlayer.edict() );
	pInfo.SetValue( "model", sModelName );
	SetKV( pPlayer, KVN_PLAYERMODEL, sModelName );
}

string GetPlayerModel( CBasePlayer@ pPlayer )
{
	if( pPlayer !is null and pPlayer.IsConnected() )
		return GetKVString( pPlayer, KVN_PLAYERMODEL );

	return "";
}

void StartRoundTimer()
{
	if( DEBUG )
		g_Game.AlertMessage( at_notice, "StartRoundTimer()\n" );

	if( schedRoundTimer !is null )
		g_Scheduler.RemoveTimer( schedRoundTimer );

	if( RoundTimerCheck() )
	{
		DisplayTimer();
		RoundTimerThink(); //make sure it gets called at once
		@schedRoundTimer = g_Scheduler.SetInterval( "RoundTimerThink", 1.0 );
	}
}

void RoundTimerThink()
{
	if( DEBUG )
		g_Game.AlertMessage( at_notice, "RoundTimerThink g_flRoundTime: %1\n", g_flRoundTime );

	/*not instant enough, doing this in func_breakpoints instead
	if( g_iBreakPoints >= BREAKPOINTS_TO_WIN )
	{
		g_iRoundWinner = TEAM_SLAYER;
		RoundEnd();
	}*/

	if( g_flRoundTime <= 0 )
	{
		g_iRoundWinner = TEAM_NONE;
		RoundEnd();
	}

	if( RoundTimerCheck() )
	{
		g_flRoundTime--;

		if( DEBUG )
			g_Game.AlertMessage( at_notice, "RoundTimerThink g_flRoundTime reduced: %1\n", g_flRoundTime );
	}
}

bool RoundTimerCheck()
{
	if( DEBUG )
		g_Game.AlertMessage( at_notice, "RoundTimerCheck() g_bRoundStarted: %1, g_flRoundTime: %2\n", g_bRoundStarted, g_flRoundTime );

	return g_bRoundStarted and g_flRoundTime > 0 ? true : false;
}

void PlaySoundAll( string sound, bool bRemoveExtension = true )
{
	//Without this, "S_LoadSound: Couldn't load /items/_period.wav" gets printed to console every time
	string snd = sound;

	if( bRemoveExtension )
		snd = sound.SubString( 0, sound.Length()-4 );

	if( DEBUG )
		g_Game.AlertMessage( at_notice, "PlaySoundAll snd: %1\n", snd );

	for( int i = 1; i <= g_Engine.maxClients; i++ )
	{
		CBasePlayer@ pPlayer = g_PlayerFuncs.FindPlayerByIndex( i );

		if( pPlayer !is null and pPlayer.IsConnected() )
		{
			NetworkMessage spk( MSG_ONE, NetworkMessages::SVC_STUFFTEXT, pPlayer.edict() );
				spk.WriteString( "speak "+ snd + "\n" );
			spk.End();
		}
	}
}

void SpeakSnd( CBasePlayer@ pPlayer, string sound, bool bRemoveExtension = true )
{
	//Without this, "S_LoadSound: Couldn't load /items/_period.wav" gets printed to console every time
	string snd = sound;

	if( bRemoveExtension )
		snd = sound.SubString( 0, sound.Length()-4 );

	if( DEBUG )
		g_Game.AlertMessage( at_notice, "SpeakSnd snd: %1\n", snd );

	if( pPlayer !is null and pPlayer.IsConnected() )
	{
		NetworkMessage spk( MSG_ONE, NetworkMessages::SVC_STUFFTEXT, pPlayer.edict() );
			spk.WriteString( "speak "+ snd + "\n" );
		spk.End();
	}
}

void ChangePlayerTeam( CBasePlayer@ pPlayer, int teamid, bool kill = false )
{
	if( !EXPERIMENTAL )
		return;

	CBaseEntity@ pGameTeamMaster = FindGameTeamMaster();
	CBaseEntity@ pGamePlayerTeam = FindGamePlayerTeam();
	int iSpawnFlags = 0;

	if( pGameTeamMaster is null )
	{
		@pGameTeamMaster = g_EntityFuncs.Create( "game_team_master", g_vecZero, g_vecZero, false );
		pGameTeamMaster.pev.targetname = "changeteam"; //set_pev(pGameTeamMaster, pev_targetname, "changeteam");
	}

	if( pGamePlayerTeam is null )
	{
		@pGamePlayerTeam = g_EntityFuncs.Create( "game_player_team", g_vecZero, g_vecZero, false );
		g_EntityFuncs.DispatchKeyValue( pGamePlayerTeam.edict(), "target", "changeteam" ); //DispatchKeyValue(pGamePlayerTeam, "target", "changeteam");
	}

	if( kill )
		iSpawnFlags |= 2; //SF_PTEAM_KILL (Kill Player)

	pGamePlayerTeam.pev.spawnflags = iSpawnFlags;

	g_EntityFuncs.DispatchKeyValue( pGameTeamMaster.edict(), "teamindex", string(teamid - 1) ); //DispatchKeyValue(pGameTeamMaster, "teamindex", fmt("%i", teamid - 1));

	pGamePlayerTeam.Use( pPlayer, null, USE_ON, 0.0 ); //ExecuteHamB(Ham_Use, pGamePlayerTeam, id, 0, USE_ON, 0.0);

	if( EXPERIMENTAL and pPlayer.GetObserver().IsObserver() )
	{
		NetworkMessage m1( MSG_ALL, NetworkMessages::TeamInfo ); //84
			m1.WriteByte( pPlayer.entindex() );
			m1.WriteString( "" );
		m1.End();
	}
}

CBaseEntity@ FindGameTeamMaster()
{
	CBaseEntity@ pEntity = null;
	while( (@pEntity = g_EntityFuncs.FindEntityByClassname(pEntity, "game_team_master")) !is null )
	{
		if( pEntity.pev.targetname == "changeteam" )
			return pEntity;
	}

	return null;
}

CBaseEntity@ FindGamePlayerTeam()
{
	CBaseEntity@ pEntity = null;
	while( (@pEntity = g_EntityFuncs.FindEntityByClassname(pEntity, "game_player_team")) !is null )
	{
		return pEntity;
	}

	return null;
}

void UpdateTeamNames( CBasePlayer@ pPlayer = null )
{
	string sSlayer; //[HL_MAX_TEAMNAME_LENGTH]
	string sVampire; //[HL_MAX_TEAMNAME_LENGTH]

	//Get translated team name
	if( pPlayer !is null )
	{
		sSlayer = lang::getLocalizedText( pPlayer, "TITLE_SLAYER" );
		sVampire = lang::getLocalizedText( pPlayer, "TITLE_VAMPIRE" );
	}
	else
	{
		sSlayer = lang::getStringFromLanguage( lang::LANG_ENGLISH, "TITLE_SLAYER" );
		sVampire = lang::getStringFromLanguage( lang::LANG_ENGLISH, "TITLE_VAMPIRE" );
	}

	sSlayer.ToUppercase();
	sVampire.ToUppercase();

	if( DEBUG )
		g_Game.AlertMessage( at_logged, "sSlayer: %1, sVampire: %2\n", sSlayer, sVampire );

	hl_set_user_teamnames( pPlayer, "<nullteam>", sVampire, "<nullteam>", sSlayer );
}

void UpdateTeamScore( CBasePlayer@ pPlayer = null )
{
	hl_set_user_teamscore( pPlayer, TEAMNAME_SLAYER, GetTeamScore(TEAM_SLAYER) );
	hl_set_user_teamscore( pPlayer, TEAMNAME_VAMPIRE, GetTeamScore(TEAM_VAMPIRE) );
}

bool IsPlayerBot( CBasePlayer@ pPlayer )
{
	return HasFlags( pPlayer.pev.flags, FL_FAKECLIENT );
}

void set_user_rendering( CBasePlayer@ pPlayer, int fx = kRenderFxNone, int r = 0, int g = 0, int b = 0, int render = kRenderNormal, int amount = 0 )
{
	if( pPlayer is null or !pPlayer.IsConnected() )
	{
		g_Game.AlertMessage( at_logged, "pPlayer is null or not connected in set_user_rendering\n" );
		return;
	}

	pPlayer.pev.renderfx = fx;
	pPlayer.pev.rendercolor = Vector( r, g, b );
	pPlayer.pev.rendermode = render;
	pPlayer.pev.renderamt = amount;
}

void HUDMessage( CBasePlayer@ pPlayer, const string& in text, int channel = 1, float x = -1, float y = -1, RGBA color = RGBA_WHITE, float fin = 0.5, float fout = 0.5, float hold = 5.0 )
{
	HUDTextParams textParams;

	textParams.x = x;
	textParams.y = y;
	textParams.effect = 0;

	textParams.r1 = textParams.r2 = color.r;
	textParams.g1 = textParams.g2 = color.g;
	textParams.b1 = textParams.b2 = color.b;
	textParams.a1 = textParams.a2 = color.a;

	textParams.fadeinTime = fin;
	textParams.fadeoutTime = fout;
	textParams.holdTime = hold;
	textParams.fxTime = 0;
	textParams.channel = channel;

	if( pPlayer !is null )
		g_PlayerFuncs.HudMessage( pPlayer, textParams, text );
	else
		g_PlayerFuncs.HudMessageAll( textParams, text );
}

void VSSettings( const CCommand@ args )
{
	CBasePlayer@ pPlayer = g_ConCommandSystem.GetCurrentPlayer();

	if( args.ArgC() < 2 ) //If no args are supplied
	{
		if( args.Arg(0) == "vs_roundtime" )
			g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTCONSOLE, "\"vs_roundtime\" is \"" + cvar_flRoundTime.GetFloat() + "\"\n" );
		else if( args.Arg(0) == "vs_roundlimit" )
			g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTCONSOLE, "\"vs_roundlimit\" is \"" + cvar_iRoundLimit.GetInt() + "\"\n" );
	}
	else if( args.ArgC() == 2 ) //If one arg is supplied (value to set)
	{
		if( args.Arg(0) == "vs_roundtime" and Math.clamp(0.0, 9999.0, atof(args.Arg(1))) != cvar_flRoundTime.GetFloat() )
		{
			cvar_flRoundTime.SetFloat( Math.clamp(0.0, 9999.0, atof(args.Arg(1))) );
			g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTCONSOLE, "\"vs_roundtime\" changed to \"" + cvar_flRoundTime.GetFloat() + "\"\n" );
		}
		else if( args.Arg(0) == "vs_roundlimit" and Math.clamp(0, 99, atoi(args.Arg(1))) != cvar_iRoundLimit.GetInt() )
		{
			cvar_iRoundLimit.SetInt( Math.clamp(0, 99, atoi(args.Arg(1))) );
			g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTCONSOLE, "\"vs_roundlimit\" changed to \"" + cvar_iRoundLimit.GetInt() + "\"\n" );
		}
	}
}

void CmdRestartGame( const CCommand@ args )
{
	 //if( g_PlayerFuncs.AdminLevel(pPlayer) == ADMIN_NO )
		//return;

	// reset players score
	for( int i = 1; i <= g_Engine.maxClients; i++ )
	{
		CBasePlayer@ pPlayer = g_PlayerFuncs.FindPlayerByIndex( i );

		if( pPlayer !is null and pPlayer.IsConnected() )
			hl_set_user_score( pPlayer, 0, 0 );
	}

	// reset team score
	for( uint i = 0; i < g_iTeamScore.length(); ++i )
	{
		g_iTeamScore[i] = 0;
	}

	UpdateTeamScore();

	g_bRoundStarted = false;
	RoundStart();
	lang::ClientPrintAll( HUD_PRINTCENTER, "ROUND_RESTART" );
}

void CmdRestartRound( const CCommand@ args )
{
	 //if( g_PlayerFuncs.AdminLevel(pPlayer) == ADMIN_NO )
		//return;

	g_bRoundStarted = false;
	RoundStart();
	lang::ClientPrintAll( HUD_PRINTCENTER, "ROUND_RESTART" );
}

} //namespace vs END

//"Client lost reserved sound!" :aRage:
//ERROR:  Decrypt processing error: HashVerificationFilter: message hash or MAC not valid ???
//ERROR:  Decrypt error: Encrpyted digest mismatch. - when adding bots