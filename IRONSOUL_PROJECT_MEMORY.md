# Iron Soul Kaitun — Compact Project Memory

## Goal
24/7 automatic **fresh account -> end progression**. Headless/API-first, fast, low CPU/RAM. No normal clicking.

## Stable foundation
- Tutorial `76701861705540`; Lobby `117533937949084`.
- World1 V61.15 routing stable/frozen through Normal D5.
- World1 traversal = smooth fast CFrame tween/floating, never Humanoid walking.
- Historical combat near Luau local-register ceiling; substantial new behavior stays external.
- Fresh Lobby uses `PlayerData.LevelData.Level` if `LG_Level` is nil.

## World2
- PlaceId `136216144170036`.
- W2 D1 validated unattended: settlement166.89s, GameRound6, 66 targets, 0 deaths, GateSuccess1/GateFail0, watchdog0, PortalsInvoked4; BasicAttack verified + real SkillU.
- Current route mapper remains discovery-only in World2; preserve successful existing transition stack.
- Normal recs: D1 17/3600; D2 20/5600; D3 22/8000; D4 25/14000; D5 30/22000.
- Latest FirstEgg account Lv22/P4346 has W2 D1 cleared repeatedly but is still power-blocked from D2 recommendation.

## Cave combat baseline
- Cave1 `91584731222940`; Cave2 `119524374829397`; Cave3 `132445869992129`.
- One-room Round1; no Story doors/portals.
- V61.19 chase waits for combat-controller readiness, then handles far enemies; mobile validated.
- One Cave run -> Lobby; reserve5 Ticket1; cooldown360s.

## SMART Cave V61.26 — HIGHEST READY NORMAL TIER
Production `systems/cave_planner.lua` commit `25a52ac4dda343bb9461e7f7915696aaa06fe212`.
- Removed hardcoded D1.
- For each demanded Cave, inspect live `ResWorldRound` configs with `Style==Normal`; choose highest server-unlocked diff meeting current RecPlayerLv/RecBattlePower and ticket reserve.
- Cave1 demand = exact Blessing/Fortify `CrystalShardsMissing`.
- Cave2 demand = exact Enchant empty-keeper-slot + no-stone blocker.
- Cave3 first-pet demand = zero owned pets AND zero owned eggs AND an egg-capable ready D2+ exists.
- Priority remains deterministic Fortify > first-pet egg > Enchant.

Normal Cave recommendations:
- Cave1 D1 10/480; D2 15/1300; D3 20/3400; D4 22/5200; D5 28/12000.
- Cave2 D1 13/780; D2 16/2400; D3 22/5400; D4 25/8000.
- Cave3 D1 13/940; D2 16/2880; D3 22/6480; D4 25/9600.
- Each observed Normal Cave tier costs Ticket1 x1.

Latest account Lv22/P4346/Ticket33:
- Cave1 D1-D2 clear -> highest ready D3.
- Cave2 D1 clear -> highest ready D2.
- Cave3 D1 clear -> highest ready D2.

## First egg truth — V61.26 recon
Latest uploaded FirstEgg recon:
- Pets.Owned0, Pets.Equipped0, PetHatch.Egg0, 3 hatch slots.
- Guidebook.InitPet=Inited but Guidebook.Pet empty.
- Worlds.OpenHell=true.

### Cave3 egg source CONFIRMED
World display/config:
- Cave3 D1: WholeDragonScale/DragonClaw/BrokenDragonScale family, **no egg**.
- Cave3 D2: `Random_Egg` + DragonHorn/DragonClaw/WholeDragonScale.
- Cave3 D3: `Random_Egg` + DragonTear/DragonHorn/DragonClaw.
- Cave3 D4: `Random_Egg` + DragonTear/DragonHorn.
- Config `ResWorldRound[32/33/34]` uses `LootTable24WithEgg/25WithEgg/26WithEgg`.
- Reward loot tables contain concrete pet eggs including `Pet_DragonIce_Egg` and `Pet_Eagle_Egg` possibilities.
Therefore D2+ is legitimate chance-based first-pet farming and D1 must never be used for an egg blocker.

### Guaranteed task egg also exists
`ResMainTask.Main_Pet_001`:
- `ActionParam2=EquipmentForgeNpcPetEgg1|1`
- `Reward=Pet_DragonIce_Egg|Egg|1`
Current CurGuides did not include Main_Pet_001. When its normal progression condition becomes active, prefer/claim this legitimate guaranteed egg; never call client `GiveEgg` to fabricate it.

### Expedition later
`ResPetsExpeditionSlot` exposes `Random_Egg` loot tables, but expedition requires pets and is not the first-pet solution.

## Pet acquisition V61.25
`systems/pet_manager.lua` restored old validated hatch bridge:
- claim completed hatch via `Claim` + verify;
- read eggs from `PlayerData.PetHatch.Egg`;
- start highest-rarity egg in free slot via `StartHatch` + verify EggUUID;
- EquipBest after pet exists;
- no GUI/click/no paid action; non-blocking.
Latest production state correctly `WAIT_EGG`.

## Pet growth
- `PetsFortifyUtil` / `PetsUpgradeUtil` mapped.
- Star1..9 Fortify max 10/20/.../90.
- Costs use BrokenDragonScale -> WholeDragonScale -> DragonClaw -> DragonHorn/etc.
- No mutation enabled until actual pet exists. After first pet, validate one mutation then publish exact Cave3 material demand.

## Skills/combat
- Level Skill activation server-granted only.
- V61.21 weapon-aware best loadout passed.
- V61.22 fixed skills-only regression; BaseAttack + native charge-based SkillU verified in Cave/W1/W2.

## Blessing/Fortify V61.23
Blessing is player-facing name; internal API = Fortify.
- auto only guaranteed +2/+3/+4;
- primary weapon -> armor -> competitive Weapon2;
- reserve2 CrystalShards + Currency1 10000; max6 verified actions/Lobby.
- First production pass 6/6 verified; dynamic demand recalculates after Forge replacements.

## Smart Enchant V61.24
- Exact live write validated: `EquipmentRE:FireServer("Enchant", equipmentUUID, slotKey, stoneUUID)`.
- +4 keeper minimum, existing empty slot only, one action/Lobby, reserve Currency1 10000, no overwrite/UnEnchant.
- Burn controlled proof: Currency -2400, power616->696, stone consumed.
- Cave2 demand is exact state, not old rune-count buffer.

## Hell mode — OPEN BUT NOT YET PRODUCTION
Latest PlayerData: `Worlds.OpenHell=true`.
- Historical Story planner currently filters `cfg.Style=="Normal"`, so Hell is not selected.
- FirstEgg reward recon can read World1 D6-D8 with Hellstone1 plus ores and World2 higher diffs with Hell-related ores; good evidence Hell can be a better farm.
- Exact live non-Normal/Hell `Style`, RecPlayerLv/RecBattlePower, unlock state still needs one clean dump before production.
- Intended smart policy: **Normal progression first whenever ready; when the next Normal stage is power-blocked, farm highest safe unlocked Hell config, then re-check Normal.** Never let Hell prevent Normal D2-D5 unlock progression.
- Diagnostic created: `/mnt/data/IronSoul_Hell_Grocery_Recon_V61_27.lua`.

## Grocery / shops — MAPPED API, SPENDING NOT YET VALIDATED
Known Grocery API `ConsumableShopUtil`:
- RemoteEvent;
- `GetShopConfig`, `GetShopData`, `GetShopSnapshot`, `GetAllShopConfigs`, `GetItemStock`, `BuyItem`, refresh helpers.
- Gold/Bond/Honor/Season shops also exist.
- Exact current stock IDs/prices/currencies and live `BuyItem` tuple still not validated; do not auto-spend yet.
- V61.27 diagnostic maps Hell + Grocery/shop surfaces together, read-only.

Target shop architecture:
`exact upgrade blocker -> check shop current stock/price -> buy if useful and reserves remain -> verify -> recalc blocker -> only then spend Cave ticket`.
Potential secondary buff policy later: EXP while leveling, Attack/Berserk for power walls, Life for survival walls, Harvest/material buff for dedicated farming, but only after exact shop data proves IDs/effects/costs.

## Current chain
`Forge/EquipBest -> Pet acquisition -> Blessing/Fortify -> Smart Enchant -> highest-ready SMART Cave -> Normal Story`.

## Next work
1. Run standalone V61.27 Hell+Grocery recon in Lobby.
2. Build smart Hell fallback + purpose-driven Shop manager from exact config/tuple evidence.
3. Let V61.26 Cave difficulty resolver run naturally in normal loader and verify selected D3/D2 tiers.
4. First pet -> controlled growth mutation -> exact Cave3 pet-material demand; then pet expedition.
5. Higher-risk Blessing +5+ only with explicit risk/value policy; Endless later.
