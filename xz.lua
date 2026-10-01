local Rayfield = loadstring(game:HttpGet("https://sirius.menu/gen2"))()

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer

local unpack = table.unpack or unpack
local newcc = (type(newcclosure) == "function" and newcclosure) or function(f)
    return f
end

local S = {
    unloaded = false,
    teamCheck = true, deadCheck = true,
    silentAim = false, silentHitPart = "Head", silentFov = 120, showFov = false, wallCheck = true,
    silent360 = false, smartPriority = true,
    longArm = false, longArmRange = 20, longArmRate = 1, longArmBackstab = true,
    noSpread = false, triggerBot = false, triggerDelay = 0.05, autoFire = false,
    wallbang = false,
    hitmarker = true, hitSound = true, hitVolume = 1,
    esp = false, espCorner = true, espFill = true, espNames = true, espHealth = true, espDistance = true,
    espSkeleton = false, espSnaplines = false,
    enemyColor = Color3.fromRGB(255, 40, 80),
    chams = false, chamsColor = Color3.fromRGB(255, 40, 80),
    headDot = false,
    fovChange = false, fovValue = 100,
    fakeLag = false, fakeLagMs = 150,
    simRadius = false,
    pingDelay = false, pingDelayMs = 200,
    killcamPoison = false, spectateHijack = false,
    aaMode = "Off", spinSpeed = 360, jitterInterval = 0.1, fakeCrouch = false,
    pitchDesync = false, pitchValue = -80, lateralDesync = false, lateralAmount = 60,
    speedEnabled = false, speedValue = 16,
    bhop = false, infJump = false,
    noclip = false, fly = false, flySpeed = 60,
    silentDebug = false, thirdPerson = false, tpDistance = 8,
    roundBypass = false,
}

local remoteCache = {}
local deepScanned = false
local function findRemote(name)
    local cached = remoteCache[name]
    if cached and cached.Parent then
        return cached
    end
    local folder = ReplicatedStorage:FindFirstChild("Remotes")
    local r = folder and folder:FindFirstChild(name)
    if not r then
        local gameFolder = ReplicatedStorage:FindFirstChild("Game")
        local gr = gameFolder and gameFolder:FindFirstChild("Remotes")
        r = gr and gr:FindFirstChild(name)
    end
    if not r and not deepScanned then
        deepScanned = true
        r = ReplicatedStorage:FindFirstChild(name, true)
    end
    remoteCache[name] = r
    return r
end

local function getRootPart()
    local char = LocalPlayer.Character
    return char and char:FindFirstChild("HumanoidRootPart")
end

local function isEnemyModel(model)
    if not model or not model:IsA("Model") or not model:FindFirstChild("Head") then
        return false
    end
    local player = Players:GetPlayerFromCharacter(model)
    if player == LocalPlayer then
        return false
    end
    if S.teamCheck and player then
        local myTeam = LocalPlayer.Team
        if myTeam and player.Team == myTeam then
            return false
        end
    end
    if S.deadCheck then
        local humanoid = model:FindFirstChildOfClass("Humanoid")
        if humanoid and humanoid.Health <= 0 then
            return false
        end
    end
    return true
end

local function isPartVisible(part)
    local char = LocalPlayer.Character
    local camera = Workspace.CurrentCamera
    if not char or not camera then
        return false
    end
    local origin = camera.CFrame.Position
    local dir = part.Position - origin
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = { char }
    params.IgnoreWater = true
    local res = Workspace:Raycast(origin, dir, params)
    if not res then
        return true
    end
    return res.Instance:IsDescendantOf(part.Parent)
end

local VIS_PRIORITY = {
    "Head", "Torso", "UpperTorso", "HumanoidRootPart", "LowerTorso",
    "Left Arm", "Right Arm", "LeftUpperArm", "RightUpperArm",
    "Left Leg", "Right Leg", "LeftUpperLeg", "RightUpperLeg",
}
local visCache = {}
local function findVisiblePart(model)
    local now = os.clock()
    local cached = visCache[model]
    if cached and now - cached.at < 0.1 then
        local p = cached.part
        if p then
            if p.Parent then
                return p
            end
        else
            return nil
        end
    end
    local char = LocalPlayer.Character
    local camera = Workspace.CurrentCamera
    if not char or not camera then
        return nil
    end
    local origin = camera.CFrame.Position
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = { char }
    params.IgnoreWater = true
    local preferred = model:FindFirstChild(S.silentHitPart)
    local fallbackHead = model:FindFirstChild("Head")
    local candidates = {}
    if preferred then
        table.insert(candidates, preferred)
    end
    if fallbackHead and fallbackHead ~= preferred then
        table.insert(candidates, fallbackHead)
    end
    for _, name in ipairs(VIS_PRIORITY) do
        if #candidates >= 9 then
            break
        end
        local p = model:FindFirstChild(name)
        if p and p ~= preferred and p ~= fallbackHead then
            table.insert(candidates, p)
        end
    end
    for _, part in ipairs(candidates) do
        local res = Workspace:Raycast(origin, part.Position - origin, params)
        if not res or res.Instance:IsDescendantOf(model) then
            visCache[model] = { part = part, at = now }
            return part
        end
    end
    visCache[model] = { part = nil, at = now }
    return nil
end

local function getSilentTarget(camera)
    local folder = Workspace:FindFirstChild("Characters")
    if not folder then
        return nil
    end
    local center = camera.ViewportSize / 2
    local origin = camera.CFrame.Position
    local best, bestScore = nil, math.huge
    for _, model in ipairs(folder:GetChildren()) do
        if isEnemyModel(model) then
            local visPart = nil
            if S.wallCheck then
                visPart = findVisiblePart(model)
            end
            if visPart or not S.wallCheck or S.wallbang then
                local part
                if S.wallCheck and not S.wallbang then
                    part = visPart
                else
                    part = model:FindFirstChild(S.silentHitPart) or model:FindFirstChild("Head")
                end
                if part then
                    local pos = camera:WorldToViewportPoint(part.Position)
                    local inFront = pos.Z > 0
                    local crosshairDist = inFront and (Vector2.new(pos.X, pos.Y) - center).Magnitude or math.huge
                    if S.silent360 or crosshairDist <= S.silentFov then
                        local visible = visPart ~= nil or not S.wallCheck
                        local score
                        if S.smartPriority and not visible then
                            score = 1000000 + (S.silent360 and (part.Position - origin).Magnitude or crosshairDist)
                        elseif S.silent360 then
                            score = (part.Position - origin).Magnitude
                        else
                            score = crosshairDist
                        end
                        if score < bestScore then
                            best, bestScore = part, score
                        end
                    end
                end
            end
        end
    end
    return best
end

local function findThroughWallTarget(origin, dirVec)
    local folder = Workspace:FindFirstChild("Characters")
    if not folder then
        return nil
    end
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Include
    local range = math.min(dirVec.Magnitude, 1000)
    local dir = dirVec.Unit
    local best = nil
    for _, model in ipairs(folder:GetChildren()) do
        if isEnemyModel(model) then
            params.FilterDescendantsInstances = { model }
            local res = Workspace:Raycast(origin, dir * range, params)
            if res and res.Instance then
                local d = (res.Position - origin).Magnitude
                if not best or d < best.dist then
                    best = { part = res.Instance, pos = res.Position, normal = res.Normal, dist = d }
                end
            end
        end
    end
    return best
end

local function crosshairOverEnemy(camera)
    local char = LocalPlayer.Character
    if not char then
        return false
    end
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = { char }
    params.IgnoreWater = true
    local res = Workspace:Raycast(camera.CFrame.Position, camera.CFrame.LookVector * 1000, params)
    if res and res.Instance then
        local model = res.Instance:FindFirstAncestorOfClass("Model")
        return isEnemyModel(model)
    end
    return false
end

local canClick = "none"
if type(mouse1press) == "function" and type(mouse1release) == "function" then
    canClick = "mouse1"
else
    canClick = "vim"
end
local vim = game:GetService("VirtualInputManager")
local function fireClick()
    if canClick == "mouse1" then
        mouse1press()
        task.delay(0.03, mouse1release)
    elseif canClick == "vim" then
        local camera = Workspace.CurrentCamera
        local vp = camera and camera.ViewportSize or Vector2.new(1920, 1080)
        vim:SendMouseButtonEvent(vp.X / 2, vp.Y / 2, 0, true, game, 0)
        task.delay(0.03, function()
            vim:SendMouseButtonEvent(vp.X / 2, vp.Y / 2, 0, false, game, 0)
        end)
    else
        pcall(function()
            local VirtualUser = game:GetService("VirtualUser")
            VirtualUser:Button1Down(Vector2.new())
            task.delay(0.03, function()
                VirtualUser:Button1Up(Vector2.new())
            end)
        end)
    end
end

local hasDrawing = pcall(function()
    local d = Drawing.new("Circle")
    d:Remove()
end)

local fovCircle
if hasDrawing then
    fovCircle = Drawing.new("Circle")
    fovCircle.Thickness = 1
    fovCircle.NumSides = 64
    fovCircle.Radius = S.silentFov
    fovCircle.Filled = false
    fovCircle.Transparency = 0.5
    fovCircle.Color = Color3.fromRGB(255, 255, 255)
    fovCircle.Visible = false
end

local hitLines = {}
if hasDrawing then
    for i = 1, 4 do
        local line = Drawing.new("Line")
        line.Thickness = 2
        line.Color = Color3.fromRGB(255, 255, 255)
        line.Transparency = 0
        line.Visible = false
        hitLines[i] = line
    end
end

local hitmarkerToken = 0
local function showHitmarker()
    if not hasDrawing then
        return
    end
    hitmarkerToken += 1
    local token = hitmarkerToken
    local vp = Workspace.CurrentCamera.ViewportSize
    local cx, cy = vp.X / 2, vp.Y / 2
    local gap, len = 7, 6
    local segs = {
        { cx - gap, cy - gap, cx - gap - len, cy - gap - len },
        { cx + gap, cy - gap, cx + gap + len, cy - gap - len },
        { cx - gap, cy + gap, cx - gap - len, cy + gap + len },
        { cx + gap, cy + gap, cx + gap + len, cy + gap + len },
    }
    for i, seg in ipairs(segs) do
        local line = hitLines[i]
        line.From = Vector2.new(seg[1], seg[2])
        line.To = Vector2.new(seg[3], seg[4])
        line.Transparency = 1
        line.Visible = true
    end
    task.spawn(function()
        for t = 1, 12 do
            if S.unloaded or token ~= hitmarkerToken then
                return
            end
            task.wait(0.02)
            for _, line in ipairs(hitLines) do
                line.Transparency = 1 - t / 12
            end
        end
        if token == hitmarkerToken and not S.unloaded then
            for _, line in ipairs(hitLines) do
                line.Visible = false
            end
        end
    end)
end

local hitSound = Instance.new("Sound")
hitSound.SoundId = "rbxasset://sounds/electronicpingshort.wav"
hitSound.PlaybackSpeed = 1.5
hitSound.Volume = S.hitVolume
hitSound.Parent = SoundService

local espObjects = {}

local function destroyEspObj(model)
    local obj = espObjects[model]
    if not obj then
        return
    end
    for _, d in pairs(obj) do
        if type(d) == "table" then
            for _, sub in ipairs(d) do
                pcall(function()
                    sub:Remove()
                end)
            end
        else
            pcall(function()
                d:Remove()
            end)
        end
    end
    espObjects[model] = nil
    visCache[model] = nil
end

local function createEspObj()
    local obj = {}
    local function mkLine()
        local l = Drawing.new("Line")
        l.Thickness = 1
        l.Transparency = 1
        l.Visible = false
        return l
    end
    obj.corners = {}
    for i = 1, 8 do
        obj.corners[i] = mkLine()
    end
    obj.box = Drawing.new("Square")
    obj.box.Thickness = 1
    obj.box.Filled = false
    obj.box.Transparency = 1
    obj.box.Visible = false
    obj.fill = Drawing.new("Square")
    obj.fill.Thickness = 1
    obj.fill.Filled = true
    obj.fill.Color = Color3.fromRGB(0, 0, 0)
    obj.fill.Transparency = 0.6
    obj.fill.Visible = false
    obj.name = Drawing.new("Text")
    obj.name.Size = 13
    obj.name.Center = true
    obj.name.Outline = true
    obj.name.Font = 2
    obj.name.Visible = false
    obj.dist = Drawing.new("Text")
    obj.dist.Size = 12
    obj.dist.Center = true
    obj.dist.Outline = true
    obj.dist.Font = 2
    obj.dist.Color = Color3.fromRGB(255, 255, 255)
    obj.dist.Visible = false
    obj.hpBg = Drawing.new("Square")
    obj.hpBg.Thickness = 1
    obj.hpBg.Filled = true
    obj.hpBg.Color = Color3.fromRGB(20, 20, 20)
    obj.hpBg.Transparency = 0.7
    obj.hpBg.Visible = false
    obj.hpFill = Drawing.new("Square")
    obj.hpFill.Thickness = 1
    obj.hpFill.Filled = true
    obj.hpFill.Color = Color3.fromRGB(0, 255, 80)
    obj.hpFill.Transparency = 1
    obj.hpFill.Visible = false
    obj.skel = {}
    for i = 1, 15 do
        obj.skel[i] = mkLine()
    end
    obj.snap = mkLine()
    obj.dot = Drawing.new("Circle")
    obj.dot.Thickness = 1
    obj.dot.NumSides = 12
    obj.dot.Radius = 4
    obj.dot.Filled = true
    obj.dot.Visible = false
    return obj
end

local function hideEspObj(obj)
    obj.box.Visible = false
    obj.fill.Visible = false
    obj.name.Visible = false
    obj.dist.Visible = false
    obj.hpBg.Visible = false
    obj.hpFill.Visible = false
    obj.dot.Visible = false
    obj.snap.Visible = false
    for _, l in ipairs(obj.corners) do
        l.Visible = false
    end
    for _, l in ipairs(obj.skel) do
        l.Visible = false
    end
end

local function skeletonJoints(model)
    local head = model:FindFirstChild("Head")
    local torso = model:FindFirstChild("Torso") or model:FindFirstChild("UpperTorso")
    local lower = model:FindFirstChild("LowerTorso")
    local root = model:FindFirstChild("HumanoidRootPart")
    local joints = {}
    if head and torso then
        table.insert(joints, { head, torso })
    end
    if torso and lower then
        table.insert(joints, { torso, lower })
    end
    if torso and root and root ~= torso then
        table.insert(joints, { torso, root })
    end
    local pairsList
    if model:FindFirstChild("Left Arm") then
        pairsList = {
            { "Torso", "Left Arm" }, { "Torso", "Right Arm" },
            { "Torso", "Left Leg" }, { "Torso", "Right Leg" },
        }
    else
        pairsList = {
            { "UpperTorso", "LeftUpperArm" }, { "LeftUpperArm", "LeftLowerArm" }, { "LeftLowerArm", "LeftHand" },
            { "UpperTorso", "RightUpperArm" }, { "RightUpperArm", "RightLowerArm" }, { "RightLowerArm", "RightHand" },
            { "LowerTorso", "LeftUpperLeg" }, { "LeftUpperLeg", "LeftLowerLeg" }, { "LeftLowerLeg", "LeftFoot" },
            { "LowerTorso", "RightUpperLeg" }, { "RightUpperLeg", "RightLowerLeg" }, { "RightLowerLeg", "RightFoot" },
        }
    end
    for _, pr in ipairs(pairsList) do
        local a = model:FindFirstChild(pr[1])
        local b = model:FindFirstChild(pr[2])
        if a and b then
            table.insert(joints, { a, b })
        end
    end
    return joints
end

local function destroyAllChams()
    local folder = Workspace:FindFirstChild("Characters")
    if not folder then
        return
    end
    for _, model in ipairs(folder:GetChildren()) do
        local h = model:FindFirstChild("XZ_Chams")
        if h then
            h:Destroy()
        end
    end
end

local ESP_HEAD_OFF = Vector3.new(0, 0.6, 0)
local ESP_FEET_OFF = Vector3.new(0, 2.9, 0)

local function updateEsp(camera)
    if not hasDrawing then
        return
    end
    for model in pairs(espObjects) do
        if not model.Parent or not isEnemyModel(model) then
            destroyEspObj(model)
        end
    end
    if not S.esp and not S.chams and not S.headDot then
        for model in pairs(espObjects) do
            destroyEspObj(model)
        end
        return
    end
    local folder = Workspace:FindFirstChild("Characters")
    if not folder then
        return
    end
    local function setSeg(line, x1, y1, x2, y2)
        line.From = Vector2.new(x1, y1)
        line.To = Vector2.new(x2, y2)
        line.Visible = true
    end
    for _, model in ipairs(folder:GetChildren()) do
        if isEnemyModel(model) then
            if S.chams then
                if not model:FindFirstChild("XZ_Chams") then
                    local h = Instance.new("Highlight")
                    h.Name = "XZ_Chams"
                    h.FillColor = S.chamsColor
                    h.OutlineColor = Color3.fromRGB(255, 255, 255)
                    h.FillTransparency = 0.55
                    h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                    h.Parent = model
                else
                    model.XZ_Chams.FillColor = S.chamsColor
                end
            else
                local h = model:FindFirstChild("XZ_Chams")
                if h then
                    h:Destroy()
                end
            end
            local obj = espObjects[model]
            if not obj then
                obj = createEspObj()
                espObjects[model] = obj
            end
            if obj.lastColor ~= S.enemyColor then
                local c = S.enemyColor
                for _, l in ipairs(obj.corners) do
                    l.Color = c
                end
                obj.box.Color = c
                for _, l in ipairs(obj.skel) do
                    l.Color = c
                end
                obj.snap.Color = c
                obj.name.Color = c
                obj.dot.Color = c
                obj.lastColor = c
            end
            if not (S.esp or S.headDot) then
                hideEspObj(obj)
                continue
            end
            local head = model:FindFirstChild("Head")
            if not head then
                hideEspObj(obj)
                continue
            end
            local hrp = model:FindFirstChild("HumanoidRootPart")
            local hp3 = head.Position
            local bp3 = hrp and hrp.Position or (hp3 - ESP_HEAD_OFF)
            local topPos = camera:WorldToViewportPoint(hp3 + ESP_HEAD_OFF)
            local botPos = camera:WorldToViewportPoint(bp3 - ESP_FEET_OFF)
            if topPos.Z <= 0 or botPos.Z <= 0 then
                hideEspObj(obj)
                continue
            end
            local h = math.abs(botPos.Y - topPos.Y)
            local w = math.clamp(h / 2, 4, 400)
            local left = math.min(topPos.X, botPos.X) - w / 2
            local topY = math.min(topPos.Y, botPos.Y)
            if S.esp then
                if S.espFill then
                    obj.fill.Size = Vector2.new(w, h)
                    obj.fill.Position = Vector2.new(left, topY)
                    obj.fill.Visible = true
                else
                    obj.fill.Visible = false
                end
                if S.espCorner then
                    obj.box.Visible = false
                    local cl = math.clamp(math.floor(math.min(w, h) * 0.25), 3, 18)
                    setSeg(obj.corners[1], left, topY, left + cl, topY)
                    setSeg(obj.corners[2], left, topY, left, topY + cl)
                    setSeg(obj.corners[3], left + w - cl, topY, left + w, topY)
                    setSeg(obj.corners[4], left + w, topY, left + w, topY + cl)
                    setSeg(obj.corners[5], left, topY + h - cl, left, topY + h)
                    setSeg(obj.corners[6], left, topY + h, left + cl, topY + h)
                    setSeg(obj.corners[7], left + w, topY + h - cl, left + w, topY + h)
                    setSeg(obj.corners[8], left + w - cl, topY + h, left + w, topY + h)
                else
                    for _, l in ipairs(obj.corners) do
                        l.Visible = false
                    end
                    obj.box.Size = Vector2.new(w, h)
                    obj.box.Position = Vector2.new(left, topY)
                    obj.box.Visible = true
                end
                local humanoid = model:FindFirstChildOfClass("Humanoid")
                if S.espHealth and humanoid then
                    local frac = math.clamp(humanoid.Health / math.max(humanoid.MaxHealth, 1), 0, 1)
                    obj.hpBg.Size = Vector2.new(3, h)
                    obj.hpBg.Position = Vector2.new(left - 5, topY)
                    obj.hpBg.Visible = true
                    obj.hpFill.Size = Vector2.new(3, h * frac)
                    obj.hpFill.Position = Vector2.new(left - 5, topY + h * (1 - frac))
                    obj.hpFill.Color = Color3.fromRGB(255 * (1 - frac), 255 * frac, 40)
                    obj.hpFill.Visible = true
                else
                    obj.hpBg.Visible = false
                    obj.hpFill.Visible = false
                end
                if S.espNames then
                    obj.name.Text = model.Name
                    obj.name.Position = Vector2.new(left + w / 2, topY - 16)
                    obj.name.Visible = true
                else
                    obj.name.Visible = false
                end
                if S.espDistance then
                    local dist = math.floor((head.Position - camera.CFrame.Position).Magnitude + 0.5)
                    obj.dist.Text = dist .. "m"
                    obj.dist.Position = Vector2.new(left + w / 2, topY + h + 2)
                    obj.dist.Visible = true
                else
                    obj.dist.Visible = false
                end
                if S.espSkeleton then
                    local joints = skeletonJoints(model)
                    for i, l in ipairs(obj.skel) do
                        local pr = joints[i]
                        if pr then
                            local a = camera:WorldToViewportPoint(pr[1].Position)
                            local b = camera:WorldToViewportPoint(pr[2].Position)
                            if a.Z > 0 and b.Z > 0 then
                                l.From = Vector2.new(a.X, a.Y)
                                l.To = Vector2.new(b.X, b.Y)
                                l.Visible = true
                            else
                                l.Visible = false
                            end
                        else
                            l.Visible = false
                        end
                    end
                else
                    for _, l in ipairs(obj.skel) do
                        l.Visible = false
                    end
                end
                if S.espSnaplines then
                    local vp = camera.ViewportSize
                    obj.snap.From = Vector2.new(vp.X / 2, vp.Y)
                    obj.snap.To = Vector2.new(left + w / 2, topY + h)
                    obj.snap.Visible = true
                else
                    obj.snap.Visible = false
                end
            else
                hideEspObj(obj)
            end
            if S.headDot then
                local hp = camera:WorldToViewportPoint(head.Position)
                if hp.Z > 0 then
                    obj.dot.Position = Vector2.new(hp.X, hp.Y)
                    obj.dot.Radius = math.clamp(1600 / hp.Z, 2, 8)
                    obj.dot.Visible = true
                else
                    obj.dot.Visible = false
                end
            else
                obj.dot.Visible = false
            end
        end
    end
end

local Window
local unload

local hookState = { mode = nil, old = nil }
local probeRemote = Instance.new("RemoteEvent")
local realFireServer = probeRemote.FireServer
probeRemote:Destroy()

local realUnreliableFire
pcall(function()
    local probeUnreliable = Instance.new("UnreliableRemoteEvent")
    realUnreliableFire = probeUnreliable.FireServer
    probeUnreliable:Destroy()
end)

local lastSilentName = ""
local lastSilentAt = 0
local lastSilentShown = 0

local function makeFireHandler()
    return newcc(function(self, ...)
        local method = getnamecallmethod()
        if method ~= "FireServer" then
            return hookState.old(self, ...)
        end
        local callArgs = table.pack(...)
        local deferred = false
        local modifiedArgs = nil
        if not S.unloaded then
            pcall(function()
                if (S.pitchDesync or S.lateralDesync) and self == findRemote("ReplayAimSync") then
                    local pitch, yaw = callArgs[1], callArgs[2]
                    if typeof(pitch) == "number" and typeof(yaw) == "number" then
                        local np, ny = pitch, yaw
                        if S.pitchDesync then
                            np = math.rad(S.pitchValue)
                        end
                        if S.lateralDesync then
                            ny = yaw + math.rad((math.random() * 2 - 1) * S.lateralAmount)
                        end
                        modifiedArgs = table.pack(np, ny)
                    end
                    return
                end
                if typeof(self) ~= "Instance" or not self:IsA("RemoteEvent") then
                    return
                end
                local shootRemote = findRemote("ShootReplicate")
                local reportRemote = findRemote("ReportHit")
                if self == shootRemote then
                    local payload = callArgs[1]
                    if type(payload) == "table" then
                        if S.silentAim then
                            local camera = Workspace.CurrentCamera
                            local part = getSilentTarget(camera)
                            if part then
                                local origin = typeof(payload.origin) == "Vector3" and payload.origin or camera.CFrame.Position
                                local normal = -camera.CFrame.LookVector
                                payload.hitPos = part.Position
                                payload.to = origin + (part.Position - origin).Unit * 1000
                                payload.hitInstance = part
                                payload.isCharacterHit = true
                                payload.hitNormal = normal
                                payload.segments = {
                                    {
                                        from = false,
                                        hitPos = part.Position,
                                        hitNormal = normal,
                                        hitInstance = part,
                                        isCharacterHit = true,
                                    },
                                }
                                payload.chainHits = nil
                                lastSilentName = part.Parent.Name
                                lastSilentAt = os.clock()
                            end
                        end
                        if S.wallbang and not payload.isCharacterHit
                            and typeof(payload.origin) == "Vector3" and typeof(payload.to) == "Vector3" then
                            local dirVec = payload.to - payload.origin
                            local range = dirVec.Magnitude
                            if range > 1 then
                                local wb = findThroughWallTarget(payload.origin, dirVec)
                                if wb and wb.dist <= range + 20 then
                                    local dir = dirVec.Unit
                                    local wallRes = nil
                                    pcall(function()
                                        local params = RaycastParams.new()
                                        params.FilterType = Enum.RaycastFilterType.Exclude
                                        params.FilterDescendantsInstances = LocalPlayer.Character and { LocalPlayer.Character } or {}
                                        params.IgnoreWater = true
                                        wallRes = Workspace:Raycast(payload.origin, dir * math.min(wb.dist + 1, range + 20), params)
                                    end)
                                    local wallInstance, wallPos, wallNormal
                                    if wallRes and wallRes.Distance < wb.dist then
                                        wallInstance = wallRes.Instance
                                        wallPos = wallRes.Position
                                        wallNormal = wallRes.Normal
                                    end
                                    local normal2 = -dir
                                    payload.hitPos = wb.pos
                                    payload.to = wb.pos
                                    payload.hitInstance = wb.part
                                    payload.isCharacterHit = true
                                    payload.hitNormal = normal2
                                    if wallInstance then
                                        payload.segments = {
                                            {
                                                from = false,
                                                hitPos = wallPos,
                                                hitNormal = wallNormal,
                                                hitInstance = wallInstance,
                                                isCharacterHit = false,
                                            },
                                            {
                                                from = wallPos,
                                                hitPos = wb.pos,
                                                hitNormal = normal2,
                                                hitInstance = wb.part,
                                                isCharacterHit = true,
                                            },
                                        }
                                    else
                                        payload.segments = {
                                            {
                                                from = false,
                                                hitPos = wb.pos,
                                                hitNormal = normal2,
                                                hitInstance = wb.part,
                                                isCharacterHit = true,
                                            },
                                        }
                                    end
                                    payload.chainHits = nil
                                end
                            end
                        end
                        if S.noSpread and not payload.isCharacterHit then
                            local camera = Workspace.CurrentCamera
                            if typeof(payload.origin) == "Vector3" and typeof(payload.hitPos) == "Vector3" then
                                local d = (payload.hitPos - payload.origin).Magnitude
                                local newHit = payload.origin + camera.CFrame.LookVector * d
                                payload.hitPos = newHit
                                payload.to = newHit
                            end
                        end
                    end
                end
                local parentName = self.Parent and self.Parent.Name
                if S.fakeLag and parentName == "Remotes" then
                    local target = self
                    task.delay(S.fakeLagMs / 1000, function()
                        if not S.unloaded then
                            realFireServer(target, unpack(callArgs, 1, callArgs.n))
                        end
                    end)
                    deferred = true
                    return
                end
                if S.pingDelay and self == findRemote("PingHeartbeat") then
                    local target = self
                    task.delay(S.pingDelayMs / 1000, function()
                        if not S.unloaded then
                            realFireServer(target, unpack(callArgs, 1, callArgs.n))
                        end
                    end)
                    deferred = true
                    return
                end
            end)
        end
        if deferred then
            return
        end
        if typeof(self) == "Instance" then
            if self:IsA("RemoteEvent") then
                return realFireServer(self, ...)
            elseif realUnreliableFire and self:IsA("UnreliableRemoteEvent") then
                if modifiedArgs then
                    return realUnreliableFire(self, unpack(modifiedArgs, 1, modifiedArgs.n))
                end
                return realUnreliableFire(self, ...)
            end
        end
        return hookState.old(self, ...)
    end)
end

local hooked = false
if type(hookmetamethod) == "function" then
    local ok, old = pcall(hookmetamethod, game, "__namecall", makeFireHandler())
    if ok and old then
        hookState.mode = "hookmetamethod"
        hookState.old = old
        hooked = true
    end
end
if not hooked and type(getrawmetatable) == "function" and type(setreadonly) == "function" then
    pcall(function()
        local mt = getrawmetatable(game)
        local old = mt.__namecall
        setreadonly(mt, false)
        mt.__namecall = makeFireHandler()
        setreadonly(mt, true)
        hookState.mode = "rawmetatable"
        hookState.old = old
        hooked = true
    end)
end

local directShotId = 0
local function fireDirect()
    local shootRemote = findRemote("ShootReplicate")
    local camera = Workspace.CurrentCamera
    if not shootRemote or not camera then
        return false
    end
    local char = LocalPlayer.Character
    local origin = camera.CFrame.Position
    local target = S.silentAim and getSilentTarget(camera) or nil
    local hitPos, hitInstance, isCharHit, hitNormal
    if target then
        hitPos = target.Position
        hitInstance = target
        isCharHit = true
        hitNormal = -camera.CFrame.LookVector
    else
        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude
        params.FilterDescendantsInstances = char and { char } or {}
        params.IgnoreWater = true
        local res = Workspace:Raycast(origin, camera.CFrame.LookVector * 1000, params)
        hitPos = res and res.Position or (origin + camera.CFrame.LookVector * 1000)
        hitInstance = res and res.Instance or nil
        isCharHit = false
        hitNormal = res and res.Normal or -camera.CFrame.LookVector
    end
    directShotId += 1
    local payload = {
        kind = "bullet",
        mode = "single",
        id = directShotId,
        origin = origin,
        firedAt = Workspace:GetServerTimeNow(),
        to = hitPos,
        hitInstance = hitInstance,
        hitPos = hitPos,
        hitNormal = hitNormal,
        isCharacterHit = isCharHit,
        ownerUserId = LocalPlayer.UserId,
        isADS = false,
        segments = {
            {
                from = false,
                hitPos = hitPos,
                hitNormal = hitNormal,
                hitInstance = hitInstance,
                isCharacterHit = isCharHit,
            },
        },
    }
    pcall(function()
        realFireServer(shootRemote, payload)
    end)
    return true
end

local function shootOnce()
    if not fireDirect() then
        fireClick()
    end
end

local function revolverEquipped()
    local char = LocalPlayer.Character
    return char and char:FindFirstChild("Revolver") ~= nil
end

local function knifeEquipped()
    local char = LocalPlayer.Character
    return char and char:FindFirstChild("Knife") ~= nil
end

local function longArmStep()
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local reportRemote = findRemote("ReportHit")
    if not (char and hrp and reportRemote) then
        return
    end
    local folder = Workspace:FindFirstChild("Characters")
    if not folder then
        return
    end
    local myPos = hrp.Position
    local best, bestDist = nil, math.huge
    for _, model in ipairs(folder:GetChildren()) do
        if isEnemyModel(model) then
            local torso = model:FindFirstChild("HumanoidRootPart")
                or model:FindFirstChild("Torso")
                or model:FindFirstChild("UpperTorso")
            local head = model:FindFirstChild("Head")
            if torso and head then
                local d = (torso.Position - myPos).Magnitude
                if d <= S.longArmRange and d < bestDist and (not S.wallCheck or isPartVisible(head)) then
                    best, bestDist = model, d
                end
            end
        end
    end
    if not best then
        return
    end
    local victimPlayer = Players:GetPlayerFromCharacter(best)
    local victimHrp = best:FindFirstChild("HumanoidRootPart")
    local dir = victimHrp and (victimHrp.Position - myPos).Unit or hrp.CFrame.LookVector
    local backstab
    if S.longArmBackstab then
        backstab = true
    elseif victimHrp then
        backstab = victimHrp.CFrame.LookVector:Dot(-dir) <= -0.35
    else
        backstab = false
    end
    pcall(function()
        realFireServer(reportRemote, {
            kind = "melee",
            targetUserId = victimPlayer and victimPlayer.UserId or 0,
            targetModel = best,
            direction = dir,
            at = Workspace:GetServerTimeNow(),
            backstab = backstab == true,
        })
    end)
end

local hitConn
local function connectHitListener()
    if hitConn then
        hitConn:Disconnect()
        hitConn = nil
    end
    local shootRemote = findRemote("ShootReplicate")
    if shootRemote then
        hitConn = shootRemote.OnClientEvent:Connect(function(info)
            if S.unloaded or not S.hitmarker then
                return
            end
            if type(info) == "table" and info.targetUserId == LocalPlayer.UserId and info.isCharacterHit then
                showHitmarker()
                if S.hitSound then
                    hitSound.Volume = S.hitVolume
                    hitSound:Play()
                end
            end
        end)
    end
end
connectHitListener()

local nextTrigger = 0
local nextClick = 0
local nextLongArm = 0
local lastJitter = 0
local simAccum = 0
local hitRetry = 0

local bypassFrozen = false
local bypassLastCf = nil
local bypassUnfrozenAt = 0
local noclipChar = nil
local noclipParts = nil

local renderConn = RunService.RenderStepped:Connect(function(dt)
    if S.unloaded then
        return
    end
    local camera = Workspace.CurrentCamera
    if not camera then
        return
    end
    if not hitConn then
        hitRetry += dt
        if hitRetry >= 3 then
            hitRetry = 0
            connectHitListener()
        end
    end
    if fovCircle then
        fovCircle.Visible = S.showFov and S.silentAim and not S.unloaded
        if fovCircle.Visible then
            fovCircle.Position = camera.ViewportSize / 2
            fovCircle.Radius = S.silentFov
        end
    end
    if S.silentDebug and lastSilentAt > 0 and os.clock() - lastSilentAt <= 0.25 and os.clock() - lastSilentShown >= 1 then
        lastSilentShown = os.clock()
        lastSilentAt = 0
        if Window then
            pcall(function()
                Window:Notify({
                    title = "Silent Aim",
                    content = "Redirect -> " .. lastSilentName,
                    duration = 1,
                })
            end)
        end
    end
    local hrp = getRootPart()
    if hrp then
        if S.aaMode == "Spin" then
            hrp.CFrame = hrp.CFrame * CFrame.Angles(0, math.rad(S.spinSpeed) * dt, 0)
        elseif S.aaMode == "Jitter" then
            if tick() - lastJitter >= S.jitterInterval then
                lastJitter = tick()
                local dir = math.random() < 0.5 and -1 or 1
                hrp.CFrame = hrp.CFrame * CFrame.Angles(0, dir * math.rad(math.random(90, 270)), 0)
            end
        end
    end
    local char = LocalPlayer.Character
    local humanoid = char and char:FindFirstChildOfClass("Humanoid")
    if S.speedEnabled and humanoid then
        humanoid.WalkSpeed = S.speedValue
    end
    if S.noclip and char then
        if char ~= noclipChar then
            noclipChar = char
            noclipParts = {}
            for _, p in ipairs(char:GetDescendants()) do
                if p:IsA("BasePart") then
                    noclipParts[#noclipParts + 1] = p
                end
            end
        end
        for _, p in ipairs(noclipParts) do
            if p.Parent and p.CanCollide then
                p.CanCollide = false
            end
        end
    end
    if S.fly and hrp then
        local look = camera.CFrame.LookVector
        local right = camera.CFrame.RightVector
        local move = Vector3.zero
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then move += look end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then move -= look end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then move += right end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then move -= right end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then move += Vector3.yAxis end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then move -= Vector3.yAxis end
        if move.Magnitude > 0 then
            hrp.AssemblyLinearVelocity = move.Unit * S.flySpeed
        else
            hrp.AssemblyLinearVelocity = Vector3.zero
        end
    end
    if S.bhop and humanoid and humanoid:GetState() == Enum.HumanoidStateType.Landed then
        humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
    end
    if S.roundBypass then
        local bchar = LocalPlayer.Character
        local bh = bchar and bchar:FindFirstChildOfClass("Humanoid")
        local bhrp = bchar and bchar:FindFirstChild("HumanoidRootPart")
        if bchar and bh and bhrp and bh.Health > 0 then
            local frozen = bhrp.Anchored or bh.WalkSpeed == 0
            if frozen and not bypassFrozen then
                bypassFrozen = true
                bypassLastCf = bhrp.CFrame
            elseif not frozen and bypassFrozen then
                bypassFrozen = false
                bypassUnfrozenAt = os.clock()
            end
            if frozen then
                if bhrp.Anchored then
                    bhrp.Anchored = false
                end
                if bh.WalkSpeed == 0 then
                    bh.WalkSpeed = 16
                    bh.JumpPower = 50
                end
            end
            if (bypassFrozen or os.clock() - bypassUnfrozenAt <= 3) and bypassLastCf then
                local cur = bhrp.CFrame
                if (cur.Position - bypassLastCf.Position).Magnitude > 12 then
                    bhrp.CFrame = bypassLastCf
                    bhrp.AssemblyLinearVelocity = Vector3.zero
                else
                    bypassLastCf = cur
                end
            end
        end
    else
        bypassFrozen = false
        bypassLastCf = nil
    end
    if S.triggerBot and revolverEquipped() and tick() >= nextTrigger and crosshairOverEnemy(camera) then
        nextTrigger = tick() + S.triggerDelay
        shootOnce()
    end
    if S.autoFire and revolverEquipped() and tick() >= nextClick and getSilentTarget(camera) then
        nextClick = tick() + 1 / 50
        fireDirect()
    end
    if S.longArm and knifeEquipped() and tick() >= nextLongArm then
        nextLongArm = tick() + 1 / math.max(S.longArmRate, 0.5)
        longArmStep()
    end
    if S.simRadius then
        simAccum += dt
        if simAccum >= 0.25 then
            simAccum = 0
            pcall(function()
                if type(setsimulationradius) == "function" then
                    setsimulationradius(1e9, 1e9)
                end
                local part = getRootPart()
                if part and type(sethiddenproperty) == "function" then
                    sethiddenproperty(part, "SimulationRadius", 1e9)
                end
            end)
        end
    end
    updateEsp(camera)
end)

local infJumpConn = UserInputService.JumpRequest:Connect(function()
    if S.unloaded or not S.infJump then
        return
    end
    local char = LocalPlayer.Character
    local humanoid = char and char:FindFirstChildOfClass("Humanoid")
    if humanoid then
        pcall(function()
            humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
        end)
    end
end)

local function restoreNoclip()
    local char = LocalPlayer.Character
    if not char then
        return
    end
    pcall(function()
        for _, p in ipairs(char:GetDescendants()) do
            if p:IsA("BasePart") then
                p.CanCollide = true
            end
        end
    end)
end

RunService:BindToRenderStep("XZ_ThirdPerson", Enum.RenderPriority.Camera.Value + 1, function()
    if S.unloaded or not S.thirdPerson then
        return
    end
    local camera = Workspace.CurrentCamera
    if not camera then
        return
    end
    local char = LocalPlayer.Character
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = { char }
    params.IgnoreWater = true
    local back = -camera.CFrame.LookVector * S.tpDistance
    local res = Workspace:Raycast(camera.CFrame.Position, back, params)
    local dist = S.tpDistance
    if res then
        dist = math.max((res.Position - camera.CFrame.Position).Magnitude - 0.3, 0.5)
    end
    camera.CFrame = camera.CFrame * CFrame.new(0, 0, dist)
    if char then
        for _, p in ipairs(char:GetDescendants()) do
            if p:IsA("BasePart") then
                p.LocalTransparencyModifier = 0
            end
        end
    end
end)

local fovApplied = nil
RunService:BindToRenderStep("XZ_Fov", Enum.RenderPriority.Camera.Value + 1, function(dt)
    if S.unloaded or not S.fovChange then
        return
    end
    local camera = Workspace.CurrentCamera
    if not camera then
        return
    end
    if not fovApplied then
        fovApplied = camera.FieldOfView
    end
    local gameDelta = math.clamp(camera.FieldOfView - fovApplied, -45, 45)
    local target = math.clamp(S.fovValue + gameDelta, 10, 120)
    camera.FieldOfView = camera.FieldOfView + (target - camera.FieldOfView) * math.clamp(dt * 10, 0, 1)
    fovApplied = camera.FieldOfView
end)

task.spawn(function()
    while not S.unloaded do
        if S.fakeCrouch then
            local r = findRemote("ParkourState")
            if r then
                pcall(function()
                    r:FireServer("Crouching")
                end)
            end
        end
        task.wait(0.8)
    end
end)

task.spawn(function()
    while not S.unloaded do
        if S.killcamPoison then
            local r = findRemote("ReplayAimSync")
            if r then
                pcall(function()
                    r:FireServer((math.random() - 0.5) * math.pi, (math.random() * 2 - 1) * math.pi)
                end)
            end
        end
        task.wait(0.05)
    end
end)

task.spawn(function()
    while not S.unloaded do
        if S.spectateHijack then
            local r = findRemote("SpectateCam")
            if r then
                pcall(function()
                    local base = getRootPart()
                    local pos = base and base.Position or Vector3.zero
                    local ang = os.clock() * 2
                    local fake = CFrame.new(pos + Vector3.new(math.cos(ang) * 40, 60, math.sin(ang) * 40)) * CFrame.Angles(0, -ang, 0)
                    r:FireServer(fake, fake, os.clock())
                end)
            end
        end
        task.wait(0.05)
    end
end)

Window = Rayfield:CreateWindow({
    name = "Nuclide XZ",
    subtitle = "Combat Suite",
    theme = "ember",
    configuration = {
        autoSave = true,
        autoLoad = true,
        fileName = "NuclideXZ",
    },
})

local CombatTab = Window:CreateTab({ name = "Combat" })
local VisualsTab = Window:CreateTab({ name = "Visuals" })
local MovementTab = Window:CreateTab({ name = "Movement" })
local DesyncTab = Window:CreateTab({ name = "Desync" })
local AntiAimTab = Window:CreateTab({ name = "Anti Aim" })
local MiscTab = Window:CreateTab({ name = "Misc" })

CombatTab:CreateSection({ name = "Filters" })

CombatTab:CreateToggle({
    name = "Team Check",
    value = S.teamCheck,
    flag = "TeamCheck",
    callback = function(v)
        S.teamCheck = v
    end,
})

CombatTab:CreateToggle({
    name = "Dead Check",
    value = S.deadCheck,
    flag = "DeadCheck",
    callback = function(v)
        S.deadCheck = v
    end,
})

CombatTab:CreateSection({ name = "Silent Aim" })

CombatTab:CreateToggle({
    name = "Silent Aim",
    value = S.silentAim,
    flag = "SilentAim",
    callback = function(v)
        S.silentAim = v
    end,
})

CombatTab:CreateDropdown({
    name = "Hit Part",
    options = { "Head", "Torso" },
    value = S.silentHitPart,
    flag = "SilentHitPart",
    callback = function(sel)
        S.silentHitPart = sel
    end,
})

CombatTab:CreateSlider({
    name = "Target FOV",
    range = { 30, 400 },
    increment = 5,
    value = S.silentFov,
    suffix = "px",
    flag = "SilentFov",
    callback = function(v)
        S.silentFov = v
    end,
})

CombatTab:CreateToggle({
    name = "Show FOV Circle",
    value = S.showFov,
    flag = "ShowFov",
    callback = function(v)
        S.showFov = v
    end,
})

CombatTab:CreateToggle({
    name = "Silent Aim Debug Notify",
    value = false,
    flag = "SilentDebug",
    callback = function(v)
        S.silentDebug = v
    end,
})

CombatTab:CreateToggle({
    name = "Wall Check",
    value = S.wallCheck,
    flag = "WallCheck",
    callback = function(v)
        S.wallCheck = v
    end,
})

CombatTab:CreateSection({ name = "Weapon" })

CombatTab:CreateToggle({
    name = "No Spread / No Recoil",
    value = S.noSpread,
    flag = "NoSpread",
    callback = function(v)
        S.noSpread = v
    end,
})

CombatTab:CreateToggle({
    name = "Trigger Bot",
    value = S.triggerBot,
    flag = "TriggerBot",
    callback = function(v)
        S.triggerBot = v
    end,
})

CombatTab:CreateSlider({
    name = "Trigger Delay",
    range = { 0, 0.3 },
    increment = 0.01,
    value = S.triggerDelay,
    suffix = "s",
    flag = "TriggerDelay",
    callback = function(v)
        S.triggerDelay = v
    end,
})

CombatTab:CreateToggle({
    name = "Auto Fire (with Silent Aim)",
    value = S.autoFire,
    flag = "AutoFire",
    callback = function(v)
        S.autoFire = v
    end,
})

CombatTab:CreateToggle({
    name = "Silent Aim 360°",
    value = S.silent360,
    flag = "Silent360",
    callback = function(v)
        S.silent360 = v
    end,
})

CombatTab:CreateToggle({
    name = "Smart Priority",
    value = S.smartPriority,
    flag = "SmartPriority",
    callback = function(v)
        S.smartPriority = v
    end,
})

CombatTab:CreateSection({ name = "Knife" })

CombatTab:CreateToggle({
    name = "Long Arm (melee range)",
    value = S.longArm,
    flag = "LongArm",
    callback = function(v)
        S.longArm = v
    end,
})

CombatTab:CreateSlider({
    name = "Long Arm Range",
    range = { 6, 30 },
    increment = 1,
    value = S.longArmRange,
    suffix = " studs",
    flag = "LongArmRange",
    callback = function(v)
        S.longArmRange = v
    end,
})

CombatTab:CreateSlider({
    name = "Long Arm Rate",
    range = { 0.5, 5 },
    increment = 0.5,
    value = S.longArmRate,
    suffix = " hits/s",
    flag = "LongArmRate",
    callback = function(v)
        S.longArmRate = v
    end,
})

CombatTab:CreateToggle({
    name = "Force Backstab (250 dmg)",
    value = S.longArmBackstab,
    flag = "LongArmBackstab",
    callback = function(v)
        S.longArmBackstab = v
    end,
})

CombatTab:CreateSection({ name = "Wallbang" })

CombatTab:CreateToggle({
    name = "Wallbang (shoot through walls)",
    value = S.wallbang,
    flag = "Wallbang",
    callback = function(v)
        S.wallbang = v
    end,
})

CombatTab:CreateSection({ name = "Feedback" })

CombatTab:CreateToggle({
    name = "Hit Marker",
    value = S.hitmarker,
    flag = "Hitmarker",
    callback = function(v)
        S.hitmarker = v
    end,
})

CombatTab:CreateToggle({
    name = "Hit Sound",
    value = S.hitSound,
    flag = "HitSound",
    callback = function(v)
        S.hitSound = v
    end,
})

CombatTab:CreateSlider({
    name = "Hit Volume",
    range = { 0, 3 },
    increment = 0.1,
    value = S.hitVolume,
    suffix = "x",
    flag = "HitVolume",
    callback = function(v)
        S.hitVolume = v
    end,
})

VisualsTab:CreateSection({ name = "ESP" })

VisualsTab:CreateToggle({
    name = "Player ESP",
    value = S.esp,
    flag = "PlayerEsp",
    callback = function(v)
        S.esp = v
    end,
})

VisualsTab:CreateToggle({
    name = "Corner Boxes",
    value = S.espCorner,
    flag = "EspCorner",
    callback = function(v)
        S.espCorner = v
    end,
})

VisualsTab:CreateToggle({
    name = "Box Fill",
    value = S.espFill,
    flag = "EspFill",
    callback = function(v)
        S.espFill = v
    end,
})

VisualsTab:CreateToggle({
    name = "Skeleton",
    value = S.espSkeleton,
    flag = "EspSkeleton",
    callback = function(v)
        S.espSkeleton = v
    end,
})

VisualsTab:CreateToggle({
    name = "Snaplines",
    value = S.espSnaplines,
    flag = "EspSnaplines",
    callback = function(v)
        S.espSnaplines = v
    end,
})

VisualsTab:CreateToggle({
    name = "ESP Names",
    value = S.espNames,
    flag = "EspNames",
    callback = function(v)
        S.espNames = v
    end,
})

VisualsTab:CreateToggle({
    name = "ESP Health",
    value = S.espHealth,
    flag = "EspHealth",
    callback = function(v)
        S.espHealth = v
    end,
})

VisualsTab:CreateToggle({
    name = "ESP Distance",
    value = S.espDistance,
    flag = "EspDistance",
    callback = function(v)
        S.espDistance = v
    end,
})

VisualsTab:CreateColorPicker({
    name = "Enemy Color",
    color = S.enemyColor,
    flag = "EnemyColor",
    callback = function(color)
        S.enemyColor = color
    end,
})

VisualsTab:CreateToggle({
    name = "Chams",
    value = S.chams,
    flag = "Chams",
    callback = function(v)
        S.chams = v
        if not v then
            destroyAllChams()
        end
    end,
})

VisualsTab:CreateColorPicker({
    name = "Chams Color",
    color = S.chamsColor,
    flag = "ChamsColor",
    callback = function(color)
        S.chamsColor = color
    end,
})

VisualsTab:CreateToggle({
    name = "Head Dot",
    value = S.headDot,
    flag = "HeadDot",
    callback = function(v)
        S.headDot = v
    end,
})

VisualsTab:CreateSection({ name = "Camera" })

VisualsTab:CreateToggle({
    name = "FOV Changer",
    value = S.fovChange,
    flag = "FovChange",
    callback = function(v)
        S.fovChange = v
        if not v then
            fovApplied = nil
            local camera = Workspace.CurrentCamera
            if camera then
                camera.FieldOfView = 70
            end
        end
    end,
})

VisualsTab:CreateSlider({
    name = "Field Of View",
    range = { 60, 120 },
    increment = 1,
    value = S.fovValue,
    suffix = "°",
    flag = "FovValue",
    callback = function(v)
        S.fovValue = v
    end,
})

VisualsTab:CreateSection({ name = "Third Person" })

local thirdPersonToggle = VisualsTab:CreateToggle({
    name = "Third Person",
    value = false,
    flag = "ThirdPerson",
    callback = function(v)
        S.thirdPerson = v
    end,
})

VisualsTab:CreateSlider({
    name = "Third Person Distance",
    range = { 2, 20 },
    increment = 0.5,
    value = S.tpDistance,
    suffix = "st",
    flag = "TpDistance",
    callback = function(v)
        S.tpDistance = v
    end,
})

VisualsTab:CreateKeybind({
    name = "Third Person Key",
    value = Enum.KeyCode.T,
    flag = "TpKey",
    callback = function()
        S.thirdPerson = not S.thirdPerson
        thirdPersonToggle:Set(S.thirdPerson)
    end,
})

MovementTab:CreateSection({ name = "Speed" })

MovementTab:CreateToggle({
    name = "Speed Changer",
    value = S.speedEnabled,
    flag = "SpeedEnabled",
    callback = function(v)
        S.speedEnabled = v
        if not v then
            local char = LocalPlayer.Character
            local humanoid = char and char:FindFirstChildOfClass("Humanoid")
            if humanoid then
                humanoid.WalkSpeed = 16
            end
        end
    end,
})

MovementTab:CreateSlider({
    name = "WalkSpeed",
    range = { 16, 150 },
    increment = 1,
    value = S.speedValue,
    flag = "SpeedValue",
    callback = function(v)
        S.speedValue = v
    end,
})

MovementTab:CreateSection({ name = "Air Control" })

MovementTab:CreateToggle({
    name = "Round Start Bypass",
    value = S.roundBypass,
    flag = "RoundBypass",
    callback = function(v)
        S.roundBypass = v
    end,
})

MovementTab:CreateToggle({
    name = "Bunny Hop",
    value = S.bhop,
    flag = "Bhop",
    callback = function(v)
        S.bhop = v
    end,
})

MovementTab:CreateToggle({
    name = "Infinite Jump",
    value = S.infJump,
    flag = "InfJump",
    callback = function(v)
        S.infJump = v
    end,
})

MovementTab:CreateSection({ name = "Fly / Clip" })

local flyToggle = MovementTab:CreateToggle({
    name = "Fly  [WASD + Space/Ctrl]",
    value = S.fly,
    flag = "Fly",
    callback = function(v)
        S.fly = v
        if not v then
            local hrp = getRootPart()
            if hrp then
                hrp.AssemblyLinearVelocity = Vector3.zero
            end
        end
    end,
})

MovementTab:CreateSlider({
    name = "Fly Speed",
    range = { 20, 200 },
    increment = 5,
    value = S.flySpeed,
    suffix = " st/s",
    flag = "FlySpeed",
    callback = function(v)
        S.flySpeed = v
    end,
})

MovementTab:CreateKeybind({
    name = "Fly Key",
    value = Enum.KeyCode.F,
    flag = "FlyKey",
    callback = function()
        S.fly = not S.fly
        flyToggle:Set(S.fly, true)
        if not S.fly then
            local hrp = getRootPart()
            if hrp then
                hrp.AssemblyLinearVelocity = Vector3.zero
            end
        end
    end,
})

local noclipToggle = MovementTab:CreateToggle({
    name = "Noclip",
    value = S.noclip,
    flag = "Noclip",
    callback = function(v)
        S.noclip = v
        if not v then
            restoreNoclip()
        end
    end,
})

MovementTab:CreateKeybind({
    name = "Noclip Key",
    value = Enum.KeyCode.N,
    flag = "NoclipKey",
    callback = function()
        S.noclip = not S.noclip
        noclipToggle:Set(S.noclip, true)
        if not S.noclip then
            restoreNoclip()
        end
    end,
})

DesyncTab:CreateSection({ name = "Network" })

DesyncTab:CreateToggle({
    name = "Fake Lag",
    value = S.fakeLag,
    flag = "FakeLag",
    callback = function(v)
        S.fakeLag = v
    end,
})

DesyncTab:CreateSlider({
    name = "Fake Lag Delay",
    range = { 10, 1000 },
    increment = 10,
    value = S.fakeLagMs,
    suffix = "ms",
    flag = "FakeLagMs",
    callback = function(v)
        S.fakeLagMs = v
    end,
})

DesyncTab:CreateToggle({
    name = "Sim Radius Desync",
    value = S.simRadius,
    flag = "SimRadius",
    callback = function(v)
        S.simRadius = v
    end,
})

DesyncTab:CreateToggle({
    name = "Ping Delay",
    value = S.pingDelay,
    flag = "PingDelay",
    callback = function(v)
        S.pingDelay = v
    end,
})

DesyncTab:CreateSlider({
    name = "Ping Delay Amount",
    range = { 10, 1000 },
    increment = 10,
    value = S.pingDelayMs,
    suffix = "ms",
    flag = "PingDelayMs",
    callback = function(v)
        S.pingDelayMs = v
    end,
})

DesyncTab:CreateSection({ name = "Replay" })

DesyncTab:CreateToggle({
    name = "Killcam Poison",
    value = S.killcamPoison,
    flag = "KillcamPoison",
    callback = function(v)
        S.killcamPoison = v
    end,
})

DesyncTab:CreateToggle({
    name = "Spectate Cam Hijack",
    value = S.spectateHijack,
    flag = "SpectateHijack",
    callback = function(v)
        S.spectateHijack = v
    end,
})

AntiAimTab:CreateSection({ name = "Orientation" })

AntiAimTab:CreateDropdown({
    name = "Mode",
    options = { "Off", "Spin", "Jitter" },
    value = S.aaMode,
    flag = "AaMode",
    callback = function(sel)
        S.aaMode = sel
    end,
})

AntiAimTab:CreateSlider({
    name = "Spin Speed",
    range = { 30, 720 },
    increment = 10,
    value = S.spinSpeed,
    suffix = "°/s",
    flag = "SpinSpeed",
    callback = function(v)
        S.spinSpeed = v
    end,
})

AntiAimTab:CreateSlider({
    name = "Jitter Interval",
    range = { 0.05, 0.5 },
    increment = 0.05,
    value = S.jitterInterval,
    suffix = "s",
    flag = "JitterInterval",
    callback = function(v)
        S.jitterInterval = v
    end,
})

AntiAimTab:CreateSection({ name = "State" })

AntiAimTab:CreateToggle({
    name = "Fake Crouch",
    value = S.fakeCrouch,
    flag = "FakeCrouch",
    callback = function(v)
        S.fakeCrouch = v
    end,
})

AntiAimTab:CreateSection({ name = "Desync (Replay Spoof)" })

AntiAimTab:CreateToggle({
    name = "Pitch Desync",
    value = S.pitchDesync,
    flag = "PitchDesync",
    callback = function(v)
        S.pitchDesync = v
    end,
})

AntiAimTab:CreateSlider({
    name = "Fake Pitch",
    range = { -89, 89 },
    increment = 1,
    value = S.pitchValue,
    suffix = "°",
    flag = "PitchValue",
    callback = function(v)
        S.pitchValue = v
    end,
})

AntiAimTab:CreateToggle({
    name = "Lateral Desync",
    value = S.lateralDesync,
    flag = "LateralDesync",
    callback = function(v)
        S.lateralDesync = v
    end,
})

AntiAimTab:CreateSlider({
    name = "Lateral Angle",
    range = { 5, 180 },
    increment = 5,
    value = S.lateralAmount,
    suffix = "°",
    flag = "LateralAmount",
    callback = function(v)
        S.lateralAmount = v
    end,
})

MiscTab:CreateSection({ name = "Control" })

MiscTab:CreateKeybind({
    name = "Panic Unload Key",
    value = Enum.KeyCode.K,
    flag = "PanicKey",
    callback = function()
        unload()
    end,
})

MiscTab:CreateButton({
    name = "Unload",
    callback = function()
        unload()
    end,
})

MiscTab:CreateText({
    name = "Nuclide XZ",
    text = "Combat: SA-01..07, SA-12 | Visuals: ESP-01/03/04/08 | Movement: MV-01..05 | Desync: DS-01..06 | Anti Aim: AA-01..06",
})

if hooked then
    Window:Notify({
        title = "Nuclide XZ",
        content = "Hook installed via " .. tostring(hookState.mode) .. ".",
        duration = 5,
    })
else
    Window:Notify({
        title = "Hook failed",
        content = "__namecall hook could not be installed, combat features are offline.",
        duration = 8,
    })
end

function unload()
    if S.unloaded then
        return
    end
    S.unloaded = true
    for k, v in pairs(S) do
        if type(v) == "boolean" and k ~= "unloaded" then
            S[k] = false
        end
    end
    S.aaMode = "Off"
    task.defer(function()
        if infJumpConn then
            pcall(function()
                infJumpConn:Disconnect()
            end)
        end
        pcall(restoreNoclip)
        pcall(function()
            local char = LocalPlayer.Character
            local humanoid = char and char:FindFirstChildOfClass("Humanoid")
            if humanoid then
                humanoid.WalkSpeed = 16
            end
        end)
        pcall(function()
            local hrp = getRootPart()
            if hrp then
                hrp.AssemblyLinearVelocity = Vector3.zero
            end
        end)
        if renderConn then
            pcall(function()
                renderConn:Disconnect()
            end)
        end
        if hitConn then
            pcall(function()
                hitConn:Disconnect()
            end)
        end
        pcall(function()
            RunService:UnbindFromRenderStep("XZ_ThirdPerson")
        end)
        pcall(function()
            RunService:UnbindFromRenderStep("XZ_Fov")
        end)
        fovApplied = nil
        if fovCircle then
            pcall(function()
                fovCircle:Remove()
            end)
        end
        for _, line in ipairs(hitLines) do
            pcall(function()
                line:Remove()
            end)
        end
        for model in pairs(espObjects) do
            destroyEspObj(model)
        end
        pcall(destroyAllChams)
        pcall(function()
            hitSound:Destroy()
        end)
        pcall(function()
            Workspace.CurrentCamera.FieldOfView = 70
        end)
        pcall(function()
            Window:Unload()
        end)
    end)
end
