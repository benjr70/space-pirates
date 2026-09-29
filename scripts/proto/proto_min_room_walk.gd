extends Node3D
## PROTOTYPE — walk a minimum-size Room in first person (issue #12).
##
##   flatpak run org.godotengine.Godot --path . res://scenes/proto_min_room_walk.tscn \
##       -- short=6 long=10 crew=2
##
## Two Rooms of the candidate minimum joined by a width-2 Door: an empty entry
## Room, then a fight Room with a crate and a console for cover. Judges whether
## the floor holds a first-person firefight, not just the arithmetic.

@export var short_side := 6
@export var long_side := 10
@export var crew := 2


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		var kv := arg.split("=")
		if kv.size() != 2:
			continue
		match kv[0]:
			"short":
				short_side = int(kv[1])
			"long":
				long_side = int(kv[1])
			"crew":
				crew = int(kv[1])

	var main: Node3D = load("res://scenes/main_3d.tscn").instantiate()
	main.layout_override = _make_layout()
	main.explore_darkness = false
	add_child(main)
	print("walking a %dx%d minimum room" % [short_side, long_side])


## Entry Room at the origin, fight Room to its +X side, one wall tile between.
func _make_layout() -> ShipLayout:
	var layout := ShipLayout.new()
	layout.ship_name = "Min Room %dx%d" % [short_side, long_side]

	var entry := RoomData.new()
	entry.rects = [Rect2i(0, 0, long_side, short_side)]
	entry.role = &"cargo"
	layout.rooms.append(entry)

	var fight := RoomData.new()
	fight.rects = [Rect2i(long_side + 1, 0, long_side, short_side)]
	fight.role = &"quarters"
	fight.crew_count = crew
	# Crate a third of the way in, console two thirds, offset to opposite
	# sides so neither covers the whole doorway sightline.
	fight.props = [
		{type = &"crate", tile = Vector2i(long_side + 1 + long_side / 3, 1)},
		{type = &"console", tile = Vector2i(long_side + 1 + (2 * long_side) / 3, short_side - 2)},
	]
	layout.rooms.append(fight)

	var door := DoorData.new()
	door.room_a = 0
	door.room_b = 1
	door.horizontal = false
	door.tile = Vector2i(long_side, short_side / 2 - 1)
	layout.doors.append(door)

	layout.hatches = [ProtoHatch.through_hull(layout, 0)]
	return layout
