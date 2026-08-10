--========================================================--
-- IRON SOUL - QUIET EGG-ATTACK CONTINUOUS COMBAT V59.3
--
-- MAJOR CHANGE:
-- Portal/gate progression now uses the GAME'S EXACT route recovered
-- from LocalRoundPortal:
--
--   if CanOpen() then
--       Root.RF:InvokeServer()
--   end
--
-- LocalRoundPortal CanOpen:
--   * if RoundNum is nil -> true
--   * Settlement must NOT be active
--   * GameRoundCfg.GameRound must exist
--   * RoundNum < GameRound
--
-- NO:
--   visual portal guessing
--   wall-torch/particle guessing
--   firetouchinterest
--   physical door crossing
--   mouse basic attacks while headless RF is verified
--   attribute spending
--   replay / return lobby
--
-- RUN:
--   inside a dungeon with Sword active.
--========================================================--

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")

local LocalPlayer = Players.LocalPlayer

-- Multiple queued loaders were observed starting the same combat module
-- 1 second apart in the same JobId. Ignore near-simultaneous duplicates.
do
    local key =
        tostring(game.PlaceId)
        .. "|"
        .. tostring(game.JobId)

    local old =
        getgenv().IronSoulCombatGuard

    if type(old) == "table"
        and old.Key == key
        and os.clock()
            - tonumber(old.At or 0)
            < 12
    then
        return
    end

    getgenv().IronSoulCombatGuard = {
        Key = key,
        At = os.clock(),
    }
end

local UserConfig =
    getgenv().IronSoulConfig
    or {}

local CFG = {
    FPS_CAP = 8,

    -- Keep console + disk logs quiet by default.
    -- Set DEBUG_LOGS=true in IronSoulConfig only when diagnosing.
    DEBUG_LOGS =
        UserConfig.DEBUG_LOGS == true,

    TARGET_DISTANCE = 5.2,
    MAX_TARGET_DISTANCE = 500,

    -- Stable elevated farming.
    -- V55.3 empirical result:
    --   5  = pass
    --   9  = pass
    --   13/17/21 = inconsistent
    --   25 = fail
    --
    -- 9 studs is therefore the highest CONSISTENT verified height.
    ELEVATED_COMBAT = true,
    ELEVATED_NORMAL_HEIGHT = 9.0,
    ELEVATED_RECOVERY_HEIGHT = 5.5,
    ELEVATED_HORIZONTAL_OFFSET = 1.50,

    -- If a specific enemy gets no real HP damage at the normal height,
    -- temporarily descend for that target only.
    ELEVATED_TARGET_NO_DAMAGE_TIME = 2.25,
    ELEVATED_RECOVERY_HOLD = 1.20,

    BASIC_INTERVAL = 0.14,
    COMBAT_TICK = 0.045,

    HEADLESS_DAMAGE_WATCHDOG = 3.5,
    HEADLESS_RECOVERY_COOLDOWN = 1.5,

    -- V55.2 NEVER falls back to synthetic Mouse1.
    -- A stalled headless attack resets/replays its combo instead.
    NO_MOUSE_BASIC_ATTACK = true,

    -- Immediately stop Action-priority animations while direct
    -- headless attacks/skills are running. Visual-only.
    SUPPRESS_ACTION_ANIMATIONS = true,

    NO_ENEMY_STABLE_TIME = 0.75,

    -- Current-room filtering. Enemies outside the current RoundWakeTouch
    -- volume are completely ignored.
    ROOM_ENEMY_MARGIN = 28,
    ROOM_RELOCK_DISTANCE = 70,

    -- Door selection must belong to the current room boundary.
    DOOR_REGION_MAX_DISTANCE = 80,
    DOOR_OPEN_TIMEOUT = 2.0,
    DOOR_CROSS_TIMEOUT = 5.0,

    -- Only the exact RoundDoor.Portal can be used, never Workspace.Portal.
    SECTION_PORTAL_NEAR_DISTANCE = 85,
    SECTION_PORTAL_APPEAR_TIMEOUT = 12,
    SECTION_PORTAL_TOUCH_TIMEOUT = 10,
    SECTION_PORTAL_JIGGLE_STEP = 1.15,

    PORTAL_MAX_BOX_DISTANCE = 75,
    PORTAL_VERIFY_TIMEOUT = 12,

    DEATH_RESPAWN_TIMEOUT = 18,
    GLOBAL_TIMEOUT = 900,
}

if type(setfpscap) == "function" then
    pcall(setfpscap, CFG.FPS_CAP)
end

task.wait(2)

--========================================================--
-- OUTPUT
--========================================================--

local ROOT_FOLDER =
    "IronSoul_QuietCombat_V59_3"

local SESSION =
    os.date("%Y%m%d_%H%M%S")
    .. "_"
    .. tostring(game.PlaceId)

local FOLDER =
    ROOT_FOLDER
    .. "/"
    .. SESSION

pcall(makefolder, ROOT_FOLDER)
pcall(makefolder, FOLDER)

local report = {}
local combatOut = {}
local portalOut = {}
local deathOut = {}
local settlementOut = {}

local function ts()
    return string.format("%.3f", os.clock())
end

local function add(t, s)
    table.insert(t, tostring(s))
end

local function important(s)
    print(
        "[IronSoul]",
        tostring(s)
    )
end

local function log(s)
    local line =
        "["
        .. ts()
        .. "] "
        .. tostring(s)

    if CFG.DEBUG_LOGS then
        add(report, line)
    end

    local text =
        tostring(s)

    if string.find(
        text,
        "AttackDriver=HEADLESS_REMOTE VERIFIED",
        1,
        true
    )
        or string.find(
            text,
            "Headless damage watchdog",
            1,
            true
        )
        or string.find(
            text,
            "ABORT",
            1,
            true
        )
    then
        important(text)
    end
end

local function combatLog(s)
    if CFG.DEBUG_LOGS then
        add(
            combatOut,
            "["
                .. ts()
                .. "] "
                .. tostring(s)
        )
    end
end

local function portalLog(s)
    if CFG.DEBUG_LOGS then
        add(
            portalOut,
            "["
                .. ts()
                .. "] "
                .. tostring(s)
        )
    end
end

local function deathLog(s)
    if CFG.DEBUG_LOGS then
        add(
            deathOut,
            "["
                .. ts()
                .. "] "
                .. tostring(s)
        )
    end

    important(
        "Death | "
            .. tostring(s)
    )
end

local function settlementLog(s)
    if CFG.DEBUG_LOGS then
        add(
            settlementOut,
            "["
                .. ts()
                .. "] "
                .. tostring(s)
        )
    end
end

local function save()
    if not CFG.DEBUG_LOGS
        or type(writefile)
            ~= "function"
    then
        return
    end

    for _, row in ipairs({
        {"report.txt", report},
        {"combat.txt", combatOut},
        {"portals.txt", portalOut},
        {"deaths.txt", deathOut},
        {"settlement.txt", settlementOut},
    }) do
        pcall(
            writefile,
            FOLDER
                .. "/"
                .. row[1],
            table.concat(
                row[2],
                "\n"
            )
        )
    end
end

--========================================================--
-- GENERIC HELPERS
--========================================================--

local function findByName(root, name, className)
    for _, obj in ipairs(root:GetDescendants()) do
        if obj.Name == name
            and (
                not className
                or obj:IsA(className)
            )
        then
            return obj
        end
    end
end

local function req(name)
    local obj =
        findByName(
            ReplicatedStorage,
            name,
            "ModuleScript"
        )

    if not obj then
        return nil
    end

    local ok, value =
        pcall(require, obj)

    return ok and value or nil
end

local function waitUntil(fn, timeout, step)
    local deadline =
        os.clock()
        + (timeout or 5)

    step = step or 0.05

    while os.clock() < deadline do
        local ok, value =
            pcall(fn)

        if ok and value then
            return value
        end

        task.wait(step)
    end
end

local function fullName(obj)
    if typeof(obj) ~= "Instance" then
        return tostring(obj)
    end

    local ok, value =
        pcall(function()
            return obj:GetFullName()
        end)

    return ok
        and value
        or obj.Name
end

--========================================================--
-- DATA / ACTIVE SWORD
--========================================================--

local DataUtil = req("DataUtil")

local PlayerActionRE =
    findByName(
        ReplicatedStorage,
        "PlayerActionRE",
        "RemoteEvent"
    )

local GameRoundCfg =
    ReplicatedStorage:
        FindFirstChild(
            "GameRoundCfg"
        )

local function gameRound()
    return GameRoundCfg
        and tonumber(
            GameRoundCfg:
                GetAttribute(
                    "GameRound"
                )
        )
end

local function pdata()
    if not DataUtil then
        return nil
    end

    local ok, value =
        pcall(function()
            return DataUtil:
                GetPlayerData(
                    LocalPlayer
                )
        end)

    return ok
        and type(value) == "table"
        and value
        or nil
end

local function activeSword()
    local d = pdata()

    local equipment =
        d
        and d.Equipment

    if not equipment then
        return nil
    end

    local slot =
        equipment.CurWeaponSlot
        or "Weapon"

    local uuid =
        equipment.EquipSlots
        and equipment.EquipSlots[slot]

    local item =
        uuid
        and equipment.Owned
        and equipment.Owned[uuid]

    if item
        and item.Class == "Sword"
    then
        return {
            Slot = slot,
            UUID = uuid,
            Item = item,
        }
    end
end

local sword =
    activeSword()

if not sword then
    log("ABORT: active weapon is not Sword.")
    save()
    return
end

log(
    "Sword="
        .. tostring(sword.Item.ID)
        .. " UUID="
        .. tostring(sword.UUID)
)

--========================================================--
-- CHARACTER
--========================================================--

local Character
local Humanoid
local Root
local Animator
local animConn

local AttackDriverMode =
    "UNTESTED"

local SkillCastingUntil = 0

local function installAnimationSuppressor()
    if animConn then
        pcall(function()
            animConn:Disconnect()
        end)
        animConn = nil
    end

    if not CFG.SUPPRESS_ACTION_ANIMATIONS
        or not Animator
    then
        return
    end

    animConn =
        Animator.AnimationPlayed:
            Connect(function(track)
                -- This changes visuals only. Do not suppress while we
                -- intentionally allow a short skill-cast window.
                if AttackDriverMode == "HEADLESS_REMOTE"
                    and os.clock()
                        >= SkillCastingUntil
                then
                    local p =
                        track.Priority

                    if p == Enum.AnimationPriority.Action
                        or p == Enum.AnimationPriority.Action2
                        or p == Enum.AnimationPriority.Action3
                        or p == Enum.AnimationPriority.Action4
                    then
                        pcall(function()
                            track:Stop(0)
                        end)
                    end
                end
            end)
end

local function bindCharacter(char)
    Character = char

    Humanoid =
        char:WaitForChild(
            "Humanoid",
            10
        )

    Root =
        char:WaitForChild(
            "HumanoidRootPart",
            10
        )

    Animator =
        Humanoid
        and (
            Humanoid:
                FindFirstChildOfClass(
                    "Animator"
                )
            or Humanoid:
                WaitForChild(
                    "Animator",
                    3
                )
        )

    installAnimationSuppressor()

    return Humanoid ~= nil
        and Root ~= nil
end

if not bindCharacter(
    LocalPlayer.Character
    or LocalPlayer.CharacterAdded:Wait()
) then
    log("ABORT: character unavailable.")
    save()
    return
end

--========================================================--
-- EFFECTIVE GUI VISIBILITY / SETTLEMENT
--========================================================--

local function effectivelyVisible(obj)
    if not obj
        or not (
            obj:IsA("GuiObject")
            or obj:IsA("ScreenGui")
        )
    then
        return false
    end

    local current = obj

    while current
        and current ~= LocalPlayer
    do
        if current:IsA("GuiObject")
            and current.Visible == false
        then
            return false
        elseif current:IsA("ScreenGui")
            and current.Enabled == false
        then
            return false
        end

        if current
            == LocalPlayer.PlayerGui
        then
            break
        end

        current = current.Parent
    end

    if obj:IsA("GuiObject") then
        if obj.AbsoluteSize.X <= 0
            or obj.AbsoluteSize.Y <= 0
        then
            return false
        end
    end

    return true
end

local function visibleTextContains(pattern)
    local pg =
        LocalPlayer:
            FindFirstChildOfClass(
                "PlayerGui"
            )

    if not pg then
        return false
    end

    pattern =
        string.lower(pattern)

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
                    tostring(obj.Text)
                )

            if string.find(
                text,
                pattern,
                1,
                true
            ) then
                return true,
                    fullName(obj),
                    obj.Text
            end
        end
    end

    return false
end

local function settlementDetected()
    if LocalPlayer:GetAttribute(
        "Settlement"
    ) == true
    then
        return true,
            "Player.Attribute.Settlement",
            true
    end

    for _, text in ipairs({
        "return to lobby",
        "play again",
    }) do
        local ok, path, raw =
            visibleTextContains(text)

        if ok then
            return true,
                path,
                raw
        end
    end

    return false
end

--========================================================--
-- ENEMIES
--========================================================--

local CurrentCombatRegion = nil
local CurrentCombatRound = nil
local CurrentState = "INIT"

local function roundWakeFolder()
    local worldEnemies =
        workspace:
            FindFirstChild(
                "WorldEnemys"
            )

    return worldEnemies
        and worldEnemies:
            FindFirstChild(
                "RoundWakeTouch"
            )
end

local function boxDistance(part, worldPos)
    if not part
        or not worldPos
    then
        return math.huge
    end

    local localPos =
        part.CFrame:
            PointToObjectSpace(
                worldPos
            )

    local half =
        part.Size * 0.5

    local dx =
        math.max(
            math.abs(localPos.X)
                - half.X,
            0
        )

    local dy =
        math.max(
            math.abs(localPos.Y)
                - half.Y,
            0
        )

    local dz =
        math.max(
            math.abs(localPos.Z)
                - half.Z,
            0
        )

    return Vector3.new(
        dx,
        dy,
        dz
    ).Magnitude
end

local function pointInExpandedPart(
    part,
    worldPos,
    margin
)
    if not part
        or not worldPos
    then
        return false
    end

    margin = margin or 0

    local p =
        part.CFrame:
            PointToObjectSpace(
                worldPos
            )

    local half =
        part.Size * 0.5

    return math.abs(p.X)
            <= half.X + margin
        and math.abs(p.Y)
            <= half.Y + margin
        and math.abs(p.Z)
            <= half.Z + margin
end

local function nearestWakeRegion(pos)
    local folder =
        roundWakeFolder()

    if not folder
        or not pos
    then
        return nil,
            math.huge
    end

    local best = nil
    local bestDist =
        math.huge

    for _, obj in ipairs(
        folder:GetChildren()
    ) do
        if obj:IsA("BasePart") then
            local dist =
                boxDistance(
                    obj,
                    pos
                )

            if dist < bestDist then
                best = obj
                bestDist = dist
            end
        end
    end

    return best,
        bestDist
end

local function lockRegion(reason)
    if not Root then
        return nil
    end

    local region, dist =
        nearestWakeRegion(
            Root.Position
        )

    if region then
        CurrentCombatRegion =
            region

        CurrentCombatRound =
            gameRound()

        log(
            "REGION_LOCK reason="
                .. tostring(reason)
                .. " region="
                .. fullName(region)
                .. " boxDist="
                .. string.format(
                    "%.2f",
                    dist
                )
                .. " GameRound="
                .. tostring(
                    CurrentCombatRound
                )
                .. " PlayerPos="
                .. tostring(
                    Root.Position
                )
        )
    end

    return region
end

local function ensureRegion()
    if CurrentCombatRegion
        and CurrentCombatRegion.Parent
        and Root
    then
        local dist =
            boxDistance(
                CurrentCombatRegion,
                Root.Position
            )

        -- Do NOT re-lock during gate transition. This prevents a manual
        -- player movement or distant enemy from stealing the state.
        if CurrentState == "COMBAT"
            and dist
                > CFG.ROOM_RELOCK_DISTANCE
        then
            return lockRegion(
                "PLAYER_LEFT_REGION"
            )
        end

        return CurrentCombatRegion
    end

    return lockRegion(
        "MISSING_REGION"
    )
end

local function enemyContainer()
    return workspace:
        FindFirstChild(
            "EnemyNpc"
        )
end

local function modelRoot(model)
    if not model then
        return nil
    end

    return model:
        FindFirstChild(
            "HumanoidRootPart"
        )
        or model.PrimaryPart
        or model:
            FindFirstChildWhichIsA(
                "BasePart"
            )
end

local function enemyAlive(model)
    if not model
        or not model.Parent
    then
        return false
    end

    if model:GetAttribute("Dead") == true
        or model:GetAttribute("IsDead") == true
    then
        return false
    end

    local hum =
        model:
            FindFirstChildOfClass(
                "Humanoid"
            )

    if hum
        and hum.Health <= 0
    then
        return false
    end

    return modelRoot(model)
        ~= nil
end

local function liveEnemies()
    local container =
        enemyContainer()

    local out = {}

    if not container then
        return out
    end

    for _, model in ipairs(
        container:GetChildren()
    ) do
        if model:IsA("Model")
            and enemyAlive(model)
        then
            table.insert(out, model)
        end
    end

    return out
end

local function enemyBelongsToRegion(
    enemy,
    region
)
    if not enemy
        or not region
    then
        return false
    end

    local eroot =
        modelRoot(enemy)

    if not eroot then
        return false
    end

    return pointInExpandedPart(
        region,
        eroot.Position,
        CFG.ROOM_ENEMY_MARGIN
    )
end

local function localLiveEnemies()
    local region =
        ensureRegion()

    local out = {}

    if not region then
        return out
    end

    for _, enemy in ipairs(
        liveEnemies()
    ) do
        if enemyBelongsToRegion(
            enemy,
            region
        )
        then
            table.insert(
                out,
                enemy
            )
        end
    end

    return out
end

local function nearestEnemy()
    if not Root then
        return nil
    end

    local region =
        ensureRegion()

    if not region then
        return nil
    end

    local best
    local bestDist =
        math.huge

    for _, enemy in ipairs(
        liveEnemies()
    ) do
        if enemyBelongsToRegion(
            enemy,
            region
        )
        then
            local eroot =
                modelRoot(enemy)

            if eroot then
                local dist =
                    (
                        eroot.Position
                        - Root.Position
                    ).Magnitude

                if dist < bestDist
                    and dist
                        <= CFG.MAX_TARGET_DISTANCE
                then
                    best = enemy
                    bestDist = dist
                end
            end
        end
    end

    return best,
        bestDist
end

local function enemyHealth(enemy)
    local hum =
        enemy
        and enemy:
            FindFirstChildOfClass(
                "Humanoid"
            )

    return hum
        and hum.Health
end

--========================================================--
-- STABLE ELEVATED COMBAT POSITION
--
-- V55.3 measured real SERVER HP at multiple heights:
--   5  = 100% pass in sample
--   9  = 100% pass in sample
--   13 = inconsistent
--   17 = inconsistent
--   21 = inconsistent
--   25 = failed twice
--
-- Therefore V55.4 uses a conservative fixed 9-stud hover.
--
-- If one enemy receives no real damage for a sustained period:
--   temporarily drop to 5.5 studs for that enemy
--   then restore 9 studs on the next target.
--
-- No client hitbox/range expansion.
--========================================================--

local Elevation = {
    ActiveHeight =
        CFG.ELEVATED_NORMAL_HEIGHT,

    NormalHeight =
        CFG.ELEVATED_NORMAL_HEIGHT,

    RecoveryHeight =
        CFG.ELEVATED_RECOVERY_HEIGHT,

    InRecovery = false,
    RecoveryCount = 0,
    RecoveryStartedAt = -math.huge,

    LastDamageAt = os.clock(),
    LastObservedHP = nil,
}

local function currentCombatHeight()
    if not CFG.ELEVATED_COMBAT then
        return 0
    end

    return Elevation.ActiveHeight
end

local function resetElevationForNewTarget(enemy)
    Elevation.ActiveHeight =
        Elevation.NormalHeight

    Elevation.InRecovery =
        false

    Elevation.LastObservedHP =
        enemyHealth
        and enemyHealth(enemy)
        or nil

    Elevation.LastDamageAt =
        os.clock()
end

local function startElevationRecovery(enemy)
    if Elevation.InRecovery then
        return
    end

    Elevation.InRecovery =
        true

    Elevation.RecoveryCount += 1

    Elevation.RecoveryStartedAt =
        os.clock()

    Elevation.ActiveHeight =
        Elevation.RecoveryHeight

    Elevation.LastObservedHP =
        enemyHealth(enemy)

    Elevation.LastDamageAt =
        os.clock()

    combatLog(
        "ELEVATION_RECOVERY_START #"
            .. tostring(
                Elevation.RecoveryCount
            )
            .. " normal="
            .. tostring(
                Elevation.NormalHeight
            )
            .. " recovery="
            .. tostring(
                Elevation.RecoveryHeight
            )
            .. " enemy="
            .. fullName(enemy)
    )
end

local function trackElevationDamage(enemy)
    local hp =
        enemyHealth(enemy)

    local old =
        Elevation.LastObservedHP

    if old == nil
        or (
            hp ~= nil
            and hp < old
        )
    then
        Elevation.LastDamageAt =
            os.clock()

        if Elevation.InRecovery then
            combatLog(
                "ELEVATION_RECOVERY_DAMAGE hp="
                    .. tostring(old)
                    .. " -> "
                    .. tostring(hp)
            )
        end
    end

    Elevation.LastObservedHP = hp

    if not Elevation.InRecovery
        and enemyAlive(enemy)
        and os.clock()
            - Elevation.LastDamageAt
            > CFG.ELEVATED_TARGET_NO_DAMAGE_TIME
    then
        startElevationRecovery(
            enemy
        )
    end
end

local function horizontalUnitFromEnemy(eroot)
    if not Root
        or not eroot
    then
        return Vector3.new(
            0,
            0,
            1
        )
    end

    local delta =
        Vector3.new(
            Root.Position.X
                - eroot.Position.X,
            0,
            Root.Position.Z
                - eroot.Position.Z
        )

    if delta.Magnitude <= 0.05 then
        return Vector3.new(
            0,
            0,
            1
        )
    end

    return delta.Unit
end

--========================================================--
-- MOVEMENT
--========================================================--

local function moveNear(enemy)
    if not Root then
        return false
    end

    local eroot =
        modelRoot(enemy)

    if not eroot then
        return false
    end

    local height =
        currentCombatHeight()

    local horizontal =
        height > 0
        and CFG.ELEVATED_HORIZONTAL_OFFSET
        or CFG.TARGET_DISTANCE

    local dir =
        horizontalUnitFromEnemy(
            eroot
        )

    local goal =
        eroot.Position
        + dir * horizontal
        + Vector3.new(
            0,
            height,
            0
        )

    -- Look directly toward the enemy. At elevated height this points the
    -- attack direction down toward the target instead of horizontally
    -- over its head.
    Root.CFrame =
        CFrame.lookAt(
            goal,
            eroot.Position
        )

    -- Keep the combat hover stable. Gate/portal code controls its own
    -- movement and therefore is not affected by this.
    pcall(function()
        Root.AssemblyLinearVelocity =
            Vector3.zero

        Root.AssemblyAngularVelocity =
            Vector3.zero
    end)

    return true
end

local function face(enemy)
    if not Root then
        return
    end

    local eroot =
        modelRoot(enemy)

    if not eroot then
        return
    end

    local pos =
        Root.Position

    Root.CFrame =
        CFrame.lookAt(
            pos,
            eroot.Position
        )
end


--========================================================--
-- NATIVE SKILL CALLBACKS
--========================================================--

local Callbacks = {}

local function actionNameMatches(obj, action)
    local n =
        string.lower(obj.Name)

    if action == "Skill1" then
        return n == "skill1"
            or string.find(
                n,
                "skill1",
                1,
                true
            )
            ~= nil
    end

    if action == "Skill2" then
        return n == "skill2"
            or string.find(
                n,
                "skill2",
                1,
                true
            )
            ~= nil
    end

    return false
end

local function discoverCallbacks()
    Callbacks = {}

    if type(getconnections)
        ~= "function"
    then
        return
    end

    local pg =
        LocalPlayer:
            FindFirstChildOfClass(
                "PlayerGui"
            )

    if not pg then
        return
    end

    for _, obj in ipairs(
        pg:GetDescendants()
    ) do
        if obj:IsA("GuiButton") then
            for _, action in ipairs({
                "Skill1",
                "Skill2",
            }) do
                if not Callbacks[action]
                    and actionNameMatches(
                        obj,
                        action
                    )
                then
                    for _, signal in ipairs({
                        obj.Activated,
                        obj.MouseButton1Click,
                        obj.MouseButton1Down,
                    }) do
                        local ok, conns =
                            pcall(
                                getconnections,
                                signal
                            )

                        if ok then
                            for _, conn in ipairs(
                                conns
                            ) do
                                if type(
                                    conn.Function
                                ) == "function"
                                then
                                    local accept =
                                        true

                                    if debug
                                        and debug.info
                                    then
                                        local okInfo,
                                            source =
                                                pcall(
                                                    debug.info,
                                                    conn.Function,
                                                    "s"
                                                )

                                        if okInfo
                                            and type(source)
                                                == "string"
                                            and string.find(
                                                source,
                                                "ScreenInput",
                                                1,
                                                true
                                            )
                                        then
                                            accept = true
                                        end
                                    end

                                    if accept then
                                        Callbacks[action] =
                                            conn.Function

                                        break
                                    end
                                end
                            end
                        end

                        if Callbacks[action] then
                            break
                        end
                    end
                end
            end
        end
    end

    log(
        "Callbacks Skill1="
            .. tostring(
                Callbacks.Skill1 ~= nil
            )
            .. " Skill2="
            .. tostring(
                Callbacks.Skill2 ~= nil
            )
    )
end

discoverCallbacks()

local localLastCast = {
    Skill1 = -math.huge,
    Skill2 = -math.huge,
}

local fallbackCD = {
    Skill1 = 10,
    Skill2 = 12,
}

local function weaponCDObject(action)
    for _, obj in ipairs(
        Character:GetDescendants()
    ) do
        if obj:GetAttribute(
            action .. "LastTs"
        ) ~= nil
            or obj:GetAttribute(
                action .. "CD"
            ) ~= nil
        then
            return obj
        end
    end
end

local function skillReady(action)
    local obj =
        weaponCDObject(action)

    if obj then
        local readyTs =
            obj:GetAttribute(
                action .. "LastTs"
            )

        if readyTs ~= nil then
            return workspace:
                GetServerTimeNow()
                >= tonumber(readyTs)
        end
    end

    return os.clock()
        - localLastCast[action]
        >= fallbackCD[action]
end

local function castSkill(action)
    local fn =
        Callbacks[action]

    if not fn
        or not skillReady(action)
    then
        return false
    end

    -- Allow native skill visual briefly if desired; basic attack visuals
    -- remain suppressed.
    SkillCastingUntil =
        os.clock() + 0.35

    local ok, err =
        pcall(fn)

    if ok then
        localLastCast[action] =
            os.clock()

        combatLog(
            "CAST "
                .. action
        )

        return true
    end

    combatLog(
        "CAST_FAIL "
            .. action
            .. " "
            .. tostring(err)
    )

    return false
end

--========================================================--
-- HEADLESS BASIC ATTACK
--========================================================--

local AttackDriver = {
    ComboStep = 1,
    LastObservedHP = nil,
    LastDamageAt = os.clock(),
}

local function sendHeadlessAttack()
    if not PlayerActionRE then
        return false
    end

    local step =
        AttackDriver.ComboStep

    PlayerActionRE:
        FireServer(
            "SkillAction",
            "BaseAttack",
            step
        )

    AttackDriver.ComboStep =
        step >= 4
        and 1
        or step + 1

    return true
end

local function calibrateHeadless(enemy)
    if AttackDriverMode
        ~= "UNTESTED"
    then
        return
    end

    local before =
        enemyHealth(enemy)

    if not before
        or before <= 0
        or not PlayerActionRE
    then
        AttackDriverMode =
            "HEADLESS_FAILED"

        log(
            "AttackDriver=HEADLESS_FAILED (direct BaseAttack unavailable); "
                .. "Mouse1 fallback is disabled in V55.2."
        )

        return
    end

    moveNear(enemy)
    face(enemy)

    log(
        "Testing exact direct BaseAttack RF path..."
    )

    local ok =
        pcall(
            sendHeadlessAttack
        )

    if ok then
        local damaged =
            waitUntil(
                function()
                    if not enemyAlive(enemy) then
                        return true
                    end

                    local hp =
                        enemyHealth(enemy)

                    return hp
                        and hp < before
                end,
                1,
                0.02
            )

        if damaged then
            AttackDriverMode =
                "HEADLESS_REMOTE"

            AttackDriver.LastObservedHP =
                enemyHealth(enemy)

            AttackDriver.LastDamageAt =
                os.clock()

            log(
                "AttackDriver=HEADLESS_REMOTE VERIFIED"
            )

            return
        end
    end

    AttackDriverMode =
        "HEADLESS_FAILED"

    log(
        "AttackDriver=HEADLESS_FAILED; "
            .. "Mouse1 fallback is intentionally disabled."
    )
end

local HeadlessRecovery = {
    LastAt = -math.huge,
    Count = 0,
}

local function headlessRecovery(enemy)
    if os.clock()
        - HeadlessRecovery.LastAt
        < CFG.HEADLESS_RECOVERY_COOLDOWN
    then
        return
    end

    -- If the 9-stud position is the reason damage stopped, descend
    -- before retrying the direct combo.
    if CFG.ELEVATED_COMBAT
        and not Elevation.InRecovery
    then
        startElevationRecovery(
            enemy
        )
    end

    HeadlessRecovery.LastAt =
        os.clock()

    HeadlessRecovery.Count += 1

    -- Reset combo state instead of clicking Mouse1.
    AttackDriver.ComboStep = 1
    AttackDriver.LastObservedHP =
        enemyHealth(enemy)
    AttackDriver.LastDamageAt =
        os.clock()

    moveNear(enemy)
    face(enemy)

    combatLog(
        "HEADLESS_RECOVERY #"
            .. tostring(
                HeadlessRecovery.Count
            )
            .. " enemy="
            .. fullName(enemy)
    )

    -- Send a clean four-stage direct combo.
    for step = 1, 4 do
        if not enemyAlive(enemy) then
            break
        end

        AttackDriver.ComboStep =
            step

        pcall(
            sendHeadlessAttack
        )

        task.wait(0.055)
    end

    AttackDriver.ComboStep = 1
end

local function basicAttack(enemy)
    if AttackDriverMode
        == "UNTESTED"
    then
        calibrateHeadless(enemy)
    end

    if AttackDriverMode
        == "HEADLESS_REMOTE"
    then
        local old =
            AttackDriver.LastObservedHP

        local hp =
            enemyHealth(enemy)

        if old == nil
            or (
                hp
                and hp < old
            )
        then
            AttackDriver.LastDamageAt =
                os.clock()
        end

        AttackDriver.LastObservedHP =
            hp

        pcall(
            sendHeadlessAttack
        )

        -- IMPORTANT V55.2:
        -- Never switch to VirtualInputManager / Mouse1.
        if enemyAlive(enemy)
            and os.clock()
                - AttackDriver.LastDamageAt
                > CFG.HEADLESS_DAMAGE_WATCHDOG
        then
            log(
                "Headless damage watchdog -> HEADLESS_RECOVERY "
                    .. "(NO Mouse1)"
            )

            headlessRecovery(
                enemy
            )
        end

        return
    end

    -- HEADLESS_FAILED:
    -- skills may still fire, but basic attack deliberately does nothing.
    -- This keeps the diagnostic truly no-click.
end

--========================================================--
-- REGION-LOCKED EXACT DOOR SYSTEM
--
-- Ground truth from V54/V54.1:
--
-- Workspace.RoundDoor is a Folder containing MANY Door models at once.
--
-- Every physical door:
--   Door.Root.RoundNum
--   Door.Root.RE
--   Door.Root.LocalRoundDoor
--   Door.Root.E.Interact_ProximityPrompt
--
-- Exact LocalRoundDoor:
--
--   if Root.Switch ~= 1 then
--       if RoundNum < GameRound then
--           RE:FireServer()
--       end
--   end
--
-- Therefore:
--   completedRound = GameRound - 1
--
-- Multiple doors can share that RoundNum, so selection is:
--   correct RoundNum
--   + nearest to CURRENT ROOM REGION
--   + nearest to player as tiebreaker
--
-- During GATE state, combat is completely frozen.
--========================================================--

local UsedDoorRoots =
    setmetatable(
        {},
        {__mode = "k"}
    )

local function promptWorldPosition(prompt)
    if not prompt then
        return nil
    end

    local p =
        prompt.Parent

    if p:IsA("Attachment") then
        return p.WorldPosition
    elseif p:IsA("BasePart") then
        return p.Position
    end

    local attachment =
        p:
            FindFirstChildWhichIsA(
                "Attachment"
            )

    if attachment then
        return attachment.WorldPosition
    end

    local part =
        p:
            FindFirstChildWhichIsA(
                "BasePart"
            )

    if part then
        return part.Position
    end

    local ancestor =
        p:
            FindFirstAncestorWhichIsA(
                "BasePart"
            )

    return ancestor
        and ancestor.Position
end

local function physicalDoorRows()
    local folder =
        workspace:
            FindFirstChild(
                "RoundDoor"
            )

    local rows = {}

    if not folder then
        return rows
    end

    for _, root in ipairs(
        folder:GetDescendants()
    ) do
        if root:IsA("BasePart")
            and root.Name == "Root"
            and root.Parent
            and root.Parent.Name
                == "Door"
            and not UsedDoorRoots[root]
        then
            local roundNum =
                tonumber(
                    root:GetAttribute(
                        "RoundNum"
                    )
                )

            local prompt =
                root:
                    FindFirstChildWhichIsA(
                        "ProximityPrompt",
                        true
                    )

            local ppos =
                promptWorldPosition(
                    prompt
                )

            if roundNum
                and prompt
                and ppos
            then
                table.insert(
                    rows,
                    {
                        Root = root,
                        Door = root.Parent,
                        RoundNum = roundNum,
                        Prompt = prompt,
                        PromptPos = ppos,
                        Switch =
                            root:GetAttribute(
                                "Switch"
                            ),
                    }
                )
            end
        end
    end

    return rows
end

local function selectDoorForCompletedRound(
    completedRound
)
    local region =
        CurrentCombatRegion
        or ensureRegion()

    if not region
        or not Root
    then
        return nil
    end

    local candidates = {}

    for _, row in ipairs(
        physicalDoorRows()
    ) do
        if row.RoundNum
            == completedRound
            and row.Switch ~= 1
        then
            local regionDist =
                boxDistance(
                    region,
                    row.PromptPos
                )

            local playerDist =
                (
                    row.PromptPos
                    - Root.Position
                ).Magnitude

            if regionDist
                <= CFG.DOOR_REGION_MAX_DISTANCE
            then
                row.RegionDistance =
                    regionDist

                row.PlayerDistance =
                    playerDist

                table.insert(
                    candidates,
                    row
                )
            end
        end
    end

    table.sort(
        candidates,
        function(a,b)
            if math.abs(
                a.RegionDistance
                - b.RegionDistance
            ) > 0.01
            then
                return a.RegionDistance
                    < b.RegionDistance
            end

            return a.PlayerDistance
                < b.PlayerDistance
        end
    )

    if #candidates > 0 then
        local chosen =
            candidates[1]

        portalLog(
            "DOOR_SELECTED completedRound="
                .. tostring(
                    completedRound
                )
                .. " region="
                .. fullName(region)
                .. " promptPos="
                .. tostring(
                    chosen.PromptPos
                )
                .. " regionDist="
                .. string.format(
                    "%.2f",
                    chosen.RegionDistance
                )
                .. " playerDist="
                .. string.format(
                    "%.2f",
                    chosen.PlayerDistance
                )
                .. " candidates="
                .. tostring(
                    #candidates
                )
        )

        for i, row in ipairs(
            candidates
        ) do
            portalLog(
                "  CANDIDATE#"
                    .. tostring(i)
                    .. " RoundNum="
                    .. tostring(
                        row.RoundNum
                    )
                    .. " pos="
                    .. tostring(
                        row.PromptPos
                    )
                    .. " regionDist="
                    .. string.format(
                        "%.2f",
                        row.RegionDistance
                    )
                    .. " playerDist="
                    .. string.format(
                        "%.2f",
                        row.PlayerDistance
                    )
            )
        end

        return chosen
    end

    portalLog(
        "NO_DOOR completedRound="
            .. tostring(
                completedRound
            )
            .. " region="
            .. tostring(
                region
                and fullName(region)
            )
    )

    return nil
end

local function placeCharacter(
    pos,
    lookDir
)
    if not Root then
        return
    end

    local p =
        Vector3.new(
            pos.X,
            pos.Y,
            pos.Z
        )

    Root.CFrame =
        CFrame.lookAt(
            p,
            p + lookDir
        )
end

local function exactRoundDoorPortal()
    local folder =
        workspace:
            FindFirstChild(
                "RoundDoor"
            )

    local portal =
        folder
        and folder:
            FindFirstChild(
                "Portal"
            )

    local root =
        portal
        and portal:
            FindFirstChild(
                "Root"
            )

    if root
        and root:IsA(
            "BasePart"
        )
    then
        return root
    end
end

local function portalThinDirection(
    portal,
    preferred
)
    local look =
        portal.CFrame.LookVector

    look =
        Vector3.new(
            look.X,
            0,
            look.Z
        )

    if look.Magnitude < 0.1 then
        look =
            preferred
            or Root.CFrame.LookVector
    else
        look =
            look.Unit
    end

    if preferred
        and preferred.Magnitude > 0.1
    then
        local p =
            Vector3.new(
                preferred.X,
                0,
                preferred.Z
            )

        if p.Magnitude > 0.1 then
            p = p.Unit

            if look:Dot(p) < 0 then
                look = -look
            end
        end
    end

    return look
end

local function fireExactPortalTouch(
    portal
)
    if not Root
        or not portal
        or not portal.Parent
    then
        return
    end

    if type(firetouchinterest)
        == "function"
    then
        pcall(function()
            firetouchinterest(
                Root,
                portal,
                0
            )

            task.wait(0.035)

            firetouchinterest(
                Root,
                portal,
                1
            )
        end)
    end
end

local function portalTeleportEvidence(
    beforePos,
    oldRegion
)
    if settlementDetected() then
        return "SETTLEMENT"
    end

    if not Root
        or not Root.Parent
    then
        return "CHARACTER_CHANGED"
    end

    if beforePos
        and (
            Root.Position
            - beforePos
        ).Magnitude > 100
    then
        return "PORTAL_MOVED"
    end

    local region,
        dist =
            nearestWakeRegion(
                Root.Position
            )

    if region
        and oldRegion
        and region ~= oldRegion
        and dist <= 20
    then
        return region
    end
end

local function maybeEnterSectionPortal(
    oldRegion,
    outward
)
    if not Root then
        return false
    end

    local started =
        os.clock()

    local beforePos =
        Root.Position

    local attempts = 0
    local lastPortalPos = nil

    -- The exact RoundDoor.Portal can MOVE after a door opens.
    -- V55.1 checked it only once; final portal often streamed/moved later.
    while os.clock()
        - started
        < CFG.SECTION_PORTAL_APPEAR_TIMEOUT
    do
        local evidence =
            portalTeleportEvidence(
                beforePos,
                oldRegion
            )

        if evidence then
            portalLog(
                "PORTAL_EARLY_EVIDENCE "
                    .. tostring(evidence)
            )

            return true,
                evidence
        end

        local portal =
            exactRoundDoorPortal()

        if portal
            and portal.Parent
        then
            local dist =
                boxDistance(
                    portal,
                    Root.Position
                )

            local roundNum =
                tonumber(
                    portal:GetAttribute(
                        "RoundNum"
                    )
                )

            local current =
                gameRound()

            local unlocked =
                not roundNum
                or not current
                or roundNum < current

            if lastPortalPos == nil
                or (
                    portal.Position
                    - lastPortalPos
                ).Magnitude > 8
            then
                portalLog(
                    "SECTION_PORTAL_SEEN pos="
                        .. tostring(
                            portal.Position
                        )
                        .. " size="
                        .. tostring(
                            portal.Size
                        )
                        .. " boxDist="
                        .. string.format(
                            "%.2f",
                            dist
                        )
                        .. " RoundNum="
                        .. tostring(roundNum)
                        .. " GameRound="
                        .. tostring(current)
                        .. " unlocked="
                        .. tostring(unlocked)
                )

                lastPortalPos =
                    portal.Position
            end

            if unlocked
                and dist
                    <= CFG.SECTION_PORTAL_NEAR_DISTANCE
            then
                attempts += 1

                local dir =
                    portalThinDirection(
                        portal,
                        outward
                    )

                local center =
                    portal.Position

                portalLog(
                    "PORTAL_HANDSHAKE attempt="
                        .. tostring(attempts)
                        .. " center="
                        .. tostring(center)
                        .. " dir="
                        .. tostring(dir)
                        .. " boxDist="
                        .. string.format(
                            "%.2f",
                            dist
                        )
                )

                -- Enter the exact small RoundDoor.Portal volume.
                -- Unlike old versions, this is NOT a generic Workspace.Portal.
                for _, offset in ipairs({
                    -4.0,
                    -1.0,
                    0,
                    1.0,
                    3.5,
                }) do
                    local p =
                        center
                        + dir * offset

                    placeCharacter(
                        Vector3.new(
                            p.X,
                            Root.Position.Y,
                            p.Z
                        ),
                        dir
                    )

                    task.wait(0.10)

                    if boxDistance(
                        portal,
                        Root.Position
                    ) <= 2.5
                    then
                        fireExactPortalTouch(
                            portal
                        )
                    end

                    local hit =
                        portalTeleportEvidence(
                            beforePos,
                            oldRegion
                        )

                    if hit then
                        portalLog(
                            "PORTAL_HANDSHAKE success="
                                .. tostring(hit)
                                .. " attempt="
                                .. tostring(attempts)
                        )

                        return true,
                            hit
                    end
                end

                -- User observed that tiny movement while standing in the
                -- portal can make the teleport fire. Reproduce that
                -- deliberately while staying inside the exact portal.
                local touchStart =
                    os.clock()

                local sign = 1

                while os.clock()
                    - touchStart
                    < CFG.SECTION_PORTAL_TOUCH_TIMEOUT
                do
                    if not portal.Parent then
                        break
                    end

                    local p =
                        center
                        + dir
                        * (
                            sign
                            * CFG.SECTION_PORTAL_JIGGLE_STEP
                        )

                    placeCharacter(
                        Vector3.new(
                            p.X,
                            Root.Position.Y,
                            p.Z
                        ),
                        dir
                    )

                    sign = -sign

                    fireExactPortalTouch(
                        portal
                    )

                    local hit =
                        portalTeleportEvidence(
                            beforePos,
                            oldRegion
                        )

                    if hit then
                        portalLog(
                            "PORTAL_JIGGLE success="
                                .. tostring(hit)
                                .. " attempt="
                                .. tostring(attempts)
                                .. " elapsed="
                                .. string.format(
                                    "%.2f",
                                    os.clock()
                                        - touchStart
                                )
                        )

                        return true,
                            hit
                    end

                    task.wait(0.18)
                end

                -- Do not leave GATE immediately. The portal may relocate
                -- or re-arm after a short server delay.
                task.wait(0.20)
            else
                task.wait(0.12)
            end
        else
            task.wait(0.12)
        end
    end

    portalLog(
        "SECTION_PORTAL_TIMEOUT attempts="
            .. tostring(attempts)
            .. " PlayerPos="
            .. tostring(
                Root
                and Root.Position
            )
    )

    return false,
        "PORTAL_TIMEOUT"
end

local function openAndCrossSelectedDoor(
    row
)
    if not row
        or not Root
        or not row.Root.Parent
        or not row.Prompt.Parent
    then
        return false,
            "INVALID_DOOR"
    end

    local region =
        CurrentCombatRegion

    if not region then
        return false,
            "NO_REGION"
    end

    -- Freeze this exact door instance/position. NEVER refresh to a future
    -- Door after the prompt is fired.
    local frozenRoot =
        row.Root

    local frozenPrompt =
        row.Prompt

    local doorPos =
        row.PromptPos

    -- Cross along the DOOR'S NORMAL.
    --
    -- V55.1 used (doorPos - region.Position), which can point diagonally
    -- across a wide room. At the final gate that sent us toward the
    -- right side / z=-32 instead of straight through the portal.
    local outward =
        frozenRoot.CFrame.LookVector

    outward =
        Vector3.new(
            outward.X,
            0,
            outward.Z
        )

    if outward.Magnitude <= 0.1 then
        outward =
            Vector3.new(
                doorPos.X
                    - region.Position.X,
                0,
                doorPos.Z
                    - region.Position.Z
            )
    end

    if outward.Magnitude <= 0.1 then
        outward =
            Root.CFrame.LookVector
    else
        outward =
            outward.Unit
    end

    -- Choose the normal pointing AWAY from the current room.
    local fromRegion =
        Vector3.new(
            doorPos.X
                - region.Position.X,
            0,
            doorPos.Z
                - region.Position.Z
        )

    if fromRegion.Magnitude > 0.1
        and outward:
            Dot(
                fromRegion.Unit
            ) < 0
    then
        outward = -outward
    end

    portalLog(
        "DOOR_NORMAL outward="
            .. tostring(outward)
            .. " RootLook="
            .. tostring(
                frozenRoot.CFrame.LookVector
            )
    )

    local approach =
        doorPos
        - outward * 2.5

    local y =
        doorPos.Y

    placeCharacter(
        Vector3.new(
            approach.X,
            y,
            approach.Z
        ),
        outward
    )

    task.wait(0.18)

    local promptDist =
        (
            Root.Position
            - doorPos
        ).Magnitude

    portalLog(
        "DOOR_APPROACH RoundNum="
            .. tostring(
                row.RoundNum
            )
            .. " PlayerPos="
            .. tostring(
                Root.Position
            )
            .. " PromptPos="
            .. tostring(
                doorPos
            )
            .. " PromptDist="
            .. string.format(
                "%.2f",
                promptDist
            )
            .. " Max="
            .. tostring(
                frozenPrompt.MaxActivationDistance
            )
    )

    if promptDist
        > frozenPrompt.MaxActivationDistance
            + 0.75
    then
        return false,
            "PROMPT_TOO_FAR"
    end

    if type(fireproximityprompt)
        ~= "function"
    then
        return false,
            "NO_FIREPROXIMITYPROMPT"
    end

    local fired, err =
        pcall(
            fireproximityprompt,
            frozenPrompt,
            0
        )

    portalLog(
        "DOOR_PROMPT_FIRED ok="
            .. tostring(fired)
            .. " err="
            .. tostring(err)
    )

    if not fired then
        return false,
            "PROMPT_ERROR"
    end

    -- Critical authoritative verification:
    -- ServerRoundDoor should set Switch=1, which also disables prompt.
    local opened =
        waitUntil(
            function()
                if not frozenRoot.Parent then
                    return "ROOT_REMOVED"
                end

                if frozenRoot:GetAttribute(
                    "Switch"
                ) == 1
                then
                    return "SWITCH_1"
                end

                if frozenPrompt.Parent
                    and frozenPrompt.Enabled
                        == false
                then
                    return "PROMPT_DISABLED"
                end
            end,
            CFG.DOOR_OPEN_TIMEOUT,
            0.05
        )

    portalLog(
        "DOOR_OPEN_VERIFY result="
            .. tostring(opened)
            .. " Switch="
            .. tostring(
                frozenRoot.Parent
                and frozenRoot:
                    GetAttribute(
                        "Switch"
                    )
            )
            .. " PromptEnabled="
            .. tostring(
                frozenPrompt.Parent
                and frozenPrompt.Enabled
            )
    )

    if not opened then
        return false,
            "SERVER_DID_NOT_OPEN_DOOR"
    end

    UsedDoorRoots[
        frozenRoot
    ] = true

    -- Once GATE state begins, DO NOT look at enemies until this completes.
    for _, distance in ipairs({
        2,
        5,
        9,
        14,
        20,
        27,
        34,
        41,
    }) do
        if settlementDetected() then
            return true,
                "SETTLEMENT"
        end

        local p =
            doorPos
            + outward * distance

        placeCharacter(
            Vector3.new(
                p.X,
                Root.Position.Y,
                p.Z
            ),
            outward
        )

        portalLog(
            "DOOR_CROSS distance="
                .. tostring(distance)
                .. " PlayerPos="
                .. tostring(
                    Root.Position
                )
        )

        task.wait(0.14)
    end

    -- Section-ending doors have RoundDoor.Portal just beyond them.
    local portalUsed,
        portalResult =
            maybeEnterSectionPortal(
                region,
                outward
            )

    if portalUsed then
        return true,
            portalResult
    end

    -- Determine the new room only AFTER gate crossing.
    local oldRegion =
        region

    local newRegion =
        waitUntil(
            function()
                if settlementDetected() then
                    return "SETTLEMENT"
                end

                if not Root
                    or not Root.Parent
                then
                    return "CHARACTER_CHANGED"
                end

                local candidate,
                    dist =
                        nearestWakeRegion(
                            Root.Position
                        )

                if candidate
                    and candidate
                        ~= oldRegion
                    and dist <= 25
                then
                    return candidate
                end
            end,
            CFG.DOOR_CROSS_TIMEOUT,
            0.08
        )

    if typeof(newRegion)
        == "Instance"
    then
        CurrentCombatRegion =
            newRegion

        CurrentCombatRound =
            gameRound()

        portalLog(
            "NEW_REGION "
                .. fullName(
                    newRegion
                )
                .. " GameRound="
                .. tostring(
                    CurrentCombatRound
                )
        )

        return true,
            "NEW_REGION"
    end

    if newRegion
        == "SETTLEMENT"
    then
        return true,
            "SETTLEMENT"
    end

    -- Final/section portals can stream or relocate AFTER the ordinary
    -- new-region timeout. Give the exact portal one more handshake while
    -- gate ownership is still frozen.
    local retryPortal,
        retryResult =
            maybeEnterSectionPortal(
                oldRegion,
                outward
            )

    if retryPortal then
        return true,
            retryResult
    end

    -- Only after both new-region and exact-portal checks fail do we
    -- re-lock. Combat never steals control during these waits.
    lockRegion(
        "POST_DOOR_FALLBACK"
    )

    return true,
        "DOOR_CROSSED_NO_PORTAL"
end

local EggHandled =
    setmetatable(
        {},
        {__mode = "k"}
    )

local function eggCenter(egg)
    if not egg then
        return nil
    end

    if egg:IsA("BasePart") then
        return egg.Position
    end

    if egg:IsA("Model") then
        local part =
            egg.PrimaryPart
            or egg:
                FindFirstChild(
                    "HumanoidRootPart"
                )
            or egg:
                FindFirstChildWhichIsA(
                    "BasePart",
                    true
                )

        return part
            and part.Position
    end

    local part =
        egg:
            FindFirstChildWhichIsA(
                "BasePart",
                true
            )

    return part
        and part.Position
end

local function findNearbyEggPrompt()
    if not Root then
        return nil
    end

    local egg =
        workspace:
            FindFirstChild(
                "DragonEgg"
            )

    if not egg then
        return nil
    end

    local prompt =
        egg:
            FindFirstChildWhichIsA(
                "ProximityPrompt",
                true
            )

    if not prompt then
        return nil
    end

    local pos =
        promptWorldPosition(
            prompt
        )

    if not pos then
        return nil
    end

    if CurrentCombatRegion
        and not pointInExpandedPart(
            CurrentCombatRegion,
            pos,
            55
        )
    then
        return nil
    end

    local dist =
        (
            pos
            - Root.Position
        ).Magnitude

    if dist > 120 then
        return nil
    end

    return prompt,
        pos,
        dist,
        egg
end

local function interactNearbyEgg()
    local prompt,
        promptPos,
        dist,
        egg =
            findNearbyEggPrompt()

    if not prompt
        or not egg
    then
        return false
    end

    local beforeRound =
        gameRound()

    local center =
        eggCenter(egg)
        or promptPos

    -- IMPORTANT:
    -- Previous V59.x went straight to the prompt.
    -- V59.3 performs a real headless Sword combo into the DragonEgg first.
    if not EggHandled[egg] then
        EggHandled[egg] = true

        important(
            "Dragon Egg | attacking first"
        )

        local horizontal =
            Vector3.new(
                Root.Position.X
                    - center.X,
                0,
                Root.Position.Z
                    - center.Z
            )

        local dir =
            horizontal.Magnitude > 0.1
            and horizontal.Unit
            or Vector3.new(
                0,
                0,
                1
            )

        local attackPos =
            center
            + dir
                * CFG.ELEVATED_HORIZONTAL_OFFSET
            + Vector3.new(
                0,
                CFG.ELEVATED_RECOVERY_HEIGHT,
                0
            )

        Root.CFrame =
            CFrame.lookAt(
                attackPos,
                center
            )

        pcall(function()
            Root.AssemblyLinearVelocity =
                Vector3.zero

            Root.AssemblyAngularVelocity =
                Vector3.zero
        end)

        -- Two clean 4-step headless combos.
        -- No Mouse1, no visible synthetic click.
        for combo = 1, 2 do
            for step = 1, 4 do
                if not egg.Parent then
                    break
                end

                AttackDriver.ComboStep =
                    step

                pcall(
                    sendHeadlessAttack
                )

                task.wait(0.065)
            end

            if not egg.Parent then
                break
            end
        end

        AttackDriver.ComboStep = 1

        -- If attacks themselves advanced the objective, do not prompt.
        if not egg.Parent
            or (
                beforeRound
                and gameRound()
                and gameRound()
                    > beforeRound
            )
        then
            important(
                "Dragon Egg | cleared by attack"
            )

            return true
        end

        task.wait(0.08)
    end

    -- Then activate the egg normally so maps where the prompt is
    -- authoritative still progress.
    if not prompt.Parent then
        return true
    end

    local delta =
        promptPos
        - Root.Position

    local dir =
        delta.Magnitude > 0.1
        and delta.Unit
        or Root.CFrame.LookVector

    local approach =
        promptPos
        - dir * 2.5

    placeCharacter(
        Vector3.new(
            approach.X,
            promptPos.Y,
            approach.Z
        ),
        dir
    )

    task.wait(0.12)

    if type(fireproximityprompt)
        ~= "function"
    then
        important(
            "Dragon Egg | prompt API unavailable"
        )

        return false
    end

    local ok =
        pcall(
            fireproximityprompt,
            prompt,
            0
        )

    if not ok then
        important(
            "Dragon Egg | activation failed"
        )

        return false
    end

    local progressed =
        waitUntil(
            function()
                if not egg.Parent then
                    return true
                end

                local now =
                    gameRound()

                if beforeRound
                    and now
                    and now > beforeRound
                then
                    return true
                end
            end,
            2.5,
            0.06
        )

    important(
        progressed
        and "Dragon Egg | attacked + activated"
        or "Dragon Egg | attacked + activated, waiting for round"
    )

    return true
end

--========================================================--
-- DEATH RECOVERY
--========================================================--

local dead = false
local deaths = 0

local function remainLife()
    for _, obj in ipairs({
        LocalPlayer,
        Character,
        workspace,
    }) do
        if obj then
            local value =
                obj:GetAttribute(
                    "RemainLife"
                )

            if value ~= nil then
                return tonumber(value)
            end
        end
    end
end

local deathConn

local function installDeathWatcher()
    if deathConn then
        pcall(function()
            deathConn:Disconnect()
        end)
    end

    if not Humanoid then
        return
    end

    deathConn =
        Humanoid.Died:
            Connect(function()
                dead = true
                deaths += 1

                deathLog(
                    "Died count="
                        .. tostring(deaths)
                        .. " RemainLife="
                        .. tostring(
                            remainLife()
                        )
                )

                save()
            end)
end

installDeathWatcher()

local function recoverDeath()
    if not dead then
        return true
    end

    local lives =
        remainLife()

    if lives ~= nil
        and lives <= 0
    then
        return false
    end

    local old =
        Character

    local newChar =
        waitUntil(
            function()
                local c =
                    LocalPlayer.Character

                if c then
                    local h =
                        c:
                            FindFirstChildOfClass(
                                "Humanoid"
                            )

                    local r =
                        c:
                            FindFirstChild(
                                "HumanoidRootPart"
                            )

                    if h
                        and r
                        and h.Health > 0
                        and (
                            c ~= old
                            or dead
                        )
                    then
                        return c
                    end
                end
            end,
            CFG.DEATH_RESPAWN_TIMEOUT,
            0.1
        )

    if not newChar then
        return false
    end

    bindCharacter(newChar)

    dead = false

    installDeathWatcher()
    discoverCallbacks()

    deathLog(
        "Recovered RemainLife="
            .. tostring(
                remainLife()
            )
    )

    return true
end

--========================================================--
-- COMBAT
--========================================================--

local totalTargets = 0
local lastBasic =
    -math.huge

local function fightEnemy(enemy)
    if not enemyAlive(enemy) then
        return true
    end

    local fightRound =
        gameRound()

    totalTargets += 1

    if AttackDriverMode
        == "HEADLESS_REMOTE"
    then
        AttackDriver.LastObservedHP =
            enemyHealth(enemy)

        AttackDriver.LastDamageAt =
            os.clock()
    end

    combatLog(
        "TARGET "
            .. fullName(enemy)
    )

    local started =
        os.clock()

    resetElevationForNewTarget(
        enemy
    )

    while enemyAlive(enemy) do
        if settlementDetected() then
            return "SETTLEMENT"
        end

        -- GameRound is the authoritative room-clear signal.
        -- Once it advances, NEVER chase this enemy into another room.
        local nowRound =
            gameRound()

        if fightRound
            and nowRound
            and nowRound > fightRound
        then
            combatLog(
                "ROUND_ADVANCED during target "
                    .. tostring(
                        fightRound
                    )
                    .. " -> "
                    .. tostring(
                        nowRound
                    )
            )

            return "ROUND_ADVANCED"
        end

        if dead
            or (
                Humanoid
                and Humanoid.Health <= 0
            )
        then
            if not recoverDeath() then
                return "OUT_OF_LIVES"
            end

            return "REACQUIRE"
        end

        moveNear(enemy)
        face(enemy)

        trackElevationDamage(
            enemy
        )

        if Callbacks.Skill2
            and skillReady("Skill2")
        then
            if castSkill("Skill2") then
                task.wait(0.16)
            end
        elseif Callbacks.Skill1
            and skillReady("Skill1")
        then
            if castSkill("Skill1") then
                task.wait(0.13)
            end
        elseif os.clock()
                - lastBasic
                >= CFG.BASIC_INTERVAL
        then
            basicAttack(enemy)
            lastBasic =
                os.clock()
        end

        if os.clock()
            - started
            > 100
        then
            return "TARGET_TIMEOUT"
        end

        task.wait(
            CFG.COMBAT_TICK
        )
    end

    combatLog(
        "DEFEATED "
            .. fullName(enemy)
    )

    return true
end

--========================================================--
-- REGION-LOCKED ONE-DUNGEON STATE MACHINE
--========================================================--

local stopReason = nil
local portalsInvoked = 0
local startedAt = os.clock()

local state =
    "COMBAT"

local lastRound =
    gameRound()

local completedRound =
    nil

local noLocalEnemySince =
    nil

local gateRetryAt =
    0

lockRegion(
    "START"
)

log(
    "Starting REGION-LOCKED controller. GameRound="
        .. tostring(lastRound)
        .. " Region="
        .. tostring(
            CurrentCombatRegion
            and fullName(
                CurrentCombatRegion
            )
        )
)

while not stopReason do
    CurrentState = state

    local settled,
        sPath,
        sText =
            settlementDetected()

    if settled then
        settlementLog(
            "Detected path="
                .. tostring(sPath)
                .. " text="
                .. tostring(sText)
        )

        stopReason =
            "SETTLEMENT_REACHED"

        break
    end

    local nowRound =
        gameRound()

    -- AUTHORITATIVE transition:
    -- If GameRound advances, current room is done.
    if nowRound
        and lastRound
        and nowRound > lastRound
        and state ~= "GATE"
    then
        completedRound =
            nowRound - 1

        portalLog(
            "ROUND_CLEAR authoritative "
                .. tostring(lastRound)
                .. " -> "
                .. tostring(nowRound)
                .. " completedRound="
                .. tostring(
                    completedRound
                )
                .. " region="
                .. tostring(
                    CurrentCombatRegion
                    and fullName(
                        CurrentCombatRegion
                    )
                )
        )

        lastRound =
            nowRound

        state =
            "GATE"

        noLocalEnemySince =
            nil
    elseif nowRound
        and (
            not lastRound
            or nowRound > lastRound
        )
    then
        lastRound =
            nowRound
    end

    if state == "COMBAT" then
        ensureRegion()

        local enemy =
            nearestEnemy()

        if enemy then
            noLocalEnemySince =
                nil

            local result =
                fightEnemy(enemy)

            if result == "SETTLEMENT" then
                stopReason =
                    "SETTLEMENT_REACHED"

            elseif result == "OUT_OF_LIVES" then
                stopReason =
                    "OUT_OF_LIVES"

            elseif result == "TARGET_TIMEOUT" then
                stopReason =
                    "TARGET_TIMEOUT"

            elseif result == "ROUND_ADVANCED" then
                local r =
                    gameRound()

                if r then
                    completedRound =
                        r - 1

                    lastRound = r

                    state =
                        "GATE"

                    portalLog(
                        "COMBAT -> GATE from ROUND_ADVANCED completedRound="
                            .. tostring(
                                completedRound
                            )
                    )
                end
            end
        else
            if not noLocalEnemySince then
                noLocalEnemySince =
                    os.clock()
            end

            -- IMPORTANT:
            -- Global EnemyNpc is intentionally ignored here.
            -- Only current-room enemies can interrupt combat.
            local localCount =
                #localLiveEnemies()

            if localCount == 0
                and os.clock()
                    - noLocalEnemySince
                    >= CFG.NO_ENEMY_STABLE_TIME
            then
                -- DragonEgg may be the current-room continuation.
                if interactNearbyEgg() then
                    noLocalEnemySince =
                        os.clock()

                    task.wait(0.35)
                else
                    task.wait(0.08)
                end
            else
                task.wait(0.06)
            end
        end

    elseif state == "GATE" then
        -- NON-INTERRUPTIBLE STATE.
        -- Do not inspect or chase ANY enemies here.

        if not completedRound then
            completedRound =
                (gameRound() or 1) - 1
        end

        if os.clock()
            >= gateRetryAt
        then
            local row =
                selectDoorForCompletedRound(
                    completedRound
                )

            if row then
                local ok,
                    result =
                        openAndCrossSelectedDoor(
                            row
                        )

                portalLog(
                    "GATE_RESULT ok="
                        .. tostring(ok)
                        .. " result="
                        .. tostring(result)
                )

                if ok then
                    portalsInvoked += 1

                    if result
                        == "SETTLEMENT"
                    then
                        stopReason =
                            "SETTLEMENT_REACHED"
                    else
                        state =
                            "COMBAT"

                        CurrentState =
                            state

                        lockRegion(
                            "AFTER_GATE"
                        )

                        CurrentCombatRound =
                            gameRound()

                        lastRound =
                            gameRound()
                            or lastRound

                        completedRound =
                            nil

                        noLocalEnemySince =
                            nil

                        task.wait(0.45)
                    end
                else
                    -- Keep gate ownership. Never fall back to combat just
                    -- because distant/global enemies exist.
                    gateRetryAt =
                        os.clock() + 0.6

                    task.wait(0.10)
                end
            else
                -- Door may stream in a moment. Stay in GATE.
                gateRetryAt =
                    os.clock() + 0.5

                task.wait(0.10)
            end
        else
            task.wait(0.06)
        end
    end

    if os.clock()
        - startedAt
        > CFG.GLOBAL_TIMEOUT
    then
        stopReason =
            "GLOBAL_TIMEOUT"
    end

    save()
end

--========================================================--
-- SMART SETTLEMENT / REPLAY / LOBBY V59
--
-- The farm does NOT return to Lobby after every win.
--
-- Direct Play Again is used when:
--   * the post-run planner still chooses the SAME stage
--   * no important Lobby maintenance is pending
--   * direct replay count is below the maintenance limit
--
-- Lobby is used when:
--   * next Story stage becomes ready
--   * attributes should be spent
--   * inventory is high
--   * replay maintenance limit is reached
--   * dungeon failed / timed out / out of lives
--
-- Combat remains NO-Mouse1.
-- Play Again uses the exact GameRoundRE server route recovered from
-- ScreenSettlement. No settlement UI click is required.
--========================================================--

local LOBBY_PLACE_ID =
    117533937949084

local Config =
    getgenv().IronSoulConfig
    or {}

local MAX_DIRECT_REPEATS =
    6

local ATTACK_SOFT_CAP =
    15

local INVENTORY_CLEAN_AT =
    85

local JOURNAL_FILE =
    "IronSoul_Kaitun_Journal_V59.txt"

local queueBootstrap =
    getgenv().IronSoulQueueBootstrap

local BASE =
    getgenv().IronSoulBaseURL
    or (
        "https://raw.githubusercontent.com/"
        .. "MUshihara/ironsoulkaitun/main/"
    )

local function readJournal()
    local out = {}

    if type(readfile)
            ~= "function"
        or type(isfile)
            == "function"
            and not isfile(
                JOURNAL_FILE
            )
    then
        return out
    end

    local ok, text =
        pcall(
            readfile,
            JOURNAL_FILE
        )

    if not ok
        or type(text)
            ~= "string"
    then
        return out
    end

    for line in string.gmatch(
        text,
        "[^\r\n]+"
    ) do
        local k, v =
            string.match(
                line,
                "^([^=]+)=(.*)$"
            )

        if k then
            out[k] = v
        end
    end

    return out
end

local function writeJournal(data)
    if type(writefile)
        ~= "function"
    then
        return false
    end

    local keys = {}

    for k in pairs(data) do
        table.insert(keys, k)
    end

    table.sort(keys)

    local lines = {}

    for _, k in ipairs(keys) do
        table.insert(
            lines,
            tostring(k)
                .. "="
                .. tostring(data[k])
        )
    end

    return pcall(
        writefile,
        JOURNAL_FILE,
        table.concat(
            lines,
            "\n"
        )
    )
end

local function num(v)
    return tonumber(v) or 0
end

local function inventoryCountNow()
    local d = pdata()

    local owned =
        d
        and d.Equipment
        and d.Equipment.Owned
        or {}

    local n = 0

    for _ in pairs(owned) do
        n += 1
    end

    return n
end

local function equipmentPowerReplay(uuid)
    if not uuid
        or not EquipmentUtilReplay
        or type(
            EquipmentUtilReplay.GetEquipmentPowerByUUID
        ) ~= "function"
    then
        return 0
    end

    local ok, value =
        pcall(function()
            return EquipmentUtilReplay:
                GetEquipmentPowerByUUID(
                    LocalPlayer,
                    uuid
                )
        end)

    return ok
        and num(value)
        or 0
end

local function equipmentBaseReplay(uuid)
    if not uuid
        or not EquipmentCombatReplay
        or type(
            EquipmentCombatReplay.GetDmgOrHp
        ) ~= "function"
    then
        return 0
    end

    local ok, value =
        pcall(function()
            return EquipmentCombatReplay:
                GetDmgOrHp(
                    LocalPlayer,
                    uuid
                )
        end)

    return ok
        and num(value)
        or 0
end

local function betterEquipmentWaiting()
    local d = pdata()

    local equipment =
        d
        and d.Equipment

    if type(equipment)
        ~= "table"
    then
        return false
    end

    local owned =
        equipment.Owned
        or {}

    local slots =
        equipment.EquipSlots
        or {}

    local active =
        equipment.CurWeaponSlot
        or "Weapon"

    local equippedWeapon =
        slots[active]

    local equippedSwordBase =
        equipmentBaseReplay(
            equippedWeapon
        )

    local equippedSwordPower =
        equipmentPowerReplay(
            equippedWeapon
        )

    local bestSwordBase =
        equippedSwordBase

    local bestSwordPower =
        equippedSwordPower

    for uuid, item in pairs(owned) do
        if type(item) == "table"
            and item.Type == "Weapon"
            and item.Class == "Sword"
        then
            local base =
                equipmentBaseReplay(
                    uuid
                )

            local pwr =
                equipmentPowerReplay(
                    uuid
                )

            if base > bestSwordBase
                or (
                    base == bestSwordBase
                    and pwr > bestSwordPower
                )
            then
                bestSwordBase = base
                bestSwordPower = pwr
            end
        end
    end

    if bestSwordBase
            > equippedSwordBase
        or (
            bestSwordBase
                == equippedSwordBase
            and bestSwordPower
                > equippedSwordPower
        )
    then
        return true,
            "BETTER_SWORD"
    end

    for _, armorClass in ipairs({
        "Helmet",
        "Breastplate",
    }) do
        local equipped =
            slots[armorClass]

        local equippedPower =
            equipmentPowerReplay(
                equipped
            )

        local bestPower =
            equippedPower

        for uuid, item in pairs(owned) do
            if type(item) == "table"
                and item.Type == "Armor"
                and item.Class
                    == armorClass
            then
                local pwr =
                    equipmentPowerReplay(
                        uuid
                    )

                if pwr > bestPower then
                    bestPower = pwr
                end
            end
        end

        if bestPower
            > equippedPower
        then
            return true,
                "BETTER_"
                .. string.upper(
                    armorClass
                )
        end
    end

    return false
end

local function lobbyMaintenanceNeeded()
    local d = pdata()

    if not d then
        return false,
            "NO_DATA"
    end

    local attr =
        d.AttributeUpgrade
        or {}

    local levels =
        attr.AttributeLvs
        or {}

    local points =
        num(
            attr.RemainingPoint
        )

    local attackLv =
        num(
            levels.AtkBonusValue
        )

    if points > 0
        and attackLv
            < ATTACK_SOFT_CAP
    then
        return true,
            "ATTRIBUTE_POINTS"
    end

    if inventoryCountNow()
        >= INVENTORY_CLEAN_AT
    then
        return true,
            "INVENTORY_HIGH"
    end

    local better,
        betterReason =
            betterEquipmentWaiting()

    if better then
        return true,
            betterReason
    end

    return false,
        "NONE"
end


local ResWorldRound =
    req("ResWorldRound")

local WorldUtil =
    req("WorldUtil")

local EquipmentUtilReplay =
    req("EquipmentUtil")

local EquipmentCombatReplay =
    req("EquipmentCombat")

local STORY_ORDER = {
    World1 = 1,
    World2 = 2,
    World3 = 3,
    World4 = 4,
}

local function buildStoryRounds()
    local rounds = {}

    if type(ResWorldRound)
        ~= "table"
    then
        return rounds
    end

    local function addCfg(cfg)
        if type(cfg)
                == "table"
            and cfg.WorldId
            and cfg.DiffLevel
            and STORY_ORDER[
                cfg.WorldId
            ]
            and cfg.Style
                == "Normal"
        then
            table.insert(
                rounds,
                cfg
            )
        end
    end

    if type(
        ResWorldRound.__index
    ) == "table"
    then
        for _, key in ipairs(
            ResWorldRound.__index
        ) do
            addCfg(
                ResWorldRound[key]
            )
        end
    else
        for _, cfg in pairs(
            ResWorldRound
        ) do
            addCfg(cfg)
        end
    end

    table.sort(
        rounds,
        function(a,b)
            local aw =
                STORY_ORDER[
                    a.WorldId
                ]
                or 999

            local bw =
                STORY_ORDER[
                    b.WorldId
                ]
                or 999

            if aw ~= bw then
                return aw < bw
            end

            return num(
                a.DiffLevel
            ) < num(
                b.DiffLevel
            )
        end
    )

    return rounds
end

local function clearData()
    if WorldUtil
        and type(
            WorldUtil.GetClearData
        ) == "function"
    then
        local ok, value =
            pcall(function()
                return WorldUtil:
                    GetClearData(
                        LocalPlayer
                    )
            end)

        if ok
            and type(value)
                == "table"
        then
            return value
        end
    end

    local d = pdata()

    return d
        and d.Worlds
        and d.Worlds.ClearWolrds
        or {}
end

local function isCleared(
    worldId,
    diff
)
    local clear =
        clearData()

    return clear[worldId]
        and clear[worldId][
            "Diff_"
            .. tostring(diff)
        ] ~= nil
end

local function isUnlocked(
    worldId,
    diff
)
    if not WorldUtil
        or type(
            WorldUtil.IsUnlockWorld
        ) ~= "function"
    then
        return false
    end

    local ok, value =
        pcall(function()
            return WorldUtil:
                IsUnlockWorld(
                    LocalPlayer,
                    worldId,
                    diff
                )
        end)

    return ok
        and value == true
end

local function postRunPlan()
    local rounds =
        buildStoryRounds()

    local nextStory = nil
    local highestCleared = nil

    for _, cfg in ipairs(rounds) do
        if isCleared(
            cfg.WorldId,
            cfg.DiffLevel
        )
        then
            highestCleared = cfg

        elseif not nextStory
            and isUnlocked(
                cfg.WorldId,
                cfg.DiffLevel
            )
        then
            nextStory = cfg
        end
    end

    local lv =
        num(
            LocalPlayer:
                GetAttribute(
                    "LG_Level"
                )
        )

    local pwr =
        num(
            LocalPlayer:
                GetAttribute(
                    "LG_PowerNew1"
                )
        )

    if nextStory then
        local recLv =
            num(
                nextStory.RecPlayerLv
            )

        local recPower =
            num(
                nextStory.RecBattlePower
            )

        if lv >= recLv
            and pwr >= recPower
        then
            return {
                Decision =
                    "ADVANCE_STORY",
                Target =
                    nextStory,
                Level = lv,
                Power = pwr,
            }
        end
    end

    if highestCleared then
        return {
            Decision =
                "REPEAT_STORY",
            Target =
                highestCleared,
            Level = lv,
            Power = pwr,
        }
    end

    return {
        Decision = "LOBBY",
        Target = nil,
        Level = lv,
        Power = pwr,
    }
end

local function queueNext(reason)
    if type(queueBootstrap)
        == "function"
    then
        return queueBootstrap(
            reason
        )
    end

    local queue =
        queue_on_teleport
        or (
            syn
            and syn.queue_on_teleport
        )

    if type(queue)
        ~= "function"
    then
        return false
    end

    local payload =
        "task.wait(1.35);"
        .. "loadstring(game:HttpGet("
        .. string.format(
            "%q",
            BASE
                .. "bootstrap.lua"
        )
        .. "))()"

    local ok =
        pcall(
            queue,
            payload
        )

    return ok
end

local function directLobby(reason)
    important(
        "Lobby | "
            .. tostring(reason)
    )

    settlementLog(
        "RETURN_LOBBY reason="
            .. tostring(reason)
    )

    queueNext(
        "dungeon -> lobby: "
            .. tostring(reason)
    )

    task.wait(0.20)

    local remote =
        WorldUtil
        and WorldUtil.RemoteEvent

    if remote then
        local before =
            LocalPlayer:
                GetAttribute(
                    "IsTeleporting"
                )

        local sent, err =
            pcall(function()
                -- Exact native Return-to-Lobby route recovered from
                -- ScreenSettlement:
                -- WorldUtil.RemoteEvent:FireServer("BackLobby")
                remote:
                    FireServer(
                        "BackLobby"
                    )
            end)

        settlementLog(
            "BACK_LOBBY_REMOTE sent="
                .. tostring(sent)
                .. " err="
                .. tostring(err)
                .. " before="
                .. tostring(before)
        )

        if sent then
            local started =
                waitUntil(
                    function()
                        local target =
                            LocalPlayer:
                                GetAttribute(
                                    "IsTeleporting"
                                )

                        if target ~= nil
                            and target ~= false
                        then
                            return target
                        end
                    end,
                    5,
                    0.10
                )

            if started then
                settlementLog(
                    "BACK_LOBBY_REMOTE teleport="
                        .. tostring(started)
                )

                return true
            end
        end
    end

    -- Hard safety fallback only.
    settlementLog(
        "BACK_LOBBY_REMOTE did not confirm; "
            .. "TeleportService fallback."
    )

    local ok, err =
        pcall(function()
            TeleportService:
                Teleport(
                    LOBBY_PLACE_ID,
                    LocalPlayer
                )
        end)

    settlementLog(
        "LOBBY_TELEPORT_FALLBACK ok="
            .. tostring(ok)
            .. " err="
            .. tostring(err)
    )

    return ok
end


local function findNativePlayAgainButton()
    local pg =
        LocalPlayer:
            FindFirstChildOfClass(
                "PlayerGui"
            )

    local result =
        pg
        and pg:
            FindFirstChild(
                "ResultGui"
            )

    local screen =
        result
        and result:
            FindFirstChild(
                "ScreenSettlement"
            )

    local group =
        screen
        and screen:
            FindFirstChild(
                "BtnGroup"
            )

    return group
        and group:
            FindFirstChild(
                "PlayAgainBtn"
            )
end

local function fireNativePlayAgainCallback()
    local button =
        findNativePlayAgainButton()

    if not button then
        return false,
            "NO_PLAY_AGAIN_BUTTON"
    end

    -- Diagnostic proved the real game callback is attached specifically to
    -- MouseButton1Down. Execute the game's callback directly: no VIM mouse.
    if type(getconnections)
        == "function"
    then
        local ok, conns =
            pcall(
                getconnections,
                button.MouseButton1Down
            )

        if ok then
            for _, conn in ipairs(conns) do
                local fn =
                    conn.Function

                if type(fn)
                    == "function"
                then
                    local source = ""

                    if debug
                        and debug.info
                    then
                        pcall(function()
                            source =
                                tostring(
                                    debug.info(
                                        fn,
                                        "s"
                                    )
                                )
                        end)
                    end

                    if string.find(
                        source,
                        "ScreenSettlement",
                        1,
                        true
                    )
                    then
                        local callOk,
                            callErr =
                                pcall(fn)

                        return callOk,
                            callOk
                            and "GAME_CALLBACK"
                            or tostring(
                                callErr
                            )
                    end
                end
            end
        end
    end

    if type(firesignal)
        == "function"
    then
        local ok, err =
            pcall(
                firesignal,
                button.MouseButton1Down
            )

        if ok then
            return true,
                "FIRESIGNAL_MOUSEDOWN"
        end

        return false,
            tostring(err)
    end

    return false,
        "NO_CALLBACK_ROUTE"
end

local function attemptDirectReplay(
    journal,
    postPlan
)
    local directRepeats =
        num(
            journal.DirectRepeats
        )

    local failures =
        num(
            journal.FailureCount
        )

    writeJournal({
        State = "REPLAYING",
        Decision =
            postPlan.Decision,
        World =
            journal.World,
        Diff =
            journal.Diff,
        DirectRepeats =
            directRepeats + 1,
        FailureCount =
            failures,
        FailPower =
            journal.FailPower
            or 0,
        Level =
            postPlan.Level,
        Power =
            postPlan.Power,
        UpdatedAt =
            os.time(),
    })

    queueNext(
        "native Play Again callback"
    )

    local oldRound =
        gameRound()

    local teleported =
        false

    local conn =
        LocalPlayer.OnTeleport:
            Connect(function()
                teleported = true
            end)

    important(
        "Victory | replaying same stage"
    )

    local sent,
        route =
            fireNativePlayAgainCallback()

    -- Last fallback: exact remote learned from settlement code.
    if not sent then
        local remotes =
            ReplicatedStorage:
                FindFirstChild(
                    "Remotes"
                )

        local gameRoundRE =
            remotes
            and remotes:
                FindFirstChild(
                    "GameRoundRE"
                )

        if gameRoundRE
            and gameRoundRE:IsA(
                "RemoteEvent"
            )
        then
            sent =
                pcall(function()
                    gameRoundRE:
                        FireServer(
                            "VotePlayAgain"
                        )
                end)

            route =
                "REMOTE_FALLBACK"
        end
    end

    if not sent then
        pcall(function()
            conn:Disconnect()
        end)

        important(
            "Replay failed | returning Lobby"
        )

        return false,
            route
    end

    local deadline =
        os.clock() + 12

    while os.clock()
        < deadline
    do
        local teleportAttr =
            LocalPlayer:
                GetAttribute(
                    "IsTeleporting"
                )

        if teleported
            or (
                teleportAttr ~= nil
                and teleportAttr ~= false
            )
        then
            pcall(function()
                conn:Disconnect()
            end)

            important(
                "Replay | next run starting"
            )

            return true,
                "TELEPORT"
        end

        local settled =
            settlementDetected()

        local nowRound =
            gameRound()

        if not settled
            and (
                nowRound == nil
                or nowRound <= 1
                or (
                    oldRound
                    and nowRound < oldRound
                )
            )
        then
            pcall(function()
                conn:Disconnect()
            end)

            important(
                "Replay | same-server reset"
            )

            task.defer(function()
                task.wait(0.8)

                local loader =
                    getgenv().IronSoulLoadRaw

                if type(loader)
                    == "function"
                then
                    loader(
                        "systems/combat.lua"
                    )
                end
            end)

            return true,
                "SAME_PLACE"
        end

        task.wait(0.10)
    end

    pcall(function()
        conn:Disconnect()
    end)

    important(
        "Replay timeout | returning Lobby"
    )

    return false,
        "REPLAY_TIMEOUT"
end

--========================================================--
-- FINAL CHECKPOINT
--========================================================--

log(
    "FINAL stopReason="
        .. tostring(stopReason)
)

log(
    "AttackDriver="
        .. tostring(
            AttackDriverMode
        )
        .. " MouseBasicUsed=false"
        .. " HeadlessRecoveries="
        .. tostring(
            HeadlessRecovery.Count
        )
)

log(
    "Elevation NormalHeight="
        .. tostring(
            Elevation.NormalHeight
        )
        .. " RecoveryHeight="
        .. tostring(
            Elevation.RecoveryHeight
        )
        .. " RecoveryCount="
        .. tostring(
            Elevation.RecoveryCount
        )
        .. " FinalActiveHeight="
        .. tostring(
            Elevation.ActiveHeight
        )
)

log(
    "targets="
        .. tostring(totalTargets)
        .. " portalsInvoked="
        .. tostring(portalsInvoked)
        .. " deaths="
        .. tostring(deaths)
        .. " elapsed="
        .. string.format(
            "%.2f",
            os.clock()
                - startedAt
        )
)

important(
    "Victory | "
        .. tostring(totalTargets)
        .. " targets | "
        .. tostring(deaths)
        .. " deaths | "
        .. string.format(
            "%.1fs",
            os.clock()
                - startedAt
        )
)

save()

local journal =
    readJournal()

if stopReason
    ~= "SETTLEMENT_REACHED"
then
    local failures =
        num(
            journal.FailureCount
        ) + 1

    writeJournal({
        State = "FAILED",
        Decision =
            journal.Decision
            or "RECOVERY",
        World =
            journal.World
            or "?",
        Diff =
            journal.Diff
            or "?",
        DirectRepeats =
            journal.DirectRepeats
            or 0,
        FailureCount =
            failures,
        FailPower =
            LocalPlayer:
                GetAttribute(
                    "LG_PowerNew1"
                )
            or 0,
        Level =
            LocalPlayer:
                GetAttribute(
                    "LG_Level"
                )
            or 0,
        Power =
            LocalPlayer:
                GetAttribute(
                    "LG_PowerNew1"
                )
            or 0,
        UpdatedAt =
            os.time(),
    })

    directLobby(
        "COMBAT_FAILURE_"
            .. tostring(
                stopReason
            )
    )

    return
end

-- Let settlement rewards / clear state replicate.
task.wait(1.25)

local post =
    postRunPlan()

local maintenance,
    maintenanceReason =
        lobbyMaintenanceNeeded()

local currentWorld =
    tostring(
        journal.World
        or ""
    )

local currentDiff =
    num(
        journal.Diff
    )

local sameTarget =
    post.Target
        ~= nil
    and tostring(
        post.Target.WorldId
    ) == currentWorld
    and num(
        post.Target.DiffLevel
    ) == currentDiff

local repeats =
    num(
        journal.DirectRepeats
    )

settlementLog(
    "POST_PLAN decision="
        .. tostring(
            post.Decision
        )
        .. " target="
        .. tostring(
            post.Target
            and post.Target.WorldId
        )
        .. " Diff="
        .. tostring(
            post.Target
            and post.Target.DiffLevel
        )
        .. " Level="
        .. tostring(
            post.Level
        )
        .. " Power="
        .. tostring(
            post.Power
        )
        .. " sameTarget="
        .. tostring(
            sameTarget
        )
        .. " DirectRepeats="
        .. tostring(repeats)
        .. " Maintenance="
        .. tostring(
            maintenance
        )
        .. ":"
        .. tostring(
            maintenanceReason
        )
)

local canDirectReplay =
    sameTarget
    and post.Decision
        == "REPEAT_STORY"
    and not maintenance
    and repeats
        < MAX_DIRECT_REPEATS

if canDirectReplay then
    local replayOk,
        replayResult =
            attemptDirectReplay(
                journal,
                post
            )

    settlementLog(
        "DIRECT_REPLAY ok="
            .. tostring(replayOk)
            .. " result="
            .. tostring(
                replayResult
            )
    )

    save()

    if replayOk then
        return
    end

    directLobby(
        "REPLAY_FAILED_"
            .. tostring(
                replayResult
            )
    )

    return
end

local reason

if not sameTarget then
    reason =
        "STAGE_CHANGE"
elseif post.Decision
    == "ADVANCE_STORY"
then
    reason =
        "ADVANCE_READY"
elseif maintenance then
    reason =
        "MAINTENANCE_"
        .. tostring(
            maintenanceReason
        )
elseif repeats
    >= MAX_DIRECT_REPEATS
then
    reason =
        "PERIODIC_MAINTENANCE"
else
    reason =
        "PLANNER_LOBBY"
end

writeJournal({
    State = "RETURNING_LOBBY",
    Decision =
        post.Decision,
    World =
        post.Target
        and post.Target.WorldId
        or currentWorld,
    Diff =
        post.Target
        and post.Target.DiffLevel
        or currentDiff,
    DirectRepeats = 0,
    FailureCount =
        journal.FailureCount
        or 0,
    FailPower =
        journal.FailPower
        or 0,
    Level =
        post.Level,
    Power =
        post.Power,
    UpdatedAt =
        os.time(),
})

directLobby(reason)
