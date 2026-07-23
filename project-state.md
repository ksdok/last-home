# Project State

## Résumé

- Projet : **Last Home**
- Repo : `/Users/kim/Documents/Zomboid/last-home`
- Branche de référence : `main`
- Branche source du ticket livré : `feat/lh-10-timers-skip`
- Référence utilisée : `/Users/kim/Documents/Zomboid/EscapadeExpress`

## État actuel

- ✅ Les specs versionnées **LH-01** à **LH-08** et **LH-10** sont rédigées et validées
- ✅ **LH-02** à **LH-08** sont implémentés et corrigés après review / debug
- ✅ **LH-10** est implémenté : timers raccourcis, skip de vague, HUD de skip, debounce client
- ✅ 4 challenges enregistrés dans le menu Challenges de PZ (Hôpital, Villa, Prison, École)
- ✅ Les challenges Last Home désactivent désormais la pop vanilla (`SandboxVars.Zombies = 6` + multipliers à 0) et nettoient les zombies ambiants autour de la base
- ✅ La Villa est fiabilisée : vagues forcées au **Sud**, spawns au sol, attraction des vagues recentrée sur des impulsions sonores type alarme vers la base
- ⏳ La prochaine étape reste la **vérification en jeu** (solo/LAN puis multijoueur), surtout sur la pression zombie réelle, l'attraction vers la Villa, les spectateurs et le pacing LH-10

## Terminé

### Specs
- [x] LH-01 — Concept et spécification
- [x] LH-02 — Rôles réajustés
- [x] LH-03 — Vagues
- [x] LH-04 — Maison, réparations et défense
- [x] LH-05 — Zone de confinement
- [x] LH-06 — Refonte HUD et position
- [x] LH-07 — Fix sync solo state via OnTick dédié
- [x] LH-08 — Équipement des rôles
- [x] LH-10 — Timers réduits et skip de vague

### Implémentation
- [x] LH-02 — Système de rôles Last Home
  - `media/lua/shared/LastHomeRoles.lua`
  - `media/lua/client/LastHomeRolePicker.lua`
  - `media/lua/client/LastHomeClient.lua`
  - `media/lua/server/LastHomeServer.lua`
  - `mod.info`
  - Correctifs post-review appliqués :
    - ouverture du role picker fiabilisée côté client
    - `applyPerkLevel()` rendu plus robuste
    - texte du picker rendu plus pérenne
    - `version=0.1.0` ajoutée à `mod.info`

- [x] LH-03 — Système de vagues Last Home
  - `media/lua/server/LastHomeWaves.lua`
  - `media/lua/shared/LastHomeShared.lua`
  - `media/lua/server/LastHomeServer.lua`
  - `media/lua/client/LastHomeClient.lua`
  - `mod.info`
  - Fonctionnalités implémentées :
    - cycle prep 10 min / vague 10 min en temps réel
    - scaling des zombies selon vague + joueurs vivants
    - directions croissantes 1 / 2 / 3 / 360
    - annonces serveur/client + HUD timer MM:SS
    - débordement des zombies restants sur la vague suivante
    - mode spectateur avec 1 spawn zombie par vague
    - score = nombre de vagues survécues
  - Correctifs post-review appliqués :
    - score fiabilisé via `wavesSurvived`
    - timers migrés sur un suivi temps réel partagé
    - robustesse côté serveur sur détection de mort joueur
    - feedback ciblé si un spawn spectateur est refusé
    - `version=0.2.0` ajoutée à `mod.info`

- [x] LH-04 — Maison, réparations et défense
  - `media/lua/shared/LastHomeShared.lua`
  - `media/lua/server/LastHomeServer.lua`
  - `media/lua/server/LastHomeWaves.lua`
  - `media/lua/client/LastHomeClient.lua`
  - `mod.info`
  - Fonctionnalités implémentées :
    - sélection aléatoire d'un bâtiment vanilla parmi 4 (Hôpital, Villa, Prison, École élémentaire)
    - zones de spawn joueur par bâtiment (radius ou box selon la maison)
    - centre de maison synchronisé au système de vagues et au HUD client
    - stock communautaire dans un conteneur vanilla dédié par maison
    - fallback sur le conteneur vanilla le plus proche si le conteneur dédié est absent
    - refill Builder conservé + stock maison rerempli toutes les 10 minutes
  - Correctifs post-review appliqués :
    - validation plus stricte des squares de spawn joueur
    - garde anti-spam sur le refill du stock maison lors des reconnexions / assignations
    - warning serveur si un téléport de joueur vers la maison échoue
    - `version=0.3.0` ajoutée à `mod.info`

- [x] LH-05 — Zone de confinement autour de la maison
  - `media/lua/shared/LastHomeShared.lua`
  - `media/lua/server/LastHomeWaves.lua`
  - `media/lua/client/LastHomeClient.lua`
  - `specs/LH-05-zone-confinement.md`
  - `README.md`
  - `mod.info`
  - Fonctionnalités implémentées :
    - `boundary` rectangulaire 2D configurable par maison (coordonnées validées en jeu)
    - détection serveur des sorties de zone pour les joueurs vivants avec rôle
    - compte à rebours de 10s synchronisé au HUD client via `BoundaryState`
    - dégâts progressifs autoritatifs côté serveur après expiration du compte à rebours
    - exemption des spectateurs et arrêt immédiat du confinement au retour dans la zone
  - Notes :
    - l'architecture de la spec a été corrigée vers un modèle **serveur autoritatif** pour le multijoueur
    - zones de confinement rectangulaires 2D `X/Y` sans contrainte `Z` pour les 4 lieux
    - correctifs post-review : suppression de la re-normalisation inutile de `boundary` à chaque tick, alignement du fallback de dégâts sur `BOUNDARY_DAMAGE_AMOUNT`
    - `version=0.5.0` ajoutée à `mod.info`

- [x] LH-06 — Refonte HUD et position
  - `media/lua/client/LastHomeClient.lua`
  - `specs/LH-06-hud.md`
  - `mod.info`
  - Fonctionnalités implémentées :
    - HUD ancré en haut à droite avec calcul dynamique (`getCore():getScreenWidth()`)
    - secondes du countdown de confinement affichées en entier (`math.ceil()`)
    - clignotement de la ligne « Dégâts actifs » (alternance toutes les 0.5s)
    - message « De retour dans la zone » (vert, disparaît après 3s) via `boundaryReturnedAt`
  - Correctifs post-review appliqués :
    - détection du retour en zone dans `updateBoundaryState()` (transition countdown/damaging → inside)
    - `version=0.6.0` ajoutée à `mod.info`

- [x] LH-07 — Fix sync solo / confinement
  - `media/lua/client/LastHomeClient.lua`
  - `media/lua/server/LastHomeWaves.lua`
  - `media/lua/shared/LastHomeShared.lua`
  - `specs/LH-07-fix-sync-solo.md`
  - Fonctionnalités implémentées :
    - sync solo déplacée du rendu HUD vers un `Events.OnTick` dédié
    - resynchronisation solo de `waveState` et `boundaryState` indépendante du draw UI
    - indicateur local HUD `Zone: IN/OUT` pour visualiser l'état du confinement côté client
    - logs ciblés serveur/client pour debugger la détection boundary en solo
  - Correctifs post-debug appliqués :
    - `LastHomeShared.isInsideBoundary()` corrigé pour gérer les objets joueur PZ via `getX()/getY()` au lieu d'un test `type(...) == "table"`
    - warning local client « Hors zone ! Retournez vers la base » ajouté en fallback visuel
    - spam de logs périodiques des coordonnées joueur retiré après validation

- [x] LH-08 — Équipement des rôles
  - `media/lua/shared/LastHomeShared.lua`
  - `media/lua/client/LastHomeClient.lua`
  - `media/lua/server/LastHomeServer.lua`
  - `specs/LH-08-equipement-roles.md`
  - Fonctionnalités implémentées :
    - répartition de l'inventaire, du sac et des objets équipés plus robuste selon le rôle
    - détection automatique des armes 2 mains
    - munitions préchargées au spawn
    - helpers partagés `applyCarryProfile`, `primeRoleLoadout`, `equipRoleItems`
  - Correctifs appliqués :
    - duplication client/serveur réduite pour l'équipement et la charge
    - compatibilité conservée avec les rôles existants et le refill Builder

- [x] LH-10 — Timers réduits, skip de vague et fiabilisation Villa
  - `media/lua/server/LastHomeWaves.lua`
  - `media/lua/client/LastHomeClient.lua`
  - `media/lua/shared/LastHomeShared.lua`
  - `media/lua/client/LastStand/LastHomeHospital.lua`
  - `media/lua/client/LastStand/LastHomePrison.lua`
  - `media/lua/client/LastStand/LastHomeSchool.lua`
  - `media/lua/client/LastStand/LastHomeVilla.lua`
  - `specs/LH-10-timers-skip.md`
  - Fonctionnalités implémentées :
    - prep vague 1 = `2 * 60`, prep vagues suivantes = `5 * 60`, vague = `5 * 60`
    - skip de la prep via touche `N`, solo direct ou commande réseau selon le runtime
    - HUD de skip + debounce client pour éviter les doubles demandes
    - spawns de vagues au sol pour la Villa
    - désactivation des zombies vanilla dans les 4 challenges (`SandboxVars.Zombies = 6`, multipliers/respawn/rally à 0)
    - nettoyage des zombies ambiants autour de la base au début de la prep et au démarrage de vague
    - Villa forcée au **Sud** et attraction des vagues recentrée sur des impulsions sonores type alarme vers la base
  - Commits associés :
    - `9da0397` — `LH-10: ajouter le skip de vague et réduire les timers`
    - `5e0335d` — `LH-10: debounce la demande de skip de vague`
    - `b3dc132` — `fix: aggro des vagues et zombies vanilla des challenges`

- [x] Challenges PZ (menu Challenges)
  - `media/lua/client/LastStand/LastHomeHospital.lua`
  - `media/lua/client/LastStand/LastHomeVilla.lua`
  - `media/lua/client/LastStand/LastHomePrison.lua`
  - `media/lua/client/LastStand/LastHomeSchool.lua`
  - `media/lua/server/LastHomeServer.lua` (handler `SetHouse`)
  - `media/lua/server/LastHomeWaves.lua` (`hasStarted()`)
  - `mod.info` (`poster=poster.png`, `version=0.4.0`)
  - Fonctionnalités implémentées :
    - 4 challenges enregistrés via `Events.OnChallengeQuery.Add()`
    - chaque challenge force la maison correspondante côté serveur
    - images de preview 200x200 + poster 256x256
  - Correctifs post-review appliqués :
    - verrouillage serveur de la maison challenge via `houseSelectionLocked`
    - surcharge autorisée d'une rotation initiale tant que les vagues n'ont pas démarré
    - re-téléport des joueurs déjà assignés + refill immédiat si `SetHouse` corrige une rotation initiale
    - garde client `_houseSelectionSent` pour éviter les doublons `SetHouse`
    - API explicite `LastHomeWaves.hasStarted()` + log debug sur le no-op `SetHouse` avec même maison

- [x] Fallback solo role picker (mode Challenge)
  - `media/lua/client/LastHomeClient.lua`
  - `media/lua/client/LastHomeRolePicker.lua`
  - Fonctionnalités implémentées :
    - `isSinglePlayerRuntime()` détecte le solo (isClient + getOnlinePlayers)
    - `TickRolePickerFallback` ouvre le picker localement après 3s si le serveur ne répond pas
    - `applyRoleLocally()` duplique la logique d'applyRole côté client (items, skills, stats, equip, unlimitedCarry)
    - `openLocal()` + mode "solo" dans `onChooseRole` du RolePicker
    - `showRoleAssigned` déclenché en solo via forward declaration
    - `roleRequestSent` reset dans `onGameStart` pour permettre le Retry en mode Challenge

## Backlog

### Priorité haute
- [ ] Vérification en jeu solo/LAN de LH-03 à LH-10 (timers réels, skip, spectateurs, score, spawn maison, stock partagé, confinement, HUD, sync solo)
- [ ] Vérification en jeu multijoueur du picker de rôles, des téléports de spawn, du refill Builder/maison, du confinement serveur et du skip de vague
- [ ] Valider en jeu la pression zombie sur la Villa avec l'attraction par impulsions sonores (portée, fréquence, sensation de horde)

### Plus tard
- [ ] Loot structuré dans les environs des maisons si nécessaire
- [ ] HUD / notifications plus complètes pour Last Home
- [ ] Ajustements d'équilibrage des rôles si nécessaire après tests
- [ ] Refactor complémentaire: extraire le reste de `applyRole` / `addRoleItems` dans un helper shared pour finir d'éliminer la duplication client/serveur
- [ ] Vérifier `Events.OnTick.Remove` en B41 — si l'API n'existe pas, le tick fallback tourne en idle (review point 2, non-bloquant)

## Notes d'implémentation

- Les doublons de rôles sont autorisés dans Last Home
- Le rôle `mecanicien` est supprimé
- Le `builder` conserve `setUnlimitedCarry` et son refill toutes les 10 minutes en temps réel
- LH-03 introduit `LastHomeShared.lua` pour mutualiser `round()`, `getScenarioPlayers()` et `getNowSeconds()`
- LH-04 étend `LastHomeShared.lua` avec la définition des 4 maisons, leurs zones de spawn et leurs conteneurs de stock dédiés
- LH-05 ajoute un `boundary` rectangulaire par maison et un confinement **autoritatif côté serveur**, avec affichage HUD côté client
- LH-07 déplace la sync solo sur `Events.OnTick`, corrige la détection `isInsideBoundary()` pour les objets joueur PZ et ajoute un indicateur HUD local `Zone: IN/OUT`
- LH-08 extrait la logique commune d'équipement/charge dans `LastHomeShared.lua` (`applyCarryProfile`, `primeRoleLoadout`, `equipRoleItems`) pour réduire la duplication client/serveur
- LH-10 réduit les timers de vague et ajoute le skip de prep via `N`, en conservant `pendingDirections` grâce à `startWave(false)` lors du skip
- Pour la Villa, les vagues sont actuellement forcées au **Sud** et l'attraction repose sur des impulsions sonores centrées sur la base plutôt que sur un ciblage d'aggro zombie par zombie
- Les challenges Last Home utilisent désormais `SandboxVars.Zombies = 6` pour couper la pop vanilla ; `5` correspond seulement à une population faible dans PZ
- Le stock maison est injecté dans un conteneur vanilla existant, avec fallback sur le conteneur le plus proche dans la zone si besoin
- L'implémentation de LH-02 s'inspire de la structure d'Escapade Express, mais sans logique de verrouillage des rôles
- La backlog courante doit être maintenue ici à chaque ticket terminé ou corrigé
