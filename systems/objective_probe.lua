--========================================================--
-- IRON SOUL - ROUTE-BLOCKER OBJECTIVE RESOLVER V61.12
--
-- Rule:
--   enemies / eggs > exact current-round portal > real route blocker.
--
-- This module MUST NOT farm scenery just because it has HitCount.
-- A destroyable can be attacked only when it is the FIRST collidable,
-- tagged DestructibleObject physically blocking the route toward the
-- authoritative current-round portal / wake region.
--
-- Object removal alone is NOT progression success.
--========================================================--

return function(D)
    local R = {}

    local CollectionService =
        game:GetService("CollectionService")

    local LastTry = -math.huge
    local LastArchiveAt = -math.huge
    local ProbeSerial = 0

    local TRY_COOLDOWN = 0.70
    local ARCHIVE_COOLDOWN = 10.0

    local LOCAL_PORTAL_HINT_MAX = 320
    local BLOCKER_TARGET_MAX = 520
    local BLOCKER_ATTACK_MAX = 150

    local SCENERY_NAMES = {
        tree = true,
        tree1 = true,
        tree2 = true,
        tree3 = true,
        chest = true,
        chest1 = true,
        chest2 = true,
        chest3 = true,
        goldcoin = true,
        icecrystal = true,
    }

    local function emit(name, detail)
        if type(D.event) == "function" then
            pcall(D.event, name, detail)
        end
    end

    local function root()
        if type(D.getRoot) ~= "function" then
            return nil
        end

        local ok, value = pcall(D.getRoot)
        return ok and value or nil
    end

    local function currentRegion()
        if type(D.getCurrentRegion) ~= "function" then
            return nil
        end

        local ok, value = pcall(D.getCurrentRegion)
        return ok and value or nil
    end

    local function gameRound()
        if type(D.gameRound) ~= "function" then
            return nil
        end

        local ok, value = pcall(D.gameRound)
        return ok and tonumber(value) or nil
    end

    local function fullName(obj)
        if type(D.fullName) == "function" then
            local ok, value = pcall(D.fullName, obj)
            if ok then
                return tostring(value)
            end
        end

        if typeof(obj) ~= "Instance" then
            return tostring(obj)
        end

        local ok, value =
            pcall(function()
                return obj:GetFullName()
            end)

        return ok and tostring(value) or tostring(obj.Name)
    end

    local function hasNormalObjective()
        if type(D.hasNormalObjective) ~= "function" then
            return false
        end

        local ok, value = pcall(D.hasNormalObjective)
        return ok and value == true
    end

    local function settled()
        if type(D.settlementDetected) ~= "function" then
            return false
        end

        local ok, value = pcall(D.settlementDetected)
        return ok and value == true
    end

    local function portalRows()
        local r = root()
        local round = gameRound()
        local folder = workspace:FindFirstChild("RoundDoor")
        local rows = {}

        if not r or not round or not folder then
            return rows
        end

        for _, part in ipairs(folder:GetDescendants()) do
            if part:IsA("BasePart")
                and part.Name == "Root"
                and part.Parent
                and string.sub(tostring(part.Parent.Name), 1, 6) == "Portal"
            then
                local roundNum =
                    tonumber(part:GetAttribute("RoundNum"))

                if roundNum == round - 1 then
                    table.insert(rows, {
                        Root = part,
                        Name = tostring(part.Parent.Name),
                        RoundNum = roundNum,
                        Distance = (part.Position - r.Position).Magnitude,
                    })
                end
            end
        end

        table.sort(rows, function(a, b)
            return a.Distance < b.Distance
        end)

        return rows
    end

    local function currentWake()
        local round = gameRound()
        local r = root()

        if not round or not r then
            return nil, nil
        end

        local worldEnemies =
            workspace:FindFirstChild("WorldEnemys")

        local folder =
            worldEnemies
            and worldEnemies:FindFirstChild("RoundWakeTouch")

        if not folder then
            return nil, nil
        end

        local exact =
            folder:FindFirstChild(
                "Round" .. tostring(round),
                true
            )

        if exact and exact:IsA("BasePart") then
            local localPos =
                exact.CFrame:PointToObjectSpace(r.Position)

            local half = exact.Size * 0.5

            local dx =
                math.max(math.abs(localPos.X) - half.X, 0)

            local dy =
                math.max(math.abs(localPos.Y) - half.Y, 0)

            local dz =
                math.max(math.abs(localPos.Z) - half.Z, 0)

            local distance =
                Vector3.new(dx, dy, dz).Magnitude

            return exact, distance
        end

        return nil, nil
    end

    local function progressionEvidence(
        beforeRound,
        beforeRegion
    )
        if settled() then
            return "SETTLEMENT"
        end

        if hasNormalObjective() then
            return "OBJECTIVE_APPEARED"
        end

        local nowRound = gameRound()

        if beforeRound
            and nowRound
            and nowRound ~= beforeRound
        then
            return "GAME_ROUND_CHANGED"
        end

        local nowRegion = currentRegion()

        if beforeRegion
            and nowRegion
            and nowRegion ~= beforeRegion
        then
            return "REGION_CHANGED"
        end

        return nil
    end

    local function taggedDestructibleAncestor(instance)
        local current = instance

        while current and current ~= workspace do
            local ok, tagged =
                pcall(
                    CollectionService.HasTag,
                    CollectionService,
                    current,
                    "DestructibleObject"
                )

            if ok and tagged then
                return current
            end

            current = current.Parent
        end

        return nil
    end

    local function isExplicitScenery(obj)
        if not obj then
            return true
        end

        local low =
            string.lower(tostring(obj.Name or ""))

        if SCENERY_NAMES[low] then
            return true
        end

        local dropLoot =
            obj:GetAttribute("DropLootId")

        if dropLoot ~= nil
            and tostring(dropLoot) ~= ""
        then
            return true
        end

        return false
    end

    local function firstRouteBlocker(targetPart)
        local r = root()

        if not r
            or not targetPart
            or not targetPart.Parent
        then
            return nil, "NO_ROUTE_TARGET"
        end

        local targetPos = targetPart.Position
        local total = targetPos - r.Position
        local distance = total.Magnitude

        if distance < 4 then
            return nil, "TARGET_ALREADY_NEAR"
        end

        if distance > BLOCKER_TARGET_MAX then
            return nil, "TARGET_TOO_FAR"
        end

        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude
        params.IgnoreWater = true

        local excluded = {}

        if D.LocalPlayer and D.LocalPlayer.Character then
            table.insert(excluded, D.LocalPlayer.Character)
        end

        local direction = total

        for _ = 1, 18 do
            params.FilterDescendantsInstances = excluded

            local result =
                workspace:Raycast(
                    r.Position,
                    direction,
                    params
                )

            if not result or not result.Instance then
                return nil, "ROUTE_CLEAR"
            end

            local hit = result.Instance
            local blocker =
                taggedDestructibleAncestor(hit)

            if blocker then
                local blockerDistance =
                    (result.Position - r.Position).Magnitude

                if hit:IsA("BasePart")
                    and hit.CanCollide == true
                    and blockerDistance <= BLOCKER_ATTACK_MAX
                    and not isExplicitScenery(blocker)
                then
                    return {
                        Object = blocker,
                        HitPart = hit,
                        HitPosition = result.Position,
                        Distance = blockerDistance,
                        Target = targetPart,
                        TargetDistance = distance,
                    }
                end

                table.insert(excluded, blocker)
            else
                if hit:IsA("BasePart")
                    and (
                        hit.CanCollide == false
                        or hit.Transparency >= 0.98
                    )
                then
                    table.insert(excluded, hit)
                else
                    return nil,
                        "SOLID_NON_DESTRUCTIBLE:"
                            .. fullName(hit)
                end
            end
        end

        return nil, "RAY_LIMIT"
    end

    local function progressMetric(obj)
        if not obj or not obj.Parent then
            return nil
        end

        for _, key in ipairs({
            "HitCount",
            "HitDamage",
            "DamageTaken",
            "Progress",
            "Health",
            "HP",
            "Durability",
        }) do
            local value = obj:GetAttribute(key)

            if type(value) == "number" then
                return key, value
            end
        end

        return nil
    end

    local function archive(
        reason,
        detail
    )
        local now = os.clock()

        if now - LastArchiveAt < ARCHIVE_COOLDOWN then
            return
        end

        LastArchiveAt = now
        ProbeSerial += 1

        local r = root()

        local text =
            table.concat({
                "Version=V61.12",
                "Reason=" .. tostring(reason),
                "PlaceId=" .. tostring(game.PlaceId),
                "GameRound=" .. tostring(gameRound()),
                "PlayerPos=" .. tostring(r and r.Position),
                tostring(detail or ""),
            }, "\n")

        if type(writefile) == "function" then
            pcall(
                writefile,
                "IronSoul_LastObjectiveProbe_V61_12.txt",
                text
            )
        end

        local telemetry =
            getgenv().IronSoulTelemetry

        if telemetry
            and type(telemetry.ArchiveFile) == "function"
        then
            pcall(
                telemetry.ArchiveFile,
                telemetry,
                string.format(
                    "ObjectiveProbe_%03d_R%s.txt",
                    ProbeSerial,
                    tostring(gameRound())
                ),
                text
            )
        end
    end

    local function attackBlocker(row)
        if not row
            or not row.Object
            or not row.Object.Parent
            or not row.HitPart
            or not row.HitPart.Parent
        then
            return false, "BLOCKER_INVALID"
        end

        local r = root()

        if not r then
            return false, "NO_ROOT"
        end

        local beforeRound = gameRound()
        local beforeRegion = currentRegion()
        local obj = row.Object

        local metricKey, metricValue =
            progressMetric(obj)

        local started = os.clock()
        local lastProgress = started
        local sawProgress = false

        emit(
            "OBJECTIVE_ROUTE_BLOCKER_START",
            "name="
                .. tostring(obj.Name)
                .. " path="
                .. fullName(obj)
                .. " dist="
                .. string.format("%.1f", row.Distance)
                .. " target="
                .. fullName(row.Target)
                .. " targetDist="
                .. string.format("%.1f", row.TargetDistance)
        )

        while os.clock() - started < 4.2 do
            local evidence =
                progressionEvidence(
                    beforeRound,
                    beforeRegion
                )

            if evidence then
                return true, evidence
            end

            if not obj.Parent then
                local deadline = os.clock() + 0.65

                while os.clock() < deadline do
                    task.wait(0.08)

                    evidence =
                        progressionEvidence(
                            beforeRound,
                            beforeRegion
                        )

                    if evidence then
                        return true, evidence
                    end
                end

                emit(
                    "OBJECTIVE_ROUTE_BLOCKER_REMOVED_NO_PROGRESS",
                    "name=" .. tostring(obj.Name)
                )

                return false,
                    "BLOCKER_REMOVED_NO_PROGRESSION"
            end

            if hasNormalObjective() then
                return true, "OBJECTIVE_APPEARED"
            end

            local liveRoot = root()

            if not liveRoot then
                return false, "NO_ROOT"
            end

            local hitPos =
                row.HitPart.Parent
                and row.HitPart.Position
                or row.HitPosition

            if hitPos then
                local delta =
                    liveRoot.Position - hitPos

                local horizontal =
                    Vector3.new(
                        delta.X,
                        0,
                        delta.Z
                    )

                if horizontal.Magnitude < 0.1 then
                    horizontal =
                        -Vector3.new(
                            row.HitPart.CFrame.LookVector.X,
                            0,
                            row.HitPart.CFrame.LookVector.Z
                        )
                end

                if horizontal.Magnitude < 0.1 then
                    horizontal = Vector3.new(0, 0, 1)
                else
                    horizontal = horizontal.Unit
                end

                local goal =
                    hitPos
                    + horizontal * 5
                    + Vector3.new(0, 1.5, 0)

                liveRoot.CFrame =
                    CFrame.lookAt(goal, hitPos)
            end

            if type(D.skillReady) == "function"
                and type(D.castSkill) == "function"
            then
                if D.skillReady("Skill2") then
                    pcall(D.castSkill, "Skill2")
                elseif D.skillReady("Skill1") then
                    pcall(D.castSkill, "Skill1")
                end
            end

            if type(D.sendHeadlessAttack) == "function" then
                pcall(D.sendHeadlessAttack)
            end

            local newKey, newValue =
                progressMetric(obj)

            if metricKey
                and newKey == metricKey
                and type(metricValue) == "number"
                and type(newValue) == "number"
                and newValue ~= metricValue
            then
                sawProgress = true
                lastProgress = os.clock()

                emit(
                    "OBJECTIVE_ROUTE_BLOCKER_DAMAGE",
                    tostring(metricKey)
                        .. " "
                        .. tostring(metricValue)
                        .. "->"
                        .. tostring(newValue)
                )

                metricValue = newValue
            elseif newKey then
                metricKey = newKey
                metricValue = newValue
            end

            if not sawProgress
                and os.clock() - lastProgress >= 1.35
            then
                return false,
                    "NO_CONFIRMED_BLOCKER_DAMAGE"
            end

            task.wait(0.11)
        end

        if sawProgress then
            return false, "DAMAGE_PROGRESS"
        end

        return false, "NO_CONFIRMED_BLOCKER_DAMAGE"
    end

    function R:TryResolve(reason, age)
        local now = os.clock()

        if now - LastTry < TRY_COOLDOWN then
            return false, "COOLDOWN"
        end

        LastTry = now

        if hasNormalObjective() then
            return false, "NORMAL_OBJECTIVE_ACTIVE"
        end

        local portals = portalRows()
        local nearestPortal = portals[1]

        if nearestPortal
            and nearestPortal.Distance <= LOCAL_PORTAL_HINT_MAX
        then
            emit(
                "OBJECTIVE_DEFER_TO_PORTAL",
                "name="
                    .. tostring(nearestPortal.Name)
                    .. " round="
                    .. tostring(nearestPortal.RoundNum)
                    .. " dist="
                    .. string.format(
                        "%.1f",
                        nearestPortal.Distance
                    )
            )

            local watchdog =
                getgenv().IronSoulTransitionWatchdog

            if watchdog
                and type(watchdog.Recover) == "function"
                and tonumber(age)
                and tonumber(age) >= 0.75
            then
                local ok, result =
                    watchdog:Recover(
                        currentRegion(),
                        "OBJECTIVE_DEFER_LOCAL_PORTAL"
                    )

                if ok then
                    return true, tostring(result)
                end
            end

            return false, "KNOWN_LOCAL_PORTAL"
        end

        local wake, wakeDistance =
            currentWake()

        if not wake
            or not wakeDistance
            or wakeDistance <= 3
            or wakeDistance > BLOCKER_TARGET_MAX
        then
            archive(
                reason,
                "No blocker target."
                    .. "\nNearestPortal="
                    .. tostring(
                        nearestPortal
                        and nearestPortal.Name
                    )
                    .. "@"
                    .. tostring(
                        nearestPortal
                        and nearestPortal.Distance
                    )
                    .. "\nWake="
                    .. tostring(
                        wake
                        and fullName(wake)
                    )
                    .. "@"
                    .. tostring(wakeDistance)
            )

            return false, "NO_SAFE_BLOCKER_TARGET"
        end

        local blocker, blockerReason =
            firstRouteBlocker(wake)

        if not blocker then
            archive(
                reason,
                "Wake="
                    .. fullName(wake)
                    .. "@"
                    .. string.format("%.1f", wakeDistance)
                    .. "\nRoute="
                    .. tostring(blockerReason)
            )

            return false,
                "NO_ROUTE_BLOCKER:"
                    .. tostring(blockerReason)
        end

        archive(
            reason,
            "BLOCKER="
                .. fullName(blocker.Object)
                .. "\nHitPart="
                .. fullName(blocker.HitPart)
                .. "\nDistance="
                .. tostring(blocker.Distance)
                .. "\nTarget="
                .. fullName(blocker.Target)
        )

        local ok, result =
            attackBlocker(blocker)

        emit(
            "OBJECTIVE_ROUTE_BLOCKER_RESULT",
            tostring(result)
        )

        if ok then
            return true,
                "OBJECTIVE_"
                    .. tostring(result)
        end

        if result == "DAMAGE_PROGRESS" then
            return false, "DAMAGE_PROGRESS"
        end

        return false, tostring(result)
    end

    return R
end
