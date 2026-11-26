Status: resolved
Blocked by: 18

# Fair fire

## Parent

Part of `.scratch/crew-combat/spec.md` (Spec: crew combat). Build order 5 of 14. Vocabulary is `CONTEXT.md`'s. Numbers are starting numbers, tuned in the last ticket.

## What to build

See the spec's "Fair fire" and `issues/06`; `git show origin/research/fair-fire-and-cover:docs/research/fair-fire-and-cover.md` for the sources.

- Exposure ramp: spread opens at the Gunnery's multiple (3x) and closes to 1x over its closing time (2 s) of unbroken sight; resets on broken sight. Remove the 1.5x to 0.5x curve.
- First burst of a sighting walks in from 1 m to one side, reaching him on its last round. Not for the Shotgun or Marksman Rifle.
- True aim: at most two Guards aim true at once, at least one when any has sight and a clear muzzle line. Handover by a timer of 0.8 s, doubled while he is crouched or in cover, halved inside 3 m, to the Guard nearest him with a clear line that held it least recently. A Guard starting a reload gives it up at once.
- Miss points for everyone else: 0.4 to 0.8 m off his body, at the edge of his cover on the side he last peeked from, or beside his head away from his movement in the open.
- Lead by the Gunnery's fraction of the true intercept; halved during a Slide or Clamber.
- A crew Shotgun shot hurts with at most 9 pellets.
- Hitting a Guard throws its spread back to the opening multiple and restarts the closing.
- The numbers a later ticket puts in the sheet (how many aim true, the handover time, the walk-in distance, the pellet cap) live on the Sandbox resource from the start.
- The Marksman Rifle's sight line and the Shotgun's rack are in "A habit per gun".
- Update `CREW_AI.md`.

## Acceptance criteria

- [x] (agent) A Guard's spread is 3x its base (gun spread plus aim error) on first sight and 1x after 2 s of unbroken sight, each within 5%, and never below 1x in 10 s; after sight breaks and returns it is 3x again.
- [x] (agent) In the first burst of a sighting from an Assault Rifle Guard, every round but the last is aimed at least 0.3 m to one side of the Pirate and the last is aimed at him (before spread).
- [x] (agent) With five Guards in sight of him for 20 s, no physics frame has more than two aiming true, and every frame in which any has a clear muzzle line has at least one.
- [x] (agent) Every shot from a Guard not aiming true is aimed between 0.4 and 0.8 m from his body centre (before spread).
- [x] (agent) Against a Pirate walking across at 4 m/s, a Marksman Rifle shot is aimed at the full intercept and a Pistol shot at 0.3 of it, each within 10%; a Shotgun shot at where he is.
- [x] (agent) A crew Shotgun shot from 1 m with all 12 pellets striking takes 117 Health and leaves a full-health Pirate alive.
- [x] (agent) A Guard hit by the Pirate after 2 s of sight has its spread back at 3x.
- [x] (agent) Standing still and exposed at full health against one Guard at its range, over 20 seeded runs the median time to die is within 40% of 10 s (Pistol, 6 m) and 6 s (Assault Rifle, 7.5 m). A run outside that is reported, not tuned away.
- [x] (agent) `tests/run_all.sh` passes.
- [ ] (human) Enemy fire warns before it hurts, and damage feels like the price of staying exposed.

## Evidence

- Exposure ramp: `tests/test_crew.gd::_check_exposure_ramp`. A Pistol Guard in FIGHT with the Pirate 5 m off in the open: after one tick of sight `spread_degrees() / base_cone_degrees()` is within 5% of 3; after 120 ticks (2 s) within 5% of 1; over the next 480 ticks (10 s in all) never below 1. He is then put out of sight with the Guard down behind its own cover (mode DOWN): the exposure is unchanged after 0.5 s. With the Guard no longer down, one tick out of sight and one back in sight gives 3x within 5% again.
- Walk-in: `tests/test_crew.gd::_check_walk_in`. An Assault Rifle Guard alone, 7 m from a still Pirate, fights in the open; every shot's aim before spread is recorded (`Crew3D.last_aim_point`). For two sightings (his sight broken for 0.5 s between), the first whole burst has at least 3 rounds, every round but the last aimed 0.3 m or more from his body centre and the last within 0.01 m of it, all aimed true; the second burst is all within 0.01 m of him. The offset is sideways only (`CrewFire.side_axis`), so its distance from his body centre is its distance to one side.
- At most two aim true, at least one: `tests/test_crew.gd::_check_true_aim`. Five Guards (Pistol, Assault Rifle, Pistol, Assault Rifle, Shotgun) 6.3 to 7 m from him in the empty test Room, all fighting in the open for 20 s (1200 frames). Each frame, at its start, the check takes the frame's own decision (`CrewFire.update`, run once a frame) and counts the Guards aiming true: never more than 2. It judges each Guard's clear muzzle line itself (in the fight, eye ray to his eyes unblocked, `_muzzle_blocked()` false): every one of the frames with any clear line (over 600 required) has at least one aiming true. It also asserts true aim reached at least 3 of the 5 Guards.
- Miss points: `tests/test_crew.gd::_check_true_aim` records every shot of the five Guards; every shot fired while not aiming true (at least 20 required) is aimed 0.4 to 0.8 m from his body centre (before spread). `_check_miss_at_cover` covers the cover branch: in the ring rig, a Guard 4 m beyond a crate from him, 60 miss points (him 0.3 m to +x of the crate, square behind it, 0.3 m to -x) are all "cover", 0.4 to 0.8 m from his body centre and on the crate's side he last peeked from (+x, +x remembered, -x); from the open side with him moving +x at 4 m/s, 20 miss points are all "open", in the band, on his -x side and at least 0.4 m above his body centre.
- Lead: `tests/test_crew.gd::_check_lead`. The Pirate walks back and forth across the Room at 4 m/s, 6 m in front of a lone Guard. For each true shot that is not a walk-in round (at least 3 per gun), the check finds the true intercept itself (stepping the bolt's flight time 20 times from the shot's muzzle point, his body centre and velocity at the shot) and asserts the aim's offset from his body centre is the gun's fraction of the intercept's offset within 10% and the same way: Marksman Rifle 1.0, Pistol 0.3; the Shotgun's is within 0.01 m of him. Also asserted there: a Pistol shot at him mid Slide is led 0.15 of the intercept, every pellet leaves within the Guard's `spread_degrees()` of its aim, and some pellet strays up or down by at least 0.3 of the cone (a real cone).
- Pellet cap: `tests/test_crew.gd::_check_pellet_cap`. A fresh Pirate (150 Health) 1 m in front of a Shotgun Guard in the fight, aiming true, with the gun's spread and the Gunnery's aim error both set to 0 on copies, so every pellet flies true: 12 pellets strike him (each pellet's `hit` signal), he loses exactly 117 Health and is alive. The same check asserts the four crew fight numbers on `resources/sandbox.tres` are 2, 0.8 s, 1 m and 9.
- Hit spoils aim: `tests/test_crew.gd::_check_exposure_ramp`, last part: after 2 s of sight (spread at 1x) the Guard is hit (`take_damage(1, player)`) and its spread is within 5% of 3x.
- Median time to die: `tests/test_crew.gd::_check_time_to_die`. Twenty rigs per gun run side by side, each its own Room with a crate, its own Pirate (full health, standing, physics off) and one Guard behind the crate at the gun's range (Pistol 6 m, Assault Rifle 7.5 m), run i seeded i + 1. It records each Pirate's time from the fight's start to death (up to 60 s) and asserts the median is within 40% of 10 s and 6 s. Measured: Pistol 10.08 s, Assault Rifle 7.56 s, both inside (see Comments). The same check asserts no Guard bolt strikes the ship within 2 m of where it left the muzzle.
- `tests/run_all.sh`: see the gate runs under Comments.

## Owed to playtest

- (human) Enemy fire warns before it hurts, and damage feels like the price of staying exposed.

## Comments

Built 2026-11-25.

**Shape.** `scripts/crew/crew_fire.gd` (`CrewFire`) is new: one per Pirate (`CrewFire.of(pirate)`, kept as meta on him), shared by every Guard whose `target` he is. It decides who aims true and builds every shot's aim point. `Crew3D._fire` asks it (`_aim_point`), then scatters each pellet inside `spread_degrees()`. `CrewCombat.spread` and its 1.5x to 0.5x constants are gone.

**Choices where the ticket left them open:**

- **A real cone: yes.** The spec's hit chances (Pistol about 50% at 6 m with 8.5 degrees, Assault Rifle about 45% at 7.5 m) only come out of the arithmetic for a cone spread evenly over a disc against a 0.7 by 1.8 m body; a sideways-only spread gives about 39% and 37%. So each pellet now draws evenly over the cone's disc (`CrewFire.scatter`, as the prototype and the Pirate's own `_scatter` do). A Shotgun's 12 pellets still each draw on their own inside the whole cone (gun spread plus aim error), which is what gives "about half its pellets a shot" at 3.5 m.
- **Own cover.** A real cone strays down, and from low cover that put bolts into the crate the Guard fired over: the first `seeds=20` smoke sweep (seed 248963915) failed twice on "a Guard (assault_rifle.tres) put 4 shots in a row into the ship within 2 m of its muzzle", both replaying alone. A pellet whose first 2.5 m (`Crew3D.OWN_COVER`) would strike the ship now has its up-and-down stray turned the other way, or dropped if that strikes too (`Crew3D._over_own_cover`). Both replays pass. `_check_time_to_die` now also asserts no Guard bolt strikes the ship within 2 m of its muzzle; with the fix disabled it fails (50 Pistol and 45 Assault Rifle bolts) and the medians rise (Pistol 11.93 s, Assault Rifle 8.16 s, since those bolts were wasted).
- **Broken sight versus ducking.** Ticket 18 left the spread resetting every time a Guard stepped back behind full cover, which would make every peek a first sight (3x, and a walk-in). The spec says the ramp resets "when he breaks sight". The exposure clock now holds (neither runs nor resets) while the Guard is down behind its own cover or stepping out or back (`CrewCover.behind_own_cover`), runs whenever it can see him (so behind low cover it keeps closing while down), and resets when he is out of its sight otherwise. A sighting, for the walk-in, is the same clock: the first burst started after it last reset.
- **Walk-in.** The first round is aimed the walk-in distance (1 m) to one side (a coin toss per burst), falling linearly to 0.4 of it on the last round but one, and the last on him. A straight line from 1 m to 0 would put the fourth of five rounds 0.25 m off, under the criterion's 0.3 m. The Shotgun and Marksman Rifle skip it because their bursts are one round, and a one-round burst has nothing to walk (a sheet edit giving them longer bursts would walk them in). Only a Guard aiming true walks in.
- **True aim.** Decided once a physics frame, at its start, before any Guard moves or fires in it (the first Guard to tick, or anything that asks, does it; `CrewFire.update` is idempotent per frame), so the count can never pass two inside a frame, the frame of a handover included. A Guard can take it with him in sight from its eyes and a clear muzzle line, judged afresh then (`Crew3D.can_aim_true`). Holders without a clear line are swapped at once for waiting Guards with one; empty places fill at once; a holder past its handover time (0.8 s, doubled while he is crouched or behind cover from that holder, halved with him within 3 m of that holder) hands to the waiting Guard that held it least recently (never-held first), the nearer him on a tie. With nobody waiting, a holder keeps it. The count is clamped to at least 1 so the "at least one" rule survives a sheet edit to 0.
- **Ticket 17's hook.** Nothing reloads yet. `CrewFire.give_up(crew)` takes true aim from a Guard at once; "Crew magazines and reloads" should call it as a reload starts and add `not reloading` to `Crew3D.can_aim_true`, so it is not handed straight back.
- **Miss points, and knowing his cover cheaply.** No per-frame tracking. When a Guard not aiming true fires, one grid lookup decides: the tile 0.8 m from him toward that Guard, on the walking grid (`CrewPaths.grid`), is a prop or a wall: he is behind cover from it. The miss then goes at that tile's edge, 0.3 m above his body centre, on the side he last peeked from, drawn into 0.42 to 0.78 m from his body centre. The peek side is the side of the tile he stands off by 0.15 m or more, remembered per tile for when he is square behind it, a coin toss if never seen off it. In the open the miss goes 0.5 m above his body centre and beside it, on the side away from his flat velocity (a coin toss when he is under 0.5 m/s), 0.55 to 0.78 m off. "Body centre" is his position plus 1.0 m (`Crew3D.TORSO_HEIGHT`), where a true shot at a still Pirate goes. The same grid test is "in cover" for the handover time.
- **Lead.** His flat velocity (`velocity` on the Pirate); the intercept solved for the bolt's speed from the muzzle; half the fraction while `in_slide_or_clamber()` (a small new method on the Pirate, `scripts/player_3d.gd`). Miss points are not led.
- **Pellet cap.** `Projectile3D.Volley`: the pellets of one crew Shotgun shot share a counter, and pellets past the cap still strike (and stop) but do no damage. The Pirate's own shots carry none.
- **The Sandbox.** The four numbers are on `resources/sandbox.tres` under a new "Crew fight" group: `true_aim_count` 2, `true_aim_handover` 0.8, `walk_in_distance` 1.0, `shotgun_pellet_cap` 9. The sheet builds its Health and Melee table from every exported Sandbox field, so they show there and in `docs/sandbox.md` (regenerated) as a "Crew fight" group already. Ticket 26 owns the real Crew fight section with its other four numbers. The Gunnery table's note now says what is read.
- **Bursts stagger per Pirate.** `CrewCombat.burst_blocked` only counts crew with the same `target`. In a Raid there is one Pirate, so nothing changes; it lets the time-to-die check run twenty independent fights side by side.

**Checks changed because the ticket replaces what they asserted:**

- `tests/test_crew.gd::_check_aim` asserted the 1.5x to 0.5x curve over 3 s through `CrewCombat.spread`, which the ticket removes. It is replaced by `_check_exposure_ramp` (3x to 1x over 2 s, never below 1x, 3x again after broken sight and after a hit).
- No other existing check was changed. Each of the new checks that drives the suite's shared Pirate turns his physics off for its run and puts it back after: by the time they run, his physics is running (left on by something earlier in the suite; not traced), so his own friction and floor states were moving him and resetting a Slide.

**Median time to die (criterion 8), measured.** Twenty runs per gun, run i seeded i + 1 on every suite run, so the gate gives the same medians each time: Pistol at 6 m 10.08 s (target 10 s, limit 14 s), Assault Rifle at 7.5 m 7.56 s (target 6 s, limit 8.4 s). Both are inside 40%, so the line is ticked, but the Assault Rifle sits 26% over its target. Before the own-cover fix, six 20-run sets on rolled seeds gave Assault Rifle medians of 7.77 to 8.41 s (one just outside) and Pistol 10.3 to 13.1 s; the fix shortens both (fewer wasted bolts), and rolled-seed sets were not measured again after it. Nothing was tuned: the aim errors, rhythm and Health are the spec's.

**For later tickets.**
- "A habit per gun": the Marksman Rifle's claim on a true-aim place goes through `CrewFire` (take one as its sight line starts, `give_up` after the shot); today it is an ordinary Guard here. Its hip fire "with doubled aim error ... needs no true-aim place" will need a way to fire a true shot outside the count.
- "Guards work together": suppression fires "deliberate misses only" at a prop's edges; `CrewFire.miss_point` already aims at his cover's edge but only when he is in sight; out of sight there is no shot today.
- "Firefights in the raid smoke suite": "never more than two aiming true" can read `CrewFire.of(player).holders` after calling `update()` at the start of a frame, as `_check_true_aim` does.
- `Crew3D.last_aim_point`, `last_aim_origin`, `last_aimed_true`, `last_walk_in`, `last_miss_kind` record each shot before spread, for checks.

**Validation.**
- Full gate twice, both PASS: seed 875165833 (256 s) and seed 447910967 (265 s): static 174, generator 357186, layouts 252, ship_3d 3720, pirate 2402, crew 327, sandbox 490, attachments 1674, raid_smoke 1104 checks.
- `tests/run_all.sh only=raid_smoke seeds=20`: PASS, seed 644706923, 4389 checks, 579 s. Endings: Quiet 54 Ghost of 60; Loud 60 extracted with a kill of 60; Caught 60 down of 60.
- `tests/run_all.sh only=crew` three more times: PASS on seeds 697116865, 14680982 and 897650361 (327 checks, 28 to 29 s).
- Before the own-cover fix, both gates and one default smoke run passed and the `seeds=20` sweep (seed 248963915) failed on the two Raids named above; both replays pass now.
- Screenshots: `tests/shots.sh crew` (PASS, 2 frames). `front.png` and `side.png` show the Guard and the Worker beside a crate, whole, textured and on the floor; nothing on the checklist. This ticket changes nothing seen there; where shots go is checked headless.
