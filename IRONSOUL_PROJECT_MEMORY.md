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
- `systems/upgrade_preflight.lua`: safe Fortify -> exact demand -> SMART Cave -> otherwise Story.
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

## V61.23 SAFE FORTIFY — ACTIVE, AWAITING ONE PRODUCTION PASS
Standalone demand scan at Lobby Lv20 / Power2603:
- Breastplate `HeavyBody_Monarch_T3`: Power908, Fortify1, rarity4.
- Helmet `LightHead_Monarch_T3`: Power576, Fortify1, rarity6.
- primary Weapon `Single_Gray`: Power484, Fortify1, rarity6.
- Weapon2 `Single_KnightSword`: Power108, Fortify1, rarity2.
- live +2/+3/+4 all PR=100.
- all four to +4: CrystalFlake12 have31; CrystalShards27 have17; Currency1 27600 have83686.
- Weak Weapon2 alone costs 6 shards to +4; production must not blindly spend on it.

Production `systems/fortify_manager.lua` V61.23:
- runs after Forge/EquipBest.
- safe target +4 only; do not auto-roll +5+ yet because success drops below 100% and resources are spent before roll.
- priority primary Weapon -> equipped Armor by official power -> Weapon2 only if >=80% of primary power.
- reserves: CrystalShards2, Currency1 10000.
- max6 verified Fortify actions per Lobby cycle.
- exact remaining demand written to `IronSoul_UpgradeDemand_V61_23.txt`.
- current expected first production cycle: primary weapon + breastplate can consume 14 shards over 6 guaranteed actions; remaining helmet need then produces a real Cave1 shortage while preserving reserve.
- logs: `IronSoul_FortifyManager_V61_23.txt`, `IronSoul_UpgradeDemand_V61_23.txt`, `IronSoul_UpgradePreflight_V61_23.txt`, `IronSoul_CavePlannerDecision_V61_23.txt`.

## Settlement / replay / inventory
- Equipment maintenance threshold 85; full/high inventory -> Lobby.
- Replay waits bounded; stuck/full replay -> Lobby.

## Luau/compiler reliability
- historical combat chunk near local-register ceiling; prior change hit `Out of local registers`.
- update existing patches/modules in place; substantial behavior external when possible.
- Fortify/Cave upgrade logic is external; no new lobby patch file was added. Existing forge metrics patch carries the tiny post-forge hook.

## Next progression work
1. Run normal production loader once in Lobby and verify V61.23 Fortify + exact Cave1 demand/selection.
2. Then map/automate Enchant exact mutation tuple and actual EnchantedStone quantities; publish Cave2 demand.
3. Pet growth exact costs -> Cave3 demand.
4. Smart shops driven by upgrade blockers.
5. Blessing / risky Fortify policy only after exact cost/value evidence.
6. Endless Tower later.

World2 active movement remains frozen until deliberately revisited; never reuse World1 coordinates/door assumptions there.
