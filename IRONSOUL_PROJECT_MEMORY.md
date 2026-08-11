# Iron Soul Kaitun — Compact Project Memory

## Goal
24/7 automatic **fresh account -> end progression**. Headless/API-first, fast, low CPU/RAM. No normal clicking.

## Current focus
**World1 V61.15 is stable/frozen. Next major production target is the three Cave activities and a SMART Cave Ticket/material scheduler.** World2 active movement remains frozen.

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
- Trial clear: **76 kills, 1m56s**.
- One run consumed exactly **1 Ticket1**: `18 -> 17`.
- `PlayerData.Crystals.CrystalShards`: `3 -> 10` = **+7 total** on first clear.
- Settlement UI decomposed this as **x1 First Clear + x6 normal Trial reward**. Therefore a repeat Trial should not assume +7; normal displayed component was x6.
- Currency1 `43790 -> 44072` (+282); XP `36913 -> 37177` (+264) in this observed clear.

### Cave2 — Cave of Runes
- `WorldId=Cave2`.
- PlaceId `119524374829397`.
- Screenshot recommendation: **Lv13 / Power780**.
- Possible Lv1 rune drops shown: **Burn, Methysis, Frost, Corrode** (use exact live item ids from PlayerData/config when automating; screenshot spelling may differ from internal ids).
- Trial clear: **78 kills, 52s**.
- One run consumed exactly **1 Ticket1**: `17 -> 16`.
- Before: one `Burn_1`; after: two new `Frost_1` entries. Settlement UI showed **x1 Frost First Clear + x1 Frost normal reward** in this clear.
- Currency1 `44072 -> 44346` (+274); XP `37177 -> 37574` (+397).
- Runes live in `PlayerData.EnchantedStone.Owned` with ids/types such as `Burn_1`, `Frost_1`.

### Cave3 — Abandoned Courtyard
- `WorldId=Cave3`.
- PlaceId `132445869992129`.
- Screenshot recommendation: **Lv13 / Power940**.
- Possible drops shown: **Dragon Claw, Whole Scale, Broken Scale**.
- Trial clear: **75 kills, 59s**.
- One run consumed exactly **1 Ticket1**: `16 -> 15`.
- `PlayerData.Crystals.WholeDragonScale`: absent/0 -> **24** on first clear.
- Settlement UI decomposed this as **x10 First Clear + x14 normal Trial reward**.
- Currency1 `44349 -> 44600` (+251); XP `37584 -> 37956` (+372).

### Shared Cave architecture
All 3 Cave Trial runs are structurally much simpler than Story World1:
- one authoritative room/round only;
- `WorldEnemys.RoundSpawnGroup.Round1`;
- `WorldEnemys.RoundWakeTouch.Round1`;
- `WaveSpawnGroup.Round1_1`, `Round1_2`, `Round1_3` (three wave spawn groups observed);
- `PlayerRespawn.Round1`;
- combat enemies under `Workspace.EnemyNpc`;
- completion observed as `GameRoundComplete=1`, `GameOver=true`, then `Player.Settlement=true`;
- no multi-room World1-style gate traversal is required for the core Cave clear;
- replicated configs expose `ResRoundEnemy_Cave1`, `ResRoundEnemy_Cave2`, `ResRoundEnemy_Cave3` and `WorldUtil` contains Cave1/Cave2/Cave3 tables;
- `GameRoundRE`, `GameMatchRE`, matchmaking remotes are present.

### Cave matchmaking
The proven Lobby base already creates solo rooms generically with:
`GameMatchRE:FireServer("CreatRoom", target.WorldId, target.DiffLevel, 1)`.
This means Cave1/Cave2/Cave3 should be able to reuse the same **headless solo room creation protocol**, subject to live eligibility/ticket checks. Do not build GUI clicking for cave entry.

### Cave Ticket policy
`Ticket1` is confirmed as the shared Cave-entry currency for these observed Trial runs, at exactly **1 ticket per run**.
Do not blindly burn all tickets. Planned SMART policy should reserve/spend according to account bottleneck:
1. Cave1 for Crystal Shards when permanent/skill/upgrade material stock needs it;
2. Cave2 when Enchant/rune stock is needed;
3. Cave3 when pet-growth materials are needed;
4. otherwise preserve tickets and continue World progression.
Exact higher-difficulty costs/rewards are not yet validated; start automation on Trial only.

## Cave automation recommendation
- Build a **dedicated `systems/cave.lua` / Cave mode**, not another local-heavy combat patch.
- Cave combat can reuse proven headless attack/skill principles, but its state machine should be one-room/three-wave -> settlement -> return/repeat policy, with no World1 route mapper dependence.
- First production milestone: auto-enter Cave1 Trial headlessly, clear one run, verify reward/ticket delta, return Lobby.
- Then validate Cave2 and Cave3 using the same Cave engine with only WorldId/reward-policy differences.
- Only after all three pass should Lobby SMART scheduler spend tickets autonomously.

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
2. Implement dedicated Cave mode with the 3 validated PlaceId/WorldId mappings.
3. First live automation test: Cave1 Trial, one ticket/one run, verify `Ticket1 -1` and CrystalShards reward, return Lobby.
4. Then Cave2 Trial and Cave3 Trial.
5. After all three pass, integrate a SMART ticket/material scheduler into Lobby.
