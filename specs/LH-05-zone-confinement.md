# LH-05 (S) - Last Home: Zone de confinement

## Contexte

Les joueurs doivent rester près de la maison pour la défendre. Sans restriction, un
joueur peut s'éloigner indéfiniment, ce qui casse l'objectif de défense coopérative.
Cette spec introduit une zone de confinement autour de chaque maison : si un joueur
sort de la zone, il reçoit un avertissement et dispose de 10 secondes pour revenir.
Au-delà de ce délai, il subit des dégâts progressifs jusqu'à la mort.

## Correction d'architecture

La première version de cette spec proposait une détection et des dégâts **côté client**.
Ce n'est pas le bon choix pour Last Home : en multijoueur, le confinement doit être
**autoritatif côté serveur** pour éviter les divergences de synchro et les contournements.
Le client garde uniquement l'affichage HUD temps réel.

Appui doc Context7 utilisé :
- **Project Zomboid Lua Docs / Events** : `OnPlayerGetDamage` est documenté comme un
  événement déclenché pour le joueur local, ce qui confirme qu'un flux purement client
  n'est pas une bonne base pour une règle gameplay multijoueur.
- **Project Zomboid Javadocs** : `IsoGameCharacter:getBodyDamage()` existe bien côté
  personnage, donc l'application de dégâts peut rester pilotée par la logique serveur.

## Comportement attendu

### Définition de la zone
- Chaque maison possède une **zone de confinement rectangulaire** définie dans
  `LastHomeShared.lua` via un champ `boundary`
- La zone est définie par `minX`, `maxX`, `minY`, `maxY`
- Par défaut, le confinement est **2D** : si aucun `minZ/maxZ` n'est défini, tous les
  étages sont autorisés tant que le joueur reste dans le rectangle en `X/Y`
- Si `boundary` est absent, le confinement est désactivé pour cette maison

### Zones validées
- **Hôpital** : `minX=12345`, `maxX=12474`, `minY=3597`, `maxY=3724`
- **Villa** : `minX=13524`, `maxX=13545`, `minY=2830`, `maxY=2858`
- **Prison** : `minX=7585`, `maxX=7781`, `minY=11761`, `maxY=11978`
- **École élémentaire** : `minX=10602`, `maxX=10636`, `minY=9949`, `maxY=9991`

### Détection de sortie de zone
- Côté **serveur**, le tick existant vérifie la position des joueurs vivants par rapport
  à la zone de confinement de la maison courante
- Le check ne s'active que si :
  - une maison est sélectionnée
  - le scénario n'est pas en phase `idle` / `gameover`
  - le joueur a un rôle (`modData.LH_role ~= nil`)
  - le joueur n'est pas spectateur (`modData.LH_dead ~= true` et `modData.LH_spectator ~= true`)
- Les spectateurs sont **exemptés** du confinement

### Avertissement et compte à rebours
- Quand le joueur sort de la zone :
  - le serveur ouvre un état `countdown` personnel de **10 secondes**
  - le client affiche dans le HUD : « Hors zone ! Revenez dans 10s »
- Si le joueur revient dans la zone avant la fin du compte à rebours :
  - le compte à rebours est annulé côté serveur
  - le client affiche : « De retour dans la zone »
  - les dégâts s'arrêtent immédiatement
- Le compte à rebours est affiché en temps réel par le client à partir d'un timestamp
  absolu reçu du serveur (`countdownEndsAt`)

### Pénalité : dégâts progressifs
- Quand le compte à rebours atteint 0, le joueur passe en état `damaging`
- Les dégâts sont appliqués **côté serveur** une fois par seconde
- Intensité cible : ~5% de santé perdue par seconde (mort en ~20s si le joueur ne revient pas)
- Les dégâts continuent tant que le joueur est hors zone
- Si le joueur revient dans la zone, les dégâts s'arrêtent mais la santé n'est pas régénérée
- Si le joueur meurt des dégâts, cela déclenche le système de mort existant
  (`OnPlayerDeath` / `checkDeadPlayers` / `PlayerDied` → mode spectateur)

### Synchronisation client
- La structure `boundary` est incluse dans les données de maison envoyées au client via
  `WaveState`
- Un nouveau message serveur `BoundaryState` synchronise l'état personnel du joueur :
  - `username`
  - `status` (`inside` | `countdown` | `damaging`)
  - `countdownEndsAt`
- Le client n'applique aucun dégât ; il affiche seulement l'état en HUD

## Architecture technique

### Fichiers impactés

- `media/lua/shared/LastHomeShared.lua`
  - Ajout du champ `boundary` sur chaque entrée de `HOUSE_DEFS`
  - Ajout d'un helper `LastHomeShared.hasBoundary(house)`
  - `LastHomeShared.isInsideBoundary(playerOrX, house, y, z)` gère en priorité les
    rectangles `boundary`, avec fallback legacy possible vers un rayon si besoin

- `media/lua/server/LastHomeWaves.lua`
  - Ajout d'un état serveur par joueur : `Server.boundaryStates[username]`
  - Vérification de confinement dans le `onTick()` serveur existant
  - Application des dégâts côté serveur
  - Nouveau message `BoundaryState`

- `media/lua/client/LastHomeClient.lua`
  - Nouvel état local : `LastHomeClient.boundaryState`
  - Réception du message `BoundaryState`
  - Affichage HUD du compte à rebours / état hors zone
  - Aucun tick client de détection ni de dégâts

## Critères d'acceptation

1. Chaque maison peut définir une zone `boundary` personnalisée
2. Le confinement fonctionne sur les rectangles `X/Y` fournis
3. Les étages restent autorisés tant qu'aucune contrainte `Z` n'est définie
4. Un joueur qui sort de la zone reçoit un message d'avertissement
5. Un compte à rebours de 10 secondes s'affiche en temps réel dans le HUD
6. Si le joueur revient dans la zone, le compte à rebours est annulé
7. Si le compte à rebours atteint 0, le joueur subit des dégâts progressifs
8. Les dégâts sont appliqués côté serveur
9. Les dégâts s'arrêtent dès que le joueur revient dans la zone
10. Les dégâts peuvent tuer le joueur (déclenche le mode spectateur existant)
11. Les spectateurs sont exemptés du confinement
12. Si une maison n'a pas de `boundary`, le confinement est désactivé pour elle

## Dependencies

- Dépend de LH-04 (système de maison, `LastHomeShared.lua` avec `HOUSE_DEFS`)
- Dépend de LH-03 (`waveState` synchronisé au client via `WaveState`)
- Réutilise le `Events.OnTick` serveur déjà en place dans `LastHomeWaves.lua`
- Réutilise le HUD client existant dans `LastHomeClient.lua`

## Taille estimée

Small (S) — extension locale des états serveur/client existants, sans nouveau sous-système
persistant ni logique réseau complexe.