--========================================================--
-- IRON SOUL - POST-FORGE UPGRADE PREFLIGHT V61.23
--
-- Exact order:
--   historical Forge/EquipBest
--     -> safe Fortify manager
--     -> exact upgrade-demand file
--     -> demand-driven SMART Cave
--     -> otherwise historical Story planner
--========================================================--

local Preflight = {}
Preflight.VERSION = "V61.23"
Preflight.LOG_FILE = "IronSoul_UpgradePreflight_V61_23.txt"

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
    print("[IronSoul Upgrade V61.23]", tostring(text))
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

    -- A false Fortify result means exact demand could not be trusted. Do not
    -- spend a Cave ticket using a stale demand file.
    if fortifyOk ~= true then
        table.insert(lines, "Result=FAIL_CLOSED_TO_STORY")
        write(lines)
        status("Fortify unavailable -> Story")
        return false, "FORTIFY_NOT_READY"
    end

    local okPlanner, planner = loadRaw("systems/cave_planner.lua")
    if not okPlanner or type(planner) ~= "table" or type(planner.Run) ~= "function" then
        table.insert(lines, "CavePlanner=LOAD_FAILED " .. tostring(planner))
        table.insert(lines, "Result=STORY")
        write(lines)
        return false, "CAVE_PLANNER_LOAD_FAILED"
    end

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

    table.insert(lines, "Result=STORY")
    write(lines)

    if not okPlan then
        status("Cave planner failed closed -> Story | " .. tostring(handled))
    else
        status("No paid Cave needed -> Story | " .. tostring(detail))
    end

    return false, detail or "STORY"
end

getgenv().IronSoulUpgradePreflight = Preflight
return Preflight
