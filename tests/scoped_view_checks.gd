class_name ScopedViewChecks
extends RefCounted
## The scoped view and the Reflex Sight
## (`.scratch/weapon-attachments/issues/20-scoped-view-and-reflex-sight.md`):
## a scope aims through a picture-in-picture lens magnified by the Built
## Weapon's `ads_zoom` while the view around it zooms 1.25x, the eye sits
## 0.06 m from the rear glass, the mouse slows by the lens's zoom, the lens
## camera renders only while aimed through a lens, the Viewmodel stays out of
## it, and the HUD crosshair hides behind a lens or a Reflex Sight. Headless
## runs draw no pixels: what the lens and the surround look like, and where
## the reticle lands, are measured by `tests/shots.sh scoped`.
## Run from the pirate suite: `await ScopedViewChecks.run(self)`.

const DIR := "res://resources/attachments/%s.tres"
## The Pirate's unaimed view, from `scenes/player_3d.tscn`.
const HIP_FOV := 75.0
## From `.scratch/weapon-attachments/issues/13-starting-numbers.md`: what
## each scope's lens magnifies by on its gun.
const LENS_ZOOM := {"long_scope": 5.01, "combat_scope": 2.48}
## The spec's "Scoped view": the view around the lens, and the eye's
## distance from the rear glass.
const VIEW_AROUND_LENS := 1.25
const EYE_TO_GLASS := 0.06
## A target 1 m wide at 50 m.
const TARGET_WIDTH := 1.0
const TARGET_RANGE := 50.0
## The screen the spans are worked out on (the shots' default size).
const SCREEN_HEIGHT := 720.0
## How far off the aimed pose the gun is pushed for the reticle check.
const SHIFT := 0.006

var suite: Object


static func run(on: Object) -> void:
	var checks := ScopedViewChecks.new()
	checks.suite = on
	await checks._run()


func _run() -> void:
	await suite._place(suite.RUNWAY)
	_check_viewmodel_layer_left_out()
	await _check_lens_magnification()
	await _check_view_around_lens()
	await _check_mouse_through_lens()
	await _check_eye_to_glass()
	await _check_lens_renders_only_aimed()
	await _check_surround_follows_sights()
	await _check_reticle_seen_when_shifted()
	await _check_hud_crosshair_hides()
	for gun in ["pistol", "assault_rifle", "shotgun", "marksman_rifle"]:
		await _draw(gun, _bare(gun))
	await _draw("pistol", _bare("pistol"))
	await suite._place(suite.RUNWAY)


func _expect(condition: bool, message: String) -> void:
	suite._expect(condition, "scoped view: " + message)


func _bare(gun: String) -> WeaponProfile:
	return load("res://resources/weapons/%s.tres" % gun)


func _scoped() -> ScopedView:
	return suite.player.scoped_view


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


## Sights up and settled.
func _aim_settled() -> void:
	await suite._aim(true)
	await suite._seconds(suite.player.weapon.aim_time * 3.0 + 0.3)


## How much the main camera magnifies against the unaimed view right now.
func _camera_zoom() -> float:
	return tan(deg_to_rad(HIP_FOV) * 0.5) / tan(deg_to_rad(suite.player.camera.fov) * 0.5)


## Everything the Viewmodel draws is on its own render layer, and the lens
## camera leaves that layer out, so the lens never shows its own tube.
func _check_viewmodel_layer_left_out() -> void:
	var layer: int = 1 << (Viewmodel.LAYER - 1)
	var count := 0
	for found in suite.weapon.find_children("*", "VisualInstance3D", true, false):
		count += 1
		var drawn := found as VisualInstance3D
		_expect(drawn.layers == layer, "%s draws on layers %d, want the Viewmodel's alone (%d)" % [drawn.name, drawn.layers, layer])
	_expect(count > 0, "the Viewmodel draws nothing")
	_expect(_scoped().lens_camera.cull_mask & layer == 0, "the lens camera draws the Viewmodel's layer")
	_expect(suite.player.camera.cull_mask & layer != 0, "the Pirate's camera leaves the Viewmodel out")


## Aimed with the Long Scope, a target 1 m wide at 50 m spans in the lens
## the screen width it would span at 5.01x zoom, within 5%; with the Combat
## Scope at 2.48x. The span is found through the lens camera itself (where
## it draws the target's two edges in its picture) and the lens's own mapping
## of that picture onto the screen ([member ScopedView.PICTURE_SPAN]).
func _check_lens_magnification() -> void:
	for case in [["marksman_rifle", "long_scope"], ["assault_rifle", "combat_scope"]]:
		var built := await _hold(case[0], [case[1]])
		if built == null:
			continue
		var want_zoom: float = LENS_ZOOM[case[1]]
		_expect(absf(built.ads_zoom - want_zoom) < 0.01, "%s with %s magnifies %.3fx, want %.2fx" % [case[0], case[1], built.ads_zoom, want_zoom])
		await _aim_settled()
		var scoped := _scoped()
		var camera: Camera3D = suite.player.camera
		var lens := scoped.lens_camera
		_expect(lens.global_transform.is_equal_approx(camera.global_transform), "the lens camera does not look where the Pirate does")
		var centre := camera.global_position - camera.global_basis.z * TARGET_RANGE
		var half := camera.global_basis.x * TARGET_WIDTH * 0.5
		var picture := float(scoped.lens_view.size.y)
		var left := lens.unproject_position(centre - half)
		var right := lens.unproject_position(centre + half)
		# The lens lays its picture over PICTURE_SPAN half-heights of screen
		# either side of the middle.
		var in_half_heights := (right.x - left.x) / picture * 2.0 * ScopedView.PICTURE_SPAN
		var span := in_half_heights * SCREEN_HEIGHT * 0.5
		var want := TARGET_WIDTH / TARGET_RANGE * want_zoom / tan(deg_to_rad(HIP_FOV) * 0.5) * SCREEN_HEIGHT * 0.5
		_expect(absf(span / want - 1.0) <= 0.05, "%s with %s: the target spans %.1f px in the lens, want %.1f (%.2fx) within 5%%" % [
				case[0], case[1], span, want, want_zoom])
		await suite._aim(false)


## Aimed through a lens the main camera's zoom is 1.25x within 2%; with the
## Reflex Sight and a gun's own sights the whole view zooms by `ads_zoom`.
func _check_view_around_lens() -> void:
	var cases := [["marksman_rifle", ["long_scope"]], ["assault_rifle", ["combat_scope"]],
			["assault_rifle", ["reflex_sight"]], ["marksman_rifle", []]]
	for case: Array in cases:
		var built := await _hold(case[0], case[1])
		if built == null:
			continue
		await _aim_settled()
		var want: float = VIEW_AROUND_LENS if built.aims_through_lens else built.ads_zoom
		_expect(absf(_camera_zoom() / want - 1.0) <= 0.02, "%s with %s aimed: the camera zooms %.3fx, want %.3fx within 2%%" % [
				case[0], case[1], _camera_zoom(), want])
		await suite._aim(false)


## Aimed through a lens the mouse turns the view the hip rate divided by the
## lens's zoom, within 2%.
func _check_mouse_through_lens() -> void:
	for case in [["marksman_rifle", "long_scope"], ["assault_rifle", "combat_scope"]]:
		var built := await _hold(case[0], [case[1]])
		if built == null:
			continue
		var player: CharacterBody3D = suite.player
		player.head.rotation.x = 0.0
		var yaw: float = player.rotation.y
		player.look(Vector2(100.0, 40.0))
		var hip_yaw: float = yaw - player.rotation.y
		var hip_pitch: float = -player.head.rotation.x
		await _aim_settled()
		yaw = player.rotation.y
		var pitch: float = player.head.rotation.x
		player.look(Vector2(100.0, 40.0))
		var aimed_yaw: float = yaw - player.rotation.y
		var aimed_pitch: float = pitch - player.head.rotation.x
		var want: float = LENS_ZOOM[case[1]]
		_expect(absf(hip_yaw / aimed_yaw / want - 1.0) <= 0.02 and absf(hip_pitch / aimed_pitch / want - 1.0) <= 0.02,
				"%s with %s aimed: the mouse turns %.4f and pitches %.4f rad against %.4f and %.4f at the hip, want %.2f times less within 2%%" % [
					case[0], case[1], aimed_yaw, aimed_pitch, hip_yaw, hip_pitch, want])
		await suite._aim(false)
		player.head.rotation.x = 0.0


## The scope's rear glass, the mesh the lens is drawn on.
func _rear_glass(attachment_file: String) -> MeshInstance3D:
	var model: Node3D = suite.weapon.fitting.model_of(load(DIR % attachment_file))
	return null if model == null else model.find_child("*_RearGlass", true, false) as MeshInstance3D


## Aimed through a scope the eye is 0.06 m from the rear glass's middle, on
## the camera's axis, within 2 mm; the rear glass carries the lens shader.
func _check_eye_to_glass() -> void:
	for case in [["marksman_rifle", "long_scope"], ["assault_rifle", "combat_scope"]]:
		var built := await _hold(case[0], [case[1]])
		if built == null:
			continue
		await _aim_settled()
		var glass := _rear_glass(case[1])
		_expect(glass != null, "%s with %s has no rear glass" % [case[0], case[1]])
		if glass == null:
			continue
		var at: Vector3 = suite.player.camera.to_local(glass.global_transform * glass.get_aabb().get_center())
		_expect(absf(-at.z - EYE_TO_GLASS) <= 0.002 and Vector2(at.x, at.y).length() <= 0.002,
				"%s with %s aimed: the rear glass sits at %s from the eye, want 0.060 m straight ahead within 2 mm" % [case[0], case[1], at])
		_expect(glass.get_active_material(0) is ShaderMaterial and glass.get_active_material(0) == _scoped().lens_material(),
				"%s with %s: the rear glass does not carry the lens" % [case[0], case[1]])
		await suite._aim(false)


## The lens camera renders only while aimed through a lens: not at the hip,
## not with a gun's own sights, not with the Reflex Sight.
func _check_lens_renders_only_aimed() -> void:
	var cases := [["marksman_rifle", ["long_scope"], true], ["assault_rifle", ["combat_scope"], true],
			["assault_rifle", ["reflex_sight"], false], ["marksman_rifle", [], false], ["pistol", [], false]]
	for case: Array in cases:
		var built := await _hold(case[0], case[1])
		if built == null:
			continue
		await suite._seconds(0.3)
		_expect(not _scoped().lens_rendering(), "%s with %s at the hip: the lens camera renders" % [case[0], case[1]])
		await _aim_settled()
		_expect(_scoped().lens_rendering() == case[2], "%s with %s aimed: the lens camera %s" % [
				case[0], case[1], "does not render" if case[2] else "renders"])
		await suite._aim(false)
		await suite._seconds(built.aim_time * 3.0 + 0.3)
		_expect(not _scoped().lens_rendering(), "%s with %s dropped: the lens camera still renders" % [case[0], case[1]])


## The surround comes in with the sights through a lens, by how far up they
## are, and is gone at the hip; never with the Reflex Sight.
func _check_surround_follows_sights() -> void:
	var built := await _hold("marksman_rifle", ["long_scope"])
	if built == null:
		return
	_expect(_scoped().surround_amount() == 0.0, "the surround shows at the hip")
	await suite._aim(true)
	await suite._seconds(built.aim_time * 0.5)
	var halfway: float = _scoped().surround_amount()
	_expect(absf(halfway - suite.player.aim_progress) < 0.05 and halfway > 0.2 and halfway < 0.8,
			"halfway up the surround is %.2f with the sights %.2f up" % [halfway, suite.player.aim_progress])
	await suite._seconds(built.aim_time * 2.0)
	_expect(_scoped().surround_amount() == 1.0, "aimed, the surround is %.2f, want 1" % _scoped().surround_amount())
	await suite._aim(false)
	await suite._seconds(built.aim_time * 2.0)
	_expect(_scoped().surround_amount() == 0.0, "dropped, the surround is %.2f" % _scoped().surround_amount())
	await _hold("assault_rifle", ["reflex_sight"])
	await _aim_settled()
	_expect(_scoped().surround_amount() == 0.0, "the Reflex Sight blurs the surround")
	await suite._aim(false)


## The reticle is drawn at the middle of the screen wherever the glass is, so
## it stays on the shot line as long as the glass still covers the middle:
## with the gun 6 mm off its aimed pose the middle of the screen is still
## inside each scope's lens and the Reflex Sight's window. Where it lands in
## pixels is measured by `tests/shots.sh scoped`.
func _check_reticle_seen_when_shifted() -> void:
	var cases := [["marksman_rifle", "long_scope"], ["assault_rifle", "combat_scope"], ["assault_rifle", "reflex_sight"]]
	for case: Array in cases:
		var built := await _hold(case[0], [case[1]])
		if built == null:
			continue
		await _aim_settled()
		var glass := _scoped().glass()
		_expect(glass != null and glass.is_visible_in_tree(), "%s with %s has no glass to see the reticle through" % [case[0], case[1]])
		if glass == null:
			continue
		if case[1] == "reflex_sight":
			_expect_window_clear(glass)
		var weapon: Viewmodel = suite.weapon
		weapon.set_process(false)
		for shift in [Vector3(SHIFT, 0, 0), Vector3(-SHIFT, 0, 0), Vector3(0, SHIFT, 0), Vector3(0, -SHIFT, 0)]:
			weapon.position = weapon.pose_ads + shift
			# Where the glass is drawn on screen, in half-heights, with the
			# Viewmodel's own field of view, and how far its edge reaches.
			var box := glass.get_aabb()
			var at: Vector3 = suite.player.camera.to_local(glass.global_transform * box.get_center())
			var scale := 1.0 / (-at.z * tan(deg_to_rad(weapon.fov_override) * 0.5))
			var reach := minf(box.size.x, box.size.y) * 0.5 * scale
			var off := Vector2(at.x, at.y).length() * scale
			_expect(off < reach, "%s with %s shifted %s: the glass's middle is %.3f half-heights off centre, its edge only %.3f" % [
					case[0], case[1], shift, off, reach])
		weapon.set_process(true)
		await suite._aim(false)


## Nothing of the Reflex Sight's own model sits within 3 mm of its aim
## point, the middle of [param window], where it would hide the reticle (the
## model's built-in glowing dot is taken out).
func _expect_window_clear(window: MeshInstance3D) -> void:
	var model := window.get_parent().get_parent() as MeshInstance3D
	var centre := (window.get_parent() as Node3D).position
	var near := 0
	for i in model.mesh.get_surface_count():
		for v: Vector3 in model.mesh.surface_get_arrays(i)[Mesh.ARRAY_VERTEX]:
			if v.distance_to(centre) <= 0.003:
				near += 1
	_expect(near == 0, "%d of the Reflex Sight model's vertices sit within 3 mm of its aim point, in front of the reticle" % near)


## The HUD crosshair is hidden while aimed through a lens or a Reflex Sight
## and shown otherwise: at the hip with them, and aimed with a gun's own
## sights.
func _check_hud_crosshair_hides() -> void:
	var cases := [["marksman_rifle", ["long_scope"], true], ["assault_rifle", ["combat_scope"], true],
			["assault_rifle", ["reflex_sight"], true], ["pistol", ["reflex_sight"], true],
			["marksman_rifle", [], false], ["pistol", [], false], ["assault_rifle", ["long_barrel"], false]]
	for case: Array in cases:
		var built := await _hold(case[0], case[1])
		if built == null:
			continue
		_expect(suite.hud.crosshair_shown(), "%s with %s at the hip: the crosshair is hidden" % [case[0], case[1]])
		await _aim_settled()
		_expect(suite.hud.crosshair_shown() != case[2], "%s with %s aimed: the crosshair is %s" % [
				case[0], case[1], "shown" if suite.hud.crosshair_shown() else "hidden"])
		await suite._aim(false)
		_expect(suite.hud.crosshair_shown(), "%s with %s dropped: the crosshair is hidden" % [case[0], case[1]])
