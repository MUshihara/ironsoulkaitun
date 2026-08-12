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
- Fist/Greatsword/Heavy/Sickle/Staff each had server-granted `UnlockSkill1=true`; only Sword had proficiency data.
- `SkillTreeUtil.RemoteEvent = ReplicatedStorage.Framework.Gameplay.SkillTreeSystem.SkillTreeUtil.RemoteEvent`.
- `TryUnlockSkill` arity3 references player Level + `GetWpnProfById`.
- `CanUnlockSkill` arity4 checks branch `NeedLv`.
- `HasEnoughWpnProf` arity4 checks weapon proficiency.
- `GetWpnProfById` reads `PlayerData.SkillTree.WpnProfs`.
- **No ore/crystal/currency/material cost appears in the actual level-skill unlock path. Do not invent one.** Gray/The Guide is tutorial/UI context, not a proven skill-payment gate.
- Server automatically populates `PlayerData.SkillTree.Unlock` when requirements are satisfied. Do not force speculative unlock commands.

### Skill production V61.20.1
- `systems/skill_manager.lua` is weapon-aware across every class present in `SkillTree.Unlock`.
- It waits for authoritative SkillTree PlayerData on fresh/mobile Lobby loads.
- For every server-granted `UnlockSkillN=true` that is not yet Active, it uses the already-proven free action:
  `SkillTreeUtil.RemoteEvent:FireServer("ActiveSkill", classId, "UnlockSkillN")`.
- Every activation is verified from `PlayerData.SkillTree.Active`; failures do not block Lobby.
- Log: `IronSoul_SkillManager_V61_20.txt`.
- Existing `systems/cave_audit.lua` is now the post-Lobby-readiness maintenance hook: SkillManager first, then pending Cave reward audit. This hook is already loaded before SMART Cave planning and the historical Lobby body, so new skills are activated before leaving Lobby.
- Historical Sword-only activation remains behind this and is harmless/idempotent.

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
- Honor/Season/shop modules/remotes mapped.

Recommended order:
1. **Verify V61.20 SkillManager once in normal Lobby logs** (`Failed=0`; any newly granted non-Sword branches should activate).
2. Fortify/Blessing protocol + conservative spending.
3. Enchant exact mutation tuple + rune-demand-aware Cave2 scheduler.
4. Pet growth + Cave3 demand-aware scheduler.
5. Honor/Glory/shops.
6. Endless Tower.

## Reliability / workflow
- Diagnostics are `.lua`; logs/results may be `.txt`.
- Production changes in GitHub; helpers fail closed.
- Keep memory operational/compact; do not restore huge chronological history as default context.
- World2 active movement remains frozen until deliberately revisited; never reuse World1 coordinates/door assumptions there.
