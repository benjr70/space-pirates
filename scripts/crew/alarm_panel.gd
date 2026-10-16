class_name AlarmPanel
extends StaticBody3D
## A wall-mounted panel a crew member raises the ship-wide Alarm from. The
## Pirate can shoot one out: a broken panel goes dark and raises nothing.
## Placed by [ShipBuilder3D] at the spots [method spots] picks: one per
## Bridge and Armory. See `CREW_AI.md`.

## Rooms that get a panel.
const ROLES: Array[StringName] = [&"bridge", &"armory"]
## Panel face size, and how high its centre sits on the wall.
const SIZE := Vector3(0.6, 0.45, 0.1)
const HEIGHT := 1.4
const COLOR_FRAME := Color(0.12, 0.13, 0.15)
const COLOR_SCREEN := Color(1.0, 0.35, 0.15)
const COLOR_RAISED := Color(1.0, 0.1, 0.08)

## Where a crew member stands to work it: the floor tile in front of it.
var use_at := Vector3.ZERO
var room := -1
var broken := false
var _screen: StandardMaterial3D


## A panel on the wall beside [param stand] (a Room's floor tile), in the
## wall tile [param wall_dir] from it. Call before adding to the tree.
func setup(room_index: int, stand: Vector2i, wall_dir: Vector2i) -> void:
	name = "AlarmPanel"
	room = room_index
	use_at = ShipBuilder3D.tile_to_world(stand)
	var out := Vector3(wall_dir.x, 0.0, wall_dir.y)
	transform = Transform3D(Basis.looking_at(out, Vector3.UP),
			use_at + out * (ShipBuilder3D.TILE / 2.0 - SIZE.z / 2.0) + Vector3.UP * HEIGHT)
	collision_layer = 1
	collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = SIZE
	shape.shape = box
	add_child(shape)
	var frame := MeshInstance3D.new()
	var frame_mesh := BoxMesh.new()
	frame_mesh.size = SIZE
	var frame_material := StandardMaterial3D.new()
	frame_material.albedo_color = COLOR_FRAME
	frame_mesh.material = frame_material
	frame.mesh = frame_mesh
	add_child(frame)
	_screen = StandardMaterial3D.new()
	_screen.albedo_color = COLOR_SCREEN * 0.4
	_screen.emission_enabled = true
	_screen.emission = COLOR_SCREEN
	_screen.emission_energy_multiplier = 1.5
	var screen := MeshInstance3D.new()
	screen.name = "Screen"
	var screen_mesh := BoxMesh.new()
	screen_mesh.size = Vector3(SIZE.x * 0.8, SIZE.y * 0.7, 0.02)
	screen_mesh.material = _screen
	screen.mesh = screen_mesh
	screen.position = Vector3(0.0, 0.0, SIZE.z / 2.0)
	add_child(screen)


func _ready() -> void:
	add_to_group(&"alarm_panels")


## Only the Pirate breaks a panel; stray crew fire does not.
func take_damage(_amount: int, from: Node = null) -> void:
	if broken or from is Crew3D:
		return
	broken = true
	_screen.emission_enabled = false
	_screen.albedo_color = Color(0.03, 0.03, 0.03)


## Shows the Alarm is up on every working panel.
func show_raised() -> void:
	if broken:
		return
	_screen.emission = COLOR_RAISED
	_screen.emission_energy_multiplier = 3.0


## One spot per Bridge and Armory: the floor tile nearest the Room's centre
## that has Hull or wall straight behind it (not a doorway or Hatch, not a
## prop's tile, not in front of a doorway). Each is
## {room: int, stand: Vector2i, wall_dir: Vector2i}.
static func spots(layout: ShipLayout) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var floors := layout.floor_tiles()
	var walls := ShipBuilder3D.wall_tiles(layout, floors)
	var gaps := {}
	for door in layout.doors:
		for tile in door.tiles():
			gaps[tile] = true
	for hatch in layout.hatches:
		for tile in hatch.tiles():
			gaps[tile] = true
	for index in layout.rooms.size():
		var room_data := layout.rooms[index]
		if not room_data.role in ROLES:
			continue
		var props := {}
		for prop in room_data.props:
			props[prop.get("tile", Vector2i.ZERO)] = true
		var centre := room_data.center_tile()
		var best := {}
		var best_distance := INF
		for tile: Vector2i in room_data.tiles():
			if props.has(tile) or _beside_gap(tile, gaps):
				continue
			for side: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
				if not walls.has(tile + side):
					continue
				var distance := Vector2(tile).distance_to(centre)
				if distance < best_distance:
					best_distance = distance
					best = {"room": index, "stand": tile, "wall_dir": side}
		if not best.is_empty():
			out.append(best)
	return out


static func _beside_gap(tile: Vector2i, gaps: Dictionary) -> bool:
	for x in range(-1, 2):
		for y in range(-1, 2):
			if gaps.has(tile + Vector2i(x, y)):
				return true
	return false
