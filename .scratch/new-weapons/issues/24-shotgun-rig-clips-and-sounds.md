Status: ready-for-agent
Blocked by: 23

# Shotgun rig, clips and sounds

## Parent

Part of `.scratch/new-weapons/spec.md` (Spec: Shotgun, Marksman Rifle and the Sandbox sheet). Build order 8 of 12. Vocabulary is `CONTEXT.md`'s. Numbers are starting numbers, tuned in the last ticket.

## What to build

See `issues/10-shotgun-look.md` and `issues/12-new-gun-sounds.md`.

Give `tools/blender/shotgun.py` a skeleton and clips with `kit.rig` and `kit.clip`, as `tools/blender/carbine.py` has (renamed by then). Its fore-end is already a separate mesh named Pump. Clips: the pump after a shot (the fore-end travels 7.5 cm back and returns within 0.55 s, starting 0.15 s after the shot), one shell going in, and the closing pump. Rebuild and reimport the model, and have the Viewmodel play the shell clip once per shell and the closing pump at the end of a reload from empty.

Sounds, from branch `prototype/new-gun-sounds`: the pump (shotgun cock) 0.2 s after each shot and on the closing pump, and one shell going in (first shell) as each shell seats. Bring them into `assets/audio/` with their licence note.

Blender runs headless: `flatpak run --filesystem=$PWD org.blender.Blender -b --python $PWD/tools/blender/shotgun.py`.

## Acceptance criteria

- [ ] The fore-end racks after every shot and the pump sound follows the shot.
- [ ] Each shell loaded plays the shell clip and sound once, in time with the counter.
- [ ] A reload from empty ends with the pump clip and sound; a top-up does not.
- [ ] Breaking the reload with a shot stops the clip cleanly.
- [ ] `tests/run_all.sh` passes.

## Comments
