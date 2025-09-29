//based on HL crowbar
namespace vs_stake
{

const int VSW_DAMAGE					= 30;
const float VSW_TIME_DELAY			= 0.5;
const float VSW_TIME_DRAW			= 0.5;
const float VSW_TIME_IDLE1			= 3.4;
const float VSW_TIME_IDLE2			= 3.1;
const float VSW_TIME_IDLE3			= 3.35;
const float VSW_TIME_IDLE4			= 2.05;

const string VSW_ANIMEXT				= "crowbar";
const string MODEL_VIEW				= "models/vs/weapons/v_stake.mdl";
const string MODEL_PLAYER			= "models/vs/weapons/p_stake.mdl";
const string MODEL_WORLD			= "models/vs/weapons/w_weaponbox.mdl";

const int HUD_CHANNEL_POWER	= 2;
const float HUD_DRAINRATE			= 0.5;
const float HUD_CHARGERATE			= 0.5;
const int HUD_LEFT						= 40;
const int HUD_TOP							= 24;
const int HUD_WIDTH						= 40;
const int HUD_HEIGHT					= 40;
const int HUD_LEFT_EMPTY				= 0;
const int HUD_TOP_EMPTY				= 24;
const int HUD_WIDTH_EMPTY			= 40;
const int HUD_HEIGHT_EMPTY		= 40;

const float POWER_TIME					= 5.0;
const float POWER_CHARGE			= 30.0;
const int POWER_MAX					= HUD_HEIGHT;

enum anim_e
{
	ANIM_IDLE1 = 0,
	ANIM_IDLE2,
	ANIM_IDLE3,
	ANIM_IDLE4,
	ANIM_DRAW,
	ANIM_HOLSTER,
	ANIM_ATTACK1HIT,
	ANIM_ATTACK1MISS,
	ANIM_ATTACK2HIT,
	ANIM_ATTACK2MISS,
	ANIM_ATTACK3HIT,
	ANIM_ATTACK3MISS,
	ANIM_PRAY
};

enum sounds_e
{
	SND_HIT1 = 0,
	SND_HIT2,
	SND_HITBOD1,
	SND_HITBOD2,
	SND_HITBOD3,
	SND_MISS,
	SND_PRAY1,
	SND_PRAY2,
	SND_PRAY3,
	SND_PRAY4,
	SND_PRAY5,
	SND_PRAY6
};

const array<string> arrsSounds =
{
	"vs/weapons/cbar_hit1.wav",
	"vs/weapons/cbar_hit2.wav",
	"weapons/cbar_hitbod1.wav",
	"weapons/cbar_hitbod2.wav",
	"weapons/cbar_hitbod3.wav",
	"weapons/cbar_miss1.wav",
	"vs/weapons/latin1.wav",
	"vs/weapons/latin2.wav",
	"vs/weapons/latin3.wav",
	"vs/weapons/latin4.wav",
	"vs/weapons/latin5.wav",
	"vs/weapons/latin6.wav"
};

class weapon_vsstake : CBaseVSWeapon
{
	int m_iSwing;
	TraceResult m_trHit;

	bool m_bInvulOn;
	private float m_flInvulTime;
	private float m_flInvulNextThink;
	private float m_flInvulThinkRate;
	private int m_iPower;

	private HUDSpriteParams m_hudParamsPower;

	void Spawn()
	{
		Precache();
		g_EntityFuncs.SetModel( self, MODEL_WORLD );
		self.m_iClip = WEAPON_NOCLIP;
		self.m_flCustomDmg = pev.dmg;

		m_iPower = POWER_MAX;
		SetHudParamsPower();

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

		g_Game.PrecacheGeneric( "sprites/vs/weapon_vsstake.txt" );
		g_Game.PrecacheGeneric( "sprites/vs/640hud1.spr" );
		g_Game.PrecacheGeneric( "sprites/vs/640hud4.spr" );
	}

	bool GetItemInfo( ItemInfo& out info )
	{
		info.iMaxAmmo1	= -1;
		info.iMaxAmmo2	= -1;
		info.iMaxClip			= WEAPON_NOCLIP;
		info.iSlot				= vs::STAKE_SLOT-1;
		info.iPosition			= vs::STAKE_POSITION-1;
		info.iWeight			= vs::STAKE_WEIGHT;
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
			m.WriteLong( g_ItemRegistry.GetIdForName("weapon_vsstake") );
		m.End();

		return true;
	}

	bool Deploy()
	{
		bool bResult;
		{
			bResult = self.DefaultDeploy( self.GetV_Model(MODEL_VIEW), self.GetP_Model(MODEL_PLAYER), ANIM_DRAW, VSW_ANIMEXT );
			self.m_flTimeWeaponIdle = self.m_flNextPrimaryAttack = self.m_flNextSecondaryAttack = g_Engine.time + VSW_TIME_DRAW;

			ShowPowerBar();

			return bResult;
		}
	}

	void Holster( int skiplocal )
	{
		SetThink( null );
		//m_bInvulOn = false;
		//m_flInvulTime = 0.0;
		//m_flInvulNextThink = 0.0;
		//m_flInvulThinkRate = 0.0;

		g_PlayerFuncs.HudToggleElement( m_pPlayer, HUD_CHANNEL_POWER, false );

		BaseClass.Holster( skiplocal );
	}

	void PrimaryAttack()
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

		if( tr.flFraction >= 1.0 )
		{
			switch( (m_iSwing++) % 3 )
			{
				case 0: self.SendWeaponAnim( ANIM_ATTACK1MISS ); break;
				case 1: self.SendWeaponAnim( ANIM_ATTACK2MISS ); break;
				case 2: self.SendWeaponAnim( ANIM_ATTACK3MISS ); break;
			}

			self.m_flNextPrimaryAttack = g_Engine.time + VSW_TIME_DELAY;
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

			float flDamage = VSW_DAMAGE;
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
				self.m_flNextPrimaryAttack = g_Engine.time + VSW_TIME_DELAY; //uncomment this and remove the other instance of this line below to fix the insane attack speed on dead mobs

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
			//self.m_flNextPrimaryAttack = g_Engine.time + (VSW_TIME_DELAY * 0.5); //uncomment this and remove the other instance of this line above to enable the insane attack speed on dead mobs
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
		if( m_bInvulOn or m_iPower < POWER_MAX )
		{
			self.m_flNextSecondaryAttack = g_Engine.time + 0.25;
			return;
		}

		self.SendWeaponAnim( ANIM_PRAY );
		g_SoundSystem.EmitSound( m_pPlayer.edict(), CHAN_VOICE, arrsSounds[SND_PRAY1 + Math.RandomLong(0, 5)], VOL_NORM, ATTN_NORM );

		//m_pPlayer.pev.flags |= FL_GODMODE; //TEMP
		m_bInvulOn = true;
		m_flInvulTime = g_Engine.time + POWER_TIME;
		m_hudParamsPower.color1 = RGBA_WHITE;
		ShowPowerBar();

		self.m_flNextPrimaryAttack = self.m_flNextSecondaryAttack = g_Engine.time + 3.05;
		//self.m_flNextSecondaryAttack = g_Engine.time + POWER_CHARGE;
		self.m_flTimeWeaponIdle = g_Engine.time + 5.0;
	}

	void WeaponIdle()
	{
		self.ResetEmptySound();

		if( self.m_flTimeWeaponIdle > g_Engine.time )
			return;

		int iAnim;
		float flNextIdle;
		float flRand = Math.RandomFloat( 0.0, 1.0 );

		if( flRand <= 0.8 )
		{
			iAnim = ANIM_IDLE2;
			flNextIdle = 5.4;
		}
		else if( flRand <= 0.9 )
		{
			iAnim = ANIM_IDLE1;
			flNextIdle = 2.7;
		}
		else
		{
			iAnim = ANIM_IDLE3;
			flNextIdle = 5.4;
		}

		self.SendWeaponAnim( iAnim );
		self.m_flTimeWeaponIdle = g_Engine.time + flNextIdle;

		/*float flIdleTime;
		int iAnim = Math.RandomLong( ANIM_IDLE1, ANIM_IDLE4 );
		self.SendWeaponAnim( iAnim );

		switch( iAnim )
		{
			case ANIM_IDLE1: flIdleTime = VSW_TIME_IDLE1; break;
			case ANIM_IDLE2: flIdleTime = VSW_TIME_IDLE2; break;
			case ANIM_IDLE3: flIdleTime = VSW_TIME_IDLE3; break;
			case ANIM_IDLE4: flIdleTime = VSW_TIME_IDLE4; break;
		}

		self.m_flTimeWeaponIdle = g_Engine.time + (flIdleTime + Math.RandomFloat(3.0, (flIdleTime*4)));*/
	}

	void ItemPostFrame()
	{
		PowerThink( true );

		BaseClass.ItemPostFrame();
	}

	void InactiveItemPreFrame()
	{
		if( m_pPlayer.IsAlive() )
			PowerThink( false );

		BaseClass.InactiveItemPreFrame();
	}

	void PowerThink( bool bActive )
	{
		if( m_flInvulNextThink > 0.0 and m_flInvulNextThink <= g_Engine.time )
		{
			//g_Game.AlertMessage( at_notice, "PowerThink bActive: %1\n", bActive );
			if( !m_bInvulOn and m_iPower < POWER_MAX )
			{
				//m_hudParamsPower.y += 0.0005; //TESTING keeping the icon in the same place instead of growing upwards
				m_iPower++;
				m_flInvulNextThink = g_Engine.time + m_flInvulThinkRate;

				if( bActive )
					ShowPowerBar();
			}
			else if( m_flInvulNextThink > 0.0 )
			{
				m_flInvulNextThink = 0.0;
				m_flInvulThinkRate = 0.0;
				SetHudParamsPower();

				if( bActive )
					ShowPowerBar();
			}
		}

		if( m_bInvulOn and m_flInvulTime < g_Engine.time )
		{
			//m_pPlayer.pev.flags &= ~FL_GODMODE; //TEMP
			m_bInvulOn = false;
			m_flInvulTime = 0.0;
			m_flInvulNextThink = g_Engine.time;
			m_flInvulThinkRate = ( POWER_CHARGE / POWER_MAX );
			m_iPower = 1;
			m_hudParamsPower.color1 = RGBA_RED;
			//m_hudParamsPower.y = 0.95; //TESTING keeping the icon in the same place instead of growing upwards

			if( bActive )
				ShowPowerBar();
		}
	}

	void ShowPowerBar()
	{
		m_hudParamsPower.height = m_iPower;
		//g_PlayerFuncs.HudToggleElement( m_pPlayer, HUD_CHANNEL_POWER, false ); //should this be used ??
		g_PlayerFuncs.HudCustomSprite( m_pPlayer, m_hudParamsPower );
	}

	void SetHudParamsPower()
	{
		m_hudParamsPower.channel = HUD_CHANNEL_POWER;
		m_hudParamsPower.flags = HUD_ELEM_SCR_CENTER_X | HUD_ELEM_DEFAULT_ALPHA;
		m_hudParamsPower.spritename = "invul_full";
		m_hudParamsPower.x = 0.85; //ammo icon
		m_hudParamsPower.y = 1.0;
		m_hudParamsPower.left = HUD_LEFT;
		m_hudParamsPower.top = HUD_TOP;
		m_hudParamsPower.width = HUD_WIDTH;
		m_hudParamsPower.height = POWER_MAX;
		m_hudParamsPower.color1 = RGBA_RED;
	}
}

void Register()
{
	g_CustomEntityFuncs.RegisterCustomEntity( "vs_stake::weapon_vsstake", "weapon_vsstake" );
	g_ItemRegistry.RegisterWeapon( "weapon_vsstake", "vs" );
}

}