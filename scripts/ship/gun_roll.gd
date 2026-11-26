class_name GunRoll
extends RefCounted
## Which of the four weapons each Guard carries, rolled when [ShipBuilder3D]
## builds a ship from its [ShipLayout] (`.scratch/crew-combat/spec.md`,
## "Which Guard carries which gun"). The gun is not stored in the layout.
##
## Each Guard rolls by weight: its Ship Class's base weights, slid from the
## poor row to the rich row by Richness, times its Post Room's multipliers,
## renormalised. Caps: no Marksman Rifle on a small ship, at most 1 on a
## medium and 2 on a large, never two posted in one Room; a Room of three or
## more Guards is never all Shotguns. A roll that breaks a cap is rolled
## again among the remaining weapons with the same weights.
##
## Rolls run in a fixed order, Rooms by index and Guards by spawn order, from
## a random stream of their own seeded off the layout's seed: the same
## layout always gives the same guns, whatever else in the build draws.
## Workers roll nothing.

## Weapon indices, in [constant Loadout.WEAPONS] (wheel) order.
const PISTOL := 0
const ASSAULT_RIFLE := 1
const SHOTGUN := 2
const MARKSMAN_RIFLE := 3
## A Worker's slot: no weapon.
const NONE := -1
## The four weapons' files, by index: [constant Loadout.WEAPONS], named
## here by path so rolling loads no weapon until one is asked for.
const WEAPON_PATHS: PackedStringArray = [
	"res://resources/weapons/pistol.tres",
	"res://resources/weapons/assault_rifle.tres",
	"res://resources/weapons/shotgun.tres",
	"res://resources/weapons/marksman_rifle.tres",
]

## Base weights per Ship Class: the poor row, then the rich row.
const BASE := {
	&"small": [[60.0, 25.0, 15.0, 0.0], [40.0, 35.0, 25.0, 0.0]],
	&"medium": [[35.0, 35.0, 25.0, 5.0], [20.0, 45.0, 25.0, 10.0]],
	&"large": [[20.0, 45.0, 25.0, 10.0], [10.0, 50.0, 25.0, 15.0]],
}
## The weights a ship of no known Ship Class (the hand-authored one) rolls
## with: the small ship's.
const DEFAULT_CLASS := &"small"
## The Post Room's multipliers on the weights; a Role not listed leaves them.
const ROOM := {
	&"corridor": [1.0, 1.5, 0.5, 2.0],
	&"armory": [0.5, 1.5, 2.0, 0.5],
	&"bridge": [1.5, 1.5, 1.0, 1.0],
	&"quarters": [2.0, 1.0, 1.0, 0.5],
}
## Most Marksman Rifles per ship, by Ship Class.
const MARKSMAN_CAP := {&"small": 0, &"medium": 1, &"large": 2}
## A Room of this many Guards or more is never all Shotguns.
const ALL_SHOTGUN_ROOM := 3
## Mixed into the layout's seed so the gun stream is its own.
const STREAM := "gun roll"


## The gun of every crew member of [param layout]: one Array per Room, by
## index, of one weapon index per crew member in spawn order ([constant
## NONE] for a Worker).
static func roll(layout: ShipLayout) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([layout.gen_seed, STREAM])
	var ship_class := _class_of(layout)
	var marksman_cap: int = MARKSMAN_CAP.get(ship_class, 0)
	var marksmen := 0
	var out := []
	for room: RoomData in layout.rooms:
		var guns := []
		var guards := guards_in(room)
		var weights := weights_for(layout, room.role)
		var shotguns := 0
		var rolled := 0
		for n in room.crew_count:
			if CrewTypes.for_role(room.role, n) != CrewTypes.Type.GUARD:
				guns.append(NONE)
				continue
			rolled += 1
			var left := weights.duplicate()
			var gun := _pick(rng, left)
			while _breaks_cap(gun, marksmen, marksman_cap, guns, guards, rolled, shotguns):
				left[gun] = 0.0
				gun = _pick(rng, left)
			if gun == MARKSMAN_RIFLE:
				marksmen += 1
			if gun == SHOTGUN:
				shotguns += 1
			guns.append(gun)
		out.append(guns)
	return out


## The live, bare Weapon Profile of weapon [param index] (the cached one
## the Pirate's Loadout holds too); null for [constant NONE].
static func weapon(index: int) -> WeaponProfile:
	return null if index < 0 else load(WEAPON_PATHS[index])


## How many Guards a Room of [param room] posts.
static func guards_in(room: RoomData) -> int:
	var count := 0
	for n in room.crew_count:
		if CrewTypes.for_role(room.role, n) == CrewTypes.Type.GUARD:
			count += 1
	return count


## The four weights a Guard posted in a Room of [param role] on
## [param layout] rolls with, before any cap: its Class's slid by Richness,
## times the Room's multipliers, renormalised to sum to 1.
static func weights_for(layout: ShipLayout, role: StringName) -> Array:
	var rows: Array = BASE[_class_of(layout)]
	var t := clampf(layout.richness, 0.0, 1.0)
	var times: Array = ROOM.get(role, [1.0, 1.0, 1.0, 1.0])
	var weights := []
	var total := 0.0
	for i in 4:
		var w: float = lerpf(rows[0][i], rows[1][i], t) * times[i]
		weights.append(w)
		total += w
	for i in 4:
		weights[i] /= total
	return weights


static func _class_of(layout: ShipLayout) -> StringName:
	return layout.ship_class if BASE.has(layout.ship_class) else DEFAULT_CLASS


static func _pick(rng: RandomNumberGenerator, weights: Array) -> int:
	var total := 0.0
	for w: float in weights:
		total += w
	var at := rng.randf() * total
	for i in weights.size():
		at -= weights[i]
		if at < 0.0 and weights[i] > 0.0:
			return i
	# Rounding at the very top: the last weapon with any weight.
	for i in range(weights.size() - 1, -1, -1):
		if weights[i] > 0.0:
			return i
	return PISTOL


## Whether [param gun] for the [param rolled]th Guard of a Room of
## [param guards] breaks a cap, given the guns already rolled there and the
## ship's Marksman Rifles so far.
static func _breaks_cap(gun: int, marksmen: int, marksman_cap: int, room_guns: Array,
		guards: int, rolled: int, shotguns: int) -> bool:
	if gun == MARKSMAN_RIFLE and (marksmen >= marksman_cap or MARKSMAN_RIFLE in room_guns):
		return true
	# The last Guard of a big Room may not make it all Shotguns.
	return gun == SHOTGUN and guards >= ALL_SHOTGUN_ROOM and rolled == guards and shotguns == guards - 1
