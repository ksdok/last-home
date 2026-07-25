# LH-16 (M) - Last Home: Localisation FR/EN via Translate system

## Contexte

Toutes les chaînes affichées au joueur dans Last Home sont actuellement
hardcodées en français : titres de challenges, textes du HUD, messages du
role picker, libellés de la flèche de stock, logs console, etc.

Un joueur configurant le jeu en anglais voit donc du français — ce qui n'est
pas idéal pour la diffusion du mod.

Project Zomboid B41 supporte nativement la localisation via des fichiers de
traduction dans `media/lua/shared/Translate/<LANG>/`. L'API Lua
`getText("Key")` (ou `Translator.getText()`) résout la clé dans la langue
du joueur et tombe sur l'anglais par défaut si la traduction est absente.

## Objectif

1. Créer les fichiers de traduction EN (default) et FR pour les chaînes du mod.
2. Remplacer les chaînes hardcodées en français par des appels `getText()`.
3. Les chaînes de log/diagnostics restent en anglais (dev-facing).

## Translation files

### Structure à créer

```
media/lua/shared/Translate/
  EN/
    Challenge_EN.txt     -- ajouter les entrées LastHome dans le tableau existant
    IG_UI_EN.txt         -- ajouter les entrées LastHome dans le tableau existant
  FR/
    Challenge_FR.txt     -- idem, valeurs en français
    IG_UI_FR.txt         -- idem, valeurs en français
```

### Convention de nommage des clés

Toutes les clés du mod sont préfixées par `LH_` :

| Préfixe | Usage |
|---------|-------|
| `Challenge_LH_<id>_name` | Nom du challenge dans le menu Challenges |
| `Challenge_LH_<id>_desc` | Description du challenge |
| `IGUI_LH_<key>` | Texte HUD et interface |

### Clés de traduction

#### Challenges (Challenge_EN.txt / Challenge_FR.txt)

| Clé | EN | FR |
|-----|----|----|
| `Challenge_LastHomeHospital_name` | `"Last Home: Hospital"` | `"Last Home : Hôpital"` |
| `Challenge_LastHomeHospital_desc` | `"Defend the hospital against growing waves of zombies."` | `"Défendez l'hôpital contre des vagues croissantes de zombies."` |
| `Challenge_LastHomeVilla_name` | `"Last Home: Villa"` | `"Last Home : Villa"` |
| `Challenge_LastHomeVilla_desc` | `"Defend the villa against growing waves of zombies."` | `"Défendez la villa contre des vagues croissantes de zombies."` |
| `Challenge_LastHomePrison_name` | `"Last Home: Prison"` | `"Last Home : Prison"` |
| `Challenge_LastHomePrison_desc` | `"Defend the prison against growing waves of zombies."` | `"Défendez la prison contre des vagues croissantes de zombies."` |
| `Challenge_LastHomeSchool_name` | `"Last Home: Elementary School"` | `"Last Home : École élémentaire"` |
| `Challenge_LastHomeSchool_desc` | `"Defend the elementary school against growing waves of zombies."` | `"Défendez l'école élémentaire contre des vagues croissantes de zombies."` |

#### HUD / UI (IG_UI_EN.txt / IG_UI_FR.txt)

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
| `IGUI_LH_SpectatorMode` | `"Spectator mode"` | `"Mode spectateur"` |
| `IGUI_LH_SpectatorSpawnUsed` | `"Zombie spawn used for this wave"` | `"Spawn zombie utilisé pour cette vague"` |
| `IGUI_LH_SpectatorSpawnHint` | `"Right-click outside to spawn 1 zombie"` | `"Clique droit dehors pour spawner 1 zombie"` |
| `IGUI_LH_SpectatorNextWave` | `"Spectator spawn resets next wave"` | `"Le spawn spectateur revient à la prochaine vague"` |
| `IGUI_LH_ZoneIn` | `"Zone: IN"` | `"Zone : IN"` |
| `IGUI_LH_ZoneOut` | `"Zone: OUT"` | `"Zone : OUT"` |
| `IGUI_LH_ZoneCountdown` | `"Out of zone! Return in %1s"` | `"Hors zone ! Revenez dans %1s"` |
| `IGUI_LH_ZoneDamaging` | `"Out of zone! Damage active"` | `"Hors zone ! Dégâts actifs"` |
| `IGUI_LH_ZoneWarning` | `"Out of zone! Return to base"` | `"Hors zone ! Retournez vers la base"` |
| `IGUI_LH_ZoneReturned` | `"Back in the zone"` | `"De retour dans la zone"` |

#### Role picker (IG_UI_EN.txt / IG_UI_FR.txt)

| Clé | EN | FR |
|-----|----|----|
| `IGUI_LH_RolePicker_Title` | `"Choose your role"` | `"Choisis ton rôle"` |
| `IGUI_LH_RolePicker_Subtitle` | `"%1 roles available. Duplicates allowed and the choice is final for the game."` | `"%1 rôles disponibles. Les doublons sont autorisés et le choix est définitif pour la partie."` |
| `IGUI_LH_RolePicker_BuilderNote` | `"The Builder retains their automatic resource refill every 10 minutes."` | `"Le Builder conserve son refill automatique de ressources toutes les 10 minutes."` |
| `IGUI_LH_RolePicker_Choose` | `"Choose"` | `"Choisir"` |
| `IGUI_LH_RolePicker_Validating` | `"Validating..."` | `"Validation..."` |
| `IGUI_LH_RolePicker_Available` | `"Available"` | `"Disponible"` |
| `IGUI_LH_RolePicker_ValidatingRole` | `"Validating role..."` | `"Validation du rôle en cours..."` |
| `IGUI_LH_RolePicker_Unavailable` | `"Role unavailable."` | `"Rôle indisponible."` |
| `IGUI_LH_RolePicker_Denied` | `"Choice denied."` | `"Choix refusé."` |

#### Stock arrow (IG_UI_EN.txt / IG_UI_FR.txt)

La flèche du stock utilise déjà des marqueurs ASCII + distance formatée
directement en Lua ; pas de traduction nécessaire (la valeur distance est
numérique).

## Changements

### 1. Fichiers de traduction

Créer `media/lua/shared/Translate/EN/Challenge_EN.txt` et
`media/lua/shared/Translate/FR/Challenge_FR.txt` avec les entrées
`Challenge_LastHome*`.

Créer `media/lua/shared/Translate/EN/IG_UI_EN.txt` et
`media/lua/shared/Translate/FR/IG_UI_FR.txt` avec les entrées `IGUI_LH_*`.

### 2. Remplacement des chaînes hardcodées

#### `media/lua/client/LastHomeClient.lua`

- Fonction `drawWaveHud()` : remplacer les chaînes `"Base: "`, `"Preparation - Vague %d dans %s"`, etc. par `getText("IGUI_LH_Base", ...)`, `getText("IGUI_LH_Prep", ...)`, etc.
- Fonction `drawStockArrow()` : pas de changement (marqueurs ASCII + distance pure).
- Messages zone : remplacer `"Zone: IN"`, `"Zone: OUT"`, etc.

#### `media/lua/client/LastHomeRolePicker.lua`

- `drawText("Choisis ton role")` → `drawText(getText("IGUI_LH_RolePicker_Title"))`
- Idem pour subtitle, builder note.

#### `media/lua/client/LastStand/LastHomeHospital.lua`

- `gameMode = "Last Home: Hopital"` → utiliser `getText("Challenge_LastHomeHospital_name")`
  ou laisser le challenge PZ lire la clé automatiquement.
  → À vérifier : PZ résout-t-il automatiquement `Challenge_<id>_name` pour
  le champ `gameMode` ? Si oui, il suffit de définir `id = "LastHomeHospital"`
  et le jeu résout la clé. Sinon, appel explicite à `getText()` dans le code.

#### `media/lua/client/LastStand/LastHomeVilla.lua`
#### `media/lua/client/LastStand/LastHomePrison.lua`
#### `media/lua/client/LastStand/LastHomeSchool.lua`

Même pattern.

### 3. Gestion des paramètres

`getText()` en PZ supporte les paramètres positionnels `%1`, `%2`, etc.
Les chaînes comme `"Preparation - Wave %1 in %2"` utilisent `%1` pour le
numéro de vague et `%2` pour le timer.

### 4. Fallback

Si `getText("IGUI_LH_...")` retourne la clé elle-même (pas de traduction
trouvée), le texte anglais apparaîtra. Les fichiers EN servent de fallback
naturel.

## Critères d'acceptation

1. Un joueur en langue **française** voit tous les textes du mod en français.
2. Un joueur en langue **anglaise** (ou langue non traduite) voit les textes
   en anglais.
3. Les paramètres (`%1`, `%2`) sont correctement substitués (numéro de vague,
   timer, compteurs).
4. Aucune régression dans le HUD, le role picker, les messages de zone, les
   menus challenge.
5. Les logs et diagnostics restent en anglais (inchangés).

## Fichiers impactés

- `media/lua/shared/Translate/EN/Challenge_EN.txt` — nouveau
- `media/lua/shared/Translate/EN/IG_UI_EN.txt` — nouveau
- `media/lua/shared/Translate/FR/Challenge_FR.txt` — nouveau
- `media/lua/shared/Translate/FR/IG_UI_FR.txt` — nouveau
- `media/lua/client/LastHomeClient.lua` — `drawWaveHud()`, zone messages
- `media/lua/client/LastHomeRolePicker.lua` — `prerender()`, `render()`
- `media/lua/client/LastStand/LastHomeHospital.lua` — `gameMode`
- `media/lua/client/LastStand/LastHomeVilla.lua` — `gameMode`
- `media/lua/client/LastStand/LastHomePrison.lua` — `gameMode`
- `media/lua/client/LastStand/LastHomeSchool.lua` — `gameMode`
- `specs/LH-16-localisation.md` — nouvelle spec
- `README.md` — table des specs
- `project-state.md` — ticket + note
- `mod.info` — bump version

## Dépendances

- Aucune (travail purement cosmétique / i18n)

## Taille estimée

Medium (M) — création de 4 fichiers, modifications dans 8 fichiers Lua.
