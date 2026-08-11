# Iron Soul Kaitun — Compact Project Memory

## Goal
24/7 automatic **fresh account -> end progression**. Headless/API-first, fast, low CPU/RAM. No normal clicking.

## Current focus
**World2 frozen. Keep Tutorial -> Lobby -> World1 -> Lobby stable, then expand Lobby upgrades.**

## Proven baseline
- Tutorial `76701861705540`; Lobby `117533937949084`; validated World1 dungeon `116456628154258`.
- Multiple fresh accounts proved repeated `Lobby -> W1 D1 -> settlement -> Lobby -> next run`.
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
- Never generic RoundPortal RF; it previously skipped rooms/state.

Known route fixes:
- Empty COMBAT may follow a far gate ONLY when `RoundNum == GameRound-1`, bounded <=650 studs. This fixed a real ~414-stud Round3 traversal stall.
- Normal GATE selection keeps the old tight region rule; historical/wrong-round gates remain rejected.

V61.14.2 final-gate race proof/fix:
- New-account run completed 3 W1D1 matches, then intermittently stalled after `GameRound 5->6` around x=450.
- Round5 gate was already open. Old recovery tweened only 14 studs, returned `OPEN_GATE_CROSSED` from geometric plane crossing, then entered empty COMBAT before Round6 region/enemies existed.
- Successful normal gate runs cross to ~41 studs and then produce `DOOR_FAST_REGION Round6`.
- V61.14.2 updates the existing open-gate patch in place: tween full 41 studs, wait for settlement/GameRound/new-region evidence, and **do not treat crossed plane as progression success**.
- If evidence is late, stay/retry the same correct GATE instead of dropping into watchdog probe loops.

## Forge
- Lobby forge chain: V61.6 -> V61.7 reserve-best-ore -> V61.8 measured forge.
- Previously validated headless forge remains preserved; recent fresh runs simply did not hit forge threshold.

## Lobby mutation discovery
R2 snapshot: Level7/Power207, Currency1 13,837, SeasonCurrency1,000, ores61, no pets/stones.
- `FortifyUtil.Fortify` arity3.
- `EnchantmentUtil.Enchant` arity5; `UnEnchant` arity4.
- Pet growth, Honor, Season and shop modules/remotes confirmed live.
R3 found concrete system remotes (`EquipmentRE`, `ForgeRF`, `PetsRE`, Honor/Season/shop remotes) but not the exact Fortify/Enchant outbound request tuple. Do not enable unattended mutation spending yet.

## Workflow rules
- Diagnostics are standalone downloadable `.lua`; results/logs may be `.txt` in ZIPs.
- Helpers fail closed; diagnostics/recovery must not kill combat.
- Production fixes in GitHub.

## World2 retained while frozen
- D1 `136216144170036`, MaxRound6, PortalD exists.
- DestructibleObject/HitCount alone never proves progression; do not restore scenery attacks/far portal skipping.

## Next
1. Retest W1D1 V61.14.2 on fresh account: especially Round5->6; expect full smooth tween cross and no repeated R6 watchdog probes.
2. Then validate exact Fortify/Enchant mutation call protocol before conservative headless spending.
3. After equipment upgrades: Pet growth -> Honor/Glory -> shops -> Blessing.
