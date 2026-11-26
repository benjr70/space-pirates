Status: resolved
Blocked by: 23

# Surrender and Bound

## Parent

Part of `.scratch/crew-combat/spec.md` (Spec: crew combat). Build order 10 of 14. Vocabulary is `CONTEXT.md`'s. Numbers are starting numbers, tuned in the last ticket.

## What to build

See the spec's "Surrender and Bound" and `issues/09`.

- Trigger: a Worker that sees the Pirate surrenders when he is within 4 m, or when his crosshair has rested on it within 10 m for 0.5 s, and it is hiding or has no route away that does not pass him. A Worker running with a way out keeps running. Never a Guard. The same with the Alarm up.
- Surrendered: it stands facing him, and after 1.5 s kneels, holding while he is in its sight. Out of his sight it goes back to hiding and the hiding rules apply.
- Bound: holding the interact key on a surrendered Worker within 2 m for 2 s. The weapon is lowered meanwhile; a hit on the Pirate or letting go cancels with nothing kept. A Bound Worker never moves, reports or raises the Alarm for the rest of the Raid.
- HUD: "Hold [interact] to tie up" with a fill ring within 2 m of a surrendered Worker. A Bound Worker shows no Awareness bar. The interact key must still prefer whatever the Pirate is looking at among a Door, a Container and a Worker.
- A Bound Worker is a serious trace: a Guard that sees one hunts from there, a Worker runs for a panel; it is reported once like a body, and is not untied.
- XP: binding 50 with a toast; killing a surrendered or Bound Worker 0 with a toast that says so; other kills unchanged. The end screen lists Workers bound.
- Ghost unaffected. Shots and Melee work on a kneeling or Bound Worker as on any crew; a hit that does not kill leaves it as it was.
- Poses are a later ticket: use a stand-in and say which.
- Update `CREW_AI.md` and the Stealth XP section.

## Acceptance criteria

- [x] (agent) A hiding Worker surrenders within 0.2 s of the Pirate coming within 4 m in its sight; one 8 m off surrenders 0.5 s after his crosshair settles on it, within 0.1 s, and not while it points 20 degrees away.
- [x] (agent) A Worker running for a panel with a clear route does not surrender when aimed at from 8 m.
- [x] (agent) No Guard is ever surrendered across the crew suite.
- [x] (agent) A surrendered Worker is kneeling 1.5 s after surrendering, within 0.2 s, and has not moved 30 s later with the Pirate in its sight.
- [x] (agent) A surrendered Worker the Pirate leaves, Alarm down and a panel working, has raised the Alarm within 20 s plus its walk; a Bound one in the same place has not after 120 s.
- [x] (agent) Holding interact within 2 m for 2 s binds it; released at 1.5 s it is not Bound and the next hold starts from nothing; the Pirate cannot fire during the hold.
- [x] (agent) Binding adds 50 XP; killing a surrendered Worker and killing a Bound one each add 0; an unaware Worker kill still adds 150.
- [x] (agent) A Guard patrolling into sight of a Bound Worker is hunting within 3 s of reaching it, and a second Guard later passing the same Worker does not react.
- [x] (agent) Extracting after binding two Workers with the Alarm never raised still earns the Ghost bonus, and the end screen shows 2 bound.
- [x] (agent) `tests/run_all.sh` passes.
- [ ] (human) Aiming at a cornered Worker and seeing it give up reads at once.
- [ ] (human) Tying one up feels worth the 2 seconds it costs.

## Evidence

- Surrenders near and aimed: `tests/test_crew.gd::_check_surrender_near` (a hidden Worker on the hiding rig, him 6 m off in its sight for 1 s: still COWER; him at 3.9 m: asserts surrendered within 0.2 s; measured 0.017 s) and `::_check_surrender_aimed` (with the Alarm up, a hidden Worker, him 8 m off in its sight: his crosshair turned 20 degrees off its chest for 1 s, asserts still COWER and `aimed_for` never above 0; crosshair on its chest (`Player3D.crosshair_on` asserted true), asserts surrendered 0.5 s after within 0.1 s; measured 0.500 s).
- Running with a clear route: `tests/test_crew.gd::_check_flee_aimed`: a Worker fleeing for a panel along Room A's north wall, the Pirate 8 m off aiming at its chest every frame until it raises the Alarm; asserts his crosshair rested on it at least 0.5 s in a row (measured 1.25 s), it never entered SURRENDER, and it raised the Alarm.
- No Guard surrendered: `tests/test_crew.gd::_check_no_guard_surrenders`, run last: a `node_added` hook connects every crew member's `surrender_changed`; asserts 0 Guard surrenders over the whole suite and more than 0 Worker ones (so the count listens).
- Kneeling and holding: `tests/test_crew.gd::_check_surrender_near`: asserts kneeling (`Crew3D.surrender == KNEELING`) 1.5 s after surrendering within 0.2 s (measured 1.50 s), then over the next 30 s with him 3.9 m off, him in its sight every frame, state SURRENDER every frame and at most 0.05 m moved (measured 0.000 m).
- Left surrendered, left Bound: `tests/test_crew.gd::_check_surrender_left`: surrendered to him 3 m off, the Pirate parked off the ship, Alarm down, a working panel in Room B; asserts it hid again, came out (REPORT) 20 s after it last saw him within 1 s (measured 20.00 s) and raised the Alarm within 1.5 m of the panel at the end of its walk (11.4 s walk, raised 31.4 s after). `::_check_bound_left`: the Worker Bound by `_check_bind_hold`, on the same tile, the Pirate parked, the same panel working; asserts after 120 s the Alarm is down, it is still BOUND and it moved at most 0.05 m.
- Binding by the hold: `tests/test_crew.gd::_check_bind_hold`, the Pirate under his own physics 1.5 m off facing the kneeling Worker: the key let go when the hold reached 1.5 s: asserts not Bound and `bind_held` back to 0; a hold cut by a hit at 1 s and the key kept down 1.5 s more: asserts the hold ended and did not start again; a fresh hold: asserts Bound 2.0 s after the hold started within 1.5 frames and not Bound at 1.9 s (so nothing of the 1.5 s was kept), and with the shoot key pressed in the middle of it, no `fired` signal and the magazine unchanged; asserts the Sandbox's bind reach and time are 2 m and 2 s.
- XP: `tests/raid_checks.gd::_check_surrender_xp` (in `ship_3d`), a medium Raid: binding through the hold's last frame adds exactly 50 to the ledger with the toast "+50 XP  bound"; killing that Bound Worker (a Melee strike) adds 0 with "+0 XP  it was Bound"; killing a surrendered one adds 0 with "+0 XP  it had surrendered"; killing an unaware Worker adds 150; both 0 kills count as kills.
- A Guard and a Bound Worker: `tests/test_crew.gd::_check_bound_left`: a Guard walking in from Room B to the Bound Worker; asserts it is in HUNT within 3 s of first coming within 2 m of it (measured 0.3 s) and the Worker is reported; 45 s later a second Guard walking the same way reaches it within 2 m and asserts it never leaves PATROL.
- Ghost with two Bound: `tests/raid_checks.gd::_check_ghost_with_bound`: a medium Raid, two Workers surrendered and Bound, the Alarm never raised, extracted through the pod; asserts the Ghost bonus (250) earned, exactly 2 x 50 + 350 + 250 XP banked, and the end screen's tally contains "2 bound" and ", 250 Ghost)".
- `tests/run_all.sh` passes: see the gate runs in Comments.

## Owed to playtest

- (human) Aiming at a cornered Worker and seeing it give up reads at once.
- (human) Tying one up feels worth the 2 seconds it costs.

## Comments

Built 2026-11-26.

Choices made:
- Two new states, last in `Crew3D.State`: SURRENDER and BOUND (Workers only). The trigger (`Crew3D._gives_up`) runs at the top of each FLEE and COWER tick, so it replaces the hook comment ticket 23 left at the end of `CrewHiding.tick`. "Sees him" is `_can_see`, the all-round sight those states already use. "His crosshair rests on it" is a ray along his view (`Player3D.crosshair_on`: the first thing on the world and body layers within 10 m is its body), counted in a row (`Crew3D.aimed_for`).
- "Hiding or no route away that does not pass him": on its hiding tile or hiding where it stands (`CrewHiding.is_hidden()`) counts as hiding; running to hide counts as having a way out (its run was chosen fair); freezing or fleeing, it has no way out when its flee route is not a fair run (`CrewHiding.fair_run`) and no hiding place has one (`CrewHiding.find`). That look runs at most once a second (`WAY_OUT_EVERY`) and only once the 4 m or 0.5 s test has passed.
- "Out of his sight it goes back to hiding": after 0.5 s out of sight (`SURRENDER_LOST`), so a frame of a prop between them does not end it; the come-out clock is set to the time since it last saw him, so with the Alarm down it comes out 20 s after it last saw him, as a hiding Worker does.
- A hit that does not kill leaves a surrendered or Bound Worker as it was, and marks it wounded (so if it hides again it never comes out, as ticket 23's wounded rule says). A Bound Worker killed has its `reported` cleared, so its body is a fresh trace ("leaves a body, a trace as usual", issue 09).
- Binding lives on the Pirate (`Player3D._tick_bind`): a fresh press of the interact key on `bind_target()` starts the hold; it needs the key down, the Worker still surrendered and within 2 m. Letting go, a hit (`take_damage`), a swing, a Clamber, death or the Worker getting up cancels it and keeps nothing; a held key after a hit does not restart it. During the hold `fire()` returns nothing, the sights cannot go up and the Viewmodel takes its sprint-low pose ("weapon lowered").
- The interact key: within 2 m of a surrendered Worker it is the Worker's unless a Door in his reach or a Container in reach is nearer the middle of his view (smallest flat angle from his facing). Doors ask `Player3D.can_interact()`, which is false while the Worker has the key; `main_3d.gd` neither searches nor prompts anything else then. Door-before-Container is unchanged. Extraction at the home door still comes first. Ticket `.scratch/raid-smoke-bugs/issues/08-...` (an emptied Container keeping the key) is still an open design question; binding does not depend on it (an emptied Container in reach that he faces more squarely still wins, like any Container).
- HUD: "Hold E to tie up" (the other prompts say "E — ...") with a ring over the prompt, filling clockwise from the top over the 2 s (`Hud.set_bind_progress`, set from `main_3d.gd` every frame). `tests/shots.sh hud` gains `hud_bind.png`.
- Numbers: the six surrender and bind numbers are on the Sandbox resource in a "Surrender and Bound" group (surrender reach 4 m, aim time 0.5 s, aim reach 10 m, kneel after 1.5 s, bind time 2 s, bind reach 2 m), so they already show as rows in the sheet's Health table; `docs/sandbox.md` regenerated. The XP are constants beside the other XP in `RaidLedger` (`BIND_XP` 50, `SURRENDERED_KILL_XP` 0). Ticket 26 may want to move the Sandbox rows into its Crew fight section.
- XP: a kill on a Worker that was SURRENDER or BOUND when it fell (`Crew3D.died_surrendered`) counts as a kill worth 0 and wins over unaware; toasts "+0 XP  it had surrendered" and "+0 XP  it was Bound"; binding "+50 XP  bound". Bind XP is kept on either ending like kill XP (`RaidLedger.kept_xp()`, used by both settles and both tallies). The end screens add ", N bound" after the kills when N > 0.
- Left as it was, recorded because the spec does not settle it: a Worker walking out of hiding to report (REPORT) is not in combat at Awareness 0.15, so killing it still counts as an unaware kill, 150 XP (ticket 23's note). The spec says "running or hiding kill 100" and "unaware kill 150" and does not name this case.
- Stand-in poses until ticket 25: surrendered (hands up and kneeling alike) plays the rig's Wave clip, looped; Bound plays Idle_Neutral. For ticket 25: `Crew3D.surrender` (`Surrender.HANDS_UP`, `KNEELING`, `BOUND`, `NONE`), the `surrender_changed` signal and `surrendered_for`. The stage goes back to NONE on death.
- A Bound Worker sets its Awareness to 0 and is skipped by `AwarenessMarkers.mark_at`; it does nothing in `_physics_process` (no perception, traces, hearing, movement) and `on_alarm` leaves both SURRENDER and BOUND alone.

Existing checks changed: `tests/test_crew.gd::_check_worker`'s cornered case: a Worker with no panel and no Guard, him 2.5 m off in its sight for 30 s, now asserts state SURRENDER (it asserted COWER): this ticket replaces hiding there with surrendering (him within 4 m in its sight). Its other assertions (no bolt, unarmed, cornered on 90% of frames) are unchanged. `tests/test_raid_smoke.gd`: the bot's `_onto_him` treats a surrendered Worker like a hiding one (shot only cornered at his elbow, 3 m, as before this ticket a hiding Worker at his elbow was) and never shoots a Bound one (the bot never binds); the ending checks now expect the ledger's `kept_xp()` (kill plus bind XP) where they expected `kill_xp()`, which is the same number while the bot binds nobody. The Loud script still shoots any Worker in sight, a surrendered one included (a 0 XP kill, still a kill). Not measured: how often a Worker surrenders in the smoke Raids.

Validation, 2026-11-26: full gate twice, both PASS (seed 377741020: crew 496 checks 78 s, ship_3d 3733, smoke 1097, total 358 s; seed 93018009: crew 88 s, smoke 1104, total 367 s). The tip commit's Jolt and spawn-order fixes were gated together for the first time in the first of these. `tests/run_all.sh only=crew seed=377741020` replayed the first gate's crew output exactly (diff of everything but wall times empty). `tests/run_all.sh only=crew` three more times PASS (seeds 377741020 replay, 464433969, 673008044; 496 checks each, 80-86 s). `tests/run_all.sh only=raid_smoke seeds=20` PASS (seed 342303098, 4389 checks, 780 s while other runs shared the machine). `tests/shots.sh hud` PASS: `hud.png` the HUD as before, no ring with the Hatch prompt; `hud_busy.png` as before; `hud_bind.png` "Hold E to tie up" with a ring 60% full above it, clear of the prompt and the toasts, "+50 XP  bound" toast readable beside the crosshair; nothing cut off or overlapping.
