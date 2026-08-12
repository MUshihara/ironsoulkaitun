# Iron Soul Kaitun — Compact Project Memory

## Goal
24/7 automatic **fresh account -> end progression**. Headless/API-first, fast, low CPU/RAM. No normal clicking.

## Stable foundation
- Tutorial `76701861705540`; Lobby `117533937949084`.
- World1 V61.15 routing stable/frozen through Normal D5.
- World1 traversal = smooth fast CFrame tween/floating, never Humanoid walking.
- Historical combat near Luau local-register ceiling; substantial new behavior stays external or inside existing patch functions.
- Fresh Lobby uses `PlayerData.LevelData.Level` if `LG_Level` is nil.

## World2 — Normal + Hell progression validated through Challenge
- PlaceId `136216144170036`.
- Normal Trial/internal1 validated: settlement166.89s, Round6, 66 targets, 0 deaths.
- Hell Trial/internal6 validated: settlement179.14s, Round6, 51 targets, 0 deaths.
- **Normal Challenge/internal2 validated** on 2026-08-12: settlement255.52s, 58 targets, PlayerHits15, PlayerDamage2124, 0 deaths, final HP about50%.
- **Hell Challenge/internal7 validated** immediately afterward: settlement276.39s, 40 targets, PlayerHits19, PlayerDamage3069, 0 deaths, final HP about37.5%.
- This proves V61.30 Hell-first bridge behavior: Normal Challenge clear unlocked Hell Challenge; next Lobby selected World2 Hell Challenge by default.
- Route mapper remains discovery-only in World2; existing transition stack continues to succeed.

### Hell internal IDs vs UI stage names
The UI always has five buttons: `Trial / Challenge / Penitent / Torment / Inferno`.
- Normal internal Diff1..5 = those five stages.
- Hell internal Diff6..10 = the same five stages.
- Therefore internal Diff6 = **Hell Trial**, Diff7 = **Hell Challenge**, etc.; do not describe these as visible D6/D7 stages.

World2 Hell unlocks from corresponding Normal clears:
- Hell Trial internal6 -> `World2|1`.
- Hell Challenge internal7 -> `World2|2` (now unlocked + live-cleared).
- Hell Penitent internal8 -> `World2|3` (next bridge; Normal Penitent currently power-blocked).
- Hell Torment internal9 -> `World2|4`.
- Hell Inferno internal10 -> `World2|5`.

## Hell-first V61.30
Production `systems/hell_planner.lua`, commit `a825ea380f61282e67b2195c35cd3b3a0a2f22f5`.
- Hell is the default free farm/repeat mode.
- Normal is used only as a **one-clear unlock bridge** when it opens the next Hell stage; next Lobby returns to Hell.
- Hard gates: server unlock + recommended level.
- Hell configs have blank RecBattlePower, so matching Normal stage RecBattlePower is the proxy.
- Script-ready power floor = **78%** of matching Normal recommendation.
- Latest Hell planner at Lv23/P4628 correctly chose `World2_HELL_Challenge_InternalDiff7`; Normal Penitent bridge needs minimum6240 at current78% rule.

## Cave combat baseline
- Cave1 `91584731222940`; Cave2 `119524374829397`; Cave3 `132445869992129`.
- One-room Round1; no Story doors/portals.
- V61.19 chase waits for combat-controller readiness, then handles far enemies; mobile validated.
- One Cave run -> Lobby; reserve5 Ticket1; cooldown360s.

## SMART Cave V61.30
Production `systems/cave_planner.lua`, commit `8e8d8faf5a1f7d6f728c89dd51b2deb96be1e572`.
- Demand-driven; highest current server-unlocked Cave stage chosen when recommended LEVEL is met and current power >= **78%** of recommendation.
- Ticket1 reserve5 preserved.
- Cave1 = exact Blessing/Fortify CrystalShards blocker.
- Cave2 = exact Enchant empty-slot/no-stone blocker.
- Cave3 = no pet + no egg + egg-capable D2+.
- Priority currently deterministic Fortify > first-pet egg > Enchant.
- Latest decision at Lv23/P4628: Cave1 D3, Cave3 D2, Cave2 D2 were eligible; Cave cooldown prevented spending that cycle.

## First egg / pets
- Cave3 D1 no egg; D2/D3/D4 display Random_Egg.
- `Main_Pet_001` separately rewards guaranteed DragonIce egg when legitimately active.
- `systems/pet_manager.lua` V61.25 claim/start/equip bridge is production; current account can legitimately remain WAIT_EGG at 0 pets/0 eggs.
- Pet Fortify costs use BrokenDragonScale -> WholeDragonScale -> DragonClaw -> DragonHorn/etc.; live mutation waits for first pet.

## Skills/combat baseline through V61.22
- Level Skill activation server-granted only.
- V61.21 weapon-aware loadout passed.
- V61.22 BaseAttack + native charge-based SkillU verified in Cave/W1/W2/Hell.

## V61.31 threat-first boss combat — COMMITTED, LIVE TEST PENDING
Latest W2 telemetry exposed a clear threat split:
- Normal Challenge: **all 15 incoming hits** occurred while fighting the 11k+ HP large targets; the 46,162 HP target alone caused6 hits/900 damage.
- Hell Challenge: **all 19 incoming hits** came from 9,400+ HP targets. The two largest targets (42,006 and 68,627 HP) caused14/19 hits and 2,277/3,069 damage (~74%).
- Many 1.6k-4k enemies were classified `BossLike` under the old fixed1500 threshold yet caused zero hits, wasting Boss Orbit/Ultimate behavior.

V61.31 changes existing patches instead of adding another combat patch:
- `combat_v61_7_boss_safe.patch` commit `432de25cce50203bb66e59b9c1ec06ffd501ff9f`:
  - nearest-target remains fallback;
  - nearby true threat first within180 studs;
  - threat threshold = `max(1500, PlayerMaxHP * 3.0)`;
  - among qualifying threats, highest HP first, distance tie-break;
  - telemetry event `TARGET_PRIORITY | THREAT_FIRST ...`.
- `combat_position_v61_7_burst_lock.patch` commit `908c941f02f282106a3e43d1601ed2120e86214b`:
  - `BossLike` now uses same account-relative threshold, so medium mobs no longer get boss movement unnecessarily.
- `combat_v61_8_skill_telemetry.patch` commit `c83903a09cbf702c15554fac6e63dc32a32ef019`:
  - SkillU reserved for same true-threat threshold instead of every1500+ HP enemy.

### Height decision
Do **not** raise permanent height yet.
- Current profiles: normal9, boss10.25, first evade11.25, repeated-burst wide12.25, lowHP10.5.
- These survived both Challenge clears with0 deaths, but large targets still landed meaningful damage.
- Historical combat proof says 9 was the highest consistently reliable permanent height; 13/17/21 became inconsistent and25 failed attack registration.
- Therefore V61.31 changes threat priority/classification first. Re-evaluate boss height/offset only after one clean V61.31 telemetry run; avoid changing two variables at once.

## Blessing/Fortify V61.23
- Blessing player-facing; internal API Fortify.
- auto guaranteed +2/+3/+4 only; primary weapon -> armor -> competitive Weapon2.
- reserve2 CrystalShards + Currency1 10000; max6 verified actions/Lobby.

## Smart Enchant V61.24
- Exact write validated: `EquipmentRE:FireServer("Enchant", equipmentUUID, slotKey, stoneUUID)`.
- +4 keeper minimum; existing empty slot only; one action/Lobby; no overwrite/UnEnchant.

## Grocery V61.30
Exact protocol proved: `ConsumableShopUtil.RemoteEvent:FireServer("BuyShopItem", "Gold", itemConfigId)`.
Production `systems/shop_manager.lua`, commit `2650ec92f15a489ca36603e40ee80c19f100b2e3`.
- buys only exact Fortify/Enchant blockers from current Gold rotation;
- no paid refresh; Currency1 reserve20000; max3 buys/Lobby; verify stock + currency + actual resource gain.
- Latest live pass bought CrystalShards x3 three times for3000 total, each purchase verified, then Fortify re-ran and upgraded breastplate/helmet safely.

## Current chain
`Forge/EquipBest -> Pet acquisition -> Blessing/Fortify -> Smart Enchant -> Grocery exact blocker -> re-run upgrades if Grocery bought -> SMART Cave -> Hell-first -> one-clear Normal bridge only when needed to unlock next Hell stage -> historical Story fallback only if Hell cannot handle`.

## Immediate next validation
1. Run normal loader with V61.31 combat changes.
2. In telemetry look for `TARGET_PRIORITY | THREAT_FIRST`; true 8k+/relative large enemies should be selected before nearby small mobs.
3. Compare PlayerHits/PlayerDamage and ending HP against Normal Challenge15/2124/50% and Hell Challenge19/3069/37.5% baselines.
4. Verify medium 1.6k-4k mobs are no longer `BossLike` and SkillU is saved for real threats.
5. If boss damage remains high, next change should be **pre-emptive true-boss movement** (height/offset/orbit), not a global height increase.
6. First pet -> one controlled pet-growth mutation -> exact Cave3 material demand.
7. Higher-risk Blessing +5+ only with explicit risk/value policy; Endless later.