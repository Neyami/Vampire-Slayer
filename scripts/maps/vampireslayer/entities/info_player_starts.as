namespace vs_playerstart
{

class info_player_vsstart : ScriptBaseEntity
{
	void Spawn()
	{
		g_EntityFuncs.SetOrigin( self, pev.origin );

		CreatePlayerDeathmatch();

		g_EntityFuncs.Remove( self );
	}

	void CreatePlayerDeathmatch()
	{
		dictionary keys;

		keys[ "origin" ] = pev.origin.ToString();
		keys[ "angles" ] = pev.angles.ToString();
		keys[ "netname" ] = self.GetClassname() == "info_player_slayer" ? "team1" : "team2";

		g_EntityFuncs.CreateEntity( "info_player_deathmatch", keys, true );
	}
}

void Register()
{
	g_CustomEntityFuncs.RegisterCustomEntity( "vs_playerstart::info_player_vsstart", "info_player_slayer" );
	g_CustomEntityFuncs.RegisterCustomEntity( "vs_playerstart::info_player_vsstart", "info_player_vampire" );
}

} //end of namespace vs_playerstart