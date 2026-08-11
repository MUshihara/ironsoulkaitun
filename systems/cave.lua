--========================================================--
-- IRON SOUL - CAVE MODE V61.17 R1
--
-- First production Cave milestone:
--   * recognize Cave1 / Cave2 / Cave3 by live PlaceId + GameRoundCfg
--   * reuse the proven headless combat engine for the one-room Cave fight
--   * NEVER auto-spam Cave Tickets yet
--   * after exactly one settlement, return to Lobby before replay can consume
--     another Ticket1
--   * persist a pre-reward baseline; Lobby resolves the authoritative material
--     delta after PlayerData has fully replicated there
--========================================================--

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")

local LocalPlayer = Players.LocalPlayer
local LOBBY_PLACE_ID = 117533937949084
local PENDING_FILE = "IronSoul_CavePending_V61_17.txt"

local CAVES = {
    [91584731222940] = {WorldId="Cave1", Name="Cave of Crystal", RewardKind="CrystalShards"},
    [119524374829397] = {WorldId="Cave2", Name="Cave of Runes", RewardKind="EnchantedStone"},
    [132445869992129] = {WorldId="Cave3", Name="Abandoned Courtyard", RewardKind="WholeDragonScale"},
}

local Cave = CAVES[game.PlaceId]
if not Cave then
    error("Cave V61.17 unsupported PlaceId=" .. tostring(game.PlaceId))
end

local loadRaw = getgenv().IronSoulLoadRaw
assert(type(loadRaw) == "function", "Cave V61.17 loader unavailable")

local function status(text)
    text = tostring(text or "")
    local fn = getgenv().IronSoulStatus
    if type(fn) == "function" then pcall(fn, "Cave | " .. text) end
    print("[IronSoul Cave V61.17]", text)
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

local function readPending()
    if type(readfile) ~= "function" then return nil end
    if type(isfile) == "function" and not isfile(PENDING_FILE) then return nil end
    local ok, text = pcall(readfile, PENDING_FILE)
    if not ok or type(text) ~= "string" or text == "" then return nil end
    return parse(text)
end

local function findModule(name)
    for _, obj in ipairs(ReplicatedStorage:GetDescendants()) do
        if obj:IsA("ModuleScript") and obj.Name == name then return obj end
    end
end

local DataUtil
local WorldUtil

do
    local module = findModule("DataUtil")
    if module then
        local ok, value = pcall(require, module)
        if ok and type(value) == "table" then DataUtil = value end
    end
end

do
    local module = findModule("WorldUtil")
    if module then
        local ok, value = pcall(require, module)
        if ok and type(value) == "table" then WorldUtil = value end
    end
end

local function pdata()
    if type(DataUtil) ~= "table" or type(DataUtil.GetPlayerData) ~= "function" then return nil end
    local ok, value = pcall(function() return DataUtil:GetPlayerData(LocalPlayer) end)
    return ok and type(value) == "table" and value or nil
end

local function ticket1(data)
    return data and data.Currency and tonumber(data.Currency.Ticket1) or nil
end

local function crystal(data, id)
    return data and data.Crystals and tonumber(data.Crystals[id]) or 0
end

local function enchantedCount(data)
    local owned = data and data.EnchantedStone and data.EnchantedStone.Owned
    if type(owned) ~= "table" then return 0 end
    local n = 0
    for _ in pairs(owned) do n += 1 end
    return n
end

local function rewardValue(data)
    if Cave.RewardKind == "CrystalShards" then
        return crystal(data, "CrystalShards")
    elseif Cave.RewardKind == "WholeDragonScale" then
        return crystal(data, "WholeDragonScale")
    elseif Cave.RewardKind == "EnchantedStone" then
        return enchantedCount(data)
    end
    return 0
end

local StartData = pdata()
local StartTicket = ticket1(StartData)
local StartReward = rewardValue(StartData)
local StartAt = os.clock()
local Finished = false

local cfg = ReplicatedStorage:FindFirstChild("GameRoundCfg")
local liveWorldId = cfg and cfg:GetAttribute("WorldId")
local liveDiff = cfg and cfg:GetAttribute("DiffLevel")

local function writePending(result)
    if type(writefile) ~= "function" then return end

    -- If a future SMART Lobby planner created this baseline BEFORE CreatRoom,
    -- preserve its authoritative TicketBeforeEntry/RewardBefore values.
    local row = readPending() or {}
    local samePending = row.Resolved ~= "true"
        and tostring(row.WorldId or "") == tostring(Cave.WorldId)
        and tonumber(row.StartedUnix or 0) > 0
        and os.time() - tonumber(row.StartedUnix or 0) < 600

    if not samePending then row = {} end

    row.Version = "V61.17"
    row.Resolved = "false"
    row.PlaceId = tostring(game.PlaceId)
    row.WorldId = tostring(Cave.WorldId)
    row.Name = tostring(Cave.Name)
    row.Diff = tostring(liveDiff)
    row.StartedUnix = row.StartedUnix or tostring(os.time())
    row.RewardKind = tostring(Cave.RewardKind)
    row.RewardBefore = row.RewardBefore or tostring(StartReward)
    row.TicketAtCaveStart = row.TicketAtCaveStart or tostring(StartTicket)
    row.Result = tostring(result or "RUNNING")

    pcall(writefile, PENDING_FILE, serialize(row))
end

status("START | " .. tostring(Cave.Name)
    .. " | WorldId=" .. tostring(liveWorldId)
    .. " | Diff=" .. tostring(liveDiff)
    .. " | Ticket1=" .. tostring(StartTicket))

if liveWorldId ~= nil and tostring(liveWorldId) ~= Cave.WorldId then
    status("WARNING | Place says " .. tostring(Cave.WorldId)
        .. " but GameRoundCfg says " .. tostring(liveWorldId))
end

writePending("RUNNING")

local function writeRun(result)
    if type(writefile) ~= "function" then return end
    local now = pdata()
    local nowTicket = ticket1(now)
    local nowReward = rewardValue(now)

    pcall(writefile, "IronSoul_CaveRun_V61_17.txt", table.concat({
        "Version=V61.17",
        "AuditScope=CAVE_LOCAL_PRE_RETURN",
        "FinalAuditFile=IronSoul_CaveAudit_V61_17.txt",
        "Result=" .. tostring(result),
        "PlaceId=" .. tostring(game.PlaceId),
        "WorldId=" .. tostring(Cave.WorldId),
        "Name=" .. tostring(Cave.Name),
        "Diff=" .. tostring(liveDiff),
        "Elapsed=" .. string.format("%.2f", os.clock() - StartAt),
        "TicketAtCaveStart=" .. tostring(StartTicket),
        "TicketLocalBeforeReturn=" .. tostring(nowTicket),
        "RewardKind=" .. tostring(Cave.RewardKind),
        "RewardBefore=" .. tostring(StartReward),
        "RewardLocalBeforeReturn=" .. tostring(nowReward),
        "GameRoundComplete=" .. tostring(cfg and cfg:GetAttribute("GameRoundComplete")),
        "GameOver=" .. tostring(cfg and cfg:GetAttribute("GameOver")),
        "Settlement=" .. tostring(LocalPlayer:GetAttribute("Settlement")),
        "Note=Authoritative reward delta is reconciled after Lobby PlayerData readiness.",
    }, "\n"))
end

local function returnLobby(reason)
    if Finished then return end
    Finished = true

    task.wait(0.22)
    writePending(reason)
    writeRun(reason)
    status("CLEAR | one-run policy -> Lobby | " .. tostring(reason))

    local queueBootstrap = getgenv().IronSoulQueueBootstrap
    if type(queueBootstrap) == "function" then
        pcall(queueBootstrap, "cave one-run complete -> lobby")
    end

    if type(WorldUtil) == "table" and WorldUtil.RemoteEvent then
        pcall(function() WorldUtil.RemoteEvent:FireServer("BackLobby") end)
    end

    task.delay(2.0, function()
        if game.PlaceId ~= LOBBY_PLACE_ID then
            pcall(function() TeleportService:Teleport(LOBBY_PLACE_ID, LocalPlayer) end)
        end
    end)
end

local function checkSettlement(reason)
    if Finished then return end
    local settlement = LocalPlayer:GetAttribute("Settlement") == true
    local gameOver = cfg and cfg:GetAttribute("GameOver") == true
    local complete = cfg and tonumber(cfg:GetAttribute("GameRoundComplete")) or 0
    if settlement or (gameOver and complete >= 1) then task.spawn(returnLobby, reason) end
end

LocalPlayer:GetAttributeChangedSignal("Settlement"):Connect(function()
    checkSettlement("PLAYER_SETTLEMENT")
end)

if cfg then
    cfg:GetAttributeChangedSignal("GameOver"):Connect(function() checkSettlement("GAME_OVER") end)
    cfg:GetAttributeChangedSignal("GameRoundComplete"):Connect(function() checkSettlement("ROUND_COMPLETE") end)
end

local queueBootstrap = getgenv().IronSoulQueueBootstrap
if type(queueBootstrap) == "function" then pcall(queueBootstrap, "cave run") end

if StartTicket ~= nil and StartTicket <= 0 then
    status("NOTICE | Ticket1 is 0 after cave entry; finishing paid run only")
end

-- Prevent systems/combat.lua from redirecting back into Cave mode while this
-- wrapper deliberately loads the proven underlying combat entry.
getgenv().IronSoulInsideCaveCombat = true
local ok, result = loadRaw("systems/combat.lua")
getgenv().IronSoulInsideCaveCombat = nil

if not ok then
    writePending("COMBAT_LOAD_FAILED")
    writeRun("COMBAT_LOAD_FAILED")
    error("Cave combat load failed: " .. tostring(result))
end

return result
