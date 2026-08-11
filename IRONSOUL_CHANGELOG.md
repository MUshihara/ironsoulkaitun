# Iron Soul Kaitun - Change / Learning Log

Purpose: chronological record of important production changes, failures, and evidence. Future conversations should read this together with `IRONSOUL_PROJECT_MEMORY.md` before modifying the project.

## 2026-08-11 - V61.11.3 local PortalD watchdog recovery
### Evidence from supplied kaitun + targeted diagnostic ZIPs
World2 D1 run `20260811_210919_136216144170036_fce19773_D1` cleared Round1 and reached authoritative `GameRound=2 / GameRoundComplete=1`, then remained in `GATE` for 170+ seconds with 0 enemies and no region-valid egg.

The targeted post-crystal diagnostic showed the player at approximately `(-6389, 33, 687)` and a legitimate local `Workspace.RoundDoor.PortalD.Root` with `RoundNum=1` only ~20.6 studs away. A different literal `Workspace.RoundDoor.Portal.Root` with the same RoundNum remained ~1036 studs away.

The match summary reported `WatchdogStarts=0`. The decisive evidence was `IronSoul_MobileStatus_V61_11.txt`:
`Runtime failed | systems/transition_watchdog.lua | :196: patch hunk source not found near source line 408`.

### Learned
1. The no-boss-skip behavior in this run did NOT prove the V61.11.2 guard was active; the watchdog had failed to load entirely, which also prevented the old far-portal jump.
2. World2 can use `PortalD` as the legitimate current-1 local RoundDoor transition. The historical watchdog only recognized parent name exactly `Portal`, so it could ignore the correct `PortalD` while seeing a far literal `Portal` copy.
3. Safety should not be implemented as another late unified diff against the watchdog. Repeated patch-context failures are themselves a reliability problem.
4. For recovery, known local current-1 RoundDoor portals outrank unknown-objective probing and far replicated copies.

### Changed
- Replaced the active V61.11.2 patched watchdog entry with V61.11.3 local-safe wrapper architecture.
- Removed `watchdog_v61_11_2_progression_guard.patch` from the active watchdog patch chain.
- Preserved the previously proven V61.6/V61.8 watchdog implementation underneath the wrapper.
- Wrapper scans all current-1 RoundDoor roots whose parent name begins with `Portal`, including `PortalD` and future `Portal*` variants.
- Local recovery limit is 220 studs.
- Local portal crossing uses native Humanoid movement only; no far CFrame snap and no direct portal RF forcing.
- Success requires settlement, objective appearance, GameRound change, or a genuinely new nearby RoundWakeTouch region. Raw displacement is not accepted by the wrapper.
- If current-1 portals exist only far away, wrapper refuses recovery rather than delegating into the historical far-portal path.
- Only when no current-1 RoundDoor portal exists at all does the wrapper delegate to the older learned-route / bounded-probe recovery.

### Intentionally left untouched
- Normal combat / boss positioning.
- World2 objective probe logic.
- World1 door traversal.
- Forge, inventory, progression and mobile bootstrap behavior.

### Expected verification
After World2 Round1 becomes GameRound2, V61.11.3 should see the ~20-stud Round1 `PortalD`, walk through it naturally, obtain real progression evidence, and enter the legitimate next room. It must never choose the ~1000-stud literal Round1 `Portal` instead.

### Status
The watchdog load failure and local/far portal topology are proven. V61.11.3 local `PortalD` crossing is experimental until the next run.

## 2026-08-11 - V61.11.2 World2 boss-skip regression guard
### Evidence
Standalone RAW_RECON_R3 captured World2 D1 after only the first stage was cleared. Authoritative server state was still `GameRound=2` / `GameRoundComplete=1`, but the player was already physically inside `Workspace.World.Room5` near the boss-side area.

Kaitun nav history showed a replicated Round1 portal more than 1,000 studs away being used as recovery and raw displacement being accepted as `PORTAL_MOVED` success. That route could then contaminate persistent route learning.

### Learned
- A transition watchdog is a local recovery tool. It must never snap to a replicated current-1 portal hundreds/thousands of studs away.
- Raw displacement (`PORTAL_MOVED`) is not sufficient progression proof.

### Attempted change
A multi-hunk `watchdog_v61_11_2_progression_guard.patch` was added to enforce local-only portal acquisition and reject displacement-only learned routes.

### Later correction
The next run proved this patch itself failed to load (`patch hunk source not found near source line 408`). The intended V61.11.2 guard was therefore not actually active. This implementation is superseded by V61.11.3's wrapper architecture, which avoids modifying the watchdog internals with another fragile late diff.

## 2026-08-11 - Diagnostic / continuity policy correction
### User preference
Temporary recon scripts should be standalone raw scripts supplied in chat. They should not live in the production GitHub repository unless the user explicitly asks for that.

### Changed
- Removed the temporary committed `DIAGNOSTIC.lua` and `diagnostics/world_recon_v61_11.lua` files.
- Added `IRONSOUL_PROJECT_MEMORY.md` as persistent project knowledge.
- Added `IRONSOUL_CHANGELOG.md` as the chronological evidence/change record.
- Added `START_HERE_CHATGPT.md` instructing future chats to read the memory/changelog before changing code.

### Maintenance rule
Production fixes stay in GitHub. Deep one-off diagnostics stay raw in chat. Update project memory/changelog whenever production behavior or verified knowledge changes.

## 2026-08-11 - V61.11.1 combat hotfix
### Evidence
World2 D1 reached Round4/CompletedRound3, then remained in GATE with 0 local/global enemies, no region-valid DragonEgg, no recognized doors, and no objective-probe events.

### Learned
The V61.10 anti-nil shortcut used a direct `workspace.DragonEgg` check. That can see a stale/future egg outside the current combat branch and incorrectly tell the objective resolver that a normal objective is active.

### Changed
- Added `combat_v61_11_1_region_egg_bridge.patch`.
- Publish the actual region-aware `currentDragonEgg()` only after that helper is defined.
- Early objective resolver resolves this published function at runtime.
- Removed dependency on global unfiltered DragonEgg presence.

## 2026-08-11 - V61.11 lobby/mobile stabilization
### Failure that triggered it
`[IronSoul V61.10] Runtime failed | systems/lobby.lua | :196: patch hunk source not found near source line 342`

### Changed
- Removed active `lobby_v61_10_mobile_executor.patch` from the lobby chain.
- Lobby uses only proven V61.6 balanced forge, V61.7 best-ore reserve, and V61.8 forge metrics patches.
- `bootstrap_v61_11.lua` detects real executor teleport queue aliases before lobby loads.
- Standard queue compatibility is normalized in bootstrap instead of patching lobby internals.
- If no native queue exists, current-cycle progression can continue while HUD/status marks manual re-execution mode.
- Tutorial route corrected to a versioned mobile-safe tutorial.

## 2026-08-11 - V61.10 combat scope hotfix
### Failure
`[IronSoul V61.9] Runtime failed: systems/combat.lua | :4034: attempt to call a nil value`

### Cause
V61.9 objective resolver was constructed before local `currentDragonEgg()` declaration and attempted to use that name too early.

### Later correction
The first global DragonEgg workaround was too broad for multi-branch World2 and was superseded by V61.11.1's region-aware bridge.

## 2026-08-11 - V61.9 unknown-objective recovery
### Evidence
World2 introduced empty progression states that did not look like normal RoundDoor transitions.

### Changed
- Added bounded unknown-objective resolver.
- Scan nearby gate/wall/barrier/crystal/ice/rock-like objects.
- Rank evidence using attributes, HP/progress values, prompts, touches, remotes, collision and distance.
- Attack only when there is evidence of a real damageable progression object.
- Require server-visible progress before continuing attacks.
- Fall back to transition recovery when no damageable objective is confirmed.

### Important rule
Do not assume object names alone mean a gate is attackable.

## 2026-08-11 - V61.8 / multi-match optimization phase
### Battle evidence
Across complete D5 benchmark runs:
- normal mobs were around ~1 second per kill;
- most incoming damage was concentrated on boss/high-HP targets;
- a repeated Round4->Round5 transition cost about 21 seconds.

### Changed
- Preserve normal combat values.
- Add stronger boss burst-safe escape behavior.
- Keep skill cast telemetry.
- Add learned-route transition fast path after a route has already been proven.
- Add authoritative settlement checkpoint before replay/lobby teardown.

## 2026-08-11 - Patch loader V2
### Failure that triggered it
Combat patch context mismatch around source line 9244 after preceding patches shifted the later hunk.

### Changed
- Keep exact-context safety.
- If recorded line drifts, search remaining source for the complete unchanged/removed hunk sequence.
- Re-anchor only on a unique/unambiguous exact match.
- Reject fuzzy/ambiguous matches.

## Earlier validated milestones
### V55.2
Full dungeon success in PlaceId 116456628154258: SETTLEMENT_REACHED, 126.13s, 128 targets, 5 transitions, 0 deaths, headless remote attack, no mouse basic attack.

### V58
One-cycle progression passed: World1 Diff2 Level10/Power341 -> Lobby Level11 Power355.

### V59
Continuous modular Tutorial -> Lobby -> Dungeon -> Lobby architecture established.

## Maintenance rule for future changes
Every meaningful production change should append an entry with:
1. Evidence/problem.
2. Root cause or current hypothesis.
3. Exact files/modules changed.
4. What was intentionally left untouched.
5. Expected verification in the next run.
6. Whether the finding is proven, probable, or experimental.
