# LH-10 (S) - Last Home: Timers de vagues ajustables + bouton skip

## Contexte

Les timers actuels sont de 10 min pour la préparation et 10 min par vague. C'est
trop long, surtout pour la première vague. L'utilisateur veut :
1. Première préparation réduite à 2 min
2. Vagues suivantes toutes les 5 min (prep + vague)
3. Un bouton dans l'HUD pour lancer la prochaine vague manuellement

## Changements

### 1. Timers ajustés

| Phase | Durée actuelle | Nouvelle durée |
|-------|----------------|----------------|
| Prep vague 1 | 10 min | 2 min |
| Vague 1 | 10 min | 5 min |
| Prep vague 2+ | 10 min | 5 min |
| Vague 2+ | 10 min | 5 min |

### 2. Bouton "Lancer la vague" dans l'HUD

Pendant les phases de préparation, un bouton s'affiche dans le HUD permettant
de lancer immédiatement la vague suivante sans attendre la fin du timer.

Comportement :
- Le bouton n'apparaît qu'en phase "prep"
- Clic sur le bouton → envoie une commande client → serveur lance la vague
- Le timer restant est annulé
- Le bouton disparaît pendant les vagues (phase "wave")
- En solo : appelle directement `LastHomeWaves` pour lancer la vague
- En multijoueur : envoie `sendClientCommand("LastHome", "SkipToNextWave", {})`
  → le serveur valide et lance la vague

### 3. Implémentation du bouton

PZ ne propose pas de boutons UI dans `OnPostUIDraw` (c'est du texte uniquement).
Solutions :
- **Option A** : Utiliser `ISTickBox` ou `ISButton` via un overlay ISUI
  (panel persistant attaché au HUD)
- **Option B** : Utiliser une touche clavier (ex: touche "N") pour skip la vague,
  avec un message HUD "[N] Lancer la vague" pendant la prep

## Fichiers impactés

- `media/lua/server/LastHomeWaves.lua`
  - Modifier `PREP_DURATION_SECONDS` : 10*60 → dynamique (2*60 pour vague 1,
    5*60 pour les suivantes)
  - Modifier `WAVE_DURATION_SECONDS` : 10*60 → 5*60
  - Ajouter handler `SkipToNextWave` dans `onClientCommand`
  - Ajouter fonction `LastHomeWaves.skipToNextWave()` qui déclenche `startWave(true)`

- `media/lua/client/LastHomeClient.lua`
  - Ajouter l'affichage du bouton/touche dans le HUD pendant la phase "prep"
  - Ajouter le handler pour la touche ou le bouton
  - En solo : appeler `LastHomeWaves.skipToNextWave()` directement

## Critères d'acceptation

1. La première prep dure 2 minutes (120 secondes)
2. Les vagues et prep suivantes durent 5 minutes (300 secondes)
3. Un bouton ou touche permet de lancer la vague suivante pendant la prep
4. Le bouton/touche n'est visible/actif qu'en phase "prep"
5. En solo, le skip lance immédiatement la vague
6. En multijoueur, le skip est validé par le serveur
7. Le timer est annulé quand le skip est utilisé

## Questions en attente

Toutes validées :
1. Touche clavier (option B) — validé
2. Touche "N" — validé
3. N'importe quel joueur peut skip — validé
4. Message HUD "[N] Lancer la prochaine vague" affiché pendant la prep

## Dependencies

- Dépend de LH-03 (système de vagues, timers, phases)
- Dépend de LH-06 (HUD client)
- Utilise `Events.OnPostUIDraw` et potentiellement `Events.OnKeyPressed` (API PZ B41)

## Taille estimée

Small (S) — ajustement de constantes + ajout d'un handler de commande + affichage
HUD conditionnel + handler touche/clavier.