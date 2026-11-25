Status: ready-for-agent
Blocked by: 22, 24

# Workers' poses

## Parent

Part of `.scratch/crew-combat/spec.md` (Spec: crew combat). Build order 11 of 14. Vocabulary is `CONTEXT.md`'s. Numbers are starting numbers, tuned in the last ticket.

## What to build

See the spec's "How crew look" (Workers) and `issues/10`. Pose numbers: `git show prototype/crew-look:scripts/proto/proto_crew_look.gd` (`HIDE`, `HIDE_FLINCH`, `HIDE_SAT`, `HANDS_UP`, `HANDS_HIGH`, `KNEEL`, `KNEEL_LOW`, `BOUND_SAT`, `BOUND_KNEEL`), using the poser the Guards' poses ticket brought in.

- Each Worker rolls its own set once at ship build, from the ship's seed, even odds on each: hiding crouched with arms over its head or sat down; hands by its head or straight up; kneeling upright or on its heels; Bound sat against the wall or kneeling with hands behind its back.
- Hiding crouched, it ducks lower at each gunshot it hears, then comes back up.
- Hiding, its back is to the wall or prop it hides against and it faces into the Room.
- The surrender runs hiding, hands up, kneeling, as the prototype's sequence does.
- Bound sat, it sits against the nearest wall or prop; with none within 1 m it uses its kneeling Bound pose.
- The collision and head zone follow each pose.
- The stand-ins from the Workers and Surrender tickets go.
- `tests/shots.sh crew` (or a preset) shows all eight poses.

## Acceptance criteria

- [ ] (agent) Over 400 Workers across seeds, each of the eight poses is rolled by between 40% and 60% of them for its pair, and the same seed gives each Worker the same set.
- [ ] (agent) A hiding Worker faces within 30 degrees of directly away from the wall or prop behind it.
- [ ] (agent) A crouched hiding Worker's head is at least 0.1 m lower within 0.3 s of a gunshot it hears, and back within 1.5 s.
- [ ] (agent) In every pose the head zone is within 0.15 m of the head bone and the body's collision top is no higher than the head.
- [ ] (agent) The screenshots show the eight poses on the Worker model with hands where the pose puts them (on the head, raised, or behind the back) and no defect from the checklist.
- [ ] (agent) `tests/run_all.sh` passes.
- [ ] (human) Worker poses read as fear and as giving up, and three Workers in a Room do not look copied.

## Comments
