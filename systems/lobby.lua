--========================================================--
-- IRON SOUL - FORGE AUDIT + REWARD FIXES LOBBY V59.8
--
-- RUN IN LOBBY.
--
-- One bounded autonomous cycle:
--
--   LOBBY LOAD
--     -> free/idempotent rewards
--     -> activate available Sword skills
--     -> Main_009 deterministic forge ONLY if active
--     -> pets
--     -> best equipment
--     -> early Attack attributes
--     -> safe inventory cleanup if high
--     -> progression planner
--     -> ADVANCE or REPEAT Story
--     -> free physical matchmaking room
--     -> queue proven V57.2 combat
--     -> teleport to dungeon
--     -> combat completes
--     -> direct no-click return to Lobby
--     -> STOP
--
-- This is intentionally ONE cycle.
-- If this passes, V59 can turn the same state machine into continuous
-- unattended progression.
--========================================================--

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer

-- Ignore duplicate queued lobby loaders in the same server.
do
    local key =
        tostring(game.PlaceId)
        .. "|"
        .. tostring(game.JobId)

    local old =
        getgenv().IronSoulLobbyGuard

    if type(old) == "table"
        and old.Key == key
        and os.clock()
            - tonumber(old.At or 0)
            < 12
    then
        return
    end

    getgenv().IronSoulLobbyGuard = {
        Key = key,
        At = os.clock(),
    }
end

local LOBBY_PLACE_ID = 117533937949084

local UserConfig =
    getgenv().IronSoulConfig
    or {}

local CFG = {
    FPS_CAP = 8,

    DEBUG_LOGS =
        UserConfig.DEBUG_LOGS == true,

    -- Early permanent-stat policy.
    -- Attack is proven to give strong real server damage early.
    -- We stop at 15 for now instead of spending every future point.
    ATTACK_SOFT_CAP = 15,

    INVENTORY_CLEAN_AT = 85,
    INVENTORY_TARGET = 70,

    LOAD_TIMEOUT = 25,
    TELEPORT_TIMEOUT = 18,
}

if type(setfpscap) == "function" then
    pcall(
        setfpscap,
        CFG.FPS_CAP
    )
end

--========================================================--
-- OUTPUT
--========================================================--

local ROOT_FOLDER =
    "IronSoul_ContinuousLobby_V59"

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
local actions = {}
local plannerOut = {}
local matchmakingOut = {}

local function clk()
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

local function shouldPrintLobby(text)
    return string.find(
        text,
        "STOP ",
        1,
        true
    )
    or string.find(
        text,
        "ACTION Attribute",
        1,
        true
    )
    or string.find(
        text,
        "ACTION Equip ",
        1,
        true
    )
    or string.find(
        text,
        "ACTION Main_009",
        1,
        true
    )
    or string.find(
        text,
        "PLAN TARGET=",
        1,
        true
    )
    or string.find(
        text,
        "SUCCESS:",
        1,
        true
    )
end

local function log(s)
    local line =
        "["
        .. clk()
        .. "] "
        .. tostring(s)

    if CFG.DEBUG_LOGS then
        add(report, line)
    end

    local text =
        tostring(s)

    if shouldPrintLobby(text) then
        important(text)
    end
end

local function action(s)
    if CFG.DEBUG_LOGS then
        add(
            actions,
            "["
                .. clk()
                .. "] "
                .. tostring(s)
        )
    end

    log(
        "ACTION "
            .. tostring(s)
    )
end

local function plan(s)
    if CFG.DEBUG_LOGS then
        add(
            plannerOut,
            "["
                .. clk()
                .. "] "
                .. tostring(s)
        )
    end

    log(
        "PLAN "
            .. tostring(s)
    )
end

local function matchLog(s)
    if CFG.DEBUG_LOGS then
        add(
            matchmakingOut,
            "["
                .. clk()
                .. "] "
                .. tostring(s)
        )
    end

    log(
        "MATCH "
            .. tostring(s)
    )
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
        {"actions.txt", actions},
        {"planner.txt", plannerOut},
        {"matchmaking.txt", matchmakingOut},
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

local function stop(reason)
    important(
        "STOP | "
            .. tostring(reason)
    )

    save()

    return false
end

--========================================================--
-- BASIC HELPERS
--========================================================--

local function waitUntil(
    fn,
    timeout,
    step
)
    local deadline =
        os.clock()
        + (timeout or 5)

    step = step or 0.08

    while os.clock()
        < deadline
    do
        local ok, value =
            pcall(fn)

        if ok and value then
            return value
        end

        task.wait(step)
    end
end

local function findByName(
    root,
    wanted,
    className
)
    for _, obj in ipairs(
        root:GetDescendants()
    ) do
        if obj.Name == wanted
            and (
                not className
                or obj:IsA(
                    className
                )
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
        pcall(
            require,
            obj
        )

    return ok
        and value
        or nil
end

local function num(v)
    return tonumber(v) or 0
end

local function count(t)
    local n = 0

    if type(t) == "table" then
        for _ in pairs(t) do
            n += 1
        end
    end

    return n
end

local function currency(
    data,
    id
)
    if type(data)
        ~= "table"
    then
        return 0
    end

    if type(data.Currency)
        == "table"
        and type(
            data.Currency[id]
        ) == "number"
    then
        return data.Currency[id]
    end

    return num(data[id])
end

local function fullName(obj)
    local ok, value =
        pcall(function()
            return obj:GetFullName()
        end)

    return ok
        and value
        or tostring(obj)
end

--========================================================--
-- ENVIRONMENT / EXECUTOR
--========================================================--

if game.PlaceId
    ~= LOBBY_PLACE_ID
then
    return stop(
        "V59 is lobby-only. PlaceId="
            .. tostring(
                game.PlaceId
            )
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
    return stop(
        "V59 requires queue_on_teleport for continuous progression."
    )
end

local queueBootstrap =
    getgenv().IronSoulQueueBootstrap

if type(queueBootstrap)
        ~= "function"
then
    return stop(
        "V59 bootstrap queue helper missing."
    )
end

local JOURNAL_FILE =
    "IronSoul_Kaitun_Journal_V59.txt"

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

--========================================================--
-- MODULES
--========================================================--

local DataUtil = req("DataUtil")
local WorldUtil = req("WorldUtil")
local ResWorldRound = req("ResWorldRound")

local EquipmentUtil = req("EquipmentUtil")
local EquipmentCombat = req("EquipmentCombat")
local EquipmentSlots = req("EquipmentSlots")
local EquipmentRE =
    findByName(
        ReplicatedStorage,
        "EquipmentRE",
        "RemoteEvent"
    )

local TaskUtil = req("TaskUtil")

local DailyQuestUtil = req("DailyQuestUtil")
local SevenDailyUtil = req("SevenDailyUtil")
local DailyLoginUtil = req("DailyLoginUtil")
local GuidebookUtil = req("GuidebookUtil")
local UpdateLogUtil = req("UpdateLogUtil")
local ResUpdateLog = req("ResUpdateLog")
local SeasonUtil = req("SeasonUtil")
local ResSeasonPass = req("ResSeasonPass")

local PetsUtil = req("PetsUtil")
local PetsHatchUtil = req("PetsHatchUtil")

local SkillTreeUtil = req("SkillTreeUtil")
local UnForgeUtil = req("UnForgeUtil")

local AttributeUpgradeUtil =
    req("AttributeUpgradeUtil")

local ForgeUtil = req("ForgeUtil")
local ForgeRF =
    findByName(
        ReplicatedStorage,
        "ForgeRF",
        "RemoteFunction"
    )

local GameMatchRE =
    findByName(
        ReplicatedStorage,
        "GameMatchRE",
        "RemoteEvent"
    )

if not DataUtil
    or not WorldUtil
    or not ResWorldRound
    or not GameMatchRE
then
    return stop(
        "Required progression modules missing."
    )
end

--========================================================--
-- PLAYER DATA
--========================================================--

local function pdata()
    local ok, value =
        pcall(function()
            return DataUtil:
                GetPlayerData(
                    LocalPlayer
                )
        end)

    return ok
        and type(value)
            == "table"
        and value
        or nil
end

local function lobbyOreBagStatus()
    if not ForgeUtil then
        return false,
            nil,
            nil
    end

    local ores = nil
    local max = nil
    local canAdd = nil

    if type(
        ForgeUtil.GetOres
    ) == "function"
    then
        local ok, value =
            pcall(function()
                return ForgeUtil:
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
        ForgeUtil.GetMax
    ) == "function"
    then
        local ok, value =
            pcall(function()
                return ForgeUtil:
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
        ForgeUtil.CheckCanAdd
    ) == "function"
    then
        local ok, value =
            pcall(function()
                return ForgeUtil:
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

local function lobbyEquipmentBagFull()
    if not EquipmentUtil
        or type(
            EquipmentUtil.CheckCanAdd
        ) ~= "function"
    then
        return false
    end

    local ok, value =
        pcall(function()
            return EquipmentUtil:
                CheckCanAdd(
                    LocalPlayer
                )
        end)

    return ok
        and value == false
end

local loaded =
    waitUntil(
        function()
            local data =
                pdata()

            if not data then
                return nil
            end

            if LocalPlayer:
                GetAttribute(
                    "Loaded"
                ) == false
            then
                return nil
            end

            if LocalPlayer:
                    GetAttribute(
                        "LG_Level"
                    )
                == nil
                or LocalPlayer:
                    GetAttribute(
                        "LG_PowerNew1"
                    )
                == nil
            then
                return nil
            end

            return data
        end,
        CFG.LOAD_TIMEOUT,
        0.12
    )

if not loaded then
    return stop(
        "PlayerData did not become fully loaded."
    )
end

local function level()
    return num(
        LocalPlayer:
            GetAttribute(
                "LG_Level"
            )
    )
end

local function power()
    return num(
        LocalPlayer:
            GetAttribute(
                "LG_PowerNew1"
            )
    )
end

local function inventoryCount()
    local d =
        pdata()

    return count(
        d
        and d.Equipment
        and d.Equipment.Owned
        or {}
    )
end

log(
    "LOADED Level="
        .. tostring(level())
        .. " Power="
        .. tostring(power())
        .. " Inventory="
        .. tostring(
            inventoryCount()
        )
)

--========================================================--
-- SNAPSHOT
--========================================================--

local function snapshot(label)
    local d =
        pdata()

    local attr =
        d
        and d.AttributeUpgrade
        or {}

    local lvs =
        attr.AttributeLvs
        or {}

    log(
        label
            .. " Level="
            .. tostring(level())
            .. " Power="
            .. tostring(power())
            .. " AttrPoints="
            .. tostring(
                num(
                    attr.RemainingPoint
                )
            )
            .. " AttackLv="
            .. tostring(
                num(
                    lvs.AtkBonusValue
                )
            )
            .. " Inventory="
            .. tostring(
                inventoryCount()
            )
            .. " Ticket1="
            .. tostring(
                currency(
                    d,
                    "Ticket1"
                )
            )
            .. " SeasonTicket="
            .. tostring(
                currency(
                    d,
                    "SeasonTicket"
                )
            )
    )
end

snapshot("BEFORE")

--========================================================--
-- SAFE / FREE REWARDS
--========================================================--

local function boolAt(
    t,
    key
)
    if type(t)
        ~= "table"
    then
        return nil
    end

    if t[key] ~= nil then
        return t[key]
    end

    return t[
        tostring(key)
    ]
end

local function claimDailyQuest()
    if not DailyQuestUtil
        or type(
            DailyQuestUtil.ClickGetReward
        ) ~= "function"
    then
        return
    end

    local function claimed(index)
        local d = pdata()

        local state =
            d
            and d.DailyQuest
            and d.DailyQuest.RewardState

        return state
            and boolAt(
                state,
                index
            ) == true
    end

    local d = pdata()
    local q =
        d
        and d.DailyQuest

    if type(q)
        ~= "table"
    then
        return
    end

    local completed =
        num(q.CompletedNum)

    -- Normal DailyQuest reward milestones are finite. Scan the replicated
    -- RewardState rather than trusting only one stale snapshot.
    for i = 1, math.max(5, completed) do
        local now = pdata()

        local state =
            now
            and now.DailyQuest
            and now.DailyQuest.RewardState
            or {}

        local value =
            boolAt(
                state,
                i
            )

        if value == false then
            local success = false

            for attempt = 1, 2 do
                action(
                    "Claim DailyQuest #"
                        .. tostring(i)
                        .. " attempt "
                        .. tostring(attempt)
                )

                pcall(function()
                    DailyQuestUtil:
                        ClickGetReward(
                            LocalPlayer,
                            i
                        )
                end)

                if waitUntil(
                    function()
                        return claimed(i)
                    end,
                    3.5
                ) then
                    success = true
                    break
                end

                task.wait(0.20)
            end

            if not success then
                -- Exact mapped fallback: nil index asks the system to process
                -- currently available unclaimed milestones.
                pcall(function()
                    DailyQuestUtil:
                        ClickGetReward(
                            LocalPlayer
                        )
                end)

                task.wait(0.35)
            end
        end
    end
end


local function claimSeasonPass()
    if not SeasonUtil
        or not SeasonUtil.RemoteEvent
        or not ResSeasonPass
    then
        return
    end

    local seasonId =
        "Season3"

    if type(
        SeasonUtil.GetCurrentSeason
    ) == "function"
    then
        pcall(function()
            local value =
                SeasonUtil:
                    GetCurrentSeason()

            if type(value)
                == "string"
            then
                seasonId = value
            end
        end)
    end

    local d = pdata()
    local season =
        d
        and d.Seasons
        and d.Seasons[seasonId]

    local cfg =
        ResSeasonPass[seasonId]

    if type(season)
            ~= "table"
        or type(cfg)
            ~= "table"
    then
        return
    end

    local each =
        tonumber(cfg.EachEXP)
        or 1000

    local maxLevel =
        tonumber(cfg.MaxLevel)
        or 1

    local earned =
        math.min(
            maxLevel,
            math.floor(
                num(season.EXP)
                / each
            ) + 1
        )

    for lv = 1, earned do
        local key =
            "C"
            .. tostring(lv)
            .. "F"

        if season[key]
            ~= true
        then
            action(
                "Claim Season free Lv"
                    .. tostring(lv)
            )

            pcall(function()
                SeasonUtil.RemoteEvent:
                    FireServer(
                        "Claim",
                        lv
                    )
            end)

            waitUntil(
                function()
                    local now =
                        pdata()

                    return now
                        and now.Seasons
                        and now.Seasons[seasonId]
                        and now.Seasons[seasonId][key]
                            == true
                end,
                4
            )
        end
    end
end

local function claimSevenDaily()
    if not SevenDailyUtil
        or type(
            SevenDailyUtil.CanGetDailyReward
        ) ~= "function"
    then
        return
    end

    local d = pdata()
    local seven =
        d
        and d.SevenDaily

    if type(seven)
        ~= "table"
    then
        return
    end

    local unlock =
        math.clamp(
            num(
                seven.UnlockDay
            ),
            0,
            7
        )

    local function dayClaimed(day)
        local now = pdata()

        local claimed =
            now
            and now.SevenDaily
            and now.SevenDaily.Claimed

        if type(claimed)
            ~= "table"
        then
            return false
        end

        local key =
            "Day"
            .. tostring(day)

        return claimed[key] == true
            or boolAt(
                claimed,
                day
            ) == true
    end

    for day = 1, unlock do
        if not dayClaimed(day) then
            for attempt = 1, 2 do
                action(
                    "Claim SevenDaily Day"
                        .. tostring(day)
                )

                pcall(function()
                    SevenDailyUtil:
                        CanGetDailyReward(
                            LocalPlayer,
                            day
                        )
                end)

                if waitUntil(
                    function()
                        return dayClaimed(day)
                    end,
                    3
                ) then
                    break
                end

                task.wait(0.20)
            end
        end
    end
end


local function claimGuidebook()
    if not GuidebookUtil
        or type(
            GuidebookUtil.CanClaimed
        ) ~= "function"
        or type(
            GuidebookUtil.GetRewards
        ) ~= "function"
    then
        return
    end

    local categories = {
        "Unlock_Total",
        "Unlock_Sword",
        "Unlock_Heavy",
        "Unlock_Greatsword",
        "Unlock_Staff",
        "Unlock_Fist",
        "Unlock_Bow",
        "Unlock_Sickle",
        "Unlock_Helmet",
        "Unlock_Breastplate",
        "Unlock_Scrolls",
        "Unlock_Pet",
    }

    for _, category
        in ipairs(categories)
    do
        for _ = 1, 12 do
            local ok, can =
                pcall(function()
                    return GuidebookUtil:
                        CanClaimed(
                            LocalPlayer,
                            category
                        )
                end)

            if not ok
                or can ~= true
            then
                break
            end

            action(
                "Claim Guidebook "
                    .. category
            )

            pcall(function()
                GuidebookUtil:
                    GetRewards(
                        LocalPlayer,
                        category
                    )
            end)

            task.wait(0.18)
        end
    end
end

local function claimUpdateLog()
    if not UpdateLogUtil
        or type(
            UpdateLogUtil.ClaimReward
        ) ~= "function"
        or type(ResUpdateLog)
            ~= "table"
    then
        return
    end

    local index =
        ResUpdateLog.__index

    if type(index)
        ~= "table"
    then
        return
    end

    for _, id in ipairs(index) do
        local def =
            ResUpdateLog[id]

        if def then
            local d =
                pdata()

            local state =
                d
                and d.UpdateLog
                or {}

            if state[id]
                ~= true
            then
                local success =
                    false

                for attempt = 1, 2 do
                    action(
                        "Claim UpdateLog "
                            .. tostring(id)
                    )

                    pcall(function()
                        UpdateLogUtil:
                            ClaimReward(
                                LocalPlayer,
                                id
                            )
                    end)

                    if waitUntil(
                        function()
                            local now =
                                pdata()

                            return now
                                and now.UpdateLog
                                and now.UpdateLog[id]
                                    == true
                        end,
                        3.5
                    ) then
                        success = true
                        break
                    end

                    task.wait(0.20)
                end

                if not success then
                    important(
                        "UpdateLog pending | "
                            .. tostring(id)
                    )
                end
            end
        end
    end
end


local function inspectDailyLogin()
    if not DailyLoginUtil then
        return 0,
            {}
    end

    local pending = {}

    if type(
        DailyLoginUtil.GetClientState
    ) == "function"
    then
        local ok, state =
            pcall(function()
                -- nil third arg intentionally prevents us from treating
                -- MakeUp as a normal claimable reward.
                return DailyLoginUtil:
                    GetClientState(
                        LocalPlayer,
                        nil
                    )
            end)

        if ok
            and type(state)
                == "table"
            and type(state.Rewards)
                == "table"
        then
            for _, reward in ipairs(
                state.Rewards
            ) do
                if type(reward)
                    == "table"
                    and tostring(
                        reward.State
                    ) == "Claimable"
                then
                    table.insert(
                        pending,
                        {
                            Id =
                                reward.Id,
                            Day =
                                reward.Day,
                        }
                    )
                end
            end
        end
    end

    -- Fallback signal if state layout ever changes.
    if #pending == 0
        and type(
            DailyLoginUtil.HasUnclaimedReward
        ) == "function"
    then
        local ok, can =
            pcall(function()
                return DailyLoginUtil:
                    HasUnclaimedReward(
                        LocalPlayer
                    )
            end)

        if ok
            and can == true
        then
            table.insert(
                pending,
                {
                    Id = "?",
                    Day = "?",
                }
            )
        end
    end

    if #pending > 0 then
        important(
            "DailyLogin free reward pending | "
                .. tostring(
                    #pending
                )
        )
    end

    return #pending,
        pending
end


local function spendSeasonTickets()
    if not SeasonUtil
        or not SeasonUtil.RemoteEvent
    then
        return
    end

    local tickets =
        currency(
            pdata(),
            "SeasonTicket"
        )

    while tickets >= 3 do
        local before = tickets

        action(
            "Season Lottery x3"
        )

        pcall(function()
            SeasonUtil.RemoteEvent:
                FireServer(
                    "TrySeasonLottery",
                    3
                )
        end)

        local changed =
            waitUntil(
                function()
                    local now =
                        currency(
                            pdata(),
                            "SeasonTicket"
                        )

                    return now
                            <= before - 3
                        and now
                end,
                5
            )

        if changed == nil then
            break
        end

        tickets =
            num(changed)
    end

    while tickets > 0 do
        local before = tickets

        action(
            "Season Lottery x1"
        )

        pcall(function()
            SeasonUtil.RemoteEvent:
                FireServer(
                    "TrySeasonLottery",
                    1
                )
        end)

        local changed =
            waitUntil(
                function()
                    local now =
                        currency(
                            pdata(),
                            "SeasonTicket"
                        )

                    return now
                            <= before - 1
                        and now
                end,
                5
            )

        if changed == nil then
            break
        end

        tickets =
            num(changed)
    end
end

claimDailyQuest()
claimSeasonPass()
claimSevenDaily()
claimGuidebook()
claimUpdateLog()

local dailyLoginPending,
    dailyLoginRows =
        inspectDailyLogin()

spendSeasonTickets()

local function writeRewardAudit()
    if type(writefile)
        ~= "function"
    then
        return
    end

    local d =
        pdata()
        or {}

    local lines = {
        "Version=V59.8",
    }

    -- DailyQuest pending milestones.
    local dqPending = {}

    local dq =
        d.DailyQuest

    if type(dq)
        == "table"
        and type(
            dq.RewardState
        ) == "table"
    then
        for k, v in pairs(
            dq.RewardState
        ) do
            if v == false then
                table.insert(
                    dqPending,
                    tostring(k)
                )
            end
        end
    end

    table.sort(dqPending)

    table.insert(
        lines,
        "DailyQuestPending="
            .. table.concat(
                dqPending,
                ","
            )
    )

    -- SevenDaily pending unlocked days.
    local sevenPending = {}

    local seven =
        d.SevenDaily

    if type(seven)
        == "table"
    then
        local unlock =
            math.clamp(
                num(
                    seven.UnlockDay
                ),
                0,
                7
            )

        local claimed =
            seven.Claimed
            or {}

        for day = 1, unlock do
            if claimed[
                "Day"
                .. tostring(day)
            ] == false
            then
                table.insert(
                    sevenPending,
                    tostring(day)
                )
            end
        end
    end

    table.insert(
        lines,
        "SevenDailyPending="
            .. table.concat(
                sevenPending,
                ","
            )
    )

    -- Update logs still unclaimed after fixed claimant.
    local updatePending = {}

    if type(ResUpdateLog)
            == "table"
        and type(
            ResUpdateLog.__index
        ) == "table"
    then
        local state =
            d.UpdateLog
            or {}

        for _, id in ipairs(
            ResUpdateLog.__index
        ) do
            if ResUpdateLog[id]
                and state[id]
                    ~= true
            then
                table.insert(
                    updatePending,
                    tostring(id)
                )
            end
        end
    end

    table.insert(
        lines,
        "UpdateLogPending="
            .. table.concat(
                updatePending,
                ","
            )
    )

    table.insert(
        lines,
        "DailyLoginFreePending="
            .. tostring(
                dailyLoginPending
            )
    )

    for _, row in ipairs(
        dailyLoginRows
    ) do
        table.insert(
            lines,
            "DailyLogin="
                .. tostring(
                    row.Day
                )
                .. "|"
                .. tostring(
                    row.Id
                )
        )
    end

    pcall(
        writefile,
        "IronSoul_LastRewardAudit_V59_8.txt",
        table.concat(
            lines,
            "\n"
        )
    )
end

writeRewardAudit()

--========================================================--
-- SWORD SKILL TREE
--========================================================--

local function activateSwordSkills()
    if not SkillTreeUtil
        or not SkillTreeUtil.RemoteEvent
    then
        return
    end

    local d = pdata()

    local unlock =
        d
        and d.SkillTree
        and d.SkillTree.Unlock
        and d.SkillTree.Unlock.Sword
        or {}

    local active =
        d
        and d.SkillTree
        and d.SkillTree.Active
        and d.SkillTree.Active.Sword
        or {}

    for i = 1, 7 do
        local key =
            "UnlockSkill"
            .. tostring(i)

        if unlock[key] == true
            and active[key] ~= true
        then
            action(
                "Activate Sword "
                    .. key
            )

            SkillTreeUtil.RemoteEvent:
                FireServer(
                    "ActiveSkill",
                    "Sword",
                    key
                )

            waitUntil(
                function()
                    local now =
                        pdata()

                    return now
                        and now.SkillTree
                        and now.SkillTree.Active
                        and now.SkillTree.Active.Sword
                        and now.SkillTree.Active.Sword[key]
                            == true
                end,
                4
            )
        end
    end
end

activateSwordSkills()

--========================================================--
-- FORGE MAIN_009 ONLY WHEN ACTIVE
--========================================================--

local function taskState(id)
    local d = pdata()

    return d
        and d.TaskData
        and d.TaskData.Tasks
        and d.TaskData.Tasks[id]
end

local function taskCompleted(id)
    if TaskUtil
        and type(
            TaskUtil.IsCompleted
        ) == "function"
    then
        local ok, value =
            pcall(function()
                return TaskUtil:
                    IsCompleted(
                        LocalPlayer,
                        id
                    )
            end)

        if ok then
            return value == true
        end
    end

    local s =
        taskState(id)

    return s
        and s.Completed == true
        or false
end

local function forgeData()
    if not ForgeUtil
        or type(
            ForgeUtil.GetForgeData
        ) ~= "function"
    then
        return nil
    end

    local ok, value =
        pcall(function()
            return ForgeUtil:
                GetForgeData(
                    LocalPlayer
                )
        end)

    return ok
        and type(value)
            == "table"
        and value
        or nil
end

local function forgeQTE()
    if not ForgeUtil
        or type(
            ForgeUtil.GetQTE
        ) ~= "function"
    then
        return nil
    end

    local ok, value =
        pcall(function()
            return ForgeUtil:
                GetQTE(
                    LocalPlayer
                )
        end)

    return ok
        and type(value)
            == "table"
        and value
        or nil
end

local function forgeInvoke(...)
    if not ForgeRF then
        return false
    end

    local args = {...}

    local packed =
        table.pack(
            pcall(function()
                return ForgeRF:
                    InvokeServer(
                        table.unpack(args)
                    )
            end)
        )

    if not packed[1] then
        return false,
            packed[2]
    end

    return true,
        table.unpack(
            packed,
            2,
            packed.n
        )
end

local function requiredQTE(
    oresNum
)
    if ForgeUtil
        and type(
            ForgeUtil.GetForgeQTE
        ) == "function"
    then
        local ok, cfg =
            pcall(function()
                return ForgeUtil:
                    GetForgeQTE(
                        oresNum
                    )
            end)

        if ok
            and type(cfg)
                == "table"
            and tonumber(cfg.QT)
        then
            return tonumber(cfg.QT)
        end
    end

    return math.max(
        1,
        num(oresNum)
    )
end

local function completeForgeQTE()
    local f =
        forgeData()

    if not f
        or f.ForgeState
            ~= "QTE"
    then
        return true
    end

    local need =
        requiredQTE(
            f.OresNum
        )

    for _ = 1, need + 5 do
        local q =
            forgeQTE()

        if not q then
            return false
        end

        if num(q.Times)
            >= need
        then
            return true
        end

        if not q.UUID then
            return false
        end

        local old =
            num(q.Times)

        local ok =
            forgeInvoke(
                "QTE",
                {
                    UUID = q.UUID,
                    Rating = 15,
                }
            )

        if not ok then
            return false
        end

        if not waitUntil(
            function()
                local nq =
                    forgeQTE()

                return nq
                    and num(nq.Times)
                        > old
            end,
            5
        ) then
            return false
        end
    end

    return false
end

local function recoverForge()
    local f =
        forgeData()

    if not f
        or not f.ForgeState
    then
        return true
    end

    action(
        "Recover pending forge "
            .. tostring(
                f.ForgeState
            )
    )

    if f.ForgeState == "QTE" then
        if not completeForgeQTE() then
            return false
        end

        local ok, success =
            forgeInvoke(
                "ForgeFinish"
            )

        if not ok
            or success ~= true
        then
            return false
        end

        task.wait(0.25)
    end

    f =
        forgeData()

    if f
        and (
            f.ForgeState == "Result"
            or f.Result ~= nil
        )
    then
        forgeInvoke(
            "ForgeResult",
            true
        )

        task.wait(0.25)
    end

    return true
end

local function forgeSwordPyrite3()
    if not recoverForge() then
        return false
    end

    local before =
        pdata()

    local beforeOre =
        before
        and before.Ores
        and num(
            before.Ores.Pyrite
        )
        or 0

    local beforeOwned =
        inventoryCount()

    if beforeOre < 3 then
        return false
    end

    local ok, accepted =
        forgeInvoke(
            "DropOres",
            {
                Pyrite = 3,
            },
            "Weapon",
            nil
        )

    if not ok
        or accepted ~= true
    then
        return false
    end

    if not waitUntil(
        function()
            local f =
                forgeData()

            return f
                and f.ForgeState
                    == "QTE"
        end,
        5
    ) then
        return false
    end

    if not completeForgeQTE() then
        return false
    end

    local finishOk,
        success =
            forgeInvoke(
                "ForgeFinish"
            )

    if not finishOk
        or success ~= true
    then
        return false
    end

    waitUntil(
        function()
            local f =
                forgeData()

            return f
                and (
                    f.ForgeState
                        == "Result"
                    or f.Result
                        ~= nil
                )
        end,
        5
    )

    forgeInvoke(
        "ForgeResult",
        true
    )

    return waitUntil(
        function()
            local now =
                pdata()

            local oreNow =
                now
                and now.Ores
                and num(
                    now.Ores.Pyrite
                )
                or 0

            return oreNow
                    <= beforeOre - 3
                and inventoryCount()
                    >= beforeOwned + 1
        end,
        7
    ) ~= nil
end

local function oreTotalAndMax()
    if not ForgeUtil then
        return 0,
            nil,
            {}
    end

    local ores = {}

    if type(
        ForgeUtil.GetOres
    ) == "function"
    then
        local ok, value =
            pcall(function()
                return ForgeUtil:
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

    local max = nil

    if type(
        ForgeUtil.GetMax
    ) == "function"
    then
        local ok, value =
            pcall(function()
                return ForgeUtil:
                    GetMax(
                        LocalPlayer
                    )
            end)

        if ok then
            max =
                tonumber(value)
        end
    end

    local total = 0

    for _, amount in pairs(ores) do
        if type(amount)
            == "number"
        then
            total += amount
        end
    end

    return total,
        max,
        ores
end

local function oreQuality(id)
    local rarity = 0
    local multiplier = 0
    local hell = 0
    local price = 0

    if EquipmentUtil
        and type(
            EquipmentUtil.GetOreRarity
        ) == "function"
    then
        pcall(function()
            rarity =
                num(
                    EquipmentUtil:
                        GetOreRarity(id)
                )
        end)
    end

    if ForgeUtil
        and type(
            ForgeUtil.GetDef
        ) == "function"
    then
        local ok, def =
            pcall(function()
                return ForgeUtil:
                    GetDef(id)
            end)

        if ok
            and type(def)
                == "table"
        then
            rarity =
                math.max(
                    rarity,
                    num(
                        def.Rarity
                        or def.Level
                        or def.Tier
                    )
                )

            multiplier =
                num(
                    def.ValueMultiplier
                )

            hell =
                num(
                    def.Hellweight
                )

            price =
                num(
                    def.Price
                )
        end
    end

    return rarity * 1000000000
        + multiplier * 1000000
        + hell * 1000
        + price
end

local function buildBestOreMap(
    amountNeeded
)
    local _, _, ores =
        oreTotalAndMax()

    local rows = {}

    for id, amount in pairs(ores) do
        amount =
            math.floor(
                num(amount)
            )

        if amount > 0 then
            table.insert(
                rows,
                {
                    ID = id,
                    Amount = amount,
                    Score =
                        oreQuality(id),
                }
            )
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

            return a.Amount
                > b.Amount
        end
    )

    local map = {}
    local used = 0
    local highest = nil

    for _, row in ipairs(rows) do
        if used
            >= amountNeeded
        then
            break
        end

        local take =
            math.min(
                row.Amount,
                amountNeeded
                    - used
            )

        if take > 0 then
            map[row.ID] = take
            used += take

            if not highest then
                highest =
                    row.ID
            end
        end
    end

    return map,
        used,
        highest
end

local function forgeOreMap(
    oreMap,
    forgeType
)
    if not recoverForge() then
        return false
    end

    local beforeTotal =
        select(
            1,
            oreTotalAndMax()
        )

    local beforeOwned =
        inventoryCount()

    local requested = 0

    for _, amount in pairs(
        oreMap
    ) do
        requested +=
            num(amount)
    end

    if requested < 3 then
        return false
    end

    local ok, accepted =
        forgeInvoke(
            "DropOres",
            oreMap,
            forgeType,
            nil
        )

    if not ok
        or accepted ~= true
    then
        return false
    end

    if not waitUntil(
        function()
            local f =
                forgeData()

            return f
                and f.ForgeState
                    == "QTE"
        end,
        5
    ) then
        return false
    end

    if not completeForgeQTE() then
        return false
    end

    local finishOk,
        success =
            forgeInvoke(
                "ForgeFinish"
            )

    if not finishOk
        or success ~= true
    then
        return false
    end

    waitUntil(
        function()
            local f =
                forgeData()

            return f
                and (
                    f.ForgeState
                        == "Result"
                    or f.Result
                        ~= nil
                )
        end,
        5
    )

    local resultData =
        forgeData()

    local result =
        resultData
        and resultData.Result

    forgeInvoke(
        "ForgeResult",
        true
    )

    local verified =
        waitUntil(
            function()
                local nowTotal =
                    select(
                        1,
                        oreTotalAndMax()
                    )

                return nowTotal
                    <= beforeTotal
                        - requested
            end,
            6
        )

    if verified then
        action(
            "Smart forge "
                .. tostring(forgeType)
                .. " ores="
                .. tostring(requested)
                .. " result="
                .. tostring(
                    result
                    and result.ID
                    or "?"
                )
        )
    end

    return verified ~= nil,
        result
end


local function resolveMain009()
    if taskCompleted(
        "Main_009"
    ) then
        return
    end

    local live =
        taskState(
            "Main_009"
        )

    if type(live)
        ~= "table"
    then
        log(
            "Main_009 not active; no tutorial forge."
        )

        return
    end

    local progress =
        num(
            live.Progress
        )

    local remaining =
        math.max(
            0,
            2 - progress
        )

    for i = 1, remaining do
        local d = pdata()

        local pyrite =
            d
            and d.Ores
            and num(
                d.Ores.Pyrite
            )
            or 0

        if pyrite < 3 then
            log(
                "Main_009 blocked: Pyrite<3"
            )

            break
        end

        action(
            "Main_009 Sword forge "
                .. tostring(i)
                .. "/"
                .. tostring(
                    remaining
                )
        )

        if not forgeSwordPyrite3() then
            log(
                "Main_009 forge failed verification."
            )

            break
        end

        task.wait(0.3)

        if taskCompleted(
            "Main_009"
        ) then
            break
        end
    end
end

resolveMain009()

--========================================================--
-- PETS
--========================================================--

local function equippedPets()
    if PetsUtil
        and type(
            PetsUtil.GetEquippedPets
        ) == "function"
    then
        local ok, value =
            pcall(function()
                return PetsUtil:
                    GetEquippedPets(
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
        and d.Pets
        and d.Pets.Equipped
        or {}
end

local function petPass()
    if PetsHatchUtil
        and PetsHatchUtil.RemoteEvent
        and type(
            PetsHatchUtil.IsCompleted
        ) == "function"
    then
        local d = pdata()

        local slots =
            d
            and d.PetHatch
            and d.PetHatch.Slots
            or {}

        for index in pairs(slots) do
            if type(index)
                == "number"
            then
                local ok, done =
                    pcall(function()
                        return PetsHatchUtil:
                            IsCompleted(
                                LocalPlayer,
                                index
                            )
                    end)

                if ok
                    and done == true
                then
                    action(
                        "Claim pet hatch "
                            .. tostring(index)
                    )

                    PetsHatchUtil.RemoteEvent:
                        FireServer(
                            "Claim",
                            index
                        )

                    task.wait(0.2)
                end
            end
        end
    end

    local d = pdata()

    local owned =
        d
        and d.Pets
        and d.Pets.Owned
        or {}

    if count(owned) > 0
        and count(
            equippedPets()
        ) == 0
        and PetsUtil
        and PetsUtil.RemoteEvent
    then
        action(
            "Pets EquipBest"
        )

        PetsUtil.RemoteEvent:
            FireServer(
                "EquipBest"
            )

        waitUntil(
            function()
                return count(
                    equippedPets()
                ) > 0
            end,
            5
        )
    end
end

petPass()

--========================================================--
-- EQUIPMENT
--========================================================--

local function equipmentPower(uuid)
    if not EquipmentUtil
        or type(
            EquipmentUtil.GetEquipmentPowerByUUID
        ) ~= "function"
    then
        return 0
    end

    local ok, value =
        pcall(function()
            return EquipmentUtil:
                GetEquipmentPowerByUUID(
                    LocalPlayer,
                    uuid
                )
        end)

    return ok
        and num(value)
        or 0
end

local function equipmentBase(uuid)
    if not EquipmentCombat
        or type(
            EquipmentCombat.GetDmgOrHp
        ) ~= "function"
    then
        return 0
    end

    local ok, value =
        pcall(function()
            return EquipmentCombat:
                GetDmgOrHp(
                    LocalPlayer,
                    uuid
                )
        end)

    return ok
        and num(value)
        or 0
end

local function ownedRows()
    local d = pdata()

    local owned =
        d
        and d.Equipment
        and d.Equipment.Owned
        or {}

    local rows = {}

    for uuid, item in pairs(owned) do
        if type(item)
            == "table"
        then
            table.insert(
                rows,
                {
                    UUID = uuid,
                    Item = item,
                    Power =
                        equipmentPower(
                            uuid
                        ),
                    Base =
                        equipmentBase(
                            uuid
                        ),
                }
            )
        end
    end

    return rows
end

local function bestWeapon(class)
    local best = nil

    for _, row in ipairs(
        ownedRows()
    ) do
        local item =
            row.Item

        if item.Type == "Weapon"
            and item.Class == class
        then
            if not best
                or row.Base
                    > best.Base
                or (
                    row.Base
                        == best.Base
                    and row.Power
                        > best.Power
                )
                or (
                    row.Base
                        == best.Base
                    and row.Power
                        == best.Power
                    and num(
                        item.Fortify
                    )
                        > num(
                            best.Item.Fortify
                        )
                )
            then
                best = row
            end
        end
    end

    return best
end

local function bestArmor(class)
    local best = nil

    for _, row in ipairs(
        ownedRows()
    ) do
        local item =
            row.Item

        if item.Type == "Armor"
            and item.Class == class
        then
            if not best
                or row.Power
                    > best.Power
            then
                best = row
            end
        end
    end

    return best
end

local function equipWeapon(
    row,
    slot
)
    if not row
        or not EquipmentRE
    then
        return false
    end

    local d = pdata()

    local current =
        d
        and d.Equipment
        and d.Equipment.EquipSlots
        and d.Equipment.EquipSlots[slot]

    if current == row.UUID then
        return true
    end

    action(
        "Equip "
            .. tostring(
                row.Item.Class
            )
            .. " "
            .. tostring(
                row.Item.ID
            )
            .. " Base="
            .. tostring(
                row.Base
            )
            .. " Power="
            .. tostring(
                row.Power
            )
            .. " -> "
            .. tostring(slot)
    )

    EquipmentRE:
        FireServer(
            "Equip",
            row.UUID,
            slot
        )

    return waitUntil(
        function()
            local now =
                pdata()

            return now
                and now.Equipment
                and now.Equipment.EquipSlots
                and now.Equipment.EquipSlots[slot]
                    == row.UUID
        end,
        5
    ) ~= nil
end

local function equipArmor(row)
    if not row
        or not EquipmentRE
    then
        return false
    end

    local class =
        row.Item.Class

    local d = pdata()

    local current =
        d
        and d.Equipment
        and d.Equipment.EquipSlots
        and d.Equipment.EquipSlots[class]

    if current == row.UUID then
        return true
    end

    action(
        "Equip armor "
            .. tostring(class)
            .. " "
            .. tostring(
                row.Item.ID
            )
    )

    EquipmentRE:
        FireServer(
            "Equip",
            row.UUID
        )

    return waitUntil(
        function()
            local now =
                pdata()

            return now
                and now.Equipment
                and now.Equipment.EquipSlots
                and now.Equipment.EquipSlots[class]
                    == row.UUID
        end,
        5
    ) ~= nil
end

local function equipmentPass()
    local d = pdata()

    if not d
        or not d.Equipment
    then
        return
    end

    local slots =
        d.Equipment.EquipSlots
        or {}

    local active =
        d.Equipment.CurWeaponSlot
        or "Weapon"

    if active ~= "Weapon"
        and active ~= "Weapon2"
    then
        active = "Weapon"
    end

    local backup =
        active == "Weapon"
        and "Weapon2"
        or "Weapon"

    local sword =
        bestWeapon(
            "Sword"
        )

    local staff =
        bestWeapon(
            "Staff"
        )

    if sword then
        equipWeapon(
            sword,
            active
        )
    elseif staff then
        equipWeapon(
            staff,
            active
        )
    end

    local secondUnlocked =
        slots[backup] ~= nil

    if not secondUnlocked
        and EquipmentSlots
        and type(
            EquipmentSlots.IsUnlockWeaponSlot
        ) == "function"
    then
        pcall(function()
            secondUnlocked =
                EquipmentSlots:
                    IsUnlockWeaponSlot(
                        LocalPlayer,
                        backup
                    ) == true
        end)
    end

    if secondUnlocked
        and staff
    then
        equipWeapon(
            staff,
            backup
        )
    end

    equipArmor(
        bestArmor(
            "Helmet"
        )
    )

    equipArmor(
        bestArmor(
            "Breastplate"
        )
    )
end

equipmentPass()

--========================================================--
-- EARLY ATTACK ATTRIBUTES
--========================================================--

local function spendAttackPoints()
    if not AttributeUpgradeUtil
        or not AttributeUpgradeUtil.RemoteEvent
    then
        return
    end

    for _ = 1, 30 do
        local d = pdata()

        local attr =
            d
            and d.AttributeUpgrade
            or {}

        local lvs =
            attr.AttributeLvs
            or {}

        local remaining =
            num(
                attr.RemainingPoint
            )

        local atk =
            num(
                lvs.AtkBonusValue
            )

        if remaining <= 0
            or atk
                >= CFG.ATTACK_SOFT_CAP
        then
            break
        end

        local expectedAtk =
            atk + 1

        local expectedRemaining =
            remaining - 1

        action(
            "Attribute Attack "
                .. tostring(atk)
                .. " -> "
                .. tostring(
                    expectedAtk
                )
        )

        AttributeUpgradeUtil.RemoteEvent:
            FireServer(
                "Upgrade",
                {
                    AtkBonusValue = 1,
                }
            )

        local verified =
            waitUntil(
                function()
                    local now =
                        pdata()

                    local a =
                        now
                        and now.AttributeUpgrade

                    local lv =
                        a
                        and a.AttributeLvs
                        and num(
                            a.AttributeLvs.AtkBonusValue
                        )
                        or 0

                    local rem =
                        a
                        and num(
                            a.RemainingPoint
                        )
                        or 0

                    return lv
                            == expectedAtk
                        and rem
                            == expectedRemaining
                end,
                4
            )

        if not verified then
            log(
                "Attribute write failed verification; stop spending."
            )

            break
        end
    end
end

spendAttackPoints()

--========================================================--
-- SAFE INVENTORY CLEANUP
--========================================================--

local function hasEnchantments(
    item
)
    local ench =
        item
        and item.Enchantments

    if type(ench)
        ~= "table"
    then
        return false
    end

    for _, v in pairs(ench) do
        if type(v)
            == "table"
            and v.Id
        then
            return true
        end
    end

    return false
end

local function protectedEquipment()
    local d = pdata()

    local protected = {}

    local slots =
        d
        and d.Equipment
        and d.Equipment.EquipSlots
        or {}

    for _, uuid in pairs(slots) do
        if type(uuid)
            == "string"
            and uuid ~= ""
        then
            protected[uuid] =
                "equipped"
        end
    end

    local byClass = {}

    for _, row in ipairs(
        ownedRows()
    ) do
        local item =
            row.Item

        local class =
            tostring(
                item.Class
                or item.Type
                or "Unknown"
            )

        byClass[class] =
            byClass[class]
            or {}

        table.insert(
            byClass[class],
            row
        )

        if num(item.Fortify) > 1 then
            protected[row.UUID] =
                "fortified"
        elseif item.Locked == true
            or item.Lock == true
        then
            protected[row.UUID] =
                "locked"
        elseif hasEnchantments(item) then
            protected[row.UUID] =
                "enchanted"
        end
    end

    for class, list in pairs(
        byClass
    ) do
        table.sort(
            list,
            function(a,b)
                if a.Item.Type
                        == "Weapon"
                    and b.Item.Type
                        == "Weapon"
                    and a.Base
                        ~= b.Base
                then
                    return a.Base
                        > b.Base
                end

                return a.Power
                    > b.Power
            end
        )

        for i = 1,
            math.min(
                2,
                #list
            )
        do
            protected[
                list[i].UUID
            ] =
                protected[
                    list[i].UUID
                ]
                or (
                    "top_"
                    .. class
                )
        end
    end

    return protected
end

local function inventoryCleanup()
    local before =
        inventoryCount()

    if before
        < CFG.INVENTORY_CLEAN_AT
    then
        log(
            "Inventory cleanup not needed: "
                .. tostring(before)
        )

        return
    end

    if not EquipmentRE then
        return
    end

    local protected =
        protectedEquipment()

    local candidates = {}

    for _, row in ipairs(
        ownedRows()
    ) do
        if not protected[
            row.UUID
        ]
        then
            table.insert(
                candidates,
                row
            )
        end
    end

    table.sort(
        candidates,
        function(a,b)
            if a.Power
                ~= b.Power
            then
                return a.Power
                    < b.Power
            end

            return a.Base
                < b.Base
        end
    )

    local need =
        math.max(
            0,
            before
                - CFG.INVENTORY_TARGET
        )

    local sell = {}

    for i = 1,
        math.min(
            need,
            #candidates
        )
    do
        table.insert(
            sell,
            candidates[i].UUID
        )
    end

    if #sell == 0 then
        log(
            "Inventory high, but nothing safely sellable."
        )

        return
    end

    action(
        "Sell safe low-value equipment x"
            .. tostring(#sell)
    )

    EquipmentRE:
        FireServer(
            "Sell",
            sell
        )

    waitUntil(
        function()
            return inventoryCount()
                <= before
                    - #sell
        end,
        5
    )
end

inventoryCleanup()

local SMART_FORGE_STATUS_FILE =
    "IronSoul_LastSmartForge_V59_8.txt"

local function writeSmartForgeStatus(lines)
    if type(writefile)
        == "function"
    then
        pcall(
            writefile,
            SMART_FORGE_STATUS_FILE,
            table.concat(
                lines,
                "\n"
            )
        )
    end
end

local function smartForgeFullOreBag()
    local initialTotal,
        initialMax =
            oreTotalAndMax()

    if not initialMax
        or initialTotal
            < initialMax
    then
        return true
    end

    local target =
        math.max(
            20,
            math.floor(
                initialMax * 0.70
            )
        )

    local initialPower =
        power()

    local initialInventory =
        inventoryCount()

    important(
        "Ore bag "
            .. tostring(initialTotal)
            .. "/"
            .. tostring(initialMax)
            .. " | smart forge"
    )

    local forged = 0
    local results = {}

    -- If armor slots are missing, make the first craft specifically useful.
    local d = pdata()

    local slots =
        d
        and d.Equipment
        and d.Equipment.EquipSlots
        or {}

    local needHelmet =
        not slots.Helmet

    local needBreastplate =
        not slots.Breastplate

    local total =
        initialTotal

    local max =
        initialMax

    while total > target
        and forged < 10
    do
        if inventoryCount() >= 84 then
            equipmentPass()
            inventoryCleanup()
        end

        if inventoryCount() >= 100 then
            important(
                "Ore forge paused | equipment inventory full"
            )

            break
        end

        local excess =
            total - target

        local amount
        local forgeType =
            "Armor"

        if needHelmet then
            amount = 3
            needHelmet = false

        elseif needBreastplate then
            amount =
                math.min(
                    22,
                    excess
                )

            if amount < 3 then
                amount = 3
            end

            needBreastplate = false

        else
            amount =
                math.min(
                    22,
                    excess
                )

            if amount < 3 then
                amount = 3
            end
        end

        amount =
            math.min(
                amount,
                total
            )

        local oreMap,
            used,
            highest =
                buildBestOreMap(
                    amount
                )

        if used < 3 then
            break
        end

        local ok,
            result =
                forgeOreMap(
                    oreMap,
                    forgeType
                )

        if not ok then
            important(
                "Ore forge failed | stopping safely"
            )

            break
        end

        forged += 1

        table.insert(
            results,
            {
                Craft = forged,
                Ores = used,
                HighestOre =
                    highest,
                ID =
                    result
                    and result.ID
                    or "?",
                Class =
                    result
                    and result.Class
                    or "?",
                MaxOre =
                    result
                    and result.MaxOre
                    or "?",
                Rating =
                    result
                    and result.Rating
                    or "?",
                Factor =
                    result
                    and result.Factor
                    or "?",
            }
        )

        equipmentPass()

        total,
            max =
                oreTotalAndMax()

        task.wait(0.18)
    end

    equipmentPass()
    inventoryCleanup()
    equipmentPass()

    local finalTotal,
        finalMax =
            oreTotalAndMax()

    local finalPower =
        power()

    local finalInventory =
        inventoryCount()

    local lines = {
        "Version=V59.8",
        "OreBefore="
            .. tostring(
                initialTotal
            )
            .. "/"
            .. tostring(
                initialMax
            ),
        "OreTarget="
            .. tostring(target),
        "OreAfter="
            .. tostring(
                finalTotal
            )
            .. "/"
            .. tostring(
                finalMax
            ),
        "Crafts="
            .. tostring(forged),
        "PowerBefore="
            .. tostring(
                initialPower
            ),
        "PowerAfter="
            .. tostring(
                finalPower
            ),
        "EquipmentInventoryBefore="
            .. tostring(
                initialInventory
            ),
        "EquipmentInventoryAfter="
            .. tostring(
                finalInventory
            ),
    }

    for _, row in ipairs(results) do
        table.insert(
            lines,
            "Craft"
                .. tostring(
                    row.Craft
                )
                .. "="
                .. tostring(
                    row.Class
                )
                .. "|"
                .. tostring(
                    row.ID
                )
                .. "|ores="
                .. tostring(
                    row.Ores
                )
                .. "|highest="
                .. tostring(
                    row.HighestOre
                )
                .. "|MaxOre="
                .. tostring(
                    row.MaxOre
                )
                .. "|Rating="
                .. tostring(
                    row.Rating
                )
                .. "|Factor="
                .. tostring(
                    row.Factor
                )
        )
    end

    writeSmartForgeStatus(
        lines
    )

    important(
        "Ore forge | "
            .. tostring(
                initialTotal
            )
            .. "→"
            .. tostring(
                finalTotal
            )
            .. " | "
            .. tostring(forged)
            .. " crafts | Power "
            .. tostring(
                initialPower
            )
            .. "→"
            .. tostring(
                finalPower
            )
    )

    return finalMax
        and finalTotal
            < finalMax
end

smartForgeFullOreBag()

-- Re-run equipment in case rewards/forge changed best options.
equipmentPass()

snapshot("AFTER_LOBBY_PASS")

-- V59.7 BAG GATE:
-- equipment cleanup above gets the first chance to make space.
-- If the bag is still full, never launch another no-reward dungeon.
local oreFull,
    oreUsed,
    oreMax =
        lobbyOreBagStatus()

local equipmentFull =
    lobbyEquipmentBagFull()

if oreFull
    or equipmentFull
then
    important(
        oreFull
        and (
            "Bag full | Ores "
            .. tostring(
                oreUsed
            )
            .. "/"
            .. tostring(
                oreMax
            )
            .. " | dungeon paused"
        )
        or (
            "Bag full | Equipment | dungeon paused"
        )
    )

    local old =
        readJournal()

    writeJournal({
        State = "BAG_FULL",
        Decision = "WAIT_FOR_BAG_SPACE",
        World = old.World or "?",
        Diff = old.Diff or "?",
        DirectRepeats = 0,
        FailureCount = old.FailureCount or 0,
        FailPower = old.FailPower or 0,
        Level = level(),
        Power = power(),
        BagReason =
            oreFull
            and "ORES"
            or "EQUIPMENT",
        OreUsed = oreUsed or "?",
        OreMax = oreMax or "?",
        UpdatedAt = os.time(),
    })

    return
end

--========================================================--
-- STORY PLANNER
--========================================================--

local STORY_ORDER = {
    World1 = 1,
    World2 = 2,
    World3 = 3,
    World4 = 4,
}

local rounds = {}

local function addRound(cfg)
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

if type(ResWorldRound.__index)
    == "table"
then
    for _, key in ipairs(
        ResWorldRound.__index
    ) do
        addRound(
            ResWorldRound[key]
        )
    end
else
    for _, cfg in pairs(
        ResWorldRound
    ) do
        addRound(cfg)
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

local function clearData()
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

local nextStory = nil
local highestCleared = nil

for _, cfg in ipairs(
    rounds
) do
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

local target = nil
local decision = nil

if nextStory then
    local recLv =
        num(
            nextStory.RecPlayerLv
        )

    local recPower =
        num(
            nextStory.RecBattlePower
        )

    if level() >= recLv
        and power() >= recPower
    then
        target =
            nextStory

        decision =
            "ADVANCE_STORY"
    elseif highestCleared then
        target =
            highestCleared

        decision =
            "REPEAT_STORY"
    else
        return stop(
            "Next Story exists but account does not meet recommendation "
                .. "and there is no cleared stage to repeat."
        )
    end
elseif highestCleared then
    target =
        highestCleared

    decision =
        "REPEAT_HIGHEST_CLEARED"
else
    return stop(
        "No available Story target."
    )
end

plan(
    "DECISION="
        .. tostring(decision)
)

plan(
    "TARGET="
        .. tostring(
            target.WorldId
        )
        .. " Diff="
        .. tostring(
            target.DiffLevel
        )
)

plan(
    "ACCOUNT Level="
        .. tostring(level())
        .. " Power="
        .. tostring(power())
        .. " TargetRecLv="
        .. tostring(
            target.RecPlayerLv
        )
        .. " TargetRecPower="
        .. tostring(
            target.RecBattlePower
        )
)

--========================================================--
-- MATCHMAKING
--========================================================--

local function getRoot()
    local char =
        LocalPlayer.Character
        or LocalPlayer.CharacterAdded:
            Wait()

    return char:
        WaitForChild(
            "HumanoidRootPart",
            10
        )
end

local function roomContainer()
    return Workspace:
        FindFirstChild(
            "MatchRoom"
        )
end

local function enteredRoomId()
    return LocalPlayer:
        GetAttribute(
            "EnterRoomId"
        )
end

local function roomById(id)
    local c =
        roomContainer()

    return c
        and id
        and c:
            FindFirstChild(
                tostring(id)
            )
end

local function isFreeRoom(room)
    local owner =
        tonumber(
            room:
                GetAttribute(
                    "HomeownerId"
                )
        )

    return not owner
        or owner == 0
        or owner
            == LocalPlayer.UserId
end

local function findFreeRoom()
    local c =
        roomContainer()

    if not c then
        return nil
    end

    local rooms = {}

    for _, room in ipairs(
        c:GetChildren()
    ) do
        if (
            room:IsA("Model")
            or room:IsA("Folder")
        )
            and isFreeRoom(room)
        then
            table.insert(
                rooms,
                room
            )
        end
    end

    table.sort(
        rooms,
        function(a,b)
            return a.Name < b.Name
        end
    )

    return rooms[1]
end

local function touchParts(room)
    local preferred = {}
    local fallback = {}

    for _, obj in ipairs(
        room:GetDescendants()
    ) do
        if obj:IsA("BasePart") then
            local low =
                string.lower(
                    obj.Name
                )

            local touch =
                obj:
                    FindFirstChildOfClass(
                        "TouchTransmitter"
                    ) ~= nil

            if touch
                or string.find(
                    low,
                    "enter",
                    1,
                    true
                )
                or string.find(
                    low,
                    "trigger",
                    1,
                    true
                )
                or string.find(
                    low,
                    "touch",
                    1,
                    true
                )
            then
                table.insert(
                    preferred,
                    obj
                )
            else
                table.insert(
                    fallback,
                    obj
                )
            end
        end
    end

    return #preferred > 0
        and preferred
        or fallback
end

local function waitRoom(
    expected,
    timeout
)
    return waitUntil(
        function()
            local id =
                enteredRoomId()

            if id
                and id ~= ""
            then
                return tostring(id)
            end
        end,
        timeout,
        0.05
    )
end

local function enterRoom(room)
    local existing =
        enteredRoomId()

    if existing
        and existing ~= ""
    then
        return true
    end

    local root =
        getRoot()

    if not root then
        return false
    end

    local original =
        root.CFrame

    local parts =
        touchParts(room)

    matchLog(
        "Enter room "
            .. room.Name
            .. " candidates="
            .. tostring(#parts)
    )

    if type(firetouchinterest)
        == "function"
    then
        for _, part in ipairs(
            parts
        ) do
            pcall(function()
                firetouchinterest(
                    root,
                    part,
                    0
                )

                task.wait(0.05)

                firetouchinterest(
                    root,
                    part,
                    1
                )
            end)

            if waitRoom(
                room.Name,
                0.45
            ) then
                return true
            end
        end
    end

    for _, part in ipairs(
        parts
    ) do
        pcall(function()
            root.CFrame =
                part.CFrame
                * CFrame.new(
                    0,
                    2.5,
                    0
                )
        end)

        if waitRoom(
            room.Name,
            0.7
        ) then
            return true
        end
    end

    if room:IsA("Model") then
        pcall(function()
            root.CFrame =
                room:GetPivot()
                * CFrame.new(
                    0,
                    3,
                    0
                )
        end)

        if waitRoom(
            room.Name,
            1.5
        ) then
            return true
        end
    end

    pcall(function()
        root.CFrame =
            original
    end)

    return false
end

local room = nil

local existing =
    enteredRoomId()

if existing
    and existing ~= ""
then
    room =
        roomById(
            existing
        )

    matchLog(
        "Using existing room "
            .. tostring(existing)
    )
else
    room =
        findFreeRoom()

    if not room then
        return stop(
            "No free MatchRoom available."
        )
    end

    matchLog(
        "Selected free room "
            .. room.Name
    )

    if not enterRoom(room) then
        return stop(
            "Could not enter free room."
        )
    end
end

local roomId =
    enteredRoomId()

if not roomId
    or roomId == ""
then
    return stop(
        "EnterRoomId missing."
    )
end

matchLog(
    "ENTER VERIFIED "
        .. tostring(roomId)
)

--========================================================--
-- QUEUE CONTINUOUS BOOTSTRAP BEFORE CREATE
--========================================================--

local queued =
    queueBootstrap(
        "lobby -> dungeon"
    )

if not queued then
    return stop(
        "Could not queue V59 bootstrap before dungeon teleport."
    )
end

matchLog(
    "V59 bootstrap queued."
)

--========================================================--
-- SELECT + CREATE SOLO STORY
--========================================================--

if not WorldUtil.RemoteEvent then
    return stop(
        "WorldUtil.RemoteEvent missing."
    )
end

action(
    "SelectWorld "
        .. tostring(
            target.WorldId
        )
        .. " Diff="
        .. tostring(
            target.DiffLevel
        )
)

WorldUtil.RemoteEvent:
    FireServer(
        "SelectWorld",
        target.WorldId,
        target.DiffLevel
    )

task.wait(0.18)

action(
    "CreatRoom "
        .. tostring(
            target.WorldId
        )
        .. " Diff="
        .. tostring(
            target.DiffLevel
        )
        .. " solo"
)

GameMatchRE:
    FireServer(
        "CreatRoom",
        target.WorldId,
        target.DiffLevel,
        1
    )

do
    local old =
        readJournal()

    local oldWorld =
        old.World

    local oldDiff =
        tonumber(
            old.Diff
        )

    local oldFailures =
        tonumber(
            old.FailureCount
        )
        or 0

    local failPower =
        tonumber(
            old.FailPower
        )
        or 0

    if oldWorld
            ~= tostring(
                target.WorldId
            )
        or oldDiff
            ~= tonumber(
                target.DiffLevel
            )
        or power()
            > failPower
    then
        oldFailures = 0
    end

    writeJournal({
        State = "TELEPORTING",
        Decision = decision,
        World = target.WorldId,
        Diff = target.DiffLevel,
        DirectRepeats = 0,
        FailureCount = oldFailures,
        FailPower = failPower,
        Level = level(),
        Power = power(),
        UpdatedAt = os.time(),
    })
end

local teleportObserved =
    false

local conn =
    LocalPlayer.OnTeleport:
        Connect(function(state)
            teleportObserved = true

            matchLog(
                "OnTeleport="
                    .. tostring(state)
            )

            save()
        end)

local started =
    waitUntil(
        function()
            if LocalPlayer:
                GetAttribute(
                    "IsTeleporting"
                )
            then
                return "IsTeleporting"
            end

            if teleportObserved then
                return "OnTeleport"
            end
        end,
        CFG.TELEPORT_TIMEOUT,
        0.05
    )

pcall(function()
    conn:Disconnect()
end)

matchLog(
    "TELEPORT_STARTED="
        .. tostring(started)
)

snapshot("FINAL_LOBBY_STATE")

save()

if not started then
    return stop(
        "Match created but teleport did not begin."
    )
end

important(
    "Entering "
        .. tostring(
            target.WorldId
        )
        .. " D"
        .. tostring(
            target.DiffLevel
        )
        .. " | Lv"
        .. tostring(level())
        .. " P"
        .. tostring(power())
)

save()


save()
