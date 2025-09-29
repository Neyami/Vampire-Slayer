class CBaseVSWeapon : ScriptBasePlayerWeaponEntity
{
	// Possible workaround for the SendWeaponAnim() access violation crash.
	// According to R4to0 this seems to provide at least some improvement.
	// GeckoN: TODO: Remove this once the core issue is addressed.
	protected CBasePlayer@ m_pPlayer
	{
		get const { return cast<CBasePlayer@>(self.m_hPlayer.GetEntity()); }
		set { self.m_hPlayer = EHandle(@value); }
	}

	float m_flEjectBrass;
	int m_iInSpecialReload;
	int m_iNumShots;

	private bool m_bWeaponThrown;

	//Prevent weapon from being dropped manually, not needed with mp_dropweapons 0, but Slayers should still drop their weapons upon death
	CBasePlayerItem@ DropItem() { return null; }

	void Think()
	{
		if( self.GetClassname() == "weapon_vsclaw" )
		{
			//weapon has been dropped upon death
			if( !vs::HasFlags(pev.effects, EF_NODRAW) )
			{
				g_EntityFuncs.Remove( self );
				return;
			}
		}
		else
		{
			//throw the weapon away from the corpse so it doesn't interfere with feeding
			if( !vs::HasFlags(pev.effects, EF_NODRAW) and !m_bWeaponThrown )
			{
				Vector vecAiming = Vector( Math.RandomFloat(1, 360), Math.RandomFloat(1, 360), 250 );
				Math.MakeVectors( vecAiming );
				pev.velocity = vecAiming.Normalize() + g_Engine.v_forward * 210;

				m_bWeaponThrown = true;
			}
		}

		BaseClass.Think();
	}
}