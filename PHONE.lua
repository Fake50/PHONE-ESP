-- Auto Clan Invite Script with WindUI
-- Автоматически отправляет приглашения в клан всем игрокам на сервере

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

-- Загрузка WindUI
local WindUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/Wind-Explorer/WindUI/main/source.lua"))()

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
        return ReplicatedStorage:WaitForChild("ClanRemotes"):WaitForChild("GetMyClan"):InvokeServer()
    end)
    return success and result or nil
end

-- Проверка Rainbow статуса
local function getRainbowStatus()
    local success, result = pcall(function()
        return ReplicatedStorage:WaitForChild("ClanRemotes"):WaitForChild("GetRainbowStatus"):InvokeServer()
    end)
    return success and result or nil
end

-- Отправка приглашения игроку
local function invitePlayer(playerName)
    if invitedPlayers[playerName] then
        return false, "Already invited"
    end
    
    local success, err = pcall(function()
        local args = {playerName}
        ReplicatedStorage:WaitForChild("ClanRemotes"):WaitForChild("InvitePlayer"):InvokeServer(unpack(args))
    end)
    
    if success then
        invitedPlayers[playerName] = true
        stats.totalInvited = stats.totalInvited + 1
        stats.successInvites = stats.successInvites + 1
        notify("✓ Приглашен: " .. playerName, "success")
        updateStats()
        return true
    else
        stats.failedInvites = stats.failedInvites + 1
        notify("✗ Ошибка приглашения: " .. playerName, "error")
        updateStats()
        return false, err
    end
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
            wait(CONFIG.DELAY_BETWEEN_INVITES)
        end
    end
    
    notify(string.format("✓ Приглашено игроков: %d/%d", inviteCount, #players - 1), "success")
    updateStats()
end

-- Автоматическое приглашение новых игроков
local function setupAutoInvite()
    Players.PlayerAdded:Connect(function(player)
        if CONFIG.AUTO_REINVITE then
            wait(2) -- Ждем загрузки игрока
            
            if canInvitePlayer(player) then
                notify("👤 Новый игрок: " .. player.Name, "info")
                wait(CONFIG.DELAY_BETWEEN_INVITES)
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
    local window = WindUI:CreateWindow({
        Title = "Auto Clan Invite",
        Icon = "rbxassetid://10734950309",
        Author = "by Script",
        Folder = "AutoInviteConfig",
        Size = UDim2.fromOffset(480, 520),
        KeySystem = {
            Key = "test123",
            Note = "Тестовый ключ: test123",
            URL = "https://example.com/key",
            SaveKey = true
        },
        Transparent = false,
        Theme = "Dark",
        SideBarWidth = 170,
        HasOutline = true
    })

    -- Вкладка: Главная
    local mainTab = window:Tab({
        Name = "Главная",
        Icon = "rbxassetid://10734950309",
        Color = Color3.fromRGB(150, 120, 255)
    })

    local mainSection = mainTab:Section({
        Name = "Управление"
    })

    -- Кнопка: Пригласить всех
    mainSection:Button({
        Name = "Пригласить всех игроков",
        Callback = function()
            inviteAllPlayers()
        end
    })

    -- Кнопка: Очистить список
    mainSection:Button({
        Name = "Очистить список приглашенных",
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
    local statsSection = mainTab:Section({
        Name = "Статистика"
    })

    local statsLabel = statsSection:Label({
        Text = "Загрузка статистики..."
    })

    -- Функция обновления статистики
    _G.UpdateInviteStats = function(data)
        statsLabel:Set(string.format(
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
    local settingsTab = window:Tab({
        Name = "Настройки",
        Icon = "rbxassetid://10734950682",
        Color = Color3.fromRGB(255, 170, 0)
    })

    local settingsSection = settingsTab:Section({
        Name = "Параметры приглашений"
    })

    -- Переключатель: Авто приглашение
    settingsSection:Toggle({
        Name = "Авто-приглашение новых игроков",
        Value = CONFIG.AUTO_REINVITE,
        Callback = function(value)
            CONFIG.AUTO_REINVITE = value
            notify(value and "✓ Авто-приглашение включено" or "✗ Авто-приглашение выключено", "info")
        end
    })

    -- Переключатель: Исключить друзей
    settingsSection:Toggle({
        Name = "Исключить друзей",
        Value = CONFIG.EXCLUDE_FRIENDS,
        Callback = function(value)
            CONFIG.EXCLUDE_FRIENDS = value
            notify(value and "✓ Друзья исключены" or "✗ Друзья не исключаются", "info")
        end
    })

    -- Переключатель: Уведомления
    settingsSection:Toggle({
        Name = "Уведомления",
        Value = CONFIG.NOTIFY,
        Callback = function(value)
            CONFIG.NOTIFY = value
        end
    })

    -- Слайдер: Задержка между приглашениями
    settingsSection:Slider({
        Name = "Задержка между приглашениями (сек)",
        Min = 0.1,
        Max = 5,
        Value = CONFIG.DELAY_BETWEEN_INVITES,
        Callback = function(value)
            CONFIG.DELAY_BETWEEN_INVITES = value
            notify(string.format("⏱ Задержка: %.1f сек", value), "info")
        end
    })

    -- Вкладка: Логи
    local logsTab = window:Tab({
        Name = "Логи",
        Icon = "rbxassetid://10747372992",
        Color = Color3.fromRGB(0, 200, 255)
    })

    local logsSection = logsTab:Section({
        Name = "История действий"
    })

    local logText = logsSection:Paragraph({
        Title = "Лог событий",
        Desc = "Ожидание событий..."
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
        
        logText:Set({
            Title = "Лог событий",
            Desc = table.concat(logs, "\n")
        })
    end

    -- Кнопка очистки логов
    logsSection:Button({
        Name = "Очистить логи",
        Callback = function()
            logs = {}
            logText:Set({
                Title = "Лог событий",
                Desc = "Логи очищены"
            })
        end
    })

    -- Вкладка: Список игроков
    local playersTab = window:Tab({
        Name = "Игроки",
        Icon = "rbxassetid://10747373176",
        Color = Color3.fromRGB(100, 255, 150)
    })

    local playersSection = playersTab:Section({
        Name = "Игроки на сервере"
    })

    local playersList = playersSection:Paragraph({
        Title = "Список игроков",
        Desc = "Загрузка..."
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
        
        playersList:Set({
            Title = string.format("Игроков: %d", #playerNames),
            Desc = #playerNames > 0 and table.concat(playerNames, "\n") or "Нет игроков"
        })
    end

    -- Кнопка обновления списка
    playersSection:Button({
        Name = "Обновить список",
        Callback = updatePlayersList
    })

    -- Автообновление каждые 5 секунд
    spawn(function()
        while wait(5) do
            updatePlayersList()
        end
    end)

    -- Вкладка: Информация
    local infoTab = window:Tab({
        Name = "Инфо",
        Icon = "rbxassetid://10734923549",
        Color = Color3.fromRGB(255, 100, 100)
    })

    local infoSection = infoTab:Section({
        Name = "О скрипте"
    })

    infoSection:Paragraph({
        Title = "Auto Clan Invite",
        Desc = "Автоматическое приглашение игроков в клан\n\n" ..
               "Функции:\n" ..
               "• Автоматические приглашения\n" ..
               "• Отслеживание новых игроков\n" ..
               "• Настраиваемая задержка\n" ..
               "• Статистика и логи\n" ..
               "• Список игроков\n\n" ..
               "Версия: 2.0"
    })

    -- Начальное обновление
    updateStats()
    updatePlayersList()
    
    return window
end

-- Инициализация скрипта
local function initialize()
    notify("🚀 Auto Invite загружен!", "success")
    
    -- Проверяем наличие клана
    local myClan = getMyClan()
    if myClan then
        notify("✓ Клан найден", "success")
    else
        notify("⚠ Клан не найден", "warning")
    end
    
    -- Создание GUI
    createGUI()
    
    -- Настройка автоматического приглашения
    setupAutoInvite()
    
    -- Первичное обновление статистики
    updateStats()
    
    notify("� Используйте GUI для управления", "info")
end

-- Запуск
initialize()

