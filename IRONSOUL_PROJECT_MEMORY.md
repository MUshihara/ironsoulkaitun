# Iron Soul Kaitun — Compact Project Memory

## Goal
24/7 automatic **fresh account -> end progression**. Headless/API-first, fast, low CPU/RAM. No normal clicking.

## Stable foundation
- Tutorial `76701861705540`; Lobby `117533937949084`.
- World1 V61.15 stable/frozen after repeated fresh-account D1/D2/D3 clears and four consecutive clean D3 matches.
- World1 movement = smooth fast CFrame tween/floating, never Humanoid walking for traversal.
- `dungeon_route_mapper.lua` owns live place-aware Story routing; raw movement/crossed-plane is never progression proof.
- Headless Forge, EquipBest/smart cleanup, pet hatch/claim/equip validated.
- Latest forge proof: `MEASURED_RESERVE_BEST_ORE`, ores `93/100 -> 28/100`, 9 crafts, Power `755 -> 1197` (+442).
- Fresh Lobby: `PlayerData.LevelData.Level` is authoritative if `LG_Level` is nil; resolve/mirror only in preflight.

## Cave activities — STABLE BASELINE INCLUDING MOBILE
All three are **one-room Round1 resource activities**. No Story door/portal traversal is required.

### Cave1 — Cave of Crystal
- WorldId `Cave1`; PlaceId `91584731222940`; Trial shown Lv10/P480.
- Material: Crystal Shards. Observed Trial cost: 1 Ticket1.
- First production auto-clear: 56 targets, 0 deaths/damage, settlement ~29.89s.

### Cave2 — Cave of Runes
- WorldId `Cave2`; PlaceId `119524374829397`; Trial shown Lv13/P780.
- Material: runes in `PlayerData.EnchantedStone.Owned`.
- V61.19 mobile validation: **30 targets, 0 deaths, 0 damage, settlement 29.41s**.
- Startup ordering correct: ARMED -> COMBAT_READY -> ACTIVE. No movement before controller readiness.
- Distant target ~107 studs handled automatically.

### Cave3 — Abandoned Courtyard
- WorldId `Cave3`; PlaceId `132445869992129`; Trial shown Lv13/P940.
- Materials: Dragon Claw / Whole Scale / Broken Scale family; WholeDragonScale validated in PlayerData.
- V61.19 mobile validation: **40 targets, 0 deaths, 0 damage, settlement 44.40s**.
- Distant targets ~141/~108/~128 studs handled automatically.

### Cave runtime
- `systems/cave.lua`: one Cave run -> settlement -> Lobby; no paid replay spam.
- `systems/cave_chase.lua` V61.19 waits for current-run combat-controller readiness, then living/stable character, then enables far-enemy tween chase.
- Basic Cave combat is now stable/mobile-safe baseline unless new evidence appears.

## SMART Cave planner
- `systems/cave_planner.lua` runs before Story planner and fails closed to Story.
- Trial only for now; reserve 5 Ticket1; 360s cooldown.
- Temporary policy buffers, not game costs: Crystal Shards 18, runes 4, WholeDragonScale 28; Cave3 only if pet owned.
- Replace these buffers with exact upgrade-demand formulas after Fortify/Enchant/Pet protocols are automated.

## Skill Tree — PROTOCOL RECON COMPLETE
Lobby recon at **Lv16 / Power1713**:
- `PlayerData.SkillTree.WpnProfs.Sword = 17874`.
- Server already granted Sword `UnlockSkill1..4=true`; all four Active on recon account.
- Fist/Greatsword/Heavy/Sickle/Staff each had server-granted `UnlockSkill1=true`.
- `TryUnlockSkill` references player Level + weapon proficiency; `CanUnlockSkill` checks branch `NeedLv`; `HasEnoughWpnProf` checks proficiency.
- **No ore/crystal/currency/material cost appears in the actual level-skill unlock path.** Gray/The Guide is tutorial/UI context, not a proven payment gate.
- Server automatically populates `PlayerData.SkillTree.Unlock`; do not force speculative unlock commands.

### Skill activation production V61.20.1 — PASSED
- `systems/skill_manager.lua` activates only server-granted `UnlockSkillN=true` branches using `RemoteEvent("ActiveSkill", classId, key)` and verifies `PlayerData.SkillTree.Active`.
- Latest test: **9 server-unlocked branches, 5 newly activated, 4 already active, 0 failed**.
- Newly activated non-Sword Skill1 branches included Fist, Greatsword, Heavy, Sickle and Staff.
- Skill Tree activation is separate from the equipped combat loadout.

## Weapon-aware best combat loadout V61.21
Prior V43.1 validation recovered exact protocol:
- explicit state: `PlayerData.WeaponSkill.Equipped[class][slot]`;
- effective state: `WeaponUtil:GetWeaponSkillId(player, weaponId, slot)`;
- eligibility: `WeaponUtil:CanEquipSkill(player, weaponId, slot, skillId)`;
- write: `WeaponUtil.RemoteEvent:FireServer("EquipSkill", weaponId, slot, skillId)`;
- active weapon: `WeaponUtil:GetEquippedWeaponClass/GetEquippedWeaponId`.

Production:
- `systems/skill_loadout_manager.lua` V61.21 runs from the small `systems/combat.lua` entry wrapper, after Lobby equipment choice and before historical combat-controller initialization.
- This avoids the ordering bug where an early Lobby loadout could be invalidated by a later EquipBest/equipment change.
- Candidate pool is live `ResSkillTree[class]`: native Skill1/Skill2/SkillU plus only level branches that are both server-unlocked and active.
- `ResSkillTree` mappings are weapon-specific (Sword, Staff, Heavy, Sickle, Fist, Greatsword; Bow currently may expose empty level entries).
- Basic candidates compete for Skill1 + Skill2; Ultimate candidates compete for SkillU.
- Scoring uses live `ResSkill`/`ResSkillStage` + WeaponUtil data: damage events, effective cooldown, action time, range, charge cost, mitigation. It does not assume later-numbered skill = better.
- `CanEquipSkill` remains authoritative for slot compatibility; every equip mutation is verified with `GetWeaponSkillId`.
- Failure is fail-closed: keep existing loadout and continue combat.
- Cave V61.19 safety is preserved: its chaser remains armed/motionless while loadout maintenance runs and only moves after combat-controller readiness.
- Log: `IronSoul_SkillLoadout_V61_21.txt`.
- Next test: normal Story or Cave run; verify correct `WeaponClass`, SelectedSkill1/2/U, `Failed=0`, and normal combat/settlement.

## Settlement / replay / inventory
- Equipment maintenance threshold 85.
- Full/high inventory at settlement -> Lobby immediately.
- Replay waits short/bounded; stuck/full replay -> Lobby.

## Luau compiler constraint
- Historical `systems/combat.lua` is near local-register ceiling; a prior change caused `Out of local registers`.
- Substantial new behavior belongs in external modules/wrappers, not local-heavy combat patches.

## Next progression work
Known recon surfaces:
- `FortifyUtil.Fortify` arity3.
- `EnchantmentUtil.Enchant` arity5; `UnEnchant` arity4.
- Pet growth modules/remotes mapped (`PetsFortifyUtil`, `PetsUpgradeUtil`).

Recommended order:
1. **Verify V61.21 loadout once** with `IronSoul_SkillLoadout_V61_21.txt` and normal combat logs.
2. Fortify/Blessing protocol + conservative spending.
3. Enchant exact mutation tuple + rune-demand-aware Cave2 scheduler.
4. Pet growth + Cave3 demand-aware scheduler.
5. Endless Tower.

## Reliability / workflow
- Diagnostics are `.lua`; logs/results may be `.txt`.
- Production changes in GitHub; helpers fail closed.
- Keep memory operational/compact.
- World2 active movement remains frozen until deliberately revisited; never reuse World1 coordinates/door assumptions there.
