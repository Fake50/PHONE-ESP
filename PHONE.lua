-- Auto Clan Invite Script with Fluent UI
-- Автоматически отправляет приглашения в клан всем игрокам на сервере

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

-- Загрузка Fluent UI
local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua"))()
local InterfaceManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua"))()

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
        -- Пробуем разные возможные пути к RemoteFunction клана
        local remotes = ReplicatedStorage:FindFirstChild("ClanRemotes") or 
                        ReplicatedStorage:FindFirstChild("Remotes") or
                        ReplicatedStorage:FindFirstChild("NetworkRemotes")
        
        if not remotes then
            warn("[Auto Invite] ClanRemotes не найдены!")
            return nil
        end
        
        local getMyClanRemote = remotes:FindFirstChild("GetMyClan") or
                                 remotes:FindFirstChild("GetClan") or
                                 remotes:FindFirstChild("GetPlayerClan")
        
        if getMyClanRemote and getMyClanRemote:IsA("RemoteFunction") then
            return getMyClanRemote:InvokeServer()
        end
        
        return nil
    end)
    
    if success and result then
        notify("✓ Клан найден", "success")
        return result
    else
        notify("⚠ Не удалось получить информацию о клане", "warning")
        return nil
    end
end

-- Отправка приглашения игроку
local function invitePlayer(playerName)
    if invitedPlayers[playerName] then
        return false, "Already invited"
    end
    
    local success, err = pcall(function()
        -- Ищем правильный путь к RemoteEvent/RemoteFunction
        local remotes = ReplicatedStorage:FindFirstChild("ClanRemotes") or 
                        ReplicatedStorage:FindFirstChild("Remotes") or
                        ReplicatedStorage:FindFirstChild("NetworkRemotes")
        
        if not remotes then
            error("ClanRemotes не найдены!")
        end
        
        -- Пробуем разные варианты названий
        local inviteRemote = remotes:FindFirstChild("InvitePlayer") or
                             remotes:FindFirstChild("InviteToClan") or
                             remotes:FindFirstChild("SendInvite") or
                             remotes:FindFirstChild("ClanInvite")
        
        if not inviteRemote then
            error("InvitePlayer RemoteEvent не найден!")
        end
        
        -- Вызываем в зависимости от типа
        if inviteRemote:IsA("RemoteFunction") then
            return inviteRemote:InvokeServer(playerName)
        elseif inviteRemote:IsA("RemoteEvent") then
            inviteRemote:FireServer(playerName)
            return true
        end
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
        notify("✗ Ошибка: " .. tostring(err), "error")
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
    -- Диагностика: выводим все RemoteEvents/RemoteFunctions
    print("=== ДИАГНОСТИКА AUTO INVITE ===")
    print("Поиск RemoteEvents для клана...")
    
    local function scanFolder(folder, depth)
        depth = depth or 0
        if depth > 3 then return end
        
        for _, child in pairs(folder:GetChildren()) do
            if child:IsA("RemoteEvent") or child:IsA("RemoteFunction") then
                local path = child:GetFullName()
                if path:lower():find("clan") or path:lower():find("invite") then
                    print(string.format("  [%s] %s", child.ClassName, path))
                end
            elseif child:IsA("Folder") or child:IsA("Model") then
                scanFolder(child, depth + 1)
            end
        end
    end
    
    scanFolder(ReplicatedStorage)
    print("=== КОНЕЦ ДИАГНОСТИКИ ===")
    
    notify("🚀 Auto Invite загружен!", "success")
    
    -- Проверяем наличие клана
    task.wait(1)
    local myClan = getMyClan()
    if myClan then
        notify("✓ Клан найден: " .. tostring(myClan.Name or "Unknown"), "success")
    else
        notify("⚠ Клан не найден или ошибка", "warning")
        notify("ℹ Проверьте консоль (F9) для диагностики", "info")
    end
    
    -- Создание GUI
    createGUI()
    
    -- Настройка автоматического приглашения
    setupAutoInvite()
    
    -- Первичное обновление статистики
    updateStats()
    
    notify("✓ Используйте GUI для управления", "info")
    
    Fluent:Notify({
        Title = "Auto Invite",
        Content = "Скрипт успешно загружен! Проверьте консоль (F9) для диагностики.",
        Duration = 5
    })
end

-- Запуск
initialize()
