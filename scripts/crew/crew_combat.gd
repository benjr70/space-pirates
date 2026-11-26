class_name CrewCombat
extends RefCounted
## How Guards fight as a team: sharing where the Pirate is with Guards
## nearby, bursts that never start in step, and the way round for a Guard
## flanking through another Door while another pins him. The crew body asks;
## this works it out. Who flanks, and firing on his cover when he hides, is
## [CrewTeam]; how each Guard fights from cover (covering fire, one mover at
## a time, the last Guard) is [CrewCover]; where its shots are aimed, and who
## may aim true, is [CrewFire].
## See `CREW_AI.md`.

## No two crew start a burst within this many physics frames of each other.
const BURST_STAGGER_FRAMES := 18
## How often a Guard that can see him tells the others, in seconds.
const SHARE_EVERY := 1.0
## A flank is given up after this many seconds without arriving; the
## flanker then takes cover where it stands.
const FLANK_GIVE_UP := 20.0
## A flanker this close to the Door it goes in by has arrived: it takes a
## cover spot inside it. One that sees him this close to the Door does the
## same; further off it turns to fight him where it is.
const FLANK_ARRIVE := 1.5
const FLANK_SEE := 6.0
## Per-Guard jitter on its timings, as a range of multipliers.
const JITTER := Vector2(0.75, 1.35)


## Whether another crew member fighting the same Pirate started a burst
## too recently for [param crew] to start one now.
static func burst_blocked(crew: Crew3D) -> bool:
	var now := Engine.get_physics_frames()
	for node in crew.get_tree().get_nodes_in_group(&"crew"):
		var other := node as Crew3D
		if other == null or other == crew or not other.is_alive() or other.target != crew.target:
			continue
		if now - other.burst_frame < BURST_STAGGER_FRAMES:
			return true
	return false


## Tells every living Guard in [param crew]'s Room and the Rooms next to it
## (by any Door, open or shut: they have radios) where the Pirate is. A
## Guard not already fighting starts hunting there. [param from_trace]:
## only where a trace says he was. Returns how many heard.
static func share(crew: Crew3D, at: Vector3, from_trace := false) -> int:
	if crew.layout == null:
		return 0
	var near := rooms_near(crew.layout, CrewNoise.rooms_at(crew.layout, crew.global_position))
	var told := 0
	for node in crew.get_tree().get_nodes_in_group(&"crew"):
		var other := node as Crew3D
		if other == null or other == crew or other.is_worker() or not other.is_alive():
			continue
		var theirs := CrewNoise.rooms_at(crew.layout, other.global_position)
		if not theirs.any(func(room: int) -> bool: return room in near):
			continue
		other.hear_position(at, from_trace)
		told += 1
	return told


## [param rooms] and every Room a Door joins to one of them.
static func rooms_near(layout: ShipLayout, rooms: Array[int]) -> Array[int]:
	var out: Array[int] = rooms.duplicate()
	for door in layout.doors:
		if door.room_a in rooms and not door.room_b in out:
			out.append(door.room_b)
		elif door.room_b in rooms and not door.room_a in out:
			out.append(door.room_a)
	return out


## The Door of his Room a flank goes in by, or an ambush waits at: of the
## unlocked Doors into [param room], the one furthest from the pinning Guard
## at [param pinner]. Null with none.
static func far_door(layout: ShipLayout, room: int, pinner: Vector3) -> DoorData:
	var best: DoorData = null
	var best_distance := -INF
	for door in layout.doors:
		if door.locked or not (door.room_a == room or door.room_b == room):
			continue
		var distance := ShipBuilder3D.door_center_world(door).distance_to(pinner)
		if distance > best_distance:
			best_distance = distance
			best = door
	return best


## A route for [param crew] into the Pirate's Room through a Door other than
## the one a pinning Guard at [param pinner] covers ([method far_door]),
## going round rather than through his Room. Empty when his Room has no
## second way in, or the crew member's own way in would be that Door
## anyway. [param door_out] gets the Door's centre.
static func flank_route(crew: Crew3D, pirate_at: Vector3, pinner: Vector3, door_out: Array = []) -> Array[Vector3]:
	var layout := crew.layout
	if layout == null:
		return []
	var target_room := layout.room_at(ShipBuilder3D.world_to_tile(pirate_at))
	if target_room < 0:
		return []
	var best := far_door(layout, target_room, pinner)
	if best == null:
		return []
	var centre := ShipBuilder3D.door_center_world(best)
	# The straight way in: a flank through the same Door is no flank.
	var direct := ShipNavigator.waypoints_3d(layout, crew.global_position, pirate_at)
	for point in direct:
		if point.distance_to(centre) < 0.6:
			return []
	var across := Vector3(0, 0, 1) if best.horizontal else Vector3(1, 0, 0)
	var inside := centre + across
	if layout.room_at(ShipBuilder3D.world_to_tile(inside)) != target_room:
		inside = centre - across
	var outside := centre - (inside - centre)
	var route := ShipNavigator.waypoints_3d(layout, crew.global_position, outside, target_room)
	if route.is_empty():
		return []
	route.append(centre)
	route.append(inside)
	door_out.assign([centre])
	return route


## A per-Guard multiplier from [param rng] within [constant JITTER].
static func jitter(rng: RandomNumberGenerator) -> float:
	return rng.randf_range(JITTER.x, JITTER.y)
