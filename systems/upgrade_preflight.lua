--========================================================--
-- IRON SOUL - POST-FORGE UPGRADE PREFLIGHT V61.28
--
-- Exact order:
--   historical Forge/EquipBest
--     -> pet acquisition bridge (claim/start hatch/EquipBest)
--     -> Blessing/Fortify manager
--     -> Smart Enchant manager
--     -> exact upgrade-demand file
--     -> demand-driven SMART Cave
--     -> Smart Hell fallback if next Normal stage is blocked
--     -> otherwise historical Story planner
--========================================================--

local Preflight = {}
Preflight.VERSION = "V61.28"
Preflight.LOG_FILE = "IronSoul_UpgradePreflight_V61_28.txt"

local function write(lines)
    if type(writefile) == "function" then
        pcall(writefile, Preflight.LOG_FILE, table.concat(lines, "\n"))
    end
end

local function status(text)
    local fn = getgenv().IronSoulStatus
    if type(fn) == "function" then
        pcall(fn, "Upgrade | " .. tostring(text))
    end
    print("[IronSoul Upgrade V61.28]", tostring(text))
end

function Preflight.Run()
    local lines = {
        "Version=" .. Preflight.VERSION,
        "StartedUnix=" .. tostring(os.time()),
        "PlaceId=" .. tostring(game.PlaceId),
    }

    local loadRaw = getgenv().IronSoulLoadRaw
    if type(loadRaw) ~= "function" then
        table.insert(lines, "Result=LOADER_UNAVAILABLE")
        write(lines)
        return false, "LOADER_UNAVAILABLE"
    end

    -- Pet acquisition is intentionally non-blocking for Story progression.
    local okPetLoad, petManager = loadRaw("systems/pet_manager.lua")
    if okPetLoad and type(petManager) == "table" and type(petManager.Run) == "function" then
        local okPetRun, petOk, petDetail = pcall(petManager.Run)
        table.insert(lines, "PetManagerPcall=" .. tostring(okPetRun))
        table.insert(lines, "PetManagerOk=" .. tostring(petOk))
        table.insert(lines, "PetManagerDetail=" .. tostring(petDetail))
        if not okPetRun or petOk ~= true then
            status("Pet bridge unavailable; continuing core progression")
        end
    else
        table.insert(lines, "PetManager=LOAD_FAILED " .. tostring(petManager))
        status("Pet bridge load failed; continuing core progression")
    end

    local okFortify, fortify = loadRaw("systems/fortify_manager.lua")
    if not okFortify or type(fortify) ~= "table" or type(fortify.Run) ~= "function" then
        table.insert(lines, "Fortify=LOAD_FAILED " .. tostring(fortify))
        table.insert(lines, "Result=FAIL_CLOSED_TO_STORY")
        write(lines)
        return false, "FORTIFY_LOAD_FAILED"
    end

    local okRun, fortifyOk, fortifyDetail = pcall(fortify.Run)
    table.insert(lines, "FortifyPcall=" .. tostring(okRun))
    table.insert(lines, "FortifyOk=" .. tostring(fortifyOk))
    table.insert(lines, "FortifyDetail=" .. tostring(fortifyDetail))

    if not okRun then
        table.insert(lines, "Result=FAIL_CLOSED_TO_STORY")
        write(lines)
        status("Fortify error -> Story | " .. tostring(fortifyOk))
        return false, "FORTIFY_RUNTIME_FAILED"
    end

    if fortifyOk ~= true then
        table.insert(lines, "Result=FAIL_CLOSED_TO_STORY")
        write(lines)
        status("Fortify unavailable -> Story")
        return false, "FORTIFY_NOT_READY"
    end

    local okEnchant, enchant = loadRaw("systems/enchant_manager.lua")
    if not okEnchant or type(enchant) ~= "table" or type(enchant.Run) ~= "function" then
        table.insert(lines, "Enchant=LOAD_FAILED " .. tostring(enchant))
        table.insert(lines, "Result=FAIL_CLOSED_TO_STORY")
        write(lines)
        return false, "ENCHANT_LOAD_FAILED"
    end

    local okEnchantRun, enchantOk, enchantDetail = pcall(enchant.Run)
    table.insert(lines, "EnchantPcall=" .. tostring(okEnchantRun))
    table.insert(lines, "EnchantOk=" .. tostring(enchantOk))
    table.insert(lines, "EnchantDetail=" .. tostring(enchantDetail))

    if not okEnchantRun then
        table.insert(lines, "Result=FAIL_CLOSED_TO_STORY")
        write(lines)
        status("Enchant error -> Story | " .. tostring(enchantOk))
        return false, "ENCHANT_RUNTIME_FAILED"
    end

    if enchantOk ~= true then
        table.insert(lines, "Result=FAIL_CLOSED_TO_STORY")
        write(lines)
        status("Enchant unavailable -> Story")
        return false, "ENCHANT_NOT_READY"
    end

    local okPlanner, planner = loadRaw("systems/cave_planner.lua")
    if not okPlanner or type(planner) ~= "table" or type(planner.Run) ~= "function" then
        table.insert(lines, "CavePlanner=LOAD_FAILED " .. tostring(planner))
    else
        local okPlan, handled, detail = pcall(planner.Run)
        table.insert(lines, "CavePlannerPcall=" .. tostring(okPlan))
        table.insert(lines, "CaveHandled=" .. tostring(handled))
        table.insert(lines, "CaveDetail=" .. tostring(detail))

        if okPlan and handled == true then
            table.insert(lines, "Result=CAVE")
            write(lines)
            status("SMART Cave handled | " .. tostring(detail))
            return true, detail
        end

        if not okPlan then
            status("Cave planner failed closed; checking Hell | " .. tostring(handled))
        else
            status("No paid Cave needed; checking Hell | " .. tostring(detail))
        end
    end

    -- Hell never consumes Ticket1 and never replaces a ready Normal progression
    -- step. The Hell planner itself verifies that the next Normal stage is
    -- blocked before selecting an unlocked Hell difficulty.
    local okHell, hell = loadRaw("systems/hell_planner.lua")
    if okHell and type(hell) == "table" and type(hell.Run) == "function" then
        local okHellRun, hellHandled, hellDetail = pcall(hell.Run)
        table.insert(lines, "HellPlannerPcall=" .. tostring(okHellRun))
        table.insert(lines, "HellHandled=" .. tostring(hellHandled))
        table.insert(lines, "HellDetail=" .. tostring(hellDetail))

        if okHellRun and hellHandled == true then
            table.insert(lines, "Result=HELL")
            write(lines)
            status("SMART Hell handled | " .. tostring(hellDetail))
            return true, hellDetail
        end

        if not okHellRun then
            status("Hell planner failed closed -> Story | " .. tostring(hellHandled))
        else
            status("Hell not applicable -> Story | " .. tostring(hellDetail))
        end
    else
        table.insert(lines, "HellPlanner=LOAD_FAILED " .. tostring(hell))
        status("Hell planner unavailable -> Story")
    end

    table.insert(lines, "Result=STORY")
    write(lines)
    return false, "STORY"
end

getgenv().IronSoulUpgradePreflight = Preflight
return Preflight
