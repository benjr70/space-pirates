extends Node
## PROTOTYPE, throwaway -- how Attachments mount on a gun model
## (.scratch/weapon-attachments/issues/06-how-attachments-mount-on-a-gun.md).
##
##   flatpak run org.godotengine.Godot --path . res://scenes/proto_attachment_mounting.tscn \
##       -- --seed=7 --class=large
##
## A real Raid with an Assault Rifle whose barrel, iron sights, stock and cell
## are separate meshes (`tools/blender/proto_ar_split.py`), and rough
## Attachments for every Slot (`tools/blender/proto_ar_attachments.py`), both
## copied to `assets/models/proto_attachments/`. An Attachment either adds
## itself or takes the place of one of the rifle's own parts. Only the look
## changes: the rifle shoots as it always does.
##
##   F5        Sight: iron sights / Reflex Sight / Combat Scope
##   F6        Barrel: own barrel / Suppressor / Long Barrel / Short Barrel
##   F7        Magazine: own cell / Extended Magazine / Drum
##   F8        Underbarrel: none / Foregrip / Laser
##   F9        Stock: own stock / Heavy Stock / Light Stock
##   F10       inspect: hold the rifle side-on in front of the eye, on/off
##   J L       hip pose left / right
##   I K       hip pose up / down
##   U O       hip pose nearer / further
##   9 0       how far ahead of the eye it sits in Aim Down Sights
##   F2        cannot die, on/off (starts on)
##
## The muzzle flash and tracer start at whichever barrel is on; the sights
## centre on whichever Sight is on. Reload (R) to see a Magazine ride the
## cell's own reload clip.

## Each Slot: the rifle's own part it can replace, and its Attachments.
## `replaces` says whether the Attachment hides that part or adds to it.
const SLOTS := [
	{"slot": "Sight", "key": KEY_F5, "own": "Sights", "marker": "SightTip", "choices": [
		{"name": "Reflex Sight", "node": "ReflexSight", "replaces": true},
		{"name": "Combat Scope", "node": "CombatScope", "replaces": true}]},
	{"slot": "Barrel", "key": KEY_F6, "own": "Barrel", "marker": "Muzzle", "choices": [
		{"name": "Suppressor", "node": "Suppressor", "replaces": false},
		{"name": "Long Barrel", "node": "LongBarrel", "replaces": true},
		{"name": "Short Barrel", "node": "ShortBarrel", "replaces": true}]},
	{"slot": "Magazine", "key": KEY_F7, "own": "Cell", "marker": "", "choices": [
		{"name": "Extended Magazine", "node": "ExtendedMagazine", "replaces": true},
		{"name": "Drum", "node": "Drum", "replaces": true}]},
	{"slot": "Underbarrel", "key": KEY_F8, "own": "", "marker": "", "choices": [
		{"name": "Foregrip", "node": "Foregrip", "replaces": false},
		{"name": "Laser", "node": "Laser", "replaces": false}]},
	{"slot": "Stock", "key": KEY_F9, "own": "Stock", "marker": "", "choices": [
		{"name": "Heavy Stock", "node": "HeavyStock", "replaces": true},
		{"name": "Light Stock", "node": "LightStock", "replaces": true}]},
]
const DIR := "res://assets/models/proto_attachments/"

var _player: Node
var _view: Node
var _rifle: WeaponProfile
var _model: Node3D
## Chosen Attachment per Slot: 0 is none, the rifle as it comes.
var _picked := [0, 0, 0, 0, 0]
var _immortal := true
var _inspect := false
var _label: Label


func _ready() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	_player = get_parent().player
	_view = _player.viewmodel
	var stock_rifle: WeaponProfile = load("res://resources/weapons/assault_rifle.tres")
	_rifle = stock_rifle.duplicate()
	_rifle.model = _wrap()
	var at: int = _player.weapons.find(stock_rifle)
	if at >= 0:
		_player.weapons[at] = _rifle
	else:
		_player.weapons.append(_rifle)
	_player.swap_time = 0.0
	_player.weapon = _rifle
	_player.ammo = _rifle.magazine_size
	_player.ammo_changed.emit(_player.ammo)
	_view._mount(_rifle)
	_player.swap_time = 0.4
	_model = _view._models[_rifle.model]
	_ride_the_cell()
	_apply()

	var layer := CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	_label = Label.new()
	_label.position = Vector2(24, 110)
	_label.add_theme_font_size_override("font_size", 16)
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 6)
	layer.add_child(_label)
	var args := OS.get_cmdline_user_args()
	if "--selftest" in args:
		_selftest()
	elif "--shots" in args:
		_shots()


## The split rifle and every Attachment under one root, in the rifle's space.
func _wrap() -> PackedScene:
	var root := Node3D.new()
	root.name = "ProtoArModel"
	for file in ["proto_ar", "proto_ar_attachments"]:
		var model: Node3D = load(DIR + file + ".glb").instantiate()
		model.name = "Gun" if file == "proto_ar" else "Attachments"
		model.position = Vector3(0, 0.068, -0.01)
		root.add_child(model)
		model.owner = root
	var packed := PackedScene.new()
	packed.pack(root)
	root.free()
	return packed


func _part(node_name: String) -> Node3D:
	return _model.find_child(node_name, true, false) as Node3D


## The Magazines go under the cell's bone, so the reload clip that drops and
## seats the cell does the same to whichever Magazine is on.
func _ride_the_cell() -> void:
	_view._stop_clip()
	var skeleton: Skeleton3D = _model.find_child("Skeleton3D", true, false)
	var bone := BoneAttachment3D.new()
	bone.name = "CellMount"
	skeleton.add_child(bone)
	# The importer renames a bone that shares its name with a mesh: Cell_2.
	for i in skeleton.get_bone_count():
		if skeleton.get_bone_name(i).begins_with("Cell"):
			bone.bone_idx = i
	for choice: Dictionary in SLOTS[2].choices:
		_part(choice.node).reparent(bone, true)


func _apply() -> void:
	_view._stop_clip()
	for i in SLOTS.size():
		var slot: Dictionary = SLOTS[i]
		var hide_own := false
		var marker := String(slot.marker)
		for c in slot.choices.size():
			var choice: Dictionary = slot.choices[c]
			var on: bool = _picked[i] == c + 1
			_part(choice.node).visible = on
			if on:
				hide_own = choice.replaces
				if marker != "":
					marker = "%s_%s" % [choice.node, slot.marker]
		if slot.own != "":
			_part(slot.own).visible = not hide_own
		if marker != "":
			var to_view: Transform3D = _view.global_transform.affine_inverse()
			var where: Vector3 = to_view * _part(marker).global_position
			if slot.marker == "Muzzle":
				_view._muzzle.position = where
			else:
				_view._sight_tip.position = where
				var sight: Vector3 = Basis.from_euler(_view.rotation_hip * PI / 180.0) * where
				_view.pose_ads = Vector3(-sight.x, -sight.y, _view.pose_ads.z)


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo) or _model == null:
		return
	var key: int = event.physical_keycode
	for i in SLOTS.size():
		if key == SLOTS[i].key:
			_picked[i] = (_picked[i] + 1) % (SLOTS[i].choices.size() + 1)
			_apply()
			print("[attachment mounting] ", _state_line())
			return
	match key:
		KEY_J: _view.pose_hip.x -= 0.01
		KEY_L: _view.pose_hip.x += 0.01
		KEY_I: _view.pose_hip.y += 0.01
		KEY_K: _view.pose_hip.y -= 0.01
		KEY_U: _view.pose_hip.z += 0.01
		KEY_O: _view.pose_hip.z -= 0.01
		KEY_9: _view.pose_ads.z += 0.01
		KEY_0: _view.pose_ads.z -= 0.01
		KEY_F2: _immortal = not _immortal
		KEY_F10: _set_inspect(not _inspect)
		_: return
	print("[attachment mounting] ", _state_line())


## Side-on in front of the eye, frozen, to read the whole build at once.
func _set_inspect(on: bool) -> void:
	_inspect = on
	_view.set_process(not on)
	if on:
		_view.position = Vector3(-0.14, -0.03, -0.95)
		_view.rotation_degrees = Vector3(0, 90, 0)


func _state_line() -> String:
	var parts := PackedStringArray()
	for i in SLOTS.size():
		var name: String = "own" if _picked[i] == 0 else SLOTS[i].choices[_picked[i] - 1].name
		parts.append("%s: %s" % [SLOTS[i].slot, name])
	return "%s | hip pose %s, aimed distance %.2f" % [", ".join(parts), _view.pose_hip, -_view.pose_ads.z]


func _process(_delta: float) -> void:
	if _label == null:
		return
	if _immortal and _player.health.is_alive():
		_player.health.current = _player.health.max_health
		get_parent().hud.set_health(_player.health.current)
	_label.text = "ATTACHMENT MOUNTING PROTOTYPE%s\n%s\n\nF5 Sight  F6 Barrel  F7 Magazine  F8 Underbarrel  F9 Stock   F10 inspect: %s\nJ L / I K / U O hip pose   9 0 aimed distance   R reload   F2 cannot die: %s" % [
		"" if _player.weapon == _rifle else "   (wheel to the Assault Rifle)", _state_line().replace(" | ", "\n"),
		"on" if _inspect else "off", "on" if _immortal else "off"]


## Headless check: every Attachment shows, the right part hides, the markers
## move and the rifle still fires and reloads.
func _selftest() -> void:
	for i in SLOTS.size():
		for c in SLOTS[i].choices.size() + 1:
			_picked = [0, 0, 0, 0, 0]
			_picked[i] = c
			_apply()
			var own: String = SLOTS[i].own
			print("[selftest] ", _state_line().get_slice(" | ", 0), "  own part shown: ",
				"-" if own == "" else str(_part(own).visible),
				"  muzzle ", _view._muzzle.position.snappedf(0.001), "  sight ", _view._sight_tip.position.snappedf(0.001),
				"  aimed ", _view.pose_ads.snappedf(0.001))
	_picked = [1, 1, 2, 1, 1]
	_apply()
	_player.cancel_reload()
	_player._cooldown = 0.0
	_player.ammo = 5
	for f in 4:
		await get_tree().physics_frame
	print("[selftest] fired: ", _player.fire() != null)
	_player.start_reload()
	await get_tree().create_timer(0.6).timeout
	var drum := _part("Drum")
	print("[selftest] drum mid-reload is ", (drum.global_position - _model.global_position).snappedf(0.001), " from the gun")
	get_tree().quit()


## Offscreen frames for the agent to read: `--shots` under gamescope.
func _shots() -> void:
	_label.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	DirAccess.make_dir_recursive_absolute("res://.godot/shots/proto_mounting")
	var builds := {
		"own": [0, 0, 0, 0, 0],
		"reflex_suppressor_ext_grip_heavy": [1, 1, 1, 1, 1],
		"scope_long_drum_laser_light": [2, 2, 2, 2, 2],
		"reflex_short_own_grip_light": [1, 3, 0, 1, 2],
	}
	_player.set_physics_process(false)
	for build: String in builds:
		_picked = builds[build]
		_apply()
		_view.set_process(false)
		for pose in ["hip", "ads", "inspect"]:
			_view.rotation_degrees = _view.rotation_hip
			match pose:
				"hip": _view.position = _view.pose_hip
				"ads": _view.position = _view.pose_ads
				"inspect": _set_inspect(true)
			for f in 4:
				await get_tree().process_frame
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("res://.godot/shots/proto_mounting/%s_%s.png" % [build, pose])
	print("SHOTS_DONE")
	get_tree().quit()
