--// CRYEFUL SCRIPT v17 - ULTRA EDITION
--// Beautiful Menu + Auto Pred + X/Y Adjustments + Full Customization
--// Da Hood / Da Strike / Copies Support

getgenv().CONFIG = {
    -- KEYBINDS (Easy Customization)
    Keys = {
        ToggleMenu = "M",
        Resolver = "C",
        Camlock = "F",
        SilentAim = "V",
        AutoAir = "B",
        TriggerBot = "T",
        LegitSmooth = "L",
        BlatantMode = "K",
        SilentLock = "Q",
        AntiCurve = "U",
        AimAssist = "P",
        SilentFOVUp = "RightBracket",
        SilentFOVDown = "LeftBracket",
        AimAssistFOVUp = "Equals",
        AimAssistFOVDown = "Minus",
        ToggleBox = "Y",
    },
    
    -- FOV SETTINGS
    SilentAimFOV = 235,
    AimAssistFOV = 45,
    FOVChangeAmount = 10,
    
    -- SMOOTHING
    Smoothing = 0.070,
    LegitSmoothing = 0.018,
    BlatantSmoothing = 1.0,
    AimAssistSmooth = 0.145,
    
    -- PREDICTION
    BasePred = 0.1483,
    PredPingFactor = 0.00029,
    PredDistFactor = 0.000052,
    PredVelFactor = 0.0142,
    MaxPred = 0.1483,
    MinPred = 0.1483,
    PredX = 0.5,
    PredY = 0.5,
    AutoPredEnabled = true,
    
    -- AIR PREDICTION
    JumpOffsetBase = -0.4,
    FallOffsetBase = -0.25,
    AirExtraBoostBase = 0.048,
    AirVelFactor = 0.00135,
    VelSmooth = 0.78,
    
    -- VISUALS
    ShowFOV = true,
    FOVColor = Color3.fromRGB(255, 0, 255),
    ShakeEnabled = true,
    ShakeIntensity = 0.75,
    ShowTriggerBox = true,
    
    -- TRIGGER BOT
    TriggerFireRate = 0.032,
    TriggerDelayMin = 0.004,
    TriggerDelayMax = 0.012,
    RandomizeTriggerDelay = true,
    TriggerTargetOnly = true,
    TriggerVisibilityCheck = true,
    
    -- AUTO AIR
    airTriggerDelay = 0.15,
    airFireRate = 0.015,
    
    -- STATE
    resolver = false,
    silentAim = false,
    camlock = false,
    autoAirFire = false,
    triggerBot = false,
    legitSmooth = false,
    blatantMode = false,
    silentLockEnabled = false,
    antiCurve = true,
    aimAssist = false,
}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local Stats = game:GetService("Stats")
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer
local WS = game:GetService("Workspace")
local RS = game:GetService("ReplicatedStorage")

local MainRemote = nil
local ShootArg = nil
local detectedGame = "Unknown"
local lockedTarget = nil
local silentLockedTarget = nil
local lastPos, lastTime, lastVel, velHistory = {}, {}, {}, {}
local airStart = {}
local hitCount = 0
local currentPing = 50
local lastAutoFire = 0
local lastTriggerFire = 0
local forceTarget = nil

-- DETECT GAME
local function detectRemote()
    if RS:FindFirstChild("MAINEVENT") then
        MainRemote = RS.MAINEVENT; ShootArg = "MOUSE"; detectedGame = "Da Strike"
    elseif RS:FindFirstChild("MainEvent") then
        MainRemote = RS.MainEvent; ShootArg = "UpdateMousePos"; detectedGame = "Da Hood"
    else
        for _, remote in ipairs(RS:GetChildren()) do
            if remote:IsA("RemoteEvent") and (remote.Name:lower():find("main") or remote.Name:lower():find("shoot")) then
                MainRemote = remote; ShootArg = "UpdateMousePos"; detectedGame = "Copy (" .. remote.Name .. ")"; break
            end
        end
    end
end

detectRemote()
if not MainRemote then warn("🚫 Unsupported game!"); return end
print("✅ Detected: " .. detectedGame .. " | CRYEFUL SCRIPT v17 LOADED!")

-- GET PING
spawn(function()
    while wait(0.3) do
        local pingItem = Stats.Network.ServerStatsItem["Data Ping"]
        currentPing = pingItem and pingItem:GetValue() or 50
    end
end)

-- VISIBILITY CHECK
local function isVisible(target)
    if not target or not target.Character then return false end
    local head = target.Character:FindFirstChild("Head")
    if not head then return false end
    local origin = Camera.CFrame.Position
    local direction = (head.Position - origin)
    local raycastParams = RaycastParams.new()
    raycastParams.FilterDescendantsInstances = {LocalPlayer.Character}
    raycastParams.FilterType = Enum.RaycastFilterType.Exclude
    local result = workspace:Raycast(origin, direction, raycastParams)
    return not result or result.Instance:IsDescendantOf(target.Character)
end

-- FIND CLOSEST IN FOV
local function findClosestInFOV()
    local closest, minDist = nil, getgenv().CONFIG.AimAssistFOV
    local center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character then
            local hrp = plr.Character:FindFirstChild("HumanoidRootPart")
            local hum = plr.Character:FindFirstChild("Humanoid")
            if hrp and hum and hum.Health > 0 then
                local screen, onScreen = Camera:WorldToViewportPoint(hrp.Position)
                if onScreen then
                    local dist2d = (Vector2.new(screen.X, screen.Y) - center).Magnitude
                    if dist2d < minDist then minDist = dist2d; closest = plr end
                end
            end
        end
    end
    return closest
end

-- FIND CLOSEST
local function findClosest()
    local closest, minDist = nil, getgenv().CONFIG.SilentAimFOV
    local center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character then
            local hrp = plr.Character:FindFirstChild("HumanoidRootPart")
            local hum = plr.Character:FindFirstChild("Humanoid")
            if hrp and hum and hum.Health > 0 then
                local screen, onScreen = Camera:WorldToViewportPoint(hrp.Position)
                if onScreen then
                    local dist2d = (Vector2.new(screen.X, screen.Y) - center).Magnitude
                    if dist2d < minDist then minDist = dist2d; closest = plr end
                end
            end
        end
    end
    return closest
end

-- GET PREDICTION WITH AUTO PRED
local function getPred(target)
    local pingMs = currentPing
    local base = getgenv().CONFIG.BasePred + (pingMs * getgenv().CONFIG.PredPingFactor)
    
    if getgenv().CONFIG.AutoPredEnabled and target and target.Character and LocalPlayer.Character then
        local targetRoot = target.Character:FindFirstChild("HumanoidRootPart")
        local myRoot = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if targetRoot and myRoot then
            local dist = (targetRoot.Position - myRoot.Position).Magnitude
            base = base + dist * getgenv().CONFIG.PredDistFactor
            local targetVel = targetRoot.AssemblyLinearVelocity
            local myVel = myRoot.AssemblyLinearVelocity
            local relVel = (targetVel - myVel).Magnitude
            base = base + relVel * getgenv().CONFIG.PredVelFactor
        end
    end
    
    return math.clamp(base, getgenv().CONFIG.MinPred, getgenv().CONFIG.MaxPred)
end

-- GET AIM POSITION
local function getAimPos(plr)
    if not plr or not plr.Character then return Vector3.new() end
    local root = plr.Character:FindFirstChild("HumanoidRootPart")
    if not root then return Vector3.new() end
    
    local partName = getgenv().CONFIG.blatantMode and "UpperTorso" or "Head"
    local aimPart = plr.Character:FindFirstChild(partName) or root
    
    local pos = aimPart.Position
    local vel = root.AssemblyLinearVelocity
    local t = getPred(plr)
    local g = WS.Gravity
    local offsetY = 0
    
    local hum = plr.Character:FindFirstChild("Humanoid")
    local isAir = hum and (hum:GetState() == Enum.HumanoidStateType.Jumping or hum:GetState() == Enum.HumanoidStateType.Freefall)
    
    if isAir then
        local baseOffset = (hum:GetState() == Enum.HumanoidStateType.Freefall) and getgenv().CONFIG.FallOffsetBase or getgenv().CONFIG.JumpOffsetBase
        local velEffect = math.abs(vel.Y) * getgenv().CONFIG.AirVelFactor
        offsetY = baseOffset + velEffect + (vel.Y > 0 and getgenv().CONFIG.AirExtraBoostBase or 0)
    end
    
    pos = pos + Vector3.new(0, offsetY, 0)
    
    local predXZ = Vector3.new(vel.X * t * getgenv().CONFIG.PredX, 0, vel.Z * t * getgenv().CONFIG.PredX)
    local predY = isAir and (vel.Y * t * getgenv().CONFIG.PredY - 0.5 * g * t * t + (vel.Y > 0 and 0.24 * t or 0)) or (vel.Y * t * getgenv().CONFIG.PredY)
    
    if getgenv().CONFIG.antiCurve then
        local mousePos = UIS:GetMouseLocation()
        local targetScreen = Camera:WorldToViewportPoint(aimPart.Position)
        if targetScreen.Z > 0 then
            local dist = (Vector2.new(targetScreen.X, targetScreen.Y) - mousePos).Magnitude
            if dist > 40 then
                predY = predY * 0.96
                predXZ = predXZ * 0.985
            end
        end
    end
    
    return pos + predXZ + Vector3.new(0, predY, 0)
end

-- BEAUTIFUL GUI MENU
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "CryefulMenu"
screenGui.Parent = game.CoreGui
screenGui.ResetOnSpawn = false

local mainFrame = Instance.new("Frame", screenGui)
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(0, 450, 0, 600)
mainFrame.Position = UDim2.new(0.5, -225, 0.5, -300)
mainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 25)
mainFrame.BorderSizePixel = 0
mainFrame.Draggable = true
mainFrame.Active = true

-- Corner
local corner = Instance.new("UICorner", mainFrame)
corner.CornerRadius = UDim.new(0, 15)

-- Shadow effect
local shadow = Instance.new("Frame", screenGui)
shadow.Name = "Shadow"
shadow.Size = mainFrame.Size
shadow.Position = mainFrame.Position + UDim2.new(0, 5, 0, 5)
shadow.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
shadow.BorderSizePixel = 0
shadow.ZIndex = mainFrame.ZIndex - 1
Instance.new("UICorner", shadow).CornerRadius = UDim.new(0, 15)
local shadowTransparency = Instance.new("TextLabel", shadow)
shadowTransparency.Size = UDim2.new(1, 0, 1, 0)
shadowTransparency.BackgroundTransparency = 0.7
shadowTransparency.BorderSizePixel = 0

-- Title
local titleBar = Instance.new("Frame", mainFrame)
titleBar.Name = "TitleBar"
titleBar.Size = UDim2.new(1, 0, 0, 50)
titleBar.BackgroundColor3 = Color3.fromRGB(255, 0, 127)
titleBar.BorderSizePixel = 0
Instance.new("UICorner", titleBar).CornerRadius = UDim.new(0, 15)

local titleText = Instance.new("TextLabel", titleBar)
titleText.Size = UDim2.new(1, 0, 1, 0)
titleText.BackgroundTransparency = 1
titleText.TextColor3 = Color3.fromRGB(255, 255, 255)
titleText.Font = Enum.Font.GothamBold
titleText.TextSize = 22
titleText.Text = "🔥 CRYEFUL SCRIPT v17"

-- Close button
local closeBtn = Instance.new("TextButton", titleBar)
closeBtn.Name = "CloseBtn"
closeBtn.Size = UDim2.new(0, 40, 0, 40)
closeBtn.Position = UDim2.new(1, -45, 0, 5)
closeBtn.BackgroundColor3 = Color3.fromRGB(200, 0, 100)
closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 16
closeBtn.Text = "✕"
closeBtn.BorderSizePixel = 0
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 8)

closeBtn.MouseButton1Click:Connect(function()
    mainFrame.Visible = false
    shadow.Visible = false
end)

-- Scroll Frame
local scrollFrame = Instance.new("ScrollingFrame", mainFrame)
scrollFrame.Name = "ScrollFrame"
scrollFrame.Size = UDim2.new(1, 0, 1, -60)
scrollFrame.Position = UDim2.new(0, 0, 0, 55)
scrollFrame.BackgroundTransparency = 1
scrollFrame.BorderSizePixel = 0
scrollFrame.ScrollBarThickness = 8
scrollFrame.ScrollBarImageColor3 = Color3.fromRGB(255, 0, 127)
scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 1200)

local layout = Instance.new("UIListLayout", scrollFrame)
layout.Padding = UDim.new(0, 10)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.FillDirection = Enum.FillDirection.Vertical

-- Function to create toggle button
local function createToggleButton(parent, name, defaultState, callback)
    local button = Instance.new("Frame", parent)
    button.Name = name
    button.Size = UDim2.new(1, -20, 0, 45)
    button.Position = UDim2.new(0, 10, 0, 0)
    button.BackgroundColor3 = Color3.fromRGB(25, 25, 40)
    button.BorderSizePixel = 0
    Instance.new("UICorner", button).CornerRadius = UDim.new(0, 10)
    
    local label = Instance.new("TextLabel", button)
    label.Size = UDim2.new(0.7, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.TextColor3 = Color3.fromRGB(255, 255, 255)
    label.Font = Enum.Font.Gotham
    label.TextSize = 14
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Text = "   " .. name
    
    local toggleBox = Instance.new("Frame", button)
    toggleBox.Name = "ToggleBox"
    toggleBox.Size = UDim2.new(0, 50, 0, 25)
    toggleBox.Position = UDim2.new(1, -65, 0.5, -12)
    toggleBox.BackgroundColor3 = defaultState and Color3.fromRGB(0, 200, 100) or Color3.fromRGB(100, 100, 100)
    toggleBox.BorderSizePixel = 0
    Instance.new("UICorner", toggleBox).CornerRadius = UDim.new(0, 5)
    
    local indicator = Instance.new("Frame", toggleBox)
    indicator.Name = "Indicator"
    indicator.Size = UDim2.new(0, 20, 0, 20)
    indicator.Position = defaultState and UDim2.new(1, -23, 0.5, -10) or UDim2.new(0, 3, 0.5, -10)
    indicator.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    indicator.BorderSizePixel = 0
    Instance.new("UICorner", indicator).CornerRadius = UDim.new(0, 3)
    
    local state = defaultState
    
    local toggleConnection
    toggleConnection = button.MouseButton1Click:Connect(function()
        state = not state
        callback(state)
        
        local targetColor = state and Color3.fromRGB(0, 200, 100) or Color3.fromRGB(100, 100, 100)
        local targetPos = state and UDim2.new(1, -23, 0.5, -10) or UDim2.new(0, 3, 0.5, -10)
        
        local tween = game:GetService("TweenService"):Create(
            toggleBox,
            TweenInfo.new(0.2),
            {BackgroundColor3 = targetColor}
        )
        tween:Play()
        
        local tween2 = game:GetService("TweenService"):Create(
            indicator,
            TweenInfo.new(0.2),
            {Position = targetPos}
        )
        tween2:Play()
    end)
    
    return button, function() return state end
end

-- Function to create slider
local function createSlider(parent, name, minVal, maxVal, defaultVal, callback)
    local container = Instance.new("Frame", parent)
    container.Name = name
    container.Size = UDim2.new(1, -20, 0, 60)
    container.Position = UDim2.new(0, 10, 0, 0)
    container.BackgroundColor3 = Color3.fromRGB(25, 25, 40)
    container.BorderSizePixel = 0
    Instance.new("UICorner", container).CornerRadius = UDim.new(0, 10)
    
    local label = Instance.new("TextLabel", container)
    label.Size = UDim2.new(0.7, 0, 0.4, 0)
    label.Position = UDim2.new(0, 10, 0, 5)
    label.BackgroundTransparency = 1
    label.TextColor3 = Color3.fromRGB(255, 0, 127)
    label.Font = Enum.Font.GothamBold
    label.TextSize = 12
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Text = name
    
    local valueLabel = Instance.new("TextLabel", container)
    valueLabel.Size = UDim2.new(0.2, 0, 0.4, 0)
    valueLabel.Position = UDim2.new(0.75, 0, 0, 5)
    valueLabel.BackgroundTransparency = 1
    valueLabel.TextColor3 = Color3.fromRGB(100, 200, 255)
    valueLabel.Font = Enum.Font.Gotham
    valueLabel.TextSize = 12
    valueLabel.Text = tostring(defaultVal)
    
    local sliderBg = Instance.new("Frame", container)
    sliderBg.Name = "SliderBg"
    sliderBg.Size = UDim2.new(0.9, 0, 0, 6)
    sliderBg.Position = UDim2.new(0.05, 0, 0.55, 0)
    sliderBg.BackgroundColor3 = Color3.fromRGB(50, 50, 70)
    sliderBg.BorderSizePixel = 0
    Instance.new("UICorner", sliderBg).CornerRadius = UDim.new(0, 3)
    
    local sliderFill = Instance.new("Frame", sliderBg)
    sliderFill.Name = "Fill"
    sliderFill.Size = UDim2.new((defaultVal - minVal) / (maxVal - minVal), 0, 1, 0)
    sliderFill.BackgroundColor3 = Color3.fromRGB(255, 0, 127)
    sliderFill.BorderSizePixel = 0
    Instance.new("UICorner", sliderFill).CornerRadius = UDim.new(0, 3)
    
    local sliderButton = Instance.new("Frame", sliderBg)
    sliderButton.Name = "Button"
    sliderButton.Size = UDim2.new(0, 14, 0, 14)
    sliderButton.Position = sliderFill.Size + UDim2.new(-0.5, 0, -4, 0)
    sliderButton.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    sliderButton.BorderSizePixel = 0
    Instance.new("UICorner", sliderButton).CornerRadius = UDim.new(0, 7)
    
    local currentValue = defaultVal
    
    local function updateSlider(input)
        local mousePos = UIS:GetMouseLocation().X
        local sliderPos = sliderBg.AbsolutePosition.X
        local sliderSize = sliderBg.AbsoluteSize.X
        
        local percentage = math.clamp((mousePos - sliderPos) / sliderSize, 0, 1)
        currentValue = minVal + (maxVal - minVal) * percentage
        
        sliderFill.Size = UDim2.new(percentage, 0, 1, 0)
        sliderButton.Position = sliderFill.Size + UDim2.new(-0.5, 0, -4, 0)
        valueLabel.Text = tostring(math.floor(currentValue * 100) / 100)
        
        callback(currentValue)
    end
    
    sliderButton.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            local connection
            connection = RunService.Heartbeat:Connect(function()
                if UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
                    updateSlider(input)
                else
                    connection:Disconnect()
                end
            end)
        end
    end)
    
    return container
end

-- Create menu items
createToggleButton(scrollFrame, "🎯 Silent Aim", getgenv().CONFIG.silentAim, function(state)
    getgenv().CONFIG.silentAim = state
end)

createToggleButton(scrollFrame, "🔒 Camlock", getgenv().CONFIG.camlock, function(state)
    getgenv().CONFIG.camlock = state
    if not state then lockedTarget = nil end
end)

createToggleButton(scrollFrame, "🤖 Trigger Bot", getgenv().CONFIG.triggerBot, function(state)
    getgenv().CONFIG.triggerBot = state
end)

createToggleButton(scrollFrame, "✈️ Auto Air", getgenv().CONFIG.autoAirFire, function(state)
    getgenv().CONFIG.autoAirFire = state
end)

createToggleButton(scrollFrame, "🎨 Aim Assist", getgenv().CONFIG.aimAssist, function(state)
    getgenv().CONFIG.aimAssist = state
end)

createToggleButton(scrollFrame, "💥 Blatant Mode", getgenv().CONFIG.blatantMode, function(state)
    getgenv().CONFIG.blatantMode = state
end)

createToggleButton(scrollFrame, "🔓 Silent Lock", getgenv().CONFIG.silentLockEnabled, function(state)
    getgenv().CONFIG.silentLockEnabled = state
    if not state then silentLockedTarget = nil end
end)

createToggleButton(scrollFrame, "📡 Auto Pred", getgenv().CONFIG.AutoPredEnabled, function(state)
    getgenv().CONFIG.AutoPredEnabled = state
end)

createToggleButton(scrollFrame, "🛡️ Anti-Curve", getgenv().CONFIG.antiCurve, function(state)
    getgenv().CONFIG.antiCurve = state
end)

-- Sliders
createSlider(scrollFrame, "📊 Pred X", 0.1, 2, getgenv().CONFIG.PredX, function(val)
    getgenv().CONFIG.PredX = val
end)

createSlider(scrollFrame, "📊 Pred Y", 0.1, 2, getgenv().CONFIG.PredY, function(val)
    getgenv().CONFIG.PredY = val
end)

createSlider(scrollFrame, "🔫 Silent FOV", 50, 400, getgenv().CONFIG.SilentAimFOV, function(val)
    getgenv().CONFIG.SilentAimFOV = val
end)

createSlider(scrollFrame, "🎯 Assist FOV", 30, 200, getgenv().CONFIG.AimAssistFOV, function(val)
    getgenv().CONFIG.AimAssistFOV = val
end)

createSlider(scrollFrame, "⚙️ Smoothing", 0.01, 1, getgenv().CONFIG.Smoothing, function(val)
    getgenv().CONFIG.Smoothing = val
end)

-- Stats Label
local statsLabel = Instance.new("TextLabel", scrollFrame)
statsLabel.Name = "Stats"
statsLabel.Size = UDim2.new(1, -20, 0, 80)
statsLabel.Position = UDim2.new(0, 10, 0, 0)
statsLabel.BackgroundColor3 = Color3.fromRGB(25, 25, 40)
statsLabel.BorderSizePixel = 0
statsLabel.TextColor3 = Color3.fromRGB(100, 200, 255)
statsLabel.Font = Enum.Font.Code
statsLabel.TextSize = 11
statsLabel.TextWrapped = true
statsLabel.TextXAlignment = Enum.TextXAlignment.Left
Instance.new("UICorner", statsLabel).CornerRadius = UDim.new(0, 10)

-- Toggle menu with M key
UIS.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Enum.KeyCode[getgenv().CONFIG.Keys.ToggleMenu] then
        mainFrame.Visible = not mainFrame.Visible
        shadow.Visible = mainFrame.Visible
    end
end)

-- Update stats
RunService.Heartbeat:Connect(function()
    local pred = getPred(lockedTarget or silentLockedTarget or findClosest())
    statsLabel.Text = "📡 Game: " .. detectedGame .. "\n⏱️ Ping: " .. currentPing .. "ms\n📊 Pred: " .. string.format("%.4f", pred) .. "\n🎯 Hits: " .. hitCount
end)

print("✅ CRYEFUL SCRIPT v17 FULLY LOADED!")
print("📁 Press M to toggle menu | All features are in the beautiful GUI!"