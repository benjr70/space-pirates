Status: resolved
Blocked by: 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27

# First balance pass of crew combat

## Parent

Part of `.scratch/crew-combat/spec.md` (Spec: crew combat). Build order 14 of 14. Vocabulary is `CONTEXT.md`'s. Numbers are starting numbers, tuned in the last ticket.

## What to build

See the spec's "Owed to playtest". Played by the user, with the Sandbox sheet open.

- Play small, medium and large ships, quiet and loud.
- Tune each weapon's Gunnery and the Crew fight section in the sheet until fights read right; save.
- Decide whether crew counts per Ship Class and the Pirate's 150 Health still fit; change them if not.
- Collect every `(human)` line from the other tickets' "Owed to playtest" and tick or reopen each.
- Record the numbers that changed under Comments, and update `CREW_AI.md` and `docs/sandbox.md` to match.

## Acceptance criteria

- [ ] (agent) After the pass, `tests/run_all.sh` passes with the checks' expected values updated to the tuned numbers.
- [ ] (human) The fight reads as trading shots, not a rush.
- [ ] (human) Each gun's habit is recognisable, and its deadliness in a Guard's hands feels fair.
- [ ] (human) The Marksman Rifle's sight line and the Shotgun's rack give enough warning; the reload sound reads as a window.
- [ ] (human) How each crew gun sounds from the receiving end is acceptable, or a sound ticket is opened.
- [ ] (human) Crew counts and the Pirate's Health fit the new fights, or were changed here.
- [ ] (human) Workers running, hiding, surrendering and being tied up feel right, and a witness is a real cost.

## Comments

- First balance pass, 2026-11-26. The user played Raids on the branch, asked for the changes below, and then said the playtest "is good enough for this iteration" and to merge and close out. The `(human)` lines above, and the `(human)` lines collected under each ticket's "Owed to playtest", were not ruled on one by one and stay unticked; anything the user did not raise is taken as acceptable for this iteration.
- What the user asked for and what changed:
  - "They don't shoot often enough": time down cut about 40% (Pistol 1.0–2.0 → 0.6–1.2 s, Assault Rifle 1.5–2.5 → 0.9–1.5, Shotgun 1.2–1.5 → 0.7–0.9, Marksman Rifle 2.5–4.0 → 1.5–2.4).
  - "Five of them took way too long to kill me": `true_aim_count` 2 → 3; aim error Pistol 7.5 → 5, Assault Rifle 6 → 4, Shotgun 8 → 6 degrees; `closing_time` 2.0 → 1.2 s on every gun. Range was not changed: Guards already fire at any distance, except the Shotgun beyond 8 m. Median time to die on the fixed seeds: Pistol at 6 m 9.56 → 5.05 s, Assault Rifle at 7.5 m 5.68 → 3.29 s; `_check_time_to_die` now wants 5 s and 3.5 s within 40%.
  - "The Guards' Shotgun is ear-splittingly loud; keep the rack audible": a crew Shotgun's shot is 9 dB quieter (`Crew3D.shotgun_shot_trim_db`), and every crew gun action (the rack, the bolt) plays at `Crew3D.action_volume_db` −9 dB, 6 dB under what it was.
  - "Headshots are not registering": head zones were where the heads are in every pose. The bolt's own 0.09 m width was striking the crate a Guard kneels behind, so a shot at the top of its head died on the crate. A bolt now stops on the hull or a prop only when its line strikes it, or when it is born inside it (`Projectile3D._on_body_entered`, `_inside`). Check: `_check_down_poses`, a bolt at 1.14 m over the 1.1 m crate is a Headshot (it failed before the fix, striking the crate).
  - "They stand up and get down faster than my bullets reach them": `CrewPose.DROP_TIME` 0.15 → 0.4 s, `RISE_TIME` 0.2 → 0.3 s, and the capsule now comes down when the body has (`CrewCover.settle_capsule`), not at the start of the drop.
- Checks updated to the tuned numbers: `_check_gunnery`, `_check_time_to_die`, `_check_true_aim` (default three), `_check_marksman_waits_for_place` (its rig pins the count at 2), `_check_cover_ring` and `_check_down_poses` (the capsule's delay), `test_sandbox.gd`'s doc strings, and the smoke run's `TRUE_AIM_MOST` 3.
- Gate after the pass, seed 138129134: every suite passes except the smoke run, 1 of 1285 checks: a Guard firing into a wall at its muzzle point blank in one Raid, filed as `.scratch/raid-smoke-bugs/issues/13-guard-fires-into-a-wall-at-its-muzzle.md`. The `(agent)` line above stays unticked for that reason. The user chose to merge with it open.
- Crew counts per Ship Class and the Pirate's 150 Health: not changed.
