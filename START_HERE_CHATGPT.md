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

## V61.23 demand-driven SMART Cave — PASSED FOR CAVE1
- Fixed stock buffers are retired from automatic spending.
- Upgrade planning runs **after Forge/EquipBest and safe upgrades**, before Story.
- Current chain: Forge/EquipBest -> Fortify/Blessing -> exact demand -> SMART Cave -> otherwise Story.
- Cave1 is selected only from real `CrystalShardsMissing`.
- Automatic Cave2 is held until Enchant publishes exact stone demand; old EnchantedStone table-entry counting was unreliable.
- Automatic Cave3 held until pet-upgrade manager publishes exact costs.
- Trial only; reserve 5 Ticket1; cooldown 360s.

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

## V61.23 Fortify/Blessing — PRODUCTION PASS
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
- Helmet remained +1 and exact demand became: CrystalFlake4 have23, CrystalShards7 have3 with reserve2 => **Missing6**, Currency1 7800 have69286 => enough.
- SMART Cave then selected **Cave1** with `FortifyCrystalMissing=6` and Ticket1=26.
- This proves **upgrade -> blocker -> correct material Cave** end-to-end.

## Enchant — CURRENT NEXT TEST V61.24
Recovered older V17/V18 protocol:
- write: `EquipmentRE:FireServer("Enchant", equipmentUUID, enchantSlotKey, enchantedStoneUUID)`.
- target must have an existing empty `Enchantments[slot]` table (`Type == nil`).
- stone must exist in `PlayerData.EnchantedStone.Owned`.
- cost: `EnchantmentUtil:GetEnchantCost(equipmentRarity, stoneRarity)`; recovered formula gearRarity * stoneRarity * 200 Currency1.
- success consumes stone and fills slot.
- do NOT auto-UnEnchant; DetachTool consumption/stone restoration are not safe enough.
- No trustworthy historical live mutation report was found, so do one controlled validation before 24/7 integration.

User has standalone `IronSoul_Enchant_Controlled_V61_24.lua`:
- run in Lobby, no normal loader required;
- equipped Fortify>=4 keeper only;
- primary Weapon first, then Armor; skips Weapon2;
- requires existing empty slot;
- lowest-rarity stone first for this first irreversible test;
- Currency1 reserve10000;
- one action maximum;
- verifies installed slot + exact stone UUID consumed;
- output `IronSoul_EnchantControlled_V61_24.txt`.

If V61.24 passes: build production smart Enchant scorer/demand publisher and re-enable Cave2 based on exact Enchant need, then pet upgrades/Cave3, then smart shops.

## Settlement / replay
- Inventory maintenance threshold 85; full/high inventory at settlement -> Lobby immediately.
- Replay waits are short/bounded; stuck/full replay vote -> Lobby.

Repo is source of truth when chat memory conflicts.
