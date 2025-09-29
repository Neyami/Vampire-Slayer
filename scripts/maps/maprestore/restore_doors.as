namespace maprestore
{

bool RestoreDoors( bool bWater = false )
{
	bool bSomethingFound = false;
	string sClassname = bWater ? "func_water" : "func_door";

	CBaseEntity@ pEntity = null;
	while( (@pEntity = g_EntityFuncs.FindEntityByClassname(pEntity, sClassname)) !is null )
	{
		CBaseDoor@ pDoor = cast<CBaseDoor@>( pEntity );
		if( pDoor is null ) continue;

		RestoreDoor( pDoor );

		bSomethingFound = true;

		if( g_bDebug )
			g_Game.AlertMessage( at_notice, "RESTORED %1 (%2) AT: %3\n", pDoor.GetClassname(), pDoor.pev.model, pDoor.Center().ToString() );
	}

	return bSomethingFound;
}

void RestoreDoor( CBaseDoor@ pDoor )
{
	SetMovedir( pDoor );
	pDoor.m_toggle_state = TS_AT_BOTTOM;
	//pDoor.DoorGoDown(); //fixes restoring a moving door, but may cause unforseen consequences D:

	//doesn't work on a moving door
	pDoor.pev.velocity = g_vecZero;
	g_EntityFuncs.SetOrigin( pDoor, pDoor.m_vecPosition1 );

	/*if (FBitSet(pev->spawnflags, SF_DOOR_USE_ONLY))
		SetTouch(NULL);
	else
		SetTouch(&CBaseDoor::DoorTouch);*/
}

bool RestoreRotDoors()
{
	bool bSomethingFound = false;
	CBaseEntity@ pEntity = null;
	while( (@pEntity = g_EntityFuncs.FindEntityByClassname(pEntity, "func_door_rotating")) !is null )
	{
		CBaseDoor@ pDoor = cast<CBaseDoor@>( pEntity );
		if( pDoor is null ) continue;

		RestoreRotDoor( pDoor );

		bSomethingFound = true;

		if( g_bDebug )
			g_Game.AlertMessage( at_notice, "RESTORED %1 (%2) AT: %3\n", pDoor.GetClassname(), pDoor.pev.model, pDoor.Center().ToString() );
	}

	return bSomethingFound;
}

void RestoreRotDoor( CBaseDoor@ pDoor )
{
	AxisDir( pDoor );
	pDoor.m_toggle_state = TS_AT_BOTTOM;

	pDoor.pev.avelocity = g_vecZero;

	if( HasFlags(pDoor.pev.spawnflags, SF_DOOR_ROTATE_BACKWARDS) )
		pDoor.pev.movedir = pDoor.pev.movedir * -1;

	if( pDoor.pev.speed == 0)
		pDoor.pev.speed = 100.0;

	pDoor.pev.angles = pDoor.m_vecAngle1;

	/*if (pev(ent, pev_spawnflags) & SF_DOOR_USE_ONLY)
		set_ent_data(ent, "CBaseEntity", "m_pfnTouch", 0);
	else
		set_ent_data(ent, "CBaseEntity", "m_pfnTouch", pev(ent, Pev_SavedTouchAdress));*/

	/*string sTempTarget = pButton.pev.target;
	pButton.pev.target = "";
	pButton.ButtonBackHome();
	pButton.pev.target = sTempTarget;*/
}

} //namespace maprestore END