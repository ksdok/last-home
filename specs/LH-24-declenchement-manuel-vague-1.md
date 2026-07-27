# LH-24 (S) - Last Home : déclenchement manuel de la 1ère vague

## Contexte

LH-10 a fixé les timers : prep vague 1 = 2 min, preps suivantes = 5 min,
vague = 5 min, et un **skip** optionnel via la touche `K` (`skipToNextWave`)
qui lance la vague suivante immédiatement pendant la prep.

Aujourd'hui, la vague 1 démarre **automatiquement** à la fin du compte à rebours
de 2 min (`updatePhaseState` → `if Server.phase == "prep" and remaining <= 0
then startWave(false)`).

L'hôte veut que la **1ère vague n'ait pas de timer d'auto-start** : c'est un
joueur qui la déclenche manuellement. Le reste est inchangé.

## Objectif

Pour la **prep de la vague 1 uniquement** (`Server.currentWave == 0` en
phase prep) :
- **aucun compte à rebours** n'est armé (pas d'auto-start) ;
- la vague 1 ne démarre que quand un **joueur vivant** appuie sur `K`
  (`skipToNextWave`, mécanisme existant) ;
- le HUD affiche un prompt « Appuyez sur K pour lancer la vague 1 » au lieu
  d'un compte à rebours.

Pour tout le reste (vague 1 = 5 min une fois lancée, preps suivantes = 5 min
avec auto-start, vagues suivantes = 5 min, skip `K` sur les preps suivantes) :
**inchangé**.

## Décisions (validées par l'hôte)

- Déclencheur : **touche `K` existante** (réutilise `skipToNextWave`).
- Qui peut déclencher : **n'importe quel joueur vivant** (les
  spectateurs/morts ne peuvent pas).
- **Pas de fallback** : si personne n'appuie sur K, la vague 1 ne démarre
  jamais (choix assumé par l'hôte).

## Changements

### 1. `startPrepPhase` (serveur) — ne pas armer de timer pour la vague 1

Dans `media/lua/server/LastHomeWaves.lua`, `startPrepPhase` arme actuellement :

```lua
Server.phaseEndsAt = getNowSeconds() + prepDurationSeconds
```

Pour la vague 1 (`nextWave == 1`, i.e. `Server.currentWave == 0`), ne pas armer
de compte à rebours :

```lua
if nextWave == 1 then
    Server.phaseEndsAt = 0                 -- pas de timer : vague 1 manuelle
    Server.phaseDurationSeconds = 0
else
    Server.phaseEndsAt = getNowSeconds() + prepDurationSeconds
    Server.phaseDurationSeconds = prepDurationSeconds
end
```

`prepDurationSeconds` reste calculé par `getPrepDurationSeconds(nextWave)`
(valeur inchangée), simplement non appliqué à la vague 1.

### 2. `updatePhaseState` (serveur) — pas d'auto-start pour la vague 1

Le gate d'auto-start actuel :

```lua
if Server.phase == "prep" and remaining <= 0 then
    startWave(false)
    return
end
```

Devient (n'auto-start que si ce n'est pas la vague 1) :

```lua
if Server.phase == "prep" and remaining <= 0 and Server.currentWave > 0 then
    startWave(false)
    return
end
```

Avec `phaseEndsAt = 0` pour la vague 1, `remaining` vaut déjà 0 mais le gate
`currentWave > 0` bloque l'auto-start. Le `phaseEndsAt > 0` existant dans le
gate du 1-min warning empêche déjà l'alerte pour la vague 1.

### 3. `skipToNextWave` (serveur) — gate « joueur vivant »

`LastHomeWaves.skipToNextWave(player)` garde son gate `phase == "prep"` et
ajoute un **gate joueur vivant** (les spectateurs/morts ne peuvent pas
déclencher) :

```lua
function LastHomeWaves.skipToNextWave(player)
    if Server.gameOver or not Server.started or Server.phase ~= "prep" then
        return false
    end
    if player ~= nil and not isPlayerAlive(player) then
        return false
    end
    ...
    return startWave(false)
end
```

`isPlayerAlive` est déjà défini localement dans `LastHomeWaves.lua`. Ce gate
s'applique aussi aux skips des preps suivantes (cohérent : un spectateur ne
devrait pas pouvoir skip une vague). L'hôte a validé « n'importe quel vivant ».

### 4. HUD client — prompt vague 1 au lieu du compte à rebours

Dans `media/lua/client/LastHomeClient.lua` (`drawWaveHud`), la branche
`phase == "prep"` affiche le compte à rebours. Pour la vague 1 (prep sans
timer), afficher un prompt de déclenchement :

```lua
elseif state.phase == "prep" then
    local isWave1Prep = (state.currentWave or 0) == 0
    if isWave1Prep and (state.phaseEndsAt or 0) <= 0 then
        -- vague 1 : attente du déclenchement manuel
        drawLine(x, y, "Appuyez sur K pour lancer la vague 1", colorWarning)
    else
        -- prep normale : compte à rebours existant
        ... (comportement actuel)
    end
end
```

L'état client (`waveState`) transporte déjà `currentWave` et `phaseEndsAt`
(`syncWaveState`). Aucune nouvelle donnée à synchroniser.

### 5. Solo

En solo, `requestSkipToNextWave` appelle déjà `LastHomeWaves.skipToNextWave`
directement → fonctionne pour la vague 1. Le gate vivant passe (le joueur solo
est vivant tant qu'il n'est pas mort → s'il est mort, il est spectateur et ne
peut plus déclencher, ce qui est cohérent).

## Fichiers impactés

- `media/lua/server/LastHomeWaves.lua` — `startPrepPhase` (pas de timer vague 1),
  `updatePhaseState` (gate `currentWave > 0`), `skipToNextWave` (gate vivant)
- `media/lua/client/LastHomeClient.lua` — `drawWaveHud` (prompt vague 1)
- `README.md` + `project-state.md` — référence LH-24
- `specs/LH-24-declenchement-manuel-vague-1.md` (cette spec)

## Critères d'acceptation

1. Au lancement d'une partie, la phase prep de la vague 1 **n'affiche pas de
   compte à rebours** (HUD : « Appuyez sur K pour lancer la vague 1 »).
2. La vague 1 **ne démarre pas automatiquement** même après un long moment.
3. Quand un **joueur vivant** appuie sur `K`, la vague 1 démarre immédiatement
   (même comportement que le skip existant : `startWave(false)`).
4. Un **joueur mort/spectateur** qui appuie sur `K` pendant la prep vague 1 ne
   déclenche rien (gate vivant).
5. Une fois la vague 1 lancée, sa **durée est 5 min** (inchangé).
6. À la fin de la vague 1, la **prep vague 2 démarre avec un compte à rebours
   de 5 min et un auto-start** (inchangé).
7. Le skip `K` sur les preps suivantes fonctionne toujours (joueur vivant
   uniquement via le nouveau gate).
8. Le 1-min warning ne se déclenche pas pendant la prep vague 1 (pas de timer).
9. En solo et en MP, le déclenchement fonctionne (solo : appel local ;
   MP : `SkipToNextWave` → serveur).

## Questions en attente

- Le prompt HUD exact (« Appuyez sur K pour lancer la vague 1 ») : valider
  la formulation en jeu.

## Décisions

- Touche `K` existante (pas de nouveau bouton).
- N'importe quel joueur vivant.
- **Pas de fallback** (vague 1 peut rester indéfiniment en attente — y compris si
  tous les joueurs sont morts pendant la prep vague 1 ; choix assumé par l'hôte,
  pas de game-over automatique dans ce cas).

## Dépendances

- LH-10 (timers prep/vague, skip `K`, debounce client)
- LH-03 (cycle de phase `prep`/`wave`, `startWave`, `updatePhaseState`)

## Taille estimée

Small (S) — 3 edits serveur (un gate de phase, un gate vivant, un no-timer
vague 1) + 1 edit HUD client. Aucune nouvelle state serveur, aucune nouvelle
commande réseau. Risque principal : s'assurer que le HUD vague 1 n'affiche
pas un compte à rebours à 0:00 figé.