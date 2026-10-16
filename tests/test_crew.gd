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
## Three Rooms: A (the Pirate's) with Doors to B west and C north, and B
## and C joined round A's corner, for flanking.
var tri_layout: ShipLayout
## The generated medium ship's crew, kept for the type checks.
var routine_crew: Array[Crew3D] = []
var routine_layout: ShipLayout


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
	_build_tri()
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
	await _check_worker()
	_check_on_edge()
	await _check_share()
	_check_aim()
	await _check_stagger()
	_check_flank()
	await _check_bodies()
	await _check_alarm()
	_check_reported_body()
	_check_panel_spots()
	await _check_routines()
	_check_types()
	_report()
	quit(1 if failures.size() > 0 else 0)


func _crew(type := CrewTypes.Type.GUARD) -> Crew3D:
	var crew: Crew3D = load("res://scenes/crew_3d.tscn").instantiate()
	crew.crew_type = type
	crew.target = player
	crew.layout = layout
	crew.position = CREW_AT
	world.add_child(crew)
	crew.face_direction(Vector3.FORWARD)
	crew.set_physics_process(false)
	# Stood still: no routine to walk off on, no glance to swing the cone
	# away, unless a check moves it on purpose.
	crew.routine = null
	crew._hold_timer = 10.0
	crew._glance_timer = 10.0
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


## A generated medium ship left alone for 60 simulated seconds, the Pirate
## parked far off the hull: crew roam beyond their Posts, stand at their
## props facing them, shut the Doors they open, and one made suspicious goes
## back to its routine once it calms down.
func _check_routines() -> void:
	world.free()
	world = Node3D.new()
	root.add_child(world)
	var ship_layout := ShipGenerator.generate(&"medium", 7)
	routine_layout = ship_layout
	var ship := Node3D.new()
	ship.name = "Ship"
	world.add_child(ship)
	ShipBuilder3D.build(ship_layout, ship)
	player = load("res://scenes/player_3d.tscn").instantiate()
	world.add_child(player)
	player.set_physics_process(false)
	player.global_position = Vector3(-500, 0, -500)
	routine_crew.clear()
	var crew := routine_crew
	for node: Crew3D in ship.get_node("Crew").get_children():
		node.target = player
		crew.append(node)
	var away := {}
	var bad_work := []
	var worked := 0
	var stray_doors := 0
	var probe := crew[0]
	var probe_resumed := false
	Engine.time_scale = 6.0
	Engine.max_physics_steps_per_frame = 16
	for frame in 3600:
		await physics_frame
		if frame == 600:
			probe.perception.awareness = 0.5
			probe._noticed_at = probe.global_position + probe.facing() * 2.0
		if frame > 600 and probe.state == Crew3D.State.PATROL and probe.job_phase in [Crew3D.JobPhase.WALKING, Crew3D.JobPhase.WORKING]:
			probe_resumed = probe_resumed or frame > 700
		if frame % 10 != 0:
			continue
		for member in crew:
			var room := ship_layout.room_at(ShipBuilder3D.world_to_tile(member.global_position))
			if room >= 0 and room != member.home_room:
				away[member] = true
			var job := member.routine.current()
			if member.job_phase == Crew3D.JobPhase.WORKING and not job.patrol and member._hold_timer < job.duration - 0.6:
				worked += 1
				var to_prop := job.prop_at - member.global_position
				to_prop.y = 0.0
				if to_prop.length() > 1.5 or member.facing().dot(to_prop.normalized()) < 0.8:
					bad_work.append("%.1f m, facing %.2f" % [to_prop.length(), member.facing().dot(to_prop.normalized())])
		if frame % 60 == 0:
			for node in get_nodes_in_group(&"doors"):
				var door: Door3D = node
				if not door.is_open:
					continue
				var near := crew.any(func(m: Crew3D) -> bool: return m.global_position.distance_to(door.global_position) < Crew3D.DOOR_FORGET + 1.0)
				if not near:
					stray_doors += 1
	# The Alarm going up stops every routine: Workers hide, Guards hunt.
	var alarm: ShipAlarm = ship.get_node("Alarm")
	alarm.raise(ShipBuilder3D.room_center_world(ship_layout.rooms[0]))
	for i in 30:
		await physics_frame
	var still_routine := []
	for member in crew:
		if member.is_worker() and member.state != Crew3D.State.COWER:
			still_routine.append("worker in state %d" % member.state)
		elif not member.is_worker() and member.state == Crew3D.State.PATROL:
			still_routine.append("guard on patrol")
	_expect(still_routine.is_empty(), "alarm: %d crew carried on their routine: %s" % [still_routine.size(), still_routine.slice(0, 3)])
	_expect(ship.get_node("AlarmPanels").get_child_count() == AlarmPanel.spots(ship_layout).size()
			and ship.get_node("AlarmPanels").get_child_count() > 0, "alarm: the built ship's panels do not match its spots")
	Engine.time_scale = 1.0
	Engine.max_physics_steps_per_frame = 8
	_expect(away.size() * 2 >= crew.size(), "routines: only %d of %d crew left their Post in 60 s" % [away.size(), crew.size()])
	_expect(worked > 0, "routines: no crew member was ever seen working at a prop")
	_expect(bad_work.is_empty(), "routines: %d working samples away from or facing off their prop, e.g. %s" % [bad_work.size(), bad_work.slice(0, 3)])
	_expect(stray_doors == 0, "routines: doors left standing open with no crew near, %d times" % stray_doors)
	_expect(probe_resumed, "routines: a crew member made suspicious never went back to its routine")


## A shot leaves the magazine: a bolt at 2.5 m lands and is gone before it
## could be counted.
func _has_fired(crew: Crew3D) -> bool:
	return crew._shots_left < crew.burst_size or crew._reload_timer > 0.0


## A Worker that spots the Pirate 8 m off runs for the Guard behind it and
## does not shoot; cornered at 2.5 m it fires its sidearm. Workers wear
## their tint, Guards do not.
func _check_worker() -> void:
	var guard := _crew(CrewTypes.Type.GUARD)
	guard.global_position = Vector3(1.5, 0.0, 23.0)
	guard.face_direction(Vector3.LEFT)
	var worker := _crew(CrewTypes.Type.WORKER)
	worker.hide_chance = 0.0
	_place(8.0)
	var to_guard := worker.global_position.distance_to(guard.global_position)
	var to_pirate := worker.global_position.distance_to(player.global_position)
	var fired := false
	worker.set_physics_process(true)
	for i in 120:
		await physics_frame
		fired = fired or _has_fired(worker)
	worker.set_physics_process(false)
	_expect(worker.state in [Crew3D.State.FLEE, Crew3D.State.COWER], "a spotted Worker is in state %d, not fleeing" % worker.state)
	_expect(worker.global_position.distance_to(guard.global_position) < to_guard - 0.5
			and worker.global_position.distance_to(player.global_position) > to_pirate,
			"a fleeing Worker did not head for the Guard and away from the pirate")
	_expect(not fired, "a Worker fired at a pirate 8 m away")
	_expect(worker.body_tint == CrewTypes.WORKER_TINT and guard.body_tint == Color.WHITE, "Workers and Guards are not told apart by tint")
	var tinted := false
	for node in worker.model.find_children("*", "MeshInstance3D", true, false):
		var material := (node as MeshInstance3D).get_surface_override_material(0) as BaseMaterial3D
		if material != null and not material.albedo_color.is_equal_approx(Color.WHITE):
			tinted = true
	_expect(tinted, "the Worker's rig carries no tinted material")
	worker.free()
	guard.free()

	var cornered := _crew(CrewTypes.Type.WORKER)
	_place(2.5)
	fired = false
	cornered.set_physics_process(true)
	for i in 90:
		await physics_frame
		fired = fired or _has_fired(cornered)
	cornered.set_physics_process(false)
	_expect(fired, "a Worker cornered at 2.5 m never fired")
	cornered.free()
	for shot in get_first_node_in_group(&"projectiles").get_children():
		shot.free()


## On the generated ship: Armory and Bridge crew are Guards walking patrol
## loops, Engine and Cargo crew Workers walking work loops.
func _check_types() -> void:
	var seen := {}
	for member in routine_crew:
		var role: StringName = routine_layout.rooms[member.home_room].role
		if role in [&"armory", &"bridge"]:
			_expect(not member.is_worker() and member.routine.patroller, "a crew member posted in the %s is not a patrolling Guard" % role)
			seen[role] = true
		elif role in [&"engine", &"cargo"]:
			_expect(member.is_worker() and not member.routine.patroller, "a crew member posted in the %s is not a working Worker" % role)
			seen[role] = true
	_expect(seen.size() == 4, "the medium ship had crew in only %s of armory, bridge, engine, cargo" % [seen.keys()])


## Losing the Pirate leaves a crew member On Edge: it spots him faster.
func _check_on_edge() -> void:
	var crew := _crew()
	_place(10.0)
	var calm := _time_to_spot(crew)
	crew._last_seen = player.global_position
	crew._enter(Crew3D.State.SEARCH)
	crew.state = Crew3D.State.PATROL
	var edgy := _time_to_spot(crew)
	_expect(crew.perception.on_edge and edgy < calm * 0.8, "On Edge: spotted at 10 m in %.2f s, calm %.2f s" % [edgy, calm])
	crew.free()


## In the open test Room: a spotted Worker runs for the nearest working
## panel. Shot out on the way, that panel raises nothing and the Worker
## runs on to the other, which raises the Alarm: red lights, the Worker
## hides, the panels show it.
func _check_alarm() -> void:
	var ship := world.get_node("Ship")
	var alarm: ShipAlarm = ship.get_node("Alarm")
	var near := AlarmPanel.new()
	near.setup(0, Vector2i(1, 21), Vector2i.LEFT)
	ship.add_child(near)
	var far := AlarmPanel.new()
	far.setup(0, Vector2i(6, 13), Vector2i.RIGHT)
	ship.add_child(far)
	await physics_frame
	var worker := _crew(CrewTypes.Type.WORKER)
	worker.hide_chance = 0.0
	_place(8.0)
	worker.set_physics_process(true)
	var broke_near := false
	var ran_to_near := false
	for i in 600:
		await physics_frame
		if not broke_near and worker._flee_panel == near:
			ran_to_near = true
			near.take_damage(1, player)
			broke_near = true
		if alarm.is_raised:
			break
	worker.set_physics_process(false)
	_expect(ran_to_near, "alarm: the spotted Worker never ran for the nearest panel")
	_expect(near.broken, "alarm: a panel shot by the pirate is not broken")
	_expect(alarm.is_raised, "alarm: the Worker never raised the Alarm at the other panel")
	_expect(worker.global_position.distance_to(far.use_at) < 1.5, "alarm: the Alarm went up with the Worker away from the working panel")
	near.take_damage(1, worker)
	var crew_shot := AlarmPanel.new()
	crew_shot.setup(0, Vector2i(6, 5), Vector2i.RIGHT)
	ship.add_child(crew_shot)
	crew_shot.take_damage(1, worker)
	_expect(not crew_shot.broken, "alarm: a crew member's shot broke a panel")
	var red := true
	for light: OmniLight3D in ship.get_node("Lights").get_children():
		red = red and light.light_color.r > light.light_color.g * 3.0
	_expect(red, "alarm: the room lights did not turn red")
	for i in 5:
		await physics_frame
	worker._tick_cower()
	_expect(worker.state == Crew3D.State.COWER, "alarm: the Worker that raised it is in state %d, not hiding" % worker.state)
	worker.free()
	near.free()
	far.free()
	crew_shot.free()


## Every generated ship has an Alarm Panel in its Bridge.
func _check_panel_spots() -> void:
	var missing := []
	for ship_class in ShipGenerator.CLASSES:
		for seed in range(1, 16):
			var ship := ShipGenerator.generate(ship_class, seed)
			var in_bridge := AlarmPanel.spots(ship).any(func(spot: Dictionary) -> bool:
					return ship.rooms[spot.room].role == &"bridge")
			if not in_bridge:
				missing.append("%s %d" % [ship_class, seed])
	_expect(missing.is_empty(), "alarm: no Bridge panel on %s" % [missing])


## A at x 200-207, B west of it at 191-198, C a long Room north of both at
## y -9 to -2; Doors A-B (x 199), A-C (y -1) and B-C (y -1).
func _build_tri() -> void:
	tri_layout = ShipLayout.new()
	var a := RoomData.new()
	a.rects = [Rect2i(200, 0, 8, 8)]
	var b := RoomData.new()
	b.rects = [Rect2i(191, 0, 8, 8)]
	var c := RoomData.new()
	c.rects = [Rect2i(191, -9, 17, 8)]
	tri_layout.rooms = [a, b, c]
	tri_layout.doors = [_door(0, 1, Vector2i(199, 3), false), _door(0, 2, Vector2i(204, -1), true),
			_door(1, 2, Vector2i(194, -1), true)]
	var ship := Node3D.new()
	ship.name = "TriShip"
	world.add_child(ship)
	ShipBuilder3D.build(tri_layout, ship)


func _door(a: int, b: int, tile: Vector2i, horizontal: bool) -> DoorData:
	var door := DoorData.new()
	door.room_a = a
	door.room_b = b
	door.tile = tile
	door.horizontal = horizontal
	return door


func _guard_at(at: Vector3, ship_layout: ShipLayout, facing: Vector3) -> Crew3D:
	var guard := _crew(CrewTypes.Type.GUARD)
	guard.layout = ship_layout
	guard.global_position = at
	guard.face_direction(facing)
	return guard


## A Guard that spots the Pirate tells a Guard in the next Room, which
## hunts him without seeing him: the Door between them is shut.
func _check_share() -> void:
	pair_door.close()
	# A door's blocker comes back on the next physics frame.
	for i in 2:
		await physics_frame
	var spotter := _guard_at(ShipBuilder3D.tile_to_world(Vector2i(102, 4)), pair_layout, Vector3.RIGHT)
	var told := _guard_at(ShipBuilder3D.tile_to_world(Vector2i(113, 4)), pair_layout, Vector3.RIGHT)
	player.global_position = ShipBuilder3D.tile_to_world(Vector2i(106, 4))
	player.state = player.State.WALK
	for i in 120:
		spotter._update_perception(STEP)
		if spotter.perception.band() == CrewPerception.Band.SPOTTED:
			spotter._react_spotted()
			break
	told._update_perception(STEP)
	_expect(not told._can_see, "share: the told Guard could see the pirate through the shut door")
	_expect(told.state == Crew3D.State.HUNT and told._last_seen.distance_to(player.global_position) < 0.5,
			"share: the Guard next door is in state %d, not hunting the pirate's position" % told.state)
	spotter.free()
	told.free()


## Spread opens at 1.5x base and closes to half that or less after 3 s of
## exposure; breaking line of sight resets it.
func _check_aim() -> void:
	_expect(is_equal_approx(CrewCombat.spread(7.0, 0.0), 10.5) and CrewCombat.spread(7.0, 3.0) <= 10.5 / 2.0,
			"aim: spread does not tighten from 10.5 to half over 3 s")
	var guard := _crew()
	guard.state = Crew3D.State.FIGHT
	_place(5.0)
	var opening := CrewCombat.spread(guard.spread_degrees, guard._exposed_for)
	for i in 185:
		guard._update_perception(STEP)
	var tight := CrewCombat.spread(guard.spread_degrees, guard._exposed_for)
	_expect(tight <= opening / 2.0, "aim: after 3 s exposed the spread is %.1f°, opening %.1f°" % [tight, opening])
	player.global_position = CREW_AT + Vector3.FORWARD * 40.0
	guard._update_perception(STEP)
	_expect(guard._exposed_for == 0.0, "aim: losing sight did not reset the tightening")
	guard.free()


## Two Guards fighting the Pirate for 10 s never start a burst on the same
## frame, or within the stagger of each other.
func _check_stagger() -> void:
	player.health.max_health = 100000
	player.health.reset()
	var a := _crew()
	var b := _crew()
	b.global_position = CREW_AT + Vector3(-2.0, 0.0, 0.0)
	_place(6.0)
	for guard in [a, b]:
		guard.perception.awareness = 1.0
		guard._last_seen = player.global_position
		guard._enter(Crew3D.State.FIGHT)
		guard.set_physics_process(true)
	var starts := {a: [], b: []}
	for i in 600:
		await physics_frame
		for guard in [a, b]:
			if starts[guard].is_empty() or starts[guard][-1] != guard.burst_frame:
				if guard.burst_frame > 0:
					starts[guard].append(guard.burst_frame)
	var closest := 1000
	for fa in starts[a]:
		for fb in starts[b]:
			closest = mini(closest, absi(fa - fb))
	_expect(starts[a].size() >= 2 and starts[b].size() >= 2, "stagger: the Guards fired %d and %d bursts in 10 s" % [starts[a].size(), starts[b].size()])
	_expect(closest >= CrewCombat.BURST_STAGGER_FRAMES, "stagger: two bursts started %d frames apart" % closest)
	a.free()
	b.free()
	player.health.max_health = 5
	player.health.reset()
	for shot in get_first_node_in_group(&"projectiles").get_children():
		shot.free()


## With one Guard pinning the Pirate through the A-B Door, a second Guard
## in B goes round through C and in by the A-C Door.
func _check_flank() -> void:
	var pirate := ShipBuilder3D.tile_to_world(Vector2i(204, 4))
	var pinner := _guard_at(ShipBuilder3D.tile_to_world(Vector2i(197, 4)), tri_layout, Vector3.RIGHT)
	var flanker := _guard_at(ShipBuilder3D.tile_to_world(Vector2i(193, 5)), tri_layout, Vector3.RIGHT)
	pinner._last_seen = pirate
	pinner._enter(Crew3D.State.FIGHT)
	flanker._last_seen = pirate
	flanker._enter(Crew3D.State.HUNT)
	var second := ShipBuilder3D.door_center_world(tri_layout.doors[1])
	var first := ShipBuilder3D.door_center_world(tri_layout.doors[0])
	var through_second := flanker._path.any(func(p: Vector3) -> bool: return p.distance_to(second) < 0.6)
	var through_first := flanker._path.any(func(p: Vector3) -> bool: return p.distance_to(first) < 0.6)
	_expect(flanker.flanking and through_second and not through_first,
			"flank: the second Guard's route %s does not go round through the other door" % [flanker._path])
	pinner.free()
	flanker.free()


## A dead crew member lying 6 m in front of [param observer], the Pirate
## parked far out of sight so only the body can draw it.
func _body_ahead(observer: Crew3D, distance := 6.0) -> Crew3D:
	var body := _crew()
	body.global_position = observer.global_position + observer.facing() * distance
	body.take_damage(1000)
	player.global_position = Vector3(60.0, 0.0, 60.0)
	return body


## A Guard that sees a body walks to it, reports it and hunts from there; a
## Worker that finds one runs for an Alarm Panel without stopping to hide.
func _check_bodies() -> void:
	var guard := _crew()
	var body := _body_ahead(guard)
	var start := guard.global_position.distance_to(body.global_position)
	guard.set_physics_process(true)
	var walked := false
	for i in 400:
		await physics_frame
		if guard.state == Crew3D.State.INVESTIGATE and guard.global_position.distance_to(body.global_position) < start - 1.0:
			walked = true
		if body.reported:
			break
	guard.set_physics_process(false)
	_expect(walked, "bodies: a Guard that saw a body did not walk to it suspicious")
	_expect(body.reported and guard.state == Crew3D.State.HUNT, "bodies: the Guard did not report the body and hunt (state %d)" % guard.state)
	guard.free()
	body.free()

	var ship := world.get_node("Ship")
	var panel := AlarmPanel.new()
	panel.setup(0, Vector2i(6, 23), Vector2i.RIGHT)
	ship.add_child(panel)
	var worker := _crew(CrewTypes.Type.WORKER)
	worker.hide_chance = 1.0
	body = _body_ahead(worker, 4.0)
	worker.set_physics_process(true)
	var to_panel := false
	for i in 400:
		await physics_frame
		if worker.state == Crew3D.State.FLEE and worker._flee_panel == panel:
			to_panel = true
			break
	worker.set_physics_process(false)
	_expect(body.reported and to_panel, "bodies: a Worker that found a body did not run for the Alarm Panel (state %d)" % worker.state)
	worker.free()
	body.free()
	panel.free()


## Once the Alarm is up, a body already reported draws nobody.
func _check_reported_body() -> void:
	var alarm: ShipAlarm = world.get_node("Ship/Alarm")
	_expect(alarm.is_raised, "bodies: the test room's Alarm is not up for the reported-body check")
	var worker := _crew(CrewTypes.Type.WORKER)
	var body := _body_ahead(worker)
	body.reported = true
	for i in 60:
		worker._update_perception(STEP)
	_expect(worker.perception.awareness == 0.0 and worker._trace == null, "bodies: a reported body drew a second crew member")
	worker.free()
	body.free()
	# Walking to a body someone else then reports: it stops caring.
	var late := _crew()
	body = _body_ahead(late, 8.0)
	late._update_perception(STEP)
	late._enter(Crew3D.State.INVESTIGATE)
	body.reported = true
	late._tick_investigate()
	_expect(late._trace == null, "bodies: a crew member kept walking to a body already reported")
	late.free()
	body.free()
