Status: resolved

# Checks for the ship dump tools

## Parent

`.scratch/agent-verification/spec.md`, follow-up from `08-fast-loop.md` (an area with no suite in the coverage table of `docs/agents/paperclip.md`).

## What to build

`scripts/gen/ship_dumper.gd` (`ShipDumper`) turns a `ShipLayout` into an ASCII plan (`ascii`) and a text listing (`listing`); `scripts/gen/dump_ship.gd` is the command-line wrapper that prints any seed's plan and sentence. They are debugging aids: `tests/test_generator.gd` calls `ShipDumper` only to print the first failing seed, and asserts nothing about what it prints. Only the static load check touches `dump_ship.gd`.

A broken dumper costs a confusing failure report, not a broken game, so a few cheap checks are enough. Add them to `tests/test_generator.gd` (it already generates the layouts):

- `ShipDumper.ascii` of one seed per Ship Class draws no `?` (its glyph for an unknown prop or Role) and only glyphs from `PROP_GLYPH`, `ROLE_GLYPH` or the documented wall/floor/doorway/Hatch/crew set.
- `ShipDumper.listing` has one `room` line per Room and one `door` line per Door.

## Acceptance criteria

- [x] (agent) For one seed of each Ship Class, `ShipDumper.ascii` contains no `?` and only glyphs from `PROP_GLYPH`, `ROLE_GLYPH`, `#`, `.`, `+`, `H`, `x`, space and newline; asserted in `tests/test_generator.gd`.
- [x] (agent) For the same seeds, `ShipDumper.listing` has exactly as many `room` lines as the layout has Rooms and `door` lines as it has Doors; asserted in `tests/test_generator.gd`.
- [x] (agent) `flatpak run org.godotengine.Godot --headless --path . --script res://scripts/gen/dump_ship.gd -- small 1` exits 0 and prints a plan; recorded as a command in the evidence (not a gate suite).

## Evidence

- Glyph set: `tests/test_generator.gd::_check_dumper`, run from `_initialize` on seed 1 (`FIRST_SEED`) of each Ship Class (small, medium, large). It asserts the `ShipDumper.ascii` plan contains no `?` and that every character is in `PROP_GLYPH` values, `ROLE_GLYPH` values, `#`, `.`, `+`, `H`, `x`, space or newline. Failures read `ShipDumper on <class> seed <n>: ...  [sentence]`. `tests/run_all.sh only=generator` went from `PASS (341833 checks, 41 s)` to `PASS (341845 checks, 42 s)`, 4 new checks per Class. Shown to fail with a temporary edit to `scripts/gen/ship_dumper.gd`, reverted afterwards (`git diff --stat` on the file is empty). Run with `tests/run_all.sh only=generator seeds=1`:
  - `&"crate"` removed from `PROP_GLYPH`: `FAIL  ShipDumper on small seed 1: ascii plan draws '?' for an unknown prop or role:` and `FAIL  ShipDumper on small seed 1: ascii plan draws glyphs outside its set: ["?"]`, the same for medium and large.
  - Hatch glyph `"H"` changed to `"h"`: `FAIL  ShipDumper on medium seed 1: ascii plan draws glyphs outside its set: ["h"]`, the same for small and large.
- Listing counts: the same check, on the same seeds, counts the `ShipDumper.listing` lines that start `room ` and `door `, and asserts they equal `layout.rooms.size()` and `layout.doors.size()`. Shown to fail with temporary, reverted edits: with the last Door's line dropped it printed `FAIL  ShipDumper on large seed 1: listing has 15 door lines for 16 doors`, and with Room 0's line dropped `FAIL  ShipDumper on small seed 1: listing has 5 room lines for 6 rooms`, the same for every Class.
- Command: `flatpak run org.godotengine.Godot --headless --path . --script res://scripts/gen/dump_ship.gd -- small 1` gave `exit=0`. It printed the summary `=== seed 1  class small  "CSS Merry Anvil"  |  6 rooms (5 counted), 5 doors, 1168 floor tiles, 25x71 m`, then the sentence, then a 27-line ASCII plan (Role letters B, C, c, q, c, E; `H` Hatches, `+` doorways, `x` crew, `=`, `P`, `$`, `L` props), then 6 `room` lines and 5 `door` lines.

## Comments

2026-11-22: built by a subagent (test code only). The orchestrating session re-ran `tests/run_all.sh only=generator,ship_3d` (both PASS) and confirmed no game script changed.
