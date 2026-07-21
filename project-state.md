# Project State

## Résumé

- Projet : **Last Home**
- Repo : `/Users/kim/Documents/Zomboid/last-home`
- Branche de travail actuelle : `feat/lh-02-roles`
- Référence utilisée : `/Users/kim/Documents/Zomboid/EscapadeExpress`

## État actuel

- ✅ Les specs **LH-01** à **LH-04** sont rédigées et validées
- ✅ **LH-02** est implémenté
- ⏳ Le prochain ticket recommandé est **LH-03**
- ⏳ **LH-04** dépend en partie de l'infrastructure de vagues et de maison

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

## Backlog

### Priorité haute
- [ ] **LH-03 — Vagues**
  - cycle prep 10 min / vague 10 min
  - scaling du nombre de zombies selon vague + joueurs vivants
  - directions croissantes (1 / 2 / 3 / 360)
  - annonces serveur/client
  - gestion des zombies restants si le timer expire
  - mode spectateur : 1 spawn zombie par vague
  - score = nombre de vagues survécues

### Priorité moyenne
- [ ] **LH-04 — Maison, réparations et défense**
  - sélection aléatoire d'un bâtiment vanilla parmi les 4 validés
  - spawn des joueurs dans la zone du bâtiment choisi
  - calcul du centre et des points de spawn à 40 tiles
  - synchronisation client du bâtiment courant
  - intégration avec les réparations / barricades vanilla
  - préparation du loot structuré dans les environs

### Plus tard
- [ ] HUD / notifications plus complètes pour Last Home
- [ ] Écran ou message de game over avec score final
- [ ] Vérification en jeu multijoueur du picker de rôles et du refill Builder
- [ ] Ajustements d'équilibrage des rôles si nécessaire après tests

## Notes d'implémentation

- Les doublons de rôles sont autorisés dans Last Home
- Le rôle `mecanicien` est supprimé
- Le `builder` conserve `setUnlimitedCarry` et son refill toutes les 10 minutes
- L'implémentation de LH-02 s'inspire de la structure d'Escapade Express, mais sans logique de verrouillage des rôles
