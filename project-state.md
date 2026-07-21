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
- ⏳ Le prochain ticket recommandé est **LH-04**

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

## Backlog

### Priorité haute
- [ ] **LH-04 — Maison, réparations et défense**
  - sélection aléatoire d'un bâtiment vanilla parmi les 4 validés
  - spawn des joueurs dans la zone du bâtiment choisi
  - calcul du centre et des points de spawn à 40 tiles
  - synchronisation client du bâtiment courant
  - intégration avec les réparations / barricades vanilla
  - préparation du loot structuré dans les environs

### Plus tard
- [ ] Vérification en jeu solo/LAN du système de vagues LH-03 (timer réel, spectateurs, score)
- [ ] Vérification en jeu multijoueur du picker de rôles et du refill Builder
- [ ] HUD / notifications plus complètes pour Last Home
- [ ] Ajustements d'équilibrage des rôles si nécessaire après tests

## Notes d'implémentation

- Les doublons de rôles sont autorisés dans Last Home
- Le rôle `mecanicien` est supprimé
- Le `builder` conserve `setUnlimitedCarry` et son refill toutes les 10 minutes en temps réel
- LH-03 introduit `LastHomeShared.lua` pour mutualiser `round()`, `getScenarioPlayers()` et `getNowSeconds()`
- L'implémentation de LH-02 s'inspire de la structure d'Escapade Express, mais sans logique de verrouillage des rôles
- La backlog courante doit être maintenue ici à chaque ticket terminé ou corrigé
