# Sandbox

Every Sandbox number, generated from `resources/weapons/`, `resources/sandbox.tres`, `resources/gunnery/` and `resources/attachments/`. Do not edit by hand: change numbers in the in-Raid sheet (F1, debug builds) and Save, or edit the resources and run `flatpak run org.godotengine.Godot --headless --path . --script res://scripts/sandbox/write_sandbox_doc.gd`. Rows marked `=` are derived.

## Weapons

| | Pistol | Assault Rifle | Shotgun | Marksman Rifle |
|---|---|---|---|---|
| **Trigger** | | | | |
| Semi Auto | true | false | true | true |
| Fire Interval | 0.12 | 0.09 | 0.8 | 0.4 |
| **Magazine** | | | | |
| Magazine Size | 12 | 30 | 6 | 8 |
| Reload Tactical | 1.2 | 1.8 | 2.4 | 2.0 |
| Reload Empty | 1.6 | 2.3 | 2.4 | 2.4 |
| Shell Reload | false | false | true | false |
| First Shell Time | 0.55 | 0.55 | 0.55 | 0.55 |
| Shell Time | 0.45 | 0.45 | 0.45 | 0.45 |
| Closing Pump Time | 0.45 | 0.45 | 0.45 | 0.45 |
| Break Out Time | 0.25 | 0.25 | 0.25 | 0.25 |
| **Projectile** | | | | |
| Pellet Count | 1 | 1 | 12 | 1 |
| Damage | 25 | 25 | 13 | 50 |
| Headshot Multiplier | 1.5 | 1.0 | 1.0 | 2.0 |
| Projectile Speed | 80.0 | 100.0 | 60.0 | 200.0 |
| Projectile Lifetime | 0.5 | 0.5 | 0.25 | 0.4 |
| **Spread** | | | | |
| Spread Base Degrees | 1.0 | 1.2 | 5.0 | 3.0 |
| Bloom Per Shot Degrees | 0.5 | 0.3 | 0.0 | 1.0 |
| Bloom Decay Seconds | 0.3 | 0.35 | 0.3 | 0.5 |
| Spread Crouch | 0.7 | 0.7 | 1.0 | 0.8 |
| Spread Still | 1.0 | 1.0 | 1.0 | 1.0 |
| Spread Walking | 1.2 | 1.3 | 1.0 | 1.5 |
| Spread Slide | 1.5 | 1.6 | 1.0 | 2.0 |
| Spread Air | 1.5 | 1.8 | 1.3 | 2.0 |
| **Aim Down Sights** | | | | |
| Ads Spread | 0.5 | 0.45 | 0.8 | 0.0167 |
| Ads Moving Spread | 0.6 | 0.585 | 0.8 | 0.4 |
| Ads Sway Degrees | 0.0 | 0.0 | 0.0 | 0.25 |
| Ads Zoom | 1.6 | 1.6 | 1.15 | 3.0 |
| Ads Speed | 0.8 | 0.7 | 0.85 | 0.6 |
| Aim Time | 0.15 | 0.22 | 0.22 | 0.32 |
| **Weapon Wheel** | | | | |
| Swap Time | 0.3 | 0.4 | 0.45 | 0.5 |
| **Recoil** | | | | |
| Recoil Push | 0.05 | 0.035 | 0.09 | 0.05 |
| Recoil Kick Degrees | 7.0 | 3.0 | 11.0 | 5.0 |
| Ads Recoil Push | 0.05 | 0.03 | 0.07 | 0.05 |
| Ads Recoil Kick Degrees | 7.0 | 0.0 | 6.0 | 0.0 |
| Camera Kick Degrees | 1.2 | 0.5 | 3.0 | 1.6 |
| Fire Clip | fire | - | - | - |
| **Sound** | | | | |
| Shot Sounds | kurt_22_magnum/shot_1.ogg, kurt_22_magnum/shot_2.ogg, kurt_22_magnum/shot_3.ogg | kurt_gunshots/shot_1.ogg, kurt_gunshots/shot_2.ogg, kurt_gunshots/shot_3.ogg, kurt_gunshots/shot_4.ogg | firearm_library_shotgun/shot.ogg | firearm_library_marksman/shot.ogg |
| Reload Sounds | oga_reload/clipload1.ogg, oga_reload/clipload2.ogg | oga_reload/clipload1.ogg, oga_reload/clipload2.ogg | oga_shotgun_reload/shell_in.ogg | oga_gun_reload_sounds/rifle_magazine_out.ogg, oga_gun_reload_sounds/rifle_magazine_in.ogg |
| Action Sound | - | - | shotgun_pump.ogg | - |
| Action Sound Delay | 0.0 | 0.0 | 0.2 | 0.0 |
| Suppressed Shot Sounds | suppressed_shots/pistol_suppressed.ogg | suppressed_shots/assault_rifle_suppressed.ogg | - | suppressed_shots/marksman_rifle_suppressed.ogg |
| Loudness | 24.0 | 24.0 | 32.0 | 24.0 |
| **Crew** | | | | |
| Conspicuous | 1.0 | 1.0 | 1.0 | 1.0 |
| **Attachments** | | | | |
| Fits | attachments/reflex_sight.tres, attachments/suppressor.tres, attachments/extended_magazine.tres, attachments/quick_magazine.tres, attachments/laser.tres | attachments/reflex_sight.tres, attachments/combat_scope.tres, attachments/suppressor.tres, attachments/long_barrel.tres, attachments/short_barrel.tres, attachments/extended_magazine.tres, attachments/quick_magazine.tres, attachments/drum.tres, attachments/foregrip.tres, attachments/laser.tres, attachments/bipod.tres, attachments/heavy_stock.tres, attachments/light_stock.tres | attachments/reflex_sight.tres, attachments/long_barrel.tres, attachments/short_barrel.tres, attachments/foregrip.tres, attachments/laser.tres, attachments/heavy_stock.tres, attachments/light_stock.tres | attachments/long_scope.tres, attachments/suppressor.tres, attachments/long_barrel.tres, attachments/extended_magazine.tres, attachments/quick_magazine.tres, attachments/foregrip.tres, attachments/bipod.tres, attachments/heavy_stock.tres, attachments/light_stock.tres |
| **Viewmodel** | | | | |
| Model | pistol_model.tscn | assault_rifle_model.tscn | shotgun_model.tscn | marksman_rifle_model.tscn |
| Pose Hip | (0.16, -0.18, -0.3) | (0.13, -0.19, -0.4) | (0.15, -0.24, -0.34) | (0.15, -0.2, -0.36) |
| Pose Low | (0.2, -0.26, -0.3) | (0.2, -0.3, -0.38) | (0.21, -0.36, -0.32) | (0.21, -0.32, -0.36) |
| Ads Distance | 0.32 | 0.265 | 0.3 | 0.36 |
| Model Fire Clip | fire | fire | fire | fire |
| Model Reload Clip | reload | reload | shell | reload |
| Model Rack Clip | rack | rack | pump | rack |
| Fire Cycle Time | 0.15 | 0.08 | 0.55 | 0.15 |
| Rack Time | 0.3 | 0.35 | 0.3 | 0.3 |
| **Derived** | | | | |
| = Reach (m) | 40.0 | 50.0 | 15.0 | 80.0 |
| = Damage per shot | 25 | 25 | 156 | 50 |
| = Shots to kill crew | 4 | 4 | 1 | 2 |
| = Shots to kill crew by Headshot | 3 | 4 | 1 | 1 |
| = Pellets to kill crew | - | - | 8 | - |
| = Seconds to kill crew (from a full magazine) | 0.36 | 0.27 | 0.0 | 0.4 |
| = Shots per second | 8.3333 | 11.1111 | 1.25 | 2.5 |
| = Seconds from empty to full | 1.6 | 2.3 | 3.25 | 2.4 |

## Health and Melee

| | Value |
|---|---|
| **Health** | |
| Pirate Health | 150 |
| Crew Health | 100 |
| **Melee** | |
| Melee Damage | 75 |

Melee from behind (inside the 120.0 degree cone behind the target's facing) kills outright, whatever the damage.

## Gunnery

| | Pistol | Assault Rifle | Shotgun | Marksman Rifle |
|---|---|---|---|---|
| **Aim** | | | | |
| Aim Error Degrees | 7.5 | 6.0 | 8.0 | 0.0 |
| Opening Spread | 3.0 | 3.0 | 3.0 | 3.0 |
| Closing Time | 2.0 | 2.0 | 2.0 | 2.0 |
| Lead | 0.3 | 0.5 | 0.0 | 1.0 |
| **Bursts** | | | | |
| Shots Per Burst Low | 2 | 3 | 1 | 1 |
| Shots Per Burst High | 3 | 5 | 1 | 1 |
| Bursts Per Peek | 1 | 2 | 1 | 1 |
| Gap Between Bursts Low | 0.0 | 0.4 | 0.0 | 0.0 |
| Gap Between Bursts High | 0.0 | 0.8 | 0.0 | 0.0 |
| Time Down Low | 1.0 | 1.5 | 1.2 | 2.5 |
| Time Down High | 2.0 | 2.5 | 1.5 | 4.0 |
| Settle | 0.35 | 0.35 | 0.35 | 0.9 |
| **Range** | | | | |
| Range Near | 4.0 | 5.0 | 2.0 | 8.0 |
| Range Far | 8.0 | 10.0 | 5.0 | 14.0 |
| Hold Before Shifting | 4.0 | 8.0 | 4.0 | -1.0 |
| **Reload** | | | | |
| Reload Factor | 1.5 | 1.5 | 1.5 | 1.5 |

A Guard fires the gun it rolled at ship build: that weapon's damage, projectile, pellets, time between shots and sounds. Aim error adds to the weapon's base cone. Each Guard draws its own 0.75-1.35x on time between shots at spawn. Read today: aim error, shots per burst and time down; the other fields wait for the cover, fair fire and habit rules.

## Attachments

| | Combat Scope | Long Scope | Reflex Sight | Long Barrel | Short Barrel | Suppressor | Drum | Extended Magazine | Quick Magazine | Bipod | Foregrip | Laser | Heavy Stock | Light Stock |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Magazine Size |  |  |  |  |  |  | 2.5 | 1.5 | 0.8 |  |  |  |  |  |
| Reload Tactical |  |  |  |  |  |  | 1.6 | 1.25 | 0.7 |  |  |  |  |  |
| Reload Empty |  |  |  |  |  |  | 1.6 | 1.25 | 0.7 |  |  |  |  |  |
| Projectile Speed |  |  |  | 1.25 | 0.85 | 0.8 |  |  |  |  |  |  |  |  |
| Spread Base Degrees |  |  |  | 0.85 | 1.25 |  |  |  |  |  |  | 0.7 |  |  |
| Spread Crouch |  |  |  |  |  |  |  |  |  | 0.5 |  |  |  |  |
| Ads Spread | 0.75 |  |  |  |  |  |  |  |  |  |  | 1.4286 |  |  |
| Ads Moving Spread |  |  |  |  |  |  |  |  |  |  |  | 1.4286 | 0.8 |  |
| Ads Sway Degrees |  | 1.5 |  |  |  |  |  |  |  | 0.5 |  |  | 0.6 | 1.3 |
| Ads Zoom | 1.55 | 1.67 | 0.85 |  |  |  |  |  |  |  |  |  |  |  |
| Ads Speed | 0.85 |  | 1.1 |  |  |  |  |  |  |  |  |  | 0.85 | 1.15 |
| Aim Time | 1.3 | 1.35 | 0.8 | 1.2 | 0.8 |  | 1.25 |  |  | 1.2 | 1.15 |  | 1.2 | 0.8 |
| Swap Time |  |  |  | 1.2 | 0.8 |  | 1.3 |  |  | 1.2 |  |  |  | 0.8 |
| Recoil Kick Degrees |  |  |  |  |  |  |  |  |  |  | 0.7 |  |  | 1.25 |
| Ads Recoil Kick Degrees |  |  |  |  |  |  |  |  |  |  | 0.7 |  |  |  |
| Camera Kick Degrees |  |  |  |  |  |  |  |  |  |  | 0.7 |  |  |  |
| Loudness |  |  |  |  |  | 0.4 |  |  |  |  |  |  |  |  |
| Conspicuous |  |  |  |  |  |  |  |  |  |  |  | 1.3 |  |  |

Each cell multiplies that attribute of the gun the Attachment is fitted to; blank changes nothing. Two on one attribute multiply. A whole-number attribute rounds and never goes under 1; times and spreads never go under 0; zoom never under 1.
