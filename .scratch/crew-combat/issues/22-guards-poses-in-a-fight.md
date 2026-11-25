Status: ready-for-agent
Blocked by: 16, 17, 18

# Guards' poses in a fight

## Parent

Part of `.scratch/crew-combat/spec.md` (Spec: crew combat). Build order 8 of 14. Vocabulary is `CONTEXT.md`'s. Numbers are starting numbers, tuned in the last ticket.

## What to build

See the spec's "How crew look" and `issues/10`. Pose numbers and the poser: `git show prototype/crew-look:scripts/proto/proto_crew_look.gd` (`DOWN`, `DOWN_KNEE`, `DOWN_DEEP`, `RUN_LOW`, `RUN_TALL`, `RELOAD_*`, `AIM_LONG`).

- Down behind cover: a squat or one knee, picked again every time the Guard drops back after a peek, 60 to 40. Squatting, the top of its head is below 1.05 m; on one knee it is above 1.15 m.
- The head zone and the body's collision follow the pose, so a bolt over a 1.1 m crate can strike the head of a Guard on one knee and cannot strike a squatting one.
- Pop up over low cover; step out from full cover and back, with feet that step rather than slide; duck lower at a near miss.
- Reload while down: the left hand leaves the gun, goes to the belt, to the magazine well and back, timed to the reload; shell by shell for the Shotgun. Better than the prototype's three positions if a real clip is within reach (see `issues/02`); say what was used.
- Runs: low when the cover it runs to is low, upright when it is full or there is none.
- The stand-in pose from the cover ticket goes.
- `tests/shots.sh crew` (or a preset) shows a Guard down in each pose behind a crate, popped up, stepped out and reloading.

## Acceptance criteria

- [ ] (agent) Over 200 drops behind low cover, between 50% and 70% are squats, and a Guard's pose differs between some two consecutive drops.
- [ ] (agent) Squatting behind a 1.1 m crate, a bolt fired level at 1.2 m from the far side strikes nothing of the Guard; on one knee, the same bolt at 1.2 m strikes its head zone and is a Headshot.
- [ ] (agent) The body's collision top is below 1.05 m squatting and the crew member cannot be hit in the body over a 1.1 m crate in either pose.
- [ ] (agent) Running to a low cover tile the hips are at least 0.2 m lower than running to a full cover tile.
- [ ] (agent) Stepping out and back, neither foot bone moves more than 0.15 m while it is the planted foot.
- [ ] (agent) The screenshots show the squat, the knee, the pop-up, the step-out and the reload with the gun in both hands where it should be and no defect from the checklist.
- [ ] (agent) `tests/run_all.sh` passes.
- [ ] (human) A Guard on one knee offers a head shot that feels earned, and a squatting one feels properly hidden.
- [ ] (human) The reload and the step-out no longer look rough.

## Comments
