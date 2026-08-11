# Iron Soul Kaitun — Compact Project Memory

## Goal
24/7 automatic **fresh account -> end progression**. Headless/API-first, fast, low CPU/RAM. No normal clicking.

## Current focus
**World2 frozen. Keep Tutorial -> Lobby -> World1 -> Lobby stable, then expand Lobby upgrades.**

## Proven baseline
- Tutorial `76701861705540`; Lobby `117533937949084`; validated World1 dungeon `116456628154258`.
- Multiple fresh accounts proved repeated `Lobby -> W1 D1 -> settlement -> next cycle`.
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
- **Portal timing:** after tweening to the safe pre-portal point, wait about **0.60s before first touch/cross**. This prevents the fast tween from ending beyond a portal before its server trigger is armed.
- This 0.60s settle is applied to normal exact section-portal handshake and transition/watchdog tween wrappers.
- Never generic RoundPortal RF; it previously skipped rooms/state.

Known traversal fixes:
- Empty COMBAT may follow a far gate ONLY when `RoundNum == GameRound-1`, bounded <=650 studs. Fixed real ~414-stud Round3 traversal stall.
- Normal GATE selection keeps old tight region rule; historical/wrong-round gates remain rejected.
- Already-open gate recovery tweens full ~41 studs and requires settlement/GameRound/new-region evidence. `CROSSED_PLANE` alone is no longer success.

## Settlement / replay / inventory — V61.14.3
Old replay path could wait ~8s UI + 12s signal + 15s remote + 15s retry + 15s vote before `NATIVE_SOLO_REPLAY_FAILED`. This is unacceptable for 24/7.

Current rules:
- Equipment maintenance threshold = `INVENTORY_CLEAN_AT` = 85 (not 90).
- If ore/equipment bag is full OR inventory >=85 at settlement, **skip replay and return Lobby immediately**.
- Re-check bag/inventory again just before any replay mutation because settlement rewards can fill capacity.
- Replay UI wait ~1.4s; replay route evidence windows ~1.1–1.45s instead of 12–15s.
- If `VotedAgainCount >= PlayersCount` while settlement is still stuck, treat replay as full/stuck and return Lobby immediately instead of firing more routes.
- Any bounded replay failure returns Lobby; do not use public same-PlaceId fallback.
- `directLobby`: queue next boot, fire native `WorldUtil.RemoteEvent:FireServer("BackLobby")` almost immediately, wait ~2s for teleport confirmation, then use Lobby TeleportService fallback.
- Lobby then performs smart cleanup/forge/equip/progression before launching the next solo run.

## Forge
- Lobby forge chain: V61.6 -> V61.7 reserve-best-ore -> V61.8 measured forge.
- Previously validated headless forge remains preserved; recent fresh runs simply did not hit forge threshold.

## Lobby mutation discovery
R2 snapshot: Level7/Power207, Currency1 13,837, SeasonCurrency1,000, ores61, no pets/stones.
- `FortifyUtil.Fortify` arity3.
- `EnchantmentUtil.Enchant` arity5; `UnEnchant` arity4.
- Pet growth, Honor, Season and shop modules/remotes confirmed live.
R3 found concrete system remotes (`EquipmentRE`, `ForgeRF`, `PetsRE`, Honor/Season/shop remotes) but not exact Fortify/Enchant outbound request tuple. Do not enable unattended mutation spending yet.

## Workflow rules
- Diagnostics are standalone downloadable `.lua`; results/logs may be `.txt` in ZIPs.
- Helpers fail closed; diagnostics/recovery must not kill combat.
- Production fixes in GitHub.

## World2 retained while frozen
- D1 `136216144170036`, MaxRound6, PortalD exists.
- DestructibleObject/HitCount alone never proves progression; do not restore scenery attacks/far portal skipping.

## Next
1. Let a fresh account run several W1 cycles on V61.14.3. Verify portal logs include `PORTAL_ARM_SETTLE` / `TWEEN_PORTAL_SETTLE` and transitions still complete reliably.
2. At settlement, verify full/high inventory goes straight Lobby; stuck replay vote returns Lobby in a few seconds, not ~1 minute.
3. Then validate exact Fortify/Enchant mutation call protocol before conservative headless spending.
