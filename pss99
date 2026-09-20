local ok, err = pcall(function()
    local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

    local Players = game:GetService("Players")
    local RunService = game:GetService("RunService")
    local LocalPlayer = Players.LocalPlayer

    local BlockWorldClient = require(game.ReplicatedStorage.Library.Client.ToolCmds.BlockWorldClient)
    local ToolCmds = require(game.ReplicatedStorage.Library.Client.ToolCmds)
    local ToolUtil = require(game.ReplicatedStorage.Library.Util.ToolUtil)
    local PickaxeUtil = require(game.ReplicatedStorage.Library.Util.PickaxeUtil)
    local AutoMineCmds = require(game.ReplicatedStorage.Library.Client.AutoMineCmds)

    if type(getgenv().NuclidePS99_Unload) == "function" then
        pcall(getgenv().NuclidePS99_Unload)
    end

    local State = {
        Unloaded = false,
        AutoMine = false,
        Teleport = true,
        Priority = "Top-down",
        Radius = 60,
        BlocksPerSweep = 4,
        MaxRetries = 3,
        MaxBreakTime = 10,
        OreFilter = { "All ores" },
        ChamsEnabled = false,
        ChamsColor = Color3.fromRGB(170, 0, 255),
        ChamsTargets = { "All ores" },
    }

    local Connections = {}
    local Queue = {}
    local Current = nil
    local Blacklist = {}
    local TimeCache = {}
    local CHAM_NAME = "NuclideChams"

    local Stalls = {
        lastDamage = -1,
        lastChange = 0,
        footMismatch = 0,
    }

    local ORE_IDS = {
        Sapphire = "Moonstone Ore",
        Ruby = "Star Ruby Ore",
        Emerald = "Helium-3 Ore",
        Amethyst = "Nebulite Ore",
        Rainbow = "Dark Matter Ore",
        Quartz = "Quartz Ore",
        Topaz = "Topaz Ore",
        Onyx = "Onyx Ore",
    }

    local NAME_TO_ID = {}
    local ORE_OPTIONS = { "All ores" }
    for id, name in pairs(ORE_IDS) do
        NAME_TO_ID[name] = id
        table.insert(ORE_OPTIONS, name)
    end

    local StatusLabel

    local function notify(text)
        Rayfield:Notify({
            Title = "Nuclide",
            Content = text,
            Duration = 3,
        })
    end

    local function setStatus(text)
        if StatusLabel then
            pcall(function()
                StatusLabel:Set("Status: " .. text)
            end)
        end
    end

    local function isAlive(block)
        local part = block:GetPart()
        return part ~= nil and part.Parent ~= nil
    end

    local function encode(pos)
        return pos.X .. "_" .. pos.Y .. "_" .. pos.Z
    end

    local function getDps(directory)
        local selected = ToolUtil.GetSelectedTool(LocalPlayer, "Pickaxe")
        local best = ToolUtil.GetBestTool(LocalPlayer, "Pickaxe", true)
        if not (selected and best) then
            return 0
        end

        local success, dps = pcall(function()
            return PickaxeUtil.ComputeDamage(LocalPlayer, selected, best, directory)
                * PickaxeUtil.ComputeSpeed(LocalPlayer, selected)
        end)

        if success and dps and dps > 0 then
            return dps
        end

        return 0
    end

    local function getBreakTime(directory)
        local key = directory._id or directory.DisplayName
        if TimeCache[key] then
            return TimeCache[key]
        end

        local dps = getDps(directory)
        local strength = PickaxeUtil.ComputeStrength(directory)
        local breakTime = dps > 0 and strength / dps or math.huge

        TimeCache[key] = breakTime
        return breakTime
    end

    local function isWantedOre(id)
        if not ORE_IDS[id] then
            return false
        end

        if table.find(State.OreFilter, "All ores") then
            return true
        end

        return table.find(State.OreFilter, ORE_IDS[id]) ~= nil
    end

    local function makeHighlight(part, color, fill)
        local highlight = Instance.new("Highlight")
        highlight.Name = CHAM_NAME
        highlight.FillColor = color
        highlight.OutlineColor = color
        highlight.FillTransparency = fill
        highlight.OutlineTransparency = 0
        highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        highlight.Parent = part
    end

    local function removeHighlight(part)
        local existing = part and part:FindFirstChild(CHAM_NAME)
        if existing then
            existing:Destroy()
        end
    end

    local function teleportTo(cframe)
        local character = LocalPlayer.Character
        local root = character and character:FindFirstChild("HumanoidRootPart")
        if not root then
            return
        end

        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
        character:PivotTo(CFrame.new(cframe.Position + Vector3.new(0, 8, 0)))
    end

    local function isStandable(world, pos)
        return world:GetBlock(pos + Vector3int16.new(0, 1, 0)) == nil
            and world:GetBlock(pos + Vector3int16.new(0, 2, 0)) == nil
    end

    local function repick(world)
        local character = LocalPlayer.Character
        local root = character and character:FindFirstChild("HumanoidRootPart")
        if not root then
            return false
        end

        local origin = root.Position
        local candidates = {}

        for _, block in pairs(world.Blocks) do
            if isAlive(block) then
                local directory = block:GetDirectory()
                local breakTime = getBreakTime(directory)

                if breakTime <= State.MaxBreakTime then
                    local pos = block:GetPosition()
                    local key = encode(pos)

                    if not Blacklist[key] and isStandable(world, pos) then
                        local dist = (block:GetCFrame().Position - origin).Magnitude
                        if dist <= State.Radius then
                            local id = directory._id or ""
                            local priority = 0
                            if isWantedOre(id) then
                                priority = 2
                            elseif ORE_IDS[id] then
                                priority = 1
                            end

                            table.insert(candidates, {
                                block = block,
                                pos = pos,
                                dist = dist,
                                tier = directory.Tier or 0,
                                strength = PickaxeUtil.ComputeStrength(directory),
                                prio = priority,
                            })
                        end
                    end
                end
            end
        end

        if #candidates == 0 then
            setStatus("no minable blocks in radius")
            return false
        end

        if State.Priority == "Top-down" then
            table.sort(candidates, function(a, b)
                if a.prio ~= b.prio then
                    return a.prio > b.prio
                end
                if a.pos.Y ~= b.pos.Y then
                    return a.pos.Y > b.pos.Y
                end
                return a.dist < b.dist
            end)
        elseif State.Priority == "Rarest first" then
            table.sort(candidates, function(a, b)
                if a.prio ~= b.prio then
                    return a.prio > b.prio
                end
                if a.tier ~= b.tier then
                    return a.tier > b.tier
                end
                return a.dist < b.dist
            end)
        elseif State.Priority == "Lowest Strength" then
            table.sort(candidates, function(a, b)
                if a.prio ~= b.prio then
                    return a.prio > b.prio
                end
                if a.strength ~= b.strength then
                    return a.strength < b.strength
                end
                return a.dist < b.dist
            end)
        else
            table.sort(candidates, function(a, b)
                if a.prio ~= b.prio then
                    return a.prio > b.prio
                end
                return a.dist < b.dist
            end)
        end

        table.clear(Queue)
        for i = 1, math.min(#candidates, State.BlocksPerSweep) do
            local candidate = candidates[i]
            table.insert(Queue, {
                pos = candidate.pos,
                directory = candidate.block:GetDirectory(),
                retries = 0,
            })
        end

        return true
    end

    local lastStatus = 0

    local function onHeartbeat()
        if State.Unloaded or not State.AutoMine then
            return
        end

        local world = BlockWorldClient.GetLocal()
        if not world or world:IsDestroyed() then
            Queue = {}
            Current = nil
            setStatus("not in the mine")
            return
        end

        if not AutoMineCmds.IsEnabled() then
            AutoMineCmds.Enable()
        end

        local now = os.clock()

        if Current then
            local block = world:GetBlock(Current.pos)

            if not (block and isAlive(block)) then
                Current = nil
                Stalls.footMismatch = 0
            elseif now >= Current.deadline then
                if Current.retries >= State.MaxRetries then
                    Blacklist[encode(Current.pos)] = true
                    Current = nil
                else
                    Current.retries += 1
                    Current.deadline = now + getBreakTime(Current.directory) * 1.6 + 2
                    Stalls.lastDamage = -1
                    if State.Teleport then
                        teleportTo(block:GetCFrame())
                    end
                end
            else
                local entry = world.Players[LocalPlayer]

                if entry and entry.Target == Current.pos then
                    local damage = entry.TargetDamage or 0

                    if damage ~= Stalls.lastDamage then
                        Stalls.lastDamage = damage
                        Stalls.lastChange = now
                    elseif now - Stalls.lastChange > 2.5 then
                        Stalls.lastChange = now
                        Stalls.lastDamage = -1
                        Current.retries += 1
                        world:LocalSetTarget(nil)
                        task.delay(0.1, function()
                            if Current and not State.Unloaded then
                                local currentBlock = world:GetBlock(Current.pos)
                                if currentBlock then
                                    world:LocalSetTarget(currentBlock)
                                end
                            end
                        end)
                    end
                end

                local foot = ToolCmds.GetBlockAtFoot()
                if foot and encode(foot:GetPosition()) ~= encode(Current.pos) then
                    Stalls.footMismatch += 1
                    if Stalls.footMismatch > 15 then
                        Stalls.footMismatch = 0
                        Current.retries += 1
                        Stalls.lastDamage = -1
                        if State.Teleport then
                            teleportTo(block:GetCFrame())
                        end
                        world:LocalSetTarget(block)
                    end
                else
                    Stalls.footMismatch = 0
                end
            end
        end

        if not Current then
            if #Queue == 0 then
                if not repick(world) then
                    return
                end
            end

            while #Queue > 0 do
                local candidate = table.remove(Queue, 1)
                local block = world:GetBlock(candidate.pos)
                if block and isAlive(block) and not Blacklist[encode(candidate.pos)] then
                    Current = candidate
                    Current.deadline = now + getBreakTime(candidate.directory) * 1.6 + 2
                    Stalls.lastDamage = -1
                    Stalls.lastChange = now
                    Stalls.footMismatch = 0
                    if State.Teleport then
                        teleportTo(block:GetCFrame())
                    end

                    if now - lastStatus > 0.5 then
                        lastStatus = now
                        setStatus("mining " .. (candidate.directory.DisplayName or candidate.directory._id or "?"))
                    end
                    break
                end
            end
        end

        if Current then
            local block = world:GetBlock(Current.pos)
            if block then
                local entry = world.Players[LocalPlayer]
                if not (entry and entry.Target and entry.Target == Current.pos) then
                    world:LocalSetTarget(block)
                end
            end
        end
    end

    table.insert(Connections, RunService.Heartbeat:Connect(onHeartbeat))

    local function shouldCham(directory)
        if not State.ChamsEnabled then
            return false
        end

        local id = directory._id or ""

        for _, target in ipairs(State.ChamsTargets) do
            if target == "All ores" then
                if ORE_IDS[id] then
                    return true
                end
            elseif NAME_TO_ID[target] == id then
                return true
            end
        end

        return false
    end

    local function clearChams()
        local world = BlockWorldClient.GetLocal()
        if not world then
            return
        end

        for _, block in pairs(world.Blocks) do
            removeHighlight(block:GetPart())
        end
    end

    task.spawn(function()
        while not State.Unloaded do
            if State.ChamsEnabled then
                pcall(function()
                    local world = BlockWorldClient.GetLocal()
                    if world and not world:IsDestroyed() then
                        for _, block in pairs(world.Blocks) do
                            local part = block:GetPart()
                            if part and part.Parent then
                                local existing = part:FindFirstChild(CHAM_NAME)
                                if shouldCham(block:GetDirectory()) then
                                    if existing then
                                        if existing.FillColor ~= State.ChamsColor then
                                            existing.FillColor = State.ChamsColor
                                            existing.OutlineColor = State.ChamsColor
                                        end
                                    else
                                        makeHighlight(part, State.ChamsColor, 0.45)
                                    end
                                elseif existing then
                                    existing:Destroy()
                                end
                            end
                        end
                    end
                end)
            end
            task.wait(0.4)
        end
    end)

    local function unload()
        if State.Unloaded then
            return
        end

        State.Unloaded = true
        State.AutoMine = false

        pcall(function()
            AutoMineCmds.Disable()
        end)

        pcall(function()
            local world = BlockWorldClient.GetLocal()
            if world then
                world:LocalSetTarget(nil)
            end
        end)

        pcall(clearChams)

        for _, connection in ipairs(Connections) do
            pcall(function()
                connection:Disconnect()
            end)
        end
        table.clear(Connections)

        getgenv().NuclidePS99_Unload = nil

        pcall(function()
            Rayfield:Destroy()
        end)
    end

    getgenv().NuclidePS99_Unload = unload

    local Window = Rayfield:CreateWindow({
        Name = "Nuclide | Pet Sim 99",
        LoadingTitle = "Nuclide",
        LoadingSubtitle = "Space Mine",
        ConfigurationSaving = {
            Enabled = true,
            FolderName = "NuclidePS99",
            FileName = "spacemine",
        },
    })

    local Tab = Window:CreateTab("Auto Mine", "pickaxe")
    local UnloadTab = Window:CreateTab("Unload", "power")

    StatusLabel = Tab:CreateLabel("Status: off")

    Tab:CreateSection("Farming")

    Tab:CreateToggle({
        Name = "Auto Mine",
        CurrentValue = false,
        Flag = "AutoMineEnabled",
        Callback = function(value)
            State.AutoMine = value
            if value then
                TimeCache = {}
            else
                AutoMineCmds.Disable()
                setStatus("off")
            end
        end,
    })

    Tab:CreateKeybind({
        Name = "Toggle Auto Mine",
        CurrentKeybind = "Z",
        HoldToInteract = false,
        Flag = "AutoMineKeybind",
        Callback = function()
            State.AutoMine = not State.AutoMine
            notify(State.AutoMine and "Auto Mine: ON" or "Auto Mine: OFF")
        end,
    })

    Tab:CreateToggle({
        Name = "Teleport to targets",
        CurrentValue = true,
        Flag = "TeleportTargets",
        Callback = function(value)
            State.Teleport = value
        end,
    })

    Tab:CreateDropdown({
        Name = "Ore filter",
        Options = ORE_OPTIONS,
        CurrentOption = { "All ores" },
        MultipleOptions = true,
        Flag = "OreFilter",
        Callback = function(options)
            State.OreFilter = type(options) == "table" and options or { options }
            TimeCache = {}
        end,
    })

    Tab:CreateDropdown({
        Name = "Digging mode",
        Options = { "Top-down", "Nearest", "Rarest first", "Lowest Strength" },
        CurrentOption = { "Top-down" },
        MultipleOptions = false,
        Flag = "TargetPriority",
        Callback = function(option)
            State.Priority = type(option) == "table" and option[1] or option
        end,
    })

    Tab:CreateSlider({
        Name = "Mining radius",
        Range = { 10, 150 },
        Increment = 5,
        Suffix = " studs",
        CurrentValue = 60,
        Flag = "MiningRadius",
        Callback = function(value)
            State.Radius = value
        end,
    })

    Tab:CreateSlider({
        Name = "Blocks per sweep",
        Range = { 1, 15 },
        Increment = 1,
        Suffix = " blocks",
        CurrentValue = 4,
        Flag = "BlocksPerSweep",
        Callback = function(value)
            State.BlocksPerSweep = value
        end,
    })

    Tab:CreateSlider({
        Name = "Max break time",
        Range = { 1, 60 },
        Increment = 1,
        Suffix = "s",
        CurrentValue = 10,
        Flag = "MaxBreakTime",
        Callback = function(value)
            State.MaxBreakTime = value
            TimeCache = {}
        end,
    })

    Tab:CreateSlider({
        Name = "Commit retries",
        Range = { 1, 6 },
        Increment = 1,
        Suffix = "x",
        CurrentValue = 3,
        Flag = "MaxRetries",
        Callback = function(value)
            State.MaxRetries = value
        end,
    })

    Tab:CreateSection("Chams")

    Tab:CreateToggle({
        Name = "Enable chams",
        CurrentValue = false,
        Flag = "ChamsEnabled",
        Callback = function(value)
            State.ChamsEnabled = value
            if not value then
                pcall(clearChams)
            end
        end,
    })

    Tab:CreateDropdown({
        Name = "Chams targets",
        Options = ORE_OPTIONS,
        CurrentOption = { "All ores" },
        MultipleOptions = true,
        Flag = "ChamsTargets",
        Callback = function(options)
            State.ChamsTargets = type(options) == "table" and options or { options }
        end,
    })

    Tab:CreateColorPicker({
        Name = "Chams color",
        Color = Color3.fromRGB(170, 0, 255),
        Flag = "ChamsColor",
        Callback = function(color)
            State.ChamsColor = color
        end,
    })

    UnloadTab:CreateButton({
        Name = "Unload script",
        Callback = unload,
    })

    notify("Loaded! Toggle Auto Mine inside the Space Mining event.")
end)

if not ok then
    warn("[Nuclide] load error: " .. tostring(err))
end
