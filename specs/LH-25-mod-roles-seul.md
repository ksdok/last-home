# LH-25 (M) - Mod séparé : choix de rôle seul (role picker standalone)

## Contexte

Le système de rôles de Last Home (définitions + picker + application de
loadout) est la partie la plus autonome du mod. L'hôte wants un **nouveau mod
séparé** qui ne fournit **que le choix de rôle** : les joueurs spawn normalement
(vanilla), choisissent un rôle via le picker, et reçoivent l'équipement, les
skills et les stats du rôle. **Pas de maison, pas de téléportation, pas de
vagues, pas de stock, pas de confinement, pas de bootstrap maison.**

Le set de rôles est **hybride** : rôles vanilla par défaut + rôles Brita
(LH-22 agent + LH-23 relook) si les packs Brita/Arsenal sont détectés au
runtime.

## Objectif

Créer un nouveau mod Workshop-style (dossier dédié, `mod.info`, `id` distinct)
qui extrait et simplifie le sous-système de rôles de Last Home :

- au spawn (solo ou MP), le picker s'ouvre ;
- le joueur choisit un rôle (doublons autorisés) ;
- le rôle est appliqué : items (inventaire + sac), skills, stats, équipement
  (primary/bag/clothes), carry profile, priming des armes à feu ;
- persistance du rôle via `modData.LH_role` (rejoin → restauration) ;
- détection runtime de Brita → set de rôles Brita ; sinon set vanilla.

**Retiré** vs Last Home : `teleportPlayerToHouse`, `notifyWavesRoleAssigned`,
`ensureScenarioStarted`, `setSelectedHouse`, stock au sol, confinement, Builder
refill 10 min, bootstrap `OnServerStarted`, sandbox vars.

## Décisions (validées par l'hôte)

- **Mod séparé** : nouveau dossier, `mod.id` distinct (proposition :
  `id=LastHomeRoles`, name `Last Home - Roles` — ajustable).
- **Spawn vanilla** : pas de TP, pas de maison. Les joueurs apparaissent
  normalement et choisissent un rôle.
- **Set hybride** : rôles vanilla par défaut + rôles Brita si Brita/Arsenal
  détectés au runtime.
- **Builder refill 10 min retiré** (c'était une feature liée aux vagues).
  Builder conserve `setUnlimitedCarry` (via `ROLE_CARRY_CAPACITY`).

## Architecture du nouveau mod

```
<new-mod>/
  mod.info
  media/lua/
    shared/
      LastHomeRolesShared.lua   -- helpers de loadout extraits (applyCarryProfile,
                                -- primeRoleLoadout, equipRoleItems, addRoleItems,
                                -- buildItemCounts, applyRoleStats, applyPerkLevel,
                                -- applyManualTeleportState, fillAmmoItem,
                                -- resolveSecondaryEquipItem, isPassivePerk,
                                -- forEachContainerItemRecursive, round, getNowSeconds)
      LastHomeRoles.lua          -- ROLE_DEFS_VANILLA + ROLE_DEFS_BRITA + ROLE_ORDER/
                                -- ROLE_NAMES/ROLE_INFO + ROLE_CARRY_CAPACITY +
                                -- BUILDER_REFILL_ITEMS (inutilisé ici) + COMMUNITY_STOCK
                                -- (inutilisé ici). Sélection du set actif à la demande.
    client/
      LastHomeRolePicker.lua    -- copie adaptée du picker (sans dépendance Last Home)
      LastHomeRolesClient.lua   -- requestRolePicker (solo + MP), RoleAssigned handler,
                                -- applyRoleLocally, showRoleAssigned, tick retry.
                                -- PAS de applyRoleAssignedTeleport.
    server/
      LastHomeRolesServer.lua   -- RolePickerReady, ChooseRole, applyRole (sans TP,
                                -- sans notifyWaves), restoreAssignedRole (sans TP),
                                -- sendRoleAssigned, détection Brita.
```

## Changements détaillés

### 1. Extraction des helpers (`LastHomeRolesShared.lua`)

Copier depuis `LastHomeShared.lua` les fonctions de loadout (pures, sans
dépendance maison/boundary) :
`applyCarryProfile`, `primeRoleLoadout`, `equipRoleItems`, `addRoleItems`,
`buildItemCounts`, `applyRoleStats`, `applyPerkLevel`, `applyManualTeleportState`,
`fillAmmoItem`, `resolveSecondaryEquipItem`, `isPassivePerk`,
`forEachContainerItemRecursive`, `round`, `getNowSeconds`, et le
`ROLE_CARRY_CAPACITY`. Renommer le module global en `LastHomeRolesShared` (ou
garder `LastHomeShared` pour minimiser les diffs — décision d'implémentation).

### 2. Définitions de rôles (`LastHomeRoles.lua`)

Deux tables :
- `ROLE_DEFS_VANILLA` : les 17 rôles tels qu'ils sont aujourd'hui dans Last Home
  (avant LH-22/LH-23) — équipement vanilla.
- `ROLE_DEFS_BRITA` : les 17 rôles relookés Brita (LH-23) + le rôle `agent`
  (LH-22) — équipement Brita/Arsenal. **Dépend de l'implémentation de LH-22 et
  LH-23** dans Last Home (les blocs finalisés existent dans les specs ; à copier
  une fois implémentés, ou à autoriser directement depuis les specs).

Une fonction `getActiveRoleDefs()` renvoie l'un ou l'autre selon la détection
Brita (cache du résultat après première détection).

### 3. Détection Brita au runtime

Dans `LastHomeRolesServer.lua` (côté serveur, autoritaire) :

```lua
local function isBritaInstalled()
    local sm = getScriptManager()
    if sm == nil or sm.getItem == nil then return false end
    -- PPK est un item Arsenal(26) GunFighter (module Base), absent du vanilla.
    return sm:getItem("Base.PPK") ~= nil
end
```

Côté client, même détection (le picker a besoin du set actif pour afficher les
noms/descriptions). La détection se fait **au runtime** (à la première demande
du picker), pas au chargement du fichier (les scripts Brita peuvent charger
après notre lua).

> Note : `getScriptManager():getItem("Base.PPK")` — vérifier l'API exacte en
> B41 (`getScriptManager()` global vs `ScriptManager.instance`). Fallback :
> itérer sur un petit set d'IDs Brita connus (`Base.PPK`, `Base.M4A1`,
> `Base.Suit_Wick`).

### 4. Flow d'assignation (sans maison/vagues)

**Client** (`LastHomeRolesClient.lua`) :
- `OnCreatePlayer` / `OnGameStart` → `requestRolePicker()` :
  - solo : appelle directement `LastHomeRolesServer.applyRole` local ? Non —
    en solo, le picker s'ouvre localement puis `applyRoleLocally` applique.
  - MP : `sendClientCommand("LastHomeRoles", "RolePickerReady", {})` + retry
    3 s (comme Last Home).
- `OpenRolePicker` (commande serveur) → ouvre le picker.
- `onChooseRole(roleKey)` → `sendClientCommand("LastHomeRoles", "ChooseRole",
  {role = roleKey})` (MP) / `applyRoleLocally` (solo).
- `RoleAssigned` (commande serveur) → `applyRoleLocally(player, role)` (PAS
  de `applyRoleAssignedTeleport`).

**Serveur** (`LastHomeRolesServer.lua`) :
- `RolePickerReady` → si `modData.LH_role` existe → `sendRoleAssigned`
  (restauration) ; sinon `sendServerCommand("LastHomeRoles", "OpenRolePicker",
  {})`.
- `ChooseRole` → `applyRole(player, roleKey)` (items server-side tracking +
  `modData.LH_role`, skills, stats, carry ; en MP les items sont appliqués
  côté client via `applyRoleLocally` pour la robustesse sync) →
  `sendRoleAssigned(username, roleKey)`. **Pas de `teleportPlayerToHouse`,
  pas de `notifyWavesRoleAssigned`, pas de `ensureScenarioStarted`.**
- `restoreAssignedRole(player)` → `applyRole(player, persistedRole)` (PAS de
  TP).

### 5. `applyRole` simplifié

Copier `applyRole` de Last Home en retirant :
- l'appel à `teleportPlayerToHouse` ;
- le `spawn = pickHouseSpawnPoint(...)` ;
- le `schedulePostSpawnMaintenance` / `spawnStockOnGround` ;
- le `notifyWavesRoleAssigned`.

Garder : `modData.LH_role = roleKey`, `applyPerkLevel` (skills),
`applyRoleStats`, `applyCarryProfile` (unlimitedCarry pour builder/rambo/etc.
selon le set), et le tracking serveur du loadout (pour la restauration).

### 6. `mod.info`

```
name=Last Home - Roles
id=LastHomeRoles
poster=poster.png
description=Standalone role picker (extracted from Last Home). Choose a role at spawn, get its loadout. Vanilla roles by default, Brita roles if Brita's Weapon+Armor Packs (and Arsenal GunFighter) are installed.
```

Pas de `require=` (Brita est optionnel — détection runtime).

### 7. Sandbox vars / bootstrap

**Aucun bootstrap** : pas de `OnServerStarted` qui applique des sandbox vars,
pas de suppression de zombies vanilla. Le mod est purement additif : il
n'altère pas la population zombie ni la carte. Les joueurs jouent une partie
vanilla (ou avec d'autres mods) et choisissent juste un rôle.

## Fichiers impactés / créés

- Nouveau dossier `<new-mod>/` (proposition : `~/Documents/Zomboid/last-home-roles/`)
- `mod.info`, `poster.png` (placeholder)
- `media/lua/shared/LastHomeRolesShared.lua`, `LastHomeRoles.lua`
- `media/lua/client/LastHomeRolePicker.lua`, `LastHomeRolesClient.lua`
- `media/lua/server/LastHomeRolesServer.lua`
- `README.md` (nouveau mod)
- `specs/LH-25-mod-roles-seul.md` (cette spec, dans last-home)

## Critères d'acceptation

1. Le mod s'active seul (sans Last Home) dans une partie solo sandbox et MP
   Host ; pas d'erreur de chargement.
2. Au spawn, le picker s'ouvre (solo : local ; MP : via `RolePickerReady` +
   retry).
3. Le joueur choisit un rôle → reçoit items (inventaire + sac), skills, stats,
   équipement (primary/bag/clothes), carry profile, armes à feu chargées
   (priming).
4. **Pas de téléportation** : le joueur reste à son spawn vanilla.
5. **Pas de vagues, pas de stock, pas de confinement, pas de modification des
   zombies vanilla.**
6. Détection Brita : sans Brita → set vanilla (17 rôles, items vanilla) ;
   avec Brita/Arsenal → set Brita (17 relookés + agent, items Brita). Le picker
   affiche le bon set.
7. Rejoin MP : le rôle est restauré (items/skills/stats) sans TP.
8. Builder a `setUnlimitedCarry` ; pas de refill 10 min (retiré).
9. Doublons de rôles autorisés (plusieurs joueurs peuvent prendre le même).
10. Aucune dépendance `require=` à Brita dans `mod.info` (Brita optionnel).

## Questions en attente

- **Set Brita dépend de LH-22/LH-23** : les blocs Brita finalisés existent dans
  les specs mais ne sont pas encore implémentés dans Last Home. Le nouveau mod
  peut (a) attendre l'implémentation de LH-22/LH-23 puis copier les blocs, ou
  (b) autoriser les blocs Brita directement depuis les specs. Décision
  suggérée : (b) — les specs sont finalisées, on copie les blocs.
- **Nom/ID du mod** : `Last Home - Roles` / `id=LastHomeRoles` ? À confirmer.
- **API détection Brita** : `getScriptManager():getItem("Base.PPK")` à valider
  en B41 (signature exacte). Fallback multi-items.
- **Séparation du code** : faut-il dupliquer le code (copie dans le nouveau
  mod) ou le partager via un `require` vers last-home (qui serait alors une
  dépendance) ? Décision suggérée : **dupliquer** (mod vraiment standalone, pas
  de dépendance à last-home).
- **Builder refill** : confirmé retiré (choix hôte « Rôles seuls, spawn
  vanilla »).
- **`modData.LH_role`** : conserver le même namespace que Last Home
  (`LH_role`) permet à un joueur de basculer entre les deux mods sans perdre
  son rôle, mais crée un couplage implicite. Décision suggérée : namespace
  propre au nouveau mod (ex. `LR_role`) pour éviter toute interférence.

## Décisions

- Mod séparé, standalone (code dupliqué, pas de `require` vers last-home).
- Spawn vanilla, pas de maison/TP/vagues/stock/confinement/bootstrap.
- Set hybride vanilla + Brita (détection runtime).
- Builder refill retiré ; `setUnlimitedCarry` conservé.
- Détection Brita au runtime via `getScriptManager():getItem(...)`.
- Namespace `modData` propre au nouveau mod.

## Dépendances

- Réutilise le sous-système de rôles de Last Home (LH-02, LH-08, LH-14, LH-17)
- Set Brita : LH-22 (agent + Brita requis) + LH-23 (relook 10 rôles) — blocs
  finalisés dans les specs
- Brita's Weapon Pack (2200148440) + Arsenal(26) GunFighter (2297098490)
  + Brita's Armor Pack (2460154811) — **optionnels** (détection runtime)

## Taille estimée

Medium (M) — 5 fichiers à créer (3 extraits/adaptés de Last Home, 2 réécrits
pour stripper maison/vagues), 1 `mod.info`, 1 README. Le cœur (rôles + helpers
+ picker) se copie ; l'effort principal est la réécriture du flow d'assignation
(retirer teleport/notifyWaves/ensureScenarioStarted) + la détection Brita +
le double set de rôles. Risque : sync MP de l'application des items (déjà géré
par `applyRoleLocally` côté client dans Last Home — à réutiliser).