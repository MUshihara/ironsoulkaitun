# Iron Soul Kaitun — START HERE

Read this, then `IRONSOUL_PROJECT_MEMORY.md`, then inspect current repo. Long changelog is optional.

## Non-negotiable
- 24/7 **fresh account -> end progression**.
- **Headless/API-first:** remotes/modules/server state; no normal mouse/GUI clicking.
- **World1 movement = fast smooth CFrame tween/floating, NOT Roblox walking.** Do not use `Humanoid:MoveTo`/`Humanoid:Move` for gate/portal traversal.
- Tween toward the exact valid current transition, then settle about **0.60s before final portal touch/cross** so the server trigger can arm.
- Fast only when authoritative state remains valid; movement/crossed-plane alone is never progression proof.
- Preserve proven World1 combat/forge unless evidence requires change.
- Helpers fail closed; a diagnostic/recovery failure must not kill combat.
- Temporary diagnostics are downloadable **`.lua`** files in chat; output/log files may be `.txt`.

## Fresh Lobby truth
- Lobby `117533937949084` is the progression brain.
- Fresh account may have `Loaded=true` and PlayerData ready while `LG_Level=nil` permanently.
- Real level is `PlayerData.LevelData.Level`; never require `LG_Level` alone.
- Handle level compatibility in preflight, not another late lobby patch.

## Proven loop
Fresh accounts have completed repeated `Lobby -> World1 D1 -> settlement -> Lobby/replay -> next run` cycles. World1 combat is baseline; do not casually retune it.

## World1 traversal
- Exact/current progression only; never chase historical wrong-round gates/portals.
- Empty traversal may use an exact `GameRound-1` gate up to 650 studs only while no combat objective exists.
- Known ~414-stud Round3 gate stall fixed by this exact-current far traversal rule.
- Already-open gates tween through the proven ~41-stud checkpoint depth and require settlement/GameRound/new-region evidence.
- Portal wrappers and the direct section-portal handshake now dwell ~0.60s before first final touch/cross to prevent overshooting an unarmed trigger.
- Never generically force RoundPortal RF; it previously skipped rooms/state.
- World2 remains frozen/isolated.

## Settlement / inventory / replay — 24/7 rule
- **Do not wait a minute for native replay failure.** Old replay path could wait 8 + 12 + 15 + 15 + 15 seconds.
- Current V61.14.3 uses short bounded replay windows and returns Lobby within a few seconds when replay does not begin.
- Equipment inventory maintenance threshold is `INVENTORY_CLEAN_AT` (85), not 90.
- If ore/equipment bag is full or inventory is already at maintenance threshold at settlement, return Lobby immediately and skip Play Again.
- Re-check capacity immediately before replay because rewards can fill the bag.
- If `VotedAgainCount >= PlayersCount` but restart still does not begin, treat replay as stuck/full and return Lobby immediately.
- Lobby return uses native `WorldUtil.RemoteEvent:FireServer("BackLobby")`, with a short confirmation window then TeleportService safety fallback.

## Lobby upgrade recon
- `FortifyUtil.Fortify`: 3 args.
- `EnchantmentUtil.Enchant`: 5 args; `UnEnchant`: 4 args.
- Pet/Honor/Season/shop modules/remotes are live.
- R3 found Equipment/Pets/Honor/Season remotes but did not yet prove the exact Fortify/Enchant outbound argument tuple.
- Do not enable unattended spending until mutation protocol + conservative spending rule are validated.

Repo is source of truth when chat memory conflicts.
