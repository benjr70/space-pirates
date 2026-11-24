Status: resolved
Blocked by: 21

# Pellets and the Shotgun

## Parent

Part of `.scratch/new-weapons/spec.md` (Spec: Shotgun, Marksman Rifle and the Sandbox sheet). Build order 6 of 12. Vocabulary is `CONTEXT.md`'s. Numbers are starting numbers, tuned in the last ticket.

## What to build

See the spec's "The Shotgun" section, `issues/05-shotgun-role.md` and `issues/08-shotgun-pellet-pattern.md`. The prototype on branch `prototype/shotgun-pellets` is the reference for feel.

The Weapon Profile gains a pellet count, 1 for the existing guns. A shot launches that many projectiles, each thrown at random inside the live cone, evenly over its area, each doing the Profile's damage. One shot gives one hit marker per crew member and counts one kill, however many pellets land: a pellet striking a crew member already killed by the same shot must not report a second kill.

Add the Shotgun as a Weapon Profile with the spec's starting values (12 pellets of 13, 5 degree cone with no bloom, 15 m reach, 0.8 s between shots, 6 shells, the Aim Down Sights and recoil numbers, no Slide widening, loudness 32, the picked shot sound) and put it on the Weapon Wheel after the Assault Rifle. Import the model built by `tools/blender/shotgun.py` into `assets/models/` with a scene under `scenes/weapons/`, at hip pose (0.15, -0.24, -0.34) and aimed distance 0.30, with a lowered pose set clearly below the hip pose. The model has no skeleton yet: give it the minimum the Viewmodel needs to mount it; its real clips are a later ticket. Until then it reloads like a magazine gun.

Pellet count, damage per shot and pellets needed to kill join the sheet.

## Acceptance criteria

- [x] A Shotgun shot launches 12 pellets, all inside the cone.
- [x] A shot that kills one crew member awards one kill's XP and flashes one marker.
- [ ] At about 3 m a centred shot kills; at about 8 m it usually takes two.
  Not met as written. Measured with headless shots (100 per distance) at a crew member standing still, aimed at the chest:

  | Distance | One shot kills | Two shots kill |
  |---|---|---|
  | 3 m | 100% | 100% |
  | 4 m | 100% | 100% |
  | 6 m | 100% | 100% |
  | 8 m | 89% | 100% |
  | 10 m | 50% | 100% |
  | 12 m | 20% | 96% |

  Cause: every bolt has a 0.09 m overlap sphere (`scenes/projectile_3d.tscn`). That widens a crew member's 0.35 m half-width to about 0.44 m, so about 10 of 12 pellets land at 8 m where the band assumed about 7. The pellet prototype fired the same projectiles, so this is the gun the user picked. The numbers stay as the user picked them, and the band is left to the balance pass in ticket 28.
- [x] A shot during a Slide is no wider than one standing still.
- [x] The Shotgun is on the wheel and shows the pump-action model at the hip, aimed and lowered.
- [x] The Pistol and Assault Rifle still fire one projectile.
- [x] `tests/run_all.sh` passes.

## Comments

Build note, 2026-11-22:

- `WeaponProfile.pellet_count` (default 1; Shotgun 12). `fire()` in `scripts/player_3d.gd` launches that many projectiles, each scattered evenly over the cone's disc, and keeps them in `last_pellets` (it still returns the first). The scatter change applies to every gun: the Pistol and Assault Rifle used to scatter over a square of yaw and pitch, whose corners reached outside the cone, so their shots now group slightly tighter.
- One hit marker and one kill per crew member per shot: each shot keeps a record of what it has struck. The first strike on a target reports `hit_landed` about 1.5 physics steps later (`SHOT_REPORT_DELAY`), as a kill if the volley finished it by then. A pellet that kills after the plain hit was reported sends one kill report; nothing reports a target as killed twice. XP comes off that signal in `main_3d.gd`, unchanged.
- The Shotgun is `resources/weapons/shotgun.tres` with the spec's numbers, third on the Pirate's `weapons` list. The lowered pose is (0.21, -0.36, -0.32). For now it reloads like a magazine gun, 2.4 s with the magazine sounds. The model is `assets/models/shotgun/` (from `tools/blender/shotgun.py`). The scene is `scenes/weapons/shotgun_model.tscn`, with an empty `Skeleton3D` and empty `fire` and `reload` clips as stand-ins until ticket 24.
- The shot sound is `assets/audio/firearm_library_shotgun/shot.ogg` with a `LICENSE.txt`. ffmpeg finds one shot in it: no silence inside, one onset, and two 10 ms reflections at 0.67 s and 1.00 s.
- The sheet has a pellet count row. Damage per shot is damage times pellets (156), shots to kill assumes every pellet lands (1), and there is a new "Pellets to kill crew" row (8, and "-" for one-projectile guns). `docs/sandbox.md` is regenerated.
- The range band was not met as written:

| Distance | One shot kills | Two shots kill |
|---|---|---|
| 3 m | 100% | 100% |
| 4 m | 100% | 100% |
| 6 m | 100% | 100% |
| 8 m | 89% | 100% |
| 10 m | 50% | 100% |
| 12 m | 20% | 96% |

  Cause: the 0.09 m overlap sphere on every bolt widens the target. The numbers were kept as the user picked them, and the band is left to ticket 28. `_check_shotgun_range` in `tests/test_crew.gd` is now a loose seeded guard: at 3 m one shot kills at least 95% of the time, at 12 m one shot kills at most 45%, and at 8 m two shots kill at least 95%.
- Not checked by eye or ear: the model, the poses, the sound and the recoil feel.

- 2026-11-24: The unticked range line stays unticked: the Shotgun kills in one shot further out than it says. The user played with these numbers and kept them (see the first balance pass ticket), so the measured band is the accepted one.
