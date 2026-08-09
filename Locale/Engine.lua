-- DoF/Locale/Engine.lua
-- Движок локализации: регистрация языков, доступ к строкам, fallback, множественные формы.
--
-- Файлы локалей лежат в Locale/<lang>/<Домен>.lua и вызывают DoF.Locale:Register().
-- Загружается ПЕРВЫМ среди файлов локали (см. DoF.toc).

local ADDON_NAME, DoF = ...

DoF.Locale = {
    -- data[lang][key] = "строка"
    data = {},

    -- Язык, используемый сейчас. Проставляется в DetectLanguage() ниже.
    current = "enUS",

    -- Язык, на который откатываемся при отсутствии ключа.
    fallback = "enUS",

    -- Языки, для которых есть файлы в Locale/. Порядок значения не имеет.
    supported = {
        enUS = true,
        ruRU = true,
    },

    -- Тот же набор, но упорядоченный: списки и переключатели в интерфейсе
    -- не должны менять порядок между открытиями, а pairs() его не гарантирует.
    order = { "ruRU", "enUS" },
}

-- ═══════════════════════════════════════════════════════════
-- ОПРЕДЕЛЕНИЕ ЯЗЫКА
-- ═══════════════════════════════════════════════════════════

-- Клиентские локали, которые мы считаем русскими.
local CLIENT_TO_LANG = {
    ruRU = "ruRU",
}

-- Язык берётся из настройки аддона, а не только из клиента: русский игрок на
-- английском клиенте должен получать русский аддон, и наоборот.
--
-- ВАЖНО ПРО ПОРЯДОК ЗАГРУЗКИ. SavedVariables (DoF_DB) становятся доступны
-- только к событию ADDON_LOADED — то есть ПОСЛЕ того, как все Lua-файлы аддона
-- уже выполнились. Поэтому первый вызов DetectLanguage() при загрузке Engine.lua
-- всегда видит DoF_DB == nil и откатывается на язык клиента, а сохранённый
-- выбор игрока применяется вторым вызовом — из DoF.Locale:Refresh()
-- в Core/Init.lua:OnInitialize. Всё, что «запекает» строки на этапе загрузки,
-- обязано уметь пересобраться: см. RegisterRelocalizer ниже.
function DoF.Locale:DetectLanguage()
    local override = DoF_DB and DoF_DB.settings and DoF_DB.settings.locale
    if override and self.supported[override] then
        self.current = override
        return self.current
    end

    local client = GetLocale and GetLocale() or "enUS"
    self.current = CLIENT_TO_LANG[client] or self.fallback
    return self.current
end

-- Смена языка требует /reload: часть строк уже отрисована во фреймах и в XML.
function DoF.Locale:SetLanguage(lang)
    if not self.supported[lang] then return false end
    if not DoF_DB then DoF_DB = {} end
    if not DoF_DB.settings then DoF_DB.settings = {} end
    DoF_DB.settings.locale = lang
    return true
end

DoF.Locale:DetectLanguage()

-- ═══════════════════════════════════════════════════════════
-- РЕГИСТРАЦИЯ СТРОК
-- ═══════════════════════════════════════════════════════════

-- Вызывается из каждого файла локали. Домены сливаются в одну плоскую таблицу
-- на язык — ключи уже несут префикс домена ("ui.", "combat.", ...), поэтому
-- коллизий между доменами быть не должно.
function DoF.Locale:Register(lang, strings)
    local target = self.data[lang]
    if not target then
        target = {}
        self.data[lang] = target
    end

    for key, value in pairs(strings) do
        target[key] = value
    end
end

-- ═══════════════════════════════════════════════════════════
-- ДОСТУП К СТРОКАМ
-- ═══════════════════════════════════════════════════════════

-- Текущий язык → fallback → сам ключ в скобках.
-- Ключ в скобках специально бросается в глаза: непереведённая строка должна
-- быть заметна при беглом взгляде на интерфейс, а не молча стать пустотой.
function DoF.Locale:Get(key)
    local current = self.data[self.current]
    if current then
        local value = current[key]
        if value then return value end
    end

    local fallback = self.data[self.fallback]
    if fallback then
        local value = fallback[key]
        if value then return value end
    end

    return "[" .. tostring(key) .. "]"
end

-- Есть ли ключ хоть в одном языке. Нужно там, где отсутствие ключа — это не
-- недоработка перевода, а сообщение от клиента более новой версии: журнал боя
-- принимает ключ по сети и должен уметь отличить «нет перевода» от «нет ключа».
function DoF.Locale:Has(key)
    local current = self.data[self.current]
    if current and current[key] then return true end
    local fallback = self.data[self.fallback]
    if fallback and fallback[key] then return true end
    return false
end

-- Основная точка входа: DoF.L["ui.npc_library"]
DoF.L = setmetatable({}, {
    __index = function(_, key)
        return DoF.Locale:Get(key)
    end,

    -- Локаль — данные, а не состояние: писать в неё из кода незачем.
    __newindex = function()
        error("DoF.L is read-only, use DoF.Locale:Register()", 2)
    end,
})

-- Сахар для строк с подстановками: DoF.Locale:Format("combat.heal", a, b, c)
function DoF.Locale:Format(key, ...)
    return string.format(self:Get(key), ...)
end

-- ═══════════════════════════════════════════════════════════
-- МНОЖЕСТВЕННЫЕ ФОРМЫ
-- ═══════════════════════════════════════════════════════════

-- Русский требует три формы (1 раунд / 2 раунда / 5 раундов), английский — две.
-- Правило выбора формы принадлежит языку, поэтому живёт здесь, а не в вызывающем коде.
local PLURAL_RULES = {
    -- Возвращает индекс формы: 1 = one, 2 = few, 3 = many
    ruRU = function(n)
        n = math.abs(n) % 100
        local n10 = n % 10
        if n > 10 and n < 20 then return 3 end
        if n10 == 1 then return 1 end
        if n10 >= 2 and n10 <= 4 then return 2 end
        return 3
    end,

    -- 1 = one, всё остальное = other (передаётся вторым аргументом)
    enUS = function(n)
        return (math.abs(n) == 1) and 1 or 2
    end,
}

-- DoF.Locale:Plural(n, "раунд", "раунда", "раундов") -> "раунда"
-- DoF.Locale:Plural(n, "round", "rounds")            -> "rounds"
function DoF.Locale:Plural(n, ...)
    local rule = PLURAL_RULES[self.current] or PLURAL_RULES.enUS
    local forms = { ... }
    local index = rule(n)
    -- Если язык требует форму, которую вызывающий не передал, берём последнюю:
    -- английские строки с двумя формами так корректно работают под русским правилом.
    return forms[index] or forms[#forms] or ""
end

-- ═══════════════════════════════════════════════════════════
-- ПОВТОРНОЕ ПРИМЕНЕНИЕ ЯЗЫКА
-- ═══════════════════════════════════════════════════════════

-- Модули, которые собирают строки в таблицы на этапе загрузки файла
-- (определения эффектов, роли, панель действий, глобалы для XML), регистрируют
-- здесь функцию пересборки. Она вызывается, когда язык оказался не тем, что был
-- при загрузке — а это норма, а не исключение: сохранённый выбор читается
-- только на ADDON_LOADED.
DoF.Locale.relocalizers = {}

function DoF.Locale:RegisterRelocalizer(fn)
    self.relocalizers[#self.relocalizers + 1] = fn
end

-- Перечитывает настройку и, если язык сменился, пересобирает всё запечённое.
-- Вызывается из Core/Init.lua:OnInitialize — первым делом, до создания UI.
function DoF.Locale:Refresh()
    local before = self.current
    self:DetectLanguage()
    if self.current == before then return false end

    for _, fn in ipairs(self.relocalizers) do
        -- Ошибка в одном модуле не должна оставить остальные на старом языке.
        local ok, err = pcall(fn)
        if not ok then
            print("|cFFFF3333[DoF]|r relocalize: " .. tostring(err))
        end
    end
    return true
end

-- Сохранённый выбор языка (может отличаться от активного: между сменой и
-- /reload аддон ещё говорит на старом, а в базе уже записан новый).
function DoF.Locale:GetSaved()
    local saved = DoF_DB and DoF_DB.settings and DoF_DB.settings.locale
    if saved and self.supported[saved] then return saved end
    return self.current
end

-- Следующий язык по кругу — для переключателя одной кнопкой.
function DoF.Locale:GetNext()
    local saved = self:GetSaved()
    for i, lang in ipairs(self.order) do
        if lang == saved then
            return self.order[i % #self.order + 1]
        end
    end
    return self.order[1]
end

-- Строка на конкретном языке, в обход текущего выбора.
-- Нужна ровно в одном месте — в подтверждении смены языка: пользователь только
-- что выбрал новый язык, и спрашивать его о перезагрузке логично уже на нём,
-- хотя DoF.L до /reload продолжает отдавать старый.
function DoF.Locale:GetIn(lang, key)
    local data = self.data[lang]
    return (data and data[key]) or self:Get(key)
end

-- Есть ли ключ хотя бы в одном языке. Нужно там, где ключ собирается динамически
-- ("ui.buff." .. id .. ".name") и может не существовать для части id.
function DoF.Locale:Has(key)
    local current = self.data[self.current]
    if current and current[key] then return true end
    local fallback = self.data[self.fallback]
    return (fallback and fallback[key]) ~= nil
end

-- Раунд — базовая единица боя, склоняется в подсказках десятки раз.
-- Отдельный хелпер, чтобы не тащить три ключа в каждый вызов.
function DoF.Locale:Rounds(n)
    return self:Plural(n, self:Get("ui.rounds_one"), self:Get("ui.rounds_few"), self:Get("ui.rounds_many"))
end

-- ═══════════════════════════════════════════════════════════
-- ДИАГНОСТИКА
-- ═══════════════════════════════════════════════════════════

-- Ключи, которые есть в fallback, но отсутствуют в указанном языке.
-- Используется валидатором полноты перевода (Tools/check_locale.ps1).
function DoF.Locale:GetMissingKeys(lang)
    local base = self.data[self.fallback] or {}
    local target = self.data[lang] or {}
    local missing = {}

    for key in pairs(base) do
        if not target[key] then
            missing[#missing + 1] = key
        end
    end

    table.sort(missing)
    return missing
end
