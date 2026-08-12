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

## World2 — D1 NOW VALIDATED
- PlaceId `136216144170036`.
- **World2 was not disabled.** Previous “frozen” wording meant new World2-specific route-mapper intervention was frozen; the Story planner and existing combat/transition/watchdog system were still allowed to run.
- `dungeon_route_mapper.lua` remains discovery/logging-only for World2. Do NOT enable its active recovery merely because D1 now works.
- Latest unattended W2 D1 full clear: settlement166.89s, GameRound6, 66 targets, 0 deaths, 7 hits/739 damage, GateSuccess1, GateFail0, no watchdog failure, PortalsInvoked4.
- Successful transition sequence observed: Round1 PortalD -> Round2; Round2 gate -> Round3; Round3 PortalD -> Round4; Round4 Portal -> Round5; Round5 -> Round6 settlement.
- BasicAttack verified and SkillU fired normally.
- A second W2 D1 run in the same ZIP was still running at capture but had already reached Round3 cleanly: 42 targets, one hit, GateSuccess1, no gate/watchdog failure.
- **Current proof is D1 only.** Let D2+ happen naturally and collect evidence before declaring the rest of World2 stable.
- Preserve the exact current W2 path; only add World2-specific recovery if later evidence shows a real failure.

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
- Order: Forge/EquipBest -> Blessing/Fortify -> Smart Enchant -> exact demand -> SMART Cave -> otherwise Story.
- **Cave1** only from real `CrystalShardsMissing` for guaranteed Blessing/Fortify.
- **Cave2** only when a useful +4 keeper has an existing empty enchant slot and zero usable stones. Never use the old unreliable `3/4 runes` count target.
- Cave1 outranks Cave2 when both blockers exist because guaranteed Fortify is deterministic.
- **Cave3** waits for pet-upgrade exact demand.
- Trial only; reserve5 Ticket1; cooldown360s.

Latest integrated decision at Lv21/P4221:
- CrystalShards3;
- FortifyCrystalMissing13;
- EnchantEligibleEmptySlots0;
- EnchantStoneMissing0;
- only valid Cave candidate = Cave1;
- remaining cooldown correctly sent account to Story instead of spending another ticket.

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

First proof: `Single_Gray` +1->+4 and Monarch T3 breastplate +1->+4, 6/6 verified.
Latest session proves it recalculates after Forge replacements: newly equipped Iron T2 breastplate + Monarch T2 helmet remain +1 because only 3 shards exist; exact remaining shard blocker became Missing13 rather than spending below reserve.

## V61.24 Smart Enchant — LIVE / INTEGRATED
Exact write: `EquipmentRE:FireServer("Enchant", equipmentUUID, enchantSlotKey, enchantedStoneUUID)`.
- Controlled Burn_1 test on `Single_Gray` +4 passed: Currency1 -2400, power616->696, stone consumed, slot verified.
- Production manager: keeper Fortify>=4, active weapon first, one action/Lobby, existing empty slots only, Currency reserve10000, no overwrite/UnEnchant/DetachTool, verify installed slot + exact stone consumption.
- Latest normal-loader state has `Single_Gray` power776, EnchantSlots2, Empty0/Filled2. Since the controlled test left only one slot filled at power696, this strongly indicates a later production cycle successfully filled the second slot; its one-action log was overwritten by a later no-action Lobby cycle.
- Current Enchant demand correctly says zero: new armor is not yet +4 and Sword has no empty slot, so Cave2 is not requested.

## Upgrade chain — INTEGRATED PASS
`Forge/EquipBest -> Blessing/Fortify -> Smart Enchant -> SMART Cave -> Story` ran unattended and continued through World1, Cave1, Lobby maintenance, and into a successful World2 D1 clear.

## Next phase
1. **Pet growth (`PetsFortifyUtil` / `PetsUpgradeUtil`) + exact Cave3 demand.**
2. Let World2 D2+ be reached naturally and inspect logs before changing routing.
3. Smart shops/currency spending.
4. Higher-risk Blessing/Fortify +5+ only with explicit risk/value policy.
5. Endless Tower later.

## Settlement / replay
- Inventory maintenance threshold85; full/high inventory -> Lobby.
- Replay waits bounded; stuck/full replay -> Lobby.

Repo is source of truth when chat memory conflicts.
