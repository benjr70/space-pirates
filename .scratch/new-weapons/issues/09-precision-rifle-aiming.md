Type: prototype
Status: resolved
Blocked by: 06, 07
Map: ../map.md

# How the precision rifle aims

## Question

How does aiming the precision rifle look and feel? Prototype zoom level or levels, a scope overlay against sights on the Viewmodel, hip-fire spread, sway, movement speed while aimed and the Descope response, until the user picks one by playing it.

## Answer

Picked by playing: the Marksman Rifle aims over **sights on the Viewmodel at 3x zoom**, with a little sway.

- **Sights, not a scope.** No scope overlay for now. Scopes arrive later with weapon attachments and modifications, which is a separate effort.
- **Zoom.** 3x in Aim Down Sights.
- **Sway.** 0.25 degrees while aimed: a slow figure of eight.
- **Mouse.** Slowed by the zoom while aimed, so a hand movement covers the same distance on screen.
- **Hip cone.** 3 degrees.
- **Aimed.** Pinpoint when still or crouched; a 1.2 degree cone when walking.
- **Speed while aimed.** 0.6 of walking speed.
- **Descope.** Unchanged: the same rule as every gun, as decided in [What the precision rifle is](06-precision-rifle-identity.md).

These are starting numbers for the balance pass. The prototype also ran 8 rounds, 0.4 s between shots and a 200 m/s bolt reaching 80 m, which were not objected to.

For the build, found while prototyping:

- The Weapon Profile multiplies spread (base, times movement, times aimed). Fixed numbers in that shape cannot give a 3 degree hip cone, a pinpoint aimed-and-still cone and a 1.2 degree aimed-and-walking cone together. The Profile needs an aimed-and-moving spread of its own.
- Sway and slowing the mouse by the zoom are new behaviour for Aim Down Sights. Sway is a Profile field (0 for the other guns); mouse slowing applies to every gun by its zoom.

**Prototype.** Branch `prototype/marksman-aim` (local, never merged), commit 4154377: `scenes/proto_marksman_aim.tscn` and `scripts/proto/proto_marksman_aim.gd`. Run it from that branch with `flatpak run org.godotengine.Godot --path . res://scenes/proto_marksman_aim.tscn -- --seed=7 --class=large`.
