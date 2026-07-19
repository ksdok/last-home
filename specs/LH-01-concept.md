# LH-01 (L) - Last Home: Concept et specification

## Contexte

Last Home est un mod coop pour Project Zomboid (B41). Les joueurs defendent
une maison contre des vagues de zombies croissantes. Entre chaque vague, ils
doivent crafter, reparer, preparer leurs defenses. Survie la plus longue
possible.

## Concept general

Les joueurs spawn dans une maison. Toutes les 5 a 10 minutes, une horde de
zombies attaque la maison. Entre les vagues, les joueurs ont un temps de
preparation pour crafter, reparer les barricades, soigner les blessures,
chercher des ressources autour de la maison. Les vagues sont de plus en plus
nombreuses et dangereuses. Le but est de survivre le plus longtemps possible.

## Regles

### Objectif
- Survivre le plus longtemps possible
- Pas de fin predefinie -- la partie se termine quand tous les joueurs sont morts
- **A valider**: y a-t-il un nombre de vagues a atteindre pour "gagner" ? **[VALIDE: survie illimitee, score = nombre de vagues survecues]**

### Joueurs
- Coop (tous dans la meme equipe)
- **A valider**: nombre max de joueurs ? **[VALIDE: 8 joueurs max]**
- Chaque joueur choisit un role au spawn (via un role picker)
- **A valider**: roles uniques ou doublons autorises ? **[VALIDE: doublons autorises]**

### Mort
- **A valider**: permadeath (spectateur jusqu'a la fin) ou respawn au debut
  de la vague suivante ? **[VALIDE: permadeath -- le joueur mort devient
  spectateur et peut faire spawner 1 zombie ou il veut pendant chaque vague
  suivante]**
- **A valider**: si tous les joueurs meurt pendant une vague = game over ?

### Vagues
- Une vague toutes les 5 a 10 minutes (premier vague apres un temps de prep)
- Les vagues sont de plus en plus difficiles:
  - Vague 1-3: quelques zombies, lents
  - Vague 4-6: plus de zombies, quelques-uns plus rapides
  - Vague 7-10: beaucoup de zombies, sprinters possibles
  - Vague 10+: horde massive, zombies speciaux possibles
  **[VALIDE: a chaque nouvelle vague, les zombies deviennent un peu plus
  agressifs et un peu plus rapides (progression continue, pas par paliers)]**
- **A valider**: intervalle entre vagues (5 min fixe ? 10 min ? variable ?) **[VALIDE: 10 min fixe]**
- **A valider**: le premier intervalle est-il plus long (prep initiale) ? **[VALIDE: non, 10 min comme les autres]**

### Spawn des hordes
- **A valider**: les zombies viennent d'une direction ? De plusieurs ?
  - Option A: une direction par vague (annoncee avant)
  - Option B: 360 degres (tous les cotes)
  - Option C: de plus en plus de directions au fil des vagues
  **[VALIDE: Option C -- direction croissante (1 direction au debut, puis
  2, puis 360 aux vagues avancees), annoncee avant chaque vague]**
- **A valider**: les zombies spawnent a quelle distance de la maison ?

## La maison

### Structure
- **A valider**: maison custom build ou maison vanilla existante ? **[VALIDE: vanilla]**
- La maison peut etre endommagee par les zombies (murs, portes, fenetres)
- Les joueurs peuvent reparer, barricader, renforcer pendant les pauses

### Reparations et craft
- Entre les vagues, les joueurs peuvent:
  - Reparer les murs, portes, fenetres detruits
  - Construire des barricades
  - Crafter des pieges
  - Fabriquer des armes
  - Soigner les blessures
- **A valider**: le materiau de reparation vient d'ou ?
  - Option A: ressources autour de la maison (arbres, deconstruction)
  - Option B: stock de ressources illimite dans la maison
  - Option C: loot dans les environs entre les vagues
  **[VALIDE: Option B -- stock illimite dans la maison pour l'instant;
  loot dans les environs a reflechir]**

## Roles

Les roles sont repris d'Escapade Express (EE-12) et reajustes pour le mode
coop defense. Certains roles sont plus utiles que d'autres en defense.

### Roles existants (d'EE-12) a reajuster

| Role | Style | Utilite en defense |
|------|-------|--------------------|
| Soldat | Combat equilibre | Defense principale, tir |
| Voleur | Furtif | Peu utile en defense fixe |
| Local | Survie urbaine | Craft, reparations, gestion ressources |
| Medic | Soin | Indispensable (soigner entre les vagues) |
| Rambo | Tank melee | Tanking au contact |
| Sniper | Tir longue distance | Eliminer les zombies a distance |
| Samourai | Katana / mobility | Combat melee si breach |
| Geek | Cerveau / crafting | Pieges, gadgets, reparations avancees |
| Survivaliste | Autonomie / nature | Pieges, nourriture, autonomie |
| Pompier | Sauveur / anti-feu | Demolition, secours, resistant |
| Mecanicien | Repare vehicule | A revoir (pas de vehicule en defense) |
| Builder | Construction / craft | Indispensable (construire, renforcer, reparer la maison) |
| Athlete | Vitesse / mobilite | Alerte, va chercher des ressources loin |
| Eclaireur | Exploration / discret | Repere la direction des hordes |
| Demolisseur | Explosions / chaos | Degats de zone sur les hordes |
| Invincible | Tout au max | A nerf pour la balance coop |
| Mule | Porteur / transport | Transport de ressources, stockage |
| Civil | Lambda / difficile | Challenge volontaire |

### Ajustements prevus
- **A valider**: le Mecanicien doit-il etre remplace ou ajuste ? **[VALIDE: supprime (pas de vehicule en defense) -- les reparations seront couvertes par le Local/Geek]**
- **A valider**: l'Invincible doit-il etre nerf ? **[VALIDE: garder tel quel, les joueurs s'autoregulent]**
- **A valider**: le Voleur a-t-il une utilite en defense fixe ? **[VALIDE: garder -- il pourra aller piller les maisons aux alentours entre les vagues]**
- **A valider**: faut-il des roles specifiques au mode defense ? (ex: Architecte
  pour construire/renforcer, Artificier pour les pieges)
  **[VALIDE: non -- le Builder existe deja et couvre la construction/renforcement;
  les pieges sont couverts par Geek/Survivaliste]**

## Mecaniques specifiques

### Phase de preparation
- Annonce de la prochaine vague (direction, taille estimee)
- Timer visible pour la prochaine vague
- Les joueurs craftent, reparent, se soignent

### Phase d'attaque
- Les zombies spawnent et avancent vers la maison
- Les joueurs defendent
- La vague se termine quand tous les zombies de la vague sont morts
- **A valider**: que se passe-t-il si la vague n'est pas eliminee a temps ?
  - Option A: la vague suivante arrive quand meme (plus de zombies)
  - Option B: timer extended jusqu'a ce que la vague soit eliminee
  - Option C: la vague se retire apres un certain temps (survie = win)
  **[VALIDE: Option A -- la vague suivante arrive quand meme (les zombies
  restants s'ajoutent a la nouvelle vague)]**

### Progression entre les vagues
- **A valider**: les joueurs gagnent-ils quelque chose entre les vagues ?
  - Option A: points pour debloquer de l'equipement
  - Option B: loot qui apparait dans la maison
  - Option C: augmentation des skills
  - Option D: rien (survie pure)
  **[VALIDE: Option D -- rien pour l'instant (survie pure)]**

### Evenements
- **A valider**: evenements aleatoires entre les vagues ?
  - Helicoptere qui largue du loot
  - PNJ a sauver
  - Maladie qui se declenche
  - Penurie d'eau ou d'electricite
  **[VALIDE: aucun event pour l'instant]**
- **A valider**: evenements pendant les vagues ?
  - Zombie special (plus rapide, plus resistant, explosion)
  - Horde qui vient de plusieurs directions
  **[VALIDE: aucun event pour l'instant]**

## Architecture technique

### Fichiers prevus
- `media/lua/server/LastHomeServer.lua` -- logique serveur (vagues, zombies, timer, events)
- `media/lua/client/LastHomeClient.lua` -- logique client (UI, timer, notifications, annonces)
- `media/lua/client/LastHomeRolePicker.lua` -- picker de roles
- `media/lua/shared/LastHomeRoles.lua` -- definitions des roles reajustes
- `media/lua/server/LastHomeWaves.lua` -- gestion des vagues (spawn, scaling, direction)

### Evenements PZ utilises
- `OnGameStart` -- setup de la maison, premiere annonce
- `OnPlayerDeath` -- gestion de la mort
- `EveryMinutes` ou timer custom -- timer des vagues, annonces
- `OnZombieDeath` -- verifier si la vague est terminee

### Structure du mod
```
last-home/
  modinfo.txt
  media/
    lua/
      server/
        LastHomeServer.lua
        LastHomeWaves.lua
      client/
        LastHomeClient.lua
        LastHomeRolePicker.lua
      shared/
        LastHomeRoles.lua
  specs/
    LH-01-concept.md       (ce fichier)
    LH-02-roles.md         (a creer -- roles reajustes en detail)
    LH-03-vagues.md        (a creer -- details techniques des vagues)
    LH-04-maison.md        (a creer -- structure, reparations, defense)
    LH-05-events.md        (non necessaire -- aucun event valide dans LH-01 Q15)
```

## Critere d'acceptation

1. Les joueurs spawn dans la maison
2. Chaque joueur choisit un role au spawn
3. Les vagues arrivent toutes les 5-10 minutes
4. Les vagues sont de plus en plus difficiles
5. Les joueurs peuvent crafter et reparer entre les vagues
6. La maison peut etre endommagee et reparee
7. Les zombies attaquent la maison pendant les vagues
8. Un timer affiche le temps avant la prochaine vague
9. La prochaine vague est annoncee (direction, taille)
10. La partie se termine quand tous les joueurs sont morts

## Questions en attente (a valider)

1. **Nombre max de joueurs** ? **[VALIDE: 8 joueurs max]**
2. **Roles**: uniques ou doublons autorises ? **[VALIDE: doublons autorises]**
3. **Mort**: permadeath ou respawn au debut de la vague suivante ? **[VALIDE: permadeath -- spectateur, peut spawner 1 zombie ou il veut pendant chaque vague suivante]**
4. **Nombre de vagues pour gagner** ou survie illimitee ? **[VALIDE: survie illimitee, score = nombre de vagues survecues]**
5. **Intervalle entre vagues**: 5 min, 10 min, variable ? **[VALIDE: 10 min fixe]**
6. **Prep initiale**: plus longue que les autres intervalles ? **[VALIDE: non, 10 min comme les autres]**
7. **Direction des hordes**: fixe, 360, ou croissante ? **[VALIDE: croissante -- 1 direction au debut, puis 2, puis 360 aux vagues avancees, annoncee avant chaque vague]**
8. **Maison**: custom ou vanilla ? **[VALIDE: vanilla]**
9. **Ressources**: autour de la maison, illimitees, ou loot entre les vagues ? **[VALIDE: illimitees dans la maison pour l'instant; loot environs a reflechir]**
10. **Mecanicien**: remplacer ou ajuster (pas de vehicule) ? **[VALIDE: supprime -- reparations couvertes par Local/Geek]**
11. **Invincible**: nerf pour la balance ? **[VALIDE: garder tel quel, joueurs s'autoregulent]**
12. **Voleur**: utilite en defense fixe ? **[VALIDE: garder -- il pourra piller les maisons aux alentours entre les vagues]**
13. **Nouveaux roles**: Architecte, Artificier ? **[VALIDE: non -- Builder existe deja; pieges couverts par Geek/Survivaliste]**
14. **Progression**: points, loot, skills, ou rien ? **[VALIDE: rien pour l'instant (survie pure)]**
15. **Evenements**: lesquels entre/pendant les vagues ? **[VALIDE: aucun event pour l'instant]**
16. **Vague non eliminee a temps**: que se passe-t-il ? **[VALIDE: la vague suivante arrive quand meme (zombies restants s'ajoutent a la nouvelle vague)]**
17. **Zombies speciaux**: types, a partir de quelle vague ? **[VALIDE: pas de zombies speciaux -- a chaque nouvelle vague, les zombies deviennent un peu plus agressifs et un peu plus rapides (progression continue, pas par paliers)]**

## Dependencies

- Aucune dependance externe -- mod standalone
- Inspiration d'Escapade Express pour le systeme de roles (EE-12, EE-13)

## Taille estimee

Large (L) -- systeme de vagues + scaling + maison destructible/reparable +
reajustement de 17 roles + events + UI timer + annonces