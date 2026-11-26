class_name CrewRigModifier
extends SkeletonModifier3D
## What a crew rig's skeleton modifiers share: bones read and written in
## the rig's own space (the body's Model node: metres, +Z ahead of the body,
## +X to its left, on a rig fitted to 2 m), and the two-bone solve that puts
## an arm or a leg onto a target. [CrewPose] (the body: hips, spine, head,
## legs and feet) and [CrewGun] (the gun and the arms on it) both extend it;
## the pose runs first, so the gun is placed from the posed chest.

## Whose rig.
var crew: Crew3D

var _sk: Skeleton3D
var _to_model := Transform3D.IDENTITY
var _to_bones := Transform3D.IDENTITY
## Bone indices by name.
var _index := {}


## Reads the skeleton and the rig's space for this frame. False when there
## is nothing to pose.
func _begin_frame() -> bool:
	_sk = get_skeleton()
	if _sk == null or crew == null or not is_instance_valid(crew):
		return false
	_to_model = crew.model.global_transform.affine_inverse() * _sk.global_transform
	_to_bones = _to_model.affine_inverse()
	return true


## A bone's index, looked up once.
func _i(bone: String) -> int:
	var found: Variant = _index.get(bone)
	if found == null:
		found = _sk.find_bone(bone)
		_index[bone] = found
	return found


func _bone(bone: String) -> Transform3D:
	return _to_model * _sk.get_bone_global_pose(_i(bone))


func _rest_pose(bone: String) -> Transform3D:
	return _to_model * _sk.get_bone_global_rest(_i(bone))


func _put(bone: String, pose: Transform3D) -> void:
	_sk.set_bone_global_pose(_i(bone), _to_bones * pose)


func _rest_local(bone: String) -> void:
	var i := _i(bone)
	if i >= 0:
		_sk.set_bone_pose_rotation(i, _sk.get_bone_rest(i).basis.get_rotation_quaternion())


func _turn_bone(bone: String, axis: Vector3, angle: float) -> void:
	if is_zero_approx(angle):
		return
	var pose := _bone(bone)
	pose.basis = Basis(axis, angle) * pose.basis
	_put(bone, pose)


## Points a bone (its +Y) along [param direction], by the shortest turn.
func _aim_bone(bone: String, direction: Vector3) -> void:
	var pose := _bone(bone)
	var now := pose.basis.y.normalized()
	var want := direction.normalized()
	if now.dot(want) > 0.9999:
		return
	if now.dot(want) < -0.9999:
		pose.basis = Basis(pose.basis.x.normalized(), PI) * pose.basis
	else:
		pose.basis = Basis(Quaternion(now, want)) * pose.basis
	_put(bone, pose)


## The rest length from one bone's head to another's, in the rig's space.
func _rest_length(from: String, to: String) -> float:
	return (_rest_pose(to).origin - _rest_pose(from).origin).length()


## Two bones solved so the second one's far end reaches [param target], the
## joint between them pushed toward [param pole].
func _two_bone(upper: String, lower: String, lower_length: float, target: Vector3, pole: Vector3) -> void:
	var root := _bone(upper).origin
	var upper_length := (_bone(lower).origin - root).length()
	var to := target - root
	var reach := clampf(to.length(), 0.01, upper_length + lower_length - 0.002)
	var along := to.normalized()
	var near := (upper_length * upper_length + reach * reach - lower_length * lower_length) / (2.0 * reach)
	var out := sqrt(maxf(upper_length * upper_length - near * near, 0.0))
	var side := pole - along * pole.dot(along)
	if side.length_squared() < 0.0001:
		side = Vector3.FORWARD - along * Vector3.FORWARD.dot(along)
	var joint := root + along * near + side.normalized() * out
	_aim_bone(upper, joint - root)
	_aim_bone(lower, root + along * reach - _bone(lower).origin)
