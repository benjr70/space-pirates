Type: prototype
Status: resolved
Blocked by: 04, 06
Map: ../map.md

# What each Attachment looks like

## Question

What does each Attachment in the catalogue look like on each gun it fits? Build every Attachment's model in Blender by the mounting method chosen in "How Attachments mount on a gun model", put them on the guns in a turntable scene and in the Viewmodel, and have the user judge each: does it read as what it is at a glance in first person, does it match the guns' style and palette, and can two Attachments in the same Slot be told apart? Record the scripts on the prototype branch so the build can lift them.

## Answer

Prototyped and looked over by the user in a Raid on 2026-11-24; verdict on every model, the shared ones on every gun included: "looks good".

**Prototype (primary source)**: local branch `prototype/attachment-look` (commit a427b8a, never merged, not pushed). The build lifts its models from here.

- `tools/blender/proto_attachments.py`: all fourteen Attachments, in the guns' palette, baked to one atlas.
- `tools/blender/proto_split_gun.py`: builds any of the four guns from its own untouched script with the replaceable parts left as separate meshes and a mount point per Slot.
- `scenes/proto_attachment_look.tscn` and `scripts/proto/proto_attachment_look.gd`: a Raid carrying all four guns, fitting each as the catalogue allows. Run with `flatpak run org.godotengine.Godot --path . res://scenes/proto_attachment_look.tscn -- --seed=7 --class=large`; `--selftest` checks all 34 gun-and-Attachment pairs headless.
- Baked models in `assets/models/proto_attachments/`.

**Two kinds of model**

- Shared, one model each, built around the point where it meets a gun and placed at a mount point the gun gives: Reflex Sight, Combat Scope, Long Scope, Suppressor, Foregrip, Laser, Bipod. Seven.
- Per gun, one model for each gun the Attachment fits, built in that gun's space because it takes the place of that gun's own part: Long Barrel (Assault Rifle, Shotgun, Marksman Rifle), Short Barrel (Assault Rifle, Shotgun), Extended and Quick Magazine (Pistol, Assault Rifle, Marksman Rifle), Drum (Assault Rifle), Heavy and Light Stock (Assault Rifle, Shotgun, Marksman Rifle). Eighteen.
- An Attachment is still one thing with one set of changes; only its model may differ by gun.

**What each gun gives**

- Mount points: `MountSight` (top of the rail), `MountMuzzle` (the muzzle's tip, for the Suppressor; the Shotgun has none), `MountUnder` (the underside ahead of the trigger).
- Separate meshes an Attachment can hide: Pistol: magazine. Assault Rifle: barrel, sights, stock, cell. Shotgun: barrel with its magazine tube and heat shield, front sight, rear sight, stock. Marksman Rifle: barrel, sights, butt pad with cheek riser, magazine.
- The Pistol keeps its own sights under the Reflex Sight.
- The Marksman Rifle is a bullpup: its Stocks replace the butt pad and cheek riser, not a stock.

**What rides what**

- Magazines ride the magazine's bone, as in "How Attachments mount on a gun model".
- The Shotgun's Foregrip and Laser sit on the pump and move with it.
- The Pistol's Reflex Sight sits on the slide and moves with it.
- The Shotgun's Long and Short Barrel bring their own bead, and the aim point follows it when no Sight is fitted; its own front sight shows only with its own barrel and no Sight.

**Looks accepted as built**

- The Suppressor is one size on all three guns, large on the Pistol.
- Same-Slot pairs are told apart by shape and by brass: a Quick Magazine has a brass floor and a pull loop, a Heavy Stock a cheek riser and deep pad, a Light Stock is a bare plate on a strut.
- Scopes have dark glass caps here; the lens view is "What the scoped view looks like".

**For the build**

- Give each shared model its origin at its mount point. The prototype's joined meshes kept the origin of their first piece, so the prototype carries the whole file to the mount instead.
- A bone's mesh is named apart from the bone (`CellMesh`, `MagazineMesh`), which avoids Godot renaming the bone.

**Not settled here**

- The Laser's visible dot was not built; it stays on the map under "Not yet specified".
