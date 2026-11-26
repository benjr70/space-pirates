Status: resolved
Blocked by: none

# The Boarding Pod docks in a notch of the Hull and runs into the ship's own wall

## Parent

Found by the whole-Raid smoke run (`tests/run_all.sh only=raid_smoke seed=724804562`) on the `crew-combat` branch, 2026-11-26. It fails the same way on the older `6f448c6`, so it predates the crew combat work. Not seen in a play session.

## What was seen

Both the Quiet and the Loud Raid on one small ship stopped on the way back to the pod:

- `small seed 212624805 quiet: stuck on the way to the home door at (51.06273, 0.000873, 22.3917)  [t=33.9 s]`
- `small seed 212624805 loud: stuck on the way to the home door at (50.97508, 0.000023, 22.38976)  [t=40.6 s]`

`FAILED 2 of 1090 checks`. No crew member was within 14 m. The home-door point (51.0, 20.2) lies outside every Room, and the generator's summary for the ship reads "hatches relaxed×2".

## Cause

A generator bug, not a fault in the smoke bot. `HatchPlacer._candidates` (`scripts/gen/hatch_placer.gd`) took any two-wide run of Hull wall beside a Room as long as the single tile straight out of each gap was outside. It never looked further out. On a ragged Hull a gap can sit in a notch between two Masses: open for one tile, then the wall of another part of the ship. A Boarding Pod docked there (`BoardingPod`, 3.2 m tube plus a 0.2 m back wall) runs into that wall.

On small seed 212624805 both Hatches sit in such a notch. Hatch 0 is at tile (50, 23), two wide along x, with its Room on +y. Its pod tube runs out along -y over tiles x 50–51, y 22 down to 19. Tiles (51, 21), (51, 20) and (51, 19) are wall of the Room next door, and (52, 20) and (52, 19) are that Room's floor. Hatch 1 at (52, 45) mirrors it. `BoardingPod.choose_hatch` found no Hatch where even the tube's lane was clear, so it fell back to hatch 0. The pod was built straight through that wall. The home door is set 0.4 m in from the pod's back, at local x = 0, which is world (51.0, 20.2), on the face of wall tile (51, 20). Coming back, the Pirate stops at z ≈ 22.39, his radius off the face of wall tile (51, 21) at z = 22. That is the first wall inside the tube.

What a player would see: on such a ship the pod's tube is half filled by the ship's own wall. He cannot reach the home door to extract, and probably starts the Raid pressed against that wall (the spawn point, world (51.0, 21.1), is on the wall's edge; not checked separately).

The game already meant to stop this: `tests/test_ship_3d.gd::_check_boarding` asserts `BoardingPod.fits(layout, hatch, false)` ("the boarding pod runs into the ship's own hull"). It only runs on the built sample ship, though, and nothing in the generator enforced it.

## Fix

- `scripts/gen/hatch_placer.gd`: a new `POD_LANE` (4 tiles, the pod's depth plus its back wall, rounded up) and a public `lane_clear(hatch, out, floors, wall_set)`. `_candidates` now offers a gap only when the `POD_LANE` tiles straight out of both of its tiles are neither floor nor wall. A notch is never a Hatch, so a Raid can board by any Hatch.
- `scripts/gen/ship_invariants.gd`: clause 9 adds the clear pod lane, so the generator rerolls any ship that still breaks it, and the sweep asserts it on every ship.
- `tests/test_ship_3d.gd::_check_boarding`: asserts `HatchPlacer.POD_LANE` covers `BoardingPod.DEPTH + WALL`, so changing the pod's size cannot quietly outgrow the lane.

Generator distributions barely move (the default 100-seed sweep per Class, same code otherwise): small Hatches relaxed on 24 ships (was 23), 22 of them to half separation (was 21), Armory rate 33% (was 34%). Medium and large are unchanged, and reroll counts are the same (1, 0, 0).

## Acceptance criteria

- [x] (agent) The failure is reproduced and its cause shown: which Hatch, which tiles block the pod, and where the Pirate stops.
- [x] (agent) No Hatch is placed where the `POD_LANE` tiles straight out of it are not clear of the ship's floor and walls, asserted in `tests/test_generator.gd` (in `generator`), failing without the fix.
- [x] (agent) `tests/run_all.sh only=raid_smoke seed=724804562` passes.
- [x] (agent) `only=generator` and `only=ship_3d` pass; `only=raid_smoke seeds=20` passes once; the full gate `tests/run_all.sh` passes twice.

## Evidence

- Reproduced on `9323751`: `tests/run_all.sh only=raid_smoke seed=724804562` gave the two failures above, `FAILED 2 of 1090 checks`. A throwaway script (not committed) generated small 212624805 and printed every Hatch with `BoardingPod.fits` and the footprint tiles that are floor or wall. Hatch 0 at (50, 23), inward (0, 1), centre (51.0, 23.5): `fits false lane false`, blocked by walls (52, 22), (51, 21), (52, 21), (51, 20), (51, 19) and floor (52, 20), (52, 19). Hatch 1 at (52, 45), inward (0, -1): `fits false lane false`, the same pattern. `choose_hatch` returned 0. The tube's lane tiles (51, 21), (51, 20), (51, 19) are wall, and the Pirate stopped at z 22.39, his radius off the face of tile (51, 21).
- Regression check: `tests/test_generator.gd::_check_pod_lanes`. It takes small 212624805's own roll (`ShipGenerator._attempt(..., 0)`, so a reroll cannot hide a bad Hatch). It asserts that roll breaks no invariant and that its Hatches have clear lanes. Then it draws Hatches with `HatchPlacer.place` on that partition 60 times, each with its own RNG seed, and asserts every Hatch drawn has a clear lane. With the `lane_clear` filter taken out of `_candidates`: `FAIL pod lanes on small seed 212624805: the seed's own roll is invalid: hatch at (50, 23) has no clear lane out for a boarding pod; hatch at (52, 45) has no clear lane out for a boarding pod`, the same for both emitted Hatches, and `53 of 120 Hatches drawn have no clear pod lane`. With the fix it passes.
- The replay on the final code: `tests/run_all.sh only=raid_smoke seed=724804562 class=small ship=212624805`: `PASS (73 checks)`. The whole seed `tests/run_all.sh only=raid_smoke seed=724804562`: `PASS (1104 checks, 190 s)`, quiet, loud and caught 5/5 on every Class.
- `tests/run_all.sh only=generator,ship_3d` on the final code: `generator sweep: PASS (358259 checks, 51 s)`, `3D ship and built sample: PASS (3718 checks, 12 s)`.
- `tests/run_all.sh only=raid_smoke seeds=20`, seed 619145975: `PASS (4389 checks, 679 s)`, 20/20 for every Class and script, Ghost 60/60 Quiet, a kill 60/60 Loud.
- Full gate on the final code: seed 90023943, every suite PASS (static 177, generator 358259, layouts 252, ship_3d 3718, pirate 2402, crew 369, sandbox 490, attachments 1674, raid_smoke 1104), 324 s. Seed 546187845, every suite PASS (raid_smoke 1104 checks), 309 s.

## Owed to playtest

None: no `(human)` criteria.

## Comments

2026-11-26: diagnosed and fixed by a subagent in its own worktree on branch `fix/pod-home-door`, from `9323751`, for cherry-picking onto `crew-combat`. How often the old placer put the boarding Hatch in a notch over a wide sweep was not measured. Of the 15 ships smoke seed 724804562 rolls, this was the only one that failed.
