-- DoF/Combat/TurnSystem_Sync.lua
-- Синхронизация системы ходов: Broadcast и Handle функции

local ADDON_NAME, DoF = ...

-- Кэширование глобальных функций
local pairs = pairs
local ipairs = ipairs
local tonumber = tonumber
local table_insert = table.insert
local table_sort = table.sort
local table_remove = table.remove
local strsplit = strsplit
local UnitGUID = UnitGUID
local UnitName = UnitName
local UnitExists = UnitExists
local GetTime = GetTime
local C_Timer = C_Timer
local PlaySound = PlaySound

-- ═══════════════════════════════════════════════════════════
-- СИНХРОНИЗАЦИЯ (заглушки — реализуем в Comm.lua)
-- ═══════════════════════════════════════════════════════════

function DoF.TurnSystem:BroadcastCombatStart()
    if not DoF.Sync then return end

    local parts = {}
    for _, p in ipairs(self.participants) do
        table.insert(parts, p.name .. "," .. p.guid .. "," .. p.roll)
    end

    -- Формат: mode;useTimer;duration;participant1;participant2;...
    local data = self.mode .. ";" ..
                 (self.useTimer and "1" or "0") .. ";" ..
                 self.turnDuration .. ";" ..
                 table.concat(parts, ";")
    DoF.Sync:Send("COMBAT_START", data)
end

function DoF.TurnSystem:BroadcastCombatEnd()
    if not DoF.Sync then return end
    DoF.Sync:Send("COMBAT_END", "")
end

function DoF.TurnSystem:BroadcastPhaseChange(phase)
    if not DoF.Sync then return end
    DoF.Sync:Send("PHASE_CHANGE", phase)
end

function DoF.TurnSystem:BroadcastRoundStart()
    if not DoF.Sync then return end
    DoF.Sync:Send("ROUND_START", self.round .. ";" .. self.currentIndex)
end

function DoF.TurnSystem:BroadcastTurnChange()
    if not DoF.Sync then return end
    -- Передаём оставшееся время, фазу и guid текущего игрока для надёжной синхронизации.
    -- 5-е поле — абсолютный серверный deadline. Старые клиенты его проигнорируют
    -- (strsplit возвращает лишние поля — они просто не присваиваются).
    local remaining = self:GetTimeRemaining()
    local current = self.participants[self.currentIndex]
    local currentGUID = current and current.guid or ""
    local deadline = (self.turnDeadlineServer and self.turnDeadlineServer > 0)
        and self.turnDeadlineServer
        or (GetServerTime() + remaining)
    DoF.Sync:SendReliable("TURN_CHANGE",
        self.currentIndex .. ";" .. remaining .. ";" .. self.phase .. ";" .. currentGUID .. ";" .. deadline)
end

function DoF.TurnSystem:BroadcastActed(guid)
    if not DoF.Sync then return end
    DoF.Sync:Send("PLAYER_ACTED", guid or "")
end

function DoF.TurnSystem:BroadcastParticipantAdd(name, guid, roll)
    if not DoF.Sync then return end
    DoF.Sync:Send("PARTICIPANT_ADD", name .. ";" .. guid .. ";" .. roll .. ";" .. self.currentIndex)
end

function DoF.TurnSystem:BroadcastParticipantRemove(guid)
    if not DoF.Sync then return end
    DoF.Sync:Send("PARTICIPANT_REMOVE", guid)
end

function DoF.TurnSystem:BroadcastFreeAction(guid)
    if not DoF.Sync then return end
    DoF.Sync:Send("FREE_ACTION", guid or "")
end

function DoF.TurnSystem:SendSkipToMaster()
    if not DoF.Sync then return end
    DoF.Sync:Send("PLAYER_SKIP", UnitGUID("player"))
end

function DoF.TurnSystem:SendActionDoneToMaster()
    if not DoF.Sync then return end
    DoF.Sync:SendReliable("ACTION_DONE", UnitGUID("player"))
end

-- ═══════════════════════════════════════════════════════════
-- ОБРАБОТКА ВХОДЯЩИХ СООБЩЕНИЙ (вызывается из Comm.lua)
-- ═══════════════════════════════════════════════════════════

function DoF.TurnSystem:HandleCombatStart(data)
    local parts = {strsplit(";", data)}

    -- Парсим параметры: mode;useTimer;duration;participant1;participant2;...
    self.mode = parts[1] or "queue"
    self.useTimer = (parts[2] == "1")
    self.turnDuration = tonumber(parts[3]) or 60
    self.participants = {}
    self.actedThisRound = {}

    for i = 4, #parts do
        local name, guid, roll = strsplit(",", parts[i])
        if name and guid and roll then
            table.insert(self.participants, {
                name = name,
                guid = guid,
                roll = tonumber(roll) or 0,
                acted = false,
            })
        end
    end

    self.phase = "players"
    self.round = 1

    -- Построить индекс для быстрого поиска
    self:BuildParticipantIndex()

    -- Генерируем COMBAT_STARTED чтобы UI активировал боевой режим (ДО ShowTurnQueue, чтобы TrackerHeader был создан)
    DoF.Events:Fire("COMBAT_STARTED", self.mode)

    -- Показываем окно очереди
    if DoF.UI and DoF.UI.ShowTurnQueue then
        DoF.UI:ShowTurnQueue()
    end

    if self.mode == "queue" then
        -- Очередной режим
        self.currentIndex = 1
        self.turnStartTime = GetTime()
        self.turnDeadlineServer = GetServerTime() + (self.turnDuration or 60)

        -- Оповещаем если наш ход
        if self:IsMyTurn() then
            self:ShowYourTurn()
        end

        -- Запускаем таймер хода если включен
        if self.useTimer then
            self:StartTimer()
        end
    else
        -- Свободный режим
        self.currentIndex = 0

        -- Запускаем таймер раунда если включен
        if self.useTimer then
            self.roundStartTime = GetTime()
            self.roundDeadlineServer = GetServerTime() + (self.turnDuration or 60)
            self:StartRoundTimer()
        end
    end
end

function DoF.TurnSystem:HandleCombatState(data)
    local parts = {strsplit(";", data)}

    -- Формат: phase;mode;useTimer;duration;round;currentIndex;remaining;participant1;participant2;...
    local phase = parts[1] or "idle"
    local mode = parts[2] or "queue"
    local useTimer = (parts[3] == "1")
    local turnDuration = tonumber(parts[4]) or 60
    local round = tonumber(parts[5]) or 0
    local currentIndex = tonumber(parts[6]) or 0
    local remaining = tonumber(parts[7]) or turnDuration

    self.phase = phase
    self.mode = mode
    self.useTimer = useTimer
    self.turnDuration = turnDuration
    self.round = round
    self.participants = {}

    for i = 8, #parts do
        local name, guid, roll, acted = strsplit(",", parts[i])
        if name and guid and roll then
            table.insert(self.participants, {
                name = name,
                guid = guid,
                roll = tonumber(roll) or 0,
                acted = (acted == "1"),
            })
        end
    end

    -- Валидация currentIndex: пришедший индекс должен указывать в пределах списка участников
    local partCount = #self.participants
    if partCount == 0 then
        self.currentIndex = 0
        self.phase = "idle"
    elseif self.mode == "queue" then
        if currentIndex < 1 or currentIndex > partCount then
            currentIndex = 1
        end
        self.currentIndex = currentIndex
    else
        -- free-режим: currentIndex не адресует конкретного игрока
        self.currentIndex = math.max(0, math.min(currentIndex, partCount))
    end

    -- Построить индекс
    self:BuildParticipantIndex()

    -- Генерируем COMBAT_STARTED чтобы UI активировал боевой режим (ДО ShowTurnQueue, чтобы TrackerHeader был создан)
    DoF.Events:Fire("COMBAT_STARTED", self.mode)

    -- Показываем окно очереди (после COMBAT_STARTED, чтобы TrackerHeader уже существовал)
    if DoF.UI and DoF.UI.ShowTurnQueue then
        DoF.UI:ShowTurnQueue()
    end

    -- Запускаем таймер если нужно. Dedline вычисляем через GetServerTime() +
    -- remaining — клиент только что получил remaining от мастера, так что offset
    -- от мастера минимален (разница лишь в packet-latency). GetServerTime()
    -- синхронизирован между клиентами → остаток времени согласован.
    if phase == "players" then
        if mode == "queue" then
            self.turnStartTime = GetTime() - (turnDuration - remaining)
            self.turnDeadlineServer = GetServerTime() + remaining
            if useTimer then
                self:StartTimer()
            end
            if self:IsMyTurn() then
                self:ShowYourTurn()
            end
        else
            if useTimer then
                self.roundStartTime = GetTime() - (turnDuration - remaining)
                self.roundDeadlineServer = GetServerTime() + remaining
                self:StartRoundTimer()
            end
        end
    end

    -- Восстанавливаем actedThisRound для свободного режима
    if self.mode == "free" then
        self.actedThisRound = {}
        for _, p in ipairs(self.participants) do
            if p.acted then
                self.actedThisRound[p.guid] = true
            end
        end
    end

    -- Обновляем весь UI
    if DoF.UI and DoF.UI.UpdateTurnQueue then
        DoF.UI:UpdateTurnQueue()
    end

    if DoF.Sync._showSystemMessages then
        DoF.Utils:Info(DoF.Locale:Format("combat.turn.state_synced", round, phase))
    end
end

-- Отправить состояние боя мастеру для восстановления (без проверки IsMaster)
-- Используется не-мастером в ответ на RECOVERY_REQUEST
function DoF.TurnSystem:SendCombatStateRecovery(targetPlayer)
    if self.phase == "idle" then return end

    local parts = {}
    for _, p in ipairs(self.participants) do
        table.insert(parts, p.name .. "," .. p.guid .. "," .. p.roll .. "," .. (p.acted and "1" or "0"))
    end

    local remaining
    if self.mode == "free" then
        remaining = self:GetRoundTimeRemaining()
    else
        remaining = self:GetTimeRemaining()
    end

    local data = (self.phase or "idle") .. ";" ..
                 (self.mode or "queue") .. ";" ..
                 (self.useTimer and "1" or "0") .. ";" ..
                 (self.turnDuration or 60) .. ";" ..
                 (self.round or 0) .. ";" ..
                 (self.currentIndex or 0) .. ";" ..
                 remaining .. ";" ..
                 table.concat(parts, ";")

    DoF.Sync:SendTo("COMBAT_STATE_RECOVERY", data, targetPlayer)
end

function DoF.TurnSystem:HandleCombatEnd()
    self:StopTimer()

    self.phase = "idle"
    self.participants = {}
    self.participantsByGuid = {}  -- Очищаем индекс
    self.currentIndex = 0
    self.round = 0

    -- Сброс усталости лечения и серии защит танка
    DoF.Combat.HealingFatigue = {}
    DoF.Combat.TankDefenseStreak = {}
    if DoF.db and DoF.db.char then DoF.db.char.healingFatigue = nil end

    -- Сброс AoE состояний (могут застрять при внезапном завершении боя)
    if DoF.Combat:IsAoEActive() then DoF.Combat:CancelAoE() end
    if DoF.Combat:IsAoEHealActive() then DoF.Combat:CancelAoEHeal() end
    if DoF.Combat:IsAoEBuffActive() then DoF.Combat:CancelAoEBuff() end

    -- Сброс CritChoicePending
    DoF.Combat.CritChoicePending = false

    -- Сброс мгновенной защиты
    DoF.Combat.instantDefense = false

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

    -- Генерируем COMBAT_ENDED чтобы UI скрыл боевые элементы (хедер, очередь, панели)
    DoF.Events:Fire("COMBAT_ENDED")

    -- Показываем уведомление об окончании боя
    if DoF.UI and DoF.UI.ShowCombatEndAlert then
        DoF.UI:ShowCombatEndAlert()
    end
end

function DoF.TurnSystem:HandlePhaseChange(phase)
    self.phase = phase

    if phase == "npc" then
        self:StopTimer()
        -- Показываем уведомление о фазе NPC
        if DoF.UI and DoF.UI.ShowNPCPhaseAlert then
            DoF.UI:ShowNPCPhaseAlert()
        end
    end

    -- Обновляем UI
    if DoF.UI and DoF.UI.UpdateTurnQueue then
        DoF.UI:UpdateTurnQueue()
    end
end

function DoF.TurnSystem:HandleRoundStart(data)
    local round, currentIndex = strsplit(";", data)
    local prevRound = self.round

    self.round = tonumber(round) or 1
    self.currentIndex = tonumber(currentIndex) or 1
    self.phase = "players"
    self.turnStartTime = GetTime()
    -- Новый раунд — новый серверный deadline, одинаковый у всех клиентов
    self.turnDeadlineServer = GetServerTime() + (self.turnDuration or 60)

    -- Сброс acted
    for _, p in ipairs(self.participants) do
        p.acted = false
    end
    self.actedThisRound = {}  -- ВАЖНО: сбрасываем для свободного режима

    -- Запускаем таймер
    if self.useTimer then
        if self.mode == "queue" then
            self:StartTimer()
        else
            self.roundStartTime = GetTime()
            self.roundDeadlineServer = GetServerTime() + (self.turnDuration or 60)
            self:StartRoundTimer()
        end
    end

    -- ══════ ОБРАБОТКА КУЛДАУНОВ (для клиентов) ══════
    -- Мастер уже обработал через ProcessNPCEffects, клиенты тикают свои кулдауны
    if prevRound > 0 and not DoF.Sync:IsMaster() and DoF.Effects then
        DoF.Effects:TickCooldowns()
    end

    -- ══════ ОБНОВЛЕНИЕ UI ЭФФЕКТОВ ══════
    if prevRound > 0 and DoF.UI and DoF.UI.Effects then
        DoF.UI.Effects:UpdateAll()
    end

    -- Логируем новый раунд (для клиентов)
    if prevRound > 0 and DoF.CombatLog and not DoF.Sync:IsMaster() then
        DoF.CombatLog:Add(DoF.Locale:Format("combat.turn.round_header", self.round))
    end

    -- Показываем уведомление о фазе игроков (если не первый раунд)
    if prevRound > 0 and DoF.UI and DoF.UI.ShowPlayersPhaseAlert then
        DoF.UI:ShowPlayersPhaseAlert()
    end

    -- Оповещаем если наш ход
    if self:IsMyTurn() then
        self:ShowYourTurn()
    end

    -- Обновляем UI
    if DoF.UI and DoF.UI.UpdateTurnQueue then
        DoF.UI:UpdateTurnQueue()
    end
end

function DoF.TurnSystem:HandleTurnChange(data)
    local currentIndex, remainingTime, phase, currentGUID, deadlineStr = strsplit(";", data)
    self.currentIndex = tonumber(currentIndex) or 1

    -- Синхронизируем фазу если передана (защита от рассинхронизации)
    if phase and phase ~= "" then
        self.phase = phase
    end

    -- Проверяем что currentIndex указывает на правильного игрока (по guid)
    if currentGUID and currentGUID ~= "" then
        local current = self.participants[self.currentIndex]
        if current and current.guid ~= currentGUID then
            -- Индекс расходится — ищем по guid
            for i, p in ipairs(self.participants) do
                if p.guid == currentGUID then
                    self.currentIndex = i
                    break
                end
            end
        end
    end

    -- Предпочтительно: абсолютный серверный deadline от мастера. Клиенты с любой
    -- задержкой получат одинаковый остаток времени (GetServerTime синхронизирован).
    -- Fallback на remaining+turnStartTime — для старых мастеров, не шлющих deadline.
    local deadline = tonumber(deadlineStr)
    local remaining = tonumber(remainingTime) or self.turnDuration
    if deadline and deadline > 0 then
        self.turnDeadlineServer = deadline
        self.turnStartTime = GetTime() - (self.turnDuration - remaining)
    else
        self.turnDeadlineServer = GetServerTime() + remaining
        self.turnStartTime = GetTime() - (self.turnDuration - remaining)
    end

    -- Оповещаем если наш ход
    if self:IsMyTurn() then
        self:ShowYourTurn()
    end

    -- Обновляем UI
    if DoF.UI and DoF.UI.UpdateTurnQueue then
        DoF.UI:UpdateTurnQueue()
    end
end

function DoF.TurnSystem:HandlePlayerActed(guid)
    -- Внеочередной ход — не помечаем как обычное действие
    if self.freeActionGUID == guid then
        if DoF.Sync:IsMaster() then
            self.freeActionGUID = nil
            self:BroadcastFreeAction(nil)
        end
        if DoF.UI and DoF.UI.UpdateTurnQueue then
            DoF.UI:UpdateTurnQueue()
        end
        return
    end

    -- Используем индекс для O(1) доступа
    local p = self.participantsByGuid[guid]
    if p then
        p.acted = true
        self.actedThisRound[guid] = true
    end

    -- Обновляем UI
    if DoF.UI and DoF.UI.UpdateTurnQueue then
        DoF.UI:UpdateTurnQueue()
    end

    -- Мастер проверяет завершение раунда в свободном режиме
    if self.mode == "free" and DoF.Sync:IsMaster() then
        self:CheckRoundComplete()
    end
end

function DoF.TurnSystem:HandleParticipantAdd(data)
    local name, guid, roll, masterIndex = strsplit(";", data)

    local participant = {
        name = name,
        guid = guid,
        roll = tonumber(roll) or 0,
        acted = false,
    }

    table_insert(self.participants, participant)
    self.participantsByGuid[guid] = participant  -- Добавляем в индекс

    -- Пересортировка
    table_sort(self.participants, function(a, b)
        return a.roll > b.roll
    end)

    -- Синхронизируем currentIndex с мастером (после сортировки порядок может отличаться)
    if masterIndex then
        self.currentIndex = tonumber(masterIndex) or self.currentIndex
    end

    -- Обновляем UI
    if DoF.UI and DoF.UI.UpdateTurnQueue then
        DoF.UI:UpdateTurnQueue()
    end
end

function DoF.TurnSystem:HandleParticipantRemove(guid)
    for i, p in ipairs(self.participants) do
        if p.guid == guid then
            table_remove(self.participants, i)
            break
        end
    end

    -- Удаляем из индекса
    self.participantsByGuid[guid] = nil

    -- Обновляем UI
    if DoF.UI and DoF.UI.UpdateTurnQueue then
        DoF.UI:UpdateTurnQueue()
    end
end

function DoF.TurnSystem:HandleFreeAction(guid)
    self.freeActionGUID = (guid and guid ~= "") and guid or nil

    if self.freeActionGUID then
        -- Резолвим имя из участников
        local targetName = nil
        for _, p in ipairs(self.participants) do
            if p.guid == self.freeActionGUID then
                targetName = p.name
                break
            end
        end
        targetName = targetName or DoF.L["combat.turn.unknown_player"]

        local isMe = (self.freeActionGUID == UnitGUID("player"))
        local isMaster = DoF.Sync:IsMaster()

        if isMe then
            -- Звук + алерт для получателя
            PlaySound(8960, "SFX") -- READY_CHECK
            if DoF.UI and DoF.UI.ShowFreeActionAlert then
                DoF.UI:ShowFreeActionAlert()
            end

            if isMaster then
                -- Мастер-игрок дал себе
                DoF.Utils:Info(DoF.L["combat.turn.extra_turn_self"])
            else
                -- Обычный игрок получил внеочередной ход
                DoF.Utils:Info(DoF.L["combat.turn.extra_turn_you"])
            end
        else
            -- Все остальные (включая мастера, давшего ход другому игроку)
            DoF.Utils:Info(DoF.Locale:Format("combat.turn.extra_turn_given", targetName))
        end

        -- Боевой журнал для всех
        if DoF.CombatLog then
            DoF.CombatLog:Add(DoF.Locale:Format("combat.turn.extra_turn_log", targetName))
        end
    end

    -- Обновляем окно очереди
    if DoF.UI and DoF.UI.UpdateTurnQueue then
        DoF.UI:UpdateTurnQueue()
    end
end

-- Обработка от игроков (только мастер)
function DoF.TurnSystem:HandlePlayerSkip(guid)
    if not DoF.Sync:IsMaster() then return end

    if self.mode == "free" then
        self:SkipPlayerTurn(guid)
    else
        local current = self.participants[self.currentIndex]
        if current and current.guid == guid then
            -- Восстанавливаем энергию за пропуск хода
            local skipEnergy = DoF.Config.ENERGY_GAIN_SKIP_TURN or 1
            DoF.Sync:GiveEnergy(current.name, skipEnergy)
            self:NextTurn()
        end
    end
end

function DoF.TurnSystem:HandleActionDone(guid)
    if not DoF.Sync:IsMaster() then return end

    if self.mode == "free" then
        for _, p in ipairs(self.participants) do
            if p.guid == guid then
                p.acted = true
                self.actedThisRound[guid] = true
                self:BroadcastActed(guid)
                self:CheckRoundComplete()
                if DoF.UI and DoF.UI.UpdateTurnQueue then
                    DoF.UI:UpdateTurnQueue()
                end
                break
            end
        end
    else
        local current = self.participants[self.currentIndex]
        if current and current.guid == guid then
            self:NextTurn()
        end
    end
end
