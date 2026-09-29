class_name GeneratedShipChecks
extends RefCounted
## A generated ship must build and board like the hand-authored one: the
## main scene takes it as an override, drops the pirate just inside the
## chosen Hatch (a different Room for Hatch 0 and Hatch 1), and the crew
## navigator can string a route from the Bridge to an Engine through open
## doorways. Run from the headless 3D suite: `GeneratedShipChecks.run(_expect, root)`.

const CLASS := &"large"
## The first of these seeds whose ship leaves a Room empty is built, so the
## boarding checks below also see the Threat Budget's breathing room.
const SEEDS := [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]
## Seeds per Class whose every Hatch boarding point is checked against the floor.
const BOARDING_SEEDS := 25


static func run(expect: Callable, root: Node) -> void:
	# The main scene boards a generated target when given a seed, the
	# hand-authored ship otherwise.
	var main_script: GDScript = load("res://scripts/main_3d.gd")
	var from_seed: ShipLayout = main_script._layout_from_args(PackedStringArray(["--seed=7", "--class=small"]))
	expect.call(from_seed.gen_seed == 7 and from_seed.ship_class == &"small", "generated: --seed=7 --class=small did not board that target")
	var default_class: ShipLayout = main_script._layout_from_args(PackedStringArray(["--seed=7"]))
	expect.call(default_class.ship_class == &"medium", "generated: --seed alone did not board a medium target")
	expect.call(main_script._layout_from_args(PackedStringArray()).gen_seed == 0, "generated: no seed did not board the hand-authored ship")
	# Every Hatch's boarding point stands on its own Room's floor: behind a
	# Hatch on a ragged Hull the Room can be one tile deep.
	var off_floor := 0
	for ship_class in ShipGenerator.CLASSES:
		for seed in range(1, BOARDING_SEEDS + 1):
			var ship := ShipGenerator.generate(ship_class, seed)
			for hatch in ship.hatches:
				if ship.room_at(ShipBuilder3D.world_to_tile(ShipBuilder3D.hatch_entry_world(ship, hatch))) != hatch.room:
					off_floor += 1
	expect.call(off_floor == 0, "generated: %d boarding points stand off their room's floor" % off_floor)
	var layout: ShipLayout = null
	for seed: int in SEEDS:
		var candidate := ShipGenerator.generate(CLASS, seed)
		if layout == null:
			layout = candidate
		if _has_empty_room(candidate):
			layout = candidate
			break
	expect.call(_has_empty_room(layout), "generated: no large seed in %s leaves a room empty" % [SEEDS])
	var main: Node3D = load("res://scenes/main_3d.tscn").instantiate()
	main.layout_override = layout
	main.explore_darkness = false
	root.add_child(main)

	var player: CharacterBody3D = main.get_node("Player")
	expect.call(layout.hatches.size() >= 2, "generated: ship has %d hatches" % layout.hatches.size())
	# The HUD shows "The Rusty Hauler" for an unprefixed name and a
	# prefixed one ("ISV Kestrel") unchanged.
	var hud: Hud = main.get_node("Hud")
	expect.call(hud.ship_name_text() == layout.display_name(),
			"generated: HUD names the ship '%s', layout displays '%s'" % [hud.ship_name_text(), layout.display_name()])
	var prefixed := layout.ship_name.get_slice(" ", 0) in ShipNamer.prefixes()
	expect.call(hud.ship_name_text() == (layout.ship_name if prefixed else "The " + layout.ship_name),
			"generated: HUD shows '%s' for stored name '%s'" % [hud.ship_name_text(), layout.ship_name])
	# Both literal cases through the same path the main scene uses.
	var sample := ShipLayout.new()
	sample.ship_name = "Rusty Hauler"
	hud.set_ship_name(sample.display_name())
	expect.call(hud.ship_name_text() == "The Rusty Hauler", "HUD shows '%s' for 'Rusty Hauler'" % hud.ship_name_text())
	sample.ship_name = "ISV Kestrel"
	hud.set_ship_name(sample.display_name())
	expect.call(hud.ship_name_text() == "ISV Kestrel", "HUD shows '%s' for 'ISV Kestrel'" % hud.ship_name_text())
	hud.set_ship_name(layout.display_name())
	var first := layout.room_at(ShipBuilder3D.world_to_tile(player.global_position))
	expect.call(layout.hatches.size() > 0 and first == layout.hatches[0].room,
			"generated: pirate boarded into room %d, expected hatch 0's room" % first)
	expect.call(main.get_node("Ship/Hatches").get_child_count() == layout.hatches.size(),
			"generated: %d hatch leaves for %d hatches" % [main.get_node("Ship/Hatches").get_child_count(), layout.hatches.size()])
	if layout.hatches.size() > 1:
		var other: Node3D = load("res://scenes/main_3d.tscn").instantiate()
		other.layout_override = layout
		other.explore_darkness = false
		other.entry_hatch = 1
		root.add_child(other)
		var second := layout.room_at(ShipBuilder3D.world_to_tile(other.get_node("Player").global_position))
		expect.call(second == layout.hatches[1].room and second != first,
				"generated: boarding through hatch 1 landed in room %d, hatch 0 in room %d" % [second, first])
		root.remove_child(other)
		other.free()

	var floor_map: GridMap = main.get_node("Ship/Floor")
	expect.call(floor_map.get_used_cells().size() == layout.floor_tiles().size(),
			"generated: %d floor cells for %d floor tiles" % [floor_map.get_used_cells().size(), layout.floor_tiles().size()])
	expect.call(main.get_node("Ship/Doors").get_child_count() == layout.doors.size(),
			"generated: %d door leaves for %d doors" % [main.get_node("Ship/Doors").get_child_count(), layout.doors.size()])

	_check_bridge_to_engine(expect, layout, main)
	_check_crew(expect, layout, main)

	root.remove_child(main)
	main.free()


## A route from the Bridge to an Engine Room exists, every doorway on it is
## wide enough and opens, and every waypoint lands on floor.
static func _check_bridge_to_engine(expect: Callable, layout: ShipLayout, main: Node3D) -> void:
	var bridge := -1
	var engine := -1
	for i in layout.rooms.size():
		if layout.rooms[i].role == &"bridge":
			bridge = i
		elif layout.rooms[i].role == &"engine" and engine < 0:
			engine = i
	expect.call(bridge >= 0 and engine >= 0, "generated: no bridge or no engine to walk between")
	if bridge < 0 or engine < 0:
		return
	var rooms := ShipNavigator.room_path(layout, bridge, engine)
	expect.call(not rooms.is_empty(), "generated: no route from the bridge to the engine")
	if rooms.is_empty():
		return
	var doors: Node3D = main.get_node("Ship/Doors")
	for k in range(rooms.size() - 1):
		var door := ShipNavigator.door_between(layout, rooms[k], rooms[k + 1])
		expect.call(door != null and door.width >= 2, "generated: rooms %d and %d on the route share no usable door" % [rooms[k], rooms[k + 1]])
		if door == null:
			continue
		var leaf: Door3D = doors.get_child(layout.doors.find(door))
		leaf.open()
		expect.call(leaf.is_open, "generated: door between rooms %d and %d would not open" % [rooms[k], rooms[k + 1]])
	var from := ShipBuilder3D.room_center_world(layout.rooms[bridge])
	var to := ShipBuilder3D.room_center_world(layout.rooms[engine])
	var points := ShipNavigator.waypoints_3d(layout, from, to)
	expect.call(points.size() >= rooms.size(), "generated: %d waypoints for a %d-room route" % [points.size(), rooms.size()])
	var floors := layout.floor_tiles()
	for p in points:
		expect.call(floors.has(ShipBuilder3D.world_to_tile(p)), "generated: waypoint %s is not on floor" % p)


## Whether some counted Room has no crew.
static func _has_empty_room(layout: ShipLayout) -> bool:
	for room in layout.rooms:
		if room.role != &"corridor" and room.crew_count == 0:
			return true
	return false


## Crew stand where the Threat Budget put them: every Room's count, some
## in the Armory, and at least one Room with none.
static func _check_crew(expect: Callable, layout: ShipLayout, main: Node3D) -> void:
	var per_room := {}
	for member in main.get_node("Ship/Crew").get_children():
		per_room[member.home_room] = per_room.get(member.home_room, 0) + 1
	var armory_crew := 0
	var empty_rooms := 0
	for i in layout.rooms.size():
		var room := layout.rooms[i]
		expect.call(per_room.get(i, 0) == room.crew_count,
				"generated: room %d (%s) spawned %d crew for a share of %d" % [i, room.role, per_room.get(i, 0), room.crew_count])
		if room.role == &"armory":
			armory_crew += per_room.get(i, 0)
		if room.role != &"corridor" and per_room.get(i, 0) == 0:
			empty_rooms += 1
	expect.call(armory_crew > 0, "generated: no crew in the armory")
	expect.call(empty_rooms > 0, "generated: every room is crewed")
