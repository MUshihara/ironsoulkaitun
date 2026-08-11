-- IRON SOUL - V61.13 24/7 LOBBY PREFLIGHT
--
-- Keep the proven lobby implementation underneath, but never let a slow fresh
-- account permanently die on the historical 25-second PlayerData gate.
--
-- Policy:
--   * wait indefinitely for real lobby readiness;
--   * report the exact missing readiness signals;
--   * require several consecutive ready checks before entering lobby logic;
--   * queue the stable bootstrap.lua across teleports, never a stale version;
--   * do not patch the early lobby environment again.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer
local BASE = "https://raw.githubusercontent.com/MUshihara/ironsoulkaitun/main/"

local function status(text)
    text = tostring(text or "")

    local fn = getgenv().IronSoulStatus
    if type(fn) == "function" then
        pcall(fn, text)
    end

    print("[IronSoul Lobby V61.13]", text)
end

local function writeReadiness(text)
    if type(writefile) == "function" then
        pcall(
            writefile,
            "IronSoul_LobbyReadiness_V61_13.txt",
            tostring(text or "")
        )
    end
end

local DataUtilModule = nil
local DataUtil = nil

local function findDataUtil()
    if DataUtilModule and DataUtilModule.Parent then
        return DataUtilModule
    end

    for _, obj in ipairs(ReplicatedStorage:GetDescendants()) do
        if obj:IsA("ModuleScript") and obj.Name == "DataUtil" then
            DataUtilModule = obj
            return obj
        end
    end
end

local function getDataUtil()
    if type(DataUtil) == "table" then
        return DataUtil
    end

    local module = findDataUtil()
    if not module then
        return nil, "DataUtil module missing"
    end

    local ok, value = pcall(require, module)
    if not ok or type(value) ~= "table" then
        return nil, "DataUtil require failed"
    end

    DataUtil = value
    return DataUtil
end

local function readiness()
    local missing = {}
    local data = nil

    local util, utilErr = getDataUtil()

    if not util then
        table.insert(missing, utilErr or "DataUtil unavailable")
    elseif type(util.GetPlayerData) ~= "function" then
        table.insert(missing, "DataUtil.GetPlayerData missing")
    else
        local ok, value = pcall(function()
            return util:GetPlayerData(LocalPlayer)
        end)

        if ok and type(value) == "table" then
            data = value
        else
            table.insert(missing, "PlayerData table unavailable")
        end
    end

    local loadedAttr = LocalPlayer:GetAttribute("Loaded")
    local levelAttr = LocalPlayer:GetAttribute("LG_Level")
    local powerAttr = LocalPlayer:GetAttribute("LG_PowerNew1")

    if loadedAttr == false then
        table.insert(missing, "Loaded=false")
    end

    if levelAttr == nil then
        table.insert(missing, "LG_Level=nil")
    end

    if powerAttr == nil then
        table.insert(missing, "LG_PowerNew1=nil")
    end

    return #missing == 0 and data ~= nil,
        table.concat(missing, ", "),
        data,
        loadedAttr,
        levelAttr,
        powerAttr
end

-- Fresh/mobile accounts can take much longer than the old 25-second lobby
-- timeout. For a 24/7 kaitun, waiting with useful state is safer than stopping.
local started = os.clock()
local lastReport = -math.huge
local stableReady = 0

while stableReady < 4 do
    local ready,
        missing,
        data,
        loadedAttr,
        levelAttr,
        powerAttr = readiness()

    if ready then
        stableReady += 1
    else
        stableReady = 0
    end

    local elapsed = os.clock() - started

    if os.clock() - lastReport >= 2.0 or ready then
        lastReport = os.clock()

        local detail = table.concat({
            "Version=V61.13",
            "Elapsed=" .. string.format("%.2f", elapsed),
            "Ready=" .. tostring(ready),
            "StableChecks=" .. tostring(stableReady) .. "/4",
            "Loaded=" .. tostring(loadedAttr),
            "LG_Level=" .. tostring(levelAttr),
            "LG_PowerNew1=" .. tostring(powerAttr),
            "PlayerData=" .. tostring(type(data)),
            "Missing=" .. tostring(missing),
        }, "\n")

        writeReadiness(detail)

        if ready then
            status(
                "Lobby data stabilizing | "
                    .. tostring(stableReady)
                    .. "/4"
            )
        else
            status(
                "Lobby waiting for data | "
                    .. (missing ~= "" and missing or "unknown")
                    .. " | "
                    .. string.format("%.1fs", elapsed)
            )
        end
    end

    if stableReady < 4 then
        task.wait(0.25)
    end
end

status("Lobby PlayerData ready | starting progression")

-- Always queue the STABLE bootstrap entry. This prevents a continuous session
-- from getting pinned to an old versioned bootstrap after production updates.
do
    local queue = rawget(getgenv(), "queue_on_teleport")

    if type(queue) == "function" then
        getgenv().IronSoulQueueBootstrap = function(reason)
            local config = getgenv().IronSoulConfig or {}

            local payload = string.format([[
task.wait(1.35)
getgenv().IronSoulConfig = getgenv().IronSoulConfig or {
    FPS_CAP = %s,
    FARM = %q,
    TICKETS = %q,
    HEADLESS = %s,
    DEBUG_LOGS = %s,
}
loadstring(game:HttpGet(
    %q .. "?t=" .. tostring(os.time())
))()
]],
                tostring(tonumber(config.FPS_CAP) or 8),
                tostring(config.FARM or "NEWBIE"),
                tostring(config.TICKETS or "SMART"),
                tostring(config.HEADLESS ~= false),
                tostring(config.DEBUG_LOGS == true),
                BASE .. "bootstrap.lua"
            )

            local ok, result = pcall(queue, payload)

            if ok then
                status(
                    "Queued stable bootstrap | "
                        .. tostring(reason or "next teleport")
                )
                return true
            end

            status("ERROR | stable queue failed | " .. tostring(result))
            return false
        end
    end
end

local function getPatcher()
    local loadRaw = getgenv().IronSoulLoadRaw

    if type(loadRaw) == "function" then
        local ok, patcher = loadRaw("systems/patch_loader.lua")

        if ok and type(patcher) == "function" then
            return patcher
        end
    end

    local source = game:HttpGet(
        BASE .. "systems/patch_loader.lua?t=" .. tostring(os.time())
    )

    local fn, err = loadstring(source)
    assert(fn, err)

    local patcher = fn()
    assert(type(patcher) == "function", "V61.13 lobby patch loader unavailable")
    return patcher
end

-- Proven lobby body remains unchanged below this preflight.
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
