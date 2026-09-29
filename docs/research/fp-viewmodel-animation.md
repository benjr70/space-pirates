# Prior art: first-person viewmodel animation in Godot 4 and CC0 arms rigs

Resolves [#30](https://github.com/benjr70/space-pirates/issues/30), part of the movement-and-gunplay map [#29](https://github.com/benjr70/space-pirates/issues/29). Researched 2026-09-28 against primary sources (Godot 4 docs, engine PRs, project source on GitHub, asset store pages). Every claim links to the page it came from; where a page could not be fetched the note says so.

**Project context.** `project.godot` declares `config/features=PackedStringArray("4.7", "Forward Plus")` and the flatpak editor is 4.7.2. The pirate (`scenes/player_3d.tscn`) is `Player (CharacterBody3D) > Head (Node3D) > Camera3D (fov 75, near 0.05) > Weapon (Node3D) > Blaster (kenney_blaster/blaster-d.glb)` plus a `Muzzle` node under the camera. No rig, no AnimationPlayer, no procedural layer.

## TL;DR

1. Godot 4 FPS projects animate the viewmodel almost entirely **procedurally in GDScript** (lerp/tween on the weapon holder's transform, kick on the camera), with **AnimationPlayer keyframes** on the weapon node for discrete clips (reload, melee, draw). Imported glTF clips only matter once a rig exists.
2. The clipping/FOV problem has an **engine-native answer since Godot 4.5**: `BaseMaterial3D.use_z_clip_scale` / `z_clip_scale` and `use_fov_override` / `fov_override`, added by [godot PR #93142](https://github.com/godotengine/godot/pull/93142) specifically to replace SubViewport overlays for FPS weapons and hands. This project is on 4.7, so the SubViewport second-camera setup that Kenney's kit and most tutorials use is no longer necessary.
3. **No CC0 or CC-BY first-person arms rig ships a pistol set** (idle, fire, reload, melee, sprint-lower). The best CC0 base is [WRAD ARMS](https://wriks.itch.io/wrad-arms) (rigged, 1200 tris, no animations). The only CC-BY arms+pistol animation bundle found is [LokitoBlu's Pistol Animations](https://sketchfab.com/3d-models/pistol-animations-blender-93e5143258aa48b4a20c836177969f34) (14.3k tris, realistic style, no melee/sprint). The arms option stays reachable but means authoring clips ourselves.

**Recommendation:** keep the weapon-only viewmodel (per the standing preference in #29), keep it under `Head/Camera3D`, drive sway/bob/recoil/FOV-push procedurally, keyframe reload/melee/lower with an AnimationPlayer on the `Weapon` node, and apply `fov_override` + `z_clip_scale` on the blaster's material for FOV independence and anti-clipping. Details in section 4.

## 1. How Godot 4 animates a weapon viewmodel

### 1.1 AnimationPlayer keyframes on the weapon node

The [animation introduction](https://docs.godotengine.org/en/stable/tutorials/animation/introduction.html) states an AnimationPlayer can animate "anything available in the Inspector, such as Node transforms, sprites, UI elements, particles, visibility and color of materials"; with the Animation panel open, each Inspector property gets a keyframe button, and "One AnimationPlayer node can hold multiple animations". Animations live in an [AnimationLibrary](https://docs.godotengine.org/en/stable/classes/class_animationlibrary.html) ("stores a set of animations accessible through StringName keys"), and [Animation.loop_mode](https://docs.godotengine.org/en/stable/classes/class_animation.html) is `LOOP_NONE`, `LOOP_LINEAR` or `LOOP_PINGPONG`.

For a weapon-only viewmodel this is the whole pipeline: put an AnimationPlayer next to the `Weapon` Node3D, key `position`/`rotation` of `Weapon` (and optionally the blaster's child parts, e.g. a magazine mesh) for `reload`, `melee`, `lower`, `raise`. Nothing needs to be exported from Blender.

### 1.2 Imported glTF clips

Per the [import configuration](https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_3d_scenes/import_configuration.html) docs, a glTF imported as a Scene gets an AnimationPlayer with its clips; the Animation import options are **Import**, **FPS**, **Trimming** and **Remove Immutable Tracks**, and the Import dock can switch the file to **Animation Library** mode to yield an AnimationLibrary shared across scenes. [Node type customization](https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_3d_scenes/node_type_customization.html): clips whose name starts or ends with `loop` or `cycle` import with the loop flag set. [Advanced import settings](https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_3d_scenes/advanced_import_settings.html) allow per-clip **Save to File** and **Slices** (splitting one `default` timeline into named clips with loop toggles).

This path only pays off with a skinned rig (arms). Kenney's blaster glTFs carry no animations.

### 1.3 Blending states: AnimationTree

[Using AnimationTree](https://docs.godotengine.org/en/stable/tutorials/animation/animation_tree.html): root nodes `AnimationNodeStateMachine` (Immediate / Sync / At End transitions with advance conditions), `AnimationNodeBlendTree`, `BlendSpace1D/2D`, and `OneShot`. `OneShot` over an idle loop is the natural fit for fire/reload; the state machine is driven from GDScript via `animation_tree["parameters/playback"].travel("Reload")`. For a handful of weapon clips a bare AnimationPlayer plus `animation_finished` is enough; AnimationTree becomes worth it when sprint-lower must blend with reload.

### 1.4 The procedural layer (sway, bob, recoil, FOV push)

Every well-regarded Godot 4 FPS project does this in `_process`/`_physics_process` on a holder Node3D, not in animation clips.

[KenneyNL/Starter-Kit-FPS](https://github.com/KenneyNL/Starter-Kit-FPS) (README: Godot 4.6; code MIT, assets CC0) has **no AnimationPlayer at all**. From [objects/player.gd](https://github.com/KenneyNL/Starter-Kit-FPS/blob/main/objects/player.gd):

```gdscript
@onready var container = $Head/Camera/SubViewportContainer/SubViewport/CameraItem/Container
# velocity-driven sway/lag every frame
container.position = lerp(container.position, container_offset - (basis.inverse() * applied_velocity / 30), delta * 10)
# recoil on shoot: push the holder back and kick the camera pitch
container.position.z += 0.25
camera.rotation.x += knockback.x
rotation_target.x += knockback.x
# weapon switch dip
tween.tween_property(container, "position", container_offset - Vector3(0, 1, 0), 0.1)
tween.tween_callback(change_weapon)
```

Weapon numbers (`cooldown`, `spread`, `knockback`, `min_knockback`/`max_knockback: Vector2`, `muzzle_position`, `model: PackedScene`) live in a `Weapon` `Resource` ([scripts/weapon.gd](https://github.com/KenneyNL/Starter-Kit-FPS/blob/main/scripts/weapon.gd)), which matches the "weapon behaviour stays data" preference in #29. Kenney's kit does no FOV kick and no mouse sway.

[Jeh3no/Godot-Simple-FPS-Weapon-System-Asset](https://github.com/Jeh3no/Godot-Simple-FPS-Weapon-System-Asset) (Godot 4.4-4.7, GDScript) lists weapon bobbing, tilting, swaying, camera procedural recoil, and resource-based weapon components; [Dodoveloper/godot4-fps-prototype](https://github.com/Dodoveloper/godot4-fps-prototype) (4.2+) lists procedural visual recoil, sway/tilt/bob and muzzle flash. [Whimfoome/godot-FirstPersonStarter](https://github.com/Whimfoome/godot-FirstPersonStarter) is look/movement only with no weapon code, so it is not a viewmodel reference. (`Jorge-Ruiz-Guillen/godot4-fps-viewmodel`, a Lukky repo and a GarbajYT Godot 4 repo were not found and are not cited.)

The common shape, distilled:

- **Sway**: on `_unhandled_input` mouse motion accumulate a small target rotation on the holder, lerp back to zero each frame.
- **Bob**: `sin(time * freq)` offsets on holder position scaled by horizontal speed; zero when airborne.
- **Recoil**: additive kick on holder z/rotation plus a camera pitch kick that decays (Kenney above).
- **FOV push**: `camera.fov = lerp(camera.fov, base_fov + sprint_bonus, delta * k)` on sprint/slide. Camera FOV changes are why the weapon's FOV must be decoupled (section 2).

## 2. Keeping the viewmodel out of walls and at its own FOV

Three techniques exist; the engine added a fourth in 4.5 that supersedes the others for this project.

### 2.1 SubViewport + second Camera3D (the "weapon camera")

What Kenney's kit does. From [objects/player.tscn](https://github.com/KenneyNL/Starter-Kit-FPS/blob/main/objects/player.tscn):

```
Player (CharacterBody3D)
└─ Head (Node3D)
   └─ Camera (Camera3D, fov 80, cull_mask excludes layer 2)
      ├─ SubViewportContainer (anchors full rect, stretch = true)
      │  └─ SubViewport (transparent_bg = true, handle_input_locally = false, msaa_3d = 1, size 1280x720, render_target_update_mode = 4)
      │     └─ CameraItem (Camera3D, fov = 40, cull_mask = 1047554  # layer 2 only)
      │        ├─ Container (Node3D)   # weapon meshes instanced here with child.layers = 2
      │        └─ Muzzle (AnimatedSprite3D)
      └─ RayCast (RayCast3D)
```

Relevant engine facts: [Camera3D.cull_mask](https://docs.godotengine.org/en/stable/classes/class_camera3d.html) "describes which VisualInstance3D.layers are rendered by this camera"; [VisualInstance3D.layers](https://docs.godotengine.org/en/stable/classes/class_visualinstance3d.html) makes an object "only ... visible for Camera3Ds whose cull mask includes any of the render layers"; [Viewport.transparent_bg](https://docs.godotengine.org/en/stable/classes/class_viewport.html) renders the viewport background transparent; each Viewport has its own current camera (`get_camera_3d()`); a [SubViewportContainer](https://docs.godotengine.org/en/stable/classes/class_subviewportcontainer.html) "displays the contents of underlying SubViewport child nodes" and is stacked over the 3D world purely by Control draw order.

Trade-offs: the weapon gets an independent FOV and can never intersect world geometry, but the scene is rendered twice ([proposal #956](https://github.com/godotengine/godot-proposals/issues/956), still open, and PR #93142 both name the cost), lighting/environment must be shared via `world_3d` or duplicated, MSAA/size are configured separately, and [matiturock/fps-tutorial](https://github.com/matiturock/fps-tutorial)'s README reports shadows not rendering on subviewport models.

### 2.2 Same camera, small `near` plane, weapon scaled down and close

Uses only `Camera3D.near` and render layers. The docs warn `near` below the default `0.05` "can lead to increased Z-fighting" and lowers depth precision across the whole range ([Camera3D](https://docs.godotengine.org/en/stable/classes/class_camera3d.html)). The weapon still shares the world FOV and still clips when a wall is nearer than the weapon's extent. Adequate for a prototype only.

### 2.3 Shader depth squash

Community shaders squash clip-space depth in `vertex()`: the [majikayogames gist](https://gist.github.com/majikayogames/94ac6c76650a609e4db09febb82ab197) (CC0, 4.3+ reverse-Z aware) uses `POSITION.z = mix(POSITION.z, POSITION.w, 0.9);` plus a `viewmodel_fov` uniform that rewrites the projection, and a GDScript helper that swaps every MeshInstance3D's StandardMaterial3D for the ShaderMaterial. The cheaper `BaseMaterial3D.no_depth_test` is a poor fit because it "puts the object in the transparent draw pass" and [Material.render_priority](https://docs.godotengine.org/en/stable/classes/class_material.html) cannot order it against opaque geometry, so a multi-part gun sorts wrongly against itself.

### 2.4 Engine-native (Godot 4.5+): `z_clip_scale` and `fov_override`

[godot PR #93142](https://github.com/godotengine/godot/pull/93142) (clayjohn, merged May 2025, milestone 4.5; origin [proposals discussion #8941](https://github.com/godotengine/godot-proposals/discussions/8941)) adds to StandardMaterial3D/BaseMaterial3D:

- [`use_z_clip_scale` / `z_clip_scale`](https://docs.godotengine.org/en/stable/classes/class_basematerial3d.html) (default `1.0`): scales the object toward the camera in the depth test so it does not clip walls; lighting and shadows stay correct, though SSAO/SSR may break at low scales.
- [`use_fov_override` / `fov_override`](https://docs.godotengine.org/en/stable/classes/class_basematerial3d.html) (default `75.0`): "Overrides the Camera3D's field of view angle (in degrees)" for that material only.
- Shader built-ins `Z_CLIP_SCALE` and `IN_SHADOW_PASS` for custom spatial shaders ([spatial shader reference](https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/spatial_shader.html)).

The PR's stated purpose is exactly this problem: "For FPS games managing arms/objects/weapons can be a nightmare as you want them to have believable lighting, but you also want to ensure they don't clip through walls and you need to tweak their perspective." It is the recommended path on 4.7.

## 3. CC0 / CC-BY first-person arms rigs with a pistol set

Sources fetched: Kenney, Quaternius, KayKit, itch.io, Sketchfab, OpenGameArt, Poly Pizza, Godot Asset Library. Licence text quoted from each asset page.

### 3.1 The big CC0 houses have nothing

- **Kenney**: no arms/hands packs ([search](https://kenney.nl/assets?q=arms)); [Blaster Kit](https://kenney.nl/assets/blaster-kit) is weapon meshes only; the Animated Characters packs are full-body third-person. [Starter-Kit-FPS/models](https://github.com/KenneyNL/Starter-Kit-FPS/tree/main/models) holds only `blaster.glb`, `blaster-repeater.glb` and environment meshes: the reference kit is weapon-only too.
- **Quaternius**: gun packs and full-body characters, no FPS arms ([pack list](https://quaternius.com/)); [Ultimate Guns](https://quaternius.com/packs/ultimategun.html) is unanimated. Caveat: [quaternius.com/license.html](https://quaternius.com/license.html) now shows a "Quaternius Asset License (QAL) v1.0" (updated 2026-08-28) alongside pack pages still saying CC0; check the LICENSE in any download.
- **KayKit**: third-person only ([storefront](https://kaylousberg.itch.io/)).
- **Godot Asset Library**: "fps arms" for Godot 4 returns [0 results](https://godotengine.org/asset-library/asset?filter=fps+arms&godot_version=4); [FPS Hands (Bytez)](https://godotengine.org/asset-library/asset/3715) is GPLv3 (knife/rifle/SMG).
- **GDQuest godot-4-fps-arms** has idle/walk/shoot/reload but the art is [CC-BY-NC-SA 4.0](https://raw.githubusercontent.com/gdquest-demos/godot-4-fps-arms/main/LICENSE): excluded.

### 3.2 Candidates that exist

| Asset | Licence | Format / size | Animations | Fit |
|---|---|---|---|---|
| [WRAD ARMS](https://wriks.itch.io/wrad-arms) (wriks, itch) | "Creative Commons Zero v1.0 Universal" | GLB/FBX/OBJ, 1200 tris, 512px, IK-rigged, 2 skins | **None** | Best CC0 base; GoldSrc-style low poly sits well next to Kenney blasters. Clips must be authored. |
| [PSX First Person Arms](https://drillimpact.itch.io/psx-first-person-arms-free) (Drillimpact, itch) | "released under CC0 (Public Domain)" | FBX/GLB/Blend, 512px, 2 textures | relax, push L/R, jab L/R, guard_draw/idle, grab L/R, finger_gun_idle/fix/fire/broken, knife_draw/hit_01/hit_02/idle | CC0 melee/unarmed set; **no pistol**. Its jab/knife clips could seed a melee. |
| [Pistol Animations (BLENDER)](https://sketchfab.com/3d-models/pistol-animations-blender-93e5143258aa48b4a20c836177969f34) (LokitoBlu, Sketchfab) | CC Attribution 4.0 | 14.3k tris, arms included | Idle, Walk, Jump, Draw/NotDraw, Fire, Reload (fast, complete) | Only verified CC-BY arms+pistol set. **No melee, no sprint-lower**; mid-poly realistic style clashes with Kenney. |
| [Cartoon FPS Arms](https://sketchfab.com/3d-models/cartoon-fps-arms-25d06c227fa3419b92fe65f39887b0b8) (DJMaesen, Sketchfab) | CC Attribution | 1.3k tris, rigged | None | Good CC-BY low-poly base, unanimated. |
| [Rigged FPS Arms](https://sketchfab.com/3d-models/rigged-fps-arms-6b1cde4746774b7893513f84cac7a866) (RafaP) / [Low Poly FPS Arms](https://sketchfab.com/3d-models/low-poly-fps-arms-4b2a03333baf42aa82182e73ac4f4fc5) (BIGMACorSomething) | CC Attribution | 4.8k / 4.6k tris, rigged | None | Unanimated bases. |
| [fps arms (rigged only)](https://opengameart.org/content/fps-arms-rigged-only) (para, OGA) | CC0 | blend/fbx, ~8k tris | one "very crude" sample | MakeHuman-derived, too realistic. |
| [Low Poly FPS Rifle and Hands](https://opengameart.org/content/low-poly-fps-rifle-and-hands) (Robin Lamb, OGA) | CC0 | Blend/FBX/glTF/OBJ | one shoot | Rifle, not pistol. |
| [Low Poly - FPS Arms Pack](https://opengameart.org/content/low-poly-fps-arms-pack) (NetSriK, OGA) | CC-BY 4.0 | .blend, includes pistol + arms | "Not Animated Yet" | Base only. |
| [PSX-Weapons Assets Free Pack](https://kuptchi.itch.io/f) (Kuptchi, itch) | **Not a CC licence**: "free to use by anyone, for anything without any need to credit us (just don't resell it please)" | FBX/Blend, 482 MB | 80+ incl. pistol idle/fire/reload | Functionally closest, but unnamed licence and PSX-realistic look. Not recommended. |

Excluded on licence: [Low Poly Arms Rig](https://keyschain.itch.io/first-person-arms-rig) (CC BY-ND, no derivatives), [Low-poly FPS Arms (Rigged)](https://sketchfab.com/3d-models/low-poly-fps-arms-rigged-ae2aab6803334a52b0ad517c3489b5a3) (CC BY-NC), Synty ([proprietary EULA](https://syntystore.com/pages/licences-overview)), Mixamo (Adobe terms, full-body only; Adobe FAQ returned 403). Poly Haven has no character/hand models ([API listing](https://api.polyhaven.com/assets?type=models)).

### 3.3 Honest verdict

There is no CC0 or CC-BY low-poly arms rig with the requested pistol set. If arms ever become the plan, the realistic route is **WRAD ARMS (CC0)** plus a Kenney blaster parented to the hand bone, with the five clips authored in Blender (idle/fire/lower are quick; reload and melee are each roughly a day), optionally lifting melee timing from Drillimpact's CC0 jab/knife clips. LokitoBlu's CC-BY set is the only shortcut and would need decimation and a retexture to sit beside Kenney art.

## 4. Recommendation for this project

Confirms the standing preference in #29: weapon viewmodel plus camera work, no arms.

1. **Node setup** (no SubViewport; project is on 4.7):
   ```
   Player (CharacterBody3D)
   └─ Head (Node3D)                          # yaw/pitch look, as today
      └─ Camera3D (fov 75, near 0.05)        # base_fov exported; FOV push lerps this
         ├─ Muzzle (Node3D)
         └─ Weapon (Node3D)                  # procedural sway/bob/recoil offsets on this transform
            ├─ AnimationPlayer               # reload, melee, lower, raise keyed on Weapon and blaster parts
            └─ Blaster (blaster-d.glb)       # material: use_fov_override + fov_override ~50-60, use_z_clip_scale + z_clip_scale ~0.5, layers left default
   ```
   Do the material change as a material override on the blaster's MeshInstance3D (or a small helper that sets the flags on every surface), so the Kenney glTF import stays untouched.
2. **Procedural layer** in `player_3d.gd` (or a `ViewmodelMotion` script on `Weapon`): mouse sway, speed-scaled bob, recoil kick on `Weapon` plus a camera pitch kick that decays, and FOV push on sprint/slide. Numbers are exported and settled by prototype, per #29.
3. **Clips**: AnimationPlayer keyframes on `Weapon` for `reload`, `melee`, `lower`/`raise`. Play through the AnimationPlayer directly with `animation_finished` replacing the bare reload timer; move to an AnimationTree `OneShot` only if sprint-lower must blend with reload.
4. **Weapon data** as a `Resource` in the Kenney shape (cooldown, knockback range, spread, magazine, projectile scene) so later weapons are modifiers.
5. **Arms** remain reachable via WRAD ARMS + self-authored clips; not planned.

Open question for the prototype ticket: does `z_clip_scale` alone keep the blaster clean in the ship's narrowest corridors and doorways, or does the weapon also need a small "pull in" when a short forward raycast from the camera hits within ~0.5 m (the classic Halo wall-push)? Both are cheap to test.
