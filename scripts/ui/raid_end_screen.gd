class_name RaidEndScreen
extends CanvasLayer
## How a Raid ends, either way. Down: the ship carries on behind a red wash
## and he can Retry the same target, every crew member back at their post.
## Extracted: the ship freezes behind a green wash and he can take a New
## Raid on a fresh ship of the same Class. Both offer the main menu. Hidden
## until [method show_death] or [method show_extracted].

signal retry_pressed
signal new_raid_pressed
signal menu_pressed

const DEATH_COLOR := Color(1.0, 0.3, 0.25)
const DEATH_WASH := Color(0.25, 0.0, 0.02, 0.55)
const EXTRACT_COLOR := Color(0.4, 1.0, 0.55)
const EXTRACT_WASH := Color(0.0, 0.12, 0.06, 0.7)

var _root: Control
var _wash: ColorRect
var _title: Label
var _detail: Label
var _retry: Button
var _new_raid: Button


func _ready() -> void:
	layer = 10
	# The extracted screen runs over a paused ship.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.name = "Root"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Swallows stray clicks so they cannot recapture the mouse.
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.visible = false
	add_child(_root)

	_wash = ColorRect.new()
	_wash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_wash)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	center.add_child(column)

	_title = MenuStyle.heading("", 72)
	_title.name = "Title"
	column.add_child(_title)
	_detail = MenuStyle.heading("", 20, MenuStyle.DIM_TEXT)
	column.add_child(_detail)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 18)
	column.add_child(gap)

	_retry = MenuStyle.button("Retry")
	_retry.name = "Retry"
	_retry.pressed.connect(retry_pressed.emit)
	column.add_child(_retry)
	_new_raid = MenuStyle.button("New Raid")
	_new_raid.name = "NewRaid"
	_new_raid.pressed.connect(new_raid_pressed.emit)
	column.add_child(_new_raid)
	var menu := MenuStyle.button("Exit to Main Menu")
	menu.name = "Menu"
	menu.pressed.connect(menu_pressed.emit)
	column.add_child(menu)


## Raises the screen for a pirate who went down; `detail` names the ship.
func show_death(detail: String) -> void:
	_raise("YOU DIED", DEATH_COLOR, DEATH_WASH, detail, _retry)


## Raises the screen for a pirate who got out; `detail` sums up the Raid.
func show_extracted(detail: String) -> void:
	_raise("EXTRACTED", EXTRACT_COLOR, EXTRACT_WASH, detail, _new_raid)


func is_showing() -> bool:
	return _root.visible


## Which way the Raid ended: the heading's text, empty while hidden.
func title_text() -> String:
	return _title.text if is_showing() else ""


func _raise(title: String, color: Color, wash: Color, detail: String, first: Button) -> void:
	_title.text = title
	_title.add_theme_color_override("font_color", color)
	_title.add_theme_color_override("font_shadow_color", Color(color, 0.35))
	_wash.color = wash
	_detail.text = detail
	_retry.visible = first == _retry
	_new_raid.visible = first == _new_raid
	_root.visible = true
	_root.modulate.a = 0.0
	create_tween().tween_property(_root, "modulate:a", 1.0, 0.6)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	first.grab_focus()
