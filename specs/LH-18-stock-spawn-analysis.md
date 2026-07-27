# LH-18 (analysis → implémentation approche A) — Stock communautaire

> Statut : **approche A en test** (branche `feat/lh-18-stock-container`). Si le
> sync MP du conteneur spawné ne fonctionne pas, on basculera sur l'approche B
> (spawn au sol). Investigation initiale sauvée ci-dessous pour référence.

## Rappel du problème

- Le stock communautaire est injecté via `LastHomeServer.refillHouseSupplies()` →
  `getPrimaryHouseSupplyContainer()` → `Container:AddItems(itemId, count)`.
- Volume : `BUILDER_REFILL_ITEMS` = 43 types, 562 unités de base, ×
  `HOUSE_SUPPLY_MULTIPLIER` (8) = **4496 items** dans **un seul** conteneur.
- Pour l'école, `house.supply = (10616, 9971, 0)` pointe vers une **poubelle**
  (conteneur map). Les coords sont correctes (aucune ligne "fallback supply" en
  jeu → le carré configuré a bien un conteneur).
- `Container:AddItems` **ne respecte pas la capacité** du conteneur : les 4496
  items sont ajoutés au-delà. Donc ça "fonctionne" (log : `refillHouseSupplies:
  43 types, 4496 items ajoutes`) mais la poubelle est surchargée → UX mauvaise
  (inventaire illisible, lag potentiel à l'ouverture).
- En challenge (solo) le même code/capacity débordait aussi (log 25-07 :
  même refill 4496 items). Non remarqué car le joueur spawnait **à l'école**.

### Côté serveur ou client ?

**Serveur.** `getPrimaryHouseSupplyContainer` + `refillHouseSupplies` sont dans
`media/lua/server/LastHomeServer.lua` (VM serveur). Log dans
`DebugLog-server.txt`. Aucune logique de remplissage côté client.

### Pourquoi des WARN "aucun conteneur trouve" en MP mais pas en challenge

Ce n'est **pas** un bug de détection — c'est un délai de chargement de chunk :

| | Challenge (solo) | MP Host |
|---|---|---|
| Spawn joueur | directement à l'école → chunk chargé tout de suite | point MP par défaut (10872,9489) → chunk école non chargé |
| 1er scan | trouve la poubelle immédiatement | WARN (chunk absent) |
| Refill | immédiat | ~5s après téléportation (post-spawn maintenance, retry 2s ×8) |

Log 27-07 14:11 : WARN à 14:11:10/44/49, puis succès à **14:11:54**
(`refillHouseSupplies: 43 types, 4496 items`). Donc **ça fonctionne en MP**,
juste retardé et bruyant. Le `processPostSpawnMaintenance` gère le délai.

### La bonne fonction pour remplir ?

`Container:AddItems(itemId, count)` / `Container:AddItem(itemId)` est la bonne
API PZ côté serveur. Elle a fonctionné. **Mais elle bypass la capacité** —
n'applique pas la limite de poids/slots du conteneur.

## Deux approches pour corriger la capacité

### Approche A — Spawner un conteneur dédié (caisse)

Pattern PZ canonique (cf. `media/lua/server/Camping/SCampfireGlobalObject.lua`,
`ISWoodenContainer.lua`) :

```lua
local cell = getCell()
local square = cell:getGridSquare(x, y, z) or cell:getOrCreateGridSquare(x, y, z)
local isoObject = IsoObject.new(square, "carpentry_02_53", "LastHomeStock")  -- sprite caisse
local container = ItemContainer.new("crate", square, isoObject, 1000, 1000)  -- type, sq, parent, cap, maxCap
container:setExplored(true)
isoObject:setContainer(container)
isoObject:getModData().LH_stockContainer = true   -- marqueur de détection
square:AddTileObject(isoObject)
isoObject:transmitModData()                       -- sync MP
```

- `getPrimaryHouseSupplyContainer` cherche d'abord l'objet avec
  `modData.LH_stockContainer == true` ; fallback = logique actuelle
  (premier conteneur / scan boundary).
- Spawn **déféré** jusqu'à ce que le chunk de la maison soit chargé (réutiliser
  le tick `processPostSpawnMaintenance` ou un tick dédié) — comme pour le
  refill, ne pas spawner au bootstrap (chunk absent).
- Persistance : vérifier le marqueur avant de spawner (éviter les doublons au
  re-host/refill). L'objet est persisté dans la save avec le chunk.
- `house.supply` = carré du crate → la flèche LH-15 pointe dessus.
- Capacité : `ItemContainer.new("crate", sq, obj, 1000, 1000)` (grande). Comme
  `AddItems` bypass la capacité, le remplissage marche pareil ; la capacité
  haute sert seulement si le joueur veut y déposer des items.

**Sprite caisse** : `carpentry_02_53` (caisse en bois, confirmée dans
`Trailer2Scenario.lua` et `MORainCollectorBarrel.lua`). Alternatives :
`carpentry_02_52`, `furniture_containers_01_*`.

**Risques** : spawn de world-object en MP (sync, persistance) — non testé.
L'approche campfire (`AddTileObject` + `transmitModData`) est éprouvée côté
serveur. À valider en jeu.

### Approche B — Spawner les ressources au sol (recommandée par l'hôte, plus simple)

Pattern PZ (cf. `ClientCommands.lua`, `SCampfireGlobalObject.lua:141`,
`STrapGlobalObject.lua`) :

```lua
local square = cell:getGridSquare(x, y, z)
square:AddWorldInventoryItem("Base.Plank", 0.0, 0.0, 0.0)   -- accepte un fulltype string
-- ou avec un item construit :
-- local item = InventoryItemFactory.CreateItem("Base.Plank")
-- square:AddWorldInventoryItem(item, 0.5, 0.5, 0)
```

- `square:AddWorldInventoryItem(itemOrFullType, offsetX, offsetY, rot)` —
  serveur, auto-sync clients (world items stream avec le chunk).
- Beaucoup plus simple : pas de `IsoObject`/`ItemContainer`/`setContainer`,
  pas de marqueur, pas de sync manuel, pas de capacité.
- **Attention perf** : 4496 `IsoWorldInventoryObject` sur un carré = lourd
  (rendu, stream, sauvegarde). Les items d'un même type s'empilent visuellement
  mais restent des objets distincts.
  - Mitigation : réduire le volume (`HOUSE_SUPPLY_MULTIPLIER` 8 → 2-3, ou
    réduire `BUILDER_REFILL_ITEMS`), et/ou répartir sur plusieurs carrés voisins
    (le `boundary` de l'école = 35×43), et/ou n spawner qu'une fois au début du
    scénario (pas de refill toutes les 10 min qui rajoute au sol).

**Avantages** : pas de conteneur à trouver/gérer, plus de problème de
capacité, visible immédiatement par le joueur, fiable en MP (les world items
sont un mécanisme natif et bien syncé). Supprime le besoin de
`getPrimaryHouseSupplyContainer` et de la flèche LH-15 (ou la flèche pointe
vers le carré de spawn au sol).

**Inconvénients** : volume à calibrer (perf), pas de "refill" propre (le sol
se remplit), items éparpillés, nettoyage éventuel.

## Recommandation (à valider)

Approche **B (spawn au sol)** avec :
- Réduction du volume : `HOUSE_SUPPLY_MULTIPLIER` 8 → 2 (≈ 1124 items) ou
  ajuster `BUILDER_REFILL_ITEMS` pour un kit de départ raisonnable.
- Spawn unique au début du scénario (après téléportation, chunk chargé), pas de
  refill périodique au sol (le Builder garde son refill **inventaire**).
- Répartir sur 1-3 carrés voisins du spawn (pas 4496 sur un seul).
- Désactiver/adapter LH-15 (flèche stock) → pointer vers le carré de spawn au
  sol, ou retirer la flèche si le stock est visible au sol.

Si l'hôte préfère un conteneur propre (inventaire rangeable, refill toutes les
10 min), approche **A** (caisse dédiée) — plus de code, à valider en jeu pour
la sync MP.

## API PZ confirmées (référence)

- `IsoObject.new(square, spriteName, name?)` — crée un IsoObject sur un carré
  avec un sprite. (`SCampfireGlobalObject.lua:79`)
- `ItemContainer.new(type, square, parent, capacity, maxCapacity)` — crée un
  conteneur. Types vus : `"campfire"`, `"crate"`, `"kitchen"`, `"bathroom"`,
  `"bedroom"`, `"shed"`, `"floor"`. (`SCampfireGlobalObject.lua:107`,
  `ISInventoryPage.lua:1305` floor `(10,10)`)
- `isoObject:setContainer(container)` + `square:AddTileObject(isoObject)` (+
  `AddSpecialObject` pour les buildables).
- `isoObject:transmitModData()` — sync modData serveur→clients.
- `square:AddWorldInventoryItem(itemOrFullType, offX, offY, rot)` — spawn d'un
  item monde au sol, auto-sync clients. (`ClientCommands.lua:257`,
  `SCampfireGlobalObject.lua:141`)
- `InventoryItemFactory.CreateItem(fullType)` / `instanceItem(fullType)` —
  crée un `InventoryItem` hors-monde.
- `Container:AddItem(fullType)` / `AddItems(fullType, count)` — ajoute à un
  conteneur existant, **bypass la capacité**.

## Fichiers impactés ( whichever approach )

- `media/lua/server/LastHomeServer.lua` — `getPrimaryHouseSupplyContainer`,
  `refillHouseSupplies`, `processPostSpawnMaintenance` (timing chunk).
- `media/lua/shared/LastHomeRoles.lua` — `BUILDER_REFILL_ITEMS` (volume).
- `media/lua/shared/LastHomeShared.lua` — `HOUSE_SUPPLY_MULTIPLIER`,
  `house.supply` coords.
- `media/lua/client/LastHomeClient.lua` — `drawStockArrow` (LH-15) à adapter ou
  retirer.
- `project-state.md`, `README.md`.

## Décision en attente

- Approche A (caisse dédiée) vs B (spawn au sol).
- Volume cible (multiplier / liste) si approche B.
- Garder LH-15 (flèche) ou non.
- Garder le refill périodique (10 min) ou spawn unique.

## Size estimate

**M** — soit (A) spawn de world-container + détection par marqueur +
validation sync MP, soit (B) spawn au sol + recalibrage volume + adaptation
LH-15.