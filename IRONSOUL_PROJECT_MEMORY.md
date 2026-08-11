# Iron Soul Kaitun - Persistent Project Memory

Last updated: 2026-08-11

## Purpose
This file is the continuity source for future ChatGPT conversations. Read this before changing code. It records what is proven, what failed, current architecture rules, and current open problems.

## User / project priorities
- Fully automatic NEWBIE progression from fresh account onward.
- Prefer headless/internal game paths: remotes/modules/native server state over mouse/GUI interaction.
- Preserve proven logic; do not rewrite working portal/combat/forge behavior casually.
- Low CPU/RAM, suitable for long unattended farming.
- Mobile/Delta support should be capability-based, not executor-name-based.
- Production fixes belong in GitHub. Temporary diagnostics/recon scripts should be given raw in chat and run by the user, not committed.
- Temporary diagnostic scripts should preferably be delivered as downloadable `.txt` files instead of huge pasted chat blocks.
- Every change should be evidence-driven from telemetry/recon where possible.

## Stable place IDs
- Tutorial/starter: 76701861705540
- Lobby: 117533937949084
- Known World1 dungeon used in validated V55.2: 116456628154258
- World2 D1 dungeon currently under investigation: 136216144170036

## Major validated milestones
### V20-V47 lobby/progression discoveries
- Headless pet Hatch+Claim worked; Eagle example validated.
- EquipBest, official power scoring, smart selling, task claiming, skill equip/loadout, attributes, season/lottery, forge, and starter Sword selection were mapped.
- Headless forge path validated: DropOres -> QTE rating 15 -> ForgeFinish -> ForgeResult.
- Starter/newbie weapon preference is Sword; index 1 maps to Single_BroadSword.

### V52-V55 portal/combat
- RoundDoor portal handshake solved headlessly.
- V55.2 completed a full dungeon in PlaceId 116456628154258:
  - SETTLEMENT_REACHED
  - 126.13s
  - 128 targets
  - 5 transitions
  - 0 deaths
  - AttackDriver=HEADLESS_REMOTE
  - MouseBasicUsed=false
  - HeadlessRecoveries=0
- Validated traversal concepts: region-locked combat, exact RoundNum door selection, door-normal crossing, RoundDoor.Portal handshake.

### V58/V59 continuous progression
- V58 one-cycle passed: World1 Diff2 Level 10 / Power 341 -> Lobby Level 11 / Power 355.
- V59 became the continuous modular architecture: Tutorial -> Lobby -> Dungeon -> Lobby.

## Combat knowledge
- Normal mobs are mostly solved and should not be retuned without evidence.
- Reliable elevated combat testing found:
  - 5 studs: works
  - ~9 studs: consistently reliable high position
  - 13/17/21: inconsistent
  - 25: failed
- Current philosophy: safest position that still produces verified enemy HP loss.
- Close damage-recovery position around 5.5 studs is used when server HP stops decreasing.
- Adaptive profiles evolved to DEFAULT / EVADE / EVADE_WIDE / BOSS_ORBIT / LOW_HP_ORBIT / KNOCK_EVADE / HIT_RECOVERY.
- V61.8-era battle logs showed normal mobs around ~1 second per kill; most player damage came from boss/high-HP targets.
- Boss burst-safe positioning was added; do not replace it without new comparative telemetry.
- Infinite/huge aura is not assumed better; server-confirmed damage is the truth signal.

## Transition knowledge
- Directly forcing an unlocked portal remote can skip intended rooms/state. Avoid using remote force merely because it advances.
- Preferred transition pattern: identify exact valid portal/gate, approach quickly, use real/native final movement/touch, verify actual transition evidence.
- Recovery must remain LOCAL. A replicated current-1 portal hundreds/thousands of studs away is not a valid recovery target.
- Raw displacement is not sufficient progression proof.
- World2 proved that valid local RoundDoor portal variants may be named `PortalD`, not only literal `Portal`.
- Current-1 `Portal*` near the player must outrank far replicated copies and generic unknown-objective probing.
- Avoid implementing transition safety as another fragile late multi-hunk patch when a wrapper/pre-load normalization can enforce the policy.

## Forge/inventory knowledge
- Balanced forge is preferred over blindly consuming best ores.
- Reserve premium ores for deliberate upgrade attempts; use lower-quality ores for bulk capacity drain.
- Maintain missing slots first, then targeted Sword/Helmet attempts, then efficient drain.
- A strong observed maintenance cycle was roughly 95/100 ores -> 30/100, 9 crafts, Power 2642 -> 3490 (+848).
- Do not make forge more aggressive without evidence.

## Mobile/executor support
- Capability detection should check teleport queue aliases, firesignal, getconnections, fireproximityprompt, firetouchinterest, and filesystem functions.
- Old lobby code stopped after FPS cap when queue_on_teleport was absent; this looked like 'FPS lowers then nothing'.
- V61.11 moved queue compatibility into bootstrap before lobby loads, instead of patching the lobby's early environment block.
- If no native teleport queue exists, the compatibility shim lets the current lobby cycle continue and clearly marks manual re-execution mode. It does not claim native persistence.
- Mobile tutorial should: select Sword -> trigger real Skip Tutorial button signal -> verify real teleport -> bounded direct Lobby fallback.

## Important patch-system lessons
- Repeated unified-diff drift caused runtime failures such as combat line 9244, lobby line 342, and watchdog line 408.
- patch_loader V2 can re-anchor line drift only when the old hunk source still exists exactly; it cannot fix a patch written against the wrong effective source.
- Do not add fragile late patches when compatibility/safety can be normalized before or around the module.
- The V61.11.2 watchdog progression-guard patch is superseded and should NOT be re-added to the active chain.

## World2 D1 knowledge (PlaceId 136216144170036)
### Map-level facts
- `GameRoundCfg` exposes WorldId=World2, DiffLevel=1, GameRound, GameRoundComplete, MaxRound=6.
- At least one earlier World2 D1 run reached settlement with 68 targets / 0 deaths, so the map is fundamentally clearable.
- The map contains many `DestructibleObject` tagged models, including crystal/ice/tree objects with replicated attributes such as `HitCount` and `PowerRate`.
- User-observed progression includes a destroyable gate/crystal mechanic. Do not treat all crystal geometry as merely decorative, but do not attack by name alone.

### Boss-skip regression evidence
A previous recon captured authoritative `GameRound=2 / GameRoundComplete=1` while the character was already in Room5/boss-side geometry. The historical watchdog could snap to a far replicated Round1 literal `Portal` and accept displacement as success.

### Latest supplied run after attempted V61.11.2 guard
Match: `20260811_210919_136216144170036_fce19773_D1`.
- Cleared Round1: 17 targets, 0 hits taken, 0 deaths.
- Server advanced to `GameRound=2 / GameRoundComplete=1`.
- Character stayed locally around `(-6389, 33, 687)` instead of jumping to Room5.
- Then stalled in GATE for 170+ seconds.
- Region remained Round1; no enemies; no region-valid DragonEgg.
- Objective probe repeatedly ran, but watchdog counters stayed zero.
- Mobile status proved why: `systems/transition_watchdog.lua` failed to load because the V61.11.2 patch could not find its hunk near source line 408.

Targeted post-crystal diagnostic at the same stop proved portal topology:
- legitimate local `Workspace.RoundDoor.PortalD.Root`, `RoundNum=1`, ~20.6 studs away;
- literal `Workspace.RoundDoor.Portal.Root`, `RoundNum=1`, ~1036 studs away;
- additional future RoundDoor portals were thousands of studs away.

This means the correct immediate recovery after Round1 is the local `PortalD`, not the far literal `Portal`.

### Production correction: V61.11.3 local-safe watchdog wrapper
- Active watchdog entry no longer applies `watchdog_v61_11_2_progression_guard.patch`.
- It loads only the previously proven V61.6/V61.8 watchdog patches, then wraps the resulting watchdog object.
- Wrapper scans all current-1 RoundDoor roots whose parent starts with `Portal`, including `PortalD`.
- Local portal limit: 220 studs.
- Local `Portal*` crossing uses native Humanoid movement only; no portal RF force and no far CFrame snap.
- Wrapper success requires settlement, objective appearance, GameRound change, or a genuinely new nearby wake region.
- If current-1 portals exist only far away, wrapper refuses recovery instead of delegating to the historical far-portal route.
- Only when no current-1 portal exists does it delegate to the older learned-route / bounded local probe system.

Expected next result: after Round1 -> GameRound2, V61.11.3 should cross the ~20-stud `PortalD` and enter the legitimate next room. This remains experimental until confirmed by the next run.

## Recent failures that must not be repeated
1. V61.11.2 watchdog patch load failure near source line 408
   - Cause: safety was implemented as another late multi-hunk diff against an already-patched watchdog.
   - Fix: V61.11.3 wrapper architecture; remove the bad patch from active chain.

2. World2 boss skip after stage 1
   - Cause: far replicated current-1 portal plus displacement-only success in historical watchdog behavior.
   - Fix direction: local Portal* wrapper; far current-1 portals refused.

3. V61.9 combat runtime `:4034 attempt to call a nil value`
   - Cause: objective resolver was constructed before local currentDragonEgg declaration.
   - Fix: region-aware runtime bridge in V61.11.1.

4. V61.10 lobby patch failure near source line 342
   - Cause: mobile compatibility was another late lobby diff.
   - Fix: normalize queue APIs in bootstrap before proven lobby code loads.

5. Earlier combat patch failure around source line 9244
   - Cause: prior patch shifted later hunk.
   - Fix: patch_loader V2 exact-context re-anchoring.

## Diagnostic policy
- Diagnostics are temporary standalone raw scripts supplied as downloadable text files when practical.
- Do not commit recon/diagnostic scripts to GitHub unless user explicitly changes this preference.
- Deep recon should be run only at an exact unknown/stuck mechanic.
- Preferred recon output: game/round state, local geometry/rooms, full paths, attributes, tags, prompts/touches, RoundDoor/portal distances, current kaitun state and a short timeline.

## Current active architecture
- Stable loader URL -> `bootstrap.lua`.
- `bootstrap.lua` routes into `bootstrap_v61_11.lua` (overall runtime family V61.11).
- Lobby entry: V61.11 stable chain using proven V61.6/V61.7/V61.8 forge patches.
- Combat entry: V61.11.1 region-aware egg bridge on top of V61.8/V61.9 combat work.
- Transition watchdog entry: **V61.11.3 local-safe wrapper** over proven V61.6/V61.8 watchdog patches.
- Tutorial entry: mobile-safe V61.11 path.

## Next verification
1. Re-run World2 D1 with current code.
2. Confirm watchdog module loads (no line-408 runtime failure).
3. After Round1 -> GameRound2, confirm telemetry includes `WATCHDOG_LOCAL_PORTAL_START` for `PortalD` around ~20 studs.
4. Confirm `WATCHDOG_LOCAL_PORTAL_SUCCESS` produces real progression and does not move to Room5 early.
5. If local PortalD fails, reuse the focused post-crystal diagnostic `.txt` and send the ZIP; do not guess or manually force portals.
