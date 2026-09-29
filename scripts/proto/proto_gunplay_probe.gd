extends SceneTree
## Throwaway: exercise the gunplay rules headless (issue #36).
func _init() -> void:
	var scene: Node = load("res://scenes/proto_movement_walk.tscn").instantiate()
	root.add_child(scene)
	for i in 3:
		await process_frame
	var p: CharacterBody3D = scene.player
	var vm: Node = p.get_node("Head/Camera3D/Weapon")
	var mat: Material = vm.blaster.find_children("*", "MeshInstance3D", true, false)[0].get_surface_override_material(0)
	print("material z_clip_scale=%s fov_override=%s" % [mat.get("z_clip_scale"), mat.get("fov_override")])
	print("clips: ", vm.anim.get_animation_list())
	var d: Node3D = scene.get_node_or_null("Main/Ship/Props/Dummy1")
	if d == null:
		for n in scene.find_children("Dummy1", "", true, false): d = n
	print("dummy facing -Z at ", d.global_position)
	# Behind: stand at +Z of the dummy (it faces -Z), look toward it (-Z).
	p.global_position = d.global_position + Vector3(0, 0, 1.5); p.rotation.y = 0.0
	await physics_frame
	print("behind -> is_behind=%s target=%s" % [p._is_behind(d), p._pick_melee_target()])
	p.global_position = d.global_position + Vector3(0, 0, -1.5); p.rotation.y = PI
	await physics_frame
	print("in front -> is_behind=%s target=%s" % [p._is_behind(d), p._pick_melee_target()])
	p.global_position = d.global_position + Vector3(3.0, 0, 0); p.rotation.y = PI * 0.5
	await physics_frame
	print("3 m away -> target=%s (expect null)" % [p._pick_melee_target()])
	p.global_position = d.global_position + Vector3(0, 0, 1.5); p.rotation.y = 0.0
	await physics_frame
	p._melee(); await create_timer(0.3).timeout
	print("back melee: %s | dummy alive=%s" % [p.last_melee, d.is_alive()])
	await create_timer(2.2).timeout
	p.ammo = 0; p.start_reload(); print("empty reload timer %.2f" % p._reload_timer)
	p._reload_timer = 0.0; p.ammo = 5; p.start_reload(); print("tactical reload timer %.2f" % p._reload_timer)
	p._melee(); print("melee during reload -> reloading=%s" % p.is_reloading())
	p._set_state(p.State.CROUCH, "probe"); print("crouch spread %.2f" % p.spread_deg())
	p._set_state(p.State.SLIDE, "probe"); print("slide spread %.2f" % p.spread_deg())
	p._set_state(p.State.WALK, "probe"); p.ads = true; print("ads still spread %.2f" % p.spread_deg())
	quit()
