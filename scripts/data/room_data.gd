class_name RoomData
extends Resource
## One rectangular room, described in TILE coordinates.
##
## `rect` is the walkable floor only -- the surrounding wall ring is implied and
## painted by [ShipBuilder]. Two rooms that should share a wall are placed with
## exactly one tile of gap between them; that gap tile becomes the shared wall.

@export var rect: Rect2i = Rect2i(0, 0, 4, 4)
## What the room is for: &"bridge", &"engine", &"cargo", &"medbay", &"quarters".
@export var role: StringName = &"quarters"
## How many hostile crew start in this room. The generator will set this from
## a threat budget later.
@export var crew_count: int = 0
## Props to spawn, as [{type = StringName, tile = Vector2i}]. `tile` is the tile
## the prop is centred on, so odd-sized props line up with the grid.
@export var props: Array[Dictionary] = []


func center_tile() -> Vector2:
	return Vector2(rect.position) + Vector2(rect.size) / 2.0
