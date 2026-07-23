# LH-08 (S) - Last Home: Rééquilibrage équipement des rôles

## Contexte

L'équipement actuel des rôles pose deux problèmes :
1. Plusieurs rôles ont une arme secondaire équipée en main gauche (ex: Invincible
   avec M4 + Katana). L'utilisateur veut une seule arme en main principale.
2. Le poids total des items dépasse souvent 19 unités, forçant le joueur à trier
   et ranger dans le sac dès le spawn.

## Changements

### 1. Arme secondaire → dans le sac

Pour chaque rôle ayant `equipped.secondary`, l'arme secondaire est :
- Retirée de `equipped.secondary` (plus équipée en main gauche)
- Déplacée dans `bagContents` (stockée dans le sac)

Rôles concernés :
- soldat : secondary = HuntingKnife → bagContents
- voleur : secondary = Screwdriver → bagContents
- local_ : secondary = Screwdriver → bagContents
- rambo : secondary = Machete → bagContents
- sniper : secondary = HuntingKnife → bagContents
- samourai : secondary = Machete → bagContents
- invincible : secondary = Katana → bagContents

Les items restent disponibles dans le sac, le joueur peut les récupérer manuellement.

### 2. Poids ≤ 19 par rôle (hors sac et contenu du sac)

Le poids des items (hors sac équipé et hors contenu du sac) doit être ≤ 19 unités
pour chaque rôle. Ajustement au cas par cas :

- Calculer le poids PZ réel de chaque item pour chaque rôle
- Réduire les quantités (munitions, consommables, matériaux) pour rester sous 19
- Le sac équipé et son contenu ne comptent pas dans la limite
- Les items équipés (arme primaire, sac, vêtements) ne pèsent pas sur l'inventaire

- **Builder** : conserve tout son équipement (unlimitedCarry), mais ne doit pas
  déclencher le moodle "Charge Lourde". Si le poids dépasse le seuil du moodle
  malgré `setUnlimitedCarry(true)`, appliquer un reset du poids ou un autre
  mécanisme pour supprimer le moodle.
- **Demolisseur** : `setUnlimitedCarry(true)` + suppression du moodle
  "Charge Lourde" (même traitement que le Builder).
- **Invincible** : `setUnlimitedCarry(true)` + suppression du moodle
  "Charge Lourde" (même traitement que le Builder).

### 3. Armes à deux mains équipées à deux mains

Les armes à deux mains (fusils, haches à deux mains, masse, katana, etc.) doivent
être équipées en main principale ET main secondaire via `equipped.secondary`
avec le même item. Cela force le personnage à tenir l'arme à deux mains.

Rôles concernés (armes à deux mains identifiées) :
- soldat : Pistol (1 main) — non concerné
- sniper : HuntingRifle → primary = HuntingRifle, secondary = HuntingRifle
- survivaliste : HuntingRifle → primary = HuntingRifle, secondary = HuntingRifle
- invincible : AssaultRifle → primary = AssaultRifle, secondary = AssaultRifle
- rambo : Axe → primary = Axe, secondary = Axe
- pompier : Axe → primary = Axe, secondary = Axe
- samourai : Katana → primary = Katana, secondary = Katana
- demolisseur : Sledgehammer → primary = Sledgehammer, secondary = Sledgehammer
- builder : Crowbar → primary = Crowbar, secondary = Crowbar (si 2 mains)

Pour les rôles avec arme à 1 main (Pistol, Crowbar, Machete, Hammer, etc.) :
- `equipped.secondary` reste nil (une seule main)

Note : il faut vérifier quelles armes sont réellement à 2 mains dans PZ B41
(isTwoHandWeapon ou équivalent). L'implémentation vérifiera l'API.

### 5. Chargeurs chargés et armes à feu chargées par défaut

Les armes à feu et leurs chargeurs doivent être donnés déjà chargés au moment
de l'équipement du rôle. Concrètement :

- Les chargeurs (clips) donnés au joueur doivent être pleins
- L'arme à feu équipée en main doit avoir un chargeur inséré et être chargée
  (un coup dans la chambre si applicable)

Rôles avec armes à feu :
- soldat : Base.Pistol + Base.9mmClip
- sniper : Base.HuntingRifle + Base.308Clip
- survivaliste : Base.HuntingRifle (pas de clip séparé, munitions internes)
- invincible : Base.AssaultRifle + Base.556Clip

Implémentation : après avoir ajouté l'arme et les chargeurs dans l'inventaire,
utiliser l'API PZ B41 pour remplir les chargeurs (`clip:setContains()`) et charger
l'arme (`weapon:setContainItem()` ou équivalent selon l'API disponible).

### 6. Builder : suppression du moodle "Charge Lourde"

Le Builder a `setUnlimitedCarry(true)` mais peut quand-même déclencher le moodle
visuel "Charge Lourde" si le poids des items dépasse le seuil. Solutions possibles :
- Reset du poids de l'inventaire après application du rôle (si API disponible)
- Forcer la capacité de transport via `getInventory():setMaxWeight()` ou équivalent
- À déterminer pendant l'implémentation selon l'API PZ B41 disponible

## Fichiers impactés

- `media/lua/shared/LastHomeRoles.lua` — déplacer les secondary vers bagContents,
  ajuster les quantités d'items
- `media/lua/server/LastHomeServer.lua` — si besoin pour le moodle Builder
- `media/lua/client/LastHomeClient.lua` — si besoin pour le moodle Builder (solo)

## Critères d'acceptation

1. Aucun rôle n'a `equipped.secondary` (une seule arme en main principale)
2. Les armes secondaires sont dans le sac (bagContents) de chaque rôle concerné
3. Le poids des items (hors sac + contenu sac) est ≤ 19 unités pour chaque rôle
7. Les armes à feu sont chargées par défaut (chargeur plein + arme prête à tirer)
8. Le Builder ne déclenche pas le moodle "Charge Lourde"
9. Le Demolisseur a `unlimitedCarry` et ne déclenche pas le moodle "Charge Lourde"
10. L'Invincible a `unlimitedCarry` et ne déclenche pas le moodle "Charge Lourde"
11. Le Builder conserve tout son équipement et unlimitedCarry
12. Les autres mécaniques (skills, stats, refill) ne changent pas

## Questions en attente

1. Les poids exacts des items PZ seront calculés pendant l'implémentation.
   Si un rôle ne peut pas descendre sous 19 sans supprimer des items essentiels,
   l'utilisateur sera consulté.

## Dependencies

- Dépend de LH-02 (système de rôles, LastHomeRoles.lua)
- Utilise l'API PZ B41 pour le poids des items et le moodle

## Taille estimée

Small (S) — ajustement de quantités dans ROLE_DEFS + déplacement de champs
secondary vers bagContents + fix moodle Builder.