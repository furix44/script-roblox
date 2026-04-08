-- Créer un ScreenGui qui ne disparaît pas à la mort
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "HandleHiderGui"
screenGui.ResetOnSpawn = false
screenGui.Parent = game.Players.LocalPlayer:WaitForChild("PlayerGui")

-- Créer un bouton stylé
local button = Instance.new("TextButton")
button.Size = UDim2.new(0, 220, 0, 60)
button.Position = UDim2.new(0.5, -110, 0, 20)
button.BackgroundColor3 = Color3.fromRGB(30, 144, 255)
button.BorderSizePixel = 0
button.Text = "Cacher tous les Handle"
button.Font = Enum.Font.GothamBold
button.TextSize = 22
button.TextColor3 = Color3.fromRGB(255, 255, 255)
button.Parent = screenGui

-- Coins arrondis
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 12)
corner.Parent = button

-- Etat
local handlesHidden = false

-- Stocker état initial
local handleStates = {}

local function registerHandle(obj)
    if obj:IsA("BasePart") and obj.Name == "Handle" then
        handleStates[obj] = obj.Transparency

        -- Si déjà en mode caché → on le cache direct
        if handlesHidden and handleStates[obj] == 0 then
            obj.Transparency = 1
        end
    end
end

-- Enregistrer ceux déjà présents
for _, obj in pairs(game:GetDescendants()) do
    registerHandle(obj)
end

-- Détecter les nouveaux Handle
game.DescendantAdded:Connect(function(obj)
    registerHandle(obj)
end)

-- Toggle
local function toggleHandles()
    for obj, initialTransparency in pairs(handleStates) do
        if obj and obj.Parent then
            if not handlesHidden then
                if initialTransparency == 0 then
                    obj.Transparency = 1
                end
            else
                if initialTransparency == 0 then
                    obj.Transparency = 0
                end
            end
        end
    end

    handlesHidden = not handlesHidden

    if handlesHidden then
        button.Text = "Montrer tous les Handle"
    else
        button.Text = "Cacher tous les Handle"
    end
end

button.MouseButton1Click:Connect(toggleHandles)

-- Drag (déplacement)
local dragging = false
local dragInput, mousePos, framePos

button.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true
        mousePos = input.Position
        framePos = button.Position

        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end)

button.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement then
        dragInput = input
    end
end)

game:GetService("UserInputService").InputChanged:Connect(function(input)
    if input == dragInput and dragging then
        local delta = input.Position - mousePos
        button.Position = UDim2.new(
            framePos.X.Scale,
            framePos.X.Offset + delta.X,
            framePos.Y.Scale,
            framePos.Y.Offset + delta.Y
        )
    end
end)
