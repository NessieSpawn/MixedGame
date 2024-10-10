untyped
global function OnWeaponPrimaryAttack_shotgun_doublebarrel

#if SERVER
global function OnWeaponNpcPrimaryAttack_shotgun_doublebarrel
#endif // #if SERVER

// modified callback
global function OnWeaponActivate_weapon_shotgun_doublebarrel
global function OnWeaponDeactivate_weapon_shotgun_doublebarrel

const SHOTGUN_DOUBLEBARREL_MAX_BOLTS = 8 // this is the code limit for bolts per frame... do not increase.

struct
{
	float[2][SHOTGUN_DOUBLEBARREL_MAX_BOLTS] boltOffsets = [
		[0.4, 0.8], // right
		[0.4, -0.8], // left
		[0.0, 0.65],
		[0.0, -0.65],
		[0.4, 0.2],
		[0.4, -0.2],
		[0.0, 0.2],
		[0.0, -0.2],
	]

	int maxAmmo
	float ammoRegenTime
} file

var function OnWeaponPrimaryAttack_shotgun_doublebarrel( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	#if CLIENT
		weapon.EmitWeaponSound( "Weapon_Titan_Sniper_LevelTick_2" )
	#endif

	return FireWeaponPlayerAndNPC( attackParams, true, weapon )
}

#if SERVER
var function OnWeaponNpcPrimaryAttack_shotgun_doublebarrel( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	return FireWeaponPlayerAndNPC( attackParams, false, weapon )
}
#endif // #if SERVER

function FireWeaponPlayerAndNPC( WeaponPrimaryAttackParams attackParams, bool playerFired, entity weapon )
{
	entity owner = weapon.GetWeaponOwner()
	bool shouldCreateProjectile = false
	if ( IsServer() || weapon.ShouldPredictProjectiles() )
		shouldCreateProjectile = true
	#if CLIENT
		if ( !playerFired )
			shouldCreateProjectile = false
	#endif

	vector attackAngles = VectorToAngles( attackParams.dir )
	vector baseUpVec = AnglesToUp( attackAngles )
	vector baseRightVec = AnglesToRight( attackAngles )

	if ( shouldCreateProjectile )
	{
		weapon.EmitWeaponNpcSound( LOUD_WEAPON_AI_SOUND_RADIUS_MP, 0.2 )

		for ( int index = 0; index < SHOTGUN_DOUBLEBARREL_MAX_BOLTS; index++ )
		{
			vector upVec = baseUpVec * file.boltOffsets[index][0] * 0.05 * RandomFloatRange( 1.2, 1.7 )
			vector rightVec = baseRightVec * file.boltOffsets[index][1] * 0.05 * RandomFloatRange( 1.2, 1.7 )

			vector attackDir = attackParams.dir + upVec + rightVec
			float projectileSpeed = 2800

			// remove all meaningless codes...
			//if ( weapon.GetWeaponClassName() == "mp_weapon_shotgun_doublebarrel" )
			//	{
					attackDir = attackParams.dir
					projectileSpeed = 3800
			//	}

			entity bolt = FireWeaponBolt_RecordData( weapon, attackParams.pos, attackDir, projectileSpeed, damageTypes.largeCaliber | DF_SHOTGUN, damageTypes.largeCaliber | DF_SHOTGUN, playerFired, index )
			if ( bolt )
			{
				bolt.kv.gravity = 0.4 // 0.09

				// remove all meaningless codes...
				//if ( weapon.GetWeaponClassName() == "mp_weapon_shotgun_doublebarrel" )
					bolt.SetProjectileLifetime( RandomFloatRange( 1.0, 1.3 ) )
				//else
				//	bolt.SetProjectileLifetime( RandomFloatRange( 0.50, 0.65 ) )

				// modded npc weapon!!!
				if ( weapon.HasMod( "projectile_shotgun_npc" ) )
				{
					// fix effect
					StartParticleEffectOnEntity( bolt, GetParticleSystemIndex( $"P_mastiff_proj_amp" ), FX_PATTACH_ABSORIGIN_FOLLOW, -1 )
					EmitSoundOnEntity( bolt, "wpn_leadwall_projectile_crackle" )
				}
			}
		}
	}

	return 2
}

// modified callback
void function OnWeaponActivate_weapon_shotgun_doublebarrel( entity weapon )
{
	// update model for other players on npc use
	#if SERVER
		entity owner = weapon.GetWeaponOwner()
		if ( IsValid( owner ) && !owner.IsPlayer() )
			CreateFakeModelForDoubleBarrelShotgun( weapon )
	#endif
}

void function OnWeaponDeactivate_weapon_shotgun_doublebarrel( entity weapon )
{

}

#if SERVER
// modified content: adding fake model for fake weapons
// can't get eWeaponVar.playermodel... currently hardcode
const asset DOUBLE_BARREL_SHOTGUN_MODEL = $"models/weapons/shotgun_doublebarrel/w_shotgun_doublebarrel.md"
const table< string, asset > FAKE_MODEL_MODS =
{
	["tfo_doublebarrel_shotgun"] = DOUBLE_BARREL_SHOTGUN_MODEL,
	["fake_tf1_sprint_anim_active"] = DOUBLE_BARREL_SHOTGUN_MODEL, // this one is replacement mod, needs to handle as well
}

void function CreateFakeModelForDoubleBarrelShotgun( entity weapon )
{
	string fakeModelMod = ""
	array<string> mods = weapon.GetMods()
	foreach ( mod in mods )
	{
		if ( mod in FAKE_MODEL_MODS )
		{
			//print( "Found fakemodel mod!" )
			fakeModelMod = mod
			break
		}
	}

	if ( fakeModelMod == "" )
	{
		//print( "Can't find fakemodel mod!" )
		return
	}

	// can't get eWeaponVar.playermodel... currently hardcode
	asset model = FAKE_MODEL_MODS[ fakeModelMod ]
	// shared utility from _fake_world_weapon_model.gnut
	entity fakeModel = FakeWorldModel_CreateForWeapon( weapon, model )
}
#endif