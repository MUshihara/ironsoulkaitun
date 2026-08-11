# Iron Soul Kaitun — Compact Project Memory

## Goal
24/7 automatic **fresh account -> end progression**. Headless/API-first, fast, low CPU/RAM. No normal clicking.

## Current focus
**World2 frozen for active movement. Keep Tutorial -> Lobby -> World1 -> Lobby stable, while a generic live route mapper learns each dungeon place.**

## Proven baseline
- Tutorial `76701861705540`; Lobby `117533937949084`; validated World1 dungeon `116456628154258`.
- Multiple fresh accounts proved repeated W1 D1/D2/D3 progression and settlement.
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
- Portal timing: dwell about **0.60s** at safe pre-portal point before first touch/cross.
- Never generic RoundPortal RF; it previously skipped rooms/state.

Known fixes:
- Exact current-1 far gate may be followed up to 650 studs only in empty traversal; fixed real ~414-stud Round3 stall.
- Already-open gate recovery crosses ~41 studs and requires real evidence; `CROSSED_PLANE` is not success.
- Raw >100-stud movement is never progression proof.

## V61.15 live dungeon route mapper — IMPORTANT
`systems/dungeon_route_mapper.lua` is a place-aware live route engine.
- Every Roblox Place has a separate Workspace instance tree. World1 and World2 use the same Roblox `workspace` API, but their PlaceIds/layouts/doors/portal variants are different. **Never share coordinates or exact door assumptions across places.**
- Mapper keys/discovers from live `PlaceId`, `WorldId`, `Diff`, `GameRound`, `RoundWakeTouch.RoundN`, Door roots, Portal* roots, Switch/RoundNum, objectives and streamed-object appearance.
- World1 active recovery; World2 discovery/logging only until World2 is deliberately unfrozen.
- Writes `IronSoul_DungeonRouteMap_V61_15.txt` so future chats can see the current place's full round/wake/door/portal map.
- If server-current wake is live, tween to that exact round.
- If server already advanced but current wake is **not streamed yet**, use the last exact open `GameRound-1` gate as a frontier and probe farther beyond it in bounded smooth-tween steps, watching for current wake, objectives, server round change, or a newly streamed exact local current-1 portal.
- No wrong-round historical portal/gate is accepted.
- Bounded repeated failure returns Lobby/rebuild instead of looping forever.

### D3 evidence that motivated V61.15
Earlier D3 proof: reused section Portal could physically land in Round7 while authoritative `GameRound=5`; this was an invalid premature boss jump. `world1_round_recovery.lua` now follows the server-current wake before ambiguous portal use.

Latest ZIP `20260812_013625...D3` proved the opposite edge:
- `GameRound` correctly advanced `6->7`.
- Player crossed open Round6 gate at x~453 to x~494.
- **Round7 wake did not exist yet at all**; live wakes were only Round1–Round6, no enemies, no current portal.
- Old code repeated `OPEN_GATE_TWEEN_FULL_CROSS` every ~2.7s forever.
- V61.15 now calls the external live route mapper after this open-gate stall, so it searches/probes forward from the exact Round6 frontier instead of repeating the same 41-stud cross.
- Round7 is still the real D3 boss round, but its region can be a streamed/special transition and therefore cannot always be located by `RoundWakeTouch.Round7` before the final trigger fires.

## Settlement / replay / inventory
- Equipment maintenance threshold = 85.
- Full ore/equipment bag or inventory >=85 at settlement -> skip replay, return Lobby immediately.
- Replay UI/route waits are short bounded windows (~1.1–1.45s); stuck full vote -> Lobby.
- No public same-PlaceId fallback.

## Luau local-register ceiling — DO NOT FORGET
- Historical `systems/combat.lua` is near Luau local-register limit.
- A prior settlement change caused `Out of local registers`.
- Future substantial logic belongs in external modules/wrappers. V61.15 mapper is preloaded outside the historical chunk; open-gate integration adds no new locals.

## Forge / lobby upgrades
- Forge chain remains V61.6 -> V61.7 reserve-best-ore -> V61.8 measured forge; previously validated.
- R2: `FortifyUtil.Fortify` arity3; `EnchantmentUtil.Enchant` arity5; `UnEnchant` arity4.
- R3 found concrete Equipment/Pets/Honor/Season remotes but not exact mutation argument tuple. Do not enable unattended Fortify/Enchant spending yet.

## World2 retained while frozen
- World2 D1 PlaceId `136216144170036`, MaxRound6, PortalD exists.
- Many scenery props have DestructibleObject/HitCount; never infer objective from tags alone.
- Generic mapper may log World2 live wakes/doors/PortalD, but active World2 movement remains disabled until validated.

## Workflow
- Diagnostic scripts in chat are `.lua`; output/log files may be `.txt` in ZIPs.
- Production fixes in GitHub; helpers fail closed.

## Next
1. Run normal loader on V61.15 and let D3 reach Round6->7.
2. Expect route events such as `ROUTE_MAP_FRONTIER_START`, `ROUTE_MAP_FRONTIER_PROBE`, then `ROUTE_MAP_FRONTIER_SUCCESS` when Round7 streams/portal triggers/boss appears.
3. Send normal ZIP plus `IronSoul_DungeonRouteMap_V61_15.txt` if it still stalls.
4. Once W1 D3 is stable across several runs, resume Fortify/Enchant protocol validation.
