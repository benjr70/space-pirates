extends CharacterBody3D
## PROTOTYPE — a crew-shaped target (issue #36). Faces -Z with a blue nose,
## shows its hit points overhead, falls over when killed and stands back up.

const TEAM := &"crew"
var health: Health
var _tag: Label3D
var _body: MeshInstance3D


func _ready() -> void:
	health = Health.new()
	health.name = "Health"
	health.max_health = 4
	add_child(health)
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.8
	col.shape = cap
	col.position.y = 0.9
	add_child(col)
	_body = MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.35
	mesh.height = 1.8
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.75, 0.3, 0.3)
	mesh.material = mat
	_body.mesh = mesh
	_body.position.y = 0.9
	add_child(_body)
	var nose := MeshInstance3D.new()
	var nb := BoxMesh.new()
	nb.size = Vector3(0.2, 0.2, 0.3)
	var nm := StandardMaterial3D.new()
	nm.albedo_color = Color(0.3, 0.5, 1.0)
	nb.material = nm
	nose.mesh = nb
	nose.position = Vector3(0, 1.5, -0.4)
	_body.add_child(nose)
	_tag = Label3D.new()
	_tag.font_size = 48
	_tag.pixel_size = 0.005
	_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_tag.position.y = 2.2
	add_child(_tag)
	health.died.connect(_on_died)
	_refresh()


func get_team() -> StringName:
	return TEAM


func is_alive() -> bool:
	return health.is_alive()


func take_damage(amount: int, from: Node = null) -> void:
	health.take_damage(amount, from)
	_refresh()


func _refresh() -> void:
	_tag.text = "%s  %d/%d" % [name, health.current, health.max_health]


func _on_died(_from: Node) -> void:
	_tag.text = "%s  DOWN" % name
	var tw := create_tween()
	tw.tween_property(_body, "rotation_degrees:x", 85.0, 0.25)
	set_collision_layer_value(2, false)
	await get_tree().create_timer(2.0).timeout
	health.reset()
	_body.rotation_degrees.x = 0.0
	set_collision_layer_value(2, true)
	_refresh()
