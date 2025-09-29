namespace maprestore
{

const int SF_WALL_START_OFF = 1;

const string KVN_PEV_FRAME = "$i_pevframe";
const string KVN_PEV_ORIGIN = "$v_pevorigin";

void BmodelsMapActivate()
{
	maprestore::SetupBmodelsForRestoring();
}

void SetupBmodelsForRestoring()
{
	CBaseEntity@ pEntity = null;
	while( (@pEntity = g_EntityFuncs.FindEntityByClassname(pEntity, "func_wall")) !is null )
	{
		SetKV( pEntity, KVN_PEV_FRAME, pEntity.pev.frame );

		if( g_bDebug )
			g_Game.AlertMessage( at_notice, "%1 added at %2: %3\n", pEntity.GetClassname(), pEntity.Center().ToString(), pEntity.pev.spawnflags );
	}

	while( (@pEntity = g_EntityFuncs.FindEntityByClassname(pEntity, "func_wall_toggle")) !is null )
	{
		SetKV( pEntity, KVN_PEV_FRAME, pEntity.pev.frame );

		if( g_bDebug )
			g_Game.AlertMessage( at_notice, "%1 added at %2: %3\n", pEntity.GetClassname(), pEntity.Center().ToString(), pEntity.pev.spawnflags );
	}
}

bool RestoreBmodels( string sClassname = "" )
{
	bool bSomethingFound = false;

	if( sClassname == "func_wall" )
		bSomethingFound = RestoreFuncWall();
	else if( sClassname == "func_wall_toggle" )
		bSomethingFound = RestoreFuncWallToggle();
	else
	{
		bool bRestoredFuncWalls = RestoreFuncWall();
		bool bRestoredFuncWallToggles = RestoreFuncWallToggle();

		if( !bRestoredFuncWalls and !bRestoredFuncWallToggles )
			return false;
		else
			return true;
	}

	return bSomethingFound;
}

bool RestoreFuncWall()
{
	bool bSomethingFound = false;
	CBaseEntity@ pEntity = null;

	while( (@pEntity = g_EntityFuncs.FindEntityByClassname(pEntity, "func_wall")) !is null )
	{
		bool bUpdatedSomething = false;

		if( pEntity.pev.frame != GetKVInt(pEntity, KVN_PEV_FRAME) )
		{
			pEntity.pev.frame = GetKVInt( pEntity, KVN_PEV_FRAME );
			bUpdatedSomething = true;
		}

		bUpdatedSomething = RestoreOrigin( pEntity );
		bSomethingFound = true;

		if( g_bDebug and bUpdatedSomething )
			g_Game.AlertMessage( at_notice, "RESTORED %1 (%2) AT: %3\n", pEntity.GetClassname(), pEntity.pev.model, pEntity.Center().ToString() );
	}

	return bSomethingFound;
}

bool RestoreFuncWallToggle()
{
	bool bSomethingFound = false;
	CBaseEntity@ pEntity = null;

	while( (@pEntity = g_EntityFuncs.FindEntityByClassname(pEntity, "func_wall_toggle")) !is null )
	{
		bool bUpdatedSomething = false;

		if( pEntity.pev.frame != GetKVInt(pEntity, KVN_PEV_FRAME) )
		{
			pEntity.pev.frame = GetKVInt( pEntity, KVN_PEV_FRAME );
			bUpdatedSomething = true;
		}

		if( HasFlags(pEntity.pev.spawnflags, SF_WALL_START_OFF) )
		{
			if( TurnOffWallToggle(pEntity) )
				bUpdatedSomething = true;
		}
		else
		{
			if( TurnOnWallToggle(pEntity) )
				bUpdatedSomething = true;
		}

		bUpdatedSomething = RestoreOrigin( pEntity );
		bSomethingFound = true;

		if( g_bDebug and bUpdatedSomething )
			g_Game.AlertMessage( at_notice, "RESTORED %1 (%2) AT: %3\n", pEntity.GetClassname(), pEntity.pev.model, pEntity.Center().ToString() );
	}

	return bSomethingFound;
}

bool RestoreOrigin( CBaseEntity@ pEntity )
{
	if( pEntity.pev.origin != g_vecZero )
	{
		g_EntityFuncs.SetOrigin( pEntity, g_vecZero );
		return true;
	}

	return false;
}

bool IsWallOff( CBaseEntity@ pEntity )
{
	return ( pEntity.pev.solid == SOLID_NOT and HasFlags(pEntity.pev.effects, EF_NODRAW) );
}

bool TurnOnWallToggle( CBaseEntity@ pEntity )
{
	if( IsWallOff(pEntity) )
	{
		pEntity.pev.solid = SOLID_BSP;
		pEntity.pev.effects &= ~EF_NODRAW;

		/*new Float:origin[3];
		pev(ent, pev_origin, origin);	
		engfunc(EngFunc_SetOrigin, ent, origin);*/

		return true;
	}

	return false;
}

bool TurnOffWallToggle( CBaseEntity@ pEntity )
{
	if( !IsWallOff(pEntity) )
	{
		pEntity.pev.solid = SOLID_NOT;
		pEntity.pev.effects |= EF_NODRAW;
		
		/*new Float:origin[3];
		pev(ent, pev_origin, origin);	
		engfunc(EngFunc_SetOrigin, ent, origin);*/

		return true;
	}

	return false;
}

} //namespace maprestore END