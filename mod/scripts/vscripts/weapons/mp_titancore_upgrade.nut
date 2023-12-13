global function UpgradeCore_Init
global function OnWeaponPrimaryAttack_UpgradeCore
// modified callbacks
global function OnCoreCharge_UpgradeCore
global function OnCoreChargeEnd_UpgradeCore
//

// modified contents debug
const bool UPGRADE_CORE_DEBUG = false

#if SERVER
global function OnWeaponNpcPrimaryAttack_UpgradeCore

// modified settings
// allow modifying shield regen amount when using custom shield amount
global function UpgradeCore_SetShieldRegenScale

// allow modifying upgrading method for titan
// not a good idea to use weapon for stroing modified upgrades--- they can be easily destroyed
//global function UpgradeCore_SetWeaponUpgradePassive
//global function UpgradeCore_WeaponHasModifiedUpgrades
global function UpgradeCore_SetTitanUpgradePassive
global function UpgradeCore_SetTitanUpgradePassivesTable

global function UpgradeCore_TitanHasModifiedUpgrades
global function UpgradeCore_GetTitanMaxUpgradeLevel

global function UpgradeCore_GetTitanModifiedUpgradePassive
global function UpgradeCore_GetTitanModifiedUpgradesTable

// to be shared with titan_replace, for handling loadout pickup
global function UpgradeCore_GetTitanUpgradeCount // scripted upgrade count, not networkvar
global function UpgradeCore_SetTitanUpgradeCount

global function UpgradeCore_GetTitanReceivedUpgradePassives
global function UpgradeCore_SetTitanReceivedUpgradePassives

// built function for fun
// example case:
//	UpgradeCore_GenerateRandomUpgradesForTitan( titan, 2, 3 ) will generate a random upgrade at each stage
//	UpgradeCore_GenerateRandomUpgradesForTitan( titan, 2, 1 ) will generate full upgrades at first stage
//	UpgradeCore_GenerateRandomUpgradesForTitan( titan, 8, 3 ) will generate full upgrades at all three stages
global function UpgradeCore_GenerateRandomUpgradesForTitan

// vanilla hardcode turns to default value
const int UPGRADE_CORE_DEFAULT_MAX_LEVEL = 2 // lv0-lv1-lv2( stage1-stage2-stage3 )
//
#endif
#if CLIENT
global function ServerCallback_VanguardUpgradeMessage
#endif

const LASER_CHAGE_FX_1P = $"P_handlaser_charge"
const LASER_CHAGE_FX_3P = $"P_handlaser_charge"
const FX_SHIELD_GAIN_SCREEN		= $"P_xo_shield_up"

// modified settings
struct
{
	// allow modifying shield regen amount when using custom shield amount
	float shieldRegenScale = 1.0 // 1.0 means regen to max shield
	// allow modifying upgrading method for titan
	// not a good idea to use weapon for stroing modified upgrades--- they can be easily destroyed
	//table< entity, table<int, int> > upgradeCorePassivesTable
	table< entity, table<int, int> > soulUpgradePassivesTable
	table<entity, int> soulUpgradeCount
	// storing received upgrades for titan. array<int> is for storing passives index
	table< entity, array<int> > soulReceivedUpgradePassives
} file

void function UpgradeCore_Init()
{
	RegisterSignal( "OnSustainedDischargeEnd" )

	PrecacheParticleSystem( FX_SHIELD_GAIN_SCREEN )
	PrecacheParticleSystem( LASER_CHAGE_FX_1P )
	PrecacheParticleSystem( LASER_CHAGE_FX_3P )

	
	#if SERVER
		// modified init
		AddSoulInitFunc( InitUpgradeCoreTitanSoul )
		// modified function in sv_earn_meter.gnut, to get rid of maelstrom hardcode
		AddCallback_OnGiveOffhandElectricSmoke( UpgradeCoreOffhandElectricSmoke )
	#endif
}

// modified callbacks
#if SERVER
// init
void function InitUpgradeCoreTitanSoul( entity soul )
{
	file.soulUpgradeCount[ soul ] <- 0
	file.soulReceivedUpgradePassives[ soul ] <- []
	file.soulUpgradePassivesTable[ soul ] <- {}
}

// get rid of maelstrom hardcode
void function UpgradeCoreOffhandElectricSmoke( entity titan, bool startWithSmoke )
{
	if ( !startWithSmoke ) // if titan not start with smoke when earning one, it must have been taken away
	{
		// restore maelstrom if we have upgrade
		entity smokeWeapon = titan.GetOffhandWeapon( OFFHAND_INVENTORY )
		if ( IsValid( smokeWeapon ) )
		{
			if ( UpgradeCore_GetTitanReceivedUpgradePassives( titan ).contains( ePassives.PAS_VANGUARD_CORE5 ) )
			{
				// debug
				#if UPGRADE_CORE_DEBUG
					print( "Restoring maelstrom for electric smoke... Owner is " + string( titan ) )
				#endif
				array<string> mods = smokeWeapon.GetMods()
				mods.append( "maelstrom" )
				smokeWeapon.SetMods( mods )
			}
		}
	}
}
#endif

#if SERVER
var function OnWeaponNpcPrimaryAttack_UpgradeCore( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	OnWeaponPrimaryAttack_UpgradeCore( weapon, attackParams )
	return 1
}
#endif

var function OnWeaponPrimaryAttack_UpgradeCore( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	// modded weapon
	if( weapon.HasMod( "shield_core" ) )
		return OnAbilityStart_Shield_Core( weapon, attackParams )
	//

	// vanilla behavior
	if ( !CheckCoreAvailable( weapon ) )
		return false

	entity owner = weapon.GetWeaponOwner()
	entity soul = owner.GetTitanSoul()
	#if SERVER
		float coreDuration = weapon.GetCoreDuration()
		thread UpgradeCoreThink( weapon, coreDuration )

		// below are heavily modified
		int totalUpgradeCount = UpgradeCore_GetTitanUpgradeCount( owner ) // script upgrade counter

		bool functionref( entity ) upgradeFunc = null
		//if ( !UpgradeCore_WeaponHasModifiedUpgrades( weapon ) ) // don't have modified settings?
		if ( !UpgradeCore_TitanHasModifiedUpgrades( owner ) )
			upgradeFunc = GetUpgradeFunctionFromTitan( owner ) // get upgrade from titan
		else // has modified upgrade order
		{
			// not a good idea to use weapon for stroing modified upgrades--- they can be easily destroyed
			/*
			if ( totalUpgradeCount in file.upgradeCorePassivesTable[ weapon ] )
			{
				int passive = file.upgradeCorePassivesTable[ weapon ][ totalUpgradeCount ]
				upgradeFunc = GetUpgradeFunctionFromPassive( passive )
			}
			*/
			if ( UpgradeCore_TitanHasUpgradePassiveForLevel( owner, totalUpgradeCount ) )
			{
				int passive = UpgradeCore_GetTitanModifiedUpgradePassive( owner, totalUpgradeCount )
				upgradeFunc = GetUpgradeFunctionFromPassive( passive )
			}
		}

		// modified: this variable only stores "effective" upgrades
		// if we don't have any upgrade function calling, this variable isn't gonna increase
		int currentUpgradeCount = soul.GetTitanSoulNetInt( "upgradeCount" )
		// debug
		#if UPGRADE_CORE_DEBUG
			print( "Titan: " + string( owner ) + " effective upgrade count before upgrading: " + string( soul.GetTitanSoulNetInt( "upgradeCount" ) ) )
			print( "Titan: " + string( owner ) + " total upgrade count before upgrading: " + string( file.soulUpgradeCount[ soul ] ) )
		#endif

		bool effectiveUpgrade = false
		if ( upgradeFunc != null )
		{
			// debug
			#if UPGRADE_CORE_DEBUG
				print( "Titan: " + string( owner ) + " got effective upgrade!" )
			#endif

			effectiveUpgrade = upgradeFunc( owner ) // can failed if titan already have this upgrade...
		}

		if ( effectiveUpgrade ) // upgrading succeeded!
		{
			PlayUpgradeDialogue( owner ) // play dialogue before we update upgrade counter
			soul.SetTitanSoulNetInt( "upgradeCount", currentUpgradeCount + 1 )
		}
		else
		{
			// do shield replenish dialogue if there're no valid upgrade
			if ( owner.IsPlayer() )
				Remote_CallFunction_Replay( owner, "ServerCallback_PlayTitanConversation", GetConversationIndex( "upgradeShieldReplenish" ) )
		}

		// this is the variable that stores any upgrade we tried to do, not only effective ones
		UpgradeCore_SetTitanUpgradeCount( owner, totalUpgradeCount + 1 )
		
		// upgrade bodygroup
		int newUpgradeCount = soul.GetTitanSoulNetInt( "upgradeCount" )
		if ( newUpgradeCount > 0 )
		{
			int statesIndex = owner.FindBodyGroup( "states" )
			if ( statesIndex > -1 ) // anti-crash
				owner.SetBodygroup( statesIndex, 1 )
		}

		// debug
		#if UPGRADE_CORE_DEBUG
			print( "Titan: " + string( owner ) + " effective upgrade count after upgrade: " + string( soul.GetTitanSoulNetInt( "upgradeCount" ) ) )
			print( "Titan: " + string( owner ) + " total upgrade count after upgrade: " + string( file.soulUpgradeCount[ soul ] ) )
		#endif
	#endif

	#if CLIENT
		if ( owner.IsPlayer() )
		{
			entity cockpit = owner.GetCockpit()
			if ( IsValid( cockpit ) )
				StartParticleEffectOnEntity( cockpit, GetParticleSystemIndex( FX_SHIELD_GAIN_SCREEN	), FX_PATTACH_ABSORIGIN_FOLLOW, -1 )
		}
	#endif
	OnAbilityCharge_TitanCore( weapon )
	OnAbilityStart_TitanCore( weapon )

	return 1
}

#if SERVER
void function UpgradeCoreThink( entity weapon, float coreDuration )
{
	weapon.EndSignal( "OnDestroy" )
	entity owner = weapon.GetWeaponOwner()
	owner.EndSignal( "OnDestroy" )
	owner.EndSignal( "OnDeath" )
	owner.EndSignal( "DisembarkingTitan" )
	owner.EndSignal( "TitanEjectionStarted" )

	// modified to add npc usage
	if ( owner.IsPlayer() ) 
	{
		EmitSoundOnEntityOnlyToPlayer( owner, owner, "Titan_Monarch_Smart_Core_Activated_1P" )
		EmitSoundOnEntityOnlyToPlayer( owner, owner, "Titan_Monarch_Smart_Core_ActiveLoop_1P" )
		EmitSoundOnEntityExceptToPlayer( owner, owner, "Titan_Monarch_Smart_Core_Activated_3P" )
	}
	else
		EmitSoundOnEntity( owner, "Titan_Monarch_Smart_Core_Activated_3P" )
	
	entity soul = owner.GetTitanSoul()
	//soul.SetShieldHealth( soul.GetShieldHealthMax() )
	// adding settings that allows shield regen amount to be modified
	int shieldRegen = int( soul.GetShieldHealthMax() * file.shieldRegenScale )
    soul.SetShieldHealth( min( soul.GetShieldHealthMax(), soul.GetShieldHealth() + shieldRegen ) )

	OnThreadEnd(
	function() : ( weapon, owner, soul )
		{
			if ( IsValid( owner ) )
			{
				StopSoundOnEntity( owner, "Titan_Monarch_Smart_Core_ActiveLoop_1P" )
				//EmitSoundOnEntityOnlyToPlayer( owner, owner, "Titan_Monarch_Smart_Core_Activated_1P" )
			}

			if ( IsValid( weapon ) )
			{
				OnAbilityChargeEnd_TitanCore( weapon )
				OnAbilityEnd_TitanCore( weapon )
			}

			if ( IsValid( soul ) )
			{
				CleanupCoreEffect( soul )
			}
		}
	)

	wait coreDuration
}


// modified rework starts here
// split everything into functions
bool functionref( entity ) function GetUpgradeFunctionFromTitan( entity titan )
{
	entity soul = titan.GetTitanSoul()
	if ( IsValid( soul ) )
	{
		int currentUpgradeCount = soul.GetTitanSoulNetInt( "upgradeCount" )
		if ( currentUpgradeCount == 0 )
		{
			if ( SoulHasPassive( soul, ePassives.PAS_VANGUARD_CORE1 ) ) // Arc Rounds
				return Upgrade_ArcRounds
			else if ( SoulHasPassive( soul, ePassives.PAS_VANGUARD_CORE2 ) ) //Missile Racks
				return Upgrade_MissileRacks
			else if ( SoulHasPassive( soul, ePassives.PAS_VANGUARD_CORE3 ) ) //Energy Transfer
				return Upgrade_EnergyTransfer
		}
		else if ( currentUpgradeCount == 1 )
		{
			if ( SoulHasPassive( soul, ePassives.PAS_VANGUARD_CORE4 ) )  // Rapid Rearm
				return Upgrade_RapidRearm
			else if ( SoulHasPassive( soul, ePassives.PAS_VANGUARD_CORE5 ) ) //Maelstrom
				return Upgrade_Maelstrom
			else if ( SoulHasPassive( soul, ePassives.PAS_VANGUARD_CORE6 ) ) //Energy Field
				return Upgrade_EnergyField
		}
		else if ( currentUpgradeCount == 2 )
		{
			if ( SoulHasPassive( soul, ePassives.PAS_VANGUARD_CORE7 ) )  // Multi-Target Missiles
				return Upgrade_MultiTargetMissiles
			else if ( SoulHasPassive( soul, ePassives.PAS_VANGUARD_CORE8 ) ) //Superior Chassis
				return Upgrade_SuperiorChassis
			else if ( SoulHasPassive( soul, ePassives.PAS_VANGUARD_CORE9 ) ) //XO-16 Battle Rifle
				return Upgrade_XO16BattleRifle
		}
	}

	return null
}

bool functionref( entity ) function GetUpgradeFunctionFromPassive( int passive )
{
	switch ( passive )
	{
		case ePassives.PAS_VANGUARD_CORE1:
			return Upgrade_ArcRounds
		case ePassives.PAS_VANGUARD_CORE2:
			return Upgrade_MissileRacks
		case ePassives.PAS_VANGUARD_CORE3:
			return Upgrade_EnergyTransfer

		case ePassives.PAS_VANGUARD_CORE4:
			return Upgrade_RapidRearm
		case ePassives.PAS_VANGUARD_CORE5:
			return Upgrade_Maelstrom
		case ePassives.PAS_VANGUARD_CORE6:
			return Upgrade_EnergyField

		case ePassives.PAS_VANGUARD_CORE7:
			return Upgrade_MultiTargetMissiles
		case ePassives.PAS_VANGUARD_CORE8:
			return Upgrade_SuperiorChassis
		case ePassives.PAS_VANGUARD_CORE9:
			return Upgrade_XO16BattleRifle
	}

	return null
}

void function PlayUpgradeDialogue( entity titan )
{
	// dialogue is only for players
	if ( !titan.IsPlayer() )
		return

	entity soul = titan.GetTitanSoul()
	if ( !IsValid( soul ) )
		return
	
	int conversationID = -1

	// this variable only stores "effective" upgrades. if an upgrade only included shield regen it won't be consider as effective
	int effectiveUpgradeCount = soul.GetTitanSoulNetInt( "upgradeCount" )
	if ( effectiveUpgradeCount == 0 )
		conversationID = GetConversationIndex( "upgradeTo1" )
	else if ( effectiveUpgradeCount == 1 )
		conversationID = GetConversationIndex( "upgradeTo2" )
	else if ( effectiveUpgradeCount == 2 )
	{
		array<string> conversations = [ "upgradeTo3" ]
		if ( UpgradeCore_GetTitanMaxUpgradeLevel( titan ) == 2 ) // max upgrade level is 2
			conversations.append( "upgradeToFin" ) // add chance to pick "final upgrade" dialogue
		conversationID = GetConversationIndex( conversations.getrandom() )
	}
	else // higher than level 2
	{
		conversationID = GetConversationIndex( "upgradeShieldReplenish" )

		// custom level
		if ( UpgradeCore_GetTitanUpgradeCount( titan ) == UpgradeCore_GetTitanMaxUpgradeLevel( titan ) ) // reaching max upgrade level?
			conversationID = GetConversationIndex( "upgradeToFin" ) // use final upgrade dialogue instead
	}

	if ( conversationID != -1 )
		Remote_CallFunction_Replay( titan, "ServerCallback_PlayTitanConversation", conversationID )
}

int function UpgradeCore_GetTitanMaxUpgradeLevel( entity titan )
{
	// not a good idea to use weapon for stroing modified upgrades--- they can be easily destroyed
	/*
	entity upgradeCore = GetUpgradeCoreWeapon( titan )
	if ( !IsValid( upgradeCore ) ) // don't have upgrade core for some reason...
		return 0

	// core with no modified settings, just return default value
	if ( !UpgradeCore_WeaponHasModifiedUpgrades( upgradeCore ) )
		return UPGRADE_CORE_DEFAULT_MAX_LEVEL
	*/

	// titan with no modified settings, just return default value
	if ( !UpgradeCore_TitanHasModifiedUpgrades( titan ) )
		return UPGRADE_CORE_DEFAULT_MAX_LEVEL
	
	int highestLevel = 0
	//foreach ( int level, int passive in file.upgradeCorePassivesTable[ upgradeCore ] )
	foreach ( int level, int passive in UpgradeCore_GetTitanModifiedUpgradesTable( titan ) )
	{
		if ( highestLevel < level )
			highestLevel = level
	}
	return highestLevel
}

// this is hardcoded!
// not a good idea to use weapon for stroing modified upgrades--- they can be easily destroyed
/*
entity function GetUpgradeCoreWeapon( entity titan )
{
	entity coreWeapon = titan.GetOffhandWeapon( OFFHAND_EQUIPMENT )
	if ( IsValid( coreWeapon ) && coreWeapon.GetWeaponClassName() == "mp_titancore_upgrade" )
		return coreWeapon
	
	return null
}
*/

bool function Upgrade_ArcRounds( entity titan )
{
	// anti-crash: don't upgrade again if we already got the same upgrade
	array<int> receivedUpgrades = UpgradeCore_GetTitanReceivedUpgradePassives( titan )
	if ( receivedUpgrades.contains( ePassives.PAS_VANGUARD_CORE1 ) )
		return false // upgrading failed
	
	// debug
	#if UPGRADE_CORE_DEBUG
		PrintFunc()
	#endif

	array<entity> weapons = GetPrimaryWeapons( titan )
	if ( weapons.len() > 0 )
	{
		entity primaryWeapon = weapons[0]
		if ( IsValid( primaryWeapon ) )
		{
			array<string> mods = primaryWeapon.GetMods()
			mods.append( "arc_rounds" )
			primaryWeapon.SetMods( mods )
			primaryWeapon.SetWeaponPrimaryClipCount( primaryWeapon.GetWeaponPrimaryClipCount() + 10 )
		}
	}

	if ( titan.IsPlayer() )
		Remote_CallFunction_NonReplay( titan, "ServerCallback_VanguardUpgradeMessage", 1 )

	// append passive to received upgrades
	receivedUpgrades.append( ePassives.PAS_VANGUARD_CORE1 )
	UpgradeCore_SetTitanReceivedUpgradePassives( titan, receivedUpgrades )
	return true // upgrading succeeded
}

bool function Upgrade_MissileRacks( entity titan )
{
	// anti-crash: don't upgrade again if we already got the same upgrade
	array<int> receivedUpgrades = UpgradeCore_GetTitanReceivedUpgradePassives( titan )
	if ( receivedUpgrades.contains( ePassives.PAS_VANGUARD_CORE2 ) )
		return false // upgrading failed
	
	// debug
	#if UPGRADE_CORE_DEBUG
		PrintFunc()
	#endif

	entity offhandWeapon = titan.GetOffhandWeapon( OFFHAND_RIGHT )
	if ( IsValid( offhandWeapon ) )
	{
		array<string> mods = offhandWeapon.GetMods()
		mods.append( "missile_racks" )
		offhandWeapon.SetMods( mods )
	}

	if ( titan.IsPlayer() )
		Remote_CallFunction_NonReplay( titan, "ServerCallback_VanguardUpgradeMessage", 2 )

	// append passive to received upgrades
	receivedUpgrades.append( ePassives.PAS_VANGUARD_CORE2 )
	UpgradeCore_SetTitanReceivedUpgradePassives( titan, receivedUpgrades )
	return true // upgrading succeeded
}

bool function Upgrade_EnergyTransfer( entity titan )
{
	// anti-crash: don't upgrade again if we already got the same upgrade
	array<int> receivedUpgrades = UpgradeCore_GetTitanReceivedUpgradePassives( titan )
	if ( receivedUpgrades.contains( ePassives.PAS_VANGUARD_CORE3 ) )
		return false // upgrading failed
	
	// debug
	#if UPGRADE_CORE_DEBUG
		PrintFunc()
	#endif

	entity offhandWeapon = titan.GetOffhandWeapon( OFFHAND_LEFT )
	if ( IsValid( offhandWeapon ) )
	{
		array<string> mods = offhandWeapon.GetMods()
		mods.append( "energy_transfer" )
		offhandWeapon.SetMods( mods )
	}

	if ( titan.IsPlayer() )
		Remote_CallFunction_NonReplay( titan, "ServerCallback_VanguardUpgradeMessage", 3 )
	
	// append passive to received upgrades
	receivedUpgrades.append( ePassives.PAS_VANGUARD_CORE3 )
	UpgradeCore_SetTitanReceivedUpgradePassives( titan, receivedUpgrades )
	return true // upgrading succeeded
}

bool function Upgrade_RapidRearm( entity titan )
{
	// anti-crash: don't upgrade again if we already got the same upgrade
	array<int> receivedUpgrades = UpgradeCore_GetTitanReceivedUpgradePassives( titan )
	if ( receivedUpgrades.contains( ePassives.PAS_VANGUARD_CORE4 ) )
		return false // upgrading failed
	
	// debug
	#if UPGRADE_CORE_DEBUG
		PrintFunc()
	#endif

	entity offhandWeapon = titan.GetOffhandWeapon( OFFHAND_ANTIRODEO )
	if ( IsValid( offhandWeapon ) )
	{
		array<string> mods = offhandWeapon.GetMods()
		mods.append( "rapid_rearm" )
		offhandWeapon.SetMods( mods )
	}
	array<entity> weapons = GetPrimaryWeapons( titan )
	if ( weapons.len() > 0 )
	{
		entity primaryWeapon = weapons[0]
		if ( IsValid( primaryWeapon ) )
		{
			array<string> mods = primaryWeapon.GetMods()
			mods.append( "rapid_reload" )
			primaryWeapon.SetMods( mods )
		}
	}

	if ( titan.IsPlayer() )
		Remote_CallFunction_NonReplay( titan, "ServerCallback_VanguardUpgradeMessage", 4 )
	
	// append passive to received upgrades
	receivedUpgrades.append( ePassives.PAS_VANGUARD_CORE4 )
	UpgradeCore_SetTitanReceivedUpgradePassives( titan, receivedUpgrades )
	return true // upgrading succeeded
}

bool function Upgrade_Maelstrom( entity titan )
{
	// anti-crash: don't upgrade again if we already got the same upgrade
	array<int> receivedUpgrades = UpgradeCore_GetTitanReceivedUpgradePassives( titan )
	if ( receivedUpgrades.contains( ePassives.PAS_VANGUARD_CORE5 ) )
		return false // upgrading failed
	
	// debug
	#if UPGRADE_CORE_DEBUG
		PrintFunc()
	#endif

	entity offhandWeapon = titan.GetOffhandWeapon( OFFHAND_INVENTORY )
	if ( IsValid( offhandWeapon ) )
	{
		array<string> mods = offhandWeapon.GetMods()
		mods.append( "maelstrom" )
		offhandWeapon.SetMods( mods )
	}

	if ( titan.IsPlayer() )
		Remote_CallFunction_NonReplay( titan, "ServerCallback_VanguardUpgradeMessage", 5 )
	
	// append passive to received upgrades
	receivedUpgrades.append( ePassives.PAS_VANGUARD_CORE5 )
	UpgradeCore_SetTitanReceivedUpgradePassives( titan, receivedUpgrades )
	return true // upgrading succeeded
}

bool function Upgrade_EnergyField( entity titan )
{
	// anti-crash: don't upgrade again if we already got the same upgrade
	array<int> receivedUpgrades = UpgradeCore_GetTitanReceivedUpgradePassives( titan )
	if ( receivedUpgrades.contains( ePassives.PAS_VANGUARD_CORE6 ) )
		return false // upgrading failed
	
	// debug
	#if UPGRADE_CORE_DEBUG
		PrintFunc()
	#endif

	entity offhandWeapon = titan.GetOffhandWeapon( OFFHAND_LEFT )
	if ( IsValid( offhandWeapon ) )
	{
		array<string> mods = offhandWeapon.GetMods()
		if ( mods.contains( "energy_transfer" ) )
		{
			array<string> mods = offhandWeapon.GetMods()
			mods.fastremovebyvalue( "energy_transfer" )
			mods.append( "energy_field_energy_transfer" )
			offhandWeapon.SetMods( mods )
		}
		else
		{
			array<string> mods = offhandWeapon.GetMods()
			mods.append( "energy_field" )
			offhandWeapon.SetMods( mods )
		}
	}

	if ( titan.IsPlayer() )
		Remote_CallFunction_NonReplay( titan, "ServerCallback_VanguardUpgradeMessage", 6 )

	// append passive to received upgrades
	receivedUpgrades.append( ePassives.PAS_VANGUARD_CORE6 )
	UpgradeCore_SetTitanReceivedUpgradePassives( titan, receivedUpgrades )
	return true // upgrading succeeded
}

bool function Upgrade_MultiTargetMissiles( entity titan )
{
	// anti-crash: don't upgrade again if we already got the same upgrade
	array<int> receivedUpgrades = UpgradeCore_GetTitanReceivedUpgradePassives( titan )
	if ( receivedUpgrades.contains( ePassives.PAS_VANGUARD_CORE7 ) )
		return false // upgrading failed
	
	// debug
	#if UPGRADE_CORE_DEBUG
		PrintFunc()
	#endif

	entity ordnance = titan.GetOffhandWeapon( OFFHAND_RIGHT )
	array<string> mods
	if ( ordnance.HasMod( "missile_racks") )
		mods = [ "upgradeCore_MissileRack_Vanguard" ]
	else
		mods = [ "upgradeCore_Vanguard" ]

	if ( ordnance.HasMod( "fd_balance" ) )
		mods.append( "fd_balance" )

	float ammoFrac = float( ordnance.GetWeaponPrimaryClipCount() ) / float( ordnance.GetWeaponPrimaryClipCountMax() )
	titan.TakeWeaponNow( ordnance.GetWeaponClassName() )
	titan.GiveOffhandWeapon( "mp_titanweapon_shoulder_rockets", OFFHAND_RIGHT, mods )
	ordnance = titan.GetOffhandWeapon( OFFHAND_RIGHT )
	ordnance.SetWeaponChargeFractionForced( 1 - ammoFrac )

	if ( titan.IsPlayer() )
		Remote_CallFunction_NonReplay( titan, "ServerCallback_VanguardUpgradeMessage", 7 )

	// append passive to received upgrades
	receivedUpgrades.append( ePassives.PAS_VANGUARD_CORE7 )
	UpgradeCore_SetTitanReceivedUpgradePassives( titan, receivedUpgrades )
	return true // upgrading succeeded
}

bool function Upgrade_SuperiorChassis( entity titan )
{
	// anti-crash: don't upgrade again if we already got the same upgrade
	array<int> receivedUpgrades = UpgradeCore_GetTitanReceivedUpgradePassives( titan )
	if ( receivedUpgrades.contains( ePassives.PAS_VANGUARD_CORE8 ) )
		return false // upgrading failed
	
	// debug
	#if UPGRADE_CORE_DEBUG
		PrintFunc()
	#endif

	entity soul = titan.GetTitanSoul()
	if ( IsValid( soul ) )
	{
		if ( !GetDoomedState( titan ) )
		{
			if ( titan.IsPlayer() )
			{
				int missingHealth = titan.GetMaxHealth() - titan.GetHealth()
				array<string> settingMods = titan.GetPlayerSettingsMods()
				settingMods.append( "core_health_upgrade" )
				titan.SetPlayerSettingsWithMods( titan.GetPlayerSettings(), settingMods )
				titan.SetHealth( max( titan.GetMaxHealth() - missingHealth, VANGUARD_CORE8_HEALTH_AMOUNT ) )

				//Hacky Hack - Append core_health_upgrade to setFileMods so that we have a way to check that this upgrade is active.
				soul.soul.titanLoadout.setFileMods.append( "core_health_upgrade" )
			}
			else
			{
				titan.SetMaxHealth( titan.GetMaxHealth() + VANGUARD_CORE8_HEALTH_AMOUNT )
				titan.SetHealth( titan.GetHealth() + VANGUARD_CORE8_HEALTH_AMOUNT )
			}
		}
		else
		{
			titan.SetHealth( titan.GetMaxHealth() )
		}

		soul.SetPreventCrits( true )
	}

	if ( titan.IsPlayer() )
		Remote_CallFunction_NonReplay( titan, "ServerCallback_VanguardUpgradeMessage", 8 )

	// append passive to received upgrades
	receivedUpgrades.append( ePassives.PAS_VANGUARD_CORE8 )
	UpgradeCore_SetTitanReceivedUpgradePassives( titan, receivedUpgrades )
	return true // upgrading succeeded
}

bool function Upgrade_XO16BattleRifle( entity titan )
{
	// anti-crash: don't upgrade again if we already got the same upgrade
	array<int> receivedUpgrades = UpgradeCore_GetTitanReceivedUpgradePassives( titan )
	if ( receivedUpgrades.contains( ePassives.PAS_VANGUARD_CORE9 ) )
		return false // upgrading failed

	// debug
	#if UPGRADE_CORE_DEBUG
		PrintFunc()
	#endif

	array<entity> weapons = GetPrimaryWeapons( titan )
	if ( weapons.len() > 0 )
	{
		entity primaryWeapon = weapons[0]
		if ( IsValid( primaryWeapon ) )
		{
			if ( primaryWeapon.HasMod( "arc_rounds" ) )
			{
				primaryWeapon.RemoveMod( "arc_rounds" )
				array<string> mods = primaryWeapon.GetMods()
				mods.append( "arc_rounds_with_battle_rifle" )
				primaryWeapon.SetMods( mods )
			}
			else
			{
				array<string> mods = primaryWeapon.GetMods()
				mods.append( "battle_rifle" )
				mods.append( "battle_rifle_icon" )
				primaryWeapon.SetMods( mods )
			}
		}
	}

	if ( titan.IsPlayer() )
		Remote_CallFunction_NonReplay( titan, "ServerCallback_VanguardUpgradeMessage", 9 )

	// append passive to received upgrades
	receivedUpgrades.append( ePassives.PAS_VANGUARD_CORE9 )
	UpgradeCore_SetTitanReceivedUpgradePassives( titan, receivedUpgrades )
	return true // upgrading succeeded
}
#endif

// modified callbacks
bool function OnCoreCharge_UpgradeCore( entity weapon )
{
	// modded weapon
	if( weapon.HasMod( "shield_core" ) )
		return OnCoreCharge_Shield_Core( weapon )

	return true
}

void function OnCoreChargeEnd_UpgradeCore( entity weapon )
{
	// modded weapon
	if( weapon.HasMod( "shield_core" ) )
		return OnCoreChargeEnd_Shield_Core( weapon )
}
//

#if CLIENT
void function ServerCallback_VanguardUpgradeMessage( int upgradeID )
{
	switch ( upgradeID )
	{
		case 1:
			AnnouncementMessageSweep( GetLocalClientPlayer(), Localize( "#GEAR_VANGUARD_CORE1" ), Localize( "#GEAR_VANGUARD_CORE1_UPGRADEDESC" ), <255, 135, 10> )
			break
		case 2:
			AnnouncementMessageSweep( GetLocalClientPlayer(), Localize( "#GEAR_VANGUARD_CORE2" ), Localize( "#GEAR_VANGUARD_CORE2_UPGRADEDESC" ), <255, 135, 10> )
			break
		case 3:
			AnnouncementMessageSweep( GetLocalClientPlayer(), Localize( "#GEAR_VANGUARD_CORE3" ), Localize( "#GEAR_VANGUARD_CORE3_UPGRADEDESC" ), <255, 135, 10> )
			break
		case 4:
			AnnouncementMessageSweep( GetLocalClientPlayer(), Localize( "#GEAR_VANGUARD_CORE4" ), Localize( "#GEAR_VANGUARD_CORE4_UPGRADEDESC" ), <255, 135, 10> )
			break
		case 5:
			AnnouncementMessageSweep( GetLocalClientPlayer(), Localize( "#GEAR_VANGUARD_CORE5" ), Localize( "#GEAR_VANGUARD_CORE5_UPGRADEDESC" ), <255, 135, 10> )
			break
		case 6:
			AnnouncementMessageSweep( GetLocalClientPlayer(), Localize( "#GEAR_VANGUARD_CORE6" ), Localize( "#GEAR_VANGUARD_CORE6_UPGRADEDESC" ), <255, 135, 10> )
			break
		case 7:
			AnnouncementMessageSweep( GetLocalClientPlayer(), Localize( "#GEAR_VANGUARD_CORE7" ), Localize( "#GEAR_VANGUARD_CORE7_UPGRADEDESC" ), <255, 135, 10> )
			break
		case 8:
			AnnouncementMessageSweep( GetLocalClientPlayer(), Localize( "#GEAR_VANGUARD_CORE8" ), Localize( "#GEAR_VANGUARD_CORE8_UPGRADEDESC" ), <255, 135, 10> )
			break
		case 9:
			AnnouncementMessageSweep( GetLocalClientPlayer(), Localize( "#GEAR_VANGUARD_CORE9" ), Localize( "#GEAR_VANGUARD_CORE9_UPGRADEDESC" ), <255, 135, 10> )
			break
	}
}
#endif

// modified settings
#if SERVER
// allow modifying shield regen amount when using custom shield amount
void function UpgradeCore_SetShieldRegenScale( float scale )
{
	file.shieldRegenScale = scale
}

// allow modifying upgrading method for titan
// not a good idea to use weapon for stroing modified upgrades--- they can be easily destroyed
/*
void function UpgradeCore_SetWeaponUpgradePassive( entity weapon, int upgradeLevel, int passive )
{
	table<int, int> emptyTable
	if ( !( weapon in file.upgradeCorePassivesTable ) )
		file.upgradeCorePassivesTable[ weapon ] <- emptyTable
	
	if ( !( upgradeLevel in file.upgradeCorePassivesTable[ weapon ] ) )
		file.upgradeCorePassivesTable[ weapon ][ upgradeLevel ] <- passive
	else
		file.upgradeCorePassivesTable[ weapon ][ upgradeLevel ] = passive
}

bool function UpgradeCore_WeaponHasModifiedUpgrades( entity weapon )
{
	return ( weapon in file.upgradeCorePassivesTable )
}
*/

void function UpgradeCore_SetTitanUpgradePassive( entity titan, int upgradeLevel, int passive )
{
	entity soul = titan.GetTitanSoul()
	if ( !IsValid( soul ) )
		return
	
	if ( !( upgradeLevel in file.soulUpgradePassivesTable[ soul ] ) )
		file.soulUpgradePassivesTable[ soul ][ upgradeLevel ] <- passive
	else
		file.soulUpgradePassivesTable[ soul ][ upgradeLevel ] = passive
}

void function UpgradeCore_SetTitanUpgradePassivesTable( entity titan, table<int, int> upgradeTable )
{
	entity soul = titan.GetTitanSoul()
	if ( !IsValid( soul ) )
		return

	file.soulUpgradePassivesTable[ soul ] = upgradeTable
}

bool function UpgradeCore_TitanHasModifiedUpgrades( entity titan )
{
	entity soul = titan.GetTitanSoul()
	if ( !IsValid( soul ) )
		return false
	
	return file.soulUpgradePassivesTable[ soul ].len() > 0
}

bool function UpgradeCore_TitanHasUpgradePassiveForLevel( entity titan, int level )
{
	entity soul = titan.GetTitanSoul()
	if ( !IsValid( soul ) )
		return false
	return level in file.soulUpgradePassivesTable[ soul ]
}

int function UpgradeCore_GetTitanModifiedUpgradePassive( entity titan, int level )
{
	entity soul = titan.GetTitanSoul()
	if ( !IsValid( soul ) )
		return -1
	
	if ( !UpgradeCore_TitanHasUpgradePassiveForLevel( titan, level ) ) // level overloaded!
		return -1

	return file.soulUpgradePassivesTable[ soul ][ level ]
}

table<int, int> function UpgradeCore_GetTitanModifiedUpgradesTable( entity titan )
{
	entity soul = titan.GetTitanSoul()
	if ( !IsValid( soul ) )
		return {}
	
	if ( !UpgradeCore_TitanHasModifiedUpgrades( titan ) )
		return {}

	return clone file.soulUpgradePassivesTable[ soul ]
}

void function UpgradeCore_RemoveTitanModifiedUpgrades( entity titan )
{
	entity soul = titan.GetTitanSoul()
	if ( !IsValid( soul ) )
		return

	file.soulUpgradePassivesTable[ soul ] = {} // clean up
}

int function UpgradeCore_GetTitanUpgradeCount( entity titan )
{
	entity soul = titan.GetTitanSoul()
	if ( !IsValid( soul ) )
		return 0

	return file.soulUpgradeCount[ soul ]
}

void function UpgradeCore_SetTitanUpgradeCount( entity titan, int upgradeCount )
{
	entity soul = titan.GetTitanSoul()
	if ( !IsValid( soul ) )
		return

	file.soulUpgradeCount[ soul ] = upgradeCount
}

array<int> function UpgradeCore_GetTitanReceivedUpgradePassives( entity titan )
{
	entity soul = titan.GetTitanSoul()
	if ( !IsValid( soul ) )
		return []

	return file.soulReceivedUpgradePassives[ soul ]
}

void function UpgradeCore_SetTitanReceivedUpgradePassives( entity titan, array<int> upgradePassives )
{
	entity soul = titan.GetTitanSoul()
	if ( !IsValid( soul ) )
		return

	file.soulReceivedUpgradePassives[ soul ] = upgradePassives
}

// function for fun
void function UpgradeCore_GenerateRandomUpgradesForTitan( entity titan, int maxLevel, int maxStage )
{
	array<int> firstStagePassives = 
	[
		ePassives.PAS_VANGUARD_CORE1,
		ePassives.PAS_VANGUARD_CORE2,
		ePassives.PAS_VANGUARD_CORE3,
	]

	array<int> secondStagePassives =
	[
		ePassives.PAS_VANGUARD_CORE4,
		ePassives.PAS_VANGUARD_CORE5,
		ePassives.PAS_VANGUARD_CORE6,
	]

	array<int> thirdStagePassives =
	[
		ePassives.PAS_VANGUARD_CORE7,
		ePassives.PAS_VANGUARD_CORE8,
		ePassives.PAS_VANGUARD_CORE9,
	]

	int upgradesPerStage = ( maxLevel + 1 ) / maxStage
	if ( upgradesPerStage < 1 )
		upgradesPerStage = 1
	
	int currentLevel = 0

	for ( int i = 0; i < upgradesPerStage; i++ )
	{
		int passive = firstStagePassives.getrandom()
		firstStagePassives.removebyvalue( passive )

		UpgradeCore_SetTitanUpgradePassive( titan, currentLevel, passive )

		currentLevel += 1
		if ( currentLevel > maxLevel )
			return

		if ( firstStagePassives.len() == 0 )
			break
	}

	for ( int i = 0; i < upgradesPerStage; i++ )
	{
		int passive = secondStagePassives.getrandom()
		secondStagePassives.removebyvalue( passive )
		
		UpgradeCore_SetTitanUpgradePassive( titan, currentLevel, passive )
		
		currentLevel += 1
		if ( currentLevel > maxLevel )
			return

		if ( secondStagePassives.len() == 0 )
			break
	}

	for ( int i = 0; i < upgradesPerStage; i++ )
	{
		int passive = thirdStagePassives.getrandom()
		thirdStagePassives.removebyvalue( passive )
		
		UpgradeCore_SetTitanUpgradePassive( titan, currentLevel, passive )
		
		currentLevel += 1
		if ( currentLevel > maxLevel )
			return

		if ( thirdStagePassives.len() == 0 )
			break
	}
}
#endif