--========================================================--
-- IRON SOUL - CONTINUOUS DODGE COMBAT POSITION V61.4
--
-- Attack rotation never pauses because of these profiles.
--
-- Normal mobs:
--   DEFAULT -> reactive EVADE / EVADE_WIDE on incoming damage.
--
-- Boss-like HP:
--   BOSS_ORBIT continuously circles while attacking.
--
-- Low HP:
--   LOW_HP_ORBIT keeps a wider, faster orbit while still attacking.
--
-- Own attacks stop registering:
--   HIT_RECOVERY returns to the previously validated close 5.5-stud profile.
--
-- Knock/ragdoll-like Humanoid state:
--   KNOCK_EVADE changes position aggressively but does NOT fake server state.
--========================================================--

return function(D)
    local C = {}

    local S = {
        Mode = "DEFAULT",

        Height =
            D.CFG.ADAPTIVE_DEFAULT_HEIGHT,

        Offset =
            D.CFG.ADAPTIVE_DEFAULT_OFFSET,

        Yaw = 0,
        OrbitSpeed = 0,
        Side = 1,

        BossLike = false,
        IncomingHits = 0,

        LastPlayerHP = nil,
        PlayerMaxHP = nil,
        LastPlayerHitAt =
            -math.huge,

        LastTargetHP = nil,
        LastTargetDamageAt =
            os.clock(),

        LastHumanoidState =
            nil,

        ModeStartedAt =
            os.clock(),

        ModeUntil =
            -math.huge,

        RecoveryDamageAt =
            nil,
    }

    local function emit(name, detail)
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

    local function setMode(
        mode,
        height,
        offset,
        yaw,
        hold,
        orbitSpeed
    )
        local changed =
            S.Mode ~= mode
            or S.Height ~= height
            or S.Offset ~= offset
            or S.Yaw ~= yaw
            or S.OrbitSpeed
                ~= (
                    orbitSpeed
                    or 0
                )

        S.Mode = mode
        S.Height = height
        S.Offset = offset
        S.Yaw = yaw
        S.OrbitSpeed =
            orbitSpeed
            or 0

        S.ModeStartedAt =
            os.clock()

        S.ModeUntil =
            hold
            and (
                os.clock()
                + hold
            )
            or -math.huge

        if changed then
            emit(
                "COMBAT_PROFILE",
                "mode="
                    .. tostring(mode)
                    .. " h="
                    .. tostring(height)
                    .. " offset="
                    .. tostring(offset)
                    .. " yaw="
                    .. tostring(yaw)
                    .. " orbit="
                    .. tostring(
                        S.OrbitSpeed
                    )
                    .. " boss="
                    .. tostring(
                        S.BossLike
                    )
                    .. " incomingHits="
                    .. tostring(
                        S.IncomingHits
                    )
            )
        end
    end

    local function baseMode()
        if S.BossLike then
            setMode(
                "BOSS_ORBIT",
                D.CFG.ADAPTIVE_BOSS_HEIGHT,
                D.CFG.ADAPTIVE_BOSS_OFFSET,
                0,
                nil,
                D.CFG.ADAPTIVE_BOSS_ORBIT_SPEED
                    * S.Side
            )
        else
            setMode(
                "DEFAULT",
                D.CFG.ADAPTIVE_DEFAULT_HEIGHT,
                D.CFG.ADAPTIVE_DEFAULT_OFFSET,
                0,
                nil,
                0
            )
        end
    end

    local function lowHPRatio(playerHP)
        if not playerHP
            or not S.PlayerMaxHP
            or S.PlayerMaxHP <= 0
        then
            return 1
        end

        return playerHP
            / S.PlayerMaxHP
    end

    local function knockLike(state)
        if state == nil then
            return false
        end

        local text =
            string.lower(
                tostring(state)
            )

        return string.find(
            text,
            "ragdoll",
            1,
            true
        )
            or string.find(
                text,
                "fallingdown",
                1,
                true
            )
            or string.find(
                text,
                "platformstanding",
                1,
                true
            )
            or string.find(
                text,
                "physics",
                1,
                true
            )
    end

    function C:ResetTarget(
        enemy,
        targetHP,
        playerHP,
        playerMaxHP,
        humanoidState
    )
        S.LastTargetHP =
            targetHP

        S.LastTargetDamageAt =
            os.clock()

        S.LastPlayerHP =
            playerHP

        S.PlayerMaxHP =
            playerMaxHP

        S.LastPlayerHitAt =
            -math.huge

        S.LastHumanoidState =
            humanoidState

        S.BossLike =
            tonumber(targetHP)
                and tonumber(targetHP)
                    >= D.CFG.ADAPTIVE_BOSS_HP
            or false

        S.IncomingHits = 0
        S.Side = 1
        S.RecoveryDamageAt = nil

        baseMode()

        if S.BossLike then
            emit(
                "BOSS_ORBIT_START",
                "hp="
                    .. tostring(
                        targetHP
                    )
                    .. " playerHP="
                    .. tostring(
                        playerHP
                    )
            )
        end
    end

    function C:Update(
        enemy,
        targetHP,
        playerHP,
        playerMaxHP,
        humanoidState
    )
        local now =
            os.clock()

        if playerMaxHP
            and playerMaxHP > 0
        then
            S.PlayerMaxHP =
                playerMaxHP
        end

        local knocked =
            knockLike(
                humanoidState
            )

        if knocked
            and not knockLike(
                S.LastHumanoidState
            )
        then
            S.Side =
                -S.Side

            emit(
                "KNOCK_STATE",
                tostring(
                    humanoidState
                )
            )

            setMode(
                "KNOCK_EVADE",
                D.CFG.ADAPTIVE_KNOCK_HEIGHT,
                D.CFG.ADAPTIVE_KNOCK_OFFSET,
                0,
                D.CFG.ADAPTIVE_KNOCK_EVADE_HOLD,
                D.CFG.ADAPTIVE_KNOCK_ORBIT_SPEED
                    * S.Side
            )
        end

        S.LastHumanoidState =
            humanoidState

        -- Incoming player damage: attack loop continues; only position changes.
        if playerHP ~= nil
            and S.LastPlayerHP ~= nil
            and playerHP
                < S.LastPlayerHP
                    - D.CFG.ADAPTIVE_PLAYER_HIT_EPSILON
        then
            local amount =
                S.LastPlayerHP
                - playerHP

            local repeated =
                now
                    - S.LastPlayerHitAt
                <= D.CFG.ADAPTIVE_REPEAT_HIT_WINDOW

            S.IncomingHits += 1
            S.Side = -S.Side
            S.LastPlayerHitAt =
                now

            emit(
                "PLAYER_HIT",
                "damage="
                    .. string.format(
                        "%.1f",
                        amount
                    )
                    .. " hp="
                    .. tostring(
                        playerHP
                    )
                    .. " ratio="
                    .. string.format(
                        "%.2f",
                        lowHPRatio(
                            playerHP
                        )
                    )
                    .. " repeated="
                    .. tostring(
                        repeated
                    )
            )

            if lowHPRatio(
                    playerHP
                )
                <= D.CFG.ADAPTIVE_LOW_HP_RATIO
            then
                setMode(
                    "LOW_HP_ORBIT",
                    D.CFG.ADAPTIVE_LOW_HP_HEIGHT,
                    D.CFG.ADAPTIVE_LOW_HP_OFFSET,
                    0,
                    nil,
                    D.CFG.ADAPTIVE_LOW_HP_ORBIT_SPEED
                        * S.Side
                )

            elseif repeated then
                setMode(
                    "EVADE_WIDE",
                    D.CFG.ADAPTIVE_WIDE_HEIGHT,
                    D.CFG.ADAPTIVE_WIDE_OFFSET,
                    D.CFG.ADAPTIVE_WIDE_YAW
                        * S.Side,
                    D.CFG.ADAPTIVE_EVADE_HOLD,
                    D.CFG.ADAPTIVE_WIDE_ORBIT_SPEED
                        * S.Side
                )
            else
                setMode(
                    "EVADE",
                    D.CFG.ADAPTIVE_EVADE_HEIGHT,
                    D.CFG.ADAPTIVE_EVADE_OFFSET,
                    D.CFG.ADAPTIVE_EVADE_YAW
                        * S.Side,
                    D.CFG.ADAPTIVE_EVADE_HOLD,
                    D.CFG.ADAPTIVE_EVADE_ORBIT_SPEED
                        * S.Side
                )
            end
        end

        if playerHP ~= nil then
            S.LastPlayerHP =
                playerHP
        end

        -- Real server target damage.
        local damaged =
            targetHP ~= nil
            and S.LastTargetHP ~= nil
            and targetHP
                < S.LastTargetHP

        if damaged then
            S.LastTargetDamageAt =
                now

            if S.Mode
                == "HIT_RECOVERY"
            then
                S.RecoveryDamageAt =
                    now

                emit(
                    "TARGET_DAMAGE_RESUMED",
                    "hp="
                        .. tostring(
                            S.LastTargetHP
                        )
                        .. "->"
                        .. tostring(
                            targetHP
                        )
                )
            end
        end

        if targetHP ~= nil then
            S.LastTargetHP =
                targetHP
        end

        local noTargetDamageAge =
            now
            - S.LastTargetDamageAt

        -- Preserve damage reliability above avoidance. If attacks stop
        -- registering, move to the already-validated close profile.
        if noTargetDamageAge
                >= D.CFG.ADAPTIVE_NO_TARGET_DAMAGE
            and S.Mode
                ~= "HIT_RECOVERY"
        then
            S.RecoveryDamageAt =
                nil

            setMode(
                "HIT_RECOVERY",
                D.CFG.ADAPTIVE_RECOVERY_HEIGHT,
                D.CFG.ADAPTIVE_RECOVERY_OFFSET,
                0,
                nil,
                0
            )

            emit(
                "TARGET_HIT_STALL",
                "age="
                    .. string.format(
                        "%.2f",
                        noTargetDamageAge
                    )
            )
        end

        if S.Mode
            == "HIT_RECOVERY"
        then
            if S.RecoveryDamageAt
                and now
                    - S.RecoveryDamageAt
                    >= D.CFG.ADAPTIVE_RETURN_STABLE
            then
                if lowHPRatio(
                        playerHP
                    )
                    <= D.CFG.ADAPTIVE_LOW_HP_RATIO
                then
                    setMode(
                        "LOW_HP_ORBIT",
                        D.CFG.ADAPTIVE_LOW_HP_HEIGHT,
                        D.CFG.ADAPTIVE_LOW_HP_OFFSET,
                        0,
                        nil,
                        D.CFG.ADAPTIVE_LOW_HP_ORBIT_SPEED
                            * S.Side
                    )
                else
                    baseMode()
                end
            end

        elseif S.Mode
            == "LOW_HP_ORBIT"
        then
            -- Stay defensive until this target dies or HP is no longer low.
            if lowHPRatio(
                    playerHP
                )
                > D.CFG.ADAPTIVE_LOW_HP_RATIO
                    + 0.08
                and noTargetDamageAge
                    < D.CFG.ADAPTIVE_NO_TARGET_DAMAGE
            then
                baseMode()
            end

        elseif (
            S.Mode == "EVADE"
            or S.Mode == "EVADE_WIDE"
            or S.Mode == "KNOCK_EVADE"
        )
            and now >= S.ModeUntil
            and now
                - S.LastPlayerHitAt
                >= D.CFG.ADAPTIVE_EVADE_HOLD
            and noTargetDamageAge
                < D.CFG.ADAPTIVE_NO_TARGET_DAMAGE
            and not knocked
        then
            if lowHPRatio(
                    playerHP
                )
                <= D.CFG.ADAPTIVE_LOW_HP_RATIO
            then
                setMode(
                    "LOW_HP_ORBIT",
                    D.CFG.ADAPTIVE_LOW_HP_HEIGHT,
                    D.CFG.ADAPTIVE_LOW_HP_OFFSET,
                    0,
                    nil,
                    D.CFG.ADAPTIVE_LOW_HP_ORBIT_SPEED
                        * S.Side
                )
            else
                baseMode()
            end
        end
    end

    function C:GetMovement()
        local yaw =
            S.Yaw

        if S.OrbitSpeed ~= 0 then
            yaw +=
                (
                    os.clock()
                    - S.ModeStartedAt
                )
                * S.OrbitSpeed
        end

        return {
            Mode = S.Mode,
            Height = S.Height,
            Offset = S.Offset,
            Yaw = yaw,
        }
    end

    function C:GetState()
        return {
            Mode = S.Mode,
            Height = S.Height,
            Offset = S.Offset,
            Yaw = S.Yaw,
            OrbitSpeed =
                S.OrbitSpeed,
            Side = S.Side,
            BossLike =
                S.BossLike,
            IncomingHits =
                S.IncomingHits,
            LastPlayerHP =
                S.LastPlayerHP,
            PlayerMaxHP =
                S.PlayerMaxHP,
            PlayerRatio =
                lowHPRatio(
                    S.LastPlayerHP
                ),
            LastPlayerHitAt =
                S.LastPlayerHitAt,
            LastTargetHP =
                S.LastTargetHP,
            LastTargetDamageAt =
                S.LastTargetDamageAt,
            TargetNoDamageAge =
                os.clock()
                - S.LastTargetDamageAt,
            HumanoidState =
                S.LastHumanoidState,
        }
    end

    return C
end
