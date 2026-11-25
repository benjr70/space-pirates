Status: ready-for-agent
Blocked by: 15

# Unarmed Workers run and hide

## Parent

Part of `.scratch/crew-combat/spec.md` (Spec: crew combat). Build order 9 of 14. Vocabulary is `CONTEXT.md`'s. Numbers are starting numbers, tuned in the last ticket.

## What to build

See the spec's "Workers" and `issues/08`.

- Spotting the Pirate with the Alarm down: three in four run for the nearest working Alarm Panel, else the nearest living Guard; one in four freeze 1 s and run to a hiding place; with neither panel nor Guard, hide.
- Alarm up: every Worker not already hiding runs to a hiding place; one on its way to a Guard switches.
- A hiding place, scored by preference: a corner or a wedge between wall and prop; out of sight of every doorway of its Room; far from the Pirate and from any Guard's cover. In its Post Room if reachable without passing him, else in the joined Room furthest from him. Never a tile a Guard has claimed; if a Guard claims its tile it moves to its next best.
- It runs at full speed, by no route that runs toward him, avoiding the line between him and a fighting Guard where another route exists.
- Hiding: it stays put when found, and through a fight in its Room.
- Coming out: never with the Alarm up. With it down, after 20 s with no sight or sound of him it comes out On Edge and walks to the nearest working panel (raising the Alarm) or Guard (alerting it), then resumes its routine; with neither, it resumes On Edge. This replaces the 15 s silent return.
- A Worker shot and alive always hides, with no roll, and never comes out.
- Traces unchanged.
- Poses are a later ticket: use today's stance or a stand-in and say which.
- Update `CREW_AI.md`.

## Acceptance criteria

- [ ] (agent) No Worker fires a shot in any check of the crew suite.
- [ ] (agent) With the Alarm raised, every living Worker is within 0.5 m of a tile with wall or prop on at least two sides within 25 s, on a generated medium ship.
- [ ] (agent) Over 20 seeds, at least 80% of hiding tiles have no clear line at 1.5 m to any doorway of their Room.
- [ ] (agent) No Worker's hiding tile is a tile a Guard has claimed as cover, over a 60 s fight.
- [ ] (agent) A Worker running to hide is never nearer the Pirate than both ends of its route less 1 m.
- [ ] (agent) Over 400 spottings with the Alarm down and a panel in reach, between 20% and 30% of Workers hide and the rest run for a panel or a Guard.
- [ ] (agent) A hidden Worker with the Alarm down and the Pirate gone raises the Alarm at a working panel, having left its tile 20 s after last noticing him, within 1 s.
- [ ] (agent) With every panel broken and no Guard alive, that Worker is back on its routine and On Edge, and the Alarm is still down.
- [ ] (agent) A Worker hit for less than its Health is on a hiding tile within 15 s and has not left it 60 s later, Alarm down.
- [ ] (agent) A hidden Worker with the Pirate standing 5 m off in its sight for 10 s does not leave its tile.
- [ ] (agent) `tests/run_all.sh` passes.
- [ ] (human) Under the Alarm the ship feels afraid: Workers run and are found tucked into corners.
- [ ] (human) Leaving a witness with the Alarm down feels like a real cost.

## Comments
