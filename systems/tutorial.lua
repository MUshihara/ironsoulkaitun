--========================================================--
-- IRON SOUL V59 - TUTORIAL / STARTER
--
-- Proven starter:
--   index 1 = Single_BroadSword
--
-- Preferred:
--   SelectDefaultWeapon(player, 1)
--   wait for game's own Lobby teleport
--
-- Fallback:
--   one-time visible "Skip Tutorial" UI click
--   then direct Lobby teleport only if still stuck.
--========================================================--

local Players =
    game:GetService("Players")

local ReplicatedStorage =
    game:GetService(
        "ReplicatedStorage"
    )

local TeleportService =
    game:GetService(
        "TeleportService"
    )

local VirtualInputManager =
    game:GetService(
        "VirtualInputManager"
    )

local LocalPlayer =
    Players.LocalPlayer

local LOBBY_PLACE_ID =
    117533937949084

local queueBootstrap =
    getgenv().IronSoulQueueBootstrap

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

        if current
            == LocalPlayer.PlayerGui
        then
            break
        end

        current = current.Parent
    end

    return true
end

local function findSkipButton()
    local pg =
        LocalPlayer:
            FindFirstChildOfClass(
                "PlayerGui"
            )

    if not pg then
        return nil
    end

    for _, obj in ipairs(
        pg:GetDescendants()
    ) do
        if (
            obj:IsA("TextButton")
            or obj:IsA("ImageButton")
        )
            and effectivelyVisible(obj)
        then
            local texts = {}

            if obj:IsA("TextButton") then
                table.insert(
                    texts,
                    tostring(
                        obj.Text or ""
                    )
                )
            end

            for _, child in ipairs(
                obj:GetDescendants()
            ) do
                if child:IsA("TextLabel")
                    or child:IsA("TextButton")
                then
                    table.insert(
                        texts,
                        tostring(
                            child.Text or ""
                        )
                    )
                end
            end

            for _, text in ipairs(texts) do
                if string.find(
                    string.lower(text),
                    "skip tutorial",
                    1,
                    true
                )
                then
                    return obj
                end
            end
        end
    end
end

local function clickButton(button)
    if not button
        or not effectivelyVisible(
            button
        )
    then
        return false
    end

    local pos =
        button.AbsolutePosition

    local size =
        button.AbsoluteSize

    local x =
        math.floor(
            pos.X
            + size.X * 0.5
        )

    local y =
        math.floor(
            pos.Y
            + size.Y * 0.5
        )

    local ok =
        pcall(function()
            VirtualInputManager:
                SendMouseMoveEvent(
                    x,
                    y,
                    game
                )

            task.wait(0.05)

            VirtualInputManager:
                SendMouseButtonEvent(
                    x,
                    y,
                    0,
                    true,
                    game,
                    0
                )

            task.wait(0.06)

            VirtualInputManager:
                SendMouseButtonEvent(
                    x,
                    y,
                    0,
                    false,
                    game,
                    0
                )
        end)

    return ok
end

local UnForgeUtil =
    req("UnForgeUtil")

if not UnForgeUtil then
    warn(
        "[IronSoul V59] Tutorial: UnForgeUtil missing."
    )

    return
end

if type(queueBootstrap)
    == "function"
then
    queueBootstrap(
        "tutorial -> lobby"
    )
end

local equipment =
    LocalPlayer:
        GetAttribute(
            "Equipment.GetDefaultWeapon"
        )

local shouldSelect =
    equipment ~= true

if type(
    UnForgeUtil.GetDefaultWeaponInfo
) == "function"
then
    local ok, info =
        pcall(function()
            return UnForgeUtil:
                GetDefaultWeaponInfo(
                    LocalPlayer,
                    1
                )
        end)

    if ok and info then
        print(
            "[IronSoul V59] Tutorial starter index1="
                .. tostring(
                    info.ID
                    or info.Name
                    or "Sword"
                )
        )
    end
end

if shouldSelect
    and type(
        UnForgeUtil.SelectDefaultWeapon
    ) == "function"
then
    print(
        "[IronSoul V59] Selecting starter Sword."
    )

    pcall(function()
        UnForgeUtil:
            SelectDefaultWeapon(
                LocalPlayer,
                1
            )
    end)
end

local deadline =
    os.clock() + 8

while os.clock()
    < deadline
do
    if game.PlaceId
        == LOBBY_PLACE_ID
        or workspace:
            GetAttribute(
                "WorldName"
            ) == "Lobby"
    then
        return
    end

    local target =
        LocalPlayer:
            GetAttribute(
                "IsTeleporting"
            )

    if target
        == LOBBY_PLACE_ID
    then
        return
    end

    task.wait(0.15)
end

local skip =
    findSkipButton()

if skip then
    print(
        "[IronSoul V59] Tutorial native flow did not teleport; using one-time Skip Tutorial fallback."
    )

    clickButton(skip)

    local second =
        os.clock() + 7

    while os.clock()
        < second
    do
        if LocalPlayer:
            GetAttribute(
                "IsTeleporting"
            )
        then
            return
        end

        task.wait(0.15)
    end
end

warn(
    "[IronSoul V59] Tutorial still stuck; direct Lobby fallback."
)

pcall(function()
    TeleportService:
        Teleport(
            LOBBY_PLACE_ID,
            LocalPlayer
        )
end)
