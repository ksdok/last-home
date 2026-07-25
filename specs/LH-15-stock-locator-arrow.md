# LH-15 (S) - Last Home: Flèche du stock à l'écran

## Contexte

Le conteneur de stock communautaire (`house.supply`) est injecté dans un
conteneur vanilla par maison. Les joueurs ne savent pas facilement où il se
trouve, surtout la première fois dans un lieu.

Le client reçoit déjà `state.house.supply.x/y/z` dans le `WaveState`
(préservé par `cloneHouse` + envoyé par `syncWaveState`).

## Objectif

Afficher une **flèche à l'écran** pointant vers le stock, avec la distance,
visible à travers les murs, pendant la prep et les vagues.

## Changements

### `media/lua/client/LastHomeClient.lua` — `drawStockArrow`

Nouvelle fonction branchée sur `Events.OnPostUIDraw` :

- Récupère `state.house.supply` (fallback sur le centre de la maison).
- Distance 2D joueur→stock (`IsoUtils.DistanceTo2D` ou calcul manuel).
- Si `dist < 3` tiles → pas de flèche (joueur sur le stock).
- Projection monde→écran via `IsoUtils.XToScreenExact/YToScreenExact`
  (déjà caméra-adjustées : `XToScreen − IsoCamera.getOffX`).
- Si le stock est **à l'écran** : marqueur `v <dist>m` au-dessus du conteneur.
- Si le stock est **hors écran** : clamp à l'edge le long de la ligne
  centre→stock, flèche cardinale (`^ v < >`) + distance.
- Texte centré via `TextManager:DrawStringCentre(UIFont.Medium, ...)`,
  ombre noire + couleur jaune.
- Désactivé en phase `idle` / `gameover` ou sans maison.

### Note sur les fonts

Les fonts bitmap PZ (`zomboidSmall/Medium.fnt`) ne contiennent **pas** les
glyphe de flèches unicode (↗↘↑↓, U+2190–2199, U+25B6/25BC). Seuls les caractères
ASCII `^ v < >` rendent de façon fiable. La flèche est donc **cardinale** (4
directions) plutôt que 8. À mettre à jour si une police unicode est utilisée.

## Critères d'acceptation

1. Pendant la prep et la vague, une flèche jaune + distance apparaît pointant
   vers le stock.
2. La flèche reste visible à travers les murs (projection écran).
3. Quand le joueur est à moins de 3 tiles du stock, la flèche disparaît.
4. Quand le stock est visible à l'écran, un marqueur `v` apparaît au-dessus du
   conteneur.
5. Désactivé hors partie active (idle/gameover) ou sans maison.

## Fichiers impactés

- `media/lua/client/LastHomeClient.lua` — `drawStockArrow` + registration
- `specs/LH-15-stock-locator-arrow.md` — nouvelle spec
- `README.md` — table des specs
- `project-state.md` — ticket + note
- `mod.info` — bump version

## Dépendances

- Dépend de LH-04 (`house.supply` par maison, sync client)
- Dépend de LH-06 (HUD client, `Events.OnPostUIDraw`)

## Taille estimée

Small (S) — fonction client pure, réutilise le state sync existant.