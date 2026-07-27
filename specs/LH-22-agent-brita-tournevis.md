# LH-22 (M) - Last Home : rôle 007 Agent + dépendance Brita + tournevis pour tous

## Contexte

L'hôte a installé les mods Workshop **Brita's Armor Pack** (2460154811,
`Mod ID: Brita_2`) et **Brita's Weapon Pack** (2200148440, `Mod ID: Brita`). Après inspection,
il s'avère que **Brita's Weapon Pack ne contient que des assets** (modèles
3D / textures / sons) — les items fonctionnels (définitions avec `MagazineType`,
`AmmoType`, `MaxAmmo`...) sont fournis par **Arsenal(26) GunFighter**
(2297098490, `Mod ID: Arsenal(26)GunFighter[MAIN MOD 2.0]`), dans `module Base`. Les REF lists du
pack Brita (`"Base.PPK"`, `"Base.MP5"`...) pointent bien vers ces items : les
deux mods sont complémentaires (Arsenal = items fonctionnels, Brita Weapon =
assets visuels, Brita Armor = tenues).

L'hôte souhaite :

1. faire de Brita (Weapon + Armor, via Arsenal pour les items fonctionnels) une
   **dépendance requise** du mod Last Home ;
2. ajouter un nouveau rôle **007 Agent** (agent secret / élimination
   silencieuse) ;
3. ajouter un **tournevis** (`Base.Screwdriver`) à chaque rôle, car il est
   obligatoire en jeu pour monter les accessoires d'armes (suppressors, scopes,
   grips…) du système Brita/Arsenal.

Les rôles existants ne sont **pas** convertis au Brita dans ce ticket (ils
gardent leur équipement vanilla actuel) — leur relook Brita fera l'objet de
tickets séparés une fois les rôles prioritaires choisis.

## Objectif

- Déclarer Brita Weapon Pack + Brita Armor Pack + Arsenal(26) GunFighter comme
  dépendances requises dans `mod.info` et le README.
- Ajouter le rôle `agent` (007 Agent) au système de rôles, avec un loadout
  silencieux (PPK + MP5SD6) et une tenue agent (costume slim + ceinture
  tactique).
- Ajouter `Base.Screwdriver` x1 à l'inventaire principal de **tous** les rôles
  (sauf ceux qui en ont déjà un : geek, builder, voleur, local_).
- Ne pas casser le priming LH-14 (armes à feu chargées au spawn) ni le rôle
  picker (doublons autorisés).

## Changements

### 1. Dépendance Brita / Arsenal requise

- `mod.info` : ajouter `require=Brita,Brita_2,Arsenal(26)GunFighter[MAIN MOD 2.0]`.
  Concrètement, les trois packs doivent être activés en même temps que Last Home.
- `README.md` > Dependencies > Required mods : ajouter Brita's Weapon Pack
  (2200148440), Brita's Armor Pack (2460154811), Arsenal(26) GunFighter
  (2297098490) avec leur rôle (assets / tenues / items fonctionnels).

### 2. Nouveau rôle `agent` (007 Agent)

Ajout dans `media/lua/shared/LastHomeRoles.lua` :

- `Roles.ROLE_ORDER` : insérer `"agent"` (proposition : après `"sniper"`,
  avant `"samourai"`, ou en fin de liste — à fixer).
- `Roles.ROLE_NAMES` : `agent = "007 Agent"`.
- `Roles.ROLE_INFO` : `agent = { name = "007 Agent", summary = "Agent secret /
  elimination silencieuse", strengths = "PPK silencieux, MP5SD6, discretion" }`.
- Bloc de définition `agent` :

```lua
agent = {
    name = "007 Agent",
    skills = {
        {Perks.Aiming, 10},
        {Perks.Reloading, 10},
        {Perks.Sneak, 8},
        {Perks.Nimble, 8},
        {Perks.Lightfoot, 7},
        {Perks.Maintenance, 5},
        {Perks.Strength, 4},
        {Perks.Fitness, 5},
        {Perks.Carpentry, 3},
        {Perks.Trapping, 3},
    },
    items = {
        {"Base.PPK", 1},
        {"Base.380Clip", 3},
        {"Base.Bullets380", 40},
        {"Base.MP5SD6_Fixed", 1},
        {"Base.9mmClip", 4},
        {"Base.Bullets9mm", 60},
        {"Base.Suppressor_Pistol", 1},   -- silencieux pour le PPK
        {"Base.Screwdriver", 1},         -- monter les accessoires
        {"Base.HuntingKnife", 1},
        {"Base.Bandage", 6},
        {"Base.WaterBottleFull", 1},
    },
    bagContents = {
        {"Base.380Clip", 2},
        {"Base.9mmClip", 3},
        {"Base.Bullets380", 20},
        {"Base.Bullets9mm", 30},
        {"Base.Suppressor_Pistol", 1},
        {"Base.Bandage", 3},
    },
    equipped = {
        primary = "Base.PPK",
        bag = "Base.Bag_Tactical_Belt_Front",
        clothes = {
            "Base.Suit_Wick",        -- Slim Fit Suit Jacket (Brita Armor)
            "Base.Suit_Trousers",    -- pantalon costume (vanilla, toujours present)
            "Base.DressShoes",       -- chaussures habillees (vanilla)
            "Base.Glove_Mechanix",   -- gants tactiques discrets (Brita Armor)
        },
    },
    stats = { endurance = 0.5, panic = 10 },
},
```

Notes sur les IDs (tous confirmés dans les scripts Arsenal/Brita) :
- `Base.PPK` : Walther PPK, `MagazineType = Base.380Clip`, `AmmoType =
  Base.Bullets380`, `MaxAmmo = 7`, `FireMode = Single`.
- `Base.MP5SD6_Fixed` : H&K MP5SD2 (MP5 **intégralement silencé**),
  `MagazineType = Base.9mmClip`, `AmmoType = Base.Bullets9mm`, `MaxAmmo = 15`,
  `FireMode = Auto`. C'est le "mp5 + silencieux" demandé : la variante SD6
  intègre le silencieux, donc pas d'attachment séparé nécessaire (et évite
  l'incertitude d'attachement d'un `Suppressor_Rifle` sur un MP5
  `AttachmentType = Rifle`).
- `Base.Suppressor_Pistol` : `WeaponPart`, silencieux pistolet (monté sur le
  PPK via le tournevis).
- `Base.Bag_Tactical_Belt_Front` : Fairwin Tactical Belt (Front),
  `BodyLocation = TorsoExtra`, `Capacity = 4` (petit — la ceinture demandée ;
  le MP5SD6 et le gros des munitions restent en inventaire principal).
- `Base.Suit_Wick` : Slim Fit Suit Jacket, `BodyLocation = Jacket`.
- Tenue : veste costume Brita + pantalon/chaussures vanilla (toujours présents
  même avec Brita requis) + gants tactiques Brita.

### 3. Tournevis pour tous

Ajouter `{"Base.Screwdriver", 1}` à l'`items` de chaque rôle qui n'en a pas
déjà un. Rôles **déjà équipés** (ne pas dupliquer) :
- `geek` (primary = Screwdriver)
- `builder` (outils, contient déjà Screwdriver)
- `voleur` (Screwdriver déjà présent en `items` et `bagContents`)
- `local_` (Screwdriver déjà présent en `items` et `bagContents`)

Rôles à équiper (13 + agent) : `soldat`, `medic`, `rambo`, `sniper`,
`samourai`, `survivaliste`, `pompier`, `athlete`, `eclaireur`, `demolisseur`,
`invincible`, `mule`, `civil`, et le nouveau `agent` (déjà inclus dans le
bloc ci-dessus).

Le tournevis va dans l'`items` (inventaire principal), pas dans `bagContents`,
pour rester accessible sans ouvrir le sac.

## Fichiers impactés

- `media/lua/shared/LastHomeRoles.lua` — ajout du rôle `agent` (ROLE_ORDER,
  ROLE_NAMES, ROLE_INFO, bloc de définition) + `Base.Screwdriver` dans 13 rôles
  existants
- `media/lua/shared/LastHomeShared.lua` — `equipRoleItems()` généralisé pour
  équiper un conteneur porté hors slot `Back` (ex. `Base.Bag_Tactical_Belt_Front`)
- `mod.info` — dépendances requises (Brita Weapon, Brita Armor, Arsenal
  GunFighter)
- `README.md` — section Dependencies + table des specs (LH-22)
- `project-state.md` — specs + backlog (LH-22)
- `specs/LH-22-agent-brita-tournevis.md` (cette spec)

## Critères d'acceptation

1. Le rôle picker propose le **007 Agent** (18 rôles au total, doublons
   autorisés).
2. Au spawn, l'agent a : PPK (chargé 7/7, prêt à tirer) équipé en main, MP5SD6
   (chargé 15/15) en inventaire, 3× `380Clip` + 4× `9mmClip` (remplis), balles
   380 + 9mm, 1× `Suppressor_Pistol`, 1× `Screwdriver`, couteau, bandages,
   bouteille d'eau, ceinture tactique équipée, veste costume + pantalon +
   chaussures + gants portés.
3. Le priming LH-14 fonctionne sur les armes Brita/Arsenal : vérifier en jeu
   que `Base.PPK` et `Base.MP5SD6_Fixed` apparaissent **chargés** au spawn
   (chargeur inséré + balle chambrée), et que les chargeurs spare (`380Clip`,
   `9mmClip`) sont remplis. Si une arme Brita n'implémente pas
   `getMagazineType()`/`getMaxAmmo()`, le priming ne s'applique pas → ticket de
   suivi.
4. Le `Suppressor_Pistol` peut être monté sur le PPK en jeu (avec le
   tournevis) ; le MP5SD6 est silencieux nativement (pas d'attachment requis).
5. Tous les 17+1 rôles ont un `Base.Screwdriver` accessible (inventaire
   principal ou déjà présent pour geek/builder/voleur/local_).
6. `mod.info` déclare les dépendances Brita/Arsenal ; lancer Last Home sans
   ces mods activés doit soit échouer proprement, soit être documenté comme
   non supporté.
7. Aucune erreur Lua au chargement des rôles (vérifier `coop-console.txt` /
   `DebugLog-server.txt`).
8. Les autres rôles ne sont pas modifiés au-delà de l'ajout du tournevis.

## Questions en attente

- **Pantalon / chaussures du costume** : la veste `Base.Suit_Wick` (Brita) n'a
  pas de pantalon assorti évident dans Brita Armor. Proposition : pantalon +
  chaussures vanilla (`Base.Suit_Trousers`, `Base.DressShoes`, toujours
  présents). Alternativement, choisir un pantalon Brita (ex. un pantalon
  tactique noir) pour un look "agent tactique" plutôt que "smoking". À fixer
  en implémentation.
- **Position du rôle dans le picker** : fin de liste ou regroupement avec les
  rôles de tir ? Proposer fin de liste (après `civil`) pour le mettre en
  évidence comme nouveauté, ou après `sniper` (rôle de tir/stealth). Décision
  suggérée : après `sniper`.
- **Priming des armes Brita** : à valider en jeu (critère 3). Si certaines
  armes Brita ne supportent pas l'API PZ standard, prévoir un fallback ou
  pré-charger les chargeurs manuellement.
- **MP5 + silencieux séparé** : ce ticket utilise le MP5SD6 (silencieux
  intégré). Si l'hôte préfère un `Base.MP5_Fixed` + `Base.Suppressor_Rifle`
  (attachment séparé, à vérifier la compatibilité d'attachement car le MP5 est
  `AttachmentType = Rifle`), ouvrir un ticket de suivi.

## Décisions

- **Dépendance Brita requise** (décision hôte 27-07) : les items Brita/Arsenal
  sont référencés directement, pas de fallback vanilla.
- **MP5 silencieux = MP5SD6** (intégralement silencé) plutôt que MP5 +
  suppressor séparé : plus authentique et évite l'incertitude d'attachement.
- **Tournevis pour tous** : règle d'équipement globale (convention projet
  enregistrée), car obligatoire pour monter les accessoires Brita.
- **Tenue 007** : veste costume Brita (`Suit_Wick`) + bas vanilla + gants
  tactiques Brita — compromis "look 007" + "full tactical par rôle" (le 007 est
  un rôle stealth, son "tactical" est discret, pas un casque+rig lourd).
- Les rôles existants ne sont **pas** relookés en Brita dans ce ticket.

## Dépendances

- Brita's Weapon Pack (2200148440, assets)
- Brita's Armor Pack (2460154811, tenues)
- Arsenal(26) GunFighter (2297098490, items fonctionnels module Base)
- Dépend de LH-02 (système de rôles), LH-08 (équipement/loadout),
  LH-14 (priming armes à feu)

## Taille estimée

Medium (M) — un nouveau rôle (définition + 3 tables d'index), 13 ajouts de
tournevis, dépendances `mod.info`/README, plus un petit ajustement de
`equipRoleItems()` pour supporter un conteneur porté hors slot `Back`. Le rôle
réutilise `addRoleItems` / `primeRoleLoadout` / `equipRoleItems`. Risque
principal : priming des armes Brita (à valider en jeu) et petite capacité de la
ceinture (capacity 4).