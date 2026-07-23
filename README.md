# Last Home

Mod coop pour Project Zomboid (B41). Les joueurs défendent un bâtiment contre des vagues de zombies croissantes. Entre chaque vague, ils craftent, réparent et préparent leurs défenses. Survie la plus longue possible.

## Concept

- **Coop** jusqu'à 8 joueurs (doublons de rôles autorisés)
- **Vagues** en temps réel : prep 2 min pour la vague 1, puis 5 min ; chaque vague dure 5 min
- **Bâtiment aléatoire** parmi 4 (Hôpital, Villa, Prison, École élémentaire), ou forcé par challenge
- **Direction croissante** des hordes : 1 direction au début, puis 2, 3, jusqu'à 360° — avec exceptions de gameplay par lieu si nécessaire
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
| [LH-05](specs/LH-05-zone-confinement.md) | Zone de confinement autour de la maison | ✅ |
| [LH-06](specs/LH-06-hud.md) | Refonte HUD et position | ✅ |
| [LH-07](specs/LH-07-fix-sync-solo.md) | Fix sync solo / confinement | ✅ |
| [LH-08](specs/LH-08-equipement-roles.md) | Équipement des rôles et helpers partagés | ✅ |
| [LH-10](specs/LH-10-timers-skip.md) | Timers réduits + skip de vague | ✅ |

## État

- ✅ Specs versionnées complètes pour **LH-01** à **LH-08** et **LH-10**
- ✅ Implémentation de **LH-02** à **LH-08** et **LH-10** terminée
- ✅ Confinement solo fiabilisé (sync dédiée, détection boundary corrigée, HUD IN/OUT)
- ✅ 4 challenges enregistrés dans le menu (Hôpital, Villa, Prison, École)
- ✅ Timers LH-10 : prep vague 1 = 2 min, prep suivantes = 5 min, vague = 5 min, skip via touche `N`
- ✅ Challenges Last Home : zombies vanilla désactivés, nettoyage ambiant autour de la base, Villa forcée au **Sud**
- ✅ Attraction des vagues recentrée sur des impulsions sonores type alarme vers la base pour fiabiliser la pression zombie
- 📋 Backlog et suivi courant dans [project-state.md](project-state.md)

## Structure du mod

```text
last-home/
  mod.info
  poster.png
  README.md
  project-state.md
  media/
    lua/
      server/
        LastHomeServer.lua      -- rôles, attribution, refill Builder, SetHouse
        LastHomeWaves.lua       -- vagues, scaling, directions, spectateur, confinement
      client/
        LastStand/
          LastHomeHospital.lua  -- challenge Hôpital
          LastHomeVilla.lua     -- challenge Villa
          LastHomePrison.lua    -- challenge Prison
          LastHomeSchool.lua    -- challenge École
          *.png                 -- images de preview (200x200)
        LastHomeClient.lua      -- bootstrap client / HUD / sync solo
        LastHomeRolePicker.lua  -- picker de rôles
      shared/
        LastHomeRoles.lua       -- définitions des 17 rôles
        LastHomeShared.lua      -- helpers partagés (maisons, coords, timers, boundary)
  specs/
    LH-01-concept.md
    LH-02-roles.md
    LH-03-vagues.md
    LH-04-maison.md
    LH-05-zone-confinement.md
    LH-06-hud.md
    LH-07-fix-sync-solo.md
    LH-08-equipement-roles.md
    LH-10-timers-skip.md
```

## Dépendances

- Aucune dépendance externe — mod standalone
- Inspiration d'Escapade Express pour le système de rôles (github.com/ksdok/escapade-express)

## Licence

MIT
