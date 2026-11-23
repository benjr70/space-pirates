Status: resolved

# Spec: agents can verify what they build

Plan written 2026-11-22. This document is the build-order view; each ticket under `issues/` carries its slice in full.

## Problem Statement

Agents build features from tickets and are expected to prove the result is correct and matches the spec. Today they can only partly do that:

- **They cannot see the game.** `docs/agents/paperclip.md` says there is no display, so everything about how the game looks is `(human)`. A missing mesh, a magenta material or a HUD drawn off-screen passes the gate.
- **"Matches the spec" is not checkable.** Tickets carry prose and sometimes a checklist, but nothing says which check proves which criterion, so a reviewer cannot tell a covered criterion from a forgotten one.
- **The gate can pass on broken code.** A script or scene that no suite loads is never parsed. A suite that hits a script error mid-function can still exit 0. `tests/run_all.sh` reports a missing suite as `skipped`, which reads like a pass.
- **Nothing exercises a whole Raid.** Suites test pieces; no run boards a ship, loots, gets noticed and extracts.
- **Failures are not reproducible on demand.** 18 scripts draw random numbers, and a failing check does not print what seed would replay it.
- **Glossary use is unenforced.** `CONTEXT.md` terms are meant to appear verbatim in code, and nothing checks.

## Solution

Four layers, each one command an agent can run from a worktree, each documented in `docs/agents/paperclip.md`:

1. **Static**: every script, scene and resource loads cleanly.
2. **Behaviour**: the existing suites, made strict (any engine error fails, a missing suite fails) and reproducible (seeded, seed printed on failure), plus a whole-Raid smoke run.
3. **Visual**: screenshots rendered offscreen that the agent reads back and checks against a fixed list of objective defects.
4. **Spec**: every ticket has an `## Acceptance criteria` list where each line is tagged `(agent)` or `(human)`, and the finished ticket records the evidence for every `(agent)` line.

What stays `(human)` after all of this: how the game feels, sounds and paces, and whether art is good rather than merely present.

## Verified on 2026-11-22

Two spikes were run on this machine before writing the tickets:

- **Offscreen rendering works.** `gamescope --backend headless -W 960 -H 540 -- flatpak run org.godotengine.Godot --path . --resolution 960x540 --script res://tests/viewmodel_shots.gd -- out=res://.godot/shots_spike` rendered on the real GPU (Vulkan, Forward+) with no window and saved four PNGs showing the Viewmodel, two crew and the room correctly lit. The output directory must exist first: the script does not create it and `save_png` fails without it. gamescope dumps core on shutdown after the child exits; the PNGs are complete by then.
- **Parse errors are detectable.** `--headless --check-only --script <file>` exits 1 with `SCRIPT ERROR: Parse Error` on a broken script and 0 on a good one.

Not verified: whether the Dev Factory's agent environment has gamescope and GPU access (the spikes ran in a local session), whether two offscreen runs can share the GPU at once, and how long the full gate takes.

## Build order

| # | Ticket | Layer | Blocked by |
| - | ------ | ----- | ---------- |
| 01 | Static load check | Static | none |
| 02 | Strict runner | Behaviour | none |
| 03 | Acceptance criteria and evidence format | Spec | none |
| 04 | Offscreen screenshots | Visual | none |
| 05 | Reproducible runs | Behaviour | 02 |
| 06 | Whole-Raid smoke run | Behaviour | 02, 05 |
| 07 | Glossary check | Static | none |
| 08 | Fast loop: which suite covers which code | Behaviour | 02 |
| 09 | Decide whether agents may run Blender | Visual | none (human) |

01–04 are independent and give most of the value; they can be built in parallel. 09 is a decision for the maintainer, not a build.

## Out of scope

- Judging feel, sound or difficulty automatically.
- Pixel-diff golden images. Screenshots are read by the agent, not compared to a stored baseline: the art is still changing and baselines would churn.
- CI on GitHub. The gate runs in the worktree; hosting it elsewhere is a later question.

2026-11-22: the validation docs these tickets wrote into `docs/agents/paperclip.md` were moved to `docs/agents/validation.md` at the maintainer's request; `paperclip.md` keeps only the gate command and a pointer. Ticket evidence that cites `paperclip.md` sections refers to that file.

2026-11-22: all tickets built and resolved except 07 (glossary check), which waits on the maintainer's answer to the proposed `_Avoid_:` list in its Comments. Game bugs the smoke run found are tracked and resolved under `.scratch/raid-smoke-bugs/`, bar one design question (08).
