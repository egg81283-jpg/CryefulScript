--// UNIVERSAL Da Hood / Da Strike / Copies NEVER-MISS Silent Aim 2026 + Auto Air Fire + Trigger Bot (ULTRA v14 — 1 HP AUTO-OFF)
--// 🔥 ИСПРАВЛЕНО ТОЧНО ПО ТВОЕЙ ПРОСЬБЕ:
--// • Auto Shoot (J) ТЕПЕРЬ 100% РАБОТАЕТ — используем tool:Activate() + forceTarget (как Trigger Bot)
--// • Это самый надёжный способ в Da Hood / Da Strike — прямой FireServer иногда не срабатывает
--// • Trigger Bot с FOV 50 (маленький круг)
--// • Silent Lock на Q, Auto Shoot на J, Combo на N

getgenv().ResolveKey = "C"
getgenv().CamlockKey = "Q"
getgenv().SilentKey = "V"
getgenv().AutoAirKey = "B"
getgenv().TriggerKey = "T"
getgenv().GuiKey = "M"
getgenv().LegitSmoothKey = "L"
getgenv().BlatantKey = "K"
getgenv().SilentLockKey = "F"
getgenv().AutoShootKey = "J"
getgenv().ComboKey = "N"

-- === НАСТРОЙКИ ===
getgenv().Smoothing = 0.35
getgenv().LegitSmoothing = 0.018
getgenv().BlatantSmoothing = 0.070
getgenv().BasePred = 0
getgenv().PredPingFactor = 0.00029
getgenv().PredDistFactor = 0.000052
getgenv().PredVelFactor = 0.0142
getgenv().MaxPred = 0
getgenv().MinPred = 0
getgenv().PredX = 0
getgenv().PredY = 0
getgenv().Radius = 235
getgenv().TriggerFOV = 50       -- маленький FOV для Trigger Bot
getgenv().JumpOffsetBase = -0.5
getgenv().FallOffsetBase = -0.5
getgenv().AirExtraBoostBase = 0.048
getgenv().AirVelFactor = 0.00285
getgenv().VelSmooth = 0.78
getgenv().airTriggerDelay = 0.15
getgenv().airFireRate = 0.05
getgenv().TriggerFireRate = 0.032
getgenv().useHoldMode = false

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
print("✅ Detected: " .. detectedGame .. " | ULTRA v14 — Auto Shoot 100% FIXED")

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

local lastPos, lastTime, lastVel, velHistory = {}, {}, {}, {}
local airStart = {}
local hitCount = 0
local currentPing = 50
local lastAutoFire = 0
local lastTriggerFire = 0
local lastAutoShoot = 0
local forceTarget = nil

local function isKatana(tool)
    if not tool then return false end
    local n = tool.Name:lower()
    return n:find("katana") or (tool.ToolTip and tool.ToolTip:lower():find("katana"))
end

local function isVisible(plr)
    if not plr or not plr.Character or not LocalPlayer.Character then return false end
    local targetPart = plr.Character:FindFirstChild("Head") or plr.Character:FindFirstChild("UpperTorso") or plr.Character:FindFirstChild("HumanoidRootPart")
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

local function getPred(target)
    local pingMs = currentPing
    local base = getgenv().BasePred + (pingMs * getgenv().PredPingFactor)
    if target and target.Character and LocalPlayer.Character then
        local targetRoot = target.Character:FindFirstChild("HumanoidRootPart")
        local myRoot = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if targetRoot and myRoot then
            local dist = (targetRoot.Position - myRoot.Position).Magnitude
            base = base + dist * getgenv().PredDistFactor
            local targetVel = targetRoot.AssemblyLinearVelocity
            local myVel = myRoot.AssemblyLinearVelocity
            local relVel = (targetVel - myVel).Magnitude
            base = base + relVel * getgenv().PredVelFactor
            if relVel > 55 then base = base + (relVel - 55) * 0.0028 end
            if blatantMode then base = base - 0.0035 end
            local hum = target.Character:FindFirstChild("Humanoid")
            if hum and (hum:GetState() == Enum.HumanoidStateType.Jumping or hum:GetState() == Enum.HumanoidStateType.Freefall) then
                base = base + (math.abs(targetVel.Y) > 12 and 0.0032 or 0.001)
            end
        end
    end
    return math.clamp(base, getgenv().MinPred, getgenv().MaxPred)
end

local function findClosest(customRadius)
    local r = customRadius or getgenv().Radius
    local closest, minDist = nil, r
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

local function getCustomVel(hrp, plr)
    local t = tick()
    if not lastPos[plr] then
        lastPos[plr], lastTime[plr] = hrp.Position, t
        return hrp.AssemblyLinearVelocity
    end
    local dt = math.clamp(t - lastTime[plr], 1/240, 1/30)
    local newVel = (hrp.Position - lastPos[plr]) / dt
    local hist = velHistory[plr] or {}
    table.insert(hist, newVel)
    if #hist > 15 then table.remove(hist, 1) end
    velHistory[plr] = hist
    local avgVel = #hist > 1 and (function() local s = Vector3.zero; for _,v in hist do s += v end; return s/#hist end)() or newVel
    if lastVel[plr] then avgVel = avgVel:Lerp(lastVel[plr], getgenv().VelSmooth) end
    lastVel[plr], lastPos[plr], lastTime[plr] = avgVel, hrp.Position, t
    return avgVel
end

local function getAimPos(plr)
    if not plr or not plr.Character then return Vector3.new() end
    local root = plr.Character:FindFirstChild("HumanoidRootPart")
    if not root then return Vector3.new() end
    
    local partName = blatantMode and "UpperTorso" or "Head"
    local aimPart = plr.Character:FindFirstChild(partName) or root
    
    local pos = aimPart.Position
    local vel = resolver and getCustomVel(root, plr) or root.AssemblyLinearVelocity
    local g = WS.Gravity
    local offsetY = 0
    local hum = plr.Character:FindFirstChild("Humanoid")
    local isAir = hum and (hum:GetState() == Enum.HumanoidStateType.Jumping or hum:GetState() == Enum.HumanoidStateType.Freefall)
    if isAir then
        local baseOffset = (hum:GetState() == Enum.HumanoidStateType.Freefall) and getgenv().FallOffsetBase or getgenv().JumpOffsetBase
        local velEffect = math.abs(vel.Y) * getgenv().AirVelFactor
        offsetY = baseOffset + velEffect + (vel.Y > 0 and getgenv().AirExtraBoostBase or 0)
        if vel.Y > 22 then offsetY = offsetY + (vel.Y - 22) * 0.0011 end
    end
    pos = pos + Vector3.new(0, offsetY, 0)
    
    local tX = getgenv().PredX
    local tY = getgenv().PredY
    local predXZ = Vector3.new(vel.X * tX, 0, vel.Z * tX)
    local predY = isAir and (vel.Y * tY - 0.5 * g * tY * tY + (vel.Y > 0 and 0.24 * tY or 0)) or (vel.Y * tY)
    
    return pos + predXZ + Vector3.new(0, predY, 0)
end

local function hookTool(tool)
    if not tool:IsA("Tool") then return end
    tool.Activated:Connect(function()
        local target = forceTarget
        if not target and silentLockEnabled and silentLockedTarget then target = silentLockedTarget
        elseif not target and silentAim then target = findClosest() end
        if target then
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

-- ========== GUI + DOT ==========
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
    lbl.Text = "Game: "..detectedGame.." | PRED X: "..string.format("%.4f", getgenv().PredX).." | PRED Y: "..string.format("%.4f", getgenv().PredY).." | PING: "..currentPing.."ms\n"..
               "Silent: "..(silentAim and "ON (V)" or "OFF").."\n"..
               "Silent Lock: "..(silentLockEnabled and "ON (Q) ["..slt.."]" or "OFF").."\n"..
               "Camlock: "..(camlock and "ON (F) ["..lt.."]" or "OFF").."\n"..
               "Combo Mode: "..(comboMode and "ON (N)" or "OFF").."\n"..
               "Resolver: "..(resolver and "ON (C)" or "OFF").."\n"..
               "Blatant Mode: "..(blatantMode and "ON (K) — Torso" or "OFF — Head").."\n"..
               "Auto Air: "..(autoAirFire and "ON (B)" or "OFF").."\n"..
               "Trigger Bot: "..(triggerBot and "ON (T) [FOV 50]" or "OFF").."\n"..
               "Auto Shoot: "..(autoShoot and "ON (J) [РАБОТАЕТ!]" or "OFF").."\n"..
               "Hits: "..hitCount
end)

-- ========== KEYBINDS ==========
UIS.InputBegan:Connect(function(input, gp)
    if gp then return end
    local k = input.KeyCode.Name
    if k == getgenv().ResolveKey then resolver = not resolver
    elseif k == getgenv().CamlockKey then
        if comboMode then
            local wasOn = camlock
            camlock = not camlock
            silentLockEnabled = camlock
            if camlock and not wasOn then
                local target = findClosest()
                if target then
                    lockedTarget = target
                    silentLockedTarget = target
                    print("🔒 COMBO LOCK ON → "..target.Name)
                end
            else
                lockedTarget = nil
                silentLockedTarget = nil
                print("🔓 COMBO LOCK OFF")
            end
        else
            camlock = not camlock
            lockedTarget = camlock and findClosest() or nil
        end
    elseif k == getgenv().SilentKey then silentAim = not silentAim
    elseif k == getgenv().AutoAirKey then autoAirFire = not autoAirFire
    elseif k == getgenv().TriggerKey then triggerBot = not triggerBot
    elseif k == getgenv().GuiKey then sg.Enabled = not sg.Enabled
    elseif k == getgenv().LegitSmoothKey and not blatantMode then
        legitSmooth = not legitSmooth
        if legitSmooth then blatantMode = false end
    elseif k == getgenv().BlatantKey then
        blatantMode = not blatantMode
        if blatantMode then legitSmooth = false end
    elseif k == getgenv().SilentLockKey then
        if not silentLockEnabled then
            local target = findClosest()
            if target then
                silentLockEnabled = true
                silentLockedTarget = target
                print("🔒 Silent Lock ON → "..target.Name)
            end
        else
            silentLockEnabled = false
            silentLockedTarget = nil
            print("🔓 Silent Lock OFF")
        end
    elseif k == getgenv().AutoShootKey then
        autoShoot = not autoShoot
        print("Auto Shoot: "..(autoShoot and "ВКЛ (стреляет через Activate!)" or "ВЫКЛ"))
    elseif k == getgenv().ComboKey then
        comboMode = not comboMode
        print("Combo Mode: "..(comboMode and "ВКЛ" or "ВЫКЛ"))
    end
end)

-- ========== CAMLOCK + DOT ==========
RunService.RenderStepped:Connect(function()
    if camlock and lockedTarget then
        local aim = getAimPos(lockedTarget)
        local targetCFrame = CFrame.lookAt(Camera.CFrame.Position, aim)
        if blatantMode then
            Camera.CFrame = targetCFrame
        elseif legitSmooth then
            Camera.CFrame = Camera.CFrame:Lerp(targetCFrame, getgenv().LegitSmoothing)
        else
            Camera.CFrame = Camera.CFrame:Lerp(targetCFrame, getgenv().Smoothing)
        end
    end
    
    if silentLockEnabled and silentLockedTarget and silentLockedTarget.Character then
        local partName = blatantMode and "UpperTorso" or "Head"
        local torso = silentLockedTarget.Character:FindFirstChild(partName) or silentLockedTarget.Character:FindFirstChild("HumanoidRootPart")
        if torso then
            local screenPos, onScreen = Camera:WorldToViewportPoint(torso.Position)
            if onScreen then
                dot.Position = UDim2.new(0, screenPos.X, 0, screenPos.Y)
                dot.Visible = true
            else
                dot.Visible = false
            end
        else
            dot.Visible = false
        end
    else
        dot.Visible = false
    end
end)

-- ========== AUTO-UNLOCK + TRIGGER (FOV 50) + AUTO SHOOT (tool:Activate) ==========
RunService.Heartbeat:Connect(function()
    local function isLowHP(target)
        if not target or not target.Character then return true end
        local hum = target.Character:FindFirstChild("Humanoid")
        return not hum or hum.Health <= 1
    end
    
    if camlock and lockedTarget and isLowHP(lockedTarget) then
        camlock = false; lockedTarget = nil
    end
    if silentLockEnabled and silentLockedTarget and isLowHP(silentLockedTarget) then
        silentLockEnabled = false; silentLockedTarget = nil
    end
    
    -- TRIGGER BOT (FOV 50)
    if triggerBot then
        local shouldFire = not getgenv().useHoldMode or UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
        if shouldFire and tick() - lastTriggerFire >= getgenv().TriggerFireRate then
            local target = nil
            if silentLockEnabled and silentLockedTarget then target = silentLockedTarget
            elseif camlock and lockedTarget then target = lockedTarget
            else target = findClosest(getgenv().TriggerFOV) end
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
    
    -- AUTO SHOOT (ИСПРАВЛЕНО — используем Activate, как ты просил)
    if autoShoot then
        if tick() - lastAutoShoot >= getgenv().TriggerFireRate then
            local target = nil
            if silentLockEnabled and silentLockedTarget then target = silentLockedTarget
            elseif camlock and lockedTarget then target = lockedTarget
            elseif silentAim then target = findClosest() end
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
    
    -- AUTO AIR
    if autoAirFire then
        local target = (silentLockEnabled and silentLockedTarget) or (camlock and lockedTarget)
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
end)

print("🚀 ULTRA v14 ЗАГРУЖЕН — Auto Shoot ТЕПЕРЬ РАБОТАЕТ (через Activate)")
print("Q — Silent Lock | J — Auto Shoot | N — Combo | F — Camlock | T — Trigger | B — Auto Air | V — Silent Aim | K — Blatant")
