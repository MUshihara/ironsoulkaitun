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

## Fresh Lobby recon — critical facts
Recon `FULL_LOBBY_RECON_R1` on a fresh account proved:
- `DataUtil:GetPlayerData(Player)` already returned a table.
- `Loaded=true`.
- `LG_PowerNew1=110`.
- **`LG_Level=nil` stayed nil throughout the full watch.**
- Authoritative level exists at `PlayerData.LevelData.Level=1`, `XP=0`.
- Starter equipment: only `Single_BroadSword`, Fortify 1.
- Pets owned/equipped: empty.
- World clears/unlocks: empty.
- Current main guide/task: `Main_001`.
- SeasonTicket=1; other early currencies mostly 0.

Therefore never gate fresh lobby readiness on `LG_Level` alone. Current V61.13.1 lobby uses PlayerData level fallback both in preflight and the proven lobby body.

## Recon-exposed systems worth learning later
- Equipment: `FortifyUtil.Fortify`, `EnchantmentUtil.CreateEnchantmentSlot/GetEquippedEnchantments`.
- Pets: `PetsUtil`, `PetsHatchUtil`, `PetsFortifyUtil`, `PetsUpgradeUtil`.
- Honor: `HonorLotteryUtil`, HonorStore.
- Season: SeasonUtil / SeasonLotteryUtil / Season shop data.
- Shops: ConsumableShopUtil, GoldShop/BondShop state.
- Tasks/dailies: TaskUtil, DailyQuestUtil, SevenDailyUtil, DailyLoginUtil.
- Skills/attributes: SkillTreeUtil, AttributeUpgradeUtil.
These names/APIs are discovery evidence, not permission to spend blindly. Validate action protocol + spending rule before enabling 24/7 mutations.

## Headless rules
- APIs/remotes/modules/server state first.
- Fast only when authoritative progression remains correct.
- For portals, direct RoundPortal RF is NOT a generic shortcut; proven able to skip rooms/state.
- Helpers fail closed and must never kill combat.
- Diagnostics are standalone downloadable **`.lua`** files from chat; outputs/logs may be `.txt` inside ZIPs.

## World2 facts retained while frozen
- D1 `136216144170036`, MaxRound 6, PortalD exists.
- Many props have DestructibleObject/HitCount; that alone never proves progression.
- Do not restore random scenery attacks or far/learned portal skipping.

## Next verification
Use the same normal loader on the fresh account. Confirm V61.13.1 resolves **Lv1 via `PlayerData.LevelData.Level`**, enters lobby logic, performs only already-proven safe maintenance, launches the first valid World1 story run, and returns to Lobby. Send the normal logs afterward. Only then expand Fortify/Enchant/Pet growth/Honor/shops one subsystem at a time from evidence.
