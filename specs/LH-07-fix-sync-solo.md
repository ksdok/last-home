# LH-07 (S) - Last Home: Fix sync solo state via OnTick dedie

## Contexte

En mode solo (Challenge), le client ne recupere jamais l'etat des vagues ni du
confinement depuis le serveur. Cause : `syncSoloState()` est appelee uniquement
dans `drawWaveHud()` (Events.OnPostUIDraw), qui fait un early return quand
`waveState.phase == "idle"`. Comme `waveState` demarre a `"idle"` et n'est mis
a jour que par `syncSoloState()`, on a une boucle circulaire :

  phase=idle → HUD skip → syncSoloState jamais appelé → phase reste idle

Le confinement (LH-05) s'execute bien côté serveur (`updateBoundaryStates` dans
LastHomeWaves.lua) mais les `BoundaryState` ne sont jamais synchronises au client
en solo. Resultat : aucun message hors zone, aucun countdown, aucun degat visible.

## Changement

Extraire `syncSoloState()` de `drawWaveHud()` et l'executer sur un tick dedie
`Events.OnTick` independant du rendu UI.

### Comportement attendu

- `syncSoloState()` s'execute a chaque tick serveur en solo (throttle 1/s deja
  present via `soloStateLastSyncSecond`)
- Le HUD `drawWaveHud()` ne contient plus l'appel a `syncSoloState()`
- Le HUD s'affiche des que `waveState.phase` passe a `"prep"` / `"wave"` / etc.
- Le `boundaryState` est synchronise en temps reel en solo
- Le countdown et les degats s'affichent correctement dans le HUD
- Le multijoueur n'est pas affecte (syncSoloState fait deja un early return si
  `not isSinglePlayerRuntime()`)

### Fichiers impactes

- `media/lua/client/LastHomeClient.lua`

### Modifications detaillees

1. Supprimer l'appel `syncSoloState()` au debut de `drawWaveHud()` (ligne ~510)

2. Ajouter un handler `Events.OnTick` dedie :
   ```lua
   local function onTickSyncSoloState()
       syncSoloState()
   end
   Events.OnTick.Add(onTickSyncSoloState)
   ```

3. `syncSoloState()` contient deja un throttle `soloStateLastSyncSecond` qui
   limite a 1 execution/seconde — aucun changement necessaire

4. Mettre a jour le print final de LastHomeClient pour inclure le nouveau handler

## Critères d'acceptation

1. En solo, le HUD s'affiche des que le serveur entre en phase PREP
2. En solo, le boundaryState est synchronise au client (countdown visible)
3. En solo, les messages "Hors zone" et "De retour dans la zone" s'affichent
4. En solo, les degats de confinement s'appliquent visiblement (perte de sante)
5. En multijoueur, aucun changement de comportement
6. Le throttle de 1/s est conserve (pas de surconsomme CPU)

## Questions en attente

Aucune — l'option B a ete choisie par l'utilisateur.

## Dependencies

- Depended de LH-05 (boundaryState, syncSoloState, updateBoundaryState)
- Depended de LH-06 (drawWaveHud, syncSoloState dans le HUD)
- Utilise Events.OnTick (API vanilla PZ B41)

## Taille estimee

Small (S) — deplacer un appel de fonction d'un handler a un autre, 3 lignes
modifiees.