Status: ready-for-agent
Blocked by: 20

# Per-weapon sounds and loudness

## Parent

Part of `.scratch/new-weapons/spec.md` (Spec: Shotgun, Marksman Rifle and the Sandbox sheet). Build order 5 of 12. Vocabulary is `CONTEXT.md`'s. Numbers are starting numbers, tuned in the last ticket.

## What to build

See the spec's "New Weapon Profile fields" and "Sounds" sections and `issues/12-new-gun-sounds.md`.

The Weapon Profile gains: shot sounds (a list, one played at random), reload sounds, an optional action sound with a delay after the shot, and loudness, the distance in metres at which crew hear the shot. Shot sounds leave `scripts/pirate_audio.gd` and `scripts/crew/crew.gd` for the Profile; the gunshot noise crew hear takes the Profile's loudness in place of the constant in `scripts/crew/crew_noise.gd`.

The Pistol takes its new shot, kurt's .22 Magnum, for the Pirate and crew alike. The Assault Rifle keeps today's gunshot. Both stay at loudness 24. The picked cuts, their `LICENSE.txt` and the cutting script are on branch `prototype/new-gun-sounds` under `assets/audio/audition_picks/`; bring across what this ticket uses into `assets/audio/` with its licence note. The pick is one take: cut two or three more variants of the Pistol shot from the same source recording.

Loudness joins the sheet as a row.

## Acceptance criteria

- [ ] The Pistol and the Assault Rifle sound different; crew shots sound like the Pistol.
- [ ] Crew hear a shot at the weapon's loudness: raising it in the sheet makes a further crew member react.
- [ ] No shot sound is referenced outside a Weapon Profile.
- [ ] Every audio file added carries its source and licence.
- [ ] `tests/run_all.sh` passes.

## Comments
