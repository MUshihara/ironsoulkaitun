# Iron Soul Kaitun — Compact Project Memory

## Goal
24/7 automatic **fresh account -> end progression**. Headless/API-first, fast, low CPU/RAM. No normal clicking.

## Stable foundation
- Tutorial `76701861705540`; Lobby `117533937949084`.
- World1 V61.15 routing stable/frozen after repeated fresh-account D1/D2/D3 clears and four consecutive clean D3 matches.
- World1 movement = smooth fast CFrame tween/floating, never Humanoid walking for traversal.
- `dungeon_route_mapper.lua` owns live place-aware Story routing; raw movement/crossed-plane is never progression proof.
- Headless Forge, EquipBest/smart cleanup, pet hatch/claim/equip validated.
- Latest forge proof: ores `93/100 -> 28/100`, 9 measured crafts, Power `755 -> 1197` (+442).
- Fresh Lobby: `PlayerData.LevelData.Level` authoritative if `LG_Level` nil; mirror only in preflight.

## Cave — STABLE MOBILE BASELINE
- Cave1 Crystal `91584731222940`: Crystal Shards; Trial Lv10/P480; 1 Ticket1 observed; production clear 56 targets, 0 deaths/damage, ~29.89s.
- Cave2 Runes `119524374829397`: runes; Trial Lv13/P780; V61.19 mobile clear 30 targets, 0 deaths/damage, 29.41s.
- Cave3 Courtyard `132445869992129`: dragon-scale pet materials; Trial Lv13/P940; V61.19 mobile clear 40 targets, 0 deaths/damage, 44.40s.
- All are one-room Round1. `cave_chase.lua` waits for combat-controller readiness before moving, then handles far enemies. One run -> Lobby; no paid replay spam.
- SMART Cave: Trial only, reserve 5 Ticket1, 360s cooldown, temporary stock buffers until exact upgrade demand is automated.

## Skill Tree V61.20.1 — PASSED
- Unlock path is Level + weapon proficiency. No validated ore/crystal/currency payment in Level Skill unlocks.
- Server populates `PlayerData.SkillTree.Unlock`; do not force speculative unlocks.
- `systems/skill_manager.lua` activates only server-granted branches and verifies `SkillTree.Active`.
- Latest test: 9 server-unlocked branches, 5 newly activated, 4 already active, 0 failed.

## Weapon-aware loadout V61.21 — EQUIP PATH PASSED
- Exact write: `WeaponUtil.RemoteEvent:FireServer("EquipSkill", weaponId, slot, skillId)`.
- Validate with `CanEquipSkill`; verify with `GetWeaponSkillId`.
- `systems/skill_loadout_manager.lua` runs after Lobby equipment choice and before combat controller.
- Latest D4: Sword `Single_Gray`; selected/equipped/verified Skill1 `Single_Skill_1`, Skill2 `Single_Skill_2`, SkillU `Ashwarden_Skill_US`; Failed=0.
- Skill Tree activation and equipped combat loadout are separate systems.

## V61.22 BASIC ATTACK + ULTIMATE FIX — CURRENT TEST TARGET
Latest D4 after V61.21 exposed an **old calibration flaw**, not a loadout-write failure:
- telemetry showed Skill2/Skill1 casts, then repeated `TARGET_HIT_STALL`; HP mostly resumed when skills returned; one 261-HP enemy sat close for >8s.
- historical fight loop cast skills before the first BaseAttack calibration.
- `calibrateHeadless` had only one ~1s HP test. If a skill action window contaminated it, it permanently set `AttackDriverMode=HEADLESS_FAILED`.
- `basicAttack()` explicitly does nothing in HEADLESS_FAILED, while skills continue. This exactly explains skills-only combat.

Fix is **in-place update** of existing `systems/patches/combat_v61_8_skill_telemetry.patch`; do not add another combat patch:
- UNTESTED BaseAttack gets first priority before Skill1/Skill2/SkillU.
- calibration waits out `SkillCastingUntil`, sends proven direct four-step BaseAttack combo, verifies real HP.
- one failed sample no longer permanently disables basics; keep `HEADLESS_REMOTE` and let existing no-damage watchdog/headlessRecovery retry.
- still **NO Mouse1 fallback**.
- telemetry: `BASIC_DRIVER | VERIFIED` or `BASIC_DRIVER | UNVERIFIED_RETRY attempt=N`.

### Ultimate / SkillU truth
- SkillU is **charge-based**, not merely a third normal cooldown skill.
- live `ResSkill` config has `GenerateCharge` on BaseAttack/basic skills and required `Charge` on Ultimate skills.
- current equipped `Ashwarden_Skill_US` requires `Charge=80`; older `Single_Skill_U` requires 40.
- basic attacks therefore contribute to both ordinary DPS and filling Ultimate charge.
- V61.22 discovers native SkillU callback and only attempts it against boss/high-HP targets; the native game callback/server remains authoritative on charge availability. No charge bypass/spoof.
- old Sword V51 recon already discovered native SkillU and noted charge can reject a not-ready cast.

## Settlement / replay / inventory
- Equipment maintenance threshold 85; full/high inventory -> Lobby.
- Replay waits bounded; stuck/full replay -> Lobby.

## Luau/compiler reliability
- historical combat chunk near local-register ceiling; prior change hit `Out of local registers`.
- update existing patches/modules in place; substantial behavior external when possible.
- V61.22 adds no new combat patch layer.

## Next progression work
1. Retest normal loader after V61.22: expect BASIC_DRIVER proof, rapid normal HP loss between skill cooldowns, no long TARGET_HIT_STALL, SkillU only on boss/high-HP when native charge permits.
2. Then Fortify/Blessing exact protocol + conservative spending.
3. Enchant + rune-demand-aware Cave2.
4. Pet growth + Cave3 demand.
5. Endless Tower.

World2 active movement remains frozen until deliberately revisited; never reuse World1 coordinates/door assumptions there.
