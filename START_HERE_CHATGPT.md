# Iron Soul Kaitun — START HERE

Read this file, then `IRONSOUL_PROJECT_MEMORY.md`, then inspect current repo.
Long changelog is optional; use only to trace an old regression.

## Non-negotiable
- 24/7 NEWBIE -> end progression.
- **Headless/API-first:** remotes/modules/server state. No mouse/GUI clicking in normal automation.
- Fast only when server state stays valid.
- Preserve proven World1 combat/forge/traversal; do not casually retune it.
- Enemy/DragonEgg outrank destructibles.
- Never attack scenery because of `HitCount`/`DestructibleObject` alone.
- Never chase far replicated portals or accept movement/object removal as progression proof.
- Do not generically force RoundPortal RF; proven able to skip rooms/state.
- Recovery/diagnostic helpers fail closed; never kill combat.
- Diagnostics are standalone `.txt` from chat, not production repo.

## Current priority
**Freeze World2 tuning. Return to fresh account -> Tutorial -> Lobby -> World1.**
Lobby is the progression brain and must be fully learned/validated before more World2 work.

## Lobby rule
Slow fresh/mobile PlayerData must WAIT/SELF-HEAL, never permanently stop on a short timeout.
Current lobby preflight waits for stable PlayerData + Loaded/Level/Power before running proven lobby logic and queues stable `bootstrap.lua` across teleports.

## Mechanic status
- Proven: headless forge, EquipBest, smart cleanup, pets hatch/equip, tasks/dailies pieces, Sword skills, attributes, season/lottery pieces, World1 progression/matchmaking.
- Pet growth Fortify/StarUp/SkillUp was mapped but previously disabled when mats/dupes were insufficient.
- Blessing / Enchant / Merchant-vendor / Glory-Wheel-specific automation must be re-learned from the full lobby recon before production assumptions.

Repo is source of truth when chat memory conflicts.
