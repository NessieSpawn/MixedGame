global function OnWeaponPrimaryAttack_holopilot
global function PlayerCanUseDecoy

// modified callback
global function OnWeaponOwnerChanged_holopilot

global const int DECOY_FADE_DISTANCE = 16000 //Really just an arbitrarily large number
global const float DECOY_DURATION = 10.0

global const vector HOLOPILOT_ANGLE_SEGMENT = < 0, 25, 0 >

#if SERVER
global function CodeCallback_PlayerDecoyDie
global function CodeCallback_PlayerDecoyDissolve
global function CodeCallback_PlayerDecoyRemove
global function CodeCallback_PlayerDecoyStateChange
global function CreateHoloPilotDecoys
global function SetupDecoy_Common

global function Decoy_Init

#if MP
global function GetDecoyActiveCountForPlayer
#endif //if MP
#endif //if server

// MODDED
#if SERVER
global function CleanupExistingDecoy // globlized for multiple uses

// modified callbacks
global function AddCallback_OnDecoyCreated // since decoys won't DispatchSpawn(), server can't use AddSpawnCallback()
global function RunCallbacks_OnDecoyCreated // to be shared with mp_ability_modded_holopilot.gnut
global function AddCallback_PlayerDecoyDie
global function AddCallback_PlayerDecoyDissolve
global function AddCallback_PlayerDecoyRemove
global function AddCallback_PlayerDecoyStateChange
#endif

// modded decoy, this is not a modding interfacer, check more in mp_ability_modded_holopilot.gnut
global function AddDecoyModifier
//

struct
{
	table< entity, int > playerToDecoysActiveTable //Mainly used to track stat for holopilot unlock

	// modified callbacks
	array< void functionref( entity, entity ) > decoyCreatedCallbacks
	array< void functionref( entity, int ) > playerDecoyDieCallbacks
	array< void functionref( entity, int ) > playerDecoyDissolveCallbacks
	array< void functionref( entity, int ) > playerDecoyRemoveCallbacks
	array< void functionref( entity, int, int ) > playerDecoyStateChangeCallbacks

	// modified
	array<string> decoyModifiers = []
}
file

/*Player decoy states: defined in player_decoy_shared.h
	PLAYER_DECOY_STATE_NONE,
	PLAYER_DECOY_STATE_IDLE,
	PLAYER_DECOY_STATE_CROUCH_IDLE,
	PLAYER_DECOY_STATE_CROUCH_WALK,
	PLAYER_DECOY_STATE_WALLHANG,
	PLAYER_DECOY_STATE_AIRBORNE,
	PLAYER_DECOY_STATE_WALK,
	PLAYER_DECOY_STATE_RUN,
	PLAYER_DECOY_STATE_SPRINT,
	PLAYER_DECOY_STATE_DYING,
	PLAYER_DECOY_STATE_COUNT
*/

// decoy modifiers functions!
void function AddDecoyModifier( string modName )
{
	if ( !( file.decoyModifiers.contains( modName ) ) )
		file.decoyModifiers.append( modName )
}

bool function HasDecoyModifier( array<string> mods )
{
	bool isModdedStim = false
	foreach ( string mod in file.decoyModifiers )
	{
		if ( mods.contains( mod ) ) // has at least one modifier
			return true
	}

	return false
}
//

#if SERVER
void function Decoy_Init()
{
	#if MP
		RegisterSignal( "CleanupFXAndSoundsForDecoy" )
	#endif
}

void function CleanupExistingDecoy( entity decoy )
{
	if ( IsValid( decoy ) ) //This cleanup function is called from multiple places, so check that decoy is still valid before we try to clean it up again
	{
		decoy.Decoy_Dissolve()
		CleanupFXAndSoundsForDecoy( decoy )
	}
}

void function CleanupFXAndSoundsForDecoy( entity decoy )
{
	if ( !IsValid( decoy ) )
		return

	decoy.Signal( "CleanupFXAndSoundsForDecoy" )

	foreach( fx in decoy.decoy.fxHandles )
	{
		if ( IsValid( fx ) )
		{
			fx.ClearParent()
			EffectStop( fx )
		}
	}

	decoy.decoy.fxHandles.clear() //probably not necessary since decoy is already being cleaned up, just for throughness.

	foreach ( loopingSound in decoy.decoy.loopingSounds )
	{
		StopSoundOnEntity( decoy, loopingSound )
	}

	decoy.decoy.loopingSounds.clear()
}

void function OnHoloPilotDestroyed( entity decoy )
{
	EmitSoundAtPosition( TEAM_ANY, decoy.GetOrigin(), "holopilot_end_3P" )

	entity bossPlayer = decoy.GetBossPlayer()
	if ( IsValid( bossPlayer ) )
		EmitSoundOnEntityOnlyToPlayer( bossPlayer, bossPlayer, "holopilot_end_1P" )

	CleanupFXAndSoundsForDecoy( decoy )
}

void function CodeCallback_PlayerDecoyDie( entity decoy, int currentState ) //All Die does is play the death animation. Eventually calls CodeCallback_PlayerDecoyDissolve too
{
	//PrintFunc()
	OnHoloPilotDestroyed( decoy )

	// modified callback
	foreach ( void functionref( entity, int ) callbackFunc in file.playerDecoyDieCallbacks )
		callbackFunc( decoy, currentState )
}

void function CodeCallback_PlayerDecoyDissolve( entity decoy, int currentState )
{
	//PrintFunc()
	OnHoloPilotDestroyed( decoy )

	// modified callback
	foreach ( void functionref( entity, int ) callbackFunc in file.playerDecoyDissolveCallbacks )
		callbackFunc( decoy, currentState )
}


void function CodeCallback_PlayerDecoyRemove( entity decoy, int currentState )
{
	//PrintFunc()

	// modified callback
	foreach ( void functionref( entity, int ) callbackFunc in file.playerDecoyRemoveCallbacks )
		callbackFunc( decoy, currentState )
}


void function CodeCallback_PlayerDecoyStateChange( entity decoy, int previousState, int currentState )
{
	//print( "playerDecoy state Changed!" )
	//print( "previousState: " + string( previousState ) )
	//print( "currentState: " + string( currentState ) )
	//PrintFunc()

	// modified callback
	foreach ( void functionref( entity, int, int ) callbackFunc in file.playerDecoyStateChangeCallbacks )
		callbackFunc( decoy, previousState, currentState )
}
#endif // SERVER

// modified callback
void function OnWeaponOwnerChanged_holopilot( entity weapon, WeaponOwnerChangedParams changeParams )
{
	if ( weapon.HasMod( "holoshift" ) )
		return OnWeaponOwnerChanged_ability_holoshift( weapon, changeParams )
}

// vanilla
var function OnWeaponPrimaryAttack_holopilot( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	entity weaponOwner = weapon.GetWeaponOwner()
	Assert( weaponOwner.IsPlayer() )

	// modded weapon
	if ( weapon.HasMod( "dead_ringer" ) )
		return OnAbilityStart_FakeDeath( weapon, attackParams )
	if ( weapon.HasMod( "holoshift" ) )
		return OnWeaponPrimaryAttack_ability_holoshift( weapon, attackParams )
	// decoy modifier
	if ( HasDecoyModifier( weapon.GetMods() ) )
		return OnWeaponPrimaryAttack_modded_holopilot( weapon, attackParams )

	if ( !PlayerCanUseDecoy( weapon ) )
		return 0

#if SERVER
	CreateHoloPilotDecoys( weaponOwner, 1 )
#else
	Rumble_Play( "rumble_holopilot_activate", {} )
#endif

	PlayerUsedOffhand( weaponOwner, weapon )
	//return 0
	return weapon.GetWeaponSettingInt( eWeaponVar.ammo_min_to_fire )
}

#if SERVER

// modified to make it return a decoy entity
// void function CreateHoloPilotDecoys( entity player, int numberOfDecoysToMake = 1 )
entity function CreateHoloPilotDecoys( entity player, int numberOfDecoysToMake = 1 )
{
	Assert( numberOfDecoysToMake > 0  )
	Assert( player )

	float displacementDistance = 30.0

	bool setOriginAndAngles = numberOfDecoysToMake > 1

	float stickPercentToRun = 0.65
	if ( setOriginAndAngles )
		stickPercentToRun = 0.0

	entity decoy
	for( int i = 0; i < numberOfDecoysToMake; ++i )
	{
		decoy = player.CreatePlayerDecoy( stickPercentToRun )
		decoy.SetMaxHealth( 50 )
		decoy.SetHealth( 50 )
		// debug
		/*
		SetShieldHealthMaxWithFix( decoy, 50 )
		SetShieldHealthWithFix( decoy, 50 )
		*/
		decoy.EnableAttackableByAI( 50, 0, AI_AP_FLAG_NONE )
		SetObjectCanBeMeleed( decoy, true )
		decoy.SetTimeout( DECOY_DURATION )

		if ( setOriginAndAngles )
		{
			vector angleToAdd = CalculateAngleSegmentForDecoy( i, HOLOPILOT_ANGLE_SEGMENT )
			vector normalizedAngle = player.GetAngles() +  angleToAdd
			normalizedAngle.y = AngleNormalize( normalizedAngle.y ) //Only care about changing the yaw
			decoy.SetAngles( normalizedAngle )

			vector forwardVector = AnglesToForward( normalizedAngle )
			forwardVector *= displacementDistance
			decoy.SetOrigin( player.GetOrigin() + forwardVector ) //Using player origin instead of decoy origin as defensive fix, see bug 223066
			PutEntityInSafeSpot( decoy, player, null, player.GetOrigin(), decoy.GetOrigin()  )
		}

		SetupDecoy_Common( player, decoy )
		// not vanilla behavior but I'd add one: make decoys follow player's bodygroup
		decoy.SetFullBodygroup( player.GetFullBodygroup() )

		#if MP
			thread MonitorDecoyActiveForPlayer( decoy, player )
		#endif
		
		// modified callbacks
		//foreach ( callbackFunc in file.decoyCreatedCallbacks )
		//	callbackFunc( player, decoy )
		RunCallbacks_OnDecoyCreated( player, decoy )
	}

	#if BATTLECHATTER_ENABLED
		PlayBattleChatterLine( player, "bc_pHolo" )
	#endif

	return decoy
}

void function SetupDecoy_Common( entity player, entity decoy ) //functioned out mainly so holopilot execution can call this as well
{
	// modified: enable damage callbacks for decoy
	// this might break vanilla behavior at some case( scorch thermite damage stuffs? ), but whatever
	decoy.SetDamageNotifications( true )

	decoy.SetDeathNotifications( true )
	decoy.SetPassThroughThickness( 0 )
	decoy.SetNameVisibleToOwner( true )
	decoy.SetNameVisibleToFriendly( true )
	decoy.SetNameVisibleToEnemy( true )
	decoy.SetDecoyRandomPulseRateMax( 0.5 ) //pulse amount per second
	decoy.SetFadeDistance( DECOY_FADE_DISTANCE )

	int friendlyTeam = decoy.GetTeam()
	EmitSoundOnEntityToTeam( decoy, "holopilot_loop", friendlyTeam  ) //loopingSound
	EmitSoundOnEntityToEnemies( decoy, "holopilot_loop_enemy", friendlyTeam  ) ///loopingSound
	decoy.decoy.loopingSounds = [ "holopilot_loop", "holopilot_loop_enemy" ]
	Highlight_SetFriendlyHighlight( decoy, "friendly_player_decoy" )
	Highlight_SetOwnedHighlight( decoy, "friendly_player_decoy" )

	decoy.e.hasDefaultEnemyHighlight = true
	SetDefaultMPEnemyHighlight( decoy )

	int attachID = decoy.LookupAttachment( "CHESTFOCUS" )

	#if MP
	var childEnt = player.FirstMoveChild()
	while ( childEnt != null )
	{
		expect entity( childEnt )

		bool isBattery = false
		bool createHologram = false
		switch( childEnt.GetClassName() )
		{
			case "item_titan_battery":
			{
				isBattery = true
				createHologram = true
				break
			}

			case "item_flag":
			{
				createHologram = true
				break
			}
		}

		asset modelName = childEnt.GetModelName()
		if ( createHologram && modelName != $"" && childEnt.GetParentAttachment() != "" )
		{
			entity decoyChildEnt = CreatePropDynamic( modelName, <0, 0, 0>, <0, 0, 0>, 0 )
			decoyChildEnt.SetSkin( childEnt.GetSkin() ) // this is just a meaningless misc fix: add skin for decoy's child
			decoyChildEnt.Highlight_SetInheritHighlight( true )
			decoyChildEnt.SetParent( decoy, childEnt.GetParentAttachment() )

			if ( isBattery ){
				thread Decoy_BatteryFX( decoy, decoyChildEnt )
			}else{
				thread Decoy_FlagFX( decoy, decoyChildEnt )
			}
		}

		childEnt = childEnt.NextMovePeer()
	}
	#endif // MP
	
	entity holoPilotTrailFX = StartParticleEffectOnEntity_ReturnEntity( decoy, HOLO_PILOT_TRAIL_FX, FX_PATTACH_POINT_FOLLOW, attachID )
	SetTeam( holoPilotTrailFX, friendlyTeam )
	holoPilotTrailFX.kv.VisibilityFlags = ENTITY_VISIBLE_TO_FRIENDLY
	decoy.decoy.fxHandles.append( holoPilotTrailFX )

	// modified to add friendlyFire support
	//decoy.SetFriendlyFire( false )
	decoy.SetFriendlyFire( FriendlyFire_IsEnabled() )
	decoy.SetKillOnCollision( false )
}

vector function CalculateAngleSegmentForDecoy( int loopIteration, vector angleSegment )
{
	if ( loopIteration == 0 )
		return < 0, 0, 0 >

	if ( loopIteration % 2 == 0  )
		return ( loopIteration / 2 ) * angleSegment * -1
	else
		return ( ( loopIteration / 2 ) + 1 ) * angleSegment

	unreachable
}

#if MP
void function Decoy_BatteryFX( entity decoy, entity decoyChildEnt )
{
	decoy.EndSignal( "OnDeath" )
	decoy.EndSignal( "CleanupFXAndSoundsForDecoy" )
	Battery_StartFX( decoyChildEnt )

	OnThreadEnd(
		function() : ( decoyChildEnt )
		{
			Battery_StopFX( decoyChildEnt )
			if ( IsValid( decoyChildEnt ) )
				decoyChildEnt.Destroy()
		}
	)

	WaitForever()
}

void function Decoy_FlagFX( entity decoy, entity decoyChildEnt )
{
	decoy.EndSignal( "OnDeath" )
	decoy.EndSignal( "CleanupFXAndSoundsForDecoy" )

	SetTeam( decoyChildEnt, decoy.GetTeam() )
	entity flagTrailFX = StartParticleEffectOnEntity_ReturnEntity( decoyChildEnt, GetParticleSystemIndex( FLAG_FX_ENEMY ), FX_PATTACH_POINT_FOLLOW, decoyChildEnt.LookupAttachment( "fx_end" ) )
	flagTrailFX.kv.VisibilityFlags = ENTITY_VISIBLE_TO_ENEMY

	OnThreadEnd(
		function() : ( flagTrailFX, decoyChildEnt )
		{
			if ( IsValid( flagTrailFX ) )
				flagTrailFX.Destroy()

			if ( IsValid( decoyChildEnt ) )
				decoyChildEnt.Destroy()
		}
	)

	WaitForever()
}

void function MonitorDecoyActiveForPlayer( entity decoy, entity player )
{
	if ( player in file.playerToDecoysActiveTable )
		++file.playerToDecoysActiveTable[ player ]
	else
		file.playerToDecoysActiveTable[ player ] <- 1

	decoy.EndSignal( "OnDestroy" ) //Note that we do this OnDestroy instead of the inbuilt OnHoloPilotDestroyed() etc functions so there is a bit of leeway after the holopilot starts to die/is fully invisible before being destroyed
	player.EndSignal( "OnDestroy" )

	OnThreadEnd(
	function() : ( player )
		{
			if( IsValid( player ) )
			{
				Assert( player in file.playerToDecoysActiveTable )
				--file.playerToDecoysActiveTable[ player ]
			}

		}
	)

	WaitForever()
}

int function GetDecoyActiveCountForPlayer( entity player )
{
	if ( !(player in file.playerToDecoysActiveTable ))
		return 0

	return file.playerToDecoysActiveTable[player ]
}

#endif // MP
#endif // SERVER

bool function PlayerCanUseDecoy( entity weapon ) //For holopilot and HoloPilot Nova. No better place to put this for now
{
	entity ownerPlayer = weapon.GetWeaponOwner()
	if ( !ownerPlayer.IsZiplining() )
	{
		if ( ownerPlayer.IsTraversing() )
			return false

		if ( ownerPlayer.ContextAction_IsActive() ) //Stops every single context action from letting decoy happen, including rodeo, melee, embarking etc
			return false
	}

	//Do we need to check isPhaseShifted here? Re-examine when it's possible to get both Phase and Decoy (maybe through burn cards?)
	if(ownerPlayer.IsPhaseShifted())
		return false
	return true
}

// modified callbacks
#if SERVER
void function AddCallback_OnDecoyCreated( void functionref( entity, entity ) callbackFunc )
{
	file.decoyCreatedCallbacks.append( callbackFunc )
}

void function RunCallbacks_OnDecoyCreated( entity player, entity decoy )
{
	foreach ( callbackFunc in file.decoyCreatedCallbacks )
		callbackFunc( player, decoy )
}

void function AddCallback_PlayerDecoyDie( void functionref( entity, int ) callbackFunc )
{
	file.playerDecoyDieCallbacks.append( callbackFunc )
}

void function AddCallback_PlayerDecoyDissolve( void functionref( entity, int ) callbackFunc )
{
	file.playerDecoyDissolveCallbacks.append( callbackFunc )
}

void function AddCallback_PlayerDecoyRemove( void functionref( entity, int ) callbackFunc )
{
	file.playerDecoyRemoveCallbacks.append( callbackFunc )
}

void function AddCallback_PlayerDecoyStateChange( void functionref( entity, int, int ) callbackFunc )
{
	file.playerDecoyStateChangeCallbacks.append( callbackFunc )
}
#endif