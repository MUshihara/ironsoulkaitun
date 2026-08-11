--========================================================--
-- IRON SOUL - SELF-HEALING TRANSITION WATCHDOG V61.5
--
-- Purpose:
--   Recover empty post-gate states without hardcoding D3/D4 coordinates.
--
-- Strategy:
--   1) Find ALL exact current-1 RoundDoor portals, not only the first
--      Workspace.RoundDoor.Portal returned by FindFirstChild.
--   2) Reuse a previously learned successful transition hint.
--   3) Probe around ONE fixed anchor. Every failed probe returns to that
--      exact anchor, so there is no cumulative wandering.
--
-- Persistent learning:
--   IronSoul_TransitionLearn_V61_5.json
--
-- Compact latest diagnostic:
--   IronSoul_LastTransitionWatchdog_V61_5.txt
--========================================================--

return function(D)
    local W = {}

    local Players =
        game:GetService(
            "Players"
        )

    local HttpService =
        game:GetService(
            "HttpService"
        )

    local TeleportService =
        game:GetService(
            "TeleportService"
        )

    local RunService =
        game:GetService(
            "RunService"
        )

    local LocalPlayer =
        D.LocalPlayer

    local LEARN_FILE =
        "IronSoul_TransitionLearn_V61_5.json"

    local SNAPSHOT_FILE =
        "IronSoul_LastTransitionWatchdog_V61_5.txt"

    local LastAttempt =
        -math.huge

    local Learn = {}

    local function emit(
        name,
        detail
    )
        if type(D.event)
            == "function"
        then
            pcall(
                D.event,
                name,
                detail
            )
        end
    end

    local function root()
        local ok, value =
            pcall(
                D.getRoot
            )

        return ok
            and value
            or nil
    end

    local function currentRegion()
        local ok, value =
            pcall(
                D.getCurrentRegion
            )

        return ok
            and value
            or nil
    end

    local function hasObjective()
        if type(D.hasCombatObjective)
            ~= "function"
        then
            return false
        end

        local ok, value =
            pcall(
                D.hasCombatObjective
            )

        return ok
            and value == true
    end

    local function settled()
        if type(D.settlementDetected)
            ~= "function"
        then
            return false
        end

        local ok, value =
            pcall(
                D.settlementDetected
            )

        return ok
            and value == true
    end

    local function loadLearn()
        if type(readfile)
                ~= "function"
            or (
                type(isfile)
                    == "function"
                and not isfile(
                    LEARN_FILE
                )
            )
        then
            return
        end

        local ok, text =
            pcall(
                readfile,
                LEARN_FILE
            )

        if not ok
            or type(text)
                ~= "string"
        then
            return
        end

        local decodedOk,
            decoded =
                pcall(
                    HttpService.JSONDecode,
                    HttpService,
                    text
                )

        if decodedOk
            and type(decoded)
                == "table"
        then
            Learn =
                decoded
        end
    end

    local function saveLearn()
        if type(writefile)
            ~= "function"
        then
            return
        end

        local ok, text =
            pcall(
                HttpService.JSONEncode,
                HttpService,
                Learn
            )

        if ok then
            pcall(
                writefile,
                LEARN_FILE,
                text
            )
        end
    end

    loadLearn()

    local function diffLevel()
        local data = nil

        pcall(function()
            data =
                TeleportService:
                    GetLocalPlayerTeleportData()
        end)

        if type(data)
            == "table"
        then
            return data.DiffLevel
                or data.Diff
                or "?"
        end

        return "?"
    end

    local function routeKey(
        round
    )
        return tostring(
            game.PlaceId
        )
            .. "|D"
            .. tostring(
                diffLevel()
            )
            .. "|R"
            .. tostring(
                round
            )
    end

    local function v3Table(v)
        return {
            x = v.X,
            y = v.Y,
            z = v.Z,
        }
    end

    local function tableV3(t)
        if type(t)
            ~= "table"
        then
            return nil
        end

        local x =
            tonumber(t.x)

        local y =
            tonumber(t.y)

        local z =
            tonumber(t.z)

        if not x
            or not y
            or not z
        then
            return nil
        end

        return Vector3.new(
            x,
            y,
            z
        )
    end

    local function learnSuccess(
        kind,
        round,
        sourcePos,
        targetPos,
        result
    )
        local key =
            routeKey(round)

        local old =
            Learn[key]

        Learn[key] = {
            kind = kind,
            source =
                v3Table(sourcePos),
            target =
                v3Table(targetPos),
            success =
                (
                    type(old)
                        == "table"
                    and tonumber(
                        old.success
                    )
                    or 0
                ) + 1,
            result =
                tostring(result),
            updated =
                os.time(),
        }

        saveLearn()

        emit(
            "WATCHDOG_LEARN",
            "key="
                .. key
                .. " kind="
                .. tostring(kind)
                .. " result="
                .. tostring(result)
        )
    end

    local function transitionEvidence(
        beforePos,
        beforeRegion,
        beforeRound
    )
        if settled() then
            return "SETTLEMENT"
        end

        if hasObjective() then
            return "OBJECTIVE_APPEARED"
        end

        local r =
            root()

        if not r
            or not r.Parent
        then
            return "CHARACTER_CHANGED"
        end

        local nowRound =
            D.gameRound()

        if beforeRound
            and nowRound
            and nowRound
                ~= beforeRound
        then
            return "GAME_ROUND_CHANGED"
        end

        if (
            r.Position
            - beforePos
        ).Magnitude > 100
        then
            return "PORTAL_MOVED"
        end

        local region,
            dist =
                D.nearestWakeRegion(
                    r.Position
                )

        if region
            and region
                ~= beforeRegion
            and dist <= 28
        then
            return "NEW_REGION"
        end
    end

    local function portalRows()
        local r =
            root()

        local current =
            D.gameRound()

        local folder =
            workspace:
                FindFirstChild(
                    "RoundDoor"
                )

        local rows = {}

        if not r
            or not current
            or not folder
        then
            return rows
        end

        for _, part in ipairs(
            folder:GetDescendants()
        ) do
            if part:IsA(
                "BasePart"
            )
                and part.Name
                    == "Root"
                and part.Parent
                and part.Parent.Name
                    == "Portal"
            then
                local roundNum =
                    tonumber(
                        part:
                            GetAttribute(
                                "RoundNum"
                            )
                    )

                local rf =
                    part:
                        FindFirstChild(
                            "RF"
                        )

                local localPortal =
                    part:
                        FindFirstChild(
                            "LocalRoundPortal"
                        )

                local serverPortal =
                    part:
                        FindFirstChild(
                            "ServerRoundPortal"
                        )

                if roundNum
                        == current - 1
                    and (
                        rf
                        or localPortal
                        or serverPortal
                        or part:
                            FindFirstChildWhichIsA(
                                "TouchTransmitter"
                            )
                    )
                then
                    table.insert(
                        rows,
                        {
                            Root = part,
                            RoundNum =
                                roundNum,
                            Distance =
                                (
                                    part.Position
                                    - r.Position
                                ).Magnitude,
                            RF = rf,
                            LocalPortal =
                                localPortal,
                            ServerPortal =
                                serverPortal,
                        }
                    )
                end
            end
        end

        table.sort(
            rows,
            function(a,b)
                return a.Distance
                    < b.Distance
            end
        )

        return rows
    end

    local function futureDoorRows()
        local r =
            root()

        local current =
            D.gameRound()

        local folder =
            workspace:
                FindFirstChild(
                    "RoundDoor"
                )

        local rows = {}

        if not r
            or not current
            or not folder
        then
            return rows
        end

        for _, part in ipairs(
            folder:GetDescendants()
        ) do
            if part:IsA(
                "BasePart"
            )
                and part.Name == "Root"
                and part.Parent
                and part.Parent.Name == "Door"
            then
                local roundNum =
                    tonumber(
                        part:
                            GetAttribute(
                                "RoundNum"
                            )
                    )

                if roundNum
                    and roundNum >= current
                then
                    table.insert(
                        rows,
                        {
                            Root = part,
                            RoundNum =
                                roundNum,
                            Distance =
                                (
                                    part.Position
                                    - r.Position
                                ).Magnitude,
                        }
                    )
                end
            end
        end

        table.sort(
            rows,
            function(a,b)
                if a.RoundNum
                    ~= b.RoundNum
                then
                    return a.RoundNum
                        < b.RoundNum
                end

                return a.Distance
                    < b.Distance
            end
        )

        return rows
    end

    local function touchRows()
        local r =
            root()

        local out = {}

        if not r then
            return out
        end

        for _, obj in ipairs(
            workspace:GetDescendants()
        ) do
            if obj:IsA(
                "TouchTransmitter"
            )
                and obj.Parent
                and obj.Parent:IsA(
                    "BasePart"
                )
            then
                local part =
                    obj.Parent

                local dist =
                    (
                        part.Position
                        - r.Position
                    ).Magnitude

                if dist <= 120 then
                    local path =
                        D.fullName(part)

                    local low =
                        string.lower(
                            path
                        )

                    local score = 0

                    for _, word in ipairs({
                        "portal",
                        "round",
                        "wake",
                        "teleport",
                        "gate",
                        "door",
                        "trigger",
                    }) do
                        if string.find(
                            low,
                            word,
                            1,
                            true
                        )
                        then
                            score += 1
                        end
                    end

                    table.insert(
                        out,
                        {
                            Part = part,
                            Distance =
                                dist,
                            Score =
                                score,
                            Path =
                                path,
                        }
                    )
                end
            end
        end

        table.sort(
            out,
            function(a,b)
                if a.Score
                    ~= b.Score
                then
                    return a.Score
                        > b.Score
                end

                return a.Distance
                    < b.Distance
            end
        )

        return out
    end

    local function writeSnapshot(
        label,
        portals,
        futureDoors,
        touches
    )
        if type(writefile)
            ~= "function"
        then
            return
        end

        local r =
            root()

        local lines = {
            "Version=V61.5",
            "Label="
                .. tostring(label),
            "Diff="
                .. tostring(
                    diffLevel()
                ),
            "GameRound="
                .. tostring(
                    D.gameRound()
                ),
            "PlayerPos="
                .. tostring(
                    r
                    and r.Position
                ),
            "CurrentRegion="
                .. tostring(
                    currentRegion()
                    and D.fullName(
                        currentRegion()
                    )
                ),
            "",
            "ACTIVE_PORTALS:",
        }

        if #portals == 0 then
            table.insert(
                lines,
                "none"
            )
        else
            for i = 1,
                math.min(
                    8,
                    #portals
                )
            do
                local row =
                    portals[i]

                table.insert(
                    lines,
                    "#"
                        .. tostring(i)
                        .. " Round="
                        .. tostring(
                            row.RoundNum
                        )
                        .. " dist="
                        .. string.format(
                            "%.1f",
                            row.Distance
                        )
                        .. " pos="
                        .. tostring(
                            row.Root.Position
                        )
                        .. " path="
                        .. D.fullName(
                            row.Root
                        )
                )
            end
        end

        table.insert(
            lines,
            ""
        )

        table.insert(
            lines,
            "FUTURE_DOORS:"
        )

        for i = 1,
            math.min(
                8,
                #futureDoors
            )
        do
            local row =
                futureDoors[i]

            table.insert(
                lines,
                "#"
                    .. tostring(i)
                    .. " Round="
                    .. tostring(
                        row.RoundNum
                    )
                    .. " dist="
                    .. string.format(
                        "%.1f",
                        row.Distance
                    )
                    .. " pos="
                    .. tostring(
                        row.Root.Position
                    )
            )
        end

        table.insert(
            lines,
            ""
        )

        table.insert(
            lines,
            "NEAR_TOUCHES:"
        )

        for i = 1,
            math.min(
                12,
                #touches
            )
        do
            local row =
                touches[i]

            table.insert(
                lines,
                "#"
                    .. tostring(i)
                    .. " score="
                    .. tostring(
                        row.Score
                    )
                    .. " dist="
                    .. string.format(
                        "%.1f",
                        row.Distance
                    )
                    .. " "
                    .. row.Path
            )
        end

        pcall(
            writefile,
            SNAPSHOT_FILE,
            table.concat(
                lines,
                "\n"
            )
        )
    end

    local function nativeWalk(
        targetPos,
        beforePos,
        beforeRegion,
        beforeRound,
        timeout
    )
        local r =
            root()

        local character =
            LocalPlayer.Character

        local humanoid =
            character
            and character:
                FindFirstChildOfClass(
                    "Humanoid"
                )

        if not r
            or not humanoid
            or humanoid.Health <= 0
        then
            return false,
                "NO_HUMANOID"
        end

        local deadline =
            os.clock()
            + (
                timeout
                or 1.2
            )

        while os.clock()
            < deadline
        do
            pcall(
                humanoid.MoveTo,
                humanoid,
                targetPos
            )

            task.wait(0.10)

            local evidence =
                transitionEvidence(
                    beforePos,
                    beforeRegion,
                    beforeRound
                )

            if evidence then
                humanoid:
                    Move(
                        Vector3.zero,
                        false
                    )

                return true,
                    evidence
            end
        end

        humanoid:
            Move(
                Vector3.zero,
                false
            )

        return false,
            "NO_TRANSITION"
    end

    local function tryPortal(row)
        local r =
            root()

        if not r
            or hasObjective()
        then
            return false
        end

        local beforeRound =
            D.gameRound()

        local oldRegion =
            currentRegion()

        local fromPortal =
            r.Position
            - row.Root.Position

        fromPortal =
            Vector3.new(
                fromPortal.X,
                0,
                fromPortal.Z
            )

        if fromPortal.Magnitude < 0.1 then
            fromPortal =
                -Vector3.new(
                    row.Root.CFrame.LookVector.X,
                    0,
                    row.Root.CFrame.LookVector.Z
                )
        end

        if fromPortal.Magnitude < 0.1 then
            fromPortal =
                Vector3.new(
                    0,
                    0,
                    1
                )
        else
            fromPortal =
                fromPortal.Unit
        end

        local pre =
            Vector3.new(
                row.Root.Position.X
                    + fromPortal.X * 9,
                row.Root.Position.Y + 2,
                row.Root.Position.Z
                    + fromPortal.Z * 9
            )

        emit(
            "WATCHDOG_PORTAL",
            "round="
                .. tostring(
                    row.RoundNum
                )
                .. " dist="
                .. string.format(
                    "%.1f",
                    row.Distance
                )
                .. " pos="
                .. tostring(
                    row.Root.Position
                )
        )

        r.CFrame =
            CFrame.lookAt(
                pre,
                row.Root.Position
            )

        pcall(function()
            r.AssemblyLinearVelocity =
                Vector3.zero

            r.AssemblyAngularVelocity =
                Vector3.zero
        end)

        task.wait(0.10)

        local verifyFrom =
            r.Position

        local target =
            row.Root.Position
            - fromPortal * 12

        local ok,
            result =
                nativeWalk(
                    target,
                    verifyFrom,
                    oldRegion,
                    beforeRound,
                    1.6
                )

        if not ok
            and type(D.firetouchinterest)
                == "function"
        then
            pcall(
                D.firetouchinterest,
                r,
                row.Root,
                0
            )

            task.wait(0.04)

            pcall(
                D.firetouchinterest,
                r,
                row.Root,
                1
            )

            task.wait(0.15)

            result =
                transitionEvidence(
                    verifyFrom,
                    oldRegion,
                    beforeRound
                )

            ok =
                result ~= nil
        end

        if ok then
            learnSuccess(
                "PORTAL",
                beforeRound,
                verifyFrom,
                row.Root.Position,
                result
            )

            emit(
                "WATCHDOG_PORTAL_SUCCESS",
                tostring(result)
            )

            return true,
                "WATCHDOG_PORTAL_"
                    .. tostring(
                        result
                    )
        end

        emit(
            "WATCHDOG_PORTAL_FAIL",
            "round="
                .. tostring(
                    row.RoundNum
                )
        )

        return false,
            "PORTAL_NO_TRIGGER"
    end

    local function tryLearned()
        local r =
            root()

        local round =
            D.gameRound()

        if not r
            or not round
            or hasObjective()
        then
            return false
        end

        local key =
            routeKey(round)

        local learned =
            Learn[key]

        if type(learned)
            ~= "table"
        then
            return false
        end

        local source =
            tableV3(
                learned.source
            )

        local target =
            tableV3(
                learned.target
            )

        if not source
            or not target
        then
            return false
        end

        local sourceDist =
            (
                r.Position
                - source
            ).Magnitude

        if sourceDist > 120 then
            return false
        end

        emit(
            "WATCHDOG_LEARNED_TRY",
            "key="
                .. key
                .. " success="
                .. tostring(
                    learned.success
                )
                .. " sourceDist="
                .. string.format(
                    "%.1f",
                    sourceDist
                )
                .. " target="
                .. tostring(
                    target
                )
        )

        local before =
            r.Position

        local oldRegion =
            currentRegion()

        local ok,
            result =
                nativeWalk(
                    target,
                    before,
                    oldRegion,
                    round,
                    2.0
                )

        if ok then
            learnSuccess(
                learned.kind
                    or "LEARNED",
                round,
                before,
                target,
                result
            )

            emit(
                "WATCHDOG_LEARNED_SUCCESS",
                tostring(result)
            )

            return true,
                "WATCHDOG_LEARNED_"
                    .. tostring(
                        result
                    )
        end

        return false
    end

    local function probeDirections(
        futureDoors
    )
        local r =
            root()

        if not r then
            return {}
        end

        local out = {}

        local function add(v)
            v =
                Vector3.new(
                    v.X,
                    0,
                    v.Z
                )

            if v.Magnitude < 0.1 then
                return
            end

            v =
                v.Unit

            for _, old in ipairs(
                out
            ) do
                if old:
                    Dot(v) > 0.97
                then
                    return
                end
            end

            table.insert(
                out,
                v
            )
        end

        -- Best directional hint: where the next RoundNum door exists.
        if futureDoors[1] then
            add(
                futureDoors[1].Root.Position
                - r.Position
            )
        end

        local look =
            r.CFrame.LookVector

        local right =
            r.CFrame.RightVector

        add(look)
        add(right)
        add(-right)
        add(-look)
        add(look + right)
        add(look - right)
        add(-look + right)
        add(-look - right)

        return out
    end

    local function tryProbe(
        futureDoors
    )
        local r =
            root()

        local character =
            LocalPlayer.Character

        local humanoid =
            character
            and character:
                FindFirstChildOfClass(
                    "Humanoid"
                )

        local round =
            D.gameRound()

        if not r
            or not humanoid
            or not round
            or hasObjective()
        then
            return false
        end

        local anchorCF =
            r.CFrame

        local anchor =
            anchorCF.Position

        local oldRegion =
            currentRegion()

        local directions =
            probeDirections(
                futureDoors
            )

        local radii = {
            5,
            11,
            20,
            32,
        }

        emit(
            "WATCHDOG_PROBE_START",
            "round="
                .. tostring(round)
                .. " anchor="
                .. tostring(anchor)
                .. " dirs="
                .. tostring(
                    #directions
                )
        )

        for _, radius in ipairs(
            radii
        ) do
            for index, dir in ipairs(
                directions
            ) do
                if hasObjective() then
                    return true,
                        "OBJECTIVE_APPEARED"
                end

                -- Every probe starts from the SAME anchor.
                r.CFrame =
                    anchorCF

                pcall(function()
                    r.AssemblyLinearVelocity =
                        Vector3.zero
                end)

                task.wait(0.04)

                local before =
                    r.Position

                local target =
                    anchor
                    + dir * radius

                local ok,
                    result =
                        nativeWalk(
                            target,
                            before,
                            oldRegion,
                            round,
                            0.45
                        )

                if ok then
                    learnSuccess(
                        "PROBE",
                        round,
                        anchor,
                        target,
                        result
                    )

                    emit(
                        "WATCHDOG_PROBE_SUCCESS",
                        "radius="
                            .. tostring(radius)
                            .. " dir="
                            .. tostring(index)
                            .. " result="
                            .. tostring(result)
                    )

                    return true,
                        "WATCHDOG_PROBE_"
                            .. tostring(
                                result
                            )
                end
            end
        end

        -- Critical stability guarantee: failed probing ends exactly where it
        -- started. No cumulative walking across the map.
        r.CFrame =
            anchorCF

        pcall(function()
            r.AssemblyLinearVelocity =
                Vector3.zero
        end)

        emit(
            "WATCHDOG_PROBE_FAIL",
            "round="
                .. tostring(round)
                .. " returned="
                .. tostring(
                    r.Position
                )
        )

        return false,
            "PROBE_EXHAUSTED"
    end

    function W:Recover(
        oldRegion,
        reason
    )
        local now =
            os.clock()

        if now
            - LastAttempt
            < (
                tonumber(
                    D.CFG.TRANSITION_WATCHDOG_COOLDOWN
                )
                or 3.5
            )
        then
            return false,
                "COOLDOWN"
        end

        LastAttempt =
            now

        if hasObjective() then
            return false,
                "OBJECTIVE_ACTIVE"
        end

        local r =
            root()

        if not r then
            return false,
                "NO_ROOT"
        end

        local portals =
            portalRows()

        local futureDoors =
            futureDoorRows()

        local touches =
            touchRows()

        writeSnapshot(
            reason,
            portals,
            futureDoors,
            touches
        )

        emit(
            "WATCHDOG_START",
            "reason="
                .. tostring(reason)
                .. " round="
                .. tostring(
                    D.gameRound()
                )
                .. " portals="
                .. tostring(
                    #portals
                )
                .. " futureDoors="
                .. tostring(
                    #futureDoors
                )
                .. " touches="
                .. tostring(
                    #touches
                )
        )

        -- Exact current-1 portal is highest confidence.
        for i = 1,
            math.min(
                3,
                #portals
            )
        do
            local ok,
                result =
                    tryPortal(
                        portals[i]
                    )

            if ok then
                return true,
                    result
            end
        end

        -- Reuse a previously successful local checkpoint route.
        local learnedOk,
            learnedResult =
                tryLearned()

        if learnedOk then
            return true,
                learnedResult
        end

        -- Final self-healing fallback: bounded, non-drifting movement probes.
        local probeOk,
            probeResult =
                tryProbe(
                    futureDoors
                )

        if probeOk then
            return true,
                probeResult
        end

        emit(
            "WATCHDOG_EXHAUSTED",
            "round="
                .. tostring(
                    D.gameRound()
                )
                .. " pos="
                .. tostring(
                    r.Position
                )
        )

        return false,
            "WATCHDOG_EXHAUSTED"
    end

    return W
end
