# LH-19 (M) — Stock communautaire : spawn au sol (approche B)

## Statut

**Implémentation en cours.** L'approche A (caisse dédiée spawnée via `IsoObject` +
`ItemContainer`) a été testée en jeu le 27-07-26 et **échoue en MP** : la caisse
est bien créée et remplie côté serveur (`Stock crate spawn` + `refillHouseSupplies:
43 types, 4496 items` dans `DebugLog-server.txt`), mais le client ne la voit pas.
Cause : le chunk de la maison est déjà chargé côté client au moment de la
téléportation ; le spawn serveur a lieu ~2s plus tard (chargement du chunk
serveur), et `AddTileObject` + `transmitModData` ne poussent **pas** un nouvel
`IsoObject` aux clients qui ont déjà le chunk. Aucun transmit server→client
fiable n'a été trouvé pour un runtime-add sur un chunk déjà chargé
(`transmitCompleteItemToServer` est client→server).

On bascule sur l'approche B : **spawn des ressources au sol** via
`square:AddWorldInventoryItem`, dont le sync server→client est natif et fiable
(c'est le chemin utilisé par les drops de zombies, le foraging, etc.).

Voir `specs/LH-18-stock-spawn-analysis.md` pour l'analyse complète (A vs B, API
PZ, trade-offs).

## Objectif

Déposer le stock communautaire (**nourriture + bouteilles d'eau + munitions**)
au sol, près du spawn de la maison, une fois au début du scénario, pour que le
groupe le récupère directement. Plus de conteneur de stock, plus de problème
de capacité (poubelle surchargée) ni de sync de world-object.

## Non-goals

- Garder le remplissage périodique du stock communautaire (toutes les 10 min).
  Le stock au sol est **ponctuel** (un spawn unique) ; le refill continu du
  **Builder** (inventaire, toutes les 10 min) reste inchangé.
- Spawner un conteneur monde (approche A, abandonnée).

## Architecture

### 1. Spawn au sol, one-shot

`LastHomeServer.spawnStockOnGround(house)` :

- Garde d'idempotence : `Server.stockGroundSpawned` (bool). Si déjà fait,
  retourne `true` sans rien refaire.
- Récupère le carré de spawn via `cell:getGridSquare(stockSpawn.x, .y, .z)`.
  Si `nil` (chunk non chargé) → retourne `false` (l'appelant retrye, comme
  aujourd'hui via `processPostSpawnMaintenance`).
- Pour chaque entrée de `COMMUNITY_STOCK_ITEMS` : `count = baseCount *
  HOUSE_SUPPLY_MULTIPLIER`, appelle `square:AddWorldInventoryItem(itemId, offX,
  offY, 0)` `count` fois (`itemId` accepte un fulltype string, cf.
  `ClientCommands.lua:257`).
- Répartit les types sur le carré de spawn + ses voisins (3×3) pour éviter
  ~4500 world-items sur un seul tile (rendu/lag). Round-robin par type.
- Set `Server.stockGroundSpawned = true`, log `Stock au sol spawn: N items sur M
  carres a (x,y,z) pour <house>`.
- `AddWorldInventoryItem` sync nativement server→client (world-inventory
  packet) → le client voit les items apparaître, même sur un chunk déjà chargé.

`ensureStockOnGround(house)` = wrapper idempotent (retourne `true` une fois
spawné / déjà fait, `false` si chunk non chargé).

### 2. Coordonnées de spawn (à fournir par l'hôte)

Le carré où déposer le stock. Par défaut on réutilise `house.supply` (école :
`(10616, 9971, 0)`), mais l'hôte peut vouloir un endroit plus dégagé (pas sur la
poubelle). **L'hôte fournira les coordonnées par maison** — à inscrire soit
dans `LastHomeShared.HOUSE_DEFS[].stockSpawn`, soit en réutilisant `supply`.

| Maison | `stockSpawn` (TBD par l'hôte) |
|---|---|
| hospital | TBD |
| villa | TBD |
| prison | TBD |
| elementary_school | `(10616, 9971, 0)` (réutilise `supply`) ou TBD |

Tant que les coords ne sont pas fournies, on retombe sur `house.supply`.

### 3. Volume

- `COMMUNITY_STOCK_ITEMS` = 38 types, 182 unités de base, × `HOUSE_SUPPLY_MULTIPLIER`
  (8) = **1456 items**.
- 1456 `IsoWorldInventoryObject` reste significatif (rendu, sauvegarde). Le spread 3×3
  aide (≈ 500/tile) mais le total reste élevé.
- Réglage : baisser `HOUSE_SUPPLY_MULTIPLIER` (8 → 2-3) si lag constaté en jeu.
  Le Builder inventory refill compense côté ressources continues.
- Pas de refill au sol périodique (sinon accumulation infinie).

### 4. Suppressions (approche A)

Retirer du serveur :
- `findStockContainerOnSquare`, `ensureStockContainerSpawned`,
  `getPrimaryHouseSupplyContainer`, `refillHouseSupplies`,
  `refillHouseSuppliesIfNeeded`.
- `Server.stockSpawnFailed` → remplacé par `Server.stockGroundSpawned`.
- Les constantes `LastHomeShared.LH_STOCK_SPRITE` / `LH_STOCK_CONTAINER_TYPE` /
  `LH_STOCK_CAPACITY` (approche A).

### 5. Points d'appel

Remplacer les appels `refillHouseSuppliesIfNeeded()` / `ensureStockContainerSpawned()`
par `ensureStockOnGround(house)` :
- `teleportPlayerToHouse` (après TP — déclenche le spawn dès que le chunk
  charge).
- `processPostSpawnMaintenance` (retry jusqu'à chunk chargé).
- `setSelectedHouse` (au choix de la maison).
- `onBuilderRefillTick` (le cycle 10 min : `refillBuilderResources` reste ;
  `refillHouseSuppliesIfNeeded` → `ensureStockOnGround`, no-op après le 1er
  spawn).

### 6. LH-15 (flèche de stock)

`drawStockArrow` pointe sur `house.supply`. Avec le stock au sol, la flèche
pointe sur le carré de spawn (les items sont visibles au sol). À conserver tel
quel, ou la retirer si le stock au sol est assez visible. Décision en attente
(test en jeu). La flèche se masque à < 3 tiles du carré — OK.

## API PZ confirmée (référence)

- `square:AddWorldInventoryItem(itemOrFullType, offsetX, offsetY, rot)` —
  spawn d'un item monde au sol. Accepte un fulltype string **ou** un
  `InventoryItem`. Sync natif server→client. (`ClientCommands.lua:257`,
  `SCampfireGlobalObject.lua:141`, `STrapGlobalObject.lua:444`.)
- `InventoryItemFactory.CreateItem(fullType)` / `instanceItem(fullType)` —
  crée un `InventoryItem` hors-monde (utile si on veut setter des props avant de
  poser).

## Fichiers impactés

- `media/lua/server/LastHomeServer.lua` — remplacer la logique container (A) par
  `spawnStockOnGround` + `ensureStockOnGround` ; ajuster les points d'appel ;
  reset `Server.stockGroundSpawned` ; utiliser `COMMUNITY_STOCK_ITEMS` pour le stock.
- `media/lua/shared/LastHomeShared.lua` — retirer `LH_STOCK_SPRITE`/`TYPE`/
  `CAPACITY` ; ajouter `stockSpawn` par maison (coords fournies par l'hôte) ;
  éventuellement baisser `HOUSE_SUPPLY_MULTIPLIER`.
- `media/lua/shared/LastHomeRoles.lua` — introduire `COMMUNITY_STOCK_ITEMS`
  (nourriture, eau, munitions) séparé de `BUILDER_REFILL_ITEMS`.
- `media/lua/client/LastHomeClient.lua` — `drawStockArrow` (LH-15) à conserver
  ou retirer selon test.
- `specs/LH-19-stock-ground-spawn.md` (ce fichier), `README.md`,
  `project-state.md`.

## Critères d'acceptation

1. En jeu MP Host (école), après téléportation, le stock apparaît **au sol**
   près du spawn et est **visible côté client** (sync natif world-inventory).
2. Plus de conteneur de stock / poubelle surchargée.
3. Le spawn est ponctuel (un seul spawn par scénario) ; pas d'accumulation.
4. Le Builder conserve son refill d'inventaire toutes les 10 min.
5. Re-host dans le même process : le reset efface `stockGroundSpawned` → re-spawn
   au prochain scénario.
6. Si les coords `stockSpawn` ne sont pas fournies, fallback sur `house.supply`.
7. La flèche LH-15 pointe sur le carré de stock (ou est retirée si redondante).

## Pièges

- 1456 world-items reste non trivial. Surveiller le lag ; réduire le
  multiplicateur si besoin.
- Ne PAS appeler `AddWorldInventoryItem` avant que le chunk soit chargé
  (`getGridSquare` nil) — retry via le tick.
- Ne PAS réactiver un refill périodique au sol (accumulation).
- `AddWorldInventoryItem` avec un fulltype invalide → peut throw ou ignorer ;
  wrapper dans pcall si besoin.

## Dépendances

- LH-MP-6 (mod MP, `SCENARIO_HOUSE` hardcodé, bootstrap `OnServerStarted`).
- LH-18 (analyse A vs B + API PZ).

## Supersedes

- L'approche A (caisse dédiée) de LH-18 — testée, sync MP échoué, abandonnée.

## Size estimate

**M** — remplace la logique container par un spawn au sol one-shot + spread,
ajuste les points d'appel, retire les constantes A, récupère les coords de
l'hôte.