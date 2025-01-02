// this file is compeletely different from cl__gunship.nut, it's more like titan stuffs

global function ClGunship_MixedGame_Init

void function ClGunship_MixedGame_Init( asset gunship_model )
{
	// allow server turning off
    bool enableServerLoopingEffects = GetCurrentPlaylistVarInt( "gunship_server_effects", 0 ) == 1

	// played by server
	/*
	ModelFX_BeginData( "thrusters", gunship_model, "all", true )
		//----------------------
		// Thrusters
		//----------------------
		ModelFX_AddTagSpawnFX( "L_exhaust_rear_1", $"veh_hornet_jet_full" )
		ModelFX_AddTagSpawnFX( "L_exhaust_front_1", $"veh_hornet_jet_full" )

		ModelFX_AddTagSpawnFX( "R_exhaust_rear_1", $"veh_hornet_jet_full" )
		ModelFX_AddTagSpawnFX( "R_exhaust_front_1", $"veh_hornet_jet_full" )
	ModelFX_EndData()
	*/


	ModelFX_BeginData( "gunshipDamage", gunship_model, "all", true )
		//----------------------
		// Health effects
		//----------------------
		// played by server
		/*
		ModelFX_AddTagHealthFX( 0.80, "L_exhaust_front_1", $"P_veh_crow_exp_sml", true )
		ModelFX_AddTagHealthFX( 0.75, "R_exhaust_front_1", $"P_veh_crow_exp_sml", true )
		ModelFX_AddTagHealthFX( 0.50, "L_exhaust_front_1", $"P_veh_crow_exp_sml", true )
		ModelFX_AddTagHealthFX( 0.25, "R_exhaust_front_1", $"P_veh_crow_exp_sml", true )
		*/
	
		if ( !enableServerLoopingEffects )
		{
			ModelFX_AddTagHealthFX( 0.80, "L_exhaust_rear_1", $"xo_health_smoke_white", false )
			ModelFX_AddTagHealthFX( 0.75, "R_exhaust_rear_1", $"xo_health_smoke_white", false )

			ModelFX_AddTagHealthFX( 0.66, "L_exhaust_rear_1", $"P_sup_spectre_dam_1", false )
			ModelFX_AddTagHealthFX( 0.66, "R_exhaust_rear_1", $"P_sup_spectre_dam_1", false )

			ModelFX_AddTagHealthFX( 0.33, "L_exhaust_front_1", $"P_sup_spectre_dam_2", false )
			ModelFX_AddTagHealthFX( 0.33, "R_exhaust_front_1", $"P_sup_spectre_dam_2", false )

			ModelFX_AddTagHealthFX( 0.40, "L_exhaust_rear_1", $"xo_health_smoke_black", false )
			ModelFX_AddTagHealthFX( 0.35, "R_exhaust_rear_1", $"xo_health_smoke_black", false )
		}
	ModelFX_EndData()
}