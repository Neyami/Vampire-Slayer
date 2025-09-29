namespace maprestore
{

const string KVN_STARTHEALTH = "$f_starthealth";

class MaprestoreBreakable
{
	Vector startorigin;
	string model;
	float health;
	string target;
	string targetname;
	float scale;
	int rendermode;
	float renderamt;
	Vector rendercolor;
	int renderfx;
	int material;
	int explodemagnitude;
	int spawnflags;
}

array<MaprestoreBreakable> arrpBreakables;
array<MaprestoreBreakable> arrpPushables;

dictionary dicMaterials;

void BreakablesMapActivate()
{
	ReadMaterialsFromFile();

	g_Game.PrecacheModel( "models/cindergibs.mdl" );
	g_Game.PrecacheModel( "models/metalplategibs.mdl" );
	maprestore::SetupBreakablesForRestoring();
	maprestore::SetupPushablesForRestoring();
}

void SetupBreakablesForRestoring()
{
	arrpBreakables.resize( 0 );

	CBaseEntity@ pEntity = null;
	while( (@pEntity = g_EntityFuncs.FindEntityByClassname(pEntity, "func_breakable")) !is null )
	{
		if( pEntity.pev.health > 0 )
			SetKV( pEntity, KVN_STARTHEALTH, pEntity.pev.health );

		MaprestoreBreakable breakable;

		breakable.model = pEntity.pev.model;
		breakable.health = pEntity.pev.health;
		breakable.target = pEntity.pev.target;
		breakable.targetname = pEntity.pev.targetname;
		breakable.scale = pEntity.pev.scale;
		breakable.rendermode = pEntity.pev.rendermode;
		breakable.renderamt = pEntity.pev.renderamt;
		breakable.rendercolor = pEntity.pev.rendercolor;
		breakable.renderfx = pEntity.pev.renderfx;
		breakable.material = GetMaterial( pEntity ); //Try to find a way to get private data ?? Save/Restore, ReadField/ReadFields
		breakable.explodemagnitude = pEntity.pev.impulse;
		breakable.spawnflags = pEntity.pev.spawnflags;

		arrpBreakables.insertLast( breakable );
		//g_Game.AlertMessage( at_notice, "%1 added, model: %2, health: %3, material: %4\n", pEntity.GetClassname(), breakable.model, breakable.health, breakable.material );
		//g_Game.AlertMessage( at_notice, "target: %1, targetname: %2, scale: %3\n", breakable.target, breakable.targetname, breakable.scale );
		//g_Game.AlertMessage( at_notice, "rendermode: %1, renderamt: %2\n", breakable.rendermode, breakable.renderamt );
	}
}

bool RestoreBreakables()
{
	if( arrpBreakables.length() <= 0 )
		return false;

	for( uint i = 0; i < arrpBreakables.length(); ++i )
	{
		bool bSpawnDontUpdate = true;

		CBaseEntity@ pEntity = null;
		while( (@pEntity = g_EntityFuncs.FindEntityByClassname(pEntity, "func_breakable")) !is null )
		{
			if( pEntity.pev.model == arrpBreakables[i].model )
			{
				bool bUpdatedSomething = false;

				if( pEntity.pev.health != GetKVFloat(pEntity, KVN_STARTHEALTH) )
				{
					pEntity.pev.health = GetKVFloat( pEntity, KVN_STARTHEALTH );
					bUpdatedSomething = true;
				}

				//if( pEntity.pev.absmin != arrpBreakables[i].absmin or pEntity.pev.absmax != arrpBreakables[i].absmax )
				if( pEntity.pev.origin != g_vecZero )
				{
					g_EntityFuncs.SetOrigin( pEntity, g_vecZero );
					bUpdatedSomething = true;
				}

				if( g_bDebug and bUpdatedSomething )
					g_Game.AlertMessage( at_notice, "RESTORED BREAKABLE (UPDATE): %1\n", arrpBreakables[i].model );

				bSpawnDontUpdate = false;
				break;
			}
		}

		if( bSpawnDontUpdate )
		{
			dictionary keys;
			keys["health"] = string( arrpBreakables[i].health );
			keys["target"] = arrpBreakables[i].target;
			keys["targetname"] = arrpBreakables[i].targetname;
			keys["scale"] = string( arrpBreakables[i].scale );
			keys["material"] = string( arrpBreakables[i].material );
			keys["spawnflags"] = string( arrpBreakables[i].spawnflags );
			CBaseEntity@ pBreakable = g_EntityFuncs.CreateEntity( "func_breakable", keys );

			g_EntityFuncs.SetModel( pBreakable, arrpBreakables[i].model );
			//g_EntityFuncs.SetOrigin( pBreakable, vecCenter ); //this requires func_breakable entities to have an origin brush
			pBreakable.pev.impulse = arrpBreakables[i].explodemagnitude;
			pBreakable.pev.rendermode = arrpBreakables[i].rendermode;
			pBreakable.pev.renderamt = arrpBreakables[i].renderamt;
			pBreakable.pev.rendercolor = arrpBreakables[i].rendercolor;
			pBreakable.pev.renderfx = arrpBreakables[i].renderfx;

			SetKV( pBreakable, KVN_STARTHEALTH, arrpBreakables[i].health );

			if( g_bDebug )
				g_Game.AlertMessage( at_notice, "RESTORED BREAKABLE (RESPAWN): %1\n", arrpBreakables[i].model );
		}
	}

	return true;
}

void SetupPushablesForRestoring()
{
	arrpPushables.resize( 0 );

	CBaseEntity@ pEntity = null;
	while( (@pEntity = g_EntityFuncs.FindEntityByClassname(pEntity, "func_pushable")) !is null )
	{
		if( pEntity.pev.health > 0 )
			SetKV( pEntity, KVN_STARTHEALTH, pEntity.pev.health );

		MaprestoreBreakable pushable;

		pushable.startorigin = pEntity.pev.origin;
		pushable.model = pEntity.pev.model;
		pushable.health = pEntity.pev.health;
		pushable.target = pEntity.pev.target;
		pushable.targetname = pEntity.pev.targetname;
		pushable.scale = pEntity.pev.scale;
		pushable.rendermode = pEntity.pev.rendermode;
		pushable.renderamt = pEntity.pev.renderamt;
		pushable.rendercolor = pEntity.pev.rendercolor;
		pushable.renderfx = pEntity.pev.renderfx;
		pushable.material = GetMaterial( pEntity ); //Try to find a way to get private data ?? Save/Restore, ReadField/ReadFields
		pushable.explodemagnitude = pEntity.pev.impulse;
		pushable.spawnflags = pEntity.pev.spawnflags;

		arrpPushables.insertLast( pushable );
		//g_Game.AlertMessage( at_notice, "Pushable added, model: %1, health: %2, material: %3\n", pushable.model, pushable.health, pushable.material );
		//g_Game.AlertMessage( at_notice, "target: %1, targetname: %2, scale: %3\n", pushable.target, pushable.targetname, pushable.scale );
		//g_Game.AlertMessage( at_notice, "rendermode: %1, renderamt: %2\n", pushable.rendermode, pushable.renderamt );
	}
}

bool RestorePushables()
{
	if( arrpPushables.length() <= 0 )
		return false;

	for( uint i = 0; i < arrpPushables.length(); ++i )
	{
		bool bSpawnDontUpdate = true;

		CBaseEntity@ pEntity = null;
		while( (@pEntity = g_EntityFuncs.FindEntityByClassname(pEntity, "func_pushable")) !is null )
		{
			if( pEntity.pev.model == arrpPushables[i].model )
			{
				if( pEntity.pev.health != GetKVFloat(pEntity, KVN_STARTHEALTH) )
					pEntity.pev.health = GetKVFloat( pEntity, KVN_STARTHEALTH );

				pEntity.pev.movetype = MOVETYPE_PUSHSTEP;
				pEntity.pev.solid = SOLID_BBOX;

				//if( pEntity.pev.friction > 399 )
					//pEntity.pev.friction = 399;

				//set_ent_data_float(ent, "CPushable", "m_soundTime", 0.0);
				//set_ent_data_float(ent, "CPushable", "m_maxSpeed", 400.0 - pev(ent, pev_friction));

				pEntity.pev.flags |= FL_FLOAT;
				//set_pev(ent, pev_friction, 0);
				
				pEntity.pev.velocity = g_vecZero;

				g_EntityFuncs.SetModel( pEntity, arrpPushables[i].model );
				g_EntityFuncs.SetOrigin( pEntity, arrpPushables[i].startorigin );

				if( g_bDebug )
					g_Game.AlertMessage( at_notice, "RESTORED PUSHABLE (UPDATE): %1\n", arrpPushables[i].model );

				bSpawnDontUpdate = false;
			}
		}

		if( bSpawnDontUpdate )
		{
			dictionary keys;
			keys["health"] = string( arrpPushables[i].health );
			keys["target"] = arrpPushables[i].target;
			keys["targetname"] = arrpPushables[i].targetname;
			keys["scale"] = string( arrpPushables[i].scale );
			keys["material"] = string( arrpPushables[i].material );
			keys["spawnflags"] = string( arrpPushables[i].spawnflags );
			CBaseEntity@ pBreakable = g_EntityFuncs.CreateEntity( "func_pushable", keys );

			g_EntityFuncs.SetModel( pBreakable, arrpPushables[i].model );
			g_EntityFuncs.SetOrigin( pBreakable, arrpPushables[i].startorigin );
			pBreakable.pev.impulse = arrpPushables[i].explodemagnitude;
			pBreakable.pev.rendermode = arrpPushables[i].rendermode;
			pBreakable.pev.renderamt = arrpPushables[i].renderamt;
			pBreakable.pev.rendercolor = arrpPushables[i].rendercolor;
			pBreakable.pev.renderfx = arrpPushables[i].renderfx;

			if( g_bDebug )
				g_Game.AlertMessage( at_notice, "RESTORED PUSHABLE (RESPAWN): %1\n", arrpPushables[i].model );
		}
	}

	return true;
}

//some breakables may not be regular geometric shapes, this should take care of that
int GetMaterial( CBaseEntity@ pEntity )
{
	//Check for .mat file first
	int iMaterial = GetMaterialFromFile( pEntity );
	if( iMaterial != -1 )
		return iMaterial;

	TraceResult tr;
	Vector vecTraceStart = pEntity.Center();
	Vector vecTraceDir;

	const array<Vector> arrvecTraceDirs =
	{
		Vector( 0, 0, -1 ),	//down
		Vector( 0, 0, 1 ),	//up
		Vector( -1, 0, 0 ),	//south (based on North being pev.angles 0 0 0)
		Vector( 1, 0, 0 ),	//north
		Vector( 0, -1, 0 ),	//east
		Vector( 0, 1, 0 )		//west
	};

	int iTraceAttempt = 0;
	int iMaxAttempts = arrvecTraceDirs.length();

	while( iTraceAttempt < iMaxAttempts )
	{
		vecTraceDir = arrvecTraceDirs[ iTraceAttempt ];
		g_Utility.TraceLine( vecTraceStart, vecTraceStart + vecTraceDir * 1024, ignore_monsters, null, tr );

		if( tr.pHit is null or tr.pHit !is pEntity.edict() )
		{
			//g_Game.AlertMessage( at_notice, "Trace #%1 failed: %2\n", iTraceAttempt, pEntity.pev.model );

			iTraceAttempt++;
			continue;
		}
		else
		{
			//g_Game.AlertMessage( at_notice, "Trace #%1 success: %2\n", iTraceAttempt, pEntity.pev.model );
			break;
		}
	}

	string sTexture = g_Utility.TraceTexture( pEntity.edict(), vecTraceStart, vecTraceStart + vecTraceDir * 1024 );
	char cType = g_SoundSystem.FindMaterialType( sTexture );

	//g_Game.AlertMessage( at_notice, "GetMaterial cType: %1\n", string(cType) );

	if( string(cType) == "Y" )
		return matGlass;
	else if( string(cType) == "W" )
		return matWood;
	else if( string(cType) == "M" )
		return matMetal; //requires precaching 'models/metalplategibs.mdl'
	else if( string(cType) == "F" )
		return matFlesh;
	else if( string(cType) == "C" )
		return matCinderBlock; //requires precaching 'models/cindergibs.mdl'
	else if( string(cType) == "T" )
		return matCeilingTile;
	else if( string(cType) == "P" )
		return matComputer;
	else if( string(cType) == "D" )
		return matRocks;

	return matNone;
}

int GetMaterialFromFile( CBaseEntity@ pEntity )
{
	int iMaterial = -1;

	if( dicMaterials.getSize() == 0 )
	{
		if( g_bDebug )
			g_Game.AlertMessage( at_notice, "[MAPRESTORE DEBUG] GetMaterialFromFile dicMaterials is empty\n" );

		return -1;
	}

	if( dicMaterials.exists(pEntity.pev.model) )
	{
		iMaterial = atoi( string(dicMaterials[pEntity.pev.model]) );

		if( g_bDebug )
			g_Game.AlertMessage( at_notice, "[MAPRESTORE DEBUG] GetMaterialFromFile model exists: %1 %2\n", pEntity.pev.model, iMaterial );
	}
	else
	{
		if( g_bDebug )
			g_Game.AlertMessage( at_notice, "[MAPRESTORE DEBUG] GetMaterialFromFile no material found for model: %1\n", pEntity.pev.model );
	}

	return iMaterial;
}

void ReadMaterialsFromFile()
{
	dicMaterials.deleteAll();
	string sFileName = "scripts/maps/maprestore/matfiles/" + g_Engine.mapname + ".mat";

	File@ file = g_FileSystem.OpenFile( sFileName, OpenFile::READ );

	if( g_bDebug )
		g_Game.AlertMessage( at_notice, "[MAPRESTORE DEBUG] Looking for materials file in: %1\n", sFileName );

	if( file !is null and file.IsOpen() )
	{
		if( g_bDebug )
			g_Game.AlertMessage( at_notice, "[MAPRESTORE DEBUG] Materials file found for map: %1\n", g_Engine.mapname );

		while( !file.EOFReached() )
		{
			string sLine;
			file.ReadLine(sLine);
			//fix for linux
			string sFix = sLine.SubString( sLine.Length() - 1, 1 );
			if( sFix == " " or sFix == "\n" or sFix == "\r" or sFix == "\t" )
				sLine = sLine.SubString( 0, sLine.Length() - 1 );

			//comment
			if( sLine.SubString(0,2) == "//" or sLine.SubString(0,1) != "*" or sLine.IsEmpty() )
				continue;

			array<string> parsed = sLine.Split(" ");
			if( parsed.length() < 2 )
			{
				if( g_bDebug )
					g_Game.AlertMessage( at_notice, "[MAPRESTORE DEBUG] INVALID LINE: %1\n", sLine );

				continue;
			}

			dicMaterials[ parsed[0] ] = parsed[ 1 ];

			if( g_bDebug )
				g_Game.AlertMessage( at_notice, "[MAPRESTORE DEBUG] Adding material: %1 to model: %2\n", parsed[1], parsed[0] );
		}

		file.Close();
	}
	else
	{
		if( g_bDebug )
			g_Game.AlertMessage( at_notice, "[MAPRESTORE DEBUG] No materials file found for map: %1\n", g_Engine.mapname );
	}
}

} //namespace maprestore END