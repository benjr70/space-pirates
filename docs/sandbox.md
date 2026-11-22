# Sandbox

Every Sandbox number, generated from `resources/weapons/` and `resources/sandbox.tres`. Do not edit by hand: change numbers in the in-Raid sheet (F1, debug builds) and Save, or edit the resources and run `flatpak run org.godotengine.Godot --headless --path . --script res://scripts/sandbox/write_sandbox_doc.gd`. Rows marked `=` are derived.

## Weapons

| | Pistol | Assault Rifle |
|---|---|---|
| **Trigger** | | |
| Semi Auto | true | false |
| Fire Interval | 0.12 | 0.09 |
| **Magazine** | | |
| Magazine Size | 12 | 30 |
| Reload Tactical | 1.2 | 1.8 |
| Reload Empty | 1.6 | 2.3 |
| **Projectile** | | |
| Damage | 25 | 25 |
| Projectile Speed | 80.0 | 100.0 |
| Projectile Lifetime | 0.5 | 0.5 |
| **Spread** | | |
| Spread Base Degrees | 1.0 | 1.2 |
| Bloom Per Shot Degrees | 0.5 | 0.3 |
| Bloom Decay Seconds | 0.3 | 0.35 |
| Spread Crouch | 0.7 | 0.7 |
| Spread Still | 1.0 | 1.0 |
| Spread Walking | 1.2 | 1.3 |
| Spread Slide | 1.5 | 1.6 |
| Spread Air | 1.5 | 1.8 |
| **Aim Down Sights** | | |
| Ads Spread | 0.5 | 0.45 |
| Ads Zoom | 1.6 | 1.6 |
| Ads Speed | 0.8 | 0.7 |
| **Recoil** | | |
| Recoil Push | 0.05 | 0.035 |
| Recoil Kick Degrees | 7.0 | 3.0 |
| Ads Recoil Push | 0.05 | 0.03 |
| Ads Recoil Kick Degrees | 7.0 | 0.0 |
| Camera Kick Degrees | 1.2 | 0.5 |
| Fire Clip | fire | - |
| **Viewmodel** | | |
| Model | pistol_model.tscn | assault_rifle_model.tscn |
| Pose Hip | (0.16, -0.18, -0.3) | (0.13, -0.19, -0.4) |
| Pose Low | (0.2, -0.26, -0.3) | (0.2, -0.3, -0.38) |
| Ads Distance | 0.32 | 0.265 |
| Model Fire Clip | fire | fire |
| Model Reload Clip | reload | reload |
| Model Rack Clip | rack | rack |
| Fire Cycle Time | 0.15 | 0.08 |
| Rack Time | 0.3 | 0.35 |
| **Derived** | | |
| = Reach (m) | 40.0 | 50.0 |
| = Damage per shot | 25 | 25 |
| = Shots to kill crew | 4 | 4 |
| = Seconds to kill crew (from a full magazine) | 0.36 | 0.27 |
| = Shots per second | 8.3333 | 11.1111 |

## Health and Melee

| | Value |
|---|---|
| **Health** | |
| Pirate Health | 150 |
| Crew Health | 100 |
| **Melee** | |
| Melee Damage | 75 |

Melee from behind (inside the 120.0 degree cone behind the target's facing) kills outright, whatever the damage.
