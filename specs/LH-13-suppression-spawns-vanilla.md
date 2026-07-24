# LH-13 (M) - Last Home: Suppression continue des spawns vanilla/story en Challenge

## Contexte

Les logs de test montrent qu'en **vague 1 solo**, Last Home spawn bien ses
**8 zombies de vague** attendus, mais que des zombies **vanilla/story** peuvent
apparaître en plus autour de la base.

Constat observé :
- `DebugLog` : `Vague 1: 8/8 zombies spawnes, total restants=8`
- `ZombieSpawn.txt` : présence de spawns `RDSPrisonEscape`,
  `createEatingZombies`, `RBSafehouse`, etc.
- le nettoyage ponctuel actuel supprime beaucoup de zombies ambiants, mais ne
  garantit pas qu'aucun spawn parasite ne réapparaisse ensuite pendant la prep
  ou la vague

Les sandbox vars du challenge sont déjà configurées en mode restrictif :
- `SandboxVars.Zombies = 6`
- `SandboxVars.MetaEvent = 1`
- `SandboxVars.SurvivorHouseChance = 1`
- `SandboxVars.ZoneStoryChance = 1`
- `SandboxVars.VehicleStoryChance = 1`
- `ZombieConfig.PopulationMultiplier/Respawn/Rally = 0`

Conclusion : **la configuration sandbox seule ne suffit pas** à garantir une
zone de jeu propre en mode Challenge. Il faut ajouter une **suppression serveur
continue** des zombies non-Last-Home autour de la base.

## Objectif

Garantir qu'en Challenge Last Home, la zone de défense autour de la maison ne
contienne que :
- les zombies de vague Last Home
- les zombies spawnés par les spectateurs

Tous les autres zombies vanilla/story/ambiants proches de la base doivent être
supprimés automatiquement pendant la prep et pendant les vagues.

## Changements

### 1. Conserver la configuration sandbox actuelle

Cette spec **ne change pas** les sandbox vars déjà en place dans les fichiers
challenge.

But : ne pas rouvrir la piste "tuning sandbox" tant que l'observation en logs
montre que le vrai problème est l'apparition tardive de spawns vanilla/story.

### 2. Passer d'un cleanup ponctuel à une suppression continue

Le nettoyage actuel autour de la base est déclenché ponctuellement au début de
la prep et au démarrage de vague.

Nouveau comportement :
- conserver le cleanup immédiat existant aux transitions de phase
- ajouter un **cleanup périodique serveur** tant que la partie Last Home est
  active et qu'une maison est définie
- fréquence cible : toutes les quelques secondes (ex. `5s`), configurable par
  constante

But : si le moteur spawn un `RDS*`, `createEatingZombies` ou autre zombie
parasite après le premier nettoyage, il est retiré rapidement avant de polluer
la défense de la base.

### 3. Nettoyer uniquement les zombies non taggés Last Home

La suppression continue doit préserver :
- les zombies de vague taggés `LH_waveZombie`
- les zombies spectateurs s'ils utilisent le même tagging Last Home

Règles :
- **ne jamais supprimer** un zombie déjà taggé `LH_waveZombie == true`
- continuer à supprimer tous les zombies non taggés dans la zone de suppression
- conserver la logique de comptage existante (`Server.zombieCount`) inchangée

### 4. Activer la suppression dès que le scénario est réellement lancé

La suppression continue doit être active :
- pendant la prep
- pendant la vague
- tant que `Server.started == true` et `Server.gameOver == false`

Elle ne doit pas tourner inutilement quand :
- aucune maison n'est choisie
- la partie n'a pas commencé
- le game over est atteint

### 5. Garder une zone de suppression configurable par maison

Le cleanup actuel utilise déjà un rayon autour de la base.

Nouveau comportement attendu :
- conserver le mécanisme existant de rayon / fallback
- permettre un réglage explicite par maison si nécessaire
- dimensionner la zone pour couvrir la maison, ses abords immédiats et la zone
  où des spawns parasites ont été observés

But : ne pas dépendre d'une valeur implicite trop petite pour certains lieux.

### 6. Ajouter des logs ciblés pour distinguer les nettoyages

Le serveur doit logguer :
- le cleanup de transition de phase
- le cleanup périodique
- le nombre de zombies supprimés
- la maison concernée

But : pouvoir vérifier facilement en test que :
- la vague 1 spawn toujours 8/8 zombies Last Home
- les spawns vanilla/story supplémentaires sont bien supprimés ensuite

## Fichiers impactés

- `media/lua/server/LastHomeWaves.lua`
  - faire évoluer `clearAmbientZombiesNearHouse()`
  - ajouter l'état et l'ordonnancement du cleanup périodique
  - déclencher la suppression continue dans la boucle serveur

- `media/lua/shared/LastHomeShared.lua`
  - éventuellement ajuster / exposer les paramètres de zone de suppression par
    maison si le rayon actuel est insuffisant

- `specs/LH-13-suppression-spawns-vanilla.md`
  - nouvelle spec versionnée

## Modifications détaillées

### État serveur supplémentaire

Ajouter dans `resetState()` :

```lua
Server.nextAmbientCleanupAt = nil
```

Ajouter une constante de rythme, par exemple :

```lua
local AMBIENT_CLEANUP_INTERVAL_SECONDS = 5
```

### Nouveau flux attendu

- au début de la prep :
  - cleanup immédiat
  - planifier le prochain cleanup périodique

- au début de la vague :
  - cleanup immédiat
  - replanifier le prochain cleanup périodique

- sur `OnTick` serveur :
  - si partie active + maison définie + `now >= Server.nextAmbientCleanupAt`
  - appeler `clearAmbientZombiesNearHouse()`
  - repousser `Server.nextAmbientCleanupAt`

Pseudo-code attendu :

```lua
if Server.started and not Server.gameOver and Server.house ~= nil then
    if Server.nextAmbientCleanupAt ~= nil and now >= Server.nextAmbientCleanupAt then
        clearAmbientZombiesNearHouse("periodic")
        Server.nextAmbientCleanupAt = now + AMBIENT_CLEANUP_INTERVAL_SECONDS
    end
end
```

### Évolution du cleanup existant

Faire évoluer la fonction actuelle pour :
- accepter éventuellement un `reason` (`"prep"`, `"wave"`, `"periodic"`)
- conserver l'exclusion des zombies Last Home taggés
- logguer le type de cleanup effectué

Exemple de log attendu :

```lua
[LastHome] Nettoyage zombies ambiants (periodic) pres de la base: 3 supprimes
```

## Critères d'acceptation

1. En vague 1 solo, Last Home continue de logguer `8/8 zombies spawnes`.
2. Les zombies de vague Last Home et les zombies spectateurs ne sont jamais
   supprimés par le cleanup périodique.
3. Les zombies vanilla/story non taggés proches de la base sont supprimés même
   s'ils apparaissent après le cleanup initial.
4. La suppression fonctionne pendant la prep et pendant la vague.
5. La suppression s'arrête quand la partie n'est pas active ou après game over.
6. Les logs serveur distinguent au minimum les nettoyages `prep`, `wave` et
   `periodic`.
7. En test Challenge, la zone de défense ne contient plus de zombies parasites
   persistants autour de la base au-delà de la courte fenêtre entre deux ticks
   de cleanup.

## Questions en attente

- Le rayon actuel de cleanup est-il suffisant pour les 4 maisons, ou faut-il un
  paramètre dédié `ambientSuppressionRadius` par lieu ?
- Faut-il activer la suppression continue seulement en mode Challenge, ou pour
  tout runtime Last Home ?

## Dépendances

- Dépend de LH-03 (système de vagues, comptage, `LH_waveZombie`)
- Dépend de LH-04 (définition des maisons et de leur centre)
- Dépend de LH-10 (état actuel des challenges et du nettoyage ambiant)

## Taille estimée

Medium (M) — la logique est locale, mais ajoute un comportement serveur
périodique qu'il faut calibrer sans casser le comptage des zombies de vague.
