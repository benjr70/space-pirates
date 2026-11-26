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
## A Worker's body (crew-combat ticket 25): hiding (crouched with its arms
## over its head, ducking lower at a gunshot, or sat down), surrendering
## (hands by its head or arms straight up, then kneeling upright or on its
## heels) and Bound (sat against a wall or kneeling, hands behind its back),
## each from the set the Worker rolled once at ship build ([method roll_set],
## [member Crew3D.pose_set]). What it shows is decided by the Worker's state
## ([method worker_pose]); its arms are solved here onto its head, chest or
## hips, since a Worker carries no [CrewGun]. Its capsule follows the pose
## ([constant WORKER_TOP], set by [Crew3D]).
##
## Space: the rig's own (the Model node's), metres, +Z ahead of the body, +X
## to its left, on a rig fitted to 2 m.

enum Stance { STAND, SQUAT, KNEE }

## A pose, every field with its neutral value: the hips lowered ("drop")
## and moved ("shift"), the spine pitched forward ("lean", degrees, shared
## over its three bones), the head pitched down and turned left ("head",
## degrees), each foot moved and pitched toes-down, and each knee's pull.
## A Worker's poses add its arms: "arms" 1 solves both onto their targets,
## each hand placed off the chest, or off the head ("at_head" 1) or the
## hips ("at_hips" 1), each elbow pulled toward its pole and each wrist
## pointed along its palm (zero leaves the wrist); and "back" 1 moves the
## whole body back toward the wall behind it by [member Crew3D.seat_back].
const NEUTRAL := {
	"drop": 0.0, "shift": Vector3.ZERO, "lean": 0.0, "head": Vector2.ZERO,
	"foot_l": Vector3.ZERO, "foot_r": Vector3.ZERO, "toes_l": 0.0, "toes_r": 0.0,
	"knee_l": Vector3(0.15, 0.0, 1.0), "knee_r": Vector3(-0.15, 0.0, 1.0),
	"arms": 0.0, "at_head": 0.0, "at_hips": 0.0, "hand_l": Vector3.ZERO, "hand_r": Vector3.ZERO,
	"elbow_l": Vector3(0.7, -1.0, -0.3), "elbow_r": Vector3(-0.7, -1.0, -0.3),
	"palm_l": Vector3.ZERO, "palm_r": Vector3.ZERO, "back": 0.0,
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

## A Worker's poses (crew-combat ticket 25), from the look prototype
## (`prototype/crew-look`: HIDE, HIDE_FLINCH, HIDE_SAT, HANDS_UP, HANDS_HIGH,
## KNEEL, KNEEL_LOW, BOUND_SAT, BOUND_KNEEL), fitted to the real rig.
## Hiding crouched, back to the wall, arms over its head.
const HIDE := {"drop": 0.56, "lean": 34.0, "head": Vector2(26, 0), "back": 1.0,
		"arms": 1.0, "at_head": 1.0, "hand_l": Vector3(0.09, 0.17, 0.05), "hand_r": Vector3(-0.09, 0.17, 0.05),
		"elbow_l": Vector3(0.8, -0.2, 0.7), "elbow_r": Vector3(-0.8, -0.2, 0.7),
		"palm_l": Vector3(-0.8, 0.3, -0.3), "palm_r": Vector3(0.8, 0.3, -0.3)}
## The same, ducked lower at a gunshot, for FLINCH seconds.
const HIDE_FLINCH := {"drop": 0.68, "lean": 48.0, "head": Vector2(36, 0), "back": 1.0,
		"arms": 1.0, "at_head": 1.0, "hand_l": Vector3(0.08, 0.16, 0.03), "hand_r": Vector3(-0.08, 0.16, 0.03),
		"elbow_l": Vector3(0.6, -0.3, 0.8), "elbow_r": Vector3(-0.6, -0.3, 0.8),
		"palm_l": Vector3(-0.8, 0.3, -0.3), "palm_r": Vector3(0.8, 0.3, -0.3)}
## Hiding sat down against the wall, hugging its knees, arms over its head.
const HIDE_SAT := {"drop": 0.90, "lean": 26.0, "head": Vector2(30, 0), "back": 1.0,
		"foot_l": Vector3(0.0, 0.0, 0.36), "foot_r": Vector3(0.0, 0.0, 0.36),
		"knee_l": Vector3(0.1, 1.0, 0.4), "knee_r": Vector3(-0.1, 1.0, 0.4),
		"arms": 1.0, "at_head": 1.0, "hand_l": Vector3(0.09, 0.17, 0.05), "hand_r": Vector3(-0.09, 0.17, 0.05),
		"elbow_l": Vector3(0.8, -0.2, 0.7), "elbow_r": Vector3(-0.8, -0.2, 0.7),
		"palm_l": Vector3(-0.8, 0.3, -0.3), "palm_r": Vector3(0.8, 0.3, -0.3)}
## Surrendered, standing: hands up by its head.
const HANDS_UP := {"head": Vector2(6, 0),
		"arms": 1.0, "hand_l": Vector3(0.36, 0.22, 0.06), "hand_r": Vector3(-0.36, 0.22, 0.06),
		"elbow_l": Vector3(1.0, -0.5, 0.0), "elbow_r": Vector3(-1.0, -0.5, 0.0),
		"palm_l": Vector3(0, 1, 0), "palm_r": Vector3(0, 1, 0)}
## Surrendered, standing: arms straight up.
const HANDS_HIGH := {
		"arms": 1.0, "hand_l": Vector3(0.22, 0.62, 0.02), "hand_r": Vector3(-0.22, 0.62, 0.02),
		"elbow_l": Vector3(1.0, 0.2, 0.0), "elbow_r": Vector3(-1.0, 0.2, 0.0),
		"palm_l": Vector3(0, 1, 0), "palm_r": Vector3(0, 1, 0)}
## Kneeling upright, hands on its head.
const KNEEL := {"drop": 0.52, "lean": 4.0, "head": Vector2(14, 0), "toes_l": 80.0, "toes_r": 80.0,
		"foot_l": Vector3(0.0, 0.06, -0.52), "foot_r": Vector3(0.0, 0.06, -0.52),
		"arms": 1.0, "at_head": 1.0, "hand_l": Vector3(0.10, 0.13, -0.03), "hand_r": Vector3(-0.10, 0.13, -0.03),
		"elbow_l": Vector3(1.0, 0.0, 0.1), "elbow_r": Vector3(-1.0, 0.0, 0.1),
		"palm_l": Vector3(-1, 0.2, 0), "palm_r": Vector3(1, 0.2, 0)}
## Kneeling sat back on its heels, hands on its head.
const KNEEL_LOW := {"drop": 0.78, "shift": Vector3(0, 0, -0.30), "lean": 10.0, "head": Vector2(18, 0), "toes_l": 80.0, "toes_r": 80.0,
		"foot_l": Vector3(0.0, 0.06, -0.52), "foot_r": Vector3(0.0, 0.06, -0.52),
		"arms": 1.0, "at_head": 1.0, "hand_l": Vector3(0.10, 0.13, -0.03), "hand_r": Vector3(-0.10, 0.13, -0.03),
		"elbow_l": Vector3(1.0, 0.0, 0.1), "elbow_r": Vector3(-1.0, 0.0, 0.1),
		"palm_l": Vector3(-1, 0.2, 0), "palm_r": Vector3(1, 0.2, 0)}
## Bound, sat against the wall, hands behind its back.
const BOUND_SAT := {"drop": 0.92, "lean": -6.0, "head": Vector2(22, 0), "back": 1.0,
		"foot_l": Vector3(0.02, 0.0, 0.62), "foot_r": Vector3(-0.02, 0.0, 0.62),
		"knee_l": Vector3(0.1, 1.0, 0.5), "knee_r": Vector3(-0.1, 1.0, 0.5),
		"arms": 1.0, "at_hips": 1.0, "hand_l": Vector3(0.05, 0.06, -0.17), "hand_r": Vector3(-0.05, 0.06, -0.17),
		"elbow_l": Vector3(1.0, 0.2, -0.6), "elbow_r": Vector3(-1.0, 0.2, -0.6),
		"palm_l": Vector3(-1, -0.3, 0), "palm_r": Vector3(1, -0.3, 0)}
## Bound, kneeling on its heels, hands behind its back.
const BOUND_KNEEL := {"drop": 0.78, "shift": Vector3(0, 0, -0.30), "lean": 14.0, "head": Vector2(26, 0), "toes_l": 80.0, "toes_r": 80.0,
		"foot_l": Vector3(0.0, 0.06, -0.52), "foot_r": Vector3(0.0, 0.06, -0.52),
		"arms": 1.0, "at_hips": 1.0, "hand_l": Vector3(0.05, 0.10, -0.17), "hand_r": Vector3(-0.05, 0.10, -0.17),
		"elbow_l": Vector3(1.0, 0.2, -0.6), "elbow_r": Vector3(-1.0, 0.2, -0.6),
		"palm_l": Vector3(-1, -0.3, 0), "palm_r": Vector3(1, -0.3, 0)}

## The pairs a Worker rolls between, even odds each, once at ship build:
## {pair: [first, second]}, each a key of POSES.
const PAIRS := {
	"hide": ["hide", "hide_sat"],
	"hands": ["hands_up", "hands_high"],
	"kneel": ["kneel", "kneel_low"],
	"bound": ["bound_sat", "bound_kneel"],
}
## The top of a Worker's capsule in each pose, metres: under the head as
## drawn there (the head is its own zone). A pose not listed stands, the
## scene's 1.7 m. The ducked hide keeps the hide's top, which is under its
## head too.
const WORKER_TOP := {"hide": 1.0, "hide_flinch": 0.8, "hide_sat": 0.75, "kneel": 1.2,
		"kneel_low": 0.93, "bound_sat": 0.8, "bound_kneel": 0.9}
## Seconds a Worker takes into a pose, and to duck at a gunshot.
const WORKER_BLEND := 0.45
## A hiding Worker turns its head to watch him, at most this far, degrees,
## at this rate, degrees a second.
const WATCH_MOST := 60.0
const WATCH_RATE := 240.0

## The top of the body's capsule in each stance, metres: the top of its
## back and shoulders in that pose (the head is its own zone). Standing it
## is the scene's 1.7 m.
const BODY_TOP := {Stance.SQUAT: 0.82, Stance.KNEE: 1.0}

## Seconds to go down, to come up (the gun's own blend to the aimed hold,
## [constant CrewGun.BLEND], so it is up when the gun is), and to duck a
## near miss and come back from it.
## (Slowed in the first balance pass: at 0.15 s a Guard was down before a
## bolt fired at it arrived.)
const DROP_TIME := 0.4
const RISE_TIME := 0.3
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

## A Worker's head turned to watch him now, degrees left.
var _watch := 0.0
## Each forearm's length (elbow to wrist), measured once.
var _forearms := {}
## A test's or a screenshot's pose for a Worker, a key of POSES; "" leaves
## it to the Worker's state.
var forced := ""

const POSES := {
	"neutral": NEUTRAL, "squat": SQUAT, "knee": KNEE, "squat_deep": SQUAT_DEEP,
	"knee_deep": KNEE_DEEP, "run_low": RUN_LOW, "step": STEP,
	"hide": HIDE, "hide_flinch": HIDE_FLINCH, "hide_sat": HIDE_SAT, "hands_up": HANDS_UP,
	"hands_high": HANDS_HIGH, "kneel": KNEEL, "kneel_low": KNEEL_LOW, "bound_sat": BOUND_SAT,
	"bound_kneel": BOUND_KNEEL,
}


## A Worker's pose set, rolled once at ship build: {pair: pose} for each of
## PAIRS, even odds on each. From its own generator seeded off the ship's
## seed and the Worker's spawn tile, so a Retry of the same ship rolls the
## same and nothing else's draws move; [param fallback] seeds it on a
## layout with no ship seed (a test rig).
static func roll_set(gen_seed: int, tile: Vector2i, fallback := 0) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([gen_seed, "worker poses", tile]) if gen_seed > 0 else hash([fallback, "worker poses"])
	var out := {}
	for pair: String in ["hide", "hands", "kneel", "bound"]:
		out[pair] = PAIRS[pair][0] if rng.randf() < 0.5 else PAIRS[pair][1]
	return out


## The pose a Worker's state calls for now, from its set (the gunshot duck
## aside): hidden, its hiding pose; surrendered, hands up then kneeling;
## Bound, sat against the wall behind it, or kneeling with none found
## ([member Crew3D.bound_against]); else standing as its clip has it.
static func worker_pose(body: Crew3D) -> String:
	if body.pose != null and body.pose.forced != "":
		return body.pose.forced
	if not body.is_alive():
		return "neutral"
	var set := body.pose_set
	if set.is_empty():
		return "neutral"
	match body.state:
		Crew3D.State.BOUND:
			if set.bound == "bound_sat" and body.bound_against != Vector3.ZERO:
				return "bound_sat"
			return "bound_kneel"
		Crew3D.State.SURRENDER:
			return set.kneel if body.surrender == Crew3D.Surrender.KNEELING else set.hands
		Crew3D.State.COWER:
			if body.hiding != null and body.hiding.is_hidden():
				return set.hide
	return "neutral"


## The top of [param body]'s capsule for the pose it is in (ducked at a
## gunshot included), metres; INF standing.
static func worker_top(body: Crew3D) -> float:
	var shown := body.pose._target() if body.pose != null else worker_pose(body)
	return WORKER_TOP.get(shown, INF)


## A pose for [param body], put on its rig's skeleton (a Guard's ahead of
## its gun). Null with no rig, or for a Guard with no cover fight.
static func fit(body: Crew3D) -> CrewPose:
	if body.cover == null and not body.is_worker():
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
	if crew.is_worker():
		var want := worker_pose(crew)
		if want == "hide" and _flinch > 0.0 and forced == "":
			return "hide_flinch"
		return want
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
		if want.ends_with("_deep") or want == "hide_flinch":
			_blend = FLINCH_IN
		elif crew.is_worker():
			_blend = WORKER_BLEND
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
	if crew.is_worker():
		_watch = move_toward(_watch, _watch_angle(), WATCH_RATE * delta)
		look.y += _watch
	# Back toward the wall behind it (a Worker hiding or Bound).
	var back := Vector3(0.0, 0.0, -crew.seat_back * p.back)

	# Hips down and across; the spine leaned; the head turned.
	var body := _bone("Body")
	body.origin += Vector3(p.shift.x, -p.drop, p.shift.z) + back
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
			foot.origin += p["foot_" + low] + back
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
	if p.arms > 0.01:
		_arms(p)


## A Worker's arms solved onto where its pose puts its hands: off its head,
## chest or hips as posed this frame, blended in from where the clip has
## them by "arms".
func _arms(p: Dictionary) -> void:
	var at_head: float = p.at_head
	var at_hips: float = p.at_hips
	var ref: Vector3 = _bone("Chest").origin * (1.0 - at_head - at_hips) \
			+ _bone("Head").origin * at_head + _bone("Hips").origin * at_hips
	for side: String in ["L", "R"]:
		var low := side.to_lower()
		var target: Vector3 = ref + p["hand_" + low]
		target = _bone("Wrist." + side).origin.lerp(target, p.arms)
		if not _forearms.has(side):
			_forearms[side] = _rest_length("LowerArm." + side, "Wrist." + side)
		_two_bone("UpperArm." + side, "LowerArm." + side, _forearms[side], target, p["elbow_" + low])
		var palm: Vector3 = p["palm_" + low]
		if palm.length_squared() > 0.01 and p.arms > 0.5:
			_aim_bone("Wrist." + side, palm)


## Degrees left a hiding Worker turns its head to watch him while it has
## him in sight, at most WATCH_MOST; 0 otherwise.
func _watch_angle() -> float:
	if not shown.begins_with("hide") or not crew._can_see or crew.target == null or not is_instance_valid(crew.target):
		return 0.0
	var to := crew.model.global_transform.affine_inverse() * crew.target.global_position
	return clampf(rad_to_deg(atan2(to.x, to.z)), -WATCH_MOST, WATCH_MOST)


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
