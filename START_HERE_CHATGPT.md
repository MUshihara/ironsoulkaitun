# Iron Soul Kaitun — START HERE

Read this file, then `IRONSOUL_PROJECT_MEMORY.md`, then inspect the current repo.
Do **not** read the long changelog by default; use it only to trace an old regression.

## Non-negotiable engineering rules
- **Headless/API-first:** remotes/modules/server state first. No mouse/GUI clicking in normal automation.
- Fast farming is good only when **server progression stays valid**.
- **Enemies/DragonEgg always outrank destructibles.**
- Never attack scenery because it has `HitCount` or `DestructibleObject`.
- Unknown destructible may be attacked only when it is the **first physical blocker on the route to the authoritative current portal/wake region**.
- `OBJECT_REMOVED`, large movement, or CFrame displacement are **not progression proof**.
- Progression truth = GameRound / settlement / new valid objective / new valid region.
- Never chase a replicated portal across the map.
- Never force RoundPortal RF just because it exists: this was proven able to skip rooms/state.
- Exact local portal: safe pre-position + native/touch handshake + progression verification.
- Preserve validated World1 combat/forge/door logic; isolate World2 experiments.
- Temporary diagnostics are standalone `.txt` scripts in chat, not GitHub.
- Recovery/diagnostic helpers must fail closed and must not kill combat.

## Current focus
World2 D1 (`136216144170036`) progression. Current repository is source of truth.
