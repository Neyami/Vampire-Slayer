//based on HL mp5
namespace vs_uzi
{

const int VSW_DEFAULT_GIVE			= 36;
const int VSW_MAX_CLIP 				= 36;
const int VSW_MAX_AMMO				= 108;

const int VSW_DAMAGE					= 11;
const float VSW_TIME_DELAY			= 0.1;
const float VSW_TIME_DRAW			= 0.5;
const float VSW_TIME_IDLE1			= 3.4;
const float VSW_TIME_IDLE2			= 3.4;
const float VSW_TIME_IDLE3			= 3.4;
const float VSW_TIME_IDLE4			= 1.6;
const float VSW_TIME_IDLE5			= 3.4;
const float VSW_TIME_RELOAD		= 1.7;

const string VSW_ANIMEXT				= "onehanded";
const string MODEL_VIEW				= "models/vs/weapons/v_uzi.mdl";
const string MODEL_PLAYER			= "models/vs/weapons/p_uzi.mdl";
const string MODEL_WORLD			= "models/vs/weapons/w_weaponbox.mdl";

enum anim_e
{
	ANIM_IDLE1,
	ANIM_IDLE2,
	ANIM_IDLE3,
	ANIM_IDLE4,
	ANIM_IDLE5,
	ANIM_RELOAD,
	ANIM_DRAW,
	ANIM_SHOOT1,
	ANIM_SHOOT2,
	ANIM_SHOOT3,
	ANIM_HOLSTER
};

enum sounds_e
{
	SND_SHOOT1 = 0,
	SND_SHOOT2,
	SND_EMPTY
};

const array<string> arrsSounds =
{
	"vs/weapons/uzi-1.wav",
	"vs/weapons/uzi-2.wav",
	"weapons/357_cock1.wav"
};

class weapon_vsmp5 : CBaseVSWeapon
{
	private int m_iShell;

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

		g_Game.PrecacheGeneric( "sprites/vs/weapon_vsmp5.txt" );
		g_Game.PrecacheGeneric( "sprites/vs/640hud1.spr" );
		g_Game.PrecacheGeneric( "sprites/vs/640hud4.spr" );
		g_Game.PrecacheGeneric( "sprites/vs/640hud7.spr" );
		g_Game.PrecacheGeneric( "sprites/vs/crosshairs.spr" );
		g_Game.PrecacheGeneric( "events/vs/muzzle_uzi.txt" );
	}

	bool GetItemInfo( ItemInfo& out info )
	{
		info.iMaxAmmo1	= VSW_MAX_AMMO;
		info.iMaxAmmo2	= -1;
		info.iMaxClip			= VSW_MAX_CLIP;
		info.iSlot				= vs::UZI_SLOT-1;
		info.iPosition			= vs::UZI_POSITION-1;
		info.iWeight			= vs::UZI_WEIGHT;
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
			m.WriteLong( g_ItemRegistry.GetIdForName("weapon_vsmp5") );
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
		if( m_pPlayer.pev.waterlevel == WATERLEVEL_HEAD or self.m_iClip <= 0 )
		{
			self.PlayEmptySound();
			self.m_flNextPrimaryAttack = 0.15;
			return;
		}

		m_pPlayer.m_iWeaponVolume = NORMAL_GUN_VOLUME;
		m_pPlayer.m_iWeaponFlash = NORMAL_GUN_FLASH;

		self.m_iClip--;
		self.SendWeaponAnim( Math.RandomLong(ANIM_SHOOT1, ANIM_SHOOT3) );

		m_pPlayer.pev.effects |= EF_MUZZLEFLASH;

		Math.MakeVectors( m_pPlayer.pev.v_angle + m_pPlayer.pev.punchangle );
		Vector vecAiming = g_Engine.v_forward;
		Vector vecSrc	 = m_pPlayer.GetGunPosition( );

		float flDamage = VSW_DAMAGE;
		if( self.m_flCustomDmg > 0 ) flDamage = self.m_flCustomDmg;
		// optimized multiplayer. Widened to make it easier to hit a moving player
		self.FireBullets( 1, vecSrc, vecAiming, VECTOR_CONE_6DEGREES, 8192, BULLET_PLAYER_CUSTOMDAMAGE, 2, int(flDamage), m_pPlayer.pev );

		// single player spread
		//self.FireBullets( 1, vecSrc, vecAiming, VECTOR_CONE_3DEGREES, 8192, BULLET_PLAYER_CUSTOMDAMAGE, 2, int(flDamage), m_pPlayer.pev );

		m_pPlayer.SetAnimation( PLAYER_ATTACK1 );
		m_pPlayer.pev.punchangle.x = Math.RandomFloat( -2.0, 2.0 );

		Vector vecShellVelocity = m_pPlayer.pev.velocity 
								 + g_Engine.v_right * Math.RandomFloat( 50, 70 ) 
								 + g_Engine.v_up * Math.RandomFloat( 100, 150 ) 
								 + g_Engine.v_forward * 25;

		g_EntityFuncs.EjectBrass( pev.origin + m_pPlayer.pev.view_ofs + g_Engine.v_forward * 20 + g_Engine.v_right * 4 + g_Engine.v_up * -12, vecShellVelocity, pev.angles.y, m_iShell, TE_BOUNCE_SHELL );

		g_SoundSystem.EmitSoundDyn( m_pPlayer.edict(), CHAN_WEAPON, arrsSounds[Math.RandomLong(SND_SHOOT1, SND_SHOOT2)], VOL_NORM, ATTN_NORM, 0, 94 + Math.RandomLong(0, 0xf) );

		if( self.m_iClip <= 0 and m_pPlayer.m_rgAmmo(self.m_iPrimaryAmmoType) <= 0 )
			m_pPlayer.SetSuitUpdate( "!HEV_AMO0", false, 0 );

		self.m_flNextPrimaryAttack = g_Engine.time + VSW_TIME_DELAY;
		self.m_flTimeWeaponIdle = g_Engine.time + g_PlayerFuncs.SharedRandomFloat( m_pPlayer.random_seed, 10, 15 );
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
	g_CustomEntityFuncs.RegisterCustomEntity( "vs_uzi::weapon_vsmp5", "weapon_vsmp5" );
	g_ItemRegistry.RegisterWeapon( "weapon_vsmp5", "vs", "vsmp5ammo" );
}

}