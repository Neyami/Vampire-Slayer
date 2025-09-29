/*
* Author(s): Nero
* https://www.reddit.com/r/svencoop
*
* Include this in your script/plugin.
* Modify the three lists according to your wishes. (lang_e, arrsLanguagesCodes, dicLanguageNames)
*
* Read the example language file in scripts\plugins\data\lang\localization.txt
* If your script is a map script, the file needs to be in scripts\maps\data\lang\
*
* Call lang::Initialize( "scripts/plugins/data/lang/langfile.txt" );
* in Plugin/MapInit
*
* ClientPrint( CBasePlayer@ pPlayer, HUD hud, const string &in szFormat, string &in a1 = "", ... , string &in a8 = "" )
* ClientPrintAll( CBasePlayer@ pPlayer, HUD hud, const string &in szFormat, string &in a1 = "", ... , string &in a8 = "" )
* Does what the g_PlayerFuncs functions do but with snprintf formatting.
* USE DOLLARSIGNS $ INSTEAD OF PERCENT % IN szFormat.
* Up to 8 variables, can be any data type (probably :heh:)
* eg: lang::ClientPrintAll( HUD_PRINTCENTER, "$1\n\n$2 : $3 $4 : $5", "ROUND_VAMPIRESWIN", "TITLE_SLAYER", GetTeamScore(TEAM_SLAYER), "TITLE_VAMPIRE", GetTeamScore(TEAM_VAMPIRE) );
* eg: lang::ClientPrintAll( HUD_PRINTNOTIFY, "NOTIF_STAKED", pPlayer.pev.netname, "Vampire Santa Claus" );
*
* FormatMessage( CBasePlayer@ pPlayer, string &out szOutBuffer, const string &in szFormat, string &in a1 = "", ... , string &in a8 = "" )
* Same rules as the ClientPrint functions, szOutBuffer is the resulting string.
*
* getLocalizedText( CBasePlayer@ pPlayer, const string &in sString )
* Directly access one of the entries in the language file.
* eg: teamMenu.SetTitle( lang::getLocalizedText(pPlayer, "MENU_TEAM") );
*
* getLanguageName( CBasePlayer@ pPlayer, const string &in sLanguageCode, int iNameType = LANGNAME_ENGLISH )
* iNameType look at the enum langname_e and the dictionary dicLanguageNames for the explanation.
*/

namespace lang
{

const bool DEBUG = false;

const string KVN_LANGUAGE = "$i_language";

enum langname_e
{
	LANGNAME_ENGLISH = 0,				//eg: Spanish
	LANGNAME_SELECTED,					//eg: Español
	LANGNAME_SELECTED_ENGLISH	//eg: Espanol
};

//The languages in these three lists need to be in the same order
//hardcoded (:aRage:) because it's easier
enum lang_e
{
	LANG_INVALID = -1,
	LANG_ENGLISH = 0,
	LANG_SWEDISH,
	LANG_SPANISH,
	LANG_FRENCH,
	LANG_JAPANESE
};

const array<string> arrsLanguagesCodes = 
{
	"en",
	"sv",
	"es",
	"fr",
	"ja"
};

const dictionary dicLanguageNames = 
{
	{ "en", "English" },
	{ "sv", "Swedish,Svenska,Espanol" },
	{ "es", "Spanish,Español,Espanol" },
	{ "fr", "French,Français,Francais" },
	{ "ja", "Japanese,日本語,nihongo" }
};

array<dictionary> arrdicLocalizations( arrsLanguagesCodes.length() );

bool g_bInitialized = false;

void Initialize( const string &in sLocalizationFile )
{
	if( g_bInitialized )
		return;

	ReadLocalizationFile( sLocalizationFile );

	g_bInitialized = true;
}

void ClientPrint( CBasePlayer@ pPlayer, HUD hud, const string &in szFormat, string &in a1 = "", string &in a2 = "", string &in a3 = "", string &in a4 = "", string &in a5 = "", string &in a6 = "", string &in a7 = "", string &in a8 = "" )
{
	string sMessage;
	FormatMessage( pPlayer, sMessage, szFormat, a1, a2, a3, a4, a5, a6, a7, a8 );

	g_PlayerFuncs.ClientPrint( pPlayer, hud, sMessage + "\n" );
}

void ClientPrintAll( HUD hud, const string &in szFormat, string &in a1 = "", string &in a2 = "", string &in a3 = "", string &in a4 = "", string &in a5 = "", string &in a6 = "", string &in a7 = "", string &in a8 = "" )
{
	string sMessage;

	for( int i = 1; i <= g_Engine.maxClients; i++ )
	{
		CBasePlayer@ pPlayer = g_PlayerFuncs.FindPlayerByIndex( i );

		if( pPlayer is null or !pPlayer.IsConnected() )
			continue;

		FormatMessage( pPlayer, sMessage, szFormat, a1, a2, a3, a4, a5, a6, a7, a8 );

		g_PlayerFuncs.ClientPrint( pPlayer, hud, sMessage + "\n" );
	}
}

string getLocalizedText( CBasePlayer@ pPlayer, const string &in sString )
{
	int iLanguage = GetKVInt( pPlayer, KVN_LANGUAGE );

	//default to English if the player's chosen language has no entries
	if( arrdicLocalizations[iLanguage].isEmpty() )
		iLanguage = LANG_ENGLISH;

	if( arrdicLocalizations[iLanguage].exists(sString) )
		return string( arrdicLocalizations[iLanguage][sString] );

	return sString;
}

string getStringFromLanguage( int iLanguage, const string &in sString )
{
	//default to English if the chosen language has no entries
	if( arrdicLocalizations[iLanguage].isEmpty() )
		iLanguage = LANG_ENGLISH;

	if( arrdicLocalizations[iLanguage].exists(sString) )
		return string( arrdicLocalizations[iLanguage][sString] );

	return sString;
}

string getLanguageName( CBasePlayer@ pPlayer, const string &in sLanguageCode, int iNameType = LANGNAME_ENGLISH )
{
	int iLanguage = LANG_ENGLISH;

	if( pPlayer !is null )
		iLanguage = GetKVInt( pPlayer, KVN_LANGUAGE );

	if( iLanguage != LANG_ENGLISH )
		iNameType = LANGNAME_SELECTED;

	string sString = "INVALID";

	int iFindIndex = arrsLanguagesCodes.find( sLanguageCode );
	if( iFindIndex != LANG_INVALID )
	{
		string sBuffer = string( dicLanguageNames[sLanguageCode] );

		array<string> parsed = sBuffer.Split(",");
		if( parsed.length() == 1 )
			sString = parsed[0];
		else
			sString = parsed[ Math.clamp(0, parsed.length()-1, iNameType) ];
	}

	return sString;
}

void FormatMessage( CBasePlayer@ pPlayer, string &out szOutBuffer, const string &in szFormat, string &in a1 = "", string &in a2 = "", string &in a3 = "", string &in a4 = "", string &in a5 = "", string &in a6 = "", string &in a7 = "", string &in a8 = "" )
{
    array<string> args = { a1, a2, a3, a4, a5, a6, a7, a8 };
    string result = getLocalizedText( pPlayer, szFormat );

    for( uint i = 0; i < args.length(); i++ )
    {
        string token = "$" + (i + 1);
        string value;

        if( g_Utility.IsStringInt(args[i]) )
            value = formatInt( atoi(args[i]) );
        else if( g_Utility.IsStringFloat(args[i]) )
            value = formatFloat( atof(args[i]), "f", 0, 1 );
        else if( !args[i].IsEmpty() )
            value = getLocalizedText( pPlayer, args[i] );
        else
            continue;

        result = result.Replace( token, value );
    }

    szOutBuffer = result;
}

void ReadLocalizationFile( const string &in sLocalizationFile )
{
	File@ file = g_FileSystem.OpenFile( sLocalizationFile, OpenFile::READ );

	if( file !is null and file.IsOpen() )
	{
		dictionary d_out;
		array <string> s_out;
		bool in_lang = false;
		string langCode = "";
		int iLanguageIndex = LANG_INVALID;

		while( !file.EOFReached() )
		{
			string sLine;
			file.ReadLine(sLine);
			//fix for linux
			string sFix = sLine.SubString( sLine.Length() - 1, 1 );
			if( sFix == " " or sFix == "\n" or sFix == "\r" or sFix == "\t" )
				sLine = sLine.SubString( 0, sLine.Length() - 1 );

			//comment
			if( sLine.SubString(0,2) == "//" )
				continue;

			if( sLine.IsEmpty() and in_lang )
			{
				in_lang = false;

				if( DEBUG )
					g_Game.AlertMessage( at_notice, "[LOCALIZATION DEBUG] End of lang definition for: %1\n", langCode );

				continue;
			}
			else if( sLine.StartsWith("[") and sLine.EndsWith("]") and !in_lang )
			{
				langCode = sLine.SubString( 1, sLine.Length() - 2 );

				int iFindIndex = arrsLanguagesCodes.find( langCode );
				if( iFindIndex != LANG_INVALID )
				{
					iLanguageIndex = iFindIndex;
					in_lang = true;

					if( DEBUG )
						g_Game.AlertMessage( at_notice, "[LOCALIZATION DEBUG] Start of lang definition for: %1\n", langCode );

					continue;
				}

				if( DEBUG )
					g_Game.AlertMessage( at_notice, "[LOCALIZATION DEBUG] Start of INVALID lang definition for: %1\n", langCode );

				continue;
			}
			else if( in_lang )
			{
				array<string> parsed = sLine.Split("=");
				if( parsed.length() < 2 )
				{
					if( DEBUG )
						g_Game.AlertMessage( at_notice, "[LOCALIZATION DEBUG] INVALID LINE: %1\n", sLine );

					continue;
				}

				parsed[ 0 ].Trim();
				parsed[ 1 ].Trim();
				arrdicLocalizations[iLanguageIndex][ parsed[0] ] = parsed[ 1 ];

				if( DEBUG )
					g_Game.AlertMessage( at_notice, "[LOCALIZATION DEBUG] \"%1\" = \"%2\" added to language: \"%3\"\n", parsed[0], parsed[1], langCode );
			}
		}

		file.Close();
	}
}

int GetKVInt( CBaseEntity@ pEntity, const string &in sKey )
{
	if( pEntity is null ) return 0;

	CustomKeyvalues@ pCustom = pEntity.GetCustomKeyvalues();
	CustomKeyvalue keyValue = pCustom.GetKeyvalue( sKey );

	if( keyValue.Exists() )
		return keyValue.GetInteger();

	return 0;
}

} //namespace lang END