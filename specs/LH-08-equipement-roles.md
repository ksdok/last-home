# LH-08 (S) - Last Home: Rééquilibrage équipement des rôles

## Contexte

L'équipement actuel des rôles pose deux problèmes :
1. Plusieurs rôles ont une arme secondaire équipée en main gauche (ex : Invincible
   avec M4 + Katana). L'utilisateur veut une seule arme secondaire dédiée : la
   seconde arme doit être stockée dans le sac.
2. Le poids porté au spawn est souvent trop élevé. Le joueur doit trier
   immédiatement son inventaire avant de jouer.

## Changements

### 1. Arme secondaire → dans le sac

Pour chaque rôle ayant une seconde arme/outil dans `equipped.secondary`, cet item est :
- retiré de `equipped.secondary`
- déplacé dans `bagContents`

Rôles concernés :
- soldat : HuntingKnife
- voleur : Screwdriver
- local_ : Screwdriver
- rambo : Machete
- sniper : HuntingKnife
- samourai : Machete
- invincible : Katana

Les items restent disponibles dans le sac et peuvent être récupérés manuellement.

### 2. Réduction du poids porté au spawn

Objectif : réduire le poids porté hors sac en déplaçant un maximum d'items non essentiels
vers `bagContents`.

Principes :
- privilégier le stockage dans le sac plutôt que dans l'inventaire principal
- conserver le total d'items du rôle autant que possible
- ne pas considérer ce ticket comme un buff d'équipement : on change surtout la
  répartition inventaire/sac
- le Builder, le Demolisseur et l'Invincible gardent leur équipement complet

Pour les rôles à capacité spéciale :
- **Builder** : conserve tout son équipement + `unlimitedCarry`
- **Demolisseur** : reçoit `unlimitedCarry`
- **Invincible** : reçoit `unlimitedCarry`
- pour ces 3 rôles, relever aussi la capacité de transport pour éviter le moodle
  visuel "Charge Lourde"

### 3. Armes à deux mains équipées à deux mains

Les armes à deux mains doivent être tenues en main principale ET en main secondaire
au runtime.

Implémentation retenue :
- `ROLE_DEFS` ne duplique pas `equipped.secondary = equipped.primary`
- au moment de l'équipement, le code vérifie `InventoryItem:isTwoHandWeapon()`
- si l'arme primaire est réellement à 2 mains, le même item est équipé en main
  principale et secondaire automatiquement
- si l'arme est à 1 main, `equipped.secondary` reste `nil`

Conséquence : la source de vérité est l'API du jeu, pas une liste manuelle figée
par rôle.

### 4. Chargeurs chargés et armes à feu prêtes à tirer

Les armes à feu et leurs chargeurs doivent être donnés déjà chargés au moment de
l'équipement du rôle.

Rôles avec armes à feu :
- soldat : Base.Pistol + Base.9mmClip
- sniper : Base.HuntingRifle + Base.308Clip
- survivaliste : Base.HuntingRifle (munitions internes)
- invincible : Base.AssaultRifle + Base.556Clip

Implémentation : après ajout à l'inventaire, utiliser l'API PZ B41 pour :
- remplir les chargeurs via `setCurrentAmmoCount()`
- marquer le chargeur inséré via `setContainsClip(true)` si applicable
- chambrer une balle via `setRoundChambered(true)`
- nettoyer l'état de douille via `setSpentRoundChambered(false)`

### 5. Suppression du moodle "Charge Lourde"

Le Builder a `setUnlimitedCarry(true)` mais peut quand-même afficher le moodle
visuel "Charge Lourde" si le seuil de port n'est pas relevé.

Solutions retenues :
- `setUnlimitedCarry(true)` pour Builder / Demolisseur / Invincible
- `setMaxWeightBase(...)` et `setMaxWeight(...)` relevés pour ces rôles
- `setMaxWeightDelta(0)` pour éviter un malus résiduel

## Fichiers impactés

- `media/lua/shared/LastHomeRoles.lua` — déplacer les secondary vers bagContents,
  ajuster la répartition inventaire/sac sans augmenter le total d'items
- `media/lua/shared/LastHomeShared.lua` — helpers partagés d'équipement,
  munitions, armes à 2 mains et profil de charge
- `media/lua/server/LastHomeServer.lua` — branchement serveur sur les helpers partagés
- `media/lua/client/LastHomeClient.lua` — branchement client / fallback solo sur les helpers partagés

## Critères d'acceptation

1. Aucun rôle n'a d'arme secondaire dédiée dans `equipped.secondary`
2. Les anciennes armes secondaires sont dans le sac (`bagContents`) des rôles concernés
3. Le poids porté hors sac est réduit autant que possible via la répartition inventaire/sac
4. Les armes réellement à 2 mains sont équipées à deux mains via `isTwoHandWeapon()`
5. Les armes à feu sont chargées par défaut (chargeur plein + arme prête à tirer)
6. Le Builder ne déclenche pas le moodle "Charge Lourde"
7. Le Demolisseur a `unlimitedCarry` et ne déclenche pas le moodle "Charge Lourde"
8. L'Invincible a `unlimitedCarry` et ne déclenche pas le moodle "Charge Lourde"
9. Le Builder conserve tout son équipement
10. Les autres mécaniques (skills, stats, refill) ne changent pas

## Questions en attente

1. La vérification finale en jeu reste nécessaire pour confirmer le moodle
   "Charge Lourde" sur Builder / Demolisseur / Invincible.
2. Si un rôle reste trop chargé malgré la répartition inventaire/sac, un second
   passage d'équilibrage chiffré pourra être ouvert.

## Dependencies

- Dépend de LH-02 (système de rôles, LastHomeRoles.lua)
- Utilise l'API PZ B41 pour l'équipement, les munitions et la capacité de transport

## Taille estimée

Small (S) — répartition inventaire/sac dans `ROLE_DEFS`, helpers partagés pour
équipement/munitions/charge, et fix du profil de charge.
