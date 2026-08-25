class_name RoomFog
extends Node2D
## Darkness over rooms the pirate has not walked into yet. A raided ship should
## be explored, not displayed.

const TILE_SIZE := 32
const FADE_TIME := 0.4
const UNSEEN := Color(0.02, 0.03, 0.06, 1.0)

var _overlays := {}
var _revealed := {}


func setup(layout: ShipLayout) -> void:
	for child in get_children():
		child.queue_free()
		remove_child(child)
	_overlays.clear()
	_revealed.clear()

	for i in layout.rooms.size():
		# Grown by one so a room's walls stay hidden with it.
		var rect := layout.rooms[i].rect.grow(1)
		var shade := ColorRect.new()
		shade.color = UNSEEN
		shade.position = Vector2(rect.position) * TILE_SIZE
		shade.size = Vector2(rect.size) * TILE_SIZE
		shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(shade)
		_overlays[i] = shade


## True the first time a given room is revealed.
func reveal(room: int) -> bool:
	if not _overlays.has(room):
		return false
	if _revealed.has(room):
		return false
	_revealed[room] = true
	var shade: ColorRect = _overlays[room]
	create_tween().tween_property(shade, "modulate:a", 0.0, FADE_TIME)
	return true


## True once the room has been walked into, even while the fade is still running.
func is_revealed(room: int) -> bool:
	return _revealed.has(room)
