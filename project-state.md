# Project State

## Résumé

- Projet : **Last Home**
- Repo : `/Users/kim/Documents/Zomboid/last-home`
- Branche de travail actuelle : `main`
- Référence utilisée : `/Users/kim/Documents/Zomboid/EscapadeExpress`

## État actuel

- ✅ Les specs **LH-01** à **LH-04** sont rédigées et validées
- ✅ **LH-02** est implémenté et corrigé après review
- ✅ **LH-03** est implémenté et corrigé après review
- ✅ **LH-04** est implémenté et corrigé après review
- ✅ 4 challenges enregistrés dans le menu Challenges de PZ (Hôpital, Villa, Prison, École)
- ⏳ Le prochain ticket recommandé est la **vérification en jeu** (solo/LAN puis multijoueur)

## Terminé

### Specs
- [x] LH-01 — Concept et spécification
- [x] LH-02 — Rôles réajustés
- [x] LH-03 — Vagues
- [x] LH-04 — Maison, réparations et défense

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

- [x] Challenges PZ (menu Challenges)
  - `media/lua/client/LastStand/LastHomeHospital.lua`
  - `media/lua/client/LastStand/LastHomeVilla.lua`
  - `media/lua/client/LastStand/LastHomePrison.lua`
  - `media/lua/client/LastStand/LastHomeSchool.lua`
  - `media/lua/server/LastHomeServer.lua` (handler `SetHouse`)
  - `mod.info` (`poster=poster.png`, `version=0.4.0`)
  - Fonctionnalités implémentées :
    - 4 challenges enregistrés via `Events.OnChallengeQuery.Add()`
    - chaque challenge force la maison correspondante côté serveur
    - images de preview 200x200 + poster 256x256

## Backlog

### Priorité haute
- [ ] Vérification en jeu solo/LAN de LH-03 + LH-04 (timer réel, spectateurs, score, spawn maison, stock partagé)
- [ ] Vérification en jeu multijoueur du picker de rôles, des téléports de spawn et du refill Builder/maison

### Plus tard
- [ ] Loot structuré dans les environs des maisons si nécessaire
- [ ] HUD / notifications plus complètes pour Last Home
- [ ] Ajustements d'équilibrage des rôles si nécessaire après tests

## Notes d'implémentation

- Les doublons de rôles sont autorisés dans Last Home
- Le rôle `mecanicien` est supprimé
- Le `builder` conserve `setUnlimitedCarry` et son refill toutes les 10 minutes en temps réel
- LH-03 introduit `LastHomeShared.lua` pour mutualiser `round()`, `getScenarioPlayers()` et `getNowSeconds()`
- LH-04 étend `LastHomeShared.lua` avec la définition des 4 maisons, leurs zones de spawn et leurs conteneurs de stock dédiés
- Le stock maison est injecté dans un conteneur vanilla existant, avec fallback sur le conteneur le plus proche dans la zone si besoin
- L'implémentation de LH-02 s'inspire de la structure d'Escapade Express, mais sans logique de verrouillage des rôles
- La backlog courante doit être maintenue ici à chaque ticket terminé ou corrigé
