# Paperclip factory contract

What the Dev Factory agents need to know to build, check and run this
repository. The Developer, Code Reviewer and QA Engineer read this file before
anything else; keep it exact.

## Base

Base branch: `main`

## Setup

Run once in a fresh worktree, from the repository root. It builds the `.godot/`
import cache (not tracked by git) that every headless run needs. Safe to repeat.

```sh
flatpak run org.godotengine.Godot --headless --import --path .
```

## Gate

Must pass before a pull request is opened, from the repository root:

```sh
tests/run_all.sh
```

Only the full run, with no `only=` and no `seeds=`, is the gate. How the gate
works, the faster loop to use while building, replaying a failure, the
screenshot tool, and the evidence each ticket needs are all in
`docs/agents/validation.md`; read it before building or reviewing.

## Running it

There is no display for agents. Logic is exercised headless and the look of
the game is checked from offscreen screenshots; see
`docs/agents/validation.md` for the tools and for what stays `(human)`.

## Notes

- Godot is the system flatpak `org.godotengine.Godot` (4.7); there is no bare
  `godot` binary.
- Blender is the system flatpak `org.blender.Blender`, and agents have full use
  of it (decided 2026-11-22): run and edit the scripts under `tools/blender`,
  edit `.blend` files, and build new models. Run a script headless with
  absolute paths:
  `flatpak run --filesystem=$PWD org.blender.Blender -b --python "$PWD/<script>.py"`.
  Check every export with `tests/shots.sh` (see `docs/agents/validation.md`);
  whether a model looks good stays a `(human)` criterion on its ticket. Where
  the environment has no Blender, block the task instead.
- `CONTEXT.md` is the glossary; names in code use its terms verbatim.
- Tickets live under `.scratch/` (see `docs/agents/issue-tracker.md`). GitHub
  issues are not used; pull requests are.
