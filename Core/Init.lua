-- DoF/Core/Init.lua
-- Инициализация аддона через Ace3

local ADDON_NAME, DoF = ...
_G.DoF = DoF

-- Создаём аддон через AceAddon
local Addon = LibStub("AceAddon-3.0"):NewAddon(ADDON_NAME, 
    "AceEvent-3.0",     -- События
    "AceComm-3.0",      -- Коммуникация между игроками
    "AceTimer-3.0",     -- Таймеры
    "AceSerializer-3.0" -- Сериализация данных
)

DoF.Addon = Addon

-- ═══════════════════════════════════════════════════════════
-- ACE CALLBACKS
-- ═══════════════════════════════════════════════════════════

function Addon:OnInitialize()
    -- Язык применяем ПЕРВЫМ делом. До этого момента аддон говорит на языке
    -- клиента: сохранённый выбор лежит в SavedVariables, а они становятся
    -- доступны только сейчас, к ADDON_LOADED — файлы аддона выполнились раньше.
    -- Refresh перечитает настройку и, если язык другой, пересоберёт всё, что
    -- успело «запечь» строки при загрузке (см. Locale/Engine.lua).
    DoF.Locale:Refresh()

    -- Инициализация базы данных через AceDB
    self.db = LibStub("AceDB-3.0"):New("DoF_DB", DoF.Defaults, true)
    DoF.db = self.db

    -- Персистентность эффектов: направляем таблицы Effects на db, чтобы изменения
    -- в памяти автоматически сохранялись между /reload и дисконнектами.
    -- Эффекты round-based — /reload не продвигает раунды, remainingRounds остаётся валидным.
    if DoF.Effects then
        DoF.Effects.PlayerEffects = self.db.global.playerEffects
        DoF.Effects.NPCEffects    = self.db.global.npcEffects
        DoF.Effects.Cooldowns     = self.db.global.effectCooldowns
    end

    -- TTL-чистка unitData: удаляем NPC, которых не видели >7 дней. Без этого
    -- база растёт неограниченно (мастер создаёт сессионные NPC, они копятся в
    -- db.global.unitData у каждого, у кого был бой). При большой базе риск
    -- SAVED_VARIABLES_TOO_LARGE в 9.2.7.
    local UNIT_DATA_TTL = 7 * 24 * 60 * 60  -- 7 дней в секундах
    if self.db.global and self.db.global.unitData and GetServerTime and GetServerTime() > 0 then
        local now = GetServerTime()
        local pruned = 0
        for guid, data in pairs(self.db.global.unitData) do
            -- Записи без lastSeenAt — наследие старых версий, прощаем их.
            -- Новые записи получают lastSeenAt в Units:Set.
            if data.lastSeenAt and (now - data.lastSeenAt) > UNIT_DATA_TTL then
                self.db.global.unitData[guid] = nil
                pruned = pruned + 1
            end
        end
        if pruned > 0 then
            print(DoF.Locale:Format("core.init.pruned_npcs", pruned))
        end
    end

    -- Регистрация префикса для коммуникации
    self:RegisterComm(DoF.Config.ADDON_PREFIX)

    -- Проверяем, что префикс действительно зарегистрирован: в 9.2.7 клиент
    -- игнорирует CHAT_MSG_ADDON для незарегистрированных префиксов, и адон
    -- просто не получает ни одного входящего сообщения. AceComm не проверяет
    -- возврат C_ChatInfo.RegisterAddonMessagePrefix (редко, но теоретически
    -- возможен отказ при переполнении глобального лимита 512 префиксов).
    -- Делаем defensive-проверку и сообщаем пользователю — иначе отладка
    -- «почему ничего не синкается» займёт часы.
    if C_ChatInfo and C_ChatInfo.IsAddonMessagePrefixRegistered then
        if not C_ChatInfo.IsAddonMessagePrefixRegistered(DoF.Config.ADDON_PREFIX) then
            -- Пытаемся зарегистрировать ещё раз напрямую
            local ok = C_ChatInfo.RegisterAddonMessagePrefix(DoF.Config.ADDON_PREFIX)
            if not ok then
                print(DoF.Locale:Format("core.init.prefix_failed", DoF.Config.ADDON_PREFIX))
            end
        end
    end

end

function Addon:OnEnable()
    -- Регистрация событий
    self:RegisterEvent("GROUP_ROSTER_UPDATE")
    self:RegisterEvent("PLAYER_TARGET_CHANGED")
    self:RegisterEvent("NAME_PLATE_UNIT_ADDED")
    self:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
    self:RegisterEvent("PLAYER_ENTERING_WORLD")
    self:RegisterEvent("UNIT_PORTRAIT_UPDATE")

    -- Инициализация модулей
    if DoF.Stats then DoF.Stats:Init() end
    if DoF.Units then DoF.Units:Init() end
    if DoF.Passives then DoF.Passives:Init() end
    if DoF.NPCLibrary then DoF.NPCLibrary:Init() end
    if DoF.Sync then DoF.Sync:Init() end
    if DoF.Settings then
        DoF.Settings:Init()
        if DoF.Settings.RegisterPanel then DoF.Settings.RegisterPanel() end
    end
    if DoF.UI then DoF.UI:Init() end

    -- Heartbeat мастера: запуск при становлении мастером, остановка при потере
    -- статуса. Heartbeat нужен не только в бою (для детекции рассинхрона HP),
    -- но и как liveness-сигнал — без него нельзя определить, жив ли ещё мастер
    -- после его /reload или краша в момент простоя между боями.
    DoF.Events:Register("MASTER_CHANGED", function()
        if not DoF.Sync then return end
        if DoF.Sync:IsMaster() and IsInGroup() then
            DoF.Sync:StartHeartbeat()
            DoF.Sync:StopMasterLivenessMonitor()
        else
            DoF.Sync:StopHeartbeat()
            -- Не-мастер отслеживает liveness мастера
            if IsInGroup() and DoF.Sync.MasterName then
                DoF.Sync:StartMasterLivenessMonitor()
            end
        end
    end, "Init_Heartbeat_MasterChanged")

    -- На всякий случай подхватываем начальное состояние
    DoF.Events:Register("COMBAT_ENDED", function()
        -- Только если мы не мастер — мастер продолжает heartbeat между боями.
        if DoF.Sync and not DoF.Sync:IsMaster() then
            DoF.Sync:StopHeartbeat()
        end
    end, "Init_Heartbeat_CombatEnded")

    -- Инициализация Unit Frames (после загрузки UI)
    self:ScheduleTimer(function()
        if DoF.UI and DoF.UI.UnitFrames then
            DoF.UI.UnitFrames:Init()
        end
    end, 0.5)

    -- Инициализация Action Bar
    self:ScheduleTimer(function()
        if DoF.ActionBar then
            DoF.ActionBar:Init()
        end
    end, 0.6)
    
    -- Восстановление усталости лечения из SavedVariables (после перелогина в бою)
    if DoF.Combat and DoF.db.char.healingFatigue then
        local myName = UnitName("player")
        local saved = DoF.db.char.healingFatigue
        DoF.Combat.HealingFatigue[myName] = { count = saved.count or 0 }
        if saved.stacks and saved.stacks > 0 and DoF.Effects then
            DoF.Effects:ApplyInternal("player", myName, "healing_fatigue", saved.stacks, 999)
        end
    end

    -- Подавляем ранние сообщения до загрузки ростера (без "Заблокировано" в чате)
    -- Данные будут запрошены заново через REQUESTHP после полной загрузки мира
    if DoF.Sync then
        DoF.Sync._suppressEarlyMessages = true
        self:ScheduleTimer(function()
            DoF.Sync._suppressEarlyMessages = false
        end, 10)
        -- Запускаем периодическую очистку дедупликации ACK/Retry
        DoF.Sync:StartReliableCleanup()
    end

    -- Отложенная инициализация после полной загрузки
    self:ScheduleTimer(function()
        if DoF.Sync then
            DoF.Sync:UpdateMasterStatus()
            if IsInGroup() then
                DoF.Sync:BroadcastPlayerData()
                DoF.Sync:Send("REQUESTHP")
                if DoF.Sync:IsMaster() then
                    -- Мастер: восстановление через выделенный метод
                    DoF.Sync:PerformMasterRecovery()
                else
                    -- Не-мастер: запрашиваем данные НПЦ и состояние от мастера
                    DoF.Sync:RequestFullData()
                    DoF.Sync:Send("COMBAT_STATE_REQUEST")
                end
            end
        end

        -- Применяем масштаб UI
        if DoF.Utils then
            DoF.Utils:ApplyUIScale()
        end
    end, 2)
    
    DoF.Utils:Info(DoF.Locale:Format("core.init.loaded", DoF.Config.VERSION))
end

function Addon:OnDisable()
    -- Отключение (если нужно)
end

-- ═══════════════════════════════════════════════════════════
-- ОБРАБОТЧИКИ СОБЫТИЙ
-- ═══════════════════════════════════════════════════════════

-- Дебаунс GROUP_ROSTER_UPDATE. Blizzard fire'ит событие ~40 раз подряд при
-- входе в рейд 40 человек (по одному на каждого в ростере). Вместо обычного
-- throttle (игнорить до окончания окна) используем debounce: каждый новый
-- вызов сбрасывает таймер, и действие выполняется один раз после паузы.
-- Это собирает всю бурю событий в один тик.
local _rosterDebounceTimer = nil

function Addon:GROUP_ROSTER_UPDATE()
    if DoF.Sync then
        -- UpdateMasterStatus и CleanupRaidData дешёвые и должны выполняться сразу,
        -- чтобы IsMaster() возвращал корректное значение немедленно.
        DoF.Sync:UpdateMasterStatus()
        DoF.Sync:CleanupRaidData()

        -- Дорогостоящие broadcast/request дебаунсим: собираем 40 быстрых событий
        -- в один тик через 1.5с после последнего вызова.
        if IsInGroup() then
            if _rosterDebounceTimer then
                self:CancelTimer(_rosterDebounceTimer)
            end
            _rosterDebounceTimer = self:ScheduleTimer(function()
                _rosterDebounceTimer = nil
                if not IsInGroup() then return end
                DoF.Sync:BroadcastPlayerData()
                DoF.Sync:RequestMissingPlayerData()
                if not DoF.Sync:IsMaster() then
                    DoF.Sync:RequestFullData()
                end
            end, 1.5)
        end

        -- Мастер-рекавери: если ещё не выполнено — выполняем сейчас
        -- (покрывает случай, когда deferred-таймер отработал раньше IsInGroup)
        if IsInGroup() and DoF.Sync:IsMaster() then
            DoF.Sync:PerformMasterRecovery()
        end
    end

end

function Addon:PLAYER_TARGET_CHANGED()
    if DoF.UI then
        -- Обязательно обновляем эффекты цели при смене
        if DoF.UI.Effects then
            DoF.UI.Effects:UpdateTarget()
        end
        -- Обновляем фрейм цели и эффекты
        if DoF.UI.UnitFrames then
            DoF.UI.UnitFrames:UpdateTargetFrame()
            DoF.UI.UnitFrames:UpdateTargetEffects()
        end
    end
end

function Addon:NAME_PLATE_UNIT_ADDED(event, unitId)
    local nameplate = C_NamePlate.GetNamePlateForUnit(unitId)
    if nameplate and DoF.UI then
        DoF.UI:UpdateNameplateFrame(nameplate, unitId)
    end
end

function Addon:NAME_PLATE_UNIT_REMOVED(event, unitId)
    local nameplate = C_NamePlate.GetNamePlateForUnit(unitId)
    if nameplate and DoF.UI and DoF.UI.NameplateFrames[nameplate] then
        DoF.UI.NameplateFrames[nameplate]:Hide()
    end
end

function Addon:UNIT_PORTRAIT_UPDATE(event, unit)
    if DoF.UI and DoF.UI.UnitFrames then
        if unit == "player" then
            DoF.UI.UnitFrames:UpdatePlayerFrame()
        end
        if unit == "target" then
            DoF.UI.UnitFrames:UpdateTargetFrame()
        end
    end
end

function Addon:PLAYER_ENTERING_WORLD()
    -- Обновляем юнит-фреймы при входе в мир (портреты)
    if DoF.UI and DoF.UI.UnitFrames then
        self:ScheduleTimer(function()
            DoF.UI.UnitFrames:UpdatePlayerFrame()
        end, 0.5)
    end

    if DoF.Sync then
        -- НЕ вызываем UpdateMasterStatus до загрузки группы —
        -- иначе FindMaster вернёт fallback на игрока (ложный мастер)
        if IsInGroup() then
            DoF.Sync:UpdateMasterStatus()
        end
        DoF.Sync:BroadcastPlayerData()

        -- Предложение очистки NPC при входе без группы
        if not IsInGroup() and not DoF.Sync._loginCleanupShown then
            DoF.Sync._loginCleanupShown = true
            local npcCount = DoF.Units and DoF.Units:Count() or 0
            if npcCount > 0 then
                Addon:ScheduleTimer(function()
                    if IsInGroup() then return end
                    StaticPopup_Show("DoF_LOGIN_CLEANUP_NPC", tostring(npcCount))
                end, 2)
            end
        end

        -- Ресинк после входа в мир: три попытки с экспоненциальным интервалом
        -- (0.5 / 1.5 / 3.5 сек). Фиксированная задержка 4с покрывала случай
        -- медленной загрузки ростера, но теряла ~4 секунды активной боевой
        -- сессии на быстрой загрузке. Экспоненциал даёт быстрый ресинк на
        -- типичной загрузке, fallback на 3.5с если ростер ещё не готов.
        if not DoF.Sync._worldRecoveryScheduled then
            DoF.Sync._worldRecoveryScheduled = true
            local attempts = { 0.5, 1.5, 3.5 }
            local function tryRecover(attempt)
                if not DoF.Sync or not IsInGroup() then return end
                -- Проверяем, что ростер наполнен (для неслабых групп)
                if GetNumGroupMembers() == 0 then
                    if attempt < #attempts then
                        Addon:ScheduleTimer(function()
                            tryRecover(attempt + 1)
                        end, attempts[attempt + 1])
                    end
                    return
                end
                -- Ростер загружен — отключаем подавление и делаем ресинк
                DoF.Sync._suppressEarlyMessages = false
                DoF.Sync:UpdateMasterStatus()
                DoF.Sync:BroadcastPlayerData()
                DoF.Sync:Send("REQUESTHP")
                if DoF.Sync:IsMaster() then
                    DoF.Sync:StartHeartbeat()
                    DoF.Sync:PerformMasterRecovery()
                else
                    DoF.Sync:StartMasterLivenessMonitor()
                    DoF.Sync:RequestFullData()
                    DoF.Sync:Send("COMBAT_STATE_REQUEST")
                end
            end
            Addon:ScheduleTimer(function() tryRecover(1) end, attempts[1])
        end
    end
end

-- ═══════════════════════════════════════════════════════════
-- ДИАЛОГ ОЧИСТКИ NPC ПРИ ВХОДЕ БЕЗ ГРУППЫ
-- ═══════════════════════════════════════════════════════════

StaticPopupDialogs["DoF_LOGIN_CLEANUP_NPC"] = {
    text = DoF.L["core.init.stale_data_confirm"],
    button1 = DoF.L["core.init.clear"],
    button2 = DoF.L["core.init.keep"],
    OnAccept = function()
        DoF.db.global.unitData = {}
        DoF.Events:Fire("UNITS_CLEARED")
        DoF.Utils:Info(DoF.L["core.init.stale_data_cleared"])
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

-- ═══════════════════════════════════════════════════════════
-- ОБРАБОТКА СООБЩЕНИЙ (AceComm)
-- ═══════════════════════════════════════════════════════════

function Addon:OnCommReceived(prefix, message, distribution, sender)
    if prefix == DoF.Config.ADDON_PREFIX and DoF.Sync then
        DoF.Sync:OnMessage(message, sender)
    end
end

-- ═══════════════════════════════════════════════════════════
-- SLASH КОМАНДЫ - СПРАВКА
-- ═══════════════════════════════════════════════════════════

SLASH_DOFHELP1 = "/dofhelp"
SLASH_DOFHELP2 = "/dof?"
SlashCmdList["DOFHELP"] = function()
    if DoF.Dialogs then
        DoF.Dialogs:ShowHelpWindow()
    end
end

-- ═══════════════════════════════════════════════════════════
-- SLASH КОМАНДЫ - ОСНОВНЫЕ
-- ═══════════════════════════════════════════════════════════

SLASH_DOF1 = "/dof"
SlashCmdList["DOF"] = function(msg)
    local cmd = msg:lower():trim()
    
    if cmd == "" then
        if DoF.UI then DoF.UI:ToggleCharacterSidebar() end
    elseif cmd == "help" then
        SlashCmdList["DOFHELP"]()
    elseif cmd == "reset" then
        if DoF.UI then DoF.UI:TryResetStats() end
    elseif cmd == "fullreset" then
        if DoF.Stats then DoF.Stats:FullReset() end
    elseif cmd == "log" then
        if DoF.CombatLog then DoF.CombatLog:Toggle() end
    elseif cmd == "master" then
        if DoF.UI then DoF.UI:ToggleMasterFrame() end
    elseif cmd == "settings" or cmd == "options" or cmd == "config" then
        if DoF.Dialogs then DoF.Dialogs:ToggleSettings() end
    elseif cmd == "sync" then
        if not IsInGroup() then
            DoF.Utils:Error(DoF.L["errors.not_in_group"])
            return
        end
        if DoF.Sync then
            if DoF.Sync:IsMaster() then
                DoF.Sync:BroadcastFullData()
                DoF.Utils:Info(DoF.L["core.init.data_sent"])
            else
                DoF.Sync:RequestFullData()
                DoF.Utils:Info(DoF.L["core.init.request_sent"])
            end
        end
    elseif cmd == "stats" then
        if DoF.Stats then DoF.Stats:PrintStats() end
    elseif cmd == "level" then
        -- Показать информацию об уровне
        if DoF.Stats then
            local level = DoF.Stats:GetLevel()
            local pointsLeft = DoF.Stats:GetPointsLeft()
            local totalPoints = DoF.Stats:GetTotalPoints()

            print(DoF.L["core.init.level_header"])
            print(DoF.Locale:Format("core.init.level_line", level, DoF.Config.MAX_LEVEL))
            print(DoF.Locale:Format("core.init.points_line", pointsLeft, totalPoints))
            print(DoF.Locale:Format("core.init.base_hp_line", DoF.Config:GetBaseHPForLevel(level)))
            print(DoF.Locale:Format("core.init.max_energy_line", DoF.Config:GetMaxEnergyForLevel(level)))
        end
    elseif cmd == "frames" or cmd == "frame" or cmd == "uf" then
        -- Управление Unit Frames
        if DoF.UI and DoF.UI.UnitFrames then
            DoF.UI.UnitFrames:TogglePlayerFrame()
        end
    elseif cmd == "frames reset" then
        -- Сброс позиций фреймов
        if DoF.UI and DoF.UI.UnitFrames then
            DoF.UI.UnitFrames:ResetPosition("player")
            DoF.UI.UnitFrames:ResetPosition("target")
            DoF.Utils:Info(DoF.L["core.init.frames_reset"])
        end
    elseif cmd == "frames lock" then
        -- Блокировка фреймов
        if DoF.UI and DoF.UI.UnitFrames then
            DoF.UI.UnitFrames:ToggleLock()
        end
    end
end

-- ═══════════════════════════════════════════════════════════
-- SLASH КОМАНДЫ - UNIT FRAMES
-- ═══════════════════════════════════════════════════════════

SLASH_DOFFRAMES1 = "/dofframes"
SLASH_DOFFRAMES2 = "/dofuf"
SlashCmdList["DOFFRAMES"] = function(msg)
    local cmd = msg:lower():trim()

    if cmd == "" or cmd == "toggle" then
        if DoF.UI and DoF.UI.UnitFrames then
            DoF.UI.UnitFrames:TogglePlayerFrame()
        end
    elseif cmd == "reset" then
        if DoF.UI and DoF.UI.UnitFrames then
            DoF.UI.UnitFrames:ResetPosition("player")
            DoF.UI.UnitFrames:ResetPosition("target")
            DoF.Utils:Info(DoF.L["core.init.frames_reset"])
        end
    elseif cmd == "lock" then
        if DoF.UI and DoF.UI.UnitFrames then
            DoF.UI.UnitFrames:ToggleLock()
        end
    elseif cmd == "player" then
        if DoF.UI and DoF.UI.UnitFrames then
            DoF.UI.UnitFrames:TogglePlayerFrame()
        end
    elseif cmd == "target" then
        if DoF.UI and DoF.UI.UnitFrames then
            DoF.UI.UnitFrames:ToggleTargetFrame()
        end
    else
        print("|cFFFFD700=== Unit Frames ===|r")
        print(DoF.L["core.init.help_frames"])
    end
end

-- ═══════════════════════════════════════════════════════════
-- SLASH КОМАНДЫ - ACTION BAR
-- ═══════════════════════════════════════════════════════════

SLASH_DOFBAR1 = "/dofbar"
SlashCmdList["DOFBAR"] = function(msg)
    local cmd = (msg or ""):lower():trim()
    if cmd == "" or cmd == "toggle" then
        if DoF.ActionBar then DoF.ActionBar:Toggle() end
    elseif cmd == "lock" then
        if DoF.ActionBar then DoF.ActionBar:ToggleLock() end
    elseif cmd == "reset" then
        if DoF.ActionBar then DoF.ActionBar:ResetPosition() end
    else
        print("|cFFFFD700=== Action Bar ===|r")
        print(DoF.L["core.init.help_bar"])
    end
end

-- ═══════════════════════════════════════════════════════════
-- SLASH КОМАНДЫ - РОЛИ (бывшие специализации)
-- ═══════════════════════════════════════════════════════════

SLASH_DOFROLE1 = "/dofrole"
SLASH_DOFROLE2 = "/dofspec"  -- Алиас для совместимости
SlashCmdList["DOFROLE"] = function(msg)
    msg = msg:trim()
    
    if msg == "" then
        -- Выбор своей роли
        if not DoF.Stats:CanChooseRole() then
            DoF.Utils:Error(DoF.Locale:Format("errors.level_required", DoF.Config.ROLE_REQUIRED_LEVEL))
            return
        end
        if DoF.Dialogs then
            DoF.Dialogs:ShowRoleMenu()
        end
        return
    end
    
    if not DoF.Utils:RequireMaster(false) then return end

    local target, role = msg:match("^(%S+)%s+(%S+)$")
    if not target or not role then
        DoF.Utils:Error(DoF.L["core.usage.role"])
        return
    end
    
    role = role:lower()
    if role == "none" or role == "reset" then
        role = nil
    elseif role ~= "tank" and role ~= "dd" and role ~= "healer" then
        DoF.Utils:Error(DoF.L["core.usage.roles_list"])
        return
    end
    
    DoF.Sync:SetSpec(target, role)
end

-- ═══════════════════════════════════════════════════════════
-- SLASH КОМАНДЫ - РАНЕНИЯ
-- ═══════════════════════════════════════════════════════════

SLASH_DOFWOUND1 = "/dofwound"
SlashCmdList["DOFWOUND"] = function(msg)
    if not DoF.Utils:RequireMaster(false) then return end
    
    local target = msg:trim()
    if target == "" then
        -- Использовать цель
        local guid, name = DoF.Utils:GetTargetGUID()
        if not guid or not DoF.Utils:IsTargetPlayer() then
            DoF.Utils:Error(DoF.L["core.usage.wound"])
            return
        end
        target = name
    end
    
    DoF.Sync:AddWound(target)
end

SLASH_DOFHEALWOUND1 = "/dofhealwound"
SLASH_DOFHEALWOUND2 = "/dofunwound"
SlashCmdList["DOFHEALWOUND"] = function(msg)
    if not DoF.Utils:RequireMaster(false) then return end
    
    local target = msg:trim()
    if target == "" then
        local guid, name = DoF.Utils:GetTargetGUID()
        if not guid or not DoF.Utils:IsTargetPlayer() then
            DoF.Utils:Error(DoF.L["core.usage.healwound"])
            return
        end
        target = name
    end
    
    DoF.Sync:RemoveWound(target)
end

-- AoE Исцеление
SLASH_DOFAOEHEAL1 = "/dofaoeheal"
SlashCmdList["DOFAOEHEAL"] = function()
    DoF.Combat:StartAoEHeal()
end

SLASH_DOFAOEBUFF1 = "/dofaoebuff"
SlashCmdList["DOFAOEBUFF"] = function(msg)
    local effectId = msg and msg:trim() or ""
    if effectId == "" then
        DoF.Utils:Info(DoF.L["core.usage.aoebuff"])
        DoF.Utils:Info(DoF.L["core.usage.aoebuff_example"])
        return
    end
    DoF.Combat:StartAoEBuff(effectId)
end

-- ═══════════════════════════════════════════════════════════
-- SLASH КОМАНДЫ - ЩИТ
-- ═══════════════════════════════════════════════════════════

SLASH_DOFSHIELD1 = "/dofshield"
SlashCmdList["DOFSHIELD"] = function()
    if DoF.Combat then
        DoF.Combat:Shield()
    end
end

-- ═══════════════════════════════════════════════════════════
-- SLASH КОМАНДЫ - HP NPC
-- ═══════════════════════════════════════════════════════════

SLASH_DOFHP1 = "/dofhp"
SlashCmdList["DOFHP"] = function(msg)
    msg = msg:trim()
    local guid, name = DoF.Utils:GetTargetGUID()
    
    if not guid then
        DoF.Utils:Error(DoF.L["errors.no_target"])
        return
    end
    
    if UnitIsPlayer("target") then
        DoF.Utils:Error(DoF.L["errors.not_for_players"])
        return
    end
    
    if msg == "" then
        -- Показать HP
        local data = DoF.Units:Get(guid)
        if data then
            DoF.Utils:Info(DoF.Locale:Format("core.cmd.npc_line", name, data.hp, data.maxHp,
                data.fort, data.reflex, data.will))
        else
            DoF.Utils:Warn(DoF.Locale:Format("core.cmd.npc_no_hp", name))
        end
        return
    end
    
    if not DoF.Utils:RequireMaster(false) then return end

    -- Формат current/max. Используем SetHP, а не Set — он сохраняет существующие
    -- fort/reflex/will. Set без 6-ти параметров сбрасывает защиты к дефолту 10
    -- и «слетает» применённый шаблон.
    local cur, max = msg:match("^(%d+)/(%d+)$")
    if cur and max then
        DoF.Units:SetHP(guid, name, tonumber(cur), tonumber(max))
        return
    end

    -- Просто число
    local hp = tonumber(msg)
    if hp then
        if hp <= 0 then
            DoF.Units:Remove(guid)
            DoF.Utils:Warn(DoF.Locale:Format("core.cmd.npc_data_removed", name))
        else
            DoF.Units:SetHP(guid, name, hp, hp)
            DoF.Utils:Info(name .. ": HP " .. hp .. "/" .. hp)
        end
        return
    end
    
    DoF.Utils:Error(DoF.L["core.usage.hp"])
end

-- ═══════════════════════════════════════════════════════════
-- SLASH КОМАНДЫ - АТАКА
-- ═══════════════════════════════════════════════════════════

SLASH_DOFATTACK1 = "/dofattack"
SlashCmdList["DOFATTACK"] = function(msg)
    local map = { str = "Strength", dex = "Dexterity", int = "Intelligence" }
    local stat = map[msg:trim():lower()]
    
    if stat and DoF.Combat then
        DoF.Combat:Attack(stat)
    else
        DoF.Utils:Error(DoF.L["core.usage.attack"])
    end
end

-- Исцеление
SLASH_DOFHEAL1 = "/dofheal"
SlashCmdList["DOFHEAL"] = function()
    if DoF.Combat then DoF.Combat:Heal() end
end

-- Проверка характеристики
SLASH_DOFCHECK1 = "/dofcheck"
SlashCmdList["DOFCHECK"] = function(msg)
    local map = { str = "Strength", dex = "Dexterity", int = "Intelligence", spi = "Spirit" }
    local stat = map[msg:trim():lower()]
    if stat and DoF.Combat then
        DoF.Combat:Check(stat)
    else
        DoF.Utils:Error(DoF.L["core.usage.check"])
    end
end

-- AoE атака
SLASH_DOFAOEATTACK1 = "/dofaoeattack"
SlashCmdList["DOFAOEATTACK"] = function(msg)
    local map = { str = "Strength", dex = "Dexterity", int = "Intelligence" }
    local stat = map[msg:trim():lower()]
    if stat and DoF.Combat then
        DoF.Combat:StartAoEAttack(stat)
    else
        DoF.Utils:Error(DoF.L["core.usage.aoeattack"])
    end
end

-- ═══════════════════════════════════════════════════════════
-- SLASH КОМАНДЫ - ПРОЧЕЕ
-- ═══════════════════════════════════════════════════════════

SLASH_DOFHPLIST1 = "/dofhplist"
SlashCmdList["DOFHPLIST"] = function()
    if DoF.Units then DoF.Units:PrintList() end
end

SLASH_DOFHPCLEAR1 = "/dofhpclear"
SlashCmdList["DOFHPCLEAR"] = function()
    if DoF.Units then DoF.Units:ClearAllConfirm() end
end

SLASH_DOFRESET1 = "/dofreset"
SlashCmdList["DOFRESET"] = function()
    if DoF.UI then DoF.UI:TryResetStats() end
end

SLASH_DOFSYNC1 = "/dofsync"
SlashCmdList["DOFSYNC"] = function()
    SlashCmdList["DOF"]("sync")
end

-- ═══════════════════════════════════════════════════════════
-- SLASH КОМАНДЫ - ПОШАГОВЫЙ БОЙ
-- ═══════════════════════════════════════════════════════════

SLASH_DOFCOMBAT1 = "/dofcombat"
SLASH_DOFCOMBAT2 = "/doffight"
SlashCmdList["DOFCOMBAT"] = function(msg)
    local cmd, arg = msg:match("^(%S*)%s*(.*)$")
    cmd = cmd:lower()
    
    if cmd == "start" or cmd == "" then
        -- /dofcombat start [секунды]
        if not DoF.Utils:RequireMaster(false) then return end
        local duration = tonumber(arg) or 60
        DoF.TurnSystem:StartCombat(duration)
        
    elseif cmd == "end" or cmd == "stop" then
        if not DoF.Utils:RequireMaster(false) then return end
        DoF.TurnSystem:EndCombat()
        
    elseif cmd == "skip" then
        if DoF.Sync:IsMaster() then
            DoF.TurnSystem:SkipTurn()
        else
            DoF.TurnSystem:PlayerSkipTurn()
        end
        
    elseif cmd == "npc" then
        if not DoF.Utils:RequireMaster(false) then return end
        DoF.TurnSystem:StartNPCTurn()
        
    elseif cmd == "players" then
        if not DoF.Utils:RequireMaster(false) then return end
        DoF.TurnSystem:StartPlayersTurn()
        
    elseif cmd == "add" then
        if not DoF.Utils:RequireMaster(false) then return end
        if arg == "" then
            DoF.Utils:Error(DoF.L["core.usage.combat_add"])
            return
        end
        DoF.TurnSystem:AddParticipant(arg)
        
    elseif cmd == "remove" or cmd == "kick" then
        if not DoF.Utils:RequireMaster(false) then return end
        if arg == "" then
            DoF.Utils:Error(DoF.L["core.usage.combat_remove"])
            return
        end
        DoF.TurnSystem:RemoveParticipant(arg)
        
    elseif cmd == "free" then
        if not DoF.Utils:RequireMaster(false) then return end
        if arg == "" then
            DoF.Utils:Error(DoF.L["core.usage.combat_free"])
            return
        end
        DoF.TurnSystem:GiveFreeAction(arg)
        
    elseif cmd == "queue" then
        if DoF.UI and DoF.UI.ToggleTurnQueue then
            DoF.UI:ToggleTurnQueue()
        end
        
    else
        print(DoF.L["core.init.help_combat"])
    end
end

SLASH_DOFSKIP1 = "/dofskip"
SlashCmdList["DOFSKIP"] = function()
    SlashCmdList["DOFCOMBAT"]("skip")
end

-- ═══════════════════════════════════════════════════════════
-- SLASH КОМАНДЫ - УПРАВЛЕНИЕ ИГРОКАМИ (МАСТЕР)
-- ═══════════════════════════════════════════════════════════

-- Задать роль игроку
SLASH_DOFSETROLE1 = "/dofsetrole"
SlashCmdList["DOFSETROLE"] = function(msg)
    if not DoF.Utils:RequireMaster(false) then return end

    local targetName = msg:trim()
    if targetName == "" then
        -- Используем цель
        local guid, name = DoF.Utils:GetTargetGUID()
        if not guid or not DoF.Utils:IsTargetPlayer() then
            DoF.Utils:Error(DoF.L["core.usage.setrole"])
            return
        end
        targetName = name
    end

    if DoF.Dialogs then
        DoF.Dialogs:ShowSetSpecMenu(targetName)
    end
end

-- Выдать игроку уровень DoF: /dofsetlevel [игрок] <уровень>
-- Без имени работает по текущей цели, как остальные команды мастера.
SLASH_DOFSETLEVEL1 = "/dofsetlevel"
SlashCmdList["DOFSETLEVEL"] = function(msg)
    if not DoF.Utils:RequireMaster(false) then return end

    local args = msg:trim()
    -- Имя может быть составным ("Имя-Реалм"), поэтому уровень отделяем с конца.
    local targetName, level = args:match("^(.-)%s+(%d+)$")
    if not targetName then
        level = args:match("^(%d+)$")
        targetName = ""
    end

    if not level then
        DoF.Utils:Error(DoF.L["core.usage.setlevel"])
        return
    end

    if targetName == "" then
        local guid, name = DoF.Utils:GetTargetGUID()
        if not guid or not DoF.Utils:IsTargetPlayer() then
            DoF.Utils:Error(DoF.L["core.usage.setlevel"])
            return
        end
        targetName = name
    end

    if DoF.Sync then
        DoF.Sync:SetPlayerLevel(targetName, level)
    end
end

-- Сбросить статы игрока
SLASH_DOFRESETSTATS1 = "/dofresetstats"
SlashCmdList["DOFRESETSTATS"] = function(msg)
    if not DoF.Utils:RequireMaster(false) then return end

    local targetName = msg:trim()
    if targetName == "" then
        -- Используем цель
        local guid, name = DoF.Utils:GetTargetGUID()
        if not guid or not DoF.Utils:IsTargetPlayer() then
            DoF.Utils:Error(DoF.L["core.usage.resetstats"])
            return
        end
        targetName = name
    end

    if DoF.Sync then
        DoF.Sync:ResetPlayerStats(targetName)
    end
end

-- Дать энергию игроку
SLASH_DOFGIVEENERGY1 = "/dofgiveenergy"
SlashCmdList["DOFGIVEENERGY"] = function(msg)
    if not DoF.Utils:RequireMaster(false) then return end

    local targetName = msg:trim()
    if targetName == "" then
        -- Используем цель
        local guid, name = DoF.Utils:GetTargetGUID()
        if not guid or not DoF.Utils:IsTargetPlayer() then
            DoF.Utils:Error(DoF.L["core.usage.giveenergy"])
            return
        end
        targetName = name
    end

    if DoF.Sync then
        DoF.Sync:GiveEnergy(targetName, 1)
    end
end

-- Восстановить полную энергию игроку
SLASH_DOFRESTOREENERGY1 = "/dofrestoreenergy"
SlashCmdList["DOFRESTOREENERGY"] = function(msg)
    if not DoF.Utils:RequireMaster(false) then return end

    local targetName = msg:trim()
    if targetName == "" then
        -- Используем цель
        local guid, name = DoF.Utils:GetTargetGUID()
        if not guid or not DoF.Utils:IsTargetPlayer() then
            DoF.Utils:Error(DoF.L["core.usage.restoreenergy"])
            return
        end
        targetName = name
    end

    if DoF.Sync then
        DoF.Sync:Send("RESTOREENERGY", targetName)
        DoF.Utils:Info(DoF.Locale:Format("ui.gm.energy_restored", DoF.Utils:Color("FFFFFF", targetName)))
    end
end

-- ═══════════════════════════════════════════════════════════
-- SLASH КОМАНДЫ - ДЕЙСТВИЯ С NPC/ИГРОКАМИ
-- ═══════════════════════════════════════════════════════════

-- Задать HP цели (NPC)
-- Использование: /dofsethp 100 (для текущей цели)
SLASH_DOFSETHP1 = "/dofsethp"
SlashCmdList["DOFSETHP"] = function(msg)
    if not DoF.Utils:RequireMaster(false) then return end

    local hp = tonumber(msg:trim())
    if not hp or hp <= 0 then
        DoF.Utils:Error(DoF.L["core.usage.sethp"])
        return
    end

    local guid, name = DoF.Utils:GetTargetGUID()
    if not guid then
        DoF.Utils:Error(DoF.L["errors.select_target"])
        return
    end

    if DoF.Utils:IsTargetPlayer() then
        DoF.Utils:Error(DoF.L["errors.cannot_set_player_hp"])
        return
    end

    if DoF.Units:SetHP(guid, name, hp, hp) then
        DoF.Utils:Info(name .. ": HP " .. hp .. "/" .. hp)
    end
end

-- Задать защиту NPC
-- Использование: /dofdefense 12 15 10 (fortitude reflex will для текущей цели)
SLASH_DOFDEFENSE1 = "/dofdefense"
SlashCmdList["DOFDEFENSE"] = function(msg)
    if not DoF.Utils:RequireMaster(false) then return end

    local fort, reflex, will = msg:match("^(%d+)%s+(%d+)%s+(%d+)$")
    if not fort or not reflex or not will then
        DoF.Utils:Error(DoF.L["core.usage.defense"])
        return
    end

    local guid, name = DoF.Utils:GetTargetGUID()
    if not guid then
        DoF.Utils:Error(DoF.L["errors.select_target"])
        return
    end

    if DoF.Utils:IsTargetPlayer() then
        DoF.Utils:Error(DoF.L["errors.cannot_set_player_defense"])
        return
    end

    DoF.Units:SetDefenses(guid, name, tonumber(fort), tonumber(reflex), tonumber(will))
    DoF.Utils:Info(DoF.Locale:Format("core.cmd.defense_set", name, fort, reflex, will))
end

-- Изменить HP NPC (±)
-- Использование: /dofmodifynpchp +50 или /dofmodifynpchp -20 (для текущей цели)
SLASH_DOFMODIFYNPCHP1 = "/dofmodifynpchp"
SlashCmdList["DOFMODIFYNPCHP"] = function(msg)
    if not DoF.Utils:RequireMaster(false) then return end

    local delta = tonumber(msg:trim())
    if not delta then
        DoF.Utils:Error(DoF.L["core.usage.modifynpchp"])
        return
    end

    local guid, name = DoF.Utils:GetTargetGUID()
    if not guid then
        DoF.Utils:Error(DoF.L["errors.select_target"])
        return
    end

    if DoF.Utils:IsTargetPlayer() then
        DoF.Utils:Error(DoF.L["errors.is_player_use_modify"])
        return
    end

    local data = DoF.Units:Get(guid)
    if not data then
        DoF.Utils:Error(DoF.Locale:Format("errors.npc_hp_not_set_for", name))
        return
    end

    local result
    if delta < 0 then
        result = DoF.Units:Damage(guid, -delta)
    else
        result = DoF.Units:Heal(guid, delta)
    end
    if result then
        local color = delta > 0 and "00FF00" or "FF0000"
        local sign = delta > 0 and "+" or ""
        DoF.Utils:Info(name .. ": HP " .. DoF.Utils:Color(color, sign .. delta) .. " (" .. data.hp .. "/" .. data.maxHp .. ")")
    end
end

-- Удалить NPC из базы
SLASH_DOFREMOVENPC1 = "/dofremovenpc"
SlashCmdList["DOFREMOVENPC"] = function()
    if not DoF.Utils:RequireMaster(false) then return end
    if DoF then
        DoF:RemoveTargetHP()
    end
end


-- Атака NPC на игрока
-- Функция подстановки %t -> имя цели
local function ResolveTarget(msg)
    if msg:find("%%t") then
        local targetName = UnitName("target")
        if not targetName then
            DoF.Utils:Error(DoF.L["errors.no_target_for_t"])
            return nil
        end
        return msg:gsub("%%t", targetName)
    end
    return msg
end

-- Атака NPC (мастер)
-- Использование: /dofnpcattack Игрок 5-10 15 Fortitude (или /dofnpcattack Игрок 10 15 Fort)
SLASH_DOFNPCATTACK1 = "/dofnpcattack"
SlashCmdList["DOFNPCATTACK"] = function(msg)
    if not DoF.Utils:RequireMaster(false) then return end

    msg = ResolveTarget(msg)
    if not msg then return end

    -- Разбиваем на аргументы
    local args = {}
    for arg in msg:gmatch("%S+") do
        table.insert(args, arg)
    end

    -- Минимум 4 аргумента: target, damage, threshold, defense
    if #args < 4 then
        DoF.Utils:Error(DoF.L["core.usage.npcattack"])
        DoF.Utils:Info(DoF.L["core.usage.npcattack_example"])
        DoF.Utils:Info(DoF.L["core.usage.npcattack_debuff"])
        return
    end

    local target = args[1]
    local damageStr = args[2]
    local threshold = tonumber(args[3])
    local defense = args[4]

    -- Парсим урон (диапазон или фиксированный)
    local dMin, dMax = damageStr:match("^(%d+)-(%d+)$")
    if not dMin then
        local d = tonumber(damageStr)
        if d then
            dMin, dMax = d, d
        end
    end

    if not dMin or not dMax or not threshold then
        DoF.Utils:Error(DoF.L["core.usage.npcattack"])
        return
    end

    -- Маппинг сокращений защиты
    local defenseMap = {
        fort = "Fortitude", fortitude = "Fortitude", f = "Fortitude",
        ref = "Reflex", reflex = "Reflex", r = "Reflex",
        will = "Will", w = "Will",
        hybrid = "Hybrid", hyb = "Hybrid", h = "Hybrid",
    }
    defense = defenseMap[defense:lower()] or defense

    local damageMin = tonumber(dMin)
    local damageMax = tonumber(dMax)
    if damageMin > damageMax then
        damageMin, damageMax = damageMax, damageMin
    end

    -- Проверяем валидность защиты
    if defense ~= "Fortitude" and defense ~= "Reflex" and defense ~= "Will" and defense ~= "Hybrid" then
        DoF.Utils:Error(DoF.L["core.usage.npcattack_defense"])
        return
    end

    -- Опциональные аргументы дебаффа (аргументы 5, 6, 7)
    local debuffId = args[5] or nil
    local debuffValue = tonumber(args[6]) or 0
    local debuffDuration = tonumber(args[7]) or 0

    -- Если дебафф указан как пустая строка или "none" — обнуляем
    if debuffId == "none" or debuffId == "" then
        debuffId = nil
    end

    if DoF.Combat then
        DoF.Combat:NPCAttack(target, damageMin, damageMax, threshold, defense, nil, debuffId, debuffValue, debuffDuration)
    end
end

-- Изменить HP игрока (±)
-- Использование: /dofmodifyplayerhp Игрок +10 или /dofmodifyplayerhp %t -5
SLASH_DOFMODIFYPLAYERHP1 = "/dofmodifyplayerhp"
SlashCmdList["DOFMODIFYPLAYERHP"] = function(msg)
    if not DoF.Utils:RequireMaster(false) then return end

    msg = ResolveTarget(msg)
    if not msg then return end

    local target, delta = msg:match("^(%S+)%s+([+-]?%d+)$")
    if not target or not delta then
        DoF.Utils:Error(DoF.L["core.usage.modifyplayerhp"])
        return
    end

    if DoF.Sync then
        DoF.Sync:ModifyPlayerHP(target, tonumber(delta))
    end
end

-- Добавить ранение игроку (на основе цели)
SLASH_DOFADDWOUND1 = "/dofaddwound"
SlashCmdList["DOFADDWOUND"] = function()
    if not DoF.Utils:RequireMaster(false) then return end
    if DoF.UI then
        DoF.UI:MasterAddWound()
    end
end

-- Снять ранение игроку (на основе цели)
SLASH_DOFREMWOUND1 = "/dofremwound"
SlashCmdList["DOFREMWOUND"] = function()
    if not DoF.Utils:RequireMaster(false) then return end
    if DoF.UI then
        DoF.UI:MasterRemoveWound()
    end
end

-- Дать щит игроку
-- Использование: /dofgiveshield Игрок
SLASH_DOFGIVESHIELD1 = "/dofgiveshield"
SlashCmdList["DOFGIVESHIELD"] = function(msg)
    if not DoF.Utils:RequireMaster(false) then return end

    local target = msg:match("^(%S+)$")
    if not target then
        DoF.Utils:Error(DoF.L["core.usage.giveshield"])
        return
    end

    if DoF.Sync then
        DoF.Sync:GiveShield(target)
    end
end

-- ═══════════════════════════════════════════════════════════
-- МАКРОСЫ ДЛЯ МАСТЕРА: БАФФЫ, ДЕБАФФЫ, ЭФФЕКТЫ НПЦ
-- ═══════════════════════════════════════════════════════════

-- Наложить бафф на игрока
-- /dofbuff <игрок|%t> <эффект> [значение] [раунды]
-- Эффекты: empower, fortify_fortitude, fortify_reflex, fortify_will, regeneration, blessing
SLASH_DOFBUFF1 = "/dofbuff"
SlashCmdList["DOFBUFF"] = function(msg)
    if not DoF.Utils:RequireMaster(false) then return end

    msg = ResolveTarget(msg)
    if not msg then return end

    local target, effectId, value, rounds = msg:match("^(%S+)%s+(%S+)%s*(%d*)%s*(%d*)$")
    if not target or not effectId then
        DoF.Utils:Error(DoF.L["core.usage.buff"])
        DoF.Utils:Info(DoF.L["core.usage.buff_effects"])
        return
    end

    local def = DoF.Effects.Definitions[effectId]
    if not def or def.type ~= "buff" then
        DoF.Utils:Error(DoF.Locale:Format("errors.unknown_buff", effectId))
        return
    end

    value = tonumber(value) or def.fixedValue or 1
    rounds = tonumber(rounds) or def.fixedDuration or 3

    DoF.Effects:Apply("player", target, effectId, value, rounds, DoF.L["combat.label.gm"])
    DoF.Effects:BroadcastAllEffects()
    DoF.Utils:Info(DoF.Locale:Format("core.cmd.buff_applied", def.name, target))
    DoF.Sync:BroadcastCombatLog(DoF.Locale:Format("core.cmd.master_applies_log", def.name, target, value, rounds))
end

-- Наложить дебафф на игрока
-- /dofdebuff <игрок|%t> <эффект> [значение] [раунды]
-- Эффекты: stun, weakness_damage, weakness_healing, vulnerability_fortitude, vulnerability_reflex, vulnerability_will, dot_master
SLASH_DOFDEBUFF1 = "/dofdebuff"
SlashCmdList["DOFDEBUFF"] = function(msg)
    if not DoF.Utils:RequireMaster(false) then return end

    msg = ResolveTarget(msg)
    if not msg then return end

    local target, effectId, value, rounds = msg:match("^(%S+)%s+(%S+)%s*(%d*)%s*(%d*)$")
    if not target or not effectId then
        DoF.Utils:Error(DoF.L["core.usage.debuff"])
        DoF.Utils:Info(DoF.L["core.usage.debuff_effects"])
        return
    end

    local def = DoF.Effects.Definitions[effectId]
    if not def or (def.type ~= "debuff" and def.type ~= "dot") then
        DoF.Utils:Error(DoF.Locale:Format("errors.unknown_debuff", effectId))
        return
    end

    value = tonumber(value) or def.fixedValue or 1
    rounds = tonumber(rounds) or def.fixedDuration or 2

    DoF.Effects:Apply("player", target, effectId, value, rounds, DoF.L["combat.label.gm"])
    DoF.Effects:BroadcastAllEffects()
    DoF.Utils:Info(DoF.Locale:Format("core.cmd.debuff_applied", def.name, target))
    DoF.Sync:BroadcastCombatLog(DoF.Locale:Format("core.cmd.master_applies_log", def.name, target, value, rounds))
end

-- Наложить эффект на НПЦ (по цели в игре)
-- /dofnpceffect <эффект> [значение] [раунды]
-- Эффекты: stun, weakness_fortitude, weakness_reflex, weakness_will, bleeding
SLASH_DOFNPCEFFECT1 = "/dofnpceffect"
SlashCmdList["DOFNPCEFFECT"] = function(msg)
    if not DoF.Utils:RequireMaster(false) then return end

    local effectId, value, rounds = msg:match("^(%S+)%s*(%d*)%s*(%d*)$")
    if not effectId then
        DoF.Utils:Error(DoF.L["core.usage.npceffect"])
        DoF.Utils:Info(DoF.L["core.usage.npceffect_effects"])
        return
    end

    local npcGuid = UnitGUID("target")
    if not npcGuid then
        DoF.Utils:Error(DoF.L["errors.select_npc_as_target"])
        return
    end

    local npcData = DoF.Units:Get(npcGuid)
    if not npcData then
        DoF.Utils:Error(DoF.L["errors.target_not_dof_npc"])
        return
    end

    local def = DoF.Effects.Definitions[effectId]
    if not def then
        DoF.Utils:Error(DoF.Locale:Format("errors.unknown_effect", effectId))
        return
    end

    value = tonumber(value) or def.fixedValue or 1
    rounds = tonumber(rounds) or def.fixedDuration or 2

    DoF.Effects:Apply("npc", npcGuid, effectId, value, rounds, DoF.L["combat.label.gm"])
    DoF.Effects:BroadcastAllEffects()
    local npcName = npcData.name or DoF.L["combat.npc_fallback"]
    DoF.Utils:Info(DoF.Locale:Format("core.cmd.effect_applied", def.name, npcName))
    DoF.Sync:BroadcastCombatLog(DoF.Locale:Format("core.cmd.master_applies_log", def.name, npcName, value, rounds))
end

-- Быстро оглушить НПЦ
-- /dofnpcstun [раунды]
SLASH_DOFNPCSTUN1 = "/dofnpcstun"
SlashCmdList["DOFNPCSTUN"] = function(msg)
    if not DoF.Utils:RequireMaster(false) then return end

    local rounds = tonumber(msg) or 1

    local npcGuid = UnitGUID("target")
    if not npcGuid then
        DoF.Utils:Error(DoF.L["errors.select_npc_as_target"])
        return
    end

    local npcData = DoF.Units:Get(npcGuid)
    if not npcData then
        DoF.Utils:Error(DoF.L["errors.target_not_dof_npc"])
        return
    end

    DoF.Effects:Apply("npc", npcGuid, "stun", 0, rounds, DoF.L["combat.label.gm"])
    DoF.Effects:BroadcastAllEffects()
    local npcName = npcData.name or DoF.L["combat.npc_fallback"]
    DoF.Utils:Info(DoF.Locale:Format("core.cmd.npc_stunned", npcName, rounds))
    DoF.Sync:BroadcastCombatLog(DoF.Locale:Format("core.cmd.npc_stunned_log", npcName, rounds))
end

-- ═══════════════════════════════════════════════════════════
-- SLASH КОМАНДЫ - МАСТЕР (ДОПОЛНИТЕЛЬНЫЕ)
-- ═══════════════════════════════════════════════════════════

-- Проверка версий группы
SLASH_DOFVERSION1 = "/dofversion"
SlashCmdList["DOFVERSION"] = function()
    if DoF.MasterCheckVersions then DoF:MasterCheckVersions() end
end


-- Снять бафф с цели
SLASH_DOFPURGE1 = "/dofpurge"
SlashCmdList["DOFPURGE"] = function()
    if DoF.MasterPurge then DoF:MasterPurge() end
end

-- Снять дебафф с цели
SLASH_DOFDISPEL1 = "/dofdispel"
SlashCmdList["DOFDISPEL"] = function()
    if DoF.MasterDispel then DoF:MasterDispel() end
end

-- Снять все эффекты с цели
SLASH_DOFCLEAREFFECTS1 = "/dofcleareffects"
SlashCmdList["DOFCLEAREFFECTS"] = function()
    if DoF.MasterClearAllEffects then DoF:MasterClearAllEffects() end
end

-- ═══════════════════════════════════════════════════════════
-- ИНФОРМАЦИЯ ОБ АДДОНЕ
-- ═══════════════════════════════════════════════════════════

function DoF:ShowAddonInfoTooltip(frame)
    DoF.Utils:ShowTooltip(frame, {
        { text = "DoF -- Dice of Fate", r = 1, g = 0.82, b = 0, size = 14 },
        { text = DoF.Locale:Format("core.init.about_version", DoF.Config.VERSION), r = 0.7, g = 0.7, b = 0.7 },
        { text = DoF.Locale:Format("core.init.about_author", DoF.Config.AUTHOR), r = 0.7, g = 0.7, b = 0.7 },
        { text = DoF.L["core.init.about_tagline"], r = 0.5, g = 0.5, b = 0.5, size = 11 },
    }, "BOTTOM")
end

-- ═══════════════════════════════════════════════════════════
-- СИСТЕМНЫЕ СООБЩЕНИЯ (ТОГГЛ)
-- ═══════════════════════════════════════════════════════════

function DoF:ToggleSystemMessages()
    if not DoF.Sync then return end
    -- Мастер всегда видит системные сообщения — переключатель влияет только на
    -- личную настройку рядового игрока, которая активируется когда он не мастер.
    DoF.db.profile.systemMessages = not DoF.db.profile.systemMessages
    DoF.Sync:_RecalcShowSystemMessages()
    if DoF.db.profile.systemMessages then
        DoF.Utils:Info(DoF.Locale:Format("core.init.system_messages", DoF.Utils:Color("00FF00", DoF.L["core.init.on"])))
    else
        DoF.Utils:Info(DoF.Locale:Format("core.init.system_messages", DoF.Utils:Color("FF6666", DoF.L["core.init.off"])))
    end
end

-- ПРОВЕРКА ВЕРСИЙ (МАСТЕР)
-- ═══════════════════════════════════════════════════════════

function DoF:MasterCheckVersions()
    if not DoF.Utils:RequireMaster() then return end
    if not IsInGroup() then
        DoF.Utils:Error(DoF.L["errors.not_in_group"])
        return
    end

    -- Очищаем старые данные
    DoF.Sync.VersionResponses = {}
    DoF.Sync.VersionCheckTime = GetTime()

    -- Запрашиваем версии
    DoF.Sync:Send("VERSION_REQUEST")
    DoF.Utils:Info(DoF.L["core.init.version_request_sent"])

    -- Через 3 секунды показываем результаты
    Addon:ScheduleTimer(function()
        DoF:ShowVersionCheckResults()
    end, 3)
end

function DoF:ShowVersionCheckResults()
    local responses = DoF.Sync.VersionResponses or {}
    local myName = UnitName("player")

    print(DoF.L["core.init.versions_header"])

    -- Добавляем себя
    print(string.format("  |cFFFFFFFF%s|r: |cFF00FF00%s|r", myName, DoF.Config.VERSION))

    -- Показываем ответы
    for name, version in pairs(responses) do
        local color = version == DoF.Config.VERSION and "00FF00" or "FF6666"
        print(string.format("  |cFFFFFFFF%s|r: |cFF%s%s|r", name, color, version))
    end

    -- Проверяем кто не ответил
    local noResponse = {}
    local numMembers = GetNumGroupMembers()
    local prefix = IsInRaid() and "raid" or "party"

    for i = 1, numMembers do
        local unit = prefix .. i
        local name = UnitName(unit)
        if name and name ~= myName and not responses[name] then
            table.insert(noResponse, name)
        end
    end

    if #noResponse > 0 then
        print(DoF.Locale:Format("core.init.no_response", table.concat(noResponse, ", ")))
    end
end
