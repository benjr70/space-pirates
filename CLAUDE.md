## Agent skills

### Issue tracker

Issues live as local markdown files under `.scratch/<feature>/`; nothing is posted to GitHub issues. See `docs/agents/issue-tracker.md`.

### Triage labels

The five canonical triage roles, each string equal to its name, recorded as a `Status:` line in the issue file. See `docs/agents/triage-labels.md`.

### Domain docs

Single-context: `CONTEXT.md` and `docs/adr/` at the repo root. See `docs/agents/domain.md`.

### Validation

Every change is validated before it is called done. From the repository root:

```sh
tests/run_all.sh                    # the gate: every suite, about 150 s; must pass
tests/run_all.sh only=<suite>       # fast loop while building: static, generator, layouts, ship_3d, pirate, crew, raid_smoke
tests/run_all.sh only=crew seed=<n> # replay a failure exactly, with the seed the failing run printed
tests/shots.sh <preset>             # offscreen screenshots to read: viewmodel, ship, crew, hud, menu, scene
```

A ticket closes only with an evidence entry for each `(agent)` acceptance criterion. See `docs/agents/validation.md` for every tool, which suite covers which code, the screenshot defect checklist and the validation loop.
