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

@export_group("Recoil")
## A shot shoves the weapon this far back toward him and tips its muzzle up
## by this much, and it settles on its own.
@export var recoil_push := 0.05
@export var recoil_kick_degrees := 7.0
## The same in Aim Down Sights. A long gun is braced in the shoulder there,
## so it comes straight back along the sight line with no kick at all; a
## handgun snaps up in the wrist either way.
@export var ads_recoil_push := 0.05
@export var ads_recoil_kick_degrees := 7.0
## Degrees the view itself jumps on a shot.
@export var camera_kick_degrees := 1.2
## The Viewmodel clip a shot plays on the weapon on top of all that; blank
## for a weapon whose recoil is only the numbers above.
@export var fire_clip: StringName = &"fire"

@export_group("Viewmodel")
## The mesh he holds: a scene under `scenes/weapons` that mounts the model
## where the hand goes, with `Muzzle` and `SightTip` markers somewhere inside
## it. Blank keeps whatever is already mounted, poses and all.
@export var model: PackedScene
## Where the weapon rides at the hip, and lowered for a sprint or clamber,
## in camera space.
@export var pose_hip := Vector3(0.16, -0.18, -0.30)
@export var pose_low := Vector3(0.20, -0.26, -0.30)
## How far ahead of the eye the weapon is held in Aim Down Sights. The front
## sight centres itself; this only sets how big the weapon looks.
@export var ads_distance := 0.32
## The weapon mesh's own skeleton clips, by name on its AnimationPlayer.
@export var model_fire_clip: StringName = &"fire"
@export var model_reload_clip: StringName = &"reload"
## Racks the slide to close an empty reload; blank for a weapon without one.
@export var model_rack_clip: StringName = &"rack"
## How long the action cycles on a shot.
@export var fire_cycle_time := 0.15
## The empty reload ends with the rack; this much of it is the rack.
@export var rack_time := 0.3


## Whether a reload from empty ends with the slide racked: the weapon has a
## rack clip and the reload is long enough to hold one.
func racks_after(from_empty: bool) -> bool:
	return from_empty and model_rack_clip != &"" and reload_empty > rack_time


## How long the magazine swap itself takes: the reload, less the rack when
## there is one.
func swap_time(from_empty: bool) -> float:
	var total := reload_empty if from_empty else reload_tactical
	return total - (rack_time if racks_after(from_empty) else 0.0)
