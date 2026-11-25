Type: grilling
Status: resolved
Blocked by: none
Map: ../map.md

# What the rules of a Loadout are

## Question

What exactly is a Loadout and what may it hold?

- Two weapons, any two: may both be the same weapon with different Attachments? May he carry one? Is there an order (which is in hand at the start of a Raid, which number key is which)?
- What is the Loadout before he has ever opened the screen?
- How is it kept: in the pirate's saved profile beside XP and gold? What happens to a saved Loadout when the catalogue changes under it (an Attachment removed or no longer fitting)?
- Where does a Raid read it, and what do a Retry and a New Raid do?
- What do the Sandbox sheet, the prototype scenes and the test suites hold, now that the Pirate no longer carries all four guns: is there a debug way to carry everything?
- What changes in the Weapon Wheel entry of `CONTEXT.md`?

## Answer

Grilled with the user on 2026-11-24. `CONTEXT.md`: the Loadout entry is rewritten and the Weapon Wheel entry now turns through "the weapons of his Loadout".

**What it holds**

- Exactly two weapons, never one, never the same weapon twice.
- They are ordered: the first is in hand at Raid start and on key 1, the second on key 2. The wheel flips between them.
- Attachments belong to the weapon, not to the Loadout: each of the four weapons remembers its own Attachments whether carried or not. The Loadout is which two.
- Default, before he has ever opened the screen: Pistol first, Assault Rifle second, every Slot empty.

**Saving**

- Kept in the same profile file as XP and gold (`user://profile.cfg`, `scripts/profile.gd`), saved when he leaves the Loadout screen.
- On load, anything stale is dropped quietly: an unknown Attachment, or one that no longer fits, becomes an empty Slot; an unknown or doubled weapon becomes the default. A save never fails to load because the catalogue changed.

**When it applies**

- A Raid reads the Loadout once at its start. A Retry and a New Raid reuse it. Changing it means going back to the main menu: no Loadout button on the death or extraction screens in this effort.

**Debug and tests**

- The Loadout applies only to a Raid started from the menu. Suites and prototype scenes keep setting the Pirate's weapons directly, any number of them.
- The Sandbox sheet shows all four weapons and all Attachments always, not only what is carried. Today it takes its weapon columns from the Pirate's carried list (`scripts/sandbox/sandbox_sheet.gd`), so that must change.
- The sheet, debug only, also gets a way to change the carried weapons and their Attachments during a Raid, so the balance pass needs no trip to the menu. The player has no such thing.
