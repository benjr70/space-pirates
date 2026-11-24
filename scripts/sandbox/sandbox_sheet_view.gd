class_name SandboxSheetView
extends CanvasLayer
## The in-Raid Sandbox sheet, debug builds only. F1 pauses the Raid and
## shows every [SandboxSheet] table: weapons as columns, attributes as rows.
## A number changed here changes the live Resource, so it is in the next
## shot; F1 or Esc closes the sheet and the Raid resumes with it. A cell
## that differs from disk turns amber and shows the disk value beside it.
## Save writes the resources and `docs/sandbox.md`; Revert puts back what is
## on disk. Crew read their Pistol and Gunnery live, so those need nothing
## more. Health is taken at spawn, so a Health change is pushed onto the
## Pirate (refilled) and every crew member still standing.
##
## Esc belongs to the sheet while it is open, and to the pause menu
## otherwise; F1 does nothing over the pause menu or once the Raid is over.

const CHANGED := Color(1.0, 0.78, 0.3)
const HEADING := Color(0.6, 0.85, 1.0)
const DIM := Color(1, 1, 1, 0.5)

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
	# The crew's own Gunnery: the cached Resources they hold.
	sheet = SandboxSheet.build(player.weapons, player.sandbox, Gunnery.all())
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


## What a change needs beyond the Resource: Health is read at spawn.
func _applied(table: SheetTable, key: StringName) -> void:
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

	var scroll := ScrollContainer.new()
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
	grid.add_theme_constant_override("h_separation", 20)
	grid.add_theme_constant_override("v_separation", 2)
	box.add_child(grid)
	grid.add_child(Control.new())
	for column_name in table.columns:
		var head := Label.new()
		head.text = column_name
		head.add_theme_color_override("font_color", HEADING)
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
		if row.kind != SheetTable.Kind.EDIT:
			label.modulate = DIM
		grid.add_child(label)
		for c in table.columns.size():
			grid.add_child(_cell(table, row, c))
	for note in table.notes:
		var n := Label.new()
		n.text = note
		n.modulate = DIM
		box.add_child(n)
	return box


func _cell(table: SheetTable, row: Dictionary, column: int) -> Control:
	var id := _id(table.title, row.key, column)
	if row.kind != SheetTable.Kind.EDIT:
		var label := Label.new()
		label.modulate = DIM
		_cells[id] = label
		return label
	var holder := HBoxContainer.new()
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
		spin.value_changed.connect(func(v: float) -> void: _edit(table, row.key, column, v))
		editor = spin
	holder.add_child(editor)
	var disk := Label.new()
	disk.add_theme_color_override("font_color", CHANGED)
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
					(control as Label).text = SheetTable.format(value)
				if _disk_labels.has(id):
					var changed := table.is_changed(row.key, c)
					control.modulate = CHANGED if changed else Color.WHITE
					_disk_labels[id].visible = changed
					_disk_labels[id].text = "disk %s" % SheetTable.format(table.disk_value(row.key, c)) if changed else ""
	var changed_count := sheet.changed_count()
	_status.text = "%d changed, unsaved" % changed_count if changed_count > 0 else "matches disk"
