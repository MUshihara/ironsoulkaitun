--========================================================--
-- IRON SOUL - STAGING-AWARE TRANSITION MODULE V60.4
--
-- Factory module used by systems/combat.lua.
--
-- Keeps portal/gate discovery outside the main combat chunk so Luau does
-- not hit the "Out of local registers" compiler limit.
--========================================================--

return function(D)
    local Resolver = {}

    local Players =
        D.Players

    local LocalPlayer =
        D.LocalPlayer

    local CFG =
        D.CFG

    local effectivelyVisible =
        D.effectivelyVisible

    local portalTeleportEvidence =
        D.portalTeleportEvidence

    local exactRoundDoorPortal =
        D.exactRoundDoorPortal

    local gameRound =
        D.gameRound

    local fullName =
        D.fullName

    local placeCharacter =
        D.placeCharacter

    local important =
        D.important

    local portalLog =
        D.portalLog

    local firetouchinterest =
        D.firetouchinterest

    local fireproximityprompt =
        D.fireproximityprompt

    local function Root()
        return D.getRoot()
    end

    local function CurrentRegion()
        return D.getCurrentRegion()
    end

    local function roomClearedVisible()
        local pg =
            LocalPlayer:
                FindFirstChildOfClass(
                    "PlayerGui"
                )

        if not pg then
            return false
        end

        for _, obj in ipairs(
            pg:GetDescendants()
        ) do
            if (
                obj:IsA("TextLabel")
                or obj:IsA("TextButton")
            )
                and effectivelyVisible(obj)
            then
                local text =
                    string.lower(
                        tostring(
                            obj.Text or ""
                        )
                    )

                if string.find(
                    text,
                    "room cleared",
                    1,
                    true
                )
                then
                    return true
                end
            end
        end

        return false
    end

    function Resolver:RoomClearedVisible()
        return roomClearedVisible()
    end

    local function transitionEvidence(
        beforePos,
        oldRegion,
        wasRoomCleared
    )
        local hit =
            portalTeleportEvidence(
                beforePos,
                oldRegion
            )

        if hit then
            return hit
        end

        if wasRoomCleared
            and not roomClearedVisible()
        then
            return "ROOM_CLEARED_GUI_GONE"
        end
    end

    local function exactPortalMechanism()
        local portalRoot =
            exactRoundDoorPortal()

        if not portalRoot
            or not portalRoot.Parent
        then
            return nil
        end

        local rf =
            portalRoot:
                FindFirstChild(
                    "RF"
                )

        local localPortal =
            portalRoot:
                FindFirstChild(
                    "LocalRoundPortal"
                )

        local serverPortal =
            portalRoot:
                FindFirstChild(
                    "ServerRoundPortal"
                )

        if not rf
            or not rf:IsA(
                "RemoteFunction"
            )
            or not (
                localPortal
                or serverPortal
            )
        then
            return nil
        end

        local roundNum =
            tonumber(
                portalRoot:
                    GetAttribute(
                        "RoundNum"
                    )
            )

        local current =
            gameRound()

        local unlocked =
            not roundNum
            or not current
            or roundNum < current

        if not unlocked then
            return nil
        end

        return {
            Root = portalRoot,
            RF = rf,
            Score = 1000,
            Name =
                fullName(
                    portalRoot.Parent
                ),
        }
    end

    function Resolver:TryFastExactPortal()
        -- Disabled in V60.3.
        --
        -- V60.1 proved that the RF is real, but also proved that invoking a
        -- replicated section portal remotely can skip intermediate rooms.
        -- Exact RoundDoor.Portal progression is now handled only by
        -- combat.lua's physical near-portal handshake.
        return false,
            "DIRECT_ROUND_PORTAL_RF_DISABLED"
    end


    local function objectPosition(obj)
        if not obj then
            return nil
        end

        if obj:IsA("BasePart") then
            return obj.Position
        end

        if obj:IsA("Attachment") then
            return obj.WorldPosition
        end

        if obj:IsA("Model") then
            local ok, pivot =
                pcall(
                    obj.GetPivot,
                    obj
                )

            if ok then
                return pivot.Position
            end
        end

        local part =
            obj:
                FindFirstChildWhichIsA(
                    "BasePart",
                    true
                )

        return part
            and part.Position
    end

    local function candidatePart(obj)
        if not obj then
            return nil
        end

        if obj:IsA("BasePart") then
            return obj
        end

        if obj:IsA("Model") then
            local root =
                obj:
                    FindFirstChild(
                        "Root",
                        true
                    )

            if root
                and root:IsA(
                    "BasePart"
                )
            then
                return root
            end

            return obj.PrimaryPart
                or obj:
                    FindFirstChildWhichIsA(
                        "BasePart",
                        true
                    )
        end

        return obj:
            FindFirstChildWhichIsA(
                "BasePart",
                true
            )
    end

    local function mechanism(obj)
        return {
            Prompt =
                obj:
                    FindFirstChildWhichIsA(
                        "ProximityPrompt",
                        true
                    ),

            Touch =
                obj:
                    FindFirstChildWhichIsA(
                        "TouchTransmitter",
                        true
                    ),

            RF =
                obj:
                    FindFirstChildWhichIsA(
                        "RemoteFunction",
                        true
                    ),

            RE =
                obj:
                    FindFirstChildWhichIsA(
                        "RemoteEvent",
                        true
                    ),

            LocalPortal =
                obj:
                    FindFirstChild(
                        "LocalRoundPortal",
                        true
                    ),

            ServerPortal =
                obj:
                    FindFirstChild(
                        "ServerRoundPortal",
                        true
                    ),
        }
    end

    local function candidateRows()
        local root =
            Root()

        if not root then
            return {}
        end

        local good = {
            portal = 180,
            teleport = 165,
            exit = 145,
            transition = 140,
            next = 120,
            gate = 105,
            door = 55,
        }

        local bad = {
            torch = 190,
            walltorch = 260,
            spawn = 200,
            reset = 230,
            kill = 260,
            damage = 180,
            lava = 220,
            hazard = 180,
            decoration = 120,
            decor = 120,
        }

        local rows = {}
        local seen = {}

        local function scoreName(text)
            local low =
                string.lower(
                    tostring(text or "")
                )

            local score = 0

            for word, value
                in pairs(good)
            do
                if string.find(
                    low,
                    word,
                    1,
                    true
                )
                then
                    score += value
                end
            end

            for word, value
                in pairs(bad)
            do
                if string.find(
                    low,
                    word,
                    1,
                    true
                )
                then
                    score -= value
                end
            end

            return score
        end

        local function consider(obj)
            if not obj
                or seen[obj]
            then
                return
            end

            seen[obj] = true

            local pos =
                objectPosition(obj)

            if not pos then
                return
            end

            local distance =
                (
                    pos
                    - root.Position
                ).Magnitude

            if distance
                > CFG.ADAPTIVE_MAX_DISTANCE
            then
                return
            end

            local path =
                fullName(obj)

            -- Never use generic Workspace.Portal: older validation proved
            -- that it can be a large safety/reset volume.
            --
            -- Also do NOT use RoundDoor.Portal here. That portal is handled
            -- only by combat.lua's physical near-portal handshake so a
            -- replicated future section portal cannot skip rooms.
            if path == "Workspace.Portal"
                or string.sub(
                    path,
                    1,
                    #"Workspace.Portal."
                ) == "Workspace.Portal."
                or path == "Workspace.RoundDoor.Portal"
                or string.sub(
                    path,
                    1,
                    #"Workspace.RoundDoor.Portal."
                ) == "Workspace.RoundDoor.Portal."
            then
                return
            end

            local mech =
                mechanism(obj)

            local score =
                scoreName(
                    obj.Name
                    .. " "
                    .. path
                )

            if mech.Prompt then
                score += 65
            end

            if mech.Touch then
                score += 55
            end

            if mech.RF then
                score += 60
            end

            if mech.LocalPortal
                or mech.ServerPortal
            then
                score += 150
            end

            score +=
                math.max(
                    0,
                    75
                        - distance * 0.20
                )

            local part =
                candidatePart(obj)

            if part
                and part:IsA(
                    "BasePart"
                )
            then
                local maxDim =
                    math.max(
                        part.Size.X,
                        part.Size.Y,
                        part.Size.Z
                    )

                if maxDim > 120 then
                    score -= 220
                end
            end

            if score >= 170
                and (
                    mech.RF
                    or mech.Prompt
                    or mech.Touch
                )
            then
                table.insert(
                    rows,
                    {
                        Object = obj,
                        Position = pos,
                        Distance = distance,
                        Score = score,
                        Mechanism = mech,
                        Part = part,
                    }
                )
            end
        end

        for _, obj in ipairs(
            workspace:GetDescendants()
        ) do
            if obj:IsA("Model")
                or obj:IsA("Folder")
                or obj:IsA("BasePart")
            then
                local low =
                    string.lower(
                        obj.Name
                    )

                local interesting =
                    false

                for word in pairs(good) do
                    if string.find(
                        low,
                        word,
                        1,
                        true
                    )
                    then
                        interesting =
                            true
                        break
                    end
                end

                if interesting then
                    consider(obj)
                end
            end
        end

        table.sort(
            rows,
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

        return rows
    end

    function Resolver:Snapshot(limit)
        local rows =
            candidateRows()

        limit =
            tonumber(limit)
            or 8

        local out = {}

        for i = 1,
            math.min(
                limit,
                #rows
            )
        do
            local row =
                rows[i]

            local mech =
                row.Mechanism

            table.insert(
                out,
                "#"
                    .. tostring(i)
                    .. " score="
                    .. string.format(
                        "%.1f",
                        row.Score
                    )
                    .. " dist="
                    .. string.format(
                        "%.1f",
                        row.Distance
                    )
                    .. " path="
                    .. fullName(
                        row.Object
                    )
                    .. " prompt="
                    .. tostring(
                        mech.Prompt ~= nil
                    )
                    .. " touch="
                    .. tostring(
                        mech.Touch ~= nil
                    )
                    .. " rf="
                    .. tostring(
                        mech.RF ~= nil
                    )
                    .. " re="
                    .. tostring(
                        mech.RE ~= nil
                    )
            )
        end

        if #out == 0 then
            return "none"
        end

        return table.concat(
            out,
            "\n"
        )
    end

    local function promptPosition(
        prompt
    )
        if not prompt
            or not prompt.Parent
        then
            return nil
        end

        local parent =
            prompt.Parent

        if parent:IsA(
            "Attachment"
        ) then
            return parent.WorldPosition
        end

        if parent:IsA(
            "BasePart"
        ) then
            return parent.Position
        end

        return objectPosition(
            parent
        )
    end

    function Resolver:TryAdaptive()
        local root =
            Root()

        if not root then
            return false,
                "NO_ROOT"
        end

        local rows =
            candidateRows()

        portalLog(
            "ADAPTIVE_LOCAL candidates="
                .. tostring(
                    #rows
                )
        )

        local oldRegion =
            CurrentRegion()

        local wasCleared =
            roomClearedVisible()

        for i = 1,
            math.min(
                6,
                #rows
            )
        do
            local row =
                rows[i]

            local mech =
                row.Mechanism

            local beforePos =
                root.Position

            portalLog(
                "ADAPTIVE_TRY #"
                    .. tostring(i)
                    .. " score="
                    .. string.format(
                        "%.1f",
                        row.Score
                    )
                    .. " dist="
                    .. string.format(
                        "%.1f",
                        row.Distance
                    )
                    .. " path="
                    .. fullName(
                        row.Object
                    )
            )

            if mech.RF
                and row.Distance <= 35
                and (
                    mech.LocalPortal
                    or mech.ServerPortal
                )
            then
                pcall(function()
                    mech.RF:
                        InvokeServer()
                end)

                local deadline =
                    os.clock() + 1.25

                while os.clock()
                    < deadline
                do
                    local evidence =
                        transitionEvidence(
                            beforePos,
                            oldRegion,
                            wasCleared
                        )

                    if evidence then
                        important(
                            "Phase | adaptive portal"
                        )

                        return true,
                            evidence
                    end

                    task.wait(0.08)
                end
            end

            if mech.Prompt
                and mech.Prompt.Enabled
                and type(
                    fireproximityprompt
                ) == "function"
            then
                local pos =
                    promptPosition(
                        mech.Prompt
                    )

                if pos then
                    local dir =
                        root.Position
                        - pos

                    if dir.Magnitude
                        < 0.1
                    then
                        dir =
                            root.CFrame.LookVector
                    else
                        dir =
                            dir.Unit
                    end

                    placeCharacter(
                        pos
                            + dir * 2.2,
                        -dir
                    )

                    task.wait(0.10)
                end

                pcall(
                    fireproximityprompt,
                    mech.Prompt,
                    0
                )

                local deadline =
                    os.clock() + 1.50

                while os.clock()
                    < deadline
                do
                    local evidence =
                        transitionEvidence(
                            beforePos,
                            oldRegion,
                            wasCleared
                        )

                    if evidence then
                        important(
                            "Phase | adaptive gate"
                        )

                        return true,
                            evidence
                    end

                    task.wait(0.08)
                end
            end

            local part =
                row.Part

            if part
                and part:IsA(
                    "BasePart"
                )
                and (
                    mech.Touch
                    or string.find(
                        string.lower(
                            fullName(
                                row.Object
                            )
                        ),
                        "portal",
                        1,
                        true
                    )
                    or string.find(
                        string.lower(
                            fullName(
                                row.Object
                            )
                        ),
                        "exit",
                        1,
                        true
                    )
                )
            then
                local maxDim =
                    math.max(
                        part.Size.X,
                        part.Size.Y,
                        part.Size.Z
                    )

                if maxDim <= 120 then
                    local center =
                        part.Position

                    local axis =
                        part.Size.X
                            < part.Size.Z
                        and part.CFrame.RightVector
                        or part.CFrame.LookVector

                    axis =
                        Vector3.new(
                            axis.X,
                            0,
                            axis.Z
                        )

                    if axis.Magnitude
                        < 0.1
                    then
                        axis =
                            root.CFrame.LookVector
                    else
                        axis =
                            axis.Unit
                    end

                    for _, offset
                        in ipairs({
                            -4,
                            -1,
                            0,
                            1,
                            4,
                        })
                    do
                        local p =
                            center
                            + axis * offset

                        placeCharacter(
                            Vector3.new(
                                p.X,
                                center.Y,
                                p.Z
                            ),
                            axis
                        )

                        if mech.Touch
                            and type(
                                firetouchinterest
                            ) == "function"
                        then
                            pcall(
                                firetouchinterest,
                                root,
                                part,
                                0
                            )

                            task.wait(0.035)

                            pcall(
                                firetouchinterest,
                                root,
                                part,
                                1
                            )
                        end

                        task.wait(0.12)

                        local evidence =
                            transitionEvidence(
                                beforePos,
                                oldRegion,
                                wasCleared
                            )

                        if evidence then
                            important(
                                "Phase | adaptive touch"
                            )

                            return true,
                                evidence
                        end
                    end
                end
            end
        end

        return false,
            "NO_ADAPTIVE_TRANSITION"
    end

    return Resolver
end
