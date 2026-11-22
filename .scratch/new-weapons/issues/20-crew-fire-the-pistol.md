Status: ready-for-agent
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

- [ ] A crew shot carries the Pistol Profile's damage, speed and lifetime; changing the Pistol in the sheet changes crew shots too.
- [ ] A Guard's cone is the Pistol's base cone plus 6 degrees; a Worker's plus 11.
- [ ] Burst length, pause and engage range come from the Gunnery resource and can be dialled and saved in the sheet.
- [ ] No gun number is left as a constant or export on the crew script.
- [ ] `tests/run_all.sh` passes.

## Comments
