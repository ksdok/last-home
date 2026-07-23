# LH-06 (S) - Last Home: Refonte HUD et position

## Contexte

Le HUD actuel de Last Home est affiché en haut à gauche de l'écran (x=20, y=120).
L'utilisateur souhaite le déplacer en haut à droite. Cette spec couvre le
repositionnement du HUD existant ainsi que l'intégration du countdown de
confinement (LH-05) dans le HUD.

## État actuel du HUD

Le HUD est dessiné par `drawWaveHud()` dans `LastHomeClient.lua` via
`Events.OnPostUIDraw`. Il affiche :

- En-tête `[Last Home]`
- Nom de la base (ex: `Base: Hôpital`)
- Phase de préparation : timer MM:SS, direction, taille estimée
- Phase de vague : timer restant, directions, zombies restants
- Game over : score final
- Mode spectateur : statut + spawn zombie
- Messages d'alerte ponctuels

Position actuelle : `x = 20, y = 120` (haut gauche)

## État actuel du HUD (post LH-05)

Les lignes de confinement (countdown/damaging) sont **déjà présentes**
dans `drawWaveHud()` depuis l'implémentation de LH-05. Ce qui reste à
faire est détaillé ci-dessous.

## Changements

### Repositionnement en haut à droite

- Le HUD est ancré en haut à droite de l'écran
- Calcul du `x` dynamique : `x = getCore():getScreenWidth() - HUD_WIDTH - 20`
  (où `HUD_WIDTH` est la largeur estimée du texte, ~280 pixels)
- `y` reste à `120` (même hauteur, juste décalé à droite)
- Toutes les lignes du HUD existant sont concernées (aucun changement de
  contenu, uniquement la position horizontale)

### Amélioration du countdown confinement (raffinement LH-05)

Les lignes de confinement existent déjà. Les améliorations suivantes
sont appliquées :

- Affichage des secondes en **entier** via `math.ceil()` (actuellement
  `%ds` affiche une valeur flottante)
- Ligne damaging : ajout d'un effet **clignotant** (alterne visible/masqué
  toutes les 0.5s)
- Ligne de retour en zone : ajout du message **« De retour dans la zone »**
  (vert, disparaît après 3s). Implémenté via un champ
  `LastHomeClient.boundaryReturnedAt` (timestamp absolu).

## Architecture technique

### Fichiers impactés

- `media/lua/client/LastHomeClient.lua`
  - Modification de `drawWaveHud()` : calcul dynamique du `x` pour ancrage
    à droite
  - Ajout du message « De retour dans la zone » (vert, 3s) via
    `LastHomeClient.boundaryReturnedAt`
  - Ajout du clignotement pour l'état `damaging`
  - Utilisation de `math.ceil()` pour l'affichage des secondes du countdown
  - Initialisation de `boundaryReturnedAt` dans l'état initial
  - Détection du retour en zone dans `updateBoundaryState()` (quand le
    statut passe de `countdown`/`damaging` à `inside`)

### Calcul de position

```lua
local HUD_WIDTH = 280
local screenW = getCore():getScreenWidth()
local x = screenW - HUD_WIDTH - 20
local y = 120
```

- `getCore():getScreenWidth()` est l'API vanilla PZ B41 pour la largeur d'écran
- Le HUD s'adapte aux différentes résolutions

## Critères d'acceptation

1. Le HUD est affiché en haut à droite de l'écran
2. Le HUD s'adapte à la résolution de l'écran (calcul dynamique du x)
3. Le contenu du HUD existant ne change pas (seule la position change)
4. ~~Les lignes de confinement LH-05 s'affichent dans le HUD quand actives~~
   ✅ Déjà implémenté dans LH-05
5. Le message de retour en zone (« De retour dans la zone », vert) s'affiche
   et disparaît après 3 secondes
6. Le countdown de confinement affiche des secondes entières (pas de float)
7. La ligne « Dégâts en cours » clignote en rouge
8. Pas de régression sur l'affichage existant du HUD (phases, spectateur, etc.)

## Questions en attente

Aucune — la position et le contenu sont validés.

## Dependencies

- Dépend de LH-05 (zone de confinement) pour les lignes de countdown
- Utilise `getCore():getScreenWidth()` (API vanilla PZ B41)

## Taille estimée

Small (S) — repositionnement d'un calcul de coordonnées + ajout de
quelques lignes conditionnelles dans le HUD existant.