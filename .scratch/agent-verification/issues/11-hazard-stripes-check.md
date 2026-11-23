Status: resolved

# A check for the Hazard stripes

## Parent

`.scratch/agent-verification/spec.md`, follow-up from `08-fast-loop.md` (an area with no suite in the coverage table of `docs/agents/paperclip.md`).

## What to build

`scripts/ship/hazard_stripes.gd` (`HazardStripes`) draws a yellow-and-black stripe texture in code and hands out a matte, triplanar material for it. `scripts/door_3d.gd` puts it on a sealed Hatch and `scripts/ship/boarding_pod.gd` on the Boarding Pod's collar. No suite asserts anything about it: the 3D suites build Hatches and the Boarding Pod, so the code runs, but nothing would notice the stripes going missing or turning grey.

What deserves a check is small and objective: the material is the striped one and it is on the parts it is meant to mark. Whether it looks right is a screenshot question (`tests/shots.sh ship`, or `scene` on `door_3d.tscn`), not a suite one. The headless checks can go in `tests/test_ship_3d.gd`, which already builds a ship with Hatches and a Boarding Pod:

- `HazardStripes.texture()` holds both `YELLOW` and `BLACK` pixels, and `material()` is triplanar, matte (roughness 1, metallic 0) and uses that texture.
- Both leaves of a sealed Hatch and the Boarding Pod's collar carry that material.

## Acceptance criteria

- [x] (agent) `HazardStripes.texture()` contains both `YELLOW` and `BLACK` pixels, and `HazardStripes.material()` is triplanar with `uv1_scale` of `DENSITY` on each axis, roughness 1.0, metallic 0.0, and that texture; asserted in `tests/test_ship_3d.gd`.
- [x] (agent) In the built ship, both leaves of a sealed Hatch and the Boarding Pod's collar each have a surface using a `HazardStripes` material; asserted in `tests/test_ship_3d.gd`.
- [x] (agent) A `tests/shots.sh` frame showing a Hatch and the Boarding Pod collar shows the stripes, recorded under the defect checklist in the evidence.

## Evidence

- Texture and material: `tests/test_ship_3d.gd::_check_hazard_stripes_material`, called from `_initialize`. It reads `HazardStripes.texture().get_image()` and needs at least one pixel within one 8-bit step of `YELLOW` and one of `BLACK`. It then asserts that `HazardStripes.material()` has `uv1_triplanar`, `uv1_scale` equal to `Vector3.ONE * DENSITY`, `roughness` 1.0, `metallic` 0.0, and `albedo_texture == HazardStripes.texture()`. Shown to fail with temporary edits to `scripts/ship/hazard_stripes.gd`, reverted with `git checkout` (the file had no changes before; `git diff --stat` was empty afterwards). Run with `tests/run_all.sh only=ship_3d`:
  - Every pixel painted `YELLOW` and roughness set to 0.5: `FAIL  HazardStripes.texture() yellow pixels true, black pixels false; want both` and `FAIL  HazardStripes.material() roughness 0.50, want 1.0`.
  - Triplanar off, scale doubled, metallic 0.3: `FAIL  HazardStripes.material() is not triplanar`, `FAIL  HazardStripes.material() uv1_scale (3.2, 3.2, 3.2), want (1.6, 1.6, 1.6)`, `FAIL  HazardStripes.material() metallic 0.30, want 0.0`.
- On the built ship: `tests/generated_ship_checks.gd::check_hazard_stripes`, which runs inside `ship_3d`. `test_ship_3d.gd` calls it on the hand-authored ship of the main scene, right after `_check_boarding`, and `GeneratedShipChecks.run` calls it on the generated large ship (seed 10 on this corpus). For every sealed Hatch it asserts that `_leaf_a` and `_leaf_b` both have a surface whose active material is a `HazardStripes` material, meaning its albedo texture is `HazardStripes.texture()` and it is triplanar. It asserts that at least one Hatch is sealed. It asserts that the Boarding Pod has exactly 3 such meshes at its collar (local z from `COLLAR_Z` to `COLLAR_Z + 0.5`: the deck strip and the two side frames). Failures name the Ship Class and seed (`large seed 10: ...`; the hand-authored ship reads `hand-authored seed 0: ...`). `tests/run_all.sh only=ship_3d` went from `PASS (3646 checks, 9 s)` to `PASS (3661 checks, 9 s)`. Shown to fail with temporary edits, reverted with `git checkout`: `_leaf_b.mesh.material = stripes` replaced with `pass` in `scripts/door_3d.gd`, and both collar side frames given `hull` in `scripts/ship/boarding_pod.gd`. That printed `FAIL  large seed 10: sealed hatch 1 leaves are not both hazard striped (a true, b false)`, the same for hatches 2 and 3 and for `hand-authored seed 0: sealed hatch 1`, and `FAIL  large seed 10: boarding pod collar has 1 hazard striped pieces, want 3 (deck strip, two side frames)`, the same for the hand-authored ship.
- Screenshots: two `scene` frames of `res://scenes/main_3d.tscn` (the hand-authored ship, boarded through Hatch 0 at (21.5, 0, 34) with Hatch 1 at (-0.5, 0, 18) sealed). Both runs printed `shots: PASS scene, 1 frames`. `pod_collar.png` shows a Hatch (the boarding one) and the Boarding Pod collar in one frame. The sealed Hatch is on another wall, so its stripes get a frame of their own:
  - `.godot/shots/stripes/sealed_hatch.png` (`cam=4.5,1.6,18 look=-0.5,1.1,18 fov=80`): the sealed Hatch from inside its Room. Both leaves show diagonal yellow-and-black stripes, the seam is between them, and the red lamp bar sits above. The yellow reads olive in the Room's dim light, and the black bands stay black, not grey. Checklist: no mesh missing, no magenta, nothing floating or clipping. The ceiling is very dark (navy) and the walls near black because this Room is unrevealed under `explore_darkness`; the Room is lit, just dim. The plain blue-grey box on the right is a hand-authored prop. The HUD shows `E — Open hatch` because the Pirate stands at the boarding Hatch; the camera is a separate one.
  - `.godot/shots/stripes/pod_collar.png` (`cam=23.3,1.5,34 look=21.5,1.1,34 fov=90`): inside the Boarding Pod facing the boarding Hatch. The collar's two side frames and its deck strip all carry clear orange-yellow and black diagonal stripes, with the handrails on both walls. The Hatch leaf between the frames is cyan because its trim is in the hint state (the Pirate is in reach). It is not striped, which is correct for the Hatch the Pod is docked at. Checklist: no missing mesh, no magenta, nothing floating or clipping, HUD readable. An earlier framing from `cam=24.6` showed the whole collar and the beacon too, but the Pirate's Viewmodel pistol floated mid-frame because the shot camera stood behind the Pirate. That is a shot-setup artifact (the `scene` preset does not hide the Player), not a game defect, so the frame was retaken in front of him.

## Comments

2026-11-22: built by a subagent (test code only). The orchestrating session re-ran `tests/run_all.sh only=generator,ship_3d` (both PASS) and confirmed no game script changed.
