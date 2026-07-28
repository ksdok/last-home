# LH-20 (S) - Last Home : nettoyer pendant la prep, pas pendant la vague

> **Note historique** : ce comportement LH-20 a ensuite été **revert côté code**.
> Le nettoyage périodique tourne désormais de nouveau **pendant la vague**,
> avec une cadence plus rapide de **1 s** au lieu de 5 s.

## Contexte

LH-13 a ajouté un **nettoyage périodique** serveur des zombies vanilla/story
autour de la base (`clearAmbientZombiesNearHouse`), toutes les
`AMBIENT_CLEANUP_INTERVAL_SECONDS` (5 s), tant que la partie est active et qu'une
maison scénario/challenge est définie. Le but était de retirer les spawns
parasites (`RDS*`, `createEatingZombies`, `RBSafehouse`, etc.) qui réapparaissent
après le cleanup initial.

Le gate actuel dans `LastHomeWaves.onTick` est :

```lua
if Server.started and not Server.gameOver and isScenarioHouse()
    and Server.nextAmbientCleanupAt ~= nil and now >= Server.nextAmbientCleanupAt then
    clearAmbientZombiesNearHouse("periodic")
    Server.nextAmbientCleanupAt = now + AMBIENT_CLEANUP_INTERVAL_SECONDS
end
```

Il **ne tient pas compte de la phase**. Le nettoyage périodique tourne donc aussi
**pendant la vague**, en plus de la prep. Il préserve bien les zombies taggés
`LH_waveZombie` (vague + spectateurs), mais il supprime quand même tous les
zombies non-taggés (vanilla/story) qui apparaissent pendant la vague.

Comportement attendu par l'hôte :

1. le nettoyage **tourne pendant la prep** (jusqu'au démarrage de la vague) ;
2. **pendant la vague, aucun nettoyage** tant que les zombies de la vague ne
   sont pas morts ;
3. **reprise du nettoyage quand la vague est terminée**.

## Objectif

Confirmer le découpage par phase :

- **Prep** : nettoyage périodique actif (comme aujourd'hui).
- **Vague** : nettoyage périodique **suspendu**. Aucun `clearAmbientZombiesNearHouse`
  n'est déclenché par le tick périodique tant que `Server.phase == "wave"`.
- **Fin de vague** : le nettoyage reprend dès le retour en prep (vague nettoyée)
  via l'appel immédiat `"prep"` existant + réarmement du périodique.

Les cleanups **immédiats aux transitions** (`"prep"` au démarrage de la prep,
`"wave"` au démarrage de la vague) sont conservés tels quels : ils ne sont pas du
nettoyage "pendant la vague", ce sont les one-shots de transition (le `"wave"`
se produit juste avant `spawnWaveZombies`, donc avant que la vague ne soit
réellement active — c'est le "dernier nettoyage avant la vague").

## Changements

### 1. Gater le nettoyage périodique sur la phase

Dans `LastHomeWaves.onTick`, ajouter la condition `Server.phase ~= "wave"` au
gate du nettoyage périodique :

```lua
if Server.started and not Server.gameOver and isScenarioHouse()
    and Server.phase ~= "wave"
    and Server.nextAmbientCleanupAt ~= nil and now >= Server.nextAmbientCleanupAt then
    clearAmbientZombiesNearHouse("periodic")
    Server.nextAmbientCleanupAt = now + AMBIENT_CLEANUP_INTERVAL_SECONDS
end
```

C'est le seul changement fonctionnel. Le nettoyage périodique ne tourne plus
pendant la vague.

### 2. Ne pas réarmer le périodique au démarrage de la vague

Dans `startWave`, le bloc suivant devient inutile pendant la vague (le tick
périodique est désormais gaté sur `phase ~= "wave"`) :

```lua
if isScenarioHouse() then
    Server.nextAmbientCleanupAt = getNowSeconds() + AMBIENT_CLEANUP_INTERVAL_SECONDS
end
```

Le supprimer (ou le laisser : il est inoffensif car le tick ne déclenchera pas
pendant la vague). Décision retenue : **le supprimer** pour garder un état
propre (aucun timer périodique armé pendant la vague). Le `"prep"` de la phase
suivante le réarme de toute façon.

L'appel immédiat `clearAmbientZombiesNearHouse("wave")` dans `startWave` est
**conservé** : c'est le one-shot de transition "dernier nettoyage avant que la
vague ne démarre", pas un nettoyage pendant la vague.

### 3. Cas du carry-over (timer de vague expiré)

Quand le timer de vague expire avec des zombies encore vivants,
`updatePhaseState` appelle `startWave(true)` : la vague suivante démarre
immédiatement avec les zombies restants, la phase reste `"wave"`. Avec le gate
`phase ~= "wave"`, le nettoyage périodique **ne reprend pas** tant que des
zombies de vague sont vivants — ce qui correspond exactement à "pas de
nettoyage tant que les zombies de la vague ne sont pas morts".

Le one-shot `"wave"` de `startWave(true)` s'exécute quand même à cette transition
(clear des non-taggés avant le spawn de la nouvelle vague). C'est acceptable et
cohérent avec "jusqu'à que la vague commence" : c'est le cleanup de transition,
pas un cleanup pendant la vague. Si l'hôte préfère le désactiver sur le
carry-over, voir la question en attente.

### 4. Reprise à la fin de la vague

Quand le dernier zombie de vague meurt (`onZombieDead` → `zombieCount <= 0` →
`endWaveCleared` → `startPrepPhase`) :
- `startPrepPhase` appelle `clearAmbientZombiesNearHouse("prep")` (cleanup
  immédiat de reprise) ;
- puis arme `Server.nextAmbientCleanupAt = now + 5 s` ;
- le tick périodique reprend (phase `"prep"`).

Aucun changement à faire ici : le flux existant réalise déjà la "reprise du
nettoyage quand la vague est terminée".

## Fichiers impactés

- `media/lua/server/LastHomeWaves.lua`
  - `onTick` : ajouter `Server.phase ~= "wave"` au gate du nettoyage périodique
  - `startWave` : supprimer le réarmement de `nextAmbientCleanupAt` (devenu inutile)
- `specs/LH-20-cleanup-pas-pendant-vague.md` (cette spec)

## Critères d'acceptation

1. Pendant la prep, le nettoyage périodique tourne toutes les 5 s (inchangé).
2. Au démarrage de la vague, le one-shot `"wave"` s'exécute (dernier nettoyage
   avant la vague), puis **plus aucun nettoyage périodique** pendant toute la
   durée de la vague.
3. Les zombies `LH_waveZombie` (vague + spectateurs) ne sont jamais supprimés,
   pendant la vague comme pendant la prep (inchangé).
4. Dès que le dernier zombie de vague meurt, le one-shot `"prep"` s'exécute et le
   nettoyage périodique reprend (vague suivante en prep).
5. En cas de carry-over (timer expiré, zombies vivants), le nettoyage périodique
   ne reprend pas tant que la vague n'est pas nettoyée.
6. En game over, le nettoyage périodique reste désactivé (inchangé).
7. Les logs serveur continuent de distinguer `prep`, `wave` et `periodic`.

## Questions en attente

- Faut-il désactiver le one-shot `"wave"` de `startWave(true)` dans le cas
  carry-over (timer expiré) ? Aujourd'hui il s'exécute à chaque démarrage de
  vague, y compris le carry-over. Le garder est inoffensif (il ne retire que
  les non-taggés, les `LH_waveZombie` sont préservés) et donne une zone propre
  au début de chaque vague ; le supprimer respecterait strictement "aucun
  nettoyage pendant la vague" même aux transitions de vague en vague.
  Décision suggérée : **le garder** (comportement actuel), car c'est un cleanup
  de transition, pas un cleanup pendant la vague.

## Décisions

- Le nettoyage périodique est suspendu pendant la vague via un gate de phase
  (`Server.phase ~= "wave"`), pas via un flag séparé : la phase est déjà l'état
  autoritaire du cycle prep/vague.
- Les one-shots de transition `"prep"` et `"wave"` sont conservés (ce ne sont
  pas des nettoyages "pendant la vague").
- Aucun changement au périmètre `isScenarioHouse()` : la suspension s'applique
  à la fois au mode Challenge et au mode Scenario/MP.

## Dépendances

- Dépend de LH-13 (nettoyage périodique `clearAmbientZombiesNearHouse`,
  `AMBIENT_CLEANUP_INTERVAL_SECONDS`, `nextAmbientCleanupAt`, `isScenarioHouse`)
- Dépend de LH-03 (cycle de phase `prep`/`wave`, `Server.phase`, `endWaveCleared`,
  `startWave`, `onZombieDead`)

## Taille estimée

Small (S) — un gate de phase à ajouter dans `onTick`, un réarmement à retirer
dans `startWave`. Aucune nouvelle state serveur, aucun changement au comptage
des zombies de vague.