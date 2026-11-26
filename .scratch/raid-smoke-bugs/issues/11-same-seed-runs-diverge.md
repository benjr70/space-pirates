Status: resolved
Blocked by: none

# Two runs on one seed play out differently

## Parent

Reported by a builder on the `crew-combat` branch, 2026-11-26: on a clean checkout of `c3ce6d8`, two runs of `tests/run_all.sh only=crew seed=506719008` generated different ships for the ship fight (`tests/test_crew.gd::_check_cover_fight_on_ship`). `docs/agents/validation.md` promises that `seed=<n>` replays a run exactly: same seed, same draws, same failure. Not a play-session bug; it breaks the replay a failing check prints.

## What was seen

On `97558be` (tip of `crew-combat`), crew suite, seed 506719008, run bare with `--fixed-fps 60` as the runner does. A throwaway diagnostic printed one global `randi()` after every check in `_initialize`. The extra draw is the same in every run, so it does not hide a divergence. Two runs one after another split in `_check_shotgun_rack`: run 1 `990564386`, run 2 `1621518224` (run 1's value two checks later). Every later check and the ship fight's seed differed. The splits are intermittent: another pair split only in `_check_shotgun_range` ("Shotgun at 12 m: one shot kills 22%, two shots 92%" against "95%"). Of six runs side by side, five differed from the first, each at a different place.

## Causes

1. **Jolt reports a step's contacts in a different order each run, and a bolt struck the first body reported.** `Projectile3D._on_body_entered` (`scripts/projectile_3d.gd`) struck whatever body its Area3D reported first. A bolt born touching two bodies at once (most often the Floor and the Pirate or a crew member it skims) gets two `body_entered` signals in one step. Jolt fills those in from its worker threads, so their order changes from run to run. Whichever came first took the hit: in one run the Pirate is hit (Health, the hit sound and its `pick_random()` draw on the global RNG), in the other the bolt is spent on the floor. From there the global RNG is offset, and every later crew seed, sound pick and the ship fight's `randi_range` differ. About 14 such double touches happen in a crew suite run.
2. **Instance ids differ between runs, and `Crew3D._acts_first` used them as the tiebreak.** Of two crew blocking each other that both can act, the one with the lower `get_instance_id()` acted (`scripts/crew/crew.gd`). Ids are not stable: a one-off sound (`SoundAt`) frees itself on `finished`, which the audio mixer emits in real time. `--fixed-fps` runs faster than real time, so the frame it is freed on depends on machine load, and with it which ObjectDB slot and id the next object gets. The same crew member got different ids by physics frame 93 of the suite.

Ruled out: wall-clock time and real frame deltas (`--fixed-fps 60` holds; nothing in `scripts/` reads `Time` or the ticks), Dictionary order (Godot iterates in insertion order), and the global-RNG sound pitch draws (`SoundAt`, `pick_random`). Those draws happen in a fixed order as long as the hits are the same.

## Fix

- `scripts/projectile_3d.gd`: `_on_body_entered` resolves the touch with a new `_deepest_touch`: `get_rest_info` with the bolt's own sphere at its own transform and mask, its shooter excluded and any pass-through (same-team) body skipped. It strikes the body the sphere is deepest in, whatever order the touches were reported in. When the query finds nothing (the body moved since the step), it strikes the reported body as before. Before, the order was a thread race. Now the choice is geometric and has no bias toward the floor or toward bodies.
- `scripts/crew/crew.gd`: each crew member takes a `_ready_order` from a static counter in `_ready`. `_acts_first` compares that instead of instance ids. Instance ids almost always rise with creation order, so which of a pair acts is the same as before in practice.
- `docs/agents/validation.md` ("Seeds and replay"): names the two things that still differ run to run and must decide nothing: instance ids (and auto-generated node names), and Jolt's contact order.

## What stays non-reproducible

- Instance ids and auto-generated node names (`@CharacterBody3D@4564` in one run, `@4565` in another). Nothing in the game decides anything by them now.
- The order of different bolts' `body_entered` signals within one step. Each bolt now picks its body by geometry, and nothing that follows depends on the order between bolts: the hit sounds draw the same number of times, and damage adds up the same. Six runs side by side gave identical output apart from node names in a trace.
- `raid_smoke` did not diverge at seed 506719008 even without the fix (three runs each way, identical but for wall times). It reseeds per Raid, and the double touch is rare there. It goes through the same bolt code, so the fix covers it.

## Acceptance criteria

- [x] (agent) Two same-seed runs shown differing, and each cause shown with evidence.
- [x] (agent) Each cause fixed where it starts, with no check weakened.
- [x] (agent) A cheap regression check that fails without the fix.
- [x] (agent) `tests/run_all.sh only=crew seed=506719008` three times gives identical output apart from timings; the full gate passes twice; `only=raid_smoke seeds=20` passes once.

## Evidence

- Reproduction (diagnostics, not committed): the `randi()` trace after each check, plus traces in `SoundAt.play`, `Crew3D._ready` (seed and instance id), `PirateAudio._play` and `Projectile3D` (each strike: sweep or entered, body, position, direction). Six runs side by side on `97558be` plus the traces: crew `_ready` ids differed from frame 93 (`id=151649258379` against `151649258380`). The first behaviour difference was a dropped Pirate hit (`PATRACE f=21760 hit` missing in run 2), then a different crew seed at frame 22061 (`4014265806` against `90669402`). With the strike traced: at frame 11954 one bolt reported `entered Floor` then `entered Player` in one run and the reverse in another, at the same position and direction (508.5171, 0.004257, 8.715764). It struck whichever came first. In `_check_shotgun_range`, the same player RNG state, origin and aim point gave 52 damage in one run and 65 in another (4 pellets against 5).
- With both fixes and the traces still in: six crew runs side by side were identical once instance ids and node names were masked; the Floor/Player order still changed run to run, but the struck body did not. With the id tiebreak put back and only the bolt fix in: six crew runs and three smoke runs were identical as well. So at this seed cause 2 was latent. It is fixed because the ids it read were shown to differ.
- Regression check `tests/test_crew.gd::_check_replays` (in `crew`, 4 checks, under 0.1 s). It calls `_on_body_entered` on a bolt born on the floor inside a Guard's capsule, once telling it of the Floor first and once of the Guard first; it must strike the Guard both times. Then two crew in an empty Room, the one readied first instantiated second (so with the lower id last): it must be the one that acts. A precondition asserts both can get past, so the check bites. Without either fix, at seed 506719008: `FAIL replay: a bolt on the floor inside a Guard, told of the Floor first, struck ["Floor"]; want the Guard either way` and `FAIL replay: of two crew blocking each other, the one readied first (instantiated second) acts false, the other true; want only the first`, `FAILED 2 of 430 checks`. With the fixes: `PASS 430 checks`. A same-process twice-run trace was not used: the Jolt race is a thread race and would not fail reliably without the fix.
- `_check_time_to_die` medians, before and after (fixed per-run seeds): Pistol 9.56 s and Assault Rifle 5.68 s, the same.
- `tests/run_all.sh only=crew seed=506719008` three times on the final code, every run `crew awareness: PASS (430 checks, 66-67 s)`. The logs are identical apart from the wall times.
- Full gate on the final code: seed 788379062, every suite PASS (static 181, generator 358259, layouts 252, ship_3d 3718, pirate 2402, crew 430, sandbox 490, attachments 1674, raid_smoke 1104), 359 s. Seed 144619545, every suite PASS with the same counts, 331 s.
- `tests/run_all.sh only=raid_smoke seeds=20`, seed 120245782: `PASS (4379 checks, 836 s)`, 20/20 quiet, loud and caught on every Class.

## Owed to playtest

None: no `(human)` criteria.

## Comments

2026-11-26: diagnosed and fixed by a subagent in its own worktree on branch `fix/exact-seed-replay`, from `97558be`, for cherry-picking onto `crew-combat`.
