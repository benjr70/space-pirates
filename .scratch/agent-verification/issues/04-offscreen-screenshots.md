Status: resolved
Blocked by: none

# Offscreen screenshots

## Parent

`.scratch/agent-verification/spec.md`, build order 4 of 9.

## What to build

A way for an agent to render the game without a display and look at the result.

Proven on 2026-11-22: wrapping the windowed Godot run in `gamescope --backend headless` renders on the GPU with no window, and `tests/viewmodel_shots.gd` saved correct PNGs (see the spec's "Verified" section for the exact command and its two quirks).

- **`tests/shots.sh <preset> [args]`**: wraps the gamescope command, creates the output directory, runs the shot script, and exits non-zero if any expected PNG is missing or empty. Ignore gamescope's own exit status (it dumps core on shutdown after the child has finished); judge by Godot's output and the files. Default output is `.godot/shots/<preset>/`, which git ignores.
- **`tests/shots.gd`**: one script with presets, built on what `viewmodel_shots.gd` already does. Keep that file's pose arguments working, as the `viewmodel` preset.
  - `viewmodel`: hip, ADS, sprint-low and tracer, per weapon (`wheel=<n>`).
  - `ship class=<Ship Class> seed=<n>`: the generated ship built in 3D; one shot from inside each Room at eye height, plus one top-down overview.
  - `crew`: one of each crew type, front and side.
  - `hud`: the in-Raid HUD with known values (ammo, health, Loot).
  - `menu`: the main menu and each screen reachable from it.
  - `scene path=<res://…> cam=x,y,z look=x,y,z`: any scene from a given camera, for whatever a ticket adds.
- **Defect checklist** in `docs/agents/paperclip.md`: what an agent must confirm in each shot and may report as a failure. Missing or invisible mesh; magenta or untextured surface; object floating, sunk or facing the wrong way; geometry clipping the camera; HUD or menu element cut off, overlapping or unreadable; a Room with no light; anything the ticket says should be visible that is not. Anything beyond the list (whether it looks good) stays `(human)`.
- **Cheap automatic checks** in `shots.gd` before saving: the frame is not a single flat colour, and the share of pure magenta pixels is under a small threshold. These catch a black or broken frame without anyone reading it.
- **Rewrite the "Running it" section** of `docs/agents/paperclip.md`: it currently says there is no display and all look is `(human)`.

Open point to settle while building: confirm the Dev Factory's agent environment can run gamescope with GPU access, and whether two offscreen runs at once work. If the factory cannot, record that in `paperclip.md` and keep shots as a local-session tool.

## Acceptance criteria

- [x] (agent) `tests/shots.sh viewmodel` produces four non-empty PNGs with no window opened and exits 0.
- [x] (agent) Each of the six presets produces its PNGs; the agent reads at least one from each and records what it shows.
- [x] (agent) `tests/shots.sh ship class=<a Ship Class> seed=1` saves one shot per Room; the count matches the Room count the generator reports for that seed.
- [x] (agent) A run with a deliberately missing output mesh fails the flat-colour or magenta check, or is caught by the defect checklist, shown in the evidence.
- [x] (agent) `docs/agents/paperclip.md` documents the command, the presets, the defect checklist, and what remains `(human)`.
- [x] (agent) Whether the factory environment and parallel runs work is recorded in `paperclip.md`, either way.
- [ ] (human) The shots are framed usefully: a person looking at them can tell what the agent was meant to check.

## Evidence

Built 2026-11-22: `tests/shots.sh`, `tests/shots.gd`; `tests/viewmodel_shots.gd` folded into the `viewmodel` preset and deleted. All runs at the default 1280x720; PNGs under `.godot/shots/<preset>/`.

- **viewmodel, four PNGs, no window, exit 0.** `tests/shots.sh viewmodel` → `SHOT_SAVED hip.png / ads.png / low.png / tracer.png`, `SHOTS_DONE ok`, `shots: PASS viewmodel, 4 frames in 3s`, exit 0 (gamescope `--backend headless`; nothing appeared on the desktop). Sizes 98-136 KB. `hip.png`: Sidearm low right, two Guards behind the crate, test room lit. `ads.png` (run with `wheel=1`): Carbine sights centred, front post in the rear ring. `low.png`: weapon dropped out of frame bottom right (sprint-low). `tracer.png`: a pale orange bolt streaking toward the back wall past the right Guard. `tests/shots.gd` also passes `--headless --check-only` (exit 0) and under plain `--headless` prints `shots: needs a renderer` and exits 1 instead of doing window work.
- **All six presets produce their PNGs; one or more read from each.** Final run, each exit 0: viewmodel 4 frames 3 s; `ship class=small seed=1` 7 frames 4 s; crew 2 frames 2 s; hud 2 frames 4 s; menu 5 frames 5 s; `scene path=res://scenes/props3d/prop_crate_3d.tscn cam=2,1.5,2 look=0,0.5,0` 1 frame 2 s.
  - ship `room_03_quarters.png`: lockers, crates, a green container and a Guard at left, ceiling lit by the Room light; `room_01_corridor.png`: long Corridor with crates along the wall; `room_05_engine.png`: red engine floor, crew member and crates at the far end; `overview.png`: whole small ship from above, Bridge at the top, Corridor down the left, Cargo/Quarters/Cargo stacked right, Engine at the bottom, Boarding Pod docked on the right flank.
  - crew `front.png`: Guard (dark armour) left, Worker (orange engineer suit, helmet) right, both facing camera; `side.png`: both turned side-on, Worker's back tank visible.
  - hud `hud.png`: ship name top left, Loot 240 gold and 4 of 6 health pips bottom left, `5 / ∞` bottom right, crosshair centred, Sidearm, game's own `E — Open hatch` prompt; `hud_busy.png`: adds `ALARM RAISED` top centre, `+150 XP unaware` toast, `0 / ∞` in red. Nothing cut off or overlapping.
  - menu `home.png`: title, tagline, profile line and XP bar, Play/Exit over the drifting ship and planet; `classes.png`: CHOOSE A TARGET with Small/Medium/Large Ship and Back; `pause.png`: PAUSED with Resume/Main Menu over a darkened Raid; `death.png`: red wash, YOU DIED, detail, Retry/Exit to Main Menu, HUD hidden; `extracted.png`: green wash, EXTRACTED, New Raid/Exit to Main Menu.
  - scene `prop_console_3d.png` (cam=1.8,1.6,2.2 look=0,0.6,0): the console prop, a pale blue placeholder box, lit on a dark background.
- **One shot per Room, count matches.** `tests/shots.sh ship class=small seed=1` → `shots: small seed 1, "CSS Merry Anvil": rooms=6 counted=5`, then `SHOT_EXPECT room_00_bridge … room_05_engine` and `overview.png`, all saved, PASS. Six Room shots for the six Rooms in the generated layout; the generator's `counted_rooms` of 5 is the Class count, which leaves out the one Corridor (`room_01_corridor.png`). Also `ship class=medium seed=1` → `rooms=9 counted=8`, 9 Room shots + overview, PASS.
- **A deliberately missing mesh fails.** A throwaway scene (in git-ignored `.godot/shots_test/`, deleted after) whose MeshInstance3D points at a non-existent `res://assets/models/does_not_exist.res`: `tests/shots.sh scene path=res://.godot/shots_test/missing_mesh.tscn cam=1.8,1.6,2.2 look=0,0.5,0 out=res://.godot/shots_test/out` → `SHOT_FAIL missing_mesh.png: flat colour 19191f, nothing drawn`, `SHOTS_DONE fail`, exit 1. A second throwaway scene with a pure-magenta unshaded box → `SHOT_FAIL magenta.png: 11.4% magenta, a missing texture or material`, exit 1; the saved PNG shows the magenta cube. A GDScript error mid-preset (seen while building: a wrong node path) is also caught: the shell fails on `SCRIPT ERROR` and on the missing frames.
- **paperclip.md documents it.** "Running it" now opens with screenshots being the agent's way to check the look, and a `### Screenshots` subsection gives the command, each preset's args and outputs, the automatic checks, the defect checklist (the seven items from this ticket), and the `(human)` paragraph rewritten to "whether the game looks good beyond the defect checklist", sound, feel, editor and play sessions.
- **Factory and parallel runs recorded.** Two presets at once (`ship class=medium seed=1` and `viewmodel wheel=1` in background subshells): both PASS, exit 0, 4 s wall time, outputs correct (`room_02_armory.png`, Carbine `ads.png` read). paperclip.md records this as verified in a local session only (gamescope 3.17, RTX 5080) and the Dev Factory environment as unconfirmed, with shots then a local-session tool.

## Owed to playtest

- (human) The shots are framed usefully: a person looking at them can tell what the agent was meant to check.

## Comments

2026-11-22: built by a subagent. The orchestrating session re-ran the `hud` and `ship class=small seed=1` presets (both PASS, exit 0) and read `hud_busy.png`, `room_05_engine.png` and `overview.png`; they show what the evidence says. Findings about the game itself, not fixed here: floor and ceiling surfaces in generated Rooms show placeholder grid lettering ("WALL 1024x1024"), and walls in the Engine Room render near-black.
