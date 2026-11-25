Type: prototype
Status: resolved
Blocked by: none
Map: ../map.md

# How Attachments mount on a gun model

## Question

How does an Attachment's model go onto a gun's model so that it looks right in the Viewmodel? Build one gun (the Assault Rifle) with a rough Attachment in each of its Slots and look at it in first person.

- Does an Attachment add a mesh at a mount marker, replace part of the gun's mesh (its barrel, magazine or stock), or both, depending on the Slot? What does that ask of the existing gun scripts in `tools/blender/` and the scenes in `scenes/weapons/`?
- A Barrel moves the `Muzzle`; a Sight moves the `SightTip`: who owns those markers once Attachments exist?
- Do the gun's own clips (fire, reload, rack) still read with a different Magazine or Stock on it?
- Does a longer or bulkier gun still sit right at the hip, lowered and in Aim Down Sights, or do the poses need to follow the Attachments?

## Answer

Prototyped and played by the user on 2026-11-24; verdict: "All looks right" on every point below.

**Prototype (primary source)**: local branch `prototype/attachment-mounting` (commit 3f8d434, never merged, not pushed).

- `tools/blender/proto_ar_split.py`: the Assault Rifle with its barrel, iron sights, stock and cell as separate meshes on one skeleton.
- `tools/blender/proto_ar_attachments.py`: rough Attachments for all five Slots.
- `scenes/proto_attachment_mounting.tscn` and `scripts/proto/proto_attachment_mounting.gd`: a Raid that cycles them. Run with `flatpak run org.godotengine.Godot --path . res://scenes/proto_attachment_mounting.tscn -- --seed=7 --class=large`; add `--selftest` for a headless check.

**How an Attachment goes on**

- An Attachment either adds itself or takes the place of one of the gun's own parts. Which one is a fact about the Attachment, not the Slot: in the Barrel Slot the Suppressor adds to the gun's barrel while the Long and Short Barrel replace it.
- As prototyped: Sights replace the iron sights; Long and Short Barrel replace the barrel; Magazines replace the cell; Stocks replace the stock; Suppressor, Foregrip and Laser add.
- So each gun's model keeps every replaceable part (barrel, sights, magazine, stock) as its own mesh that can be hidden, where today everything is joined into one. `kit.rig` joins all meshes; the prototype's `rig_parts` keeps them apart on one skeleton, and the baked atlas is shared, so the gun looks as it does today.

**Markers**

- A Barrel brings its own `Muzzle`; a Sight brings its own `SightTip`. With one fitted, the Viewmodel takes the marker from the Attachment in place of the gun's, and works out the aimed pose from it as it does now. Flash, tracer and the centred sight all followed in play.

**Clips**

- A Magazine rides the bone that carries the gun's own magazine, so the gun's existing reload clip drops and seats it. The Extended Magazine and the Drum both read with the Assault Rifle's clip: no clip per Magazine.
- Fire, rack and recoil are untouched by any build.

**Poses**

- The hip, lowered and aimed poses stay the weapon's own. They do not follow the Attachments: the Long Barrel, the Suppressor and the Heavy Stock (which shows in the bottom corner at the hip) all sat right for the user.
- A Sight needs no aimed distance of its own.

**Found while building**

- Godot's importer renames a bone that shares its name with a mesh (`Cell` becomes `Cell_2`). The build should name bones and meshes apart.
- Attachments added after the Viewmodel mounts a model need the same material flags (`_flag_materials`: FOV override, clip scale) as the gun.

**Not tested here**

- The prototype's Attachments were built in the Assault Rifle's own space. Sharing one Attachment across guns needs a mount point per Slot on each gun, with the Attachment built around its own origin. "What each Attachment looks like" is where that first meets the other three guns.
