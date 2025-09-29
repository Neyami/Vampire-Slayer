//based on HL crossbow
namespace vs_crossbow
{

const int VSW_DEFAULT_GIVE			= 1;
const int VSW_MAX_CLIP 				= 1;
const int VSW_MAX_AMMO				= 6;

const int VSW_DAMAGE1				= 50;
const int VSW_DAMAGE2				= 100; //120 ??
const float VSW_TIME_DELAY1		= 0.75;
const float VSW_TIME_DELAY2		= 0.3;
const float VSW_TIME_DRAW			= 0.5;
const float VSW_TIME_RELOAD		= 4.0;

const string VSW_ANIMEXT				= "crossbow";
const string MODEL_VIEW				= "models/vs/weapons/v_crossbow.mdl";
const string MODEL_PLAYER			= "models/vs/weapons/p_crossbow.mdl";
const string MODEL_WORLD			= "models/vs/weapons/w_weaponbox.mdl";
const string MODEL_BOLT				= "models/vs/weapons/crossbow_bolt.mdl";

const int VSW_FOV_ZOOM				= 13;

enum anim_e
{
	ANIM_IDLE1,
	ANIM_IDLE2,
	ANIM_IDLE3,
	ANIM_IDLE4,
	ANIM_SHOOT1,
	ANIM_SHOOT2,
	ANIM_SHOOT3,
	ANIM_RELOAD,
	ANIM_DRAW1,
	ANIM_DRAW2,
	ANIM_HOLSTER1,
	ANIM_HOLSTER2
};

enum sounds_e
{
	SND_SHOOT = 0,
	SND_HIT,
	SND_HITBOD1,
	SND_HITBOD2,
	SND_RELOAD,
	SND_EMPTY
};

const array<string> arrsSounds =
{
	"weapons/xbow_fire1.wav",
	"weapons/xbow_hit1.wav",
	"weapons/xbow_hitbod1.wav",
	"weapons/xbow_hitbod2.wav",
	"vs/weapons/xbow_reload1.wav",
	"weapons/357_cock1.wav"
};

class weapon_vscrossbow : CBaseVSWeapon
{
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
		g_Game.PrecacheModel( MODEL_BOLT );

		for( uint i = 0; i < arrsSounds.length(); ++i )
			g_SoundSystem.PrecacheSound( arrsSounds[i] );

		//Precache these for downloading
		for( uint i = 0; i < arrsSounds.length(); ++i )
			g_Game.PrecacheGeneric( "sound/" + arrsSounds[i] );

		g_Game.PrecacheGeneric( "sprites/vs/weapon_vscrossbow.txt" );
		g_Game.PrecacheGeneric( "sprites/vs/640hud2.spr" );
		g_Game.PrecacheGeneric( "sprites/vs/640hud5.spr" );
		g_Game.PrecacheGeneric( "sprites/vs/640hud7.spr" );
		g_Game.PrecacheGeneric( "sprites/vs/crosshairs.spr" );
	}

	bool GetItemInfo( ItemInfo& out info )
	{
		info.iMaxAmmo1	= VSW_MAX_AMMO;
		info.iMaxAmmo2	= -1;
		info.iMaxClip			= VSW_MAX_CLIP;
		info.iSlot				= vs::CROSSBOW_SLOT-1;
		info.iPosition			= vs::CROSSBOW_POSITION-1;
		info.iWeight			= vs::CROSSBOW_WEIGHT;
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
			m.WriteLong( g_ItemRegistry.GetIdForName("weapon_vscrossbow") );
		m.End();

		return true;
	}

	bool Deploy()
	{
		bool bResult;
		{
			int iAnim = (self.m_iClip > 0) ? ANIM_DRAW1 : ANIM_DRAW2;
			bResult = self.DefaultDeploy( self.GetV_Model(MODEL_VIEW), self.GetP_Model(MODEL_PLAYER), iAnim, VSW_ANIMEXT );
			self.m_flTimeWeaponIdle = self.m_flNextPrimaryAttack = self.m_flNextSecondaryAttack = g_Engine.time + VSW_TIME_DRAW;
			self.ResetEmptySound();

			return bResult;
		}
	}

	void Holster( int skiplocal )
	{
		self.m_fInReload= false;
		m_pPlayer.pev.fov = m_pPlayer.m_iFOV = 0;

		BaseClass.Holster( skiplocal );
	}

	bool PlayEmptySound()
	{
		if( self.m_bPlayEmptySound )
		{
			g_SoundSystem.EmitSound( m_pPlayer.edict(), CHAN_WEAPON, arrsSounds[SND_EMPTY], 0.8, ATTN_NORM );
			self.m_bPlayEmptySound = false;
		}

		return false;
	}

	void PrimaryAttack()
	{
		if( m_pPlayer.m_iFOV != 0 )
		{
			FireSniperBolt();
			return;
		}

		FireBolt();
	}

	void FireSniperBolt()
	{
		self.m_flNextPrimaryAttack = g_Engine.time + VSW_TIME_DELAY1;

		if( self.m_iClip == 0 )
		{
			self.PlayEmptySound();
			return;
		}

		TraceResult tr;

		m_pPlayer.m_iWeaponVolume = QUIET_GUN_VOLUME;
		self.m_iClip--;

		g_SoundSystem.EmitSoundDyn( m_pPlayer.edict(), CHAN_WEAPON, arrsSounds[SND_SHOOT], VOL_NORM, ATTN_NORM, 0, 93 + Math.RandomLong(0, 0xF) );

		self.SendWeaponAnim( Math.RandomLong(ANIM_SHOOT1, ANIM_SHOOT3) );

		m_pPlayer.SetAnimation( PLAYER_ATTACK1 );

		Math.MakeVectors( m_pPlayer.pev.v_angle + m_pPlayer.pev.punchangle );
		Vector vecSrc = m_pPlayer.GetGunPosition();
		Vector vecDir = g_Engine.v_forward;

		g_Utility.TraceLine( vecSrc, vecSrc + vecDir * 8192, dont_ignore_monsters, m_pPlayer.edict(), tr );

		if( tr.pHit.vars.takedamage != DAMAGE_NO )
		{
			g_WeaponFuncs.ClearMultiDamage();
			g_EntityFuncs.Instance(tr.pHit).TraceAttack( m_pPlayer.pev, VSW_DAMAGE2, vecDir, tr, DMG_BULLET | DMG_NEVERGIB );
			g_WeaponFuncs.ApplyMultiDamage( self.pev, m_pPlayer.pev );
		}

		if( tr.flFraction < 1.0 )
		{
			CBaseEntity@ pEntity = g_EntityFuncs.Instance( tr.pHit );

			if( !pEntity.IsBSPModel() )
				g_SoundSystem.PlaySound( pEntity.edict(), CHAN_BODY, arrsSounds[Math.RandomLong(SND_HITBOD1, SND_HITBOD2)], VOL_NORM, ATTN_NORM, 0, PITCH_NORM, 0, true, tr.vecEndPos ); //m_pPlayer.edict() ??
			else
			{
				g_SoundSystem.PlaySound( g_EntityFuncs.Instance(0).edict(), CHAN_BODY, arrsSounds[SND_HIT], Math.RandomFloat(0.95, 1.0), ATTN_NORM, 0, PITCH_NORM, 0, true, tr.vecEndPos ); //null ??

				if( g_EngineFuncs.PointContents(tr.vecEndPos) != CONTENTS_WATER )
					g_Utility.Sparks( tr.vecEndPos );

				Vector vecOrigin = tr.vecEndPos - g_Engine.v_forward * 10;
				CBaseEntity@ pBolt = g_EntityFuncs.Create( "crossbow_bolt", vecOrigin, Math.VecToAngles(g_Engine.v_forward), false );
				if( pBolt !is null )
				{
					g_EntityFuncs.SetModel( pBolt, MODEL_BOLT );
					pBolt.pev.dmg = 0;
					pBolt.pev.solid = SOLID_NOT;
					pBolt.Touch( pEntity );
					pBolt.pev.nextthink = g_Engine.time + 10.0;

					if( pEntity.GetClassname() == "func_breakable" )
						pBolt.pev.movetype = MOVETYPE_TOSS;
				}
			}
		}
	}

	void FireBolt()
	{
		if( self.m_iClip == 0 )
		{
			self.PlayEmptySound();
			return;
		}

		TraceResult tr;

		m_pPlayer.m_iWeaponVolume = QUIET_GUN_VOLUME;

		self.m_iClip--;

		g_SoundSystem.EmitSoundDyn( m_pPlayer.edict(), CHAN_WEAPON, arrsSounds[SND_SHOOT], VOL_NORM, ATTN_NORM, 0, 93 + Math.RandomLong(0, 0xF) );

		self.SendWeaponAnim( Math.RandomLong(ANIM_SHOOT1, ANIM_SHOOT3) );

		m_pPlayer.pev.punchangle.x = -2.0;
		m_pPlayer.SetAnimation( PLAYER_ATTACK1 );

		Vector anglesAim = m_pPlayer.pev.v_angle + m_pPlayer.pev.punchangle;
		Math.MakeVectors( anglesAim );

		anglesAim.x = -anglesAim.x;
		Vector vecSrc = m_pPlayer.GetGunPosition();
		Vector vecDir = g_Engine.v_forward;

		CBaseEntity@ pBolt = g_EntityFuncs.Create( "crossbow_bolt", vecSrc, anglesAim, false, m_pPlayer.edict() );
		g_EntityFuncs.SetModel( pBolt, MODEL_BOLT );

		if( m_pPlayer.pev.waterlevel == WATERLEVEL_HEAD )
		{
			pBolt.pev.velocity = vecDir * 1000; //BOLT_WATER_VELOCITY
			pBolt.pev.speed = 1000; //BOLT_WATER_VELOCITY
		}
		else
		{
			pBolt.pev.velocity = vecDir * 2000; //BOLT_AIR_VELOCITY
			pBolt.pev.speed = 2000; //BOLT_AIR_VELOCITY
		}

		pBolt.pev.avelocity.z = 10;

		if( self.m_iClip <= 0 and m_pPlayer.m_rgAmmo(self.m_iPrimaryAmmoType) <= 0 )
			m_pPlayer.SetSuitUpdate( "!HEV_AMO0", false, 0 );

		self.m_flNextPrimaryAttack = self.m_flNextSecondaryAttack = g_Engine.time + 0.75;

		if( self.m_iClip != 0 )
			self.m_flTimeWeaponIdle = g_Engine.time + 5.0;
		else
			self.m_flTimeWeaponIdle = g_Engine.time + 0.75;
	}

	void SecondaryAttack()
	{
		switch( m_pPlayer.m_iFOV )
		{
			case 0: m_pPlayer.pev.fov = m_pPlayer.m_iFOV = VSW_FOV_ZOOM; m_pPlayer.m_szAnimExtension = "sniperscope"; break;
			default: ResetZoom(); break;
		}

		self.m_flNextSecondaryAttack = g_Engine.time + VSW_TIME_DELAY2;
	}

	void Reload()
	{
		if( m_pPlayer.m_iFOV != 0 )
			m_pPlayer.pev.fov = m_pPlayer.m_iFOV = 0;

		if( self.DefaultReload(VSW_MAX_CLIP, ANIM_RELOAD, VSW_TIME_RELOAD) )
		{
			g_SoundSystem.EmitSoundDyn( m_pPlayer.edict(), CHAN_ITEM, arrsSounds[SND_RELOAD], Math.RandomFloat(0.95, 1.0), ATTN_NORM, 0, 93 + Math.RandomLong(0, 0xF) );
			m_pPlayer.SetAnimation( PLAYER_RELOAD );
			self.m_flTimeWeaponIdle = g_Engine.time + Math.RandomFloat( 10, 15 );
		}
	}

	void WeaponIdle()
	{
		if( self.m_flTimeWeaponIdle > g_Engine.time )
			return;

		float flRand = g_PlayerFuncs.SharedRandomFloat( m_pPlayer.random_seed, 0, 1 );
		if( flRand <= 0.75 )
		{
			if( self.m_iClip > 0 )
				self.SendWeaponAnim( ANIM_IDLE1 );
			else
				self.SendWeaponAnim( ANIM_IDLE2 );

			self.m_flTimeWeaponIdle = g_Engine.time + g_PlayerFuncs.SharedRandomFloat( m_pPlayer.random_seed, 10, 15 );
		}
		else
		{
			if( self.m_iClip > 0 )
			{
				self.SendWeaponAnim( ANIM_IDLE3 );
				self.m_flTimeWeaponIdle = g_Engine.time + 90.0 / 30.0;
			}
			else
			{
				self.SendWeaponAnim( ANIM_IDLE4 );
				self.m_flTimeWeaponIdle = g_Engine.time + 80.0 / 30.0;
			}
		}
	}

	void ResetZoom()
	{
		m_pPlayer.pev.fov = m_pPlayer.m_iFOV = 0;
		m_pPlayer.m_szAnimExtension = VSW_ANIMEXT;
	}
}

void Register()
{
	g_CustomEntityFuncs.RegisterCustomEntity( "vs_crossbow::weapon_vscrossbow", "weapon_vscrossbow" );
	g_ItemRegistry.RegisterWeapon( "weapon_vscrossbow", "vs", "vscrossbowammo" );
}

}