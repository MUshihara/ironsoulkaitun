--========================================================--
-- IRON SOUL - SMART HELL FARM PLANNER V61.28
--
-- Hell is a free material/ore farming fallback, not a replacement for Normal
-- progression. Run order:
--   Normal stage ready -> historical Story planner wins.
--   Normal stage blocked -> highest safe server-unlocked Hell stage.
--
-- Hell configs omit RecBattlePower in the live V61.27 recon. To fail safely,
-- this planner uses the corresponding Normal difficulty (HellDiff - 5) as a
-- minimum power proxy and adds 15% headroom before entering Hell.
--========================================================--

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local Hell = {}

Hell.VERSION = "V61.28"
Hell.LOG_FILE = "IronSoul_HellPlanner_V61_28.txt"
Hell.POWER_SAFETY_MULTIPLIER = 1.15
Hell.SUPPORTED_WORLDS = {
    World1 = 1,
    World2 = 2,
}

local function status(text)
    local fn = getgenv().IronSoulStatus
    if type(fn) == "function" then
        pcall(fn, "Hell farm | " .. tostring(text))
    end
    print("[IronSoul Hell V61.28]", tostring(text))
end

local function write(lines)
    if type(writefile) == "function" then
        pcall(writefile, Hell.LOG_FILE, table.concat(lines, "\n"))
    end
end

local function findByName(root, wanted, className)
    for _, obj in ipairs(root:GetDescendants()) do
        if obj.Name == wanted and (not className or obj:IsA(className)) then
            return obj
        end
    end
end

local function req(name)
    local module = findByName(ReplicatedStorage, name, "ModuleScript")
    if not module then return nil end
    local ok, value = pcall(require, module)
    return ok and value or nil
end

local DataUtil = req("DataUtil")
local WorldUtil = req("WorldUtil")
local ResWorldRound = req("ResWorldRound")
local GameMatchRE = findByName(ReplicatedStorage, "GameMatchRE", "RemoteEvent")

local function pdata()
    if type(DataUtil) ~= "table" or type(DataUtil.GetPlayerData) ~= "function" then
        return nil
    end
    local ok, value = pcall(function()
        return DataUtil:GetPlayerData(LocalPlayer)
    end)
    return ok and type(value) == "table" and value or nil
end

local function level(data)
    return tonumber(LocalPlayer:GetAttribute("LG_Level"))
        or (data and data.LevelData and tonumber(data.LevelData.Level))
        or 0
end

local function power()
    return tonumber(LocalPlayer:GetAttribute("LG_PowerNew1")) or 0
end

local function clearData(data)
    if type(WorldUtil) == "table" and type(WorldUtil.GetClearData) == "function" then
        local ok, value = pcall(function()
            return WorldUtil:GetClearData(LocalPlayer)
        end)
        if ok and type(value) == "table" then return value end
    end
    return data and data.Worlds and data.Worlds.ClearWolrds or {}
end

local function isCleared(data, worldId, diff)
    local clear = clearData(data)
    return type(clear[worldId]) == "table"
        and clear[worldId]["Diff_" .. tostring(diff)] ~= nil
end

local function isUnlocked(worldId, diff)
    if type(WorldUtil) ~= "table" or type(WorldUtil.IsUnlockWorld) ~= "function" then
        return false
    end
    local ok, value = pcall(function()
        return WorldUtil:IsUnlockWorld(LocalPlayer, worldId, diff)
    end)
    return ok and value == true
end

local function allRounds()
    local out = {}
    if type(ResWorldRound) ~= "table" then return out end

    local function add(cfg)
        if type(cfg) == "table" and cfg.WorldId and cfg.DiffLevel then
            table.insert(out, cfg)
        end
    end

    if type(ResWorldRound.__index) == "table" then
        for _, key in ipairs(ResWorldRound.__index) do add(ResWorldRound[key]) end
    else
        for _, cfg in pairs(ResWorldRound) do add(cfg) end
    end
    return out
end

local function normalSibling(rounds, worldId, normalDiff)
    for _, cfg in ipairs(rounds) do
        if cfg.WorldId == worldId
            and tostring(cfg.Style) == "Normal"
            and tonumber(cfg.DiffLevel) == tonumber(normalDiff)
        then
            return cfg
        end
    end
end

local function nextNormal(data, rounds)
    local normal = {}
    for _, cfg in ipairs(rounds) do
        local order = Hell.SUPPORTED_WORLDS[cfg.WorldId]
        if order and tostring(cfg.Style) == "Normal" then
            table.insert(normal, cfg)
        end
    end

    table.sort(normal, function(a, b)
        local aw = Hell.SUPPORTED_WORLDS[a.WorldId] or 999
        local bw = Hell.SUPPORTED_WORLDS[b.WorldId] or 999
        if aw ~= bw then return aw < bw end
        return (tonumber(a.DiffLevel) or 0) < (tonumber(b.DiffLevel) or 0)
    end)

    for _, cfg in ipairs(normal) do
        local diff = tonumber(cfg.DiffLevel) or 0
        if not isCleared(data, cfg.WorldId, diff) and isUnlocked(cfg.WorldId, diff) then
            return cfg
        end
    end
end

local function chooseHell(data, rounds, lines)
    local lv = level(data)
    local pw = power()
    local worlds = data and data.Worlds or {}
    if worlds.OpenHell ~= true then
        table.insert(lines, "OpenHell=false")
        return nil, "HELL_NOT_OPEN"
    end

    local candidate = {}
    for _, cfg in ipairs(rounds) do
        local worldOrder = Hell.SUPPORTED_WORLDS[cfg.WorldId]
        local diff = tonumber(cfg.DiffLevel) or 0
        if worldOrder
            and tostring(cfg.Style) == "Hell"
            and diff >= 6
            and isUnlocked(cfg.WorldId, diff)
            and lv >= (tonumber(cfg.RecPlayerLv) or 0)
        then
            local sibling = normalSibling(rounds, cfg.WorldId, diff - 5)
            local basePower = sibling and tonumber(sibling.RecBattlePower) or 0
            local safePower = math.ceil(basePower * Hell.POWER_SAFETY_MULTIPLIER)
            local powerReady = basePower <= 0 or pw >= safePower

            table.insert(lines,
                "HellCandidate=" .. tostring(cfg.WorldId)
                    .. ",Diff=" .. tostring(diff)
                    .. ",RecLv=" .. tostring(cfg.RecPlayerLv)
                    .. ",ProxyNormalPower=" .. tostring(basePower)
                    .. ",SafePower=" .. tostring(safePower)
                    .. ",PowerReady=" .. tostring(powerReady)
            )

            if powerReady then
                table.insert(candidate, {
                    Cfg = cfg,
                    WorldOrder = worldOrder,
                    Diff = diff,
                    SafePower = safePower,
                })
            end
        end
    end

    table.sort(candidate, function(a, b)
        if a.WorldOrder ~= b.WorldOrder then return a.WorldOrder > b.WorldOrder end
        return a.Diff > b.Diff
    end)

    return candidate[1], candidate[1] and "READY" or "NO_SAFE_HELL"
end

local function roomContainer()
    return Workspace:FindFirstChild("MatchRoom")
end

local function enteredRoomId()
    return LocalPlayer:GetAttribute("EnterRoomId")
end

local function roomById(id)
    local c = roomContainer()
    return c and id and c:FindFirstChild(tostring(id))
end

local function isFreeRoom(room)
    local owner = tonumber(room:GetAttribute("HomeownerId"))
    return not owner or owner == 0 or owner == LocalPlayer.UserId
end

local function findFreeRoom()
    local deadline = os.clock() + 5
    while os.clock() < deadline do
        local c = roomContainer()
        if c then
            local rooms = {}
            for _, room in ipairs(c:GetChildren()) do
                if (room:IsA("Model") or room:IsA("Folder")) and isFreeRoom(room) then
                    table.insert(rooms, room)
                end
            end
            table.sort(rooms, function(a,b) return a.Name < b.Name end)
            if rooms[1] then return rooms[1] end
        end
        task.wait(0.10)
    end
end

local function getRoot()
    local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    return char:WaitForChild("HumanoidRootPart", 8)
end

local function touchParts(room)
    local preferred, fallback = {}, {}
    for _, obj in ipairs(room:GetDescendants()) do
        if obj:IsA("BasePart") then
            local low = string.lower(obj.Name)
            local touch = obj:FindFirstChildOfClass("TouchTransmitter") ~= nil
            if touch
                or string.find(low, "enter", 1, true)
                or string.find(low, "trigger", 1, true)
                or string.find(low, "touch", 1, true)
            then
                table.insert(preferred, obj)
            else
                table.insert(fallback, obj)
            end
        end
    end
    return #preferred > 0 and preferred or fallback
end

local function waitRoom(timeout)
    local deadline = os.clock() + (timeout or 1)
    while os.clock() < deadline do
        local id = enteredRoomId()
        if id and id ~= "" then return tostring(id) end
        task.wait(0.05)
    end
end

local function enterRoom(room)
    local existing = enteredRoomId()
    if existing and existing ~= "" then return true end

    local root = getRoot()
    if not root then return false end
    local original = root.CFrame
    local parts = touchParts(room)

    if type(firetouchinterest) == "function" then
        for _, part in ipairs(parts) do
            pcall(function()
                firetouchinterest(root, part, 0)
                task.wait(0.04)
                firetouchinterest(root, part, 1)
            end)
            if waitRoom(0.45) then return true end
        end
    end

    for _, part in ipairs(parts) do
        root.CFrame = part.CFrame * CFrame.new(0, 2.5, 0)
        if waitRoom(0.65) then return true end
    end

    if room:IsA("Model") then
        root.CFrame = room:GetPivot() * CFrame.new(0, 3, 0)
        if waitRoom(1.2) then return true end
    end

    root.CFrame = original
    return false
end

function Hell.Run()
    local config = getgenv().IronSoulConfig or {}
    if config.HELL_AUTO == false then return false, "DISABLED" end

    local data = pdata()
    if not data or not WorldUtil or not WorldUtil.RemoteEvent or not GameMatchRE then
        return false, "MISSING_DATA_OR_REMOTES"
    end

    local rounds = allRounds()
    local lines = {
        "Version=" .. Hell.VERSION,
        "StartedUnix=" .. tostring(os.time()),
        "Level=" .. tostring(level(data)),
        "Power=" .. tostring(power()),
        "OpenHell=" .. tostring(data.Worlds and data.Worlds.OpenHell),
    }

    local normal = nextNormal(data, rounds)
    if normal then
        local needLv = tonumber(normal.RecPlayerLv) or 0
        local needPower = tonumber(normal.RecBattlePower) or 0
        local normalReady = level(data) >= needLv and power() >= needPower
        table.insert(lines,
            "NextNormal=" .. tostring(normal.WorldId)
                .. ",Diff=" .. tostring(normal.DiffLevel)
                .. ",NeedLv=" .. tostring(needLv)
                .. ",NeedPower=" .. tostring(needPower)
                .. ",Ready=" .. tostring(normalReady)
        )
        if normalReady then
            table.insert(lines, "Result=NORMAL_READY")
            write(lines)
            return false, "NORMAL_READY"
        end
    else
        table.insert(lines, "NextNormal=none")
    end

    local chosen, reason = chooseHell(data, rounds, lines)
    if not chosen then
        table.insert(lines, "Result=" .. tostring(reason))
        write(lines)
        return false, reason
    end

    local room
    local existing = enteredRoomId()
    if existing and existing ~= "" then
        room = roomById(existing)
    else
        room = findFreeRoom()
        if not room then
            table.insert(lines, "Result=NO_FREE_ROOM")
            write(lines)
            return false, "NO_FREE_ROOM"
        end
        if not enterRoom(room) then
            table.insert(lines, "Result=ROOM_ENTER_FAILED")
            write(lines)
            return false, "ROOM_ENTER_FAILED"
        end
    end

    local roomId = enteredRoomId()
    if not roomId or roomId == "" then
        table.insert(lines, "Result=ENTER_ROOM_ID_MISSING")
        write(lines)
        return false, "ENTER_ROOM_ID_MISSING"
    end

    local cfg = chosen.Cfg
    local queueBootstrap = getgenv().IronSoulQueueBootstrap
    if type(queueBootstrap) ~= "function"
        or not queueBootstrap("smart hell -> " .. tostring(cfg.WorldId) .. " D" .. tostring(cfg.DiffLevel))
    then
        table.insert(lines, "Result=QUEUE_FAILED")
        write(lines)
        return false, "QUEUE_FAILED"
    end

    table.insert(lines,
        "Chosen=" .. tostring(cfg.WorldId)
            .. ",Diff=" .. tostring(cfg.DiffLevel)
            .. ",SafePower=" .. tostring(chosen.SafePower)
    )
    table.insert(lines, "Result=START_HELL")
    write(lines)

    status("START " .. tostring(cfg.WorldId) .. " Hell D" .. tostring(cfg.DiffLevel)
        .. " | power=" .. tostring(power()) .. "/safe>=" .. tostring(chosen.SafePower))

    WorldUtil.RemoteEvent:FireServer("SelectWorld", cfg.WorldId, cfg.DiffLevel)
    task.wait(0.18)
    GameMatchRE:FireServer("CreatRoom", cfg.WorldId, cfg.DiffLevel, 1)

    return true, tostring(cfg.WorldId) .. "_HELL_D" .. tostring(cfg.DiffLevel)
end

getgenv().IronSoulHellPlanner = Hell
return Hell
