class_name RoomFog
extends Node2D
## Darkness over rooms the pirate has not walked into yet. A raided ship should
## be explored, not displayed.
##
## Doorways are deliberately left uncovered: standing in a black room you can
## still make out where the exits are, which is what keeps unexplored space
## navigable instead of merely hidden.

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

	var doorways := {}
	for door in layout.doors:
		for tile in door.tiles():
			doorways[tile] = true

	for i in layout.rooms.size():
		# Each rect grown by one so a room's walls stay hidden with it.
		var holder := Node2D.new()
		add_child(holder)
		var covered := {}
		for part in layout.rooms[i].shape():
			var rect := part.grow(1)
			for y in range(rect.position.y, rect.end.y):
				_shade_row(holder, rect, y, doorways, covered)
		_overlays[i] = holder


## Covers one row of a rect as a few wide strips, broken wherever a doorway
## sits or a tile is already shaded by a sibling rect of the same room.
func _shade_row(holder: Node2D, rect: Rect2i, y: int, doorways: Dictionary, covered: Dictionary) -> void:
	var run_start := -1
	for x in range(rect.position.x, rect.end.x + 1):
		var tile := Vector2i(x, y)
		var shaded := x < rect.end.x and not doorways.has(tile) and not covered.has(tile)
		if shaded:
			covered[tile] = true
		if shaded and run_start == -1:
			run_start = x
		elif not shaded and run_start != -1:
			var shade := ColorRect.new()
			shade.color = UNSEEN
			shade.position = Vector2(run_start, y) * TILE_SIZE
			shade.size = Vector2(x - run_start, 1) * TILE_SIZE
			shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
			holder.add_child(shade)
			run_start = -1


## True the first time a given room is revealed.
func reveal(room: int) -> bool:
	if not _overlays.has(room) or _revealed.has(room):
		return false
	_revealed[room] = true
	create_tween().tween_property(_overlays[room], "modulate:a", 0.0, FADE_TIME)
	return true


## True once the room has been walked into, even while the fade is still running.
func is_revealed(room: int) -> bool:
	return _revealed.has(room)
