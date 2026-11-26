class_name CrewSightLine
extends MeshInstance3D
## The Marksman Rifle's tell: a thin red line from the rifle to where it is
## aimed, shown for the length of its sight line before each shot
## ([CrewCover]). A box one metre long, stretched and turned to run between
## two points, unshaded so it reads in any light, casting no shadow.

const WIDTH := 0.012
const COLOUR := Color(1.0, 0.08, 0.05, 0.85)

static var _material: StandardMaterial3D


func _init() -> void:
	name = "SightLine"
	var box := BoxMesh.new()
	box.size = Vector3(WIDTH, WIDTH, 1.0)
	mesh = box
	if _material == null:
		_material = StandardMaterial3D.new()
		_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_material.albedo_color = COLOUR
	material_override = _material
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	top_level = true
	visible = false


## Shown from [param from] to [param to].
func show_between(from: Vector3, to: Vector3) -> void:
	var along := to - from
	var length := along.length()
	if length < 0.01:
		visible = false
		return
	var forward := along / length
	var up := Vector3.UP if absf(forward.dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
	var basis := Basis.looking_at(forward, up)
	global_transform = Transform3D(basis * Basis.from_scale(Vector3(1.0, 1.0, length)), from + along * 0.5)
	visible = true
