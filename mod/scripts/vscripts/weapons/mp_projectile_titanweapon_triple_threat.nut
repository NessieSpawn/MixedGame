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

			// more of sound fix: do 3p_vs_1p impact sound against victim!
			// welp we need handle shield hit effect... cannot pass only players
			/*
			if ( hitEnt.IsPlayer() )
				projectile.s.collisionPlayer <- hitEnt
			*/
			projectile.s.collisionEnt <- hitEnt
			
			projectile.GrenadeExplode( normal )
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
	// something needs testing is that, maybe because that triple threat grenade won't parent to entity and no special sound will be played
	bool isShieldHit = false
	string shieldHitSoundPrefix = "TitanShield.Explosive.BulletImpact"
	// cannot handle only players due that we want shield sound to be fixed
	//if ( ( "collisionPlayer" in projectile.s ) && IsValid( projectile.s.collisionPlayer ) )
	if ( ( "collisionEnt" in projectile.s ) && IsValid( projectile.s.collisionEnt ) )
	{
		//print( "playing victim sound" )
		//victim = expect entity( projectile.s.collisionPlayer )
		victim = expect entity( projectile.s.collisionEnt )
		// just for suffer
		if ( victim.IsTitan() )
		{
			entity soul = victim.GetTitanSoul()
			if ( IsValid( soul ) && GetShieldHealthWithFix( soul ) > 0 )
				isShieldHit = true // sound already played by triplethreat_frag impact!!!
		}
		else
		{
			if ( GetShieldHealthWithFix( victim ) > 0 )
				isShieldHit = true
		}
		// player sound
		if ( victim.IsPlayer() )
		{
			string sound = soundPrefix + "_3P_vs_1P"
			if ( isShieldHit )
				sound = shieldHitSoundPrefix + "_3P_vs_1P"
			EmitSoundAtPositionOnlyToPlayer( projectile.GetTeam(), projectile.GetOrigin(), victim, sound )
		}
	}
	if ( IsValid( owner ) && owner.IsPlayer() )
	{
		//print( "playing owner sound" )
		string sound = soundPrefix + "_1P_vs_3P"
		if ( isShieldHit )
			sound = shieldHitSoundPrefix + "_1P_vs_3P"
		EmitSoundAtPositionOnlyToPlayer( projectile.GetTeam(), projectile.GetOrigin(), owner, sound )
	}
	// victim sound and owner sound both played
	if ( ( IsValid( victim ) && victim.IsPlayer() ) && ( IsValid( owner ) && owner.IsPlayer() ) )
	{
		//print( "both owner and npc sound played" )
		// do sound individually for other players
		string sound = soundPrefix + "_3P_vs_3P"
		if ( isShieldHit )
			sound = shieldHitSoundPrefix + "_3P_vs_3P"
		foreach ( entity player in GetPlayerArray )
		{
			if ( player != victim && player != owner )
				EmitSoundAtPositionOnlyToPlayer( projectile.GetTeam(), projectile.GetOrigin(), player, sound )
		}
	}
	else if ( IsValid( owner ) && owner.IsPlayer() ) // only owner sound played
	{
		//print( "only owner sound" )
		string sound = soundPrefix + "_3P_vs_3P"
		if ( isShieldHit )
			sound = shieldHitSoundPrefix + "_3P_vs_3P"
		EmitSoundAtPositionExceptToPlayer( projectile.GetTeam(), projectile.GetOrigin(), owner, sound )
	}
	else if ( ( IsValid( victim ) && victim.IsPlayer() ) ) // only victim sound played
	{
		//print( "only victim sound" )
		string sound = soundPrefix + "_3P_vs_3P"
		if ( isShieldHit )
			sound = shieldHitSoundPrefix + "_3P_vs_3P"
		EmitSoundAtPositionExceptToPlayer( projectile.GetTeam(), projectile.GetOrigin(), victim, sound )
	}
	else // non-player sound not hitting anything
	{
		//print( "neutral sound" )
		string sound = soundPrefix + "_3P_vs_3P"
		if ( isShieldHit )
			sound = shieldHitSoundPrefix + "_3P_vs_3P"
		EmitSoundAtPosition( projectile.GetTeam(), projectile.GetOrigin(), sound )
	}

	// adding fix from tf|1: upper and middle grenade travel speed greatly increased. due to that, needs to fix client-side impact visual
	if( "fixImpactEffect" in projectile.s )
	{
		//print( "fixing projectile impact effect" )
		FixImpactEffectForProjectileAtPosition( projectile, projectile.GetOrigin() )
	}
#endif
}