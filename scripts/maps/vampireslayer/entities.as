#include "entities/info_player_starts"
#include "entities/vs_head"
#include "entities/vs_corpse"
#include "entities/func_breakpoints"

namespace vs
{

const array<string> arrsRemoveWeapons =
{
	"weapon_357",
	"weapon_9mmAR",
	"weapon_9mmhandgun",
	"weapon_crossbow",
	"weapon_egon",
	"weapon_gauss",
	"weapon_handgrenade",
	"weapon_hornetgun",
	"weapon_rpg",
	"weapon_satchel",
	"weapon_shotgun",
	"weapon_snark",
	"weapon_tripmine",
	"weaponbox",
	"weapon_vsclaw",
	"weapon_vsstake",
	"weapon_vscolt",
	"weapon_vscue",
	"weapon_vsmp5",
	"weapon_vsshotgun",
	"weapon_vsthunderfive",
	"weapon_vsdbshotgun",
	"weapon_vswinchester",
	"weapon_vscrossbow"
};

const array<string> arrsRemoveAmmo =
{
	"ammo_357",
	"ammo_9mmAR",
	"ammo_9mmbox",
	"ammo_9mmclip",
	"ammo_ARgrenades",
	"ammo_buckshot",
	"ammo_crossbow",
	"ammo_egonclip",
	"ammo_gaussclip",
	"ammo_glockclip",
	"ammo_mp5clip",
	"ammo_mp5grenades",
	"ammo_rpgclip"
};

const array<string> arrsRemoveItems =
{
	"item_longjump",
	"item_suit",
	"item_battery",
	"item_healthkit",
	"vs_head",
	"vs_corpse"
};

void RegisterEntities()
{
	vs_playerstart::Register();
	vs_head::Register();
	vs_corpse::Register();
	vs_breakpoints::Register();
}

void BSPCompatInit()
{
/*
	// spawn all func_breakpoints
	for (new i; i < ArraySize(g_BreakPointsList); i++)
	{
		dllfunc(DLLFunc_Spawn, ArrayGetCell(g_BreakPointsList, i));
	}
*/
	//if( g_CustomSpawnsExist )
	{
		if( vs::EXPERIMENTAL )
		{
			CreateGameTeamMaster( "team1", TEAM_SLAYER );
			CreateGameTeamMaster( "team2", TEAM_VAMPIRE );
		}

		RemoveNoTeamSpawns();
	}

	RemoveItems();
	DisableChargers();
}

CBaseEntity@ CreateGameTeamMaster( string sTargetName, int teamid )
{
	CBaseEntity@ pEntity = g_EntityFuncs.Create( "game_team_master", g_vecZero, g_vecZero, false );
	pEntity.pev.targetname = sTargetName;

	g_EntityFuncs.DispatchKeyValue( pEntity.edict(), "teamindex", string(teamid - 1) ); //DispatchKeyValue(ent, "teamindex", fmt("%i", teamid - 1));

	return pEntity;
}

// remove deathmatch spawns so the team spawns can work correctly
void RemoveNoTeamSpawns()
{
	CBaseEntity@ pEntity;
	while( (@pEntity = g_EntityFuncs.FindEntityByClassname(pEntity, "info_player_deathmatch")) !is null )
	{
		string sNetName = pEntity.pev.netname;
		if( sNetName != "team1" and sNetName != "team2" )
			g_EntityFuncs.Remove( pEntity );
	}
}

void RemoveItems()
{
	for( uint i = 0; i < arrsRemoveWeapons.length(); ++i )
	{
		CBaseEntity@ pEntity;
		while( (@pEntity = g_EntityFuncs.FindEntityByClassname(pEntity, arrsRemoveWeapons[i])) !is null )
		{
			if( pEntity.pev.owner is null ) //not really needed as FL_KILLME shouldn't affect any weapons a player has
			{
				pEntity.pev.flags = FL_KILLME;
				g_Game.AlertMessage( at_notice, "RemoveItems REMOVED %1\n", pEntity.GetClassname() );
			}
		}
	}

	for( uint i = 0; i < arrsRemoveAmmo.length(); ++i )
	{
		CBaseEntity@ pEntity;
		while( (@pEntity = g_EntityFuncs.FindEntityByClassname(pEntity, arrsRemoveAmmo[i])) !is null )
		{
			pEntity.pev.flags = FL_KILLME;
			g_Game.AlertMessage( at_notice, "RemoveItems REMOVED %1\n", pEntity.GetClassname() );
		}
	}

	for( uint i = 0; i < arrsRemoveItems.length(); ++i )
	{
		CBaseEntity@ pEntity;
		while( (@pEntity = g_EntityFuncs.FindEntityByClassname(pEntity, arrsRemoveItems[i])) !is null )
		{
			pEntity.pev.flags = FL_KILLME;
			g_Game.AlertMessage( at_notice, "RemoveItems REMOVED %1\n", pEntity.GetClassname() );
		}
	}
}

void DisableChargers()
{
	/*new ent;
	while ((ent = find_ent_by_class(ent, "func_recharge")))
	{
		new ptr = pev(ent, pev_model);
		remove_entity(ent);
		
		new ent2 = create_entity("func_wall");
		set_pev_string(ent2, pev_model, ptr);
		DispatchSpawn(ent2);
	}

	ent = 0;
	while ((ent = find_ent_by_class(ent, "func_healthcharger")))
	{
		new ptr = pev(ent, pev_model);
		remove_entity(ent);
		
		new ent2 = create_entity("func_wall");
		set_pev_string(ent2, pev_model, ptr);
		DispatchSpawn(ent2);
	}*/
}

void RestoreVSEntities()
{
	CBaseEntity@ torestart = g_EntityFuncs.FindEntityByClassname( null, "func_breakpoints" );

	while( torestart !is null )
	{
		vs_breakpoints::func_breakpoints@ pBreakPoints = cast<vs_breakpoints::func_breakpoints@>( CastToScriptClass(torestart) );
		if( pBreakPoints !is null )
			pBreakPoints.Restart();

		@torestart = g_EntityFuncs.FindEntityByClassname( torestart, "func_breakpoints" );
	}
}

} //namespace vs END



//@PointClass  base(PlayerClass) size(-16 -16 -36, 16 16 36) color(255 0 0) = info_player_vampire : "Player Vampire start" []
//@PointClass  base(PlayerClass) size(-16 -16 -36, 16 16 36) color(0 255 0) = info_player_slayer : "Player Slayer start" []
//@PointClass  base(PlayerClass) size(-16 -16 -36, 16 16 36) color(0 0 255) = info_draw_slayerswin : "Slayers win in a round draw" []
//@PointClass  base(PlayerClass) size(-16 -16 -36, 16 16 36) color(0 0 255) = info_draw_vampireswin : "Vimpires win in a round draw" []

/*@PointClass  base(PlayerClass) size(-16 -16 -16, 16 16 16) color(100 200 200) = info_dm : "Enable Deathmatch Play"
[
	delay(integer) : "Time before respawn (secs 1-30)"
]*/

/*@SolidClass base(Breakable, RenderFields, ZHLT) = func_breakpoints : "Breakable Points Object" 
[
	spawnflags(flags) =
	[
		1 : "Only Trigger" : 0
		2 : "Touch"	   : 0
		4 : "Pressure"     : 0
		256: "Instant Crowbar" : 1
	]
	_minlight(string) : "Minimum light level"
	vsteam(integer) : "Team (0=Slayer,1=Vampire)"
	points(integer) : "Points given to team when broken (0-100)"
]*/


//@PointClass size(-16 -16 0, 16 16 36) base(Weapon, Targetx) = item_flag_slayer : "Slayer Flag" []
//@PointClass size(-16 -16 0, 16 16 36) base(Weapon, Targetx) = item_flag_vampire : "Vampire Flag" []