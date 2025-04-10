global function OnWeaponPrimaryAttack_weapon_flak_rifle
// modified callback
global function OnProjectileExplode_weapon_flak_rifle

#if SERVER
global function OnWeaponNpcPrimaryAttack_weapon_flak_rifle
#endif

#if CLIENT
global function OnClientAnimEvent_weapon_flak_rifle
#endif

global const float PROJECTILE_SPEED_FLAK = 7500.0

// modded weapon
const float PROJECILE_SPEED_FLAK_CANNON = 1900.0
// modded const
const float FLATLINE_FIRE_SOUND_RATE = 9 // spitfire sound is designed for 9 fire rate

var function OnWeaponPrimaryAttack_weapon_flak_rifle( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	if( weapon.HasMod( "flak_rifle" ) || weapon.HasMod( "flak_cannon" ) ) // flak rifle
	{
		// flak cannon sound
		if ( weapon.HasMod( "flak_cannon" ) )
		{
			thread FlakCannonSoundThink( weapon )
		}

		weapon.EmitWeaponSound_1p3p( "Weapon_Sidewinder_Fire_1P", "Weapon_Sidewinder_Fire_3P" )
		weapon.EmitWeaponNpcSound( LOUD_WEAPON_AI_SOUND_RADIUS_MP, 0.2 )
		entity weaponOwner = weapon.GetWeaponOwner()
		vector bulletVec = ApplyVectorSpread( attackParams.dir, weaponOwner.GetAttackSpreadAngle() - 1.0 )
		attackParams.dir = bulletVec

		float projectileSpeed = weapon.HasMod( "flak_cannon" ) ? PROJECILE_SPEED_FLAK_CANNON : PROJECTILE_SPEED_FLAK

		if ( IsServer() || weapon.ShouldPredictProjectiles() )
		{
			//entity missile = FireWeaponMissile_RecordData( weapon, attackParams.pos, attackParams.dir, PROJECTILE_SPEED_FLAK, DF_GIB | DF_EXPLOSION, DF_GIB | DF_EXPLOSION, false, PROJECTILE_PREDICTED )
			entity missile = FireWeaponMissile_RecordData( weapon, attackParams.pos, attackParams.dir, projectileSpeed, DF_GIB | DF_EXPLOSION, DF_GIB | DF_EXPLOSION, false, PROJECTILE_PREDICTED )
			if ( missile )
			{
				SetTeam( missile, weaponOwner.GetTeam() )
				#if SERVER
					asset trailEffect = weapon.GetWeaponSettingAsset( eWeaponVar.projectile_trail_effect_0 )
					thread DelayedStartParticleSystem( missile, trailEffect )
					if ( weapon.HasMod( "flak_cannon" ) )
						missile.SetModel( $"models/domestic/nessy_doll.mdl" ) // :D
					// change every projectile sound to be sync with client!
					//EmitSoundOnEntity( missile, "Weapon_Sidwinder_Projectile" )
					missile.ProjectileSetDamageSourceID( eDamageSourceId.mp_weapon_flak_rifle )
					//thread PROTO_FlakCannonMissiles( missile, PROJECTILE_SPEED_FLAK )
					thread PROTO_FlakCannonMissiles( missile, projectileSpeed )
				#endif
				EmitSoundOnEntity( missile, "Weapon_Sidwinder_Projectile" )
			}
		}
	}
	else // flatline
	{
		//entity weaponOwner = weapon.GetWeaponOwner()
		// don't calculate again! client will desync
		//vector bulletVec = ApplyVectorSpread( attackParams.dir, weaponOwner.GetAttackSpreadAngle() )
		//attackParams.dir = bulletVec
		weapon.EmitWeaponNpcSound( LOUD_WEAPON_AI_SOUND_RADIUS_MP, 0.2 )
		weapon.FireWeaponBullet( attackParams.pos, attackParams.dir, 1, weapon.GetWeaponDamageFlags() )
	}
}

// modded weapon
void function FlakCannonSoundThink( entity weapon )
{
	entity owner = weapon.GetWeaponOwner()
	if ( IsValid( owner ) && owner.IsPlayer() )
	{
		#if CLIENT
			weapon.EmitWeaponSound( "Weapon_Vinson_FirstShot_1P" )
		#else
			EmitSoundOnEntityExceptToPlayer( weapon, owner, "Weapon_Vinson_Loop_3P" )
		#endif
	}
	else
		EmitSoundOnEntity( weapon, "Weapon_Vinson_Loop_3P" )

    weapon.EndSignal( "OnDestroy" )

	// signal registered in mp_weapon_flak_rifle_fixed.nut
    weapon.Signal( "FlatlineWeaponFire" )
    weapon.EndSignal( "FlatlineWeaponFire" )

    float oneShotDuration = ( 1.0 / FLATLINE_FIRE_SOUND_RATE ) - 0.05 // calculate sound duration for firing 1 shot

    wait oneShotDuration
	#if CLIENT
		StopSoundOnEntity( weapon, "Weapon_Vinson_Loop_1P" )
	#endif
    StopSoundOnEntity( weapon, "Weapon_Vinson_Loop_3P" )
}

// modified callback
void function OnProjectileExplode_weapon_flak_rifle( entity projectile )
{
	array<string> mods = Vortex_GetRefiredProjectileMods( projectile )

#if SERVER
	if( mods.contains( "flak_cannon" ) )
	{
		// visual fix for client hitting near target
		FixImpactEffectForProjectileAtPosition( projectile, projectile.GetOrigin() ) // shared from _unpredicted_impact_fix.gnut
	}
#endif
}

// trail fix
#if SERVER
void function DelayedStartParticleSystem( entity missile, asset trailEffect = $"Rocket_Smoke_SMR" )
{
    WaitFrame()
    if( IsValid( missile ) )
        StartParticleEffectOnEntity( missile, GetParticleSystemIndex( trailEffect ), FX_PATTACH_ABSORIGIN_FOLLOW, -1 )
}
#endif

#if SERVER
// nowhere called this
var function OnWeaponNpcPrimaryAttack_weapon_flak_rifle( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	weapon.EmitWeaponSound( "Weapon_Sidewinder_Fire_3P" )
	weapon.EmitWeaponNpcSound( LOUD_WEAPON_AI_SOUND_RADIUS_MP, 0.2 )

		entity missile = FireWeaponMissile_RecordData( weapon, attackParams.pos, attackParams.pos, 2000.0, damageTypes.largeCaliberExp, damageTypes.largeCaliberExp, true, PROJECTILE_NOT_PREDICTED )
		if ( missile )
		{
			entity weaponOwner = weapon.GetWeaponOwner()
			SetTeam( missile, weaponOwner.GetTeam() )
			EmitSoundOnEntity( missile, "Weapon_Sidwinder_Projectile" )
			thread PROTO_FlakCannonMissiles( missile, PROJECTILE_SPEED_FLAK )
		}
}
#endif // #if SERVER

#if CLIENT
void function OnClientAnimEvent_weapon_flak_rifle( entity weapon, string name )
{
	GlobalClientEventHandler( weapon, name )
}
#endif // #if CLIENT