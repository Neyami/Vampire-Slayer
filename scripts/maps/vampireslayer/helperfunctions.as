namespace vs
{

void SetKV( CBaseEntity@ pEntity, const string &in sKey, const int &in iValue )
{
	if( pEntity is null ) return;

	CustomKeyvalues@ pCustom = pEntity.GetCustomKeyvalues();
	pCustom.SetKeyvalue( sKey, iValue );
}

void SetKV( CBaseEntity@ pEntity, const string &in sKey, const float &in flValue )
{
	if( pEntity is null ) return;

	CustomKeyvalues@ pCustom = pEntity.GetCustomKeyvalues();
	pCustom.SetKeyvalue( sKey, flValue );
}

void SetKV( CBaseEntity@ pEntity, const string &in sKey, const string &in sValue )
{
	if( pEntity is null ) return;

	g_EntityFuncs.DispatchKeyValue( pEntity.edict(), sKey, sValue );
	//Using this will CRASH the game when retrieving the CKV :aRage:
	//CustomKeyvalues@ pCustom = pEntity.GetCustomKeyvalues();
	//pCustom.SetKeyvalue( sKey, sValue );
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

float GetKVFloat( CBaseEntity@ pEntity, const string &in sKey )
{
	if( pEntity is null ) return 0.0;

	CustomKeyvalues@ pCustom = pEntity.GetCustomKeyvalues();
	CustomKeyvalue keyValue = pCustom.GetKeyvalue( sKey );

	if( keyValue.Exists() )
		return keyValue.GetFloat();

	return 0.0;
}

string GetKVString( CBaseEntity@ pEntity, const string &in sKey )
{
	if( pEntity is null ) return "";

	CustomKeyvalues@ pCustom = pEntity.GetCustomKeyvalues();
	CustomKeyvalue keyValue = pCustom.GetKeyvalue( sKey );

	if( keyValue.Exists() )
	{
		string sKeyValue = keyValue.GetString();
		return sKeyValue;
	}

	return "";
}

Vector GetKVVector( CBaseEntity@ pEntity, const string &in sKey )
{
	if( pEntity is null ) return g_vecZero;

	CustomKeyvalues@ pCustom = pEntity.GetCustomKeyvalues();
	CustomKeyvalue keyValue = pCustom.GetKeyvalue( sKey );

	if( keyValue.Exists() )
		return keyValue.GetVector();

	return g_vecZero;
}

bool HasFlags( int iFlagVariable, int iFlags )
{
	return (iFlagVariable & iFlags) != 0;
}

} //namespace vs END