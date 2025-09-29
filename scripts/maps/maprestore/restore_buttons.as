namespace maprestore
{

const int SF_BUTTON_SPARK_IF_OFF = 64;

bool RestoreButtons()
{
	bool bSomethingFound = false;
	CBaseEntity@ pEntity = null;
	while( (@pEntity = g_EntityFuncs.FindEntityByClassname(pEntity, "func_button")) !is null )
	{
		CBaseButton@ pButton = cast<CBaseButton@>( pEntity );
		if( pButton is null ) continue;

		pButton.m_hActivator = null;
		SetMovedir( pButton );
		pButton.m_toggle_state = TS_AT_BOTTOM;

		ButtonResetPos( pButton );

		pButton.pev.frame = 0;

		/*if (pev(ent, pev_spawnflags) & SF_BUTTON_SPARK_IF_OFF) 
		{
			set_ent_data(ent, "CBaseEntity", "m_pfnThink", pev(ent, Pev_SavedThinkAdress));
			set_pev(ent, pev_nextthink, get_gametime() + 0.5);
		}*/

		/*if (pev(ent, pev_spawnflags) & SF_BUTTON_TOUCH_ONLY)
		{
			set_ent_data(ent, "CBaseEntity", "m_pfnTouch", pev(ent, Pev_SavedTouchAdress));
		}
		else
		{
			set_ent_data(ent, "CBaseEntity", "m_pfnTouch", 0);
			set_ent_data(ent, "CBaseEntity", "m_pfnUse", pev(ent, Pev_SavedUseAdress));        
		}*/

		bSomethingFound = true;

		if( g_bDebug )
			g_Game.AlertMessage( at_notice, "RESTORED %1 (%2) AT: %3\n", pButton.GetClassname(), pButton.pev.model, pButton.Center().ToString() );
	}

	return bSomethingFound;
}

bool RestoreRotButtons()
{
	bool bSomethingFound = false;
	CBaseEntity@ pEntity = null;
	while( (@pEntity = g_EntityFuncs.FindEntityByClassname(pEntity, "func_rot_button")) !is null )
	{
		CBaseButton@ pButton = cast<CBaseButton@>( pEntity );
		if( pButton is null ) continue;

		AxisDir( pButton );
		pButton.m_toggle_state = TS_AT_BOTTOM;

		RotButtonResetPos( pButton );

		pButton.pev.frame = 0;

		//ButtonBackHome makes the button return properly, but also sets think to ButtonSpark if "X Axis" spawnflag is set.
		bool bHasSparkSpawnflag = HasFlags( pButton.pev.spawnflags, SF_BUTTON_SPARK_IF_OFF );
		if( bHasSparkSpawnflag )
			pButton.pev.spawnflags &= ~SF_BUTTON_SPARK_IF_OFF;

		string sTempTarget = pButton.pev.target;
		pButton.pev.target = "";
		pButton.ButtonBackHome();
		pButton.pev.target = sTempTarget;

		if( bHasSparkSpawnflag )
			pButton.pev.spawnflags |= SF_BUTTON_SPARK_IF_OFF;

		bSomethingFound = true;

		if( g_bDebug )
			g_Game.AlertMessage( at_notice, "RESTORED %1 (%2) AT: %3\n", pButton.GetClassname(), pButton.pev.model, pButton.Center().ToString() );
	}

	return bSomethingFound;
}

void ButtonResetPos( CBaseButton@ pButton )
{
	pButton.pev.velocity = g_vecZero;
	g_EntityFuncs.SetOrigin( pButton, pButton.m_vecPosition1 );
}

void RotButtonResetPos( CBaseButton@ pButton )
{
	pButton.pev.avelocity = g_vecZero;

	if( HasFlags(pButton.pev.spawnflags, SF_DOOR_ROTATE_BACKWARDS) )
		pButton.pev.movedir = pButton.pev.movedir * -1;

	if( pButton.pev.speed == 0)
		pButton.pev.speed = 40.0; //100

	pButton.pev.angles = pButton.m_vecAngle1;
}

} //namespace maprestore END