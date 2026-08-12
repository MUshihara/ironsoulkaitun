# Iron Soul Kaitun — Compact Project Memory

## Goal
24/7 automatic **fresh account -> end progression**. Headless/API-first, fast, low CPU/RAM. No normal clicking.

## Stable foundation
- Tutorial `76701861705540`; Lobby `117533937949084`.
- World1 V61.15 routing stable/frozen after repeated fresh-account clears through D5.
- World1 movement = smooth fast CFrame tween/floating, never Humanoid walking for traversal.
- `dungeon_route_mapper.lua` owns place-aware Story discovery/recovery; raw movement/crossed-plane is never progression proof.
- Headless Forge, EquipBest/smart cleanup validated.
- Fresh Lobby: `PlayerData.LevelData.Level` authoritative if `LG_Level` nil; mirror only in preflight.

## World2 D1 — VALIDATED 2026-08-12
- World2 PlaceId `136216144170036`.
- **World2 was never disabled/paused from Story progression.** What was frozen was NEW World2-specific route-mapper intervention/experimentation. `dungeon_route_mapper.lua` remained discovery/logging-only for World2 while existing combat + transition/watchdog stayed active.
- Latest unattended World2 D1 clear: settlement166.89s, GameRound6, 66 targets, 0 deaths, GateSuccess1/GateFail0, WatchdogStarts0/Exhausted0, PortalsInvoked4.
- Sequence: R1 PortalD -> R2; R2 gate -> R3; R3 PortalD -> R4; R4 Portal -> R5; R5 -> R6 settlement.
- Combat showed `BASIC_DRIVER | VERIFIED` and real SkillU casts.
- Same ZIP contained another W2 D1 run already at Round3 cleanly when captured.
- Preserve current W2 behavior. Active route recovery remains off/discovery-only until D2+ produces a specific failure.
- Validation scope is D1 only.

## Cave — STABLE MOBILE BASELINE
- Cave1 Crystal `91584731222940`: Crystal Shards; Trial Lv10/P480.
- Cave2 Runes `119524374829397`: Enchant/rune materials; Trial Lv13/P780.
- Cave3 Courtyard `132445869992129`: pet materials; Trial Lv13/P940.
- All are one-room Round1. `cave_chase.lua` V61.19 waits for combat-controller readiness before moving, then handles far enemies.
- Cave2/Cave3 validated on mobile.
- One Cave run -> Lobby; no paid replay spam.

## Demand-driven SMART Cave
- Fixed stock buffers retired.
- **Cave1** from exact Blessing/Fortify `CrystalShardsMissing`.
- **Cave2** from exact Enchant blocker: useful +4 keeper has an existing empty enchant slot and zero usable Enchanted Stones.
- Cave1 outranks Cave2 when both blockers exist because guaranteed Fortify is deterministic.
- **Cave3 remains held until an actual useful owned pet has an exact next pet-growth material shortage.** Owning WholeDragonScale or other pet materials by itself is NOT Cave3 demand.
- Trial only; reserve5 Ticket1; cooldown360s.

## Skill/combat baseline
- Skill unlock path = Level + weapon proficiency; `skill_manager.lua` activates server-granted branches only.
- Weapon-aware V61.21 loadout passed.
- V61.22 fixed old skills-only BaseAttack regression; W1/W2/Cave show `BASIC_DRIVER | VERIFIED`.
- SkillU is charge-based; native server controls readiness; W1/W2 produced real Ultimate casts.

## Blessing / Fortify terminology
- **Blessing is the player-facing game name for the same equipment upgrade system implemented internally as `Fortify` / `FortifyUtil`.**
- Do not design a separate Blessing module without new evidence.

## V61.23 SAFE BLESSING/FORTIFY — PRODUCTION PASS
Policy:
- auto only guaranteed +2/+3/+4 (PR=100); no +5+ gambling yet;
- primary Weapon -> equipped Armor -> Weapon2 only if >=80% primary power;
- reserve CrystalShards2 + Currency1 10000;
- max6 verified actions/Lobby.

Proof:
- `Single_Gray` +1 -> +4, power484->616, all3 verified.
- `HeavyBody_Monarch_T3` +1 -> +4, power908->1073, all3 verified.
- 6 actions, 0 failures; weak Weapon2 skipped.
- Later Forge replacements correctly caused fresh exact demand recalculation; at Lv21/P4221 CrystalShards3 yielded Missing13 after reserve instead of stale old-gear demand.

## V61.24 ENCHANT — LIVE / PRODUCTION
Controlled proof on `Single_Gray` +4:
- exact call `EquipmentRE:FireServer("Enchant", equipmentUUID, slotKey, stoneUUID)`;
- Burn_1 installed;
- Currency1 69286->66886 (-2400);
- power616->696 (+80);
- exact stone consumed.

Production:
- keeper Fortify>=4, primary weapon first, existing empty slots only, one action/Lobby;
- Currency1 reserve10000; no overwrite/reroll/UnEnchant/DetachTool;
- effects scored from DMG/Chance/Duration + rarity;
- verifies installed slot + exact stone consumption;
- publishes exact Cave2 need.
- Later integrated state had `Single_Gray` power776, Fortify4, EnchantSlots2, Empty0/Filled2, strong evidence production filled the second slot. Current Cave2 demand correctly zero.

## V61.25 PET GROWTH RECON — PETLESS ACCOUNT TRUTH
Standalone recon at Lobby Lv22/P4235:
- `PlayerData.Pets.Owned` count0;
- `PlayerData.Pets.Equipped` count0;
- `OwnedPetCount=0`;
- `HasFortifiablePet=false`;
- `HasUpgradablePet=false`;
- Currency1=73459, Gem1460, Ticket1=26, WholeDragonScale=24.

Interpretation:
- **Do NOT request Cave3 on this state.** There is no pet to upgrade, so no valid pet-growth blocker exists even though pet material is already owned.
- Pet Fortify API/config is mapped and definitely uses Cave3 material families:
  - `PetsFortifyUtil`: CanFortify/Fortify/GetFortifyDef/GetNextFortify/GetPetFortifyMax/HasFortifiablePet;
  - `PetsUpgradeUtil`: CanUpgradeStar/UpgradeStar/StrengthenPetAttr/HasUpgradablePet;
  - Star1..9 Fortify caps = 10/20/.../90;
  - cost tables include BrokenDragonScale, WholeDragonScale, DragonClaw, then higher materials such as DragonHorn.
- Exact live mutation is still not validated on the current account because there is no pet. Do not enable unattended pet Fortify/Star spending yet.

## V61.25 PET ACQUISITION BRIDGE — PRODUCTION FIX
Regression found:
- historical later Lobby `petPass()` retained claim-completed-hatch + EquipBest but dropped V20 `StartHatch` for owned eggs;
- it also used a fragile/wrong completion-call shape. V20 validation uses `PetsHatchUtil:IsCompleted(slotData)`.

New `systems/pet_manager.lua` V61.25:
- external bounded Lobby pass; no GUI/clicks/no paid pet action/no fast polling;
- claim completed hatch via `PetsHatchUtil.RemoteEvent:FireServer("Claim", slotIndex)` and verify slot cleared + pet count increased;
- read eggs from `PlayerData.PetHatch.Egg`;
- free-slot detection from `GetSlotData`/`GetSlotCount`;
- choose higher-rarity egg first using `GetEggCfg(EggId).Rarity`;
- start via `PetsHatchUtil.RemoteEvent:FireServer("StartHatch", slotIndex, eggUUID)` and verify slot `EggUUID`;
- `PetsUtil.RemoteEvent:FireServer("EquipBest")` after a pet exists;
- log `IronSoul_PetManager_V61_25.txt`;
- states `PET_READY`, `HATCHING`, `WAIT_EGG`.

`systems/upgrade_preflight.lua` V61.25 now runs pet acquisition before Fortify/Enchant. Pet bridge is deliberately **non-blocking**, so failures cannot stop proven Story progression.

Next pet branch:
- `PET_READY` -> inspect exact live pet rarity/star/next Fortify cost, validate ONE mutation, then add exact Cave3 demand;
- `HATCHING` -> continue 24/7 until normal Lobby claim;
- `WAIT_EGG` -> map/automate first-egg acquisition before pet growth. Do not burn Cave3 tickets for material while no pet exists.

## Upgrade chain current
`historical Forge/EquipBest -> Pet acquisition V61.25 -> Blessing/Fortify V61.23 -> Smart Enchant V61.24 -> exact SMART Cave -> Story`.
Pet acquisition is non-blocking; Cave3 still disabled pending `PET_READY` + validated exact growth demand.

## Settlement / replay / inventory
- Equipment maintenance threshold85; full/high inventory -> Lobby.
- Replay waits bounded; stuck/full replay -> Lobby.

## Reliability
- Historical combat chunk near local-register ceiling; substantial new behavior stays external.
- Upgrade managers fail closed to Story when state/demand cannot be trusted.
- Do not alter World1 or newly proven W2 D1 without failure evidence.

## Next progression work
1. Normal-loader Lobby pass: inspect `IronSoul_PetManager_V61_25.txt` to determine PET_READY/HATCHING/WAIT_EGG.
2. PET_READY -> one controlled pet-growth mutation -> exact Cave3 demand; WAIT_EGG -> exact first-egg acquisition source first.
3. Continue observing W2 D2+ naturally.
4. Smart shops driven by actual resource/currency/egg blockers.
5. Higher-risk Blessing/Fortify +5+ only after deliberate risk/value policy; Endless later.
