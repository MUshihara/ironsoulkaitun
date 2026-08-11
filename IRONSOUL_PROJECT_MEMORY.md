# Iron Soul Kaitun — Compact Project Memory

## Goal
24/7 automatic **fresh account -> end progression**. Headless/API-first, fast, low CPU/RAM. No normal clicking.

## Current focus
**World1 V61.15 is now stable enough to freeze. Next major learning target is the Cave system, starting with Crystal Cave.** World2 active movement remains frozen; generic route mapper may continue discovery only.

## Proven baseline
- Tutorial `76701861705540`; Lobby `117533937949084`; validated World1 dungeon `116456628154258`.
- Multiple fresh accounts proved W1 D1/D2/D3 progression and settlement.
- Latest V61.15 evidence: **4 consecutive completed W1 D3 matches** with no route failure; a fifth run was still active when logs were collected.
- Normal World1 combat/traversal is now baseline; do not retune casually.
- Headless Forge, EquipBest/smart cleanup, pet hatch/claim/equip validated.

## Latest Forge proof
Latest forge history on the stable account:
- Mode `MEASURED_RESERVE_BEST_ORE`.
- Ores `93/100 -> 28/100` in 9 crafts.
- Power `755 -> 1197` (+442).
- Equipment inventory `8 -> 17`.
- Reserve-best-ore behavior remained active; useful gains came from measured crafts while avoiding blind full-bag waste.
Keep forge logic unless an actual forge failure appears.

## Fresh Lobby truth
- PlayerData can be ready while fresh `LG_Level=nil`.
- Authoritative fresh level is `PlayerData.LevelData.Level`.
- Resolve/mirror level in lobby preflight only; do not add another fresh-level patch.

## Skill Tree truth — IMPORTANT CORRECTION
Older deep recons established:
- `PlayerData.SkillTree` is authoritative.
- Skill unlock progression is driven by **player level + weapon proficiency**; `SkillTree.Start` updates unlock state during data/level changes.
- Later Staff evidence observed `UnlockSkill3` at **Level 10 / Proficiency 2000**.
- Gray / “The Guide” was involved in tutorial/UI flow, but was **not proven to be required by the server unlock algorithm**.
- No prior validated evidence identified a specific ore payment required for Sword Skill1/2/3 unlocks. Do not invent an ore requirement.
Future auto-skill work should watch SkillTree + weapon proficiency/level and use validated skill APIs/loadout logic rather than assuming an NPC/ore gate.

## World1 movement/traversal — CRITICAL
- User wants **smooth fast CFrame tween/floating**, not Roblox walking and not hard instant snapping everywhere.
- Never use `Humanoid:MoveTo` as normal World1 gate/portal movement.
- `systems/world1_motion.lua`: ~210 studs/sec normal, ~260 long traversal.
- Exact gate/portal + prompt/touch/handshake + authoritative progression verification required.
- Portal timing: dwell about **0.60s** at safe pre-portal point before first touch/cross.
- Never generic RoundPortal RF; it previously skipped rooms/state.

Known fixes:
- Exact current-1 far gate may be followed up to 650 studs only in empty traversal; fixed real ~414-stud Round3 stall.
- Already-open gate recovery crosses ~41 studs and requires real evidence; `CROSSED_PLANE` is not success.
- Raw >100-stud movement is never progression proof.

## V61.15 live dungeon route mapper
`systems/dungeon_route_mapper.lua` is a place-aware live route engine.
- Different PlaceIds have different Workspace contents/layouts. Never share exact coordinates/door assumptions across World1, World2, caves, or Tower.
- Learns from live `PlaceId`, `WorldId`, `Diff`, `GameRound`, RoundWakeTouch, Doors, Portal*, RoundNum/Switch, objectives and streaming.
- World1 active recovery; World2 discovery-only.
- Writes `IronSoul_DungeonRouteMap_V61_15.txt`.
- Server-current wake live -> tween to that round.
- Server advanced but wake not streamed -> use exact previous-round open gate as bounded frontier and probe for wake/objective/current portal.
- Wrong-round historical gates/portals are rejected.
- Bounded failure rebuilds through Lobby rather than infinite stall.

## Cave system — NEXT PRIORITY
Why Cave before Fortify/Enchant automation: material income should be stable before unattended spending.
Current source-backed roles (exact live requirements/rewards must still be learned in-game):
- **Crystal Cave / Cave of Crystal:** resource/material cave.
- **Cave of Runes / Rune Cave:** rune farming, feeds Enchant.
- **Abandoned Courtyard:** pet-enhancement materials.
- Cave Tickets are a shared limited entry resource; public sources list daily quests as a source. Do not blindly spend all tickets on one cave.

Planned default 24/7 scheduler after cave recon:
1. normal World stages for XP/ore/story progression;
2. Crystal Cave when permanent/gear-upgrade materials are the bottleneck;
3. Rune Cave once Enchant is usable and rune stock matters;
4. Abandoned Courtyard once pet growth is actually available/useful;
5. return to normal stages after the targeted material deficit is fixed.
This must become resource-aware, not a fixed cave spam loop.

### Cave diagnostic workflow
First target is Crystal Cave. User manually enters the Cave Place, then runs standalone `.lua` diagnostic:
`IronSoul_FULL_Cave_World_Recon_R1.lua`
It is read-only and captures PlaceId/WorldId, ticket/material PlayerData before/after, cave objectives/enemies/rounds, doors/portals/interactables, rewards/settlement/exit, relevant modules/remotes/configs, UI, and live object/attribute changes. Output ZIP will determine exact cave automation rather than guessing.

## Endless Tower / “limitless” content
Current Season III public evidence confirms Endless Tower exists and is a later progression system:
- extra weapon slot/new ores/Scrolls/Boss Mutations;
- progress saves every five rounds (1, 6, 11, ... without Fast Pass according to current update coverage);
- role is Season progression/Scroll decisions; exact live entry/reward tables still need in-game verification.
Do **not** prioritize Tower before the fresh-account material/upgrade loop is stable. After Cave + skill/upgrade systems are automated, perform a dedicated Tower recon and integrate it as a build-readiness/endgame farm, not a blind fresh-account default.

## Settlement / replay / inventory
- Equipment maintenance threshold = 85.
- Full ore/equipment bag or inventory >=85 at settlement -> skip replay, return Lobby immediately.
- Replay UI/route waits are short bounded windows (~1.1–1.45s); stuck full vote -> Lobby.
- No public same-PlaceId fallback.

## Luau local-register ceiling — DO NOT FORGET
- Historical `systems/combat.lua` is near Luau local-register limit.
- A prior settlement change caused `Out of local registers`.
- Future substantial logic belongs in external modules/wrappers. Do not add large local-heavy combat patches.

## Lobby upgrades waiting after Cave
- R2: `FortifyUtil.Fortify` arity3; `EnchantmentUtil.Enchant` arity5; `UnEnchant` arity4.
- R3 found concrete Equipment/Pets/Honor/Season remotes but not exact mutation argument tuple.
- Do not enable unattended Fortify/Enchant spending until Cave/material income is mapped and exact mutation protocol is validated.

## World2 retained while frozen
- World2 D1 PlaceId `136216144170036`, MaxRound6, PortalD exists.
- Many scenery props have DestructibleObject/HitCount; never infer objective from tags alone.
- Generic mapper may log World2 live wakes/doors/PortalD; active movement stays disabled until validated.

## Workflow
- Diagnostic scripts in chat are `.lua`; output/log files may be `.txt` in ZIPs.
- Production fixes in GitHub; helpers fail closed.

## Next
1. **Freeze V61.15 World1** unless new evidence shows a regression.
2. Manually enter **Crystal Cave**, run `IronSoul_FULL_Cave_World_Recon_R1.lua`, clear one run normally, send the whole output ZIP.
3. Build headless Cave entry/combat/objective/reward/exit only from that evidence.
4. Then map Rune Cave and Abandoned Courtyard using the same architecture.
5. After material farming is stable: auto skill unlock/proficiency -> Blessing/Fortify -> Enchant -> pet growth -> Endless Tower recon/integration.
