class_name Gunnery
extends Resource
## How well a Guard handles one kind of weapon, apart from what the weapon
## is: the aim error it adds to the weapon's own cone, how wide its aim
## opens on first sight and how fast it closes, how long its bursts are and
## how long it stays down between them, how far it leads a moving Pirate,
## how far off it likes to fight and how slowly it reloads. One file per
## weapon under `resources/gunnery/`, named as the weapon's own file, edited
## in the Sandbox sheet. The weapon's damage, projectile, pellets, time
## between shots and sounds come from its [WeaponProfile].
##
## Numbers are the starting numbers of `.scratch/crew-combat/spec.md`. Not
## every field is read yet: the cover, fair fire and habit tickets of that
## spec use the rest (see `scripts/crew/CREW_AI.md`).

const DIR := "res://resources/gunnery/"
## Every weapon's Gunnery, in Sandbox sheet column order: the wheel's
## ([constant Loadout.WEAPONS]).
const PATHS: PackedStringArray = [
	DIR + "pistol.tres",
	DIR + "assault_rifle.tres",
	DIR + "shotgun.tres",
	DIR + "marksman_rifle.tres",
]
const NAMES: PackedStringArray = ["Pistol", "Assault Rifle", "Shotgun", "Marksman Rifle"]

@export_group("Aim")
## Degrees added on top of the weapon's base cone.
@export var aim_error_degrees := 6.0
## The cone on first sight, as a multiple of the closed cone (the weapon's
## base cone plus the aim error), and the seconds of unbroken sight it
## takes to close to 1x.
@export var opening_spread := 3.0
@export var closing_time := 2.0
## Fraction of the true intercept it leads a moving Pirate by.
@export var lead := 0.5

@export_group("Bursts")
## Shots in one burst, drawn between these for each burst.
@export var shots_per_burst_low := 3
@export var shots_per_burst_high := 3
## Bursts it fires in one peek from cover, and the seconds between two of
## them, drawn between these.
@export var bursts_per_peek := 1
@export var gap_between_bursts_low := 0.0
@export var gap_between_bursts_high := 0.0
## Seconds down between one peek and the next, drawn between these.
@export var time_down_low := 1.0
@export var time_down_high := 2.0
## Seconds up before its first shot of a peek.
@export var settle := 0.35

@export_group("Range")
## Metres off the Pirate it likes to fight from: a preference, never a
## filter.
@export var range_near := 4.0
@export var range_far := 8.0
## Seconds it holds a spot out of its band before shifting one nearer or
## further; negative never moves up.
@export var hold_before_shifting := 4.0

@export_group("Reload")
## The weapon's reload times are multiplied by this in a Guard's hands.
@export var reload_factor := 1.5


## The Gunnery a Guard handles [param weapon] with: the file named as the
## weapon's own, the live (cached) one; the Pistol's for a weapon with no
## file of its own (a test's copy). Null for no weapon.
static func for_weapon(weapon: WeaponProfile) -> Gunnery:
	if weapon == null:
		return null
	var path := DIR + weapon.resource_path.get_file()
	if weapon.resource_path.is_empty() or not ResourceLoader.exists(path):
		path = PATHS[0]
	return load(path)


## Shots in one burst, drawn from [param rng] between the low and high.
func draw_shots(rng: RandomNumberGenerator) -> int:
	return maxi(rng.randi_range(shots_per_burst_low, maxi(shots_per_burst_high, shots_per_burst_low)), 1)


## Seconds down after a peek, drawn from [param rng] between the low and high.
func draw_time_down(rng: RandomNumberGenerator) -> float:
	return rng.randf_range(time_down_low, maxf(time_down_high, time_down_low))


## Every weapon's Gunnery, the live (cached) ones the crew hold.
static func all() -> Array:
	var out := []
	for path in PATHS:
		out.append(load(path))
	return out
