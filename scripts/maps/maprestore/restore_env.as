namespace maprestore
{

const int SF_SPRITE_START_ON	= 1;
const string KVN_SPRITE_STARTED_ON = "$i_spritestarton";

void EnvMapActivate()
{
	maprestore::SetupEnvForRestoring();
}

void SetupEnvForRestoring()
{
	CBaseEntity@ pEntity = null;
	while( (@pEntity = g_EntityFuncs.FindEntityByClassname(pEntity, "env_sprite")) !is null )
	{
		if( HasFlags(pEntity.pev.spawnflags, SF_SPRITE_START_ON) )
			SetKV( pEntity, KVN_SPRITE_STARTED_ON, 1 );

		if( g_bDebug )
			g_Game.AlertMessage( at_notice, "%1 added at %2: %3\n", pEntity.GetClassname(), pEntity.pev.origin.ToString(), pEntity.pev.spawnflags );
	}
}

bool RestoreEnv()
{
	int iEnvReset = 0;

	CBaseEntity@ pEntity = null;
	while( (@pEntity = g_EntityFuncs.FindEntityByClassname(pEntity, "env_sprite")) !is null )
	{
		if( GetKVInt(pEntity, KVN_SPRITE_STARTED_ON) == 1 )
		{
			pEntity.Use( pEntity, pEntity, USE_ON, 0 );

			if( g_bDebug )
				g_Game.AlertMessage( at_notice, "TURNED ON SPRITE AT %1\n", pEntity.pev.origin.ToString() );
		}
		else
		{
			pEntity.Use( pEntity, pEntity, USE_OFF, 0 );

			if( g_bDebug )
				g_Game.AlertMessage( at_notice, "TURNED OFF SPRITE AT %1\n", pEntity.pev.origin.ToString() );
		}

		iEnvReset++;
	}

	return iEnvReset > 0;
}

} //namespace maprestore END