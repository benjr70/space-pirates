class_name CrewTypes
extends RefCounted
## Who a crew member is, decided by the Role of its Post Room: a **Guard**
## (armed, trained, walks patrol routes, fights) or a **Worker** (works at
## props, runs for a Guard or hides when it spots the Pirate, fights only
## when cornered). See `CREW_AI.md`.

enum Type { GUARD, WORKER }

const GUARD_ROLES: Array[StringName] = [&"armory", &"bridge", &"corridor"]
const WORKER_ROLES: Array[StringName] = [&"engine", &"cargo", &"shield", &"medbay"]

## Workers wear this tint until their own model is picked in the booth.
const WORKER_TINT := Color(1.0, 0.62, 0.28)


## The type for the [param index]th crew member posted in a Room of
## [param role]. Quarters house both, alternating; anything unlisted guards.
static func for_role(role: StringName, index: int) -> Type:
	if role in GUARD_ROLES:
		return Type.GUARD
	if role in WORKER_ROLES:
		return Type.WORKER
	if role == &"quarters":
		return Type.GUARD if index % 2 == 0 else Type.WORKER
	return Type.GUARD


static func tint(type: Type) -> Color:
	return WORKER_TINT if type == Type.WORKER else Color.WHITE
