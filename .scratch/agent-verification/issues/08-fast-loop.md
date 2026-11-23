Status: resolved
Blocked by: 02

# Fast loop: which suite covers which code

## Parent

`.scratch/agent-verification/spec.md`, build order 8 of 9.

## What to build

An agent mid-task should know which suite to run for the files it touched, and how long each takes, instead of choosing between guessing and running the whole gate.

- **Measure.** Time each suite and the full gate on this machine; record the numbers in `docs/agents/paperclip.md`.
- **Coverage table** in `docs/agents/paperclip.md`: code area to suite. Starting point, to be checked against what each suite actually loads:
  - `scripts/gen/`, `scripts/data/` → `tests/test_generator.gd`, `tests/test_layouts.gd`
  - `scripts/ship/`, 3D scenes → `tests/test_ship_3d.gd`
  - `scripts/player_3d.gd`, weapons, Viewmodel → `tests/test_pirate.gd`
  - `scripts/crew/` → `tests/test_crew.gd`
  - `scripts/raid.gd`, `scripts/ui/` → `tests/test_ship_3d.gd` (it runs `RaidChecks`)
- **`tests/run_all.sh only=<suite>[,<suite>]`** runs the named suites with the same strictness and summary as the full run, so the fast loop and the gate report the same way.
- **Areas with no suite** are listed as such in the table. Each becomes a follow-up ticket, not work for this one.
- Restate in the contract that only the full `tests/run_all.sh` is the gate.

## Acceptance criteria

- [x] (agent) Per-suite and full-gate timings are in `docs/agents/paperclip.md`.
- [x] (agent) Every directory under `scripts/` except `scripts/proto/` appears in the coverage table, mapped to a suite or marked uncovered.
- [x] (agent) `tests/run_all.sh only=<suite>` runs just that suite and prints the usual summary.
- [x] (agent) A follow-up ticket file exists for each uncovered area.

## Evidence

- Timings: `docs/agents/paperclip.md`, "Fast loop" timings table: each suite's checks and wall time and the full gate (325 s), from the full `tests/run_all.sh` run on 2026-11-22. The runner now prints each suite's wall time in its summary line and `total: <n> s` at the end, so the numbers are reproducible.
- Coverage table: `docs/agents/paperclip.md`, "Coverage" table: rows for `scripts/crew/`, `scripts/data/`, `scripts/gen/`, `scripts/layouts/`, `scripts/ship/`, `scripts/ui/` (every directory under `scripts/` but `scripts/proto/`, from `find scripts -type d`) and every top-level script in `scripts/`, each mapped to suites or with its uncovered files named. Built by grepping the suites and their `*_checks.gd` helpers for each script's class name and `res://` path, then reading the checks that use them; the standard (a check asserts on its behaviour, loading alone does not count) is stated above the table.
- `only=`: `tests/run_all.sh only=crew` printed `=== crew awareness`, then `=== summary`, `crew awareness: PASS (88 checks, 91 s)`, `total: 91 s`, exit 0, and no other suite. `tests/run_all.sh seeds=3 only=generator,static` ran static then the generator on 3 seeds (`seeds=` passed through) with the usual summary. `only=bogus` and `only=` each exit 2 with `run_all.sh: unknown suite '<name>' in only=; known: static generator layouts ship_3d pirate crew`.
- Follow-up tickets: `10-ship-dumper-checks.md` (`scripts/gen/ship_dumper.gd`, `dump_ship.gd`) and `11-hazard-stripes-check.md` (`scripts/ship/hazard_stripes.gd`), the only uncovered areas in the table.

## Comments

2026-11-22: built by a subagent. The orchestrating session re-ran `only=static` (PASS) and `only=bogus` (exit 2). Correction to the plan: the slow suites are pirate (123 s) and crew (91 s), not the generator sweep (40 s). Follow-ups: tickets 10 and 11.
