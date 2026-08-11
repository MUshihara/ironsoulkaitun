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
Fresh accounts have completed repeated `Lobby -> World1 -> settlement -> Lobby/replay -> next run` cycles through D1/D2/D3. World1 combat is baseline; do not casually retune it.

## World1 traversal
- Exact/current progression only; never chase historical wrong-round gates/portals.
- Empty traversal may use an exact `GameRound-1` gate up to 650 studs only while no combat objective exists.
- Known ~414-stud Round3 gate stall fixed by this exact-current far traversal rule.
- Already-open gates tween through the proven ~41-stud checkpoint depth and require settlement/GameRound/new-region evidence.
- Portal wrappers and direct section-portal handshake dwell ~0.60s before first final touch/cross.
- **D3 boss rule:** successful order is `Round4 -> Round5 -> Round6 -> Round7 boss`. Round7 is correct boss area only when server `GameRound==7`.
- A reused section Portal was proven to jump physically to Round7 while server was still GameRound5. Never accept raw >100-stud displacement as portal success.
- Before ambiguous cross-section portal use, `world1_round_recovery.lua` follows/caches the wake matching the authoritative current `GameRound` and tween-routes there when far. New-region evidence must match `Round<GameRound>`.
- Never generically force RoundPortal RF; it previously skipped rooms/state.
- World2 remains frozen/isolated.

## Settlement / inventory / replay — 24/7 rule
- Do not wait a minute for native replay failure.
- Equipment maintenance threshold is `INVENTORY_CLEAN_AT` (85).
- Full/high inventory at settlement returns Lobby immediately and skips Play Again.
- Replay windows are short/bounded; full/stuck replay vote returns Lobby in a few seconds.
- Lobby return uses native `WorldUtil.RemoteEvent:FireServer("BackLobby")`, then TeleportService fallback if needed.

## Combat compiler constraint
- Historical `systems/combat.lua` is near Luau's local-register ceiling.
- Do not add substantial locals directly to that giant chunk. Put new logic in separate modules/wrappers; settlement patch is intentionally zero-new-local.

## Lobby upgrade recon
- `FortifyUtil.Fortify`: 3 args.
- `EnchantmentUtil.Enchant`: 5 args; `UnEnchant`: 4 args.
- Pet/Honor/Season/shop modules/remotes are live.
- Exact Fortify/Enchant outbound tuple still needs validation before unattended spending.

Repo is source of truth when chat memory conflicts.
