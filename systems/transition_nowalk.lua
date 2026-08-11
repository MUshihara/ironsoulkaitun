--========================================================--
-- IRON SOUL - WORLD1 TWEEN TRANSITION WRAPPER V61.14
--
-- User-required movement style:
--   * NO Humanoid walking / MoveTo for World1 transitions.
--   * Smooth fast CFrame tween/floating movement instead of hard snaps.
--   * Exact current-1 portal only.
--   * Exact touch/handshake + authoritative progression verification.
--   * Never generic RoundPortal RF.
--========================================================--

local baseLoadRaw =
    getgenv().IronSoulDependencyBaseLoadRaw
    or getgenv().IronSoulLoadRaw

assert(type(baseLoadRaw) == "function", "V61.14 base loader unavailable")

local ok, baseFactory = baseLoadRaw("systems/transition.lua")
assert(ok and type(baseFactory) == "function", "V61.14 base transition unavailable")

local motionOk, Motion = baseLoadRaw("systems/world1_motion.lua")
assert(motionOk and type(Motion) == "table", "V61.14 World1 motion unavailable")

return function(D)
    local R = baseFactory(D)
    assert(type(R) == "table", "V61.14 base transition build failed")

    local basePulse = R.PulseNativeMovement
    local baseGuided = R.GuidedWalk

    local ReplicatedStorage =
        D.ReplicatedStorage
        or game:GetService("ReplicatedStorage")

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

        if type(D.portalLog) == "function" then
            pcall(D.portalLog, tostring(name) .. " " .. tostring(detail or ""))
        end
    end

    local function getRoot()
        if type(D.getRoot) ~= "function" then
            return nil
        end

        local okRoot, root = pcall(D.getRoot)
        return okRoot and root or nil
    end

    local function hasObjective()
        if type(D.hasCombatObjective) ~= "function" then
            return false
        end

        local okObjective, value = pcall(D.hasCombatObjective)
        return okObjective and value == true
    end

    local function gameRound()
        if type(D.gameRound) ~= "function" then
            return nil
        end

        local okRound, value = pcall(D.gameRound)
        return okRound and tonumber(value) or nil
    end

    local function exactCurrentPortal()
        if type(D.exactRoundDoorPortal) ~= "function" then
            return nil, "NO_PORTAL_RESOLVER"
        end

        local okPortal, portal = pcall(D.exactRoundDoorPortal)
        if not okPortal or not portal or not portal.Parent or not portal:IsA("BasePart") then
            return nil, "NO_EXACT_PORTAL"
        end

        local current = gameRound()
        local roundNum = tonumber(portal:GetAttribute("RoundNum"))

        if current and roundNum and roundNum ~= current - 1 then
            return nil, "PORTAL_NOT_CURRENT_MINUS_1"
        end

        local root = getRoot()
        if not root then
            return nil, "NO_ROOT"
        end

        local distance = (portal.Position - root.Position).Magnitude
        local maxDistance =
            D.CFG
            and tonumber(D.CFG.FAST_PORTAL_MAX_DISTANCE)
            or 900

        if distance > maxDistance then
            return nil, "PORTAL_TOO_FAR"
        end

        return portal, nil, distance
    end

    local function exactTouch(root, portal)
        if type(D.firetouchinterest) ~= "function"
            or not root
            or not portal
            or not portal.Parent
        then
            return false
        end

        local ok0 = pcall(D.firetouchinterest, root, portal, 0)
        task.wait(0.025)
        local ok1 = pcall(D.firetouchinterest, root, portal, 1)
        return ok0 or ok1
    end

    local function progressionEvidence(beforeRound, oldRegion, verifyFrom)
        if hasObjective() then
            return "OBJECTIVE_APPEARED"
        end

        local nowRound = gameRound()
        if beforeRound and nowRound and nowRound ~= beforeRound then
            return "GAME_ROUND_CHANGED"
        end

        if type(D.portalTeleportEvidence) == "function" then
            local okEvidence, evidence =
                pcall(D.portalTeleportEvidence, verifyFrom, oldRegion)

            if okEvidence and evidence then
                if typeof(evidence) == "Instance" then
                    return "NEW_REGION"
                end
                return tostring(evidence)
            end
        end

        return nil
    end

    local function horizontal(v, fallback)
        local h = Vector3.new(v.X, 0, v.Z)
        if h.Magnitude < 0.1 then
            h = fallback or Vector3.new(0, 0, 1)
        end
        if h.Magnitude < 0.1 then
            h = Vector3.new(0, 0, 1)
        end
        return h.Unit
    end

    local function tweenPortal(oldRegion, reason)
        if hasObjective() then
            return false, "OBJECTIVE_ACTIVE"
        end

        local root = getRoot()
        if not root or not root.Parent then
            return false, "NO_ROOT"
        end

        local portal, why, startDistance = exactCurrentPortal()
        if not portal then
            return false, why
        end

        local beforeRound = gameRound()
        local fromPortal = horizontal(
            root.Position - portal.Position,
            -portal.CFrame.LookVector
        )

        -- Keep the same proven portal geometry: about 10 studs before and
        -- 12-14 studs through. Only the visual movement style changes.
        local preDistance =
            D.CFG
            and tonumber(D.CFG.FAST_PORTAL_PRE_DISTANCE)
            or 10

        local crossDistance =
            math.max(
                12,
                D.CFG
                and tonumber(D.CFG.FAST_PORTAL_CROSS_DISTANCE)
                or 12
            )

        local travelY = root.Position.Y

        local pre = Vector3.new(
            portal.Position.X + fromPortal.X * preDistance,
            travelY,
            portal.Position.Z + fromPortal.Z * preDistance
        )

        emit(
            "TWEEN_PORTAL_START",
            "reason=" .. tostring(reason)
                .. " round=" .. tostring(portal:GetAttribute("RoundNum"))
                .. " dist=" .. string.format("%.1f", startDistance or -1)
                .. " pre=" .. tostring(pre)
                .. " portal=" .. tostring(portal.Position)
        )

        local moved, moveKind, moveDist, moveTime = Motion.MoveToPosition(
            root,
            pre,
            Vector3.new(portal.Position.X, travelY, portal.Position.Z),
            {
                Speed = startDistance and startDistance > 80 and Motion.FAR_SPEED or Motion.DEFAULT_SPEED,
                MaxTime = 0.90,
            }
        )

        if not moved then
            return false, "TWEEN_PRE_FAILED_" .. tostring(moveKind)
        end

        emit(
            "TWEEN_PORTAL_APPROACH",
            "kind=" .. tostring(moveKind)
                .. " studs=" .. string.format("%.1f", moveDist or 0)
                .. " time=" .. string.format("%.2f", moveTime or 0)
        )

        -- Baseline AFTER approach tween. Never count our own glide as portal
        -- progression evidence.
        local verifyFrom = root.Position

        local early = progressionEvidence(beforeRound, oldRegion, verifyFrom)
        if early then
            emit("TWEEN_PORTAL_SUCCESS", "phase=pre result=" .. tostring(early))
            return true, "TWEEN_" .. tostring(early)
        end

        exactTouch(root, portal)

        local beyond = Vector3.new(
            portal.Position.X - fromPortal.X * crossDistance,
            travelY,
            portal.Position.Z - fromPortal.Z * crossDistance
        )

        Motion.MoveToPosition(
            root,
            beyond,
            Vector3.new(portal.Position.X, travelY, portal.Position.Z),
            {
                Speed = Motion.DEFAULT_SPEED,
                MaxTime = 0.28,
            }
        )

        exactTouch(root, portal)

        local deadline = os.clock() + 1.15
        while os.clock() < deadline do
            task.wait(0.06)

            local evidence = progressionEvidence(beforeRound, oldRegion, verifyFrom)
            if evidence then
                emit(
                    "TWEEN_PORTAL_SUCCESS",
                    "phase=cross result=" .. tostring(evidence)
                        .. " pos=" .. tostring(root.Position)
                )
                return true, "TWEEN_" .. tostring(evidence)
            end
        end

        -- If the game needs an exact touch frame, glide through a few tiny
        -- points inside the portal. Still no Humanoid movement/walking.
        for _, offset in ipairs({-2.0, 0.0, 2.0, -4.0, 4.0}) do
            if not portal.Parent or not root.Parent then
                break
            end

            local p = Vector3.new(
                portal.Position.X + fromPortal.X * offset,
                travelY,
                portal.Position.Z + fromPortal.Z * offset
            )

            Motion.MoveToPosition(
                root,
                p,
                Vector3.new(portal.Position.X, travelY, portal.Position.Z),
                {Speed = 240, MaxTime = 0.12}
            )

            exactTouch(root, portal)
            task.wait(0.045)

            local evidence = progressionEvidence(beforeRound, oldRegion, verifyFrom)
            if evidence then
                emit(
                    "TWEEN_PORTAL_SUCCESS",
                    "phase=touch_probe offset=" .. tostring(offset)
                        .. " result=" .. tostring(evidence)
                )
                return true, "TWEEN_" .. tostring(evidence)
            end
        end

        emit(
            "TWEEN_PORTAL_NO_PROGRESS",
            "reason=" .. tostring(reason)
                .. " finalDist=" .. tostring(
                    portal.Parent and (portal.Position - root.Position).Magnitude or nil
                )
        )

        return false, "TWEEN_PORTAL_NO_PROGRESSION"
    end

    function R:PulseNativeMovement(oldRegion, preferred, reason)
        if worldId() ~= "World1" then
            return basePulse(self, oldRegion, preferred, reason)
        end

        local okTween, result = tweenPortal(oldRegion, "PULSE:" .. tostring(reason))
        if okTween then
            return true, result
        end

        emit("WORLD1_NATIVE_WALK_SKIPPED", tostring(result))
        return false, "WORLD1_TWEEN_ONLY"
    end

    function R:GuidedWalk(oldRegion, reason)
        if worldId() ~= "World1" then
            return baseGuided(self, oldRegion, reason)
        end

        return tweenPortal(oldRegion, "GUIDED:" .. tostring(reason))
    end

    return R
end
