# Status Report: Wave zombies don't attack the player (Project Zomboid B41, Last Home mod)

## 1. Context

- I'm developing a **Last Home** mod for Project Zomboid **Build 41** (Steam Mac version, ~41.78).
- Game mode: **Custom Challenge** (Challenges menu). The selected challenge forces a "house" (here **Villa**) and starts a zombie wave system.
- Goal: wave zombies must **move toward the base (villa) and attack the players**.
- Symptom: regardless of the approach tried, **spawned zombies never attack the player**. They can approach (pathing) but remain passive / go idle, never entering `AttackState`.

## 2. Environment / Configuration

### Wave zombie spawning
- Zombies are created via the global Lua function:
  ```lua
  addZombiesInOutfit(x, y, z, count, nil, 0)
  ```
  (x,y,z = spawn points calculated around the house center, `count` zombies, `outfit=nil`, `range=0`.)
- Spawn at **20 tiles** south of the villa center (also tested at 30). Actual observed coordinates: spawn around `(13524..13541, 2872, 0)`, villa rect `x=13524..13545, y=2830..2858`.
- Each spawned zombie is tagged via `zombie:getModData()`:
  ```lua
  modData.LH_waveZombie = true
  modData.LH_waveNumber = wave
  modData.LH_countedDead = false
  zombie:setCanWalk(true)
  ```

### Challenge sandbox vars (applied via `LastHomeVilla.setSandBoxVars`)
```lua
SandboxVars.Zombies = 6          -- 6 = "None" (disables ambient vanilla pop)
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
- ⚠️ **Unexplored track**: `SandboxVars.Zombies = 6` ("None") disables ambient population, but **could it also disable attack globally** for all zombies (including manually spawned ones)? To be checked.
- `ZombieLore` (Strength/Speed/Cognition/Memory/Hearing/Sight) is **not** modified → vanilla defaults (normal).

### Player confinement
- The player is **confined within a rectangle** around the villa (`boundary`), taking damage if they leave (10s countdown then 5 hp/tick). So the player can't easily go toward the zombies.

## 3. Precise Symptom (observed in-game + logs)

Regardless of the forced aggro mechanism tried:
- Zombies can **move** toward the player (pathing OK via `addSound` investigation or `pathToCharacter`).
- But they **never transition to `AttackState`** → never attack.
- Same observation in **pure vanilla** (no forcing, 20-tile spawn): the player approaches zombies → they don't attack.

## 4. Chronology of Approaches Tried and Results

Tests done in real games, with diagnostic logs reading `getTarget()`, `getCurrentState()`, `isAttacking()`, `isZombiesDontAttack()`, `isFakeDead()`, `isCanWalk()`, `isTargetVisible()` on zombies.

| # | Approach | Observed Result |
|---|----------|-----------------|
| 1 | `addSound(player, x, y, z, radius, vol)` at **fixed center** of base (z=0) | Zombies converge to ground floor, don't see player (z=1 upstairs) → no aggro. Regression identified. |
| 2 | `addSound` at **player's actual position** (x,y,z) | Zombies path to player but stay in investigation, **no aggro**. |
| 3 | `zombie:spotted(player, true)` by pulse (every 3s) | `spotted` executes without error (`fail=0`), but `getTarget() → none` → **does not set target**. No aggro. |
| 4 | `zombie:addAggro(player, 100)` by pulse | Executes without error but **effectively a no-op**: `getTarget() → none` even at `minDist=0` (zombie on player's tile). No aggro. |
| 5 | `zombie:setTarget(player)` by pulse | ✅ **Sets target**: `getTarget() → player:X`, `isTargetVisible() → true`. **But** `getCurrentState()` stays `WalkTowardState` / `ZombieIdleState` / `PathFindState2` / `ClimbOverFenceState` — **never `AttackState`**. `isAttacking() → false` even at `minDist=0` (zombie on player's tile). |
| 6 | `setTarget` + stop pulse on arrival (≤6 tiles) | Same: target set, `targetVis=true`, but no transition to `AttackState`. |
| 7 | At **spawn** only: `setTarget(nearest player)` + `spotted(player, true)`, **no `pathToCharacter`**, no pulse | Player reports zombies **don't attack** even when approaching. |
| 8 | **Pure vanilla**: no forcing, 20-tile spawn | Zombies don't attack, even when the player approaches within ~2 tiles. |

## 5. Verified API Facts (IsoZombie B41 — official javadocs + in-game tests)

Sources: `projectzomboid.com/modding/zombie/characters/IsoZombie.html`, `zomboid-javadoc.com/41.78`, `.class` parsing of `zombie/characters/IsoZombie.class`.

Relevant methods and **observed** behavior:
- `setTarget(IsoMovingObject)` → sets the public `target` field. **Confirmed working** (`getTarget()` returns the player afterward).
- `spotted(IsoMovingObject, boolean bForced)` → executes without error but **does not set `target`** by itself.
- `addAggro(IsoMovingObject, float)` → **effectively a no-op** in our context (`getTarget()` remains `none`).
- `pathToCharacter(IsoGameCharacter)` → forces pathing, puts zombie in `PathFindState`/`WalkTowardState`. **Suspected of blocking the transition to `AttackState`** (state machine kept in "walk toward" mode).
- `AttemptAttack()` → `boolean`, forces an attack swing. **Not tested**.
- `getTarget()`, `getCurrentState()`, `isAttacking()`, `isZombiesDontAttack()`, `isFakeDead()`, `isCanWalk()`, `isTargetVisible()` → all exposed to Lua.

Public fields: `target`, `LastTargetSeenX/Y/Z`, `alerted`, `AttackAnimTime`.

AI Brain `GameCharacterAIBrain` (public fields): `spottedCharacters` (ArrayList<IsoGameCharacter>), `aiTarget` (IsoMovingObject) — **separate** from the IsoZombie's `target` field.

⚠️ **The vanilla engine provides no Lua pattern**: all aggro/perception logic is in Java; no vanilla function calls `setTarget`/`spotted`/`addAggro` from Lua. No canonical example to copy.

## 6. The Central Mystery

> Even with successful `setTarget(player)` (`getTarget()=player`, `isTargetVisible()=true`), a zombie **on the player's exact tile** (`minDist=0`, same z) stays in `WalkTowardState`/`ZombieIdleState` and **never attacks**. `isZombiesDontAttack()=false`, `isFakeDead()=false`, `isCanWalk()=true`.

The state machine does not transition to `AttackState` despite a valid and visible target at point-blank range. Something prevents the attack transition — it's not the `target` (it's set), nor the `dontAttack`/`fakeDead` flags.

## 7. Remaining Hypotheses / Unexplored Tracks

1. **Does `SandboxVars.Zombies = 6` ("None") disable attack globally** (not just ambient pop)? If so, all zombies — even manually spawned — couldn't attack. → **Strong track to verify first** (test with `SandboxVars.Zombies = 4` "Normal" + population at 0 via ZombieConfig).
2. **Zombies spawned via `addZombiesInOutfit` = "non-real" zombies?** They might have a flag (`bRemote`, `authOwner`, `bIndoorZombie`...) that prevents attacking, or their AI isn't ticked properly server-side. Check if spawning via normal population (instead of `addZombiesInOutfit`) attacks.
3. **The `GameCharacterAIBrain` brain needs to be fed** (`spottedCharacters`, `aiTarget`) rather than just `zombie.target`. `setTarget` alone may not be enough; may need to add the player to `zombie:getBrain().spottedCharacters` + set `aiTarget`. Brain access API to confirm (`getBrain()`?).
4. **`AttemptAttack()` forced at range**: call `zombie:AttemptAttack()` when `minDist <= ~2` to force the swing, bypassing the state machine.
5. **Sight/Hearing perception**: in pure vanilla, zombies only attack if they perceive the player (sight/sound). A silent player in a closed villa at 20 tiles is not perceived. → Confinement + pure vanilla are incompatible: either a minimal `addSound` at spawn (investigation toward base), or lift the confinement.

## 8. Current Code State

`media/lua/server/LastHomeWaves.lua`:
- `SPAWN_DISTANCE = 20`.
- Pure vanilla spawn: `addZombiesInOutfit` + modData tag (`LH_waveZombie`...) + `setCanWalk(true)`.
- **No** calls to `setTarget`/`spotted`/`addAggro`/`pathToCharacter`/`addSound`. No pulse.
- `onZombieDead` decrements the counter and triggers the next wave when `zombieCount <= 0`.
- The wave/prep/skip/HUD/confinement cycle works.

## 9. Questions for the Consulted LLM

1. Does `SandboxVars.Zombies = 6` ("None") **disable zombie attack globally**, including for manually spawned zombies via `addZombiesInOutfit`? If so, how to disable ambient pop WITHOUT disabling attack?
2. Why does a zombie with `setTarget(player)` + `isTargetVisible()=true` + on the player's tile **never** transition to `AttackState`? What is the exact `WalkTowardState → AttackState` transition condition on the Java side?
3. What is the **reliable method** (Lua, B41) to force a zombie to attack a given player? `setTarget` alone is not enough. Do we need to manipulate `GameCharacterAIBrain.spottedCharacters`/`aiTarget`? Call `AttemptAttack()`?
4. Are `addZombiesInOutfit` zombies "active" (AI ticked) server-side in solo, or do we need a different spawn (e.g. normal population) for them to attack?
5. Is there a known mod pattern (B41) that makes zombies attack a specific player (directed horde)?

---

## One-Sentence Summary

Zombies spawned via `addZombiesInOutfit` in a challenge that sets `SandboxVars.Zombies = 6` ("None") never attack the player, even with `setTarget` + `isTargetVisible()=true` at point-blank range; `addAggro`/`spotted` are no-ops; `pathToCharacter` blocks `AttackState`; and even in pure vanilla they don't attack — we need to determine whether the "None" sandbox setting disables attack, a problem with manually spawned zombies, or an unfed brain mechanism.
