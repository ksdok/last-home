# LH-04 (M) - Last Home: Maison, reparations et defense

## Contexte

La maison est le point central de Last Home: c'est ce que les joueurs defendent.
Elle est endommagee par les zombies pendant les vagues et reparee/renforcee par
les joueurs entre les vagues. La maison utilise une structure vanilla (pas de
custom build).

Les ressources de reparation sont illimitees dans la maison (stock infini) pour
l'instant. Le loot dans les environs est a reflechir (le Voleur peut deja
aller piller les maisons aux alentours entre les vagues).

## La maison

### Choix de la maison
- **Maison vanilla** (pas de custom build)
- La maison est definie une fois au debut de la partie (au spawn)
- **Maison aleatoire**: tirée au sort parmi une liste de 4 batiments vanilla
  adaptees a chaque nouvelle partie (plus de rejouabilite)
- La liste des batiments candidates (coords + zone de spawn):

| Batiment | Centre (X, Y, Z) | Zone de spawn |
|----------|-------------------|---------------|
| Hopital | 12380, 3682, 0 | Radius 4 autour du centre |
| Villa | 13532, 2842, 1 | X=13352 a 13533, Y=2839 a 2843, Z=1 (box) |
| Prison | 7683, 11863, 0 | Radius 4 autour du centre |
| Ecole elementaire | 10613, 9974, 0 | Radius 4 autour du centre |

- Au `OnGameStart`, un des 4 batiments est tire au sort
- Les joueurs spawn dans la zone de spawn definie pour ce batiment
- Les points de spawn des vagues sont calcules a 40 tiles du centre du batiment

### Perimetre de la maison
- La maison est definie par ses coordonnees (centre + bounding box)
- Les points de spawn des zombies sont calcules par rapport au centre
- Les directions (N/S/E/O) sont definies par rapport au centre

### Endommagement
- Les zombies peuvent endommager: murs, portes, fenetres, barricades
- Les degats sont gerees par le moteur PZ standard (les zombies attaquent les
  obstacles sur leur chemin)
- Pas de mecanique custom d'endommagement -- on utilise le comportement vanilla
  des zombies qui attaquent les obstacles bloquants

### Reparations et renforcement
Pendant les phases de preparation, les joueurs peuvent:
- **Reparer** les murs, portes, fenetres detruits (carpentry vanilla)
- **Construire des barricades** (planches, metal) sur les fenetres/portes
- **Renforcer les murs** (metal welding pour murs metal)
- **Construire des structures** (murs supplementaires, tours de vigilance)
- **Fabriquer des pieges** (alarmes, pieges a l'exterieur)

### Ressources
- **Stock illimite dans la maison** (pour l'instant)
- Le Builder a un refill automatique toutes les 10 min (EveryTenMinutes) avec:
  Planks x50, Nails x200, SheetMetal x20, ScrapMetal x30, Wire x10, DuctTape
  x10, Rope x5, MetalPipe x10, Glue x5, MetalBar x10, Screws x100
- Les autres joueurs peuvent utiliser les ressources du stock pour crafter
  et reparer (pas limite au Builder)
- **Loot structure dans les environs**: du loot apparait dans des batiments
  voisins a definir (marques sur la map). Les joueurs (Voleur, Eclaireur,
  Athlete) peuvent aller le recuperer entre les vagues.

## Defense

### Strategies defensives
Les joueurs peuvent adopter differentes strategies selon les roles:
- **Sniper** au 2e etage (tir longue distance par les fenetres)
- **Rambo/Samourai** en defense rapprochee aux breches
- **Demolisseur** lance des explosions sur les groupes avant qu'ils atteignent
  la maison
- **Pompier** demoli des murs pour creer des sorties de secours
- **Builder** construit/renforce les defenses pendant les pauses
- **Geek** pose des alarmes et pieges electroniques
- **Survivaliste** pose des pieges exterieurs (traps)
- **Mule** garde le stock de munitions/soins au centre

### Barricades
- Les barricades sont construites avec le systeme vanilla PZ (planches + nails)
- Les barricades metal necessitent MetalWelding (Builder)
- Les barricades peuvent etre detruites par les zombies pendant les vagues
- Les barricades peuvent etre reparees/remplacees entre les vagues

### Pieges
- Pieges exterieurs (Survivaliste): systeme vanilla de trapping
- Pieges electroniques (Geek): alarmes, capteurs de mouvement
- Les pieges sont deployes pendant les phases de prep
- Les pieges sont declenches par les zombies pendant les vagues

## Architecture technique

### Fichier prevu
Aucun fichier dedie -- la gestion de la maison est integree dans:
- `media/lua/server/LastHomeServer.lua` -- definition de la maison (coords,
  bounding box), game over
- `media/lua/server/LastHomeWaves.lua` -- calcul des points de spawn par
  rapport a la maison
- `media/lua/client/LastHomeClient.lua` -- UI timer, annonces, affichage
  perimetre (optionnel)

### Variables serveur
```lua
Server = {
    house = {
        centerX = 0,
        centerY = 0,
        centerZ = 0,
        boundingBox = { min = {x, y}, max = {x, y} },
    },
    -- ...
}
```

### Definition de la maison
- Au `OnGameStart`, la maison est definie (coords fixes ou aleatoires)
- Les coords sont synchronisees aux clients pour l'affichage
- Les points de spawn des vagues sont calcules par rapport au centre

## Critere d'acceptation

1. La maison est vanilla (pas de custom build)
2. Les zombies peuvent endommager murs, portes, fenetres (comportement vanilla)
3. Les joueurs peuvent reparer entre les vagues (carpentry vanilla)
4. Les joueurs peuvent construire des barricades (vanilla)
5. Les joueurs peuvent renforcer avec du metal (MetalWelding, Builder)
6. Les joueurs peuvent fabriquer des pieges (trapping, electronique)
7. Le Builder a un refill automatique de ressources toutes les 10 min
8. Les ressources sont illimitees dans la maison (pour l'instant)
9. Le Sniping depuis le 2e etage est possible (depend du choix de maison)

## Questions en attente

1. **Maison specifique fixe** ou **aleatoire** parmi une liste ? **[VALIDE: aleatoire parmi une liste de maisons vanilla adaptees]**
2. **Choix de la maison vanilla** : **[VALIDE: 4 batiments -- Hopital (12380,3682,0), Villa (13532,2842,1, box X=13352-13533 Y=2839-2843), Prison (7683,11863,0), Ecole elementaire (10613,9974,0)]**
3. **Loot dans les environs**: systeme structure ou seulement le Voleur ? **[VALIDE: systeme structure -- loot qui apparait dans des batiments voisins, marques sur la map, recupere par Voleur/Eclaireur/Athlete]**
4. **Affichage du perimetre** de la maison sur la map (optionnel) ? **[VALIDE: non -- les joueurs reperent la maison visuellement]**

## Dependencies

- Aucune dependance externe -- mod standalone
- Utilise les systemes vanilla PZ: carpentry, metal welding, trapping,
  barricades, degats zombies sur obstacles

## Taille estimee

Medium (M) -- principalement de la configuration (choix de maison, coords) et
de l'integration avec les systemes vanilla. Pas beaucoup de code custom --
la majorite est geree par PZ vanilla.