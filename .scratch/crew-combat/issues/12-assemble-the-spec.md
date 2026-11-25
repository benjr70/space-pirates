Type: task
Status: resolved
Blocked by: 03, 04, 05, 06, 07, 08, 09, 10, 13, 14
Map: ../map.md

# Assemble the spec

## Question

With every decision on the map made, write `.scratch/crew-combat/spec.md` from the tickets' answers and slice it into build tickets under `.scratch/crew-combat/issues/`, each with tagged acceptance criteria as `docs/agents/issue-tracker.md` requires.

Nothing is decided here. If writing the spec exposes a gap, it becomes a new decision ticket that blocks this one. Anything still listed under the map's "Not yet specified" when this ticket is reached must have graduated or been ruled out of scope first.

## Answer

Done on 2026-11-25. Nothing was decided here; every line of the spec comes from a resolved ticket.

- The spec: [`spec.md`](../spec.md), `Status: ready-for-agent`.
- Fourteen build tickets, `issues/15` to `issues/28`, each with a `Blocked by:` line and acceptance criteria tagged `(agent)` or `(human)` as `docs/agents/issue-tracker.md` requires. Thirteen are `ready-for-agent`; the balance pass is `ready-for-human`. The Awareness bar ticket (`issues/11`) rides along, unblocked.

| Order | Ticket | Blocked by |
|---|---|---|
| 1 | [A Gunnery per weapon and the gun roll](15-gunnery-per-weapon-and-the-gun-roll.md) | none |
| 2 | [Guards carry their guns](16-guards-carry-their-guns.md) | 15 |
| 3 | [Crew magazines and reloads](17-magazines-and-reloads.md) | 15 |
| 4 | [Guards find, hold and peek from cover](18-guards-find-hold-and-peek-from-cover.md) | 15 |
| 5 | [Fair fire](19-fair-fire.md) | 18 |
| 6 | [A habit per gun](20-a-habit-per-gun.md) | 18, 19 |
| 7 | [Guards work together](21-guards-work-together.md) | 19, 20 |
| 8 | [Guards' poses in a fight](22-guards-poses-in-a-fight.md) | 16, 17, 18 |
| 9 | [Unarmed Workers run and hide](23-unarmed-workers-run-and-hide.md) | 15 |
| 10 | [Surrender and Bound](24-surrender-and-bound.md) | 23 |
| 11 | [Workers' poses](25-workers-poses.md) | 22, 24 |
| 12 | [Crew fight in the Sandbox sheet](26-crew-fight-in-the-sandbox-sheet.md) | 19, 21 |
| 13 | [Firefights in the raid smoke suite](27-firefights-in-the-raid-smoke-suite.md) | 21, 24 |
| 14 | [First balance pass of crew combat](28-first-balance-pass.md) | all thirteen |

**Slicing choices made in the writing, none a new decision**

- "Holds before shifting" (4 s, 4 s, 8 s, never) is written as a Gunnery field, since the range band it goes with is one.
- Between the first ticket and the Workers ticket a cornered Worker cowers as today; between the cover ticket and the poses tickets crew use stand-in poses. Each interim is named in its ticket.
- The pose tickets come after the behaviour they dress, so behaviour can be judged and checked before the look is.

**For whoever builds**

- The two prototype branches are local and unpushed: `prototype/guards-in-cover` (`5f2bf8c`) and `prototype/crew-look` (`76e13fc`). Read with `git show <branch>:<path>`. The research branches are on origin.
- The cover prototype is a brain bolted onto `crew.gd` through one hook. The cover ticket asks for it to be ported properly, not copied.
- Many tolerances in the acceptance criteria are judgement, not measurement, and the lifetimes in "Fair fire" come from arithmetic. A builder who finds one wrong against the spec should say so in the ticket and not bend the check.
- `CONTEXT.md` was updated as each decision was made (Guard, Worker, Pistol, Gunnery, Sandbox, Surrender, Bound), so it describes the game as specified, ahead of the code.
