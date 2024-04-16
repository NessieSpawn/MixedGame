global function MpTitanWeaponLaserLite_Init

global function OnWeaponAttemptOffhandSwitch_titanweapon_laser_lite
global function OnWeaponPrimaryAttack_titanweapon_laser_lite

#if SERVER
global function OnWeaponNPCPrimaryAttack_titanweapon_laser_lite
#endif

// modified callbacks
// currently hardcoded "gunner_bison_laser"
global function OnWeaponOwnerChanged_titanweapon_laser_lite

// "gunner_bison_laser"
const float GUNNER_BISON_LASER_REGEN_RATE = 60
const float GUNNER_BISON_LASER_REGEN_DELAY = 1.0
const int GUNNER_BISON_LASER_ENERGY_TOTAL = 550 // one laser shot

void function MpTitanWeaponLaserLite_Init()
{
	#if SERVER
		AddDamageCallbackSourceID( eDamageSourceId.mp_titanweapon_laser_lite, LaserLite_DamagedTarget )
	#endif
}

bool function OnWeaponAttemptOffhandSwitch_titanweapon_laser_lite( entity weapon )
{
	// wrap into function
	/*
	entity owner = weapon.GetWeaponOwner()
	int curCost = weapon.GetWeaponCurrentEnergyCost()
	bool canUse = owner.CanUseSharedEnergy( curCost )

	#if CLIENT
		if ( !canUse )
			FlashEnergyNeeded_Bar( curCost )
	#endif
	return canUse
	*/

	return CanUseLaserLite( weapon )
}

// new wrapped function
bool function CanUseLaserLite( entity weapon )
{
	entity owner = weapon.GetWeaponOwner()
	int curCost = weapon.GetWeaponCurrentEnergyCost()
	bool canUse = owner.CanUseSharedEnergy( curCost )

	#if CLIENT
		if ( !canUse )
			FlashEnergyNeeded_Bar( curCost )
	#endif

	return canUse
}

var function OnWeaponPrimaryAttack_titanweapon_laser_lite( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	// misc fix version here: make it failed to fire if no enough energy
	if ( bool( GetCurrentPlaylistVarInt( "laser_lite_fix", 0 ) ) || weapon.HasMod( "laser_lite_fix" ) )
	{
		entity weaponOwner = weapon.GetWeaponOwner()
		// does not affect using during execution!
		if ( !weaponOwner.Anim_IsActive() )
		{
			if ( !CanUseLaserLite( weapon ) )
			{
				#if CLIENT
					// manual dryfire event
					entity viewPlayer = GetLocalViewPlayer()
					if ( IsValid( viewPlayer ) )
						EmitSoundOnEntity( viewPlayer, string( weapon.GetWeaponInfoFileKeyField( "sound_dryfire" ) ) )
				#endif
				return 0
			}
		}
	}

	#if CLIENT
		if ( !weapon.ShouldPredictProjectiles() )
			return 1
	#endif

	entity weaponOwner = weapon.GetWeaponOwner()
	if ( weaponOwner.IsPlayer() )
		PlayerUsedOffhand( weaponOwner, weapon )

	ShotgunBlast( weapon, attackParams.pos, attackParams.dir, 1, DF_GIB | DF_EXPLOSION )
	weapon.EmitWeaponNpcSound( LOUD_WEAPON_AI_SOUND_RADIUS_MP, 0.2 )
	weapon.SetWeaponChargeFractionForced(1.0)
	return 1
}
#if SERVER
var function OnWeaponNPCPrimaryAttack_titanweapon_laser_lite( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	return OnWeaponPrimaryAttack_titanweapon_laser_lite( weapon, attackParams )
}

void function LaserLite_DamagedTarget( entity target, var damageInfo )
{
	entity weapon = DamageInfo_GetWeapon( damageInfo )
	entity attacker = DamageInfo_GetAttacker( damageInfo )

	if ( attacker == target )
	{
		DamageInfo_SetDamage( damageInfo, 0 )
		return
	}
}

#endif

// modified callbacks
// currently hardcoded "gunner_bison_laser"
void function OnWeaponOwnerChanged_titanweapon_laser_lite( entity weapon, WeaponOwnerChangedParams changeParams )
{
	if ( weapon.HasMod( "gunner_bison_laser" ) )
	{
#if SERVER
		// shared from _shared_energy_update.gnut
		// for handling modified shared energy regen
		UpdateSharedEnergyOnWeaponOwnerChanged(
			weapon,
			changeParams,
			GUNNER_BISON_LASER_REGEN_RATE,           	// energyRegenRate
			GUNNER_BISON_LASER_REGEN_DELAY,           	// energyRegenDelay
			GUNNER_BISON_LASER_ENERGY_TOTAL				// energyTotalCount
		)
#endif
	}
}