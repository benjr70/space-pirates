class_name AttachmentModelChecks
extends RefCounted
## Attachment models on the gun in hand
## (`.scratch/weapon-attachments/issues/19-attachment-models-in-the-viewmodel.md`):
## the Viewmodel holding a Built Weapon shows each fitted Attachment's model,
## hides the gun's parts it takes the place of, takes the Muzzle and the aim
## point from a fitted Barrel or Sight, and the riders move with their bones.
## Run from the pirate suite: `await AttachmentModelChecks.run(self)`, which
## drives the suite's Pirate through its own helpers.

const DIR := "res://resources/attachments/%s.tres"

## Per gun, from the spec's "Models and mounting": each Attachment it takes,
## the model that must show, and the gun's own part meshes that must hide.
const PAIRS := {
	"pistol": {
		"reflex_sight": ["ReflexSight", []],
		"suppressor": ["Suppressor", []],
		"extended_magazine": ["Pistol_ExtendedMagazine", ["MagazineMesh"]],
		"quick_magazine": ["Pistol_QuickMagazine", ["MagazineMesh"]],
		"laser": ["Laser", []],
	},
	"assault_rifle": {
		"reflex_sight": ["ReflexSight", ["Sights"]],
		"combat_scope": ["CombatScope", ["Sights"]],
		"suppressor": ["Suppressor", []],
		"long_barrel": ["AssaultRifle_LongBarrel", ["Barrel"]],
		"short_barrel": ["AssaultRifle_ShortBarrel", ["Barrel"]],
		"extended_magazine": ["AssaultRifle_ExtendedMagazine", ["CellMesh"]],
		"quick_magazine": ["AssaultRifle_QuickMagazine", ["CellMesh"]],
		"drum": ["AssaultRifle_Drum", ["CellMesh"]],
		"foregrip": ["Foregrip", []],
		"laser": ["Laser", []],
		"bipod": ["Bipod", []],
		"heavy_stock": ["AssaultRifle_HeavyStock", ["Stock"]],
		"light_stock": ["AssaultRifle_LightStock", ["Stock"]],
	},
	"shotgun": {
		"reflex_sight": ["ReflexSight", ["Sights", "FrontSight"]],
		"long_barrel": ["Shotgun_LongBarrel", ["Barrel", "FrontSight"]],
		"short_barrel": ["Shotgun_ShortBarrel", ["Barrel", "FrontSight"]],
		"foregrip": ["Foregrip", []],
		"laser": ["Laser", []],
		"heavy_stock": ["Shotgun_HeavyStock", ["Stock"]],
		"light_stock": ["Shotgun_LightStock", ["Stock"]],
	},
	"marksman_rifle": {
		"long_scope": ["LongScope", ["Sights"]],
		"suppressor": ["Suppressor", []],
		"long_barrel": ["MarksmanRifle_LongBarrel", ["Barrel"]],
		"extended_magazine": ["MarksmanRifle_ExtendedMagazine", ["MagazineMesh"]],
		"quick_magazine": ["MarksmanRifle_QuickMagazine", ["MagazineMesh"]],
		"foregrip": ["Foregrip", []],
		"bipod": ["Bipod", []],
		"heavy_stock": ["MarksmanRifle_HeavyStock", ["Stock"]],
		"light_stock": ["MarksmanRifle_LightStock", ["Stock"]],
	},
}
## Each gun's own part meshes an Attachment may hide.
const PARTS := {
	"pistol": ["MagazineMesh"],
	"assault_rifle": ["Barrel", "Sights", "Stock", "CellMesh"],
	"shotgun": ["Barrel", "FrontSight", "Sights", "Stock"],
	"marksman_rifle": ["Barrel", "Sights", "Stock", "MagazineMesh"],
}
## How much further forward the Assault Rifle's muzzle sits, metres, from
## the spec's numbers (the prototype's marker places), within 5 mm.
const MUZZLE_GAIN := {"suppressor": 0.168, "long_barrel": 0.156}
const MUZZLE_TOLERANCE := 0.005
## The aim point on the camera axis, and a rider on its bone, within 1 mm.
const ON_AXIS := 0.001
const RIDE_TOLERANCE := 0.001

var suite: Object


static func run(on: Object) -> void:
	var checks := AttachmentModelChecks.new()
	checks.suite = on
	await checks._run()


func _run() -> void:
	await suite._place(suite.RUNWAY)
	await _check_every_pair()
	await _check_muzzle()
	await _check_aim_points()
	await _check_magazines_ride()
	await _check_pump_and_slide_riders()
	# Every gun he carries bare again, the Pistol in hand, as the suite had it.
	for gun: String in PAIRS:
		await _hold_bare(gun)
	await _hold_bare("pistol")
	await suite._place(suite.RUNWAY)


func _expect(condition: bool, message: String) -> void:
	suite._expect(condition, "attachment models: " + message)


func _bare(gun: String) -> WeaponProfile:
	return load("res://resources/weapons/%s.tres" % gun)


## The Pirate holding [param gun] built with [param files] (Attachment file
## stems), drawn through the weapon wheel like any swap and waited out.
func _hold(gun: String, files: Array) -> WeaponProfile:
	var bare := _bare(gun)
	var choice := {}
	for file: String in files:
		var attachment: Attachment = load(DIR % file)
		choice[attachment.slot] = attachment
	var built: WeaponProfile = bare.build(choice)
	_expect(built != null, "%s refused %s" % [gun, files])
	if built == null:
		return null
	await _draw(gun, built)
	return built


func _hold_bare(gun: String) -> void:
	await _draw(gun, _bare(gun))


## [param profile] in the place of [param gun] in what he carries, then that
## place drawn: the Viewmodel mounts it at the bottom of the swap dip.
func _draw(gun: String, profile: WeaponProfile) -> void:
	var player: CharacterBody3D = suite.player
	var at := -1
	for i in player.weapons.size():
		if player.weapons[i].model == _bare(gun).model:
			at = i
	if player.weapon == player.weapons[at]:
		# Off the place first, so drawing it back is a real swap.
		player.switch_weapon(1)
		await suite._seconds(player.weapon.swap_time + 0.1)
	player.weapons[at] = profile
	player.select_weapon(at)
	await suite._seconds(profile.swap_time + 0.2)
	_expect(player.weapon == profile, "the wheel did not draw the %s build" % gun)


## The node named [param node_name] showing on the gun in hand, or null.
func _shown(node_name: String) -> Node3D:
	for found in suite.weapon.holder.find_children(node_name, "Node3D", true, false):
		if (found as Node3D).is_visible_in_tree():
			return found
	return null


## For all 34 gun-and-Attachment pairs: the model shows on the mounted gun,
## every part it takes the place of hides and every other part still shows.
## Bare, every part shows and no Attachment model does.
func _check_every_pair() -> void:
	var pairs := 0
	for gun: String in PAIRS:
		await _hold_bare(gun)
		for part: String in PARTS[gun]:
			_expect(_shown(part) != null, "bare %s does not show its own %s" % [gun, part])
		for file: String in PAIRS[gun]:
			_expect(_shown(PAIRS[gun][file][0]) == null, "bare %s shows %s" % [gun, PAIRS[gun][file][0]])
		for file: String in PAIRS[gun]:
			var want: String = PAIRS[gun][file][0]
			var hides: Array = PAIRS[gun][file][1]
			if await _hold(gun, [file]) == null:
				continue
			pairs += 1
			var model := _shown(want)
			_expect(model != null and model is MeshInstance3D, "%s with %s does not show %s" % [gun, file, want])
			for part: String in PARTS[gun]:
				var showing := _shown(part) != null
				_expect(showing != (part in hides), "%s with %s: its %s %s" % [gun, file, part,
						"shows, want hidden" if showing else "is hidden, want shown"])
	_expect(pairs == 34, "%d gun-and-Attachment pairs checked, want 34" % pairs)


## Where the Viewmodel's muzzle sits, in its own space.
func _muzzle() -> Vector3:
	return (suite.weapon.get_node("Muzzle") as Node3D).position


## On the Assault Rifle the Suppressor puts the muzzle 0.168 m further
## forward than bare and the Long Barrel 0.156 m, each within 5 mm, at the
## Attachment's own marker; a shot's tracer starts there.
func _check_muzzle() -> void:
	await _hold_bare("assault_rifle")
	var bare := _muzzle()
	for file: String in MUZZLE_GAIN:
		await _hold("assault_rifle", [file])
		var moved := _muzzle() - bare
		_expect(absf(moved.z - MUZZLE_GAIN[file]) <= MUZZLE_TOLERANCE and Vector2(moved.x, moved.y).length() <= MUZZLE_TOLERANCE,
				"with %s the muzzle moved %s, want %.3f m forward within %.3f" % [file, moved, MUZZLE_GAIN[file], MUZZLE_TOLERANCE])
		var marker_name: String = PAIRS["assault_rifle"][file][0] + "_Muzzle"
		var marker := _shown(marker_name)
		_expect(marker != null, "with %s no %s marker shows" % [file, marker_name])
		if marker == null:
			continue
		# The tracer starts where the barrel's tip is drawn: the marker as the
		# Viewmodel's own narrow FOV shows it.
		suite._clear_shots()
		var eye: Camera3D = suite.player.camera
		var tip := eye.to_local(marker.global_position)
		var widen: float = tan(deg_to_rad(eye.fov) * 0.5) / tan(deg_to_rad(suite.weapon.fov_override) * 0.5)
		var drawn := Vector3(tip.x * widen, tip.y * widen, tip.z)
		suite.player.ammo = suite.player.weapon.magazine_size
		var bolt: Projectile3D = suite.player.fire()
		_expect(bolt != null, "no shot with %s" % file)
		if bolt != null:
			var born := eye.to_local(bolt.global_position)
			_expect(born.distance_to(drawn) < MUZZLE_TOLERANCE,
					"with %s the tracer starts at %s in the camera, the %s marker is drawn at %s" % [file, born, marker_name, drawn])
		suite._clear_shots()
		await suite._seconds(0.5)


## With any Sight fitted and aimed, its aim point (its own SightTip marker)
## is on the camera's axis within 1 mm; on the Shotgun the Long and Short
## Barrel's bead is, with no Sight.
func _check_aim_points() -> void:
	var cases := [
		["pistol", ["reflex_sight"], "ReflexSight_SightTip"],
		["assault_rifle", ["reflex_sight"], "ReflexSight_SightTip"],
		["assault_rifle", ["combat_scope"], "CombatScope_SightTip"],
		["assault_rifle", ["combat_scope", "long_barrel"], "CombatScope_SightTip"],
		["shotgun", ["reflex_sight"], "ReflexSight_SightTip"],
		["shotgun", ["reflex_sight", "long_barrel"], "ReflexSight_SightTip"],
		["shotgun", ["long_barrel"], "Shotgun_LongBarrel_SightTip"],
		["shotgun", ["short_barrel"], "Shotgun_ShortBarrel_SightTip"],
		["marksman_rifle", ["long_scope"], "LongScope_SightTip"],
	]
	for case: Array in cases:
		var built := await _hold(case[0], case[1])
		if built == null:
			continue
		await suite._aim(true)
		await suite._seconds(built.aim_time * 3.0 + 0.3)
		var marker := _shown(case[2])
		_expect(marker != null, "%s with %s shows no %s" % [case[0], case[1], case[2]])
		if marker != null:
			var at: Vector3 = suite.player.camera.to_local(marker.global_position)
			_expect(Vector2(at.x, at.y).length() <= ON_AXIS and at.z < 0.0,
					"%s with %s aimed: %s sits at (%.4f, %.4f) m off the camera axis, want within %.3f" % [
						case[0], case[1], case[2], at.x, at.y, ON_AXIS])
		await suite._aim(false)
		await suite._seconds(0.4)


## How far [param node] and the [param bone] it rides have each moved from
## [param rest], in the skeleton's own space: [node, bone].
func _in_skeleton(node: Node3D, bone: String) -> Array[Vector3]:
	var skeleton: Skeleton3D = suite.weapon.holder.find_child("Skeleton3D", true, false)
	for found in suite.weapon.holder.find_children("Skeleton3D", "Skeleton3D", true, false):
		if (found as Node3D).is_visible_in_tree():
			skeleton = found
	var local := skeleton.global_transform.affine_inverse() * node.global_position
	return [local, skeleton.get_bone_global_pose(skeleton.find_bone(bone)).origin]


## Halfway through a reload an Extended Magazine and a Drum are displaced
## from rest by the same offset as the gun's own magazine bone, within 1 mm.
func _check_magazines_ride() -> void:
	var cases := [
		["pistol", "extended_magazine", "Magazine"],
		["assault_rifle", "extended_magazine", "Cell"],
		["assault_rifle", "drum", "Cell"],
		["marksman_rifle", "extended_magazine", "Magazine"],
	]
	for case: Array in cases:
		var built := await _hold(case[0], [case[1]])
		if built == null:
			continue
		var model := _shown(PAIRS[case[0]][case[1]][0])
		_expect(model != null, "%s's %s is not showing" % [case[0], case[1]])
		if model == null:
			continue
		var rest := _in_skeleton(model, case[2])
		suite.player.ammo = built.magazine_size - 1
		suite.player.start_reload()
		await suite._seconds(built.reload_tactical * 0.5)
		var now := _in_skeleton(model, case[2])
		var bone_moved: Vector3 = now[1] - rest[1]
		var model_moved: Vector3 = now[0] - rest[0]
		_expect(bone_moved.length() > 0.01, "halfway through the %s reload its %s bone has moved only %s" % [case[0], case[2], bone_moved])
		_expect(model_moved.distance_to(bone_moved) <= RIDE_TOLERANCE,
				"halfway through the %s reload the %s moved %s, its %s bone %s" % [case[0], case[1], model_moved, case[2], bone_moved])
		await suite._seconds(built.reload_tactical * 0.5 + 0.3)


## Through a shot's cycle the Shotgun's Foregrip and Laser move with the
## pump, and through the slide's cycle the Pistol's Reflex Sight moves with
## the slide, each within 1 mm at every frame.
func _check_pump_and_slide_riders() -> void:
	var cases := [
		["shotgun", "foregrip", "Foregrip", "Pump"],
		["shotgun", "laser", "Laser", "Pump"],
		["pistol", "reflex_sight", "ReflexSight", "Slide"],
	]
	for case: Array in cases:
		var built := await _hold(case[0], [case[1]])
		if built == null:
			continue
		var model := _shown(case[2])
		_expect(model != null, "%s's %s is not showing" % [case[0], case[2]])
		if model == null:
			continue
		var rest := _in_skeleton(model, case[3])
		suite.player.ammo = built.magazine_size
		suite._clear_shots()
		suite.player.fire()
		var furthest := 0.0
		var worst := 0.0
		for i in ceili(built.fire_cycle_time / suite.FRAME) + 6:
			await suite._frames(1)
			var now := _in_skeleton(model, case[3])
			var bone_moved: Vector3 = now[1] - rest[1]
			furthest = maxf(furthest, bone_moved.length())
			worst = maxf(worst, (now[0] - rest[0]).distance_to(bone_moved))
		_expect(furthest > 0.01, "the %s's %s bone moved only %.4f m in a shot's cycle" % [case[0], case[3], furthest])
		_expect(worst <= RIDE_TOLERANCE, "the %s's %s strayed %.4f m from its %s bone in a shot's cycle" % [case[0], case[2], worst, case[3]])
		suite._clear_shots()
		await suite._seconds(0.6)
