Status: resolved
Blocked by: 02

# Reproducible runs

## Parent

`.scratch/agent-verification/spec.md`, build order 5 of 9.

## What to build

Any failing check can be replayed exactly, and the gate does not flake.

- **Audit randomness.** 18 scripts outside `scripts/proto/` use `randi`/`randf`/`randomize`/`RandomNumberGenerator` (generator, crew routine and combat, player, raid, audio, menu backdrop among them). The generator is already seed-driven. For the rest, list each draw and whether it affects simulated behaviour (crew decisions, spread, timings) or only presentation (sound variation, backdrop).
- **Seed the behaviour draws.** Behaviour draws come from an RNG that a test can seed: either the global one via `seed()` at suite start, or an injected `RandomNumberGenerator` where a script already owns one. Choose the smaller change per script; do not restructure game code beyond that.
- **Suites take `seed=<n>`** and print the seed in use at the start and again on any failure, with the exact command that replays it.
- **Fixed step.** Suites that advance physics run with a fixed frame step (Godot's `--fixed-fps`, set in `run_all.sh`), so timing checks do not depend on machine load.
- **Flake hunt.** Run the full gate 10 times in a row. Any check that fails in some runs and not others is fixed or its cause recorded in the ticket.

## Acceptance criteria

- [x] (agent) The audit table (script, draw, behaviour or presentation) is in this ticket's `## Evidence`.
- [x] (agent) Running a behaviour suite twice with the same `seed=<n>` prints identical check results; shown for `tests/test_crew.gd` and `tests/test_pirate.gd`.
- [x] (agent) A forced failure prints the seed and a replay command, and that command reproduces the failure.
- [x] (agent) 10 consecutive full gate runs all pass; the run log tail is in the evidence.
- [x] (agent) `docs/agents/paperclip.md` documents `seed=<n>` and the replay line.
- [ ] (human) A play session shows no change in how crew or weapons behave.

## Evidence

- **Audit table.** Every `randi`/`randf`/`randomize`/`RandomNumberGenerator`/`pick_random` use outside `scripts/proto/` (18 scripts; found with `grep -rnE 'randi|randf|randomize|RandomNumberGenerator|seed\(|shuffle|pick_random'`). "Global" is Godot's global RNG, which the engine randomizes at launch and a suite fixes with `seed(n)`.

  | Script | Draw | Behaviour or presentation | Reproducible from |
  | ------ | ---- | ------------------------- | ----------------- |
  | `scripts/gen/ship_generator.gd` | own RNG: Room count, richness, area target; passes it to the generator modules below | behaviour (the ship) | `rng_seed(class, seed, attempt)`; already seed-driven |
  | `scripts/gen/hull_grammar.gd` | archetype, aspect, masses, bands, skeleton | behaviour | generator RNG |
  | `scripts/gen/room_packer.gd` | Room sizes, filler roles, chain doors, pods | behaviour | generator RNG |
  | `scripts/gen/role_assigner.gd` | Role counts, small-ship Armory chance | behaviour | generator RNG |
  | `scripts/gen/role_flavour.gd` | console count per Role | behaviour (props) | generator RNG |
  | `scripts/gen/door_stitcher.gd` | which Door to open | behaviour | generator RNG |
  | `scripts/gen/hatch_placer.gd` | Hatch count, spot, shuffle | behaviour | generator RNG |
  | `scripts/gen/interiors.gd` | islands, Container runs, consoles, cryopod rows | behaviour (props, cover) | generator RNG |
  | `scripts/gen/ship_namer.gd` | own RNG: prefix, shape, words of the ship's name | presentation | seeded from the ship's seed; already reproducible |
  | `scripts/crew/crew.gd` | own `_rng`: Guard burst size; burst gap, reload and cover-hold jitter; Routine plan; start delay and chat cooldown; hold, shot and glance timers; hide chance; wander Room; chat chance and length; shot spread; random tile | behaviour | **changed:** `_rng.randomize()` became `_rng.seed = randi()` (global) |
  | `scripts/crew/crew_routine.gd` | Job count, Rooms, durations, start index | behaviour | the crew member's `_rng` |
  | `scripts/crew/crew_combat.gd` | `jitter()` | behaviour | the crew member's `_rng` |
  | `scripts/crew/crew.gd:1150` | `shot_streams.pick_random()` | presentation (which shot sound) | global |
  | `scripts/crew.gd` (2D) | own `_rng`: patrol choice, hold timers, spread, random tile | behaviour | **changed:** `_rng.randomize()` became `_rng.seed = randi()` (global) |
  | `scripts/player_3d.gd` | own `_rng`: shot scatter yaw and pitch | behaviour (spread) | **changed:** `_rng.seed = randi()` (global) added to `_ready`; it was seeded at random by the constructor |
  | `scripts/pirate_audio.gd` | `pick_random()` of step, shot, melee, land, hit streams | presentation | global |
  | `scripts/pirate_audio.gd` | own `_rng`: pitch spread | presentation | not seeded (constructor-random); nothing asserts on pitch. Left alone |
  | `scripts/sound_at.gd` | pitch spread | presentation | global |
  | `scripts/raid.gd` | a new Raid's seed in `Raid.start` | behaviour (which ship) | global; suites set `Raid.seed` directly |
  | `scripts/ui/menu_backdrop.gd` | own `_rng`: backdrop ship seed, hull shading and deck clutter | presentation | seeded from its `seed` export or a global `randi()` |

  No behaviour draw needed more than a one-line change. The three changed lines keep game behaviour the same: the engine randomizes the global RNG at launch (checked: two bare runs printed `randi()` 658463059 and 4274762917), so each crew member and the Pirate still get a fresh random seed every game.
- **Same seed, same results** (crew and pirate). `tests/run_all.sh only=pirate,crew seed=4242`, twice: the two outputs differ only in wall times (`diff` shows lines `pirate ... PASS (597 checks, 3 s)` vs `4 s` and the `total:` line). Both print `seed: 4242`, `PASS  597 checks`, `PASS  88 checks`. The draws themselves replay too: the forced failure below carries a crew member's position after the 3600-frame Routine run, and it came out identical to the last digit on every replay.
- **Forced failure prints the seed and a replay command that reproduces it.** A temporary check added at the end of `tests/test_crew.gd::_initialize` (removed afterwards), failing with sim-derived values: `_expect(false, "FORCED: probe at %s, burst_gap %.5f, job %d" % [...])` on the first Routine crew member. `tests/run_all.sh only=crew` printed:
  ```
  seed: 451195380
  FAIL  FORCED: probe at (63.56942, 0.000023, 43.39051), burst_gap 0.13663, job 1
  FAILED  1 of 89 checks
  seed: 451195380  replay: tests/run_all.sh only=crew seed=451195380
  crew awareness: FAIL (exit 1, 89 checks, 10 s)
      replay: tests/run_all.sh only=crew seed=451195380
  ```
  Running the replay command printed the same `FAIL  FORCED: probe at (63.56942, 0.000023, 43.39051), burst_gap 0.13663, job 1`. `seed=12345` gave `probe at (64.45939, 0.000873, 8.825363), burst_gap 0.10695, job 2`, so the values follow the seed. Mechanism: `tests/suite_seed.gd` (`SuiteSeed.pick`, `SuiteSeed.replay_line`), called first in `_initialize` and in `_report` of `test_layouts.gd`, `test_ship_3d.gd`, `test_pirate.gd`, `test_crew.gd`; `tests/run_all.sh` rolls the seed, passes `seed=` to those four and adds the `replay:` line under a failing suite.
- **10 consecutive full gate runs pass.** `tests/run_all.sh` ten times in a row, each on its own rolled seed (329917388, 6355278, 338274066, 363967179, 8105714, 851098476, 821482350, 829751331, 284170239, 549616138): all exit 0, 60 of 60 suite lines PASS, check counts the same in every run (generator 341833, layouts 252, ship_3d 3646, pirate 597, crew 88; static 123 in runs 1–8 and 125 in 9–10, because someone else's `scripts/proto/` files were swapped mid-hunt). Each run 65–68 s. Tail of the log:
  ```
  ##### run 10
  exit 0
  seed: 549616138
  === summary
  static load check: PASS (125 checks, 3 s)
  generator sweep: PASS (341833 checks, 41 s)
  2D layouts: PASS (252 checks, 1 s)
  3D ship and built sample: PASS (3646 checks, 8 s)
  pirate movement and gunplay: PASS (597 checks, 3 s)
  crew awareness: PASS (88 checks, 10 s)
  total: 66 s
  profile after: 2026-11-22 09:30:39.086131236 -0500 79590aa343469657984b730bdcf4cba1  -
  ```
  No check failed in any run, so no flaky checks were found.
- **`docs/agents/paperclip.md` documents `seed=<n>` and the replay line**: new "Seeds and replay" subsection under Gate (the replay line, `seed=` on `only=` and full runs, the fixed frame step); the bare-run command now carries `--fixed-fps 60` and `seed=<n>`; timings table re-measured.
- **Fixed step (`--fixed-fps 60`), what it does here.** In 4.7 it switches off real-time sync: every main-loop iteration is one 1/60 s physics tick plus one process frame. Without it the suites were paced in real time (a 3600-frame loop took 60 s of wall time) and `_process` code (Viewmodel, Alarm, Awareness markers, Extraction) got whatever real deltas the machine produced. With it, every check passed unchanged, the gate went from 325 s to 65 s (pirate 123 s to 3 s, crew 91 s to 10 s, ship_3d 39 s to 9 s, layouts 30 s to 1 s), and the same seed replays exactly. On an idle machine the crew forced-failure values also replayed exactly *without* it (crew logic is all in `_physics_process`); the step is what guarantees it under load. One side effect, fixed in the harness: the suite now outruns the real-time audio mixer, so the pirate suite quit with sounds mid-play (`ERROR: 6 resources still in use at exit`); `test_pirate.gd::_silence` stops every player and waits 300 ms before quitting.
- **Real profile no longer written.** Diagnosis: all six suites were run one by one with Godot's user dir pointed at a sentinel copy (`XDG_DATA_HOME` inside the flatpak); no suite touched it. `ship_3d` already redirected `Profile.path`; `pirate`, `crew`, `layouts` and `static` never reach `Profile`. The writer was `tests/shots.gd`: the real `profile.cfg` mtime is 09:30:39 today and `tests/shots.gd` was rewritten 18 s later (09:30:57) to raise the menu preset's death screen by hand, which suggests an earlier version settled a real death (+100 XP, one kill). `tests/shots.gd` never redirected `Profile.path`; it now banks into `user://shots_profile_<pid>.cfg` and deletes it at exit (checked: `tests/shots.sh menu` PASS, `home.png` shows "LEVEL 1 · 0 / 500 XP · 0 GOLD IN THE HOLD", real profile unchanged). `RaidChecks.TEST_PROFILE` became `RaidChecks.test_profile`, named per process, because every worktree shares one `user://` dir and two concurrent `ship_3d` runs would have banked into the same file. Proof across the ten gate runs and the shots run: real `profile.cfg` mtime `2026-11-22 09:30:39.086131236` and md5 `79590aa343469657984b730bdcf4cba1` before and after; the user dir holds only `logs objectdb_snapshots profile.cfg shader_cache vulkan` (no test profiles left).

## Owed to playtest

- [ ] (human) A play session shows no change in how crew or weapons behave.

## Comments

2026-11-22: built by a subagent. The orchestrating session read the three one-line game-script changes, re-ran the full gate (all PASS, 66 s) and confirmed the real `profile.cfg` mtime did not move. `--fixed-fps 60` cut the gate from 325 s to about 65 s. The real-profile writer was an early version of `tests/shots.gd` (ticket 04), not a gate suite; it now redirects `Profile.path`.
