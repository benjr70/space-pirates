class_name CrewTraces
extends RefCounted
## What the Pirate leaves behind that crew can find: bodies where they fell,
## the boarding Hatch he left open, Containers he emptied and Doors he left
## standing open. A crew member that sees an unreported trace in its forward
## cone becomes suspicious and walks to it, and reaching it reports it once.
## How hard it reacts depends on how bad the trace is ([method serious]).
## See `CREW_AI.md`.

## Seconds between one crew member's looks for traces.
const LOOK_EVERY := 0.25
## A trace is reached, and reported, from this close.
const REACH := 1.6
## Awareness a found trace lifts a crew member to: suspicious, not spotted.
const AWARENESS := 0.5
## Where on a trace the sight line is aimed, off the floor.
const AIM_HEIGHT := 0.4


## The nearest unreported trace [param crew] can see: in its cone, within
## sight range, with a clear line from its eyes. Null when there is none.
static func spot(crew: Crew3D) -> Node3D:
	var best: Node3D = null
	var best_distance := INF
	var tree := crew.get_tree()
	for group in [&"crew", &"containers", &"doors"]:
		for node in tree.get_nodes_in_group(group):
			var trace := node as Node3D
			if trace == null or trace == crew or not is_trace(trace) or trace in crew.abandoned_traces:
				continue
			var to := trace.global_position - crew.global_position
			var distance := Vector2(to.x, to.z).length()
			if distance > CrewPerception.SIGHT_RANGE or distance >= best_distance:
				continue
			if not CrewPerception.in_cone(crew.facing(), to):
				continue
			if crew._blocked(crew.global_position + Vector3.UP * Crew3D.EYE_HEIGHT,
					trace.global_position + Vector3.UP * AIM_HEIGHT, trace):
				continue
			best = trace
			best_distance = distance
	return best


## Whether [param node] is a trace nobody has reported yet: a dead crew
## member, an emptied Container, or a Door or Hatch the Pirate left open.
static func is_trace(node: Node) -> bool:
	if node is Crew3D:
		return not node.is_alive() and not node.reported
	if node is Container3D:
		return node.is_open and not node.reported
	if node is Door3D:
		return node.is_open and node.left_open and not node.reported and not node.sealed
	return false


## A body or the boarding Hatch: worth raising the Alarm over. An emptied
## Container or a Door left open only puts a crew member On Edge.
static func serious(node: Node) -> bool:
	return node is Crew3D or (node is Door3D and node.is_hatch())
