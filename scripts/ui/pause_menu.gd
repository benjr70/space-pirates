class_name PauseMenu
extends CanvasLayer
## Esc mid-Raid: the ship freezes behind a dark wash and the pirate can
## Resume or abandon the Raid for the main menu. Esc again resumes. Runs
## while the tree is paused; switched off once he is dead, when the death
## screen owns the way out.

signal menu_pressed

## Off while something else owns the screen (the death screen).
var enabled := true

var _root: Control
var _resume: Button


func _ready() -> void:
	layer = 11
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.name = "Root"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.visible = false
	add_child(_root)

	var wash := ColorRect.new()
	wash.set_anchors_preset(Control.PRESET_FULL_RECT)
	wash.color = Color(0.0, 0.01, 0.03, 0.65)
	wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(wash)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	center.add_child(column)

	column.add_child(MenuStyle.heading("PAUSED", 64))
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 18)
	column.add_child(gap)

	_resume = MenuStyle.button("Resume")
	_resume.name = "Resume"
	_resume.pressed.connect(resume)
	column.add_child(_resume)
	var menu := MenuStyle.button("Main Menu")
	menu.name = "Menu"
	menu.pressed.connect(func() -> void:
		get_tree().paused = false
		menu_pressed.emit())
	column.add_child(menu)


# _input, not _unhandled_input: Esc must reach the menu before the pirate,
# who would otherwise just let go of the mouse.
func _input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	if is_showing():
		resume()
	elif enabled:
		pause()
	else:
		return
	get_viewport().set_input_as_handled()


func pause() -> void:
	if not enabled or is_showing():
		return
	get_tree().paused = true
	_root.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_resume.grab_focus()


func resume() -> void:
	if not is_showing():
		return
	_root.visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	# The click on Resume is not a trigger pull.
	Input.action_release("shoot")


func is_showing() -> bool:
	return _root.visible
