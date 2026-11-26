# Grenade physics, blast, smoke and flash in Godot 4

Research note, 2026-11-25. Question
(`.scratch/equipment/issues/02-grenade-effects-in-godot.md`): what are the
workable ways in Godot 4 to build (a) a thrown bouncing grenade with a matching
predicted arc and the same flight on every headless run, (b) blast damage with
cover checks, (c) smoke the player cannot see through, (d) smoke that stops
crew sight rays, (e) a flash whiteout with muffled sound, and what does each
cost.

The repo is on **Godot 4.7, Forward+, Jolt Physics** (`project.godot`:
`config/features=PackedStringArray("4.7", "Forward Plus")`,
`3d/physics_engine="Jolt Physics"`; the installed editor is 4.7.2). Engine
facts below were read from the engine's `4.7-stable` tag (class reference XML
and C++ source) and the `4.7` branch of the documentation repository, which are
the sources of the pages on docs.godotengine.org. **Nothing here was run in the
engine**: every claim is from reading, and "Not confirmed" at the end lists
what a prototype has to settle. In particular no frame times were measured;
where the ticket asks for "frame cost" this note gives what the sources say
drives the cost, not milliseconds.

Each claim carries a source number, listed at the end. A claim marked
**(derived)** is my own reasoning from the cited facts and the repo's code, not
something a source states. Sources 22 and 23 are other games' source code, used
only for "the usual way"; source 25 is a pull request thread.

## Summary

| | Recommended | Cost | Main pitfalls |
|---|---|---|---|
| a | Hand-stepped body in the `Projectile3D` pattern: gravity plus a swept sphere each physics tick, bounce by `Vector3.bounce`, and the **same step function** run ahead for the arc | One sphere sweep per grenade per tick; about one per tick of flight drawn for the arc, each frame the arc shows | Sweeps ignore what they start inside; the arc cannot know about Doors or crew that move after the throw; rolling has to be faked |
| b | `intersect_shape` with a sphere on the body layer, then rays on the world layer from the blast to two or three points on each body; damage = falloff by distance x share of rays that are clear | One shape query and a few rays, once | A ray that starts inside a wall's box does not see that wall; result order is not promised, so sort; the alarm panel is on the world layer and will be missed |
| c | `FogVolume` in volumetric fog (Forward+ has it), with the gameplay radius smaller than the drawn one; a custom shader sphere as the second candidate | Turning volumetric fog on costs a froxel pass over the whole view while it is on; no numbers in the docs | Coarse froxel grid, lag from temporal reprojection as the cloud grows, soft rim that is see-through, and fog is not clipped by walls |
| d | A sphere shape on a new physics layer 5 (value 16), tested by a second, smoke-only ray with `hit_from_inside = true` | One extra ray per sight check while a cloud lives | Without `hit_from_inside` a crew member standing in the cloud sees out of it; a sphere pokes through walls into the next room; do not put it on layer 1 |
| e | A white `ColorRect` on its own `CanvasLayer`, its strength counted down in `_physics_process`; an `AudioEffectLowPassFilter` on the `sfx` bus with its cutoff swept back up; the ring on `Master` | One blended full-screen quad; one filter on one bus | A true kept frame needs a GPU read-back and holds the HUD in it; same-index CanvasLayers have no fixed order |

Recommendation in one line: **do the grenade's flight and the smoke's
blocking as plain script over space queries, the way bolts and crew sight
already work, and keep engine simulation (RigidBody3D, particles, fog) for
looks only**, because the headless suites draw nothing and step at a fixed
1/60 s, and only script state is checkable there.

## What the project has today

Read from `project.godot`, `scripts/projectile_3d.gd`, `scripts/player_3d.gd`,
`scripts/sound_at.gd`, `scripts/crew/crew.gd`, `scripts/crew/head_zone.gd`,
`scripts/door_3d.gd`, `scripts/ship/ship_builder_3d.gd`, `scripts/laser_dot.gd`,
`scripts/ui/hud.gd`, `default_bus_layout.tres`, `scenes/*.tscn` and
`docs/agents/validation.md`.

**Physics layers in use** (no layer names are set in `project.godot`):

| Layer | Bit value | What is on it | Who scans it |
|---|---|---|---|
| 1 | 1 | The ship: hull `GridMap`, props, a shut Door's blocker, the alarm panel, the boarding pod (`WORLD_LAYER := 1` in `player_3d.gd` and `crew.gd`) | Pirate and crew bodies (mask 3), bolts (mask 3), crew sight and cover rays, the Laser dot (`MASK := 1 \| 2`) |
| 2 | 2 | Bodies that can be hit: the Pirate and living crew (`BODY_LAYER := 2`); a dead crew member leaves it | Bodies, bolts, Door triggers (mask 2), melee's `intersect_shape` |
| 3 | 4 | Bolts (`scenes/projectile_3d.tscn`: `collision_layer = 4`, `collision_mask = 3`) | Nothing |
| 4 | 8 | Crew head zones, `Area3D` (`HeadZone.LAYER := 8`) | Only a bolt's separate head ray |

Layers 5 to 32 are free; the engine gives each object 32 [1][2].

**Patterns to fit:**

- **Nothing is hitscan and nothing is a rigid body.** A bolt is an `Area3D`
  that, each physics tick, casts a ray from where it is to where it will be
  and stops at the first hit (`Projectile3D._sweep`). `launch()` is called
  before the node enters the tree. The class comment gives the reason: at
  speed a bolt covers more than a body's width in one step.
- **Crew sight** is one bodies-only ray from eye to eye on `WORLD_LAYER`
  (`Crew3D._blocked`, called from `_update_perception`). The same `_blocked`
  also serves the cover search and `crew_traces.gd`.
- **Shape queries are already used**: `Crew3D._ball_blocked` sweeps a sphere
  with `cast_motion`; `Player3D.melee_target` finds bodies with
  `intersect_shape` on `BODY_LAYER`.
- **Damage** goes through `take_damage(amount: int, from: Node = null)` on the
  Pirate, crew and the alarm panel.
- **Timers** are counted down in `_physics_process` (`Player3D._count_down`
  and `TIMER_SLOP`), so they land on whole ticks.
- **Sound**: two buses, `Master` and `sfx` (which sends to `Master`).
  `SoundAt.play` and `PirateAudio` put everything on `sfx`; only the awareness
  sting plays on `Master`.
- **HUD** is a `CanvasLayer` of `ColorRect`s built in code; the hurt vignette
  is a full-screen `ColorRect` whose alpha is tweened.
- **Ship collision** is boxes: walls are 1 m thick (1.08 m with their proud
  collision), a Door's blocker is 1 m thick and is switched off with
  `disabled` when the Door opens, floors and ceilings are 0.1 m thick.
- **Tests**: the physics suites run `--headless --fixed-fps 60`, which the
  repo's validation doc describes as one 1/60 s physics tick and one process
  frame per frame, with the global RNG seeded per run. "Headless runs draw no
  pixels"; looks are checked with `tests/shots.sh`. The engine's own
  description of the flag is "Force a fixed number of frames per second. This
  setting disables real-time synchronization" [3].

## a. A thrown body that bounces

### Option 1: `RigidBody3D`

Let Jolt simulate it: a sphere shape, a `PhysicsMaterial` for bounce and
friction, `continuous_cd` on.

- **Tunnelling.** Without continuous collision detection a rigid body "can
  miss small, fast-moving objects" [4]. In the Jolt module `continuous_cd`
  switches the body's motion quality from `Discrete` to `LinearCast` [5]. Jolt
  describes `LinearCast` as an extra shape cast after the step; on a hit "the
  object is placed back to where the collision occurred and will remain there
  until the next time step", which it calls time stealing, and the body "may
  appear to move much slower for a single time step" [6]. It only applies once
  the body moves more than a fraction of its inner radius in a step (project
  setting `continuous_cd_movement_threshold`, default 0.75), and it lets the
  body sink in by a fraction (`continuous_cd_max_penetration`, default 0.25)
  [7]. The general advice for tunnelling is thicker static shapes or a higher
  tick rate [8]; the ship's walls and Doors are already 1 m thick, and only the
  0.1 m floors and ceilings are thin **(derived)**.
- **Bounce and friction.** `PhysicsMaterial.bounce` runs 0 to 1 and
  `friction` 0 to 1; `rough` and `absorbent` change how two materials combine
  [9]. Under Jolt a collision slower than
  `bounce_velocity_threshold` (default 1 m/s) does not bounce at all [7].
  Bounce sounds need `contact_monitor = true` and `max_contacts_reported > 0`
  [4].
- **Same throw every run.** The Godot docs make no promise of determinism for
  rigid bodies; I found none in the 4.7 class reference or the Jolt page [10].
  Jolt's own documentation says its simulation "is deterministic provided
  that" the calls that change the simulation come in exactly the same order
  and the same binary is used [6]. Under `--fixed-fps 60` with a seeded run
  that condition plausibly holds, but it is Jolt's claim about Jolt, not
  Godot's about its module **(derived)**.
- **Predicted arc.** This is where the option fails. Godot has no call to step
  a physics space ahead: `PhysicsServer3D` in 4.7 has no step method [11], and
  the pull request that would add `space_step()` is still open [25]. So the
  arc has to come from a second, hand-written integrator that imitates Jolt,
  and it will drift from the real flight at the first bounce: restitution and
  friction combining, spin, the 1 m/s bounce cut-off, time stealing, and
  damping (each tick the engine multiplies velocity by
  `1 - damp / ticks_per_second` [7]) all have to be reproduced
  **(derived)**.

Cost: the cheapest to write for the flight, the most expensive to make the arc
honest.

### Option 2: hand-stepped with a ray (the `Projectile3D` pattern as it is)

Each physics tick: add gravity to the velocity, cast a ray from the position
to the next position, and on a hit place the grenade at the hit and reflect
the velocity. `Vector3.bounce(n)` is the reflection off a plane with normal
`n` (Godot's `reflect` is the other convention) [12]; `intersect_ray` returns
`position` and `normal` [13]. Split the bounced velocity into its part along
the normal (times a restitution number) and its part along the surface (times
a friction number) **(derived)**.

- No tunnelling at any speed, because the whole step is swept.
- A ray has no width, so the grenade's centre can pass within a hair of a
  corner and the model will visibly cut through it **(derived)**.
- A ray does not see a shape it starts inside unless `hit_from_inside` is set,
  and then the normal comes back as zero [13][14].

### Option 3: hand-stepped with a swept sphere

The same loop with a sphere instead of a ray. Two ways to get it:

- **Space queries, no body.** `cast_motion` takes a shape and a motion and
  returns the safe and unsafe fractions of the motion, but no normal; it
  ignores shapes the sphere already overlaps [13]. `get_rest_info` at the
  touching position returns `point` and `normal` [13]. `Crew3D._ball_blocked`
  already does the first half.
- **A body that is moved by hand.** `PhysicsBody3D.move_and_collide(motion)`
  stops at the first collision and returns a `KinematicCollision3D` with
  `get_normal()`, `get_travel()` and `get_remainder()` [15][16].
  `test_move(from, motion, collision)` does the same from any transform
  without moving the body [15], so the arc can be walked ahead with the real
  body's own shape and mask. Under Jolt these motion queries also push the
  body out of anything it overlaps (`motion_queries/recovery_*` settings) [7].

Either way the arc is the flight: run the same step function N ticks ahead
from the throw's start state and draw the points. It matches exactly as long
as the world does not change between the preview and the flight
**(derived)**.

Costs and limits **(derived)** unless marked:

- One sweep per grenade per tick in flight. The arc costs one sweep per tick
  of flight shown (a 2 s fuse is 120) on each frame it is drawn; stepping the
  preview with a larger step would make it cheaper and wrong, so draw every
  few points rather than step coarser. Not measured.
- Rolling and coming to rest are not simulated: below some speed on a
  near-level surface, stop it. That rule is in the step function, so the arc
  shows it too.
- A Door that opens or shuts, or a crew member who walks into the path, after
  the preview, changes the flight. Previewing against `WORLD_LAYER` only, and
  letting the real grenade also bounce off bodies, is the honest choice: the
  arc shows the ship, not the people.
- Queries are against the space as it stands that tick; a Door switches its
  blocker with `set_deferred`, so it changes between ticks, not within one.

### Recommendation for (a)

**Option 3, in the shape of `Projectile3D`**: a node with `launch()` called
before it enters the tree, a `shooter` it ignores, stepped in
`_physics_process`, with the step written as one function of
(position, velocity, delta) that both the grenade and the arc call. Yes, the
grenade should follow the bolt's pattern; what it adds is gravity, a width,
and a bounce instead of a strike.

Reasons: the arc matches by construction; it is deterministic for the same
reason bolts are (arithmetic and queries on a fixed 1/60 s step, no solver);
nothing can tunnel; and it adds no rigid bodies to a project that has none.
Between the two forms of option 3, `move_and_collide` and `test_move` hand
back the normal directly and are the less code; the pure space-query form
needs no body at all. A prototype should pick by which gives clean normals on
box edges (see "Not confirmed").

Give the grenade no layer unless bolts should hit it, and a mask of
`WORLD_LAYER` (plus `BODY_LAYER` if it should bounce off people).

## b. Blast damage

### Finding what is in the radius

- **`intersect_shape` with a `SphereShape3D`** returns every shape it
  overlaps, immediately, up to `max_results` (default 32) [13]. This is what
  `melee_target` does on `BODY_LAYER`. It returns shapes, so one body can
  appear more than once; and neither the docs nor Jolt promise an order (Jolt
  notes its broad-phase queries are not deterministic and tells callers to
  order results themselves [6]). Collect unique colliders and sort them (by
  distance, say) before dealing damage, so a replayed seed kills in the same
  order **(derived)**.
- **`Area3D.get_overlapping_bodies()`** "is modified once during the physics
  step, not immediately after objects are moved" [17]. An area made at the
  moment of the blast knows nothing until a later tick, so a one-shot blast
  has to wait a tick or keep an idle area on every grenade. A poor fit.
- **Walking the `crew` and `player` groups and comparing distances** needs no
  physics and has a fixed order. It measures to the body's origin, not its
  surface **(derived)**.

### Checking cover

A ray from the blast to a point on the target, on `WORLD_LAYER`, bodies only:
exactly `Crew3D._blocked`. Empty result means clear [13].

How other games count cover, from their source:

- **Quake III** (`CanDamage`): all or nothing. One trace to the middle of the
  target's bounds, then four more to points offset 15 units on the horizontal
  plane; any clear trace allows full damage. Damage falls off linearly,
  `damage * (1 - dist / radius)`, with the distance taken from the edge of the
  target's box [22].
- **Source SDK 2013** (`CGameRules::RadiusDamage`): one trace to the target's
  body point. The world in the way means no damage (with a second, bent trace
  for targets within half the radius). Another object in the way, with the
  world clear behind it, blocks a share: by its mass if it is a physics
  object, otherwise a flat 25% [23].
- **Share of rays** **(derived, not from a source I read)**: cast to several
  points on the target and scale damage by how many are clear. The crew code
  already names the heights: `COVER_HEIGHT` 0.9 m, `TORSO_HEIGHT` 1.0 m,
  `EYE_HEIGHT` 1.5 m.

### Pitfalls

- A ray does not hit a shape it starts inside unless `hit_from_inside` is on
  [14]. A grenade resting in a corner whose blast origin lies inside a wall's
  box (walls run 0.04 m proud of their mesh) would blast through that wall.
  Start the rays from the grenade's centre lifted clear of the floor, which a
  swept sphere from (a) guarantees is outside every shape **(derived)**.
- The alarm panel takes damage but sits on layer 1, so a body-layer query
  misses it. Dead crew have left layer 2 and are skipped, as wanted.
- The Pirate is on layer 2 as well: self-damage is on unless excluded.
- Whether bodies shield each other is a design choice; world-only rays say
  no.

### Recommendation for (b)

`intersect_shape` on `BODY_LAYER` from the blast point, unique colliders
sorted by distance, then for each two or three world-layer rays to named
heights on the body. Damage = linear falloff by distance x share of rays
clear, through the existing `take_damage`. Whether cover is all-or-nothing
(Quake) or a share is a tuning decision the Sandbox can settle; the query
code is the same.

## c. Smoke the player cannot see through

### Option 1: `FogVolume` in volumetric fog

Volumetric fog is Forward+ only, which this project is [18]. A `FogVolume`
adds fog in an ellipsoid, cone, cylinder or box; it shows only when
`Environment.volumetric_fog_enabled` is true, and global density 0 leaves fog
only inside volumes [19]. `scenes/main_3d.tscn`'s Environment has it off
today.

- **How it hides things.** In the Forward+ scene shader the fog is sampled per
  pixel at that pixel's depth and blended over the final colour, for
  transparent materials too, unless a material opts out (`fog_disabled`
  render mode, `BaseMaterial3D.disable_fog`) [20][21]. So crew, props, the
  transparent Bolt streak and emissive lamps behind the cloud are all covered
  **(derived from the shader)**.
- **Camera inside.** It is a real volume, so being inside it just means fog
  in front of everything. This is the case billboards handle worst and fog
  handles best [18].
- **Edges.** The fog lives in a froxel grid (64 x 64 x 64 by default, spread
  over `volumetric_fog_length`, default 64 m) [7][24]. "The level of detail
  that a fog shader can add depends on how close the FogVolume is to the
  camera", and the shader runs for every froxel the volume's bounding box
  touches [26]. Dense volumes "may suffer from under-sampling artifacts that
  look like stripes"; thin ones "may appear to flicker" [19][27]. Shortening
  `volumetric_fog_length` to the ship's sight lines gives more detail for
  free [18].
- **Leaks.** Density is exponential along the view ray [24], so the rim of an
  ellipsoid, where the ray's path through it is short, is always see-through
  **(derived)**. `edge_fade` softens it further [27].
- **Growing and fading.** Temporal reprojection (on by default, amount 0.9)
  makes "moving FogVolumes ... 'ghosting' and leaving a trail" [24]; a cloud
  that blooms in half a second will lag on screen **(derived)**.
- **Light.** The fog is lit by lights (single scattering) and "tends to need
  a little bit of emission" [24]. In a dark room an unlit cloud is a black
  mass; give the `FogMaterial` some emission [27].
- **Walls.** Nothing clips a `FogVolume` to geometry: a 3 m ellipsoid next to
  a 1 m wall shows in the next room **(derived)**.
- **Cost.** "Performance of FogVolumes is directly related to their relative
  size on the screen and the complexity of their attached FogMaterial" [19].
  The froxel pass exists whenever volumetric fog is enabled; the docs give no
  timings [18].

### Option 2: `GPUParticles3D` puffs

Billboarded, alpha-blended quads. Transparent objects are sorted "based on
the Node3D's position, not the vertex position", Godot has no
order-independent transparency [28], and transparency is "particularly bad
for fill rate, because every item has to be drawn even if other transparent
objects will be drawn on top", worst "where multiple transparent objects
overlap" [29]. A cloud thick enough to be opaque is many overlapping
full-screen quads once the camera is in it. Puffs also need proximity fade
(fades each pixel by its distance to what is behind it [21]) to hide where
they cut walls, and they pop at the near plane. Particles pass through walls
unless particle collision is set up. `use_fixed_seed` exists for a repeatable
look [30]. Gaps between puffs leak **(derived)**.

### Option 3: hand-placed billboard quads

The docs describe this as a stand-in for fog and list its faults: "less
realistic falloff, especially if the camera enters the fog", "transparency
sorting issues", and no better performance "if there are lots of sprites
close to the camera" [18]. Same weaknesses as particles with more control.

### Option 4: a shader volume

One sphere mesh with a spatial shader that works out how far the view ray
travels inside the sphere, clipped by the scene's depth
(`hint_depth_texture` [31][32]), and sets opacity from that length. Drawn
with front faces culled and depth test off [31], it works from inside and
outside and can be made exactly opaque through the middle
**(derived; not found as a documented recipe)**. Cost is one draw of a cheap
shader over the pixels it covers. Its weakness is the transparent pass: it
is sorted against the Bolt streak and other clouds by node position [28], and
the depth texture holds opaque geometry only, so a tracer inside the cloud
draws wholly in front of it or wholly behind.

### A helper for any option: blind the camera when it is inside

A full-screen `ColorRect` whose alpha follows how deep the camera is in the
cloud, in the manner of the hurt vignette in `hud.gd`. It makes "inside"
certain whatever the 3D effect does, and it is a number a headless test can
read **(derived)**.

### Recommendation for (c)

Prototype **option 1** first and judge it with `tests/shots.sh`: it is built
in, the renderer supports it, it covers transparent things, and it is the
only option that is naturally right with the camera inside. Keep **option 4**
as the fallback if the froxel grid leaks or lags too much in 5 m rooms. Use
particles only as dressing at the rim, never as the thing that blocks sight.

Whichever draws it, the rule that keeps it fair is: **the radius that blocks
crew (d) is smaller than the radius that is drawn**, so that anywhere the
crew are blind the player is too. The rim leaks for the player by nature;
make the rim count as clear for both sides.

## d. Smoke crew cannot see through

### Option 1: a shape on its own physics layer

A `SphereShape3D` on a new layer 5 (`SMOKE_LAYER := 16`), mask 0. An object
is only detected by things whose mask includes its layer [1], so nothing in
the game reacts to it until a ray asks for it: bodies and bolts have mask 3,
and the Laser dot, the Pirate's aim ray and the crew's muzzle check name
layers 1 and 2 only.

- **Body or area.** A `StaticBody3D` is hit by a default ray. An `Area3D`
  needs `collide_with_areas = true` on the ray [14][33]; `HeadZone` is the
  project's precedent for an area on a private layer read by its own ray.
- **The inside case.** `hit_from_inside`: "the query will detect a hit when
  starting inside shapes" [14]. It defaults to false, and the Jolt module
  passes it straight to Jolt's `mTreatConvexAsSolid` and does not turn on
  back-face hits for convex shapes [34]; Jolt's sphere then reports no hit at
  all for a ray that starts inside it [35]. So with the default, **a crew
  member standing in the smoke sees out of it, and sees the Pirate standing
  in it** **(derived from the source)**. The smoke ray must set
  `hit_from_inside = true`, as `Projectile3D._head_on_line` already does for
  heads.
- **Do not widen the world ray.** `Crew3D._blocked` also decides cover, and
  setting `hit_from_inside` on a ray that scans layer 1 changes what it does
  near walls. Cast a second ray on `SMOKE_LAYER` only, and only from the
  sight check **(derived)**. One extra ray per crew member per tick while a
  cloud lives; skip it when none does.
- **Grow and shrink.** Change the shape's `radius`; scaling collision shapes
  is not supported, and each cloud needs its own shape resource since
  resources are shared by default [8].
- **Never layer 1.** On the world layer the cloud would stop bolts and
  bodies, count as cover, and fill `_solid` point checks **(derived)**.

### Option 2: no physics, segment against sphere

Keep a list of live clouds (centre, radius) and test the eye-to-eye segment
against each sphere in script. Exact, deterministic, no layer, no extra
physics objects, and the inside case is right without a flag. It stops being
simple if clouds are ever not spheres **(derived)**.

### The same cloud for both sides

One `SmokeCloud` node owns the radius over time, counted in
`_physics_process`. The drawn effect (c) and the blocking shape (d) both read
that number, and the test suites read it too. Bolts are untouched by either
option, so both sides can still fire blind through it **(derived)**.

A sphere, like the fog volume, goes through walls: a cloud against a wall
blocks sight in the next room as well. Either accept it (walls are 1 m
thick, so keep the radius modest), or clamp the cloud to its Room's box,
which the generator knows **(derived)**.

### Recommendation for (d)

**Option 1 with an `Area3D` or `StaticBody3D` on layer 5 and a separate
smoke-only ray with `hit_from_inside = true`**, because it is the pattern
`HeadZone` set and it carries over if clouds become boxes fitted to Rooms.
Option 2 is a sound fallback and is what I would use if the timing question
under "Not confirmed" goes badly.

## e. Flash

### The whiteout

- **`CanvasLayer` + `ColorRect`.** A `CanvasLayer` draws its children at a
  layer index over the 3D view [36]. A white rect whose alpha falls from 1 is
  one blended quad. If two layers share an index, which draws in front "is
  non-deterministic" [36], so give the flash an index of its own, above or
  below the HUD on purpose.
- **Screen-reading shader.** A `canvas_item` shader on the same rect can read
  what is behind it with `hint_screen_texture`; this is the documented way to
  post-process, and with a mipmap filter it gives a blur for free [37][38].
  The first use in a frame costs a full-screen copy [37]. It can bleach and
  blur the view instead of painting flat white.
- **A kept frame (true after-image).** Wait for
  `RenderingServer.frame_post_draw`, take `get_viewport().get_texture()
  .get_image()`, and make an `ImageTexture` from it [39][40]. The docs call
  this conversion "a slow operation, so it should not be performed every
  frame" [41]; once per flash is a single hitch of unknown size. The
  viewport's image includes the HUD, and under `--headless` there is no
  picture to take, so the code needs a guard **(derived)**.
- **`Environment.tonemap_exposure`.** Raising it brightens the scene before
  tone mapping at no extra pass [24]. Black stays black, and the HUD is not
  affected, so it is a garnish, not a whiteout **(derived)**.
- **`CompositorEffect`.** Works in Forward+, but the docs call it "an
  advanced feature" that runs on the render thread through a compute shader
  [42]. Far more than a flash needs.

How strong the flash is for the Pirate is script: a world-layer ray from the
blast to the camera (as in b) and the angle between the camera's forward and
the blast **(derived)**.

### Muffled sound

`AudioEffectLowPassFilter` "can be used to muffle sounds"; its `cutoff_hz`
runs from 1 to 20500 [43]. Effects sit on a bus and act on everything routed
through it [44]. `AudioServer.add_bus_effect`, `set_bus_effect_enabled` and
`get_bus_index` manage them from code [45].

Fit: every game sound is already on `sfx`, and the awareness sting already
bypasses it on `Master`. So: one low-pass on `sfx`, off by default; on a
flash, enable it with a low cutoff and sweep the cutoff back up, then disable
it. Play the ringing tone on `Master` so the filter does not swallow it
**(derived)**. Add the effect in `default_bus_layout.tres` or keep the
reference returned when adding it in code, rather than looking it up by
index.

`AudioStreamPlayer3D` has its own distance low-pass
(`attenuation_filter_cutoff_hz`) that is separate from bus effects [46].
`Engine.time_scale` does not slow audio [47], if a slow-motion beat is ever
wanted.

### Recommendation for (e)

A flash strength number on the Pirate, set by the blast and counted down in
`_physics_process` like the other timers, read by a `ColorRect` on its own
`CanvasLayer` and by the `sfx` low-pass. Start with flat white. If it reads
as cheap, move to the screen-reading shader (bleach and blur) before trying
a kept frame: the kept frame is the only variant with a read-back hitch, a
HUD baked into it and a headless special case.

## Not confirmed

- **Frame cost of everything in (c).** No timings were found in the docs and
  none were measured. Needed: volumetric fog on against off in a Raid, and
  one cloud at 1 m, 5 m and with the camera inside.
- **Whether a `FogVolume` can be dense enough** to hide a lit crew member at
  3 m without stripes at the default 64-froxel grid, and how long temporal
  reprojection takes to catch up with a cloud that blooms in 0.5 s.
- **Whether toggling `volumetric_fog_enabled` at runtime hitches** (shader
  variants), which decides whether fog can be off when no smoke exists.
- **Determinism of a Jolt `RigidBody3D` through Godot's module.** Jolt claims
  it under conditions; Godot's docs are silent. Not needed if (a) is
  hand-stepped.
- **Normals from `get_rest_info` or `move_and_collide` on box edges and at
  the seams between the `GridMap`'s wall boxes** (Jolt's edge-removal settings
  only work within one body [10]). A bad normal at a seam would send a
  grenade off sideways.
- **Cost of walking the arc** (about 120 sphere sweeps a frame). Expected to
  be small next to the crew's own queries; not measured.
- **When a new or resized shape becomes visible to `intersect_ray`**: the
  same tick, or the next. Matters for the first tick of a cloud in (d).
- **Whether `AudioServer` bus effects behave the same under the Dummy audio
  driver** that `--headless` selects [3], so that a suite can assert on the
  filter's state.
- **Size of the hitch from one viewport read-back** for a kept-frame
  after-image.
- **"Share of rays" as the usual partial-cover rule**: I found it in no
  primary source; the two engines read use all-or-nothing and a flat share
  for a blocking object.
- Not investigated: particle collision and attractors for smoke that flows
  around props, `GPUParticles3D` sub-emitters, a custom fog shader that clips
  a cloud to a Room, and flashing or stunning crew (a design question more
  than an engine one).

## Sources

Godot class reference XML, tag `4.7-stable`, under
<https://github.com/godotengine/godot/blob/4.7-stable/doc/classes/>; Godot
documentation, branch `4.7`, under
<https://github.com/godotengine/godot-docs/blob/4.7/>.

1. Class reference, `CollisionObject3D.xml` (`collision_layer`,
   `collision_mask`).
2. Docs, `tutorials/physics/physics_introduction.rst`, "Collision layers and
   masks".
3. Docs, `tutorials/editor/command_line_tutorial.rst` (`--headless`,
   `--fixed-fps`); engine source `main/main.cpp` and
   `main/main_timer_sync.cpp` at `4.7-stable` for how `fixed_fps` sets the
   step.
4. Class reference, `RigidBody3D.xml` (`continuous_cd`, `contact_monitor`,
   `max_contacts_reported`, `body_entered`).
5. Engine source, `modules/jolt_physics/objects/jolt_body_3d.cpp`,
   `JoltBody3D::set_ccd_enabled`:
   <https://github.com/godotengine/godot/blob/4.7-stable/modules/jolt_physics/objects/jolt_body_3d.cpp>
6. Jolt Physics, `Docs/Architecture.md`, "Continuous Collision Detection"
   and "Deterministic Simulation" (Jolt's own documentation, `master`):
   <https://github.com/jrouwe/JoltPhysics/blob/master/Docs/Architecture.md>
7. Class reference, `ProjectSettings.xml` (`physics/jolt_physics_3d/...`,
   `physics/3d/default_linear_damp`, `physics/common/physics_ticks_per_second`,
   `rendering/environment/volumetric_fog/...`).
8. Docs, `tutorials/physics/troubleshooting_physics_issues.rst`.
9. Class reference, `PhysicsMaterial.xml`.
10. Docs, `tutorials/physics/using_jolt_physics.rst`.
11. Class reference, `PhysicsServer3D.xml` (searched for a step method; none).
12. Class reference, `Vector3.xml` (`bounce`, `reflect`).
13. Class reference, `PhysicsDirectSpaceState3D.xml` (`intersect_ray`,
    `intersect_shape`, `cast_motion`, `get_rest_info`).
14. Class reference, `PhysicsRayQueryParameters3D.xml` (`hit_from_inside`,
    `collide_with_areas`, `collide_with_bodies`).
15. Class reference, `PhysicsBody3D.xml` (`move_and_collide`, `test_move`).
16. Class reference, `KinematicCollision3D.xml`.
17. Class reference, `Area3D.xml` (`get_overlapping_bodies`).
18. Docs, `tutorials/3d/volumetric_fog.rst`.
19. Class reference, `FogVolume.xml`.
20. Engine source, Forward+ scene shader, the `FOG_DISABLED` blocks and
    `volumetric_fog_process`:
    <https://github.com/godotengine/godot/blob/4.7-stable/servers/rendering/renderer_rd/shaders/forward_clustered/scene_forward_clustered.glsl>
21. Class reference, `BaseMaterial3D.xml` (`disable_fog`,
    `proximity_fade_enabled`, `billboard_mode`, `no_depth_test`).
22. id Software, Quake III Arena source, `code/game/g_combat.c`, `CanDamage`
    and `G_RadiusDamage` (another game's code):
    <https://github.com/id-Software/Quake-III-Arena/blob/master/code/game/g_combat.c>
23. Valve, Source SDK 2013, `src/game/shared/gamerules.cpp`,
    `CGameRules::RadiusDamage` (another game's code):
    <https://github.com/ValveSoftware/source-sdk-2013/blob/master/src/game/shared/gamerules.cpp>
24. Class reference, `Environment.xml` (`volumetric_fog_*`,
    `tonemap_exposure`, `adjustment_*`).
25. Godot pull request 76462, "Add `PhysicsServer2/3D::space_step()` to step
    physics simulation manually", open, milestone 4.x on the day read
    (a pull request thread, not documentation):
    <https://github.com/godotengine/godot/pull/76462>
26. Docs, `tutorials/shaders/shader_reference/fog_shader.rst`.
27. Class reference, `FogMaterial.xml`.
28. Docs, `tutorials/3d/3d_rendering_limitations.rst`, "Transparency sorting".
29. Docs, `tutorials/performance/gpu_optimization.rst`, "Transparency and
    blending".
30. Class reference, `GPUParticles3D.xml` (`use_fixed_seed`, `draw_order`,
    `visibility_aabb`, `fixed_fps`).
31. Docs, `tutorials/shaders/shader_reference/spatial_shader.rst` (render
    modes `cull_front`, `depth_test_disabled`, `fog_disabled`).
32. Docs, `tutorials/shaders/advanced_postprocessing.rst`
    (`hint_depth_texture`).
33. Docs, `tutorials/physics/ray-casting.rst`.
34. Engine source,
    `modules/jolt_physics/spaces/jolt_physics_direct_space_state_3d.cpp`,
    `intersect_ray`:
    <https://github.com/godotengine/godot/blob/4.7-stable/modules/jolt_physics/spaces/jolt_physics_direct_space_state_3d.cpp>
35. Jolt Physics source, `Jolt/Physics/Collision/RayCast.h`
    (`mTreatConvexAsSolid`, `mBackFaceModeConvex`) and
    `Jolt/Physics/Collision/Shape/SphereShape.cpp` (`CastRay`), `master`,
    which may differ from the copy Godot 4.7 bundles:
    <https://github.com/jrouwe/JoltPhysics/blob/master/Jolt/Physics/Collision/Shape/SphereShape.cpp>
36. Class reference, `CanvasLayer.xml`.
37. Docs, `tutorials/shaders/screen-reading_shaders.rst`.
38. Docs, `tutorials/shaders/custom_postprocessing.rst`.
39. Class reference, `Viewport.xml` (`get_texture`) and `RenderingServer.xml`
    (`frame_post_draw`).
40. Class reference, `ImageTexture.xml` (`create_from_image`, `update`).
41. Class reference, `ViewportTexture.xml`.
42. Docs, `tutorials/rendering/compositor.rst`.
43. Class reference, `AudioEffectLowPassFilter.xml` and
    `AudioEffectFilter.xml`.
44. Docs, `tutorials/audio/audio_buses.rst` and
    `tutorials/audio/audio_effects.rst`.
45. Class reference, `AudioServer.xml`.
46. Class reference, `AudioStreamPlayer3D.xml`.
47. Class reference, `Engine.xml` (`time_scale`).
