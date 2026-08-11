--========================================================--
-- IRON SOUL - WORLD / DUNGEON RECON V61.11
--
-- READ-ONLY diagnostic. It does NOT fire remotes, prompts, touches, attacks,
-- or alter progression. Run it while standing at a new/stuck mechanic.
--
-- Output folder contains bounded snapshots of workspace objects, possible
-- gates/barriers, interactions, remotes/modules, player/game state, and a
-- short timeline so new-world mechanics can be mapped from one ZIP.
--========================================================--

local VERSION = "V61.11"
local WATCH_SECONDS = 12
local WORKSPACE_INDEX_LIMIT = 12000
local NEAR_RADIUS = 360
local NEAR_LIMIT = 1800
local RELEVANT_LIMIT = 600
local REMOTE_LIMIT = 2200
local MODULE_LIMIT = 2600

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local Character = LocalPlayer.Character
local Root = Character
    and Character:FindFirstChild("HumanoidRootPart")

local stamp = os.date("%Y%m%d_%H%M%S")
local baseName =
    "IronSoul_WorldRecon_V61_11_"
    .. stamp
    .. "_"
    .. tostring(game.PlaceId)

local folderReady = false

if type(makefolder) == "function" then
    local ok = pcall(makefolder, baseName)
    folderReady = ok == true
end

local function outPath(name)
    if folderReady then
        return baseName .. "/" .. tostring(name)
    end

    return baseName .. "_" .. tostring(name)
end

local function writeText(name, text)
    if type(writefile) ~= "function" then
        return false
    end

    return pcall(
        writefile,
        outPath(name),
        tostring(text or "")
    )
end

local function appendText(name, text)
    local path = outPath(name)

    if type(appendfile) == "function" then
        return pcall(
            appendfile,
            path,
            tostring(text or "")
        )
    end

    local old = ""

    if type(readfile) == "function" then
        pcall(function()
            old = readfile(path)
        end)
    end

    return writeText(
        name,
        tostring(old or "") .. tostring(text or "")
    )
end

local externalStatus = getgenv().IronSoulStatus
local reconLabel = nil

local function ensureReconGui()
    if reconLabel and reconLabel.Parent then
        return reconLabel
    end

    if not UserInputService.TouchEnabled then
        return nil
    end

    local pg =
        LocalPlayer:FindFirstChildOfClass("PlayerGui")
        or LocalPlayer:WaitForChild("PlayerGui", 4)

    if not pg then
        return nil
    end

    local old = pg:FindFirstChild("IronSoulReconStatus")
    if old then
        pcall(function() old:Destroy() end)
    end

    local gui = Instance.new("ScreenGui")
    gui.Name = "IronSoulReconStatus"
    gui.ResetOnSpawn = false
    gui.DisplayOrder = 1000000

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0, 350, 0, 48)
    label.Position = UDim2.new(0, 8, 0, 62)
    label.BackgroundTransparency = 0.22
    label.BorderSizePixel = 0
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextYAlignment = Enum.TextYAlignment.Center
    label.TextWrapped = true
    label.TextSize = 12
    label.Font = Enum.Font.Code
    label.Active = false
    label.Selectable = false
    label.Text = "IronSoul Recon V61.11 | starting"
    label.Parent = gui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = label

    gui.Parent = pg
    reconLabel = label
    return label
end

local function status(text)
    text = tostring(text or "")
    print("[IronSoul Recon]", text)

    if type(externalStatus) == "function" then
        pcall(
            externalStatus,
            "Recon | " .. text
        )
    end

    local label = ensureReconGui()
    if label then
        pcall(function()
            label.Text = "IronSoul Recon V61.11 | " .. text
        end)
    end
end

local function fullName(obj)
    if typeof(obj) ~= "Instance" then
        return tostring(obj)
    end

    local ok, value = pcall(function()
        return obj:GetFullName()
    end)

    return ok and value or obj.Name
end

local function safeValue(value)
    local kind = typeof(value)

    if kind == "string"
        or kind == "number"
        or kind == "boolean"
        or kind == "Vector3"
        or kind == "CFrame"
        or kind == "Color3"
        or kind == "BrickColor"
        or kind == "EnumItem"
    then
        return tostring(value)
    end

    return "<" .. tostring(kind) .. ">"
end

local function attributesText(obj, maxCount)
    if typeof(obj) ~= "Instance" then
        return ""
    end

    local ok, attrs = pcall(obj.GetAttributes, obj)

    if not ok or type(attrs) ~= "table" then
        return ""
    end

    local keys = {}
    for key in pairs(attrs) do
        table.insert(keys, tostring(key))
    end
    table.sort(keys)

    local rows = {}
    local limit = tonumber(maxCount) or 32

    for i, key in ipairs(keys) do
        if i > limit then
            table.insert(rows, "...")
            break
        end

        table.insert(
            rows,
            key .. "=" .. safeValue(attrs[key])
        )
    end

    return table.concat(rows, ";")
end

local function valueText(obj)
    if not obj then
        return ""
    end

    if obj:IsA("StringValue")
        or obj:IsA("NumberValue")
        or obj:IsA("IntValue")
        or obj:IsA("BoolValue")
        or obj:IsA("ObjectValue")
        or obj:IsA("Vector3Value")
        or obj:IsA("CFrameValue")
    then
        local ok, value = pcall(function()
            return obj.Value
        end)

        if ok then
            return safeValue(value)
        end
    end

    return ""
end

local function instancePosition(obj)
    if not obj then
        return nil
    end

    if obj:IsA("BasePart") then
        return obj.Position
    end

    if obj:IsA("Attachment")
        and obj.Parent
        and obj.Parent:IsA("BasePart")
    then
        return obj.WorldPosition
    end

    if obj:IsA("Model") then
        local part =
            obj.PrimaryPart
            or obj:FindFirstChild("HumanoidRootPart")
            or obj:FindFirstChild("Root")
            or obj:FindFirstChildWhichIsA("BasePart", true)

        return part and part.Position or nil
    end

    local part = obj:FindFirstChildWhichIsA("BasePart", true)
    return part and part.Position or nil
end

local function distanceFromPlayer(obj)
    if not Root then
        return nil
    end

    local pos = instancePosition(obj)
    if not pos then
        return nil
    end

    return (pos - Root.Position).Magnitude
end

local function tagsText(obj)
    local ok, tags = pcall(CollectionService.GetTags, CollectionService, obj)

    if not ok or type(tags) ~= "table" then
        return ""
    end

    table.sort(tags)
    return table.concat(tags, ",")
end

local KEYWORDS = {
    "gate",
    "door",
    "portal",
    "wall",
    "barrier",
    "barricade",
    "seal",
    "crystal",
    "ice",
    "rock",
    "break",
    "destroy",
    "obstacle",
    "round",
    "wake",
    "trigger",
    "checkpoint",
    "teleport",
    "boss",
    "egg",
    "enemy",
    "objective",
    "switch",
}

local METRIC_KEYS = {
    "Health",
    "HP",
    "Hp",
    "CurrentHP",
    "CurHP",
    "HitPoint",
    "HitPoints",
    "Durability",
    "HitDamage",
    "DamageTaken",
    "Progress",
    "HitCount",
    "Broken",
    "Destroyed",
    "Opened",
    "Open",
    "Switch",
    "RoundNum",
    "Round",
    "Active",
    "Damageable",
    "Destructible",
}

local function keywordHits(name)
    local low = string.lower(tostring(name or ""))
    local hits = {}

    for _, word in ipairs(KEYWORDS) do
        if string.find(low, word, 1, true) then
            table.insert(hits, word)
        end
    end

    return hits
end

local function metricText(obj)
    if not obj then
        return ""
    end

    local rows = {}

    for _, key in ipairs(METRIC_KEYS) do
        local value = obj:GetAttribute(key)

        if value ~= nil then
            table.insert(
                rows,
                key .. "=" .. safeValue(value)
            )
        end

        local child = obj:FindFirstChild(key)

        if child and (
            child:IsA("ValueBase")
            or child:IsA("StringValue")
        ) then
            table.insert(
                rows,
                "Value." .. key .. "=" .. valueText(child)
            )
        end
    end

    return table.concat(rows, ";")
end

local function objectLine(obj)
    local dist = distanceFromPlayer(obj)
    local extra = {}

    if obj:IsA("BasePart") then
        table.insert(extra, "pos=" .. tostring(obj.Position))
        table.insert(extra, "size=" .. tostring(obj.Size))
        table.insert(extra, "collide=" .. tostring(obj.CanCollide))
        table.insert(extra, "touch=" .. tostring(obj.CanTouch))
        table.insert(extra, "query=" .. tostring(obj.CanQuery))
        table.insert(extra, "trans=" .. tostring(obj.Transparency))
    elseif obj:IsA("ProximityPrompt") then
        table.insert(extra, "enabled=" .. tostring(obj.Enabled))
        table.insert(extra, "max=" .. tostring(obj.MaxActivationDistance))
        table.insert(extra, "hold=" .. tostring(obj.HoldDuration))
        table.insert(extra, "action=" .. tostring(obj.ActionText))
        table.insert(extra, "object=" .. tostring(obj.ObjectText))
    elseif obj:IsA("Humanoid") then
        table.insert(extra, "hp=" .. tostring(obj.Health))
        table.insert(extra, "maxhp=" .. tostring(obj.MaxHealth))
    end

    local attrs = attributesText(obj, 28)
    if attrs ~= "" then
        table.insert(extra, "attrs={" .. attrs .. "}")
    end

    local metric = metricText(obj)
    if metric ~= "" then
        table.insert(extra, "metrics={" .. metric .. "}")
    end

    local tags = tagsText(obj)
    if tags ~= "" then
        table.insert(extra, "tags={" .. tags .. "}")
    end

    return table.concat({
        "class=" .. obj.ClassName,
        "name=" .. obj.Name,
        "path=" .. fullName(obj),
        "dist=" .. (dist and string.format("%.2f", dist) or "?"),
        table.concat(extra, " "),
    }, " | ")
end

local function dumpExecutorCaps()
    local rows = {
        "Version=" .. VERSION,
        "Executor=" .. tostring(
            type(identifyexecutor) == "function"
                and select(1, pcall(identifyexecutor))
                or "unknown"
        ),
        "Touch=" .. tostring(UserInputService.TouchEnabled),
        "writefile=" .. tostring(type(writefile) == "function"),
        "readfile=" .. tostring(type(readfile) == "function"),
        "makefolder=" .. tostring(type(makefolder) == "function"),
        "appendfile=" .. tostring(type(appendfile) == "function"),
        "firesignal=" .. tostring(type(firesignal) == "function"),
        "getconnections=" .. tostring(type(getconnections) == "function"),
        "fireproximityprompt=" .. tostring(type(fireproximityprompt) == "function"),
        "firetouchinterest=" .. tostring(type(firetouchinterest) == "function"),
        "getgc=" .. tostring(type(getgc) == "function"),
        "decompile=" .. tostring(type(decompile) == "function"),
        "getscripts=" .. tostring(type(getscripts) == "function"),
    }

    writeText("ExecutorCaps.txt", table.concat(rows, "\n"))
end

local function dumpGameState()
    local rows = {
        "Version=" .. VERSION,
        "PlaceId=" .. tostring(game.PlaceId),
        "JobId=" .. tostring(game.JobId),
        "WorldName=" .. tostring(workspace:GetAttribute("WorldName")),
        "Player=" .. tostring(LocalPlayer.Name),
        "UserId=" .. tostring(LocalPlayer.UserId),
        "PlayerPos=" .. tostring(Root and Root.Position),
        "PlayerAttributes={" .. attributesText(LocalPlayer, 80) .. "}",
        "WorkspaceAttributes={" .. attributesText(workspace, 120) .. "}",
        "",
        "=== IMPORTANT ROOT OBJECTS ===",
    }

    for _, name in ipairs({
        "RoundDoor",
        "RoundWakeTouch",
        "Portal",
        "EnemyNpc",
        "WorldEnemys",
        "DragonEgg",
        "Settlement",
        "MatchRoom",
    }) do
        local obj = workspace:FindFirstChild(name)
        table.insert(
            rows,
            name .. "=" .. tostring(obj and fullName(obj) or "nil")
        )
    end

    table.insert(rows, "")
    table.insert(rows, "=== GameRoundCfg ===")

    local cfg = ReplicatedStorage:FindFirstChild("GameRoundCfg")

    if cfg then
        table.insert(rows, objectLine(cfg))

        local desc = cfg:GetDescendants()
        for i, obj in ipairs(desc) do
            if i > 600 then
                table.insert(rows, "... GameRoundCfg truncated ...")
                break
            end

            table.insert(rows, objectLine(obj))
        end
    else
        table.insert(rows, "GameRoundCfg=nil")
    end

    writeText("GameState.txt", table.concat(rows, "\n"))
end

local function dumpPlayerSurface()
    local rows = {
        "=== PLAYER ===",
        objectLine(LocalPlayer),
        "",
    }

    if Character then
        table.insert(rows, "=== CHARACTER ===")
        table.insert(rows, objectLine(Character))

        local desc = Character:GetDescendants()
        for i, obj in ipairs(desc) do
            if i > 1200 then
                table.insert(rows, "... character truncated ...")
                break
            end

            if obj:IsA("Tool")
                or obj:IsA("Humanoid")
                or obj:IsA("BasePart")
                or #keywordHits(obj.Name) > 0
                or attributesText(obj, 1) ~= ""
            then
                table.insert(rows, objectLine(obj))
            end
        end
    end

    writeText("PlayerSurface.txt", table.concat(rows, "\n"))
end

local function dumpWorkspaceIndex()
    status("workspace index")

    local rows = {
        "Version=" .. VERSION,
        "Limit=" .. tostring(WORKSPACE_INDEX_LIMIT),
        "",
    }

    local desc = workspace:GetDescendants()
    local count = 0

    for _, obj in ipairs(desc) do
        count += 1

        if count > WORKSPACE_INDEX_LIMIT then
            table.insert(
                rows,
                "... TRUNCATED totalLoaded=" .. tostring(#desc)
            )
            break
        end

        local suffix = ""
        local attrs = attributesText(obj, 12)

        if attrs ~= "" then
            suffix = " | attrs={" .. attrs .. "}"
        end

        if obj:IsA("ValueBase") then
            suffix = suffix .. " | value=" .. valueText(obj)
        end

        table.insert(
            rows,
            obj.ClassName
                .. " | "
                .. fullName(obj)
                .. suffix
        )

        if count % 350 == 0 then
            task.wait()
        end
    end

    writeText("WorkspaceIndex.txt", table.concat(rows, "\n"))
    return math.min(count, WORKSPACE_INDEX_LIMIT), #desc
end

local function dumpNearbyParts()
    status("nearby geometry")

    local rows = {
        "Radius=" .. tostring(NEAR_RADIUS),
        "PlayerPos=" .. tostring(Root and Root.Position),
        "",
    }

    if not Root then
        table.insert(rows, "No HumanoidRootPart")
        writeText("NearbyParts.txt", table.concat(rows, "\n"))
        return 0
    end

    local ok, parts = pcall(
        workspace.GetPartBoundsInRadius,
        workspace,
        Root.Position,
        NEAR_RADIUS
    )

    if not ok or type(parts) ~= "table" then
        parts = {}
    end

    table.sort(parts, function(a, b)
        local da = (a.Position - Root.Position).Magnitude
        local db = (b.Position - Root.Position).Magnitude
        return da < db
    end)

    for i, part in ipairs(parts) do
        if i > NEAR_LIMIT then
            table.insert(rows, "... nearby parts truncated ...")
            break
        end

        table.insert(rows, objectLine(part))

        if i % 250 == 0 then
            task.wait()
        end
    end

    writeText("NearbyParts.txt", table.concat(rows, "\n"))
    return math.min(#parts, NEAR_LIMIT)
end

local function dumpInteractions()
    status("interactions")

    local rows = {}
    local count = 0

    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("ProximityPrompt")
            or obj:IsA("ClickDetector")
            or obj:IsA("TouchTransmitter")
        then
            count += 1
            table.insert(rows, objectLine(obj))

            if count >= 1200 then
                table.insert(rows, "... interactions truncated ...")
                break
            end
        end
    end

    writeText("Interactions.txt", table.concat(rows, "\n"))
    return count
end

local function dumpRoundDoors()
    status("round doors / portals")

    local rows = {}
    local containers = {}

    if workspace:FindFirstChild("RoundDoor") then
        table.insert(containers, workspace.RoundDoor)
    end

    for _, obj in ipairs(workspace:GetDescendants()) do
        local low = string.lower(obj.Name)

        if obj ~= workspace:FindFirstChild("RoundDoor")
            and (
                low == "rounddoor"
                or string.find(low, "rounddoor", 1, true)
                or string.find(low, "portal", 1, true)
                or string.find(low, "checkpoint", 1, true)
            )
        then
            table.insert(containers, obj)

            if #containers >= 180 then
                break
            end
        end
    end

    local seen = {}
    local written = 0

    local function add(obj)
        if not obj or seen[obj] or written >= 1800 then
            return
        end

        seen[obj] = true
        written += 1
        table.insert(rows, objectLine(obj))
    end

    for _, container in ipairs(containers) do
        add(container)

        for _, child in ipairs(container:GetDescendants()) do
            add(child)
            if written >= 1800 then
                break
            end
        end
    end

    writeText("RoundDoors_Portals.txt", table.concat(rows, "\n"))
    return written
end

local function dumpRemotesAndModules()
    status("remotes / modules")

    local remotes = {}
    local modules = {}
    local remoteCount = 0
    local moduleCount = 0

    local function scan(root, rootLabel)
        for _, obj in ipairs(root:GetDescendants()) do
            if obj:IsA("RemoteEvent")
                or obj:IsA("RemoteFunction")
            then
                remoteCount += 1

                if remoteCount <= REMOTE_LIMIT then
                    table.insert(
                        remotes,
                        rootLabel .. " | " .. objectLine(obj)
                    )
                end

            elseif obj:IsA("ModuleScript") then
                moduleCount += 1

                if moduleCount <= MODULE_LIMIT then
                    local hits = keywordHits(obj.Name)
                    local marker =
                        #hits > 0
                        and " relevant=" .. table.concat(hits, ",")
                        or ""

                    table.insert(
                        modules,
                        rootLabel
                            .. " | "
                            .. fullName(obj)
                            .. marker
                            .. " | attrs={"
                            .. attributesText(obj, 18)
                            .. "}"
                    )
                end
            end
        end
    end

    scan(ReplicatedStorage, "ReplicatedStorage")
    scan(workspace, "Workspace")

    writeText("Remotes.txt", table.concat(remotes, "\n"))
    writeText("Modules.txt", table.concat(modules, "\n"))

    return remoteCount, moduleCount
end

local function candidateRoot(part)
    local current = part
    local best = part

    for _ = 1, 4 do
        if not current or current == workspace then
            break
        end

        if #keywordHits(current.Name) > 0
            or metricText(current) ~= ""
        then
            best = current
        end

        current = current.Parent
    end

    return best
end

local function interactionCount(obj)
    local prompts = 0
    local touches = 0
    local clicks = 0
    local remotes = 0
    local scanned = 0

    for _, child in ipairs(obj:GetDescendants()) do
        scanned += 1
        if scanned > 350 then
            break
        end

        if child:IsA("ProximityPrompt") then
            prompts += 1
        elseif child:IsA("TouchTransmitter") then
            touches += 1
        elseif child:IsA("ClickDetector") then
            clicks += 1
        elseif child:IsA("RemoteEvent")
            or child:IsA("RemoteFunction")
        then
            remotes += 1
        end
    end

    return prompts, touches, clicks, remotes
end

local function dumpPotentialObjectives()
    status("potential gates / barriers")

    local rows = {}
    local seen = {}
    local parts = {}

    if Root then
        local ok, value = pcall(
            workspace.GetPartBoundsInRadius,
            workspace,
            Root.Position,
            520
        )

        if ok and type(value) == "table" then
            parts = value
        end
    end

    if #parts == 0 then
        for _, obj in ipairs(workspace:GetDescendants()) do
            if obj:IsA("BasePart") then
                table.insert(parts, obj)
                if #parts >= 5000 then
                    break
                end
            end
        end
    end

    for _, part in ipairs(parts) do
        local obj = candidateRoot(part)

        if obj and not seen[obj] then
            seen[obj] = true

            local hits = keywordHits(obj.Name)
            local metrics = metricText(obj)
            local prompts, touches, clicks, remotes =
                interactionCount(obj)

            if #hits > 0
                or metrics ~= ""
                or prompts > 0
                or touches > 0
                or clicks > 0
                or remotes > 0
            then
                local dist = distanceFromPlayer(obj) or 99999
                local score =
                    #hits * 20
                    + (metrics ~= "" and 85 or 0)
                    + prompts * 6
                    + touches * 5
                    + clicks * 4
                    + remotes * 8
                    - math.min(dist, 600) * 0.02

                table.insert(rows, {
                    Object = obj,
                    Distance = dist,
                    Score = score,
                    Hits = table.concat(hits, ","),
                    Metrics = metrics,
                    Prompts = prompts,
                    Touches = touches,
                    Clicks = clicks,
                    Remotes = remotes,
                })
            end
        end
    end

    table.sort(rows, function(a, b)
        if math.abs(a.Score - b.Score) > 0.01 then
            return a.Score > b.Score
        end
        return a.Distance < b.Distance
    end)

    local out = {}

    for i, row in ipairs(rows) do
        if i > RELEVANT_LIMIT then
            table.insert(out, "... candidates truncated ...")
            break
        end

        table.insert(
            out,
            string.format(
                "#%d score=%.1f dist=%.1f hits=%s interactions=prompt:%d,touch:%d,click:%d,remote:%d metrics={%s} | %s",
                i,
                row.Score,
                row.Distance,
                row.Hits,
                row.Prompts,
                row.Touches,
                row.Clicks,
                row.Remotes,
                row.Metrics,
                objectLine(row.Object)
            )
        )
    end

    writeText("PotentialObjectives.txt", table.concat(out, "\n"))
    return rows
end

local function compactRoundState()
    local cfg = ReplicatedStorage:FindFirstChild("GameRoundCfg")
    local rows = {}

    if cfg then
        local attrs = attributesText(cfg, 40)
        if attrs ~= "" then
            table.insert(rows, "cfgAttrs=" .. attrs)
        end

        for _, obj in ipairs(cfg:GetDescendants()) do
            local low = string.lower(obj.Name)

            if string.find(low, "round", 1, true)
                or string.find(low, "state", 1, true)
                or string.find(low, "stage", 1, true)
                or string.find(low, "section", 1, true)
            then
                table.insert(
                    rows,
                    obj.Name
                        .. "="
                        .. valueText(obj)
                        .. " attrs="
                        .. attributesText(obj, 10)
                )

                if #rows >= 24 then
                    break
                end
            end
        end
    end

    return table.concat(rows, " | ")
end

local function countContainerModels(name)
    local container = workspace:FindFirstChild(name)
    if not container then
        return 0
    end

    local n = 0
    for _, child in ipairs(container:GetDescendants()) do
        if child:IsA("Humanoid") and child.Health > 0 then
            n += 1
        end
    end
    return n
end

local function timelineSnapshot(tag, candidates)
    local top = {}

    for i = 1, math.min(5, #candidates) do
        local row = candidates[i]
        local obj = row.Object

        table.insert(
            top,
            tostring(obj and obj.Parent and obj.Name or "REMOVED")
                .. "{" .. tostring(obj and metricText(obj) or "") .. "}"
        )
    end

    return table.concat({
        "[" .. string.format("%.2f", os.clock()) .. "]",
        tostring(tag),
        "pos=" .. tostring(Root and Root.Position),
        "world=" .. tostring(workspace:GetAttribute("WorldName")),
        "enemyNpc=" .. tostring(countContainerModels("EnemyNpc")),
        "worldEnemies=" .. tostring(countContainerModels("WorldEnemys")),
        "round={" .. compactRoundState() .. "}",
        "topCandidates=" .. table.concat(top, ","),
    }, " | ")
end

--========================================================--
-- RUN
--========================================================--

if type(writefile) ~= "function" then
    status("STOP | executor has no writefile")
    warn("[IronSoul Recon] writefile unavailable; cannot build recon package")
    return
end

status("starting read-only recon")

dumpExecutorCaps()
dumpGameState()
dumpPlayerSurface()

local workspaceWritten, workspaceLoaded = dumpWorkspaceIndex()
local nearbyCount = dumpNearbyParts()
local interactionCountTotal = dumpInteractions()
local roundDoorCount = dumpRoundDoors()
local remoteCount, moduleCount = dumpRemotesAndModules()
local candidates = dumpPotentialObjectives()

local eventRows = {}
local function captureEvent(kind, obj)
    if #eventRows >= 1000 then
        return
    end

    if not obj then
        return
    end

    local relevant =
        obj:IsA("ProximityPrompt")
        or obj:IsA("TouchTransmitter")
        or obj:IsA("RemoteEvent")
        or obj:IsA("RemoteFunction")
        or #keywordHits(obj.Name) > 0
        or metricText(obj) ~= ""

    if relevant then
        table.insert(
            eventRows,
            "[" .. string.format("%.2f", os.clock()) .. "] "
                .. tostring(kind)
                .. " | "
                .. objectLine(obj)
        )
    end
end

local addedConn = workspace.DescendantAdded:Connect(function(obj)
    pcall(captureEvent, "ADDED", obj)
end)

local removingConn = workspace.DescendantRemoving:Connect(function(obj)
    pcall(captureEvent, "REMOVING", obj)
end)

local timeline = {
    timelineSnapshot("WATCH_START", candidates),
}

for second = 1, WATCH_SECONDS do
    status(
        "watching new world "
            .. tostring(second)
            .. "/"
            .. tostring(WATCH_SECONDS)
    )

    task.wait(1)

    Character = LocalPlayer.Character
    Root = Character
        and Character:FindFirstChild("HumanoidRootPart")

    table.insert(
        timeline,
        timelineSnapshot("T+" .. tostring(second), candidates)
    )
end

pcall(function() addedConn:Disconnect() end)
pcall(function() removingConn:Disconnect() end)

writeText("Timeline.txt", table.concat(timeline, "\n"))
writeText("WorldEvents.txt", table.concat(eventRows, "\n"))

local summary = {
    "Version=" .. VERSION,
    "Mode=READ_ONLY_WORLD_RECON",
    "PlaceId=" .. tostring(game.PlaceId),
    "JobId=" .. tostring(game.JobId),
    "WorldName=" .. tostring(workspace:GetAttribute("WorldName")),
    "PlayerPos=" .. tostring(Root and Root.Position),
    "WorkspaceLoadedDescendants=" .. tostring(workspaceLoaded),
    "WorkspaceIndexed=" .. tostring(workspaceWritten),
    "NearbyParts=" .. tostring(nearbyCount),
    "Interactions=" .. tostring(interactionCountTotal),
    "RoundDoorPortalRows=" .. tostring(roundDoorCount),
    "RemoteCount=" .. tostring(remoteCount),
    "ModuleCount=" .. tostring(moduleCount),
    "PotentialObjectiveCount=" .. tostring(#candidates),
    "WatchSeconds=" .. tostring(WATCH_SECONDS),
    "CapturedWorldEvents=" .. tostring(#eventRows),
    "Output=" .. tostring(baseName),
}

writeText("Summary.txt", table.concat(summary, "\n"))

writeText(
    "README.txt",
    table.concat({
        "IRON SOUL WORLD RECON V61.11",
        "",
        "This diagnostic is read-only. It did not fire remotes, prompts, touches, or attacks.",
        "Run it while standing at the exact new/stuck mechanic whenever possible.",
        "",
        "Most useful files to send:",
        "1. Summary.txt",
        "2. GameState.txt",
        "3. PotentialObjectives.txt",
        "4. RoundDoors_Portals.txt",
        "5. Interactions.txt",
        "6. Remotes.txt",
        "7. Timeline.txt",
        "8. WorldEvents.txt",
        "9. NearbyParts.txt",
        "10. WorkspaceIndex.txt",
        "",
        "ZIP the whole output folder and send it back to ChatGPT.",
    }, "\n")
)

writeText(
    "DONE.txt",
    "ReconComplete=true\nOutput=" .. tostring(baseName)
)

status("DONE | zip folder: " .. tostring(baseName))

print(
    "[IronSoul Recon] COMPLETE. ZIP this folder:",
    baseName
)
