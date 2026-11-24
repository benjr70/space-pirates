Status: resolved
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

- [x] The Pistol and the Assault Rifle sound different; crew shots sound like the Pistol.
- [x] Crew hear a shot at the weapon's loudness: raising it in the sheet makes a further crew member react.
- [x] No shot sound is referenced outside a Weapon Profile.
- [x] Every audio file added carries its source and licence.
- [x] `tests/run_all.sh` passes.

## Comments

**Build note (2026-11-22).** `WeaponProfile` gained a Sound group: `shot_sounds: Array[AudioStream]` (one at random), `reload_sounds: Array[AudioStream]` (first as the magazine comes out, second as it goes in), `action_sound: AudioStream` with `action_sound_delay: float` (none on both guns; tested with a duplicated Pistol carrying one), and `loudness: float = 24.0`. `PirateAudio` plays the held Profile's shot, reload and action sounds (kind `action` on the `gun` player; a respawn reset kills a pending one); the dry click and rack stay in `PirateAudio`. Crew play `weapon.shot_sounds`; the Pirate's and crew's gunshot noise reach `weapon.loudness`, and `CrewNoise.GUNSHOT` is gone. The listener volumes (`PirateAudio.shot_volume_db`, `Crew3D.shot_volume_db`) stay where they are: they are mix levels, not sounds. The sheet shows the new rows (loudness and the delay editable, the sound lists read-only as folder/file); `SheetTable.format` learned arrays so the doc is stable.

The prototype pick `pistol_shot.ogg` turned out to hold all three shots in "22 Magnum.wav" (bangs at 0, 0.7 and 1.4 s of its 1.6 s), so it was not brought across as is: the source was re-downloaded and cut into three single takes, one per shot, the cut.py way (onset less 15 ms, 0.5-0.6 s, 0.12 s fade, -1.5 dB peak, mono 44.1 kHz ogg), in `assets/audio/kurt_22_magnum/shot_1..3.ogg` with `LICENSE.txt`. Unheard: the takes are checked by level only, never by ear.

Checks: `test_pirate` (Pistol and Assault Rifle play their own Profile's takes, crew ring the Pistol's, reload plays the Profile's sounds in order, the action sound plays its delay after a shot, no file outside `resources/weapons` names a shot-sound folder); `test_crew` `_check_loudness` (24 m reaches crew 20 m off not 28 m; 32 set through the sheet table reaches 28 m; the same for a crew member's own shot). Gate green: pirate 619, crew 127, sandbox 94.
