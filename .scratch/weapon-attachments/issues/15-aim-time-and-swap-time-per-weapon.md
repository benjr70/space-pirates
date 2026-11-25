Status: resolved
Blocked by: none

# Aim time and swap time per weapon

## Parent

Part of `.scratch/weapon-attachments/spec.md` (Spec: weapon Attachments and the Loadout). Build order 1 of 10. Vocabulary is `CONTEXT.md`'s. Numbers are starting numbers, tuned in the last ticket.

## What to build

See the spec's "New Weapon Profile attributes" and `issues/12-aim-time-and-swap-time.md`. The prototype on branch `prototype/aim-and-swap-time` (`scripts/proto/proto_aim_swap_time.gd`) is the reference for feel; lift its behaviour, not its code.

Two new Weapon Profile fields, in the four `.tres` files and in the Sandbox sheet's rows and `docs/sandbox.md`: aim time (Pistol 0.15, Assault Rifle 0.22, Shotgun 0.22, Marksman Rifle 0.32 s) and swap time (0.30, 0.40, 0.45, 0.50 s). The Pirate's own `swap_time` goes.

- The Viewmodel's pose and the camera's zoom ease toward the aimed pose at 3 divided by the aim time, and back at the same rate.
- `ads_spread`, `ads_moving_spread` and `ads_speed` blend in a straight line from the hip value to the aimed value over the aim time, and back.
- Firing while the sights rise is allowed.
- After a Descope the sights return over the full aim time, once the Descope's recovery has passed.
- A swap takes the swap time of the weapon being drawn.

## Acceptance criteria

- [x] (agent) Each Profile holds the aim time and swap time above, exactly, and both are rows in the sheet and in `docs/sandbox.md`.
- [x] (agent) Holding aim from the hip, each gun's Viewmodel is within 5% of its aimed pose at its aim time, within 10% of that time.
- [x] (agent) Halfway through the Assault Rifle's aim time its aimed-still cone is halfway between its hip cone and its aimed cone, within 10%; at the aim time it equals the aimed cone, within 2%.
- [x] (agent) Swapping from the Pistol to the Marksman Rifle blocks fire for 0.50 s, and back to the Pistol for 0.30 s, each within 0.02 s.
- [x] (agent) A shot fired halfway up is allowed and counts.
- [x] (agent) `tests/run_all.sh` passes.
- [ ] (human) Each bare gun feels as good to aim and to draw as in the prototype.

## Evidence

- Profiles and sheet: `tests/test_pirate.gd::_check_aim_and_swap_numbers` asserts each Profile's `aim_time` is 0.15 / 0.22 / 0.22 / 0.32 and `swap_time` 0.30 / 0.40 / 0.45 / 0.50 (`is_equal_approx`), and that the Pirate has no `swap_time` of his own; `tests/test_sandbox.gd::_check_doc_fresh` asserts the sheet has editable `aim_time` and `swap_time` rows and `docs/sandbox.md` has `| Aim Time | 0.15 | 0.22 | 0.22 | 0.32 |` and `| Swap Time | 0.3 | 0.4 | 0.45 | 0.5 |` (plus the stale check).
- Viewmodel at the sights: `tests/test_pirate.gd::_check_aim_time_pose`, which for each of the four guns presses aim from rest at the hip and asserts the first frame the Viewmodel is within 5% of the aimed pose is within 10% of the aim time (measured at 60 fps: Pistol 0.150, Assault Rifle 0.233, Shotgun 0.233, Marksman Rifle 0.333 s). It asserts the same for the zoom (same times) and for the drop back to the hip.
- Assault Rifle cone: `tests/test_pirate.gd::_check_aim_time_cone` asserts the hip cone is 1.2 deg, the cone 7 frames (0.117 s) up is within 10% of 0.87 (measured 0.850), and at the frame nearest the 0.22 s aim time (0.217 s) within 2% of the aimed 0.54 (measured 0.550); also that it narrows every frame and is back to 1.2 one aim time after the sights drop.
- Swap blocks fire: `tests/test_pirate.gd::_check_swap_time_of_drawn` tries a shot every frame after the swap and asserts Pistol to Marksman Rifle blocks fire for 0.50 s and back to the Pistol 0.30 s, each within 0.02 s (measured 0.517 and 0.317 s).
- Shot halfway up: `tests/test_pirate.gd::_check_shot_halfway_up` fires the Assault Rifle halfway up the sights and asserts the shot goes off, spends one round, signals `fired`, lands on a body 6 m ahead for 25 damage, and that its cone was within 10% of 0.87 (measured 0.850).
- Gate: `tests/run_all.sh` on seed 422456343, every suite PASS (static 141, generator 341845, layouts 252, ship_3d 3681, pirate 1027, crew 200, sandbox 111, raid_smoke 924 checks), `total: 229 s`.

## Owed to playtest

- (human) Each bare gun feels as good to aim and to draw as in the prototype.

## Comments

Built 2026-11-24 on `weapon-attachments`.

- `WeaponProfile` (`scripts/weapon_profile.gd`) has `aim_time` (end of the "Aim Down Sights" group) and `swap_time` (new "Weapon Wheel" group), both plain exports, so the Sandbox sheet and `docs/sandbox.md` pick them up as editable rows. `aim_ease_rate()` returns `AIM_EASE / aim_time` with `AIM_EASE := 3.0`.
- The old magazine method `WeaponProfile.swap_time(from_empty)` clashed with the new field, so it is renamed `magazine_swap_time(from_empty)` (callers in `viewmodel.gd` and `pirate_audio.gd`). Nothing else changed in it.
- The Pirate (`scripts/player_3d.gd`) lost `swap_time` and `ads_zoom_speed`. He has a public `aim_progress` (0 hip, 1 aimed) that follows `ads` in a straight line over `weapon.aim_time` each physics frame (`_tick_aim_progress`, also on the Clamber path). `spread_degrees()` blends `ads_spread` (from 1) and `ads_moving_spread` (from `spread_walking`) by it, and `_walk` blends `ads_speed` (from 1), both ways. `ads` itself is still a flag and still flips at once: sway, recoil push and kick, bob and the mouse slowdown key off `ads` as before. A swap sets `_swap_left = next.swap_time`.
- The zoom uses `1 - exp(-aim_ease_rate() * delta)` instead of `ads_zoom_speed * delta`, and so does the Viewmodel between the hip and the sights (`viewmodel.gd`), so 95% at the aim time holds at any frame rate. The sprint-low pose still eases at `pose_lerp` (10). The Viewmodel's swap dip reads the drawn Profile's `swap_time`.
- A Descope needed no code of its own: the sights drop, `aim_progress` falls, and when the recovery ends they come up from the hip over the full aim time (`_check_descope_full_aim_time`: 0.317 s for the Marksman Rifle's 0.32).
- Existing checks changed only where the timing changed: `_stance_cones` now waits the Profile's aim time after aiming before it reads the aimed cones, and every wait on `player.swap_time` reads `player.weapon.swap_time` (the drawn weapon). `tests/shots.gd`'s `wheel=` draws a copy of the next weapon with `swap_time = 0` in place of zeroing the Pirate's.
- Found, not fixed: a swap blocks fire one frame longer than its time at 60 fps (0.517 s for 0.50, 0.317 for 0.30), because `_swap_left` counts down by float deltas and lands a hair above 0. Inside this ticket's 0.02 s tolerance; the same for reload and the other timers.
- For ticket 16 (Attachments and the Built Weapon): multiply `aim_time` and `swap_time` on the Built Weapon's Profile; nothing caches them (the Pirate reads `weapon.aim_time` every frame, the Viewmodel calls `profile.aim_ease_rate()` every frame, and a swap reads the drawn Profile's `swap_time` when it starts). For ticket 17 (the Loadout): a swap's time is the drawn weapon's, taken in `switch_weapon`.
