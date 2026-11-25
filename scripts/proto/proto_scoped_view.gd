extends Node
## PROTOTYPE, throwaway -- what the scoped view looks like
## (.scratch/weapon-attachments/issues/07-scoped-view.md).
##
##   flatpak run org.godotengine.Godot --path . res://scenes/proto_scoped_view.tscn \
##       -- --seed=7 --class=large
##
## A real Raid with the Marksman Rifle in hand and a rough scope built in code
## on its rail. Five views to compare in Aim Down Sights:
##
##   own sights    the rifle as it is today: open sights, the whole view zooms
##   zoom          a scope on the gun; the whole view zooms, the reticle shows
##                 only through the lens
##   overlay       the gun leaves the screen: a black surround with a round
##                 hole and a reticle, the whole view zooms
##   lens          picture-in-picture: only the lens magnifies, the view
##                 around the scope barely zooms
##   red dot       an unmagnified Reflex Sight: a window with a dot that stays
##                 on the shot line while the gun moves around it
##
##   F5        next view
##   F6 F7     magnification down / up (scope views)
##   F8 F9     how much the view around the lens zooms (lens view only)
##   F10       reticle: dot / cross / chevron
##   9 0       eye nearer to / further from the sight
##   F2        cannot die, on/off (starts on)
##
## The mouse slows by the magnification in every view.

enum View { OWN, ZOOM, OVERLAY, LENS, RED_DOT }
const VIEW_NAMES := ["own sights", "zoom", "overlay", "lens (picture-in-picture)", "red dot"]
const RETICLES := ["dot", "cross", "chevron"]
const OWN_ZOOM := 3.0
const RED_DOT_ZOOM := 1.36
## The lens shows this much of the screen's half-height of scope picture, so
## sway never runs off its edge.
const PIP_SPAN := 0.7
const PIP_SIZE := 640
const VIEWMODEL_LAYER := 2

const LENS_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never;
uniform float fov_override = 50.0;
uniform float z_clip = 0.35;
uniform sampler2D pip : source_color, filter_linear, repeat_disable;
uniform bool use_pip = false;
uniform bool round_lens = true;
uniform float pip_span = 0.7;
uniform int reticle = 0;
uniform vec3 reticle_color : source_color = vec3(1.0, 0.12, 0.08);
uniform float glass = 0.10;

void vertex() {
	// What BaseMaterial3D's FOV override and depth scale do, by hand.
	float f = 1.0 / tan(radians(fov_override) * 0.5);
	float aspect = abs(PROJECTION_MATRIX[1][1] / PROJECTION_MATRIX[0][0]);
	PROJECTION_MATRIX[1][1] = sign(PROJECTION_MATRIX[1][1]) * f;
	PROJECTION_MATRIX[0][0] = sign(PROJECTION_MATRIX[0][0]) * f / aspect;
	Z_CLIP_SCALE = z_clip;
}

float mark(vec2 px) {
	if (reticle == 0) {
		return 1.0 - smoothstep(2.5, 4.0, length(px));
	} else if (reticle == 1) {
		float gap = step(7.0, max(abs(px.x), abs(px.y)));
		float line = (1.0 - smoothstep(0.8, 1.8, min(abs(px.x), abs(px.y)))) * gap;
		return max(line, 1.0 - smoothstep(1.2, 2.2, length(px)));
	}
	float y = px.y - 1.0;
	float arm = abs(abs(px.x) - y) * 0.7071;
	return (1.0 - smoothstep(1.0, 2.2, arm)) * step(0.0, y) * step(y, 16.0);
}

void fragment() {
	vec2 c = UV - 0.5;
	if (round_lens && length(c) > 0.5) {
		discard;
	}
	// Where this pixel is from the middle of the screen, in half-heights.
	vec2 p = (SCREEN_UV - 0.5) * 2.0;
	p.x *= VIEWPORT_SIZE.x / VIEWPORT_SIZE.y;
	vec3 colour = vec3(0.03, 0.05, 0.06);
	float alpha = glass;
	if (use_pip) {
		vec2 uv = 0.5 + p * 0.5 / pip_span;
		colour = texture(pip, uv).rgb;
		if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
			colour = vec3(0.0);
		}
		alpha = 1.0;
		if (round_lens) {
			colour *= 1.0 - smoothstep(0.40, 0.5, length(c));
		}
	}
	float m = mark(p * VIEWPORT_SIZE.y * 0.5);
	ALBEDO = mix(colour, reticle_color, m);
	ALPHA = max(alpha, m);
}
"""

const OVERLAY_SHADER := """
shader_type canvas_item;
uniform float hole = 0.80;
uniform int reticle = 0;
void fragment() {
	vec2 size = 1.0 / SCREEN_PIXEL_SIZE;
	vec2 p = (SCREEN_UV - 0.5) * 2.0;
	p.x *= size.x / size.y;
	vec2 px = p * size.y * 0.5;
	float dark = smoothstep(hole - 0.02, hole + 0.01, length(p));
	float line = 0.0;
	if (reticle == 0) {
		line = 1.0 - smoothstep(2.5, 4.0, length(px));
	} else if (reticle == 1) {
		float thin = 1.0 - smoothstep(0.8, 1.8, min(abs(px.x), abs(px.y)));
		float thick = (1.0 - smoothstep(2.5, 3.5, min(abs(px.x), abs(px.y)))) * step(size.y * 0.16, max(abs(px.x), abs(px.y)));
		line = max(thin * step(7.0, max(abs(px.x), abs(px.y))), thick);
	} else {
		float y = px.y - 1.0;
		line = (1.0 - smoothstep(1.0, 2.2, abs(abs(px.x) - y) * 0.7071)) * step(0.0, y) * step(y, 16.0);
	}
	COLOR = vec4(vec3(0.0), max(dark, line * 0.9));
}
"""

var _player: Node
var _view: Node
var _rifle: WeaponProfile
var _model: Node3D
var _own_sight: Vector3
var _scope: Node3D
var _scope_lens: MeshInstance3D
var _reflex: Node3D
var _reflex_lens: MeshInstance3D
var _pip: SubViewport
var _pip_camera: Camera3D
var _overlay: ColorRect
var _label: Label

var _which := View.ZOOM
var _magnification := 4.0
var _surround := 1.25
var _reticle := 1
var _eye := 0.10
var _immortal := true
var _base_sensitivity := 0.0


func _ready() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	_player = get_parent().player
	_view = _player.viewmodel
	_base_sensitivity = _player.mouse_sensitivity
	var stock_rifle: WeaponProfile = load("res://resources/weapons/marksman_rifle.tres")
	_rifle = stock_rifle.duplicate()
	var at: int = _player.weapons.find(stock_rifle)
	_player.weapons[at] = _rifle
	_player.swap_time = 0.0
	_player.weapon = _rifle
	_player.ammo = _rifle.magazine_size
	_player.ammo_changed.emit(_player.ammo)
	_view._mount(_rifle)
	_player.swap_time = 0.4
	_model = _view._mounted
	_own_sight = _view._sight_tip.position

	_build_sights()
	_build_pip()
	_build_overlay()
	_apply()
	if "--selftest" in OS.get_cmdline_user_args():
		_selftest()
	elif "--shots" in OS.get_cmdline_user_args():
		_shots()


func _metal(colour := Color(0.05, 0.05, 0.06)) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = colour
	m.metallic = 0.8
	m.roughness = 0.45
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


func _tube(parent: Node3D, radius: float, length: float, z: float) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = length
	mesh.cap_top = false
	mesh.cap_bottom = false
	mesh.radial_segments = 32
	mesh.material = _metal()
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.rotation_degrees = Vector3(90, 0, 0)
	node.position = Vector3(0, 0, z)
	parent.add_child(node)


func _box(parent: Node3D, size: Vector3, at: Vector3) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = _metal()
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = at
	parent.add_child(node)


func _lens(parent: Node3D, size: Vector2, z: float, round_lens: bool) -> MeshInstance3D:
	var mesh := QuadMesh.new()
	mesh.size = size
	var shader := Shader.new()
	shader.code = LENS_SHADER
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("round_lens", round_lens)
	material.set_shader_parameter("fov_override", _view.fov_override)
	material.set_shader_parameter("z_clip", _view.z_clip_scale)
	material.set_shader_parameter("pip_span", PIP_SPAN)
	mesh.material = material
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = Vector3(0, 0, z)
	parent.add_child(node)
	return node


## A scope and a Reflex Sight on the rail, each in a frame whose -Z runs down
## the barrel and whose origin is the middle of the glass the eye looks into.
func _build_sights() -> void:
	var tip: Vector3 = (_model.find_child("SightTip", true, false) as Node3D).global_position
	var rear: Vector3 = (_model.find_child("SightRear", true, false) as Node3D).global_position
	var up: Vector3 = _model.global_transform.basis.y.normalized()
	var frame := Transform3D(Basis.looking_at(tip - rear, up), rear + up * 0.034)

	_scope = Node3D.new()
	_model.add_child(_scope)
	_scope.global_transform = frame
	_tube(_scope, 0.0150, 0.170, -0.085)
	_tube(_scope, 0.0190, 0.034, -0.012)
	_tube(_scope, 0.0215, 0.046, -0.180)
	_box(_scope, Vector3(0.012, 0.010, 0.010), Vector3(0, 0.020, -0.090))
	_box(_scope, Vector3(0.018, 0.030, 0.012), Vector3(0, -0.028, -0.050))
	_box(_scope, Vector3(0.018, 0.030, 0.012), Vector3(0, -0.028, -0.125))
	_scope_lens = _lens(_scope, Vector2(0.037, 0.037), 0.0, true)

	_reflex = Node3D.new()
	_model.add_child(_reflex)
	_reflex.global_transform = frame.translated_local(Vector3(0, -0.004, -0.060))
	_box(_reflex, Vector3(0.030, 0.008, 0.050), Vector3(0, -0.022, 0.012))
	_box(_reflex, Vector3(0.036, 0.003, 0.006), Vector3(0, 0.0145, 0))
	_box(_reflex, Vector3(0.036, 0.003, 0.006), Vector3(0, -0.0145, 0))
	_box(_reflex, Vector3(0.003, 0.032, 0.006), Vector3(0.0165, 0, 0))
	_box(_reflex, Vector3(0.003, 0.032, 0.006), Vector3(-0.0165, 0, 0))
	_reflex_lens = _lens(_reflex, Vector2(0.030, 0.026), 0.0, false)

	for sight: Node3D in [_scope, _reflex]:
		_view._flag_materials(sight)
	# Everything he holds goes on its own layer, so the lens camera can leave
	# it out and not look down the inside of its own scope.
	for found in _view.find_children("*", "VisualInstance3D", true, false):
		(found as VisualInstance3D).layers = 1 << (VIEWMODEL_LAYER - 1)


func _build_pip() -> void:
	_pip = SubViewport.new()
	_pip.size = Vector2i(PIP_SIZE, PIP_SIZE)
	_pip.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_pip)
	_pip_camera = Camera3D.new()
	_pip_camera.near = 0.05
	_pip_camera.set_cull_mask_value(VIEWMODEL_LAYER, false)
	_pip.add_child(_pip_camera)
	(_scope_lens.get_active_material(0) as ShaderMaterial).set_shader_parameter("pip", _pip.get_texture())


func _build_overlay() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 0
	add_child(layer)
	_overlay = ColorRect.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = OVERLAY_SHADER
	var material := ShaderMaterial.new()
	material.shader = shader
	_overlay.material = material
	_overlay.visible = false
	layer.add_child(_overlay)

	var top := CanvasLayer.new()
	top.layer = 20
	add_child(top)
	_label = Label.new()
	_label.position = Vector2(24, 110)
	_label.add_theme_font_size_override("font_size", 16)
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 6)
	top.add_child(_label)


func _apply() -> void:
	var scoped: bool = _which in [View.ZOOM, View.OVERLAY, View.LENS]
	_scope.visible = scoped
	_reflex.visible = _which == View.RED_DOT
	match _which:
		View.OWN: _rifle.ads_zoom = OWN_ZOOM
		View.ZOOM, View.OVERLAY: _rifle.ads_zoom = _magnification
		View.LENS: _rifle.ads_zoom = _surround
		View.RED_DOT: _rifle.ads_zoom = RED_DOT_ZOOM
	_pip.render_target_update_mode = SubViewport.UPDATE_ALWAYS if _which == View.LENS else SubViewport.UPDATE_DISABLED
	var lens := _scope_lens.get_active_material(0) as ShaderMaterial
	lens.set_shader_parameter("use_pip", _which == View.LENS)
	lens.set_shader_parameter("reticle", _reticle)
	_overlay.material.set_shader_parameter("reticle", _reticle)
	# The red dot is a dot whatever the scopes carry.
	(_reflex_lens.get_active_material(0) as ShaderMaterial).set_shader_parameter("reticle", 0)

	# The sights centre on whichever glass is up.
	var sight := _own_sight
	if _which != View.OWN:
		var glass: Node3D = _reflex if _which == View.RED_DOT else _scope
		_view._stop_clip()
		sight = _view.global_transform.affine_inverse() * glass.global_position
	_view._sight_tip.position = sight
	var turned: Vector3 = Basis.from_euler(_view.rotation_hip * PI / 180.0) * sight
	# With a glass up, `_eye` is the distance from the eye to it; the rifle's
	# own sights keep the Profile's distance.
	var z: float = -_rifle.ads_distance if _which == View.OWN else -_eye - turned.z
	_view.pose_ads = Vector3(-turned.x, -turned.y, z)


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo) or _model == null:
		return
	match event.physical_keycode:
		KEY_F5: _which = (_which + 1) % View.size() as View
		KEY_F6: _magnification = maxf(_magnification - 0.5, 1.5)
		KEY_F7: _magnification = minf(_magnification + 0.5, 8.0)
		KEY_F8: _surround = maxf(_surround - 0.05, 1.0)
		KEY_F9: _surround = minf(_surround + 0.05, 2.0)
		KEY_F10: _reticle = (_reticle + 1) % RETICLES.size()
		KEY_9: _eye = maxf(_eye - 0.01, 0.06)
		KEY_0: _eye = minf(_eye + 0.01, 0.40)
		KEY_F2: _immortal = not _immortal
		_: return
	_apply()
	print("[scoped view] ", _state_line())


## How much the thing he aims through magnifies, against the unaimed view.
func _power() -> float:
	match _which:
		View.OWN: return OWN_ZOOM
		View.RED_DOT: return RED_DOT_ZOOM
	return _magnification


func _state_line() -> String:
	var line := "view: %s, magnification %.1fx, reticle %s" % [VIEW_NAMES[_which], _power(), RETICLES[_reticle]]
	if _which == View.LENS:
		line += ", view around the lens %.2fx" % _surround
	if _which != View.OWN:
		line += ", eye to glass %.2f m" % _eye
	return line


func _process(_delta: float) -> void:
	if _label == null:
		return
	if _immortal and _player.health.is_alive():
		_player.health.current = _player.health.max_health
		get_parent().hud.set_health(_player.health.current)
	var holding: bool = _player.weapon == _rifle
	var aimed: bool = holding and _player.ads
	var camera: Camera3D = _player.camera

	# The Pirate divides the mouse by the Profile's zoom; make that come out
	# as the magnification he is looking through.
	_player.mouse_sensitivity = _base_sensitivity * (_rifle.ads_zoom / _power() if aimed else 1.0)

	# Overlay: the gun leaves the screen once the sights are nearly up.
	var hip_tan := tan(deg_to_rad(_player._hip_fov) * 0.5)
	var zoomed: float = hip_tan / tan(deg_to_rad(camera.fov) * 0.5)
	var up: bool = aimed and _which == View.OVERLAY and zoomed > lerpf(1.0, _rifle.ads_zoom, 0.8)
	_overlay.visible = up
	_view.visible = not up

	if _which == View.LENS:
		_pip_camera.global_transform = camera.global_transform
		# The lens draws PIP_SPAN half-heights of this picture across the
		# screen, so that much of the main view at `_magnification`.
		var aspect_tan := PIP_SPAN * tan(deg_to_rad(camera.fov) * 0.5) * zoomed / _magnification
		_pip_camera.fov = rad_to_deg(2.0 * atan(aspect_tan))
		(_scope_lens.get_active_material(0) as ShaderMaterial).set_shader_parameter("pip_span", PIP_SPAN)

	_label.text = "SCOPED VIEW PROTOTYPE%s\n%s\n\nF5 view   F6 F7 magnification   F8 F9 view around the lens   F10 reticle   9 0 eye distance   F2 cannot die: %s" % [
		"" if holding else "   (wheel to the Marksman Rifle)", _state_line().replace(", ", "\n"), "on" if _immortal else "off"]


func _selftest() -> void:
	for v in View.size():
		_which = v as View
		_apply()
		for f in 3:
			await get_tree().process_frame
		print("[selftest] ", _state_line(), "  sight ", _view._sight_tip.position.snappedf(0.001), "  aimed ", _view.pose_ads.snappedf(0.001))
	_player.cancel_reload()
	_player._cooldown = 0.0
	for f in 4:
		await get_tree().physics_frame
	print("[selftest] fired: ", _player.fire() != null)
	get_tree().quit()


## Offscreen frames for the agent to read: `--shots` under gamescope.
func _shots() -> void:
	_label.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	DirAccess.make_dir_recursive_absolute("res://.godot/shots/proto_scoped")
	_player.set_physics_process(false)
	_player.rotate_y(deg_to_rad(-14.0))
	_view.set_process(false)
	_view.rotation_degrees = _view.rotation_hip
	var camera: Camera3D = _player.camera
	for v in View.size():
		_which = v as View
		_apply()
		for pose in ["hip", "ads", "ads_swayed"]:
			_player.ads = pose != "hip"
			_view.position = _view.pose_hip if pose == "hip" else _view.pose_ads
			if pose == "ads_swayed":
				_view.position += Vector3(0.006, -0.004, 0)
			var zoom: float = _rifle.ads_zoom if _player.ads else 1.0
			camera.fov = rad_to_deg(2.0 * atan(tan(deg_to_rad(_player._hip_fov) / 2.0) / zoom))
			for f in 6:
				await get_tree().process_frame
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("res://.godot/shots/proto_scoped/%d_%s_%s.png" % [v, VIEW_NAMES[v].get_slice(" ", 0), pose])
	print("SHOTS_DONE")
	get_tree().quit()
