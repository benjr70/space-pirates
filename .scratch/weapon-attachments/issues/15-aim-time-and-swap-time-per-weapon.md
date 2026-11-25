Status: ready-for-agent
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

- [ ] (agent) Each Profile holds the aim time and swap time above, exactly, and both are rows in the sheet and in `docs/sandbox.md`.
- [ ] (agent) Holding aim from the hip, each gun's Viewmodel is within 5% of its aimed pose at its aim time, within 10% of that time.
- [ ] (agent) Halfway through the Assault Rifle's aim time its aimed-still cone is halfway between its hip cone and its aimed cone, within 10%; at the aim time it equals the aimed cone, within 2%.
- [ ] (agent) Swapping from the Pistol to the Marksman Rifle blocks fire for 0.50 s, and back to the Pistol for 0.30 s, each within 0.02 s.
- [ ] (agent) A shot fired halfway up is allowed and counts.
- [ ] (agent) `tests/run_all.sh` passes.
- [ ] (human) Each bare gun feels as good to aim and to draw as in the prototype.

## Comments
