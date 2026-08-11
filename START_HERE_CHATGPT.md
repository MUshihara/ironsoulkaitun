# Iron Soul Kaitun — START HERE

Read this, then `IRONSOUL_PROJECT_MEMORY.md`, then inspect current repo. Long changelog is optional.

## Non-negotiable
- 24/7 **fresh account -> end progression**.
- **Headless/API-first:** remotes/modules/server state; no normal mouse/GUI clicking.
- **No visible portal/gate walking in normal World1 farming.** Teleport/pre-position to the exact valid transition, use only the minimum required touch/handshake, then verify progression.
- Do not use `Humanoid:MoveTo`/walking as the normal World1 portal fallback.
- Fast only when authoritative state remains valid.
- Preserve proven World1 combat/forge unless evidence requires change.
- Helpers fail closed; a diagnostic/recovery failure must not kill combat.
- Temporary diagnostics are downloadable **`.lua`** files in chat; output/log files may be `.txt`.

## Fresh Lobby truth
- Lobby `117533937949084` is the progression brain.
- Fresh account may have `Loaded=true` and PlayerData ready while `LG_Level=nil` permanently.
- Real level is `PlayerData.LevelData.Level`; never require `LG_Level` alone.
- Handle level compatibility in preflight, not another late lobby patch.

## Proven loop
Fresh account has completed `Lobby -> World1 D1 -> settlement -> Lobby -> next run` cleanly. World1 normal combat/gates are baseline; do not casually retune them.

## Transition safety
- Enemy/DragonEgg before any destructible.
- Never infer progression from HitCount/tag, object removal, or raw movement.
- Never chase far replicated portals or generically force RoundPortal RF; this previously skipped rooms/state.
- World1 current policy: exact current transition -> teleport/touch/verify; no visible walking.
- World2 remains frozen/isolated until its blocker/PortalD state machine is revisited.

## Lobby upgrade recon R2 — useful facts
- `FortifyUtil.Fortify`: 3 args.
- `EnchantmentUtil.Enchant`: 5 args; `UnEnchant`: 4 args.
- `PetsFortifyUtil`, `PetsUpgradeUtil`, `HonorLotteryUtil`, `HonorStoreUtil`, `SeasonUtil`, `SeasonLotteryUtil`, `ConsumableShopUtil` are live.
- Recon account snapshot: Level 7 / Power 207, Currency1 13,837, SeasonCurrency 1,000, 61 ores, no pets, no enchanted stones.
- Exact cost/config tables were captured. Do not enable 24/7 spending until the client->server action protocol and conservative spending rule are validated.

Repo is source of truth when chat memory conflicts.
