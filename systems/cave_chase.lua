--========================================================--
-- IRON SOUL - CAVE ONE-ROOM CHASE V61.18
--
-- Cave1/Cave2/Cave3 are validated one-round resource activities. Do not wait
-- for Story combat's target-stall recovery when the next Cave enemy is far.
-- Smoothly float/tween into the Round1 arena and directly near distant live
-- enemies, then let the proven headless combat driver own attacks.
--========================================================--

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local Chase = {}

Chase.VERSION = "V61.18"
Chase.ENGAGE_DISTANCE = 45
Chase.STANDOFF = 7.5
Chase.HEIGHT = 8.5
Chase.SPEED = 300
Chase.MAX_MOVE_TIME = 0.78
Chase.IDLE_STEP = 0.12
Chase.NO_ENEMY_WAKE_DELAY = 0.90

local CAVE_PLACES = {
    [91584731222940] = true,
    [119524374829397] = true,
    [132445869992129] = true,
}

local Running = false
local StartedAt = 0
local LastEnemySeenAt = os.clock()
local LastMoveAt = -math.huge

local function status(text)
    local fn = getgenv().IronSoulStatus
    if type(fn) == "function" then
        pcall(fn, "Cave chase | " .. tostring(text))
    end

    if type(writefile) == "function" then
        pcall(
            writefile,
            "IronSoul_CaveChase_V61_18.txt",
            table.concat({
                "Version=V61.18",
                "PlaceId=" .. tostring(game.PlaceId),
                "At=" .. tostring(os.time()),
                "Status=" .. tostring(text),
            }, "\n")
        )
    end
end

local function root()
    local character = LocalPlayer.Character
    return character and character:FindFirstChild("HumanoidRootPart")
end

local function enemyRoot(model)
    if not model then return nil end
    return model:FindFirstChild("HumanoidRootPart")
        or model.PrimaryPart
        or model:FindFirstChildWhichIsA("BasePart")
end

local function nearestEnemy(r)
    local folder = Workspace:FindFirstChild("EnemyNpc")
    if not folder or not r then return nil end

    local bestModel
    local bestRoot
    local bestDist = math.huge

    for _, obj in ipairs(folder:GetChildren()) do
        if obj:IsA("Model") then
            local hum = obj:FindFirstChildOfClass("Humanoid")
            local er = hum and hum.Health > 0 and enemyRoot(obj) or nil

            if er then
                local dist = (er.Position - r.Position).Magnitude
                if dist < bestDist then
                    bestDist = dist
                    bestModel = obj
                    bestRoot = er
                end
            end
        end
    end

    return bestModel, bestRoot, bestDist
end

local function round1Wake()
    local worldEnemies = Workspace:FindFirstChild("WorldEnemys")
    local wakeFolder = worldEnemies and worldEnemies:FindFirstChild("RoundWakeTouch")
    return wakeFolder and wakeFolder:FindFirstChild("Round1")
end

local function boxDistance(part, point)
    if not part or not part:IsA("BasePart") then return math.huge end
    local localPoint = part.CFrame:PointToObjectSpace(point)
    local half = part.Size * 0.5
    local dx = math.max(math.abs(localPoint.X) - half.X, 0)
    local dy = math.max(math.abs(localPoint.Y) - half.Y, 0)
    local dz = math.max(math.abs(localPoint.Z) - half.Z, 0)
    return Vector3.new(dx, dy, dz).Magnitude
end

local function motion()
    local existing = getgenv().IronSoulWorld1Motion
    if type(existing) == "table" and type(existing.MoveToPosition) == "function" then
        return existing
    end

    local loadRaw = getgenv().IronSoulLoadRaw
    if type(loadRaw) == "function" then
        local ok, value = loadRaw("systems/world1_motion.lua")
        if ok and type(value) == "table" and type(value.MoveToPosition) == "function" then
            return value
        end
    end
end

local function nearEnemyPosition(r, er)
    local away = Vector3.new(r.Position.X - er.Position.X, 0, r.Position.Z - er.Position.Z)
    if away.Magnitude < 0.1 then
        away = Vector3.new(1, 0, 0)
    end
    away = away.Unit

    return er.Position
        + away * Chase.STANDOFF
        + Vector3.new(0, Chase.HEIGHT, 0)
end

local function moveNearEnemy(r, model, er, dist)
    local m = motion()
    if not m then return false end

    local target = nearEnemyPosition(r, er)
    local look = er.Position + Vector3.new(0, 2.5, 0)

    status(
        "ENEMY_TWEEN_START name=" .. tostring(model.Name)
            .. " dist=" .. string.format("%.1f", dist)
    )

    local ok, mode, moved, elapsed = m.MoveToPosition(
        r,
        target,
        look,
        {
            Speed = Chase.SPEED,
            MaxTime = Chase.MAX_MOVE_TIME,
            MinTime = 0.08,
        }
    )

    LastMoveAt = os.clock()

    status(
        "ENEMY_TWEEN_RESULT ok=" .. tostring(ok)
            .. " mode=" .. tostring(mode)
            .. " moved=" .. tostring(moved)
            .. " elapsed=" .. tostring(elapsed)
    )

    return ok
end

local function moveIntoWake(r, wake)
    local m = motion()
    if not m or not wake or not wake:IsA("BasePart") then return false end

    local target = wake.Position + Vector3.new(0, 5.5, 0)
    local horizontal = Vector3.new(r.Position.X - wake.Position.X, 0, r.Position.Z - wake.Position.Z)
    if horizontal.Magnitude > 0.1 then
        target = target + horizontal.Unit * math.min(10, wake.Size.X * 0.15)
    end

    status("WAKE_TWEEN_START dist=" .. string.format("%.1f", boxDistance(wake, r.Position)))

    local ok = m.MoveToPosition(
        r,
        target,
        wake.Position,
        {
            Speed = Chase.SPEED,
            MaxTime = Chase.MAX_MOVE_TIME,
            MinTime = 0.08,
        }
    )

    LastMoveAt = os.clock()
    return ok == true
end

function Chase.Start()
    if Running or not CAVE_PLACES[game.PlaceId] then
        return Running
    end

    Running = true
    StartedAt = os.clock()
    LastEnemySeenAt = os.clock()
    status("START")

    task.spawn(function()
        while Running and CAVE_PLACES[game.PlaceId] do
            if LocalPlayer:GetAttribute("Settlement") == true then
                break
            end

            local r = root()
            if r then
                local model, er, dist = nearestEnemy(r)

                if model and er and dist then
                    LastEnemySeenAt = os.clock()

                    if dist > Chase.ENGAGE_DISTANCE
                        and os.clock() - LastMoveAt > 0.18
                    then
                        moveNearEnemy(r, model, er, dist)
                    end
                elseif os.clock() - LastEnemySeenAt >= Chase.NO_ENEMY_WAKE_DELAY
                    and os.clock() - LastMoveAt > 0.50
                then
                    local wake = round1Wake()
                    if wake and boxDistance(wake, r.Position) > 10 then
                        moveIntoWake(r, wake)
                    end
                end
            end

            task.wait(Chase.IDLE_STEP)
        end

        Running = false
        status("STOP elapsed=" .. string.format("%.2f", os.clock() - StartedAt))
    end)

    return true
end

function Chase.Stop()
    Running = false
end

getgenv().IronSoulCaveChase = Chase
return Chase
