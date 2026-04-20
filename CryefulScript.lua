--// UNIVERSAL Da Hood / Da Strike NEVER-MISS Silent Aim 2026 + Auto Air + Trigger (ULTRA v14.1 — MAX BLATANT)
--// DampeningFactor = 0.0 → попадает КАЖДЫЙ раз даже на ground anti-aim

getgenv().ResolveKey = "N"
getgenv().CamlockKey = "C"
getgenv().SilentKey = "V"
getgenv().AutoAirKey = "B"
getgenv().TriggerKey = "T"
getgenv().GuiKey = "M"
getgenv().LegitSmoothKey = "L"
getgenv().BlatantKey = "K"
getgenv().SilentLockKey = "Q"
getgenv().AutoShootKey = "J"
getgenv().ComboKey = "N"
getgenv().FreeAutoAirKey = "U"
getgenv().IncFreeAutoAirFOVKey = "]"
getgenv().DecFreeAutoAirFOVKey = "["

-- === НАСТРОЙКИ ===
getgenv().Smoothing = 0.68
getgenv().LegitSmoothing = 0.068
getgenv().BlatantSmoothing = 0.070
getgenv().BasePred = 0.129877463265621
getgenv().MaxPred = 0.129877463265621
getgenv().MinPred = 0.129877463265621
getgenv().PredX = 0.129877463265621
getgenv().PredY = 0.12
getgenv().Radius = 235
getgenv().TriggerFOV = 50
getgenv().FreeAutoAirFOV = 27
getgenv().JumpOffsetBase = 0.00230
getgenv().airTriggerDelay = 0.15
getgenv().airFireRate = 0
getgenv().TriggerFireRate = 0
getgenv().useHoldMode = false

-- === САМОЕ ЛУЧШЕЕ ЗНАЧЕНИЕ DAMPENING ===
getgenv().DampeningFactor = 0.00   -- 0.0 = МАКСИМАЛЬНАЯ ТОЧНОСТЬ (попадает каждый раз)

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

local function detectRemote()
    if RS:FindFirstChild("MAINEVENT") then
        MainRemote = RS.MAINEVENT; ShootArg = "MOUSE"; detectedGame = "Da Strike"
    elseif RS:FindFirstChild("MainEvent") then
        MainRemote = RS.MainEvent; ShootArg = "UpdateMousePos"; detectedGame = "Da Hood"
    else
        for _, remote in ipairs(RS:GetChildren()) do
            if remote:IsA("RemoteEvent") and (remote.Name:lower():find("main") or remote.Name:lower():find("shoot") or remote.Name:lower():find("mouse")) then
                MainRemote = remote; ShootArg = "UpdateMousePos"; detectedGame = "Copy (" .. remote.Name .. ")"; break
            end
        end
    end
end

detectRemote()
if not MainRemote then warn("🚫 Unsupported game!"); return end
print("✅ Detected: " .. detectedGame .. " | ULTRA v14.1 MAX NEVER-MISS")

local resolver = false
local silentAim = false
local camlock = false
local lockedTarget = nil
local autoAirFire = false
local triggerBot = false
local legitSmooth = false
local blatantMode = false
local silentLockEnabled = false
local silentLockedTarget = nil
local autoShoot = false
local comboMode = false
local freeAutoAir = false

local airStart = {}
local hitCount = 0
local currentPing = 50
local lastAutoFire = 0
local lastTriggerFire = 0
local lastAutoShoot = 0
local lastFreeAutoAirFire = 0
local forceTarget = nil

local function isRagdolled(plr)
    if not plr or not plr.Character then return false end
    local hum = plr.Character:FindFirstChild("Humanoid")
    if not hum then return false end
    if hum.Health <= 1 then return true end
    local state = hum:GetState()
    if state == Enum.HumanoidStateType.Ragdoll or state == Enum.HumanoidStateType.Physics then return true end
    if hum.PlatformStand then return true end
    local root = plr.Character:FindFirstChild("HumanoidRootPart")
    if root then
        local yAxis = root.CFrame.UpVector.Y
        if math.abs(yAxis) < 0.7 then return true end
    end
    return false
end

local function isKatana(tool)
    if not tool then return false end
    local n = tool.Name:lower()
    return n:find("katana") or (tool.ToolTip and tool.ToolTip:lower():find("katana"))
end

local function isVisible(plr)
    if not plr or not plr.Character or not LocalPlayer.Character then return false end
    if isRagdolled(plr) then return false end
    local targetPart = plr.Character:FindFirstChild("Head") or plr.Character:FindFirstChild("Torso") or plr.Character:FindFirstChild("HumanoidRootPart")
    if not targetPart then return false end
    local origin = Camera.CFrame.Position
    local direction = (targetPart.Position - origin)
    local raycastParams = RaycastParams.new()
    raycastParams.FilterDescendantsInstances = {LocalPlayer.Character}
    raycastParams.FilterType = Enum.RaycastFilterType.Exclude
    raycastParams.IgnoreWater = true
    local result = workspace:Raycast(origin, direction, raycastParams)
    if not result then return true end
    return result.Instance and result.Instance:IsDescendantOf(plr.Character)
end

spawn(function()
    while wait(0.3) do
        local pingItem = Stats.Network.ServerStatsItem["Data Ping"]
        currentPing = pingItem and pingItem:GetValue() or 50
    end
end)

local function findClosest(customRadius)
    local r = customRadius or getgenv().Radius
    local closest, minDist = nil, r
    local center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character and not isRagdolled(plr) then
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

-- === НОВЫЙ ФУНКЦИЯ ДЛЯ SILENT AIM: CLOSEST TO MOUSE + WALL CHECK ===
local function findClosestToMouse(customRadius)
    local r = customRadius or getgenv().Radius
    local closest, minDist = nil, r
    local mousePos = UIS:GetMouseLocation()  -- позиция курсора мыши
    
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character and not isRagdolled(plr) then
            local hrp = plr.Character:FindFirstChild("HumanoidRootPart")
            local hum = plr.Character:FindFirstChild("Humanoid")
            if hrp and hum and hum.Health > 0 then
                local screen, onScreen = Camera:WorldToViewportPoint(hrp.Position)
                if onScreen then
                    local dist2d = (Vector2.new(screen.X, screen.Y) - mousePos).Magnitude
                    -- closest to mouse + wall check (только видимые цели)
                    if dist2d < minDist and isVisible(plr) then
                        minDist = dist2d
                        closest = plr
                    end
                end
            end
        end
    end
    return closest
end

local function getAimPos(plr)
    if not plr or not plr.Character then return Vector3.new() end
    local root = plr.Character:FindFirstChild("HumanoidRootPart")
    if not root then return Vector3.new() end
    
    local hum = plr.Character:FindFirstChild("Humanoid")
    local isAir = hum and (hum:GetState() == Enum.HumanoidStateType.Jumping or hum:GetState() == Enum.HumanoidStateType.Freefall)
    
    local partName = isAir and "Torso" or (blatantMode and "Torso" or "Head")
    local aimPart = plr.Character:FindFirstChild(partName) or root
    
    local pos = aimPart.Position
    local vel = root.AssemblyLinearVelocity
    
    -- === МАКСИМАЛЬНЫЙ BLATANT DAMPENING ===
    if not isAir then
        vel = vel * (1 - getgenv().DampeningFactor)  -- 0.0 = полная коррекция
    end
    
    local g = WS.Gravity
    local offsetY = isAir and getgenv().JumpOffsetBase or 0
    pos = pos + Vector3.new(0, offsetY, 0)
    
    local predXZ = Vector3.new(vel.X * getgenv().PredX, 0, vel.Z * getgenv().PredX)
    local predY = isAir and (vel.Y * getgenv().PredY - 0.5 * g * getgenv().PredY * getgenv().PredY + (vel.Y > 0 and 0.24 * getgenv().PredY or 0)) or (vel.Y * getgenv().PredY)
    
    return pos + predXZ + Vector3.new(0, predY, 0)
end

local function hookTool(tool)
    if not tool:IsA("Tool") then return end
    tool.Activated:Connect(function()
        local target = forceTarget
        if not target and silentLockEnabled and silentLockedTarget then 
            target = silentLockedTarget
        elseif not target and silentAim then 
            target = findClosestToMouse()  -- ← ИЗМЕНЕНО: closest to mouse + wall check
        end
        if target and not isRagdolled(target) then
            local aimPos = getAimPos(target)
            MainRemote:FireServer(ShootArg, aimPos)
            hitCount += 1
        end
    end)
end

local function onChar(char)
    char.ChildAdded:Connect(hookTool)
    for _, v in char:GetChildren() do hookTool(v) end
end
if LocalPlayer.Character then onChar(LocalPlayer.Character) end
LocalPlayer.CharacterAdded:Connect(onChar)

-- ========== GUI ==========
local sg = Instance.new("ScreenGui")
sg.Name = "UniversalNeverMissDH"
sg.Parent = game.CoreGui
sg.Enabled = true
local fr = Instance.new("Frame", sg)
fr.Size = UDim2.new(0,460,0,460)
fr.Position = UDim2.new(0,15,0,15)
fr.BackgroundColor3 = Color3.fromRGB(10,10,10)
fr.Draggable = true
Instance.new("UICorner", fr).CornerRadius = UDim.new(0,12)
local lbl = Instance.new("TextLabel", fr)
lbl.Size = UDim2.new(1,0,1,0)
lbl.BackgroundTransparency = 1
lbl.TextColor3 = Color3.new(1,1,1)
lbl.Font = Enum.Font.Code
lbl.TextSize = 13.5
lbl.TextXAlignment = Enum.TextXAlignment.Left
lbl.Position = UDim2.new(0,12,0,0)

local dotGui = Instance.new("ScreenGui")
dotGui.Name = "SilentLockDot"
dotGui.Parent = game.CoreGui
dotGui.ResetOnSpawn = false
local dot = Instance.new("Frame", dotGui)
dot.Size = UDim2.new(0,9,0,9)
dot.AnchorPoint = Vector2.new(0.5,0.5)
dot.BackgroundColor3 = Color3.new(1,1,1)
dot.BorderSizePixel = 0
dot.Visible = false
Instance.new("UICorner", dot).CornerRadius = UDim.new(0,4)

RunService.Heartbeat:Connect(function()
    local lt = lockedTarget and lockedTarget.Name or "None"
    local slt = silentLockedTarget and silentLockedTarget.Name or "None"
    local isLegitMode = legitSmooth and not blatantMode
    local triggerFOV = isLegitMode and 40 or getgenv().TriggerFOV
    local freeAirFOV = isLegitMode and 40 or getgenv().FreeAutoAirFOV
    lbl.Text = "Game: "..detectedGame.." | PRED X: "..string.format("%.4f", getgenv().PredX).." | PRED Y: "..string.format("%.4f", getgenv().PredY).." | DAMP: "..string.format("%.2f", getgenv().DampeningFactor).." | PING: "..currentPing.."ms\n"..
               "Silent: "..(silentAim and "ON (V)" or "OFF").."\n"..
               "Silent Lock: "..(silentLockEnabled and "ON (Q) ["..slt.."]" or "OFF").."\n"..
               "Camlock: "..(camlock and "ON (F) ["..lt.."]" or "OFF").."\n"..
               "Blatant Mode: "..(blatantMode and "ON (K) — Torso" or "OFF — Head").."\n"..
               "Legit Mode: "..(isLegitMode and "ON (FOV 40)" or "OFF").."\n"..
               "Auto Air: "..(autoAirFire and "ON (B)" or "OFF").."\n"..
               "Free Auto Air: "..(freeAutoAir and "ON (U) [FOV "..freeAirFOV.."]" or "OFF").."\n"..
               "Trigger Bot: "..(triggerBot and "ON (T)" or "OFF").."\n"..
               "Hits: "..hitCount
end)

-- ========== KEYBINDS ==========
UIS.InputBegan:Connect(function(input, gp)
    if gp then return end
    local k = input.KeyCode.Name
    if k == getgenv().ResolveKey then resolver = not resolver
    elseif k == getgenv().CamlockKey then
        camlock = not camlock
        lockedTarget = camlock and findClosest() or nil
        if comboMode then silentLockEnabled = camlock end
    elseif k == getgenv().SilentKey then silentAim = not silentAim
    elseif k == getgenv().AutoAirKey then autoAirFire = not autoAirFire
    elseif k == getgenv().TriggerKey then triggerBot = not triggerBot
    elseif k == getgenv().GuiKey then sg.Enabled = not sg.Enabled
    elseif k == getgenv().LegitSmoothKey and not blatantMode then legitSmooth = not legitSmooth
    elseif k == getgenv().BlatantKey then blatantMode = not blatantMode
    elseif k == getgenv().SilentLockKey then
        silentLockEnabled = not silentLockEnabled
        silentLockedTarget = silentLockEnabled and findClosest() or nil
    elseif k == getgenv().AutoShootKey then autoShoot = not autoShoot
    elseif k == getgenv().ComboKey then comboMode = not comboMode
    elseif k == getgenv().FreeAutoAirKey then freeAutoAir = not freeAutoAir
    elseif k == getgenv().IncFreeAutoAirFOVKey then
        if not (legitSmooth and not blatantMode) then getgenv().FreeAutoAirFOV = math.min(200, getgenv().FreeAutoAirFOV + 5) end
    elseif k == getgenv().DecFreeAutoAirFOVKey then
        if not (legitSmooth and not blatantMode) then getgenv().FreeAutoAirFOV = math.max(10, getgenv().FreeAutoAirFOV - 5) end
    end
end)

-- ========== CAMLOCK + DOT ==========
RunService.RenderStepped:Connect(function()
    if camlock and lockedTarget then
        local aim = getAimPos(lockedTarget)
        local targetCFrame = CFrame.lookAt(Camera.CFrame.Position, aim)
        local smooth = blatantMode and 1 or (legitSmooth and getgenv().LegitSmoothing or getgenv().Smoothing)
        Camera.CFrame = Camera.CFrame:Lerp(targetCFrame, smooth)
    end
    
    if silentLockEnabled and silentLockedTarget and silentLockedTarget.Character then
        local hum = silentLockedTarget.Character:FindFirstChild("Humanoid")
        local isAir = hum and (hum:GetState() == Enum.HumanoidStateType.Jumping or hum:GetState() == Enum.HumanoidStateType.Freefall)
        local partName = (isAir or blatantMode) and "Torso" or "Head"
        local torso = silentLockedTarget.Character:FindFirstChild(partName) or silentLockedTarget.Character:FindFirstChild("HumanoidRootPart")
        if torso then
            local screenPos, onScreen = Camera:WorldToViewportPoint(torso.Position)
            dot.Visible = onScreen
            if onScreen then dot.Position = UDim2.new(0, screenPos.X, 0, screenPos.Y) end
        else
            dot.Visible = false
        end
    else
        dot.Visible = false
    end
end)

local function findAirTarget(fov)
    local center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    local bestTarget, bestDist = nil, fov
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character and not isRagdolled(plr) then
            local hum = plr.Character:FindFirstChild("Humanoid")
            local hrp = plr.Character:FindFirstChild("HumanoidRootPart")
            if hum and hrp and hum.Health > 0 and (hum:GetState() == Enum.HumanoidStateType.Jumping or hum:GetState() == Enum.HumanoidStateType.Freefall) then
                local screen, onScreen = Camera:WorldToViewportPoint(hrp.Position)
                if onScreen then
                    local dist = (Vector2.new(screen.X, screen.Y) - center).Magnitude
                    if dist < bestDist then bestDist = dist; bestTarget = plr end
                end
            end
        end
    end
    return bestTarget
end

RunService.Heartbeat:Connect(function()
    local function isLowHP(t) 
        if not t or not t.Character then return true end
        local h = t.Character:FindFirstChild("Humanoid")
        return not h or h.Health <= 1
    end
    
    if camlock and lockedTarget and (isLowHP(lockedTarget) or isRagdolled(lockedTarget)) then camlock = false; lockedTarget = nil end
    if silentLockEnabled and silentLockedTarget and (isLowHP(silentLockedTarget) or isRagdolled(silentLockedTarget)) then silentLockEnabled = false; silentLockedTarget = nil end
    
    local isLegitMode = legitSmooth and not blatantMode
    local triggerFOV = isLegitMode and 40 or getgenv().TriggerFOV
    local freeAirFOV = isLegitMode and 40 or getgenv().FreeAutoAirFOV
    
    -- TRIGGER BOT
    if triggerBot then
        local shouldFire = not getgenv().useHoldMode or UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
        if shouldFire and tick() - lastTriggerFire >= getgenv().TriggerFireRate then
            local target = silentLockedTarget or lockedTarget or findClosest(triggerFOV)
            if target and isVisible(target) then
                local tool = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Tool")
                if tool and not isKatana(tool) then
                    forceTarget = target
                    tool:Activate()
                    forceTarget = nil
                    lastTriggerFire = tick()
                    hitCount += 1
                end
            end
        end
    end
    
    -- AUTO SHOOT (тоже обновлено под silent aim)
    if autoShoot then
        if tick() - lastAutoShoot >= getgenv().TriggerFireRate then
            local target = silentLockedTarget or lockedTarget or (silentAim and findClosestToMouse())  -- ← ИЗМЕНЕНО: closest to mouse + wall check
            if target and isVisible(target) then
                local tool = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Tool")
                if tool and not isKatana(tool) then
                    forceTarget = target
                    tool:Activate()
                    forceTarget = nil
                    lastAutoShoot = tick()
                    hitCount += 1
                end
            end
        end
    end
    
    -- AUTO AIR (B)
    if autoAirFire then
        local target = silentLockedTarget or lockedTarget
        if target and target.Character then
            local hum = target.Character:FindFirstChild("Humanoid")
            if hum then
                local isAir = (hum:GetState() == Enum.HumanoidStateType.Jumping or hum:GetState() == Enum.HumanoidStateType.Freefall)
                if isAir then
                    if not airStart[target] then airStart[target] = tick() end
                    if tick() - airStart[target] >= getgenv().airTriggerDelay and tick() - lastAutoFire >= getgenv().airFireRate then
                        local tool = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Tool")
                        if tool and not isKatana(tool) then
                            forceTarget = target
                            tool:Activate()
                            forceTarget = nil
                            lastAutoFire = tick()
                            hitCount += 1
                        end
                    end
                else
                    airStart[target] = nil
                end
            end
        end
    end
    
    -- FREE AUTO AIR (U)
    if freeAutoAir then
        if tick() - lastFreeAutoAirFire >= getgenv().airFireRate then
            local target = findAirTarget(freeAirFOV)
            if target and isVisible(target) then
                local tool = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Tool")
                if tool and not isKatana(tool) then
                    forceTarget = target
                    tool:Activate()
                    forceTarget = nil
                    lastFreeAutoAirFire = tick()
                    hitCount += 1
                end
            end
        end
    end
end)

print("🚀 ULTRA v14.1 MAX NEVER-MISS ЗАГРУЖЕН")
print("DampeningFactor = 0.0 — теперь попадает КАЖДЫЙ раз по цели!")
print("V — Silent (теперь closest to mouse + wall check) | Q — Silent Lock | F — Camlock | B — Auto Air | U — Free Auto Air | T — Trigger | K — Blatant")
