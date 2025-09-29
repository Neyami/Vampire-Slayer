//based on HL crowbar
namespace vs_cue
{

const int VSW_DAMAGE1				= 30; //stab (and kill)
const int VSW_DAMAGE2				= 5; //swing
const float VSW_TIME_DELAY			= 0.5;
const float VSW_TIME_DRAW			= 0.5;
const float VSW_TIME_IDLE1			= 3.4;
const float VSW_TIME_IDLE2			= 3.4;
const float VSW_TIME_IDLE3			= 3.4;
const float VSW_TIME_IDLE4			= 0.7;
const float VSW_TIME_IDLE5			= 1.7;

const string VSW_ANIMEXT				= "crowbar";
const string MODEL_VIEW				= "models/vs/weapons/v_cue.mdl";
const string MODEL_PLAYER			= "models/vs/weapons/p_cue.mdl";
const string MODEL_WORLD			= "models/vs/weapons/w_weaponbox.mdl";

enum anim_e
{
	ANIM_IDLE1 = 0,
	ANIM_IDLE2,
	ANIM_IDLE3,
	ANIM_IDLE4,
	ANIM_IDLE5,
	ANIM_DRAW,
	ANIM_HOLSTER,
	ANIM_ATTACK1HIT,
	ANIM_ATTACK1MISS,
	ANIM_ATTACK2HIT,
	ANIM_ATTACK2MISS,
	ANIM_ATTACK3HIT,
	ANIM_ATTACK3MISS,
	ANIM_SWING1,
	ANIM_SWING2,
	ANIM_SWING3
};

enum sounds_e
{
	SND_HIT1 = 0,
	SND_HIT2,
	SND_HITBOD1,
	SND_HITBOD2,
	SND_HITBOD3,
	SND_MISS
};

const array<string> arrsSounds =
{
	"vs/weapons/cbar_hit1.wav",
	"vs/weapons/cbar_hit2.wav",
	"weapons/cbar_hitbod1.wav",
	"weapons/cbar_hitbod2.wav",
	"weapons/cbar_hitbod3.wav",
	"weapons/cbar_miss1.wav"
};

class weapon_vscue : CBaseVSWeapon
{
	int m_iSwing;
	TraceResult m_trHit;

	void Spawn()
	{
		Precache();
		g_EntityFuncs.SetModel( self, MODEL_WORLD );
		self.m_iClip = WEAPON_NOCLIP;
		self.m_flCustomDmg = pev.dmg;

		self.FallInit();
	}

	void Precache()
	{
		self.PrecacheCustomModels();

		g_Game.PrecacheModel( MODEL_VIEW );
		g_Game.PrecacheModel( MODEL_WORLD );
		g_Game.PrecacheModel( MODEL_PLAYER );

		for( uint i = 0; i < arrsSounds.length(); ++i )
			g_SoundSystem.PrecacheSound( arrsSounds[i] );

		//Precache these for downloading
		for( uint i = 0; i < arrsSounds.length(); ++i )
			g_Game.PrecacheGeneric( "sound/" + arrsSounds[i] );

		g_Game.PrecacheGeneric( "sprites/vs/weapon_vscue.txt" );
		g_Game.PrecacheGeneric( "sprites/vs/640hud2.spr" );
		g_Game.PrecacheGeneric( "sprites/vs/640hud5.spr" );
	}

	bool GetItemInfo( ItemInfo& out info )
	{
		info.iMaxAmmo1	= -1;
		info.iMaxAmmo2	= -1;
		info.iMaxClip			= WEAPON_NOCLIP;
		info.iSlot				= vs::CUE_SLOT-1;
		info.iPosition			= vs::CUE_POSITION-1;
		info.iWeight			= vs::CUE_WEIGHT;
		info.iFlags				= ITEM_FLAG_SELECTONEMPTY | ITEM_FLAG_NOAUTOSWITCHEMPTY;

		return true;
	}

	bool AddToPlayer( CBasePlayer@ pPlayer )
	{
		//not needed with mp_dropweapons 0
		if( vs::GetPlayerTeam(pPlayer) != vs::TEAM_SLAYER or vs::GetPlayerClass(pPlayer) != vs::CLASS_HUMAN_EIGHTBALL )
			return false;

		if( !BaseClass.AddToPlayer(pPlayer) )
			return false;

		@m_pPlayer = pPlayer;

		NetworkMessage m( MSG_ONE, NetworkMessages::WeapPickup, pPlayer.edict() );
			m.WriteLong( g_ItemRegistry.GetIdForName("weapon_vscue") );
		m.End();

		return true;
	}

	bool Deploy()
	{
		bool bResult;
		{
			bResult = self.DefaultDeploy( self.GetV_Model(MODEL_VIEW), self.GetP_Model(MODEL_PLAYER), ANIM_DRAW, VSW_ANIMEXT );
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
		Swing();
	}

	void SecondaryAttack()
	{
		Swing( false );
	}

	void Smack()
	{
		g_WeaponFuncs.DecalGunshot( m_trHit, BULLET_PLAYER_CROWBAR );
	}

	void Swing( bool bPrimary = true )
	{
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

		g_SoundSystem.EmitSoundDyn( m_pPlayer.edict(), CHAN_WEAPON, arrsSounds[SND_MISS], 1, ATTN_NORM, 0, 94 + Math.RandomLong( 0,0xF ) );

		if( tr.flFraction >= 1.0 )
		{
			switch( (m_iSwing++) % 3 )
			{
				case 0: self.SendWeaponAnim( bPrimary ? ANIM_ATTACK1MISS : ANIM_SWING1 ); break;
				case 1: self.SendWeaponAnim( bPrimary ? ANIM_ATTACK2MISS : ANIM_SWING2 ); break;
				case 2: self.SendWeaponAnim( bPrimary ? ANIM_ATTACK3MISS : ANIM_SWING3 ); break;
			}

			self.m_flNextPrimaryAttack  = self.m_flNextSecondaryAttack = g_Engine.time + VSW_TIME_DELAY;
			self.m_flTimeWeaponIdle = g_Engine.time + ( 0.5 + Math.RandomFloat(0.5, (0.5*4)) );

			m_pPlayer.SetAnimation( PLAYER_ATTACK1 );
		}
		else
		{
			switch( ((m_iSwing++) % 2) + 1 )
			{
				case 0: self.SendWeaponAnim( bPrimary ? ANIM_ATTACK1HIT : ANIM_SWING1 ); break;
				case 1: self.SendWeaponAnim( bPrimary ? ANIM_ATTACK2HIT : ANIM_SWING2 ); break;
				case 2: self.SendWeaponAnim( bPrimary ? ANIM_ATTACK3HIT : ANIM_SWING3 ); break;
			}

			m_pPlayer.SetAnimation( PLAYER_ATTACK1 );

			CBaseEntity@ pEntity = g_EntityFuncs.Instance( tr.pHit );

			g_WeaponFuncs.ClearMultiDamage();

			float flDamage = bPrimary ? VSW_DAMAGE1 : VSW_DAMAGE2;
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
			if( bPrimary and iHitgroup == HITGROUP_CHEST )
				flDamage *= 2.0;

			if( pEntity.IsPlayer() )
			{
				CBasePlayer@ pTarget = cast<CBasePlayer@>( pEntity );
				pTarget.m_LastHitGroup = iHitgroup;
			}

			int iDamageType = DMG_SLASH;
			if( !bPrimary ) iDamageType = DMG_CLUB;

			if( pEntity.BloodColor() != DONT_BLEED )
			{
				vecAngle = m_pPlayer.pev.v_angle;
				Math.MakeVectors( vecAngle );

				vecForward = g_Engine.v_forward;
				vecEnd = tr.vecEndPos;

				vecSrc = vecForward * 4.0;
				vecEnd = vecEnd - vecSrc;

				g_Utility.BloodDrips( vecEnd, vecForward, pEntity.BloodColor(), int(flDamage) );
				pEntity.TraceBleed( flDamage, vecForward, tr, iDamageType | DMG_NEVERGIB );
			}

			pEntity.TraceAttack( m_pPlayer.pev, flDamage, g_Engine.v_forward, tr, iDamageType | DMG_NEVERGIB ); //TakeDamage instead ??

			g_WeaponFuncs.ApplyMultiDamage( m_pPlayer.pev, m_pPlayer.pev );

			float flVol = 1.0;
			bool fHitWorld = true;

			if( pEntity !is null )
			{
				self.m_flNextPrimaryAttack = self.m_flNextSecondaryAttack  = g_Engine.time + VSW_TIME_DELAY; //uncomment this and remove the other instance of this line below to fix the insane attack speed on dead mobs

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
			//self.m_flNextPrimaryAttack = self.m_flNextSecondaryAttack  = g_Engine.time + (VSW_TIME_DELAY * 0.5); //uncomment this and remove the other instance of this line above to enable the insane attack speed on dead mobs
			self.m_flTimeWeaponIdle = g_Engine.time + ( 0.25 + Math.RandomFloat(0.25, (0.25*4)) );

			SetThink( ThinkFunction(this.Smack) );
			pev.nextthink = g_Engine.time + 0.2;
		}
	}

	void WeaponIdle()
	{
		self.ResetEmptySound();

		if( self.m_flTimeWeaponIdle > g_Engine.time )
			return;

		float flIdleTime;
		int iAnim = Math.RandomLong( ANIM_IDLE1, ANIM_IDLE5 );
		self.SendWeaponAnim( iAnim );

		switch( iAnim )
		{
			case ANIM_IDLE1: flIdleTime = VSW_TIME_IDLE1; break;
			case ANIM_IDLE2: flIdleTime = VSW_TIME_IDLE2; break;
			case ANIM_IDLE3: flIdleTime = VSW_TIME_IDLE3; break;
			case ANIM_IDLE4: flIdleTime = VSW_TIME_IDLE4; break;
			case ANIM_IDLE5: flIdleTime = VSW_TIME_IDLE5; break;
		}

		self.m_flTimeWeaponIdle = g_Engine.time + (flIdleTime + Math.RandomFloat(3.0, (flIdleTime*4)));
	}
}

void Register()
{
	g_CustomEntityFuncs.RegisterCustomEntity( "vs_cue::weapon_vscue", "weapon_vscue" );
	g_ItemRegistry.RegisterWeapon( "weapon_vscue", "vs" );
}

}