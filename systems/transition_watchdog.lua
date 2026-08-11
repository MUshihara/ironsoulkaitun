-- IRON SOUL - V61.11.3 LOCAL-SAFE TRANSITION WATCHDOG ENTRY
--
-- Keep the previously proven V61.8 watchdog internals untouched, but place a
-- safety wrapper in front of them. This avoids another fragile late diff while
-- fixing the World2 regression discovered from live recon:
--   * current-1 PortalD can be the legitimate local route;
--   * a replicated current-1 Portal can also exist 1000+ studs away;
--   * far portal CFrame recovery must never outrank a local PortalD.
--
-- Wrapper policy:
--   1) Find ALL current-1 RoundDoor portal roots whose parent starts "Portal"
--      (Portal, PortalD, future Portal* variants).
--   2) If a local one exists <= 220 studs, cross it using native Humanoid
--      movement only. No RF force, no far CFrame snap, no displacement-only
--      success signal.
--   3) Require authoritative progression evidence: settlement, objective,
--      GameRound change, or a genuinely new nearby RoundWakeTouch region.
--   4) If current-1 portals exist only far away, refuse recovery instead of
--      letting the historical watchdog snap to them.
--   5) Only when NO current-1 RoundDoor portal is replicated do we delegate to
--      the older learned-route / bounded-probe recovery.

local function getPatcher()
    local loadRaw = getgenv().IronSoulLoadRaw

    if type(loadRaw) == "function" then
        local ok, patcher = loadRaw("systems/patch_loader.lua")
        if ok and type(patcher) == "function" then
            return patcher
        end
    end

    local source = game:HttpGet(
        "https://raw.githubusercontent.com/MUshihara/ironsoulkaitun/main/systems/patch_loader.lua?t="
            .. tostring(os.time())
    )

    local fn, err = loadstring(source)
    assert(fn, err)

    local patcher = fn()
    assert(type(patcher) == "function", "V61.11.3 watchdog patch loader unavailable")
    return patcher
end

local baseFactory = getPatcher()({
    repository = "MUshihara/ironsoulkaitun",
    base_commit = "1d47f7f50ec8ecd92bca691b17d586d6bdecfa55",
    path = "systems/transition_watchdog.lua",
    patch_paths = {
        "systems/patches/watchdog_v61_6.patch",
        "systems/patches/watchdog_v61_6_1_hotfix.patch",
        "systems/patches/watchdog_v61_6_2_learning_guard.patch",
        "systems/patches/watchdog_v61_8_learned_fastpath.patch",
    },
})

assert(type(baseFactory) == "function", "V61.11.3 base watchdog factory unavailable")

return function(D)
    local old = baseFactory(D)
    assert(type(old) == "table", "V61.11.3 base watchdog build failed")

    local W = {}
    local MAX_LOCAL_PORTAL_DISTANCE = 220

    local function emit(name, detail)
        if type(D.event) == "function" then
            pcall(D.event, name, detail)
        end
    end

    local function getRoot()
        if type(D.getRoot) ~= "function" then
            return nil
        end

        local ok, value = pcall(D.getRoot)
        return ok and value or nil
    end

    local function hasObjective()
        if type(D.hasCombatObjective) ~= "function" then
            return false
        end

        local ok, value = pcall(D.hasCombatObjective)
        return ok and value == true
    end

    local function settled()
        if type(D.settlementDetected) ~= "function" then
            return false
        end

        local ok, value = pcall(D.settlementDetected)
        return ok and value == true
    end

    local function gameRound()
        if type(D.gameRound) ~= "function" then
            return nil
        end

        local ok, value = pcall(D.gameRound)
        return ok and tonumber(value) or nil
    end

    local function currentPortalRows()
        local root = getRoot()
        local round = gameRound()
        local folder = workspace:FindFirstChild("RoundDoor")
        local rows = {}

        if not root or not round or not folder then
            return rows
        end

        for _, part in ipairs(folder:GetDescendants()) do
            if part:IsA("BasePart")
                and part.Name == "Root"
                and part.Parent
                and string.sub(tostring(part.Parent.Name), 1, 6) == "Portal"
            then
                local roundNum = tonumber(part:GetAttribute("RoundNum"))

                if roundNum == round - 1 then
                    local distance = (part.Position - root.Position).Magnitude
                    table.insert(rows, {
                        Root = part,
                        ParentName = tostring(part.Parent.Name),
                        RoundNum = roundNum,
                        Distance = distance,
                    })
                end
            end
        end

        table.sort(rows, function(a, b)
            return a.Distance < b.Distance
        end)

        return rows
    end

    local function progressionEvidence(beforeRound, beforeRegion)
        if settled() then
            return "SETTLEMENT"
        end

        if hasObjective() then
            return "OBJECTIVE_APPEARED"
        end

        local nowRound = gameRound()
        if beforeRound and nowRound and nowRound ~= beforeRound then
            return "GAME_ROUND_CHANGED"
        end

        local root = getRoot()
        if not root then
            return nil
        end

        if type(D.nearestWakeRegion) == "function" then
            local ok, region, distance = pcall(D.nearestWakeRegion, root.Position)
            if ok
                and region
                and region ~= beforeRegion
                and tonumber(distance)
                and tonumber(distance) <= 28
            then
                return "NEW_REGION"
            end
        end

        return nil
    end

    local function thinAxis(part)
        if part.Size.X <= part.Size.Z then
            local v = part.CFrame.RightVector
            return Vector3.new(v.X, 0, v.Z)
        end

        local v = part.CFrame.LookVector
        return Vector3.new(v.X, 0, v.Z)
    end

    local function walkFor(humanoid, target, deadline, beforeRound, beforeRegion)
        while os.clock() < deadline do
            if hasObjective() or settled() then
                return progressionEvidence(beforeRound, beforeRegion)
            end

            local root = getRoot()
            if not root or not root.Parent or humanoid.Health <= 0 then
                return nil
            end

            pcall(humanoid.MoveTo, humanoid, target)
            task.wait(0.08)

            local evidence = progressionEvidence(beforeRound, beforeRegion)
            if evidence then
                pcall(humanoid.Move, humanoid, Vector3.zero, false)
                return evidence
            end
        end

        return progressionEvidence(beforeRound, beforeRegion)
    end

    local function tryLocalPortal(row, oldRegion)
        local root = getRoot()
        local character = D.LocalPlayer and D.LocalPlayer.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")

        if not root or not humanoid or humanoid.Health <= 0
            or not row or not row.Root or not row.Root.Parent
        then
            return false, "LOCAL_PORTAL_INVALID"
        end

        if row.Distance > MAX_LOCAL_PORTAL_DISTANCE then
            return false, "LOCAL_PORTAL_TOO_FAR"
        end

        local beforeRound = gameRound()
        local beforeRegion = oldRegion

        if not beforeRegion and type(D.getCurrentRegion) == "function" then
            local ok, value = pcall(D.getCurrentRegion)
            if ok then
                beforeRegion = value
            end
        end

        emit(
            "WATCHDOG_LOCAL_PORTAL_START",
            "name=" .. tostring(row.ParentName)
                .. " round=" .. tostring(row.RoundNum)
                .. " dist=" .. string.format("%.1f", row.Distance)
                .. " pos=" .. tostring(row.Root.Position)
        )

        local axis = thinAxis(row.Root)
        if axis.Magnitude < 0.1 then
            axis = Vector3.new(0, 0, 1)
        else
            axis = axis.Unit
        end

        local delta = root.Position - row.Root.Position
        local side = delta:Dot(axis) >= 0 and 1 or -1
        local halfThin = math.min(row.Root.Size.X, row.Root.Size.Z) * 0.5

        -- First enter the real portal volume using normal Humanoid movement.
        local evidence = walkFor(
            humanoid,
            row.Root.Position,
            os.clock() + 2.2,
            beforeRound,
            beforeRegion
        )

        if not evidence then
            -- Then cross completely through the portal along its thin axis.
            local beyond = row.Root.Position - axis * side * (halfThin + 7)
            evidence = walkFor(
                humanoid,
                beyond,
                os.clock() + 2.2,
                beforeRound,
                beforeRegion
            )
        end

        -- Allow streamed objective/region state a short moment to settle.
        if not evidence then
            local settleDeadline = os.clock() + 0.8
            while os.clock() < settleDeadline do
                task.wait(0.08)
                evidence = progressionEvidence(beforeRound, beforeRegion)
                if evidence then
                    break
                end
            end
        end

        pcall(humanoid.Move, humanoid, Vector3.zero, false)

        if evidence then
            emit(
                "WATCHDOG_LOCAL_PORTAL_SUCCESS",
                "name=" .. tostring(row.ParentName)
                    .. " evidence=" .. tostring(evidence)
            )

            return true, "WATCHDOG_LOCAL_PORTAL_" .. tostring(evidence)
        end

        emit(
            "WATCHDOG_LOCAL_PORTAL_FAIL",
            "name=" .. tostring(row.ParentName)
                .. " round=" .. tostring(row.RoundNum)
        )

        return false, "LOCAL_PORTAL_NO_PROGRESSION"
    end

    function W:Recover(oldRegion, reason)
        if hasObjective() then
            return false, "OBJECTIVE_ACTIVE"
        end

        local rows = currentPortalRows()
        local localRows = {}
        local farRows = {}

        for _, row in ipairs(rows) do
            if row.Distance <= MAX_LOCAL_PORTAL_DISTANCE then
                table.insert(localRows, row)
            else
                table.insert(farRows, row)
            end
        end

        if #localRows > 0 then
            for i = 1, math.min(3, #localRows) do
                local ok, result = tryLocalPortal(localRows[i], oldRegion)
                if ok then
                    return true, result
                end
            end

            -- A legitimate local current-1 portal exists. Never abandon it to
            -- snap toward a different far replicated copy in this recovery.
            return false, "LOCAL_CURRENT_PORTAL_UNRESOLVED"
        end

        if #farRows > 0 then
            emit(
                "WATCHDOG_FAR_PORTAL_REJECT",
                "reason=" .. tostring(reason)
                    .. " nearest=" .. string.format("%.1f", farRows[1].Distance)
                    .. " name=" .. tostring(farRows[1].ParentName)
                    .. " round=" .. tostring(farRows[1].RoundNum)
            )

            return false, "ONLY_FAR_CURRENT_PORTALS"
        end

        if type(old.Recover) == "function" then
            return old:Recover(oldRegion, reason)
        end

        return false, "BASE_RECOVER_UNAVAILABLE"
    end

    function W:HasLearnedRoute()
        local rows = currentPortalRows()
        local nearestLocal = nil
        local nearestFar = nil

        for _, row in ipairs(rows) do
            if row.Distance <= MAX_LOCAL_PORTAL_DISTANCE then
                nearestLocal = nearestLocal or row
            else
                nearestFar = nearestFar or row
            end
        end

        -- Treat a legitimate local current-1 portal as an immediately usable
        -- safe recovery route, even if it has never been learned before.
        if nearestLocal then
            return true,
                "LOCAL_CURRENT_PORTAL",
                nearestLocal.ParentName,
                nearestLocal.Distance
        end

        if nearestFar then
            return false,
                "ONLY_FAR_CURRENT_PORTALS",
                nearestFar.ParentName,
                nearestFar.Distance
        end

        if type(old.HasLearnedRoute) == "function" then
            return old:HasLearnedRoute()
        end

        return false, "NO_SAFE_ROUTE"
    end

    return W
end
