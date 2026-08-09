--========================================================--
-- IRON SOUL KAITUN - CONTINUOUS V59
--
-- Single public loader:
-- loadstring(game:HttpGet(
--   "https://raw.githubusercontent.com/MUshihara/IronSoul-Kaitun/main/bootstrap.lua"
-- ))()
--
-- Dispatch:
--   Tutorial -> systems/tutorial.lua
--   Lobby    -> systems/lobby.lua
--   Dungeon  -> systems/combat.lua
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
    .. "MUshihara/IronSoul-Kaitun/main/"

local TUTORIAL_PLACE_ID =
    76701861705540

local LOBBY_PLACE_ID =
    117533937949084

local function loadRaw(path)
    local ok, source =
        pcall(
            game.HttpGet,
            game,
            BASE .. path
        )

    if not ok
        or type(source) ~= "string"
    then
        warn(
            "[IronSoul V59] HTTP load failed: "
                .. tostring(path)
                .. " | "
                .. tostring(source)
        )

        return false
    end

    local fn, err =
        loadstring(source)

    if not fn then
        warn(
            "[IronSoul V59] Compile failed: "
                .. tostring(path)
                .. " | "
                .. tostring(err)
        )

        return false
    end

    local runOk, result =
        pcall(fn)

    if not runOk then
        warn(
            "[IronSoul V59] Runtime failed: "
                .. tostring(path)
                .. " | "
                .. tostring(result)
        )

        return false
    end

    return true,
        result
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
            "[IronSoul V59] queue_on_teleport unavailable: "
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

loadstring(
    game:HttpGet(%q)
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
        BASE .. "bootstrap.lua"
    )

    local ok, err =
        pcall(
            queue,
            payload
        )

    if not ok then
        warn(
            "[IronSoul V59] queue failed: "
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
        "[IronSoul V59] Unknown place; no action. PlaceId="
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
    Version = "V59",
    Route = route,
    PlaceId = game.PlaceId,
    StartedAt = os.clock(),
}

print(
    "[IronSoul V59] Route="
        .. route
        .. " PlaceId="
        .. tostring(
            game.PlaceId
        )
)

loadRaw(route)
