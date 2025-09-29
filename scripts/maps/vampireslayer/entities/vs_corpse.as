namespace vs_corpse
{

class vs_corpse : ScriptBaseAnimating
{
	private float m_flRemoveTime;

	void Spawn()
	{
		Precache();

		g_EntityFuncs.SetOrigin( self, pev.origin );

		pev.set_controller( 0, 150 );
		pev.set_controller( 1, 180 );
		pev.set_controller( 2, 90 );
		pev.set_controller( 3, 90 );

		pev.solid = SOLID_NOT;
		pev.movetype = MOVETYPE_NONE;
		pev.effects |= EF_NODRAW;

		SetUse( UseFunction(this.CorpseUse) );
		SetThink( ThinkFunction(this.CorpseThink) );
		pev.nextthink = g_Engine.time;
	}

	void Precache()
	{
		g_Game.PrecacheModel( "sprites/blood.spr" );
		g_Game.PrecacheModel( "sprites/bloodspray.spr" );
	}

	int ObjectCaps()
	{
		if( vs::HasFlags(pev.effects, EF_NODRAW) )
			return BaseClass.ObjectCaps();
		else
			return ( BaseClass.ObjectCaps() | FCAP_CONTINUOUS_USE );
	}

	void CorpseUse( CBaseEntity@ pActivator, CBaseEntity@ pCaller, USE_TYPE useType, float value )
	{
		CBasePlayer@ pPlayer = cast<CBasePlayer@>( pActivator );
		if( pPlayer is null or !pPlayer.IsConnected() or !pPlayer.IsAlive() )
			return;

		if( vs::GetPlayerTeam(pPlayer) != vs::TEAM_VAMPIRE )
			return;

		//make sure player drinks only from one corpse ??

		Vector vecOrigin = pev.origin;

		if( vs::GetNextDrinkSound(pPlayer) < g_Engine.time )
		{
			vecOrigin.z -= 28;
			te_display_falling_sprite( vecOrigin, "sprites/bloodspray.spr", "sprites/blood.spr", BLOOD_COLOR_RED );
			te_display_falling_sprite( vecOrigin, "sprites/bloodspray.spr", "sprites/blood.spr", BLOOD_COLOR_RED, 15 ); // bright red
			
			g_SoundSystem.EmitSound( pPlayer.edict(), CHAN_ITEM, vs::arrsSounds[vs::SND_VAMP_DRINKING], VOL_NORM, ATTN_NORM );
			vs::SetNextDrinkSound( pPlayer, g_Engine.time + 0.45 );
		}

		if( vs::GetNextDrinkHeal(pPlayer) < g_Engine.time )
		{
			pPlayer.TakeHealth( 0.5, DMG_GENERIC );
			vs::SetNextDrinkHeal( pPlayer, g_Engine.time + 0.1 );
		}
	}

	void CorpseThink()
	{
		//spawn instantly instead ??
		if( pev.owner is null )
		{
			pev.effects &= ~EF_NODRAW;
			return;
		}
		else
		{
			CBasePlayer@ pPlayer = cast<CBasePlayer@>( g_EntityFuncs.Instance(pev.owner) );
			if( pPlayer is null or !pPlayer.IsConnected() or vs::HasFlags(pPlayer.pev.effects, EF_NODRAW) )
			{
				pev.effects &= ~EF_NODRAW;
				return;
			}
		}

		pev.nextthink = g_Engine.time + 0.1;
	}

	void te_display_falling_sprite( Vector vecPos, string sSprite1, string sSprite2, int iColor = 78, int iScale = 10 ) //receiver = 0, bool:reliable = true
	{
		NetworkMessage m( MSG_ALL, NetworkMessages::SVC_TEMPENTITY );
			m.WriteByte( TE_BLOODSPRITE );
			m.WriteCoord( vecPos.x );
			m.WriteCoord( vecPos.y );
			m.WriteCoord( vecPos.z );
			m.WriteShort( g_EngineFuncs.ModelIndex(sSprite1) );
			m.WriteShort( g_EngineFuncs.ModelIndex(sSprite2) );
			m.WriteByte( iColor );
			m.WriteByte( iScale );
		m.End();
	}
}

void Register()
{
	g_CustomEntityFuncs.RegisterCustomEntity( "vs_corpse::vs_corpse", "vs_corpse" );
}

} //end of namespace vs_corpse