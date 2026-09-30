extends SceneTree
## Headless checks on ship layouts and the 3D geometry ShipBuilder3D makes from
## them, plus the FPS gameplay that stands on it.
##
##   flatpak run org.godotengine.Godot --headless --path . --script res://tests/test_ship_3d.gd

const UP := Vector3.UP

var failures: Array[String] = []
var checks := 0

var main: Node3D
var player: CharacterBody3D
var floors: Dictionary
var directions := [
	Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, -1), Vector3(0, 0, 1),
	Vector3(1, 0, 1).normalized(), Vector3(-1, 0, 1).normalized(),
	Vector3(1, 0, -1).normalized(), Vector3(-1, 0, -1).normalized(),
]
var dir_index := 0
var built_layout: ShipLayout
var geometry_checked := false
var smoke_checked := false
var phase := 0
var locked_push := Vector3.ZERO
var locked_to := -1
var test_door: Door3D
var test_door_data: DoorData
var shot: Projectile3D
var shot_start := Vector3.ZERO
var shot_last := Vector3.ZERO
var gunman: Crew3D
var bystander: Crew3D
var frames := 0
var escapes := 0
## The room the pirate boards into: behind the hatch the main scene chose.
var boarding_room := -1
var hatch_leaf: Door3D
var hatch_push := Vector3.ZERO
var hatch_room := -1
var built_sample: BuiltSampleChecks


func _initialize() -> void:
	RoomDataChecks.run(_expect)

	var layout := PlayerShipLayout.create()
	_check_rooms_disjoint(layout)
	_check_rooms_fightable(layout)
	_check_ship_name(layout)
	# The corridor rule needs a corridor Room, which the pirate ship lacks.
	var with_corridor := RoomDataChecks.corridor_layout()
	_check_rooms_disjoint(with_corridor)
	_check_rooms_fightable(with_corridor)
	_check_doors(with_corridor)
	_check_hatches(with_corridor)
	_check_connectivity(with_corridor)
	_check_doors(layout)
	_check_hatches(layout)
	_check_connectivity(layout)

	main = load("res://scenes/main_3d.tscn").instantiate()
	# The reveal machinery stays under test even while the game runs fully lit.
	main.explore_darkness = true
	root.add_child(main)
	player = main.get_node("Player")
	player.set_physics_process(false)
	floors = layout.floor_tiles()
	built_layout = layout


func _physics_process(_delta: float) -> bool:
	# The scene's _ready runs after _initialize returns, so the built geometry is
	# only there to inspect once the first physics frame comes round.
	if not geometry_checked:
		geometry_checked = true
		built_layout = main.layout
		floors = built_layout.floor_tiles()
		boarding_room = built_layout.hatches[main.entry_hatch].room
		_check_boarding(built_layout)
		_check_built_geometry(built_layout)
		# Needs a live tree for global positions and tweens.
		TwoRectRoomChecks.run(_expect, root)
		GeneratedShipChecks.run(_expect, root)
		return false
	if not smoke_checked:
		# GridMap physics comes live one frame after the scene enters the tree,
		# so the collision smoke test waits for the second frame.
		smoke_checked = true
		_check_physics_smoke()
		return false

	if phase == 7:
		if built_sample.tick():
			_finish()
		return false
	if phase == 6:
		_physics_hatch_walk()
		return false
	if phase == 5:
		_physics_crew()
		return false
	if phase == 4:
		_physics_shooting()
		return false
	if phase == 3:
		_physics_ammo()
		return false
	if phase == 2:
		_physics_open_door()
		return false
	if phase == 1:
		_physics_locked_door()
		return false

	# Shove the player hard in every direction; his centre must never leave the floor.
	player.velocity = directions[dir_index] * 10.0
	player.move_and_slide()
	if not floors.has(ShipBuilder3D.world_to_tile(player.global_position)):
		escapes += 1
	frames += 1
	if frames >= 150:
		frames = 0
		dir_index += 1
		if dir_index >= directions.size():
			_expect(escapes == 0, "player escaped the hull on %d physics frames" % escapes)
			_begin_open_door_phase()
	return false


## Sanity that 3D physics is really live under --headless: the floor holds a
## ray, the wall holds a ray, and the reveal reacted to the walk above.
func _check_physics_smoke() -> void:
	var center := ShipBuilder3D.room_center_world(built_layout.rooms[boarding_room])
	var floor_map: GridMap = main.get_node("Ship/Floor")
	var space: PhysicsDirectSpaceState3D = floor_map.get_world_3d().direct_space_state

	var down := PhysicsRayQueryParameters3D.create(center + UP * 1.0, center - UP * 1.0, 1)
	var floor_hit: Dictionary = space.intersect_ray(down)
	_expect(not floor_hit.is_empty(), "no floor collision under the entry room centre")
	if not floor_hit.is_empty():
		_expect(absf(floor_hit.position.y) < 0.05,
				"floor surface sits at y %.3f, expected 0" % floor_hit.position.y)

	var box := built_layout.rooms[boarding_room].bounds()
	var outside := ShipBuilder3D.tile_to_world(Vector2i(box.position.x - 3, box.position.y))
	var across := PhysicsRayQueryParameters3D.create(center + UP * 0.9,
			Vector3(outside.x, 0.9, center.z), 1)
	_expect(not space.intersect_ray(across).is_empty(),
			"a ray out through the hull wall hit nothing")

	# The ceiling sits a full room height up. Rooms were 2.5 m until the
	# movement spec raised them to 3.5, pinned in _check_built_geometry.
	var up_ray := PhysicsRayQueryParameters3D.create(center + UP * 1.0, center + UP * 6.0, 1)
	var ceiling_hit: Dictionary = space.intersect_ray(up_ray)
	_expect(not ceiling_hit.is_empty(), "no ceiling collision over the entry room centre")
	if not ceiling_hit.is_empty():
		_expect(absf(ceiling_hit.position.y - ShipBuilder3D.WALL_HEIGHT) < 0.05,
				"ceiling surface sits at y %.3f, expected %.1f" % [ceiling_hit.position.y, ShipBuilder3D.WALL_HEIGHT])
	_check_standing_room_on_crate(space)


## The pirate's own capsule, stood on one of the ship's real crates, must not
## touch the ceiling: the reason the rooms grew. Sizes come from the scenes,
## so a resized crate or pirate is caught here too.
func _check_standing_room_on_crate(space: PhysicsDirectSpaceState3D) -> void:
	var crate: StaticBody3D
	for prop in main.get_node("Ship/Props").get_children():
		if prop.name.begins_with("PropCrate"):
			crate = prop
			break
	_expect(crate != null, "the pirate ship placed no crate to stand on")
	if crate == null:
		return
	var crate_box: BoxShape3D = crate.get_node("CollisionShape3D").shape
	var crate_top: float = crate.global_position.y + crate_box.size.y
	var capsule: CapsuleShape3D = player.get_node("CollisionShape3D").shape
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = capsule
	query.collision_mask = 1
	# Centre the capsule so its feet rest a hair above the crate top.
	var centre := crate.global_position + UP * (crate_box.size.y + capsule.height / 2.0 + 0.01)
	query.transform = Transform3D(Basis.IDENTITY, centre)
	query.exclude = [crate.get_rid()]
	var blocked: Array[String] = []
	for hit in space.intersect_shape(query, 8):
		blocked.append(str(hit.collider.name))
	_expect(blocked.is_empty(),
			"a %.1f m pirate standing on the %.1f m crate at %s intersects %s" % [capsule.height, crate_top, crate.global_position, blocked])

## Stand him next to an unlocked door; it should notice him and open.
func _begin_open_door_phase() -> void:
	# The sweep dragged him through several rooms; the darkness should have
	# lifted off them.
	var reveal: RoomReveal = main.get_node("Ship/Reveal")
	var seen := 0
	for i in built_layout.rooms.size():
		if reveal.is_revealed(i):
			seen += 1
	_expect(seen > 1, "only %d room revealed after walking the whole ship" % seen)

	# Crew visibility follows the room they are stood in: seen where the pirate
	# has been, hidden where he has not.
	for member in main.get_node("Ship/Crew").get_children():
		var room := built_layout.room_at(ShipBuilder3D.world_to_tile(member.global_position))
		if room == -1:
			continue
		if reveal.is_revealed(room):
			_expect(member.visible, "crew in revealed room %d is invisible" % room)
		else:
			_expect(not member.visible, "crew in unexplored room %d is visible" % room)

	var doors: Node3D = main.get_node("Ship/Doors")
	for i in built_layout.doors.size():
		if not built_layout.doors[i].locked:
			test_door = doors.get_child(i)
			test_door_data = built_layout.doors[i]
			break
	if test_door == null:
		_begin_locked_door_phase()
		return
	# Straight back from the threshold on the room_a side: close enough to reach
	# the controls, far enough that his collider is clear of the doorway itself.
	var from := ShipBuilder3D.room_center_world(built_layout.rooms[test_door_data.room_a])
	var door_pos := ShipBuilder3D.door_center_world(test_door_data)
	var across := Vector3(0, 0, 1) if test_door_data.horizontal else Vector3(1, 0, 0)
	var side := signf((from - door_pos).dot(across))
	player.global_position = door_pos + across * (side if side != 0.0 else 1.0) * 1.4
	player.velocity = Vector3.ZERO
	phase = 2
	frames = 0


## Walks the interact key through a full open/close cycle on one door.
func _physics_open_door() -> void:
	player.move_and_slide()
	frames += 1
	match frames:
		5:
			_expect(test_door.in_reach(), "door did not notice the player standing next to it")
			_expect(test_door.close(), "door would not shut with nobody in the doorway")
		7:
			_expect(not test_door.is_open, "door is still open after being shut")
			_expect(test_door.prompt_text() == "E — Open hatch",
					"shut door offers '%s'" % test_door.prompt_text())
		8:
			Input.action_press("interact")
		9:
			Input.action_release("interact")
		14:
			_expect(test_door.is_open, "pressing interact did not open the door")
		15:
			Input.action_press("interact")
		16:
			Input.action_release("interact")
		21:
			_expect(not test_door.is_open, "pressing interact again did not shut the door")
			_begin_locked_door_phase()


## Park him in the medbay and shove him at the locked interior door.
func _begin_locked_door_phase() -> void:
	var locked_door: DoorData = null
	for d in built_layout.doors:
		if d.locked:
			locked_door = d
			break
	if locked_door == null:
		_finish()
		return
	locked_to = locked_door.room_b
	player.global_position = ShipBuilder3D.room_center_world(built_layout.rooms[locked_door.room_a])
	player.velocity = Vector3.ZERO
	var toward := ShipBuilder3D.room_center_world(built_layout.rooms[locked_to]) - player.global_position
	toward.y = 0.0
	locked_push = toward.normalized()
	phase = 1
	frames = 0


func _physics_locked_door() -> void:
	player.velocity = locked_push * 10.0
	player.move_and_slide()
	frames += 1
	if frames >= 240:
		var room := built_layout.room_at(ShipBuilder3D.world_to_tile(player.global_position))
		_expect(room != locked_to,
				"player walked through a locked door into room %d" % locked_to)
		_begin_ammo_phase()


## The magazine and the reload lockout, checked before live fire.
func _begin_ammo_phase() -> void:
	var room: RoomData = built_layout.rooms[boarding_room]
	player.global_position = ShipBuilder3D.room_center_world(room)
	player.velocity = Vector3.ZERO
	# The reload timer ticks in the player's own physics loop.
	player.set_physics_process(true)
	_expect(player.ammo == player.weapon.magazine_size, "pirate did not start with a full magazine")
	player.start_reload()
	_expect(not player.is_reloading(), "reloading a full magazine should be refused")
	phase = 3
	frames = 0


func _physics_ammo() -> void:
	frames += 1
	match frames:
		2:
			var first: Projectile3D = player.fire()
			_expect(first != null, "the pirate did not fire")
			_expect(player.ammo == player.weapon.magazine_size - 1,
					"one shot left the magazine at %d" % player.ammo)
			_expect(player.fire() == null, "fired a second shot while still on cooldown")
			if first != null:
				first.queue_free()
			player.start_reload()
			_expect(player.is_reloading(), "reload did not start")
			_expect(player.fire() == null, "fired mid-reload")
		80:
			# A tactical reload of 1.2 s is 72 frames; well past it the magazine is full.
			_expect(not player.is_reloading(), "still reloading after %d frames" % frames)
			_expect(player.ammo == player.weapon.magazine_size, "reload did not refill the magazine")
			_begin_shooting_phase()


## Stand in the middle of the cargo hold and shoot at the far wall.
func _begin_shooting_phase() -> void:
	var room: RoomData = built_layout.rooms[boarding_room]
	player.set_physics_process(false)
	player.global_position = ShipBuilder3D.room_center_world(room)
	player.velocity = Vector3.ZERO
	# Face -X: the crosshair ray and the bolt both leave along the view axis.
	player.rotation = Vector3(0.0, PI / 2.0, 0.0)
	player.head.rotation = Vector3.ZERO

	var aim: Vector3 = player.aim_point()
	_expect(aim.x < player.global_position.x,
			"aiming down -X found a point at %s" % aim)

	shot = player.fire()
	_expect(shot != null, "the pirate did not fire")
	if shot == null:
		_finish()
		return
	_expect(shot.get_parent() == main.get_node("Projectiles"),
			"shot was parented to %s, not the projectile container" % shot.get_parent())
	_expect(shot.direction.x < -0.9,
			"shot flies %s, expected roughly -X" % shot.direction)
	shot_start = shot.global_position
	shot_last = shot_start
	phase = 4
	frames = 0


func _physics_shooting() -> void:
	frames += 1
	if is_instance_valid(shot):
		shot_last = shot.global_position
		if frames > 120:
			_expect(false, "shot never hit the hull; stopped tracking at %s" % shot_last)
			_finish()
		return

	# Gone: it struck something. The cargo hold's left wall spans x -1..0.
	_expect(frames > 1, "shot died on its first frame, probably on the shooter")
	_expect(shot_last.x < shot_start.x, "shot travelled the wrong way")
	_expect(shot_last.x < 1.0 and shot_last.x > -1.0,
			"shot stopped at x %.2f, not against the hull" % shot_last.x)
	_begin_crew_phase()


## Put a live hostile in the room with the pirate and let them fight.
func _begin_crew_phase() -> void:
	for stray in main.get_node("Projectiles").get_children():
		stray.free()

	var room: RoomData = built_layout.rooms[boarding_room]
	player.global_position = ShipBuilder3D.room_center_world(room)
	player.velocity = Vector3.ZERO
	player.health.reset()

	var crew_scene: PackedScene = load("res://scenes/crew_3d.tscn")
	var holder: Node3D = main.get_node("Ship/Crew")

	gunman = crew_scene.instantiate()
	gunman.layout = built_layout
	gunman.home_room = boarding_room
	gunman.target = player
	gunman.spread_degrees = 0.0
	gunman.position = player.global_position + Vector3(5.6, 0.0, 0.0)
	holder.add_child(gunman)

	# A second hostile directly in the line of fire, stood down so it holds
	# position: friendly shots must pass straight through it.
	bystander = crew_scene.instantiate()
	bystander.layout = built_layout
	bystander.home_room = boarding_room
	bystander.position = player.global_position + Vector3(2.8, 0.0, 0.0)
	holder.add_child(bystander)
	bystander.set_physics_process(false)

	phase = 5
	frames = 0


func _physics_crew() -> void:
	frames += 1
	match frames:
		30:
			_expect(gunman.state in [Crew3D.State.HUNT, Crew3D.State.FIGHT, Crew3D.State.COVER],
					"crew saw the pirate and stayed on patrol (state %d)" % gunman.state)
		240:
			_expect(player.health.current < player.health.max_health,
					"crew never landed a shot on the pirate")
			_expect(bystander.health.current == bystander.health.max_health,
					"crew shot one of their own")
			_check_cover()
			_check_navigation()
			_check_crew_dies()
			_begin_hatch_phase()


## Out through the boarding hatch into space, then back in: the hull gap is
## real and the pirate can extract by the way he came.
func _begin_hatch_phase() -> void:
	gunman.set_physics_process(false)
	var hatch: HatchData = built_layout.hatches[main.entry_hatch]
	hatch_room = hatch.room
	hatch_leaf = main.get_node("Ship/Hatches").get_child(main.entry_hatch)
	hatch_leaf.open()
	_expect(hatch_leaf.is_open, "the boarding hatch would not open")
	player.global_position = ShipBuilder3D.hatch_entry_world(built_layout, hatch)
	player.velocity = Vector3.ZERO
	var step := hatch.inward(built_layout.rooms[hatch.room])
	hatch_push = Vector3(-step.x, 0.0, -step.y)
	phase = 6
	frames = 0


func _physics_hatch_walk() -> void:
	frames += 1
	# There is no deck outside the hull; hold him at floor height so stepping
	# off the last plate does not drop him against its edge on the way back.
	player.global_position.y = 0.0
	if frames <= 40:
		player.velocity = hatch_push * 4.0
		player.move_and_slide()
		if frames == 40:
			var tile := ShipBuilder3D.world_to_tile(player.global_position)
			_expect(not floors.has(tile), "pirate never left the hull through the open hatch (at %s)" % tile)
		return
	if frames <= 80:
		player.velocity = -hatch_push * 4.0
		player.move_and_slide()
		if frames == 80:
			var tile := ShipBuilder3D.world_to_tile(player.global_position)
			_expect(built_layout.room_at(tile) == hatch_room,
					"pirate walking back in through the hatch landed at %s, not in room %d" % [tile, hatch_room])
			hatch_leaf.close()
			# The generated ships, built and checked a frame at a time.
			built_sample = BuiltSampleChecks.new()
			built_sample.begin(_expect, root)
			phase = 7


## Cover must actually be cover: something solid between it and the target, and
## a clear walk to it.
func _check_cover() -> void:
	# Crates sit around tile (1,27); stand the two of them either side.
	player.global_position = ShipBuilder3D.tile_to_world(Vector2i(1, 26))
	gunman.global_position = ShipBuilder3D.tile_to_world(Vector2i(1, 30))
	gunman._last_seen = player.global_position

	var spot: Vector3 = gunman._find_cover_point()
	_expect(spot != Vector3.INF, "crew could not find cover beside a crate stack")
	if spot == Vector3.INF:
		return
	_expect(gunman._blocked(spot + UP * Crew3D.COVER_HEIGHT,
			player.global_position + UP * Crew3D.TORSO_HEIGHT),
			"the chosen cover at %s is in the open" % spot)
	_expect(not gunman._blocked(gunman.global_position + UP * Crew3D.COVER_HEIGHT,
			spot + UP * Crew3D.COVER_HEIGHT),
			"the chosen cover at %s cannot be walked to" % spot)


## Every way the crew build a path, including standing in a doorway, which
## belongs to no room.
func _check_navigation() -> void:
	var bridge := ShipBuilder3D.room_center_world(built_layout.rooms[0])
	gunman._repath_to(bridge)
	_expect(gunman._path.size() > 0, "crew could not plot a route to the bridge")
	if gunman._path.size() > 0:
		_expect(gunman._path[gunman._path.size() - 1].is_equal_approx(bridge),
				"route ends at %s, not the destination" % gunman._path[gunman._path.size() - 1])

	gunman._path.clear()
	gunman._can_see = false
	gunman._hold_timer = 0.0
	gunman.state = Crew3D.State.PATROL
	gunman._tick_patrol()
	_expect(gunman._path.size() == 1, "patrolling crew did not pick somewhere to walk")

	gunman._last_seen = bridge
	gunman._enter(Crew3D.State.SEARCH)
	_expect(gunman._path.size() > 0, "crew giving up the chase lost its route")

	var doorway := built_layout.doors[0].tile
	_expect(built_layout.room_at(doorway) == -1, "doorway tile unexpectedly belongs to a room")
	gunman.global_position = ShipBuilder3D.tile_to_world(doorway)
	gunman._path.clear()
	gunman._repath_to(bridge)
	_expect(gunman._path.size() > 0, "crew stood in a doorway could not build a route")
	if gunman._path.size() > 0:
		_expect(gunman._path[gunman._path.size() - 1].is_equal_approx(bridge),
				"doorway fallback route does not end at the destination")

	# And with no layout at all it should still walk straight at the target.
	var saved := gunman.layout
	gunman.layout = null
	gunman._path.clear()
	gunman._repath_to(bridge)
	_expect(gunman._path.size() == 1 and gunman._path[0].is_equal_approx(bridge),
			"crew with no layout did not fall back to walking straight there")
	gunman.layout = saved


func _check_crew_dies() -> void:
	var before := gunman.health.current
	_expect(before > 0, "crew was already down before being shot")
	gunman.take_damage(1)
	_expect(gunman.health.current == before - 1, "crew shrugged off a hit")
	gunman.take_damage(gunman.health.max_health)
	_expect(not gunman.is_alive(), "crew survived fatal damage")
	_expect(gunman.state == Crew3D.State.DEAD, "dead crew is not in the dead state")


func _check_rooms_disjoint(layout: ShipLayout) -> void:
	for i in layout.rooms.size():
		for j in range(i + 1, layout.rooms.size()):
			for a in layout.rooms[i].shape():
				for b in layout.rooms[j].shape():
					_expect(not a.intersects(b), "rooms %d and %d overlap (%s / %s)" % [i, j, a, b])
					# Rooms must also not touch, or they would share no wall tile.
					_expect(not a.grow(1).intersects(b), "rooms %d and %d are flush; need a 1-tile wall gap" % [i, j])


## One floor for every Room: [method RoomData.meets_floor]. Non-corridor Rooms
## hold a 10x10 Fight Core and 140 to 260 tiles; corridors are 3 wide throughout.
func _check_rooms_fightable(layout: ShipLayout) -> void:
	for i in layout.rooms.size():
		var room := layout.rooms[i]
		_expect(room.meets_floor(),
				"room %d (%s, %s, %d tiles) fails the fightable floor" % [i, room.role, room.bounds().size, room.area()])


## The stored name is bare; "The" is a display rule.
func _check_ship_name(layout: ShipLayout) -> void:
	_expect(layout.ship_name == "Pirate", "hand-authored ship stores '%s', want 'Pirate'" % layout.ship_name)
	_expect(layout.display_name() == "The Pirate", "hand-authored ship displays as '%s'" % layout.display_name())


func _check_doors(layout: ShipLayout) -> void:
	var floor_set := {}
	for room in layout.rooms:
		floor_set.merge(room.tiles())

	for d in layout.doors:
		_expect(d.room_a >= 0 and d.room_a < layout.rooms.size(), "door has bad room_a %d" % d.room_a)
		_expect(d.room_b >= 0 and d.room_b < layout.rooms.size(), "door has bad room_b %d" % d.room_b)
		_expect(d.width >= 1, "door at %s has width %d" % [d.tile, d.width])
		for tile in d.tiles():
			_expect(not floor_set.has(tile), "doorway tile %s sits on floor, not on a wall" % tile)
			_expect(_on_wall_ring(layout.rooms[d.room_a], tile) and _on_wall_ring(layout.rooms[d.room_b], tile),
					"doorway tile %s is not on the wall shared by rooms %d and %d" % [tile, d.room_a, d.room_b])


## Whether `tile` lies in the one-tile ring around any rect of the room.
func _on_wall_ring(room: RoomData, tile: Vector2i) -> bool:
	for rect in room.shape():
		if rect.grow(1).has_point(tile):
			return true
	return false


func _check_connectivity(layout: ShipLayout) -> void:
	var adjacency := {}
	for i in layout.rooms.size():
		adjacency[i] = []
	for d in layout.doors:
		if d.locked:
			continue  # a locked door must never be the only way into a room
		adjacency[d.room_a].append(d.room_b)
		adjacency[d.room_b].append(d.room_a)

	for hatch in layout.hatches:
		var seen := {hatch.room: true}
		var queue := [hatch.room]
		while not queue.is_empty():
			var room: int = queue.pop_front()
			for neighbour in adjacency[room]:
				if not seen.has(neighbour):
					seen[neighbour] = true
					queue.append(neighbour)
		_expect(seen.size() == layout.rooms.size(),
				"only %d of %d rooms reachable from hatch room %d through unlocked doors" % [seen.size(), layout.rooms.size(), hatch.room])


## Hatches are the ship's boarding points: two to four, exactly one into a
## cargo hold, never on the bridge or engine, each a hull tile that opens into
## exactly one room and can be reached from outside the ship.
func _check_hatches(layout: ShipLayout) -> void:
	_expect(layout.hatches.size() >= 2 and layout.hatches.size() <= 4,
			"ship has %d hatches, want 2 to 4" % layout.hatches.size())
	var cargo_hatches := 0
	var rooms_with_hatch := {}
	var room_floor := {}
	for room in layout.rooms:
		room_floor.merge(room.tiles())
	var floors_all := layout.floor_tiles()
	var walls := ShipBuilder3D.wall_tiles(layout, floors_all)
	var outside := _outside_tiles(floors_all, walls)

	for h in layout.hatches:
		_expect(h.room >= 0 and h.room < layout.rooms.size(), "hatch at %s has bad room %d" % [h.tile, h.room])
		if h.room < 0 or h.room >= layout.rooms.size():
			continue
		var room: RoomData = layout.rooms[h.room]
		_expect(h.width == 2, "hatch at %s is %d wide, want 2" % [h.tile, h.width])
		_expect(room.role != &"bridge" and room.role != &"engine",
				"hatch at %s opens into the %s" % [h.tile, room.role])
		if room.role == &"cargo":
			cargo_hatches += 1
		_expect(not rooms_with_hatch.has(h.room), "room %d holds more than one hatch" % h.room)
		rooms_with_hatch[h.room] = true

		var step := h.inward(room)
		_expect(step != Vector2i.ZERO, "hatch at %s does not face its room %d" % [h.tile, h.room])
		for tile in h.tiles():
			_expect(not room_floor.has(tile), "hatch tile %s sits on floor, not on the hull" % tile)
			_expect(_on_wall_ring(room, tile), "hatch tile %s is not on room %d's wall ring" % [tile, h.room])
			_expect(room.has_tile(tile + step), "hatch tile %s does not open into room %d" % [tile, h.room])
			_expect(layout.room_at(tile - step) == -1,
					"hatch tile %s has a room on both sides; that is a door" % tile)
			_expect(outside.has(tile - step), "hatch tile %s cannot be reached from outside the ship" % tile)
			# Exactly one room on the four sides, or a hatch on a corner would
			# open into two.
			var touching := {}
			for side in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
				var r := layout.room_at(tile + side)
				if r != -1:
					touching[r] = true
			_expect(touching.size() == 1 and touching.has(h.room),
					"hatch tile %s touches rooms %s, want only %d" % [tile, touching.keys(), h.room])
	_expect(cargo_hatches == 1, "%d hatches open into cargo holds, want exactly one" % cargo_hatches)


## Every tile of empty space reachable by flood-fill from outside the ship's
## bounding box. Walls and floor (rooms, doors, hatches) are solid to the fill.
func _outside_tiles(floors_all: Dictionary, walls: Dictionary) -> Dictionary:
	var box := Rect2i()
	var first := true
	for tile in floors_all.keys() + walls.keys():
		if first:
			box = Rect2i(tile, Vector2i.ONE)
			first = false
		else:
			box = box.expand(tile)
	box = box.grow(2)
	var start := box.position
	var seen := {start: true}
	var queue := [start]
	while not queue.is_empty():
		var tile: Vector2i = queue.pop_front()
		for side in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var n: Vector2i = tile + side
			if seen.has(n) or not box.has_point(n) or floors_all.has(n) or walls.has(n):
				continue
			seen[n] = true
			queue.append(n)
	return seen


## The main scene boards through its chosen hatch: the pirate stands just
## inside it, on his own floor, and that room is the one lit.
func _check_boarding(layout: ShipLayout) -> void:
	_expect(main.entry_hatch >= 0 and main.entry_hatch < layout.hatches.size(),
			"main scene boards through hatch %d of %d" % [main.entry_hatch, layout.hatches.size()])
	var hatch: HatchData = layout.hatches[main.entry_hatch]
	var expected := ShipBuilder3D.hatch_entry_world(layout, hatch)
	_expect(player.global_position.is_equal_approx(expected),
			"pirate spawned at %s, expected just inside the hatch at %s" % [player.global_position, expected])
	_expect(player.spawn_point.is_equal_approx(expected), "respawn point is not the boarding hatch")
	var tile := ShipBuilder3D.world_to_tile(player.global_position)
	_expect(layout.room_at(tile) == hatch.room,
			"pirate spawned on tile %s, not in hatch room %d" % [tile, hatch.room])
	var centre := ShipBuilder3D.hatch_center_world(hatch)
	_expect(player.global_position.distance_to(centre) < 2.5,
			"pirate spawned %.1f m from the hatch, not just inside it" % player.global_position.distance_to(centre))


func _check_built_geometry(layout: ShipLayout) -> void:
	var ship: Node3D = main.get_node("Ship")
	var floor_map: GridMap = ship.get_node("Floor")
	var wall_map: GridMap = ship.get_node("Walls")
	var ceiling_map: GridMap = ship.get_node("Ceiling")

	var expected_floor := layout.floor_tiles()
	_expect(floor_map.get_used_cells().size() == expected_floor.size(),
			"placed %d floor cells, expected %d" % [floor_map.get_used_cells().size(), expected_floor.size()])
	_expect(ceiling_map.get_used_cells().size() == expected_floor.size(),
			"placed %d ceiling cells, expected %d" % [ceiling_map.get_used_cells().size(), expected_floor.size()])
	_expect(wall_map.get_used_cells().size() > 0, "no wall cells were placed")

	# No cell may be both floor and wall, or doorways would be blocked.
	var clashes := 0
	for cell: Vector3i in wall_map.get_used_cells():
		if expected_floor.has(Vector2i(cell.x, cell.z)):
			clashes += 1
	_expect(clashes == 0, "%d cells are both floor and wall" % clashes)

	# Walls must fully enclose the floor: every floor tile's neighbours are floor or wall.
	# Walls must fully enclose the floor: every floor tile's neighbours are floor
	# or wall, except a hatch tile, whose outward side is space by design.
	var walls := ShipBuilder3D.wall_tiles(layout, expected_floor)
	var hatch_tiles := {}
	for h in layout.hatches:
		for tile in h.tiles():
			hatch_tiles[tile] = true
	var leaks := 0
	for tile: Vector2i in expected_floor:
		if hatch_tiles.has(tile):
			continue
		for step in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var n: Vector2i = tile + step
			if not expected_floor.has(n) and not walls.has(n):
				leaks += 1
	_expect(leaks == 0, "%d floor tiles open onto empty space" % leaks)
	for tile: Vector2i in hatch_tiles:
		_expect(floor_map.get_cell_item(Vector3i(tile.x, 0, tile.y)) == ShipBuilder3D.ITEM_FLOOR_DOOR,
				"hatch tile %s has no threshold floor" % tile)
		_expect(not walls.has(tile), "hatch tile %s is still walled up" % tile)

	# Every hatch gets a leaf that seals the hull until it is worked.
	var hatches: Node3D = ship.get_node("Hatches")
	_expect(hatches.get_child_count() == layout.hatches.size(),
			"spawned %d hatch leaves, expected %d" % [hatches.get_child_count(), layout.hatches.size()])
	for i in mini(hatches.get_child_count(), layout.hatches.size()):
		var leaf: Door3D = hatches.get_child(i)
		var data: HatchData = layout.hatches[i]
		_expect(leaf.position.is_equal_approx(ShipBuilder3D.hatch_center_world(data)),
				"hatch leaf %d sits at %s, expected %s" % [i, leaf.position, ShipBuilder3D.hatch_center_world(data)])
		var shape: BoxShape3D = leaf.get_node("Blocker/CollisionShape3D").shape
		var along := shape.size.x if data.horizontal else shape.size.z
		_expect(is_equal_approx(along, data.width * ShipBuilder3D.TILE),
				"hatch leaf %d blocks %s m of a %s m gap" % [i, along, data.width * ShipBuilder3D.TILE])
		_expect(not leaf.is_open, "hatch leaf %d starts open" % i)

	var doors: Node3D = ship.get_node("Doors")
	_expect(doors.get_child_count() == layout.doors.size(),
			"spawned %d doors, expected %d" % [doors.get_child_count(), layout.doors.size()])
	for i in mini(doors.get_child_count(), layout.doors.size()):
		var node: Door3D = doors.get_child(i)
		var data: DoorData = layout.doors[i]
		_expect(node.position.is_equal_approx(ShipBuilder3D.door_center_world(data)),
				"door %d sits at %s, expected %s" % [i, node.position, ShipBuilder3D.door_center_world(data)])
		var shape: BoxShape3D = node.get_node("Blocker/CollisionShape3D").shape
		var span := data.width * ShipBuilder3D.TILE
		var along := shape.size.x if data.horizontal else shape.size.z
		_expect(is_equal_approx(along, span),
				"door %d blocks %s m of a %s m doorway" % [i, along, span])
		_expect(is_equal_approx(shape.size.y, ShipBuilder3D.WALL_HEIGHT),
				"door %d is %s m tall in a %s m wall" % [i, shape.size.y, ShipBuilder3D.WALL_HEIGHT])
		_expect(not node.is_open, "door %d starts open" % i)
		if data.locked:
			node.open()
			_expect(not node.is_open, "locked door %d opened anyway" % i)

	var reveal: RoomReveal = ship.get_node("Reveal")
	_expect(reveal.is_revealed(boarding_room), "entry room is still dark")
	for i in layout.rooms.size():
		if i != boarding_room:
			_expect(not reveal.is_revealed(i), "room %d was revealed before being entered" % i)

	var crew_holder: Node3D = ship.get_node("Crew")
	var expected_crew := 0
	for room in layout.rooms:
		expected_crew += room.crew_count
	_expect(crew_holder.get_child_count() == expected_crew,
			"spawned %d crew, expected %d" % [crew_holder.get_child_count(), expected_crew])
	var misplaced := 0
	var visible_in_dark := 0
	for member in crew_holder.get_children():
		var tile := ShipBuilder3D.world_to_tile(member.global_position)
		if not layout.rooms[member.home_room].has_tile(tile):
			misplaced += 1
		_expect(member.layout == layout, "crew was not handed the ship layout")
		# The crew all start in unexplored rooms, so none may be visible yet.
		if member.visible and not reveal.is_revealed(member.home_room):
			visible_in_dark += 1
		# Stand them down for the movement phases below.
		member.set_physics_process(false)
		member.get_node("CollisionShape3D").set_deferred("disabled", true)
	_expect(misplaced == 0, "%d crew spawned outside their own room" % misplaced)
	_expect(visible_in_dark == 0, "%d crew are visible in unexplored rooms" % visible_in_dark)

	# Lights start dark everywhere but the entry room, which has been revealed.
	var lights: Node3D = ship.get_node("Lights")
	_expect(lights.get_child_count() == layout.rooms.size(),
			"built %d room lights, expected %d" % [lights.get_child_count(), layout.rooms.size()])
	# Room lights hang just under the ceiling and follow it when it moves.
	_expect(is_equal_approx(ShipBuilder3D.WALL_HEIGHT, 3.5),
			"rooms are %.1f m tall, expected 3.5" % ShipBuilder3D.WALL_HEIGHT)
	for light: OmniLight3D in lights.get_children():
		_expect(is_equal_approx(light.position.y, ShipBuilder3D.WALL_HEIGHT - 0.3),
				"room light hangs at y %.2f, expected 0.3 m below the %.1f m ceiling" % [light.position.y, ShipBuilder3D.WALL_HEIGHT])

	# Doors do not open on approach, so prop the ship open for the roam below.
	for door_node in doors.get_children():
		door_node.open()

	var hud: Hud = main.get_node("Hud")
	_expect(hud.ship_name_text() == "The Pirate", "HUD names the ship '%s'" % hud.ship_name_text())
	# The main scene hands the HUD the pirate's spread, sights and dry pulls.
	_expect(player.spread_changed.is_connected(hud.set_spread), "main does not feed the HUD the spread")
	_expect(player.ads_changed.is_connected(hud.set_ads), "main does not feed the HUD the sights")
	_expect(player.dry_fired.is_connected(hud.dry_fire), "main does not feed the HUD the dry pull")
	_expect(player.hit_landed.is_connected(hud.flash_hitmarker), "main does not feed the HUD the hits")

	var props: Node3D = ship.get_node("Props")
	var expected_props := 0
	for room in layout.rooms:
		expected_props += room.props.size()
	_expect(props.get_child_count() == expected_props,
			"spawned %d props, expected %d" % [props.get_child_count(), expected_props])


func _finish() -> void:
	_report()
	quit(1 if failures.size() > 0 else 0)


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _report() -> void:
	if failures.is_empty():
		print("PASS  %d checks" % checks)
	else:
		for f in failures:
			print("FAIL  ", f)
		print("FAILED  %d of %d checks" % [failures.size(), checks])
