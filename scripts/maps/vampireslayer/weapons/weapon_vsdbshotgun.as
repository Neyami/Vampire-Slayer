//based on HL shotgun
namespace vs_dbshotgun
{

const int VSW_DEFAULT_GIVE				= 2;
const int VSW_MAX_CLIP 					= 2;
const int VSW_MAX_AMMO					= 32;

const int VSW_DAMAGE						= 50;
const float VSW_TIME_DRAW				= 0.5;
const float VSW_TIME_IDLE1				= 2.6;
const float VSW_TIME_IDLE2				= 2.6;
const float VSW_TIME_IDLE3				= 2.6;
const float VSW_TIME_IDLE4				= 4.2;
const float VSW_TIME_RELOAD			= 1.7;

const string VSW_ANIMEXT					= "shotgun";
const string MODEL_VIEW					= "models/vs/weapons/v_dbshotgun.mdl";
const string MODEL_PLAYER				= "models/vs/weapons/p_dbshotgun.mdl";
const string MODEL_WORLD				= "models/vs/weapons/w_weaponbox.mdl";

const Vector VSW_SPREAD					= VECTOR_CONE_3DEGREES;
															//VECTOR_CONE_10DEGREES // regular old, untouched spread. 
															//vs::VECTOR_CONE_DM_SHOTGUN //multiplayer spread

const Vector VSW_OFFSETS_SHELL_L	= Vector( 14.344878, 3.083264, -2.482792 );
const Vector VSW_OFFSETS_SHELL_R	= Vector( 14.384326, 4.382496, -2.461832 );

enum anim_e
{
	ANIM_IDLE1,
	ANIM_IDLE2,
	ANIM_IDLE3,
	ANIM_IDLE4,
	ANIM_SHOOT1,
	ANIM_SHOOT2,
	ANIM_SHOOT3,
	ANIM_RELOAD_L,
	ANIM_RELOAD_R,
	ANIM_RELOAD_B,
	ANIM_RELOAD_FINISH,
	ANIM_RELOAD_START,
	ANIM_DRAW,
	ANIM_HOLSTER
};

enum sounds_e
{
	SND_SHOOT = 0,
	SND_RELOAD_START,
	SND_RELOAD_INSERT1,
	SND_RELOAD_INSERT2,
	SND_RELOAD_FINISH,
	SND_EMPTY
};
//reload1.wav or reload3.wav when expelling both shells and then inserting
//only 1 of the sounds when reloading one barrel
const array<string> arrsSounds =
{
	"vs/weapons/dbshotgun1.wav",
	"vs/weapons/dbopen.wav",
	"hlclassic/weapons/reload1.wav",
	"vs/weapons/reload3.wav",
	"vs/weapons/dbclose.wav",
	"weapons/357_cock1.wav"
};

enum reload_e
{
	RELOAD_NONE = -1,
	RELOAD_LEFT_START,
	RELOAD_LEFT_FINISH,
	RELOAD_RIGHT_START,
	RELOAD_RIGHT_FINISH,
	RELOAD_BOTH_START,
	RELOAD_BOTH_MID,
	RELOAD_BOTH_FINISH
};

class weapon_vsdbshotgun : CBaseVSWeapon
{
	private int m_iShell;
	private bool m_bFiredLeft, m_bFiredRight;
	private float m_flNextReloadStage;

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

		g_Game.PrecacheGeneric( "sprites/vs/weapon_vsdbshotgun.txt" );
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
		info.iSlot				= vs::DBSHOTGUN_SLOT-1;
		info.iPosition			= vs::DBSHOTGUN_POSITION-1;
		info.iWeight			= vs::DBSHOTGUN_WEIGHT;
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
			m.WriteLong( g_ItemRegistry.GetIdForName("weapon_vsdbshotgun") );
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
		m_flEjectBrass = 0.0;
		m_iInSpecialReload = RELOAD_NONE;
		m_flNextReloadStage = 0.0;

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
		FireShotgun();
	}

	void SecondaryAttack()
	{
		FireShotgun( false );
	}

	void FireShotgun( bool bLeft = true )
	{
		if( (bLeft and m_bFiredLeft) or (!bLeft and m_bFiredRight) )
			return;

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

		if( bLeft ) m_bFiredLeft = true;
		if( !bLeft ) m_bFiredRight = true;

		m_iNumShots++;

		m_pPlayer.m_iWeaponVolume = LOUD_GUN_VOLUME;
		m_pPlayer.m_iWeaponFlash = NORMAL_GUN_FLASH;

		self.m_iClip--;

		m_pPlayer.pev.effects |= EF_MUZZLEFLASH;
		m_pPlayer.SetAnimation( PLAYER_ATTACK1 );

		Math.MakeVectors( m_pPlayer.pev.v_angle );
		Vector vecAiming = g_Engine.v_forward;
		Vector vecSrc	 = m_pPlayer.GetGunPosition();

		float flDamage = VSW_DAMAGE;
		if( self.m_flCustomDmg > 0 ) flDamage = self.m_flCustomDmg;

		
		self.FireBullets( 1, vecSrc, vecAiming, VSW_SPREAD, 2048, BULLET_PLAYER_CUSTOMDAMAGE, 0, int(flDamage), m_pPlayer.pev );

		self.SendWeaponAnim( ANIM_SHOOT1 );
		m_pPlayer.pev.punchangle.x = -5.0;

		g_SoundSystem.EmitSoundDyn( m_pPlayer.edict(), CHAN_WEAPON, arrsSounds[SND_SHOOT], VOL_NORM, ATTN_NORM, 0, 85 + Math.RandomLong(0, 0x1f) );

		if( self.m_iClip <= 0 and m_pPlayer.m_rgAmmo(self.m_iPrimaryAmmoType) <= 0 )
			m_pPlayer.SetSuitUpdate( "!HEV_AMO0", false, 0 );

		self.m_flNextPrimaryAttack = self.m_flNextSecondaryAttack = 0.0;

		if( self.m_iClip != 0 )
			self.m_flTimeWeaponIdle = g_Engine.time + 5.0;
		else
			self.m_flTimeWeaponIdle = g_Engine.time + 0.75;

		m_iInSpecialReload = RELOAD_NONE;
	}

	void Reload()
	{
		if( m_pPlayer.m_rgAmmo(self.m_iPrimaryAmmoType) <= 0 or self.m_iClip >= VSW_MAX_CLIP )
			return;

		if( m_iInSpecialReload == RELOAD_NONE )
		{
			self.SendWeaponAnim( ANIM_RELOAD_START );
			g_SoundSystem.EmitSound( m_pPlayer.edict(), CHAN_ITEM, arrsSounds[SND_RELOAD_START], VOL_NORM, ATTN_NORM );

			if( m_bFiredLeft and m_bFiredRight )
				m_iInSpecialReload = RELOAD_BOTH_START;
			else if( m_bFiredLeft )
				m_iInSpecialReload = RELOAD_LEFT_START;
			else if( m_bFiredRight )
				m_iInSpecialReload = RELOAD_RIGHT_START;

			m_flNextReloadStage = g_Engine.time + 0.6;
			self.m_flNextPrimaryAttack = self.m_flNextSecondaryAttack = self.m_flTimeWeaponIdle = g_Engine.time + 1.5;
		}
	}

	void WeaponIdle()
	{
		self.ResetEmptySound();

		if( self.m_flTimeWeaponIdle > g_Engine.time )
			return;

		float flIdleTime;
		int iAnim = Math.RandomLong( ANIM_IDLE1, ANIM_IDLE4 );
		self.SendWeaponAnim( iAnim );

		switch( iAnim )
		{
			case ANIM_IDLE1: flIdleTime = VSW_TIME_IDLE1; break;
			case ANIM_IDLE2: flIdleTime = VSW_TIME_IDLE2; break;
			case ANIM_IDLE3: flIdleTime = VSW_TIME_IDLE3; break;
			case ANIM_IDLE4: flIdleTime = VSW_TIME_IDLE4; break;
		}

		self.m_flTimeWeaponIdle = g_Engine.time + (flIdleTime + Math.RandomFloat(3.0, (flIdleTime*4)));
	}

	void ItemPreFrame()
	{
		if( m_iInSpecialReload != RELOAD_NONE )
		{
			if( m_flNextReloadStage > 0 and m_flNextReloadStage <= g_Engine.time )
			{
				switch( m_iInSpecialReload )
				{
					case RELOAD_LEFT_START:
					{
						self.SendWeaponAnim( ANIM_RELOAD_L );
						m_flEjectBrass = g_Engine.time + 0.2;
						m_flNextReloadStage = g_Engine.time + 0.92;
						m_iInSpecialReload = RELOAD_LEFT_FINISH;
						self.m_flNextPrimaryAttack = self.m_flNextSecondaryAttack = self.m_flTimeWeaponIdle = g_Engine.time + 1.5;

						break;
					}

					case RELOAD_LEFT_FINISH:
					{
						m_pPlayer.SetAnimation( PLAYER_RELOAD );
						self.m_iClip++;
						m_pPlayer.m_rgAmmo( self.m_iPrimaryAmmoType, m_pPlayer.m_rgAmmo(self.m_iPrimaryAmmoType) - 1 );
						self.SendWeaponAnim( ANIM_RELOAD_FINISH );
						g_SoundSystem.EmitSound( m_pPlayer.edict(), CHAN_ITEM, arrsSounds[SND_RELOAD_FINISH], VOL_NORM, ATTN_NORM );

						m_flNextReloadStage = 0.0;
						m_iInSpecialReload = RELOAD_NONE;
						m_bFiredLeft = false;

						self.m_flNextPrimaryAttack = self.m_flNextSecondaryAttack = g_Engine.time + 0.6;
						self.m_flTimeWeaponIdle = g_Engine.time + 3.0;

						break;
					}

					case RELOAD_RIGHT_START:
					{
						self.SendWeaponAnim( ANIM_RELOAD_R );
						m_flEjectBrass = g_Engine.time + 0.2;
						m_flNextReloadStage = g_Engine.time + 0.92;
						m_iInSpecialReload = RELOAD_RIGHT_FINISH;
						self.m_flNextPrimaryAttack = self.m_flNextSecondaryAttack = self.m_flTimeWeaponIdle = g_Engine.time + 1.5;

						break;
					}

					case RELOAD_RIGHT_FINISH:
					{
						m_pPlayer.SetAnimation( PLAYER_RELOAD );
						self.m_iClip++;
						m_pPlayer.m_rgAmmo( self.m_iPrimaryAmmoType, m_pPlayer.m_rgAmmo(self.m_iPrimaryAmmoType) - 1 );
						self.SendWeaponAnim( ANIM_RELOAD_FINISH );
						g_SoundSystem.EmitSound( m_pPlayer.edict(), CHAN_ITEM, arrsSounds[SND_RELOAD_FINISH], VOL_NORM, ATTN_NORM );

						m_flNextReloadStage = 0.0;
						m_iInSpecialReload = RELOAD_NONE;
						m_bFiredRight = false;

						self.m_flNextPrimaryAttack = self.m_flNextSecondaryAttack = g_Engine.time + 0.6;
						self.m_flTimeWeaponIdle = g_Engine.time + 3.0;

						break;
					}

					case RELOAD_BOTH_START:
					{
						self.SendWeaponAnim( ANIM_RELOAD_B );
						m_flEjectBrass = g_Engine.time + 0.2;
						m_flNextReloadStage = g_Engine.time + 0.7;
						m_iInSpecialReload = RELOAD_BOTH_MID;
						self.m_flNextPrimaryAttack = self.m_flNextSecondaryAttack = self.m_flTimeWeaponIdle = g_Engine.time + 1.5;

						break;
					}

					case RELOAD_BOTH_MID:
					{
						m_pPlayer.SetAnimation( PLAYER_RELOAD );
						self.m_iClip++;
						m_pPlayer.m_rgAmmo( self.m_iPrimaryAmmoType, m_pPlayer.m_rgAmmo(self.m_iPrimaryAmmoType) - 1 );
						m_flNextReloadStage = g_Engine.time + 0.36;
						m_iInSpecialReload = RELOAD_BOTH_FINISH;
						m_bFiredLeft = false;

						self.m_flNextPrimaryAttack = self.m_flNextSecondaryAttack = self.m_flTimeWeaponIdle = g_Engine.time + 3.0;

						break;
					}

					case RELOAD_BOTH_FINISH:
					{
						m_pPlayer.SetAnimation( PLAYER_RELOAD );
						self.m_iClip++;
						m_pPlayer.m_rgAmmo( self.m_iPrimaryAmmoType, m_pPlayer.m_rgAmmo(self.m_iPrimaryAmmoType) - 1 );
						self.SendWeaponAnim( ANIM_RELOAD_FINISH );
						g_SoundSystem.EmitSound( m_pPlayer.edict(), CHAN_ITEM, arrsSounds[SND_RELOAD_FINISH], VOL_NORM, ATTN_NORM );

						m_flNextReloadStage = 0.0;
						m_iInSpecialReload = RELOAD_NONE;
						m_bFiredRight = false;

						self.m_flNextPrimaryAttack = self.m_flNextSecondaryAttack = g_Engine.time + 0.6;
						self.m_flTimeWeaponIdle = g_Engine.time + 3.0;

						break;
					}
				}
			}
		}

		if( m_flEjectBrass > 0 and m_flEjectBrass < g_Engine.time )
		{
			Math.MakeVectors( m_pPlayer.pev.v_angle + m_pPlayer.pev.punchangle );

			if( m_bFiredLeft and m_bFiredRight )
			{
				EjectLeftShell( true );
				EjectRightShell( true );
			}
			else if( m_bFiredLeft )
				EjectLeftShell();
			else if( m_bFiredRight )
				EjectRightShell();

			m_flEjectBrass = 0.0;
			m_iNumShots = 0;
		}

		BaseClass.ItemPreFrame();
	}

	void EjectLeftShell( bool bBoth = false )
	{
		Vector vecOffsets = VSW_OFFSETS_SHELL_L;

		Vector vecShellVelocity = m_pPlayer.pev.velocity + g_Engine.v_forward * -25 + g_Engine.v_right * Math.RandomFloat(-100, -150);
		if( bBoth )
			vecShellVelocity = m_pPlayer.pev.velocity + g_Engine.v_forward * -70 + g_Engine.v_right * Math.RandomFloat(50, 70);

		g_EntityFuncs.EjectBrass( pev.origin + m_pPlayer.pev.view_ofs + g_Engine.v_forward * vecOffsets.x + g_Engine.v_right * vecOffsets.y + g_Engine.v_up * vecOffsets.z, vecShellVelocity, pev.angles.y, m_iShell, TE_BOUNCE_SHOTSHELL );
	}

	void EjectRightShell( bool bBoth = false )
	{
		Vector vecOffsets = VSW_OFFSETS_SHELL_R;

		Vector vecShellVelocity = m_pPlayer.pev.velocity + g_Engine.v_forward * -70 + g_Engine.v_right * Math.RandomFloat(50, 70) + g_Engine.v_up * Math.RandomFloat(50, 70);
		if( bBoth )
			vecShellVelocity = m_pPlayer.pev.velocity + g_Engine.v_forward * -70 + g_Engine.v_right * Math.RandomFloat(50, 70);

		g_EntityFuncs.EjectBrass( pev.origin + m_pPlayer.pev.view_ofs + g_Engine.v_forward * vecOffsets.x + g_Engine.v_right * vecOffsets.y + g_Engine.v_up * vecOffsets.z, vecShellVelocity, pev.angles.y, m_iShell, TE_BOUNCE_SHOTSHELL );
	}
}

void Register()
{
	g_CustomEntityFuncs.RegisterCustomEntity( "vs_dbshotgun::weapon_vsdbshotgun", "weapon_vsdbshotgun" );
	g_ItemRegistry.RegisterWeapon( "weapon_vsdbshotgun", "vs", "vsdbshotgunammo" );
}

}