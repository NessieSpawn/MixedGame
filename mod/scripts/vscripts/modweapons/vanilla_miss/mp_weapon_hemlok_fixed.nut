global function MpWeaponHemlok_Init

global function OnWeaponPrimaryAttack_hemlok

const float HEMLOK_FIRE_SOUND_RATE = 15.5 // hemlok sound is designed for 15.5 fire rate

void function MpWeaponHemlok_Init()
{
#if SERVER
    // burnmod replace -- WIP, tempraroly just disable burn mods for them
	//ModdedBurnMods_AddReplacementBurnMod( "starburst", "burn_mod_modded_hemlok" )
    //ModdedBurnMods_AddReplacementBurnMod( "lmg", "burn_mod_modded_hemlok" )

    // burnmod blacklist
    ModdedBurnMods_AddDisabledMod( "starburst" )
	ModdedBurnMods_AddDisabledMod( "lmg" )
#endif

    // sound fix signals
    RegisterSignal( "HemlokWeaponFire" )
}

var function OnWeaponPrimaryAttack_hemlok( entity weapon, WeaponPrimaryAttackParams attackParams )
{
    // weapon firing
    weapon.EmitWeaponNpcSound( LOUD_WEAPON_AI_SOUND_RADIUS_MP, 0.2 )
	weapon.FireWeaponBullet( attackParams.pos, attackParams.dir, 1, weapon.GetWeaponDamageFlags() )

    // sound fix for firing non-3-round burst
    // works pretty bad, let's just use npc firing sound
    if ( weapon.GetWeaponBurstFireCount() != 3 )
    {
        //thread HemlokFiringSoundFix( weapon )
        #if SERVER
            if ( !weapon.IsBurstFireInProgress() )
            {
                //print( "first burst!" )
                StopSoundOnEntity( weapon, "Weapon_Hemlok_FirstShot_3P" )
            }
            entity owner = weapon.GetWeaponOwner()
            if ( IsValid( owner ) && owner.IsPlayer() )
                EmitSoundOnEntityExceptToPlayer( weapon, owner, "Weapon_Hemlok_FirstShot_npc" )
            else
                EmitSoundOnEntity( weapon, "Weapon_Hemlok_FirstShot_npc" )
        #endif
    }
}

void function HemlokFiringSoundFix( entity weapon )
{
    weapon.EndSignal( "OnDestroy" )

    weapon.Signal( "HemlokWeaponFire" )
    weapon.EndSignal( "HemlokWeaponFire" )

    float oneShotDuration = ( 1.0 / HEMLOK_FIRE_SOUND_RATE ) + 0.04 // calculate sound duration for firing 1 shot

    wait oneShotDuration
    #if CLIENT
        // sounds better?
        // I don't think so...
        //StopSoundOnEntity( weapon, "Weapon_Hemlok_FirstShot_1P" )
        //FadeOutSoundOnEntity( weapon, "Weapon_Hemlok_FirstShot_1P", 1.0 )
    #endif
    StopSoundOnEntity( weapon, "Weapon_Hemlok_FirstShot_3P" )
}