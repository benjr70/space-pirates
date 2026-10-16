class_name MainMenu
extends Node3D
## The game's one entry point: the title over a ship drifting in space, Play
## to pick which Ship Class to raid (a fresh seed every time), and Exit.

## Where the camera sits, off the ship's bow quarter, and how far it turns
## away from the ship so it is framed right of the title.
const CAMERA_AT := Vector3(-34, 16, -40)
const CAMERA_TURN_DEGREES := 17.0
## The way the sun shines, shared by the ship's key light and the planet.
const SUN_DIR := Vector3(0.9, -0.5, -0.1)

@onready var ui: CanvasLayer = $UI
@onready var camera: Camera3D = $Camera3D
@onready var sun: DirectionalLight3D = $Sun
@onready var planet: MeshInstance3D = $Planet

var _home: Control
var _classes: Control


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	camera.look_at_from_position(CAMERA_AT, Vector3.ZERO)
	camera.rotate_object_local(Vector3.UP, deg_to_rad(CAMERA_TURN_DEGREES))
	sun.look_at_from_position(Vector3.ZERO, SUN_DIR)
	(planet.get_surface_override_material(0) as ShaderMaterial).set_shader_parameter("sun_dir", SUN_DIR)
	var root := Control.new()
	root.name = "Root"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.add_child(root)

	# A soft dark band down the left so the title reads over any star.
	var shade := TextureRect.new()
	shade.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	shade.custom_minimum_size = Vector2(720, 0)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fade := GradientTexture2D.new()
	fade.gradient = Gradient.new()
	fade.gradient.set_color(0, Color(0, 0, 0, 0.75))
	fade.gradient.set_color(1, Color(0, 0, 0, 0))
	shade.texture = fade
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	root.add_child(shade)

	var column := VBoxContainer.new()
	column.name = "Column"
	column.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	column.offset_left = 96
	column.offset_right = 640
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 10)
	root.add_child(column)

	var title := MenuStyle.heading("SPACE PIRATE", 84)
	title.name = "Title"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	column.add_child(title)
	var tagline := MenuStyle.heading("BOARD  ·  PLUNDER  ·  GET OUT ALIVE", 18, MenuStyle.ACCENT)
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	column.add_child(tagline)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 48)
	column.add_child(gap)

	_home = _menu(column, "Home", [["Play", _show_classes], ["Exit", _quit]])
	_classes = _menu(column, "Classes", [
		["Small Ship", Raid.start.bind(&"small")],
		["Medium Ship", Raid.start.bind(&"medium")],
		["Large Ship", Raid.start.bind(&"large")],
		["Back", _show_home],
	])
	var pick := MenuStyle.heading("CHOOSE A TARGET", 16, MenuStyle.DIM_TEXT)
	pick.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_classes.add_child(pick)
	_classes.move_child(pick, 0)
	_show_home()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and _classes.visible:
		_show_home()
		get_viewport().set_input_as_handled()


func _menu(parent: Control, menu_name: String, entries: Array) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.name = menu_name
	box.add_theme_constant_override("separation", 12)
	for entry in entries:
		var b := MenuStyle.button(entry[0])
		b.name = String(entry[0]).replace(" ", "")
		b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		b.pressed.connect(entry[1])
		box.add_child(b)
	parent.add_child(box)
	return box


func _show_home() -> void:
	_classes.visible = false
	_home.visible = true
	_home.get_node("Play").grab_focus()


func _show_classes() -> void:
	_home.visible = false
	_classes.visible = true
	_classes.get_node("MediumShip").grab_focus()


func _quit() -> void:
	get_tree().quit()
