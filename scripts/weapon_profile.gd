class_name WeaponProfile
extends Resource
## Every number that makes a weapon what it is, so a second weapon is a data
## file and a weapon modifier is a field. The Pistol is
## `resources/weapons/pistol.tres`; the Pirate reads whichever Profile he
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
## Loads one round at a time in place of swapping a magazine: one tap of
## reload loads until full or broken off, a shot, a Melee or a swap breaks it
## keeping the rounds already in, and the two reload times above are unused.
@export var shell_reload := false
## Seconds for the first shell, and for each shell after it.
@export var first_shell_time := 0.55
@export var shell_time := 0.45
## Seconds to pump closed after loading from empty; a shot cannot break it.
@export var closing_pump_time := 0.45
## Seconds from a shot breaking the shell reload to the gun firing by itself.
@export var break_out_time := 0.25

@export_group("Projectile")
## Projectiles one shot launches, each thrown at random inside the cone and
## each doing `damage`: 1 for a gun with a single bolt, more for a Shotgun's
## pellets. However many land, a shot is one hit and at most one kill on
## each crew member it strikes.
@export var pellet_count := 1
## Damage per hit, per pellet, on the body.
@export var damage := 25
## A Headshot does `damage` times this, rounded: 1 for no bonus. Only a gun
## above 1 shows the Headshot hit marker, so a pellet on the head reads as a
## body hit.
@export var headshot_multiplier := 1.0
@export var projectile_speed := 80.0
## Seconds a shot flies before it gives up.
@export var projectile_lifetime := 0.5

@export_group("Spread")
## Half-angle of the cone shots scatter inside, evenly over its area,
## before bloom and state.
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
## Multiplier on the cone while aimed and still or crouched; a crouch
## multiplies it further, as at the hip.
@export var ads_spread := 0.5
## Multiplier on the cone while aimed and walking, in place of `ads_spread`
## times `spread_walking`: so an aimed long gun can be pinpoint held still
## and still loose on the move.
@export var ads_moving_spread := 0.6
## Degrees the aim drifts while aimed, in a slow figure of eight laid over
## wherever he looks: 0 holds dead still.
@export var ads_sway_degrees := 0.0
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

@export_group("Sound")
## The takes a shot plays, one at random. Shot sounds live here and nowhere
## else, so the Pirate and crew holding this weapon sound alike.
@export var shot_sounds: Array[AudioStream] = []
## The reload, in order: the first as the magazine comes out, the second as
## it goes in. A shell-by-shell reload plays the first as each shell seats.
@export var reload_sounds: Array[AudioStream] = []
## A sound after each shot, such as a pump, `action_sound_delay` seconds
## after it; none for a gun whose action is silent. A shell-by-shell reload
## plays it again on the closing pump.
@export var action_sound: AudioStream
@export var action_sound_delay := 0.0
## Metres at which crew hear the shot.
@export var loudness := 24.0

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
## The weapon mesh's own skeleton clips, by name on its AnimationPlayer. A
## shell-by-shell reload plays the reload clip once per shell, over that
## shell's time.
@export var model_fire_clip: StringName = &"fire"
@export var model_reload_clip: StringName = &"reload"
## Racks the slide to close an empty reload; blank for a weapon without one.
## A shell-by-shell reload plays it over the closing pump.
@export var model_rack_clip: StringName = &"rack"
## How long the action cycles on a shot.
@export var fire_cycle_time := 0.15
## The empty reload ends with the rack; this much of it is the rack.
@export var rack_time := 0.3


## What one bolt of [param damage] does on a head zone with
## [param multiplier]: the one rounding the Pirate's shots, crew shots and
## the Sandbox sheet share.
static func head_damage(damage: int, multiplier: float) -> int:
	return roundi(damage * multiplier)


## What one hit does on the head.
func headshot_damage() -> int:
	return head_damage(damage, headshot_multiplier)


## Seconds a reload takes from a dry gun to a full one.
func seconds_empty_to_full() -> float:
	if shell_reload:
		return first_shell_time + shell_time * maxi(magazine_size - 1, 0) + closing_pump_time
	return reload_empty


## Whether a reload from empty ends with the slide racked: the weapon has a
## rack clip and the reload is long enough to hold one.
func racks_after(from_empty: bool) -> bool:
	return from_empty and model_rack_clip != &"" and reload_empty > rack_time


## How long the magazine swap itself takes: the reload, less the rack when
## there is one.
func swap_time(from_empty: bool) -> float:
	var total := reload_empty if from_empty else reload_tactical
	return total - (rack_time if racks_after(from_empty) else 0.0)
