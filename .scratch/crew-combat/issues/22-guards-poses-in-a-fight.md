Status: resolved
Blocked by: 16, 17, 18

# Guards' poses in a fight

## Parent

Part of `.scratch/crew-combat/spec.md` (Spec: crew combat). Build order 8 of 14. Vocabulary is `CONTEXT.md`'s. Numbers are starting numbers, tuned in the last ticket.

## What to build

See the spec's "How crew look" and `issues/10`. Pose numbers and the poser: `git show prototype/crew-look:scripts/proto/proto_crew_look.gd` (`DOWN`, `DOWN_KNEE`, `DOWN_DEEP`, `RUN_LOW`, `RUN_TALL`, `RELOAD_*`, `AIM_LONG`).

- Down behind cover: a squat or one knee, picked again every time the Guard drops back after a peek, 60 to 40. Squatting, the top of its head is below 1.05 m; on one knee it is above 1.15 m.
- The head zone and the body's collision follow the pose, so a bolt over a 1.1 m crate can strike the head of a Guard on one knee and cannot strike a squatting one.
- Pop up over low cover; step out from full cover and back, with feet that step rather than slide; duck lower at a near miss.
- Reload while down: the left hand leaves the gun, goes to the belt, to the magazine well and back, timed to the reload; shell by shell for the Shotgun. Better than the prototype's three positions if a real clip is within reach (see `issues/02`); say what was used.
- Runs: low when the cover it runs to is low, upright when it is full or there is none.
- The stand-in pose from the cover ticket goes.
- `tests/shots.sh crew` (or a preset) shows a Guard down in each pose behind a crate, popped up, stepped out and reloading.

## Acceptance criteria

- [x] (agent) Over 200 drops behind low cover, between 50% and 70% are squats, and a Guard's pose differs between some two consecutive drops.
- [x] (agent) Squatting behind a 1.1 m crate, a bolt fired level at 1.2 m from the far side strikes nothing of the Guard; on one knee, the same bolt at 1.2 m strikes its head zone and is a Headshot.
- [x] (agent) The body's collision top is below 1.05 m squatting and the crew member cannot be hit in the body over a 1.1 m crate in either pose.
- [x] (agent) Running to a low cover tile the hips are at least 0.2 m lower than running to a full cover tile.
- [x] (agent) Stepping out and back, neither foot bone moves more than 0.15 m while it is the planted foot.
- [x] (agent) The screenshots show the squat, the knee, the pop-up, the step-out and the reload with the gun in both hands where it should be and no defect from the checklist.
- [x] (agent) `tests/run_all.sh` passes.
- [ ] (human) A Guard on one knee offers a head shot that feels earned, and a squatting one feels properly hidden.
- [ ] (human) The reload and the step-out no longer look rough.

## Evidence

- **200 drops, 50 to 70% squats, the pose changing between two drops.** `tests/test_crew.gd::_check_down_poses`: an Assault Rifle Guard on the tile behind the cover ring's south crate (1.1 m, low cover) is put up over it (`_stand`, mode SHOOT) and drops back (`CrewCover._duck`, the real path after a peek) 200 times. It asserts the squat share lies in [0.5, 0.7] with every other drop on one knee, that some two drops in a row differ, and that the capsule's top equals `CrewPose.BODY_TOP` for that stance on every drop. Measured: 120 of 200 squats (60%) on every run (the bag gives exactly 3 in 5). Real fights: `_check_cover_ring` asserts each of the four guns was seen down in both stances over its 20+ drops after a peek.
- **Level bolt at 1.2 m: nothing squatting, a Headshot on one knee.** `tests/test_crew.gd::_check_down_poses`: in each stance (pose blended in, 30 frames), a real `Projectile3D` of the Pirate's is fired level at 1.2 m from 4 m beyond the crate straight at the head zone. Squatting it asserts nothing of the Guard was struck (it hit the wall behind); on one knee it asserts exactly one strike on the Guard, `on_head` true (a Headshot). It also asserts the head zone's top below 1.05 m squatting (measured 0.991 m) and above 1.15 m on one knee (1.348 m, centre 1.188 m).
- **Collision top below 1.05 m squatting; no body hit over the crate in either pose.** `tests/test_crew.gd::_check_down_poses`: asserts the capsule's top below 1.05 m squatting (0.82 m; 1.0 m on one knee), then in each stance fires 37 bolts over the crate: 16 level at 1.2, 1.3, 1.45 and 1.6 m across its width (±0.15, ±0.3 m), and 15 down from his eyes (1.5 m, 6 m off) at points on its body 0.2 to 1.0 m up, ±0.25 m across; asserts none struck its body (`on_head` false). Head strikes on one knee are allowed.
- **Hips at least 0.2 m lower running to low cover than to full cover.** `tests/test_crew.gd::_check_runs`: the spot the cover search picks beside the ring's crate (asserted low cover) and beside the locker (asserted full cover); the Guard runs to each from a far corner of the Room and must get down there. Hips bone heights are read in `skeleton_updated` on every frame 0.25 s into the run at over 2 m/s; it asserts at least 20 frames of each and the mean to full cover minus the mean to low cover at least 0.2 m. Measured: 0.609 m (111 frames) against 0.909 m (64 frames), 0.30 m lower.
- **Planted foot within 0.15 m stepping out and back.** `tests/test_crew.gd::_check_full_cover` (`_watch_feet`, `_check_planted_feet`): the Pistol Guard behind the locker steps out and back at least four times; both foot bones are read in `skeleton_updated` on every frame of `CrewCover.stepping()` (out, up there, back). A foot is planted while within 0.02 m of the lowest it stood; over each planted stretch it asserts the foot bone moved no more than 0.15 m from where it was set down. It also asserts four or more step outs each moving the body at least 0.7 m, and both feet lifting (over 0.04 m) on every one, so the feet step. Measured: body 1.01 m each time, worst planted foot 0.052 m, both feet lifted on 4 of 4. Mutation: with stepping switched off (the clip's feet under a sliding body) the check fails, 1.209 m and feet lifted on 0 and 1 of 4.
- **Screenshots.** `tests/shots.sh crew`: PASS, 40 frames, in `.godot/shots/crew/`, read against the defect checklist:
  - `front.png`, `side.png`, `guns_*`, `hands_*`, `sight_line.png`: as ticket 16 left them, unchanged.
  - `down_squat_front.png`: four Guards behind crates from the Pirate's eye height; no head shows over any crate (a boot or a muzzle tip shows past two crates' sides).
  - `down_squat_above.png`, `down_squat_close.png`: from behind and from the Assault Rifle's right: squatting, hips back, spine leaned, feet flat on the floor, the gun held in both hands in close, muzzle up and to the left, nothing inside the crate.
  - `down_knee_front.png`: the top of each head shows over its crate; the Marksman Rifle's muzzle tip over its crate.
  - `down_knee_above.png`, `down_knee_close.png`: on the right knee, the knee just off the floor, toes down, the left foot flat; gun upright in both hands, clear of the crate.
  - `duck_above.png`: squat, knee, squat, knee, each ducked lower, heads down.
  - `popup_front.png`, `popup_above.png`: all four stood behind their crates, aimed over them, both hands on each gun (the Pistol two handed).
  - `stepout_above.png`, `stepout_close.png`: the Shotgun stood a tile out from the wall's edge, aimed, feet on the floor.
  - `reload_<gun>_<well|belt|seat>.png`, all four guns from the left: the left hand under the magazine (the Shotgun's port) at well and seat, at the belt beside the hip in belt; the right hand on the grip throughout; the gun tipped up and left, clear of the crate and passing beside the head, not through it.
  - `run_side.png`: the Assault Rifle running low (hips down, leaning), the Marksman Rifle upright beside it.
  Nothing missing, magenta or untextured; nothing floating or sunk into the floor; no camera clipping. A probe run (not committed) measured every wrist on its place on the gun, squatting and on one knee, for all four guns (0.000 m), and the left wrist on its reload way at every moment but one in transit (the magazine pulled clear, up to 0.1 m short: out of the arm's reach).
- **`tests/run_all.sh` passes.** See Validation under Comments.

## Owed to playtest

- (human) A Guard on one knee offers a head shot that feels earned, and a squatting one feels properly hidden.
- (human) The reload and the step-out no longer look rough.
- Motion, not judged from stills: the pop up, the step out and back, the duck at a near miss, the reload's hand moving, the 0.15 s drop and 0.2 s rise, and the low run in motion.

## Comments

Built 2026-11-26.

**Shape.** `scripts/crew/crew_pose.gd` (`CrewPose`) is new: a skeleton modifier on the rig (`Crew3D.pose`, null for a Worker), added before `CrewGun` so the gun is placed from the posed chest. It poses the hips (`Body` bone lowered and moved), the spine (lean over Abdomen, Torso, Chest), the head, and solves each leg onto its foot, as the prototype's poser did. What it shows is decided by `CrewCover`: `crouched` and `stance` (down), `near_miss` (`CrewPose.flinch`), `mode == MOVE` with `low` (run low), `stepping()` (step out). `scripts/crew/crew_rig_modifier.gd` (`CrewRigModifier`) holds the bone helpers and two-bone solve both modifiers share; `CrewGun` now extends it (its own copies are gone, no behaviour change). The stand-in sink (`CrewCover.SINK`, `CROUCH`) is gone.

**Choices where the ticket left them open:**
- **60 to 40 is a shuffled bag** (`CrewCover.SQUATS` 3, `KNEES` 2), refilled when empty, not an independent 60% draw each drop: every five drops are three squats and two knees in a random order, so 200 drops are exactly 120 squats and the check cannot flake on a seed. The bag draws from its own generator (`CrewCover._stance_rng`) seeded by hashing the body's `_rng.seed`, so no draw is added to the body's or the global stream (the time-to-die medians are unchanged: Pistol 9.56 s, Assault Rifle 5.68 s). A pick happens at every `_get_down`: arriving at a spot, ducking back after a peek over low cover, stepping back behind full cover. A near miss while down does not re-pick; it ducks lower in the same stance.
- **The prototype's squat was not low enough.** Measured on the rig, `DOWN` (drop 0.72 m, lean 38) puts the head zone's top at 1.14 m, over a 1.1 m crate, against the spec's "head below the cover". The squat is now drop 0.76 m, lean 56, head -26 (top 0.99 m), and the hips go back 0.17 m so the leaned head clears the crate's face (a cover tile's prop face is 0.55 m ahead of the body's centre; the head's front was 15 cm inside it before). One knee is drop 0.54 m (the prototype's 0.60 put the knee joint 2 cm under the floor); top of head 1.35 m. The deep ducks follow (`SQUAT_DEEP`, `KNEE_DEEP`).
- **Capsule tops** (`CrewPose.BODY_TOP`): squat 0.82 m, knee 1.0 m, the top of the back and shoulders in each measured pose (neck 0.68 m and 1.0 m). The old stand-in was 0.94 m for both. It changes at once on going down or standing, as the stand-in did; the drawn pose blends 0.15 s down, 0.2 s up (the gun's own `BLEND`, so a popped-up Guard is up when its gun is: the first shot can come no sooner than 0.2 s after rising, so the aimed hold's muzzle and `muzzle_from` stay the same point).
- **The head zone** rides the head bone. The hips, spine and head are posed even when the ship's reveal hides the body, so a hidden Guard's head is where its stance puts it; only legs and stepping feet are skipped there, as the arm solve is.
- **Gun down behind cover**: the prototype's down hold pointed the barrel forward, and the 1.15x long guns went into the crate (seen in the first screenshots). Down, a long gun is now held in close, muzzle up and across to the left (`CrewGun.DOWN_LONG`); the Pistol two-handed at the chest, muzzle up (`DOWN_PISTOL`). Squatting, every muzzle stays under the crate; on one knee the Marksman Rifle's tip shows, as the head does.
- **Reload**: no real clip was within reach. The rig has none (issue 02); `Pistol_Reload` from Quaternius's Universal Animation Library is on another skeleton and would need a Blender retarget and bake, and is a pistol reload. So it is made in code, but along a continuous way of seven places timed to the reload's own progress (`CrewGun.RELOAD_WAY`: fore-end, well, magazine pulled clear, belt, belt, clear, well, well, fore-end), not the prototype's three held positions; the Shotgun goes port, belt, port once per shell by the shell's own time (`SHELL_WAY`). Places: `WELLS` per gun (measured off each model's magazine or loading port), `BELT` off the hips bone. The gun tips up and left meanwhile (`RELOAD_LONG`, `RELOAD_PISTOL`) and the head turns to it. A reloading Guard's gun is never in the aimed hold (it fires nothing). The magazine mesh itself stays in the gun.
- **Step out**: feet are planted in the world and stepped one at a time (`CrewPose._step_feet`), not driven by `Run_Left`/`Run_Right` (which slide whenever the clip's stride and the body's speed differ). To let steps keep up, a Guard steps out and back at `CrewPose.STEP_SPEED` 0.45 of its speed (`CrewCover._set_mode` sets `_speed_scale` in OUT and BACK, and puts it back). A 1 m step out now takes about 0.7 s instead of about 0.3 s, each way: ticket 28 (balance) should know full-cover peeks are slower. The body plays its standing clip while stepping (`Crew3D._update_animation`).
- **Runs**: run low (`RUN_LOW`, the prototype's) while walking to a spot whose `low` is true and not to an ambush; upright otherwise.

**Fixed on the way, outside the ticket (it blocked the gate):** `only=crew` failed once on seed 506719008, `_check_cover_fight_on_ship`: "a pistol.tres Guard in mode none at (59, 89) stuck for 5 s". Replayed with the ship forced to that run's ship (medium 692645), it failed every time: a Guard searching (then wandering) walked into a Shotgun standing in ambush in a one-wide way; `route_around` found no way round, and `make_way_for` refuses anyone not on patrol, so it pushed against it for the rest of the fight. Nothing in the poses is involved. Fix in `Crew3D._get_past`: a walker out of the fight blocked by a Guard in FIGHT or COVER with no way round gives that walk up and stands `BLOCKED_PAUSE` (1.5 s) before walking anywhere again. A first, broader version (any search or wander, whoever the blocker) broke `_check_head_on_doorway`, so it is limited to a blocker holding a fight spot. The forced replay passes three times out of three.

**Seen and not fixed (pre-existing, reported):** a replay of one `seed=` is not exact. Two runs of `only=crew seed=506719008` on a clean worktree of `c3ce6d8` (before this ticket) generated different ships for the ship fight (medium 626802 and 689672), and on this branch the same seed gave 692645, 906459 and 272085 in different runs. Something before that check draws from the global RNG a varying number of times. `Crew3D._acts_first` breaks ties by instance id, which is one candidate for run-to-run divergence; not chased further. `validation.md`'s "same seed, same draws, same failure" does not hold for the crew suite.

**Existing checks changed:** none were loosened. `_check_cover_ring` gains one assertion (every gun seen down in both stances after its peeks); `_check_full_cover` gains the feet checks. `_check_cover_ring`'s capsule check ("capsule above the crate's 1.1 m top while down") still passes with the new tops.
- `test_raid_smoke.gd`, invariant 4(a) (down with him in sight): the Marksman Rifle's cap on time left out as habit (two doubled handovers, 3.2 s) was applied to every wait in `CrewCover.waited`, including a Guard hiding with no peek waiting its turn to move (ticket 21), which the suite's header and `validation.md` list as a separate, uncapped exemption. The cap now applies only with a peek (a place wait needs one: `CrewCover._holds_down`). Found by the first `seeds=20` sweep on this code (seed 18801616, `class=medium ship=920154835 script=caught`: a Marksman Rifle hiding in his sight waited 10 s for its turn while ten Guards fought and moved between cover). The narrow sweep `only=raid_smoke seed=18801616 seeds=20 class=medium script=caught` reproduces it; the single Raid alone passes. On `c3ce6d8` that narrow sweep passed, and with `STEP_SPEED` set back to 1.0 it passed on this branch too: the slower step outs change the fight's timing enough to reach the case. The game is not changed for it; the check now asserts what its own header says.

**For later tickets.**
- 25 (Workers' poses): `CrewPose` takes its target from `_target()`; Worker poses can be added there and to `POSES` (the prototype's `HIDE`, `HANDS_UP`, `KNEEL`, `BOUND_*` use the same fields, plus hand targets, which this module does not have yet: Workers carry no `CrewGun`, so the arms need their own solve). `CrewPose.fit` returns null without a `cover` today (Workers have none).
- 28 (balance): slower full-cover step outs (above); the squat capsule is 0.82 m (was 0.94 m).
- Cosmetic, for the playtest: the knee pose's raised muzzle on long guns shows over low cover; the hand at the belt sits low by the thigh because the squat's hips are so low.

**Validation, on the final code:**
- Full gate twice, both PASS: seed 748018334 (367 s) and seed 234512129 (382 s). Every suite passed: static 181, generator 358259, layouts 252, ship_3d 3718, pirate 2402, crew 426, sandbox 490, attachments 1674, raid_smoke 1104 and 1091 checks.
- `tests/run_all.sh only=raid_smoke seeds=20`: PASS, seed 946896059, 4389 checks, 780 s. Endings: Quiet 60 Ghost of 60; Loud 60 extracted with a kill of 60; Caught 60 down of 60. The sweep that failed before the smoke fix, seed 18801616, now PASSES (4389 checks).
- `tests/run_all.sh only=crew` three more times: PASS on seeds 78928732, 954041158 and 565613066 (426 checks, 63 to 65 s). Those ran before the smoke-test fix, which touches only `test_raid_smoke.gd`.
- Failed runs, each replayed and fixed as above, never rerun to green: `only=crew` seed 506719008 (the Guard stuck against an ambusher), the `seeds=20` sweep seed 18801616 (the Marksman Rifle cap). The full gates and sweeps before those fixes passed (seeds 357791424, 23798677, 502498249; sweep 442338439).
- Median time to die unchanged on its fixed seeds: Pistol 9.56 s, Assault Rifle 5.68 s.
- `tests/shots.sh crew`: PASS, 40 frames, read as under Evidence.
- Mutation: stepping switched off fails `_check_full_cover` (planted foot 1.209 m; feet lifted on 0 and 1 of 4).
- Pose cost: about 2.3 s of the crew suite (timed inside the modifier); the suite went from 56 to 57 s to 63 to 65 s, the rest being the new checks' bolts and runs.
- Every headless run here was bounded by `timeout`; none is left running.
