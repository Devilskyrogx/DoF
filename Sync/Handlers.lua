-- DoF/Sync/Handlers.lua
-- Обработчики входящих сообщений синхронизации

local ADDON_NAME, DoF = ...

-- Кэширование глобальных функций
local pairs = pairs
local ipairs = ipairs
local tonumber = tonumber
local tostring = tostring
local string_match = string.match
local string_format = string.format
local strsplit = strsplit
local UnitName = UnitName
local UnitGUID = UnitGUID
local GetTime = GetTime
local PlaySound = PlaySound

-- ═══════════════════════════════════════════════════════════
-- ОБРАБОТЧИКИ СООБЩЕНИЙ
-- ═══════════════════════════════════════════════════════════

DoF.Sync.Handlers = {
    -- ═══════════════════════════════════════════════════════════
    -- НАДЁЖНАЯ ДОСТАВКА (ACK/RELIABLE)
    -- ═══════════════════════════════════════════════════════════

    RELIABLE = function(self, args, sender)
        self:_HandleReliable(args, sender)
    end,

    ACK = function(self, args, sender)
        self:_HandleAck(args, sender)
    end,

    -- ═══════════════════════════════════════════════════════════
    -- МАСТЕР И БАЗОВЫЕ
    -- ═══════════════════════════════════════════════════════════

    MASTER = function(self, args, sender)
        -- Валидация: отправитель должен быть реальным лидером
        if sender ~= args then return end -- Мастером может объявить себя только сам отправитель
        if not self:HasMasterAuth(sender) then
            -- Проверяем через WoW API: sender должен быть лидером
            local isLeader = false
            if IsInRaid() then
                for i = 1, 40 do
                    local name, rank = GetRaidRosterInfo(i)
                    if name == sender and rank >= 2 then
                        isLeader = true
                        break
                    end
                end
            elseif IsInGroup() then
                for i = 1, 4 do
                    if UnitName("party" .. i) == sender and UnitIsGroupLeader("party" .. i) then
                        isLeader = true
                        break
                    end
                end
            end
            if not isLeader then return end
        end
        self.MasterName = args
        self._isMaster = (args == UnitName("player"))
        DoF.Utils:Info(DoF.Locale:Format("combat.sync.master_is", DoF.Utils:Color("A06AF1", args)))
        DoF.Events:Fire("MASTER_CHANGED", args)
    end,

    -- ═══════════════════════════════════════════════════════════
    -- ПРОВЕРКА ВЕРСИЙ
    -- ═══════════════════════════════════════════════════════════

    VERSION_REQUEST = function(self, args, sender)
        -- Отправляем свою версию в ответ
        self:Send("VERSION_RESPONSE", DoF.Config.VERSION)
    end,

    VERSION_RESPONSE = function(self, args, sender)
        -- Сохраняем ответ от игрока
        if not self.VersionResponses then
            self.VersionResponses = {}
        end
        -- Жёсткий лимит, чтобы таблица не росла бесконтрольно (например, если
        -- кто-то подделывает payload или спамит). 50 записей достаточно для
        -- любого рейда; лишние просто игнорируем.
        if not self.VersionResponses[sender] then
            local count = 0
            for _ in pairs(self.VersionResponses) do count = count + 1 end
            if count >= 50 then return end
        end
        self.VersionResponses[sender] = args
    end,

    -- ═══════════════════════════════════════════════════════════
    -- ДАННЫЕ NPC
    -- ═══════════════════════════════════════════════════════════
    
    UNIT = function(self, args, sender)
        local guid, name, hp, maxHp, fort, reflex, will, shield, hpVer, passivesStr =
            args:match("([^;]+);([^;]+);([^;]+);([^;]+);([^;]+);([^;]+);([^;]+);?([^;]*);?([^;]*);?([^;]*)")
        if guid then
            local incomingVersion = tonumber(hpVer) or 0
            local existing = DoF.db.global.unitData[guid]
            local decodedPassives, decodedAdaptTracker
            if passivesStr and passivesStr ~= "" and DoF.Passives then
                decodedPassives, decodedAdaptTracker = DoF.Passives:Decode(passivesStr)
            end

            name = DoF.Units.UnescapeName(name)
            local existingVer = existing and existing.hpVersion or 0
            -- Split-brain tie-break: при равных версиях (ситуация «двух мастеров»
            -- после сплит/мердж группы) побеждает детерминированно меньшее имя
            -- отправителя. Без этого порядок приёма определяет победителя →
            -- недетерминированный стейт между клиентами.
            local existingSource = existing and existing.hpVersionSource
            local rejectEqual = existingVer == incomingVersion and existingSource
                and existingSource < sender
            -- Если existing — это HPCHANGE-stub (создан до прихода UNIT),
            -- его hpVersion может быть выше из-за HPCHANGE, но fort/reflex/will=0.
            -- Принудительно полностью переписываем — у stub нет валидных данных.
            local existingIsStub = existing and existing._stub
            if existing and not existingIsStub and (existingVer > incomingVersion or rejectEqual) then
                -- HP и shield у клиента свежее — обновляем только параметры
                existing.name = name
                existing.fort = tonumber(fort)
                existing.reflex = tonumber(reflex)
                existing.will = tonumber(will)
                if decodedPassives then
                    existing.passives = decodedPassives
                end
                if decodedAdaptTracker then
                    existing.adaptTracker = decodedAdaptTracker
                end
            else
                -- Новые данные свежее, юнит новый или existing был stub —
                -- полное обновление. Stub-флаг снимаем (теперь у нас настоящие данные).
                DoF.db.global.unitData[guid] = {
                    name = name,
                    hp = tonumber(hp),
                    maxHp = tonumber(maxHp),
                    fort = tonumber(fort),
                    reflex = tonumber(reflex),
                    will = tonumber(will),
                    shield = tonumber(shield) or 0,
                    hpVersion = incomingVersion,
                    hpVersionSource = sender,
                    passives = decodedPassives,
                    adaptTracker = decodedAdaptTracker,
                }
            end
            DoF.Events:Fire("UNIT_HP_CHANGED", guid, tonumber(hp), tonumber(maxHp))
        end
    end,
    
    -- Синхронизация трекера адаптации (guid;stat;count)
    ADAPT = function(self, args, sender)
        if sender == UnitName("player") then return end
        local guid, stat, countStr = args:match("([^;]+);([^;]+);([^;]+)")
        if not guid then return end
        local existing = DoF.db.global.unitData[guid]
        if existing then
            existing.adaptTracker = { lastStat = stat, count = tonumber(countStr) or 0 }
        end
    end,

    HPCHANGE = function(self, args, sender)
        -- Пропускаем свои сообщения (уже применено локально)
        if sender == UnitName("player") then return end

        local guid, hp, maxHp, hpVer, deltaStr =
            args:match("([^;]+);([^;]+);([^;]+);?([^;]*);?([^;]*)")
        if not guid then return end
        local incomingVersion = tonumber(hpVer) or 0
        local delta = tonumber(deltaStr)
        local existing = DoF.db.global.unitData[guid]
        local wasDead = existing and (existing.hp or 0) <= 0

        if existing then
            local existingVer = existing.hpVersion or 0
            local existingSource = existing.hpVersionSource
            if existingVer > incomingVersion then
                -- Устаревшее — отклоняем
                if DoF.Sync._showSystemMessages then
                    DoF.Utils:Warn(DoF.Locale:Format("combat.sync.hpchange_rejected", incomingVersion, existingVer, sender))
                end
                return
            elseif existingVer == incomingVersion and delta then
                -- Та же версия + delta → конкурентная атака, применяем delta
                existing.hp = DoF.Utils:Clamp(existing.hp + delta, 0, existing.maxHp or tonumber(maxHp))
            elseif existingVer == incomingVersion and existingSource and existingSource < sender then
                -- Split-brain tie-break: равные версии без delta (ситуация двух мастеров
                -- после сплит/мердж). Побеждает детерминированно меньшее имя источника,
                -- чтобы все клиенты сошлись на одном значении независимо от порядка приёма.
                return
            else
                -- Входящая версия выше (или tie-break в нашу пользу) — абсолютное обновление
                existing.hp = tonumber(hp)
                existing.maxHp = tonumber(maxHp)
                existing.hpVersion = incomingVersion
                existing.hpVersionSource = sender
            end
            -- Обнаружение смерти NPC на стороне приёмника. Локальный ModifyHP
            -- файрит UNIT_DIED только у атакующего; без этого мастер не увидит
            -- смерть, нанесённую не им (ломает пассивку death_explosion).
            if existing.hp <= 0 and not wasDead then
                DoF.Events:Fire("UNIT_DIED", guid, existing.name)
            end
        else
            -- UNIT ещё не пришёл — создаём запись-заглушку с HP.
            -- _stub=true чтобы заглушка не разносилась через FULLDATA3 и не
            -- затирала реальные данные при ImportData. Снимается в UNIT handler
            -- когда придёт настоящее сообщение со статами.
            DoF.db.global.unitData[guid] = {
                name = guid,
                hp = tonumber(hp),
                maxHp = tonumber(maxHp),
                fort = 0, reflex = 0, will = 0,
                shield = 0,
                hpVersion = incomingVersion,
                _stub = true,
            }
            existing = DoF.db.global.unitData[guid]
        end
        DoF.Events:Fire("UNIT_HP_CHANGED", guid, existing.hp, existing.maxHp)
    end,
    
    REMOVE = function(self, args, sender)
        if not args or args == "" then return end
        DoF.db.global.unitData[args] = nil
        DoF.Events:Fire("UNIT_REMOVED", args)
    end,
    
    CLEAR = function(self, args, sender)
        DoF.db.global.unitData = {}
        DoF.Events:Fire("UNITS_CLEARED")
    end,
    
    REQUEST = function(self, args, sender)
        if self:IsMaster() then
            -- Rate-limit: один полный NPC-дамп одному игроку раз в 10 секунд.
            -- BroadcastFullData шлёт сериализованную БД всех НПЦ — это дорогая
            -- операция по ChatThrottleLib. При 40 игроках спам REQUEST от
            -- нескольких человек легко забьёт канал; 10-секундное окно
            -- даёт мастеру передохнуть. Без ограничения это DoS-вектор.
            if not self._lastFullDataSent then self._lastFullDataSent = {} end
            local now = GetTime()
            if self._lastFullDataSent[sender] and (now - self._lastFullDataSent[sender]) < 10 then
                return
            end
            self._lastFullDataSent[sender] = now
            self:BroadcastFullData(sender)
        end
    end,

    -- Точечный запрос данных одного NPC. Игрок жмёт кнопку "🔄" в окне
    -- персонажа когда у него «Нет данных» по таргету — мы шлём UNIT-сообщение
    -- только этому юниту, не трогая всю базу. Rate-limit: per-(sender, guid) 2с.
    REQUEST_UNIT = function(self, args, sender)
        if not self:IsMaster() then return end
        local guid = args
        if not guid or guid == "" then return end

        if not self._lastUnitReqSent then self._lastUnitReqSent = {} end
        local key = sender .. ":" .. guid
        local now = GetTime()
        if self._lastUnitReqSent[key] and (now - self._lastUnitReqSent[key]) < 2 then
            return
        end
        self._lastUnitReqSent[key] = now

        local data = DoF.Units and DoF.Units:Get(guid)
        if data then
            self:BroadcastUnit(guid, data)
        end
    end,
    
    FULLDATA = function(self, args, sender)
        local idx, total, data = args:match("^(%d+):(%d+):(.*)")
        idx, total = tonumber(idx), tonumber(total)

        -- Таймаут: очищаем устаревший буфер (>15 сек)
        if self.FullDataStartTime and (GetTime() - self.FullDataStartTime) > 15 then
            self.FullDataBuffer = {}
            self.FullDataExpected = 0
            self.FullDataStartTime = nil
            self.FullDataSender = nil
            -- Автоматически повторяем запрос при таймауте (через централизованный метод)
            if not self:IsMaster() then
                self:RequestFullData()
            end
            return -- Отбрасываем текущий чанк, вызвавший таймаут
        end

        if idx == 1 then
            self.FullDataBuffer = {}
            self.FullDataExpected = total
            self.FullDataStartTime = GetTime()
            self.FullDataSender = sender
        end

        -- Отклоняем чанки от другого отправителя (защита от перемешивания)
        if self.FullDataSender and self.FullDataSender ~= sender then
            return
        end

        self.FullDataBuffer[idx] = data

        local complete = true
        for i = 1, self.FullDataExpected do
            if not self.FullDataBuffer[i] then
                complete = false
                break
            end
        end

        if complete then
            local fullData = table.concat(self.FullDataBuffer)
            if fullData ~= "EMPTY" then
                -- authoritative=true только когда мы (не-мастер) ждали данные
                -- от мастера. При recovery мастеру от не-мастера — false,
                -- иначе чужие «дыры» удалят валидные юниты у нового мастера.
                local authoritative = self.WaitingForFullData and not self:IsMaster()
                DoF.Units:ImportData(DoF.Units:Deserialize(fullData), { authoritative = authoritative })
            end

            local count = DoF.Units:Count()
            if self.WaitingForFullData then
                if self._showSystemMessages then
                    DoF.Utils:Info(DoF.Locale:Format("combat.sync.data_from_master", count))
                end
                self:FullDataReceived()
            elseif self:IsMaster() and count > 0 then
                if self._showSystemMessages then
                    DoF.Utils:Info(DoF.Locale:Format("combat.sync.data_from_group", count))
                end
            end

            self.FullDataBuffer = {}
            self.FullDataExpected = 0
            self.FullDataStartTime = nil
            self.FullDataSender = nil
        end
    end,
    
    -- FULLDATA3: AceSerializer формат — автоматическая сериализация всех данных.
    -- Поддерживает опциональный префикс "v<N>:" для версионирования формата.
    -- Payload без префикса — legacy v1 (обратная совместимость).
    -- Максимально поддерживаемая локальная версия определена в Sync/Core.lua.
    FULLDATA3 = function(self, args, sender)
        if args ~= "EMPTY" then
            local version, body = args:match("^v(%d+):(.*)$")
            if version then
                version = tonumber(version)
                if version > 1 then
                    -- Формат новее, чем клиент умеет — не пытаемся десериализовать
                    if self._showSystemMessages then
                        DoF.Utils:Warn(DoF.Locale:Format("combat.sync.format_unsupported", version))
                    end
                    return
                end
                args = body
            end
            -- authoritative=true только когда мы (не-мастер) ждали данные
            -- от мастера. При recovery мастеру от не-мастера — false,
            -- иначе чужие «дыры» удалят валидные юниты у нового мастера.
            local authoritative = self.WaitingForFullData and not self:IsMaster()
            DoF.Units:ImportData(DoF.Units:Deserialize(args), { authoritative = authoritative })
        end

        local count = DoF.Units:Count()
        if self.WaitingForFullData then
            if self._showSystemMessages then
                DoF.Utils:Info(DoF.Locale:Format("combat.sync.data_from_master", count))
            end
            self:FullDataReceived()
        elseif self:IsMaster() and count > 0 then
            if self._showSystemMessages then
                DoF.Utils:Info(DoF.Locale:Format("combat.sync.data_from_group", count))
            end
            -- Отмечаем, что RECOVERY_REQUEST получил ответ — не пробуем следующего кандидата
            self:_MarkRecoveryReceived()
        end
    end,

    -- ═══════════════════════════════════════════════════════════
    -- ДАННЫЕ ИГРОКОВ
    -- ═══════════════════════════════════════════════════════════
    
    PLAYERDATA = function(self, args, sender)
        -- Инициализируем кэш если его нет
        if not self._playerDataCache then
            self._playerDataCache = {}
        end

        -- Проверяем кэш - если данные не изменились, пропускаем парсинг
        if self._playerDataCache[sender] == args then
            return
        end
        self._playerDataCache[sender] = args

        local parts = { strsplit(";", args) }
        local hp, maxHp, level, role = parts[1], parts[2], parts[3], parts[4]
        local wounds, shield = parts[5], parts[6]
        local str, dex, int, spi = parts[7], parts[8], parts[9], parts[10]
        local fort, refl, wil = parts[11], parts[12], parts[13]
        local energy, maxEnergy = parts[14], parts[15]
        local incomingVer = tonumber(parts[16]) or 0

        if hp then
            local roleValue = (role and role ~= "none") and role or nil

            -- Stale-rejection hp/maxHp: если master ранее сделал optimistic update
            -- (RaidData[sender].hpVersion = GetServerTime() в момент апдейта),
            -- а этот PLAYERDATA был собран отправителем ДО применения MODIFYHP
            -- (у него _myHpVersion < master.hpVersion), то hp в payload устарел.
            -- Сохраняем мастерское значение hp/maxHp, остальное принимаем свежее.
            -- Это устраняет визуальное мерцание HP у мастера после optimistic update.
            -- Legacy (отправитель без 16-го поля) → incomingVer=0; если у нас был
            -- bump с GetServerTime() (большое число), 0 < timestamp → stale. Корректно.
            local existing = self.RaidData[sender]
            local existingVer = existing and existing.hpVersion or 0
            local hpStale = existing and incomingVer > 0 and incomingVer < existingVer

            self.RaidData[sender] = {
                hp = hpStale and existing.hp or tonumber(hp),
                maxHp = hpStale and existing.maxHp or tonumber(maxHp),
                level = tonumber(level),
                role = roleValue,
                spec = roleValue,  -- Алиас для совместимости
                wounds = tonumber(wounds),
                shield = tonumber(shield),
                -- Атакующие статы
                strength = (str and str ~= "") and tonumber(str) or 0,
                dexterity = (dex and dex ~= "") and tonumber(dex) or 0,
                intelligence = (int and int ~= "") and tonumber(int) or 0,
                spirit = (spi and spi ~= "") and tonumber(spi) or 0,
                -- Защитные статы
                fortitude = (fort and fort ~= "") and tonumber(fort) or 0,
                reflex = (refl and refl ~= "") and tonumber(refl) or 0,
                will = (wil and wil ~= "") and tonumber(wil) or 0,
                -- Энергия
                energy = (energy and energy ~= "") and tonumber(energy) or 0,
                maxEnergy = (maxEnergy and maxEnergy ~= "") and tonumber(maxEnergy) or 2,
                hpVersion = math.max(existingVer, incomingVer),
            }

            -- Оповещение мастера если у игрока нет роли
            if self:IsMaster() and not roleValue then
                if not self.WarnedNoRole then self.WarnedNoRole = {} end
                if not self.WarnedNoRole[sender] then
                    self.WarnedNoRole[sender] = true
                    DoF.Utils:Warn(DoF.Locale:Format("combat.sync.no_role_chosen", DoF.Utils:Color("FFFFFF", sender)))
                end
            end

            -- Снимаем предупреждение если роль появилась
            if roleValue and self.WarnedNoRole then
                self.WarnedNoRole[sender] = nil
            end

            DoF.Events:Fire("PLAYER_DATA_RECEIVED", sender, self.RaidData[sender])
        end
    end,
    
    PLAYERHP = function(self, args, sender)
        local current, max = args:match("([^;]+);([^;]+)")
        if current then
            if not self.RaidData[sender] then
                -- Нет полных данных — запрашиваем у конкретного отправителя (whisper)
                self:RequestPlayerData(sender)
                return
            end
            self.RaidData[sender].hp = tonumber(current)
            self.RaidData[sender].maxHp = tonumber(max)
            DoF.Events:Fire("PLAYER_DATA_RECEIVED", sender, self.RaidData[sender])
        end
    end,
    
    REQUESTHP = function(self, args, sender)
        -- Rate-limit per-sender: один PLAYERDATA одному и тому же запросившему
        -- не чаще раза в секунду. При 40 игроках без лимита каждый может
        -- спамить запросы — суммарно >40 whisper-ответов в секунду, что
        -- переполнит ALERT-очередь и задержит критичные команды боя.
        if not self._lastPlayerDataSentTo then self._lastPlayerDataSentTo = {} end
        local now = GetTime()
        if self._lastPlayerDataSentTo[sender] and (now - self._lastPlayerDataSentTo[sender]) < 1 then
            return
        end
        self._lastPlayerDataSentTo[sender] = now
        self:SendPlayerDataTo(sender)
    end,

    -- Усталость лечения: healer → все. Формат: healerName;count;stacks.
    -- Принимаем только от самого healer'а (sender == healerName), иначе кто-то
    -- может подделать чужую усталость. stacks также синкается через effect
    -- healing_fatigue, но count до этого был чисто локальным у healer'а.
    FATIGUE = function(self, args, sender)
        local healerName, countStr, stacksStr = args:match("([^;]+);([^;]+);([^;]+)")
        if not healerName then return end
        if healerName ~= sender then return end  -- anti-spoof
        if not DoF.Combat then return end
        local count = tonumber(countStr) or 0
        if count > 0 then
            DoF.Combat.HealingFatigue[healerName] = { count = count }
        else
            DoF.Combat.HealingFatigue[healerName] = nil
        end
        -- stacks — для справки; авторитетное значение в Effects:healing_fatigue
    end,

    -- Трекер серии ударов танка: tank → все. Формат: tankName;guid;count.
    -- Каждый танк владеет своим трекером и рассылает его. Клиенты получают
    -- копию для UI/логики (до этого видел только сам танк).
    TANK_SHRED_TRACKER = function(self, args, sender)
        local tankName, guid, countStr = args:match("([^;]+);([^;]+);([^;]+)")
        if not tankName then return end
        if tankName ~= sender then return end  -- anti-spoof
        if not DoF.Combat or not DoF.Combat.TankShredTracker then return end
        local count = tonumber(countStr) or 0
        if not DoF.Combat.TankShredTracker[tankName] then
            DoF.Combat.TankShredTracker[tankName] = {}
        end
        DoF.Combat.TankShredTracker[tankName][guid] = count > 0 and count or nil
    end,
    
    -- Журнал в виде «ключ локали + аргументы»: текст собирается здесь, из
    -- локали ПОЛУЧАТЕЛЯ. Благодаря этому каждый читает бой на своём языке.
    COMBATLOG2 = function(self, args, sender)
        -- Игнорируем свои сообщения — их уже добавил BroadcastCombatLogKey
        if sender == UnitName("player") then return end
        if not DoF.CombatLog then return end
        if self:IsDuplicateLogEntry(sender, args) then return end

        DoF.CombatLog:Add(self:BuildCombatLogLine(args), sender)
    end,

    -- Готовый текст: клиенты старых версий и немногие места, где строка
    -- собирается динамически и ключа у неё нет. Такие записи остаются на
    -- языке отправителя — иначе их не перевести.
    COMBATLOG = function(self, args, sender)
        if sender == UnitName("player") then return end
        if not DoF.CombatLog then return end
        if self:IsDuplicateLogEntry(sender, args) then return end

        DoF.CombatLog:Add(args, sender)
    end,

    PLAYERHPCHANGE = function(self, args, sender)
        local playerName, oldHP, newHP = args:match("([^;]+);([^;]+);([^;]+)")
        if playerName and self:IsMaster() and playerName ~= UnitName("player") then
            local diff = tonumber(newHP) - tonumber(oldHP)
            if DoF.CombatLog then
                DoF.CombatLog:AddMasterLog(
                    string.format(DoF.L["combat.sync.hp_changed_log"],
                        playerName, oldHP, newHP, diff > 0 and "+" or "", diff),
                    "hp_change")
            end
        end
    end,
    
    -- ═══════════════════════════════════════════════════════════
    -- БОЙ И ЭФФЕКТЫ
    -- ═══════════════════════════════════════════════════════════
    
    NPCATTACK = function(self, args, sender)
        local target, dMin, dMax, threshold, defense, npcName, debuffId, debuffVal, debuffDur, instantStr =
            args:match("([^;]+);([^;]+);([^;]+);([^;]+);([^;]+);([^;]*);?([^;]*);?([^;]*);?([^;]*);?([^;]*)")
        if target == UnitName("player") then
            local damageMin = tonumber(dMin)
            local damageMax = tonumber(dMax)
            local thresh = tonumber(threshold)
            local npc = (npcName and npcName ~= "") and npcName or "NPC"
            local dId = (debuffId and debuffId ~= "") and debuffId or nil
            local dVal = tonumber(debuffVal) or 0
            local dDur = tonumber(debuffDur) or 0
            local instant = (instantStr == "1")

            if instant and DoF.Combat then
                -- Мгновенная защита: авто-бросок без окна
                local defStat = defense
                if defStat == "Hybrid" then
                    defStat = DoF.Combat:GetBestDefenseStat()
                end
                DoF.Combat:ProcessNPCAttack(damageMin, damageMax, thresh, defStat, npc, dId, dVal, dDur, true)
            elseif defense == "Hybrid" then
                if DoF.Dialogs and DoF.Dialogs.ShowHybridDefenseChoice then
                    DoF.Dialogs:ShowHybridDefenseChoice(npc, damageMin, damageMax, thresh, dId, dVal, dDur)
                end
            else
                if DoF.Dialogs and DoF.Dialogs.ShowNPCAttackAlert then
                    DoF.Dialogs:ShowNPCAttackAlert(npc, defense, damageMin, damageMax, thresh, dId, dVal, dDur)
                end
            end
        end
    end,

    -- Перехват урона: атака перенаправлена на танка
    REDIRECT_DAMAGE = function(self, args, sender)
        local target, dMin, dMax, threshold, defense, npcName, debuffId, debuffVal, debuffDur, instantStr =
            args:match("([^;]+);([^;]+);([^;]+);([^;]+);([^;]+);([^;]*);?([^;]*);?([^;]*);?([^;]*);?([^;]*)")
        if target == UnitName("player") then
            local damageMin = tonumber(dMin)
            local damageMax = tonumber(dMax)
            local thresh = tonumber(threshold)
            local npc = (npcName and npcName ~= "") and npcName or "NPC"
            local dId = (debuffId and debuffId ~= "") and debuffId or nil
            local dVal = tonumber(debuffVal) or 0
            local dDur = tonumber(debuffDur) or 0
            local instant = (instantStr == "1")

            if instant and DoF.Combat then
                local defStat = defense
                if defStat == "Hybrid" then
                    defStat = DoF.Combat:GetBestDefenseStat()
                end
                DoF.Combat:ProcessNPCAttack(damageMin, damageMax, thresh, defStat, npc, dId, dVal, dDur, true)
            elseif defense == "Hybrid" then
                if DoF.Dialogs and DoF.Dialogs.ShowHybridDefenseChoice then
                    DoF.Dialogs:ShowHybridDefenseChoice(npc, damageMin, damageMax, thresh, dId, dVal, dDur)
                end
            else
                if DoF.Dialogs and DoF.Dialogs.ShowNPCAttackAlert then
                    DoF.Dialogs:ShowNPCAttackAlert(npc, defense, damageMin, damageMax, thresh, dId, dVal, dDur)
                end
            end
        end
    end,

    MODIFYHP = function(self, args, sender)
        local target, value = args:match("([^;]+);([^;-]*-?%d+)")
        if target == UnitName("player") and DoF.Combat then
            DoF.Combat:ProcessModifyHP(tonumber(value), sender)
        end
    end,
    
    HEAL = function(self, args, sender)
        local target, heal, removeWound = args:match("([^;]+);([^;]+);?([^;]*)")
        if target == UnitName("player") and DoF.Combat then
            DoF.Combat:ProcessHeal(tonumber(heal), sender, removeWound == "1")
        end
    end,
    
    FULLHEAL = function(self, args, sender)
        local target, removeWound = args:match("([^;]+);?([^;]*)")
        if target == UnitName("player") then
            local maxHP = DoF.Stats:GetMaxHP()
            DoF.Stats:SetCurrentHP(maxHP)
            DoF.Events:Fire("PLAYER_HP_CHANGED", maxHP, maxHP)
            DoF.Utils:Info(DoF.Locale:Format("combat.sync.full_heal_from", sender, maxHP, maxHP))
            if removeWound == "1" and DoF.Stats:GetWounds() > 0 then
                DoF.Stats:RemoveWound()
            end
            if DoF.Sync then
                DoF.Sync:BroadcastPlayerData()
            end
        end
    end,

    SHIELD = function(self, args, sender)
        local target = args
        if target == UnitName("player") and DoF.Combat then
            DoF.Combat:ProcessShield(sender)
        end
    end,
    
    SETLEVEL = function(self, args, sender)
        local target, level = args:match("([^;]+);([^;]+)")
        if target ~= UnitName("player") then return end

        local oldLevel = DoF.Stats:GetLevel()
        if not DoF.Stats:SetLevel(level) then return end

        local newLevel = DoF.Stats:GetLevel()
        if newLevel > oldLevel then
            DoF.Utils:Info(DoF.Locale:Format("combat.sync.level_raised_by", newLevel, sender))
        else
            DoF.Utils:Warn(DoF.Locale:Format("combat.sync.level_lowered_by", newLevel, sender))
        end
    end,

    SETSPEC = function(self, args, sender)
        local target, spec = args:match("([^;]+);([^;]+)")
        if target == UnitName("player") then
            local specValue = spec ~= "none" and spec or nil
            local currentRole = DoF.Stats:GetRole()
            
            if currentRole and not specValue then
                DoF.Sync:ShowConfirmDialog(
                    "SETSPEC", sender, DoF.L["combat.sync.role_removal_title"],
                    DoF.Locale:Format("combat.sync.role_removal_text", sender, currentRole),
                    function()
                        DoF.Stats:SetRole(nil)
                        DoF.Utils:Warn(DoF.Locale:Format("combat.sync.role_removed_by", sender))
                    end
                )
            else
                DoF.Stats:SetRole(specValue)
                if specValue then
                    DoF.Utils:Info(DoF.Locale:Format("combat.sync.role_changed_by", DoF.Utils:Color("A06AF1", specValue), sender))
                end
            end
        end
    end,
    
    ADDWOUND = function(self, args, sender)
        if args == UnitName("player") then
            DoF.Stats:AddWound()
            DoF.Utils:Warn(DoF.Locale:Format("combat.sync.wound_from", sender))
        end
    end,
    
    REMOVEWOUND = function(self, args, sender)
        if args == UnitName("player") then
            DoF.Stats:RemoveWound()
            DoF.Utils:Info(DoF.Locale:Format("combat.sync.wound_removed_by", sender))
        end
    end,

    -- Игрок получил критическое ранение — у мастера открывается диалог с выбором
    -- (дать бросок на выживание / оставить с ранением). Остальные получат новое
    -- значение wounds через PLAYERDATA и увидят «КРИТ» в UI.
    CRITICAL_WOUND = function(self, args, sender)
        -- Валидация: только сам игрок может сообщить о своём критическом ранении
        if sender ~= args then return end

        if DoF.Sync:IsMaster() then
            PlaySound(8959, "Master") -- RAID_WARNING
            if DoF.Dialogs and DoF.Dialogs.ShowCriticalWoundMasterDialog then
                DoF.Dialogs:ShowCriticalWoundMasterDialog(args)
            elseif DoF.UI and DoF.UI.ShowCriticalWoundAlert then
                DoF.UI:ShowCriticalWoundAlert(args)
            end
        end
    end,

    -- Мастер запросил бросок на выживание у конкретного игрока.
    -- args = "targetName;stat;dc"
    SURVIVAL_ROLL_REQUEST = function(self, args, sender)
        local target, stat, dc = strsplit(";", args)
        dc = tonumber(dc) or 14
        if target ~= UnitName("player") then return end -- не нам — игнор

        if DoF.Dialogs and DoF.Dialogs.ShowSurvivalRollPlayer then
            DoF.Dialogs:ShowSurvivalRollPlayer(target, stat, dc)
        end
    end,

    -- Игрок отправил результат броска на выживание — все выводят в боевой лог.
    -- args = "playerName;stat;dc;roll;mod;total;success"
    SURVIVAL_ROLL_RESULT = function(self, args, sender)
        local playerName, stat, dc, roll, mod, total, success = strsplit(";", args)
        if sender ~= playerName then return end -- анти-спуф

        dc = tonumber(dc) or 0
        roll = tonumber(roll) or 0
        mod = tonumber(mod) or 0
        total = tonumber(total) or 0
        local ok = (success == "1")

        local color = DoF.Config.StatColors[stat] or "FFFFFF"
        local statName = DoF.Config.StatNames[stat] or stat
        local modStr = (mod >= 0 and "+" or "") .. mod
        local resultColor = ok and "00FF00" or "FF3333"
        local resultText = ok and DoF.L["combat.sync.survival_success"] or DoF.L["combat.sync.survival_fail"]

        local line = string.format(
            DoF.L["combat.sync.survival_line"],
            playerName,
            DoF.Utils:Color(color, statName),
            DoF.Utils:Color("FFFF00", tostring(total)),
            roll, modStr, dc,
            DoF.Utils:Color(resultColor, resultText)
        )

        if DoF.CombatLog and DoF.CombatLog.Add then
            DoF.CombatLog:Add(line)
        end
        DoF.Utils:Info(line)

        if not ok then
            local deathLine = DoF.Utils:Color("FF0000", DoF.Locale:Format("combat.sync.death_line", playerName))
            if DoF.CombatLog and DoF.CombatLog.Add then
                DoF.CombatLog:Add(deathLine)
            end
            DoF.Utils:Info(deathLine)
            if DoF.Sync:IsMaster() then
                PlaySound(8959, "Master")
            end
        end
    end,
    
    RESETSTATS = function(self, args, sender)
        if args == UnitName("player") then
            DoF.Sync:ShowConfirmDialog(
                "RESETSTATS", sender, DoF.L["combat.sync.stats_reset_title"],
                DoF.Locale:Format("combat.sync.stats_reset_text", sender),
                function()
                    DoF.Stats:ResetStats()
                    DoF.Utils:Warn(DoF.Locale:Format("combat.sync.stats_reset_by", sender))
                end
            )
        end
    end,
    
    GIVESHIELD = function(self, args, sender)
        local target = args
        if target == UnitName("player") then
            DoF.Stats:ApplyShield()
            DoF.Utils:Info(DoF.L["combat.sync.shield_from_master"])
        end
    end,

    NPC_SHIELD = function(self, args, sender)
        -- Пропускаем свои сообщения (уже применено локально в Units:Damage)
        if sender == UnitName("player") then return end
        local guid, amount = args:match("^([^;]+);(%d+)$")
        if guid and amount then
            local data = DoF.Units:Get(guid)
            if data then
                data.shield = tonumber(amount) or 0
                data.hpVersion = (data.hpVersion or 0) + 1
                DoF.Events:Fire("UNIT_SHIELD_CHANGED", guid, data.shield)
            end
        end
    end,

    CONFIRM_RESPONSE = function(self, args, sender)
        local cmdType, result, targetMaster = args:match("([^;]+);([^;]+);([^;]+)")
        
        if not self:IsMaster() then return end
        if targetMaster ~= UnitName("player") then return end
        
        local cmdNames = {
            RESETSTATS = DoF.L["combat.sync.stats_reset_title"],
            SETSPEC = DoF.L["combat.sync.role_removal_title"],
        }
        local cmdName = cmdNames[cmdType] or cmdType
        
        if result == "ACCEPTED" then
            if DoF.Sync._showSystemMessages then
                DoF.Utils:Info(DoF.Locale:Format("combat.sync.confirmed", sender, cmdName))
            end
            if DoF.CombatLog then
                DoF.CombatLog:AddMasterLog(DoF.Locale:Format("combat.sync.confirmed_log", sender, cmdName), "confirm_accept")
            end
        elseif result == "DECLINED" then
            if DoF.Sync._showSystemMessages then
                DoF.Utils:Warn(DoF.Locale:Format("combat.sync.declined", sender, cmdName))
            end
            if DoF.CombatLog then
                DoF.CombatLog:AddMasterLog(DoF.Locale:Format("combat.sync.declined_log", sender, cmdName), "confirm_decline")
            end
        elseif result == "TIMEOUT" then
            if DoF.Sync._showSystemMessages then
                DoF.Utils:Warn(DoF.Locale:Format("combat.sync.no_answer", sender, cmdName))
            end
            if DoF.CombatLog then
                DoF.CombatLog:AddMasterLog(DoF.Locale:Format("combat.sync.no_answer_log", sender, cmdName), "confirm_timeout")
            end
        end
    end,
    
    -- ═══════════════════════════════════════════════════════════
    -- HEARTBEAT МАСТЕРА
    -- ═══════════════════════════════════════════════════════════

    HEARTBEAT = function(self, args, sender)
        -- Принимаем только от мастера
        if not self:HasMasterAuth(sender) then return end

        self._lastMasterHeartbeat = GetTime()

        -- Сравниваем хеш NPC-данных
        if not self:IsMaster() then
            local npcCount, hpSum = args:match("^(%d+);(%d+)$")
            npcCount, hpSum = tonumber(npcCount), tonumber(hpSum)
            if npcCount and hpSum then
                local localCount, localSum = 0, 0
                for _, data in pairs(DoF.db.global.unitData) do
                    localCount = localCount + 1
                    localSum = localSum + (data.hp or 0)
                end
                if localCount ~= npcCount or localSum ~= hpSum then
                    -- Рассинхрон — запрашиваем данные (throttle: не чаще 30 сек)
                    local now = GetTime()
                    if not self._lastDesyncRequest or (now - self._lastDesyncRequest) > 30 then
                        self._lastDesyncRequest = now
                        if self._showSystemMessages then
                            DoF.Utils:Warn(DoF.L["combat.sync.desync_resync"])
                        end
                        self:RequestFullData()
                    end
                end
            end
        end
    end,

    -- ═══════════════════════════════════════════════════════════
    -- ПОШАГОВАЯ СИСТЕМА
    -- ═══════════════════════════════════════════════════════════

    COMBAT_START = function(self, args, sender)
        if DoF.TurnSystem then
            DoF.TurnSystem:HandleCombatStart(args)
        end
    end,
    
    COMBAT_END = function(self, args, sender)
        if DoF.TurnSystem then
            DoF.TurnSystem:HandleCombatEnd()
        end
    end,

    COMBAT_STATE = function(self, args, sender)
        if DoF.TurnSystem then
            DoF.TurnSystem:HandleCombatState(args)
        end
    end,

    COMBAT_STATE_REQUEST = function(self, args, sender)
        if not self:IsMaster() then return end

        -- Очищаем залипшие состояния реджойнившегося игрока
        if DoF.Combat and DoF.Combat.PendingAttacks then
            DoF.Combat.PendingAttacks[sender] = nil
        end
        if DoF.TurnSystem and DoF.TurnSystem.mode == "free" and DoF.TurnSystem.actedThisRound then
            for _, p in ipairs(DoF.TurnSystem.participants) do
                if p.name == sender then
                    p.acted = false
                    DoF.TurnSystem.actedThisRound[p.guid] = nil
                    break
                end
            end
        end

        -- Всегда синхронизируем эффекты — реджойнившийся клиент мог сохранить устаревшее состояние.
        -- Если эффектов нет, BroadcastAllEffects просто ничего не отправляет.
        if DoF.Effects then
            DoF.Effects:BroadcastAllEffects()
        end
        -- Состояние боя — только если бой активен
        if DoF.TurnSystem and DoF.TurnSystem.phase ~= "idle" then
            self:SendCombatState(sender)
        end
    end,

    -- Мастер запрашивает полное восстановление у группы (краш-рекавери).
    -- Формат args: имя назначенного получателя. Отвечает ТОЛЬКО этот игрок —
    -- это защита от лавины ответов при рейде 40 человек (иначе канал забьётся
    -- 40 одновременными FULLDATA3+STATE+EFFECTS, и новый мастер не сможет
    -- разрулить конфликтующие версии). Если args пусто — принимаем как broadcast
    -- (обратная совместимость со старыми клиентами).
    -- Не-мастер отдаёт ВСЁ: NPC + состояние боя + эффекты.
    RECOVERY_REQUEST = function(self, args, sender)
        if self:IsMaster() then return end
        if not DoF.Sync:HasMasterAuth(sender) then return end
        -- Targeted recovery: отвечаем только если назначены или args пусто (legacy)
        if args and args ~= "" and args ~= UnitName("player") then return end
        -- NPC данные
        if DoF.Units and DoF.Units:Count() > 0 then
            DoF.Sync:BroadcastFullData(sender)
        end
        -- Состояние боя (если бой активен)
        if DoF.TurnSystem and DoF.TurnSystem.phase ~= "idle" then
            DoF.TurnSystem:SendCombatStateRecovery(sender)
        end
        -- Эффекты (через SAFE команду EFFECT_SYNC_RECOVERY → мастеру)
        if DoF.Effects then
            DoF.Effects:BroadcastEffectsForRecovery(sender)
        end
    end,

    -- Восстановление состояния боя (не-мастер → мастеру, после краша мастера)
    COMBAT_STATE_RECOVERY = function(self, args, sender)
        -- Принимаем только если мы мастер (это данные ДЛЯ нас)
        if not self:IsMaster() then return end
        if DoF.TurnSystem then
            DoF.TurnSystem:HandleCombatState(args)
        end
        -- Отмечаем успешный ответ на RECOVERY_REQUEST
        self:_MarkRecoveryReceived()
    end,

    PHASE_CHANGE = function(self, args, sender)
        if DoF.TurnSystem then
            DoF.TurnSystem:HandlePhaseChange(args)
        end
    end,
    
    ROUND_START = function(self, args, sender)
        if DoF.TurnSystem then
            DoF.TurnSystem:HandleRoundStart(args)
        end
    end,
    
    TURN_CHANGE = function(self, args, sender)
        if DoF.TurnSystem then
            DoF.TurnSystem:HandleTurnChange(args)
        end
    end,
    
    PLAYER_ACTED = function(self, args, sender)
        if DoF.TurnSystem then
            DoF.TurnSystem:HandlePlayerActed(args)
        end
    end,
    
    PARTICIPANT_ADD = function(self, args, sender)
        if DoF.TurnSystem then
            DoF.TurnSystem:HandleParticipantAdd(args)
        end
    end,
    
    PARTICIPANT_REMOVE = function(self, args, sender)
        if DoF.TurnSystem then
            DoF.TurnSystem:HandleParticipantRemove(args)
        end
    end,
    
    FREE_ACTION = function(self, args, sender)
        if DoF.TurnSystem then
            DoF.TurnSystem:HandleFreeAction(args)
        end
    end,
    
    PLAYER_SKIP = function(self, args, sender)
        if DoF.TurnSystem then
            DoF.TurnSystem:HandlePlayerSkip(args)
        end
    end,
    
    ACTION_DONE = function(self, args, sender)
        if DoF.TurnSystem then
            DoF.TurnSystem:HandleActionDone(args)
        end
    end,
    
    -- ═══════════════════════════════════════════════════════════
    -- ОСОБОЕ ДЕЙСТВИЕ
    -- ═══════════════════════════════════════════════════════════

    -- Мастер получает запрос от игрока
    SPECIALACTION_REQUEST = function(self, args, sender)
        if not DoF.Sync:IsMaster() then return end

        local playerName, description = args:match("([^;]+);(.+)")
        if playerName and description then
            DoF.Dialogs:ShowMasterSpecialActionApproval(playerName, description)
        end
    end,

    -- Игрок получает одобрение от мастера (или помощника с правами effects)
    SPECIALACTION_APPROVED = function(self, args, sender)
        local playerName, threshold, stat, rest = args:match("([^;]+);([^;]+);([^;]+);(.*)")
        if playerName == UnitName("player") then
            threshold = tonumber(threshold) or 14
            local description, energyFlag, energyAmountStr, actionType, actionParams, noRollFlag

            -- Новый формат: description;energyFlag;energyAmount;actionType;actionParams;noRollFlag
            description, energyFlag, energyAmountStr, actionType, actionParams, noRollFlag =
                rest:match("(.*);([01]);(%d+);([^;]+);([^;]*);([01])$")

            if not description then
                -- Формат без noRoll: description;energyFlag;energyAmount;actionType;actionParams
                description, energyFlag, energyAmountStr, actionType, actionParams =
                    rest:match("(.*);([01]);(%d+);([^;]+);([^;]*)$")
                noRollFlag = "0"
            end

            if not description then
                -- Старый формат: description;energyFlag;energyAmount
                description, energyFlag, energyAmountStr = rest:match("(.*);([01]);(%d+)$")
                actionType = "simple_roll"
                actionParams = ""
                noRollFlag = "0"
            end
            if not description then
                -- Фолбэк для старого формата (description;energyFlag)
                description, energyFlag = rest:match("(.*);([01])$")
                energyAmountStr = "1"
                actionType = "simple_roll"
                actionParams = ""
                noRollFlag = "0"
            end
            if not description then
                description = rest
                energyFlag = "1"
                energyAmountStr = "1"
                actionType = "simple_roll"
                actionParams = ""
                noRollFlag = "0"
            end
            local requireEnergy = (energyFlag == "1")
            local energyAmount = tonumber(energyAmountStr) or 1
            local noRoll = (noRollFlag == "1")
            actionType = actionType or "simple_roll"
            actionParams = actionParams or ""
            -- Очищаем PendingSpecialAction
            DoF.Combat.PendingSpecialAction = nil
            -- Показываем диалог броска
            DoF.Dialogs:ShowSpecialActionRollDialog(threshold, stat, description, requireEnergy, energyAmount, actionType, actionParams, noRoll)
        end
    end,

    -- Игрок получает отклонение от мастера (или помощника с правами effects)
    SPECIALACTION_REJECTED = function(self, args, sender)
        local playerName = args
        if playerName == UnitName("player") then
            -- Очищаем PendingSpecialAction
            DoF.Combat.PendingSpecialAction = nil
            -- Записываем текущий раунд для блокировки повторных попыток
            local currentRound = DoF.TurnSystem and DoF.TurnSystem.round or 0
            DoF.Combat.RejectedSpecialActions[playerName] = currentRound

            DoF.Utils:Warn(DoF.L["combat.sync.special_rejected_by_master"])
            PlaySound(8960, "SFX")
        end
    end,
    
    -- ═══════════════════════════════════════════════════════════
    -- ЭНЕРГИЯ
    -- ═══════════════════════════════════════════════════════════
    
    GIVEENERGY = function(self, args, sender)
        local target, amount = args:match("([^;]+);([^;]+)")
        if target == UnitName("player") then
            DoF.Stats:AddEnergy(tonumber(amount) or 0)
            DoF.Utils:Info(DoF.Locale:Format("combat.sync.energy_received", DoF.Utils:Color("9966FF", DoF.Locale:Format("combat.sync.energy_amount", amount)), sender))
        end
    end,

    TAKEENERGY = function(self, args, sender)
        local target, amount = args:match("([^;]+);([^;]+)")
        if target == UnitName("player") then
            DoF.Stats:SpendEnergy(tonumber(amount) or 0)
            DoF.Utils:Warn(DoF.Locale:Format("combat.sync.energy_removed_by_master", DoF.Utils:Color("9966FF", DoF.Locale:Format("combat.sync.energy_amount", amount))))
        end
    end,
    
    RESTOREENERGY = function(self, args, sender)
        local targetName = args
        if targetName == UnitName("player") then
            DoF.Stats:RestoreEnergy()
        end
    end,

    HEALER_RESTORE_ENERGY = function(self, args, sender)
        local target, amount = args:match("([^;]+);([^;]+)")
        if target == UnitName("player") then
            DoF.Stats:AddEnergy(tonumber(amount) or 0)
            DoF.Utils:Info(DoF.Locale:Format("combat.sync.energy_from_healer", DoF.Utils:Color("9966FF", DoF.Locale:Format("combat.sync.energy_amount", amount)), DoF.Utils:Color("FFFFFF", sender)))
        end
    end,

    -- ═══════════════════════════════════════════════════════════
    -- ЭФФЕКТЫ (БАФФЫ/ДЕБАФФЫ/DoT)
    -- ═══════════════════════════════════════════════════════════
    
    EFFECT_APPLY = function(self, args, sender)
        -- Игнорируем свои собственные сообщения (мы уже применили эффект локально)
        if sender == UnitName("player") then
            return
        end

        local targetType, targetId, effectId, value, duration, caster =
            args:match("([^;]+);([^;]+);([^;]+);([^;]+);([^;]+);([^;]+)")

        if targetType and effectId and DoF.Effects then
            -- Применяем эффект локально без повторной синхронизации
            local storage = targetType == "npc" and DoF.Effects.NPCEffects or DoF.Effects.PlayerEffects
            if not storage[targetId] then
                storage[targetId] = {}
            end

            -- Проверяем, есть ли уже такой эффект (стакинг)
            if storage[targetId][effectId] then
                local existing = storage[targetId][effectId]
                local def = DoF.Effects.Definitions[effectId]
                -- Добавляем кастера если его нет
                if existing.casters then
                    local found = false
                    for _, c in ipairs(existing.casters) do
                        if c == caster then found = true break end
                    end
                    if not found then
                        table.insert(existing.casters, caster)
                        existing.stacks = (existing.stacks or 1) + 1
                        existing.value = (existing.value or 0) + tonumber(value)
                    else
                        -- Кастер уже есть — обновляем значение (замена через ApplyInternal)
                        local numValue = tonumber(value)
                        existing.value = numValue
                        if def and def.useValueAsStacks then
                            existing.stacks = numValue or 1
                            existing.remainingRounds = 0
                        end
                    end
                end
            else
                -- Новый эффект
                local def = DoF.Effects.Definitions[effectId]
                local numValue = tonumber(value)
                local numDuration = tonumber(duration)
                local effectStacks = 1
                local effectRemaining = numDuration

                -- useValueAsStacks: стаки = value, без длительности
                if def and def.useValueAsStacks then
                    effectStacks = numValue or 1
                    effectRemaining = 0
                end

                storage[targetId][effectId] = {
                    id = effectId,
                    value = numValue,
                    duration = numDuration,
                    remainingRounds = effectRemaining,
                    casters = { caster },
                    stacks = effectStacks,
                    appliedAt = GetTime(),
                }
            end

            DoF.Events:Fire("EFFECT_APPLIED", targetType, targetId, effectId)

            -- HP бафф: если цель — локальный игрок, увеличиваем currentHP
            if targetType == "player" and targetId == UnitName("player") then
                local def = DoF.Effects.Definitions[effectId]
                if def and def.isHPBuff then
                    DoF.Effects:ApplyHPBuff(tonumber(value))
                end
            end
        end
    end,

    TANK_SHRED_APPLY = function(self, args, sender)
        if sender == UnitName("player") then return end

        local npcGuid, effectId, value, stacks, caster =
            args:match("([^;]+);([^;]+);([^;]+);([^;]+);([^;]+)")

        if not npcGuid or not effectId or not DoF.Effects then return end

        local numValue = tonumber(value)
        local numStacks = tonumber(stacks)
        local cfg = DoF.Config
        -- Защита от некорректных данных
        numStacks = math.min(numStacks, cfg.TANK_SHRED_MAX_STACKS)
        numValue = math.min(numValue, cfg.TANK_SHRED_MAX_STACKS * cfg.TANK_SHRED_PER_STACK)

        local storage = DoF.Effects.NPCEffects
        if not storage[npcGuid] then storage[npcGuid] = {} end

        local existing = storage[npcGuid][effectId]
        if existing then
            existing.value = numValue
            existing.stacks = numStacks
            existing.remainingRounds = 3
            existing.duration = 3
            existing.appliedAt = GetTime()
            local found = false
            for _, c in ipairs(existing.casters) do
                if c == caster then found = true; break end
            end
            if not found then
                table.insert(existing.casters, caster)
            end
        else
            storage[npcGuid][effectId] = {
                id = effectId,
                value = numValue,
                stacks = numStacks,
                duration = 3,
                remainingRounds = 3,
                casters = { caster },
                appliedAt = GetTime(),
            }
        end

        DoF.Events:Fire("EFFECT_APPLIED", "npc", npcGuid, effectId)
    end,

    EFFECT_REMOVE = function(self, args, sender)
        local targetType, targetId, effectId = args:match("([^;]+);([^;]+);([^;]+)")
        
        if targetType and effectId and DoF.Effects then
            local storage = targetType == "npc" and DoF.Effects.NPCEffects or DoF.Effects.PlayerEffects
            if storage[targetId] then
                storage[targetId][effectId] = nil
                if next(storage[targetId]) == nil then
                    storage[targetId] = nil
                end
            end
            
            DoF.Events:Fire("EFFECT_REMOVED", targetType, targetId, effectId)

            -- HP бафф снят: пересчитываем HP локального игрока
            if targetType == "player" and targetId == UnitName("player") then
                local def = DoF.Effects.Definitions[effectId]
                if def and def.isHPBuff then
                    DoF.Effects:RemoveHPBuff()
                end
            end
        end
    end,

    EFFECT_TICK = function(self, args, sender)
        -- Обработка тика эффекта (урон/лечение)
        local targetType, targetId = args:match("([^;]+);([^;]+)")
        
        if DoF.Effects then
            DoF.Effects:ProcessRound(targetType, targetId)
        end
    end,
    
    DEFENSE_DONE = function(self, args, sender)
        -- Игрок защитился, очищаем pending атаку
        local playerName = args
        if self:IsMaster() and DoF.Combat and DoF.Combat.PendingAttacks then
            DoF.Combat.PendingAttacks[playerName] = nil
        end
    end,
    
    EFFECTS_CLEAR_TARGET = function(self, args, sender)
        local targetType, targetId = args:match("([^;]+);([^;]+)")
        if targetType and targetId and DoF.Effects then
            local storage = targetType == "npc" and DoF.Effects.NPCEffects or DoF.Effects.PlayerEffects
            storage[targetId] = nil
            DoF.Events:Fire("EFFECTS_CLEARED", targetType, targetId)
        end
    end,
    
    EFFECT_SYNC = function(self, args, sender)
        -- Мастер не обрабатывает свои собственные синхронизации
        if self:IsMaster() then
            return
        end
        
        -- Синхронизация состояния эффекта от мастера
        local targetType, targetId, effectId, value, remaining, castersStr, pendingFlag, stacksStr =
            args:match("([^;]+);([^;]+);([^;]+);([^;]+);([^;]+);([^;]*);?([01]?);?(%d*)")
        local explicitStacks = tonumber(stacksStr)
        
        if targetType and effectId and DoF.Effects then
            local storage = targetType == "npc" and DoF.Effects.NPCEffects or DoF.Effects.PlayerEffects
            if not storage[targetId] then
                storage[targetId] = {}
            end
            
            -- Парсим кастеров
            local casters = {}
            if castersStr and castersStr ~= "" then
                for caster in castersStr:gmatch("[^,]+") do
                    table.insert(casters, caster)
                end
            end
            
            local isPending = (pendingFlag == "1")
            local def = DoF.Effects.Definitions[effectId]
            local numValue = tonumber(value)
            local numRemaining = tonumber(remaining)

            -- useValueAsStacks: стаки = value, без длительности
            local useValueStacks = def and def.useValueAsStacks

            -- Обновляем или создаём эффект
            if storage[targetId][effectId] then
                -- Обновляем существующий
                storage[targetId][effectId].value = numValue
                storage[targetId][effectId].pendingActivation = isPending
                if useValueStacks then
                    storage[targetId][effectId].stacks = numValue or 1
                    storage[targetId][effectId].remainingRounds = 0
                else
                    storage[targetId][effectId].remainingRounds = numRemaining
                    if #casters > 0 then
                        storage[targetId][effectId].casters = casters
                        storage[targetId][effectId].stacks = explicitStacks or (#casters > 0 and #casters or 1)
                    end
                end
            else
                -- Создаём новый
                local effectStacks = 1
                local effectRemaining = numRemaining
                if useValueStacks then
                    effectStacks = numValue or 1
                    effectRemaining = 0
                elseif explicitStacks then
                    effectStacks = explicitStacks
                elseif #casters > 0 then
                    effectStacks = #casters
                end

                storage[targetId][effectId] = {
                    id = effectId,
                    value = numValue,
                    duration = def and def.fixedDuration or numRemaining,
                    remainingRounds = effectRemaining,
                    casters = #casters > 0 and casters or { "Unknown" },
                    stacks = effectStacks,
                    appliedAt = GetTime(),
                    pendingActivation = isPending,
                }
            end

            -- Уведомляем все UI-компоненты через событие
            DoF.Events:Fire("EFFECTS_SYNCED")
        end
    end,

    -- Восстановление эффектов: не-мастер → мастеру (SAFE команда)
    EFFECT_SYNC_RECOVERY = function(self, args, sender)
        -- Только мастер принимает данные восстановления
        if not self:IsMaster() then return end

        local targetType, targetId, effectId, value, remaining, castersStr, pendingFlag, stacksStr =
            args:match("([^;]+);([^;]+);([^;]+);([^;]+);([^;]+);([^;]*);?([01]?);?(%d*)")
        local explicitStacks = tonumber(stacksStr)

        if targetType and effectId and DoF.Effects then
            local storage = targetType == "npc" and DoF.Effects.NPCEffects or DoF.Effects.PlayerEffects
            if not storage[targetId] then
                storage[targetId] = {}
            end

            local casters = {}
            if castersStr and castersStr ~= "" then
                for caster in castersStr:gmatch("[^,]+") do
                    table.insert(casters, caster)
                end
            end

            local isPending = (pendingFlag == "1")
            local def = DoF.Effects.Definitions[effectId]
            local numValue = tonumber(value)
            local numRemaining = tonumber(remaining)
            local useValueStacks = def and def.useValueAsStacks

            if storage[targetId][effectId] then
                storage[targetId][effectId].value = numValue
                storage[targetId][effectId].pendingActivation = isPending
                if useValueStacks then
                    storage[targetId][effectId].stacks = numValue or 1
                    storage[targetId][effectId].remainingRounds = 0
                else
                    storage[targetId][effectId].remainingRounds = numRemaining
                    if #casters > 0 then
                        storage[targetId][effectId].casters = casters
                        storage[targetId][effectId].stacks = explicitStacks or (#casters > 0 and #casters or 1)
                    end
                end
            else
                local effectStacks = 1
                local effectRemaining = numRemaining
                if useValueStacks then
                    effectStacks = numValue or 1
                    effectRemaining = 0
                elseif explicitStacks then
                    effectStacks = explicitStacks
                elseif #casters > 0 then
                    effectStacks = #casters
                end

                storage[targetId][effectId] = {
                    id = effectId,
                    value = numValue,
                    duration = def and def.fixedDuration or numRemaining,
                    remainingRounds = effectRemaining,
                    casters = #casters > 0 and casters or { "Unknown" },
                    stacks = effectStacks,
                    appliedAt = GetTime(),
                    pendingActivation = isPending,
                }
            end

            DoF.Events:Fire("EFFECTS_SYNCED")
            -- Отмечаем успешный ответ на RECOVERY_REQUEST
            self:_MarkRecoveryReceived()
        end
    end,

    EFFECT_STACK = function(self, args, sender)
        -- Игнорируем свои собственные сообщения
        if sender == UnitName("player") then
            return
        end

        -- Синхронизация стакнутого эффекта
        local targetType, targetId, effectId, value, remaining, stacks, castersStr =
            args:match("([^;]+);([^;]+);([^;]+);([^;]+);([^;]+);([^;]+);([^;]*)")

        if targetType and effectId and DoF.Effects then
            local storage = targetType == "npc" and DoF.Effects.NPCEffects or DoF.Effects.PlayerEffects
            if not storage[targetId] then
                storage[targetId] = {}
            end

            -- Парсим кастеров
            local casters = {}
            if castersStr and castersStr ~= "" then
                for caster in castersStr:gmatch("[^,]+") do
                    table.insert(casters, caster)
                end
            end

            local def = DoF.Effects.Definitions[effectId]

            -- Запоминаем старое значение для вычисления дельты HP
            local oldValue = 0
            if storage[targetId][effectId] then
                oldValue = storage[targetId][effectId].value or 0
            end

            storage[targetId][effectId] = {
                id = effectId,
                value = tonumber(value),
                duration = def and def.fixedDuration or tonumber(remaining),
                remainingRounds = tonumber(remaining),
                casters = casters,
                stacks = tonumber(stacks),
                appliedAt = GetTime(),
            }

            -- HP бафф: увеличиваем HP локального игрока на дельту стака
            if targetType == "player" and targetId == UnitName("player") then
                if def and def.isHPBuff then
                    local delta = (tonumber(value) or 0) - oldValue
                    if delta > 0 then
                        DoF.Effects:ApplyHPBuff(delta)
                    end
                end
            end

            DoF.Events:Fire("EFFECT_APPLIED", targetType, targetId, effectId)
        end
    end,

}
