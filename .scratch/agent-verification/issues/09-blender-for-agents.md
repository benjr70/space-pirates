Status: resolved
Blocked by: none

# Decide whether agents may run Blender

## Parent

`.scratch/agent-verification/spec.md`, build order 9 of 9. A decision for the maintainer, not a build.

## Question

`docs/agents/paperclip.md` says Blender is not available to agents: they must never regenerate assets under `tools/blender` and must block any ticket that needs new art. Blender 5.3 is installed on this machine as a flatpak, and earlier local sessions have scripted it headless (the Worker engineer models were built that way).

Should factory agents be allowed to run the existing export scripts in `tools/blender`?

- **Keep the ban**: art stays a human step. Tickets needing a model block, as now.
- **Allow re-export only**: agents may run existing scripts unchanged to regenerate an asset, and must verify the result with the screenshot tool (ticket 04). No new modelling.
- **Allow scripted modelling**: agents may write Blender scripts for new assets. Result quality is a `(human)` criterion on every such ticket.

Things that bear on it: whether the factory environment has Blender at all, that regenerated `.glb` files are binary diffs a reviewer cannot read, and that ticket 04 is what would let an agent check its own export.

## Acceptance criteria

- [x] (human) Decision recorded here under `## Answer`.
- [x] (agent) `docs/agents/paperclip.md` Notes section updated to match the decision.

## Answer

Decided by the maintainer on 2026-11-22: agents have full access to Blender. They may run the export scripts, edit Blender files and scripts, and build new models. Not one of the three options as written; it goes further than "scripted modelling" by including edits to existing `.blend` files.

## Evidence

- Notes updated: `docs/agents/paperclip.md`, Notes, the Blender bullet now grants full use, gives the headless command and requires a `tests/shots.sh` check of every export.

## Comments

2026-11-22: whether the Dev Factory environment has Blender is not confirmed; the note tells an agent to block the task where it does not.
