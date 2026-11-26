class_name CrewPose
extends CrewRigModifier
## A Guard's body in a fight (crew-combat ticket 22): down behind cover in a
## squat or on one knee, ducking lower at a near miss, running low to low
## cover, and stepping out from full cover and back on feet that step. A
## skeleton modifier over whatever clip the body plays, as the look
## prototype (`prototype/crew-look`) posed it: the hips lowered and moved,
## the spine leaned, the head turned, and the legs solved onto the feet. It
## runs before [CrewGun], which places the gun from the posed chest and puts
## the arms on it.
##
## What it shows is decided by the fight ([CrewCover]): which stance a Guard
## is down in ([member CrewCover.stance], picked again at every drop), the
## near miss ([method flinch]), the run to a spot ([member CrewCover.low]),
## and the step out ([method CrewCover.stepping]). The body's capsule
## follows the stance there too ([constant BODY_TOP]); the head zone rides
## the head bone this poses.
##
## The hips, spine and head are posed even on a body the ship's reveal
## hides, so its head zone stands where its pose puts it; the legs and the
## stepping feet only on a body that can be seen.
##
## Space: the rig's own (the Model node's), metres, +Z ahead of the body, +X
## to its left, on a rig fitted to 2 m.

enum Stance { STAND, SQUAT, KNEE }

## A pose, every field with its neutral value: the hips lowered ("drop")
## and moved ("shift"), the spine pitched forward ("lean", degrees, shared
## over its three bones), the head pitched down and turned left ("head",
## degrees), each foot moved and pitched toes-down, and each knee's pull.
const NEUTRAL := {
	"drop": 0.0, "shift": Vector3.ZERO, "lean": 0.0, "head": Vector2.ZERO,
	"foot_l": Vector3.ZERO, "foot_r": Vector3.ZERO, "toes_l": 0.0, "toes_r": 0.0,
	"knee_l": Vector3(0.15, 0.0, 1.0), "knee_r": Vector3(-0.15, 0.0, 1.0),
}
## Down behind cover, squatting: the top of its head under 1.05 m.
const SQUAT := {"drop": 0.76, "shift": Vector3(0, 0, -0.17), "lean": 56.0, "head": Vector2(-26, 0)}
## Down on one knee, the right one: the top of its head over 1.15 m, so it
## shows over a 1.1 m crate and a Headshot is there to take.
const KNEE := {"drop": 0.54, "shift": Vector3(0, 0, -0.05), "lean": 32.0, "head": Vector2(-20, 0),
		"foot_r": Vector3(0.0, 0.06, -0.50), "toes_r": 75.0, "foot_l": Vector3(0.0, 0.0, 0.12)}
## Each ducked lower at a near miss, for FLINCH seconds.
const SQUAT_DEEP := {"drop": 0.80, "shift": Vector3(0, 0, -0.19), "lean": 66.0, "head": Vector2(4, 0)}
const KNEE_DEEP := {"drop": 0.58, "shift": Vector3(0, 0, -0.07), "lean": 50.0, "head": Vector2(14, 0),
		"foot_r": Vector3(0.0, 0.06, -0.50), "toes_r": 75.0, "foot_l": Vector3(0.0, 0.0, 0.12)}
## Running to low cover: hips down, leaning into it.
const RUN_LOW := {"drop": 0.30, "lean": 24.0, "head": Vector2(-14, 0)}
## Stepping out from full cover and back: knees a little bent, for reach.
const STEP := {"drop": 0.06}

## The top of the body's capsule in each stance, metres: the top of its
## back and shoulders in that pose (the head is its own zone). Standing it
## is the scene's 1.7 m.
const BODY_TOP := {Stance.SQUAT: 0.82, Stance.KNEE: 1.0}

## Seconds to go down, to come up (the gun's own blend to the aimed hold,
## [constant CrewGun.BLEND], so it is up when the gun is), and to duck a
## near miss and come back from it.
const DROP_TIME := 0.15
const RISE_TIME := 0.2
const FLINCH_IN := 0.12
const FLINCH := 0.5
## Reloading, the head turns to the gun this far (down, left), degrees.
const RELOAD_LOOK := Vector2(22, 10)

## Stepping: a foot steps when the place it would stand (where the clip
## puts it, led by the body's speed) is this far from where it is planted,
## metres, or turned this far, degrees; a step takes STEP_TIME seconds and
## lifts the foot STEP_LIFT. One foot steps at a time; the other stays put.
const STEP_TRIGGER := 0.08
const STEP_TURN := 25.0
const STEP_TIME := 0.14
const STEP_LIFT := 0.07
## A Guard stepping out or back moves at this fraction of its speed, so its
## feet keep up ([CrewCover] sets it).
const STEP_SPEED := 0.45

## The pose shown and the one it blends to, as a name (a key of POSES).
var shown := "neutral"
var _from := NEUTRAL
var _to := NEUTRAL
var _k := 1.0
var _blend := RISE_TIME
## Seconds left ducked from a near miss.
var _flinch := 0.0
## 0 to 1: reloading, blended.
var _reload := 0.0

## Stepping, each foot in the world: where it stands (or last stood), the
## foot stepping ("" for none) and its step's start and progress.
var _planted := {}
var _swing := ""
var _swing_from := Transform3D.IDENTITY
var _swing_t := 0.0
var _stepping := false
## Each foot as last drawn, in the world, and whether that is this frame's
## neighbour (drawn last frame): stepping starts from there, and leaving it
## blends from there over DROP_TIME.
var _drawn := {}
var _drawn_ok := false
var _release := 0.0
## The pose as blended now, worked out again only while it blends.
var _pose := {}
## Each shin's length (knee to foot bone), measured once.
var _shins := {}

const POSES := {
	"neutral": NEUTRAL, "squat": SQUAT, "knee": KNEE, "squat_deep": SQUAT_DEEP,
	"knee_deep": KNEE_DEEP, "run_low": RUN_LOW, "step": STEP,
}


## A pose for [param body] (a Guard), put on its rig's skeleton ahead of its
## gun. Null with no rig or no cover fight.
static func fit(body: Crew3D) -> CrewPose:
	if body.cover == null:
		return null
	var rig := body.model.get_node_or_null("Rig")
	if rig == null:
		return null
	var skeletons := rig.find_children("*", "Skeleton3D", true, false)
	if skeletons.is_empty():
		return null
	var made := CrewPose.new()
	made.name = "CrewPose"
	made.crew = body
	(skeletons[0] as Skeleton3D).add_child(made)
	return made


## A near miss: ducked lower for FLINCH seconds, if down.
func flinch() -> void:
	_flinch = FLINCH


## 0 standing, 1 fully down behind cover (squat or knee), between while it
## goes down or comes up.
func down_weight() -> float:
	var a := 1.0 if _down_pose(_from) else 0.0
	var b := 1.0 if _down_pose(_to) else 0.0
	return lerpf(a, b, smoothstep(0.0, 1.0, _k))


## 0 to 1: the reload's look and hold, blended in over the gun's BLEND.
func reload_weight() -> float:
	return _reload


## Its feet stepping now (out from full cover and back).
func stepping() -> bool:
	return _stepping


static func _down_pose(p: Dictionary) -> bool:
	return p.get("drop", 0.0) >= 0.5


## The pose the fight calls for now.
func _target() -> String:
	var cover := crew.cover
	if cover == null or not crew.is_alive():
		return "neutral"
	if cover.crouched:
		var deep := _flinch > 0.0
		if cover.stance == Stance.KNEE:
			return "knee_deep" if deep else "knee"
		return "squat_deep" if deep else "squat"
	if cover.mode == CrewCover.Mode.MOVE and cover.low and not cover.ambushing:
		return "run_low"
	if cover.stepping():
		return "step"
	return "neutral"


func _process_modification_with_delta(delta: float) -> void:
	if crew == null or not is_instance_valid(crew):
		return
	_flinch = maxf(_flinch - delta, 0.0)
	_reload = move_toward(_reload, 1.0 if crew.is_reloading() else 0.0, delta / CrewGun.BLEND)
	var want := _target()
	if want != shown:
		var now := _mix(_from, _to, smoothstep(0.0, 1.0, _k))
		_from = now
		_to = POSES[want]
		_k = 0.0
		if want.ends_with("_deep"):
			_blend = FLINCH_IN
		elif _to.drop > now.drop:
			_blend = DROP_TIME
		else:
			_blend = RISE_TIME
		shown = want
	var was_stepping := _stepping
	_stepping = crew.cover != null and crew.cover.stepping() and crew.is_alive()
	if _stepping and not was_stepping:
		_planted.clear()
		_swing = ""
	if was_stepping and not _stepping:
		_release = 1.0 if _drawn_ok else 0.0
	_release = move_toward(_release, 0.0, delta / DROP_TIME)
	if shown == "neutral" and _k >= 1.0 and not _stepping and _release <= 0.0 and _reload <= 0.0:
		# Standing as the clip has it: nothing to pose (most of the time).
		_drawn_ok = false
		return
	if not _begin_frame():
		return
	if _k < 1.0 or _pose.is_empty():
		_k = move_toward(_k, 1.0, delta / _blend)
		_pose = _mix(_from, _to, smoothstep(0.0, 1.0, _k))
	var p := _pose
	var look: Vector2 = p.head + RELOAD_LOOK * _reload

	# Hips down and across; the spine leaned; the head turned.
	var body := _bone("Body")
	body.origin += Vector3(p.shift.x, -p.drop, p.shift.z)
	_put("Body", body)
	for bone in ["Abdomen", "Torso", "Chest"]:
		_turn_bone(bone, Vector3.RIGHT, deg_to_rad(p.lean / 3.0))
	_turn_bone("Head", Vector3.RIGHT, deg_to_rad(look.x))
	_turn_bone("Head", Vector3.UP, deg_to_rad(look.y))
	if not crew.is_visible_in_tree():
		_drawn_ok = false
		_swing = ""
		return  # out of the Pirate's sight (the ship's reveal): no legs to solve

	# Feet: stepping, or where the pose puts them; legs solved onto them.
	var to_world := crew.model.global_transform
	var feet := _step_feet(delta, to_world) if _stepping else {}
	for side: String in ["L", "R"]:
		var low := side.to_lower()
		var foot: Transform3D
		if _stepping:
			foot = feet[side]
		else:
			foot = _bone("Foot." + side)
			foot.origin += p["foot_" + low]
			foot.basis = Basis(Vector3.RIGHT, deg_to_rad(p["toes_" + low])) * foot.basis
			if _release > 0.0 and _drawn.has(side):
				var from: Transform3D = to_world.affine_inverse() * (_drawn[side] as Transform3D)
				var k := smoothstep(0.0, 1.0, _release)
				foot = Transform3D(Basis(foot.basis.get_rotation_quaternion().slerp(from.basis.get_rotation_quaternion(), k)).scaled(foot.basis.get_scale()),
						foot.origin.lerp(from.origin, k))
		_put("Foot." + side, foot)
		if not _shins.has(side):
			_shins[side] = _rest_length("LowerLeg." + side, "Foot." + side)
		_two_bone("UpperLeg." + side, "LowerLeg." + side, _shins[side], foot.origin, p["knee_" + low])
		if not _stepping:
			_drawn[side] = to_world * foot
	_drawn_ok = true


## Each foot, in the rig's space, while stepping: the planted one where it
## stands in the world, the other stepping toward where the clip would put
## it, led by the body's speed, lifted on the way.
func _step_feet(delta: float, to_world: Transform3D) -> Dictionary:
	var from_world := to_world.affine_inverse()
	var lead := Vector3(crew.velocity.x, 0.0, crew.velocity.z) * STEP_TIME * 0.6
	var home := {}
	for side: String in ["L", "R"]:
		var at := to_world * _bone("Foot." + side)
		at.origin += lead
		home[side] = at
		if not _planted.has(side) or not _drawn_ok:
			_planted[side] = _drawn[side] if _drawn_ok and _drawn.has(side) else at
	if not _drawn_ok:
		_swing = ""
	if _swing == "":
		var worst := ""
		var worst_off := 0.0
		for side: String in ["L", "R"]:
			var off := _foot_off(_planted[side], home[side])
			if off > worst_off:
				worst_off = off
				worst = side
		if worst != "" and worst_off > 1.0:
			_swing = worst
			_swing_from = _planted[worst]
			_swing_t = 0.0
	var out := {}
	for side: String in ["L", "R"]:
		var at: Transform3D = _planted[side]
		if side == _swing:
			_swing_t = minf(_swing_t + delta / STEP_TIME, 1.0)
			var goal: Transform3D = home[side]
			var k := smoothstep(0.0, 1.0, _swing_t)
			var scale := goal.basis.get_scale()
			at = Transform3D(Basis(_swing_from.basis.get_rotation_quaternion().slerp(goal.basis.get_rotation_quaternion(), k)).scaled(scale),
					_swing_from.origin.lerp(goal.origin, k) + Vector3.UP * STEP_LIFT * sin(PI * _swing_t))
			if _swing_t >= 1.0:
				_planted[side] = goal
				at = goal
				_swing = ""
		_drawn[side] = at
		out[side] = from_world * at
	return out


## How far a planted foot is from where it would stand: 1 at the step's
## trigger (STEP_TRIGGER metres, or STEP_TURN degrees, whichever is more).
static func _foot_off(planted: Transform3D, home: Transform3D) -> float:
	var flat := Vector2(planted.origin.x - home.origin.x, planted.origin.z - home.origin.z).length()
	var qa := planted.basis.get_rotation_quaternion()
	var qb := home.basis.get_rotation_quaternion()
	var turn := rad_to_deg(qa.angle_to(qb))
	return maxf(flat / STEP_TRIGGER, turn / STEP_TURN)


## Pose [param a] blended toward [param b] by [param k], every field filled
## from NEUTRAL.
static func _mix(a: Dictionary, b: Dictionary, k: float) -> Dictionary:
	var out := {}
	for key: String in NEUTRAL:
		var x: Variant = a.get(key, NEUTRAL[key])
		var y: Variant = b.get(key, NEUTRAL[key])
		if x is float or x is int:
			out[key] = lerpf(float(x), float(y), k)
		else:
			out[key] = x.lerp(y, k)
	return out
