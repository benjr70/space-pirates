Status: ready-for-agent
Blocked by: 18

# Fair fire

## Parent

Part of `.scratch/crew-combat/spec.md` (Spec: crew combat). Build order 5 of 14. Vocabulary is `CONTEXT.md`'s. Numbers are starting numbers, tuned in the last ticket.

## What to build

See the spec's "Fair fire" and `issues/06`; `git show origin/research/fair-fire-and-cover:docs/research/fair-fire-and-cover.md` for the sources.

- Exposure ramp: spread opens at the Gunnery's multiple (3x) and closes to 1x over its closing time (2 s) of unbroken sight; resets on broken sight. Remove the 1.5x to 0.5x curve.
- First burst of a sighting walks in from 1 m to one side, reaching him on its last round. Not for the Shotgun or Marksman Rifle.
- True aim: at most two Guards aim true at once, at least one when any has sight and a clear muzzle line. Handover by a timer of 0.8 s, doubled while he is crouched or in cover, halved inside 3 m, to the Guard nearest him with a clear line that held it least recently. A Guard starting a reload gives it up at once.
- Miss points for everyone else: 0.4 to 0.8 m off his body, at the edge of his cover on the side he last peeked from, or beside his head away from his movement in the open.
- Lead by the Gunnery's fraction of the true intercept; halved during a Slide or Clamber.
- A crew Shotgun shot hurts with at most 9 pellets.
- Hitting a Guard throws its spread back to the opening multiple and restarts the closing.
- The numbers a later ticket puts in the sheet (how many aim true, the handover time, the walk-in distance, the pellet cap) live on the Sandbox resource from the start.
- The Marksman Rifle's sight line and the Shotgun's rack are in "A habit per gun".
- Update `CREW_AI.md`.

## Acceptance criteria

- [ ] (agent) A Guard's spread is 3x its base (gun spread plus aim error) on first sight and 1x after 2 s of unbroken sight, each within 5%, and never below 1x in 10 s; after sight breaks and returns it is 3x again.
- [ ] (agent) In the first burst of a sighting from an Assault Rifle Guard, every round but the last is aimed at least 0.3 m to one side of the Pirate and the last is aimed at him (before spread).
- [ ] (agent) With five Guards in sight of him for 20 s, no physics frame has more than two aiming true, and every frame in which any has a clear muzzle line has at least one.
- [ ] (agent) Every shot from a Guard not aiming true is aimed between 0.4 and 0.8 m from his body centre (before spread).
- [ ] (agent) Against a Pirate walking across at 4 m/s, a Marksman Rifle shot is aimed at the full intercept and a Pistol shot at 0.3 of it, each within 10%; a Shotgun shot at where he is.
- [ ] (agent) A crew Shotgun shot from 1 m with all 12 pellets striking takes 117 Health and leaves a full-health Pirate alive.
- [ ] (agent) A Guard hit by the Pirate after 2 s of sight has its spread back at 3x.
- [ ] (agent) Standing still and exposed at full health against one Guard at its range, over 20 seeded runs the median time to die is within 40% of 10 s (Pistol, 6 m) and 6 s (Assault Rifle, 7.5 m). A run outside that is reported, not tuned away.
- [ ] (agent) `tests/run_all.sh` passes.
- [ ] (human) Enemy fire warns before it hurts, and damage feels like the price of staying exposed.

## Comments
