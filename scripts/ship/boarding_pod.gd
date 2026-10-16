class_name BoardingPod
extends Node3D
## The pirate's own boarding tube, clamped to the outside of the Hatch a Raid
## boards through. A short enclosed airlock in his ship's rust and amber,
## not the target's grey: he starts inside it facing the shut Hatch, and the
## sealed door at its back is the way home.
##
## Built in code, like [Door3D]. The node sits at the Hatch's centre with
## local +Z pointing out into space and X across the gap, so every piece
## below is placed as if every Hatch faced the same way.

## Interior length, from the Hull's outer face to the back door.
const DEPTH := 3.2
## Interior height: lower than the ship's rooms, so it feels like a tube.
const HEIGHT := 2.7
## Extra width each side of the Hatch gap; the Hull wall beside the gap
## closes it off.
const SIDE_ROOM := 0.5
const WALL := 0.2
## Where the Hull's outer face is: the Hatch fills one wall tile centred on
## the node.
const COLLAR_Z := ShipBuilder3D.TILE / 2.0

const COLOR_HULL := Color(0.3, 0.15, 0.1)
const COLOR_RIB := Color(0.14, 0.11, 0.1)
const COLOR_FLOOR := Color(0.12, 0.12, 0.13)
const COLOR_LAMP := Color(1.0, 0.5, 0.15)
const COLOR_HOME_LIGHT := Color(1.0, 0.2, 0.15)
## The home light while an Extraction counts down.
const COLOR_HOME_GO := Color(0.25, 1.0, 0.4)
## How close to the home door the pirate must stand to work it.
const HOME_REACH := 1.2

## The Hatch it is docked at.
var hatch: HatchData
var _width := 2.0
var _beacon: StandardMaterial3D
var _home_light: StandardMaterial3D
var _extracting := false
var _time := 0.0


## Size the pod to [param hatch] and place it on [param layout]'s Hull.
## Call before adding to the tree.
func setup(layout: ShipLayout, hatch_data: HatchData) -> void:
	name = "BoardingPod"
	hatch = hatch_data
	add_to_group(&"boarding_pod")
	_width = hatch.width * ShipBuilder3D.TILE + SIDE_ROOM * 2.0
	transform = Transform3D(_facing(layout, hatch), ShipBuilder3D.hatch_center_world(hatch))
	_build()


## Where the pirate stands at the start of the Raid: mid-tube, a little
## toward the back, so the Hatch is a few steps ahead.
func spawn_point() -> Vector3:
	return to_global(Vector3(0.0, 0.0, COLLAR_Z + DEPTH * 0.6))


## The way the pirate faces at the start: at the Hatch.
func spawn_basis() -> Basis:
	return Basis.looking_at(-global_basis.z, Vector3.UP)


## Whether [param point] is inside the tube, between the Hull's outer face
## and the back door: where an Extraction must be waited out.
func contains(point: Vector3) -> bool:
	var local := to_local(point)
	return absf(local.x) <= _width / 2.0 and local.z >= COLLAR_Z and local.z <= COLLAR_Z + DEPTH \
			and local.y > -0.5 and local.y < HEIGHT


## Whether [param point] is close enough to the home door to work it.
func at_home_door(point: Vector3) -> bool:
	var local := to_local(point)
	return contains(point) and local.z >= COLLAR_Z + DEPTH - HOME_REACH


## Lights the home door green while an Extraction counts down, red otherwise.
func set_extracting(on: bool) -> void:
	_extracting = on
	var color := COLOR_HOME_GO if on else COLOR_HOME_LIGHT
	_home_light.albedo_color = color * 0.4
	_home_light.emission = color


## Local +Z out of the Hull through [param hatch], X across the gap.
static func _facing(layout: ShipLayout, hatch: HatchData) -> Basis:
	var step := hatch.inward(layout.rooms[hatch.room])
	var out := Vector3(-step.x, 0.0, -step.y)
	return Basis(Vector3.UP.cross(out), Vector3.UP, out)


## The tiles the pod covers outside the Hull, for checking it clears the
## ship's own Masses. Without [param sides], only the lane straight out of
## the gap: a pod tucked into a corner of the Hull may rest its side
## against the ship's wall, but its tube must not run into it.
static func footprint(layout: ShipLayout, hatch: HatchData, sides := true) -> Array[Vector2i]:
	var step := hatch.inward(layout.rooms[hatch.room])
	var across := Vector2i.RIGHT if hatch.horizontal else Vector2i.DOWN
	var reach := 1 if sides else 0
	var out: Array[Vector2i] = []
	for depth in range(1, ceili(DEPTH + WALL) + 1):
		for i in range(-reach, hatch.width + reach):
			out.append(hatch.tile + across * i - step * depth)
	return out


## Whether a pod on [param hatch] stands clear of every floor and wall tile.
static func fits(layout: ShipLayout, hatch: HatchData, sides := true) -> bool:
	var floors := layout.floor_tiles()
	var walls := ShipBuilder3D.wall_tiles(layout, floors)
	for tile in footprint(layout, hatch, sides):
		if floors.has(tile) or walls.has(tile):
			return false
	return true


## The Hatch a Raid boards by when none was asked for: the first a pod docks
## at cleanly, else the first whose lane is clear, else the first.
static func choose_hatch(layout: ShipLayout) -> int:
	for sides in [true, false]:
		for i in layout.hatches.size():
			if fits(layout, layout.hatches[i], sides):
				return i
	return 0


func _process(delta: float) -> void:
	_time += delta
	# The lamp over the Hatch pulses: the ship is through there.
	_beacon.emission_energy_multiplier = 0.9 + sin(_time * 4.0) * 0.6
	# The home light blinks fast while the pod gets ready to cast off.
	_home_light.emission_energy_multiplier = (1.6 + sin(_time * 12.0) * 1.0) if _extracting else 1.2


func _build() -> void:
	var hull := _metal(COLOR_HULL)
	var rib := _metal(COLOR_RIB)
	var deck := _metal(COLOR_FLOOR)
	deck.roughness = 0.85
	var half := _width / 2.0
	var mid_z := COLLAR_Z + DEPTH / 2.0
	var outer := _width + WALL * 2.0

	# Shell: floor, ceiling, both sides and the back.
	_solid("Floor", Vector3(outer, WALL, DEPTH + WALL), Vector3(0, -WALL / 2.0, mid_z + WALL / 2.0), deck)
	_solid("Ceiling", Vector3(outer, WALL, DEPTH + WALL), Vector3(0, HEIGHT + WALL / 2.0, mid_z + WALL / 2.0), hull)
	_solid("Left", Vector3(WALL, HEIGHT, DEPTH), Vector3(-half - WALL / 2.0, HEIGHT / 2.0, mid_z), hull)
	_solid("Right", Vector3(WALL, HEIGHT, DEPTH), Vector3(half + WALL / 2.0, HEIGHT / 2.0, mid_z), hull)
	var back_z := COLLAR_Z + DEPTH + WALL / 2.0
	_solid("Back", Vector3(outer, HEIGHT, WALL), Vector3(0, HEIGHT / 2.0, back_z), hull)

	# Ribs every metre or so: what makes a box read as a pressure tube.
	var ribs := 3
	for i in ribs:
		var z := COLLAR_Z + DEPTH * (i + 0.5) / ribs
		_mesh(Vector3(0.12, HEIGHT, 0.18), Vector3(-half + 0.06, HEIGHT / 2.0, z), rib)
		_mesh(Vector3(0.12, HEIGHT, 0.18), Vector3(half - 0.06, HEIGHT / 2.0, z), rib)
		_mesh(Vector3(_width, 0.12, 0.18), Vector3(0, HEIGHT - 0.06, z), rib)

	# The docking collar: warning stripes framing the Hatch and across the deck.
	var stripes := HazardStripes.material()
	_mesh(Vector3(_width, 0.02, 0.45), Vector3(0, 0.01, COLLAR_Z + 0.25), stripes)
	_mesh(Vector3(SIDE_ROOM, HEIGHT, 0.08), Vector3(-half + SIDE_ROOM / 2.0, HEIGHT / 2.0, COLLAR_Z + 0.04), stripes)
	_mesh(Vector3(SIDE_ROOM, HEIGHT, 0.08), Vector3(half - SIDE_ROOM / 2.0, HEIGHT / 2.0, COLLAR_Z + 0.04), stripes)

	# Handholds down both walls.
	var rail := _metal(Color(0.55, 0.5, 0.42))
	rail.metallic = 0.8
	rail.roughness = 0.35
	for side in [-1.0, 1.0]:
		var bar := MeshInstance3D.new()
		var tube := CylinderMesh.new()
		tube.top_radius = 0.03
		tube.bottom_radius = 0.03
		tube.height = DEPTH - 0.6
		tube.material = rail
		bar.mesh = tube
		bar.rotation_degrees.x = 90.0
		bar.position = Vector3(side * (half - 0.1), 1.3, mid_z)
		add_child(bar)

	# The way home: a round sealed door in the back wall, red-lit.
	var hatch_door := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.9
	disc.bottom_radius = 0.9
	disc.height = 0.1
	disc.radial_segments = 32
	disc.material = rib
	hatch_door.mesh = disc
	hatch_door.rotation_degrees.x = 90.0
	hatch_door.position = Vector3(0, 1.2, back_z - WALL / 2.0 - 0.05)
	add_child(hatch_door)
	_home_light = _glow(COLOR_HOME_LIGHT, 1.2)
	_mesh(Vector3(0.5, 0.08, 0.04), Vector3(0, 1.2, back_z - WALL / 2.0 - 0.12), _home_light)

	# Strip lamps along the ceiling corners and a pulsing beacon over the Hatch.
	var lamp := _glow(COLOR_LAMP, 0.8)
	for side in [-1.0, 1.0]:
		_mesh(Vector3(0.06, 0.06, DEPTH - 0.4), Vector3(side * (half - 0.2), HEIGHT - 0.2, mid_z), lamp)
	_beacon = _glow(COLOR_LAMP, 0.9)
	_mesh(Vector3(0.6, 0.12, 0.12), Vector3(0, HEIGHT - 0.1, COLLAR_Z + 0.15), _beacon)
	var light := OmniLight3D.new()
	light.name = "Lamp"
	light.light_color = COLOR_LAMP
	light.light_energy = 0.7
	light.omni_range = 4.5
	light.position = Vector3(0, HEIGHT - 0.4, mid_z)
	add_child(light)


## A box that blocks bodies, on the world layer the pirate walks on.
func _solid(node_name: String, size: Vector3, at: Vector3, material: Material) -> void:
	var body := StaticBody3D.new()
	body.name = node_name
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = at
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	var mesh := MeshInstance3D.new()
	var visual := BoxMesh.new()
	visual.size = size
	visual.material = material
	mesh.mesh = visual
	body.add_child(mesh)
	add_child(body)


func _mesh(size: Vector3, at: Vector3, material: Material) -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	box.material = material
	mesh.mesh = box
	mesh.position = at
	add_child(mesh)


static func _metal(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = 0.45
	m.roughness = 0.6
	return m


static func _glow(color: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color * 0.4
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	return m
