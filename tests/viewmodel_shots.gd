extends SceneTree
## Windowed (not headless) probe for tuning the Viewmodel by eye: the player
## in a small lit room, one screenshot each of the hip, ADS and sprint-low
## poses. The ADS shot is how the SightTip marker was calibrated: the front
## sight's top-most pixel must land on the frame's centre row.
##
##   flatpak run org.godotengine.Godot --path . --resolution 960x540 \
##       --script res://tests/viewmodel_shots.gd -- out=res://.godot/shots
##
## Args after --: out=<dir>; hip=x,y,z ads=x,y,z low=x,y,z lowrot=x,y,z
## override the Viewmodel's poses; pistol=1 scale=<f> rot=x,y,z pos=x,y,z
## hides the scene's Sidearm and mounts a fresh pistol.glb instance at that
## transform instead, for trying a new mesh before it goes in the scene.
var out := "/tmp/shots"
var use_pistol := false
var pscale := 0.02
var prot := Vector3(0, -90, 0)
var ppos := Vector3.ZERO
var hip := Vector3.INF
var ads := Vector3.INF
var low := Vector3.INF
var lowrot := Vector3.INF

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=")
		match kv[0]:
			"out": out = kv[1]
			"pistol": use_pistol = kv[1] == "1"
			"scale": pscale = float(kv[1])
			"rot": prot = _v3(kv[1])
			"pos": ppos = _v3(kv[1])
			"hip": hip = _v3(kv[1])
			"ads": ads = _v3(kv[1])
			"low": low = _v3(kv[1])
			"lowrot": lowrot = _v3(kv[1])
	_run()

func _v3(s: String) -> Vector3:
	var p := s.split(",")
	return Vector3(float(p[0]), float(p[1]), float(p[2]))

func _box(parent: Node, size: Vector3, at: Vector3, color: Color) -> void:
	var b := StaticBody3D.new(); b.collision_layer = 1
	var cs := CollisionShape3D.new(); var bs := BoxShape3D.new(); bs.size = size; cs.shape = bs; b.add_child(cs)
	var mi := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = size; mi.mesh = bm
	var mat := StandardMaterial3D.new(); mat.albedo_color = color; mi.material_override = mat; b.add_child(mi)
	b.position = at; parent.add_child(b)

func _run() -> void:
	var world := Node3D.new(); root.add_child(world)
	_box(world, Vector3(8, 0.2, 8), Vector3(0, -0.1, 0), Color(0.35, 0.36, 0.4))
	_box(world, Vector3(8, 0.2, 8), Vector3(0, 3.6, 0), Color(0.3, 0.3, 0.32))
	_box(world, Vector3(8, 3.5, 0.2), Vector3(0, 1.75, -4), Color(0.5, 0.55, 0.6))
	_box(world, Vector3(1.0, 1.1, 1.0), Vector3(0.0, 0.55, -2.5), Color(0.6, 0.45, 0.3))
	var light := DirectionalLight3D.new(); light.rotation_degrees = Vector3(-50, 30, 0); light.light_energy = 1.2; world.add_child(light)
	var env := WorldEnvironment.new(); var e := Environment.new(); e.background_mode = Environment.BG_COLOR; e.background_color = Color(0.1, 0.1, 0.12); e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; e.ambient_light_color = Color(0.6, 0.6, 0.65); e.ambient_light_energy = 0.8; env.environment = e; world.add_child(env)
	var player: CharacterBody3D = load("res://scenes/player_3d.tscn").instantiate()
	world.add_child(player)
	player.position = Vector3(0, 0, 0)
	var weapon: Node3D = player.get_node("Head/Camera3D/Weapon")
	if use_pistol:
		weapon.get_node("Sidearm").visible = false
		var holder := Node3D.new(); holder.name = "PistolHolder"
		var pistol: Node3D = load("res://assets/models/quaternius_pistol/pistol.glb").instantiate()
		holder.add_child(pistol)
		holder.scale = Vector3.ONE * pscale
		holder.rotation_degrees = prot
		holder.position = ppos
		weapon.add_child(holder)
	if hip != Vector3.INF:
		weapon.pose_hip = hip
		weapon.position = hip
	if ads != Vector3.INF:
		weapon.pose_ads = ads
	if low != Vector3.INF:
		weapon.pose_low = low
	if lowrot != Vector3.INF:
		weapon.rotation_low = lowrot
	await process_frame
	await process_frame
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await _snap("hip")
	player.set_physics_process(false)
	weapon.set_process(false)
	weapon.position = weapon.pose_ads
	weapon.rotation_degrees = weapon.rotation_hip
	await _snap("ads")
	weapon.position = weapon.pose_low
	weapon.rotation_degrees = weapon.rotation_low
	await _snap("low")
	quit()

func _snap(label: String) -> void:
	for i in 6: await process_frame
	var img := root.get_viewport().get_texture().get_image()
	img.save_png("%s/%s.png" % [out, label])
	print("saved ", label)
