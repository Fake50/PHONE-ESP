-- Auto Clan Invite Script with Fluent UI
-- Автоматически отправляет приглашения в клан всем игрокам на сервере

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

print("[Auto Invite] Начало загрузки...")

-- Загрузка Fluent UI
local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua"))()
local InterfaceManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua"))()

print("[Auto Invite] Fluent UI загружен")

-- Настройки
local CONFIG = {
    DELAY_BETWEEN_INVITES = 0.5,
    AUTO_REINVITE = true,
    EXCLUDE_FRIENDS = false,
    NOTIFY = true
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
        local ClanRemotes = ReplicatedStorage:WaitForChild("ClanRemotes", 5)
        local GetMyClan = ClanRemotes:WaitForChild("GetMyClan", 5)
        return GetMyClan:InvokeServer()
    end)
    
    if success and result then
        return result
    else
        warn("[Auto Invite] Ошибка получения клана:", result)
        return nil
    end
end

-- Отправка приглашения игроку
local function invitePlayer(playerName)
    if invitedPlayers[playerName] then
        return false, "Already invited"
    end
    
    local success, result = pcall(function()
        local ClanRemotes = ReplicatedStorage:WaitForChild("ClanRemotes", 5)
        local InvitePlayer = ClanRemotes:WaitForChild("InvitePlayer", 5)
        return InvitePlayer:InvokeServer(playerName)
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
        local errorMsg = tostring(result)
        notify("✗ Ошибка: " .. errorMsg, "error")
        warn("[Auto Invite] Ошибка:", errorMsg)
        updateStats()
        return false, result
    end
end

-- Проверка, можно ли пригласить игрока
local function canInvitePlayer(player)
    if player == LocalPlayer then
        return false
    end
    
    if invitedPlayers[player.Name] then
        return false
    end
    
    if CONFIG.EXCLUDE_FRIENDS then
        local isFriend = player:IsFriendsWith(LocalPlayer.UserId)
        if isFriend then
            return false
        end
    end
    
    return true
end

-- Пригласить всех игроков
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
    
    notify(string.format("✓ Приглашено: %d/%d", inviteCount, #players - 1), "success")
    updateStats()
end

-- Автоматическое приглашение новых игроков
local function setupAutoInvite()
    Players.PlayerAdded:Connect(function(player)
        if CONFIG.AUTO_REINVITE then
            task.wait(2)
            
            if canInvitePlayer(player) then
                notify("👤 Новый игрок: " .. player.Name, "info")
                task.wait(CONFIG.DELAY_BETWEEN_INVITES)
                invitePlayer(player.Name)
            end
        end
        updateStats()
    end)
    
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

    -- Главная
    Tabs.Main:AddSection("Управление")

    Tabs.Main:AddButton({
        Title = "🧪 Тест приглашения",
        Description = "Пригласить первого игрока для теста",
        Callback = function()
            local testPlayer = nil
            for _, player in ipairs(Players:GetPlayers()) do
                if player ~= LocalPlayer then
                    testPlayer = player
                    break
                end
            end
            
            if testPlayer then
                notify("🧪 Тест: " .. testPlayer.Name, "info")
                local success, err = invitePlayer(testPlayer.Name)
                
                if success then
                    Fluent:Notify({
                        Title = "Тест успешен!",
                        Content = "Приглашение отправлено: " .. testPlayer.Name,
                        Duration = 5
                    })
                else
                    Fluent:Notify({
                        Title = "Тест провален",
                        Content = "Ошибка: " .. tostring(err),
                        Duration = 5
                    })
                end
            else
                notify("⚠ Нет других игроков", "warning")
            end
        end
    })

    Tabs.Main:AddButton({
        Title = "Пригласить всех игроков",
        Description = "Отправить приглашения всем",
        Callback = function()
            inviteAllPlayers()
        end
    })

    Tabs.Main:AddButton({
        Title = "Очистить список",
        Description = "Сбросить статистику",
        Callback = function()
            invitedPlayers = {}
            stats.totalInvited = 0
            stats.successInvites = 0
            stats.failedInvites = 0
            notify("🔄 Список очищен", "info")
            updateStats()
        end
    })

    -- Статистика
    Tabs.Main:AddSection("Статистика")

    local StatsParagraph = Tabs.Main:AddParagraph({
        Title = "Статистика приглашений",
        Content = "Загрузка..."
    })

    _G.UpdateInviteStats = function(data)
        StatsParagraph:SetDesc(string.format(
            "📊 Всего: %d\n✅ Успешно: %d\n❌ Ошибок: %d\n👥 Игроков: %d",
            data.totalInvited,
            data.successInvites,
            data.failedInvites,
            data.playersOnServer
        ))
    end

    -- Настройки
    Tabs.Settings:AddSection("Параметры")

    Tabs.Settings:AddToggle("AutoInvite", {
        Title = "Авто-приглашение новых игроков",
        Default = CONFIG.AUTO_REINVITE,
        Callback = function(value)
            CONFIG.AUTO_REINVITE = value
            notify(value and "✓ Авто-приглашение ВКЛ" or "✗ Авто-приглашение ВЫКЛ", "info")
        end
    })

    Tabs.Settings:AddToggle("ExcludeFriends", {
        Title = "Исключить друзей",
        Default = CONFIG.EXCLUDE_FRIENDS,
        Callback = function(value)
            CONFIG.EXCLUDE_FRIENDS = value
            notify(value and "✓ Друзья исключены" or "✗ Друзья не исключаются", "info")
        end
    })

    Tabs.Settings:AddToggle("Notifications", {
        Title = "Уведомления",
        Default = CONFIG.NOTIFY,
        Callback = function(value)
            CONFIG.NOTIFY = value
        end
    })

    Tabs.Settings:AddSlider("Delay", {
        Title = "Задержка (сек)",
        Default = CONFIG.DELAY_BETWEEN_INVITES,
        Min = 0.1,
        Max = 5,
        Rounding = 1,
        Callback = function(value)
            CONFIG.DELAY_BETWEEN_INVITES = value
            notify(string.format("⏱ Задержка: %.1f сек", value), "info")
        end
    })

    -- Игроки
    Tabs.Players:AddSection("Список игроков")

    local PlayersList = Tabs.Players:AddParagraph({
        Title = "Игроки на сервере",
        Content = "Загрузка..."
    })

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
        Callback = updatePlayersList
    })

    task.spawn(function()
        while task.wait(5) do
            updatePlayersList()
        end
    end)

    -- Логи
    Tabs.Logs:AddSection("История")

    local LogsParagraph = Tabs.Logs:AddParagraph({
        Title = "Лог событий",
        Content = "Ожидание..."
    })

    local logs = {}
    local maxLogs = 15

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
        Callback = function()
            logs = {}
            LogsParagraph:SetDesc("Логи очищены")
        end
    })

    -- Инфо
    Tabs.Info:AddSection("О скрипте")

    Tabs.Info:AddParagraph({
        Title = "Auto Clan Invite v2.0",
        Content = "Автоматическое приглашение игроков в клан\n\nФункции:\n• Автоматические приглашения\n• Новые игроки\n• Настройки\n• Статистика\n• Логи"
    })

    -- Диагностика
    Tabs.Info:AddSection("Диагностика")
    
    Tabs.Info:AddButton({
        Title = "🔍 Проверить RemoteEvents",
        Callback = function()
            print("=== ДИАГНОСТИКА ===")
            
            local ClanRemotes = ReplicatedStorage:FindFirstChild("ClanRemotes")
            if ClanRemotes then
                print("✅ ClanRemotes найден")
                
                for _, child in pairs(ClanRemotes:GetChildren()) do
                    print("  -", child.Name, "(" .. child.ClassName .. ")")
                end
                
                Fluent:Notify({
                    Title = "Диагностика",
                    Content = "Проверьте консоль (F9)",
                    Duration = 5
                })
            else
                print("❌ ClanRemotes не найден!")
            end
            
            print("=== КОНЕЦ ===")
        end
    })

    -- Настройка SaveManager
    SaveManager:SetLibrary(Fluent)
    InterfaceManager:SetLibrary(Fluent)
    SaveManager:IgnoreThemeSettings()
    SaveManager:SetIgnoreIndexes({})
    InterfaceManager:SetFolder("AutoInviteConfig")
    SaveManager:SetFolder("AutoInviteConfig/saves")
    InterfaceManager:BuildInterfaceSection(Tabs.Settings)
    SaveManager:BuildConfigSection(Tabs.Settings)

    updateStats()
    updatePlayersList()
    
    Window:SelectTab(1)
    
    return Window
end

-- Инициализация
local function initialize()
    notify("🚀 Auto Invite загружен!", "success")
    
    task.wait(1)
    local myClan = getMyClan()
    
    if myClan then
        local clanName = type(myClan) == "table" and (myClan.Name or myClan.name or "Unknown") or "Unknown"
        notify("✓ Клан: " .. tostring(clanName), "success")
    else
        notify("⚠ У вас нет клана!", "warning")
    end
    
    createGUI()
    setupAutoInvite()
    updateStats()
    
    notify("✓ Готов к работе", "info")
    
    Fluent:Notify({
        Title = "Auto Clan Invite",
        Content = myClan and "Скрипт готов!" or "У вас нет клана!",
        Duration = 5
    })
end

-- Запуск
initialize()
