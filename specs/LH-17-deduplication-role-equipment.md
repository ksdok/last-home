# LH-17 (M) — Single source of truth for role application (deduplication)

## Context

Role application logic is currently **duplicated verbatim** between the server
and the client:

- `media/lua/server/LastHomeServer.lua` — `addItemsToContainer`,
  `buildItemCounts`, `addRoleItems`, `applyRoleStats`, `isPassivePerk`,
  `applyPerkLevel`, and the body of `applyRole`.
- `media/lua/client/LastHomeClient.lua` (the solo `applyRoleLocally` block) —
  the same six helpers plus `applyRoleLocally`.

This is ~200 lines of duplicated code and **two sources of truth** for what a
role puts in a player's inventory, their skills, stats, and equipment. It has
already caused a real divergence: LH-14 fixed `fillAmmoItem` (which lives in the
shared module) but the duplicated `addRoleItems`/`applyPerkLevel` copies had to
be kept in sync by hand. Any future change to role equipment must be made in
two places or the solo fallback drifts from the server path.

The shared module `LastHomeShared.lua` already centralizes some helpers
(`applyCarryProfile`, `primeRoleLoadout`, `equipRoleItems`,
`resolveSecondaryEquipItem`, `fillAmmoItem`, `forEachContainerItemRecursive`).
This ticket finishes the job.

## Goal

A single source of truth for role application in `LastHomeShared.lua`. Both
the server (`applyRole`) and the solo client fallback (`applyRoleLocally`)
call the same shared routine. No duplicated role-application logic remains in
either `LastHomeServer.lua` or `LastHomeClient.lua`.

## Changes

### `media/lua/shared/LastHomeShared.lua` — new shared role-application API

Add the helpers currently duplicated, exposed on `LastHomeShared`:

- `LastHomeShared.addItemsToContainer(container, itemId, count)`
- `LastHomeShared.buildItemCounts(items)`
- `LastHomeShared.addRoleItems(inv, bagItem, bagItemId, items, bagContents)`
- `LastHomeShared.applyRoleStats(player, stats)`
- `LastHomeShared.isPassivePerk(perk)`
- `LastHomeShared.applyPerkLevel(player, perk, level)`

Add a single high-level routine that performs the **common** role-application
body shared by both sides:

```
LastHomeShared.applyRoleCore(player, roleKey)
```

Responsibilities of `applyRoleCore` (the body that is identical today):

1. Resolve `ROLE_DEFS[roleKey]`, bail if nil.
2. Add the role bag (`def.equipped.bag`) to the inventory.
3. Distribute items via `addRoleItems`.
4. Prime the loadout via `primeRoleLoadout`.
5. Apply each skill via `applyPerkLevel`.
6. Equip items via `equipRoleItems`.
7. Apply stats via `applyRoleStats`.
8. Apply the carry profile via `applyCarryProfile`.

`applyRoleCore` does **not** touch mod-data flags (`LH_role`,
`LH_localRoleApplied`), does **not** manage `Server.assignedRoles` /
`Server.roleLoadouts`, and does **not** send commands or show UI. Those remain
the responsibility of the thin wrappers, which differ between server and
client.

### `media/lua/server/LastHomeServer.lua` — thin `applyRole`

Replace the duplicated helpers with local aliases to the shared module
(or call `LastHomeShared.*` directly). `applyRole` becomes:

- `LastHomeShared.applyRoleCore(player, roleKey)`
- then the server-specific concerns only:
  - set `modData.LH_role = roleKey`
  - if `Server.roleLoadouts[username] == roleKey` (already applied), only
    `applyCarryProfile` and return (existing guard, kept)
  - record `Server.roleLoadouts[username]` and `Server.assignedRoles[username]`

Remove the six now-duplicated local functions from the server file.

### `media/lua/client/LastHomeClient.lua` — thin `applyRoleLocally`

Replace the duplicated solo block with:

- `LastHomeShared.applyRoleCore(player, roleKey)`
- then the solo-specific concerns only:
  - set `modData.LH_role = roleKey` and `modData.LH_localRoleApplied = roleKey`
  - call `showRoleAssigned(roleName)`
  - log the "applied locally (solo)" line

Remove the six duplicated local functions and the local `ROLE_DEFS` alias from
the client file.

## Acceptance criteria

1. `LastHomeServer.lua` and `LastHomeClient.lua` contain **no** local definition
   of `addItemsToContainer`, `buildItemCounts`, `addRoleItems`, `applyRoleStats`,
   `isPassivePerk`, or `applyPerkLevel`.
2. Both `applyRole` (server) and `applyRoleLocally` (client) call
   `LastHomeShared.applyRoleCore` for the common body.
3. In-game behavior is unchanged: assigning a role in MP and in solo produces
   the same inventory, skills, stats, equipped items, and carry profile as
   before (verified against the Rambo / Sniper / Builder / Invincible roles
   which cover melee, magazine-fed firearm, two-handed weapon, and unlimited
   carry respectively).
4. The server `roleLoadouts`/`assignedRoles` tracking and the "already applied"
   guard still work (re-assigning the same role does not re-grant items).
5. The solo fallback (`applyRoleLocally`) still sets `LH_localRoleApplied` and
   shows the role-assigned halo.
6. `mod.info` version bumped.

## Files impacted

- `media/lua/shared/LastHomeShared.lua` — add the six helpers + `applyRoleCore`
- `media/lua/server/LastHomeServer.lua` — remove dups, thin `applyRole`
- `media/lua/client/LastHomeClient.lua` — remove dups, thin `applyRoleLocally`
- `specs/LH-17-deduplication-role-equipment.md` — this spec
- `README.md` — spec table
- `project-state.md` — ticket tracking
- `mod.info` — version bump

## Dependencies

- LH-02 (role system) and LH-08 (shared equipment helpers) — this ticket
  completes the extraction started in LH-08.

## Estimated size

Medium (M) — mechanical move + two thin wrappers. No gameplay logic changes.
The risk is regression on role equipment, mitigated by acceptance criterion 3
(verify the four representative roles).

## Notes

- Keep `applyRoleCore` pure (no side effects beyond the player object), so the
  server and client wrappers keep full control over state tracking and UI.
- Do not change `primeRoleLoadout` / `fillAmmoItem` (LH-14) behavior — they
  already live in the shared module and are called by `applyRoleCore`.
- If `Events.OnTick.Remove` is confirmed absent in B41 (backlog item), the solo
  fallback tick change is unrelated and out of scope here.