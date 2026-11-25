Status: ready-for-agent
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

- [ ] (agent) Aimed with the Long Scope, a target 1 m wide at 50 m spans in the lens the screen width it would span at 5.01x zoom, within 5%; with the Combat Scope, at 2.48x.
- [ ] (agent) Aimed through a lens the main camera's zoom is 1.25x, within 2%.
- [ ] (agent) With the gun shifted 6 mm off its aimed pose, the reticle's centre is still the screen's centre within 2 px, for both scopes and the Reflex Sight.
- [ ] (agent) Aimed through a lens, turn rate per unit of mouse is the hip rate divided by the lens's zoom, within 2%.
- [ ] (agent) The lens camera does not render at the hip or with a gun's own sights.
- [ ] (agent) The HUD crosshair is hidden while aimed through a lens or a Reflex Sight and shown otherwise.
- [ ] (agent) `tests/shots.sh scoped`: the lens picture fills the lens with no black wedge, the scope's own tube is not seen inside it, the surround is blurred and dark at the corners, the Reflex window is clear.
- [ ] (agent) `tests/run_all.sh` passes.
- [ ] (human) The lens view feels as it did in the prototype at the chosen settings, with no stutter or shadow flicker.
- [ ] (human) Coming up, dropping and a Descope look right with the blur.

## Comments
