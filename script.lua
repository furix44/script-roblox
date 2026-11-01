
--========================================================
-- ROCKS ADMIN V7
-- LocalScript
-- StarterPlayer > StarterPlayerScripts
--========================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

--========================================================
-- CONFIGURATION
--========================================================

local CONFIG = {
    ROOM_FOLDER = "Rooms",
    ROCKS_FOLDER = "Rocks",
    ROOM_COUNT = 39,

    REFRESH_TIME = 1,
    PREVIEW_REFRESH_TIME = 2,

    MODEL_TP_DISTANCE = 9,
    TP_HEIGHT = 3,

    COLUMNS = 5,

    HOVER_AMPLITUDE = 0.25,
    HOVER_SPEED = 2,
    ROTATION_AMPLITUDE = math.rad(4),

    PREVIEW_SIZE = 58,
}

local COLORS = {
    Background = Color3.fromRGB(18, 17, 27),
    Panel = Color3.fromRGB(27, 25, 39),
    Section = Color3.fromRGB(36, 33, 51),
    Item = Color3.fromRGB(43, 40, 59),

    Accent = Color3.fromRGB(125, 75, 235),
    AccentHover = Color3.fromRGB(155, 105, 255),

    Text = Color3.fromRGB(245, 243, 255),
    Muted = Color3.fromRGB(160, 155, 180),
}

--========================================================
-- DOSSIERS ET ETAT
--========================================================

local roomsFolder = workspace:WaitForChild(CONFIG.ROOM_FOLDER)

local roomData = {}
local activeHoverModels = {}

--========================================================
-- UTILITAIRES
--========================================================

local function corner(parent, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius or 8)
    c.Parent = parent
    return c
end

local function getRoot()
    local character = player.Character
    if not character then return nil end

    return character:FindFirstChild("HumanoidRootPart")
end

local function getModels(room)

    local result = {}

    if not room then
        return result
    end

    local rocks = room:FindFirstChild(CONFIG.ROCKS_FOLDER)

    if not rocks then
        return result
    end

    for _, object in ipairs(rocks:GetDescendants()) do

        if object:IsA("Model") then

            local success = pcall(function()
                object:GetBoundingBox()
            end)

            if success then
                result[object.Name] = result[object.Name] or {}
                table.insert(result[object.Name], object)
            end
        end
    end

    return result
end

local function getModelPosition(model)

    if not model or not model.Parent then
        return nil
    end

    local success, cf = pcall(function()
        return model:GetBoundingBox()
    end)

    if not success then
        return nil
    end

    return cf.Position
end

--========================================================
-- TELEPORTATION DU JOUEUR
--========================================================

local function teleportPlayer(position, lookAtPosition)

    local character = player.Character
    local root = getRoot()

    if not character or not root then
        warn("Personnage indisponible.")
        return false
    end

    local destination = position + Vector3.new(0, CONFIG.TP_HEIGHT, 0)

    local targetCFrame

    if lookAtPosition then

        local flatTarget = Vector3.new(
            lookAtPosition.X,
            destination.Y,
            lookAtPosition.Z
        )

        if (flatTarget - destination).Magnitude > 0.1 then
            targetCFrame = CFrame.lookAt(destination, flatTarget)
        else
            targetCFrame = CFrame.new(destination)
        end

    else
        targetCFrame = CFrame.new(destination)
    end

    character:PivotTo(targetCFrame)

    root.AssemblyLinearVelocity = Vector3.zero
    root.AssemblyAngularVelocity = Vector3.zero

    return true
end

--========================================================
-- TP ROOM : LE JOUEUR VA AU CENTRE
--========================================================

local function teleportToRoom(room)

    if not room then
        return
    end

    local groups = getModels(room)
    local positions = {}

    for _, models in pairs(groups) do
        for _, model in ipairs(models) do

            local position = getModelPosition(model)

            if position then
                table.insert(positions, position)
            end
        end
    end

    if #positions == 0 then
        warn("Aucun modèle dans cette Room.")
        return
    end

    local minimum = positions[1]
    local maximum = positions[1]

    for _, position in ipairs(positions) do

        minimum = Vector3.new(
            math.min(minimum.X, position.X),
            math.min(minimum.Y, position.Y),
            math.min(minimum.Z, position.Z)
        )

        maximum = Vector3.new(
            math.max(maximum.X, position.X),
            math.max(maximum.Y, position.Y),
            math.max(maximum.Z, position.Z)
        )
    end

    local center = (minimum + maximum) / 2

    -- Oriente le joueur vers le modèle le plus proche du centre.
    local nearestPosition = positions[1]
    local nearestDistance = math.huge

    for _, position in ipairs(positions) do

        local distance = (position - center).Magnitude

        if distance < nearestDistance then
            nearestDistance = distance
            nearestPosition = position
        end
    end

    teleportPlayer(center, nearestPosition)
end

--========================================================
-- PART CENTRALE DU MODELE
--========================================================

local function createCenterMarker(model)

    local folder = workspace:FindFirstChild("LocalRockMarkers")

    if not folder then
        folder = Instance.new("Folder")
        folder.Name = "LocalRockMarkers"
        folder.Parent = workspace
    end

    local old = model:FindFirstChild("LocalCenterMarker")

    if old then
        old:Destroy()
    end

    local boxCFrame, boxSize = model:GetBoundingBox()

    local marker = Instance.new("Part")
    marker.Name = "LocalCenterMarker"
    marker.Size = Vector3.new(1.2, 0.2, 1.2)
    marker.Anchored = true
    marker.CanCollide = false
    marker.CanTouch = false
    marker.CanQuery = false
    marker.Material = Enum.Material.Neon
    marker.Color = COLORS.Accent
    marker.Transparency = 0.1

    marker.CFrame = CFrame.new(
        boxCFrame.Position.X,
        boxCFrame.Position.Y - boxSize.Y / 2 - 0.3,
        boxCFrame.Position.Z
    )

    marker.Parent = folder

    local billboard = Instance.new("BillboardGui")
    billboard.Size = UDim2.fromOffset(150, 28)
    billboard.StudsOffset = Vector3.new(0, 1, 0)
    billboard.AlwaysOnTop = true
    billboard.Parent = marker

    local label = Instance.new("TextLabel")
    label.Size = UDim2.fromScale(1, 1)
    label.BackgroundTransparency = 1
    label.Text = model.Name
    label.TextColor3 = COLORS.Text
    label.TextStrokeTransparency = 0.4
    label.TextScaled = true
    label.Font = Enum.Font.GothamBold
    label.Parent = billboard

    return marker
end

--========================================================
-- TP MODELE : LE MODELE VIENT AU JOUEUR
--========================================================

local function teleportToModel(model)

    local root = getRoot()

    if not root then
        warn("Personnage indisponible.")
        return
    end

    if not model or not model.Parent then
        return
    end

    -- Position devant le joueur.
    local targetCFrame =
        root.CFrame
        * CFrame.new(0, 0, -CONFIG.MODEL_TP_DISTANCE)

    -- Déplacement du modèle.
    model:PivotTo(targetCFrame)

    -- Enregistre la position fixe pour l'animation.
    activeHoverModels[model] = {
        baseCFrame = targetCFrame,
        startTime = os.clock(),
        marker = createCenterMarker(model),
    }
end

--========================================================
-- ANIMATION FLOTTANTE
--========================================================

RunService.RenderStepped:Connect(function()

    local now = os.clock()

    for model, data in pairs(activeHoverModels) do

        if not model.Parent then

            if data.marker then
                data.marker:Destroy()
            end

            activeHoverModels[model] = nil

        else

            local elapsed = now - data.startTime

            local hover =
                math.sin(elapsed * CONFIG.HOVER_SPEED)
                * CONFIG.HOVER_AMPLITUDE

            local rotation =
                math.sin(elapsed * 1.5)
                * CONFIG.ROTATION_AMPLITUDE

            local target =
                data.baseCFrame
                * CFrame.new(0, hover, 0)
                * CFrame.Angles(0, rotation, 0)

            model:PivotTo(target)

            if data.marker then

                local boxCFrame, boxSize = model:GetBoundingBox()

                data.marker.CFrame = CFrame.new(
                    boxCFrame.Position.X,
                    boxCFrame.Position.Y - boxSize.Y / 2 - 0.3,
                    boxCFrame.Position.Z
                )
            end
        end
    end
end)

--========================================================
-- PREVISUALISATION 3D
--========================================================

local function createPreview(parent, model)

    local viewport = Instance.new("ViewportFrame")
    viewport.Name = "ModelViewport"
    viewport.Size = UDim2.fromScale(1, 1)
    viewport.BackgroundColor3 = COLORS.Panel
    viewport.BorderSizePixel = 0
    viewport.Parent = parent

    corner(viewport, 8)

    local world = Instance.new("WorldModel")
    world.Parent = viewport

    local camera = Instance.new("Camera")
    camera.Parent = viewport
    viewport.CurrentCamera = camera

    local success, clone = pcall(function()
        return model:Clone()
    end)

    if not success or not clone then
        return viewport
    end

    for _, object in ipairs(clone:GetDescendants()) do

        if object:IsA("Script")
            or object:IsA("LocalScript")
            or object:IsA("ModuleScript")
            or object:IsA("Sound")
            or object:IsA("ParticleEmitter")
            or object:IsA("Beam")
            or object:IsA("Trail") then

            object:Destroy()
        end
    end

    clone.Parent = world
    clone:PivotTo(CFrame.new())

    local boxCFrame, boxSize = clone:GetBoundingBox()

    local largest = math.max(
        boxSize.X,
        boxSize.Y,
        boxSize.Z,
        1
    )

    local distance = largest * 1.8 + 1

    camera.CFrame = CFrame.lookAt(
        boxCFrame.Position + Vector3.new(
            distance,
            distance * 0.65,
            distance
        ),
        boxCFrame.Position
    )

    return viewport
end

local function refreshPreview(container, model)

    local preview = container:FindFirstChild("PreviewContainer")

    if not preview then
        return
    end

    for _, child in ipairs(preview:GetChildren()) do
        child:Destroy()
    end

    createPreview(preview, model)
end

--========================================================
-- INTERFACE
--========================================================

local oldGui = playerGui:FindFirstChild("LocalRocksAdmin")

if oldGui then
    oldGui:Destroy()
end

local gui = Instance.new("ScreenGui")
gui.Name = "LocalRocksAdmin"
gui.ResetOnSpawn = false
gui.DisplayOrder = 50
gui.Parent = playerGui

local openButton = Instance.new("TextButton")
openButton.Size = UDim2.fromOffset(150, 42)
openButton.Position = UDim2.new(0, 20, 0, 100)
openButton.BackgroundColor3 = COLORS.Accent
openButton.Text = "◆  ROCKS ADMIN"
openButton.TextColor3 = COLORS.Text
openButton.TextSize = 13
openButton.Font = Enum.Font.GothamBold
openButton.Parent = gui

corner(openButton, 10)

local panel = Instance.new("Frame")
panel.Name = "MainPanel"
panel.Size = UDim2.fromOffset(390, 520)
panel.Position = UDim2.new(0, 20, 0, 150)
panel.BackgroundColor3 = COLORS.Background
panel.BorderSizePixel = 0
panel.Visible = false
panel.Parent = gui

corner(panel, 14)

local panelStroke = Instance.new("UIStroke")
panelStroke.Color = COLORS.Accent
panelStroke.Transparency = 0.45
panelStroke.Parent = panel

local header = Instance.new("Frame")
header.Size = UDim2.new(1, 0, 0, 65)
header.BackgroundColor3 = COLORS.Panel
header.BorderSizePixel = 0
header.Parent = panel

corner(header, 14)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -60, 0, 28)
title.Position = UDim2.fromOffset(18, 9)
title.BackgroundTransparency = 1
title.Text = "ROCKS MANAGER"
title.TextColor3 = COLORS.Text
title.TextSize = 17
title.Font = Enum.Font.GothamBold
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = header

local subtitle = Instance.new("TextLabel")
subtitle.Size = UDim2.new(1, -60, 0, 18)
subtitle.Position = UDim2.fromOffset(19, 36)
subtitle.BackgroundTransparency = 1
subtitle.Text = "Prévisualisation et téléportation"
subtitle.TextColor3 = COLORS.Muted
subtitle.TextSize = 11
subtitle.Font = Enum.Font.Gotham
subtitle.TextXAlignment = Enum.TextXAlignment.Left
subtitle.Parent = header

local closeButton = Instance.new("TextButton")
closeButton.Size = UDim2.fromOffset(32, 32)
closeButton.Position = UDim2.new(1, -43, 0, 16)
closeButton.BackgroundColor3 = COLORS.Item
closeButton.Text = "×"
closeButton.TextColor3 = COLORS.Text
closeButton.TextSize = 21
closeButton.Font = Enum.Font.GothamBold
closeButton.Parent = header

corner(closeButton, 8)

local scrolling = Instance.new("ScrollingFrame")
scrolling.Name = "RoomsList"
scrolling.Size = UDim2.new(1, -20, 1, -80)
scrolling.Position = UDim2.fromOffset(10, 72)
scrolling.BackgroundTransparency = 1
scrolling.BorderSizePixel = 0
scrolling.ScrollBarThickness = 4
scrolling.ScrollBarImageColor3 = COLORS.Accent
scrolling.AutomaticCanvasSize = Enum.AutomaticSize.Y
scrolling.CanvasSize = UDim2.new()
scrolling.Parent = panel

local mainLayout = Instance.new("UIListLayout")
mainLayout.Padding = UDim.new(0, 9)
mainLayout.SortOrder = Enum.SortOrder.LayoutOrder
mainLayout.Parent = scrolling

openButton.MouseButton1Click:Connect(function()
    panel.Visible = not panel.Visible
end)

closeButton.MouseButton1Click:Connect(function()
    panel.Visible = false
end)

--========================================================
-- CREATION DES SECTIONS ROOM
--========================================================

local function createRoomSection(roomNumber)

    local roomName = "Room_" .. roomNumber

    local section = Instance.new("Frame")
    section.Name = roomName
    section.Size = UDim2.new(1, -5, 0, 48)
    section.BackgroundColor3 = COLORS.Section
    section.BorderSizePixel = 0
    section.ClipsDescendants = true
    section.Parent = scrolling

    corner(section, 10)

    local top = Instance.new("Frame")
    top.Size = UDim2.new(1, 0, 0, 48)
    top.BackgroundTransparency = 1
    top.Parent = section

    local expand = Instance.new("TextButton")
    expand.Size = UDim2.new(1, -100, 1, 0)
    expand.Position = UDim2.fromOffset(10, 0)
    expand.BackgroundTransparency = 1
    expand.Text = "▸  " .. roomName
    expand.TextColor3 = COLORS.Text
    expand.TextSize = 13
    expand.Font = Enum.Font.GothamBold
    expand.TextXAlignment = Enum.TextXAlignment.Left
    expand.Parent = top

    local roomTP = Instance.new("TextButton")
    roomTP.Size = UDim2.fromOffset(80, 30)
    roomTP.Position = UDim2.new(1, -90, 0, 9)
    roomTP.BackgroundColor3 = COLORS.Accent
    roomTP.Text = "TP ROOM"
    roomTP.TextColor3 = COLORS.Text
    roomTP.TextSize = 10
    roomTP.Font = Enum.Font.GothamBold
    roomTP.Parent = top

    corner(roomTP, 7)

    local content = Instance.new("Frame")
    content.Name = "Content"
    content.Size = UDim2.new(1, -16, 0, 0)
    content.Position = UDim2.fromOffset(8, 50)
    content.BackgroundTransparency = 1
    content.AutomaticSize = Enum.AutomaticSize.Y
    content.Parent = section

    local contentLayout = Instance.new("UIListLayout")
    contentLayout.Padding = UDim.new(0, 6)
    contentLayout.SortOrder = Enum.SortOrder.LayoutOrder
    contentLayout.Parent = content

    local data = {
        section = section,
        content = content,
        buttons = {},
        expanded = false,
    }

    expand.MouseButton1Click:Connect(function()

        data.expanded = not data.expanded

        if data.expanded then

            expand.Text = "▾  " .. roomName

            section.Size = UDim2.new(
                1, -5,
                0, 58 + content.AbsoluteSize.Y
            )

        else

            expand.Text = "▸  " .. roomName
            section.Size = UDim2.new(1, -5, 0, 48)

        end
    end)

    roomTP.MouseButton1Click:Connect(function()

        local room = roomsFolder:FindFirstChild(roomName)

        if room then
            teleportToRoom(room)
        else
            warn(roomName .. " introuvable.")
        end
    end)

    return data
end

--========================================================
-- CREATION DES BOUTONS MODELES
--========================================================

local function createModelButton(parent, name, room)

    local container = Instance.new("Frame")
    container.Name = name .. "_Container"
    container.Size = UDim2.new(1, -3, 0, 68)
    container.BackgroundColor3 = COLORS.Item
    container.BorderSizePixel = 0
    container.Parent = parent

    corner(container, 9)

    local preview = Instance.new("Frame")
    preview.Name = "PreviewContainer"
    preview.Size = UDim2.fromOffset(
        CONFIG.PREVIEW_SIZE,
        CONFIG.PREVIEW_SIZE
    )
    preview.Position = UDim2.fromOffset(5, 5)
    preview.BackgroundTransparency = 1
    preview.Parent = container

    local groups = getModels(room)
    local models = groups[name]

    if models and models[1] then
        createPreview(preview, models[1])
    end

    local nameLabel = Instance.new("TextLabel")
    nameLabel.Name = "ModelName"
    nameLabel.Size = UDim2.new(1, -150, 0, 25)
    nameLabel.Position = UDim2.fromOffset(72, 10)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = name
    nameLabel.TextColor3 = COLORS.Text
    nameLabel.TextSize = 11
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.TextXAlignment = Enum.TextXAlignment.Left
    nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
    nameLabel.Parent = container

    local countLabel = Instance.new("TextLabel")
    countLabel.Name = "ModelCount"
    countLabel.Size = UDim2.new(1, -150, 0, 20)
    countLabel.Position = UDim2.fromOffset(72, 34)
    countLabel.BackgroundTransparency = 1
    countLabel.Text = "0 modèle(s)"
    countLabel.TextColor3 = COLORS.Muted
    countLabel.TextSize = 10
    countLabel.Font = Enum.Font.Gotham
    countLabel.TextXAlignment = Enum.TextXAlignment.Left
    countLabel.Parent = container

    local button = Instance.new("TextButton")
    button.Name = "TeleportButton"
    button.Size = UDim2.fromOffset(60, 34)
    button.Position = UDim2.new(1, -68, 0.5, -17)
    button.BackgroundColor3 = COLORS.Accent
    button.Text = "TP"
    button.TextColor3 = COLORS.Text
    button.TextSize = 12
    button.Font = Enum.Font.GothamBold
    button.Parent = container

    corner(button, 8)

    button.MouseEnter:Connect(function()

        TweenService:Create(
            button,
            TweenInfo.new(0.15),
            {BackgroundColor3 = COLORS.AccentHover}
        ):Play()

    end)

    button.MouseLeave:Connect(function()

        TweenService:Create(
            button,
            TweenInfo.new(0.15),
            {BackgroundColor3 = COLORS.Accent}
        ):Play()

    end)

    button.MouseButton1Click:Connect(function()

        local currentRoom = roomsFolder:FindFirstChild(room.Name)

        if not currentRoom then
            return
        end

        local currentGroups = getModels(currentRoom)
        local currentModels = currentGroups[name]

        if currentModels and currentModels[1] then
            teleportToModel(currentModels[1])
        end
    end)

    return container
end

--========================================================
-- ACTUALISATION DES SECTIONS
--========================================================

local function updateRoom(data, roomNumber)

    local roomName = "Room_" .. roomNumber
    local room = roomsFolder:FindFirstChild(roomName)

    if not room then
        return
    end

    local groups = getModels(room)
    local names = {}

    for name in pairs(groups) do
        table.insert(names, name)
    end

    table.sort(names)

    for index, name in ipairs(names) do

        local models = groups[name]
        local container = data.buttons[name]

        if not container then

            container = createModelButton(
                data.content,
                name,
                room
            )

            data.buttons[name] = container
            container:SetAttribute("LastPreviewRefresh", os.clock())

        end

        container.LayoutOrder = index

        local countLabel = container:FindFirstChild("ModelCount")

        if countLabel then
            countLabel.Text = #models .. " modèle(s)"
        end

        -- Actualisation de la miniature toutes les 2 secondes.
        local lastRefresh =
            container:GetAttribute("LastPreviewRefresh") or 0

        if os.clock() - lastRefresh >= CONFIG.PREVIEW_REFRESH_TIME then

            if models[1] then
                refreshPreview(container, models[1])
            end

            container:SetAttribute(
                "LastPreviewRefresh",
                os.clock()
            )
        end
    end

    -- Supprime les entrées qui n'existent plus.
    for name, container in pairs(data.buttons) do

        if not groups[name] then
            container:Destroy()
            data.buttons[name] = nil
        end
    end

    if data.expanded then

        data.section.Size = UDim2.new(
            1, -5,
            0, 58 + data.content.AbsoluteSize.Y
        )
    end
end

--========================================================
-- INITIALISATION DES 39 ROOMS
--========================================================

for roomNumber = 1, CONFIG.ROOM_COUNT do

    local data = createRoomSection(roomNumber)

    data.section.LayoutOrder = roomNumber
    roomData[roomNumber] = data

    updateRoom(data, roomNumber)
end

--========================================================
-- ACTUALISATION AUTOMATIQUE
--========================================================

task.spawn(function()

    while gui.Parent do

        for roomNumber = 1, CONFIG.ROOM_COUNT do

            local data = roomData[roomNumber]

            if data then
                updateRoom(data, roomNumber)
            end
        end

        task.wait(CONFIG.REFRESH_TIME)
    end
end)

print("ROCKS ADMIN V7 chargé.")
