Type: prototype
Status: resolved
Blocked by: 01, 03
Map: ../map.md

# What the master weapon sheet is

## Question

What form does the master weapon sheet take? Where do the numbers live (one file for all weapons, or one file per weapon with a generated view), how are they seen side by side, how are they edited, and how quickly does a change reach a running Raid? Build rough candidates to react to, covering every Weapon Profile attribute and the crew numbers.

## Answer

The master weapon sheet is two things over the same numbers: an **in-Raid sheet** for dialling and a **generated Markdown view** as the record. A hot-reloaded CSV was prototyped and dropped.

**In-Raid sheet.** F1 during a Raid pauses it and opens a table: weapons as columns, attributes as rows, with Gunnery (one column per crew type) and Health (Pirate, crew) as their own tables. A change applies live; closing the sheet resumes the Raid with it. Changed cells are marked against what is on disk, and Save writes to disk. It is a dev tool: debug builds only, stripped from an export.

**Where the numbers live.**

- Weapons: one `.tres` per weapon under `resources/weapons/`, as today. There is no single master data file.
- Gunnery: a new Gunnery resource, one `.tres` per crew type (`resources/gunnery/guard.tres`, `worker.tres`).
- Health: one small Sandbox resource holding Pirate and crew Health, read by both scenes at spawn, so Save never writes into a scene.

**Generated view.** `docs/sandbox.md`, committed. Rewritten on every Save from the in-Raid sheet, and checked by the test suite, which fails when the file is stale against the resources, so an Inspector edit cannot drift it. Its git diff is the balance history.

**Derived rows.** Shown in both, read-only: reach, shots to kill crew, seconds to kill crew, shots per second. More are added as mechanics land (pellets, falloff, headshots).

**Text fields.** Model, poses and clip names stay Inspector-only: read-only in the sheet, listed in the Markdown view.

**Prototype.** Branch `prototype/sandbox-sheet` (local, never merged), commit f66bd99: `scenes/proto_sandbox_sheet.tscn` and `scripts/proto/proto_sandbox_sheet.gd`. Run it from that branch with `flatpak run org.godotengine.Godot --path . res://scenes/proto_sandbox_sheet.tscn -- --seed=7 --class=medium`. It is rough: Gunnery there drives today's `crew.gd` exports and flattens spawn jitter, and Gunnery and Health are not saved.

Not tried: the "Edit Resources as Table" editor addon, whose Godot 4.7 fix was unreleased at the time (see [What Godot offers for editing many Resources as one table](01-godot-table-tooling.md)).
