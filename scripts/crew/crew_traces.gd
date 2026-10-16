class_name CrewTraces
extends RefCounted
## What the Pirate leaves behind that crew can find: bodies where they fell.
## A crew member that sees an unreported trace in its forward cone becomes
## suspicious and walks to it; reaching it, it reports it once, and a Worker
## runs to raise the Alarm while a Guard hunts from there. See `CREW_AI.md`.

## Seconds between one crew member's looks for traces.
const LOOK_EVERY := 0.25
## A trace is reached, and reported, from this close.
const REACH := 1.6
## Awareness a found trace lifts a crew member to: suspicious, not spotted.
const AWARENESS := 0.5
## Where on a body the sight line is aimed, off the floor.
const BODY_HEIGHT := 0.4


## The nearest unreported trace [param crew] can see: in its cone, within
## sight range, with a clear line from its eyes. Null when there is none.
static func spot(crew: Crew3D) -> Node3D:
	var best: Node3D = null
	var best_distance := INF
	for node in crew.get_tree().get_nodes_in_group(&"crew"):
		var body := node as Crew3D
		if body == null or body == crew or body.is_alive() or body.reported or body in crew.abandoned_traces:
			continue
		var to := body.global_position - crew.global_position
		var distance := Vector2(to.x, to.z).length()
		if distance > CrewPerception.SIGHT_RANGE or distance >= best_distance:
			continue
		if not CrewPerception.in_cone(crew.facing(), to):
			continue
		if crew._blocked(crew.global_position + Vector3.UP * Crew3D.EYE_HEIGHT,
				body.global_position + Vector3.UP * BODY_HEIGHT):
			continue
		best = body
		best_distance = distance
	return best
