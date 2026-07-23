# LH-11 (S) - Last Home: Aggression vanilla et spawn distance réduite

## Contexte

Les zombies spawment à 40 tiles et ont une aggression scaling trop faible
(0.3 + wave * 0.03), ce qui les rend passifs. L'utilisateur veut :
1. Aggression au niveau vanilla PZ (comportement normal des zombies)
2. Spawn distance réduite à 30 tiles

## Changements

### 1. Aggression vanilla

Le mod modifie actuellement l'aggression via `getAggression(wave) = 0.3 + (wave * 0.03)`
et l'applique avec `zombie:addAggro(target, aggression * 100)`. En vague 1, cela
donne 0.33 — bien en dessous du comportement vanilla.

Nouveau comportement :
- Ne plus appliquer de modificateur d'aggression custom
- Laisser les zombies avec leur comportement vanilla (aggression sandbox par défaut)
- Conserver `zombie:spotted(target, true)` pour les mettre en alerte à leur spawn
- Conserver `zombie:setCanWalk(true)` pour qu'ils se déplacent

### 2. Speed multiplier vanilla

Le mod modifie la vitesse via `getSpeedMultiplier(wave) = 0.8 + (wave * 0.05)`.
En vague 1, cela donne 0.85 — les zombies sont plus lents que la normale.

Nouveau comportement :
- Ne plus appliquer `setSpeedMod()` ou utiliser 1.0 (vitesse vanilla)
- Laisser le moteur PZ gérer la vitesse des zombies

### 3. Spawn distance à 30

Modifier `SPAWN_DISTANCE` de 40 à 30 tiles.

### 4. Détection range

Le mod modifie la détection via `getDetectionRange(wave) = 8 + (wave * 0.5)`.
Ce n'est pas directement lié à l'aggression mais influence `addSound()`.

Nouveau comportement :
- Garder le detection range custom (il sert au pressure pulse pour attirer
  les zombies vers la maison) — seul l'aggression et la vitesse passent en vanilla

## Fichiers impactés

- `media/lua/server/LastHomeWaves.lua`

### Modifications détaillées

```lua
-- Avant
local SPAWN_DISTANCE = 40
local function getAggression(wave) return 0.3 + (wave * 0.03) end
local function getSpeedMultiplier(wave) return 0.8 + (wave * 0.05) end

-- Après
local SPAWN_DISTANCE = 30
-- getAggression et getSpeedMultiplier supprimés (vanilla)
```

Dans `scaleZombieStats()` :
- Supprimer l'appel `zombie:setSpeedMod(speedMultiplier)`
- Supprimer l'appel `zombie:addAggro(target, aggression * 100)`
- Conserver `zombie:setCanWalk(true)`
- Conserver `zombie:spotted(target, true)`
- Conserver `zombie:setTurnAlertedValues(centerX, centerY)`
- Conserver le modData (tags LH_waveZombie, etc.)

## Critères d'acceptation

1. Les zombies spawment à 30 tiles du centre de la maison
2. Les zombies ont une aggression vanilla (ils attaquent les joueurs normalement)
3. Les zombies ont une vitesse vanilla (pas de ralentissement en vague 1)
4. Les zombies sont toujours orientés vers la maison au spawn
5. Les zombies sont toujours mis en alerte au spawn (`spotted`)
6. Le pressure pulse (`addSound`) continue d'attirer les zombies vers la maison
7. Le modData de tagging des zombies est conservé (comptage, cleanup)

## Questions en attente

Aucune — les deux changements ont été validés par l'utilisateur.

## Dependencies

- Dépend de LH-03 (système de vagues, spawn, scaleZombieStats)

## Taille estimée

Small (S) — suppression de 2 fonctions, modification de 1 constante, nettoyage
de scaleZombieStats().