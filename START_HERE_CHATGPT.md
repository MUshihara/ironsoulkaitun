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
- Handle this in preflight, not another lobby patch.

## World1 — STABLE
Fresh accounts have progressed repeatedly through World1 D1/D2/D3/D4/D5. V61.15 routing remains baseline; do not casually retune World1 combat/traversal.

## World2 — D1 VALIDATED
- PlaceId `136216144170036`.
- **World2 was not disabled.** Previous “frozen” wording meant new World2-specific route-mapper intervention was frozen; Story progression and existing combat/transition/watchdog remained active.
- `dungeon_route_mapper.lua` stays discovery/logging-only for World2. Do NOT enable active recovery merely because D1 works.
- Latest unattended W2 D1 full clear: settlement166.89s, GameRound6, 66 targets, 0 deaths, GateSuccess1, GateFail0, no watchdog failure, PortalsInvoked4.
- Successful sequence: R1 PortalD -> R2; R2 gate -> R3; R3 PortalD -> R4; R4 Portal -> R5; R5 -> R6 settlement.
- BasicAttack verified and SkillU fired normally.
- A second W2 D1 run in the same ZIP had already reached Round3 cleanly at capture.
- **Current proof is D1 only.** Let D2+ happen naturally; only add W2-specific recovery after actual failure evidence.

## Cave baseline
- Cave1 Crystal `91584731222940`: Crystal Shards; Trial Lv10/P480.
- Cave2 Runes `119524374829397`: EnchantedStone/runes; Trial Lv13/P780.
- Cave3 Courtyard `132445869992129`: pet materials; Trial Lv13/P940.
- All are one-room Round1 activities; no Story door/portal traversal.
- `cave_chase.lua` V61.19 waits for combat-controller readiness before moving; this prevents pre-controller deaths.
- Cave2/Cave3 validated on mobile.
- Cave startup can look delayed because the chaser intentionally waits for combat readiness; enemy detection itself is fast after activation.
- One Cave settlement -> Lobby; no paid replay spam.

## Demand-driven SMART Cave V61.24
- Fixed stock buffers are retired.
- Order: Forge/EquipBest -> pet bridge -> Blessing/Fortify -> Smart Enchant -> exact demand -> SMART Cave -> otherwise Story.
- **Cave1** only from real `CrystalShardsMissing` for guaranteed Blessing/Fortify.
- **Cave2** only when a useful +4 keeper has an existing empty enchant slot and zero usable stones. Never use the old unreliable `3/4 runes` count target.
- Cave1 outranks Cave2 when both blockers exist because guaranteed Fortify is deterministic.
- **Cave3 is still held.** Do not infer Cave3 demand from owning pet materials alone; require an actual useful owned pet plus an exact next pet-upgrade material shortage.
- Trial only; reserve5 Ticket1; cooldown360s.

Latest integrated decision before pet phase at Lv21/P4221:
- CrystalShards3;
- FortifyCrystalMissing13;
- EnchantEligibleEmptySlots0;
- EnchantStoneMissing0;
- only valid Cave candidate = Cave1;
- remaining cooldown correctly sent account to Story instead of spending another ticket.

## V61.25 pet acquisition bridge — CURRENT
Latest standalone pet-growth recon at Lobby Lv22/P4235 proved:
- `PlayerData.Pets.Owned` = 0;
- `PlayerData.Pets.Equipped` = 0;
- `HasFortifiablePet=false`;
- `HasUpgradablePet=false`;
- Currency1=73459, Ticket1=26, WholeDragonScale=24.
Therefore **WholeDragonScale24 is NOT a Cave3 blocker/demand on this account yet**.

The recon also proved the live pet growth modules/tables exist:
- `PetsFortifyUtil`: CanFortify/Fortify/GetFortifyDef/GetNextFortify/GetPetFortifyMax/HasFortifiablePet;
- `PetsUpgradeUtil`: CanUpgradeStar/UpgradeStar/StrengthenPetAttr/HasUpgradablePet;
- Star1..9 Fortify caps = 10,20,...,90;
- pet Fortify costs directly use Cave3 families such as BrokenDragonScale, WholeDragonScale, DragonClaw, then higher materials.

Regression found in later Lobby pet pass:
- it retained claim-ready-hatch + EquipBest but lost the V20 **StartHatch owned egg** step;
- it also used the wrong/fragile completion-call shape instead of the V20-validated `PetsHatchUtil:IsCompleted(slotData)`.

Production fix:
- `systems/pet_manager.lua` V61.25 restores the validated V20 bridge as a small external bounded manager:
  1. claim completed hatch via `RemoteEvent:FireServer("Claim", slotIndex)` and verify;
  2. read owned eggs from `PlayerData.PetHatch.Egg`;
  3. start highest-rarity owned eggs in free slots via `RemoteEvent:FireServer("StartHatch", slotIndex, eggUUID)` and verify `EggUUID`;
  4. `PetsUtil.RemoteEvent:FireServer("EquipBest")` once a pet exists.
- no GUI/clicking, no paid pet action, no fast polling.
- log `IronSoul_PetManager_V61_25.txt`.
- `upgrade_preflight.lua` V61.25 runs this bridge before Fortify/Enchant and treats it as **non-blocking**, so a pet issue can never break proven Story progression.
- Possible next state: `PET_READY`, `HATCHING`, or `WAIT_EGG`.
- If `WAIT_EGG`, next task is exact **first-egg acquisition** research; do not run Cave3 just to obtain materials.

## Skill/combat baseline
- Level Skill branches = Level + weapon proficiency; `skill_manager.lua` activates server-granted branches only.
- Weapon-aware V61.21 loadout passed.
- V61.22 fixed skills-only BaseAttack regression; W1/W2/Cave now show `BASIC_DRIVER | VERIFIED`.
- SkillU is charge-based and native server readiness remains authoritative. W1 and W2 both produced real Ultimate casts.

## Blessing = internal Fortify system
- **Blessing is the player-facing game name for the equipment system implemented internally as `Fortify` / `FortifyUtil`.**
- Do not create a separate Blessing system without new evidence.

## V61.23 Blessing/Fortify — PRODUCTION PASS
- auto only guaranteed +2/+3/+4;
- primary Weapon -> equipped Armor -> competitive Weapon2 only;
- reserve CrystalShards2 / Currency1 10000;
- max6 verified actions/Lobby.
- First proof: `Single_Gray` +1->+4 and Monarch T3 breastplate +1->+4, 6/6 verified.
- Latest session proves it recalculates after Forge replacements; exact remaining shard blocker became Missing13 rather than spending below reserve.

## V61.24 Smart Enchant — LIVE / INTEGRATED
Exact write: `EquipmentRE:FireServer("Enchant", equipmentUUID, enchantSlotKey, enchantedStoneUUID)`.
- Controlled Burn_1 test on `Single_Gray` +4 passed: Currency1 -2400, power616->696, stone consumed, slot verified.
- Production manager: keeper Fortify>=4, active weapon first, one action/Lobby, existing empty slots only, Currency reserve10000, no overwrite/UnEnchant/DetachTool, verify installed slot + exact stone consumption.
- Latest normal-loader state has `Single_Gray` power776, EnchantSlots2, Empty0/Filled2, strongly indicating a later production cycle filled the second slot.
- Current Enchant demand correctly says zero, so Cave2 is not requested.

## Upgrade chain — CURRENT
`Forge/EquipBest -> Pet acquisition V61.25 -> Blessing/Fortify -> Smart Enchant -> SMART Cave -> Story`.
The pet bridge is non-blocking and Cave3 remains disabled until `PET_READY` plus exact live pet-growth demand.

## Next phase
1. Run normal loader through one Lobby and inspect `IronSoul_PetManager_V61_25.txt`.
2. If `HATCHING`, let normal 24/7 loop continue until claim; if `PET_READY`, validate one exact pet Fortify/Star mutation and then publish Cave3 demand; if `WAIT_EGG`, map the first-egg acquisition source first.
3. Let World2 D2+ be reached naturally and inspect logs before changing routing.
4. Smart shops/currency spending.
5. Higher-risk Blessing/Fortify +5+ only with explicit risk/value policy; Endless later.

## Settlement / replay
- Inventory maintenance threshold85; full/high inventory -> Lobby.
- Replay waits bounded; stuck/full replay -> Lobby.

Repo is source of truth when chat memory conflicts.
