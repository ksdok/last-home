# LH-12 (M) - Last Home: Piste A aggro des vagues via `createHordeFromTo`

## Contexte

Les zombies de vague spawnés via `addZombiesInOutfit()` n'attaquent pas correctement
les joueurs dans le mode Challenge Last Home, même après plusieurs essais de
forçage d'aggro côté Lua.

La **piste A** retenue dans `project-state.md` consiste à remplacer le spawn
manuel actuel par l'API native PZ/LastStand :

```lua
createHordeFromTo(spawnX, spawnY, targetX, targetY, count)
```

Hypothèse : cette API crée une horde "native" mieux intégrée au moteur de
population/IA que `addZombiesInOutfit()`, ce qui doit rétablir un comportement
normal de déplacement et d'attaque.

Objectif de cette spec : **tester la piste A sans refondre tout le système de
vagues**, en limitant le changement au spawn des zombies de vague.

## Changements

### 1. Remplacer le spawn des vagues par `createHordeFromTo`

Dans `spawnWaveZombies(count)` de `media/lua/server/LastHomeWaves.lua` :

- conserver la logique existante de calcul des directions (`N/E/S/W/ALL`)
- conserver les points de spawn déjà calculés autour de la maison
- remplacer, pour les zombies de vague uniquement, l'appel :

```lua
addZombiesInOutfit(point.x, point.y, point.z, zombiesHere, nil, 0)
```

par :

```lua
createHordeFromTo(point.x, point.y, Server.house.centerX, Server.house.centerY, zombiesHere)
```

Règles :
- la cible de la horde est le **centre de la maison**, pas la position exacte
  d'un joueur
- le comportement spécial de la Villa (vagues forcées au Sud) reste inchangé
- le pattern `ALL` reste basé sur les 12 segments déjà en place
- le spawn spectateur reste inchangé dans cette piste

### 2. Ajouter un mécanisme de tagging différé des zombies de vague

`createHordeFromTo()` ne retourne pas la liste des zombies créés, contrairement à
`addZombiesInOutfit()`. Il faut donc **reconstruire le tagging** utilisé par Last
Home pour :

- compter les zombies restants dans la vague
- décrémenter `Server.zombieCount` sur `OnZombieDead`
- distinguer les zombies de vague des zombies ambiants pour le cleanup
- conserver le `modData` Last Home (`LH_waveZombie`, `LH_waveNumber`, etc.)

Implémentation prévue :

- ajouter une file `Server.pendingWaveSpawnTags`
- chaque requête de horde y enregistre :
  - `wave`
  - `expectedCount`
  - `remainingToTag`
  - `spawnX`, `spawnY`
  - `targetX`, `targetY`
  - `createdAt`
- sur les ticks serveur suivants, scanner `getCell():getZombieList()`
- récupérer les zombies **non taggés** proches du point de spawn / du couloir
  vers la maison
- appliquer `scaleZombieStats(zombie, wave)` à chaque zombie reconnu comme zombie
  de la horde native
- incrémenter `Server.zombieCount` seulement pour les zombies effectivement taggés

Contraintes :
- ne jamais retagger un zombie déjà marqué `LH_waveZombie`
- limiter la fenêtre de scan dans le temps pour éviter de capter des zombies
  ambiants plus tardifs
- logguer tout écart entre `expectedCount` et `taggedCount`

### 3. Ajouter une résolution robuste des requêtes de tagging

Pour éviter qu'une requête reste bloquée indéfiniment :

- une requête de tagging expire après quelques secondes serveur
- à expiration :
  - si tous les zombies attendus sont taggés, la requête est supprimée
  - sinon la requête est supprimée avec un warning serveur
- le log doit inclure au minimum :
  - vague
  - point source
  - cible
  - demandés / taggés / manquants

But : rendre le test exploitable en jeu même si `createHordeFromTo()` ne permet
pas un tagging 100% parfait au premier essai.

### 4. Ne pas toucher au reste du gameplay dans cette piste

Cette spec **ne change pas** :

- les timers de prep/vague
- le skip de vague (`K`)
- le confinement
- les directions et leur scaling
- le nettoyage ambiant autour de la base
- le spawn spectateur manuel (`addZombiesInOutfit(..., 1, nil, 0)`)

Le but est d'isoler la variable testée : **le mode de spawn des zombies de
vague**.

## Fichiers impactés

- `media/lua/server/LastHomeWaves.lua`
  - remplacer l'appel de spawn principal des vagues
  - ajouter l'état `pendingWaveSpawnTags`
  - ajouter le scan/taging différé dans la boucle serveur
  - conserver `onZombieDead()` et le comptage existant, alimentés par le nouveau
    tagging

- `specs/LH-12-create-horde-from-to.md`
  - nouvelle spec versionnée

## Modifications détaillées

### État serveur supplémentaire

Ajouter dans `resetState()` :

```lua
Server.pendingWaveSpawnTags = {}
```

### Nouveau flux de spawn de vague

Pseudo-code attendu :

```lua
for each spawn point do
    createHordeFromTo(point.x, point.y, centerX, centerY, zombiesHere)
    queuePendingWaveSpawnTag({
        wave = Server.currentWave,
        expectedCount = zombiesHere,
        remainingToTag = zombiesHere,
        spawnX = point.x,
        spawnY = point.y,
        targetX = centerX,
        targetY = centerY,
        createdAt = now,
    })
end
```

### Nouveau flux de tagging

Pseudo-code attendu :

```lua
for each pending request do
    find nearby untagged zombies
    for each matched zombie do
        scaleZombieStats(zombie, request.wave)
        request.remainingToTag = request.remainingToTag - 1
        Server.zombieCount = Server.zombieCount + 1
    end

    if request.remainingToTag <= 0 then
        remove request
    elseif request expired then
        warn and remove request
    end
end
```

### Instrumentation minimale

Ajouter des logs ciblés :

- création de horde demandée
- nombre de zombies taggés par requête
- warning d'expiration partielle
- total `Server.zombieCount` après tagging

## Critères d'acceptation

1. Les vagues n'utilisent plus `addZombiesInOutfit()` pour leur spawn principal.
2. Chaque point de spawn de vague appelle `createHordeFromTo(spawnX, spawnY, targetX, targetY, count)`.
3. En jeu, les zombies de vague se déplacent vers la maison de façon native dès leur apparition.
4. En solo Challenge, les zombies de vague doivent enfin attaquer les joueurs au contact / à portée normale.
5. Le comptage des zombies restants continue de fonctionner via `Server.zombieCount`.
6. `OnZombieDead` continue de décrémenter uniquement les zombies de vague taggés `LH_waveZombie`.
7. Le cleanup ambiant n'efface pas les zombies de vague correctement taggés.
8. Le spawn spectateur reste inchangé et continue de fonctionner.
9. En cas de tagging partiel, le serveur loggue explicitement l'écart sans faire planter la partie.

## Questions en attente

Aucune pour la préparation de cette piste.

Décisions déjà prises :
- on teste **uniquement la piste A**
- la cible de la horde reste la **base** (centre de maison), pas un joueur précis
- le spawn spectateur ne fait pas partie de ce test

## Dépendances

- Dépend de LH-03 (système de vagues, directions, comptage)
- Dépend de LH-10 (état actuel des challenges, timers réduits, Villa forcée au Sud)
- S'appuie sur l'API Lua globale PZ `createHordeFromTo()` documentée par le moteur

## Taille estimée

Medium (M) — le remplacement du spawn est simple, mais le **tagging différé**
et la préservation du comptage Last Home ajoutent une complexité non triviale.