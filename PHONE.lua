-- ============================================
-- ESP + AUTOBUY + AUTOSELL
-- Made by: Firma Mode Hub
-- Telegram: @Firma Mode Hub
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
local autoSellEnabled = false
-- autoBuyCooldown удалена - теперь без задержек!

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
-- ESP (с автоудалением купленных предметов)
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

-- Слушаем удаление объектов из workspace для автоматического обновления ESP
workspace.DescendantRemoving:Connect(function(descendant)
    -- Если удаляется объект с ESP, обновляем весь ESP через короткую задержку
    if descendant:FindFirstChild("ESP_Billboard") or descendant.Name:find("Display_") then
        task.wait(0.1)
        if espEnabled then
            updateESP()
        end
    end
end)

-- ============================================
-- AUTOBUY (ВЫБОР ВЫГОДНОГО, ТЕЛЕПОРТ, КЛИК ЛКМ)
-- ============================================

local ReplicatedStorage = game:GetService("RobloxReplicatedStorage")

-- Телепортация к объекту (предмету или продавцу) БЕЗ ЗАДЕРЖЕК
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
    
    -- Мгновенный телепорт
    root.CFrame = CFrame.new(targetPart.Position) * CFrame.new(0, 0, 2)
    print("[AutoBuy] Телепорт выполнен")
    return true
end

-- Универсальная функция клика (ТОЛЬКО DataRemoteEvent, БЕЗ КУРСОРА)
local function clickObject(targetObj)
    print("[AutoBuy] 🎯 Взятие предмета через RemoteEvent")
    
    -- ТОЛЬКО DataRemoteEvent - мгновенно, без курсора
    local success = pcall(function()
        local dataRemote = game:GetService("ReplicatedStorage"):FindFirstChild("DataRemoteEvent")
        if dataRemote then
            if not targetObj or not targetObj.Parent then
                print("[AutoBuy] ⚠️ Объект предмета не найден в workspace")
                return false
            end
            
            local args = {
                {
                    "\003",  -- Код команды взятия предмета
                    {
                        targetObj,
                        n = 1
                    }
                }
            }
            
            print("[AutoBuy] 📡 Отправляю DataRemoteEvent для: " .. targetObj.Name)
            dataRemote:FireServer(unpack(args))
            print("[AutoBuy] ✅ DataRemoteEvent отправлен!")
            return true
        else
            print("[AutoBuy] ❌ DataRemoteEvent не найден")
            return false
        end
    end)
    
    return success
end

-- Поиск продавца Buy в том же магазине, где взят предмет
local function findBuySellerForItem(itemObj)
    -- Поднимаемся по иерархии до магазина (ActiveShops -> МагазинName)
    local current = itemObj
    local shopPart = nil
    
    -- Ищем родителя типа "SportMaster_Part", "Second-Hand_Part" и т.д.
    while current and current.Parent do
        if current.Parent.Name == "ActiveShops" then
            shopPart = current
            break
        end
        current = current.Parent
    end
    
    if not shopPart then
        print("[AutoBuy] ❌ Не удалось определить магазин предмета")
        return nil
    end
    
    print("[AutoBuy] 🏪 Магазин предмета: " .. shopPart.Name)
    
    -- Ищем продавца в этом магазине: ActiveShops.МагазинName.NPC.Buy
    local seller = nil
    pcall(function()
        seller = shopPart:FindFirstChild("NPC")
        if seller then
            seller = seller:FindFirstChild("Buy")
        end
    end)
    
    if seller then
        print("[AutoBuy] ✅ Найден продавец Buy в магазине: " .. shopPart.Name)
        return seller
    else
        print("[AutoBuy] ❌ Продавец Buy не найден в магазине: " .. shopPart.Name)
        return nil
    end
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
    
    -- 5. Находим продавца Buy в том же магазине
    local seller = findBuySellerForItem(bestItem.object)
    if not seller then
        print("[AutoBuy] ❌ Продавец Buy не найден")
        return
    end
    
    -- 6. Телепортируемся к продавцу
    if not teleportToObject(seller) then
        print("[AutoBuy] ❌ Не удалось телепортироваться к продавцу")
        return
    end
    
    -- 7. Отправляем RemoteEvent для покупки (БЕЗ КУРСОРА)
    print("[AutoBuy] 💳 Покупаю через продавца...")
    local buySuccess = pcall(function()
        local dataRemote = game:GetService("ReplicatedStorage"):FindFirstChild("DataRemoteEvent")
        if dataRemote then
            local args = {
                {
                    "\006",  -- Код команды покупки
                    {
                        seller,
                        n = 1
                    }
                }
            }
            
            print("[AutoBuy] 📡 Покупка через RemoteEvent")
            dataRemote:FireServer(unpack(args))
            print("[AutoBuy] ✅ Покупка завершена!")
        else
            print("[AutoBuy] ❌ DataRemoteEvent не найден")
        end
    end)
    
    if not buySuccess then
        print("[AutoBuy] ❌ Ошибка при покупке")
        return
    end
    
    -- 8. Обновляем ESP после покупки
    if espEnabled then
        task.wait(0.2) -- Небольшая задержка чтобы предмет успел удалиться
        updateESP()
    end
    
    print("[AutoBuy] ✅ Цикл завершен\n")
end

-- ============================================
-- AUTOSELL (АВТОПРОДАЖА) - УПРОЩЕННАЯ ВЕРСИЯ
-- ============================================

-- Поиск ближайшего продавца Sell
local function findSellDealer()
    local seller = nil
    local minDist = math.huge
    
    local activeShops = workspace:FindFirstChild("ActiveShops")
    if not activeShops then
        print("[AutoSell] ❌ ActiveShops не найдена")
        return nil
    end
    
    for _, shop in pairs(activeShops:GetChildren()) do
        pcall(function()
            local npc = shop:FindFirstChild("NPC")
            if npc then
                local sellNpc = npc:FindFirstChild("Sell")
                if sellNpc then
                    local dist = getDistance(sellNpc)
                    if dist and dist < minDist then
                        minDist = dist
                        seller = sellNpc
                        print("[AutoSell] 🔍 Найден продавец Sell в магазине: " .. shop.Name .. " (дистанция: " .. math.floor(dist) .. "м)")
                    end
                end
            end
        end)
    end
    
    if seller then
        print("[AutoSell] ✅ Выбран продавец Sell")
        return seller
    else
        print("[AutoSell] ❌ Продавец Sell не найден в ActiveShops")
        return nil
    end
end

-- Основной цикл автопродажи (УПРОЩЕННЫЙ - просто телепорт и продажа)
local function autoSellCycle()
    if not autoSellEnabled then 
        print("[AutoSell] ⚠️ AutoSell выключен")
        return 
    end
    
    print("[AutoSell] 🔄 Начинаю цикл продажи...")
    
    -- 1. Находим продавца Sell (ближайшего)
    local seller = findSellDealer()
    if not seller then
        print("[AutoSell] ❌ Продавец Sell не найден")
        return
    end
    
    -- 2. Телепортируемся к продавцу
    print("[AutoSell] 🚀 Телепортирую к продавцу...")
    if not teleportToObject(seller) then
        print("[AutoSell] ❌ Не удалось телепортироваться к продавцу")
        return
    end
    
    -- 3. Продаем через RemoteEvent (ПРАВИЛЬНЫЙ КОД \004 + StringValue)
    print("[AutoSell] 💰 Отправляю команду продажи...")
    local sellSuccess = pcall(function()
        local dataRemote = game:GetService("ReplicatedStorage"):FindFirstChild("DataRemoteEvent")
        if dataRemote then
            -- Создаем StringValue как в оригинальном коде
            local stringValue = Instance.new("StringValue")
            
            local args = {
                {
                    "\004",  -- ПРАВИЛЬНЫЙ код команды продажи!
                    {
                        stringValue,
                        n = 1
                    }
                }
            }
            
            print("[AutoSell] 📡 Отправка DataRemoteEvent с кодом \\004")
            dataRemote:FireServer(unpack(args))
            print("[AutoSell] ✅ Команда продажи отправлена!")
            return true
        else
            print("[AutoSell] ❌ DataRemoteEvent не найден в ReplicatedStorage")
            return false
        end
    end)
    
    if not sellSuccess then
        print("[AutoSell] ❌ Ошибка при отправке команды продажи")
        return
    end
    
    print("[AutoSell] ✅ Цикл продажи завершен\n")
end

local autoSellThread = nil
local function startAutoSell()
    if autoSellThread then return end
    autoSellThread = task.spawn(function()
        while autoSellEnabled do
            autoSellCycle()
            task.wait() -- Минимальная задержка
        end
        autoSellThread = nil
    end)
end

local function stopAutoSell()
    autoSellEnabled = false
    if autoSellThread then
        task.cancel(autoSellThread)
        autoSellThread = nil
    end
end

-- ============================================
-- AUTOBUY THREAD
-- ============================================

local autoBuyThread = nil
local function startAutoBuy()
    if autoBuyThread then return end
    autoBuyThread = task.spawn(function()
        while autoBuyEnabled do
            autoBuyCycle()
            task.wait() -- Минимальная задержка ~0.03 сек, чтобы не зависнуть
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
        Title = "ESP + AutoBuy + AutoSell",
        SubTitle = "by Firma Mode Hub | TG: @FirmaModeHub",
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

    MainTab:AddParagraph({
        Title = "💰 Авто-продажа",
        Content = "",
    })

    MainTab:AddToggle("AutoSell", {
        Title = "Включить AutoSell",
        Default = autoSellEnabled,
        Callback = function(v)
            autoSellEnabled = v
            if v then
                startAutoSell()
            else
                stopAutoSell()
            end
        end
    })

    MainTab:AddButton({
        Title = "Выполнить одну итерацию AutoSell",
        Callback = function()
            autoSellCycle()
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
    mainFrame.Size = UDim2.new(0, 300, 0, 410) -- Увеличено для subtitle и кнопок
    mainFrame.Position = UDim2.new(0.5, -150, 0.3, 0)
    mainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
    mainFrame.BorderSizePixel = 0
    mainFrame.Parent = screenGui
    Instance.new("UICorner").CornerRadius = UDim.new(0, 8)
    Instance.new("UICorner").Parent = mainFrame

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0, 40)
    title.BackgroundTransparency = 1
    title.Text = "⚙️ Firma Mode Hub"
    title.TextColor3 = Color3.fromRGB(255,255,255)
    title.Font = Enum.Font.SourceSansBold
    title.TextSize = 20
    title.Parent = mainFrame
    
    local subtitle = Instance.new("TextLabel")
    subtitle.Size = UDim2.new(1, 0, 0, 20)
    subtitle.Position = UDim2.new(0, 0, 0, 25)
    subtitle.BackgroundTransparency = 1
    subtitle.Text = "TG: @FirmaModeHub"
    subtitle.TextColor3 = Color3.fromRGB(150,150,150)
    subtitle.Font = Enum.Font.SourceSans
    subtitle.TextSize = 12
    subtitle.Parent = mainFrame

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

    local minBox = createInput(60, "Цена ОТ:", "0", function(v) FILTER.minPrice = v; if espEnabled then updateESP() end end)
    local maxBox = createInput(95, "Цена ДО:", "1000", function(v) FILTER.maxPrice = v; if espEnabled then updateESP() end end)
    local resBox = createInput(130, "ReSellMulti ОТ:", "2.0", function(v) FILTER.minResellMulti = v; if espEnabled then updateESP() end end)

    minBox.Text = tostring(FILTER.minPrice)
    maxBox.Text = tostring(FILTER.maxPrice)
    resBox.Text = tostring(FILTER.minResellMulti)

    local toggleBtn = Instance.new("TextButton")
    toggleBtn.Size = UDim2.new(0.8, 0, 0, 35)
    toggleBtn.Position = UDim2.new(0.1, 0, 0, 180)
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
    autoBtn.Position = UDim2.new(0.1, 0, 0, 225)
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

    local autoSellBtn = Instance.new("TextButton")
    autoSellBtn.Size = UDim2.new(0.8, 0, 0, 35)
    autoSellBtn.Position = UDim2.new(0.1, 0, 0, 270)
    autoSellBtn.BackgroundColor3 = Color3.fromRGB(100,100,100)
    autoSellBtn.BorderSizePixel = 0
    autoSellBtn.Text = "AutoSell ВЫКЛ"
    autoSellBtn.TextColor3 = Color3.fromRGB(255,255,255)
    autoSellBtn.Font = Enum.Font.SourceSansBold
    autoSellBtn.TextSize = 16
    autoSellBtn.Parent = mainFrame
    Instance.new("UICorner").CornerRadius = UDim.new(0, 5)
    Instance.new("UICorner").Parent = autoSellBtn

    autoSellBtn.MouseButton1Click:Connect(function()
        autoSellEnabled = not autoSellEnabled
        autoSellBtn.BackgroundColor3 = autoSellEnabled and Color3.fromRGB(0,200,0) or Color3.fromRGB(100,100,100)
        autoSellBtn.Text = autoSellEnabled and "AutoSell ВКЛ" or "AutoSell ВЫКЛ"
        if autoSellEnabled then
            startAutoSell()
        else
            stopAutoSell()
        end
    end)

    local refreshBtn = Instance.new("TextButton")
    refreshBtn.Size = UDim2.new(0.8, 0, 0, 35)
    refreshBtn.Position = UDim2.new(0.1, 0, 0, 315)
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
