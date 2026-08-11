--========================================================--
-- IRON SOUL V61.10 - MOBILE-SAFE TUTORIAL / STARTER
--
-- Fresh account flow:
--   1) select starter Sword (index 1)
--   2) trigger the real Skip Tutorial GuiButton signal without relying on a
--      desktop mouse when executor signal APIs exist
--   3) verify a real teleport via LocalPlayer.OnTeleport
--   4) direct Lobby teleport fallback if native skip does not move us
--========================================================--

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")
local VirtualInputManager = game:GetService("VirtualInputManager")

local LocalPlayer = Players.LocalPlayer
local LOBBY_PLACE_ID = 117533937949084

local queueBootstrap =
    getgenv().IronSoulQueueBootstrap

local function status(text)
    local fn = getgenv().IronSoulStatus
    if type(fn) == "function" then
        pcall(fn, "Tutorial | " .. tostring(text))
    end
end

local function findByName(root, wanted, className)
    for _, obj in ipairs(root:GetDescendants()) do
        if obj.Name == wanted
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

    local ok, value = pcall(require, obj)
    return ok and value or nil
end

local function effectivelyVisible(obj)
    if not obj then
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

        if current == LocalPlayer.PlayerGui then
            break
        end

        current = current.Parent
    end

    return true
end

local function buttonLooksLikeSkip(obj)
    if not obj or not obj:IsA("GuiButton") then
        return false
    end

    local haystack = {
        tostring(obj.Name or ""),
    }

    if obj:IsA("TextButton") then
        table.insert(haystack, tostring(obj.Text or ""))
    end

    for _, child in ipairs(obj:GetDescendants()) do
        if child:IsA("TextLabel")
            or child:IsA("TextButton")
        then
            table.insert(
                haystack,
                tostring(child.Text or "")
            )
        end
    end

    for _, text in ipairs(haystack) do
        local low = string.lower(text)

        if string.find(low, "skip tutorial", 1, true)
            or low == "skip"
            or string.find(low, "skiptutorial", 1, true)
        then
            return true
        end
    end

    return false
end

local function findSkipButton(timeout)
    local deadline = os.clock() + (timeout or 4)

    while os.clock() < deadline do
        local pg =
            LocalPlayer:FindFirstChildOfClass("PlayerGui")

        if pg then
            local fallback = nil

            for _, obj in ipairs(pg:GetDescendants()) do
                if obj:IsA("GuiButton")
                    and buttonLooksLikeSkip(obj)
                then
                    if effectivelyVisible(obj) then
                        return obj
                    end

                    fallback = fallback or obj
                end
            end

            if fallback then
                return fallback
            end
        end

        task.wait(0.12)
    end

    return nil
end

local teleportStarted = false
local teleportDestination = nil

local teleportConn =
    LocalPlayer.OnTeleport:
        Connect(function(state, placeId)
            local stateText = tostring(state)

            if not string.find(
                stateText,
                "Failed",
                1,
                true
            )
            then
                teleportStarted = true
                teleportDestination = placeId
                status(
                    "teleport started | "
                        .. tostring(state)
                        .. " | place="
                        .. tostring(placeId)
                )
            end
        end)

local function waitTeleport(timeout)
    local deadline = os.clock() + (timeout or 4)

    while os.clock() < deadline do
        if teleportStarted then
            return true
        end

        if game.PlaceId == LOBBY_PLACE_ID then
            return true
        end

        task.wait(0.08)
    end

    return false
end

local function triggerSignal(signal)
    if not signal then
        return false
    end

    if type(firesignal) == "function" then
        local ok = pcall(firesignal, signal)
        if ok then
            return true
        end
    end

    if type(getconnections) == "function" then
        local ok, connections = pcall(getconnections, signal)

        if ok and type(connections) == "table" then
            for _, conn in ipairs(connections) do
                if type(conn.Function) == "function" then
                    local fired = pcall(conn.Function)
                    if fired then
                        return true
                    end
                elseif type(conn.Fire) == "function" then
                    local fired = pcall(conn.Fire, conn)
                    if fired then
                        return true
                    end
                end
            end
        end
    end

    return false
end

local function virtualClick(button)
    if not button then
        return false
    end

    local pos = button.AbsolutePosition
    local size = button.AbsoluteSize

    local x = math.floor(pos.X + size.X * 0.5)
    local y = math.floor(pos.Y + size.Y * 0.5)

    return pcall(function()
        VirtualInputManager:SendMouseMoveEvent(x, y, game)
        task.wait(0.04)

        VirtualInputManager:SendMouseButtonEvent(
            x,
            y,
            0,
            true,
            game,
            0
        )

        task.wait(0.05)

        VirtualInputManager:SendMouseButtonEvent(
            x,
            y,
            0,
            false,
            game,
            0
        )
    end)
end

local function activateSkipButton(button)
    if not button then
        return false, "NO_BUTTON"
    end

    status(
        "Skip Tutorial found | "
            .. tostring(button:GetFullName())
    )

    -- Activated is input-agnostic and is the best mobile-first signal.
    if triggerSignal(button.Activated) then
        return true, "ACTIVATED_SIGNAL"
    end

    if triggerSignal(button.MouseButton1Click) then
        return true, "MOUSE_CLICK_SIGNAL"
    end

    if triggerSignal(button.MouseButton1Down) then
        return true, "MOUSE_DOWN_SIGNAL"
    end

    if virtualClick(button) then
        return true, "VIRTUAL_CLICK"
    end

    return false, "NO_SUPPORTED_TRIGGER"
end

if type(queueBootstrap) == "function" then
    local queued = queueBootstrap("tutorial -> lobby")

    if queued then
        status("next teleport queued")
    else
        status("queue unavailable; loader may need one re-execute in Lobby")
    end
end

local UnForgeUtil = req("UnForgeUtil")

if UnForgeUtil then
    local shouldSelect =
        LocalPlayer:GetAttribute(
            "Equipment.GetDefaultWeapon"
        ) ~= true

    if shouldSelect
        and type(UnForgeUtil.SelectDefaultWeapon) == "function"
    then
        status("selecting starter Sword")

        local ok, err =
            pcall(function()
                UnForgeUtil:SelectDefaultWeapon(
                    LocalPlayer,
                    1
                )
            end)

        if not ok then
            status("Sword select call failed | " .. tostring(err))
        end
    else
        status("starter weapon already selected")
    end
else
    -- Missing weapon helper must not prevent tutorial exit. On some executor
    -- builds module require support can differ, while the Skip button still
    -- works normally.
    status("UnForgeUtil unavailable; continuing to Skip Tutorial")
end

-- Give the server a short moment to commit starter weapon state before skip.
task.wait(0.65)

if waitTeleport(0.35) then
    return
end

local skip = findSkipButton(4.5)

if skip then
    local sent, route = activateSkipButton(skip)

    status(
        "Skip sent="
            .. tostring(sent)
            .. " via="
            .. tostring(route)
    )

    if sent and waitTeleport(5.0) then
        return
    end
else
    status("Skip Tutorial button not found; using Lobby fallback")
end

-- Do not trust only an IsTeleporting attribute here. The old mobile path could
-- see a stale/truthy attribute and return even when no real teleport started.
status("direct Lobby teleport fallback")

local directOk, directErr =
    pcall(function()
        TeleportService:Teleport(
            LOBBY_PLACE_ID,
            LocalPlayer
        )
    end)

if directOk and waitTeleport(4.0) then
    return
end

-- Some executor/client builds behave differently with the newer API. Keep it
-- as a second bounded attempt rather than depending on one teleport method.
local asyncOk, asyncErr =
    pcall(function()
        TeleportService:TeleportAsync(
            LOBBY_PLACE_ID,
            {LocalPlayer}
        )
    end)

if asyncOk and waitTeleport(5.0) then
    return
end

status(
    "STUCK | direct="
        .. tostring(directErr)
        .. " | async="
        .. tostring(asyncErr)
)

warn(
    "[IronSoul V61.10] Tutorial could not start Lobby teleport. direct="
        .. tostring(directErr)
        .. " async="
        .. tostring(asyncErr)
)

pcall(function()
    teleportConn:Disconnect()
end)
