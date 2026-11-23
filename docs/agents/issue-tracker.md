# Issue tracker: Local Markdown

Issues and specs for this repo live as markdown files in `.scratch/`.

## Conventions

- One feature per directory: `.scratch/<feature-slug>/`
- The spec is `.scratch/<feature-slug>/spec.md`
- Implementation issues are one file per ticket at `.scratch/<feature-slug>/issues/<NN>-<slug>.md`, numbered from `01`, never a single combined tickets file
- Triage state is recorded as a `Status:` line near the top of each issue file (see `triage-labels.md` for the role strings)
- Comments and conversation history append to the bottom of the file under a `## Comments` heading

## Acceptance criteria and evidence

Every ticket that builds something has an `## Acceptance criteria` checklist. This covers `Type: task` tickets and any implementation ticket with no `Type:` line; `research`, `prototype` and `grilling` tickets are exempt. Each line is one observable outcome with one tag:

- `(agent)`: provable by a suite check, a scripted headless run, or a screenshot defect check.
- `(human)`: needs a play session or a judgement of look, sound or feel.

A number in the spec becomes an `(agent)` line that states the value and the tolerance, and a check asserts both. "About 1.5 s at 10 m" is not a criterion; "1.5 s at 10 m, within ±25%" is.

A ticket without tagged criteria is not `ready-for-agent`. An agent that picks one up sets its `Status:` to `needs-info` and says what is missing under `## Comments`, instead of guessing the criteria.

On completion, before closing, the builder ticks every met `(agent)` line and adds two sections above `## Comments`:

- `## Evidence`: one entry per `(agent)` line, giving one of: the suite and check function that proves it (`tests/test_crew.gd::_check_timings`); the command run and the relevant output lines; or the screenshot path and what was confirmed in it.
- `## Owed to playtest`: every `(human)` line, copied as written. These stay unchecked in `## Acceptance criteria`; the maintainer ticks them after playing.

The Code Reviewer walks the list. An `(agent)` line with no evidence entry, or an entry whose check does not assert what the line says (a different value, a looser tolerance, a different case), blocks the ticket.

A ticket that is built, reviewed and passing the gate is closed by setting its `Status:` line to `resolved`, in the same session, even when the commit is still pending. Unticked `(human)` lines do not hold it open; they stay listed under `## Owed to playtest`.

### Worked example

The Awareness timings slice of `.scratch/crew-ai/spec.md`, as it would read when finished:

```md
## Acceptance criteria

- [x] (agent) Standing in the open, square in view, time to spotted is 0.3 s at 3 m, 1.5 s at 10 m and 3 s at 14 m, each within ±25%.
- [x] (agent) Crouching doubles the time to spotted at each of those distances, within ±0.25 of 2×.
- [x] (agent) The Pirate 3 m behind a crew member raises no Awareness in 2 s.
- [ ] (human) Being spotted feels fair: the approach from behind works and the marker gives time to back off.

## Evidence

- Standing times: `tests/test_crew.gd::_check_timings`, which spots the Pirate at 3, 10 and 14 m and asserts each time is within 25% of 0.3, 1.5 and 3.0 s.
- Crouching doubles: `tests/test_crew.gd::_check_timings`, which repeats each distance crouched and asserts the ratio to standing is within 0.25 of 2.0.
- Nothing from behind: `tests/test_crew.gd::_check_behind`, which ticks 2 s with the Pirate 3 m behind and asserts Awareness is still 0.

## Owed to playtest

- (human) Being spotted feels fair: the approach from behind works and the marker gives time to back off.
```

## When a skill says "publish to the issue tracker"

Create a new file under `.scratch/<feature-slug>/` (creating the directory if needed).

## When a skill says "fetch the relevant ticket"

Read the file at the referenced path. The user will normally pass the path or the issue number directly.

## Wayfinding operations

Used by `/wayfinder`. The **map** is a file with one **child** file per ticket.

- **Map**: `.scratch/<effort>/map.md` (the Notes / Decisions-so-far / Fog body).
- **Child ticket**: `.scratch/<effort>/issues/NN-<slug>.md`, numbered from `01`, with the question in the body. A `Type:` line records the ticket type (`research`/`prototype`/`grilling`/`task`); a `Status:` line records `claimed`/`resolved`.
- **Blocking**: a `Blocked by: NN, NN` line near the top. A ticket is unblocked when every file it lists is `resolved`.
- **Frontier**: scan `.scratch/<effort>/issues/` for files that are open, unblocked, and unclaimed; first by number wins.
- **Claim**: set `Status: claimed` and save before any work.
- **Resolve**: append the answer under an `## Answer` heading, set `Status: resolved`, then append a context pointer (gist + link) to the map's Decisions-so-far in `map.md`.

## GitHub is not the tracker

Never create, comment on, label or close GitHub issues for this repo. `#NN` references in older files and commits point at the retired GitHub tracker in `benjr70/space-pirates` (issues #1–#63); treat them as history. Work that was still open there was imported into `.scratch/`.
