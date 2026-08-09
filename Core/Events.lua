-- DoF/Core/Events.lua
-- Внутренняя event-система для развязки модулей

local ADDON_NAME, DoF = ...

-- Кэширование глобальных функций
local pairs = pairs
local ipairs = ipairs
local pcall = pcall
local tostring = tostring
local table_insert = table.insert
local table_remove = table.remove

DoF.Events = {
    -- Зарегистрированные обработчики { eventName = { handler1, handler2, ... } }
    handlers = {},
}

-- ═══════════════════════════════════════════════════════════
-- РЕГИСТРАЦИЯ И ОТПИСКА
-- ═══════════════════════════════════════════════════════════

-- Подписаться на событие
-- @param eventName string - название события
-- @param handler function - обработчик (получает все аргументы события)
-- @param owner table|nil - владелец (для групповой отписки)
-- @return number - ID подписки для отписки
function DoF.Events:Register(eventName, handler, owner)
    if not self.handlers[eventName] then
        self.handlers[eventName] = {}
    end
    
    local entry = {
        handler = handler,
        owner = owner,
        id = self:GenerateID(),
    }
    
    table_insert(self.handlers[eventName], entry)
    return entry.id
end

-- Отписаться по ID
function DoF.Events:Unregister(eventName, handlerID)
    local handlers = self.handlers[eventName]
    if not handlers then return end
    
    for i = #handlers, 1, -1 do
        if handlers[i].id == handlerID then
            table_remove(handlers, i)
            return true
        end
    end
    return false
end

-- Отписать все обработчики владельца
function DoF.Events:UnregisterAll(owner)
    for eventName, handlers in pairs(self.handlers) do
        for i = #handlers, 1, -1 do
            if handlers[i].owner == owner then
                table_remove(handlers, i)
            end
        end
    end
end

-- ═══════════════════════════════════════════════════════════
-- ОТПРАВКА СОБЫТИЙ
-- ═══════════════════════════════════════════════════════════

-- Немедленная отправка события
function DoF.Events:Fire(eventName, ...)
    local handlers = self.handlers[eventName]
    if not handlers then return end
    
    for _, entry in ipairs(handlers) do
        -- Безопасный вызов
        local ok, err = pcall(entry.handler, ...)
        if not ok then
            DoF.Utils:Error("Event error [" .. eventName .. "]: " .. tostring(err))
        end
    end
end

-- ═══════════════════════════════════════════════════════════
-- УТИЛИТЫ
-- ═══════════════════════════════════════════════════════════

local nextID = 0
function DoF.Events:GenerateID()
    nextID = nextID + 1
    return nextID
end

-- ═══════════════════════════════════════════════════════════
-- СПИСОК ФАКТИЧЕСКИ ИСПОЛЬЗУЕМЫХ СОБЫТИЙ
-- ═══════════════════════════════════════════════════════════
--[[
Игрок:
    PLAYER_HP_CHANGED       (currentHP, maxHP)
    PLAYER_ENERGY_CHANGED   (energy)
    PLAYER_SHIELD_CHANGED   (shield)
    PLAYER_WOUND_CHANGED    (wounds)
    PLAYER_STATS_CHANGED    ()
    PLAYER_LEVEL_CHANGED    (newLevel, oldLevel)
    PLAYER_SPEC_CHANGED     (newSpec, oldSpec)
    PLAYER_DIED             ()
    PLAYER_DATA_RECEIVED    (playerName, data)

NPC:
    UNIT_HP_CHANGED         (guid, currentHP, maxHP)
    UNIT_SHIELD_CHANGED     (guid, shield)
    UNIT_CREATED            (guid, data)
    UNIT_DIED               (guid, name)
    UNIT_REMOVED            (guid)
    UNITS_CLEARED           ()
    UNITS_IMPORTED          ()

Эффекты:
    EFFECT_APPLIED          (targetId, effectId, data)
    EFFECT_REMOVED          (targetId, effectId)
    EFFECTS_CLEARED         (targetId)
    EFFECTS_SYNCED          ()

Бой:
    COMBAT_STARTED          (queue)
    COMBAT_ENDED            ()
    TURN_CHANGED            (playerName, isMyTurn)

Система:
    MASTER_CHANGED          (masterName)
    NPC_LIBRARY_CHANGED     ()
    NPC_TEMPLATE_APPLIED    (templateId)
]]
