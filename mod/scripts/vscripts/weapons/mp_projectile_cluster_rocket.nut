
global function OnProjectileCollision_ClusterRocket

void function OnProjectileCollision_ClusterRocket( entity projectile, vector pos, vector normal, entity hitEnt, int hitbox, bool isCritical )
{
	array<string> mods = Vortex_GetRefiredProjectileMods( projectile ) // modded weapon refire behavior
	// modded weapon
	// saved only for client-side in this branch
#if CLIENT
	if( mods.contains( "brute4_grenade_volley" ) )
		return OnProjectileCollision_titanweapon_grenade_volley( projectile, pos, normal, hitEnt, hitbox, isCritical )
#endif
	//

	// vanilla behavior
	entity weaponOwner = projectile.GetOwner()
	//array<string> mods = projectile.ProjectileGetMods() // vanilla behavior, not changing to Vortex_GetRefiredProjectileMods()
	//array<string> mods = Vortex_GetRefiredProjectileMods( projectile ) // I don't care, let's break vanilla behavior
	float duration = mods.contains( "pas_northstar_cluster" ) ? PAS_NORTHSTAR_CLUSTER_ROCKET_DURATION : CLUSTER_ROCKET_DURATION

	#if SERVER
		float explosionDelay = expect float( projectile.ProjectileGetWeaponInfoFileKeyField( "projectile_explosion_delay" ) )

		ClusterRocket_Detonate( projectile, normal )
		CreateNoSpawnArea( TEAM_INVALID, TEAM_INVALID, pos, ( duration + explosionDelay ) * 0.5 + 1.0, CLUSTER_ROCKET_BURST_RANGE + 100 )
	#endif
}
