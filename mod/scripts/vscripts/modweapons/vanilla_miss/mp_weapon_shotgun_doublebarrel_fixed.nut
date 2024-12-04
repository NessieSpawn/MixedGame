global function MpWeaponShotgunDoubleBarrel_Init

const array<string> TFO_DOUBLE_BARREL_SHOTGUN_MODS =
[
    "tfo_doublebarrel_shotgun",
    "fake_tf1_sprint_anim_active",
]

void function MpWeaponShotgunDoubleBarrel_Init()
{
    #if SERVER
        foreach ( string mod in TFO_DOUBLE_BARREL_SHOTGUN_MODS )
        {
            // modified settings
            FakeWorldModel_AddModToAutoReplaceModel(
                "mp_weapon_shotgun_doublebarrel",
                mod,
                "models/weapons/shotgun_doublebarrel/w_shotgun_doublebarrel.mdl",
                "PROPGUN",
                1.0,
                1.0,
                true
            )
        }
    #endif
}