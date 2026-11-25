Status: ready-for-agent
Blocked by: 21, 24

# Firefights in the raid smoke suite

## Parent

Part of `.scratch/crew-combat/spec.md` (Spec: crew combat). Build order 13 of 14. Vocabulary is `CONTEXT.md`'s. Numbers are starting numbers, tuned in the last ticket.

## What to build

See the spec's "Testing Decisions" and `issues/14`.

- The raid smoke suite's scripted Raids check on every ship, for the whole Raid: no Guard in a fight stands in the open, fighting, for more than 3 s while a valid cover spot was in its reach; no crew member is stuck (trying to walk and moving under 0.3 m in 5 s); never more than two Guards aiming true; no Worker fires; no Bound Worker moves.
- Its scripted Pirate should meet Workers as the Raids already meet crew; add a script that aims at a cornered Worker and binds it, if no existing script would reach one.
- A failure prints the replay command as the suite does today.
- Add the invariants to the suite and coverage tables of `docs/agents/validation.md`.

## Acceptance criteria

- [ ] (agent) `tests/run_all.sh only=raid_smoke seeds=20` passes with the new invariants reported in its check count.
- [ ] (agent) With the fair-walk rule switched off for one run (a mutation), the cover invariant or a cover check fails on at least one seed, showing the invariant bites.
- [ ] (agent) At least one scripted Raid in the default sweep binds a Worker, and the suite reports it.
- [ ] (agent) `tests/run_all.sh` passes, and the smoke suite takes no more than 20% longer than before this ticket.

## Comments
