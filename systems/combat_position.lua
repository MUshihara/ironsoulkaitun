--========================================================--
-- IRON SOUL - ADAPTIVE COMBAT POSITION V61.0
--
-- Profiles:
-- DEFAULT      : proven 9-stud position
-- EVADE        : player got hit -> side angle + farther offset
-- EVADE_WIDE   : repeated hit -> wider side angle
-- HIT_RECOVERY : target HP stalled -> proven 5.5-stud close position
--
-- It never uses unvalidated extreme heights or below-floor positioning.
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
        Side = 1,

        IncomingHits = 0,

        LastPlayerHP = nil,
        LastPlayerHitAt =
            -math.huge,

        LastTargetHP = nil,
        LastTargetDamageAt =
            os.clock(),

        ModeStartedAt =
            os.clock(),

        ModeUntil =
            -math.huge,

        RecoveryDamageAt =
            nil,
    }

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

    local function setMode(
        mode,
        height,
        offset,
        yaw,
        hold
    )
        local changed =
            S.Mode ~= mode
            or S.Height ~= height
            or S.Offset ~= offset
            or S.Yaw ~= yaw

        S.Mode = mode
        S.Height = height
        S.Offset = offset
        S.Yaw = yaw
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
                    .. " incomingHits="
                    .. tostring(
                        S.IncomingHits
                    )
            )
        end
    end

    local function defaultMode()
        setMode(
            "DEFAULT",
            D.CFG.ADAPTIVE_DEFAULT_HEIGHT,
            D.CFG.ADAPTIVE_DEFAULT_OFFSET,
            0,
            nil
        )
    end

    function C:ResetTarget(
        enemy,
        targetHP,
        playerHP
    )
        S.LastTargetHP =
            targetHP

        S.LastTargetDamageAt =
            os.clock()

        S.LastPlayerHP =
            playerHP

        S.LastPlayerHitAt =
            -math.huge

        S.IncomingHits = 0
        S.Side = 1
        S.RecoveryDamageAt = nil

        defaultMode()
    end

    function C:Update(
        enemy,
        targetHP,
        playerHP
    )
        local now =
            os.clock()

        -- Incoming player damage.
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
                    .. " repeated="
                    .. tostring(
                        repeated
                    )
            )

            if repeated then
                setMode(
                    "EVADE_WIDE",
                    D.CFG.ADAPTIVE_WIDE_HEIGHT,
                    D.CFG.ADAPTIVE_WIDE_OFFSET,
                    D.CFG.ADAPTIVE_WIDE_YAW
                        * S.Side,
                    D.CFG.ADAPTIVE_EVADE_HOLD
                )
            else
                setMode(
                    "EVADE",
                    D.CFG.ADAPTIVE_EVADE_HEIGHT,
                    D.CFG.ADAPTIVE_EVADE_OFFSET,
                    D.CFG.ADAPTIVE_EVADE_YAW
                        * S.Side,
                    D.CFG.ADAPTIVE_EVADE_HOLD
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

        -- If OUR hits are not landing, farther is the wrong direction.
        -- Use the previously verified 5.5-stud close recovery profile.
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
                nil
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
                defaultMode()
            end

        elseif (
            S.Mode == "EVADE"
            or S.Mode
                == "EVADE_WIDE"
        )
            and now >= S.ModeUntil
            and now
                - S.LastPlayerHitAt
                >= D.CFG.ADAPTIVE_EVADE_HOLD
            and noTargetDamageAge
                < D.CFG.ADAPTIVE_NO_TARGET_DAMAGE
        then
            defaultMode()
        end
    end

    function C:GetMovement()
        return {
            Mode = S.Mode,
            Height = S.Height,
            Offset = S.Offset,
            Yaw = S.Yaw,
        }
    end

    function C:GetState()
        return {
            Mode = S.Mode,
            Height = S.Height,
            Offset = S.Offset,
            Yaw = S.Yaw,
            Side = S.Side,
            IncomingHits =
                S.IncomingHits,
            LastPlayerHP =
                S.LastPlayerHP,
            LastPlayerHitAt =
                S.LastPlayerHitAt,
            LastTargetHP =
                S.LastTargetHP,
            LastTargetDamageAt =
                S.LastTargetDamageAt,
            TargetNoDamageAge =
                os.clock()
                - S.LastTargetDamageAt,
        }
    end

    return C
end
