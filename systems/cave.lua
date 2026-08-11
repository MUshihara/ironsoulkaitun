--========================================================--
-- IRON SOUL - CAVE MODE V61.16 R1
--
-- First production Cave milestone:
--   * recognize Cave1 / Cave2 / Cave3 by live PlaceId + GameRoundCfg
--   * reuse the proven headless combat engine for the one-room Cave fight
--   * NEVER auto-spam Cave Tickets yet
--   * after exactly one settlement, record ticket/material deltas and return
--     to Lobby before the normal dungeon replay path can consume another ticket
--
-- Cave Trial facts validated 2026-08-12:
--   Cave1 PlaceId 91584731222940  -> Crystal Shards
--   Cave2 PlaceId 119524374829397 -> EnchantedStone/runes
--   Cave3 PlaceId 132445869992129 -> dragon-scale materials
--   observed Trial cost = 1 Ticket1/run for all three
--========================================================--

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")

local LocalPlayer = Players.LocalPlayer
local LOBBY_PLACE_ID = 117533937949084

local CAVES = {
    [91584731222940] = {
        WorldId = "Cave1",
        Name = "Cave of Crystal",
        RewardKind = "CrystalShards",
    },
    [119524374829397] = {
        WorldId = "Cave2",
        Name = "Cave of Runes",
        RewardKind = "EnchantedStone",
    },
    [132445869992129] = {
        WorldId = "Cave3",
        Name = "Abandoned Courtyard",
        RewardKind = "WholeDragonScale",
    },
}

local Cave = CAVES[game.PlaceId]
if not Cave then
    error("Cave V61.16 unsupported PlaceId=" .. tostring(game.PlaceId))
end

local loadRaw = getgenv().IronSoulLoadRaw
assert(type(loadRaw) == "function", "Cave V61.16 loader unavailable")

local function status(text)
    text = tostring(text or "")

    local fn = getgenv().IronSoulStatus
    if type(fn) == "function" then
        pcall(fn, "Cave | " .. text)
    end

    print("[IronSoul Cave V61.16]", text)
end

local function findModule(name)
    for _, obj in ipairs(ReplicatedStorage:GetDescendants()) do
        if obj:IsA("ModuleScript") and obj.Name == name then
            return obj
        end
    end
end

local DataUtil
local WorldUtil

do
    local module = findModule("DataUtil")
    if module then
        local ok, value = pcall(require, module)
        if ok and type(value) == "table" then
            DataUtil = value
        end
    end
end

do
    local module = findModule("WorldUtil")
    if module then
        local ok, value = pcall(require, module)
        if ok and type(value) == "table" then
            WorldUtil = value
        end
    end
end

local function pdata()
    if type(DataUtil) ~= "table" or type(DataUtil.GetPlayerData) ~= "function" then
        return nil
    end

    local ok, value = pcall(function()
        return DataUtil:GetPlayerData(LocalPlayer)
    end)

    return ok and type(value) == "table" and value or nil
end

local function ticket1(data)
    return data
        and data.Currency
        and tonumber(data.Currency.Ticket1)
        or nil
end

local function crystal(data, id)
    return data
        and data.Crystals
        and tonumber(data.Crystals[id])
        or 0
end

local function enchantedCount(data)
    local owned = data
        and data.EnchantedStone
        and data.EnchantedStone.Owned

    if type(owned) ~= "table" then
        return 0
    end

    local n = 0
    for _ in pairs(owned) do
        n += 1
    end
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

status(
    "START | "
        .. tostring(Cave.Name)
        .. " | WorldId="
        .. tostring(liveWorldId)
        .. " | Diff="
        .. tostring(liveDiff)
        .. " | Ticket1="
        .. tostring(StartTicket)
)

if liveWorldId ~= nil and tostring(liveWorldId) ~= Cave.WorldId then
    status(
        "WARNING | Place says "
            .. tostring(Cave.WorldId)
            .. " but GameRoundCfg says "
            .. tostring(liveWorldId)
    )
end

local function writeRun(result)
    if type(writefile) ~= "function" then
        return
    end

    local now = pdata()
    local nowTicket = ticket1(now)
    local nowReward = rewardValue(now)

    pcall(
        writefile,
        "IronSoul_CaveRun_V61_16.txt",
        table.concat({
            "Version=V61.16",
            "Result=" .. tostring(result),
            "PlaceId=" .. tostring(game.PlaceId),
            "WorldId=" .. tostring(Cave.WorldId),
            "Name=" .. tostring(Cave.Name),
            "Diff=" .. tostring(liveDiff),
            "Elapsed=" .. string.format("%.2f", os.clock() - StartAt),
            "Ticket1Before=" .. tostring(StartTicket),
            "Ticket1After=" .. tostring(nowTicket),
            "TicketDelta=" .. tostring(
                StartTicket and nowTicket and (nowTicket - StartTicket) or nil
            ),
            "RewardKind=" .. tostring(Cave.RewardKind),
            "RewardBefore=" .. tostring(StartReward),
            "RewardAfter=" .. tostring(nowReward),
            "RewardDelta=" .. tostring(nowReward - StartReward),
            "GameRoundComplete=" .. tostring(
                cfg and cfg:GetAttribute("GameRoundComplete")
            ),
            "GameOver=" .. tostring(
                cfg and cfg:GetAttribute("GameOver")
            ),
            "Settlement=" .. tostring(LocalPlayer:GetAttribute("Settlement")),
        }, "\n")
    )
end

local function returnLobby(reason)
    if Finished then
        return
    end
    Finished = true

    -- Give reward replication a tiny bounded window. This is still well ahead
    -- of the generic dungeon replay window and prevents a second Ticket1 spend.
    task.wait(0.22)

    writeRun(reason)
    status("CLEAR | one-run policy -> Lobby | " .. tostring(reason))

    local queueBootstrap = getgenv().IronSoulQueueBootstrap
    if type(queueBootstrap) == "function" then
        pcall(queueBootstrap, "cave one-run complete -> lobby")
    end

    local sent = false
    if type(WorldUtil) == "table" and WorldUtil.RemoteEvent then
        sent = pcall(function()
            WorldUtil.RemoteEvent:FireServer("BackLobby")
        end)
    end

    task.delay(2.0, function()
        if game.PlaceId ~= LOBBY_PLACE_ID then
            pcall(function()
                TeleportService:Teleport(LOBBY_PLACE_ID, LocalPlayer)
            end)
        end
    end)

    return sent
end

-- Settlement watcher is installed BEFORE combat.lua. Cave combat can therefore
-- use all proven headless attack logic, while this wrapper owns Cave replay policy.
local function checkSettlement(reason)
    if Finished then
        return
    end

    local settlement = LocalPlayer:GetAttribute("Settlement") == true
    local gameOver = cfg and cfg:GetAttribute("GameOver") == true
    local complete = cfg and tonumber(cfg:GetAttribute("GameRoundComplete")) or 0

    if settlement or (gameOver and complete >= 1) then
        task.spawn(returnLobby, reason)
    end
end

LocalPlayer:GetAttributeChangedSignal("Settlement"):Connect(function()
    checkSettlement("PLAYER_SETTLEMENT")
end)

if cfg then
    cfg:GetAttributeChangedSignal("GameOver"):Connect(function()
        checkSettlement("GAME_OVER")
    end)

    cfg:GetAttributeChangedSignal("GameRoundComplete"):Connect(function()
        checkSettlement("ROUND_COMPLETE")
    end)
end

-- Queue normal stable entry for any teleport caused by combat/recovery too.
local queueBootstrap = getgenv().IronSoulQueueBootstrap
if type(queueBootstrap) == "function" then
    pcall(queueBootstrap, "cave run")
end

-- Safety: do not start a paid cave when this server already shows no ticket.
-- Entry itself consumed the ticket in the validated runs, so zero here may be
-- legitimate after teleport; therefore only log it, never abort a run already paid for.
if StartTicket ~= nil and StartTicket <= 0 then
    status("NOTICE | Ticket1 is 0 after cave entry; finishing paid run only")
end

local ok, result = loadRaw("systems/combat.lua")
if not ok then
    writeRun("COMBAT_LOAD_FAILED")
    error("Cave combat load failed: " .. tostring(result))
end

return result
