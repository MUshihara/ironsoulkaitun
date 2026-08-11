# Iron Soul Kaitun — Compact Project Memory

## Goal
24/7 automatic **fresh account -> end progression**. Headless/API-first, fast, low CPU/RAM. No normal clicking.

## Current focus
**World1 V61.15 is stable/frozen. Current production target is the three Cave activities and a SMART Cave Ticket/material scheduler.** World2 active movement remains frozen.

## Proven baseline
- Tutorial `76701861705540`; Lobby `117533937949084`; validated World1 dungeon `116456628154258`.
- Multiple fresh accounts proved W1 D1/D2/D3 progression and settlement.
- V61.15 evidence: 4 consecutive completed W1 D3 matches with no route failure.
- Normal World1 combat/traversal is baseline; do not retune casually.
- Headless Forge, EquipBest/smart cleanup, pet hatch/claim/equip validated.

## Latest Forge proof
- Mode `MEASURED_RESERVE_BEST_ORE`.
- Ores `93/100 -> 28/100` in 9 crafts.
- Power `755 -> 1197` (+442).
- Equipment inventory `8 -> 17`.
Keep forge logic unless an actual forge failure appears.

## Fresh Lobby truth
- PlayerData can be ready while fresh `LG_Level=nil`.
- Authoritative fresh level is `PlayerData.LevelData.Level`.
- Resolve/mirror level in lobby preflight only; do not add another fresh-level patch.

## Skill Tree truth
- `PlayerData.SkillTree` is authoritative.
- Unlock progression is driven by player level + weapon proficiency; Staff evidence observed `UnlockSkill3` at Level10 / Proficiency2000.
- Gray / “The Guide” was involved in tutorial/UI, but was not proven to be a mandatory server-side unlock gate.
- No validated prior evidence identifies a specific ore payment for Sword Skill1/2/3. Do not invent one.
- Future auto-skill should watch SkillTree + proficiency/level and use validated skill/loadout APIs.

## World1 movement/traversal — CRITICAL
- Smooth fast CFrame tween/floating, never normal Humanoid walking for traversal.
- `systems/world1_motion.lua`: ~210 studs/sec normal, ~260 long traversal.
- 0.60s pre-portal settle before first touch/cross.
- Never generic RoundPortal RF; raw movement/crossed-plane is never progression proof.
- V61.15 live route mapper learns PlaceId/WorldId/Diff/GameRound/wakes/doors/Portal* and fails closed to Lobby on bounded route failure.

## THREE CAVE ACTIVITIES — VALIDATED LIVE 2026-08-12
User ran one full Trial clear in each Cave on the same Level16 / Power1485 account. Diagnostics were `FULL_LOBBY_RECON_R1` executed inside each cave, but captured sufficient live PlayerData/UI/modules/events.

### Cave1 — Cave of Crystal
- `WorldId=Cave1`.
- PlaceId `91584731222940`.
- Screenshot recommendation: **Lv10 / Power480**.
- Possible drop shown: **Crystal Shards**.
- Diagnostic Trial clear: **76 kills, 1m56s**.
- One diagnostic run consumed exactly **1 Ticket1**: `18 -> 17`.
- `PlayerData.Crystals.CrystalShards`: `3 -> 10` = **+7 total** on first clear.
- Settlement UI decomposed this as **x1 First Clear + x6 normal Trial reward**. Therefore a repeat Trial should not assume +7; normal displayed component was x6.
- Currency1 `43790 -> 44072` (+282); XP `36913 -> 37177` (+264) in that observed clear.

### Cave2 — Cave of Runes
- `WorldId=Cave2`.
- PlaceId `119524374829397`.
- Screenshot recommendation: **Lv13 / Power780**.
- Possible Lv1 rune drops shown: **Burn, Methysis, Frost, Corrode**; use internal ids from PlayerData/config when automating.
- Diagnostic Trial clear: **78 kills, 52s**.
- One diagnostic run consumed exactly **1 Ticket1**: `17 -> 16`.
- Before: one `Burn_1`; after: two new `Frost_1` entries. Settlement UI showed **x1 Frost First Clear + x1 Frost normal reward**.
- Currency1 `44072 -> 44346` (+274); XP `37177 -> 37574` (+397).
- Runes live in `PlayerData.EnchantedStone.Owned` with ids/types such as `Burn_1`, `Frost_1`.

### Cave3 — Abandoned Courtyard
- `WorldId=Cave3`.
- PlaceId `132445869992129`.
- Screenshot recommendation: **Lv13 / Power940**.
- Possible drops shown: **Dragon Claw, Whole Scale, Broken Scale**.
- Diagnostic Trial clear: **75 kills, 59s**.
- One diagnostic run consumed exactly **1 Ticket1**: `16 -> 15`.
- `PlayerData.Crystals.WholeDragonScale`: absent/0 -> **24** on first clear.
- Settlement UI decomposed this as **x10 First Clear + x14 normal Trial reward**.
- Currency1 `44349 -> 44600` (+251); XP `37584 -> 37956` (+372).

### Shared Cave architecture
All 3 Cave Trial runs are much simpler than Story World1:
- one authoritative room/round only;
- `WorldEnemys.RoundSpawnGroup.Round1`;
- `WorldEnemys.RoundWakeTouch.Round1`;
- `WaveSpawnGroup.Round1_1`, `Round1_2`, `Round1_3`;
- `PlayerRespawn.Round1`;
- enemies under `Workspace.EnemyNpc`;
- completion: `GameRoundComplete=1`, `GameOver=true`, then `Player.Settlement=true`;
- no multi-room World1 gate traversal needed;
- replicated configs expose `ResRoundEnemy_Cave1/2/3`; `WorldUtil` contains Cave1/Cave2/Cave3 tables.

### Cave matchmaking
Proven Lobby creates solo rooms generically with:
`GameMatchRE:FireServer("CreatRoom", target.WorldId, target.DiffLevel, 1)`.
Cave1/2/3 should reuse the same headless solo-room protocol with eligibility/ticket checks. Do not build GUI clicking.

### Cave Ticket policy
`Ticket1` is confirmed shared Cave-entry currency for observed Trial runs, **1 ticket per run** in the diagnostics.
Do not blindly burn all tickets. Planned SMART policy:
1. Cave1 for Crystal Shards when material stock needs it;
2. Cave2 when Enchant/rune stock is needed;
3. Cave3 when pet-growth materials are needed;
4. otherwise preserve tickets and continue World progression.
Higher-difficulty costs/rewards are not yet validated; start automation on Trial only.

## Cave production — V61.16/V61.17
Dedicated `systems/cave.lua` exists; Cave PlaceIds redirect through it while reusing proven headless combat underneath.

### Cave1 first production automation pass — PASSED
User ran Cave1 with the normal loader after V61.16:
- Cave recognized correctly as PlaceId `91584731222940`, D1.
- **56 targets completed**.
- **0 deaths, 0 damage, 0 gate/watchdog activity**.
- Settlement detected in **29.89s** combat telemetry.
- Cave wrapper returned to Lobby; Lobby readiness then passed at **Level16 / Power1713**.
- The continuous planner stayed alive and launched the next World1 D4 run.
Therefore Cave one-room combat + one-run return-to-Lobby policy is production-proven for Cave1.

### Cave reward audit timing lesson — V61.17
The first production Cave1 local file showed `TicketDelta=0` / `RewardDelta=0` because Cave-local PlayerData was sampled too early. This is an **audit timing issue**, not a combat/settlement failure.
- V61.17 writes `IronSoul_CavePending_V61_17.txt` before Cave settlement.
- Cave still returns Lobby quickly; do not hold Victory open just for logging.
- After normal Lobby PlayerData readiness, `systems/cave_audit.lua` resolves the actual material delta and writes `IronSoul_CaveAudit_V61_17.txt`.
- `TicketBeforeEntry` becomes authoritative only once the future SMART Lobby planner records it **before `CreatRoom`**. Cave-local `TicketAtCaveStart` may already be after ticket consumption.

## Settlement / replay / inventory
- Equipment maintenance threshold = 85.
- Full ore/equipment bag or inventory >=85 at settlement -> skip replay, return Lobby immediately.
- Replay windows short/bounded; no public same-PlaceId fallback.

## Luau local-register ceiling
- Historical `systems/combat.lua` is near Luau local-register limit.
- Future substantial logic belongs in external modules/wrappers. Do not add large local-heavy combat patches.

## Lobby upgrades waiting after Cave
- `FortifyUtil.Fortify` arity3; `EnchantmentUtil.Enchant` arity5; `UnEnchant` arity4.
- Concrete Equipment/Pets/Honor/Season remotes known, but exact Fortify/Enchant outbound tuple is not yet validated.
- After Cave material farming is stable: auto skill unlock/proficiency -> Blessing/Fortify -> Enchant -> pet growth -> Endless Tower.

## World2 retained while frozen
- World2 D1 PlaceId `136216144170036`, MaxRound6, PortalD exists.
- DestructibleObject/HitCount alone never proves objective; active movement stays disabled until revisited.

## Workflow
- Diagnostic scripts in chat are `.lua`; results/logs may be `.txt` in ZIPs.
- Production fixes in GitHub; helpers fail closed.

## Next
1. Keep V61.15 World1 frozen.
2. **Test Cave2 Trial with V61.17 normal loader**: one run only, automatic clear -> Lobby; inspect `IronSoul_CaveRun_V61_17.txt` and post-Lobby `IronSoul_CaveAudit_V61_17.txt`.
3. Test Cave3 Trial the same way.
4. After all 3 Cave production runs pass, add SMART Lobby scheduler with pre-entry Ticket1 baseline and resource-aware Cave selection.
5. Then resume auto skill unlock/proficiency -> Fortify/Blessing -> Enchant -> pet growth -> Endless Tower.
