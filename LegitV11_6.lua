--[[
    GUI ДИЗАЙН + РАБОЧИЙ ESP BOX
    - Чекбокс светится при включении
    - Только Box ESP (без скелета)
    - Профиль игрока + палочка
    - Полная выгрузка при закрытии
]]

local player = game.Players.LocalPlayer
local userInputService = game:GetService("UserInputService")
local players = game:GetService("Players")
local camera = workspace.CurrentCamera
local runService = game:GetService("RunService")

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "LegitMenuGUI"
screenGui.Parent = player:WaitForChild("PlayerGui")
screenGui.ResetOnSpawn = false

-- ========== ESP ЛОГИКА ==========
local espEnabled = false
local espBoxes = {} -- {[Player] = BoxDrawing}
local renderConnection = nil

-- Создаём ESP для одного игрока
local function createESPForPlayer(targetPlayer)
    if targetPlayer == player then return end
    
    local box = Drawing.new("Square")
    box.Visible = false
    box.Color = Color3.fromRGB(255, 0, 0) -- Красный цвет рамки
    box.Thickness = 1.5
    box.Filled = false
    box.Transparency = 0.5
    
    espBoxes[targetPlayer] = box
end

-- Удаляем ESP для игрока
local function removeESPForPlayer(targetPlayer)
    local box = espBoxes[targetPlayer]
    if box then
        box:Remove()
        espBoxes[targetPlayer] = nil
    end
end

-- Обновление всех ESP
local function updateAllESP()
    for targetPlayer, box in pairs(espBoxes) do
        local character = targetPlayer.Character
        local hrp = character and character:FindFirstChild("HumanoidRootPart")
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        
        if character and hrp and humanoid and humanoid.Health > 0 and espEnabled then
            local hrpPos, onScreen = camera:WorldToViewportPoint(hrp.Position)
            
            if onScreen then
                -- Расчёт размера рамки
                local scale = 1 / (hrpPos.Z * math.tan(math.rad(camera.FieldOfView / 2))) * 1000
                local width = scale * 4.5
                local height = scale * 6
                
                -- Ограничение размера
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
        
        -- Очистка если игрок вышел
        if not targetPlayer.Parent then
            removeESPForPlayer(targetPlayer)
        end
    end
end

-- Включение/выключение ESP
local function setESPEnabled(enabled)
    espEnabled = enabled
    
    if enabled then
        if not renderConnection then
            renderConnection = runService.RenderStepped:Connect(updateAllESP)
        end
        -- Показываем все рамки
        for _, box in pairs(espBoxes) do
            box.Visible = true
        end
    else
        if renderConnection then
            renderConnection:Disconnect()
            renderConnection = nil
        end
        -- Скрываем все рамки
        for _, box in pairs(espBoxes) do
            box.Visible = false
        end
    end
end

-- Инициализация ESP для всех игроков
local function initESP()
    for _, targetPlayer in ipairs(players:GetPlayers()) do
        createESPForPlayer(targetPlayer)
    end
end

-- Следим за новыми игроками
players.PlayerAdded:Connect(createESPForPlayer)
players.PlayerRemoving:Connect(removeESPForPlayer)

-- Запускаем инициализацию
initESP()

-- ========== GUI ДИЗАЙН ==========
-- ОСНОВНОЕ ОКНО
local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 500, 0, 350)
mainFrame.Position = UDim2.new(0.5, -250, 0.5, -175)
mainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
mainFrame.BackgroundTransparency = 0
mainFrame.BorderSizePixel = 0
mainFrame.ClipsDescendants = true
mainFrame.Parent = screenGui

local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0, 6)
mainCorner.Parent = mainFrame

-- ВЕРХНЯЯ ПАНЕЛЬ (для перетаскивания)
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

-- Название
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

-- Кнопка закрытия
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

-- ЛИНИЯ РАЗДЕЛИТЕЛЬ
local line = Instance.new("Frame")
line.Size = UDim2.new(1, 0, 0, 1)
line.Position = UDim2.new(0, 0, 0, 30)
line.BackgroundColor3 = Color3.fromRGB(45, 45, 55)
line.BackgroundTransparency = 0
line.BorderSizePixel = 0
line.Parent = mainFrame

-- ЛЕВАЯ ПАНЕЛЬ (только вкладка Legit)
local leftPanel = Instance.new("Frame")
leftPanel.Size = UDim2.new(0, 140, 1, -31)
leftPanel.Position = UDim2.new(0, 0, 0, 31)
leftPanel.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
leftPanel.BackgroundTransparency = 0
leftPanel.BorderSizePixel = 0
leftPanel.Parent = mainFrame

-- Кнопка Legit
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

-- Полоска индикатора
local indicator = Instance.new("Frame")
indicator.Size = UDim2.new(0, 3, 0, 40)
indicator.Position = UDim2.new(0, 0, 0, 10)
indicator.BackgroundColor3 = Color3.fromRGB(255, 170, 0)
indicator.BackgroundTransparency = 0
indicator.BorderSizePixel = 0
indicator.Parent = leftPanel

-- ПРАВАЯ ОБЛАСТЬ
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

-- Заголовок
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

-- Разделитель
local titleLine = Instance.new("Frame")
titleLine.Size = UDim2.new(1, -24, 0, 1)
titleLine.Position = UDim2.new(0, 12, 0, 50)
titleLine.BackgroundColor3 = Color3.fromRGB(45, 45, 55)
titleLine.BackgroundTransparency = 0
titleLine.BorderSizePixel = 0
titleLine.Parent = contentArea

-- КОНТЕЙНЕР ДЛЯ ESP BOX
local espContainer = Instance.new("Frame")
espContainer.Size = UDim2.new(1, -24, 0, 40)
espContainer.Position = UDim2.new(0, 12, 0, 65)
espContainer.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
espContainer.BackgroundTransparency = 0.7
espContainer.BorderSizePixel = 0
espContainer.Parent = contentArea

local espCorner = Instance.new("UICorner")
espCorner.CornerRadius = UDim.new(0, 4)
espCorner.Parent = espContainer

-- Текст ESP Box
local espLabel = Instance.new("TextLabel")
espLabel.Size = UDim2.new(0, 120, 1, 0)
espLabel.Position = UDim2.new(0, 10, 0, 0)
espLabel.BackgroundTransparency = 1
espLabel.Text = "ESP Box"
espLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
espLabel.TextSize = 13
espLabel.TextXAlignment = Enum.TextXAlignment.Left
espLabel.Font = Enum.Font.Gotham
espLabel.Parent = espContainer

-- Чекбокс (кликабельный, светится при включении)
local checkBox = Instance.new("Frame")
checkBox.Size = UDim2.new(0, 18, 0, 18)
checkBox.Position = UDim2.new(1, -30, 0.5, -9)
checkBox.BackgroundColor3 = Color3.fromRGB(45, 45, 55)
checkBox.BackgroundTransparency = 0
checkBox.BorderSizePixel = 0
checkBox.Parent = espContainer

local checkCorner = Instance.new("UICorner")
checkCorner.CornerRadius = UDim.new(0, 3)
checkCorner.Parent = checkBox

-- Внутренняя галочка/свечение
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

-- Статус ESP (включен/выключен)
local espActive = false

-- Функция обновления чекбокса
local function updateCheckbox(active)
    espActive = active
    if active then
        checkLight.BackgroundTransparency = 0
        checkBox.BackgroundColor3 = Color3.fromRGB(255, 170, 0)
        checkBox.BackgroundTransparency = 0.3
    else
        checkLight.BackgroundTransparency = 1
        checkBox.BackgroundColor3 = Color3.fromRGB(45, 45, 55)
        checkBox.BackgroundTransparency = 0
    end
end

-- Клик по чекбоксу
local function toggleESP()
    updateCheckbox(not espActive)
    setESPEnabled(espActive)
end

checkBox.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        toggleESP()
    end
end)

-- ========== ПРОФИЛЬ ИГРОКА (ЛЕВЫЙ НИЖНИЙ УГОЛ) ==========

-- Палочка над профилем
local separator = Instance.new("Frame")
separator.Size = UDim2.new(0, 110, 0, 2)
separator.Position = UDim2.new(0, 15, 1, -58)
separator.BackgroundColor3 = Color3.fromRGB(255, 170, 0)
separator.BackgroundTransparency = 0
separator.BorderSizePixel = 0
separator.Parent = leftPanel

-- Контейнер профиля
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

-- Аватар
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

-- Ник
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

-- Статус
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

-- ========== ЗАКРЫТИЕ GUI (ПОЛНАЯ ВЫГРУЗКА) ==========
local function unloadGUI()
    -- Выключаем ESP
    setESPEnabled(false)
    
    -- Удаляем все боксы
    for _, box in pairs(espBoxes) do
        box:Remove()
    end
    espBoxes = {}
    
    -- Уничтожаем GUI
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

print("GUI загружен | ESP Box РАБОТАЕТ | Чекбокс светится оранжевым при включении")
