//called restore because if the commands start with "restart" people might accidentally restart the map instead D:
//inspired by Counter-Strike and the AMXX plugin Restore Map by rtxA

#include "restore_breakables"
#include "restore_lights"
#include "restore_buttons"
#include "restore_env"
#include "restore_bmodels"
#include "restore_doors"

namespace maprestore
{

//CClientCommand restore_all( "restore_all", "Restores all entities.", @maprestore::RestoreAllCMD );
CClientCommand restore( "restore", "Restores all entities of the specified class. Enter * for all.", @maprestore::RestoreByClassCMD ); //restore_by_class

bool g_bDebug = false;

void Initialize()
{
	maprestore::BreakablesMapActivate();
	maprestore::LightsMapActivate();
	maprestore::EnvMapActivate();
	maprestore::BmodelsMapActivate();
}

void RestoreAllCMD( const CCommand@ args )
{
	CBasePlayer@ pPlayer = g_ConCommandSystem.GetCurrentPlayer();

	if( RestoreAll() )
		g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTCONSOLE, "Restored everything.\n" );
	else
		g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTCONSOLE, "Nothing to restore.\n" );
}

bool RestoreAll()
{
	bool bRestoredBreakables = RestoreBreakables();
	bool bRestoredPushables = RestorePushables();
	bool bRestoredLights = RestoreLights();
	bool bRestoredButtons = RestoreButtons();
	bool bRestoredRotButtons = RestoreRotButtons();
	bool bRestoredEnv = RestoreEnv();
	bool bRestoredBmodels = RestoreBmodels();
	bool bRestoredDoors = RestoreDoors();
	bool bRestoredRotDoors = RestoreRotDoors();

	if( !bRestoredBreakables and !bRestoredPushables and !bRestoredLights and !bRestoredButtons and !bRestoredRotButtons and !bRestoredEnv and !bRestoredBmodels and !bRestoredDoors and !bRestoredRotDoors )
		return false;
	else
		return true;
}

void RestoreByClassCMD( const CCommand@ args )
{
	CBasePlayer@ pPlayer = g_ConCommandSystem.GetCurrentPlayer();

	if( args.ArgC() < 2 )
	{
		g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTCONSOLE, "restore <classname> or * for all\n" );
		return;
	}

	string sClassname = args.Arg( 1 );

	if( sClassname == "*" )
		RestoreAllCMD( args );
	else
	{
		bool bNothingToRestore = RestoreByClass( sClassname );

		if( bNothingToRestore )
			g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTCONSOLE, "Map has no " + sClassname + " entities to restore.\n" );
		else
			g_PlayerFuncs.ClientPrint( pPlayer, HUD_PRINTCONSOLE, "Restored all " + sClassname + " entities.\n" );
	}
}

bool RestoreByClass( const string &in sClassname )
{
	bool bNothingToRestore = false;

	if( sClassname == "func_breakable" )
	{
		if( !RestoreBreakables() )
			bNothingToRestore = true;
	}
	else if( sClassname == "func_pushable" )
	{
		if( !RestorePushables() )
			bNothingToRestore = true;
	}
	else if( sClassname == "light" )
	{
		if( !RestoreLights() )
			bNothingToRestore = true;
	}
	else if( sClassname == "env_sprite" )
	{
		if( !RestoreEnv() )
			bNothingToRestore = true;
	}
	else if( sClassname == "func_button" )
	{
		if( !RestoreButtons() )
			bNothingToRestore = true;
	}
	else if( sClassname == "func_rot_button" )
	{
		if( !RestoreRotButtons() )
			bNothingToRestore = true;
	}
	else if( sClassname == "func_wall" or sClassname == "func_wall_toggle" )
	{
		if( !RestoreBmodels(sClassname) )
			bNothingToRestore = true;
	}
	else if( sClassname == "func_door" )
	{
		if( !RestoreDoors() )
			bNothingToRestore = true;
	}
	else if( sClassname == "func_water" )
	{
		if( !RestoreDoors(true) )
			bNothingToRestore = true;
	}
	else if( sClassname == "func_door_rotating" )
	{
		if( !RestoreRotDoors() )
			bNothingToRestore = true;
	}

	return bNothingToRestore;
}

void SetMovedir( CBaseEntity@ pEntity )
{
	if( pEntity.pev.angles == Vector(0, -1, 0) )
		pEntity.pev.movedir = Vector( 0, 0, 1 );
	else if( pEntity.pev.angles == Vector(0, -2, 0) )
		pEntity.pev.movedir = Vector( 0, 0, -1 );
	else
	{
		Math.MakeVectors( pEntity.pev.angles );
		pEntity.pev.movedir = g_Engine.v_forward;
	}

	pEntity.pev.angles = g_vecZero;
}

void AxisDir( CBaseEntity@ pButton )
{
	if( HasFlags(pButton.pev.spawnflags, SF_DOOR_ROTATE_Z) )
		pButton.pev.movedir = Vector( 0, 0, 1 );
	else if( HasFlags(pButton.pev.spawnflags, SF_DOOR_ROTATE_X) )
		pButton.pev.movedir = Vector( 1, 0, 0 );
	else
		pButton.pev.movedir = Vector( 0, 1, 0 );
}

bool HasFlags( int iFlagVariable, int iFlags )
{
	return (iFlagVariable & iFlags) != 0;
}

void SetKV( CBaseEntity@ pEntity, const string &in sKey, const int &in iValue )
{
	if( pEntity is null ) return;

	CustomKeyvalues@ pCustom = pEntity.GetCustomKeyvalues();
	pCustom.SetKeyvalue( sKey, iValue );
}

void SetKV( CBaseEntity@ pEntity, const string &in sKey, const float &in flValue )
{
	if( pEntity is null ) return;

	CustomKeyvalues@ pCustom = pEntity.GetCustomKeyvalues();
	pCustom.SetKeyvalue( sKey, flValue );
}

void SetKV( CBaseEntity@ pEntity, const string &in sKey, const string &in sValue )
{
	if( pEntity is null ) return;

	CustomKeyvalues@ pCustom = pEntity.GetCustomKeyvalues();
	pCustom.SetKeyvalue( sKey, sValue );
}

int GetKVInt( CBaseEntity@ pEntity, const string &in sKey )
{
	if( pEntity is null ) return 0;

	CustomKeyvalues@ pCustom = pEntity.GetCustomKeyvalues();
	CustomKeyvalue keyValue = pCustom.GetKeyvalue( sKey );

	if( keyValue.Exists() )
		return keyValue.GetInteger();

	return 0;
}

float GetKVFloat( CBaseEntity@ pEntity, const string &in sKey )
{
	if( pEntity is null ) return 0.0;

	CustomKeyvalues@ pCustom = pEntity.GetCustomKeyvalues();
	CustomKeyvalue keyValue = pCustom.GetKeyvalue( sKey );

	if( keyValue.Exists() )
		return keyValue.GetFloat();

	return 0.0;
}

string GetKVString( CBaseEntity@ pEntity, const string &in sKey )
{
	if( pEntity is null ) return "";

	CustomKeyvalues@ pCustom = pEntity.GetCustomKeyvalues();
	CustomKeyvalue keyValue = pCustom.GetKeyvalue( sKey );

	if( keyValue.Exists() )
		return keyValue.GetString();

	return "";
}

Vector GetKVVector( CBaseEntity@ pEntity, const string &in sKey )
{
	if( pEntity is null ) return g_vecZero;

	CustomKeyvalues@ pCustom = pEntity.GetCustomKeyvalues();
	CustomKeyvalue keyValue = pCustom.GetKeyvalue( sKey );

	if( keyValue.Exists() )
		return keyValue.GetVector();

	return g_vecZero;
}

} //namespace maprestore END