--// UNIVERSAL Da Hood / Da Strike / Copies NEVER-MISS Silent Aim 2026 + Auto Air Fire + Trigger Bot (ULTRA v14 — чистая версия)
--// Auto Air (B) работает ТОЛЬКО по залоченному таргету (Silent Lock / Camlock / Combo)
--// Free Auto Air (U) — независимый триггер на прыжки с настраиваемым FOV (меняется клавишами [ / ])
--// Legit Mode (L) → FOV 40 для Trigger Bot и Free Auto Air

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

-- === НАСТРОЙКИ (упрощённые) ===
getgenv().Smoothing = 0.68
getgenv().LegitSmoothing = 0.050
getgenv().BlatantSmoothing = 0.070
getgenv().BasePred = 0.1300
getgenv().MaxPred = 0.1300
getgenv().MinPred = 0.1300
getgenv().PredX = 0.15
getgenv().PredY = 0.15
getgenv().Radius = 235
getgenv().TriggerFOV = 50
getgenv().FreeAutoAirFOV = 27
getgenv().JumpOffsetBase = -0.09
getgenv().airTriggerDelay = 0.15
getgenv().airFireRate = 0
getgenv().TriggerFireRate = 0
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
print("✅ Detected: " .. detectedGame .. " | ULTRA v14 — чистая версия (меню удалено)")

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
local currentPing = 50
local lastAutoFire = 0
local lastTriggerFire = 0
local lastAutoShoot = 0
local lastFreeAutoAirFire = 0
local forceTarget = nil

-- === ANTI‑GROUND ===
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

spawn(function()
    while wait(0.3) do
        local pingItem = Stats.Network.ServerStatsItem["Data Ping"]
        currentPing = pingItem and pingItem:GetValue() or 50
    end
end)

local function getPred(target)
    local base = getgenv().BasePred
    if target and target.Character and LocalPlayer.Character then
        local targetRoot = target.Character:FindFirstChild("HumanoidRootPart")
        local myRoot = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if targetRoot and myRoot then
            local hum = target.Character:FindFirstChild("Humanoid")
            if hum and (hum:GetState() == Enum.HumanoidStateType.Jumping or hum:GetState() == Enum.HumanoidStateType.Freefall) then
                local targetVel = targetRoot.AssemblyLinearVelocity
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

local function getAimPos(plr)
    if not plr or not plr.Character then return Vector3.new() end
    local root = plr.Character:FindFirstChild("HumanoidRootPart")
    if not root then return Vector3.new() end
    
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
    local vel = root.AssemblyLinearVelocity
    local g = WS.Gravity
    local offsetY = 0
    if isAir then
        offsetY = getgenv().JumpOffsetBase   -- только JumpOffset, FallOffset полностью убран
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

-- ========== KEYBINDS (без GUI) ==========
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
    -- GuiKey (M) intentionally removed – no menu to toggle
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
        print("Auto Shoot: "..(autoShoot and "ВКЛ" or "ВЫКЛ"))
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

-- ========== CAMLOCK (без визуальной точки) ==========
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
    -- Точка прицела (dot) полностью удалена
end)

-- ========== ПОИСК ПРЫГАЮЩЕГО В FOV ==========
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

-- ========== АВТОМАТИЧЕСКИЕ ФУНКЦИИ ==========
RunService.Heartbeat:Connect(function()
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
                    hitCount += 1
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
                    hitCount += 1
                end
            end
        end
    end
    
    -- AUTO AIR (B) — ТОЛЬКО ПО ЗАЛОЧЕННОМУ ТАРГЕТУ
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

print("🚀 ULTRA v14 (чистая версия, меню удалено) — Auto Air (B) по локу, Free Auto Air (U) с Legit Mode FOV 40")
print("Q — Silent Lock | J — Auto Shoot | N — Combo | F — Camlock | T — Trigger | B — Auto Air (по залоченному) | V — Silent Aim | K — Blatant | U — Free Auto Air | L — Legit Mode (FOV 40)")
print("✅ FallOffset полностью убран — теперь только JumpOffsetBase для всех воздушных состояний")
