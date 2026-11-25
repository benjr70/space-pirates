# Where new crew clips come from

Research for `.scratch/crew-combat/issues/02-where-new-crew-clips-come-from.md`, 2026-11-25.
Nothing was made or imported; this only finds what is possible.

The redesign needs seven clips: a crouch held behind low cover, a lean or step
out to shoot and back, a crouched run, a reload, a cower, and hands raised in
surrender, standing and kneeling.

Each claim is marked with where it comes from: **[file]** read from this
repository, **[measured]** from a headless Blender or Godot script run on the
repository's files, **[source]** a cited web page, **[inferred]** my reasoning
from those. Estimates of cost are mine and are in agent working days.

## Recommendation

| Clip | Route | Cost | Risk |
|---|---|---|---|
| Crouch held behind low cover | Built in Blender on this rig by script: lower the `Body` bone, re-solve the legs onto the existing `Foot` bones, hunch the spine, bake. Arms from `Idle_Gun`. | 1 day, including the build script the other clips share | Low to medium: knee direction and mesh clipping need a screenshot pass |
| Lean or step out to shoot and back | No new clip. Over low cover: blend from the crouch clip to `Idle_Gun_Pointing` and back. Round a corner: side-step with the rig's unused `Run_Left` and `Run_Right`. A torso lean, if wanted, is a small custom `SkeletonModifier3D` in code. | 0.25 day of state code; 0.5 day more for the lean modifier | Low |
| Crouched run | Built in Blender by the same script, from the existing `Run`: same lowered `Body` and re-solved legs, foot lift scaled down, baked as a new clip. | 0.5 day on top of the crouch | Medium: a run's high foot lift under lowered hips may fold the legs too far; the fallback is retargeting `Crouch_Fwd_Loop` from Universal Animation Library 1 |
| Reload | Retarget the arms and spine only of `Pistol_Reload` (Universal Animation Library 1, free tier) in headless Blender, laid over the crouch pose. | 1 day | Medium: the two rigs' arms differ in length, so the hands may not meet; and it is a pistol reload, which will not suit a long gun |
| Cower | Posed in Blender on this rig by script: the crouch pose, head down, arms over the head, a small tremble. | 0.25 day | Low |
| Surrender, standing | Posed in Blender by script: the raised left arm of the rig's own `Wave` clip, mirrored onto the right arm, over `Idle_Neutral`. | 0.25 day | Low |
| Surrender, kneeling | Posed in Blender by script: `Body` lowered to a kneel, `Foot` bones moved back and turned toes-down, legs re-solved, the same raised arms. | 0.5 day | Medium: knee contact with the floor on a stylised low-poly body |

About 4 days in all, no money, and no new licence: every recommended clip is
either made from the rig's own clips or from one free Quaternius clip.

The reason the Blender route wins for most of them is the rig itself (see
[The rig](#the-rig)): its feet are not children of its shins, which makes the
legs hard to retarget onto and easy to re-solve.

Two findings change the question as it was asked:

- The rig carries **24 clips, not five** **[measured]**. The crew code plays six
  of them. The unused ones include four-way strafes, a roll, two shooting
  clips, two hit reactions and a wave.
- Nothing free that was found has a surrender or a cower. Those two have to be
  made whichever route the others take.

## The rig

### Which pack

`soldier.glb` and `gunner.glb` are Quaternius's "SWAT" and a space-suit
character, downloaded from poly.pizza as CC0 **[file: `assets/models/crew/LICENSE.txt`]**.
The poly.pizza page names the model "SWAT", by Quaternius, "Public Domain
(CC0)", and names no pack **[source: https://poly.pizza/m/Btfn3G5Xv4]**.

The pack is most likely the **Ultimate Modular Men Pack** **[inferred]**: its
page says "11 Different characters with 24 animations!" and "Each character is
divided into 4 models that can be swapped", CC0
**[source: https://quaternius.com/packs/ultimatemodularcharacters.html]**, and
each crew glb holds exactly 24 clips and four meshes (`Swat_Legs`, `Swat_Feet`,
`Swat_Body`, `Swat_Head`) **[measured]**. The pack page does not list its
characters or clips, so this is a match on counts and not a confirmed name.

It follows that there are no further clips to be had from the rig's own pack:
all 24 are already in the file.

### Clips

All three glbs hold the same 24 **[measured: glb JSON chunk]**, each named with
a `CharacterArmature|` prefix:

| Clip | Seconds | Used by `crew.gd` |
|---|---|---|
| `Idle` | 1.67 | yes |
| `Idle_Gun` | 1.67 | fallback only |
| `Idle_Gun_Pointing` | 1.67 | yes, in FIGHT |
| `Idle_Gun_Shoot` | 0.67 | no |
| `Gun_Shoot` | 0.58 | no |
| `Idle_Neutral` | 1.67 | no |
| `Idle_Sword` | 1.67 | no |
| `Run` | 0.79 | yes |
| `Run_Back`, `Run_Left`, `Run_Right` | 0.79 to 0.83 | no |
| `Run_Shoot` | 0.83 | no |
| `Walk` | 1.33 | yes |
| `Roll` | 1.33 | no |
| `HitRecieve`, `HitRecieve_2` | 0.54 | no |
| `Death` | 1.04 | yes |
| `Interact` | 1.25 | no |
| `Wave` | 1.67 | no |
| `Kick_Left`, `Kick_Right`, `Punch_Left`, `Punch_Right`, `Sword_Slash` | 0.83 to 1.00 | no |

None is a crouch, a kneel or raised hands **[measured]**: outside `Death` and
`Roll`, the hips never drop below 0.81 m on a rig whose hips rest at 0.89 m.
`Wave` raises the left hand only, to 0.27 m above the chest with the fingers
pointing up.

`crew.gd` plays `Run`, `Walk`, `Idle_Gun_Pointing` (in FIGHT), `Idle` and
`Death` **[file: `scripts/crew/crew.gd`, `_update_animation` and `_on_died`]**.

### Skeleton

62 bones, the same names in all three files **[measured]**:

```
CharacterArmature (node, scale 100, rotated -90 degrees about X)
  Root
    Body
      Hips > Abdomen > Torso > Chest
        Neck > Head
        Shoulder.L > UpperArm.L > LowerArm.L > Wrist.L > Index1-4, Middle1-4, Ring1-4, Pinky1-4, Thumb1-3 (.L)
        Shoulder.R > ... the same on the right
      UpperLeg.L > LowerLeg.L
      UpperLeg.R > LowerLeg.R
    Foot.L   PT.L
    Foot.R   PT.R
```

Three things about it decide the routes:

1. **The feet are children of `Root`, not of the shins** **[measured]**. `Foot.L`
   and `Foot.R` are leg IK handles baked into the export, and `PT.L`, `PT.R` are
   their pole targets. `Run` keys `Foot` rotation and position and `PT`
   position in root space, beside `UpperLeg` and `LowerLeg` rotations.
2. **`Body` carries the hips and both legs**, and is the only bone the standing
   clips move in position **[measured]**.
3. **`soldier.glb` and `gunner.glb` keep the x100 armature scale; `engineer.glb`
   does not** **[measured]**. In the two FBX2glTF files the `CharacterArmature`
   node has scale 100 and the bones are in hundredths of a metre.
   `build_engineer.py` applies that transform to the armature and its meshes
   and multiplies every bone location key by the scale, so `engineer.glb` is in
   metres under an identity node **[file: `assets/models/crew/build_engineer.py`]**.
   Runtime code already copes with both: `HeadZone.attach` divides by the bone's
   measured scale **[file: `scripts/crew/head_zone.gd`]** and `_dress` fits each
   rig to 2.0 m by its measured height **[file: `scripts/crew/crew.gd`]**.

The clips are sparse in the two FBX2glTF files: `Idle` keys 21 bones,
`Idle_Gun_Pointing` 35, `Run` 50. The Blender export of `engineer.glb` keys all
62 bones in every clip **[measured]**.

### One file feeds the other

`build_engineer.py` imports `soldier.glb`, keeps every action it finds and
exports them all into `engineer.glb` **[file]**. So a clip added to the
Soldier's file reaches the Engineer by re-running that script. A clip added to
`engineer.glb` alone would not reach the Soldier, and could not be copied
across as it stands, since the two files differ in units and in bone rests
after the transform was applied **[inferred]**.

Any Blender route therefore wants one script that loads the Soldier, adds the
new actions, and writes a Soldier in metres the way `build_engineer.py` writes
the Engineer, with `build_engineer.py` re-run after it. The untouched download
should stay beside it as the source.

## Route 1: clips already made by Quaternius

### The rig's own pack

Exhausted: see [Which pack](#which-pack).

### Universal Animation Library 1 and 2

Quaternius's two animation libraries are the only Quaternius packs found with
anything on the list.

| | Library 1 | Library 2 |
|---|---|---|
| Size | "120+ animations" | "130+ Animations" |
| Free tier | 45 clips | 42 clips |
| Paid tiers | Pro $9.99 (all clips, FBX and GLB), Source $14.99 (adds the .blend) | Source $14.99 |
| Stated licence | CC0 | CC0 |

**[source: https://quaternius.com/packs/universalanimationlibrary.html,
https://quaternius.com/packs/universalanimationlibrary2.html,
https://quaternius.itch.io/universal-animation-library,
https://quaternius.itch.io/universal-animation-library-2]**

The clip lists are published only as images on those pages. Read from the
images **[source: https://quaternius.com/assets/images/fullres/universalanimationlibrary/standard.jpg,
https://quaternius.com/assets/images/fullres/universalanimationlibrary2/standard.jpg,
https://quaternius.com/assets/images/fullres/universalanimationlibrary2/source.jpg]**:

| Wanted | Library 1, free | Library 1, paid only | Library 2 |
|---|---|---|---|
| Crouch hold | Crouch Idle | Crouch Enter, Exit | none |
| Crouched run | Crouch Fwd | Crouch Left, Right, Bwd and four diagonals | none |
| Step out, lean | none | Jog Leaning Left, Right; Dodge Left, Right | none |
| Reload | Pistol Reload | none | none |
| Aim, shoot | Pistol Idle, Shoot, Aim Up, Down, Neutral | none | Bow only |
| Cower | none | Crying, Ground Sit (neither is a cower by name) | Surprise (paid) |
| Surrender, standing | none | none | none |
| Surrender, kneeling | none; Fixing Kneeling is a kneel with the hands busy | Pickup Kneeling | none |

I confirmed the free tier of Library 1 by reading a copy of `UAL1_Standard.glb`:
43 clips and a T-pose, including `Crouch_Idle_Loop` (2.93 s), `Crouch_Fwd_Loop`
(2.00 s), `Pistol_Reload` (1.67 s), `Pistol_Idle_Loop`, `Pistol_Shoot`,
`Pistol_Aim_Up`, `Pistol_Aim_Down`, `Pistol_Aim_Neutral` and `Fixing_Kneeling`
(5.20 s) **[measured]**. That copy came from a third-party public repository,
not from Quaternius's own download.

Every gun clip in both libraries is a pistol clip. There is no rifle idle, aim
or reload.

### Does its skeleton match

No. The library's skeleton is a different rig **[measured]**: 65 bones named in
the Unreal style (`root`, `pelvis`, `spine_01` to `spine_03`, `neck_01`,
`Head`, `clavicle_l`, `upperarm_l`, `lowerarm_l`, `hand_l`, `thigh_l`,
`calf_l`, `foot_l`, `ball_l`), in metres, with no scaled armature node, and
with each foot a child of its calf.

Quaternius describes it as "a universal humanoid rig, which is compatible with
Unreal Engine, Godot and Unity, ready for retargeting"
**[source: https://quaternius.com/packs/universalanimationlibrary.html]**, and
the itch page says it shares its naming with the newer "modular outfits / base
chars" **[source: https://quaternius.itch.io/universal-animation-library]**.
The Universal Base Characters pack says "Compatible with the Universal
Animation Library" **[source: https://quaternius.com/packs/universalbasecharacters.html]**.
That compatibility is with Quaternius's newer characters, not with the older
Modular Men rig the crew wear.

So a library clip reaches the crew only by retargeting: see
[Retargeting onto this rig](#retargeting-onto-this-rig).

### Licence

The pack pages and itch pages all say CC0. The site's licence page, though, now
shows a **Quaternius Asset License (QAL) v1.0**, "Last updated: 8/28/2026",
covering "content made available by Quaternius under this License". It allows
personal, educational and commercial use in a product with no attribution, and
forbids one thing: "You may not extract, repackage, sublicense, sell, or
otherwise redistribute the Assets (in original or modified form) as a
standalone asset, asset pack, stock file, template, or similar product". It
also says changes "will not apply retroactively to Assets you've already
obtained under an earlier version" **[source: https://quaternius.com/license.html]**.

Either licence allows the clips in this game. Which one governs a library
downloaded today is not stated on any page I read.

## Route 2: free libraries

### Mixamo

Adobe's own FAQ could not be fetched: both
`https://helpx.adobe.com/creative-cloud/faq/mixamo-faq.html` and its `/en/`
variant returned HTTP 403 to this session. What follows is therefore weaker
than a primary source.

- A search-engine summary of that helpx page says characters and animations may
  be used royalty free for personal, commercial and non-profit projects, and
  that Mixamo is free with no purchase or subscription.
- A FAQ posted on Adobe's community forum on 2022-09-29 (author "TylerG 3D";
  the page does not say whether he is Adobe staff) lists video games as
  allowed, says credit is not required, and says "really the only thing you
  can't do is distribute the raw character and animation files". It lists free
  distribution of raw files and asset-store packages as not allowed, and says
  the content may not be used to train machine-learning models
  **[source: https://community.adobe.com/t5/mixamo-discussions/mixamo-faq-licensing-royalties-ownership-eula-and-tos/td-p/13234775]**.

If the forum post is right, there is a snag for this project
**[inferred]**: `origin` is a GitHub repository, and a Mixamo-derived clip
committed inside a glb is a raw animation file. In a public repository that is
the one thing the post forbids. A CC0 clip has no such limit.

Mixamo needs an Adobe sign-in and a browser to pick and download clips, so an
agent cannot fetch them; the user would. I did not sign in, so I have not
confirmed which clips its library holds. It is widely used for rifle idles,
crouches and reloads, which is the one gap the Quaternius libraries leave.

### Others

- **Quaternius Universal Animation Library**: covered above. It is the only
  CC0 source found with a crouch and a reload.
- **CMU Graphics Lab Motion Capture Database**: its FAQ page failed to load
  here (a certificate error), so I report nothing about its terms.

I looked no further. A surrender and a cower were in none of the lists I could
read, so a wider search would be for those two clips alone, and both are simple
held poses.

### Retargeting onto this rig

Two tools, and the rig's feet decide between them.

**Godot's import retargeting does not fit this rig.** Godot retargets by mapping
a skeleton's bones onto a `SkeletonProfileHumanoid` through a `BoneMap` in the
advanced import settings; with the Rest Fixer's Overwrite Axis option it then
unifies the bone rests so clips are shared by name. Its reference rules are a
T-pose facing +Z, and "The humanoid should not have a Transform as Node".
Wrong parent-child mappings are flagged, and "animations may not be shared
correctly"
**[source: https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/retargeting_3d_skeletons.html]**.

In `SkeletonProfileHumanoid`, `LeftFoot` is a required bone whose parent is
`LeftLowerLeg` **[measured: Godot 4.7.2, `SkeletonProfileHumanoid.get_bone_parent`]**.
On the crew rig `Foot.L` is a child of `Root`. A humanoid clip's foot track is
a rotation relative to the shin; played on a bone that hangs from the root it
would leave the foot on the floor at its rest place while the leg moves
**[inferred]**. The Soldier also breaks the no-node-transform rule with its
x100 armature, which the Rest Fixer's Apply Node Transform option exists to
fix. `RetargetModifier3D` (a runtime retarget between a parent and child
skeleton) matches bones "with names matching the bone list" of the same kind of
profile **[source: https://docs.godotengine.org/en/stable/classes/class_retargetmodifier3d.html]**
and meets the same foot problem.

Godot's route would work for the upper body alone, but it would also rename the
rig's bones and rewrite its rests on import, which touches `HeadZone.BONE` and
every clip the crew already play. I do not recommend it.

**Headless Blender can do it, per clip, by baking.** Import the crew rig and the
library glb into one scene, constrain each crew bone to its counterpart, bake
the result to an action on the crew rig, and export. The pairs are plain for
the spine, neck, head, arms and fingers, since both rigs have the same chain
there. The legs need more **[inferred]**:

- `UpperLeg`, `LowerLeg` copy the rotations of `thigh`, `calf`.
- `Foot` must be baked in world space: its rotation from the source `foot`, its
  position from the end of the crew rig's own shin, so the foot stays on the
  leg however the proportions differ.
- `Body` takes the height of `pelvis`, scaled by the ratio of hip heights
  (0.89 m here against about 0.92 m there **[measured]**).

Arms differ too: the library's hand rests 0.74 m from the centre line, the
crew's wrist 0.57 m **[measured]**. A clip where the hands must meet, a reload,
will leave them apart unless a second pass pulls them together.

Cost: about 1 day for the retarget script and its first clip, then a quarter of
a day per clip for the screenshot pass. Risk: medium for an upper-body clip,
medium to high for a full-body one.

## Route 3: made in Blender on this rig

Blender runs headless here (`flatpak run org.blender.Blender -b --python
<script>`, version 5.3) and `build_engineer.py` already shows the whole round
trip on this rig: import the Soldier, edit, apply the armature scale, rescale
the location keys, export with animations **[file]**.

The baked leg handles make posed clips cheap **[inferred]**. The export has no
IK constraint, but a script can put one back: an IK constraint on `LowerLeg.L`
aimed at `Foot.L` with `PT.L` as its pole, chain length 2. Then:

- **Crouch**: lower `Body`; the legs fold onto feet that stay where they are;
  add a forward lean on `Abdomen`, `Torso`, `Chest`; bake.
- **Crouched run**: start from the `Run` action, add the same `Body` offset and
  spine lean to its curves, scale the feet's lift, and bake with the legs
  re-solved. The run's timing and foot placement are kept.
- **Kneel**: lower `Body` further, move the `Foot` bones back and turn them
  toes-down, bake.
- **Raised hands**: copy the left arm of `Wave` at its mid frame (hand 0.27 m
  above the chest, fingers up **[measured]**) and paste it mirrored onto the
  right arm. Blender's pose paste has a flipped mode for `.L`/`.R` names.
- **Cower**: the crouch, with the head and chest bowed and both forearms over
  the head, posed by hand through the script.

Every clip made this way should key all the bones it poses and loop, and the
new loops need adding to `LOOPING_CLIPS` in `crew.gd` **[file]**.

A script has no eyes, so each pose is checked the way the repository already
checks models: render, read the picture, adjust. `tests/shots.sh crew` gives
the in-game view **[file: `CLAUDE.md`]**.

Cost: about 1 day for the script with the crouch, then a quarter to half a day
per clip. Risk: low for held poses, medium for the crouched run and the kneel.
Hand-keying a moving action such as a reload this way is possible but slow: it
is four or five key poses of both arms and the fingers, found by trial.

## Route 4: in code instead of a clip

### What Godot 4.7 has

The project runs Godot 4.7 **[file: `project.godot`, `config/features`]**; the
installed flatpak is 4.7.2 **[measured]**.

| Class | Since | What it does |
|---|---|---|
| `SkeletonModifier3D` | 4.3 | Base class. Modifiers are children of the `Skeleton3D` and run in child order, after the `AnimationMixer` has applied its clip. A custom one overrides `_process_modification()`. Each has an `influence` to blend it in and out. |
| `SkeletonIK3D` | 4.0 | The old IK node. Marked "This class may be changed or removed in future versions." |
| `LookAtModifier3D` | 4.4 | Rotates one bone to face a target, with angle limits. "partially replacing the deprecated SkeletonIK3D". |
| `RetargetModifier3D`, `SpringBoneSimulator3D` | 4.4 | Runtime retarget; jiggle bones. |
| `BoneConstraint3D`: `CopyTransformModifier3D`, `AimModifier3D`, `ConvertTransformModifier3D` | 4.5 | Bind one bone to another. |
| `IKModifier3D`: `TwoBoneIK3D`, and through `ChainIK3D` the solvers `SplineIK3D`, `FABRIK3D`, `CCDIK3D`, `JacobianIK3D` | 4.6 | The replacement IK family. `TwoBoneIK3D` takes a root, middle and end bone, a target node and a pole node. |

All of these exist in the installed 4.7.2 **[measured: `ClassDB.class_exists`]**.

Sources: design and the 4.3 date
**[https://godotengine.org/article/design-of-the-skeleton-modifier-3d/]**;
class list **[https://docs.godotengine.org/en/stable/classes/class_skeletonmodifier3d.html]**;
`SkeletonIK3D` notice **[https://docs.godotengine.org/en/stable/classes/class_skeletonik3d.html]**;
`LookAtModifier3D` **[https://godotengine.org/releases/4.4/,
https://docs.godotengine.org/en/stable/classes/class_lookatmodifier3d.html]**;
constraints **[https://godotengine.org/releases/4.5/]**; IK
**[https://godotengine.org/releases/4.6/,
https://docs.godotengine.org/en/stable/classes/class_twoboneik3d.html,
https://docs.godotengine.org/en/stable/classes/class_ikmodifier3d.html]**.
The 4.6 release page says of the IK framework that "Documentation is in the
works".

The same design article says `Skeleton3D`'s global pose override methods are
deprecated, so new code should not pose bones that way.

### What it could do here

- **Lean**: a custom `SkeletonModifier3D` that adds a roll to `Abdomen`,
  `Torso` and `Chest`, driven by one number. About 30 lines; half a day with a
  test. Low risk. It layers over whatever clip is playing, which a lean clip
  would not.
- **Aim up and down**: `LookAtModifier3D` on `Chest` or `UpperArm.R`, so a
  Guard's gun points at a Pirate on a different level. Not on the ticket's
  list, but it is the cheapest win in this table.
- **Raised hands**: `TwoBoneIK3D` per arm to two markers above the shoulders.
  It works, but a posed clip costs less and gives the fingers and shoulders a
  shape as well.
- **Crouch**: a custom modifier lowering `Body`, then a `TwoBoneIK3D` per leg
  (`UpperLeg`, `LowerLeg`, with the end extended, since the shin has no child
  bone) aimed at the `Foot` bone with `PT` as the pole. This is the same
  operation as the Blender crouch, done every frame, and it would turn every
  existing clip into a crouched one, with the depth as one number. Against it:
  two IK solves and a custom modifier on every crew member every frame, the
  Soldier's bones being in hundredths of a metre while the Engineer's are in
  metres, and a result that can only be judged in motion. Baking it once in
  Blender gives the same pictures with none of that.

I recommend code for the lean, and for the off hand on a long gun (below), and
clips for the rest.

## Carrying a gun

### Today

Crew hold nothing. The glbs contain four body meshes and no gun
**[measured]**; `crew_3d.tscn` has only a collision shape, an empty `Model`
node and `Health` **[file]**; the only thing `crew.gd` attaches to the skeleton
is the head zone. A crew member's `weapon` is a `WeaponProfile` used for its
numbers and sounds, and a bolt is born at a computed point, 1.3 m up and
0.625 m ahead of the body, not at a muzzle **[file: `scripts/crew/crew.gd`,
`MUZZLE_HEIGHT`, `MUZZLE_FORWARD`, `_fire`]**.

### Attaching a weapon scene

The pattern is already in the repository twice: `HeadZone.attach` adds a
`BoneAttachment3D` under the rig's `Skeleton3D` and hangs a node from it, and
`WeaponModel` hangs Attachment models from `BoneAttachment3D`s on a gun's own
bones **[file: `scripts/crew/head_zone.gd`, `scripts/weapon_model.gd`]**.
`BoneAttachment3D` "selects a bone in a Skeleton3D and attaches to it"
**[source: https://docs.godotengine.org/en/stable/classes/class_boneattachment3d.html]**.

For a Guard's gun:

1. Add a `BoneAttachment3D` with `bone_name = "Wrist.R"` under the rig's
   `Skeleton3D`, after `_dress`.
2. Instance the profile's `model` scene under it. Each `WeaponProfile` already
   points at its scene in `scenes/weapons` **[file: `resources/weapons/*.tres`]**,
   and each scene is a `Node3D` holding the gun's glb, placed so the origin is
   "where the hand goes", with `Muzzle` and `SightTip` markers inside
   **[file: `scripts/weapon_profile.gd`]**. All four are built the same way, so
   one piece of code carries any of them.
3. Give it a grip transform. The guns point along their own +Z
   **[file: `tools/blender/kit.py`]**; the hand points along the `Wrist.R`
   bone's +Y, towards the knuckles **[measured]**. So the grip is a fixed
   rotation taking the gun's +Z to the bone's +Y, plus a roll to square it with
   the palm and a small offset into the palm. The roll and offset have to be
   found by eye, in screenshots. A per-weapon offset on the profile may be
   needed, as the four grips differ.
4. Undo the rig's scale. Under the Soldier's skeleton a child is a hundred
   times too big; `HeadZone.attach` shows the fix, dividing by the bone's
   measured scale **[file]**. The rig is also fitted to 2.0 m from about 1.6 m,
   a factor near 1.25: left alone, a Guard's gun is a quarter bigger than the
   Pirate's, in proportion to the Guard's hands.
5. Call `WeaponModel.of(model).fit(...)` if Guards are ever to show
   Attachments. Not needed for a bare gun.

The right-hand fingers already close in the gun clips: `Idle_Gun_Pointing`
keys 14 right-hand finger bones that `Idle` leaves alone **[measured]**.

Cost: half a day to a day, most of it the screenshot pass for four grips.

### Does `Idle_Gun` suit a long gun

No **[measured]**. Both gun idles are one-handed:

- `Idle_Gun`: the right arm hangs at the side with the hand pointing straight
  down, the gun beside the thigh. The left arm hangs as in `Idle`.
- `Idle_Gun_Pointing`: the right arm is straight out ahead at chest height, the
  hand 0.42 m in front of the chest. The left arm still hangs at the side,
  0.70 m from the right hand and pointing at the floor.
- `Gun_Shoot`, `Idle_Gun_Shoot` and `Run_Shoot` are the same hold with a kick.

That reads as a pistol at arm's length. An Assault Rifle, Shotgun or Marksman
Rifle held that way is a long gun waved in one fist, with no hand on the
fore-end and no stock at the shoulder.

No free Quaternius clip fixes it: every gun clip in both libraries is a pistol
clip. The route I recommend **[inferred]**:

- One new held pose, made in Blender on this rig: the right hand drawn back to
  the right side of the chest with the elbow bent, as a long gun is shouldered.
  A quarter of a day beside the other posed clips.
- The left hand placed in code: a `TwoBoneIK3D` on `UpperArm.L`, `LowerArm.L`,
  `Wrist.L`, its target a marker on the gun's fore-end. Godot's 4.6 notes give
  this very case, "the arm of a character extend and snap to a weapon"
  **[source: https://godotengine.org/releases/4.6/]**. One solve handles four
  guns of four lengths, where clips would need a pose each. Half a day, plus a
  fore-end marker on each weapon scene. For the Pistol, turn its influence to
  zero and keep `Idle_Gun_Pointing`.

This is two more pieces of work than the ticket lists, and Guards carrying long
guns will not look right without them.

## Not verified

- **Adobe's Mixamo FAQ.** The helpx page returned 403. Mixamo's terms here rest
  on a search summary and a 2022 forum post of unknown authorship.
- **Mixamo's clip list.** It needs a sign-in. Whether it has the rifle, crouch,
  cower and surrender clips is from general knowledge, not checked.
- **The pack name.** "Ultimate Modular Men Pack" matches on counts only.
- **Which Quaternius licence applies today.** Pack pages say CC0; the licence
  page shows QAL v1.0 dated 8/28/2026.
- **The `UAL1_Standard.glb` I read** came from a third-party repository. Its
  clip names agree with Quaternius's own image of the free tier.
- **The paid clips.** Known by name only, from the images. "Crying", "Ground
  Sit", "Jog Leaning" and "Dodge" were not seen in motion.
- **CMU's terms.** The page did not load.
- **Every route's result.** Nothing was built. The leg re-solve in Blender, the
  retarget bake, the grip transform and the left-hand IK are each reasoned from
  the rig's measured structure and the cited docs, not tried. The costs are
  estimates.
- **How Godot treats a bone a sparse clip does not key** when blending from a
  clip that does. Not looked up. Keying every posed bone in new clips avoids
  the question.

## How the files were inspected

Scripts were kept in a scratch directory outside the repository and nothing was
written into it but this file.

- The glb JSON chunks were parsed with a short Python script for nodes, skin
  joints, animation names, lengths and keyed bones.
- Headless Blender 5.3 imported `soldier.glb`, set each action at its start,
  middle and end frame, and printed the world positions of the head, hips,
  wrists and feet and the direction of each hand.
- Headless Godot 4.7.2 loaded the glbs with `GLTFDocument`, printed bone
  parents and rests, checked which modifier classes exist, and read the bone
  parents of `SkeletonProfileHumanoid`.
