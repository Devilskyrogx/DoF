-- DoF/Locale/Globals.lua
-- Мост между локалью и UI/Frames.xml.
--
-- Атрибут text="..." в XML нельзя вычислить в рантайме, но парсер WoW подставляет
-- значение глобальной переменной, если text= совпадает с её именем (так работают
-- стандартные OKAY, CANCEL и т.п.). Поэтому вместо text="Библиотека NPC" в разметке
-- пишется text="DoF_L_NPC_LIBRARY", а глобал объявляется здесь.
--
-- Глобалы генерируются автоматически из всех ключей локали с префиксом "xml.":
--   "xml.npc_library"  ->  _G["DoF_L_NPC_LIBRARY"]
-- Добавление новой надписи в XML = добавление ключа "xml.*" в Locale/<lang>/UI.lua,
-- править этот файл при этом не нужно.
--
-- ВАЖНО: загружается после всех файлов локали и ДО UI/Frames.xml (см. DoF.toc).

local ADDON_NAME, DoF = ...

local PREFIX = "xml."
local GLOBAL_PREFIX = "DoF_L_"

-- Собираем объединение ключей всех языков: если строка есть только в fallback,
-- глобал всё равно должен существовать, иначе XML покажет само имя переменной.
local xmlKeys = {}
for _, strings in pairs(DoF.Locale.data) do
    for key in pairs(strings) do
        if key:sub(1, #PREFIX) == PREFIX then
            xmlKeys[key] = GLOBAL_PREFIX .. key:sub(#PREFIX + 1):upper()
        end
    end
end

function DoF.Locale:ApplyXMLGlobals()
    for key, name in pairs(xmlKeys) do
        _G[name] = self:Get(key)
    end
end

DoF.Locale:ApplyXMLGlobals()

-- ═══════════════════════════════════════════════════════════
-- ПОВТОРНОЕ ПРИМЕНЕНИЕ К УЖЕ СОЗДАННЫМ ФРЕЙМАМ
-- ═══════════════════════════════════════════════════════════
--
-- Фреймы из Frames.xml создаются при загрузке XML, и text= в них подставляется
-- один раз — со значением глобала на тот момент. Сохранённый язык к этому
-- моменту ещё неизвестен (SavedVariables приходят позже), поэтому после смены
-- языка подписи нужно проставить заново.
--
-- Виджет находится по parentKey вида L_<ИМЯ_ГЛОБАЛА>: он проставлен в разметке
-- рядом с каждым text="DoF_L_...". Отдельной таблицы соответствий нет намеренно —
-- она разъезжалась бы с XML при первой же правке разметки.

-- Корневые фреймы Frames.xml (только те, что не virtual). Обход идёт вглубь
-- по детям, поэтому перечислять нужно лишь верхний уровень.
local ROOT_FRAMES = {
    "DoF_GMPanel",
    "DoF_NPCSetupDialog",
    "DoF_NPCAttackDialog",
    "DoF_ModifyNPCHPDialog",
    "DoF_ModifyPlayerHPDialog",
}

-- Пять подписей, у которых parentKey занят вёрсткой: на них ссылается
-- UI/MainFrame_GM.lua при расстановке элементов, и переименование сломало бы
-- раскладку. Единственное исключение из правила «parentKey = L_<ГЛОБАЛ>».
local EXCEPTIONS = {
    modeFreeLabel       = "DoF_L_FREE_QUEUE",
    modeQueueLabel      = "DoF_L_BY_INITIATIVE",
    useTimerLabel       = "DoF_L_USE_TIMER",
    instantDefenseLabel = "DoF_L_INSTANT_DEFENSE",
    utilitiesLabel      = "DoF_L_UTILITIES_CAPS",
}

local function ApplyToFrame(frame)
    if type(frame) ~= "table" then return end

    for key, widget in pairs(frame) do
        if type(key) == "string" and type(widget) == "table" and widget.SetText then
            local globalName
            if key:sub(1, 2) == "L_" then
                globalName = GLOBAL_PREFIX .. key:sub(3)
            else
                globalName = EXCEPTIONS[key]
            end

            local value = globalName and _G[globalName]
            if value then widget:SetText(value) end
        end
    end

    if frame.GetChildren then
        local children = { frame:GetChildren() }
        for i = 1, #children do
            ApplyToFrame(children[i])
        end
    end
end

DoF.Locale:RegisterRelocalizer(function()
    DoF.Locale:ApplyXMLGlobals()

    for _, name in ipairs(ROOT_FRAMES) do
        ApplyToFrame(_G[name])
    end
end)
