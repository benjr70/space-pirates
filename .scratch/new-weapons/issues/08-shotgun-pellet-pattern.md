Type: prototype
Status: resolved
Blocked by: 05, 07
Map: ../map.md

# How the Shotgun's pellets fly

## Question

How does one Shotgun shot behave and feel in a Raid? Prototype pellet count, a fixed pattern against a random scatter, per-pellet damage, pellet speed and lifetime, and how spread, bloom and Aim Down Sights apply to a pattern, until the user picks one by playing it.

## Answer

Picked by playing: a **random scatter of 12 pellets**, at the prototype's starting numbers.

- **Pattern.** 12 pellets, each thrown at random inside the cone, evenly over its area. No fixed shape.
- **Damage.** 13 per pellet against crew Health 100, so 8 of 12 pellets kill and a full shot does 156.
- **Cone.** 5 degrees half-angle. No bloom. No change for crouching, standing or walking; 1.3x in the air.
- **Reach.** 15 m: pellets fly at 60 m/s for 0.25 s and then die.
- **Pump.** 0.8 s between shots.
- **Aim Down Sights.** Tightens the cone to 0.8 and zooms 1.15x.
- **Slide.** No widening, as decided in [What the Shotgun is for](05-shotgun-role.md).
- **Damage falloff.** Still none. Spread and reach alone gave the range band, so [What the damage model needs](07-damage-model.md) stands.

These are starting numbers for the balance pass, not final ones.

For the build, found while prototyping: each pellet reports its own hit, and a pellet that strikes a crew member already killed by an earlier pellet of the same shot reports a kill again. One shot must give one hit marker per crew member and count one kill, or XP is paid several times.

Not covered here: the shell-by-shell reload (the prototype used a magazine reload) and how the crosshair shows the pattern.

**Prototype.** Branch `prototype/shotgun-pellets` (local, never merged), commit 9517be3: `scenes/proto_shotgun_pellets.tscn` and `scripts/proto/proto_shotgun_pellets.gd`. Run it from that branch with `flatpak run org.godotengine.Godot --path . res://scenes/proto_shotgun_pellets.tscn -- --seed=7 --class=medium`.
