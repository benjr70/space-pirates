class_name Gunnery
extends Resource
## How a crew type handles the weapon it fires, apart from what the weapon
## is: the aim error it adds to the weapon's own cone, how long a burst it
## fires, how long it pauses between bursts and how far off it opens fire.
## One file per crew type under `resources/gunnery/`, edited in the Sandbox
## sheet. The weapon's damage, bolt and time between shots come from its
## [WeaponProfile]; spawn jitter on top of these base values is the crew's
## own ([Crew3D]).

const GUARD_PATH := "res://resources/gunnery/guard.tres"
const WORKER_PATH := "res://resources/gunnery/worker.tres"
## Every crew type's Gunnery, in Sandbox sheet column order.
const PATHS: PackedStringArray = [GUARD_PATH, WORKER_PATH]
const NAMES: PackedStringArray = ["Guard", "Worker"]

@export_group("Aim")
## Degrees added on top of the weapon's base cone.
@export var aim_error_degrees := 6.0

@export_group("Bursts")
## Shots in a burst.
@export var burst_length := 3
## Seconds behind cover between one burst and the next.
@export var pause_between_bursts := 1.1

@export_group("Range")
## Metres off the Pirate it opens fire from.
@export var engage_range := 10.6


## The Gunnery a crew member of [param type] handles its weapon with.
static func for_type(type: CrewTypes.Type) -> Gunnery:
	return load(WORKER_PATH if type == CrewTypes.Type.WORKER else GUARD_PATH)


## Every crew type's Gunnery, the live (cached) ones the crew hold.
static func all() -> Array:
	var out := []
	for path in PATHS:
		out.append(load(path))
	return out
