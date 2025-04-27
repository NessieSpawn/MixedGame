global function MpWeaponSword_Init

global function OnWeaponActivate_weapon_sword

void function MpWeaponSword_Init()
{

}

void function OnWeaponActivate_weapon_sword( entity weapon )
{
    #if SERVER
        entity owner = weapon.GetWeaponOwner()
        // try to fix sound on melee attack!
        if ( IsAlive( owner ) && !weapon.HasMod( "allow_as_primary" ) )
        {
            string sound = "Pilot_Mvmt_Melee_RightHook_1P"
            // sword don't have mid-air sound
            //if ( !owner.IsOnGround() ) // mid-air slash
            //    sound = "Pilot_Mvmt_Melee_AirKick_1P"
            EmitSoundOnEntityOnlyToPlayer( weapon, owner, sound )
        }
    #endif // CLIENT   
}