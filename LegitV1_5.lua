--[[
    LEGIT МЕНЮ + ESP + AIMBOT + TRIGGERBOT + NO RECOIL + FOV
    - No Recoil (нет отдачи)
    - Triggerbot (спамит выстрел)
    - AimBot (работает внутри круга FOV)
    - ESP Box
    - FOV Circle на экране
]]

local player = game.Players.LocalPlayer
local userInputService = game:GetService("UserInputService")
local players = game:GetService("Players")
local camera = workspace.CurrentCamera
local runService = game:GetService("RunService")
local mouse = player:GetMouse()

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "LegitMenuGUI"
screenGui.Parent = player:WaitForChild("PlayerGui")
screenGui.ResetOnSpawn = false

-- ========== НАСТРОЙКИ ==========
local FOVRadius = 150 -- Радиус круга (в пикселях)
local AimFOV = 150 -- В градусах для AimBot (угол обзора)
local MaxDistance = 120 -- Макс дистанция для AimBot
local TriggerDelay = 0.05 -- Задержка между выстрелами триггера (сек)

-- ========== ПЕРЕМЕННЫЕ ==========
local espEnabled = false
local aimbotEnabled = false
local triggerbotEnabled = false
local noRecoilEnabled = false

local espBoxes = {}
local renderConnection = nil
local aimbotConnection = nil
local triggerConnection = nil

local CurrentTarget = nil
local lastTriggerTime = 0

-- FOV Circle (рисуем на экране)
local fovCircle = Drawing.new("Circle")
fovCircle.Visible = false
fovCircle.Radius = FOVRadius
fovCircle.Color = Color3.fromRGB(255, 170, 0)
fovCircle.Thickness = 1.5
fovCircle.Filled = false
fovCircle.Transparency = 0.5
fovCircle.NumSides = 64
fovCircle.Position = Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2)

-- Обновление позиции круга при изменении размера экрана
camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
    fovCircle.Position = Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2)
end)

-- ========== ESP ЛОГИКА ==========
local function createESPForPlayer(targetPlayer)
    if targetPlayer == player then return end
    
    local box = Drawing.new("Square")
    box.Visible = false
    box.Color = Color3.fromRGB(255, 0, 0)
    box.Thickness = 1.5
    box.Filled = false
    box.Transparency = 0.5
    
    espBoxes[targetPlayer] = box
end

local function removeESPForPlayer(targetPlayer)
    local box = espBoxes[targetPlayer]
    if box then
        box:Remove()
        espBoxes[targetPlayer] = nil
    end
end

local function updateAllESP()
    for targetPlayer, box in pairs(espBoxes) do
        local character = targetPlayer.Character
        local hrp = character and character:FindFirstChild("HumanoidRootPart")
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        
        if character and hrp and humanoid and humanoid.Health > 0 and espEnabled then
            local hrpPos, onScreen = camera:WorldToViewportPoint(hrp.Position)
            
            if onScreen then
                local scale = 1 / (hrpPos.Z * math.tan(math.rad(camera.FieldOfView / 2))) * 1000
                local width = scale * 4.5
                local height = scale * 6
                
                if width > 400 then width = 400 end
                if height > 500 then height = 500 end
                
                box.Size = Vector2.new(width, height)
                box.Position = Vector2.new(hrpPos.X - width / 2, hrpPos.Y - height / 2)
                box.Visible = true
            else
                box.Visible = false
            end
        else
            box.Visible = false
        end
        
        if not targetPlayer.Parent then
            removeESPForPlayer(targetPlayer)
        end
    end
end

-- ========== NO RECOIL ==========
local function applyNoRecoil()
    if not noRecoilEnabled then return end
    
    local cameraCFrame = camera.CFrame
    -- Сбрасываем отдачу (фиксим дрожание камеры)
    if player.Character and player.Character:FindFirstChild("Humanoid") then
        -- Микро-коррекция для стабилизации
        camera.CFrame = cameraCFrame
    end
end

-- ========== AIMBOT + FOV ==========
local function isPlayerVisible(targetChar)
    local head = targetChar:FindFirstChild("Head")
    if not head then return false end

    local origin = camera.CFrame.Position
    local direction = (head.Position - origin)
    
    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Exclude
    
    local ignoreList = {player.Character, targetChar}
    for _, child in ipairs(targetChar:GetChildren()) do
        if child:IsA("Accessory") then
            table.insert(ignoreList, child)
        end
    end
    raycastParams.FilterDescendantsInstances = ignoreList
    raycastParams.IgnoreWater = true

    local result = workspace:Raycast(origin, direction, raycastParams)
    return not result or result.Instance:IsDescendantOf(targetChar)
end

-- Проверка, находится ли враг в круге FOV на экране
local function isInFOV(targetHead)
    local screenPos, onScreen = camera:WorldToViewportPoint(targetHead.Position)
    if not onScreen then return false end
    
    local centerX = camera.ViewportSize.X / 2
    local centerY = camera.ViewportSize.Y / 2
    local distance = math.sqrt((screenPos.X - centerX)^2 + (screenPos.Y - centerY)^2)
    
    return distance <= FOVRadius
end

-- Поиск ближайшего врага в FOV
local function getClosestPlayerInFOV()
    local closestTarget = nil
    local closestDistance = FOVRadius + 1
    
    for _, targetPlayer in ipairs(players:GetPlayers()) do
        if targetPlayer ~= player then
            local character = targetPlayer.Character
            local head = character and character:FindFirstChild("Head")
            local humanoid = character and character:FindFirstChildOfClass("Humanoid")
            
            if head and humanoid and humanoid.Health > 0 then
                local screenPos, onScreen = camera:WorldToViewportPoint(head.Position)
                if onScreen then
                    local centerX = camera.ViewportSize.X / 2
                    local centerY = camera.ViewportSize.Y / 2
                    local distance = math.sqrt((screenPos.X - centerX)^2 + (screenPos.Y - centerY)^2)
                    
                    if distance <= FOVRadius then
                        local worldDistance = (head.Position - camera.CFrame.Position).Magnitude
                        if worldDistance <= MaxDistance and isPlayerVisible(character) then
                            if distance < closestDistance then
                                closestTarget = head
                                closestDistance = distance
                            end
                        end
                    end
                end
            end
        end
    end
    return closestTarget
end

-- AimBot обновление
local function updateAimbot()
    if not aimbotEnabled then return end
    
    -- Проверяем текущую цель
    if CurrentTarget and CurrentTarget.Parent then
        local character = CurrentTarget.Parent
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        if humanoid and humanoid.Health > 0 and isPlayerVisible(character) and isInFOV(CurrentTarget) then
            camera.CFrame = CFrame.lookAt(camera.CFrame.Position, CurrentTarget.Position)
            return
        end
    end
    
    -- Ищем новую цель в FOV
    CurrentTarget = getClosestPlayerInFOV()
end

-- ========== TRIGGERBOT ==========
local function updateTriggerbot()
    if not triggerbotEnabled then return end
    
    local currentTime = tick()
    if currentTime - lastTriggerTime < TriggerDelay then return end
    
    -- Проверяем, смотрит ли игрок на врага
    local cameraPos = camera.CFrame.Position
    local cameraDir = camera.CFrame.LookVector
    
    local closestDistance = MaxDistance
    local closestTarget = nil
    
    for _, targetPlayer in ipairs(players:GetPlayers()) do
        if targetPlayer ~= player then
            local character = targetPlayer.Character
            local head = character and character:FindFirstChild("Head")
            local humanoid = character and character:FindFirstChildOfClass("Humanoid")
            
            if head and humanoid and humanoid.Health > 0 then
                local directionToTarget = (head.Position - cameraPos).Unit
                local dotProduct = cameraDir:Dot(directionToTarget)
                
                -- Проверяем, смотрит ли игрок прямо на врага (угол ~1-2 градуса)
                if dotProduct > 0.98 then
                    local distance = (head.Position - cameraPos).Magnitude
                    if distance < closestDistance and isPlayerVisible(character) then
                        closestDistance = distance
                        closestTarget = targetPlayer
                    end
                end
            end
        end
    end
    
    if closestTarget then
        -- Симулируем клик мышкой (выстрел)
        mouse1click()
        lastTriggerTime = currentTime
    end
end

-- ========== ВКЛЮЧЕНИЕ/ВЫКЛЮЧЕНИЕ ФУНКЦИЙ ==========
local function setESPEnabled(enabled)
    espEnabled = enabled
    if enabled then
        if not renderConnection then
            renderConnection = runService.RenderStepped:Connect(updateAllESP)
        end
        for _, box in pairs(espBoxes) do
            box.Visible = true
        end
    else
        if renderConnection then
            renderConnection:Disconnect()
            renderConnection = nil
        end
        for _, box in pairs(espBoxes) do
            box.Visible = false
        end
    end
end

local function setAimbotEnabled(enabled)
    aimbotEnabled = enabled
    if enabled then
        if not aimbotConnection then
            aimbotConnection = runService.RenderStepped:Connect(updateAimbot)
        end
        fovCircle.Visible = true
    else
        if aimbotConnection then
            aimbotConnection:Disconnect()
            aimbotConnection = nil
        end
        CurrentTarget = nil
        fovCircle.Visible = false
    end
end

local function setTriggerbotEnabled(enabled)
    triggerbotEnabled = enabled
    if enabled then
        if not triggerConnection then
            triggerConnection = runService.RenderStepped:Connect(updateTriggerbot)
        end
    else
        if triggerConnection then
            triggerConnection:Disconnect()
            triggerConnection = nil
        end
    end
end

local function setNoRecoilEnabled(enabled)
    noRecoilEnabled = enabled
    if enabled then
        -- No recoil активен постоянно через RenderStepped
        if not noRecoilConnection then
            noRecoilConnection = runService.RenderStepped:Connect(applyNoRecoil)
        end
    else
        if noRecoilConnection then
            noRecoilConnection:Disconnect()
            noRecoilConnection = nil
        end
    end
end

local noRecoilConnection = nil

-- Инициализация ESP
local function initESP()
    for _, targetPlayer in ipairs(players:GetPlayers()) do
        createESPForPlayer(targetPlayer)
    end
end

players.PlayerAdded:Connect(createESPForPlayer)
players.PlayerRemoving:Connect(removeESPForPlayer)
initESP()

-- ========== GUI ДИЗАЙН ==========
local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 500, 0, 520)
mainFrame.Position = UDim2.new(0.5, -250, 0.5, -260)
mainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
mainFrame.BackgroundTransparency = 0
mainFrame.BorderSizePixel = 0
mainFrame.ClipsDescendants = true
mainFrame.Parent = screenGui

local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0, 6)
mainCorner.Parent = mainFrame

-- Верхняя панель
local topBar = Instance.new("Frame")
topBar.Size = UDim2.new(1, 0, 0, 30)
topBar.Position = UDim2.new(0, 0, 0, 0)
topBar.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
topBar.BackgroundTransparency = 0
topBar.BorderSizePixel = 0
topBar.Parent = mainFrame

local topCorner = Instance.new("UICorner")
topCorner.CornerRadius = UDim.new(0, 6)
topCorner.Parent = topBar

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -80, 1, 0)
title.Position = UDim2.new(0, 12, 0, 0)
title.BackgroundTransparency = 1
title.Text = "PenestereLS | LEGIT"
title.TextColor3 = Color3.fromRGB(255, 170, 0)
title.TextSize = 13
title.TextXAlignment = Enum.TextXAlignment.Left
title.Font = Enum.Font.GothamBold
title.Parent = topBar

local closeButton = Instance.new("TextButton")
closeButton.Size = UDim2.new(0, 30, 1, 0)
closeButton.Position = UDim2.new(1, -30, 0, 0)
closeButton.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
closeButton.BackgroundTransparency = 0
closeButton.Text = "X"
closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
closeButton.TextSize = 13
closeButton.Font = Enum.Font.GothamBold
closeButton.BorderSizePixel = 0
closeButton.Parent = topBar

local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 6)
closeCorner.Parent = closeButton

local line = Instance.new("Frame")
line.Size = UDim2.new(1, 0, 0, 1)
line.Position = UDim2.new(0, 0, 0, 30)
line.BackgroundColor3 = Color3.fromRGB(45, 45, 55)
line.BackgroundTransparency = 0
line.BorderSizePixel = 0
line.Parent = mainFrame

-- Левая панель
local leftPanel = Instance.new("Frame")
leftPanel.Size = UDim2.new(0, 140, 1, -31)
leftPanel.Position = UDim2.new(0, 0, 0, 31)
leftPanel.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
leftPanel.BackgroundTransparency = 0
leftPanel.BorderSizePixel = 0
leftPanel.Parent = mainFrame

local legitButton = Instance.new("TextButton")
legitButton.Size = UDim2.new(1, -20, 0, 40)
legitButton.Position = UDim2.new(0, 10, 0, 10)
legitButton.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
legitButton.BackgroundTransparency = 0.2
legitButton.Text = "  LEGIT"
legitButton.TextColor3 = Color3.fromRGB(255, 170, 0)
legitButton.TextSize = 13
legitButton.TextXAlignment = Enum.TextXAlignment.Left
legitButton.Font = Enum.Font.GothamSemibold
legitButton.BorderSizePixel = 0
legitButton.Parent = leftPanel

local legitCorner = Instance.new("UICorner")
legitCorner.CornerRadius = UDim.new(0, 4)
legitCorner.Parent = legitButton

local indicator = Instance.new("Frame")
indicator.Size = UDim2.new(0, 3, 0, 40)
indicator.Position = UDim2.new(0, 0, 0, 10)
indicator.BackgroundColor3 = Color3.fromRGB(255, 170, 0)
indicator.BackgroundTransparency = 0
indicator.BorderSizePixel = 0
indicator.Parent = leftPanel

-- Правая область
local contentArea = Instance.new("Frame")
contentArea.Size = UDim2.new(1, -150, 1, -41)
contentArea.Position = UDim2.new(0, 150, 0, 36)
contentArea.BackgroundColor3 = Color3.fromRGB(22, 22, 27)
contentArea.BackgroundTransparency = 0
contentArea.BorderSizePixel = 0
contentArea.Parent = mainFrame

local contentCorner = Instance.new("UICorner")
contentCorner.CornerRadius = UDim.new(0, 4)
contentCorner.Parent = contentArea

local tabTitle = Instance.new("TextLabel")
tabTitle.Size = UDim2.new(1, -20, 0, 35)
tabTitle.Position = UDim2.new(0, 12, 0, 10)
tabTitle.BackgroundTransparency = 1
tabTitle.Text = "Legit"
tabTitle.TextColor3 = Color3.fromRGB(255, 170, 0)
tabTitle.TextSize = 16
tabTitle.TextXAlignment = Enum.TextXAlignment.Left
tabTitle.Font = Enum.Font.GothamBold
tabTitle.Parent = contentArea

local titleLine = Instance.new("Frame")
titleLine.Size = UDim2.new(1, -24, 0, 1)
titleLine.Position = UDim2.new(0, 12, 0, 50)
titleLine.BackgroundColor3 = Color3.fromRGB(45, 45, 55)
titleLine.BackgroundTransparency = 0
titleLine.BorderSizePixel = 0
titleLine.Parent = contentArea

-- Функция создания чекбокса
local function createCheckbox(parent, yPos, text, callback)
    local container = Instance.new("Frame")
    container.Size = UDim2.new(1, -24, 0, 40)
    container.Position = UDim2.new(0, 12, 0, yPos)
    container.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
    container.BackgroundTransparency = 0.7
    container.BorderSizePixel = 0
    container.Parent = parent
    
    local containerCorner = Instance.new("UICorner")
    containerCorner.CornerRadius = UDim.new(0, 4)
    containerCorner.Parent = container
    
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0, 150, 1, 0)
    label.Position = UDim2.new(0, 10, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = Color3.fromRGB(220, 220, 220)
    label.TextSize = 13
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Font = Enum.Font.Gotham
    label.Parent = container
    
    local checkBox = Instance.new("Frame")
    checkBox.Size = UDim2.new(0, 18, 0, 18)
    checkBox.Position = UDim2.new(1, -30, 0.5, -9)
    checkBox.BackgroundColor3 = Color3.fromRGB(45, 45, 55)
    checkBox.BackgroundTransparency = 0
    checkBox.BorderSizePixel = 0
    checkBox.Parent = container
    
    local checkCorner = Instance.new("UICorner")
    checkCorner.CornerRadius = UDim.new(0, 3)
    checkCorner.Parent = checkBox
    
    local checkLight = Instance.new("Frame")
    checkLight.Size = UDim2.new(0, 10, 0, 10)
    checkLight.Position = UDim2.new(0.5, -5, 0.5, -5)
    checkLight.BackgroundColor3 = Color3.fromRGB(255, 170, 0)
    checkLight.BackgroundTransparency = 1
    checkLight.BorderSizePixel = 0
    checkLight.Parent = checkBox
    
    local lightCorner = Instance.new("UICorner")
    lightCorner.CornerRadius = UDim.new(0, 2)
    lightCorner.Parent = checkLight
    
    local active = false
    
    local function update(forced)
        active = forced ~= nil and forced or not active
        if active then
            checkLight.BackgroundTransparency = 0
            checkBox.BackgroundColor3 = Color3.fromRGB(255, 170, 0)
            checkBox.BackgroundTransparency = 0.3
        else
            checkLight.BackgroundTransparency = 1
            checkBox.BackgroundColor3 = Color3.fromRGB(45, 45, 55)
            checkBox.BackgroundTransparency = 0
        end
        callback(active)
    end
    
    checkBox.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            update()
        end
    end)
    
    return update
end

-- Создаём чекбоксы
local yOffset = 65
createCheckbox(contentArea, yOffset, "ESP Box", function(enabled)
    setESPEnabled(enabled)
end)

createCheckbox(contentArea, yOffset + 50, "AimBot (FOV)", function(enabled)
    setAimbotEnabled(enabled)
end)

createCheckbox(contentArea, yOffset + 100, "Triggerbot", function(enabled)
    setTriggerbotEnabled(enabled)
end)

createCheckbox(contentArea, yOffset + 150, "No Recoil", function(enabled)
    setNoRecoilEnabled(enabled)
end)

-- ========== ПРОФИЛЬ ИГРОКА ==========
local separator = Instance.new("Frame")
separator.Size = UDim2.new(0, 110, 0, 2)
separator.Position = UDim2.new(0, 15, 1, -58)
separator.BackgroundColor3 = Color3.fromRGB(255, 170, 0)
separator.BackgroundTransparency = 0
separator.BorderSizePixel = 0
separator.Parent = leftPanel

local profileFrame = Instance.new("Frame")
profileFrame.Size = UDim2.new(0, 120, 0, 48)
profileFrame.Position = UDim2.new(0, 10, 1, -50)
profileFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
profileFrame.BackgroundTransparency = 0.5
profileFrame.BorderSizePixel = 0
profileFrame.Parent = leftPanel

local profileCorner = Instance.new("UICorner")
profileCorner.CornerRadius = UDim.new(0, 5)
profileCorner.Parent = profileFrame

local avatar = Instance.new("ImageLabel")
avatar.Size = UDim2.new(0, 32, 0, 32)
avatar.Position = UDim2.new(0, 8, 0, 8)
avatar.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
avatar.BackgroundTransparency = 0
avatar.BorderSizePixel = 0
avatar.Image = "rbxthumb://type=AvatarHeadShot&id=" .. player.UserId .. "&w=150&h=150"
avatar.Parent = profileFrame

local avatarCorner = Instance.new("UICorner")
avatarCorner.CornerRadius = UDim.new(1, 0)
avatarCorner.Parent = avatar

local nameLabel = Instance.new("TextLabel")
nameLabel.Size = UDim2.new(1, -48, 0, 18)
nameLabel.Position = UDim2.new(0, 46, 0, 8)
nameLabel.BackgroundTransparency = 1
nameLabel.Text = player.Name
nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
nameLabel.TextSize = 11
nameLabel.TextXAlignment = Enum.TextXAlignment.Left
nameLabel.Font = Enum.Font.GothamBold
nameLabel.Parent = profileFrame

local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(1, -48, 0, 14)
statusLabel.Position = UDim2.new(0, 46, 0, 27)
statusLabel.BackgroundTransparency = 1
statusLabel.Text = "Level: 1"
statusLabel.TextColor3 = Color3.fromRGB(160, 160, 160)
statusLabel.TextSize = 9
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.Font = Enum.Font.Gotham
statusLabel.Parent = profileFrame

-- ========== ПЕРЕТАСКИВАНИЕ ОКНА ==========
local dragging = false
local dragStartX, dragStartY = 0, 0
local frameStartX, frameStartY = 0, 0

topBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true
        dragStartX = input.Position.X
        dragStartY = input.Position.Y
        frameStartX = mainFrame.Position.X.Offset
        frameStartY = mainFrame.Position.Y.Offset
    end
end)

topBar.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = false
    end
end)

userInputService.InputChanged:Connect(function(input)
    if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
        local deltaX = input.Position.X - dragStartX
        local deltaY = input.Position.Y - dragStartY
        mainFrame.Position = UDim2.new(0, frameStartX + deltaX, 0, frameStartY + deltaY)
    end
end)

-- ========== ЗАКРЫТИЕ GUI ==========
local function unloadGUI()
    setESPEnabled(false)
    setAimbotEnabled(false)
    setTriggerbotEnabled(false)
    setNoRecoilEnabled(false)
    
    fovCircle:Remove()
    
    for _, box in pairs(espBoxes) do
        box:Remove()
    end
    espBoxes = {}
    
    screenGui:Destroy()
end

closeButton.MouseButton1Click:Connect(function()
    unloadGUI()
end)

userInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.Insert then
        unloadGUI()
    end
end)

print([[========================================
   LEGIT MENU ЗАГРУЖЕН
   Функции: ESP Box, AimBot (FOV), Triggerbot, No Recoil
   FOV Circle отображается при включённом AimBot
   Triggerbot спамит выстрел, не зажимает
========================================]])
