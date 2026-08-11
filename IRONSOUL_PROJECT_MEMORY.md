# Iron Soul Kaitun — Compact Project Memory

## Goal
24/7 automatic **fresh account -> end progression**. Headless/API-first, fast, low CPU/RAM. No normal clicking.

## Current focus
**World2 frozen. Keep Tutorial -> Lobby -> World1 -> Lobby stable, then expand Lobby upgrades.**

## Proven baseline
- Tutorial `76701861705540`; Lobby `117533937949084`; validated World1 dungeon `116456628154258`.
- Multiple fresh accounts proved repeated `Lobby -> W1 -> settlement -> next cycle` through W1 D1/D2/D3.
- Normal World1 combat is strong; do not retune without evidence.
- Headless forge, EquipBest/smart cleanup, pet hatch/claim/equip validated.

## Fresh Lobby truth
- PlayerData can be ready while fresh `LG_Level=nil`.
- Authoritative fresh level is `PlayerData.LevelData.Level`.
- Resolve/mirror level in lobby preflight only; do not add another fresh-level patch.

## World1 movement/traversal — CRITICAL
- User wants **smooth fast CFrame tween/floating**, not Roblox walking and not hard instant snapping everywhere.
- Never use `Humanoid:MoveTo` as normal World1 gate/portal movement.
- `systems/world1_motion.lua`: ~210 studs/sec normal, ~260 long traversal.
- Exact gate/portal + prompt/touch/handshake + authoritative progression verification required.
- Portal timing: after tweening to safe pre-portal point, wait about **0.60s before first touch/cross**.
- Never generic RoundPortal RF; it previously skipped rooms/state.

Known traversal fixes:
- Empty COMBAT may follow a far gate ONLY when `RoundNum == GameRound-1`, bounded <=650 studs. Fixed real ~414-stud Round3 traversal stall.
- Normal GATE selection keeps old tight region rule; historical/wrong-round gates remain rejected.
- Already-open gate recovery tweens full ~41 studs and requires settlement/GameRound/new-region evidence. `CROSSED_PLANE` alone is not success.

### W1 D3 cross-section / premature boss jump — V61.14.5
Fresh evidence ZIP `20260812_011643...D3` proved a reused section `Portal` can send the character to the **Round7 boss-area wake while authoritative `GameRound` is still 5**.
- Stuck proof: `GameRound=5`, `CurrentRegion=RoundWakeTouch.Round7`, player about `(-2558, 50.8, 7)`, no enemies, no settlement.
- Successful D3 order is `Round4 -> Round5 enemies -> Round6 -> Round7 boss`.
- Before the bad jump, Round5 enemies/wake were already authoritative and ~770–950 studs ahead.
- Old `portalTeleportEvidence` treated any >100-stud displacement as `PORTAL_MOVED`; this was fake progression and is removed.
- New region evidence only counts when wake name equals `Round<GameRound>`.
- `systems/world1_round_recovery.lua` caches/live-tracks RoundWakeTouch locations and, before ambiguous section-portal handshake, smooth-tweens to the **server-current round wake** when it is a far cross-section route. This cannot intentionally skip to Round7 while server is Round5.
- If a portal still misplaces the character, the cached current-round wake can recover the route on the next bounded attempt.
- Round7 remains the correct D3 boss area; it should only be entered when server `GameRound==7`.

## Settlement / replay / inventory — V61.14.4+
Old replay path could wait ~8s UI + 12s signal + 15s remote + 15s retry + 15s vote before `NATIVE_SOLO_REPLAY_FAILED`; unacceptable for 24/7.

Current rules:
- Equipment maintenance threshold = `INVENTORY_CLEAN_AT` = 85.
- If ore/equipment bag full OR inventory >=85 at settlement, skip replay and return Lobby immediately.
- Re-check capacity before replay because settlement rewards can fill it.
- Replay UI wait ~1.4s; replay evidence windows ~1.1–1.45s.
- If `VotedAgainCount >= PlayersCount` while restart does not begin, return Lobby immediately.
- Any bounded replay failure returns Lobby; no public same-PlaceId fallback.
- Lobby then performs cleanup/forge/equip/progression before next solo run.

### Luau local-register ceiling — DO NOT FORGET
- Historical `systems/combat.lua` is extremely close to Luau's local-register limit.
- First fast-settlement change caused `Out of local registers` because it added locals.
- Current settlement patch is zero-new-local in the giant combat chunk.
- Future substantial logic belongs in wrappers/modules such as `world1_round_recovery.lua`, not more combat locals.

## Forge
- Lobby forge chain: V61.6 -> V61.7 reserve-best-ore -> V61.8 measured forge.
- Previously validated headless forge remains preserved.

## Lobby mutation discovery
R2: `FortifyUtil.Fortify` arity3; `EnchantmentUtil.Enchant` arity5; `UnEnchant` arity4. Pet/Honor/Season/shop modules/remotes confirmed.
R3 found concrete system remotes but not exact Fortify/Enchant outbound tuple. Do not enable unattended mutation spending yet.

## Workflow rules
- Diagnostics are standalone downloadable `.lua`; results/logs may be `.txt` in ZIPs.
- Helpers fail closed; diagnostics/recovery must not kill combat.
- Production fixes in GitHub.

## World2 retained while frozen
- D1 `136216144170036`, MaxRound6, PortalD exists.
- DestructibleObject/HitCount alone never proves progression; do not restore scenery attacks/far portal skipping.

## Next
1. Re-execute normal loader; confirm V61.14.5 compiles.
2. Retest W1 D3. At Round4->5 expect `CURRENT_ROUND_ROUTE_START round=5` then `CURRENT_ROUND_ROUTE_SUCCESS`, not a jump to Round7.
3. Confirm Round5 clears, then Round6, then Round7 boss normally.
4. After W1 D3 is stable, resume Fortify/Enchant protocol validation.
