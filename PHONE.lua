-- ============================================
-- ESP + AUTOBUY (ВЫБОР САМОГО ВЫГОДНОГО, КЛИК ЛКМ, ПРОДАВЕЦ)
-- ============================================

-- Загружаем Fluent
local Fluent = nil
local FluentLoaded = false

local function loadFluent()
    local success, result = pcall(function()
        local source = game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua")
        local func = loadstring(source)
        if func then
            Fluent = func()
            return Fluent
        end
    end)
    if success and result then
        FluentLoaded = true
        print("[Fluent] Загружен с GitHub")
    else
        print("[Fluent] Не удалось загрузить, используем встроенный GUI")
    end
end

loadFluent()

-- ============================================
-- ОСНОВНОЙ КОД
-- ============================================
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local player = Players.LocalPlayer
local espEnabled = true
local autoBuyEnabled = false
local autoBuyCooldown = 2

local FILTER = {
    minPrice = 0,
    maxPrice = 1000,
    minResellMulti = 2,
    excludedQualities = {"Poor", "Worn"},
}

-- ============================================
-- РАБОТА С JSON И ПОИСК ПРЕДМЕТОВ
-- ============================================
local function decodeItemData(jsonString)
    if not jsonString or type(jsonString) ~= "string" then return nil end
    if #jsonString == 0 then return nil end
    local first, last = string.sub(jsonString, 1, 1), string.sub(jsonString, -1)
    if first == "}" and last == "{" then
        jsonString = string.reverse(jsonString)
    end
    local success, data = pcall(function()
        return HttpService:JSONDecode(jsonString)
    end)
    if success and data then
        return data
    else
        return nil
    end
end

local function findJsonInObject(obj)
    local val
    if obj:IsA("StringValue") then
        val = obj.Value
    elseif obj:IsA("ObjectValue") then
        val = tostring(obj.Value)
    elseif obj:IsA("IntValue") or obj:IsA("NumberValue") then
        val = tostring(obj.Value)
    else
        val = obj:GetAttribute("Value")
    end
    if val and type(val) == "string" and string.find(val, "{") then
        local data = decodeItemData(val)
        if data then
            return data
        end
    end
    for key, value in pairs(obj:GetAttributes()) do
        if type(value) == "string" and string.find(value, "{") then
            local data = decodeItemData(value)
            if data then
                return data
            end
        end
    end
    return nil
end

local function isItemRelevant(data)
    local price = tonumber(data.Price or data.ecirP or data["Price"] or data["ecirP"] or 0)
    local resell = tonumber(data.ReSellMulti or data.itluMlleSeR or data["ReSellMulti"] or data["itluMlleSeR"] or 0)
    local quality = data.Quality or data.ytilauQ or data["Quality"] or data["ytilauQ"] or ""
    if quality ~= "" and table.find(FILTER.excludedQualities, quality) then
        return false
    end
    if price < FILTER.minPrice or price > FILTER.maxPrice then
        return false
    end
    if resell < FILTER.minResellMulti then
        return false
    end
    return true
end

local function findAllItems()
    local results = {}
    for _, obj in pairs(workspace:GetDescendants()) do
        local data = findJsonInObject(obj)
        if data then
            if isItemRelevant(data) then
                -- Ищем сам предмет (Model с Pants/Shirt внутри)
                local target = obj
                
                -- Поднимаемся по иерархии до Model
                while target and not (target:IsA("Model") or target:IsA("BasePart")) do
                    target = target.Parent
                    if target == workspace or target == game then
                        target = nil
                        break
                    end
                end
                
                if target then
                    local name = data.Name or data.emaN or data["Name"] or data["emaN"] or "Без названия"
                    local price = tonumber(data.Price or data.ecirP or data["Price"] or data["ecirP"] or 0)
                    local resell = tonumber(data.ReSellMulti or data.itluMlleSeR or data["ReSellMulti"] or data["itluMlleSeR"] or 0)
                    local rarity = data.Rarity or data.ytiraR or data["Rarity"] or data["ytiraR"] or "Common"
                    local itemType = data.Type or data.epyT or data["Type"] or data["epyT"] or ""
                    local quality = data.Quality or data.ytilauQ or data["Quality"] or data["ytilauQ"] or ""
                    table.insert(results, {
                        object = target, -- Сам предмет (Display_Pants_XX)
                        name = tostring(name),
                        price = price,
                        resellMulti = resell,
                        rarity = tostring(rarity),
                        type = tostring(itemType),
                        quality = tostring(quality),
                    })
                end
            end
        end
    end
    return results
end

-- ============================================
-- ESP (без изменений)
-- ============================================
local function clearESP()
    for _, obj in pairs(workspace:GetDescendants()) do
        if obj:FindFirstChild("ESP_Billboard") then
            obj.ESP_Billboard:Destroy()
        end
    end
end

local rarityColors = {
    Common = Color3.fromRGB(255, 255, 255),
    Uncommon = Color3.fromRGB(0, 255, 0),
    Rare = Color3.fromRGB(0, 150, 255),
    Epic = Color3.fromRGB(200, 0, 255),
    Legendary = Color3.fromRGB(255, 180, 0),
    Purple = Color3.fromRGB(200, 0, 255),
}

local function getDistance(obj)
    local char = player.Character
    if not char then return nil end
    local root = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso")
    if not root then return nil end
    local pos
    if obj:IsA("BasePart") then
        pos = obj.Position
    elseif obj:IsA("Model") then
        if obj.PrimaryPart then
            pos = obj.PrimaryPart.Position
        else
            local part = obj:FindFirstChildWhichIsA("BasePart")
            if part then pos = part.Position end
        end
    end
    if not pos then return nil end
    return (root.Position - pos).Magnitude
end

local function createESP(obj, item)
    if not obj or not obj.Parent then return end
    if obj:FindFirstChild("ESP_Billboard") then return end

    local distance = getDistance(obj)
    local distText = distance and string.format("%.0f м", distance) or ""

    local billboard = Instance.new("BillboardGui")
    billboard.Name = "ESP_Billboard"
    billboard.Adornee = obj
    billboard.Size = UDim2.new(0, 300, 0, 70)
    billboard.StudsOffset = Vector3.new(0, 4, 0)
    billboard.AlwaysOnTop = true
    billboard.Parent = obj

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 1, 0)
    frame.BackgroundTransparency = 1
    frame.Parent = billboard

    local nameLabel = Instance.new("TextLabel")
    nameLabel.Size = UDim2.new(1, 0, 0.5, 0)
    nameLabel.Position = UDim2.new(0, 0, 0, 0)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = item.name
    nameLabel.TextColor3 = rarityColors[item.rarity] or Color3.fromRGB(255, 255, 255)
    nameLabel.Font = Enum.Font.SourceSansBold
    nameLabel.TextSize = 16
    nameLabel.TextStrokeTransparency = 0.3
    nameLabel.Parent = frame

    local infoLabel = Instance.new("TextLabel")
    infoLabel.Size = UDim2.new(1, 0, 0.5, 0)
    infoLabel.Position = UDim2.new(0, 0, 0.5, 0)
    infoLabel.BackgroundTransparency = 1
    infoLabel.Text = string.format("[%s]  💰 %d  |  🔄 x%.1f  |  %s", item.type, item.price, item.resellMulti, distText)
    infoLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    infoLabel.Font = Enum.Font.SourceSans
    infoLabel.TextSize = 14
    infoLabel.TextStrokeTransparency = 0.3
    infoLabel.Parent = frame
end

local function updateESP()
    clearESP()
    if not espEnabled then return end
    local items = findAllItems()
    for _, item in pairs(items) do
        createESP(item.object, item)
    end
end

-- ============================================
-- AUTOBUY (ВЫБОР ВЫГОДНОГО, ТЕЛЕПОРТ, КЛИК ЛКМ)
-- ============================================

local ReplicatedStorage = game:GetService("RobloxReplicatedStorage")
local VirtualInputManager = game:GetService("VirtualInputManager")
local Camera = workspace.CurrentCamera

-- Поиск хитбокса (кликабельной части) предмета
local function findItemHitbox(itemObj)
    print("[AutoBuy] 🔍 Поиск хитбокса в объекте: " .. itemObj.Name)
    
    -- ПРИОРИТЕТ 1: Ищем Part/MeshPart с ClickDetector внутри
    for _, child in pairs(itemObj:GetDescendants()) do
        if child:IsA("ClickDetector") then
            local parentPart = child.Parent
            print("[AutoBuy] ✅ Найден ClickDetector! Родитель: " .. parentPart.Name .. " (" .. parentPart.ClassName .. ")")
            return parentPart
        end
    end
    
    -- ПРИОРИТЕТ 2: Ищем MeshPart/Part с именем типа предмета (Shirt, Pants, Hat и т.д.)
    for _, child in pairs(itemObj:GetDescendants()) do
        if child:IsA("MeshPart") or child:IsA("Part") then
            local name = child.Name:lower()
            if name:find("shirt") or name:find("pants") or name:find("hat") or 
               name:find("shoes") or name:find("item") or name:find("clothing") then
                print("[AutoBuy] 🎯 Найден MeshPart предмета: " .. child.Name)
                
                -- Проверяем, есть ли у него ClickDetector
                if child:FindFirstChildOfClass("ClickDetector") then
                    print("[AutoBuy] ✅ У MeshPart есть ClickDetector!")
                end
                
                return child
            end
        end
    end
    
    -- ПРИОРИТЕТ 3: Берем первый MeshPart/Part
    for _, child in pairs(itemObj:GetDescendants()) do
        if child:IsA("MeshPart") or child:IsA("Part") then
            print("[AutoBuy] 🎯 Использую первый MeshPart: " .. child.Name)
            return child
        end
    end
    
    -- ПРИОРИТЕТ 4: Сам объект
    if itemObj:IsA("Model") then
        local part = itemObj.PrimaryPart or itemObj:FindFirstChildWhichIsA("BasePart")
        print("[AutoBuy] 🎯 Использую PrimaryPart модели")
        return part
    elseif itemObj:IsA("BasePart") then
        print("[AutoBuy] 🎯 Объект сам BasePart")
        return itemObj
    end
    
    print("[AutoBuy] ❌ Хитбокс не найден!")
    return nil
end

-- Телепортация к объекту (предмету или продавцу)
local function teleportToObject(targetObj)
    local char = player.Character
    if not char then return false end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return false end
    
    local targetPart = targetObj
    if targetObj:IsA("Model") then
        targetPart = targetObj.PrimaryPart or targetObj:FindFirstChildWhichIsA("BasePart")
    end
    
    if not targetPart or not targetPart:IsA("BasePart") then
        print("[AutoBuy] Не удалось найти позицию для телепорта")
        return false
    end
    
    -- Телепорт ОЧЕНЬ БЛИЗКО к объекту (почти вплотную)
    root.CFrame = CFrame.new(targetPart.Position) * CFrame.new(0, 0, 2)
    task.wait(0.3) -- Увеличил время ожидания
    print("[AutoBuy] Телепорт выполнен к позиции")
    return true
end

-- Метод 1: Клик через VirtualUser (самый надежный для Roblox)
local function clickVirtualUser(targetPart)
    if not targetPart then return false end
    
    pcall(function()
        -- Получаем позицию на экране
        local targetPos = targetPart.Position
        local screenPos, onScreen = Camera:WorldToViewportPoint(targetPos)
        
        if onScreen then
            -- VirtualUser клик
            game:GetService("VirtualUser"):Button1Down(Vector2.new(screenPos.X, screenPos.Y))
            task.wait(0.1)
            game:GetService("VirtualUser"):Button1Up(Vector2.new(screenPos.X, screenPos.Y))
            print("[AutoBuy] VirtualUser клик выполнен")
        else
            -- Если не на экране, просто жмем по центру
            game:GetService("VirtualUser"):Button1Down(Vector2.new(500, 500))
            task.wait(0.1)
            game:GetService("VirtualUser"):Button1Up(Vector2.new(500, 500))
        end
    end)
    
    return true
end

-- Метод 2: mouse1press/mouse1release
local function clickMousePress(targetPart)
    if not targetPart then return false end
    
    pcall(function()
        mouse1press()
        task.wait(0.1)
        mouse1release()
        print("[AutoBuy] mouse1press/release выполнен")
    end)
    
    return true
end

-- Метод 2.5: Эмуляция UserInputService клика
local function clickUserInput(targetPart)
    if not targetPart then return false end
    
    pcall(function()
        local targetPos = targetPart.Position
        local screenPos = Camera:WorldToViewportPoint(targetPos)
        
        -- Эмулируем ввод через VirtualInputManager
        VirtualInputManager:SendMouseButtonEvent(screenPos.X, screenPos.Y, 0, true, game, 0)
        task.wait(0.1)
        VirtualInputManager:SendMouseButtonEvent(screenPos.X, screenPos.Y, 0, false, game, 0)
        print("[AutoBuy] VirtualInputManager клик выполнен")
    end)
    
    return true
end

-- Метод 3: ClickDetector (УСИЛЕННАЯ ВЕРСИЯ)
local function clickDetector(targetPart)
    if not targetPart then return false end
    
    local detector = nil
    
    -- Ищем ClickDetector прямо в targetPart
    if targetPart:FindFirstChildOfClass("ClickDetector") then
        detector = targetPart:FindFirstChildOfClass("ClickDetector")
        print("[AutoBuy] ✅ ClickDetector найден в самом объекте")
    else
        -- Ищем в потомках
        for _, child in pairs(targetPart:GetDescendants()) do
            if child:IsA("ClickDetector") then
                detector = child
                print("[AutoBuy] ✅ ClickDetector найден в потомке: " .. child.Parent.Name)
                break
            end
        end
    end
    
    if detector then
        -- Пробуем ВСЕ способы вызова ClickDetector
        pcall(function()
            fireclickdetector(detector)
        end)
        task.wait(0.05)
        
        pcall(function()
            fireclickdetector(detector, 0)
        end)
        task.wait(0.05)
        
        pcall(function()
            detector:FireClick(player)
        end)
        task.wait(0.05)
        
        pcall(function()
            detector.Parent.ClickDetector.MouseClick:Fire(player)
        end)
        
        print("[AutoBuy] ✅ ClickDetector активирован всеми методами")
        return true
    else
        print("[AutoBuy] ⚠️ ClickDetector не найден")
    end
    
    return false
end

-- Метод 4: ProximityPrompt (если есть)
local function clickProximity(targetPart)
    if not targetPart then return false end
    
    local prompt = nil
    
    if targetPart:FindFirstChildOfClass("ProximityPrompt") then
        prompt = targetPart:FindFirstChildOfClass("ProximityPrompt")
    else
        for _, child in pairs(targetPart:GetDescendants()) do
            if child:IsA("ProximityPrompt") then
                prompt = child
                break
            end
        end
    end
    
    if prompt then
        pcall(function()
            fireproximityprompt(prompt)
        end)
        print("[AutoBuy] Клик через ProximityPrompt")
        return true
    end
    
    return false
end

-- Универсальная функция клика (пробует ВСЕ методы + DataRemoteEvent)
local function clickObject(targetObj)
    local targetPart = findItemHitbox(targetObj)
    if not targetPart then
        print("[AutoBuy] ❌ Не найден хитбокс объекта")
        return false
    end
    
    print("[AutoBuy] 🎯 Попытка клика по: " .. targetPart.Name)
    print("[AutoBuy] 📍 Позиция: " .. tostring(targetPart.Position))
    
    -- ГЛАВНЫЙ МЕТОД: DataRemoteEvent (ИСПРАВЛЕННАЯ ВЕРСИЯ)
    local success = pcall(function()
        local dataRemote = game:GetService("ReplicatedStorage"):FindFirstChild("DataRemoteEvent")
        if dataRemote then
            -- Проверяем, что объект существует в workspace
            if not targetObj or not targetObj.Parent then
                print("[AutoBuy] ⚠️ Объект предмета не найден в workspace")
                return false
            end
            
            -- Формируем аргументы точно как в Remote Spy
            local args = {
                {
                    "\003",  -- Код команды взятия предмета
                    {
                        targetObj,  -- Сам объект (Display_Pants_15 и т.д.)
                        n = 1
                    }
                }
            }
            
            print("[AutoBuy] 📡 Отправляю DataRemoteEvent для: " .. targetObj.Name)
            print("[AutoBuy] 📍 Полный путь: " .. targetObj:GetFullName())
            
            dataRemote:FireServer(unpack(args))
            print("[AutoBuy] ✅ DataRemoteEvent отправлен успешно!")
            return true
        else
            print("[AutoBuy] ❌ DataRemoteEvent не найден в ReplicatedStorage")
            return false
        end
    end)
    
    if not success then
        print("[AutoBuy] ❌ Ошибка при отправке DataRemoteEvent")
    end
    
    task.wait(0.3)
    
    -- Резервные методы на случай, если RemoteEvent не сработал
    
    -- Наводим камеру на объект
    local targetPos = targetPart.Position
    Camera.CFrame = CFrame.new(Camera.CFrame.Position, targetPos)
    task.wait(0.3)
    
    print("[AutoBuy] �️ Пробую резервные методы клика...")
    
    -- МЕТОД 1: VirtualUser
    clickVirtualUser(targetPart)
    task.wait(0.2)
    
    -- МЕТОД 2: VirtualInputManager
    clickUserInput(targetPart)
    task.wait(0.2)
    
    -- МЕТОД 3: mouse1press/release
    clickMousePress(targetPart)
    task.wait(0.2)
    
    -- МЕТОД 4: mouse1click
    pcall(function()
        mouse1click()
    end)
    print("[AutoBuy] 🖱️ mouse1click выполнен")
    
    print("[AutoBuy] ✅ Все методы выполнены")
    return true
end

-- Поиск модели продавца "buy"
local function findBuySeller()
    -- Ищем точное совпадение "buy"
    local seller = workspace:FindFirstChild("buy")
    if seller then
        print("[AutoBuy] Найден продавец 'buy'")
        return seller
    end
    
    -- Ищем в потомках workspace
    for _, obj in pairs(workspace:GetDescendants()) do
        if obj.Name:lower() == "buy" then
            print("[AutoBuy] Найден продавец 'buy' в потомках")
            return obj
        end
    end
    
    -- Ищем модели с названиями, похожими на продавца
    for _, obj in pairs(workspace:GetDescendants()) do
        local name = obj.Name:lower()
        if name:find("buy") or name:find("seller") or name:find("cashier") or name:find("npc") then
            print("[AutoBuy] Найден возможный продавец: " .. obj.Name)
            return obj
        end
    end
    
    print("[AutoBuy] Продавец не найден")
    return nil
end

-- Основной цикл автобая
local function autoBuyCycle()
    if not autoBuyEnabled then return end
    
    -- 1. Находим все подходящие предметы
    local items = findAllItems()
    if #items == 0 then
        print("[AutoBuy] Нет подходящих предметов в ESP")
        return
    end
    
    -- 2. Выбираем самый выгодный (множитель / цена)
    table.sort(items, function(a, b)
        local profitA = a.resellMulti / math.max(a.price, 1)
        local profitB = b.resellMulti / math.max(b.price, 1)
        return profitA > profitB
    end)
    
    local bestItem = items[1]
    print(string.format("[AutoBuy] ✅ Выбран предмет: %s (💰 %d, 🔄 x%.1f)", 
        bestItem.name, bestItem.price, bestItem.resellMulti))
    print("[AutoBuy] 📦 Объект: " .. bestItem.object.Name .. " (" .. bestItem.object.ClassName .. ")")
    
    -- 3. Телепортируемся к предмету
    if not teleportToObject(bestItem.object) then
        print("[AutoBuy] ❌ Не удалось телепортироваться к предмету")
        return
    end
    
    -- 4. Кликаем ЛКМ по предмету
    print("[AutoBuy] 🖱️ Клик ЛКМ по предмету...")
    
    if not clickObject(bestItem.object) then
        print("[AutoBuy] ❌ Не удалось кликнуть по предмету")
        return
    end
    
    task.wait(0.7) -- Ждем добавления в корзину
    
    -- 5. Находим продавца "buy"
    local seller = findBuySeller()
    if not seller then
        print("[AutoBuy] ❌ Продавец 'buy' не найден")
        return
    end
    
    -- 6. Телепортируемся к продавцу
    if not teleportToObject(seller) then
        print("[AutoBuy] ❌ Не удалось телепортироваться к продавцу")
        return
    end
    
    -- 7. Кликаем ЛКМ по продавцу
    print("[AutoBuy] 🖱️ Клик ЛКМ по продавцу...")
    if not clickObject(seller) then
        print("[AutoBuy] ❌ Не удалось кликнуть по продавцу")
        return
    end
    
    task.wait(0.5)
    
    -- 8. Пытаемся отправить RemoteEvent (если нужно)
    pcall(function()
        local bulkEvent = ReplicatedStorage:FindFirstChild("ServerSideBulkPurchaseEvent")
        if bulkEvent and bulkEvent:IsA("RemoteEvent") then
            bulkEvent:FireServer()
            print("[AutoBuy] 📡 Отправлен ServerSideBulkPurchaseEvent")
        end
    end)
    
    print("[AutoBuy] ✅ Цикл завершен успешно\n")
end

local autoBuyThread = nil
local function startAutoBuy()
    if autoBuyThread then return end
    autoBuyThread = task.spawn(function()
        while autoBuyEnabled do
            autoBuyCycle()
            task.wait(autoBuyCooldown)
        end
        autoBuyThread = nil
    end)
end

local function stopAutoBuy()
    autoBuyEnabled = false
    if autoBuyThread then
        task.cancel(autoBuyThread)
        autoBuyThread = nil
    end
end

-- ============================================
-- GUI (FLUENT или встроенный)
-- ============================================
local function createFluentGUI()
    if not FluentLoaded then
        createSimpleGUI()
        return
    end

    local Window = Fluent:CreateWindow({
        Title = "ESP + AutoBuy",
        SubTitle = "by YourName",
        TabWidth = 160,
        Size = UDim2.fromOffset(450, 400),
        Acrylic = false,
        Theme = "Dark",
        MinimizeKey = Enum.KeyCode.LeftControl,
    })

    local MainTab = Window:AddTab({ Title = "Фильтры", Icon = "settings" })

    MainTab:AddToggle("ESP", {
        Title = "Включить ESP",
        Default = espEnabled,
        Callback = function(v)
            espEnabled = v
            clearESP()
            if espEnabled then updateESP() end
        end
    })

    MainTab:AddParagraph({
        Title = "💰 Цена",
        Content = "",
    })

    MainTab:AddInput("MinPrice", {
        Title = "Цена ОТ",
        Default = tostring(FILTER.minPrice),
        Placeholder = "0",
        Numeric = true,
        Finished = true,
        Callback = function(v)
            local num = tonumber(v)
            if num then
                FILTER.minPrice = num
                if espEnabled then updateESP() end
            end
        end
    })

    MainTab:AddInput("MaxPrice", {
        Title = "Цена ДО",
        Default = tostring(FILTER.maxPrice),
        Placeholder = "1000",
        Numeric = true,
        Finished = true,
        Callback = function(v)
            local num = tonumber(v)
            if num then
                FILTER.maxPrice = num
                if espEnabled then updateESP() end
            end
        end
    })

    MainTab:AddParagraph({
        Title = "🔄 Множитель перепродажи",
        Content = "",
    })

    MainTab:AddInput("Resell", {
        Title = "ReSellMulti ОТ",
        Default = tostring(FILTER.minResellMulti),
        Placeholder = "2.0",
        Numeric = true,
        Finished = true,
        Callback = function(v)
            local num = tonumber(v)
            if num then
                FILTER.minResellMulti = num
                if espEnabled then updateESP() end
            end
        end
    })

    MainTab:AddParagraph({
        Title = "🎯 Авто-покупка",
        Content = "",
    })

    MainTab:AddToggle("AutoBuy", {
        Title = "Включить AutoBuy",
        Default = autoBuyEnabled,
        Callback = function(v)
            autoBuyEnabled = v
            if v then
                startAutoBuy()
            else
                stopAutoBuy()
            end
        end
    })

    MainTab:AddButton({
        Title = "Выполнить одну итерацию AutoBuy",
        Callback = function()
            if autoBuyEnabled then
                autoBuyCycle()
            else
                print("[AutoBuy] Включите AutoBuy сначала")
            end
        end
    })

    MainTab:AddButton({
        Title = "Обновить ESP",
        Callback = function()
            if espEnabled then updateESP() end
        end
    })
end

-- ============================================
-- ПРОСТОЙ ВСТРОЕННЫЙ GUI (если Fluent не загружен)
-- ============================================
function createSimpleGUI()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "ESPSettings"
    screenGui.Parent = player:WaitForChild("PlayerGui")

    local mainFrame = Instance.new("Frame")
    mainFrame.Size = UDim2.new(0, 300, 0, 350)
    mainFrame.Position = UDim2.new(0.5, -150, 0.3, 0)
    mainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
    mainFrame.BorderSizePixel = 0
    mainFrame.Parent = screenGui
    Instance.new("UICorner").CornerRadius = UDim.new(0, 8)
    Instance.new("UICorner").Parent = mainFrame

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0, 40)
    title.BackgroundTransparency = 1
    title.Text = "⚙️ ESP + AutoBuy"
    title.TextColor3 = Color3.fromRGB(255,255,255)
    title.Font = Enum.Font.SourceSansBold
    title.TextSize = 20
    title.Parent = mainFrame

    local function createInput(y, labelText, placeholder, callback)
        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(0.4, 0, 0, 25)
        lbl.Position = UDim2.new(0, 10, 0, y)
        lbl.BackgroundTransparency = 1
        lbl.Text = labelText
        lbl.TextColor3 = Color3.fromRGB(200,200,200)
        lbl.Font = Enum.Font.SourceSans
        lbl.TextSize = 14
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Parent = mainFrame

        local box = Instance.new("TextBox")
        box.Size = UDim2.new(0.4, 0, 0, 25)
        box.Position = UDim2.new(0.55, 0, 0, y)
        box.BackgroundColor3 = Color3.fromRGB(50,50,60)
        box.BorderSizePixel = 0
        box.TextColor3 = Color3.fromRGB(255,255,255)
        box.Font = Enum.Font.SourceSans
        box.TextSize = 14
        box.PlaceholderText = placeholder
        box.Text = ""
        box.Parent = mainFrame
        Instance.new("UICorner").CornerRadius = UDim.new(0, 4)
        Instance.new("UICorner").Parent = box
        box.FocusLost:Connect(function()
            local num = tonumber(box.Text)
            if num then callback(num) end
        end)
        return box
    end

    local minBox = createInput(50, "Цена ОТ:", "0", function(v) FILTER.minPrice = v; if espEnabled then updateESP() end end)
    local maxBox = createInput(85, "Цена ДО:", "1000", function(v) FILTER.maxPrice = v; if espEnabled then updateESP() end end)
    local resBox = createInput(120, "ReSellMulti ОТ:", "2.0", function(v) FILTER.minResellMulti = v; if espEnabled then updateESP() end end)

    minBox.Text = tostring(FILTER.minPrice)
    maxBox.Text = tostring(FILTER.maxPrice)
    resBox.Text = tostring(FILTER.minResellMulti)

    local toggleBtn = Instance.new("TextButton")
    toggleBtn.Size = UDim2.new(0.8, 0, 0, 35)
    toggleBtn.Position = UDim2.new(0.1, 0, 0, 170)
    toggleBtn.BackgroundColor3 = Color3.fromRGB(0,200,0)
    toggleBtn.BorderSizePixel = 0
    toggleBtn.Text = "ESP ВКЛ"
    toggleBtn.TextColor3 = Color3.fromRGB(255,255,255)
    toggleBtn.Font = Enum.Font.SourceSansBold
    toggleBtn.TextSize = 16
    toggleBtn.Parent = mainFrame
    Instance.new("UICorner").CornerRadius = UDim.new(0, 5)
    Instance.new("UICorner").Parent = toggleBtn

    toggleBtn.MouseButton1Click:Connect(function()
        espEnabled = not espEnabled
        toggleBtn.BackgroundColor3 = espEnabled and Color3.fromRGB(0,200,0) or Color3.fromRGB(200,0,0)
        toggleBtn.Text = espEnabled and "ESP ВКЛ" or "ESP ВЫКЛ"
        clearESP()
        if espEnabled then updateESP() end
    end)

    local autoBtn = Instance.new("TextButton")
    autoBtn.Size = UDim2.new(0.8, 0, 0, 35)
    autoBtn.Position = UDim2.new(0.1, 0, 0, 215)
    autoBtn.BackgroundColor3 = Color3.fromRGB(100,100,100)
    autoBtn.BorderSizePixel = 0
    autoBtn.Text = "AutoBuy ВЫКЛ"
    autoBtn.TextColor3 = Color3.fromRGB(255,255,255)
    autoBtn.Font = Enum.Font.SourceSansBold
    autoBtn.TextSize = 16
    autoBtn.Parent = mainFrame
    Instance.new("UICorner").CornerRadius = UDim.new(0, 5)
    Instance.new("UICorner").Parent = autoBtn

    autoBtn.MouseButton1Click:Connect(function()
        autoBuyEnabled = not autoBuyEnabled
        autoBtn.BackgroundColor3 = autoBuyEnabled and Color3.fromRGB(0,200,0) or Color3.fromRGB(100,100,100)
        autoBtn.Text = autoBuyEnabled and "AutoBuy ВКЛ" or "AutoBuy ВЫКЛ"
        if autoBuyEnabled then
            startAutoBuy()
        else
            stopAutoBuy()
        end
    end)

    local refreshBtn = Instance.new("TextButton")
    refreshBtn.Size = UDim2.new(0.8, 0, 0, 35)
    refreshBtn.Position = UDim2.new(0.1, 0, 0, 260)
    refreshBtn.BackgroundColor3 = Color3.fromRGB(60,60,80)
    refreshBtn.BorderSizePixel = 0
    refreshBtn.Text = "Обновить ESP"
    refreshBtn.TextColor3 = Color3.fromRGB(255,255,255)
    refreshBtn.Font = Enum.Font.SourceSansBold
    refreshBtn.TextSize = 16
    refreshBtn.Parent = mainFrame
    Instance.new("UICorner").CornerRadius = UDim.new(0, 5)
    Instance.new("UICorner").Parent = refreshBtn
    refreshBtn.MouseButton1Click:Connect(function()
        if espEnabled then updateESP() end
    end)

    print("[GUI] Простой интерфейс создан (Fluent не загружен)")
end

-- ============================================
-- ЗАПУСК
-- ============================================
createFluentGUI()
updateESP()

while wait(2) do
    if espEnabled then
        updateESP()
    end
endnnect(function()
        if espEnabled then updateESP() end
    end)

    print("[GUI] Простой интерфейс создан (Fluent не загружен)")
end

-- ============================================
-- ЗАПУСК
-- ============================================
createFluentGUI()
updateESP()

while wait(2) do
    if espEnabled then
        updateESP()
    end
end
