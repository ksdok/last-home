# Spec LH-26 — Reprise des rôles de PZRolePlay dans Last Home (set Brita)

**Date :** 2025-08-05
**Projet :** Last Home
**Repo cible :** `/Users/kim/Documents/Zomboid/last-home`
**Source :** `/Users/kim/Documents/Zomboid/PZRolePlay` (mod standalone `id=PZRolePlaying`)
**Statut :** ✅ Décisions validées — prêt à implémenter

---

## Contexte

Last Home embarque son propre sous-système de rôles dans `LastHomeRoles.lua` (18 rôles,
jeu unique quasi-Brita, rôle `civil`). Ce sous-système a dérivé du système de rôles
d'Escapade Express puis a été affiné par LH-22 (agent + tournevis) et LH-23 (relook
Brita de 10 rôles).

Le mod standalone **PZRolePlay** (`../PZRolePlay`) constitue désormais la version de
référence du système de rôles : double jeu (vanilla 20 rôles / Brita 22 rôles) avec
détection auto, helpers factorisés, correction des clés `Perks` invalides, migration
modData, et réouverture debug du picker.

Cette spec remplace les définitions de rôles embarquées de Last Home par celles du
**set Brita de PZRolePlay** (rôles, équipements, perks, stats, sacs, vêtements,
helpers, profil de port). Les mécaniques de jeu Last Home (vagues, maison, téléport
spawn, confinement, Builder refill, stock au sol) sont **conservées** et adaptées
au nouveau set.

### Décisions validées (utilisateur)

| Choix | Valeur |
|---|---|
| Direction du remplacement | **PZRolePlay → Last Home** (Last Home adopte le système de rôles de PZRolePlay) |
| Set de rôles | **Brita uniquement** (le set vanilla de PZRolePlay n'est pas repris) |

### Décisions dérivées (validées)

| # | Décision | Raison |
|---|---|---|
| D1 ✅ | Profil de port = **unlimited carry pour tous les rôles sauf `vanilla`** (comportement PZRolePlay) | Port fidèle de PZRolePlay ; accepté malgré l'impact difficulté |
| D2 ✅ | Conserver la règle Last Home **« tous les rôles (sauf `vanilla`) ont min Woodwork 3 + Trapping 3 »** en injectant ces perks dans chaque def importée **sauf `vanilla`** (qui reste no-op) | Préserve le gameplay défensif (barricades/pièges) ; `vanilla` reste un no-op complet |
| D3 ✅ | Remplacer le rôle `civil` Last Home par le rôle **`vanilla`** PZRolePlay (no-op) + migration `civil→vanilla` | Cohérent avec PZRolePlay ; le spawn vanilla devient le « mode difficile » |
| D4 ✅ | Garder le namespace modData **`LH_role` / `LH_localRoleApplied`** (ne pas adopter `PZRP_role`) | Sauvegardes Last Home existantes ; adopter juste le pattern de migration |
| D5 ✅ | **Brita/Arsenal deviennent des dépendances requises** (`mod.info` `require=` ré-ajouté) + **livrer quand même** sur le Workshop | Le set unique est 100 % Brita/Arsenal ; `require=` produit un échec de chargement « mod manquant » clair plutôt qu'un crash silencieux |
| D6 ❌ | **Reprise de la spec reopen-picker refusée** | Hors périmètre ; pas de réouverture debug du picker via K (reste un éventuel ticket séparé) |

---

## État courant (remplacé)

### Last Home — `LastHomeRoles.lua` (18 rôles, jeu unique)

```
ROLE_ORDER = soldat, voleur, local_, medic, rambo, sniper, agent, samourai, geek,
            survivaliste, pompier, athlete, eclaireur, demolisseur, invincible,
            mule, builder, civil
```

- Quasi-totalité en loadout Brita/Arsenal (`Base.M4A1`, `Base.PPK`, `Base.MP5SD6_Fixed`, `Base.Bag_D3M`...).
- **Bugs Perks** : utilise `Perks.Carpentry` et `Perks.Electrical` — clés **invalides**
  en B41 (→ nil → talent reste à 0, cf. `PZRolePlay/docs/Perks.md`). PZRolePlay a
  corrigé en `Perks.Woodwork` / `Perks.Electricity`.
- Rôle `civil` = loadout minimal (KitchenKnife, bandage, sac école) + Woodwork/Trapping 3.
- Règle « tous les rôles min Woodwork 3 + Trapping 3 » (barricades/pièges) — cf. `project-state.md`.
- `ROLE_CARRY_CAPACITY` Last Home = `builder, demolisseur, invincible, rambo, samourai`
  → unlimited carry **seulement pour ces 5 rôles**.
- `BUILDER_REFILL_ITEMS` (refill 10 min) et `COMMUNITY_STOCK_ITEMS` (stock au sol).

### Last Home — helpers rôle dans `LastHomeShared.lua`

`applyCarryProfile`, `primeRoleLoadout`, `equipRoleItems`, `applyPerkLevel`,
`addRoleItems`, `addItemsToContainer`, `buildItemCounts`, `applyRoleStats`,
`applyManualTeleportState`, `fillAmmoItem` (dédupliqués via LH-17). Namespace `LH_role`
/ `LH_localRoleApplied`, **sans** migration legacy ni migration de valeur.

### PZRolePlay — `PZRolePlayingRolesBrita.lua` (22 rôles, set Brita)

```
ROLE_ORDER = soldat, voleur, local_, medic, rambo, sniper, agent, hunk, samourai,
            geek, survivaliste, pompier, athlete, eclaireur, demolisseur,
            invincible, mule, builder, leon, chris, jill, vanilla
```

Rôles supplémentaires vs Last Home : `hunk`, `leon`, `chris`, `jill`, `vanilla`
(perd `civil`). Perks en clés valides. Profil de port : unlimited carry pour tous
sauf `vanilla` ; `ROLE_CARRY_CAPACITY` (bonus maxWeight) pour builder, chris,
demolisseur, hunk, invincible, leon, mule, rambo, samourai, soldat, sniper,
survivaliste.

---

## Cible (ce qu'on adopte)

### 1. Set de rôles — `LastHomeRoles.lua` réécrit

Remplacer intégralement `ROLE_ORDER`, `ROLE_NAMES`, `ROLE_INFO`, `ROLE_DEFS` par le
**set Brita de PZRolePlay** (`PZRolePlayingRolesBrita.lua`) :

- **22 rôles** : `soldat, voleur, local_, medic, rambo, sniper, agent, hunk, samourai,
  geek, survivaliste, pompier, athlete, eclaireur, demolisseur, invincible, mule,
  builder, leon, chris, jill, vanilla`.
- Chaque `ROLE_DEFS[role]` reporte : `name`, `skills` (clés `Perks` valides), `items`,
  `bagContents`, `equipped` (`primary` / `bag` / `clothes`), `stats`.
- Correction automatique des perks : `Perks.Woodwork` (pas `Carpentry`),
  `Perks.Electricity` (pas `Electrical`), `Perks.Doctor` (ok).
- **D2** : injecter `{Perks.Woodwork, 3}` et `{Perks.Trapping, 3}` dans **chaque def
  sauf `vanilla`** (en préservant les niveaux existants supérieurs, ex. builder
  Woodwork 10, survivaliste Trapping 10). `vanilla` reste un no-op complet (aucun
  perk/item/stat/carry) — l'injection D2 ne s'y applique pas.

### 2. Profil de port — `LastHomeShared.lua`

Remplacer `LastHomeShared.applyCarryProfile` + `ROLE_CARRY_CAPACITY` par
l'implémentation PZRolePlay :

- `setUnlimitedCarry(true)` pour **tous les rôles sauf `vanilla`** (D1).
- `ROLE_CARRY_CAPACITY` (bonus `maxWeightBase`/`maxWeight`) : `builder=90, chris=60,
  demolisseur=60, hunk=50, invincible=90, leon=50, mule=80, rambo=60, samourai=60,
  soldat=60, sniper=60, survivaliste=60`.
- `setMaxWeightDelta(0)`.
- Pas de `resetCarryProfile` / `clearPlayerLoadout` / `resetPlayerPerks` /
  `buildRolePerkUnion` : ces helpers PZRolePlay ne servent qu'au debug switch
  (reopen-picker), refusé en D6. L'application de rôle reste **one-shot** (spawn
  ou restauration de save) sans réinitialisation préalable.

> ⚠️ **D1 — balance** : Last Home applique aujourd'hui l'unlimited carry à 5 rôles
> seulement. L'étendre à 21 rôles sur 22 supprime une contrainte de poids centrale
> dans une boucle survie (craft/loot/transport). **Validé par l'utilisateur** (D1).

### 3. modData & migration — `LastHomeShared.lua` + clients/serveur

- Conserver le namespace **`LH_role`** / **`LH_localRoleApplied`** (D4).
- Ajouter une fonction `normalizeRoleModData(modData)` calquée sur
  `PZRolePlayingRoles.normalizeModData` :
  - **Migration de valeur** : `civil → vanilla` (D3) pour `LH_role` ET
    `LH_localRoleApplied` (les sauvegardes existantes avec `LH_role="civil"` doivent
    se restaurer vers `vanilla`, sinon `defs["civil"] == nil` et le picker réapparait).
  - (Pas de migration legacy `LR_*` : Last Home n'a jamais utilisé ce namespace.)
- **Règle : normaliser à CHAQUE lecture** de `modData.LH_role` ou
  `modData.LH_localRoleApplied`. Liste exhaustive des sites à instrumenter (lecture) :
  - `LastHomeClient.lua:104` — spawn fallback (`LH_role ~= nil`).
  - `LastHomeClient.lua:167-168` — `applyRoleLocally` skip guard (`LH_localRoleApplied`).
  - `LastHomeClient.lua:206-207` — `requestRolePicker` « role deja choisi ».
  - `LastHomeClient.lua:414` — `hasRole` pour le HUD.
  - `LastHomeClient.lua:747` — comparaison `LH_role ~= data.role` (sync serveur).
  - `LastHomeRolePicker.lua:266` — garde « `LH_role == nil` » avant ouverture.
  - `LastHomeServer.lua:370` — branche Builder refill (`LH_role == "builder"`).
  - `LastHomeServer.lua:461` — `persistedRole` (restauration MP).
  - `LastHomeServer.lua:527` — `scenarioPlayer` role check.
  - `LastHomeBoundary.lua:152` — exemption spectateur (`roleKey`).
  - `LastHomeWaves.lua` : **aucune** lecture de `LH_role` (spectateur géré sans
    `LH_role`, vérifié au grep) — rien à instrumenter.
  - Les **écritures** (`LastHomeClient.lua:190,748`, `LastHomeRolePicker.lua:275`,
    `LastHomeServer.lua:318`) écrivent déjà une valeur canonique ; pas de
    normalisation nécessaire, mais la valeur écrite ne doit plus jamais être `civil`.
  - Recommandé : centraliser via `LastHomeShared.getRoleKey(modData)` qui appelle
    `normalizeRoleModData` puis renvoie `modData.LH_role`, pour éviter d'en oublier.
- **Migration sémantique seule (D3)** : la migration ne touche **que la valeur du
  rôle**. Sur restauration d'une save `civil`, l'inventaire/les perks/le carry **ne
  sont pas réinitialisés** — non destructif. Le joueur conserve son ancien loadout
  `civil` (harmless ; `vanilla` no-op ne régit que les NOUVELLES applications de
  rôle). Le picker ne réapparaît pas (`LH_role` migré → `vanilla` →
  `defs["vanilla"]` existe). Un nouveau spawn ou un re-choix `vanilla` n'applique rien.

### 4. Helpers rôle — `LastHomeShared.lua`

Remplacer les implémentations Last Home par les versions PZRolePlay (namespace
`LastHomeShared.*` conservé pour limiter le churn) :

| Helper | Source PZRolePlay | Notes Last Home |
|---|---|---|
| `applyPerkLevel(player, perk, level)` | `PZRolePlayingShared.applyPerkLevel` | Corrige le path `setXPToLevel` + `LevelPerk`/`LoseLevel` + `setXPToLevel` |
| `addRoleItems(inv, bagItem, bagItemId, items, bagContents)` | `PZRolePlayingShared.addRoleItems` | Sémantique : `items` = total, `bagContents` = répartition bornée au total |
| `addItemsToContainer` / `buildItemCounts` | idem | déjà présents (LH-17), vérifier parité exacte |
| `equipRoleItems(player, inv, equipped)` | `PZRolePlayingShared.equipRoleItems` | Gère `bag` non-Back (worn container `BodyLocation`), création à la volée des clothes absentes de `items` |
| `resolveSecondaryEquipItem` | idem | Dédup 2-handed vs `equipped.secondary` |
| `fillAmmoItem` / `primeRoleLoadout(inv)` | idem | = LH-14, parité à vérifier (magazine-fed `setContainsClip`, `RoundChambered`, `SpentRoundChambered`) |
| `applyRoleStats` / `resetRoleStats` | idem | `setPanic(30)/setHunger(0.2)/setThirst(0.2)/setFatigue(0)` baseline + overrides |
| `applyCarryProfile` | idem | cf. §2 (pas de `resetCarryProfile` — D6) |

**Conservés (Last Home uniquement, ne pas écraser)** : `applyManualTeleportState`,
`isInsideBoundary`, `getHouseStockSpawn`, `formatCoords`, `formatHouseLabel`,
`formatBoundaryLabel`, `log`, `getScenarioPlayers`, `getNowSeconds`, tables maisons.

### 5. Role picker — `LastHomeRolePicker.lua`

- Lire le nouveau `ROLE_ORDER` (22 rôles) — déjà itéré sur `ROLE_ORDER`/`ROLE_INFO`.
- Adapter la hauteur/grille du picker (22 entrées vs 18).
- Garder le flux Last Home (picker rouvert automatiquement tant qu'aucun rôle n'est
  choisi). Pas de bouton de fermeture X ni de réouverture debug via K (reopen-picker
  refusé en D6 ; reporté vers un éventuel LH-27).

### 6. Flux client/serveur — `LastHomeClient.lua` / `LastHomeServer.lua`

- `LastHomeClient.applyRoleLocally` : appeler `normalizeRoleModData` puis la chaîne
  PZRolePlay (create bag → `addRoleItems` → `applyPerkLevel` loop → `equipRoleItems`
  → `applyRoleStats` → `applyCarryProfile` → `primeRoleLoadout`). Garder la pose
  `modData.LH_role` / `LH_localRoleApplied`.
- `LastHomeServer` (autorité MP) : `assignRole`/`requestRolePicker` consomment les
  nouvelles defs ; `applyCarryProfile` côté serveur. **Builder refill** (`LH_role ==
  "builder"`) conservé tel quel.
- **Téléport spawn** : inchangé — déclenché après application du rôle, vers
  `house.spawn` (Last Home). PZRolePlay n'a pas de teleport ; ne pas importer.
- **Confinement** : inchangé (`LastHomeBoundary` lit `modData.LH_role` pour
  l'exemption spectateur — vérifier qu'aucune branche ne dépend de `civil`).

### 7. Builder refill & stock communautaire — préservés

- `BUILDER_REFILL_ITEMS` : **inchangé** (mécanique Last Home, absente de PZRolePlay).
- `COMMUNITY_STOCK_ITEMS` : **conservé**. La couverture en munitions n'est **pas
  maintenue à la main** : elle est **dérivée des `ROLE_DEFS`** pour éviter la
  dérive quand on importe tout le set PZRolePlay.
  - **Règle de couverture (vérification automatisée)** : collecter tous les IDs
    d'items apparaissant dans `ROLE_DEFS[*].items` ou `bagContents` dont le script
    est une munition/chargeur (patterns : `*Clip`, `*Bullets*`, `*Bullet*`,
    `ShotgunShells*`, `*Speed`, `*Belt` pour munitions ceinturées, `556Belt`) ;
    chaque ID trouvé doit figurer dans `COMMUNITY_STOCK_ITEMS` avec une quantité > 0.
    Un ID présent dans les defs mais absent du stock = échec de vérification.
  - Implémentation conseillée : un petit script (Lua de test ou `rg` sur les defs
    + diff contre `COMMUNITY_STOCK_ITEMS`) exécuté en vérification, produit le diff
    `munitions(roleDefs) − munitions(stock)`. Aucun ID munition laissé non couvert.
  - Application immédiate connue : ajouter `Base.AKClip` / `Base.Bullets762`
    (Chris — `Base.AK103`) — la dérivation le signalera automatiquement.
  - Food/water : inchangés.

### 8. Dépendances — `mod.info`

- **D5** : ré-ajouter `require=Brita;Brita_2;Arsenal(26)GunFighter[MAIN MOD 2.0]`
  (Workshop IDs : `2200148440`, `2460154811`, `2297098490`).
- **Livraison Workshop immédiate** (pas d'attente de publication de Brita/Arsenal).
  Grâce au `require=`, un joueur qui n'a pas Brita/Arsenal installés obtient un
  **échec de chargement « mod manquant » clair** côté hôte — pas un crash
  silencieux en partie. Le README doit le documenter explicitement.
- Bumper `version` (ex. `0.13.0`).

### 9. Docs

- `README.md` : « 22 rôles (set Brita PZRolePlay) » au lieu de « 17/18 rôles » ;
  décrire Brita/Arsenal comme **requis** ; retirer la mention « 17 roles taken from
  Escapade Express ».
- `project-state.md` : nouvelle entrée LH-26 **séparée** de LH-25 (corrige la
  fusion accidentelle des deux lignes) ; clarifier la relation LH-25 (mod standalone,
  réalisé par `../PZRolePlay`) vs LH-26 (port en place dans Last Home, code
  dupliqué sans `require`) ; mettre à jour les notes d'implémentation (rôle `civil`
  → `vanilla`, unlimited carry, correction Perks).

---

## Fichiers modifiés

| Fichier | Changement |
|---|---|
| `media/lua/shared/LastHomeRoles.lua` | Réécriture complète : set Brita 22 rôles (depuis `PZRolePlayingRolesBrita.lua`) + injection D2 Woodwork/Trapping 3 ; `BUILDER_REFILL_ITEMS` et `COMMUNITY_STOCK_ITEMS` conservés (ammo list màj) |
| `media/lua/shared/LastHomeShared.lua` | `applyCarryProfile`/`ROLE_CARRY_CAPACITY` + `applyPerkLevel`/`addRoleItems`/`equipRoleItems`/`fillAmmoItem`/`primeRoleLoadout`/`applyRoleStats`/`resetRoleStats` remplacés par les versions PZRolePlay ; ajout `normalizeRoleModData` (+ helper `getRoleKey`) ; helpers non-rôle conservés. Pas de `resetCarryProfile`/`clearPlayerLoadout`/`resetPlayerPerks`/`buildRolePerkUnion` (D6) |
| `media/lua/client/LastHomeRolePicker.lua` | Itération sur 22 rôles ; layout. Pas de bouton X / reopen K (D6) |
| `media/lua/client/LastHomeClient.lua` | `applyRoleLocally` chaîne PZRolePlay + `normalizeRoleModData`/`getRoleKey` à chaque lecture `LH_role`/`LH_localRoleApplied` (l.104, 167-168, 206-207, 414, 747) ; spawn fallback lit clé migrée |
| `media/lua/server/LastHomeServer.lua` | `assignRole`/role flow consomment nouvelles defs + `applyCarryProfile` ; Builder refill conservé ; `normalizeRoleModData`/`getRoleKey` sur `persistedRole` (l.461), Builder branch (l.370), scenario check (l.527) |
| `media/lua/server/LastHomeBoundary.lua` | Lecture `modData.LH_role` (l.152) via `getRoleKey` ; vérifier absence de branche dépendant de `civil` |
| `media/lua/server/LastHomeWaves.lua` | Aucune lecture de `LH_role` (spectateur géré sans `LH_role`, vérifié au grep) ; aucun changement attendu |
| `mod.info` | `require=` Brita/Arsenal ré-ajouté ; `version` bumpé |
| `README.md` / `project-state.md` | Màj compteur rôles, deps, notes |
| `specs/LH-26-roles-pzroleplay.md` | (cette spec) |

---

## Décisions validées

1. **D1 ✅ — Unlimited carry pour tous (sauf vanilla).** Étend la règle de 5 → 21 rôles.
2. **D2 ✅ — Règle « min Woodwork 3 + Trapping 3 » injectée dans chaque def importée
   sauf `vanilla`** (préserve le gameplay défensif Last Home ; `vanilla` reste no-op).
3. **D3 ✅ — `civil` → `vanilla` (no-op).** Le « mode difficile » Last Home = spawn
   vanilla pur, aucun item. Migration `civil→vanilla` des sauvegardes existantes,
   **sémantique seule** (valeur du rôle uniquement ; inventaire/perks/carry non
   réinitialisés — non destructif).
4. **D4 ✅ — Namespace `LH_role` / `LH_localRoleApplied` conservé** (sauvegardes
   existantes préservées).
5. **D5 ✅ — Brita/Arsenal requis + livraison Workshop immédiate.** `require=`
   ré-ajouté ; les joueurs sans Brita/Arsenal obtiennent un échec de chargement
   « mod manquant » clair (pas de crash silencieux). Pas d'attente de publication
   de Brita/Arsenal côté Workshop.
6. **D6 ❌ — Pas de reprise de la spec reopen-picker.** La réouverture debug du
   picker via K n'est pas reprise. Reste un éventuel ticket séparé (LH-27).

---

## Vérification

1. Sans Brita/Arsenal : `mod.info` `require=` bloque le lancement (attendu, D5).
2. Avec Brita/Arsenal + LastHome : spawn → picker affiche **22 rôles**, ordre PZRolePlay.
3. Choisir `soldat` → loadout Brita PZRolePlay (M4A1, DEagle, D3M, vêtements militaires),
   perks **Aiming 9 / Reloading 7 / Strength 8** avec clés valides (Woodwork/Electricity
   non à 0), unlimited carry actif, arme primée (chambered + clip).
4. Choisir `hunk` / `leon` / `chris` / `jill` (nouveaux) → loadouts Brita complets.
5. Choisir `vanilla` → **aucun item/perk/stat/carry** appliqué (no-op).
6. Sauvegarde existante avec `LH_role="civil"` → restaurée en `vanilla` : picker ne
   réapparaît pas, **inventaire/perks existants préservés** (migration sémantique
   seule, non destructif), aucun nouveau loadout appliqué.
7. Sauvegarde existante avec `LH_role="builder"` → restaurée, Builder refill 10 min
   toujours actif.
8. Tous les rôles **sauf `vanilla`** peuvent poser barricades (Woodwork ≥3) et pièges
   (Trapping ≥3). `vanilla` : aucun perk (no-op).
9. Téléport spawn maison, confinement, vagues, spectateur, stock au sol : non
   régressés.
10. Vérification automatisée : `munitions(ROLE_DEFS) − munitions(COMMUNITY_STOCK_ITEMS)`
    = ensemble vide (toutes les munitions/chargeurs des 22 rôles couverts par le
    stock). Pas de chargeur 0 dans l'inventaire d'un nouveau rôle.
11. MP Host : `OnServerStarted` bootstrap inchangé ; rôle appliqué côté serveur
    (autorité) puis sync client ; `LH_role` persisté (valeur `vanilla`, jamais `civil`).
12. Pas de réouverture debug du picker via K (D6) — la touche K garde son rôle Last
    Home existant (skip de vague).

---

## Références

- `../PZRolePlay/README.md` — tables vanilla/Brita, fichiers principaux.
- `../PZRolePlay/docs/spec-re-roles.md` — specs Leon/Chris/Jill (source des 3 rôles RE).
- `../PZRolePlay/docs/Perks.md` — clés `Perks.X` valides (Woodwork/Electricity/Doctor).
- `../PZRolePlay/media/lua/shared/PZRolePlayingRolesBrita.lua` — source des 22 defs.
- `../PZRolePlay/media/lua/shared/PZRolePlayingShared.lua` — source des helpers.
- `specs/LH-22-agent-brita-tournevis.md`, `specs/LH-23-relook-brita-10-roles.md` —
  relook Brita historique (supersédé par LH-26 pour le set).
- `specs/LH-25-mod-roles-seul.md` — mod standalone (contexte PZRolePlay).