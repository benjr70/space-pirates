class_name ScopedView
extends Node
## What the Pirate sees through a Sight Attachment in Aim Down Sights
## (`.scratch/weapon-attachments/spec.md`, "Scoped view").
##
## A scope (an [Attachment] with [member Attachment.lens]: the Combat Scope,
## the Long Scope) is a picture-in-picture lens. Its rear glass
## (`<Model>_RearGlass`) shows a second camera's picture of the scene,
## magnified by the Built Weapon's `ads_zoom` against the unaimed view, while
## the Pirate's own camera zooms only [constant WeaponProfile.VIEW_AROUND_LENS]
## and the gun stays on screen. Outside the lens the screen blurs and goes
## dark toward its edge by how far up the sights are
## (the Pirate's `aim_progress`). The reticle is a red cross on the shot
## line, seen only through the lens.
##
## The Reflex Sight is an unmagnified window at its aim point with a red dot
## on the shot line, seen only through the window; the whole view zooms as
## with a gun's own sights and nothing blurs.
##
## The lens camera leaves out the Viewmodel's render layer
## ([constant Viewmodel.LAYER]), so the lens never looks down its own tube, and
## renders only while the sights are up through a lens. The lens and the
## reticle are drawn by `resources/shaders/scope_lens.gdshader`, the blur and
## the dark edge by `resources/shaders/scope_surround.gdshader`.

const LENS_SHADER: Shader = preload("res://resources/shaders/scope_lens.gdshader")
const SURROUND_SHADER: Shader = preload("res://resources/shaders/scope_surround.gdshader")
## The lens camera's square picture, in pixels.
const PICTURE_SIZE := 1024
## How many of the screen's half-heights the picture covers either side of
## the middle: more than the lens ever spans, so a swaying gun never carries
## the lens off the picture's edge.
const PICTURE_SPAN := 1.15
## The screen mipmap level read outside the lens, and how dark the screen
## goes toward its edge (1 is black at the corners): the user's settings.
const BLUR := 2.0
const EDGE_DARK := 1.0
## The Reflex Sight's window: the opening of its frame, centred on its aim
## point, in metres.
const WINDOW_SIZE := Vector2(0.029, 0.027)
## How far from the Reflex Sight's aim point its model's own glowing dot
## reaches (a 2.2 mm cube), in metres; the frame's nearest edge is 13 mm off.
const BUILT_IN_DOT_REACH := 0.003
## How much the window tints what is seen through it.
const WINDOW_TINT := 0.10
## Reticles the lens shader draws.
const RETICLE_DOT := 0
const RETICLE_CROSS := 1

## The lens camera and the picture it renders into.
var lens_view: SubViewport
var lens_camera: Camera3D

var _pirate: CharacterBody3D
var _viewmodel: Viewmodel
var _camera: Camera3D
## The fitted Sight's glass (a scope's rear glass or the Reflex Sight's
## window), and a scope's lens material; null without them.
var _glass: MeshInstance3D
var _lens: ShaderMaterial
## The blur and dark edge round the lens, and how much of it shows.
var _surround: ColorRect
var _amount := 0.0


func _ready() -> void:
	_pirate = get_parent() as CharacterBody3D
	_camera = _pirate.get_node("Head/Camera3D")
	_viewmodel = _camera.get_node("Weapon")

	lens_view = SubViewport.new()
	lens_view.name = "LensView"
	lens_view.size = Vector2i(PICTURE_SIZE, PICTURE_SIZE)
	lens_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(lens_view)
	lens_camera = Camera3D.new()
	lens_camera.name = "LensCamera"
	lens_camera.near = _camera.near
	lens_camera.set_cull_mask_value(Viewmodel.LAYER, false)
	lens_view.add_child(lens_camera)

	var layer := CanvasLayer.new()
	layer.name = "Surround"
	# Under the HUD, over the scene.
	layer.layer = 0
	add_child(layer)
	_surround = ColorRect.new()
	_surround.set_anchors_preset(Control.PRESET_FULL_RECT)
	_surround.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = SURROUND_SHADER
	material.set_shader_parameter("blur", BLUR)
	material.set_shader_parameter("edge", EDGE_DARK)
	_surround.material = material
	_surround.visible = false
	layer.add_child(_surround)

	_viewmodel.mounted.connect(_on_mounted)
	_on_mounted()


## The fitted Sight's glass on the gun in hand, the reticle's only window:
## a scope's rear glass or the Reflex Sight's window. Null without a Sight.
func glass() -> MeshInstance3D:
	return _glass


## The live lens material on the fitted scope's rear glass, or null.
func lens_material() -> ShaderMaterial:
	return _lens


## The lens camera is drawing: the sights are up, or coming up, through a lens.
func lens_rendering() -> bool:
	return lens_view.render_target_update_mode != SubViewport.UPDATE_DISABLED


## How much of the blur and dark edge shows: how far up the sights are
## through a lens, 0 otherwise.
func surround_amount() -> float:
	return _amount


## A new gun or Built Weapon in hand: find its Sight's glass and dress it.
func _on_mounted() -> void:
	_glass = null
	_lens = null
	var fitting := _viewmodel.fitting
	if fitting == null:
		return
	for attachment in fitting.fitted:
		if attachment.slot != Attachment.Slot.SIGHT:
			continue
		var model := fitting.model_of(attachment)
		if model == null:
			continue
		if attachment.lens:
			_glass = model.find_child("*_RearGlass", true, false) as MeshInstance3D
			if _glass != null:
				_lens = _lens_on(_glass)
		else:
			_glass = _window_on(model)


## The lens material on a scope's [param rear_glass], made the first time.
## The Viewmodel has already given the glass its own copy of a flagged
## material; the lens takes that copy's place.
func _lens_on(rear_glass: MeshInstance3D) -> ShaderMaterial:
	var made := rear_glass.get_surface_override_material(0) as ShaderMaterial
	if made != null:
		return made
	var box := rear_glass.get_aabb()
	made = _glass_material(RETICLE_CROSS, 1.0)
	made.set_shader_parameter("picture", lens_view.get_texture())
	made.set_shader_parameter("picture_span", PICTURE_SPAN)
	made.set_shader_parameter("glass_centre", Vector2(box.get_center().x, box.get_center().y))
	made.set_shader_parameter("glass_radius", minf(box.size.x, box.size.y) * 0.5)
	rear_glass.set_surface_override_material(0, made)
	return made


## The window of an unmagnified Sight (the Reflex Sight) on [param model],
## centred on its aim point, made the first time. It rides with the model.
func _window_on(model: Node3D) -> MeshInstance3D:
	var tip := model.find_child("*_SightTip", true, false) as Node3D
	if tip == null:
		return null
	var named := String(model.name) + "_Window"
	var window := tip.get_node_or_null(named) as MeshInstance3D
	if window != null:
		return window
	var quad := QuadMesh.new()
	quad.size = WINDOW_SIZE
	window = MeshInstance3D.new()
	window.name = named
	window.mesh = quad
	window.layers = 1 << (Viewmodel.LAYER - 1)
	window.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	window.set_surface_override_material(0, _glass_material(RETICLE_DOT, WINDOW_TINT))
	tip.add_child(window)
	if model is MeshInstance3D:
		_drop_built_in_dot(model as MeshInstance3D, tip.position)
	return window


## The Reflex Sight's model carries a little glowing dot of its own in the
## middle of its window (`reflex_dot` in `tools/blender/attachments.py`),
## fixed to the gun; it would hide the reticle when the window is centred and
## show a second dot when the gun sways. The model gets a copy of its mesh
## without the triangles within [constant BUILT_IN_DOT_REACH] of
## [param centre], its aim point, where nothing else of the frame comes.
func _drop_built_in_dot(model: MeshInstance3D, centre: Vector3) -> void:
	var overrides: Array[Material] = []
	for i in model.mesh.get_surface_count():
		overrides.append(model.get_surface_override_material(i))
	var trimmed := ArrayMesh.new()
	for i in model.mesh.get_surface_count():
		var tool := MeshDataTool.new()
		tool.create_from_surface(model.mesh as ArrayMesh, i)
		var kept := SurfaceTool.new()
		kept.begin(Mesh.PRIMITIVE_TRIANGLES)
		for face in tool.get_face_count():
			var inside := true
			for corner in 3:
				var v := tool.get_face_vertex(face, corner)
				inside = inside and tool.get_vertex(v).distance_to(centre) <= BUILT_IN_DOT_REACH
			if inside:
				continue
			for corner in 3:
				var v := tool.get_face_vertex(face, corner)
				kept.set_normal(tool.get_vertex_normal(v))
				kept.set_uv(tool.get_vertex_uv(v))
				kept.add_vertex(tool.get_vertex(v))
		kept.generate_tangents()
		kept.set_material(model.mesh.surface_get_material(i))
		kept.commit(trimmed)
	model.mesh = trimmed
	for i in overrides.size():
		model.set_surface_override_material(i, overrides[i])


func _glass_material(reticle: int, tint: float) -> ShaderMaterial:
	var made := ShaderMaterial.new()
	made.shader = LENS_SHADER
	made.set_shader_parameter("fov_override", _viewmodel.fov_override)
	made.set_shader_parameter("z_clip_scale", _viewmodel.z_clip_scale)
	made.set_shader_parameter("reticle", reticle)
	made.set_shader_parameter("glass", tint)
	return made


func _process(_delta: float) -> void:
	var weapon: WeaponProfile = _pirate.weapon
	var through_lens: bool = _lens != null and weapon.aims_through_lens
	_amount = _pirate.aim_progress if through_lens else 0.0
	var rendering := _amount > 0.0
	lens_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS if rendering else SubViewport.UPDATE_DISABLED
	if _lens != null:
		_lens.set_shader_parameter("magnifies", rendering)
	if rendering:
		# The lens lays PICTURE_SPAN half-heights of this picture over the
		# screen, so that much of the unaimed view at the lens's zoom.
		lens_camera.global_transform = _camera.global_transform
		var half := PICTURE_SPAN * tan(deg_to_rad(_pirate.hip_fov()) * 0.5) / weapon.ads_zoom
		lens_camera.fov = rad_to_deg(2.0 * atan(half))
	_surround.visible = _amount > 0.01
	if _surround.visible:
		# The lens is drawn with the Viewmodel's own field of view, so that is
		# the projection that says where it is on screen.
		var box := _glass.get_aabb()
		var at := _camera.to_local(_glass.global_transform * box.get_center())
		var scale := 1.0 / (maxf(-at.z, 0.01) * tan(deg_to_rad(_viewmodel.fov_override) * 0.5))
		var material := _surround.material as ShaderMaterial
		material.set_shader_parameter("lens_centre", Vector2(at.x, -at.y) * scale)
		material.set_shader_parameter("lens_radius", minf(box.size.x, box.size.y) * 0.5 * scale)
		material.set_shader_parameter("amount", _amount)
