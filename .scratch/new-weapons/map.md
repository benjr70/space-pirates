Label: wayfinder:map

# New weapons: Shotgun, precision rifle and the Sandbox sheet

## Destination

One spec at `.scratch/new-weapons/spec.md` that a build can start from with nothing left to decide. It covers three things: the Shotgun, a precision rifle, and a master weapon sheet where every attribute of every weapon in the Sandbox (the Pirate's and the crew's) is seen side by side and dialled.

## Notes

- Domain: Godot 4 first-person extraction shooter. Weapons are data: `scripts/weapon_profile.gd` plus one `.tres` per weapon under `resources/weapons/`. Read `CONTEXT.md` for vocabulary (Weapon Profile, Sandbox, Viewmodel, Aim Down Sights, Descope).
- Planning only: tickets resolve decisions. Prototypes are throwaway.
- Skills: `grilling` and `domain-modeling` for every grilling ticket; `prototype` for prototype tickets; `research` for research tickets.
- Glossary renames decided while charting: Sidearm is now **Pistol**, Carbine is now **Assault Rifle**. `CONTEXT.md` is updated; code, resources, scenes and asset folders still say sidearm/carbine. The spec must include that rename, since the glossary says code uses its terms verbatim.
- The rule "a new weapon is a new Profile, never new code" stands: a new shot mechanic is added once as Profile fields, and the guns stay data.
- Sounds are picked by the user's ear in the sound booth prototype, never by measurement.
- Weapon models are built headless in Blender from `tools/blender/*.py`. `shotgun.glb` and `blunderbuss.glb` are already built in `tools/blender/out/` and not yet imported.
- Facts at charting time: one shot is one projectile; `damage` is a flat int with no headshots or falloff; crew `Health` is 4 and the Pirate's is 6; shot sounds are shared in `scripts/pirate_audio.gd` rather than per Profile; crew gunnery numbers live in `scripts/crew/crew.gd`, not in a Weapon Profile.

## Decisions so far

<!-- one line per resolved ticket -->

- [What Godot offers for editing many Resources as one table](issues/01-godot-table-tooling.md): no built-in table; one maintained addon edits `.tres` in place with gaps for Vector3 and PackedScene; CSV carries strings only; a plain `.tres` change does not reach a running game without a reload step.
- [How reference shooters tune shotguns and precision rifles](issues/02-reference-shooter-numbers.md): Halo Infinite's shotgun is a fast 2-shot non-power weapon with no headshot bonus; precision rifles kill in a fixed shot count finished by a headshot; pellet patterns, falloff and descope numbers could not be confirmed.
- [How crew gunnery sits in the Sandbox sheet](issues/03-crew-gunnery-in-the-sandbox.md): crew hold the Pirate's own Pistol Profile; what is theirs alone is a per-crew-type Gunnery row (aim error, burst, pause, engage range); Health joins the sheet; crew bolts get fast and are retuned in the balance pass.
- [What the master weapon sheet is](issues/04-master-weapon-sheet.md): an in-Raid sheet (F1, debug only) that dials live and saves to one `.tres` per weapon, per-crew-type Gunnery resources and a Health resource, plus a generated, test-checked `docs/sandbox.md` as the record; no CSV.
- [What the Shotgun is for](issues/05-shotgun-role.md): the doorway gun; one-shot kill inside about 4 m, pump-action, 6 shells loaded one at a time with an interruptible reload, no Slide penalty, and the loudest gun now that loudness is a Profile attribute.
- [What the precision rifle is](issues/06-precision-rifle-identity.md): the Marksman Rifle; semi-automatic, 8 rounds, one headshot or two body shots kills, poor from the hip and pinpoint when aimed and still, normal loudness, fastest bolt.
- [What the damage model needs](issues/07-damage-model.md): Health and damage scale by 25 (crew 100, Pirate 150); crew get a head zone and each Profile a headshot multiplier (Marksman Rifle 2, Pistol 1.5, others 1); a pellet count field; no damage falloff.
- [How the Shotgun's pellets fly](issues/08-shotgun-pellet-pattern.md): a random scatter of 12 pellets at 13 damage each (8 kill), 5 degree cone, 15 m reach, 0.8 s pump; still no falloff; one shot must count one kill.
- [How the precision rifle aims](issues/09-precision-rifle-aiming.md): sights on the Viewmodel at 3x, 0.25 degrees of sway, mouse slowed by zoom, 3 degree hip cone, 1.2 degrees aimed and walking; the Profile needs an aimed-and-moving spread.
- [What the Shotgun looks like](issues/10-shotgun-look.md): the pump-action boarding shotgun already built in Blender, hip pose (0.15, -0.24, -0.34); it still needs a rig, clips and importing.
- [What the Marksman Rifle looks like](issues/11-marksman-rifle-look.md): the black bullpup, hip pose (0.15, -0.2, -0.36), aimed distance 0.36; the rough model needs a finished pass, a rig and clips.
- [Which sounds the new guns make](issues/12-new-gun-sounds.md): Shotgun shot, pump and shell, Marksman Rifle shot and magazine, and a new Pistol shot picked by ear, all CC0; shot sounds become per weapon; the Headshot sound and the Assault Rifle's shot stay open.
- [How the Shotgun's shell-by-shell reload plays](issues/13-shotgun-shell-reload.md): one tap fills it; 0.55 s first shell, 0.45 s each after, 0.45 s closing pump from empty; a shot breaks in and fires 0.25 s later, losing the shell in hand.
- [How the HUD shows the new guns](issues/14-hud-for-new-guns.md): the crosshair stays today's four lines for every gun; a Headshot is the same X in gold; Health becomes one bar in six segments of 25.
- [Assembling the spec](issues/15-assemble-the-spec.md): the spec is written at [spec.md](spec.md); wheel order Pistol, Assault Rifle, Shotgun, Marksman Rifle with keys 1 to 4; the rename goes first and the balance pass last, in twelve build steps.

## Not yet specified

Nothing. The destination is reached: [spec.md](spec.md) is written. One ticket stays open and does not hold up the build: [What a Headshot sounds like, and the Assault Rifle's shot](issues/16-headshot-and-assault-rifle-sounds.md). The Marksman Rifle's reload is a plain magazine swap and needs no decision of its own.

## Out of scope

- Loadouts: the Pirate carries all four weapons on the Weapon Wheel. Choosing what to bring is a later effort.
- Crew holding any weapon but the Pistol: a future map. Crew magazines and reloads go with it.
- Ammo reserves and pickups: reserves stay infinite.
- Scopes, and weapon attachments and modifications generally: a later effort. The Marksman Rifle ships with sights.
