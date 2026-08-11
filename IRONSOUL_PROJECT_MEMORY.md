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
- Transition watchdog persists successful learned routes and bounded recovery attempts.
- Learned-route fast path should only be used when a route was previously proven; unseen transitions fall back to conservative logic.
- World2 introduces transition/objective classes not covered by old RoundDoor logic.

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
- Repeated unified-diff line-number drift caused runtime failures such as line 9244 and lobby line 342.
- patch_loader V2 re-anchors by exact old hunk text when recorded line numbers drift, and rejects ambiguous/nonexistent anchors.
- Do not add fragile late patches when compatibility can be normalized before the module loads.

## Recent World2 evidence (2026-08-11)
PlaceId 136216144170036, World2 Diff1.

A prior World2 run reached settlement with 68 targets and 0 deaths, proving the whole map is not fundamentally unsupported.

Latest supplied run (MatchId 20260811_203347_136216144170036_11bfe0a9_D1):
- World=World2, Diff=1
- Reached GameRound 4 / CompletedRound 3
- TargetsCompleted=46
- PlayerHits=1, PlayerDamage=96
- 0 deaths
- Round2 gate succeeded normally with NEW_REGION_FAST
- After Round3 clear, controller entered GATE at Round4 and stalled
- During stall:
  - LocalEnemies=0
  - GlobalEnemies=0
  - Egg=none according to region-aware combat state
  - Nearest doors=none
  - player full HP 2973/2973
  - current region Round3
  - exact replicated portal was thousands of studs away and not a valid local transition
- No OBJECTIVE_PROBE events occurred during this Round4 stall.

### Root cause hypothesis/fix for missing Round4 probe
V61.10 fixed an earlier nil by making the early objective resolver check any workspace.DragonEgg directly. That was too broad: a stale/future DragonEgg replicated in another streamed branch can block the resolver even when region-aware currentDragonEgg() correctly returns nil.

V61.11.1 combat adds a runtime bridge to the actual region-aware currentDragonEgg() function. The objective resolver now uses the same egg ownership logic as normal combat instead of a global workspace egg check.

## Recent failures that must not be repeated
1. V61.9 combat runtime `:4034 attempt to call a nil value`
   - Cause: objective resolver was constructed before local currentDragonEgg declaration and closed over a nil/out-of-scope name.
   - Fix: first scope hotfix; later improved by region-aware runtime bridge.

2. V61.10 lobby patch failure `patch hunk source not found near source line 342`
   - Cause: mobile compatibility was implemented as another late lobby diff on top of older lobby patches.
   - Fix: remove that mobile lobby patch entirely. Normalize queue APIs in bootstrap before proven lobby code loads.

3. Earlier combat patch failure around source line 9244
   - Cause: prior patch shifted later hunk by one line.
   - Fix: patch_loader V2 exact-context re-anchoring.

## Diagnostic policy
- Diagnostics are temporary, standalone raw scripts supplied in chat.
- Do not commit recon/diagnostic scripts to GitHub unless user explicitly changes this preference.
- Production code should collect bounded useful telemetry automatically, but deep recon should be run only when needed.
- Preferred recon output for unknown world mechanics: game/round state, nearby objects, full paths, attributes, NumberValue/IntValue state, prompts/touches/clicks, remotes/modules names, CollectionService tags, candidate objective ranking, and a short change timeline.

## Current active architecture
- Stable loader URL -> bootstrap.lua
- bootstrap.lua currently routes into bootstrap_v61_11.lua (overall runtime family V61.11)
- Lobby entry is V61.11 stable chain with only proven V61.6/V61.7/V61.8 forge patches.
- Combat entry is V61.11.1 and adds the region-aware egg bridge after V61.10 scope hardening.
- Tutorial entry is mobile-safe V61.11 path.

## Next investigation
1. Re-run World2 D1 with V61.11.1 combat and verify Round4 produces OBJECTIVE_PROBE instead of silently stalling.
2. Run standalone raw recon at the exact World2 Round4 stuck/gate area.
3. Use recon to identify whether the new mechanic is:
   - damageable gate/barrier,
   - interaction/touch gate,
   - hidden checkpoint/portal,
   - streamed objective with HP/progress state,
   - or another mechanic entirely.
4. Only then encode a permanent generic resolver.
