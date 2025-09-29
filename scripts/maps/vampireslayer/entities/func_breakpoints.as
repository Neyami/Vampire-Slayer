namespace vs_breakpoints
{

const int SF_ENVEXPLOSION_NODAMAGE	= 1;

const int SF_BREAK_TRIGGER_ONLY			= 1; // may only be broken by trigger
const int SF_BREAK_TOUCH						= 2; // can be 'crashed through' by running player (plate glass)
const int SF_BREAK_PRESSURE					= 4; // can be broken by a player standing on it
const int SF_BREAK_CROWBAR					= 256; // instant break if hit with crowbar
//8: "Repairable"
//32: "Show HUD Info"
//64: "Immune To Clients"
//512: "Explosives Only"
//displayname(string) : "HUD Info name"

const array<string> pSpawnObjects =
{
	"",									// 0
	"item_battery",					// 1
	"item_healthkit",				// 2
	"weapon_9mmhandgun",	// 3
	"ammo_9mmclip",				// 4
	"weapon_9mmAR",			// 5
	"ammo_9mmAR",				// 6
	"ammo_ARgrenades",			// 7
	"weapon_shotgun",			// 8
	"ammo_buckshot",				// 9
	"weapon_crossbow",			// 10
	"ammo_crossbow",			// 11
	"weapon_357",					// 12
	"ammo_357",					// 13
	"weapon_rpg",					// 14
	"ammo_rpgclip",				// 15
	"ammo_gaussclip",				// 16
	"weapon_handgrenade",		// 17
	"weapon_tripmine",			// 18
	"weapon_satchel",				// 19
	"weapon_snark",				// 20
	"weapon_hornetgun",			// 21
	"weapon_crowbar",			// 22
	"weapon_pipewrench",		// 23
	"weapon_sniperrifle",			// 24
	"ammo_762",					// 25
	"weapon_m16",					// 26
	"weapon_saw",					// 27
	"weapon_minigun",			// 28
	"ammo_556",					// 29
	"weapon_sporelauncher",	// 30
	"ammo_sporeclip",				// 31
	"ammo_9mmbox",				// 32
	"weapon_uzi",					// 33
	"weapon_uziakimbo",			// 34
	"weapon_eagle",				// 35
	"weapon_grapple",				// 36
	"weapon_medkit",				// 37
	"item_suit",						// 38
	"item_antidote"					// 39
};

const array<string> pSoundsWood =
{
	"debris/wood1.wav",
	"debris/wood2.wav",
	"debris/wood3.wav"
};

const array<string> pSoundsFlesh =
{
	"debris/flesh1.wav",
	"debris/flesh2.wav",
	"debris/flesh3.wav",
	"debris/flesh5.wav",
	"debris/flesh6.wav",
	"debris/flesh7.wav"
};

const array<string> pSoundsMetal =
{
	"debris/metal1.wav",
	"debris/metal2.wav",
	"debris/metal3.wav"
};

const array<string> pSoundsConcrete =
{
	"debris/concrete1.wav",
	"debris/concrete2.wav",
	"debris/concrete3.wav"
};

const array<string> pSoundsGlass =
{
	"debris/glass1.wav",
	"debris/glass2.wav",
	"debris/glass3.wav"
};

enum explosions_e { expRandom = 0, expDirected };

class func_breakpoints : ScriptBaseEntity
{
	Vector g_vecAttackDir; //actually make global ??

	float m_flDelay;

	//func_breakable
	int m_Material;
	int m_Explosion;
	float m_angle;
	string m_iszGibModel;
	string m_iszSpawnObject;
	// Explosion magnitude is stored in pev.impulse
	int m_idShard;

	float m_flSaveHealth; //for Restart
	int m_iPoints;
	int m_iTeam;

	bool KeyValue( const string& in szKey, const string& in szValue )
	{
		if( szKey == "explosion" )
		{
			if( szValue == "directed" )
				m_Explosion = expDirected;
			else
				m_Explosion = expRandom;

			return true;
		}
		else if( szKey == "material" )
		{
			int i = atoi( szValue );

			if( i < 0 or i >= matLastMaterial )
				m_Material = matWood;
			else
				m_Material = i;

			return true;
		}
		else if( szKey == "deadmodel" )
		{
			return true;
		}
		else if( szKey == "shards" )
		{
			return true;
		}
		else if( szKey == "gibmodel" )
		{
			m_iszGibModel = szValue;
			return true;
		}
		else if( szKey == "spawnobject" )
		{
			int object = atoi( szValue );

			if( object > 0 and object < int(pSpawnObjects.length()) )
				m_iszSpawnObject = pSpawnObjects[ object ];

			return true;
		}
		else if( szKey == "explodemagnitude" )
		{
			ExplosionSetMagnitude( atoi(szValue) );
			return true;
		}
		else if( szKey == "lip" )
			return true;
		else if( szKey == "vsteam" ) //"Team (0= Breakable by Slayers,1= Breakable by Vampires)"
		{
			m_iTeam = Math.clamp( 0, 1, atoi(szValue) );
			return true;
		}
		else if( szKey == "points" ) //"Points given to team when broken (0-100)" (Not frags, a team wins if their score reaches 100)
		{
			m_iPoints = atoi( szValue );
			return true;
		}
		else
			return BaseClass.KeyValue( szKey, szValue );
	}

	void Spawn()
	{
		Precache();

		if( vs::HasFlags(pev.spawnflags, SF_BREAK_TRIGGER_ONLY) )
			pev.takedamage = DAMAGE_NO;
		else
			pev.takedamage = DAMAGE_YES;

		m_flSaveHealth = pev.health;
		pev.solid = SOLID_BSP;
		pev.movetype = MOVETYPE_PUSH;
		m_angle = pev.angles.y;
		pev.angles.y = 0;

		if( m_Material == matGlass )
			pev.playerclass = 1;

		g_EntityFuncs.SetModel( self, string(pev.model) );
		SetTouch( TouchFunction(this.BreakTouch) );

		if( vs::HasFlags(pev.spawnflags, SF_BREAK_TRIGGER_ONLY) )
			SetTouch( null );

		if( !IsBreakable() and pev.rendermode != kRenderNormal )
			pev.flags |= FL_WORLDBRUSH;
	}

	const array<string> MaterialSoundList( int precacheMaterial, int &out soundCount )
	{
		array<string> pSoundList;

		switch( precacheMaterial )
		{
			case matWood:
			{
				pSoundList = pSoundsWood;
				soundCount = pSoundsWood.length();
				break;
			}

			case matFlesh:
			{
				pSoundList = pSoundsFlesh;
				soundCount = pSoundsFlesh.length();
				break;
			}

			case matComputer:
			case matUnbreakableGlass:
			case matGlass:
			{
				pSoundList = pSoundsGlass;
				soundCount = pSoundsGlass.length();
				break;
			}

			case matMetal:
			{
				pSoundList = pSoundsMetal;
				soundCount = pSoundsMetal.length();
				break;
			}

			case matCinderBlock:
			case matRocks:
			{
				pSoundList = pSoundsConcrete;
				soundCount = pSoundsConcrete.length();
				break;
			}

			case matCeilingTile:
			case matNone:
			default: soundCount = 0; break;
		}

		return pSoundList;
	}

	void MaterialSoundPrecache( int precacheMaterial )
	{
		int soundCount = 0;
		const array<string> pSoundList = MaterialSoundList( precacheMaterial, soundCount );

		for( int i = 0; i < soundCount; i++ )
			g_SoundSystem.PrecacheSound( string(pSoundList[i]) );
	}

	void Precache()
	{
		//const char *pGibName = NULL;
		string sGibName = "";

		switch( m_Material )
		{
			case matWood:
			{
				sGibName = "models/woodgibs.mdl";
				g_SoundSystem.PrecacheSound( "debris/bustcrate1.wav" );
				g_SoundSystem.PrecacheSound( "debris/bustcrate2.wav" );
				break;
			}

			case matFlesh:
			{
				sGibName = "models/fleshgibs.mdl";
				g_SoundSystem.PrecacheSound( "debris/bustflesh1.wav" );
				g_SoundSystem.PrecacheSound( "debris/bustflesh2.wav" );
				break;
			}

			case matComputer:
			{
				g_SoundSystem.PrecacheSound( "buttons/spark5.wav" );
				g_SoundSystem.PrecacheSound( "buttons/spark6.wav" );
				sGibName = "models/computergibs.mdl";
				g_SoundSystem.PrecacheSound( "debris/bustmetal1.wav" );
				g_SoundSystem.PrecacheSound( "debris/bustmetal2.wav" );
				break;
			}

			case matUnbreakableGlass:
			case matGlass:
			{
				sGibName = "models/glassgibs.mdl";
				g_SoundSystem.PrecacheSound( "debris/bustglass1.wav" );
				g_SoundSystem.PrecacheSound( "debris/bustglass2.wav" );
				break;
			}

			case matMetal:
			{
				sGibName = "models/metalplategibs.mdl";
				g_SoundSystem.PrecacheSound( "debris/bustmetal1.wav" );
				g_SoundSystem.PrecacheSound( "debris/bustmetal2.wav" );
				break;
			}

			case matCinderBlock:
			{
				sGibName = "models/cindergibs.mdl";
				g_SoundSystem.PrecacheSound( "debris/bustconcrete1.wav" );
				g_SoundSystem.PrecacheSound( "debris/bustconcrete2.wav" );
				break;
			}

			case matRocks:
			{
				sGibName = "models/rockgibs.mdl";
				g_SoundSystem.PrecacheSound( "debris/bustconcrete1.wav" );
				g_SoundSystem.PrecacheSound( "debris/bustconcrete2.wav" );
				break;
			}

			case matCeilingTile:
			{
				sGibName = "models/ceilinggibs.mdl";
				g_SoundSystem.PrecacheSound( "debris/bustceiling.wav" );
				break;
			}
		}

		MaterialSoundPrecache( m_Material );

		if( !m_iszGibModel.IsEmpty() )
			sGibName = string( m_iszGibModel );

		m_idShard = g_Game.PrecacheModel( sGibName );

		if( !m_iszSpawnObject.IsEmpty() )
			g_Game.PrecacheOther( string(m_iszSpawnObject) );
	}

	void Restart()
	{
		pev.solid = SOLID_BSP;
		pev.movetype = MOVETYPE_PUSH;
		pev.deadflag = DEAD_NO;

		if( vs::HasFlags(pev.spawnflags, SF_BREAK_TRIGGER_ONLY) )
			pev.takedamage = DAMAGE_NO;
		else
			pev.takedamage = DAMAGE_YES;

		pev.deadflag = DEAD_NO;
		pev.health = m_flSaveHealth;
		pev.effects &= ~EF_NODRAW;
		m_angle = pev.angles.y;
		pev.angles.y = 0;

		g_EntityFuncs.SetModel( self, string(pev.model) );
		SetTouch( TouchFunction(this.BreakTouch) );

		if( vs::HasFlags(pev.spawnflags, SF_BREAK_TRIGGER_ONLY) )
			SetTouch( null );

		if( !IsBreakable() and pev.rendermode != kRenderNormal )
			pev.flags |= FL_WORLDBRUSH;
	}

	void DamageSound()
	{
		array<string> rgpsz(6);
		int i = 0;
		int material = m_Material;

		int pitch = ( Math.RandomLong(0, 2) != 0 ) ? PITCH_NORM : ( 95 + Math.RandomLong(0, 34) );
		float fvol = Math.RandomFloat( 0.75, 1 );

		if( material == matComputer and Math.RandomLong(0, 1) != 0 )
			material = matMetal;

		switch( material )
		{
			case matComputer:
			case matGlass:
			case matUnbreakableGlass:
			{
				rgpsz[0] = "debris/glass1.wav";
				rgpsz[1] = "debris/glass2.wav";
				rgpsz[2] = "debris/glass3.wav";
				i = 3;
				break;
			}

			case matWood:
			{
				rgpsz[0] = "debris/wood1.wav";
				rgpsz[1] = "debris/wood2.wav";
				rgpsz[2] = "debris/wood3.wav";
				i = 3;
				break;
			}

			case matMetal:
			{
				rgpsz[0] = "debris/metal1.wav";
				rgpsz[1] = "debris/metal3.wav";
				rgpsz[2] = "debris/metal2.wav";
				i = 2;
				break;
			}

			case matFlesh:
			{
				rgpsz[0] = "debris/flesh1.wav";
				rgpsz[1] = "debris/flesh2.wav";
				rgpsz[2] = "debris/flesh3.wav";
				rgpsz[3] = "debris/flesh5.wav";
				rgpsz[4] = "debris/flesh6.wav";
				rgpsz[5] = "debris/flesh7.wav";
				i = 6;
				break;
			}

			case matRocks:
			case matCinderBlock:
			{
				rgpsz[0] = "debris/concrete1.wav";
				rgpsz[1] = "debris/concrete2.wav";
				rgpsz[2] = "debris/concrete3.wav";
				i = 3;
				break;
			}

			case matCeilingTile:
			{
				i = 0;
				break;
			}
		}

		if( i > 0 )
			g_SoundSystem.EmitSoundDyn( self.edict(), CHAN_VOICE, rgpsz[Math.RandomLong(0, i - 1)], fvol, ATTN_NORM, 0, pitch );
	}

	void BreakTouch( CBaseEntity@ pOther )
	{
		entvars_t@ pevToucher = pOther.pev;

/*HL original
		// only players can break these right now
		if ( !pOther.IsPlayer() or !IsBreakable() )
			return;
*/
		//CS
		if( !pOther.IsPlayer() or !IsBreakable() )
		{
			if( pev.rendermode == kRenderNormal or !pOther.pev.ClassNameIs("grenade") )
				return;

			pev.angles.y = m_angle;
			Math.MakeVectors( pev.angles );
			g_vecAttackDir = g_Engine.v_forward;
			pev.takedamage = DAMAGE_NO;
			pev.deadflag = DEAD_DEAD;
			pev.effects = EF_NODRAW;
			Die();
		}

		if( vs::HasFlags(pev.spawnflags, SF_BREAK_TOUCH) )
		{
			float flDamage = pevToucher.velocity.Length() * 0.01;

			if( flDamage >= pev.health )
			{
				SetTouch( null );
				TakeDamage( pevToucher, pevToucher, flDamage, DMG_CRUSH );

				// do a little damage to player if we broke glass or computer
				pOther.TakeDamage( self.pev, self.pev, flDamage/4, DMG_SLASH );
			}
		}

		if( vs::HasFlags(pev.spawnflags, SF_BREAK_PRESSURE) and pevToucher.absmin.z >= pev.maxs.z - 2 )
		{
			DamageSound();

			SetThink( ThinkFunction(this.Die) );
			SetTouch( null );

			if( m_flDelay == 0 )
				m_flDelay = 0.1;

			pev.nextthink = pev.ltime + m_flDelay;
		}
	}

	void Use( CBaseEntity@ pActivator, CBaseEntity@ pCaller, USE_TYPE useType, float value )
	{
		if( IsBreakable() )
		{
			pev.angles.y = m_angle;
			Math.MakeVectors( pev.angles );
			g_vecAttackDir = g_Engine.v_forward;
			pev.takedamage = DAMAGE_NO;
			pev.deadflag = DEAD_DEAD;
			pev.effects = EF_NODRAW;
			Die();
		}
	}

	int TakeDamage( entvars_t@ pevInflictor, entvars_t@ pevAttacker, float flDamage, int bitsDamageType )
	{
		Vector vecTemp;

		if( pevAttacker is pevInflictor )
		{
			vecTemp = pevInflictor.origin - (pev.absmin + (pev.size * 0.5));

			if( vs::HasFlags(pevAttacker.flags, FL_CLIENT) and vs::HasFlags(pev.spawnflags, SF_BREAK_CROWBAR) and vs::HasFlags(bitsDamageType, DMG_CLUB) )
				flDamage = pev.health;
		}
		else
			vecTemp = pevInflictor.origin - (pev.absmin + (pev.size * 0.5));

		if( !IsBreakable() )
			return 0;

		//WHY IS pevAttacker NULL ?!
		if( pevAttacker !is null and vs::HasFlags(pevAttacker.flags, FL_CLIENT) )
		{
			CBasePlayer@ pPlayer = cast<CBasePlayer@>( g_EntityFuncs.Instance(pevAttacker) );
			if( pPlayer !is null and !CanDamageThis(pPlayer, bitsDamageType) )
			{
				flDamage = 0;
				return 1; //so smoke puffs and decals are still drawn (doesn't work :aRage:)
			}
		}

		if( vs::HasFlags(bitsDamageType, DMG_CLUB) )
			flDamage *= 2;

		if( vs::HasFlags(bitsDamageType, DMG_POISON) )
			flDamage *= 0.1;

		g_vecAttackDir = vecTemp.Normalize();
		pev.health -= flDamage;

		if( pev.health <= 0 )
		{
			pev.takedamage = DAMAGE_NO;
			pev.deadflag = DEAD_DEAD;
			pev.effects = EF_NODRAW;
			Die();

			if( m_flDelay == 0 )
				m_flDelay = 0.1;

			pev.nextthink = pev.ltime + m_flDelay;
			return 0;
		}

		DamageSound();

		return 1;
	}

	void TraceAttack( entvars_t@ pevAttacker, float flDamage, const Vector& in vecDir, TraceResult& in ptr, int bitsDamageType )
	{
		//only take damage from a Slayer's stake and Vampire's claws
		if( !vs::HasFlags(bitsDamageType, DMG_SLASH) )
			flDamage = 0.0;

		//WHY IS pevAttacker NULL ?!
		if( pevAttacker !is null and vs::HasFlags(pevAttacker.flags, FL_CLIENT) )
		{
			CBasePlayer@ pPlayer = cast<CBasePlayer@>( g_EntityFuncs.Instance(pevAttacker) );
			if( pPlayer !is null and CanDamageThis(pPlayer, bitsDamageType) )
				g_Utility.Ricochet( ptr.vecEndPos, 1.0 );
		}

		if( Math.RandomLong(0, 1) != 0 )
		{
			switch( m_Material )
			{
				case matComputer:
				{
					g_Utility.Sparks( ptr.vecEndPos );
					float flVolume = Math.RandomFloat( 0.7, 1 );

					switch( Math.RandomLong(0, 1) )
					{
						case 0: g_SoundSystem.EmitSound( self.edict(), CHAN_VOICE, "buttons/spark5.wav", flVolume, ATTN_NORM );
						case 1: g_SoundSystem.EmitSound( self.edict(), CHAN_VOICE, "buttons/spark6.wav", flVolume, ATTN_NORM );
					}

					break;
				}

				case matUnbreakableGlass:
				{
					g_Utility.Ricochet( ptr.vecEndPos, Math.RandomFloat(0.5, 1.5) );
					break;
				}
			}
		}

		BaseClass.TraceAttack( pevAttacker, flDamage, vecDir, ptr, bitsDamageType );
	}

	bool CanDamageThis( CBasePlayer@ pPlayer, int bitsDamageType )
	{
		if( m_iTeam == 0 )
		{
			if( vs::GetPlayerTeam(pPlayer) != vs::TEAM_SLAYER or !vs::HasFlags(bitsDamageType, DMG_SLASH) )
				return false;
		}

		if( m_iTeam == 1 and vs::GetPlayerTeam(pPlayer) != vs::TEAM_VAMPIRE )
			return false;

		return true;
	}

	void Die()
	{
		int cFlag = 0;
		int pitch = 95 + Math.RandomLong( 0, 29 );

		if( pitch > 97 and pitch < 103 )
			pitch = 100;

		float fvol = Math.RandomFloat(0.85, 1.0) + (abs(int(pev.health)) / 100.0);

		if( fvol > 1 )
			fvol = 1;

		switch( m_Material )
		{
			case matGlass:
			{
				switch( Math.RandomLong(0, 1) )
				{
					case 0: g_SoundSystem.EmitSoundDyn( self.edict(), CHAN_VOICE, "debris/bustglass1.wav", fvol, ATTN_NORM, 0, pitch ); break;
					case 1: g_SoundSystem.EmitSoundDyn( self.edict(), CHAN_VOICE, "debris/bustglass2.wav", fvol, ATTN_NORM, 0, pitch ); break;
				}

				cFlag = BREAK_GLASS;
				break;
			}

			case matWood:
			{
				switch( Math.RandomLong(0, 1) )
				{
					case 0: g_SoundSystem.EmitSoundDyn( self.edict(), CHAN_VOICE, "debris/bustcrate1.wav", fvol, ATTN_NORM, 0, pitch ); break;
					case 1: g_SoundSystem.EmitSoundDyn( self.edict(), CHAN_VOICE, "debris/bustcrate2.wav", fvol, ATTN_NORM, 0, pitch ); break;
				}

				cFlag = BREAK_WOOD;
				break;
			}

			case matComputer:
			case matMetal:
			{
				switch( Math.RandomLong(0, 1) )
				{
					case 0: g_SoundSystem.EmitSoundDyn( self.edict(), CHAN_VOICE, "debris/bustmetal1.wav", fvol, ATTN_NORM, 0, pitch ); break;
					case 1: g_SoundSystem.EmitSoundDyn( self.edict(), CHAN_VOICE, "debris/bustmetal2.wav", fvol, ATTN_NORM, 0, pitch ); break;
				}

				cFlag = BREAK_METAL;
				break;
			}

			case matFlesh:
			{
				switch( Math.RandomLong(0, 1) )
				{
					case 0: g_SoundSystem.EmitSoundDyn( self.edict(), CHAN_VOICE, "debris/bustflesh1.wav", fvol, ATTN_NORM, 0, pitch ); break;
					case 1: g_SoundSystem.EmitSoundDyn( self.edict(), CHAN_VOICE, "debris/bustflesh1´2.wav", fvol, ATTN_NORM, 0, pitch ); break;
				}

				cFlag = BREAK_FLESH;
				break;
			}

			case matRocks:
			case matCinderBlock:
			{
				switch( Math.RandomLong(0, 1) )
				{
					case 0: g_SoundSystem.EmitSoundDyn( self.edict(), CHAN_VOICE, "debris/bustconcrete1.wav", fvol, ATTN_NORM, 0, pitch ); break;
					case 1: g_SoundSystem.EmitSoundDyn( self.edict(), CHAN_VOICE, "debris/bustconcrete2.wav", fvol, ATTN_NORM, 0, pitch ); break;
				}

				cFlag = BREAK_CONCRETE;
				break;
			}

			case matCeilingTile: g_SoundSystem.EmitSoundDyn( self.edict(), CHAN_VOICE, "debris/bustceiling.wav", fvol, ATTN_NORM, 0, pitch ); break;
		}

		Vector vecSpot, vecVelocity;

		if( m_Explosion == expDirected )
			vecVelocity = g_vecAttackDir * 200;
		else
		{
			vecVelocity.x = 0;
			vecVelocity.y = 0;
			vecVelocity.z = 0;
		}

		vecSpot = pev.origin + (pev.mins + pev.maxs) * 0.5;

		NetworkMessage m1( MSG_PVS, NetworkMessages::SVC_TEMPENTITY, vecSpot );
			m1.WriteByte( TE_BREAKMODEL );
			m1.WriteCoord( vecSpot.x ); // position
			m1.WriteCoord( vecSpot.y );
			m1.WriteCoord( vecSpot.z );
			m1.WriteCoord( pev.size.x ); // size
			m1.WriteCoord( pev.size.y );
			m1.WriteCoord( pev.size.z );
			m1.WriteCoord( vecVelocity.x ); // velocity
			m1.WriteCoord( vecVelocity.y );
			m1.WriteCoord( vecVelocity.z );
			m1.WriteByte( 10 ); // randomization
			m1.WriteShort( m_idShard ); //model id#
			m1.WriteByte( 0 ); // # of shards. let client decide
			m1.WriteByte( 25 ); // duration 3.0 seconds
			m1.WriteByte( cFlag ); // flags
		m1.End();

		float size = pev.size.x;

		if( size < pev.size.y )
			size = pev.size.y;

		if( size < pev.size.z )
			size = pev.size.z;

		Vector mins = pev.absmin;
		Vector maxs = pev.absmax;
		mins.z = pev.absmax.z;
		maxs.z += 8;

		/*not needed because SOLID_NOT is set ??
		array<CBaseEntity@> pList(256);
		int count = g_EntityFuncs.EntitiesInBox( pList, mins, maxs, FL_ONGROUND );

		if( count > 0 )
		{
			for( int i = 0; i < count; i++ )
			{
				pList[i].pev.flags &= ~FL_ONGROUND;
				@pList[i].pev.groundentity = null;
				//g_Game.AlertMessage( at_notice, "%1 NO LONGER STANDING ON BREAKABLE!\n", pList[i].GetClassname() );
			}
		}*/

		pev.solid = SOLID_NOT;
		self.SUB_UseTargets( null, USE_TOGGLE, 0 );
		SetThink( null );
		pev.nextthink = pev.ltime + 0.1;

		if( !m_iszSpawnObject.IsEmpty() )
			g_EntityFuncs.Create( m_iszSpawnObject, VecBModelOrigin(self.pev), pev.angles, false, self.edict() );

		if( Explodable() )
			ExplosionCreate( self.Center(), pev.angles, self.edict(), ExplosionMagnitude(), true );

		if( m_iPoints > 0 and vs::g_iBreakPointsVampire < vs::BREAKPOINTS_TO_WIN and vs::g_iBreakPointsSlayer < vs::BREAKPOINTS_TO_WIN )
		{
			if( m_iTeam == 1 ) //vampire
			{
				vs::g_iBreakPointsVampire += m_iPoints;
				g_SoundSystem.EmitSound( self.edict(), CHAN_BODY, vs::arrsSounds[vs::SND_VAMPIRE_BREAK], VOL_NORM, ATTN_NORM );

				if( vs::g_iBreakPointsVampire >= vs::BREAKPOINTS_TO_WIN )
				{
					HUDMessageVampire( true );
					vs::g_iRoundWinner = vs::TEAM_VAMPIRE;
					vs::RoundEnd();
				}
				else
					HUDMessageVampire();
			}
			else
			{
				vs::g_iBreakPointsSlayer += m_iPoints;
				g_SoundSystem.EmitSound( self.edict(), CHAN_BODY, vs::arrsSounds[vs::SND_SLAYER_BREAK], VOL_NORM, ATTN_NORM );

				if( vs::g_iBreakPointsSlayer >= vs::BREAKPOINTS_TO_WIN )
				{
					HUDMessageSlayer( true );
					vs::g_iRoundWinner = vs::TEAM_SLAYER;
					vs::RoundEnd();
				}
				else
					HUDMessageSlayer();
			}
		}
	}

	bool IsBreakable() 
	{
		return m_Material != matUnbreakableGlass;
	}

	int DamageDecal( int bitsDamageType )
	{
		if( m_Material == matGlass )
			return DECAL_GLASSBREAK1 + Math.RandomLong( 0, 2 );

		if( m_Material == matUnbreakableGlass )
			return DECAL_BPROOF1;

		return self.DamageDecal( bitsDamageType );
	}

	void ExplosionCreate( const Vector &in center, const Vector &in angles, edict_t@ pOwner, int magnitude, bool doDamage )
	{
		CBaseEntity@ pExplosion = g_EntityFuncs.Create( "env_explosion", center, angles, true, pOwner );

		pExplosion.KeyValue( "iMagnitude", string(magnitude) );
		if( !doDamage )
			pExplosion.pev.spawnflags |= SF_ENVEXPLOSION_NODAMAGE;

		g_EntityFuncs.DispatchSpawn( pExplosion.edict() );
		pExplosion.Use( null, null, USE_TOGGLE, 0 );
	}

	bool Explodable() { return ExplosionMagnitude() > 0; }
	int ExplosionMagnitude() { return pev.impulse; }
	void ExplosionSetMagnitude( int magnitude ) { pev.impulse = magnitude; }

	Vector VecBModelOrigin( entvars_t@ pevBModel )
	{
		return pevBModel.absmin + ( pevBModel.size * 0.5 );
	}

	void HUDMessageVampire( bool bWin = false )
	{
		for( int i = 1; i <= g_Engine.maxClients; i++ )
		{
			CBasePlayer@ pPlayer = g_PlayerFuncs.FindPlayerByIndex( i );

			if( pPlayer is null or !pPlayer.IsConnected() )
				continue;

			RGBA color = RGBA_RED;
			if( bWin )
				color = RGBA_BROWN;

			vs::HUDMessage( pPlayer, lang::getLocalizedText(pPlayer, "RELICBREAK_VAMPIRE") + " (" + Math.clamp(0, vs::BREAKPOINTS_TO_WIN, vs::g_iBreakPointsVampire) + "%)", vs::HUD_CHAN_BREAKPOINTS, -0.8, -0.8, color, 0.0, 0.5, 3.0 );
		}
	}

	void HUDMessageSlayer( bool bWin = false )
	{
		for( int i = 1; i <= g_Engine.maxClients; i++ )
		{
			CBasePlayer@ pPlayer = g_PlayerFuncs.FindPlayerByIndex( i );

			if( pPlayer is null or !pPlayer.IsConnected() )
				continue;

			RGBA color = RGBA_YELLOW;
			if( bWin )
				color = RGBA_GREEN;

			vs::HUDMessage( pPlayer, lang::getLocalizedText(pPlayer, "RELICBREAK_SLAYER") + " (" + Math.clamp(0, vs::BREAKPOINTS_TO_WIN, vs::g_iBreakPointsSlayer) + "%)", vs::HUD_CHAN_BREAKPOINTS, -0.8, -0.8, color, 0.0, 0.5, 3.0 );
		}
	}
}

void Register()
{
	g_CustomEntityFuncs.RegisterCustomEntity( "vs_breakpoints::func_breakpoints", "func_breakpoints" );
}

} //end of namespace vs_breakpoints