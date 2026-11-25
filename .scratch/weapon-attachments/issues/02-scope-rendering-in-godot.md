Type: research
Status: resolved
Blocked by: none
Map: ../map.md

# How a magnified scope is drawn in Godot 4

## Question

What are the ways to draw a first-person magnified scope in Godot 4, and what does each cost? Cover at least: lowering the camera field of view with the scope model in front of the eye; a full-screen overlay with a reticle and black surround; a picture-in-picture lens drawn from a second camera into a SubViewport and shown on the lens mesh; and a screen-reading shader on the lens that magnifies what is behind it. For each: how it is set up in Godot 4 (nodes, shader inputs, render layers), what it costs to render, known problems (the Viewmodel's own field of view and render layer, depth and clipping of a weapon drawn close to the camera, mouse sensitivity under zoom), and which shipped games or documented Godot projects use it. The game's Viewmodel is drawn in front of the camera by `scripts/viewmodel.gd` and Aim Down Sights already zooms by `ads_zoom`.

## Answer

Full note: `docs/research/scope-rendering-in-godot.md` on branch `research/scope-rendering-in-godot` (pushed, never merged). Nothing was run in the engine; claims come from the Godot docs, engine source and PR 93142, or are marked as derived. Godot 4.7, Forward+.

- **Lower the camera field of view** (what the Marksman Rifle does today at 3.0x): no extra cost. The Viewmodel's materials use `fov_override`, so the weapon keeps its size while the world zooms. The whole screen magnifies, not just the lens.
- **Full-screen overlay**: near free, reticle exactly centred. The weapon is hidden, so sway, recoil and reload clips disappear and the change is a cut.
- **Picture-in-picture SubViewport on the lens**: the only way to get a magnified lens inside an unmagnified view. Costs a second scene render. Needs the Viewmodel on its own render layer, left out of the scope camera's `cull_mask`. A custom lens shader must repeat the FOV override and `Z_CLIP_SCALE` itself, because `_flag_materials` in `scripts/viewmodel.gd` skips a `ShaderMaterial`. An open Godot 4.7 forum report describes shadow flicker with this setup.
- **Screen-reading lens shader**: cheap, but a digital zoom, and transparent objects are missing from the screen texture, so the bolt (alpha material) would vanish in the lens.

Recommended for the scoped view prototype: lowered field of view with a real scope model and lens reticle, and picture-in-picture beside it; the overlay as fallback; the screen-reading shader only for optics of about 2x or less.

Not confirmed: any shipped Godot game using these, the measured cost of the SubViewport, one-frame lag, double tone mapping, a first-party mouse sensitivity formula.
