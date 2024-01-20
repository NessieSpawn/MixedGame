global function OnWeaponPrimaryAttack_cloak
// modified callback!
global function OnProjectileCollision_cloak


var function OnWeaponPrimaryAttack_cloak( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	// modded weapons!
	// saved only for client-side in this branch
#if CLIENT
	if ( weapon.HasMod( "cloak_field" ) )
		return OnWeaponPrimaryAttack_ability_cloak_field( weapon, attackParams )
	if ( weapon.HasMod( "cloak_drone" ) )
		return OnWeaponPrimaryAttack_ability_cloak_drone( weapon, attackParams )
#endif
	//

	// vanilla behavior
	entity ownerPlayer = weapon.GetWeaponOwner()

	Assert( IsValid( ownerPlayer) && ownerPlayer.IsPlayer() )

	if ( IsValid( ownerPlayer ) && ownerPlayer.IsPlayer() )
	{
		if ( ownerPlayer.GetCinematicEventFlags() & CE_FLAG_CLASSIC_MP_SPAWNING )
			return false

		if ( ownerPlayer.GetCinematicEventFlags() & CE_FLAG_INTRO )
			return false
	}

	PlayerUsedOffhand( ownerPlayer, weapon )
	
	#if SERVER
		float duration = weapon.GetWeaponSettingFloat( eWeaponVar.fire_duration )
		EnableCloak( ownerPlayer, duration )
		#if BATTLECHATTER_ENABLED
			TryPlayWeaponBattleChatterLine( ownerPlayer, weapon )
		#endif
		//ownerPlayer.Signal( "PlayerUsedAbility" )
	#endif

	return weapon.GetWeaponSettingInt( eWeaponVar.ammo_min_to_fire )
}

// modified callback!
void function OnProjectileCollision_cloak( entity projectile, vector pos, vector normal, entity hitEnt, int hitbox, bool isCritical )
{
	// modded weapons!
	// saved only for client-side in this branch
#if CLIENT
	array<string> mods = Vortex_GetRefiredProjectileMods( projectile ) // modded weapon refire behavior
	if ( mods.contains( "cloak_field" ) )
		return OnProjectileCollision_ability_cloak_field( projectile, pos, normal, hitEnt, hitbox, isCritical )
	if ( mods.contains( "cloak_drone" ) )
		return OnProjectileCollision_ability_cloak_drone( projectile, pos, normal, hitEnt, hitbox, isCritical )
#endif
}