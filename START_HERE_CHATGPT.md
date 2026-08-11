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

## Proven loop
Fresh accounts have progressed repeatedly through World1 D1/D2/D3. Normal World1 combat is baseline; do not casually retune it.

## V61.15 dungeon routing
- Use `systems/dungeon_route_mapper.lua` as the live place-aware route layer.
- **World1 and World2 do NOT share one physical Workspace layout.** Every PlaceId/server has its own Workspace tree. They may share naming conventions, but never share coordinates or assume identical doors/portals.
- Mapper discovers live `GameRound`, `RoundWakeTouch.RoundN`, Door/Portal* roots, RoundNum/Switch, objective appearance, and streamed transitions for the current PlaceId/World/Diff.
- World1 active recovery; World2 discovery/logging only while World2 remains frozen.
- If current-round wake exists, tween to it.
- If server has advanced but current wake is not streamed, use the exact open `GameRound-1` gate as a frontier and bounded-probe farther beyond it until current wake/objective/current local portal appears.
- Writes `IronSoul_DungeonRouteMap_V61_15.txt`; this is important future-chat evidence.
- Wrong-round historical gates/portals remain rejected; bounded repeated route failure rebuilds through Lobby instead of hanging.

## D3 route facts
- Correct progression: `Round4 -> Round5 -> Round6 -> Round7 boss`.
- A reused section Portal previously sent the character physically to Round7 while server was still Round5; raw >100-stud `PORTAL_MOVED` success is removed.
- Latest evidence also proved `GameRound=7` can occur while **Round7 wake has not streamed yet**. Old code repeatedly crossed the open Round6 gate to 41 studs forever. V61.15 frontier probing handles this special streamed boss transition.
- Round7 is correct only when authoritative `GameRound==7`.

## Cave architecture — V61.19
- Three validated Cave Trial worlds:
  - Cave1 / Crystal: PlaceId `91584731222940`, gate Lv10/P480, Crystal Shards.
  - Cave2 / Runes: PlaceId `119524374829397`, gate Lv13/P780, runes in `PlayerData.EnchantedStone.Owned`.
  - Cave3 / Abandoned Courtyard: PlaceId `132445869992129`, gate Lv13/P940, dragon-scale pet materials.
- All three are **one-room Round1 resource activities**. Do not require Story doors/portals or next-room traversal.
- Cave2 production logs proved distant targets at ~138 studs and ~101 studs; `systems/cave_chase.lua` owns far-enemy approach.
- **Critical startup race:** V61.18 started Cave chase before `combat.lua` finished loading. One Cave2 test recorded **3 deaths before telemetry `START | controller initialized`**, then cleared in 16.14s after the combat controller came online. Do not move the player toward Cave enemies before combat readiness.
- V61.19 chaser captures the old telemetry baseline, waits for the current run to publish controller/target/heartbeat readiness, waits for a living stable character after any startup death, then activates tween chase.
- If readiness never arrives, chaser fails closed and does not move.
- Chaser log is now an append-style timeline: `IronSoul_CaveChase_V61_19.txt`.
- Cave one-run policy still returns Lobby after one settlement; no paid replay spam.

## SMART Cave scheduler — V61.18
- `systems/cave_planner.lua` runs from Lobby before the historical Story planner.
- Trial only for now.
- Keep **5 Ticket1 reserved**.
- At most one Cave run per **360 seconds** so Story remains the main progression loop.
- Conservative stock buffers (policy, not claimed game costs): Crystal Shards 18, runes 4, Whole Dragon Scale 28.
- Cave3 is considered only when at least one pet is owned.
- If no useful Cave deficit / not eligible / cooldown / reserve reached, fall through unchanged to Story World1.
- Planner records `TicketBeforeEntry` before `CreatRoom`; Lobby `cave_audit.lua` resolves authoritative reward/ticket delta after return.

## Skill tree truth
- `PlayerData.SkillTree` is authoritative.
- Unlock progression is driven by level + weapon proficiency; do not invent an ore/NPC requirement without new evidence.

## Settlement / replay
- Inventory maintenance threshold 85; full/high inventory at settlement -> Lobby immediately.
- Replay waits are short/bounded; stuck/full replay vote -> Lobby, not minute-long retry chains.

## Lobby upgrades
- `FortifyUtil.Fortify` arity3.
- `EnchantmentUtil.Enchant` arity5; `UnEnchant` arity4.
- Exact unattended mutation tuple still needs validation before enabling spending.

Repo is source of truth when chat memory conflicts.
