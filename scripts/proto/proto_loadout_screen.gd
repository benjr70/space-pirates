extends Node
## PROTOTYPE, throwaway -- what the Loadout screen looks like
## (.scratch/weapon-attachments/issues/08-loadout-screen.md).
##
##   flatpak run org.godotengine.Godot --path . res://scenes/proto_loadout_screen.tscn
##
## The real main menu with a Loadout button added. Behind it, three rough
## layouts of the same screen, switched from the bar along the bottom or with
## F1 F2 F3:
##
##   F1  workbench   one gun at a time, big; its Slots are tags around it and
##                   a Slot opens a list
##   F2  columns     all four guns down the left, every Slot's choices laid
##                   out as chips in the middle, the gun and bars on the right
##   F3  two-up      both carried guns side by side with drop-downs
##
## Nothing is saved and Play still starts an ordinary Raid. The Attachments
## and which gun takes which are the catalogue's; every number behind the
## bars is a placeholder, and the turning gun never shows its Attachments.

const LAYOUTS := ["workbench", "columns", "two-up"]
const WEAPONS := ["Pistol", "Assault Rifle", "Shotgun", "Marksman Rifle"]
const FILES := {"Pistol": "pistol", "Assault Rifle": "assault_rifle", "Shotgun": "shotgun", "Marksman Rifle": "marksman_rifle"}
const SLOTS := ["Sight", "Barrel", "Magazine", "Underbarrel", "Stock"]
const FIT := {
	"Pistol": {"Sight": ["Reflex Sight"], "Barrel": ["Suppressor"], "Magazine": ["Extended Magazine", "Quick Magazine"],
		"Underbarrel": ["Laser"]},
	"Assault Rifle": {"Sight": ["Reflex Sight", "Combat Scope"], "Barrel": ["Suppressor", "Long Barrel", "Short Barrel"],
		"Magazine": ["Extended Magazine", "Quick Magazine", "Drum"], "Underbarrel": ["Foregrip", "Laser", "Bipod"],
		"Stock": ["Heavy Stock", "Light Stock"]},
	"Shotgun": {"Sight": ["Reflex Sight"], "Barrel": ["Long Barrel", "Short Barrel"], "Underbarrel": ["Foregrip", "Laser"],
		"Stock": ["Heavy Stock", "Light Stock"]},
	"Marksman Rifle": {"Sight": ["Long Scope"], "Barrel": ["Suppressor", "Long Barrel"],
		"Magazine": ["Extended Magazine", "Quick Magazine"], "Underbarrel": ["Foregrip", "Bipod"],
		"Stock": ["Heavy Stock", "Light Stock"]},
}
## PLACEHOLDER factors, only so the bars move.
const CHANGES := {
	"Reflex Sight": {"zoom": 0.85, "aim_time": 0.8},
	"Combat Scope": {"zoom": 1.55, "aimed_spread": 0.75, "aim_time": 1.3},
	"Long Scope": {"zoom": 1.67, "aim_time": 1.4},
	"Suppressor": {"loudness": 0.4, "bolt_speed": 0.8},
	"Long Barrel": {"bolt_speed": 1.25, "spread": 0.8, "aim_time": 1.2},
	"Short Barrel": {"aim_time": 0.8, "spread": 1.25, "bolt_speed": 0.85},
	"Extended Magazine": {"magazine": 1.5, "reload": 1.25},
	"Quick Magazine": {"reload": 0.7, "magazine": 0.8},
	"Drum": {"magazine": 2.5, "reload": 1.6, "aim_time": 1.25},
	"Foregrip": {"recoil": 0.7, "aim_time": 1.15},
	"Laser": {"spread": 0.7, "seen": 1.3},
	"Bipod": {"aimed_spread": 0.7, "aim_time": 1.2},
	"Heavy Stock": {"aimed_spread": 0.8, "aim_time": 1.2},
	"Light Stock": {"aim_time": 0.8, "recoil": 1.25},
}
const WORDS := {
	"Reflex Sight": "faster to the sights · less zoom",
	"Combat Scope": "more zoom, tighter aimed · slower to the sights",
	"Long Scope": "most zoom · slower to the sights, more sway",
	"Suppressor": "crew hear it much less far · slower bolt",
	"Long Barrel": "faster bolt, tighter spread · slower handling",
	"Short Barrel": "faster handling · wider spread, slower bolt",
	"Extended Magazine": "more rounds · slower reload",
	"Quick Magazine": "faster reload · fewer rounds",
	"Drum": "far more rounds · much slower reload and handling",
	"Foregrip": "less recoil · slower to the sights",
	"Laser": "tighter hip fire · crew notice him sooner",
	"Bipod": "steadier crouched · slower handling",
	"Heavy Stock": "steadier aimed · slower handling",
	"Light Stock": "faster handling · more sway and recoil",
}
## Bar, the attribute behind it, the value a full bar means, and whether
## less of the attribute is better.
const BARS := [
	["Bolt speed", "bolt_speed", 260.0, false, "%d m/s"],
	["Hip accuracy", "spread", 6.0, true, "%.1f°"],
	["Aimed accuracy", "aimed_spread", 1.2, true, "%.2f°"],
	["Recoil control", "recoil", 14.0, true, "%.1f°"],
	["Handling", "aim_time", 0.6, true, "%.2f s"],
	["Magazine", "magazine", 80.0, false, "%d"],
	["Reload", "reload", 4.0, true, "%.1f s"],
	["Quiet", "loudness", 36.0, true, "%d m"],
	["Zoom", "zoom", 6.0, false, "%.1fx"],
]
## Where the workbench hangs each Slot's tag around the gun, as a fraction of
## the gun's box.
const TAG_AT := {"Sight": Vector2(0.50, 0.14), "Barrel": Vector2(0.10, 0.26), "Underbarrel": Vector2(0.24, 0.84),
	"Magazine": Vector2(0.54, 0.90), "Stock": Vector2(0.86, 0.38)}
const GAIN := Color(0.35, 0.9, 0.45)
const COST := Color(0.95, 0.35, 0.3)

var _loadout := ["Pistol", "Assault Rifle"]
var _fitted := {}
var _layout := 0
## The gun being worked on: in the workbench 0 or 1 of the Loadout; in
## columns any of the four.
var _editing := 0
var _column_gun := "Assault Rifle"
var _open_slot := ""
var _menu_root: Control
var _screen: Control
var _body: Control
## How far he has turned the gun by dragging it: yaw and pitch, radians.
var _turn := Vector2.ZERO
var _pivots: Array[Node3D] = []


func _ready() -> void:
	for weapon: String in WEAPONS:
		_fitted[weapon] = {}
	await get_tree().process_frame
	_menu_root = get_parent().get_node("UI/Root")
	var home: Control = _menu_root.get_node("Column/Home")
	var button := MenuStyle.button("Loadout")
	button.name = "Loadout"
	button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	button.pressed.connect(_open)
	home.add_child(button)
	home.move_child(button, 1)

	_screen = Control.new()
	_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	_screen.visible = false
	get_parent().get_node("UI").add_child(_screen)
	var args := OS.get_cmdline_user_args()
	if "--shots" in args:
		_shots()
	elif "--selftest" in args:
		_selftest()


func _open() -> void:
	_menu_root.visible = false
	_screen.visible = true
	_rebuild()


func _close() -> void:
	print("[loadout screen] left with: ", _state_line())
	_screen.visible = false
	_menu_root.visible = true


func _unhandled_input(event: InputEvent) -> void:
	if not _screen.visible or not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.physical_keycode:
		KEY_F1, KEY_F2, KEY_F3:
			_layout = event.physical_keycode - KEY_F1
			_open_slot = ""
			_rebuild()
		KEY_ESCAPE:
			if _open_slot != "":
				_open_slot = ""
				_rebuild()
			else:
				_close()
		_: return
	get_viewport().set_input_as_handled()


## Drag on the gun to turn it freely; it stays where he leaves it.
func _on_gun_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		_turn.x += event.relative.x * 0.01
		_turn.y = clampf(_turn.y + event.relative.y * 0.01, -PI / 2, PI / 2)
		_pose_guns()
	elif event is InputEventMouseButton and event.double_click:
		_turn = Vector2.ZERO
		_pose_guns()


func _pose_guns() -> void:
	# The camera looks down -X, so across the screen is Z and up it is Y.
	for pivot in _pivots:
		pivot.basis = Basis(Vector3.BACK, _turn.y) * Basis(Vector3.UP, _turn.x)


# --- The Loadout itself -----------------------------------------------------

func _carry(index: int, weapon: String) -> void:
	var other := 1 - index
	if _loadout[other] == weapon:
		_loadout[other] = _loadout[index]
	_loadout[index] = weapon
	_changed()


func _fit(weapon: String, slot: String, attachment: String) -> void:
	if attachment == "":
		_fitted[weapon].erase(slot)
	else:
		_fitted[weapon][slot] = attachment
	_open_slot = ""
	_changed()


func _changed() -> void:
	print("[loadout screen] ", _state_line())
	_rebuild()


func _gun_line(weapon: String) -> String:
	var parts := PackedStringArray()
	for slot: String in SLOTS:
		if _fitted[weapon].has(slot):
			parts.append(_fitted[weapon][slot])
	return "%s (%s)" % [weapon, ", ".join(parts) if not parts.is_empty() else "bare"]


func _state_line() -> String:
	return "layout %s | first %s | second %s" % [LAYOUTS[_layout], _gun_line(_loadout[0]), _gun_line(_loadout[1])]


## The gun's numbers bare, read from its Weapon Profile.
func _bare(weapon: String) -> Dictionary:
	var p: WeaponProfile = load("res://resources/weapons/%s.tres" % FILES[weapon])
	return {
		"bolt_speed": p.projectile_speed, "spread": p.spread_base_degrees,
		"aimed_spread": p.spread_base_degrees * p.ads_spread, "recoil": p.recoil_kick_degrees,
		"aim_time": 0.2 if weapon == "Pistol" else 0.3, "magazine": float(p.magazine_size),
		"reload": p.seconds_empty_to_full() if p.shell_reload else p.reload_tactical,
		"loudness": p.loudness, "zoom": p.ads_zoom, "seen": 1.0,
	}


## The same with every fitted Attachment's factors multiplied in.
func _built(weapon: String) -> Dictionary:
	var values := _bare(weapon)
	for slot: String in _fitted[weapon]:
		var changes: Dictionary = CHANGES[_fitted[weapon][slot]]
		for attribute: String in changes:
			values[attribute] *= changes[attribute]
	values.magazine = maxf(roundf(values.magazine), 1.0)
	return values


# --- Pieces every layout uses ----------------------------------------------

func _label(text: String, size: int, colour: Color = MenuStyle.TEXT) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", colour)
	return label


func _button(text: String, pressed: Callable, min_size := Vector2(0, 36), chosen := false) -> Button:
	var b := MenuStyle.button(text)
	b.custom_minimum_size = min_size
	b.add_theme_font_size_override("font_size", 16)
	if chosen:
		b.add_theme_color_override("font_color", MenuStyle.ACCENT)
		b.add_theme_stylebox_override("normal", b.get_theme_stylebox("pressed"))
	b.pressed.connect(pressed)
	return b


func _panel(child: Control) -> PanelContainer:
	var panel := MenuStyle.panel()
	panel.add_child(child)
	return panel


## One comparison bar: grey up to the lower of bare and built, then green
## for what the Attachments gained or red for what they cost.
func _bar(bar: Array, bare: Dictionary, built: Dictionary, width: float) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var name := _label(bar[0], 14, MenuStyle.DIM_TEXT)
	name.custom_minimum_size = Vector2(118, 0)
	row.add_child(name)
	var track := ColorRect.new()
	track.color = Color(1, 1, 1, 0.08)
	track.custom_minimum_size = Vector2(width, 10)
	track.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(track)
	var score := func(v: float) -> float:
		var s: float = clampf(v / bar[2], 0.0, 1.0)
		return 1.0 - s if bar[3] else s
	var a: float = score.call(bare[bar[1]])
	var b: float = score.call(built[bar[1]])
	var base := ColorRect.new()
	base.color = Color(MenuStyle.TEXT, 0.75)
	base.size = Vector2(width * minf(a, b), 10)
	track.add_child(base)
	if not is_equal_approx(a, b):
		var change := ColorRect.new()
		change.color = GAIN if b > a else COST
		change.position = Vector2(width * minf(a, b), 0)
		change.size = Vector2(maxf(width * absf(b - a), 3.0), 10)
		track.add_child(change)
	var text: String = bar[4] % built[bar[1]]
	var value := _label(text, 14, MenuStyle.TEXT if is_equal_approx(a, b) else (GAIN if b > a else COST))
	value.custom_minimum_size = Vector2(64, 0)
	row.add_child(value)
	return row


func _bars(weapon: String, width: float) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	var bare := _bare(weapon)
	var built := _built(weapon)
	for bar: Array in BARS:
		box.add_child(_bar(bar, bare, built, width))
	if built.seen > 1.0:
		box.add_child(_label("Crew notice him sooner", 14, COST))
	return box


## The gun side-on in a little world of its own, turned by dragging.
func _preview(weapon: String, size: Vector2) -> SubViewportContainer:
	var container := SubViewportContainer.new()
	container.custom_minimum_size = size
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_STOP
	container.mouse_default_cursor_shape = Control.CURSOR_DRAG
	container.gui_input.connect(_on_gun_input)
	var viewport := SubViewport.new()
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.size = Vector2i(size)
	container.add_child(viewport)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_CLEAR_COLOR
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.6, 0.7, 0.9)
	environment.ambient_light_energy = 0.6
	var world := WorldEnvironment.new()
	world.environment = environment
	viewport.add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 140, 0)
	sun.light_energy = 2.0
	viewport.add_child(sun)
	var camera := Camera3D.new()
	camera.position = Vector3(1.9 if weapon != "Pistol" else 0.75, 0.08, 0)
	camera.fov = 30.0 * minf(1.0, 420.0 / size.x * 0.75 + 0.25)
	camera.rotation_degrees = Vector3(-4, 90, 0)
	viewport.add_child(camera)
	var pivot := Node3D.new()
	viewport.add_child(pivot)
	var model: Node3D = load("res://scenes/weapons/%s_model.tscn" % FILES[weapon]).instantiate()
	model.position = Vector3(0, -0.07, 0.0 if weapon == "Pistol" else 0.08)
	pivot.add_child(model)
	_pivots.append(pivot)
	_pose_guns()
	return container


func _rebuild() -> void:
	_pivots.clear()
	for child in _screen.get_children():
		child.queue_free()
	var shade := ColorRect.new()
	shade.color = Color(0.01, 0.015, 0.03, 0.82)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_screen.add_child(shade)

	var frame := MarginContainer.new()
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		frame.add_theme_constant_override("margin_" + side, 36)
	_screen.add_child(frame)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	frame.add_child(column)

	var top := HBoxContainer.new()
	var title := MenuStyle.heading("LOADOUT", 34)
	top.add_child(title)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)
	top.add_child(_button("Back", _close, Vector2(120, 40)))
	column.add_child(top)

	_body = Control.new()
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_body)
	match _layout:
		0: _build_workbench()
		1: _build_columns()
		2: _build_two_up()

	var bar := HBoxContainer.new()
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.add_theme_constant_override("separation", 8)
	bar.add_child(_label("PROTOTYPE LAYOUT", 13, MenuStyle.DIM_TEXT))
	for i in LAYOUTS.size():
		bar.add_child(_button("F%d  %s" % [i + 1, LAYOUTS[i]], func() -> void:
			_layout = i
			_open_slot = ""
			_rebuild(), Vector2(150, 32), i == _layout))
	column.add_child(bar)


func _fill(control: Control) -> void:
	control.set_anchors_preset(Control.PRESET_FULL_RECT)
	_body.add_child(control)


# --- F1: workbench -----------------------------------------------------------

func _build_workbench() -> void:
	var weapon: String = _loadout[_editing]
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	_fill(row)

	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 10)
	row.add_child(left)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	for i in 2:
		tabs.add_child(_button("%s   %s" % ["FIRST" if i == 0 else "SECOND", _loadout[i].to_upper()], func() -> void:
			_editing = i
			_open_slot = ""
			_rebuild(), Vector2(250, 44), i == _editing))
	left.add_child(tabs)
	var swap := HBoxContainer.new()
	swap.add_theme_constant_override("separation", 8)
	swap.add_child(_label("Carry here:", 14, MenuStyle.DIM_TEXT))
	for other: String in WEAPONS:
		swap.add_child(_button(other, _carry.bind(_editing, other), Vector2(0, 30), other == weapon))
	left.add_child(swap)

	var bench := Control.new()
	bench.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bench.custom_minimum_size = Vector2(700, 380)
	left.add_child(bench)
	var gun := _preview(weapon, Vector2(700, 380))
	gun.set_anchors_preset(Control.PRESET_FULL_RECT)
	bench.add_child(gun)
	for slot: String in SLOTS:
		var has: bool = FIT[weapon].has(slot)
		var fitted: String = _fitted[weapon].get(slot, "")
		var tag := _button("%s\n%s" % [slot.to_upper(), fitted if fitted != "" else ("empty" if has else "no Slot")],
			func() -> void:
				_open_slot = "" if _open_slot == slot else slot
				_rebuild(), Vector2(170, 52), fitted != "" or _open_slot == slot)
		tag.disabled = not has
		tag.add_theme_font_size_override("font_size", 14)
		tag.anchor_left = TAG_AT[slot].x
		tag.anchor_top = TAG_AT[slot].y
		tag.anchor_right = TAG_AT[slot].x
		tag.anchor_bottom = TAG_AT[slot].y
		tag.offset_left = -85
		tag.offset_top = -26
		bench.add_child(tag)

	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(430, 0)
	right.add_theme_constant_override("separation", 12)
	row.add_child(right)
	if _open_slot != "":
		var list := VBoxContainer.new()
		list.add_theme_constant_override("separation", 6)
		list.add_child(_label("%s  ·  %s" % [weapon.to_upper(), _open_slot.to_upper()], 16, MenuStyle.ACCENT))
		list.add_child(_button("None", _fit.bind(weapon, _open_slot, ""), Vector2(360, 34), not _fitted[weapon].has(_open_slot)))
		for attachment: String in FIT[weapon][_open_slot]:
			list.add_child(_button(attachment, _fit.bind(weapon, _open_slot, attachment), Vector2(360, 34),
				_fitted[weapon].get(_open_slot, "") == attachment))
			list.add_child(_label("    " + WORDS[attachment], 13, MenuStyle.DIM_TEXT))
		right.add_child(_panel(list))
	var stats := VBoxContainer.new()
	stats.add_child(_label("%s AS BUILT" % weapon.to_upper(), 16, MenuStyle.ACCENT))
	stats.add_child(_bars(weapon, 180))
	right.add_child(_panel(stats))


# --- F2: columns -------------------------------------------------------------

func _build_columns() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	_fill(row)

	var guns := VBoxContainer.new()
	guns.add_theme_constant_override("separation", 10)
	guns.add_child(_label("WEAPONS", 14, MenuStyle.DIM_TEXT))
	for weapon: String in WEAPONS:
		var at: int = _loadout.find(weapon)
		var badge: String = ["   · FIRST", "   · SECOND"][at] if at >= 0 else ""
		guns.add_child(_button(weapon + badge, func() -> void:
			_column_gun = weapon
			_rebuild(), Vector2(250, 46), weapon == _column_gun))
		if at < 0:
			var carry := HBoxContainer.new()
			carry.add_theme_constant_override("separation", 6)
			carry.add_child(_button("carry first", _carry.bind(0, weapon), Vector2(120, 26)))
			carry.add_child(_button("carry second", _carry.bind(1, weapon), Vector2(124, 26)))
			guns.add_child(carry)
	row.add_child(guns)

	var weapon := _column_gun
	var slots := VBoxContainer.new()
	slots.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slots.add_theme_constant_override("separation", 12)
	slots.add_child(_label("%s  ·  ATTACHMENTS" % weapon.to_upper(), 14, MenuStyle.DIM_TEXT))
	for slot: String in SLOTS:
		var line := VBoxContainer.new()
		line.add_theme_constant_override("separation", 4)
		line.add_child(_label(slot.to_upper(), 15, MenuStyle.ACCENT))
		if not FIT[weapon].has(slot):
			line.add_child(_label("This weapon has no %s Slot" % slot, 14, MenuStyle.DIM_TEXT))
		else:
			var chips := HBoxContainer.new()
			chips.add_theme_constant_override("separation", 6)
			var fitted: String = _fitted[weapon].get(slot, "")
			chips.add_child(_button("None", _fit.bind(weapon, slot, ""), Vector2(70, 34), fitted == ""))
			for attachment: String in FIT[weapon][slot]:
				chips.add_child(_button(attachment, _fit.bind(weapon, slot, attachment), Vector2(0, 34), fitted == attachment))
			line.add_child(chips)
			line.add_child(_label(WORDS[fitted] if fitted != "" else "as it comes", 13, MenuStyle.DIM_TEXT))
		slots.add_child(line)
	row.add_child(_panel(slots))

	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 8)
	right.add_child(_preview(weapon, Vector2(420, 210)))
	right.add_child(_panel(_bars(weapon, 170)))
	row.add_child(right)


# --- F3: two-up --------------------------------------------------------------

func _build_two_up() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	_fill(row)
	for i in 2:
		var weapon: String = _loadout[i]
		var card := VBoxContainer.new()
		card.custom_minimum_size = Vector2(520, 0)
		card.add_theme_constant_override("separation", 8)
		var head := HBoxContainer.new()
		head.add_theme_constant_override("separation", 12)
		head.add_child(_label("FIRST" if i == 0 else "SECOND", 16, MenuStyle.ACCENT))
		var pick := OptionButton.new()
		pick.custom_minimum_size = Vector2(240, 36)
		for other: String in WEAPONS:
			pick.add_item(other)
		pick.select(WEAPONS.find(weapon))
		pick.item_selected.connect(func(at: int) -> void: _carry(i, WEAPONS[at]))
		head.add_child(pick)
		card.add_child(head)
		card.add_child(_preview(weapon, Vector2(500, 170)))
		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 12)
		grid.add_theme_constant_override("v_separation", 6)
		for slot: String in SLOTS:
			grid.add_child(_label(slot, 15, MenuStyle.DIM_TEXT))
			if not FIT[weapon].has(slot):
				grid.add_child(_label("no Slot", 14, MenuStyle.DIM_TEXT))
				continue
			var options := OptionButton.new()
			options.custom_minimum_size = Vector2(260, 32)
			options.add_item("None")
			var fits: Array = FIT[weapon][slot]
			for attachment: String in fits:
				options.add_item(attachment)
			options.select(fits.find(_fitted[weapon].get(slot, "")) + 1)
			options.item_selected.connect(func(at: int) -> void: _fit(weapon, slot, "" if at == 0 else fits[at - 1]))
			grid.add_child(options)
		card.add_child(grid)
		card.add_child(_bars(weapon, 200))
		row.add_child(_panel(card))


# --- Checks ------------------------------------------------------------------

func _selftest() -> void:
	_open()
	_carry(0, "Assault Rifle")
	print("[selftest] carrying the second gun as first swaps them: ", _loadout)
	_fit("Assault Rifle", "Magazine", "Drum")
	_fit("Assault Rifle", "Barrel", "Suppressor")
	var built := _built("Assault Rifle")
	print("[selftest] drum and suppressor: magazine ", built.magazine, " loudness ", built.loudness, " bolt ", built.bolt_speed)
	for i in LAYOUTS.size():
		_layout = i
		_rebuild()
		await get_tree().process_frame
		print("[selftest] built layout ", LAYOUTS[i])
	get_tree().quit()


func _shots() -> void:
	DirAccess.make_dir_recursive_absolute("res://.godot/shots/proto_loadout")
	_open()
	_fitted["Assault Rifle"] = {"Sight": "Combat Scope", "Barrel": "Suppressor", "Magazine": "Drum", "Stock": "Light Stock"}
	_fitted["Pistol"] = {"Barrel": "Suppressor", "Underbarrel": "Laser"}
	_editing = 1
	for i in LAYOUTS.size():
		_layout = i
		_open_slot = "Underbarrel" if i == 0 else ""
		_rebuild()
		for f in 8:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://.godot/shots/proto_loadout/%d_%s.png" % [i + 1, LAYOUTS[i]])
	print("SHOTS_DONE")
	get_tree().quit()
