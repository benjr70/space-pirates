Status: needs-triage
Blocked by: none

# An emptied Container can take the interact key from a full one beside it

## Parent

Noticed on 2026-11-22 while hardening the whole-Raid smoke run. A design question, not a confirmed bug.

## What was seen

The interact key works the nearest Container in view even when that Container is already open and shows "Empty", so it can keep the Pirate from searching a full Container right next to it until he moves. The smoke bot steps closer to the full one to get round it.

## Question for the maintainer

Should an emptied Container stop offering a prompt, so the key goes to the nearest Container that still holds Loot?

## Acceptance criteria

- [ ] (human) Decided: change it or leave it.

## Comments
