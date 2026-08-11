-- IRON SOUL - V61.8 COMBAT ENTRY
-- Applies V61.7 boss-safe tuning, V61.8 burst-safe positioning values,
-- lightweight skill-cast telemetry, learned-route fast-path recovery, and
-- authoritative settlement finalization to the immutable V61.6 combat source.

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
        "V61.8 patch loader unavailable"
    )

    return patcher
end

return getPatcher()({
    repository = "MUshihara/ironsoulkaitun",
    base_commit = "1d47f7f50ec8ecd92bca691b17d586d6bdecfa55",
    path = "systems/combat.lua",
    patch_paths = {
        "systems/patches/combat_v61_7_boss_safe.patch",
        "systems/patches/combat_v61_8_burst_safe.patch",
        "systems/patches/combat_v61_8_skill_telemetry.patch",
        "systems/patches/combat_v61_8_learned_transition.patch",
    },
})
