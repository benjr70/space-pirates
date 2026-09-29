class_name WeaponProfile
extends Resource
## Every number that makes a weapon what it is, so a second weapon is a data
## file and a weapon modifier is a field. The Sidearm is
## `resources/weapons/sidearm.tres`; the Pirate reads whichever Profile he
## holds and never keeps a weapon number of his own.

@export_group("Trigger")
## One shot per press: holding the trigger never repeats. Off, the trigger
## fires again every `fire_interval` while held.
@export var semi_auto := true
## Seconds between shots, held or tapped.
@export var fire_interval := 0.12

@export_group("Magazine")
## Rounds per magazine. Reserves are infinite until the loot system says otherwise.
@export var magazine_size := 12
## Seconds to swap a magazine with rounds still in it.
@export var reload_tactical := 1.2
## Seconds to reload a dry magazine, which also has to be racked.
@export var reload_empty := 1.6

@export_group("Projectile")
## Flat damage per hit: no headshots.
@export var damage := 1
@export var projectile_speed := 80.0
## Seconds a shot flies before it gives up.
@export var projectile_lifetime := 0.5

@export_group("Spread")
## Half-angle of the cone shots scatter inside, before bloom and state.
@export var spread_base_degrees := 1.0
## Each shot widens the cone by this much.
@export var bloom_per_shot_degrees := 0.5
## Seconds for one shot's bloom to decay to nothing, linearly.
@export var bloom_decay_seconds := 0.3
## Multipliers on the cone by what the Pirate is doing.
@export var spread_crouch := 0.7
@export var spread_still := 1.0
@export var spread_walking := 1.2
@export var spread_slide := 1.5
@export var spread_air := 1.5

@export_group("Aim Down Sights")
## Multiplier on the cone while aimed.
@export var ads_spread := 0.5
## Magnification while aimed.
@export var ads_zoom := 1.3
## Multiplier on walking speed while aimed.
@export var ads_speed := 0.8

@export_group("Viewmodel")
## The weapon mesh's own skeleton clips, by name on its AnimationPlayer.
@export var model_fire_clip: StringName = &"PistolArmature|Fire"
@export var model_reload_clip: StringName = &"PistolArmature|Reload"
## Racks the slide to close an empty reload; blank for a weapon without one.
@export var model_rack_clip: StringName = &"PistolArmature|Slide"
## How long the action cycles on a shot.
@export var fire_cycle_time := 0.15
## The empty reload ends with the rack; this much of it is the rack.
@export var rack_time := 0.3
