# Iron Soul Kaitun — Compact Project Memory

## Goal / style
- Fully automatic NEWBIE -> higher progression, 24/7.
- Headless, low CPU/RAM, fast.
- Internal APIs/remotes/modules preferred; no clicking.
- Preserve proven systems unless telemetry/recon proves a reason to change them.

## Proven stable knowledge
- Tutorial: `76701861705540`; starter Sword index 1.
- Lobby: `117533937949084`.
- Validated World1 dungeon example: `116456628154258`.
- V55.2: settlement, 128 targets, 5 transitions, 0 deaths, headless remote attack, no mouse basic.
- V58 W1 D2: Lv10/P341 -> Lobby Lv11/P355.
- Normal combat is strong. ~9-stud elevated profile is reliable; ~5.5-stud close recovery restores damage when HP stops moving.
- Balanced forge/inventory logic is useful; do not casually retune it.

## Transition rules that must not be forgotten
- Exact server progression > movement.
- Direct RoundPortal RF can skip intermediate rooms; do not use as a generic fast path.
- Far replicated current-1 portals are unsafe.
- `PORTAL_MOVED`, large displacement, and object removal are not success.
- Known exact local portal/gate outranks unknown-object probing.
- Fast safe portal pattern: exact local `Portal*` -> safe pre-position BEFORE it -> native/touch handshake -> verify round/objective/region.
- Preserve validated World1 recovery; World2 must not reuse unsafe learned/far-route behavior.

## World2 D1 (`136216144170036`)
- `WorldId=World2`, Diff1, `MaxRound=6`.
- Correct RoundDoor may be named `PortalD`, not only literal `Portal`.
- Many ordinary props are tagged `DestructibleObject` and expose `HitCount`/`PowerRate`: trees, chests/coins, IceCrystal, crystals, etc.
- Therefore `HitCount` or tag alone NEVER proves a progression gate.
- Bad behavior proved: after Round3->4, old resolver attacked Tree -> IceCrystal -> Tree2 because removal counted as success, then traversal looped while round stayed 4.
- Full recon proved local `PortalD` can be correct: Round1 PortalD at ~49 studs produced `OBJECTIVE_APPEARED`.
- Round4 evidence showed Round3 PortalD around ~37-115 studs, while native-only crossing could repeatedly fail.

## Current World2 production rule
- `objective_probe.lua` is route-blocker-only: it may attack only the first collidable `DestructibleObject` physically ray-hit on the route to the authoritative current wake, after excluding obvious loot/scenery.
- Enemy/DragonEgg and exact current portal always win first.
- Removing a blocker is not enough; success still requires GameRound / settlement / objective / region evidence.
- `transition_watchdog.lua` uses local current-1 `Portal*` up to 320 studs, safe pre-position, native movement + exact touch, and NO portal RF.
- World2 does not fall back to the old far/learned watchdog when no safe local current portal exists.

## Mobile
- Detect capabilities, not executor brand.
- Normalize teleport queue aliases in bootstrap.
- If no native queue exists, current cycle may continue but re-execution after teleport can be required.
- Mobile HUD/status file should expose actual runtime errors/state.

## Reliability / continuity
- Avoid fragile late patch stacks when a direct module/wrapper can enforce behavior safely.
- Diagnostics are standalone downloadable `.txt` scripts supplied in chat, not production GitHub.
- Current repo beats stale chat memory when they conflict.
- Read `IRONSOUL_CHANGELOG.md` only when tracing a specific old regression.

## Next verification
Run World2 D1 with current code. Confirm:
1. enemies are attacked before any destructible;
2. no Tree/Chest/IceCrystal farming;
3. local `PortalD` transitions quickly with real progression;
4. no boss skip / far portal jump;
5. if a true route blocker exists, only that blocker is attacked and its removal alone does not mark success.
