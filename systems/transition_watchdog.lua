-- IRON SOUL - V61.6 TRANSITION WATCHDOG ENTRY
-- Applies the verified V61.6 watchdog patch to the immutable V61.5 source.

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
        "V61.6 patch loader unavailable"
    )

    return patcher
end

return getPatcher()({
    repository = "MUshihara/ironsoulkaitun",
    base_commit = "1d47f7f50ec8ecd92bca691b17d586d6bdecfa55",
    path = "systems/transition_watchdog.lua",
    patch_paths = {
        "systems/patches/watchdog_v61_6.patch",
    },
})