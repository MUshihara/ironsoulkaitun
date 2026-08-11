# Iron Soul Kaitun — Compact Project Memory

## Goal
24/7 automatic **fresh account -> end progression**. Headless/API-first, fast, low CPU/RAM. No normal clicking.

## Stable foundation
- Tutorial `76701861705540`; Lobby `117533937949084`.
- World1 V61.15 stable/frozen after repeated fresh-account D1/D2/D3 clears and 4 consecutive clean D3 matches.
- World1 movement = smooth fast CFrame tween/floating, never Humanoid walking for traversal.
- `dungeon_route_mapper.lua` owns live place-aware Story routing; raw movement/crossed-plane is never progression proof.
- Headless Forge, EquipBest/smart cleanup, pet hatch/claim/equip validated.
- Latest forge proof: `MEASURED_RESERVE_BEST_ORE`, ores `93/100 -> 28/100`, 9 crafts, Power `755 -> 1197` (+442).
- Fresh Lobby: `PlayerData.LevelData.Level` is authoritative if `LG_Level` is nil; resolve/mirror only in preflight.

## Cave activities — STABLE BASELINE
All three are **one-room Round1 resource activities**. No Story door/portal traversal is required.

### Cave1 — Cave of Crystal
- WorldId `Cave1`; PlaceId `91584731222940`; Trial shown Lv10/P480.
- Material: Crystal Shards.
- Trial observed cost: 1 Ticket1.
- First production auto-clear passed: 56 targets, 0 deaths/damage, settlement ~29.89s.

### Cave2 — Cave of Runes
- WorldId `Cave2`; PlaceId `119524374829397`; Trial shown Lv13/P780.
- Material: runes in `PlayerData.EnchantedStone.Owned`.
- V61.19 validation on mobile/normal loader: **30 targets, 0 deaths, 0 damage, settlement 29.41s**.
- Startup ordering correct: ARMED -> COMBAT_READY -> ACTIVE. No movement before controller readiness.
- First live target could be ~158 studs away; final target ~107 studs. Cave chaser handled the distant target automatically.

### Cave3 — Abandoned Courtyard
- WorldId `Cave3`; PlaceId `132445869992129`; Trial shown Lv13/P940.
- Materials: Dragon Claw / Whole Scale / Broken Scale family; WholeDragonScale validated in PlayerData.
- V61.19 validation on mobile/normal loader: **40 targets, 0 deaths, 0 damage, settlement 44.40s**.
- Chaser automatically handled distant targets ~49, 70, 66, 141, 108, 59 and 128 studs away.

### Cave runtime V61.19
- `systems/cave.lua`: one Cave run -> settlement -> Lobby; no paid replay spam.
- `systems/cave_chase.lua`: movement is armed but disabled until current combat telemetry proves `START | controller initialized`; then waits for living/stable character + short settle before moving.
- This fixes V61.18 startup race where Cave movement could enter enemy packs before headless attacks loaded.
- Far enemy threshold ~45 studs; smooth CFrame chase to safe elevated combat position.
- Cave2 + Cave3 V61.19 are now validated on mobile with zero deaths/damage. Treat basic Cave combat as stable unless new evidence appears.

## SMART Cave planner V61.18
- `systems/cave_planner.lua` runs in Lobby before Story planner; falls through unchanged if no useful Cave run.
- Trial only for now; reserve 5 Ticket1; 360s cooldown; one paid Cave run at a time.
- Temporary policy buffers, not claimed upgrade costs: Crystal Shards 18, runes 4, WholeDragonScale 28.
- Cave3 considered only when at least one pet is owned.
- Future improvement: replace static buffers with exact material demand from validated Fortify/Enchant/Pet upgrade formulas.

## Skill Tree truth / NEXT TARGET
- Current historical Lobby already requires `SkillTreeUtil` and automatically **activates** any `PlayerData.SkillTree.Unlock.Sword.UnlockSkill1..7` that are true using:
  `SkillTreeUtil.RemoteEvent:FireServer("ActiveSkill", "Sword", key)`.
- Therefore skill activation is already partly automatic; what is still missing is a deliberate headless **unlock/eligibility protocol** and generalization beyond Sword.
- Live `SkillTreeUtil` exposes: `TryUnlockSkill`, `CanUnlockSkill`, `UpdateUnlockSkill`, `TryActiveSkill`, `IsUnlockSkill`, `IsActiveSkill`, `GetSkillTreeInfo`, `GetUnlockData`, `GetActiveData`, `HasEnoughWpnProf`, `GetWpnProfById`, `AddWpnProf`, `Start`.
- `PlayerData.SkillTree` is authoritative. Existing evidence points to level + weapon proficiency; Staff evidence had UnlockSkill3 at Level10 / Proficiency2000.
- Gray/The Guide was tutorial/UI flow, not proven mandatory server unlock gate.
- No validated specific ore payment for Sword Skill1/2/3. Do not invent one.
- Next diagnostic: `IronSoul_SkillTree_Unlock_Protocol_Recon_R1.lua` in Lobby. Use it to recover exact function arity/constants/config requirements before enabling unattended unlock mutation.

## After Skill Tree
1. Automatic skill unlock/proficiency + best skill activation/loadout.
2. Fortify/Blessing protocol and conservative spending.
3. Enchant using Cave2 rune demand.
4. Pet growth using Cave3 materials.
5. Endless Tower state machine/reward planner.

## Reliability rules
- Historical `systems/combat.lua` is near Luau local-register ceiling; substantial behavior belongs in external modules/wrappers.
- Diagnostics are `.lua`; logs/results may be `.txt`.
- Production fixes in GitHub; helpers fail closed.
- World2 active movement remains frozen until deliberately revisited; do not reuse World1 coordinates/door assumptions there.
