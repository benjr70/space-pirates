Type: prototype
Status: resolved
Blocked by: 02, 05, 09
Map: ../map.md

# How crew look in a fight

## Question

What does the Pirate see when a Guard takes cover, peeks, reloads and carries each gun, and when a Worker hides, cowers and surrenders?

Using the routes "Where new crew clips come from" recommends, put each pose and clip on the real Guard and Worker models in a prototype scene the user walks round: crouched behind low cover, the peek out and back, a reload, each of the four guns in a Guard's hands, a Worker hiding in a corner (crouched, back to the wall, arms over its head, ducking at a gunshot), hands up standing, kneeling with hands on its head, and Bound, sitting against a wall. Include the two pieces the research added for long guns: a shouldered hold, and the left hand placed on the fore-end. Offer more than one candidate where the routes allow.

The user picks by eye. The answer records which clip and route won for each, and what is still owed.

## Answer

Prototyped and judged by the user on 2026-11-25 in a booth of 24 figures. Prototype: branch `prototype/crew-look` (`scripts/proto/proto_crew_look.gd`), where every pose's numbers are.

**The standing rule.** Where the booth showed two candidates, the game uses both: "I don't want to choose one or the other. I want to use all of them diversely so the game feels fresh and natural."

**How poses are made.** In code over the rig's own clips, as the prototype did: hips lowered and legs re-solved onto the feet, arms solved onto the gun or the head. No new clips and nothing retargeted, except that the reload is still owed a real clip. The build may bake the same poses into clips if that proves cheaper at run time; the look is what is decided.

**Guards carrying and aiming.**
- The gun is positioned first and the hands are put on it: right hand on the grip, left on the fore-end for the three long guns, shouldered.
- Pistol aim: two hands (candidate B).
- On patrol: Pistol at the thigh, a long gun low across the body.
- The one criticism: the hands do not line up on the guns. The build owes hands that close on the grip and fore-end of each gun, with the wrists squared to it.

**Down behind low cover: both, chosen each time it goes down.** Every time a Guard drops back after a peek it picks again: squat 60%, one knee 40%. Squatting, its head is below the cover and cannot be hit; on one knee the top of its head shows and can be. The head zone follows the pose, so a Headshot over a crate is there to take only against one knee. This was the user's point: it should be an opening the Pirate sometimes gets.

**Running to cover: by where it is going.** A low run to low cover; an upright run to full cover or with no cover to go to.

**The moves.** Pop up over low cover, step out from full cover and back, duck lower at a near miss, reload while down: accepted as moves. The reload (three arm positions) and the step-out (which slides) are rough and stay so until given proper animation.

**Workers: each rolls its own set, once.** At ship build, from the ship's seed, so a Retry matches. Even odds on each: hiding crouched with arms over its head (ducking lower at a gunshot) or sat down; surrendering with hands by its head or arms straight up; kneeling upright or on its heels; Bound sat against the wall or kneeling with hands behind its back. One Worker stays consistent; a Room of three shows different poses.

**The surrender sequence.** Hiding, then hands up, then kneeling, as shown.

**Owed.** Gripping hands and squared wrists for all four guns; a real reload; a step-out that steps; the Marksman Rifle's sight line and the Shotgun's rack, which this booth did not show.

## Comments

2026-11-25: prototype built on local branch `prototype/crew-look` (commit `76e13fc`, local, never merged). Scene `scenes/proto_crew_look.tscn`, script `scripts/proto/proto_crew_look.gd`. Run:

    flatpak run org.godotengine.Godot --path . res://scenes/proto_crew_look.tscn

24 figures in a row, each a pose or a looping move, candidates side by side as A and B. Every pose is made in code over the rig's own clips (hips lowered, legs re-solved onto the feet, arms solved onto the gun or the head), so nothing was baked in Blender and no clip was retargeted. Stills of every figure were rendered offscreen and read; the moves (pop up, step out, reload, duck, the surrender sequence) were not seen in motion by the agent.
