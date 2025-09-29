namespace vs_head
{

const array<string> arrsSoundsFlesh = 
{
	"debris/flesh1.wav",
	"debris/flesh2.wav",
	"debris/flesh3.wav",
	"debris/flesh5.wav",
	"debris/flesh6.wav",
	"debris/flesh7.wav"
};

class vs_head : ScriptBaseEntity
{
	private float m_flRemoveTime;
	int m_iBloodDecals;

	void Spawn()
	{
		Precache();

		g_EntityFuncs.SetOrigin( self, pev.origin );

		pev.solid = SOLID_BBOX;
		pev.movetype = MOVETYPE_BOUNCE;

		SetTouch( TouchFunction(this.HeadTouch) );
		SetThink( ThinkFunction(this.HeadThink) );
		pev.nextthink = g_Engine.time;
	}

	void Precache()
	{
		for( uint i = 0; i < arrsSoundsFlesh.length(); ++i )
			g_SoundSystem.PrecacheSound( arrsSoundsFlesh[i] );
	}

	void HeadTouch( CBaseEntity@ pOther )
	{
		//if( vs::HasFlags(pev.flags, FL_ONGROUND) )
		{
			if( pev.velocity.Length() < 120.0 )
				pev.velocity = g_vecZero;
			else
				pev.velocity = pev.velocity * 0.42;

			//g_Game.AlertMessage( at_notice, "vs_head velocity Length: %1\n", pev.velocity.Length() );

			pev.avelocity.x = 0;
			pev.avelocity.z = 0;
		}
		//else
		if( !vs::HasFlags(pev.flags, FL_ONGROUND) )
		{
			if( m_iBloodDecals > 0 )
			{
				TraceResult tr;
				Vector vecOrigin = pev.origin - pev.velocity.Normalize() * 32;

				g_Utility.TraceLine( vecOrigin, vecOrigin + pev.velocity.Normalize() * 64, ignore_monsters, self.edict(), tr );
				g_Utility.BloodDecalTrace( tr, BLOOD_COLOR_RED );

				m_iBloodDecals--;
			}

			if( Math.RandomLong(0, 2) == 0 )
			{
				float volume;
				float zvel = abs( pev.velocity.z ); //fabs

				volume = 0.8 * Math.min( 1.0, zvel / 450.0 );

				//get Postal 2 sound effects!
				g_SoundSystem.EmitSound( self.edict(), CHAN_BODY, arrsSoundsFlesh[Math.RandomLong(0, arrsSoundsFlesh.length()-1)], volume, ATTN_NORM );
			}
		}
	}

	void HeadThink()
	{
		if( m_flRemoveTime == 0 and (pev.velocity == g_vecZero/* or vs::HasFlags(pev.flags, FL_ONGROUND)*/) )
			m_flRemoveTime = g_Engine.time + 5.0;

		if( m_flRemoveTime > 0 and m_flRemoveTime <= g_Engine.time )
		{
			g_EntityFuncs.Remove( self );
			return;
		}

		Vector vecBonePos, vecAttachment;
		g_EngineFuncs.GetBonePosition( self.edict(), 9, vecBonePos, void );
		g_EngineFuncs.GetAttachment( self.edict(), 0, vecAttachment, void );
		Vector vecBleed = (vecAttachment - vecBonePos).Normalize();

		g_Utility.BloodStream( self.Center(), vecBleed, 72, 75 ); //using BLOOD_COLOR_RED doesn't work

		pev.nextthink = g_Engine.time + 0.1;
	}
}

void Register()
{
	g_CustomEntityFuncs.RegisterCustomEntity( "vs_head::vs_head", "vs_head" );
}

} //end of namespace vs_head