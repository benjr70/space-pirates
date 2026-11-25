Type: task
Status: resolved
Blocked by: 03, 04, 05, 06, 07, 08, 09, 10, 12, 13, 14
Map: ../map.md

# Assemble the spec and the build tickets

## Question

Write `.scratch/weapon-attachments/spec.md` from the resolved tickets, then slice it into build tickets with tagged acceptance criteria as `docs/agents/issue-tracker.md` requires. Nothing is decided here: anything the tickets left open goes back on the map as a new ticket first. This ticket is also blocked by whatever the fog under "Not yet specified" graduates into.

## Answer

Done on 2026-11-24. Nothing was decided here; every line of the spec comes from a resolved ticket.

- The spec: [`spec.md`](../spec.md), `Status: ready-for-agent`.
- Ten build tickets, `issues/15` to `issues/24`, each with a `Blocked by:` line and acceptance criteria tagged `(agent)` or `(human)` as `docs/agents/issue-tracker.md` requires. Nine are `ready-for-agent`; the balance pass is `ready-for-human`.

| Order | Ticket | Blocked by |
|---|---|---|
| 1 | [Aim time and swap time per weapon](15-aim-time-and-swap-time-per-weapon.md) | none |
| 2 | [Attachments as data and the Built Weapon](16-attachments-and-the-built-weapon.md) | 15 |
| 3 | [The Loadout](17-the-loadout.md) | 16 |
| 4 | [Guns with replaceable parts and mount points](18-guns-with-replaceable-parts.md) | none |
| 5 | [Attachment models on the gun in hand](19-attachment-models-in-the-viewmodel.md) | 16, 18 |
| 6 | [The scoped view and the Reflex Sight](20-scoped-view-and-reflex-sight.md) | 19 |
| 7 | [The Laser's dot](21-the-lasers-dot.md) | 19 |
| 8 | [The Loadout screen](22-the-loadout-screen.md) | 17, 19 |
| 9 | [Attachments in the Sandbox sheet](23-attachments-in-the-sandbox-sheet.md) | 17 |
| 10 | [First balance pass of the Attachments](24-first-balance-pass.md) | all nine |

The two patches of fog left on the map were settled in the writing: how the suites cover it is the spec's "Testing Decisions" (a new `attachments` suite, three screenshot presets, behaviour checked in the suite that covers its code), and the slicing is the table above.

**For whoever builds**

- The build needs the prototypes, `prototype/attachment-look` and `prototype/suppressed-sounds` above all. All six prototype branches were pushed to origin on 2026-11-24 (the tickets' own answers still say "not pushed", as written at the time); they are never merged. Read from them with `git show origin/prototype/<name>:<path>` or check files out of them.
- Some numbers in the acceptance criteria are derived, not measured: the muzzle offsets in ticket 19 come from the prototype's marker positions, and the Awareness and hearing checks in ticket 16 from the factors. A builder who finds one wrong against the spec's tables should say so in the ticket and not bend the check.
