# Iron Soul Kaitun — Compact Project Memory

## Goal
24/7 automatic **fresh account -> end progression**. Headless/API-first, fast, low CPU/RAM. No normal clicking.

## Stable foundation
- Tutorial `76701861705540`; Lobby `117533937949084`.
- World1 V61.15 routing stable/frozen through Normal D5.
- World1 traversal = smooth fast CFrame tween/floating, never Humanoid walking.
- Historical combat near Luau local-register ceiling; substantial new behavior stays external.
- Fresh Lobby uses `PlayerData.LevelData.Level` if `LG_Level` is nil.

## World2
- PlaceId `136216144170036`.
- Normal Trial (internal Diff1) unattended clear validated: settlement166.89s, Round6, 66 targets, 0 deaths, gate1/0, watchdog0.
- **Hell Trial** unattended clear validated: internal Diff6, settlement179.14s, Round6, 51 targets, 0 deaths, gate1/0, watchdog0; BaseAttack and SkillU worked.
- Route mapper remains discovery-only in World2; preserve successful existing transition stack.

### Hell internal IDs vs UI stage names
The UI always has five buttons: `Trial / Challenge / Penitent / Torment / Inferno`.
- Normal internal Diff1..5 = those five stages.
- Hell internal Diff6..10 = the same five stages.
- Therefore internal Diff6 = **Hell Trial**, not visible “D6”.

World2 Hell unlocks from corresponding Normal clears:
- Hell Trial internal6 -> `World2|1` (currently unlocked + cleared live).
- Hell Challenge internal7 -> `World2|2` (currently locked in screenshot/recon).
- Hell Penitent internal8 -> `World2|3`.
- Hell Torment internal9 -> `World2|4`.
- Hell Inferno internal10 -> `World2|5`.

## Hell-first V61.30
Production `systems/hell_planner.lua`, commit `a825ea380f61282e67b2195c35cd3b3a0a2f22f5`.
- Hell is now the **default free farm/repeat mode**.
- Do not switch back to Normal simply because Normal is ready.
- Normal is used only as a **one-clear unlock bridge** when it opens the next Hell stage; next Lobby returns to Hell.
- Hard gates: server unlock + recommended level.
- Hell configs have blank RecBattlePower, so use matching Normal stage RecBattlePower as proxy.
- Script-ready power floor = **78%** of matching Normal recommendation.
- Example current W2 behavior: Hell Trial -> once Normal Challenge is unlocked/level-ready and power >=78% of5600 (=4368), clear Normal Challenge once -> Hell Challenge becomes default.

## Cave combat baseline
- Cave1 `91584731222940`; Cave2 `119524374829397`; Cave3 `132445869992129`.
- One-room Round1; no Story doors/portals.
- V61.19 chase waits for combat-controller readiness, then handles far enemies; mobile validated.
- One Cave run -> Lobby; reserve5 Ticket1; cooldown360s.

## SMART Cave V61.30
Production `systems/cave_planner.lua`, commit `8e8d8faf5a1f7d6f728c89dd51b2deb96be1e572`.
- Demand-driven; no arbitrary Cave farming.
- Highest current server-unlocked Normal Cave stage is chosen if:
  - recommended LEVEL is met exactly/hard gate;
  - current power >= **78%** of recommended power;
  - Ticket1 reserve preserved.
- This intentionally allows roughly22% under recommended power because headless combat is much stronger than ordinary play.
- Cave1 demand = exact Blessing/Fortify CrystalShards blocker.
- Cave2 demand = exact Enchant empty-slot/no-stone blocker.
- Cave3 first-pet demand = no pet + no egg + egg-capable D2+.
- Priority currently deterministic Fortify > first-pet egg > Enchant.
- If a Cave says Lv16/P2880, level15 is NOT allowed; level16 with power >=2247 is eligible if server-unlocked.

## First egg / pets
- Cave3 D1 no egg; D2/D3/D4 display Random_Egg.
- `Main_Pet_001` separately rewards guaranteed DragonIce egg when legitimately active.
- `systems/pet_manager.lua` V61.25 claim/start/equip bridge is production; current account state correctly WAIT_EGG when 0 pets/0 eggs.
- Pet Fortify costs use BrokenDragonScale -> WholeDragonScale -> DragonClaw -> DragonHorn/etc.; live mutation waits for first pet.

## Skills/combat
- Level Skill activation server-granted only.
- V61.21 weapon-aware loadout passed.
- V61.22 BaseAttack + native charge-based SkillU verified in Cave/W1/W2/Hell Trial.

## Blessing/Fortify V61.23
- Blessing player-facing; internal API Fortify.
- auto guaranteed +2/+3/+4 only; primary weapon -> armor -> competitive Weapon2.
- reserve2 CrystalShards + Currency1 10000; max6 verified actions/Lobby.

## Smart Enchant V61.24
- Exact write validated: `EquipmentRE:FireServer("Enchant", equipmentUUID, slotKey, stoneUUID)`.
- +4 keeper minimum; existing empty slot only; one action/Lobby; no overwrite/UnEnchant.

## Grocery V61.30
V61.29 source recon fully proved purchase protocol:
`ConsumableShopUtil.RemoteEvent:FireServer("BuyShopItem", "Gold", itemConfigId)`.
Server checks stock/currency/daily limit and grants configured item.

Gold useful configs include:
- CrystalShards x3/1000.
- tier3 Burn/Methysis/Frost/Corrode stones /3000.
- BrokenDragonScale x5/1000, WholeDragonScale x5/2000, DragonClaw x5/3500, DragonHorn x5/5000, DragonTear x5/7500.
- EXP/Drop/Atk/HP and other potions; Hell ores also rotate.

Production `systems/shop_manager.lua`, commit `2650ec92f15a489ca36603e40ee80c19f100b2e3`.
- buys only exact Fortify/Enchant blockers from current Gold rotation;
- no paid refresh;
- Currency1 reserve20000;
- max3 buys/Lobby, >=0.40 sec interval;
- verify stock decrease + currency decrease + resource/stone increase.
- pet mats wait until exact pet-growth demand; potions wait until use-policy/protocol.

## Current chain V61.30
`Forge/EquipBest -> Pet acquisition -> Blessing/Fortify -> Smart Enchant -> Grocery exact blocker -> re-run upgrades if Grocery bought -> SMART Cave -> Hell-first -> one-clear Normal bridge only when needed to unlock next Hell stage -> historical Story fallback only if Hell cannot handle`.

Preflight integration commit `3c361ed55bb809f3038c604c8788c430bcb7f1ab`.

## Immediate next validation
1. Run normal loader.
2. Verify Grocery buy if CrystalShards/stone blocker is in current rotation; it must verify and then re-run upgrades before Cave.
3. Verify Cave V61.30 selects highest unlocked stage at hard level + 78% power floor.
4. W2 should default to Hell Trial until the one-clear Normal Challenge bridge becomes eligible; after bridge, Hell Challenge should become default.
5. First pet -> one controlled pet-growth mutation -> exact Cave3 material demand.
6. Higher-risk Blessing +5+ only with explicit risk/value policy; Endless later.