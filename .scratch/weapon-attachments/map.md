Label: wayfinder:map

# Weapon Attachments and the Loadout

## Destination

One spec at `.scratch/weapon-attachments/spec.md`, with build tickets, that a build can start from with nothing left to decide. It covers three things: Attachments (the catalogue, which Slots each weapon has, what each Attachment does to a weapon and a model for each one, seen on the gun in the Viewmodel), the Loadout (two weapons and their Attachments, kept between sessions), and a Loadout screen reached from the main menu.

## Notes

- Domain: Godot 4 first-person extraction shooter. Weapons are data: `scripts/weapon_profile.gd` plus one `.tres` per weapon under `resources/weapons/`. Read `CONTEXT.md` for vocabulary (Attachment, Slot, Loadout, Weapon Profile, Sandbox, Viewmodel, Aim Down Sights, Weapon Wheel).
- Planning only: tickets resolve decisions. Prototypes are throwaway, on local `prototype/<name>` branches, never merged.
- Skills: `grilling` and `domain-modeling` for every grilling ticket; `prototype` for prototype tickets; `research` for research tickets.
- Decided while charting:
  - Five Slots: Sight, Barrel, Magazine, Underbarrel, Stock. A weapon has only the Slots that make sense for it. An empty Slot is always valid.
  - Every Attachment is a sidegrade: a gain and a cost.
  - All Attachments are free and available from the start.
  - The Loadout is two weapons, any two, with their Attachments. It is saved with the pirate's profile and used by every Raid and Retry.
  - Crew weapons take no Attachments.
  - A small shared catalogue: about 12 to 16 Attachments, 2 to 3 per Slot, each fitting several weapons where that makes sense.
  - The Sight Slot includes magnified scopes. The Barrel Slot includes a suppressor that cuts how far crew hear the shot. Underbarrel Attachments are passive. Magazine Attachments change capacity and reload time only.
  - Attachments are part of the Sandbox and are tuned in the in-Raid sheet (F1).
  - The Loadout screen is its own screen behind a main menu button: pick two weapons, pick an Attachment per Slot, with a turning 3D preview of the gun as built and bars comparing it to the bare gun.
- Models are built headless in Blender from `tools/blender/*.py` (see `kit.py`, `palette.py` and one script per gun). The user judges every look in a prototype scene.
- Sounds are picked by the user's ear in the sound booth prototype, never by measurement.
- Facts at charting time: the Pirate carries all four guns (`scripts/player_3d.gd`, `weapons`); a gun's model is one scene under `scenes/weapons` with `Muzzle` and `SightTip` markers, and the Viewmodel centres the `SightTip` in Aim Down Sights; there is no damage falloff, so a shot's reach is its `projectile_speed` times `projectile_lifetime`; `loudness` is a Profile field; the Sandbox sheet saves to one `.tres` per weapon; gold and XP exist and nothing spends them.
- The rule "a new weapon is a new Profile, never new code" stands. How an Attachment sits beside it is the first decision ticket.

## Decisions so far

<!-- one line per resolved ticket -->

- [How reference shooters build their attachment systems](issues/01-reference-shooter-attachments.md): shared optics and muzzles are common, effects run 10 to 50%, suppressors are paid for in bullet velocity; the best-evidenced mistake is unclear or misreported effects; magazine size against reload time unconfirmed anywhere.
- [How a magnified scope is drawn in Godot 4](issues/02-scope-rendering-in-godot.md): four ways; lowering the field of view (today's way) is free and keeps the weapon's size, picture-in-picture is the only true lens and costs a second render; prototype those two, overlay as fallback, nothing measured in engine.
- [How an Attachment changes a weapon](issues/03-how-an-attachment-changes-a-weapon.md): bare Profile plus Attachments gives a Built Weapon, itself a Profile, never saved; changes are multipliers, same on every gun; damage and the kind of gun are off limits; no falloff, range is bolt speed and spread; aim time and swap time become per-weapon attributes.
- [Which Slots each weapon has and what the Attachments are](issues/04-slots-and-the-catalogue.md): fourteen Attachments, one job per Slot, with the fit table; Pistol has no Stock Slot, Shotgun no Magazine Slot and no Suppressor, Marksman Rifle only the Long Scope; zoom becomes a factor; the Laser costs being seen, through a new conspicuous attribute.
- [What the rules of a Loadout are](issues/05-loadout-rules.md): exactly two different weapons, first and second; each weapon remembers its own Attachments; default Pistol and Assault Rifle bare; saved in the profile file with stale entries dropped quietly; read once at Raid start; the sheet shows everything and can change the Loadout in a Raid for debug.
- [How Attachments mount on a gun model](issues/06-how-attachments-mount-on-a-gun.md): an Attachment adds itself or replaces one of the gun's own parts, so each gun keeps barrel, sights, magazine and stock as separate meshes; a Barrel brings the muzzle and a Sight the aim point; Magazines ride the gun's reload clip; poses stay the weapon's own. Prototype on `prototype/attachment-mounting`.
- [What the scoped view looks like](issues/07-scoped-view.md): a scope is a picture-in-picture lens with the view around it at 1.25x, blurred and fading to black at the edge; cross reticle on the shot line; both scopes share it and differ only in magnification; the Reflex Sight is an unmagnified window with a dot. Prototype on `prototype/scoped-view`.
- [What the Loadout screen looks like](issues/08-loadout-screen.md): the workbench: FIRST and SECOND tabs, the gun still and side-on (drag to turn), Slots as tags around it that open a list, nine bars of built against bare with numbers; only carried guns are edited; mouse and keyboard. Prototype on `prototype/loadout-screen`.
- [What each Attachment looks like](issues/09-attachment-look.md): all fourteen modelled and accepted: seven shared models placed at mount points each gun gives (sight, muzzle, underside), eighteen per-gun models for Barrels, Magazines and Stocks; all four guns split into hideable parts. Prototype on `prototype/attachment-look`.
- [What a suppressed shot sounds like](issues/10-suppressed-shot-sounds.md): picked by ear, all real recordings of smaller or subsonic rounds: 9 mm at mid distance for the Pistol, a .22 revolver for the Assault Rifle, .300 Blackout for the Marksman Rifle. Picks on `prototype/suppressed-sounds`.
- [What aim time and swap time feel like on each gun](issues/12-aim-time-and-swap-time.md): bare aim times 0.15 to 0.32 s and swap times 0.30 to 0.50 s by gun; what aiming gives comes in with the rise; a swap takes the drawn gun's time; a Descope recovers over the full aim time. No felt range found. Prototype on `prototype/aim-and-swap-time`.
- [What each Attachment's starting numbers are](issues/13-starting-numbers.md): a factor for every change of all fourteen, with the Built Weapon numbers the checks assert; zoom floored at 1.0; no cap on stacked aim time; suppressed shots heard at 9.6 m; a list flagged for the balance pass.
- [What the sheet, the HUD, the Laser's dot and the reload sounds do](issues/14-sheet-hud-laser-and-reload-sounds.md): an Attachments table in the sheet, Built Weapon numbers beside bare ones, a debug Loadout strip; the crosshair hides behind a lens or Reflex Sight; the Laser is a red dot to 30 m, no beam; Magazines keep the gun's reload sounds.
- [Assemble the spec and the build tickets](issues/11-assemble-the-spec.md): the spec is `spec.md`; ten build tickets, `issues/15` to `issues/24`, in build order with tagged acceptance criteria; the map is walked.

## Not yet specified

Nothing. Every decision is made; the way to the destination is `spec.md` and its build tickets.

## Out of scope

- Buying Attachments with gold, unlocking them by level, or finding them as Loot: all are free for now; the economy is a later effort.
- Attachments on crew weapons.
- Underbarrel Attachments with their own input: grenade launchers, a flashlight toggle.
- Ammo types (incendiary, armour piercing).
- Changing Attachments or weapons during a Raid.
