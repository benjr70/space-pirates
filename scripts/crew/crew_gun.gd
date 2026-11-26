class_name CrewGun
extends CrewRigModifier
## A Guard's gun, seen in its hands (crew-combat ticket 16): its Weapon
## Profile's model, 1.15x, from the moment it spawns. The gun is placed
## first, from the chest, and the arms are then solved onto it, the wrists
## turned square to it and the fingers closed round its grip and fore-end.
## A skeleton modifier over whatever clip the body plays, as the look
## prototype (`prototype/crew-look`) did: nothing is baked into clips.
##
## Two holds, blended over BLEND seconds:
## - **carrying** (patrol, routine, moving between cover): the Pistol at the
##   thigh in the right hand; a long gun low across the body, both hands on
##   it. It rides the chest as the clip moves it (Idle, Walk, Run).
## - **aiming** ([method Crew3D.aiming], today's FIGHT): the Pistol in two
##   hands; a long gun shouldered, right hand on the grip and left on the
##   fore-end, the torso turned a little side-on. Held still at the chest's
##   place in `Idle_Gun_Pointing` and turned about the body's axis to point
##   where the Guard aims, so its `Muzzle` marker is exactly where
##   [method muzzle_from] says: a shot leaves from it and the clear-shot test
##   sweeps from it.
##
## The carried hold changes with the body's pose ([CrewPose], ticket 22):
## down behind cover the gun is held in close, muzzle up past the cover;
## reloading, the gun is tipped toward the left hand, which leaves it, goes
## to the magazine well, down to the belt and back up to the well with a
## fresh magazine and back onto the fore-end, timed to the reload; for the
## Shotgun from the belt to the loading port once for each shell. A Guard
## reloading holds its gun in the carried hold, never aimed.
##
## Space: the rig's own (the Model node's), metres, +Z ahead of the body,
## +X to its left, on a rig fitted to 2 m.

## The gun is this much bigger than the Pirate's, to suit crew hands.
const SCALE := 1.15
## Seconds from carrying to aiming, and back.
const BLEND := 0.2
## Where the chest bone stands in the rig's `Idle_Gun_Pointing`: aimed holds
## are placed from here, held still, so the muzzle does not breathe.
const AIM_CHEST := Vector3(0.005, 1.446, 0.071)

## A hold: the gun's origin from the chest, the way its barrel points, the
## torso's turn to the right (degrees), the elbows' pull, and whether the
## left hand is on the gun.
const CARRY_LONG := {"at": Vector3(-0.05, -0.30, 0.24), "dir": Vector3(0.55, -0.30, 0.78), "twist": 0.0,
		"elbow_r": Vector3(-0.6, -1.0, -0.4), "elbow_l": Vector3(0.5, -1.0, -0.2), "left": 1.0}
const CARRY_PISTOL := {"at": Vector3(-0.22, -0.46, 0.12), "dir": Vector3(0.0, -0.85, 0.53), "twist": 0.0,
		"elbow_r": Vector3(-0.4, -1.0, -0.6), "elbow_l": Vector3(0.5, -1.0, -0.2), "left": 0.0}
const AIM_LONG := {"at": Vector3(-0.10, -0.10, 0.40), "dir": Vector3(0, 0, 1), "twist": 30.0,
		"elbow_r": Vector3(-1.0, -0.6, -0.2), "elbow_l": Vector3(0.6, -1.0, 0.0), "left": 1.0}
## The Shotgun is held this much further back along its barrel than the
## other long guns, carried or aimed, so the left hand reaches its pump.
const SHOTGUN_BACK := 0.08
const AIM_PISTOL := {"at": Vector3(-0.04, -0.02, 0.36), "dir": Vector3(0, 0, 1), "twist": 0.0,
		"elbow_r": Vector3(-0.8, -1.0, 0.0), "elbow_l": Vector3(0.8, -1.0, 0.0), "left": 1.0}
## Down behind cover (squat or knee): held in close, muzzle up and across
## to the left, so the gun keeps out of the cover it hides behind (a tile's
## prop face is 0.55 m ahead). The Pistol in both hands at the chest,
## muzzle up.
const DOWN_LONG := {"at": Vector3(-0.04, -0.26, 0.16), "dir": Vector3(0.6, 0.72, 0.25), "twist": 0.0,
		"elbow_r": Vector3(-0.8, -1.0, -0.2), "elbow_l": Vector3(0.6, -1.0, 0.0), "left": 1.0}
const DOWN_PISTOL := {"at": Vector3(-0.06, -0.24, 0.22), "dir": Vector3(0.15, 0.7, 0.7), "twist": 0.0,
		"elbow_r": Vector3(-0.8, -1.0, 0.0), "elbow_l": Vector3(0.8, -1.0, 0.0), "left": 1.0}
## Reloading: the gun tipped up and to the left, its well toward the left
## hand.
const RELOAD_LONG := {"at": Vector3(-0.02, -0.24, 0.18), "dir": Vector3(0.75, 0.5, 0.35), "twist": 0.0,
		"elbow_r": Vector3(-0.8, -1.0, -0.2), "elbow_l": Vector3(0.8, -1.0, 0.0), "left": 1.0}
const RELOAD_PISTOL := {"at": Vector3(-0.06, -0.22, 0.2), "dir": Vector3(0.3, 0.65, 0.7), "twist": 0.0,
		"elbow_r": Vector3(-0.8, -1.0, 0.0), "elbow_l": Vector3(0.8, -1.0, 0.0), "left": 1.0}

## Where the left hand takes a magazine from the well, or puts a shell in
## the loading port, in the gun model's space as HOLDS: palm up under it.
const WELLS := {
	CrewHabit.Gun.PISTOL: [Vector3(0.0, -0.07, -0.16), Vector3(0.0, 0.0, -1.0), Vector3(0.0, 1.0, 0.0)],
	CrewHabit.Gun.ASSAULT_RIFLE: [Vector3(0.0, -0.06, 0.062), Vector3(0.0, 0.0, -1.0), Vector3(0.0, 1.0, 0.0)],
	CrewHabit.Gun.SHOTGUN: [Vector3(0.0, -0.02, 0.07), Vector3(0.0, 0.0, -1.0), Vector3(0.0, 1.0, 0.0)],
	CrewHabit.Gun.MARKSMAN_RIFLE: [Vector3(0.0, -0.01, -0.19), Vector3(0.0, 0.0, -1.0), Vector3(0.0, 1.0, 0.0)],
}
## The pouch on the belt, from the hips bone in the rig's space: front left,
## fingers down into it, palm to the body.
const BELT := [Vector3(0.17, -0.02, 0.14), Vector3(1.0, 0.0, 0.0), Vector3(0.0, 0.0, -1.0)]
## A magazine pulled clear of the well (on the way out and back in): this
## far under the well in the rig's space.
const WELL_CLEAR := Vector3(0.04, -0.13, 0.0)
## The left hand's way through a magazine reload, [progress, place]:
## off the fore-end to the well, the old magazine out, down to the belt,
## the new one up and in, seated, back onto the fore-end. For the Shotgun,
## each shell: from the port to the belt and back.
const RELOAD_WAY := [[0.0, "fore"], [0.10, "well"], [0.20, "clear"], [0.40, "belt"], [0.50, "belt"],
		[0.66, "clear"], [0.76, "well"], [0.86, "well"], [1.0, "fore"]]
const SHELL_WAY := [[0.0, "well"], [0.40, "belt"], [0.55, "belt"], [1.0, "well"]]

## Where each hand closes on each gun, in the gun model's own space (+Z to
## the muzzle, +X its left, before SCALE): the middle of what it grips, the
## way the grip runs across the hand (from the index finger to the little
## one), and the way the palm faces it. "grip" is the right hand on the
## pistol grip; "fore" the left, under the fore-end, fingers up its right
## side (the Pistol's: wrapped round the right hand from the left).
const HOLDS := {
	CrewHabit.Gun.PISTOL: {
		"grip": [Vector3(0.0, -0.005, -0.155), Vector3(0.0, -0.966, -0.257), Vector3(1.0, 0.0, 0.0)],
		"fore": [Vector3(0.030, -0.015, -0.140), Vector3(0.0, -0.966, -0.257), Vector3(-1.0, 0.0, 0.2)],
	},
	CrewHabit.Gun.ASSAULT_RIFLE: {
		"grip": [Vector3(0.0, 0.015, -0.148), Vector3(0.0, -0.93, -0.37), Vector3(1.0, 0.0, 0.0)],
		"fore": [Vector3(0.0, 0.123, 0.130), Vector3(0.0, 0.0, -1.0), Vector3(0.25, 0.97, 0.0)],
	},
	CrewHabit.Gun.SHOTGUN: {
		"grip": [Vector3(0.0, 0.014, -0.142), Vector3(0.0, -0.93, -0.37), Vector3(1.0, 0.0, 0.0)],
		"fore": [Vector3(0.0, 0.099, 0.215), Vector3(0.0, 0.0, -1.0), Vector3(0.25, 0.97, 0.0)],
	},
	CrewHabit.Gun.MARKSMAN_RIFLE: {
		"grip": [Vector3(0.0, 0.014, -0.090), Vector3(0.0, -0.93, -0.36), Vector3(1.0, 0.0, 0.0)],
		"fore": [Vector3(0.0, 0.126, 0.140), Vector3(0.0, 0.0, -1.0), Vector3(0.25, 0.97, 0.0)],
	},
}
## The hole a closed hand makes, from its wrist, metres: along the fingers,
## out of the palm, and across toward the little finger. Measured on the
## rig with CURL.
const FIST := Vector3(0.14, 0.03, 0.012)
## A closed hand: each finger's three joints (knuckle, middle, tip) turned
## toward the palm, degrees; the thumb's three.
const CURL := [52.0, 64.0, 40.0]
const THUMB_CURL := [18.0, 30.0, 30.0]
const FINGERS := ["Index", "Middle", "Ring", "Pinky"]
## How far a clavicle may swing to bring a hand within reach, degrees.
const CLAVICLE_REACH := 30.0

## The gun's scene, instanced from its Weapon Profile's `model`, under the
## body's Model node.
var gun: Node3D
## Its `Muzzle` marker.
var muzzle: Node3D
## 0 carrying, 1 aiming, between while it blends.
var aim := 0.0
## Which of the four guns it is.
var kind: CrewHabit.Gun = CrewHabit.Gun.PISTOL
## The world direction the aimed gun points (flat), set by a shot.
var aim_direction := Vector3.ZERO

var _weapon: WeaponProfile
var _muzzle_local := Transform3D.IDENTITY
## Per side: the rest hand's frame (fingers, palm, across) and the wrist's
## rest basis, both in the rig's space, without scale.
var _rest := {}
## Per side: each finger and thumb bone's index with its local rotation at
## rest and closed round a grip, worked out once from the rest pose.
var _curls := {}
## The reload's way: the left wrist's last place on it, and the shell being
## loaded's time and time left (Shotgun).
var _way_at := Transform3D.IDENTITY
var _shell_length := 0.0
var _shell_left := 0.0


## A gun for [param body] (a Guard with a weapon), put on its rig. Null for
## a Worker, or a rig with no skeleton.
static func arm(body: Crew3D) -> CrewGun:
	if body.weapon == null or body.weapon.model == null:
		return null
	var rig := body.model.get_node_or_null("Rig")
	if rig == null:
		return null
	var skeletons := rig.find_children("*", "Skeleton3D", true, false)
	if skeletons.is_empty():
		return null
	var made := CrewGun.new()
	made.name = "CrewGun"
	made.crew = body
	(skeletons[0] as Skeleton3D).add_child(made)
	made._mount()
	return made


## The gun model of its current weapon, placed in its hold at once.
func _mount() -> void:
	if gun != null:
		gun.free()
	_weapon = crew.weapon
	kind = CrewHabit.gun_of(_weapon)
	gun = _weapon.model.instantiate()
	gun.name = "Gun"
	crew.model.add_child(gun)
	muzzle = gun.find_child("Muzzle", true, false) as Node3D
	_muzzle_local = Transform3D.IDENTITY
	var at: Node = muzzle
	while at != null and at != gun:
		_muzzle_local = (at as Node3D).transform * _muzzle_local
		at = at.get_parent()
	gun.transform = _aim_hold(0.0)


func _hold(aiming: bool) -> Dictionary:
	if kind == CrewHabit.Gun.PISTOL:
		return AIM_PISTOL if aiming else CARRY_PISTOL
	return AIM_LONG if aiming else CARRY_LONG


## The gun aimed straight ahead of the body, turned [param turn] radians
## about its axis, in the rig's space.
func _aim_hold(turn: float) -> Transform3D:
	var hold := _hold(true)
	var place := Transform3D(_gun_basis(hold.dir), AIM_CHEST + _at(hold))
	return Transform3D(Basis(Vector3.UP, turn), Vector3.ZERO) * place


## Where [param hold] puts the gun's origin from the chest, for this gun.
func _at(hold: Dictionary) -> Vector3:
	if kind == CrewHabit.Gun.SHOTGUN:
		return hold.at - (hold.dir as Vector3).normalized() * SHOTGUN_BACK
	return hold.at


static func _gun_basis(direction: Vector3) -> Basis:
	var forward := direction.normalized()
	var up := Vector3.UP if absf(forward.y) < 0.95 else Vector3.BACK
	return Basis.looking_at(forward, up, true).scaled(Vector3.ONE * SCALE)


## Where its `Muzzle` stands when a Guard standing at [param at] aims at
## [param toward]: the aimed hold turned to face it.
func muzzle_from(at: Vector3, toward: Vector3) -> Vector3:
	var flat := Vector3(toward.x - at.x, 0.0, toward.z - at.z)
	var yaw := atan2(-flat.x, -flat.z) if flat.length_squared() > 0.000001 else crew.global_rotation.y
	# The Model node is the body turned round (its +Z is the body's -Z).
	var in_body := Transform3D(crew.model.basis, Vector3.ZERO) * (_aim_hold(0.0) * _muzzle_local).origin
	return at + Basis(Vector3.UP, yaw) * in_body


## Points the gun at [param point] in the aimed hold now, with no blend: a
## shot is leaving it.
func aim_at(point: Vector3) -> void:
	var flat := Vector3(point.x - crew.global_position.x, 0.0, point.z - crew.global_position.z)
	if flat.length_squared() > 0.000001:
		aim_direction = flat.normalized()
	aim = 1.0
	gun.transform = _aim_hold(_turn())


## Where the gun's `Muzzle` marker is now, in the world.
func muzzle_point() -> Vector3:
	return muzzle.global_position


## Radians from the way the body faces to where the gun aims.
func _turn() -> float:
	var look := aim_direction
	if look.length_squared() < 0.000001:
		return 0.0
	return wrapf(atan2(-look.x, -look.z) - crew.global_rotation.y, -PI, PI)


## Where each wrist belongs on the gun now, in the rig's space, so its
## hand closes round its hold (HOLDS): "grip" and "fore" as [Transform3D]s
## whose +Y runs along the fingers and +Z out of the palm.
func hand_place(which: String) -> Transform3D:
	return gun.transform * _place(HOLDS[kind][which], which == "grip")


## The same in the world.
func hand_place_global(which: String) -> Transform3D:
	return crew.model.global_transform * hand_place(which)


## The wrist's place for a hand closing on [param hold] ([point, across,
## palm], as HOLDS), in the hold's own space; [param right] for a right
## hand.
static func _place(hold: Array, right: bool) -> Transform3D:
	var across: Vector3 = (hold[1] as Vector3).normalized()
	var palm: Vector3 = (hold[2] as Vector3)
	palm = (palm - across * palm.dot(across)).normalized()
	# A right hand's palm faces fingers x across; a left hand's across x fingers.
	var fingers := across.cross(palm) if right else palm.cross(across)
	var wrist: Vector3 = hold[0] - fingers * FIST.x - palm * FIST.y - across * FIST.z
	return Transform3D(Basis(fingers.cross(palm), fingers, palm), wrist)


## Whether its left hand belongs on the gun in the hold it is in.
func left_on() -> bool:
	return lerpf(_carry().left, _hold(true).left, aim) > 0.5


## The carried hold as the body's pose has it now: down behind cover, and
## reloading, blended over the plain carry.
func _carry() -> Dictionary:
	var hold := _hold(false)
	var pose := crew.pose
	if pose == null:
		return hold
	var pistol := kind == CrewHabit.Gun.PISTOL
	hold = _mix_hold(hold, DOWN_PISTOL if pistol else DOWN_LONG, pose.down_weight())
	return _mix_hold(hold, RELOAD_PISTOL if pistol else RELOAD_LONG, pose.reload_weight())


static func _mix_hold(a: Dictionary, b: Dictionary, k: float) -> Dictionary:
	if k <= 0.0:
		return a
	if k >= 1.0:
		return b
	var t := smoothstep(0.0, 1.0, k)
	return {"at": (a.at as Vector3).lerp(b.at, t), "dir": (a.dir as Vector3).normalized().slerp((b.dir as Vector3).normalized(), t),
			"twist": lerpf(a.twist, b.twist, t), "elbow_r": (a.elbow_r as Vector3).lerp(b.elbow_r, t),
			"elbow_l": (a.elbow_l as Vector3).lerp(b.elbow_l, t), "left": lerpf(a.left, b.left, t)}


## Where the left wrist is in a reload now, in the rig's space: along
## RELOAD_WAY by the reload's progress, or SHELL_WAY by the shell's for
## a Shotgun, blended from the fore-end by the reload's weight.
func reload_place() -> Transform3D:
	var fore := hand_place("fore")
	var magazine := crew.magazine
	var pose := crew.pose
	if magazine == null or pose == null or pose.reload_weight() <= 0.0:
		return fore
	var way: Array = RELOAD_WAY
	var progress := 0.0
	if magazine.reloading:
		if magazine.shell_by_shell():
			way = SHELL_WAY
			if magazine.left > _shell_left + 0.0001 or _shell_length <= 0.0:
				_shell_length = magazine.left  # a new shell's time starts
			progress = 1.0 - magazine.left / maxf(_shell_length, 0.001)
		else:
			progress = 1.0 - magazine.left / maxf(magazine.duration, 0.001)
		_shell_left = magazine.left
		_way_at = _along(way, clampf(progress, 0.0, 1.0), fore)
	else:
		_shell_length = 0.0
	# Done or broken off: back to the fore-end as the weight falls.
	return _lerp_place(fore, _way_at, smoothstep(0.0, 1.0, pose.reload_weight()))


## The place [param progress] of the way along [param way].
func _along(way: Array, progress: float, fore: Transform3D) -> Transform3D:
	for i in range(1, way.size()):
		if progress <= way[i][0] or i == way.size() - 1:
			var a: Array = way[i - 1]
			var b: Array = way[i]
			var k := clampf((progress - a[0]) / maxf(b[0] - a[0], 0.0001), 0.0, 1.0)
			return _lerp_place(_way_place(a[1], fore), _way_place(b[1], fore), smoothstep(0.0, 1.0, k))
	return fore


func _way_place(which: String, fore: Transform3D) -> Transform3D:
	match which:
		"well":
			return gun.transform * _place(WELLS[kind], false)
		"clear":
			var well := gun.transform * _place(WELLS[kind], false)
			well.origin += WELL_CLEAR
			return well
		"belt":
			var belt := _place(BELT, false)
			belt.origin += _bone("Hips").origin
			return belt
	return fore


static func _lerp_place(a: Transform3D, b: Transform3D, k: float) -> Transform3D:
	var qa := a.basis.orthonormalized().get_rotation_quaternion()
	var qb := b.basis.orthonormalized().get_rotation_quaternion()
	return Transform3D(Basis(qa.slerp(qb, k)), a.origin.lerp(b.origin, k))


## Hidden with its owner dead: nothing is left to pick up.
func drop() -> void:
	if gun != null:
		gun.visible = false
	active = false


func _process_modification_with_delta(delta: float) -> void:
	if not _begin_frame() or gun == null:
		return
	if crew.weapon != _weapon and crew.weapon != null and crew.weapon.model != null:
		_mount()
	var want := 1.0 if crew.aiming() and not crew.is_reloading() else 0.0
	aim = move_toward(aim, want, delta / BLEND)
	if crew.shot_age() >= Crew3D.AIM_HOLD or aim_direction.length_squared() < 0.000001:
		# No shot just now: the gun points where the body looks.
		aim_direction = crew._aim
	if _rest.is_empty():
		_learn_rest()

	var carry := _carry()
	var aimed := _hold(true)
	var chest := _bone("Chest").origin
	var carried := Transform3D(_gun_basis(carry.dir), chest + _at(carry))
	var held := _aim_hold(_turn())
	var k := smoothstep(0.0, 1.0, aim)
	gun.transform = Transform3D(_blend_basis(carried.basis, held.basis, k), carried.origin.lerp(held.origin, k))
	if not crew.is_visible_in_tree():
		return  # out of the Pirate's sight (the ship's reveal): no arms to solve

	# Side-on to aim a long gun: the spine turned right, the head kept ahead.
	var twist := deg_to_rad(lerpf(carry.twist, aimed.twist, k))
	if not is_zero_approx(twist):
		for bone in ["Abdomen", "Torso", "Chest"]:
			_turn_bone(bone, Vector3.UP, -twist / 3.0)
		_turn_bone("Head", Vector3.UP, twist)

	var elbow_r: Vector3 = (carry.elbow_r as Vector3).lerp(aimed.elbow_r, k)
	var elbow_l: Vector3 = (carry.elbow_l as Vector3).lerp(aimed.elbow_l, k)
	_hand("R", hand_place("grip"), 1.0, elbow_r)
	var reload := crew.pose.reload_weight() if crew.pose != null else 0.0
	var left := maxf(lerpf(carry.left, aimed.left, k), reload)
	_hand("L", reload_place() if reload > 0.0 else hand_place("fore"), left, elbow_l)


## A basis blend that keeps the gun's scale.
static func _blend_basis(a: Basis, b: Basis, k: float) -> Basis:
	var qa := a.orthonormalized().get_rotation_quaternion()
	var qb := b.orthonormalized().get_rotation_quaternion()
	return Basis(qa.slerp(qb, k)).scaled(Vector3.ONE * a.get_scale().x)


## The rest hand of each side: fingers from the wrist to the middle
## knuckle, across from the index knuckle to the little one, and the palm's
## facing from those (a right hand's palm is fingers x across).
func _learn_rest() -> void:
	for side: String in ["L", "R"]:
		var wrist := _rest_pose("Wrist." + side)
		var fingers := (_rest_pose("Middle2." + side).origin - wrist.origin).normalized()
		var across := _rest_pose("Pinky2." + side).origin - _rest_pose("Index2." + side).origin
		var palm := fingers.cross(across) if side == "R" else across.cross(fingers)
		palm = (palm - fingers * palm.dot(fingers)).normalized()
		_rest[side] = [Basis(fingers.cross(palm), fingers, palm), wrist.basis.orthonormalized()]
		_learn_curls(side, _rest[side][0])


## The closed hand, as local rotations: each finger's three joints turned
## toward the palm about the hand's crosswise axis (each joint adding to
## the one before), and each thumb joint turned toward the palm about its
## own crosswise axis. Worked on the rest pose, in the skeleton's space;
## the wrist only turns the whole hand, so the locals hold for any wrist.
func _learn_curls(side: String, frame: Basis) -> void:
	var to_skeleton := _to_bones.basis.orthonormalized()
	var across := (to_skeleton * frame.x).normalized()
	var palm := (to_skeleton * frame.z).normalized()
	var out: Array = []
	for finger: String in FINGERS:
		var parent := _rest_basis("%s1.%s" % [finger, side])
		var turned := 0.0
		for j in 3:
			var bone := "%s%d.%s" % [finger, j + 2, side]
			turned += deg_to_rad(CURL[j])
			var closed := Basis(across, turned) * _rest_basis(bone)
			out.append(_curl_entry(bone, parent, closed))
			parent = closed
	var parent := _rest_basis("Wrist." + side)
	var carried := Basis.IDENTITY
	for j in 3:
		var bone := "Thumb%d.%s" % [j + 1, side]
		var now := carried * _rest_basis(bone)
		var axis := now.y.normalized().cross(palm)
		var turn := Basis(axis.normalized(), deg_to_rad(THUMB_CURL[j])) if axis.length_squared() > 0.0001 else Basis.IDENTITY
		var closed := turn * now
		out.append(_curl_entry(bone, parent, closed))
		carried = turn * carried
		parent = closed
	_curls[side] = out


func _rest_basis(bone: String) -> Basis:
	return _sk.get_bone_global_rest(_i(bone)).basis.orthonormalized()


func _curl_entry(bone: String, parent: Basis, closed: Basis) -> Array:
	var i := _i(bone)
	var rest := _sk.get_bone_rest(i).basis.get_rotation_quaternion()
	return [i, rest, (parent.inverse() * closed).get_rotation_quaternion()]


## One arm solved onto [param place] (weight [param on]): the clavicle
## swung forward if the hand is out of reach, the arm's two bones put so
## the wrist lands on it with the elbow toward [param pole], the wrist
## turned square to the gun and the fingers closed round it.
func _hand(side: String, place: Transform3D, on: float, pole: Vector3) -> void:
	if on <= 0.01:
		return
	var wrist_bone := "Wrist." + side
	var goal := _bone(wrist_bone).origin.lerp(place.origin, on)
	_reach(side, goal)
	var fore_arm := (_bone(wrist_bone).origin - _bone("LowerArm." + side).origin).length()
	_two_bone("UpperArm." + side, "LowerArm." + side, fore_arm, goal, pole)

	var rest: Array = _rest[side]
	var frame := Basis(place.basis.x.normalized(), place.basis.y.normalized(), place.basis.z.normalized())
	var turn: Basis = frame * (rest[0] as Basis).transposed()
	var want: Basis = turn * (rest[1] as Basis)
	var wrist := _bone(wrist_bone)
	var scale := wrist.basis.get_scale().x
	var now := wrist.basis.orthonormalized().get_rotation_quaternion()
	wrist.basis = Basis(now.slerp(want.get_rotation_quaternion(), on)).scaled(Vector3.ONE * scale)
	_put(wrist_bone, wrist)

	# Fingers from their rest shape, closed toward the palm.
	for finger in FINGERS:
		_rest_local("%s1.%s" % [finger, side])
	for entry: Array in _curls[side]:
		_sk.set_bone_pose_rotation(entry[0], (entry[1] as Quaternion).slerp(entry[2], on))


## Swings the clavicle toward [param goal] a few degrees at a time while the
## arm cannot reach it.
func _reach(side: String, goal: Vector3) -> void:
	var upper := "UpperArm." + side
	var lower := "LowerArm." + side
	var wrist := "Wrist." + side
	var length := (_bone(lower).origin - _bone(upper).origin).length() + (_bone(wrist).origin - _bone(lower).origin).length()
	var swung := 0.0
	while swung < CLAVICLE_REACH and _bone(upper).origin.distance_to(goal) > length * 0.995:
		var clavicle := _bone("Shoulder." + side)
		var out := _bone(upper).origin - clavicle.origin
		var axis := out.cross(goal - clavicle.origin)
		if axis.length_squared() < 0.000001:
			return
		clavicle.basis = Basis(axis.normalized(), deg_to_rad(3.0)) * clavicle.basis
		_put("Shoulder." + side, clavicle)
		swung += 3.0
