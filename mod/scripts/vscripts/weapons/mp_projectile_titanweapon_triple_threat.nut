untyped


global function OnProjectileCollision_titanweapon_triple_threat
// new adding, fix sound for ttf2
global function OnProjectileExplode_titanweapon_triplethreat

void function OnProjectileCollision_titanweapon_triple_threat( entity projectile, vector pos, vector normal, entity hitEnt, int hitbox, bool isCritical )
{
	if( !IsValid( hitEnt ) )
		return

	if( "impactFuse" in projectile.s && projectile.s.impactFuse == true )
		projectile.GrenadeExplode( Vector( 0,0,0 ) )
	
	if( hitEnt.GetClassName() == "player" && !hitEnt.IsTitan() )
		return

	// Should not be necessary
	if( !IsValid( projectile ) )
		return

	if( IsMagneticTarget( hitEnt ) )
	{
		// adding friendlyfire support
		//if ( hitEnt.GetTeam() != projectile.GetTeam() )
		if ( FriendlyFire_IsEnabled() || hitEnt.GetTeam() != projectile.GetTeam() )
		{
			local normal = Vector( 0, 0, 1 )
			if( "collisionNormal" in projectile.s )
				normal = projectile.s.collisionNormal

			// adding visual fix: if client without mod installed hits a friendly target in close range
			// they won't predict the impact effect
			#if SERVER
				if ( hitEnt.GetTeam() == projectile.GetTeam() )
				{
					// to keep same as mgl does, no need to add normal
					//vector explodePos = pos + expect vector( normal )
					vector explodePos = pos
					FixImpactEffectForProjectileAtPosition( projectile, explodePos ) // shared from _unpredicted_impact_fix.gnut
					// make sure we don't fix visual multiple times
					if( "fixImpactEffect" in projectile.s )
						delete projectile.s.fixImpactEffect
				}
			#endif
			
			projectile.GrenadeExplode( normal )

			// more of sound fix: do 3p_vs_1p impact sound against victim!
			if ( hitEnt.IsPlayer() )
				projectile.s.collisionPlayer <- hitEnt
		}
	}
	else if( "becomeProxMine" in projectile.s && projectile.s.becomeProxMine == true )
	{
		table collisionParams =
		{
			pos = pos,
			normal = normal,
			hitEnt = hitEnt,
			hitbox = hitbox
		}

		PlantStickyEntity( projectile, collisionParams )
		projectile.s.collisionNormal <- normal
		#if SERVER
			thread TripleThreatProximityTrigger( projectile )
		#endif
	}
}

#if SERVER
function TripleThreatProximityTrigger( entity nade )
{
	//Hack, shouldn't be necessary with the IsValid check in OnProjectileCollision.
	if( !IsValid( nade ) )
		return

	nade.EndSignal( "OnDestroy" )
	EmitSoundOnEntity( nade, "Wpn_TripleThreat_Grenade_MineAttach" )

	wait TRIPLETHREAT_MINE_FIELD_ACTIVATION_TIME

	EmitSoundOnEntity( nade, "Weapon_Vortex_Gun.ExplosiveWarningBeep" )
	local rangeCheck = PROX_MINE_RANGE
	while( 1 )
	{
		local origin = nade.GetOrigin()
		int team = nade.GetTeam()

		local entityArray = GetScriptManagedEntArrayWithinCenter( level._proximityTargetArrayID, team, origin, PROX_MINE_RANGE )
		foreach( entity ent in entityArray )
		{
			if ( TRIPLETHREAT_MINE_FIELD_TITAN_ONLY )
				if ( !ent.IsTitan() )
					continue

			if ( IsAlive( ent ) )
			{
				nade.Signal( "ProxMineTrigger" )
				return
			}
		}
		WaitFrame()
	}
}
#endif // SERVER


// new adding, fix sound for ttf2
void function OnProjectileExplode_titanweapon_triplethreat( entity projectile )
{
#if SERVER
	//print( "Running here" )
	//for( int i = 0; i < 30; i ++ ) // stack the sound!!! don't work well
	//	EmitSoundAtPosition( TEAM_UNASSIGNED, projectile.GetOrigin(), "Explo_TripleThreat_Impact_3P" )
	// explo_40mm_splashed_impact_3p might be quiet crazy but whatever
	//EmitSoundAtPosition( TEAM_UNASSIGNED, projectile.GetOrigin(), "Explo_40mm_Impact_3P" )
	// welp this is definitely way too crazy
	//EmitSoundAtPosition( TEAM_UNASSIGNED, projectile.GetOrigin(), "explo_40mm_splashed_impact_3p" )
	//EmitSoundAtPosition( TEAM_UNASSIGNED, projectile.GetOrigin(), "Default.ClusterRocket_Primary_Explosion_3P_vs_3P" )
	// more of sound think -- let's fully fake impact sound system!
	string soundPrefix = "Default.ClusterRocket_Primary_Explosion"
	entity victim
	entity owner = projectile.GetOwner()
	int team = projectile.GetTeam()
	if ( ( "collisionPlayer" in projectile.s ) && IsValid( projectile.s.collisionPlayer ) )
	{
		victim = expect entity( projectile.s.collisionPlayer )
		EmitSoundAtPositionOnlyToPlayer( projectile.GetTeam(), projectile.GetOrigin(), victim, soundPrefix + "_3P_vs_1P" )
	}
	if ( IsValid( owner ) && owner.IsPlayer() )
		EmitSoundAtPositionOnlyToPlayer( projectile.GetTeam(), projectile.GetOrigin(), owner, soundPrefix + "_1P_vs_3P" )
	// victim sound and owner sound both played
	if ( IsValid( victim ) && ( IsValid( owner ) && owner.IsPlayer() ) )
	{
		// do sound individually for other players
		foreach ( entity player in GetPlayerArray )
		{
			if ( player != victim && player != owner )
				EmitSoundAtPositionOnlyToPlayer( projectile.GetTeam(), projectile.GetOrigin(), player, soundPrefix + "_3P_vs_3P" )
		}
	}
	else if ( IsValid( owner ) && owner.IsPlayer() ) // only owner sound played
		EmitSoundAtPositionExceptToPlayer( projectile.GetTeam(), projectile.GetOrigin(), owner, soundPrefix + "_3P_vs_3P" )
	else if ( IsValid( victim ) ) // only victim sound played
		EmitSoundAtPositionExceptToPlayer( projectile.GetTeam(), projectile.GetOrigin(), victim, soundPrefix + "_3P_vs_3P" )
	else // non-player sound not hitting anything
		EmitSoundAtPosition( projectile.GetTeam(), projectile.GetOrigin(), soundPrefix + "_3P_vs_3P" )

	// adding fix from tf|1: upper and middle grenade travel speed greatly increased. due to that, needs to fix client-side impact visual
	if( "fixImpactEffect" in projectile.s )
		FixImpactEffectForProjectileAtPosition( projectile, projectile.GetOrigin() )
#endif
}