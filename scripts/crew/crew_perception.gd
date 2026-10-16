class_name CrewPerception
extends RefCounted
## One crew member's Awareness of the Pirate: 0 (unaware) to 1 (spotted),
## built up by seeing him in a forward cone and draining slowly once he is
## out of it. Pure arithmetic: the crew body works out whether he is in view
## and hands that over each tick, so the timings are testable without physics.
##
## See `CREW_AI.md` beside this file for the numbers and why they are what
## they are.

## Half of the 110° forward sight cone.
const CONE_HALF_DEGREES := 55.0
const SIGHT_RANGE := 14.4
## Awareness at or above this is suspicious: the crew member comes to look.
const SUSPICIOUS := 0.3
## Awareness lost per second while the Pirate is out of view.
const DECAY_PER_SECOND := 0.2
## Seconds to go from unaware to spotted, standing in the open, square in
## view, at these distances; linear between, flat beyond the ends.
const SPOT_TIMES := [Vector2(3.0, 0.3), Vector2(10.0, 1.5), Vector2(14.0, 3.0)]
## A crouched Pirate takes this many times as long to spot.
const CROUCH_FACTOR := 2.0

enum Band { UNAWARE, SUSPICIOUS, SPOTTED }

var awareness := 0.0


## Seconds a crew member takes to spot the Pirate at [param distance].
static func spot_time(distance: float, crouched := false) -> float:
	var time: float = SPOT_TIMES[0].y
	if distance >= SPOT_TIMES[-1].x:
		time = SPOT_TIMES[-1].y
	else:
		for i in range(1, SPOT_TIMES.size()):
			var near: Vector2 = SPOT_TIMES[i - 1]
			var far: Vector2 = SPOT_TIMES[i]
			if distance <= far.x:
				time = lerpf(near.y, far.y, clampf((distance - near.x) / (far.x - near.x), 0.0, 1.0))
				break
	return time * (CROUCH_FACTOR if crouched else 1.0)


## Whether a point lies inside the forward cone of someone facing
## [param facing] (flat), ignoring range and walls.
static func in_cone(facing: Vector3, to_target: Vector3) -> bool:
	var a := Vector2(facing.x, facing.z)
	var b := Vector2(to_target.x, to_target.z)
	if b.length_squared() < 0.0001:
		return true
	if a.length_squared() < 0.0001:
		return false
	return absf(a.angle_to(b)) <= deg_to_rad(CONE_HALF_DEGREES)


static func band_of(value: float) -> Band:
	if value >= 1.0:
		return Band.SPOTTED
	if value >= SUSPICIOUS:
		return Band.SUSPICIOUS
	return Band.UNAWARE


func band() -> Band:
	return band_of(awareness)


## One tick. [param in_view] means in the cone, in range and in line of
## sight. Returns true on the tick Awareness tips into spotted.
func sense(delta: float, in_view: bool, distance: float, crouched := false) -> bool:
	var was_spotted := awareness >= 1.0
	if in_view:
		awareness = minf(awareness + delta / spot_time(distance, crouched), 1.0)
	else:
		awareness = maxf(awareness - DECAY_PER_SECOND * delta, 0.0)
	return awareness >= 1.0 and not was_spotted


## Straight to spotted, as when shot. Returns true if that was a tip.
func alert() -> bool:
	var was_spotted := awareness >= 1.0
	awareness = 1.0
	return not was_spotted
