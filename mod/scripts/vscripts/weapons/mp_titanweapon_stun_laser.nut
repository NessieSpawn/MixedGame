global function MpTitanWeaponStunLaser_Init

global function OnWeaponAttemptOffhandSwitch_titanweapon_stun_laser
global function OnWeaponPrimaryAttack_titanweapon_stun_laser

#if SERVER
global function OnWeaponNPCPrimaryAttack_titanweapon_stun_laser
global function AddStunLaserHealCallback
#endif

const FX_EMP_BODY_HUMAN			= $"P_emp_body_human"
const FX_EMP_BODY_TITAN			= $"P_emp_body_titan"
const FX_SHIELD_GAIN_SCREEN		= $"P_xo_shield_up"
const SHIELD_BODY_FX			= $"P_xo_armor_body_CP"

// moving here from _weapon_utility.nut, because we've globalized Electricity_DamagedPlayerOrNPC()
const float LASER_STUN_SEVERITY_SLOWTURN = 0.20
const float LASER_STUN_SEVERITY_SLOWMOVE = 0.30
const asset FX_VANGUARD_ENERGY_BODY_HUMAN		= $"P_monarchBeam_body_human"
const asset FX_VANGUARD_ENERGY_BODY_TITAN		= $"P_monarchBeam_body_titan"
//

struct
{
	void functionref(entity,entity,int) stunHealCallback
} file

void function MpTitanWeaponStunLaser_Init()
{

	PrecacheParticleSystem( FX_SHIELD_GAIN_SCREEN )
	PrecacheParticleSystem( SHIELD_BODY_FX )

	// moving here from _weapon_utility.nut, because we've globalized Electricity_DamagedPlayerOrNPC()
	PrecacheParticleSystem( FX_VANGUARD_ENERGY_BODY_HUMAN )
	PrecacheParticleSystem( FX_VANGUARD_ENERGY_BODY_TITAN )
	//

	#if SERVER
		AddDamageCallbackSourceID( eDamageSourceId.mp_titanweapon_stun_laser, StunLaser_DamagedTarget )
	#endif

	#if CLIENT
		AddEventNotificationCallback( eEventNotifications.VANGUARD_ShieldGain, Vanguard_ShieldGain )
	#endif
}

bool function OnWeaponAttemptOffhandSwitch_titanweapon_stun_laser( entity weapon )
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

var function OnWeaponPrimaryAttack_titanweapon_stun_laser( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	// modded weapon
	if( weapon.HasMod( "archon_charge_ball" ) )
		return OnWeaponPrimaryAttack_titanweapon_charge_ball( weapon, attackParams )
	//
	
	// vanilla behavior
	#if CLIENT
		if ( !weapon.ShouldPredictProjectiles() )
			return weapon.GetWeaponSettingInt( eWeaponVar.ammo_per_shot )
	#endif

	entity weaponOwner = weapon.GetWeaponOwner()
	if ( weaponOwner.IsPlayer() )
		PlayerUsedOffhand( weaponOwner, weapon )

	ShotgunBlast( weapon, attackParams.pos, attackParams.dir, 1, DF_GIB | DF_EXPLOSION )
	weapon.EmitWeaponNpcSound( LOUD_WEAPON_AI_SOUND_RADIUS_MP, 0.2 )
	weapon.SetWeaponChargeFractionForced(1.0)
	return weapon.GetWeaponSettingInt( eWeaponVar.ammo_per_shot )
}
#if SERVER
var function OnWeaponNPCPrimaryAttack_titanweapon_stun_laser( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	return OnWeaponPrimaryAttack_titanweapon_stun_laser( weapon, attackParams )
}

void function StunLaser_DamagedTarget( entity target, var damageInfo )
{
	entity attacker = DamageInfo_GetAttacker( damageInfo )
	if( !IsValid( attacker ) )
		return

	if ( attacker == target )
	{
		DamageInfo_SetDamage( damageInfo, 0 )
		return
	}

	entity weapon = GetStunLaserWeapon( attacker ) // can't use DamageInfo_GetWeapon( damageInfo ) since it can't handle radius damage caused by energy field!
	//print( "current monarch weapon is: " + string( weapon ) )
	if( !IsValid( weapon ) )
		return

	// hardcoded for archon laser
	// in any case AddCallback_WeaponMod_DamageSourceIdOverride() failsafe
	if ( weapon.HasMod( "shock_laser" ) )
	{
		DamageInfo_SetDamageSourceIdentifier( damageInfo, eDamageSourceId.mp_titanweapon_energy_laser )
		return
	}

	// we added friendly fire, do a new check now!
	bool hasEnergyTransfer = weapon.HasMod( "energy_transfer" ) || weapon.HasMod( "energy_field_energy_transfer" )
	bool friendlyFireOn = FriendlyFire_IsEnabled()
	bool forceHeal = FriendlyFire_IsMonarchForcedHealthEnabled()
	bool sameTeam = attacker.GetTeam() == target.GetTeam()
	// vanguard shield gain think
	// energy transfer
	//if ( attacker.GetTeam() == target.GetTeam() )
	if ( ( sameTeam || ( friendlyFireOn && forceHeal ) ) && hasEnergyTransfer )
	{
		// triggered healing!
		DamageInfo_SetDamage( damageInfo, 0 )
		entity attackerSoul = attacker.GetTitanSoul()
		// this is absolutely hardcoded, removed
		/*
		entity weapon = attacker.GetOffhandWeapon( OFFHAND_LEFT )
		if ( !IsValid( weapon ) )
			return
		bool hasEnergyTransfer = weapon.HasMod( "energy_transfer" ) || weapon.HasMod( "energy_field_energy_transfer" )
		*/
		//if ( target.IsTitan() && IsValid( attackerSoul ) && hasEnergyTransfer )
		if ( target.IsTitan() && IsValid( attackerSoul ) )
		{
			entity soul = target.GetTitanSoul()
			if ( IsValid( soul ) )
			{
				int shieldRestoreAmount = 750
				// NOTE here: respawn mess things up by checking target's titan soul passive
				// so if we want to handle weapon, needs to get target's weapon here
				//if ( SoulHasPassive( soul, ePassives.PAS_VANGUARD_SHIELD ) ) // respawn messed this up
				// removed, this method gets attacker's weapon
				//if ( SoulHasPassive( soul, ePassives.PAS_VANGUARD_SHIELD ) || weapon.HasMod( "pas_vanguard_shield" ) ) 
				bool shouldDoAmpedRegen = SoulHasPassive( soul, ePassives.PAS_VANGUARD_SHIELD )
				entity targetStunLaser = GetStunLaserWeapon( target )
				if ( !shouldDoAmpedRegen && IsValid( targetStunLaser ) )
					shouldDoAmpedRegen = targetStunLaser.HasMod( "pas_vanguard_shield" )
				
				// misc fix here: shield amplifier should always amp shield given to friendlies
				// not only when target titan also has shiled amplifer
				// titan with the passive still always receive amped regen amount
				bool shouldFixPassive = bool( GetCurrentPlaylistVarInt( "stun_laser_fix", 0 ) ) || weapon.HasMod( "stun_laser_fix" )
				if ( !shouldDoAmpedRegen && shouldFixPassive ) // target titan has no shield amplifier
					shouldDoAmpedRegen = SoulHasPassive( attackerSoul, ePassives.PAS_VANGUARD_SHIELD ) || weapon.HasMod( "pas_vanguard_shield" )

				if ( shouldDoAmpedRegen )
					shieldRestoreAmount = int( 1.25 * shieldRestoreAmount )

				float shieldAmount = min( GetShieldHealthWithFix( soul ) + shieldRestoreAmount, GetShieldHealthMaxWithFix( soul ) )
				shieldRestoreAmount = GetShieldHealthMaxWithFix( soul ) - int( shieldAmount )

				//soul.SetShieldHealth( shieldAmount )
				SetShieldHealthWithFix( soul, shieldAmount )

				if ( file.stunHealCallback != null && shieldRestoreAmount > 0 )
					file.stunHealCallback( attacker, target, shieldRestoreAmount )
			}
			if ( target.IsPlayer() )
				MessageToPlayer( target, eEventNotifications.VANGUARD_ShieldGain, target )

			if ( attacker.IsPlayer() )
				EmitSoundOnEntityOnlyToPlayer( target, attacker, "EnergySyphon_ShieldGive" )

			float shieldHealthFrac = GetShieldHealthFrac( target )
			if ( shieldHealthFrac < 1.0 )
			{
				int shieldbodyFX = GetParticleSystemIndex( SHIELD_BODY_FX )
				int attachID
				if ( target.IsTitan() )
					attachID = target.LookupAttachment( "exp_torso_main" )
				else
					attachID = target.LookupAttachment( "ref" )

				entity shieldFXEnt = StartParticleEffectOnEntity_ReturnEntity( target, shieldbodyFX, FX_PATTACH_POINT_FOLLOW, attachID )
				EffectSetControlPointVector( shieldFXEnt, 1, < 115, 247, 255 > )
			}
		}
	}
	// non energy transfer condition
	else if ( target.IsNPC() || target.IsPlayer() ) 
	{
		if ( sameTeam && !friendlyFireOn ) // normal condition: no friendlyFire, hits teammate
		{
			DamageInfo_SetDamage( damageInfo, 0 ) // don't do following checks
			return
		}
		VanguardEnergySiphon_DamagedPlayerOrNPC( target, damageInfo ) // taken from _weapon_utility.nut. must handle it!
		int shieldRestoreAmount = target.GetArmorType() == ARMOR_TYPE_HEAVY ? 750 : 250
		entity soul = attacker.GetTitanSoul()
		if ( IsValid( soul ) )
		{
			//if ( SoulHasPassive( soul, ePassives.PAS_VANGUARD_SHIELD ) ) // respawn messed this up
			if ( SoulHasPassive( soul, ePassives.PAS_VANGUARD_SHIELD ) || weapon.HasMod( "pas_vanguard_shield" ) )
				shieldRestoreAmount = int( 1.25 * shieldRestoreAmount )
			//soul.SetShieldHealth( min( soul.GetShieldHealth() + shieldRestoreAmount, soul.GetShieldHealthMax() ) )
			SetShieldHealthWithFix( soul, min( GetShieldHealthWithFix( soul ) + shieldRestoreAmount, GetShieldHealthMaxWithFix( soul ) ) )
		}
		if ( attacker.IsPlayer() )
			MessageToPlayer( attacker, eEventNotifications.VANGUARD_ShieldGain, attacker )
	}
}

// moving here from _weapon_utility.nut, because we've globalized Electricity_DamagedPlayerOrNPC()
void function VanguardEnergySiphon_DamagedPlayerOrNPC( entity ent, var damageInfo )
{
	entity attacker = DamageInfo_GetAttacker( damageInfo )
	// we added friendly fire, do a new check now!
	// removed, other checks left for function calls this to modify( like StunLaser_DamagedTarget() )
	//if ( IsValid( attacker ) && attacker.GetTeam() == ent.GetTeam() )
	if( !IsValid( attacker ) ) 
		return
	
	// nerfed shield damage check
	bool hasNerfedShieldDamage = false
	entity weapon = GetStunLaserWeapon( attacker ) // can't use DamageInfo_GetWeapon( damageInfo ) since it can't handle radius damage caused by energy field!
	if ( IsValid( weapon ) )
		hasNerfedShieldDamage = weapon.HasMod( "rebalanced_weapon" )

	const float LASER_STUN_AFFECTS_SHIELD_SCALE_NERFED = 0.33
	float shieldDamage = EMP_AFFECTS_SHIELD_SCALE // modified const from _weapon_utility.nut
	if ( hasNerfedShieldDamage )
		shieldDamage = LASER_STUN_AFFECTS_SHIELD_SCALE_NERFED

	Electricity_DamagedPlayerOrNPC( ent, damageInfo, FX_VANGUARD_ENERGY_BODY_HUMAN, FX_VANGUARD_ENERGY_BODY_TITAN, LASER_STUN_SEVERITY_SLOWTURN, LASER_STUN_SEVERITY_SLOWMOVE, EMP_GRENADE_PILOT_SCREEN_EFFECTS_DURATION_MIN, EMP_GRENADE_PILOT_SCREEN_EFFECTS_DURATION_MAX, EMP_GRENADE_PILOT_SCREEN_EFFECTS_FADE, EMP_GRENADE_PILOT_SCREEN_EFFECTS_MIN, EMP_GRENADE_PILOT_SCREEN_EFFECTS_MAX, shieldDamage )
}
//

// modified utility function
entity function GetStunLaserWeapon( entity ent )
{
	foreach ( entity offhand in ent.GetOffhandWeapons() )
	{
		if ( offhand.GetWeaponClassName() == "mp_titanweapon_stun_laser" ) // this is hardcoded!!!
		{
			return offhand
		}
	}

	// can't find anything
	return null
}

void function AddStunLaserHealCallback( void functionref(entity,entity,int) func )
{
	file.stunHealCallback = func
}
#endif


#if CLIENT
void function Vanguard_ShieldGain( entity attacker, var eventVal )
{
	if ( attacker.IsPlayer() )
	{
		//FlashCockpitHealthGreen()
		EmitSoundOnEntity( attacker, "EnergySyphon_ShieldRecieved"  )
		entity cockpit = attacker.GetCockpit()
		if ( IsValid( cockpit ) )
			StartParticleEffectOnEntity( cockpit, GetParticleSystemIndex( FX_SHIELD_GAIN_SCREEN	), FX_PATTACH_ABSORIGIN_FOLLOW, -1 )
		Rumble_Play( "rumble_titan_battery_pickup", { position = attacker.GetOrigin() } )
	}

}
#endif
