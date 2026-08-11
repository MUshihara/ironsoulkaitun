--========================================================--
-- IRON SOUL - WORLD1 TELEPORT-ONLY WATCHDOG WRAPPER V61.13.3
--
-- Reuses the proven watchdog but intercepts World1 exact current-1 portals
-- before the base watchdog can use Humanoid MoveTo. World2 remains isolated.
--========================================================--

local baseLoadRaw =
    getgenv().IronSoulDependencyBaseLoadRaw
    or getgenv().IronSoulLoadRaw

assert(type(baseLoadRaw) == "function", "V61.13.3 watchdog base loader unavailable")

local ok, baseFactory = baseLoadRaw("systems/transition_watchdog.lua")
assert(ok and type(baseFactory) == "function", "V61.13.3 base watchdog unavailable")

return function(D)
    local W = baseFactory(D)
    assert(type(W) == "table", "V61.13.3 base watchdog build failed")

    local baseRecover = W.Recover

    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local MAX_LOCAL_PORTAL_DISTANCE = 320

    local function worldId()
        local cfg = ReplicatedStorage:FindFirstChild("GameRoundCfg")
        if cfg then
            local value = cfg:GetAttribute("WorldId")
            if value ~= nil then
                return tostring(value)
            end
        end

        local value = workspace:GetAttribute("WorldName")
        return value ~= nil and tostring(value) or "?"
    end

    local function emit(name, detail)
        if type(D.event) == "function" then
            pcall(D.event, name, detail)
        end
    end

    local function root()
        if type(D.getRoot) ~= "function" then
            return nil
        end

        local okRoot, value = pcall(D.getRoot)
        return okRoot and value or nil
    end

    local function round()
        if type(D.gameRound) ~= "function" then
            return nil
        end

        local okRound, value = pcall(D.gameRound)
        return okRound and tonumber(value) or nil
    end

    local function region()
        if type(D.getCurrentRegion) ~= "function" then
            return nil
        end

        local okRegion, value = pcall(D.getCurrentRegion)
        return okRegion and value or nil
    end

    local function hasObjective()
        if type(D.hasCombatObjective) ~= "function" then
            return false
        end

        local okObjective, value = pcall(D.hasCombatObjective)
        return okObjective and value == true
    end

    local function settled()
        if type(D.settlementDetected) ~= "function" then
            return false
        end

        local okSettlement, value = pcall(D.settlementDetected)
        return okSettlement and value == true
    end

    local function currentPortalRows()
        local r = root()
        local current = round()
        local folder = workspace:FindFirstChild("RoundDoor")
        local rows = {}

        if not r or not current or not folder then
            return rows
        end

        for _, part in ipairs(folder:GetDescendants()) do
            if part:IsA("BasePart")
                and part.Name == "Root"
                and part.Parent
                and string.sub(tostring(part.Parent.Name), 1, 6) == "Portal"
            then
                local roundNum = tonumber(part:GetAttribute("RoundNum"))
                if roundNum == current - 1 then
                    local distance = (part.Position - r.Position).Magnitude
                    if distance <= MAX_LOCAL_PORTAL_DISTANCE then
                        table.insert(rows, {
                            Root = part,
                            Name = tostring(part.Parent.Name),
                            RoundNum = roundNum,
                            Distance = distance,
                        })
                    end
                end
            end
        end

        table.sort(rows, function(a,b)
            return a.Distance < b.Distance
        end)

        return rows
    end

    local function horizontal(v, fallback)
        local h = Vector3.new(v.X, 0, v.Z)
        if h.Magnitude < 0.1 then
            h = fallback or Vector3.new(0,0,1)
        end
        if h.Magnitude < 0.1 then
            h = Vector3.new(0,0,1)
        end
        return h.Unit
    end

    local function exactTouch(r, portal)
        if type(D.firetouchinterest) ~= "function" then
            return false
        end

        local ok0 = pcall(D.firetouchinterest, r, portal, 0)
        task.wait(0.025)
        local ok1 = pcall(D.firetouchinterest, r, portal, 1)
        return ok0 or ok1
    end

    local function evidence(beforeRound, beforeRegion)
        if settled() then
            return "SETTLEMENT"
        end

        if hasObjective() then
            return "OBJECTIVE_APPEARED"
        end

        local nowRound = round()
        if beforeRound and nowRound and nowRound ~= beforeRound then
            return "GAME_ROUND_CHANGED"
        end

        local r = root()
        if r and type(D.nearestWakeRegion) == "function" then
            local okRegion, newRegion, distance = pcall(D.nearestWakeRegion, r.Position)
            if okRegion
                and newRegion
                and newRegion ~= beforeRegion
                and tonumber(distance)
                and tonumber(distance) <= 28
            then
                return "NEW_REGION"
            end
        end

        return nil
    end

    local function teleportPortal(row, oldRegion, reason)
        local r = root()
        if not r or not row or not row.Root or not row.Root.Parent then
            return false, "INVALID_PORTAL"
        end

        if hasObjective() then
            return false, "OBJECTIVE_ACTIVE"
        end

        local portal = row.Root
        local beforeRound = round()
        local beforeRegion = oldRegion or region()
        local fromPortal = horizontal(r.Position - portal.Position, -portal.CFrame.LookVector)

        local pre = portal.Position + fromPortal * 8 + Vector3.new(0, 2, 0)
        local beyond = portal.Position - fromPortal * 11 + Vector3.new(0, 2, 0)

        emit(
            "WATCHDOG_TELEPORT_PORTAL_START",
            "reason=" .. tostring(reason)
                .. " name=" .. tostring(row.Name)
                .. " round=" .. tostring(row.RoundNum)
                .. " dist=" .. string.format("%.1f", row.Distance)
        )

        r.CFrame = CFrame.lookAt(pre, portal.Position)
        pcall(function()
            r.AssemblyLinearVelocity = Vector3.zero
            r.AssemblyAngularVelocity = Vector3.zero
        end)
        task.wait(0.05)

        local early = evidence(beforeRound, beforeRegion)
        if early then
            return true, "WATCHDOG_TELEPORT_" .. tostring(early)
        end

        exactTouch(r, portal)
        r.CFrame = CFrame.lookAt(beyond, portal.Position)
        pcall(function()
            r.AssemblyLinearVelocity = Vector3.zero
            r.AssemblyAngularVelocity = Vector3.zero
        end)
        exactTouch(r, portal)

        local deadline = os.clock() + 1.15
        while os.clock() < deadline do
            task.wait(0.06)
            local hit = evidence(beforeRound, beforeRegion)
            if hit then
                emit(
                    "WATCHDOG_TELEPORT_PORTAL_SUCCESS",
                    "name=" .. tostring(row.Name) .. " result=" .. tostring(hit)
                )
                return true, "WATCHDOG_TELEPORT_" .. tostring(hit)
            end
        end

        for _, offset in ipairs({-2, 0, 2, -4, 4}) do
            if not r.Parent or not portal.Parent then
                break
            end

            local p = portal.Position + fromPortal * offset + Vector3.new(0, 2, 0)
            r.CFrame = CFrame.lookAt(p, portal.Position)
            exactTouch(r, portal)
            task.wait(0.07)

            local hit = evidence(beforeRound, beforeRegion)
            if hit then
                emit(
                    "WATCHDOG_TELEPORT_PORTAL_SUCCESS",
                    "name=" .. tostring(row.Name)
                        .. " offset=" .. tostring(offset)
                        .. " result=" .. tostring(hit)
                )
                return true, "WATCHDOG_TELEPORT_" .. tostring(hit)
            end
        end

        emit(
            "WATCHDOG_TELEPORT_PORTAL_FAIL",
            "name=" .. tostring(row.Name) .. " round=" .. tostring(row.RoundNum)
        )

        return false, "WATCHDOG_TELEPORT_NO_PROGRESSION"
    end

    function W:Recover(oldRegion, reason)
        if worldId() ~= "World1" then
            return baseRecover(self, oldRegion, reason)
        end

        local rows = currentPortalRows()
        if #rows > 0 then
            for i = 1, math.min(3, #rows) do
                local okTeleport, result = teleportPortal(rows[i], oldRegion, reason)
                if okTeleport then
                    return true, result
                end
            end

            -- Do not fall back to the base local-portal native walking path.
            return false, "WORLD1_LOCAL_PORTAL_TELEPORT_UNRESOLVED"
        end

        -- No exact local current portal exists. The older watchdog's bounded
        -- learned/probe recovery is still allowed; it is not the portal walk.
        return baseRecover(self, oldRegion, reason)
    end

    return W
end
