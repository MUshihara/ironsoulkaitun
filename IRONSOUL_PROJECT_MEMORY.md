# Iron Soul Kaitun — Compact Project Memory

## Goal
24/7 automatic **fresh account -> end progression**. Headless/API-first, fast, low CPU/RAM. No normal clicking.

## Stable foundation
- Tutorial `76701861705540`; Lobby `117533937949084`.
- World1 V61.15 is stable/frozen after repeated fresh-account D1/D2/D3 clears and 4 consecutive clean D3 matches.
- Normal World1 combat/traversal should not be retuned without new failure evidence.
- Headless Forge, EquipBest/smart cleanup, pet hatch/claim/equip are validated.
- Latest forge proof: `MEASURED_RESERVE_BEST_ORE`, ores `93/100 -> 28/100`, 9 crafts, Power `755 -> 1197` (+442).
- Fresh Lobby truth: `PlayerData.LevelData.Level` is authoritative when `LG_Level` is nil; resolve/mirror in preflight, never another fresh-level patch.

## World1 movement / routing
- User wants **smooth fast CFrame tween/floating**, not Humanoid walking and not hard snapping everywhere.
- `world1_motion.lua`: ~210 studs/s normal, ~260 long traversal; portal pre-touch settle ~0.60s.
- Never generic RoundPortal RF; raw movement/crossed-plane is never progression proof.
- `dungeon_route_mapper.lua` V61.15 discovers live PlaceId/WorldId/Diff/GameRound/wakes/doors/Portal* and fails closed to Lobby on bounded route failure.
- World2 remains frozen for active movement; its layout/PortalD/blockers are different and must not inherit World1 coordinates/rules.

## Skill Tree truth
- `PlayerData.SkillTree` authoritative.
- Unlock progression is level + weapon proficiency; old Staff evidence had UnlockSkill3 at Level10 / Proficiency2000.
- Gray/The Guide was tutorial/UI flow, not proven mandatory server unlock gate.
- No validated specific ore payment for Sword Skill1/2/3; do not invent one.
- Future auto-skill should monitor SkillTree/proficiency/level and use validated skill/loadout APIs.

## Three Cave activities — validated live
All are **one-stage/one-room Round1 resource activities**. There may be several internal spawn groups, but there is no Story-style next room/gate traversal.

### Cave1 — Cave of Crystal
- WorldId `Cave1`; PlaceId `91584731222940`.
- Trial recommendation shown: Lv10 / Power480.
- Material role: Crystal Shards.
- Diagnostic first clear consumed 1 Ticket1 (`18 -> 17`).
- CrystalShards `3 -> 10` (+7 first clear); UI showed x1 first-clear + x6 normal Trial component.
- First production auto-clear passed: 56 targets, 0 deaths/damage, settlement ~29.89s, return Lobby, continuous Story loop remained healthy.

### Cave2 — Cave of Runes
- WorldId `Cave2`; PlaceId `119524374829397`.
- Trial recommendation shown: Lv13 / Power780.
- Material role: runes in `PlayerData.EnchantedStone.Owned`; observed ids/types include Burn_1 and Frost_1; screenshot also showed Burn/Methysis/Frost/Corrode.
- Diagnostic first clear consumed 1 Ticket1 (`17 -> 16`).
- Latest production test eventually settled, but user sometimes had to manually attack because enemies were far.
- Telemetry proved first useful target ~138 studs away and another final target ~101 studs away. The problem was approach distance, not Cave gates/rooms.

### Cave3 — Abandoned Courtyard
- WorldId `Cave3`; PlaceId `132445869992129`.
- Trial recommendation shown: Lv13 / Power940.
- Material role: pet-enhancement materials; screenshot showed Dragon Claw, Whole Scale, Broken Scale.
- Diagnostic first clear consumed 1 Ticket1 (`16 -> 15`).
- WholeDragonScale 0 -> 24 on first clear; UI showed x10 first-clear + x14 normal Trial component.

### Shared Cave architecture
- `WorldEnemys.RoundWakeTouch.Round1`.
- `WaveSpawnGroup.Round1_1/2/3` may exist internally.
- enemies under `Workspace.EnemyNpc`.
- completion: `GameRoundComplete=1`, `GameOver=true`, then `Player.Settlement=true`.
- No Story doors/portals are required for the core Cave clear.
- Observed Trial cost = **1 Ticket1 per run** for all three.

## Cave production V61.18
### `systems/cave.lua`
- Dedicated one-run Cave wrapper for all 3 validated PlaceIds.
- Reuses proven headless attack driver but owns Cave-specific movement/settlement policy.
- No automatic paid Play Again spam; one settlement -> Lobby.
- Saves pending reward baseline and Lobby reconciles authoritative reward after PlayerData readiness.
- Any Cave entry, manual or SMART, marks the SMART Cave cooldown so a manual test cannot immediately trigger another paid run.

### `systems/cave_chase.lua`
Fix for Cave2 manual-attack/far-enemy stall:
- Cave is treated as a one-room activity, not Story traversal.
- If no enemy is live and Round1 needs arming, tween into the Round1 wake.
- If nearest live Cave enemy is >45 studs away, smooth-tween directly to a safe ~7.5 stud horizontal / 8.5 stud elevated combat position.
- Uses speed ~300 studs/s, max move ~0.78s, then the proven combat attack driver owns damage.
- Logs `IronSoul_CaveChase_V61_18.txt`.
- This should cover the observed ~138-stud and ~101-stud Cave2 targets without manual attacks.

### Cave reward audit
- Cave-local PlayerData can lag settlement; local `RewardDelta=0` is not authoritative.
- `IronSoul_CavePending_V61_17.txt` persists baseline.
- Lobby `systems/cave_audit.lua` writes `IronSoul_CaveAudit_V61_17.txt` after authoritative PlayerData readiness.
- SMART planner writes `TicketBeforeEntry` before `CreatRoom`, making entry ticket delta authoritative.

## SMART Cave planner V61.18
`systems/cave_planner.lua` runs in Lobby **before** historical Story planner. If it declines, Lobby falls through unchanged to stable World1 progression.

Current conservative policy:
- only `TICKETS="SMART"`; `CAVE_AUTO=false` disables it.
- Trial difficulty only until higher-difficulty costs/rewards are validated live.
- reserve **5 Ticket1**; never spend below reserve.
- cooldown **360 seconds** between Cave runs so Story remains primary progression.
- eligibility from validated screens:
  - Cave1 Lv10/P480
  - Cave2 Lv13/P780
  - Cave3 Lv13/P940
- current temporary stock buffers (policy buffers, NOT claimed game upgrade costs):
  - CrystalShards target 18
  - rune/EnchantedStone count target 4
  - WholeDragonScale target 28
- Cave3 only considered when at least one pet is owned.
- Candidate is chosen by material deficit/priority, not fixed cave spam.
- Planner records `TicketBeforeEntry`, reward baseline, decision file, then reuses proven headless MatchRoom + `SelectWorld` + `CreatRoom` protocol.
- Decision log: `IronSoul_CavePlannerDecision_V61_18.txt`.
- Planner state: `IronSoul_CavePlanner_V61_18.txt`.

These stock targets are intentionally temporary. Replace them with actual Fortify/Enchant/Pet upgrade demand once those exact spending protocols/costs are validated.

## Material role / future scheduler direction
- Normal World stages: normal ores + XP/story progression; existing headless Forge consumes normal ore safely.
- Cave1: Crystal material reserve for gear/permanent upgrade demand.
- Cave2: rune stock for future Enchant automation.
- Cave3: pet-enhancement material stock when pets actually exist/need upgrades.
- Skill unlocking is not currently treated as a Cave-material need; validated evidence points to level + proficiency.
- Do not burn all Cave Tickets simply because tickets exist.

## Settlement / replay / inventory
- Equipment maintenance threshold 85.
- Full/high inventory at settlement -> Lobby immediately.
- Replay waits short/bounded; stuck/full replay -> Lobby.

## Luau compiler constraint
- Historical `systems/combat.lua` is near local-register ceiling; prior change caused `Out of local registers`.
- New substantial behavior belongs in external modules/wrappers. Do not stack large local-heavy combat patches.

## Lobby upgrades after Cave
- `FortifyUtil.Fortify` arity3.
- `EnchantmentUtil.Enchant` arity5; `UnEnchant` arity4.
- Concrete Equipment/Pets/Honor/Season remotes known; exact unattended mutation tuple still needs validation.
- Planned order after Cave stability: auto skill unlock/proficiency -> Blessing/Fortify -> Enchant -> pet growth -> Endless Tower.

## Next verification
1. Run Cave2 again with the normal loader and **do not manually attack**. Expect Cave chaser to tween to far targets and settle automatically.
2. Test Cave3 with same V61.18 one-room chase.
3. Observe Lobby SMART Cave decision after return; cooldown should normally send the immediate next cycle back to Story.
4. Send normal ZIP plus `IronSoul_CaveRun_V61_18.txt`, `IronSoul_CaveChase_V61_18.txt`, `IronSoul_CaveAudit_V61_17.txt` if present, and `IronSoul_CavePlannerDecision_V61_18.txt`.
5. Once Cave2/Cave3 no-manual clears pass, continue exact auto-skill + Fortify/Enchant protocol work.

## Workflow
- Diagnostic scripts are `.lua`; output/log files may be `.txt`.
- Production changes in GitHub; helpers fail closed.
