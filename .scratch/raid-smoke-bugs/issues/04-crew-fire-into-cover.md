Status: resolved
Blocked by: none

# Crew empty bursts into cover

## Parent

Found on 2026-11-22 by the whole-Raid smoke run (`.scratch/agent-verification/issues/06-whole-raid-smoke-run.md`, Comments). Not yet confirmed in a play session.

## What is wrong

FIGHT fires whenever the eye-to-eye line is clear, but the muzzle-to-torso line can clip the top of a crate or cryopod. Seen: 20 or more bolts in a row into the same prop with the Pirate standing in view, the crew member never repositioning. With bug 02 this makes some Caught Raids never end.

Replay: `tests/run_all.sh only=raid_smoke seed=20 seeds=10 class=small ship=27592579 script=caught`

## Acceptance criteria

- [x] (agent) A crew member whose muzzle line to the Pirate is blocked does not keep firing from the same spot; asserted in `tests/test_crew.gd` with a prop between muzzle and Pirate.
- [x] (agent) The replay above passes (it fails today: Caught is not downed in 150 s).
- [ ] (human) Guard fire feels fair in a play session.

## Evidence

- Root cause: partly as described (FIGHT fired on the eye line alone), and partly different. A debug print of every crew shot in the replay showed the thin muzzle-to-torso ray was clear for all 20+ bolts: the crew member stood beside the cryopod, and each bolt was born within its 0.09 m overlap sphere of the cryopod's side (the barrel poking past it), so the Area3D overlap struck it at once. With a thin-ray muzzle check alone the replay still printed the 20-bolts NOTE into the same cryopod, so the fix tests the path the bolt actually takes.
- Fix (`crew.gd::_tick_fight`, `_muzzle_blocked`, `_muzzle_blocked_from`): FIGHT fires only while its muzzle line is clear as well. That line is a 0.1 m ball (`MUZZLE_BALL`) swept from the body's axis at 1.3 m to 0.4 m short of his torso (`MUZZLE_TARGET_GAP`), plus both edges of its current spread for the first 1.5 m (`MUZZLE_NEAR`). Blocked, it holds fire and steps out to the nearest tile at least 1 m away (`FIRING_STEP`), in range, with a clear muzzle line, and walks all the way there before firing again (`_stepping_out`); with no such tile it closes on him. `_find_firing_position` uses the same test. Recorded in `scripts/crew/CREW_AI.md` (States, "A clear shot").
- Check: `tests/test_crew.gd::_check_muzzle_blocked` (`_muzzle_rig`), two rigs with the Pirate 6 m off and the eye line clear: a crate he stands just behind (0.7 m), and a locker at the Guard's shoulder whose side the barrel passes by 7 cm. It counts bolts by what they strike (the projectile `hit` signal, not the code under test) over 6 s and asserts no bolt into the cover from within 0.5 m of where it stood, a step more than 0.5 m off, and at least one hit on the Pirate. With the muzzle check off: `FAIL  muzzle (crate): ... put 8 bolts into it from where it stood (8 in all) and 0 into the Pirate, stepping at most 0.1 m off` and `FAIL  muzzle (locker): ... 6 bolts into it from where it stood (10 in all) and 3 into the Pirate, stepping at most 0.5 m off`. After: PASS on seeds 777 and 1–9.
- Replay: `tests/run_all.sh only=raid_smoke seed=20 seeds=10 class=small ship=27592579 script=caught` printed `NOTE ... fired 20 bolts in a row into the ship (prop_cryopod_3d ...)` and failed before; after: `PASS  8 checks` with no bolts NOTE, also with `CREW_STEERING_BUG_IS_NOTE` false.

## Owed to playtest

- (human) Guard fire feels fair in a play session.

## Comments

2026-11-22: fixed by a subagent, test-first. The orchestrating session re-ran the full gate after the smoke suite was hardened (all 7 suites PASS, 149 s); reintroducing this bug was shown to fail the gate (mutation table in `.scratch/agent-verification/issues/06-whole-raid-smoke-run.md`, Comments). Play session owed.
