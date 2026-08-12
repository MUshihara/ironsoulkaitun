# Iron Soul Kaitun — START HERE

Read this, then `IRONSOUL_PROJECT_MEMORY.md`, then inspect current repo. Long changelog is optional.

## Non-negotiable
- 24/7 **fresh account -> end progression**.
- **Headless/API-first:** remotes/modules/server state; no normal mouse/GUI clicking.
- **World1 movement = fast smooth CFrame tween/floating, NOT Roblox walking.** Do not use `Humanoid:MoveTo`/`Humanoid:Move` for gate/portal traversal.
- Tween toward exact/current progression, dwell about **0.60s before final portal touch/cross**, and require authoritative evidence.
- Movement/crossed-plane/raw displacement alone is never progression proof.
- Preserve proven World1 combat/forge unless evidence requires change.
- Historical `combat.lua` is near Luau's local-register ceiling: substantial new logic belongs in external modules/wrappers or existing patches updated in place.
- Diagnostics are downloadable `.lua`; result/log files may be `.txt`.

## Fresh Lobby truth
- Lobby `117533937949084` is the progression brain.
- Fresh PlayerData may be ready while `LG_Level=nil`; real level is `PlayerData.LevelData.Level`.
- Handle this in preflight, not another lobby patch.

## Proven World1 loop
Fresh accounts have progressed repeatedly through World1 D1/D2/D3/D4/D5. V61.15 routing remains baseline; do not casually retune normal World1 combat/traversal.

## Cave baseline
- Cave1 Crystal `91584731222940`: Crystal Shards; Trial Lv10/P480; 1 Ticket1 observed.
- Cave2 Runes `119524374829397`: EnchantedStone/runes; Trial Lv13/P780.
- Cave3 Courtyard `132445869992129`: pet materials; Trial Lv13/P940.
- All are one-room Round1 activities; no Story door/portal traversal.
- `cave_chase.lua` V61.19 waits for combat-controller readiness before moving; this startup wait prevents pre-controller deaths.
- Cave2/Cave3 validated on mobile with same headless/CFrame path.
- One Cave settlement -> Lobby; no paid replay spam.

## Demand-driven SMART Cave V61.24
- Fixed stock buffers are retired from automatic spending.
- Upgrade planning runs **after Forge/EquipBest and safe upgrades**, before Story.
- Current order: Forge/EquipBest -> Blessing/Fortify -> Smart Enchant -> exact demand -> SMART Cave -> otherwise Story.
- **Cave1** only from real `CrystalShardsMissing` for guaranteed Blessing/Fortify demand.
- **Cave2** only when a useful +4 keeper still has an existing empty enchant slot AND Smart Enchant has zero usable stones. It does NOT use the old unreliable `3/4 runes` stock target.
- Cave1 has higher priority than Cave2 when both blockers exist because guaranteed Fortify is deterministic.
- **Cave3** held until pet-upgrade manager publishes exact material costs.
- Trial only; reserve 5 Ticket1; cooldown 360s.
- Decision log: `IronSoul_CavePlannerDecision_V61_24.txt`.

## Skill/combat baseline
- Skill Tree Level branches = Level + weapon proficiency; `skill_manager.lua` activates server-granted branches only.
- Weapon-aware V61.21 loadout uses validated `EquipSkill`/`CanEquipSkill`/`GetWeaponSkillId` path and passed.
- V61.22 fixed old skills-only BaseAttack regression. Latest Cave2 + World1 D5 both showed `BASIC_DRIVER | VERIFIED`.
- SkillU is charge-based; native game/server owns readiness. D5 produced real Ultimate casts.
- Treat combat/loadout/basic/Ultimate layer as stable unless new evidence appears.

## Blessing = internal Fortify system
- **Blessing is the in-game/player-facing name for the equipment upgrade system implemented internally as `Fortify` / `FortifyUtil`.**
- Do not create a separate Blessing module path unless future live evidence proves another mechanic.
- Crystal Shards/Flakes + Currency1 are used; success chance falls as Fortify level rises.

## V61.23 Blessing/Fortify — PRODUCTION PASS
Policy:
- auto only guaranteed steps through +4;
- primary Weapon -> equipped Armor -> Weapon2 only if >=80% primary power;
- reserve CrystalShards2 and Currency1 10000;
- max6 verified actions/Lobby.

Latest production proof at Lv20/P2603:
- `Single_Gray` +1 -> +4, power `484 -> 616`, all 3 steps verified.
- `HeavyBody_Monarch_T3` +1 -> +4, power `908 -> 1073`, all 3 verified.
- 6 actions, 0 failures.
- weak `Single_KnightSword` Weapon2 correctly skipped.
- shards `17 -> 3`.
- Helmet remained +1 and exact demand became CrystalShards Missing6 after reserve.
- SMART Cave selected Cave1 from that real blocker.

## V61.24 Enchant — LIVE MUTATION PASSED / PRODUCTION ENABLED
Exact verified server write:
`EquipmentRE:FireServer("Enchant", equipmentUUID, enchantSlotKey, enchantedStoneUUID)`.

Live controlled proof on `Single_Gray` +4:
- target slot1 was an existing empty enchant slot;
- selected `Burn_1` rarity2;
- `GetEnchantCost` returned 2400 Currency1;
- FireServer succeeded;
- slot verified populated with Burn fields;
- exact stone UUID consumed;
- Currency1 `69286 -> 66886` (-2400);
- official equipment power `616 -> 696` (+80);
- Result `ENCHANTED_VERIFIED`.

Production `systems/enchant_manager.lua` V61.24:
- runs after Blessing/Fortify;
- minimum keeper Fortify +4;
- active/primary weapon first, then strongest equipped Armor;
- secondary weapon only if competitive (>=80% active weapon power);
- existing empty enchant slots only;
- one enchant maximum/Lobby;
- preserve Currency1 10000;
- never overwrite/reroll/UnEnchant/use DetachTool;
- available stones ranked from live effect data (`DMG`, `Chance`, `Duration`, rarity) rather than old weakest-first validation policy;
- each mutation verified from installed slot + exact stone consumption;
- writes `EnchantEligibleEmptySlots`, `EnchantUsableStones`, `EnchantStoneMissing`, `Cave2Needed` into `IronSoul_UpgradeDemand_V61_23.txt`.
- log `IronSoul_EnchantManager_V61_24.txt`.

## Next phase
1. One normal production-loader cycle to verify V61.24 Smart Enchant + Cave1/Cave2 demand handoff.
2. Then pet growth (`PetsFortifyUtil` / `PetsUpgradeUtil`) + exact Cave3 demand.
3. Then smart shops/currency spending.
4. Endless Tower after core upgrade economy is stable.

## Settlement / replay
- Inventory maintenance threshold 85; full/high inventory at settlement -> Lobby immediately.
- Replay waits are short/bounded; stuck/full replay vote -> Lobby.

Repo is source of truth when chat memory conflicts.
