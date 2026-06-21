-- Загрузка WindUI
local WindUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/Footagesus/WindUI/main/WindUI.lua"))()

local runService = game:GetService("RunService")
local players = game:GetService("Players")
local localPlayer = players.LocalPlayer
local camera = workspace.CurrentCamera

local espEnabled = false
local espObjects = {}

-- Создание окна
local Window = WindUI:Window({
    Title = "PHONE ESP",
    Resizable = true,
    Size = UDim2.fromOffset(250, 150),
    Position = UDim2.fromScale(0.1, 0.3)
})

-- Переключатель
Window:Toggle({
    Title = "Enable ESP",
    Callback = function(state)
        espEnabled = state
        if not espEnabled then
            for _, data in pairs(espObjects) do 
                if data.line then data.line:Remove() end
                if data.text then data.text:Remove() end
            end
            espObjects = {}
        end
    end
})

-- Функция отрисовки
local function createESP(obj)
    local espData = { line = Drawing.new("Line"), text = Drawing.new("Text") }
    espData.line.Thickness = 1.5
    espData.line.Color = Color3.fromRGB(255, 255, 0)
    espData.text.Size = 18
    espData.text.Color = Color3.fromRGB(255, 255, 0)
    espData.text.Outline = true
    espData.text.Center = true
    return espData
end

-- Цикл обновления
runService.RenderStepped:Connect(function()
    if not espEnabled then return end
    
    local character = localPlayer.Character
    if not character then return end
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not rootPart then return end
    
    -- Простой поиск объектов
    for _, obj in pairs(workspace:GetDescendants()) do
        if obj:IsA("Model") and obj.Name:lower():find("iphone") then
            local part = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")
            if part then
                if not espObjects[obj] then
                    espObjects[obj] = createESP(obj)
                end
                
                local pos, onScreen = camera:WorldToViewportPoint(part.Position)
                local charPos = camera:WorldToViewportPoint(rootPart.Position)
                
                local data = espObjects[obj]
                data.line.Visible = onScreen
                data.line.From = Vector2.new(charPos.X, charPos.Y)
                data.line.To = Vector2.new(pos.X, pos.Y)
                
                data.text.Visible = onScreen
                data.text.Position = Vector2.new(pos.X, pos.Y - 20)
                data.text.Text = "iPhone"
            end
        end
    end
end)
