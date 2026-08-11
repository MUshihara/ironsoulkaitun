# Iron Soul Kaitun — Compact Project Memory

## Goal
24/7 automatic **fresh account -> end progression**. Headless/API-first, fast, low CPU/RAM. No normal clicking.

## Current focus
**World2 frozen. Rebuild/verify Tutorial -> Lobby -> World1 -> Lobby.** Lobby is the progression brain.

## Proven baseline
- Tutorial `76701861705540`; starter Sword index 1.
- Lobby `117533937949084`.
- Validated World1 dungeon `116456628154258`.
- V55.2 World1: settlement, 128 targets, 5 transitions, 0 deaths, headless remote attack, no mouse basic.
- V58 W1D2: Lv10/P341 -> Lobby Lv11/P355.
- Normal combat is strong; do not retune without evidence.
- Headless forge, EquipBest/smart cleanup, pet hatch/claim/equip are validated.
- Pet Fortify/StarUp/SkillUp was mapped; spend only when mats/dupes justify it.
- Task/daily pieces, Sword skills, attributes and Season/Lottery pieces were previously validated.

## Fresh Lobby truth
Fresh recon proved:
- `DataUtil:GetPlayerData(Player)` can be ready with `Loaded=true` and `LG_PowerNew1` while `LG_Level=nil` permanently.
- Real fresh level is `PlayerData.LevelData.Level` (observed Level 1).
- Never require `LG_Level` alone.
- V61.13.2 preflight resolves PlayerData level, then locally mirrors verified level to `LG_Level` only for compatibility with the older proven lobby body. Do not create another fresh-level lobby patch.

## FIRST CLEAN FRESH-ACCOUNT 24/7 CYCLE — 2026-08-11
Fresh account successfully completed:
`Lobby -> World1 D1 -> settlement -> Lobby -> launch next World1 run`.
Evidence:
- first battle elapsed 176.89s;
- 157 targets;
- GateSuccess 5 / GateFail 0;
- WatchdogStarts 0;
- deaths 0;
- PlayerHits 1 / PlayerDamage 4;
- all 5 transitions `NEW_REGION_FAST`;
- settlement reached;
- return Lobby readiness passed in 3.40s at Level 3 / Power 138;
- next planner decision `REPEAT_STORY`, World1 D1, then second dungeon launched.
`REPEAT_STORY` is intentional when next Story exists but account is below its recommended Level/Power; do not force advance.

## Forge status
- Active lobby chain remains V61.6 -> V61.7 reserve-best-ore -> V61.8 forge metrics.
- First clean fresh cycle did NOT trigger smart-forge maintenance (no forge history/status file), so it is not a new forge validation.
- Previously validated headless forge remains preserved; do not retune unless a real forge run fails.

## Recon-exposed systems worth learning next
- Equipment: `FortifyUtil.Fortify`, `EnchantmentUtil.Enchant/UnEnchant/GetEnchantCost/GetEquippedEnchantments`.
- Pets: `PetsUtil`, `PetsHatchUtil`, `PetsFortifyUtil`, `PetsUpgradeUtil`.
- Honor: `HonorLotteryUtil`, HonorStore.
- Season: SeasonUtil / SeasonLotteryUtil / Season shop data.
- Shops: ConsumableShopUtil, GoldShop/BondShop state.
- Tasks/dailies: TaskUtil, DailyQuestUtil, SevenDailyUtil, DailyLoginUtil.
- Skills/attributes: SkillTreeUtil, AttributeUpgradeUtil.
These APIs are discovery evidence, not permission to spend blindly. Validate protocol + spending rule before enabling 24/7 mutations.

## Headless rules
- APIs/remotes/modules/server state first.
- Fast only when authoritative progression remains correct.
- For portals, direct RoundPortal RF is NOT a generic shortcut; proven able to skip rooms/state.
- Helpers fail closed and must never kill combat.
- Diagnostics are standalone downloadable **`.lua`** files from chat; outputs/logs may be `.txt` inside ZIPs.

## World2 retained while frozen
- D1 `136216144170036`, MaxRound 6, PortalD exists.
- Many props have DestructibleObject/HitCount; that alone never proves progression.
- Do not restore random scenery attacks or far/learned portal skipping.

## Next
Keep current World1 loop untouched. Deep-map lobby mutation protocols/costs for **Equipment Fortify + Enchant first**, then add only conservative, evidence-backed spending. After that: Pet growth -> Honor/Glory -> shops -> Blessing.
