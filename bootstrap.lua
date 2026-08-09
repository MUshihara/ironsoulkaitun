--========================================================--
-- IRON SOUL KAITUN - CONTINUOUS V59.1 BOOTSTRAP
--
-- Fixes GitHub/executor source-cache + invisible-prefix compile issues.
--========================================================--

getgenv().IronSoulConfig =
    getgenv().IronSoulConfig
    or {
        FPS_CAP = 8,
        FARM = "NEWBIE",
        TICKETS = "SMART",
        HEADLESS = true,
    }

local Config =
    getgenv().IronSoulConfig

if type(setfpscap) == "function"
    and tonumber(Config.FPS_CAP)
then
    pcall(
        setfpscap,
        tonumber(Config.FPS_CAP)
    )
end

local BASE =
    "https://raw.githubusercontent.com/"
    .. "MUshihara/ironsoulkaitun/main/"

local TUTORIAL_PLACE_ID =
    76701861705540

local LOBBY_PLACE_ID =
    117533937949084

local VERSION =
    "59.1"

local fetchCounter = 0

local function cacheBust(path)
    fetchCounter += 1

    return BASE
        .. path
        .. "?isv="
        .. VERSION
        .. "&n="
        .. tostring(fetchCounter)
        .. "&t="
        .. tostring(os.time())
end

local function normalizeSource(source)
    if type(source) ~= "string" then
        return source
    end

    -- UTF-8 BOM
    if string.sub(source, 1, 3)
        == "\239\187\191"
    then
        source =
            string.sub(
                source,
                4
            )
    end

    -- UTF-16 BOMs should never be returned by GitHub raw, but explicitly
    -- reject them instead of letting loadstring produce a misleading
    -- line-1 parser error.
    local b1 =
        string.byte(source, 1)

    local b2 =
        string.byte(source, 2)

    if (
        b1 == 255
        and b2 == 254
    )
        or (
            b1 == 254
            and b2 == 255
        )
    then
        return nil,
            "UTF-16 source received"
    end

    -- Remove common zero-width UTF-8 prefixes if an executor/network layer
    -- somehow prepends one.
    local prefixes = {
        "\226\128\139", -- zero width space
        "\226\128\140",
        "\226\128\141",
        "\226\129\160",
    }

    local changed = true

    while changed do
        changed = false

        for _, prefix in ipairs(
            prefixes
        ) do
            if string.sub(
                source,
                1,
                #prefix
            ) == prefix
            then
                source =
                    string.sub(
                        source,
                        #prefix + 1
                    )

                changed = true
            end
        end
    end

    return source
end

local function sourceHead(source)
    if type(source) ~= "string" then
        return tostring(source)
    end

    local head =
        string.sub(
            source,
            1,
            120
        )

    head =
        string.gsub(
            head,
            "\r",
            "\\r"
        )

    head =
        string.gsub(
            head,
            "\n",
            "\\n"
        )

    return head
end

local function sourceBytes(source)
    if type(source) ~= "string" then
        return "not-string"
    end

    local bytes = {}

    for i = 1,
        math.min(
            12,
            #source
        )
    do
        table.insert(
            bytes,
            tostring(
                string.byte(
                    source,
                    i
                )
            )
        )
    end

    return table.concat(
        bytes,
        ","
    )
end

local function loadRaw(path)
    local url =
        cacheBust(path)

    print(
        "[IronSoul V59.1] Fetching "
            .. tostring(path)
    )

    local ok, source =
        pcall(
            game.HttpGet,
            game,
            url
        )

    if not ok
        or type(source) ~= "string"
    then
        warn(
            "[IronSoul V59.1] HTTP load failed: "
                .. tostring(path)
                .. " | "
                .. tostring(source)
        )

        return false
    end

    local normalized,
        normalizeErr =
            normalizeSource(
                source
            )

    if not normalized then
        warn(
            "[IronSoul V59.1] Source normalization failed: "
                .. tostring(path)
                .. " | "
                .. tostring(
                    normalizeErr
                )
        )

        return false
    end

    source =
        normalized

    print(
        "[IronSoul V59.1] Source "
            .. tostring(path)
            .. " length="
            .. tostring(#source)
            .. " bytes=["
            .. sourceBytes(source)
            .. "]"
    )

    local fn, err =
        loadstring(source)

    if not fn then
        warn(
            "[IronSoul V59.1] Compile failed: "
                .. tostring(path)
                .. " | "
                .. tostring(err)
        )

        warn(
            "[IronSoul V59.1] SOURCE_HEAD="
                .. sourceHead(source)
        )

        warn(
            "[IronSoul V59.1] FIRST_BYTES="
                .. sourceBytes(source)
        )

        return false
    end

    local runOk, result =
        pcall(fn)

    if not runOk then
        warn(
            "[IronSoul V59.1] Runtime failed: "
                .. tostring(path)
                .. " | "
                .. tostring(result)
        )

        return false
    end

    return true,
        result
end

local function bootstrapURL()
    return BASE
        .. "bootstrap.lua"
        .. "?isv="
        .. VERSION
        .. "&t="
        .. tostring(os.time())
end

local function queueBootstrap(reason)
    local queue =
        queue_on_teleport
        or (
            syn
            and syn.queue_on_teleport
        )

    if type(queue)
        ~= "function"
    then
        warn(
            "[IronSoul V59.1] queue_on_teleport unavailable: "
                .. tostring(reason)
        )

        return false
    end

    local payload = string.format([[
task.wait(1.35)

getgenv().IronSoulConfig =
    getgenv().IronSoulConfig
    or {
        FPS_CAP = %s,
        FARM = %q,
        TICKETS = %q,
        HEADLESS = %s,
    }

local url =
    %q
    .. "?isv=59.1&t="
    .. tostring(os.time())

loadstring(
    game:HttpGet(url)
)()
]],
        tostring(
            tonumber(Config.FPS_CAP)
            or 8
        ),
        tostring(
            Config.FARM
            or "NEWBIE"
        ),
        tostring(
            Config.TICKETS
            or "SMART"
        ),
        tostring(
            Config.HEADLESS
            ~= false
        ),
        BASE
            .. "bootstrap.lua"
    )

    local ok, err =
        pcall(
            queue,
            payload
        )

    if not ok then
        warn(
            "[IronSoul V59.1] queue failed: "
                .. tostring(reason)
                .. " | "
                .. tostring(err)
        )
    end

    return ok
end

getgenv().IronSoulBaseURL =
    BASE

getgenv().IronSoulQueueBootstrap =
    queueBootstrap

getgenv().IronSoulLoadRaw =
    loadRaw

local function looksLikeDungeon()
    local rs =
        game:GetService(
            "ReplicatedStorage"
        )

    local hasRound =
        rs:
            FindFirstChild(
                "GameRoundCfg"
            )
        ~= nil

    local hasCombatWorld =
        workspace:
            FindFirstChild(
                "RoundDoor"
            )
        or workspace:
            FindFirstChild(
                "EnemyNpc"
            )
        or workspace:
            FindFirstChild(
                "WorldEnemys"
            )

    return hasRound
        and hasCombatWorld
end

local route

if game.PlaceId
    == TUTORIAL_PLACE_ID
then
    route =
        "systems/tutorial.lua"

elseif game.PlaceId
    == LOBBY_PLACE_ID
    or workspace:
        GetAttribute(
            "WorldName"
        ) == "Lobby"
then
    route =
        "systems/lobby.lua"

elseif looksLikeDungeon()
then
    route =
        "systems/combat.lua"
else
    warn(
        "[IronSoul V59.1] Unknown place; no action. PlaceId="
            .. tostring(
                game.PlaceId
            )
            .. " WorldName="
            .. tostring(
                workspace:
                    GetAttribute(
                        "WorldName"
                    )
            )
    )

    return
end

getgenv().IronSoulRuntime = {
    Version = "V59.1",
    Route = route,
    PlaceId = game.PlaceId,
    StartedAt = os.clock(),
}

print(
    "[IronSoul V59.1] Route="
        .. route
        .. " PlaceId="
        .. tostring(
            game.PlaceId
        )
)

loadRaw(route)
