//based on HL shotgun
namespace vs_shotgun
{

const int VSW_DEFAULT_GIVE				= 8;
const int VSW_MAX_CLIP 					= 8;
const int VSW_MAX_AMMO					= 28;

const int VSW_DAMAGE						= 22;
const int VSW_SHOTS1						= 4; //88 damage total
const int VSW_SHOTS2						= 8; //176 damage total ??
const float VSW_TIME_DELAY1			= 0.75;
const float VSW_TIME_DELAY2			= 1.5;
const float VSW_TIME_DRAW				= 0.5;

const string VSW_ANIMEXT					= "shotgun";
const string MODEL_VIEW					= "models/vs/weapons/v_shotgun.mdl";
const string MODEL_PLAYER				= "models/vs/weapons/p_shotgun.mdl";
const string MODEL_WORLD				= "models/vs/weapons/w_weaponbox.mdl";

const Vector VSW_OFFSETS_SHELL1	= Vector( 17.140528, 12.745428, -10.018049 ); //32.0, 6.0, -12.0
const Vector VSW_OFFSETS_SHELL2	= Vector( 17.448786, 12.745428, -9.470949 );
 
enum anim_e
{
	ANIM_IDLE1,
	ANIM_SHOOT1,
	ANIM_SHOOT2,
	ANIM_RELOAD_INSERT,
	ANIM_RELOAD_FINISH,
	ANIM_RELOAD_START,
	ANIM_DRAW,
	ANIM_HOLSTER,
	ANIM_IDLE4,
	ANIM_IDLE_DEEP
};

enum sounds_e
{
	SND_SHOOT1 = 0,
	SND_SHOOT2,
	SND_RELOAD_INSERT1,
	SND_RELOAD_INSERT2,
	SND_RELOAD_FINISH,
	SND_EMPTY
};

const array<string> arrsSounds =
{
	"vs/weapons/sbarrel1.wav",
	"vs/weapons/dbarrel1.wav",
	"hlclassic/weapons/reload1.wav",
	"vs/weapons/reload3.wav",
	"vs/weapons/scock1.wav",
	"weapons/357_cock1.wav"
};

class weapon_vsshotgun : CBaseVSWeapon
{
	private int m_iShell;
	private float m_flPumpTime;

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

		m_iShell = g_Game.PrecacheModel( "models/shotgunshell.mdl" );

		for( uint i = 0; i < arrsSounds.length(); ++i )
			g_SoundSystem.PrecacheSound( arrsSounds[i] );

		//Precache these for downloading
		for( uint i = 0; i < arrsSounds.length(); ++i )
			g_Game.PrecacheGeneric( "sound/" + arrsSounds[i] );

		g_Game.PrecacheGeneric( "sprites/vs/weapon_vsshotgun.txt" );
		g_Game.PrecacheGeneric( "sprites/vs/640hud1.spr" );
		g_Game.PrecacheGeneric( "sprites/vs/640hud4.spr" );
		g_Game.PrecacheGeneric( "sprites/vs/640hud7.spr" );
		g_Game.PrecacheGeneric( "sprites/vs/crosshairs.spr" );
	}

	bool GetItemInfo( ItemInfo& out info )
	{
		info.iMaxAmmo1	= VSW_MAX_AMMO;
		info.iMaxAmmo2	= -1;
		info.iMaxClip			= VSW_MAX_CLIP;
		info.iSlot				= vs::SHOTGUN_SLOT-1;
		info.iPosition			= vs::SHOTGUN_POSITION-1;
		info.iWeight			= vs::SHOTGUN_WEIGHT;
		info.iFlags				= ITEM_FLAG_SELECTONEMPTY | ITEM_FLAG_NOAUTOSWITCHEMPTY;

		return true;
	}

	bool AddToPlayer( CBasePlayer@ pPlayer )
	{
		//not needed with mp_dropweapons 0
		if( vs::GetPlayerTeam(pPlayer) != vs::TEAM_SLAYER or vs::GetPlayerClass(pPlayer) != vs::CLASS_HUMAN_FATHER )
			return false;

		if( !BaseClass.AddToPlayer(pPlayer) )
			return false;

		@m_pPlayer = pPlayer;

		NetworkMessage m( MSG_ONE, NetworkMessages::WeapPickup, pPlayer.edict() );
			m.WriteLong( g_ItemRegistry.GetIdForName("weapon_vsshotgun") );
		m.End();

		return true;
	}

	bool Deploy()
	{
		bool bResult;
		{
			bResult = self.DefaultDeploy( self.GetV_Model(MODEL_VIEW), self.GetP_Model(MODEL_PLAYER), ANIM_DRAW, VSW_ANIMEXT );
			self.m_flTimeWeaponIdle = self.m_flNextPrimaryAttack = self.m_flNextSecondaryAttack = g_Engine.time + VSW_TIME_DRAW;
			self.ResetEmptySound();

			return bResult;
		}
	}

	void Holster( int skiplocal )
	{
		m_flPumpTime = m_flEjectBrass = 0.0;
		m_iInSpecialReload = 0;

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
		if( m_pPlayer.pev.waterlevel == WATERLEVEL_HEAD )
		{
			self.PlayEmptySound();
			self.m_flNextPrimaryAttack = 0.15;
			return;
		}

		if( self.m_iClip <= 0 )
		{
			Reload();

			if( self.m_iClip == 0 )
				self.PlayEmptySound();

			return;
		}

		m_iNumShots = 1;

		m_pPlayer.m_iWeaponVolume = LOUD_GUN_VOLUME;
		m_pPlayer.m_iWeaponFlash = NORMAL_GUN_FLASH;

		self.m_iClip--;

		m_pPlayer.pev.effects |= EF_MUZZLEFLASH;
		m_pPlayer.SetAnimation( PLAYER_ATTACK1 );

		Math.MakeVectors( m_pPlayer.pev.v_angle + m_pPlayer.pev.punchangle );
		Vector vecAiming = g_Engine.v_forward;
		Vector vecSrc	 = m_pPlayer.GetGunPosition();

		float flDamage = VSW_DAMAGE;
		if( self.m_flCustomDmg > 0 ) flDamage = self.m_flCustomDmg;

		//multiplayer spread
		self.FireBullets( VSW_SHOTS1, vecSrc, vecAiming, vs::VECTOR_CONE_DM_SHOTGUN, 2048, BULLET_PLAYER_CUSTOMDAMAGE, 0, int(flDamage), m_pPlayer.pev );

		// regular old, untouched spread. 
		//self.FireBullets( 6, vecSrc, vecAiming, VECTOR_CONE_10DEGREES, 2048, BULLET_PLAYER_CUSTOMDAMAGE, 0, int(flDamage), m_pPlayer.pev );

		self.SendWeaponAnim( ANIM_SHOOT1 );
		m_pPlayer.pev.punchangle.x = -5.0;

		g_SoundSystem.EmitSoundDyn( m_pPlayer.edict(), CHAN_WEAPON, arrsSounds[SND_SHOOT1], VOL_NORM, ATTN_NORM, 0, 85 + Math.RandomLong(0, 0x1f) );

		if( self.m_iClip <= 0 and m_pPlayer.m_rgAmmo(self.m_iPrimaryAmmoType) <= 0 )
			m_pPlayer.SetSuitUpdate( "!HEV_AMO0", false, 0 );

		//if( self.m_iClip != 0 ) //this causes the last shot fired to not expel shells, but why ??
		{
			m_flPumpTime = g_Engine.time + 0.15;
			m_flEjectBrass = g_Engine.time + 0.3;
		}

		self.m_flNextPrimaryAttack = self.m_flNextSecondaryAttack = g_Engine.time + VSW_TIME_DELAY1;

		if( self.m_iClip != 0 )
			self.m_flTimeWeaponIdle = g_Engine.time + 5.0;
		else
			self.m_flTimeWeaponIdle = g_Engine.time + 0.75;

		m_iInSpecialReload = 0;
	}

	void SecondaryAttack()
	{
		if( m_pPlayer.pev.waterlevel == WATERLEVEL_HEAD )
		{
			self.PlayEmptySound();
			self.m_flNextPrimaryAttack = 0.15;
			return;
		}

		if( self.m_iClip <= 1 )
		{
			Reload();
			self.PlayEmptySound();

			return;
		}

		m_iNumShots = 2;

		m_pPlayer.m_iWeaponVolume = LOUD_GUN_VOLUME;
		m_pPlayer.m_iWeaponFlash = NORMAL_GUN_FLASH;

		self.m_iClip -= 2;

		m_pPlayer.pev.effects |= EF_MUZZLEFLASH;
		m_pPlayer.SetAnimation( PLAYER_ATTACK1 );

		Math.MakeVectors( m_pPlayer.pev.v_angle + m_pPlayer.pev.punchangle );
		Vector vecAiming = g_Engine.v_forward;
		Vector vecSrc	 = m_pPlayer.GetGunPosition();

		float flDamage = VSW_DAMAGE;
		if( self.m_flCustomDmg > 0 ) flDamage = self.m_flCustomDmg;
		// tuned for deathmatch
		self.FireBullets( VSW_SHOTS2, vecSrc, vecAiming, vs::VECTOR_CONE_DM_DOUBLESHOTGUN, 2048, BULLET_PLAYER_CUSTOMDAMAGE, 0, int(flDamage), m_pPlayer.pev );

		// untouched default single player
		//self.FireBullets( 12, vecSrc, vecAiming, VECTOR_CONE_10DEGREES, 2048, BULLET_PLAYER_CUSTOMDAMAGE, 0, flDamage, m_pPlayer.pev );

		self.SendWeaponAnim( ANIM_SHOOT2 );
		m_pPlayer.pev.punchangle.x = -10.0;

		g_SoundSystem.EmitSoundDyn( m_pPlayer.edict(), CHAN_WEAPON, arrsSounds[SND_SHOOT2], Math.RandomFloat(0.98, 1.0), ATTN_NORM, 0, 85 + Math.RandomLong(0, 0x1f) );

		if( self.m_iClip <= 0 and m_pPlayer.m_rgAmmo(self.m_iPrimaryAmmoType) <= 0 )
			m_pPlayer.SetSuitUpdate( "!HEV_AMO0", false, 0 );

		//if( self.m_iClip != 0 ) //this causes the last shot fired to not expel shells, but why ??
		{
			m_flPumpTime = g_Engine.time + 0.45;
			m_flEjectBrass = g_Engine.time + 0.5;
		}

		self.m_flNextPrimaryAttack = self.m_flNextSecondaryAttack = g_Engine.time + VSW_TIME_DELAY2;

		if( self.m_iClip != 0 )
			self.m_flTimeWeaponIdle = g_Engine.time + 6.0;
		else
			self.m_flTimeWeaponIdle = 1.5;

		m_iInSpecialReload = 0;
	}

	void Reload()
	{
		if( m_pPlayer.m_rgAmmo(self.m_iPrimaryAmmoType) <= 0 or self.m_iClip >= VSW_MAX_CLIP )
			return;

		// don't reload until recoil is done
		if( self.m_flNextPrimaryAttack > g_Engine.time )
			return;

		if( m_iInSpecialReload == 0 )
		{
			self.SendWeaponAnim( ANIM_RELOAD_START );
			m_iInSpecialReload = 1;

			self.m_flNextPrimaryAttack = self.m_flNextSecondaryAttack = self.m_flTimeWeaponIdle = g_Engine.time + 0.6;
		}
		else if( m_iInSpecialReload == 1 )
		{
			if( self.m_flTimeWeaponIdle > g_Engine.time )
				return;

			m_iInSpecialReload = 2;

			g_SoundSystem.EmitSoundDyn( m_pPlayer.edict(), CHAN_ITEM, arrsSounds[Math.RandomLong(SND_RELOAD_INSERT1, SND_RELOAD_INSERT2)], VOL_NORM, ATTN_NORM, 0, 85 + Math.RandomLong(0, 0x1f) );

			self.SendWeaponAnim( ANIM_RELOAD_INSERT );

			self.m_flTimeWeaponIdle = g_Engine.time + 0.45;
		}
		else
		{
			m_pPlayer.SetAnimation( PLAYER_RELOAD );
			self.m_iClip++;
			m_pPlayer.m_rgAmmo( self.m_iPrimaryAmmoType, m_pPlayer.m_rgAmmo(self.m_iPrimaryAmmoType) - 1 );
			m_iInSpecialReload = 1;
		}
	}

	void WeaponIdle()
	{
		self.ResetEmptySound();

		if( self.m_flTimeWeaponIdle <  g_Engine.time )
		{
			if( self.m_iClip == 0 and m_iInSpecialReload == 0 and m_pPlayer.m_rgAmmo(self.m_iPrimaryAmmoType) > 0 )
				Reload();
			else if( m_iInSpecialReload != 0 )
			{
				if( self.m_iClip != VSW_MAX_CLIP and m_pPlayer.m_rgAmmo(self.m_iPrimaryAmmoType) > 0 )
					Reload();
				else
				{
					self.SendWeaponAnim( ANIM_RELOAD_FINISH );

					g_SoundSystem.EmitSoundDyn( m_pPlayer.edict(), CHAN_ITEM, arrsSounds[SND_RELOAD_FINISH], VOL_NORM, ATTN_NORM, 0, 95 + Math.RandomLong(0, 0x1f) );
					m_iInSpecialReload = 0;
					self.m_flTimeWeaponIdle = g_Engine.time + 1.5;
				}
			}
			else
			{
				int iAnim;
				float flRand = g_PlayerFuncs.SharedRandomFloat( m_pPlayer.random_seed, 0, 1 );

				if( flRand <= 0.8 )
				{
					iAnim = ANIM_IDLE_DEEP;
					self.m_flTimeWeaponIdle = g_Engine.time + ( 60.0 / 12.0 );
				}
				else if( flRand <= 0.95 )
				{
					iAnim = ANIM_IDLE1;
					self.m_flTimeWeaponIdle = g_Engine.time + ( 20.0 / 9.0 );
				}
				else
				{
					iAnim = ANIM_IDLE4;
					self.m_flTimeWeaponIdle = g_Engine.time + ( 20.0 / 9.0 );
				}

				self.SendWeaponAnim( iAnim );
			}
		}
	}

	void ItemPostFrame()
	{
		if( m_flPumpTime > 0 and m_flPumpTime < g_Engine.time )
		{
			g_SoundSystem.EmitSoundDyn( m_pPlayer.edict(), CHAN_ITEM, arrsSounds[SND_RELOAD_FINISH], VOL_NORM, ATTN_NORM, 0, 95 + Math.RandomLong(0, 0x1f) );

			m_flPumpTime = 0.0;
		}

		if( m_flEjectBrass > 0 and m_flEjectBrass < g_Engine.time )
		{
			for( int i = 0; i < m_iNumShots; i++ )
			{
				Vector vecOffsets = (m_iNumShots == 1) ? VSW_OFFSETS_SHELL1 : VSW_OFFSETS_SHELL2;

				Math.MakeVectors( m_pPlayer.pev.v_angle + m_pPlayer.pev.punchangle );
				Vector vecShellVelocity = m_pPlayer.pev.velocity + g_Engine.v_right * Math.RandomFloat(50, 70) + g_Engine.v_up * Math.RandomFloat(100, 150) + g_Engine.v_forward * 25;
				g_EntityFuncs.EjectBrass( pev.origin + m_pPlayer.pev.view_ofs + g_Engine.v_forward * vecOffsets.x + g_Engine.v_right * vecOffsets.y + g_Engine.v_up * vecOffsets.z, vecShellVelocity, pev.angles.y, m_iShell, TE_BOUNCE_SHOTSHELL );
			}

			m_flEjectBrass = 0.0;
		}

		BaseClass.ItemPostFrame();
	}
}

void Register()
{
	g_CustomEntityFuncs.RegisterCustomEntity( "vs_shotgun::weapon_vsshotgun", "weapon_vsshotgun" );
	g_ItemRegistry.RegisterWeapon( "weapon_vsshotgun", "vs", "vsshotgunammo" );
}

}