//based on HL crowbar and glock
namespace vs_colt
{

const int VSW_DEFAULT_GIVE			= 7;
const int VSW_MAX_CLIP 				= 7;
const int VSW_MAX_AMMO				= 42;

const int VSW_DAMAGE_STAKE		= 30;
const int VSW_DAMAGE_GUN			= 15;
const float VSW_TIME_DELAY1		= 0.5;
const float VSW_TIME_DELAY2		= 0.5;
const float VSW_TIME_DRAW			= 1.0;
const float VSW_TIME_IDLE1			= 4.0;
const float VSW_TIME_IDLE2			= 3.0;
const float VSW_TIME_IDLE3			= 3.0;
const float VSW_TIME_IDLE4			= 3.0;
const float VSW_TIME_IDLE5			= 3.0;
const float VSW_TIME_IDLE6			= 1.04;
const float VSW_TIME_RELOAD		= 1.3;

const string VSW_ANIMEXT1			= "crowbar";
const string VSW_ANIMEXT2			= "onehanded";
const string MODEL_VIEW				= "models/vs/weapons/v_colt.mdl";
const string MODEL_PLAYER			= "models/vs/weapons/p_colt.mdl";
const string MODEL_WORLD			= "models/vs/weapons/w_weaponbox.mdl";

enum anim_e
{
	ANIM_DRAW = 0,
	ANIM_SHOOT,
	ANIM_RELOAD,
	ANIM_ATTACK1HIT,
	ANIM_ATTACK1MISS,
	ANIM_ATTACK2HIT,
	ANIM_ATTACK2MISS,
	ANIM_ATTACK3HIT,
	ANIM_ATTACK3MISS,
	ANIM_IDLE1,
	ANIM_IDLE2,
	ANIM_IDLE3,
	ANIM_IDLE4,
	ANIM_IDLE5,
	ANIM_IDLE6
};

enum sounds_e
{
	SND_HIT1 = 0,
	SND_HIT2,
	SND_HITBOD1,
	SND_HITBOD2,
	SND_HITBOD3,
	SND_MISS,
	SND_SHOOT
};

const array<string> arrsSounds =
{
	"vs/weapons/cbar_hit1.wav",
	"vs/weapons/cbar_hit2.wav",
	"weapons/cbar_hitbod1.wav",
	"weapons/cbar_hitbod2.wav",
	"weapons/cbar_hitbod3.wav",
	"weapons/cbar_miss1.wav",
	"vs/weapons/pl_gun3.wav"
};

class weapon_vscolt : CBaseVSWeapon
{
	private int m_iSwing;
	private int m_iShell;
	private TraceResult m_trHit;

	void Spawn()
	{
		Precache();
		g_EntityFuncs.SetModel( self, MODEL_WORLD );

		self.m_iDefaultAmmo = VSW_DEFAULT_GIVE;
		self.m_flCustomDmg = pev.dmg;

		self.FallInit();
	}

	void Precache()
	{
		self.PrecacheCustomModels();

		g_Game.PrecacheModel( MODEL_VIEW );
		g_Game.PrecacheModel( MODEL_WORLD );
		g_Game.PrecacheModel( MODEL_PLAYER );

		m_iShell = g_Game.PrecacheModel( "models/shell.mdl" );

		for( uint i = 0; i < arrsSounds.length(); ++i )
			g_SoundSystem.PrecacheSound( arrsSounds[i] );

		//Precache these for downloading
		for( uint i = 0; i < arrsSounds.length(); ++i )
			g_Game.PrecacheGeneric( "sound/" + arrsSounds[i] );

		g_Game.PrecacheGeneric( "sprites/vs/weapon_vscolt.txt" );
		g_Game.PrecacheGeneric( "sprites/vs/640hud1.spr" );
		g_Game.PrecacheGeneric( "sprites/vs/640hud4.spr" );
		g_Game.PrecacheGeneric( "sprites/vs/640hud7.spr" );
	}

	bool GetItemInfo( ItemInfo& out info )
	{
		info.iMaxAmmo1	= VSW_MAX_AMMO;
		info.iMaxAmmo2	= -1;
		info.iMaxClip			= VSW_MAX_CLIP;
		info.iSlot				= vs::COLT_SLOT-1;
		info.iPosition			= vs::COLT_POSITION-1;
		info.iWeight			= vs::COLT_WEIGHT;
		info.iFlags				= ITEM_FLAG_SELECTONEMPTY | ITEM_FLAG_NOAUTOSWITCHEMPTY;

		return true;
	}

	bool AddToPlayer( CBasePlayer@ pPlayer )
	{
		//not needed with mp_dropweapons 0
		if( vs::GetPlayerTeam(pPlayer) != vs::TEAM_SLAYER or vs::GetPlayerClass(pPlayer) != vs::CLASS_HUMAN_MOLLY )
			return false;

		if( !BaseClass.AddToPlayer(pPlayer) )
			return false;

		@m_pPlayer = pPlayer;

		NetworkMessage m( MSG_ONE, NetworkMessages::WeapPickup, pPlayer.edict() );
			m.WriteLong( g_ItemRegistry.GetIdForName("weapon_vscolt") );
		m.End();

		return true;
	}

	bool Deploy()
	{
		bool bResult;
		{
			bResult = self.DefaultDeploy( self.GetV_Model(MODEL_VIEW), self.GetP_Model(MODEL_PLAYER), ANIM_DRAW, VSW_ANIMEXT1 );
			self.m_flTimeWeaponIdle = self.m_flNextPrimaryAttack = self.m_flNextSecondaryAttack = g_Engine.time + VSW_TIME_DRAW;

			return bResult;
		}
	}

	void Holster( int skiplocal )
	{
		SetThink( null );

		BaseClass.Holster( skiplocal );
	}

	void PrimaryAttack()
	{
		m_pPlayer.m_szAnimExtension = VSW_ANIMEXT1;

		TraceResult tr;

		Math.MakeVectors( m_pPlayer.pev.v_angle );
		Vector vecSrc	= m_pPlayer.GetGunPosition();
		Vector vecEnd	= vecSrc + g_Engine.v_forward * 32;

		g_Utility.TraceLine( vecSrc, vecEnd, dont_ignore_monsters, m_pPlayer.edict(), tr );

		if( tr.flFraction >= 1.0 )
		{
			g_Utility.TraceHull( vecSrc, vecEnd, dont_ignore_monsters, head_hull, m_pPlayer.edict(), tr );

			if( tr.flFraction < 1.0 )
			{
				CBaseEntity@ pHit = g_EntityFuncs.Instance( tr.pHit );

				if( pHit is null or pHit.IsBSPModel() )
					g_Utility.FindHullIntersection( vecSrc, tr, tr, VEC_DUCK_HULL_MIN, VEC_DUCK_HULL_MAX, m_pPlayer.edict() );

				vecEnd = tr.vecEndPos;
			}
		}

		if( tr.flFraction >= 1.0 )
		{
			switch( (m_iSwing++) % 3 )
			{
				case 0: self.SendWeaponAnim( ANIM_ATTACK1MISS ); break;
				case 1: self.SendWeaponAnim( ANIM_ATTACK2MISS ); break;
				case 2: self.SendWeaponAnim( ANIM_ATTACK3MISS ); break;
			}

			self.m_flNextPrimaryAttack = g_Engine.time + VSW_TIME_DELAY1;
			self.m_flTimeWeaponIdle = g_Engine.time + ( 0.5 + Math.RandomFloat(0.5, (0.5*4)) );

			g_SoundSystem.EmitSoundDyn( m_pPlayer.edict(), CHAN_WEAPON, arrsSounds[SND_MISS], 1, ATTN_NORM, 0, 94 + Math.RandomLong( 0,0xF ) );

			m_pPlayer.SetAnimation( PLAYER_ATTACK1 );
		}
		else
		{
			switch( ((m_iSwing++) % 2) + 1 )
			{
				case 0: self.SendWeaponAnim( ANIM_ATTACK1HIT ); break;
				case 1: self.SendWeaponAnim( ANIM_ATTACK2HIT ); break;
				case 2: self.SendWeaponAnim( ANIM_ATTACK3HIT ); break;
			}

			m_pPlayer.SetAnimation( PLAYER_ATTACK1 );

			CBaseEntity@ pEntity = g_EntityFuncs.Instance( tr.pHit );

			g_WeaponFuncs.ClearMultiDamage();

			float flDamage = VSW_DAMAGE_STAKE;
			if( self.m_flCustomDmg > 0 ) flDamage = self.m_flCustomDmg;

			vecSrc = pEntity.Center();
			vecEnd = m_pPlayer.Center();

			vecEnd = vecEnd - vecSrc;
			vecEnd = vecEnd.Normalize();

			Vector vecAngle = pEntity.pev.angles;
			Math.MakeVectors( vecAngle );

			Vector vecForward = g_Engine.v_forward;
			vecEnd = vecEnd * -1.0;

			int iHitgroup = tr.iHitgroup;

			//vampires take more damage when stabbed in the chest
			if( iHitgroup == HITGROUP_CHEST )
				flDamage *= 2.0;

			if( pEntity.IsPlayer() )
			{
				CBasePlayer@ pTarget = cast<CBasePlayer@>( pEntity );
				pTarget.m_LastHitGroup = iHitgroup;
			}

			if( pEntity.BloodColor() != DONT_BLEED )
			{
				vecAngle = m_pPlayer.pev.v_angle;
				Math.MakeVectors( vecAngle );

				vecForward = g_Engine.v_forward;
				vecEnd = tr.vecEndPos;

				vecSrc = vecForward * 4.0;
				vecEnd = vecEnd - vecSrc;

				g_Utility.BloodDrips( vecEnd, vecForward, pEntity.BloodColor(), int(flDamage) );
				pEntity.TraceBleed( flDamage, vecForward, tr, DMG_SLASH | DMG_NEVERGIB ); //DMG_CLUB
			}

			pEntity.TraceAttack( m_pPlayer.pev, flDamage, g_Engine.v_forward, tr, DMG_SLASH | DMG_NEVERGIB ); //TakeDamage instead ??

			g_WeaponFuncs.ApplyMultiDamage( m_pPlayer.pev, m_pPlayer.pev );

			float flVol = 1.0;
			bool fHitWorld = true;

			if( pEntity !is null )
			{
				self.m_flNextPrimaryAttack = g_Engine.time + VSW_TIME_DELAY1; //uncomment this and remove the other instance of this line below to fix the insane attack speed on dead mobs

				if( pEntity.Classify() != CLASS_NONE and pEntity.Classify() != CLASS_MACHINE )
				{
					g_SoundSystem.EmitSound( m_pPlayer.edict(), CHAN_ITEM, arrsSounds[Math.RandomLong(SND_HITBOD1, SND_HITBOD3)], VOL_NORM, ATTN_NORM );

					m_pPlayer.m_iWeaponVolume = 128;

					if( !pEntity.IsAlive() )
						return;
					else
						flVol = 0.1;

					fHitWorld = false;
				}
			}

			if( fHitWorld == true )
			{
				float fvolbar = g_SoundSystem.PlayHitSound( tr, vecSrc, vecSrc + (vecEnd - vecSrc) * 2, BULLET_PLAYER_CROWBAR );

				fvolbar = 1;

				switch( Math.RandomLong(0, 1) )
				{
					case 0: g_SoundSystem.EmitSoundDyn( m_pPlayer.edict(), CHAN_ITEM, arrsSounds[SND_HIT1], fvolbar, ATTN_NORM, 0, 98 + Math.RandomLong(0, 3) ); break;
					case 1: g_SoundSystem.EmitSoundDyn( m_pPlayer.edict(), CHAN_ITEM, arrsSounds[SND_HIT2], fvolbar, ATTN_NORM, 0, 98 + Math.RandomLong(0, 3) ); break;
				}

				m_trHit = tr;
			}

			m_pPlayer.m_iWeaponVolume = int( flVol * 512 );
			//self.m_flNextPrimaryAttack = g_Engine.time + (VSW_TIME_DELAY1 * 0.5); //uncomment this and remove the other instance of this line above to enable the insane attack speed on dead mobs
			self.m_flTimeWeaponIdle = g_Engine.time + ( 0.25 + Math.RandomFloat(0.25, (0.25*4)) );

			SetThink( ThinkFunction(this.Smack) );
			pev.nextthink = g_Engine.time + 0.2;
		}
	}

	void Smack()
	{
		g_WeaponFuncs.DecalGunshot( m_trHit, BULLET_PLAYER_CROWBAR );
	}

	void SecondaryAttack()
	{
		m_pPlayer.m_szAnimExtension = VSW_ANIMEXT2;
		ColtFire( 0.01, 0.3 );
	}

	void ColtFire( float flSpread , float flCycleTime )
	{
		if( self.m_iClip <= 0 )
		{
			if( self.m_bFireOnEmpty )
			{
				self.PlayEmptySound();
				self.m_flNextPrimaryAttack = g_Engine.time + 0.2;
			}

			return;
		}

		self.m_iClip--;

		m_pPlayer.pev.effects |= EF_MUZZLEFLASH;

		self.SendWeaponAnim( ANIM_SHOOT );

		/*if ( fUseAutoAim )
		{
			PLAYBACK_EVENT_FULL( 0, m_pPlayer.edict(), m_usFireGlock1, 0.0, (float *)&g_vecZero, (float *)&g_vecZero, 0.0, 0.0, 0, 0, ( m_iClip == 0 ) ? 1 : 0, 0 );
		}
		else
		{
			PLAYBACK_EVENT_FULL( 0, m_pPlayer.edict(), m_usFireGlock2, 0.0, (float *)&g_vecZero, (float *)&g_vecZero, 0.0, 0.0, 0, 0, ( m_iClip == 0 ) ? 1 : 0, 0 );
		}*/

		m_pPlayer.SetAnimation( PLAYER_ATTACK1 );

		Math.MakeVectors( m_pPlayer.pev.v_angle + m_pPlayer.pev.punchangle );
			
		Vector vecShellVelocity = m_pPlayer.pev.velocity 
								 + g_Engine.v_right * Math.RandomFloat( 50, 70 ) 
								 + g_Engine.v_up * Math.RandomFloat( 100, 150 ) 
								 + g_Engine.v_forward * 25;

		g_EntityFuncs.EjectBrass( pev.origin + m_pPlayer.pev.view_ofs + g_Engine.v_up * -12 + g_Engine.v_forward * 32 + g_Engine.v_right * 6 , vecShellVelocity, pev.angles.y, m_iShell, TE_BOUNCE_SHELL );

		m_pPlayer.m_iWeaponVolume = NORMAL_GUN_VOLUME;
		m_pPlayer.m_iWeaponFlash = NORMAL_GUN_FLASH;

		g_SoundSystem.EmitSoundDyn( m_pPlayer.edict(), CHAN_WEAPON, arrsSounds[SND_SHOOT], Math.RandomFloat(0.92, 1.0), ATTN_NORM, 0, 98 + Math.RandomLong(0, 3) );

		Vector vecSrc	 = m_pPlayer.GetGunPosition();
		Vector vecAiming = g_Engine.v_forward;

		self.FireBullets( 1, vecSrc, vecAiming, Vector(flSpread, flSpread, flSpread), 8192, BULLET_PLAYER_CUSTOMDAMAGE, 0, VSW_DAMAGE_GUN, m_pPlayer.pev );

		self.m_flNextPrimaryAttack = self.m_flNextSecondaryAttack = g_Engine.time + flCycleTime;

		if( self.m_iClip <= 0 and m_pPlayer.m_rgAmmo(self.m_iPrimaryAmmoType) <= 0 )
			m_pPlayer.SetSuitUpdate( "!HEV_AMO0", false, 0 );

		self.m_flTimeWeaponIdle = g_Engine.time + Math.RandomFloat( 10, 15 );

		m_pPlayer.pev.punchangle.x -= 2;
	}

	void Reload()
	{
		if( self.DefaultReload(VSW_MAX_CLIP, ANIM_RELOAD, VSW_TIME_RELOAD) )
		{
			m_pPlayer.SetAnimation( PLAYER_RELOAD );
			self.m_flTimeWeaponIdle = g_Engine.time + Math.RandomFloat( 10, 15 );
		}
	}

	void WeaponIdle()
	{
		self.ResetEmptySound();

		if( self.m_flTimeWeaponIdle > g_Engine.time )
			return;

		float flIdleTime;
		int iAnim = Math.RandomLong( ANIM_IDLE1, ANIM_IDLE6 );
		self.SendWeaponAnim( iAnim );

		switch( iAnim )
		{
			case ANIM_IDLE1: flIdleTime = VSW_TIME_IDLE1; break;
			case ANIM_IDLE2: flIdleTime = VSW_TIME_IDLE2; break;
			case ANIM_IDLE3: flIdleTime = VSW_TIME_IDLE3; break;
			case ANIM_IDLE4: flIdleTime = VSW_TIME_IDLE4; break;
			case ANIM_IDLE5: flIdleTime = VSW_TIME_IDLE5; break;
			case ANIM_IDLE6: flIdleTime = VSW_TIME_IDLE6; break;
		}

		self.m_flTimeWeaponIdle = g_Engine.time + (flIdleTime + Math.RandomFloat(3.0, (flIdleTime*4)));
	}
}

void Register()
{
	g_CustomEntityFuncs.RegisterCustomEntity( "vs_colt::weapon_vscolt", "weapon_vscolt" );
	g_ItemRegistry.RegisterWeapon( "weapon_vscolt", "vs", "vscoltammo" );
}

}