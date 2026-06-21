-- Загрузка WindUI
local WindUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/Footagesus/WindUI/main/WindUI.lua"))()

local runService = game:GetService("RunService")
local players = game:GetService("Players")
local localPlayer = players.LocalPlayer
local camera = workspace.CurrentCamera

local espEnabled = false
local espObjects = {}
local lastScan = 0
local SCAN_INTERVAL = 5

-- Создание окна
local Window = WindUI:Window({
    Title = "PHONE ESP PRO",
    Resizable = true,
    Size = UDim2.fromOffset(250, 180),
    Position = UDim2.fromScale(0.1, 0.3)
})

-- Тогл
local espToggle = Window:Toggle({
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

-- Статус
local statusLabel = Window:Label({
    Title = "Ready"
})

-- Функция ESP
local function createESP(obj)
    local espData = { line = Drawing.new("Line"), text = Drawing.new("Text") }
    espData.line.Thickness = 2
    espData.text.Size = 20
    espData.text.Outline = true
    espData.text.Center = true
    return espData
end

-- Основной цикл
runService.RenderStepped:Connect(function()
    if not espEnabled then return end
    
    local myPos = localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart") and localPlayer.Character.HumanoidRootPart.Position or Vector3.new(0,0,0)
    
    if tick() - lastScan > SCAN_INTERVAL then
        lastScan = tick()
        for obj, data in pairs(espObjects) do 
            if data.line then data.line:Remove() end
            if data.text then data.text:Remove() end
        end
        espObjects = {}
        
        for _, obj in pairs(workspace:GetDescendants()) do
            if obj:IsA("Model") and obj.Name:lower():find("iphone") then
                local part = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")
                if part then espObjects[obj] = createESP(obj) end
            end
        end
    end

    local closestDist = math.huge
    local closestName = "NONE"
    
    for obj, data in pairs(espObjects) do
        local part = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")
        if part then
            local dist = (myPos - part.Position).Magnitude
            if dist < closestDist then closestDist = dist; closestName = obj.Name end
            
            local pos, onScreen = camera:WorldToViewportPoint(part.Position)
            local charPos = camera:WorldToViewportPoint(myPos)
            
            data.line.Visible = onScreen
            data.line.From = Vector2.new(charPos.X, charPos.Y)
            data.line.To = Vector2.new(pos.X, pos.Y)
            
            data.text.Visible = onScreen
            data.text.Position = Vector2.new(pos.X, pos.Y - 50)
            data.text.Text = obj.Name .. " (" .. math.floor(dist) .. "m)"
        end
    end
    
    if closestName ~= "NONE" then
        statusLabel:SetTitle(closestName .. ": " .. math.floor(closestDist) .. "m")
    else
        statusLabel:SetTitle("No phones found")
    end
end)
