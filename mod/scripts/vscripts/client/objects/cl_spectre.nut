global function ClSpectre_Init

struct
{
	table <asset,bool> initialized
} file

void function ClSpectre_Init()
{
	AddCreateCallback( "npc_spectre", CreateCallback_Spectre )

	RegisterSignal( "SpectreGlowEYEGLOW" )

	PrecacheParticleSystem( $"P_spectre_eye_foe" )
	PrecacheParticleSystem( $"P_spectre_eye_friend" )

	// modified: init model effects for speicific model
	Cl_SpectreModel_Init( $"models/Robots/spectre/imc_spectre.mdl" )
}

void function CreateCallback_Spectre( entity spectre )
{
	AddAnimEvent( spectre, "create_dataknife", CreateThirdPersonDataKnife )
	spectre.DoBodyGroupChangeScriptCallback( true, spectre.FindBodyGroup( "removableHead" ) )

	// why is respawn always using create callbacks for non-titan npcs to init model effects?
	// that means first npc never receive model effects
	// maybe to reduce load till this kind of npc's first time spawn?
	// spectres works better because they will init different model(tf|1 leftover I think), but I'd like to init them manually though
	/*
	asset model = spectre.GetModelName()
	if ( model in file.initialized )
		return
	file.initialized[ model ] <- true

	//----------------------
	// model Lights - Friend
	//----------------------
	ModelFX_BeginData( "friend_lights", model, "friend", true )
		ModelFX_HideFromLocalPlayer()
		ModelFX_AddTagSpawnFX( "EYEGLOW",		$"P_spectre_eye_friend" )
	ModelFX_EndData()

	//----------------------
	// model Lights - Foe
	//----------------------
	ModelFX_BeginData( "foe_lights", model, "foe", true )
		ModelFX_HideFromLocalPlayer()
		ModelFX_AddTagSpawnFX( "EYEGLOW",		$"P_spectre_eye_foe" )
	ModelFX_EndData()
	*/
}

// modified function for init model effects
void function Cl_SpectreModel_Init( asset model_name )
{
	//----------------------
	// model Lights - Friend
	//----------------------
	ModelFX_BeginData( "friend_lights", model, "friend", true )
		ModelFX_HideFromLocalPlayer()
		ModelFX_AddTagSpawnFX( "EYEGLOW",		$"P_spectre_eye_friend" )
	ModelFX_EndData()

	//----------------------
	// model Lights - Foe
	//----------------------
	ModelFX_BeginData( "foe_lights", model, "foe", true )
		ModelFX_HideFromLocalPlayer()
		ModelFX_AddTagSpawnFX( "EYEGLOW",		$"P_spectre_eye_foe" )
	ModelFX_EndData()
}