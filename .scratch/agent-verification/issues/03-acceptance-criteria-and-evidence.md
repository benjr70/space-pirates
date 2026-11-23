Status: resolved
Blocked by: none

# Acceptance criteria and evidence format

## Parent

`.scratch/agent-verification/spec.md`, build order 3 of 9.

## What to build

A ticket format that makes "matches the spec" something a reviewer can check line by line. Documentation only; no game code.

In `docs/agents/issue-tracker.md`, add a section defining:

- **Every `task` ticket has `## Acceptance criteria`**: a checklist where each line is one observable outcome, tagged `(agent)` or `(human)`.
  - `(agent)`: provable by a suite check, a scripted headless run or a screenshot defect check (ticket 04).
  - `(human)`: needs a play session or a judgement of look, sound or feel.
- **Numbers in the spec become `(agent)` lines.** If a spec says "~1.5 s at 10 m", the criterion states the value and tolerance, and a check asserts it.
- **A ticket without tagged criteria is not `ready-for-agent`.** The agent sets it to `needs-info` instead of guessing.
- **Evidence on completion.** Before closing, the builder appends `## Evidence` with one entry per `(agent)` line: the suite and check function that proves it (`tests/test_crew.gd::_check_timings`), or the command run and the relevant output lines, or the screenshot path and what was confirmed in it. `(human)` lines are listed under `## Owed to playtest` and stay unchecked.
- **Reviewer rule.** The Code Reviewer walks the list: an `(agent)` line with no evidence entry, or an entry whose check does not assert what the line says, blocks the ticket.

Also:

- Point `docs/agents/paperclip.md` at the new section from its Gate heading.
- Add one worked example ticket to the section, taken from a real past slice (the Awareness timings from the crew AI spec are a good one).

## Acceptance criteria

- [x] (agent) `docs/agents/issue-tracker.md` defines the tags, the `needs-info` rule, the `## Evidence` and `## Owed to playtest` sections and the reviewer rule.
- [x] (agent) The worked example names a check function that exists in `tests/`.
- [x] (agent) `docs/agents/paperclip.md` links to the section.
- [ ] (human) The maintainer agrees the format is light enough to use on every ticket.

## Evidence

- Definitions: `grep -n` on `docs/agents/issue-tracker.md` finds the section `## Acceptance criteria and evidence` (line 13) defining the `(agent)`/`(human)` tags, the `needs-info` rule (line 22), `## Evidence` (line 26), `## Owed to playtest` (line 27) and the reviewer rule (line 29).
- Worked example check exists: the example cites `tests/test_crew.gd::_check_timings` and `tests/test_crew.gd::_check_behind`; `grep -n "^func _check_timings\|^func _check_behind" tests/test_crew.gd` prints `133:func _check_behind() -> void:` and `143:func _check_timings() -> void:`. Read against the example lines: `_check_timings` asserts each standing time within 25% of 0.3/1.5/3.0 s at 3/10/14 m and the crouched ratio within 0.25 of 2.0; `_check_behind` ticks 120 steps of 1/60 s with the Pirate 3 m behind and asserts Awareness is 0.
- Paperclip link: `docs/agents/paperclip.md` under `## Gate` names the section "Acceptance criteria and evidence" in `docs/agents/issue-tracker.md` (`grep -n` line 23).

## Owed to playtest

- (human) The maintainer agrees the format is light enough to use on every ticket.

## Comments

2026-11-22: built by a subagent, checked by the orchestrating session (section text, cited check functions and the paperclip pointer all confirmed). Closing rule (`Status: resolved`) added to `docs/agents/issue-tracker.md` afterwards, since no finished state was defined.
