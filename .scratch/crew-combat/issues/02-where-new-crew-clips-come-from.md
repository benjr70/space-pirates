Type: research
Status: resolved
Map: ../map.md

# Where new crew clips come from

## Question

The crew rig (`assets/models/crew/soldier.glb`, with `engineer.glb` re-dressed on the same skeleton) has five clips: `Idle`, `Idle_Gun`, `Run`, `Walk`, `Death`. This effort needs more: a crouch held behind low cover, a lean or step out to shoot and back, a crouched run, a reload, a cower, and hands raised in surrender (standing and kneeling).

Where can each come from, and what does each route cost?

- Clips already in the Quaternius packs the rig came from, or in other Quaternius packs on a matching skeleton.
- Free libraries (Mixamo, others): licence terms, and how a clip is retargeted onto this skeleton in Blender headless or in Godot 4's retargeting, given the armature export fix this repo already uses.
- Made by hand in Blender on this rig.
- Done in code instead of a clip: a Godot 4 `SkeletonIK3D` or bone pose override for a lean, raised hands or a crouch.

Also report how the weapon scenes under `scenes/weapons` would attach to the rig's hand so a Guard can be seen carrying any of the four guns, and whether the existing `Idle_Gun` pose suits a two-handed long gun.

Recommend a route per clip. Looks are judged later by the user in a prototype scene; this ticket only finds what is possible.

## Answer

Researched 2026-11-25. Full findings: `docs/research/crew-clips.md` on branch `research/crew-clips` (commit `612f492`, pushed, never merged). Nothing was built or imported; costs are estimates.

Facts that correct the ticket:

- The rig holds 24 clips, not five; crew code plays six. Unused ones include `Run_Left`, `Run_Right`, `Run_Back`, `Run_Shoot`, `Gun_Shoot`, `Idle_Gun_Shoot`, `Idle_Gun_Pointing`, `Roll`, `HitRecieve`, `Wave` and `Idle_Neutral`. None is a crouch, a kneel or raised hands.
- The rig is most likely from Quaternius's Ultimate Modular Men Pack, which has nothing more to give.
- `Foot.L/R` and the pole bones are children of `Root`, not of the shins. Godot's humanoid BoneMap retargeting therefore does not fit this rig, but a crouch is cheap in Blender: lower `Body`, re-solve the legs onto the feet, bake.
- Quaternius's Universal Animation Library 1 (free tier) has `Crouch_Idle_Loop`, `Crouch_Fwd_Loop` and `Pistol_Reload` on a different skeleton, so anything from it needs a Blender retarget bake. It has no surrender, cower or rifle clip.
- Godot 4.7 has `SkeletonModifier3D`, `LookAtModifier3D` and `TwoBoneIK3D`. `SkeletonIK3D` is on its way out.
- Crew hold no gun today: no gun mesh, no attachment; bolts are born at a computed point.

Recommended route per clip (about 4 agent-days in all, no money):

| Clip | Route | Risk |
|---|---|---|
| Crouch hold | Blender script on this rig | Low to medium |
| Lean or step out | No new clip: blend crouch to `Idle_Gun_Pointing`, side-step with `Run_Left`/`Run_Right`; optional torso lean as a `SkeletonModifier3D` | Low |
| Crouched run | Same Blender script, derived from `Run`; fallback is retargeting `Crouch_Fwd_Loop` | Medium |
| Reload | Retarget arms and spine of the library's `Pistol_Reload` over the crouch | Medium: it is a pistol reload and arm lengths differ |
| Cower | Posed in Blender by script | Low |
| Surrender, standing | `Wave`'s raised arm mirrored to both sides | Low |
| Surrender, kneeling | Posed in Blender, legs re-solved | Medium |

New clips go onto the Soldier by one Blender script that also bakes it to metres; re-running `build_engineer.py` carries them to the Engineer.

Carrying a gun: a `BoneAttachment3D` on `Wrist.R` with the Weapon Profile's model scene under it and a grip transform found by eye. `Idle_Gun` does not suit a long gun: a Guard with one needs a shouldered-hold pose made in Blender and a `TwoBoneIK3D` putting the left hand on the fore-end. Neither was on the ticket's list.

Not verified: Mixamo's licence (Adobe's page refused the fetch; a forum post says raw animation files may not be redistributed, which would be a problem in a public repo), so Mixamo is not recommended. Quaternius's site now shows an asset licence dated 2026-08-28 beside the packs' CC0 wording; either allows use in the game.
