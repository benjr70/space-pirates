Type: prototype
Status: resolved
Blocked by: none
Map: ../map.md

# What aim time and swap time feel like on each gun

## Question

"How an Attachment changes a weapon" adds two attributes to every Weapon Profile: aim time (seconds to raise the sights) and swap time (today one 0.4 s on the Pirate). What are they for the bare Pistol, Assault Rifle, Shotgun and Marksman Rifle, and how does aim time behave? Build both with live dials and play: does the zoom, the tighter spread and the slower walk come in over the aim time or at its end; can he fire while the sights are still rising, and how does that shot group; does a Descope recover over the same time; does the swap time belong to the gun put away, the gun drawn, or half each? Find the range over which a change is felt, so Attachments have room to cost aim time and swap time without the bare guns feeling worse than they do today.

## Answer

Prototyped and played by the user on 2026-11-24: "I liked the default feel that you had here. I didn't change anything and it all felt good." So the prototype's starting values and settings stand. `CONTEXT.md`: Aim Down Sights and Weapon Wheel now say the sights and the swap take the weapon's own time.

**Prototype (primary source)**: local branch `prototype/aim-and-swap-time` (commit 1ffa840, never merged, not pushed). `scenes/proto_aim_swap_time.tscn` and `scripts/proto/proto_aim_swap_time.gd`. Run with `flatpak run org.godotengine.Godot --path . res://scenes/proto_aim_swap_time.tscn -- --seed=7 --class=large`; `F9` switches to today's feel for comparison; `--selftest` for a headless check.

**The bare guns**

| Gun | Aim time | Swap time |
|---|---|---|
| Pistol | 0.15 s | 0.30 s |
| Assault Rifle | 0.22 s | 0.40 s |
| Shotgun | 0.22 s | 0.45 s |
| Marksman Rifle | 0.32 s | 0.50 s |

Today every gun raises its sights at one speed, about 0.25 s, and swaps in 0.4 s.

**How aim time behaves**

- The gun and the zoom ease up and are all but there (95%) at the aim time. The prototype set the Viewmodel's pose speed and the camera's zoom speed to 3 divided by the aim time; today they are 10 and 14 a second for every gun.
- What aiming gives comes in with the rise: the tighter spread, the looser aimed-and-moving spread and the slower walk each blend from the hip value to the aimed value as the sights come up, in a straight line over the aim time.
- He may fire while the sights are still rising; the shot groups by how far up they are.
- The sights drop over the same time.
- After a Descope the sights come back over the full aim time, once the Descope's own recovery has passed.
- The mouse still slows the moment he aims; that was not part of this test.

**How swap time behaves**

- A swap takes the swap time of the gun being drawn.

**Not found**

- The range over which a change is felt. The user played only the starting values, so nothing here says how much aim time or swap time an Attachment can add before a gun feels bad, or how little goes unnoticed. "What each Attachment's starting numbers are" has to choose its factors without that, and the balance pass has to check them.
