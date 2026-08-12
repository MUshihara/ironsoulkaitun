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
- Latest account Lv22/P4346 has W2 D1 cleared but is power-blocked from D2.

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
- Priority: deterministic Fortify > first-pet egg > Enchant.

Normal Cave recommendations:
- Cave1 D1 10/480; D2 15/1300; D3 20/3400; D4 22/5200; D5 28/12000.
- Cave2 D1 13/780; D2 16/2400; D3 22/5400; D4 25/8000.
- Cave3 D1 13/940; D2 16/2880; D3 22/6480; D4 25/9600.
- Each observed Normal Cave tier costs Ticket1 x1.

Latest account Lv22/P4346/Ticket33:
- Cave1 highest ready D3.
- Cave2 highest ready D2.
- Cave3 highest ready D2.

## First egg truth
- Cave3 D1 has pet-growth materials but no egg.
- Cave3 D2/D3/D4 have `Random_Egg` plus increasingly advanced pet materials.
- `LootTable24WithEgg/25WithEgg/26WithEgg` contain concrete eggs including DragonIce/Eagle possibilities.
- `ResMainTask.Main_Pet_001` separately rewards guaranteed `Pet_DragonIce_Egg|Egg|1`; claim only when legitimately active.
- Expedition can later produce Random_Egg but requires a pet first.

## Pet acquisition V61.25
`systems/pet_manager.lua`:
- claim completed hatch + verify;
- read owned eggs from `PlayerData.PetHatch.Egg`;
- start highest-rarity egg in free slot via `StartHatch` + verify EggUUID;
- EquipBest after pet exists;
- no GUI/click/paid pet action; non-blocking.
Latest state correctly `WAIT_EGG`.

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
- Blessing player-facing; internal API Fortify.
- auto guaranteed +2/+3/+4 only;
- primary weapon -> armor -> competitive Weapon2;
- reserve2 CrystalShards + Currency1 10000; max6 verified actions/Lobby.
- First production pass 6/6 verified.

## Smart Enchant V61.24
- Exact write: `EquipmentRE:FireServer("Enchant", equipmentUUID, slotKey, stoneUUID)`.
- +4 keeper minimum, existing empty slot only, one action/Lobby, reserve Currency1 10000, no overwrite/UnEnchant.
- Burn proof: Currency -2400, power616->696, exact stone consumed.

## Smart Hell V61.28 — ENABLED, FIRST LIVE CLEAR PENDING
Live V61.27 recon proved:
- `PlayerData.Worlds.OpenHell=true`.
- 20 Hell configs across World1-World4.
- World1 Hell D6-D10 unlocked on latest account.
- World2 Hell D6 unlocked; D7+ locked until further W2 Normal clears.
- Hell configs have `RecPlayerLv` but blank `RecBattlePower`.

Production:
- `systems/hell_planner.lua` commit `c0c17769225dc2d356e0de58f5272ae2cbb9c834`.
- `systems/upgrade_preflight.lua` integration commit `98391fc0e67ba88be73a6aa050bac7f961d2d198`.
- Policy: ready Normal progression always wins. If next Normal stage is blocked and no Cave action handled the cycle, choose highest safe server-unlocked Hell in supported World1/World2.
- Power safety: corresponding Normal difficulty `(HellDiff-5)` RecBattlePower ×1.15. This is a conservative proxy because Hell RecPower is absent; do not invent a Hell power requirement.
- Latest account Lv22/P4346 should choose W2 Hell D6. Proxy W2 Normal D1 P3600 -> safe4140; account passes.
- W2 Hell D6 rewards: Hellstone3, Hellstone2, Hexbane, Bloodshard, Verdanite.
- Mark stable only after first clean unattended Hell clear.

## Grocery / shops — ROTATIONS + ECONOMY PROVEN; PURCHASE PROTOCOL PENDING
V61.27 recon:
- `ConsumableShopUtil` owns `Gold` and `Bond` configs and a RemoteEvent.
- Gold: Currency1, 10 items/refresh, refresh every5 min, max15 daily purchases.
- Bond: BondCoin, 10 items/day, max5 daily purchases.
- PlayerData has `GoldShop.StockLimit`, `BuyCount`, refresh timer, daily purchase count.

Gold config useful items:
- `GoldShop_17`: CrystalShards x3 for 1000.
- `GoldShop_18..21`: Burn_3/Methysis_3/Frost_3/Corrode_3 x1 for3000.
- `GoldShop_29`: BrokenDragonScale x5 for1000.
- `GoldShop_30`: WholeDragonScale x5 for2000.
- `GoldShop_31`: DragonClaw x5 for3500.
- `GoldShop_32`: DragonHorn x5 for5000.
- `GoldShop_33`: DragonTear x5 for7500.
- Potions include Gold/EXP/Luck/Drop/Atk/HP/CH.
- Gold shop also sells useful Hell ores.

Latest Gold rotation at V61.27:
`GoldShop_05,06,14,15,16,21,22,26,29,33` = Hellstone3, Earthmaw, CrystalGem, CrystalPrism, CrystalFlake, Corrode_3, GoldPotion, AtkPotion, BrokenDragonScale, DragonTear.

Season shop config can rotate Ticket1, Hellstone8, crystals, DragonTear, scrolls and potions. Latest normal rotation IDs: 08,16,20,07,15,21; special01. Latest SeasonCurrency=500.

Do NOT auto-buy yet:
- `ConsumableShopUtil.BuyItem` exists (argc4), but exact client argument tuple/call site was not proven by V61.27.
- Focused read-only diagnostic created: `IronSoul_Shop_Protocol_Recon_V61_29.lua`.
- Target flow after proof: exact blocker -> current stock -> price/reserve -> buy once -> authoritative inventory/currency verification -> recalc blocker -> only then Cave ticket.

## Current chain
`Forge/EquipBest -> Pet acquisition -> Blessing/Fortify -> Smart Enchant -> highest-ready SMART Cave -> Smart Hell fallback if Normal blocked -> Normal Story`.

## Next work
1. Normal loader: validate first W2 Hell D6 unattended clear; if failure, use logs rather than retune blindly.
2. Run `IronSoul_Shop_Protocol_Recon_V61_29.lua` in Lobby; implement purpose-driven verified Grocery buying before Cave from exact tuple evidence.
3. Verify V61.26 Cave chooses D3/D2 naturally.
4. First pet -> one controlled growth mutation -> exact Cave3 demand; then Pet Expedition.
5. Higher-risk Blessing +5+ only with explicit risk/value policy; Endless later.
