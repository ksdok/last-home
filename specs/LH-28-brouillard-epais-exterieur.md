# LH-28 (M) - Last Home : brouillard épais permanent à l'extérieur

## Contexte

Last Home est un mode défense coopératif : les joueurs préparent leur base
pendant la prep puis subissent des vagues croissantes de zombies arrivant de
directions de plus en plus nombreuses (LH-03), avec une zone de confinement qui
les empêche de fuir (LH-05). L'host souhaite ajouter un **brouillard épais et
permanent à l'extérieur** du bâtiment scénario pour :

- renforcer l'atmosphère de siège / horreur
- réduire la visibilité au loin, donc l'anticipation des vagues entrantes
- rendre les zombies approchant depuis les directions éloignées (jusqu'à 360°)
  plus menaçants car moins visibles avant d'être proches

L'effet doit concerner **l'extérieur** (le monde ouvert autour de la base), pas
l'intérieur du bâtiment scénario qui doit rester visible pour que les joueurs
puissent organiser leurs défenses et leur stock au sol (LH-19).

## Objectif

Maintenir un **brouillard épais** (fog intensity élevée) en permanence à
l'extérieur pendant une partie Last Home active (prep + vague), tout en
préservant la visibilité à l'intérieur du bâtiment scénario.

Contraintes :

- l'effet doit démarrer quand la partie Last Home démarre (`Server.started` et
  maison définie) et s'arrêter au game over
- ne doit pas empêcher les joueurs de voir leur HUD (LH-06), le stock au sol
  (LH-19), ni leur personnage / inventaire
- ne doit pas casser le spawn des zombies de vague (LH-03), le nettoyage ambiant
  (LH-13) ni le tagging `LH_waveZombie`
- doit fonctionner en MP Host + solo sandbox (bootstrap two-VM, LH-MP-2)

## Changements

### 1. Constantes de configuration

Dans `media/lua/shared/LastHomeShared.lua`, ajouter :

```lua
LastHomeShared.FOG_ENABLED = true
LastHomeShared.FOG_INTENSITY = 0.9   -- 0.0 = clair, 1.0 = brouillard maximal
```

- `FOG_INTENSITY` : valeur cible d'intensité du brouillard (à calibrer en jeu ;
  voir Questions en attente). Valeur haute (≥ 0.8) pour un brouillard "épais".
- `FOG_ENABLED` : permet à l'host de désactiver la feature sans retirer le code.

### 2. Override périodique de l'intensité du brouillard

Le moteur PZ B41 gère le brouillard via le `ClimateManager` (climat / météo),
dont l'intensité est normalement pilotée par la simulation météo et les
`SandboxVars`. Pour forcer un brouillard permanent, il faut **surcharger**
l'intensité du fog de manière répétée, car la simulation météo la ré-évalue en
permanence.

Approche attendue (à valider côté API — voir Questions en attente) :

- utiliser `getClimateManager()` et un setter d'override du fog intensity
  (candidats à vérifier : `ClimateManager:setFogIntensity(float)` /
  `setFogIntensityOverride(float)` / passage par `ClimateManager:transmit()`).
- ré-appliquer l'override à intervalle régulier (ex. toutes les 1 à 2s) tant
  que la partie est active, pour contrer la ré-évaluation météo
- côté **serveur** (authoritative) si le climate manager serveur propage la
  valeur aux clients ; sinon appliquer l'override **côté client** sur chaque VM
  via un `OnTick` / `OnTickEvenPaused` et synchroniser l'état via le state
  existant (comme la zone de confinement LH-05 / le HUD LH-06)

Pseudo-code indicatif (serveur) :

```lua
if LastHomeShared.FOG_ENABLED and Server.started
   and not Server.gameOver and Server.house ~= nil then
    if Server.nextFogRefreshAt == nil or now >= Server.nextFogRefreshAt then
        applyFogOverride(LastHomeShared.FOG_INTENSITY)
        Server.nextFogRefreshAt = now + FOG_REFRESH_INTERVAL_SECONDS
    end
end
```

Et à l'arrêt / game over, **relâcher** l'override pour revenir au comportement
météo vanilla :

```lua
releaseFogOverride()
```

### 3. Préserver l'intérieur du bâtiment scénario

Le brouillard étant un effet global de scène, il peut reduire la visibilité
même en intérieur selon la façon dont le moteur le rend. Deux pistes à valider
en jeu (voir Questions en attente) :

- **Piste A (préférée)** : le moteur PZ réduit déjà naturellement l'effet visuel
  du fog en intérieur (pieces couvertes / `IsoRoom`). Si c'est le cas, aucun
  traitement spécial n'est nécessaire — juste calibrer `FOG_INTENSITY` pour que
  l'extérieur soit épais sans rendre l'intérieur opaque.
- **Piste B (repli)** : si l'intérieur devient trop brumeux, réduire
  `FOG_INTENSITY` à un compromis acceptable, ou envisager un override ciblé
  restauré autour de la zone intérieure du bâtiment (plus complexe, à découper
  dans un ticket séparé si la piste A ne suffit pas).

### 4. Cycle de vie lié à la partie

L'override du fog suit le même cycle de vie que le cleanup ambiant (LH-13) :

- **démarrage** : dès que la partie Last Home est active et la maison définie
  (prep ou vague)
- **pendant** : prep + vague, rafraîchi périodiquement
- **arrêt** : au game over (`Server.gameOver = true`) ou sur `resetState()`
  (retour menu / nouvelle partie), relâcher l'override pour ne pas laisser un
  brouillard permanent dans une partie vanilla

Ne **pas** activer le fog dans une partie qui n'est pas un scénario Last Home
(`isScenarioHouse()` déjà disponible via LH-MP-3), pour ne pas altérer le
gameplay vanilla ni le mod standalone PZRolePlay (LH-25).

### 5. Logs ciblés

Logger côté serveur :

- l'activation du fog override au démarrage de partie (`[LastHome] Brouillard
  exterieur active (intensity=0.9)`)
- le relâchement au game over / reset (`[LastHome] Brouillard exterieur
  relache`)

But : pouvoir vérifier en logs que l'override est bien posé et relâché, et ne
fuit pas hors d'une partie Last Home.

## Fichiers impactés

- `media/lua/shared/LastHomeShared.lua`
  - constantes `FOG_ENABLED`, `FOG_INTENSITY`, `FOG_REFRESH_INTERVAL_SECONDS`
  - helpers `applyFogOverride(intensity)` / `releaseFogOverride()` (à valider
    côté API)
- `media/lua/server/LastHomeWaves.lua`
  - état `Server.nextFogRefreshAt` dans `resetState()`
  - rafraîchissement périodique dans la boucle serveur (à côté du cleanup
    ambiant LH-13)
  - activation au `startGame` / prep, relâchement au `gameOver`
- `media/lua/client/LastHomeClient.lua` *(si l'override doit être appliqué côté
  client — à valider)*
  - réception de l'état fog via le state sync existant et application locale
- `specs/LH-28-brouillard-epais-exterieur.md` (cette spec)
- `README.md` — table des specs (LH-28 ajoutée, statut 📝)
- `project-state.md` — backlog High priority + specs list (LH-28)

## Modifications détaillées

### État serveur

Dans `resetState()` (LastHomeWaves.lua) :

```lua
Server.nextFogRefreshAt = nil
Server.fogOverrideActive = false
```

Constante de rythme (LastHomeShared.lua) :

```lua
LastHomeShared.FOG_REFRESH_INTERVAL_SECONDS = 2
```

### Flux attendu

- au démarrage de la partie (`Server.started = true` + maison définie) :
  - `applyFogOverride(FOG_INTENSITY)`
  - `Server.fogOverrideActive = true`
  - planifier `Server.nextFogRefreshAt = now + FOG_REFRESH_INTERVAL_SECONDS`
- sur la boucle serveur (OnTick) :
  - si partie active + maison scénario + `now >= Server.nextFogRefreshAt` :
    `applyFogOverride(FOG_INTENSITY)` + repousser `nextFogRefreshAt`
- au game over / `resetState()` :
  - `releaseFogOverride()`
  - `Server.fogOverrideActive = false`
  - `Server.nextFogRefreshAt = nil`

## Critères d'acceptation

1. En partie Last Home active (prep + vague), l'extérieur présente un brouillard
   épais réduisant nettement la visibilité au loin.
2. L'intérieur du bâtiment scénario reste suffisamment visible pour organiser
   défenses, stock au sol (LH-19) et HUD (LH-06).
3. Le brouillard est ré-appliqué périodiquement (ne se dissipe pas avec la
   météo vanilla pendant la partie).
4. Au game over, le brouillard est relâché (retour à la météo vanilla).
5. En `resetState()` (retour menu / nouvelle partie), l'override est relâché —
   aucune fuite de brouillard permanent dans une partie vanilla.
6. Le fog n'est actif que sur une partie scénario Last Home
   (`isScenarioHouse()`), pas sur une partie vanilla ni sur PZRolePlay (LH-25).
7. Le spawn des zombies de vague (LH-03), le nettoyage ambiant (LH-13) et le
   tagging `LH_waveZombie` ne sont pas impactés.
8. Aucune erreur Lua côté serveur/client liée au fog au lancement, pendant la
   partie, au game over, ni au reset.
9. Fonctionne en MP Host et en solo sandbox (bootstrap two-VM, LH-MP-2).

## Questions en attente

- **API exacte** : quel setter d'override du fog utiliser en B41
  (`ClimateManager:setFogIntensity` vs `setFogIntensityOverride` vs autre) ?
  Valider via les sources PZ / un test rapide.
- **Serveur vs client** : l'override posé côté serveur se propage-t-il aux
  clients via le climate sync, ou faut-il appliquer l'override côté client sur
  chaque VM ? (impacts MP Host + solo)
- **Intérieur** : la piste A (rendu naturellement réduit en intérieur) suffit-elle
  ou faut-il un traitement dédié (piste B) ?
- **Intensité cible** : valeur de `FOG_INTENSITY` donnant un brouillard "épais"
  sans rendre l'intérieur opaque — à calibrer en jeu (0.8 ? 0.9 ? 1.0 ?).
- **Pendant les vagues uniquement ou prep aussi ?** Décision suggérée :
  **prep + vague** (atmosphère continue), mais calibrable.

## Décisions

- Feature activée par défaut (`FOG_ENABLED = true`), désactivable par constante.
- Fog actif en prep + vague, relâché au game over et au reset.
- Restreint aux parties scénario Last Home via `isScenarioHouse()`.
- Approche override périodique (pas de modification des `SandboxVars` météo,
  qui restent gérées par le bootstrap LH-MP-2).

## Dépendances

- Dépend de LH-03 (cycle de vie vague/prep, `Server.started`, `Server.gameOver`)
- Dépend de LH-04 (définition des maisons et de leur centre)
- Dépend de LH-MP-3 (`isScenarioHouse()`)
- Dépend de LH-MP-2 (bootstrap two-VM, ne pas casser la config sandbox)
- Ne doit pas casser LH-13 (cleanup ambiant) ni LH-06 (HUD)

## Taille estimée

Medium (M) — la logique de cycle de vie est simple et calquée sur LH-13, mais
l'API `ClimateManager` fog en B41 nécessite une validation préalable
(serveur vs client, override vs setter simple, gestion intérieur), d'où les
Questions en attente avant implémentation.