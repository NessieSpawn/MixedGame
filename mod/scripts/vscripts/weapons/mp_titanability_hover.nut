global function MpTitanAbilityHover_Init
global function OnWeaponOwnerChanged_TitanHover // for jet pack
global function OnWeaponPrimaryAttack_TitanHover
const LERP_IN_FLOAT = 0.5

#if SERVER
global function NPC_OnWeaponPrimaryAttack_TitanHover
global function FlyerHovers
#endif

void function MpTitanAbilityHover_Init()
{
	PrecacheParticleSystem( $"P_xo_jet_fly_large" )
	PrecacheParticleSystem( $"P_xo_jet_fly_small" )

	// modified conents
	#if SERVER
		// to end last hover before activating another one
		RegisterSignal( "VTOLHoverBegin" )
	#endif
}

// note: owner dying also triggers OwnerChanged
void function OnWeaponOwnerChanged_TitanHover( entity weapon, WeaponOwnerChangedParams changeParams )
{
#if SERVER
	if( weapon.HasMod( JET_PACK_MOD ) )
		thread DelayedCheckJetPack( weapon, changeParams ) // in case we're using AddMod()
#endif
}

#if SERVER
void function DelayedCheckJetPack( entity weapon, WeaponOwnerChangedParams changeParams )
{
	WaitFrame()
	if( !IsValid( weapon ) )
		return
	if( weapon.HasMod( JET_PACK_MOD ) )
	{
		if ( IsValid( changeParams.newOwner ) )
		{
			entity player
			if( changeParams.newOwner.IsPlayer() )
				player = changeParams.newOwner
			if( !IsValid( player ) )
				return
			thread JetPackThink( player, weapon )
		}
	}
}
#endif

var function OnWeaponPrimaryAttack_TitanHover( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	entity flyer = weapon.GetWeaponOwner()
	if ( !IsAlive( flyer ) )
		return

	if ( flyer.IsPlayer() )
	{
		if( weapon.HasMod( JET_PACK_MOD ) ) // so player won't consume ammo
		{
			#if SERVER
				SendHudMessage(flyer, "喷气背包为被动技能\n跳跃耗尽后再次按下跳跃以使用", -1, -0.3, 255, 255, 100, 255, 0, 2, 0)
			#endif
			return 0
		}

		PlayerUsedOffhand( flyer, weapon )
	}

	bool hasPasFlightCore = false

	entity soul = flyer.GetTitanSoul()
	
	if( IsValid( soul ) )
	{
		#if SERVER
			if( SoulHasPassive( soul, ePassives.PAS_NORTHSTAR_FLIGHTCORE ) )
				hasPasFlightCore = true
		#endif
		foreach( entity offhand in flyer.GetOffhandWeapons() )
		{
			if ( !IsValid( offhand ) )
				continue
			if( offhand.GetWeaponClassName() == "mp_titanability_hover" )
			{
				if( offhand.HasMod( "pas_northstar_flightcore" ) )
					hasPasFlightCore = true
			}
		}
	}

	#if SERVER

		HoverSounds soundInfo
		soundInfo.liftoff_1p = "titan_flight_liftoff_1p"
		soundInfo.liftoff_3p = "titan_flight_liftoff_3p"
		soundInfo.hover_1p = "titan_flight_hover_1p"
		soundInfo.hover_3p = "titan_flight_hover_3p"
		soundInfo.descent_1p = "titan_flight_descent_1p"
		soundInfo.descent_3p = "titan_flight_descent_3p"
		soundInfo.landing_1p = "core_ability_land_1p"
		soundInfo.landing_3p = "core_ability_land_3p"
		float horizontalVelocity
		if( hasPasFlightCore )
			horizontalVelocity = 350.0
		else
			horizontalVelocity = 250.0
		// adding weapon as parameter to handle stuffs better
		//thread FlyerHovers( flyer, soundInfo, 3.0, horizontalVelocity )
		thread FlyerHovers( flyer, soundInfo, 3.0, horizontalVelocity, weapon )
	#endif

	return weapon.GetWeaponSettingInt( eWeaponVar.ammo_per_shot )
}

#if SERVER

var function NPC_OnWeaponPrimaryAttack_TitanHover( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	OnWeaponPrimaryAttack_TitanHover( weapon, attackParams )
}

// adding weapon as parameter to handle stuffs better
//void function FlyerHovers( entity player, HoverSounds soundInfo, float flightTime = 3.0, float horizVel = 200.0 )
void function FlyerHovers( entity player, HoverSounds soundInfo, float flightTime = 3.0, float horizVel = 200.0, entity weapon = null )
{
	// fixes
	bool hasHoveringFix = bool( GetCurrentPlaylistVarInt( "vtol_hover_fix", 0 ) )
	if ( IsValid( weapon ) && weapon.HasMod( "vtol_hover_fix" ) )
		hasHoveringFix = true

	// prevent multiple hovering to be used together
	if ( hasHoveringFix )
	{
		player.Signal( "VTOLHoverBegin" )
		player.EndSignal( "VTOLHoverBegin" )
		if ( IsValid( weapon ) )
			weapon.EndSignal( "OnDestroy" ) // shall we??
	}

	player.EndSignal( "OnDeath" )
	player.EndSignal( "TitanEjectionStarted" )

	thread AirborneThink( player, soundInfo )

	if ( player.IsPlayer() )
	{
		player.Server_TurnDodgeDisabledOn()
	    player.kv.airSpeed = horizVel
	    player.kv.airAcceleration = 540
	    player.kv.gravity = 0.0
	}

	CreateShake( player.GetOrigin(), 16, 150, 1.00, 400 )
	PlayFX( FLIGHT_CORE_IMPACT_FX, player.GetOrigin() )

	float startTime = Time()

	array<entity> activeFX

	player.SetGroundFrictionScale( 0 )

	OnThreadEnd(
		function() : ( activeFX, player, soundInfo )
		{
			if ( IsValid( player ) )
			{
				StopSoundOnEntity( player, soundInfo.hover_1p )
				StopSoundOnEntity( player, soundInfo.hover_3p )
				// using custom utility!
				//player.SetGroundFrictionScale( 1 )
				if ( player.IsPlayer() )
				{
					player.Server_TurnDodgeDisabledOff()
					// modified to use saved settings
					//player.kv.airSpeed = player.GetPlayerSettingsField( "airSpeed" )
					//player.kv.airAcceleration = player.GetPlayerSettingsField( "airAcceleration" )
					//player.kv.gravity = player.GetPlayerSettingsField( "gravityScale" )
					RestorePlayerPermanentGroundFriction( player )
					RestorePlayerPermanentAirSpeed( player )
					RestorePlayerPermanentAirAcceleration( player )
					RestorePlayerPermanentGravity( player )

					if ( player.IsOnGround() )
					{
						EmitSoundOnEntityOnlyToPlayer( player, player, soundInfo.landing_1p )
						EmitSoundOnEntityExceptToPlayer( player, player, soundInfo.landing_3p )
					}
				}
				else
				{
					if ( player.IsOnGround() )
						EmitSoundOnEntity( player, soundInfo.landing_3p )
				}
			}

			foreach ( fx in activeFX )
			{
				if ( IsValid( fx ) )
					fx.Destroy()
			}
		}
	)

	// fix visual stuffs
	if ( player.LookupAttachment( "FX_L_BOT_THRUST" ) != 0 ) // BT doesn't have this attachment
	{
		/*
		activeFX.append( StartParticleEffectOnEntity_ReturnEntity( player, GetParticleSystemIndex( $"P_xo_jet_fly_large" ), FX_PATTACH_POINT_FOLLOW, player.LookupAttachment( "FX_L_BOT_THRUST" ) ) )
		activeFX.append( StartParticleEffectOnEntity_ReturnEntity( player, GetParticleSystemIndex( $"P_xo_jet_fly_large" ), FX_PATTACH_POINT_FOLLOW, player.LookupAttachment( "FX_R_BOT_THRUST" ) ) )
		activeFX.append( StartParticleEffectOnEntity_ReturnEntity( player, GetParticleSystemIndex( $"P_xo_jet_fly_small" ), FX_PATTACH_POINT_FOLLOW, player.LookupAttachment( "FX_L_TOP_THRUST" ) ) )
		activeFX.append( StartParticleEffectOnEntity_ReturnEntity( player, GetParticleSystemIndex( $"P_xo_jet_fly_small" ), FX_PATTACH_POINT_FOLLOW, player.LookupAttachment( "FX_R_TOP_THRUST" ) ) )
		*/

		// use better function to hide effect from their owner
		activeFX.append( CreateTitanHoverJetEffect( player, $"P_xo_jet_fly_large", "FX_L_BOT_THRUST" ) )
		activeFX.append( CreateTitanHoverJetEffect( player, $"P_xo_jet_fly_large", "FX_R_BOT_THRUST" ) )
		activeFX.append( CreateTitanHoverJetEffect( player, $"P_xo_jet_fly_small", "FX_L_TOP_THRUST" ) )
		activeFX.append( CreateTitanHoverJetEffect( player, $"P_xo_jet_fly_small", "FX_R_TOP_THRUST" ) )
	}
	else if( IsPilot( player ) && player.LookupAttachment( "vent_center" ) != 0 ) // modified: pilot jet effect
	{
		activeFX.append( CreateTitanHoverJetEffect( player, $"P_xo_jet_fly_small", "vent_center" ) )
		activeFX.append( CreateTitanHoverJetEffect( player, $"P_xo_jet_fly_large", "vent_left_back" ) )
		activeFX.append( CreateTitanHoverJetEffect( player, $"P_xo_jet_fly_large", "vent_right_back" ) )
	}
	// to keep behavior consist as npcs: no effect for other titan models?
	/*
	else if ( player.LookupAttachment( "thrust" ) != 0 ) // modified: non-northstar titans jet effect
	{
		activeFX.append( CreateTitanHoverJetEffect( player, $"P_xo_jet_fly_small", "thrust" ) )
		activeFX.append( CreateTitanHoverJetEffect( player, $"P_xo_jet_fly_large", "vent_left" ) )
		activeFX.append( CreateTitanHoverJetEffect( player, $"P_xo_jet_fly_large", "vent_right" ) )
	}
	*/
	ArrayRemoveInvalid( activeFX ) // we may have failed creating effects due to attachments, better handle like this!

	EmitSoundOnEntityOnlyToPlayer( player, player,  soundInfo.liftoff_1p )
	EmitSoundOnEntityExceptToPlayer( player, player, soundInfo.liftoff_3p )
	EmitSoundOnEntityOnlyToPlayer( player, player,  soundInfo.hover_1p )
	EmitSoundOnEntityExceptToPlayer( player, player, soundInfo.hover_3p )

	float RISE_VEL = 450
	float movestunEffect = 1.0 - StatusEffect_Get( player, eStatusEffect.dodge_speed_slow )

	entity soul = player.GetTitanSoul()
	if ( soul == null )
		soul = player

	float fadeTime = 0.75
	StatusEffect_AddTimed( soul, eStatusEffect.dodge_speed_slow, 0.65, flightTime + fadeTime, fadeTime )

	vector startOrigin = player.GetOrigin()

	for ( ;; )
	{
		float timePassed = Time() - startTime
		if ( timePassed > flightTime )
			break

		float height

		// modified: adding a stall hovering height to make it more stable
		// nah this doesn't working fine, vanilla works good enough
		/*
		if ( hasHoveringFix )
		{
			if ( timePassed < LERP_IN_FLOAT )
				height = RISE_VEL
			else
				height = 70
		}
		else // vanilla behavior
		{
		*/	
			if ( timePassed < LERP_IN_FLOAT )
				height = GraphCapped( timePassed, 0, LERP_IN_FLOAT, RISE_VEL * 0.5, RISE_VEL )
			else
				height = GraphCapped( timePassed, LERP_IN_FLOAT, LERP_IN_FLOAT + 0.75, RISE_VEL, 70 )
		//}	

		height *= movestunEffect

		vector vel = player.GetVelocity()
		vel.z = height
		vel = LimitVelocityHorizontal( vel, horizVel + 50 )
		player.SetVelocity( vel )
		WaitFrame()
	}

	vector endOrigin = player.GetOrigin()

	// printt( endOrigin - startOrigin )
	EmitSoundOnEntityOnlyToPlayer( player, player, soundInfo.descent_1p )
	EmitSoundOnEntityExceptToPlayer( player, player, soundInfo.descent_3p )
}

// modified function for better handling hover effects
entity function CreateTitanHoverJetEffect( entity owner, asset effectName, string attachment )
{
	if( owner.LookupAttachment( attachment ) > 0 )
    {
		entity jetFX = StartParticleEffectOnEntity_ReturnEntity( owner, GetParticleSystemIndex( effectName ), FX_PATTACH_POINT_FOLLOW, owner.LookupAttachment( attachment ) )
		jetFX.SetOwner( owner )
		jetFX.kv.VisibilityFlags = ENTITY_VISIBLE_TO_FRIENDLY | ENTITY_VISIBLE_TO_ENEMY
		return jetFX
	}

	// failed to create due to bad attachment!
	return null
}
//

void function AirborneThink( entity player, HoverSounds soundInfo )
{
	player.EndSignal( "OnDeath" )
	player.EndSignal( "TitanEjectionStarted" )
	player.EndSignal( "DisembarkingTitan" )

	if ( player.IsPlayer() )
		player.SetTitanDisembarkEnabled( false )

	OnThreadEnd(
	function() : ( player )
		{
			if ( IsValid( player ) && player.IsPlayer() )
				player.SetTitanDisembarkEnabled( true )
		}
	)
	wait 0.1

	while( !player.IsOnGround() )
	{
		wait 0.1
	}

	if ( player.IsPlayer() )
	{
		EmitSoundOnEntityOnlyToPlayer( player, player, soundInfo.landing_1p )
		EmitSoundOnEntityExceptToPlayer( player, player, soundInfo.landing_3p )
	}
	else
	{
		EmitSoundOnEntity( player, soundInfo.landing_3p )
	}
}

vector function LimitVelocityHorizontal( vector vel, float speed )
{
	vector horzVel = <vel.x, vel.y, 0>
	if ( Length( horzVel ) <= speed )
		return vel

	horzVel = Normalize( horzVel )
	horzVel *= speed
	vel.x = horzVel.x
	vel.y = horzVel.y
	return vel
}
#endif // SERVER
