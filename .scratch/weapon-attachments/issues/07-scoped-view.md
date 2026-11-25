Type: prototype
Status: resolved
Blocked by: 02
Map: ../map.md

# What the scoped view looks like

## Question

What does the Pirate see in Aim Down Sights through a magnified scope, and through an unmagnified Sight such as a red dot? Build the candidates the research on "How a magnified scope is drawn in Godot 4" finds workable on the Marksman Rifle and compare them in a Raid: how much of the screen the scope takes, what the reticle is, what is magnified and what is not, how the scope comes up and drops on a Descope, and how sway and mouse sensitivity feel at each zoom. Which one ships?

## Answer

Prototyped and played by the user on 2026-11-24. Five views were compared on the Marksman Rifle: its own sights, the whole view zooming behind a scope, a black overlay with the gun off screen, a picture-in-picture lens, and an unmagnified red dot.

**Prototype (primary source)**: local branch `prototype/scoped-view` (commits 4c89a58 and 7cb2486, never merged, not pushed). `scenes/proto_scoped_view.tscn` and `scripts/proto/proto_scoped_view.gd`; the lens, overlay and surround shaders are in the script. Run with `flatpak run org.godotengine.Godot --path . res://scenes/proto_scoped_view.tscn -- --seed=7 --class=large`; add `--selftest` for a headless check.

**What ships: the lens**

- A scope is picture-in-picture: only the lens magnifies; the gun stays on screen.
- The view around the lens zooms a little: 1.25x.
- Everything outside the lens goes out of focus as the sights come up, the gun and the scope's own ring included, and fades to black toward the edge of the screen. The user asked for this: "it doesn't make sense that it's clear because a person would be looking through the scope". It clears when the sights drop.
- The eye sits 0.06 m from the glass, so the lens fills most of the screen's height.
- The reticle is a cross. It sits on the shot line always; the gun and lens sway around it.
- The mouse slows by the lens's magnification.
- The user's settings, as printed by the prototype: `view: lens (picture-in-picture), magnification 4.0x, reticle cross, view around the lens 1.25x, blur 2.0, edge dark 1.0, eye to glass 0.06 m`.

**Both scopes**

- The Combat Scope and the Long Scope use this same view and these settings. Only the magnification differs: about 2.5x and about 5x; the exact values belong to "What each Attachment's starting numbers are". The user played it at 4x.

**Reflex Sight**

- As the prototype's red dot: an unmagnified window with a dot that stays on the shot line while the gun moves around it. No blur, no dark edge; the whole view zooms as with the gun's own sights.

**The guns' own sights**

- Unchanged: the whole view zooms. The Marksman Rifle bare has open sights at 3x, not a scope.

**Coming up, Descope, cost**

- The blur and dark edge fade in as the sights rise and drop on a Descope. No further scope-in effect.
- The lens view ran clean for the user: no stutter, shadow flicker or frame drop seen. Nothing was measured.

**What it asks of the build**

- Everything in the Viewmodel on its own render layer, left out of the lens camera, so the lens does not look down its own tube.
- A lens camera in a SubViewport that copies the Pirate's camera and renders only while aimed with a scope. The prototype used 1024 px square, covering 1.15 half-heights of screen so the picture never runs out when the gun sways.
- The lens samples that picture by where each pixel is on screen, not by the lens's own UVs, so the picture stays put and the lens moves over it like glass. The reticle is drawn the same way at the middle of the screen, visible only through the lens.
- The lens is a custom shader, which `Viewmodel._flag_materials` skips, so the shader sets the Viewmodel's field of view and depth scale itself. `_flag_materials` also hands every surface a duplicate material: read a lens's live material with `get_active_material`, not from its mesh.
- The surround is a full-screen layer under the HUD reading the screen's mipmaps for the blur, masked by where the lens is on screen, which is worked out with the Viewmodel's field of view, not the camera's.

**For the model in "How an Attachment changes a weapon"**

- A scope carries two magnifications: the lens's, which is the zoom the Sight's factor acts on and the one the mouse follows, and the view around it, fixed at 1.25x. So a Sight also says whether it is a lens. The spec has to carry that.
