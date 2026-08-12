# Iron Soul Kaitun — START HERE

Read this, then `IRONSOUL_PROJECT_MEMORY.md`, then inspect current repo. Long changelog is optional.

## Non-negotiable
- 24/7 **fresh account -> end progression**.
- **Headless/API-first:** remotes/modules/server state; no normal mouse/GUI clicking.
- **World1 movement = fast smooth CFrame tween/floating, NOT Roblox walking.** Do not use `Humanoid:MoveTo`/`Humanoid:Move` for gate/portal traversal.
- Tween toward exact/current progression, dwell about **0.60s before final portal touch/cross**, and require authoritative evidence.
- Movement/crossed-plane/raw displacement alone is never progression proof.
- Preserve proven paths unless evidence requires change.
- Historical `combat.lua` is near Luau's local-register ceiling: substantial new logic belongs in external modules/wrappers or existing patches updated in place.
- Diagnostics are downloadable `.lua`; result/log files may be `.txt`.

## Fresh Lobby truth
- Lobby `117533937949084` is the progression brain.
- Fresh PlayerData may be ready while `LG_Level=nil`; real level is `PlayerData.LevelData.Level`.

## World1 — STABLE
Fresh accounts progressed repeatedly through World1 Normal D1-D5. V61.15 routing remains baseline; do not casually retune World1 traversal/combat.

## World2 — D1 VALIDATED
- PlaceId `136216144170036`.
- World2 was never disabled; only new World2-specific route-mapper intervention was frozen.
- Unattended D1 clear: settlement166.89s, GameRound6, 66 targets, 0 deaths, GateSuccess1/GateFail0, no watchdog failure, PortalsInvoked4.
- Existing combat/transition stack handled PortalD/gate/Portal sequence and SkillU/BaseAttack correctly.
- Keep route mapper discovery-only in W2 until D2+ gives actual failure evidence.
- Current Normal recommendations: W2 D2 Lv20/P5600, D3 Lv22/P8000, D4 Lv25/P14000, D5 Lv30/P22000.

## Cave baseline
- Cave1 `91584731222940`; Cave2 `119524374829397`; Cave3 `132445869992129`.
- All are one-room Round1 resource activities. No Story doors/portals.
- `cave_chase.lua` V61.19 waits for combat-controller readiness before moving; preserve this safety.
- Cave2/Cave3 mobile validated; one Cave clear -> Lobby.

## SMART Cave V61.26 — HIGHEST READY DIFFICULTY
`systems/cave_planner.lua` no longer hardcodes D1.
- For a demanded Cave, inspect live `ResWorldRound` Normal configs and choose the **highest server-unlocked difficulty whose RecPlayerLv/RecBattlePower the account meets** while preserving Ticket1 reserve5.
- Cooldown360s remains.
- Cave1 demand = exact Blessing/Fortify CrystalShards blocker.
- Cave2 demand = useful +4 keeper has empty enchant slot and zero usable Enchanted Stones.
- Cave3 first-pet demand = account owns **no pet and no egg**, and an egg-capable Cave3 **D2+** is ready.
- Priority: deterministic Fortify blocker > first-pet egg blocker > Enchant stone blocker.

Latest FirstEgg recon at Lv22/P4346 with Ticket1=33:
- Cave1 clear D1-D2 -> highest recommendation-ready Normal tier is **D3** (D4 requires P5200).
- Cave2 clear D1 -> highest ready **D2** (D3 requires P5400).
- Cave3 clear D1 -> highest ready **D2** (D3 requires P6480).
- Cave costs remain Ticket1 x1 across these Normal tiers, so paying for D1 when a stronger ready tier exists is wasteful.

### Cave3 egg truth
- D1 display rewards: pet-growth materials, **no egg**.
- D2/D3/D4 display `Random_Egg` plus increasingly advanced pet materials.
- Config uses egg loot tables (`LootTable24WithEgg/25WithEgg/26WithEgg`) containing concrete pet eggs including DragonIce/Eagle possibilities.
- Therefore Cave3 D2+ is a legitimate chance-based first-pet source.
- `ResMainTask.Main_Pet_001` separately defines a guaranteed `Pet_DragonIce_Egg|Egg|1`; automate this task reward when its normal progression condition is active, but do not fake/give it directly.

## Pet acquisition V61.25
`systems/pet_manager.lua` restores V20 claim/start/equip behavior:
- claim completed hatch and verify;
- read `PlayerData.PetHatch.Egg`;
- start highest-rarity owned egg in free slot via `StartHatch` and verify EggUUID;
- EquipBest after pet exists;
- no GUI/clicking/paid pet action; non-blocking.
Latest production state was correct `WAIT_EGG`: 0 pets, 0 eggs, 3 empty hatch slots.
Once an egg drops/arrives, V61.25 should start it automatically.

## Pet growth
- `PetsFortifyUtil` and `PetsUpgradeUtil` mapped.
- Pet Fortify costs use BrokenDragonScale -> WholeDragonScale -> DragonClaw -> DragonHorn/etc.
- Star1..9 Fortify caps 10/20/.../90.
- Exact live mutation is intentionally not enabled until an actual pet exists.
- After first pet: validate one growth mutation, then replace egg-only Cave3 demand with exact pet-material demand.

## Skill/combat baseline
- Level Skill branches = Level + weapon proficiency; activate only server-granted branches.
- V61.21 weapon-aware best loadout passed.
- V61.22 restored continuous headless BaseAttack and native charge-based SkillU; W1/W2/Cave show verified basics and real Ultimates.

## Blessing / Fortify
- Blessing is player-facing name; internal system = `Fortify`/`FortifyUtil`.
- V61.23 production auto-upgrades useful gear only through guaranteed +4, reserves 2 shards + Currency1 10000, verifies every mutation.
- First proof: Sword +1->+4 and breastplate +1->+4, 6/6 verified.

## Smart Enchant V61.24
- Exact write validated: `EquipmentRE:FireServer("Enchant", equipmentUUID, slotKey, stoneUUID)`.
- Keeper +4 minimum; existing empty slots only; one verified action/Lobby; no overwrite/UnEnchant.
- Controlled Burn test spent 2400 Currency1, consumed exact stone, power616->696.
- Cave2 demand is exact state, never old unreliable `3/4 runes` counting.

## Hell mode — NEXT, NOT YET PRODUCTION
Latest PlayerData has `Worlds.OpenHell=true`.
- Current historical Story planner explicitly filters `cfg.Style == "Normal"`, so Hell is **not currently selected**.
- FirstEgg recon can display World1 Diff6-D8 rewards with Hellstone1 and World2 higher diff rewards with Hell ores, strongly indicating useful Hell farming exists.
- Do not blindly hardcode Diff6 as Hell. Next diagnostic `IronSoul_Hell_Grocery_Recon_V61_27.lua` enumerates live non-Normal/Hell configs, recommendations, unlock state and rewards.
- Intended policy after proof: **advance Normal progression whenever ready; if next Normal stage is power-blocked, farm the highest safe unlocked Hell stage for better ores/power, then re-check Normal progression.**

## Grocery / shops — NEXT
Known API:
- Grocery = `ConsumableShopUtil` / `ScreenConsumableShop`.
- Utility exposes `GetShopConfig`, `GetShopData`, `GetShopSnapshot`, `GetAllShopConfigs`, `GetItemStock`, `BuyItem`, refresh helpers and RemoteEvent.
- Gold/Bond/Honor/Season shops also exist.
- Production buying is NOT enabled yet because exact current stock IDs, prices, currencies and `BuyItem` tuple have not been live-validated.
- Target architecture: upgrade manager publishes exact blocker -> shop manager checks stock/price/reserve -> buys and verifies if economical -> only then spend Cave ticket.
- V61.27 read-only recon maps this next.

## Current upgrade chain
`Forge/EquipBest -> Pet acquisition -> Blessing/Fortify -> Smart Enchant -> highest-ready SMART Cave -> Story`.

## Next phase
1. Run standalone `IronSoul_Hell_Grocery_Recon_V61_27.lua` in Lobby and inspect its txt.
2. Build smart Hell fallback + exact purpose-driven shop purchasing from that evidence.
3. Normal loader test V61.26 Cave highest-difficulty selection naturally.
4. After first pet: controlled pet-growth mutation -> exact Cave3 material demand -> Pet Expedition later.
5. Higher-risk Blessing +5+ only with explicit risk/value policy; Endless later.

## Settlement / replay
- Inventory maintenance threshold85; full/high inventory -> Lobby.
- Replay waits bounded; stuck/full replay -> Lobby.

Repo is source of truth when chat memory conflicts.
