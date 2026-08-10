IRON SOUL V59.3 - QUIET + EGG ATTACK PATCH

Replace:
  bootstrap.lua
  systems/lobby.lua
  systems/combat.lua
  systems/tutorial.lua

Main changes:
- quiet console by default
- detailed disk logs disabled by default
- set DEBUG_LOGS=true in IronSoulConfig only when diagnosing
- duplicate bootstrap/lobby/combat run guards
- DragonEgg: 2 headless 4-step Sword combos BEFORE prompt activation
- still activates the egg afterward if attacks alone do not progress
- no Mouse1 / VirtualInputManager combat clicking
- Play Again first executes the game's exact ScreenSettlement
  MouseButton1Down callback directly (no physical mouse movement/click)
- remote VotePlayAgain remains fallback
- normal gate/portal spam no longer prints to console

Expected normal console is only a few lines:
  [IronSoul] Lobby
  [IronSoul] PLAN TARGET=World1 Diff=...
  [IronSoul] Entering World1 D...
  [IronSoul] Dungeon
  [IronSoul] AttackDriver=HEADLESS_REMOTE VERIFIED
  [IronSoul] Dragon Egg | attacking first
  [IronSoul] Dragon Egg | attacked + activated
  [IronSoul] Victory | ...
  [IronSoul] Victory | replaying same stage
or:
  [IronSoul] Lobby | <reason>

For temporary detailed diagnostics add:
  DEBUG_LOGS = true
to IronSoulConfig.
