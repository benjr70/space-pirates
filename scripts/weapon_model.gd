class_name WeaponModel
extends Node
## A gun's model showing a Built Weapon's Attachments: wherever a weapon's
## `model` scene is instanced (the Viewmodel, a menu preview), one call puts
## the Attachments on it.
##
##     var model: Node3D = built.model.instantiate()
##     WeaponModel.of(model).fit(built)
##
## Each fitted Attachment shows its model ([member Attachment.model] or its
## per-gun [member Attachment.models], out of `attachments.glb`), the gun's own
## parts it takes the place of hide ([member Attachment.hides]), and a model
## that rides a bone ([member Attachment.rides]) moves with the gun's own
## clips. A shared model goes on its mount point (`MountSight`, `MountMuzzle`,
## `MountUnder`) as it is, since it was built around that point; a per-gun
## model was built in the gun's space and sits where it was built. Fitting
## again shows the next build: the Viewmodel keeps one instance per gun, and
## two Built Weapons of one gun share it.
##
## A fitted Barrel brings its own `<Model>_Muzzle` and a fitted Sight its own
## `<Model>_SightTip`, which [method muzzle] and [method sight_tip] give in
## place of the gun's `Muzzle` and `SightTip`. A Barrel with a bead (the
## Shotgun's own) brings a `_SightTip` too, the aim point while no Sight is
## fitted: a Sight's beats a Barrel's.
##
## It lives as a child named `WeaponModel` of the model's root, which keeps
## the Attachment models it has placed; the model needs no tree to be fitted.

const ATTACHMENTS: PackedScene = preload("res://assets/models/attachments/attachments.glb")
const NODE_NAME := &"WeaponModel"

## The gun's name: its body mesh's (`Pistol`, `AssaultRifle`, `Shotgun`,
## `MarksmanRifle`), the key an Attachment's per-gun fields use.
var gun: StringName = &""
## What is fitted now, in Slot order.
var fitted: Array[Attachment] = []

var _model: Node3D
var _skeleton: Skeleton3D
## The attachments file under the gun's root, in the gun's space, holding
## every Attachment model not yet placed.
var _source: Node3D
var _own_muzzle: Node3D
var _own_sight_tip: Node3D
var _muzzle: Node3D
var _sight_tip: Node3D
## Attachment model name to its placed node.
var _placed := {}
## Bone name to the BoneAttachment3D its riders hang under.
var _riders := {}
## Every gun part some Attachment has hidden, so the next fit can show it.
var _parts := {}


## The fitting on [param model] (an instance of a weapon's `model` scene),
## made on first use.
static func of(model: Node3D) -> WeaponModel:
	var found := model.get_node_or_null(NodePath(NODE_NAME)) as WeaponModel
	if found != null:
		return found
	var made := WeaponModel.new()
	made.name = NODE_NAME
	made._take(model)
	model.add_child(made)
	return made


func _take(model: Node3D) -> void:
	_model = model
	_skeleton = model.find_child("Skeleton3D", true, false)
	_own_muzzle = model.find_child("Muzzle", true, false)
	_own_sight_tip = model.find_child("SightTip", true, false)
	_muzzle = _own_muzzle
	_sight_tip = _own_sight_tip
	gun = _own_muzzle.get_parent().name
	# The gun's root: the instanced gun file whose space the per-gun models
	# were built in.
	var gun_root: Node = _skeleton
	while gun_root.get_parent() != model:
		gun_root = gun_root.get_parent()
	_source = ATTACHMENTS.instantiate()
	_source.name = "Attachments"
	gun_root.add_child(_source)
	# Per-gun models are named `<Gun>_<Attachment>`; another gun's are no use
	# here. Shared ones have no `_` in their name.
	for child in _source.get_children():
		var named := String(child.name)
		if named.contains("_") and not named.begins_with(String(gun) + "_"):
			_source.remove_child(child)
			child.free()
		elif child is Node3D:
			(child as Node3D).visible = false


## Shows [param weapon]'s Attachments (its [member WeaponProfile.attachments];
## none for a bare Profile) and nothing else. Call it with the gun's bones at
## rest: a rider is hung on its bone where it sits now.
func fit(weapon: WeaponProfile) -> void:
	fitted = weapon.attachments.duplicate()
	var shown := {}
	var hidden := {}
	_muzzle = _own_muzzle
	_sight_tip = _own_sight_tip
	var tip_brought := false
	for attachment in fitted:
		var node := _place(attachment)
		if node == null:
			continue
		shown[node] = true
		for part in attachment.hides_on(gun):
			hidden[part] = true
			_parts[part] = true
		for marker in node.get_children():
			var named := String(marker.name)
			if named.ends_with("_Muzzle"):
				_muzzle = marker
			elif named.ends_with("_SightTip") and not tip_brought:
				# Slot order puts a Sight first, so its aim point beats a bead.
				_sight_tip = marker
				tip_brought = true
	for node: Node3D in _placed.values():
		node.visible = shown.has(node)
	for part: StringName in _parts:
		var mesh := _skeleton.get_node_or_null(NodePath(part)) as Node3D
		if mesh != null:
			mesh.visible = not hidden.has(part)
	# Riders follow their bones from the next skeleton update; until then
	# they sit where the bones are now.
	for bone: StringName in _riders:
		var rider: BoneAttachment3D = _riders[bone]
		rider.transform = _skeleton.get_bone_global_pose(rider.bone_idx)


## The marker a shot leaves from: a fitted Barrel's own, or the gun's.
func muzzle() -> Node3D:
	return _muzzle


## The aim point: a fitted Sight's own, else a fitted Barrel's bead, else the
## gun's front sight.
func sight_tip() -> Node3D:
	return _sight_tip


## The model [param attachment] shows while fitted, or null when it is not
## fitted or has none here. A scope's rear glass is its child mesh
## `<Model>_RearGlass`; the Laser's beam leaves its child `Laser_Origin`.
func model_of(attachment: Attachment) -> Node3D:
	if not attachment in fitted:
		return null
	return _placed.get(attachment.model_on(gun))


## [param attachment]'s model on this gun, placed on its mount or bone the
## first time it is asked for.
func _place(attachment: Attachment) -> Node3D:
	var named := attachment.model_on(gun)
	if named == &"":
		return null
	if _placed.has(named):
		return _placed[named]
	var node := _source.get_node_or_null(NodePath(named)) as Node3D
	if node == null:
		push_error("WeaponModel: %s has no model %s for %s" % [gun, named, attachment.display_name])
		return null
	if not attachment.models.has(gun) and attachment.mount != &"":
		# Shared: built around its mount point, so it goes on as it is.
		var mount := _model.find_child(String(attachment.mount), true, false)
		node.get_parent().remove_child(node)
		mount.add_child(node)
		node.transform = Transform3D.IDENTITY
	var bone := attachment.rides_on(gun)
	if bone != &"":
		var rider := _rider(bone)
		var at := _in(rider, node)
		node.get_parent().remove_child(node)
		rider.add_child(node)
		node.transform = at
	_placed[named] = node
	return node


## The BoneAttachment3D on [param bone], made on first use.
func _rider(bone: StringName) -> BoneAttachment3D:
	if _riders.has(bone):
		return _riders[bone]
	var rider := BoneAttachment3D.new()
	rider.name = "Ride" + bone
	_skeleton.add_child(rider)
	rider.bone_name = bone
	rider.transform = _skeleton.get_bone_global_pose(rider.bone_idx)
	_riders[bone] = rider
	return rider


## [param node]'s transform in [param space]'s space, worked out from local
## transforms so it holds outside the tree too. Both under the model's root.
func _in(space: Node3D, node: Node3D) -> Transform3D:
	return _to_root(space).affine_inverse() * _to_root(node)


func _to_root(node: Node3D) -> Transform3D:
	var out := Transform3D.IDENTITY
	var at: Node = node
	while at != _model:
		if at is Node3D:
			out = (at as Node3D).transform * out
		at = at.get_parent()
	return out
