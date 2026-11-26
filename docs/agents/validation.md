# Validation

How to check that what was built is correct and matches its ticket: every
validation tool in this repository, how to run it, and what it proves. Read
this before building or reviewing anything. All commands run from the
repository root; Godot is the flatpak `org.godotengine.Godot`, and a fresh
worktree needs the one-off import first (Setup in `docs/agents/paperclip.md`).

## Quick reference

| To check | Run | Time |
| -------- | --- | ---: |
| Everything, the gate | `tests/run_all.sh` | about 150 s |
| Only the suites covering what you touched | `tests/run_all.sh only=<suite>[,<suite>]` | 1–90 s |
| Every script, scene and resource loads | `tests/run_all.sh only=static` | 2 s |
| A failure again, exactly | the `replay:` command the failing suite printed (`seed=<n>`) | |
| Whole Raids end to end | `tests/run_all.sh only=raid_smoke` (`seeds=10` or `seeds=20` for the wide sweep) | 80–90 s |
| How the game looks | `tests/shots.sh <preset>`, then read the PNGs against the defect checklist | 2–10 s |
| One-off state or behaviour | a scripted headless run (see "Scripted runs") | |
| That a ticket matches its spec | one evidence entry per `(agent)` criterion (see "Evidence") | |

The validation loop for a ticket:

1. While building, run the fast loop for the code you touch, and add checks
   in `tests/` for the new behaviour.
2. If the change can be seen, take screenshots and read them.
3. Before finishing, run the full gate.
4. Record evidence for every `(agent)` acceptance criterion in the ticket.

## Evidence

The ticket's `(agent)` acceptance criteria each need an evidence entry before
it closes; see "Acceptance criteria and evidence" in
`docs/agents/issue-tracker.md` for the format and the reviewer rule.

## The gate

Must pass before a pull request is opened, from the repository root:

```sh
tests/run_all.sh
```

It runs the static load check first (`tests/test_static.gd`: every `.gd`,
`.tscn` and `.tres` outside `addons/`, `.godot/`, `tools/` and hidden
directories loads, and each scene instantiates; about 2 s), then the
behaviour suites. A suite fails on a non-zero exit, on a missing suite file
(`FAIL (missing ...)`), or on any `SCRIPT ERROR:` or line starting `ERROR:` in
its output that is not on the `ALLOWED` list in `run_all.sh`, even if Godot
exited 0. Each summary line carries the suite's check count; a count far below
the last run means checks stopped running. An error a check provokes on
purpose goes on `ALLOWED` as an exact pattern with a comment naming that
check; any other error gets fixed.

**Only the full `tests/run_all.sh`, with no `only=` and no `seeds=`, is the
gate.** A fast-loop pass is not evidence that a ticket is done.

New behaviour gets its checks in `tests/`, added to `tests/run_all.sh` when it
is a new suite.

## Fast loop

While working, run only the suites that cover the files you touched (see the
coverage table below), with the same strictness and summary as the gate:

```sh
tests/run_all.sh only=crew                  # one suite
tests/run_all.sh only=generator,layouts     # several, run in the gate's order
tests/run_all.sh only=generator seeds=10    # other args still reach the generator sweep
tests/run_all.sh only=raid_smoke seeds=20   # and the smoke run: 20 ships per Ship Class
```

Suite names are the file stem without `test_`: `static`, `generator`,
`layouts`, `ship_3d`, `pirate`, `crew`, `sandbox`, `attachments`, `raid_smoke`. An unknown or empty
name stops the run with exit 2 and the list of known names. `seeds=10`
narrows the generator sweep for a quick look, but its distribution checks
then run on too few seeds to be a verdict; the same `seeds=<n>` sets how
many ships per Ship Class the smoke run plays (default 5, so `seeds=20` is
the wider sweep). The smoke run also takes `class=`, `ship=` and `script=`
to replay one Raid; its failure lines print the exact command. A suite can also be run bare, without the runner's error
filter: `flatpak run org.godotengine.Godot --headless --fixed-fps 60 --path . --script res://tests/<suite>.gd -- seed=<n>`
(leave out `--fixed-fps 60` and the run is paced in real time and no longer
matches the runner's; see below).

## Seeds and replay

Every behaviour draw (crew decisions and timing jitter, Routines, shot
spread for crew and Pirate) comes from Godot's global RNG or from an RNG
seeded off it, so one seed fixes a run. The runner rolls a seed per run and
prints `seed: <n>` first; `layouts`, `ship_3d`, `pirate`, `crew` and
`raid_smoke` each seed the global RNG with it at start (`tests/suite_seed.gd`)
and print it again (`raid_smoke` also rolls its ships from it, and reseeds
per Raid from it, so each Raid replays on its own). A failing suite prints,
after its `FAILED` line and again under its summary line, the command that
replays it exactly:

```sh
seed: 451195380  replay: tests/run_all.sh only=crew seed=451195380
```

```sh
tests/run_all.sh only=crew seed=451195380   # same seed, same draws, same failure
tests/run_all.sh seed=451195380             # the whole gate on one seed
```

`seed=` takes a positive integer (anything else exits 2). `generator`
ignores it (its seed corpus is fixed, and each failure names its ship seed)
and `static` draws nothing.

Those five suites run with `--fixed-fps 60`, set in `run_all.sh`: each frame
is exactly one 1/60 s physics tick and one process frame, with no real-time
sync. `_process` code (the Viewmodel, the Alarm, Awareness markers) then sees
the same deltas on every run whatever the machine load, so a seed replays to
the same float positions, and the suites run as fast as the CPU allows. The
audio mixer still runs in real time, so a suite that plays sounds stops them
before it quits (`test_pirate.gd::_silence`).

## Timings

Timings, measured 2026-11-22 on the local machine (NVIDIA RTX 5080 box) over
ten full `tests/run_all.sh` runs on rolled seeds, all passing; the runner prints each suite's wall time in its
summary line and the total at the end, so a later run shows drift:

| Suite (`only=`) | File | Checks | Wall time |
| --------------- | ---- | -----: | --------: |
| `static` | `tests/test_static.gd` | 125 | 2 s |
| `generator` | `tests/test_generator.gd` | 357186 | 49 s |
| `layouts` | `tests/test_layouts.gd` | 252 | 1 s |
| `ship_3d` | `tests/test_ship_3d.gd` | 3681 | 9–10 s |
| `pirate` | `tests/test_pirate.gd` | 597 | 3–4 s |
| `crew` | `tests/test_crew.gd` | 325 | 28–40 s |
| `attachments` | `tests/test_attachments.gd` | 1674 | 6 s |
| `raid_smoke` | `tests/test_raid_smoke.gd` | about 920 | 75–105 s |
| full gate | `tests/run_all.sh` | | 145–176 s |

The `generator` row was re-measured on 2026-11-25 after the gun roll checks
(ticket `.scratch/crew-combat/issues/15-gunnery-per-weapon-and-the-gun-roll.md`),
which generate 100 more large ships for the gun shares. The `crew` row was
re-measured on 2026-11-25 over eight passing runs after the cover checks
(ticket `.scratch/crew-combat/issues/18-guards-find-hold-and-peek-from-cover.md`),
which add about 9 s of simulated fights, and again on 2026-11-25 over
nine passing runs after the fair fire checks
(ticket `.scratch/crew-combat/issues/19-fair-fire.md`), whose median time to
die runs twenty Pirates and Guards side by side for up to 60 s per gun. The
habit checks (ticket `.scratch/crew-combat/issues/20-a-habit-per-gun.md`)
add about 2 s (352 checks).
The `crew`, `raid_smoke` and full gate rows were re-measured later on
2026-11-22 over twenty passing full gates after the crew give-way fix
(ticket `.scratch/raid-smoke-bugs/issues/06-crew-block-each-other.md`),
some of them while a second worktree ran Godot on the same machine, which
likely accounts for the top of each range.

The smoke run and the generator sweep are the slow ones. The physics suites
run on the fixed frame step (see "Seeds and replay"); before it they were
paced in real time and the gate took 325 s. The smoke run's check count
moves a little from run to run (its ships are rolled from the seed, and a
Raid's check count depends on how it ended); its default of 5 ships per Ship
Class (45 Raids) is the gate, and `seeds=10` (about 3.5 minutes) or
`seeds=20` (about 7 minutes) is the wider sweep for a change that touches
the Raid loop.

## Smoke run

`raid_smoke` plays whole Raids with a scripted Pirate (Quiet, Loud,
Caught; the rules are in the suite's header). Crew are meant to be
dangerous, so the verdict never asks the bot to win: a Raid where it is
seen into an Alarm or shot down is legitimate. Every Raid carries a fitted Loadout (the Assault Rifle
with a Suppressor and a Drum, in hand, and the Shotgun with a Short Barrel),
given through `Raid.arm` as a Raid from the menu gives it. Every Raid is played once
(no second draw, no workarounds, no `NOTE` lines) and judged on:

- **Invariants, strict on every Raid:** no engine error; the Pirate never
  leaves the Hull or drops below the floor; no crew member walking to a Job
  goes 40 s without moving 1 m; no Guard fighting from cover stays down
  with the Pirate in its sight longer than its longest time down
  (`CrewCover.longest_down`: its Gunnery's time-down ceiling plus 30 %, plus
  the 0.8 s near-miss hold) plus 0.5 s since it got down or last ducked a
  near miss, leaving out time spent waiting on its gun's habit
  (`CrewCover.waited`: a Shotgun holding fire with him beyond 8 m, or a
  Marksman Rifle waiting for a true-aim place, at most two doubled
  handovers, 3.2 s; crew-combat ticket 20), or tries to walk 5 s without
  moving 0.3 m (a second standing
  still starts the count again); these replaced the old limit on time in
  COVER (crew-combat ticket 18), since a dug-in Guard now rightly holds a
  spot as long as the fight lasts; none puts 4 shots (a Shotgun's 12 pellets count as one) in a
  row into the ship within 2 m of its own muzzle (longest streak seen 2);
  the HUD offers a Door's prompt only with the Pirate in a Door's reach,
  and shows the Alarm banner exactly while the Alarm is raised; at a
  Container in reach the HUD offers the search and the interact key
  searches it (no `search()` fallback), and the Loot line shows the gold;
  the Raid reaches an end state (extracted, or the Pirate down) in its
  budget.
- **Ending consistency, whatever the ending:** the ledger's kills equal the
  crew down; the HUD's spotted stings equal the crew that tipped into
  spotted; extracted means EXTRACTED on the end screen, the HUD hidden, the
  gold carried banked and on the tally, the ledger's XP banked, the Ghost
  bonus on the tally if and only if the Alarm was never raised; down means
  YOU DIED, the HUD hidden, no gold banked and only the kill XP. Caught must
  go down without firing, every Raid (330 of 330 did).
- **Sweep floors**, on a full sweep only (no `class=`, `ship=`, `script=`),
  counting only Raids that passed: at least 60% of Quiet Raids end in a
  Ghost Extraction (measured 97%, lowest sweep 28 of 30), at least 60% of
  Loud Raids extract with a kill (98%, lowest 29 of 30), at least 70% of
  Quiet and Loud Raids bank Loot (lowest 58 of 60), and at least 40% of
  each Ship Class's Quiet and Loud Raids reach their ending (lowest 9 of 10
  in a sweep, 3 of 5 in a default run). Measured 2026-11-22 over eleven
  `seeds=10` sweeps (330 Raids per script). A broken Extraction or banking
  path gives 0. The run prints an `endings` line per script and a `floor:`
  line per floor; a floor failure lists the Raids that missed, with their
  replays.

Mutation proof (2026-11-22, default seeds, run seeds 101 and 202; ticket
`.scratch/agent-verification/issues/06-whole-raid-smoke-run.md`): the smoke
run fails on the Door prompt bug, crew routing round props off, a broken
Extraction and gold not banked on both seeds, and on `COVER_GIVE_UP` or the
muzzle-line check disabled on both seeds but by one or two Raids each; it
does not catch the blocked-crew facing fix disabled, which `crew`
(`_check_blocked_by_pirate`) does. `crew` also catches the cover and muzzle
mutations (`_check_cover_blocked`, `_check_muzzle_blocked`).

Mutation proof for the cover fight's invariants (2026-11-25, ticket 18):
a Guard that never peeks (`CrewCover._start_peek` always staying down)
fails the smoke run on `class=small seed=101` ("stayed down 3.9 s with him
in its sight, longer than 3.40 + 0.5 s"); a Guard that never gives up a
spot it cannot reach passes the smoke run (seed 202: no Guard was boxed
out of its spot) and fails `crew` (`_check_cover_blocked`). The bot aims
under the top of a crew member's body as it is now (`_chest`), so a Guard
down behind cover is not a target it fires over forever.

Game bug it used to fail on (fixed 2026-11-22, ticket
`.scratch/raid-smoke-bugs/issues/06-crew-block-each-other.md`): two crew
blocking each other (head-on in a doorway, or one stood in the other's way)
so neither got past for 40 s, about one gate in twelve. Its replay,
`tests/run_all.sh only=raid_smoke seed=4444 seeds=10 class=large ship=739174378 script=loud`,
now passes; `crew` covers the rule (`_check_head_on_doorway`,
`_check_standing_in_gap`).

Game bug it used to fail on (fixed 2026-11-25, ticket
`.scratch/raid-smoke-bugs/issues/09-kill-in-the-last-step-of-extraction.md`):
"the ledger counts 1 kills with 2 crew down" on a Quiet Raid, seen in two
`seeds=20` sweeps. The bot fires during the extraction countdown; a
bolt that felled a crew member in the physics step the pod cast off in had
its hit report still waiting out `SHOT_REPORT_DELAY` when the ledger
settled, so the kill was dropped. It showed only inside a sweep because a
Raid started mid-sweep runs its physics one frame ahead of its countdown
compared with the same Raid replayed alone, which put the kill on that last
step; the alone replay passes either way. Its sweeps,
`tests/run_all.sh only=raid_smoke seeds=20 seed=888720613` and
`seed=188082639`, now pass; `ship_3d` covers the rule
(`RaidChecks._check_kill_as_he_extracts`).

## Coverage

Which suite to run for which code. Standard applied: a suite **covers** a file
when one of its checks asserts on that file's behaviour, directly or through
the public entry point it serves (the Room packer through the
`ShipGenerator` output that `ShipInvariants` checks, `MenuStyle` through the
menu buttons `RaidChecks` asserts on). Being loaded by `static`, or run
inside a suite with nothing asserted about it, does not count. `static`
covers every file below for loading and is left out of the table.
Helper files fold into the suite that calls them: `tests/raid_checks.gd`,
`tests/generated_ship_checks.gd`, `tests/two_rect_room_checks.gd` and
`tests/built_sample_checks.gd` run inside `ship_3d`; `tests/loadout_checks.gd` and `tests/loadout_screen_checks.gd` run inside `pirate`; `tests/room_data_checks.gd`
runs inside both `layouts` and `ship_3d`. Verified 2026-11-22 by grepping the
suites and helpers for each script's class name and `res://` path, then
reading the checks that use it.

| Code | Suites | What asserts on it |
| ---- | ------ | ------------------ |
| `scripts/crew/` | `crew`; `ship_3d`, `pirate`, `raid_smoke` in part | `crew`: Awareness, hearing, routines (`CrewRoutine`), Guards and Workers (`CrewTypes`; a cornered Worker unarmed, never firing in 30 s and cowering), each weapon's `Gunnery` file and a Guard firing each gun (pellets, projectile, bursts, time down),  the Alarm and Alarm panels, fair fire (`CrewFire`: `_check_exposure_ramp` 3x to 1x over 2 s, held while it ducks, 3x again on broken sight and on a hit; `_check_walk_in`; `_check_true_aim`, five Guards for 20 s with at most two aiming true in any frame and one whenever any has a clear muzzle line, and every miss 0.4 to 0.8 m off his body centre; `_check_miss_at_cover`; `_check_lead`, the intercept fraction per gun, halved mid Slide, every pellet inside a real cone; `_check_pellet_cap`, 117 of 150 from 12 pellets, and the four crew fight numbers on the Sandbox; `_check_time_to_die`, the median of 20 fixed-seed runs per gun, and no bolt into the crate a Guard fires over), combat (a cover spot it cannot reach, holding fire with the muzzle line blocked), fighting from cover (`CrewCover`: `_check_cover_ring` hidden within 6 s by a fair walk, low cover fired from, the capsule lowered, 20 peeks of each gun's shots per burst and time down; `_check_full_cover`; `_check_flanked_and_closed_on`; `_check_open_fight`; `_check_cover_fight_on_ship`, 60 s of three Guards on a generated medium ship with none stuck, no shared tile, none beside a Breaker), a habit per gun (`CrewHabit`, ticket 20: `_check_bands`, each gun's cover tile inside its band within 1 m after 20 s in a 14 x 10 m Room; `_check_shotgun_holds_fire`, no shot at 10 m in 10 s, a shot at 6 m; `_check_shotgun_ambush`, in ambush within 5 m of the doorway and out of his sight within 10 s by a fair walk; `_check_shotgun_rack`, the action sound 0.2 to 1.0 s before every shot popping up and stepping out; `_check_sight_line`, the line shown from 0.9 s (within 0.1 s) before each perched shot, aimed at a still Pirate, missing a 1.5 m sidestep in the last 0.15 s, no shot when hit during it; `_check_marksman_waits_for_place`, nothing fired while both true-aim places are held by others and a shot within 2 s of one freeing; `_check_marksman_small_room`, cover and a shot within 6 s in a 6 x 6 m Room, its tile held 20 s with him hidden, and from the hip with him at 4 m: no line, twice its base cone; `_check_marksman_falls_back`, on a further perch within 5 s with him at 4 m), steering round props and bodies (`CrewPaths`), two crew blocking each other (one gives way), one crew member per work spot, bodies and traces (`CrewTraces`). `ship_3d`: crew spawn, shooting and death on a built ship. `pirate`: crew models and the crew shot. `raid_smoke`: whole Raids against the crew: a Guard killing a Pirate who stands in view, no crew member stuck on its way to a Job, no Guard fighting from cover stuck down with him in sight past its longest time down or stuck walking, none emptying bolts into cover at its muzzle, the HUD's spotted stings matching the crew that tipped into spotted, kills matching the crew down, and across the sweep enough Quiet Raids unseen into a Ghost Extraction |
| `scripts/data/` | `layouts`, `ship_3d`, `generator` | `RoomDataChecks` (in `layouts` and `ship_3d`): Room rects, fight core, floor rule, Corridor width, display name. `generator`: every `ShipLayout` it emits through `ShipInvariants` |
| `scripts/gen/` | `generator`; `ship_3d` in part | `generator`: the sweep, distributions, determinism and `ShipInvariants` (with its self-test) over everything `ShipGenerator` calls. `ship_3d`: generated ships built in 3D, `ShipNamer` prefixes, `Interiors` props in the built sample. `generator` also checks `ShipDumper` (`_check_dumper`: glyph set, one listing line per Room and Door). **Uncovered:** `dump_ship.gd` (command-line wrapper, debug output only; loaded by `static`, run by hand in ticket `.scratch/agent-verification/issues/10-ship-dumper-checks.md`) |
| `scripts/layouts/` | `layouts`, `ship_3d` | `PlayerShipLayout` is the built sample both suites walk |
| `scripts/ship/` | `ship_3d` (3D), `layouts` (2D); `generator` for `GunRoll` | `generator` (`_check_guns`, `_check_gun_shares`): `GunRoll`'s caps on every swept ship (no Marksman Rifle on a small ship, at most 1 on a medium and 2 on a large, never two in a Room, no Room of three or more Guards all Shotguns, a gun for every Guard and none for a Worker) and each gun's share of the Guards on 200 large ships at Richness 1.0 within 5 points of the weights' prediction. `ship_3d` (`GeneratedShipChecks._check_guns`): every built Guard holds a rolled weapon and its Gunnery, no Worker either, and the same layout built again, or after extra global random draws, gives the same guns. `ship_3d`: `ShipBuilder3D` geometry, `BoardingPod`, `RoomReveal`, `RoomTracker`, `ShipNavigator`. `layouts`: `ShipBuilder` and `RoomFog`. `crew` builds on `ShipBuilder3D` too. `ship_3d` also checks `HazardStripes` (texture, material, and on sealed Hatches and the Boarding Pod collar) |
| `scripts/ui/` | `ship_3d`, `pirate`, `crew`, `raid_smoke` | `ship_3d` (`RaidChecks`): `MainMenu`, `MenuBackdrop`, `PauseMenu`, `RaidEndScreen`, `MenuStyle`, the `Hud` hidden on death. `pirate`: `Hud` crosshair, ammo, dry click, hit markers. `pirate` (`tests/loadout_screen_checks.gd`): the `LoadoutScreen` from the menu's Loadout button (the home list's order, the places and the swap, "no Slot" tags, a Slot's list, the bars and their colours against the bare gun, the bench gun's Attachments and materials, drag and double click, the keyboard alone, a fitted Drum carried into a Raid) and `WeaponAttributes` (every Attachment's line made from its changes). `crew`: `AwarenessMarkers` (colours, and a bar only with a clear line from the camera, `_check_bar_behind_walls`). `raid_smoke`: the `RaidEndScreen` heading and tally on both endings (gold banked or left behind, XP, kills, the Ghost bonus if and only if the Alarm was never raised), the `Hud` hidden at the end, its Alarm banner every frame, Loot line, spotted stings and Door and search prompts, in whole Raids |
| `scripts/raid.gd`, `raid_ledger.gd`, `extraction.gd`, `profile.gd`, `loadout.gd` | `ship_3d`, `raid_smoke`, `pirate` | `RaidChecks`: levels, the ledger and Ghost bonus, a Raid's seed, pause, death, Extraction, banking to the Profile, a kill in the step the pod casts off in counted and banked (`_check_kill_as_he_extracts`). `raid_smoke`: the same end to end, a seeded Raid boarded, played and extracted from (or died on), with the XP and gold banked checked against the ledger on either ending, and sweep floors on Ghost Extractions, Extractions with a kill and Loot banked. `pirate` (`LoadoutChecks`): the `Loadout`'s default, set and swap of the two places, fitting, save and load in the profile file beside XP and gold, the stale-entry fallbacks, and a Raid from the menu carrying its two Built Weapons (keys 1 and 2, the wheel, a Retry carrying the same two). `raid_smoke` plays every Raid with a fitted Loadout given through `Raid.arm` |
| `scripts/main_3d.gd`, `door_3d.gd` | `ship_3d`, `raid_smoke`; `crew` for doors | the Raid scene, open and locked Doors, Hatches, boarding, a Door's prompt offered only to the Pirate in its reach (`test_ship_3d.gd::_physics_door_prompt`, with a crew member at a Door across the ship). `raid_smoke`: Doors and the boarding Hatch worked with the interact key, a Container searched with it (and the HUD offering the search there), a Door's prompt offered only with the Pirate in a Door's reach, checked every frame, the home door worked to extract |
| `scripts/container_3d.gd` | `ship_3d`, `crew`, `raid_smoke` | searching a Container (`RaidChecks`; the interact key searching one while crew stand at a distant Door, `test_ship_3d.gd::_physics_door_prompt`; `raid_smoke` with the interact key in a live Raid, failing if the key does nothing at a Container in reach), an emptied Container as a trace (`crew`) |
| `scripts/attachment.gd`, `resources/attachments/`, and the Slots, fits and `build` in `weapon_profile.gd` | `attachments`; `crew` in part | `attachments`: the fourteen Attachment files (Slot, name, factors, lens, Suppressor), each gun's Slots and what fits them, every gun with every Attachment it takes built against the catalogue's factors and limits, the Built Weapon numbers of `.scratch/weapon-attachments/issues/13-starting-numbers.md`, stacking, the suppressed shot per gun, building leaving the bare Profile and the Attachment files alone, and refusals. `crew`: a Laser's conspicuous on Awareness (`_check_conspicuous`), a suppressed shot's reach (`_check_suppressed`) |
| `scripts/player_3d.gd`, `viewmodel.gd`, `weapon_profile.gd`, `pirate_audio.gd`, `health.gd`, `projectile_3d.gd`, `sound_at.gd` | `pirate`; `ship_3d`, `raid_smoke`, `crew` in part | `pirate`: movement course, weapons and the wheel, ADS, melee, Viewmodel poses and clips, sounds, bolts, damage. `ship_3d`: walking, ammo and shooting on a built ship. `raid_smoke`: the Pirate never leaves the Hull or drops below the floor while walked through generated ships by input actions, and goes down under crew fire (Caught, every Raid). `crew`: a crew Shotgun shot's pellet cap (`Projectile3D.Volley`, `_check_pellet_cap`) and the Pirate's `in_slide_or_clamber` halving a Guard's lead (`_check_lead`) |
| `scripts/sandbox/` | `sandbox`; `crew` in part | `sandbox`: `docs/sandbox.md` against the resources (the stale check, a hand edit to a weapon, a Gunnery, the Sandbox or an Attachment file failing it), every table (the four weapon columns, the four weapon Gunnery columns with every Gunnery field editable, the fourteen Attachment columns with each file's factors), edit, Save and Revert over scratch copies (a factor too), and in Raids: F1 and Esc, live edits on the next shot, a menu Raid's Built Weapon values beside the bare ones, a dialled factor or bare number rebuilding the gun in hand (`WeaponProfile.rebuild`), and the debug Loadout strip applied on close without writing the saved Loadout. `crew`: the loudness row |
| `scripts/scoped_view.gd`, `resources/shaders/scope_lens.gdshader`, `scope_surround.gdshader`, the lens pose and render layer in `viewmodel.gd`, `view_zoom` and `aims_through_sight` in `weapon_profile.gd`, the crosshair hiding in `hud.gd` | `pirate`; `tests/shots.sh scoped` | `pirate` (`tests/scoped_view_checks.gd`): the Viewmodel on its own render layer and the lens camera leaving it out, the lens magnifying a 1 m target at 50 m by 5.01x (Long Scope) and 2.48x (Combat Scope) within 5% through the lens camera's own projection, the camera at 1.25x through a lens and at `ads_zoom` with the Reflex Sight and a gun's own sights within 2%, the mouse slowed by the lens's zoom within 2%, the eye 0.06 m from the rear glass within 2 mm, the lens camera rendering only aimed through a lens, the surround following the sights, the glass still covering the screen's middle with the gun 6 mm off, the Reflex Sight model's own dot gone, the HUD crosshair hidden only aimed through a Sight Attachment. `scoped` measures the reticle's centre and the target's span in pixels. Headless runs draw no pixels, so the look is the preset's |
| `scripts/laser_dot.gd` (the Laser's dot, `player.laser_dot`) | `pirate`; `tests/shots.sh attachments` | `pirate` (`tests/laser_dot_checks.gd`): the dot within 2 cm of where the gun's line from `Laser_Origin` meets a wall 5 m off, at the hip and aimed, on the Pistol, Assault Rifle and Shotgun; none facing open space, a wall at 32 m hidden and at 28 m shown; none without a Laser, while sprinting, clambering or swapping; a bare mesh with no collision, on a layer the scope's lens camera sees. `tests/shots.sh attachments`: the Laser builds' `_hip` shots show one red dot on the far wall and no beam |
| `scripts/weapon_model.gd`, the model fields of `attachment.gd`, `tools/blender/attachments.py` as imported under `assets/models/attachments/` | `pirate`; `tests/shots.sh attachments` | `pirate` (`tests/attachment_model_checks.gd`): all 34 gun-and-Attachment pairs show their model and hide the parts they replace, the Assault Rifle's muzzle with a Suppressor and a Long Barrel and the tracer from it, every Sight's (and the Shotgun Barrels' bead's) aim point on the camera axis when aimed, Magazines riding the magazine's bone through a reload, the Shotgun's Foregrip and Laser riding the pump and the Pistol's Reflex Sight the slide through a shot. `_check_viewmodel_materials` covers the Attachment meshes' material flags. Rebuilding the models needs Blender and is not part of the Gate |
| `tools/blender/` gun scripts and `kit.py`, as imported under `assets/models/` | `pirate`; `tests/shots.sh viewmodel` | `pirate` (`tests/gun_model_checks.gd`): each gun's separate part meshes and `<Bone>Mesh` names, the mesh each bone carries, the mount markers, Muzzle and sights within 1 mm of their recorded places, and the bones each clip moves. Rebuilding a gun needs Blender and is not part of the Gate |
| `scripts/main.gd`, `player.gd`, `crew.gd`, `door.gd`, `projectile.gd` (2D) | `layouts` | the 2D scene: Doors, shooting, crew, fog, navigation |
| `scripts/proto/` | none, by design | prototypes; excluded |

Uncovered areas each have a follow-up ticket; when one is built, move its row
here.

## Scripted runs and parallel runs

There is no display for agents. Logic is exercised headless; the look of the
game is checked from offscreen screenshots an agent reads itself.

- **Scripted runs:** a GDScript run with
  `flatpak run org.godotengine.Godot --headless --path . --script <file>` can
  load any scene or script through `res://`, drive its public functions and
  print or assert on state. QA keeps such scripts in its evidence directory and
  passes them by absolute path; nothing is added to the worktree.
- **Parallel runs:** headless runs share no ports, so two worktrees can run
  at once. Each worktree has its own `.godot/`, but every worktree shares one
  `user://` directory (`~/.var/app/org.godotengine.Godot/data/godot/app_userdata/Space Pirate/`,
  which also holds the player's real `profile.cfg`). Anything a test banks
  goes to a throwaway profile named per process (`RaidChecks.test_profile`,
  and `shots_profile_<pid>.cfg` for screenshots), deleted when the run ends.
  A new suite that can reach `Profile` (a Raid scene, the main menu, a
  `RaidLedger`) sets `Profile.path` the same way before anything else.

## Screenshots

`tests/shots.sh <preset> [args]` renders the game on the GPU inside
`gamescope --backend headless` (no window, no display) and saves PNGs under
`.godot/shots/<preset>/` (git-ignored), with Godot's output in `shots.log`
beside them. It exits non-zero if any frame the preset announced is missing or
empty, if a frame fails the automatic checks, or on a script error. Not part of
the Gate and not in `tests/run_all.sh`.

```sh
tests/shots.sh viewmodel                     # hip, ads, low, tracer
tests/shots.sh viewmodel wheel=1             # the same for the next weapon (Assault Rifle)
tests/shots.sh attachments                   # each gun bare and in two builds, side-on and at the hip
tests/shots.sh scoped                        # aimed through each scope's lens and the Reflex Sight, measured
tests/shots.sh ship class=medium seed=1      # room_<i>_<role>.png per Room, overview.png
tests/shots.sh crew                          # front.png, side.png: Guard left, Worker right; sight_line.png
tests/shots.sh hud                           # hud.png, hud_busy.png
tests/shots.sh menu                          # home, classes, loadout, loadout_slot, pause, death, extracted
tests/shots.sh sheet                         # sheet, sheet_attachments, sheet_attachments_end
tests/shots.sh scene path=res://scenes/props3d/prop_crate_3d.tscn cam=2,1.5,2 look=0,0.5,0
```

- **viewmodel:** the Pirate in a small lit test room with two crew ahead.
  Takes the Viewmodel's pose overrides `hip= ads= low= lowrot=` (x,y,z) and
  `pistol=1 scale= rot= pos=` to try a fresh pistol mesh.
- **attachments:** each of the four guns bare and in two full builds of
  Attachments (`BUILDS` in `tests/shots.gd`), mounted by the Viewmodel as in
  a Raid: `<gun>_<bare|a|b>_side.png` held side-on in front of the eye, barrel
  left, and `<gun>_<bare|a|b>_hip.png` in the hip pose, 24 frames. Between
  them the builds show every Attachment model but the Assault Rifle's
  Suppressor and Extended Magazine (the same models show on the other
  guns). Read each for a fitted part floating off its gun, a gap where a
  replaced part was, a part of the gun showing through its replacement, and
  the Shotgun's front sight only with its own barrel and no Sight. Scopes
  have dark glass here.
- **scoped:** the Pirate down a lit hall 90 m long with a pure blue board
  1 m wide at 50 m, aimed through the Long Scope (Marksman Rifle), the
  Combat Scope (Assault Rifle) and the Reflex Sight (Assault Rifle):
  `long_scope.png`, `combat_scope.png`, `reflex.png`, each again as
  `<name>_shifted.png` with the gun 6 mm off its aimed pose (down and
  right). Sights fully up, so the surround is at full strength. Beyond the
  automatic checks it measures each frame and prints `SHOT_MEASURE` lines,
  failing the frame (`SHOT_FAIL`) when the red reticle's centre (a centroid
  of red within 12 px of the middle) is more than 2 px off the screen's
  centre, or, in a lens, when the board's span along a row 5 px above the
  middle (in linear light, part-covered edge pixels counting by their
  share) is more than 5% off what the lens's zoom gives against the
  unaimed 75° view (47.0 px at 5.01x, 23.3 px at 2.48x on 720 px). The
  lens picture is 1024 px square, so a small target can be a texel wider or
  narrower: about 3.5% at 2.48x. Read each lens shot for a black wedge at
  the lens's edge, the scope's own tube seen inside the lens, and the
  surround not blurred or not dark at the corners; each Reflex shot for a
  clear window with one red dot and no second dot fixed to the gun.
- **ship:** the generated ship of that Ship Class and seed, fully lit with
  every crew member held at their post: one shot per Room (Corridors
  included) from the corner of its largest rect clearest of props, at eye
  height (1.6 m, 90° FOV) looking across to the opposite corner, then a
  top-down orthographic overview with the ceiling off and a sun added. The log
  prints `rooms=<n> counted=<n>` (all Rooms, and the Class count without
  Corridors) and warns `SHOT_WARN` when a camera starts inside geometry.
- **crew:** one of each crew type (Guard, Worker) side by side in the test
  room, facing the camera, then turned side-on; then `sight_line.png`, the
  Guard turned right with a Marksman Rifle's sight line (`CrewSightLine`)
  from its muzzle across the room: one thin red line, unshaded, starting
  just in front of the Guard's chest.
- **hud:** a Raid on small seed 1, the Pirate in his Boarding Pod, the HUD set
  to known values (health 2 short of full, ammo 5, Loot 240); `hud_busy` adds
  the Alarm, an XP toast and an empty magazine.
- **menu:** the main menu and Play's Ship Class screen, the Loadout screen
  (`loadout`: the default Loadout, the bare Pistol on the bench;
  `loadout_slot`: the Assault Rifle with a Combat Scope, Suppressor, Drum,
  Laser and Light Stock, its Underbarrel list open), then the pause, death
  and extracted screens over the same Raid. The preset uses a throwaway
  Profile, so the menu shows a fresh level 1 pirate and nothing is written
  to the player's own.
- **sheet:** the Sandbox sheet (F1) open over a Raid carrying the Assault
  Rifle with a Suppressor and a Drum, then the Pistol: the debug Loadout
  strip and the Weapons table with the Built Weapon values beside the bare
  ones, then the Attachments table top and bottom with the Suppressor's
  loudness dialled to 0.5 (amber). Nothing is saved; the dial is reverted.
- **scene:** any scene under `res://` from `cam=` looking at `look=`
  (`fov=`, `name=` optional), lit by the shot script when the scene brings no
  WorldEnvironment of its own. For whatever a ticket adds.

Common args: `out=<dir inside the project>` (the flatpak Godot cannot read or
write `/tmp`), `size=WxH` (default 1280x720); `SHOTS_TIMEOUT` (seconds,
default 300). Each preset takes 2 to 5 seconds. gamescope dumps core on
shutdown after Godot exits; that is expected and ignored.

**Automatic checks**, before each frame is saved: it is not one flat colour
(black, clear colour, nothing drawn) and under 0.5% of it is pure magenta
(Godot's missing-texture colour). A failure prints `SHOT_FAIL <file>: <why>`
and the frame is still saved for reading.

**Defect checklist.** Passing the automatic checks is not enough: read every
PNG with the image viewer (Read tool) and confirm, reporting any of these as a
failure with the PNG path:

- a mesh missing or invisible;
- a magenta or untextured surface;
- an object floating, sunk into the floor or facing the wrong way;
- geometry clipping the camera;
- a HUD or menu element cut off, overlapping another or unreadable;
- a Room with no light;
- anything the ticket says should be visible that is not.

Record in the evidence what each shot shows, one line per PNG.

**Where it runs.** Verified on 2026-11-22 in a local session only (gamescope
3.17, NVIDIA RTX 5080, Vulkan Forward+), including two presets run at once
(`ship class=medium seed=1` and `viewmodel wheel=1`, both PASS, 4 s wall
time): concurrent offscreen runs share the GPU fine. Unconfirmed for the Dev
Factory's agent environment: whether it has gamescope and GPU access is not
known. Where `tests/shots.sh` cannot start, screenshots are a local-session
tool and every look criterion stays `(human)`.

## What an agent cannot check

Not checkable by an agent, always `(human)`: whether the game looks good
(art, animation, lighting mood, framing taste) beyond the defect checklist,
anything about how it sounds or feels (camera motion, controls, pacing,
difficulty), and anything that needs the editor or a play session.
