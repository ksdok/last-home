# LH-23 (L) - Last Home : relook Brita de 10 rôles (armes + armure tactique)

## Contexte

Suite à LH-22 (dépendance `mod.info` **Brita + Brita_2 + Arsenal(26)GunFighter[MAIN MOD 2.0]**,
rôle 007 Agent, tournevis pour tous, et support `equipRoleItems()` des conteneurs
portés hors slot `Back`), l'hôte a sélectionné **10 rôles existants** à relooker
en équipement Brita. Les 7 autres rôles (Pompier, Medic, Geek, Builder, Local,
Athlete, Civil) restent en équipement vanilla.

Le relook a été validé rôle par rôle avec l'hôte (session 27-07). Les blocs
ci-dessous sont les versions **finalisées** (chargeurs, munitions, armure,
accessoires, sidearms, capacités de portage).

IDs confirmés dans les scripts Arsenal (`module Base` pour les armes ; Mod ID
`Arsenal(26)GunFighter[MAIN MOD 2.0]`) et Brita Armor (`module Base` pour les
vêtements ; Mod ID `Brita_2`) :

- `Base.M4A1` (Colt M4A1, Auto, 30, mag `Base.556Clip`, ammo `Base.556Bullets`)
- `Base.M40A3` (Remington M40A3, bolt, 5 internes, ammo `Base.308Bullets`, pas de chargeur)
- `Base.HuntingRifle` (Howa 1500, bolt, 5 internes, ammo `Base.3006Bullets`)
- `Base.M249` (M249E2 LMG, Auto, 100, mag `Base.556Belt`, ammo `Base.556Bullets`)
- `Base.TAC15` (PSE TAC-15 Crossbow, silencieux, 1, ammo `Base.Bolt_Bear`)
- `Base.M870_MCS` (Model 870 MCS breach, 6, ammo `Base.ShotgunShells`)
- `Base.MP7` (H&K MP7, Auto, 15, mag `Base.9mmClip`, ammo `Base.Bullets9mm`)
- `Base.PPK` (Walther PPK, 7, mag `Base.380Clip`, ammo `Base.Bullets380`)
- `Base.DEagle` (Desert Eagle, 8, mag `Base.44Clip`, ammo `Base.Bullets44`)
- `Base.Colt1911` (Colt M1911, 7, mag `Base.45Clip`, ammo `Base.Bullets45`)
- `Base.Revolver_Long_357` (Ruger GP100 6", 6, mag `Base.357Speed`, ammo `Base.Bullets357`)
- Suppressors : `Base.Suppressor_Rifle` (rifle/SMG), `Base.Suppressor_Pistol` (pistolet)
- Lampes : `Base.Light_Medium_SureFire_M952V` (WeaponPart, rail)
- Lunettes : `Base.Sight_4xACOG`, `Base.Sight_6xELCAN`
- NV : `Base.Hat_PVS15_ON` (AN PVS-15, BodyLocation=Hat)
- Vêtements combat : `Base.Military_Jumper`/`Military_Pants`, `Base.Gorka_Jacket_New`/`Gorka_Pants_New`, `Base.Combat_Jumper`/`Combat_Pants`, `Base.Ela_Jacket`/`Ela_Pants`, `Base.Tactical_Hood`
- Casques : `Base.Hat_FAST_Opscore`, `Base.Hat_PSGT_Helmet_Camo`, `Base.Maska_1_Helmet`, `Base.EOD_Helmet`
- Rigs/sacs : `Base.Bag_D3M` (Tail), `Base.Bag_X_Vest` (Tail), `Base.Bag_Tactical_Alice` (Tail, gros)
- Bottes : `Base.Tac_Boots`, `Base.Boots_Trackstar` ; Gants : `Base.Glove_Mechanix`, `Base.Glove_Mechanix_Pact`, `Base.Glove_Leather`

## Objectif

Réécrire les 10 blocs de rôles dans `LastHomeRoles.lua` avec les loadouts
finalisés ci-dessous. Conserver les `skills` existants sauf ajustements notés
(Samourai : Sprinting 10). Conserver `stats` sauf Samourai (panic 0). Ajouter
`rambo` et `samourai` à `ROLE_CARRY_CAPACITY` dans `LastHomeShared.lua`
(setUnlimitedCarry). Préserver le `Base.Screwdriver` (règle LH-22) dans chaque
bloc. **Ne pas modifier `mod.info` dans ce ticket** : les dépendances Brita sont
déjà couvertes par LH-22. Les sacs/rigs Brita en `Tail` s'appuient sur la
généralisation `equipRoleItems()` livrée en LH-22 ; aucun nouveau helper
d'équipement n'est attendu ici. Les 7 rôles non sélectionnés ne sont pas
modifiés.

## Changements — blocs finalisés par rôle

### 1. Soldat

```lua
soldat = {
    name = "Soldat",
    skills = { {Perks.Aiming, 7}, {Perks.Reloading, 7}, {Perks.Strength, 5},
               {Perks.Fitness, 5}, {Perks.Axe, 4}, {Perks.SmallBlade, 4},
               {Perks.Carpentry, 3}, {Perks.Trapping, 3} },
    items = {
        {"Base.M4A1", 1}, {"Base.556Clip", 4}, {"Base.556Bullets", 90},
        {"Base.Suppressor_Rifle", 1}, {"Base.Sight_4xACOG", 1},
        {"Base.DEagle", 1}, {"Base.44Clip", 2}, {"Base.Bullets44", 30},
        {"Base.Light_Medium_SureFire_M952V", 1},
        {"Base.Screwdriver", 1}, {"Base.HuntingKnife", 1},
        {"Base.Bandage", 3}, {"Base.WaterBottleFull", 1}, {"Base.Bag_D3M", 1},
    },
    bagContents = {
        {"Base.556Clip", 3}, {"Base.556Bullets", 60},
        {"Base.44Clip", 1}, {"Base.Bullets44", 16},
        {"Base.Bandage", 3}, {"Base.TinnedSoup", 2},
    },
    equipped = {
        primary = "Base.M4A1", bag = "Base.Bag_D3M",
        clothes = { "Base.Military_Jumper", "Base.Military_Pants",
                    "Base.Hat_FAST_Opscore", "Base.Tac_Boots", "Base.Glove_Mechanix" },
    },
    stats = { endurance = 0.5, panic = 20 },
},
```

### 2. Sniper

```lua
sniper = {
    name = "Sniper",
    skills = { {Perks.Aiming, 10}, {Perks.Reloading, 8}, {Perks.Sneak, 6},
               {Perks.Strength, 4}, {Perks.Fitness, 4},
               {Perks.Carpentry, 3}, {Perks.Trapping, 3} },
    items = {
        {"Base.M40A3", 1}, {"Base.308Bullets", 60},
        {"Base.Sight_6xELCAN", 1}, {"Base.Suppressor_Rifle", 1},
        {"Base.Revolver_Long_357", 1}, {"Base.357Speed", 2}, {"Base.Bullets357", 30},
        {"Base.Screwdriver", 1}, {"Base.HuntingKnife", 1},
        {"Base.Bandage", 3}, {"Base.WaterBottleFull", 1}, {"Base.Bag_D3M", 1},
    },
    bagContents = {
        {"Base.308Bullets", 40}, {"Base.357Speed", 1}, {"Base.Bullets357", 18},
        {"Base.Bandage", 3}, {"Base.TinnedSoup", 2},
    },
    equipped = {
        primary = "Base.M40A3", bag = "Base.Bag_D3M",
        clothes = { "Base.Gorka_Jacket_New", "Base.Gorka_Pants_New",
                    "Base.Hat_PSGT_Helmet_Camo", "Base.Tac_Boots", "Base.Glove_Mechanix" },
    },
    stats = { endurance = 0.4, panic = 15 },
},
```

### 3. Survivaliste

```lua
survivaliste = {
    name = "Survivaliste",
    skills = { {Perks.Trapping, 8}, {Perks.Aiming, 6}, {Perks.Sneak, 5},
               {Perks.Strength, 4}, {Perks.Fitness, 5},
               {Perks.Carpentry, 3} },
    items = {
        {"Base.HuntingRifle", 1}, {"Base.3006Bullets", 60},
        {"Base.Sight_4xACOG", 1},
        {"Base.Revolver_Long_357", 1}, {"Base.357Speed", 2}, {"Base.Bullets357", 30},
        {"Base.MouseTrap", 3},
        {"Base.Screwdriver", 1}, {"Base.HuntingKnife", 1},
        {"Base.Bandage", 3}, {"Base.WaterBottleFull", 1}, {"Base.Bag_D3M", 1},
    },
    bagContents = {
        {"Base.3006Bullets", 40}, {"Base.357Speed", 1}, {"Base.Bullets357", 18},
        {"Base.MouseTrap", 2}, {"Base.Bandage", 3},
    },
    equipped = {
        primary = "Base.HuntingRifle", bag = "Base.Bag_D3M",
        clothes = { "Base.Gorka_Jacket_New", "Base.Gorka_Pants_New",
                    "Base.Hat_PSGT_Helmet_Camo", "Base.Boots_Trackstar", "Base.Glove_Mechanix" },
    },
    stats = { endurance = 0.4, panic = 15 },
},
```

### 4. Invincible

```lua
invincible = {
    name = "Invincible",
    skills = { -- toutes a 10 (voir bloc existant)
    },
    items = {
        {"Base.M249", 1}, {"Base.556Belt", 2}, {"Base.556Bullets", 200},
        {"Base.Katana", 1}, {"Base.Sledgehammer", 1},
        {"Base.Screwdriver", 1}, {"Base.Bandage", 5}, {"Base.PillsVitamin", 2},
        {"Base.WaterBottleFull", 1}, {"Base.Bag_Tactical_Alice", 1},
    },
    bagContents = {
        {"Base.556Belt", 1}, {"Base.556Bullets", 120},
        {"Base.Katana", 1}, {"Base.Bandage", 5},
    },
    equipped = {
        primary = "Base.M249", bag = "Base.Bag_Tactical_Alice",
        clothes = { "Base.Combat_Jumper", "Base.Combat_Pants",
                    "Base.EOD_Helmet", "Base.Tac_Boots", "Base.Glove_Mechanix_Pact" },
    },
    stats = { endurance = 0.8, panic = 5, fatigue = 0 },
},
```

### 5. Rambo

```lua
rambo = {
    name = "Rambo",
    skills = { {Perks.Axe, 10}, {Perks.Fitness, 8}, {Perks.Strength, 7},
               {Perks.LongBlunt, 5}, {Perks.Carpentry, 3}, {Perks.Trapping, 3} },
    items = {
        {"Base.Axe", 1}, {"Base.Machete", 1},
        {"Base.TAC15", 1}, {"Base.Bolt_Bear", 10}, {"Base.Bolt_Bear_Pack", 2},
        {"Base.Colt1911", 1}, {"Base.45Clip", 3}, {"Base.Bullets45", 30},
        {"Base.Screwdriver", 1}, {"Base.Bandage", 4},
        {"Base.WaterBottleFull", 1}, {"Base.Bag_X_Vest", 1},
    },
    bagContents = {
        {"Base.Machete", 1}, {"Base.Bolt_Bear", 10},
        {"Base.45Clip", 2}, {"Base.Bullets45", 20},
        {"Base.Bandage", 4}, {"Base.TinnedBeans", 2},
    },
    equipped = {
        primary = "Base.Axe", bag = "Base.Bag_X_Vest",
        clothes = { "Base.Combat_Jumper", "Base.Combat_Pants",
                    "Base.Maska_1_Helmet", "Base.Tac_Boots", "Base.Glove_Mechanix_Pact" },
    },
    stats = { endurance = 0.7, panic = 10 },
},
```

### 6. Samourai

```lua
samourai = {
    name = "Samourai",
    skills = { {Perks.LongBlade, 10}, {Perks.SmallBlade, 8},
               {Perks.Sprinting, 10},        -- etait 8 -> 10 (running)
               {Perks.Nimble, 8},
               {Perks.Carpentry, 3}, {Perks.Trapping, 3} },
    items = {
        {"Base.Katana", 1}, {"Base.Machete", 1},
        {"Base.Screwdriver", 1}, {"Base.Bandage", 3},
        {"Base.WaterBottleFull", 1}, {"Base.Bag_D3M", 1},
    },
    bagContents = {
        {"Base.Machete", 1}, {"Base.Bandage", 3}, {"Base.TinnedBeans", 2},
    },
    equipped = {
        primary = "Base.Katana", bag = "Base.Bag_D3M",
        clothes = { "Base.Ela_Jacket", "Base.Ela_Pants",
                    "Base.Tac_Boots", "Base.Glove_Mechanix" },
    },
    stats = { endurance = 0.5, panic = 0 },   -- panic supprimee
},
```

### 7. Demolisseur

```lua
demolisseur = {
    name = "Demolisseur",
    skills = { {Perks.Strength, 6}, {Perks.Fitness, 5}, {Perks.Axe, 5},
               {Perks.LongBlunt, 5}, {Perks.Aiming, 5},
               {Perks.Carpentry, 3}, {Perks.Trapping, 3} },
    items = {
        {"Base.M870_MCS", 1}, {"Base.ShotgunShells", 24}, {"Base.ShotgunShellsBox", 2},
        {"Base.Axe", 1},
        {"Base.PipeBomb", 5}, {"Base.Aerosolbomb", 6}, {"Base.AerosolbombTriggered", 3},
        {"Base.Molotov", 5},
        {"Base.Screwdriver", 1}, {"Base.Bandage", 4},
        {"Base.WaterBottleFull", 1}, {"Base.Bag_Tactical_Alice", 1},
    },
    bagContents = {
        {"Base.ShotgunShells", 18}, {"Base.Axe", 1},
        {"Base.PipeBomb", 5}, {"Base.Aerosolbomb", 6}, {"Base.Molotov", 5},
        {"Base.Bandage", 4},
    },
    equipped = {
        primary = "Base.M870_MCS", bag = "Base.Bag_Tactical_Alice",
        clothes = { "Base.Combat_Jumper", "Base.Combat_Pants",
                    "Base.EOD_Helmet", "Base.Tac_Boots", "Base.Glove_Mechanix_Pact" },
    },
    stats = { endurance = 0.6, panic = 10 },
},
```

### 8. Voleur

```lua
voleur = {
    name = "Voleur",
    skills = { {Perks.Sneak, 8}, {Perks.Lockpicking, 7}, {Perks.Nimble, 6},
               {Perks.Lightfoot, 5}, {Perks.Strength, 4}, {Perks.Fitness, 4},
               {Perks.Carpentry, 3}, {Perks.Trapping, 3} },
    items = {
        {"Base.PPK", 1}, {"Base.380Clip", 3}, {"Base.Bullets380", 40},
        {"Base.Suppressor_Pistol", 1},
        {"Base.Crowbar", 1}, {"Base.Screwdriver", 1},
        {"Base.Bandage", 2}, {"Base.WaterBottleFull", 1}, {"Base.Bag_D3M", 1},
    },
    bagContents = {
        {"Base.380Clip", 2}, {"Base.Bullets380", 20}, {"Base.Bandage", 2},
    },
    equipped = {
        primary = "Base.PPK", bag = "Base.Bag_D3M",
        clothes = { "Base.Tactical_Hood", "Base.Combat_Pants",
                    "Base.Tac_Boots", "Base.Glove_Mechanix" },
    },
    stats = { endurance = 0.7, panic = 10 },
},
```
> Le Screwdriver du Voleur doit rester accessible en inventaire principal
> (règle LH-22). Il n'est pas nécessaire de conserver un doublon en `bagContents`
> sauf besoin d'équilibrage explicite.

### 9. Eclaireur

```lua
eclaireur = {
    name = "Eclaireur",
    skills = { {Perks.Sneak, 8}, {Perks.Lightfoot, 7}, {Perks.Sprinting, 6},
               {Perks.Aiming, 5}, {Perks.Fitness, 5}, {Perks.SmallBlade, 5},
               {Perks.Carpentry, 3}, {Perks.Trapping, 3} },
    items = {
        {"Base.MP7", 1}, {"Base.9mmClip", 4}, {"Base.Bullets9mm", 60},
        {"Base.Suppressor_Rifle", 1},
        {"Base.Hat_PVS15_ON", 1}, {"Base.Map", 1}, {"Base.Torch", 1},
        {"Base.Screwdriver", 1}, {"Base.Bandage", 2},
        {"Base.WaterBottleFull", 1}, {"Base.Bag_D3M", 1},
    },
    bagContents = {
        {"Base.9mmClip", 3}, {"Base.Bullets9mm", 30},
        {"Base.Map", 1}, {"Base.Torch", 1}, {"Base.Bandage", 2},
    },
    equipped = {
        primary = "Base.MP7", bag = "Base.Bag_D3M",
        clothes = { "Base.Tactical_Hood", "Base.Combat_Pants",
                    "Base.Hat_PVS15_ON", "Base.Tac_Boots", "Base.Glove_Mechanix" },
    },
    stats = { endurance = 0.3, panic = 20 },
},
```

### 10. Mule

```lua
mule = {
    name = "Mule",
    skills = { {Perks.Strength, 8}, {Perks.Fitness, 6},
               {Perks.Carpentry, 3}, {Perks.Trapping, 3} },
    items = {
        {"Base.Crowbar", 1},
        {"Base.Colt1911", 1}, {"Base.45Clip", 2}, {"Base.Bullets45", 28},
        {"Base.Screwdriver", 1}, {"Base.Bandage", 3},
        {"Base.WaterBottleFull", 2}, {"Base.Bag_Tactical_Alice", 1},
    },
    bagContents = {
        {"Base.Bandage", 3}, {"Base.TinnedBeans", 2}, {"Base.TinnedSoup", 2},
    },
    equipped = {
        primary = "Base.Crowbar", bag = "Base.Bag_Tactical_Alice",
        clothes = { "Base.Military_Jumper", "Base.Military_Pants",
                    "Base.Tac_Boots", "Base.Glove_Leather" },
    },
    stats = { endurance = 0.6, panic = 15 },
},
```

### Changement transversal : ROLE_CARRY_CAPACITY

Dans `media/lua/shared/LastHomeShared.lua` (`ROLE_CARRY_CAPACITY`) :

```lua
local ROLE_CARRY_CAPACITY = {
    builder = 90,
    demolisseur = 60,
    invincible = 90,
    rambo = 60,        -- NEW (LH-23)
    samourai = 60,     -- NEW (LH-23)
}
```

`applyCarryProfile` active déjà `setUnlimitedCarry` pour toute clé présente
dans cette table. Rambo et Samourai deviennent donc unlimitedCarry.

## Fichiers impactés

- `media/lua/shared/LastHomeRoles.lua` — réécriture des 10 blocs (items /
  bagContents / equipped), skills/stats ajustés (Samourai)
- `media/lua/shared/LastHomeShared.lua` — `ROLE_CARRY_CAPACITY` : +rambo, +samourai
  (pas de changement `equipRoleItems()` attendu : le support des sacs/rigs Brita
  hors slot `Back`, ex. `Tail`, a déjà été livré en LH-22)
- `README.md` + `project-state.md` — référence LH-23
- `specs/LH-23-relook-brita-10-roles.md` (cette spec)

## Critères d'acceptation

1. Les 10 rôles apparaissent avec leur nouvel équipement Brita au spawn
   (armes, chargeurs, munitions, armure complète portée, sac, accessoires,
   NV pour Eclaireur).
2. Les armes à feu Brita apparaissent **chargées** au spawn (priming LH-14) :
   M4A1 (30), M249 (100), MP7 (15), PPK (7), DEagle (8), Colt1911 (7),
   M870_MCS (6), Revolver_Long_357 (6). Les armes à balles internes (M40A3,
   HuntingRifle) et l'arbalète TAC15 sont chargées via `getMaxAmmo()`.
3. L'armure et les rigs/sacs sont portés aux bons `BodyLocation`
   (Jacket/Pants/Hat/Shoes/Hands/Tail), en s'appuyant sur la généralisation
   `equipRoleItems()` livrée en LH-22 pour les conteneurs hors slot `Back`.
4. Les accessoires (suppressors, sights, lampe SureFire, NV) peuvent être
   montés en jeu avec le tournevis. Compatibilité d'attachement à valider par
   arme (fallback `Suppressor_SOCOM_Pistol` / `Light_Small` si besoin).
5. `Screwdriver` présent dans chaque rôle relooké (règle LH-22).
6. Rambo et Samourai ont `setUnlimitedCarry` actif (vérifier moodle "Charge
   Lourde" absent).
7. Invincible et Demolisseur conservent leur `unlimitedCarry`.
8. Les 7 rôles non sélectionnés (Pompier, Medic, Geek, Builder, Local,
   Athlete, Civil) ne sont **pas** modifiés.
9. Aucune erreur Lua au chargement (logs `coop-console.txt` /
   `DebugLog-server.txt`).
10. Équilibrage vs pression des vagues (LH-03) à valider en jeu : les armes
    Brita changent le dakka ; ajuster si une vague devient trop facile.

## Questions en attente

- **Compatibilité d'attachement** : `Suppressor_Rifle` sur M4A1/MP7/M40A3,
  `Suppressor_Pistol` sur PPK, `Light_Medium_SureFire_M952V` sur M4A1+DEagle,
  `Sight_4xACOG`/`Sight_6xELCAN` sur les fusils. Valider en jeu ; fallbacks
  notés plus haut.
- **Rigs/sacs Brita en `equipped.bag`** : `Bag_D3M`, `Bag_X_Vest` et
  `Bag_Tactical_Alice` sont des conteneurs portés hors slot `Back` (`Tail`).
  LH-22 a déjà généralisé `equipRoleItems()` pour ce cas ; valider en jeu qu'ils
  se portent bien sans régression.
- **NV goggles en `equipped.clothes`** : `Hat_PVS15_ON` est un `Hat` →
  `setWornItem(BodyLocation=Hat)` devrait fonctionner. Valider.
- **Priming M249 (belt-fed)** : `Base.556Belt` est un chargeur-ceinturon ;
  vérifier que LH-14 le remplit (`getMaxAmmo()` = 100) et que le M249 spawn
  chargé.
- **`Base.MouseTrap`** (Survivaliste) : confirmer l'item vanilla exact (sinon
  `Base.Trap_Cage` / `Base.Trap_Snare`).
- **`Bolt_Bear_Pack`** (Rambo) : confirmer que c'est un consommable qui donne
  des carreaux (et non un container).
- **Équilibrage** : M249 100 coups Auto + Invincible = potentiellement
  déséquilibrant. Ajuster si besoin (réduire 556Belt count, ou passer Invincible
  en M4A1).

## Décisions

- Le relook = armure tactique + sac + armes à feu Brita pour les rôles de tir
  et la discrétion. Les mêlées (Katana, Hache, Machete, Crowbar) restent
  vanilla (Brita n'ajoute pas de mêlée).
- Invincible : AssaultRifle → **M249 LMG** (belt-fed 100), garde Katana +
  Sledgehammer.
- Rambo : + **arbalète TAC15** (silencieux) + Colt1911 sidearm + setUnlimitedCarry.
- Samourai : **Sprinting 10 + panic 0 + setUnlimitedCarry** + tenue Ela légère.
- Demolisseur : + **M870 MCS breach** shotgun en plus des explosifs.
- Eclaireur : scout nocturne (MP7 + NV goggles PVS-15).
- Voleur : PPK silencieux + tenue furtive (capuche, pas de casque).
- Mule : Colt1911 sidearm + gros sac Tactical_Alice + cargo.
- `Screwdriver` (LH-22) préservé dans chaque bloc.

## Dépendances

- Brita's Weapon Pack (2200148440, Mod ID `Brita`) + Arsenal(26) GunFighter
  (2297098490, Mod ID `Arsenal(26)GunFighter[MAIN MOD 2.0]`) + Brita's Armor
  Pack (2460154811, Mod ID `Brita_2`) — requis (LH-22)
- LH-02 (rôles), LH-08 (équipement/loadout), LH-14 (priming), LH-22
  (tournevis + agent + Brita requis)

## Taille estimée

Large (L) — 10 blocs de rôles à réécrire + 2 entrées `ROLE_CARRY_CAPACITY`.
~50 IDs Brita à valider en jeu (armes, chargeurs, munitions, accessoires,
vêtements, attachement). Le support technique des conteneurs portés hors slot
`Back` est déjà en place via LH-22 ; le risque principal reste donc la
compatibilité d'attachement des accessoires + le priming du belt-fed (M249) +
le port des NV goggles / rigs en conditions réelles. Validation in-game
indispensable avant de considérer livré.