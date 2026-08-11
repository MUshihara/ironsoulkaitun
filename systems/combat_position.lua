-- IRON SOUL - V61.7 COMBAT POSITION ENTRY
-- Applies boss-safe burst-lock positioning to immutable V61.4 combat_position.

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
        "V61.7 combat position patch loader unavailable"
    )

    return patcher
end

return getPatcher()({
    repository = "MUshihara/ironsoulkaitun",
    base_commit = "602aed720534a355a2633433a951659c396c3227",
    path = "systems/combat_position.lua",
    patch_paths = {
        "systems/patches/combat_position_v61_7_burst_lock.patch",
    },
})