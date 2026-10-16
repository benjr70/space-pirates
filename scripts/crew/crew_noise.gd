class_name CrewNoise
extends RefCounted
## Sounds the crew can hear: the Pirate's footsteps, gunshots and doors. A
## noise has a kind, a position and a reach in metres. It reaches crew in
## its own Room within that reach, and crew in a neighbouring Room only
## through a Door standing open between them: Hull and shut Doors stop it.
## Hearing raises Awareness toward suspicious and gives a place to look; it
## never spots the Pirate on its own. See `CREW_AI.md`.

enum Kind { STEP, GUNSHOT, DOOR }

## Reach of one footstep by the Pirate's stance, in metres. Crouched or
## sliding feet make no noise at all.
const SPRINT_STEP := 9.0
const WALK_STEP := 3.0
const GUNSHOT := 24.0
const DOOR := 6.0


## Rings a noise at [param at] for every crew member that can hear it.
## [param source] is whoever made it, so nobody hears their own.
static func make(tree: SceneTree, at: Vector3, kind: Kind, reach: float, source: Node = null) -> int:
	var heard := 0
	for node in tree.get_nodes_in_group(&"crew"):
		var crew := node as Crew3D
		if crew == null or crew == source or not crew.is_alive():
			continue
		if Vector2(at.x, at.z).distance_to(Vector2(crew.global_position.x, crew.global_position.z)) > reach:
			continue
		if not carries(tree, crew.layout, at, crew.global_position):
			continue
		if crew.hear(at, kind, source):
			heard += 1
	return heard


## One footstep by [param pirate], as loud as his stance makes it.
static func footstep(pirate: Node3D) -> int:
	var reach := step_reach(pirate)
	if reach <= 0.0:
		return 0
	return make(pirate.get_tree(), pirate.global_position, Kind.STEP, reach, pirate)


static func step_reach(pirate: Node3D) -> float:
	if pirate.has_method("is_crouched") and pirate.is_crouched():
		return 0.0
	if pirate.get("state") == pirate.State.SPRINT:
		return SPRINT_STEP
	return WALK_STEP


## Whether a noise at [param from] reaches [param to]: the same Room, or
## Rooms joined by a Door that stands open. Without a layout, anything.
static func carries(tree: SceneTree, layout: ShipLayout, from: Vector3, to: Vector3) -> bool:
	if layout == null:
		return true
	var source := rooms_at(layout, from)
	var listener := rooms_at(layout, to)
	for room in source:
		if room in listener:
			return true
	for node in tree.get_nodes_in_group(&"doors"):
		var door := node as Door3D
		if door == null or door.data == null or not door.is_open:
			continue
		if (door.data.room_a in source and door.data.room_b in listener) \
				or (door.data.room_b in source and door.data.room_a in listener):
			return true
	return false


## The Rooms a point stands in: its own, or both sides of the doorway it is in.
static func rooms_at(layout: ShipLayout, point: Vector3) -> Array[int]:
	var tile := ShipBuilder3D.world_to_tile(point)
	var room := layout.room_at(tile)
	if room >= 0:
		return [room]
	for door in layout.doors:
		if tile in door.tiles():
			return [door.room_a, door.room_b]
	return []
