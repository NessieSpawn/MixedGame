//untyped

global function OnWeaponPrimaryAttack_lmg

global function OnWeaponActivate_lmg
global function OnWeaponBulletHit_weapon_lmg

const float LMG_SMART_AMMO_TRACKER_TIME = 10.0

// modded const
const float LMG_FIRE_SOUND_RATE = 9 // spitfire sound is designed for 9 fire rate

void function OnWeaponActivate_lmg( entity weapon )
{
	//PrintFunc()
	SmartAmmo_SetAllowUnlockedFiring( weapon, true )
	SmartAmmo_SetUnlockAfterBurst( weapon, (SMART_AMMO_PLAYER_MAX_LOCKS > 1) )
	SmartAmmo_SetWarningIndicatorDelay( weapon, 9999.0 )
}


var function OnWeaponPrimaryAttack_lmg( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	if ( weapon.HasMod( "smart_lock_dev" ) )
	{
		int damageFlags = weapon.GetWeaponDamageFlags()
		//printt( "DamageFlags for lmg: " + damageFlags )
		//return ( weapon, attackParams, damageFlags, damageFlags ) // why it can't compile?
	}
	else
	{
		// modded weapon
		if ( weapon.HasMod( "apex_rampage" ) ) // this will fix rampage's thirdperson fire sound, hardcoded!
		{
			// now change to new method of fixing: stop sound at specific point so client&server both syncs
			/*
			#if SERVER
				StopSoundOnEntity( weapon, "Weapon_LMG_Loop_3P" )
				entity owner = weapon.GetWeaponOwner()
				if( owner.IsPlayer() )
					EmitSoundOnEntityExceptToPlayer( weapon, owner, "Weapon_Wingman_Fire_NPC" )
			#endif
			*/
			// welp don't really need such a fix, looping sound feels bad when not played through
			// just change sound effect to "Weapon_LMG_FirstShot_1P" is enough
			// this think is only for third person sound effect now
			thread RampageSoundThink( weapon )
		}
		//

		// bullet behavior
		weapon.EmitWeaponNpcSound( LOUD_WEAPON_AI_SOUND_RADIUS_MP, 0.2 )
		weapon.FireWeaponBullet( attackParams.pos, attackParams.dir, 1, weapon.GetWeaponDamageFlags() )
	}
}

// modded weapon
void function RampageSoundThink( entity weapon )
{
	entity owner = weapon.GetWeaponOwner()
	if ( IsValid( owner ) && owner.IsPlayer() )
	{
		#if CLIENT
			// this think is only for third person sound effect now
			//weapon.EmitWeaponSound( "Weapon_LMG_Loop_1P" )
			weapon.EmitWeaponSound( "Weapon_LMG_FirstShot_1P" )
		#else
			//EmitSoundOnEntityOnlyToPlayer( weapon, owner, "Weapon_LMG_Loop_1P" )
			EmitSoundOnEntityExceptToPlayer( weapon, owner, "Weapon_LMG_Loop_3P" )
		#endif
	}
	else
		EmitSoundOnEntity( weapon, "Weapon_LMG_Loop_3P" )

    weapon.EndSignal( "OnDestroy" )

	// signal registered in mp_weapon_lmg_fixed.nut
    weapon.Signal( "LmgWeaponFire" )
    weapon.EndSignal( "LmgWeaponFire" )

    float oneShotDuration = ( 1.0 / LMG_FIRE_SOUND_RATE ) - 0.05 // calculate sound duration for firing 1 shot

    wait oneShotDuration
	// this think is only for third person sound effect now
    //StopSoundOnEntity( weapon, "Weapon_LMG_Loop_1P" )
	#if CLIENT
		StopSoundOnEntity( weapon, "Weapon_LMG_Loop_1P" )
	#endif
    StopSoundOnEntity( weapon, "Weapon_LMG_Loop_3P" )
}
//

void function OnWeaponBulletHit_weapon_lmg( entity weapon, WeaponBulletHitParams hitParams )
{
	if ( !weapon.HasMod( "smart_lock_dev" ) )
		return

	entity hitEnt = hitParams.hitEnt //Could be more efficient with this and early return out if the hitEnt is not a player, if only smart_ammo_player_targets_must_be_tracked  is set, which is currently true

	if ( IsValid( hitEnt ) )
	{
		weapon.SmartAmmo_TrackEntity( hitEnt, LMG_SMART_AMMO_TRACKER_TIME )

		#if SERVER
			if ( hitEnt.IsPlayer() &&  !hitEnt.IsTitan() ) //Note that there is a max of 10 status effects, which means that if you theoreteically get hit as a pilot 10 times without somehow dying, you could knock out other status effects like emp slow etc
			{
				printt( "Adding status effect" )
				StatusEffect_AddTimed( hitEnt, eStatusEffect.sonar_detected, 1.0, LMG_SMART_AMMO_TRACKER_TIME, 0.0 )
			}
		#endif
	}
}
