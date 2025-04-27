
// modified callbacks
global function OnWeaponOwnerChanged_gunship_missile
global function OnWeaponActivate_gunship_missile
global function OnWeaponPrimaryAttack_gunship_missile

#if SERVER
global function OnWeaponNpcPrimaryAttack_gunship_missile
#endif // SERVER

// include all mods that converts primary attack into melee!
const array<string> MELEE_CONVERTOR_MODS = 
[
	"melee_convertor",
	"pilot_sword_primary",
	"titan_electric_fist_primary",
]

// modified callbacks
void function OnWeaponOwnerChanged_gunship_missile( entity weapon, WeaponOwnerChangedParams changeParams )
{
	// disable run_and_gun on server-side
	#if SERVER
	Disable_RunAndGun_ServerSide( weapon, changeParams )
	#endif
}

void function OnWeaponActivate_gunship_missile( entity weapon )
{
#if SERVER
	CreateModelForFakeMeleePrimary( weapon )
#endif
}

var function OnWeaponPrimaryAttack_gunship_missile( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	entity owner = weapon.GetWeaponOwner()
	// fake primary melee
	if ( IsValid( owner ) && owner.IsPlayer() )
	{
		// clinet can't sync melee_sound_attack_1p when this is triggered
		#if SERVER // server-side only, for better ads blend
			//if ( weapon.GetWeaponSettingBool( eWeaponVar.attack_button_presses_melee ) )
			bool shouldPressMelee = false
			foreach ( mod in MELEE_CONVERTOR_MODS )
			{
				if ( weapon.HasMod( mod ) )
				{
					shouldPressMelee = true
					break
				}
			}
			if ( shouldPressMelee )
			{
				// hopefully fix everything related with melee...
				CodeCallback_OnMeleePressed( owner )
				return 0 // never consume any ammo
			}
		#endif

		// fake primary melee weapon
		// melee sound now handled by melee weapon themselves!
		/*
		#if SERVER
			if ( GetWeaponFakePilotPrimaryMod( weapon ) != "" )
				FakeMeleeWeaponSound( weapon )
		#endif // SERVER
		*/
	}
}

#if SERVER
var function OnWeaponNpcPrimaryAttack_gunship_missile( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	//self.EmitWeaponSound( "Weapon_ARL.Single" )
	// removing scripted firing sound now, try to use settings file
	//weapon.EmitWeaponSound( "ShoulderRocket_Salvo_Fire_3P" )

	// manually play another muzzle flash fx
    weapon.PlayWeaponEffect( $"", $"wpn_muzzleflash_40mm", "muzzle_flash" )

	weapon.EmitWeaponNpcSound( LOUD_WEAPON_AI_SOUND_RADIUS_MP, 0.2 )

	// this function is already pure server-side...
	//#if SERVER
		entity missile = FireWeaponMissile_RecordData( weapon, attackParams.pos, attackParams.dir, 1, damageTypes.largeCaliberExp, damageTypes.largeCaliberExp, false, PROJECTILE_NOT_PREDICTED )
		if ( missile )
		{
			// change every projectile sound to be sync with client!
			// this function is pure server-side though...
			EmitSoundOnEntity( missile, "Weapon_Sidwinder_Projectile" )
			missile.InitMissileForRandomDriftFromWeaponSettings( attackParams.pos, attackParams.dir )
		
			// modified damageSourceId in mp_weapon_gunship_missile_fixed.nut, fixes display name
			missile.ProjectileSetDamageSourceID( eDamageSourceId.mp_weapon_gunship_missile_fixed )
		}
	//#endif
}
#endif // #if SERVER


#if SERVER
// modified content: adding fake model for fake weapons
// can't get eWeaponVar.playermodel... currently hardcode
const table< string, asset > FAKE_PILOT_PRIMARY_MODS =
{
	["pilot_sword_primary"] = $"models/weapons/bolo_sword/w_bolo_sword.mdl"
}

string function GetWeaponFakePilotPrimaryMod( entity weapon )
{
	array<string> mods = weapon.GetMods()
	foreach ( mod in mods )
	{
		if ( mod in FAKE_PILOT_PRIMARY_MODS )
		{
			//print( "Found fakemodel mod!" )
			return mod
		}
	}

	return ""
}

void function CreateModelForFakeMeleePrimary( entity weapon )
{
	string fakeModelMod = GetWeaponFakePilotPrimaryMod( weapon )
	if ( fakeModelMod == "" )
	{
		//print( "Can't find fakemodel mod!" )
		return
	}

	// can't get eWeaponVar.playermodel... currently hardcode
	asset model = FAKE_PILOT_PRIMARY_MODS[ fakeModelMod ]
	// shared utility from _fake_world_weapon_model.gnut
	// this will create 2 swords in hand, guess no need to handle
	//FakeWorldModel_CreateForWeapon( weapon, model, "L_HAND", true, true ) // PROPGUN will change position when player melee, L_HAND is just good for melee animation!
	FakeWorldModel_CreateForWeapon( weapon, model )
}

void function FakeMeleeWeaponSound( entity weapon )
{
    entity owner = weapon.GetWeaponOwner()
    EmitSoundOnEntityOnlyToPlayer( weapon, owner, "Pilot_Mvmt_Melee_RightHook_1P" )
}
#endif // SERVER