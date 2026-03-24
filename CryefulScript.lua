--// UNIVERSAL Da Hood / Da Strike / Copies — MAXIMUM ACCURACY (Zero Prediction Mode Optional)
--// 🔥 КЛАВИШИ: Camlock = Q, Silent Lock = F, Silent Aim = V, Auto Shoot = J, Trigger = T, Auto Air = B, Aim Assist = U
--// • Zero Prediction Mode: для игр без системы прицеливания (Da Hood, копии) — отключает избыточный предикшн
--// • Универсальный предикшн: учитывает пинг, дистанцию, относительную скорость, состояние в воздухе, ускорение
--// • Триггер бот: рейкаст + FOV, стреляет только при точном наведении
--// • Silent Aim / Auto Shoot: стреляют в предсказанную позицию цели (гарантия попадания)
--// • Auto Air Fire: стрельба по воздушным целям
--// • Игнорирование лежачих (Ragdoll)

getgenv().ResolveKey = "C"
getgenv().CamlockKey = "Q"               -- Изменено: Camlock на Q
getgenv().SilentKey = "V"
getgenv().AutoAirKey = "B"
getgenv().TriggerKey = "T"
getgenv().GuiKey = "M"
getgenv().LegitSmoothKey = "L"
getgenv().BlatantKey = "K"
getgenv().SilentLockKey = "F"            -- Изменено: Silent Lock на F
getgenv().AutoShootKey = "J"
getgenv().ComboKey = "N"
getgenv().AimAssistKey = "U"

-- === НАСТРОЙКИ ===
getgenv().Smoothing = 0.35
getgenv().LegitSmoothing = 0.018
getgenv().BlatantSmoothing = 0.070

-- Режим нулевого предсказания (для Da Hood / копий без системы прицеливания)
getgenv().ZeroPredictionMode = false       -- true: отключает избыточный предикшн, оставляет только пинг+базу
getgenv().BasePred = 0.13021749999999999
getgenv().PredPingFactor = 0.00029
getgenv().PredDistFactor = 0.000052
getgenv().PredVelFactor = 0.0145
getgenv().PredAccelFactor = 0.0025
getgenv().MaxPred = 0.13021749999999999
getgenv().MinPred = 0.13021749999999999

-- Для ZeroPredictionMode используются эти минимальные значения
getgenv().ZeroPredBase = 0.09
getgenv().ZeroPredMax = 0.12
getgenv().ZeroPredMin = 0.07

getgenv().Radius = 235
getgenv().TriggerFOV = 70
getgenv().hitbox_horizontal_size_multiplier = 2.65
getgenv().hitbox_vertical_size_multiplier = 3.15
getgenv().JumpOffsetBase = -0.09
getgenv().FallOffsetBase = -0.10
getgenv().AirExtraBoostBase = 0.048
getgenv().AirVelFactor = 0.00285
getgenv().VelSmooth = 0.78
getgenv().airTriggerDelay = 0.15
getgenv().airFireRate = 0.05
getgenv().TriggerFireRate = 0.022
getgenv().AutoShootFireRate = 0.022
getgenv().useHoldMode = false
getgenv().AutoShootOnlyWhenCrosshair = false

-- === НАСТРОЙКИ AIM ASSIST ===
getgenv().AimAssistFOV = 80
getgenv().AimAssistSmoothing = 0.08
getgenv().AimAssistMaxDistance = 150
getgenv().AimAssistDelay = 0.1

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

print("✅ Detected: " .. detectedGame .. " | ULTRA v18 — ZERO PREDICTION MODE = " .. tostring(getgenv().ZeroPredictionMode))

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
local aimAssist = false

-- Данные для предсказания
local lastPos, lastTime, lastVel, lastAccel, velHistory, accelHistory = {}, {}, {}, {}, {}, {}
local airStart = {}
local hitCount = 0
local currentPing = 50
local lastAutoFire = 0
local lastTriggerFire = 0
local lastAutoShoot = 0
local forceTarget = nil

-- Для AIM ASSIST
local mouseMoved = false
local lastMousePos = UIS:GetMouseLocation()
local assistCooldown = 0

UIS.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement then
        mouseMoved = true
        lastMousePos = UIS:GetMouseLocation()
    end
end)

local function isKatana(tool)
    if not tool then return false end
    local n = tool.Name:lower()
    return n:find("katana") or (tool.ToolTip and tool.ToolTip:lower():find("katana"))
end

local function isTargetValid(plr)
    if not plr or not plr.Character then return false end
    local hum = plr.Character:FindFirstChild("Humanoid")
    if not hum then return false end
    if hum.Health <= 0 then return false end
    local state = hum:GetState()
    if state == Enum.HumanoidStateType.Ragdoll then return false end
    return true
end

local function isVisible(plr)
    if not isTargetValid(plr) then return false end
    if not plr.Character or not LocalPlayer.Character then return false end
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

-- === ГИБКИЙ ПРЕДИКШН (с возможностью нулевого режима) ===
local function getCustomVelAccel(hrp, plr)
    local t = tick()
    if not lastPos[plr] then
        lastPos[plr], lastTime[plr] = hrp.Position, t
        return hrp.AssemblyLinearVelocity, Vector3.new()
    end
    local dt = math.clamp(t - lastTime[plr], 1/240, 1/30)
    local newVel = (hrp.Position - lastPos[plr]) / dt
    local histVel = velHistory[plr] or {}
    table.insert(histVel, newVel)
    if #histVel > 12 then table.remove(histVel, 1) end
    velHistory[plr] = histVel

    local avgVel = #histVel > 1 and (function() local s = Vector3.zero; for _,v in histVel do s += v end; return s/#histVel end)() or newVel
    if lastVel[plr] then avgVel = avgVel:Lerp(lastVel[plr], getgenv().VelSmooth) end

    local newAccel = (avgVel - (lastVel[plr] or avgVel)) / dt
    local histAcc = accelHistory[plr] or {}
    table.insert(histAcc, newAccel)
    if #histAcc > 8 then table.remove(histAcc, 1) end
    accelHistory[plr] = histAcc
    local avgAccel = #histAcc > 1 and (function() local s = Vector3.zero; for _,v in histAcc do s += v end; return s/#histAcc end)() or newAccel

    lastVel[plr], lastPos[plr], lastTime[plr], lastAccel[plr] = avgVel, hrp.Position, t, avgAccel
    return avgVel, avgAccel
end

local function calculatePrediction(plr)
    if not plr or not plr.Character or not LocalPlayer.Character then 
        return getgenv().ZeroPredictionMode and getgenv().ZeroPredBase or getgenv().BasePred 
    end

    local targetRoot = plr.Character:FindFirstChild("HumanoidRootPart")
    local myRoot = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not targetRoot or not myRoot then 
        return getgenv().ZeroPredictionMode and getgenv().ZeroPredBase or getgenv().BasePred 
    end

    if getgenv().ZeroPredictionMode then
        -- Минимальный предикшн: только пинг и базовая константа
        local pingTime = currentPing * 0.001
        local pred = getgenv().ZeroPredBase + pingTime * 1.05
        return math.clamp(pred, getgenv().ZeroPredMin, getgenv().ZeroPredMax)
    end

    -- Полноценный предикшн (для Da Strike и подобных)
    local dist = (targetRoot.Position - myRoot.Position).Magnitude
    local pingTime = currentPing * 0.001

    local vel, accel = getCustomVelAccel(targetRoot, plr)
    local myVel = myRoot.AssemblyLinearVelocity
    local speed = vel.Magnitude
    local relVel = (vel - myVel).Magnitude
    local relAccel = (accel).Magnitude

    local pred = getgenv().BasePred
    pred = pred + (pingTime * 1.05)
    pred = pred + (dist * getgenv().PredDistFactor * 2.1)
    pred = pred + (speed * 0.000135)
    pred = pred + (relVel * getgenv().PredVelFactor * 1.35)
    pred = pred + (relAccel * getgenv().PredAccelFactor)

    if speed > 58 then pred = pred + ((speed - 58) * 0.00115) end
    if relVel > 52 then pred = pred + ((relVel - 52) * 0.00095) end
    if relAccel > 30 then pred = pred + 0.003 end

    local hum = plr.Character:FindFirstChild("Humanoid")
    if hum and (hum:GetState() == Enum.HumanoidStateType.Jumping or hum:GetState() == Enum.HumanoidStateType.Freefall) then
        pred = pred + 0.021
        if math.abs(vel.Y) > 14 then pred = pred + 0.007 end
    end

    local tool = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Tool")
    if tool then
        local weaponName = tool.Name:lower()
        if weaponName:find("sniper") then pred = pred * 1.15
        elseif weaponName:find("pistol") then pred = pred * 0.9
        elseif weaponName:find("ar") or weaponName:find("rifle") then pred = pred * 1.05 end
    end

    if blatantMode then pred = pred * 0.965 end
    return math.clamp(pred, getgenv().MinPred, getgenv().MaxPred)
end

local function getBestTarget(fovRadius, maxDistance)
    local r = fovRadius or getgenv().Radius
    local best = nil
    local bestDist = r
    local center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character then
            if not isTargetValid(plr) then continue end
            local hrp = plr.Character:FindFirstChild("HumanoidRootPart")
            if not hrp then continue end
            if maxDistance and (hrp.Position - Camera.CFrame.Position).Magnitude > maxDistance then continue end
            local screen, onScreen = Camera:WorldToViewportPoint(hrp.Position)
            if onScreen then
                local dist2d = (Vector2.new(screen.X, screen.Y) - center).Magnitude
                if dist2d < bestDist then
                    bestDist = dist2d
                    best = plr
                end
            end
        end
    end
    return best
end

local function findClosest()
    return getBestTarget(getgenv().Radius)
end

local function getAimPos(plr)
    if not plr or not plr.Character then return Vector3.new() end
    local root = plr.Character:FindFirstChild("HumanoidRootPart")
    if not root then return Vector3.new() end

    local partName = blatantMode and "UpperTorso" or "Head"
    local aimPart = plr.Character:FindFirstChild(partName) or root

    local pos = aimPart.Position
    local vel, accel = getCustomVelAccel(root, plr)
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

    local pred = calculatePrediction(plr)

    local predXZ, predY
    if getgenv().ZeroPredictionMode then
        -- В нулевом режиме учитываем только горизонтальную скорость, без ускорения и гравитации
        predXZ = Vector3.new(vel.X * pred, 0, vel.Z * pred)
        predY = vel.Y * pred
    else
        predXZ = Vector3.new(vel.X * pred + 0.5 * accel.X * pred * pred, 0, vel.Z * pred + 0.5 * accel.Z * pred * pred)
        predY = isAir and (vel.Y * pred + 0.5 * accel.Y * pred * pred - 0.5 * g * pred * pred + (vel.Y > 0 and 0.24 * pred or 0)) or (vel.Y * pred + 0.5 * accel.Y * pred * pred)
    end

    local aimPos = pos + predXZ + Vector3.new(0, predY, 0)

    -- Ограничиваем Y в пределах тела (всегда полезно)
    if hum and root then
        local halfHeight = root.Size.Y / 2
        local feetY = root.Position.Y - halfHeight
        local headY = feetY + (hum.HipHeight or 0) + (root.Size.Y * 0.8)
        aimPos = Vector3.new(aimPos.X, math.clamp(aimPos.Y, feetY, headY), aimPos.Z)
    end

    return aimPos
end

local function isCrosshairOnTarget(plr)
    if not isTargetValid(plr) then return false end
    local aimPos = getAimPos(plr)
    local screenPos, onScreen = Camera:WorldToViewportPoint(aimPos)
    if not onScreen then return false end
    local center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    local dist = (Vector2.new(screenPos.X, screenPos.Y) - center).Magnitude
    return dist <= getgenv().TriggerFOV
end

local function silentShoot(target)
    if not target or not isTargetValid(target) then return false end
    if not isVisible(target) then return false end
    local aimPos = getAimPos(target)
    if aimPos == Vector3.new() then return false end
    MainRemote:FireServer(ShootArg, aimPos)
    hitCount += 1
    return true
end

local function triggerShoot(target)
    if not target or not isTargetValid(target) then return false end
    if not isVisible(target) then return false end
    if not isCrosshairOnTarget(target) then return false end
    local tool = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Tool")
    if tool and not isKatana(tool) then
        forceTarget = target
        tool:Activate()
        forceTarget = nil
        hitCount += 1
        return true
    end
    return false
end

local function hookTool(tool)
    if not tool:IsA("Tool") then return end
    tool.Activated:Connect(function()
        local target = forceTarget
        if not target and silentLockEnabled and silentLockedTarget then target = silentLockedTarget
        elseif not target and silentAim then target = getBestTarget(getgenv().Radius) end
        if target and isTargetValid(target) then
            silentShoot(target)
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
sg.Name = "UltimateNeverMiss"
sg.Parent = game.CoreGui
sg.Enabled = true
local fr = Instance.new("Frame", sg)
fr.Size = UDim2.new(0,480,0,480)
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
    local displayPred = getgenv().ZeroPredictionMode and getgenv().ZeroPredBase or getgenv().BasePred
    if lockedTarget then displayPred = calculatePrediction(lockedTarget)
    elseif silentLockedTarget then displayPred = calculatePrediction(silentLockedTarget) end

    lbl.Text = "Game: "..detectedGame.." | ZeroPred="..tostring(getgenv().ZeroPredictionMode).." | PRED: "..string.format("%.4f", displayPred).." | PING: "..currentPing.."ms\n"..
               "Silent: "..(silentAim and "ON (V)" or "OFF").."\n"..
               "Silent Lock: "..(silentLockEnabled and "ON (F) ["..slt.."]" or "OFF").."\n"..
               "Camlock: "..(camlock and "ON (Q) ["..lt.."]" or "OFF").."\n"..
               "Combo Mode: "..(comboMode and "ON (N)" or "OFF").."\n"..
               "Aim Assist: "..(aimAssist and "ON (U) [LEGIT]" or "OFF").."\n"..
               "Resolver: "..(resolver and "ON (C)" or "OFF").."\n"..
               "Blatant Mode: "..(blatantMode and "ON (K) — Torso" or "OFF — Head").."\n"..
               "Auto Air: "..(autoAirFire and "ON (B)" or "OFF").."\n"..
               "Trigger Bot: "..(triggerBot and "ON (T) [CROSSHAIR]" or "OFF").."\n"..
               "Auto Shoot: "..(autoShoot and "ON (J)" or "OFF").."\n"..
               "Hits: "..hitCount
end)

-- ========== KEYBINDS ==========
UIS.InputBegan:Connect(function(input, gp)
    if gp then return end
    local k = input.KeyCode.Name
    if k == getgenv().ResolveKey then resolver = not resolver
    elseif k == getgenv().CamlockKey then  -- Q
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
    elseif k == getgenv().SilentLockKey then  -- F
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
        print("Auto Shoot: "..(autoShoot and "ВКЛ" or "ВЫКЛ"))
    elseif k == getgenv().ComboKey then
        comboMode = not comboMode
        print("Combo Mode: "..(comboMode and "ВКЛ" or "ВЫКЛ"))
    elseif k == getgenv().AimAssistKey then
        aimAssist = not aimAssist
        print("Aim Assist: "..(aimAssist and "ВКЛ (легитное притя
