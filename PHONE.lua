-- Auto Clan Invite Script with Fluent UI
-- Автоматически отправляет приглашения в клан всем игрокам на сервере

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

-- Загрузка Fluent UI
local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua"))()
local InterfaceManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua"))()

-- Получаем ClanScript игрока
local ClanScript = LocalPlayer:WaitForChild("ClanScript", 10)
if not ClanScript then
    LocalPlayer:Kick("❌ ClanScript не найден! Перезайдите в игру.")
    return
end

print("[Auto Invite] ClanScript найден:", ClanScript:GetFullName())

-- Настройки
local CONFIG = {
    DELAY_BETWEEN_INVITES = 0.5, -- Задержка между приглашениями (секунды)
    AUTO_REINVITE = true, -- Автоматически приглашать новых игроков
    EXCLUDE_FRIENDS = false, -- Исключить друзей из приглашений
    NOTIFY = true -- Показывать уведомления
}

-- Список уже приглашенных игроков
local invitedPlayers = {}

-- Статистика
local stats = {
    totalInvited = 0,
    successInvites = 0,
    failedInvites = 0,
    playersOnServer = 0
}

-- Функция уведомлений
local function notify(message, type)
    if CONFIG.NOTIFY then
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = "Auto Invite";
            Text = message;
            Duration = 3;
        })
    end
    print("[Auto Invite]", message)
    
    -- Обновление лога в GUI
    if _G.AutoInviteLog then
        _G.AutoInviteLog(message, type or "info")
    end
end

-- Обновление статистики
local function updateStats()
    stats.playersOnServer = #Players:GetPlayers() - 1
    if _G.UpdateInviteStats then
        _G.UpdateInviteStats(stats)
    end
end

-- Получение информации о клане
local function getMyClan()
    local success, result = pcall(function()
        -- Используем ClanRemotes напрямую
        local ClanRemotes = ReplicatedStorage:WaitForChild("ClanRemotes", 5)
        if not ClanRemotes then
            error("ClanRemotes не найдены")
        end
        
        local GetMyClan = ClanRemotes:WaitForChild("GetMyClan", 5)
        if not GetMyClan then
            error("GetMyClan не найден")
        end
        
        return GetMyClan:InvokeServer()
    end)
    
    if success and result then
        print("[Auto Invite] Клан найден:", result)
        return result
    else
        warn("[Auto Invite] Ошибка получения клана:", result)
        return nil
    end
end

-- Проверка Rainbow статуса
local function getRainbowStatus()
    local success, result = pcall(function()
        return ReplicatedStorage:WaitForChild("ClanRemotes", 5):WaitForChild("GetRainbowStatus", 5):InvokeServer()
    end)
    return success and result or nil
end

-- Отправка приглашения игроку (ОСНОВНАЯ ФУНКЦИЯ)
local function invitePlayer(playerName)
    if invitedPlayers[playerName] then
        return false, "Already invited"
    end
    
    -- ВАРИАНТ 1: Прямой вызов через InvokeServer
    local success, result = pcall(function()
        local ClanRemotes = ReplicatedStorage:WaitForChild("ClanRemotes", 5)
        local InvitePlayer = ClanRemotes:WaitForChild("InvitePlayer", 5)
        
        -- Пробуем вызвать напрямую
        return InvitePlayer:InvokeServer(playerName)
    end)
    
    if success then
        invitedPlayers[playerName] = true
        stats.totalInvited = stats.totalInvited + 1
        stats.successInvites = stats.successInvites + 1
        notify("✓ Приглашен: " .. playerName, "success")
        updateStats()
        return true
    end
    
    -- ВАРИАНТ 2: Через FireServer если InvokeServer не работает
    local success2, result2 = pcall(function()
        local ClanRemotes = ReplicatedStorage:WaitForChild("ClanRemotes", 5)
        local InvitePlayer = ClanRemotes:WaitForChild("InvitePlayer", 5)
        
        if InvitePlayer:IsA("RemoteEvent") then
            InvitePlayer:FireServer(playerName)
            return true
        end
    end)
    
    if success2 then
        invitedPlayers[playerName] = true
        stats.totalInvited = stats.totalInvited + 1
        stats.successInvites = stats.successInvites + 1
        notify("✓ Приглашен: " .. playerName, "success")
        updateStats()
        return true
    end
    
    -- Если оба варианта не сработали
    stats.failedInvites = stats.failedInvites + 1
    local errorMsg = tostring(result) .. " | " .. tostring(result2)
    notify("✗ Ошибка: " .. errorMsg, "error")
    warn("[Auto Invite] Ошибка приглашения игрока", playerName, ":", errorMsg)
    updateStats()
    return false, errorMsg
end

-- Проверка, можно ли пригласить игрока
local function canInvitePlayer(player)
    -- Не приглашать самого себя
    if player == LocalPlayer then
        return false
    end
    
    -- Проверка на уже приглашенных
    if invitedPlayers[player.Name] then
        return false
    end
    
    -- Исключить друзей если настройка включена
    if CONFIG.EXCLUDE_FRIENDS then
        local isFriend = player:IsFriendsWith(LocalPlayer.UserId)
        if isFriend then
            return false
        end
    end
    
    return true
end

-- Пригласить всех игроков на сервере
local function inviteAllPlayers()
    local myClan = getMyClan()
    
    if not myClan then
        notify("⚠ У вас нет клана!", "warning")
        Fluent:Notify({
            Title = "Auto Invite",
            Content = "У вас нет клана! Создайте клан перед использованием.",
            Duration = 5
        })
        return
    end
    
    notify("🔄 Начинаю приглашать игроков...", "info")
    
    local inviteCount = 0
    local players = Players:GetPlayers()
    
    for _, player in ipairs(players) do
        if canInvitePlayer(player) then
            local success = invitePlayer(player.Name)
            if success then
                inviteCount = inviteCount + 1
            end
            task.wait(CONFIG.DELAY_BETWEEN_INVITES)
        end
    end
    
    notify(string.format("✓ Приглашено игроков: %d/%d", inviteCount, #players - 1), "success")
    updateStats()
end

-- Автоматическое приглашение новых игроков
local function setupAutoInvite()
    Players.PlayerAdded:Connect(function(player)
        if CONFIG.AUTO_REINVITE then
            task.wait(2) -- Ждем загрузки игрока
            
            if canInvitePlayer(player) then
                notify("👤 Новый игрок: " .. player.Name, "info")
                task.wait(CONFIG.DELAY_BETWEEN_INVITES)
                invitePlayer(player.Name)
            end
        end
        updateStats()
    end)
    
    -- Очистка списка при выходе игрока
    Players.PlayerRemoving:Connect(function(player)
        invitedPlayers[player.Name] = nil
        updateStats()
    end)
end

-- Создание GUI
local function createGUI()
    local Window = Fluent:CreateWindow({
        Title = "Auto Clan Invite " .. Fluent.Version,
        SubTitle = "by Script",
        TabWidth = 160,
        Size = UDim2.fromOffset(580, 460),
        Acrylic = true,
        Theme = "Dark",
        MinimizeKey = Enum.KeyCode.LeftControl
    })

    local Tabs = {
        Main = Window:AddTab({ Title = "Главная", Icon = "home" }),
        Settings = Window:AddTab({ Title = "Настройки", Icon = "settings" }),
        Players = Window:AddTab({ Title = "Игроки", Icon = "users" }),
        Logs = Window:AddTab({ Title = "Логи", Icon = "list" }),
        Info = Window:AddTab({ Title = "Инфо", Icon = "info" })
    }

    -- Вкладка: Главная
    local MainSection = Tabs.Main:AddSection("Управление")

    Tabs.Main:AddButton({
        Title = "🧪 Тест приглашения",
        Description = "Попробовать пригласить первого игрока для теста",
        Callback = function()
            local testPlayer = nil
            for _, player in ipairs(Players:GetPlayers()) do
                if player ~= LocalPlayer then
                    testPlayer = player
                    break
                end
            end
            
            if testPlayer then
                notify("🧪 Тестирую приглашение для: " .. testPlayer.Name, "info")
                print("[Auto Invite] === НАЧАЛО ТЕСТА ===")
                print("[Auto Invite] Тестовый игрок:", testPlayer.Name)
                
                local success, err = invitePlayer(testPlayer.Name)
                
                if success then
                    print("[Auto Invite] ✅ ТЕСТ УСПЕШЕН")
                    Fluent:Notify({
                        Title = "Тест успешен!",
                        Content = "Приглашение отправлено: " .. testPlayer.Name,
                        Duration = 5
                    })
                else
                    print("[Auto Invite] ❌ ТЕСТ ПРОВАЛЕН:", err)
                    Fluent:Notify({
                        Title = "Тест провален",
                        Content = "Ошибка: " .. tostring(err),
                        Duration = 5
                    })
                end
                
                print("[Auto Invite] === КОНЕЦ ТЕСТА ===")
            else
                notify("⚠ Нет других игроков на сервере", "warning")
            end
        end
    })

    Tabs.Main:AddButton({
        Title = "Пригласить всех игроков",
        Description = "Отправить приглашения всем игрокам",
        Callback = function()
            inviteAllPlayers()
        end
    })

    Tabs.Main:AddButton({
        Title = "Очистить список приглашенных",
        Description = "Сбросить всю статистику",
        Callback = function()
            invitedPlayers = {}
            stats.totalInvited = 0
            stats.successInvites = 0
            stats.failedInvites = 0
            notify("🔄 Список приглашенных очищен", "info")
            updateStats()
        end
    })

    -- Статистика
    local StatsSection = Tabs.Main:AddSection("Статистика")

    local StatsParagraph = Tabs.Main:AddParagraph({
        Title = "Статистика приглашений",
        Content = "Загрузка статистики..."
    })

    -- Функция обновления статистики
    _G.UpdateInviteStats = function(data)
        StatsParagraph:SetDesc(string.format(
            "📊 Всего приглашено: %d\n" ..
            "✅ Успешно: %d\n" ..
            "❌ Ошибок: %d\n" ..
            "👥 Игроков на сервере: %d",
            data.totalInvited,
            data.successInvites,
            data.failedInvites,
            data.playersOnServer
        ))
    end

    -- Вкладка: Настройки
    local SettingsSection = Tabs.Settings:AddSection("Параметры приглашений")

    Tabs.Settings:AddToggle("AutoInvite", {
        Title = "Авто-приглашение новых игроков",
        Description = "Автоматически приглашать новых игроков",
        Default = CONFIG.AUTO_REINVITE,
        Callback = function(value)
            CONFIG.AUTO_REINVITE = value
            notify(value and "✓ Авто-приглашение включено" or "✗ Авто-приглашение выключено", "info")
        end
    })

    Tabs.Settings:AddToggle("ExcludeFriends", {
        Title = "Исключить друзей",
        Description = "Не приглашать друзей в клан",
        Default = CONFIG.EXCLUDE_FRIENDS,
        Callback = function(value)
            CONFIG.EXCLUDE_FRIENDS = value
            notify(value and "✓ Друзья исключены" or "✗ Друзья не исключаются", "info")
        end
    })

    Tabs.Settings:AddToggle("Notifications", {
        Title = "Уведомления",
        Description = "Показывать уведомления о действиях",
        Default = CONFIG.NOTIFY,
        Callback = function(value)
            CONFIG.NOTIFY = value
        end
    })

    Tabs.Settings:AddSlider("Delay", {
        Title = "Задержка между приглашениями",
        Description = "Задержка в секундах",
        Default = CONFIG.DELAY_BETWEEN_INVITES,
        Min = 0.1,
        Max = 5,
        Rounding = 1,
        Callback = function(value)
            CONFIG.DELAY_BETWEEN_INVITES = value
            notify(string.format("⏱ Задержка: %.1f сек", value), "info")
        end
    })

    -- Вкладка: Игроки
    local PlayersSection = Tabs.Players:AddSection("Игроки на сервере")

    local PlayersList = Tabs.Players:AddParagraph({
        Title = "Список игроков",
        Content = "Загрузка..."
    })

    -- Обновление списка игроков
    local function updatePlayersList()
        local playerNames = {}
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer then
                local status = invitedPlayers[player.Name] and "✓" or "○"
                table.insert(playerNames, string.format("%s %s", status, player.Name))
            end
        end
        
        PlayersList:SetTitle(string.format("Игроков: %d", #playerNames))
        PlayersList:SetDesc(#playerNames > 0 and table.concat(playerNames, "\n") or "Нет игроков")
    end

    Tabs.Players:AddButton({
        Title = "Обновить список",
        Description = "Обновить список игроков",
        Callback = updatePlayersList
    })

    -- Автообновление каждые 5 секунд
    task.spawn(function()
        while task.wait(5) do
            updatePlayersList()
        end
    end)

    -- Вкладка: Логи
    local LogsSection = Tabs.Logs:AddSection("История действий")

    local LogsParagraph = Tabs.Logs:AddParagraph({
        Title = "Лог событий",
        Content = "Ожидание событий..."
    })

    local logs = {}
    local maxLogs = 15

    -- Функция добавления логов
    _G.AutoInviteLog = function(message, type)
        local timestamp = os.date("%H:%M:%S")
        local logEntry = string.format("[%s] %s", timestamp, message)
        
        table.insert(logs, 1, logEntry)
        
        if #logs > maxLogs then
            table.remove(logs, maxLogs + 1)
        end
        
        LogsParagraph:SetDesc(table.concat(logs, "\n"))
    end

    Tabs.Logs:AddButton({
        Title = "Очистить логи",
        Description = "Очистить всю историю",
        Callback = function()
            logs = {}
            LogsParagraph:SetDesc("Логи очищены")
        end
    })

    -- Вкладка: Информация
    local InfoSection = Tabs.Info:AddSection("О скрипте")

    Tabs.Info:AddParagraph({
        Title = "Auto Clan Invite v2.0",
        Content = "Автоматическое приглашение игроков в клан\n\n" ..
                   "Функции:\n" ..
                   "• Автоматические приглашения\n" ..
                   "• Отслеживание новых игроков\n" ..
                   "• Настраиваемая задержка\n" ..
                   "• Статистика и логи\n" ..
                   "• Список игроков\n\n" ..
                   "Создано для игры Stand For All Time"
    })
    
    Tabs.Info:AddSection("Диагностика")
    
    Tabs.Info:AddButton({
        Title = "🔍 Проверить ClanRemotes",
        Description = "Показать информацию о RemoteEvents",
        Callback = function()
            print("=== ДИАГНОСТИКА CLAN REMOTES ===")
            
            local ClanRemotes = ReplicatedStorage:FindFirstChild("ClanRemotes")
            if ClanRemotes then
                print("✅ ClanRemotes найден:", ClanRemotes:GetFullName())
                
                for _, child in pairs(ClanRemotes:GetChildren()) do
                    print("  -", child.Name, "(" .. child.ClassName .. ")")
                end
                
                local InvitePlayer = ClanRemotes:FindFirstChild("InvitePlayer")
                if InvitePlayer then
                    print("✅ InvitePlayer найден:", InvitePlayer.ClassName)
                else
                    print("❌ InvitePlayer не найден")
                end
                
                Fluent:Notify({
                    Title = "Диагностика",
                    Content = "Проверьте консоль (F9) для подробностей",
                    Duration = 5
                })
            else
                print("❌ ClanRemotes не найден!")
                Fluent:Notify({
                    Title = "Ошибка",
                    Content = "ClanRemotes не найден в ReplicatedStorage",
                    Duration = 5
                })
            end
            
            print("=== КОНЕЦ ДИАГНОСТИКИ ===")
        end
    })
    
    Tabs.Info:AddButton({
        Title = "📋 Показать информацию о клане",
        Description = "Вывести данные вашего клана",
        Callback = function()
            local clan = getMyClan()
            if clan then
                print("=== ИНФОРМАЦИЯ О КЛАНЕ ===")
                print("Тип данных:", type(clan))
                
                if type(clan) == "table" then
                    for k, v in pairs(clan) do
                        print("  " .. tostring(k) .. ":", tostring(v))
                    end
                else
                    print("Данные:", clan)
                end
                
                print("=== КОНЕЦ ИНФОРМАЦИИ ===")
                
                Fluent:Notify({
                    Title = "Информация о клане",
                    Content = "Проверьте консоль (F9)",
                    Duration = 5
                })
            else
                Fluent:Notify({
                    Title = "Ошибка",
                    Content = "Не удалось получить информацию о клане",
                    Duration = 5
                })
            end
        end
    })

    -- Настройка SaveManager и InterfaceManager
    SaveManager:SetLibrary(Fluent)
    InterfaceManager:SetLibrary(Fluent)
    SaveManager:IgnoreThemeSettings()
    SaveManager:SetIgnoreIndexes({})
    InterfaceManager:SetFolder("AutoInviteConfig")
    SaveManager:SetFolder("AutoInviteConfig/saves")
    InterfaceManager:BuildInterfaceSection(Tabs.Settings)
    SaveManager:BuildConfigSection(Tabs.Settings)

    -- Начальное обновление
    updateStats()
    updatePlayersList()
    
    Window:SelectTab(1)
    
    return Window
end

-- Инициализация скрипта
local function initialize()
    notify("🚀 Auto Invite загружен!", "success")
    
    -- Проверяем наличие клана
    task.wait(1)
    local myClan = getMyClan()
    
    if myClan then
        local clanName = type(myClan) == "table" and (myClan.Name or myClan.name or "Unknown") or "Unknown"
        notify("✓ Клан найден: " .. tostring(clanName), "success")
        print("[Auto Invite] Информация о клане:", myClan)
    else
        notify("⚠ У вас нет клана!", "warning")
    end
    
    -- Создание GUI
    createGUI()
    
    -- Настройка автоматического приглашения
    setupAutoInvite()
    
    -- Первичное обновление статистики
    updateStats()
    
    notify("✓ Используйте GUI для управления", "info")
    
    Fluent:Notify({
        Title = "Auto Clan Invite",
        Content = myClan and "Скрипт готов к работе!" or "У вас нет клана! Создайте клан перед использованием.",
        Duration = 5
    })
end

-- Запуск
initialize()
