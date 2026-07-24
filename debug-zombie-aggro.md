# État des lieux : les zombies de vague n'attaquent pas le joueur (Project Zomboid B41, mod Last Home)

## 1. Contexte

- Je développe un mod **Last Home** pour Project Zomboid **Build 41** (version Steam Mac, ~41.78).
- Mode de jeu : **Challenge personnalisé** (menu Challenges). Le challenge sélectionné force une « maison » (ici **Villa**) et lance un système de vagues zombies.
- Objectif : les zombies d'une vague doivent **se déplacer vers la base (villa) et attaquer les joueurs**.
- Symptôme : quelle que soit l'approche essayée, **les zombies spawness n'attaquent jamais le joueur**. Ils peuvent s'approcher (pathing) mais restent passifs / passent en idle, jamais en `AttackState`.

## 2. Environnement / configuration

### Spawn des zombies de vague
- Les zombies sont créés via la fonction Lua globale :
  ```lua
  addZombiesInOutfit(x, y, z, count, nil, 0)
  ```
  (x,y,z = points de spawn calculés autour du centre de la maison, `count` zombies, `outfit=nil`, `range=0`.)
- Spawn à **20 tiles** au sud du centre de la villa (testé aussi à 30). Coordonnées réelles observées : spawn vers `(13524..13541, 2872, 0)`, villa rect `x=13524..13545, y=2830..2858`.
- Chaque zombie spawné est taggé via `zombie:getModData()` :
  ```lua
  modData.LH_waveZombie = true
  modData.LH_waveNumber = wave
  modData.LH_countedDead = false
  zombie:setCanWalk(true)
  ```

### Sandbox vars du challenge (appliquées via `LastHomeVilla.setSandBoxVars`)
```lua
SandboxVars.Zombies = 6          -- 6 = "None" (désactive la pop vanilla ambiante)
SandboxVars.Distribution = 1
SandboxVars.MetaEvent = 1
...
ZombieConfig.PopulationMultiplier = 0
ZombieConfig.PopulationStartMultiplier = 0
ZombieConfig.PopulationPeakMultiplier = 0
ZombieConfig.RespawnHours = 0
ZombieConfig.RespawnUnseenHours = 0
ZombieConfig.RespawnMultiplier = 0
ZombieConfig.RallyGroupSize = 0
```
- ⚠️ **Piste non explorée** : `SandboxVars.Zombies = 6` ("None") désactive la population ambiante, mais **peut-il aussi désactiver l'attaque globalement** pour tous les zombies (y compris ceux spawnés manuellement) ? À vérifier.
- `ZombieLore` (Strength/Speed/Cognition/Memory/Hearing/Sight) n'est **pas** modifié → defaults vanilla (normal).

### Confinement du joueur
- Le joueur est **confiné dans un rectangle** autour de la villa (`boundary`), dégâts s'il en sort (10s de compte à rebours puis 5 hp/tick). Donc le joueur ne peut pas facilement aller vers les zombies.

## 3. Symptôme précis (observé en jeu + logs)

Quel que soit le mécanisme d'aggro forcé essayé :
- Les zombies peuvent **se déplacer** vers le joueur (pathing OK via `addSound` investigation ou `pathToCharacter`).
- Mais ils **ne passent jamais en `AttackState`** → n'attaquent jamais.
- Même constat en **vanilla pure** (aucun forçage, spawn à 20 tiles) : le joueur s'approche des zombies → ils ne l'attaquent pas.

## 4. Chronologie des approches essayées et résultats

Tests faits en partie réelle, avec logs diagnostiques lisant `getTarget()`, `getCurrentState()`, `isAttacking()`, `isZombiesDontAttack()`, `isFakeDead()`, `isCanWalk()`, `isTargetVisible()` sur les zombies.

| # | Approche | Résultat observé |
|---|----------|------------------|
| 1 | `addSound(player, x, y, z, radius, vol)` au **centre fixe** de la base (z=0) | Zombies convergent vers le RDC, ne voient pas le joueur (z=1 étage) → aucun aggro. Régression identifiée. |
| 2 | `addSound` à la **position réelle du joueur** (x,y,z) | Zombies pathent jusqu'au joueur mais restent en investigation, **aucun aggro**. |
| 3 | `zombie:spotted(player, true)` par pulse (toutes les 3s) | `spotted` s'exécute sans erreur (`fail=0`), mais `getTarget() → none` → **ne set pas le target**. Aucun aggro. |
| 4 | `zombie:addAggro(player, 100)` par pulse | S'exécute sans erreur mais **no-op effectif** : `getTarget() → none` même à `minDist=0` (zombie sur la tuile du joueur). Aucun aggro. |
| 5 | `zombie:setTarget(player)` par pulse | ✅ **set le target** : `getTarget() → player:X`, `isTargetVisible() → true`. **Mais** `getCurrentState()` reste `WalkTowardState` / `ZombieIdleState` / `PathFindState2` / `ClimbOverFenceState` — **jamais `AttackState`**. `isAttacking() → false` même à `minDist=0` (zombie sur la tuile du joueur). |
| 6 | `setTarget` + arrêt du pulse à l'arrivée (≤6 tiles) | Idem : target posé, `targetVis=true`, mais pas de transition vers `AttackState`. |
| 7 | Au **spawn** seulement : `setTarget(player le plus proche)` + `spotted(player, true)`, **pas de `pathToCharacter`**, pas de pulse | Le joueur rapporte que les zombies **ne l'attaquent pas** même en s'approchant. |
| 8 | **Vanilla pure** : aucun forçage, spawn à 20 tiles | Les zombies n'attaquent pas, même quand le joueur s'approche à ~2 tiles. |

## 5. Faits API vérifiés (IsoZombie B41 — javadocs officielles + tests en jeu)

Sources : `projectzomboid.com/modding/zombie/characters/IsoZombie.html`, `zomboid-javadoc.com/41.78`, parsage du `.class` `zombie/characters/IsoZombie.class`.

Méthodes pertinentes et comportement **observé** :
- `setTarget(IsoMovingObject)` → set le champ public `target`. **Confirmeé fonctionne** (`getTarget()` renvoie le joueur ensuite).
- `spotted(IsoMovingObject, boolean bForced)` → s'exécute sans erreur mais **ne set pas `target`** seul.
- `addAggro(IsoMovingObject, float)` → **no-op effectif** dans notre contexte (`getTarget()` reste `none`).
- `pathToCharacter(IsoGameCharacter)` → force le pathing, met le zombie en `PathFindState`/`WalkTowardState`. **Suspecté de bloquer la transition vers `AttackState`** (state machine maintenu en mode « marche vers »).
- `AttemptAttack()` → `boolean`, force un swing d'attaque. **Non testé**.
- `getTarget()`, `getCurrentState()`, `isAttacking()`, `isZombiesDontAttack()`, `isFakeDead()`, `isCanWalk()`, `isTargetVisible()` → tous exposés au Lua.

Champs publics : `target`, `LastTargetSeenX/Y/Z`, `alerted`, `AttackAnimTime`.

Cerveau IA `GameCharacterAIBrain` (champs publics) : `spottedCharacters` (ArrayList<IsoGameCharacter>), `aiTarget` (IsoMovingObject) — **séparés** du champ `target` de l'IsoZombie.

⚠️ **Le moteur vanilla ne fournit aucun pattern Lua** : toute la logique d'aggro/perception est en Java ; aucune fonction vanilla n'appelle `setTarget`/`spotted`/`addAggro` depuis Lua. Pas d'exemple canonique à copier.

## 6. Le mystère central

> Même avec `setTarget(player)` réussi (`getTarget()=player`, `isTargetVisible()=true`), un zombie **sur la tuile même du joueur** (`minDist=0`, même z) reste en `WalkTowardState`/`ZombieIdleState` et **n'attaque jamais**. `isZombiesDontAttack()=false`, `isFakeDead()=false`, `isCanWalk()=true`.

Le state machine ne transitionne pas vers `AttackState` malgré une cible valide et visible à portée. Quelque chose empêche la transition attaque — ce n'est pas le `target` (il est posé), ni les flags `dontAttack`/`fakeDead`.

## 7. Hypothèses restantes / pistes NON explorées

1. **`SandboxVars.Zombies = 6` ("None") désactiverait-il l'attaque globalement** (pas seulement la pop ambiante) ? Si oui, tous les zombies — même spawnés manuellement — ne pourraient pas attaquer. → **Piste forte à vérifier en premier** (tester avec `SandboxVars.Zombies = 4` "Normal" + population à 0 via ZombieConfig).
2. **Zombies spawnés via `addZombiesInOutfit` = zombies « non réels » ?** Peut-être qu'ils ont un flag (`bRemote`, `authOwner`, `bIndoorZombie`...) qui les empêche d'attaquer, ou que leur IA n'est pas tickée correctement côté serveur. Vérifier si un spawn via la population normale (au lieu de `addZombiesInOutfit`) attaque.
3. **Le brain `GameCharacterAIBrain` doit être alimenté** (`spottedCharacters`, `aiTarget`) plutôt que juste `zombie.target`. `setTarget` ne suffit peut-être pas ; il faut peut-être ajouter le joueur à `zombie:getBrain().spottedCharacters` + set `aiTarget`. API d'accès au brain à confirmer (`getBrain()` ?).
4. **`AttemptAttack()` forcé à portée** : appeler `zombie:AttemptAttack()` quand `minDist <= ~2` pour forcer le swing, contournant le state machine.
5. **Sight/Hearing perception** : en vanilla pure, les zombies n'attaquent que s'ils perçoivent le joueur (vue/son). Un joueur silencieux dans une villa fermée à 20 tiles n'est pas perçu. → Le confinement + vanilla pure sont incompatibles : il faut soit un `addSound` minimal au spawn (investigation vers la base), soit lever le confinement.

## 8. État actuel du code

`media/lua/server/LastHomeWaves.lua` :
- `SPAWN_DISTANCE = 20`.
- Spawn vanilla pur : `addZombiesInOutfit` + tag modData (`LH_waveZombie`...) + `setCanWalk(true)`.
- **Aucun** appel à `setTarget`/`spotted`/`addAggro`/`pathToCharacter`/`addSound`. Aucun pulse.
- `onZombieDead` décrémente le compteur et déclenche la vague suivante quand `zombieCount <= 0`.
- Le cycle vague/prep/skip/HUD/confinement fonctionne.

## 9. Questions pour le LLM consulté

1. `SandboxVars.Zombies = 6` ("None") **désactive-t-il l'attaque des zombies globalement**, y compris pour des zombies spawnés manuellement via `addZombiesInOutfit` ? Si oui, comment désactiver la pop ambiante SANS désactiver l'attaque ?
2. Pourquoi un zombie avec `setTarget(player)` + `isTargetVisible()=true` + sur la tuile du joueur ne passe-t-il **jamais** en `AttackState` ? Quelle est la condition exacte de transition `WalkTowardState → AttackState` côté Java ?
3. Quelle est la méthode **fiable** (Lua, B41) pour forcer un zombie à attaquer un joueur donné ? `setTarget` seul ne suffit pas. Faut-il manipuler `GameCharacterAIBrain.spottedCharacters`/`aiTarget` ? Appeler `AttemptAttack()` ?
4. Les zombies de `addZombiesInOutfit` sont-ils « actifs » (IA tickée) côté serveur en solo, ou faut-il un spawn différent (ex. population normale) pour qu'ils attaquent ?
5. Existe-t-il un pattern de mod connu (B41) qui fait attaquer des zombies à un joueur précis (horde dirigée) ?

---

## Résumé en une phrase

Des zombies spawnés via `addZombiesInOutfit` dans un challenge qui met `SandboxVars.Zombies = 6` ("None") n'attaquent jamais le joueur, même avec `setTarget` + `isTargetVisible()=true` à portée zéro ; `addAggro`/`spotted` sont no-ops ; `pathToCharacter` bloque `AttackState` ; et même en vanilla pure ils n'attaquent pas — il faut déterminer si c'est le sandbox "None" qui désactive l'attaque, un problème avec les zombies spawnés manuellement, ou un mécanisme du brain non alimenté.