# LH-09 (S) - Last Home: Scaling adaptable des vagues selon le nombre de joueurs

## Contexte

La formule actuelle de calcul du nombre de zombies par vague est :
```
baseCount = 10 + (wave * 5)
zombies = baseCount * (alivePlayers / 4)
```

En solo, cela donne trop peu de zombies (4 en vague 1, 15 en vague 10). La nouvelle
formule doit commencer à 8 zombies en vague 1 pour 1 joueur et s'adapter au nombre
de joueurs connectés.

## Changement

### Nouvelle formule

```
baseCount = 3 + (wave * 5)
multiplier = max(1, alivePlayers / 2)
zombies = round(baseCount * multiplier)
```

### Tableau de référence

| Vague | 1 joueur | 2 joueurs | 4 joueurs | 8 joueurs |
|-------|----------|-----------|-----------|-----------|
| 1     | 8        | 8         | 16        | 32        |
| 2     | 13       | 13        | 26        | 52        |
| 3     | 18       | 18        | 36        | 72        |
| 4     | 23       | 23        | 46        | 92        |
| 5     | 28       | 28        | 56        | 112       |
| 6     | 33       | 33        | 66        | 132       |
| 7     | 38       | 38        | 76        | 152       |
| 8     | 43       | 43        | 86        | 172       |
| 9     | 48       | 48        | 96        | 192       |
| 10    | 53       | 53        | 106       | 212       |

### Comportement
- 1-2 joueurs : baseCount brut (pas de multiplicateur supplémentaire)
- 4 joueurs : x2
- 8 joueurs : x4
- Le nombre de joueurs est recalculé à chaque vague (joueurs vivants uniquement)
- Si un joueur meurt pendant la partie, la vague suivante s'adapte à la baisse

## Fichiers impactés

- `media/lua/server/LastHomeWaves.lua` — modifier `calculateZombieCount()`

### Modification détaillée

Remplacer dans `calculateZombieCount()` :
```lua
-- Avant
local function calculateZombieCount(wave, alivePlayers)
    local baseCount = 10 + (wave * 5)
    local scaledByPlayers = baseCount * ((alivePlayers or 0) / 4)
    return math.max(1, round(scaledByPlayers))
end

-- Après
local function calculateZombieCount(wave, alivePlayers)
    local baseCount = 3 + (wave * 5)
    local multiplier = math.max(1, (alivePlayers or 0) / 2)
    return math.max(1, round(baseCount * multiplier))
end
```

## Critères d'acceptation

1. Vague 1 en solo = 8 zombies
2. Vague 10 en solo = 53 zombies
3. 4 joueurs = x2 par rapport au solo
4. 8 joueurs = x4 par rapport au solo
5. Le nombre de zombies s'adapte au nombre de joueurs vivants à chaque vague
6. Si tous les joueurs sont morts, game over (déjà géré par `getAlivePlayerCount() <= 0`)

## Questions en attente

Aucune — la formule a été validée par l'utilisateur.

## Dependencies

- Dépend de LH-03 (système de vagues, `calculateZombieCount()`)
- Utilise `getAlivePlayerCount()` (déjà existant)

## Taille estimée

Small (S) — 3 lignes à modifier dans une seule fonction.