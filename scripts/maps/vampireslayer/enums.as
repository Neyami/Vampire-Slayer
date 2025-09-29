namespace vs
{

const string TEAMNAME_SLAYER = "SLAYER";
const string TEAMNAME_VAMPIRE = "VAMPIRE";

enum vsteams_e
{
	TEAM_NONE = 0,
	TEAM_VAMPIRE = 2, // red color
	TEAM_SLAYER = 4 // green color
};

enum vsclasses_e
{
	CLASS_NOCLASS = 0,
	CLASS_VAMP_LOUIS,
	CLASS_VAMP_EDGAR,
	CLASS_VAMP_NINA,
	CLASS_HUMAN_FATHER,
	CLASS_HUMAN_EIGHTBALL,
	CLASS_HUMAN_MOLLY
};

const string MDL_VAMP_EDGAR						= "models/player/edgar/edgar.mdl";
const string MDL_VAMP_LOUIS						= "models/player/louis/louis.mdl";
const string MDL_VAMP_NINA							= "models/player/nina/nina.mdl";
const string MDL_HUMAN_FATHER					= "models/player/fatherd/fatherd.mdl";
const string MDL_HUMAN_MOLLY					= "models/player/molly/molly.mdl";
const string MDL_HUMAN_EIGHTBALL				= "models/player/eightball/eightball.mdl";
const string MDL_HUMAN_FATHER_NH				= "models/player/fatherd_decap/fatherd_decap.mdl";
const string MDL_HUMAN_MOLLY_NH				= "models/player/molly_decap/molly_decap.mdl";
const string MDL_HUMAN_EIGHTBALL_NH		= "models/player/eightball_decap/eightball_decap.mdl";
const string MDL_HUMAN_FATHER_HEAD			= "models/vs/fatherd_head.mdl"; //the original model crashes the game :aRage:
const string MDL_HUMAN_MOLLY_HEAD			= "models/vs/w_mh.mdl";
const string MDL_HUMAN_EIGHTBALL_HEAD	= "models/vs/w_eh.mdl";
const string MDL_BIKE_EDGAR						= "models/player/bike_edgar/bike_edgar.mdl";
const string MDL_BIKE_LOUIS							= "models/player/bike_louis/bike_louis.mdl";
const string MDL_BIKE_NINA							= "models/player/bike_nina/bike_nina.mdl";
const string MDL_BIKE_FATHER						= "models/player/bike_fatherd/bike_fatherd.mdl";
const string MDL_BIKE_MOLLY						= "models/player/bike_molly/bike_molly.mdl";
const string MDL_BIKE_EIGHTBALL					= "models/player/bike_eightball/bike_eightball.mdl";

const string KVN_TEAM = "$i_vsteam";
const string KVN_CLASS = "$i_vsclass";
const string KVN_KNOCKOUT = "$i_vsknockout"; //g_HasToBeKnockOut
const string KVN_ISKNOCKEDOUT = "$i_vsko"; //g_bIsKnockOut
const string KVN_KNOCKOUTTIME = "$f_vskot"; //g_KnockOutTime
const string KVN_KNOCKOUTENDTIME = "$f_vskoet"; //g_KnockOutEndTime
const string KVN_WAKEUPHEALTH = "$f_vswuh"; //g_WakeUpHealth
const string KVN_CREATECORPSE = "$i_vscc";
const string KVN_PLAYERMODEL = "$s_vspm";
const string KVN_NEXTDRINKSOUND = "$f_vsnds"; //g_NextDrinkSound
const string KVN_NEXTDRINKHEAL = "$f_vsndh";
const string KVN_FALLSOUNDPLAYED = "$i_vsfsp"; //g_FallSoundPlayed
const string KVN_SENDTOSPEC = "$i_vssts"; //g_SendToSpecVictim
const string KVN_CANOPENMENU = "$i_vscom";


// Server supports up to 32 teams, but client's scoreboard is hardcoded up to 10.
const int HL_MAX_TEAMS								= 10;
//const int HL_TEAMNAME_LENGTH					= 16;
const int HL_MAX_TEAMNAME_LENGTH			= 16;
const int HL_MAX_WEAPON_SLOTS					= 6;
const int HL_MAX_TEAMLIST_LENGTH				= 512;

const Vector VECTOR_CONE_DM_SHOTGUN = Vector( 0.08716, 0.04362, 0.0 ); //10 degrees by 5 degrees
const Vector VECTOR_CONE_DM_DOUBLESHOTGUN = Vector( 0.17365, 0.04362, 0.0 ); //20 degrees by 5 degrees

} //namespace vs END