#include "weapons/vsbaseweapon"
//#include "weapons/weapon_vsbike"

#include "weapons/weapon_vsclaw"
#include "weapons/weapon_vsstake"
#include "weapons/weapon_vscolt"
#include "weapons/weapon_vscue"

#include "weapons/weapon_vsmp5"
#include "weapons/weapon_vsshotgun"
#include "weapons/weapon_vsthunderfive"

#include "weapons/weapon_vsdbshotgun"
#include "weapons/weapon_vswinchester"
#include "weapons/weapon_vscrossbow"

namespace vs
{

//irrelevant, but needed ??
//const int BIKE_SLOT						= 5;
//const int BIKE_POSITION				= 16;
//const int BIKE_WEIGHT					= 42;

const int CLAW_SLOT						= 1;
const int CLAW_POSITION				= 10;
const int CLAW_WEIGHT					= 0;
const int STAKE_SLOT					= 1;
const int STAKE_POSITION				= 11;
const int STAKE_WEIGHT				= 0;
const int COLT_SLOT						= 1;
const int COLT_POSITION				= 12;
const int COLT_WEIGHT					= 0;
const int CUE_SLOT						= 1;
const int CUE_POSITION					= 13;
const int CUE_WEIGHT					= 0;

const int UZI_SLOT						= 3;
const int UZI_POSITION					= 11;
const int UZI_WEIGHT					= 0;
const int SHOTGUN_SLOT				= 3;
const int SHOTGUN_POSITION		= 12;
const int SHOTGUN_WEIGHT			= 10;
const int THUNDER5_SLOT				= 3;
const int THUNDER5_POSITION		= 13;
const int THUNDER5_WEIGHT			= 10;

const int DBSHOTGUN_SLOT			= 4;
const int DBSHOTGUN_POSITION	= 11;
const int DBSHOTGUN_WEIGHT		= 5;
const int WINCHESTER_SLOT			= 4;
const int WINCHESTER_POSITION	= 12;
const int WINCHESTER_WEIGHT		= 10;
const int CROSSBOW_SLOT			= 4;
const int CROSSBOW_POSITION		= 13;
const int CROSSBOW_WEIGHT		= 10;

void RegisterWeapons()
{
	//vs_bike::Register();

	vs_claw::Register();
	vs_stake::Register();
	vs_colt::Register();
	vs_cue::Register();

	vs_uzi::Register();
	vs_shotgun::Register();
	vs_thunderfive::Register();

	vs_dbshotgun::Register();
	vs_winchester::Register();
	vs_crossbow::Register();
}

} //namespace vs END