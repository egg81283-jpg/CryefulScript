--[[
    ╔══════════════════════════════════════════════════════════════════╗
    ║  UNIVERSAL Da Hood / Da Strike / Copies                          ║
    ║  ULTRA v14.5 — С КАЛИБРОВКОЙ ПРЕДИКТА (взято из v19.5)           ║
    ║  + Auto Air, Free Auto Air, Legit Mode, Combo Mode и т.д.        ║
    ║  Добавлена автоматическая подстройка предсказания и оффсета в    ║
    ║  воздухе на основе реальных попаданий (оптимизировано под пинг). ║
    ╚══════════════════════════════════════════════════════════════════╝
--]]

getgenv().ResolveKey = "C"
getgenv().CamlockKey = "F"
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
getgenv().IncFreeAutoAirFOVKey = "]"   -- увеличить FOV для Free Auto Air
getgenv().DecFreeAutoAirFOVKey = "["   -- уменьшить FOV для Free Auto Air

-- === НАСТРОЙКИ (можно менять) ===
getgenv().Smoothing = 0.18
getgenv().LegitSmoothing = 0.040
getgenv().BlatantSmoothing = 0.070
-- Базовые параметры предсказания (будут автоматически калиброваться)
getgenv().PredDistFactor = 0.000052
getgenv().PredVelFactor = 0
getgenv().VelSmooth = 0.8
getgenv().airTriggerDelay = 0.15
getgenv().airFireRate = 0
getgenv().TriggerFireRate = 0
getgenv().useHoldMode = false
getgenv().Radius = 235
getgenv().TriggerFOV = 50
getgenv().FreeAutoAirFOV = 27        -- FOV для Free Auto Air (U)
getgenv().JumpOffsetBase = 0.09
getgenv().FallOffsetBase = 0.1
getgenv().AirExtraBoostBase = 0.048
getgenv().AirVelFactor = 0

-- === НАСТРОЙКИ КАЛИБРОВКИ (взяты из v19.5) ===
getgenv().CalibEnabled      = true
getgenv().CalibWindowShots  = 8             -- быстрая адаптация
getgenv().CalibMaxAdj       = 0.008         -- макс. коррекция предсказания
getgenv().CalibStepSmall    = 0.0004
getgenv().CalibStepLarge    = 0.0009
getgenv().AirCalibEnabled   = true
getgenv().AirCalibMaxAdj    = 0.20
getgenv().AirCalibStep      = 0.012

-- ========== СЛУЖЕБНЫЕ ПЕРЕМЕННЫЕ ==========
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

-- ========== ОПРЕДЕЛЕНИЕ РЕМОТА ==========
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
print("✅ Detected: " .. detectedGame .. " | ULTRA v14.5 (с калибровкой)")

-- ========== ИЗМЕРЕНИЕ ПИНГА (v19.5) ==========
local pingBuf = {}
local pingMed = 30   -- по умолчанию

task.spawn(function()
    while task.wait(0.1) do
        local ok, v = pcall(function()
            return Stats.Network.ServerStatsItem["Data Ping"]:GetValue()
        end)
        local p = ok and math.max(0, math.floor(v)) or pingMed
        table.insert(pingBuf, p)
        if #pingBuf > 15 then table.remove(pingBuf, 1) end
        if #pingBuf >= 3 then
            local sorted = {}
            for i, val in ipairs(pingBuf) do sorted[i] = val end
            table.sort(sorted)
            pingMed = sorted[math.ceil(#sorted / 2)]
        end
    end
end)

-- ========== ТАБЛИЦА ПРЕДИКТА (0-200 мс, оптимизирована) ==========
local PRED_TABLE = {}
for ms = 0, 200 do
    local base = 0.13085 + 0.00004 * ms
    local wave = math.sin(ms * 0.05) * 0.0003
    PRED_TABLE[ms + 1] = base + wave
end

local function tablePred(ms)
    ms = math.clamp(ms, 0, 200)
    local idx = math.floor(ms) + 1
    return PRED_TABLE[idx]
end

-- ========== КАЛИБРОВКА ПРЕДИКТА (8 бакетов по 25 мс) ==========
local CALIB_BUCKETS = 8
local predAdj    = {}
local adjDir     = {}
local bucketHR   = {}
local badStreak  = {}
local calibCount = {}

for b = 1, CALIB_BUCKETS do
    predAdj[b]    = 0
    adjDir[b]     = 1
    bucketHR[b]   = 85          -- начальная уверенность
    badStreak[b]  = 0
    calibCount[b] = 0
end

local function pingToBucket(ms)
    return math.clamp(math.floor(ms / 25) + 1, 1, CALIB_BUCKETS)
end

local function updateCalib(bucket, hit)
    if not getgenv().CalibEnabled then return end
    bucketHR[bucket] = bucketHR[bucket] * 0.86 + (hit and 100 or 0) * 0.14
    calibCount[bucket] = calibCount[bucket] + 1
    if calibCount[bucket] < getgenv().CalibWindowShots then return end
    calibCount[bucket] = 0

    local ema = bucketHR[bucket]
    if ema >= 78 then
        badStreak[bucket] = 0
    elseif ema >= 70 then
        predAdj[bucket] = predAdj[bucket] + adjDir[bucket] * getgenv().CalibStepSmall
        badStreak[bucket] = math.max(0, badStreak[bucket] - 1)
    else
        predAdj[bucket] = predAdj[bucket] + adjDir[bucket] * getgenv().CalibStepLarge
        badStreak[bucket] = badStreak[bucket] + 1
        if badStreak[bucket] >= 3 then
            adjDir[bucket]    = -adjDir[bucket]
            badStreak[bucket] = 0
        end
    end
    predAdj[bucket] = math.clamp(predAdj[bucket], -getgenv().CalibMaxAdj, getgenv().CalibMaxAdj)
end

-- ========== КАЛИБРОВКА ВОЗДУХА (4 бинта по скорости Y) ==========
local AIR_BINS = 4
local airAdj   = {0, 0, 0, 0}
local airADir  = {1, 1, -1, -1}
local airHR    = {85, 85, 85, 85}
local airStreak= {0, 0, 0, 0}
local airCount = {0, 0, 0, 0}
local AIR_WIN  = 6

local function velYBin(vy)
    if vy > 15   then return 1 end
    if vy > 2    then return 2 end
    if vy > -15  then return 3 end
    return 4
end

local function updateAirCalib(velY, hit)
    if not getgenv().AirCalibEnabled then return end
    local b = velYBin(velY)
    airHR[b]    = airHR[b] * 0.82 + (hit and 100 or 0) * 0.18
    airCount[b] = airCount[b] + 1
    if airCount[b] < AIR_WIN then return end
    airCount[b] = 0

    local ema = airHR[b]
    if ema >= 76 then
        airStreak[b] = 0
    elseif ema >= 65 then
        airAdj[b]  = airAdj[b] + airADir[b] * getgenv().AirCalibStep * 0.6
        airStreak[b] = math.max(0, airStreak[b] - 1)
    else
        airAdj[b]  = airAdj[b] + airADir[b] * getgenv().AirCalibStep
        airStreak[b] = airStreak[b] + 1
        if airStreak[b] >= 3 then
            airADir[b]   = -airADir[b]
            airStreak[b] = 0
        end
    end
    airAdj[b] = math.clamp(airAdj[b], -getgenv().AirCalibMaxAdj, getgenv().AirCalibMaxAdj)
end

-- ========== ФУНКЦИЯ ПОЛУЧЕНИЯ ОФФСЕТА В ВОЗДУХЕ (с калибровкой) ==========
local function getAirOffset(vy, isJumping)
    local bin  = velYBin(vy)
    local base = (isJumping and getgenv().JumpOffsetBase) or getgenv().FallOffsetBase
    local velEffect = math.abs(vy) * getgenv().AirVelFactor
    local boost = (isJumping and vy > 0) and getgenv().AirExtraBoostBase or 0
    if vy > 22 then boost = boost + (vy - 22) * 0.001 end
    return base + velEffect + boost + airAdj[bin]
end

-- ========== НОВАЯ ФУНКЦИЯ ПРЕДСКАЗАНИЯ (на основе v19.5 + калибровка) ==========
local function getPred(target)
    local bucket = pingToBucket(pingMed)
    local base   = tablePred(pingMed) + predAdj[bucket]

    if target and target.Character and LocalPlayer.Character then
        local tR = target.Character:FindFirstChild("HumanoidRootPart")
        local mR = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if tR and mR then
            local dist   = (tR.Position - mR.Position).Magnitude
            base = base + dist * getgenv().PredDistFactor

            local tV     = tR.AssemblyLinearVelocity
            local mV     = mR.AssemblyLinearVelocity
            local relVel = (tV - mV).Magnitude
            base = base + relVel * getgenv().PredVelFactor
            if relVel > 55 then base = base + (relVel - 55) * 0.0025 end

            local hum = target.Character:FindFirstChild("Humanoid")
            if hum then
                local st = hum:GetState()
                if st == Enum.HumanoidStateType.Jumping or st == Enum.HumanoidStateType.Freefall then
                    base = base + (math.abs(tV.Y) > 12 and 0.0025 or 0.0008)
                end
            end
        end
    end
    -- Ограничиваем, чтобы не выходить за разумные пределы
    return math.clamp(base, 0.128, 0.190)
end

-- ========== ОСТАЛЬНЫЕ ФУНКЦИИ (из v14, но с использованием нового getPred) ==========
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

local lastPos, lastTime, lastVel, velHistory = {}, {}, {}, {}
local airStart = {}
local hitCount = 0
local lastAutoFire = 0
local lastTriggerFire = 0
local lastAutoShoot = 0
local lastFreeAutoAirFire = 0
local forceTarget = nil

-- Логи выстрелов для калибровки
local shotLog    = {}
local totalFired = 0
local totalHits  = 0
local globalHR   = 85

-- === ANTI‑GROUND (из v14) ===
local function isRagdolled(plr)
    if not plr or not plr.Character then return false end
    local hum = plr.Character:FindFirstChild("Humanoid")
    if not hum then return false end
    if hum.Health <= 1 then return true end
    local state = hum:GetState()
    if state == Enum.HumanoidStateType.Ragdoll or state == Enum.HumanoidStateType.Physics then
        return true
    end
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

-- Resolver (упрощённый, из v19.5)
local posHist    = {}
local smoothVel  = {}
local lockState  = {}
local HIST_SIZE  = 32

local function initPl(plr)
    if not posHist[plr] then
        posHist[plr]   = {}
        smoothVel[plr] = Vector3.zero
        lockState[plr] = {rev = 0, lastDir = Vector3.zero}
    end
end

local function pushPos(plr, pos)
    initPl(plr)
    local h = posHist[plr]
    h[#h + 1] = {pos = pos, t = tick()}
    if #h > HIST_SIZE then table.remove(h, 1) end
end

local function getCustomVel(hrp, plr)
    initPl(plr)
    local h = posHist[plr]
    if #h < 3 then return hrp.AssemblyLinearVelocity end

    local sumV, sumW = Vector3.zero, 0
    for i = 2, #h do
        local dt = math.clamp(h[i].t - h[i-1].t, 1/240, 1/20)
        local v  = (h[i].pos - h[i-1].pos) / dt
        local w  = math.exp(0.15 * (i - 1))
        sumV = sumV + v * w; sumW = sumW + w
    end
    local ewa = sumW > 0 and (sumV / sumW) or hrp.AssemblyLinearVelocity

    local ls  = lockState[plr]
    local xzV = Vector3.new(ewa.X, 0, ewa.Z)
    if xzV.Magnitude > 0.5 then
        local dir = xzV.Unit
        if ls.lastDir.Magnitude > 0.5 then
            local dot = math.clamp(dir:Dot(ls.lastDir), -1, 1)
            if dot < -0.25 then
                ls.rev = math.min(ls.rev + 1, 8)
            else
                ls.rev = math.max(ls.rev - 0.4, 0)
            end
        end
        ls.lastDir = dir
    end

    local alpha = math.clamp(1 - getgenv().VelSmooth, 0.04, 0.65)
    smoothVel[plr] = smoothVel[plr]:Lerp(ewa, alpha)
    return smoothVel[plr]
end

-- Функция получения точки прицеливания (с новым предсказанием)
local function getAimPos(plr)
    if not plr or not plr.Character then return Vector3.new() end
    local root = plr.Character:FindFirstChild("HumanoidRootPart")
    if not root then return Vector3.new() end

    pushPos(plr, root.Position)

    local hum = plr.Character:FindFirstChild("Humanoid")
    local isAir = hum and (hum:GetState() == Enum.HumanoidStateType.Jumping or hum:GetState() == Enum.HumanoidStateType.Freefall)
    local partName
    if isAir then
        partName = "Torso"
    else
        partName = blatantMode and "Torso" or "Head"
    end
    local aimPart = plr.Character:FindFirstChild(partName) or root

    local pos = aimPart.Position
    local vel = resolver and getCustomVel(root, plr) or root.AssemblyLinearVelocity
    local g = WS.Gravity

    -- Оффсет по Y в воздухе (с калибровкой)
    local offsetY = 0
    if isAir then
        local jumping = hum:GetState() == Enum.HumanoidStateType.Jumping
        offsetY = getAirOffset(vel.Y, jumping)
    end
    pos = pos + Vector3.new(0, offsetY, 0)

    -- Предсказание (единое время)
    local t = getPred(plr)
    local predXZ = Vector3.new(vel.X * t, 0, vel.Z * t)
    local predY = isAir and (vel.Y * t - 0.5 * g * t * t + (vel.Y > 0 and 0.24 * t or 0)) or (vel.Y * t)

    return pos + predXZ + Vector3.new(0, predY, 0)
end

-- Хуки на инструменты
local function hookTool(tool)
    if not tool:IsA("Tool") then return end
    tool.Activated:Connect(function()
        local target = forceTarget
        if not target and silentLockEnabled and silentLockedTarget then target = silentLockedTarget
        elseif not target and silentAim then target = findClosest() end
        if target and not isRagdolled(target) then
            local aimPos = getAimPos(target)
            MainRemote:FireServer(ShootArg, aimPos)
            hitCount += 1
            -- Запись выстрела для калибровки
            local hum2 = target.Character:FindFirstChild("Humanoid")
            local preHP = hum2 and hum2.Health or 100
            local hrp2 = target.Character:FindFirstChild("HumanoidRootPart")
            local velY = hrp2 and hrp2.AssemblyLinearVelocity.Y or 0
            local inAir = isAir and true or false
            table.insert(shotLog, {
                tm     = tick(),
                tgt    = target,
                hp     = preHP,
                bucket = pingToBucket(pingMed),
                velY   = velY,
                inAir  = inAir,
            })
            if #shotLog > 20 then table.remove(shotLog, 1) end
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
sg.Name = "UniversalNeverMissDH_Calib"
sg.Parent = game.CoreGui
sg.Enabled = true
local fr = Instance.new("Frame", sg)
fr.Size = UDim2.new(0, 520, 0, 540)
fr.Position = UDim2.new(0, 15, 0, 15)
fr.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
fr.Draggable = true
Instance.new("UICorner", fr).CornerRadius = UDim.new(0, 12)
local lbl = Instance.new("TextLabel", fr)
lbl.Size = UDim2.new(1, 0, 1, 0)
lbl.BackgroundTransparency = 1
lbl.TextColor3 = Color3.new(1, 1, 1)
lbl.Font = Enum.Font.Code
lbl.TextSize = 13
lbl.TextXAlignment = Enum.TextXAlignment.Left
lbl.Position = UDim2.new(0, 12, 0, 0)

local dotGui = Instance.new("ScreenGui")
dotGui.Name = "SilentLockDot_Calib"
dotGui.Parent = game.CoreGui
dotGui.ResetOnSpawn = false
local dot = Instance.new("Frame", dotGui)
dot.Size = UDim2.new(0, 9, 0, 9)
dot.AnchorPoint = Vector2.new(0.5, 0.5)
dot.BackgroundColor3 = Color3.new(1, 1, 1)
dot.BorderSizePixel = 0
dot.Visible = false
Instance.new("UICorner", dot).CornerRadius = UDim.new(0, 4)

-- Обновление GUI с отображением калибровки
RunService.Heartbeat:Connect(function()
    local lt = lockedTarget and lockedTarget.Name or "None"
    local slt = silentLockedTarget and silentLockedTarget.Name or "None"
    local isLegitMode = legitSmooth and not blatantMode
    local triggerFOV = isLegitMode and 40 or getgenv().TriggerFOV
    local freeAirFOV = isLegitMode and 40 or getgenv().FreeAutoAirFOV
    local bucket = pingToBucket(pingMed)
    local basePr = tablePred(pingMed)
    local adj    = predAdj[bucket]
    local bHR    = math.floor(bucketHR[bucket])
    local gHR    = totalFired > 0 and string.format("%d%% (%d/%d)", globalHR, totalHits, totalFired) or "—"
    lbl.Text = "Game: "..detectedGame.." | Ping: "..pingMed.."ms | Bucket: "..bucket.."/8\n"..
               "BasePred: "..string.format("%.5f", basePr).."  Adj: "..string.format("%+.5f", adj).."  BktHR: "..bHR.."%\n"..
               "FinalPred: "..string.format("%.5f", basePr + adj).."  GlobalHR: "..gHR.."\n"..
               "AirAdj JF/JS/FS/FF: "..
               string.format("%.3f", airAdj[1]).."/"..string.format("%.3f", airAdj[2]).."/"..
               string.format("%.3f", airAdj[3]).."/"..string.format("%.3f", airAdj[4]).."\n"..
               "Silent: "..(silentAim and "ON (V)" or "OFF").."\n"..
               "Silent Lock: "..(silentLockEnabled and "ON (Q) ["..slt.."]" or "OFF").."\n"..
               "Camlock: "..(camlock and "ON (F) ["..lt.."]" or "OFF").."\n"..
               "Combo Mode: "..(comboMode and "ON (N)" or "OFF").."\n"..
               "Resolver: "..(resolver and "ON (C)" or "OFF").."\n"..
               "Blatant Mode: "..(blatantMode and "ON (K) — Torso" or "OFF — Head").."\n"..
               "Legit Mode: "..(isLegitMode and "ON (FOV 40)" or "OFF").."\n"..
               "Auto Air: "..(autoAirFire and "ON (B) [только по локу]" or "OFF").."\n"..
               "Free Auto Air: "..(freeAutoAir and "ON (U) [FOV "..freeAirFOV.."]" or "OFF").."\n"..
               "Trigger Bot: "..(triggerBot and "ON (T) [FOV "..triggerFOV.."]" or "OFF").."\n"..
               "Auto Shoot: "..(autoShoot and "ON (J) [РАБОТАЕТ!]" or "OFF").."\n"..
               "Hits: "..hitCount
end)

-- ========== KEYBINDS (без изменений) ==========
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
    elseif k == getgenv().FreeAutoAirKey then
        freeAutoAir = not freeAutoAir
        local isLegit = legitSmooth and not blatantMode
        local fov = isLegit and 40 or getgenv().FreeAutoAirFOV
        print("Free Auto Air: "..(freeAutoAir and "ВКЛ (FOV "..fov..", торс)" or "ВЫКЛ"))
    elseif k == getgenv().IncFreeAutoAirFOVKey then
        if not (legitSmooth and not blatantMode) then
            getgenv().FreeAutoAirFOV = math.min(200, getgenv().FreeAutoAirFOV + 5)
            print("📈 Free Auto Air FOV increased to "..getgenv().FreeAutoAirFOV)
        else
            print("⚠️ Cannot change FOV in Legit Mode (fixed at 40). Turn off Legit Mode first.")
        end
    elseif k == getgenv().DecFreeAutoAirFOVKey then
        if not (legitSmooth and not blatantMode) then
            getgenv().FreeAutoAirFOV = math.max(10, getgenv().FreeAutoAirFOV - 5)
            print("📉 Free Auto Air FOV decreased to "..getgenv().FreeAutoAirFOV)
        else
            print("⚠️ Cannot change FOV in Legit Mode (fixed at 40). Turn off Legit Mode first.")
        end
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
        local hum = silentLockedTarget.Character:FindFirstChild("Humanoid")
        local isAir = hum and (hum:GetState() == Enum.HumanoidStateType.Jumping or hum:GetState() == Enum.HumanoidStateType.Freefall)
        local partName = (isAir or blatantMode) and "Torso" or "Head"
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

-- ========== ВСПОМОГАТЕЛЬНАЯ ДЛЯ FREE AUTO AIR ==========
local function findAirTarget(fov)
    local center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    local bestTarget = nil
    local bestDist = fov
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character and not isRagdolled(plr) then
            local hum = plr.Character:FindFirstChild("Humanoid")
            local hrp = plr.Character:FindFirstChild("HumanoidRootPart")
            if hum and hrp and hum.Health > 0 then
                local isAir = (hum:GetState() == Enum.HumanoidStateType.Jumping or hum:GetState() == Enum.HumanoidStateType.Freefall)
                if isAir then
                    local screen, onScreen = Camera:WorldToViewportPoint(hrp.Position)
                    if onScreen then
                        local dist2d = (Vector2.new(screen.X, screen.Y) - center).Magnitude
                        if dist2d < bestDist then
                            bestDist = dist2d
                            bestTarget = plr
                        end
                    end
                end
            end
        end
    end
    return bestTarget
end

-- ========== ОБРАБОТКА ЛОГОВ ВЫСТРЕЛОВ (КАЛИБРОВКА) ==========
RunService.Heartbeat:Connect(function()
    -- Обработка выстрелов из shotLog (аналогично v19.5)
    if #shotLog > 0 then
        local log = shotLog[1]
        if tick() - log.tm >= pingMed / 1000 + 0.07 then
            local hum3  = log.tgt and log.tgt.Character and log.tgt.Character:FindFirstChild("Humanoid")
            local curHP = hum3 and hum3.Health or log.hp
            local hit   = (log.hp - curHP) > 0.3

            updateCalib(log.bucket, hit)

            if log.inAir then
                updateAirCalib(log.velY, hit)
            end

            totalFired = totalFired + 1
            if hit then totalHits = totalHits + 1 end
            globalHR = math.floor(globalHR * 0.92 + (hit and 100 or 0) * 0.08)

            table.remove(shotLog, 1)
        end
    end

    -- ========== АВТОМАТИЧЕСКИЕ ФУНКЦИИ (с учётом калибровки, но логика та же) ==========
    local function isLowHP(target)
        if not target or not target.Character then return true end
        local hum = target.Character:FindFirstChild("Humanoid")
        return not hum or hum.Health <= 1
    end

    -- Сброс замков
    if camlock and lockedTarget and (isLowHP(lockedTarget) or isRagdolled(lockedTarget)) then
        camlock = false; lockedTarget = nil
    end
    if silentLockEnabled and silentLockedTarget and (isLowHP(silentLockedTarget) or isRagdolled(silentLockedTarget)) then
        silentLockEnabled = false; silentLockedTarget = nil
    end

    local isLegitMode = legitSmooth and not blatantMode
    local triggerFOV = isLegitMode and 40 or getgenv().TriggerFOV
    local freeAirFOV = isLegitMode and 40 or getgenv().FreeAutoAirFOV

    -- TRIGGER BOT
    if triggerBot then
        local shouldFire = not getgenv().useHoldMode or UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
        if shouldFire and tick() - lastTriggerFire >= getgenv().TriggerFireRate then
            local target = nil
            if silentLockEnabled and silentLockedTarget then target = silentLockedTarget
            elseif camlock and lockedTarget then target = lockedTarget
            else target = findClosest(triggerFOV) end
            if target and isVisible(target) then
                local tool = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Tool")
                if tool and not isKatana(tool) then
                    forceTarget = target
                    tool:Activate()
                    forceTarget = nil
                    lastTriggerFire = tick()
                    -- Выстрел уже записан в хуке, но чтобы увеличить hitCount дублируем?
                    -- В хуке выстрела уже увеличивается hitCount и добавляется лог. Не нужно дважды.
                end
            end
        end
    end

    -- AUTO SHOOT
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
                end
            end
        end
    end

    -- AUTO AIR (B) — только по залоченному
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
                end
            end
        end
    end
end)

print("🚀 ULTRA v14.5 ЗАГРУЖЕН — добавлена автоматическая калибровка предикта и воздуха (адаптация под ваш пинг и стиль игры)")
print("Q — Silent Lock | J — Auto Shoot | N — Combo | F — Camlock | T — Trigger | B — Auto Air (по залоченному)")
print("V — Silent Aim | K — Blatant | U — Free Auto Air | L — Legit Mode (FOV 40) | C — Resolver")
print("Калибровка включена по умолчанию. Через 8-10 выстрелов вы заметите повышение точности.")
