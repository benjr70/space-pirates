class_name LaserDotChecks
extends RefCounted
## The Laser's dot (`.scratch/weapon-attachments/issues/21-the-lasers-dot.md`):
## with a Laser fitted to the weapon in hand, a small red dot on the first
## surface or body along the gun's line from the Laser's `Laser_Origin`, at
## the hip and aimed, out to 30 m; nothing beyond; hidden while the weapon is
## lowered for a Sprint or a Clamber and during a swap. It is seen through a
## scope's lens, collides with nothing, and the ray ignores the Pirate.
## Headless runs draw no pixels: what the dot looks like is read in
## `tests/shots.sh attachments`.
## Run from the pirate suite: `await LaserDotChecks.run(self)`.

const DIR := "res://resources/attachments/%s.tres"
## The spec's "The Laser": the dot reaches 30 m, then nothing.
const REACH := 30.0
## The ticket: the dot within 2 cm of where the gun's line meets the wall.
const ON_LINE := 0.02
## Where the Pirate stands for these checks: facing -Z toward a wall 5 m off
## (its face at z 5), +Z toward a far wall, or +X down open floor that ends
## 10 m on, with nothing past it.
const STAND := Vector3(70.0, 0.0, 10.0)
const WALL_RANGE := 5.0
## A second wall facing -Z, its face this far down +Z from STAND.
const FAR_WALL := 32.0

var suite: Object
var _near: StaticBody3D
var _far: StaticBody3D


static func run(on: Object) -> void:
	var checks := LaserDotChecks.new()
	checks.suite = on
	await checks._run()


func _run() -> void:
	_near = suite._box("LaserWall", Vector3(8.0, 3.4, 0.4), Vector3(STAND.x, 1.7, STAND.z - WALL_RANGE - 0.2))
	_far = suite._box("LaserFarWall", Vector3(8.0, 3.4, 0.4), Vector3(STAND.x, 1.7, STAND.z + FAR_WALL + 0.2))
	_check_dot_is_only_a_visual()
	for gun in ["pistol", "assault_rifle", "shotgun"]:
		await _check_dot_on_wall(gun)
	await _check_open_space()
	await _check_reach()
	await _check_no_laser()
	await _check_hidden_lowered()
	await _check_hidden_in_swap()
	for gun in ["pistol", "assault_rifle", "shotgun", "marksman_rifle"]:
		await _draw(gun, _bare(gun))
	await _draw("pistol", _bare("pistol"))
	_near.free()
	_far.free()
	await suite._place(suite.RUNWAY)


func _expect(condition: bool, message: String) -> void:
	suite._expect(condition, "laser dot: " + message)


func _bare(gun: String) -> WeaponProfile:
	return load("res://resources/weapons/%s.tres" % gun)


func _laser() -> Attachment:
	return load(DIR % "laser")


func _dot() -> LaserDot:
	return suite.player.laser_dot


## The Pirate at [param at] facing -Z, or turned [param yaw] radians from it
## (PI faces +Z, -PI / 2 faces +X).
func _stand(at: Vector3, yaw := 0.0) -> void:
	await suite._place(at)
	suite.player.rotation.y = yaw
	suite.player.head.rotation.x = 0.0
	await suite._seconds(0.2)


## The Pirate holding [param gun] built with [param files], drawn through the
## weapon wheel.
func _hold(gun: String, files: Array) -> WeaponProfile:
	var choice := {}
	for file: String in files:
		var attachment: Attachment = load(DIR % file)
		choice[attachment.slot] = attachment
	var built: WeaponProfile = _bare(gun).build(choice)
	_expect(built != null, "%s refused %s" % [gun, files])
	if built != null:
		await _draw(gun, built)
	return built


func _draw(gun: String, profile: WeaponProfile) -> void:
	var player: CharacterBody3D = suite.player
	await suite._aim(false)
	var at := -1
	for i in player.weapons.size():
		if player.weapons[i].model == _bare(gun).model:
			at = i
	if player.weapon == player.weapons[at]:
		player.switch_weapon(1)
		await suite._seconds(player.weapon.swap_time + 0.1)
	player.weapons[at] = profile
	player.select_weapon(at)
	await suite._seconds(profile.swap_time + 0.2)
	_expect(player.weapon == profile, "the wheel did not draw the %s build" % gun)


## Where the gun's line meets the plane z = [param plane_z]: from the Laser's
## `Laser_Origin` marker along the gun's barrel, which runs down the
## Viewmodel's +Z (the muzzle is ahead of the grip on +Z).
func _line_meets(plane_z: float) -> Vector3:
	var origin: Node3D = suite.weapon.fitting.model_of(_laser()).get_node("Laser_Origin")
	var from := origin.global_position
	var along: Vector3 = (suite.weapon as Node3D).global_basis.z.normalized()
	return from + along * ((plane_z - from.z) / along.z)


## The dot is a mesh and nothing else: no body or area under it for a ray,
## a bolt or a crew member's eyes to meet, and it draws on a layer the
## scope's lens camera sees (the dot is in the world, so a Laser and a Combat
## Scope together show it in the lens).
func _check_dot_is_only_a_visual() -> void:
	var dot := _dot()
	_expect(dot != null and dot.dot != null, "the Pirate has no laser dot")
	if dot == null or dot.dot == null:
		return
	_expect(dot.dot.find_children("*", "CollisionObject3D", true, false).is_empty() and dot.find_children("*", "CollisionObject3D", true, false).is_empty(),
			"the dot carries a collision object")
	_expect(dot.dot.layers & (1 << (Viewmodel.LAYER - 1)) == 0, "the dot draws on the Viewmodel's layer")
	_expect(suite.player.scoped_view.lens_camera.cull_mask & dot.dot.layers != 0, "the scope's lens camera does not see the dot")
	_expect(suite.player.camera.cull_mask & dot.dot.layers != 0, "the Pirate's camera does not see the dot")


## Facing a wall 5 m off with a Laser fitted, at the hip and aimed, the dot
## shows within 2 cm of where the gun's line meets the wall; at the hip it
## sits off the crosshair, as the gun does, so it follows the gun and not
## the camera.
func _check_dot_on_wall(gun: String) -> void:
	await _stand(STAND)
	var built := await _hold(gun, ["laser"])
	if built == null:
		return
	var wall_z := STAND.z - WALL_RANGE
	await suite._seconds(0.3)
	for aimed in [false, true]:
		if aimed:
			await suite._aim(true)
			await suite._seconds(built.aim_time * 3.0 + 0.3)
		var dot := _dot()
		var want := _line_meets(wall_z)
		var at := dot.dot.global_position
		var pose := "aimed" if aimed else "at the hip"
		_expect(dot.shown(), "%s with a Laser %s facing a wall 5 m off: no dot" % [gun, pose])
		_expect(at.distance_to(want) <= ON_LINE, "%s with a Laser %s: the dot is at %s, %.3f m from where the gun's line meets the wall %s, want within %.2f" % [
				gun, pose, at, at.distance_to(want), want, ON_LINE])
		if not aimed:
			var camera: Camera3D = suite.player.camera
			var off := Vector2(at.x - camera.global_position.x, at.y - camera.global_position.y).length()
			_expect(off > 0.05, "%s with a Laser at the hip: the dot is %.3f m off the crosshair's line, on the camera's and not the gun's" % [gun, off])
	await suite._aim(false)


## Facing open floor with nothing inside 30 m, no dot is shown.
func _check_open_space() -> void:
	await _stand(STAND, -PI / 2.0)
	await _hold("assault_rifle", ["laser"])
	await suite._seconds(0.3)
	_expect(not _dot().shown(), "facing open space with a Laser, at the hip: a dot shows at %s" % _dot().dot.global_position)
	await suite._aim(true)
	await suite._seconds(0.6)
	_expect(not _dot().shown(), "facing open space with a Laser, aimed: a dot shows at %s" % _dot().dot.global_position)
	await suite._aim(false)


## A wall 28 m down the gun's line gets the dot; the same wall at 32 m
## does not.
func _check_reach() -> void:
	await _hold("assault_rifle", ["laser"])
	for range_m in [28.0, 32.0]:
		await _stand(STAND + Vector3(0.0, 0.0, FAR_WALL - range_m), PI)
		await suite._seconds(0.3)
		var want: bool = range_m <= REACH
		_expect(_dot().shown() == want, "a wall %.0f m off with a Laser: the dot is %s, want %s" % [
				range_m, "shown" if _dot().shown() else "hidden", "shown" if want else "hidden"])


## Without a Laser, facing the wall, no dot.
func _check_no_laser() -> void:
	await _stand(STAND)
	for case in [["pistol", []], ["assault_rifle", ["combat_scope"]], ["marksman_rifle", []]]:
		await _hold(case[0], case[1])
		await suite._seconds(0.3)
		_expect(not _dot().shown(), "%s with %s and no Laser facing a wall: a dot shows" % case)
		await suite._aim(true)
		await suite._seconds(0.6)
		_expect(not _dot().shown(), "%s with %s and no Laser, aimed: a dot shows" % case)
		await suite._aim(false)


## Watches [param frames] frames: whether [param during] was ever true, and
## whether the dot showed on a frame drawn while it was. A frame's
## `process_frame` comes before its `_process`, so the dot seen at one is the
## one drawn for the state read at the last.
func _watch(frames: int, during: Callable) -> Array[bool]:
	var happened := false
	var seen := false
	# The first frame's dot was drawn before the watch began.
	var was := false
	for i in frames:
		await suite.process_frame
		if was:
			happened = true
			seen = seen or _dot().shown()
		was = during.call()
	return [happened, seen]


## Lowered for a Sprint (toward the wall, which would take the dot) and for a
## Clamber, no dot; back at a walk it returns.
func _check_hidden_lowered() -> void:
	await _stand(STAND + Vector3(0.0, 0.0, 6.0))
	await _hold("pistol", ["laser"])
	await suite._seconds(0.3)
	_expect(_dot().shown(), "with a Laser facing a wall 11 m off before the sprint: no dot")
	Input.action_press("move_up")
	Input.action_press("sprint")
	var watched := await _watch(30, func() -> bool: return suite.player.state == suite.player.State.SPRINT)
	var seen: bool = watched[1]
	_expect(suite.player.state == suite.player.State.SPRINT, "holding sprint and forward gave %s" % suite.player.State.keys()[suite.player.state])
	_expect(not seen, "sprinting toward a wall with a Laser: a dot shows")
	Input.action_release("sprint")
	Input.action_release("move_up")
	await suite._seconds(0.6)
	_expect(_dot().shown(), "with a Laser after the sprint, at a walk facing the wall: no dot")

	# The 1.1 m block of the course, its face 0.5 m ahead, looking down at
	# it so the gun's line meets it.
	await _stand(suite._before_block(4))
	suite.player.head.rotation.x = -0.35
	await suite._seconds(0.3)
	_expect(_dot().shown(), "with a Laser looking down at a block 0.5 m off: no dot")
	Input.action_press("move_up")
	Input.action_press("jump")
	await suite.physics_frame
	await suite.physics_frame
	Input.action_release("jump")
	watched = await _watch(20, func() -> bool: return suite.player.state == suite.player.State.CLAMBER)
	var clambered: bool = watched[0]
	seen = watched[1]
	Input.action_release("move_up")
	_expect(clambered, "the 1.1 m block was not clambered")
	_expect(not seen, "clambering with a Laser: a dot shows")
	await suite._seconds(0.7)


## Through a swap, out of a Laser build and back into it, no dot.
func _check_hidden_in_swap() -> void:
	await _stand(STAND)
	await _hold("pistol", ["laser"])
	await suite._seconds(0.3)
	_expect(_dot().shown(), "with a Laser facing the wall before the swap: no dot")
	var player: CharacterBody3D = suite.player
	for step in [1, -1]:
		player.switch_weapon(step)
		var watched := await _watch(20, player.is_swapping)
		var swapping: bool = watched[0]
		var seen: bool = watched[1]
		_expect(swapping, "the swap did not start")
		_expect(not seen, "swapping %s a Laser build: a dot shows" % ("out of" if step == 1 else "into"))
		await suite._seconds(player.weapon.swap_time + 0.2)
	_expect(_dot().shown(), "with a Laser drawn again facing the wall: no dot")
