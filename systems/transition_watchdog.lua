-- IRON SOUL - V61.11.2 TRANSITION WATCHDOG ENTRY
-- Preserves verified watchdog learning/recovery, then adds a progression guard:
-- recovery portals must be local, displacement alone is not success evidence,
-- and old PORTAL_MOVED learned routes are rejected.

local function getPatcher()
    local loadRaw =
        getgenv().IronSoulLoadRaw

    if type(loadRaw) == "function" then
        local ok, patcher =
            loadRaw(
                "systems/patch_loader.lua"
            )

        if ok
            and type(patcher) == "function"
        then
            return patcher
        end
    end

    local source =
        game:HttpGet(
            "https://raw.githubusercontent.com/MUshihara/ironsoulkaitun/main/systems/patch_loader.lua?t="
                .. tostring(os.time())
        )

    local fn, err =
        loadstring(source)

    assert(fn, err)

    local patcher = fn()
    assert(
        type(patcher) == "function",
        "V61.11.2 transition watchdog patch loader unavailable"
    )

    return patcher
end

return getPatcher()({
    repository = "MUshihara/ironsoulkaitun",
    base_commit = "1d47f7f50ec8ecd92bca691b17d586d6bdecfa55",
    path = "systems/transition_watchdog.lua",
    patch_paths = {
        "systems/patches/watchdog_v61_6.patch",
        "systems/patches/watchdog_v61_6_1_hotfix.patch",
        "systems/patches/watchdog_v61_6_2_learning_guard.patch",
        "systems/patches/watchdog_v61_8_learned_fastpath.patch",
        "systems/patches/watchdog_v61_11_2_progression_guard.patch",
    },
})
