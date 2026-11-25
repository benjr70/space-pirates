extends Node
## PROTOTYPE, throwaway -- what each Attachment looks like
## (.scratch/weapon-attachments/issues/09-attachment-look.md).
##
##   flatpak run org.godotengine.Godot --path . res://scenes/proto_attachment_look.tscn \
##       -- --seed=7 --class=large
##
## A real Raid carrying all four guns, each rebuilt with its replaceable parts
## as separate meshes (`tools/blender/proto_split_gun.py`), and all fourteen
## Attachments (`tools/blender/proto_attachments.py`), fitted as the catalogue
## says each gun takes them. Only the look changes: every gun shoots as it
## always does.
##
##   wheel / 1-4   which gun
##   F5            Sight
##   F6            Barrel
##   F7            Magazine
##   F8            Underbarrel
##   F9            Stock
##   F10           inspect: the gun held side-on in front of the eye, frozen
##   A D / W S     while inspecting: turn the gun
##   F2            cannot die, on/off (starts on)
##
## A Slot the gun in hand does not have does nothing. Sights, the Suppressor
## and the Underbarrels are one model each, placed at a mount point every gun
## gives; Barrels, Magazines and Stocks are a model per gun, since they take
## the place of that gun's own part.

const SLOTS := ["Sight", "Barrel", "Magazine", "Underbarrel", "Stock"]
const SLOT_KEYS := [KEY_F5, KEY_F6, KEY_F7, KEY_F8, KEY_F9]
const DIR := "res://assets/models/proto_attachments/"

## A shared Attachment: its node, the mount it goes on, whether it hides the
## gun's own part, and the marker it brings.
const REFLEX := {"name": "Reflex Sight", "node": "ReflexSight", "mount": "MountSight", "replaces": true, "sight": "ReflexSight_SightTip"}
const COMBAT := {"name": "Combat Scope", "node": "CombatScope", "mount": "MountSight", "replaces": true, "sight": "CombatScope_SightTip"}
const LONG_SCOPE := {"name": "Long Scope", "node": "LongScope", "mount": "MountSight", "replaces": true, "sight": "LongScope_SightTip"}
const SUPPRESSOR := {"name": "Suppressor", "node": "Suppressor", "mount": "MountMuzzle", "replaces": false, "muzzle": "Suppressor_Muzzle"}
const FOREGRIP := {"name": "Foregrip", "node": "Foregrip", "mount": "MountUnder", "replaces": false}
const LASER := {"name": "Laser", "node": "Laser", "mount": "MountUnder", "replaces": false}
const BIPOD := {"name": "Bipod", "node": "Bipod", "mount": "MountUnder", "replaces": false}

## Per gun: the file, each Slot's own parts and choices, and the bones a
## Slot's Attachments ride.
const GUNS := {
	"pistol": {"name": "Pistol", "slots": {
		"Sight": {"own": [], "ride": "Slide", "choices": [
			{"name": "Reflex Sight", "node": "ReflexSight", "mount": "MountSight", "replaces": false, "sight": "ReflexSight_SightTip"}]},
		"Barrel": {"own": [], "choices": [SUPPRESSOR]},
		"Magazine": {"own": ["MagazineMesh"], "ride": "Magazine", "choices": [
			{"name": "Extended Magazine", "node": "Pistol_ExtendedMagazine", "replaces": true},
			{"name": "Quick Magazine", "node": "Pistol_QuickMagazine", "replaces": true}]},
		"Underbarrel": {"own": [], "choices": [LASER]},
	}},
	"assault_rifle": {"name": "Assault Rifle", "slots": {
		"Sight": {"own": ["Sights"], "choices": [REFLEX, COMBAT]},
		"Barrel": {"own": ["Barrel"], "choices": [SUPPRESSOR,
			{"name": "Long Barrel", "node": "AR_LongBarrel", "replaces": true, "muzzle": "AR_LongBarrel_Muzzle"},
			{"name": "Short Barrel", "node": "AR_ShortBarrel", "replaces": true, "muzzle": "AR_ShortBarrel_Muzzle"}]},
		"Magazine": {"own": ["CellMesh"], "ride": "Cell", "choices": [
			{"name": "Extended Magazine", "node": "AR_ExtendedMagazine", "replaces": true},
			{"name": "Quick Magazine", "node": "AR_QuickMagazine", "replaces": true},
			{"name": "Drum", "node": "AR_Drum", "replaces": true}]},
		"Underbarrel": {"own": [], "choices": [FOREGRIP, LASER, BIPOD]},
		"Stock": {"own": ["Stock"], "choices": [
			{"name": "Heavy Stock", "node": "AR_HeavyStock", "replaces": true},
			{"name": "Light Stock", "node": "AR_LightStock", "replaces": true}]},
	}},
	"shotgun": {"name": "Shotgun", "slots": {
		"Sight": {"own": ["Sights", "FrontSight"], "choices": [REFLEX]},
		"Barrel": {"own": ["Barrel", "FrontSight"], "choices": [
			{"name": "Long Barrel", "node": "Shotgun_LongBarrel", "replaces": true, "muzzle": "Shotgun_LongBarrel_Muzzle",
				"sight": "Shotgun_LongBarrel_SightTip"},
			{"name": "Short Barrel", "node": "Shotgun_ShortBarrel", "replaces": true, "muzzle": "Shotgun_ShortBarrel_Muzzle",
				"sight": "Shotgun_ShortBarrel_SightTip"}]},
		"Underbarrel": {"own": [], "ride": "Pump", "choices": [FOREGRIP, LASER]},
		"Stock": {"own": ["Stock"], "choices": [
			{"name": "Heavy Stock", "node": "Shotgun_HeavyStock", "replaces": true},
			{"name": "Light Stock", "node": "Shotgun_LightStock", "replaces": true}]},
	}},
	"marksman_rifle": {"name": "Marksman Rifle", "slots": {
		"Sight": {"own": ["Sights"], "choices": [LONG_SCOPE]},
		"Barrel": {"own": ["Barrel"], "choices": [SUPPRESSOR,
			{"name": "Long Barrel", "node": "Marksman_LongBarrel", "replaces": true, "muzzle": "Marksman_LongBarrel_Muzzle"}]},
		"Magazine": {"own": ["MagazineMesh"], "ride": "Magazine", "choices": [
			{"name": "Extended Magazine", "node": "Marksman_ExtendedMagazine", "replaces": true},
			{"name": "Quick Magazine", "node": "Marksman_QuickMagazine", "replaces": true}]},
		"Underbarrel": {"own": [], "choices": [FOREGRIP, BIPOD]},
		"Stock": {"own": ["Stock"], "choices": [
			{"name": "Heavy Stock", "node": "Marksman_HeavyStock", "replaces": true},
			{"name": "Light Stock", "node": "Marksman_LightStock", "replaces": true}]},
	}},
}

var _player: Node
var _view: Node
## Per gun file: its Profile, its mounted model, what is picked per Slot.
var _profiles := {}
var _models := {}
var _picked := {}
var _immortal := true
var _inspect := false
var _inspect_turn := Vector2.ZERO
var _was_mounted: Node3D
var _label: Label


func _ready() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	_player = get_parent().player
	_view = _player.viewmodel
	_player.swap_time = 0.0
	for file: String in GUNS:
		var stock: WeaponProfile = load("res://resources/weapons/%s.tres" % file)
		var profile: WeaponProfile = stock.duplicate()
		profile.model = _wrap(file)
		_profiles[file] = profile
		_picked[file] = {}
		var at: int = _player.weapons.find(stock)
		_player.weapons[at] = profile
		_player.weapon = profile
		_view._mount(profile)
		_models[file] = _view._models[profile.model]
		_prepare(file)
		_apply(file)
	_player.weapon = _profiles["assault_rifle"]
	_view._mount(_player.weapon)
	_player.ammo = _player.weapon.magazine_size
	_player.ammo_changed.emit(_player.ammo)
	_player.swap_time = 0.4
	_apply("assault_rifle")

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


## The split gun and its own copy of every Attachment under one root, set
## where the gun's real model scene sets it.
func _wrap(file: String) -> PackedScene:
	var real: Node3D = load("res://scenes/weapons/%s_model.tscn" % file).instantiate()
	var offset: Transform3D = (real.get_child(0) as Node3D).transform
	real.free()
	var root := Node3D.new()
	root.name = "ProtoModel"
	for source in ["proto_" + file, "proto_attachments"]:
		var model: Node3D = load(DIR + source + ".glb").instantiate()
		model.name = "Attachments" if source == "proto_attachments" else "Gun"
		model.transform = offset
		root.add_child(model)
		model.owner = root
	var packed := PackedScene.new()
	packed.pack(root)
	root.free()
	return packed


func _current() -> String:
	for file: String in _profiles:
		if _profiles[file] == _player.weapon:
			return file
	return ""


func _node(file: String, node_name: String) -> Node3D:
	return (_models[file] as Node3D).find_child(node_name, true, false) as Node3D


## Once per gun: hide everything, hang each marker on its Attachment, put the
## shared ones on their mounts and the riders under their bones.
func _prepare(file: String) -> void:
	_view._stop_clip()
	var attachments: Node3D = _models[file].get_node("Attachments")
	for child in attachments.get_children():
		if child is MeshInstance3D:
			(child as Node3D).visible = false
	var skeleton: Skeleton3D = _models[file].find_child("Skeleton3D", true, false)
	var slots: Dictionary = GUNS[file].slots
	for slot: String in slots:
		var bone: BoneAttachment3D = null
		if slots[slot].has("ride"):
			bone = BoneAttachment3D.new()
			bone.name = "Ride" + slot
			skeleton.add_child(bone)
			bone.bone_idx = skeleton.find_bone(slots[slot].ride)
		for choice: Dictionary in slots[slot].choices:
			var node := _node(file, choice.node)
			for key in ["muzzle", "sight"]:
				if choice.has(key):
					_node(file, choice[key]).reparent(node, true)
			if choice.has("mount"):
				# The model was built around the file's origin, which is not
				# always the mesh node's own: carry the whole file to the mount.
				node.global_transform = _node(file, choice.mount).global_transform \
					* attachments.global_transform.affine_inverse() * node.global_transform
			if bone != null:
				node.reparent(bone, true)


func _apply(file: String) -> void:
	if _view._mounted != _models[file]:
		return
	_view._stop_clip()
	var slots: Dictionary = GUNS[file].slots
	var hidden := {}
	var muzzle := "Muzzle"
	var sight := "SightTip"
	for slot: String in slots:
		var chosen: int = _picked[file].get(slot, 0)
		for c in slots[slot].choices.size():
			var choice: Dictionary = slots[slot].choices[c]
			var on: bool = chosen == c + 1
			_node(file, choice.node).visible = on
			if not on:
				continue
			if choice.replaces:
				for own: String in slots[slot].own:
					hidden[own] = true
			muzzle = choice.get("muzzle", muzzle)
			# A Sight's aim point beats a Barrel's bead.
			if choice.has("sight") and (slot == "Sight" or sight == "SightTip"):
				sight = choice.sight
		for own: String in slots[slot].own:
			if not hidden.has(own):
				hidden[own] = false
	for own: String in hidden:
		_node(file, own).visible = not hidden[own]
	var to_view: Transform3D = _view.global_transform.affine_inverse()
	_view._muzzle.position = to_view * _node(file, muzzle).global_position
	var tip: Vector3 = to_view * _node(file, sight).global_position
	_view._sight_tip.position = tip
	var turned: Vector3 = Basis.from_euler(_view.rotation_hip * PI / 180.0) * tip
	_view.pose_ads = Vector3(-turned.x, -turned.y, -_profiles[file].ads_distance)


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo) or _label == null:
		return
	var file := _current()
	var key: int = event.physical_keycode
	var at := SLOT_KEYS.find(key)
	if at >= 0 and file != "":
		var slot: String = SLOTS[at]
		if GUNS[file].slots.has(slot):
			_picked[file][slot] = (_picked[file].get(slot, 0) + 1) % (GUNS[file].slots[slot].choices.size() + 1)
			_apply(file)
			_hold_inspect()
		print("[attachment look] ", _state_line())
		return
	match key:
		KEY_F2: _immortal = not _immortal
		KEY_F10:
			_inspect = not _inspect
			_inspect_turn = Vector2.ZERO
			_view.set_process(not _inspect)
			_player.set_physics_process(not _inspect)
			_hold_inspect()


func _hold_inspect() -> void:
	if not _inspect:
		return
	var long_gun: bool = _current() != "pistol"
	_view.position = Vector3(-0.16, -0.03, -1.05) if long_gun else Vector3(-0.05, 0.0, -0.66)
	_view.basis = Basis(Vector3.RIGHT, _inspect_turn.y) * Basis(Vector3.UP, PI / 2 + _inspect_turn.x)


func _state_line() -> String:
	var file := _current()
	if file == "":
		return "no gun"
	var parts := PackedStringArray()
	for slot: String in SLOTS:
		if not GUNS[file].slots.has(slot):
			parts.append("%s: no Slot" % slot)
			continue
		var chosen: int = _picked[file].get(slot, 0)
		parts.append("%s: %s" % [slot, "own" if chosen == 0 else GUNS[file].slots[slot].choices[chosen - 1].name])
	return "%s | %s" % [GUNS[file].name, ", ".join(parts)]


func _process(delta: float) -> void:
	if _label == null:
		return
	if _immortal and _player.health.is_alive():
		_player.health.current = _player.health.max_health
		get_parent().hud.set_health(_player.health.current)
	# The Viewmodel mounts the next gun at the bottom of its swap dip.
	if _view._mounted != _was_mounted:
		_was_mounted = _view._mounted
		var file := _current()
		if file != "" and _view._mounted == _models[file]:
			_apply(file)
	if _inspect:
		var turn := Vector2(float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)),
			float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W)))
		_inspect_turn += turn * delta * 1.5
		_hold_inspect()
	_label.text = "ATTACHMENT LOOK PROTOTYPE\n%s\n\nwheel gun   F5 Sight  F6 Barrel  F7 Magazine  F8 Underbarrel  F9 Stock\nF10 inspect: %s (A D / W S turn)   R reload   F2 cannot die: %s" % [
		_state_line().replace(" | ", "\n").replace(", ", "\n"), "on" if _inspect else "off", "on" if _immortal else "off"]


func _mount_now(file: String) -> void:
	_player.swap_time = 0.0
	_player.weapon = _profiles[file]
	_view._mount(_profiles[file])
	_apply(file)


## Headless check: every Attachment on every gun shows, with its markers.
func _selftest() -> void:
	for file: String in GUNS:
		_mount_now(file)
		for slot: String in GUNS[file].slots:
			for c in GUNS[file].slots[slot].choices.size():
				_picked[file] = {slot: c + 1}
				_apply(file)
				var choice: Dictionary = GUNS[file].slots[slot].choices[c]
				print("[selftest] %s / %s: shown %s, muzzle %s, sight %s" % [GUNS[file].name, choice.name,
					_node(file, choice.node).is_visible_in_tree(), _view._muzzle.position.snappedf(0.001),
					_view._sight_tip.position.snappedf(0.001)])
		_picked[file] = {}
	get_tree().quit()


## Offscreen frames for the agent to read: `--shots` under gamescope.
func _shots() -> void:
	_label.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	DirAccess.make_dir_recursive_absolute("res://.godot/shots/proto_look")
	_player.rotate_y(deg_to_rad(180.0))
	_inspect = true
	_view.set_process(false)
	_player.set_physics_process(false)
	for file: String in GUNS:
		var most := 0
		for slot: String in GUNS[file].slots:
			most = maxi(most, GUNS[file].slots[slot].choices.size())
		for build in most + 1:
			_picked[file] = {}
			for slot: String in GUNS[file].slots:
				_picked[file][slot] = mini(build, GUNS[file].slots[slot].choices.size())
			_mount_now(file)
			_hold_inspect()
			for f in 5:
				await get_tree().process_frame
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("res://.godot/shots/proto_look/%s_%d.png" % [file, build])
	_inspect = false
	_view.rotation_degrees = _view.rotation_hip
	for file: String in ["assault_rifle", "marksman_rifle"]:
		_picked[file] = {"Sight": 2 if file == "assault_rifle" else 1, "Barrel": 1, "Magazine": 1, "Underbarrel": 1, "Stock": 1}
		_mount_now(file)
		_view.position = _view.pose_hip
		for f in 5:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://.godot/shots/proto_look/%s_hip.png" % file)
	print("SHOTS_DONE")
	get_tree().quit()
