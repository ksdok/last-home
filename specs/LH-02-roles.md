# LH-02 (M) - Last Home: Roles reajustes

## Contexte

Les roles sont repris d'Escapade Express (EE-12/EE-13) et reajustes pour le
mode coop defense de maison. 17 roles sont retenus (le Mecanicien est supprime
-- pas de vehicule en defense fixe). Les doublons sont autorises: plusieurs
joueurs peuvent prendre le meme role.

Les roles sont attribues au spawn via un role picker (UI client). Le joueur
choisit son role une fois pour toute la partie (pas de changement en cours).
La mort est permadeath: le joueur mort devient spectateur et peut faire
spawner 1 zombie ou il veut pendant chaque vague suivante (voir LH-03).

## Liste des roles (17)

### 1. Soldat
- **Role key**: `soldat`
- **Style**: Combat equilibre
- **Utilite en defense**: Defense principale, tir, couverture des entrees
- **Ajustement LH**: Aucun (identique a EE)
- **Skills**: Aiming 7, Reloading 7, Strength 5, Fitness 5, Axe 4, SmallBlade 4
- **Items**: Pistol, munitions, couteau, bandages, sac moyen
- **Stats**: endurance 0.5, panic 20

### 2. Voleur
- **Role key**: `voleur`
- **Style**: Furtif, melee
- **Utilite en defense**: Peu utile en defense fixe, mais **peut aller piller
  les maisons aux alentours entre les vagues** (loot furtif)
- **Ajustement LH**: Aucun changement de stats/items. Son role est repositionne:
  entre les vagues, il sort discrtement fouiller les maisons voisines pour
  rapporter du loot supplementaire (nourriture, outils, munitions).
- **Skills**: Sneak 8, Lightfoot 8, Nimble 8, Sprinting 6, LongBlunt 4, Strength 3
- **Items**: Crowbar, sac leger, bandages, water, nourriture
- **Stats**: endurance 0.3, panic 15

### 3. Local
- **Role key**: `local_`
- **Style**: Survie urbaine, craft
- **Utilite en defense**: Craft, reparations, gestion des ressources. Role
  polyvalent de soutien logistique.
- **Ajustement LH**: Aucun (identique a EE)
- **Skills**: Carpentry 6, Cooking 6, Mechanics 4, Electricity 4, PlantScavenging 5, Strength 4
- **Items**: Outils (hammer, saw, screwdriver), vivres, carte, sac moyen
- **Stats**: endurance 0.4, panic 25

### 4. Medic
- **Role key**: `medic`
- **Style**: Soin / support
- **Utilite en defense**: **Indispensable** -- soigne les blessures entre les
  vagues, garde l'equipe en etat de combattre
- **Ajustement LH**: Aucun (identique a EE). Stock de soins renforce.
- **Skills**: Doctor 8, Strength 3, Fitness 4, SmallBlade 4
- **Items**: Bandages x10, AlcoholWipes x5, Splint x3, Pills x3, PillsBeta x2,
  PillsVitamins x2, Antibiotics x2, duffel bag, couteau
- **Stats**: endurance 0.4, panic 20

### 5. Rambo
- **Role key**: `rambo`
- **Style**: Tank melee
- **Utilite en defense**: Tanking au contact, absorbe les zombies aux breches,
  defense rapprochee
- **Ajustement LH**: Aucun (identique a EE)
- **Skills**: Strength 10, Fitness 8, Axe 8, LongBlade 6, Sprinting 4
- **Items**: Fire Axe, machette, bandages x5, sac lourd, water, nourriture
- **Stats**: endurance 0.7, panic 10

### 6. Sniper
- **Role key**: `sniper`
- **Style**: Tir longue distance
- **Utilite en defense**: Elimine les zombies a distance avant qu'ils
  n'atteignent la maison. Idéal depuis une fenetre du 2e etage.
- **Ajustement LH**: Aucun (identique a EE)
- **Skills**: Aiming 10, Reloading 8, Sneak 6, Strength 4, Fitness 4
- **Items**: Hunting Rifle avec lunette x4, .308 x50, bandages, sac moyen
- **Stats**: endurance 0.4, panic 15

### 7. Samourai
- **Role key**: `samourai`
- **Style**: Katana / mobilite
- **Utilite en defense**: Combat melee rapide en cas de breach, intercepte les
  zombies qui entrent
- **Ajustement LH**: Aucun (identique a EE)
- **Skills**: LongBlade 10, SmallBlade 8, Sprinting 8, Nimble 8, Fitness 7, Strength 5
- **Items**: Katana, wakizashi, bandages x3, sac leger
- **Stats**: endurance 0.5, panic 10

### 8. Geek
- **Role key**: `geek`
- **Style**: Electronique / crafting
- **Utilite en defense**: Pieges electroniques, gadgets, reparations avancees
  (alarmes, capteurs, systems defensifs)
- **Ajustement LH**: Aucun (identique a EE). Particulierement utile pour les
  pieges et alarmes autour de la maison.
- **Skills**: Electrical 8, Carpentry 5, Mechanics 4, Cooking 3, Strength 3
- **Items**: Electronics components, screwdriver, livres, duct tape, sac moyen
- **Stats**: endurance 0.3, panic 30

### 9. Survivaliste
- **Role key**: `survivaliste`
- **Style**: Nature / autonomie
- **Utilite en defense**: Pieges, nourriture, autonomie. Peut poser des pieges
  exterieurs et gerer la nourriture de l'equipe.
- **Ajustement LH**: Aucun (identique a EE)
- **Skills**: PlantScavenging 8, Trapping 8, Aiming 6, Sneak 6, Carpentry 4, Cooking 5
- **Items**: Hunting Rifle, ALICE pack, pieges, nourriture, water
- **Stats**: endurance 0.4, panic 15

### 10. Pompier
- **Role key**: `pompier`
- **Style**: Sauvetage / anti-feu
- **Utilite en defense**: Demolition (murs a abattre pour creer des sorties de
  secours), secours aux joueurs en difficulte, resistant aux coups
- **Ajustement LH**: Aucun (identique a EE)
- **Skills**: Strength 8, Fitness 7, Axe 7, LongBlunt 5
- **Items**: Fire Axe, extincteur, casque de pompier, bandages x5, sac lourd
- **Stats**: endurance 0.6, panic 10

### 11. Athlete
- **Role key**: `athlete`
- **Style**: Vitesse / mobilite
- **Utilite en defense**: Alerte, va chercher des ressources loin, decoit les
  zombies en courant autour de la maison
- **Ajustement LH**: Aucun (identique a EE)
- **Skills**: Sprinting 10, Fitness 10, Nimble 8, Lightfoot 7, Strength 4, SmallBlade 4
- **Items**: Machette, sac leger, water, bandages, nourriture energique
- **Stats**: endurance 0.4, panic 15

### 12. Eclaireur
- **Role key**: `eclaireur`
- **Style**: Exploration / discret
- **Utilite en defense**: Repere la direction des hordes avant qu'elles
  n'arrivent, va chercher du loot dans les environs. Combinaison avec Voleur
  pour les sorties de loot.
- **Ajustement LH**: Aucun (identique a EE)
- **Skills**: Sneak 8, Lightfoot 7, Sprinting 6, Aiming 5, Fitness 5, SmallBlade 5
- **Items**: Machette, carte, jumelles, sac leger, water, bandages
- **Stats**: endurance 0.3, panic 20

### 13. Demolisseur
- **Role key**: `demolisseur`
- **Style**: Explosions / chaos
- **Utilite en defense**: Degats de zone sur les hordes, peut faire exploser
  des groupes de zombies avant qu'ils atteignent la maison
- **Ajustement LH**: Aucun (identique a EE)
- **Skills**: Strength 6, Fitness 5, Axe 5, LongBlunt 5, Aiming 4
- **Items**: Bombes artisanales, molotovs x5, masse, allumettes, sac lourd
- **Stats**: endurance 0.5, panic 15

### 14. Invincible
- **Role key**: `invincible`
- **Style**: Tout au max
- **Utilite en defense**: Role ultimate -- peut tout faire (tir, melee, soin,
  craft). Aucun nerf, les joueurs s'autoregulent.
- **Ajustement LH**: Aucun (garde tel quel, doublons autorises)
- **Skills**: Toutes les skills a 10 (voir EE pour la liste complete)
- **Items**: Assault rifle, katana, sledgehammer, riot helmet, army coat,
  munitions, soins lourds, ALICE pack army
- **Stats**: endurance 0.8, panic 5, fatigue 0

### 15. Mule
- **Role key**: `mule`
- **Style**: Porteur / transport
- **Utilite en defense**: Transport de ressources, stockage. Le porteur de
  l'equipe -- garde le stock de munitions, soins, outils au centre de la maison.
- **Ajustement LH**: Aucun (identique a EE)
- **Skills**: Strength 10, Fitness 7, Sprinting 10, Carpentry 4
- **Items**: ALICE pack army, duffel bag, crowbar, vivres, water, bidon
- **Stats**: endurance 0.5, panic 25

### 16. Builder
- **Role key**: `builder`
- **Style**: Construction / craft
- **Utilite en defense**: **Indispensable** -- construit, renforce, repare la
  maison. A acces a un stock de ressources illimite dans la maison et un refill
  automatique toutes les 10 min (identique a EE).
- **Ajustement LH**: Aucun (identique a EE). Le setUnlimitedCarry=true est
  conserve (portage illimité pour transporter les ressources de construction).
- **Skills**: Carpentry 10, Electricity 10, MetalWelding 10, Mechanics 10,
  Tailoring 10, Cooking 10, Strength 7, Fitness 5
- **Items**: Hammer, saw, screwdriver, wrench, welding mask, blow torch,
  crowbar, sledgehammer, garden saw, planks x50, nails x200, sheet metal x20,
  scrap metal x30, wire x10, duct tape x10, rope x5, metal pipe x10, glue x5,
  metal bar x10, screws x100, big hiking bag, boilersuit
- **Refill auto (EveryTenMinutes)**: Planks x50, Nails x200, SheetMetal x20,
  ScrapMetal x30, Wire x10, DuctTape x10, Rope x5, MetalPipe x10, Glue x5,
  MetalBar x10, Screws x100
- **Stats**: endurance 0.3, panic 20

### 17. Civil
- **Role key**: `civil`
- **Style**: Lambda / difficile
- **Utilite en defense**: Challenge volontaire. Aucune specialite, survie pure.
- **Ajustement LH**: Aucun (identique a EE)
- **Skills**: Fitness 1, Strength 1, Sneak 1, Lightfoot 1, Nimble 1
- **Items**: Kitchen knife, bandage x1, water, granola bar, school bag, hoodie,
  torch, battery
- **Stats**: panic 50, endurance 0.2, fatigue 0.15

## Role picker (UI client)

### Comportement
- Le role picker s'ouvre au spawn du joueur
- Le joueur choisit un role dans la liste
- **Doublons autorises**: un role peut etre pris par plusieurs joueurs (pas de
  verrouillage). Le role picker n'affiche pas "taken" pour les roles deja
  choisis.
- Pas de bouton "random" -- le choix est volontaire
- Une fois confirme, le role est definitif pour la partie

### Differences avec le picker d'EE
- Suppression de la logique `isRoleTaken` / `hasFreeRole` (doublons autorises)
- Suppression du role `mecanicien` de la liste
- Le reste (UI, colors, layout) est identique a EE

## Architecture technique

### Fichiers concernes
- `media/lua/shared/LastHomeRoles.lua` -- definitions des 17 roles (skills,
  items, equipement, stats) reprises d'EE sans le Mecanicien
- `media/lua/client/LastHomeRolePicker.lua` -- picker UI (adapte d'EE, sans
  verrouillage des roles)

### Structure d'un role (format EE conserve)
```lua
roleKey = {
    name = "Nom",
    skills = { {Perks.X, level}, ... },
    items = { {"Base.ItemID", count}, ... },
    bagContents = { {"Base.ItemID", count}, ... },  -- optionnel
    equipped = {
        primary = "Base.ItemID",      -- optionnel
        secondary = "Base.ItemID",    -- optionnel
        bag = "Base.ItemID",          -- optionnel
        clothes = { "Base.ItemID", ... },
    },
    stats = { endurance = N, panic = N, ... },
}
```

## Critere d'acceptation

1. 17 roles sont definis (sans Mecanicien, avec Builder)
2. Les doublons sont autorises dans le role picker
3. Le role picker s'ouvre au spawn et permet de choisir un role
4. Le role est definitif apres confirmation
5. Le Voleur est repositionne comme role de loot furtif entre les vagues
6. Le Builder a son refill automatique conserve
7. L'Invincible n'est pas nerf
8. Le Civil reste un challenge volontaire

## Questions en attente

Aucune (toutes les questions relatives aux roles ont ete validees dans LH-01).

## Dependencies

- Reprend les definitions d'EE (EscapadeExpressServer.lua lignes 115-1035)
- Aucune dependance externe -- mod standalone

## Taille estimee

Medium (M) -- 17 roles a definir dans LastHomeRoles.lua + adaptation du
role picker (suppression du verrouillage et du Mecanicien)