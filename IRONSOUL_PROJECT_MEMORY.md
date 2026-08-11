# Iron Soul Kaitun — Compact Project Memory

## Goal
24/7 automatic **fresh account -> end progression**. Headless/API-first, fast, low CPU/RAM. No normal clicking.

## Current focus
**World2 frozen. Keep Tutorial -> Lobby -> World1 -> Lobby stable, then expand Lobby upgrades.**

## Proven baseline
- Tutorial `76701861705540`; starter Sword index 1.
- Lobby `117533937949084`.
- Validated World1 dungeon `116456628154258`.
- Fresh account clean cycle proved: `Lobby -> W1 D1 -> settlement -> Lobby -> next W1 run`.
- First clean battle: 176.89s, 157 targets, Gate 5/5, watchdog 0, deaths 0, damage taken 4.
- Later same log set contained 4 clean W1 D1 settlements: 176.89s / 132.13s / 140.15s / 131.39s. Only one run needed one bounded watchdog recovery; all settled.
- Normal combat is strong; do not retune without evidence.
- Headless forge, EquipBest/smart cleanup, pet hatch/claim/equip are validated.

## Fresh Lobby truth
- PlayerData may be ready with `Loaded=true` while `LG_Level=nil` on a fresh account.
- Authoritative fresh level is `PlayerData.LevelData.Level`.
- V61.13.2+ resolves PlayerData level in preflight and may locally mirror it only for compatibility with the proven historical lobby body.
- Do not create another fresh-level lobby patch.

## World1 transition policy — IMPORTANT USER REQUIREMENT
- **Do not visibly walk to/through portals or gates.**
- Prefer teleport/CFrame pre-position to the exact valid current transition, exact touch/handshake, then progression verification.
- Do not use `Humanoid:MoveTo`/guided walking as World1 portal fallback.
- Current V61.13.3 combat entry routes transition dependencies through `transition_nowalk.lua` and `transition_watchdog_nowalk.lua`; the combat patch chain itself is unchanged.
- Normal `DOOR_FAST_REGION` gate logic remains preserved; wrappers only intercept walking fallbacks.
- Never generically force RoundPortal RF; it previously skipped valid rooms/state.

## Forge status
- Active lobby chain remains V61.6 -> V61.7 reserve-best-ore -> V61.8 measured forge.
- Recent fresh-account logs did not hit the smart-forge threshold, so they were not a new forge validation.
- Previously validated headless forge remains preserved; do not retune unless an actual forge run fails.

## Lobby upgrade protocol recon R2 — 2026-08-11
Snapshot: Lobby, Level 7 / Power 207, Currency1 13,837, SeasonCurrency 1,000, 61 ores (Sandstone42/Pyrite12/Obsidian7), no pets, no enchanted stones, starter BroadSword Fortify1.
Discovered:
- `FortifyUtil.Fortify`: 3 args; `GetFortifyDef`: 3 args.
- `EnchantmentUtil.Enchant`: 5 args; `UnEnchant`: 4 args; cost/equipped-enchantment APIs present.
- Equipment fortify cost/config tables fully captured (`ResFortifyCost`, etc.).
- Pet growth live modules: `PetsFortifyUtil`, `PetsUpgradeUtil`; shared `PetsRE` exposed.
- Honor: `HonorLotteryUtil`, `HonorStoreUtil`; Honor remote exposed.
- Season: `SeasonUtil`, `SeasonLotteryUtil`; Season remote exposed.
- Shops: `ConsumableShopUtil`; GoldShop/BondShop PlayerData/config surfaces exist.
Do NOT enable unattended spending from names/arity alone. Validate the actual client->server action protocol and conservative spending policy first.

## Headless rules
- APIs/remotes/modules/server state first.
- Fast only when authoritative progression remains correct.
- Helpers fail closed and must never kill combat.
- Diagnostics are standalone downloadable **`.lua`** files from chat; result/log files may be `.txt` in ZIPs.

## World2 retained while frozen
- D1 `136216144170036`, MaxRound 6, PortalD exists.
- Many props have DestructibleObject/HitCount; that alone never proves progression.
- Do not restore random scenery attacks or far/learned portal skipping.

## Next
1. Retest World1 once with V61.13.3 and confirm no visible portal walking / no transition regression.
2. Continue deep mapping of **Equipment Fortify + Enchant client->server protocol**; then add conservative headless spending.
3. After equipment upgrades: Pet growth -> Honor/Glory -> shops -> Blessing.
