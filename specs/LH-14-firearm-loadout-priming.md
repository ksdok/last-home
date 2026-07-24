# LH-14 (S) - Last Home: Amorçage des armes à feu à l'attribution du rôle

## Contexte

A l'attribution d'un rôle, `LastHomeShared.primeRoleLoadout(inv)` parcourt
l'inventaire et appelle `fillAmmoItem(item)` pour pré-charger les armes à feu et
les chargeurs spare.

Bug remonté en jeu : le rôle **Invincible** démarre avec son `AssaultRifle` non
chargé (0 balle, pas de cartouche chambrée), alors qu'il dispose de
`Base.556Clip` et `Base.556Bullets`.

## Root cause

`fillAmmoItem` (LastHomeShared.lua) teste en priorité `item.getClipSize` :

```lua
if item.getClipSize ~= nil and item.setCurrentAmmoCount ~= nil then
    local clipSize = item:getClipSize()
    if clipSize ~= nil and clipSize > 0 then
        item:setCurrentAmmoCount(clipSize)
    end
elseif item.getMaxAmmo ~= nil and item.setCurrentAmmoCount ~= nil then
    ...
end
```

Sur un `HandWeapon`, la méthode `getClipSize()` existe toujours, mais elle ne
renvoie une valeur > 0 que si le script de l'arme définit `ClipSize`. Or :

| Arme | `ClipSize` | `MaxAmmo` | `MagazineType` | Comportement actuel |
|------|-----------|----------|-----------------|----------------------|
| `AssaultRifle` | non | 30 | `Base.556Clip` | `getClipSize()` = 0 → `setCurrentAmmoCount` sauté, `elseif getMaxAmmo` bloqué → **0 balle** |
| `HuntingRifle` | non | 3 | `Base.308Clip` | idem → **0 balle** |
| `Shotgun` | non | 6 | (aucun) | idem → **0 balle** |
| `Pistol` | 15 | 15 | (aucun) | `getClipSize()` = 15 → **OK** |

Le `if/elseif` est en défaut : quand la méthode `getClipSize` existe mais
renvoie 0, le premier `if` matche (sans rien faire) et le `elseif getMaxAmmo`
n'est jamais évalué.

Modèle PZ (cf. `ISInsertMagazine:loadAmmo`) : pour une arme magazine-fed, le
gun stocke `currentAmmoCount` directement (le chargeur est consommé à
l'insertion). Il faut donc `setCurrentAmmoCount(maxAmmo)` + `setContainsClip(true)`
+ `setRoundChambered(true)`.

## Objectif

Toutes les armes à feu des rôles démarrent chargées (cartouche chambrée incluse)
et tous les chargeurs spare sont remplis, quel que soit le modèle de rechargement
PZ (magazine-fed, clip interne, ou bullet-by-bullet).

## Changements

### `media/lua/shared/LastHomeShared.lua` — `fillAmmoItem`

Restructurer la détection de la capacité pour ne plus bloquer sur
`getClipSize() == 0` :

1. Détecter une arme **magazine-fed** via `getMagazineType()` non vide.
2. Calculer la capacité :
   - magazine-fed → `getMaxAmmo()`
   - sinon `getClipSize()` si > 0
   - sinon `getMaxAmmo()` (bullet-by-bullet / chargeur spare)
3. `setCurrentAmmoCount(capacity)` si > 0.
4. `setContainsClip(true)` seulement si magazine-fed.
5. Chambrer une cartouche en décrémentant `currentAmmoCount` de `ammoPerShoot`
   (comme le rack moteur `ISRackFirearm`), pour ne pas démarrer à capacity+1
   coups. `setRoundChambered(true)` seulement si `currentAmmoCount > 0`.
6. `setSpentRoundChambered(false)`.

Ordre conservé identique au moteur : ammo → containsClip → chambered.

## Critères d'acceptation

1. Invincible démarre avec l'AssaultRifle chargé (29 balles en magasin + 1 cartouche chambrée = 30 coups).
2. Sniper / Survivaliste démarrent avec le HuntingRifle chargé (2 en magasin + 1 chambrée = 3 coups).
3. Soldat démarre toujours avec le Pistol chargé (14 + 1 chambrée = 15 coups) — non régression.
4. Les chargeurs spare (`556Clip`, `308Clip`, etc.) sont remplis à `MaxAmmo` (plein, sans cartouche chambrée).
5. Les armes de mêlée et objets non-armes ne sont pas affectés.
6. Aucune arme ne démarre à capacity+1 coups.

## Fichiers impactés

- `media/lua/shared/LastHomeShared.lua` — `fillAmmoItem`
- `specs/LH-14-firearm-loadout-priming.md` — nouvelle spec
- `README.md` — table des specs
- `project-state.md` — ticket et entrée d'implémentation
- `mod.info` — bump version

## Dépendances

- Dépend de LH-08 (`primeRoleLoadout`, `fillAmmoItem`, `equipRoleItems`)

## Taille estimée

Small (S) — correction localisée d'un helper shared utilisé côté serveur et
client.