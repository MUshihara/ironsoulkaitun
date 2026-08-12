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

## Demand-driven SMART Cave V61.24
- Old fixed stock buffers are retired.
- Planner runs after Forge/EquipBest + Blessing/Fortify + Enchant.
- **Cave1** from exact Blessing/Fortify `CrystalShardsMissing`.
- **Cave2** from exact Enchant blocker: a useful +4 keeper has an existing empty enchant slot and zero usable Enchanted Stones.
- Cave2 does NOT use old `count(EnchantedStone.Owned)` target like 3/4; current stone presence is checked by Enchant manager each Lobby.
- Cave1 score > Cave2 when both blockers exist because guaranteed Fortify is deterministic.
- **Cave3** held until pet manager publishes exact costs.
- Trial only; reserve5 Ticket1; 360s cooldown retained.
- Decision log `IronSoul_CavePlannerDecision_V61_24.txt`.

## Skill/combat baseline
- Level Skill unlock path = Level + weapon proficiency; `skill_manager.lua` activates server-granted branches only.
- Weapon-aware V61.21 loadout passed.
- V61.22 fixed old skills-only BaseAttack regression; latest Cave2 + W1 D5 show `BASIC_DRIVER | VERIFIED`.
- SkillU is charge-based; native game/server controls readiness; D5 produced real Ultimate casts.

## Blessing / Fortify terminology
- **Blessing is the player-facing game name for the same equipment upgrade system implemented internally as `Fortify` / `FortifyUtil`.**
- Do not design a separate Blessing module unless future live evidence proves another mechanic.

## V61.23 SAFE BLESSING/FORTIFY — PRODUCTION PASS
Policy:
- auto only guaranteed +2/+3/+4 (PR=100); no +5+ gambling yet;
- primary Weapon -> equipped Armor -> Weapon2 only if >=80% primary power;
- reserve CrystalShards2 + Currency1 10000;
- max6 verified actions/Lobby.

Latest proof:
- `Single_Gray` +1 -> +4, power `484 -> 616`, all3 verified.
- `HeavyBody_Monarch_T3` +1 -> +4, power `908 -> 1073`, all3 verified.
- 6 actions, 0 failures; weak Weapon2 skipped.
- shards `17 -> 3`.
- Helmet remained +1; exact CrystalShards shortage after reserve =6.
- SMART Cave correctly chose Cave1 from that blocker.

## V61.24 ENCHANT — LIVE PASS / PRODUCTION ENABLED
Controlled live proof on `Single_Gray` +4:
- existing empty slot1;
- owned stones: Burn_1 rarity2 and two Frost_1 rarity2;
- selected Burn_1 for first controlled validation;
- exact call `EquipmentRE:FireServer("Enchant", equipmentUUID, slotKey, stoneUUID)`;
- cost API returned 2400 Currency1;
- FireServer OK, verification OK;
- Currency1 `69286 -> 66886` (-2400);
- equipment official power `616 -> 696` (+80);
- exact Burn stone UUID consumed;
- installed fields: Type=Burn, Id=Burn_1, DMG=8, Chance=0.07, Duration=1.1;
- Result `ENCHANTED_VERIFIED`.

Production `systems/enchant_manager.lua` V61.24:
- runs after Blessing/Fortify, before Cave planner;
- keeper minimum Fortify +4;
- active/primary weapon first, then strongest equipped Armor;
- secondary weapon only if >=80% active weapon power;
- existing empty enchant slots only;
- one action maximum/Lobby;
- Currency1 reserve10000;
- no overwrite/reroll/UnEnchant/DetachTool;
- stones scored from live `DMG * Chance * Duration` effect with rarity quality tie-break instead of old weakest-first validation policy;
- every mutation verifies populated slot + exact stone UUID consumption;
- after mutation, writes to shared demand file:
  - `EnchantEligibleEmptySlots`
  - `EnchantUsableStones`
  - `EnchantStoneMissing`
  - `EnchantCurrencyBlocked`
  - `Cave2Needed`
- Cave2 demand only true if an eligible empty +4 keeper slot remains, zero valid stones remain, and Currency1 is not the blocker.
- log `IronSoul_EnchantManager_V61_24.txt`.

## Upgrade chain current
`historical Forge/EquipBest -> Blessing/Fortify V61.23 -> Smart Enchant V61.24 -> demand-driven Cave V61.24 -> Story`.
`systems/upgrade_preflight.lua` V61.24 owns this sequence.

## Settlement / replay / inventory
- Equipment maintenance threshold85; full/high inventory -> Lobby.
- Replay waits bounded; stuck/full replay -> Lobby.

## Reliability
- Historical combat chunk near local-register ceiling; substantial new behavior stays external.
- Upgrade managers fail closed to Story when state/demand cannot be trusted.
- No new giant lobby patch; small post-forge hook loads `upgrade_preflight.lua`.

## Next progression work
1. One normal production-loader cycle: verify Smart Enchant selects remaining Frost/valid stone, writes fresh demand, and Cave1/Cave2 choice matches blocker priority.
2. Then pet growth exact costs (`PetsFortifyUtil` / `PetsUpgradeUtil`) -> Cave3 demand.
3. Smart shops driven by actual resource/currency blockers.
4. Higher-risk Blessing/Fortify +5+ only after deliberate expected-value/risk policy.
5. Endless Tower later.

World2 active movement remains frozen until deliberately revisited; never reuse World1 coordinates/door assumptions there.
