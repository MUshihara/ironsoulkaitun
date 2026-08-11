# Iron Soul Kaitun — START HERE

Read this, then `IRONSOUL_PROJECT_MEMORY.md`, then inspect current repo. Long changelog is optional.

## Non-negotiable
- 24/7 **fresh account -> end progression**.
- **Headless/API-first:** remotes/modules/server state; no normal mouse/GUI clicking.
- Fast only when authoritative state remains valid.
- Preserve proven World1 combat/forge/traversal unless evidence requires change.
- Helpers fail closed; a diagnostic/recovery failure must not kill combat.
- Temporary diagnostics are standalone downloadable **`.lua`** files in chat, never production GitHub.

## Fresh Lobby truth
- Lobby `117533937949084` is the progression brain.
- Fresh-account recon proved `DataUtil:GetPlayerData()` can be fully ready with `Loaded=true`, `LG_PowerNew1=110`, but **`LG_Level=nil` permanently**.
- Real level is `PlayerData.LevelData.Level` (fresh recon: Level 1). Never require `LG_Level` alone.
- Handle this in the lobby **preflight compatibility layer**, not with another late lobby patch. Resolve PlayerData level, then locally mirror it to `LG_Level` only for the proven historical lobby code.
- The malformed `lobby_v61_13_1_fresh_level.patch` was deleted. Do not recreate/re-add it.

## Current priority
Freeze World2. Prove **Tutorial -> Lobby -> World1 -> Lobby** first, then expand lobby mechanics.

## Safe architecture reminders
- Enemy/DragonEgg before any destructible.
- Never infer progression from HitCount/tag, object removal, or raw movement.
- Never chase far replicated portals or generically force RoundPortal RF; both caused invalid skips.
- Exact valid local portal + required native/touch handshake + server-state verification.

## Mechanic status
- Proven baseline: headless forge, EquipBest/smart cleanup, pet hatch/equip, task/daily pieces, Sword skills, attributes, Season/Lottery pieces, World1 progression/matchmaking.
- Pet Fortify/StarUp/SkillUp was mapped but should spend only when materials/duplicates justify it.
- Fresh recon exposed `EnchantmentUtil`, `FortifyUtil`, `PetsFortifyUtil`, `PetsUpgradeUtil`, `HonorLotteryUtil`, shops, Season systems, etc.; action protocols/policies still need deliberate validation before 24/7 spending.
- Blessing and any separate Glory Wheel mechanic are not considered mapped just from names.

Repo is source of truth when chat memory conflicts.
