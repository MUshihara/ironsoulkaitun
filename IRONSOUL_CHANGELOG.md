# Iron Soul Kaitun - Change / Learning Log

Purpose: chronological record of important production changes, failures, and evidence. Future conversations should read this together with `IRONSOUL_PROJECT_MEMORY.md` before modifying the project.

## 2026-08-11 - V61.11.2 World2 boss-skip regression guard
### Evidence
Standalone RAW_RECON_R3 captured World2 D1 after only the first stage was cleared. Authoritative server state was still `GameRound=2` / `GameRoundComplete=1`, but the player was already physically inside `Workspace.World.Room5` near the boss-side area.

Kaitun nav history showed the sequence:
- objective resolver correctly attacked `Workspace.World.Room1...crystal6`;
- `crystal6` exposed `HitCount` / `PowerRate` and was tagged `DestructibleObject`;
- the authoritative round advanced from 1 to 2 after the destructible crystal gate was handled;
- empty traversal then called the transition watchdog;
- watchdog selected a replicated Round1 portal more than 1,000 studs away;
- watchdog CFramed near the remote portal, crossed it, and accepted `PORTAL_MOVED` (>100 stud displacement) as transition success;
- the resulting bad route was persisted as a successful D1/R2 learned route;
- the player bounced between the old Round1 portal area and Room5 while server GameRound remained 2.

### Learned
1. World2 uses real destructible progression objects. `crystal6` / `DestructibleObject` with server-visible `HitCount` is a valid mechanic, not decoration.
2. Destroying the barrier and advancing GameRound does not mean navigation to the next physical room is finished.
3. A transition watchdog is a local recovery tool. It must never CFrame to a replicated current-1 portal hundreds/thousands of studs away.
4. Raw displacement (`PORTAL_MOVED`) is not progression proof.
5. Persistent route learning must not replay or advertise routes learned from displacement-only evidence.

### Changed
- Added `watchdog_v61_11_2_progression_guard.patch`.
- Watchdog portal acquisition is capped at 220 studs.
- Removed `PORTAL_MOVED` from transition success evidence.
- Reject old learned routes whose result is `PORTAL_MOVED` or `CHARACTER_CHANGED`.
- Reject the same unsafe results from `HasLearnedRoute()` so the combat fast path cannot advertise them as proven.
- Prevent future unsafe results from being saved by `learnSuccess()`.
- Kept the bounded local movement probes as the fallback when no safe local portal exists.

### Intentionally left untouched
- World2 destructible-object resolver: the crystal gate detection/attack was correct and produced real GameRound progression.
- Normal combat positioning/DPS.
- Proven World1 exact-door and portal traversal logic.
- Forge/inventory policy.

### Expected verification
After clearing World2 Round1, GameRound should become 2 and the character should remain on the local route instead of jumping to Room5. The watchdog should ignore far Round1 portals and use local traversal/probing. Boss-room entry should only occur when normal authoritative progression reaches it.

### Status
Root cause of the boss skip is proven by recon. Correct next-room local traversal behavior is still experimental until the next World2 run.

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
Latest World2 D1 run reached Round4/CompletedRound3, then remained in GATE with 0 local/global enemies, no region-valid DragonEgg, no recognized doors, and no objective-probe events.

### Learned
The V61.10 anti-nil shortcut used a direct `workspace.DragonEgg` check. That can see a stale/future egg outside the current combat branch and incorrectly tell the objective resolver that a normal objective is active.

### Changed
- Added `combat_v61_11_1_region_egg_bridge.patch`.
- Publish the actual region-aware `currentDragonEgg()` only after that helper is defined.
- Early objective resolver resolves this published function at runtime.
- Removed dependency on global unfiltered DragonEgg presence.

### Expected result
World2 empty GATE states can reach objective probing even when another branch has a replicated DragonEgg.

## 2026-08-11 - V61.11 lobby/mobile stabilization
### Failure that triggered it
`[IronSoul V61.10] Runtime failed | systems/lobby.lua | :196: patch hunk source not found near source line 342`

### Learned
Executor compatibility should not be another late diff against a heavily patched lobby source.

### Changed
- Removed active `lobby_v61_10_mobile_executor.patch` from the lobby chain.
- Lobby now uses only proven V61.6 balanced forge, V61.7 best-ore reserve, and V61.8 forge metrics patches.
- `bootstrap_v61_11.lua` detects real executor teleport queue aliases before lobby loads.
- Standard `queue_on_teleport` compatibility is normalized in bootstrap.
- If no native queue exists, current-cycle progression can continue while HUD/status clearly marks manual re-execution mode.
- Mobile status/capability logging kept in bootstrap.
- Tutorial route corrected to a versioned mobile-safe tutorial.

## 2026-08-11 - V61.10 combat scope hotfix
### Failure that triggered it
`[IronSoul V61.9] Runtime failed: systems/combat.lua | :4034: attempt to call a nil value`

### Cause
V61.9 objective resolver was constructed before local `currentDragonEgg()` declaration and attempted to close over/use that name too early.

### Changed
- Replaced direct early reference with a self-contained objective check.
- Nil-guarded optional nav/status callback.

### Later correction
The self-contained global DragonEgg check was too broad for multi-branch World2 and is superseded by V61.11.1's region-aware bridge.

## 2026-08-11 - V61.9 unknown-objective recovery
### Evidence
World2 introduced empty progression states that did not look like normal RoundDoor transitions. A previous run could finish, while another stopped at a new icy gate/transition.

### Changed
- Added bounded unknown-objective resolver.
- Scan nearby gate/wall/barrier/crystal/ice/rock-like objects.
- Rank evidence using attributes, HP/progress values, prompts, touches, remotes, collision and distance.
- Attack only when there is evidence of a real damageable progression object.
- Require server-visible progress before continuing attacks.
- Fall back to existing transition watchdog when no damageable objective is confirmed.

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
