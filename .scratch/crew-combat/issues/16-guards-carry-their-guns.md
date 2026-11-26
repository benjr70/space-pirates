Status: resolved
Blocked by: 15

# Guards carry their guns

## Parent

Part of `.scratch/crew-combat/spec.md` (Spec: crew combat). Build order 2 of 14. Vocabulary is `CONTEXT.md`'s. Numbers are starting numbers, tuned in the last ticket.

## What to build

See the spec's "How crew look" (a Guard's gun), `issues/10`, `issues/02`, and `git show prototype/crew-look:scripts/proto/proto_crew_look.gd` for the poser and the pose numbers (`READY`, `READY_PISTOL`, `AIM_LONG`, `AIM_PISTOL_TWO`).

- A Guard shows its Weapon Profile's model, 1.15x, from the moment it spawns. The gun is positioned relative to the chest and the hands are solved onto it, as the prototype does; decide whether that runs as a skeleton modifier or is baked into clips, and say which under Comments.
- On patrol and in routine: the Pistol at the thigh; a long gun low across the body, both hands on it, in `Idle`, `Walk` and `Run`.
- Aiming (today's FIGHT): the Pistol in two hands; a long gun shouldered, right hand on the grip, left on the fore-end.
- Hands that close: fingers curled round the grip and the fore-end of each of the four guns, wrists squared to the gun. This is the prototype's known fault and the main work of this ticket. A fore-end marker on each weapon scene if that helps.
- Shots leave from the gun's `Muzzle` marker, not a computed point; the clear-shot test uses the same point.
- A dead Guard's gun falls with it or is hidden; it cannot be picked up.
- A `tests/shots.sh crew` view (or a new preset) showing a Guard with each gun, on patrol and aiming, from the front and the side. Update `docs/agents/validation.md` if a preset is added.

## Acceptance criteria

- [x] (agent) Every living Guard has a visible gun model whose scene is its Weapon Profile's `model`; no Worker has one.
- [x] (agent) Aiming, each hand's wrist is within 4 cm of its place on the gun (grip, and fore-end for the three long guns), for all four guns.
- [x] (agent) A Guard's projectile starts within 5 cm of its gun's `Muzzle` marker.
- [x] (agent) The screenshots show, for each of the four guns, a gun in hand on patrol and aimed, with no gun floating clear of the hands and no defect from the checklist.
- [x] (agent) `tests/run_all.sh` passes.
- [ ] (human) Hands look like they are holding each gun, on patrol and aiming.
- [ ] (human) From across a Room it is clear which gun a Guard carries.

## Evidence

- **Every living Guard shows its model; no Worker one.** `tests/test_crew.gd::_check_guns_carried`: every living crew member of the generated medium ship (`_check_routines`, 60 s in) is checked. Each Guard's `CrewGun.gun` has the scene file of its Weapon Profile's `model`, has meshes, is the only weapon-model scene under the body, and is visible as far up as the body (the ship's reveal hides whole bodies out of the Pirate's sight, so visibility is judged up to the body). Each Worker has no `CrewGun` and no `scenes/weapons/` scene under it. It asserts at least 2 Guards. "From the moment it spawns": `tests/test_crew.gd::_check_guns_in_hands` asserts all 4 Guards show their `model` scene, visible in tree, right after `add_child` with no frame run.
- **Wrists within 4 cm, aiming, all four guns.** `tests/test_crew.gd::_check_guns_in_hands`: one Guard per gun in FIGHT for 30 frames (the hold fully blended in, `aim == 1` asserted). Each wrist bone is read in `Skeleton3D.skeleton_updated`, so after the modifier has run, and must lie within `WRIST_TOLERANCE` (0.04 m) of `CrewGun.hand_place_global` (right on "grip", left on "fore") for all four guns. The Pistol's left wrist is held to the same 4 cm, though the criterion does not ask for it. Measured on every run: right 0.000 m on all four; left 0.000 (Pistol), 0.000 (Assault Rifle), 0.018 (Shotgun), 0.006 (Marksman Rifle). The same check asserts that each grip, and each long gun's fore-end, lies inside the gun model's own mesh bounds (5 mm grown), so the place is on the gun.
- **Projectile within 5 cm of the `Muzzle` marker.** `tests/test_crew.gd::_check_guns_in_hands`: the four Guards then fight a Pirate in open Rooms for 12 s (`GUN_FIGHT`). Every bolt they fire is checked as it enters the tree. It must start within `MUZZLE_TOLERANCE` (0.05 m) of its gun's `Muzzle` marker (a node named `Muzzle` inside the gun scene). The clear-shot test's muzzle for that aim (`Crew3D.aim_muzzle(position, last_aim_point)`) must be the same point within 0.05 m. At least 2 bolts per gun are required. Measured: furthest bolt 0.0000 m from its marker, clear-shot point 0.0005 m.
- **Screenshots.** `tests/shots.sh crew` PASS, 16 frames, in `.godot/shots/crew/`. Read against the defect checklist:
  - `guns_patrol_front.png`, `guns_patrol_side.png`: left to right, the Pistol at the right thigh in the right hand, then the Assault Rifle, Shotgun and Marksman Rifle each low across the body in both hands.
  - `guns_walk_side.png`: all four walking, guns still in hand.
  - `guns_aim_front.png`, `guns_aim_side.png`: the Pistol in two hands at the chest; the long guns shouldered, torso turned side-on.
  - `hands_<gun>_patrol.png`, `hands_<gun>_aim.png` for all four guns, close up from the right front: the right fist closed round each pistol grip; the left hand closed under each fore-end (on the Shotgun's pump) with the fingers up its right side; on the Pistol aimed, the left hand wrapped round the right; wrists in line with the gun.
  - `sight_line.png`: the red line starts at the end of the Marksman Rifle's barrel.
  - `front.png`, `side.png`: the Guard (Pistol at the thigh) and the unarmed Worker.

  No gun floats clear of its hands. Nothing is missing, magenta or untextured, nothing floats or sinks, and no camera clips. Cosmetic, left to playtest: the thumbs of the left hand stand up beside the fore-end instead of lying along it. On the carried Pistol the top of the fist rides level with the slide. A long gun's stock in the aimed hold sits inside the shoulder (the arms are too short to reach the fore-end with the butt at the shoulder's front).
- **`tests/run_all.sh` passes.** Final code, twice: seed 884981243 PASS (331 s) and seed 731029283 PASS (308 s). Every suite passed: static 179, generator 358259, layouts 252, ship_3d 3718, pirate 2402, crew 407, sandbox 490, attachments 1674, raid_smoke 1104 checks.

## Owed to playtest

- [ ] (human) Hands look like they are holding each gun, on patrol and aiming.
- [ ] (human) From across a Room it is clear which gun a Guard carries.

## Comments

**Skeleton modifier, not baked clips.** `scripts/crew/crew_gun.gd` (`CrewGun`) is a `SkeletonModifier3D` added to the rig's skeleton at spawn (`Crew3D.gun`; null for a Worker). It places the gun model (the Weapon Profile's `model` scene, instanced under the body's Model node at 1.15x) and then solves the arms onto it every frame over whatever clip plays, as the prototype did. Baking was not needed. Every clip and ticket 18's stand-in crouch carry the gun as they are, and ticket 22's poses can blend over it. The cost is about 9 s on the `crew` suite (407 checks at 55 to 56 s; 48 s with the arm solve switched off). The finger closing is worked out once from the rest pose as local rotations, so per frame it costs only the arm IK and 30 local rotations a hand. A body the ship's reveal hides has its gun placed but no arms solved.

**Holds** (all numbers are `CrewGun` constants):
- Carried: the long gun's origin is at chest + (-0.05, -0.30, 0.24), barrel pointing (0.55, -0.30, 0.78). It is placed from the animated chest, so it rides `Idle`, `Walk` and `Run`. The Pistol is at chest + (-0.22, -0.46, 0.12), muzzle down and forward, right hand only.
- Aimed: placed from the chest's place in `Idle_Gun_Pointing` (`AIM_CHEST`), held still. Long guns at (-0.10, -0.10, 0.40) with the spine turned 30 degrees side-on and the head kept ahead. The Pistol at (-0.04, -0.02, 0.36), both hands.
- The Shotgun sits 8 cm further back along its barrel in both holds, so the left hand reaches the pump.
- Blend: 0.2 s, carried to aimed and back. Aimed means today's FIGHT, or within 0.5 s of a shot (`Crew3D.AIM_HOLD`), so firing on his cover or a break-off shot also raises the gun.
- In the aimed hold the gun turns about the body's axis to where the Guard aims: where it looks, or its last shot's aim point.

The prototype's `READY` numbers could not be used as written. The rig's arms (0.45 m shoulder to wrist) cannot reach a long gun's fore-end at hip height, nor with the butt at the shoulder's front. That was the "hands do not line up" fault. Hence the higher low-ready carry, the side-on aim, the clavicle swing (up to 30 degrees when a hand is out of reach) and a stock that sits inside the shoulder.

**Hands.** No markers were added to the weapon scenes; they are shared with the Pirate's Viewmodel and the Loadout screen. Each hand's place is in `CrewGun.HOLDS`, in the gun model's own space: the middle of the grip or fore-end, measured off side views of each model; the way it runs across the hand; and the way the palm faces it. The wrist is placed so the hole of a closed hand (`FIST`, measured on the rig: 0.14 m along the fingers, 0.03 m out of the palm) sits on that point. Then the wrist is turned square to the gun and the fingers are closed: knuckle 52, middle 64 and tip 40 degrees; thumb 18, 30 and 30. "Its place on the gun" in the criterion is that wrist place.

**Muzzle and the clear-shot test.** `Crew3D._fire` works out where the muzzle will be (`Crew3D.aim_muzzle`, the aimed hold turned to face the target) and aims from there. It then turns the gun onto the aim point (`CrewGun.aim_at`, with no blend) and launches every pellet from the `Muzzle` marker, where the shot sound plays too. `_muzzle_blocked_from` now sweeps the bolt-wide ball along the barrel, from the body's axis at the muzzle's height to the muzzle, and then from the muzzle to his torso, with the spread edges also from the muzzle. A barrel poking into a prop still counts. The muzzle is where the gun really is: about 1.53 m up and 0.53 m ahead for the Pistol, 1.49 m up and about 0.9 m ahead for the long guns, slightly to the right. It used to be 1.3 m up on the body's axis, 0.625 m ahead.
- The Marksman Rifle's sight line (`CrewSightLine`) now starts at the rifle's `Muzzle` marker, as ticket 20's builder suggested, because this ticket moves where shots leave.
- The smoke run's two muzzle approximations (`test_raid_smoke.gd::_on_shot`, `_spot_near`) now use the bolt's start and `aim_muzzle`.

**Median time to die moved, within tolerance; not tuned.** `_check_time_to_die` on its fixed seeds: Pistol 10.08 s to 9.56 s, Assault Rifle 7.56 s to 5.68 s. Both are still inside 10 s and 6 s within 40%. I counted, on the same fixed seeds, the pellets `Crew3D._over_own_cover` had to turn because they would strike the crate the Guard fires over. Before: 123 of 256 Pistol shots and 129 of 352 Assault Rifle shots. Now: 7 and 0. That rule turns a pellet straying down into one straying up, so about half of all shots from 1.3 m were biased high, over his head. From the gun's real muzzle, 1.5 m up and already past the crate, almost none need turning. The share of shots that hit rose: Pistol 47% to 51%, Assault Rifle 34% to 43%, and every shot in both runs was aimed true. Fewer shots kill him. The balance pass (ticket 28) is where this is tuned.

**Existing checks changed, and one fix, because the muzzle moved:**
- `tests/test_crew.gd::_check_cover_blocked`: the stray crates boxing the Guard in are now stacked two high. From the old 1.3 m muzzle the ring crate 3 m ahead clipped its line, so its own tile had no shot and it set off for cover (the case under test). From the gun's 1.5 m muzzle the single crate in front is low cover it fires over, so it stayed and the check never started. With taller crates it again has no shot and sets off. The assertion (gives up within 3.1 s, does not set off for it again) is unchanged.
- `Crew3D._find_firing_position` now skips tiles its body has no room to stand on (`Crew3D._no_room`: a 0.33 m ball at 0.6 m touching the ship). `_check_muzzle_blocked` (crate) failed without it. The Guard picked a tile beside a stray crate whose centre had a clear line. Its body stopped 0.2 m short against the crate, and from there the muzzle, now 0.5 m ahead, sat over the crate's corner and the line was blocked. It then went back and forth between two such tiles for 12 s without a shot. The old axis muzzle hid this. The check is unchanged and passes.
- `test_crew.gd::_check_lead`'s cone test measures pellets against `last_aim_origin`. That is now set to the actual marker after the gun turns onto the aim point, so it is the point the pellets leave from.

**For later tickets.**
- 22 (poses): `CrewGun` places the gun and solves the hands over the clip. Ticket 22's down, knee, pop-up, step-out and run poses can set the carried hold per pose (new hold dictionaries like `CARRY_LONG`) and lower the body before `CrewGun` solves the arms. The left hand for the reload can use `_hand("L", ...)` with a belt or magazine-well place and weight. The stand-in crouch (`model.position.y = -SINK`) sinks the gun with the body. The muzzle prediction (`muzzle_from`) assumes a standing Guard, so a pose that fires while lowered must keep the aimed hold's muzzle where `muzzle_from` says, or change both together.
- 28 (balance): the time-to-die drop above. Also, the higher muzzle makes more props count as low cover (`CrewCover.find`'s `is_low`), because a Guard can now fire over anything below about 1.45 m.
- The doc comment on `Crew3D.MUZZLE_BALL` says "a ball 0.1 m across", but it is the radius (0.2 m across). It is untouched here; it predates this ticket.

**First gate on the combination with `c83b88f`.** The first full gate run on this branch with this ticket's code passed every suite: total 366 s; crew 406 checks; raid_smoke 1104 checks. Nothing failed from the cherry-picked pod-lane commit combined with ticket 17. That run predates two later edits (the cached finger rotations, and the 12 s fight with at least 2 bolts per gun), so it is not counted below.

**Validation, on the final code:**
- Full gate twice, both PASS: seed 884981243 (331 s) and seed 731029283 (308 s).
- `tests/run_all.sh only=raid_smoke seeds=20`: PASS, seed 728733854, 4389 checks, 757 s. Endings: Quiet 60 Ghost of 60; Loud 60 extracted with a kill of 60; Caught 60 down of 60.
- `tests/run_all.sh only=crew` three more times: PASS on seeds 876749133, 682633743 and 841183858 (407 checks, 55 to 56 s).
- `tests/shots.sh crew`: PASS, 16 frames, read as under Evidence.
- No run failed on the final code, so no seed needed replaying. Earlier, during the build, `only=crew` failed on seed 67001122 with the Marksman Rifle firing 2 bolts in the check's first 8 s fight. That was my own threshold (3 bolts), not a criterion. The replay of that seed after the fix (12 s, at least 2 bolts per gun) passes.
- Every headless Godot run here was bounded by `timeout`; none is left running.
