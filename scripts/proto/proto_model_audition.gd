extends SceneTree
## PROTOTYPE: a model booth. Every glb under assets/models/audition stands in
## a row on a lit floor with its name over its head, playing its idle (or
## first) clip; the camera slowly orbits. Keys 1-9 jump to one candidate and
## cycle its clips with Space; Esc quits. Throwaway.
##
##   flatpak run org.godotengine.Godot --path . --script res://scripts/proto/proto_model_audition.gd

const DIR := "res://assets/models/audition"
const SPACING := 1.6

var models: Array[Node3D] = []
var names: Array[String] = []
var players: Array = []
var camera: Camera3D
var focus := -1
var clip_index := 0
var label: Label
var orbit := 0.0


class Booth extends Node:
	var tree: SceneTree
	func _unhandled_input(event: InputEvent) -> void:
		if event is InputEventKey and event.pressed and not event.echo:
			tree._key(event.keycode)
	func _process(delta: float) -> void:
		tree._tick(delta)


func _initialize() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(30, 30)
	floor_mesh.mesh = plane
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color(0.32, 0.33, 0.38)
	floor_mesh.material_override = floor_material
	world.add_child(floor_mesh)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-50, 35, 0)
	light.light_energy = 1.3
	light.shadow_enabled = true
	world.add_child(light)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.09, 0.09, 0.12)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.7, 0.7, 0.75)
	e.ambient_light_energy = 0.9
	env.environment = e
	world.add_child(env)

	var dir := DirAccess.open(DIR)
	var files: Array[String] = []
	for f in dir.get_files():
		if f.ends_with(".glb"):
			files.append(f)
	files.sort()
	for i in files.size():
		var scene: PackedScene = load(DIR + "/" + files[i])
		var model: Node3D = scene.instantiate()
		var holder := Node3D.new()
		holder.position = Vector3((i - (files.size() - 1) / 2.0) * SPACING, 0, 0)
		holder.add_child(model)
		world.add_child(holder)
		_fit(model)
		models.append(holder)
		names.append(files[i].get_basename())
		var anim := _find_anim(model)
		players.append(anim)
		if anim != null:
			for wanted in ["Idle", "CharacterArmature|Idle", "Idle_Gun", "CharacterArmature|Idle_Gun"]:
				if anim.has_animation(wanted):
					anim.play(wanted)
					break
			if not anim.is_playing() and anim.get_animation_list().size() > 0:
				anim.play(anim.get_animation_list()[0])
			for a in anim.get_animation_list():
				anim.get_animation(a).loop_mode = Animation.LOOP_LINEAR
		var tag := Label3D.new()
		tag.text = "[%d] %s" % [i + 1, names[i]]
		tag.position = Vector3(0, 2.2, 0)
		tag.font_size = 48
		tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		holder.add_child(tag)

	camera = Camera3D.new()
	camera.fov = 55
	world.add_child(camera)
	var ui := CanvasLayer.new()
	root.add_child(ui)
	label = Label.new()
	label.position = Vector2(20, 16)
	label.add_theme_font_size_override("font_size", 20)
	label.text = "MODEL BOOTH  -  1-9 focus a model, Space cycles its clips, Esc quits"
	ui.add_child(label)
	var booth := Booth.new()
	booth.tree = self
	root.add_child(booth)


## Scales the model so it stands about 1.8 m tall on the floor.
func _fit(model: Node3D) -> void:
	var lo := Vector3.INF
	var hi := -Vector3.INF
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var b: AABB = (mi as MeshInstance3D).get_aabb()
		var t: Transform3D = (mi as MeshInstance3D).transform
		var n: Node = mi.get_parent()
		while n != model and n is Node3D:
			t = (n as Node3D).transform * t
			n = n.get_parent()
		var gb := t * b
		lo = lo.min(gb.position)
		hi = hi.max(gb.end)
	var height := hi.y - lo.y
	if height > 0.01:
		var s := 1.8 / height
		model.scale = Vector3.ONE * s
		model.position.y = -lo.y * s


func _find_anim(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for c in node.get_children():
		var f := _find_anim(c)
		if f != null:
			return f
	return null


func _key(keycode: int) -> void:
	if keycode == KEY_ESCAPE:
		quit()
		return
	if keycode == KEY_SPACE and focus >= 0 and players[focus] != null:
		var anim: AnimationPlayer = players[focus]
		var list := anim.get_animation_list()
		clip_index = (clip_index + 1) % list.size()
		anim.play(list[clip_index])
		label.text = "%s  -  clip: %s" % [names[focus], list[clip_index]]
		return
	var n := keycode - KEY_1
	if n >= 0 and n < models.size():
		focus = n
		clip_index = 0
		label.text = "%s  -  Space cycles clips, 0 back to the row" % names[focus]
	elif keycode == KEY_0:
		focus = -1
		label.text = "MODEL BOOTH  -  1-9 focus a model, Space cycles its clips, Esc quits"


func _tick(delta: float) -> void:
	orbit += delta * 0.25
	var centre := Vector3.ZERO
	var radius := 2.2 + models.size() * 0.9
	var height := 1.4
	if focus >= 0:
		centre = models[focus].position
		radius = 3.2
	var eye := centre + Vector3(sin(orbit) * radius, height, cos(orbit) * radius)
	camera.global_position = eye
	camera.look_at(centre + Vector3(0, 0.9, 0), Vector3.UP)
