# LH-16 (M) - Last Home: Localisation FR/EN via Translate system

## Contexte

Toutes les chaînes affichées au joueur dans Last Home sont actuellement
hardcodées en français : titres de challenges, textes du HUD, messages du
role picker, noms de rôles, noms de maisons, libellés de la flèche de stock,
alertes serveur, logs console, etc.

Un joueur configurant le jeu en anglais voit donc du français — ce qui n'est
pas idéal pour la diffusion du mod.

Project Zomboid B41 supporte nativement la localisation via des fichiers de
traduction dans `media/lua/shared/Translate/<LANG>/`. L'API Lua
`getText("Key")` (ou `Translator.getText()`) résout la clé dans la langue
du joueur et tombe sur l'anglais par défaut si la traduction est absente.

## Objectif

1. Créer les fichiers de traduction EN (default) et FR pour toutes les chaînes
   du mod visibles par le joueur.
2. Remplacer toutes les chaînes hardcodées en français par des appels
   `getText()`.
3. Les chaînes de log/diagnostics (print, logClient, logBoundary, etc.)
   restent en anglais (dev-facing).

## Translation files

### Structure à créer

```
media/lua/shared/Translate/
  EN/
    Challenge_EN.txt     -- ajouter les entrées Last Home dans le tableau existant
    IG_UI_EN.txt         -- ajouter les entrées Last Home dans le tableau existant
  FR/
    Challenge_FR.txt     -- idem, valeurs en français
    IG_UI_FR.txt         -- idem, valeurs en français
```

### Convention de nommage des clés

Les clés suivent le format attendu par le moteur PZ :

| Table | Format de clé | Exemple |
|-------|---------------|---------|
| Challenge | `Challenge_<id>_name` / `Challenge_<id>_desc` | `Challenge_LastHomeHospital_name` |
| IG_UI | `IGUI_LH_<description_snake_case>` | `IGUI_LH_zone_in` |

Pour les challenges, le moteur PZ résout automatiquement les clés
`Challenge_<id>_name` et `Challenge_<id>_desc` à partir du champ `id` de la
définition du challenge. Les `id` existants sont :
`LastHomeHospital`, `LastHomeVilla`, `LastHomePrison`, `LastHomeSchool`.

Pour IG_UI, le préfixe `IGUI_LH_` distingue les clés du mod des clés vanilla.

## Périmètre — toutes les chaînes joueur

### 1. Challenges (Challenge_EN.txt / Challenge_FR.txt)

Clés résolues automatiquement par le moteur depuis `challenge.id` :

| Clé | EN | FR |
|-----|----|----|
| `Challenge_LastHomeHospital_name` | `"Last Home: Hospital"` | `"Last Home : Hôpital"` |
| `Challenge_LastHomeHospital_desc` | `"..."` | `"..."` |
| `Challenge_LastHomeVilla_name` | `"Last Home: Villa"` | `"Last Home : Villa"` |
| `Challenge_LastHomeVilla_desc` | `"..."` | `"..."` |
| `Challenge_LastHomePrison_name` | `"Last Home: Prison"` | `"Last Home : Prison"` |
| `Challenge_LastHomePrison_desc` | `"..."` | `"..."` |
| `Challenge_LastHomeSchool_name` | `"Last Home: Elementary School"` | `"Last Home : École élémentaire"` |
| `Challenge_LastHomeSchool_desc` | `"..."` | `"..."` |

Les valeurs exactes des description sont à rédiger lors de l'implémentation.
→ Si le moteur résout automatiquement `gameMode` depuis `Challenge_<id>_name`,
  le champ `gameMode` des 4 fichiers challenge peut être supprimé.
→ Sinon, le remplacer par `getText("Challenge_LastHome<id>_name")`.

### 2. HUD vague (IG_UI_EN.txt / IG_UI_FR.txt)

```
media/lua/client/LastHomeClient.lua — drawWaveHud()
```

| Clé | EN | FR |
|-----|----|----|
| `IGUI_LH_Base` | `"Base: %1"` | `"Base : %1"` |
| `IGUI_LH_Prep` | `"Preparation - Wave %1 in %2"` | `"Préparation - Vague %1 dans %2"` |
| `IGUI_LH_Direction` | `"Direction: %1"` | `"Direction : %1"` |
| `IGUI_LH_EstimatedSize` | `"Estimated size: ~%1 zombies"` | `"Taille estimée : ~%1 zombies"` |
| `IGUI_LH_SkipWave` | `"[K] Start next wave"` | `"[K] Lancer la prochaine vague"` |
| `IGUI_LH_WaveActive` | `"Wave %1 active - %2 remaining"` | `"Vague %1 active - %2 restantes"` |
| `IGUI_LH_ZombiesLeft` | `"Zombies remaining: %1"` | `"Zombies restants : %1"` |
| `IGUI_LH_GameOver` | `"Game over - score: %1 wave(s)"` | `"Game over - score : %1 vague(s)"` |

### 3. Spectateur (IG_UI_EN.txt / IG_UI_FR.txt)

```
media/lua/client/LastHomeClient.lua — drawWaveHud()
```

| Clé | EN | FR |
|-----|----|----|
| `IGUI_LH_SpectatorMode` | `"Spectator mode"` | `"Mode spectateur"` |
| `IGUI_LH_SpectatorSpawnUsed` | `"Zombie spawn used for this wave"` | `"Spawn zombie utilisé pour cette vague"` |
| `IGUI_LH_SpectatorSpawnHint` | `"Right-click outside to spawn 1 zombie"` | `"Clique droit dehors pour spawner 1 zombie"` |
| `IGUI_LH_SpectatorNextWave` | `"Spectator spawn resets next wave"` | `"Le spawn spectateur revient à la prochaine vague"` |

### 4. Menu contextuel spectateur (IG_UI_EN.txt / IG_UI_FR.txt)

```
media/lua/client/LastHomeClient.lua — onFillWorldObjectContextMenu(), ligne 813
```

Une seule chaîne, option de clic droit pour le spectateur.

| Clé | EN | FR |
|-----|----|----|
| `IGUI_LH_SpectatorSpawnHere` | `"Spawn a zombie here"` | `"Spawner un zombie ici"` |

### 5. Zone de confinement (IG_UI_EN.txt / IG_UI_FR.txt)

```
media/lua/client/LastHomeClient.lua — drawWaveHud()
```

| Clé | EN | FR |
|-----|----|----|
| `IGUI_LH_ZoneIn` | `"Zone: IN"` | `"Zone : IN"` |
| `IGUI_LH_ZoneOut` | `"Zone: OUT"` | `"Zone : OUT"` |
| `IGUI_LH_ZoneCountdown` | `"Out of zone! Return in %1s"` | `"Hors zone ! Revenez dans %1s"` |
| `IGUI_LH_ZoneDamaging` | `"Out of zone! Damage active"` | `"Hors zone ! Dégâts actifs"` |
| `IGUI_LH_ZoneWarning` | `"Out of zone! Return to base"` | `"Hors zone ! Retournez vers la base"` |
| `IGUI_LH_ZoneReturned` | `"Back in the zone"` | `"De retour dans la zone"` |

### 6. Role picker — titres et labels (IG_UI_EN.txt / IG_UI_FR.txt)

```
media/lua/client/LastHomeRolePicker.lua — prerender(), render(), createChildren()
```

| Clé | EN | FR |
|-----|----|----|
| `IGUI_LH_RolePicker_Title` | `"Choose your role"` | `"Choisis ton rôle"` |
| `IGUI_LH_RolePicker_Subtitle` | `"%1 roles available. Duplicates allowed and the choice is final."` | `"%1 rôles disponibles. Les doublons sont autorisés et le choix est définitif."` |
| `IGUI_LH_RolePicker_BuilderNote` | `"The Builder retains their automatic resource refill every 10 minutes."` | `"Le Builder conserve son refill automatique toutes les 10 minutes."` |
| `IGUI_LH_RolePicker_Choose` | `"Choose"` | `"Choisir"` |
| `IGUI_LH_RolePicker_Validating` | `"Validating..."` | `"Validation..."` |
| `IGUI_LH_RolePicker_Available` | `"Available"` | `"Disponible"` |
| `IGUI_LH_RolePicker_ValidatingRole` | `"Validating role..."` | `"Validation du rôle en cours..."` |
| `IGUI_LH_RolePicker_Unavailable` | `"Role unavailable."` | `"Rôle indisponible."` |
| `IGUI_LH_RolePicker_Denied` | `"Choice denied."` | `"Choix refusé."` |

### 7. Role picker — noms, résumés et forces des rôles (IG_UI_EN.txt / IG_UI_FR.txt)

```
media/lua/shared/LastHomeRoles.lua — ROLE_NAMES et ROLE_INFO (lignes 17-55)
media/lua/client/LastHomeRolePicker.lua — render() lignes 178-180
```

Chaque rôle a 3 chaînes affichées dans le picker : `name` (titre), `summary`
(description courte), `strengths` (forces). Actuellement hardcodées dans
`ROLE_INFO` et `ROLE_NAMES`.

**Option A (recommandée)** : remplacer les valeurs des 3 champs par des appels
`getText()` dans le code existant (dans `LastHomeRoles.lua` ou dans
`LastHomeRolePicker.lua` au moment de l'affichage). Cela évite de toucher à la
structure des données.

**Option B** : garder les champs `name`/`summary`/`strengths` comme clés et les
résoudre au render dans `LastHomeRolePicker.lua:178-180`.

Clés proposées (51 clés : 17 rôles × 3) :

| Clé | EN | FR |
|-----|----|----|
| `IGUI_LH_Role_Soldat` | `"Soldier"` | `"Soldat"` |
| `IGUI_LH_Role_Soldat_summary` | `"Combat / defense"` | `"Combat / défense"` |
| `IGUI_LH_Role_Soldat_strengths` | `"Guns, cover, melee"` | `"Tir, couverture, mêlée"` |
| `IGUI_LH_Role_Voleur` | `"Thief"` | `"Voleur"` |
| `IGUI_LH_Role_Voleur_summary` | `"Stealth loot"` | `"Loot furtif"` |
| `IGUI_LH_Role_Voleur_strengths` | `"Crowbar, stealth, runs"` | `"Crowbar, discrétion, sorties"` |
| `IGUI_LH_Role_Local` | `"Local"` | `"Local"` |
| `IGUI_LH_Role_Local_summary` | `"Repairs / resources"` | `"Réparations / ressources"` |
| `IGUI_LH_Role_Local_strengths` | `"Tools, crafting, logistics"` | `"Outils, craft, logistique"` |
| `IGUI_LH_Role_Medic` | `"Medic"` | `"Medic"` |
| `IGUI_LH_Role_Medic_summary` | `"Healing / support"` | `"Soin / support"` |
| `IGUI_LH_Role_Medic_strengths` | `"Heavy meds, stabilization"` | `"Soins lourds, stabilisation"` |
| `IGUI_LH_Role_Rambo` | `"Rambo"` | `"Rambo"` |
| `IGUI_LH_Role_Rambo_summary` | `"Melee tank"` | `"Tank mêlée"` |
| `IGUI_LH_Role_Rambo_strengths` | `"Axe, stamina, breaches"` | `"Hache, endurance, brèches"` |
| `IGUI_LH_Role_Sniper` | `"Sniper"` | `"Sniper"` |
| `IGUI_LH_Role_Sniper_summary` | `"Long range"` | `"Longue distance"` |
| `IGUI_LH_Role_Sniper_strengths` | `".308, scope, cover"` | `".308, lunette, couverture"` |
| `IGUI_LH_Role_Samourai` | `"Samurai"` | `"Samouraï"` |
| `IGUI_LH_Role_Samourai_summary` | `"Katana / mobility"` | `"Katana / mobilité"` |
| `IGUI_LH_Role_Samourai_strengths` | `"Blades, speed, precision"` | `"Lames, vitesse, précision"` |
| `IGUI_LH_Role_Geek` | `"Geek"` | `"Geek"` |
| `IGUI_LH_Role_Geek_summary` | `"Electronics / traps"` | `"Électronique / pièges"` |
| `IGUI_LH_Role_Geek_strengths` | `"Tinkering, alarms, gadgets"` | `"Bidouille, alarmes, gadgets"` |
| `IGUI_LH_Role_Survivaliste` | `"Survivalist"` | `"Survivaliste"` |
| `IGUI_LH_Role_Survivaliste_summary` | `"Nature / self-reliance"` | `"Nature / autonomie"` |
| `IGUI_LH_Role_Survivaliste_strengths` | `"Traps, loot, self-reliance"` | `"Pièges, loot, autonomie"` |
| `IGUI_LH_Role_Pompier` | `"Firefighter"` | `"Pompier"` |
| `IGUI_LH_Role_Pompier_summary` | `"Rescue / anti-fire"` | `"Sauvetage / anti-feu"` |
| `IGUI_LH_Role_Pompier_strengths` | `"Axe, extinguisher, rescue"` | `"Hache, extincteur, secours"` |
| `IGUI_LH_Role_Athlete` | `"Athlete"` | `"Athlète"` |
| `IGUI_LH_Role_Athlete_summary` | `"Speed / mobility"` | `"Vitesse / mobilité"` |
| `IGUI_LH_Role_Athlete_strengths` | `"Sprint, dodge, runs"` | `"Course, esquive, sorties"` |
| `IGUI_LH_Role_Eclaireur` | `"Scout"` | `"Éclaireur"` |
| `IGUI_LH_Role_Eclaireur_summary` | `"Recon / guide"` | `"Repérage / guide"` |
| `IGUI_LH_Role_Eclaireur_strengths` | `"Map, stealth, intel"` | `"Carte, discrétion, info"` |
| `IGUI_LH_Role_Demolisseur` | `"Demolisher"` | `"Démolisseur"` |
| `IGUI_LH_Role_Demolisseur_summary` | `"Explosives / chaos"` | `"Explosifs / chaos"` |
| `IGUI_LH_Role_Demolisseur_strengths` | `"Bombs, molotovs, area"` | `"Bombes, molotovs, zone"` |
| `IGUI_LH_Role_Invincible` | `"Invincible"` | `"Invincible"` |
| `IGUI_LH_Role_Invincible_summary` | `"Max everything"` | `"Tout au max"` |
| `IGUI_LH_Role_Invincible_strengths` | `"Weapons, craft, meds, tank"` | `"Armes, craft, soins, tank"` |
| `IGUI_LH_Role_Mule` | `"Mule"` | `"Mule"` |
| `IGUI_LH_Role_Mule_summary` | `"Transport / storage"` | `"Transport / stockage"` |
| `IGUI_LH_Role_Mule_strengths` | `"Big bag, supplies, support"` | `"Gros sac, vivres, support"` |
| `IGUI_LH_Role_Builder` | `"Builder"` | `"Builder"` |
| `IGUI_LH_Role_Builder_summary` | `"Construction / defense"` | `"Construction / défense"` |
| `IGUI_LH_Role_Builder_strengths` | `"Resources, unlim. carry, refill"` | `"Ressources, poids illimité, refill"` |
| `IGUI_LH_Role_Civil` | `"Civilian"` | `"Civil"` |
| `IGUI_LH_Role_Civil_summary` | `"Hard mode"` | `"Mode difficile"` |
| `IGUI_LH_Role_Civil_strengths` | `"Pure survival, no bonuses"` | `"Survie pure, aucun bonus"` |

Note : les clés utilisent le nom anglais du rôle comme identifiant pour la
clé (Soldat → Rôle_Soldat, Voleur → Rôle_Voleur, etc.) pour que les fichiers
EN soient naturels et les fichiers FR faciles à maintenir.

### 8. Noms de maisons (IG_UI_EN.txt / IG_UI_FR.txt)

```
media/lua/shared/LastHomeShared.lua — HOUSE_DEFS, champ name (lignes ~13-95)
media/lua/client/LastHomeClient.lua — drawWaveHud() ligne 591, "Base: <nom>"
```

| Clé | EN | FR |
|-----|----|----|
| `IGUI_LH_House_Hospital` | `"Hospital"` | `"Hôpital"` |
| `IGUI_LH_House_Villa` | `"Villa"` | `"Villa"` |
| `IGUI_LH_House_Prison` | `"Prison"` | `"Prison"` |
| `IGUI_LH_House_School` | `"Elementary School"` | `"École élémentaire"` |

### 9. Alertes serveur (IG_UI_EN.txt / IG_UI_FR.txt)

```
media/lua/server/LastHomeWaves.lua — notifyPlayer() et broadcastAlert()
Messages envoyés au client via le système AlertMessage.
```

Ces chaînes sont envoyées par le serveur via `notifyPlayer()` (message privé)
et `broadcastAlert()` (message global). Elles sont préfixées par
`"[Last Home] "` et affichées dans le HUD via `AlertMessage`.

| Clé | EN | FR |
|-----|----|----|
| `IGUI_LH_Alert_GameOver` | `"Game over! Final score: %1 wave(s)."` | `"Game over ! Score final : %1 vague(s)."` |
| `IGUI_LH_Alert_WavePrep` | `"Wave %1 in %2%3\nDirection: %4\nEstimated: ~%5 zombies"` | `"Vague %1 dans %2%3\nDirection : %4\nEstimé : ~%5 zombies"` |
| `IGUI_LH_Alert_WaveStart` | `"Wave %1! Zombies incoming from %2!"` | `"Vague %1 ! Les zombies arrivent par %2 !"` |
| `IGUI_LH_Alert_WaveCleared` | `"Wave %1 cleared! Next wave in %2."` | `"Vague %1 éliminée ! Prochaine vague dans %2."` |
| `IGUI_LH_Alert_SkipTriggered` | `"Next wave launched immediately!"` | `"La prochaine vague est lancée immédiatement !"` |
| `IGUI_LH_Alert_PlayerDied` | `"%1 is dead and becomes a spectator."` | `"%1 est mort et devient spectateur."` |
| `IGUI_LH_Alert_SpectatorWaveOnly` | `"Spectator spawn is only active during waves."` | `"Le spawn spectateur n'est actif que pendant les vagues."` |
| `IGUI_LH_Alert_SpectatorUsed` | `"You already used your spawn for this wave."` | `"Tu as déjà utilisé ton spawn pour cette vague."` |
| `IGUI_LH_Alert_SpectatorInvalid` | `"Invalid spawn."` | `"Spawn invalide."` |
| `IGUI_LH_Alert_SpectatorCantSpawn` | `"Cannot spawn a zombie here."` | `"Impossible de spawner un zombie ici."` |
| `IGUI_LH_Alert_OneMinutePrep` | `"Wave %1 in 1 min! Get ready!"` | `"Vague %1 dans 1 min ! Préparez-vous !"` |
| `IGUI_LH_Alert_OneMinuteWave` | `"Wave %1: less than 1 min before the next horde!"` | `"Vague %1 : plus qu'1 min avant la prochaine horde !"` |
| `IGUI_LH_Alert_TimeUp` | `"Time's up! Wave %1 inbound... remaining zombies join the horde!"` | `"Temps écoulé ! La vague %1 arrive... les zombies restants rejoignent la horde !"` |
| `IGUI_LH_Alert_BackInZone` | `"Back in the zone."` | `"De retour dans la zone."` |
| `IGUI_LH_Alert_OutOfZone` | `"Out of zone! Return in 10s."` | `"Hors zone ! Revenez dans 10s."` |
| `IGUI_LH_Alert_Damaging` | `"Out of zone! Damage active."` | `"Hors zone ! Dégâts actifs."` |

## Changements

### 1. Fichiers de traduction

Créer `media/lua/shared/Translate/EN/Challenge_EN.txt` et
`media/lua/shared/Translate/FR/Challenge_FR.txt`.

Créer `media/lua/shared/Translate/EN/IG_UI_EN.txt` et
`media/lua/shared/Translate/FR/IG_UI_FR.txt`.

### 2. Remplacer les chaînes hardcodées

#### `media/lua/client/LastHomeClient.lua`

- `drawWaveHud()` : toutes les chaînes string.format → `getText()`.
- `drawStockArrow()` : pas de changement (marqueurs ASCII + distance pure).
- `onFillWorldObjectContextMenu()` : `"Spawner un zombie ici"` →
  `getText("IGUI_LH_SpectatorSpawnHere")`.

#### `media/lua/client/LastHomeRolePicker.lua`

- `prerender()` : titre, subtitle, builder note → `getText()`.
- `render()` : les 3 champs par rôle (name, summary, strengths) →
  `getText("IGUI_LH_Role_<id>")`, `getText("IGUI_LH_Role_<id>_summary")`,
  `getText("IGUI_LH_Role_<id>_strengths")`.
- `createChildren()` : bouton "Choisir" → `getText("IGUI_LH_RolePicker_Choose")`.
- `updateButtons()` : "Validation..." → `getText("IGUI_LH_RolePicker_Validating")`.

#### `media/lua/shared/LastHomeRoles.lua`

- `ROLE_NAMES` : chaque nom de rôle → `getText("IGUI_LH_Role_<id>")`.
  Possible aussi au moment de l'affichage dans `LastHomeRolePicker.lua`.

#### `media/lua/shared/LastHomeShared.lua`

- `HOUSE_DEFS[].name` : chaque nom de maison → `getText("IGUI_LH_House_<id>")`.
  Possible aussi au moment de l'affichage dans `LastHomeClient.lua`.

#### `media/lua/server/LastHomeWaves.lua`

- `broadcastAlert()` et `notifyPlayer()` : les chaînes string.format →
  `getText("IGUI_LH_Alert_*")`.
- Attention : certaines alertes utilisent `string.format()` avec `%d/%s` ;
  les remplacer par `getText()` avec `%1`, `%2` (format PZ).

#### `media/lua/client/LastStand/LastHomeHospital.lua`
#### `media/lua/client/LastStand/LastHomeVilla.lua`
#### `media/lua/client/LastStand/LastHomePrison.lua`
#### `media/lua/client/LastStand/LastHomeSchool.lua`

- `gameMode` : à remplacer par `getText("Challenge_LastHome<id>_name")` si le
  moteur ne résout pas automatiquement `gameMode` depuis les fichiers Translate.

### 3. Gestion des paramètres

`getText()` en PZ supporte les paramètres positionnels `%1`, `%2`, etc.
Pour `broadcastAlert(string.format("...", ...))`, il faut :
- Définir la chaîne dans le fichier Translate avec `%1`, `%2` comme placeholders.
- Appeler `getText("IGUI_LH_Alert_*", val1, val2, ...)`.

### 4. Fallback

Si `getText("IGUI_LH_...")` retourne la clé elle-même (pas de fichier
trouvé pour la langue du joueur), le texte anglais apparaîtra (les fichiers
EN sont chargés comme fallback par le moteur PZ).

## Critères d'acceptation

1. Un joueur en langue **française** voit **tous** les textes du mod en
   français : HUD, challenges, role picker (noms, résumés, forces), noms de
   maisons, alertes, menu contextuel spectateur.
2. Un joueur en langue **anglaise** (ou langue non traduite) voit tous les
   textes en anglais.
3. Les paramètres (`%1`, `%2`) sont correctement substitués dans le HUD,
   les alertes, les messages de zone.
4. Aucune chaîne française hardcodée ne subsiste dans les endroits listés
   ci-dessus.
5. Les logs et diagnostics (print, logClient, logBoundary) restent en anglais.

## Fichiers impactés

- `media/lua/shared/Translate/EN/Challenge_EN.txt` — nouveau
- `media/lua/shared/Translate/EN/IG_UI_EN.txt` — nouveau
- `media/lua/shared/Translate/FR/Challenge_FR.txt` — nouveau
- `media/lua/shared/Translate/FR/IG_UI_FR.txt` — nouveau
- `media/lua/shared/LastHomeRoles.lua` — ROLE_NAMES / ROLE_INFO
- `media/lua/shared/LastHomeShared.lua` — HOUSE_DEFS name
- `media/lua/client/LastHomeClient.lua` — drawWaveHud, context menu
- `media/lua/client/LastHomeRolePicker.lua` — prerender, render, createChildren
- `media/lua/client/LastStand/LastHomeHospital.lua` — gameMode
- `media/lua/client/LastStand/LastHomeVilla.lua` — gameMode
- `media/lua/client/LastStand/LastHomePrison.lua` — gameMode
- `media/lua/client/LastStand/LastHomeSchool.lua` — gameMode
- `media/lua/server/LastHomeWaves.lua` — broadcastAlert, notifyPlayer
- `specs/LH-16-localisation.md` — nouvelle spec
- `README.md` — table des specs
- `project-state.md` — ticket + note
- `mod.info` — bump version

## Dépendances

- Aucune (travail purement cosmétique / i18n)

## Taille estimée

Medium (M) — création de 4 fichiers, modifications dans ~12 fichiers Lua.
