untyped

global function MpTitanWeaponShockShield_Init

global function OnWeaponActivate_titanweapon_shock_shield
global function OnWeaponDeactivate_titanweapon_shock_shield
global function OnWeaponCustomActivityStart_titanweapon_shock_shield
global function OnWeaponVortexHitBullet_titanweapon_shock_shield
global function OnWeaponVortexHitProjectile_titanweapon_shock_shield
global function OnWeaponPrimaryAttack_titanweapon_shock_shield
global function OnWeaponChargeBegin_titanweapon_shock_shield
global function OnWeaponChargeEnd_titanweapon_shock_shield
global function OnWeaponAttemptOffhandSwitch_titanweapon_shock_shield
global function OnWeaponOwnerChanged_titanweapon_shock_shield

#if SERVER
global function OnWeaponNpcPrimaryAttack_titanweapon_shock_shield
#endif // #if SERVER

#if CLIENT
global function OnClientAnimEvent_titanweapon_shock_shield
#endif // #if CLIENT

const ACTIVATION_COST_FRAC = 0.40
const SHOCK_ARM_EFFECT_FP = $"wpn_arc_cannon_electricity_fp"
const SHOCK_ARM_EFFECT = $"wpn_arc_cannon_electricity"
const SHOCK_HOLD_EFFECT_FP = $"arcTrap_CH_arcs_large"
const SHOCK_HOLD_EFFECT = $"arcTrap_CH_arcs_large"
const SHOCK_RELEASE_EFFECT_FP = $"P_wpn_muzzleflash_epg_FP"
const SHOCK_RELEASE_EFFECT = $"P_wpn_muzzleflash_epg"

// shock shield color: keep light blue colored
const SHOCK_SHIELD_VORTEX_COLOR = < 23, 236, 236 >

const VortexIgnoreClassnames = {
	["mp_titancore_flame_wave"] = true,
	["mp_ability_grapple"] = true,
	["mp_ability_flame_wave"] = true,
	["mp_titancore_storm_core"] = true,
}


// we're now setup stuffs in mod.json, return type should be void
void function MpTitanWeaponShockShield_Init()
{
	PrecacheParticleSystem( SHOCK_HOLD_EFFECT )
	PrecacheParticleSystem( SHOCK_HOLD_EFFECT_FP )
	PrecacheParticleSystem( SHOCK_RELEASE_EFFECT )
	PrecacheParticleSystem( SHOCK_RELEASE_EFFECT_FP )
	
	PrecacheParticleSystem( $"wpn_vortex_chargingCP_titan_FP" )
	PrecacheParticleSystem( $"wpn_vortex_chargingCP_titan_FP_replay" )
	PrecacheParticleSystem( $"wpn_vortex_chargingCP_titan" )
	PrecacheParticleSystem( $"wpn_vortex_shield_impact_titan" )
	PrecacheParticleSystem( $"wpn_muzzleflash_vortex_titan_CP_FP" )

	PrecacheParticleSystem( $"wpn_vortex_chargingCP_mod_FP" )
	PrecacheParticleSystem( $"wpn_vortex_chargingCP_mod_FP_replay" )
	PrecacheParticleSystem( $"wpn_vortex_chargingCP_mod" )
	PrecacheParticleSystem( $"wpn_vortex_shield_impact_mod" )
	PrecacheParticleSystem( $"wpn_muzzleflash_vortex_mod_CP_FP" )

	PrecacheParticleSystem( $"P_elec_arc_loop_LG_1" )
	PrecacheParticleSystem( $"P_impact_exp_emp_med_air" )

	// for fd shock shield arc field, not implemented yet
	RegisterSignal( "OnShieldDestroy" )

	#if SERVER
		// adding a new damageSourceId. it's gonna transfer to client automatically
		RegisterWeaponDamageSource( "mp_titanweapon_shock_shield", "Shock Shield" )
		// modified callback in _codecallbacks.gnut
		/* // now hardcode a damageSourceId in mp_titanweapon_archon_arc_cannon.nut
		AddCallback_WeaponMod_DamageSourceIdOverride( 
			"mp_titanweapon_vortex_shield",					// weapon name
			"archon_shock_shield",							// weapon mod
			eDamageSourceId.mp_titanweapon_shock_shield		// damageSourceId override
		)
		*/

		AddDamageCallbackSourceID( eDamageSourceId.mp_titanweapon_shock_shield, ShockShieldOnDamage )
	#endif
}

void function OnWeaponOwnerChanged_titanweapon_shock_shield( entity weapon, WeaponOwnerChangedParams changeParams )
{
	if ( !( "initialized" in weapon.s ) )
	{
		weapon.s.fxChargingFPControlPoint <- $"wpn_vortex_chargingCP_titan_FP"
		weapon.s.fxChargingFPControlPointReplay <- $"wpn_vortex_chargingCP_titan_FP_replay"
		weapon.s.fxChargingControlPoint <- $"wpn_vortex_chargingCP_titan"
		weapon.s.fxBulletHit <- $"P_elec_arc_loop_LG_1" // $"wpn_vortex_shield_impact_titan"

		weapon.s.fxChargingFPControlPointBurn <- $"wpn_vortex_chargingCP_mod_FP"
		weapon.s.fxChargingFPControlPointReplayBurn <- $"wpn_vortex_chargingCP_mod_FP_replay"
		weapon.s.fxChargingControlPointBurn <- $"wpn_vortex_chargingCP_mod"
		weapon.s.fxBulletHitBurn <- $"P_elec_arc_loop_LG_1"

		weapon.s.fxElectricalExplosion <- $"P_impact_exp_emp_med_air"

		weapon.s.lastFireTime <- 0
		weapon.s.hadChargeWhenFired <- false


		#if CLIENT
			weapon.s.lastUseTime <- 0
		#endif

		weapon.s.initialized <- true
	}

	// shared from modified _vortex.nut
	// allow us add modified vortex color update
	Vortex_SetWeaponVortexColorUpdateFunc( weapon, ShockShieldColorUpdate )
}

// shock shield color: keep light blue colored
void function ShockShieldColorUpdate( entity weapon, var sphereClientFXHandle = null )
{
	weapon.EndSignal( "VortexStopping" )

	#if CLIENT
		Assert( sphereClientFXHandle != null )
	#endif

	entity weaponOwner = weapon.GetWeaponOwner()
	while( IsValid( weapon ) && IsValid( weaponOwner ) )
	{
		vector colorVec = SHOCK_SHIELD_VORTEX_COLOR

		// update the world entity that is linked to the world FX playing on the server
		#if SERVER
			weapon.s.vortexSphereColorCP.SetOrigin( colorVec )
		#else
			// handles the server killing the vortex sphere without the client knowing right away,
			//  for example if an explosive goes off and we short circuit the charge timer
			if ( !EffectDoesExist( sphereClientFXHandle ) )
				break

			EffectSetControlPointVector( sphereClientFXHandle, 1, colorVec )
		#endif

		WaitFrame()
	}
}

void function OnWeaponActivate_titanweapon_shock_shield( entity weapon )
{
	entity weaponOwner = weapon.GetWeaponOwner()

	// just for NPCs (they don't do the deploy event)
	if ( !weaponOwner.IsPlayer() )
	{
		Assert( !( "isVortexing" in weaponOwner.s ), "NPC trying to vortex before cleaning up last vortex" )
		StartVortex( weapon )
	}

	#if SERVER
		thread AmpedVortexRefireThink( weapon )
	#endif
}

void function OnWeaponDeactivate_titanweapon_shock_shield( entity weapon )
{
	EndVortex( weapon )

	weapon.Signal( "DisableAmpedVortex" )
}

void function OnWeaponCustomActivityStart_titanweapon_shock_shield( entity weapon )
{
	EndVortex( weapon )
}

function StartVortex( entity weapon )
{
	entity weaponOwner = weapon.GetWeaponOwner()

#if CLIENT
	if ( weaponOwner != GetLocalViewPlayer() )
		return

	if ( IsFirstTimePredicted() )
		Rumble_Play( "rumble_titan_vortex_start", {} )
#endif

	Assert( IsAlive( weaponOwner ),  "ent trying to start vortexing after death: " + weaponOwner )

	if ( "shotgunPelletsToIgnore" in weapon.s )
		weapon.s.shotgunPelletsToIgnore = 0
	else
		weapon.s.shotgunPelletsToIgnore <- 0

	Vortex_SetBulletCollectionOffset( weapon, Vector( 110, -28, -22.0 ) )

	int sphereRadius = 120
	int bulletFOV = 120

	//ApplyActivationCost( weapon, ACTIVATION_COST_FRAC )

	if ( weapon.GetWeaponChargeFraction() < 1 )
	{
		weapon.s.hadChargeWhenFired = true
		CreateVortexSphere( weapon, false, false, sphereRadius, bulletFOV )
		EnableVortexSphere( weapon )
		weapon.EmitWeaponSound_1p3p( "vortex_shield_loop_1P", "vortex_shield_loop_3P" )
	}
	else
	{
		weapon.s.hadChargeWhenFired = false
		weapon.EmitWeaponSound_1p3p( "vortex_shield_empty_1P", "vortex_shield_empty_3P" )
	}

	#if SERVER
		thread ForceReleaseOnPlayerEject( weapon )
	#endif

	#if CLIENT
		weapon.s.lastUseTime = Time()
	#endif
}

function AmpedVortexRefireThink( entity weapon )
{
	entity weaponOwner = weapon.GetWeaponOwner()
	weapon.EndSignal( "DisableAmpedVortex" )
	weapon.EndSignal( "OnDestroy" )
	weaponOwner.EndSignal( "OnDestroy" )

	for ( ;; )
	{
		weapon.WaitSignal( "FireAmpedVortexBullet" )

		if ( IsValid( weaponOwner )	)
		{
			ShotgunBlast( weapon, weaponOwner.EyePosition(), weaponOwner.GetPlayerOrNPCViewVector(), expect int( weapon.s.ampedBulletCount ), damageTypes.shotgun | DF_VORTEX_REFIRE )
			weapon.s.ampedBulletCount = 0
		}
	}
}

function ForceReleaseOnPlayerEject( entity weapon )
{
	weapon.EndSignal( "VortexFired" )
	weapon.EndSignal( "OnDestroy" )

	entity weaponOwner = weapon.GetWeaponOwner()
	if ( !IsAlive( weaponOwner ) )
		return

	weaponOwner.EndSignal( "OnDeath" )

	weaponOwner.WaitSignal( "TitanEjectionStarted" )

	weapon.ForceRelease()
}

function ApplyActivationCost( entity weapon, float frac )
{
	if ( weapon.HasMod( "vortex_extended_effect_and_no_use_penalty" ) )
		return

	float fracLeft = weapon.GetWeaponChargeFraction()

	if ( fracLeft + frac >= 1 )
	{
		#if SERVER
		weapon.ForceRelease()
		
		weapon.SetWeaponChargeFraction( 1.0 )
		#endif
	}
	else
	{
		#if SERVER
		weapon.SetWeaponChargeFraction( fracLeft + frac )
		#endif
	}
}

function EndVortex( entity weapon )
{
	#if CLIENT
		weapon.s.lastUseTime = Time()
	#endif
	weapon.StopWeaponSound( "vortex_shield_loop_1P" )
	weapon.StopWeaponSound( "vortex_shield_loop_3P" )
	weapon.StopWeaponEffect( SHOCK_HOLD_EFFECT_FP, SHOCK_HOLD_EFFECT )
	weapon.StopWeaponEffect( SHOCK_ARM_EFFECT_FP, SHOCK_ARM_EFFECT )
	DestroyVortexSphereFromVortexWeapon( weapon )
}

bool function OnWeaponVortexHitBullet_titanweapon_shock_shield( entity weapon, entity vortexSphere, var damageInfo )
{
	#if CLIENT
		return true
	#else
		// modified: always absorb bullets, never show them on viewmodel
		if ( !ValidateVortexImpact( vortexSphere ) )
			return false

		entity attacker				= DamageInfo_GetAttacker( damageInfo )
		vector origin				= DamageInfo_GetDamagePosition( damageInfo )
		int damageSourceID			= DamageInfo_GetDamageSourceIdentifier( damageInfo )
		entity attackerWeapon		= DamageInfo_GetWeapon( damageInfo )
		string attackerWeaponName	= attackerWeapon.GetWeaponClassName()

		local impactData = Vortex_CreateImpactEventData( weapon, attacker, origin, damageSourceID, attackerWeaponName, "hitscan" )
		VortexDrainedByImpact( weapon, attackerWeapon, null, null )
		if ( impactData.refireBehavior == VORTEX_REFIRE_ABSORB )
			return true
		// generic shield ping FX, modified to globalize this function in _vortex.nut
        //Vortex_SpawnShieldPingFX( weapon, impactData )
		// heat shield ping works too, it has a better SFX
		Vortex_SpawnHeatShieldPingFX( weapon, impactData, true )

		return true
	#endif
}

bool function OnWeaponVortexHitProjectile_titanweapon_shock_shield( entity weapon, entity vortexSphere, entity attacker, entity projectile, vector contactPos )
{
	#if CLIENT
		return true
	#else
		// modified: always absorb bullets, never show them on viewmodel
		if ( !ValidateVortexImpact( vortexSphere, projectile ) )
			return false

		int damageSourceID = projectile.ProjectileGetDamageSourceID()
		string weaponName = projectile.ProjectileGetWeaponClassName()

		local impactData = Vortex_CreateImpactEventData( weapon, attacker, contactPos, damageSourceID, weaponName, "projectile" )
		VortexDrainedByImpact( weapon, projectile, projectile, null )
		if ( impactData.refireBehavior == VORTEX_REFIRE_ABSORB )
			return true
		// generic shield ping FX, modified to globalize this function in _vortex.nut
        //Vortex_SpawnShieldPingFX( weapon, impactData )
		// heat shield ping works too, it has a better SFX
		Vortex_SpawnHeatShieldPingFX( weapon, impactData, false )

		return true
	#endif
}

var function OnWeaponPrimaryAttack_titanweapon_shock_shield( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	string attackSound1p = "Vortex_Shield_Deflect_Amped"
	string attackSound3p = "Vortex_Shield_Deflect_Amped"
	
	weapon.EmitWeaponSound_1p3p( attackSound1p, attackSound3p )
	thread OnShieldDestroyed(weapon, attackParams) 

	DestroyVortexSphereFromVortexWeapon( weapon )  // sphere ent holds networked ammo count, destroy it after predicted firing is done

	FadeOutSoundOnEntity( weapon, "vortex_shield_start_amped_1P", 0.15 )
	FadeOutSoundOnEntity( weapon, "vortex_shield_start_amped_3P", 0.15 )

	return true
}


#if SERVER
var function OnWeaponNpcPrimaryAttack_titanweapon_shock_shield( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	DestroyVortexSphereFromVortexWeapon( weapon )  // sphere ent holds networked ammo count, destroy it after predicted firing is done

	return FireArchonCannon( weapon, attackParams ) // fix npc titan fire arc
}
#endif // #if SERVER

#if CLIENT
void function OnClientAnimEvent_titanweapon_shock_shield( entity weapon, string name )
{
	if ( name == "muzzle_flash" )
	{
		asset fpEffect
		if ( weapon.GetWeaponSettingBool( eWeaponVar.is_burn_mod ) )
			fpEffect = $"wpn_muzzleflash_vortex_mod_CP_FP"
		else
			fpEffect = $"wpn_muzzleflash_vortex_titan_CP_FP"

		int handle
		if ( GetLocalViewPlayer() == weapon.GetWeaponOwner() )
		{
			handle = weapon.PlayWeaponEffectReturnViewEffectHandle( fpEffect, $"", "vortex_center" )
		}
		else
		{
			handle = StartParticleEffectOnEntity( weapon, GetParticleSystemIndex( fpEffect ), FX_PATTACH_POINT_FOLLOW, weapon.LookupAttachment( "vortex_center" ) )
		}

		Assert( handle )
		// This Assert isn't valid because Effect might have been culled
		// Assert( EffectDoesExist( handle ), "vortex shield OnClientAnimEvent: Couldn't find viewmodel effect handle for vortex muzzle flash effect on client " + GetLocalViewPlayer() )

		vector colorVec = GetVortexSphereCurrentColor( weapon.GetWeaponChargeFraction() )
		EffectSetControlPointVector( handle, 1, colorVec )
	}
}
#endif

bool function OnWeaponChargeBegin_titanweapon_shock_shield( entity weapon )
{
	entity weaponOwner = weapon.GetWeaponOwner()

	// just for players
	if ( weaponOwner.IsPlayer() )
	{
		PlayerUsedOffhand( weaponOwner, weapon )
		StartVortex( weapon )
	}

	weapon.PlayWeaponEffect( SHOCK_ARM_EFFECT_FP, SHOCK_ARM_EFFECT, "vortex_center")
	weapon.PlayWeaponEffect( SHOCK_HOLD_EFFECT_FP, SHOCK_HOLD_EFFECT, "vortex_center")
	weapon.PlayWeaponEffect( SHOCK_HOLD_EFFECT_FP, SHOCK_HOLD_EFFECT, "vortex_center")
	weapon.EmitWeaponSound("EMP_Titan_Electrical_Field")

	return true
}


void function OnWeaponChargeEnd_titanweapon_shock_shield( entity weapon )
{
	entity owner = weapon.GetWeaponOwner()
	owner.Signal( "OnShieldDestroy" )

	float activationCost = ACTIVATION_COST_FRAC

	if ( weapon.HasMod( "bolt_from_the_blue" ) )
	{
			activationCost = activationCost * 0.75
	}

	ApplyActivationCost( weapon, activationCost )

	entity weaponOwner = weapon.GetWeaponOwner()
	weapon.StopWeaponEffect( SHOCK_HOLD_EFFECT_FP, SHOCK_HOLD_EFFECT )
	weapon.StopWeaponEffect( SHOCK_ARM_EFFECT_FP, SHOCK_ARM_EFFECT )
	weapon.StopWeaponSound("EMP_Titan_Electrical_Field")

}

bool function OnWeaponAttemptOffhandSwitch_titanweapon_shock_shield( entity weapon )
{

	bool allowSwitch
	entity weaponOwner = weapon.GetWeaponOwner()
	entity soul = weaponOwner.GetTitanSoul()
	Assert( IsValid( soul ) )
	entity activeWeapon = weaponOwner.GetActiveWeapon()

	float activationCost = ACTIVATION_COST_FRAC

	if ( weapon.HasMod( "bolt_from_the_blue" ) )
	{
			activationCost = activationCost * 0.75
	}

	allowSwitch = weapon.GetWeaponChargeFraction() <= 1 - activationCost

	return allowSwitch
}

function OnShieldDestroyed(entity weapon, WeaponPrimaryAttackParams attackParams)
{
	entity player = weapon.GetWeaponOwner()
	FireArchonCannon( weapon, attackParams )

	weapon.PlayWeaponEffect( SHOCK_RELEASE_EFFECT_FP, SHOCK_RELEASE_EFFECT, "vortex_center")
	weapon.StopWeaponSound( "vortex_shield_loop_1P" )
	weapon.StopWeaponSound( "vortex_shield_loop_3P" )
	weapon.StopWeaponEffect( SHOCK_HOLD_EFFECT_FP, SHOCK_HOLD_EFFECT )
	weapon.StopWeaponEffect( SHOCK_ARM_EFFECT_FP, SHOCK_ARM_EFFECT )
}

void function ShockShieldOnDamage( entity ent, var damageInfo )
{
	vector pos = DamageInfo_GetDamagePosition( damageInfo )
	entity attacker = DamageInfo_GetAttacker( damageInfo )
	vector origin = DamageInfo_GetDamagePosition( damageInfo )

	if ( ent.IsPlayer() || ent.IsNPC() )
	{
		entity entToSlow = ent
		entity soul = ent.GetTitanSoul()

		if ( soul != null )
			entToSlow = soul

		if ( DamageInfo_GetDamage( damageInfo ) <= 0 )
			return

		const ARC_TITAN_EMP_DURATION			= 0.35
		const ARC_TITAN_EMP_FADEOUT_DURATION	= 0.35


		StatusEffect_AddTimed( entToSlow, eStatusEffect.move_slow, 0.5, 1.0, 1.0 )
		StatusEffect_AddTimed( entToSlow, eStatusEffect.dodge_speed_slow, 0.5, 1.0, 1.0 )
		StatusEffect_AddTimed( ent, eStatusEffect.emp, 1.0, ARC_TITAN_EMP_DURATION, ARC_TITAN_EMP_FADEOUT_DURATION )
	}

	if ( false )//ent.IsPlayer() || ent.IsNPC() )
	{
		entity entToSlow = ent
		entity soul = ent.GetTitanSoul()

		if ( soul != null )
			entToSlow = soul

		entity weapon = attacker.GetOffhandWeapon(OFFHAND_SPECIAL)

		if (!IsValid(entToSlow))
			return
		StatusEffect_AddTimed( entToSlow, eStatusEffect.move_slow, 0.5, 1.0, 1.0 )
		StatusEffect_AddTimed( entToSlow, eStatusEffect.dodge_speed_slow, 0.5, 1.0, 1.0 )
		
		const ARC_TITAN_EMP_DURATION			= 0.35
		const ARC_TITAN_EMP_FADEOUT_DURATION	= 0.35

		StatusEffect_AddTimed( entToSlow, eStatusEffect.emp, 0.25, ARC_TITAN_EMP_DURATION, ARC_TITAN_EMP_FADEOUT_DURATION )


		//print("ENEMY: " + ent)
		//print("USER: " + attacker)


		

	}
}
