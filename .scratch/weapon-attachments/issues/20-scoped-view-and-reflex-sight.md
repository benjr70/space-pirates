Status: resolved
Blocked by: 19

# The scoped view and the Reflex Sight

## Parent

Part of `.scratch/weapon-attachments/spec.md` (Spec: weapon Attachments and the Loadout). Build order 6 of 10. Vocabulary is `CONTEXT.md`'s. Numbers are starting numbers, tuned in the last ticket.

## What to build

See the spec's "Scoped view" and "HUD", `issues/07-scoped-view.md` and `issues/02-scope-rendering-in-godot.md`. Reference: `scripts/proto/proto_scoped_view.gd` on branch `prototype/scoped-view`, which holds the lens, surround and reticle shaders and the settings the user chose: `view: lens (picture-in-picture), magnification 4.0x, reticle cross, view around the lens 1.25x, blur 2.0, edge dark 1.0, eye to glass 0.06 m`.

- A Built Weapon marked as a lens (Combat Scope, Long Scope) aims through picture-in-picture: the lens shows the scene at the Built Weapon's `ads_zoom` against the unaimed view; the view around it zooms 1.25x; the gun stays on screen.
- Outside the lens the screen blurs (mipmap level 2.0) and fades to black toward the edge, by how far up the sights are.
- The eye is 0.06 m from the scope's rear glass when aimed.
- A red cross on the shot line, seen only through the lens. The mouse slows by the lens's magnification.
- The Reflex Sight: an unmagnified window with a red dot on the shot line, seen only through the window; the whole view zooms by `ads_zoom`; no blur.
- The Viewmodel on its own render layer, left out of the lens camera. The lens camera renders only while aimed through a lens.
- The HUD crosshair hides while aimed through a lens or a Reflex Sight.
- A `tests/shots.sh scoped` preset: lens up on both scopes, Reflex Sight up, each also with the gun shifted off centre. Document it.

## Acceptance criteria

- [x] (agent) Aimed with the Long Scope, a target 1 m wide at 50 m spans in the lens the screen width it would span at 5.01x zoom, within 5%; with the Combat Scope, at 2.48x.
- [x] (agent) Aimed through a lens the main camera's zoom is 1.25x, within 2%.
- [x] (agent) With the gun shifted 6 mm off its aimed pose, the reticle's centre is still the screen's centre within 2 px, for both scopes and the Reflex Sight.
- [x] (agent) Aimed through a lens, turn rate per unit of mouse is the hip rate divided by the lens's zoom, within 2%.
- [x] (agent) The lens camera does not render at the hip or with a gun's own sights.
- [x] (agent) The HUD crosshair is hidden while aimed through a lens or a Reflex Sight and shown otherwise.
- [x] (agent) `tests/shots.sh scoped`: the lens picture fills the lens with no black wedge, the scope's own tube is not seen inside it, the surround is blurred and dark at the corners, the Reflex window is clear.
- [x] (agent) `tests/run_all.sh` passes.
- [ ] (human) The lens view feels as it did in the prototype at the chosen settings, with no stutter or shadow flicker.
- [ ] (human) Coming up, dropping and a Descope look right with the blur.

## Evidence

- Lens magnification: `tests/scoped_view_checks.gd::_check_lens_magnification` (pirate suite) aims the Marksman Rifle with the Long Scope and the Assault Rifle with the Combat Scope, asserts their `ads_zoom` is 5.01 and 2.48 within 0.01, projects the two edges of a 1 m target at 50 m through the lens camera, maps that onto the screen by the lens's `PICTURE_SPAN`, and asserts the span on a 720 px screen is within 5% of the span at 5.01x and 2.48x against the 75° unaimed view. Measured in pixels by `tests/shots.sh scoped` on a pure blue 1 m board at 50 m: `long_scope.png` and `long_scope_shifted.png` 46.9 px against 47.0 (-0.3%); `combat_scope.png` and `combat_scope_shifted.png` 22.5 px against 23.3 (-3.1%; the 1024 px lens picture puts the board on 28 or 29 texels, worth up to 3.5% at this size).
- Main camera at 1.25x: `tests/scoped_view_checks.gd::_check_view_around_lens` aims each scope and asserts tan(37.5°)/tan(fov/2) is 1.25 within 2%; it also asserts the Reflex Sight and the Marksman Rifle's own sights zoom the whole view by their `ads_zoom` within 2%.
- Reticle centred with the gun 6 mm off: `tests/shots.sh scoped` measures the red reticle's centroid within 12 px of the middle and fails a frame more than 2 px off; `long_scope_shifted.png`, `combat_scope_shifted.png` and `reflex_shifted.png` (gun 6 mm down and right of its aimed pose) and their unshifted frames each measured (640.0, 360.0), 0.00 px off. Headless, `tests/scoped_view_checks.gd::_check_reticle_seen_when_shifted` asserts that with the gun 6 mm off in each of four directions the screen's middle is still inside each scope's lens and the Reflex Sight's window, and `_expect_window_clear` that no vertex of the Reflex Sight's model sits within 3 mm of its aim point.
- Mouse through a lens: `tests/scoped_view_checks.gd::_check_mouse_through_lens` turns by the same mouse movement at the hip and aimed through each scope and asserts yaw and pitch are each the hip rate divided by 5.01 (Long Scope) and 2.48 (Combat Scope) within 2%.
- Lens camera idle at the hip and with a gun's own sights: `tests/scoped_view_checks.gd::_check_lens_renders_only_aimed` asserts the lens view's update mode is disabled at the hip, aimed and dropped for the Marksman Rifle and Pistol bare and the Assault Rifle with the Reflex Sight, and on only while aimed with either scope (off at the hip and once dropped). `_check_viewmodel_layer_left_out` asserts every Viewmodel mesh draws on layer 2 alone and the lens camera's cull mask leaves it out.
- HUD crosshair: `tests/scoped_view_checks.gd::_check_hud_crosshair_hides` asserts `Hud.crosshair_shown()` is false aimed with the Long Scope, the Combat Scope and the Reflex Sight (Assault Rifle and Pistol), and true at the hip and after dropping with each, and true aimed with the Marksman Rifle and the Pistol bare and the Assault Rifle with only a Long Barrel. The existing `test_pirate.gd::_check_hud_crosshair` (dot in ADS with a bare gun) still passes.
- `tests/shots.sh scoped`: PASS, 6 frames, read against the defect checklist. `long_scope.png`, `combat_scope.png`: the lens fills the scope's rear ring edge to edge with the hall, the blue board and a crew member, no black wedge, no scope tube inside it, a red cross on the middle; outside it the scope body and the room are blurred and fade to black at the corners. `*_shifted.png`: the same with the scope down and right of centre, the picture inside it unmoved and the cross still on the middle. `reflex.png`, `reflex_shifted.png`: the Assault Rifle sharp, nothing blurred or darkened, the Reflex Sight's window clear with the hall behind it and one red dot on the board at the screen's middle; shifted, the window has moved and the dot has not. No missing mesh, magenta, floating part or camera clipping.
- Gate: `tests/run_all.sh` (seed 808065727) passed every suite: static 162, generator 341845, layouts 252, ship_3d 3681, pirate 1946, crew 205, sandbox 111, attachments 1674, raid_smoke 924 checks; total 261 s.

## Owed to playtest

- (human) The lens view feels as it did in the prototype at the chosen settings, with no stutter or shadow flicker.
- (human) Coming up, dropping and a Descope look right with the blur.

## Comments

Built 2026-11-24 on `weapon-attachments-20`.

- `scripts/scoped_view.gd` (`ScopedView`), a node `ScopedView` on the Pirate (`scenes/player_3d.tscn`, `player.scoped_view`): the lens camera in a 1024 px `SubViewport` (`lens_view`, `lens_camera`) that copies the Pirate's camera and renders only while `aim_progress` is above 0 with a lens fitted; the lens material put on the fitted scope's `<Model>_RearGlass`; the Reflex Sight's window (`ReflexSight_Window`, a 0.029 by 0.027 m quad on `ReflexSight_SightTip`, riding with it); the surround on a CanvasLayer under the HUD, at the user's blur 2.0 and edge dark 1.0, by `aim_progress`. Seams: `glass()`, `lens_material()`, `lens_rendering()`, `surround_amount()`.
- Shaders lifted from the prototype into `resources/shaders/scope_lens.gdshader` (the lens and the Reflex window: the Viewmodel's FOV and depth scale by hand, picture and reticle by screen position, the rim darkened from the glass's own mesh position since the rear glass has atlas UVs) and `scope_surround.gdshader`. The rejected overlay was left out.
- `Viewmodel`: `LAYER` (2), every mesh of a mounted model put on it; `EYE_TO_GLASS` (0.06 m) sets the aimed pose's depth through a lens (a scope's SightTip is the middle of its rear glass); a `mounted` signal after each mount and fit.
- `WeaponProfile`: `VIEW_AROUND_LENS` (1.25), `view_zoom()` (the camera's aimed zoom: 1.25 through a lens, else `ads_zoom`), `aims_through_sight()` (a Sight Attachment fitted). The Pirate's camera zooms by `view_zoom()`; the mouse still divides by `ads_zoom`. `hip_fov()` added on the Pirate.
- `Hud`: the crosshair's lines and dot hide while aimed with `aims_through_sight()`; the hit marker still shows. `crosshair_shown()` added.
- Found: the Reflex Sight's model has a glowing dot of its own in the middle of its window (`reflex_dot` in `tools/blender/attachments.py`), fixed to the gun: it hid the reticle when centred and would be a second dot when the gun moves. `ScopedView` gives the Viewmodel's Reflex Sight a copy of its mesh without it; a menu preview (ticket 22) built with `WeaponModel` alone still shows it. Taking `reflex_dot` out of the Blender script and re-exporting would remove it everywhere.
- Seen, not changed: the Reflex Sight's hood sits in front of the lower part of its window from the eye (`reflex.png`).
- Checks in `tests/scoped_view_checks.gd`, run from `test_pirate.gd`; `tests/shots.sh scoped` documented in `docs/agents/validation.md` with a coverage row.
