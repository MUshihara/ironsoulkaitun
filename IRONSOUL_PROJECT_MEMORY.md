# Iron Soul Kaitun — Compact Project Memory

## Goal
24/7 automatic **fresh account -> end progression**. Headless/API-first, fast, low CPU/RAM. No normal clicking.

## Current focus
**World2 frozen. Keep Tutorial -> Lobby -> World1 -> Lobby stable, then expand Lobby upgrades.**

## Proven baseline
- Tutorial `76701861705540`; Lobby `117533937949084`; validated World1 dungeon `116456628154258`.
- Fresh account proved `Lobby -> W1 D1 -> settlement -> Lobby -> next run`.
- Normal World1 combat is strong; do not retune without evidence.
- Headless forge, EquipBest/smart cleanup, pet hatch/claim/equip validated.

## Fresh Lobby truth
- PlayerData can be ready while fresh `LG_Level=nil`.
- Authoritative fresh level is `PlayerData.LevelData.Level`.
- Resolve/mirror level in lobby preflight only; do not add another fresh-level patch.

## World1 movement/traversal — CRITICAL
- User wants **smooth fast CFrame tween/floating**, not Roblox walking and not hard instant snapping everywhere.
- Never use `Humanoid:MoveTo`/`Humanoid:Move` for normal World1 gate/portal traversal.
- Current helper `systems/world1_motion.lua`: ~210 studs/sec normal, ~260 long traversal; heartbeat CFrame interpolation.
- Exact gate/portal + prompt/touch/handshake + authoritative progression verification still required.
- Never generic RoundPortal RF; proven able to skip rooms/state.

Latest regression proof (2026-08-11):
- W1D1 reached GameRound4 after an already-open Round3 gate.
- Old `IronSoulCrossAlreadyOpenGate` used `Humanoid.MoveTo`, causing visible walking.
- Then player stalled ~90s at x=-339: old Round3 region dist 35.8, next Round4 enemies ~493 studs away.
- Exact next closed Round3 traversal gate was ~414 studs away.
- Old `selectDoorForCompletedRound` rejected it because regionDist > 80, so COMBAT staging never moved.

V61.14.1 fix:
- already-open gate recovery uses tween, not MoveTo;
- transition/watchdog World1 portal fallbacks use tween, not walking;
- empty COMBAT/traversal may accept a far gate ONLY when `row.RoundNum == GameRound-1`, bounded <=650 studs;
- tween to that gate, open normally, then tween through;
- normal GATE selection keeps the old tight region rule; historical/wrong-round gates remain rejected.

## Forge
- Lobby forge chain: V61.6 -> V61.7 reserve-best-ore -> V61.8 measured forge.
- Previously validated headless forge remains preserved; recent fresh runs simply did not hit forge threshold.

## Lobby mutation discovery
R2 snapshot: Level7/Power207, Currency1 13,837, SeasonCurrency1,000, ores61, no pets/stones.
- `FortifyUtil.Fortify` arity3.
- `EnchantmentUtil.Enchant` arity5; `UnEnchant` arity4.
- Pet growth, Honor, Season and shop modules/remotes confirmed live.
R3 found concrete system remotes (`EquipmentRE`, `ForgeRF`, `PetsRE`, Honor/Season/shop remotes) but GUI/current runtime did not expose the exact Fortify/Enchant outbound request tuple. Do not enable unattended mutation spending yet.

## Workflow rules
- Diagnostics are standalone downloadable `.lua`; result/log files may be `.txt` in ZIPs.
- Helpers fail closed; diagnostics/recovery must not kill combat.
- Production fixes in GitHub.

## World2 retained while frozen
- D1 `136216144170036`, MaxRound6, PortalD exists.
- DestructibleObject/HitCount alone never proves progression; do not restore scenery attacks/far portal skipping.

## Next
1. Retest W1D1 V61.14.1: confirm visible smooth tween/floating, no `OPEN_GATE_CROSS` walking, and the ~414-stud traversal case no longer stalls.
2. Then validate exact Fortify/Enchant mutation call protocol before enabling conservative headless spending.
3. After equipment upgrades: Pet growth -> Honor/Glory -> shops -> Blessing.
