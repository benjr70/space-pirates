Status: ready-for-agent
Blocked by: 15

# Crew magazines and reloads

## Parent

Part of `.scratch/crew-combat/spec.md` (Spec: crew combat). Build order 3 of 14. Vocabulary is `CONTEXT.md`'s. Numbers are starting numbers, tuned in the last ticket.

## What to build

See the spec's "Magazines and reloads" and `issues/04`.

- A Guard counts rounds against its Profile's magazine, starts full, and has unlimited magazines.
- Dry, it reloads: the Profile's empty reload time times the Gunnery's reload factor (1.5). It goes behind cover first where today's cover search finds any, else reloads where it stands, backing away. It does not fire while reloading. Being shot, flanked or closed on does not cancel or restart it.
- Topping up: behind cover with the Pirate unseen for 3 s, a part-used magazine is reloaded with the Profile's shorter time times the factor.
- The Shotgun loads shell by shell with the Profile's times times the factor; with the Pirate in sight within 3 m and at least one shell in, it breaks off and fires.
- The Profile's reload sounds play at the Guard's position, at the start and end of a reload (each shell for the Shotgun).
- Burst length stays the Gunnery's; the magazine caps it.
- Update `CREW_AI.md`.

## Acceptance criteria

- [ ] (agent) A Pistol, Assault Rifle, Shotgun and Marksman Rifle Guard each fire exactly 12, 30, 6 and 8 shots before the first reload.
- [ ] (agent) An empty Assault Rifle reload takes 3.45 s (2.3 x 1.5), within 5%, and no shot is fired during it.
- [ ] (agent) A Guard hit twice during a reload still finishes it at the same time, within 0.1 s.
- [ ] (agent) A Guard behind cover with 5 rounds left and the Pirate unseen for 3 s is at a full magazine 1.2 x 1.5 s later for the Pistol, within 10%.
- [ ] (agent) A Shotgun Guard reloading with 2 shells in fires within 0.6 s of the Pirate coming into sight inside 3 m; with him at 6 m it loads to 6 before firing.
- [ ] (agent) A reload sound is played at the reloading Guard's position when a reload starts.
- [ ] (agent) `tests/run_all.sh` passes.
- [ ] (human) A Guard's reload can be heard in a fight and reads as a chance to move.

## Comments
