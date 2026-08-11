-- IRON SOUL - V61.14.5 COMBAT ENTRY
--
-- Preserve the validated combat chain. World1 transition movement is smooth
-- fast CFrame tween/floating movement: no Humanoid walking to/through gates
-- or portals. Empty traversal may follow a FAR gate only when it is the exact
-- current-1 gate, bounded to 650 studs. Already-open gates cross the full
-- proven checkpoint depth and require authoritative progression evidence.
-- D3 cross-section recovery now follows the server-current Round wake before
-- touching an ambiguous reused section Portal, preventing premature boss jumps.
-- Settlement replay fails fast to Lobby when maintenance/replay is blocked.
-- IMPORTANT: fast-settlement patch adds zero new combat.lua locals because the
-- historical combat chunk is already at Luau's local-register ceiling.
-- World2 remains isolated/frozen.

local originalLoadRaw = getgenv().IronSoulLoadRaw

local function getPatcher()
    local loadRaw = originalLoadRaw

    if type(loadRaw) == "function" then
        local ok, patcher = loadRaw("systems/patch_loader.lua")
        if ok and type(patcher) == "function" then
            return patcher
        end
    end

    local source = game:HttpGet(
        "https://raw.githubusercontent.com/MUshihara/ironsoulkaitun/main/systems/patch_loader.lua?t="
            .. tostring(os.time())
    )

    local fn, err = loadstring(source)
    assert(fn, err)

    local patcher = fn()
    assert(type(patcher) == "function", "V61.14.5 combat patch loader unavailable")
    return patcher
end

-- Preload the shared World1 motion and authoritative current-round recovery
-- OUTSIDE the giant historical combat chunk. This avoids local-register pressure
-- inside patched combat.lua while still giving transition code a safe helper.
if type(originalLoadRaw) == "function" then
    pcall(function()
        originalLoadRaw("systems/world1_motion.lua")
        originalLoadRaw("systems/world1_round_recovery.lua")
    end)
end

-- Keep an unredirected loader available to the wrappers so they can reuse the
-- proven underlying transition/watchdog modules without recursion.
getgenv().IronSoulDependencyBaseLoadRaw = originalLoadRaw

local function routedLoadRaw(path)
    if path == "systems/transition.lua" then
        path = "systems/transition_nowalk.lua"
    elseif path == "systems/transition_watchdog.lua" then
        path = "systems/transition_watchdog_nowalk.lua"
    end

    if type(originalLoadRaw) == "function" then
        return originalLoadRaw(path)
    end

    local source = game:HttpGet(
        "https://raw.githubusercontent.com/MUshihara/ironsoulkaitun/main/"
            .. tostring(path)
            .. "?t="
            .. tostring(os.time())
    )

    local fn, err = loadstring(source)
    if not fn then
        return false, err
    end

    local ok, result = pcall(fn)
    return ok, result
end

getgenv().IronSoulLoadRaw = routedLoadRaw

local ok, result = pcall(function()
    return getPatcher()({
        repository = "MUshihara/ironsoulkaitun",
        base_commit = "1d47f7f50ec8ecd92bca691b17d586d6bdecfa55",
        path = "systems/combat.lua",
        patch_paths = {
            "systems/patches/combat_v61_7_boss_safe.patch",
            "systems/patches/combat_v61_8_burst_safe.patch",
            "systems/patches/combat_v61_8_skill_telemetry.patch",
            "systems/patches/combat_v61_8_learned_transition.patch",
            "systems/patches/combat_v61_9_unknown_objective.patch",
            "systems/patches/combat_v61_10_objective_scope_hotfix.patch",
            "systems/patches/combat_v61_11_1_region_egg_bridge.patch",
            "systems/patches/combat_v61_14_world1_tween_open_gate.patch",
            "systems/patches/combat_v61_14_far_traversal_tween.patch",
            "systems/patches/combat_v61_14_3_fast_settlement.patch",
        },
    })
end)

getgenv().IronSoulLoadRaw = originalLoadRaw

if not ok then
    error(result)
end

return result
