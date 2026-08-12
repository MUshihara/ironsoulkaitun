# Iron Soul Kaitun — Compact Project Memory

## Goal
24/7 automatic **fresh account -> end progression**. Headless/API-first, fast, low CPU/RAM. No normal clicking.

## Stable foundation
- Tutorial `76701861705540`; Lobby `117533937949084`.
- World1 V61.15 routing stable/frozen after repeated fresh-account clears through D5.
- World1 movement = smooth fast CFrame tween/floating, never Humanoid walking for traversal.
- `dungeon_route_mapper.lua` owns Story routing; raw movement/crossed-plane is never progression proof.
- Headless Forge, EquipBest/smart cleanup, pet hatch/claim/equip validated.
- Latest measured Forge proof: ores `93/100 -> 28/100`, 9 crafts, Power `755 -> 1197` (+442).
- Fresh Lobby: `PlayerData.LevelData.Level` authoritative if `LG_Level` nil; mirror only in preflight.

## Cave — STABLE MOBILE BASELINE
- Cave1 Crystal `91584731222940`: Crystal Shards; Trial Lv10/P480; 1 Ticket1 observed.
- Cave2 Runes `119524374829397`: Enchant/rune materials; Trial Lv13/P780.
- Cave3 Courtyard `132445869992129`: pet materials; Trial Lv13/P940.
- All are one-room Round1. `cave_chase.lua` V61.19 waits for combat-controller readiness before moving, then handles far enemies.
- Latest Cave2 V61.22: BASIC_DRIVER verified, 36 targets, 0 deaths. Perceived startup delay is mostly safe combat-controller load/patch time, not slow enemy detection.
- One Cave run -> Lobby; no paid replay spam.

## V61.23 SMART Cave — DEMAND DRIVEN
- Old automatic fixed buffers `Crystal18 / runes4 / scale28` are retired.
- Cave planning moved from early Lobby preflight to **after Forge/EquipBest + bag gate + safe upgrades**, immediately before Story planner.
- `systems/upgrade_preflight.lua`: safe Fortify/Blessing -> exact demand -> SMART Cave -> otherwise Story.
- `systems/cave_planner.lua` V61.23 currently auto-selects only Cave1 when `IronSoul_UpgradeDemand_V61_23.txt` reports real `CrystalShardsMissing > 0`.
- Automatic Cave2 is temporarily held because old `count(EnchantedStone.Owned)` reward measurement proved unreliable after live clears; re-enable only when Enchant manager publishes exact stone demand.
- Automatic Cave3 held until pet-upgrade manager publishes exact costs.
- Trial only; reserve 5 Ticket1; cooldown 360s retained.

## Skill Tree V61.20.1 — PASSED
- Level Skill unlock path = Level + weapon proficiency. No validated ore/crystal/currency payment.
- Server populates `PlayerData.SkillTree.Unlock`.
- `skill_manager.lua` activates only server-granted branches and verifies Active.
- Latest test: 9 server-unlocked branches, 5 newly activated, 4 already active, 0 failed.

## Weapon-aware loadout V61.21 — PASSED
- Exact write: `WeaponUtil.RemoteEvent:FireServer("EquipSkill", weaponId, slot, skillId)`.
- Validate with `CanEquipSkill`; verify with `GetWeaponSkillId`.
- `skill_loadout_manager.lua` follows the actually equipped weapon and scores live skill data.
- Latest D4: Sword loadout Skill1/Skill2/SkillU all server-verified, Failed=0.

## V61.22 BASIC ATTACK + ULTIMATE — VALIDATED
- Old BaseAttack one-shot calibration could be contaminated by a skill action window and permanently enter `HEADLESS_FAILED`, causing skills-only combat.
- Fix updated existing `combat_v61_8_skill_telemetry.patch` in place.
- UNTESTED BaseAttack now calibrates first with a clean four-step direct combo; one uncertain sample no longer disables basics. NO Mouse1 fallback.
- SkillU is charge-based; normal/basic attacks generate charge, Ultimate consumes it. Native callback/server remains authoritative.
- Latest Cave2 and World1 D5 logs both show `BASIC_DRIVER | VERIFIED`; D5 also shows real SkillU casts and settlement.

## Blessing / Fortify terminology — CORRECTED
- **Blessing is the player-facing/in-game name for the same equipment upgrade system implemented internally as `Fortify` / `FortifyUtil`.**
- Do not search for or design a separate Blessing system unless future live evidence proves an additional distinct mechanic.
- Crystal Shards/Crystal Flakes + Currency1 are Fortify/Blessing materials; success chance decreases at higher Fortify levels.

## V61.23 SAFE FORTIFY/BLESSING — PRODUCTION PASS
Standalone demand scan at Lobby Lv20 / Power2603 showed:
- Breastplate `HeavyBody_Monarch_T3`: Power908, Fortify1, rarity4.
- Helmet `LightHead_Monarch_T3`: Power576, Fortify1, rarity6.
- primary Weapon `Single_Gray`: Power484, Fortify1, rarity6.
- Weapon2 `Single_KnightSword`: Power108, Fortify1, rarity2.
- live +2/+3/+4 all PR=100.

Production test after normal loader PASSED:
- `Single_Gray` Fortify1 -> 2 -> 3 -> 4, all three verified.
- primary weapon power `484 -> 528 -> 576 -> 616`.
- `HeavyBody_Monarch_T3` Fortify1 -> 2 -> 3 -> 4, all three verified.
- breastplate power `908 -> 989 -> 1031 -> 1073`.
- 6 actions total, **0 failures**.
- Weak Weapon2 correctly skipped as `SKIP_WEAK_SECONDARY`.
- After six actions: CrystalShards `17 -> 3`; remaining useful target Helmet still Fortify1.
- Exact demand recalculation: Helmet needs CrystalFlake4 (have23), CrystalShards7 (have3, reserve2 => **Missing6**), Currency1 7800 (have69286, reserve10000 => enough).
- SMART Cave consumed that exact blocker and selected **Cave1**, with `FortifyCrystalMissing=6`, Ticket1=26, Chosen=Cave1.
- This proves the end-to-end **upgrade -> blocker -> material Cave** loop.

Production `systems/fortify_manager.lua` V61.23 policy:
- safe target +4 only; do not auto-roll +5+ yet because success drops below 100% and resources are spent before roll.
- primary Weapon -> equipped Armor by official power -> Weapon2 only if >=80% of primary power.
- reserves: CrystalShards2, Currency1 10000.
- max6 verified actions per Lobby cycle.
- exact remaining demand -> `IronSoul_UpgradeDemand_V61_23.txt`.

## Enchant — NEXT LIVE VALIDATION V61.24
Older V17/V18 work recovered strong protocol evidence:
- exact headless write: `EquipmentRE:FireServer("Enchant", equipmentUUID, enchantSlotKey, enchantedStoneUUID)`.
- equipment must have an already-existing empty `Enchantments[slot]` table with no `Type`.
- stone must exist in `PlayerData.EnchantedStone.Owned`.
- cost exposed by `EnchantmentUtil:GetEnchantCost(equipmentRarity, stoneRarity)`; recovered formula = rarityGear * rarityStone * 200 Currency1.
- success consumes the stone and populates the equipment enchant slot.
- do NOT auto-UnEnchant: it consumes DetachTool and old stone restoration is not proven.
- Old V18 code was protocol/resource-aware, but no trustworthy historical live report proving an actual mutation was found.

Therefore first step is a standalone **one-action controlled live validation**:
- file delivered to user: `IronSoul_Enchant_Controlled_V61_24.lua`.
- run in Lobby without normal loader.
- equipped gear only; requires Fortify >=4; primary Weapon first then Armor; skips Weapon2.
- requires existing empty enchant slot.
- uses lowest-rarity valid stone for this first irreversible test; keeps Currency1 reserve10000.
- one action maximum; verifies both installed enchant (`Type != nil`) and exact stone UUID consumed.
- output: `IronSoul_EnchantControlled_V61_24.txt`.
- If this passes, build production smart Enchant scorer/demand publisher and re-enable Cave2 from exact Enchant demand.

## Settlement / replay / inventory
- Equipment maintenance threshold 85; full/high inventory -> Lobby.
- Replay waits bounded; stuck/full replay -> Lobby.

## Luau/compiler reliability
- historical combat chunk near local-register ceiling; prior change hit `Out of local registers`.
- update existing patches/modules in place; substantial behavior external when possible.
- Fortify/Cave upgrade logic is external; no new lobby patch file was added. Existing forge metrics patch carries the tiny post-forge hook.

## Next progression work
1. Run standalone `IronSoul_Enchant_Controlled_V61_24.lua` once in Lobby and send `IronSoul_EnchantControlled_V61_24.txt`.
2. If verified, integrate smart Auto Enchant after Fortify/Blessing and publish exact Cave2 demand.
3. Pet growth exact costs -> Cave3 demand.
4. Smart shops driven by actual upgrade blockers.
5. Higher-risk Fortify/Blessing (+5+) policy only after cost/value/risk rules are deliberately chosen.
6. Endless Tower later.

World2 active movement remains frozen until deliberately revisited; never reuse World1 coordinates/door assumptions there.
