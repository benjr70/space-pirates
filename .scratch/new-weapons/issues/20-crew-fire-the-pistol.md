Status: resolved
Blocked by: 19

# Crew fire the Pistol, handled with a Gunnery

## Parent

Part of `.scratch/new-weapons/spec.md` (Spec: Shotgun, Marksman Rifle and the Sandbox sheet). Build order 4 of 12. Vocabulary is `CONTEXT.md`'s. Numbers are starting numbers, tuned in the last ticket.

## What to build

See the spec's "Crew and Gunnery" section and `issues/03-crew-gunnery-in-the-sandbox.md`.

Crew fire the Pistol Weapon Profile, the same resource the Pirate holds, reading its damage, projectile speed, projectile lifetime and time between shots. They ignore its magazine, reloads, bloom, Aim Down Sights, recoil and Viewmodel fields: they still fire a burst and pause.

Gunnery is a new resource, one per crew type, at `resources/gunnery/guard.tres` and `worker.tres`: aim error in degrees (added to the Pistol's own cone), burst length, pause between bursts, engage range. Guard: 6, 3, 1.1 s, 10.6 m. Worker: 11, 2, 1.1 s, 10.6 m. The Worker constants in `scripts/crew/crew.gd` move into its Gunnery; spawn jitter stays in code.

Gunnery gets its own table in the in-Raid sheet (a column per crew type) and in `docs/sandbox.md`. Update `scripts/crew/CREW_AI.md`.

Accepted consequence: crew bolts go from 23.75 m/s to 80 m/s. Do not compensate here; the balance pass retunes Gunnery.

## Acceptance criteria

- [x] A crew shot carries the Pistol Profile's damage, speed and lifetime; changing the Pistol in the sheet changes crew shots too.
- [x] A Guard's cone is the Pistol's base cone plus 6 degrees; a Worker's plus 11.
- [x] Burst length, pause and engage range come from the Gunnery resource and can be dialled and saved in the sheet.
- [x] No gun number is left as a constant or export on the crew script.
- [x] `tests/run_all.sh` passes.

## Comments

Built 2026-11-22. `Gunnery` (`scripts/crew/gunnery.gd`) with `resources/gunnery/guard.tres` (6, 3, 1.1, 10.6) and `worker.tres` (11, 2, 1.1, 10.6). `Crew3D.weapon` is the Pistol (same cached Resource as the Pirate's) and `Crew3D.gunnery` is picked by crew type at spawn when not set; both are read at the moment of use, so sheet edits reach live crew. A crew shot takes the Pistol's damage, speed and lifetime; time between shots is the Pistol's `fire_interval`; cone is `spread_base_degrees + aim_error_degrees` into `CrewCombat.spread`. Spawn jitter stays in code as stored multipliers and a Guard burst offset (now `maxi(burst + offset, 1)` instead of a fixed 2–4 clamp, so a dialled burst length is honoured). `WORKER_SPREAD`/`WORKER_BURST` and the Gunnery exports are gone; `muzzle_offset` became the body constant `MUZZLE_FORWARD` beside `MUZZLE_HEIGHT`; `projectile_scene` and the shot sound exports remain (sound moves in ticket 21). Gunnery table in the sheet and `docs/sandbox.md` (regenerated). New checks in `tests/test_crew.gd` (`_check_gunnery`) and `tests/test_sandbox.gd`; `tests/test_ship_3d.gd`'s dead-eye gunman now uses zeroed duplicates of the Pistol and Gunnery.
