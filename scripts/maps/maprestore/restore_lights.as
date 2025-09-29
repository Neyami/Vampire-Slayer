namespace maprestore
{

const int SF_LIGHT_START_OFF	= 1;
const string KVN_LIGHT_STARTED_OFF = "$i_lightstartoff";

void LightsMapActivate()
{
	maprestore::SetupLightsForRestoring();
}

void SetupLightsForRestoring()
{
	CBaseEntity@ pEntity = null;
	while( (@pEntity = g_EntityFuncs.FindEntityByClassname(pEntity, "light")) !is null )
	{
		if( HasFlags(pEntity.pev.spawnflags, SF_LIGHT_START_OFF) )
			SetKV( pEntity, KVN_LIGHT_STARTED_OFF, 1 );

		if( g_bDebug )
			g_Game.AlertMessage( at_notice, "%1 added at %2: %3\n", pEntity.GetClassname(), pEntity.pev.origin.ToString(), pEntity.pev.spawnflags );
	}
}

bool RestoreLights()
{
	int iLightsReset = 0;

	CBaseEntity@ pEntity = null;
	while( (@pEntity = g_EntityFuncs.FindEntityByClassname(pEntity, "light")) !is null )
	{
		if( GetKVInt(pEntity, KVN_LIGHT_STARTED_OFF) == 1 )
		{
			pEntity.Use( pEntity, pEntity, USE_OFF, 0 );

			if( g_bDebug )
				g_Game.AlertMessage( at_notice, "TURNED OFF LIGHT AT %1\n", pEntity.pev.origin.ToString() );
		}
		else
		{
			pEntity.Use( pEntity, pEntity, USE_ON, 0 );

			if( g_bDebug )
				g_Game.AlertMessage( at_notice, "TURNED ON LIGHT AT %1\n", pEntity.pev.origin.ToString() );
		}

		iLightsReset++;
	}

	return iLightsReset > 0;
}

} //namespace maprestore END