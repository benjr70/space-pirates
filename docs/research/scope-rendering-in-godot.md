# Scope rendering in Godot 4

Research note, 2026-11-24. Question: what are the ways to draw a first-person
magnified scope in Godot 4, what does each cost, and how would each sit with
how the Viewmodel is drawn today.

The repo is on **Godot 4.7, Forward+** (`project.godot`:
`config/features=PackedStringArray("4.7", "Forward Plus")`). Engine facts below
come from the Godot docs `latest` branch, whose pages were headed "Godot Engine
4.7 documentation" on the day they were read, and from the engine's `master`
source. Nothing here was run in the engine: every claim is from reading, and
the section "Not confirmed" lists what a prototype has to settle.

Each claim carries a source number, listed at the end. A claim marked
**(derived)** is my own reasoning from the cited facts and the repo's code, not
something a source states.

## Summary

| | Technique | Extra render cost | Fits the Viewmodel today | Main weakness |
|---|---|---|---|---|
| a | Lower `Camera3D.fov`, scope model in front of the eye | None | Already what the game does | Whole screen magnifies, not just the lens |
| b | Full-screen overlay, reticle and black surround | One alpha-blended full-screen quad | Easy: hide the Viewmodel, add a HUD layer | No weapon on screen; hard cut in and out |
| c | Picture-in-picture: second camera into a SubViewport, shown on the lens | A second render of the scene at the lens resolution | Needs a render layer for the Viewmodel and a lens material that repeats the FOV and depth flags | Cost, and several reported SubViewport problems |
| d | Screen-reading shader on the lens | One screen copy per frame | Lens shader must repeat the FOV and depth flags by hand | Magnifies existing pixels; transparent things (the Bolt) vanish in the lens |

Recommendation: prototype **(a) with a proper scope model and lens reticle**
first, since it is free and is what the code already does at 3.0x for the
Marksman Rifle, and prototype **(c)** beside it as the only technique that
gives a magnified lens inside an unmagnified view. Build (b) only as the
fallback if (a) looks wrong at high zoom. (d) is worth a quick look only for a
low-power optic (about 2x or less).

## How the Viewmodel is drawn now

Read from `scripts/viewmodel.gd`, `scripts/player_3d.gd`,
`scripts/weapon_profile.gd` and `scenes/player_3d.tscn`.

- The Viewmodel is a `Node3D` under the Pirate's one `Camera3D` (`fov = 75`,
  `near = 0.05`), in the main viewport. There is no SubViewport and no second
  camera, and no node sets `layers` or `cull_mask`: everything is on render
  layer 1.
- `Viewmodel._flag_materials` duplicates every surface material of a mounted
  weapon and sets four `BaseMaterial3D` properties on the copy:
  `use_fov_override` / `fov_override = 50` and `use_z_clip_scale` /
  `z_clip_scale = 0.35`. It uses `Object.set`, so a surface whose material is
  a `ShaderMaterial` gets nothing and no error.
- Zoom is the camera's field of view: `_animate_camera` eases `camera.fov`
  toward `2·atan(tan(hip_fov/2) / ads_zoom)`. `ads_zoom` is 1.15 to 1.6 for
  most weapons and **3.0 for the Marksman Rifle**, which is a camera FOV of
  about 28.7 degrees.
- Mouse turn is divided by `ads_zoom` while aimed (`look`).
- Aim Down Sights moves the Holder so the mesh's `SightTip` marker sits on the
  camera axis (`pose_ads = (-sight.x, -sight.y, -ads_distance)`).
- Shots are aimed from the camera's forward axis; `muzzle_point` corrects the
  bolt's start for the weapon's narrower FOV.
- The Bolt's material is alpha-transparent (`scenes/projectile_3d.tscn`,
  `transparency = 1`).

Two consequences hold for every technique below **(derived)**:

1. Because the weapon's materials override the projection, **the weapon does
   not zoom when `camera.fov` narrows**. The world magnifies and the weapon
   keeps its size on screen. That is what a real optic looks like from behind,
   and the game gets it for nothing.
2. A point on the camera axis projects to the screen centre under any
   symmetric perspective projection, so `SightTip` stays centred in Aim Down
   Sights whatever the two FOVs are. Sway, bob and recoil move it off the axis,
   where the weapon's on-screen offset follows the 50-degree projection, not
   the camera's.

### What the engine says about those material flags

- `fov_override`: "Overrides the Camera3D's field of view angle (in degrees)."
  It behaves as if set on a camera with `keep_aspect = KEEP_HEIGHT` and may
  look wrong on a non-perspective camera [1].
- `z_clip_scale`: "Scales the object being rendered towards the camera to
  avoid clipping into things like walls." Lighting and shadows keep working,
  but screen-space effects such as SSAO and SSR may break at low scales [1][2].
- In the engine source the FOV override is a few lines in the generated vertex
  shader: it rewrites `PROJECTION_MATRIX[0][0]` and `[1][1]` from
  `fov_override`, skipped when `IN_SHADOW_PASS` is true; the depth flag is the
  single line `Z_CLIP_SCALE = z_clip_scale;` [3]. A custom lens shader can
  repeat both.
- Both arrived in Godot 4.5 through pull request 93142, written to replace the
  overlaid-SubViewport way of drawing first-person weapons, which its author
  calls "cumbersome for users and error prone" and "really bad from a
  performance standpoint" [4]. The same thread records the limits: it "totally
  breaks when multiple objects need to be sorted against each other",
  screen-space effects stop affecting the model, a mesh parented to the camera
  can be culled wrongly unless given a large custom AABB, and a reviewer notes
  the viewport approach "is still relevant if you wish to make your weapon
  model translucent" [4].

## (a) Lower the camera FOV, scope model in front of the eye

**Setup.** One `Camera3D`; set `fov` to `2·atan(tan(hip/2) / zoom)` while
aimed. `fov` is the vertical angle when `keep_aspect` is `KEEP_HEIGHT` (the
default), and applies only in perspective mode [5]. The scope is ordinary
geometry on the weapon mesh: a tube, and a lens that is either a hole or a
transparent quad carrying the reticle texture. No shader inputs, layers or
cull masks are needed.

**Cost.** None extra. A narrower frustum culls more, so a scoped frame is if
anything cheaper **(derived)**.

**Problems.**

- The whole screen magnifies, including what is outside the scope tube. At
  3.0x the peripheral view is as zoomed as the lens. Whether that reads as a
  scope or as binoculars with a gun in the way is a look to judge by eye.
- Viewmodel with its own FOV: an advantage here, as above. The scope body
  stays the same size while the world zooms.
- Near plane and depth: unchanged from today. The weapon is squashed in depth
  by `z_clip_scale`, so anything that must sort against it by depth (a lens
  quad behind an eyepiece ring, say) is working with compressed depth; the
  pull request warns about exactly this sorting case [4].
- Mouse sensitivity: dividing turn rate by the zoom, as `look` does, keeps
  on-screen speed at the crosshair constant when zoom is defined by the tangent
  ratio, as `_animate_camera` defines it **(derived)**. EA's notes on
  Battlefield's Uniform Soldier Aiming describe the same goal in words [12];
  no first-party source for the exact formula was found.
- Reticle centring: a reticle on the lens is centred only while the lens
  centre is on the camera axis. Sway, bob and recoil move it off the axis
  while shots still go down the camera axis, so the reticle and the point of
  impact part by the size of the offset. Today the same is true of the front
  sight. A reticle drawn by the HUD at screen centre does not have this
  problem but does not move with the weapon.

**Who uses it.** This is the game's own current technique. It is the common
"zoom the camera" method that the Bodycam developers contrast with
picture-in-picture, as reported second-hand [11]. No first-party write-up of a
shipped Godot game using it was found.

## (b) Full-screen overlay with reticle and black surround

**Setup.** A `CanvasLayer` above the 3D view holding a full-rect `TextureRect`
(a scope texture with a transparent circle) or a `ColorRect` with a
`canvas_item` shader that draws the black surround and reticle. While scoped:
hide the Viewmodel (`visible = false`), show the overlay, and lower
`camera.fov` as in (a). No screen texture, layers or cull masks.

**Cost.** One alpha-blended full-screen quad, and the weapon is not drawn.
Effectively free.

**Problems.**

- No weapon on screen, so the Viewmodel's sway, bob, recoil and reload clips
  are invisible while scoped, and the change in and out is a cut unless a fade
  or a short blur covers it.
- Viewmodel FOV and near-plane clipping: none, since the weapon is hidden.
- Reticle centring: trivially exact, since the overlay is anchored to the
  viewport centre and shots go down the camera axis. The project stretches
  with `window/stretch/aspect="expand"`, so the overlay must keep the circle
  round and cover the extra width with black **(derived)**.
- Mouse sensitivity: as (a).
- The Descope roll and camera kick still move the world behind a fixed
  overlay; whether that looks right is for the eye.

**Who uses it.** One developer's devlog for an Unreal Engine shooter records
replacing a two-camera scope with exactly this: the old scope "needed two
cameras and everything had to be rendered twice, causing big frame drops", and
the overlay version "now has the same performance as any other gun" [10]. The
technique is widely associated with older shooters; no first-party source for
a named title was found, and none for a Godot game.

## (c) Picture-in-picture: second camera, SubViewport, lens mesh

**Setup.**

- A `SubViewport` with a `Camera3D` child. A camera always displays on its
  closest parent viewport, and a SubViewport by default uses the same world as
  its parent, so the scope camera sees the game world with no extra work
  [6]. The SubViewport draws nothing by itself: its `ViewportTexture`
  (`get_texture()`) must be drawn somewhere, here on the lens [7][8].
- Each frame, copy the main camera's (or the scope's) global transform to the
  scope camera and set its `fov` to the narrow angle.
- **Render layers.** The scope camera must not draw the weapon, or it sees the
  inside of its own scope. `Camera3D.cull_mask` selects which
  `VisualInstance3D.layers` a camera renders; all 20 user layers by default
  [5]. So: put every Viewmodel mesh on a layer of its own (say 2) and clear
  that bit on the scope camera with `set_cull_mask_value`. Today nothing in
  the repo sets layers, so this is new plumbing in `_mount`.
- **Lens material.** The lens surface shows the ViewportTexture, unshaded. A
  `StandardMaterial3D` with the texture as albedo would pick up the FOV and
  depth flags from `_flag_materials` unchanged. A custom shader (needed for a
  reticle, vignette or eye-relief effect) is a `ShaderMaterial`, which
  `_flag_materials` silently skips, so the shader must set `Z_CLIP_SCALE` and
  rewrite `PROJECTION_MATRIX` itself, as the engine's generated code does [3].
  A `ViewportTexture` is always local to its scene [8], so it is safest
  assigned in code after the model is mounted.
- **Update mode.** `render_target_update_mode` chooses when the SubViewport
  re-renders: `UPDATE_DISABLED`, `UPDATE_ONCE`, `UPDATE_WHEN_VISIBLE` (the
  default), `UPDATE_WHEN_PARENT_VISIBLE`, `UPDATE_ALWAYS` [7]. Set it to
  disabled outside Aim Down Sights and always while aimed.

**Cost.** A second render of the 3D scene every scoped frame: culling, depth,
opaque and transparent passes and that viewport's post-processing, at the
SubViewport's `size` [6][7]. The levers are the size (a lens covering a third
of a 1080p screen's height needs about 360 pixels across), the viewport's own
`msaa_3d` and `scaling_3d_scale` [9], the narrow FOV (which culls most of the
scene), and the update mode. The engine's own rendering lead calls the
SubViewport approach to weapons "really bad from a performance standpoint"
[4], though that remark is about a full-screen weapon overlay, not a small
lens. Second-hand reports from other engines agree that this is the expensive
option [10][11]. No measured Godot figure was found.

**Apparent magnification (derived).** The lens is drawn with the weapon's FOV,
not the camera's, so its size on screen comes from the 50-degree projection. A
lens of radius `r` at distance `d` from the eye covers a world half-angle
`θ` in the main view with `tan θ = (r/d) · tan(camera_fov/2) / tan(25°)`. The
magnification the player sees is `tan θ / tan(scope_fov/2)`. Changing
`fov_override`, `ads_distance` or the main camera's FOV therefore changes the
scope's apparent power; the scope camera's FOV has to be worked out from them.

**Problems.**

- Viewmodel with its own FOV: handled by the layer split above; the lens
  material must carry the override or the lens will not sit in its tube.
- Depth and near plane: the lens is a camera-close, depth-squashed surface
  that has to sort against the eyepiece ring around it [4].
- A flat texture mapped by the lens's UVs looks like a television screen in a
  tube, not a view through glass, because the image does not shift as the
  weapon sways. A community Godot shader fakes this with a parallax factor, an
  eyebox fade and a moving scope shadow [13].
- Reticle centring: a reticle drawn in the lens shader at the UV centre stays
  centred in the lens and rides with the weapon. Whether it marks where shots
  land depends on where the scope camera points. If it copies the main camera,
  the lens centre shows the shot line exactly, even when the lens is off axis
  **(derived)**.
- Mouse sensitivity: the main camera need not zoom at all, so there are two
  magnifications, the view's and the lens's. `look` divides by `ads_zoom`
  only; a scope would need the Weapon Profile to say which one the hand
  follows. Scaling by the lens magnification makes the lens image track the
  hand; scaling by the view's makes the surround track it.
- Reported faults, none confirmed against 4.7 here: a forum user on Godot 4.7
  reported main-scene shadows flickering whenever a texture showing a
  Camera3D SubViewport (apparently a scope) was visible, worked around by
  changing that camera's cull mask, with no cause found [14]; the viewports
  docs warn that a texture read before the frame has drawn is empty [6], and
  forum threads report a one-frame wait when a SubViewport wakes up.
- `Viewport.use_hdr_2d` textures are linear-encoded and "may look darker than
  normal when displayed directly" [8]; whether a scope image shown on an
  unshaded 3D surface is tone-mapped twice was not confirmed.

**Who uses it.** In Godot: a community shader with a demo project, "3D
Realistic Picture-in-picture scope" (MIT, July 2025), takes one viewport
texture from a 3D camera for the view and one from a 2D scene for the reticle
[13]. No shipped Godot game was confirmed to use it. Outside Godot it is the
documented approach in Arma Reforger's modding wiki (found by search, not
read) and is the one players name for Escape from Tarkov, Squad and
Insurgency: Sandstorm; those attributions come from community posts, not from
the developers.

## (d) Screen-reading shader on the lens

**Setup.** A spatial shader on the lens surface declares
`uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;`
and samples it at `centre + (SCREEN_UV - centre) / magnification`, where
`centre` is the lens centre in screen UV (0.5, 0.5 when the lens is on the
camera axis; otherwise projected in the vertex function or passed in from
script) [15][2]. No second camera, layers or cull masks. The engine's own
refraction feature is built the same way, with a depth comparison added [3].

**Cost.** One copy of the screen per frame: "In 3D, the screen is copied after
the opaque geometry pass, but before the transparent geometry pass" [15].
Cheap next to (c). Mipmaps are generated only if the sampler's filter asks for
them [15].

**Problems.**

- It adds no detail. At 3x the lens shows one ninth of the pixels it covers,
  stretched; it is a digital zoom **(derived)**.
- **Transparent objects are missing from the lens**: "transparent objects will
  not be captured in the screen texture" [15]. The Bolt's material is
  alpha-transparent, so bolts in flight would be invisible through the scope,
  as would any transparent particles or glass.
- A material that reads the screen texture is itself treated as transparent
  [15], so the lens sorts with other transparent objects by node position,
  which the docs warn is often wrong for overlapping objects [16].
- The docs warn the screen texture "may capture some opaque objects that are
  in front of the object using the screen texture" [15]. The weapon is opaque
  and is in the copy. Sampling toward the lens centre only ever reads pixels
  from inside the lens outline, so the tube itself is not pulled in, but
  anything opaque seen through the lens, such as the front sight or barrel, is
  magnified with the world **(derived)**. A forum thread on a 3D magnifying
  glass hit the first form of this (the glasses appeared inside their own
  lens when scaling about the screen centre) and ended with an unfixed
  artefact [17].
- Viewmodel FOV and depth: as with (c), the lens shader is a `ShaderMaterial`
  and must repeat the FOV override and `Z_CLIP_SCALE` itself [3].
- Reticle centring and mouse sensitivity: as (c). The lens can only show what
  the main camera already sees, so the lens centre is the screen centre when
  the lens is on the axis.
- It can be stacked on (a): a modest camera zoom plus a further lens zoom.

**Who uses it.** No shipped game or finished Godot project was found. The
forum thread above [17] is the only documented Godot attempt found, and it is
a magnifying glass, not a scope. The Bodycam developers describe a custom
in-pipeline optic shader as their alternative to picture-in-picture, reported
second-hand and specific to Unreal [11].

## Not confirmed

- **No shipped Godot game was confirmed to use any of the four.** Road to
  Vostok's Godot port notes mention optics with custom red-dot and holographic
  shaders; nothing found says how its magnified scopes are drawn.
- **No measured cost** for a scope-sized SubViewport in Godot 4.7 Forward+.
  Whether shadow maps are rendered again for the second viewport was not
  established from the docs or source.
- **The 4.7 shadow-flicker report** [14] has no root cause and may or may not
  affect this project.
- **One-frame lag** of a SubViewport image behind the main view while the
  camera turns: reported in forum threads for other setups, not confirmed for
  a camera whose transform is copied in `_process`.
- **Double tone mapping** of a SubViewport image shown on a 3D surface.
- **Screen texture resolution** under MSAA, TAA or 3D scaling. The project
  sets none of these in `project.godot`.
- Whether `z_clip_scale = 0.35` leaves enough depth for a lens quad to sort
  cleanly against an eyepiece ring.
- The Valve developer wiki page on zoom sensitivity refused the request, and
  EA's page gives no formula, so the sensitivity rule above rests on the
  geometry alone.
- Not investigated: a `CompositorEffect` post-process, and the stencil modes
  added in 4.5, which the shader reference marks experimental and readable
  only in the transparent pass [2]. Either might mask a lens region for a
  hybrid of (a) and (b).

## Sources

1. Godot docs, `BaseMaterial3D` class reference, and its source XML:
   <https://docs.godotengine.org/en/latest/classes/class_basematerial3d.html>,
   <https://github.com/godotengine/godot/blob/master/doc/classes/BaseMaterial3D.xml>
2. Godot docs, Spatial shaders reference (`Z_CLIP_SCALE`, `PROJECTION_MATRIX`,
   `IN_SHADOW_PASS`, `POSITION`, stencil notes):
   <https://docs.godotengine.org/en/latest/tutorials/shaders/shader_reference/spatial_shader.html>
3. Godot source, `BaseMaterial3D::_update_shader` in
   `scene/resources/material.cpp`:
   <https://github.com/godotengine/godot/blob/master/scene/resources/material.cpp>
4. Godot pull request 93142, "Add new StandardMaterial properties to allow
   users to control FPS-style objects", merged for 4.5:
   <https://github.com/godotengine/godot/pull/93142>
5. Godot docs, `Camera3D` class reference:
   <https://docs.godotengine.org/en/latest/classes/class_camera3d.html>
6. Godot docs, Using Viewports:
   <https://docs.godotengine.org/en/latest/tutorials/rendering/viewports.html>
7. Godot docs, `SubViewport` class reference:
   <https://docs.godotengine.org/en/latest/classes/class_subviewport.html>
8. Godot docs, `ViewportTexture` class reference:
   <https://docs.godotengine.org/en/latest/classes/class_viewporttexture.html>
9. Godot docs, `Viewport` class reference:
   <https://docs.godotengine.org/en/latest/classes/class_viewport.html>
10. Developer devlog, "Optimized Sniper Scope" (Unreal Engine project):
    <https://desertfoxdev.itch.io/ww2fps/devlog/623839/optimized-sniper-scope>
11. TweakTown report of the Bodycam developers' devblog video (second-hand):
    <https://www.tweaktown.com/news/113239/bodycam-develops-in-house-optics-shading-technique-for-scopes-in-unreal-engine-5-with-no-performance-loss/index.html>
12. EA, "Dev Notes: Uniform Soldier Aiming" (Battlefield 2042):
    <https://www.ea.com/en/games/battlefield/battlefield-2042/news/dev-notes-uniform-soldier-aiming>
13. Godot Shaders, "3D Realistic Picture-in-picture scope" by squid_iwl:
    <https://godotshaders.com/shader/3d-picture-in-picture-scope-with-eyebox-reticle-scope-shadow-and-fake-parallax/>
14. Godot forum, "3D Lighting flickers when a texture has a subviewport of a
    camera3D" (Godot 4.7, unresolved):
    <https://forum.godotengine.org/t/3d-lighting-flickers-when-a-texture-has-a-subviewport-of-a-camera3d/143886>
15. Godot docs, Screen-reading shaders:
    <https://docs.godotengine.org/en/latest/tutorials/shaders/screen-reading_shaders.html>
16. Godot docs, 3D rendering limitations:
    <https://docs.godotengine.org/en/latest/tutorials/3d/3d_rendering_limitations.html>
17. Godot forum, "How do I get started with a 3D Magnifying Glass Effect":
    <https://forum.godotengine.org/t/how-do-i-get-started-with-a-3d-magnifying-glass-effect/72731>
