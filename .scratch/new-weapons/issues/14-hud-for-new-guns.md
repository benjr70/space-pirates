Type: prototype
Status: resolved
Blocked by: none
Map: ../map.md

# How the HUD shows the new guns

## Question

What does the HUD show for the new mechanics? Prototype in a Raid: the crosshair for the Shotgun's 5 degree pellet cone against the four-line crosshair that opens with spread today; the Headshot hit marker beside the body-hit and kill markers; and the Pirate's 150 Health where six pips stood.

## Answer

Picked by playing, from four takes of each.

- **Shotgun crosshair.** Today's four lines, unchanged, for every gun. They open 6 px per degree of spread, so at the Shotgun's 5 degrees they sit 35 px out, inside where the pellets really go. A ring and arcs drawn at the true pellet cone were tried and not wanted. No new crosshair work.
- **Headshot marker.** The same X as a body hit, in gold (1.0, 0.8, 0.25). A body hit stays white and a kill stays red; a Headshot that kills is red.
- **Health.** One bar for the Pirate's 150 Health, split into six segments of 25 by dividers, filling continuously so 13 damage shows. It replaces the six pips. In the prototype it was 180 px wide and 10 px tall, where the pips were, in the pips' green.

**Prototype.** Branch `prototype/hud-new-guns` (local, never merged), commit c88f8b6: `scenes/proto_hud_new_guns.tscn` and `scripts/proto/proto_hud_new_guns.gd`. Run it from that branch with `flatpak run org.godotengine.Godot --path . res://scenes/proto_hud_new_guns.tscn -- --seed=7 --class=medium`.
