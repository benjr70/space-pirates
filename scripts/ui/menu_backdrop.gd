class_name MenuBackdrop
extends Node3D
## The ship drifting behind the main menu, seen from outside. It is a real
## generated target: the Hull is read off a [ShipLayout] (floor, the wall
## ring and any Bulk sealed inside), then raised as stepped plating, thicker
## toward the spine, with greebles, lit ports along the skin and engines
## burning on the aft edge. A new one is rolled every time the menu opens.

const PLATE_STEP := 0.35
const HULL_COLOR := Color(0.36, 0.38, 0.42)
const PORT_COLOR := Color(1.0, 0.75, 0.4)
const ENGINE_COLOR := Color(0.35, 0.7, 1.0)
const MAX_ENGINES := 6

@export var ship_class: StringName = &"medium"
## Zero rolls a random ship.
@export var seed := 0
## Longest side of the ship once fitted, in metres.
@export var fit_length := 40.0
@export var drift_degrees_per_second := 1.5

var layout: ShipLayout
var _rng := RandomNumberGenerator.new()
var _hull: Node3D
var _time := 0.0


func _ready() -> void:
	_rng.seed = seed if seed > 0 else randi()
	layout = ShipGenerator.generate(ship_class, seed if seed > 0 else _rng.randi_range(1, Raid.SEED_MAX))
	_hull = Node3D.new()
	_hull.name = "Hull"
	add_child(_hull)
	_build(_solid_tiles(layout))


func _process(delta: float) -> void:
	_time += delta
	rotation.y += deg_to_rad(drift_degrees_per_second) * delta
	position.y = sin(_time * 0.4) * 0.3
	rotation.z = sin(_time * 0.27) * 0.03


## Floor, walls and whatever they enclose: the ship as seen from outside.
static func _solid_tiles(source: ShipLayout) -> Dictionary:
	var floors := source.floor_tiles()
	var solid := floors.duplicate()
	solid.merge(ShipBuilder3D.wall_tiles(source, floors))
	var bounds := _bounds(solid).grow(1)
	# Flood the outside in from a corner; anything it cannot reach is hull.
	var outside := {}
	var queue: Array[Vector2i] = [bounds.position]
	outside[bounds.position] = true
	while not queue.is_empty():
		var tile: Vector2i = queue.pop_back()
		for step in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var next: Vector2i = tile + step
			if bounds.has_point(next) and not outside.has(next) and not solid.has(next):
				outside[next] = true
				queue.append(next)
	for x in range(bounds.position.x, bounds.end.x):
		for y in range(bounds.position.y, bounds.end.y):
			var tile := Vector2i(x, y)
			if not outside.has(tile):
				solid[tile] = true
	return solid


static func _bounds(tiles: Dictionary) -> Rect2i:
	var first: Vector2i = tiles.keys()[0]
	var rect := Rect2i(first, Vector2i.ONE)
	for tile: Vector2i in tiles:
		rect = rect.merge(Rect2i(tile, Vector2i.ONE))
	return rect


## Tiles from the skin inward: 1 on the edge, growing toward the spine.
static func _depths(solid: Dictionary) -> Dictionary:
	var depth := {}
	var frontier: Array[Vector2i] = []
	for tile: Vector2i in solid:
		for step in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			if not solid.has(tile + step):
				depth[tile] = 1
				frontier.append(tile)
				break
	var head := 0
	while head < frontier.size():
		var tile := frontier[head]
		head += 1
		for step in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var next: Vector2i = tile + step
			if solid.has(next) and not depth.has(next):
				depth[next] = depth[tile] + 1
				frontier.append(next)
	return depth


func _build(solid: Dictionary) -> void:
	var bounds := _bounds(solid)
	var center := Vector3(bounds.get_center().x, 0.0, bounds.get_center().y)
	var depth := _depths(solid)

	var plates: Array[Transform3D] = []
	var shades: Array[Color] = []
	var greebles: Array[Transform3D] = []
	var ports: Array[Transform3D] = []
	var aft_edge: Array[Vector2i] = []
	for tile: Vector2i in solid:
		var d: int = depth[tile]
		var top := snappedf(0.7 + minf(d, 9) * 0.5, PLATE_STEP)
		var bottom := -top * 0.7
		var at := Vector3(tile.x, 0.0, tile.y) - center
		plates.append(Transform3D(Basis.from_scale(Vector3(1.0, top - bottom, 1.0)),
				at + Vector3(0, (top + bottom) * 0.5, 0)))
		var shade := _rng.randf_range(0.82, 1.04)
		shades.append(Color(shade, shade, shade))
		if d > 1 and _rng.randf() < 0.09:
			var size := Vector3(_rng.randf_range(0.3, 0.9), _rng.randf_range(0.15, 0.7), _rng.randf_range(0.3, 0.9))
			greebles.append(Transform3D(Basis.from_scale(size), at + Vector3(0, top + size.y * 0.5, 0)))
		if d == 1:
			for step in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
				if solid.has(tile + step):
					continue
				if step == Vector2i.DOWN and _engine_row(tile, solid, bounds):
					aft_edge.append(tile)
				elif _rng.randf() < 0.45:
					var out := Vector3(step.x, 0, step.y)
					var along := Vector3(absf(step.y), 0, absf(step.x))
					var size := along * 0.55 + Vector3(0, 0.12, 0) + out.abs() * 0.06
					ports.append(Transform3D(Basis.from_scale(size + Vector3(0.001, 0, 0.001)),
							at + out * 0.5 + Vector3(0, top * 0.45, 0)))

	_hull.add_child(_multimesh("Plates", plates, _metal(HULL_COLOR), shades))
	_hull.add_child(_multimesh("Greebles", greebles, _metal(HULL_COLOR * 0.7)))
	_hull.add_child(_multimesh("Ports", ports, _glow(PORT_COLOR, 3.0)))
	_add_engines(aft_edge, center, depth)

	var length := maxf(bounds.size.x, bounds.size.y)
	_hull.scale = Vector3.ONE * (fit_length / length)


## An aft-facing edge tile far enough back to carry an engine.
static func _engine_row(tile: Vector2i, solid: Dictionary, bounds: Rect2i) -> bool:
	return tile.y >= bounds.end.y - maxi(bounds.size.y / 5, 3) and not solid.has(tile + Vector2i.DOWN)


func _add_engines(aft_edge: Array[Vector2i], center: Vector3, depth: Dictionary) -> void:
	if aft_edge.is_empty():
		return
	aft_edge.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.x < b.x)
	var count := clampi(aft_edge.size() / 3, 1, MAX_ENGINES)
	var nozzle := CylinderMesh.new()
	nozzle.top_radius = 0.95
	nozzle.bottom_radius = 0.75
	nozzle.height = 1.4
	nozzle.material = _metal(HULL_COLOR * 0.55)
	var flame := CylinderMesh.new()
	flame.top_radius = 0.0
	flame.bottom_radius = 0.65
	flame.height = 2.6
	flame.material = _glow(ENGINE_COLOR, 5.0, 0.55)
	for i in count:
		var tile: Vector2i = aft_edge[int((i + 0.5) * aft_edge.size() / count)]
		var at := Vector3(tile.x, 0.0, tile.y + 0.9) - center
		var housing := MeshInstance3D.new()
		housing.mesh = nozzle
		housing.rotation_degrees.x = 90.0
		housing.position = at
		_hull.add_child(housing)
		var plume := MeshInstance3D.new()
		plume.mesh = flame
		plume.rotation_degrees.x = 90.0
		plume.position = at + Vector3(0, 0, 1.9)
		plume.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_hull.add_child(plume)
		var light := OmniLight3D.new()
		light.light_color = ENGINE_COLOR
		light.light_energy = 2.5
		light.omni_range = 6.0
		light.position = at + Vector3(0, 0, 2.0)
		_hull.add_child(light)


static func _multimesh(node_name: String, transforms: Array[Transform3D], material: Material,
		colors: Array[Color] = []) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = not colors.is_empty()
	var box := BoxMesh.new()
	box.material = material
	mm.mesh = box
	mm.instance_count = transforms.size()
	for i in transforms.size():
		mm.set_instance_transform(i, transforms[i])
		if mm.use_colors:
			mm.set_instance_color(i, colors[i])
	var instance := MultiMeshInstance3D.new()
	instance.name = node_name
	instance.multimesh = mm
	return instance


static func _metal(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.vertex_color_use_as_albedo = true
	# Mostly paint: bare metal would only mirror black space.
	m.metallic = 0.3
	m.roughness = 0.6
	return m


static func _glow(color: Color, energy: float, alpha := 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(color, alpha)
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	return m
