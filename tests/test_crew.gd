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
## Seconds a cornered Worker is watched for a shot.
const CORNERED_SECONDS := 30.0

var failures: Array[String] = []
var checks := 0
## The seed this run draws from (`-- seed=<n>` to replay one).
var run_seed := 0
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
## One Room with a Hatch in its north wall and the Pirate's pod docked on it.
var hatch_layout: ShipLayout
var hatch_ship: Node3D
## One Room ten tiles square with a bar of props across its middle (a
## crate, a console, a crate) and gaps at both ends.
var cluttered_layout: ShipLayout
## One Room ten tiles square with a row of crates across it, leaving a
## one-wide gap at the west wall and a three-wide one at the east.
var lane_layout: ShipLayout
## One Room ten tiles by six with crates along its south side from the west
## wall, leaving a one-wide lane under them that ends at the wall.
var pocket_layout: ShipLayout
## The generated medium ship's crew, kept for the type checks.
var routine_crew: Array[Crew3D] = []
var routine_layout: ShipLayout
## The cover rigs (_build_cover_rigs): the ring of four crates round the
## Pirate, the Room with one locker, and the Room with a grid of crates.
var ring_layout: ShipLayout
var full_layout: ShipLayout
var crates_layout: ShipLayout
## The habit rigs (_build_habit_rigs): four 14 x 10 Rooms with crates
## throughout, a 6 x 6 Room with one crate, the long Room a Marksman Rifle
## perches in, and two Rooms joined by a Door for the Shotgun's ambush.
var band_layouts: Array[ShipLayout] = []
var small_layout: ShipLayout
var perch_layout: ShipLayout
var fall_back_layout: ShipLayout
var ambush_layout: ShipLayout
## Its Door, opened only while the ambush check runs: noise carries
## through any open Door joining Rooms of those indices, whatever the rig.
var ambush_door: Door3D
## Bolts fired in the whole suite by Workers, and by Guards (which shows the
## count works), crew-combat ticket 23.
var worker_bolts := 0
var guard_bolts := 0
## Surrenders in the whole suite by Workers, and by Guards (never),
## crew-combat ticket 24.
var worker_surrenders := 0
var guard_surrenders := 0


func _initialize() -> void:
	run_seed = SuiteSeed.pick("crew")
	# Every bolt fired in the suite, by who fired it: no Worker ever fires.
	node_added.connect(_count_bolt)
	# Every surrender in the suite, by who gave up: never a Guard.
	node_added.connect(_count_surrenders)
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
	_build_hatched()
	_build_cluttered()
	_build_lane()
	_build_pocket()
	_build_cover_rigs()
	_build_habit_rigs()
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
	_check_conspicuous()
	_check_decay()
	await _check_investigate()
	_check_shot()
	_check_health_and_damage()
	_check_died_unaware()
	await _check_replays()
	_check_sting()
	await _check_bar_behind_walls()
	await _check_hearing()
	_check_doorway()
	_check_loudness()
	_check_suppressed()
	await _check_worker()
	_check_on_edge()
	await _check_share()
	_check_exposure_ramp()
	_check_gunnery()
	await _check_guns_in_hands()
	await _check_walk_in()
	await _check_true_aim()
	_check_miss_at_cover()
	await _check_lead()
	await _check_pellet_cap()
	await _check_time_to_die()
	await _check_stagger()
	_check_flank()
	await _check_cover_blocked()
	await _check_blocked_by_pirate()
	await _check_muzzle_blocked()
	await _check_cover_ring()
	await _check_down_poses()
	await _check_runs()
	await _check_reloads()
	await _check_top_up()
	await _check_shotgun_reload()
	await _check_full_cover()
	await _check_flanked_and_closed_on()
	await _check_open_fight()
	await _check_bands()
	await _check_shotgun_holds_fire()
	await _check_shotgun_ambush()
	await _check_shotgun_rack()
	await _check_sight_line()
	await _check_marksman_waits_for_place()
	await _check_marksman_small_room()
	await _check_marksman_falls_back()
	await _check_flank_by_gun()
	await _check_marksman_never_flanks()
	await _check_covering_fire()
	await _check_suppression()
	await _check_radioed_in()
	await _check_last_guard()
	await _check_round_props()
	await _check_unstick()
	await _check_head_on_doorway()
	await _check_standing_in_gap()
	await _check_working_in_lane()
	await _check_shared_work_spot()
	await _check_bodies()
	await _check_alarm()
	_check_reported_body()
	await _check_container_and_door()
	await _check_hatch()
	_check_panel_spots()
	await _check_shotgun_one_kill()
	await _check_shotgun_range()
	await _check_headshots()
	await _check_marksman_rifle_kills()
	await _check_head_follows_pose()
	await _check_pirate_has_no_head()
	await _check_routines()
	_check_types()
	_check_guns_carried()
	await _check_cover_fight_on_ship()
	await _check_hiding_sweep()
	await _check_workers_in_fight()
	await _check_hiding_rig()
	await _check_flee_aimed()
	await _check_surrender_rig()
	_check_pose_roll()
	await _check_worker_poses()
	_check_no_worker_shots()
	_check_no_guard_surrenders()
	await _silence()
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


## A Laser on the gun the Pirate holds makes him conspicuous x1.3: the time
## to spotted at 10 m is the bare time divided by 1.3, within 10%.
func _check_conspicuous() -> void:
	var bare: WeaponProfile = player.weapon
	var crew := _crew()
	_place(10.0)
	var bare_time := _time_to_spot(crew)
	player.weapon = bare.build({Attachment.Slot.UNDERBARREL: load("res://resources/attachments/laser.tres")})
	var laser_time := _time_to_spot(crew)
	player.weapon = bare
	var want := bare_time / 1.3
	_expect(absf(laser_time - want) <= want * 0.1, "with a Laser spotted at 10 m in %.3f s, want %.3f (bare %.3f / 1.3) within 10%%" % [laser_time, want, bare_time])
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


## Health and damage at the times-25 scale: a crew member takes four Pistol
## or Assault Rifle hits, the Pirate six crew shots, and three or five do not.
func _check_health_and_damage() -> void:
	for path in ["res://resources/weapons/pistol.tres", "res://resources/weapons/assault_rifle.tres"]:
		var profile: WeaponProfile = load(path)
		var crew := _crew()
		_expect(crew.health.max_health == 100, "crew Health is %d, not 100" % crew.health.max_health)
		_expect(profile.damage == 25, "%s does %d damage, not 25" % [path.get_file(), profile.damage])
		for i in 3:
			crew.take_damage(profile.damage, player)
		_expect(crew.is_alive(), "three %s hits killed a crew member" % path.get_file())
		crew.take_damage(profile.damage, player)
		_expect(not crew.is_alive(), "four %s hits left a crew member on %d" % [path.get_file(), crew.health.current])
		crew.free()
	# Crew fire the Pistol, so a crew shot does its damage.
	var crew_damage: int = (load("res://resources/weapons/pistol.tres") as WeaponProfile).damage
	_expect(crew_damage == 25, "a crew shot does %d damage, not 25" % crew_damage)
	# A second Pirate to kill, so the one the other checks use stays up.
	var pirate: CharacterBody3D = load("res://scenes/player_3d.tscn").instantiate()
	pirate.auto_respawn = false
	pirate.position = CREW_AT + Vector3(0.0, 0.0, 30.0)
	world.add_child(pirate)
	pirate.set_physics_process(false)
	_expect(pirate.health.max_health == 150, "Pirate Health is %d, not 150" % pirate.health.max_health)
	for i in 5:
		pirate.take_damage(crew_damage)
	_expect(pirate.is_alive(), "five crew shots killed the Pirate")
	pirate.take_damage(crew_damage)
	_expect(not pirate.is_alive(), "six crew shots left the Pirate on %d" % pirate.health.current)
	pirate.free()


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


## The Awareness bar is drawn only with a clear line from the camera to the
## crew member's eye height: none through a wall or a shut Door at 8 m on
## screen, one with the line clear (the open Room, the open Door); a crew
## member 4 m behind the camera is pinned to the bottom edge with the line
## clear and gets none through a wall; and one tipping into spotted behind a
## wall still rings the sting once.
func _check_bar_behind_walls() -> void:
	player.camera.make_current()
	player.head.rotation = Vector3.ZERO
	var crew := _crew()
	crew.perception.awareness = 0.5
	var screen := markers.get_viewport_rect().size
	# Pair ships: Room A (x 100-107) and Room B (x 109-116), the wall at
	# x 108, the Door through it on z 3-5.
	var a_wall := Vector3(104.0, 0.0, 6.5)
	var b_wall := Vector3(112.0, 0.0, 6.5)
	pair_door.close()
	for i in 3:
		await physics_frame
	_bar_case(crew, a_wall, b_wall, false, "on screen 8 m away through a wall")
	_bar_case(crew, Vector3(104.0, 0.0, 4.0), Vector3(112.0, 0.0, 4.0), false, "on screen 8 m away behind a shut Door")
	pair_door.open()
	for i in 3:
		await physics_frame
	var open_at := _bar_case(crew, Vector3(104.0, 0.0, 4.0), Vector3(112.0, 0.0, 4.0), true, "on screen 8 m away through an open Door")
	_expect(not player.camera.is_position_behind(crew.global_position) and open_at.y < screen.y - AwarenessMarkers.BAR.y,
			"the bar through the open Door is not on screen (%s)" % open_at)
	var clear_at := _bar_case(crew, CREW_AT + Vector3.FORWARD * 8.0, CREW_AT, true, "on screen 8 m away in the open")
	_expect(clear_at.y < screen.y - AwarenessMarkers.BAR.y, "the bar in the open is pinned, not over the head (%s)" % clear_at)
	# 4 m behind the camera, the Pirate facing away.
	var behind_at := _bar_case(crew, CREW_AT + Vector3.FORWARD * 4.0, CREW_AT, true, "4 m behind with a clear line",
			CREW_AT + Vector3.FORWARD * 8.0)
	_expect(is_equal_approx(behind_at.y, screen.y - AwarenessMarkers.BAR.y),
			"4 m behind: the bar is at y %.1f, not pinned to the bottom edge (%.1f)" % [behind_at.y, screen.y - AwarenessMarkers.BAR.y])
	_bar_case(crew, Vector3(106.0, 0.0, 6.5), Vector3(110.0, 0.0, 6.5), false, "4 m behind through a wall",
			Vector3(102.0, 0.0, 6.5))
	# Tipping into spotted behind the wall: no bar, one sting.
	_bar_case(crew, a_wall, b_wall, false, "spotted through a wall")
	crew.perception.awareness = 0.0
	var before := markers.stings
	crew.take_damage(1, player)
	_expect(crew.perception.awareness == 1.0 and markers.stings == before + 1,
			"tipping into spotted behind a wall rang the sting %d times, want once" % (markers.stings - before))
	_expect(markers.mark_at(crew, player.camera) == Vector2.INF, "a crew member spotted behind a wall has a bar drawn")
	crew.free()
	player.rotation.y = 0.0
	# Left shut, as _check_doorway expects to find it: shutting it there would
	# ring the Door's own noise into its listening crew member.
	pair_door.close()
	for i in 3:
		await physics_frame


## Puts the Pirate at [param pirate] looking at [param look] (the crew
## member when not given) and the crew member at [param at], checks whether
## it has a bar, and returns where.
func _bar_case(crew: Crew3D, pirate: Vector3, at: Vector3, want: bool, what: String, look := Vector3.INF) -> Vector2:
	player.global_position = pirate
	crew.global_position = at
	var to := (at if look == Vector3.INF else look) - pirate
	player.rotation.y = atan2(-to.x, -to.z)
	var mark := markers.mark_at(crew, player.camera)
	_expect((mark != Vector2.INF) == want, "%s: bar drawn %s, want %s" % [what, mark != Vector2.INF, want])
	return mark


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
		print(SuiteSeed.replay_line("crew", run_seed))


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
		CrewNoise.make(self, player.global_position, CrewNoise.Kind.GUNSHOT, player.weapon.loudness, player)
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
	CrewNoise.make(self, shot, CrewNoise.Kind.GUNSHOT, player.weapon.loudness, player)
	_expect(crew.perception.awareness == 0.0, "a gunshot carried through a shut door")
	pair_door.open()
	crew.perception.awareness = 0.0
	CrewNoise.make(self, shot, CrewNoise.Kind.GUNSHOT, player.weapon.loudness, player)
	_expect(crew.perception.band() == CrewPerception.Band.SUSPICIOUS, "a gunshot did not carry through an open door")
	crew.free()


## A suppressed Pistol shot (heard at 9.6 m) raises no suspicion in a crew
## member 12 m off; the bare shot (24 m) does.
func _check_suppressed() -> void:
	var bare: WeaponProfile = player.weapon
	var at := Vector3(200.0, 0.0, 200.0)
	player.global_position = at
	player.state = player.State.WALK
	var crew := _crew()
	crew.layout = null
	crew.target = null
	crew.global_position = at + Vector3.RIGHT * 12.0
	var shots: Array[Projectile3D] = []
	for suppressed in [true, false]:
		player.weapon = bare.build({Attachment.Slot.BARREL: load("res://resources/attachments/suppressor.tres")}) if suppressed else bare
		crew.perception.awareness = 0.0
		player._cooldown = 0.0
		player.ammo = player.weapon.magazine_size
		var shot: Projectile3D = player.fire()
		_expect(shot != null, "the Pirate did not fire (suppressed %s)" % suppressed)
		shots.append(shot)
		if suppressed:
			_expect(crew.perception.awareness == 0.0, "a suppressed Pistol shot 12 m off raised Awareness to %.2f" % crew.perception.awareness)
		else:
			_expect(crew.perception.band() == CrewPerception.Band.SUSPICIOUS, "a bare Pistol shot 12 m off raised no suspicion")
	player.weapon = bare
	for shot in shots:
		if shot != null:
			shot.free()
	crew.free()


## A shot reaches crew as far as the weapon's loudness: the Pistol's 24 m
## stirs a crew member 20 m off and not one 28 m off, and raising it in the
## Sandbox sheet stirs the further one too, for the Pirate's shots and the
## crew's own alike.
func _check_loudness() -> void:
	var pistol: WeaponProfile = player.weapon
	_expect(is_equal_approx(pistol.loudness, 24.0), "the Pistol is %.1f m loud, not 24" % pistol.loudness)
	var sheet := SandboxSheet.build([pistol], load(Sandbox.PATH))
	var weapons := sheet.table(SandboxSheet.WEAPONS)
	_expect(weapons.is_editable(&"loudness"), "loudness is not an editable sheet row")
	var at := Vector3(200.0, 0.0, 200.0)
	player.global_position = at
	player.state = player.State.WALK
	var near := _crew()
	var far := _crew()
	for crew in [near, far]:
		crew.layout = null
		crew.target = null
	near.global_position = at + Vector3.RIGHT * 20.0
	far.global_position = at + Vector3.RIGHT * 28.0
	var shots: Array[Projectile3D] = []
	for loudness in [24.0, 32.0]:
		weapons.set_value(&"loudness", 0, loudness)
		near.perception.awareness = 0.0
		far.perception.awareness = 0.0
		player._cooldown = 0.0
		player.ammo = pistol.magazine_size
		var shot: Projectile3D = player.fire()
		_expect(shot != null, "the Pirate did not fire at loudness %.0f" % loudness)
		shots.append(shot)
		_expect(near.perception.band() == CrewPerception.Band.SUSPICIOUS, "a shot at loudness %.0f missed the crew 20 m off" % loudness)
		var heard := far.perception.band() == CrewPerception.Band.SUSPICIOUS
		_expect(heard == (loudness > 28.0), "a shot at loudness %.0f: the crew 28 m off heard it %s" % [loudness, heard])
	# A crew member's own shot carries as far as the same Pistol's loudness.
	far.global_position = near.global_position + Vector3.RIGHT * 10.0
	for loudness in [8.0, 12.0]:
		weapons.set_value(&"loudness", 0, loudness)
		far.perception.awareness = 0.0
		near.target = player
		near._aim = Vector3.LEFT
		shots.append(near._fire())
		var heard := far.perception.band() == CrewPerception.Band.SUSPICIOUS
		_expect(heard == (loudness > 10.0), "a crew shot at loudness %.0f: the crew 10 m off heard it %s" % [loudness, heard])
	sheet.revert()
	_expect(is_equal_approx(pistol.loudness, 24.0), "Revert left the Pistol %.1f m loud" % pistol.loudness)
	for shot in shots:
		if shot != null:
			shot.free()
	near.free()
	far.free()


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
	return crew._shots_left < crew.burst_length or not crew.last_pellets.is_empty()


## A Worker that spots the Pirate 8 m off runs for the Guard behind it and
## does not shoot; cornered within 3 m, with no panel and no Guard to run
## to, it carries no weapon, never fires in 30 s and surrenders (SURRENDER,
## crew-combat ticket 24; it hid before, and hid where it stood before
## ticket 23). Workers wear the Engineer, Guards the Soldier.
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
	_expect(worker.get_node("Model/Rig").scene_file_path.ends_with("engineer.glb"), "a Worker does not wear the Engineer")
	_expect(guard.get_node("Model/Rig").scene_file_path.ends_with("soldier.glb"), "a Guard does not wear the Soldier")
	worker.free()
	guard.free()

	var cornered := _crew(CrewTypes.Type.WORKER)
	_expect(cornered.weapon == null and cornered.gunnery == null,
			"cornered: a Worker carries %s with Gunnery %s" % [cornered.weapon, cornered.gunnery])
	_place(2.5)
	var bolts := 0
	var counter := func(node: Node) -> void:
		if node is Projectile3D and (node as Projectile3D).shooter == cornered:
			bolts += 1
	var shots: Node = get_first_node_in_group(&"projectiles")
	shots.child_entered_tree.connect(counter)
	var cornered_frames := 0
	var away := Vector3.FORWARD * 2.5
	cornered.set_physics_process(true)
	for i in roundi(CORNERED_SECONDS / STEP):
		# He stays on top of it, 2.5 m off, wherever it hides.
		player.global_position = cornered.global_position + away
		await physics_frame
		if cornered._cornered():
			cornered_frames += 1
	cornered.set_physics_process(false)
	shots.child_entered_tree.disconnect(counter)
	var frames := roundi(CORNERED_SECONDS / STEP)
	_expect(cornered_frames * 10 >= frames * 9,
			"cornered: the Worker had him in sight within 3 m on only %d of %d frames" % [cornered_frames, frames])
	_expect(bolts == 0 and not _has_fired(cornered), "cornered: a Worker fired %d bolts in %.0f s within 3 m" % [bolts, CORNERED_SECONDS])
	_expect(cornered.state == Crew3D.State.SURRENDER, "cornered: a Worker is in state %d after %.0f s, not surrendered" % [cornered.state, CORNERED_SECONDS])
	_expect(cornered.weapon == null, "cornered: a Worker picked up %s" % cornered.weapon)
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


## Every living Guard on the generated medium ship shows a gun model, the
## scene its Weapon Profile names as its `model`, from the moment it spawns
## (crew-combat ticket 16): shown whenever the body is (the ship's reveal
## hides whole bodies out of the Pirate's sight); no Worker carries one.
func _check_guns_carried() -> void:
	var wrong: Array[String] = []
	var guards := 0
	for member in routine_crew:
		if not is_instance_valid(member) or not member.is_alive():
			continue
		var models := member.find_children("*", "", true, false).filter(func(n: Node) -> bool:
			return n.scene_file_path.begins_with("res://scenes/weapons/"))
		if member.is_worker():
			if member.gun != null or not models.is_empty():
				wrong.append("a Worker carries %s" % [models])
			continue
		guards += 1
		var shown: Node3D = member.gun.gun if member.gun != null else null
		if shown == null or member.weapon == null or shown.scene_file_path != member.weapon.model.resource_path \
				or not _shown_with(shown, member) or shown.find_children("*", "MeshInstance3D", true, false).is_empty() \
				or models.size() != 1:
			wrong.append("a %s Guard shows %s" % [member.weapon.resource_path.get_file() if member.weapon else "unarmed",
					shown.scene_file_path if shown != null else "no gun"])
	_expect(guards >= 2 and wrong.is_empty(), "guns carried: of %d living Guards and the Workers on the medium ship, %s"
			% [guards, wrong.slice(0, 4)])


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


## --- Fair fire ---

## Seconds a Guard is watched for true aim, with five in sight of him.
const TRUE_AIM_SECONDS := 20.0
## Runs per gun of standing exposed until dead, and how long each may take.
const DIE_RUNS := 20
const DIE_LIMIT := 60.0


## The exposure ramp: a Guard's spread is 3x its base (gun spread plus aim
## error) on first sight and 1x after 2 s of unbroken sight, each within 5%,
## never below 1x in 10 s; held while it is down behind its own cover; 3x
## again after he breaks sight and comes back, and after he hits it.
func _check_exposure_ramp() -> void:
	# Held where the check puts him, whatever an earlier check left running.
	var pirate_physics := player.is_physics_processing()
	player.set_physics_process(false)
	var guard := _crew()
	guard.state = Crew3D.State.FIGHT
	_place(5.0)
	var base := guard.base_cone_degrees()
	guard._update_perception(STEP)
	var first := guard.spread_degrees() / base
	_expect(absf(first - 3.0) <= 3.0 * 0.05, "ramp: on first sight the spread is %.3fx its base, want 3x within 5%%" % first)
	for i in 119:
		guard._update_perception(STEP)
	var closed := guard.spread_degrees() / base
	_expect(absf(closed - 1.0) <= 0.05, "ramp: after 2 s of sight the spread is %.3fx its base, want 1x within 5%%" % closed)
	var least := INF
	for i in 480:
		guard._update_perception(STEP)
		least = minf(least, guard.spread_degrees() / base)
	_expect(least >= 1.0 - 0.0001, "ramp: over 10 s of sight the spread fell to %.3fx its base, want never below 1x" % least)
	# Down behind its own cover, out of his sight because it ducked: held.
	var held := guard._exposed_for
	guard.cover.mode = CrewCover.Mode.DOWN
	player.global_position = CREW_AT + Vector3.FORWARD * 40.0
	for i in 30:
		guard._update_perception(STEP)
	_expect(is_equal_approx(guard._exposed_for, held), "ramp: ducking behind its own cover changed its exposure from %.2f to %.2f s" % [held, guard._exposed_for])
	guard.cover.mode = CrewCover.Mode.NONE
	guard._update_perception(STEP)
	_place(5.0)
	guard._update_perception(STEP)
	var again := guard.spread_degrees() / base
	_expect(absf(again - 3.0) <= 3.0 * 0.05, "ramp: after sight broke and came back the spread is %.3fx its base, want 3x within 5%%" % again)
	# Hit after 2 s of sight: thrown back open.
	for i in 120:
		guard._update_perception(STEP)
	guard.take_damage(1, player)
	var hit := guard.spread_degrees() / base
	_expect(absf(hit - 3.0) <= 3.0 * 0.05, "ramp: hit after 2 s of sight its spread is %.3fx its base, want 3x within 5%%" % hit)
	guard.free()
	player.set_physics_process(pirate_physics)


## Each shot [param guard] fires, as it leaves: where it was aimed (before
## spread), from where, whether true, whether a walk-in round, and where his
## body centre was. Returns the Callable connected to the projectiles node.
func _record_shots(guards: Array, into: Array) -> Callable:
	var current := {}
	var watch := func(node: Node) -> void:
		var bolt := node as Projectile3D
		if bolt == null or not bolt.shooter in guards:
			return
		var shooter: Crew3D = bolt.shooter
		var frame := Engine.get_physics_frames()
		if current.has(shooter) and current[shooter].frame == frame:
			current[shooter].pellets.append(bolt.direction)  # another pellet of the same shot
			return
		current[shooter] = {"guard": shooter, "frame": frame, "burst": shooter.burst_frame, "length": shooter.burst_length,
				"point": shooter.last_aim_point, "origin": shooter.last_aim_origin, "aimed": shooter.last_aimed_true,
				"walk": shooter.last_walk_in, "kind": shooter.last_miss_kind, "centre": CrewFire.body_centre(shooter.target),
				"velocity": CrewFire.velocity_of(shooter.target), "cone": shooter.spread_degrees(),
				"base": shooter.base_cone_degrees(), "line": shooter.cover != null and shooter.cover.line_shown(),
				"perched": shooter.cover != null and shooter.cover.perched(),
				"pellets": [bolt.direction]}
		into.append(current[shooter])
	get_first_node_in_group(&"projectiles").child_entered_tree.connect(watch)
	return watch


## The first burst of a sighting from an Assault Rifle Guard walks in: every
## round but the last aimed at least 0.3 m to one side of him, the last at
## him (before spread); its next burst all at him. Twice, his sight broken
## between.
func _check_walk_in() -> void:
	# Held where the check puts him, whatever an earlier check left running.
	var pirate_physics := player.is_physics_processing()
	player.set_physics_process(false)
	var pirate_health: int = player.health.max_health
	player.health.max_health = 100000
	player.health.reset()
	var guard := _armed(GunRoll.weapon(GunRoll.ASSAULT_RIFLE))
	guard.face_direction(Vector3.FORWARD)
	_place(7.0)
	var him := player.global_position
	for i in 2:
		await physics_frame
	var shots: Array = []
	var watch := _record_shots([guard], shots)
	guard.hear_position(him)
	guard.set_physics_process(true)
	var sightings: Array = []
	for sighting in 2:
		var from := shots.size()
		var t := 0.0
		while t < 12.0:
			await physics_frame
			t += STEP
			if _whole_bursts(shots.slice(from)).size() >= 2:
				break
		sightings.append(_whole_bursts(shots.slice(from)))
		# Out of its sight a moment, then back where he was.
		player.global_position = CREW_AT + Vector3.FORWARD * 40.0
		for i in 30:
			await physics_frame
		player.global_position = him
	guard.set_physics_process(false)
	get_first_node_in_group(&"projectiles").child_entered_tree.disconnect(watch)
	for n in sightings.size():
		var bursts: Array = sightings[n]
		_expect(bursts.size() >= 2, "walk-in: sighting %d saw %d whole bursts, want 2" % [n + 1, bursts.size()])
		if bursts.size() < 2:
			continue
		var offsets: Array = bursts[0].map(func(s: Dictionary) -> float: return s.point.distance_to(s.centre))
		var walked := true
		for i in offsets.size() - 1:
			walked = walked and offsets[i] >= 0.3
		_expect(offsets.size() >= 3 and walked and offsets[-1] <= 0.01 and bursts[0].all(func(s: Dictionary) -> bool: return s.aimed),
				"walk-in: sighting %d's first burst aimed %s m off him, want each round but the last 0.3 m or more to one side and the last on him"
				% [n + 1, offsets.map(func(d: float) -> String: return "%.2f" % d)])
		var next: Array = bursts[1].map(func(s: Dictionary) -> float: return s.point.distance_to(s.centre))
		_expect(next.all(func(d: float) -> bool: return d <= 0.01), "walk-in: sighting %d's second burst aimed %s m off him, want all on him"
				% [n + 1, next.map(func(d: float) -> String: return "%.2f" % d)])
	guard.free()
	_clear_shots()
	player.health.max_health = pirate_health
	player.health.reset()
	player.set_physics_process(pirate_physics)


## [param shots] (one Guard's, in order) split into its whole bursts: each
## run of one burst whose count reached its length.
func _whole_bursts(shots: Array) -> Array:
	var out: Array = []
	var run: Array = []
	for shot in shots:
		if not run.is_empty() and run[0].burst != shot.burst:
			run = []
		run.append(shot)
		if run.size() == shot.length:
			out.append(run)
			run = []
	return out


## Five Guards in sight of him in the open for 20 s: no physics frame has
## more than two aiming true, every frame in which any has a clear muzzle
## line has at least one, true aim passes round, and every shot from a
## Guard not aiming true is aimed 0.4 to 0.8 m from his body centre.
func _check_true_aim() -> void:
	# Held where the check puts him, whatever an earlier check left running.
	var pirate_physics := player.is_physics_processing()
	player.set_physics_process(false)
	var pirate_health: int = player.health.max_health
	player.health.max_health = 100000
	player.health.reset()
	var him := Vector3(4.0, 0.0, 10.0)
	player.global_position = him
	player.state = player.State.WALK
	var spots: Array[Vector3] = [Vector3(1.5, 0, 16.0), Vector3(4.0, 0, 17.0), Vector3(6.5, 0, 16.0), Vector3(2.0, 0, 3.5), Vector3(6.0, 0, 4.0)]
	var guns: Array[int] = [GunRoll.PISTOL, GunRoll.ASSAULT_RIFLE, GunRoll.PISTOL, GunRoll.ASSAULT_RIFLE, GunRoll.SHOTGUN]
	var guards: Array[Crew3D] = []
	for i in spots.size():
		var guard := _armed(GunRoll.weapon(guns[i]))
		guard.global_position = spots[i]
		guard.face_direction(him - spots[i])
		guards.append(guard)
	for i in 2:
		await physics_frame
	var shots: Array = []
	var watch := _record_shots(guards, shots)
	for guard in guards:
		guard.hear_position(him)
		guard.set_physics_process(true)
	var fire := CrewFire.of(player)
	var most := 0
	var bare := 0
	var with_line := 0
	var held_by := {}
	for frame in roundi(TRUE_AIM_SECONDS / STEP):
		await physics_frame
		# The frame's own decision, made before any Guard ticks in it.
		fire.update()
		var holding := fire.holders.filter(func(g: Crew3D) -> bool: return g in guards)
		most = maxi(most, holding.size())
		for g in holding:
			held_by[g] = true
		# (A Guard reloading, or dry on its way to reload, can fire nothing
		# and takes no true aim: crew-combat ticket 17.)
		var clear := guards.filter(func(g: Crew3D) -> bool:
			return g.state in [Crew3D.State.FIGHT, Crew3D.State.COVER] and g.magazine.can_fire() \
					and not g._blocked(g.global_position + Vector3.UP * Crew3D.EYE_HEIGHT, him + Vector3.UP * Crew3D.EYE_HEIGHT) \
					and not g._muzzle_blocked())
		if not clear.is_empty():
			with_line += 1
			if holding.is_empty():
				bare += 1
	get_first_node_in_group(&"projectiles").child_entered_tree.disconnect(watch)
	for guard in guards:
		guard.set_physics_process(false)
	_expect(most <= 2, "true aim: %d Guards aimed true in one frame, want at most 2" % most)
	_expect(with_line > 600 and bare == 0, "true aim: %d of %d frames with a clear muzzle line had no Guard aiming true, want none"
			% [bare, with_line])
	_expect(held_by.size() >= 3, "true aim: only %d of 5 Guards ever aimed true in %.0f s, want it passed round" % [held_by.size(), TRUE_AIM_SECONDS])
	var misses := shots.filter(func(s: Dictionary) -> bool: return not s.aimed)
	var off := misses.filter(func(s: Dictionary) -> bool:
		var d: float = s.point.distance_to(s.centre)
		return d < 0.4 or d > 0.8)
	_expect(misses.size() >= 20 and off.is_empty(), "true aim: %d of %d shots not aiming true were aimed outside 0.4 to 0.8 m of his body centre (e.g. %s)"
			% [off.size(), misses.size(), off.slice(0, 3).map(func(s: Dictionary) -> String: return "%.2f m" % s.point.distance_to(s.centre))])
	for guard in guards:
		guard.free()
	_clear_shots()
	player.health.max_health = pirate_health
	player.health.reset()
	player.set_physics_process(pirate_physics)


## Miss points against him behind cover: in the ring, a Guard 4 m north of
## him with a crate between aims at the crate's edge on the side he last
## peeked from (stood to one side, then the memory of it, then the other
## side), 0.4 to 0.8 m from his body centre; from the south, where nothing
## is between, beside his head away from his movement.
func _check_miss_at_cover() -> void:
	# Held where the check puts him, whatever an earlier check left running.
	var pirate_physics := player.is_physics_processing()
	player.set_physics_process(false)
	var crate := ShipBuilder3D.tile_to_world(RING_CRATES[0])
	var guard := _rig_guard(load("res://resources/weapons/pistol.tres"), ring_layout, RING_CRATES[0] + Vector2i(0, -3), crate)
	var fire := CrewFire.of(player)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var behind := crate + Vector3(0.0, 0.0, 1.0)
	var wrong: Array[String] = []
	# {where he stands: which side of the crate (+x or -x) the miss must take}
	for case in [[0.3, 1.0], [0.0, 1.0], [-0.3, -1.0]]:
		player.global_position = behind + Vector3(case[0], 0.0, 0.0)
		for n in 20:
			var kind := []
			var at := fire.miss_point(guard, rng, kind)
			var d := at.distance_to(CrewFire.body_centre(player))
			if kind != ["cover"] or d < 0.4 or d > 0.8 or signf(at.x - crate.x) != case[1]:
				wrong.append("him %+.1f m: %s %.2f m off, %+.2f m of the crate" % [case[0], kind, d, at.x - crate.x])
	_expect(wrong.is_empty(), "miss points at cover: %d wrong, e.g. %s" % [wrong.size(), wrong.slice(0, 3)])
	# The open side: moving +x at 4 m/s, the miss passes on his -x side.
	guard.global_position = behind + Vector3(0.0, 0.0, 4.0)
	player.global_position = behind
	player.velocity = Vector3(4.0, 0.0, 0.0)
	var open_wrong: Array[String] = []
	for n in 20:
		var kind := []
		var at := fire.miss_point(guard, rng, kind)
		var d := at.distance_to(CrewFire.body_centre(player))
		if kind != ["open"] or d < 0.4 or d > 0.8 or at.x >= player.global_position.x or at.y < CrewFire.body_centre(player).y + 0.4:
			open_wrong.append("%s %.2f m off at %s" % [kind, d, at - player.global_position])
	_expect(open_wrong.is_empty(), "miss points in the open: %d wrong, e.g. %s" % [open_wrong.size(), open_wrong.slice(0, 3)])
	player.velocity = Vector3.ZERO
	guard.free()
	player.set_physics_process(pirate_physics)


## Lead, against a Pirate walking across at 4 m/s 6 m off: a Marksman Rifle
## shot aimed at the full intercept, a Pistol shot at 0.3 of it, each within
## 10%, a Shotgun shot where he is, and a Pistol shot at him mid Slide at
## half its lead (0.15); every pellet inside the Guard's spread
## of its aim, and the spread a real cone (up and down as well as sideways).
func _check_lead() -> void:
	# Held where the check puts him, whatever an earlier check left running.
	var pirate_physics := player.is_physics_processing()
	player.set_physics_process(false)
	var pirate_health: int = player.health.max_health
	player.health.max_health = 100000
	player.health.reset()
	player.state = player.State.WALK
	var vertical := 0.0
	# [gun, fraction of the intercept, mid Slide]
	for case in [[GunRoll.MARKSMAN_RIFLE, 1.0, false], [GunRoll.PISTOL, 0.3, false], [GunRoll.SHOTGUN, 0.0, false],
			[GunRoll.PISTOL, 0.15, true]]:
		player.state = player.State.SLIDE if case[2] else player.State.WALK
		var gun := GunRoll.weapon(case[0])
		var guard := _armed(gun)
		guard.face_direction(Vector3.FORWARD)
		var lane_z := CREW_AT.z - 6.0
		player.global_position = Vector3(2.0, 0.0, lane_z)
		var speed := 4.0
		for i in 2:
			await physics_frame
		var shots: Array = []
		var watch := _record_shots([guard], shots)
		guard.hear_position(player.global_position)
		guard.set_physics_process(true)
		var t := 0.0
		# The Marksman Rifle's shot goes where its sight line pointed
		# SIGHT_LOCK before it: his body centre and velocity as the line last
		# followed him, per line in order.
		var locks: Array = []
		var was_locked := false
		var seen_by_tick: Array = [CrewFire.body_centre(player), CrewFire.velocity_of(player)]
		var seen_before: Array = seen_by_tick
		while t < 15.0 and shots.filter(func(s: Dictionary) -> bool: return not s.walk).size() < 3:
			await physics_frame
			t += STEP
			var locked: bool = guard.cover._locked != Vector3.INF
			if locked and not was_locked:
				locks.append(seen_before)
			was_locked = locked
			seen_before = seen_by_tick
			var at := player.global_position + Vector3(speed * STEP, 0.0, 0.0)
			if at.x > 6.5 or at.x < 1.5:
				speed = -speed
				at = player.global_position + Vector3(speed * STEP, 0.0, 0.0)
			player.global_position = at
			player.velocity = Vector3(speed, 0.0, 0.0)
			seen_by_tick = [CrewFire.body_centre(player), CrewFire.velocity_of(player)]
		guard.set_physics_process(false)
		get_first_node_in_group(&"projectiles").child_entered_tree.disconnect(watch)
		var wrong: Array[String] = []
		var outside := 0
		var counted := 0
		var line_shot := 0
		for s: Dictionary in shots:
			for direction: Vector3 in s.pellets:
				var aim: Vector3 = (s.point - s.origin).normalized()
				var angle := rad_to_deg(aim.angle_to(direction))
				if angle > s.cone + 0.01:
					outside += 1
				var right := aim.cross(Vector3.UP).normalized()
				var up := right.cross(aim).normalized()
				vertical = maxf(vertical, absf(rad_to_deg(asin(clampf(direction.dot(up), -1.0, 1.0)))) / maxf(s.cone, 0.01))
			if s.walk or not s.aimed:
				continue
			counted += 1
			var centre: Vector3 = s.centre
			var velocity: Vector3 = s.velocity
			if case[0] == GunRoll.MARKSMAN_RIFLE:
				# Where he was as its sight line locked, 0.2 s before.
				if line_shot >= locks.size():
					wrong.append("a shot with no sight line locked before it")
					continue
				centre = locks[line_shot][0]
				velocity = locks[line_shot][1]
				line_shot += 1
			# The intercept, found again here by stepping the flight time.
			var flight := 0.0
			for k in 20:
				flight = (centre + velocity * flight).distance_to(s.origin) / gun.projectile_speed
			var full: Vector3 = velocity * flight
			var led: Vector3 = s.point - centre
			if case[1] == 0.0:
				if led.length() > 0.01:
					wrong.append("%.2f m off where he is" % led.length())
			elif absf(led.length() - full.length() * case[1]) > full.length() * case[1] * 0.1 or led.dot(full) <= 0.0:
				wrong.append("led %.3f m, want %.2f of the intercept's %.3f m" % [led.length(), case[1], full.length()])
		_expect(counted >= 3 and wrong.is_empty(), "lead: a %s Guard's %d true shots at him %s across at 4 m/s: %s"
				% [Gunnery.NAMES[case[0]], counted, "sliding" if case[2] else "walking", wrong.slice(0, 3)])
		_expect(outside == 0, "spread: %d %s pellets left outside the Guard's cone of its aim" % [outside, Gunnery.NAMES[case[0]]])
		guard.free()
		_clear_shots()
	_expect(vertical >= 0.3, "spread: no pellet strayed up or down by more than %.2f of the cone: not a real cone" % vertical)
	player.state = player.State.WALK
	player.velocity = Vector3.ZERO
	player.health.max_health = pirate_health
	player.health.reset()
	player.set_physics_process(pirate_physics)


## The four crew fight numbers live on the Sandbox (2 aim true, 0.8 s
## handover, 1 m walk-in, 9 pellets). A crew Shotgun shot from 1 m with all
## 12 pellets striking (no spread, so every pellet flies true) takes 117
## Health and leaves a full-health Pirate alive.
func _check_pellet_cap() -> void:
	var numbers: Sandbox = ResourceLoader.load(Sandbox.PATH, "", ResourceLoader.CACHE_MODE_IGNORE)
	_expect(numbers.true_aim_count == 2 and is_equal_approx(numbers.true_aim_handover, 0.8)
			and is_equal_approx(numbers.walk_in_distance, 1.0) and numbers.shotgun_pellet_cap == 9,
			"the Sandbox's crew fight numbers are %d, %s s, %s m and %d pellets, want 2, 0.8 s, 1 m and 9"
			% [numbers.true_aim_count, numbers.true_aim_handover, numbers.walk_in_distance, numbers.shotgun_pellet_cap])
	var shotgun: WeaponProfile = GunRoll.weapon(GunRoll.SHOTGUN).duplicate()
	shotgun.spread_base_degrees = 0.0
	var gunnery: Gunnery = (load(Gunnery.PATHS[GunRoll.SHOTGUN]) as Gunnery).duplicate()
	gunnery.aim_error_degrees = 0.0
	var pirate: CharacterBody3D = load("res://scenes/player_3d.tscn").instantiate()
	pirate.auto_respawn = false
	pirate.position = CREW_AT + Vector3(0.0, 0.0, 40.0)
	world.add_child(pirate)
	pirate.set_physics_process(false)
	var guard: Crew3D = load("res://scenes/crew_3d.tscn").instantiate()
	guard.weapon = shotgun
	guard.gunnery = gunnery
	guard.target = pirate
	guard.layout = layout
	guard.position = CREW_AT
	world.add_child(guard)
	guard.set_physics_process(false)
	guard.routine = null
	pirate.global_position = CREW_AT + Vector3.FORWARD * 1.0
	guard.face_direction(Vector3.FORWARD)
	for i in 2:
		await physics_frame
	guard._last_seen = pirate.global_position
	guard._enter(Crew3D.State.FIGHT)
	guard._update_perception(STEP)
	await physics_frame
	guard._new_burst()
	guard._fire()
	var struck := [0]
	for pellet in guard.last_pellets:
		pellet.hit.connect(func(body: Node3D, _head: bool) -> void:
			if body == pirate:
				struck[0] += 1)
	while guard.last_pellets.any(func(p) -> bool: return is_instance_valid(p)):
		await physics_frame
	var taken: int = pirate.health.max_health - pirate.health.current
	_expect(pirate.health.max_health == 150 and struck[0] == 12 and taken == 117 and pirate.is_alive(),
			"pellet cap: a crew Shotgun shot from 1 m (aimed true: %s) struck with %d of 12 pellets and took %d of %d Health (alive: %s), want 12, 117 and alive"
			% [guard.last_aimed_true, struck[0], taken, pirate.health.max_health, pirate.is_alive()])
	guard.free()
	pirate.free()


## Standing still and exposed at full health against one Guard at its range
## (Pistol 6 m, Assault Rifle 7.5 m), the Guard behind a crate at its spot,
## over 20 seeded runs (seeds 1 to 20, fixed): the median time to die is
## within 40% of 10 s and 6 s. The twenty run side by side, each in its own
## Room with its own Pirate, so each fight is its own. Measured, not tuned
## to: see the ticket.
func _check_time_to_die() -> void:
	var cases := [[GunRoll.PISTOL, 6.0, 10.0], [GunRoll.ASSAULT_RIFLE, 7.5, 6.0]]
	for c in cases.size():
		var gun := GunRoll.weapon(cases[c][0])
		var range_m: float = cases[c][1]
		var want: float = cases[c][2]
		var pirates: Array[CharacterBody3D] = []
		var guards: Array[Crew3D] = []
		var died := {}
		for i in DIE_RUNS:
			var x0 := 1000 + c * 400 + i * 12
			var rig := _rig_room("DieShip%d_%d" % [c, i], Rect2i(x0, 0, 9, 12), [{"type": &"crate", "tile": Vector2i(x0 + 4, 2)}])
			var at := ShipBuilder3D.tile_to_world(Vector2i(x0 + 4, 1))
			var pirate: CharacterBody3D = load("res://scenes/player_3d.tscn").instantiate()
			pirate.auto_respawn = false
			pirate.position = at + Vector3(0.0, 0.0, range_m)
			world.add_child(pirate)
			pirate.set_physics_process(false)
			pirate.state = pirate.State.WALK
			pirate.died.connect(func() -> void: died[pirate] = true)
			pirates.append(pirate)
			var guard: Crew3D = load("res://scenes/crew_3d.tscn").instantiate()
			guard.weapon = gun
			guard.gunnery = Gunnery.for_weapon(gun)
			guard.target = pirate
			guard.layout = rig
			guard.position = at
			world.add_child(guard)
			guard.set_physics_process(false)
			guard.routine = null
			guard.face_direction(pirate.position - at)
			# Run i is seeded i + 1, whatever the suite's seed: the same
			# twenty fights on every run, so the median is a measurement and
			# not a draw.
			guard._rng.seed = i + 1
			guard._gap_jitter = CrewCombat.jitter(guard._rng)
			guard._new_burst()
			guards.append(guard)
		# Bolts that strike the ship within 2 m of where they were fired: the
		# crate a Guard fires over, which a pellet straying down must miss.
		var into_cover := [0]
		var watch := func(node: Node) -> void:
			var bolt := node as Projectile3D
			if bolt == null or not bolt.shooter in guards:
				return
			var start := bolt.position
			bolt.hit.connect(func(body: Node3D, _head: bool) -> void:
				if not body is CharacterBody3D and is_instance_valid(bolt) and bolt.global_position.distance_to(start) < 2.0:
					into_cover[0] += 1)
		get_first_node_in_group(&"projectiles").child_entered_tree.connect(watch)
		for i in 2:
			await physics_frame
		for i in DIE_RUNS:
			guards[i].hear_position(pirates[i].global_position)
			guards[i].set_physics_process(true)
		var times: Array[float] = []
		var t := 0.0
		var dead := {}
		while t < DIE_LIMIT and dead.size() < DIE_RUNS:
			await physics_frame
			t += STEP
			for pirate in died:
				if not dead.has(pirate):
					dead[pirate] = t
		get_first_node_in_group(&"projectiles").child_entered_tree.disconnect(watch)
		_expect(into_cover[0] == 0, "own cover: %d %s bolts struck the crate or floor within 2 m of the muzzle they left" % [into_cover[0], Gunnery.NAMES[cases[c][0]]])
		for pirate in pirates:
			times.append(dead.get(pirate, INF))
		times.sort()
		var median := (times[DIE_RUNS / 2 - 1] + times[DIE_RUNS / 2]) / 2.0
		print("  time to die, %s at %.1f m: median %.2f s (want %.0f s within 40%%), runs %s" % [Gunnery.NAMES[cases[c][0]], range_m, median, want,
				times.map(func(x: float) -> String: return "%.1f" % x)])
		_expect(absf(median - want) <= want * 0.4, "time to die: against a %s Guard at %.1f m the median of %d runs is %.2f s, want %.0f s within 40%%"
				% [Gunnery.NAMES[cases[c][0]], range_m, DIE_RUNS, median, want])
		for guard in guards:
			guard.free()
		for pirate in pirates:
			pirate.free()
		_clear_shots()


## One Gunnery per weapon, each file with the spec's starting numbers; a
## Guard holds its gun's Gunnery and fires that gun: its damage, projectile
## and time between shots live, every pellet of a Shotgun shot, the
## Marksman Rifle's 200 m/s bolt; bursts of its Gunnery's shots per burst
## and time down after; its cone the gun's base plus the Gunnery's aim
## error.
func _check_gunnery() -> void:
	# {file: [aim error, range near, range far, shots low, shots high, time down low, high]}
	var want := {
		"pistol": [7.5, 4.0, 8.0, 2, 3, 1.0, 2.0],
		"assault_rifle": [6.0, 5.0, 10.0, 3, 5, 1.5, 2.5],
		"shotgun": [8.0, 2.0, 5.0, 1, 1, 1.2, 1.5],
		"marksman_rifle": [0.0, 8.0, 14.0, 1, 1, 2.5, 4.0],
	}
	_expect(Gunnery.PATHS.size() == 4, "gunnery: %d Gunnery files listed, want 4" % Gunnery.PATHS.size())
	_expect(not ResourceLoader.exists("res://resources/gunnery/guard.tres") and not ResourceLoader.exists("res://resources/gunnery/worker.tres"),
			"gunnery: the Guard or Worker Gunnery file is still there")
	for path in Gunnery.PATHS:
		var gunnery: Gunnery = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
		var key := path.get_file().get_basename()
		_expect(gunnery != null and want.has(key), "gunnery: %s does not load" % path)
		if gunnery == null or not want.has(key):
			continue
		var w: Array = want[key]
		_expect(is_equal_approx(gunnery.aim_error_degrees, w[0]), "gunnery: %s aim error is %s degrees, want %s" % [key, gunnery.aim_error_degrees, w[0]])
		_expect(is_equal_approx(gunnery.range_near, w[1]) and is_equal_approx(gunnery.range_far, w[2]),
				"gunnery: %s range band is %s to %s m, want %s to %s" % [key, gunnery.range_near, gunnery.range_far, w[1], w[2]])
		_expect(gunnery.shots_per_burst_low == w[3] and gunnery.shots_per_burst_high == w[4],
				"gunnery: %s shots per burst %d to %d, want %d to %d" % [key, gunnery.shots_per_burst_low, gunnery.shots_per_burst_high, w[3], w[4]])
		_expect(is_equal_approx(gunnery.time_down_low, w[5]) and is_equal_approx(gunnery.time_down_high, w[6]),
				"gunnery: %s time down %s to %s s, want %s to %s" % [key, gunnery.time_down_low, gunnery.time_down_high, w[5], w[6]])
		_expect(is_equal_approx(gunnery.opening_spread, 3.0) and is_equal_approx(gunnery.closing_time, 2.0)
				and is_equal_approx(gunnery.reload_factor, 1.5), "gunnery: %s opening spread, closing time or reload factor is off" % key)

	var pistol: WeaponProfile = load("res://resources/weapons/pistol.tres")
	var guard := _crew()
	_expect(guard.weapon == pistol and guard.gunnery == load(Gunnery.PATHS[0]),
			"gunnery: a Guard given no gun does not hold the Pistol and its Gunnery")
	_expect(is_equal_approx(guard.base_cone_degrees(), 8.5), "gunnery: a Pistol Guard's cone is %.1f degrees, want 1 + 7.5" % guard.base_cone_degrees())
	_expect(guard.burst_length >= 2 and guard.burst_length <= 3, "gunnery: a Pistol Guard fires a %d-round burst, want 2 to 3" % guard.burst_length)

	_place(5.0)
	guard.face_direction(Vector3.FORWARD)
	guard._aim = Vector3.FORWARD
	var shot := guard._fire()
	_expect(shot != null and shot.damage == 25 and is_equal_approx(shot.speed, 80.0) and is_equal_approx(shot.lifetime, 0.5),
			"gunnery: a Pistol Guard's shot is not the Pistol's 25 damage at 80 m/s for 0.5 s")
	_expect(guard._shot_timer > pistol.fire_interval * CrewCombat.JITTER.x - 0.001
			and guard._shot_timer < pistol.fire_interval * CrewCombat.JITTER.y + 0.001,
			"gunnery: %.3f s to the next shot is not the Pistol's %.2f s, jittered" % [guard._shot_timer, pistol.fire_interval])
	pistol.damage = 40
	pistol.projectile_speed = 60.0
	var edited := guard._fire()
	_expect(edited != null and edited.damage == 40 and is_equal_approx(edited.speed, 60.0),
			"gunnery: a crew shot after editing the Pistol did not follow it")
	pistol.damage = 25
	pistol.projectile_speed = 80.0
	# Time down after a peek: the Gunnery's, drawn, varied by 30% either way.
	var pistol_gunnery: Gunnery = guard.gunnery
	var downs: Array[float] = []
	for n in 200:
		downs.append(CrewCover.down_time(pistol_gunnery, guard._rng))
	_expect(downs.min() >= pistol_gunnery.time_down_low * 0.7 - 0.001 and downs.max() <= pistol_gunnery.time_down_high * 1.3 + 0.001
			and downs.min() < pistol_gunnery.time_down_low and downs.max() > pistol_gunnery.time_down_high,
			"gunnery: 200 times down run %.2f to %.2f s, want the Pistol Gunnery's %.1f to %.1f s varied by 30%% either way"
			% [downs.min(), downs.max(), pistol_gunnery.time_down_low, pistol_gunnery.time_down_high])
	pistol_gunnery.aim_error_degrees = 2.0
	_expect(is_equal_approx(guard.base_cone_degrees(), 3.0), "gunnery: dialling the Pistol Gunnery's aim error did not reach its cone")
	pistol_gunnery.aim_error_degrees = 7.5
	guard.free()

	# Each gun fired by a Guard, as the ship build arms it.
	var bursts := {}
	for i in 4:
		var gun: WeaponProfile = GunRoll.weapon(i)
		var armed := _armed(gun)
		_expect(armed.gunnery == load(Gunnery.PATHS[i]), "gunnery: a %s Guard does not hold that gun's Gunnery" % Gunnery.NAMES[i])
		_expect(is_equal_approx(armed.base_cone_degrees(), gun.spread_base_degrees + armed.gunnery.aim_error_degrees),
				"gunnery: a %s Guard's cone is %.1f degrees" % [Gunnery.NAMES[i], armed.base_cone_degrees()])
		armed._aim = Vector3.FORWARD
		var first := armed._fire()
		_expect(first != null and armed.last_pellets.size() == gun.pellet_count and first.damage == gun.damage
				and is_equal_approx(first.lifetime, gun.projectile_lifetime),
				"gunnery: a %s Guard's shot is %d projectiles of %s damage, want %d of %d"
				% [Gunnery.NAMES[i], armed.last_pellets.size(), first.damage if first else "no", gun.pellet_count, gun.damage])
		if i == GunRoll.SHOTGUN:
			_expect(armed.last_pellets.size() == 12, "gunnery: a Shotgun Guard's shot spawns %d projectiles, want 12" % armed.last_pellets.size())
		if i == GunRoll.MARKSMAN_RIFLE:
			_expect(first != null and absf(first.speed - 200.0) <= 2.0,
					"gunnery: a Marksman Rifle Guard's bolt travels at %s m/s, want 200 within 1%%" % (first.speed if first else "no"))
		var lengths := {}
		for n in 60:
			armed._new_burst()
			lengths[armed.burst_length] = true
		bursts[Gunnery.NAMES[i]] = lengths.keys()
		var low: int = armed.gunnery.shots_per_burst_low
		var high: int = armed.gunnery.shots_per_burst_high
		_expect(lengths.keys().all(func(n: int) -> bool: return n >= low and n <= high) and lengths.size() == high - low + 1,
				"gunnery: a %s Guard's bursts run %s rounds, want every length %d to %d" % [Gunnery.NAMES[i], lengths.keys(), low, high])
		armed.free()
	for bolt in get_first_node_in_group(&"projectiles").get_children():
		bolt.free()


## True when [param node] and everything between it and [param body] is
## visible: it shows whenever the body does.
static func _shown_with(node: Node3D, body: Node3D) -> bool:
	var at: Node = node
	while at != null and at != body:
		if at is Node3D and not (at as Node3D).visible:
			return false
		at = at.get_parent()
	return at == body


## Where the gun-in-hand rigs stand: four open Rooms, one per gun.
const GUN_X0 := 6000
## How near each wrist must be to its place on the gun, aiming; and a
## Guard's bolt to its gun's Muzzle marker, metres.
const WRIST_TOLERANCE := 0.04
const MUZZLE_TOLERANCE := 0.05
## Seconds the four Guards fight in the gun-in-hand check: a Marksman Rifle
## fires about every 3 s.
const GUN_FIGHT := 12.0

## A Guard with each of the four guns (crew-combat ticket 16): aiming, each
## wrist within 4 cm of its place on the gun (the right on the grip, the
## left on the fore-end, or round the right hand on the Pistol), each grip
## and fore-end inside the gun model's own bounds; then fighting a Pirate in an open
## Room for 12 s, every bolt starting within 5 cm of its gun's Muzzle marker, which
## is the point the clear-shot test sweeps from for that aim; and dead, the
## gun hidden.
func _check_guns_in_hands() -> void:
	var guards: Array[Crew3D] = []
	var pirates: Array[CharacterBody3D] = []
	for i in 4:
		var x0 := GUN_X0 + i * 20
		var rig := _rig_room("GunShip%d" % i, Rect2i(x0, 0, 8, 12), [])
		var at := ShipBuilder3D.tile_to_world(Vector2i(x0 + 4, 2))
		var pirate: CharacterBody3D = load("res://scenes/player_3d.tscn").instantiate()
		pirate.auto_respawn = false
		pirate.position = at + Vector3(0.0, 0.0, 6.0)
		world.add_child(pirate)
		pirate.set_physics_process(false)
		pirate.state = pirate.State.WALK
		pirate.health.max_health = 100000
		pirate.health.reset()
		pirates.append(pirate)
		var gun: WeaponProfile = GunRoll.weapon(i)
		var guard: Crew3D = load("res://scenes/crew_3d.tscn").instantiate()
		guard.weapon = gun
		guard.gunnery = Gunnery.for_weapon(gun)
		guard.target = pirate
		guard.layout = rig
		guard.position = at
		world.add_child(guard)
		guard.set_physics_process(false)
		guard.routine = null
		guard.face_direction(pirate.position - at)
		guards.append(guard)
	# From the moment it spawns: in the tree, no frame run yet.
	var at_spawn := 0
	for guard in guards:
		if guard.gun != null and guard.gun.gun.is_visible_in_tree() and guard.gun.gun.scene_file_path == guard.weapon.model.resource_path:
			at_spawn += 1
	_expect(at_spawn == 4, "guns in hand: %d of 4 Guards just spawned show their Weapon Profile's model" % at_spawn)

	# Aiming: today's FIGHT, held still while the hold blends in.
	var wrists := {}
	var watchers := {}
	for guard in guards:
		guard.state = Crew3D.State.FIGHT
		guard._update_animation()
		var skeleton := guard.gun.get_skeleton()
		var measure := func() -> void:
			var got := []
			for side: String in ["R", "L"]:
				var wrist := (skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone("Wrist." + side))).origin
				got.append(wrist.distance_to(guard.gun.hand_place_global("grip" if side == "R" else "fore").origin))
			wrists[guard] = got
		watchers[guard] = measure
		skeleton.skeleton_updated.connect(measure)
	for i in 30:
		await physics_frame
	var far: Array[String] = []
	var off_gun: Array[String] = []
	for i in 4:
		var guard := guards[i]
		guard.gun.get_skeleton().skeleton_updated.disconnect(watchers[guard])
		var got: Array = wrists.get(guard, [INF, INF])
		if not guard.gun.aim >= 1.0 or got[0] > WRIST_TOLERANCE or got[1] > WRIST_TOLERANCE:
			far.append("%s: right %.3f m, left %.3f m (hold %.2f)" % [Gunnery.NAMES[i], got[0], got[1], guard.gun.aim])
		# Each hold is on the gun, inside its model's bounds: the grip, and
		# the fore-end of a long gun (the Pistol's left hand closes round
		# the right).
		var bounds := _bounds_in(guard.gun.gun)
		for which: String in ["grip"] if i == GunRoll.PISTOL else ["grip", "fore"]:
			var hold: Vector3 = CrewGun.HOLDS[guard.gun.kind][which][0]
			if not bounds.grow(0.005).has_point(hold):
				off_gun.append("%s %s at %s outside %s" % [Gunnery.NAMES[i], which, hold, bounds])
	print("  guns in hand, aiming: wrists off their places (right, left) %s" % [guards.map(func(g: Crew3D) -> String:
			var got: Array = wrists.get(g, [INF, INF])
			return "%s %.3f %.3f m" % [Gunnery.NAMES[guards.find(g)], got[0], got[1]])])
	_expect(far.is_empty(), "guns in hand: aiming, wrists off their places on the gun by %s, want within %.2f m" % [far, WRIST_TOLERANCE])
	_expect(off_gun.is_empty(), "guns in hand: a hold is not on its gun: %s" % [off_gun])

	# Fighting: every bolt from its gun's Muzzle marker.
	var starts := {}
	var worst := [0.0, 0.0]
	var wrong: Array[String] = []
	var watch := func(node: Node) -> void:
		var bolt := node as Projectile3D
		if bolt == null or not bolt.shooter in guards:
			return
		var shooter: Crew3D = bolt.shooter
		var muzzle := shooter.gun.muzzle
		var marker := muzzle.global_position
		var tested := shooter.aim_muzzle(shooter.global_position, shooter.last_aim_point)
		var name: String = Gunnery.NAMES[guards.find(shooter)]
		starts[name] = starts.get(name, 0) + 1
		worst[0] = maxf(worst[0], bolt.global_position.distance_to(marker))
		worst[1] = maxf(worst[1], tested.distance_to(marker))
		if bolt.global_position.distance_to(marker) > MUZZLE_TOLERANCE or tested.distance_to(marker) > MUZZLE_TOLERANCE \
				or not shooter.gun.gun.is_ancestor_of(muzzle) or muzzle.name != &"Muzzle":
			wrong.append("%s: bolt %.3f m and clear-shot point %.3f m off its Muzzle" % [name,
					bolt.global_position.distance_to(marker), tested.distance_to(marker)])
	var parent := get_first_node_in_group(&"projectiles")
	parent.child_entered_tree.connect(watch)
	for i in 4:
		guards[i].hear_position(pirates[i].global_position)
		guards[i].set_physics_process(true)
	for i in roundi(GUN_FIGHT / STEP):
		await physics_frame
	parent.child_entered_tree.disconnect(watch)
	for guard in guards:
		guard.set_physics_process(false)
	print("  guns in hand, fighting: bolts %s, furthest %.4f m from its Muzzle, clear-shot point %.4f m" % [starts, worst[0], worst[1]])
	_expect(starts.size() == 4 and starts.values().all(func(n: int) -> bool: return n >= 2) and wrong.is_empty(),
			"guns in hand: bolts per gun %s in %.0f s (want 2 or more each), %d off: %s" % [starts, GUN_FIGHT, wrong.size(), wrong.slice(0, 3)])

	# Dead: the gun goes with it.
	var dead := guards[1]
	dead.take_damage(100000, pirates[1])
	await physics_frame
	_expect(not dead.is_alive() and not dead.gun.gun.is_visible_in_tree() and not dead.gun.active,
			"guns in hand: a dead Guard's gun still shows")
	for guard in guards:
		guard.free()
	for pirate in pirates:
		pirate.free()
	_clear_shots()


## The bounds of every mesh in [param model], in its own space.
static func _bounds_in(model: Node3D) -> AABB:
	var bounds := AABB()
	var first := true
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		var to_model := mesh.transform
		var up: Node = mesh.get_parent()
		while up != model:
			to_model = (up as Node3D).transform * to_model
			up = up.get_parent()
		var box := to_model * mesh.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
	return bounds


## A Guard carrying [param gun] and its Gunnery, as [ShipBuilder3D] arms
## one, stood at CREW_AT.
func _armed(gun: WeaponProfile) -> Crew3D:
	var crew: Crew3D = load("res://scenes/crew_3d.tscn").instantiate()
	crew.crew_type = CrewTypes.Type.GUARD
	crew.weapon = gun
	crew.gunnery = Gunnery.for_weapon(gun)
	crew.target = player
	crew.layout = layout
	crew.position = CREW_AT
	world.add_child(crew)
	crew.set_physics_process(false)
	crew.routine = null
	return crew


## Two Guards fighting the Pirate for 10 s never start a burst on the same
## frame, or within the stagger of each other.
func _check_stagger() -> void:
	var pirate_health: int = player.health.max_health
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
	player.health.max_health = pirate_health
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


## Physics ticks until [param done] answers true, or -1 after [param limit]
## seconds.
func _seconds_until(limit: float, done: Callable) -> float:
	for i in int(limit / STEP):
		await physics_frame
		if done.call():
			return (i + 1) * STEP
	return -1.0


## A crate dropped in the test Room that the layout knows nothing of, so no
## route goes round it: a blocked path. Freed by the caller.
func _stray_crate(at: Vector3) -> Node3D:
	var crate: Node3D = load("res://scenes/props3d/prop_crate_3d.tscn").instantiate()
	crate.position = at
	world.add_child(crate)
	return crate


## A Guard running for a cover spot it cannot reach (boxed in by crates the
## walking grid knows nothing of) gives up on that spot within
## CrewCover.MOVE_GIVE_UP plus a tick and does not set off for it again for
## the next 3 s, rather than walking at it forever. The crates are stacked
## two high, so it cannot fight from inside the box: from its gun's muzzle
## (crew-combat ticket 16), 1.5 m up, a single crate in front is low cover
## it would shoot over and stay behind.
func _check_cover_blocked() -> void:
	player.health.max_health = 100000
	player.health.reset()
	var centre := ShipBuilder3D.tile_to_world(RING_CENTRE)
	player.global_position = centre
	player.state = player.State.WALK
	var guard := _armed(load("res://resources/weapons/pistol.tres"))
	guard.layout = ring_layout
	guard.global_position = ShipBuilder3D.tile_to_world(RING_STARTS[0])
	guard.face_direction(centre - guard.global_position)
	var crates: Array[Node3D] = []
	for side in [Vector3.LEFT, Vector3.RIGHT, Vector3.BACK]:
		crates.append(_stray_crate(guard.global_position + side))
		crates.append(_stray_crate(guard.global_position + side + Vector3.UP * 1.1))
	for i in 2:
		await physics_frame
	guard.hear_position(centre)
	guard.set_physics_process(true)
	var spot := Vector2i.MAX
	var set_off := -1.0
	var gave_up := -1.0
	var again := false
	var t := 0.0
	while t < 12.0:
		await physics_frame
		t += STEP
		var walking_to := guard.cover.tile if guard.cover.mode == CrewCover.Mode.MOVE else Vector2i.MAX
		if set_off < 0.0 and walking_to != Vector2i.MAX:
			set_off = t
			spot = walking_to
		elif set_off >= 0.0 and gave_up < 0.0 and walking_to != spot:
			gave_up = t
		elif gave_up >= 0.0 and walking_to == spot:
			again = true
		if gave_up >= 0.0 and t > gave_up + 3.0:
			break
	guard.set_physics_process(false)
	_expect(set_off >= 0.0 and gave_up >= 0.0 and gave_up - set_off <= CrewCover.MOVE_GIVE_UP + 0.1 and not again,
			"cover: a Guard boxed in set off for %s at %.2f s and gave it up at %.2f s (want within %.1f s), setting off for it again: %s"
			% [spot, set_off, gave_up, CrewCover.MOVE_GIVE_UP + 0.1, again])
	guard.free()
	for crate in crates:
		crate.free()
	player.health.max_health = 5
	player.health.reset()
	for shot in get_first_node_in_group(&"projectiles").get_children():
		shot.free()


## A patrolling Guard facing 90° off its way, setting off into the standing
## Pirate's body it is already pressed against (so it never gets moving):
## it turns to its direction of travel within 0.5 s, and so spots him
## within 1 s, rather than pressing on blind.
func _check_blocked_by_pirate() -> void:
	var guard := _crew()
	guard.face_direction(Vector3.LEFT)
	# Capsules touching (0.35 m each): blocked from its first step.
	_place(0.7)
	for i in 2:
		await physics_frame
	guard._path.assign([CREW_AT + Vector3.FORWARD * 4.0])
	guard.set_physics_process(true)
	var facing := await _seconds_until(2.0, func() -> bool: return guard.facing().dot(Vector3.FORWARD) > 0.9)
	var spotted := await _seconds_until(2.0, func() -> bool: return guard.perception.awareness >= 1.0)
	guard.set_physics_process(false)
	_expect(facing >= 0.0 and facing <= 0.5, "blocked: a Guard walking into the Pirate turned to its way after %.2f s, want within 0.5 s" % facing)
	_expect(spotted >= 0.0 and facing + spotted <= 1.0, "blocked: a Guard walking into the Pirate spotted him after %.2f s, want within 1 s" % (facing + spotted))
	guard.free()


## A Guard fighting the Pirate 6 m off whose eyes see him over or past
## cover its bolts would hit: once with him stood just behind a crate (the
## line from muzzle to torso dips into it), once with a locker at its
## shoulder that its barrel pokes past by less than a bolt's width (a bolt
## born touching it strikes it). In MUZZLE_SECONDS it puts no bolt into the
## cover from where it stood, steps more than 0.5 m off, fires only with its
## muzzle line clear, and puts bolts past the cover (into him, or the wall
## behind him when they miss).
func _check_muzzle_blocked() -> void:
	for rig in [["crate", Vector3(0.0, 0.0, -5.3)], ["locker", Vector3(0.52, 0.0, -0.65)]]:
		await _muzzle_rig(rig[0], CREW_AT + rig[1])


## Seconds the muzzle rigs run: the Guard now fights from cover and fires
## only when up, a few shots a peek.
const MUZZLE_SECONDS := 12.0

func _muzzle_rig(prop: String, at: Vector3) -> void:
	player.health.max_health = 100000
	player.health.reset()
	var guard := _crew()
	var cover: Node3D = load("res://scenes/props3d/prop_%s_3d.tscn" % prop).instantiate()
	cover.position = at
	world.add_child(cover)
	_place(6.0)
	for i in 2:
		await physics_frame
	var eyes_clear := not guard._blocked(guard.global_position + Vector3.UP * Crew3D.EYE_HEIGHT,
			player.global_position + Vector3.UP * Crew3D.EYE_HEIGHT)
	var tally := {"prop": 0, "from_spot": 0, "pirate": 0, "other": 0, "fired": 0, "blind": 0}
	var shots: Node = get_first_node_in_group(&"projectiles")
	var watch := func(node: Node) -> void:
		if node is Projectile3D:
			tally.fired += 1
			if guard._muzzle_blocked():
				tally.blind += 1
			(node as Projectile3D).hit.connect(func(body: Node3D, _head: bool) -> void:
				tally["prop" if body == cover else "pirate" if body == player else "other"] += 1
				if body == cover and guard.global_position.distance_to(CREW_AT) < 0.5:
					tally.from_spot += 1)
	shots.child_entered_tree.connect(watch)
	guard.perception.awareness = 1.0
	guard._last_seen = player.global_position
	guard._enter(Crew3D.State.FIGHT)
	guard.set_physics_process(true)
	var moved := 0.0
	for i in roundi(MUZZLE_SECONDS / STEP):
		await physics_frame
		moved = maxf(moved, guard.global_position.distance_to(CREW_AT))
	guard.set_physics_process(false)
	shots.child_entered_tree.disconnect(watch)
	_expect(eyes_clear, "muzzle (%s): the rig is wrong, the eye line is blocked" % prop)
	_expect(tally.from_spot == 0 and tally.blind == 0 and tally.pirate + tally.other > 0 and moved > 0.5,
			"muzzle (%s): a Guard whose muzzle line clips cover put %d bolts into it from where it stood (%d in all), fired %d of %d with its muzzle line blocked, and %d past it (%d into the Pirate), stepping at most %.1f m off in %.0f s"
			% [prop, tally.from_spot, tally.prop, tally.blind, tally.fired, tally.pirate + tally.other, tally.pirate, moved, MUZZLE_SECONDS])
	guard.free()
	cover.free()
	player.health.max_health = 5
	player.health.reset()
	for shot in shots.get_children():
		shot.free()


## Room 0 at x 400-409, y 0-9; the bar of props runs along y 4 from x 402
## to 406 (crate, three-tile console, crate).
func _build_cluttered() -> void:
	cluttered_layout = ShipLayout.new()
	var room := RoomData.new()
	room.rects = [Rect2i(400, 0, 10, 10)]
	room.props = [{"type": &"crate", "tile": Vector2i(402, 4)}, {"type": &"console", "tile": Vector2i(404, 4)},
			{"type": &"crate", "tile": Vector2i(406, 4)}]
	cluttered_layout.rooms = [room]
	var ship := Node3D.new()
	ship.name = "ClutteredShip"
	world.add_child(ship)
	ShipBuilder3D.build(cluttered_layout, ship)


## Room 0 at x 420-429, y 0-9; crates along y 4 from x 421 to 426.
func _build_lane() -> void:
	lane_layout = ShipLayout.new()
	var room := RoomData.new()
	room.rects = [Rect2i(420, 0, 10, 10)]
	for x in range(421, 427):
		room.props.append({"type": &"crate", "tile": Vector2i(x, 4)})
	lane_layout.rooms = [room]
	var ship := Node3D.new()
	ship.name = "LaneShip"
	world.add_child(ship)
	ShipBuilder3D.build(lane_layout, ship)


## Room 0 at x 430-439, y 0-5; crates along y 4 from x 430 to 433, so the
## lane is y 5 from the west wall to x 433.
func _build_pocket() -> void:
	pocket_layout = ShipLayout.new()
	var room := RoomData.new()
	room.rects = [Rect2i(430, 0, 10, 6)]
	for x in range(430, 434):
		room.props.append({"type": &"crate", "tile": Vector2i(x, 4)})
	pocket_layout.rooms = [room]
	var ship := Node3D.new()
	ship.name = "PocketShip"
	world.add_child(ship)
	ShipBuilder3D.build(pocket_layout, ship)


## A crew member walking to a point straight across a bar of props goes
## round it and arrives within ROUND_PROPS_TIME, rather than pressing into
## the console; from just beside the console (pressed against it) as well.
const ROUND_PROPS_TIME := 8.0

func _check_round_props() -> void:
	for from in [Vector2(404.5, 1.5), Vector2(403.5, 3.4)]:
		var walker := _crew()
		walker.layout = cluttered_layout
		walker.home_room = 0
		walker.global_position = Vector3(from.x, 0.0, from.y)
		walker._hold_timer = 60.0
		player.global_position = Vector3(60.0, 0.0, 60.0)
		var to := Vector3(404.5, 0.0, 7.5)
		walker._repath_to(to)
		walker.set_physics_process(true)
		var took := await _seconds_until(ROUND_PROPS_TIME + 2.0, func() -> bool:
				return walker._path.is_empty() and Vector2(walker.global_position.x - to.x, walker.global_position.z - to.z).length() < 0.6)
		walker.set_physics_process(false)
		_expect(took >= 0.0 and took <= ROUND_PROPS_TIME,
				"steering: from %s across a bar of props took %.1f s (stood at %s), want within %.0f s" % [from, took, walker.global_position, ROUND_PROPS_TIME])
		walker.free()


## A crew member walking head-on into another standing in its way (a body
## no route knows of) works its way round within UNSTICK_TIME.
const UNSTICK_TIME := 6.0

func _check_unstick() -> void:
	var blocker := _crew()
	blocker.global_position = CREW_AT + Vector3.FORWARD * 2.0
	var walker := _crew()
	player.global_position = Vector3(60.0, 0.0, 60.0)
	var to := CREW_AT + Vector3.FORWARD * 5.0
	walker._repath_to(to)
	for i in 2:
		await physics_frame
	walker.set_physics_process(true)
	var took := await _seconds_until(UNSTICK_TIME + 2.0, func() -> bool:
			return walker._path.is_empty() and walker.global_position.distance_to(to) < 0.6)
	walker.set_physics_process(false)
	_expect(took >= 0.0 and took <= UNSTICK_TIME,
			"steering: walking head-on into a crew member standing in its way took %.1f s (stood at %s), want within %.0f s" % [took, walker.global_position, UNSTICK_TIME])
	walker.free()
	blocker.free()


## A crew member in the pair's Rooms at [param at], walking to [param to].
func _pair_walker(at: Vector3, to: Vector3) -> Crew3D:
	var walker := _crew()
	walker.layout = pair_layout
	walker.home_room = 0 if at.x < 108.0 else 1
	walker.global_position = at
	walker._hold_timer = 60.0
	walker._repath_to(to)
	return walker


func _arrived(walker: Crew3D, to: Vector3) -> bool:
	return walker._path.is_empty() and Vector2(walker.global_position.x - to.x, walker.global_position.z - to.z).length() < 0.6


## Two crew walking head-on along the line through the pair's two-wide
## doorway (they meet in it, neither able to pass the other there) both
## reach their ends 10 m off within HEAD_ON_TIME: one gives way. At routine
## pace (1.8 m/s) they take 9.2 s and 7.4 s.
const HEAD_ON_TIME := 12.0

func _check_head_on_doorway() -> void:
	player.global_position = Vector3(60.0, 0.0, 60.0)
	# Shut: crew open it themselves (one opened by hand is a trace they go to look at).
	pair_door.close()
	var west := Vector3(103.5, 0.0, 4.0)
	var east := Vector3(113.5, 0.0, 4.0)
	var a := _pair_walker(west, east)
	var b := _pair_walker(east, west)
	for i in 2:
		await physics_frame
	a.set_physics_process(true)
	b.set_physics_process(true)
	var took := {a: -1.0, b: -1.0}
	for i in int((HEAD_ON_TIME + 2.0) / STEP):
		await physics_frame
		for pair in [[a, east], [b, west]]:
			if took[pair[0]] < 0.0 and _arrived(pair[0], pair[1]):
				took[pair[0]] = (i + 1) * STEP
		if took[a] >= 0.0 and took[b] >= 0.0:
			break
	a.set_physics_process(false)
	b.set_physics_process(false)
	for pair in [[a, "west", east], [b, "east", west]]:
		var t: float = took[pair[0]]
		_expect(t >= 0.0 and t <= HEAD_ON_TIME,
				"give way: the crew member from the %s, head-on in a two-wide doorway, took %.1f s to arrive (stood at %s), want within %.0f s" % [pair[1], t, pair[0].global_position, HEAD_ON_TIME])
	a.free()
	b.free()


## A crew member standing still in the one-wide gap between the west wall
## and a row of crates, square in the way of another walking straight
## through it: there is no stepping aside in the gap, but the long way round
## the row's other end is open, and the walker takes it, arriving within
## STANDING_TIME: about 17 m at routine pace (1.8 m/s) and the 2 s it takes
## to find itself stuck, 11.9 s.
const STANDING_TIME := 15.0

func _check_standing_in_gap() -> void:
	player.global_position = Vector3(60.0, 0.0, 60.0)
	var blocker := _crew()
	blocker.layout = lane_layout
	blocker.global_position = Vector3(420.5, 0.0, 4.5)
	var walker := _crew()
	walker.layout = lane_layout
	walker.home_room = 0
	walker.global_position = Vector3(420.5, 0.0, 1.5)
	walker._hold_timer = 60.0
	var to := Vector3(420.5, 0.0, 7.5)
	walker._repath_to(to)
	for i in 2:
		await physics_frame
	walker.set_physics_process(true)
	var took := await _seconds_until(STANDING_TIME + 2.0, func() -> bool: return _arrived(walker, to))
	walker.set_physics_process(false)
	_expect(took >= 0.0 and took <= STANDING_TIME,
			"give way: walking through a one-wide gap a crew member stands in, with a way round, took %.1f s (stood at %s), want within %.0f s" % [took, walker.global_position, STANDING_TIME])
	walker.free()
	blocker.free()


## A crew member at the dead end of a one-wide lane, walking out, with a
## Worker in the lane working at a crate for a minute: the Worker makes way
## and the walker arrives within LANE_TIME (measured 8.6 s), and the Worker
## goes back to work at its spot (within 1.5 m of the crate, facing it).
const LANE_TIME := 11.0

func _check_working_in_lane() -> void:
	player.global_position = Vector3(60.0, 0.0, 60.0)
	var worker := _crew(CrewTypes.Type.WORKER)
	worker.layout = pocket_layout
	worker.home_room = 0
	worker.global_position = Vector3(431.5, 0.0, 5.5)
	var job := CrewRoutine.Job.new()
	job.room = 0
	job.at = Vector3(431.5, 0.0, 5.5)
	job.prop_at = Vector3(431.5, 0.0, 4.5)
	job.face = job.prop_at - job.at
	job.duration = 60.0
	worker.routine = CrewRoutine.new()
	worker.routine.jobs.append(job)
	worker.job_phase = Crew3D.JobPhase.WORKING
	worker._hold_timer = 60.0
	var walker := _crew()
	walker.layout = pocket_layout
	walker.home_room = 0
	walker.global_position = Vector3(430.5, 0.0, 5.5)
	walker._hold_timer = 60.0
	var to := Vector3(437.5, 0.0, 1.5)
	walker._repath_to(to)
	for i in 2:
		await physics_frame
	worker.set_physics_process(true)
	walker.set_physics_process(true)
	var took := await _seconds_until(LANE_TIME + 2.0, func() -> bool: return _arrived(walker, to))
	var back := await _seconds_until(10.0, func() -> bool:
			return worker.job_phase == Crew3D.JobPhase.WORKING and worker._hold_timer < job.duration - 0.6)
	worker.set_physics_process(false)
	walker.set_physics_process(false)
	var to_prop := job.prop_at - worker.global_position
	to_prop.y = 0.0
	_expect(took >= 0.0 and took <= LANE_TIME,
			"give way: walking out of a dead-end lane past a Worker working in it took %.1f s (stood at %s), want within %.0f s" % [took, walker.global_position, LANE_TIME])
	_expect(back >= 0.0 and to_prop.length() <= 1.5 and worker.facing().dot(to_prop.normalized()) >= 0.8,
			"give way: the Worker that made way is not back at work at its crate (%.2f m off it, facing %.2f)" % [to_prop.length(), worker.facing().dot(to_prop.normalized())])
	walker.free()
	worker.free()


## Two Workers whose loops share one work Job (a console's single spot):
## while one works it the other neither works there too nor stands pressed
## against it for more than SHARED_PRESS seconds trying to get on the spot
## (from there a nudge lands it working off the spot), and every work sample
## of either is within the routines check's 1.5 m of its prop, facing it.
const SHARED_PRESS := 1.0

func _check_shared_work_spot() -> void:
	player.global_position = Vector3(60.0, 0.0, 60.0)
	var spots := CrewRoutine.work_spots(cluttered_layout)
	var shared: CrewRoutine.Job = spots[0]
	var stop := CrewRoutine._patrol_stop(cluttered_layout, 0)
	stop.at = Vector3(401.5, 0.0, 8.5)
	var crew: Array[Crew3D] = []
	for at in [shared.at, Vector3(404.5, 0.0, 8.5)]:
		var worker := _crew(CrewTypes.Type.WORKER)
		worker.layout = cluttered_layout
		worker.home_room = 0
		worker.global_position = at
		worker.routine = CrewRoutine.new()
		for job in [shared, stop]:
			var copy := CrewRoutine._copy(job)
			copy.duration = 6.0 if job == shared else 1.0
			worker.routine.jobs.append(copy)
		crew.append(worker)
	# The first is already at the console; the second sets off for it.
	crew[0].job_phase = Crew3D.JobPhase.WORKING
	crew[0]._hold_timer = 6.0
	crew[1]._hold_timer = 0.0
	crew[1].job_phase = Crew3D.JobPhase.WAITING
	for i in 2:
		await physics_frame
	var bad := []
	var shared_at_once := 0
	var pressed := 0.0
	var worked := 0
	for member in crew:
		member.set_physics_process(true)
	for i in 600:
		await physics_frame
		var on_shared := 0
		for member in crew:
			var job: CrewRoutine.Job = member.routine.current()
			if member.job_phase != Crew3D.JobPhase.WORKING or job.patrol:
				continue
			on_shared += 1
			if member._hold_timer > job.duration - 0.6:
				continue
			worked += 1
			var to_prop := job.prop_at - member.global_position
			to_prop.y = 0.0
			if to_prop.length() > 1.5 or member.facing().dot(to_prop.normalized()) < 0.8:
				bad.append("%.2f m, facing %.2f" % [to_prop.length(), member.facing().dot(to_prop.normalized())])
		if on_shared > 1:
			shared_at_once += 1
		for k in 2:
			var worker := crew[k]
			var other := crew[1 - k]
			if other.job_phase == Crew3D.JobPhase.WORKING and not other.routine.current().patrol \
					and worker.job_phase == Crew3D.JobPhase.WALKING and not worker.routine.current().patrol \
					and worker.global_position.distance_to(other.global_position) < 0.8:
				pressed += STEP
	for member in crew:
		member.set_physics_process(false)
	_expect(worked > 0, "work spot: neither Worker was seen working the shared console")
	_expect(shared_at_once == 0, "work spot: two Workers worked the one spot at the same time for %d frames" % shared_at_once)
	_expect(pressed <= SHARED_PRESS, "work spot: a Worker stood pressed against the one working its spot for %.1f s, want at most %.0f s" % [pressed, SHARED_PRESS])
	_expect(bad.is_empty(), "work spot: %d working samples away from or facing off the prop, e.g. %s" % [bad.size(), bad.slice(0, 3)])
	for member in crew:
		member.free()


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


## Room 0 at x 300-307, y 0-7, with a Hatch at (303, -1) and the pod outside.
func _build_hatched() -> void:
	hatch_layout = ShipLayout.new()
	var room := RoomData.new()
	room.rects = [Rect2i(300, 0, 8, 8)]
	hatch_layout.rooms = [room]
	var hatch := HatchData.new()
	hatch.room = 0
	hatch.tile = Vector2i(303, -1)
	hatch.horizontal = true
	hatch_layout.hatches = [hatch]
	hatch_ship = Node3D.new()
	hatch_ship.name = "HatchShip"
	world.add_child(hatch_ship)
	ShipBuilder3D.build(hatch_layout, hatch_ship, 0)


## An unopened Container draws nobody, an emptied one does. A Door crew
## opened draws nobody; one the Pirate left open does, and the crew member
## that reports it shuts it and goes On Edge.
func _check_container_and_door() -> void:
	var crew := _crew()
	player.global_position = Vector3(60.0, 0.0, 60.0)
	var box: Container3D = load("res://scenes/props3d/prop_container_3d.tscn").instantiate()
	box.position = CREW_AT + Vector3.FORWARD * 5.0
	world.add_child(box)
	for i in 2:
		await physics_frame
	crew._look_for_traces(1.0)
	_expect(crew._trace == null and crew.perception.awareness == 0.0, "traces: an unopened Container drew a crew member")
	box.open()
	crew._look_for_traces(1.0)
	_expect(crew._trace == box and crew.perception.band() == CrewPerception.Band.SUSPICIOUS,
			"traces: an emptied Container did not make a crew member suspicious")
	crew.free()
	box.free()

	var watcher := _guard_at(ShipBuilder3D.tile_to_world(Vector2i(112, 4)), pair_layout, Vector3.LEFT)
	pair_door.close()
	var opener := _crew()
	pair_door.open(opener)
	for i in 2:
		await physics_frame
	watcher._look_for_traces(1.0)
	_expect(watcher._trace == null, "traces: a Door crew opened counts as left open")
	pair_door.close(opener)
	pair_door.open()
	for i in 2:
		await physics_frame
	watcher.perception.awareness = 0.0
	watcher._look_for_traces(1.0)
	_expect(watcher._trace == pair_door and watcher.perception.band() == CrewPerception.Band.SUSPICIOUS,
			"traces: a Door the pirate left open did not make a crew member suspicious")
	watcher._report(pair_door)
	_expect(not pair_door.is_open and watcher.perception.on_edge and watcher.state == Crew3D.State.SEARCH,
			"traces: reporting a Door left open did not shut it and put a Guard On Edge searching")
	watcher.free()
	opener.free()


## A Guard that sees the boarding Hatch standing open walks into the pod;
## a Guard hunting the Pirate while he is in the pod routes in through the
## Hatch.
func _check_hatch() -> void:
	var pod: BoardingPod = hatch_ship.get_node("BoardingPod")
	var leaf: Door3D = hatch_ship.get_node("Hatches").get_child(0)
	var guard := _guard_at(ShipBuilder3D.tile_to_world(Vector2i(304, 6)), hatch_layout, Vector3.FORWARD)
	player.global_position = Vector3(60.0, 0.0, 60.0)
	leaf.open()
	for i in 2:
		await physics_frame
	guard.set_physics_process(true)
	var suspicious := false
	var in_pod := false
	for i in 600:
		await physics_frame
		suspicious = suspicious or guard.perception.awareness >= CrewPerception.SUSPICIOUS
		if pod.contains(guard.global_position):
			in_pod = true
			break
	guard.set_physics_process(false)
	_expect(suspicious and leaf.reported, "traces: the open boarding Hatch was not noticed and reported")
	_expect(in_pod, "traces: the Guard that found the open Hatch never walked into the pod")
	guard.free()

	var hunter := _guard_at(ShipBuilder3D.tile_to_world(Vector2i(302, 6)), hatch_layout, Vector3.FORWARD)
	hunter._last_seen = pod.spawn_point()
	hunter._enter(Crew3D.State.HUNT)
	var gap := ShipBuilder3D.hatch_center_world(hatch_layout.hatches[0])
	_expect(hunter._path.size() >= 2 and hunter._path[-1].is_equal_approx(pod.spawn_point())
			and hunter._path.any(func(p: Vector3) -> bool: return p.distance_to(gap) < 0.1),
			"traces: a Guard hunting the pirate in his pod does not route in through the Hatch: %s" % [hunter._path])
	hunter.free()


## --- the Shotgun against crew ---

## The Pirate, holding [param profile], [param distance] m in front of
## [param crew], aimed at its chest, or at [param at] when given.
func _aim_at_crew(crew: Crew3D, distance: float, profile: WeaponProfile, at := Vector3.INF) -> void:
	player.weapon = profile
	player.ammo = profile.magazine_size
	player.global_position = crew.global_position + Vector3.FORWARD * distance
	player.state = player.State.WALK
	player.rotation.y = PI
	var eye: Vector3 = player.head.global_position
	var chest: Vector3 = crew.global_position + Vector3.UP * 0.95 if at == Vector3.INF else at
	player.head.rotation.x = atan2(chest.y - eye.y, Vector2(chest.x - eye.x, chest.z - eye.z).length())
	# The Viewmodel's swap beat, and the bodies live in physics.
	for i in 40:
		await physics_frame


## One trigger pull, waited out until every pellet has struck or died and
## the volley has reported.
func _shotgun_shot() -> void:
	player._cooldown = 0.0
	player.fire()
	while player.last_pellets.any(func(p) -> bool: return is_instance_valid(p)):
		await physics_frame
	for i in 3:
		await physics_frame


## A Shotgun shot that kills one crew member reports one hit and one kill,
## however many of its 12 pellets land; two crew side by side each report
## once.
func _check_shotgun_one_kill() -> void:
	var pistol: WeaponProfile = player.weapon
	var shotgun: WeaponProfile = load("res://resources/weapons/shotgun.tres")
	var hits: Array = []
	var record := func(target: Node3D, killed: bool, _headshot: bool) -> void: hits.append([target, killed])
	player.hit_landed.connect(record)
	var crew := _crew()
	await _aim_at_crew(crew, 3.0, shotgun)
	await _shotgun_shot()
	_expect(not crew.is_alive(), "a centred Shotgun shot 3 m off left crew on %d" % crew.health.current)
	_expect(hits == [[crew, true]], "a Shotgun kill reported %s, want one kill" % [hits])
	crew.free()

	hits.clear()
	var left := _crew()
	var right := _crew()
	# Shoulder to shoulder, the crosshair between them, so the pellets split.
	left.global_position = CREW_AT + Vector3.LEFT * 0.3
	right.global_position = CREW_AT + Vector3.RIGHT * 0.3
	await _aim_at_crew(left, 3.0, shotgun)
	player.global_position = CREW_AT + Vector3.FORWARD * 3.0
	await _shotgun_shot()
	var reported := hits.map(func(h: Array) -> Node3D: return h[0])
	_expect(reported.size() == 2 and left in reported and right in reported,
			"a Shotgun shot between two crew reported %s, want each once" % [hits])
	left.free()
	right.free()
	player.hit_landed.disconnect(record)
	player.head.rotation.x = 0.0
	player.weapon = pistol
	player.ammo = pistol.magazine_size


## The Shotgun's range band, fired for real at a crew member stood still,
## as a loose guard on what the picked numbers gave when it was built
## (100 shots each: one shot killed 100% at 3 to 6 m, 89% at 8 m, 50% at
## 10 m and 20% at 12 m; two shots 100% to 10 m and 96% at 12 m). The band
## is tuned in the balance pass; this only catches a gun that stops killing
## up close or starts killing far off. Crew Health is pinned high so every
## pellet lands on the body, and a shot counts as a kill when its pellets
## add up to the Sandbox's crew Health. The scatter is seeded, so the run
## repeats.
func _check_shotgun_range() -> void:
	const SHOTS := 40
	var pistol: WeaponProfile = player.weapon
	var shotgun: WeaponProfile = load("res://resources/weapons/shotgun.tres")
	var crew_health: int = (load(Sandbox.PATH) as Sandbox).crew_health
	var crew := _crew()
	crew.health.max_health = 1000000
	player._rng.seed = 22
	var rates := {}
	for distance: float in [3.0, 4.0, 8.0, 12.0]:
		await _aim_at_crew(crew, distance, shotgun)
		var damage: Array[int] = []
		for i in SHOTS:
			crew.health.current = crew.health.max_health
			player.ammo = shotgun.magazine_size
			await _shotgun_shot()
			damage.append(crew.health.max_health - crew.health.current)
		var one := damage.filter(func(d: int) -> bool: return d >= crew_health).size()
		var two := 0
		for i in damage.size() - 1:
			two += int(damage[i] + damage[i + 1] >= crew_health)
		rates[distance] = [float(one) / damage.size(), float(two) / (damage.size() - 1)]
		print("  Shotgun at %.0f m: one shot kills %.0f%%, two shots %.0f%% (%d shots)" % [distance,
				rates[distance][0] * 100.0, rates[distance][1] * 100.0, SHOTS])
	_expect(rates[3.0][0] >= 0.95, "a centred Shotgun shot 3 m off killed only %.0f%% of the time" % (rates[3.0][0] * 100.0))
	_expect(rates[12.0][0] <= 0.45, "a Shotgun shot 12 m off killed %.0f%% of the time" % (rates[12.0][0] * 100.0))
	_expect(rates[8.0][1] >= 0.95, "two Shotgun shots 8 m off killed only %.0f%% of the time" % (rates[8.0][1] * 100.0))
	crew.free()
	player.head.rotation.x = 0.0
	player.weapon = pistol
	player.ammo = pistol.magazine_size


## --- Headshots ---

## A Roll a beat in, the head down at about crouch height: a stand-in for a
## crouch, which the crew rigs have no clip for.
const LOW_ROLL_SECONDS := 0.2


func _type_name(crew: Crew3D) -> String:
	return "Worker" if crew.is_worker() else "Guard"


## One Pistol or Assault Rifle shot at [param at] on [param crew] from
## [param distance] m, waited out until it has reported.
func _single_shot(crew: Crew3D, profile: WeaponProfile, at: Vector3, distance := 3.0) -> void:
	await _aim_at_crew(crew, distance, profile, at)
	player._bloom = 0.0
	player._cooldown = 0.0
	player.fire()
	while player.last_pellets.any(func(p) -> bool: return is_instance_valid(p)):
		await physics_frame
	for i in 3:
		await physics_frame


## A Pistol shot on a crew member's head does 38 and flashes the marker
## gold with the Headshot tick, on the body 25 and white; three Headshots
## kill and the kill is red. The Assault Rifle does 25 on either and its
## head hit reads as a body hit. A Shotgun shot whose pellets split between
## head and body does plain damage per pellet and reports once.
func _check_headshots() -> void:
	var pistol: WeaponProfile = load("res://resources/weapons/pistol.tres")
	var rifle: WeaponProfile = load("res://resources/weapons/assault_rifle.tres")
	var shotgun: WeaponProfile = load("res://resources/weapons/shotgun.tres")
	_expect(is_equal_approx(pistol.headshot_multiplier, 1.5) and is_equal_approx(rifle.headshot_multiplier, 1.0)
			and is_equal_approx(shotgun.headshot_multiplier, 1.0) and is_equal_approx(WeaponProfile.new().headshot_multiplier, 1.0),
			"headshot multipliers are %s, %s, %s, want 1.5, 1, 1 and 1 by default"
			% [pistol.headshot_multiplier, rifle.headshot_multiplier, shotgun.headshot_multiplier])
	var hud: Node = load("res://scenes/ui/hud.tscn").instantiate()
	root.add_child(hud)
	await process_frame
	hud.watch(player)
	var sounds: Array[StringName] = []
	var audio: Node = player.get_node("Audio")
	var listen := func(kind: StringName, _stream: AudioStream) -> void: sounds.append(kind)
	audio.played.connect(listen)
	var hits: Array = []
	var record := func(target: Node3D, killed: bool, headshot: bool) -> void: hits.append([target, killed, headshot])
	player.hit_landed.connect(record)
	const GOLD := Color(1.0, 0.8, 0.25)

	for type in [CrewTypes.Type.GUARD, CrewTypes.Type.WORKER]:
		var crew := _crew(type)
		await physics_frame
		var head: Vector3 = crew.head_zone.global_position
		_expect(head.y > 1.6 and head.y < 2.0, "the %s's head zone sits at %.2f m" % [_type_name(crew), head.y])
		var chest := crew.global_position + Vector3.UP * 0.95
		hits.clear()
		sounds.clear()
		await _single_shot(crew, pistol, head)
		_expect(crew.health.current == 62, "a Pistol Headshot on a %s left %d, want 62 (38 damage)" % [_type_name(crew), crew.health.current])
		_expect(hits == [[crew, false, true]], "a Pistol Headshot reported %s" % [hits])
		_expect(hud.hitmarker_color().is_equal_approx(GOLD), "a Headshot flashed %s, want gold" % hud.hitmarker_color())
		_expect(sounds.count(&"headshot") == 1 and sounds.count(&"hitmark") == 0, "a Headshot played %s" % [sounds])
		hits.clear()
		sounds.clear()
		await _single_shot(crew, pistol, chest)
		_expect(crew.health.current == 37, "a Pistol body hit on a %s left %d, want 37 (25 damage)" % [_type_name(crew), crew.health.current])
		_expect(hits == [[crew, false, false]], "a Pistol body hit reported %s" % [hits])
		_expect(hud.hitmarker_color().is_equal_approx(Color.WHITE), "a body hit flashed %s, want white" % hud.hitmarker_color())
		_expect(sounds.count(&"hitmark") == 1 and sounds.count(&"headshot") == 0, "a body hit played %s" % [sounds])
		crew.free()

	# Three Pistol Headshots kill; the last is a red kill marker.
	var target := _crew()
	await physics_frame
	hits.clear()
	for i in 3:
		await _single_shot(target, pistol, target.head_zone.global_position)
	_expect(not target.is_alive(), "three Pistol Headshots left a crew member on %d" % target.health.current)
	_expect(hits.size() == 3 and hits[2][1] == true and hits[2][2] == true, "three Headshots reported %s" % [hits])
	_expect(hud.hitmarker_is_kill() and hud.hitmarker_color().is_equal_approx(Color(1.0, 0.25, 0.2)),
			"a killing Headshot flashed %s, want red" % hud.hitmarker_color())
	target.free()

	# The Assault Rifle: 25 on either, and a head hit is a body hit to the eye.
	var rifle_target := _crew()
	await physics_frame
	hits.clear()
	await _single_shot(rifle_target, rifle, rifle_target.head_zone.global_position)
	_expect(rifle_target.health.current == 75, "an Assault Rifle head hit left %d, want 75" % rifle_target.health.current)
	_expect(hits == [[rifle_target, false, false]], "an Assault Rifle head hit reported %s, want a plain hit" % [hits])
	_expect(hud.hitmarker_color().is_equal_approx(Color.WHITE), "an Assault Rifle head hit flashed %s, want white" % hud.hitmarker_color())
	await _single_shot(rifle_target, rifle, rifle_target.global_position + Vector3.UP * 0.95)
	_expect(rifle_target.health.current == 50, "an Assault Rifle body hit left %d, want 50" % rifle_target.health.current)
	rifle_target.free()

	# The Shotgun aimed at the neck from 3 m: some pellets on the head, some
	# on the body, plain damage for each, one report.
	var split := _crew()
	await physics_frame
	split.health.max_health = 1000
	var mixed := false
	player._rng.seed = 5
	for attempt in 6:
		split.health.current = 1000
		hits.clear()
		var neck: Vector3 = split.head_zone.global_position + Vector3.DOWN * 0.2
		await _aim_at_crew(split, 3.0, shotgun, neck)
		player._cooldown = 0.0
		player.fire()
		var on_head := [0, 0]
		for pellet in player.last_pellets:
			pellet.hit.connect(func(body: Node3D, head: bool) -> void:
				if body == split:
					on_head[int(head)] += 1)
		while player.last_pellets.any(func(p) -> bool: return is_instance_valid(p)):
			await physics_frame
		for i in 3:
			await physics_frame
		if on_head[0] > 0 and on_head[1] > 0:
			mixed = true
			_expect(1000 - split.health.current == shotgun.damage * (on_head[0] + on_head[1]),
					"Shotgun pellets did %d for %d body and %d head pellets, want %d each"
					% [1000 - split.health.current, on_head[0], on_head[1], shotgun.damage])
			_expect(hits == [[split, false, false]], "a Shotgun shot split between head and body reported %s" % [hits])
			break
	_expect(mixed, "no Shotgun shot at the neck split its pellets between head and body")
	# A split shot that kills reports one kill.
	split.health.max_health = 100
	split.health.current = 100
	hits.clear()
	await _aim_at_crew(split, 2.0, shotgun, split.head_zone.global_position + Vector3.DOWN * 0.2)
	await _shotgun_shot()
	_expect(not split.is_alive() and hits == [[split, true, false]], "a split Shotgun kill reported %s" % [hits])
	split.free()

	player.hit_landed.disconnect(record)
	audio.played.disconnect(listen)
	hud.free()
	player.head.rotation.x = 0.0
	player.weapon = pistol
	player.ammo = pistol.magazine_size


## The Marksman Rifle does 50 on the body and 100 on the head: one Headshot
## kills a crew member of 100 Health, two body shots kill, one does not.
func _check_marksman_rifle_kills() -> void:
	var marksman: WeaponProfile = load("res://resources/weapons/marksman_rifle.tres")
	var pistol: WeaponProfile = load("res://resources/weapons/pistol.tres")
	_expect(marksman != null and marksman.damage == 50 and marksman.headshot_damage() == 100,
			"the Marksman Rifle does %s body and %s head, want 50 and 100"
			% ([marksman.damage, marksman.headshot_damage()] if marksman else ["none", "none"]))
	if marksman == null:
		return
	var hits: Array = []
	var record := func(target: Node3D, killed: bool, headshot: bool) -> void: hits.append([target, killed, headshot])
	player.hit_landed.connect(record)
	for type in [CrewTypes.Type.GUARD, CrewTypes.Type.WORKER]:
		var crew := _crew(type)
		await physics_frame
		await _single_shot(crew, marksman, crew.head_zone.global_position)
		_expect(not crew.is_alive() and hits == [[crew, true, true]],
				"one Marksman Rifle Headshot on a %s left %d Health and reported %s" % [_type_name(crew), crew.health.current, hits])
		crew.free()
		hits.clear()
		crew = _crew(type)
		await physics_frame
		var chest := crew.global_position + Vector3.UP * 0.95
		await _single_shot(crew, marksman, chest)
		_expect(crew.is_alive() and crew.health.current == 50,
				"one Marksman Rifle body shot on a %s left %d, want 50" % [_type_name(crew), crew.health.current])
		await _single_shot(crew, marksman, chest)
		_expect(not crew.is_alive(), "two Marksman Rifle body shots left a %s on %d" % [_type_name(crew), crew.health.current])
		_expect(hits == [[crew, false, false], [crew, true, false]], "two body shots reported %s" % [hits])
		crew.free()
		hits.clear()
	player.hit_landed.disconnect(record)
	player.head.rotation.x = 0.0
	player.weapon = pistol
	player.ammo = pistol.magazine_size


## The head zone rides the head bone: when a clip carries the head low,
## the zone goes with it, and a Pistol shot at the head where it now is
## is a Headshot. Crew have no crouch clip, so the Roll stands in for one.
func _check_head_follows_pose() -> void:
	var pistol: WeaponProfile = load("res://resources/weapons/pistol.tres")
	for type in [CrewTypes.Type.GUARD, CrewTypes.Type.WORKER]:
		var crew := _crew(type)
		await physics_frame
		var standing: Vector3 = crew.head_zone.global_position
		var anim := crew._anim
		anim.play(&"CharacterArmature|Roll")
		anim.seek(LOW_ROLL_SECONDS, true)
		anim.pause()
		for i in 3:
			await physics_frame
		var low: Vector3 = crew.head_zone.global_position
		var skeleton: Skeleton3D = crew.find_children("*", "Skeleton3D", true, false)[0]
		var bone: Vector3 = (skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone(&"Head"))).origin
		_expect(standing.y - low.y > 0.4, "the %s's head zone went from %.2f to %.2f m in the Roll, want at least 0.4 lower"
				% [_type_name(crew), standing.y, low.y])
		_expect(low.distance_to(bone) < 0.3, "the %s's head zone is %.2f m off its head bone" % [_type_name(crew), low.distance_to(bone)])
		var hits: Array = []
		var record := func(target: Node3D, killed: bool, headshot: bool) -> void: hits.append([target, killed, headshot])
		player.hit_landed.connect(record)
		await _single_shot(crew, pistol, low)
		_expect(hits == [[crew, false, true]], "a Pistol shot at the %s's lowered head reported %s, want a Headshot"
				% [_type_name(crew), hits])
		player.hit_landed.disconnect(record)
		crew.free()
	player.head.rotation.x = 0.0


## Nothing that strikes the Pirate is a Headshot: a crew shot at his head
## height does the Pistol's plain 25, though the bolt carries 1.5.
func _check_pirate_has_no_head() -> void:
	var crew := _crew()
	var shot := crew._fire()
	_expect(shot != null and is_equal_approx(shot.headshot_multiplier, 1.5),
			"a crew shot carries headshot multiplier %s, want the Pistol's 1.5" % (shot.headshot_multiplier if shot else -1.0))
	if shot != null:
		shot.free()
	var pirate: CharacterBody3D = load("res://scenes/player_3d.tscn").instantiate()
	pirate.auto_respawn = false
	pirate.position = CREW_AT + Vector3(0.0, 0.0, 30.0)
	world.add_child(pirate)
	pirate.set_physics_process(false)
	var high: Vector3 = pirate.head.global_position
	var bolt: Projectile3D = load("res://scenes/projectile_3d.tscn").instantiate()
	bolt.damage = crew.weapon.damage
	bolt.headshot_multiplier = crew.weapon.headshot_multiplier
	bolt.speed = 80.0
	bolt.launch(high + Vector3.FORWARD * 3.0, Vector3.BACK, crew, Crew3D.TEAM)
	var struck: Array = []
	bolt.hit.connect(func(body: Node3D, head: bool) -> void: struck.append([body, head]))
	get_first_node_in_group(&"projectiles").add_child(bolt)
	while is_instance_valid(bolt):
		await physics_frame
	_expect(struck == [[pirate, false]], "a crew shot at the Pirate's head struck %s" % [struck])
	_expect(pirate.health.current == 125, "a crew shot at the Pirate's head left him on %d, want 125" % pirate.health.current)
	pirate.free()
	crew.free()


## A seed replays (raid-smoke-bugs ticket 11). A bolt touching two bodies
## in one step strikes the one it is deepest in, whichever Jolt reports
## first (the order differs run to run): born on the floor inside a
## Guard's capsule, told of either first, it strikes the Guard. Of two crew
## blocking each other the one readied first acts, not the lower instance
## id (ids differ run to run): here it was instantiated second.
func _check_replays() -> void:
	var guard := _crew()
	guard.health.max_health = 1000000
	guard.health.reset()
	for i in 2:
		await physics_frame
	var floor_map: Node3D = world.get_node("Ship/Floor")
	for first: Node3D in [floor_map, guard]:
		var bolt: Projectile3D = load("res://scenes/projectile_3d.tscn").instantiate()
		bolt.monitoring = false
		bolt.launch(guard.global_position + Vector3.UP * 0.05, Vector3.FORWARD, player, player.TEAM)
		var struck: Array = []
		bolt.hit.connect(func(body: Node3D, _head: bool) -> void: struck.append(body))
		get_first_node_in_group(&"projectiles").add_child(bolt)
		bolt.set_physics_process(false)
		bolt._on_body_entered(first)
		_expect(struck == [guard], "replay: a bolt on the floor inside a Guard, told of the %s first, struck %s; want the Guard either way"
				% [first.name, struck.map(func(b: Node3D) -> String: return b.name)])
		await physics_frame
	guard.free()
	var scene: PackedScene = load("res://scenes/crew_3d.tscn")
	var later: Crew3D = scene.instantiate()
	var earlier: Crew3D = scene.instantiate()
	for crew: Crew3D in [earlier, later]:
		crew.target = player
		crew.layout = layout
		crew.position = CREW_AT + Vector3.FORWARD * (1.0 if crew == later else 0.0)
		world.add_child(crew)
		crew.set_physics_process(false)
	_expect(later._can_get_past(earlier) and earlier._can_get_past(later),
			"replay: two crew 1 m apart in an empty Room cannot get past each other")
	_expect(earlier._acts_first(later) and not later._acts_first(earlier),
			"replay: of two crew blocking each other, the one readied first (instantiated second) acts %s, the other %s; want only the first"
			% [earlier._acts_first(later), later._acts_first(earlier)])
	earlier.free()
	later.free()


## A crew member killed before it spotted the Pirate died unaware; one
## killed after did not.
func _check_died_unaware() -> void:
	var quiet := _crew()
	quiet.take_damage(1000, player)
	var loud := _crew()
	loud.perception.awareness = 1.0
	loud.take_damage(1000, player)
	_expect(quiet.died_unaware and not loud.died_unaware, "stealth: died_unaware is %s for an unaware kill, %s for a spotted one" % [quiet.died_unaware, loud.died_unaware])
	quiet.free()
	loud.free()


# --- cover (crew-combat ticket 18) ---------------------------------------------

## The ring: one Room 17 tiles square at x 500-516, y 0-16, the Pirate on
## its centre tile, a crate 5 tiles off him each way, and a Guard's start
## on the wall 8 tiles off him beyond each crate.
const RING_CENTRE := Vector2i(508, 8)
const RING_CRATES: Array[Vector2i] = [Vector2i(508, 3), Vector2i(508, 13), Vector2i(503, 8), Vector2i(513, 8)]
const RING_STARTS: Array[Vector2i] = [Vector2i(508, 0), Vector2i(508, 16), Vector2i(500, 8), Vector2i(516, 8)]
## The locker Room: 9 by 10 tiles at x 520-528, the Pirate at (524, 1), a
## locker (full height) at (524, 6), the Guard's start at (524, 9).
const FULL_PIRATE := Vector2i(524, 1)
const FULL_START := Vector2i(524, 9)
## The crate grid: 15 tiles square at x 540-554, a crate every fourth tile
## each way from (543, 3).
const CRATES_PIRATE := Vector2i(547, 1)
const CRATES_START := Vector2i(547, 13)
## Peeks watched per gun for the rhythm.
const RHYTHM_PEEKS := 20
## How far a walk's samples are apart, and the tolerance on its numbers.
const WALK_SAMPLE := 0.5
## Seconds of the three-Guard fight on a generated ship, and the stuck
## rule: trying to walk this long without moving STUCK_MOVE.
const SHIP_FIGHT := 60.0
const STUCK_TIME := 5.0
const STUCK_MOVE := 0.3


func _build_cover_rigs() -> void:
	var ring_props: Array[Dictionary] = []
	for at in RING_CRATES:
		ring_props.append({"type": &"crate", "tile": at})
	ring_layout = _rig_room("RingShip", Rect2i(500, 0, 17, 17), ring_props)
	full_layout = _rig_room("FullShip", Rect2i(520, 0, 9, 10), [{"type": &"locker", "tile": Vector2i(524, 6)}])
	var grid_props: Array[Dictionary] = []
	for x in [543, 547, 551]:
		for y in [3, 7, 11]:
			grid_props.append({"type": &"crate", "tile": Vector2i(x, y)})
	crates_layout = _rig_room("CratesShip", Rect2i(540, 0, 15, 15), grid_props)


func _rig_room(ship_name: String, rect: Rect2i, props: Array[Dictionary]) -> ShipLayout:
	var rig := ShipLayout.new()
	var room := RoomData.new()
	room.rects = [rect]
	room.props = props
	rig.rooms = [room]
	var ship := Node3D.new()
	ship.name = ship_name
	world.add_child(ship)
	ShipBuilder3D.build(rig, ship)
	return rig


## A Guard carrying [param gun] on [param rig] at [param tile], facing
## [param look].
func _rig_guard(gun: WeaponProfile, rig: ShipLayout, tile: Vector2i, look: Vector3) -> Crew3D:
	var guard := _armed(gun)
	guard.layout = rig
	guard.global_position = ShipBuilder3D.tile_to_world(tile)
	guard.face_direction(look - guard.global_position)
	return guard


## A tile of the walking grid a body can stand on.
func _open_tile(astar: AStarGrid2D, tile: Vector2i) -> bool:
	return astar.is_in_boundsv(tile) and not astar.is_point_solid(tile)


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


## A tile from which a crouched body is hidden from [param him]: the ray at
## 0.9 m from its centre to his torso is blocked.
func _hidden_tile(guard: Crew3D, tile: Vector2i, him: Vector3) -> bool:
	return guard._blocked(ShipBuilder3D.tile_to_world(tile) + Vector3.UP * Crew3D.COVER_HEIGHT,
			him + Vector3.UP * Crew3D.TORSO_HEIGHT)


## The walk [param trail] (positions, first to last) against the fair-walk
## rule, sampled every WALK_SAMPLE m along its length: no more than 2.5 m of
## it with a clear line from the torso to the eyes of the Pirate at
## [param him], and no sample nearer him than both ends less 1 m, each
## within WALK_SAMPLE. Empty when fair, else what was wrong.
func _walk_unfair(guard: Crew3D, trail: Array, him: Vector3) -> String:
	if trail.size() < 2:
		return ""
	var eye := him + Vector3.UP * Crew3D.EYE_HEIGHT
	var least := minf(_flat(trail[0], him), _flat(trail[-1], him)) - 1.0
	var samples: Array[Vector3] = [trail[0]]
	var carried := 0.0
	for i in range(1, trail.size()):
		var a: Vector3 = trail[i - 1]
		var b: Vector3 = trail[i]
		var leg := _flat(a, b)
		var along := WALK_SAMPLE - carried
		while along <= leg:
			samples.append(a.lerp(b, along / leg))
			along += WALK_SAMPLE
		carried = leg - (along - WALK_SAMPLE)
	var seen := 0.0
	var nearest := INF
	for sample in samples:
		nearest = minf(nearest, _flat(sample, him))
		if not guard._blocked(sample + Vector3.UP * Crew3D.TORSO_HEIGHT, eye):
			seen += WALK_SAMPLE
	if seen > CrewCover.OPEN_RUN + WALK_SAMPLE:
		return "%.1f m of a %d-sample walk in his view (want at most %.1f + %.1f)" % [seen, samples.size(), CrewCover.OPEN_RUN, WALK_SAMPLE]
	if nearest < least - WALK_SAMPLE:
		return "came within %.1f m of him, the nearer end %.1f m (want no nearer than it less 1 m, within %.1f)" % [nearest, least + 1.0, WALK_SAMPLE]
	return ""


## The ring: four Guards, one per gun, each 8 m from the Pirate with a crate
## between, told where he is at once. Each is within 0.5 m of a tile hidden
## from his torso at 0.9 m within 6 s, by a fair walk; down, its capsule is
## below the crate's top; it fires from its cover tile (low cover); and over
## 20 peeks its shots per burst and seconds down fall inside its Gunnery's
## ranges widened by 30%. A burst cut short by the magazine running dry, and
## a stretch down that held a reload, are its magazine's (crew-combat ticket
## 17): such a burst is never longer than the Gunnery's, and such a stretch
## lasts the reload (the Profile's empty time times the reload factor) or
## its time down if longer, a Shotgun's rack lead on top. Magazines (ticket
## 17): each fires exactly its Profile's magazine size (Pistol 12, Assault
## Rifle 30, Shotgun 6, Marksman Rifle 8) before its first reload, which is
## from empty, and a reload sound plays at its position as every reload
## starts.
func _check_cover_ring() -> void:
	player.health.max_health = 100000
	player.health.reset()
	var centre := ShipBuilder3D.tile_to_world(RING_CENTRE)
	player.global_position = centre
	player.state = player.State.WALK
	var guards: Array[Crew3D] = []
	var rec := {}
	for i in 4:
		var guard := _rig_guard(GunRoll.weapon(i), ring_layout, RING_STARTS[i], centre)
		guards.append(guard)
		rec[guard] = {"name": Gunnery.NAMES[i], "trail": [guard.global_position], "arrived": -1.0, "hidden": -1.0,
				"mode": CrewCover.Mode.NONE, "since": 0.0, "after_peek": false, "downs": [], "peeks": 0,
				"bursts": [], "burst_frame": guard.burst_frame, "shot_frame": -1, "shots": 0, "off_tile": 0,
				"tall": 0, "low": true, "capped": {}, "reload_down": false, "reload_downs": [],
				"first_reload": -1, "first_from_empty": false, "reloads": 0, "sounds_wrong": [], "stances": {}}
	var sounds := []  # [frame, player] of every sound this check sees start
	for guard in guards:
		guard.reload_started.connect(func(from_empty: bool) -> void:
			var r: Dictionary = rec[guard]
			r.reloads += 1
			if r.first_reload < 0:
				r.first_reload = r.shots
				r.first_from_empty = from_empty
			if guard.cover.mode == CrewCover.Mode.DOWN:
				r.reload_down = true
			var frame := Engine.get_physics_frames()
			var heard := sounds.filter(func(s: Array) -> bool:
				return s[0] == frame and is_instance_valid(s[1]) and (s[1] as AudioStreamPlayer3D).stream in guard.weapon.reload_sounds \
						and _flat((s[1] as Node3D).global_position, guard.global_position) <= 0.05)
			if heard.is_empty():
				r.sounds_wrong.append("frame %d" % frame))
	for i in 2:
		await physics_frame
	var shots: Node = get_first_node_in_group(&"projectiles")
	var watch := func(node: Node) -> void:
		if node is AudioStreamPlayer3D:
			sounds.append([Engine.get_physics_frames(), node])
			return
		var bolt := node as Projectile3D
		if bolt == null or not rec.has(bolt.shooter):
			return
		var shooter: Crew3D = bolt.shooter
		var r: Dictionary = rec[shooter]
		var frame := Engine.get_physics_frames()
		if r.shot_frame == frame:
			return  # another pellet of the same shot
		r.shot_frame = frame
		r.shots += 1
		if shooter.burst_frame != r.burst_frame:
			r.burst_frame = shooter.burst_frame
			r.bursts.append(0)
		if not r.bursts.is_empty():
			r.bursts[-1] += 1
			if shooter.magazine.is_dry():
				r.capped[r.bursts.size() - 1] = true
		if shooter.cover.spot == Vector3.INF or _flat(shooter.global_position, shooter.cover.spot) > 0.5:
			r.off_tile += 1
	shots.child_entered_tree.connect(watch)
	for guard in guards:
		guard.hear_position(centre)
		guard.set_physics_process(true)
	var t := 0.0
	while t < 150.0:
		await physics_frame
		t += STEP
		var done := true
		for guard in guards:
			var r: Dictionary = rec[guard]
			var mode: CrewCover.Mode = guard.cover.mode
			if r.arrived < 0.0:
				r.trail.append(guard.global_position)
				if mode == CrewCover.Mode.DOWN:
					r.arrived = t
					r.low = guard.cover.low
			var tile := ShipBuilder3D.world_to_tile(guard.global_position)
			if r.hidden < 0.0 and _flat(guard.global_position, ShipBuilder3D.tile_to_world(tile)) <= 0.5 \
					and _hidden_tile(guard, tile, centre):
				r.hidden = t
			if mode != r.mode:
				if r.mode == CrewCover.Mode.DOWN and r.after_peek:
					# Less any wait on its habit (a Marksman Rifle waiting for a
					# true-aim place, ticket 20): its time down is the rhythm.
					(r.reload_downs if r.reload_down else r.downs).append(t - r.since - guard.cover.waited)
				if mode == CrewCover.Mode.DOWN:
					r.after_peek = r.mode in [CrewCover.Mode.SHOOT, CrewCover.Mode.BACK]
					r.reload_down = guard.is_reloading()
					if r.after_peek:
						r.stances[guard.cover.stance] = true
				if mode == CrewCover.Mode.SHOOT:
					r.peeks += 1
				r.mode = mode
				r.since = t
			if mode == CrewCover.Mode.DOWN:
				var shape: CollisionShape3D = guard.get_node("CollisionShape3D")
				if shape.position.y + (shape.shape as CapsuleShape3D).height / 2.0 > 1.1:
					r.tall += 1
			if r.downs.size() < RHYTHM_PEEKS or r.bursts.size() - r.capped.size() <= RHYTHM_PEEKS or r.reload_downs.is_empty():
				done = false
		if done:
			break
	shots.child_entered_tree.disconnect(watch)
	for i in 4:
		var guard := guards[i]
		guard.set_physics_process(false)
		var r: Dictionary = rec[guard]
		var gunnery: Gunnery = guard.gunnery
		_expect(r.hidden >= 0.0 and r.hidden <= 6.0, "cover: a %s Guard told of the Pirate 8 m off past a crate was within 0.5 m of a hidden tile after %.2f s, want within 6 s"
				% [r.name, r.hidden])
		var unfair := _walk_unfair(guard, r.trail, centre)
		_expect(r.arrived >= 0.0 and unfair == "", "cover: a %s Guard's walk to cover (arrived at %.2f s): %s" % [r.name, r.arrived, unfair])
		_expect(r.low and r.shots > 0 and r.off_tile == 0, "cover: a %s Guard behind a crate (low cover: %s) fired %d of %d shots off its cover tile"
				% [r.name, r.low, r.off_tile, r.shots])
		_expect(r.tall == 0, "cover: a %s Guard down behind a crate had its capsule above the crate's 1.1 m top on %d frames" % [r.name, r.tall])
		# Its stance is picked again at every drop after a peek (ticket 22).
		_expect(r.stances.has(CrewPose.Stance.SQUAT) and r.stances.has(CrewPose.Stance.KNEE),
				"cover: a %s Guard dropping back after %d peeks was only ever down %s, want both a squat and one knee"
				% [r.name, r.peeks, r.stances.keys().map(func(k: int) -> String: return CrewPose.Stance.keys()[k])])
		# The last burst may still be running. A burst the magazine cut short
		# (it ran dry) is only held to the Gunnery's longest.
		var bursts: Array = []
		var cut: Array = []
		for b in r.bursts.size() - 1:
			(cut if r.capped.has(b) else bursts).append(r.bursts[b])
		var shots_low: float = gunnery.shots_per_burst_low * 0.7
		var shots_high: float = gunnery.shots_per_burst_high * 1.3
		_expect(bursts.size() >= RHYTHM_PEEKS and bursts.all(func(n: int) -> bool: return n >= shots_low and n <= shots_high),
				"cover: a %s Guard's %d bursts ran %s shots, want %d or more each %.1f to %.1f" % [r.name, bursts.size(), _counts(bursts), RHYTHM_PEEKS, shots_low, shots_high])
		_expect(cut.all(func(n: int) -> bool: return n >= 1 and n <= gunnery.shots_per_burst_high),
				"magazines: a %s Guard's bursts cut short by its magazine ran %s shots, want 1 to %d" % [r.name, _counts(cut), gunnery.shots_per_burst_high])
		var size: int = guard.weapon.magazine_size
		_expect(r.first_reload == size and r.first_from_empty,
				"magazines: a %s Guard fired %d shots before its first reload (from empty: %s), want exactly %d" % [r.name, r.first_reload, r.first_from_empty, size])
		_expect(r.reloads > 0 and r.sounds_wrong.is_empty(),
				"magazines: of a %s Guard's %d reloads, %d started with no reload sound at its position (%s)" % [r.name, r.reloads, r.sounds_wrong.size(), r.sounds_wrong.slice(0, 3)])
		var reload := guard.magazine.longest()
		var rack_lead := CrewHabit.RACK_LEAD if CrewHabit.racks(guard.weapon) else 0.0
		var reload_high := maxf(gunnery.time_down_high * 1.3, reload + rack_lead) + 3.0 * STEP
		_expect(r.reload_downs.size() > 0 and r.reload_downs.all(func(d: float) -> bool: return d >= reload - STEP and d <= reload_high),
				"magazines: a %s Guard's %d stretches down holding a reload lasted %s s, want each %.2f to %.2f s" % [r.name, r.reload_downs.size(),
				r.reload_downs.map(func(d: float) -> String: return "%.2f" % d), reload - STEP, reload_high])
		var down_low: float = gunnery.time_down_low * 0.7 - STEP
		var down_high: float = gunnery.time_down_high * 1.3 + STEP
		var downs: Array = r.downs
		_expect(downs.size() >= RHYTHM_PEEKS and r.peeks >= RHYTHM_PEEKS and downs.all(func(d: float) -> bool: return d >= down_low and d <= down_high),
				"cover: a %s Guard's %d peeks were down %.2f to %.2f s, want %d or more each %.2f to %.2f s"
				% [r.name, downs.size(), downs.min() if downs.size() > 0 else -1.0, downs.max() if downs.size() > 0 else -1.0, RHYTHM_PEEKS, down_low, down_high])
		guard.free()
	_clear_shots()
	player.health.max_health = 5
	player.health.reset()


## {shots in a burst: how many bursts}, for a failure line.
func _counts(values: Array) -> Dictionary:
	var out := {}
	for v in values:
		out[v] = out.get(v, 0) + 1
	return out


## Every sound stopped and given time to leave the mixer, so nothing a
## Guard's gun was still playing is held at exit (as test_pirate.gd does).
func _silence() -> void:
	for node in root.find_children("*", "", true, false):
		if node is AudioStreamPlayer or node is AudioStreamPlayer3D:
			node.stop()
	OS.delay_msec(300)
	await process_frame
	await process_frame


func _clear_shots() -> void:
	for shot in get_first_node_in_group(&"projectiles").get_children():
		shot.free()

## --- Magazines and reloads (crew-combat ticket 17) -------------------------

const RELOAD_TOLERANCE := 0.05
const RELOAD_SAME := 0.1
const TOP_UP_TOLERANCE := 0.1
const BREAK_OFF_WITHIN := 0.6

## A Guard of [param gun] in the ring, south of the crate, its own Pirate at
## the centre, told where he is and fighting. Returns [guard, pirate, shot
## frames (an Array the watcher appends each shot's physics frame to),
## watcher].
func _ring_fight(gun: WeaponProfile) -> Array:
	var centre := ShipBuilder3D.tile_to_world(RING_CENTRE)
	var pirate := _own_pirate(centre)
	var guard := _rig_guard(gun, ring_layout, RING_STARTS[1], centre)
	guard.target = pirate
	var fired: Array[int] = []
	var watch := func(node: Node) -> void:
		var bolt := node as Projectile3D
		if bolt != null and bolt.shooter == guard and (fired.is_empty() or fired[-1] != Engine.get_physics_frames()):
			fired.append(Engine.get_physics_frames())
	get_first_node_in_group(&"projectiles").child_entered_tree.connect(watch)
	for i in 2:
		await physics_frame
	guard.hear_position(centre)
	guard.set_physics_process(true)
	return [guard, pirate, fired, watch]


func _end_ring_fight(fight: Array) -> void:
	get_first_node_in_group(&"projectiles").child_entered_tree.disconnect(fight[3])
	fight[0].set_physics_process(false)
	fight[0].free()
	fight[1].free()
	_clear_shots()


## Open floor [param distance] from [param guard] where it sees [param pirate]
## standing and has a clear muzzle line to him from where it stands; INF with
## none. The Pirate is not moved.
func _seen_at(guard: Crew3D, rig: ShipLayout, distance: float) -> Vector3:
	var astar := CrewPaths.grid(rig)
	var eye := guard.global_position + Vector3.UP * Crew3D.EYE_HEIGHT
	for k in 48:
		var at := guard.global_position + Vector3.FORWARD.rotated(Vector3.UP, TAU * k / 48.0) * distance
		at.y = 0.0
		if not _open_tile(astar, ShipBuilder3D.world_to_tile(at)) or not CrewPaths.clear(astar, at, at):
			continue
		if guard._blocked(eye, at + Vector3.UP * Crew3D.EYE_HEIGHT) \
				or guard._muzzle_blocked_from(guard.global_position, at + Vector3.UP * Crew3D.TORSO_HEIGHT):
			continue
		return at
	return Vector3.INF


## An empty Assault Rifle reload takes 3.45 s (2.3 x 1.5) within 5%, down
## behind its cover, with no shot fired during it; a second one, the Guard
## hit twice and closed on (him moved 2.5 m off in its sight) during it,
## ends at the same time within 0.1 s, on the same spot, never restarted.
func _check_reloads() -> void:
	var gun := GunRoll.weapon(GunRoll.ASSAULT_RIFLE)
	var want: float = gun.reload_empty * Gunnery.for_weapon(gun).reload_factor
	_expect(is_equal_approx(want, 3.45), "reloads: the Assault Rifle's empty reload times its reload factor is %.2f s, want 3.45" % want)
	var fight := await _ring_fight(gun)
	var guard: Crew3D = fight[0]
	var pirate: CharacterBody3D = fight[1]
	var fired: Array[int] = fight[2]
	var events := []  # [frame, "start"/"end", from_empty or broken]
	guard.reload_started.connect(func(from_empty: bool) -> void: events.append([Engine.get_physics_frames(), "start", from_empty]))
	guard.reload_ended.connect(func(broken: bool) -> void: events.append([Engine.get_physics_frames(), "end", broken]))
	var durations: Array[float] = []
	for run in 2:
		# A few rounds left, so it runs dry soon.
		await _seconds_until(10.0, func() -> bool: return not guard.is_reloading())
		guard.magazine.rounds = 3
		guard._new_burst()
		events.clear()
		var started := await _seconds_until(30.0, func() -> bool: return not events.is_empty())
		_expect(started >= 0.0 and events[0][1] == "start" and events[0][2],
				"reloads: an Assault Rifle Guard left 3 rounds started no reload from empty in 30 s (run %d)" % run)
		if started < 0.0:
			break
		var start_frame: int = events[0][0]
		var tile: Vector2i = guard.cover.tile
		_expect(guard.cover.mode == CrewCover.Mode.DOWN, "reloads: an Assault Rifle Guard ran dry and reloaded in mode %s, want down behind its cover (run %d)"
				% [CrewCover.MODE_NAMES[guard.cover.mode], run])
		var him_was := pirate.global_position
		var close := Vector3.INF
		var left_tile := false
		var t := 0.0
		while guard.is_reloading() and t < 10.0:
			await physics_frame
			t += STEP
			if guard.is_reloading() and guard.cover.tile != tile:
				left_tile = true
			if run == 1:
				if absf(t - 0.5) < STEP * 0.5 or absf(t - 1.5) < STEP * 0.5:
					guard.take_damage(1, pirate)
				if absf(t - 1.0) < STEP * 0.5:
					close = _seen_at(guard, ring_layout, 2.5)
					if close != Vector3.INF:
						pirate.global_position = close
		var ends := events.filter(func(e: Array) -> bool: return e[1] == "end")
		var starts := events.filter(func(e: Array) -> bool: return e[1] == "start")
		var during := fired.filter(func(f: int) -> bool: return f >= start_frame and (ends.is_empty() or f <= ends[0][0]))
		var took: float = (ends[0][0] - start_frame) * STEP if not ends.is_empty() else INF
		durations.append(took)
		_expect(during.is_empty(), "reloads: an Assault Rifle Guard fired %d shots during its reload (run %d)" % [during.size(), run])
		if run == 0:
			_expect(absf(took - want) <= want * RELOAD_TOLERANCE,
					"reloads: an empty Assault Rifle reload took %.3f s, want %.2f s within %.0f%%" % [took, want, RELOAD_TOLERANCE * 100.0])
		else:
			_expect(close != Vector3.INF, "reloads: no floor 2.5 m from the reloading Guard in its sight to close on it from")
			_expect(absf(took - durations[0]) <= RELOAD_SAME and absf(took - want) <= RELOAD_SAME and starts.size() == 1 and not left_tile,
					"reloads: hit twice and closed on, an Assault Rifle Guard's reload took %.3f s (unhit %.3f s, want %.2f s, each within %.1f s), "
					% [took, durations[0], want, RELOAD_SAME] + "started %d times, left %s while reloading: %s" % [starts.size(), tile, left_tile])
		pirate.global_position = him_was
	_end_ring_fight(fight)


## A Pistol Guard down behind its cover with 5 rounds left and the Pirate
## unseen for 3 s is at a full magazine 1.2 x 1.5 s later, within 10%.
func _check_top_up() -> void:
	var gun := GunRoll.weapon(GunRoll.PISTOL)
	var want: float = gun.reload_tactical * Gunnery.for_weapon(gun).reload_factor
	var fight := await _ring_fight(gun)
	var guard: Crew3D = fight[0]
	var pirate: CharacterBody3D = fight[1]
	var down := await _seconds_until(15.0, func() -> bool: return guard.cover.mode == CrewCover.Mode.DOWN and not guard.is_reloading())
	_expect(down >= 0.0, "top up: the Pistol Guard never got down behind the crate")
	if down >= 0.0:
		guard.magazine.rounds = 5
		# Held down (its peeks are not what is checked), and him gone.
		guard.cover.timer = 20.0
		pirate.global_position = ShipBuilder3D.tile_to_world(RING_CENTRE) + Vector3(0.0, 0.0, 40.0)
		var unseen := -1.0
		var full := -1.0
		var from_empty := [true]
		guard.reload_started.connect(func(empty: bool) -> void: from_empty[0] = empty)
		var t := 0.0
		while t < 8.0 and full < 0.0:
			await physics_frame
			t += STEP
			if unseen < 0.0 and guard._seen_ago >= CrewCover.TOP_UP_UNSEEN:
				unseen = t
			if guard.magazine.is_full():
				full = t
		var took := full - unseen if full >= 0.0 and unseen >= 0.0 else INF
		_expect(not from_empty[0] and absf(took - want) <= want * TOP_UP_TOLERANCE and guard.cover.mode == CrewCover.Mode.DOWN,
				"top up: with 5 rounds left and him unseen %.0f s a Pistol Guard was full %.3f s later (topping up: %s, mode %s), want %.2f s within %.0f%%"
				% [CrewCover.TOP_UP_UNSEEN, took, not from_empty[0], CrewCover.MODE_NAMES[guard.cover.mode], want, TOP_UP_TOLERANCE * 100.0])
	_end_ring_fight(fight)


## A Shotgun Guard down behind a crate, reloading with 2 shells in, fires
## within 0.6 s of the Pirate coming into its sight 2.5 m off (inside 3 m);
## with him coming into sight 6 m off it fires nothing until it has loaded
## to 6.
func _check_shotgun_reload() -> void:
	var gun := GunRoll.weapon(GunRoll.SHOTGUN)
	for distance: float in [2.5, 6.0]:
		var fight := await _ring_fight(gun)
		var guard: Crew3D = fight[0]
		var pirate: CharacterBody3D = fight[1]
		var fired: Array[int] = fight[2]
		var down := await _seconds_until(15.0, func() -> bool: return guard.cover.mode == CrewCover.Mode.DOWN and not guard.is_reloading())
		var at := _seen_at(guard, ring_layout, distance) if down >= 0.0 else Vector3.INF
		_expect(at != Vector3.INF, "shotgun reload: the Guard never got down behind a crate with floor %.1f m off in its sight" % distance)
		if at == Vector3.INF:
			_end_ring_fight(fight)
			continue
		var ended := []
		guard.reload_ended.connect(func(broken: bool) -> void: ended.append([Engine.get_physics_frames(), broken, guard.magazine.rounds]))
		pirate.global_position = ShipBuilder3D.tile_to_world(RING_CENTRE) + Vector3(0.0, 0.0, 40.0)
		guard.magazine.rounds = 2
		guard.magazine.start()
		for i in roundi(0.2 / STEP):
			await physics_frame
		var shells: int = guard.magazine.rounds
		var shots_before := fired.size()
		pirate.global_position = at
		var in_sight := Engine.get_physics_frames()
		var limit := BREAK_OFF_WITHIN if distance < CrewCover.BREAK_OFF else guard.magazine.longest() + 2.0
		await _seconds_until(limit + 0.5, func() -> bool: return fired.size() > shots_before or not guard.is_alive())
		var first: int = fired[shots_before] if fired.size() > shots_before else -1
		var after: float = (first - in_sight) * STEP if first >= 0 else INF
		if distance < CrewCover.BREAK_OFF:
			_expect(shells == 2 and after <= BREAK_OFF_WITHIN and not ended.is_empty() and ended[0][1],
					"shotgun reload: reloading with %d shells in, him coming into sight %.1f m off, the first shot came %.2f s later (broken off: %s), want within %.1f s"
					% [shells, distance, after, ended.map(func(e: Array) -> bool: return e[1]), BREAK_OFF_WITHIN])
		else:
			var full_at: int = ended[0][0] if not ended.is_empty() else -1
			_expect(shells == 2 and not ended.is_empty() and not ended[0][1] and ended[0][2] == 6 and (first < 0 or first >= full_at),
					"shotgun reload: reloading with %d shells in, him coming into sight %.1f m off, it loaded to %s (broken off: %s) and fired %s, want to 6 before firing"
					% [shells, distance, ended.map(func(e: Array) -> int: return e[2]), ended.map(func(e: Array) -> bool: return e[1]),
					"%.2f s after he came into sight, %.2f s before it was full" % [after, (full_at - first) * STEP] if first >= 0 else "nothing"])
		_end_ring_fight(fight)


## Behind full cover (a locker it cannot fire over) a Guard fires from a
## neighbouring tile and is back on its cover tile within 2.5 s of its last
## shot, over four peeks that fired, having walked there fairly.
func _check_full_cover() -> void:
	player.health.max_health = 100000
	player.health.reset()
	var him := ShipBuilder3D.tile_to_world(FULL_PIRATE)
	player.global_position = him
	player.state = player.State.WALK
	var guard := _rig_guard(load("res://resources/weapons/pistol.tres"), full_layout, FULL_START, him)
	for i in 2:
		await physics_frame
	var shots: Node = get_first_node_in_group(&"projectiles")
	var wrong: Array[String] = []
	var tally := {"shots": 0, "last": -1.0, "frame": -1, "t": 0.0, "this_peek": false}
	var watch := func(node: Node) -> void:
		var bolt := node as Projectile3D
		if bolt == null or bolt.shooter != guard or tally.frame == Engine.get_physics_frames():
			return
		tally.frame = Engine.get_physics_frames()
		tally.shots += 1
		tally.last = tally.t
		tally.this_peek = true
		var at := ShipBuilder3D.world_to_tile(guard.global_position)
		var off: Vector2i = at - guard.cover.tile
		if guard.cover.low or at == guard.cover.tile or maxi(absi(off.x), absi(off.y)) != 1 \
				or _flat(guard.global_position, ShipBuilder3D.tile_to_world(at)) > 0.5:
			wrong.append("from %s, cover %s (low %s)" % [at, guard.cover.tile, guard.cover.low])
	shots.child_entered_tree.connect(watch)
	var feet := _watch_feet(guard)
	guard.hear_position(him)
	guard.set_physics_process(true)
	var trail: Array = [guard.global_position]
	var arrived := false
	var away := false
	var returns: Array[float] = []
	while tally.t < 40.0 and returns.size() < 4:
		await physics_frame
		tally.t += STEP
		if not arrived:
			trail.append(guard.global_position)
			arrived = guard.cover.mode == CrewCover.Mode.DOWN
		if guard.cover.spot == Vector3.INF:
			continue
		var out := _flat(guard.global_position, guard.cover.spot) > 0.5
		# A peek with nothing to shoot (it ducks after 1.2 s) has no last shot.
		if away and not out and tally.this_peek:
			returns.append(tally.t - tally.last)
		if not out:
			tally.this_peek = false
		away = out
	shots.child_entered_tree.disconnect(watch)
	guard.set_physics_process(false)
	var unfair := _walk_unfair(guard, trail, him)
	_expect(arrived and unfair == "", "full cover: the Guard's walk to cover: %s" % unfair)
	_expect(tally.shots > 0 and wrong.is_empty(), "full cover: of %d shots, %d were not from a tile beside its cover tile, e.g. %s"
			% [tally.shots, wrong.size(), wrong.slice(0, 2)])
	_expect(returns.size() >= 4 and returns.all(func(s: float) -> bool: return s <= 2.5),
			"full cover: back on its cover tile %s s after its last shot, want four peeks each within 2.5 s" % [returns])
	_unwatch(guard)
	_check_planted_feet(feet)
	guard.free()
	_clear_shots()
	player.health.max_health = 5
	player.health.reset()


## --- Guards' poses in a fight (crew-combat ticket 22) ---------------------

## Drops behind low cover counted for the squat's share, and its band.
const POSE_DROPS := 200
const SQUAT_SHARE_LOW := 0.5
const SQUAT_SHARE_HIGH := 0.7
## Squatting, the top of the head is below this; on one knee above this.
const SQUAT_HEAD_TOP := 1.05
const KNEE_HEAD_TOP := 1.15
## Squatting, the top of the body's collision is below this.
const SQUAT_BODY_TOP := 1.05
## The bolt fired level over the crate, metres up.
const LEVEL_BOLT := 1.2
## Running to low cover the hips are at least this much lower than running
## to full cover.
const RUN_LOWER := 0.2
## A planted foot moves no more than this; a foot within PLANTED_RISE of
## the lowest it stood in the check is planted, and one LIFTED above that
## has stepped.
const PLANTED_SLIDE := 0.15
const PLANTED_RISE := 0.02
const LIFTED := 0.04
## The tile behind the ring's south crate (508, 13), facing the Pirate.
const BEHIND_CRATE := Vector2i(508, 14)
## Where the cover search is made for each run (beside the spot), and where
## the Guard runs from: a far corner of the cover ring, and of the locker
## Room.
const RUN_NEAR := {"low": Vector2i(508, 15), "full": Vector2i(524, 8)}
const RUN_STARTS := {"low": Vector2i(501, 16), "full": Vector2i(528, 9)}

## Skeleton watchers to disconnect, by Guard.
var _bone_watchers := {}


## A bone of [param guard]'s rig in the world, as last posed (read in
## `skeleton_updated`, after the pose and the gun have run).
static func _bone_at(guard: Crew3D, bone: String) -> Vector3:
	var sk := guard.pose.get_skeleton()
	return (sk.global_transform * sk.get_bone_global_pose(sk.find_bone(bone))).origin


func _watch_bones(guard: Crew3D, watch: Callable) -> void:
	var sk := guard.pose.get_skeleton()
	sk.skeleton_updated.connect(watch)
	if not _bone_watchers.has(guard):
		_bone_watchers[guard] = []
	_bone_watchers[guard].append(watch)


func _unwatch(guard: Crew3D) -> void:
	if guard.pose == null:
		return
	var sk := guard.pose.get_skeleton()
	for watch: Callable in _bone_watchers.get(guard, []):
		if sk.skeleton_updated.is_connected(watch):
			sk.skeleton_updated.disconnect(watch)
	_bone_watchers.erase(guard)


## Records [param guard]'s feet in the world on every frame it steps out from
## full cover, stands there or steps back ([method CrewCover.stepping]):
## {"steps": [[[foot L, foot R], ...] per step out], "moved": [how far its
## body went on each]}.
func _watch_feet(guard: Crew3D) -> Dictionary:
	var feet := {"steps": [], "moved": [], "from": Vector3.INF, "on": false}
	_watch_bones(guard, func() -> void:
		var stepping := guard.cover.stepping()
		if stepping and not feet.on:
			feet.steps.append([])
			feet.moved.append(0.0)
			feet.from = guard.global_position
		feet.on = stepping
		if stepping:
			feet.steps[-1].append([_bone_at(guard, "Foot.L"), _bone_at(guard, "Foot.R")])
			feet.moved[-1] = maxf(feet.moved[-1], _flat(guard.global_position, feet.from)))
	return feet


## Stepping out and back, neither foot bone moves more than PLANTED_SLIDE
## while it is the planted foot: on the floor (within PLANTED_RISE of the
## lowest it stood), measured from where it was set down. Each foot must
## also have lifted off the floor (it stepped), on step outs that moved the
## body at least 0.7 m.
func _check_planted_feet(feet: Dictionary) -> void:
	var steps: Array = feet.steps
	var worst := 0.0
	var lifts := [0, 0]
	var floor_y := [INF, INF]
	for step: Array in steps:
		for frame: Array in step:
			for f in 2:
				floor_y[f] = minf(floor_y[f], (frame[f] as Vector3).y)
	for step: Array in steps:
		for f in 2:
			var set_at := Vector3.INF
			var lifted := false
			for frame: Array in step:
				var at: Vector3 = frame[f]
				if at.y <= floor_y[f] + PLANTED_RISE:
					if set_at == Vector3.INF:
						set_at = at
					worst = maxf(worst, at.distance_to(set_at))
				else:
					set_at = Vector3.INF
					if at.y > floor_y[f] + LIFTED:
						lifted = true
			if lifted:
				lifts[f] += 1
	print("  step out: %d step outs (body moved %s m), furthest a planted foot moved %.3f m, steps with each foot lifted %s"
			% [steps.size(), feet.moved.map(func(m: float) -> String: return "%.2f" % m), worst, lifts])
	_expect(steps.size() >= 4 and feet.moved.all(func(m: float) -> bool: return m >= 0.7),
			"step out: %d step outs from full cover moving the body %s m, want 4 or more of at least 0.7 m" % [steps.size(), feet.moved])
	_expect(worst <= PLANTED_SLIDE, "step out: a planted foot moved %.3f m stepping out and back, want at most %.2f m" % [worst, PLANTED_SLIDE])
	_expect(lifts[0] >= steps.size() and lifts[1] >= steps.size(),
			"step out: of %d step outs the left foot lifted on %d and the right on %d, want both on every one (feet that step)" % [steps.size(), lifts[0], lifts[1]])


## Running to low cover the hips are at least RUN_LOWER lower than running to
## full cover, on average over each run's frames (0.25 s into the run, over
## 2 m/s). Each spot is the one the cover search picks from beside it (the
## crate south of the cover ring's centre: low cover; the locker: full
## cover), and the Guard runs to it from a far corner of the Room.
func _check_runs() -> void:
	var hips := {"low": [], "full": []}
	var ended := {}
	for kind: String in ["low", "full"]:
		var rig := ring_layout if kind == "low" else full_layout
		var him := ShipBuilder3D.tile_to_world(RING_CENTRE if kind == "low" else FULL_PIRATE)
		var pirate := _own_pirate(him)
		var guard := _rig_guard(GunRoll.weapon(GunRoll.ASSAULT_RIFLE), rig, RUN_NEAR[kind], him)
		guard.target = pirate
		for i in 2:
			await physics_frame
		guard.hear_position(him)
		var found := guard.cover.find(0)
		guard.global_position = ShipBuilder3D.tile_to_world(RUN_STARTS[kind])
		guard._enter(Crew3D.State.COVER)
		if not found.is_empty():
			guard.cover._claim(found)
		_watch_bones(guard, func() -> void:
			var cover := guard.cover
			if cover.mode == CrewCover.Mode.MOVE and cover.clock >= 0.25 and Vector2(guard.velocity.x, guard.velocity.z).length() >= 2.0:
				hips[kind].append(_bone_at(guard, "Hips").y))
		guard.set_physics_process(true)
		await _seconds_until(8.0, func() -> bool: return guard.cover.mode == CrewCover.Mode.DOWN)
		ended[kind] = [not found.is_empty() and guard.cover.mode == CrewCover.Mode.DOWN, found.get("low", null)]
		guard.set_physics_process(false)
		_unwatch(guard)
		guard.free()
		pirate.free()
		_clear_shots()
	var mean := func(a: Array) -> float: return a.reduce(func(x: float, y: float) -> float: return x + y, 0.0) / maxf(a.size(), 1.0)
	var low_mean: float = mean.call(hips.low)
	var full_mean: float = mean.call(hips.full)
	print("  runs: hips %.3f m running to low cover (%d frames), %.3f m to full cover (%d frames)" % [low_mean, hips.low.size(), full_mean, hips.full.size()])
	_expect(ended.low == [true, true] and ended.full == [true, false], "runs: [got down there, its spot low cover] %s, want low cover then full cover" % [ended])
	_expect(hips.low.size() >= 20 and hips.full.size() >= 20 and full_mean - low_mean >= RUN_LOWER,
			"runs: hips %.3f m running to low cover and %.3f m to full cover (%d and %d frames), want at least %.2f m lower"
			% [low_mean, full_mean, hips.low.size(), hips.full.size(), RUN_LOWER])


## Down behind the ring's south crate (1.1 m), an Assault Rifle Guard: over
## POSE_DROPS drops after a peek between 50% and 70% are squats and the pose
## changes between some two drops in a row, the capsule's top following each
## stance; squatting, the top of its head zone is under 1.05 m and its
## capsule's top under 1.05 m, and a bolt fired level at 1.2 m from the far
## side strikes nothing of it; on one knee its head zone's top is over
## 1.15 m and the same bolt strikes its head zone, a Headshot. In neither
## stance does any bolt over the crate (level across its width, or down from
## his eyes at every height of its body) strike its body.
func _check_down_poses() -> void:
	var centre := ShipBuilder3D.tile_to_world(RING_CENTRE)
	var pirate := _own_pirate(centre)
	var guard := _rig_guard(GunRoll.weapon(GunRoll.ASSAULT_RIFLE), ring_layout, BEHIND_CRATE, centre)
	guard.target = pirate
	guard.health.max_health = 100000
	guard.health.reset()
	for i in 2:
		await physics_frame
	var cover := guard.cover
	cover.tile = BEHIND_CRATE
	cover.spot = guard.global_position
	cover.step = Vector3.INF
	cover.low = true
	cover.has_peek = true
	var stances: Array = []
	var tops_wrong: Array[String] = []
	var shape: CollisionShape3D = guard.get_node("CollisionShape3D")
	for i in POSE_DROPS:
		# Up over the crate, then back down: a drop after a peek.
		cover._stand()
		cover._set_mode(CrewCover.Mode.SHOOT)
		cover._duck()
		stances.append(cover.stance)
		var top: float = shape.position.y + (shape.shape as CapsuleShape3D).height / 2.0
		if cover.mode != CrewCover.Mode.DOWN or not is_equal_approx(top, CrewPose.BODY_TOP.get(cover.stance, -1.0)):
			tops_wrong.append("drop %d %s top %.2f" % [i, CrewPose.Stance.keys()[cover.stance], top])
	var squats := stances.count(CrewPose.Stance.SQUAT)
	var share := float(squats) / POSE_DROPS
	var changed := false
	for i in range(1, stances.size()):
		changed = changed or stances[i] != stances[i - 1]
	print("  down poses: %d of %d drops squats (%.0f%%), the rest on one knee" % [squats, POSE_DROPS, share * 100.0])
	_expect(share >= SQUAT_SHARE_LOW and share <= SQUAT_SHARE_HIGH and squats + stances.count(CrewPose.Stance.KNEE) == POSE_DROPS,
			"down poses: %d of %d drops behind low cover were squats (%.0f%%), want %.0f%% to %.0f%%, the rest one knee"
			% [squats, POSE_DROPS, share * 100.0, SQUAT_SHARE_LOW * 100.0, SQUAT_SHARE_HIGH * 100.0])
	_expect(changed, "down poses: the pose never changed between two drops in a row over %d drops" % POSE_DROPS)
	_expect(tops_wrong.is_empty(), "down poses: the capsule's top did not follow the stance: %s" % [tops_wrong.slice(0, 3)])

	for stance: CrewPose.Stance in [CrewPose.Stance.SQUAT, CrewPose.Stance.KNEE]:
		var name: String = CrewPose.Stance.keys()[stance].to_lower()
		cover._stand()
		cover._stances = [stance] as Array[CrewPose.Stance]
		cover._get_down(30.0)
		for i in 30:
			await physics_frame  # the pose blends in (0.15 s)
		var zone := guard.head_zone
		var radius := (zone.get_child(0).shape as SphereShape3D).radius * zone.global_transform.basis.get_scale().y
		var head := zone.global_position
		var head_top := head.y + radius
		var body_top: float = shape.global_position.y + (shape.shape as CapsuleShape3D).height / 2.0
		# The bolt: level at 1.2 m, from beyond the crate straight at the head.
		var from := Vector3(head.x, LEVEL_BOLT, ShipBuilder3D.tile_to_world(RING_CENTRE).z + 2.0)
		var level := await _bolt_hits(pirate, from, Vector3(head.x, LEVEL_BOLT, head.z + 2.0))
		var on_guard := level.filter(func(h: Array) -> bool: return h[0] == guard)
		print("  down poses, %s: head zone top %.3f m (centre %.3f), capsule top %.3f m, the level bolt at %.1f m struck %s"
				% [name, head_top, head.y, body_top, LEVEL_BOLT, level.map(func(h: Array) -> String: return "%s%s" % [(h[0] as Node).name, " (head)" if h[1] else ""])])
		if stance == CrewPose.Stance.SQUAT:
			_expect(head_top < SQUAT_HEAD_TOP, "down poses: squatting, the top of the head is %.3f m, want below %.2f m" % [head_top, SQUAT_HEAD_TOP])
			_expect(body_top < SQUAT_BODY_TOP, "down poses: squatting, the capsule's top is %.3f m, want below %.2f m" % [body_top, SQUAT_BODY_TOP])
			_expect(on_guard.is_empty(), "down poses: squatting behind a 1.1 m crate, the level bolt at %.1f m struck it %s, want nothing" % [LEVEL_BOLT, on_guard])
		else:
			_expect(head_top > KNEE_HEAD_TOP, "down poses: on one knee, the top of the head is %.3f m, want above %.2f m" % [head_top, KNEE_HEAD_TOP])
			_expect(on_guard.size() == 1 and on_guard[0][1], "down poses: on one knee behind a 1.1 m crate, the level bolt at %.1f m struck %s, want its head zone (a Headshot)"
					% [LEVEL_BOLT, level])
		# Never its body over the crate: level bolts across its width, and
		# bolts down from his eyes at its body.
		var body_hits: Array[String] = []
		var eye := centre + Vector3.UP * Crew3D.EYE_HEIGHT
		var shots: Array = []
		for y: float in [1.2, 1.3, 1.45, 1.6]:
			for side: float in [-0.3, -0.15, 0.15, 0.3]:
				shots.append([Vector3(head.x + side, y, from.z), Vector3(head.x + side, y, head.z + 2.0)])
		for y: float in [0.2, 0.4, 0.6, 0.8, 1.0]:
			for side: float in [-0.25, 0.0, 0.25]:
				var aim := guard.global_position + Vector3(side, y, 0.0)
				shots.append([eye, eye + (aim - eye) * 2.0])
		for shot: Array in shots:
			for h: Array in await _bolt_hits(pirate, shot[0], shot[1]):
				if h[0] == guard and not h[1]:
					body_hits.append("%s to %s" % [shot[0], shot[1]])
		_expect(body_hits.is_empty(), "down poses: %s behind a 1.1 m crate, %d of %d bolts over it struck its body: %s"
				% [name, body_hits.size(), shots.size(), body_hits.slice(0, 3)])
	guard.free()
	pirate.free()
	_clear_shots()


## What one bolt of [param shooter]'s, fired from [param from] toward
## [param to], struck: [[body, on its head], ...] (empty: nothing).
func _bolt_hits(shooter: Node3D, from: Vector3, to: Vector3) -> Array:
	var bolt: Projectile3D = load("res://scenes/projectile_3d.tscn").instantiate()
	bolt.damage = 1
	bolt.launch(from, to - from, shooter, shooter.get_team())
	var hits: Array = []
	bolt.hit.connect(func(body: Node3D, on_head: bool) -> void: hits.append([body, on_head]))
	get_first_node_in_group(&"projectiles").add_child(bolt)
	for i in ceili(from.distance_to(to) / bolt.speed / STEP) + 2:
		await physics_frame
		if not is_instance_valid(bolt) or bolt.is_queued_for_deletion():
			break
	if is_instance_valid(bolt):
		bolt.free()
	return hits


## In the crate grid: a Guard down in cover that the Pirate, moved, sees
## crouched has left that tile for another hidden from him within 2 s (and
## walks there fairly); one he then stands 2.5 m from, in its sight, picks
## its next spot at least 1 m further from him.
func _check_flanked_and_closed_on() -> void:
	player.health.max_health = 100000
	player.health.reset()
	var him := ShipBuilder3D.tile_to_world(CRATES_PIRATE)
	player.global_position = him
	player.state = player.State.WALK
	var guard := _rig_guard(load("res://resources/weapons/pistol.tres"), crates_layout, CRATES_START, him)
	for i in 2:
		await physics_frame
	guard.hear_position(him)
	guard.set_physics_process(true)
	var down := await _seconds_until(8.0, func() -> bool: return guard.cover.mode == CrewCover.Mode.DOWN)
	_expect(down >= 0.0, "flanked: the Guard never got down in the crate grid (mode %s)" % CrewCover.MODE_NAMES[guard.cover.mode])
	var old: Vector2i = guard.cover.tile

	# Somewhere he sees it crouched, 4 to 8 m off, on open floor, with
	# somewhere else in reach for it to go.
	var astar := CrewPaths.grid(crates_layout)
	var crouched := guard.global_position + Vector3.UP * Crew3D.COVER_HEIGHT
	var flank := Vector3.INF
	for tile: Vector2i in crates_layout.rooms[0].tiles():
		var at := ShipBuilder3D.tile_to_world(tile)
		var far := _flat(at, guard.global_position)
		if not _open_tile(astar, tile) or far < 4.0 or far > 8.0:
			continue
		if not guard._blocked(crouched, at + Vector3.UP * Crew3D.EYE_HEIGHT) and _has_cover_from(guard, at, 0):
			flank = at
			break
	_expect(flank != Vector3.INF, "flanked: the rig has no tile that sees the Guard crouched at %s" % old)
	if down >= 0.0 and flank != Vector3.INF:
		player.global_position = flank
		var trail: Array = [guard.global_position]
		var left := -1.0
		var t := 0.0
		while t < 6.0:
			await physics_frame
			t += STEP
			trail.append(guard.global_position)
			var now: Vector2i = guard.cover.tile
			if left < 0.0 and now != Vector2i.MAX and now != old and _hidden_tile(guard, now, flank) \
					and _flat(guard.global_position, ShipBuilder3D.tile_to_world(old)) > 0.5:
				left = t
			if left >= 0.0 and guard.cover.mode == CrewCover.Mode.DOWN:
				break
		_expect(left >= 0.0 and left <= 2.0, "flanked: seen crouched from %s, the Guard left %s for a hidden tile after %.2f s (now %s, mode %s), want within 2 s"
				% [ShipBuilder3D.world_to_tile(flank), old, left, guard.cover.tile, CrewCover.MODE_NAMES[guard.cover.mode]])
		var unfair := _walk_unfair(guard, trail, flank)
		_expect(guard.cover.mode == CrewCover.Mode.DOWN and unfair == "", "flanked: the walk to its next spot (mode %s): %s"
				% [CrewCover.MODE_NAMES[guard.cover.mode], unfair])
		him = flank

	# Too close: him 2.5 m off in its sight, while it is down, where it has
	# a spot at least a metre further to go to (only a Shotgun takes cover
	# within 4 m of him, so from some spots there is none: he then moves
	# where he sees it crouched once more, and it picks again, up to three
	# times).
	var close := Vector3.INF
	for round in 4:
		await _seconds_until(6.0, func() -> bool: return guard.cover.mode == CrewCover.Mode.DOWN)
		var eye := guard.global_position + Vector3.UP * Crew3D.EYE_HEIGHT
		for k in 32:
			var at := guard.global_position + Vector3.FORWARD.rotated(Vector3.UP, TAU * k / 32.0) * 2.5
			at.y = 0.0
			if not _open_tile(astar, ShipBuilder3D.world_to_tile(at)) or guard._blocked(eye, at + Vector3.UP * Crew3D.EYE_HEIGHT):
				continue
			# Not crowding a crate: a body there would stand inside it.
			if not CrewPaths.clear(astar, at, at) or not _has_cover_from(guard, at, -1):
				continue
			close = at
			break
		if close != Vector3.INF or round == 3:
			break
		var seen_from := guard.global_position + Vector3.UP * Crew3D.COVER_HEIGHT
		var held: Vector2i = guard.cover.tile
		for tile: Vector2i in crates_layout.rooms[0].tiles():
			var at := ShipBuilder3D.tile_to_world(tile)
			var far := _flat(at, guard.global_position)
			if _open_tile(astar, tile) and far >= 4.0 and far <= 8.0 and _flat(at, player.global_position) > 2.0 \
					and not guard._blocked(seen_from, at + Vector3.UP * Crew3D.EYE_HEIGHT) and _has_cover_from(guard, at, 0):
				player.global_position = at
				break
		await _seconds_until(4.0, func() -> bool: return guard.cover.tile != held and guard.cover.mode == CrewCover.Mode.DOWN)
	_expect(close != Vector3.INF, "too close: no open floor 2.5 m from the Guard in its sight with a spot further off to go to")
	if close != Vector3.INF and guard.cover.mode == CrewCover.Mode.DOWN:
		var before: Vector2i = guard.cover.tile
		var from := _flat(guard.global_position, close)
		player.global_position = close
		var moved := await _seconds_until(1.0, func() -> bool: return guard.cover.tile != before)
		var next := guard.cover.spot
		_expect(moved >= 0.0 and next != Vector3.INF and _flat(next, close) >= from + 1.0,
				"too close: with him %.1f m off in its sight the Guard's next spot is %s, %.1f m from him (mode %s), want at least %.1f m"
				% [from, guard.cover.tile, _flat(next, close) if next != Vector3.INF else -1.0, CrewCover.MODE_NAMES[guard.cover.mode], from + 1.0])
	guard.set_physics_process(false)
	guard.free()
	_clear_shots()
	player.health.max_health = 5
	player.health.reset()


## Whether [param guard] would find a spot (CrewCover.find, [param want])
## with the Pirate seen at [param at]: so a rig puts him where there is
## somewhere for it to go.
func _has_cover_from(guard: Crew3D, at: Vector3, want: int) -> bool:
	var seen := guard._last_seen
	guard._last_seen = at
	var found := guard.cover.find(want)
	guard._last_seen = seen
	return not found.is_empty()


## In the empty test Room (no prop, no corner out of his sight) a Guard told
## of the Pirate 8 m off fires at him from where it stands within 3 s, and
## never closes to under 4 m in 6 s.
func _check_open_fight() -> void:
	player.health.max_health = 100000
	player.health.reset()
	var guard := _crew()
	_place(8.0)
	for i in 2:
		await physics_frame
	guard.hear_position(player.global_position)
	guard.set_physics_process(true)
	var first := -1.0
	var moved_by := 0.0
	var nearest := INF
	var t := 0.0
	while t < 6.0:
		await physics_frame
		t += STEP
		nearest = minf(nearest, _flat(guard.global_position, player.global_position))
		if first < 0.0 and _has_fired(guard):
			first = t
			moved_by = _flat(guard.global_position, CREW_AT)
	guard.set_physics_process(false)
	_expect(first >= 0.0 and first <= 3.0 and moved_by < 0.5 and guard.cover.mode == CrewCover.Mode.OPEN,
			"open fight: with no cover a Guard first fired after %.2f s, %.1f m from where it stood (mode %s), want within 3 s where it stands"
			% [first, moved_by, CrewCover.MODE_NAMES[guard.cover.mode]])
	_expect(nearest >= 4.0, "open fight: with no cover a Guard closed to %.1f m of him, want never under 4 m" % nearest)
	guard.free()
	_clear_shots()
	player.health.max_health = 5
	player.health.reset()


## Sixty simulated seconds of three Guards (rolled guns) fighting the Pirate
## in the largest Room of a generated medium ship, the Pirate moved to a
## fresh spot every 10 s: no Guard is stuck (trying to walk without moving
## 0.3 m for 5 s), no two ever claim one tile, no claimed tile is beside a
## Breaker, and never more than one Guard is between cover tiles at once
## (walking to a tile after leaving one it got down on), not counting a
## flanker (crew-combat ticket 21).
func _check_cover_fight_on_ship() -> void:
	world.free()
	world = Node3D.new()
	root.add_child(world)
	var ship_seed := randi_range(1, 1_000_000)
	var ship_layout := ShipGenerator.generate(&"medium", ship_seed)
	var ship := Node3D.new()
	ship.name = "Ship"
	world.add_child(ship)
	ShipBuilder3D.build(ship_layout, ship)
	for member in ship.get_node("Crew").get_children():
		member.free()
	var shots := Node3D.new()
	shots.add_to_group(&"projectiles")
	world.add_child(shots)
	player = load("res://scenes/player_3d.tscn").instantiate()
	world.add_child(player)
	player.set_physics_process(false)
	player.health.max_health = 100000
	player.health.reset()
	player.state = player.State.WALK

	var tag := "ship fight (medium seed %d)" % ship_seed
	var astar := CrewPaths.grid(ship_layout)
	var room := -1
	for i in ship_layout.rooms.size():
		if ship_layout.rooms[i].role != &"corridor" and (room < 0 or ship_layout.rooms[i].tiles().size() > ship_layout.rooms[room].tiles().size()):
			room = i
	var open: Array[Vector3] = []
	for tile: Vector2i in ship_layout.rooms[room].tiles():
		if _open_tile(astar, tile):
			open.append(ShipBuilder3D.tile_to_world(tile))
	var middle := ShipBuilder3D.room_center_world(ship_layout.rooms[room])
	open.sort_custom(func(a: Vector3, b: Vector3) -> bool: return _flat(a, middle) < _flat(b, middle))
	var him := open[0]
	player.global_position = him
	var near: Array[Vector3] = []
	for r in CrewCombat.rooms_near(ship_layout, [room]):
		for tile: Vector2i in ship_layout.rooms[r].tiles():
			var at := ShipBuilder3D.tile_to_world(tile)
			if _open_tile(astar, tile) and _flat(at, him) >= 5.0 and _flat(at, him) <= 10.0:
				near.append(at)
	var guards: Array[Crew3D] = []
	var crew_scene: PackedScene = load("res://scenes/crew_3d.tscn")
	while guards.size() < 3 and not near.is_empty():
		var at: Vector3 = near.pop_at(randi_range(0, near.size() - 1))
		if guards.any(func(g: Crew3D) -> bool: return _flat(g.global_position, at) < 2.0):
			continue
		var guard: Crew3D = crew_scene.instantiate()
		guard.crew_type = CrewTypes.Type.GUARD
		guard.weapon = GunRoll.weapon(randi_range(0, 3))
		guard.gunnery = Gunnery.for_weapon(guard.weapon)
		guard.target = player
		guard.layout = ship_layout
		guard.home_room = room
		guard.position = at
		ship.get_node("Crew").add_child(guard)
		guard.face_direction(him - at)
		guards.append(guard)
	_expect(guards.size() == 3, "%s: only %d Guards placed" % [tag, guards.size()])
	var breakers := {}
	for r in ship_layout.rooms.size():
		breakers.merge(guards[0]._breaker_tiles(r))
	for i in 2:
		await physics_frame
	# Each starts where it has cover in reach (a spot, or the hiding
	# fall-back): in a long Room with few props a Guard 10 m down it may
	# have none and rightly fight in the open all minute, which says nothing
	# about the cover fight.
	for guard in guards:
		guard._last_seen = him
		while guard.cover.find(0).is_empty() and guard.cover.find(0, true).is_empty() and not near.is_empty():
			var at: Vector3 = near.pop_at(randi_range(0, near.size() - 1))
			if guards.all(func(g: Crew3D) -> bool: return g == guard or _flat(g.global_position, at) >= 2.0):
				guard.global_position = at
				guard.face_direction(him - at)
	for guard in guards:
		guard.hear_position(him)
	var watch := {}
	for guard in guards:
		watch[guard] = {"anchor": guard.global_position, "walking": 0.0, "still": 0.0}
	var stuck: Array[String] = []
	var shared: Array[String] = []
	var by_breaker: Array[String] = []
	var went_down := {}
	# The tile each last got down on (or waited in ambush on), for who is
	# between cover tiles.
	var down_on := {}
	var was_moving := {}
	var moves := 0
	var two_moving: Array[String] = []
	var t := 0.0
	var frames := roundi(SHIP_FIGHT / STEP)
	for frame in frames:
		await physics_frame
		t += STEP
		if frame > 0 and frame % 600 == 0:
			# A fresh spot for him, clear of every Guard.
			for _try in 20:
				var at: Vector3 = open[randi_range(0, open.size() - 1)]
				if guards.all(func(g: Crew3D) -> bool: return _flat(g.global_position, at) >= 3.0):
					player.global_position = at
					break
		var claimed := {}
		var moving: Array[String] = []
		for guard in guards:
			var held: Vector2i = down_on.get(guard, Vector2i.MAX)
			var fighting: bool = guard.state in [Crew3D.State.FIGHT, Crew3D.State.COVER]
			if not fighting or guard.cover.mode == CrewCover.Mode.OPEN:
				down_on.erase(guard)
			elif guard.cover.mode in [CrewCover.Mode.DOWN, CrewCover.Mode.AMBUSH]:
				down_on[guard] = guard.cover.tile
			elif guard.cover.mode == CrewCover.Mode.MOVE and held != Vector2i.MAX and guard.cover.tile != held \
					and not guard.flanking and not guard.cover.flank_end:
				moving.append("%s from %s to %s" % [guard.weapon.resource_path.get_file(), held, guard.cover.tile])
				if not was_moving.get(guard, false):
					moves += 1
				was_moving[guard] = true
				continue
			was_moving[guard] = false
		if moving.size() > 1 and two_moving.size() < 3:
			two_moving.append("t=%.1f s: %s" % [t, moving])
		for guard in guards:
			var w: Dictionary = watch[guard]
			if guard.cover.mode == CrewCover.Mode.DOWN:
				went_down[guard] = true
			if _flat(guard.global_position, w.anchor) > STUCK_MOVE:
				w.anchor = guard.global_position
				w.walking = 0.0
				w.still = 0.0
			elif guard.is_walking():
				w.walking += STEP
				w.still = 0.0
				if w.walking >= STUCK_TIME and stuck.size() < 3:
					stuck.append("a %s Guard in mode %s at %s (t=%.1f s)" % [guard.weapon.resource_path.get_file(),
							CrewCover.MODE_NAMES[guard.cover.mode], ShipBuilder3D.world_to_tile(guard.global_position), t])
					w.walking = -INF
			else:
				w.still += STEP
				if w.still >= 1.0:
					w.walking = 0.0
					w.anchor = guard.global_position
			var tile: Vector2i = guard.cover.tile
			if tile == Vector2i.MAX:
				continue
			if claimed.has(tile) and shared.size() < 3:
				shared.append("%s (t=%.1f s)" % [tile, t])
			claimed[tile] = true
			if breakers.has(tile) and by_breaker.size() < 3:
				by_breaker.append("%s (t=%.1f s)" % [tile, t])
	for guard in guards:
		guard.set_physics_process(false)
	_expect(went_down.size() >= 2, "%s: only %d of 3 Guards ever got down in cover" % [tag, went_down.size()])
	_expect(stuck.is_empty(), "%s: Guards stuck, trying to walk without moving %.1f m for %.0f s: %s" % [tag, STUCK_MOVE, STUCK_TIME, stuck])
	_expect(shared.is_empty(), "%s: two Guards claimed one tile: %s" % [tag, shared])
	_expect(by_breaker.is_empty(), "%s: a Guard claimed a tile beside a Breaker: %s" % [tag, by_breaker])
	print("  %s: %d moves between cover tiles" % [tag, moves])
	_expect(two_moving.is_empty(), "%s: two Guards between cover tiles at once (%d moves in all): %s" % [tag, moves, two_moving])
	for guard in guards:
		guard.free()
	for shot in shots.get_children():
		shot.free()


# --- a habit per gun (crew-combat ticket 20) -------------------------------------

## Seconds the band rigs run before each Guard's cover tile is judged.
const BAND_SECONDS := 20.0
## The band rigs: 14 x 10 tiles each, 16 apart from x 2000, a crate every
## third tile each way from (3, 2) in, the Pirate on the middle of the west
## wall. Each gun's Guard (GunRoll order) starts out of its band: Pistol
## 11.2 m, Assault Rifle 13.6 m, Shotgun 8.9 m, Marksman Rifle 7.3 m.
const BAND_X0 := 2000
const BAND_PIRATE := Vector2i(0, 5)
const BAND_STARTS: Array[Vector2i] = [Vector2i(11, 7), Vector2i(13, 1), Vector2i(8, 1), Vector2i(7, 7)]
## The 6 x 6 Room: the Pirate in one corner, a crate at (2104, 4), the
## Marksman Rifle starting in the far corner.
const SMALL_PIRATE := Vector2i(2100, 0)
const SMALL_START := Vector2i(2105, 5)
## The perch Room: 9 x 13 tiles at x 2300, the Pirate at (2304, 1), a crate
## at (2304, 10), the Marksman Rifle starting behind it at (2304, 12), 11 m
## off.
const PERCH_PIRATE := Vector2i(2304, 1)
const PERCH_START := Vector2i(2304, 12)
## The ambush rig: Room A 12 x 8 at x 2400, Room B 6 x 8 east of it, a
## two-wide Door at (2412, 0); the Pirate at (2401, 5), a crate at
## (2410, 2) and the Shotgun behind it at (2411, 2), 10.4 m off him.
## The fall-back Room: 7 x 17 tiles at x 2500, the Pirate at (2503, 0),
## crates at (2503, 12) and (2504, 14); the Marksman Rifle perches at
## (2503, 14), 14 m off, and he walks to (2503, 10), 4 m from it, from
## where the tile behind the second crate is a further perch 1.4 m away.
const FALL_BACK_PIRATE := Vector2i(2503, 0)
const FALL_BACK_START := Vector2i(2503, 14)
const FALL_BACK_CLOSE := Vector2i(2503, 10)
const AMBUSH_PIRATE := Vector2i(2401, 5)
const AMBUSH_START := Vector2i(2411, 2)
## The sight line: shown this long before a perched shot, within this.
const LINE_SECONDS := 0.9
const LINE_TOLERANCE := 0.1


func _build_habit_rigs() -> void:
	for i in 4:
		var x0 := BAND_X0 + i * 16
		var props: Array[Dictionary] = []
		for x in [3, 6, 9, 12]:
			for y in [2, 5, 8]:
				props.append({"type": &"crate", "tile": Vector2i(x0 + x, y)})
		band_layouts.append(_rig_room("BandShip%d" % i, Rect2i(x0, 0, 14, 10), props))
	small_layout = _rig_room("SmallShip", Rect2i(2100, 0, 6, 6), [{"type": &"crate", "tile": Vector2i(2104, 4)}])
	perch_layout = _rig_room("PerchShip", Rect2i(2300, 0, 9, 13), [{"type": &"crate", "tile": Vector2i(2304, 10)}])
	fall_back_layout = _rig_room("FallBackShip", Rect2i(2500, 0, 7, 17),
			[{"type": &"crate", "tile": Vector2i(2503, 12)}, {"type": &"crate", "tile": Vector2i(2504, 14)}])
	ambush_layout = ShipLayout.new()
	var a := RoomData.new()
	a.rects = [Rect2i(2400, 0, 12, 8)]
	a.props = [{"type": &"crate", "tile": Vector2i(2410, 2)}]
	var b := RoomData.new()
	b.rects = [Rect2i(2413, 0, 6, 8)]
	ambush_layout.rooms = [a, b]
	ambush_layout.doors = [_door(0, 1, Vector2i(2412, 0), false)]
	var ship := Node3D.new()
	ship.name = "AmbushShip"
	world.add_child(ship)
	ShipBuilder3D.build(ambush_layout, ship)
	ambush_door = ship.get_node("Doors").get_child(0)


## A Pirate of the check's own at [param at]: standing, physics off, too
## tough to fall.
func _own_pirate(at: Vector3) -> CharacterBody3D:
	var pirate: CharacterBody3D = load("res://scenes/player_3d.tscn").instantiate()
	pirate.auto_respawn = false
	pirate.position = at
	world.add_child(pirate)
	pirate.set_physics_process(false)
	pirate.state = pirate.State.WALK
	pirate.health.max_health = 100000
	pirate.health.reset()
	return pirate


## The shared Pirate held still at [param at] for a check, too tough to
## fall. Returns what to put back: [physics on, max Health].
func _hold_player(at: Vector3) -> Array:
	var was := [player.is_physics_processing(), player.health.max_health]
	player.set_physics_process(false)
	player.health.max_health = 100000
	player.health.reset()
	player.global_position = at
	player.state = player.State.WALK
	player.velocity = Vector3.ZERO
	return was


func _release_player(was: Array) -> void:
	player.velocity = Vector3.ZERO
	player.health.max_health = was[1]
	player.health.reset()
	player.set_physics_process(was[0])


## In a 14 x 10 m Room with crates throughout, each gun's Guard starting
## out of its band, after 20 s its cover tile is inside its band from the
## stationary Pirate, within 1 m: Shotgun 2 to 5 m, Pistol 4 to 8, Assault
## Rifle 5 to 10, Marksman Rifle 8 to 14. The four run side by side, each in
## its own Room with its own Pirate.
func _check_bands() -> void:
	var pirates: Array[CharacterBody3D] = []
	var guards: Array[Crew3D] = []
	for i in 4:
		var x0 := BAND_X0 + i * 16
		var him := ShipBuilder3D.tile_to_world(Vector2i(x0, 0) + BAND_PIRATE)
		var pirate := _own_pirate(him)
		pirates.append(pirate)
		var guard := _rig_guard(GunRoll.weapon(i), band_layouts[i], Vector2i(x0, 0) + BAND_STARTS[i], him)
		guard.target = pirate
		guards.append(guard)
	for i in 2:
		await physics_frame
	for i in 4:
		guards[i].hear_position(pirates[i].global_position)
		guards[i].set_physics_process(true)
	for frame in roundi(BAND_SECONDS / STEP):
		await physics_frame
	for i in 4:
		var guard := guards[i]
		guard.set_physics_process(false)
		var gunnery: Gunnery = guard.gunnery
		var tile: Vector2i = guard.cover.tile
		var far := _flat(ShipBuilder3D.tile_to_world(tile), pirates[i].global_position) if tile != Vector2i.MAX else -1.0
		_expect(tile != Vector2i.MAX and far >= gunnery.range_near - 1.0 and far <= gunnery.range_far + 1.0,
				"bands: after %.0f s a %s Guard's cover tile %s is %.1f m from the Pirate (mode %s), want %.0f to %.0f m within 1 m"
				% [BAND_SECONDS, Gunnery.NAMES[i], tile, far, CrewCover.MODE_NAMES[guard.cover.mode], gunnery.range_near, gunnery.range_far])
		guard.free()
	for pirate in pirates:
		pirate.free()
	_clear_shots()


## A Shotgun Guard fires no shot at a Pirate in its sight 10 m off in 10 s
## (it holds fire beyond 8 m), and does at 6 m. The empty test Room: no
## cover, no Door to wait beside.
func _check_shotgun_holds_fire() -> void:
	var was := _hold_player(CREW_AT + Vector3.FORWARD * 10.0)
	var guard := _armed(GunRoll.weapon(GunRoll.SHOTGUN))
	guard.face_direction(Vector3.FORWARD)
	for i in 2:
		await physics_frame
	var shots: Array = []
	var watch := _record_shots([guard], shots)
	guard.hear_position(player.global_position)
	guard.set_physics_process(true)
	var saw := 0
	for frame in roundi(10.0 / STEP):
		await physics_frame
		saw += int(guard._can_see)
	_expect(saw >= roundi(9.0 / STEP) and shots.is_empty(), "shotgun: with him in its sight %.1f s of 10 s at 10 m it fired %d shots, want none"
			% [saw * STEP, shots.size()])
	player.global_position = CREW_AT + Vector3.FORWARD * 6.0
	var fired := await _seconds_until(10.0, func() -> bool: return not shots.is_empty())
	_expect(fired >= 0.0, "shotgun: with him in its sight at 6 m it fired no shot in 10 s (mode %s)" % CrewCover.MODE_NAMES[guard.cover.mode])
	guard.set_physics_process(false)
	get_first_node_in_group(&"projectiles").child_entered_tree.disconnect(watch)
	guard.free()
	_clear_shots()
	_release_player(was)


## A Shotgun Guard behind a crate 10 m from him, with only open floor
## between it and its band, is within 10 s within 5 m of the doorway of his
## Room nearest to it and out of his sight, waiting in ambush, having
## crossed no more than 2.5 m of floor in his view.
func _check_shotgun_ambush() -> void:
	var him := ShipBuilder3D.tile_to_world(AMBUSH_PIRATE)
	var was := _hold_player(him)
	var guard := _rig_guard(GunRoll.weapon(GunRoll.SHOTGUN), ambush_layout, AMBUSH_START, him)
	var door := ShipBuilder3D.door_center_world(ambush_layout.doors[0])
	ambush_door.open()
	for i in 2:
		await physics_frame
	guard.hear_position(him)
	guard.set_physics_process(true)
	var trail: Array = [guard.global_position]
	var t := 0.0
	var waiting := false
	while t < 10.0 and not waiting:
		await physics_frame
		t += STEP
		trail.append(guard.global_position)
		waiting = guard.cover.mode == CrewCover.Mode.AMBUSH
	guard.set_physics_process(false)
	var near := _flat(guard.global_position, door)
	var hidden := guard._blocked(guard.global_position + Vector3.UP * Crew3D.EYE_HEIGHT, him + Vector3.UP * Crew3D.EYE_HEIGHT)
	_expect(waiting and near <= CrewHabit.AMBUSH_REACH and hidden,
			"ambush: after %.1f s the Shotgun Guard is %.1f m from the doorway (mode %s, out of his sight: %s), want within 10 s in ambush within 5 m and out of his sight"
			% [t, near, CrewCover.MODE_NAMES[guard.cover.mode], hidden])
	var unfair := _walk_unfair(guard, trail, him)
	_expect(unfair == "", "ambush: the Shotgun Guard's walk to its ambush: %s" % unfair)
	guard.free()
	ambush_door.close()
	_clear_shots()
	_release_player(was)


## The Shotgun racks (its Profile's action sound) between 0.2 and 1.0 s
## before each shot after it pops up over a crate (the ring) and after it
## steps out from behind a locker; it pumps after none.
func _check_shotgun_rack() -> void:
	var shotgun := GunRoll.weapon(GunRoll.SHOTGUN)
	for rig in [[ring_layout, RING_STARTS[0], ShipBuilder3D.tile_to_world(RING_CENTRE), "pops up over a crate"],
			[full_layout, FULL_START, ShipBuilder3D.tile_to_world(FULL_PIRATE), "steps out from a locker"]]:
		var was := _hold_player(rig[2])
		var guard := _rig_guard(shotgun, rig[0], rig[1], rig[2])
		for i in 2:
			await physics_frame
		var shots: Array = []
		var watch := _record_shots([guard], shots)
		var racks: Array[int] = []
		var listen := func(node: Node) -> void:
			var sound := node as AudioStreamPlayer3D
			if sound != null and sound.stream == shotgun.action_sound:
				racks.append(Engine.get_physics_frames())
		var parent := get_first_node_in_group(&"projectiles")
		parent.child_entered_tree.connect(listen)
		guard.hear_position(rig[2])
		guard.set_physics_process(true)
		var peeks := 0
		var last_mode: CrewCover.Mode = guard.cover.mode
		var t := 0.0
		while t < 40.0 and shots.size() < 5:
			await physics_frame
			t += STEP
			var mode: CrewCover.Mode = guard.cover.mode
			if mode != last_mode and last_mode == CrewCover.Mode.DOWN and mode in [CrewCover.Mode.SHOOT, CrewCover.Mode.OUT]:
				peeks += 1
			last_mode = mode
		guard.set_physics_process(false)
		parent.child_entered_tree.disconnect(watch)
		parent.child_entered_tree.disconnect(listen)
		var wrong: Array[String] = []
		for s: Dictionary in shots:
			var before := racks.filter(func(f: int) -> bool: return f < s.frame).map(func(f: int) -> float: return (s.frame - f) * STEP)
			var nearest: float = before.min() if not before.is_empty() else INF
			if nearest < 0.2 - 0.001 or nearest > 1.0 + 0.001:
				wrong.append("%.2f s" % nearest)
		_expect(shots.size() >= 5 and peeks >= 5 and wrong.is_empty(),
				"rack: a Shotgun Guard that %s fired %d shots after %d peeks; the rack before each was %s, want 0.2 to 1.0 s before every one"
				% [rig[3], shots.size(), peeks, wrong if not wrong.is_empty() else "in time"])
		_expect(racks.size() <= shots.size() + peeks, "rack: a Shotgun Guard that %s racked %d times for %d shots, want no pump after a shot"
				% [rig[3], racks.size(), shots.size()])
		guard.free()
		_clear_shots()
		_release_player(was)


## A perched Marksman Rifle Guard 11 m from him behind a crate: its sight
## line is visible from 0.9 s (within 0.1 s) before every shot until the
## shot; with him standing still its shot is aimed at him (his body centre,
## within 0.01 m); with him stepping 1.5 m aside in the last 0.15 s of the
## line its shot does not hit him; hit during its line it fires no shot
## from that line (it ducks).
func _check_sight_line() -> void:
	var him := ShipBuilder3D.tile_to_world(PERCH_PIRATE)
	var was := _hold_player(him)
	var guard := _rig_guard(GunRoll.weapon(GunRoll.MARKSMAN_RIFLE), perch_layout, PERCH_START, him)
	for i in 2:
		await physics_frame
	var shots: Array = []
	var watch := _record_shots([guard], shots)
	var hits := {}
	var count_hits := func(node: Node) -> void:
		var bolt := node as Projectile3D
		if bolt != null and bolt.shooter == guard:
			# This shot's index: _record_shots (connected first) has it already.
			var n := shots.size() - 1
			bolt.hit.connect(func(body: Node3D, _head: bool) -> void:
				if body == player:
					hits[n] = hits.get(n, 0) + 1)
	var parent := get_first_node_in_group(&"projectiles")
	parent.child_entered_tree.connect(count_hits)
	guard.hear_position(him)
	guard.set_physics_process(true)
	var shown: Array[bool] = []
	var start_frame := Engine.get_physics_frames()
	# Phase 0 still, 1 the sidestep, 2 hit during the line.
	var phase := 0
	var stepping := -1
	var hit_frame := -1
	var after_hit: Array = []
	var t := 0.0
	while t < 40.0:
		await physics_frame
		t += STEP
		shown.append(guard.cover.line_shown())
		if phase == 1 and shots.size() == 1:
			if stepping < 0 and guard.cover.line_left >= 0.0 and guard.cover.line_left <= 0.15:
				stepping = 0
			if stepping >= 0 and stepping < 9:
				player.global_position += Vector3.RIGHT * (1.5 / 9.0)
				stepping += 1
		if phase == 0 and shots.size() == 1:
			phase = 1
		elif phase == 1 and shots.size() == 2:
			phase = 2
		elif phase == 2 and Engine.get_physics_frames() - shots[1].frame == 30:
			# Back where he was once that shot's bolt is spent.
			player.global_position = him
		elif phase == 2 and hit_frame < 0 and guard.cover.line_left > 0.3 and guard.cover.line_left < 0.6:
			hit_frame = Engine.get_physics_frames()
			guard.take_damage(1, player)
			after_hit = [guard.cover.line_shown(), guard.cover.mode]
		elif phase == 2 and hit_frame >= 0 and Engine.get_physics_frames() - hit_frame >= roundi(1.5 / STEP):
			break
	guard.set_physics_process(false)
	parent.child_entered_tree.disconnect(watch)
	parent.child_entered_tree.disconnect(count_hits)
	_expect(shots.size() >= 2, "sight line: the perched Marksman Rifle fired %d shots in 40 s, want 2 before the hit" % shots.size())
	# Shown from 0.9 s before each shot, without a break, until it.
	var wrong: Array[String] = []
	for s: Dictionary in shots.slice(0, 2):
		var at: int = s.frame - start_frame - 1
		var first := at
		while first > 0 and shown[first - 1]:
			first -= 1
		var lead: float = (s.frame - start_frame - first) * STEP
		if not s.perched or not s.line or absf(lead - LINE_SECONDS) > LINE_TOLERANCE:
			wrong.append("shown %.2f s before (perched %s, at the shot %s)" % [lead, s.perched, s.line])
	_expect(wrong.is_empty(), "sight line: before each perched shot the line was %s, want shown from 0.9 s before within 0.1 s" % [wrong])
	if shots.size() >= 2:
		var still: Dictionary = shots[0]
		_expect(still.aimed and still.point.distance_to(still.centre) <= 0.01,
				"sight line: with him standing still the shot was aimed %.3f m from his body centre (true: %s), want at him"
				% [still.point.distance_to(still.centre), still.aimed])
		_expect(stepping == 9 and hits.get(1, 0) == 0, "sight line: with him stepping 1.5 m aside in the last 0.15 s (%d of 9 steps), %d pellets of the shot hit him, want none"
				% [stepping, hits.get(1, 0)])
	var from_line := shots.filter(func(s: Dictionary) -> bool: return s.frame >= hit_frame).size() if hit_frame >= 0 else -1
	_expect(hit_frame >= 0 and from_line == 0 and not after_hit[0] and after_hit[1] == CrewCover.Mode.DOWN,
			"sight line: hit during its line (at frame %d) the Marksman Rifle fired %d shots in 1.5 s (line still shown: %s, mode %s), want none and down"
			% [hit_frame, from_line, after_hit[0] if hit_frame >= 0 else "-", CrewCover.MODE_NAMES[after_hit[1]] if hit_frame >= 0 else "-"])
	guard.free()
	_clear_shots()
	_release_player(was)


## A perched Marksman Rifle Guard fires nothing while both true-aim places
## are held by two other Guards in sight of him, and fires within 2 s of one
## freeing (that Guard leaving the fight).
func _check_marksman_waits_for_place() -> void:
	var him := ShipBuilder3D.tile_to_world(PERCH_PIRATE)
	var was := _hold_player(him)
	var guard := _rig_guard(GunRoll.weapon(GunRoll.MARKSMAN_RIFLE), perch_layout, PERCH_START, him)
	# Two Pistol Guards stood in the open in his sight, fighting, holding
	# their places for good (a handover time they never reach).
	var sticky: Sandbox = (load(Sandbox.PATH) as Sandbox).duplicate()
	sticky.true_aim_handover = 1000.0
	var others: Array[Crew3D] = []
	for tile in [Vector2i(2302, 6), Vector2i(2306, 6)]:
		var other := _rig_guard(GunRoll.weapon(GunRoll.PISTOL), perch_layout, tile, him)
		other.sandbox = sticky
		other._last_seen = him
		other.state = Crew3D.State.FIGHT
		others.append(other)
	for i in 2:
		await physics_frame
	var fire := CrewFire.of(player)
	fire.update()
	var shots: Array = []
	var watch := _record_shots([guard], shots)
	guard.hear_position(him)
	guard.set_physics_process(true)
	# Until it has waited down a second for a place, then four more.
	var both_held := 0
	var broken := 0
	var waited_for := 0.0
	var t := 0.0
	while t < 20.0 and waited_for < 4.0:
		await physics_frame
		t += STEP
		fire.update()
		var theirs := fire.holders.filter(func(g: Crew3D) -> bool: return g in others).size()
		if theirs == 2:
			both_held += 1
		else:
			broken += 1
		if guard.cover.waited > 1.0:
			waited_for += STEP
	_expect(both_held > 0 and broken == 0 and shots.is_empty() and waited_for >= 4.0,
			"true-aim place: with both places held by others (%d frames, %d not) the Marksman Rifle fired %d shots and waited %.1f s, want none fired while it waits"
			% [both_held, broken, shots.size(), waited_for])
	# One leaves the fight: its place frees.
	others[0].state = Crew3D.State.PATROL
	var fired := await _seconds_until(4.0, func() -> bool: return not shots.is_empty())
	_expect(fired >= 0.0 and fired <= 2.0, "true-aim place: the Marksman Rifle fired %.2f s after a place freed, want within 2 s" % fired)
	guard.set_physics_process(false)
	get_first_node_in_group(&"projectiles").child_entered_tree.disconnect(watch)
	guard.free()
	for other in others:
		other.free()
	_clear_shots()
	_release_player(was)


## In the 6 x 6 Room a Marksman Rifle Guard takes a cover spot and fires
## within 6 s; it does not change tile in 20 s with him hidden; with him
## walked to 4 m and no fair walk to a further perch, its next shot has no
## sight line and twice its aim (its base cone, the gun's own plus its aim
## error).
func _check_marksman_small_room() -> void:
	var him := ShipBuilder3D.tile_to_world(SMALL_PIRATE)
	var was := _hold_player(him)
	var guard := _rig_guard(GunRoll.weapon(GunRoll.MARKSMAN_RIFLE), small_layout, SMALL_START, him)
	var perched_cone := guard.base_cone_degrees()
	for i in 2:
		await physics_frame
	var shots: Array = []
	var watch := _record_shots([guard], shots)
	guard.hear_position(him)
	guard.set_physics_process(true)
	var fired := await _seconds_until(6.0, func() -> bool: return not shots.is_empty())
	_expect(fired >= 0.0 and shots[0].perched, "small room: the Marksman Rifle fired after %.2f s (on a cover spot: %s, tile %s), want from cover within 6 s"
			% [fired, shots[0].perched if not shots.is_empty() else false, guard.cover.tile])
	await _seconds_until(6.0, func() -> bool: return guard.cover.mode == CrewCover.Mode.DOWN)
	# Hidden: out of its sight and out of the Room.
	var held: Vector2i = guard.cover.tile
	player.global_position = him + Vector3(0.0, 0.0, -40.0)
	var moved := 0
	for frame in roundi(20.0 / STEP):
		await physics_frame
		if guard.cover.tile != held or not guard.state in [Crew3D.State.FIGHT, Crew3D.State.COVER]:
			moved += 1
	_expect(held != Vector2i.MAX and moved == 0, "perch: with him hidden for 20 s the Marksman Rifle left its tile %s on %d frames (now %s, state %d), want it held"
			% [held, moved, guard.cover.tile, guard.state])
	# Walked to 4 m where it can see him, with no further perch.
	var astar := CrewPaths.grid(small_layout)
	var eye := guard.global_position + Vector3.UP * Crew3D.EYE_HEIGHT
	var close := Vector3.INF
	for tile: Vector2i in small_layout.rooms[0].tiles():
		var at := ShipBuilder3D.tile_to_world(tile)
		var far := _flat(at, guard.global_position)
		if _open_tile(astar, tile) and far >= 3.6 and far <= 4.4 and not guard._blocked(eye, at + Vector3.UP * Crew3D.EYE_HEIGHT) \
				and not _has_cover_from(guard, at, -1):
			close = at
			break
	_expect(close != Vector3.INF, "perch: the small Room has no tile 4 m from the Marksman Rifle in its sight")
	if close != Vector3.INF:
		await _walk_player(him, close)
		var from := shots.size()
		var lined := false
		var t := 0.0
		while t < 10.0 and shots.size() == from:
			await physics_frame
			t += STEP
			lined = lined or guard.cover.line_shown()
		var hip: Dictionary = shots[from] if shots.size() > from else {}
		_expect(not hip.is_empty() and not lined and not hip.line and is_equal_approx(hip.base, perched_cone * 2.0),
				"perch: with him at 4 m and nowhere further, its next shot (after %.1f s) showed a sight line: %s, with a base cone of %.1f degrees, want none and %.1f (twice %.1f)"
				% [t, lined or (hip.line if not hip.is_empty() else false), hip.base if not hip.is_empty() else -1.0, perched_cone * 2.0, perched_cone])
	guard.set_physics_process(false)
	get_first_node_in_group(&"projectiles").child_entered_tree.disconnect(watch)
	guard.free()
	_clear_shots()
	_release_player(was)


## The shared Pirate walked from [param from] to [param to] at 4 m/s, a
## step a frame.
func _walk_player(from: Vector3, to: Vector3) -> void:
	var steps := maxi(ceili(_flat(from, to) / (4.0 * STEP)), 1)
	for i in steps:
		player.global_position = from.lerp(to, float(i + 1) / steps)
		await physics_frame


## In the fall-back Room, a perched Marksman Rifle Guard with him walked to
## 4 m and a fair walk to a further perch has moved there (on a tile at
## least a metre further from him than the one it held) within 5 s.
func _check_marksman_falls_back() -> void:
	var him := ShipBuilder3D.tile_to_world(FALL_BACK_PIRATE)
	var was := _hold_player(him)
	var guard := _rig_guard(GunRoll.weapon(GunRoll.MARKSMAN_RIFLE), fall_back_layout, FALL_BACK_START, him)
	for i in 2:
		await physics_frame
	guard.hear_position(him)
	guard.set_physics_process(true)
	await _seconds_until(8.0, func() -> bool: return guard.cover.mode == CrewCover.Mode.DOWN)
	var old: Vector2i = guard.cover.tile
	var close := ShipBuilder3D.tile_to_world(FALL_BACK_CLOSE)
	var old_far := _flat(ShipBuilder3D.tile_to_world(old), close)
	var eye := guard.global_position + Vector3.UP * Crew3D.EYE_HEIGHT
	var ready := old != Vector2i.MAX and absf(old_far - 4.0) <= 0.5 and not guard._blocked(eye, close + Vector3.UP * Crew3D.EYE_HEIGHT) \
			and _has_cover_from(guard, close, -1)
	_expect(ready, "fall back: the Marksman Rifle perched at %s, %.1f m from where he walks to, with a further perch from there: %s; want 4 m and one"
			% [old, old_far, _has_cover_from(guard, close, -1)])
	if ready:
		await _walk_player(him, close)
		var there := await _seconds_until(5.0, func() -> bool:
			var now: Vector2i = guard.cover.tile
			return now != old and now != Vector2i.MAX and _flat(ShipBuilder3D.tile_to_world(now), close) >= old_far + 1.0 \
					and _flat(guard.global_position, ShipBuilder3D.tile_to_world(now)) <= 0.5)
		_expect(there >= 0.0, "fall back: with him walked to 4 m the Marksman Rifle was not on a perch a metre further than %s within 5 s (now %s, mode %s, hip %s)"
				% [old, guard.cover.tile, CrewCover.MODE_NAMES[guard.cover.mode], guard.cover.hip])
	guard.set_physics_process(false)
	guard.free()
	_clear_shots()
	_release_player(was)


# --- Guards work together (crew-combat ticket 21) ----------------------------------

## The flank rig (_flank_rig), x offset from x0: Room A (his) 8 x 8 at
## x0 + 9, Room B (the Guards') 8 x 8 west of it at x0, Room C 17 x 8 north
## of both; Doors A-B at (x0 + 8, 4), A-C at (x0 + 13, -1), B-C at
## (x0 + 3, -1). A bar of two crates inside A's north Door at (x0 + 13, 2)
## and (x0 + 14, 2), and a crate at (x0 + 11, 5) for the pinning Guards. The
## Pirate at (x0 + 14, 6); the Guards start in B.
const FLANK_X0 := 3000
const FLANK_PIRATE := Vector2i(14, 6)
const FLANK_STARTS: Array[Vector2i] = [Vector2i(3, 2), Vector2i(3, 4), Vector2i(3, 6)]
## Seconds the flank rig runs, and the 20 seeded fights each run.
const FLANK_SECONDS := 20.0
const FLANK_FIGHTS := 20
const FLANK_FIGHTS_X0 := 5000
const FLANK_FIGHT_SECONDS := 8.0
## Covering fire: the two-Guard fight's length, how often he moves, and the
## criterion's numbers: a partner's shot within 1 s, or a 3 s wait, each
## within 0.2 s.
const COVERING_SECONDS := 60.0
const COVERING_MOVE := 6.0
const COVERING_SHOT := 1.0
const COVERING_WAIT := 3.0
const COVERING_SLACK := 0.2
## Suppression: the window, its time on the Sandbox, the margin after it,
## and how near a crate's edge a shot at it is aimed.
const SUPPRESS_SECONDS := 4.0
const SUPPRESS_AFTER := 4.5
const SUPPRESS_WATCH := 6.0
const SUPPRESS_EDGE := 0.8
## The radio rig: Room P (his) 6 x 6 at x0, Room J 30 x 4 along its north
## side from x0 - 6, Room F 8 x 8 north of J at x0 + 8; Doors P-J at
## (x0 + 3, -1), J-F at (x0 + 12, -6). The Pirate at (x0 + 3, 4), the Guard
## starting in F at (x0 + 12, -12), 18.4 m off and two Rooms away; from J
## only the cone through P's Door sees him. For the takeover itself, a
## hunting Guard 20.4 m off in J (joined to his Room) and one 21.2 m off in
## F (not joined).
const RADIO_X0 := 3200
const RADIO_PIRATE := Vector2i(3, 4)
const RADIO_START := Vector2i(12, -12)
const RADIO_JOINED := Vector2i(22, -3)
const RADIO_FAR := Vector2i(15, -13)
const RADIO_NEAR := 10.0
const RADIO_SECONDS := 40.0
## The last Guard: seconds until its spot is judged, then how long it is
## watched not to come nearer.
const LAST_AFTER := 10.0
const LAST_HOLD := 20.0


## Builds a flank rig at [param x0]: {layout, ship, doors (Door3D nodes)}.
func _flank_rig(x0: int, ship_name: String) -> Dictionary:
	var rig := ShipLayout.new()
	var a := RoomData.new()
	a.rects = [Rect2i(x0 + 9, 0, 8, 8)]
	a.props = [{"type": &"crate", "tile": Vector2i(x0 + 13, 2)}, {"type": &"crate", "tile": Vector2i(x0 + 14, 2)},
			{"type": &"crate", "tile": Vector2i(x0 + 11, 5)}]
	var b := RoomData.new()
	b.rects = [Rect2i(x0, 0, 8, 8)]
	var c := RoomData.new()
	c.rects = [Rect2i(x0, -9, 17, 8)]
	rig.rooms = [a, b, c]
	rig.doors = [_door(0, 1, Vector2i(x0 + 8, 4), false), _door(0, 2, Vector2i(x0 + 13, -1), true),
			_door(1, 2, Vector2i(x0 + 3, -1), true)]
	var ship := Node3D.new()
	ship.name = ship_name
	world.add_child(ship)
	ShipBuilder3D.build(rig, ship)
	return {"layout": rig, "ship": ship, "doors": ship.get_node("Doors").get_children()}


## Shuts every Door of a rig the Guards opened: noise carries through any
## open Door joining Rooms of the same indices, whatever the rig.
func _shut_all(doors: Array) -> void:
	for door in doors:
		if door is Door3D:
			door.close()


## In the flank rig, a Shotgun, a Pistol and an Assault Rifle Guard outside
## his Room (B), told where he is: the one that flanks is the Shotgun, and it
## ends (first down after its flank) within 0.5 m of a tile hidden from him
## (the 0.9 m ray to his torso blocked) inside A's second (north) Door: in his
## Room, within CrewCover.FLANK_SPOT_REACH of that Door, nearer it than the
## first.
func _check_flank_by_gun() -> void:
	var rig := _flank_rig(FLANK_X0, "FlankShip")
	var flank_layout: ShipLayout = rig.layout
	var him := ShipBuilder3D.tile_to_world(Vector2i(FLANK_X0, 0) + FLANK_PIRATE)
	var pirate := _own_pirate(him)
	var guards: Array[Crew3D] = []
	for i in 3:
		var gun: int = [GunRoll.SHOTGUN, GunRoll.PISTOL, GunRoll.ASSAULT_RIFLE][i]
		var guard := _rig_guard(GunRoll.weapon(gun), flank_layout, Vector2i(FLANK_X0, 0) + FLANK_STARTS[i], him)
		guard.target = pirate
		guards.append(guard)
	for i in 2:
		await physics_frame
	for guard in guards:
		guard.hear_position(him)
		guard.set_physics_process(true)
	var second := ShipBuilder3D.door_center_world(flank_layout.doors[1])
	var first := ShipBuilder3D.door_center_world(flank_layout.doors[0])
	var flankers: Array[Crew3D] = []
	var ended := {}
	var was_flanking := {}
	var t := 0.0
	while t < FLANK_SECONDS and ended.is_empty():
		await physics_frame
		t += STEP
		for guard in guards:
			if guard.flanking and not guard in flankers:
				flankers.append(guard)
			if guard.flanking or guard.cover.flank_end:
				was_flanking[guard] = true
			elif was_flanking.has(guard) and guard.cover.mode == CrewCover.Mode.DOWN:
				ended[guard] = guard.cover.tile
	for guard in guards:
		guard.set_physics_process(false)
	var shotgun := guards[0]
	print("  flank by gun: flankers %s, the Shotgun down on %s after %.1f s" % [flankers.map(func(g: Crew3D) -> String: return g.weapon.resource_path.get_file()),
			ended.get(shotgun, "-"), t])
	_expect(not flankers.is_empty() and flankers[0] == shotgun,
			"flank by gun: the first flanker was %s, want the Shotgun Guard (of Shotgun, Pistol, Assault Rifle)"
			% ("none" if flankers.is_empty() else flankers[0].weapon.resource_path.get_file()))
	var tile: Vector2i = ended.get(shotgun, Vector2i.MAX)
	var at := ShipBuilder3D.tile_to_world(tile) if tile != Vector2i.MAX else Vector3.INF
	var ok := tile != Vector2i.MAX and _flat(shotgun.global_position, at) <= 0.5 and _hidden_tile(shotgun, tile, him) \
			and flank_layout.room_at(tile) == 0 and _flat(at, second) <= CrewCover.FLANK_SPOT_REACH and _flat(at, second) < _flat(at, first)
	_expect(ok, "flank by gun: after %.1f s the Shotgun flanker ended on %s (%.2f m from it, hidden %s, Room %d, %.1f m from the second Door), want within 0.5 m of a tile hidden from him inside the second Door"
			% [t, tile, _flat(shotgun.global_position, at) if at != Vector3.INF else -1.0,
			_hidden_tile(shotgun, tile, him) if tile != Vector2i.MAX else false,
			flank_layout.room_at(tile) if tile != Vector2i.MAX else -1, _flat(at, second) if at != Vector3.INF else -1.0])
	for guard in guards:
		guard.free()
	pirate.free()
	_shut_all(rig.doors)
	_clear_shots()


## Twenty seeded fights side by side in flank rigs, each with a Marksman
## Rifle Guard and two more of rolled guns (fight i seeded i + 1): no Marksman
## Rifle Guard ever flanks, and in every fight with another gun some Guard
## does.
func _check_marksman_never_flanks() -> void:
	var rigs: Array[Dictionary] = []
	var pirates: Array[CharacterBody3D] = []
	var fights: Array = []
	for i in FLANK_FIGHTS:
		var x0 := FLANK_FIGHTS_X0 + i * 30
		var rig := _flank_rig(x0, "FlankFight%d" % i)
		rigs.append(rig)
		var him := ShipBuilder3D.tile_to_world(Vector2i(x0, 0) + FLANK_PIRATE)
		var pirate := _own_pirate(him)
		pirates.append(pirate)
		var roll := RandomNumberGenerator.new()
		roll.seed = i + 1
		var guns := [GunRoll.MARKSMAN_RIFLE, roll.randi_range(0, 3), roll.randi_range(0, 3)]
		var order := [0, 1, 2]
		order.shuffle()
		var guards: Array[Crew3D] = []
		for k in 3:
			var guard := _rig_guard(GunRoll.weapon(guns[k]), rig.layout, Vector2i(x0, 0) + FLANK_STARTS[order[k]], him)
			guard.target = pirate
			guards.append(guard)
		fights.append({"guards": guards, "him": him, "flankers": {}})
	for i in 2:
		await physics_frame
	for fight: Dictionary in fights:
		for guard: Crew3D in fight.guards:
			guard.hear_position(fight.him)
			guard.set_physics_process(true)
	for frame in roundi(FLANK_FIGHT_SECONDS / STEP):
		await physics_frame
		for fight: Dictionary in fights:
			for guard: Crew3D in fight.guards:
				if guard.flanking:
					fight.flankers[guard] = true
	var marksman: Array[String] = []
	var none: Array[int] = []
	for i in fights.size():
		var fight: Dictionary = fights[i]
		var other_gun := false
		for guard: Crew3D in fight.guards:
			guard.set_physics_process(false)
			var gun := CrewHabit.gun_of(guard.weapon)
			if gun != CrewHabit.Gun.MARKSMAN_RIFLE:
				other_gun = true
			elif fight.flankers.has(guard):
				marksman.append("fight %d" % i)
		if other_gun and fight.flankers.is_empty():
			none.append(i)
	print("  flank: %d of %d seeded fights had a flank, %d Marksman Rifle Guards among %d" % [fights.filter(func(f: Dictionary) -> bool: return not f.flankers.is_empty()).size(),
			FLANK_FIGHTS, fights.reduce(func(n: int, f: Dictionary) -> int: return n + f.guards.filter(func(g: Crew3D) -> bool: return CrewHabit.gun_of(g.weapon) == CrewHabit.Gun.MARKSMAN_RIFLE).size(), 0), FLANK_FIGHTS * 3])
	_expect(marksman.is_empty(), "flank: a Marksman Rifle Guard flanked in %s of %d seeded fights, want never" % [marksman, FLANK_FIGHTS])
	_expect(none.is_empty(), "flank: no Guard flanked in fights %s, each with a gun that may flank" % [none])
	for fight: Dictionary in fights:
		for guard: Crew3D in fight.guards:
			guard.free()
	for pirate in pirates:
		pirate.free()
	for rig in rigs:
		_shut_all(rig.doors)
		rig.ship.free()
	_clear_shots()


## The Pirate moved to a fresh open tile of [param rig] at least 3 m from
## every Guard in [param guards].
func _move_clear(pirate: Node3D, rig: ShipLayout, guards: Array) -> void:
	var astar := CrewPaths.grid(rig)
	var tiles: Array = rig.rooms[0].tiles().keys()
	for _try in 40:
		var tile: Vector2i = tiles[randi_range(0, tiles.size() - 1)]
		var at := ShipBuilder3D.tile_to_world(tile)
		if _open_tile(astar, tile) and CrewPaths.clear(astar, at, at) \
				and guards.all(func(g: Crew3D) -> bool: return not is_instance_valid(g) or _flat(g.global_position, at) >= 3.0):
			pirate.global_position = at
			return


## Covering fire: a Pistol and an Assault Rifle Guard fight him for 60 s in
## a 14 x 10 m Room with crates throughout, him moved to a fresh tile every
## 6 s. Whenever one leaves a cover tile it got down on for another, the
## other fired within the previous 1 s, or the mover had waited 3 s, each
## within 0.2 s. At least three such moves happen.
func _check_covering_fire() -> void:
	var rig: ShipLayout = band_layouts[0]
	var him := ShipBuilder3D.tile_to_world(Vector2i(BAND_X0, 0) + BAND_PIRATE)
	var pirate := _own_pirate(him)
	var guards: Array[Crew3D] = []
	for i in 2:
		var guard := _rig_guard(GunRoll.weapon(i), rig, Vector2i(BAND_X0, 0) + BAND_STARTS[i], him)
		guard.target = pirate
		guards.append(guard)
	for i in 2:
		await physics_frame
	var shots: Array = []
	var watch := _record_shots(guards, shots)
	var last_shot := {guards[0]: -1000000, guards[1]: -1000000}
	var rec := {}
	for guard in guards:
		rec[guard] = {"down": Vector2i.MAX, "tile": Vector2i.MAX, "wait": -1.0}
		guard.hear_position(him)
		guard.set_physics_process(true)
	var leaves: Array[String] = []
	var wrong: Array[String] = []
	var covered := 0
	var t := 0.0
	var frames := roundi(COVERING_SECONDS / STEP)
	for frame in frames:
		await physics_frame
		t += STEP
		var now := Engine.get_physics_frames()
		for s: Dictionary in shots:
			last_shot[s.guard] = maxi(last_shot[s.guard], s.frame)
		shots.clear()
		if frame > 0 and frame % roundi(COVERING_MOVE / STEP) == 0:
			_move_clear(pirate, rig, guards)
		for i in 2:
			var guard := guards[i]
			var other := guards[1 - i]
			var r: Dictionary = rec[guard]
			var tile: Vector2i = guard.cover.tile
			if not guard.state in [Crew3D.State.FIGHT, Crew3D.State.COVER] or guard.cover.mode == CrewCover.Mode.OPEN:
				r.down = Vector2i.MAX
			elif r.tile == r.down and r.down != Vector2i.MAX and tile != r.tile and tile != Vector2i.MAX:
				# Left the spot it held for another, this frame.
				var since: float = (now - last_shot[other]) * STEP
				var waited: float = r.wait + STEP
				var what := "t=%.2f s %s left %s for %s: partner fired %.2f s before, waited %.2f s" % [t,
						Gunnery.NAMES[i], r.down, tile, since, waited]
				leaves.append(what)
				if since <= COVERING_SHOT + COVERING_SLACK:
					covered += 1
				elif waited < COVERING_WAIT - COVERING_SLACK:
					wrong.append(what)
			if guard.cover.mode in [CrewCover.Mode.DOWN, CrewCover.Mode.AMBUSH]:
				r.down = tile
			r.tile = tile
			r.wait = guard.cover.move_wait()
	for guard in guards:
		guard.set_physics_process(false)
	get_first_node_in_group(&"projectiles").child_entered_tree.disconnect(watch)
	print("  covering fire: %d moves between cover tiles, %d under a partner's fire, the rest after a %.0f s wait" % [leaves.size(), covered, COVERING_WAIT])
	_expect(leaves.size() >= 3, "covering fire: only %d moves between cover tiles in %.0f s, want at least 3" % [leaves.size(), COVERING_SECONDS])
	_expect(wrong.is_empty(), "covering fire: of %d moves (%d under fire), %d had neither a partner's shot within %.1f s nor a %.0f s wait: %s"
			% [leaves.size(), covered, wrong.size(), COVERING_SHOT, COVERING_WAIT, wrong.slice(0, 3)])
	for guard in guards:
		guard.free()
	pirate.free()
	_clear_shots()


## Suppression: a Pistol and an Assault Rifle Guard fight him in the open
## of the suppression rig; he steps behind its crate (out of both their
## shots). Of their shots in the next 4 s at least one is aimed within 0.8 m
## of one of the crate's edges (its four upright corners) and none is aimed
## true, and none is fired at the crate after 4.5 s. The suppression time is
## the Sandbox's 4 s.
func _check_suppression() -> void:
	var numbers: Sandbox = ResourceLoader.load(Sandbox.PATH, "", ResourceLoader.CACHE_MODE_IGNORE)
	_expect(is_equal_approx(numbers.suppression_time, SUPPRESS_SECONDS),
			"suppression: the Sandbox's suppression time is %s s, want %.0f s" % [numbers.suppression_time, SUPPRESS_SECONDS])
	var x0 := 3100
	var crate := Vector2i(x0 + 4, 7)
	var rig := _rig_room("SuppressShip", Rect2i(x0, 0, 10, 18), [{"type": &"crate", "tile": crate}])
	var beside := ShipBuilder3D.tile_to_world(Vector2i(x0 + 7, 6))
	var behind := ShipBuilder3D.tile_to_world(Vector2i(x0 + 4, 6))
	var pirate := _own_pirate(beside)
	var guards: Array[Crew3D] = []
	for i in 2:
		var guard := _rig_guard(GunRoll.weapon(i), rig, Vector2i(x0 + 3 + 2 * i, 16), beside)
		guard.target = pirate
		guards.append(guard)
	for i in 2:
		await physics_frame
	for guard in guards:
		guard.hear_position(beside)
		guard.set_physics_process(true)
	# Fighting him in the open, both with a shot at him.
	var ready := await _seconds_until(6.0, func() -> bool:
		return guards.all(func(g: Crew3D) -> bool: return g._can_see and not g._muzzle_blocked() and g.shot_age() < 1.0))
	_expect(ready >= 0.0, "suppression: the two Guards were not both firing at him in the open within 6 s (modes %s, %s)"
			% [CrewCover.MODE_NAMES[guards[0].cover.mode], CrewCover.MODE_NAMES[guards[1].cover.mode]])
	var shots: Array = []
	var watch := _record_shots(guards, shots)
	pirate.global_position = behind
	var blocked := guards.all(func(g: Crew3D) -> bool: return g._muzzle_blocked())
	var start := Engine.get_physics_frames()
	for frame in roundi(SUPPRESS_WATCH / STEP):
		await physics_frame
	for guard in guards:
		guard.set_physics_process(false)
	get_first_node_in_group(&"projectiles").child_entered_tree.disconnect(watch)
	var corners: Array[Vector3] = []
	var c := ShipBuilder3D.tile_to_world(crate)
	for dx in [-0.5, 0.5]:
		for dz in [-0.5, 0.5]:
			corners.append(c + Vector3(dx, 0.0, dz))
	var near_edge := 0
	var true_shots := 0
	var late := 0
	var in_window := 0
	for s: Dictionary in shots:
		var at: float = (s.frame - start) * STEP
		var point: Vector3 = s.point
		# From the aim point to the nearest upright edge of the crate (a
		# corner of its tile, from the floor to its 1.1 m top).
		var edge := INF
		var rise := maxf(point.y - 1.1, 0.0) + maxf(-point.y, 0.0)
		for corner in corners:
			edge = minf(edge, Vector3(point.x - corner.x, rise, point.z - corner.z).length())
		if at <= SUPPRESS_SECONDS:
			in_window += 1
			if s.aimed:
				true_shots += 1
			if s.kind == "prop" and edge <= SUPPRESS_EDGE:
				near_edge += 1
		elif at > SUPPRESS_AFTER and s.kind == "prop":
			late += 1
	print("  suppression: %d shots in %.0f s, %d at the crate's edge, %d true; %d at the crate after %.1f s" % [in_window, SUPPRESS_SECONDS, near_edge, true_shots, late, SUPPRESS_AFTER])
	_expect(blocked, "suppression: behind the crate he is not out of both Guards' shots")
	_expect(near_edge >= 1 and true_shots == 0, "suppression: of %d shots in %.0f s after he hid behind the crate, %d were aimed within %.1f m of its edge and %d true, want at least 1 and none"
			% [in_window, SUPPRESS_SECONDS, near_edge, SUPPRESS_EDGE, true_shots])
	_expect(late == 0, "suppression: %d shots were fired at the crate after %.1f s, want none" % [late, SUPPRESS_AFTER])
	for guard in guards:
		guard.free()
	pirate.free()
	_clear_shots()


## A Guard radioed from two Rooms away (the radio rig, 25 m off): when it
## first comes within 10 m of him it is in the cover fight (COVER or FIGHT)
## and the tile it stands on is hidden from him (the 0.9 m ray from that
## tile's centre to his torso blocked).
func _check_radioed_in() -> void:
	var x0 := RADIO_X0
	var rig := ShipLayout.new()
	var p := RoomData.new()
	p.rects = [Rect2i(x0, 0, 6, 6)]
	var j := RoomData.new()
	j.rects = [Rect2i(x0 - 6, -5, 30, 4)]
	var f := RoomData.new()
	f.rects = [Rect2i(x0 + 8, -14, 8, 8)]
	rig.rooms = [p, j, f]
	rig.doors = [_door(0, 1, Vector2i(x0 + 3, -1), true), _door(1, 2, Vector2i(x0 + 12, -6), true)]
	var ship := Node3D.new()
	ship.name = "RadioShip"
	world.add_child(ship)
	ShipBuilder3D.build(rig, ship)
	var doors := ship.get_node("Doors").get_children()
	for door in doors:
		door.open()
	var him := ShipBuilder3D.tile_to_world(Vector2i(x0, 0) + RADIO_PIRATE)
	var pirate := _own_pirate(him)
	# The takeover: radioed, it runs while further than 18 m, unless it is in
	# a Room joined to his.
	var takes: Array[bool] = []
	for tile in [RADIO_JOINED, RADIO_FAR]:
		var hunter := _rig_guard(GunRoll.weapon(GunRoll.PISTOL), rig, Vector2i(x0, 0) + tile, him)
		hunter.target = pirate
		hunter.hear_position(him)
		hunter._tick_hunt()
		takes.append(hunter.state == Crew3D.State.COVER)
		hunter.free()
	_expect(takes == [true, false], "radioed in: a hunting Guard 20.4 m off in a Room joined to his took to cover: %s, one 21.2 m off two Rooms away: %s; want yes and no"
			% [takes[0], takes[1]])
	var guard := _rig_guard(GunRoll.weapon(GunRoll.PISTOL), rig, Vector2i(x0, 0) + RADIO_START, him)
	guard.target = pirate
	for i in 2:
		await physics_frame
	guard.hear_position(him)
	guard.set_physics_process(true)
	var t := 0.0
	var reached := false
	while t < RADIO_SECONDS and not reached:
		await physics_frame
		t += STEP
		reached = _flat(guard.global_position, him) <= RADIO_NEAR
	guard.set_physics_process(false)
	var tile := ShipBuilder3D.world_to_tile(guard.global_position)
	var fighting := guard.state in [Crew3D.State.FIGHT, Crew3D.State.COVER]
	var hidden := _hidden_tile(guard, tile, him)
	print("  radioed in: within %.0f m after %.1f s, mode %s on %s" % [RADIO_NEAR, t, CrewCover.MODE_NAMES[guard.cover.mode], tile])
	_expect(reached and fighting and hidden,
			"radioed in: the Guard came within %.0f m of him after %.1f s (reached %s) in state %d (mode %s) on tile %s, hidden from him: %s; want in the cover fight on a hidden tile"
			% [RADIO_NEAR, t, reached, guard.state, CrewCover.MODE_NAMES[guard.cover.mode], tile, hidden])
	guard.free()
	pirate.free()
	_shut_all(doors)
	ship.free()
	_clear_shots()


## The last Guard: two Pistol Guards fight him (standing still, in their
## sight) in a 14 x 10 m Room with crates; once both are down in cover one
## falls. Ten seconds later the other's cover tile is further from him than
## the one it held, and over the next 20 s no tile it holds is nearer him
## than that.
func _check_last_guard() -> void:
	var rig: ShipLayout = band_layouts[1]
	var x0 := BAND_X0 + 16
	var him := ShipBuilder3D.tile_to_world(Vector2i(x0, 0) + BAND_PIRATE)
	var pirate := _own_pirate(him)
	var guards: Array[Crew3D] = []
	for start in [Vector2i(11, 2), Vector2i(11, 7)]:
		var guard := _rig_guard(GunRoll.weapon(GunRoll.PISTOL), rig, Vector2i(x0, 0) + start, him)
		guard.target = pirate
		guards.append(guard)
	for i in 2:
		await physics_frame
	for guard in guards:
		guard.hear_position(him)
		guard.set_physics_process(true)
	var down := await _seconds_until(12.0, func() -> bool:
		return guards.all(func(g: Crew3D) -> bool: return g.cover.mode == CrewCover.Mode.DOWN))
	_expect(down >= 0.0, "last guard: the two Guards were not both down in cover within 12 s")
	var survivor := guards[1]
	var held: Vector2i = survivor.cover.tile
	var held_far := _flat(ShipBuilder3D.tile_to_world(held), him)
	guards[0].take_damage(100000, pirate)
	for frame in roundi(LAST_AFTER / STEP):
		await physics_frame
	var after: Vector2i = survivor.cover.tile
	var after_far := _flat(ShipBuilder3D.tile_to_world(after), him) if after != Vector2i.MAX else -1.0
	_expect(after != Vector2i.MAX and after_far > held_far,
			"last guard: %.0f s after its partner fell its cover tile is %s, %.1f m from him (last %s), want further than the %.1f m of %s"
			% [LAST_AFTER, after, after_far, survivor.cover.last_guard, held_far, held])
	var nearest := INF
	var nearest_tile := Vector2i.MAX
	for frame in roundi(LAST_HOLD / STEP):
		await physics_frame
		var tile: Vector2i = survivor.cover.tile
		if tile == Vector2i.MAX:
			continue
		var far := _flat(ShipBuilder3D.tile_to_world(tile), him)
		if far < nearest:
			nearest = far
			nearest_tile = tile
	print("  last guard: held %s at %.1f m, %.0f s later %s at %.1f m, nearest in the %.0f s after %.1f m" % [held, held_far, LAST_AFTER, after, after_far, LAST_HOLD, nearest])
	_expect(nearest >= after_far - 0.01, "last guard: in the %.0f s after, it held %s, %.1f m from him, nearer than the %.1f m of %s"
			% [LAST_HOLD, nearest_tile, nearest, after_far, after])
	survivor.set_physics_process(false)
	for guard in guards:
		guard.free()
	pirate.free()
	_clear_shots()


# --- Workers run and hide (crew-combat ticket 23) -----------------------------

## Medium ships the hiding sweep picks hiding places on, seeds 1 to this.
const HIDING_SWEEP := 20
## Of the sweep's picks whose Room offers a corner out of sight of every
## doorway, at least this share take one.
const HIDDEN_SHARE := 0.8
## Under the Alarm, every living Worker is near a corner within this.
const HIDE_WITHIN := 25.0
const TUCKED_NEAR := 0.5
## Over this many spottings, between these shares of Workers hide.
const SPOTTINGS := 400
const HIDE_SHARE := Vector2(0.2, 0.3)
## A wounded Worker is on its hiding tile within this, and still on it
## this much later.
const WOUNDED_HIDES := 15.0
const WOUNDED_STAYS := 60.0
## A hidden Worker leaves its tile this long after last noticing him,
## within this.
const LEAVE_AFTER := 20.0
const LEAVE_TOLERANCE := 1.0
## The Pirate in a hidden Worker's sight this far off, this long.
const FOUND_AT := 5.0
const FOUND_FOR := 10.0
## The hiding rig: Room A 12 x 12 at x 4000, Room B 6 x 12 east of it
## through a two-wide Door at (4012, 5); a wall of lockers at x 4004 from
## y 7 to 11 makes a pocket in A's south-west the Door cannot see into.
## Its own seed, so its Workers' rolls are the same on every run.
const HIDE_X0 := 4000
const HIDE_SEED := 5150
var hide_layout: ShipLayout
var hide_ship: Node3D


func _count_bolt(node: Node) -> void:
	if not node is Projectile3D:
		return
	var by := (node as Projectile3D).shooter as Crew3D
	if by == null:
		return
	if by.is_worker():
		worker_bolts += 1
	else:
		guard_bolts += 1


## No Worker fired a bolt in any check of the suite; Guards did, so the
## count was listening.
func _check_no_worker_shots() -> void:
	_expect(guard_bolts > 0 and worker_bolts == 0, "Workers fired %d bolts in the crew suite (Guards %d)" % [worker_bolts, guard_bolts])


## A new world holding only the projectiles node and the Pirate, parked far
## off, unkillable and still.
func _fresh_world() -> void:
	world.free()
	world = Node3D.new()
	root.add_child(world)
	var shots := Node3D.new()
	shots.add_to_group(&"projectiles")
	world.add_child(shots)
	player = load("res://scenes/player_3d.tscn").instantiate()
	world.add_child(player)
	player.set_physics_process(false)
	player.health.max_health = 100000
	player.health.reset()
	player.state = player.State.WALK
	player.global_position = Vector3(-500, 0, -500)


## The open tile of [param room] nearest its centre, as a world point.
func _middle_tile(ship_layout: ShipLayout, room: int, astar: AStarGrid2D) -> Vector3:
	var middle := ShipBuilder3D.room_center_world(ship_layout.rooms[room])
	var best := middle
	var best_far := INF
	for tile: Vector2i in ship_layout.rooms[room].tiles():
		var at := ShipBuilder3D.tile_to_world(tile)
		if _open_tile(astar, tile) and _flat(at, middle) < best_far:
			best = at
			best_far = _flat(at, middle)
	return best


## Within TUCKED_NEAR of the centre of a tile with a wall or a prop on two
## or more sides.
func _near_tucked(ship_layout: ShipLayout, at: Vector3) -> bool:
	var t := ShipBuilder3D.world_to_tile(at)
	for dx in [-1, 0, 1]:
		for dy in [-1, 0, 1]:
			var centre := ShipBuilder3D.tile_to_world(t + Vector2i(dx, dy))
			if _flat(centre, at) <= TUCKED_NEAR and CrewHiding.tucked(ship_layout, centre):
				return true
	return false


## On medium ships seeds 1 to 20, every Worker at its spawn picks a hiding
## place from the Pirate at the middle of the boarding Hatch's Room. Prints
## the share of hiding tiles with no clear line at 1.5 m to any doorway of
## their Room (the ticket's 80% line, which the generated Rooms cannot give:
## see the ticket's Comments), and asserts the preference behind it: where
## the Room offers a corner out of sight of every doorway, at least 80% of
## picks take one.
func _check_hiding_sweep() -> void:
	var picks := 0
	var unseen := 0
	var offered := 0
	var offered_unseen := 0
	var none := 0
	var untucked := 0
	for ship_seed in range(1, HIDING_SWEEP + 1):
		_fresh_world()
		var ship_layout := ShipGenerator.generate(&"medium", ship_seed)
		var ship := Node3D.new()
		ship.name = "Ship"
		world.add_child(ship)
		ShipBuilder3D.build(ship_layout, ship)
		var workers: Array[Crew3D] = []
		for member: Crew3D in ship.get_node("Crew").get_children():
			if member.is_worker():
				member.set_physics_process(false)
				member.target = player
				workers.append(member)
			else:
				member.free()
		await physics_frame
		await physics_frame
		var astar := CrewPaths.grid(ship_layout)
		var him := _middle_tile(ship_layout, ship_layout.hatches[0].room, astar)
		for worker in workers:
			worker._last_seen = him
			var found := worker.hiding.find()
			if found.is_empty():
				none += 1
				continue
			picks += 1
			var entries := CrewHiding.tiles_of(worker, ship_layout.room_at(found.tile))
			var entry: Dictionary = entries.filter(func(e: Dictionary) -> bool: return e.tile == found.tile)[0]
			if entry.unseen:
				unseen += 1
			if entry.sides < 2:
				untucked += 1
			if entries.any(func(e: Dictionary) -> bool: return e.unseen and e.sides >= 2):
				offered += 1
				if entry.unseen:
					offered_unseen += 1
	print("  hiding sweep (medium seeds 1-%d): %d of %d hiding tiles out of sight of every doorway (%.0f%%); %d of %d where the Room offers such a corner; %d Workers with no place, %d tiles not a corner"
			% [HIDING_SWEEP, unseen, picks, 100.0 * unseen / maxi(picks, 1), offered_unseen, offered, none, untucked])
	_expect(picks >= HIDING_SWEEP and offered > 0 and offered_unseen >= offered * HIDDEN_SHARE,
			"hiding sweep: of %d picks where the Room offers a corner out of sight of its doorways, only %d took one" % [offered, offered_unseen])


## A generated medium ship with all its crew, the Pirate (unkillable, still)
## at the middle of the Post Room of the most Workers and the Alarm raised
## there: Guards fight him for 60 s and every Worker hides. Every living
## Worker is within 0.5 m of a tile with a wall or a prop on two sides at
## 25 s, and no Worker's hiding tile is ever a tile a Guard has claimed.
func _check_workers_in_fight() -> void:
	_fresh_world()
	var ship_seed := randi_range(1, 1_000_000)
	var ship_layout := ShipGenerator.generate(&"medium", ship_seed)
	var ship := Node3D.new()
	ship.name = "Ship"
	world.add_child(ship)
	ShipBuilder3D.build(ship_layout, ship)
	var tag := "Workers in a fight (medium seed %d)" % ship_seed
	var crew: Array[Crew3D] = []
	var workers: Array[Crew3D] = []
	var per_room := {}
	for member: Crew3D in ship.get_node("Crew").get_children():
		member.target = player
		crew.append(member)
		if member.is_worker():
			workers.append(member)
			per_room[member.home_room] = per_room.get(member.home_room, 0) + 1
	_expect(not workers.is_empty(), "%s: no Workers aboard" % tag)
	if workers.is_empty():
		return
	# Each built Worker wears the set rolled from the ship's seed and its
	# spawn tile (crew-combat ticket 25, `_check_pose_roll`).
	var unrolled: Array[String] = []
	for worker in workers:
		var spawn := ShipBuilder3D.world_to_tile(worker.global_position)
		if worker.pose_set != CrewPose.roll_set(ship_layout.gen_seed, spawn) or worker.pose == null:
			unrolled.append("%s: %s" % [spawn, worker.pose_set])
	_expect(unrolled.is_empty(), "%s: Workers whose pose set is not the one rolled from the ship's seed and spawn tile: %s" % [tag, unrolled])
	var room: int = per_room.keys()[0]
	for r: int in per_room:
		if per_room[r] > per_room[room] or (per_room[r] == per_room[room]
				and ship_layout.rooms[r].tiles().size() > ship_layout.rooms[room].tiles().size()):
			room = r
	var him := _middle_tile(ship_layout, room, CrewPaths.grid(ship_layout))
	player.global_position = him
	for i in 2:
		await physics_frame
	var alarm: ShipAlarm = ship.get_node("Alarm")
	alarm.raise(him)
	var on_claimed: Array[String] = []
	var untucked: Array[String] = []
	var claims := 0
	var hidden_since := {}
	var facing_off: Array[String] = []
	var faced := 0
	var t := 0.0
	for frame in roundi(SHIP_FIGHT / STEP):
		await physics_frame
		t += STEP
		var claimed := {}
		for member in crew:
			if is_instance_valid(member) and member.is_alive() and member.cover != null and member.cover.tile != Vector2i.MAX:
				claimed[member.cover.tile] = true
		claims += claimed.size()
		for worker in workers:
			if not is_instance_valid(worker) or not worker.is_alive():
				continue
			var held := worker.hiding.tile
			if held != Vector2i.MAX and claimed.has(held) and on_claimed.size() < 3:
				on_claimed.append("%s, %s (t=%.1f s)" % [held, CrewHiding.PHASE_NAMES[worker.hiding.phase], t])
			if worker.state == Crew3D.State.COWER and worker.hiding.phase == CrewHiding.Phase.HIDDEN:
				hidden_since[worker] = hidden_since.get(worker, t)
			else:
				hidden_since.erase(worker)
			# On its tile a while, back to the wall: facing straight out from it.
			# (A tile between two solid sides facing each other has none behind.)
			if frame == roundi(HIDE_WITHIN / STEP) - 1 and t - hidden_since.get(worker, INF) >= FACING_AFTER \
					and _has_back(ship_layout, worker.global_position):
				var off := _facing_off(worker)
				if off < INF:
					faced += 1
					if off > FACING_WITHIN:
						facing_off.append("%s %.0f deg" % [ShipBuilder3D.world_to_tile(worker.global_position), off])
			if frame == roundi(HIDE_WITHIN / STEP) - 1 and not _near_tucked(ship_layout, worker.global_position):
				untucked.append("a Worker of Room %d in state %d, %s, at %s" % [worker.home_room, worker.state,
						CrewHiding.PHASE_NAMES[worker.hiding.phase], ShipBuilder3D.world_to_tile(worker.global_position)])
	for member in crew:
		if is_instance_valid(member):
			member.set_physics_process(false)
	print("  %s: %d Workers, Guards' claims over the fight %d tile-frames" % [tag, workers.size(), claims])
	_expect(claims > 0, "%s: no Guard ever claimed cover: there was no fight" % tag)
	_expect(untucked.is_empty(), "%s: at %.0f s, Workers not within %.1f m of a corner: %s" % [tag, HIDE_WITHIN, TUCKED_NEAR, untucked])
	_expect(on_claimed.is_empty(), "%s: a Worker's hiding tile was a Guard's cover: %s" % [tag, on_claimed])
	print("  %s: at %.0f s, %d hidden Workers with a wall or prop behind them, facing off straight out from it: %s" % [tag, HIDE_WITHIN, faced, facing_off])
	_expect(facing_off.is_empty(), "%s: hidden Workers facing over %.0f degrees off straight away from the wall behind them: %s"
			% [tag, FACING_WITHIN, facing_off])
	for shot in get_first_node_in_group(&"projectiles").get_children():
		shot.free()


func _build_hide_rig() -> void:
	hide_layout = ShipLayout.new()
	hide_layout.gen_seed = HIDE_SEED
	var a := RoomData.new()
	a.rects = [Rect2i(HIDE_X0, 0, 12, 12)]
	for y in range(7, 12):
		a.props.append({"type": &"locker", "tile": Vector2i(HIDE_X0 + 4, y)})
	var b := RoomData.new()
	b.rects = [Rect2i(HIDE_X0 + 13, 0, 6, 12)]
	hide_layout.rooms = [a, b]
	var door := DoorData.new()
	door.room_a = 0
	door.room_b = 1
	door.tile = Vector2i(HIDE_X0 + 12, 5)
	door.horizontal = false
	hide_layout.doors = [door]
	hide_ship = Node3D.new()
	hide_ship.name = "HideShip"
	world.add_child(hide_ship)
	ShipBuilder3D.build(hide_layout, hide_ship)


## A working Alarm Panel in Room B's east wall.
func _hide_panel() -> AlarmPanel:
	var panel := AlarmPanel.new()
	panel.setup(1, Vector2i(HIDE_X0 + 18, 1), Vector2i.RIGHT)
	hide_ship.add_child(panel)
	return panel


## A Worker posted in Room A of the hiding rig at [param tile], still.
func _hide_worker(tile: Vector2i) -> Crew3D:
	var worker: Crew3D = load("res://scenes/crew_3d.tscn").instantiate()
	worker.crew_type = CrewTypes.Type.WORKER
	worker.target = player
	worker.layout = hide_layout
	worker.home_room = 0
	worker.position = ShipBuilder3D.tile_to_world(tile)
	world.add_child(worker)
	worker.face_direction(Vector3.FORWARD)
	worker.set_physics_process(false)
	worker.routine = null
	worker._hold_timer = 10.0
	worker._glance_timer = 10.0
	return worker


func _hide_at(x: int, y: int) -> Vector3:
	return ShipBuilder3D.tile_to_world(Vector2i(HIDE_X0 + x, y))


## Seconds of physics until [param worker] is on its hiding tile, or INF
## after [param limit].
func _until_hidden(worker: Crew3D, limit: float) -> float:
	var t := 0.0
	while t < limit:
		await physics_frame
		t += STEP
		if worker.hiding.phase == CrewHiding.Phase.HIDDEN and _flat(worker.global_position, worker.hiding.spot) <= CrewHiding.ON_TILE:
			return t
	return INF


## The Workers' rig: the hide roll, the run, staying put when found, the
## wounded, and coming out with and without a panel to raise.
func _check_hiding_rig() -> void:
	_fresh_world()
	_build_hide_rig()
	for i in 2:
		await physics_frame
	var alarm: ShipAlarm = hide_ship.get_node("Alarm")
	var panel := _hide_panel()
	await physics_frame
	_check_hide_roll(panel)
	await _check_hide_run()
	await _check_wounded_hides(alarm)
	panel.take_damage(1, player)
	await _check_out_with_nothing(alarm)
	panel.free()
	await _check_out_to_panel(alarm)


## 400 spottings with the Alarm down and a panel in reach, 100 by each of
## four Workers: between 20% and 30% freeze to hide, the rest run for the
## panel. Rolled from the ship's seed: a Worker spawned again on the same
## tile of the same ship rolls the same.
func _check_hide_roll(panel: AlarmPanel) -> void:
	var hides := 0
	var runs := 0
	var other: Array[String] = []
	var first: Array[bool] = []
	var tiles: Array[Vector2i] = [Vector2i(HIDE_X0 + 6, 2), Vector2i(HIDE_X0 + 8, 9), Vector2i(HIDE_X0 + 15, 3), Vector2i(HIDE_X0 + 16, 9)]
	for k in tiles.size():
		var worker := _hide_worker(tiles[k])
		for i in SPOTTINGS / tiles.size():
			worker._enter(Crew3D.State.PATROL)
			worker._react_spotted()
			var hid := worker.state == Crew3D.State.COWER and worker.hiding.phase == CrewHiding.Phase.FREEZE
			if hid:
				hides += 1
			elif worker.state == Crew3D.State.FLEE and worker._flee_panel == panel:
				runs += 1
			elif other.size() < 3:
				other.append("state %d" % worker.state)
			if k == 0:
				first.append(hid)
		worker.free()
	var again := _hide_worker(tiles[0])
	var same := true
	for i in first.size():
		again._enter(Crew3D.State.PATROL)
		again._react_spotted()
		same = same and (again.state == Crew3D.State.COWER) == first[i]
	again.free()
	print("  hide roll: %d of %d spottings hid, %d ran for the panel" % [hides, SPOTTINGS, runs])
	_expect(hides + runs == SPOTTINGS and other.is_empty(), "hide roll: spottings neither hid nor ran for the panel: %s" % [other])
	_expect(hides >= SPOTTINGS * HIDE_SHARE.x and hides <= SPOTTINGS * HIDE_SHARE.y,
			"hide roll: %d of %d spottings hid, want %.0f%% to %.0f%%" % [hides, SPOTTINGS, HIDE_SHARE.x * 100.0, HIDE_SHARE.y * 100.0])
	_expect(same, "hide roll: a Worker spawned again on the same tile of the same ship rolled differently")


## A Worker that rolled to hide, the Pirate 4.1 m off: it freezes, runs to
## a corner never nearer him than both ends of its run less 1 m, and then,
## with him standing 5 m off in its sight for 10 s, does not leave its tile.
func _check_hide_run() -> void:
	var worker := _hide_worker(Vector2i(HIDE_X0 + 6, 4))
	worker.hide_chance = 1.0
	var him := _hide_at(10, 3)
	player.global_position = him
	worker._last_seen = him
	worker._react_spotted()
	_expect(worker.state == Crew3D.State.COWER and worker.hiding.phase == CrewHiding.Phase.FREEZE,
			"hide run: a Worker that rolled to hide is in state %d, %s, not frozen" % [worker.state, CrewHiding.PHASE_NAMES[worker.hiding.phase]])
	var start := worker.global_position
	var nearest := INF
	var froze := 0.0
	worker.set_physics_process(true)
	var t := 0.0
	while t < 15.0 and worker.hiding.phase != CrewHiding.Phase.HIDDEN:
		await physics_frame
		t += STEP
		if worker.hiding.phase == CrewHiding.Phase.FREEZE:
			froze += STEP
		nearest = minf(nearest, _flat(worker.global_position, him))
	var spot := worker.hiding.spot
	var least := minf(_flat(start, him), _flat(spot, him)) - 1.0
	print("  hide run: froze %.2f s, hid on %s after %.1f s, nearest him %.2f m (ends %.2f and %.2f m)"
			% [froze, worker.hiding.tile, t, nearest, _flat(start, him), _flat(spot, him)])
	_expect(worker.hiding.phase == CrewHiding.Phase.HIDDEN, "hide run: not hidden after 15 s (%s)" % CrewHiding.PHASE_NAMES[worker.hiding.phase])
	_expect(absf(froze - CrewHiding.FREEZE) <= 2.0 * STEP, "hide run: froze %.2f s, not %.1f" % [froze, CrewHiding.FREEZE])
	_expect(nearest >= least, "hide run: came %.2f m from him, nearer than both ends less 1 m (%.2f)" % [nearest, least])
	_expect(CrewHiding.tucked(hide_layout, spot), "hide run: its hiding tile %s is not a corner" % worker.hiding.tile)
	# Found: him 5 m off in its sight for 10 s.
	var found_at := Vector3.INF
	for k in 16:
		var along := Vector3.FORWARD.rotated(Vector3.UP, TAU * k / 16.0)
		var at := spot + along * FOUND_AT
		if not _open_tile(CrewPaths.grid(hide_layout), ShipBuilder3D.world_to_tile(at)):
			continue
		if not worker._blocked(spot + Vector3.UP * Crew3D.EYE_HEIGHT, at + Vector3.UP * Crew3D.EYE_HEIGHT):
			found_at = at
			break
	_expect(found_at != Vector3.INF, "hide run: no open floor 5 m from the hiding tile in its sight")
	if found_at != Vector3.INF:
		player.global_position = found_at
		var left := 0.0
		var seen := 0
		var frames := roundi(FOUND_FOR / STEP)
		for i in frames:
			await physics_frame
			if worker._can_see:
				seen += 1
			left = maxf(left, _flat(worker.global_position, spot))
		_expect(seen * 10 >= frames * 9, "found: the Worker had him in sight on only %d of %d frames" % [seen, frames])
		_expect(left <= CrewHiding.ON_TILE and worker.state == Crew3D.State.COWER,
				"found: with him 5 m off for 10 s the Worker moved %.2f m off its tile (state %d)" % [left, worker.state])
	# Guards come first: a Guard claiming its tile sends it on to its next best.
	var held := worker.hiding.tile
	var guard := _armed(load("res://resources/weapons/pistol.tres"))
	guard.layout = hide_layout
	guard.global_position = _hide_at(9, 9)
	guard.cover._claim({"tile": held, "at": ShipBuilder3D.tile_to_world(held), "step": Vector3.INF,
			"low": false, "peek": false, "score": 0.0})
	_expect(worker.hiding.tile != held and worker.hiding.phase == CrewHiding.Phase.RUN,
			"hide run: a Guard claimed its tile %s and the Worker is %s for %s" % [held, CrewHiding.PHASE_NAMES[worker.hiding.phase], worker.hiding.tile])
	var moved := await _until_hidden(worker, 10.0)
	_expect(moved < INF and worker.hiding.tile != held and CrewHiding.tucked(hide_layout, worker.hiding.spot),
			"hide run: after a Guard took its tile the Worker is %s on %s" % [CrewHiding.PHASE_NAMES[worker.hiding.phase], worker.hiding.tile])
	guard.free()
	worker.free()
	player.global_position = Vector3(-500, 0, -500)


## A Worker hit for less than its Health, a working panel in reach and the
## Alarm down: on a hiding tile within 15 s and still on it 60 s later.
func _check_wounded_hides(alarm: ShipAlarm) -> void:
	var worker := _hide_worker(Vector2i(HIDE_X0 + 8, 8))
	player.global_position = _hide_at(9, 2)
	worker.set_physics_process(true)
	worker.take_damage(1, player)
	player.global_position = Vector3(-500, 0, -500)
	_expect(worker.is_alive() and worker.hiding.wounded, "wounded: a Worker hit for 1 is not alive and wounded")
	var hid := await _until_hidden(worker, WOUNDED_HIDES)
	_expect(hid <= WOUNDED_HIDES, "wounded: not on a hiding tile within %.0f s (%s, state %d)" % [WOUNDED_HIDES,
			CrewHiding.PHASE_NAMES[worker.hiding.phase], worker.state])
	var spot := worker.hiding.spot
	var left := 0.0
	for i in roundi(WOUNDED_STAYS / STEP):
		await physics_frame
		left = maxf(left, _flat(worker.global_position, spot))
	_expect(left <= CrewHiding.ON_TILE and worker.state == Crew3D.State.COWER and not alarm.is_raised,
			"wounded: %.0f s later it moved %.2f m off its tile (state %d, Alarm %s)" % [WOUNDED_STAYS, left, worker.state, alarm.is_raised])
	worker.free()


## Every panel broken and no Guard alive: a hidden Worker comes out after
## 20 s quiet, back on its routine and On Edge, the Alarm still down.
func _check_out_with_nothing(alarm: ShipAlarm) -> void:
	var worker := _hide_worker(Vector2i(HIDE_X0 + 8, 8))
	worker.routine = CrewRoutine.plan(hide_layout, 0, RandomNumberGenerator.new(), false)
	var him := _hide_at(9, 2)
	player.global_position = him
	worker._last_seen = him
	worker._react_spotted()
	worker.set_physics_process(true)
	var hid := await _until_hidden(worker, 15.0)
	_expect(hid < INF, "out, nothing to raise: the Worker never hid (state %d)" % worker.state)
	player.global_position = Vector3(-500, 0, -500)
	for i in roundi((LEAVE_AFTER + 3.0) / STEP):
		await physics_frame
	_expect(worker.state == Crew3D.State.PATROL and worker.perception.on_edge and not alarm.is_raised,
			"out, nothing to raise: state %d, On Edge %s, Alarm %s; want back on its routine, On Edge, Alarm down"
			% [worker.state, worker.perception.on_edge, alarm.is_raised])
	worker.free()


## A hidden Worker, the Alarm down and the Pirate gone: it leaves its tile
## 20 s after it last noticed him, within 1 s, and raises the Alarm at the
## working panel.
func _check_out_to_panel(alarm: ShipAlarm) -> void:
	var panel := _hide_panel()
	await physics_frame
	var worker := _hide_worker(Vector2i(HIDE_X0 + 8, 8))
	worker.routine = CrewRoutine.plan(hide_layout, 0, RandomNumberGenerator.new(), false)
	worker.hide_chance = 1.0
	var him := _hide_at(9, 2)
	player.global_position = him
	worker._last_seen = him
	worker._react_spotted()
	worker.set_physics_process(true)
	# Its own eyes say when it last noticed him: the last frame it had him in
	# sight (he makes no sound, standing still).
	var t := 0.0
	var noticed := -INF
	var hidden_at := INF
	var spot := Vector3.INF
	var left := INF
	while t < 120.0 and not alarm.is_raised:
		await physics_frame
		t += STEP
		if worker._can_see and left == INF:
			noticed = t
		if hidden_at == INF and worker.hiding.phase == CrewHiding.Phase.HIDDEN:
			hidden_at = t
			spot = worker.hiding.spot
		if hidden_at < INF and t >= hidden_at + 0.5:
			player.global_position = Vector3(-500, 0, -500)
		if hidden_at < INF and left == INF and _flat(worker.global_position, spot) > CrewHiding.ON_TILE:
			left = t
	_expect(hidden_at <= 15.0, "out to a panel: the Worker never hid in 15 s (state %d)" % worker.state)
	print("  out to a panel: last noticed him at %.2f s, left its tile at %.2f s, Alarm raised at %.1f s" % [noticed, left, t])
	_expect(absf(left - noticed - LEAVE_AFTER) <= LEAVE_TOLERANCE,
			"out to a panel: left its tile %.2f s after last noticing him, want %.0f s within %.0f" % [left - noticed, LEAVE_AFTER, LEAVE_TOLERANCE])
	_expect(alarm.is_raised and _flat(worker.global_position, panel.use_at) < 1.5,
			"out to a panel: the Alarm %s, the Worker %.1f m from the panel" % ["raised" if alarm.is_raised else "not raised", _flat(worker.global_position, panel.use_at)])
	worker.free()
	panel.free()


# --- Surrender and Bound (crew-combat ticket 24) ------------------------------

## A hiding Worker surrenders within this of him coming within 4 m in its
## sight (he steps from 6 m to 3.9 m).
const SURRENDER_WITHIN := 0.2
const SURRENDER_FAR := 6.0
const SURRENDER_NEAR := 3.9
## Aimed at from 8 m: surrendered this long after his crosshair settles on
## it, within this; never while it points this many degrees away.
const AIMED_FROM := 8.0
const AIM_SETTLE := 0.5
const AIM_TOLERANCE := 0.1
const AIM_OFF := 20.0
## Kneeling this long after surrendering, within this; then still, him in
## its sight, this long, moving no more than this.
const KNEEL_AT := 1.5
const KNEEL_TOLERANCE := 0.2
const HOLDS_FOR := 30.0
const HOLD_MOVE := 0.05
## The interact key held this long within this reach binds; let go at this,
## it does not.
const BIND_AT := 2.0
const BIND_REACH := 2.0
const BIND_LET_GO := 1.5
const BIND_TOLERANCE := 1.5 / 60.0
## A Bound Worker the Pirate leaves raises nothing in this long.
const BOUND_QUIET := 120.0
## A Guard that reaches a Bound Worker is hunting within this.
const GUARD_HUNTS := 3.0
const GUARD_REACHED := 2.0


func _count_surrenders(node: Node) -> void:
	var crew := node as Crew3D
	if crew == null:
		return
	crew.surrender_changed.connect(func(stage: Crew3D.Surrender) -> void:
		if stage != Crew3D.Surrender.HANDS_UP:
			return
		if crew.is_worker():
			worker_surrenders += 1
		else:
			guard_surrenders += 1)


## No Guard surrendered in any check of the suite; Workers did, so the
## count was listening.
func _check_no_guard_surrenders() -> void:
	_expect(guard_surrenders == 0 and worker_surrenders > 0,
			"surrender: %d Guards surrendered in the crew suite (Workers %d)" % [guard_surrenders, worker_surrenders])


## Turns the Pirate (still, physics off or on) so his crosshair runs from
## his eye through [param at].
func _aim_pirate(at: Vector3) -> void:
	for i in 2:
		var to: Vector3 = at - player.camera.global_position
		player.rotation.y = atan2(-to.x, -to.z)
		player.head.rotation.x = atan2(to.y, Vector2(to.x, to.z).length())


## Back to yaw 0, level.
func _level_pirate() -> void:
	player.rotation.y = 0.0
	player.head.rotation.x = 0.0


## The middle of a Worker's body, where his crosshair rests on it: 1 m up
## standing, under the top of its capsule as its pose has cut it (crouched,
## sat or kneeling, crew-combat ticket 25), as the smoke bot aims.
func _chest(worker: Crew3D) -> Vector3:
	var shape: CollisionShape3D = worker.get_node("CollisionShape3D")
	var top: float = shape.position.y + (shape.shape as CapsuleShape3D).height / 2.0
	return worker.global_position + Vector3.UP * minf(1.0, top - 0.3)


## A point on open floor [param distance] from [param worker], in its sight
## (a clear eye line), along one of 16 ways round; each of [param also] (a
## list of other distances along the same way) open and in sight too. INF
## with none.
func _in_sight_of(worker: Crew3D, distance: float, also: Array = []) -> Vector3:
	var astar := CrewPaths.grid(worker.layout)
	var at_eye := worker.global_position + Vector3.UP * Crew3D.EYE_HEIGHT
	for k in 16:
		var along := Vector3.FORWARD.rotated(Vector3.UP, TAU * k / 16.0)
		var ok := true
		for d: float in [distance] + also:
			var at: Vector3 = worker.global_position + along * d
			at.y = 0.0
			if not _open_tile(astar, ShipBuilder3D.world_to_tile(at)) \
					or worker._blocked(at_eye, at + Vector3.UP * Crew3D.EYE_HEIGHT):
				ok = false
				break
		if ok:
			var found := worker.global_position + along * distance
			return Vector3(found.x, 0.0, found.z)
	return Vector3.INF


## A Worker of the hiding rig hidden on its tile, the Pirate parked off the
## ship; null (and a failure) if it never hid.
func _hidden_worker(tile: Vector2i, him: Vector3, tag: String) -> Crew3D:
	var worker := _hide_worker(tile)
	player.global_position = Vector3(-500, 0, -500)
	worker._last_seen = him
	worker._hide()
	worker.set_physics_process(true)
	var hid := await _until_hidden(worker, 15.0)
	_expect(hid < INF, "%s: the Worker never hid (state %d)" % [tag, worker.state])
	if hid == INF:
		worker.free()
		return null
	return worker


## A Worker running for a panel by a clear route, the Pirate 8 m off with
## his crosshair on it all the way: it never surrenders (crew-combat ticket
## 24). Its own hiding rig, with a panel on Room A's north wall, so the
## Alarm it raises there leaves the next checks' Alarm down.
func _check_flee_aimed() -> void:
	_fresh_world()
	_build_hide_rig()
	for i in 2:
		await physics_frame
	var panel := AlarmPanel.new()
	panel.setup(0, Vector2i(HIDE_X0 + 11, 0), Vector2i.UP)
	hide_ship.add_child(panel)
	await physics_frame
	var worker := _hide_worker(Vector2i(HIDE_X0 + 6, 1))
	worker.hide_chance = 0.0
	player.global_position = _hide_at(6, 9)
	worker._last_seen = player.global_position
	worker.perception.awareness = 1.0
	worker._react_spotted()
	_expect(worker.state == Crew3D.State.FLEE and worker._flee_panel == panel,
			"flee aimed: the Worker is in state %d, not running for the panel" % worker.state)
	worker.set_physics_process(true)
	var alarm: ShipAlarm = hide_ship.get_node("Alarm")
	var aimed_most := 0.0
	var surrendered := false
	var t := 0.0
	while t < 6.0 and not alarm.is_raised:
		_aim_pirate(_chest(worker))
		await physics_frame
		t += STEP
		aimed_most = maxf(aimed_most, worker.aimed_for)
		surrendered = surrendered or worker.state == Crew3D.State.SURRENDER
	print("  flee aimed: crosshair rested on it %.2f s in a row from %.1f m, Alarm %s at %.1f s"
			% [aimed_most, AIMED_FROM, "raised" if alarm.is_raised else "not raised", t])
	_expect(aimed_most >= AIM_SETTLE, "flee aimed: his crosshair rested on it only %.2f s in a row" % aimed_most)
	_expect(not surrendered, "flee aimed: a Worker running for a panel by a clear route surrendered")
	_expect(alarm.is_raised, "flee aimed: the Worker never raised the Alarm at the panel")
	worker.free()
	_level_pirate()


## The surrender rig: a hiding Worker surrendering to him near, kneeling and
## holding, then Bound by the interact key held (and not by a hold let go),
## no Awareness bar, the Pirate leaving it 120 s with nothing raised, a
## Guard finding it and hunting and a second passing it by; then one left
## surrendered coming out to raise the Alarm, one aimed at from 8 m with the
## Alarm up, and the interact key working a Door he faces over a Worker
## beside it.
func _check_surrender_rig() -> void:
	_fresh_world()
	_build_hide_rig()
	for i in 2:
		await physics_frame
	var alarm: ShipAlarm = hide_ship.get_node("Alarm")
	var panel := _hide_panel()
	await physics_frame
	var bound := await _check_surrender_near()
	if bound != null:
		await _check_bind_hold(bound)
		await _check_bound_left(bound, alarm)
		bound.free()
	await _check_surrender_left(alarm)
	await _check_surrender_aimed(alarm)
	await _check_bind_or_door()
	panel.free()


## A hidden Worker, him 6 m off in its sight: nothing. He steps to 3.9 m:
## surrendered within 0.2 s; kneeling 1.5 s later within 0.2 s; still,
## kneeling, him in its sight, 30 s on; a hit for 1 leaves it so.
func _check_surrender_near() -> Crew3D:
	var worker := await _hidden_worker(Vector2i(HIDE_X0 + 8, 8), _hide_at(10, 2), "surrender near")
	if worker == null:
		return null
	var far := _in_sight_of(worker, SURRENDER_FAR, [SURRENDER_NEAR])
	_expect(far != Vector3.INF, "surrender near: no open floor 6 m and 3.9 m off in its sight")
	if far == Vector3.INF:
		worker.free()
		return null
	var way := (far - worker.global_position).normalized()
	player.global_position = far
	# Facing away: only distance counts here.
	_aim_pirate(far + way * 5.0 + Vector3.UP * 1.6)
	for i in 60:
		await physics_frame
	_expect(worker.state == Crew3D.State.COWER and worker._can_see,
			"surrender near: him 6 m off in its sight, the Worker is in state %d (sees him %s)" % [worker.state, worker._can_see])
	player.global_position = worker.global_position + way * SURRENDER_NEAR
	player.global_position.y = 0.0
	var t := 0.0
	while t < 1.0 and worker.state != Crew3D.State.SURRENDER:
		await physics_frame
		t += STEP
	print("  surrender near: surrendered %.3f s after he came 3.9 m off" % t)
	_expect(t <= SURRENDER_WITHIN, "surrender near: surrendered %.2f s after he came within 4 m, want within %.1f s (state %d)"
			% [t, SURRENDER_WITHIN, worker.state])
	var start := worker.global_position
	var kneel := INF
	var moved := 0.0
	var seen := 0
	var lost := false
	var frames := roundi((KNEEL_AT + HOLDS_FOR) / STEP)
	var since := 0.0
	for i in frames:
		await physics_frame
		since += STEP
		if kneel == INF and worker.surrender == Crew3D.Surrender.KNEELING:
			kneel = since
		moved = maxf(moved, _flat(worker.global_position, start))
		seen += 1 if worker._can_see else 0
		lost = lost or worker.state != Crew3D.State.SURRENDER
	print("  surrender near: kneeling %.2f s after surrendering, moved %.3f m in %.0f s" % [kneel, moved, KNEEL_AT + HOLDS_FOR])
	_expect(absf(kneel - KNEEL_AT) <= KNEEL_TOLERANCE, "surrender near: kneeling %.2f s after surrendering, want %.1f within %.1f"
			% [kneel, KNEEL_AT, KNEEL_TOLERANCE])
	_expect(not lost and worker.surrender == Crew3D.Surrender.KNEELING and moved <= HOLD_MOVE and seen == frames,
			"surrender near: %.0f s on, him in its sight %d of %d frames, it moved %.3f m (state %d, %s)"
			% [HOLDS_FOR, seen, frames, moved, worker.state, Crew3D.SURRENDER_NAMES[worker.surrender]])
	worker.take_damage(1, player)
	_expect(worker.is_alive() and worker.state == Crew3D.State.SURRENDER and worker.surrender == Crew3D.Surrender.KNEELING,
			"surrender near: a hit for 1 left a kneeling Worker in state %d, %s" % [worker.state, Crew3D.SURRENDER_NAMES[worker.surrender]])
	return worker


## The Pirate, moving under his own physics, 1.5 m from the kneeling Worker
## and facing it: a hold let go at 1.5 s binds nothing and keeps nothing; a
## hold cut by a hit is not taken up again while the key stays down; a hold
## of 2 s binds it, and the trigger pulled meanwhile fires nothing. Bound,
## it shows no Awareness bar.
func _check_bind_hold(worker: Crew3D) -> void:
	var way := (player.global_position - worker.global_position)
	way.y = 0.0
	player.global_position = worker.global_position + way.normalized() * 1.5
	_aim_pirate(_chest(worker))
	player.set_physics_process(true)
	await physics_frame
	_expect(player.bind_target() == worker, "bind: 1.5 m from a surrendered Worker, facing it, it is not his to tie up")
	# Let go at 1.5 s.
	Input.action_press("interact")
	for i in roundi((BIND_LET_GO + 0.5) / STEP):
		await physics_frame
		if player.bind_held >= BIND_LET_GO - 0.001:
			break
	var held: float = player.bind_held
	Input.action_release("interact")
	await physics_frame
	_expect(absf(held - BIND_LET_GO) < 0.001 and player.is_binding() == false and player.bind_held == 0.0 and worker.is_surrendered(),
			"bind: let go at %.2f s (held %.2f), it is %s, the hold kept %.2f s" % [BIND_LET_GO, held,
			"Bound" if worker.is_bound() else "not Bound", player.bind_held])
	# A hit at 1 s: let go, and not taken up again while the key stays down.
	Input.action_press("interact")
	for i in 60:
		await physics_frame
	player.take_damage(1, worker)
	await physics_frame
	var cut: bool = not player.is_binding()
	for i in 90:
		await physics_frame
	_expect(cut and not player.is_binding() and worker.is_surrendered(),
			"bind: a hit at 1 s did not end the hold, or it started again with the key still down")
	Input.action_release("interact")
	await physics_frame
	# Held 2 s, the trigger pulled in the middle of it.
	var shots := [0]
	var count := func() -> void: shots[0] += 1
	player.fired.connect(count)
	var ammo: int = player.ammo
	Input.action_press("interact")
	# Timed from the frame the hold starts (the frame after the press is
	# seen), as the bind time is.
	var started := -1
	var t := 0.0
	var at_1_9 := false
	var frame := 0
	while frame < 200 and not worker.is_bound():
		if frame == 30:
			Input.action_press("shoot")
		if frame == 60:
			Input.action_release("shoot")
		await physics_frame
		frame += 1
		if started < 0 and player.is_binding():
			started = frame
		if started >= 0:
			t = (frame - started) * STEP
			if frame - started == 114:
				at_1_9 = worker.is_bound()
	Input.action_release("interact")
	Input.action_release("shoot")
	player.fired.disconnect(count)
	print("  bind: Bound %.3f s after the hold started (%d frames after the press), %d shots fired during the hold" % [t, started, shots[0]])
	_expect(started >= 0 and started <= 2 and worker.is_bound() and absf(t - BIND_AT) <= BIND_TOLERANCE and not at_1_9,
			"bind: a fresh hold bound it after %.2f s (Bound at 1.9 s: %s), want %.1f s" % [t, at_1_9, BIND_AT])
	_expect(shots[0] == 0 and player.ammo == ammo, "bind: the Pirate fired %d shots during the hold" % shots[0])
	_expect(BIND_REACH == player.sandbox.bind_reach and BIND_AT == player.sandbox.bind_time,
			"bind: the Sandbox's bind reach %.1f m and time %.1f s are not 2 m and 2 s" % [player.sandbox.bind_reach, player.sandbox.bind_time])
	# Beyond reach, no prompt for another surrendered Worker: none here, so
	# the Bound one is no longer his to tie up.
	_expect(player.bind_target() == null, "bind: a Bound Worker is still offered to tie up")
	player.set_physics_process(false)
	var bar := AwarenessMarkers.new()
	world.add_child(bar)
	worker.perception.awareness = 1.0
	_expect(bar.mark_at(worker, player.camera) == Vector2.INF, "bind: a Bound Worker shows an Awareness bar")
	worker.perception.awareness = 0.0
	bar.free()
	_level_pirate()


## The Bound Worker left 120 s, the Alarm down and a panel working: it
## raises nothing and never moves. A Guard walking up to it is hunting
## within 3 s of reaching it; a second Guard passing it later does not
## react.
func _check_bound_left(worker: Crew3D, alarm: ShipAlarm) -> void:
	player.global_position = Vector3(-500, 0, -500)
	var start := worker.global_position
	var moved := 0.0
	var t := 0.0
	var first: Crew3D = null
	var second: Crew3D = null
	var reached := INF
	var hunting := INF
	var second_reacted := ""
	var second_near := false
	while t < BOUND_QUIET:
		await physics_frame
		t += STEP
		moved = maxf(moved, _flat(worker.global_position, start))
		if first == null and hunting == INF and t >= 5.0:
			first = _guard_to(worker)
		if first != null and is_instance_valid(first):
			if reached == INF and _flat(first.global_position, worker.global_position) <= GUARD_REACHED:
				reached = t
			if hunting == INF and first.state == Crew3D.State.HUNT:
				hunting = t
				first.free()
				first = null
			elif t > 40.0:
				first.free()
				first = null
		if second == null and t >= 50.0 and t < 51.0:
			second = _guard_to(worker)
		if second != null and is_instance_valid(second):
			second_near = second_near or _flat(second.global_position, worker.global_position) <= GUARD_REACHED
			if second.state != Crew3D.State.PATROL and second_reacted == "":
				second_reacted = "state %d at %.1f s" % [second.state, t]
			if t >= 70.0:
				second.free()
				second = null
	print("  bound left: moved %.3f m in %.0f s, Alarm %s; a Guard reached it at %.1f s and was hunting at %.1f s"
			% [moved, BOUND_QUIET, "raised" if alarm.is_raised else "down", reached, hunting])
	_expect(not alarm.is_raised and worker.is_bound() and moved <= HOLD_MOVE,
			"bound left: %.0f s on the Alarm is %s and the Bound Worker moved %.2f m (state %d)"
			% [BOUND_QUIET, "raised" if alarm.is_raised else "down", moved, worker.state])
	_expect(hunting < INF and hunting - reached <= GUARD_HUNTS,
			"bound left: a Guard that reached the Bound Worker at %.1f s was hunting at %.1f s, want within %.0f s" % [reached, hunting, GUARD_HUNTS])
	_expect(worker.reported, "bound left: the Guard did not report the Bound Worker")
	_expect(second_near and second_reacted == "", "bound left: a second Guard passing it (reached it: %s) reacted: %s" % [second_near, second_reacted])


## A Guard on its rounds in Room B, walking up to [param worker].
func _guard_to(worker: Crew3D) -> Crew3D:
	var guard := _armed(load("res://resources/weapons/pistol.tres"))
	guard.layout = hide_layout
	guard.home_room = 1
	guard.global_position = _hide_at(16, 6)
	guard._hold_timer = 1000.0
	guard._glance_timer = 1000.0
	guard._repath_to(worker.global_position)
	guard.set_physics_process(true)
	return guard


## A hidden Worker surrendered to him 3 m off, then left, the Alarm down and
## a panel working: it hides again, comes out 20 s after it last saw him
## (within 1 s) and raises the Alarm at the end of its walk to the panel.
func _check_surrender_left(alarm: ShipAlarm) -> void:
	var worker := await _hidden_worker(Vector2i(HIDE_X0 + 8, 8), _hide_at(10, 2), "surrender left")
	if worker == null:
		return
	var near := _in_sight_of(worker, 3.0)
	_expect(near != Vector3.INF, "surrender left: no open floor 3 m off in its sight")
	if near == Vector3.INF:
		worker.free()
		return
	player.global_position = near
	var t := 0.0
	while t < 1.0 and worker.state != Crew3D.State.SURRENDER:
		await physics_frame
		t += STEP
	_expect(worker.state == Crew3D.State.SURRENDER, "surrender left: him 3 m off in its sight, the Worker did not surrender")
	player.global_position = Vector3(-500, 0, -500)
	var last_seen := t
	var out := INF
	var hid_again := false
	while t < 120.0 and not alarm.is_raised:
		await physics_frame
		t += STEP
		if worker._can_see:
			last_seen = t
		hid_again = hid_again or worker.state == Crew3D.State.COWER
		if out == INF and worker.state == Crew3D.State.REPORT:
			out = t
	print("  surrender left: last saw him at %.2f s, came out at %.2f s, raised the Alarm at %.1f s (a %.1f s walk)"
			% [last_seen, out, t, t - out])
	_expect(hid_again and absf(out - last_seen - LEAVE_AFTER) <= LEAVE_TOLERANCE,
			"surrender left: came out %.2f s after it last saw him (hid again: %s), want %.0f s within %.0f"
			% [out - last_seen, hid_again, LEAVE_AFTER, LEAVE_TOLERANCE])
	var panel: AlarmPanel = get_first_node_in_group(&"alarm_panels")
	_expect(alarm.is_raised and _flat(worker.global_position, panel.use_at) < 1.5,
			"surrender left: the Alarm %s at the end of its walk, the Worker %.1f m from the panel"
			% ["raised" if alarm.is_raised else "not raised", _flat(worker.global_position, panel.use_at)])
	worker.free()


## With the Alarm up: a hidden Worker, him 8 m off in its sight with his
## crosshair 20 degrees off it for 1 s, does not surrender; his crosshair
## on it, it surrenders 0.5 s after it settled, within 0.1 s.
func _check_surrender_aimed(alarm: ShipAlarm) -> void:
	_expect(alarm.is_raised, "surrender aimed: the Alarm is not up for the aimed check")
	var worker := await _hidden_worker(Vector2i(HIDE_X0 + 8, 8), _hide_at(10, 2), "surrender aimed")
	if worker == null:
		return
	var at := _in_sight_of(worker, AIMED_FROM)
	_expect(at != Vector3.INF, "surrender aimed: no open floor 8 m off in its sight")
	if at == Vector3.INF:
		worker.free()
		return
	player.global_position = at
	_aim_pirate(_chest(worker))
	player.rotation.y += deg_to_rad(AIM_OFF)
	var off_aimed := 0.0
	for i in 60:
		await physics_frame
		off_aimed = maxf(off_aimed, worker.aimed_for)
	_expect(worker.state == Crew3D.State.COWER and off_aimed == 0.0 and worker._can_see,
			"surrender aimed: his crosshair 20 degrees off it, the Worker is in state %d (aimed for %.2f s)" % [worker.state, off_aimed])
	_aim_pirate(_chest(worker))
	_expect(player.crosshair_on(worker, 10.0), "surrender aimed: his crosshair is not on the Worker's chest")
	var t := 0.0
	while t < 2.0 and worker.state != Crew3D.State.SURRENDER:
		await physics_frame
		t += STEP
	print("  surrender aimed: surrendered %.3f s after his crosshair settled on it from %.0f m, Alarm up" % [t, AIMED_FROM])
	_expect(absf(t - AIM_SETTLE) <= AIM_TOLERANCE, "surrender aimed: surrendered %.2f s after his crosshair settled, want %.1f within %.1f"
			% [t, AIM_SETTLE, AIM_TOLERANCE])
	worker.free()
	_level_pirate()
	player.global_position = Vector3(-500, 0, -500)


## By the Door between Rooms A and B, a surrendered Worker 1.4 m to his
## side: facing the Door, the interact key works the Door and ties nobody
## up; facing the Worker, it starts tying it up and leaves the Door be.
func _check_bind_or_door() -> void:
	var door: Door3D = get_nodes_in_group(&"doors").filter(func(d: Node) -> bool: return hide_ship.is_ancestor_of(d))[0]
	var worker := _hide_worker(Vector2i(HIDE_X0 + 11, 3))
	player.global_position = door.global_position + Vector3(-1.0, 0.0, 0.0)
	player.global_position.y = 0.0
	worker.global_position = player.global_position + Vector3(0.0, 0.0, -1.4)
	worker.perception.awareness = 1.0
	worker._enter(Crew3D.State.SURRENDER)
	worker.set_physics_process(true)
	_aim_pirate(door.global_position + Vector3.UP * 1.5)
	player.set_physics_process(true)
	for i in 3:
		await physics_frame
	var was_open := door.is_open
	_expect(door.in_reach_of(player) and player.bind_target() == null and player.can_interact(),
			"bind or door: facing the Door in its reach, the surrendered Worker beside him takes the key")
	Input.action_press("interact")
	await physics_frame
	Input.action_release("interact")
	await physics_frame
	_expect(door.is_open != was_open and not player.is_binding(),
			"bind or door: facing the Door, the key did not work it (open %s, was %s) or started tying up" % [door.is_open, was_open])
	if door.is_open:
		door.close()
	for i in 30:
		await physics_frame
	was_open = door.is_open
	_aim_pirate(_chest(worker))
	await physics_frame
	_expect(player.bind_target() == worker and not player.can_interact(),
			"bind or door: facing the surrendered Worker beside a Door, it is not his to tie up")
	Input.action_press("interact")
	await physics_frame
	await physics_frame
	_expect(player.is_binding() and door.is_open == was_open,
			"bind or door: facing the Worker, the key worked the Door (open %s, was %s) or did not start tying up" % [door.is_open, was_open])
	Input.action_release("interact")
	await physics_frame
	player.set_physics_process(false)
	worker.free()
	_level_pirate()
	player.global_position = Vector3(-500, 0, -500)


# --- Workers' poses (crew-combat ticket 25) -------------------------------------

## Workers whose pose sets are rolled, across generated medium and large
## ships from seed 1 up; each pose of a pair is rolled by this share of
## them.
const POSE_WORKERS := 400
const POSE_SHARE := Vector2(0.4, 0.6)
## A hiding Worker faces within this of straight away from the wall or prop
## behind it (looked for within FACING_REACH, at the seat's height), once
## on its tile this long.
const FACING_WITHIN := 30.0
const FACING_REACH := 1.0
const FACING_AFTER := 1.0
## At a gunshot a crouched hiding Worker's head is at least DUCK_DROP lower
## within DUCK_WITHIN, and back within DUCK_BACK_NEAR of where it was
## within DUCK_BACK.
const DUCK_DROP := 0.1
const DUCK_WITHIN := 0.3
const DUCK_BACK := 1.5
const DUCK_BACK_NEAR := 0.02
## In every pose the head zone is within this of the head bone.
const HEAD_ZONE_NEAR := 0.15
## Seconds for a pose to blend in before it is measured.
const POSE_SETTLE := 0.7


## The tile a Worker posted [param n]th in [param room] spawns on, as
## [ShipBuilder3D.build] places it.
static func _spawn_tile(room: RoomData, n: int) -> Vector2i:
	if n < room.crew_spawns.size():
		return room.crew_spawns[n]
	return ShipBuilder3D.world_to_tile(ShipBuilder3D.crew_spawn_position(room, n))


## Every Worker's pose set on [param ship_layout], in posting order, rolled
## as a Worker spawned there rolls it.
static func _rolled_sets(ship_layout: ShipLayout) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for room in ship_layout.rooms:
		for n in room.crew_count:
			if CrewTypes.for_role(room.role, n) == CrewTypes.Type.WORKER:
				out.append(CrewPose.roll_set(ship_layout.gen_seed, _spawn_tile(room, n)))
	return out


## Over 400 Workers of generated ships (medium and large in turn,
## seeds from 1), each pose of each pair rolled by 40 to 60% of them; the
## same ship generated again gives every Worker the same set. (Each built
## Worker's set is the one rolled here: `_check_workers_in_fight`.)
func _check_pose_roll() -> void:
	var counts := {}
	var workers := 0
	var ships := 0
	var differ: Array[String] = []
	var classes: Array[StringName] = [&"medium", &"large"]
	while workers < POSE_WORKERS:
		var ship_class := classes[ships % classes.size()]
		var ship_seed := ships + 1
		var sets := _rolled_sets(ShipGenerator.generate(ship_class, ship_seed))
		if ships < 6 and sets != _rolled_sets(ShipGenerator.generate(ship_class, ship_seed)):
			differ.append("%s seed %d" % [ship_class, ship_seed])
		for set in sets:
			for pair: String in set:
				counts[set[pair]] = counts.get(set[pair], 0) + 1
		workers += sets.size()
		ships += 1
	var off: Array[String] = []
	var shares: Array[String] = []
	for pair: String in CrewPose.PAIRS:
		for pose: String in CrewPose.PAIRS[pair]:
			var share := float(counts.get(pose, 0)) / workers
			shares.append("%s %.0f%%" % [pose, share * 100.0])
			if share < POSE_SHARE.x or share > POSE_SHARE.y:
				off.append("%s %d of %d" % [pose, counts.get(pose, 0), workers])
	print("  pose roll: %d Workers on %d ships: %s" % [workers, ships, ", ".join(shares)])
	_expect(off.is_empty(), "pose roll: over %d Workers, poses rolled outside %.0f to %.0f%% of their pair: %s"
			% [workers, POSE_SHARE.x * 100.0, POSE_SHARE.y * 100.0, off])
	_expect(differ.is_empty(), "pose roll: the same ship generated again rolled different pose sets: %s" % [differ])


## The way straight out from the walls and props round [param worker]: the
## flat ways to each one within FACING_REACH (16 rays at the seat's height),
## summed and turned round. Zero with none, or with them all round it.
func _away_from_walls(worker: Crew3D) -> Vector3:
	var space := worker.get_world_3d().direct_space_state
	var from := worker.global_position + Vector3.UP * Crew3D.SEAT_HEIGHT
	var sum := Vector3.ZERO
	for k in 16:
		var way := Vector3.FORWARD.rotated(Vector3.UP, TAU * k / 16.0)
		if not space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + way * FACING_REACH, Crew3D.WORLD_LAYER)).is_empty():
			sum += way
	return Vector3.ZERO if sum.length() < 0.5 else -sum.normalized()


## A wall or prop on a side of the tile under [param at] with open floor
## on the side across from it: something to put its back to.
func _has_back(ship_layout: ShipLayout, at: Vector3) -> bool:
	var astar := CrewPaths.grid(ship_layout)
	var t := ShipBuilder3D.world_to_tile(at)
	var solid := func(side: Vector2i) -> bool:
		return not astar.is_in_boundsv(t + side) or astar.is_point_solid(t + side)
	for side: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		if solid.call(side) and not solid.call(-side):
			return true
	return false


## Degrees between [param worker]'s facing and straight away from the walls
## and props round it (behind it, if it faces right); INF with none near.
func _facing_off(worker: Crew3D) -> float:
	var away := _away_from_walls(worker)
	if away == Vector3.ZERO:
		return INF
	return rad_to_deg(worker.facing().angle_to(away))


## The head bone, the head zone and the capsule's top of [param worker] as
## last posed, kept up to date in `skeleton_updated` (after every modifier):
## {"bone", "zone"} world points and "top" metres.
func _watch_head(worker: Crew3D) -> Dictionary:
	var seen := {"bone": Vector3.INF, "zone": Vector3.INF, "top": INF}
	var sk := worker.pose.get_skeleton()
	var shape: CollisionShape3D = worker.get_node("CollisionShape3D")
	sk.skeleton_updated.connect(func() -> void:
		if not is_instance_valid(worker):
			return
		seen.bone = (sk.global_transform * sk.get_bone_global_pose(sk.find_bone(&"Head"))).origin
		seen.zone = worker.head_zone.global_position
		seen.top = shape.global_position.y + (shape.shape as CapsuleShape3D).height / 2.0)
	return seen


## [param worker] in pose [param name], settled: the head zone within
## HEAD_ZONE_NEAR of its head bone, the capsule's top no higher than the
## middle of its head (the head zone's centre). Returns the measured line.
func _pose_fits(worker: Crew3D, head: Dictionary, name: String) -> String:
	var shown := worker.pose.shown
	var near: float = (head.zone as Vector3).distance_to(head.bone)
	var top: float = head.top
	var line := "%s: head zone %.3f m off the bone, centre %.3f m, capsule top %.3f m" % [name, near, (head.zone as Vector3).y, top]
	_expect(shown == name, "worker poses: want %s, it shows %s (state %d, %s)" % [name, shown, worker.state, Crew3D.SURRENDER_NAMES[worker.surrender]])
	_expect(near <= HEAD_ZONE_NEAR, "worker poses: %s, the head zone is %.3f m off the head bone, want within %.2f" % [name, near, HEAD_ZONE_NEAR])
	_expect(top <= (head.zone as Vector3).y, "worker poses: %s, the capsule's top %.3f m is over the middle of its head at %.3f m" % [name, top, (head.zone as Vector3).y])
	return line


func _wait(seconds: float) -> void:
	for i in roundi(seconds / STEP):
		await physics_frame


## A Worker on the hiding rig through every pose, both of each pair: hidden
## crouched (facing away from the wall behind it), ducking at a gunshot and
## back, sat; surrendered to him 3 m off, hands by its head and straight up;
## kneeling upright and on its heels; Bound sat against the corner's wall
## and kneeling. In each, its head zone on its head bone and its capsule
## under its head. Then a Worker Bound with no wall within 1 m kneels.
func _check_worker_poses() -> void:
	_fresh_world()
	_build_hide_rig()
	for i in 2:
		await physics_frame
	var worker := await _hidden_worker(Vector2i(HIDE_X0 + 8, 8), _hide_at(10, 2), "worker poses")
	if worker == null:
		return
	worker.pose_set = {"hide": "hide", "hands": "hands_up", "kneel": "kneel", "bound": "bound_sat"}
	var head := _watch_head(worker)
	await _wait(POSE_SETTLE + FACING_AFTER)
	var lines: Array[String] = []
	var off := _facing_off(worker)
	lines.append("hidden facing %.1f deg off straight out from the wall" % off)
	_expect(off <= FACING_WITHIN, "worker poses: hidden, it faces %.1f degrees off straight away from the wall behind it, want within %.0f" % [off, FACING_WITHIN])
	lines.append(_pose_fits(worker, head, "hide"))

	# A gunshot in its Room: it ducks, then comes back up.
	var before: float = (head.bone as Vector3).y
	CrewNoise.make(self, _hide_at(6, 6), CrewNoise.Kind.GUNSHOT, 30.0, player)
	var t := 0.0
	var lowest := before
	var down_at := INF
	var back_at := INF
	var ducked := ""
	while t < DUCK_BACK + 0.5:
		await physics_frame
		t += STEP
		var y: float = (head.bone as Vector3).y
		if t <= DUCK_WITHIN:
			lowest = minf(lowest, y)
		if down_at == INF and before - y >= DUCK_DROP:
			down_at = t
		if down_at < INF and back_at == INF and absf(y - before) <= DUCK_BACK_NEAR:
			back_at = t
		if ducked == "" and t >= 0.35 and worker.pose.shown == "hide_flinch":
			ducked = _pose_fits(worker, head, "hide_flinch")
	lines.append(ducked)
	print("  worker poses: a gunshot: head %.3f m, lowest %.3f m within %.1f s (%.3f m lower at %.2f s), back within %.2f m at %.2f s"
			% [before, lowest, DUCK_WITHIN, before - lowest, down_at, DUCK_BACK_NEAR, back_at])
	_expect(before - lowest >= DUCK_DROP, "worker poses: at a gunshot its head went %.3f m lower within %.1f s, want at least %.1f"
			% [before - lowest, DUCK_WITHIN, DUCK_DROP])
	_expect(back_at <= DUCK_BACK, "worker poses: after the gunshot its head was back within %.2f m at %.2f s, want within %.1f s"
			% [DUCK_BACK_NEAR, back_at, DUCK_BACK])
	_expect(ducked != "", "worker poses: it never showed hide_flinch after the gunshot")

	worker.pose_set.hide = "hide_sat"
	await _wait(POSE_SETTLE)
	lines.append(_pose_fits(worker, head, "hide_sat"))

	# Surrendered to him 3 m off: hands up, then kneeling.
	var near := _in_sight_of(worker, 3.0)
	_expect(near != Vector3.INF, "worker poses: no open floor 3 m off in its sight")
	if near != Vector3.INF:
		player.global_position = near
		t = 0.0
		while t < 1.0 and worker.state != Crew3D.State.SURRENDER:
			await physics_frame
			t += STEP
		await _wait(0.6)
		lines.append(_pose_fits(worker, head, "hands_up"))
		worker.pose_set.hands = "hands_high"
		await _wait(0.6)
		lines.append(_pose_fits(worker, head, "hands_high"))
		while t < 5.0 and worker.surrender != Crew3D.Surrender.KNEELING:
			await physics_frame
			t += STEP
		await _wait(POSE_SETTLE)
		lines.append(_pose_fits(worker, head, "kneel"))
		worker.pose_set.kneel = "kneel_low"
		await _wait(POSE_SETTLE)
		lines.append(_pose_fits(worker, head, "kneel_low"))
		# Bound: sat against the nearest wall of its corner.
		worker.bind()
		await _wait(POSE_SETTLE)
		var wall := worker.wall_behind(worker.facing(), 2.0)
		lines.append("Bound sat %.3f m from the wall behind it" % wall)
		_expect(worker.bound_against != Vector3.ZERO and absf(wall - Crew3D.BOUND_STANDOFF) <= 0.02,
				"worker poses: Bound sat in a corner, its body is %.3f m from the wall behind it, want %.2f" % [wall, Crew3D.BOUND_STANDOFF])
		lines.append(_pose_fits(worker, head, "bound_sat"))
		worker.pose_set.bound = "bound_kneel"
		await _wait(POSE_SETTLE)
		lines.append(_pose_fits(worker, head, "bound_kneel"))
	for line in lines:
		print("  worker poses: " + line)
	worker.free()

	# Bound with its sat pose, no wall or prop within 1 m: it kneels.
	var open := _hide_worker(Vector2i(HIDE_X0 + 8, 3))
	open.pose_set = {"hide": "hide", "hands": "hands_up", "kneel": "kneel", "bound": "bound_sat"}
	open._enter(Crew3D.State.SURRENDER)
	open.bind()
	_expect(open.is_bound() and open.bound_against == Vector3.ZERO and CrewPose.worker_pose(open) == "bound_kneel",
			"worker poses: Bound in the open with its sat pose, it shows %s (wall %s)" % [CrewPose.worker_pose(open), open.bound_against])
	open.free()
	player.global_position = Vector3(-500, 0, -500)
	_level_pirate()
