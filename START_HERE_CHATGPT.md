# Iron Soul Kaitun — START HERE

Read this, then `IRONSOUL_PROJECT_MEMORY.md`, then inspect current repo. Long changelog is optional.

## Non-negotiable
- 24/7 **fresh account -> end progression**.
- **Headless/API-first:** remotes/modules/server state; no normal mouse/GUI clicking.
- **World1 movement = fast smooth CFrame tween/floating, NOT Roblox walking.** Do not use `Humanoid:MoveTo`/`Humanoid:Move` for gate/portal traversal.
- Tween toward exact/current progression, dwell about **0.60s before final portal touch/cross**, and require authoritative evidence.
- Movement/crossed-plane/raw displacement alone is never progression proof.
- Preserve proven World1 combat/forge unless evidence requires change.
- Historical `combat.lua` is near Luau's local-register ceiling: substantial new logic belongs in external modules/wrappers.
- Diagnostics are downloadable `.lua`; result/log files may be `.txt`.

## Fresh Lobby truth
- Lobby `117533937949084` is the progression brain.
- Fresh PlayerData may be ready while `LG_Level=nil`; real level is `PlayerData.LevelData.Level`.
- Handle this in preflight, not another lobby patch.

## Proven World1 loop
Fresh accounts have progressed repeatedly through World1 D1/D2/D3. V61.15 routing is baseline; do not casually retune normal World1 combat/traversal.

## V61.15 dungeon routing
- `systems/dungeon_route_mapper.lua` is the live place-aware route layer.
- **World1 and World2 do NOT share one physical Workspace layout.** Every PlaceId/server has its own Workspace tree; never share coordinates/door assumptions across places.
- Mapper discovers live `GameRound`, `RoundWakeTouch.RoundN`, Door/Portal* roots, RoundNum/Switch, objectives and streamed transitions for the current PlaceId/World/Diff.
- World1 active recovery; World2 discovery/logging only while World2 remains frozen.
- Wrong-round historical gates/portals remain rejected; bounded repeated route failure rebuilds through Lobby.

## D3 route facts
- Correct progression: `Round4 -> Round5 -> Round6 -> Round7 boss`.
- Reused section Portal once sent character physically to Round7 while server was still Round5; raw displacement is not success.
- `GameRound=7` can occur before `RoundWakeTouch.Round7` streams. V61.15 frontier probing handles this.
- Round7 is valid only when authoritative `GameRound==7`.

## Cave architecture — VALIDATED INCLUDING MOBILE
- Cave1 / Crystal: PlaceId `91584731222940`, Trial Lv10/P480, Crystal Shards.
- Cave2 / Runes: PlaceId `119524374829397`, Trial Lv13/P780, runes in `PlayerData.EnchantedStone.Owned`.
- Cave3 / Abandoned Courtyard: PlaceId `132445869992129`, Trial Lv13/P940, dragon-scale pet materials.
- All three are **one-room Round1 resource activities**; no Story doors/portals/next-room traversal.
- Observed Trial cost = 1 `Ticket1` per run.
- `systems/cave_chase.lua` owns far-enemy approach and must never move before combat-controller readiness.
- V61.19 waits for current-run combat telemetry readiness, then a living/stable character, then activates tween chase.
- Latest no-manual validation:
  - Cave2: **30 targets, 0 deaths, 0 damage, settlement ~29.41s**; far final target ~107 studs handled automatically.
  - Cave3: **40 targets, 0 deaths, 0 damage, settlement ~44.40s**; distant targets ~141/~108/~128 studs handled automatically.
- User ran these on mobile; same headless controller/CFrame path produced the same successful behavior. Treat basic Cave combat as mobile-safe baseline unless new evidence contradicts it.
- One Cave settlement -> Lobby; no paid replay spam.

## SMART Cave scheduler
- `systems/cave_planner.lua` runs before historical Story planner.
- Trial only for now; keep 5 Ticket1 reserved; cooldown 360s so Story remains primary progression.
- Temporary policy buffers: Crystal Shards 18, runes 4, Whole Dragon Scale 28; Cave3 only if a pet is owned.
- These are policy buffers, not claimed game upgrade costs. Replace with actual upgrade-demand calculations when Fortify/Enchant/Pet protocols are automated.

## Skill Tree truth — RECON VALIDATED 2026-08-12
- `PlayerData.SkillTree` is authoritative.
- Skill protocol recon at Lv16/P1713 found Sword proficiency `17874` and server-granted Sword `UnlockSkill1..4=true`.
- `SkillTreeUtil.TryUnlockSkill` arity3 references **player Level + GetWpnProfById**.
- `CanUnlockSkill` arity4 checks branch `NeedLv`; `HasEnoughWpnProf` checks proficiency.
- **No ore/crystal/currency/material cost appears in the actual level-skill unlock path. Do not invent one.** Gray/The Guide is tutorial/UI context, not proven server payment gate.
- Server automatically populates `SkillTree.Unlock` when requirements are met. Do not force speculative unlock commands.
- `systems/skill_manager.lua` V61.20.1 only activates branches the server already granted, across all weapon classes, and verifies `PlayerData.SkillTree.Active`.
- Latest skill-manager test: 9 server-unlocked branches, 5 newly activated, 4 already active, 0 failed.

## V61.21 weapon-aware combat loadout
- **Skill Tree activation and equipped combat loadout are separate systems.** Activating a branch does not guarantee it is the skill sitting in Skill1/Skill2/SkillU.
- Proven V43.1 protocol: `WeaponUtil.RemoteEvent:FireServer("EquipSkill", weaponId, slot, skillId)`.
- Verify effective loadout with `WeaponUtil:GetWeaponSkillId(player, weaponId, slot)`; validate eligibility with `WeaponUtil:CanEquipSkill(...)`.
- `systems/skill_loadout_manager.lua` V61.21 runs from the small combat entry wrapper, after Lobby equipment choice is already final and before the historical combat controller starts.
- It reads live equipped weapon class/id from `WeaponUtil:GetEquippedWeaponClass/GetEquippedWeaponId`, so Sword/Staff/Heavy/Sickle/Fist/Greatsword each receive their own compatible loadout.
- Candidate skills come from live `ResSkillTree`: base Skill1/Skill2/SkillU plus only level branches that are both server-unlocked and active.
- Basic skills compete for Skill1+Skill2; Ultimate skills compete for SkillU.
- Selection uses live `ResSkill` + `ResSkillStage` combat data: damage events, effective cooldown, action time, range, charge and mitigation. `CanEquipSkill` is still authoritative; invalid candidates are never forced.
- Every change is verified from the effective WeaponUtil getter. Failure is fail-closed: keep existing loadout and continue dungeon.
- Log: `IronSoul_SkillLoadout_V61_21.txt`.
- Cave V61.19 startup safety remains intact: Cave chase stays armed/motionless while loadout maintenance runs and only moves after combat-controller readiness.

## Settlement / replay
- Inventory maintenance threshold 85; full/high inventory at settlement -> Lobby immediately.
- Replay waits are short/bounded; stuck/full replay vote -> Lobby, not minute-long retry chains.

## Lobby upgrades waiting next
- `FortifyUtil.Fortify` arity3.
- `EnchantmentUtil.Enchant` arity5; `UnEnchant` arity4.
- Exact unattended mutation tuple still needs validation before enabling spending.
- Recommended next progression work: verify V61.21 loadout once -> Fortify/Blessing protocol -> Enchant -> pet growth -> Endless Tower.

Repo is source of truth when chat memory conflicts.
