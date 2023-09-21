global function GamemodeTdm_Init
global function RateSpawnpoints_Directional

void function GamemodeTdm_Init()
{
	AddCallback_OnPlayerKilled( GiveScoreForPlayerKill )
	ScoreEvent_SetupEarnMeterValuesForMixedModes()
	SetTimeoutWinnerDecisionFunc( CheckScoreForDraw )

	// tempfix specifics
	SetShouldPlayDefaultMusic( true ) // play music when score or time reaches some point
	EarnMeterMP_SetPassiveGainProgessEnable( true ) // enable earnmeter gain progressing like vanilla
}

void function GiveScoreForPlayerKill( entity victim, entity attacker, var damageInfo )
{
	if ( victim != attacker 
		 && victim.IsPlayer() 
		 && IsValid( attacker ) 
		 && attacker.IsPlayer() 
		 && GetGameState() == eGameState.Playing )
	{
		AddTeamScore( attacker.GetTeam(), 1 )
		
		if ( GetGameState() == eGameState.WinnerDetermined ) // win match with AddTeamScore()
			ScoreEvent_VictoryKill( attacker )
	}
}

void function RateSpawnpoints_Directional( int checkclass, array<entity> spawnpoints, int team, entity player )
{
	// temp
	RateSpawnpoints_Generic( checkclass, spawnpoints, team, player )
}

int function CheckScoreForDraw()
{
	if ( GameRules_GetTeamScore( TEAM_IMC ) > GameRules_GetTeamScore( TEAM_MILITIA ) )
		return TEAM_IMC
	else if ( GameRules_GetTeamScore( TEAM_MILITIA ) > GameRules_GetTeamScore( TEAM_IMC ) )
		return TEAM_MILITIA

	return TEAM_UNASSIGNED
}
