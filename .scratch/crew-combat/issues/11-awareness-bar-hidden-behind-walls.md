Status: resolved

# Awareness bar hidden behind walls

## Parent

A build ticket riding along with `.scratch/crew-combat/map.md` at the user's request. It is not a decision ticket: build it with `/implement`. Vocabulary is `CONTEXT.md`'s.

## What to build

The Awareness bar over a crew member's head (`scripts/ui/awareness_markers.gd`) is drawn whenever the crew member is on screen within 22 m, or within 6 m behind the camera. Walls do not stop it, so the Pirate can see crew through the hull and through shut Doors.

Draw a crew member's bar only while there is a clear line from the Pirate's camera to that crew member's eye height (1.5 m), tested against the same world layer crew sight uses (hull, props, shut Doors). This applies to on-screen bars and to the bars pinned to the bottom edge for crew within 6 m behind the camera alike. The spotted sting is unchanged: it still rings whether or not the bar is drawn.

Update the "What the Pirate sees" section of `scripts/crew/CREW_AI.md` in the same commit.

## Acceptance criteria

- [x] (agent) A crew member with Awareness above zero, on screen 8 m away with a wall between it and the camera, has no bar drawn.
- [x] (agent) The same crew member at the same distance with nothing between has a bar drawn.
- [x] (agent) A crew member behind a shut Door has no bar; with the Door open and the line clear, it has one.
- [x] (agent) A crew member 4 m behind the camera has a bar pinned to the bottom edge with a clear line, and none with a wall between.
- [x] (agent) A crew member tipping into spotted behind a wall still rings the sting once.
- [x] (agent) `tests/run_all.sh` passes.
- [ ] (human) In a Raid, no bar shows through a wall or a shut Door, and bars on crew in view appear without a visible delay.

## Evidence

- Wall at 8 m, no bar: `tests/test_crew.gd::_check_bar_behind_walls`, case "on screen 8 m away through a wall". The Pirate stands in one pair Room at (104, 6.5) looking at a Guard 8 m off in the next Room at (112, 6.5), Awareness 0.5, with the wall column at x 108 between them. Asserts `AwarenessMarkers.mark_at` gives no bar (`Vector2.INF`).
- Nothing between at 8 m, a bar: `_check_bar_behind_walls`, case "on screen 8 m away in the open": the same Guard 8 m ahead in the single open Room. Asserts a bar is drawn, and that it sits over the head, not pinned to the bottom edge.
- Shut Door, then open: `_check_bar_behind_walls`, cases "behind a shut Door" and "through an open Door". The Pirate and the Guard are 8 m apart on the line through the pair Door's middle (z 4.0), with three physics frames after each `close()` and `open()`. Asserts no bar while the Door is shut, and a bar on screen once it is open.
- 4 m behind: `_check_bar_behind_walls`, case "4 m behind with a clear line": the Pirate faces away from the Guard 4 m behind him in the open Room. Asserts a bar is drawn, at y = screen height minus `BAR.y` (pinned to the bottom edge). Case "4 m behind through a wall" puts the Guard 4 m behind him in the next pair Room, past the wall, and asserts no bar.
- Sting behind a wall: `_check_bar_behind_walls`. The Guard behind the wall starts at Awareness 0, is shot, and tips to 1. Asserts the sting count rises by exactly 1 and that it still has no bar. The existing `_check_sting` and the smoke run's sting count (spotted stings equal crew that tipped into spotted, in every Raid) pass unchanged.
- Mutation: with the clear-line test switched off in `mark_at`, `only=crew` fails five of the new checks: wall, shut Door, behind through a wall, and both spotted-through-a-wall lines.
- Gate: `tests/run_all.sh` passed twice, 2026-11-25. Run 1: crew 257 checks, smoke 1104, total 252 s. Run 2 (seed 37447612): crew 257, smoke 1098, total 218 s. Every suite passed both times. Also passing: `tests/run_all.sh only=raid_smoke seeds=20` (seed 725940942, 4376 checks, 180 Raids, 0 failed, every floor met, 519 s) and `tests/run_all.sh only=crew` three more times (seeds 27751323, 317287341, 24914746, 257 checks each).
- Screenshots: `tests/shots.sh hud` passed. `.godot/shots/hud/hud.png` shows the HUD in the Boarding Pod: Loot line, health bar, ammo 5 / ∞, crosshair, Hatch prompt, all readable. `hud_busy.png` adds the Alarm banner, the XP toast and red 0 ammo, nothing overlapping. No crew are in view in this preset, so no bars appear. No preset frames an aware crew member, so the bars' look is owed to the playtest.

## Owed to playtest

- (human) In a Raid, no bar shows through a wall or a shut Door, and bars on crew in view appear without a visible delay.

## Comments

- `AwarenessMarkers.mark_at(crew, camera)` is new and public. It returns where a crew member's bar goes on screen, or `Vector2.INF` when it gets none. `_draw` calls it for each crew member, and so does the test. The line is one ray per marked crew member per frame, from `camera.global_position` to the crew member's position plus `Crew3D.EYE_HEIGHT`, on mask `Crew3D.WORLD_LAYER`. The cheap tests run before the ray (dead, unaware, beyond 22 m, more than 6 m behind), so only crew that could be marked cost a ray. Nothing is cached or smoothed, so a bar shows on the first frame the line clears.
- The ray starts at the camera, not at the Pirate's eye height, as the ticket says. Bodies are on layer 2, so neither the Pirate's capsule nor another crew member hides a bar. Only the hull, props, the Alarm panels and shut Doors (layer 1) do.
- Test housekeeping: the new check leaves the pair Door shut and the Pirate's yaw at 0. `_check_doorway` runs next, and if it found the Door open, its own `close()` would ring a Door noise into the crew member it listens with. That fails "a gunshot carried through a shut door". No existing check was changed.
