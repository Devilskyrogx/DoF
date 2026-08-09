-- DoF/Data/Effects.lua
-- Система статус-эффектов (баффы, дебаффы, DoT)

local ADDON_NAME, DoF = ...

-- Кэширование глобальных функций
local pairs = pairs
local ipairs = ipairs
local tonumber = tonumber
local tostring = tostring
local type = type
local next = next
local string_format = string.format
local math_max = math.max
local math_min = math.min
local math_random = math.random
local table_insert = table.insert
local table_remove = table.remove
local UnitName = UnitName
local GetTime = GetTime
local IsInGroup = IsInGroup

DoF.Effects = {
    -- Активные эффекты на игроках: { [playerName] = { [effectId] = effectData, ... }, ... }
    PlayerEffects = {},
    
    -- Активные эффекты на NPC: { [guid] = { [effectId] = effectData, ... }, ... }
    NPCEffects = {},
    
    -- Кулдауны: { [casterName] = { [effectId] = remainingRounds, ... }, ... }
    Cooldowns = {},
    
    -- UI фреймы для отображения
    PlayerEffectFrames = {},
    TargetEffectFrames = {},
}

local TEX_PATH = "Interface\\AddOns\\DoF\\texture\\"

-- Fallback иконки из стандартного WoW (пока не созданы кастомные)
local FALLBACK_ICONS = {
    effect_bleeding = "Interface\\Icons\\Ability_Rogue_Rupture",           -- Периодический урон
    effect_stun = "Interface\\Icons\\Spell_Nature_Polymorph",              -- Оглушение
    effect_weakness = "Interface\\Icons\\Spell_Shadow_CurseOfTounges",     -- Ослабление
    effect_vulnerability = "Interface\\Icons\\Ability_Warrior_Sunder",     -- Уязвимость
    effect_empower = "Interface\\Icons\\Spell_Holy_PowerWordShield",       -- Усиление
    effect_fortify = "Interface\\Icons\\Spell_Holy_DivineProtection",      -- Укрепление
}

-- Функция получения иконки с fallback
local function GetEffectIcon(iconPath)
    local iconName = iconPath:match("([^\\]+)$")
    if FALLBACK_ICONS[iconName] then
        return FALLBACK_ICONS[iconName]
    end
    return iconPath
end

-- ═══════════════════════════════════════════════════════════
-- ОПРЕДЕЛЕНИЕ ЭФФЕКТОВ
-- ═══════════════════════════════════════════════════════════

DoF.Effects.Definitions = {
    -- ══════════ DoT (Игрок → NPC) ══════════
    bleeding = {
        id = "bleeding",
        name = DoF.L["effects.bleeding.name"],
        icon = GetEffectIcon(TEX_PATH .. "effect_bleeding"),
        type = "dot",
        category = "basic",
        targetType = "npc",
        color = {0.8, 0.1, 0.1},
        description = DoF.L["effects.bleeding.desc"],
        fixedValue = 2,
        fixedDuration = 3,
        energyCost = 1,
    },
    
    -- ══════════ Дебаффы (Мастер → Игрок) ══════════
    stun = {
        id = "stun",
        name = DoF.L["effects.stun.name"],
        icon = TEX_PATH .. "effects\\debuff_stun",
        type = "debuff",
        category = "master",
        targetType = "player",
        color = {1, 1, 0},
        description = DoF.L["effects.stun.desc"],
        skipTurn = true,
        -- Мастер задаёт сам
        fixedValue = nil,
        fixedDuration = nil,
        energyCost = 0,
    },
    -- ══════════ Ослабление защитных статов NPC (игрок → NPC) ══════════
    weakness_fortitude = {
        id = "weakness_fortitude",
        name = DoF.L["effects.weakness_fortitude.name"],
        icon = TEX_PATH .. "effects\\debuff_fort",
        type = "debuff",
        category = "master",
        targetType = "npc",
        color = {0.64, 0.2, 0.79},
        description = DoF.L["effects.weakness_fortitude.desc"],
        statMod = "fort",  -- используем короткий ключ как в данных NPC
        modType = "reduce",
        fixedValue = nil,
        fixedDuration = nil,
        energyCost = 0,
    },
    weakness_reflex = {
        id = "weakness_reflex",
        name = DoF.L["effects.weakness_reflex.name"],
        icon = TEX_PATH .. "effects\\debuff_dext",
        type = "debuff",
        category = "master",
        targetType = "npc",
        color = {1, 0.49, 0.04},
        description = DoF.L["effects.weakness_reflex.desc"],
        statMod = "reflex",
        modType = "reduce",
        fixedValue = nil,
        fixedDuration = nil,
        energyCost = 0,
    },
    weakness_will = {
        id = "weakness_will",
        name = DoF.L["effects.weakness_will.name"],
        icon = TEX_PATH .. "effects\\debuff_will",
        type = "debuff",
        category = "master",
        targetType = "npc",
        color = {0.53, 0.53, 0.93},
        description = DoF.L["effects.weakness_will.desc"],
        statMod = "will",
        modType = "reduce",
        fixedValue = nil,
        fixedDuration = nil,
        energyCost = 0,
    },
    -- ══════════ Ослабление игрока (мастер → игрок) ══════════
    weakness_damage = {
        id = "weakness_damage",
        name = DoF.L["effects.weakness_damage.name"],
        icon = TEX_PATH .. "effects\\debuff_damage",
        type = "debuff",
        category = "master",
        targetType = "player",
        color = {0.8, 0.4, 0.4},
        description = DoF.L["effects.weakness_damage.desc"],
        statMod = "damage",
        modType = "reduce",
        fixedValue = nil,
        fixedDuration = nil,
        energyCost = 0,
    },
    weakness_healing = {
        id = "weakness_healing",
        name = DoF.L["effects.weakness_healing.name"],
        icon = TEX_PATH .. "effects\\debuff_heal",
        type = "debuff",
        category = "master",
        targetType = "player",
        color = {0.6, 0.8, 0.5},
        description = DoF.L["effects.weakness_healing.desc"],
        statMod = "healing",
        modType = "reduce",
        fixedValue = nil,
        fixedDuration = nil,
        energyCost = 0,
    },
    -- ══════════ Уязвимость по защитным статам (мастер → игрок) ══════════
    vulnerability_fortitude = {
        id = "vulnerability_fortitude",
        name = DoF.L["effects.vulnerability_fortitude.name"],
        icon = TEX_PATH .. "effects\\debuff_fort",
        type = "debuff",
        category = "master",
        targetType = "player",
        color = {0.64, 0.2, 0.79},
        description = DoF.L["effects.vulnerability_fortitude.desc"],
        statMod = "fortitude",
        modType = "reduce",
        fixedValue = nil,
        fixedDuration = nil,
        energyCost = 0,
    },
    vulnerability_reflex = {
        id = "vulnerability_reflex",
        name = DoF.L["effects.vulnerability_reflex.name"],
        icon = TEX_PATH .. "effects\\debuff_dext",
        type = "debuff",
        category = "master",
        targetType = "player",
        color = {1, 0.49, 0.04},
        description = DoF.L["effects.vulnerability_reflex.desc"],
        statMod = "reflex",
        modType = "reduce",
        fixedValue = nil,
        fixedDuration = nil,
        energyCost = 0,
    },
    vulnerability_will = {
        id = "vulnerability_will",
        name = DoF.L["effects.vulnerability_will.name"],
        icon = TEX_PATH .. "effects\\debuff_will",
        type = "debuff",
        category = "master",
        targetType = "player",
        color = {0.53, 0.53, 0.93},
        description = DoF.L["effects.vulnerability_will.desc"],
        statMod = "will",
        modType = "reduce",
        fixedValue = nil,
        fixedDuration = nil,
        energyCost = 0,
    },
    dot_master = {
        id = "dot_master",
        name = DoF.L["effects.dot_master.name"],
        icon = GetEffectIcon(TEX_PATH .. "effect_bleeding"),
        type = "dot",
        category = "master",
        targetType = "player",
        color = {0.8, 0.2, 0.2},
        description = DoF.L["effects.dot_master.desc"],
        fixedValue = nil,
        fixedDuration = nil,
        energyCost = 0,
    },
    
    -- ══════════ Усиление (Игрок → Игрок, DD + Healer) ══════════
    empower_strength = {
        id = "empower_strength",
        name = DoF.L["effects.empower_strength.name"],
        icon = TEX_PATH .. "effects\\buff_str",
        type = "buff",
        category = "basic",
        targetType = "player",
        color = {1, 0.4, 0.4},
        description = DoF.L["effects.empower_strength.desc"],
        statMod = "strength",
        modType = "increase",
        fixedValue = 4,
        singleTargetValue = 2,
        fixedDuration = 3,
        cooldownDuration = 2,
        aoeCooldownDuration = 4,
        energyCost = 1,
        empowerGroup = true,
    },
    empower_dexterity = {
        id = "empower_dexterity",
        name = DoF.L["effects.empower_dexterity.name"],
        icon = TEX_PATH .. "effects\\buff_agility",
        type = "buff",
        category = "basic",
        targetType = "player",
        color = {0.4, 1, 0.4},
        description = DoF.L["effects.empower_dexterity.desc"],
        statMod = "dexterity",
        modType = "increase",
        fixedValue = 4,
        singleTargetValue = 2,
        fixedDuration = 3,
        cooldownDuration = 2,
        aoeCooldownDuration = 4,
        energyCost = 1,
        empowerGroup = true,
    },
    empower_intelligence = {
        id = "empower_intelligence",
        name = DoF.L["effects.empower_intelligence.name"],
        icon = TEX_PATH .. "effects\\buff_intellect",
        type = "buff",
        category = "basic",
        targetType = "player",
        color = {0.4, 0.8, 1},
        description = DoF.L["effects.empower_intelligence.desc"],
        statMod = "intelligence",
        modType = "increase",
        fixedValue = 4,
        singleTargetValue = 2,
        fixedDuration = 3,
        cooldownDuration = 2,
        aoeCooldownDuration = 4,
        energyCost = 1,
        empowerGroup = true,
    },
    empower_spirit = {
        id = "empower_spirit",
        name = DoF.L["effects.empower_spirit.name"],
        icon = TEX_PATH .. "effects\\buff_spirit",
        type = "buff",
        category = "basic",
        targetType = "player",
        color = {1, 0.88, 0.4},
        description = DoF.L["effects.empower_spirit.desc"],
        statMod = "spirit",
        modType = "increase",
        fixedValue = 4,
        singleTargetValue = 2,
        fixedDuration = 3,
        cooldownDuration = 2,
        aoeCooldownDuration = 4,
        energyCost = 1,
        empowerGroup = true,
    },
    empower_damage = {
        id = "empower_damage",
        name = DoF.L["effects.empower_damage.name"],
        icon = TEX_PATH .. "effects\\buff_damage",
        type = "buff",
        category = "basic",
        targetType = "player",
        color = {1, 0.6, 0.2},
        description = DoF.L["effects.empower_damage.desc"],
        statMod = "damage",
        modType = "increase",
        fixedValue = 2,
        singleTargetValue = 1,
        fixedDuration = 3,
        cooldownDuration = 2,
        aoeCooldownDuration = 4,
        energyCost = 1,
        empowerGroup = true,
    },
    empower_healing = {
        id = "empower_healing",
        name = DoF.L["effects.empower_healing.name"],
        icon = TEX_PATH .. "effects\\buff_heal",
        type = "buff",
        category = "basic",
        targetType = "player",
        color = {0.2, 0.9, 0.3},
        description = DoF.L["effects.empower_healing.desc"],
        statMod = "healing",
        modType = "increase",
        fixedValue = 2,
        singleTargetValue = 1,
        fixedDuration = 3,
        cooldownDuration = 2,
        aoeCooldownDuration = 4,
        energyCost = 1,
        empowerGroup = true,
        ignoreHealCap = true,
    },
    -- ══════════ Укрепление (Игрок → Игрок, Tank + Healer) ══════════
    fortify_fortitude = {
        id = "fortify_fortitude",
        name = DoF.L["effects.fortify_fortitude.name"],
        icon = TEX_PATH .. "effects\\buff_fort",
        type = "buff",
        category = "basic",
        targetType = "player",
        color = {0.64, 0.2, 0.79},
        description = DoF.L["effects.fortify_fortitude.desc"],
        statMod = "fortitude",
        modType = "increase",
        fixedValue = 4,
        singleTargetValue = 2,
        fixedDuration = 3,
        cooldownDuration = 2,
        aoeCooldownDuration = 4,
        energyCost = 1,
        fortifyGroup = true,
    },
    fortify_reflex = {
        id = "fortify_reflex",
        name = DoF.L["effects.fortify_reflex.name"],
        icon = TEX_PATH .. "effects\\buff_dext",
        type = "buff",
        category = "basic",
        targetType = "player",
        color = {1, 0.49, 0.04},
        description = DoF.L["effects.fortify_reflex.desc"],
        statMod = "reflex",
        modType = "increase",
        fixedValue = 4,
        singleTargetValue = 2,
        fixedDuration = 3,
        cooldownDuration = 2,
        aoeCooldownDuration = 4,
        energyCost = 1,
        fortifyGroup = true,
    },
    fortify_will = {
        id = "fortify_will",
        name = DoF.L["effects.fortify_will.name"],
        icon = TEX_PATH .. "effects\\buff_will",
        type = "buff",
        category = "basic",
        targetType = "player",
        color = {0.53, 0.53, 0.93},
        description = DoF.L["effects.fortify_will.desc"],
        statMod = "will",
        modType = "increase",
        fixedValue = 4,
        singleTargetValue = 2,
        fixedDuration = 3,
        cooldownDuration = 2,
        aoeCooldownDuration = 4,
        energyCost = 1,
        fortifyGroup = true,
    },
    fortify_hp = {
        id = "fortify_hp",
        name = DoF.L["effects.fortify_hp.name"],
        icon = TEX_PATH .. "effects\\buff_health",
        type = "buff",
        category = "basic",
        targetType = "player",
        color = {0.2, 0.8, 0.2},
        description = DoF.L["effects.fortify_hp.desc"],
        fixedValue = 4,
        singleTargetValue = 2,
        fixedDuration = 3,
        cooldownDuration = 2,
        aoeCooldownDuration = 4,
        energyCost = 1,
        fortifyGroup = true,
        isHPBuff = true,
    },

    -- ══════════ Внутренние эффекты (системные, без энергии/кулдауна) ══════════
    tank_fort_streak = {
        id = "tank_fort_streak",
        name = DoF.L["effects.tank_fort_streak.name"],
        icon = TEX_PATH .. "effects\\buff_fort",
        type = "buff",
        category = "internal",
        targetType = "player",
        color = {0.8, 0.5, 0.2},
        description = DoF.L["effects.tank_fort_streak.desc"],
        statMod = "fortitude",
        modType = "increase",
        fixedValue = 1,
        fixedDuration = 3,
    },
    tank_reflex_streak = {
        id = "tank_reflex_streak",
        name = DoF.L["effects.tank_reflex_streak.name"],
        icon = TEX_PATH .. "effects\\buff_dext",
        type = "buff",
        category = "internal",
        targetType = "player",
        color = {0.6, 0.8, 0.4},
        description = DoF.L["effects.tank_reflex_streak.desc"],
        statMod = "reflex",
        modType = "increase",
        fixedValue = 1,
        fixedDuration = 3,
    },
    tank_will_streak = {
        id = "tank_will_streak",
        name = DoF.L["effects.tank_will_streak.name"],
        icon = TEX_PATH .. "effects\\buff_will",
        type = "buff",
        category = "internal",
        targetType = "player",
        color = {0.69, 0.5, 1.0},
        description = DoF.L["effects.tank_will_streak.desc"],
        statMod = "will",
        modType = "increase",
        fixedValue = 1,
        fixedDuration = 3,
    },
    -- ══════════ Бонусы танка: Пробитие защиты ══════════
    tank_shred_fortitude = {
        id = "tank_shred_fortitude",
        name = DoF.L["effects.tank_shred_fortitude.name"],
        icon = TEX_PATH .. "effects\\debuff_fort",
        type = "debuff",
        category = "internal",
        targetType = "npc",
        color = {0.8, 0.3, 0.1},
        description = DoF.L["effects.tank_shred_fortitude.desc"],
        statMod = "fort",
        modType = "reduce",
        fixedValue = 2,
        fixedDuration = 3,
    },
    tank_shred_reflex = {
        id = "tank_shred_reflex",
        name = DoF.L["effects.tank_shred_reflex.name"],
        icon = TEX_PATH .. "effects\\debuff_dext",
        type = "debuff",
        category = "internal",
        targetType = "npc",
        color = {0.9, 0.5, 0.1},
        description = DoF.L["effects.tank_shred_reflex.desc"],
        statMod = "reflex",
        modType = "reduce",
        fixedValue = 2,
        fixedDuration = 3,
    },
    -- ══════════ Бонусы танка: Перехват урона ══════════
    tank_redirect = {
        id = "tank_redirect",
        name = DoF.L["effects.tank_redirect.name"],
        icon = TEX_PATH .. "effects\\buff_fort",
        type = "buff",
        category = "internal",
        targetType = "player",
        color = {0.8, 0.5, 0.25},
        description = DoF.L["effects.tank_redirect.desc"],
        fixedDuration = 999,
    },
    cooldown_tank_redirect = {
        id = "cooldown_tank_redirect",
        name = DoF.L["effects.cooldown_tank_redirect.name"],
        icon = TEX_PATH .. "effects\\debuff_special",
        type = "debuff",
        category = "system",
        targetType = "player",
        color = {0.5, 0.3, 0.4},
        description = DoF.L["effects.cooldown_tank_redirect.desc"],
        fixedDuration = 2,
    },
    -- ══════════ Бонусы танка: Провокация ══════════
    tank_taunt = {
        id = "tank_taunt",
        name = DoF.L["effects.tank_taunt.name"],
        icon = TEX_PATH .. "effects\\debuff_fort",
        type = "debuff",
        category = "internal",
        targetType = "npc",
        color = {0.9, 0.4, 0.1},
        description = DoF.L["effects.tank_taunt.desc"],
        fixedDuration = 2,
    },
    cooldown_tank_taunt = {
        id = "cooldown_tank_taunt",
        name = DoF.L["effects.cooldown_tank_taunt.name"],
        icon = TEX_PATH .. "effects\\debuff_special",
        type = "debuff",
        category = "system",
        targetType = "player",
        color = {0.5, 0.3, 0.4},
        description = DoF.L["effects.cooldown_tank_taunt.desc"],
        fixedDuration = 2,
    },
    cooldown_tank_taunt_aoe = {
        id = "cooldown_tank_taunt_aoe",
        name = DoF.L["effects.cooldown_tank_taunt_aoe.name"],
        icon = TEX_PATH .. "effects\\debuff_special",
        type = "debuff",
        category = "system",
        targetType = "player",
        color = {0.5, 0.3, 0.4},
        description = DoF.L["effects.cooldown_tank_taunt_aoe.desc"],
        fixedDuration = 3,
    },
    healing_fatigue = {
        id = "healing_fatigue",
        name = DoF.L["effects.healing_fatigue.name"],
        icon = TEX_PATH .. "effects\\debuff_fatigue",
        type = "debuff",
        category = "system",
        targetType = "player",
        color = {0.7, 0.5, 0.2},
        description = DoF.L["effects.healing_fatigue.desc"],
        fixedDuration = 999,
        skipTurn = true,
        useValueAsStacks = true,
    },
    cooldown_special_action = {
        id = "cooldown_special_action",
        name = DoF.L["effects.cooldown_special_action.name"],
        icon = TEX_PATH .. "effects\\debuff_special",
        type = "debuff",
        category = "system",
        targetType = "player",
        color = {0.5, 0.3, 0.7},
        description = DoF.L["effects.cooldown_special_action.desc"],
        fixedDuration = 2,
    },
    cooldown_aoe = {
        id = "cooldown_aoe",
        name = DoF.L["effects.cooldown_aoe.name"],
        icon = TEX_PATH .. "effects\\debuff_special",
        type = "debuff",
        category = "system",
        targetType = "player",
        color = {0.5, 0.3, 0.4},
        description = DoF.L["effects.cooldown_aoe.desc"],
        fixedDuration = 3,
    },
    shield_exhaustion = {
        id = "shield_exhaustion",
        name = DoF.L["effects.shield_exhaustion.name"],
        icon = TEX_PATH .. "effects\\debuff_fort",
        type = "debuff",
        category = "system",
        targetType = "player",
        color = {0.4, 0.6, 1},
        description = DoF.L["effects.shield_exhaustion.desc"],
        fixedDuration = 3,
    },
    cooldown_shield = {
        id = "cooldown_shield",
        name = DoF.L["effects.cooldown_shield.name"],
        icon = TEX_PATH .. "effects\\debuff_special",
        type = "debuff",
        category = "system",
        targetType = "player",
        color = {0.3, 0.5, 0.7},
        description = DoF.L["effects.cooldown_shield.desc"],
        fixedDuration = 2,
    },
    cooldown_aoe_shield = {
        id = "cooldown_aoe_shield",
        name = DoF.L["effects.cooldown_aoe_shield.name"],
        icon = TEX_PATH .. "effects\\debuff_special",
        type = "debuff",
        category = "system",
        targetType = "player",
        color = {0.3, 0.4, 0.7},
        description = DoF.L["effects.cooldown_aoe_shield.desc"],
        fixedDuration = 3,
    },
}

-- ═══════════════════════════════════════════════════════════
-- ПРОВЕРКА ДОСТУПА
-- ═══════════════════════════════════════════════════════════

-- Получить ключ кулдауна (для групповых эффектов — общий)
function DoF.Effects:GetCooldownKey(def, effectId)
    if def.empowerGroup then return "empower_group" end
    if def.fortifyGroup then return "fortify_group" end
    return effectId
end

function DoF.Effects:CanApply(effectId, casterRole, casterName)
    local def = self.Definitions[effectId]
    if not def then return false, DoF.L["effects.deny.unknown"] end
    
    -- Master-эффекты только для мастера
    if def.category == "master" then
        if not DoF.Sync:IsMaster() then
            return false, DoF.L["effects.deny.master_only"]
        end
        return true
    end
    
    -- Проверка кулдауна (для групповых эффектов — общий)
    local cdKey = self:GetCooldownKey(def, effectId)
    if self:IsOnCooldown(casterName or UnitName("player"), cdKey) then
        local cd = self:GetCooldown(casterName or UnitName("player"), cdKey)
        return false, DoF.Locale:Format("effects.deny.cooldown", cd, DoF.Locale:Rounds(cd))
    end
    
    -- Проверка энергии
    if def.energyCost and def.energyCost > 0 then
        local currentEnergy = DoF.Stats:GetEnergy()
        if currentEnergy < def.energyCost then
            return false, DoF.Locale:Format("effects.deny.not_enough_energy", def.energyCost)
        end
    end
    
    -- Basic-эффекты доступны всем
    if def.category == "basic" then
        return true
    end
    
    -- Ролевые эффекты - проверка роли
    if def.category == casterRole then
        return true
    end
    
    return false, DoF.Locale:Format("effects.deny.role_required", def.category)
end

-- ═══════════════════════════════════════════════════════════
-- КУЛДАУНЫ
-- ═══════════════════════════════════════════════════════════

function DoF.Effects:IsOnCooldown(casterName, effectId)
    if not self.Cooldowns[casterName] then return false end
    return (self.Cooldowns[casterName][effectId] or 0) > 0
end

function DoF.Effects:GetCooldown(casterName, effectId)
    if not self.Cooldowns[casterName] then return 0 end
    return self.Cooldowns[casterName][effectId] or 0
end

function DoF.Effects:SetCooldown(casterName, effectId, rounds)
    if not self.Cooldowns[casterName] then
        self.Cooldowns[casterName] = {}
    end
    self.Cooldowns[casterName][effectId] = rounds
end

function DoF.Effects:TickCooldowns()
    for casterName, cooldowns in pairs(self.Cooldowns) do
        for effectId, remaining in pairs(cooldowns) do
            if remaining > 0 then
                cooldowns[effectId] = remaining - 1
            end
            if cooldowns[effectId] <= 0 then
                cooldowns[effectId] = nil
            end
        end
        if next(cooldowns) == nil then
            self.Cooldowns[casterName] = nil
        end
    end
end

-- ═══════════════════════════════════════════════════════════
-- ПРИМЕНЕНИЕ ЭФФЕКТОВ
-- ═══════════════════════════════════════════════════════════

function DoF.Effects:Apply(targetType, targetId, effectId, value, duration, casterName)
    local def = self.Definitions[effectId]
    if not def then
        DoF.Utils:Error(DoF.Locale:Format("errors.unknown_effect", effectId))
        return false
    end
    
    local storage = targetType == "npc" and self.NPCEffects or self.PlayerEffects
    casterName = casterName or UnitName("player")
    
    -- Создаём хранилище для цели если нет
    if not storage[targetId] then
        storage[targetId] = {}
    end
    
    -- Для игроков используем фиксированные значения (если не мастер или мастер-участник боя)
    local isMaster = DoF.Sync:IsMaster()
    local isMasterParticipant = isMaster and DoF.TurnSystem and DoF.TurnSystem:IsParticipant()
    local hasPlayerLimits = not isMaster or isMasterParticipant
    
    local finalValue = value
    local finalDuration = duration
    
    if hasPlayerLimits and def.fixedValue then
        finalValue = def.singleTargetValue or def.fixedValue
    end
    if hasPlayerLimits and def.fixedDuration then
        finalDuration = def.fixedDuration
    end
    
    -- Проверяем, не висит ли уже такой эффект
    local existingEffect = storage[targetId][effectId]
    if existingEffect then
        -- Проверяем, есть ли этот кастер уже в списке
        local casterExists = false
        if existingEffect.casters then
            for _, c in ipairs(existingEffect.casters) do
                if c == casterName then
                    casterExists = true
                    break
                end
            end
        elseif existingEffect.caster == casterName then
            casterExists = true
        end
        
        if casterExists then
            DoF.Utils:Warn(DoF.Locale:Format("effects.msg.already_applied_here", def.name))
            return false
        end

        -- Стакаем эффект от другого игрока
        if not existingEffect.casters then
            -- Конвертируем старый формат в новый
            existingEffect.casters = { existingEffect.caster }
            existingEffect.caster = nil
        end
        table.insert(existingEffect.casters, casterName)
        existingEffect.stacks = (existingEffect.stacks or 1) + 1
        existingEffect.value = (existingEffect.value or 0) + finalValue
        -- Обновляем длительность до максимальной
        if finalDuration > existingEffect.remainingRounds then
            existingEffect.remainingRounds = finalDuration
        end

        -- HP бафф: увеличиваем текущее HP при стакинге
        if def.isHPBuff and targetType == "player" and targetId == UnitName("player") then
            self:ApplyHPBuff(finalValue)
        end

        -- Тратим энергию (только для игроков, мастер-GM не тратит)
        if hasPlayerLimits and def.energyCost and def.energyCost > 0 then
            if not DoF.Stats:SpendEnergy(def.energyCost) then
                -- Откатываем изменения
                table.remove(existingEffect.casters)
                existingEffect.stacks = existingEffect.stacks - 1
                existingEffect.value = existingEffect.value - finalValue
                DoF.Utils:Error(DoF.L["errors.not_enough_energy"])
                return false
            end
        end

        -- Устанавливаем кулдаун
        if hasPlayerLimits then
            local cooldownRounds = def.cooldownDuration or 5
            local cdKey = self:GetCooldownKey(def, effectId)
            self:SetCooldown(casterName, cdKey, cooldownRounds)
        end

        -- Логируем
        local targetName = targetType == "npc" and (DoF.Units:Get(targetId) and DoF.Units:Get(targetId).name or "NPC") or targetId
        DoF.Utils:Info(string.format(DoF.L["effects.msg.stacked"],
            DoF.Utils:Color(self:GetColorHex(def.color), def.name),
            DoF.Utils:Color("FFFFFF", targetName),
            existingEffect.stacks))

        -- Синхронизация
        if DoF.Sync and IsInGroup() then
            local castersStr = table.concat(existingEffect.casters, ",")
            DoF.Sync:Send("EFFECT_STACK", string.format("%s;%s;%s;%d;%d;%d;%s",
                targetType, targetId, effectId, existingEffect.value, existingEffect.remainingRounds, existingEffect.stacks, castersStr))
        end
        
        DoF.Events:Fire("EFFECT_APPLIED", targetType, targetId, effectId)
        if DoF.UI.Effects then
            DoF.UI.Effects:UpdateAll()
        end
        return true
    end
    
    -- Тратим энергию (только для игроков, мастер-GM не тратит)
    if hasPlayerLimits and def.energyCost and def.energyCost > 0 then
        if not DoF.Stats:SpendEnergy(def.energyCost) then
            DoF.Utils:Error(DoF.L["errors.not_enough_energy"])
            return false
        end
    end

    -- Если эффект наложен во время NPC-фазы, он активируется при переходе на ход игроков
    local pending = false
    if DoF.TurnSystem and DoF.TurnSystem.phase == "npc" then
        pending = true
    end

    -- Применяем новый эффект
    storage[targetId][effectId] = {
        id = effectId,
        value = finalValue,
        duration = finalDuration,
        remainingRounds = finalDuration,
        casters = { casterName },
        stacks = 1,
        appliedAt = GetTime(),
        pendingActivation = pending,
    }

    -- Устанавливаем кулдаун (для игроков и мастера-участника)
    if hasPlayerLimits then
        local cooldownRounds = def.cooldownDuration or 5
        local cdKey = self:GetCooldownKey(def, effectId)
        self:SetCooldown(casterName, cdKey, cooldownRounds)
    end

    -- HP бафф: увеличиваем текущее HP локального игрока
    if def.isHPBuff and targetType == "player" and targetId == UnitName("player") then
        self:ApplyHPBuff(finalValue)
    end

    -- Лог в бой (броадкаст всем)
    local targetName = targetType == "npc" and (DoF.Units:Get(targetId) and DoF.Units:Get(targetId).name or "NPC") or targetId
    if DoF.Sync then
        DoF.Sync:BroadcastCombatLog(string.format(DoF.L["effects.msg.applies"],
            casterName, def.name, targetName))
    end

    -- Отправляем синхронизацию
    if DoF.Sync and IsInGroup() then
        DoF.Sync:Send("EFFECT_APPLY", string.format("%s;%s;%s;%d;%d;%s",
            targetType, targetId, effectId, finalValue, finalDuration, casterName))
    end
    
    -- Обновляем UI
    DoF.Events:Fire("EFFECT_APPLIED", targetType, targetId, effectId)
    if DoF.UI.Effects then
        DoF.UI.Effects:UpdateAll()
    end
    
    return true
end

-- Внутреннее (системное) применение эффекта: обходит энергию, кулдаун, CanApply
-- Удаляет старый эффект с тем же ID, затем создаёт новый
function DoF.Effects:ApplyInternal(targetType, targetId, effectId, value, duration, casterName)
    local def = self.Definitions[effectId]
    if not def then return false end

    local storage = targetType == "npc" and self.NPCEffects or self.PlayerEffects
    local caster = casterName or "System"

    -- Удаляем старый если есть
    if storage[targetId] and storage[targetId][effectId] then
        storage[targetId][effectId] = nil
    end

    if not storage[targetId] then
        storage[targetId] = {}
    end

    local effectStacks = 1
    local effectRemainingRounds = duration
    if def.useValueAsStacks then
        effectStacks = value or 1
        effectRemainingRounds = 0
    end

    storage[targetId][effectId] = {
        id = effectId,
        value = value,
        duration = duration,
        remainingRounds = effectRemainingRounds,
        casters = { caster },
        stacks = effectStacks,
        appliedAt = GetTime(),
    }

    -- Синхронизация
    if DoF.Sync and IsInGroup() then
        DoF.Sync:Send("EFFECT_APPLY", string.format("%s;%s;%s;%d;%d;%s",
            targetType, targetId, effectId, value, duration, caster))
    end

    DoF.Events:Fire("EFFECT_APPLIED", targetType, targetId, effectId)
    if DoF.UI.Effects then
        DoF.UI.Effects:UpdateAll()
    end

    return true
end

-- Применение эффекта игроком (использует фиксированные значения)
function DoF.Effects:PlayerApply(targetType, targetId, effectId)
    local def = self.Definitions[effectId]
    if not def then return false end
    
    if not DoF.Utils:RequireTurn(DoF.L["effects.action.apply"]) then return false end
    
    local casterName = UnitName("player")
    local casterRole = DoF.Stats:GetRole()
    
    -- Проверяем доступность
    local canApply, reason = self:CanApply(effectId, casterRole, casterName)
    if not canApply then
        DoF.Utils:Error(reason)
        return false
    end
    
    -- Применяем с значениями одиночной цели (singleTargetValue) или фиксированными (fixedValue)
    local applyValue = def.singleTargetValue or def.fixedValue
    local success = self:Apply(targetType, targetId, effectId, applyValue, def.fixedDuration, casterName)
    
    if success then
        -- Оповещаем пошаговую систему о завершении действия
        if DoF.TurnSystem then
            DoF.TurnSystem:OnActionPerformed()
        end
    end
    
    return success
end

-- Применение баффа в режиме AoE (энергия и кулдаун уже учтены)
function DoF.Effects:PlayerApplyAoE(targetName, effectId)
    local def = self.Definitions[effectId]
    if not def then return false end
    
    local casterName = UnitName("player")
    
    -- Проверяем, нет ли уже этого баффа от нас на цели
    if self:HasEffect("player", targetName, effectId) then
        local existing = self:Get("player", targetName, effectId)
        if existing then
            local hasCaster = false
            if existing.casters then
                for _, c in ipairs(existing.casters) do
                    if c == casterName then hasCaster = true; break end
                end
            elseif existing.caster == casterName then
                hasCaster = true
            end
            if hasCaster then
                DoF.Utils:Warn(DoF.Locale:Format("effects.msg.already_applied_on", def.name, targetName))
                return false
            end
        end
    end
    
    -- Применяем напрямую без проверки энергии/кулдауна
    local storage = self.PlayerEffects
    if not storage[targetName] then
        storage[targetName] = {}
    end
    
    local existing = storage[targetName][effectId]
    if existing then
        -- Стакаем
        if not existing.casters then
            existing.casters = { existing.caster }
            existing.caster = nil
        end
        table.insert(existing.casters, casterName)
        existing.stacks = (existing.stacks or 1) + 1
        existing.value = (existing.value or 0) + def.fixedValue
        if def.fixedDuration > existing.remainingRounds then
            existing.remainingRounds = def.fixedDuration
        end
    else
        storage[targetName][effectId] = {
            id = effectId,
            value = def.fixedValue,
            duration = def.fixedDuration,
            remainingRounds = def.fixedDuration,
            casters = { casterName },
            stacks = 1,
            appliedAt = GetTime(),
        }
    end
    
    -- Логируем
    DoF.Utils:Info(string.format(DoF.L["effects.msg.applied_aoe"],
        DoF.Utils:Color(self:GetColorHex(def.color), def.name),
        DoF.Utils:Color("FFFFFF", targetName)))
    
    if DoF.Sync then
        DoF.Sync:BroadcastCombatLog(string.format(DoF.L["effects.msg.applies_aoe"],
            casterName, def.name, targetName))
    end
    
    -- Синхронизация
    if DoF.Sync and IsInGroup() then
        DoF.Sync:Send("EFFECT_APPLY", string.format("%s;%s;%s;%d;%d;%s",
            "player", targetName, effectId, def.fixedValue, def.fixedDuration, casterName))
    end
    
    DoF.Events:Fire("EFFECT_APPLIED", "player", targetName, effectId)
    if DoF.UI.Effects then
        DoF.UI.Effects:UpdateAll()
    end
    
    return true
end

-- Применение эффекта мастером (кастомные значения)
function DoF.Effects:MasterApply(targetType, targetId, effectId, value, duration)
    if not DoF.Sync:IsMaster() then
        DoF.Utils:Error(DoF.L["errors.gm_only_function"])
        return false
    end
    
    -- Мастер может накладывать эффекты в любое время (это мастерское действие, не игровое)
    local success = self:Apply(targetType, targetId, effectId, value, duration, UnitName("player"))
    
    return success
end

-- Применение ослабления NPC игроком (специальная функция)
-- Игрок выбирает стат (fortitude/reflex/will), значение случайное 1-3, длительность 3 раунда
function DoF.Effects:PlayerApplyWeaken(npcGuid, effectId, value, duration)
    local def = self.Definitions[effectId]
    if not def then 
        DoF.Utils:Error(DoF.Locale:Format("errors.unknown_effect", effectId))
        return false 
    end
    
    if not DoF.Utils:RequireTurn(DoF.L["ui.action.weaken"]) then return false end
    
    local casterName = UnitName("player")
    
    if not DoF.Utils:RequireEnergy(1, DoF.L["ui.action.weaken"]) then return false end
    
    -- Проверка кулдауна (используем базовый effectId "weakness" для общего кулдауна)
    if self:IsOnCooldown(casterName, "weakness") then
        local cd = self:GetCooldown(casterName, "weakness")
        DoF.Utils:Error(DoF.Locale:Format("effects.deny.cooldown", cd, DoF.Locale:Rounds(cd)))
        return false
    end
    
    -- Стакинг ослабления (макс. 3 стака от разных игроков)
    local MAX_WEAKNESS_STACKS = 3
    local existing = self:Get("npc", npcGuid, effectId)
    local success

    if existing then
        -- Проверка: этот кастер уже наложил этот дебафф
        if existing.casters then
            for _, c in ipairs(existing.casters) do
                if c == casterName then
                    DoF.Utils:Error(DoF.Locale:Format("effects.msg.already_applied_here", def.name))
                    return false
                end
            end
        end

        -- Лимит стаков
        local currentStacks = existing.stacks or 1
        if currentStacks >= MAX_WEAKNESS_STACKS then
            DoF.Utils:Error(DoF.Locale:Format("effects.msg.max_stacks", def.name, MAX_WEAKNESS_STACKS))
            return false
        end

        -- Добавляем стак
        existing.stacks = currentStacks + 1
        existing.value = (existing.value or 0) + value
        existing.remainingRounds = duration  -- обновляем таймер

        -- Добавляем кастера
        if existing.casters then
            table.insert(existing.casters, casterName)
        end

        -- Синхронизация
        if DoF.Sync and IsInGroup() then
            local castersStr = existing.casters and table.concat(existing.casters, ",") or casterName
            DoF.Sync:Send("EFFECT_STACK", string_format("%s;%s;%s;%d;%d;%d;%s",
                "npc", npcGuid, effectId, existing.value, existing.remainingRounds, existing.stacks, castersStr))
        end

        DoF.Events:Fire("EFFECT_APPLIED", "npc", npcGuid, effectId)
        if DoF.UI.Effects then DoF.UI.Effects:UpdateAll() end
        success = true
    else
        -- Первое наложение
        success = self:Apply("npc", npcGuid, effectId, value, duration, casterName)
    end

    if success then
        -- Тратим энергию
        DoF.Stats:SpendEnergy(1)
        
        -- Ставим кулдаун на "weakness" (общий для всех типов ослабления игроком)
        self:SetCooldown(casterName, "weakness", 5)
        
        -- Броадкастим в журнал боя
        local npcData = DoF.Units:Get(npcGuid)
        local targetName = npcData and npcData.name or "NPC"
        local logMessage = string.format(DoF.L["effects.msg.applies_weakness"],
            casterName, self:GetColorHex(def.color), def.name, value, targetName, duration)
        if DoF.Sync then
            DoF.Sync:BroadcastCombatLog(logMessage)
        end
        
        -- Оповещаем пошаговую систему
        if DoF.TurnSystem then
            DoF.TurnSystem:OnActionPerformed()
        end
    end
    
    return success
end

function DoF.Effects:Remove(targetType, targetId, effectId, silent)
    local storage = targetType == "npc" and self.NPCEffects or self.PlayerEffects
    
    if not storage[targetId] or not storage[targetId][effectId] then
        return false
    end
    
    local def = self.Definitions[effectId]
    storage[targetId][effectId] = nil

    -- HP бафф или статовый бафф (может влиять на maxHP танка): пересчитываем HP
    if def and targetType == "player" and targetId == UnitName("player") then
        if def.isHPBuff or def.statMod then
            self:RemoveHPBuff()
        end
    end

    -- Очищаем пустые таблицы
    if next(storage[targetId]) == nil then
        storage[targetId] = nil
    end

    if not silent then
        local targetName = targetType == "npc" and (DoF.Units:Get(targetId) and DoF.Units:Get(targetId).name or "NPC") or targetId
        DoF.Utils:Info(DoF.Locale:Format("effects.msg.removed_from", def.name, DoF.Utils:Color("FFFFFF", targetName)))
    end

    -- Синхронизация
    if DoF.Sync and IsInGroup() then
        DoF.Sync:Send("EFFECT_REMOVE", string.format("%s;%s;%s", targetType, targetId, effectId))
    end
    
    -- Обновляем UI
    DoF.Events:Fire("EFFECT_REMOVED", targetType, targetId, effectId)
    
    return true
end

-- Снятие всех эффектов с цели
function DoF.Effects:ClearAll(targetType, targetId)
    local storage = targetType == "npc" and self.NPCEffects or self.PlayerEffects
    if not storage[targetId] then return end

    local toRemove = {}
    for effectId, _ in pairs(storage[targetId]) do
        table.insert(toRemove, effectId)
    end
    for _, effectId in ipairs(toRemove) do
        self:Remove(targetType, targetId, effectId, true)
    end

    DoF.Events:Fire("EFFECTS_CLEARED", targetType, targetId)
end

-- ═══════════════════════════════════════════════════════════
-- ОБРАБОТКА РАУНДА
-- ═══════════════════════════════════════════════════════════

function DoF.Effects:ProcessRound(targetType, targetId)
    local storage = targetType == "npc" and self.NPCEffects or self.PlayerEffects
    
    if not storage[targetId] then return end
    
    -- Для NPC проверяем что цель жива
    if targetType == "npc" then
        local npc = DoF.Units:Get(targetId)
        if not npc or npc.hp <= 0 then
            return
        end
    end
    
    local toRemove = {}
    
    for effectId, effectData in pairs(storage[targetId]) do
        local def = self.Definitions[effectId]

        -- Эффект наложен в NPC-фазу: активируем без тика
        if effectData.pendingActivation then
            effectData.pendingActivation = false
            local targetName = targetType == "npc" and (DoF.Units:Get(targetId) and DoF.Units:Get(targetId).name or "NPC") or targetId
            if DoF.Sync then
                DoF.Sync:BroadcastCombatLog(string_format(DoF.L["effects.msg.starts_on"],
                    DoF.Utils:Color(self:GetColorHex(def.color), def.name),
                    DoF.Utils:Color("FFFFFF", targetName)))
            end
        else
            -- Применяем эффект раунда (только фиксированный урон без модификаторов)
            if def.type == "dot" then
                -- Берём фиксированное значение из определения, игнорируя effectData.value
                local fixedDamage = def.fixedValue or effectData.value
                self:ApplyDamage(targetType, targetId, fixedDamage, def.name)
            elseif def.isHoT then
                -- Лечим
                self:ApplyHealing(targetType, targetId, effectData.value)
            end

            -- Уменьшаем длительность (кроме эффектов skipTurn - они тикают при пропуске хода)
            if not def.skipTurn then
                effectData.remainingRounds = effectData.remainingRounds - 1

                if effectData.remainingRounds <= 0 then
                    table.insert(toRemove, effectId)
                end
            end
        end
    end
    
    -- Удаляем истёкшие эффекты
    for _, effectId in ipairs(toRemove) do
        self:Remove(targetType, targetId, effectId)
    end
end


-- Обработка эффектов только на NPC (вызывается в начале раунда)
function DoF.Effects:ProcessNPCEffects()
    for guid, _ in pairs(self.NPCEffects) do
        self:ProcessRound("npc", guid)
    end

    -- Тикаем кулдауны
    self:TickCooldowns()

    -- Синхронизируем состояние
    if DoF.Sync and DoF.Sync:IsMaster() and IsInGroup() then
        self:BroadcastAllEffects()
    end

    -- Обновляем UI
    if DoF.UI.Effects then
        DoF.UI.Effects:UpdateAll()
    end
end

-- Обработка эффектов только на игроках (вызывается в ход NPC, только мастером)
function DoF.Effects:ProcessPlayerEffects()
    -- Только мастер тикает DoT/HoT на игроках (урон/хил синхронизируется через ModifyPlayerHP)
    if not DoF.Sync:IsMaster() then return end

    for playerName, _ in pairs(self.PlayerEffects) do
        self:ProcessRound("player", playerName)
    end

    -- Обновляем UI
    if DoF.UI.Effects then
        DoF.UI.Effects:UpdateAll()
    end
end

-- Синхронизация всех эффектов с клиентами
function DoF.Effects:BroadcastAllEffects()
    -- Синхронизируем эффекты на NPC
    for guid, effects in pairs(self.NPCEffects) do
        for effectId, effectData in pairs(effects) do
            local castersStr = ""
            if effectData.casters then
                castersStr = table.concat(effectData.casters, ",")
            elseif effectData.caster then
                castersStr = effectData.caster
            end
            local pendingFlag = effectData.pendingActivation and "1" or "0"
            DoF.Sync:Send("EFFECT_SYNC", string.format("npc;%s;%s;%d;%d;%s;%s;%d",
                guid, effectId, effectData.value or 0, effectData.remainingRounds or 0, castersStr, pendingFlag, effectData.stacks or 1))
        end
    end

    -- Синхронизируем эффекты на игроках
    for playerName, effects in pairs(self.PlayerEffects) do
        for effectId, effectData in pairs(effects) do
            local castersStr = ""
            if effectData.casters then
                castersStr = table.concat(effectData.casters, ",")
            elseif effectData.caster then
                castersStr = effectData.caster
            end
            local pendingFlag = effectData.pendingActivation and "1" or "0"
            DoF.Sync:Send("EFFECT_SYNC", string.format("player;%s;%s;%d;%d;%s;%s;%d",
                playerName, effectId, effectData.value or 0, effectData.remainingRounds or 0, castersStr, pendingFlag, effectData.stacks or 1))
        end
    end
end

-- Отправка эффектов восстанавливающемуся мастеру через SAFE команду (WHISPER)
function DoF.Effects:BroadcastEffectsForRecovery(target)
    for guid, effects in pairs(self.NPCEffects) do
        for effectId, effectData in pairs(effects) do
            local castersStr = effectData.casters and table.concat(effectData.casters, ",") or ""
            local pendingFlag = effectData.pendingActivation and "1" or "0"
            DoF.Sync:SendTo("EFFECT_SYNC_RECOVERY", string.format("npc;%s;%s;%d;%d;%s;%s;%d",
                guid, effectId, effectData.value or 0, effectData.remainingRounds or 0,
                castersStr, pendingFlag, effectData.stacks or 1), target)
        end
    end
    for playerName, effects in pairs(self.PlayerEffects) do
        for effectId, effectData in pairs(effects) do
            local castersStr = effectData.casters and table.concat(effectData.casters, ",") or ""
            local pendingFlag = effectData.pendingActivation and "1" or "0"
            DoF.Sync:SendTo("EFFECT_SYNC_RECOVERY", string.format("player;%s;%s;%d;%d;%s;%s;%d",
                playerName, effectId, effectData.value or 0, effectData.remainingRounds or 0,
                castersStr, pendingFlag, effectData.stacks or 1), target)
        end
    end
end

function DoF.Effects:ApplyDamage(targetType, targetId, damage, sourceName)
    if targetType == "npc" then
        local npc = DoF.Units:Get(targetId)
        if npc and npc.hp > 0 then
            local newHP = npc.hp - damage
            if newHP < 0 then
                newHP = 0
            end
            local actualDamage = npc.hp - newHP
            
            if actualDamage > 0 then
                DoF.Units:ModifyHP(targetId, newHP)
                if DoF.Sync then
                    DoF.Sync:BroadcastCombatLog(string.format(DoF.L["effects.msg.dot_damage_hp"],
                        npc.name, actualDamage, sourceName, newHP, npc.maxHp))
                end
            end
        end
    else
        -- Игрок: мастер синхронизирует через ModifyPlayerHP (обрабатывает и локальное применение)
        if DoF.Sync:IsMaster() then
            DoF.Sync:ModifyPlayerHP(targetId, -damage)
            DoF.Sync:BroadcastCombatLog(string.format(DoF.L["effects.msg.dot_damage"],
                targetId, damage, sourceName))
        elseif targetId == UnitName("player") then
            -- Не мастер, но цель — текущий игрок (fallback)
            DoF.Stats:ModifyHP(-damage)
        end
    end
end

function DoF.Effects:ApplyHealing(targetType, targetId, amount)
    if targetType == "player" then
        -- Мастер синхронизирует через ModifyPlayerHP (обрабатывает и локальное применение)
        if DoF.Sync:IsMaster() then
            DoF.Sync:ModifyPlayerHP(targetId, amount)
            DoF.Sync:BroadcastCombatLog(string.format(DoF.L["effects.msg.hot_heal"],
                targetId, amount))
        elseif targetId == UnitName("player") then
            -- Не мастер, но цель — текущий игрок (fallback)
            DoF.Stats:ModifyHP(amount)
        end
    end
end

-- ═══════════════════════════════════════════════════════════
-- ПОЛУЧЕНИЕ ДАННЫХ
-- ═══════════════════════════════════════════════════════════

function DoF.Effects:Get(targetType, targetId, effectId)
    local storage = targetType == "npc" and self.NPCEffects or self.PlayerEffects
    if storage[targetId] then
        return storage[targetId][effectId]
    end
    return nil
end

function DoF.Effects:GetAll(targetType, targetId)
    local storage = targetType == "npc" and self.NPCEffects or self.PlayerEffects
    return storage[targetId] or {}
end

function DoF.Effects:HasEffect(targetType, targetId, effectId)
    return self:Get(targetType, targetId, effectId) ~= nil
end

function DoF.Effects:IsStunned(playerName)
    local effect = self:Get("player", playerName, "stun")
    return effect ~= nil
end

-- Проверка оглушения NPC (по GUID)
function DoF.Effects:IsNPCStunned(npcGuid)
    local effect = self:Get("npc", npcGuid, "stun")
    return effect ~= nil
end

-- Тикнуть оглушение при пропуске хода
function DoF.Effects:TickStun(playerName)
    local effect = self:Get("player", playerName, "stun")
    if effect then
        effect.remainingRounds = effect.remainingRounds - 1
        if effect.remainingRounds <= 0 then
            self:Remove("player", playerName, "stun")
        end
        -- Синхронизируем
        if DoF.Sync and DoF.Sync:IsMaster() and IsInGroup() then
            self:BroadcastAllEffects()
        end
    end
end

-- Тикнуть оглушение NPC
function DoF.Effects:TickNPCStun(npcGuid)
    local effect = self:Get("npc", npcGuid, "stun")
    if effect then
        effect.remainingRounds = effect.remainingRounds - 1
        if effect.remainingRounds <= 0 then
            self:Remove("npc", npcGuid, "stun")
            local npcData = DoF.Units:Get(npcGuid)
            local npcName = npcData and npcData.name or DoF.L["effects.msg.npc_fallback"]
            DoF.Utils:Info(DoF.Locale:Format("effects.msg.stun_over", npcName))
        end
        -- Синхронизируем
        if DoF.Sync and DoF.Sync:IsMaster() and IsInGroup() then
            self:BroadcastAllEffects()
        end
    end
end

-- Получить модификатор от эффектов
function DoF.Effects:GetModifier(targetType, targetId, statType)
    local effects = self:GetAll(targetType, targetId)
    local modifier = 0

    for effectId, effectData in pairs(effects) do
        local def = self.Definitions[effectId]
        if def and def.statMod == statType then
            local value = effectData.value or 0
            if def.modType == "increase" then
                modifier = modifier + value
            elseif def.modType == "reduce" then
                modifier = modifier - value
            end
        end
    end

    return modifier
end

-- Раздельные модификаторы: возвращает buffTotal, debuffTotal (оба положительные числа)
function DoF.Effects:GetModifierSplit(targetType, targetId, statType)
    local effects = self:GetAll(targetType, targetId)
    local buffTotal, debuffTotal = 0, 0

    for effectId, effectData in pairs(effects) do
        local def = self.Definitions[effectId]
        if def and def.statMod == statType then
            local value = effectData.value or 0
            if def.modType == "increase" then
                buffTotal = buffTotal + value
            elseif def.modType == "reduce" then
                debuffTotal = debuffTotal + value
            end
        end
    end

    return buffTotal, debuffTotal
end

-- Увеличить HP локального игрока при наложении HP бафа
function DoF.Effects:ApplyHPBuff(value)
    if not DoF.Stats then return end
    local currentHP = DoF.Stats:GetCurrentHP()
    DoF.Stats:SetCurrentHP(currentHP + value)
    DoF.Events:Fire("PLAYER_HP_CHANGED", DoF.Stats:GetCurrentHP(), DoF.Stats:GetMaxHP())
    if DoF.Sync and IsInGroup() then
        DoF.Sync:BroadcastPlayerData()
    end
end

-- Пересчитать HP локального игрока при снятии HP бафа
function DoF.Effects:RemoveHPBuff()
    if not DoF.Stats then return end
    local maxHP = DoF.Stats:GetMaxHP()
    local currentHP = DoF.Stats:GetCurrentHP()
    if currentHP > maxHP then
        DoF.Stats:SetCurrentHP(maxHP)
    end
    DoF.Events:Fire("PLAYER_HP_CHANGED", DoF.Stats:GetCurrentHP(), DoF.Stats:GetMaxHP())
    if DoF.Sync and IsInGroup() then
        DoF.Sync:BroadcastPlayerData()
    end
end

-- Получить бонус HP от баффов (isHPBuff)
function DoF.Effects:GetHPBuffBonus(targetType, targetId)
    local effects = self:GetAll(targetType, targetId)
    local bonus = 0
    for effectId, effectData in pairs(effects) do
        local def = self.Definitions[effectId]
        if def and def.isHPBuff then
            bonus = bonus + (effectData.value or 0)
        end
    end
    return bonus
end

-- Проверить наличие флага среди активных эффектов на цели
function DoF.Effects:HasFlag(targetType, targetId, flag)
    local effects = self:GetAll(targetType, targetId)
    for effectId, _ in pairs(effects) do
        local def = self.Definitions[effectId]
        if def and def[flag] then
            return true
        end
    end
    return false
end

-- ═══════════════════════════════════════════════════════════
-- УТИЛИТЫ
-- ═══════════════════════════════════════════════════════════

function DoF.Effects:GetColorHex(color)
    return string.format("%02X%02X%02X", 
        math.floor(color[1] * 255),
        math.floor(color[2] * 255),
        math.floor(color[3] * 255))
end

-- Получить список доступных эффектов для роли
function DoF.Effects:GetAvailable(role, targetType)
    local available = {}
    local casterName = UnitName("player")
    
    for effectId, def in pairs(self.Definitions) do
        -- Проверяем тип цели
        if def.targetType == targetType or def.targetType == "any" then
            -- Проверяем доступность по роли (без проверки кулдауна/энергии)
            local categoryOk = false
            if def.category == "master" then
                categoryOk = DoF.Sync:IsMaster()
            elseif def.category == "basic" then
                categoryOk = true
            elseif def.category == role then
                categoryOk = true
            end
            
            if categoryOk then
                -- Добавляем информацию о кулдауне (для групповых эффектов — общий)
                local cdKey = self:GetCooldownKey(def, effectId)
                local onCooldown = self:IsOnCooldown(casterName, cdKey)
                local cdRemaining = self:GetCooldown(casterName, cdKey)

                table.insert(available, {
                    def = def,
                    onCooldown = onCooldown,
                    cooldownRemaining = cdRemaining,
                })
            end
        end
    end
    
    return available
end

-- Получить список мастерских эффектов
function DoF.Effects:GetMasterEffects()
    local effects = {}
    for effectId, def in pairs(self.Definitions) do
        if def.category == "master" then
            table.insert(effects, def)
        end
    end
    return effects
end

-- ═══════════════════════════════════════════════════════════
-- ДИСПЕЛ (СНЯТИЕ ЭФФЕКТОВ ХИЛЕРОМ)
-- ═══════════════════════════════════════════════════════════

function DoF.Effects:Dispel(targetName, casterRole, skipChecks)
    if not skipChecks then
        -- Только хилер может диспелить
        if casterRole ~= "healer" then
            DoF.Utils:Error(DoF.L["errors.healer_only_dispel"])
            return false
        end

        -- Проверка энергии
        local currentEnergy = DoF.Stats:GetEnergy()
        if currentEnergy < 1 then
            DoF.Utils:Error(DoF.L["errors.not_enough_energy_dispel"])
            return false
        end
    end
    
    local effects = self:GetAll("player", targetName)
    local dispelled = false
    
    for effectId, _ in pairs(effects) do
        local def = self.Definitions[effectId]
        if def.category ~= "system" and (def.type == "debuff" or (def.type == "dot" and def.category == "master")) then
            self:Remove("player", targetName, effectId)
            dispelled = true
            break -- Снимаем один эффект за раз
        end
    end
    
    if dispelled then
        if not skipChecks then
            DoF.Stats:SpendEnergy(1)
        end
        DoF.Utils:Info(DoF.Locale:Format("effects.msg.debuff_removed", DoF.Utils:Color("FFFFFF", targetName)))
        if DoF.Sync then
            DoF.Sync:BroadcastCombatLog(DoF.Locale:Format("effects.msg.debuff_removed_log", UnitName("player"), targetName))
        end
        -- OnActionPerformed вызывается в Combat:DispelTarget(), не здесь
        return true
    else
        DoF.Utils:Warn(DoF.L["effects.msg.no_debuffs"])
        return false
    end
end

-- ═══════════════════════════════════════════════════════════
-- ПУРЖ (СНЯТИЕ БАФФОВ — МАСТЕР ИЛИ ЦЕЛИТЕЛЬ)
-- ═══════════════════════════════════════════════════════════

function DoF.Effects:Purge(targetType, targetId, skipChecks)
    if not skipChecks then
        -- Мастер или целитель
        local role = DoF.Stats and DoF.Stats:GetRole()
        if not DoF.Sync:IsMaster() and role ~= "healer" then
            DoF.Utils:Error(DoF.L["errors.gm_or_healer_only_purge"])
            return false
        end
    end

    local effects = self:GetAll(targetType, targetId)
    local purged = false

    for effectId, _ in pairs(effects) do
        local def = self.Definitions[effectId]
        if def and def.type == "buff" then
            self:Remove(targetType, targetId, effectId)
            purged = true
            break
        end
    end

    if purged then
        local targetName = targetId
        if targetType == "npc" then
            local npcData = DoF.Units:Get(targetId)
            targetName = npcData and npcData.name or DoF.L["effects.msg.npc_fallback"]
        end
        DoF.Utils:Info(DoF.Locale:Format("effects.msg.buff_removed", DoF.Utils:Color("FFFFFF", targetName)))
        return true
    else
        DoF.Utils:Warn(DoF.L["effects.msg.no_buffs"])
        return false
    end
end

-- Очистка всех эффектов на цели
function DoF.Effects:ClearTarget(targetType, targetId)
    local storage = targetType == "npc" and self.NPCEffects or self.PlayerEffects
    
    if storage[targetId] then
        -- Собираем список эффектов для удаления
        local toRemove = {}
        for effectId, _ in pairs(storage[targetId]) do
            table.insert(toRemove, effectId)
        end
        
        -- Удаляем каждый эффект
        for _, effectId in ipairs(toRemove) do
            self:Remove(targetType, targetId, effectId)
        end
    end
    
    -- Синхронизируем
    if DoF.Sync and IsInGroup() then
        DoF.Sync:Send("EFFECTS_CLEAR_TARGET", targetType .. ";" .. targetId)
    end
    
    -- Обновляем UI
    DoF.Events:Fire("EFFECTS_CLEARED", targetType, targetId)
end

-- ═══════════════════════════════════════════════════════════
-- ПОВТОРНОЕ ПРИМЕНЕНИЕ ЯЗЫКА
-- ═══════════════════════════════════════════════════════════

-- Definitions собираются на этапе загрузки файла, когда сохранённый язык ещё
-- неизвестен (SavedVariables приходят только к ADDON_LOADED). Ключи выводятся
-- из id эффекта, поэтому пересборка не требует отдельной таблицы соответствий.
DoF.Locale:RegisterRelocalizer(function()
    for id, def in pairs(DoF.Effects.Definitions) do
        def.name = DoF.L["effects." .. id .. ".name"]
        def.description = DoF.L["effects." .. id .. ".desc"]
    end
end)
