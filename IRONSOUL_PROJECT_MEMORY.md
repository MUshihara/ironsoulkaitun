# Iron Soul Kaitun — Compact Project Memory

## Goal
24/7 automatic **fresh account -> end progression**. Headless/API-first, fast, low CPU/RAM. No normal clicking.

## Stable foundation
- Tutorial `76701861705540`; Lobby `117533937949084`.
- World1 V61.15 routing stable/frozen after repeated fresh-account clears through D5.
- World1 movement = smooth fast CFrame tween/floating, never Humanoid walking for traversal.
- `dungeon_route_mapper.lua` owns place-aware Story discovery/recovery; raw movement/crossed-plane is never progression proof.
- Headless Forge, EquipBest/smart cleanup, pet hatch/claim/equip validated.
- Fresh Lobby: `PlayerData.LevelData.Level` authoritative if `LG_Level` nil; mirror only in preflight.

## World2 D1 — VALIDATED 2026-08-12
- World2 PlaceId `136216144170036`.
- Important wording: **World2 was never disabled/paused from Story progression.** What was frozen was NEW World2-specific route-mapper intervention/experimentation. `dungeon_route_mapper.lua` remained discovery/logging-only for World2 while the existing combat + transition/watchdog stack stayed active.
- Latest unattended World2 D1 full clear:
  - settlement in **166.89s**;
  - `GameRound=6`;
  - **66 targets**;
  - **0 deaths**;
  - 7 incoming hits / 739 damage;
  - GateSuccess1 / GateFail0;
  - WatchdogStarts0 / Exhausted0;
  - LastState `PortalsInvoked=4`.
- Transition telemetry on the successful clear:
  1. Round1 ->2; local `PortalD` Round1 handshake succeeded with `OBJECTIVE_APPEARED`.
  2. Round2 ->3; selected gate and `GATE_RESULT ... NEW_REGION_FAST`.
  3. Round3 ->4; local `PortalD` Round3 handshake succeeded.
  4. Round4 ->5; local `Portal` Round4 handshake succeeded.
  5. Round5 ->6; authoritative settlement detected.
- Combat on W2 D1 also showed `BASIC_DRIVER | VERIFIED` and real SkillU casts.
- ZIP contained a second W2 D1 run still in progress when captured: elapsed61.63s, already GameRound3, 42 targets, 1 hit/60 damage, GateSuccess1, GateFail0, no watchdog failure. It had already passed Round1->2 (`GATE_ALREADY_OPEN` / enemy-region lock) and Round2->3 (`NEW_REGION_FAST`).
- **Preserve current W2 behavior. Do not turn route-mapper active recovery on merely because D1 now works.** Only add W2-specific intervention if D2+ or another W2 map produces evidence of a real transition failure.
- Current validation scope is **World2 D1 only**; do not claim D2+ stable until observed.

## Cave — STABLE MOBILE BASELINE
- Cave1 Crystal `91584731222940`: Crystal Shards; Trial Lv10/P480; 1 Ticket1 observed historically.
- Cave2 Runes `119524374829397`: Enchant/rune materials; Trial Lv13/P780.
- Cave3 Courtyard `132445869992129`: pet materials; Trial Lv13/P940.
- All are one-room Round1. `cave_chase.lua` V61.19 waits for combat-controller readiness before moving, then handles far enemies.
- Cave2/Cave3 validated on mobile with same headless/CFrame path.
- One Cave run -> Lobby; no paid replay spam.
- Cave startup may appear slow because chaser intentionally waits for full combat-controller readiness; after activation enemy discovery/tween is fast. Preserve safety until an explicit readiness signal replaces telemetry-based proof.

## Demand-driven SMART Cave V61.24
- Old fixed stock buffers are retired.
- Planner runs after Forge/EquipBest + Blessing/Fortify + Enchant.
- **Cave1** from exact Blessing/Fortify `CrystalShardsMissing`.
- **Cave2** from exact Enchant blocker: useful +4 keeper has existing empty enchant slot and zero usable Enchanted Stones.
- Cave2 does NOT use old `count(EnchantedStone.Owned)` target like 3/4.
- Cave1 score > Cave2 when both blockers exist because guaranteed Fortify is deterministic.
- **Cave3** held until pet manager publishes exact costs.
- Trial only; reserve5 Ticket1; 360s cooldown retained.
- Latest integrated decision at Lv21/P4221: CrystalShards3, FortifyCrystalMissing13, EnchantEligibleEmptySlots0, EnchantStoneMissing0 => Cave1 was the only valid Cave candidate. A remaining Cave cooldown correctly sent the account to Story instead of burning another ticket.

## Skill/combat baseline
- Level Skill unlock path = Level + weapon proficiency; `skill_manager.lua` activates server-granted branches only.
- Weapon-aware V61.21 loadout passed and follows actual equipped weapon.
- V61.22 fixed old skills-only BaseAttack regression; W1/W2/Cave runs now show `BASIC_DRIVER | VERIFIED`.
- SkillU is charge-based; native game/server controls readiness; World1 and World2 telemetry produced real Ultimate casts.

## Blessing / Fortify terminology
- **Blessing is the player-facing game name for the same equipment upgrade system implemented internally as `Fortify` / `FortifyUtil`.**
- Do not design a separate Blessing module unless future live evidence proves another mechanic.

## V61.23 SAFE BLESSING/FORTIFY — PRODUCTION PASS
Policy:
- auto only guaranteed +2/+3/+4 (PR=100); no +5+ gambling yet;
- primary Weapon -> equipped Armor -> Weapon2 only if >=80% primary power;
- reserve CrystalShards2 + Currency1 10000;
- max6 verified actions/Lobby.

Validated first production pass:
- `Single_Gray` +1 -> +4, power `484 -> 616`, all3 verified.
- `HeavyBody_Monarch_T3` +1 -> +4, power `908 -> 1073`, all3 verified.
- 6 actions, 0 failures; weak Weapon2 skipped.

Latest integrated state after further Forge/EquipBest progression at Lv21/P4221:
- primary `Single_Gray` remains Fortify4, official power776;
- new `HeavyBody_Iron_T2` power1738 Fortify1 and `LightHead_Monarch_T2` power1017 Fortify1 became equipped;
- only CrystalShards3 remained, so Fortify correctly spent nothing because each next step needed shards while reserve2 must remain;
- exact current guaranteed demand: CrystalFlake8 (have23), CrystalShards14 (have3 + reserve2 => **Missing13**), Currency1 15000 (have67948 + reserve10000 => enough).
- This demonstrates demand recalculation follows newly forged/replaced gear rather than stale equipment UUIDs.

## V61.24 ENCHANT — LIVE PASS / PRODUCTION ENABLED
Controlled live proof on `Single_Gray` +4:
- existing empty slot1;
- selected Burn_1 rarity2;
- exact call `EquipmentRE:FireServer("Enchant", equipmentUUID, slotKey, stoneUUID)`;
- cost2400 Currency1;
- verification OK;
- Currency1 `69286 -> 66886`;
- equipment power `616 -> 696` (+80);
- exact Burn stone UUID consumed and installed.

Production `systems/enchant_manager.lua` V61.24:
- runs after Blessing/Fortify, before Cave planner;
- keeper minimum Fortify+4;
- active/primary weapon first, then strongest armor;
- existing empty enchant slots only; one action/Lobby;
- no overwrite/reroll/UnEnchant/DetachTool;
- effects ranked from live DMG/Chance/Duration + rarity;
- mutation verifies populated slot + exact stone consumption;
- publishes exact Cave2 need into shared demand file.

Latest integrated state:
- `Single_Gray` power776, Fortify4, EnchantSlots2, **Empty0 / Filled2**.
- Controlled validation previously left it at power696 with only slot1 Burn installed; therefore the later two-filled-slot/power776 state is strong evidence that a subsequent production Lobby cycle successfully filled the second Sword enchant slot. The one-action log was later overwritten by a subsequent no-action Lobby cycle, so do not claim the exact second stone from this ZIP.
- Current Enchant manager correctly does nothing: new armor is only Fortify1 and the Sword has no empty slot. `EnchantStoneMissing=0`, `Cave2Needed=false`.

## Upgrade chain current — INTEGRATED PASS
`historical Forge/EquipBest -> Blessing/Fortify V61.23 -> Smart Enchant V61.24 -> demand-driven Cave V61.24 -> Story`.
- Latest unattended session exercised this chain, then continued through two W1 D5 settlements, a Cave1 settlement, Lobby maintenance, and into World2 D1 without user pausing it.
- Story progression is allowed to advance naturally when Cave is on cooldown or no higher-priority paid-resource action should run.

## Settlement / replay / inventory
- Equipment maintenance threshold85; full/high inventory -> Lobby.
- Replay waits bounded; stuck/full replay -> Lobby.

## Reliability
- Historical combat chunk near local-register ceiling; substantial new behavior stays external.
- Upgrade managers fail closed to Story when state/demand cannot be trusted.
- Do not alter a newly proven W2 transition path without failure evidence.

## Next progression work
1. **Pet growth exact costs** (`PetsFortifyUtil` / `PetsUpgradeUtil`) -> real Cave3 demand.
2. Continue observing automatic W2 progression; treat D1 as validated and collect D2+ evidence naturally rather than forcing route changes.
3. Smart shops driven by actual resource/currency blockers.
4. Higher-risk Blessing/Fortify +5+ only after deliberate expected-value/risk policy.
5. Endless Tower later.
