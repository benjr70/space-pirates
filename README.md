# Space Pirate

A 2D top-down space game built with [Godot 4.7](https://godotengine.org).

## Running

Open the project folder in Godot, or from a terminal:

```sh
godot --path .            # native install
flatpak run org.godotengine.Godot --path .   # flatpak install
```

Press F5 in the editor to play `scenes/main.tscn`.

## Controls

| Action | Keys |
| --- | --- |
| Move | `W` `A` `S` `D` (arrow keys also work) |

## Layout

```
assets/sprites/   art (SVGs, imported by Godot)
scenes/           main.tscn (the world), player.tscn (the spaceman)
scripts/          GDScript, one file per scene
```
