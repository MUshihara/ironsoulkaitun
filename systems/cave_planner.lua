--========================================================--
-- IRON SOUL - DEMAND-DRIVEN SMART CAVE PLANNER V61.24
--
-- Paid Cave selection is driven by real blocked upgrades, not fixed stock
-- targets.
--
-- Current production demand sources:
--   Cave1 <- Blessing/Fortify CrystalShards blocker.
--   Cave2 <- Smart Enchant: useful +4 keeper has empty slot but no stone.
--   Cave3 <- held until pet-upgrade manager publishes exact material demand.
--========================================================--

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local Planner = {}

Planner.VERSION = "V61.24"
Planner.TICKET_RESERVE = 5
Planner.COOLDOWN_SECONDS = 360
Planner.TRIAL_DIFF = 1
Planner.PENDING_FILE = "IronSoul_CavePending_V61_17.txt"
-- Preserve prior cooldown state across planner upgrades.
Planner.STATE_FILE = "IronSoul_CavePlanner_V61_18.txt"
Planner.DEMAND_FILE = "IronSoul_UpgradeDemand_V61_23.txt"
Planner.DECISION_FILE = "IronSoul_CavePlannerDecision_V61_24.txt"

Planner.CAVES = {
    Cave1 = {
        WorldId = "Cave1",
        Name = "Cave of Crystal",
        MinLevel = 10,
        MinPower = 480,
        RewardKind = "CrystalShards",
    },
    Cave2 = {
        WorldId = "Cave2",
        Name = "Cave of Runes",
        MinLevel = 13,
        MinPower = 780,
        RewardKind = "EnchantedStone",
    },
    Cave3 = {
        WorldId = "Cave3",
        Name = "Abandoned Courtyard",
        MinLevel = 13,
        MinPower = 940,
        RewardKind = "WholeDragonScale",
        RequiresPet = true,
    },
}

local function status(text)
    local fn = getgenv().IronSoulStatus
    if type(fn) == "function" then
        pcall(fn, "Cave smart | " .. tostring(text))
    end
    print("[IronSoul Cave Planner V61.24]", tostring(text))
end

local function parse(text)
    local out = {}
    for line in string.gmatch(tostring(text or ""), "[^\r\n]+") do
        local k, v = string.match(line, "^([^=]+)=(.*)$")
        if k then out[k] = v end
    end
    return out
end

local function serialize(t)
    local keys = {}
    for k in pairs(t) do table.insert(keys, k) end
    table.sort(keys)

    local rows = {}
    for _, k in ipairs(keys) do
        table.insert(rows, tostring(k) .. "=" .. tostring(t[k]))
    end
    return table.concat(rows, "\n")
end

local function readFile(path)
    if type(readfile) ~= "function" then return nil end
    if type(isfile) == "function" and not isfile(path) then return nil end
    local ok, text = pcall(readfile, path)
    return ok and type(text) == "string" and text or nil
end

local function readState()
    local text = readFile(Planner.STATE_FILE)
    return text and parse(text) or {}
end

local function readDemand()
    local text = readFile(Planner.DEMAND_FILE)
    return text and parse(text) or {}
end

local function writeState(row)
    if type(writefile) == "function" then
        pcall(writefile, Planner.STATE_FILE, serialize(row))
    end
end

local function writePending(row)
    if type(writefile) == "function" then
        pcall(writefile, Planner.PENDING_FILE, serialize(row))
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
local GameMatchRE = findByName(ReplicatedStorage, "GameMatchRE", "RemoteEvent")

local function pdata()
    if type(DataUtil) ~= "table" or type(DataUtil.GetPlayerData) ~= "function" then return nil end
    local ok, value = pcall(function() return DataUtil:GetPlayerData(LocalPlayer) end)
    return ok and type(value) == "table" and value or nil
end

local function count(t)
    local n = 0
    if type(t) == "table" then
        for _ in pairs(t) do n += 1 end
    end
    return n
end

local function level(data)
    return tonumber(LocalPlayer:GetAttribute("LG_Level"))
        or (data and data.LevelData and tonumber(data.LevelData.Level))
        or 0
end

local function power()
    return tonumber(LocalPlayer:GetAttribute("LG_PowerNew1")) or 0
end

local function tickets(data)
    return data and data.Currency and tonumber(data.Currency.Ticket1) or 0
end

local function rewardValue(data, kind)
    if kind == "CrystalShards" then
        return data and data.Crystals and tonumber(data.Crystals.CrystalShards) or 0
    elseif kind == "WholeDragonScale" then
        return data and data.Crystals and tonumber(data.Crystals.WholeDragonScale) or 0
    elseif kind == "EnchantedStone" then
        return count(data and data.EnchantedStone and data.EnchantedStone.Owned)
    end
    return 0
end

local function boolValue(v)
    return tostring(v) == "true"
end

local function choose(data)
    local lv = level(data)
    local pw = power()
    local demand = readDemand()
    local candidates = {}

    -- Guaranteed Blessing/Fortify remains higher priority than Enchant because
    -- it is deterministic and its exact CrystalShards blocker is known.
    local cave1 = Planner.CAVES.Cave1
    local missingShards = tonumber(demand.CrystalShardsMissing or 0) or 0
    local currentShards = rewardValue(data, cave1.RewardKind)

    if missingShards > 0
        and lv >= cave1.MinLevel
        and pw >= cave1.MinPower
    then
        table.insert(candidates, {
            Cave = cave1,
            Current = currentShards,
            Deficit = missingShards,
            Target = currentShards + missingShards,
            Score = 1000 + missingShards,
            Reason = "FORTIFY_CRYSTAL_BLOCKER",
        })
    end

    -- V61.24 Cave2 demand is NOT a stock-count target. It is a direct state:
    -- useful +4 keeper still has an empty enchant slot, but Enchant manager has
    -- zero usable stones. One Cave2 run is requested, then Lobby re-evaluates.
    local cave2 = Planner.CAVES.Cave2
    local cave2Needed = boolValue(demand.Cave2Needed)
    local enchantMissing = tonumber(demand.EnchantStoneMissing or 0) or 0
    local eligibleEmpty = tonumber(demand.EnchantEligibleEmptySlots or 0) or 0
    local currentStones = rewardValue(data, cave2.RewardKind)

    if cave2Needed
        and enchantMissing > 0
        and eligibleEmpty > 0
        and lv >= cave2.MinLevel
        and pw >= cave2.MinPower
    then
        table.insert(candidates, {
            Cave = cave2,
            Current = currentStones,
            Deficit = 1,
            Target = currentStones + 1,
            Score = 700 + math.min(eligibleEmpty, 50),
            Reason = "ENCHANT_STONE_BLOCKER",
        })
    end

    -- Cave3 remains held until pet growth publishes exact scale/claw demand.

    table.sort(candidates, function(a,b)
        if a.Score ~= b.Score then return a.Score > b.Score end
        return a.Cave.WorldId < b.Cave.WorldId
    end)

    return candidates[1], candidates, demand
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
    local preferred = {}
    local fallback = {}

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

local function auditDecision(data, candidate, candidates, reason, demand)
    if type(writefile) ~= "function" then return end

    local rows = {
        "Version=" .. Planner.VERSION,
        "Reason=" .. tostring(reason),
        "Level=" .. tostring(level(data)),
        "Power=" .. tostring(power()),
        "Ticket1=" .. tostring(tickets(data)),
        "Reserve=" .. tostring(Planner.TICKET_RESERVE),
        "Cooldown=" .. tostring(Planner.COOLDOWN_SECONDS),
        "CrystalShards=" .. tostring(rewardValue(data, "CrystalShards")),
        "EnchantedStones=" .. tostring(rewardValue(data, "EnchantedStone")),
        "FortifyCrystalMissing=" .. tostring(demand and demand.CrystalShardsMissing or 0),
        "EnchantEligibleEmptySlots=" .. tostring(demand and demand.EnchantEligibleEmptySlots or 0),
        "EnchantUsableStones=" .. tostring(demand and demand.EnchantUsableStones or 0),
        "EnchantStoneMissing=" .. tostring(demand and demand.EnchantStoneMissing or 0),
        "Cave2Needed=" .. tostring(demand and demand.Cave2Needed or false),
        "Cave3Needed=false",
        "Chosen=" .. tostring(candidate and candidate.Cave.WorldId or "none"),
    }

    for i, row in ipairs(candidates or {}) do
        table.insert(rows,
            "Candidate" .. tostring(i)
                .. "=" .. tostring(row.Cave.WorldId)
                .. ",Reason=" .. tostring(row.Reason)
                .. ",Current=" .. tostring(row.Current)
                .. ",Target=" .. tostring(row.Target)
                .. ",Deficit=" .. tostring(row.Deficit)
                .. ",Score=" .. string.format("%.3f", row.Score)
        )
    end

    pcall(writefile, Planner.DECISION_FILE, table.concat(rows, "\n"))
end

function Planner.Run()
    local config = getgenv().IronSoulConfig or {}
    if tostring(config.TICKETS or "SMART") ~= "SMART" or config.CAVE_AUTO == false then
        return false, "DISABLED"
    end

    local data = pdata()
    if not data or not WorldUtil or not WorldUtil.RemoteEvent or not GameMatchRE then
        return false, "MISSING_DATA_OR_REMOTES"
    end

    local ticketCount = tickets(data)
    local state = readState()
    local last = tonumber(state.LastCaveUnix or 0) or 0
    local cooldownLeft = math.max(0, Planner.COOLDOWN_SECONDS - (os.time() - last))
    local candidate, all, demand = choose(data)

    if ticketCount <= Planner.TICKET_RESERVE then
        auditDecision(data, candidate, all, "TICKET_RESERVE", demand)
        return false, "TICKET_RESERVE"
    end

    if cooldownLeft > 0 then
        auditDecision(data, candidate, all, "COOLDOWN_" .. tostring(cooldownLeft), demand)
        return false, "COOLDOWN"
    end

    if not candidate then
        auditDecision(data, nil, all, "NO_VALID_UPGRADE_DEMAND", demand)
        return false, "NO_NEED"
    end

    auditDecision(data, candidate, all, "START_CAVE", demand)

    local room
    local existing = enteredRoomId()
    if existing and existing ~= "" then
        room = roomById(existing)
    else
        room = findFreeRoom()
        if not room then
            return false, "NO_FREE_ROOM"
        end
        if not enterRoom(room) then
            return false, "ROOM_ENTER_FAILED"
        end
    end

    local roomId = enteredRoomId()
    if not roomId or roomId == "" then
        return false, "ENTER_ROOM_ID_MISSING"
    end

    local cave = candidate.Cave
    local queueBootstrap = getgenv().IronSoulQueueBootstrap
    if type(queueBootstrap) ~= "function" or not queueBootstrap("smart cave -> " .. cave.WorldId) then
        return false, "QUEUE_FAILED"
    end

    local pending = {
        Version = Planner.VERSION,
        Resolved = "false",
        StartedUnix = tostring(os.time()),
        WorldId = cave.WorldId,
        Name = cave.Name,
        Diff = tostring(Planner.TRIAL_DIFF),
        RewardKind = cave.RewardKind,
        RewardBefore = tostring(candidate.Current),
        TicketBeforeEntry = tostring(ticketCount),
        PlannerReason = tostring(candidate.Reason),
        PlannerTarget = tostring(candidate.Target),
        PlannerDeficit = tostring(candidate.Deficit),
    }
    writePending(pending)

    state.LastCaveUnix = tostring(os.time())
    state.LastWorldId = cave.WorldId
    state.LastReason = tostring(candidate.Reason)
    state.LastTicketBefore = tostring(ticketCount)
    writeState(state)

    status(
        "START " .. cave.WorldId
            .. " Trial | reason=" .. tostring(candidate.Reason)
            .. " have=" .. tostring(candidate.Current)
            .. " target=" .. tostring(candidate.Target)
            .. " missing=" .. tostring(candidate.Deficit)
            .. " tickets=" .. tostring(ticketCount)
    )

    WorldUtil.RemoteEvent:FireServer("SelectWorld", cave.WorldId, Planner.TRIAL_DIFF)
    task.wait(0.18)
    GameMatchRE:FireServer("CreatRoom", cave.WorldId, Planner.TRIAL_DIFF, 1)

    local teleportObserved = false
    local conn = LocalPlayer.OnTeleport:Connect(function()
        teleportObserved = true
    end)

    local deadline = os.clock() + 18
    local started = false
    while os.clock() < deadline do
        if LocalPlayer:GetAttribute("IsTeleporting") or teleportObserved then
            started = true
            break
        end
        task.wait(0.05)
    end

    pcall(function() conn:Disconnect() end)

    if started then
        status("TELEPORT " .. cave.WorldId .. " started")
        return true, cave.WorldId
    end

    status("ERROR | Cave room created but teleport did not start")
    return true, "TELEPORT_TIMEOUT"
end

getgenv().IronSoulCavePlanner = Planner
return Planner
