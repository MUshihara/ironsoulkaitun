-- IRON SOUL - V61.11 STABLE LOBBY ENTRY
-- Mobile/executor compatibility is normalized by bootstrap_v61_11 BEFORE
-- this file loads. Keep the proven forge/progression patches isolated here;
-- do not patch the early queue block at runtime again.

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

    local fn, err = loadstring(source)
    assert(fn, err)

    local patcher = fn()
    assert(
        type(patcher) == "function",
        "V61.11 lobby patch loader unavailable"
    )

    return patcher
end

return getPatcher()({
    repository = "MUshihara/ironsoulkaitun",
    base_commit = "1d47f7f50ec8ecd92bca691b17d586d6bdecfa55",
    path = "systems/lobby.lua",
    patch_paths = {
        "systems/patches/lobby_v61_6.patch",
        "systems/patches/lobby_v61_7_reserve_best_ore.patch",
        "systems/patches/lobby_v61_8_forge_metrics.patch",
    },
})
