# How to draw a Smoke cloud that looks like smoke

Research note, 2026-11-26. Question
(`.scratch/equipment/issues/14-smoke-rendering.md`): how do games draw a smoke
grenade's cloud so it looks like thick, lit, billowing smoke, and which of
those ways can be built in Godot 4.7 (Forward+)? The gameplay is fixed by
`12-smoke-cloud.md`: a cloud is a set of 0.75 m cells that flood-fills the
space it bursts in, with holes that open and close. Only the drawing is open.

This note builds on section (c) of `docs/research/grenade-effects-in-godot.md`
(branch `research/grenade-effects-in-godot`) and does not repeat its engine
basics.

Engine facts were read from the engine's `4.7-stable` tag and the `4.7` branch
of the documentation repository. **Nothing here was run in the engine.** Every
shader in this note is an outline put together from documented built-ins, not
tested code. Each claim carries a source number, listed at the end. A claim
marked **(derived)** is my own reasoning from the cited facts and the
prototype's code. Sources marked **[community]** are a fan recreation, a
third-party site or a forum, not a primary source.

## Summary

- **Valve has published what CS2's smoke does, not how it is drawn.** Its page
  and release notes confirm a volumetric cloud that fills space, is lit by the
  map's lighting, takes and (since February 2024) casts shadows, and is pushed
  aside by bullets and HE grenades [1][2]. I found no Valve talk, paper or post
  on the voxel grid, the ray march or the noise. Everything said about those
  comes from fan recreations and one third-party reverse-engineering page
  [3][4], and is labelled so below.
- **The prototype's look is a limit of the froxel grid, not of its tuning.** At
  the prototype's settings one fog cell 8 m away is about 0.2 m wide and 0.56 m
  deep, the fog is blurred by default, and a change takes about 22 frames to
  show 90 % because of temporal reprojection [5][6][7] **(derived)**. A hole
  that lasts 1.5 s and a bloom of 0.25 s cannot be crisp in that.
- **Recommended: one box per cloud with a ray-marched spatial shader** that
  reads the cell grid as a 3D texture, erodes its edge with scrolling 3D noise,
  stops at the depth buffer, and is lit by the engine's own lights through
  `LIGHT_VERTEX` and a custom `light()`. This is the same family of technique
  the CS2 recreations use [3], it draws holes the frame they open, and it is
  right with the camera inside.
- **Fallback: a cheap unlit version of the same box for opacity, dressed with
  lit flipbook puffs on the surface cells.** It trades the firm, continuous
  surface for a look made of sprites, and it is the usual way shooters drew
  smoke before volumes [1][8][9].
- **No source gives a frame cost for any of this in Godot.** The numbers that
  exist are from other engines and other hardware (see "Frame cost"). The
  prototype must measure.

| Technique | Looks like | Holes | Lit by the ship's lights | Camera inside | Cost driver | Verdict |
|---|---|---|---|---|---|---|
| `FogVolume`, default froxels (the prototype) | Soft grey haze, no surface | Smear over about 0.4 s, 0.2 to 0.6 m blur | Yes, single scattering, dim without emission [5] | Right by nature | Froxel count, whole view [5] | Rejected by the user |
| `FogVolume`, froxels raised to 128 to 192 | Sharper haze, still no firm surface | Sharper, flickers with reprojection off | Yes | Right by nature | 8 to 27 times the froxels of the default **(derived)** | Not enough; see below |
| Ray-marched box shader over the cell texture | Firm surface, wisps, dark crevices | Cut the frame they open, sub-cell edge from noise | Yes, through `LIGHT_VERTEX` + `light()`; shadow maps included [10][11] | Right if back faces are drawn and the ray starts at the eye | Pixels covered x steps x texture reads | **Recommended** |
| The same in a `CompositorEffect` at half resolution | Same, slightly softer | Same | Only what the script passes in | Right | A quarter of the pixels, plus an upscale [12][13] | Upgrade if full resolution is too slow |
| Lit flipbook puffs (`GPUParticles3D` or `MultiMesh`) | Billowing sprites; flat when close [9] | Puffs vanish per cell; edge is ragged | Per-pixel or per-vertex; six-way maps for depth [9] | Bad: overdraw and near-plane pops [14] | Overdraw [14] | Dressing, or the fallback's skin |

## Counter-Strike 2

### What Valve states

From the Counter-Strike 2 page [1]:

- "Smoke Grenades are now dynamic volumetric objects that interact with the
  environment, and react to lighting, gunfire, and explosions."
- "Reacts to Lighting: In Counter-Strike 2 smoke particles work with the
  unified lighting system allowing for more realistic light and color."
- "Expands to fill spaces naturally: Now the smoke will seep out of opened
  doorways and broken windows, go down and up stairs, as well as expand in
  long corridors and combine with other smokes."
- "Bullets and HE grenades can push smoke to briefly clear sightlines or expand
  occlusion."

From Valve's release notes [2], the lines that say something about the method:

| Date | Line |
|---|---|
| 2023-03-24 | "Smoke bullet holes are now fixed relative to the firstperson camera." and, under Graphics, "Fixed smoke cloud volume lighting." |
| 2023-03-30 | "HE grenades no longer affect smokes through walls." |
| 2023-06-06 | Under the heading "VOLUMETRIC SMOKE": "Improved lighting/rendering when smoke overlaps multiple distinctly lit regions." "HE grenade effect times on smoke has been reduced." "Shotguns now create larger holes in smoke volumes." |
| 2023-06-08 | "Fixed smoke expansion algorithm when detonating very close to a wall." |
| 2023-08-15, 2023-08-31 | "Minor adjustments to smoke cloud shape", "Continued iterating on smoke shape" |
| 2023-09-27 | "Adjusted smoke behavior to cover cases where smoke would stop less than a player's height above the ground" |
| 2024-02-06 | "Smokes now cast shadows" and "Rendering and animation have been improved" |
| 2024-02-08 | "Adjusted visibility of player silhouettes in smoke" |
| 2024-02-12 | "Fixed ring artifacts that could appear on smoke particles." |
| 2024-02-28 | "Fixed smoke shadow rendering issues and improvements to perf" |
| 2024-10-28 | "HE grenade explosions within smoke now clear the accumulated smoke screen effect on players inside that smoke within range of the HE grenade explosion." |
| 2026-04-29 | "Improved smoke lighting consistency." |

What these support, and no more:

- The cloud is a **volume** ("smoke cloud volume", "smoke volumes"), grown by
  an **expansion algorithm** that respects walls [1][2].
- It is **lit by the map's lighting**, and a cloud spanning two differently
  lit areas needed special work [2]. Lighting consistency was still being
  fixed three years after launch [2].
- **Shadows cast by the smoke came eleven months after the first test**, and
  needed performance work three weeks later [2]. They are an addition, not
  the base of the look.
- **Holes are per shot, sized per weapon**, and Valve chose to fix a hole
  relative to the shooter's first-person camera [2].
- **A player inside has a separate screen effect** ("accumulated smoke screen
  effect") on top of the volume [2]. The prototype's grey-out is the same
  idea.
- The notes still say "smoke particles" in 2024 [2], so particles are part of
  the effect in some role. Which role is not stated.

### What is not from Valve

I found no Valve talk, paper or post describing how the volume is stored or
drawn. The following is the best available and is **not confirmed by Valve**:

- **[community] Acerola's recreation** (video "I Tried Recreating Counter
  Strike 2's Smoke Grenades", code by Garrett Gunnell, Unity) [3]. Its README
  lists: "Voxel Based Propagation (Limited Flood Fill)", "Mesh Voxelizer",
  "Generalized Volume Ray Marcher", "Tiled Worley Noise Generator", "SDF Based
  Smoke Deformation (Not Performant)". Its author calls it "not a production
  ready asset". I read its ray-march shader; its structure is given in the
  next section because it is the only complete, working source found.
- **[community] memorin.app** [4] claims, from decoding demo files and
  decompiling a July 2026 build's shader: a 32 x 32 x 32 grid of 20-unit
  cells in Morton order; HE blasts kept in a five-entry buffer sent to the
  shader, clearing a 200-unit core with a soft edge to 240 units, leaving 2 %
  density, and recovering over 0.5 to 5 s. It gives no ray-march, noise or
  lighting detail. One site, no independent check, method only summarised.
- **[community] Other recreations** (Unity URP, DX11, Unreal) all follow
  Acerola's design and say so [15]. They are evidence that the design works,
  not evidence of what Valve does.

If memorin's numbers are right, CS2's cell is about half the size of this
project's 0.75 m cell (20 Source units is about 0.38 m at 0.75 inch a unit;
the unit size is from memory, not checked here), and its holes are analytic
shapes handed to the shader, not edits to the grid.

### The recreation's shader, as read [3] [community]

`Assets/Resources/RenderSmoke.compute`, kernel `CS_RayMarchSmoke`, one thread
per screen pixel:

1. Build the camera ray for the pixel. Read the scene depth, rebuild the world
   position behind the pixel, and turn it into a distance along the ray.
2. **Coarse skip**: step 0.4 units at a time, reading the raw voxel, until a
   filled voxel is hit; then step back once "to avoid missing details".
3. **Fine march**, default 64 steps (range 1 to 256) of 0.05 units (range 0.01
   to 0.1), until the scene distance or until the transmittance falls under a
   threshold (default 0.1).
4. **Density** at a sample = trilinear voxel value x (1 - falloff), where
   falloff = a smoothstep of the distance from the burst (and of how far the
   flood fill had travelled to reach the voxel) **plus the noise**. The noise
   pushes the edge in and out; the middle stays full.
5. **Noise**: one 128 x 128 x 128 tiling Worley fbm texture generated at
   start, sampled at `pos / smokeSize` and scrolled by
   `animationDirection * time` (default `(0, -0.1, 0)`).
6. **Bullet holes**: a list of tapered capsules (origin, direction, two
   radii). The sample's distance to each capsule, **offset by the noise**,
   goes through `smoothstep(0.75, 1.0, ...)` and multiplies the density. The
   hole is a clean analytic tunnel with a noisy lip, not a change to voxels.
7. **Light**: from each dense sample, a second march of 8 steps (range 1 to
   32) of 0.25 units straight up, summing density; the light reaching the
   sample is `exp(-sum)`. Colour adds
   `light x that x transmittance x phase x scattering x density`. The phase
   function is Henyey-Greenstein by default.
8. Output colour and transmittance to textures at **full, half or quarter
   resolution**, upscaled with an optional bicubic filter, then composited.

Points 2, 3 and 8 are its cost controls. Its README says the SDF deformation
is "not performant"; it gives no timings.

## Why the prototype looked the way it did

The prototype sets `volumetric_fog_length = 40` and leaves the rest at
defaults (`proto_smoke.gd` on `prototype/smoke-cloud`).

- **Froxel depth.** The froxel grid is 64 x 64 x 64 by default
  (`volume_size`, `volume_depth`) [6]. Slice `i` of `N` sits at depth
  `length x ((i + 0.5) / N) ^ detail_spread` [7], with `detail_spread` 2.0 by
  default [16]. With length 40 and 64 slices, the slice at 8 m is about
  0.56 m thick and the slice at 4 m about 0.40 m **(derived)**.
- **Froxel width.** The base size is 64 across the view, "scaled by the
  aspect ratio of the screen" [6]. Taking 64 over the view's height at 8 m
  and a 75 degree vertical field of view (both assumed), that is about 0.19 m
  each **(derived)**.
- **Blur.** `use_filter` is on by default and "substantially blurs the fog
  which reduces fine details" [6].
- **Lag.** Temporal reprojection is on by default with amount 0.9 [16]. Each
  frame keeps 90 % of the last, so a change reaches 90 % after about 22 frames
  (0.9 ^ 22 = 0.098), which is 0.37 s at 60 frames a second **(derived)**.
  The documentation names the symptom: moving fog "ghosting" [5][16].
- **Edge.** Fog is single scattering with density that thins exponentially
  along the ray [5], so the rim of any shape is see-through. Raising the
  density to harden it brings "under-sampling artifacts that look like
  stripes" [5].
- **Dim.** "Fog tends to need a little bit of emission" because only single
  scattering is computed [5].

### Can `FogVolume` ever be crisp enough?

Sharper, yes. Smoke-like, no **(derived)**.

- `volume_size` 192, `volume_depth` 128 and `volumetric_fog_length` 20 give
  froxels about 0.06 m wide and 0.2 m deep at 8 m, finer than a 0.75 m cell
  **(derived from [6][7])**. Turning `use_filter` off and reprojection off
  removes the blur and the lag [6][16].
- The cost: the fog shader "is run for every froxel that is touched by an
  axis-aligned bounding box" of the volume [17], and every froxel is lit.
  Three times the size on two axes and twice the depth is about eighteen
  times the default grid's froxels **(derived)**.
  The docs say only "set a larger size for more detailed fog, set a smaller
  size for better performance" [6]; no timings.
- With reprojection off, "the per-frame temporal jitter" can show [16].
- It still has no firm surface, no self-shadow and no dark crevices; it is
  better fog. It also changes fog for the whole ship, not one cloud.

Use it only if a faint haze round the cloud is wanted as dressing.

## Techniques

### 1. Ray-marched volume

**How it works.** For each pixel the cloud covers, walk along the view ray
through the volume, read a density at each step, and accumulate opacity by
Beer's law and colour by how much light reaches each sample. Guerrilla's
cloud talk is the primary reference for the look [18]:

- **Shape and detail are separate.** A low-frequency shape (here: the cell
  grid) is eroded by higher-frequency noise: "the high detail noise is always
  applied as an erosion from the edge of the base cloud shape" [18]. This is
  what gives a firm surface with wisps instead of a haze.
- **Noise.** They use Perlin-Worley and Worley noise at rising frequencies in
  128-cubed textures, and distort the detail noise with curl noise "to fake
  the swirly" motion of fluid [18].
- **Motion** comes from scrolling the noise textures, not from simulating
  [18].
- **Light.** Three parts: Beer's law (less light the more smoke it crossed),
  the Henyey-Greenstein phase function (brighter looking toward the light),
  and a "powdered sugar" term that darkens edges facing the light, which is
  what makes creases read [18].
- **Cost controls.** Cheap samples at a large step until the ray hits
  something, one step back, then full samples; light samples taken in a small
  cone toward the light (6 per sample), switching to the cheap density beyond
  a depth [18].

**What it looks like.** A continuous body with a noisy, firm silhouette that
moves, bright where lit, dark in folds. This is the CS2 look as the
recreations reproduce it [3].

**Cost.** Pixels covered x steps x texture reads per step, plus the light
steps on dense samples. See "Frame cost".

**In Godot 4.7.** Two ways to host it:

- **A spatial shader on a box** (recommended, detailed below). Everything it
  needs is documented: `sampler3D` uniforms [19]; the depth buffer through
  `hint_depth_texture` and the documented reconstruction with
  `INV_PROJECTION_MATRIX` [12]; `CAMERA_POSITION_WORLD`, `MODEL_MATRIX`,
  `VIEW_MATRIX` in `fragment()` [10]; `cull_front`, `depth_test_disabled`
  [10]; a custom `light()` called "for every light in every pixel" [10].
- **A `CompositorEffect`** running a compute shader after the transparent
  pass, with access to the depth buffer [13]. This is how the recreation is
  structured [3] and the only route to drawing the smoke at half resolution,
  since a material cannot choose its own render resolution. It gets no engine
  lighting: every light must be passed in by script.

**Pitfalls in Godot 4.7.**

- **The depth texture is reverse-Z since 4.3**: near is 1.0, far is 0.0, and
  the NDC for reconstruction is `vec3(SCREEN_UV * 2.0 - 1.0, depth)` on
  Forward+ [12]. Older tutorials and most forum shaders get this wrong.
- **Transparent things are not in the depth texture** [10]. A Bolt streak or
  muzzle flash inside or behind the cloud is not clipped per pixel; it is
  sorted against the whole cloud by node position [20]. `sorting_offset` and
  the material's render priority move the cloud in that order [20], but
  cannot make a streak half-hidden.
- **Transparent materials "cannot cast shadows"** [10]. The cloud will not
  shadow the deck. Valve added that late too [2].
- **Banding.** Too few steps shows as rings and slices. The usual cure is to
  offset each pixel's first step by a different amount and let the noise hide
  it **(derived; the recreation instead uses many small steps [3])**.
- **Empty pixels still cost.** With depth testing off, the box's back faces
  run the shader even when the cloud is wholly behind a wall; the shader must
  leave early when the ray's segment is empty **(derived)**.

### 2. Lit flipbook puffs

**How it works.** Camera-facing quads playing a pre-rendered smoke animation
from a sprite sheet. Godot supports this directly: a sprite sheet on a
`StandardMaterial3D` with **Billboard** set to **Particle Billboard**, and
**H Frames** / **V Frames** in **Particles Anim**; the docs name "animated
particles like smoke or fire" as the use [8].

**Lighting them.** Three grades:

- **Per-vertex or per-pixel on a flat quad.** Cheap; reads as lit cards.
  Godot's per-vertex mode exists for exactly "when using particle systems"
  [21].
- **A normal map baked with the flipbook.** Gives round puffs under one light.
- **Six-way lighting.** Six baked lightmaps of the same simulation lit from
  "top, bottom, left, right, front, and back, all relative to the camera",
  packed in two RGBA textures; at run time each light blends the maps by its
  direction [9]. It shows the puff's internal shadow and rim light, which a
  normal map cannot [9]. Unity's own caveat: it "is still a texture sheet and
  not a 3D volumetric effect", looks flat when it receives shadows, and does
  not know about neighbouring puffs [9]. Godot has no built-in six-way
  shader; it would be a custom `light()` blending six channels by `LIGHT`,
  which is given in view space and so already lines up with a camera-facing
  quad **(derived from [10])**. The maps must be baked in Blender or a fluid
  tool [9].

**What it looks like.** From outside at a distance, the best billowing of any
option for the cost, because the motion is a real simulation played back.
Close up and from inside, flat cards that slide and pop.

**Cost.** Overdraw. Transparency is "particularly bad for fill rate, because
every item has to be drawn even if other transparent objects will be drawn on
top", worst "where multiple transparent objects overlap" [14]. A cloud of
about 170 cells (72 cubic metres at 0.75 m [prototype]) needs a puff or two
per surface cell; with the camera inside, most of them cover the screen.

**Pitfalls in Godot 4.7.** Covered in the earlier note's option 2: sorting by
node origin, no order-independent transparency, proximity fade needed at
walls [20][21]. New here: puffs are placed per cell, so a hole is drawn by
hiding the puffs of open cells, and its edge is as ragged as the puffs are
big. CS:GO drew smoke this way, and Valve's notes show the two standing
problems: shaping ("Smoke volumes are now more consistently shaped with the
particles more evenly distributed") and the view from inside ("Increased
minimum distance from the center of a smoke grenade volume in which a
player's view will be completely obscured") [2].

### 3. Drawing the smoke at lower resolution

Smoke is soft, so it survives being drawn into a smaller target and scaled
up. NVIDIA's chapter gives the method and its faults: test against a
downsampled depth buffer (taking the farthest of each four samples reduces
halos), composite with premultiplied colour and accumulated transmittance,
and expect blocky edges where smoke meets nearer geometry unless those pixels
are redrawn at full resolution [22]. Guerrilla's clouds went from about 20 ms
to a 2 ms target by updating 1 pixel in 16 per frame and reprojecting [18].
The recreation offers half and quarter resolution with a bicubic upscale [3].

In Godot this means a `CompositorEffect` with its own low-resolution target
and an upscale-and-blend pass [13]. It is real engineering (compute or raster
pipeline by hand, depth downsample, upscale) and loses engine lighting. Keep
it as the upgrade if technique 1 is too slow at full resolution.

### 4. What other shooters state

- **Rainbow Six Siege** reworked its gas grenade to release "its gas more
  naturally, filling spaces without leaking through solid walls, floors, and
  ceilings" [23]. Ubisoft's note is about the spread, not the drawing.
- **CS:GO**: particle sprites in a round volume, with a full-view obscuring
  rule near the centre [2].
- No primary source was found for Valorant's or Battlefield's smoke drawing.

## What makes it read as smoke and not fog

Collected from the sources above; the mapping to this project is
**(derived)**.

| Quality | What produces it | Source |
|---|---|---|
| A firm outer surface | A sharp threshold on (shape minus noise), and extinction high enough that half a metre is opaque. Fog has neither. | [18][3] |
| Wisps and billows on that surface | High-frequency Worley noise eroding the edge only; the middle stays solid | [18][3] |
| Turbulence that moves | Scrolling the noise; a second layer scrolling another way; curl distortion for swirl | [18][3] |
| Darker in its depth | A short march toward the light summing density (self-shadow), plus the powder term for dark creases | [18][3] |
| Lit by the room | Real lights with distance falloff and wall shadows, not a flat tint | [1][2] |
| A fast bloom that billows | Not stated by any primary source. Driving the erosion amount and the threshold over the 0.25 s bloom, so the surface swells and then settles, is the obvious lever **(derived)** | none |
| Holes that cut | The hole applied in the density function per sample, the frame it happens, with the same noise on its lip | [3][2] |

## Frame cost

No source gives a number for Godot, and Valve gives none for CS2.

| Source | Number | Applies how |
|---|---|---|
| Guerrilla, clouds on PS4 [18] | About 20 ms at full quality; target about 2 ms after quarter-resolution update with reprojection | Sky-filling clouds, 64 to 128 steps plus 6 light samples each. An upper bound on ambition, and proof that resolution is the big lever |
| NVIDIA, GeForce 8800 GTX at 1600 x 1200 [22] | Heavy particles: 25 fps at full resolution, 46 fps at half, 61 fps at quarter | Old hardware; the ratio is the point |
| Godot docs [5][6][14][17] | None. Fog cost follows froxel count and screen size; transparency cost follows overlap | |

Arithmetic for the recommended shader **(derived)**: at 1920 x 1080 with the
cloud filling the screen, 32 steps and two texture reads a step is about 130
million 3D-texture reads a frame before early exit. Early exit matters most
exactly then: inside thick smoke a ray is opaque in a few steps. The costly
view is a large cloud a few metres away seen through thin parts.

**Measuring.** `RenderingServer.viewport_get_measured_render_time_gpu()`
"returns the GPU time taken to render the last frame in milliseconds" [24].
The prototype read 0.2 ms with and without a cloud in an offscreen run, which
`12-smoke-cloud.md` already calls not believable. Measure in a real window,
with the cloud far, near, and with the camera inside.

## Recommended approach

**A ray-marched spatial shader on one box per cloud, lit by the engine.**

Why this one: it is the only option that gives a firm, noisy, moving surface
and holes that cut the same frame; it reads the same cells that block sight,
so what is drawn and what blocks cannot drift apart; it is correct with the
camera inside without a special case; and it stays inside the normal
material system, so the ship's lights and their shadow maps light it with no
script.

### Node setup

- One `MeshInstance3D` per cloud with a `BoxMesh` the size of the cloud's
  grid in metres (the prototype's grid is 32 x 12 x 32 cells of 0.75 m, so 24
  x 9 x 24 m; shrinking the box to the filled cells plus one cell saves
  pixels). Not rotated, not scaled, so one unit in the box is one metre.
- A `ShaderMaterial` with the shader below. One `ImageTexture3D` per cloud
  for the cells; one shared tiling noise `Texture3D` for all clouds.
- `sorting_offset` or render priority set so the cloud draws after other
  transparent things in the room [20]; which way round is a prototype
  question (see "Not confirmed").
- Keep the prototype's full-screen grey-out. Valve keeps a separate screen
  effect for a player inside as well [2].
- Turn `volumetric_fog_enabled` back off unless fog is wanted for something
  else, and add `fog_disabled` to the shader.

### What feeds it from the cell grid

- **Cells texture**: `ImageTexture3D`, `FORMAT_R8`, one texel per cell, value
  = the cell's `now` (0 to 1), exactly what the prototype builds. Sampled
  with `filter_linear, repeat_disable`.
- **Upload only when something changes.** The prototype rebuilds 32 images
  and calls `update()` every frame for every cloud. `now` only changes during
  the bloom, while a hole opens or refills, and during the clear;
  `ImageTexture3D.update()` replaces the whole texture and needs the same
  size and format as `create()` [25]. Skip the upload on frames where no
  cell changed **(derived)**.
- **Uniforms**: grid size in metres, burst age (for the bloom), a small array
  of recent shots (start, end, time) and Blasts (centre, time). Uniform
  arrays are allowed; per-instance uniforms cannot hold textures or arrays
  [19], so each cloud needs its own material.

### Shader outline

Untested; every built-in used is documented in [10][12][19].

```glsl
shader_type spatial;
render_mode cull_front, depth_test_disabled, depth_draw_never,
		specular_disabled, fog_disabled;

uniform sampler2D depth_tex : hint_depth_texture, filter_nearest, repeat_disable;
uniform sampler3D cells : filter_linear, repeat_disable;   // R = fill, 0..1
uniform sampler3D detail : filter_linear, repeat_enable;   // tiling Worley fbm
uniform vec3 grid_m;            // box size in metres
uniform vec3 smoke_colour : source_color;
uniform float extinction = 6.0; // per metre; exp(-6 * 0.5) = 0.05
uniform float erosion = 0.45;
uniform float detail_scale = 0.35;
uniform vec3 wind = vec3(0.02, 0.035, 0.015);

varying vec3 cam_local;   // camera, in box space (metres from the box centre)
varying vec3 frag_local;  // this fragment, in box space

void vertex() {
	cam_local = (inverse(MODEL_MATRIX) * vec4(CAMERA_POSITION_WORLD, 1.0)).xyz;
	frag_local = VERTEX;
}

float fill(vec3 p) {                       // cheap: cells only
	return texture(cells, p / grid_m + 0.5).r;
}

float density(vec3 p) {                    // full: cells eroded by noise
	float v = fill(p);
	if (v <= 0.0) { return 0.0; }
	float n = texture(detail, p * detail_scale + wind * TIME).r;
	n = mix(n, texture(detail, p * detail_scale * 3.1 - wind * TIME * 1.7).r, 0.35);
	// Erode inward only: the surface never leaves the filled cells.
	return smoothstep(0.5, 0.62, v - erosion * n * (1.0 - v * 0.5));
	// Holes from shots and Blasts multiply in here; see "How holes show".
}

void fragment() {
	vec3 dir = normalize(frag_local - cam_local);

	// 1. Where the ray is inside the box. max(.., 0) starts it at the eye
	//    when the camera is inside.
	vec3 inv = 1.0 / dir;
	vec3 a = (-0.5 * grid_m - cam_local) * inv;
	vec3 b = ( 0.5 * grid_m - cam_local) * inv;
	vec3 lo = min(a, b);
	vec3 hi = max(a, b);
	float t0 = max(max(lo.x, max(lo.y, lo.z)), 0.0);
	float t1 = min(hi.x, min(hi.y, hi.z));

	// 2. Stop at the scene. Reverse-Z depth, documented reconstruction.
	float depth = texture(depth_tex, SCREEN_UV).x;
	vec4 view = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);
	t1 = min(t1, length(view.xyz / view.w));
	if (t1 <= t0) { discard; }

	// 3. March. A per-pixel start offset hides the step pattern.
	const int STEPS = 32;
	float dt = max((t1 - t0) / float(STEPS), 0.08);
	float t = t0 + dt * fract(52.9829189 * fract(dot(FRAGCOORD.xy, vec2(0.06711056, 0.00583715))));
	float trans = 1.0;
	float shade = 0.0;
	float t_seen = 0.0;
	for (int i = 0; i < STEPS && t < t1; i++) {
		vec3 p = cam_local + dir * t;
		float d = density(p);
		if (d > 0.001) {
			float a_step = 1.0 - exp(-d * extinction * dt);
			float w = trans * a_step;
			// 4. Self-shadow: three cheap samples upward, cells only.
			float above = fill(p + vec3(0.0, 0.4, 0.0))
					+ fill(p + vec3(0.0, 0.9, 0.0))
					+ fill(p + vec3(0.0, 1.6, 0.0));
			shade += w * mix(0.35, 1.0, exp(-above * 0.9));
			t_seen += w * t;
			trans *= 1.0 - a_step;
			if (trans < 0.02) { break; }
		}
		t += dt;
	}
	float alpha = 1.0 - trans;
	if (alpha < 0.004) { discard; }

	// 5. Hand the engine a point and a normal inside the smoke to light.
	vec3 p_seen = cam_local + dir * (t_seen / alpha);
	const float E = 0.3;
	vec3 grad = vec3(
			fill(p_seen + vec3(E, 0.0, 0.0)) - fill(p_seen - vec3(E, 0.0, 0.0)),
			fill(p_seen + vec3(0.0, E, 0.0)) - fill(p_seen - vec3(0.0, E, 0.0)),
			fill(p_seen + vec3(0.0, 0.0, E)) - fill(p_seen - vec3(0.0, 0.0, E)));
	mat4 to_view = VIEW_MATRIX * MODEL_MATRIX;
	LIGHT_VERTEX = (to_view * vec4(p_seen, 1.0)).xyz;
	NORMAL = normalize(mat3(to_view) * (-grad + dir * -0.25));
	ALBEDO = smoke_colour * (shade / alpha);
	ALPHA = alpha;
}

void light() {
	// Wrapped diffuse: smoke is lit well past the terminator.
	float wrap = clamp((dot(NORMAL, LIGHT) + 0.6) / 1.6, 0.0, 1.0);
	DIFFUSE_LIGHT += LIGHT_COLOR * ATTENUATION * wrap / PI;
}
```

### How it is lit

- **The ship's lights.** `LIGHT_VERTEX` is "a writable version of `VERTEX`
  that can be used to alter light and shadows" [10]. In the engine's shader
  the lighting position is replaced by it before fog, the light-cluster depth
  lookup and every light are evaluated [11]. Because the point lies on the
  pixel's own view ray, the clustered lights found for it are the right ones
  **(derived from [11])**. Each omni and spot light then reaches `light()`
  with `ATTENUATION` already holding distance falloff and its shadow map
  [10], so smoke in a doorway is lit from the lit room and dark on the dark
  side, and a wall's shadow falls across it.
- **Shape.** The normal is the downhill direction of the cell fill at the
  seen point, so the cloud shades as a rounded body. The noise gives the
  silhouette; the normal stays smooth on purpose, since a noisy normal on
  smoke sparkles **(derived)**.
- **Self-shadow.** Three cell-only samples above each dense sample darken
  smoke that has smoke over it. "Up" stands in for the ceiling lamps; it is
  the recreation's choice too [3]. The floor of 0.35 stops undersides going
  black, which is the job emission did for the fog [5].
- **Ambient.** The environment's ambient light applies as to any lit
  material. Add a little `EMISSION` if rooms are dark.
- **If `LIGHT_VERTEX` does not behave** (see "Not confirmed"), the plan B
  inside this approach is `render_mode unshaded` and two or three nearest
  lights passed in as uniforms from script each frame, with the falloff
  computed in the march. It loses shadow maps.

### How holes show

- **From the cells.** A hole is cells whose `now` is 0. The shader sees it
  the frame the texture is uploaded: no froxels, no reprojection. Linear
  filtering turns a row of empty cells into a rounded tunnel, and the
  erosion noise roughens its wall like the outer surface.
- **Sharper, if wanted.** Pass the last few shots as line segments and
  multiply the density by `smoothstep(r, r + 0.25, distance_to_segment + n *
  0.3)`, the recreation's method [3]. With `r` at the gameplay reach (the
  prototype empties cells within 0.9 m of the line) the drawn tunnel is round
  and exactly where the open cells are. The same with a sphere for a Blast.
  The cells stay the truth for sight; the analytic shape only tidies the
  drawing.
- **Refill** uses the last half second's ramp of `now`, which the prototype
  already computes; the threshold in `density()` turns that ramp into a
  surface closing in, not a fade.

### Camera inside

- `cull_front` draws the box's back faces, which are in view whether the
  camera is outside or inside, and `depth_test_disabled` stops a nearer wall
  from throwing those faces away; the shader does the clipping itself against
  the depth texture [10][12].
- `max(t0, 0.0)` starts the ray at the eye. In thick smoke the first steps
  are opaque, so the screen fills with lit, moving smoke and the march ends
  early.
- The HUD grey-out stays as the certain backstop and the testable number.

### Dressing

A short `GPUParticles3D` burst of flipbook wisps at the pop and a few at a
closing hole add motion the noise cannot. Keep them few, short-lived and
never relied on to block sight, as the earlier note said.

## Fallback

**A cheap opaque core from the same box, skinned with lit flipbook puffs.**
Use it if the recommended shader is too slow at full resolution on the target
machine and the half-resolution `CompositorEffect` is judged too much work.

- **Core.** The same box, material and cell texture, with the shader cut
  down: `render_mode unshaded`, no noise, no light samples, 8 steps, a flat
  colour a little darker than the puffs, and `ALPHA` from the accumulated
  fill. It makes the cloud exactly opaque where the cells are, clips at the
  depth buffer, cuts holes the same frame and works with the camera inside.
  It is the earlier note's "option 4" made to follow the cells.
- **Skin.** One `MultiMeshInstance3D` of camera-facing quads, one or two per
  **surface** cell (a filled cell with an empty neighbour), each about 1.2 m,
  offset a little outward and at random. A flipbook smoke sheet through
  **Particle Billboard** with **H Frames** / **V Frames** [8], each quad
  starting on a different frame. A `MultiMesh` and not `GPUParticles3D`,
  because the quads must sit on known cells and be hidden per cell; the cell
  list comes from script.
- **Holes.** The script sets a puff's per-instance alpha from its cell's
  `now`. The core shows the tunnel; the puffs round its mouth.
- **Lighting.** Start with per-pixel lighting and a baked normal map. Move to
  six-way lightmaps [9] only if the puffs read as flat cards; that needs
  baked textures from Blender or a fluid tool and a custom `light()`.
- **Camera inside.** Fade puffs out by distance to the camera (distance fade
  [21]) so none covers the screen at arm's length; the core and the grey-out
  carry the view from inside.
- **What is lost.** The continuous eroded surface. At a few metres it is
  visibly sprites round a flat-shaded lump, and puffs sort against each
  other and against Bolt streaks by origin [20].

## Not confirmed

- **How CS2 actually draws its smoke.** Valve states behaviour only [1][2].
  Grid size, cell size, step counts, noise type, the lighting model and how
  shadows are cast are all from community sources [3][4][15] or unknown.
- **Whether Valve gave any talk on it.** Searches found none; absence in a
  search is not proof.
- **memorin.app's numbers** [4]: read through a page summary, method not
  shown, no second source.
- **Acerola's video itself** was not watched; only the repository's code and
  README were read [3].
- **Every frame cost in Godot.** Nothing was measured, and no source gives
  timings for a ray-marched material, for `hint_depth_texture`'s depth copy,
  or for raised froxel counts.
- **`LIGHT_VERTEX` on a volume.** The source shows the lighting position is
  replaced before lights and fog [11]; that this gives a good-looking result
  on smoke, with shadow maps sampled at a point inside the cloud, is
  untested. Shadow bias at a point with a made-up normal may need tuning.
- **Writing `NORMAL` on back faces.** With `cull_front` only back faces are
  drawn; whether the engine flips a user-written `NORMAL` for them was not
  traced in source.
- **`inverse(MODEL_MATRIX)` and the per-pixel start offset** in the outline
  are standard GLSL but were not compiled in Godot's shader language.
- **The depth texture under MSAA**, and whether reading it adds a noticeable
  copy when nothing else in the scene does. The project sets no
  anti-aliasing in `project.godot` today.
- **Cells that straddle walls.** The shader never draws outside filled cells,
  but a cell whose centre is reachable can overlap a thin wall by up to half
  a cell (0.375 m), and smoke drawn there shows in the next Room. Whether the
  ship's walls are thick enough, or the fill must test a cell's whole box,
  is a prototype question.
- **Drawn size against blocking size.** Erosion pulls the surface inside the
  cells, while the earlier rule wants the drawn cloud a little bigger than
  the blocking one. `extinction`, the threshold and the 1 m blocking depth
  have to be tuned together on screen.
- **Bolt streaks and muzzle flashes against the cloud.** They are transparent
  and absent from the depth texture [10]; whether drawing the cloud after
  them or before them looks less wrong was not tried.
- **Two clouds overlapping.** Each box is sorted as a whole by its origin
  [20]. Valve says its smokes "combine" [1]; merging clouds into one grid was
  not designed here.
- **Frostbite's method** (particles voxelised into an extinction volume and
  lit there) is known only from search summaries of EA's page, which returned
  404 when opened; it is left out of the comparison.
- **The powder term's formula** in [18] is on a slide image, not in the
  extractable text; only its description is cited.
- **The bloom.** No source describes how CS2 or anyone animates the first
  quarter second. The suggestion above is mine.

## Sources

Godot documentation, branch `4.7`, under
<https://github.com/godotengine/godot-docs/blob/4.7/>; engine source, tag
`4.7-stable`, under <https://github.com/godotengine/godot/blob/4.7-stable/>.

1. Valve, Counter-Strike 2 page, <https://www.counter-strike.net/cs2>; text
   read from the page's English strings file
   (`public/javascript/csgo_react/main_english-json.js`, keys
   `cs2beta_smokes_*`).
2. Valve, Counter-Strike 2 and CS:GO release notes, Steam announcements for
   app 730, read through
   <https://api.steampowered.com/ISteamNews/GetNewsForApp/v2/?appid=730&feeds=steam_community_announcements>.
   Posts titled "Release Notes for" 3/24/2023, 3/30/2023, 6/6/2023, 6/8/2023,
   8/15/2023, 8/31/2023, 9/27/2023, 2/6/2024, 2/8/2024, 2/12/2024, 2/28/2024,
   10/28/2024; "Counter-Strike 2 Update" of 2026-04-29; "Counter-Strike:
   Global Offensive Update Released" of 2014-05-01.
3. **[community]** Garrett Gunnell (Acerola), CS2-Smoke-Grenades,
   <https://github.com/GarrettGunnell/CS2-Smoke-Grenades>: `README.md`,
   `Assets/Resources/RenderSmoke.compute`, `Assets/Scripts/Raymarcher.cs`.
4. **[community]** memorin.app, "CS2 smokes are a 32-cubed grid of 20-unit
   voxels", <https://memorin.app/mechanics/smoke-voxels>.
5. Docs, `tutorials/3d/volumetric_fog.rst`.
6. Docs, `classes/class_projectsettings.rst`:
   `rendering/environment/volumetric_fog/volume_size`, `volume_depth`,
   `use_filter`.
7. Engine source,
   `servers/rendering/renderer_rd/shaders/environment/volumetric_fog_process.glsl`
   (`get_depth_at_pos`, the `pow(..., params.detail_spread)` mapping) and
   `servers/rendering/renderer_rd/environment/fog.cpp`
   (`_point_get_position_in_froxel_volume`).
8. Docs, `tutorials/3d/particles/process_material_properties.rst`, "Animation"
   (sprite sheets, **H Frames**, **V Frames**).
9. Unity, "Realistic smoke lighting with 6-way lighting in VFX Graph",
   <https://unity.com/blog/engine-platform/realistic-smoke-with-6-way-lighting-in-vfx-graph>.
   First-party for Unity; used for the technique, not for Godot.
10. Docs, `tutorials/shaders/shader_reference/spatial_shader.rst` (render
    modes, fragment built-ins including `LIGHT_VERTEX`, light built-ins, the
    note that transparent materials do not cast shadows or appear in
    `hint_depth_texture`).
11. Engine source,
    `servers/rendering/renderer_rd/shaders/forward_clustered/scene_forward_clustered.glsl`
    (`#ifdef LIGHT_VERTEX_USED` ... `vertex = light_vertex;`, ahead of
    `fog_process`, `cluster_z` and the omni and spot light loops).
12. Docs, `tutorials/shaders/advanced_postprocessing.rst` (depth texture,
    reverse-Z, reconstruction of view and world position).
13. Docs, `tutorials/rendering/compositor.rst` and
    `classes/class_compositoreffect.rst` (`EFFECT_CALLBACK_TYPE_POST_TRANSPARENT`,
    `access_resolved_depth`).
14. Docs, `tutorials/performance/gpu_optimization.rst`, "Transparency and
    blending".
15. **[community]** Recreations that credit [3]:
    <https://github.com/TsingLoo/Smoke-CS2>,
    <https://github.com/lolgube010/DX11-TGA-Portfolio-CS2-Smoke>,
    <https://github.com/1alaLo/urp-volumetric-smoke>.
16. Docs, `classes/class_environment.rst`: `volumetric_fog_detail_spread`,
    `volumetric_fog_length`, `volumetric_fog_temporal_reprojection_enabled`,
    `volumetric_fog_temporal_reprojection_amount`.
17. Docs, `tutorials/shaders/shader_reference/fog_shader.rst`.
18. Andrew Schneider and Nathan Vos (Guerrilla Games), "The Real-time
    Volumetric Cloudscapes of Horizon Zero Dawn", SIGGRAPH 2015, Advances in
    Real-Time Rendering, slides with notes:
    <https://advances.realtimerendering.com/s2015/The%20Real-time%20Volumetric%20Cloudscapes%20of%20Horizon%20-%20Zero%20Dawn%20-%20ARTR.pdf>.
19. Docs, `tutorials/shaders/shader_reference/shading_language.rst`
    (`sampler3D`, uniform arrays, `hint_depth_texture`, varyings from
    fragment to light, per-instance uniform limits).
20. Docs, `tutorials/3d/3d_rendering_limitations.rst`, "Transparency
    sorting"; `classes/class_visualinstance3d.rst`, `sorting_offset`.
21. Docs, `tutorials/3d/standard_material_3d.rst` (shading modes, billboard
    modes, proximity and distance fade).
22. Iain Cantlay (NVIDIA), "High-Speed, Off-Screen Particles", GPU Gems 3,
    chapter 23,
    <https://developer.nvidia.com/gpugems/gpugems3/part-iv-image-effects/chapter-23-high-speed-screen-particles>.
23. Ubisoft, Rainbow Six Siege "Y6S2 Pre-Season Designer's Notes",
    <https://www.ubisoft.com/en-ca/game/rainbow-six/siege/news-updates/76KxHcLFOo2PdhSS4t1HmZ/y6s2-preseason-designers-notes>.
24. Docs, `classes/class_renderingserver.rst`,
    `viewport_get_measured_render_time_gpu`.
25. Docs, `classes/class_imagetexture3d.rst`, `create`, `update`.
