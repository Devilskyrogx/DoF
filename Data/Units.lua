-- DoF/Data/Units.lua
-- Управление данными NPC (HP, защиты)

local ADDON_NAME, DoF = ...

-- Кэширование глобальных функций
local pairs = pairs
local ipairs = ipairs
local tonumber = tonumber
local tostring = tostring
local string_format = string.format
local math_max = math.max
local math_min = math.min
local table_insert = table.insert
local UnitName = UnitName
local IsInGroup = IsInGroup

DoF.Units = {}

-- Экранирование `;` в именах NPC для безопасной передачи через протокол с разделителем `;`
local function EscapeName(name)
    if not name then return "Unknown" end
    return name:gsub("\\", "\\\\"):gsub(";", "\\s")
end

local function UnescapeName(name)
    if not name then return "Unknown" end
    return name:gsub("\\s", ";"):gsub("\\\\", "\\")
end

-- Публичный доступ для Sync/Core.lua и Sync/Handlers.lua
DoF.Units.EscapeName = EscapeName
DoF.Units.UnescapeName = UnescapeName

-- ═══════════════════════════════════════════════════════════
-- ИНИЦИАЛИЗАЦИЯ
-- ═══════════════════════════════════════════════════════════

function DoF.Units:Init()
    -- Данные уже в DoF.db.global.unitData
end

-- ═══════════════════════════════════════════════════════════
-- ГЕТТЕРЫ
-- ═══════════════════════════════════════════════════════════

function DoF.Units:Get(guid)
    return DoF.db.global.unitData[guid]
end

function DoF.Units:GetAll()
    return DoF.db.global.unitData
end

-- ═══════════════════════════════════════════════════════════
-- СЕТТЕРЫ
-- ═══════════════════════════════════════════════════════════

function DoF.Units:Set(guid, name, hp, maxHp, fort, reflex, will)
    if not DoF.Utils:RequireMaster(false) then return false end

    -- Запрещаем символы-разделители протокола в имени НПЦ
    if name and (name:find(";") or name:find(":")) then
        DoF.Utils:Error(DoF.L["errors.npc_name_invalid"])
        name = name:gsub("[;:]", "")
    end

    local isNew = not self:Get(guid)
    
    local existing = not isNew and self:Get(guid)
    local existingShield = existing and existing.shield or 0
    local existingVersion = existing and existing.hpVersion or 0
    local existingPassives = existing and existing.passives or nil
    local existingAdaptTracker = existing and existing.adaptTracker or nil

    DoF.db.global.unitData[guid] = {
        name = name or "Unknown",
        hp = hp,
        maxHp = maxHp or hp,
        fort = fort or 10,
        reflex = reflex or 10,
        will = will or 10,
        shield = existingShield,
        hpVersion = existingVersion + 1,
        hpVersionSource = UnitName("player"),
        passives = existingPassives,
        adaptTracker = existingAdaptTracker,
        lastSeenAt = GetServerTime(),
    }

    -- Событие
    if isNew then
        DoF.Events:Fire("UNIT_CREATED", guid, DoF.db.global.unitData[guid])
    else
        DoF.Events:Fire("UNIT_HP_CHANGED", guid, hp, maxHp)
    end
    
    -- Синхронизация
    if DoF.Sync then
        DoF.Sync:BroadcastUnit(guid, DoF.db.global.unitData[guid])
    end
    
    return true
end

function DoF.Units:SetHP(guid, name, hp, maxHp)
    local data = self:Get(guid)
    return self:Set(guid, name, hp, maxHp,
        data and data.fort or 10,
        data and data.reflex or 10,
        data and data.will or 10)
end

function DoF.Units:SetDefenses(guid, name, fort, reflex, will)
    local data = self:Get(guid)
    if data then
        return self:Set(guid, name, data.hp, data.maxHp, fort, reflex, will)
    else
        return self:Set(guid, name, 1, 1, fort, reflex, will)
    end
end

-- ═══════════════════════════════════════════════════════════
-- МОДИФИКАЦИЯ HP
-- ═══════════════════════════════════════════════════════════

function DoF.Units:ModifyHP(guid, newHP)
    local data = self:Get(guid)
    if not data then return false end

    local oldHP = data.hp
    local wasDead = data.hp <= 0
    data.hp = DoF.Utils:Clamp(newHP, 0, data.maxHp)
    data.hpVersion = (data.hpVersion or 0) + 1
    -- Локальный апдейт → источник = мы, для split-brain tie-break
    data.hpVersionSource = UnitName("player")
    -- Активный юнит — освежаем lastSeenAt, чтобы TTL-прунинг через 7 дней
    -- не удалил его при следующем /reload, если шаблон давно не переприменяли.
    if GetServerTime and GetServerTime() > 0 then
        data.lastSeenAt = GetServerTime()
    end
    local delta = data.hp - oldHP

    -- Событие
    DoF.Events:Fire("UNIT_HP_CHANGED", guid, data.hp, data.maxHp)

    -- Проверка смерти NPC
    if data.hp <= 0 and not wasDead then
        DoF.Events:Fire("UNIT_DIED", guid, data.name)
    end

    -- Синхронизация (с delta для обработки конкурентных атак)
    if DoF.Sync then
        DoF.Sync:Send("HPCHANGE", guid .. ";" .. data.hp .. ";" .. data.maxHp .. ";" .. (data.hpVersion or 0) .. ";" .. delta)
    end
    
    return true
end

function DoF.Units:Damage(guid, amount)
    local data = self:Get(guid)
    if not data then return false end
    -- Пассивка: Сопротивление — снижение входящего урона (минимум 1 проходит)
    if data.passives and data.passives.resistance then
        local reduction = data.passives.resistance.value or 0
        if reduction > 0 then
            amount = math_max(1, amount - reduction)
        end
    end

    -- Бинарный щит: поглощает ВЕСЬ урон от 1 удара
    if data.shield and data.shield > 0 then
        data.shield = 0
        data.hpVersion = (data.hpVersion or 0) + 1
        data.hpVersionSource = UnitName("player")
        if GetServerTime and GetServerTime() > 0 then
            data.lastSeenAt = GetServerTime()
        end
        DoF.Events:Fire("UNIT_SHIELD_CHANGED", guid, 0)
        if DoF.Sync and IsInGroup() then
            DoF.Sync:Send("NPC_SHIELD", guid .. ";" .. 0)
        end
        -- Дебафф: нельзя наложить щит 3 хода
        if DoF.Effects then
            DoF.Effects:ApplyInternal("npc", guid, "shield_exhaustion", 0, 3)
        end
        return true -- Весь урон поглощён
    end
    return self:ModifyHP(guid, data.hp - amount)
end

function DoF.Units:GetShield(guid)
    local data = self:Get(guid)
    return data and data.shield or 0
end

function DoF.Units:HasShield(guid)
    return self:GetShield(guid) > 0
end

function DoF.Units:ApplyShield(guid)
    local data = self:Get(guid)
    if not data then return false end
    if data.shield and data.shield > 0 then return false end -- Уже есть щит
    -- Проверка дебаффа истощения
    if DoF.Effects and DoF.Effects:HasEffect("npc", guid, "shield_exhaustion") then
        return false
    end
    data.shield = 1
    data.hpVersion = (data.hpVersion or 0) + 1
    data.hpVersionSource = UnitName("player")
    if GetServerTime and GetServerTime() > 0 then
        data.lastSeenAt = GetServerTime()
    end
    DoF.Events:Fire("UNIT_SHIELD_CHANGED", guid, 1)
    if DoF.Sync and IsInGroup() then
        DoF.Sync:Send("NPC_SHIELD", guid .. ";" .. 1)
    end
    return true
end

function DoF.Units:RemoveShield(guid)
    local data = self:Get(guid)
    if not data then return end
    data.shield = 0
    data.hpVersion = (data.hpVersion or 0) + 1
    data.hpVersionSource = UnitName("player")
    if GetServerTime and GetServerTime() > 0 then
        data.lastSeenAt = GetServerTime()
    end
    DoF.Events:Fire("UNIT_SHIELD_CHANGED", guid, 0)
end

function DoF.Units:Heal(guid, amount)
    local data = self:Get(guid)
    if not data then return false end
    return self:ModifyHP(guid, data.hp + amount)
end

-- ═══════════════════════════════════════════════════════════
-- УДАЛЕНИЕ
-- ═══════════════════════════════════════════════════════════

function DoF.Units:Remove(guid)
    if not DoF.Utils:RequireMaster(false) then return false end
    
    local data = self:Get(guid)
    local name = data and data.name or "Unknown"
    
    DoF.db.global.unitData[guid] = nil
    
    -- Синхронизация
    if DoF.Sync then
        DoF.Sync:Send("REMOVE", guid)
    end
    
    -- Лог мастера
    if DoF.CombatLog then
        DoF.CombatLog:AddMasterLog(DoF.Locale:Format("core.units.removed_log", name), "master_action")
    end
    
    DoF.Events:Fire("UNIT_REMOVED", guid)
    
    return true
end

function DoF.Units:Clear()
    if not DoF.Utils:RequireMaster(false) then return false end
    
    DoF.db.global.unitData = {}
    
    -- Синхронизация
    if DoF.Sync then
        DoF.Sync:Send("CLEAR")
    end
    
    -- Лог мастера
    if DoF.CombatLog then
        DoF.CombatLog:AddMasterLog(DoF.L["core.units.cleared_log"], "master_action")
    end
    
    DoF.Events:Fire("UNITS_CLEARED")
    
    DoF.Utils:Warn(DoF.L["core.units.cleared"])
    
    return true
end

function DoF.Units:ClearAllConfirm()
    if not DoF.Utils:RequireMaster(false) then return end
    
    StaticPopupDialogs["DoF_CLEAR_ALL_NPC"] = {
        text = DoF.L["core.units.clear_confirm"],
        button1 = DoF.L["ui.common.yes"],
        button2 = DoF.L["ui.common.no"],
        OnAccept = function()
            DoF.Units:Clear()
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
    }
    StaticPopup_Show("DoF_CLEAR_ALL_NPC")
end

-- ═══════════════════════════════════════════════════════════
-- УТИЛИТЫ
-- ═══════════════════════════════════════════════════════════

function DoF.Units:PrintList()
    print("|cFF00FF00=== DoF NPC List ===|r")
    
    local count = 0
    for guid, data in pairs(DoF.db.global.unitData) do
        if data then
            local name = data.name or "Unknown"
            local status
            if data.hp <= 0 then
                status = DoF.L["core.units.dead"]
            else
                status = "|cFFFF0000" .. data.hp .. "/" .. data.maxHp .. "|r"
            end
            print("|cFFFFFFFF" .. name .. "|r: " .. status .. 
                DoF.Locale:Format("core.units.stat_line", data.fort, data.reflex, data.will))
            count = count + 1
        end
    end
    
    if count == 0 then
        DoF.Utils:Warn(DoF.L["core.units.list_empty"])
    end
end

function DoF.Units:Count()
    local count = 0
    for _ in pairs(DoF.db.global.unitData) do
        count = count + 1
    end
    return count
end

-- ═══════════════════════════════════════════════════════════
-- СЕРИАЛИЗАЦИЯ (для синхронизации)
-- ═══════════════════════════════════════════════════════════

-- FULLDATA3: используем AceSerializer для полного дампа NPC
-- AceSerializer автоматически обрабатывает все типы, вложенные таблицы, экранирование.
-- ВАЖНО: пропускаем _stub-записи (HPCHANGE-заглушки без реальных fort/reflex/will).
-- Иначе заглушка из одного клиента может через recovery попасть мастеру и
-- затереть валидные данные — а на других клиентах создать запись с нулевыми
-- защитами, что выглядит как «слетел шаблон».
function DoF.Units:Serialize()
    local clean = {}
    for guid, data in pairs(DoF.db.global.unitData) do
        if data and not data._stub then
            clean[guid] = data
        end
    end
    return DoF.Addon:Serialize(clean)
end

function DoF.Units:Deserialize(str)
    if not str or str == "" then return {} end
    local ok, data = DoF.Addon:Deserialize(str)
    if ok and type(data) == "table" then
        return data
    end
    return {}
end


-- opts.authoritative (default true) — удалять ли локальные записи, отсутствующие
-- в импорте. true корректно для FULLDATA от мастера (он источник правды).
-- false ОБЯЗАТЕЛЬНО для recovery от не-мастера к новому мастеру: иначе
-- «дыры» в копии не-мастера (например, HPCHANGE-stub'ы или потерянные UNIT)
-- удалят валидные юниты у нового мастера и раскатают потерю по всей группе.
-- opts.skipStubs (default true) — пропускать impotedUnit с _stub=true, чтобы
-- заглушки HPCHANGE без UNIT не затирали реальные данные у получателя.
function DoF.Units:ImportData(data, opts)
    opts = opts or {}
    local authoritative = opts.authoritative
    if authoritative == nil then authoritative = true end
    local skipStubs = opts.skipStubs
    if skipStubs == nil then skipStubs = true end

    -- Мерж вместо полной замены: сохраняем более свежие HP (по hpVersion)
    for guid, importedUnit in pairs(data) do
        if not (skipStubs and importedUnit._stub) then
            local existing = DoF.db.global.unitData[guid]
            if not existing or (importedUnit.hpVersion or 0) > (existing.hpVersion or 0) then
                DoF.db.global.unitData[guid] = importedUnit
            else
                -- HP и shield у клиента свежее — обновляем только параметры,
                -- но НЕ нулевые stat-ы (признак HPCHANGE-stub в импорте).
                existing.name = importedUnit.name
                if (importedUnit.fort or 0) > 0 then existing.fort = importedUnit.fort end
                if (importedUnit.reflex or 0) > 0 then existing.reflex = importedUnit.reflex end
                if (importedUnit.will or 0) > 0 then existing.will = importedUnit.will end
                if importedUnit.passives then
                    existing.passives = importedUnit.passives
                end
            end
        end
    end

    if authoritative then
        -- Удаляем записи, которых нет в импорте (удалённые НПЦ)
        -- Собираем ключи для удаления отдельно (нельзя менять таблицу во время pairs)
        local toRemove = {}
        for guid in pairs(DoF.db.global.unitData) do
            if not data[guid] then
                table_insert(toRemove, guid)
            end
        end
        for _, guid in ipairs(toRemove) do
            local removedName = DoF.db.global.unitData[guid] and DoF.db.global.unitData[guid].name
            DoF.db.global.unitData[guid] = nil
            -- Логируем удаление в боевой лог мастера: помогает диагностировать
            -- сценарий, когда юнит исчезает у всех после ImportData.
            if DoF.Sync and DoF.Sync:IsMaster() and DoF.CombatLog and removedName then
                DoF.CombatLog:AddMasterLog(
                    DoF.Locale:Format("core.units.import_removed", removedName),
                    "system"
                )
            end
        end
    end

    DoF.Events:Fire("UNITS_IMPORTED")
end

-- Алиасы для совместимости
function DoF:GetUnitData(guid)
    return DoF.Units:Get(guid)
end

function DoF:SetUnitHP(guid, name, hp, maxHp)
    return DoF.Units:SetHP(guid, name, hp, maxHp)
end

function DoF:SetUnitData(guid, name, hp, maxHp, fort, reflex, will)
    if hp == nil then
        return DoF.Units:Remove(guid)
    end
    return DoF.Units:Set(guid, name, hp, maxHp, fort, reflex, will)
end

function DoF:ModifyUnitHP(guid, newHP)
    return DoF.Units:ModifyHP(guid, newHP)
end
