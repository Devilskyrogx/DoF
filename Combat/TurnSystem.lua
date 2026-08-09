-- DoF/Combat/TurnSystem.lua
-- Пошаговая боевая система

local ADDON_NAME, DoF = ...

-- Кэширование глобальных функций
local math_random = math.random
local pairs = pairs
local ipairs = ipairs
local table_insert = table.insert
local table_remove = table.remove
local table_sort = table.sort
local tonumber = tonumber
local GetTime = GetTime
local UnitGUID = UnitGUID
local UnitName = UnitName
local UnitExists = UnitExists
local UnitIsConnected = UnitIsConnected
local IsInRaid = IsInRaid
local IsInGroup = IsInGroup
local GetNumGroupMembers = GetNumGroupMembers
local GetRaidRosterInfo = GetRaidRosterInfo
local C_Timer = C_Timer
local PlaySound = PlaySound
local strsplit = strsplit

DoF.TurnSystem = {
    -- Состояние
    phase = "idle",             -- idle / rolling / players / npc
    participants = {},          -- {{name, guid, roll, acted}, ...}
    participantsByGuid = {},    -- ИНДЕКС: guid -> participant (для быстрого поиска O(1))
    currentIndex = 0,           -- Индекс текущего игрока
    round = 0,                  -- Номер раунда

    -- Настройки
    mode = "free",              -- "queue" (очередь) или "free" (свободная)
    useTimer = false,           -- Использовать таймер или нет
    turnDuration = 60,          -- Секунды на ход
    turnStartTime = 0,          -- Время начала хода

    -- Свободная очередь
    actedThisRound = {},        -- Список GUID кто сходил в этом раунде (для free mode)
    roundStartTime = 0,         -- Время начала раунда (для free mode с таймером)

    -- Специальные
    freeActionGUID = nil,       -- Кто может ходить вне очереди

    -- Таймер
    timerHandle = nil,
}

-- ═══════════════════════════════════════════════════════════
-- УТИЛИТЫ
-- ═══════════════════════════════════════════════════════════

-- Проверяет, является ли игрок участником текущего боя
function DoF.TurnSystem:IsParticipant(guid)
    if not guid then guid = UnitGUID("player") end
    -- Используем индекс для O(1) поиска
    if self.participantsByGuid then
        return self.participantsByGuid[guid] ~= nil
    end
    -- Fallback на линейный поиск
    for _, p in ipairs(self.participants) do
        if p.guid == guid then
            return true
        end
    end
    return false
end

-- Построить индекс участников для быстрого поиска
function DoF.TurnSystem:BuildParticipantIndex()
    self.participantsByGuid = {}
    for _, p in ipairs(self.participants) do
        self.participantsByGuid[p.guid] = p
    end
end

local function GetGroupMembers()
    local members = {}
    
    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            local name, _, _, _, _, _, _, online = GetRaidRosterInfo(i)
            if name and online then
                local guid = UnitGUID("raid" .. i)
                if guid then
                    table_insert(members, {name = name, guid = guid})
                end
            end
        end
    elseif IsInGroup() then
        -- Добавляем себя
        local myName = UnitName("player")
        local myGUID = UnitGUID("player")
        table_insert(members, {name = myName, guid = myGUID})
        
        -- Добавляем членов группы
        for i = 1, GetNumGroupMembers() - 1 do
            local unit = "party" .. i
            if UnitExists(unit) and UnitIsConnected(unit) then
                local name = UnitName(unit)
                local guid = UnitGUID(unit)
                if name and guid then
                    table_insert(members, {name = name, guid = guid})
                end
            end
        end
    else
        -- Соло — только игрок
        local myName = UnitName("player")
        local myGUID = UnitGUID("player")
        table_insert(members, {name = myName, guid = myGUID})
    end
    
    return members
end

-- ═══════════════════════════════════════════════════════════
-- ИНИЦИАТИВА
-- ═══════════════════════════════════════════════════════════

function DoF.TurnSystem:RollInitiative(excludeMaster)
    local members = GetGroupMembers()
    self.participants = {}
    
    local masterGUID = nil
    if excludeMaster and DoF.Sync:IsMaster() then
        masterGUID = UnitGUID("player")
    end
    
    for _, member in ipairs(members) do
        -- Пропускаем мастера если excludeMaster
        if not (excludeMaster and member.guid == masterGUID) then
            local roll = math_random(1, 100)
            table_insert(self.participants, {
                name = member.name,
                guid = member.guid,
                roll = roll,
                acted = false,
            })
        end
    end
    
    -- Сортировка по убыванию (больше = раньше)
    table_sort(self.participants, function(a, b)
        return a.roll > b.roll
    end)
    
    -- Построить индекс для быстрого поиска
    self:BuildParticipantIndex()
end

-- Собирает участников без броска инициативы (для свободного режима)
function DoF.TurnSystem:GatherParticipants(excludeMaster)
    local members = GetGroupMembers()
    self.participants = {}

    local masterGUID = nil
    if excludeMaster and DoF.Sync:IsMaster() then
        masterGUID = UnitGUID("player")
    end

    for _, member in ipairs(members) do
        -- Пропускаем мастера если excludeMaster
        if not (excludeMaster and member.guid == masterGUID) then
            table_insert(self.participants, {
                name = member.name,
                guid = member.guid,
                roll = 0,  -- Нет броска в свободном режиме
                acted = false,
            })
        end
    end

    -- Сортировки нет в свободном режиме
    -- Построить индекс для быстрого поиска
    self:BuildParticipantIndex()
end

-- ═══════════════════════════════════════════════════════════
-- УПРАВЛЕНИЕ БОЕМ (МАСТЕР)
-- ═══════════════════════════════════════════════════════════

function DoF.TurnSystem:StartCombat(mode, useTimer, duration, excludeMaster)
    if not DoF.Sync:IsMaster() then
        DoF.Utils:Error(DoF.L["errors.gm_only_start_combat"])
        return false
    end

    self.mode = mode or "free"
    self.useTimer = useTimer or false
    self.turnDuration = duration or 60
    self.phase = "rolling"
    self.round = 0
    self.freeActionGUID = nil
    self.masterExcluded = excludeMaster or false
    self.actedThisRound = {}
    self.roundStartTime = 0
    self.turnDeadlineServer = 0
    self.roundDeadlineServer = 0

    -- Выбираем способ формирования списка участников
    if self.mode == "queue" then
        -- Очередной режим - бросаем инициативу
        self:RollInitiative(excludeMaster)
    else
        -- Свободный режим - собираем без броска
        self:GatherParticipants(excludeMaster)
    end

    if #self.participants == 0 then
        DoF.Utils:Error(DoF.L["errors.no_participants"])
        self.phase = "idle"
        return false
    end

    -- Событие
    DoF.Events:Fire("COMBAT_STARTED", self.participants)

    -- Синхронизация
    self:BroadcastCombatStart()

    -- Показываем окно очереди для ведущего
    if DoF.UI and DoF.UI.ShowTurnQueue then
        DoF.UI:ShowTurnQueue()
    end

    -- Начинаем первый раунд
    self:StartRound()

    return true
end

function DoF.TurnSystem:EndCombat()
    if not DoF.Sync:IsMaster() then
        DoF.Utils:Error(DoF.L["errors.gm_only_end_combat"])
        return
    end
    
    self:StopTimer()
    
    self.phase = "idle"
    self.participants = {}
    self.participantsByGuid = {}  -- Очищаем индекс
    self.currentIndex = 0
    self.round = 0
    self.freeActionGUID = nil
    
    -- Сброс усталости лечения и серии защит танка
    DoF.Combat.HealingFatigue = {}
    DoF.Combat.TankDefenseStreak = {}
    if DoF.db and DoF.db.char then DoF.db.char.healingFatigue = nil end

    -- Сброс AoE состояний (могут застрять при внезапном завершении боя)
    if DoF.Combat:IsAoEActive() then DoF.Combat:CancelAoE() end
    if DoF.Combat:IsAoEHealActive() then DoF.Combat:CancelAoEHeal() end
    if DoF.Combat:IsAoEBuffActive() then DoF.Combat:CancelAoEBuff() end
    if DoF.Combat:IsTauntAoEActive() then DoF.Combat:CancelTauntAoE() end
    if DoF.Combat:IsSpecialActionActive() then DoF.Combat:CancelSpecialAction() end

    -- Сброс трекера пробития защиты танка
    DoF.Combat.TankShredTracker = {}

    -- Сброс CritChoicePending
    DoF.Combat.CritChoicePending = false

    -- Сброс мгновенной защиты
    DoF.Combat.instantDefense = false
    local instantCb = DoF_GMPanel_InstantDefenseCheckBtn
    if instantCb then instantCb:SetChecked(false) end

    -- Очищаем все эффекты (баффы и дебаффы)
    if DoF.Effects then
        for playerName, _ in pairs(DoF.Effects.PlayerEffects) do
            DoF.Effects:ClearAll("player", playerName)
        end
        for guid, _ in pairs(DoF.Effects.NPCEffects) do
            DoF.Effects:ClearAll("npc", guid)
        end
        -- Сброс кулдаунов эффектов. wipe() вместо {} — чтобы не порвать
        -- ссылку на db.global.effectCooldowns (персистентность).
        wipe(DoF.Effects.Cooldowns)
    end

    -- Событие
    DoF.Events:Fire("COMBAT_ENDED")

    -- Синхронизация
    self:BroadcastCombatEnd()
    
    -- Показываем уведомление об окончании боя
    if DoF.UI and DoF.UI.ShowCombatEndAlert then
        DoF.UI:ShowCombatEndAlert()
    end
    
    -- Обновляем UI
    if DoF.UI and DoF.UI.UpdateTurnQueue then
        DoF.UI:UpdateTurnQueue()
    end
end

function DoF.TurnSystem:StartNPCTurn()
    if not DoF.Sync:IsMaster() then
        DoF.Utils:Error(DoF.L["errors.gm_only_phase"])
        return
    end

    self:StopTimer()
    self.phase = "npc"

    -- ══════ ОБРАБОТКА ДЕБАФФОВ НА ИГРОКАХ (тикают каждый ход NPC) ══════
    if DoF.Effects then
        -- Обрабатываем эффекты на игроках (DoT, HoT, уменьшение длительности)
        DoF.Effects:ProcessPlayerEffects()

        -- Тикаем оглушения для всех участников
        for _, p in ipairs(self.participants) do
            if DoF.Effects:IsStunned(p.name) then
                local stunEffect = DoF.Effects:Get("player", p.name, "stun")
                if stunEffect and stunEffect.pendingActivation then
                    -- Эффект наложен в эту NPC-фазу: активируем без тика длительности
                    stunEffect.pendingActivation = false
                    if DoF.Sync then
                        DoF.Sync:BroadcastCombatLogKey("combat.turn.stun_starts", DoF.Sync.Arg.key("effects.stun.name", "FFFF00"), DoF.Sync.Arg.color("FFFFFF", p.name))
                    end
                else
                    DoF.Effects:TickStun(p.name)
                end
            end
        end

        -- Синхронизируем эффекты
        if DoF.Sync and DoF.Sync:IsMaster() and IsInGroup() then
            DoF.Effects:BroadcastAllEffects()
        end
    end

    -- Синхронизация
    self:BroadcastPhaseChange("npc")

    -- Показываем уведомление
    if DoF.UI and DoF.UI.ShowNPCPhaseAlert then
        DoF.UI:ShowNPCPhaseAlert()
    end

    -- Обновляем UI
    if DoF.UI and DoF.UI.UpdateTurnQueue then
        DoF.UI:UpdateTurnQueue()
    end
end

function DoF.TurnSystem:StartPlayersTurn()
    if not DoF.Sync:IsMaster() then
        DoF.Utils:Error(DoF.L["errors.gm_only_phase"])
        return
    end
    
    -- Сбрасываем acted для нового раунда
    self:StartRound()
end

-- ═══════════════════════════════════════════════════════════
-- РАУНДЫ И ХОДЫ
-- ═══════════════════════════════════════════════════════════

function DoF.TurnSystem:StartRound()
    local isFirstRound = (self.round == 0)

    self.round = self.round + 1
    self.phase = "players"

    -- Сброс acted
    for _, p in ipairs(self.participants) do
        p.acted = false
    end
    self.actedThisRound = {}

    -- Сброс отложенных боевых состояний (контратака, HP-бафф танка, AoE)
    if DoF.Combat then
        if DoF.Combat.CounterattackState and DoF.Combat.CounterattackState.active then
            DoF.Combat:CounterattackCancel()
        end
        if DoF.Combat.TankHPBuffActive then
            DoF.Combat:TankHPBuffCancel()
        end
        if DoF.Combat:IsAoEActive() then DoF.Combat:CancelAoE() end
        if DoF.Combat:IsAoEHealActive() then DoF.Combat:CancelAoEHeal() end
        if DoF.Combat:IsAoEBuffActive() then DoF.Combat:CancelAoEBuff() end
        if DoF.Combat:IsTauntAoEActive() then DoF.Combat:CancelTauntAoE() end
        if DoF.Combat:IsSpecialActionActive() then DoF.Combat:CancelSpecialAction() end
    end

    -- ══════ ОБРАБОТКА ЭФФЕКТОВ (только мастер, не первый раунд) ══════
    if not isFirstRound and DoF.Sync:IsMaster() and DoF.Effects then
        -- Обрабатываем эффекты только на NPC (эффекты на игроках тикают в StartNPCTurn)
        DoF.Effects:ProcessNPCEffects()

        -- Обрабатываем пассивки NPC за раунд (регенерация и т.д.)
        if DoF.Passives then
            DoF.Passives:ProcessRoundPassives()
        end

        -- Логируем в боевой журнал
        if DoF.CombatLog then
            DoF.CombatLog:Add(DoF.Locale:Format("combat.turn.round_header", self.round))
        end
    end

    -- Синхронизация
    self:BroadcastRoundStart()

    -- Обновляем UI после обработки эффектов
    if not isFirstRound and DoF.UI and DoF.UI.UpdateTurnQueue then
        DoF.UI:UpdateTurnQueue()
    end

    -- ══════ РЕЖИМЫ БОЕВОЙ СИСТЕМЫ ══════
    if self.mode == "queue" then
        -- Очередной режим - начинаем ход первого игрока
        self.currentIndex = 1

        -- Показываем уведомление (если не первый раунд — т.е. после фазы NPC)
        if not isFirstRound and DoF.UI and DoF.UI.ShowPlayersPhaseAlert then
            DoF.UI:ShowPlayersPhaseAlert()
        end

        self:StartCurrentTurn()
    else
        -- Свободный режим - игроки ходят в любом порядке
        self.currentIndex = 0  -- Нет текущего игрока

        -- Автоматически помечаем оглушённых как походивших
        if DoF.Effects then
            for _, p in ipairs(self.participants) do
                if DoF.Effects:IsStunned(p.name) then
                    p.acted = true
                    self.actedThisRound[p.guid] = true
                end
            end
        end

        -- Показываем уведомление в свободном режиме
        if DoF.UI then
            -- Общее уведомление для всех
            if DoF.UI.ShowPlayersPhaseAlert then
                DoF.UI:ShowPlayersPhaseAlert()
            end
            -- Персональное уведомление "ВАШ ХОД" для текущего игрока
            if DoF.UI.ShowYourTurnAlert then
                DoF.UI:ShowYourTurnAlert()
            end
        end

        if self.useTimer then
            -- Запускаем таймер раунда с серверным deadline
            self.roundStartTime = GetTime()
            self.roundDeadlineServer = GetServerTime() + (self.turnDuration or 60)
            self:StartRoundTimer()
        end

        -- Обновляем UI
        if DoF.UI and DoF.UI.UpdateTurnQueue then
            DoF.UI:UpdateTurnQueue()
        end
    end
end

-- Запускает ход текущего игрока (только для режима "queue")
function DoF.TurnSystem:StartCurrentTurn(skipCount)
    skipCount = skipCount or 0

    if self.currentIndex > #self.participants then
        -- Все походили — фаза NPC
        self:StartNPCTurn()
        return
    end

    local current = self.participants[self.currentIndex]
    if not current then return end

    -- Сброс CritChoicePending (страховка от зависания после UI reload)
    if DoF.Combat then
        DoF.Combat.CritChoicePending = false
    end

    -- ══════ ПРОВЕРКА НА КРИТИЧЕСКОЕ РАНЕНИЕ ══════
    -- Игрок без сознания — автоматический пропуск хода
    if DoF.Stats and DoF.Stats:IsPlayerIncapacitated(current.name) then
        if skipCount >= #self.participants then
            DoF.Utils:Warn(DoF.L["combat.turn.all_incapacitated"])
            self:StartNPCTurn()
            return
        end

        if DoF.Sync then
            DoF.Sync:BroadcastCombatLogKey("combat.turn.skip_critical", current.name)
        end

        local myGUID = UnitGUID("player")
        if current.guid == myGUID then
            DoF.Utils:Warn(DoF.L["combat.turn.you_unconscious"])
        end

        current.acted = true
        self.currentIndex = self.currentIndex + 1
        self:StartCurrentTurn(skipCount + 1)
        return
    end

    -- ══════ ПРОВЕРКА НА ОГЛУШЕНИЕ ══════
    if DoF.Effects and DoF.Effects:IsStunned(current.name) then
        -- Защита от бесконечной рекурсии: если пропущено >= участников — все заглушены
        if skipCount >= #self.participants then
            DoF.Utils:Warn(DoF.L["combat.turn.all_stunned"])
            self:StartNPCTurn()
            return
        end

        -- Получаем оставшееся время стана
        local stunEffect = DoF.Effects:Get("player", current.name, "stun")
        local remainingRounds = stunEffect and stunEffect.remainingRounds or 0

        -- Игрок оглушён — пропускаем его ход
        if DoF.Sync then
            DoF.Sync:BroadcastCombatLogKey("combat.turn.skip_stun", current.name, remainingRounds)
        end

        -- Уведомляем игрока если это его ход
        local myGUID = UnitGUID("player")
        if current.guid == myGUID then
            DoF.Utils:Warn(DoF.Locale:Format("combat.turn.you_stunned", remainingRounds, DoF.Locale:Rounds(remainingRounds)))
        end

        -- Помечаем что походил (пропустил)
        current.acted = true

        -- Оглушение тикает в StartRound(), не здесь

        -- Переходим к следующему
        self.currentIndex = self.currentIndex + 1
        self:StartCurrentTurn(skipCount + 1)
        return
    end
    
    self.turnStartTime = GetTime()
    -- Серверный deadline: абсолютное время окончания хода. Клиенты при приёме
    -- TURN_CHANGE возьмут этот же deadline и получат одинаковый остаток времени
    -- независимо от packet-latency (см. GetTimeRemaining).
    self.turnDeadlineServer = GetServerTime() + (self.turnDuration or 60)

    -- Запускаем таймер
    if self.useTimer then
        self:StartTimer()
    end

    -- Событие
    local myGUID = UnitGUID("player")
    local isMyTurn = (current.guid == myGUID)
    DoF.Events:Fire("TURN_CHANGED", current.name, isMyTurn)

    -- Оповещение
    if isMyTurn then
        self:ShowYourTurn()
    end

    -- Синхронизация
    self:BroadcastTurnChange()
    
    -- Обновляем UI
    if DoF.UI and DoF.UI.UpdateTurnQueue then
        DoF.UI:UpdateTurnQueue()
    end
end

function DoF.TurnSystem:NextTurn()
    -- Отмечаем текущего как походившего
    local current = self.participants[self.currentIndex]
    if current then
        current.acted = true
    end

    -- Сбрасываем AoE если активен (принудительное завершение хода)
    if DoF.Combat and DoF.Combat:IsAoEActive() then
        DoF.Combat:CancelAoE()
    end
    if DoF.Combat and DoF.Combat:IsTauntAoEActive() then
        DoF.Combat:CancelTauntAoE()
    end
    if DoF.Combat and DoF.Combat:IsSpecialActionActive() then
        DoF.Combat:CancelSpecialAction()
    end

    self:StopTimer()
    
    -- Следующий игрок
    self.currentIndex = self.currentIndex + 1
    
    -- Синхронизация acted
    self:BroadcastActed(current and current.guid)
    
    -- Начинаем следующий ход
    self:StartCurrentTurn()
end

-- Хелпер: уменьшить усталость лечения на 1 стак
local function ReduceHealingFatigue(playerName)
    if not DoF.Combat or not DoF.Effects then return end
    local eff = DoF.Effects:Get("player", playerName, "healing_fatigue")
    if not eff or (eff.stacks or 0) <= 0 then return end

    local newStacks = eff.stacks - 1
    if newStacks <= 0 then
        DoF.Effects:Remove("player", playerName, "healing_fatigue")
        -- Сбрасываем счётчик
        if DoF.Combat.HealingFatigue[playerName] then
            DoF.Combat.HealingFatigue[playerName].count = 0
        end
        DoF.Utils:Info(DoF.L["combat.turn.fatigue_cleared"])
    else
        DoF.Effects:ApplyInternal("player", playerName, "healing_fatigue", newStacks, 999)
        local remainingThreshold = newStacks * DoF.Config.HEALING_FATIGUE_THRESHOLD_PER_STACK
        DoF.Utils:Info(DoF.Locale:Format("combat.turn.fatigue_reduced", newStacks, DoF.Locale:Plural(newStacks, DoF.L["combat.stacks_one"], DoF.L["combat.stacks_few"], DoF.L["combat.stacks_many"]), remainingThreshold))
    end

    -- Сохраняем в SavedVariables
    if playerName == UnitName("player") then
        DoF.Combat:SaveHealingFatigue()
    end
end

function DoF.TurnSystem:SkipTurn()
    if not DoF.Sync:IsMaster() then
        DoF.Utils:Error(DoF.L["errors.gm_only_skip_turn"])
        return
    end

    -- Восстанавливаем энергию за пропуск хода
    local skipEnergy = DoF.Config.ENERGY_GAIN_SKIP_TURN or 1
    if self.mode == "queue" then
        local current = self.participants[self.currentIndex]
        if current then
            DoF.Sync:GiveEnergy(current.name, skipEnergy)
            -- Уменьшить усталость лечения для текущего участника (если это мы)
            if current.name == UnitName("player") then
                ReduceHealingFatigue(current.name)
            end
        end
        -- Очередной режим - переходим к следующему игроку
        self:NextTurn()
    else
        -- Свободный режим - помечаем текущего игрока как походившего
        local myGUID = UnitGUID("player")
        local myName = UnitName("player")
        for _, p in ipairs(self.participants) do
            if p.guid == myGUID then
                p.acted = true
                self.actedThisRound[myGUID] = true
                break
            end
        end

        DoF.Sync:GiveEnergy(myName, skipEnergy)

        -- Уменьшить усталость лечения мастера
        ReduceHealingFatigue(myName)

        -- Синхронизация
        self:BroadcastActed(myGUID)

        -- Проверяем завершение раунда
        self:CheckRoundComplete()

        -- Обновляем UI
        if DoF.UI and DoF.UI.UpdateTurnQueue then
            DoF.UI:UpdateTurnQueue()
        end
    end
end

function DoF.TurnSystem:PlayerSkipTurn()
    -- Ожидание выбора крит-бонуса — нельзя пропускать
    if DoF.Combat and DoF.Combat.CritChoicePending then
        DoF.Utils:Error(DoF.L["errors.choose_crit_bonus_first"])
        return
    end
    -- Оглушённый не может пропустить ход вручную
    if DoF.Effects and DoF.Effects:IsStunned(UnitName("player")) then
        DoF.Utils:Error(DoF.L["errors.you_are_stunned"])
        return
    end

    if self.mode == "queue" then
        -- В очередном режиме проверяем, что это наш ход
        if not self:IsMyTurn() then
            DoF.Utils:Error(DoF.L["errors.not_your_turn"])
            return
        end
    end

    if DoF.Sync:IsMaster() then
        -- Мастер обрабатывает локально (SkipTurn уже содержит ReduceHealingFatigue)
        self:SkipTurn()
    else
        -- Снять 1 стак усталости лечения при пропуске хода (локально)
        ReduceHealingFatigue(UnitName("player"))
        -- Оповещаем мастера
        self:SendSkipToMaster()
    end
end

-- ═══════════════════════════════════════════════════════════
-- ТАЙМЕР
-- ═══════════════════════════════════════════════════════════

function DoF.TurnSystem:StartTimer()
    if not self.useTimer then
        return
    end

    self:StopTimer()

    self.timerHandle = DoF.Addon:ScheduleRepeatingTimer(function()
        self:OnTimerTick()
    end, 1)
end

function DoF.TurnSystem:StopTimer()
    if self.timerHandle then
        DoF.Addon:CancelTimer(self.timerHandle)
        self.timerHandle = nil
    end
end

function DoF.TurnSystem:OnTimerTick()
    local remaining = self:GetTimeRemaining()
    
    -- Обновляем UI
    if DoF.UI and DoF.UI.UpdateTurnTimer then
        DoF.UI:UpdateTurnTimer(remaining)
    end

    -- Автопропуск (не пропускаем если ожидается выбор крит-бонуса)
    if self.useTimer and remaining <= 0 then
        if DoF.Combat and DoF.Combat.CritChoicePending then
            return -- Ждём завершения выбора крита
        end
        if DoF.Sync:IsMaster() then
            self:NextTurn()
        end
    end
end

function DoF.TurnSystem:GetTimeRemaining()
    if self.phase ~= "players" then
        return self.turnDuration
    end

    -- Предпочитаем серверный deadline: GetServerTime() синхронизирован между клиентами,
    -- поэтому остаток времени хода одинаков у всех, независимо от packet-latency.
    -- Fallback на локальный turnStartTime сохранён для старых мастеров/сохранённого
    -- состояния, где turnDeadlineServer ещё не выставлен.
    if self.turnDeadlineServer and self.turnDeadlineServer > 0 then
        return math.max(0, self.turnDeadlineServer - GetServerTime())
    end

    if self.turnStartTime == 0 then
        return self.turnDuration
    end

    local elapsed = GetTime() - self.turnStartTime
    return math.max(0, self.turnDuration - elapsed)
end

-- Запускает таймер раунда (для свободного режима)
function DoF.TurnSystem:StartRoundTimer()
    self:StopTimer()

    self.timerHandle = DoF.Addon:ScheduleRepeatingTimer(function()
        self:OnRoundTimerTick()
    end, 1)
end

-- Тик таймера раунда (для свободного режима)
function DoF.TurnSystem:OnRoundTimerTick()
    local remaining = self:GetRoundTimeRemaining()

    -- Обновляем UI
    if DoF.UI and DoF.UI.UpdateTurnTimer then
        DoF.UI:UpdateTurnTimer(remaining)
    end

    -- Автозавершение раунда при истечении времени
    if remaining <= 0 then
        -- Ждём завершения выбора крита или контратаки
        if DoF.Combat and (DoF.Combat.CritChoicePending or DoF.Combat:IsCounterattackActive()) then
            return
        end

        if DoF.Sync:IsMaster() then
            -- Помечаем всех не сходивших как сходивших
            for _, p in ipairs(self.participants) do
                if not p.acted then
                    p.acted = true
                    self.actedThisRound[p.guid] = true
                end
            end
            -- Переходим к фазе NPC
            self:StartNPCTurn()
        end
    end
end

-- Возвращает оставшееся время раунда (для свободного режима)
function DoF.TurnSystem:GetRoundTimeRemaining()
    if self.mode ~= "free" or not self.useTimer then
        return self.turnDuration
    end

    -- Серверный deadline (см. комментарий в GetTimeRemaining)
    if self.roundDeadlineServer and self.roundDeadlineServer > 0 then
        return math.max(0, self.roundDeadlineServer - GetServerTime())
    end

    if self.roundStartTime == 0 then
        return self.turnDuration
    end

    local elapsed = GetTime() - self.roundStartTime
    return math.max(0, self.turnDuration - elapsed)
end

-- ═══════════════════════════════════════════════════════════
-- УПРАВЛЕНИЕ УЧАСТНИКАМИ
-- ═══════════════════════════════════════════════════════════

function DoF.TurnSystem:AddParticipant(name)
    if not DoF.Sync:IsMaster() then
        DoF.Utils:Error(DoF.L["errors.gm_only_add_participant"])
        return
    end
    
    -- Проверяем что ещё нет в списке
    for _, p in ipairs(self.participants) do
        if p.name == name then
            DoF.Utils:Error(DoF.Locale:Format("errors.already_in_combat", name))
            return
        end
    end
    
    -- Ищем GUID
    local guid = nil
    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            local raidName = GetRaidRosterInfo(i)
            if raidName == name then
                guid = UnitGUID("raid" .. i)
                break
            end
        end
    elseif IsInGroup() then
        if UnitName("player") == name then
            guid = UnitGUID("player")
        else
            for i = 1, GetNumGroupMembers() - 1 do
                if UnitName("party" .. i) == name then
                    guid = UnitGUID("party" .. i)
                    break
                end
            end
        end
    end
    
    if not guid then
        DoF.Utils:Error(DoF.Locale:Format("errors.player_not_in_group", name))
        return
    end
    
    -- Бросок инициативы
    local roll = math_random(1, 100)
    
    -- Создаём участника
    local participant = {
        name = name,
        guid = guid,
        roll = roll,
        acted = false,
    }
    
    -- Добавляем в список и индекс
    table_insert(self.participants, participant)
    self.participantsByGuid[guid] = participant
    
    -- Пересортировка
    table_sort(self.participants, function(a, b)
        return a.roll > b.roll
    end)
    
    -- Пересчитываем currentIndex (только в очередном режиме)
    if self.currentIndex > 0 then
        local currentGUID = self.participants[self.currentIndex]
            and self.participants[self.currentIndex].guid
        if currentGUID then
            for i, p in ipairs(self.participants) do
                if p.guid == currentGUID then
                    self.currentIndex = i
                    break
                end
            end
        end
    end

    -- В свободном режиме: если все остальные уже отходили, помечаем нового как acted
    if self.mode == "free" and self.phase == "players" then
        local allOthersActed = true
        for _, p in ipairs(self.participants) do
            if p.guid ~= guid and not p.acted then
                allOthersActed = false
                break
            end
        end
        if allOthersActed then
            participant.acted = true
            self.actedThisRound[guid] = true
        end
    end

    -- Синхронизация
    self:BroadcastParticipantAdd(name, guid, roll)

    -- Отправляем полное состояние боя новому участнику
    DoF.Sync:SendCombatState(name)

    -- Отправить состояние эффектов
    if DoF.Effects then
        DoF.Effects:BroadcastAllEffects()
    end

    -- Обновляем UI
    if DoF.UI and DoF.UI.UpdateTurnQueue then
        DoF.UI:UpdateTurnQueue()
    end
end

function DoF.TurnSystem:RemoveParticipant(name)
    if not DoF.Sync:IsMaster() then
        DoF.Utils:Error(DoF.L["errors.gm_only_remove_participant"])
        return
    end
    
    local removedIndex = nil
    local removedGUID = nil
    
    for i, p in ipairs(self.participants) do
        if p.name == name then
            removedIndex = i
            removedGUID = p.guid
            table_remove(self.participants, i)
            break
        end
    end
    
    if not removedIndex then
        DoF.Utils:Error(DoF.Locale:Format("errors.not_in_combat", name))
        return
    end
    
    -- Удаляем из индекса
    if removedGUID then
        self.participantsByGuid[removedGUID] = nil
    end
    
    -- Корректируем currentIndex
    if removedIndex < self.currentIndex then
        self.currentIndex = self.currentIndex - 1
    elseif removedIndex == self.currentIndex and #self.participants > 0 then
        -- Удалили текущего, но участники остались — переходим к следующему
        if self.currentIndex > #self.participants then
            self.currentIndex = #self.participants
        end
        self:StartCurrentTurn()
    end

    -- Страховочный bounds check после всех веток
    if #self.participants > 0 and self.currentIndex > #self.participants then
        self.currentIndex = #self.participants
    end

    -- Участников не осталось — завершаем бой
    if #self.participants == 0 and self.phase == "players" then
        self.currentIndex = 0
        self:EndCombat()
    elseif self.mode == "free" and self.phase == "players" then
        -- В свободном режиме проверяем, может все оставшиеся уже походили
        self:CheckRoundComplete()
    end
    
    -- Синхронизация
    self:BroadcastParticipantRemove(removedGUID)
    
    -- Обновляем UI
    if DoF.UI and DoF.UI.UpdateTurnQueue then
        DoF.UI:UpdateTurnQueue()
    end
end

function DoF.TurnSystem:GiveFreeAction(name)
    if not DoF.Sync:IsMaster() then
        DoF.Utils:Error(DoF.L["errors.gm_only_extra_turn"])
        return
    end
    
    -- Ищем игрока
    for _, p in ipairs(self.participants) do
        if p.name == name then
            self.freeActionGUID = p.guid
            
            -- Синхронизация
            self:BroadcastFreeAction(p.guid)
            return
        end
    end
    
    DoF.Utils:Error(DoF.Locale:Format("errors.not_in_combat", name))
end

-- ═══════════════════════════════════════════════════════════
-- ПРОВЕРКИ
-- ═══════════════════════════════════════════════════════════

function DoF.TurnSystem:IsActive()
    return self.phase ~= "idle"
end

function DoF.TurnSystem:IsMyTurn()
    if self.phase ~= "players" then return false end
    
    local current = self.participants[self.currentIndex]
    if not current then return false end
    
    local myGUID = UnitGUID("player")
    return current.guid == myGUID
end

function DoF.TurnSystem:CanAct()
    -- Ожидание выбора крит-бонуса — действия заблокированы
    if DoF.Combat and DoF.Combat.CritChoicePending then return false end

    -- Ожидание выбора цели контратаки — действия заблокированы
    if DoF.Combat and DoF.Combat:IsCounterattackActive() then return false end

    -- Бой не активен — свобода
    if self.phase == "idle" then return true end

    -- Фаза NPC — игроки не могут действовать
    if self.phase == "npc" then return false end

    -- Фаза игроков
    if self.phase == "players" then
        local myGUID = UnitGUID("player")

        -- Внеочередной ход (работает в обоих режимах)
        if self.freeActionGUID == myGUID then return true end

        if self.mode == "queue" then
            -- Очередной режим - только мой ход
            if self:IsMyTurn() then return true end
        else
            -- Свободный режим - проверяем оглушение
            if DoF.Effects and DoF.Effects:IsStunned(UnitName("player")) then
                return false
            end
            -- Могу действовать если ещё не ходил
            if not self.actedThisRound[myGUID] then
                return true
            end
        end
    end

    return false
end

function DoF.TurnSystem:GetCurrentPlayer()
    return self.participants[self.currentIndex]
end

-- ═══════════════════════════════════════════════════════════
-- УВЕДОМЛЕНИЯ
-- ═══════════════════════════════════════════════════════════

function DoF.TurnSystem:ShowYourTurn()
    -- Звук
    PlaySound(8960, "SFX") -- READY_CHECK
    
    -- UI уведомление
    if DoF.UI and DoF.UI.ShowYourTurnAlert then
        DoF.UI:ShowYourTurnAlert()
    end
end

-- ═══════════════════════════════════════════════════════════
-- ДЕЙСТВИЕ ВЫПОЛНЕНО
-- ═══════════════════════════════════════════════════════════

function DoF.TurnSystem:OnActionPerformed()
    -- Вызывается после атаки/лечения
    if not self:IsActive() then return end

    local myGUID = UnitGUID("player")

    -- Если это был внеочередной ход — сбрасываем локально и оповещаем
    if self.freeActionGUID == myGUID then
        self.freeActionGUID = nil
        self:BroadcastActed(myGUID)
        -- Мастер не получит свой PLAYER_ACTED через AceComm,
        -- поэтому явно рассылаем сброс внеочередного хода
        if DoF.Sync:IsMaster() then
            self:BroadcastFreeAction(nil)
        end
        return
    end

    if self.mode == "queue" then
        -- Очередной режим - переход к следующему игроку
        if self:IsMyTurn() then
            if DoF.Sync:IsMaster() then
                -- Мастер обрабатывает локально (сообщения самому себе не доходят)
                self:NextTurn()
            else
                -- Оповещаем мастера
                self:SendActionDoneToMaster()
            end
        end
    else
        -- Свободный режим - помечаем что сходили
        for _, p in ipairs(self.participants) do
            if p.guid == myGUID then
                p.acted = true
                self.actedThisRound[myGUID] = true
                break
            end
        end

        -- Синхронизация
        self:BroadcastActed(myGUID)

        -- Проверяем завершение раунда (только мастер)
        if DoF.Sync:IsMaster() then
            self:CheckRoundComplete()
        end

        -- Обновляем UI
        if DoF.UI and DoF.UI.UpdateTurnQueue then
            DoF.UI:UpdateTurnQueue()
        end
    end
end

-- Проверяет завершение раунда в свободном режиме
function DoF.TurnSystem:CheckRoundComplete()
    if self.mode ~= "free" then return end

    local allActed = true
    for _, p in ipairs(self.participants) do
        if not p.acted then
            allActed = false
            break
        end
    end

    if allActed then
        -- Все игроки походили - переходим к фазе NPC
        self:StopTimer()
        self:StartNPCTurn()
    end
end

-- Пропускает ход конкретного игрока (для мастера в свободном режиме)
function DoF.TurnSystem:SkipPlayerTurn(playerGUID)
    if not DoF.Sync:IsMaster() then
        DoF.Utils:Error(DoF.L["errors.gm_only_skip_player"])
        return
    end

    if self.mode ~= "free" then
        -- В очередном режиме используем обычный SkipTurn
        local current = self.participants[self.currentIndex]
        if current and current.guid == playerGUID then
            self:SkipTurn()
        end
        return
    end

    -- Свободный режим - помечаем игрока как сходившего
    for _, p in ipairs(self.participants) do
        if p.guid == playerGUID then
            p.acted = true
            self.actedThisRound[playerGUID] = true

            -- Восстанавливаем энергию за пропуск хода
            local skipEnergy = DoF.Config.ENERGY_GAIN_SKIP_TURN or 1
            DoF.Sync:GiveEnergy(p.name, skipEnergy)

            -- Синхронизация
            self:BroadcastActed(playerGUID)

            -- Проверяем завершение раунда
            self:CheckRoundComplete()

            -- Обновляем UI
            if DoF.UI and DoF.UI.UpdateTurnQueue then
                DoF.UI:UpdateTurnQueue()
            end
            break
        end
    end
end


-- Синхронизация (Broadcast/Handle) вынесена в Combat/TurnSystem_Sync.lua
