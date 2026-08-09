-- DoF/Core/Config.lua
-- Константы, справочники и настройки

local ADDON_NAME, DoF = ...

DoF.Config = {
    -- Версия и разработчик
    VERSION = "1.0",
    AUTHOR = "Skyrogx",
    -- Синхронизация
    ADDON_PREFIX = "DoF_SYNC",
    -- ═══════════════════════════════════════════════════════════
    -- СИСТЕМА УРОВНЕЙ (собственная, 1-20)
    -- ═══════════════════════════════════════════════════════════
    -- Уровень DoF не связан с игровым: сервер зафиксирован на 60, а прогрессия
    -- системы своя. Хранится в db.char.level, выдаётся мастером (/dofsetlevel).
    MIN_LEVEL = 1, MAX_LEVEL = 20,
    -- Лимиты характеристик
    MAX_STAT = 8,           -- Максимум при распределении
    MAX_STAT_TOTAL = 10,    -- Абсолютный потолок (с баффами)
    MAX_TOTAL_POINTS = 17,  -- 16 за уровни 2-17 + 1 за капстоун (20)
    -- Прочие лимиты
    MAX_WOUNDS = 2, COMBAT_LOG_MAX = 100, MASTER_LOG_MAX = 200,
    -- Шрифты подбираются в рантайме — см. блок в конце файла.
    FONT = nil,
    FONT_TITLE = nil,
    FONT_SIZES = { small = 10, normal = 12, large = 14, title = 16, floating = 18, floatingCrit = 24 },
    -- ═══════════════════════════════════════════════════════════
    -- ПРОГРЕССИЯ УРОВНЕЙ
    -- ═══════════════════════════════════════════════════════════
    --
    -- Единственная таблица баланса: индекс = уровень DoF, строка = всё, что
    -- этот уровень даёт. Плотный массив 1..MAX_LEVEL — дырок быть не должно,
    -- геттеры индексируют её напрямую.
    --
    --   points — сколько очков характеристик доступно ВСЕГО на этом уровне
    --            (накопительно, не приращение); потолок = MAX_TOTAL_POINTS
    --   hp     — базовое HP до бонусов роли, ран и баффов
    --   energy — максимум энергии
    --   tier   — строка в таблицах урона и исцеления (см. ниже)
    --
    -- Уровни 1-19 повторяют прежнюю шкалу 10-100 один в один: на ней было
    -- ровно 19 различимых состояний, остальные 72 игровых уровня не давали
    -- ничего. Уровень 20 — капстоун, добавленный при переезде на свою шкалу:
    -- даёт 17-е очко характеристик, единственное сверх прежнего баланса.
    -- Очки идут подряд с 2-го по 17-й уровень, дальше пауза на 18-19.
    Progression = {
        { points =  0, hp = 10, energy = 3, tier =  1 },  -- 1
        { points =  1, hp = 10, energy = 3, tier =  1 },  -- 2
        { points =  2, hp = 11, energy = 3, tier =  2 },  -- 3
        { points =  3, hp = 11, energy = 3, tier =  2 },  -- 4
        { points =  4, hp = 12, energy = 3, tier =  3 },  -- 5
        { points =  5, hp = 12, energy = 3, tier =  3 },  -- 6
        { points =  6, hp = 13, energy = 3, tier =  4 },  -- 7
        { points =  7, hp = 13, energy = 3, tier =  4 },  -- 8
        { points =  8, hp = 14, energy = 3, tier =  5 },  -- 9
        { points =  9, hp = 14, energy = 4, tier =  5 },  -- 10
        { points = 10, hp = 15, energy = 4, tier =  6 },  -- 11
        { points = 11, hp = 15, energy = 4, tier =  6 },  -- 12
        { points = 12, hp = 16, energy = 4, tier =  7 },  -- 13
        { points = 13, hp = 16, energy = 4, tier =  7 },  -- 14
        { points = 14, hp = 17, energy = 4, tier =  8 },  -- 15
        { points = 15, hp = 17, energy = 4, tier =  8 },  -- 16
        { points = 16, hp = 18, energy = 4, tier =  9 },  -- 17
        { points = 16, hp = 19, energy = 4, tier =  9 },  -- 18
        { points = 16, hp = 20, energy = 5, tier = 10 },  -- 19
        { points = 17, hp = 20, energy = 5, tier = 10 },  -- 20  ← капстоун: 17-е очко
    },
    -- Стоимость действий в энергии
    ENERGY_COST_AOE = 1, ENERGY_COST_AOE_BUFF = 2, ENERGY_COST_SPECIAL = 1,
    ENERGY_COST_TAUNT = 1, ENERGY_COST_TAUNT_AOE = 2,
    -- Восстановление энергии
    ENERGY_GAIN_SKIP_TURN = 1, ENERGY_GAIN_CRIT_CHOICE = 1,
    -- Крит бонус: min(range.max, CRIT_BONUS_CAP)
    CRIT_BONUS_CAP = 5,
    -- Усталость лечения: каждый N-й успешный хил добавляет стак (+2 к порогу, max стаков)
    HEALING_FATIGUE_EVERY_N = 3,
    HEALING_FATIGUE_THRESHOLD_PER_STACK = 2,
    HEALING_FATIGUE_MAX_STACKS = 7,
    -- ═══════════════════════════════════════════════════════════
    -- ОСОБОЕ ДЕЙСТВИЕ
    -- ═══════════════════════════════════════════════════════════
    SPECIAL_ACTION_THRESHOLD = 14, SPECIAL_ACTION_MAX_TEXT = 1000,
    -- Типы расширенных особых действий
    SpecialActionTypes = {
        simple_roll    = DoF.L["core.action.simple_roll"],
        buff           = DoF.L["core.action.buff"],
        aoe_buff       = DoF.L["core.action.aoe_buff"],
        attack         = DoF.L["core.action.attack"],
        aoe_attack     = DoF.L["core.action.aoe_attack"],
        wound_removal  = DoF.L["core.action.wound_removal"],
        dispel         = DoF.L["core.action.dispel"],
        purge          = DoF.L["core.action.purge"],
    },
    SpecialActionTypeOrder = {
        "simple_roll", "buff", "aoe_buff", "attack",
        "aoe_attack", "wound_removal", "dispel", "purge",
    },
    -- ═══════════════════════════════════════════════════════════
    -- AOE АТАКА
    -- ═══════════════════════════════════════════════════════════
    AOE_MIN_TARGETS = 2, AOE_MAX_TARGETS = 4,
    AOE_COOLDOWN_ROUNDS = 3,
    -- ═══════════════════════════════════════════════════════════
    -- БОНУСЫ ТАНКА
    -- ═══════════════════════════════════════════════════════════
    TANK_SHRED_PER_STACK = 2,       -- снижение защиты за стак
    TANK_SHRED_MAX_STACKS = 3,      -- макс стаков пробития (итого -6)
    TANK_SHRED_HITS_REQUIRED = 2,   -- подряд удачных атак для стака
    TANK_TAUNT_DURATION = 2,        -- длительность провокации (раунды)
    -- ═══════════════════════════════════════════════════════════
    -- РОЛИ (бывшие специализации)
    -- ═══════════════════════════════════════════════════════════
    Roles = {
        tank = { name = DoF.L["roles.tank.name"], color = "CC8040", description = DoF.L["roles.tank.desc"], icon = "Interface\\AddOns\\DoF\\texture\\roles\\tank" },
        dd = { name = DoF.L["roles.dd.name"], color = "FF6666", description = DoF.L["roles.dd.desc"], icon = "Interface\\AddOns\\DoF\\texture\\roles\\damage" },
        healer = { name = DoF.L["roles.healer.name"], color = "66FF66", description = DoF.L["roles.healer.desc"], icon = "Interface\\AddOns\\DoF\\texture\\roles\\heal" },
    },
    ROLE_REQUIRED_LEVEL = 1,
    -- ═══════════════════════════════════════════════════════════
    -- ТАБЛИЦЫ УРОНА (индекс = тир из Progression, 1..10)
    -- ═══════════════════════════════════════════════════════════
    -- Урон для ДД (повышенный)
    DamageDD = {
        {min=2,max=3}, {min=2,max=4}, {min=3,max=5}, {min=3,max=5}, {min=3,max=6},
        {min=4,max=7}, {min=4,max=7}, {min=5,max=8}, {min=5,max=10}, {min=5,max=10},
    },
    -- Урон для Танка и Целителя (ниже среднего)
    DamageReduced = {
        {min=1,max=1}, {min=1,max=2}, {min=1,max=2}, {min=1,max=3}, {min=1,max=3},
        {min=2,max=4}, {min=2,max=4}, {min=2,max=5}, {min=2,max=5}, {min=3,max=5},
    },
    -- ═══════════════════════════════════════════════════════════
    -- ТАБЛИЦЫ ИСЦЕЛЕНИЯ (индекс = тир из Progression, 1..10)
    -- ═══════════════════════════════════════════════════════════
    -- Исцеление для Хила (повышенное). Макс ≤ 50% HP, крит игнорирует кап
    HealingHealer = {
        {min=1,max=3}, {min=1,max=3}, {min=2,max=4}, {min=2,max=5}, {min=3,max=5},
        {min=3,max=6}, {min=4,max=7}, {min=4,max=7}, {min=5,max=10}, {min=5,max=10},
    },
    -- Исцеление для Танка и ДД (ниже среднего)
    HealingReduced = {
        {min=1,max=1}, {min=1,max=1}, {min=1,max=2}, {min=1,max=2}, {min=1,max=3},
        {min=1,max=3}, {min=2,max=3}, {min=2,max=4}, {min=2,max=4}, {min=2,max=5},
    },
    -- ═══════════════════════════════════════════════════════════
    -- ЩИТ (только Хил)
    -- ═══════════════════════════════════════════════════════════
    -- Бинарный щит: поглощает ВЕСЬ урон от 1 удара, затем спадает
    SHIELD_COOLDOWN_TURNS = 2,          -- кулдаун одиночного щита (ходы)
    SHIELD_AOE_COOLDOWN_TURNS = 3,      -- кулдаун AoE щита (ходы)
    ENERGY_COST_AOE_SHIELD = 2,         -- стоимость AoE щита
    SHIELD_AOE_MAX_TARGETS = 4,         -- макс целей AoE щита
    -- ═══════════════════════════════════════════════════════════
    -- РАНЕНИЯ
    -- ═══════════════════════════════════════════════════════════
    -- 1 рана = обычная (-3 ко всем статам, HP восстановлено до 25% нового maxHP)
    -- 2 рана = критическое ранение (игрок небоеспособен, HP=0, мастер решает вручную)
    WoundPenalties = { [0] = 0, [1] = -3, [2] = -3 },
    WoundHPRestore = { [1] = 0.25, [2] = 0 },
    -- ═══════════════════════════════════════════════════════════
    -- НАЗВАНИЯ И ЦВЕТА
    -- ═══════════════════════════════════════════════════════════
    StatNames = { Strength = DoF.L["stats.strength.label"], Dexterity = DoF.L["stats.dexterity.label"], Intelligence = DoF.L["stats.intelligence.label"], Spirit = DoF.L["stats.spirit.label"], Fortitude = DoF.L["stats.fortitude.label"], Reflex = DoF.L["stats.reflex.label"], Will = DoF.L["stats.will.label"] },
    StatShortNames = { Strength = "Str", Dexterity = "Dex", Intelligence = "Int", Spirit = "Spi", Fortitude = "Fort", Reflex = "Reflex", Will = "Will" },
    StatColors = { Strength = "FF6666", Dexterity = "66FF66", Intelligence = "66CCFF", Spirit = "FFE066", Fortitude = "CC8040", Reflex = "99CC66", Will = "B080FF" },
    StatIcons = {
        Strength = "Interface/Icons/ability_warrior_secondwind",
        Dexterity = "Interface/Icons/ability_rogue_quickrecovery",
        Intelligence = "Interface/Icons/spell_holy_arcaneintellect",
        Spirit = "Interface/Icons/spell_holy_divinespirit",
        Fortitude = "Interface/Icons/spell_holy_devotionaura",
        Reflex = "Interface/Icons/spell_holy_blessingofagility",
        Will = "Interface/Icons/spell_arcane_mindmastery",
    },
    AttackVsDefense = { Strength = "Fortitude", Dexterity = "Reflex", Intelligence = "Will" },
    AttackStats = { "Strength", "Dexterity", "Intelligence" },
    DefenseStats = { "Fortitude", "Reflex", "Will" },
    AllStats = { "Strength", "Dexterity", "Intelligence", "Spirit", "Fortitude", "Reflex", "Will" },
}

-- ═══════════════════════════════════════════════════════════
-- ХЕЛПЕРЫ ДЛЯ ПОЛУЧЕНИЯ ДАННЫХ
-- ═══════════════════════════════════════════════════════════

-- Уровень приходит из SavedVariables и по сети от мастера — оба источника
-- могут дать мусор (правка файла руками, битый пакет, старая версия аддона).
-- Progression индексируется напрямую, поэтому клампим в одной точке, а не в
-- каждом геттере: nil-строка уронила бы всё, что считает урон и HP.
function DoF.Config:GetLevelRow(level)
    level = tonumber(level) or self.MIN_LEVEL
    level = math.floor(level)
    if level < self.MIN_LEVEL then level = self.MIN_LEVEL end
    if level > self.MAX_LEVEL then level = self.MAX_LEVEL end
    return self.Progression[level]
end

function DoF.Config:GetPointsForLevel(level) return self:GetLevelRow(level).points end
function DoF.Config:GetBaseHPForLevel(level) return self:GetLevelRow(level).hp end
function DoF.Config:GetTierForLevel(level)   return self:GetLevelRow(level).tier end

function DoF.Config:GetMaxStat() return self.MAX_STAT end
function DoF.Config:GetMaxStatTotal() return self.MAX_STAT_TOTAL end

function DoF.Config:GetWoundPenalty(wounds) return self.WoundPenalties[wounds] or 0 end

function DoF.Config:GetDamageRange(level, role)
    local tbl
    if role == "dd" then tbl = self.DamageDD
    elseif role == "tank" or role == "healer" then tbl = self.DamageReduced
    end
    if not tbl then return { min = 1, max = 1 } end
    return tbl[self:GetTierForLevel(level)]
end

function DoF.Config:GetHealingRange(level, role)
    local tbl
    if role == "healer" then tbl = self.HealingHealer
    elseif role == "tank" or role == "dd" then tbl = self.HealingReduced
    end
    if not tbl then return { min = 1, max = 1 } end
    return tbl[self:GetTierForLevel(level)]
end


-- Приращение очков именно на этом уровне: Progression хранит накопительное
-- значение, а сообщение «получено N очков» нужно про разницу с предыдущим.
function DoF.Config:GetPointsAtLevel(level)
    level = tonumber(level) or self.MIN_LEVEL
    if level <= self.MIN_LEVEL then return 0 end
    return self:GetPointsForLevel(level) - self:GetPointsForLevel(level - 1)
end

-- Ближайший уровень выше текущего, на котором дадут очко. nil — очков больше
-- не будет. Раздача неравномерная (2-17 подряд, пауза на 18-19, последнее на
-- капстоуне 20), поэтому перебираем таблицу, а не считаем формулой.
function DoF.Config:GetNextPointLevel(level)
    for lvl = (tonumber(level) or self.MIN_LEVEL) + 1, self.MAX_LEVEL do
        if self:GetPointsAtLevel(lvl) > 0 then return lvl end
    end
    return nil
end

function DoF.Config:GetMaxEnergyForLevel(level) return self:GetLevelRow(level).energy end

function DoF.Config:GetHighestAttackStat(stats)
    local highest, highestValue = "Strength", stats.Strength or 0
    if (stats.Dexterity or 0) > highestValue then highest, highestValue = "Dexterity", stats.Dexterity end
    if (stats.Intelligence or 0) > highestValue then highest, highestValue = "Intelligence", stats.Intelligence end
    return highest, highestValue
end

-- ═══════════════════════════════════════════════════════════
-- ДЕФОЛТНЫЕ ЗНАЧЕНИЯ ДЛЯ AceDB
-- ═══════════════════════════════════════════════════════════

DoF.Defaults = {
    char = {
        -- Персональные данные персонажа (сохраняются отдельно для каждого персонажа)
        -- Уровень DoF свой, не игровой: стартуем с MIN_LEVEL, повышает мастер
        level = 1,
        role = nil,
        wounds = 0, shield = 0, energy = 3,
        stats = { Strength = 0, Dexterity = 0, Intelligence = 0, Spirit = 0, Fortitude = 0, Reflex = 0, Will = 0 },
        currentHP = 10,
        healingFatigue = nil, -- { count = N, stacks = N } — сохраняется между перелогинами
    },
    profile = {
        -- Настройки интерфейса (общие для всех персонажей аккаунта)
        minimapAngle = 220, uiScale = 1.0, turnQueueScale = 1.0,
        minimap = { hide = false },
        -- Системные сообщения синхронизации в чате. Мастер видит всегда (нужно
        -- для контроля группы); рядовой игрок по умолчанию НЕ видит, чтобы не
        -- спамить чат при подключениях/recovery. Переключается /dof sysmsg.
        systemMessages = false,
        -- Unit Frames (компактные фреймы игрока и цели)
        unitFrames = {
            player = {
                enabled = true,
                locked = false,
                scale = 1.0,
                position = { point = "CENTER", x = -400, y = -200 },
            },
            target = {
                enabled = true,
                locked = false,
                scale = 1.0,
                position = { point = "CENTER", x = -400, y = -300 },
            },
        },
        -- Action Bar (плавающая панель действий)
        actionBar = {
            enabled = true,
            locked = false,
            scale = 1.0,
            position = { point = "BOTTOM", x = 0, y = 120 },
        },
    },
    global = {
        unitData = {}, combatLog = {}, npcTemplates = {},
        -- Персистентность боевого состояния для переживания /reload и дисконнектов.
        -- Эффекты round-based: /reload не продвигает раунды, поэтому remainingRounds
        -- остаётся валидным и восстанавливается без пересчёта. Очищается на COMBAT_ENDED.
        playerEffects = {},      -- { [playerName] = { [effectId] = data } }
        npcEffects = {},         -- { [guid] = { [effectId] = data } }
        effectCooldowns = {},    -- { [casterName] = { [effectId] = remainingRounds } }
    },
}

-- ═══════════════════════════════════════════════════════════
-- ШРИФТЫ
-- ═══════════════════════════════════════════════════════════
--
-- Пока FontString наследует шрифт от объекта Blizzard, клиент сам подбирает
-- начертание для символов, которых в основном файле нет. Любой явный SetFont
-- эту подстраховку убирает: дальше рисуется только то, что есть в указанном
-- файле. FRIZQT__.TTF на нерусских сборках кириллицы не содержит — отсюда
-- квадраты вместо русского текста.
--
-- Поэтому для всех явных SetFont берём шрифт с кириллицей. FRIZQT___CYR.TTF
-- поставляется не только с русским клиентом (тем же приёмом чинят кириллицу
-- в TotalRP), но наличие файла всё равно проверяем: спросить заранее нельзя,
-- поэтому пробуем установить его на служебный FontString.
local fontProbe = UIParent:CreateFontString(nil, "BACKGROUND", "GameFontNormal")

local function CanUseFont(path)
    -- SetFont в разных версиях клиента возвращает то булево, то ничего,
    -- поэтому успех подтверждаем ещё и фактически установленным шрифтом.
    if fontProbe:SetFont(path, 12) then return true end
    return fontProbe:GetFont() == path
end

local function PickFont(candidates, fallback)
    for _, path in ipairs(candidates) do
        if path and CanUseFont(path) then return path end
    end
    return fallback
end

-- Порядок важен: сначала шрифты, про которые известно, что кириллица в них
-- есть. STANDARD_TEXT_FONT стоит последним именно потому, что на английском
-- клиенте это FRIZQT__.TTF без кириллицы — он тут крайний случай, а не выбор.
DoF.Config.FONT = PickFont({
    "Fonts\\FRIZQT___CYR.TTF",   -- основной шрифт с кириллицей
    "Fonts\\ARIALN.TTF",         -- шрифт чата: кириллицу отображает
    STANDARD_TEXT_FONT,
}, "Fonts\\FRIZQT__.TTF")

-- Заголовочный «морфеус». Если его нет — берём основной шрифт: лучше другая
-- гарнитура, чем квадраты.
DoF.Config.FONT_TITLE = PickFont({
    "Fonts\\MORPHEUS_CYR.TTF",
    "Fonts\\MORPHEUS.TTF",
}, DoF.Config.FONT)

-- ═══════════════════════════════════════════════════════════
-- ПОВТОРНОЕ ПРИМЕНЕНИЕ ЯЗЫКА
-- ═══════════════════════════════════════════════════════════

-- Config собирается на этапе загрузки файла, до того как становится известен
-- сохранённый язык. Все три таблицы ключуются предсказуемо, поэтому пересборка
-- обходится без дублирования списка строк.
DoF.Locale:RegisterRelocalizer(function()
    for id, role in pairs(DoF.Config.Roles) do
        role.name = DoF.L["roles." .. id .. ".name"]
        role.description = DoF.L["roles." .. id .. ".desc"]
    end

    for stat in pairs(DoF.Config.StatNames) do
        DoF.Config.StatNames[stat] = DoF.L["stats." .. stat:lower() .. ".label"]
    end

    for actionType in pairs(DoF.Config.SpecialActionTypes) do
        DoF.Config.SpecialActionTypes[actionType] = DoF.L["core.action." .. actionType]
    end
end)
