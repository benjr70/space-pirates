Type: grilling
Status: resolved
Blocked by: none
Map: ../map.md

# What the sheet, the HUD, the Laser's dot and the reload sounds do

## Question

Four small things nothing has settled, each needed before the spec can be written:

- **Sandbox sheet.** How do Attachments appear in the in-Raid sheet (F1) and in the generated `docs/sandbox.md`: a second table with one column per Attachment and one row per attribute it can change? Does the sheet show the Built Weapon's numbers anywhere, or only bare Profiles and factors? What is the sheet's debug way of changing the carried weapons and their Attachments during a Raid ("What the rules of a Loadout are" decided it exists)?
- **HUD.** Does anything on the HUD change with Attachments: the crosshair with a Laser or a scope up, the ammo counter with a Drum, the hit marker? Is the HUD crosshair hidden while a lens or a Reflex Sight is up, since each draws its own aim mark?
- **The Laser's dot.** "Which Slots each weapon has and what the Attachments are" decided the Laser draws a visible dot. Is it a dot on whatever the gun points at, a beam, or both; what colour and size; is it there at the hip only or aimed too; and do crew show that they have seen it?
- **Reload sounds.** Does a Magazine change the reload sound (a Drum, a Quick Magazine), or do all keep the gun's own? "What a suppressed shot sounds like" settled the Suppressor only.

## Answer

Grilled with the user on 2026-11-24.

**Sandbox sheet**

- A fourth table, "Attachments", beside Weapons, Health and Melee, and Gunnery: one column per Attachment (fourteen), one row per attribute any Attachment changes, each cell a factor, blank where the Attachment changes nothing. Dialled, saved (amber when it differs from disk) and written to `docs/sandbox.md` like the other tables.
- The Weapons table gains a second, read-only value beside the bare one for the two carried guns, showing the Built Weapon's number wherever it differs. It is not written to `docs/sandbox.md`, since it depends on the Loadout.
- A strip at the top of the sheet changes the Loadout for debug: a picker for the FIRST and the SECOND gun, and under each a picker per Slot. The change applies when the sheet closes, with ammo refilled. Debug builds only, and it never touches the saved Loadout.

**HUD**

- The crosshair hides while he is aimed through a lens scope or a Reflex Sight, since each draws its own aim mark. At the hip, and aimed with a gun's own sights, it shows as today. It already opens with the live spread, so a Laser or a Barrel shows in it with no new work.
- The ammo counter shows the Built Weapon's magazine. The hit marker is unchanged. No Attachment icons.

**The Laser's dot**

- A small red dot on whatever the gun points at, at the hip and aimed. No beam. Out to 30 m, then nothing.
- Red, as the Reflex Sight's dot and the scopes' cross.
- It is a visual for the player only. Crew noticing him sooner is the conspicuous factor on Awareness already decided; they have no separate reaction to the dot.

**Reload sounds**

- Every Magazine keeps the gun's own reload sounds. Only the Suppressor changes a sound in this effort.
