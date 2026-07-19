# LH-03 (L) - Last Home: Vagues

## Contexte

Les vagues sont le coeur du gameplay de Last Home. Toutes les 10 minutes, une
horde de zombies attaque la maison. Les vagues sont de plus en plus
dangereuses: a chaque nouvelle vague, les zombies deviennent un peu plus
agressifs et un peu plus rapides (progression continue, pas par paliers).

La direction des hordes est croissante: 1 direction au debut, puis
progressivement 2, puis 360 degres aux vagues avancees. La direction est
annoncee avant chaque vague pendant la phase de preparation.

Les joueurs morts (permadeath) deviennent spectateurs et peuvent faire spawner
1 zombie ou ils veulent pendant chaque vague suivante.

## Structure d'une vague

### Cycle de jeu
```
[Game Start]
    |
    v
[Prep 10 min] -- annonce vague 1 (direction, taille)
    |
    v
[Vague 1] -- zombies spawn, attaque
    |
    v (tous les zombies morts OU timer 10 min ecoule)
[Prep 10 min] -- annonce vague 2
    |
    v
[Vague 2]
    |
    v
[... repeat ...]
    |
    v (tous les joueurs morts)
[Game Over]
```

### Phase de preparation (10 min)
- Annonce de la prochaine vague:
  - Numero de vague
  - Direction(s) d'attaque (ex: "Vague 5 arrive par le NORD")
  - Taille estimee (ex: "~30 zombies")
- Timer visible (compte a rebours avant la vague)
- Les joueurs craftent, reparent, se soignent, vont looter (Voleur/Eclaireur)
- Le Builder peut utiliser son refill automatique (EveryTenMinutes)

### Phase d'attaque
- Les zombies spawnent aux points de spawn definis selon la direction
- Les zombies avancent vers la maison
- Les joueurs defendent
- La vague se termine quand:
  - Tous les zombies de la vague sont morts, OU
  - Le timer de 10 min est ecoule (la vague suivante arrive -- les zombies
    restants s'ajoutent a la nouvelle vague)

### Fin de partie
- La partie se termine quand tous les joueurs (vivants) sont morts
- Le score final = nombre de vagues survecues
- Affichage du score a l'ecran de game over

## Scaling des vagues

### Progression continue
A chaque nouvelle vague, les zombies deviennent un peu plus:
- **Agressifs** (probabilite de detection des joueurs augmente)
- **Rapides** (vitesse de deplacement augmente legerement)

Pas de paliers -- la progression est lineaire et continue vague apres vague.

### Nombre de zombies par vague
Le nombre de zombies de base depend du nombre de vague et du nombre de joueurs
vivants:

```
baseCount = 10 + (waveNumber * 5)
scaledByPlayers = baseCount * (alivePlayers / 4)
finalCount = round(scaledByPlayers)
```

Exemples (4 joueurs vivants):
- Vague 1: 15 zombies
- Vague 5: 35 zombies
- Vague 10: 60 zombies
- Vague 20: 110 zombies

Si les joueurs meurent, le nombre de zombies diminue proportionnellement
(evite qu'une horde massive submerge 1 survivant).

### Vague non eliminee a temps
Si la vague n'est pas eliminee avant la fin du timer de 10 min:
- La vague suivante arrive quand meme
- Les zombies restants de la vague precedente s'ajoutent a la nouvelle vague
- Pas de phase de prep supplementaire -- la vague suivante demarre
  immediatement apres le timer

### Stats des zombies par vague

| Stat | Vague 1 | Vague 5 | Vague 10 | Vague 20 |
|------|---------|---------|----------|----------|
| Vitesse | 0.85x | 1.05x | 1.3x | 1.8x |
| Aggressivite | 0.33 | 0.45 | 0.6 | 0.9 |
| Detection range | 8.5 tiles | 10.5 tiles | 13 tiles | 18 tiles |

**Formule vitesse**: `speedMultiplier = 0.8 + (waveNumber * 0.05)`
- Vague 1: 0.85x
- Vague 5: 1.05x
- Vague 10: 1.3x
- Vague 20: 1.8x
- Vague 30: 2.3x

**Formule aggressivite**: `aggression = 0.3 + (waveNumber * 0.03)`
- Vague 1: 0.33
- Vague 5: 0.45
- Vague 10: 0.6
- Vague 20: 0.9

**Formule detection range**: `detectionRange = 8 + (waveNumber * 0.5)` tiles
- Vague 1: 8.5 tiles
- Vague 5: 10.5 tiles
- Vague 10: 13 tiles
- Vague 20: 18 tiles

Les formules sont appliques via les stats du zombie (crawlerSpeed, speedType,
aggression, detectionRange). Les valeurs exactes d'application aux stats PZ
seront definies lors de l'implementation.

## Direction des hordes (croissante)

### Regles
- La direction est annoncee pendant la phase de prep (avant la vague)
- Le nombre de directions augmente avec le numero de vague:

| Vagues | Directions |
|--------|-----------|
| 1-3 | 1 direction (N, S, E, ou O -- aleatoire) |
| 4-6 | 2 directions (adjacentes, ex: N+E) |
| 7-9 | 3 directions |
| 10+ | 360 degres (toutes les directions) |

- Les directions sont tirees aleatoirement a chaque vague
- L'annonce precise les directions (ex: "Vague 7 arrive par le NORD, EST et OUEST")

### Points de spawn
- Les zombies spawnent a une distance fixe de la maison (ex: 30-50 tiles)
- Plusieurs points de spawn par direction (ex: 3 points par direction)
- Les zombies se dirigent vers le centre de la maison (pathfinding PZ standard)

### Distance de spawn
- Les zombies spawnent a **40 tiles** du centre de la maison
- Suffisamment loin pour que les joueurs aient le temps de se positionner
- Assez proche pour que la vague arrive en un temps raisonnable

## Spectateur (joueur mort)

### Comportement
- Le joueur mort devient spectateur (camera libre -- peut voler sur la map
  pour voir les zombies arriver de partout)
- Pendant chaque vague suivante, le spectateur peut faire spawner **1 zombie**
  ou il veut sur la map
- Le zombie spawne est un zombie normal (pas special)
- Le spectateur choisit l'emplacement via un click sur la map ou une UI dediee

### Limitations
- 1 spawn par vague par spectateur (pas de spam)
- Le zombie spawne ne peut pas etre place directement sur un joueur vivant
  (distance minimum: 10 tiles)
- Le zombie spawne ne peut pas etre place a l'interieur de la maison (doit
  etre a l'exterieur)

### UI spectateur
- Clique droit sur la map -> menu contextuel -> "Spawner un zombie ici"
- Actif pendant les vagues uniquement (desactive pendant les phases de prep)
- Confirmation visuelle (marker sur la map)
- 1 spawn par vague par spectateur (le menu est grisé/desactive apres usage)

## Annonces

### Format
Les annonces sont affichees via le systeme de notifications PZ (comme EE).

Pendant la phase de prep (debut):
```
[Last Home] Vague 5 dans 10 min
Direction: NORD
Taille estimee: ~35 zombies
```

Alerte 1 min avant la vague:
```
[Last Home] Vague 5 dans 1 min! Preparez-vous!
```

Debut de la vague:
```
[Last Home] Vague 5! Les zombies arrivent par le NORD!
```

Fin de la vague (tous morts):
```
[Last Home] Vague 5 eliminee! Prochaine vague dans 10 min.
```

Fin de la vague (timer ecoule):
```
[Last Home] Temps ecoule! La vague 6 arrive... les zombies restants
s'ajoutent a la horde!
```

## Architecture technique

### Fichier prevu
`media/lua/server/LastHomeWaves.lua` -- gestion des vagues (spawn, scaling,
direction, timer, annonces)

### Variables serveur
```lua
Server = {
    currentWave = 0,
    waveActive = false,
    prepTimer = 600,          -- 10 min en secondes
    waveTimer = 600,          -- 10 min en secondes
    directions = {},          -- directions de la vague actuelle
    zombieCount = 0,          -- zombies restants dans la vague
    spectators = {},          -- joueurs morts (username -> {spawnedThisWave=false})
    -- ...
}
```

### Fonctions principales
- `startPrepPhase()` -- demarre la phase de prep, annonce la vague
- `startWave()` -- demarre la vague, spawn les zombies
- `endWave(reason)` -- termine la vague (all dead / timer)
- `calculateZombieCount(wave, alivePlayers)` -- calcule le nombre de zombies
- `calculateDirections(wave)` -- determine les directions de la vague
- `getSpawnPoints(directions, distance)` -- calcule les points de spawn
- `scaleZombieStats(zombie, wave)` -- applique le scaling agressivite/vitesse
- `onZombieDeath()` -- verifie si la vague est terminee
- `onPlayerDeath()` -- passe le joueur en spectateur
- `onSpectatorSpawnZombie(username, x, y)` -- spawn zombie demande par spectateur

### Evenements PZ utilises
- `OnGameStart` -- demarre le premier cycle (prep phase)
- `OnZombieDeath` -- decremente zombieCount, verifie fin de vague
- `OnPlayerDeath` -- ajoute le joueur aux spectateurs
- `EveryMinutes` ou timer custom -- gestion des timers prep/wave
- Commandes client->serveur pour le spawn de zombie spectateur

## Critere d'acceptation

1. Les vagues arrivent toutes les 10 minutes
2. La premiere vague arrive apres une phase de prep de 10 min
3. A chaque vague, les zombies sont plus agressifs et plus rapides
4. Le nombre de zombies augmente avec le numero de vague et le nombre de joueurs
5. La direction est croissante (1 -> 2 -> 3 -> 360) et annoncee avant
6. L'annonce affiche le numero, la direction et la taille estimee
7. Un timer visible compte le temps avant la prochaine vague
8. Si la vague n'est pas eliminee a temps, la suivante arrive et les zombies
   restants s'ajoutent
9. Les joueurs morts peuvent spawner 1 zombie par vague ou ils veulent
10. La partie se termine quand tous les joueurs sont morts
11. Le score final = nombre de vagues survecues

## Questions en attente

1. **Distance de spawn** des zombies : **[VALIDE: 40 tiles du centre de la maison]**
2. **Vitesse exacte** des zombies par vague : **[VALIDE: formule speedMultiplier = 0.8 + (waveNumber * 0.05)]**
3. **Aggressivite exacte** : **[VALIDE: aggression = 0.3 + (waveNumber * 0.03), detectionRange = 8 + (waveNumber * 0.5) tiles]**
4. **Camera spectateur**: libre ou suit un joueur vivant ? **[VALIDE: libre]**
5. **UI spectateur**: bouton sur l'ecran ou menu radial ? **[VALIDE: clique droit -> menu contextuel "Spawner un zombie ici"]**

## Dependencies

- Aucune dependance externe -- mod standalone
- Reutilise `addZombiesInOutfit()` de PZ pour le spawn (comme EE)
- Reutilise le systeme de notifications de PZ (comme EE)

## Taille estimee

Large (L) -- systeme de vagues + scaling continu + directions croissantes +
gestion spectateur + annonces + timers + game over