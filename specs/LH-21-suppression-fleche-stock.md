# LH-21 (S) - Last Home : supprimer la flèche du stock communautaire

## Contexte

LH-15 a ajouté une **flèche à l'écran** (`drawStockArrow`) qui pointe vers
l'emplacement du stock communautaire avec la distance en mètres, visible à
travers les murs. À l'origine, le stock était injecté dans un conteneur vanilla
dédié, et la flèche aidait les joueurs à le localiser.

Depuis LH-19, le stock communautaire est un **spawn au sol one-shot**
(`AddWorldInventoryItem`) près de `house.stockSpawn` / `house.supply`, réduit à
nourriture + eau + munitions. La flèche n'est plus jugée nécessaire et l'hôte
souhaite la supprimer.

## Objectif

Retirer la flèche à l'écran pointant vers le stock communautaire. Aucun autre
élément du HUD ne doit être affecté (le timer de vague `drawWaveHud` reste
intact). Le système de stock (spawn au sol LH-19, données `house.stockSpawn` /
`house.supply` / `getHouseStockSpawn`) reste en place — seule la **visualisation
flèche** disparaît.

## Changements

### 1. Supprimer la fonction `drawStockArrow` et son inscription

Dans `media/lua/client/LastHomeClient.lua`, supprimer :

- la fonction `local function drawStockArrow()` (et tout son corps) ;
- l'inscription `Events.OnPostUIDraw.Add(drawStockArrow)`.

C'est la totalité du périmètre fonctionnel. La fonction est autonome et n'est
appelée nulle part ailleurs.

### 2. Ne pas toucher aux données du stock

Conserver intégralement :

- `house.stockSpawn` / `house.supply` dans `LastHomeShared.lua` (définitions des
  maisons) — toujours utilisés par le spawn au sol LH-19 ;
- `getHouseStockSpawn(...)` (shared) — toujours utilisé par le spawn au sol ;
- le state `LastHomeClient.waveState.house` — toujours consommé par
  `drawWaveHud` et la logique de confinement.

Aucune de ces données ne doit être supprimée : la flèche en était seulement
consommatrice.

### 3. Nettoyer les références documentaires

- `README.md` : marquer la ligne LH-15 comme ❌ supprimée par LH-21 (ou la garder
  comme historique avec une note "supprimée par LH-21").
- `project-state.md` : ajouter LH-21 dans les specs et le backlog ; noter que
  LH-15 est superseded par LH-21 (la fonctionnalité est retirée, pas étendue).
- `specs/LH-15-stock-locator-arrow.md` : laisser en place (historique), ne pas
  modifier.

## Fichiers impactés

- `media/lua/client/LastHomeClient.lua` — suppression de `drawStockArrow` + son
  `Events.OnPostUIDraw.Add`
- `specs/LH-21-suppression-fleche-stock.md` (cette spec)
- `README.md` — table des specs (LH-15 marquée supprimée, LH-21 ajoutée)
- `project-state.md` — specs + backlog (LH-21, note LH-15 superseded)

## Critères d'acceptation

1. Plus aucune flèche / marqueur `v` / flèche cardinale à l'écran pointant vers
   le stock, en prep comme en vague.
2. Le HUD de vague (`drawWaveHud` : timer MM:SS, phase, directions, score,
   confinement) reste intact et inchangé.
3. Le stock communautaire continue d'apparaître au sol (LH-19) à l'emplacement
   `house.stockSpawn` / `house.supply`.
4. Aucune erreur Lua côté client au lancement ou pendant la partie liée à la
   suppression (pas de référence résiduelle à `drawStockArrow`).
5. `getHouseStockSpawn`, `house.stockSpawn` et `house.supply` restent présents
   et fonctionnels (pas de regression du spawn au sol).

## Questions en attente

- Faut-il remplacer la flèche par un autre repère visuel léger (ping HUD
  temporaire au début de la prep, ou marqueur sur la carte) ? Décision suggérée
  : **non** pour l'instant, suppression pure. Un éventuel repère de remplacement
  fera l'objet d'un ticket séparé si besoin.

## Décisions

- Suppression pure de la visualisation, pas de remplacement dans ce ticket.
- Les données du stock (`stockSpawn` / `supply` / `getHouseStockSpawn`) sont
  conservées car LH-19 en dépend.
- LH-15 reste dans l'historique des specs comme "superseded / removed by
  LH-21" (la fonctionnalité est retirée, pas réimplémentée).

## Dépendances

- Supersede LH-15 (`specs/LH-15-stock-locator-arrow.md`, `drawStockArrow`)
- Ne doit pas casser LH-19 (spawn au sol du stock communautaire)

## Taille estimée

Small (S) — suppression d'une fonction autonome + de son inscription
`OnPostUIDraw`, plus des mises à jour de docs. Aucun impact sur les données du
stock ou le reste du HUD.