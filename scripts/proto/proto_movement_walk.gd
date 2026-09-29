extends Node3D
## PROTOTYPE — walk the sprint / crouch / slide / clamber set (issue #32).
##
##   flatpak run org.godotengine.Godot --path . res://scenes/proto_movement_walk.tscn \
##       -- sprint=1.10 fov=0 crouch=1.2 crouchspeed=0.5 slide=0.6 boost=1.15 \
##          tilt=6 cmin=0.6 cmax=1.6 ctime=0.5 dip=0.18 ceiling=2.5 crew=0 hold=1
##
## Every knob is optional; the defaults are the Halo reference doc's starting
## table. `ceiling` stretches the walls and lifts the ceiling GridMap, because
## the ship's 2.5 m rooms cannot fit a 1.8 m pirate standing on a 1.1 m crate.
## `hold=0` makes clamber automatic on any airborne approach instead of only
## while jump is held. `crew=1` keeps the cover walk's crew in the rooms.
##
## Keys: WASD move, Shift sprint, Ctrl/C crouch, Space jump/clamber, LMB fire.
##
## You start in the entry Cargo bay of the cover walk. Straight north through a
## door is the LEDGE COURSE: ten 2-tile-deep blocks from 0.3 m to 2.1 m, each
## labelled, so the clamber band can be felt block by block. Left of the
## course a 1.3 m slab on lockers is the crouch gap.

const KNOB_DEFAULTS := {
	sprint = 1.10, fov = 0.0, crouch = 1.2, crouchspeed = 0.5,
	slide = 0.6, boost = 1.15, tilt = 6.0,
	cmin = 0.6, cmax = 1.6, ctime = 0.5, dip = 0.18,
	ceiling = 2.5, crew = 0, hold = 1,
}
const PLAYER_SCRIPT := preload("res://scripts/proto/proto_player_movement.gd")
const COVER_SCRIPT := preload("res://scripts/proto/proto_cover_walk.gd")
const COURSE_ROOM := Rect2i(5, -12, 12, 10)

var knobs := KNOB_DEFAULTS.duplicate()
var player: CharacterBody3D
var label: Label


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		var kv := arg.split("=")
		if kv.size() == 2 and knobs.has(kv[0]):
			knobs[kv[0]] = float(kv[1])

	var cover = COVER_SCRIPT.new()
	var layout: ShipLayout = cover._make_layout()
	layout.ship_name = "Movement Walk"
	var course := RoomData.new()
	course.rects = [COURSE_ROOM]
	course.role = &"cargo"
	course.crew_count = 0
	layout.rooms.append(course)
	layout.doors.append(cover._door(1, layout.rooms.size() - 1, Vector2i(10, -1), true, 2))
	cover._furnish_all(layout)

	var main: Node3D = load("res://scenes/main_3d.tscn").instantiate()
	main.layout_override = layout
	main.explore_darkness = false
	player = main.get_node("Player")
	player.set_script(PLAYER_SCRIPT)
	_apply_knobs()
	add_child(main)
	cover._spawn_extras(main, layout)
	if int(knobs.crew) == 0:
		for c in main.ship.get_node("Crew").get_children():
			c.queue_free()
	_raise_ceiling(main.ship, knobs.ceiling)
	_build_course(main.ship.get_node("Props"))
	_build_label()
	print("movement walk knobs: ", knobs)
	cover.free()


func _apply_knobs() -> void:
	player.k_sprint_mult = knobs.sprint
	player.k_sprint_fov = knobs.fov
	player.k_crouch_height = knobs.crouch
	player.k_crouch_speed_mult = knobs.crouchspeed
	player.k_slide_time = knobs.slide
	player.k_slide_boost = knobs.boost
	player.k_slide_tilt_deg = knobs.tilt
	player.k_clamber_min = knobs.cmin
	player.k_clamber_max = knobs.cmax
	player.k_clamber_time = knobs.ctime
	player.k_clamber_dip = knobs.dip
	player.k_clamber_needs_jump_held = int(knobs.hold) != 0


## Stretch the wall GridMap and lift the ceiling one, so a taller room can be
## felt without touching the builder.
func _raise_ceiling(ship: Node3D, height: float) -> void:
	var base := ShipBuilder3D.WALL_HEIGHT
	if is_equal_approx(height, base):
		return
	ship.get_node("Walls").scale.y = height / base
	ship.get_node("Ceiling").position.y += height - base


## Ten blocks, 1 tile wide and 2 deep, rising 0.2 m each, across the course
## room, plus a slab to crouch under.
func _build_course(props: Node3D) -> void:
	var row_z := COURSE_ROOM.position.y + 3
	for i in 10:
		var h := 0.3 + 0.2 * i
		var tile := Vector2i(COURSE_ROOM.position.x + 1 + i, row_z)
		var origin := ShipBuilder3D.tile_to_world(tile) + Vector3(0, 0, 0.5)
		_block(props, origin, Vector3(0.9, h, 1.9), "%.1f m" % h)
	# Crouch gap: a 0.3 m slab with its underside 1.3 m up, two tiles wide.
	var gap_tile := Vector2i(COURSE_ROOM.position.x + 2, COURSE_ROOM.end.y - 3)
	var gap_origin := ShipBuilder3D.tile_to_world(gap_tile) + Vector3(0.5, 0, 0)
	var slab := _block(props, gap_origin + Vector3(0, 1.3, 0), Vector3(2.9, 0.3, 0.9), "gap 1.3 m")
	slab.get_node("Tag").position.y = 0.6
	for dx in [-1.5, 1.5]:
		_block(props, gap_origin + Vector3(dx, 0, 0), Vector3(0.3, 1.3, 0.9), "")


func _block(parent: Node3D, origin: Vector3, size: Vector3, text: String) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = origin
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 0.55, 0.75)
	box.material = mat
	mesh.mesh = box
	mesh.position.y = size.y / 2.0
	body.add_child(mesh)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	col.position.y = size.y / 2.0
	body.add_child(col)
	var tag := Label3D.new()
	tag.name = "Tag"
	tag.text = text
	tag.font_size = 48
	tag.pixel_size = 0.005
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.position.y = size.y + 0.3
	body.add_child(tag)
	parent.add_child(body)
	return body


func _build_label() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 5
	label = Label.new()
	label.position = Vector2(16, 16)
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
	layer.add_child(label)
	add_child(layer)


func _process(_delta: float) -> void:
	if player == null or label == null:
		return
	label.text = "state %s   speed %.2f m/s   capsule %.2f m   fov %.0f\nlast: %s\nprobe: %s\n\nsprint x%.2f  fov %+.0f  crouch %.2f m @ x%.2f  slide %.2fs x%.2f tilt %.0f\nclamber %.1f–%.1f m in %.2fs  dip %.2f  ceiling %.1f  hold=%d" % [
		player.state_name(), player.flat_speed(), player._capsule.height, player.camera.fov,
		player.last_event, player.last_probe,
		knobs.sprint, knobs.fov, knobs.crouch, knobs.crouchspeed, knobs.slide, knobs.boost, knobs.tilt,
		knobs.cmin, knobs.cmax, knobs.ctime, knobs.dip, knobs.ceiling, int(knobs.hold)]
