-- DoF/Sync/Core.lua
-- Базовые функции синхронизации: отправка, мастер, инициализация

local ADDON_NAME, DoF = ...

-- Кэширование глобальных функций
local pairs = pairs
local ipairs = ipairs
local tonumber = tonumber
local tostring = tostring
local type = type
local string_format = string.format
local string_sub = string.sub
local string_len = string.len
local table_insert = table.insert
local wipe = wipe
local UnitName = UnitName
local UnitGUID = UnitGUID
local UnitIsGroupLeader = UnitIsGroupLeader
local IsInGroup = IsInGroup
local IsInRaid = IsInRaid
local GetNumGroupMembers = GetNumGroupMembers
local C_Timer = C_Timer
local GetTime = GetTime

-- Приоритеты сообщений для ChatThrottleLib (ALERT > NORMAL > BULK)
-- Критические боевые команды идут с высшим приоритетом, фоновые данные — с низшим.
--
-- ВАЖНО: UNIT/HPCHANGE/REMOVE/NPC_SHIELD = ALERT, потому что NPCATTACK тоже
-- ALERT, и если UNIT останется на NORMAL — после применения шаблона мастером
-- атака обгонит UNIT-сообщение, у клиентов создастся HPCHANGE-stub без
-- настоящих данных шаблона, и UI покажет «Нет данных» / нули в защитах.
-- REQUEST_UNIT тоже ALERT — это ручной аварийный запрос, реакция должна быть быстрой.
local COMMAND_PRIORITY = {
    -- ALERT: критические команды боя (потеря = застревание)
    NPCATTACK = "ALERT", TURN_CHANGE = "ALERT", ACTION_DONE = "ALERT",
    COMBAT_START = "ALERT", COMBAT_END = "ALERT", COMBAT_STATE = "ALERT",
    ROUND_START = "ALERT", PHASE_CHANGE = "ALERT", DEFENSE_DONE = "ALERT",
    PLAYER_SKIP = "ALERT", PLAYER_ACTED = "ALERT", FREE_ACTION = "ALERT",
    REDIRECT_DAMAGE = "ALERT", RELIABLE = "ALERT", ACK = "ALERT",
    -- Данные NPC: должны успевать за NPCATTACK/HPCHANGE, иначе шаблон «слетает»
    UNIT = "ALERT", HPCHANGE = "ALERT", REMOVE = "ALERT",
    NPC_SHIELD = "ALERT", ADAPT = "ALERT", REQUEST_UNIT = "ALERT",
    -- BULK: фоновые данные (можно задержать без последствий)
    PLAYERDATA = "BULK", PLAYERHP = "BULK", COMBATLOG = "BULK", COMBATLOG2 = "BULK",
    FULLDATA = "BULK", FULLDATA3 = "BULK",
}

DoF.Sync = {
    MasterName = nil,
    _isMaster = false,

    -- Данные игроков группы
    RaidData = {},

    -- Буфер для получения полных данных
    FullDataBuffer = {},
    FullDataExpected = 0,
    FullDataSender = nil,

    -- Ожидающие подтверждения
    PendingConfirmations = {},

    -- Обработчики (заполняются в Handlers.lua)
    Handlers = {},

    -- Системные сообщения. Дефолт false: рядовой игрок не должен видеть в чате
    -- «Данные от мастера: N NPC», «Восстановлено от группы», «Таймаут…» и т.п.
    -- На Init() пересчитывается: master видит всегда, не-master — по db.profile.systemMessages.
    _showSystemMessages = false,

    -- ACK/Retry система для надёжной доставки критических сообщений
    _nextMsgId = 1,
    _pendingAcks = {},    -- { [msgId] = { cmd, data, target, retries, timer } }
    _seenMsgIds = {},     -- { ["sender:msgId"] = expireTime } — дедупликация
}

-- ═══════════════════════════════════════════════════════════
-- ИНИЦИАЛИЗАЦИЯ
-- ═══════════════════════════════════════════════════════════

-- Пересчёт _showSystemMessages: мастер видит всегда (он отвечает за группу и
-- должен видеть сетевые проблемы), рядовой — по сохранённой настройке.
function DoF.Sync:_RecalcShowSystemMessages()
    local optIn = DoF.db and DoF.db.profile and DoF.db.profile.systemMessages
    self._showSystemMessages = self._isMaster or (optIn and true or false)
end

function DoF.Sync:Init()
    self:UpdateMasterStatus()
    self:_RecalcShowSystemMessages()

    -- Seed _nextMsgId из абсолютного серверного времени. После /reload
    -- _nextMsgId раньше сбрасывался в 1, но _seenMsgIds хранит TTL 30с → в окне
    -- реджойна пре-reload msgId=1..N и post-reload msgId=1..N коллидировали с
    -- ключом sender:msgId, и новые RELIABLE молча отбрасывались как дубликаты.
    -- GetServerTime()*1000 растёт монотонно между сессиями, пре-reload
    -- максимум (~начальное_время + несколько_сотен) всегда меньше post-reload
    -- стартового значения — дедуп-коллизия физически невозможна.
    if GetServerTime and GetServerTime() > 0 then
        self._nextMsgId = GetServerTime() * 1000 + math.random(0, 999)
    end
end

-- Экспоненциальный бэкофф для ретраев FULLDATA. ChatThrottleLib в большом рейде
-- может задерживать BULK-канал — фиксированные 20с давали клиенту сдаться раньше,
-- чем мастер успевал прислать дамп. Лимит 5 попыток, между ними 5/10/20/30/30с.
local FULLDATA_RETRY_DELAYS = { 5, 10, 20, 30, 30 }
local FULLDATA_MAX_RETRIES = 5

-- Централизованный метод для WaitingForFullData с safety-таймером и лимитом retry
function DoF.Sync:RequestFullData()
    self._fullDataRetries = (self._fullDataRetries or 0) + 1
    if self._fullDataRetries > FULLDATA_MAX_RETRIES then
        -- Не спамим в чат — короткое уведомление через UIErrorsFrame видят все,
        -- но в боевой лог чата оно не попадает. Подсказка ведёт к кнопке-ресинку.
        if UIErrorsFrame and UIErrorsFrame.AddMessage then
            UIErrorsFrame:AddMessage(DoF.L["combat.sync.no_npc_data"], 1, 0.3, 0.3, 1.0)
        end
        self.WaitingForFullData = false
        self._fullDataRetries = 0
        return
    end

    self.WaitingForFullData = true
    self:Send("REQUEST")

    -- Safety-таймер с экспоненциальным бэкоффом
    if self._fullDataSafetyTimer then
        DoF.Addon:CancelTimer(self._fullDataSafetyTimer)
    end
    local delay = FULLDATA_RETRY_DELAYS[self._fullDataRetries] or 30
    self._fullDataSafetyTimer = DoF.Addon:ScheduleTimer(function()
        self._fullDataSafetyTimer = nil
        if self.WaitingForFullData then
            if self._showSystemMessages then
                DoF.Utils:Warn(DoF.Locale:Format("combat.sync.timeout_retry", self._fullDataRetries or 0, FULLDATA_MAX_RETRIES))
            end
            self:RequestFullData()
        end
    end, delay)
end

-- Сброс состояния ожидания (вызывать при успешном получении данных)
function DoF.Sync:FullDataReceived()
    self.WaitingForFullData = false
    self._fullDataRetries = 0
    if self._fullDataSafetyTimer then
        DoF.Addon:CancelTimer(self._fullDataSafetyTimer)
        self._fullDataSafetyTimer = nil
    end
end

-- Ручной запрос данных NPC от мастера (кнопка "🔄" в окне персонажа).
-- Если выбран NPC без unitData — точечный REQUEST_UNIT (не дёргаем всю базу
-- ради одного юнита). Иначе полный ресинк через RequestFullData. Дебаунс 5с
-- защищает от мультикликов и от спама мастера.
local MANUAL_REQUEST_DEBOUNCE = 5
function DoF.Sync:RequestNPCDataManual()
    if not IsInGroup() then
        DoF.Utils:Warn(DoF.L["combat.sync.not_in_group"])
        return
    end

    local now = GetTime()
    if self._lastManualRequest and (now - self._lastManualRequest) < MANUAL_REQUEST_DEBOUNCE then
        local left = math.ceil(MANUAL_REQUEST_DEBOUNCE - (now - self._lastManualRequest))
        DoF.Utils:Info(DoF.Locale:Format("combat.sync.wait_before_retry", left))
        return
    end
    self._lastManualRequest = now

    -- Точечный запрос если есть выделенный NPC без данных
    local guid = UnitGUID("target")
    if guid and not UnitIsPlayer("target") then
        local data = DoF.Units and DoF.Units:Get(guid)
        if not data then
            self:Send("REQUEST_UNIT", guid)
            DoF.Utils:Info(DoF.L["combat.sync.requested_target"])
            return
        end
    end

    -- Иначе полный ресинк
    self._fullDataRetries = 0
    self:RequestFullData()
    DoF.Utils:Info(DoF.L["combat.sync.requested_all"])
end

-- ═══════════════════════════════════════════════════════════
-- МАСТЕР (ВЕДУЩИЙ)
-- ═══════════════════════════════════════════════════════════

function DoF.Sync:FindMaster()
    if IsInRaid() then
        for i = 1, 40 do
            local name, rank = GetRaidRosterInfo(i)
            if rank == 2 then
                return name
            end
        end
    elseif IsInGroup() then
        if UnitIsGroupLeader("player") then
            return UnitName("player")
        end
        for i = 1, 4 do
            if UnitIsGroupLeader("party" .. i) then
                return UnitName("party" .. i)
            end
        end
    end
    return UnitName("player")
end

function DoF.Sync:UpdateMasterStatus()
    local wasMaster = self._isMaster
    local oldMaster = self.MasterName
    self.MasterName = self:FindMaster()
    self._isMaster = (self.MasterName == UnitName("player"))

    -- Смена мастера — сбрасываем флаг recovery
    if oldMaster ~= self.MasterName then
        self._masterRecoveryDone = false
    end

    -- Пересчёт видимости системных сообщений: мастер всегда видит, не-мастер — по настройке
    if wasMaster ~= self._isMaster then
        self:_RecalcShowSystemMessages()
    end

    if self._isMaster and not wasMaster and IsInGroup() then
        self:Send("MASTER", self.MasterName)
        DoF.Utils:Info(DoF.L["combat.sync.you_are_master"])
        DoF.Events:Fire("MASTER_CHANGED", self.MasterName)
    elseif not self._isMaster and wasMaster then
        -- Потеря статуса мастера — уведомляем подписчиков (для остановки
        -- heartbeat, обновления UI и т.п.).
        DoF.Events:Fire("MASTER_CHANGED", self.MasterName)
    end
end

function DoF.Sync:IsMaster()
    if self._isMaster then return true end
    if not IsInGroup() then return true end
    return false
end

function DoF.Sync:HasMasterAuth(senderName)
    return self.MasterName == senderName
end

function DoF.Sync:GetMasterName()
    return self.MasterName
end

-- ═══════════════════════════════════════════════════════════
-- ВОССТАНОВЛЕНИЕ ДАННЫХ (КРАШ-РЕКАВЕРИ)
-- ═══════════════════════════════════════════════════════════

-- Однократное восстановление данных мастера после релога
-- Вызывается из deferred-таймера и GROUP_ROSTER_UPDATE (кто первый — при IsInGroup()=true)
function DoF.Sync:PerformMasterRecovery()
    if self._masterRecoveryDone then return end
    if not self:IsMaster() then return end
    if not IsInGroup() then return end

    self._masterRecoveryDone = true

    -- Краш-рекавери: запрашиваем у группы ВСЁ (NPC + бой + эффекты)
    self._recoveryTimer = DoF.Addon:ScheduleTimer(function()
        if self:IsMaster() and IsInGroup() then
            self:RequestRecoveryData()
        end
    end, 2)
end

-- Детерминированный выбор кандидата-ответчика для RECOVERY_REQUEST.
-- Берём игроков из ростера, сортируем по имени, исключаем мастера и идём
-- от начала. attemptIndex=1 — первый, 2 — второй и т.д. Возвращает nil если
-- кандидатов не осталось.
function DoF.Sync:_PickRecoveryCandidate(attemptIndex)
    local myName = UnitName("player")
    local names = {}
    if IsInRaid() then
        for i = 1, 40 do
            local name = GetRaidRosterInfo(i)
            if name and name ~= myName then
                table_insert(names, name)
            end
        end
    elseif IsInGroup() then
        for i = 1, 4 do
            local name = UnitName("party" .. i)
            if name and name ~= myName then
                table_insert(names, name)
            end
        end
    end
    table.sort(names)
    return names[attemptIndex]
end

-- Мастер запрашивает восстановление данных после краша. Запрос идёт
-- к ОДНОМУ назначенному игроку (не broadcast), чтобы при рейде 40
-- человек не получить 40 одновременных ответов, которые забили бы ChatThrottleLib
-- и новый мастер не смог бы разобрать мёрджить конфликтующие данные.
-- Если назначенный не отвечает за 5с — пробуем следующего кандидата (до 3 попыток).
function DoF.Sync:RequestRecoveryData(attemptIndex)
    if not self:IsMaster() then return end
    if not IsInGroup() then return end

    attemptIndex = attemptIndex or 1
    if attemptIndex > 3 then
        if self._showSystemMessages then
            DoF.Utils:Warn(DoF.L["combat.sync.recovery_failed"])
        end
        return
    end

    local candidate = self:_PickRecoveryCandidate(attemptIndex)
    if not candidate then
        if self._showSystemMessages then
            DoF.Utils:Info(DoF.L["combat.sync.recovery_no_candidates"])
        end
        return
    end

    -- Флаг для отслеживания — получили ли мы ответ. Сбрасывается в
    -- COMBAT_STATE_RECOVERY/FULLDATA3/EFFECT_SYNC_RECOVERY handlers.
    self._recoveryAwaiting = candidate
    self:Send("RECOVERY_REQUEST", candidate)
    if self._showSystemMessages then
        DoF.Utils:Info(DoF.Locale:Format("combat.sync.recovery_request", candidate, attemptIndex))
    end

    -- Фолбэк-таймер на случай, если кандидат не ответил
    if self._recoveryFallbackTimer then
        DoF.Addon:CancelTimer(self._recoveryFallbackTimer)
    end
    self._recoveryFallbackTimer = DoF.Addon:ScheduleTimer(function()
        self._recoveryFallbackTimer = nil
        -- Если за 5с никто не отозвался — пробуем следующего
        if self._recoveryAwaiting == candidate then
            self._recoveryAwaiting = nil
            self:RequestRecoveryData(attemptIndex + 1)
        end
    end, 5)
end

-- Вызывается из handler'ов, которые получают данные в ответ на RECOVERY_REQUEST.
-- Отмечает успешный ответ, останавливает фолбэк-таймер.
function DoF.Sync:_MarkRecoveryReceived()
    self._recoveryAwaiting = nil
    if self._recoveryFallbackTimer then
        DoF.Addon:CancelTimer(self._recoveryFallbackTimer)
        self._recoveryFallbackTimer = nil
    end
end

-- ═══════════════════════════════════════════════════════════
-- ОТПРАВКА ДАННЫХ
-- ═══════════════════════════════════════════════════════════

-- Мягкий лимит размера одного сообщения. Hard-limit Blizzard = 255 байт,
-- но AceComm автоматически чанкирует длинные сообщения. Предупреждение нужно
-- только для точечных случаев, где автор случайно собрал огромный payload
-- (обычно — забытый escape или конкатенация массивов). Молчаливое чанкирование
-- тратит полосу ChatThrottleLib.
local SOFT_SIZE_WARN = 240
-- Команды, где большой payload ожидаем и чанкирование корректно
local EXPECTED_LARGE = {
    FULLDATA = true, FULLDATA3 = true,
    COMBATLOG = true,        -- длинные строки логов с цветами
    COMBAT_START = true,     -- при 30+ участниках список участников длинный
    COMBAT_STATE = true,     -- то же
    COMBAT_STATE_RECOVERY = true,
}

function DoF.Sync:Send(cmd, data, prio)
    if not IsInGroup() then return end

    local message = cmd
    if data then
        message = cmd .. ":" .. data
    end

    if #message > SOFT_SIZE_WARN and not EXPECTED_LARGE[cmd] then
        if not self._sizeWarned then self._sizeWarned = {} end
        if not self._sizeWarned[cmd] and self._showSystemMessages then
            self._sizeWarned[cmd] = true
            DoF.Utils:Warn(DoF.Locale:Format("combat.sync.message_too_big",
                cmd, #message, SOFT_SIZE_WARN))
        end
    end

    local channel = IsInRaid() and "RAID" or "PARTY"
    local effectivePrio = prio or COMMAND_PRIORITY[cmd] or "NORMAL"
    DoF.Addon:SendCommMessage(DoF.Config.ADDON_PREFIX, message, channel, nil, effectivePrio)
end

function DoF.Sync:SendTo(cmd, data, targetPlayer, prio)
    if not IsInGroup() then return end

    local message = cmd
    if data then
        message = cmd .. ":" .. data
    end

    local effectivePrio = prio or COMMAND_PRIORITY[cmd] or "NORMAL"
    DoF.Addon:SendCommMessage(DoF.Config.ADDON_PREFIX, message, "WHISPER", targetPlayer, effectivePrio)
end

-- ═══════════════════════════════════════════════════════════
-- НАДЁЖНАЯ ДОСТАВКА (ACK/RETRY)
-- ═══════════════════════════════════════════════════════════

local ACK_MAX_RETRIES = 3    -- максимум попыток
local ACK_DEDUP_TTL = 30     -- секунд хранения ID для дедупликации

-- Адаптивный таймаут ACK в зависимости от размера группы.
-- ChatThrottleLib имеет MAX_CPS≈800, и при 30+ игроках очередь ALERT может
-- задерживать доставку на несколько секунд. Фиксированный 3с даёт ложные
-- ретраи, что порождает каскад дубликатов. Формула: 3с базово + по 1с на
-- каждые 10 участников группы сверх первых 10.
local function GetAckTimeout()
    local n = GetNumGroupMembers() or 0
    if n <= 10 then return 3 end
    return 3 + math.floor((n - 10) / 10) + 1   -- 11–20:4с, 21–30:5с, 31–40:6с
end

-- Отправить сообщение с гарантией доставки (обёртка RELIABLE)
-- target: имя игрока для whisper, или nil для broadcast
function DoF.Sync:SendReliable(cmd, data, target)
    if not IsInGroup() then return end

    local msgId = self._nextMsgId
    self._nextMsgId = self._nextMsgId + 1

    -- Формат: msgId;originalCmd;originalData
    local payload = msgId .. ";" .. cmd
    if data and data ~= "" then
        payload = payload .. ";" .. data
    end

    -- Сохраняем для отслеживания ACK
    self._pendingAcks[msgId] = {
        cmd = cmd,
        data = data,
        target = target,
        retries = 0,
    }

    -- Отправляем
    if target then
        self:SendTo("RELIABLE", payload, target)
    else
        self:Send("RELIABLE", payload)
    end

    -- Таймер на ожидание ACK
    self._pendingAcks[msgId].timer = DoF.Addon:ScheduleTimer(function()
        self:_RetryOrFail(msgId)
    end, GetAckTimeout())
end

-- Повтор или провал доставки
function DoF.Sync:_RetryOrFail(msgId)
    local pending = self._pendingAcks[msgId]
    if not pending then return end -- Уже получен ACK

    pending.retries = pending.retries + 1
    if pending.retries > ACK_MAX_RETRIES then
        -- Исчерпаны попытки — очищаем и уведомляем
        self._pendingAcks[msgId] = nil

        if pending.cmd == "TURN_CHANGE" then
            DoF.Utils:Warn(DoF.Locale:Format("combat.sync.turn_change_no_ack", ACK_MAX_RETRIES))
        elseif pending.cmd == "ACTION_DONE" then
            DoF.Utils:Warn(DoF.L["combat.sync.action_done_no_ack"])
        end
        return
    end

    -- Повторная отправка
    local payload = msgId .. ";" .. pending.cmd
    if pending.data and pending.data ~= "" then
        payload = payload .. ";" .. pending.data
    end

    if pending.target then
        self:SendTo("RELIABLE", payload, pending.target)
    else
        self:Send("RELIABLE", payload)
    end

    -- Новый таймер
    pending.timer = DoF.Addon:ScheduleTimer(function()
        self:_RetryOrFail(msgId)
    end, GetAckTimeout())
end

-- Обработка входящего ACK
function DoF.Sync:_HandleAck(msgIdStr, sender)
    local msgId = tonumber(msgIdStr)
    if not msgId then return end

    local pending = self._pendingAcks[msgId]
    if pending then
        if pending.timer then
            DoF.Addon:CancelTimer(pending.timer)
        end
        self._pendingAcks[msgId] = nil
    end
end

-- Обработка входящего RELIABLE — распаковка, дедупликация, ACK, диспатч
function DoF.Sync:_HandleReliable(args, sender)
    -- Формат args: "msgId;cmd;originalData" (originalData может отсутствовать)
    local msgIdStr, rest = args:match("^(%d+);(.*)")
    if not msgIdStr then return end

    local msgId = tonumber(msgIdStr)
    local cmd, originalData = rest:match("^([^;]+);?(.*)")
    if not cmd then return end

    -- Отправляем ACK в любом случае (даже если дубликат)
    self:SendTo("ACK", msgIdStr, sender)

    -- Дедупликация: проверяем видели ли мы уже это сообщение
    local dedupKey = sender .. ":" .. msgIdStr
    local now = GetTime()
    if self._seenMsgIds[dedupKey] then
        return -- Уже обработано — ACK отправлен, пропускаем
    end
    self._seenMsgIds[dedupKey] = now + ACK_DEDUP_TTL

    -- Защита: внутренняя команда внутри RELIABLE обёртки НЕ проходила ValidateCommand
    -- в OnMessage (проверялся только сам RELIABLE, который в SAFE). Без этой проверки
    -- не-мастер мог обернуть PHASE_CHANGE/TURN_CHANGE/UNIT в RELIABLE и обойти
    -- Security. Проверяем упакованную команду здесь.
    local isValid, reason = self:ValidateCommand(cmd, sender)
    if not isValid then
        self:LogSecurityEvent(DoF.Locale:Format("combat.sync.in_reliable", cmd), sender, reason)
        return
    end

    -- Диспатч в обычный обработчик
    local handler = self.Handlers[cmd]
    if handler then
        handler(self, originalData or "", sender)
    end
end

-- Очистка устаревших записей дедупликации (вызывать периодически)
function DoF.Sync:_CleanupSeenMsgIds()
    local now = GetTime()
    for key, expireTime in pairs(self._seenMsgIds) do
        if now > expireTime then
            self._seenMsgIds[key] = nil
        end
    end
end

-- Инициализация периодической очистки (вызывается из Init.lua)
function DoF.Sync:StartReliableCleanup()
    if self._reliableCleanupTimer then return end
    self._reliableCleanupTimer = DoF.Addon:ScheduleRepeatingTimer(function()
        self:_CleanupSeenMsgIds()
    end, 30)
end

function DoF.Sync:BroadcastUnit(guid, data)
    if not data then
        self:Send("REMOVE", guid)
    else
        local passivesStr = DoF.Passives and DoF.Passives:Encode(data.passives, data.adaptTracker) or ""
        self:Send("UNIT", string.format("%s;%s;%d;%d;%d;%d;%d;%d;%d;%s",
            guid,
            DoF.Units.EscapeName(data.name),
            data.hp,
            data.maxHp,
            data.fort,
            data.reflex,
            data.will,
            data.shield or 0,
            data.hpVersion or 0,
            passivesStr))
    end
end

function DoF.Sync:BroadcastPlayerData()
    local now = GetTime()
    -- Адаптивный throttle: больше игроков → реже отправляем (экономия полосы).
    -- ChatThrottleLib имеет MAX_CPS≈800, а PLAYERDATA летит от ВСЕХ игроков
    -- одновременно. При рейде 40 человек нужны более щадящие интервалы,
    -- иначе очередь BULK забьётся и задержит ALERT-команды боя.
    local memberCount = GetNumGroupMembers() or 0
    local throttle
    if memberCount > 30 then
        throttle = 5.0
    elseif memberCount > 20 then
        throttle = 4.0
    elseif memberCount > 15 then
        throttle = 3.0
    elseif memberCount > 8 then
        throttle = 2.0
    else
        throttle = 1.0
    end

    if self._lastPlayerDataSent and (now - self._lastPlayerDataSent) < throttle then
        -- Откладываем отправку, чтобы не спамить при массовых изменениях
        if not self._playerDataPending then
            self._playerDataPending = true
            self._playerDataTimer = DoF.Addon:ScheduleTimer(function()
                self._playerDataPending = false
                self:BroadcastPlayerData()
            end, throttle)
        end
        return
    end
    self._lastPlayerDataSent = now

    -- Сначала обновляем self.RaidData[myName] (включая актуальный hpVersion),
    -- затем отправляем его же значение. Раньше UpdateMyRaidData вызывался ПОСЛЕ
    -- Send — в payload попадала устаревшая на 1 broadcast версия, и master'ские
    -- stale-rejection проверки работали неверно.
    self:UpdateMyRaidData()
    local myName = UnitName("player")
    local myData = self.RaidData[myName]

    -- core = первые 15 полей (реальные данные игрока). hpVersion не включён в
    -- сравнение для dedup: он меняется каждую секунду (GetServerTime), но не
    -- отражает содержательное изменение. Так мы не спамим сеть одинаковыми
    -- данными только из-за тикающего таймстампа.
    local core = string_format("%d;%d;%d;%s;%d;%d;%d;%d;%d;%d;%d;%d;%d;%d;%d",
        DoF.Stats:GetCurrentHP(),
        DoF.Stats:GetMaxHP(),
        DoF.Stats:GetLevel(),
        DoF.Stats:GetRole() or "none",
        DoF.Stats:GetWounds(),
        DoF.Stats:GetShield(),
        DoF.Stats:GetTotal("Strength"),
        DoF.Stats:GetTotal("Dexterity"),
        DoF.Stats:GetTotal("Intelligence"),
        DoF.Stats:GetTotal("Spirit"),
        DoF.Stats:GetTotal("Fortitude"),
        DoF.Stats:GetTotal("Reflex"),
        DoF.Stats:GetTotal("Will"),
        DoF.Stats:GetEnergy(),
        DoF.Stats:GetMaxEnergy())

    -- Не отправляем если содержательные поля не изменились
    if core == self._lastSentPlayerData then return end
    self._lastSentPlayerData = core

    local data = core .. ";" .. (myData and myData.hpVersion or 0)
    self:Send("PLAYERDATA", data)
end

function DoF.Sync:BroadcastMyHP()
    self:BroadcastPlayerData()
end

-- Отправить данные игрока конкретному получателю (whisper, без throttle/dedup)
function DoF.Sync:SendPlayerDataTo(targetPlayer)
    self:UpdateMyRaidData()
    local myName = UnitName("player")
    local myData = self.RaidData[myName]

    local data = string_format("%d;%d;%d;%s;%d;%d;%d;%d;%d;%d;%d;%d;%d;%d;%d;%d",
        DoF.Stats:GetCurrentHP(),
        DoF.Stats:GetMaxHP(),
        DoF.Stats:GetLevel(),
        DoF.Stats:GetRole() or "none",
        DoF.Stats:GetWounds(),
        DoF.Stats:GetShield(),
        DoF.Stats:GetTotal("Strength"),
        DoF.Stats:GetTotal("Dexterity"),
        DoF.Stats:GetTotal("Intelligence"),
        DoF.Stats:GetTotal("Spirit"),
        DoF.Stats:GetTotal("Fortitude"),
        DoF.Stats:GetTotal("Reflex"),
        DoF.Stats:GetTotal("Will"),
        DoF.Stats:GetEnergy(),
        DoF.Stats:GetMaxEnergy(),
        myData and myData.hpVersion or 0)
    self:SendTo("PLAYERDATA", data, targetPlayer)
end

-- Запросить данные конкретного игрока (whisper + очистка receiver cache)
function DoF.Sync:RequestPlayerData(targetName)
    if self._playerDataCache then
        self._playerDataCache[targetName] = nil
    end
    self:SendTo("REQUESTHP", "", targetName)
end

-- Запросить данные только у игроков, отсутствующих в RaidData
function DoF.Sync:RequestMissingPlayerData()
    local myName = UnitName("player")
    if IsInRaid() then
        for i = 1, 40 do
            local name = GetRaidRosterInfo(i)
            if name and name ~= myName and not self.RaidData[name] then
                self:RequestPlayerData(name)
            end
        end
    elseif IsInGroup() then
        for i = 1, 4 do
            local name = UnitName("party" .. i)
            if name and name ~= myName and not self.RaidData[name] then
                self:RequestPlayerData(name)
            end
        end
    end
end

-- ═══════════════════════════════════════════════════════════
-- БОЕВОЙ ЖУРНАЛ: перевод на стороне получателя
-- ═══════════════════════════════════════════════════════════
--
-- Раньше отправитель собирал готовую строку и слал её текстом — получатель
-- видел журнал на языке ОТПРАВИТЕЛЯ. Теперь по сети едут ключ локали и
-- аргументы, а текст собирает каждый клиент из своей локали.
--
-- Сложность в том, что аргументы тоже бывают переведёнными: название
-- характеристики, слово «успех», имя роли или эффекта. Поэтому каждый
-- аргумент едет со своим видом, и получатель знает, что с ним делать:
--
--   Arg.text(v)          имя игрока, число, имя NPC — как есть
--   Arg.key(k, color)    произвольный ключ локали
--   Arg.stat(id)         характеристика: имя и цвет из таблиц получателя
--   Arg.role(id)         роль: имя и цвет оттуда же
--   Arg.effect(id)       эффект: имя из справочника получателя
--   Arg.color(c, v)      обычное значение, но покрашенное
--
-- Одна запись журнала часто склеена из нескольких кусков: «кто кого атакует» +
-- «результат броска» + «урон». Каждый кусок — свой ключ локали, поэтому запись
-- едет как последовательность сегментов.
--
-- Формат провода: COMBATLOG2:<сегмент>~<сегмент>~...
--   <сегмент> = <ключ>;<арг>;<арг>;...
--   <арг>     = <вид>:<цвет|->:<значение>
-- В значениях '%', ';' и '~' escape-ятся процентным кодированием: описание
-- особого действия — свободный текст игрока и может содержать что угодно.

local LOG_ARG_SEP = ";"
local LOG_SEG_SEP = "~"

local function LogEncodeValue(v)
    v = tostring(v == nil and "" or v)
    -- Порядок важен: сначала '%', иначе перекодируем собственные escape-ы.
    v = v:gsub("%%", "%%25")
    v = v:gsub(";", "%%3B")
    v = v:gsub("~", "%%7E")
    v = v:gsub(",", "%%2C")
    return v
end

local function LogDecodeValue(v)
    v = v:gsub("%%2C", ",")
    v = v:gsub("%%7E", "~")
    v = v:gsub("%%3B", ";")
    v = v:gsub("%%25", "%%")
    return v
end

-- Конструкторы аргументов. Возвращают строку провода, а не текст: собрать
-- текст может только получатель, у него своя локаль.
DoF.Sync.Arg = {}
local Arg = DoF.Sync.Arg

function Arg.text(v)          return "t:-:" .. LogEncodeValue(v) end
function Arg.color(color, v)  return "t:" .. (color or "-") .. ":" .. LogEncodeValue(v) end
function Arg.key(k, color)    return "k:" .. (color or "-") .. ":" .. LogEncodeValue(k) end
-- Ключ, у которого есть собственные аргументы: «бонусный урон +3» — это
-- отдельная переводимая фраза с числом внутри, вложенная в другую фразу.
function Arg.keyf(k, color, ...)
    local parts = { LogEncodeValue(k) }
    for i = 1, select("#", ...) do
        parts[i + 1] = LogEncodeValue((select(i, ...)))
    end
    return "f:" .. (color or "-") .. ":" .. table.concat(parts, ",")
end

-- У stat/role/effect цвет по умолчанию берётся из таблиц получателя.
-- Явная пустая строка означает «не красить» — нужно, когда кусок уже покрашен
-- снаружи: вложенный |r иначе обрывает внешний цвет на середине строки.
function Arg.stat(id, color)  return "s:" .. (color or "-") .. ":" .. LogEncodeValue(id) end
function Arg.role(id, color)  return "r:" .. (color or "-") .. ":" .. LogEncodeValue(id) end
-- color:
--   не указан — берётся цвет из определения эффекта
--   ""        — без покраски; нужно, когда весь кусок уже покрашен снаружи,
--               иначе вложенный |r обрывает внешний цвет на середине строки
function Arg.effect(id, color) return "e:" .. (color or "-") .. ":" .. LogEncodeValue(id) end

-- Разворачивает один аргумент в текст на языке ПОЛУЧАТЕЛЯ.
local function LogResolveArg(spec)
    local kind, color, value = spec:match("^(%a):([^:]*):(.*)$")
    if not kind then
        -- Не наш формат — показываем как есть, лучше кривая строка, чем дыра.
        return LogDecodeValue(spec)
    end
    value = LogDecodeValue(value)

    local text
    if kind == "k" then
        text = DoF.Locale:Get(value)
    elseif kind == "f" then
        -- Вложенная фраза со своими аргументами: "key,arg1,arg2".
        -- Значение уже раскодировано целиком, поэтому режем по ',' до decode
        -- отдельных частей — сами части свои запятые экранировали.
        local parts = {}
        for piece in spec:match("^%a:[^:]*:(.*)$"):gmatch("[^,]+") do
            parts[#parts + 1] = LogDecodeValue(piece)
        end
        local nestedKey = table.remove(parts, 1)
        local ok, rendered = pcall(string.format, DoF.Locale:Get(nestedKey), unpack(parts))
        text = ok and rendered or DoF.Locale:Get(nestedKey)
    elseif kind == "s" then
        text = DoF.Config.StatNames[value] or value
        if color == "-" then color = DoF.Config.StatColors[value] end
    elseif kind == "r" then
        local role = DoF.Config.Roles[value]
        text = role and role.name or value
        if color == "-" then color = role and role.color end
    elseif kind == "e" then
        local def = DoF.Effects and DoF.Effects.Definitions[value]
        text = def and def.name or value
        -- Цвет эффекта — тоже свойство определения, берём его у себя.
        if color == "-" and def and def.color and DoF.Effects.GetColorHex then
            color = DoF.Effects:GetColorHex(def.color)
        end
    else
        text = value
    end

    if color and color ~= "-" and color ~= "" then
        return DoF.Utils:Color(color, text)
    end
    return text
end

-- Кодирует один сегмент: ключ + аргументы. Обычные значения (имена, числа)
-- можно передавать напрямую — они оборачиваются в Arg.text автоматически.
local function LogEncodeSegment(key, ...)
    local out = { key }
    for i = 1, select("#", ...) do
        local a = select(i, ...)
        -- Готовый спек от Arg.* отличаем по префиксу вида: "<буква>:<цвет>:".
        if type(a) == "string" and a:match("^%a:[^:]*:") then
            out[i + 1] = a
        else
            out[i + 1] = Arg.text(a)
        end
    end
    return table.concat(out, LOG_ARG_SEP)
end

-- Разворачивает один сегмент в текст на языке получателя.
local function LogRenderSegment(segment)
    local fields = {}
    for piece in segment:gmatch("[^" .. LOG_ARG_SEP .. "]+") do
        fields[#fields + 1] = piece
    end

    local key = table.remove(fields, 1)
    if not key then return "" end

    for i = 1, #fields do
        fields[i] = LogResolveArg(fields[i])
    end

    -- Ключа может не быть, если у отправителя версия новее. Показываем сам
    -- ключ: строка будет некрасивой, но событие не потеряется.
    if not DoF.Locale:Has(key) then
        return key .. " " .. table.concat(fields, " ")
    end

    local ok, line = pcall(string.format, DoF.Locale:Get(key), unpack(fields))
    if not ok then
        -- Рассинхрон числа аргументов между версиями локалей.
        return DoF.Locale:Get(key) .. " " .. table.concat(fields, " ")
    end
    return line
end

-- Склеивает сегменты в готовую строку.
-- Пробел между кусками добавляем сами, но только если следующий кусок не
-- начинается с пробела: строки-суффиксы (" Урон: %s") уже несут его в себе,
-- и без этой проверки в журнале появлялись бы двойные пробелы.
function DoF.Sync:BuildCombatLogLine(payload)
    local out = ""
    for segment in payload:gmatch("[^" .. LOG_SEG_SEP .. "]+") do
        local piece = LogRenderSegment(segment)
        if out == "" then
            out = piece
        elseif piece:match("^%s") then
            out = out .. piece
        else
            out = out .. " " .. piece
        end
    end
    return out
end

function DoF.Sync:_SendLogPayload(payload)
    -- ВАЖНО: WoW API НЕ возвращает PARTY/RAID сообщения отправителю!
    -- Поэтому ВСЕГДА сначала добавляем в свой локальный лог.
    if DoF.CombatLog then
        DoF.CombatLog:Add(self:BuildCombatLogLine(payload), UnitName("player"))
    end
    if IsInGroup() then
        self:Send("COMBATLOG2", payload)
    end
end

-- Запись из одного куска — самый частый случай.
function DoF.Sync:BroadcastCombatLogKey(key, ...)
    self:_SendLogPayload(LogEncodeSegment(key, ...))
end

-- Запись из нескольких кусков:
--   DoF.Sync:NewLogLine()
--       :Add("combat.uses", name, Arg.stat(stat), target)
--       :Add("combat.roll_result", ...)
--       :Send()
local LogLine = {}
LogLine.__index = LogLine

function LogLine:Add(key, ...)
    self.segments[#self.segments + 1] = LogEncodeSegment(key, ...)
    return self
end

function LogLine:Send()
    if #self.segments == 0 then return end
    DoF.Sync:_SendLogPayload(table.concat(self.segments, LOG_SEG_SEP))
end

function DoF.Sync:NewLogLine()
    return setmetatable({ segments = {} }, LogLine)
end

-- Дедупликация входящих записей журнала в окне 3с: тот же отправитель может
-- прислать одно и то же из-за RELIABLE-ретрая или повторного вызова.
-- Ключуемся по сырому payload, а не по собранному тексту: у COMBATLOG2 текст
-- зависит от локали получателя, а дубль надо ловить до сборки.
function DoF.Sync:IsDuplicateLogEntry(sender, raw)
    if not self._combatLogDedup then self._combatLogDedup = {} end
    local now = GetTime()
    local key = sender .. "|" .. raw
    local lastSeen = self._combatLogDedup[key]
    if lastSeen and (now - lastSeen) < 3 then
        return true
    end
    self._combatLogDedup[key] = now

    -- Ленивая чистка устаревших записей, чтобы таблица не росла без границ
    if now - (self._combatLogDedupLastCleanup or 0) > 30 then
        self._combatLogDedupLastCleanup = now
        for k, t in pairs(self._combatLogDedup) do
            if now - t > 3 then self._combatLogDedup[k] = nil end
        end
    end
    return false
end

-- Совместимость: приём готового текста от клиентов старых версий и те места,
-- где строка собирается динамически и ключа у неё нет.
function DoF.Sync:BroadcastCombatLog(text)
    if DoF.CombatLog then
        DoF.CombatLog:Add(text, UnitName("player"))
    end
    if IsInGroup() then
        self:Send("COMBATLOG", text)
    end
end

-- ═══════════════════════════════════════════════════════════
-- ДАННЫЕ ГРУППЫ
-- ═══════════════════════════════════════════════════════════

function DoF.Sync:UpdateMyRaidData()
    local myName = UnitName("player")
    -- hpVersion для игроков — серверное время (GetServerTime): общий масштаб,
    -- синхронизированный между клиентами. Благодаря этому master и client
    -- могут сравнивать версии напрямую, даже если каждый ведёт собственный счёт
    -- обновлений. Любой PLAYERDATA, собранный ПОСЛЕ master's optimistic bump,
    -- имеет строго больший timestamp, и мастер не откатывает hp назад.
    -- Для NPC (unitData) hpVersion остаётся монотонным счётчиком с tie-break
    -- по hpVersionSource — там логика иная (общий стейт, broadcast у всех).
    self.RaidData[myName] = {
        hp = DoF.Stats:GetCurrentHP(),
        maxHp = DoF.Stats:GetMaxHP(),
        level = DoF.Stats:GetLevel(),
        role = DoF.Stats:GetRole(),
        spec = DoF.Stats:GetRole(),  -- Алиас для совместимости
        wounds = DoF.Stats:GetWounds(),
        shield = DoF.Stats:GetShield(),
        -- Атакующие статы
        strength = DoF.Stats:GetTotal("Strength"),
        dexterity = DoF.Stats:GetTotal("Dexterity"),
        intelligence = DoF.Stats:GetTotal("Intelligence"),
        spirit = DoF.Stats:GetTotal("Spirit"),
        -- Защитные статы
        fortitude = DoF.Stats:GetTotal("Fortitude"),
        reflex = DoF.Stats:GetTotal("Reflex"),
        will = DoF.Stats:GetTotal("Will"),
        -- Энергия
        energy = DoF.Stats:GetEnergy(),
        maxEnergy = DoF.Stats:GetMaxEnergy(),
        hpVersion = GetServerTime(),
    }
end

function DoF.Sync:GetRaidData()
    return self.RaidData
end

function DoF.Sync:CleanupRaidData()
    -- Удаляем данные игроков, которые вышли из группы
    local myName = UnitName("player")
    local groupMembers = {}
    groupMembers[myName] = true

    if IsInRaid() then
        for i = 1, 40 do
            local name = GetRaidRosterInfo(i)
            if name then groupMembers[name] = true end
        end
    elseif IsInGroup() then
        for i = 1, 4 do
            local name = UnitName("party" .. i)
            if name then groupMembers[name] = true end
        end
    end

    for name in pairs(self.RaidData) do
        if not groupMembers[name] then
            self.RaidData[name] = nil
        end
    end

    -- Очищаем кэш PLAYERDATA для вышедших
    if self._playerDataCache then
        for name in pairs(self._playerDataCache) do
            if not groupMembers[name] then
                self._playerDataCache[name] = nil
            end
        end
    end

    -- Очищаем _pendingAcks с ушедшими таргетами: таймеры ретраев бессмысленны
    -- и занимают AceTimer-слоты, а при ~30-40 игроках их может накопиться
    -- десятки. Без этой чистки retry будут слать RELIABLE в никуда пока не
    -- исчерпают ACK_MAX_RETRIES, заодно засоряя _pendingAcks.
    if self._pendingAcks then
        for msgId, pending in pairs(self._pendingAcks) do
            if pending.target and not groupMembers[pending.target] then
                if pending.timer then
                    DoF.Addon:CancelTimer(pending.timer)
                end
                self._pendingAcks[msgId] = nil
            end
        end
    end

    -- VersionResponses: не держим записи ушедших игроков
    if self.VersionResponses then
        for name in pairs(self.VersionResponses) do
            if not groupMembers[name] then
                self.VersionResponses[name] = nil
            end
        end
    end

    -- Rate-limit трекеры запросов — чистим записи ушедших игроков
    if self._lastPlayerDataSentTo then
        for name in pairs(self._lastPlayerDataSentTo) do
            if not groupMembers[name] then
                self._lastPlayerDataSentTo[name] = nil
            end
        end
    end
    if self._lastFullDataSent then
        for name in pairs(self._lastFullDataSent) do
            if not groupMembers[name] then
                self._lastFullDataSent[name] = nil
            end
        end
    end
end

function DoF.Sync:GetPlayerData(name)
    return self.RaidData[name]
end

-- Текущий уровень игрока. Свой в RaidData не попадает (туда пишутся только
-- входящие PLAYERDATA), поэтому себя обслуживаем напрямую из Stats.
-- nil — про этого игрока данных ещё нет.
function DoF.Sync:GetPlayerLevel(name)
    if name == UnitName("player") then
        return DoF.Stats:GetLevel()
    end
    local data = self:GetPlayerData(name)
    return data and data.level
end

-- ═══════════════════════════════════════════════════════════
-- ОБРАБОТКА ВХОДЯЩИХ СООБЩЕНИЙ
-- ═══════════════════════════════════════════════════════════

function DoF.Sync:OnMessage(message, sender)
    local senderName = sender:match("([^-]+)") or sender
    local cmd, args = message:match("^([^:]+):?(.*)")

    if not cmd then return end

    -- Тихое подавление ранних сообщений (до загрузки ростера после релога)
    -- Данные будут запрошены заново через REQUESTHP после полной загрузки мира
    if self._suppressEarlyMessages and senderName ~= UnitName("player") then
        local isValid = self:ValidateCommand(cmd, senderName)
        if not isValid then
            return  -- тихо игнорируем, без "Заблокировано" в чате
        end
    end

    -- ПРОВЕРКА БЕЗОПАСНОСТИ
    local isValid, reason = self:ValidateCommand(cmd, senderName)
    if not isValid then
        self:LogSecurityEvent(cmd, senderName, reason)
        return
    end

    local handler = self.Handlers[cmd]
    if handler then
        handler(self, args, senderName)
    end
end

-- ═══════════════════════════════════════════════════════════
-- КОМАНДЫ МАСТЕРА
-- ═══════════════════════════════════════════════════════════

-- Выдать игроку уровень DoF. Клампим на стороне мастера, чтобы в эфир не
-- уходило заведомо мусорное значение; получатель клампит ещё раз у себя.
function DoF.Sync:SetPlayerLevel(targetName, level)
    if not DoF.Utils:RequireMaster(false) then return end

    level = tonumber(level)
    if not level then
        DoF.Utils:Error(DoF.L["core.usage.setlevel"])
        return
    end
    level = math.max(DoF.Config.MIN_LEVEL, math.min(DoF.Config.MAX_LEVEL, math.floor(level)))

    self:Send("SETLEVEL", targetName .. ";" .. level)

    if targetName == UnitName("player") then
        DoF.Stats:SetLevel(level)
    end

    DoF.Utils:Info(DoF.Locale:Format("combat.sync.level_set",
        DoF.Utils:Color("FFFFFF", targetName), DoF.Utils:Color("FFD700", level)))
end

function DoF.Sync:SetSpec(targetName, spec)
    if not DoF.Utils:RequireMaster(false) then return end

    self:Send("SETSPEC", targetName .. ";" .. (spec or "none"))
    
    if targetName == UnitName("player") then
        DoF.Stats:SetSpecialization(spec)
    end
    
    local specName = spec and (DoF.Config.Roles[spec] and DoF.Config.Roles[spec].name or spec) or DoF.L["combat.sync.spec_removed"]
    DoF.Utils:Info(DoF.Locale:Format("combat.sync.spec_set", DoF.Utils:Color("FFFFFF", targetName), DoF.Utils:Color("A06AF1", specName)))
    
    if DoF.CombatLog then
        DoF.CombatLog:AddMasterLog(DoF.Locale:Format("combat.sync.spec_log", specName, targetName), "master_action")
    end
end

function DoF.Sync:AddWound(targetName)
    if not DoF.Utils:RequireMaster(false) then return end

    self:Send("ADDWOUND", targetName)

    if targetName == UnitName("player") then
        DoF.Stats:AddWound()
    end

    -- Мгновенно обновляем RaidData для таргета (не ждём бродкаст обратно)
    if self.RaidData[targetName] then
        local newW = math.min(DoF.Config.MAX_WOUNDS, (self.RaidData[targetName].wounds or 0) + 1)
        self.RaidData[targetName].wounds = newW
        DoF.Events:Fire("PLAYER_DATA_RECEIVED", targetName, self.RaidData[targetName])
    end

    DoF.Utils:Info(DoF.Locale:Format("combat.sync.wound_added", DoF.Utils:Color("FFFFFF", targetName)))

    if DoF.CombatLog then
        DoF.CombatLog:AddMasterLog(DoF.Locale:Format("combat.sync.wound_added_log", targetName), "master_action")
    end
end

function DoF.Sync:RemoveWound(targetName)
    if not DoF.Utils:RequireMaster(false) then return end

    self:Send("REMOVEWOUND", targetName)

    if targetName == UnitName("player") then
        DoF.Stats:RemoveWound()
    end

    -- Мгновенно обновляем RaidData для таргета (не ждём бродкаст обратно)
    if self.RaidData[targetName] then
        self.RaidData[targetName].wounds = math.max(0, (self.RaidData[targetName].wounds or 0) - 1)
        DoF.Events:Fire("PLAYER_DATA_RECEIVED", targetName, self.RaidData[targetName])
    end

    DoF.Utils:Info(DoF.Locale:Format("combat.sync.wound_removed", DoF.Utils:Color("FFFFFF", targetName)))

    if DoF.CombatLog then
        DoF.CombatLog:AddMasterLog(DoF.Locale:Format("combat.sync.wound_removed_log", targetName), "master_action")
    end
end

function DoF.Sync:ResetPlayerStats(targetName)
    if not DoF.Utils:RequireMaster(false) then return end
    
    self:Send("RESETSTATS", targetName)
    
    if targetName == UnitName("player") then
        DoF.Stats:ResetStats()
    end
    
    DoF.Utils:Info(DoF.Locale:Format("combat.sync.stats_reset", DoF.Utils:Color("FFFFFF", targetName)))
    
    if DoF.CombatLog then
        DoF.CombatLog:AddMasterLog(DoF.Locale:Format("combat.sync.stats_reset_log", targetName), "master_action")
    end
end

function DoF.Sync:GiveShield(targetName)
    if not DoF.Utils:RequireMaster(false) then return end

    self:Send("GIVESHIELD", targetName)

    if targetName == UnitName("player") then
        DoF.Stats:ApplyShield()
    end

    DoF.Utils:Info(DoF.Locale:Format("combat.sync.shield_given", DoF.Utils:Color("FFFFFF", targetName)))

    if DoF.CombatLog then
        DoF.CombatLog:AddMasterLog(DoF.Locale:Format("combat.sync.shield_given_log", targetName), "master_action")
    end
end

function DoF.Sync:ModifyPlayerHP(targetName, delta)
    if not DoF.Utils:RequireMaster(false) then return end

    self:Send("MODIFYHP", targetName .. ";" .. delta)

    if targetName == UnitName("player") then
        DoF.Stats:ModifyHP(delta)
    elseif self.RaidData[targetName] then
        -- Оптимистичное обновление: мастер видит результат сразу, не дожидаясь round-trip.
        -- hpVersion = GetServerTime() — общий масштаб времени, который клиент
        -- превысит только в следующем своём BroadcastPlayerData, собранном
        -- ПОСЛЕ применения MODIFYHP. Любой in-flight старый PLAYERDATA
        -- от этого клиента будет иметь timestamp <= нашему и будет отбракован
        -- handler'ом как stale → эхо-мерцание HP у мастера устранено.
        local data = self.RaidData[targetName]
        data.hp = DoF.Utils:Clamp((data.hp or 0) + delta, 0, data.maxHp or 10)
        data.hpVersion = GetServerTime()
        DoF.Events:Fire("PLAYER_DATA_RECEIVED", targetName, data)
    end

end

-- ═══════════════════════════════════════════════════════════
-- БОЕВАЯ СИНХРОНИЗАЦИЯ
-- ═══════════════════════════════════════════════════════════

-- Текущая версия формата сериализованных данных FULLDATA3. При любом breaking
-- изменении формата Units:Serialize/Deserialize инкрементировать. Получатель с
-- иной версией не пытается десериализовать (избегает Lua-ошибки) и логирует
-- сообщение о необходимости обновить аддон.
local FULLDATA3_FORMAT_VERSION = 1

function DoF.Sync:BroadcastFullData(target)
    local data = DoF.Units:Serialize()
    if data == "" then data = "EMPTY" end

    -- Префикс v<версия>: — добавляет совместимость с будущими форматами.
    -- Старые приёмники получат payload, начинающийся с "v1:" и попытаются
    -- десериализовать его как AceSerializer — падения не будет (AceSerializer
    -- вернёт false), но данные не применятся. Это приемлемо на миграции.
    local versioned = "v" .. FULLDATA3_FORMAT_VERSION .. ":" .. data
    if target then
        self:SendTo("FULLDATA3", versioned, target)
    else
        self:Send("FULLDATA3", versioned)
    end
end

-- ═══════════════════════════════════════════════════════════
-- HEARTBEAT МАСТЕРА
-- ═══════════════════════════════════════════════════════════

-- Мастер периодически шлёт heartbeat — это служит двум целям:
-- 1) Liveness-сигнал: клиенты знают, что мастер жив. Если heartbeat не
--    приходит >30с, мастер считается крашнутым (см. master-crash detection).
-- 2) Hash NPC-данных для детекции рассинхрона (только в бою, иначе незачем).
-- Heartbeat работает ВСЕГДА в группе, не только в бою, иначе крашнувшийся
-- между боями мастер не детектируется.
function DoF.Sync:StartHeartbeat()
    if self._heartbeatTimer then return end
    self._heartbeatTimer = DoF.Addon:ScheduleRepeatingTimer(function()
        if not (self:IsMaster() and IsInGroup()) then return end
        local inCombat = DoF.TurnSystem and DoF.TurnSystem.phase ~= "idle"
        if inCombat then
            local npcCount, hpSum = 0, 0
            for _, data in pairs(DoF.db.global.unitData) do
                npcCount = npcCount + 1
                hpSum = hpSum + (data.hp or 0)
            end
            self:Send("HEARTBEAT", npcCount .. ";" .. hpSum)
        else
            -- Вне боя шлём пустой heartbeat — только liveness
            self:Send("HEARTBEAT", "0;0")
        end
    end, 10)
end

function DoF.Sync:StopHeartbeat()
    if self._heartbeatTimer then
        DoF.Addon:CancelTimer(self._heartbeatTimer)
        self._heartbeatTimer = nil
    end
end

-- Мониторинг liveness мастера. Если мастер существует по ростеру, но не шлёт
-- heartbeat >30с, это сигнал "замершего" мастера (клиент залип в лоадскрине,
-- /reload, addon crash). Мы НЕ пытаемся сменить мастера — это прерогатива
-- Blizzard (raid leader промоутится вручную или снимается по таймауту). Но
-- предупреждаем пользователей, чтобы /promote другого игрока вручную.
local MASTER_LIVENESS_TIMEOUT = 30
function DoF.Sync:StartMasterLivenessMonitor()
    if self._masterLivenessTimer then return end
    self._masterLivenessTimer = DoF.Addon:ScheduleRepeatingTimer(function()
        if self:IsMaster() or not IsInGroup() or not self.MasterName then return end
        if not self._lastMasterHeartbeat then return end
        local silence = GetTime() - self._lastMasterHeartbeat
        if silence > MASTER_LIVENESS_TIMEOUT then
            -- Предупреждаем один раз за тихий интервал
            if not self._masterSilenceWarned then
                self._masterSilenceWarned = true
                DoF.Utils:Warn(DoF.Locale:Format("combat.sync.master_silent",
                    self.MasterName, math.floor(silence)))
            end
        else
            self._masterSilenceWarned = nil
        end
    end, 10)
end

function DoF.Sync:StopMasterLivenessMonitor()
    if self._masterLivenessTimer then
        DoF.Addon:CancelTimer(self._masterLivenessTimer)
        self._masterLivenessTimer = nil
    end
    self._masterSilenceWarned = nil
end

-- ═══════════════════════════════════════════════════════════
-- ОСОБОЕ ДЕЙСТВИЕ
-- ═══════════════════════════════════════════════════════════

-- Игрок отправляет запрос мастеру
function DoF.Sync:SendSpecialActionRequest(description)
    local playerName = UnitName("player")
    self:Send("SPECIALACTION_REQUEST", playerName .. ";" .. description)
end

-- Мастер одобряет запрос с порогом и характеристикой
function DoF.Sync:SendSpecialActionApproved(playerName, threshold, stat, description, requireEnergy, energyAmount, actionType, actionParams, noRoll)
    description = description or ""
    local energyFlag = requireEnergy and "1" or "0"
    energyAmount = energyAmount or 1
    actionType = actionType or "simple_roll"
    actionParams = actionParams or ""
    local noRollFlag = noRoll and "1" or "0"

    -- Если одобряем самому себе - вызвать напрямую
    if playerName == UnitName("player") then
        DoF.Combat.PendingSpecialAction = nil
        DoF.Dialogs:ShowSpecialActionRollDialog(threshold, stat, description, requireEnergy, energyAmount, actionType, actionParams, noRoll)
    else
        self:Send("SPECIALACTION_APPROVED", playerName .. ";" .. threshold .. ";" .. stat .. ";" .. description .. ";" .. energyFlag .. ";" .. energyAmount .. ";" .. actionType .. ";" .. actionParams .. ";" .. noRollFlag)
    end
end

-- Мастер отклоняет запрос
function DoF.Sync:SendSpecialActionRejected(playerName)
    -- Если отклоняем самому себе - вызвать напрямую
    if playerName == UnitName("player") then
        DoF.Combat.PendingSpecialAction = nil
        local currentRound = DoF.TurnSystem and DoF.TurnSystem.round or 0
        DoF.Combat.RejectedSpecialActions[playerName] = currentRound
        DoF.Utils:Warn(DoF.L["combat.sync.special_rejected"])
        PlaySound(8960, "SFX")
    else
        self:Send("SPECIALACTION_REJECTED", playerName)
    end
end

-- ═══════════════════════════════════════════════════════════
-- ЭНЕРГИЯ
-- ═══════════════════════════════════════════════════════════

function DoF.Sync:GiveEnergy(targetName, amount)
    if not DoF.Utils:RequireMaster(false) then return end

    self:Send("GIVEENERGY", targetName .. ";" .. amount)

    if targetName == UnitName("player") then
        DoF.Stats:AddEnergy(amount)
    elseif self.RaidData[targetName] then
        -- Оптимистичное обновление: мастер видит результат сразу, не дожидаясь round-trip
        local data = self.RaidData[targetName]
        data.energy = DoF.Utils:Clamp((data.energy or 0) + amount, 0, data.maxEnergy or 10)
        DoF.Events:Fire("PLAYER_DATA_RECEIVED", targetName, data)
    end

    DoF.Utils:Info(DoF.Locale:Format("combat.sync.energy_given", DoF.Utils:Color("9966FF", DoF.Locale:Format("combat.sync.energy_amount", amount)), DoF.Utils:Color("FFFFFF", targetName)))
end

function DoF.Sync:TakeEnergy(targetName, amount)
    if not DoF.Utils:RequireMaster(false) then return end

    self:Send("TAKEENERGY", targetName .. ";" .. amount)

    if targetName == UnitName("player") then
        DoF.Stats:SpendEnergy(amount)
    elseif self.RaidData[targetName] then
        -- Оптимистичное обновление: мастер видит результат сразу, не дожидаясь round-trip
        local data = self.RaidData[targetName]
        data.energy = DoF.Utils:Clamp((data.energy or 0) - amount, 0, data.maxEnergy or 10)
        DoF.Events:Fire("PLAYER_DATA_RECEIVED", targetName, data)
    end

    DoF.Utils:Info(DoF.Locale:Format("combat.sync.energy_taken", DoF.Utils:Color("9966FF", DoF.Locale:Format("combat.sync.energy_amount", amount)), DoF.Utils:Color("FFFFFF", targetName)))
end

-- ═══════════════════════════════════════════════════════════
-- СИНХРОНИЗАЦИЯ ПОЛНОГО СОСТОЯНИЯ БОЯ
-- ═══════════════════════════════════════════════════════════

function DoF.Sync:SendCombatState(targetPlayer)
    if not DoF.Sync:IsMaster() then return end
    if not DoF.TurnSystem then return end

    local ts = DoF.TurnSystem

    -- Собираем участников
    local parts = {}
    for _, p in ipairs(ts.participants) do
        table.insert(parts, p.name .. "," .. p.guid .. "," .. p.roll .. "," .. (p.acted and "1" or "0"))
    end

    -- Вычисляем оставшееся время для корректной синхронизации таймера
    local remaining
    if ts.mode == "free" then
        remaining = ts:GetRoundTimeRemaining()
    else
        remaining = ts:GetTimeRemaining()
    end

    -- Формат: phase;mode;useTimer;duration;round;currentIndex;remaining;participant1;participant2;...
    local data = (ts.phase or "idle") .. ";" ..
                 (ts.mode or "queue") .. ";" ..
                 (ts.useTimer and "1" or "0") .. ";" ..
                 (ts.turnDuration or 60) .. ";" ..
                 (ts.round or 0) .. ";" ..
                 (ts.currentIndex or 0) .. ";" ..
                 remaining .. ";" ..
                 table.concat(parts, ";")

    if targetPlayer then
        self:SendTo("COMBAT_STATE", data, targetPlayer)
    else
        self:Send("COMBAT_STATE", data)
    end
end
