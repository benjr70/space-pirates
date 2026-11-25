Status: ready-for-agent
Blocked by: 15

# Guards carry their guns

## Parent

Part of `.scratch/crew-combat/spec.md` (Spec: crew combat). Build order 2 of 14. Vocabulary is `CONTEXT.md`'s. Numbers are starting numbers, tuned in the last ticket.

## What to build

See the spec's "How crew look" (a Guard's gun), `issues/10`, `issues/02`, and `git show prototype/crew-look:scripts/proto/proto_crew_look.gd` for the poser and the pose numbers (`READY`, `READY_PISTOL`, `AIM_LONG`, `AIM_PISTOL_TWO`).

- A Guard shows its Weapon Profile's model, 1.15x, from the moment it spawns. The gun is positioned relative to the chest and the hands are solved onto it, as the prototype does; decide whether that runs as a skeleton modifier or is baked into clips, and say which under Comments.
- On patrol and in routine: the Pistol at the thigh; a long gun low across the body, both hands on it, in `Idle`, `Walk` and `Run`.
- Aiming (today's FIGHT): the Pistol in two hands; a long gun shouldered, right hand on the grip, left on the fore-end.
- Hands that close: fingers curled round the grip and the fore-end of each of the four guns, wrists squared to the gun. This is the prototype's known fault and the main work of this ticket. A fore-end marker on each weapon scene if that helps.
- Shots leave from the gun's `Muzzle` marker, not a computed point; the clear-shot test uses the same point.
- A dead Guard's gun falls with it or is hidden; it cannot be picked up.
- A `tests/shots.sh crew` view (or a new preset) showing a Guard with each gun, on patrol and aiming, from the front and the side. Update `docs/agents/validation.md` if a preset is added.

## Acceptance criteria

- [ ] (agent) Every living Guard has a visible gun model whose scene is its Weapon Profile's `model`; no Worker has one.
- [ ] (agent) Aiming, each hand's wrist is within 4 cm of its place on the gun (grip, and fore-end for the three long guns), for all four guns.
- [ ] (agent) A Guard's projectile starts within 5 cm of its gun's `Muzzle` marker.
- [ ] (agent) The screenshots show, for each of the four guns, a gun in hand on patrol and aimed, with no gun floating clear of the hands and no defect from the checklist.
- [ ] (agent) `tests/run_all.sh` passes.
- [ ] (human) Hands look like they are holding each gun, on patrol and aiming.
- [ ] (human) From across a Room it is clear which gun a Guard carries.

## Comments
