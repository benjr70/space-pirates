Type: prototype
Status: resolved
Blocked by: none
Map: ../map.md

# How the Shotgun's shell-by-shell reload plays

## Question

How does loading the Shotgun one shell at a time play in a Raid? Prototype the timings (the first shell, each shell after, the closing pump when it was empty), how a shot, a Melee or a swap breaks in and how soon the gun then fires, whether a held or a tapped reload fills it, and what the Viewmodel and the ammo counter do while it runs, until the user picks by playing. It was decided in [What the Shotgun is for](05-shotgun-role.md) that an interrupted reload keeps the shells already loaded.

## Answer

Picked by playing: the prototype's starting values, unchanged.

- **Reload key.** One tap fills the gun: it keeps loading shells until full or broken off. No holding, no tap per shell.
- **Times.** First shell 0.55 s; each shell after 0.45 s; a closing pump of 0.45 s when loading began from empty. Empty to full is 3.25 s.
- **When a shell counts.** When its time is up. The ammo counter rises by one then, and the shell sound plays then.
- **Breaking off.** A shot, a Melee or a weapon swap breaks the reload and keeps the shells already in. The shell being loaded at that moment is lost. A shot can break in only with at least one shell in the gun.
- **Break-out.** After a shot breaks the reload the gun fires 0.25 s later, by itself: the press that broke the reload is the press that fires.
- **Closing pump.** Cannot be broken by a shot.
- **Dry pull.** Starts the reload, as on the other guns.
- **Sprint.** Does not break the reload; the Pirate can load while sprinting.
- **Pump after a shot.** The pump sound follows each shot by 0.2 s.

These are starting numbers for the balance pass. New Weapon Profile fields this implies: a shell-by-shell reload switch, first-shell time, per-shell time, closing-pump time and break-out time.

The Viewmodel in the prototype only rolled the gun over and nudged it per shell. The real clips (a shell going in, the closing pump) are owed by the build, as noted in [What the Shotgun looks like](10-shotgun-look.md).

**Prototype.** Branch `prototype/shell-reload` (local, never merged), commit 705af6c: `scenes/proto_shell_reload.tscn`, `scripts/proto/proto_shell_reload.gd` and the three picked sounds it plays. Run it from that branch with `flatpak run org.godotengine.Godot --path . res://scenes/proto_shell_reload.tscn -- --seed=7 --class=medium`.
