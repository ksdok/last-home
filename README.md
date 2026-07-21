# Last Home

Mod coop pour Project Zomboid (B41). Les joueurs défendent un bâtiment contre des vagues de zombies croissantes. Entre chaque vague, ils craftent, réparent et préparent leurs défenses. Survie la plus longue possible.

## Concept

- **Coop** jusqu'à 8 joueurs (doublons de rôles autorisés)
- **Vagues** toutes les 10 minutes, de plus en plus dangereuses
- **Bâtiment aléatoire** parmi 4 (Hôpital, Villa, Prison, École élémentaire)
- **Direction croissante** des hordes : 1 direction au début, puis 2, 3, jusqu'à 360°
- **Permadeath** : le joueur mort devient spectateur et peut faire spawner 1 zombie pendant les vagues suivantes
- **17 rôles** repris d'Escapade Express (sans Mécanicien, avec Builder)
- **Survie illimitée** : le score = nombre de vagues survécues

## Spécifications

| Spec | Description | Statut |
|------|-------------|--------|
| [LH-01](specs/LH-01-concept.md) | Concept et questions validées | ✅ |
| [LH-02](specs/LH-02-roles.md) | 17 rôles réajustés | ✅ |
| [LH-03](specs/LH-03-vagues.md) | Vagues, scaling, directions, spectateur | ✅ |
| [LH-04](specs/LH-04-maison.md) | Bâtiment, réparations, défense | ✅ |

## État

- ✅ Spécifications complètes (LH-01 à LH-04)
- ✅ Implémentation de **LH-02** terminée
- ⏳ **LH-03** et **LH-04** restent à implémenter
- 📋 Backlog et suivi courant dans [project-state.md](project-state.md)

## Structure du mod

```text
last-home/
  mod.info
  README.md
  project-state.md
  media/
    lua/
      server/
        LastHomeServer.lua      -- rôles, attribution, refill Builder
        LastHomeWaves.lua       -- à venir
      client/
        LastHomeClient.lua      -- bootstrap client / ouverture du picker
        LastHomeRolePicker.lua  -- picker de rôles
      shared/
        LastHomeRoles.lua       -- définitions des 17 rôles
  specs/
    LH-01-concept.md
    LH-02-roles.md
    LH-03-vagues.md
    LH-04-maison.md
```

## Dépendances

- Aucune dépendance externe — mod standalone
- Inspiration d'Escapade Express pour le système de rôles (github.com/ksdok/escapade-express)

## Licence

MIT
