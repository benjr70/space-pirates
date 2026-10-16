class_name DeathScreen
extends CanvasLayer
## What the pirate sees when he goes down: the ship carries on behind a red
## wash, and he can Retry the same target, every crew member back at their
## post, or go back to the main menu to pick another. Hidden until [method show_death].

signal retry_pressed
signal menu_pressed

var _root: Control
var _detail: Label
var _retry: Button


func _ready() -> void:
	layer = 10
	_root = Control.new()
	_root.name = "Root"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Swallows stray clicks so they cannot recapture the mouse for a dead man.
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.visible = false
	add_child(_root)

	var wash := ColorRect.new()
	wash.set_anchors_preset(Control.PRESET_FULL_RECT)
	wash.color = Color(0.25, 0.0, 0.02, 0.55)
	wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(wash)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	center.add_child(column)

	column.add_child(MenuStyle.heading("YOU DIED", 72, Color(1.0, 0.3, 0.25)))
	_detail = MenuStyle.heading("", 20, MenuStyle.DIM_TEXT)
	column.add_child(_detail)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 18)
	column.add_child(gap)

	_retry = MenuStyle.button("Retry")
	_retry.name = "Retry"
	_retry.pressed.connect(retry_pressed.emit)
	column.add_child(_retry)
	var menu := MenuStyle.button("Exit to Main Menu")
	menu.name = "Menu"
	menu.pressed.connect(menu_pressed.emit)
	column.add_child(menu)


## Raises the screen; `detail` names what killed the run, e.g. the ship.
func show_death(detail: String) -> void:
	_detail.text = detail
	_root.visible = true
	_root.modulate.a = 0.0
	create_tween().tween_property(_root, "modulate:a", 1.0, 0.6)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_retry.grab_focus()


func is_showing() -> bool:
	return _root.visible
