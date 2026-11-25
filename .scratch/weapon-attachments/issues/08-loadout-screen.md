Type: prototype
Status: resolved
Blocked by: 05
Map: ../map.md

# What the Loadout screen looks like

## Question

How is the Loadout screen laid out and worked? Build two or three rough layouts behind a Loadout button on the main menu, with placeholder Attachments, and compare them: how the two weapons are picked, how a Slot is opened and an Attachment chosen or cleared, where the turning 3D preview of the gun sits, how the bars show the built gun against the bare one (which attributes get a bar, and how a gain and a cost read at a glance), how a weapon without a given Slot shows that, and how he gets back to the menu and into a Raid. Mouse only, or keyboard and gamepad too?

## Answer

Prototyped and used by the user on 2026-11-24. Three layouts were compared behind a Loadout button on the real main menu: workbench, columns (all four guns listed, every Slot's choices as chips) and two-up (both guns side by side with drop-downs). The user: "Layout workbench F1 is perfect", with one change, made and accepted: the gun does not spin by itself.

**Prototype (primary source)**: local branch `prototype/loadout-screen` (commits 4020faa and de9dca2, never merged, not pushed). `scenes/proto_loadout_screen.tscn` and `scripts/proto/proto_loadout_screen.gd`. Run with `flatpak run org.godotengine.Godot --path . res://scenes/proto_loadout_screen.tscn`; `F1` is the chosen layout; `--selftest` for a headless check. The numbers behind its bars are placeholders and its gun never shows its Attachments.

**The screen: the workbench**

- Reached from a Loadout button on the main menu's home list, under Play. It lies over the menu's backdrop, darkened.
- Two tabs across the top, FIRST and SECOND, each naming the gun carried there. The chosen tab's gun is the one on the bench.
- Under the tabs, a row of all four weapons to change which gun is carried in that place. Picking the gun already in the other place swaps the two.
- The gun fills the middle, still and side-on, barrel to the left. Click and drag on it turns it freely, sideways and up and down, and it stays where it is left; a double click puts it back side-on. It never turns by itself.
- Each of the five Slots is a tag hung around the gun near where the part mounts: the Slot's name over the fitted Attachment, or "empty". A weapon without that Slot shows the tag greyed with "no Slot".
- Clicking a tag opens that Slot's list at the top right: None, then each Attachment that fits, the fitted one marked, each with one short line of what it gains and costs. Picking one fits it and closes the list.
- Below the list, the gun as built against the gun bare, in bars.
- Back, top right, or Esc, returns to the main menu. A Raid starts from Play as today: no Raid button on this screen.

**Bars**

- Nine: Bolt speed, Hip accuracy, Aimed accuracy, Recoil control, Handling, Magazine, Reload, Quiet, Zoom.
- Each is grey up to the lower of bare and built, then green for what the Attachments gained or red for what they cost, with the built value as a number at the end in the same colour.
- A red line under them, "Crew notice him sooner", when a Laser is fitted.

**Words**

- The gain and cost line under each Attachment is generated from its changes, never hand-written, in keeping with "How an Attachment changes a weapon".

**What can be edited**

- Only the two carried guns. To fit a third, carry it first. A gun swapped out still remembers its Attachments, as "What the rules of a Loadout are" decided.

**Input**

- Mouse for everything, and keyboard focus (arrows, Enter, Esc) as on the rest of the menu. No gamepad in this effort.
