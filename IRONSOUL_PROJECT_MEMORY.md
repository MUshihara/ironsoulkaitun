# Iron Soul Kaitun — Compact Project Memory

## Goal
24/7 automatic **fresh account -> end progression**. Headless/API-first, fast, low CPU/RAM. No normal mouse/GUI clicking.

## Current priority
**World2 tuning is frozen. Rebuild/verify Tutorial -> Lobby -> World1 first.** Lobby is the progression brain.

## Proven baseline
- Tutorial `76701861705540`; starter Sword index 1.
- Lobby `117533937949084`.
- Validated World1 dungeon `116456628154258`.
- V55.2 World1: settlement, 128 targets, 5 transitions, 0 deaths, headless remote attack, no mouse basic.
- V58 W1D2: Lv10/P341 -> Lobby Lv11/P355.
- Normal combat is strong (~9-stud elevated; ~5.5 close damage recovery). Do not retune without evidence.
- Headless forge validated. Strong observed maintenance: ore ~95/100 -> 30/100, 9 crafts, Power 2642 -> 3490.
- EquipBest/smart cleanup useful.
- Pet hatch/claim/equip validated.
- Pet Fortify/StarUp/SkillUp remotes were mapped; growth was disabled when mats/duplicates were insufficient.
- Main/daily/task pieces, Sword skill equip/unlocks, attributes and Season/Lottery pieces were previously validated.

## Lobby readiness bug / current fix
Historical lobby permanently stopped after 25s unless all were ready: `DataUtil:GetPlayerData`, `Loaded != false`, `LG_Level`, `LG_PowerNew1`.
Current `systems/lobby.lua` has **V61.13 preflight**:
- waits indefinitely instead of stopping;
- writes exact missing readiness signals to `IronSoul_LobbyReadiness_V61_13.txt`;
- requires 4 consecutive ready checks;
- then runs the proven lobby body unchanged;
- overrides teleport queue payload to use stable `bootstrap.lua`, so continuous sessions receive future fixes.

## Lobby systems needing fresh recon before expansion
- Blessing.
- Enchant.
- Merchant/vendor/shop automation.
- Glory Wheel if separate from the already-known Season/Lottery system.
- Exact current rules/costs for Pet Fortify/StarUp/SkillUp.
Do not guess these from old names. Use live modules/remotes/PlayerData evidence.

## Headless rules
- APIs/remotes/modules/server state first.
- No normal UI clicking.
- Fast farming only if authoritative state remains correct.
- For portals, direct RoundPortal RF is NOT a generic fast path; it previously skipped rooms/state. Use exact valid local portal + native/touch handshake when required.
- Progression truth: GameRound / settlement / valid objective / valid region, not raw movement.
- Helpers fail closed and must never kill combat.

## World2 facts to retain while frozen
- D1 place `136216144170036`, MaxRound 6.
- Portal variant `PortalD` exists.
- Many ordinary props are `DestructibleObject` with `HitCount`; tag/HitCount alone never means progression.
- Old bad behavior attacked Tree/IceCrystal/etc and treated removal as success. Do not restore this.
- World2 experiments stay isolated from proven World1 logic.

## Reliability / repo hygiene
- Avoid fragile late patch stacks when a wrapper/preflight/direct module can enforce policy.
- Superseded failed patches `watchdog_v61_11_2_progression_guard.patch` and `lobby_v61_10_mobile_executor.patch` were removed.
- Temporary diagnostics are downloadable standalone `.txt` scripts in chat, not repo.
- `START_HERE_CHATGPT.md` + this file are the default continuity path. Long changelog only for tracing a specific regression.

## Next
Run the full standalone lobby recon on a fresh account in Lobby while the normal kaitun is running/waiting. Learn PlayerData load stages + Forge/Fortify/Enchant/Blessing/Pets/Merchant/Glory/Season/Tasks/Skills/Attributes/World/matchmaking surfaces, then make the next lobby production pass from evidence.
