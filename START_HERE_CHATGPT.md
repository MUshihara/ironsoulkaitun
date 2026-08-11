# Iron Soul Kaitun — START HERE

Read this, then `IRONSOUL_PROJECT_MEMORY.md`, then inspect current repo. Long changelog is optional.

## Non-negotiable
- 24/7 **fresh account -> end progression**.
- **Headless/API-first:** remotes/modules/server state; no normal mouse/GUI clicking.
- **World1 movement = fast smooth CFrame tween/floating, NOT Roblox walking.** Do not use `Humanoid:MoveTo`/`Humanoid:Move` for gate/portal traversal.
- Tween toward the exact valid current transition over useful distances, do the minimum prompt/touch/handshake, then verify server progression.
- Do not hard-snap everywhere when a short fast tween gives the intended farm behavior.
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
Fresh account has completed `Lobby -> World1 D1 -> settlement -> Lobby -> next run` cleanly. World1 combat is baseline; do not casually retune it.

## World1 traversal rule
- Exact/current progression only; never chase historical wrong-round gates/portals.
- Empty traversal can have the exact `GameRound-1` gate **hundreds of studs ahead**. Current V61.14.1 allows that exact gate up to 650 studs only while in empty COMBAT/traversal state.
- Latest proof: GameRound4, next valid closed Round3 gate ~414 studs, next Round4 enemies ~493 studs. Old 80-stud region filter caused a 90s staging stall.
- Current movement helper: ~210 studs/sec normal, ~260 studs/sec long traversal, smooth CFrame tween/floating.
- Never generically force RoundPortal RF; it previously skipped rooms/state.
- World2 remains frozen/isolated.

## Lobby upgrade recon
- `FortifyUtil.Fortify`: 3 args.
- `EnchantmentUtil.Enchant`: 5 args; `UnEnchant`: 4 args.
- Pet/Honor/Season/shop modules/remotes are live.
- R3 found Equipment/Pets/Honor/Season remotes but did not yet prove the exact Fortify/Enchant outbound argument tuple.
- Do not enable unattended spending until the mutation call protocol + conservative spending rule are validated.

Repo is source of truth when chat memory conflicts.
