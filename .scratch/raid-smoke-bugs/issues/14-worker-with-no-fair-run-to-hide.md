Status: needs-triage
Blocked by: none

# A Worker finds no fair run to any hiding place for 25 s

## What is wrong

`tests/test_crew.gd::_check_workers_in_fight` fails when it rolls medium ship seed 296842: "a Worker of Room 5 in state 8, hiding where it stands, at (65, 73)". That Worker finds no fair run to any hiding place, so it is not in a corner at 25 s.

## Replay

The check rolls its ship seed itself, so there is no replay command: put `ship_seed = 296842` into `_check_workers_in_fight` temporarily. Shown on `cfbef27` and after. See the second round in `12-crew-pinned-by-their-own-walking-rules.md`.
