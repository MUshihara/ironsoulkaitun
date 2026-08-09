IRON SOUL KAITUN - CONTINUOUS V59
=================================

Upload/replace these files in:

  MUshihara/IronSoul-Kaitun

Files:
  bootstrap.lua
  systems/tutorial.lua
  systems/lobby.lua
  systems/combat.lua

PUBLIC LOADER
-------------

Optional config:

getgenv().IronSoulConfig = {
    FPS_CAP = 8,
    FARM = "NEWBIE",
    TICKETS = "SMART",
    HEADLESS = true,
}

Then:

loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/MUshihara/IronSoul-Kaitun/main/bootstrap.lua"
))()


V59 BEHAVIOR
-------------

TUTORIAL
  - chooses starter Sword (index 1)
  - queues itself before tutorial->Lobby transition
  - prefers native starter flow
  - visible Skip Tutorial is only a one-time fallback if the game stalls

LOBBY
  - waits for PlayerData / Level / Power
  - claims safe/free rewards
  - spends dedicated SeasonTickets
  - activates unlocked Sword skills
  - Main_009 deterministic Sword forge only if active
  - claims pet hatch / EquipBest
  - equips strongest Sword
  - keeps Staff backup when slot is available
  - equips best Helmet / Breastplate
  - Attack points up to soft cap 15
  - protected inventory cleanup at 85+
  - plans ADVANCE_STORY or REPEAT_STORY
  - enters free physical matchmaking room
  - SelectWorld + CreatRoom solo
  - queues bootstrap before dungeon teleport

DUNGEON
  - proven no-Mouse1 headless BaseAttack
  - native Skill1 / Skill2 callbacks
  - stable 9-stud hover
  - 5.5-stud recovery only when a target cannot be reached
  - current-room enemy locking
  - ignores distant/global enemies from other rooms
  - authoritative GameRound room completion
  - exact RoundNum branch-door selection
  - frozen gate ownership
  - correct door-normal crossing
  - exact RoundDoor.Portal handshake + small in-volume jiggle
  - death recovery

SMART SETTLEMENT
  - DOES NOT return to Lobby after every win
  - if planner still wants the exact same Story stage:
      Play Again directly
  - max 2 direct replays, then Lobby maintenance
  - Lobby immediately when:
      next stage becomes ready
      attributes need spending
      inventory is high
      dungeon failed
      direct replay fails
  - direct Lobby return uses TeleportService; no Return-to-Lobby button click

CLICKING
  - combat basic attacks: NO Mouse1
  - gates: ProximityPrompt API, not screen click
  - Return to Lobby: NO UI click
  - Play Again: one settlement UI click may be used because this is the
    game-owned route that avoids an unnecessary Lobby round-trip
  - tutorial Skip button: one-time fallback only if native tutorial flow stalls

JOURNAL
  IronSoul_Kaitun_Journal_V59.txt

The journal is intentionally tiny and stores:
  state
  target World/Diff
  direct replay count
  failure count
  level/power checkpoint

CURRENT VALIDATION STATUS
-------------------------
Validated strongly:
  current Story dungeon family
  Sword combat
  9-stud farm
  room/gate/portal logic
  Lobby progression pass
  matchmaking
  dungeon->Lobby return
  one full Lobby->Dungeon->Lobby cycle

Production-candidate but not yet fully validated:
  direct Play Again continuous replay path
  fresh-account one-time tutorial Skip fallback
  higher-level maps that use a different dungeon structure

If Play Again ever fails, V59 falls back to Lobby rather than staying
stuck on settlement.
