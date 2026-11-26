class_name SandboxSheetView
extends CanvasLayer
## The in-Raid Sandbox sheet, debug builds only. F1 pauses the Raid and
## shows every [SandboxSheet] table: weapons as columns, attributes as rows.
## A number changed here changes the live Resource, so it is in the next
## shot; F1 or Esc closes the sheet and the Raid resumes with it. A cell
## that differs from disk turns amber and shows the disk value beside it.
## Save writes the resources and `docs/sandbox.md`; Revert puts back what is
## on disk. Crew read their weapon and Gunnery live, so those need nothing
## more. Health is taken at spawn, so a Health change is pushed onto the
## Pirate (refilled) and every crew member still standing.
##
## The weapon columns are all four weapons, whatever he carries. The guns
## he carries are Built Weapons: beside a bare number each shows its Built
## Weapon's where they differ, and a dialled bare number or Attachment
## factor rebuilds them in place, so it is in the gun in hand before the
## sheet closes. The strip at the top picks the FIRST and SECOND gun and
## what is in each of their Slots, on a [Loadout] of its own; closing the
## sheet puts those two Built Weapons in his hands, magazines full. It
## never writes the saved Loadout.
##
## Esc belongs to the sheet while it is open, and to the pause menu
## otherwise; F1 does nothing over the pause menu or once the Raid is over.

const CHANGED := Color(1.0, 0.78, 0.3)
const HEADING := Color(0.6, 0.85, 1.0)
const DIM := Color(1, 1, 1, 0.5)
const BUILT := Color(0.55, 0.9, 0.65)
## Width of an Attachment factor cell and its column's heading.
const FACTOR_WIDTH := 70.0
const PLACES := ["FIRST", "SECOND"]

var sheet: SandboxSheet

## The Raid scene: its player, hud and pause_menu.
var _raid: Node
var _root: Control
var _status: Label
var _save: Button
var _revert: Button
## "table|key|column" -> the cell's Control, and the Label showing its disk value.
var _cells := {}
var _disk_labels := {}
## "table|key|column" -> the Label showing the carried Built Weapon's value.
var _built_labels := {}
## The debug strip's own Loadout, read from what he carries at each open;
## applied on close only if the strip changed it.
var _strip: Loadout
var _strip_changed := false
var _strip_box: VBoxContainer
## place -> the gun's OptionButton; "place|slot" -> that Slot's OptionButton.
var _strip_pickers := {}


## Adds the sheet to [param raid] and returns it; nothing, in a release build.
static func attach(raid: Node, debug: bool = OS.is_debug_build()) -> SandboxSheetView:
	if not debug:
		return null
	var view := SandboxSheetView.new()
	view.name = "SandboxSheet"
	view._raid = raid
	raid.add_child(view)
	return view


func _ready() -> void:
	layer = 12
	process_mode = Node.PROCESS_MODE_ALWAYS
	var player: Node = _raid.get("player")
	# The live Resources: the four bare Profiles, the crew's own Gunnery and
	# every Attachment, as cached and shared with the game.
	sheet = SandboxSheet.build(Loadout.all_weapons(), player.sandbox, Gunnery.all(), SandboxSheet.all_attachments())
	_build()
	_root.visible = false


func is_open() -> bool:
	return _root.visible


func open() -> void:
	if is_open() or not _can_open():
		return
	# The Inspector may have saved a file since the sheet was last open.
	for table in sheet.tables:
		table.reload_disk()
	var carried: Array[WeaponProfile] = []
	for weapon: WeaponProfile in _raid.get("player").weapons:
		if weapon.bare != null:
			carried.append(weapon)
	sheet.carried = carried
	_strip = _loadout_of(_raid.get("player").weapons)
	_strip_changed = false
	_draw_strip()
	_refresh()
	_root.visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func close() -> void:
	if not is_open():
		return
	_root.visible = false
	get_viewport().gui_release_focus()
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	# The click on a cell is not a trigger pull.
	Input.action_release("shoot")
	if _strip_changed:
		_strip_changed = false
		var built := _strip.build_weapons()
		_raid.get("player").carry(built)
		# A Retry keeps the debug pick; a New Raid reads the saved Loadout.
		if Raid.is_active() and not Raid.weapons.is_empty():
			Raid.weapons = built


## What [param weapons] carries as a Loadout: the first two, bare or built,
## with the Attachments built into them.
static func _loadout_of(weapons: Array) -> Loadout:
	var loadout := Loadout.new()
	var bares: Array[WeaponProfile] = []
	for weapon: WeaponProfile in weapons.slice(0, 2):
		bares.append(weapon.bare if weapon.bare != null else weapon)
	if bares.size() == 2 and bares[0] != bares[1]:
		loadout.set_first(bares[0])
		loadout.set_second(bares[1])
	for weapon: WeaponProfile in weapons.slice(0, 2):
		if weapon.bare != null:
			for attachment in weapon.attachments:
				loadout.set_attachment(weapon.bare, attachment.slot, attachment)
	return loadout


func _can_open() -> bool:
	var pause: PauseMenu = _raid.get("pause_menu")
	return pause == null or (pause.enabled and not pause.is_showing())


# _input, ahead of the pause menu: Esc closes the sheet rather than pausing.
func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.keycode == KEY_F1:
		if is_open():
			close()
		elif _can_open():
			open()
		else:
			return
	elif key.keycode == KEY_ESCAPE and is_open():
		close()
	else:
		return
	get_viewport().set_input_as_handled()


## The cell's Control: a SpinBox or CheckBox when editable, else a Label.
func cell(table_title: String, key: StringName, column: int) -> Control:
	return _cells.get(_id(table_title, key, column))


## The disk value a changed cell shows, or "" when it matches disk.
func disk_shown(table_title: String, key: StringName, column: int) -> String:
	var label: Label = _disk_labels.get(_id(table_title, key, column))
	if label == null or not label.visible:
		return ""
	return SheetTable.format(sheet.table(table_title).disk_value(key, column))


## The carried Built Weapon's value shown beside a Weapons cell, or "" when
## none is shown.
func built_shown(table_title: String, key: StringName, column: int) -> String:
	var label: Label = _built_labels.get(_id(table_title, key, column))
	if label == null or not label.visible:
		return ""
	return SheetTable.format(sheet.built_value(key, column))


## The strip's gun picker: [param place] 0 for FIRST, 1 for SECOND.
func strip_gun(place: int) -> OptionButton:
	return _strip_pickers.get(place)


## The strip's picker for [param slot] under the gun in [param place]; null
## when that gun has no such Slot.
func strip_slot(place: int, slot: Attachment.Slot) -> OptionButton:
	return _strip_pickers.get("%d|%d" % [place, slot])


func revert_button() -> Button:
	return _revert


func save_button() -> Button:
	return _save


func _id(table_title: String, key: StringName, column: int) -> String:
	return "%s|%s|%d" % [table_title, key, column]


func _edit(table: SheetTable, key: StringName, column: int, value: Variant) -> void:
	if table.set_value(key, column, value):
		_applied(table, key)
	_refresh()


## What a change needs beyond the Resource: Health is read at spawn, and
## the carried Built Weapons are built from the bare Profiles and the
## Attachments.
func _applied(table: SheetTable, key: StringName) -> void:
	if table.title in [SandboxSheet.WEAPONS, SandboxSheet.ATTACHMENTS]:
		sheet.rebuild_carried()
		return
	if table.title != SandboxSheet.HEALTH:
		return
	match key:
		&"pirate_health":
			var player: Node = _raid.get("player")
			player.apply_sandbox()
			var hud: Hud = _raid.get("hud")
			if hud != null:
				hud.set_max_health(player.health.max_health)
				hud.set_health(player.health.current)
		&"crew_health":
			for body in get_tree().get_nodes_in_group(&"crew"):
				if body.is_alive():
					body.apply_sandbox()


func _on_save() -> void:
	var err := sheet.save()
	_refresh()
	_status.text = "Saved to resources/ and docs/sandbox.md" if err == OK else "Save failed: %s" % error_string(err)


func _on_revert() -> void:
	for cell_ref in sheet.revert():
		_applied(cell_ref[0], cell_ref[1])
	_refresh()


# --- drawing -----------------------------------------------------------------

func _build() -> void:
	_root = Control.new()
	_root.name = "Root"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	var wash := ColorRect.new()
	wash.set_anchors_preset(Control.PRESET_FULL_RECT)
	wash.color = Color(0.03, 0.04, 0.07, 0.94)
	wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(wash)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	_root.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)

	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 16)
	column.add_child(bar)
	var title := Label.new()
	title.text = "SANDBOX"
	title.add_theme_font_size_override("font_size", 26)
	bar.add_child(title)
	_save = Button.new()
	_save.name = "Save"
	_save.text = "Save"
	_save.pressed.connect(_on_save)
	bar.add_child(_save)
	_revert = Button.new()
	_revert.name = "Revert"
	_revert.text = "Revert"
	_revert.pressed.connect(_on_revert)
	bar.add_child(_revert)
	_status = Label.new()
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(_status)
	var hint := Label.new()
	hint.text = "F1 or Esc closes  ·  amber: differs from disk  ·  = derived  ·  grey text: edit in the Inspector"
	hint.modulate = DIM
	bar.add_child(hint)

	_strip_box = VBoxContainer.new()
	_strip_box.name = "Strip"
	_strip_box.add_theme_constant_override("separation", 4)
	column.add_child(_strip_box)

	var scroll := ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	var tables := VBoxContainer.new()
	tables.add_theme_constant_override("separation", 28)
	scroll.add_child(tables)
	for table in sheet.tables:
		tables.add_child(_table_box(table))


func _table_box(table: SheetTable) -> VBoxContainer:
	var box := VBoxContainer.new()
	var heading := Label.new()
	heading.text = table.title
	heading.add_theme_font_size_override("font_size", 22)
	box.add_child(heading)
	var grid := GridContainer.new()
	grid.columns = 1 + table.columns.size()
	# Fourteen Attachments: narrow columns, the names wrapped, to fit a screen.
	var narrow := table.title == SandboxSheet.ATTACHMENTS
	grid.add_theme_constant_override("h_separation", 5 if narrow else 20)
	grid.add_theme_constant_override("v_separation", 2)
	box.add_child(grid)
	grid.add_child(Control.new())
	for column_name in table.columns:
		var head := Label.new()
		head.text = column_name
		head.add_theme_color_override("font_color", HEADING)
		if narrow:
			head.autowrap_mode = TextServer.AUTOWRAP_WORD
			head.add_theme_font_size_override("font_size", 12)
			head.custom_minimum_size = Vector2(FACTOR_WIDTH, 0)
			head.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		grid.add_child(head)
	var group := ""
	for row in table.rows:
		if row.group != group:
			group = row.group
			var g := Label.new()
			g.text = group.to_upper()
			g.add_theme_font_size_override("font_size", 13)
			g.modulate = DIM
			grid.add_child(g)
			for c in table.columns.size():
				grid.add_child(Control.new())
		var label := Label.new()
		label.text = ("  = " if row.kind == SheetTable.Kind.DERIVED else "  ") + row.label
		if not row.kind in [SheetTable.Kind.EDIT, SheetTable.Kind.FACTOR]:
			label.modulate = DIM
		if narrow:
			label.add_theme_font_size_override("font_size", 14)
		grid.add_child(label)
		for c in table.columns.size():
			grid.add_child(_cell(table, row, c))
	for note in table.notes:
		var n := Label.new()
		n.text = note
		n.modulate = DIM
		n.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(n)
	return box


func _cell(table: SheetTable, row: Dictionary, column: int) -> Control:
	var id := _id(table.title, row.key, column)
	# A factor's disk value goes under it, not beside: its column is narrow.
	var holder: BoxContainer = VBoxContainer.new() if row.kind == SheetTable.Kind.FACTOR else HBoxContainer.new()
	holder.add_theme_constant_override("separation", 0 if row.kind == SheetTable.Kind.FACTOR else 4)
	if table.title == SandboxSheet.WEAPONS and row.kind != SheetTable.Kind.READ_ONLY:
		var built := Label.new()
		built.add_theme_color_override("font_color", BUILT)
		built.visible = false
		_built_labels[id] = built
		holder.add_child(built)
	if not table.is_cell_editable(row.key, column):
		var label := Label.new()
		label.modulate = DIM
		if row.kind == SheetTable.Kind.READ_ONLY:
			# A model or a list of takes is long: clipped, so every weapon
			# column fits on screen, with the whole of it on hover.
			label.clip_text = true
			label.custom_minimum_size = Vector2(170, 0)
			label.mouse_filter = Control.MOUSE_FILTER_PASS
		_cells[id] = label
		holder.add_child(label)
		holder.move_child(label, 0)
		return holder
	var editor: Control
	if row.type == TYPE_BOOL:
		var check := CheckBox.new()
		check.toggled.connect(func(on: bool) -> void: _edit(table, row.key, column, on))
		editor = check
	else:
		var spin := SpinBox.new()
		spin.min_value = -100000.0
		spin.max_value = 100000.0
		spin.allow_greater = true
		spin.allow_lesser = true
		if row.type == TYPE_INT:
			spin.step = 1.0
			spin.rounded = true
		else:
			spin.step = 0.0001
			spin.custom_arrow_step = 0.01
		spin.custom_minimum_size = Vector2(110, 0)
		if row.kind == SheetTable.Kind.FACTOR:
			spin.custom_minimum_size = Vector2(FACTOR_WIDTH, 0)
			spin.get_line_edit().add_theme_constant_override("minimum_character_width", 0)
			spin.get_line_edit().add_theme_font_size_override("font_size", 13)
		spin.value_changed.connect(func(v: float) -> void: _edit(table, row.key, column, v))
		editor = spin
	holder.add_child(editor)
	holder.move_child(editor, 0)
	var disk := Label.new()
	disk.add_theme_color_override("font_color", CHANGED)
	if row.kind == SheetTable.Kind.FACTOR:
		disk.add_theme_font_size_override("font_size", 12)
	disk.modulate = DIM
	disk.visible = false
	holder.add_child(disk)
	_cells[id] = editor
	_disk_labels[id] = disk
	return holder


## Every cell to its live value, changed ones marked with the disk value.
func _refresh() -> void:
	for table in sheet.tables:
		for row in table.rows:
			for c in table.columns.size():
				var id := _id(table.title, row.key, c)
				var control: Control = _cells[id]
				var value: Variant = table.value(row.key, c)
				if control is SpinBox:
					(control as SpinBox).set_value_no_signal(value)
				elif control is CheckBox:
					(control as CheckBox).set_pressed_no_signal(value)
				else:
					(control as Label).text = "" if value == null and row.kind == SheetTable.Kind.FACTOR else SheetTable.format(value)
					control.tooltip_text = control.text if row.kind == SheetTable.Kind.READ_ONLY else ""
				if _built_labels.has(id):
					var built: Variant = sheet.built_value(row.key, c)
					_built_labels[id].visible = built != null
					_built_labels[id].text = "built %s" % SheetTable.format(built) if built != null else ""
				if _disk_labels.has(id):
					var changed := table.is_changed(row.key, c)
					control.modulate = CHANGED if changed else Color.WHITE
					_disk_labels[id].visible = changed
					_disk_labels[id].text = "disk %s" % SheetTable.format(table.disk_value(row.key, c)) if changed else ""
	var changed_count := sheet.changed_count()
	_status.text = "%d changed, unsaved" % changed_count if changed_count > 0 else "matches disk"


# --- the debug Loadout strip -------------------------------------------------

## A row per place: its label, the gun picker, then a picker per Slot of
## that gun offering only what fits it.
func _draw_strip() -> void:
	for child in _strip_box.get_children():
		child.queue_free()
	_strip_pickers.clear()
	var heading := Label.new()
	heading.text = "DEBUG LOADOUT  ·  applied when the sheet closes, ammo refilled  ·  never saved"
	heading.add_theme_font_size_override("font_size", 13)
	heading.modulate = DIM
	_strip_box.add_child(heading)
	for place in PLACES.size():
		var gun: WeaponProfile = _strip.get_first() if place == 0 else _strip.get_second()
		var row := HFlowContainer.new()
		row.add_theme_constant_override("h_separation", 10)
		row.add_theme_constant_override("v_separation", 4)
		_strip_box.add_child(row)
		var label := Label.new()
		label.text = PLACES[place]
		label.custom_minimum_size = Vector2(70, 0)
		label.add_theme_color_override("font_color", HEADING)
		row.add_child(label)
		var guns := OptionButton.new()
		guns.custom_minimum_size = Vector2(170, 0)
		for weapon in Loadout.all_weapons():
			guns.add_item(SandboxSheet.weapon_name(weapon))
		guns.select(Loadout.all_weapons().find(gun))
		guns.item_selected.connect(_on_strip_gun.bind(place))
		_strip_pickers[place] = guns
		row.add_child(guns)
		for slot in gun.slots():
			# Each picker offers one Slot's Attachments, so a fitted one names
			# its Slot; an empty one says which it is.
			var picker := OptionButton.new()
			picker.custom_minimum_size = Vector2(150, 0)
			picker.add_item("no %s" % String(Attachment.Slot.find_key(slot)).capitalize())
			var fitted := _strip.get_attachment(gun, slot)
			for attachment in gun.fits_in(slot):
				picker.add_item(attachment.display_name)
				if attachment == fitted:
					picker.select(picker.item_count - 1)
			picker.item_selected.connect(_on_strip_slot.bind(place, slot))
			_strip_pickers["%d|%d" % [place, slot]] = picker
			row.add_child(picker)


func _on_strip_gun(index: int, place: int) -> void:
	var weapon: WeaponProfile = Loadout.all_weapons()[index]
	if place == 0:
		_strip.set_first(weapon)
	else:
		_strip.set_second(weapon)
	_strip_changed = true
	_draw_strip()


func _on_strip_slot(index: int, place: int, slot: Attachment.Slot) -> void:
	var gun: WeaponProfile = _strip.get_first() if place == 0 else _strip.get_second()
	var attachment: Attachment = null if index == 0 else gun.fits_in(slot)[index - 1]
	if _strip.set_attachment(gun, slot, attachment):
		_strip_changed = true
	_draw_strip()
