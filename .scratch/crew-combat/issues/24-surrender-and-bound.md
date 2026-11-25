Status: ready-for-agent
Blocked by: 23

# Surrender and Bound

## Parent

Part of `.scratch/crew-combat/spec.md` (Spec: crew combat). Build order 10 of 14. Vocabulary is `CONTEXT.md`'s. Numbers are starting numbers, tuned in the last ticket.

## What to build

See the spec's "Surrender and Bound" and `issues/09`.

- Trigger: a Worker that sees the Pirate surrenders when he is within 4 m, or when his crosshair has rested on it within 10 m for 0.5 s, and it is hiding or has no route away that does not pass him. A Worker running with a way out keeps running. Never a Guard. The same with the Alarm up.
- Surrendered: it stands facing him, and after 1.5 s kneels, holding while he is in its sight. Out of his sight it goes back to hiding and the hiding rules apply.
- Bound: holding the interact key on a surrendered Worker within 2 m for 2 s. The weapon is lowered meanwhile; a hit on the Pirate or letting go cancels with nothing kept. A Bound Worker never moves, reports or raises the Alarm for the rest of the Raid.
- HUD: "Hold [interact] to tie up" with a fill ring within 2 m of a surrendered Worker. A Bound Worker shows no Awareness bar. The interact key must still prefer whatever the Pirate is looking at among a Door, a Container and a Worker.
- A Bound Worker is a serious trace: a Guard that sees one hunts from there, a Worker runs for a panel; it is reported once like a body, and is not untied.
- XP: binding 50 with a toast; killing a surrendered or Bound Worker 0 with a toast that says so; other kills unchanged. The end screen lists Workers bound.
- Ghost unaffected. Shots and Melee work on a kneeling or Bound Worker as on any crew; a hit that does not kill leaves it as it was.
- Poses are a later ticket: use a stand-in and say which.
- Update `CREW_AI.md` and the Stealth XP section.

## Acceptance criteria

- [ ] (agent) A hiding Worker surrenders within 0.2 s of the Pirate coming within 4 m in its sight; one 8 m off surrenders 0.5 s after his crosshair settles on it, within 0.1 s, and not while it points 20 degrees away.
- [ ] (agent) A Worker running for a panel with a clear route does not surrender when aimed at from 8 m.
- [ ] (agent) No Guard is ever surrendered across the crew suite.
- [ ] (agent) A surrendered Worker is kneeling 1.5 s after surrendering, within 0.2 s, and has not moved 30 s later with the Pirate in its sight.
- [ ] (agent) A surrendered Worker the Pirate leaves, Alarm down and a panel working, has raised the Alarm within 20 s plus its walk; a Bound one in the same place has not after 120 s.
- [ ] (agent) Holding interact within 2 m for 2 s binds it; released at 1.5 s it is not Bound and the next hold starts from nothing; the Pirate cannot fire during the hold.
- [ ] (agent) Binding adds 50 XP; killing a surrendered Worker and killing a Bound one each add 0; an unaware Worker kill still adds 150.
- [ ] (agent) A Guard patrolling into sight of a Bound Worker is hunting within 3 s of reaching it, and a second Guard later passing the same Worker does not react.
- [ ] (agent) Extracting after binding two Workers with the Alarm never raised still earns the Ghost bonus, and the end screen shows 2 bound.
- [ ] (agent) `tests/run_all.sh` passes.
- [ ] (human) Aiming at a cornered Worker and seeing it give up reads at once.
- [ ] (human) Tying one up feels worth the 2 seconds it costs.

## Comments
