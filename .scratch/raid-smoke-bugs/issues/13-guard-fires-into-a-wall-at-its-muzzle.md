Status: needs-triage
Blocked by: none

# A Guard fires into a wall at its muzzle, point blank

## What is wrong

In one Raid of a smoke run, an Assault Rifle Guard 1.5 m from the Pirate put 4 shots in a row into the Walls within 2 m of its muzzle, at (68, 54), t=42.8 s. The smoke invariant "none emptying bolts into cover at its muzzle" fails.

## Replay

    tests/run_all.sh only=raid_smoke seed=138129134

Fails 1 of 1285 checks: `large seed 807245063 loud`. The narrowed replay (`class=large ship=807245063 script=loud`) passes, so it needs the whole run.

## Notes

Found 2026-11-26 on the gate after the first balance pass (`.scratch/crew-combat/issues/28-first-balance-pass.md`), which made Guards fire sooner and let bolts skim past the hull and props. Not diagnosed: whether the cause is `Crew3D._over_own_cover` or the clear-muzzle test at point-blank range beside a wall corner, or older. The user chose to merge with this open.
