class_name LoadoutScreen
extends Control
## The Loadout screen, a workbench over the main menu's darkened backdrop
## (`.scratch/weapon-attachments/spec.md`, "The Loadout screen"): FIRST and
## SECOND tabs, a row of the four weapons to carry in the chosen place, the
## gun still and side-on in the middle showing its fitted Attachments with a
## tag per Slot hung round it, the open Slot's list at the top right and the
## Built Weapon's bars against the bare gun under it. Drag turns the gun and
## it stays; a double click puts it back. Back or Esc saves the Loadout and
## closes the screen ([signal closed]). Mouse, or keyboard focus alone.

signal closed

const GAIN := Color(0.35, 0.9, 0.45)
const COST := Color(0.95, 0.35, 0.3)
const PLACES := ["FIRST", "SECOND"]
## Where each Slot's tag hangs round the gun, as a share of the bench; a tag
## is kept wholly inside the bench.
const TAG_AT := {
	Attachment.Slot.SIGHT: Vector2(0.50, 0.14),
	Attachment.Slot.BARREL: Vector2(0.10, 0.26),
	Attachment.Slot.UNDERBARREL: Vector2(0.24, 0.84),
	Attachment.Slot.MAGAZINE: Vector2(0.56, 0.90),
	Attachment.Slot.STOCK: Vector2(0.88, 0.38),
}
const TAG_SIZE := Vector2(196, 52)
## Left and right go round the tags in this order.
const RING: Array[Attachment.Slot] = [Attachment.Slot.BARREL, Attachment.Slot.SIGHT, Attachment.Slot.STOCK,
		Attachment.Slot.MAGAZINE, Attachment.Slot.UNDERBARREL]
## Radians the gun turns per pixel dragged.
const TURN_PER_PIXEL := 0.01
## The bench camera's field of view across, degrees, and the share of the
## bench's width the gun spans side-on.
const CAMERA_FOV := 30.0
const FILL := 0.6
const BAR_WIDTH := 180.0
const BAR_HEIGHT := 10.0

## The Loadout being edited; saved when the screen is left.
var loadout: Loadout
## The place on the bench: 0 for FIRST, 1 for SECOND.
var place := 0
## The Slot whose list is open, or -1.
var open_slot := -1
## How far the gun is turned by dragging: yaw and pitch, radians.
var turn := Vector2.ZERO

var _tabs: Array[Button] = []
var _weapon_buttons := {}
var _tags := {}
var _bench: Control
var _view: SubViewportContainer
var _camera: Camera3D
var _sun: DirectionalLight3D
var _pivot: Node3D
## Weapon to the holder centring its model on the pivot.
var _holders := {}
## Weapon to how far the camera stands from it, and on which side.
var _framing := {}
var _shown: WeaponProfile
var _built: WeaponProfile
var _list_panel: PanelContainer
var _list_title: Label
var _list_box: VBoxContainer
var _list: Array = []
var _list_buttons: Array[Button] = []
var _list_lines: Array[Label] = []
var _stats_title: Label
var _bars := {}
var _notice: Label
var _back: Button


func _ready() -> void:
	_fill(self)
	var shade := ColorRect.new()
	shade.color = Color(0.01, 0.015, 0.03, 0.82)
	_fill(shade)
	add_child(shade)
	var frame := MarginContainer.new()
	_fill(frame)
	for side in ["left", "right", "top", "bottom"]:
		frame.add_theme_constant_override("margin_" + side, 32)
	add_child(frame)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	frame.add_child(column)

	var top := HBoxContainer.new()
	top.add_child(MenuStyle.heading("LOADOUT", 34))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)
	_back = _button("Back", leave, Vector2(120, 40))
	_back.name = "Back"
	top.add_child(_back)
	column.add_child(top)

	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 24)
	column.add_child(row)
	row.add_child(_workbench())
	row.add_child(_side())
	_pose()


## Opens the screen on [param edited], the first place on the bench.
func open(edited: Loadout) -> void:
	loadout = edited
	place = 0
	open_slot = -1
	visible = true
	_refresh()
	_tabs[0].grab_focus()


## Saves the Loadout and closes the screen.
func leave() -> void:
	loadout.save()
	open_slot = -1
	visible = false
	closed.emit()


## Puts [param index]'s place (0 FIRST, 1 SECOND) on the bench.
func choose_place(index: int) -> void:
	place = index
	open_slot = -1
	_refresh()


## Carries [param weapon] in the place on the bench; the gun in the other
## place swaps with it.
func carry(weapon: WeaponProfile) -> void:
	if place == 0:
		loadout.set_first(weapon)
	else:
		loadout.set_second(weapon)
	open_slot = -1
	_refresh()


## Opens [param slot]'s list, or closes it when it is the one open.
func toggle_slot(slot: Attachment.Slot) -> void:
	open_slot = -1 if open_slot == slot else slot
	_refresh()
	if open_slot == slot:
		for i in _list.size():
			if is_marked(_list[i]):
				_list_buttons[i].grab_focus()
	else:
		_tags[slot].grab_focus()


## Fits [param attachment] (null for None) in the open Slot and closes the list.
func fit(attachment: Attachment) -> void:
	var slot := open_slot
	if slot < 0:
		return
	loadout.set_attachment(_shown, slot as Attachment.Slot, attachment)
	open_slot = -1
	_refresh()
	_tags[slot].grab_focus()


## The gun on the bench back side-on.
func reset_turn() -> void:
	turn = Vector2.ZERO
	_pose()


# --- What a check or a screenshot reads ------------------------------------

func tab(index: int) -> Button:
	return _tabs[index]


func weapon_button(weapon: WeaponProfile) -> Button:
	return _weapon_buttons[weapon]


func tag(slot: Attachment.Slot) -> Button:
	return _tags[slot]


func tags() -> Array:
	return _tags.values()


func back_button() -> Button:
	return _back


## The open list's entries in order: null for None, then each Attachment.
func list_items() -> Array:
	return _list.duplicate()


## The open list's button for [param attachment] (null for None).
func list_button(attachment: Attachment) -> Button:
	var at := _list.find(attachment)
	return _list_buttons[at] if at >= 0 else null


## The gain and cost line under [param attachment] in the open list.
func list_line(attachment: Attachment) -> String:
	var at := _list.find(attachment)
	return _list_lines[at].text if at >= 0 and _list_lines[at] != null else ""


## Whether [param attachment] (null for None) is the one marked fitted.
func is_marked(attachment: Attachment) -> bool:
	return open_slot >= 0 and loadout.get_attachment(_shown, open_slot as Attachment.Slot) == attachment


## The row of the bar for the attribute named [param attribute_name], with
## its `value` and `verdict` in its meta, its number in `Value` and the
## coloured part in `Track/Change`.
func bar(attribute_name: String) -> Control:
	return _bars.get(attribute_name)


func notice_label() -> Label:
	return _notice


func shown_weapon() -> WeaponProfile:
	return _shown


func shown_build() -> WeaponProfile:
	return _built


## The instance of the bench gun's `model` scene, with its [WeaponModel].
func shown_model() -> Node3D:
	return _holders[_shown].get_child(0)


func gun_view() -> Control:
	return _view


func pivot() -> Node3D:
	return _pivot


# --- Building the screen -----------------------------------------------------

## Stretches [param control] over its parent, whatever size either has now.
static func _fill(control: Control) -> void:
	control.anchor_left = 0.0
	control.anchor_top = 0.0
	control.anchor_right = 1.0
	control.anchor_bottom = 1.0
	control.offset_left = 0.0
	control.offset_top = 0.0
	control.offset_right = 0.0
	control.offset_bottom = 0.0


func _button(text: String, pressed: Callable, min_size := Vector2(0, 36)) -> Button:
	var b := MenuStyle.button(text)
	b.custom_minimum_size = min_size
	b.add_theme_font_size_override("font_size", 16)
	b.set_meta("plain", b.get_theme_stylebox("normal"))
	b.set_meta("chosen", b.get_theme_stylebox("pressed"))
	b.pressed.connect(pressed)
	return b


## Marks [param b] as the one chosen, in amber, or not.
func _mark(b: Button, chosen: bool) -> void:
	b.add_theme_color_override("font_color", MenuStyle.ACCENT if chosen else MenuStyle.TEXT)
	b.add_theme_stylebox_override("normal", b.get_meta("chosen" if chosen else "plain"))


func _label(text: String, size: int, colour: Color = MenuStyle.TEXT) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", colour)
	return label


func _panel(child: Control) -> PanelContainer:
	var panel := MenuStyle.panel()
	var box: StyleBoxFlat = panel.get_theme_stylebox("panel").duplicate()
	box.content_margin_left = 18
	box.content_margin_right = 18
	box.content_margin_top = 14
	box.content_margin_bottom = 14
	panel.add_theme_stylebox_override("panel", box)
	panel.add_child(child)
	return panel


func _workbench() -> Control:
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 10)
	var tabs := HBoxContainer.new()
	tabs.name = "Tabs"
	tabs.add_theme_constant_override("separation", 8)
	for i in 2:
		var b := _button(PLACES[i], choose_place.bind(i), Vector2(260, 44))
		b.name = PLACES[i].capitalize()
		tabs.add_child(b)
		_tabs.append(b)
	left.add_child(tabs)
	var carry_row := HBoxContainer.new()
	carry_row.name = "Weapons"
	carry_row.add_theme_constant_override("separation", 8)
	carry_row.add_child(_label("Carry here:", 14, MenuStyle.DIM_TEXT))
	for weapon in Loadout.all_weapons():
		var b := _button(_weapon_title(weapon), carry.bind(weapon), Vector2(0, 30))
		b.name = Loadout.weapon_name(weapon)
		carry_row.add_child(b)
		_weapon_buttons[weapon] = b
	left.add_child(carry_row)

	_bench = Control.new()
	_bench.name = "Bench"
	_bench.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_bench.custom_minimum_size = Vector2(640, 360)
	_bench.resized.connect(_place_tags)
	left.add_child(_bench)
	_bench.add_child(_gun_view())
	for slot: Attachment.Slot in RING:
		var b := _button("", toggle_slot.bind(slot), TAG_SIZE)
		b.name = String(Attachment.Slot.find_key(slot)).capitalize()
		b.add_theme_font_size_override("font_size", 14)
		b.add_theme_color_override("font_disabled_color", Color(MenuStyle.DIM_TEXT, 0.55))
		var off: StyleBoxFlat = (b.get_meta("plain") as StyleBoxFlat).duplicate()
		off.bg_color = Color(off.bg_color, 0.35)
		off.border_color = Color(1, 1, 1, 0.04)
		b.add_theme_stylebox_override("disabled", off)
		b.size = TAG_SIZE
		_bench.add_child(b)
		_tags[slot] = b
	return left


## The gun alone in a little world, lit, seen side-on, turned by dragging.
func _gun_view() -> Control:
	_view = SubViewportContainer.new()
	_view.name = "Gun"
	_fill(_view)
	_view.stretch = true
	_view.mouse_filter = Control.MOUSE_FILTER_STOP
	_view.mouse_default_cursor_shape = Control.CURSOR_DRAG
	_view.gui_input.connect(_on_gun_input)
	var viewport := SubViewport.new()
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	_view.add_child(viewport)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_CLEAR_COLOR
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.6, 0.7, 0.9)
	environment.ambient_light_energy = 0.6
	var world := WorldEnvironment.new()
	world.environment = environment
	viewport.add_child(world)
	_sun = DirectionalLight3D.new()
	_sun.light_energy = 2.0
	viewport.add_child(_sun)
	_camera = Camera3D.new()
	_camera.keep_aspect = Camera3D.KEEP_WIDTH
	_camera.fov = CAMERA_FOV
	_camera.near = 0.01
	viewport.add_child(_camera)
	_pivot = Node3D.new()
	_pivot.name = "Pivot"
	viewport.add_child(_pivot)
	return _view


func _side() -> Control:
	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(430, 0)
	right.add_theme_constant_override("separation", 10)
	_list_box = VBoxContainer.new()
	_list_box.add_theme_constant_override("separation", 4)
	_list_title = _label("", 16, MenuStyle.ACCENT)
	_list_box.add_child(_list_title)
	_list_panel = _panel(_list_box)
	_list_panel.name = "List"
	right.add_child(_list_panel)
	var stats := VBoxContainer.new()
	stats.name = "Bars"
	stats.add_theme_constant_override("separation", 5)
	_stats_title = _label("", 16, MenuStyle.ACCENT)
	stats.add_child(_stats_title)
	for attribute in WeaponAttributes.bars():
		stats.add_child(_bar_row(attribute))
	_notice = _label("", 14, COST)
	_notice.name = "Notice"
	stats.add_child(_notice)
	right.add_child(_panel(stats))
	return right


func _bar_row(attribute: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.name = String(attribute.name).replace(" ", "")
	row.add_theme_constant_override("separation", 10)
	var title := _label(attribute.name, 14, MenuStyle.DIM_TEXT)
	title.custom_minimum_size = Vector2(118, 0)
	row.add_child(title)
	var track := ColorRect.new()
	track.name = "Track"
	track.color = Color(1, 1, 1, 0.08)
	track.custom_minimum_size = Vector2(BAR_WIDTH, BAR_HEIGHT)
	track.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(track)
	var base := ColorRect.new()
	base.name = "Base"
	base.color = Color(MenuStyle.TEXT, 0.75)
	track.add_child(base)
	var change := ColorRect.new()
	change.name = "Change"
	track.add_child(change)
	var number := _label("", 14)
	number.name = "Value"
	number.custom_minimum_size = Vector2(72, 0)
	row.add_child(number)
	_bars[attribute.name] = row
	return row


static func _weapon_title(weapon: WeaponProfile) -> String:
	return Loadout.weapon_name(weapon).capitalize()


# --- Keeping it up to date ---------------------------------------------------

func _refresh() -> void:
	_shown = loadout.get_first() if place == 0 else loadout.get_second()
	_built = _shown.build(loadout.choice(_shown)) as WeaponProfile
	if _built == null:
		_built = _shown.build({}) as WeaponProfile
	var carried := [loadout.get_first(), loadout.get_second()]
	for i in 2:
		_tabs[i].text = "%s   %s" % [PLACES[i], _weapon_title(carried[i]).to_upper()]
		_mark(_tabs[i], i == place)
	for weapon: WeaponProfile in _weapon_buttons:
		_mark(_weapon_buttons[weapon], weapon == _shown)
	_refresh_tags()
	_refresh_list()
	_refresh_bars()
	_show_gun()


func _refresh_tags() -> void:
	var open: Array[Button] = []
	for slot: Attachment.Slot in RING:
		var b: Button = _tags[slot]
		var has := not _shown.fits_in(slot).is_empty()
		var fitted := loadout.get_attachment(_shown, slot)
		var under := fitted.display_name if fitted != null else ("empty" if has else "no Slot")
		b.text = "%s\n%s" % [String(Attachment.Slot.find_key(slot)), under]
		b.disabled = not has
		b.focus_mode = Control.FOCUS_ALL if has else Control.FOCUS_NONE
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if has else Control.CURSOR_ARROW
		_mark(b, has and (fitted != null or open_slot == slot))
		if has:
			open.append(b)
	# Left and right go round the tags that can be opened.
	for i in open.size():
		var b := open[i]
		b.focus_neighbor_right = b.get_path_to(open[(i + 1) % open.size()])
		b.focus_neighbor_left = b.get_path_to(open[(i - 1 + open.size()) % open.size()])


func _place_tags() -> void:
	var room := _bench.size
	for slot: Attachment.Slot in _tags:
		var b: Button = _tags[slot]
		var at: Vector2 = room * TAG_AT[slot] - TAG_SIZE / 2.0
		b.position = at.clamp(Vector2.ZERO, (room - TAG_SIZE).max(Vector2.ZERO))
		b.size = TAG_SIZE


func _refresh_list() -> void:
	for child in _list_box.get_children():
		if child != _list_title:
			_list_box.remove_child(child)
			child.queue_free()
	_list.clear()
	_list_buttons.clear()
	_list_lines.clear()
	_list_panel.visible = open_slot >= 0
	if open_slot < 0:
		return
	var slot := open_slot as Attachment.Slot
	_list_title.text = "%s  ·  %s" % [_weapon_title(_shown).to_upper(), Attachment.Slot.find_key(slot)]
	var entries: Array = [null]
	entries.append_array(_shown.fits_in(slot))
	for attachment: Attachment in entries:
		var b := _button("None" if attachment == null else attachment.display_name, fit.bind(attachment), Vector2(390, 32))
		b.name = "None" if attachment == null else attachment.resource_path.get_file().get_basename()
		_list_box.add_child(b)
		_list.append(attachment)
		_list_buttons.append(b)
		_mark(b, is_marked(attachment))
		var line: Label = null
		if attachment != null:
			line = _label(WeaponAttributes.describe(attachment), 13, MenuStyle.DIM_TEXT)
			line.custom_minimum_size = Vector2(390, 0)
			line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			line.add_theme_constant_override("line_spacing", -2)
			var indent := MarginContainer.new()
			indent.add_theme_constant_override("margin_left", 14)
			indent.add_child(line)
			_list_box.add_child(indent)
		_list_lines.append(line)


func _refresh_bars() -> void:
	var bare: WeaponProfile = _built.bare as WeaponProfile if _built.bare != null else _shown
	_stats_title.text = "%s AS BUILT" % _weapon_title(_shown).to_upper()
	for attribute in WeaponAttributes.bars():
		var row: Control = _bars[attribute.name]
		var was := WeaponAttributes.value(attribute, bare)
		var now := WeaponAttributes.value(attribute, _built)
		var verdict := WeaponAttributes.verdict(attribute, was, now)
		var a := WeaponAttributes.score(attribute, was)
		var b := WeaponAttributes.score(attribute, now)
		row.set_meta("value", now)
		row.set_meta("verdict", verdict)
		var colour := MenuStyle.TEXT if verdict == 0 else (GAIN if verdict > 0 else COST)
		var base: ColorRect = row.get_node("Track/Base")
		base.position = Vector2.ZERO
		base.size = Vector2(BAR_WIDTH * minf(a, b), BAR_HEIGHT)
		var change: ColorRect = row.get_node("Track/Change")
		change.visible = verdict != 0
		change.color = colour
		change.position = Vector2(BAR_WIDTH * minf(a, b), 0)
		change.size = Vector2(maxf(BAR_WIDTH * absf(b - a), 3.0), BAR_HEIGHT)
		var number: Label = row.get_node("Value")
		number.text = attribute.format % now
		number.add_theme_color_override("font_color", colour)
	_notice.text = WeaponAttributes.notice(_built)
	_notice.visible = _notice.text != ""


## Puts the gun on the bench, fitted with what the Loadout gives it, framed
## side-on with the barrel to the left.
func _show_gun() -> void:
	if not _holders.has(_shown):
		_holders[_shown] = _hold(_shown)
	for weapon: WeaponProfile in _holders:
		(_holders[weapon] as Node3D).visible = weapon == _shown
	WeaponModel.of(shown_model()).fit(_built)
	var framing: Vector2 = _framing[_shown]
	_camera.look_at_from_position(Vector3(framing.x * framing.y, 0, 0), Vector3.ZERO)
	_sun.look_at_from_position(Vector3(framing.y, 1.2, 0.6), Vector3.ZERO)


## A holder for [param weapon]'s model, centring it bare on the pivot, and
## its framing: the camera's distance, and the side (1 or -1) that puts the
## muzzle on the left.
func _hold(weapon: WeaponProfile) -> Node3D:
	var holder := Node3D.new()
	holder.name = Loadout.weapon_name(weapon)
	_pivot.add_child(holder)
	var model: Node3D = weapon.model.instantiate()
	holder.add_child(model)
	var fitting := WeaponModel.of(model)
	var box := AABB()
	var first := true
	for found in model.find_children("*", "MeshInstance3D", true, false):
		var mesh := found as MeshInstance3D
		if mesh.mesh == null or not _shows_in(mesh, holder):
			continue
		var part := (holder.global_transform.affine_inverse() * mesh.global_transform) * mesh.get_aabb()
		box = part if first else box.merge(part)
		first = false
	holder.position = -box.get_center()
	var muzzle_z := (holder.global_transform.affine_inverse() * fitting.muzzle().global_transform).origin.z
	# Seen from +X the screen's right is -Z: a muzzle toward -Z wants the
	# camera on -X to sit on the left.
	var side := -1.0 if muzzle_z < 0.0 else 1.0
	# Kept clear of the tags above and below too: a squat gun is framed as
	# if it were longer.
	var across := maxf(box.size.z, box.size.y * 1.8)
	var distance := (across / 2.0) / tan(deg_to_rad(CAMERA_FOV / 2.0)) / FILL + box.size.x / 2.0
	_framing[weapon] = Vector2(distance, side)
	return holder


static func _shows_in(node: Node3D, top: Node3D) -> bool:
	var at: Node = node
	while at != top:
		if at is Node3D and not (at as Node3D).visible:
			return false
		at = at.get_parent()
	return true


func _pose() -> void:
	# The camera looks along X, so across the screen is Z and up it is Y.
	_pivot.basis = Basis(Vector3.BACK, turn.y) * Basis(Vector3.UP, turn.x)


## Drag on the gun to turn it freely; it stays where he leaves it. A double
## click puts it back side-on.
func _on_gun_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		turn.x += event.relative.x * TURN_PER_PIXEL
		turn.y = clampf(turn.y + event.relative.y * TURN_PER_PIXEL, -PI / 2.0, PI / 2.0)
		_pose()
		accept_event()
	elif event is InputEventMouseButton and event.double_click:
		reset_turn()
		accept_event()


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not event.is_action_pressed("ui_cancel"):
		return
	if open_slot >= 0:
		toggle_slot(open_slot as Attachment.Slot)
	else:
		leave()
	get_viewport().set_input_as_handled()
