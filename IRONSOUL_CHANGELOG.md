# Iron Soul Kaitun - Change / Learning Log

Purpose: chronological record of important production changes, failures, and evidence. Future conversations should read this together with `IRONSOUL_PROJECT_MEMORY.md` before modifying the project.

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
One-cycle progression passed: World1 Diff2 Level10/Power341 -> Lobby Level11/Power355.

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
