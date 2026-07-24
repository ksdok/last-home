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

Reproduire le pattern officiel du moteur `HandWeapon:randomizeBullets()` (qui
pré-charge les armes au spawn des world weapons / zombies) :

1. Garde `item:isRanged()` pour ne traiter que les armes à feu.
2. `setCurrentAmmoCount(getMaxAmmo())` — le gun stocke le compte directement,
   pas besoin de remplir/insérer un chargeur item.
3. `setContainsClip(true)` si `getMagazineType()` non vide (armes magazine-fed).
4. `setRoundChambered(true)` si `haveChamber()`.
5. `setSpentRoundChambered(false)`.
6. Log debug serveur/client indiquant l'arme, maxAmmo, ammo, containsClip,
   roundChambered, haveChamber pour valider le priming en jeu.

Les chargeurs spare (items non-armes, ex. `Base.556Clip`) sont remplis à
`getMaxAmmo()`.

Note : `randomizeBullets()` ne décrémente pas `currentAmmoCount` au chambrage
au spawn — l'arme démarre donc à `maxAmmo` + 1 cartouche chambrée, ce qui
correspond à la convention du jeu pour les armes pré-chargées (un AssaultRifle
trouvé dans le monde a le même profil). Le décrément s'applique au flux de
reload en jeu (`ISRackFirearm`), pas au pré-chargement au spawn.

## Critères d'acceptation

1. Invincible démarre avec l'AssaultRifle chargé (`currentAmmoCount=30`, `containsClip=true`, `roundChambered=true`), tirable immédiatement.
2. Sniper / Survivaliste démarrent avec le HuntingRifle chargé (`currentAmmoCount=3`, `containsClip=true`, `roundChambered=true`).
3. Soldat démarre toujours avec le Pistol chargé (`currentAmmoCount=15`, `roundChambered=true`) — non régression.
4. Les chargeurs spare (`556Clip`, `308Clip`, etc.) sont remplis à `MaxAmmo`.
5. Les armes de mêlée et objets non-armes ne sont pas affectés.
6. Le log `fillAmmoItem arme=...` confirme les valeurs au spawn.

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