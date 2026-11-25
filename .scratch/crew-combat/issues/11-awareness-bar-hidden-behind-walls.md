Status: ready-for-agent

# Awareness bar hidden behind walls

## Parent

A build ticket riding along with `.scratch/crew-combat/map.md` at the user's request. It is not a decision ticket: build it with `/implement`. Vocabulary is `CONTEXT.md`'s.

## What to build

The Awareness bar over a crew member's head (`scripts/ui/awareness_markers.gd`) is drawn whenever the crew member is on screen within 22 m, or within 6 m behind the camera. Walls do not stop it, so the Pirate can see crew through the hull and through shut Doors.

Draw a crew member's bar only while there is a clear line from the Pirate's camera to that crew member's eye height (1.5 m), tested against the same world layer crew sight uses (hull, props, shut Doors). This applies to on-screen bars and to the bars pinned to the bottom edge for crew within 6 m behind the camera alike. The spotted sting is unchanged: it still rings whether or not the bar is drawn.

Update the "What the Pirate sees" section of `scripts/crew/CREW_AI.md` in the same commit.

## Acceptance criteria

- [ ] (agent) A crew member with Awareness above zero, on screen 8 m away with a wall between it and the camera, has no bar drawn.
- [ ] (agent) The same crew member at the same distance with nothing between has a bar drawn.
- [ ] (agent) A crew member behind a shut Door has no bar; with the Door open and the line clear, it has one.
- [ ] (agent) A crew member 4 m behind the camera has a bar pinned to the bottom edge with a clear line, and none with a wall between.
- [ ] (agent) A crew member tipping into spotted behind a wall still rings the sting once.
- [ ] (agent) `tests/run_all.sh` passes.
- [ ] (human) In a Raid, no bar shows through a wall or a shut Door, and bars on crew in view appear without a visible delay.

## Comments
