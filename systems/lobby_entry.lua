--========================================================--
-- IRON SOUL - LOBBY ENTRY V61.20
--
-- External pre-Lobby maintenance layer.
-- Runs only free/idempotent maintenance before the historical Lobby wrapper:
--   1) activate server-unlocked SkillTree branches for every weapon class;
--   2) then hand off to systems/lobby.lua unchanged.
--
-- If skill maintenance fails, fail closed into the normal Lobby flow.
--========================================================--

local function status(text)
    text = tostring(text or "")

    local fn = getgenv().IronSoulStatus
    if type(fn) == "function" then
        pcall(fn, text)
    end

    print("[IronSoul Lobby Entry V61.20]", text)
end

local loadRaw = getgenv().IronSoulLoadRaw
assert(type(loadRaw) == "function", "V61.20 Lobby entry loader unavailable")

status("Free skill maintenance")

do
    local okSkill, manager = loadRaw("systems/skill_manager.lua")

    if okSkill and type(manager) == "table" and type(manager.Run) == "function" then
        local okRun, handled, detail = pcall(manager.Run)

        if not okRun then
            status("Skill manager failed closed | " .. tostring(handled))
        elseif handled == true then
            status("Skill maintenance complete")
        else
            status("Skill maintenance skipped | " .. tostring(detail or handled))
        end
    elseif not okSkill then
        status("Skill manager unavailable | " .. tostring(manager))
    end
end

status("Continue normal Lobby")

local okLobby, result = loadRaw("systems/lobby.lua")
if not okLobby then
    error("V61.20 Lobby handoff failed: " .. tostring(result))
end

return result
