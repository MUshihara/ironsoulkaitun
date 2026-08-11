--========================================================--
-- IRON SOUL - UNKNOWN OBJECTIVE PROBE / RESOLVER V61.9
--
-- Used only after combat has no normal enemy/egg objective and progression
-- has stalled. It inventories nearby gate/wall/barrier-like objects, records
-- their replicated state, and only attacks a candidate when there is strong
-- evidence that it is a damageable progression object.
--
-- No world coordinates are hardcoded. Failed attempts are bounded and fall
-- back to the existing transition watchdog.
--========================================================--

return function(D)
    local R = {}

    local CollectionService =
        game:GetService("CollectionService")

    local LastTry = -math.huge
    local ProbeSerial = 0

    local NAME_WORDS = {
        "gate",
        "door",
        "wall",
        "barrier",
        "barricade",
        "seal",
        "crystal",
        "ice",
        "rock",
        "block",
        "break",
        "destroy",
        "obstacle",
    }

    local HEALTH_KEYS = {
        "Health",
        "HP",
        "Hp",
        "HitPoint",
        "HitPoints",
        "CurrentHP",
        "CurHP",
        "Durability",
    }

    local PROGRESS_KEYS = {
        "HitDamage",
        "DamageTaken",
        "Progress",
        "HitCount",
    }

    local TERMINAL_KEYS = {
        "Broken",
        "Destroyed",
        "Opened",
        "Open",
        "Dead",
    }

    local function emit(name, detail)
        if type(D.event) == "function" then
            pcall(D.event, name, detail)
        end
    end

    local function fullName(obj)
        if type(D.fullName) == "function" then
            return D.fullName(obj)
        end

        if typeof(obj) ~= "Instance" then
            return tostring(obj)
        end

        local ok, value =
            pcall(function()
                return obj:GetFullName()
            end)

        return ok and value or obj.Name
    end

    local function rootPart(obj)
        if not obj or not obj.Parent then
            return nil
        end

        if obj:IsA("BasePart") then
            return obj
        end

        if obj:IsA("Model") then
            return obj.PrimaryPart
                or obj:FindFirstChild("Root")
                or obj:FindFirstChild("HumanoidRootPart")
                or obj:FindFirstChildWhichIsA("BasePart", true)
        end

        return obj:FindFirstChildWhichIsA("BasePart", true)
    end

    local function keywordScore(name)
        local text = string.lower(tostring(name or ""))
        local score = 0
        local hits = {}

        for _, word in ipairs(NAME_WORDS) do
            if string.find(text, word, 1, true) then
                score += 1
                table.insert(hits, word)
            end
        end

        return score, table.concat(hits, ",")
    end

    local function numberAttribute(obj, keys)
        if not obj then
            return nil
        end

        for _, key in ipairs(keys) do
            local value = obj:GetAttribute(key)
            if type(value) == "number" then
                return key, value, "ATTR"
            end
        end

        return nil
    end

    local function numberValue(obj, keys)
        if not obj then
            return nil
        end

        local wanted = {}
        for _, key in ipairs(keys) do
            wanted[string.lower(key)] = true
        end

        local scanned = 0
        for _, child in ipairs(obj:GetDescendants()) do
            scanned += 1
            if scanned > 160 then
                break
            end

            if child:IsA("NumberValue")
                or child:IsA("IntValue")
            then
                if wanted[string.lower(child.Name)] then
                    return child.Name, child.Value, "VALUE", child
                end
            end
        end

        return nil
    end

    local function metric(obj)
        if not obj or not obj.Parent then
            return {
                terminal = true,
                key = "REMOVED",
                value = 0,
                direction = "DOWN",
            }
        end

        for _, key in ipairs(TERMINAL_KEYS) do
            local value = obj:GetAttribute(key)
            if value == true then
                return {
                    terminal = true,
                    key = key,
                    value = true,
                    direction = "BOOL",
                }
            end
        end

        local key, value, source, valueObj =
            numberAttribute(obj, HEALTH_KEYS)

        if not key then
            key, value, source, valueObj =
                numberValue(obj, HEALTH_KEYS)
        end

        if key then
            return {
                terminal = value <= 0,
                key = key,
                value = value,
                source = source,
                valueObj = valueObj,
                direction = "DOWN",
            }
        end

        key, value, source, valueObj =
            numberAttribute(obj, PROGRESS_KEYS)

        if not key then
            key, value, source, valueObj =
                numberValue(obj, PROGRESS_KEYS)
        end

        if key then
            return {
                terminal = false,
                key = key,
                value = value,
                source = source,
                valueObj = valueObj,
                direction = "UP",
            }
        end

        return nil
    end

    local function stateSummary(obj)
        if not obj or not obj.Parent then
            return "removed"
        end

        local rows = {}
        local attrs = obj:GetAttributes()
        local count = 0

        for key, value in pairs(attrs) do
            count += 1
            if count > 20 then
                table.insert(rows, "...")
                break
            end

            table.insert(
                rows,
                tostring(key) .. "=" .. tostring(value)
            )
        end

        table.sort(rows)
        return table.concat(rows, ";")
    end

    local function interactionSummary(obj)
        if not obj or not obj.Parent then
            return "none", 0
        end

        local prompts = 0
        local touches = 0
        local remotes = 0
        local humanoids = 0
        local scanned = 0

        for _, child in ipairs(obj:GetDescendants()) do
            scanned += 1
            if scanned > 220 then
                break
            end

            if child:IsA("ProximityPrompt") then
                prompts += 1
            elseif child:IsA("TouchTransmitter") then
                touches += 1
            elseif child:IsA("RemoteEvent")
                or child:IsA("RemoteFunction")
            then
                remotes += 1
            elseif child:IsA("Humanoid") then
                humanoids += 1
            end
        end

        return string.format(
            "prompt=%d touch=%d remote=%d humanoid=%d",
            prompts,
            touches,
            remotes,
            humanoids
        ), humanoids, prompts, touches, remotes
    end

    local function scan(radius)
        local root = D.getRoot()
        if not root then
            return {}
        end

        radius = tonumber(radius) or 220

        local overlap = OverlapParams.new()
        overlap.FilterType = Enum.RaycastFilterType.Exclude

        local character = D.LocalPlayer
            and D.LocalPlayer.Character

        overlap.FilterDescendantsInstances =
            character and {character} or {}

        local ok, parts =
            pcall(
                workspace.GetPartBoundsInRadius,
                workspace,
                root.Position,
                radius,
                overlap
            )

        if not ok or type(parts) ~= "table" then
            parts = {}
        end

        local seen = {}
        local rows = {}

        local function consider(obj, part)
            if not obj
                or not obj.Parent
                or seen[obj]
            then
                return
            end

            seen[obj] = true

            local p = rootPart(obj) or part
            if not p then
                return
            end

            local dist = (p.Position - root.Position).Magnitude
            if dist > radius then
                return
            end

            local nameScore, words =
                keywordScore(obj.Name)

            local m = metric(obj)
            local interactions,
                humanoids,
                prompts,
                touches,
                remotes =
                    interactionSummary(obj)

            -- Normal enemies are already owned by combat.lua. Do not create
            -- a second enemy controller here.
            if humanoids > 0 then
                return
            end

            local damageableAttr =
                obj:GetAttribute("Damageable") == true
                or obj:GetAttribute("CanDamage") == true
                or obj:GetAttribute("Destructible") == true

            local score =
                nameScore * 18
                + (m and 70 or 0)
                + (damageableAttr and 80 or 0)
                + prompts * 4
                + touches * 3
                + remotes * 6
                - math.min(dist, 220) * 0.03

            if nameScore > 0
                or m
                or damageableAttr
                or prompts > 0
                or touches > 0
                or remotes > 0
            then
                table.insert(rows, {
                    Object = obj,
                    Part = p,
                    Distance = dist,
                    Score = score,
                    NameScore = nameScore,
                    Words = words,
                    Metric = m,
                    Damageable = damageableAttr,
                    Interactions = interactions,
                    Attributes = stateSummary(obj),
                })
            end
        end

        for _, part in ipairs(parts) do
            local current = part
            for _ = 1, 4 do
                if not current or current == workspace then
                    break
                end

                consider(current, part)
                current = current.Parent
            end
        end

        table.sort(rows, function(a, b)
            if math.abs(a.Score - b.Score) > 0.01 then
                return a.Score > b.Score
            end
            return a.Distance < b.Distance
        end)

        return rows
    end

    local function probeText(reason, age, rows)
        local root = D.getRoot()
        local region = D.getCurrentRegion()

        local out = {
            "Version=V61.9",
            "Reason=" .. tostring(reason),
            "PlaceId=" .. tostring(game.PlaceId),
            "GameRound=" .. tostring(D.gameRound()),
            "Age=" .. tostring(age),
            "PlayerPos=" .. tostring(root and root.Position),
            "CurrentRegion=" .. tostring(region and fullName(region)),
            "Candidates=" .. tostring(#rows),
            "",
        }

        for i = 1, math.min(24, #rows) do
            local row = rows[i]
            local m = row.Metric

            table.insert(
                out,
                string.format(
                    "#%d score=%.1f dist=%.1f name=%s path=%s words=%s metric=%s:%s:%s damageable=%s %s attrs={%s}",
                    i,
                    row.Score,
                    row.Distance,
                    tostring(row.Object.Name),
                    fullName(row.Object),
                    tostring(row.Words),
                    tostring(m and m.key),
                    tostring(m and m.value),
                    tostring(m and m.direction),
                    tostring(row.Damageable),
                    tostring(row.Interactions),
                    tostring(row.Attributes)
                )
            )
        end

        return table.concat(out, "\n")
    end

    local function archiveProbe(reason, age, rows)
        ProbeSerial += 1
        local text = probeText(reason, age, rows)

        if type(writefile) == "function" then
            pcall(
                writefile,
                "IronSoul_LastObjectiveProbe_V61_9.txt",
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
                    tostring(D.gameRound())
                ),
                text
            )
        end
    end

    local function validAttackCandidate(row)
        if not row
            or not row.Object
            or not row.Object.Parent
            or not row.Part
            or not row.Part.Parent
        then
            return false
        end

        if row.Distance > 190 then
            return false
        end

        if row.Metric then
            return true
        end

        if row.Damageable then
            return true
        end

        -- Soft fallback for a strongly named progression barrier that also
        -- exposes an interaction/touch/remote mechanism. This is deliberately
        -- stricter than name-only matching so decorative ice walls are ignored.
        if row.NameScore >= 1
            and row.Score >= 24
            and string.find(
                row.Interactions,
                "prompt=0 touch=0 remote=0",
                1,
                true
            ) == nil
        then
            return true
        end

        return false
    end

    local function progressChanged(before, after)
        if not before or not after then
            return false
        end

        if before.key ~= after.key
            or before.direction ~= after.direction
        then
            return false
        end

        if before.direction == "DOWN" then
            return after.value < before.value
        elseif before.direction == "UP" then
            return after.value > before.value
        end

        return false
    end

    local function positionFor(part)
        local root = D.getRoot()
        if not root or not part or not part.Parent then
            return false
        end

        local delta = root.Position - part.Position
        local horizontal = Vector3.new(delta.X, 0, delta.Z)

        if horizontal.Magnitude < 0.1 then
            horizontal = -Vector3.new(
                part.CFrame.LookVector.X,
                0,
                part.CFrame.LookVector.Z
            )
        end

        if horizontal.Magnitude < 0.1 then
            horizontal = Vector3.new(0, 0, 1)
        else
            horizontal = horizontal.Unit
        end

        local goal = part.Position
            + horizontal * 5.0
            + Vector3.new(0, 1.5, 0)

        root.CFrame = CFrame.lookAt(goal, part.Position)

        pcall(function()
            root.AssemblyLinearVelocity = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero
        end)

        return true
    end

    local function attack(row)
        local obj = row.Object
        local part = row.Part
        local startRound = D.gameRound()
        local started = os.clock()
        local lastProgress = started
        local before = metric(obj)
        local sawProgress = false
        local initialCollision = part and part.CanCollide

        emit(
            "OBJECTIVE_ATTACK_START",
            "name=" .. tostring(obj.Name)
                .. " path=" .. fullName(obj)
                .. " dist=" .. string.format("%.1f", row.Distance)
                .. " metric=" .. tostring(before and before.key)
                .. ":" .. tostring(before and before.value)
        )

        while os.clock() - started < 3.6 do
            if D.settlementDetected() then
                return true, "SETTLEMENT"
            end

            local nowRound = D.gameRound()
            if startRound and nowRound and nowRound > startRound then
                return true, "ROUND_ADVANCED"
            end

            if type(D.hasNormalObjective) == "function"
                and D.hasNormalObjective()
            then
                return true, "OBJECTIVE_APPEARED"
            end

            if not obj.Parent
                or not part.Parent
            then
                return true, "OBJECT_REMOVED"
            end

            local nowMetric = metric(obj)
            if nowMetric and nowMetric.terminal then
                return true, "OBJECTIVE_TERMINAL_" .. tostring(nowMetric.key)
            end

            if initialCollision == true
                and part.CanCollide == false
            then
                return true, "COLLISION_OPENED"
            end

            positionFor(part)

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

            if before and nowMetric
                and progressChanged(before, nowMetric)
            then
                sawProgress = true
                lastProgress = os.clock()

                emit(
                    "OBJECTIVE_DAMAGE",
                    tostring(nowMetric.key)
                        .. " " .. tostring(before.value)
                        .. "->" .. tostring(nowMetric.value)
                )

                before = nowMetric
            elseif nowMetric then
                before = nowMetric
            end

            if os.clock() - lastProgress >= 1.65
                and not sawProgress
            then
                break
            end

            task.wait(0.12)
        end

        if sawProgress then
            return false, "DAMAGE_PROGRESS"
        end

        return false, "NO_CONFIRMED_DAMAGE"
    end

    function R:TryResolve(reason, age)
        local now = os.clock()

        if now - LastTry < 0.85 then
            return false, "COOLDOWN"
        end

        LastTry = now

        if type(D.hasNormalObjective) == "function"
            and D.hasNormalObjective()
        then
            return false, "NORMAL_OBJECTIVE_ACTIVE"
        end

        local rows = scan(235)
        archiveProbe(reason, age, rows)

        emit(
            "OBJECTIVE_PROBE",
            "reason=" .. tostring(reason)
                .. " round=" .. tostring(D.gameRound())
                .. " candidates=" .. tostring(#rows)
                .. " best=" .. tostring(rows[1] and rows[1].Object.Name)
                .. " score=" .. tostring(rows[1] and string.format("%.1f", rows[1].Score))
                .. " dist=" .. tostring(rows[1] and string.format("%.1f", rows[1].Distance))
        )

        local candidate = nil
        for _, row in ipairs(rows) do
            if validAttackCandidate(row) then
                candidate = row
                break
            end
        end

        if candidate then
            local ok, result = attack(candidate)

            emit(
                "OBJECTIVE_ATTACK_RESULT",
                tostring(result)
            )

            if ok then
                return true, "OBJECTIVE_" .. tostring(result)
            end

            -- If real HP/progress moved, keep ownership in GATE/empty combat
            -- and retry this objective shortly instead of wandering away.
            if result == "DAMAGE_PROGRESS" then
                return false, result
            end
        end

        -- After a bounded discovery attempt, reuse the existing transition
        -- recovery machinery. This prevents 30-60 second empty stalls when
        -- the new mechanic is actually a touch/portal/checkpoint instead.
        if tonumber(age) and tonumber(age) >= 5.5 then
            local watchdog =
                getgenv().IronSoulTransitionWatchdog

            if watchdog
                and type(watchdog.Recover) == "function"
            then
                local recovered, result =
                    watchdog:Recover(
                        D.getCurrentRegion(),
                        "UNKNOWN_OBJECTIVE_" .. tostring(reason)
                    )

                if recovered then
                    return true, tostring(result)
                end
            end
        end

        return false,
            candidate and "UNRESOLVED_CANDIDATE" or "NO_DAMAGEABLE_OBJECTIVE"
    end

    return R
end
