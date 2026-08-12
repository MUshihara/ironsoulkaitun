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

## V61.15 dungeon routing
- `systems/dungeon_route_mapper.lua` is the live place-aware route layer.
- Every PlaceId/server has its own Workspace tree; never share coordinates/door assumptions across worlds.
- Mapper discovers live `GameRound`, `RoundWakeTouch.RoundN`, Door/Portal* roots, RoundNum/Switch, objectives and streamed transitions.
- World1 active recovery; World2 discovery/logging only while World2 remains frozen.
- Raw movement/crossed-plane is never progression proof.

## Cave architecture — VALIDATED INCLUDING MOBILE
- Cave1 / Crystal: PlaceId `91584731222940`, Trial Lv10/P480, Crystal Shards.
- Cave2 / Runes: PlaceId `119524374829397`, Trial Lv13/P780, runes/EnchantedStone.
- Cave3 / Abandoned Courtyard: PlaceId `132445869992129`, Trial Lv13/P940, dragon-scale pet materials.
- All three are one-room Round1 resource activities; no Story door/portal traversal.
- Observed Trial cost = 1 Ticket1.
- `systems/cave_chase.lua` V61.19 must never move before combat-controller readiness.
- Latest Cave2 V61.22 run: BASIC_DRIVER verified, 36 targets, 0 deaths; startup wait is controller-loading safety, not slow enemy search.
- User has also validated Cave2/Cave3 on mobile with same headless/CFrame path.
- One Cave settlement -> Lobby; no paid replay spam.

## V61.23 demand-driven SMART Cave
- Old fixed buffers (`18 shards / 4 runes / 28 scales`) are retired from automatic spending.
- SMART Cave now runs **after Forge/EquipBest and safe upgrades**, immediately before Story planning.
- `systems/upgrade_preflight.lua`: Fortify -> exact demand -> Cave -> otherwise Story.
- `systems/cave_planner.lua` V61.23 currently auto-selects only Cave1 from real `CrystalShardsMissing` published by Fortify.
- Automatic Cave2/Cave3 are temporarily held until Enchant/Pet managers publish exact demand. This avoids repeated Cave2 spending from the unreliable old EnchantedStone entry-count metric.
- Trial only; keep 5 Ticket1 reserved; 360s cooldown remains.

## Skill Tree truth — RECON VALIDATED
- `PlayerData.SkillTree` is authoritative.
- Level skills are gated by player Level + weapon proficiency. No validated ore/crystal/currency payment exists in the level-skill unlock path.
- Server populates `SkillTree.Unlock`; do not invent unlock payments.
- `systems/skill_manager.lua` V61.20.1 activates only server-granted branches across weapon classes and verifies Active state.
- Latest activation test: 9 server-unlocked branches, 5 newly activated, 4 already active, 0 failed.

## V61.21 weapon-aware combat loadout — PASSED
- Skill Tree activation and equipped combat loadout are separate systems.
- Proven write: `WeaponUtil.RemoteEvent:FireServer("EquipSkill", weaponId, slot, skillId)`.
- Verify with `WeaponUtil:GetWeaponSkillId`; validate with `WeaponUtil:CanEquipSkill`.
- `systems/skill_loadout_manager.lua` scores live ResSkill/ResSkillStage data and follows the actually equipped weapon class.
- Latest D4 test equipped Sword Skill1/Skill2/SkillU with Failed=0.

## V61.22 basic attack + Ultimate — VALIDATED
- Old one-shot BaseAttack calibration could permanently enter `HEADLESS_FAILED` after a skill action window, producing skills-only combat.
- V61.22 updated existing `combat_v61_8_skill_telemetry.patch` in place.
- BaseAttack calibration now has first priority, uses a clean four-stage direct combo, and one uncertain sample no longer disables basics.
- No Mouse1 fallback.
- SkillU is charge-based, not just a third cooldown skill; native callback/server decides readiness.
- Latest Cave2 and D5 logs both showed `BASIC_DRIVER | VERIFIED`; D5 also produced real SkillU casts and settlement. Treat the combat/loadout/basic/ultimate layer as stable unless new evidence contradicts it.

## V61.23 safe Fortify — ACTIVE, NEEDS ONE PRODUCTION TEST
Validated standalone demand scan at Lv20 / Power2603:
- equipped: Breastplate P908, Helmet P576, primary Sword P484, weak Weapon2 P108;
- all four were Fortify1;
- live Fortify +2/+3/+4 are PR=100;
- all-equipped diagnostic demand: CrystalFlake12 (have31), CrystalShards27 (have17), Currency1 27600 (have83686).
- Weak Weapon2 accounts for 6 of those shards. Production policy does **not** blindly Fortify it.

Production:
- `systems/fortify_manager.lua` V61.23 runs after Forge/EquipBest.
- Safe ceiling = +4 only. Never auto-roll +5+ yet because success becomes <100% and resources are consumed before the roll.
- Priority: primary Weapon first -> equipped Armor by official power -> Weapon2 only if >=80% of primary power.
- Preserve CrystalShards reserve2 and Currency1 reserve10000.
- Max6 Fortify actions per Lobby cycle; every mutation verified from PlayerData.
- Exact remaining demand written to `IronSoul_UpgradeDemand_V61_23.txt`.
- `systems/cave_planner.lua` consumes `CrystalShardsMissing`; Cave1 is selected only for an actual Fortify blocker.
- Current expected account behavior from the diagnostic: primary weapon + breastplate can consume 14 shards over six guaranteed actions, then remaining helmet demand should create a Cave1 blocker while preserving reserve. Verify with production logs before calling fully stable.
- Logs: `IronSoul_FortifyManager_V61_23.txt`, `IronSoul_UpgradeDemand_V61_23.txt`, `IronSoul_UpgradePreflight_V61_23.txt`, `IronSoul_CavePlannerDecision_V61_23.txt`.

## Settlement / replay
- Inventory maintenance threshold 85; full/high inventory at settlement -> Lobby immediately.
- Replay waits are short/bounded; stuck/full replay vote -> Lobby.

## Next progression work
1. Verify V61.23 safe Fortify + real Cave1 blocker once.
2. Map/automate Enchant exact tuple + stone quantities; then enable demand-driven Cave2.
3. Pet growth exact costs; then enable demand-driven Cave3.
4. Smart shops based on upgrade demand.
5. Blessing and higher-risk Fortify policy only after exact value/cost evidence.
6. Endless Tower later.

Repo is source of truth when chat memory conflicts.
