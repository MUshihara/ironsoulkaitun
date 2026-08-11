--========================================================--
-- IRON SOUL - FAST PORTAL + SURVIVAL COMBAT V61.4
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

    -- V60.1 adaptive phase resolver.
    -- Old exact door logic remains first-class, but a cleared room can now
    -- discover and verify a different portal/gate structure.
    ADAPTIVE_FAST_VERIFY = 0.85,
    ADAPTIVE_STUCK_TIME = 2.25,
    ADAPTIVE_RETRY_COOLDOWN = 2.0,
    ADAPTIVE_MAX_DISTANCE = 450,

    -- Some section portals land in a transition-only staging area rather
    -- than directly inside a RoundWakeTouch combat room.
    STAGING_REGION_DISTANCE = 32,
    STAGING_IDLE_TIME = 5.5,
    STAGING_RETRY_COOLDOWN = 2.5,

    -- If the room-volume lock is stale after a section teleport, nearby
    -- real enemies must win over any portal/gate logic.
    SPATIAL_ENEMY_RADIUS = 240,

    -- Physical gate frontier:
    -- server-openable nearby doors must be consumed before any portal.
    FRONTIER_DOOR_PLAYER_MAX = 170,
    FRONTIER_DOOR_REGION_MAX = 115,
    FRONTIER_EXACT_BONUS = 22,
    FRONTIER_ROUND_GAP_PENALTY = 14,

    -- Empty traversal corridors appear after side/section stages.
    EMPTY_TRAVERSAL_IDLE = 2.25,
    EMPTY_TRAVERSAL_RETRY = 0.65,

    -- Compact rolling telemetry.
    TELEMETRY_HEARTBEAT = 2.0,
    TELEMETRY_STALL_AFTER = 7.0,
    TELEMETRY_FULL_EVERY = 6.0,

    -- GATE recovery:
    -- If the expected completed-round gate is ALREADY server-open, and
    -- real next-room enemies have spawned nearby, combat wins immediately.
    GATE_OPEN_NEAR_DISTANCE = 45,
    GATE_ENEMY_RECOVERY_RADIUS = 190,
    GATE_NO_EXPECTED_ENEMY_RADIUS = 120,

    -- Already-open expected gate recovery.
    OPEN_GATE_CROSS_DISTANCE = 14,
    OPEN_GATE_CROSS_SUCCESS = 6,
    OPEN_GATE_CROSS_TIMEOUT = 2.2,
    OPEN_GATE_REISSUE = 0.16,

    -- Evidence-driven gate timing. Old builds could spend ~30 sec at an
    -- ordinary gate waiting for a section portal that did not exist.
    DOOR_FAST_PROGRESS_CHECK = 1.35,
    DOOR_SECTION_PORTAL_WAIT = 3.50,
    DOOR_NEW_REGION_WAIT = 2.25,
    DOOR_SECTION_PORTAL_RETRY_WAIT = 3.50,

    -- Some transition triggers require genuine Humanoid movement.
    -- CFrame/touch alone can leave the character frozen at the checkpoint.
    NATIVE_MOTION_PULSE = true,
    NATIVE_MOTION_STEP_TIME = 0.11,
    NATIVE_MOTION_SETTLE = 0.10,
    NATIVE_MOTION_MAX_DIRECTIONS = 4,
    NATIVE_MOTION_MOVETO_FALLBACK = 2.0,

    -- V61.2 guided transition walking.
    GUIDED_WALK = true,
    GUIDED_WALK_MAX_TIME = 8.0,
    GUIDED_WALK_REISSUE = 0.22,
    GUIDED_WALK_PROGRESS_LOG = 1.0,
    GUIDED_WALK_STALL_TIME = 1.6,
    GUIDED_WALK_MIN_PROGRESS = 1.0,
    GUIDED_WALK_TARGET_RADIUS = 7.0,
    GUIDED_WALK_ONLY_OUTSIDE_REGION = 38,

    -- Once the exact current-1 portal is confidently identified, there is
    -- no reason to walk hundreds of studs. Snap near it, then use REAL
    -- Humanoid movement for the final touch/trigger distance.
    FAST_PORTAL_APPROACH = true,
    FAST_PORTAL_MIN_DISTANCE = 28,
    FAST_PORTAL_MAX_DISTANCE = 900,
    FAST_PORTAL_PRE_DISTANCE = 10,
    FAST_PORTAL_CROSS_DISTANCE = 12,
    FAST_PORTAL_SETTLE = 0.12,
    FAST_PORTAL_VERIFY = 1.55,

    -- Adaptive combat position.
    ADAPTIVE_COMBAT_POSITION = true,
    ADAPTIVE_PLAYER_HIT_EPSILON = 0.25,
    ADAPTIVE_EVADE_HOLD = 2.25,
    ADAPTIVE_REPEAT_HIT_WINDOW = 3.0,
    ADAPTIVE_NO_TARGET_DAMAGE = 1.65,
    ADAPTIVE_RETURN_STABLE = 0.65,

    ADAPTIVE_DEFAULT_HEIGHT = 9.0,
    ADAPTIVE_DEFAULT_OFFSET = 1.50,

    ADAPTIVE_EVADE_HEIGHT = 8.5,
    ADAPTIVE_EVADE_OFFSET = 4.0,
    ADAPTIVE_EVADE_YAW = 82,

    ADAPTIVE_WIDE_HEIGHT = 7.0,
    ADAPTIVE_WIDE_OFFSET = 5.0,
    ADAPTIVE_WIDE_YAW = 118,

    -- Verified close-recovery position when our hits are not registering.
    ADAPTIVE_RECOVERY_HEIGHT = 5.5,
    ADAPTIVE_RECOVERY_OFFSET = 1.0,

    -- Boss / survival movement. Attacks continue during every profile.
    ADAPTIVE_BOSS_HP = 1500,
    ADAPTIVE_BOSS_HEIGHT = 9.0,
    ADAPTIVE_BOSS_OFFSET = 3.0,
    ADAPTIVE_BOSS_ORBIT_SPEED = 62,

    ADAPTIVE_EVADE_ORBIT_SPEED = 105,
    ADAPTIVE_WIDE_ORBIT_SPEED = 135,

    ADAPTIVE_LOW_HP_RATIO = 0.40,
    ADAPTIVE_LOW_HP_HEIGHT = 8.0,
    ADAPTIVE_LOW_HP_OFFSET = 5.0,
    ADAPTIVE_LOW_HP_ORBIT_SPEED = 145,

    ADAPTIVE_KNOCK_EVADE_HOLD = 1.50,
    ADAPTIVE_KNOCK_HEIGHT = 8.0,
    ADAPTIVE_KNOCK_OFFSET = 5.5,
    ADAPTIVE_KNOCK_ORBIT_SPEED = 150,

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
    "IronSoul_ModularAdaptiveCombat_V60_2R"

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

--========================================================--
-- SOLO SESSION GUARD
--
-- V59.4's same-PlaceId fallback could join a random public dungeon.
-- The kaitun is designed around a solo room. If we ever arrive with
-- more than one participant, do not try to take over that shared run.
-- Return to Lobby once and let the normal Lobby brain create MaxCount=1.
--========================================================--

do
    local playersCount =
        GameRoundCfg
        and tonumber(
            GameRoundCfg:
                GetAttribute(
                    "PlayersCount"
                )
        )
        or 0

    if playersCount > 1 then
        important(
            "Unexpected multiplayer | rebuilding solo room"
        )

        local queueBootstrap =
            getgenv().IronSoulQueueBootstrap

        if type(queueBootstrap)
            == "function"
        then
            queueBootstrap(
                "unexpected multiplayer -> solo lobby"
            )
        end

        local EarlyWorldUtil =
            req("WorldUtil")

        local sent = false

        if EarlyWorldUtil
            and EarlyWorldUtil.RemoteEvent
        then
            sent =
                pcall(function()
                    EarlyWorldUtil.RemoteEvent:
                        FireServer(
                            "BackLobby"
                        )
                end)
        end

        if sent then
            local deadline =
                os.clock() + 6

            while os.clock()
                < deadline
            do
                local target =
                    LocalPlayer:
                        GetAttribute(
                            "IsTeleporting"
                        )

                if target ~= nil
                    and target ~= false
                then
                    return
                end

                task.wait(0.10)
            end
        end

        -- Last-resort cleanup for an already contaminated public run.
        pcall(function()
            TeleportService:
                Teleport(
                    117533937949084,
                    LocalPlayer
                )
        end)

        return
    end
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

local function nearestSpatialEnemy(
    radius
)
    if not Root then
        return nil,
            math.huge
    end

    radius =
        tonumber(radius)
        or CFG.SPATIAL_ENEMY_RADIUS

    local best = nil
    local bestDist =
        math.huge

    for _, enemy in ipairs(
        liveEnemies()
    ) do
        local eroot =
            modelRoot(enemy)

        if eroot then
            local dist =
                (
                    eroot.Position
                    - Root.Position
                ).Magnitude

            if dist < bestDist
                and dist <= radius
            then
                best = enemy
                bestDist = dist
            end
        end
    end

    return best,
        bestDist
end

getgenv().IronSoulLockRegionToEnemy =
    function(enemy, reason)
        if not enemy then
            return nil
        end

        local eroot =
            modelRoot(enemy)

        if not eroot then
            return nil
        end

        local region,
            dist =
                nearestWakeRegion(
                    eroot.Position
                )

        if region then
            CurrentCombatRegion =
                region

            CurrentCombatRound =
                gameRound()

            getgenv().IronSoulNavTrace(
                "ENEMY_REGION_LOCK reason="
                    .. tostring(reason)
                    .. " enemy="
                    .. tostring(
                        enemy.Name
                    )
                    .. " region="
                    .. fullName(region)
                    .. " enemyRegionDist="
                    .. string.format(
                        "%.1f",
                        dist
                    )
            )

            if getgenv().IronSoulTelemetry then
                getgenv().IronSoulTelemetry:
                    Event(
                        "ENEMY_REGION_LOCK",
                        "reason="
                            .. tostring(reason)
                            .. " enemy="
                            .. tostring(
                                enemy.Name
                            )
                            .. " region="
                            .. fullName(region)
                            .. " dist="
                            .. string.format(
                                "%.1f",
                                dist
                            )
                    )
            end
        end

        return region,
            dist
    end

getgenv().IronSoulExpectedGateStatus =
    function(expectedRound)
        if not Root
            or expectedRound == nil
        then
            return nil,
                nil
        end

        local folder =
            workspace:
                FindFirstChild(
                    "RoundDoor"
                )

        if not folder then
            return nil,
                nil
        end

        local nearestOpen =
            nil

        local nearestClosed =
            nil

        local openDist =
            math.huge

        local closedDist =
            math.huge

        -- Self-contained scan on purpose.
        -- Do NOT call physicalDoorRows() here: that local function is
        -- declared later in combat.lua and caused V60.9's runtime nil call.
        for _, root in ipairs(
            folder:GetDescendants()
        ) do
            if root:IsA("BasePart")
                and root.Name == "Root"
                and root.Parent
                and root.Parent.Name
                    == "Door"
                and tonumber(
                    root:GetAttribute(
                        "RoundNum"
                    )
                ) == expectedRound
            then
                local prompt =
                    root:
                        FindFirstChildWhichIsA(
                            "ProximityPrompt",
                            true
                        )

                local dist =
                    (
                        root.Position
                        - Root.Position
                    ).Magnitude

                local switch =
                    root:GetAttribute(
                        "Switch"
                    )

                local opened =
                    switch == 1
                    or (
                        prompt
                        and prompt.Enabled
                            == false
                    )

                local row = {
                    Root = root,
                    Door = root.Parent,
                    RoundNum =
                        expectedRound,
                    Prompt = prompt,
                    PromptPos =
                        root.Position,
                    Switch = switch,
                    PlayerDistance =
                        dist,
                }

                if opened then
                    if dist < openDist then
                        nearestOpen =
                            row

                        openDist =
                            dist
                    end
                else
                    if dist < closedDist then
                        nearestClosed =
                            row

                        closedDist =
                            dist
                    end
                end
            end
        end

        return nearestOpen,
            nearestClosed
    end


getgenv().IronSoulCrossAlreadyOpenGate =
    function(row, reason)
        if not row
            or not Root
            or not Root.Parent
            or not row.Root
            or not row.Root.Parent
        then
            return false,
                "INVALID_OPEN_GATE"
        end

        local region =
            CurrentCombatRegion

        if not region then
            return false,
                "NO_REGION"
        end

        local humanoid =
            Humanoid

        if not humanoid
            or humanoid.Health <= 0
        then
            return false,
                "NO_HUMANOID"
        end

        local doorRoot =
            row.Root

        local doorPos =
            row.PromptPos
            or doorRoot.Position

        local outward =
            doorRoot.CFrame.LookVector

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

        -- Orient away from the room just completed.
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
            outward =
                -outward
        end

        local beforePos =
            Root.Position

        local beforeRound =
            gameRound()

        local oldRegion =
            region

        local destination =
            doorPos
            + outward
                * CFG.OPEN_GATE_CROSS_DISTANCE

        if getgenv().IronSoulTelemetry then
            getgenv().IronSoulTelemetry:
                Event(
                    "OPEN_GATE_CROSS_START",
                    "reason="
                        .. tostring(reason)
                        .. " round="
                        .. tostring(
                            row.RoundNum
                        )
                        .. " player="
                        .. tostring(
                            beforePos
                        )
                        .. " door="
                        .. tostring(
                            doorPos
                        )
                        .. " destination="
                        .. tostring(
                            destination
                        )
                )
        end

        getgenv().IronSoulNavTrace(
            "OPEN_GATE_CROSS_START round="
                .. tostring(
                    row.RoundNum
                )
                .. " playerDist="
                .. tostring(
                    row.PlayerDistance
                )
                .. " door="
                .. tostring(
                    doorPos
                )
        )

        local started =
            os.clock()

        while os.clock()
            - started
            < CFG.OPEN_GATE_CROSS_TIMEOUT
        do
            if not Root
                or not Root.Parent
                or humanoid.Health <= 0
            then
                return true,
                    "CHARACTER_CHANGED"
            end

            -- Real movement; no CFrame teleport for this recovery.
            pcall(
                humanoid.MoveTo,
                humanoid,
                destination
            )

            task.wait(
                CFG.OPEN_GATE_REISSUE
            )

            if settlementDetected() then
                return true,
                    "SETTLEMENT"
            end

            local nowRound =
                gameRound()

            if beforeRound
                and nowRound
                and nowRound
                    ~= beforeRound
            then
                if getgenv().IronSoulTelemetry then
                    getgenv().IronSoulTelemetry:
                        Event(
                            "OPEN_GATE_CROSS_SUCCESS",
                            "GAME_ROUND "
                                .. tostring(
                                    beforeRound
                                )
                                .. "->"
                                .. tostring(
                                    nowRound
                                )
                        )
                end

                return true,
                    "GAME_ROUND_CHANGED"
            end

            local newRegion,
                newRegionDist =
                    nearestWakeRegion(
                        Root.Position
                    )

            if newRegion
                and newRegion
                    ~= oldRegion
                and newRegionDist <= 30
            then
                CurrentCombatRegion =
                    newRegion

                CurrentCombatRound =
                    gameRound()

                if getgenv().IronSoulTelemetry then
                    getgenv().IronSoulTelemetry:
                        Event(
                            "OPEN_GATE_CROSS_SUCCESS",
                            "NEW_REGION "
                                .. fullName(
                                    newRegion
                                )
                        )
                end

                return true,
                    "NEW_REGION"
            end

            -- Crossing the doorway plane is enough to leave GATE and
            -- re-evaluate from the far side.
            local beyond =
                Vector3.new(
                    Root.Position.X
                        - doorPos.X,
                    0,
                    Root.Position.Z
                        - doorPos.Z
                ):
                    Dot(outward)

            if beyond
                >= CFG.OPEN_GATE_CROSS_SUCCESS
            then
                if getgenv().IronSoulTelemetry then
                    getgenv().IronSoulTelemetry:
                        Event(
                            "OPEN_GATE_CROSS_SUCCESS",
                            "CROSSED_PLANE beyond="
                                .. string.format(
                                    "%.1f",
                                    beyond
                                )
                                .. " pos="
                                .. tostring(
                                    Root.Position
                                )
                        )
                end

                return true,
                    "OPEN_GATE_CROSSED"
            end
        end

        humanoid:
            Move(
                Vector3.zero,
                false
            )

        local moved =
            (
                Root.Position
                - beforePos
            ).Magnitude

        if getgenv().IronSoulTelemetry then
            getgenv().IronSoulTelemetry:
                Event(
                    "OPEN_GATE_CROSS_STALL",
                    "moved="
                        .. string.format(
                            "%.1f",
                            moved
                        )
                        .. " final="
                        .. tostring(
                            Root.Position
                        )
                )
        end

        return false,
            "OPEN_GATE_CROSS_STALLED"
    end

local function spatialLiveEnemyCount(
    radius
)
    if not Root then
        return 0
    end

    radius =
        tonumber(radius)
        or CFG.SPATIAL_ENEMY_RADIUS

    local n = 0

    for _, enemy in ipairs(
        liveEnemies()
    ) do
        local eroot =
            modelRoot(enemy)

        if eroot
            and (
                eroot.Position
                - Root.Position
            ).Magnitude <= radius
        then
            n += 1
        end
    end

    return n
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

--========================================================--
-- V61.0 ADAPTIVE COMBAT POSITION
--
-- Separate module to avoid increasing combat.lua's local-register load.
--========================================================--

getgenv().IronSoulCombatPosition =
    nil

do
    local loadRaw =
        getgenv().IronSoulLoadRaw

    if CFG.ADAPTIVE_COMBAT_POSITION
        and type(loadRaw)
            == "function"
    then
        local ok, factory =
            loadRaw(
                "systems/combat_position.lua"
            )

        if ok
            and type(factory)
                == "function"
        then
            local builtOk,
                built =
                    pcall(
                        factory,
                        {
                            CFG = CFG,

                            event =
                                function(name, detail)
                                    local telemetry =
                                        getgenv().IronSoulTelemetry

                                    if telemetry then
                                        telemetry:
                                            Event(
                                                name,
                                                detail
                                            )
                                    end

                                    getgenv().IronSoulNavTrace(
                                        tostring(name)
                                            .. " "
                                            .. tostring(
                                                detail
                                                or ""
                                            )
                                    )
                                end,
                        }
                    )

            if builtOk
                and type(built)
                    == "table"
            then
                getgenv().IronSoulCombatPosition =
                    built
            else
                combatLog(
                    "ADAPTIVE_POSITION_INIT_FAILED"
                )
            end
        else
            combatLog(
                "ADAPTIVE_POSITION_LOAD_FAILED"
            )
        end
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

    local adaptive =
        getgenv().IronSoulCombatPosition

    local movement =
        adaptive
        and adaptive:
            GetMovement()
        or nil

    local height =
        movement
        and movement.Height
        or currentCombatHeight()

    local horizontal =
        movement
        and movement.Offset
        or (
            height > 0
            and CFG.ELEVATED_HORIZONTAL_OFFSET
            or CFG.TARGET_DISTANCE
        )

    local dir =
        horizontalUnitFromEnemy(
            eroot
        )

    if movement
        and tonumber(
            movement.Yaw
        )
        and movement.Yaw ~= 0
    then
        local angle =
            math.rad(
                movement.Yaw
            )

        local cosA =
            math.cos(angle)

        local sinA =
            math.sin(angle)

        dir =
            Vector3.new(
                dir.X * cosA
                    - dir.Z * sinA,
                0,
                dir.X * sinA
                    + dir.Z * cosA
            )

        if dir.Magnitude > 0.01 then
            dir =
                dir.Unit
        end
    end

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

--========================================================--
-- V60.6 PHYSICAL GATE FRONTIER
--
-- Exact game rule recovered from LocalRoundDoor:
--   a closed door is server-openable when RoundNum < GameRound.
--
-- Earlier versions required ONLY RoundNum == GameRound-1. On multi-section
-- maps that can leave an older physical gate closed, then allow a portal
-- to jump past it.
--
-- This selector ranks ALL currently-openable closed doors near the player
-- and current room. A nearby physical gate always blocks adaptive portal
-- navigation until the gate is actually opened.
--========================================================--

getgenv().IronSoulSelectFrontierDoor =
    function(expectedRound)
        if not Root then
            return nil
        end

        local current =
            tonumber(
                gameRound()
            )

        if not current then
            return nil
        end

        local region =
            CurrentCombatRegion
            or ensureRegion()

        local rows = {}

        for _, row in ipairs(
            physicalDoorRows()
        ) do
            if row.Switch ~= 1
                and row.RoundNum
                and row.RoundNum < current
                and row.Root
                and row.Root.Parent
                and row.Prompt
                and row.Prompt.Parent
            then
                local playerDist =
                    (
                        row.PromptPos
                        - Root.Position
                    ).Magnitude

                local regionDist =
                    region
                    and boxDistance(
                        region,
                        row.PromptPos
                    )
                    or math.huge

                local plausible =
                    playerDist
                        <= CFG.FRONTIER_DOOR_PLAYER_MAX
                    and (
                        not region
                        or regionDist
                            <= CFG.FRONTIER_DOOR_REGION_MAX
                        or playerDist <= 70
                    )

                if plausible then
                    local gap =
                        math.max(
                            0,
                            (current - 1)
                                - row.RoundNum
                        )

                    local score =
                        playerDist
                        + (
                            regionDist
                                ~= math.huge
                            and regionDist * 0.35
                            or 0
                        )
                        + gap
                            * CFG.FRONTIER_ROUND_GAP_PENALTY

                    if expectedRound
                        and row.RoundNum
                            == expectedRound
                    then
                        score -=
                            CFG.FRONTIER_EXACT_BONUS
                    end

                    row.PlayerDistance =
                        playerDist

                    row.RegionDistance =
                        regionDist

                    row.FrontierScore =
                        score

                    table.insert(
                        rows,
                        row
                    )
                end
            end
        end

        table.sort(
            rows,
            function(a,b)
                if math.abs(
                    a.FrontierScore
                    - b.FrontierScore
                ) > 0.01
                then
                    return a.FrontierScore
                        < b.FrontierScore
                end

                return a.PlayerDistance
                    < b.PlayerDistance
            end
        )

        local chosen =
            rows[1]

        if chosen then
            getgenv().IronSoulNavTrace(
                "FRONTIER_GATE round="
                    .. tostring(
                        chosen.RoundNum
                    )
                    .. " expected="
                    .. tostring(
                        expectedRound
                    )
                    .. " current="
                    .. tostring(
                        current
                    )
                    .. " playerDist="
                    .. string.format(
                        "%.1f",
                        chosen.PlayerDistance
                    )
                    .. " regionDist="
                    .. (
                        chosen.RegionDistance
                            == math.huge
                        and "inf"
                        or string.format(
                            "%.1f",
                            chosen.RegionDistance
                        )
                    )
                    .. " pos="
                    .. tostring(
                        chosen.PromptPos
                    )
            )

            if type(writefile)
                == "function"
            then
                local lines = {
                    "GameRound="
                        .. tostring(current),
                    "ExpectedRound="
                        .. tostring(
                            expectedRound
                        ),
                    "PlayerPos="
                        .. tostring(
                            Root.Position
                        ),
                    "CurrentRegion="
                        .. tostring(
                            region
                            and fullName(
                                region
                            )
                        ),
                    "ChosenRound="
                        .. tostring(
                            chosen.RoundNum
                        ),
                    "ChosenPos="
                        .. tostring(
                            chosen.PromptPos
                        ),
                    "ChosenPlayerDist="
                        .. tostring(
                            chosen.PlayerDistance
                        ),
                    "ChosenRegionDist="
                        .. tostring(
                            chosen.RegionDistance
                        ),
                    "ChosenScore="
                        .. tostring(
                            chosen.FrontierScore
                        ),
                    "Candidates="
                        .. tostring(
                            #rows
                        ),
                }

                for i = 1,
                    math.min(
                        6,
                        #rows
                    )
                do
                    local row =
                        rows[i]

                    table.insert(
                        lines,
                        "#"
                            .. tostring(i)
                            .. " Round="
                            .. tostring(
                                row.RoundNum
                            )
                            .. " PlayerDist="
                            .. string.format(
                                "%.1f",
                                row.PlayerDistance
                            )
                            .. " RegionDist="
                            .. (
                                row.RegionDistance
                                    == math.huge
                                and "inf"
                                or string.format(
                                    "%.1f",
                                    row.RegionDistance
                                )
                            )
                            .. " Score="
                            .. string.format(
                                "%.1f",
                                row.FrontierScore
                            )
                            .. " Pos="
                            .. tostring(
                                row.PromptPos
                            )
                    )
                end

                pcall(
                    writefile,
                    "IronSoul_LastGateDecision_V60_6.txt",
                    table.concat(
                        lines,
                        "\n"
                    )
                )
            end
        end

        return chosen
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
    outward,
    timeoutOverride
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
    local timeout =
        tonumber(
            timeoutOverride
        )
        or CFG.SECTION_PORTAL_APPEAR_TIMEOUT

    while os.clock()
        - started
        < timeout
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

--========================================================--
-- V60.2 ADAPTIVE PHASE TRANSITION MODULE
--
-- Kept outside combat.lua to avoid Luau's local-register limit.
--========================================================--

do
    local loadRaw =
        getgenv().IronSoulLoadRaw

    getgenv().IronSoulTransitionResolver =
        nil

    if type(loadRaw)
        == "function"
    then
        local ok, factory =
            loadRaw(
                "systems/transition.lua"
            )

        if ok
            and type(factory)
                == "function"
        then
            local builtOk,
                built =
                    pcall(
                        factory,
                        {
                            Players = Players,
                            ReplicatedStorage =
                                ReplicatedStorage,
                            LocalPlayer =
                                LocalPlayer,

                            CFG = CFG,

                            getRoot =
                                function()
                                    return Root
                                end,

                            getCurrentRegion =
                                function()
                                    return CurrentCombatRegion
                                end,

                            effectivelyVisible =
                                effectivelyVisible,

                            portalTeleportEvidence =
                                portalTeleportEvidence,

                            exactRoundDoorPortal =
                                exactRoundDoorPortal,

                            gameRound =
                                gameRound,

                            fullName =
                                fullName,

                            placeCharacter =
                                placeCharacter,

                            firetouchinterest =
                                firetouchinterest,

                            fireproximityprompt =
                                fireproximityprompt,

                            important =
                                important,

                            portalLog =
                                portalLog,

                            event =
                                function(name, detail)
                                    local telemetry =
                                        getgenv().IronSoulTelemetry

                                    if telemetry then
                                        telemetry:
                                            Event(
                                                name,
                                                detail
                                            )
                                    end
                                end,

                            hasCombatObjective =
                                function()
                                    return #liveEnemies() > 0
                                        or currentDragonEgg()
                                            ~= nil
                                end,
                        }
                    )

            if builtOk
                and type(built)
                    == "table"
            then
                getgenv().IronSoulTransitionResolver =
                    built
            else
                important(
                    "Transition module init failed"
                )
            end
        else
            important(
                "Transition module load failed"
            )
        end
    end
end

local function writePhaseAudit(
    route,
    completed,
    result
)
    if type(writefile)
        ~= "function"
    then
        return
    end

    pcall(
        writefile,
        "IronSoul_LastPhaseTransition_V60_3.txt",
        "Route="
            .. tostring(route)
            .. "\nCompletedRound="
            .. tostring(completed)
            .. "\nGameRound="
            .. tostring(
                gameRound()
            )
            .. "\nResult="
            .. tostring(result)
            .. "\nPlayerPos="
            .. tostring(
                Root
                and Root.Position
            )
    )
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

    local oldRegion =
        region

    -- V61.0 FAST PROGRESS CHECK:
    -- ordinary gates frequently spawn the next enemies / room immediately.
    -- Do not spend a long portal timeout before checking that evidence.
    local quickStarted =
        os.clock()

    while os.clock()
        - quickStarted
        < CFG.DOOR_FAST_PROGRESS_CHECK
    do
        if settlementDetected() then
            return true,
                "SETTLEMENT"
        end

        local candidate,
            regionDist =
                nearestWakeRegion(
                    Root.Position
                )

        if candidate
            and candidate ~= oldRegion
            and regionDist <= 25
        then
            CurrentCombatRegion =
                candidate

            CurrentCombatRound =
                gameRound()

            if getgenv().IronSoulTelemetry then
                getgenv().IronSoulTelemetry:
                    Event(
                        "DOOR_FAST_REGION",
                        fullName(candidate)
                    )
            end

            return true,
                "NEW_REGION_FAST"
        end

        local enemy,
            enemyDist =
                nearestSpatialEnemy(
                    CFG.GATE_ENEMY_RECOVERY_RADIUS
                )

        if enemy then
            local enemyRegion,
                enemyRegionDist =
                    nearestWakeRegion(
                        modelRoot(enemy).Position
                    )

            if enemyRegion
                and enemyRegion ~= oldRegion
                and enemyRegionDist <= 75
            then
                getgenv().IronSoulLockRegionToEnemy(
                    enemy,
                    "DOOR_FAST_ENEMY"
                )

                if getgenv().IronSoulTelemetry then
                    getgenv().IronSoulTelemetry:
                        Event(
                            "DOOR_FAST_ENEMY",
                            tostring(
                                enemy.Name
                            )
                                .. " dist="
                                .. string.format(
                                    "%.1f",
                                    enemyDist
                                )
                        )
                end

                return true,
                    "ENEMY_FRONTIER_FAST"
            end
        end

        task.wait(0.08)
    end

    -- V61.1:
    -- Before waiting on portal objects, reproduce the tiny REAL movement
    -- that manually wakes some server-side transition/checkpoint triggers.
    if CFG.NATIVE_MOTION_PULSE then
        local resolver =
            getgenv().IronSoulTransitionResolver

        if resolver
            and type(
                resolver.PulseNativeMovement
            ) == "function"
        then
            local moved,
                moveResult =
                    resolver:
                        PulseNativeMovement(
                            oldRegion,
                            outward,
                            "POST_DOOR"
                        )

            if moved then
                return true,
                    moveResult
            end
        end
    end

    -- Only now wait briefly for a section portal.
    if getgenv().IronSoulTelemetry then
        getgenv().IronSoulTelemetry:
            Event(
                "DOOR_PORTAL_WAIT",
                "primary="
                    .. tostring(
                        CFG.DOOR_SECTION_PORTAL_WAIT
                    )
            )
    end

    local portalUsed,
        portalResult =
            maybeEnterSectionPortal(
                oldRegion,
                outward,
                CFG.DOOR_SECTION_PORTAL_WAIT
            )

    if portalUsed then
        return true,
            portalResult
    end

    -- Short room wait after portal check.
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
            CFG.DOOR_NEW_REGION_WAIT,
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
    if getgenv().IronSoulTelemetry then
        getgenv().IronSoulTelemetry:
            Event(
                "DOOR_PORTAL_RETRY",
                tostring(
                    CFG.DOOR_SECTION_PORTAL_RETRY_WAIT
                )
            )
    end

    local retryPortal,
        retryResult =
            maybeEnterSectionPortal(
                oldRegion,
                outward,
                CFG.DOOR_SECTION_PORTAL_RETRY_WAIT
            )

    if retryPortal then
        return true,
            retryResult
    end

    -- One final genuine movement pulse at the exact state where the user
    -- proved manual movement wakes the transition.
    if CFG.NATIVE_MOTION_PULSE then
        local resolver =
            getgenv().IronSoulTransitionResolver

        if resolver
            and type(
                resolver.PulseNativeMovement
            ) == "function"
        then
            local moved,
                moveResult =
                    resolver:
                        PulseNativeMovement(
                            oldRegion,
                            outward,
                            "POST_PORTAL_TIMEOUT"
                        )

            if moved then
                return true,
                    moveResult
            end
        end
    end

    -- Only after all real transition evidence fails do we re-lock.
    lockRegion(
        "POST_DOOR_FALLBACK"
    )

    return true,
        "DOOR_CROSSED_NO_PORTAL"
end

local EGG_PROMPT_SEARCH_RADIUS =
    45

local EGG_ATTACK_HEIGHT =
    1.25

local EGG_ATTACK_OFFSET =
    2.0

local EGG_NO_PROGRESS_RECOVERY =
    2.25

local EGG_SESSION_TIMEOUT =
    18

local function dragonEggBroken(egg)
    return not egg
        or not egg.Parent
        or egg:GetAttribute(
            "Broken"
        ) == true
end

local function dragonEggActive(egg)
    return egg
        and egg.Parent
        and egg:GetAttribute(
            "Active"
        ) == true
        and not dragonEggBroken(
            egg
        )
end

local function eggCenter(egg)
    if not egg then
        return nil
    end

    if egg:IsA("BasePart") then
        return egg.Position
    end

    local part =
        egg:IsA("Model")
        and (
            egg.PrimaryPart
            or egg:
                FindFirstChild(
                    "HumanoidRootPart"
                )
            or egg:
                FindFirstChild(
                    "Root"
                )
            or egg:
                FindFirstChildWhichIsA(
                    "BasePart",
                    true
                )
        )
        or egg:
            FindFirstChildWhichIsA(
                "BasePart",
                true
            )

    return part
        and part.Position
end

local function currentDragonEgg()
    local egg =
        workspace:
            FindFirstChild(
                "DragonEgg"
            )

    if dragonEggBroken(egg) then
        return nil
    end

    local center =
        eggCenter(egg)

    if not center then
        return nil
    end

    -- Do not steal an egg belonging to another streamed branch.
    if CurrentCombatRegion
        and not pointInExpandedPart(
            CurrentCombatRegion,
            center,
            65
        )
    then
        return nil
    end

    return egg
end

local function eggPromptPart(prompt)
    if not prompt then
        return nil
    end

    local current =
        prompt.Parent

    while current
        and current ~= workspace
    do
        if current:IsA("BasePart") then
            return current
        end

        if current:IsA("Attachment")
            and current.Parent
            and current.Parent:IsA(
                "BasePart"
            )
        then
            return current.Parent
        end

        current = current.Parent
    end
end

local function findEggPrompts(egg)
    local result = {}
    local seen = {}

    -- Preferred: prompt under DragonEgg.
    for _, obj in ipairs(
        egg:GetDescendants()
    ) do
        if obj:IsA(
            "ProximityPrompt"
        )
        then
            table.insert(
                result,
                obj
            )

            seen[obj] = true
        end
    end

    -- Some maps host the prompt in a nearby interaction model instead.
    local center =
        eggCenter(egg)

    if center then
        local nearby = {}

        for _, obj in ipairs(
            workspace:GetDescendants()
        ) do
            if obj:IsA(
                "ProximityPrompt"
            )
                and not seen[obj]
            then
                local part =
                    eggPromptPart(obj)

                if part then
                    local distance =
                        (
                            part.Position
                            - center
                        ).Magnitude

                    if distance
                        <= EGG_PROMPT_SEARCH_RADIUS
                    then
                        table.insert(
                            nearby,
                            {
                                Prompt = obj,
                                Distance = distance,
                            }
                        )
                    end
                end
            end
        end

        table.sort(
            nearby,
            function(a,b)
                return a.Distance
                    < b.Distance
            end
        )

        for _, row in ipairs(
            nearby
        ) do
            table.insert(
                result,
                row.Prompt
            )
        end
    end

    return result
end

local function positionAtEgg(
    egg,
    closeMode,
    side
)
    if not Root
        or not egg
        or not egg.Parent
    then
        return false
    end

    local center =
        eggCenter(egg)

    if not center then
        return false
    end

    side = side or 1

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

    if side < 0 then
        dir = -dir
    end

    local offset =
        closeMode
        and 1.25
        or EGG_ATTACK_OFFSET

    local height =
        closeMode
        and 0.55
        or EGG_ATTACK_HEIGHT

    local goal =
        center
        + dir * offset
        + Vector3.new(
            0,
            height,
            0
        )

    Root.CFrame =
        CFrame.lookAt(
            goal,
            center
        )

    pcall(function()
        Root.AssemblyLinearVelocity =
            Vector3.zero

        Root.AssemblyAngularVelocity =
            Vector3.zero
    end)

    return true
end

local function waitEggActive(
    egg,
    timeout
)
    return waitUntil(
        function()
            if dragonEggBroken(
                egg
            )
            then
                return "BROKEN"
            end

            if dragonEggActive(
                egg
            )
            then
                return "ACTIVE"
            end
        end,
        timeout,
        0.04
    )
end

local function activateDragonEggStrict(
    egg
)
    if dragonEggBroken(egg) then
        return true
    end

    if dragonEggActive(egg) then
        return true
    end

    important(
        "Egg | activating"
    )

    local prompts =
        findEggPrompts(egg)

    if #prompts == 0 then
        important(
            "Egg | prompt not found, retrying"
        )

        return false
    end

    for _, prompt in ipairs(prompts) do
        if dragonEggBroken(egg)
            or dragonEggActive(egg)
        then
            break
        end

        local part =
            eggPromptPart(prompt)

        if part
            and Root
        then
            local delta =
                part.Position
                - Root.Position

            local dir =
                delta.Magnitude > 0.1
                and delta.Unit
                or Root.CFrame.LookVector

            local approach =
                part.Position
                - dir * 2.2

            placeCharacter(
                Vector3.new(
                    approach.X,
                    part.Position.Y,
                    approach.Z
                ),
                dir
            )
        end

        task.wait(0.06)

        -- Executor-native prompt route.
        if type(fireproximityprompt)
            == "function"
        then
            pcall(
                fireproximityprompt,
                prompt
            )

            local result =
                waitEggActive(
                    egg,
                    0.85
                )

            if result then
                break
            end

            pcall(
                fireproximityprompt,
                prompt,
                0
            )

            result =
                waitEggActive(
                    egg,
                    0.85
                )

            if result then
                break
            end
        end

        -- Roblox prompt lifecycle fallback.
        local oldDuration =
            prompt.HoldDuration

        pcall(function()
            prompt.HoldDuration = 0

            prompt:
                InputHoldBegin()

            task.wait(0.06)

            prompt:
                InputHoldEnd()

            prompt.HoldDuration =
                oldDuration
        end)

        if waitEggActive(
            egg,
            1.0
        ) then
            break
        end
    end

    if dragonEggBroken(egg) then
        important(
            "Egg | already gone"
        )

        return true
    end

    if dragonEggActive(egg) then
        important(
            "Egg | active, attacking"
        )

        return true
    end

    important(
        "Egg | activation not confirmed, retrying"
    )

    return false
end

local function eggHitDamage(egg)
    local value =
        egg
        and egg:
            GetAttribute(
                "HitDamage"
            )

    return tonumber(value)
end

local function attackDragonEggStrict(
    egg
)
    if dragonEggBroken(egg) then
        return "DONE"
    end

    -- IMPORTANT:
    -- Earlier recon proved the egg cannot receive damage until Active=true.
    if not dragonEggActive(egg) then
        if not activateDragonEggStrict(
            egg
        )
        then
            return "RETRY"
        end
    end

    if dragonEggBroken(egg) then
        return "DONE"
    end

    local started =
        os.clock()

    local lastProgress =
        os.clock()

    local lastHitDamage =
        eggHitDamage(egg)

    local recoverySide = 1

    positionAtEgg(
        egg,
        false,
        recoverySide
    )

    while not settlementDetected()
        and not dragonEggBroken(
            egg
        )
        and os.clock()
            - started
            < EGG_SESSION_TIMEOUT
    do
        -- If activation drops for any reason, restore it instead of
        -- letting the state machine skip the objective.
        if not dragonEggActive(
            egg
        )
        then
            activateDragonEggStrict(
                egg
            )

            task.wait(0.10)
        end

        positionAtEgg(
            egg,
            false,
            recoverySide
        )

        -- Native skills if ready, then direct no-Mouse1 Sword combo.
        castSkill("Skill2")
        castSkill("Skill1")

        pcall(
            sendHeadlessAttack
        )

        local hit =
            eggHitDamage(egg)

        if hit ~= lastHitDamage then
            lastHitDamage = hit
            lastProgress =
                os.clock()
        end

        if os.clock()
            - lastProgress
            >= EGG_NO_PROGRESS_RECOVERY
        then
            recoverySide =
                -recoverySide

            positionAtEgg(
                egg,
                true,
                recoverySide
            )

            AttackDriver.ComboStep = 1

            for step = 1, 4 do
                if dragonEggBroken(
                    egg
                )
                then
                    break
                end

                AttackDriver.ComboStep =
                    step

                pcall(
                    sendHeadlessAttack
                )

                task.wait(0.06)
            end

            AttackDriver.ComboStep = 1

            local after =
                eggHitDamage(egg)

            if after ~= lastHitDamage then
                lastHitDamage = after
                lastProgress =
                    os.clock()
            else
                -- If the egg did not register damage, re-assert activation.
                if not dragonEggActive(
                    egg
                )
                then
                    activateDragonEggStrict(
                        egg
                    )
                end
            end

            lastProgress =
                os.clock()
        end

        task.wait(0.105)
    end

    if dragonEggBroken(egg) then
        important(
            "Egg | broken"
        )

        return "DONE"
    end

    if settlementDetected() then
        return "SETTLEMENT"
    end

    -- NEVER tell the gate system the egg is done unless Broken/disappeared.
    important(
        "Egg | still alive, continuing"
    )

    return "RETRY"
end

local function handleDragonEggStrict()
    local egg =
        currentDragonEgg()

    if not egg then
        return "NONE"
    end

    return attackDragonEggStrict(
        egg
    )
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

    if getgenv().IronSoulCombatPosition then
        getgenv().IronSoulCombatPosition:
            ResetTarget(
                enemy,
                enemyHealth(enemy),
                Humanoid
                and Humanoid.Health,
                Humanoid
                and Humanoid.MaxHealth,
                Humanoid
                and Humanoid:GetState()
            )
    end

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

        if getgenv().IronSoulCombatPosition then
            getgenv().IronSoulCombatPosition:
                Update(
                    enemy,
                    enemyHealth(enemy),
                    Humanoid
                    and Humanoid.Health,
                    Humanoid
                    and Humanoid.MaxHealth,
                    Humanoid
                    and Humanoid:GetState()
                )
        end

        moveNear(enemy)
        face(enemy)

        -- Keep the proven V55.4 elevation recovery as fallback only when the
        -- adaptive position module is unavailable.
        if not getgenv().IronSoulCombatPosition then
            trackElevationDamage(
                enemy
            )
        end

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
--
-- V59.4 adds a HARD DragonEgg invariant:
--
--   DragonEgg exists and Broken ~= true
--       => GATE IS NOT ALLOWED
--
-- Even if GameRound advances after activating the egg, the controller
-- remains in COMBAT until the egg is Broken or disappears.
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

local pendingGateRound =
    nil

local noLocalEnemySince =
    nil

local gateRetryAt =
    0

getgenv().IronSoulAdaptiveGateState = {
    EnteredAt = nil,
    LastAttemptAt = 0,
}

getgenv().IronSoulStagingState = {
    NoEnemySince = nil,
    LastAttemptAt = 0,
    LastStatusAt = 0,
}

getgenv().IronSoulEmptyTraversalState = {
    Since = nil,
    LastAttemptAt = 0,
}

getgenv().IronSoulNavTraceRows =
    getgenv().IronSoulNavTraceRows
    or {}

getgenv().IronSoulNavTrace =
    function(text)
        local rows =
            getgenv().IronSoulNavTraceRows

        table.insert(
            rows,
            string.format(
                "[%.2f] %s",
                os.clock(),
                tostring(text)
            )
        )

        while #rows > 24 do
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
                "IronSoul_LastNavTrace_V60_5.txt",
                table.concat(
                    rows,
                    "\n"
                )
            )
        end
    end

getgenv().IronSoulNavTrace(
    "START PlaceId="
        .. tostring(game.PlaceId)
        .. " Pos="
        .. tostring(
            Root
            and Root.Position
        )
        .. " GameRound="
        .. tostring(
            gameRound()
        )
)

getgenv().IronSoulTelemetry =
    nil

getgenv().IronSoulTelemetryState =
    function()
        return {
            State = state,
            LastRound = lastRound,
            CompletedRound =
                completedRound,
            PendingGateRound =
                pendingGateRound,
            CurrentCombatRound =
                CurrentCombatRound,
            CurrentCombatRegion =
                CurrentCombatRegion,
            PortalsInvoked =
                portalsInvoked,
            Deaths = deaths,
        }
    end

do
    local loadRaw =
        getgenv().IronSoulLoadRaw

    if type(loadRaw)
        == "function"
    then
        local ok, factory =
            loadRaw(
                "systems/telemetry.lua"
            )

        if ok
            and type(factory)
                == "function"
        then
            local builtOk,
                built =
                    pcall(
                        factory,
                        {
                            LocalPlayer =
                                LocalPlayer,
                            CFG = CFG,

                            getRoot =
                                function()
                                    return Root
                                end,

                            getState =
                                getgenv().IronSoulTelemetryState,

                            gameRound =
                                gameRound,

                            getCurrentRegion =
                                function()
                                    return CurrentCombatRegion
                                end,

                            nearestWakeRegion =
                                nearestWakeRegion,

                            roundWakeFolder =
                                roundWakeFolder,

                            boxDistance =
                                boxDistance,

                            fullName =
                                fullName,

                            liveEnemies =
                                liveEnemies,

                            localLiveEnemies =
                                localLiveEnemies,

                            modelRoot =
                                modelRoot,

                            enemyHealth =
                                enemyHealth,

                            physicalDoorRows =
                                physicalDoorRows,

                            exactRoundDoorPortal =
                                exactRoundDoorPortal,

                            currentDragonEgg =
                                currentDragonEgg,

                            dragonEggActive =
                                dragonEggActive,

                            dragonEggBroken =
                                dragonEggBroken,

                            settlementDetected =
                                settlementDetected,

                            getHumanoid =
                                function()
                                    return Humanoid
                                end,

                            getCombatProfile =
                                function()
                                    local controller =
                                        getgenv().IronSoulCombatPosition

                                    return controller
                                        and controller:
                                            GetState()
                                end,
                        }
                    )

            if builtOk
                and type(built)
                    == "table"
            then
                getgenv().IronSoulTelemetry =
                    built

                built:
                    Start()

                built:
                    Event(
                        "START",
                        "controller initialized"
                    )
            else
                important(
                    "Telemetry init failed"
                )
            end
        else
            important(
                "Telemetry load failed"
            )
        end
    end
end

lockRegion(
    "START"
)

if getgenv().IronSoulTelemetry then
    getgenv().IronSoulTelemetry:
        Event(
            "V60_9_1_READY",
            "expected-gate scanner self-contained"
        )
end

local function moveToGateOrHoldEgg(
    roundToGate,
    reason
)
    local egg =
        currentDragonEgg()

    if egg then
        pendingGateRound =
            roundToGate

        state =
            "COMBAT"

        noLocalEnemySince =
            nil

        combatLog(
            "ROUND_ADVANCED but DragonEgg blocks gate reason="
                .. tostring(reason)
                .. " pendingRound="
                .. tostring(
                    pendingGateRound
                )
        )

        return false
    end

    completedRound =
        roundToGate

    pendingGateRound =
        nil

    state =
        "GATE"

    noLocalEnemySince =
        nil

    return true
end

local function finishPendingGateAfterEgg()
    if currentDragonEgg() then
        return false
    end

    if pendingGateRound then
        completedRound =
            pendingGateRound

        pendingGateRound =
            nil

        state =
            "GATE"

        noLocalEnemySince =
            nil

        return true
    end

    return false
end

while not stopReason do
    CurrentState = state

    if state == "GATE" then
        if not getgenv().IronSoulAdaptiveGateState.EnteredAt then
            getgenv().IronSoulAdaptiveGateState.EnteredAt =
                os.clock()
        end
    else
        getgenv().IronSoulAdaptiveGateState.EnteredAt =
            nil
    end

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

    -- AUTHORITATIVE room completion, BUT DragonEgg is a hard blocker.
    if nowRound
        and lastRound
        and nowRound > lastRound
        and state ~= "GATE"
    then
        local roundToGate =
            nowRound - 1

        if getgenv().IronSoulTelemetry then
            getgenv().IronSoulTelemetry:
                Event(
                    "ROUND_CHANGE",
                    tostring(
                        lastRound
                    )
                        .. "->"
                        .. tostring(
                            nowRound
                        )
                        .. " state="
                        .. tostring(
                            state
                        )
                )
        end

        lastRound =
            nowRound

        moveToGateOrHoldEgg(
            roundToGate,
            "TOP_LEVEL_ROUND_ADVANCE"
        )

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

        local egg =
            currentDragonEgg()

        -- Once active, DragonEgg outranks every other target.
        -- If a round already advanced, even an inactive egg outranks everything.
        if egg
            and (
                dragonEggActive(
                    egg
                )
                or pendingGateRound
                    ~= nil
            )
        then
            local eggResult =
                attackDragonEggStrict(
                    egg
                )

            if eggResult
                == "SETTLEMENT"
            then
                stopReason =
                    "SETTLEMENT_REACHED"

            elseif eggResult
                == "DONE"
            then
                finishPendingGateAfterEgg()

                task.wait(0.08)
            else
                task.wait(0.10)
            end
        else
            local enemy =
                nearestEnemy()

            if not enemy then
                local spatialEnemy,
                    spatialDist =
                        nearestSpatialEnemy(
                            CFG.SPATIAL_ENEMY_RADIUS
                        )

                if spatialEnemy then
                    enemy =
                        spatialEnemy

                    -- Re-lock using the enemy's position, not the player's.
                    -- Using the player position could keep the old room lock
                    -- after a newly spawned next-room wave appeared ahead.
                    getgenv().IronSoulLockRegionToEnemy(
                        spatialEnemy,
                        "SPATIAL_ENEMY_RECOVERY"
                    )

                    getgenv().IronSoulNavTrace(
                        "SPATIAL_ENEMY name="
                            .. tostring(
                                spatialEnemy.Name
                            )
                            .. " dist="
                            .. string.format(
                                "%.1f",
                                spatialDist
                            )
                            .. " Pos="
                            .. tostring(
                                Root.Position
                            )
                            .. " GameRound="
                            .. tostring(
                                gameRound()
                            )
                    )
                end
            end

            if enemy then
                if getgenv().IronSoulTelemetry then
                    local eroot =
                        modelRoot(enemy)

                    getgenv().IronSoulTelemetry:
                        Event(
                            "TARGET",
                            tostring(
                                enemy.Name
                            )
                                .. " hp="
                                .. tostring(
                                    enemyHealth(
                                        enemy
                                    )
                                )
                                .. " dist="
                                .. tostring(
                                    Root
                                    and eroot
                                    and (
                                        eroot.Position
                                        - Root.Position
                                    ).Magnitude
                                )
                        )
                end

                noLocalEnemySince =
                    nil

                getgenv().IronSoulStagingState.NoEnemySince =
                    nil

                getgenv().IronSoulEmptyTraversalState.Since =
                    nil

                local result =
                    fightEnemy(enemy)

                if getgenv().IronSoulTelemetry then
                    getgenv().IronSoulTelemetry:
                        Event(
                            "TARGET_RESULT",
                            tostring(
                                enemy.Name
                            )
                                .. " => "
                                .. tostring(
                                    result
                                )
                        )
                end

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
                        lastRound = r

                        moveToGateOrHoldEgg(
                            r - 1,
                            "FIGHT_RESULT"
                        )
                    end
                end
            else
                if not noLocalEnemySince then
                    noLocalEnemySince =
                        os.clock()
                end

                local localCount =
                    #localLiveEnemies()

                -- V60.4 TRANSITION-STAGING WATCHDOG
                --
                -- A section portal can move the player into an intermediate
                -- teleport/staging area that has:
                --   * no local enemies
                --   * no DragonEgg
                --   * no nearby RoundWakeTouch combat region
                --   * no GameRound advance yet
                --
                -- V60.3 treated that as ordinary COMBAT and waited forever.
                -- Here we allow the separate transition module to search for
                -- the NEXT local gate/portal without changing completedRound.
                local nearbyEnemyCount =
                    spatialLiveEnemyCount(
                        CFG.SPATIAL_ENEMY_RADIUS
                    )

                --======================================================--
                -- V60.7 EMPTY TRAVERSAL CORRIDOR
                --
                -- W1D3 can:
                --   main route -> teleport green side-stage
                --   finish green -> teleport back to an EMPTY corridor
                --   open 1-2 traversal gates -> green/blue portal
                --   next real enemy room
                --
                -- These empty gates do not necessarily create enemies or a
                -- useful RoundWakeTouch state. Therefore navigation must
                -- continue even when we are technically inside a wake region.
                --======================================================--
                if localCount == 0
                    and nearbyEnemyCount == 0
                    and not currentDragonEgg()
                then
                    if not getgenv().IronSoulEmptyTraversalState.Since then
                        getgenv().IronSoulEmptyTraversalState.Since =
                            os.clock()
                    end

                    local emptyAge =
                        os.clock()
                        - getgenv().IronSoulEmptyTraversalState.Since

                    if emptyAge
                            >= CFG.EMPTY_TRAVERSAL_IDLE
                        and os.clock()
                            - getgenv().IronSoulEmptyTraversalState.LastAttemptAt
                            >= CFG.EMPTY_TRAVERSAL_RETRY
                    then
                        getgenv().IronSoulEmptyTraversalState.LastAttemptAt =
                            os.clock()

                        -- V61.2:
                        -- Do NOT chase arbitrary older frontier gates here.
                        -- If GameRound=5, a Round3 gate is historical and can
                        -- physically pull us backward even though it remains
                        -- replicated.
                        --
                        -- Only an exact current-1 closed door is eligible.
                        local expectedEmptyRound =
                            gameRound()
                            and (
                                gameRound() - 1
                            )
                            or nil

                        local corridorGate =
                            expectedEmptyRound
                            and selectDoorForCompletedRound(
                                expectedEmptyRound
                            )
                            or nil

                        if corridorGate then
                            if getgenv().IronSoulTelemetry then
                                getgenv().IronSoulTelemetry:
                                    Event(
                                        "EMPTY_EXPECTED_GATE",
                                        "round="
                                            .. tostring(
                                                corridorGate.RoundNum
                                            )
                                            .. " pos="
                                            .. tostring(
                                                corridorGate.PromptPos
                                            )
                                    )
                            end

                            local gateOk,
                                gateResult =
                                    openAndCrossSelectedDoor(
                                        corridorGate
                                    )

                            if gateOk then
                                portalsInvoked += 1

                                writePhaseAudit(
                                    "EMPTY_EXPECTED_GATE",
                                    corridorGate.RoundNum,
                                    gateResult
                                )

                                lockRegion(
                                    "AFTER_EMPTY_EXPECTED_GATE"
                                )

                                CurrentCombatRound =
                                    gameRound()

                                lastRound =
                                    gameRound()
                                    or lastRound

                                noLocalEnemySince =
                                    nil

                                getgenv().IronSoulStagingState.NoEnemySince =
                                    nil

                                task.wait(0.28)

                                continue
                            end
                        end

                        -- If there is no authoritative door and the character
                        -- is already outside the room volume, walk toward the
                        -- actual unlocked section portal instead of wandering.
                        local currentRegionDist =
                            CurrentCombatRegion
                            and boxDistance(
                                CurrentCombatRegion,
                                Root.Position
                            )
                            or math.huge

                        if CFG.GUIDED_WALK
                            and currentRegionDist
                                >= CFG.GUIDED_WALK_ONLY_OUTSIDE_REGION
                        then
                            local resolver =
                                getgenv().IronSoulTransitionResolver

                            if resolver
                                and type(
                                    resolver.GuidedWalk
                                ) == "function"
                            then
                                local moved,
                                    moveResult =
                                        resolver:
                                            GuidedWalk(
                                                CurrentCombatRegion,
                                                "EMPTY_CORRIDOR"
                                            )

                                if moved then
                                    portalsInvoked += 1

                                    writePhaseAudit(
                                        "GUIDED_WALK",
                                        completedRound,
                                        moveResult
                                    )

                                    lockRegion(
                                        "AFTER_GUIDED_WALK"
                                    )

                                    CurrentCombatRound =
                                        gameRound()

                                    lastRound =
                                        gameRound()
                                        or lastRound

                                    noLocalEnemySince =
                                        nil

                                    getgenv().IronSoulStagingState.NoEnemySince =
                                        nil

                                    getgenv().IronSoulEmptyTraversalState.Since =
                                        nil

                                    task.wait(0.25)

                                    continue
                                end
                            end
                        end

                        -- No physical gate. Now and only now try a LOCAL
                        -- portal/exit. Strict transition module still blocks
                        -- generic Workspace.Portal and direct RoundDoor RF.
                        local resolver =
                            getgenv().IronSoulTransitionResolver

                        if resolver then
                            local moved,
                                moveResult =
                                    resolver:
                                        TryAdaptive()

                            if moved then
                                portalsInvoked += 1

                                writePhaseAudit(
                                    "EMPTY_CORRIDOR_PORTAL",
                                    completedRound,
                                    moveResult
                                )

                                if getgenv().IronSoulTelemetry then
                                    getgenv().IronSoulTelemetry:
                                        Event(
                                            "EMPTY_PORTAL",
                                            tostring(
                                                moveResult
                                            )
                                        )
                                end

                                getgenv().IronSoulNavTrace(
                                    "EMPTY_PORTAL result="
                                        .. tostring(
                                            moveResult
                                        )
                                        .. " Pos="
                                        .. tostring(
                                            Root.Position
                                        )
                                        .. " GameRound="
                                        .. tostring(
                                            gameRound()
                                        )
                                )

                                important(
                                    "Phase | empty corridor"
                                )

                                lockRegion(
                                    "AFTER_EMPTY_CORRIDOR_PORTAL"
                                )

                                CurrentCombatRound =
                                    gameRound()

                                lastRound =
                                    gameRound()
                                    or lastRound

                                noLocalEnemySince =
                                    nil

                                getgenv().IronSoulStagingState.NoEnemySince =
                                    nil

                                getgenv().IronSoulEmptyTraversalState.Since =
                                    nil

                                task.wait(0.38)

                                continue
                            end
                        end
                    end
                else
                    getgenv().IronSoulEmptyTraversalState.Since =
                        nil
                end

                if localCount == 0
                    and nearbyEnemyCount == 0
                    and not currentDragonEgg()
                then
                    local stagingRegion,
                        stagingDist =
                            nearestWakeRegion(
                                Root.Position
                            )

                    local outsideCombatRoom =
                        not stagingRegion
                        or stagingDist
                            > CFG.STAGING_REGION_DISTANCE

                    if outsideCombatRoom then
                        if not getgenv().IronSoulStagingState.NoEnemySince then
                            getgenv().IronSoulStagingState.NoEnemySince =
                                os.clock()
                        end

                        local stagingAge =
                            os.clock()
                            - getgenv().IronSoulStagingState.NoEnemySince

                        if stagingAge
                                >= CFG.STAGING_IDLE_TIME
                            and os.clock()
                                - getgenv().IronSoulStagingState.LastAttemptAt
                                >= CFG.STAGING_RETRY_COOLDOWN
                        then
                            getgenv().IronSoulStagingState.LastAttemptAt =
                                os.clock()

                            important(
                                "Staging | searching next phase"
                            )

                            getgenv().IronSoulNavTrace(
                                "STAGING_SEARCH Pos="
                                    .. tostring(
                                        Root.Position
                                    )
                                    .. " GameRound="
                                    .. tostring(
                                        gameRound()
                                    )
                                    .. " local="
                                    .. tostring(
                                        localCount
                                    )
                                    .. " nearby="
                                    .. tostring(
                                        nearbyEnemyCount
                                    )
                                    .. " global="
                                    .. tostring(
                                        #liveEnemies()
                                    )
                                    .. " regionDist="
                                    .. tostring(
                                        stagingDist
                                    )
                            )

                            -- A physical server-openable gate always
                            -- has priority over portal scanning.
                            local frontier =
                                getgenv().IronSoulSelectFrontierDoor(
                                    nil
                                )

                            if frontier then
                                getgenv().IronSoulNavTrace(
                                    "STAGING_GATE_BLOCK round="
                                        .. tostring(
                                            frontier.RoundNum
                                        )
                                        .. " pos="
                                        .. tostring(
                                            frontier.PromptPos
                                        )
                                )

                                -- Re-lock the closest room if possible, then
                                -- open/cross THIS physical frontier gate.
                                lockRegion(
                                    "STAGING_FRONTIER_GATE"
                                )

                                local doorOk,
                                    doorResult =
                                        openAndCrossSelectedDoor(
                                            frontier
                                        )

                                if doorOk then
                                    portalsInvoked += 1

                                    writePhaseAudit(
                                        "STAGING_FRONTIER_GATE",
                                        frontier.RoundNum,
                                        doorResult
                                    )

                                    getgenv().IronSoulNavTrace(
                                        "STAGING_GATE_OPENED round="
                                            .. tostring(
                                                frontier.RoundNum
                                            )
                                            .. " result="
                                            .. tostring(
                                                doorResult
                                            )
                                            .. " Pos="
                                            .. tostring(
                                                Root.Position
                                            )
                                    )

                                    lockRegion(
                                        "AFTER_STAGING_FRONTIER_GATE"
                                    )

                                    CurrentCombatRound =
                                        gameRound()

                                    lastRound =
                                        gameRound()
                                        or lastRound

                                    noLocalEnemySince =
                                        nil

                                    getgenv().IronSoulStagingState.NoEnemySince =
                                        nil

                                    task.wait(0.45)

                                    continue
                                else
                                    -- IMPORTANT: do NOT jump to adaptive
                                    -- portal logic while a legitimate physical
                                    -- gate remains closed. Retry the gate.
                                    getgenv().IronSoulNavTrace(
                                        "STAGING_GATE_RETRY round="
                                            .. tostring(
                                                frontier.RoundNum
                                            )
                                            .. " result="
                                            .. tostring(
                                                doorResult
                                            )
                                    )

                                    task.wait(0.35)

                                    continue
                                end
                            end

                            local resolver =
                                getgenv().IronSoulTransitionResolver

                            if CFG.GUIDED_WALK
                                and resolver
                                and type(
                                    resolver.GuidedWalk
                                ) == "function"
                            then
                                local guidedMoved,
                                    guidedResult =
                                        resolver:
                                            GuidedWalk(
                                                CurrentCombatRegion,
                                                "STAGING"
                                            )

                                if guidedMoved then
                                    portalsInvoked += 1

                                    writePhaseAudit(
                                        "GUIDED_WALK_STAGING",
                                        completedRound,
                                        guidedResult
                                    )

                                    lockRegion(
                                        "AFTER_GUIDED_STAGING"
                                    )

                                    CurrentCombatRound =
                                        gameRound()

                                    lastRound =
                                        gameRound()
                                        or lastRound

                                    noLocalEnemySince =
                                        nil

                                    getgenv().IronSoulStagingState.NoEnemySince =
                                        nil

                                    task.wait(0.22)

                                    continue
                                end
                            end

                            local moved =
                                false

                            local moveResult =
                                nil

                            if resolver then
                                moved,
                                    moveResult =
                                        resolver:
                                            TryAdaptive()
                            end

                            if moved then
                                portalsInvoked += 1

                                writePhaseAudit(
                                    "COMBAT_STAGING_FALLBACK",
                                    completedRound,
                                    moveResult
                                )

                                important(
                                    "Phase | staging transition"
                                )

                                getgenv().IronSoulNavTrace(
                                    "STAGING_MOVED result="
                                        .. tostring(
                                            moveResult
                                        )
                                        .. " Pos="
                                        .. tostring(
                                            Root.Position
                                        )
                                        .. " GameRound="
                                        .. tostring(
                                            gameRound()
                                        )
                                )

                                lockRegion(
                                    "AFTER_STAGING_TRANSITION"
                                )

                                CurrentCombatRound =
                                    gameRound()

                                lastRound =
                                    gameRound()
                                    or lastRound

                                noLocalEnemySince =
                                    nil

                                getgenv().IronSoulStagingState.NoEnemySince =
                                    nil

                                task.wait(0.45)

                                continue
                            end

                            -- One tiny overwritten status file only.
                            if type(writefile)
                                == "function"
                            then
                                local snapshot =
                                    resolver
                                    and resolver:
                                        Snapshot(8)
                                    or "TransitionResolver=nil"

                                pcall(
                                    writefile,
                                    "IronSoul_LastNavigation_V60_4.txt",
                                    "State=COMBAT_STAGING"
                                        .. "\nGameRound="
                                        .. tostring(
                                            gameRound()
                                        )
                                        .. "\nPlayerPos="
                                        .. tostring(
                                            Root.Position
                                        )
                                        .. "\nNearestRegion="
                                        .. tostring(
                                            stagingRegion
                                            and fullName(
                                                stagingRegion
                                            )
                                        )
                                        .. "\nRegionDistance="
                                        .. tostring(
                                            stagingDist
                                        )
                                        .. "\nLocalEnemies="
                                        .. tostring(
                                            localCount
                                        )
                                        .. "\nNearbyEnemies="
                                        .. tostring(
                                            nearbyEnemyCount
                                        )
                                        .. "\nEmptyTraversalAge="
                                        .. tostring(
                                            getgenv().IronSoulEmptyTraversalState.Since
                                            and (
                                                os.clock()
                                                - getgenv().IronSoulEmptyTraversalState.Since
                                            )
                                        )
                                        .. "\nGlobalEnemies="
                                        .. tostring(
                                            #liveEnemies()
                                        )
                                        .. "\nCandidates:\n"
                                        .. tostring(
                                            snapshot
                                        )
                                )
                            end
                        end
                    else
                        getgenv().IronSoulStagingState.NoEnemySince =
                            nil
                    end
                else
                    getgenv().IronSoulStagingState.NoEnemySince =
                        nil
                end

                if localCount == 0
                    and os.clock()
                        - noLocalEnemySince
                        >= CFG.NO_ENEMY_STABLE_TIME
                then
                    local eggResult =
                        handleDragonEggStrict()

                    if eggResult
                        == "SETTLEMENT"
                    then
                        stopReason =
                            "SETTLEMENT_REACHED"

                    elseif eggResult
                        == "DONE"
                    then
                        if getgenv().IronSoulTelemetry then
                            getgenv().IronSoulTelemetry:
                                Event(
                                    "EGG_DONE",
                                    "GameRound="
                                        .. tostring(
                                            gameRound()
                                        )
                                )
                        end

                        getgenv().IronSoulNavTrace(
                            "EGG_DONE Pos="
                                .. tostring(
                                    Root.Position
                                )
                                .. " GameRound="
                                .. tostring(
                                    gameRound()
                                )
                                .. " nearbyEnemies="
                                .. tostring(
                                    spatialLiveEnemyCount(
                                        CFG.SPATIAL_ENEMY_RADIUS
                                    )
                                )
                        )

                        finishPendingGateAfterEgg()

                        noLocalEnemySince =
                            os.clock()

                        task.wait(0.08)

                    elseif eggResult
                        == "RETRY"
                    then
                        noLocalEnemySince =
                            os.clock()

                        task.wait(0.12)
                    else
                        task.wait(0.08)
                    end
                else
                    task.wait(0.06)
                end
            end
        end

    elseif state == "GATE" then
        -- Last-second protection against the old race:
        -- if an unbroken egg streams/replicates while GATE owns control,
        -- give control back to COMBAT immediately.
        local blockingEgg =
            currentDragonEgg()

        if blockingEgg then
            pendingGateRound =
                completedRound
                or (
                    (gameRound() or 1)
                    - 1
                )

            state =
                "COMBAT"

            noLocalEnemySince =
                nil

            task.wait(0.06)
        else
            -- NON-INTERRUPTIBLE gate state for normal enemies.
            if not completedRound then
                completedRound =
                    pendingGateRound
                    or (
                        (gameRound() or 1)
                        - 1
                    )

                pendingGateRound =
                    nil
            end

            --==================================================--
            -- V60.9 OPEN-GATE / ENEMY-FRONTIER RECOVERY
            --
            -- D4 telemetry proved this state:
            --   GameRound=3, CompletedRound=2
            --   nearest Round2 gate Switch=1 / prompt disabled at 6 studs
            --   5 live next-room enemies already spawned 93-148 studs away
            --
            -- Waiting in GATE is wrong there. The gate is already finished.
            -- Use the live enemy spawn to identify the next room and resume
            -- COMBAT without touching another portal/gate.
            --==================================================--

            local gateEnemy,
                gateEnemyDist =
                    nearestSpatialEnemy(
                        CFG.GATE_ENEMY_RECOVERY_RADIUS
                    )

            if gateEnemy then
                local openExpected,
                    closedExpected =
                        getgenv().IronSoulExpectedGateStatus(
                            completedRound
                        )

                local expectedAlreadyOpen =
                    openExpected
                    and openExpected.PlayerDistance
                        <= CFG.GATE_OPEN_NEAR_DISTANCE

                local noUsableExpected =
                    not closedExpected
                    and gateEnemyDist
                        <= CFG.GATE_NO_EXPECTED_ENEMY_RADIUS

                if expectedAlreadyOpen
                    or noUsableExpected
                then
                    if getgenv().IronSoulTelemetry then
                        getgenv().IronSoulTelemetry:
                            Event(
                                "GATE_TO_ENEMY",
                                "completed="
                                    .. tostring(
                                        completedRound
                                    )
                                    .. " enemy="
                                    .. tostring(
                                        gateEnemy.Name
                                    )
                                    .. " enemyDist="
                                    .. string.format(
                                        "%.1f",
                                        gateEnemyDist
                                    )
                                    .. " openExpectedDist="
                                    .. tostring(
                                        openExpected
                                        and openExpected.PlayerDistance
                                    )
                                    .. " closedExpectedDist="
                                    .. tostring(
                                        closedExpected
                                        and closedExpected.PlayerDistance
                                    )
                            )
                    end

                    getgenv().IronSoulNavTrace(
                        "GATE_TO_ENEMY completed="
                            .. tostring(
                                completedRound
                            )
                            .. " enemy="
                            .. tostring(
                                gateEnemy.Name
                            )
                            .. " dist="
                            .. string.format(
                                "%.1f",
                                gateEnemyDist
                            )
                    )

                    state =
                        "COMBAT"

                    CurrentState =
                        state

                    completedRound =
                        nil

                    pendingGateRound =
                        nil

                    noLocalEnemySince =
                        nil

                    getgenv().IronSoulAdaptiveGateState.EnteredAt =
                        nil

                    getgenv().IronSoulLockRegionToEnemy(
                        gateEnemy,
                        "GATE_ALREADY_OPEN"
                    )

                    task.wait(0.08)

                    continue
                end
            end

            -- V61.3: the expected gate can already be open.
            -- If so, physically cross it instead of waiting forever or
            -- considering a far duplicate branch.
            if not gateEnemy then
                local openExpected,
                    closedExpected =
                        getgenv().IronSoulExpectedGateStatus(
                            completedRound
                        )

                if openExpected
                    and openExpected.PlayerDistance
                        <= CFG.GATE_OPEN_NEAR_DISTANCE
                then
                    local crossed,
                        crossResult =
                            getgenv().IronSoulCrossAlreadyOpenGate(
                                openExpected,
                                "GATE_EXPECTED_ALREADY_OPEN"
                            )

                    if crossed then
                        portalsInvoked += 1

                        writePhaseAudit(
                            "OPEN_EXPECTED_GATE",
                            completedRound,
                            crossResult
                        )

                        state =
                            "COMBAT"

                        CurrentState =
                            state

                        completedRound =
                            nil

                        pendingGateRound =
                            nil

                        noLocalEnemySince =
                            nil

                        getgenv().IronSoulAdaptiveGateState.EnteredAt =
                            nil

                        lockRegion(
                            "AFTER_OPEN_GATE_CROSS"
                        )

                        CurrentCombatRound =
                            gameRound()

                        lastRound =
                            gameRound()
                            or lastRound

                        task.wait(0.18)

                        continue
                    else
                        -- Retry the same nearby correct gate. Do not fall
                        -- through to a far duplicate on this iteration.
                        gateRetryAt =
                            os.clock() + 0.45

                        task.wait(0.08)

                        continue
                    end
                end
            end

            if os.clock()
                >= gateRetryAt
            then
                local adaptiveDone =
                    false

                -- V60.3:
                -- DOOR-FIRST. A visible Room Cleared banner is NOT enough
                -- reason to fire a section portal. Some maps keep later
                -- section portals replicated early, and invoking them can
                -- jump straight toward the boss.
                --
                -- Always resolve the authoritative completedRound door first.
                local row =
                    selectDoorForCompletedRound(
                        completedRound
                    )

                local frontier =
                    nil

                -- V60.7:
                -- An authoritative exact completedRound door always wins.
                -- Only use the broader physical frontier if NO exact door
                -- exists. V60.6 could replace expected Round4 with a nearby
                -- Round3 gate, which caused route/backtracking confusion.
                if not row then
                    frontier =
                        getgenv().IronSoulSelectFrontierDoor(
                            completedRound
                        )

                    row =
                        frontier
                end

                if row then
                        if getgenv().IronSoulTelemetry then
                            getgenv().IronSoulTelemetry:
                                Event(
                                    "GATE_CHOSEN",
                                    "round="
                                        .. tostring(
                                            row.RoundNum
                                        )
                                        .. " switch="
                                        .. tostring(
                                            row.Switch
                                        )
                                        .. " pos="
                                        .. tostring(
                                            row.PromptPos
                                        )
                                )
                        end

                        local ok,
                            result =
                                openAndCrossSelectedDoor(
                                    row
                                )

                        if getgenv().IronSoulTelemetry then
                            getgenv().IronSoulTelemetry:
                                Event(
                                    "GATE_RESULT",
                                    "round="
                                        .. tostring(
                                            row.RoundNum
                                        )
                                        .. " ok="
                                        .. tostring(ok)
                                        .. " result="
                                        .. tostring(
                                            result
                                        )
                                )
                        end

                        if ok then
                            portalsInvoked += 1

                            writePhaseAudit(
                                "ROUND_DOOR",
                                completedRound,
                                result
                            )

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

                                pendingGateRound =
                                    nil

                                noLocalEnemySince =
                                    nil

                                getgenv().IronSoulAdaptiveGateState.EnteredAt =
                                    nil

                                task.wait(0.45)
                            end
                        else
                            gateRetryAt =
                                os.clock() + 0.35

                            task.wait(0.08)
                        end
                else
                    gateRetryAt =
                        os.clock() + 0.30

                    task.wait(0.08)
                end

                -- If old door logic has been unable to progress for a while,
                -- run the generalized high-confidence resolver.
                if not row
                    and not adaptiveDone
                    and state == "GATE"
                    and getgenv().IronSoulAdaptiveGateState.EnteredAt
                    and os.clock()
                        - getgenv().IronSoulAdaptiveGateState.EnteredAt
                        >= CFG.ADAPTIVE_STUCK_TIME
                    and os.clock()
                        - getgenv().IronSoulAdaptiveGateState.LastAttemptAt
                        >= CFG.ADAPTIVE_RETRY_COOLDOWN
                then
                    getgenv().IronSoulAdaptiveGateState.LastAttemptAt =
                        os.clock()

                    -- First use the OLD proven physical portal handshake.
                    -- It only acts when the exact RoundDoor.Portal is near
                    -- the player, so it cannot remotely skip future sections.
                    local ok,
                        result =
                            maybeEnterSectionPortal(
                                CurrentCombatRegion,
                                nil,
                                2.25
                            )

                    -- If there is no nearby exact portal, allow the modular
                    -- resolver to look for a DIFFERENT local gate/exit type.
                    if not ok then
                        local resolver =
                            getgenv().IronSoulTransitionResolver

                        if resolver then
                            ok,
                                result =
                                    resolver:
                                        TryAdaptive()
                        end
                    end

                    if ok then
                        portalsInvoked += 1

                        writePhaseAudit(
                            "NO_DOOR_FALLBACK",
                            completedRound,
                            result
                        )

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
                                "AFTER_ADAPTIVE_PHASE"
                            )

                            CurrentCombatRound =
                                gameRound()

                            lastRound =
                                gameRound()
                                or lastRound

                            completedRound =
                                nil

                            pendingGateRound =
                                nil

                            noLocalEnemySince =
                                nil

                            getgenv().IronSoulAdaptiveGateState.EnteredAt =
                                nil

                            task.wait(0.45)
                        end
                    end
                end
            else
                task.wait(0.06)
            end
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
-- SMART SETTLEMENT / REPLAY / LOBBY V59.4
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
-- Replay tries the exact settlement signal/callback/remotes first, then
-- same-PlaceId teleport with original match teleport data before Lobby.
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

local ForgeUtilReplay
local EquipmentUtilReplay
local EquipmentCombatReplay

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

local function oreBagStatus()
    if not ForgeUtilReplay then
        return false,
            nil,
            nil
    end

    local ores = nil
    local max = nil
    local canAdd = nil

    if type(
        ForgeUtilReplay.GetOres
    ) == "function"
    then
        local ok, value =
            pcall(function()
                return ForgeUtilReplay:
                    GetOres(
                        LocalPlayer
                    )
            end)

        if ok
            and type(value)
                == "table"
        then
            ores = value
        end
    end

    if type(
        ForgeUtilReplay.GetMax
    ) == "function"
    then
        local ok, value =
            pcall(function()
                return ForgeUtilReplay:
                    GetMax(
                        LocalPlayer
                    )
            end)

        if ok then
            max =
                tonumber(value)
        end
    end

    if type(
        ForgeUtilReplay.CheckCanAdd
    ) == "function"
    then
        local ok, value =
            pcall(function()
                return ForgeUtilReplay:
                    CheckCanAdd(
                        LocalPlayer
                    )
            end)

        if ok then
            canAdd = value
        end
    end

    local used = 0

    if ores then
        for _, amount in pairs(
            ores
        ) do
            if type(amount)
                == "number"
            then
                used += amount
            end
        end
    end

    local full =
        canAdd == false
        or (
            max
            and used >= max
        )

    return full,
        used,
        max
end

local function equipmentBagFull()
    if not EquipmentUtilReplay
        or type(
            EquipmentUtilReplay.CheckCanAdd
        ) ~= "function"
    then
        return false
    end

    local ok, canAdd =
        pcall(function()
            return EquipmentUtilReplay:
                CheckCanAdd(
                    LocalPlayer
                )
        end)

    return ok
        and canAdd == false
end

local function visibleBagFullWarning()
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
                "bag is full",
                1,
                true
            )
                or string.find(
                    text,
                    "will not give rewards",
                    1,
                    true
                )
            then
                return true,
                    tostring(
                        obj.Text
                    )
            end
        end
    end

    return false
end

local function dungeonBagFullStatus()
    local warning,
        warningText =
            visibleBagFullWarning()

    local oreFull,
        oreUsed,
        oreMax =
            oreBagStatus()

    local equipFull =
        equipmentBagFull()

    if warning
        or oreFull
        or equipFull
    then
        local reason =
            oreFull
            and "ORE_BAG_FULL"
            or (
                equipFull
                and "EQUIPMENT_BAG_FULL"
                or "BAG_FULL_WARNING"
            )

        return true,
            reason,
            oreUsed,
            oreMax,
            warningText
    end

    return false,
        "OK",
        oreUsed,
        oreMax,
        nil
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
    local bagFull,
        bagReason,
        oreUsed,
        oreMax =
            dungeonBagFullStatus()

    if bagFull then
        return true,
            bagReason
            .. (
                oreUsed
                and oreMax
                and (
                    "_"
                    .. tostring(oreUsed)
                    .. "_OF_"
                    .. tostring(oreMax)
                )
                or ""
            )
    end

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

    -- Do not bounce Lobby for every single level-up.
    -- Batch small permanent-stat gains and spend them during periodic
    -- maintenance or when 3+ points accumulate.
    if points >= 3
        and attackLv
            < ATTACK_SOFT_CAP
    then
        return true,
            "ATTRIBUTE_BATCH"
    end

    -- Keep a little more headroom before interrupting a repeat streak.
    if inventoryCountNow()
        >= 90
    then
        return true,
            "INVENTORY_HIGH"
    end

    -- Tiny equipment upgrades can wait for periodic maintenance.
    -- A missing slot / materially better item is still worth returning for.
    local equipment =
        d.Equipment

    if type(equipment)
        == "table"
    then
        local owned =
            equipment.Owned
            or {}

        local slots =
            equipment.EquipSlots
            or {}

        local active =
            equipment.CurWeaponSlot
            or "Weapon"

        local equippedUUID =
            slots[active]

        local equippedBase =
            equipmentBaseReplay(
                equippedUUID
            )

        local equippedPower =
            equipmentPowerReplay(
                equippedUUID
            )

        local bestBase =
            equippedBase

        local bestPower =
            equippedPower

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

                if base > bestBase
                    or (
                        base == bestBase
                        and pwr > bestPower
                    )
                then
                    bestBase = base
                    bestPower = pwr
                end
            end
        end

        if not equippedUUID
            and bestBase > 0
        then
            return true,
                "MISSING_SWORD"
        end

        if bestBase
                >= equippedBase + 2
            or (
                equippedPower > 0
                and bestPower
                    >= equippedPower * 1.25
            )
        then
            return true,
                "MAJOR_SWORD_UPGRADE"
        end

        for _, armorClass in ipairs({
            "Helmet",
            "Breastplate",
        }) do
            local equipped =
                slots[armorClass]

            local equippedArmorPower =
                equipmentPowerReplay(
                    equipped
                )

            local bestArmorPower =
                equippedArmorPower

            for uuid, item in pairs(owned) do
                if type(item) == "table"
                    and item.Type == "Armor"
                    and item.Class
                        == armorClass
                then
                    bestArmorPower =
                        math.max(
                            bestArmorPower,
                            equipmentPowerReplay(
                                uuid
                            )
                        )
                end
            end

            if not equipped
                and bestArmorPower > 0
            then
                return true,
                    "MISSING_"
                    .. string.upper(
                        armorClass
                    )
            end

            if equippedArmorPower > 0
                and bestArmorPower
                    >= equippedArmorPower
                        * 1.25
            then
                return true,
                    "MAJOR_"
                    .. string.upper(
                        armorClass
                    )
                    .. "_UPGRADE"
            end
        end
    end

    return false,
        "NONE"
end


local ResWorldRound =
    req("ResWorldRound")

local WorldUtil =
    req("WorldUtil")

ForgeUtilReplay =
    req("ForgeUtil")

EquipmentUtilReplay =
    req("EquipmentUtil")

EquipmentCombatReplay =
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

local QueuedForNextTeleport =
    false

local function queueNext(reason)
    if QueuedForNextTeleport then
        return true
    end

    local ok = false

    if type(queueBootstrap)
        == "function"
    then
        ok =
            queueBootstrap(
                reason
            )
    else
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

        ok =
            pcall(
                queue,
                payload
            )
    end

    if ok then
        QueuedForNextTeleport =
            true
    end

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


local REPLAY_STATUS_FILE =
    "IronSoul_LastReplay_V59_4.txt"

local EGG_STATUS_FILE =
    "IronSoul_LastEgg_V59_4.txt"

local function writeTinyStatus(
    path,
    text
)
    if type(writefile)
        == "function"
    then
        pcall(
            writefile,
            path,
            tostring(text)
        )
    end
end

local function findPlayAgainAloneButton()
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
                "PlayAgainAloneBtn"
            )
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

local function waitReplayUIReady(
    timeout
)
    return waitUntil(
        function()
            local button =
                findNativePlayAgainButton()

            if not button
                or not effectivelyVisible(
                    button
                )
            then
                return nil
            end

            local players =
                num(
                    GameRoundCfg:
                        GetAttribute(
                            "PlayersCount"
                        )
                )

            if players <= 0 then
                return nil
            end

            return button
        end,
        timeout,
        0.08
    )
end

local function replayEvidence(
    oldRound,
    oldVotes,
    timeout
)
    local deadline =
        os.clock() + timeout

    local voteAccepted =
        false

    while os.clock()
        < deadline
    do
        local teleportAttr =
            LocalPlayer:
                GetAttribute(
                    "IsTeleporting"
                )

        if teleportAttr ~= nil
            and teleportAttr ~= false
        then
            return "TELEPORT",
                teleportAttr
        end

        local votes =
            num(
                GameRoundCfg:
                    GetAttribute(
                        "VotedAgainCount"
                    )
            )

        if votes > oldVotes then
            voteAccepted = true
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
            return "SAME_SERVER_RESET",
                votes
        end

        task.wait(0.08)
    end

    if voteAccepted then
        return "VOTE_ACCEPTED",
            num(
                GameRoundCfg:
                    GetAttribute(
                        "VotedAgainCount"
                    )
            )
    end

    return nil,
        num(
            GameRoundCfg:
                GetAttribute(
                    "VotedAgainCount"
                )
        )
end

local function executeSettlementConnection(
    button
)
    if type(getconnections)
        ~= "function"
    then
        return false
    end

    local ok, conns =
        pcall(
            getconnections,
            button.MouseButton1Down
        )

    if not ok then
        return false
    end

    for _, conn in ipairs(conns) do
        local fn =
            conn.Function

        if type(fn)
            == "function"
        then
            local constants = nil

            if type(getconstants)
                == "function"
            then
                pcall(function()
                    constants =
                        getconstants(fn)
                end)
            end

            local isReplay =
                false

            if type(constants)
                == "table"
            then
                for _, value in pairs(
                    constants
                ) do
                    if value
                        == "VotePlayAgain"
                    then
                        isReplay = true
                        break
                    end
                end
            end

            if isReplay then
                local callOk =
                    pcall(fn)

                if callOk then
                    return true
                end
            end
        end
    end

    return false
end

local function replayTransitionEvidence(
    oldRound,
    timeout
)
    local deadline =
        os.clock() + timeout

    while os.clock()
        < deadline
    do
        local teleportAttr =
            LocalPlayer:
                GetAttribute(
                    "IsTeleporting"
                )

        if teleportAttr ~= nil
            and teleportAttr ~= false
        then
            return "TELEPORT",
                teleportAttr
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
                    and nowRound
                        < oldRound
                )
            )
        then
            return "SAME_SERVER_RESET",
                nowRound
        end

        task.wait(0.10)
    end

    return nil
end

local function runReplayRoute(
    name,
    fn,
    oldRound,
    waitTime,
    players
)
    settlementLog(
        "REPLAY_ROUTE "
            .. tostring(name)
            .. " PlayersCount="
            .. tostring(players)
    )

    local ok, err =
        pcall(fn)

    if not ok then
        writeTinyStatus(
            REPLAY_STATUS_FILE,
            "Route="
                .. tostring(name)
                .. "\nResult=CALL_ERROR"
                .. "\nError="
                .. tostring(err)
                .. "\nPlayersCount="
                .. tostring(players)
        )

        return false
    end

    local evidence,
        detail =
            replayTransitionEvidence(
                oldRound,
                waitTime
            )

    writeTinyStatus(
        REPLAY_STATUS_FILE,
        "Route="
            .. tostring(name)
            .. "\nEvidence="
            .. tostring(evidence)
            .. "\nDetail="
            .. tostring(detail)
            .. "\nPlayersCount="
            .. tostring(players)
            .. "\nPlaceId="
            .. tostring(game.PlaceId)
    )

    if evidence
        == "TELEPORT"
        or evidence
            == "SAME_SERVER_RESET"
    then
        important(
            "Replay | solo restart"
        )

        return true,
            name
    end

    return false
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

    -- Queue only ONCE in this server. If replay later fails and we must
    -- return Lobby, directLobby() will reuse this queued bootstrap instead
    -- of stacking another copy.
    queueNext(
        "solo same-stage replay"
    )

    important(
        "Replay | same stage solo"
    )

    -- Give settlement UI/server state time to fully settle.
    local button =
        waitReplayUIReady(
            8
        )

    task.wait(0.65)

    local oldRound =
        gameRound()

    local players =
        num(
            GameRoundCfg:
                GetAttribute(
                    "PlayersCount"
                )
        )

    if players <= 0 then
        players = 1
    end

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

    -- ========================================================
    -- ROUTE 1: exact "Play again (alone)" GUI signal.
    --
    -- This is deliberately FIRST even when PlayersCount==1.
    -- It is the game's explicit independent replay path and therefore
    -- cannot carry a random party forward.
    -- ========================================================
    local aloneButton =
        findPlayAgainAloneButton()

    if aloneButton
        and type(firesignal)
            == "function"
    then
        local ok =
            runReplayRoute(
                "PLAY_AGAIN_ALONE_SIGNAL",
                function()
                    firesignal(
                        aloneButton.MouseButton1Down
                    )
                end,
                oldRound,
                12,
                players
            )

        if ok then
            return true,
                "PLAY_AGAIN_ALONE_SIGNAL"
        end
    end

    -- ========================================================
    -- ROUTE 2: exact server command behind Play again (alone).
    -- Give the server a full 15 seconds; V59.4 only waited briefly and
    -- could race into its public same-PlaceId fallback before this
    -- teleport had time to start.
    -- ========================================================
    if gameRoundRE
        and gameRoundRE:IsA(
            "RemoteEvent"
        )
    then
        local ok =
            runReplayRoute(
                "PLAY_AGAIN_ALONE_REMOTE",
                function()
                    gameRoundRE:
                        FireServer(
                            "PlayAgainAlone"
                        )
                end,
                oldRound,
                15,
                players
            )

        if ok then
            return true,
                "PLAY_AGAIN_ALONE_REMOTE"
        end

        -- Retry the independent route once, after a short server cooldown.
        task.wait(0.8)

        ok =
            runReplayRoute(
                "PLAY_AGAIN_ALONE_REMOTE_RETRY",
                function()
                    gameRoundRE:
                        FireServer(
                            "PlayAgainAlone"
                        )
                end,
                oldRound,
                15,
                players
            )

        if ok then
            return true,
                "PLAY_AGAIN_ALONE_REMOTE_RETRY"
        end
    end

    -- ========================================================
    -- ROUTE 3: normal vote is allowed ONLY when this is already solo.
    -- Never use VotePlayAgain in a multiplayer settlement because it can
    -- preserve/coordinate the party instead of creating an independent run.
    -- ========================================================
    if players <= 1
        and gameRoundRE
        and gameRoundRE:IsA(
            "RemoteEvent"
        )
    then
        local ok =
            runReplayRoute(
                "VOTE_PLAY_AGAIN_SOLO",
                function()
                    gameRoundRE:
                        FireServer(
                            "VotePlayAgain"
                        )
                end,
                oldRound,
                15,
                players
            )

        if ok then
            return true,
                "VOTE_PLAY_AGAIN_SOLO"
        end
    end

    -- IMPORTANT V59.5:
    -- DO NOT Teleport(game.PlaceId). That joins an arbitrary public server
    -- and was proven by V59.4 to produce a 2-player dungeon.
    writeTinyStatus(
        REPLAY_STATUS_FILE,
        "Route=NO_PUBLIC_SAME_PLACE_FALLBACK"
            .. "\nResult=NATIVE_REPLAY_FAILED"
            .. "\nPlayersCount="
            .. tostring(players)
            .. "\nPlaceId="
            .. tostring(game.PlaceId)
    )

    important(
        "Replay | native solo retry failed, rebuilding solo room"
    )

    return false,
        "NATIVE_SOLO_REPLAY_FAILED"
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

-- V59.6: never replay into a dungeon that the game says will give
-- no rewards because the bag is full.
local bagFull,
    bagReason,
    oreUsed,
    oreMax,
    bagWarning =
        dungeonBagFullStatus()

if bagFull then
    important(
        "Bag full | "
            .. tostring(
                bagReason
            )
            .. (
                oreUsed
                and oreMax
                and (
                    " "
                    .. tostring(oreUsed)
                    .. "/"
                    .. tostring(oreMax)
                )
                or ""
            )
            .. " | returning Lobby"
    )

    writeJournal({
        State = "BAG_FULL",
        Decision = "LOBBY_MAINTENANCE",
        World = journal.World or "?",
        Diff = journal.Diff or "?",
        DirectRepeats = 0,
        FailureCount = journal.FailureCount or 0,
        FailPower = journal.FailPower or 0,
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
        BagReason = bagReason,
        OreUsed = oreUsed or "?",
        OreMax = oreMax or "?",
        UpdatedAt = os.time(),
    })

    directLobby(
        "BAG_FULL_"
            .. tostring(
                bagReason
            )
    )

    return
end

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
