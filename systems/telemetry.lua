--========================================================--
-- IRON SOUL - NATIVE-MOTION TELEMETRY V61.1
--========================================================--

return function(D)
    local T = {}

    local TeleportService =
        game:GetService(
            "TeleportService"
        )

    local rows = {}
    local lastProgress = os.clock()
    local lastFingerprint = ""
    local lastFull = 0
    local lastStall = 0
    local lastGlobalCount = 0
    local started = false

    local TRACE_FILE =
        "IronSoul_Telemetry_V61_1.txt"

    local STATE_FILE =
        "IronSoul_LastState_V61_1.txt"

    local function sv(v)
        if v == nil then
            return "nil"
        end

        return tostring(v)
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

    local function state()
        local ok, value =
            pcall(
                D.getState
            )

        if ok
            and type(value)
                == "table"
        then
            return value
        end

        return {}
    end

    local function append(text)
        table.insert(
            rows,
            string.format(
                "[%.2f] %s",
                os.clock(),
                tostring(text)
            )
        )

        while #rows > 120 do
            table.remove(
                rows,
                1
            )
        end

        if type(writefile)
            == "function"
        then
            pcall(
                writefile,
                TRACE_FILE,
                table.concat(
                    rows,
                    "\n"
                )
            )
        end
    end

    local function counts()
        local localCount = 0
        local globalCount = 0

        local ok1, list1 =
            pcall(
                D.localLiveEnemies
            )

        if ok1
            and type(list1)
                == "table"
        then
            localCount =
                #list1
        end

        local ok2, list2 =
            pcall(
                D.liveEnemies
            )

        if ok2
            and type(list2)
                == "table"
        then
            globalCount =
                #list2
        end

        return localCount,
            globalCount
    end

    local function nearestEnemies(limit)
        local r =
            root()

        local rows2 = {}

        if not r then
            return rows2
        end

        local ok, list =
            pcall(
                D.liveEnemies
            )

        if not ok
            or type(list)
                ~= "table"
        then
            return rows2
        end

        for _, enemy in ipairs(list) do
            local eroot =
                D.modelRoot(
                    enemy
                )

            if eroot then
                table.insert(
                    rows2,
                    {
                        Enemy = enemy,
                        Root = eroot,
                        Distance =
                            (
                                eroot.Position
                                - r.Position
                            ).Magnitude,
                        HP =
                            D.enemyHealth(
                                enemy
                            ),

                        Region =
                            select(
                                1,
                                D.nearestWakeRegion(
                                    eroot.Position
                                )
                            ),

                        RegionDistance =
                            select(
                                2,
                                D.nearestWakeRegion(
                                    eroot.Position
                                )
                            ),
                    }
                )
            end
        end

        table.sort(
            rows2,
            function(a,b)
                return a.Distance
                    < b.Distance
            end
        )

        while #rows2
            > (limit or 10)
        do
            table.remove(
                rows2
            )
        end

        return rows2
    end

    local function nearestDoors(limit)
        local r =
            root()

        local rows2 = {}

        if not r then
            return rows2
        end

        local ok, list =
            pcall(
                D.physicalDoorRows
            )

        if not ok
            or type(list)
                ~= "table"
        then
            return rows2
        end

        for _, row in ipairs(list) do
            if row.PromptPos then
                table.insert(
                    rows2,
                    {
                        RoundNum =
                            row.RoundNum,
                        Switch =
                            row.Switch,
                        Prompt =
                            row.Prompt,
                        PromptPos =
                            row.PromptPos,
                        Distance =
                            (
                                row.PromptPos
                                - r.Position
                            ).Magnitude,
                    }
                )
            end
        end

        table.sort(
            rows2,
            function(a,b)
                return a.Distance
                    < b.Distance
            end
        )

        while #rows2
            > (limit or 10)
        do
            table.remove(
                rows2
            )
        end

        return rows2
    end

    local function eggSummary()
        local ok, egg =
            pcall(
                D.currentDragonEgg
            )

        if not ok
            or not egg
        then
            return "none"
        end

        local active = nil
        local broken = nil
        local pos = nil

        pcall(function()
            active =
                D.dragonEggActive(
                    egg
                )

            broken =
                D.dragonEggBroken(
                    egg
                )
        end)

        if egg:IsA("Model") then
            local part =
                egg.PrimaryPart
                or egg:
                    FindFirstChildWhichIsA(
                        "BasePart",
                        true
                    )

            pos =
                part
                and part.Position
        elseif egg:IsA("BasePart") then
            pos =
                egg.Position
        end

        local r =
            root()

        local dist =
            r
            and pos
            and (
                pos
                - r.Position
            ).Magnitude

        return "active="
            .. sv(active)
            .. " broken="
            .. sv(broken)
            .. " dist="
            .. sv(dist)
            .. " pos="
            .. sv(pos)
    end

    function T:Snapshot(label)
        local st =
            state()

        local r =
            root()

        local localCount,
            globalCount =
                counts()

        local current =
            D.getCurrentRegion()

        local currentDist = nil

        if r
            and current
        then
            pcall(function()
                currentDist =
                    D.boxDistance(
                        current,
                        r.Position
                    )
            end)
        end

        local nearestRegion = nil
        local nearestRegionDist = nil

        if r then
            pcall(function()
                nearestRegion,
                    nearestRegionDist =
                        D.nearestWakeRegion(
                            r.Position
                        )
            end)
        end

        local portal = nil
        local portalDist = nil

        pcall(function()
            portal =
                D.exactRoundDoorPortal()

            if portal
                and r
            then
                portalDist =
                    D.boxDistance(
                        portal,
                        r.Position
                    )
            end
        end)

        local lines = {
            "Version=V61.1",
            "Label="
                .. sv(label),
            "State="
                .. sv(st.State),
            "GameRound="
                .. sv(
                    D.gameRound()
                ),
            "LastRound="
                .. sv(
                    st.LastRound
                ),
            "CompletedRound="
                .. sv(
                    st.CompletedRound
                ),
            "PendingGateRound="
                .. sv(
                    st.PendingGateRound
                ),
            "CurrentCombatRound="
                .. sv(
                    st.CurrentCombatRound
                ),
            "PlayerPos="
                .. sv(
                    r
                    and r.Position
                ),
            "CurrentRegion="
                .. sv(
                    current
                    and D.fullName(
                        current
                    )
                ),
            "CurrentRegionDistance="
                .. sv(
                    currentDist
                ),
            "NearestRegion="
                .. sv(
                    nearestRegion
                    and D.fullName(
                        nearestRegion
                    )
                ),
            "NearestRegionDistance="
                .. sv(
                    nearestRegionDist
                ),
            "LocalEnemies="
                .. sv(
                    localCount
                ),
            "GlobalEnemies="
                .. sv(
                    globalCount
                ),
            "Egg="
                .. eggSummary(),
            "ExactPortal="
                .. sv(
                    portal
                    and D.fullName(
                        portal
                    )
                ),
            "ExactPortalDistance="
                .. sv(
                    portalDist
                ),
            "ExactPortalRound="
                .. sv(
                    portal
                    and portal:
                        GetAttribute(
                            "RoundNum"
                        )
                ),
            "PortalsInvoked="
                .. sv(
                    st.PortalsInvoked
                ),
            "Deaths="
                .. sv(
                    st.Deaths
                ),
        }

        local teleportData = nil

        pcall(function()
            teleportData =
                TeleportService:
                    GetLocalPlayerTeleportData()
        end)

        if type(teleportData)
            == "table"
        then
            table.insert(
                lines,
                "TeleportWorld="
                    .. sv(
                        teleportData.WorldId
                        or teleportData.World
                    )
            )

            table.insert(
                lines,
                "TeleportDiff="
                    .. sv(
                        teleportData.DiffLevel
                        or teleportData.Diff
                    )
            )

            table.insert(
                lines,
                "TeleportPlayerCount="
                    .. sv(
                        teleportData.PlayerCount
                    )
            )
        end

        local humanoid =
            D.getHumanoid
            and D.getHumanoid()

        local combatProfile =
            D.getCombatProfile
            and D.getCombatProfile()

        table.insert(
            lines,
            "PlayerVelocity="
                .. sv(
                    r
                    and r.AssemblyLinearVelocity
                )
        )

        local movementHumanoid =
            D.getHumanoid
            and D.getHumanoid()

        table.insert(
            lines,
            "MoveDirection="
                .. sv(
                    movementHumanoid
                    and movementHumanoid.MoveDirection
                )
        )

        table.insert(
            lines,
            "PlayerHP="
                .. sv(
                    humanoid
                    and humanoid.Health
                )
                .. "/"
                .. sv(
                    humanoid
                    and humanoid.MaxHealth
                )
        )

        if type(combatProfile)
            == "table"
        then
            table.insert(
                lines,
                "CombatProfile="
                    .. sv(
                        combatProfile.Mode
                    )
                    .. " Height="
                    .. sv(
                        combatProfile.Height
                    )
                    .. " Offset="
                    .. sv(
                        combatProfile.Offset
                    )
                    .. " Yaw="
                    .. sv(
                        combatProfile.Yaw
                    )
                    .. " IncomingHits="
                    .. sv(
                        combatProfile.IncomingHits
                    )
                    .. " TargetNoDamageAge="
                    .. sv(
                        combatProfile.TargetNoDamageAge
                    )
            )
        else
            table.insert(
                lines,
                "CombatProfile=unavailable"
            )
        end

        table.insert(
            lines,
            ""
        )

        table.insert(
            lines,
            "ROUND_WAKE_REGIONS:"
        )

        local wakeFolder =
            D.roundWakeFolder
            and D.roundWakeFolder()

        if wakeFolder then
            local regionRows = {}

            for _, region in ipairs(
                wakeFolder:GetChildren()
            ) do
                if region:IsA(
                    "BasePart"
                ) then
                    table.insert(
                        regionRows,
                        {
                            Region = region,
                            Distance =
                                r
                                and D.boxDistance(
                                    region,
                                    r.Position
                                )
                                or math.huge,
                        }
                    )
                end
            end

            table.sort(
                regionRows,
                function(a,b)
                    return a.Distance
                        < b.Distance
                end
            )

            for i = 1,
                math.min(
                    16,
                    #regionRows
                )
            do
                local row =
                    regionRows[i]

                table.insert(
                    lines,
                    "#"
                        .. tostring(i)
                        .. " "
                        .. D.fullName(
                            row.Region
                        )
                        .. " dist="
                        .. string.format(
                            "%.1f",
                            row.Distance
                        )
                        .. " pos="
                        .. sv(
                            row.Region.Position
                        )
                        .. " size="
                        .. sv(
                            row.Region.Size
                        )
                )
            end
        else
            table.insert(
                lines,
                "none"
            )
        end

        table.insert(
            lines,
            ""
        )

        table.insert(
            lines,
            "NEAREST_ENEMIES:"
        )

        local enemies =
            nearestEnemies(10)

        if #enemies == 0 then
            table.insert(
                lines,
                "none"
            )
        else
            for i, row in ipairs(enemies) do
                table.insert(
                    lines,
                    "#"
                        .. tostring(i)
                        .. " "
                        .. sv(
                            row.Enemy.Name
                        )
                        .. " hp="
                        .. sv(
                            row.HP
                        )
                        .. " dist="
                        .. string.format(
                            "%.1f",
                            row.Distance
                        )
                        .. " pos="
                        .. sv(
                            row.Root.Position
                        )
                        .. " region="
                        .. sv(
                            row.Region
                            and D.fullName(
                                row.Region
                            )
                        )
                        .. " regionDist="
                        .. sv(
                            row.RegionDistance
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
            "NEAREST_DOORS:"
        )

        local doors =
            nearestDoors(10)

        if #doors == 0 then
            table.insert(
                lines,
                "none"
            )
        else
            for i, row in ipairs(doors) do
                table.insert(
                    lines,
                    "#"
                        .. tostring(i)
                        .. " Round="
                        .. sv(
                            row.RoundNum
                        )
                        .. " Switch="
                        .. sv(
                            row.Switch
                        )
                        .. " PromptEnabled="
                        .. sv(
                            row.Prompt
                            and row.Prompt.Enabled
                        )
                        .. " dist="
                        .. string.format(
                            "%.1f",
                            row.Distance
                        )
                        .. " pos="
                        .. sv(
                            row.PromptPos
                        )
                )
            end
        end

        local settled = false
        local settlePath = nil
        local settleText = nil

        pcall(function()
            settled,
                settlePath,
                settleText =
                    D.settlementDetected()
        end)

        table.insert(
            lines,
            ""
        )

        table.insert(
            lines,
            "Settlement="
                .. sv(settled)
                .. " path="
                .. sv(settlePath)
                .. " text="
                .. sv(settleText)
        )

        if type(writefile)
            == "function"
        then
            pcall(
                writefile,
                STATE_FILE,
                table.concat(
                    lines,
                    "\n"
                )
            )
        end

        return table.concat(
            lines,
            "\n"
        )
    end

    function T:Event(name, detail)
        lastProgress =
            os.clock()

        append(
            tostring(name)
                .. (
                    detail
                    and detail ~= ""
                    and (
                        " | "
                        .. tostring(detail)
                    )
                    or ""
                )
        )

        self:
            Snapshot(name)
    end

    function T:Start()
        if started then
            return
        end

        started = true

        task.spawn(function()
            while true do
                task.wait(
                    tonumber(
                        D.CFG.TELEMETRY_HEARTBEAT
                    )
                    or 2
                )

                local st =
                    state()

                local localCount,
                    globalCount =
                        counts()

                local nearest =
                    nearestEnemies(1)[1]

                if globalCount > 0
                    and lastGlobalCount == 0
                then
                    append(
                        "WAVE_SPAWN"
                            .. " count="
                            .. sv(
                                globalCount
                            )
                            .. " nearest="
                            .. sv(
                                nearest
                                and nearest.Enemy.Name
                            )
                            .. "@"
                            .. sv(
                                nearest
                                and math.floor(
                                    nearest.Distance
                                )
                            )
                            .. " region="
                            .. sv(
                                nearest
                                and nearest.Region
                                and D.fullName(
                                    nearest.Region
                                )
                            )
                    )
                end

                lastGlobalCount =
                    globalCount

                local fingerprint =
                    table.concat({
                        sv(st.State),
                        sv(D.gameRound()),
                        sv(
                            st.CompletedRound
                        ),
                        sv(
                            st.PendingGateRound
                        ),
                        sv(localCount),
                        sv(globalCount),
                        sv(
                            nearest
                            and nearest.Enemy.Name
                        ),
                        sv(
                            nearest
                            and math.floor(
                                nearest.Distance
                            )
                        ),
                        eggSummary(),
                    }, "|")

                local now =
                    os.clock()

                if fingerprint
                        ~= lastFingerprint
                    or now
                        - lastFull
                        >= (
                            tonumber(
                                D.CFG.TELEMETRY_FULL_EVERY
                            )
                            or 6
                        )
                then
                    lastFingerprint =
                        fingerprint

                    lastFull =
                        now

                    append(
                        "HEARTBEAT"
                            .. " state="
                            .. sv(
                                st.State
                            )
                            .. " round="
                            .. sv(
                                D.gameRound()
                            )
                            .. " completed="
                            .. sv(
                                st.CompletedRound
                            )
                            .. " pending="
                            .. sv(
                                st.PendingGateRound
                            )
                            .. " local="
                            .. sv(
                                localCount
                            )
                            .. " global="
                            .. sv(
                                globalCount
                            )
                            .. " nearest="
                            .. sv(
                                nearest
                                and nearest.Enemy.Name
                            )
                            .. "@"
                            .. sv(
                                nearest
                                and math.floor(
                                    nearest.Distance
                                )
                            )
                    )

                    self:
                        Snapshot(
                            "HEARTBEAT"
                        )
                end

                local stallAfter =
                    tonumber(
                        D.CFG.TELEMETRY_STALL_AFTER
                    )
                    or 7

                if now
                        - lastProgress
                        >= stallAfter
                    and now
                        - lastStall
                        >= stallAfter
                then
                    lastStall =
                        now

                    append(
                        "STALL"
                            .. " age="
                            .. string.format(
                                "%.1f",
                                now
                                    - lastProgress
                            )
                            .. " state="
                            .. sv(
                                st.State
                            )
                            .. " round="
                            .. sv(
                                D.gameRound()
                            )
                            .. " local="
                            .. sv(
                                localCount
                            )
                            .. " global="
                            .. sv(
                                globalCount
                            )
                    )

                    self:
                        Snapshot(
                            "STALL"
                        )
                end
            end
        end)
    end

    return T
end
