extends SceneTree
## Headless checks on the crew's brain: Awareness through the sight cone,
## its timing bands, decay, the walk to look, being shot, and the spotted
## sting and marker colours. A single long open Room, one crew member at its
## far end facing down it, and the Pirate placed by hand.
##
##   flatpak run org.godotengine.Godot --headless --path . --script res://tests/test_crew.gd

const STEP := 1.0 / 60.0
## The crew member stands here facing -Z, down the Room's length.
const CREW_AT := Vector3(4.0, 0.0, 19.5)

var failures: Array[String] = []
var checks := 0
var world: Node3D
var player: CharacterBody3D
var markers: AwarenessMarkers
var layout: ShipLayout
## Two Rooms side by side, joined by one Door, for noise through doorways.
var pair_layout: ShipLayout
var pair_door: Door3D


func _initialize() -> void:
	_check_pure()
	world = Node3D.new()
	root.add_child(world)
	layout = ShipLayout.new()
	var room := RoomData.new()
	room.rects = [Rect2i(0, 0, 8, 24)]
	room.role = &"cargo"
	layout.rooms = [room]
	var ship := Node3D.new()
	ship.name = "Ship"
	world.add_child(ship)
	ShipBuilder3D.build(layout, ship)
	_build_pair()
	var shots := Node3D.new()
	shots.add_to_group(&"projectiles")
	world.add_child(shots)
	player = load("res://scenes/player_3d.tscn").instantiate()
	world.add_child(player)
	player.set_physics_process(false)
	markers = AwarenessMarkers.new()
	world.add_child(markers)
	for i in 3:
		await physics_frame

	_check_behind()
	_check_timings()
	_check_decay()
	await _check_investigate()
	_check_shot()
	_check_sting()
	await _check_hearing()
	_check_doorway()
	_report()
	quit(1 if failures.size() > 0 else 0)


func _crew() -> Crew3D:
	var crew: Crew3D = load("res://scenes/crew_3d.tscn").instantiate()
	crew.target = player
	crew.layout = layout
	crew.position = CREW_AT
	world.add_child(crew)
	crew.face_direction(Vector3.FORWARD)
	crew.set_physics_process(false)
	return crew


func _place(distance: float, crouched := false) -> void:
	player.global_position = CREW_AT + Vector3.FORWARD * distance
	player.state = player.State.CROUCH if crouched else player.State.WALK


## Seconds of ticks until spotted, or INF after 10 s.
func _time_to_spot(crew: Crew3D) -> float:
	crew.perception.awareness = 0.0
	var t := 0.0
	while t < 10.0:
		crew._update_perception(STEP)
		t += STEP
		if crew.perception.band() == CrewPerception.Band.SPOTTED:
			return t
	return INF


func _check_pure() -> void:
	_expect(CrewPerception.in_cone(Vector3.FORWARD, Vector3(0, 0, -5)), "cone: straight ahead is not in the cone")
	_expect(CrewPerception.in_cone(Vector3.FORWARD, Vector3(3, 0, -5)), "cone: 31° off is not in the cone")
	_expect(not CrewPerception.in_cone(Vector3.FORWARD, Vector3(5, 0, -3)), "cone: 59° off is in the cone")
	_expect(not CrewPerception.in_cone(Vector3.FORWARD, Vector3(0, 0, 5)), "cone: behind is in the cone")
	_expect(is_equal_approx(CrewPerception.spot_time(6.5), 0.9), "spot time at 6.5 m is %.2f, want 0.9" % CrewPerception.spot_time(6.5))
	_expect(is_equal_approx(CrewPerception.spot_time(10.0, true), 3.0), "crouched spot time at 10 m is not doubled")
	_expect(AwarenessMarkers.color_for(0.1) == AwarenessMarkers.WHITE, "marker: unaware is not white")
	_expect(AwarenessMarkers.color_for(0.5) == AwarenessMarkers.YELLOW, "marker: suspicious is not yellow")
	_expect(AwarenessMarkers.color_for(1.0) == AwarenessMarkers.RED, "marker: spotted is not red")


func _check_behind() -> void:
	var crew := _crew()
	player.global_position = CREW_AT - Vector3.FORWARD * 3.0
	player.state = player.State.WALK
	for i in 120:
		crew._update_perception(STEP)
	_expect(crew.perception.awareness == 0.0, "behind at 3 m: Awareness rose to %.2f in 2 s" % crew.perception.awareness)
	crew.free()


func _check_timings() -> void:
	var crew := _crew()
	for pair in [[3.0, 0.3], [10.0, 1.5], [14.0, 3.0]]:
		_place(pair[0])
		var t := _time_to_spot(crew)
		_expect(absf(t - pair[1]) <= pair[1] * 0.25, "standing at %.0f m spotted in %.2f s, want %.1f s" % [pair[0], t, pair[1]])
		_place(pair[0], true)
		var crouched := _time_to_spot(crew)
		_expect(absf(crouched / t - 2.0) <= 0.25, "crouched at %.0f m took %.2f s, %.2f× standing" % [pair[0], crouched, crouched / t])
	crew.free()


func _check_decay() -> void:
	var crew := _crew()
	_place(10.0)
	for i in 45:
		crew._update_perception(STEP)
	var seen := crew.perception.awareness
	player.global_position = CREW_AT - Vector3.FORWARD * 3.0
	for i in 60:
		crew._update_perception(STEP)
	_expect(seen > 0.3 and crew.perception.awareness < seen, "Awareness did not fall out of view (%.2f to %.2f)" % [seen, crew.perception.awareness])
	crew.free()


## Noticed at 12 m but not spotted, then he steps behind: the crew member
## turns investigator and walks toward where it noticed him.
func _check_investigate() -> void:
	var crew := _crew()
	_place(12.0)
	while crew.perception.awareness < CrewPerception.SUSPICIOUS + 0.05:
		crew._update_perception(STEP)
	var noticed := player.global_position
	player.global_position = CREW_AT - Vector3.FORWARD * 3.5
	var start := crew.global_position.distance_to(noticed)
	crew.set_physics_process(true)
	for i in 90:
		await physics_frame
	_expect(crew.state == Crew3D.State.INVESTIGATE, "suspicious crew is in state %d, not investigating" % crew.state)
	var now := crew.global_position.distance_to(noticed)
	_expect(now < start - 1.0, "investigating crew did not walk toward the noticed spot (%.1f m to %.1f m)" % [start, now])
	crew.free()


func _check_shot() -> void:
	var crew := _crew()
	player.global_position = CREW_AT - Vector3.FORWARD * 4.0
	var before := markers.stings
	crew.take_damage(1, player)
	_expect(crew.state == Crew3D.State.HUNT and crew._last_seen.is_equal_approx(player.global_position),
			"shot from behind: crew did not hunt toward the shooter")
	_expect(crew.perception.awareness == 1.0 and markers.stings == before + 1, "shot from behind did not tip the crew into spotted")
	crew.free()


func _check_sting() -> void:
	var crew := _crew()
	_place(5.0)
	var before := markers.stings
	for i in 120:
		crew._update_perception(STEP)
	_expect(markers.stings == before + 1, "staying spotted rang the sting %d times, want once" % (markers.stings - before))
	crew.perception.awareness = 0.5
	for i in 60:
		crew._update_perception(STEP)
	_expect(markers.stings == before + 2, "a second tip into red did not ring the sting again")
	crew.free()


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _report() -> void:
	for f in failures:
		print("FAIL  ", f)
	if failures.is_empty():
		print("PASS  %d checks" % checks)
	else:
		print("FAILED  %d of %d checks" % [failures.size(), checks])


## Rooms 0 and 1, eight tiles square, side by side along X with one wall
## column between them and a two-wide Door through it, 100 m off the first.
func _build_pair() -> void:
	pair_layout = ShipLayout.new()
	var a := RoomData.new()
	a.rects = [Rect2i(100, 0, 8, 8)]
	var b := RoomData.new()
	b.rects = [Rect2i(109, 0, 8, 8)]
	pair_layout.rooms = [a, b]
	var door := DoorData.new()
	door.room_a = 0
	door.room_b = 1
	door.tile = Vector2i(108, 3)
	door.horizontal = false
	pair_layout.doors = [door]
	var ship := Node3D.new()
	ship.name = "PairShip"
	world.add_child(ship)
	ShipBuilder3D.build(pair_layout, ship)
	pair_door = ship.get_node("Doors").get_child(0)


## Footsteps by stance from behind, the walk to a noise, and noise alone
## never spotting him.
func _check_hearing() -> void:
	var crew := _crew()
	crew.face_direction(Vector3.BACK)
	for case in [[player.State.SPRINT, 6.0, true], [player.State.WALK, 6.0, false], [player.State.CROUCH, 2.0, false]]:
		crew.perception.awareness = 0.0
		player.global_position = CREW_AT + Vector3.FORWARD * case[1]
		player.state = case[0]
		CrewNoise.footstep(player)
		var heard := crew.perception.band() == CrewPerception.Band.SUSPICIOUS
		_expect(heard == case[2], "a step in state %d at %.0f m behind: suspicious %s, want %s" % [case[0], case[1], heard, case[2]])
	# A sprinting step 6 m behind: it turns investigator and walks to it.
	crew.perception.awareness = 0.0
	player.global_position = CREW_AT + Vector3.FORWARD * 6.0
	player.state = player.State.SPRINT
	var at := player.global_position
	CrewNoise.footstep(player)
	# Parked far out of sight range, so only the noise can draw it.
	player.global_position = Vector3(60.0, 0.0, 60.0)
	var start := crew.global_position.distance_to(at)
	crew.set_physics_process(true)
	for i in 60:
		await physics_frame
	crew.set_physics_process(false)
	_expect(crew.state == Crew3D.State.INVESTIGATE, "a crew member that heard a step is in state %d, not investigating" % crew.state)
	_expect(crew.global_position.distance_to(at) < start - 0.8, "a crew member that heard a step did not walk toward it")
	for i in 20:
		CrewNoise.make(self, player.global_position, CrewNoise.Kind.GUNSHOT, CrewNoise.GUNSHOT, player)
	_expect(crew.perception.awareness < 1.0 and crew.state != Crew3D.State.HUNT, "noise alone spotted the pirate")
	crew.perception.awareness = 0.98
	CrewNoise.make(self, player.global_position, CrewNoise.Kind.DOOR, CrewNoise.DOOR * 99.0, player)
	_expect(crew.perception.awareness == 0.98, "a noise lowered a crew member's Awareness")
	crew.free()


## A gunshot in one Room reaches crew in the next through an open Door,
## not through a shut one.
func _check_doorway() -> void:
	var crew: Crew3D = load("res://scenes/crew_3d.tscn").instantiate()
	crew.target = player
	crew.layout = pair_layout
	crew.position = ShipBuilder3D.tile_to_world(Vector2i(113, 4))
	world.add_child(crew)
	crew.set_physics_process(false)
	var shot := ShipBuilder3D.tile_to_world(Vector2i(103, 4))
	pair_door.close()
	CrewNoise.make(self, shot, CrewNoise.Kind.GUNSHOT, CrewNoise.GUNSHOT, player)
	_expect(crew.perception.awareness == 0.0, "a gunshot carried through a shut door")
	pair_door.open()
	crew.perception.awareness = 0.0
	CrewNoise.make(self, shot, CrewNoise.Kind.GUNSHOT, CrewNoise.GUNSHOT, player)
	_expect(crew.perception.band() == CrewPerception.Band.SUSPICIOUS, "a gunshot did not carry through an open door")
	crew.free()
