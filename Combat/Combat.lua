-- DoF/Combat/Combat.lua
-- Боевая система: атаки, защита, исцеление, щит

local ADDON_NAME, DoF = ...

-- Кэширование глобальных функций
local math_random = math.random
local math_max = math.max
local math_min = math.min
local math_floor = math.floor
local string_format = string.format
local GetTime = GetTime
local UnitName = UnitName
local UnitGUID = UnitGUID
local PlaySound = PlaySound

DoF.Combat = {
    CritChoicePending = false,  -- Ожидается выбор крит-бонуса (блокирует действия)
    
    -- Состояние AoE атаки
    AoEState = {
        active = false,      -- Режим AoE активен
        stat = nil,          -- Атакующая стата
        hitsLeft = 0,        -- Осталось ударов
        hitTargets = {},     -- GUID уже атакованных целей
    },
    
    -- Состояние AoE исцеления
    AoEHealState = {
        active = false,      -- Режим AoE хила активен
        healsLeft = 0,       -- Осталось исцелений
        healedTargets = {},  -- Имена уже исцелённых целей
    },
    
    -- Состояние AoE баффа
    AoEBuffState = {
        active = false,      -- Режим AoE баффа активен
        effectId = nil,       -- ID эффекта для наложения
        buffsLeft = 0,        -- Осталось наложений
        buffedTargets = {},   -- Имена уже забаффленных целей
    },

    -- Состояние AoE щита
    AoEShieldState = {
        active = false,       -- Режим AoE щита активен
        shieldsLeft = 0,      -- Осталось наложений
        shieldedTargets = {}, -- GUID уже защищённых целей
    },
    
    -- Ожидающие атаки на игроков (защита от повторных атак)
    PendingAttacks = {},  -- { [playerName] = timestamp }
    PENDING_TIMEOUT = 30, -- Таймаут pending атаки в секундах (с ACK/retry 3×3с = 9с, 30с достаточно)

    -- Мгновенная защита: авто-бросок без окна (глобально на бой, переключается мастером)
    instantDefense = false,

    -- Система особого действия
    PendingSpecialAction = nil,  -- { playerName = "...", description = "...", timestamp = 123.45 }
    RejectedSpecialActions = {}, -- { [playerName] = roundNumber }

    -- Состояние расширенного особого действия (выбор целей после успешного броска)
    SpecialActionState = {
        active = false,          -- Режим выбора целей активен
        mode = nil,              -- "buff", "aoe_buff", "attack", "aoe_attack", "wound_removal", "dispel", "purge"
        effectId = nil,          -- ID эффекта (для buff/aoe_buff)
        dmgMin = nil,            -- Мин. урон (для attack/aoe_attack)
        dmgMax = nil,            -- Макс. урон (для attack/aoe_attack)
        targetsLeft = 0,         -- Осталось целей для выбора
        selectedTargets = {},    -- Уже выбранные цели { [name/guid] = true }
        description = "",        -- Описание действия для лога
    },

    -- Усталость лечения: { [playerName] = { count = 0, stacks = 0 } }
    HealingFatigue = {},

    -- Состояние контратаки (выбор цели)
    CounterattackState = {
        active = false,
        damage = 0,
        playerName = nil,
    },

    -- Серия успешных защит танка: { [playerName] = { count = 0 } }
    TankDefenseStreak = {},

    -- Трекер пробития защиты танка: { [playerName] = { [npcGuid] = count } }
    TankShredTracker = {},

    -- Состояние AoE провокации
    AoETauntState = {
        active = false,
        tauntsLeft = 0,
        tauntedTargets = {},
    },
}

-- ═══════════════════════════════════════════════════════════
-- ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ
-- ═══════════════════════════════════════════════════════════

-- Сохранение усталости лечения в SavedVariables (персистентность при перелогине)
-- + рассылка FATIGUE всем, чтобы мастер и остальные клиенты видели актуальный
-- count/stacks этого целителя (DC лечения = базовый + stacks*2). До этого
-- count жил только у целителя, UI мастера показывал устаревшие значения.
function DoF.Combat:SaveHealingFatigue()
    if not DoF.db or not DoF.db.char then return end
    local myName = UnitName("player")
    local fatigue = DoF.Combat.HealingFatigue[myName]
    local stacks = 0
    if DoF.Effects then
        local eff = DoF.Effects:Get("player", myName, "healing_fatigue")
        if eff then stacks = eff.stacks or 0 end
    end
    if stacks > 0 or (fatigue and fatigue.count > 0) then
        DoF.db.char.healingFatigue = { count = fatigue and fatigue.count or 0, stacks = stacks }
    else
        DoF.db.char.healingFatigue = nil
    end
    -- Broadcast: каждый healer владеет своей усталостью, но рассылает её
    -- остальным — иначе UI мастера не знает count/stacks этого игрока.
    if DoF.Sync and IsInGroup() then
        local count = fatigue and fatigue.count or 0
        DoF.Sync:Send("FATIGUE", myName .. ";" .. count .. ";" .. stacks)
    end
end

-- Проверка наличия роли (обязательна для боевых действий)
local function RequireRole()
    if not DoF.Stats:GetRole() then
        DoF.Utils:Error(DoF.L["errors.choose_role"])
        return false
    end
    return true
end

-- Проверка 50/50 при равенстве броска и порога
function DoF.Combat:Check5050(total, threshold)
    if total == threshold then
        return math_random(1, 2) == 1
    end
    return total > threshold
end

-- Определение успеха с учётом 50/50
function DoF.Combat:IsSuccess(total, threshold)
    if total > threshold then
        return true
    elseif total < threshold then
        return false
    else
        return self:Check5050(total, threshold)
    end
end

-- Расчёт урона с учётом уровня и роли
function DoF.Combat:CalculateDamage(isCrit)
    local level = DoF.Stats:GetLevel()
    local role = DoF.Stats:GetRole()
    local range = DoF.Config:GetDamageRange(level, role)

    -- Модификатор от баффов
    local dmgMod = DoF.Effects and DoF.Effects:GetModifier("player", UnitName("player"), "damage") or 0

    local adjustedMin = math_max(1, range.min + dmgMod)
    local adjustedMax = math_max(1, range.max + dmgMod)
    local damage = DoF.Utils:Roll(adjustedMin, adjustedMax)

    if isCrit then
        local critBonus = math_min(range.max, DoF.Config.CRIT_BONUS_CAP)
        damage = damage + critBonus
    end

    return math_max(1, damage)
end

-- Расчёт исцеления с учётом уровня и роли
function DoF.Combat:CalculateHealing(isCrit)
    local level = DoF.Stats:GetLevel()
    local role = DoF.Stats:GetRole()
    local range = DoF.Config:GetHealingRange(level, role)

    -- Модификатор от баффов
    local healMod = DoF.Effects and DoF.Effects:GetModifier("player", UnitName("player"), "healing") or 0

    local adjustedMin = math_max(1, range.min + healMod)
    local adjustedMax = math_max(1, range.max + healMod)
    local heal = DoF.Utils:Roll(adjustedMin, adjustedMax)

    if isCrit then
        local critBonus = math_min(range.max, DoF.Config.CRIT_BONUS_CAP)
        heal = heal + critBonus
    end

    -- Ограничение 50% maxHP (если нет бафа ignoreHealCap)
    if not isCrit then
        local maxHP = DoF.Stats:GetMaxHP()
        local healCap = math_floor(maxHP / 2)
        local hasIgnoreCap = DoF.Effects and DoF.Effects:HasFlag("player", UnitName("player"), "ignoreHealCap")
        if not hasIgnoreCap and heal > healCap then
            heal = healCap
        end
    end

    return math_max(1, heal)
end

-- Форматирование результата броска
function DoF.Combat:FormatRollResult(attackerName, statName, targetName, total, roll, modifier, threshold, isSuccess, resultText)
    local compareSign = isSuccess and ">=" or "<="
    local resultColor = isSuccess and "00FF00" or "FF6666"
    local statColor = DoF.Config.StatColors[statName] or "FFFFFF"
    
    local line1 = string.format(DoF.L["combat.uses"],
        attackerName,
        DoF.Utils:Color(statColor, DoF.Config.StatNames[statName] or statName),
        targetName)
    
    local line2 = string.format(DoF.L["combat.roll_result"],
        DoF.Utils:Color("FFFF00", total),
        roll, modifier,
        compareSign,
        threshold,
        DoF.Utils:Color(resultColor, resultText))
    
    return line1, line2
end


-- ═══════════════════════════════════════════════════════════
-- АТАКА ИГРОКА ПО NPC
-- ═══════════════════════════════════════════════════════════

function DoF.Combat:Attack(stat)
    if not RequireRole() then return end

    -- Проверка AoE режима
    if self:IsAoEActive() then
        DoF.Utils:Error(DoF.L["errors.finish_aoe_first"])
        return
    end
    
    if self:IsAoEHealActive() then
        DoF.Utils:Error(DoF.L["errors.finish_aoe_heal"])
        return
    end
    
    if self:IsAoEBuffActive() then
        DoF.Utils:Error(DoF.L["errors.finish_aoe_buff"])
        return
    end

    if self:IsTauntAoEActive() then
        DoF.Utils:Error(DoF.L["errors.finish_aoe_taunt"])
        return
    end

    if not DoF.Utils:RequireTurn(DoF.L["combat.action.attack"]) then return end

    local guid, name = DoF.Utils:GetTargetGUID()

    if not guid then
        DoF.Utils:Error(DoF.L["errors.no_target"])
        return
    end

    if DoF.Utils:IsTargetPlayer() then
        DoF.Utils:Error(DoF.L["errors.cannot_attack_players"])
        return
    end
    
    -- Блокируем атаку, если данные NPC ещё не синхронизированы после реконнекта
    if DoF.Sync and DoF.Sync.WaitingForFullData then
        DoF.Utils:Error(DoF.L["errors.awaiting_npc_sync"])
        return
    end

    local data = DoF.Units:Get(guid)
    if not data then
        DoF.Utils:Error(DoF.L["errors.target_hp_not_set"])
        return
    end
    
    if data.hp <= 0 then
        DoF.Utils:Error(DoF.L["errors.target_dead"])
        return
    end
    
    -- Бросок атаки
    local modifier = DoF.Stats:GetTotal(stat)
    local roll = DoF.Utils:Roll(1, 20)
    local total = roll + modifier
    
    -- Определяем порог защиты
    local defenseStat = DoF.Config.AttackVsDefense[stat]
    local defenseKey = defenseStat == "Fortitude" and "fort" or 
                       (defenseStat == "Reflex" and "reflex" or "will")
    local baseThreshold = data[defenseKey] or 10
    
    -- Учитываем эффекты ослабления защиты на NPC
    local effectMod = DoF.Effects:GetModifier("npc", guid, defenseKey)
    -- Пассивка: Адаптация — бонус к защите после серии атак одним статом
    local adaptMod = DoF.Passives and DoF.Passives:GetAdaptationBonus(guid, defenseStat) or 0
    local threshold = math_max(1, baseThreshold + effectMod + adaptMod)
    
    -- Результат
    local damage = 0
    local resultText = ""
    local isSuccess = false
    local isCrit = false
    local floatType = "miss"

    if roll == 1 then
        isSuccess = false
        resultText = DoF.L["combat.result.crit_fail"]
        floatType = "crit_fail"

    elseif roll == 20 then
        isSuccess = true
        isCrit = true
        -- Базовый урон без +3 бонуса (игрок выберет в меню)
        damage = self:CalculateDamage(false)
        resultText = DoF.L["combat.result.crit_success"]
        floatType = "crit_success"

    else
        isSuccess = self:IsSuccess(total, threshold)
        if isSuccess then
            -- Пассивка: Уклонение — шанс полностью уклониться от успешной атаки
            local evaded = false
            if DoF.Passives and DoF.Passives:Has(guid, "evasion") then
                local evasionData = DoF.Passives:Get(guid, "evasion")
                local evasionChance = evasionData.chance or 0
                if evasionChance > 0 and math_random(1, 100) <= evasionChance then
                    evaded = true
                    isSuccess = false
                    resultText = DoF.L["combat.result.dodge"]
                    floatType = "miss"
                end
            end
            if not evaded then
                damage = self:CalculateDamage(false)
                resultText = DoF.L["combat.result.success"]
                floatType = "hit"
            end
        else
            resultText = DoF.L["combat.result.fail"]
            floatType = "miss"
        end
    end
    
    -- Пассивка: Отражение магии — шанс отразить Intelligence-атаку
    local reflected = false
    if isSuccess and damage > 0 and not isCrit and stat == "Intelligence" and DoF.Passives and DoF.Passives:Has(guid, "spell_reflection") then
        local reflData = DoF.Passives:Get(guid, "spell_reflection")
        local reflChance = reflData.chance or 0
        if reflChance > 0 and math_random(1, 100) <= reflChance then
            reflected = true
            -- Урон отражается на атакующего, NPC не получает урона
            DoF.Stats:ModifyHP(-damage)
            if DoF.Sync then DoF.Sync:BroadcastPlayerData() end
        end
    end

    -- Форматируем вывод
    local playerName = UnitName("player")
    local line1, line2

    if reflected then
        line1, line2 = self:FormatRollResult(playerName, stat, name, total, roll, modifier, threshold, isSuccess, DoF.L["combat.result.reflected"])
        line2 = line2 .. DoF.Locale:Format("combat.reflected_damage", damage)
        damage = 0 -- NPC не получает урона
    else
        line1, line2 = self:FormatRollResult(playerName, stat, name, total, roll, modifier, threshold, isSuccess, resultText)
        if damage > 0 then
            line2 = line2 .. DoF.Locale:Format("combat.damage_suffix", DoF.Utils:Color("FF6666", damage))
        end
    end

    -- Лог боя (отправляем всем через Sync, включая себя)
    DoF.Sync:BroadcastCombatLog(line1 .. " " .. line2)

    -- Всплывающий текст
    if DoF.UI then
        DoF.UI:ShowAttackResult(name, reflected and "miss" or floatType, reflected and 0 or damage)
    end

    -- При крите - показываем меню выбора
    if isCrit and damage > 0 and not reflected then
        DoF.Dialogs:ShowCritChoiceMenu("attack", function(choice, finalDamage, targetGuid, targetName)
            self:ApplyCritAttackChoice(choice, finalDamage, targetGuid, targetName, stat)
        end, damage, guid, name)
    elseif damage > 0 and not reflected then
        -- Обычный урон - применяем сразу (Damage учитывает щит)
        DoF.Units:Damage(guid, damage)

        if data.hp <= 0 then
            DoF.Utils:Print("FF0000", DoF.Locale:Format("combat.target_dead_msg", name))
        end
    end

    -- Пассивка: Ядовитый — шанс отравления при успешной атаке Силой
    if isSuccess and not isCrit and stat == "Strength" and not reflected and DoF.Passives and DoF.Passives:Has(guid, "poisonous") then
        local poisonData = DoF.Passives:Get(guid, "poisonous")
        local poisonChance = poisonData.chance or 0
        if poisonChance > 0 and math_random(1, 100) <= poisonChance then
            local dotValue = poisonData.dotValue or 1
            local dotDuration = poisonData.dotDuration or 3
            if poisonData.instantDamage then
                -- Мгновенный урон вместо DoT
                local totalDmg = dotValue * dotDuration
                DoF.Stats:ModifyHP(-totalDmg)
                if DoF.Sync then DoF.Sync:BroadcastPlayerData() end
                DoF.Sync:BroadcastCombatLog(string_format(
                    DoF.L["combat.poisoned_instant"],
                    playerName,
                    DoF.Utils:Color("00CC00", name),
                    totalDmg))
                DoF.CombatLog:Add(string_format(DoF.L["combat.poison_log"], name, playerName, totalDmg))
            elseif DoF.Effects then
                DoF.Effects:ApplyInternal("player", playerName, "dot_master", dotValue, dotDuration, name)
                DoF.Sync:BroadcastCombatLog(string_format(
                    DoF.L["combat.poisoned"],
                    playerName,
                    DoF.Utils:Color("00CC00", name),
                    dotValue, dotDuration))
            end
        end
    end

    -- Танк: пробитие защиты (счётчик подряд удачных атак по одному NPC)
    -- При крите ProcessTankShred вызывается из ApplyCritAttackChoice, чтобы не считать крит за 2 удара
    if DoF.Stats:GetRole() == "tank" then
        if isSuccess and not isCrit then
            self:ProcessTankShred(guid, name)
        else
            -- Промах сбрасывает счётчик
            local playerName = UnitName("player")
            if self.TankShredTracker[playerName] then
                self.TankShredTracker[playerName][guid] = nil
            end
        end
    end

    -- Пассивка: Адаптация — трекинг типа стата атаки
    if DoF.Passives and DoF.Passives:Has(guid, "adaptation") then
        DoF.Passives:TrackAdaptation(guid, stat)
    end

    -- Реактивные пассивки NPC (шипы, контратака, берсерк) — после основной атаки
    -- Вызывают ProcessNPCAttack, игрок должен защищаться
    if not isCrit and not reflected and data.hp > 0 then
        self:ProcessAttackReactivePassives(guid, name, stat, isSuccess)
    end

    -- Оповещаем пошаговую систему (при крите это делается после выбора в меню)
    if DoF.TurnSystem and not isCrit then
        DoF.TurnSystem:OnActionPerformed()
    end
end

-- Применить выбор крита при атаке
function DoF.Combat:ApplyCritAttackChoice(choice, baseDamage, targetGuid, targetName, attackStat)
    local data = DoF.Units:Get(targetGuid)
    if not data then
        -- Даже если цель не найдена, завершаем ход
        if DoF.TurnSystem then
            DoF.TurnSystem:OnActionPerformed()
        end
        return
    end

    local finalDamage = baseDamage

    local playerName = UnitName("player")

    if choice == "bonus_damage" then
        local range = DoF.Config:GetDamageRange(DoF.Stats:GetLevel(), DoF.Stats:GetRole())
        local critBonus = math_min(range.max, DoF.Config.CRIT_BONUS_CAP)
        finalDamage = baseDamage + critBonus
        DoF.Sync:BroadcastCombatLog(string_format(DoF.L["combat.crit_bonus_damage"],
            playerName,
            DoF.Utils:Color("FF6666", DoF.Locale:Format("combat.bonus_damage_label", critBonus)),
            DoF.Utils:Color("FFFF00", baseDamage),
            DoF.Utils:Color("FF0000", finalDamage)))
    elseif choice == "energy" then
        -- Энергия уже добавлена в меню
        DoF.Sync:BroadcastCombatLog(string_format(DoF.L["combat.crit_bonus"],
            playerName, DoF.Utils:Color("9966FF", DoF.L["combat.bonus_energy"])))
    elseif choice == "full_heal" then
        -- Полное исцеление цели (Целитель)
        local maxHP = data.maxHp or 10
        DoF.Units:ModifyHP(targetGuid, maxHP)
        DoF.Sync:BroadcastCombatLog(string_format(DoF.L["combat.crit_bonus_target"],
            playerName, DoF.Utils:Color("66FF66", DoF.L["combat.bonus_full_heal"]), targetName))
        -- Завершаем ход (не наносим урон)
        if DoF.TurnSystem then
            DoF.TurnSystem:OnActionPerformed()
        end
        return
    elseif choice == "shield" then
        -- Щит уже добавлен в меню
        DoF.Sync:BroadcastCombatLog(string_format(DoF.L["combat.crit_bonus"],
            playerName, DoF.Utils:Color("66CCFF", DoF.L["combat.bonus_shield_3"])))
    end

    -- Применяем урон (Damage учитывает щит)
    DoF.Units:Damage(targetGuid, finalDamage)

    DoF.Utils:Warn(DoF.Locale:Format("combat.takes_damage", targetName,
        DoF.Utils:Color("FF0000", finalDamage),
        DoF.Utils:Color("FF0000", data.hp .. "/" .. data.maxHp)))

    if data.hp <= 0 then
        DoF.Utils:Print("FF0000", DoF.Locale:Format("combat.target_dead_msg", targetName))
    end

    -- Пассивка: Ядовитый — шанс отравления при крит-атаке Силой
    if attackStat == "Strength" and DoF.Passives and DoF.Passives:Has(targetGuid, "poisonous") then
        local poisonData = DoF.Passives:Get(targetGuid, "poisonous")
        local poisonChance = poisonData.chance or 0
        if poisonChance > 0 and math_random(1, 100) <= poisonChance then
            local dotValue = poisonData.dotValue or 1
            local dotDuration = poisonData.dotDuration or 3
            if poisonData.instantDamage then
                -- Мгновенный урон вместо DoT
                local totalDmg = dotValue * dotDuration
                DoF.Stats:ModifyHP(-totalDmg)
                if DoF.Sync then DoF.Sync:BroadcastPlayerData() end
                DoF.Sync:BroadcastCombatLog(string_format(
                    DoF.L["combat.poisoned_instant"],
                    playerName,
                    DoF.Utils:Color("00CC00", targetName),
                    totalDmg))
                DoF.CombatLog:Add(string_format(DoF.L["combat.poison_log"], targetName, playerName, totalDmg))
            elseif DoF.Effects then
                DoF.Effects:ApplyInternal("player", playerName, "dot_master", dotValue, dotDuration, targetName)
                DoF.Sync:BroadcastCombatLog(string_format(
                    DoF.L["combat.poisoned"],
                    playerName,
                    DoF.Utils:Color("00CC00", targetName),
                    dotValue, dotDuration))
            end
        end
    end

    -- Танк: пробитие защиты (крит тоже считается удачной атакой)
    if DoF.Stats:GetRole() == "tank" then
        self:ProcessTankShred(targetGuid, targetName)
    end

    -- Реактивные пассивки NPC после крита
    if data.hp > 0 then
        self:ProcessAttackReactivePassives(targetGuid, targetName, attackStat, true)
    end

    -- Оповещаем пошаговую систему о завершении хода
    if DoF.TurnSystem then
        DoF.TurnSystem:OnActionPerformed()
    end
end

-- AoE механики вынесены в Combat/AoE.lua

-- ═══════════════════════════════════════════════════════════
-- РЕАКТИВНЫЕ ПАССИВКИ NPC (Шипы, Контратака, Берсерк)
-- ═══════════════════════════════════════════════════════════

-- Обрабатывает реактивные пассивки NPC после атаки игрока
-- Только одна реактивная пассивка может сработать за атаку (приоритет: Шипы > Берсерк > Контратака)
function DoF.Combat:ProcessAttackReactivePassives(guid, npcName, attackStat, isSuccess)
    if not DoF.Passives then return end

    local data = DoF.Units:Get(guid)
    if not data or not data.passives or data.hp <= 0 then return end

    -- 1. Шипы — гарантированные или с шансом
    if data.passives.thorns then
        local thorns = data.passives.thorns
        local triggered = false
        if thorns.mode == "guaranteed" then
            triggered = true
        elseif thorns.mode == "chance" then
            local chance = thorns.chance or 0
            triggered = chance > 0 and math_random(1, 100) <= chance
        end
        if triggered then
            local dmgMin = thorns.damageMin or 1
            local dmgMax = thorns.damageMax or 3

            if thorns.instantDamage then
                -- Мгновенный урон: без броска защиты
                local dmg = math_random(dmgMin, dmgMax)
                local playerName = UnitName("player")
                DoF.Stats:ModifyHP(-dmg)
                if DoF.Sync then DoF.Sync:BroadcastPlayerData() end
                DoF.Sync:BroadcastCombatLog(string_format(
                    DoF.L["combat.thorns_damage"],
                    DoF.Utils:Color("FFCC00", npcName), dmg, playerName))
                DoF.CombatLog:Add(string_format(DoF.L["combat.thorns_log"], npcName, playerName, dmg))
            else
                local thresh = thorns.threshold or 10
                DoF.Sync:BroadcastCombatLog(string_format(
                    DoF.L["combat.thorns_trigger"],
                    DoF.Utils:Color("FFCC00", npcName)))
                -- Показываем диалог выбора защиты (Hybrid)
                DoF.Dialogs:ShowHybridDefenseChoice(npcName, dmgMin, dmgMax, thresh, nil, 0, 0)
            end
            return -- Только одна пассивка за атаку
        end
    end

    -- 2. Берсерк — гарантированная контратака если HP < 50%
    if data.passives.berserk then
        local berserk = data.passives.berserk
        if data.hp < (data.maxHp / 2) then
            local dmgMin = berserk.damageMin or 3
            local dmgMax = berserk.damageMax or 6
            local thresh = berserk.threshold or 14
            local stunDur = berserk.stunDuration or 1
            DoF.Sync:BroadcastCombatLog(string_format(
                DoF.L["combat.berserk"],
                DoF.Utils:Color("FF4444", npcName)))
            -- Показываем диалог выбора защиты (Hybrid + стан)
            DoF.Dialogs:ShowHybridDefenseChoice(npcName, dmgMin, dmgMax, thresh, "stun", 0, stunDur)
            return
        end
    end

    -- 3. Контратака — шанс контрудара
    if data.passives.npc_counterattack then
        local ca = data.passives.npc_counterattack
        local chance = ca.chance or 0
        if chance > 0 and math_random(1, 100) <= chance then
            local dmgMin = ca.damageMin or 1
            local dmgMax = ca.damageMax or 5
            local thresh = ca.threshold or 12
            local defStat = ca.defenseStat or "Hybrid"
            DoF.Sync:BroadcastCombatLog(string_format(
                DoF.L["combat.counterattack"],
                DoF.Utils:Color("FF6666", npcName)))
            -- Показываем диалог защиты (выбор стата или фиксированный)
            if defStat == "Hybrid" then
                DoF.Dialogs:ShowHybridDefenseChoice(npcName, dmgMin, dmgMax, thresh, nil, 0, 0)
            else
                DoF.Dialogs:ShowNPCAttackAlert(npcName, defStat, dmgMin, dmgMax, thresh, nil, 0, 0)
            end
            return
        end
    end
end

-- ═══════════════════════════════════════════════════════════
-- ОСОБОЕ ДЕЙСТВИЕ
-- ═══════════════════════════════════════════════════════════

function DoF.Combat:SpecialAction()
    if not RequireRole() then return end

    if not DoF.Utils:RequireTurn(DoF.L["combat.action.special"]) then return end

    -- Проверка активных AoE/особых режимов
    if self.AoEState.active or self.AoEHealState.active or self.AoEBuffState.active or self.AoEShieldState.active then
        DoF.Utils:Error(DoF.L["errors.finish_current_aoe"])
        return
    end
    if self.SpecialActionState.active then
        DoF.Utils:Error(DoF.L["errors.special_in_progress"])
        return
    end

    -- Проверка не было ли уже отклонено в этом раунде
    local playerName = UnitName("player")
    local currentRound = DoF.TurnSystem and DoF.TurnSystem.round or 0
    if self.RejectedSpecialActions[playerName] == currentRound then
        DoF.Utils:Error(DoF.L["errors.special_rejected_this_round"])
        return
    end

    -- Проверка кулдауна особого действия
    if DoF.Effects then
        local cd = DoF.Effects:Get("player", playerName, "cooldown_special_action")
        if cd then
            local remaining = cd.remainingRounds or 0
            DoF.Utils:Error(DoF.Locale:Format("errors.special_cooldown", remaining))
            return
        end
    end

    -- Энергия проверяется мастером через чекбокс "Запросить энергию"

    -- Показываем диалог запроса
    DoF.Dialogs:ShowSpecialActionRequestDialog()
end

-- Обработка броска особого действия после одобрения мастера
function DoF.Combat:ProcessSpecialActionRoll(threshold, stat, description, requireEnergy, energyAmount, actionType, actionParams, noRoll)
    actionType = actionType or "simple_roll"
    actionParams = actionParams or ""
    local playerName = UnitName("player")

    -- Тратим энергию только если мастер запросил
    if requireEnergy then
        local energyCost = energyAmount or DoF.Config.ENERGY_COST_SPECIAL
        local success = DoF.Stats:SpendEnergy(energyCost)
        if not success then
            DoF.Utils:Error(DoF.Locale:Format("errors.not_enough_energy_need", energyCost))
            return
        end
    end

    local isSuccess = false

    if noRoll then
        -- Автоуспех без броска
        local actionTypeName = DoF.Config.SpecialActionTypes[actionType] or actionType
        local line = string.format(DoF.L["combat.special_performs"],
            playerName, description, DoF.Utils:Color("FFD700", actionTypeName),
            DoF.Utils:Color("00FF00", DoF.L["combat.special_approved_by_gm"]))
        DoF.Sync:BroadcastCombatLog(line)
        isSuccess = true
    else
        -- Получаем модификатор характеристики
        local modifier = DoF.Stats:GetTotal(stat)

        -- Бросок d20
        local roll = DoF.Utils:Roll(1, 20)
        local total = roll + modifier

        -- Используем названия и цвета из конфига
        local statName = DoF.Config.StatNames[stat] or stat
        local statColor = DoF.Config.StatColors[stat] or "FFFFFF"

        -- Крит провал (1)
        if roll == 1 then
            local line = string.format(DoF.L["combat.special_crit_fail_line"],
                playerName, description, DoF.Utils:Color(statColor, statName),
                DoF.Utils:Color("FFFF00", total), roll, modifier,
                DoF.Utils:Color("FF6666", DoF.L["combat.result.crit_fail_excl"]))
            DoF.Sync:BroadcastCombatLog(line)
            isSuccess = false

        -- Проверка успеха
        elseif total >= threshold then
            isSuccess = true
            -- Крит успех (20)
            if roll == 20 then
                DoF.Stats:AddEnergy(DoF.Config.ENERGY_GAIN_CRIT_CHOICE)
                local line = string.format(DoF.L["combat.special_success_line"],
                    playerName, description, DoF.Utils:Color(statColor, statName),
                    DoF.Utils:Color("FFFF00", total), roll, modifier, threshold,
                    DoF.Utils:Color("00FF00", DoF.L["combat.result.crit_success_excl"]))
                DoF.Sync:BroadcastCombatLog(line)
            else
                local line = string.format(DoF.L["combat.special_success_line"],
                    playerName, description, DoF.Utils:Color(statColor, statName),
                    DoF.Utils:Color("FFFF00", total), roll, modifier, threshold,
                    DoF.Utils:Color("00FF00", DoF.L["combat.result.success_excl"]))
                DoF.Sync:BroadcastCombatLog(line)
            end
        else
            -- Неудача
            local line = string.format(DoF.L["combat.special_fail_line"],
                playerName, description, DoF.Utils:Color(statColor, statName),
                DoF.Utils:Color("FFFF00", total), roll, modifier, threshold,
                DoF.Utils:Color("FF6666", DoF.L["combat.result.failure"]))
            DoF.Sync:BroadcastCombatLog(line)
            isSuccess = false
        end
    end

    -- Если провал или простой бросок — завершаем ход сразу
    if not isSuccess or actionType == "simple_roll" then
        -- Накладываем дебафф кулдауна особого действия
        if DoF.Effects then
            DoF.Effects:Apply("player", playerName, "cooldown_special_action", 0, 2, playerName)
        end
        -- Ход переходит к следующему игроку
        if DoF.TurnSystem then
            DoF.TurnSystem:OnActionPerformed()
        end
        return
    end

    -- Успех с расширенным действием — запускаем выбор целей
    self:StartSpecialActionTargetSelect(actionType, actionParams, description)
end

-- ═══════════════════════════════════════════════════════════
-- РАСШИРЕННЫЕ ОСОБЫЕ ДЕЙСТВИЯ: ВЫБОР ЦЕЛЕЙ
-- ═══════════════════════════════════════════════════════════

function DoF.Combat:StartSpecialActionTargetSelect(actionType, actionParams, description)
    local state = self.SpecialActionState
    state.active = true
    state.mode = actionType
    state.selectedTargets = {}
    state.description = description or ""

    if actionType == "buff" then
        local effectId, tc = actionParams:match("([^|]+)|(%d+)")
        if not effectId then
            effectId = actionParams
            tc = 1
        end
        state.effectId = effectId
        state.targetsLeft = tonumber(tc) or 1
        if state.targetsLeft > 1 then
            DoF.Utils:Info(DoF.Locale:Format("combat.choose_n_buff_targets", DoF.Utils:Color("FFD700", state.targetsLeft)))
        else
            DoF.Utils:Info(DoF.L["combat.choose_buff_target"])
        end

    elseif actionType == "aoe_buff" then
        local effectId, tc = actionParams:match("([^|]+)|(%d+)")
        state.effectId = effectId
        state.targetsLeft = tonumber(tc) or 2
        DoF.Utils:Info(DoF.Locale:Format("combat.choose_n_buff_targets", DoF.Utils:Color("FFD700", state.targetsLeft)))

    elseif actionType == "attack" then
        local dmgMin, dmgMax = actionParams:match("(%d+)|(%d+)")
        state.dmgMin = tonumber(dmgMin) or 1
        state.dmgMax = tonumber(dmgMax) or 3
        state.targetsLeft = 1
        DoF.Utils:Info(DoF.L["combat.choose_npc_target"])

    elseif actionType == "aoe_attack" then
        local dmgMin, dmgMax, tc = actionParams:match("(%d+)|(%d+)|(%d+)")
        state.dmgMin = tonumber(dmgMin) or 1
        state.dmgMax = tonumber(dmgMax) or 3
        state.targetsLeft = tonumber(tc) or 2
        DoF.Utils:Info(DoF.Locale:Format("combat.choose_n_npc_targets", DoF.Utils:Color("FFD700", state.targetsLeft)))

    elseif actionType == "wound_removal" then
        state.targetsLeft = 1
        DoF.Utils:Info(DoF.L["combat.choose_wound_target"])

    elseif actionType == "dispel" then
        state.targetsLeft = 1
        DoF.Utils:Info(DoF.L["combat.choose_dispel_target"])

    elseif actionType == "purge" then
        state.targetsLeft = 1
        DoF.Utils:Info(DoF.L["combat.choose_purge_target"])
    end

    -- Показываем панель выбора целей
    if DoF.UI and DoF.UI.ShowSpecialActionPanel then
        DoF.UI:ShowSpecialActionPanel()
    end
end

-- Игрок нажимает кнопку "Применить" на панели особого действия
function DoF.Combat:SpecialActionApplyTarget()
    local state = self.SpecialActionState
    if not state.active then
        DoF.Utils:Error(DoF.L["errors.special_mode_inactive"])
        return
    end

    if state.targetsLeft <= 0 then
        DoF.Utils:Error(DoF.L["errors.all_targets_chosen"])
        return
    end

    local mode = state.mode
    local playerName = UnitName("player")

    -- Действия на игроков: buff, aoe_buff, wound_removal, dispel
    if mode == "buff" or mode == "aoe_buff" or mode == "wound_removal" or mode == "dispel" then
        local targetName = UnitName("target")
        if not targetName then
            DoF.Utils:Error(DoF.L["errors.select_target"])
            return
        end

        -- Цель должна быть игроком
        if not UnitIsPlayer("target") then
            DoF.Utils:Error(DoF.L["errors.target_must_be_player"])
            return
        end

        -- Проверка на повторный выбор
        if state.selectedTargets[targetName] then
            DoF.Utils:Error(DoF.L["errors.target_already_chosen"])
            return
        end

        -- Выполнение действия
        if mode == "buff" or mode == "aoe_buff" then
            local effectId = state.effectId
            if not effectId or not DoF.Effects.Definitions[effectId] then
                DoF.Utils:Error(DoF.L["errors.effect_not_found"])
                self:EndSpecialAction()
                return
            end
            local def = DoF.Effects.Definitions[effectId]
            local value = def.singleTargetValue or def.fixedValue or 2
            if mode == "aoe_buff" then
                value = def.fixedValue or def.singleTargetValue or 2
            end
            local duration = def.fixedDuration or 3
            DoF.Effects:Apply("player", targetName, effectId, value, duration, playerName)
            DoF.Utils:Info(DoF.Locale:Format("combat.buff_applied", DoF.Utils:Color("00FF00", def.name), DoF.Utils:Color("FFFFFF", targetName)))
            if DoF.Sync then
                DoF.Sync:BroadcastCombatLog(DoF.Locale:Format("combat.buff_applied_log", playerName, def.name, targetName))
            end

        elseif mode == "wound_removal" then
            -- Снимаем рану через sync (мастер-функция, но мы skipChecks по сути)
            if DoF.Sync and DoF.Sync.RaidData and DoF.Sync.RaidData[targetName] then
                local wounds = DoF.Sync.RaidData[targetName].wounds or 0
                if wounds <= 0 then
                    DoF.Utils:Warn(DoF.Locale:Format("combat.no_wounds_target", targetName))
                    return
                end
                -- Критическое ранение может снять только мастер
                if wounds >= DoF.Config.MAX_WOUNDS then
                    DoF.Utils:Error(DoF.L["errors.critical_wound_gm_only"])
                    return
                end
            end
            -- Если цель — мы сами
            if targetName == playerName then
                DoF.Stats:RemoveWound()
            end
            -- Синхронизируем через команду
            if DoF.Sync then
                DoF.Sync:Send("REMOVEWOUND", targetName)
                if DoF.Sync.RaidData[targetName] then
                    DoF.Sync.RaidData[targetName].wounds = math.max(0, (DoF.Sync.RaidData[targetName].wounds or 0) - 1)
                    DoF.Events:Fire("PLAYER_DATA_RECEIVED", targetName, DoF.Sync.RaidData[targetName])
                end
            end
            DoF.Utils:Info(DoF.Locale:Format("combat.wound_removed_from", DoF.Utils:Color("FFFFFF", targetName)))
            if DoF.Sync then
                DoF.Sync:BroadcastCombatLog(DoF.Locale:Format("combat.wound_removed_log", playerName, targetName))
            end

        elseif mode == "dispel" then
            local result = DoF.Effects:Dispel(targetName, nil, true) -- skipChecks = true
            if not result then return end -- Нет дебаффов — не считаем как трату цели
        end

        state.selectedTargets[targetName] = true

    -- Действия на NPC: attack, aoe_attack, purge
    elseif mode == "attack" or mode == "aoe_attack" then
        local guid, name = DoF.Utils:GetTargetGUID()
        if not guid then
            DoF.Utils:Error(DoF.L["errors.select_npc_target"])
            return
        end
        if DoF.Utils:IsTargetPlayer() then
            DoF.Utils:Error(DoF.L["errors.cannot_attack_players"])
            return
        end
        if state.selectedTargets[guid] then
            DoF.Utils:Error(DoF.L["errors.target_already_attacked"])
            return
        end
        local data = DoF.Units:Get(guid)
        if not data then
            DoF.Utils:Error(DoF.L["errors.target_hp_not_set"])
            return
        end
        if data.hp <= 0 then
            DoF.Utils:Error(DoF.L["errors.target_dead"])
            return
        end

        local damage = math.random(state.dmgMin, state.dmgMax)
        DoF.Units:Damage(guid, damage)

        local line = string.format(DoF.L["combat.special_damage_log"],
            playerName, name, DoF.Utils:Color("FF6666", damage))
        DoF.Sync:BroadcastCombatLog(line)

        DoF.Utils:Warn(DoF.Locale:Format("combat.takes_damage", name,
            DoF.Utils:Color("FF0000", damage),
            DoF.Utils:Color("FF0000", data.hp .. "/" .. data.maxHp)))

        if data.hp <= 0 then
            DoF.Utils:Print("FF0000", DoF.Locale:Format("combat.target_dead_msg", name))
        end

        state.selectedTargets[guid] = true

    elseif mode == "purge" then
        local guid, name = DoF.Utils:GetTargetGUID()
        if not guid then
            DoF.Utils:Error(DoF.L["errors.select_npc_target"])
            return
        end
        if DoF.Utils:IsTargetPlayer() then
            DoF.Utils:Error(DoF.L["errors.purge_npc_only"])
            return
        end
        local result = DoF.Effects:Purge("npc", guid, true) -- skipChecks = true
        if not result then return end -- Нет баффов — не считаем как трату цели
        if DoF.Sync then
            DoF.Sync:BroadcastCombatLog(DoF.Locale:Format("combat.purge_log", playerName, name))
        end
        state.selectedTargets[guid] = true
    end

    state.targetsLeft = state.targetsLeft - 1
    DoF.Utils:Info(DoF.Locale:Format("combat.targets_left", DoF.Utils:Color("FFD700", state.targetsLeft)))

    -- Обновляем панель
    if DoF.UI and DoF.UI.UpdateSpecialActionPanel then
        DoF.UI:UpdateSpecialActionPanel()
    end

    -- Все цели выбраны — завершаем
    if state.targetsLeft <= 0 then
        self:EndSpecialAction()
    end
end

function DoF.Combat:EndSpecialAction()
    local state = self.SpecialActionState
    if not state.active then return end

    local usedTargets = 0
    for _ in pairs(state.selectedTargets) do
        usedTargets = usedTargets + 1
    end

    local actionTypeName = DoF.Config.SpecialActionTypes[state.mode] or state.mode
    DoF.Utils:Info(DoF.Locale:Format("combat.special_done", actionTypeName, DoF.Utils:Color("FFD700", usedTargets)))

    -- Сбрасываем состояние
    state.active = false
    state.mode = nil
    state.effectId = nil
    state.dmgMin = nil
    state.dmgMax = nil
    state.targetsLeft = 0
    state.selectedTargets = {}
    state.description = ""

    -- Скрываем панель
    if DoF.UI and DoF.UI.HideSpecialActionPanel then
        DoF.UI:HideSpecialActionPanel()
    end

    -- Накладываем кулдаун
    local playerName = UnitName("player")
    if DoF.Effects then
        DoF.Effects:Apply("player", playerName, "cooldown_special_action", 0, 2, playerName)
    end

    -- Ход переходит к следующему
    if DoF.TurnSystem then
        DoF.TurnSystem:OnActionPerformed()
    end
end

function DoF.Combat:CancelSpecialAction()
    if not self.SpecialActionState.active then return end
    DoF.Utils:Warn(DoF.L["combat.special_cancelled"])
    self:EndSpecialAction()
end

function DoF.Combat:IsSpecialActionActive()
    return self.SpecialActionState.active
end

function DoF.Combat:GetSpecialActionTargetsLeft()
    return self.SpecialActionState.targetsLeft
end

function DoF.Combat:GetSpecialActionMode()
    return self.SpecialActionState.mode
end

-- ═══════════════════════════════════════════════════════════
-- ИСЦЕЛЕНИЕ
-- ═══════════════════════════════════════════════════════════

function DoF.Combat:Heal()
    if not RequireRole() then return end

    -- Проверка AoE режима
    if self:IsAoEActive() then
        DoF.Utils:Error(DoF.L["errors.finish_aoe_first"])
        return
    end
    
    if self:IsAoEHealActive() then
        DoF.Utils:Error(DoF.L["errors.finish_aoe_heal"])
        return
    end
    
    if self:IsAoEBuffActive() then
        DoF.Utils:Error(DoF.L["errors.finish_aoe_buff"])
        return
    end

    if self:IsTauntAoEActive() then
        DoF.Utils:Error(DoF.L["errors.finish_aoe_taunt"])
        return
    end

    if not DoF.Utils:RequireTurn(DoF.L["combat.action.heal"]) then return end

    local guid, name = DoF.Utils:GetTargetGUID()
    local isPlayer
    if not guid then
        -- Нет цели — лечим себя
        guid = UnitGUID("player")
        name = UnitName("player")
        isPlayer = true
    else
        isPlayer = DoF.Utils:IsTargetPlayer()
    end
    local data = DoF.Units:Get(guid)

    if not isPlayer and not data then
        DoF.Utils:Error(DoF.L["errors.target_hp_not_set"])
        return
    end
    
    -- Бросок исцеления с проверкой порога усталости
    local modifier = DoF.Stats:GetTotal("Spirit")
    local roll = DoF.Utils:Roll(1, 20)
    local total = roll + modifier

    -- Порог усталости лечения (читаем стаки из системы эффектов)
    local playerName = UnitName("player")
    local fatigueStacks = 0
    if DoF.Effects then
        local fatigueEffect = DoF.Effects:Get("player", playerName, "healing_fatigue")
        if fatigueEffect then
            fatigueStacks = fatigueEffect.stacks or 0
        end
    end
    local fatigueThreshold = fatigueStacks * DoF.Config.HEALING_FATIGUE_THRESHOLD_PER_STACK

    local heal = 0
    local resultText = ""
    local isSuccess = false
    local isCrit = false
    local floatType = "miss"
    local removeWound = false

    if roll == 1 then
        isSuccess = false
        resultText = DoF.L["combat.result.crit_fail"]
        floatType = "crit_fail"

    elseif roll == 20 then
        -- Крит обходит порог усталости
        isSuccess = true
        isCrit = true
        heal = self:CalculateHealing(true)
        resultText = DoF.L["combat.result.crit_success"]
        floatType = "crit_heal"

        -- Хилер при крите снимает ранение
        if DoF.Stats:GetRole() == "healer" then
            removeWound = true
        end
    else
        -- Проверка порога усталости лечения
        if fatigueThreshold > 0 then
            isSuccess = self:IsSuccess(total, fatigueThreshold)
            if isSuccess then
                heal = self:CalculateHealing(false)
                resultText = DoF.L["combat.result.success"]
                floatType = "heal"
            else
                resultText = DoF.L["combat.result.fail_fatigue"]
                floatType = "miss"
            end
        else
            isSuccess = true
            heal = self:CalculateHealing(false)
            resultText = DoF.L["combat.result.success"]
            floatType = "heal"
        end
    end

    -- Форматируем вывод
    local statColor = DoF.Config.StatColors["Spirit"] or "FFFFFF"
    local resultColor = isSuccess and "00FF00" or "FF6666"
    local line1 = string_format(DoF.L["combat.heals"],
        playerName,
        name,
        DoF.Utils:Color(statColor, DoF.Config.StatNames["Spirit"] or "Spirit"))
    local line2
    if fatigueThreshold > 0 then
        local compareSign = isSuccess and ">=" or "<"
        line2 = string_format(DoF.L["combat.roll_short"],
            DoF.Utils:Color("FFFF00", total),
            roll, modifier,
            compareSign, fatigueThreshold,
            DoF.Utils:Color(resultColor, resultText))
    else
        line2 = string_format(DoF.L["combat.roll_short_no_threshold"],
            DoF.Utils:Color("FFFF00", total),
            roll, modifier,
            DoF.Utils:Color(resultColor, resultText))
    end
    
    -- Добавляем информацию об исцелении
    if heal > 0 then
        line2 = line2 .. DoF.Locale:Format("combat.heal_suffix", DoF.Utils:Color("66FF66", heal))
    end
    
    -- Лог боя (CombatLog:Add сам решает: записать в журнал или вывести в чат)
    DoF.Sync:BroadcastCombatLog(line1 .. " " .. line2)

    -- Всплывающий текст для исцеления
    if DoF.UI and heal > 0 then
        DoF.UI:ShowAttackResult(name, floatType, heal)
    end
    
    -- При крите — показываем меню выбора бонуса
    if isCrit and heal > 0 then
        DoF.Dialogs:ShowHealCritChoiceMenu(function(choice)
            self:ApplyCritHealChoice(choice, heal, name, isPlayer, guid, removeWound)
        end)
        return
    end

    -- Обычный хил — применяем сразу
    if heal > 0 then
        self:ApplyHealToTarget(heal, name, isPlayer, guid, removeWound)
    end

    -- Усталость лечения
    if isSuccess and heal > 0 then
        self:ProcessHealingFatigue(playerName)
    end

    -- Оповещаем пошаговую систему
    if DoF.TurnSystem then
        DoF.TurnSystem:OnActionPerformed()
    end
end

-- ═══════════════════════════════════════════════════════════
-- ВОССТАНОВЛЕНИЕ ЭНЕРГИИ (целитель → игрок)
-- ═══════════════════════════════════════════════════════════

function DoF.Combat:RestoreTargetEnergy()
    local role = DoF.Stats and DoF.Stats:GetRole()
    if role ~= "healer" then
        DoF.Utils:Error(DoF.L["errors.healer_only_energy"])
        return
    end

    -- Проверка AoE режимов
    if self:IsAoEActive() then
        DoF.Utils:Error(DoF.L["errors.finish_aoe_first"])
        return
    end
    if self:IsAoEHealActive() then
        DoF.Utils:Error(DoF.L["errors.finish_aoe_heal"])
        return
    end
    if self:IsAoEBuffActive() then
        DoF.Utils:Error(DoF.L["errors.finish_aoe_buff"])
        return
    end
    if self:IsTauntAoEActive() then
        DoF.Utils:Error(DoF.L["errors.finish_aoe_taunt"])
        return
    end

    if not DoF.Utils:RequireTurn(DoF.L["combat.action.restore_energy"]) then return end

    local guid, name = DoF.Utils:GetTargetGUID()
    if not guid then
        DoF.Utils:Error(DoF.L["errors.no_target"])
        return
    end

    local isPlayer = DoF.Utils:IsTargetPlayer()
    if not isPlayer then
        DoF.Utils:Error(DoF.L["errors.energy_players_only"])
        return
    end

    local targetName = name
    local playerName = UnitName("player")

    if targetName == playerName then
        DoF.Utils:Error(DoF.L["errors.energy_not_self"])
        return
    end

    -- Проверяем и тратим энергию
    if not DoF.Stats:SpendEnergy(1) then
        DoF.Utils:Error(DoF.L["errors.not_enough_energy"])
        return
    end

    -- Отправляем синхронизацию
    DoF.Sync:Send("HEALER_RESTORE_ENERGY", targetName .. ";1")

    -- Лог в боевой журнал
    if DoF.Sync then
        DoF.Sync:BroadcastCombatLog(string.format(DoF.L["combat.energy_restored_log"],
            playerName, targetName))
    end

    -- Оповещаем пошаговую систему
    if DoF.TurnSystem then
        DoF.TurnSystem:OnActionPerformed()
    end
end

-- Применить исцеление к цели
function DoF.Combat:ApplyHealToTarget(heal, targetName, isPlayer, targetGuid, removeWound)
    local playerName = UnitName("player")
    if heal <= 0 then return end

    if isPlayer then
        if targetName == playerName then
            -- Себя
            local maxHP = DoF.Stats:GetMaxHP()
            local currentHP = DoF.Stats:GetCurrentHP()
            local newHP = math.min(maxHP, currentHP + heal)
            DoF.Stats:SetCurrentHP(newHP)
            DoF.Events:Fire("PLAYER_HP_CHANGED", newHP, maxHP)

            DoF.Utils:Info(DoF.Locale:Format("combat.you_healed",
                DoF.Utils:Color("00FF00", heal), newHP, maxHP))

            if removeWound and DoF.Stats:GetWounds() > 0 then
                DoF.Stats:RemoveWound()
            end

            if DoF.Sync then
                DoF.Sync:BroadcastPlayerData()
            end
        else
            -- Другого игрока
            DoF.Sync:Send("HEAL", targetName .. ";" .. heal .. ";" .. (removeWound and "1" or "0"))
            DoF.Utils:Info(DoF.Locale:Format("combat.target_healed_short", targetName, DoF.Utils:Color("00FF00", heal)))
        end
    else
        -- NPC
        local data = DoF.Units:Get(targetGuid)
        if data then
            local newHP = math.min(data.maxHp, data.hp + heal)
            DoF.Units:ModifyHP(targetGuid, newHP)
            DoF.Utils:Info(DoF.Locale:Format("combat.target_healed", targetName,
                DoF.Utils:Color("00FF00", heal), newHP, data.maxHp))
        end
    end
end

-- Усталость лечения
function DoF.Combat:ProcessHealingFatigue(playerName)
    if not self.HealingFatigue[playerName] then
        self.HealingFatigue[playerName] = { count = 0 }
    end
    local fatigue = self.HealingFatigue[playerName]
    fatigue.count = fatigue.count + 1
    if fatigue.count >= DoF.Config.HEALING_FATIGUE_EVERY_N then
        fatigue.count = 0
        local currentStacks = 0
        if DoF.Effects then
            local eff = DoF.Effects:Get("player", playerName, "healing_fatigue")
            if eff then currentStacks = eff.stacks or 0 end
        end
        if currentStacks < DoF.Config.HEALING_FATIGUE_MAX_STACKS then
            local newStacks = currentStacks + 1
            local newThreshold = newStacks * DoF.Config.HEALING_FATIGUE_THRESHOLD_PER_STACK
            DoF.Utils:Warn(DoF.Locale:Format("combat.healing_fatigue", newStacks,
                DoF.Locale:Plural(newStacks, DoF.L["combat.stacks_one"], DoF.L["combat.stacks_few"], DoF.L["combat.stacks_many"]), newThreshold))
            if DoF.Effects then
                DoF.Effects:ApplyInternal("player", playerName, "healing_fatigue", newStacks, 999)
            end
        end
    end
    self:SaveHealingFatigue()
end

-- Наложить щит на цель (для крит-бонуса)
function DoF.Combat:ApplyShieldToTarget(targetName, isPlayer, targetGuid)
    local playerName = UnitName("player")

    if isPlayer then
        if targetName == playerName then
            if DoF.Effects and DoF.Effects:HasEffect("player", playerName, "shield_exhaustion") then
                DoF.Utils:Warn(DoF.Locale:Format("combat.shield_recently_broken_warn", targetName))
                return false
            end
            if not DoF.Stats:HasShield() then
                DoF.Stats:ApplyShield()
                DoF.Events:Fire("PLAYER_SHIELD_CHANGED", 1)
                if DoF.Sync then DoF.Sync:BroadcastPlayerData() end
            else
                DoF.Utils:Warn(DoF.L["combat.shield_already_active"])
                return false
            end
        else
            DoF.Sync:Send("SHIELD", targetName)
        end
    else
        if DoF.Effects and DoF.Effects:HasEffect("npc", targetGuid, "shield_exhaustion") then
            DoF.Utils:Warn(DoF.Locale:Format("combat.shield_recently_broken_warn", targetName))
            return false
        end
        if not DoF.Units:HasShield(targetGuid) then
            DoF.Units:ApplyShield(targetGuid)
        else
            DoF.Utils:Warn(DoF.Locale:Format("combat.shield_already_active_on", targetName))
            return false
        end
    end

    DoF.Sync:BroadcastCombatLog(string_format(
        DoF.L["combat.shield_applied_log"],
        playerName, targetName))
    return true
end

-- Применить выбор крита при исцелении
function DoF.Combat:ApplyCritHealChoice(choice, healAmount, targetName, isPlayer, targetGuid, removeWound)
    local playerName = UnitName("player")

    if choice == "full_heal" then
        -- Полное исцеление цели
        if isPlayer then
            if targetName == playerName then
                local maxHP = DoF.Stats:GetMaxHP()
                DoF.Stats:SetCurrentHP(maxHP)
                DoF.Events:Fire("PLAYER_HP_CHANGED", maxHP, maxHP)
                DoF.Utils:Info(DoF.Locale:Format("combat.full_heal_hp", maxHP, maxHP))
                if removeWound and DoF.Stats:GetWounds() > 0 then
                    DoF.Stats:RemoveWound()
                end
                if DoF.Sync then DoF.Sync:BroadcastPlayerData() end
            else
                DoF.Sync:Send("FULLHEAL", targetName .. ";" .. (removeWound and "1" or "0"))
                DoF.Utils:Info(DoF.Locale:Format("combat.full_heal_target", targetName))
            end
        else
            local data = DoF.Units:Get(targetGuid)
            if data then DoF.Units:ModifyHP(targetGuid, data.maxHp) end
        end
        DoF.Sync:BroadcastCombatLog(string_format(DoF.L["combat.crit_bonus_target"],
            playerName, DoF.Utils:Color("66FF66", DoF.L["combat.bonus_full_heal"]), targetName))

    elseif choice == "energy" then
        -- Энергия уже добавлена в меню; применяем обычный крит-хил
        self:ApplyHealToTarget(healAmount, targetName, isPlayer, targetGuid, removeWound)
        DoF.Sync:BroadcastCombatLog(string_format(DoF.L["combat.crit_bonus"],
            playerName, DoF.Utils:Color("9966FF", DoF.L["combat.bonus_energy"])))

    elseif choice == "shield" then
        -- Щит на цель хила + обычный крит-хил
        self:ApplyShieldToTarget(targetName, isPlayer, targetGuid)
        self:ApplyHealToTarget(healAmount, targetName, isPlayer, targetGuid, removeWound)
        DoF.Sync:BroadcastCombatLog(string_format(DoF.L["combat.crit_bonus"],
            playerName, DoF.Utils:Color("66CCFF", DoF.L["combat.bonus_shield_1"])))
    end

    -- Усталость лечения
    self:ProcessHealingFatigue(playerName)

    -- Завершаем ход
    if DoF.TurnSystem then
        DoF.TurnSystem:OnActionPerformed()
    end
end

-- ═══════════════════════════════════════════════════════════
-- ЩИТ (только для хила)
-- ═══════════════════════════════════════════════════════════

function DoF.Combat:Shield()
    if not RequireRole() then return end

    if not DoF.Utils:RequireTurn(DoF.L["combat.action.shield"]) then return end

    -- Проверка специализации (только целитель)
    local role = DoF.Stats:GetRole()
    if role ~= "healer" then
        DoF.Utils:Error(DoF.L["errors.healer_only_shield"])
        return
    end

    -- Проверка кулдауна
    local playerName = UnitName("player")
    if DoF.Effects then
        local cd = DoF.Effects:Get("player", playerName, "cooldown_shield")
        if cd then
            DoF.Utils:Error(DoF.Locale:Format("errors.shield_cooldown", cd.remainingRounds or "?",
                DoF.Locale:Plural(cd.remainingRounds or 0, DoF.L["ui.turns_one"], DoF.L["ui.turns_few"], DoF.L["ui.turns_many"])))
            return
        end
    end

    local guid, name = DoF.Utils:GetTargetGUID()
    if not guid then
        DoF.Utils:Error(DoF.L["errors.no_target"])
        return
    end

    local isPlayer = DoF.Utils:IsTargetPlayer()
    local applied = false

    if isPlayer then
        if UnitIsUnit("target", "player") then
            -- Себя
            if DoF.Stats:HasShield() then
                DoF.Utils:Warn(DoF.L["combat.shield_already_active"])
                return
            end
            if DoF.Effects and DoF.Effects:HasEffect("player", playerName, "shield_exhaustion") then
                DoF.Utils:Error(DoF.L["errors.shield_recently_broken"])
                return
            end
            DoF.Stats:ApplyShield()
            DoF.Events:Fire("PLAYER_SHIELD_CHANGED", 1)
            if DoF.Sync then
                DoF.Sync:BroadcastPlayerData()
            end
            applied = true
        else
            -- Другого игрока
            DoF.Sync:Send("SHIELD", name)
            DoF.Utils:Info(DoF.Locale:Format("combat.shield_applied_you", name))
            applied = true
        end
    else
        -- NPC
        if DoF.Units:HasShield(guid) then
            DoF.Utils:Warn(DoF.Locale:Format("combat.shield_already_active_on", name))
            return
        end
        if DoF.Effects and DoF.Effects:HasEffect("npc", guid, "shield_exhaustion") then
            DoF.Utils:Error(DoF.Locale:Format("errors.shield_recently_broken_target", name))
            return
        end
        DoF.Units:ApplyShield(guid)
        DoF.Utils:Info(DoF.Locale:Format("combat.shield_applied_you", name))
        applied = true
    end

    if applied then
        -- Лог боя
        local logLine = string.format(DoF.L["combat.shield_applied_log"], playerName, name)
        DoF.Sync:BroadcastCombatLog(logLine)

        -- Кулдаун
        if DoF.Effects then
            DoF.Effects:ApplyInternal("player", playerName, "cooldown_shield", 0, DoF.Config.SHIELD_COOLDOWN_TURNS)
        end

        -- Оповещаем пошаговую систему
        if DoF.TurnSystem then
            DoF.TurnSystem:OnActionPerformed()
        end
    end
end

-- ═══════════════════════════════════════════════════════════
-- СНЯТИЕ РАНЫ (только для хила)
-- ═══════════════════════════════════════════════════════════

function DoF.Combat:RemoveWound()
    if not RequireRole() then return end

    if not DoF.Utils:RequireTurn(DoF.L["combat.action.remove_wound"]) then return end
    
    -- Проверка специализации
    if DoF.Stats:GetRole() ~= "healer" then
        DoF.Utils:Error(DoF.L["errors.healer_only_wound"])
        return
    end
    
    local guid, name = DoF.Utils:GetTargetGUID()
    if not guid then
        DoF.Utils:Error(DoF.L["errors.no_target"])
        return
    end
    
    -- Только для игроков
    if not DoF.Utils:IsTargetPlayer() then
        DoF.Utils:Error(DoF.L["errors.wound_players_only"])
        return
    end
    
    -- Бросок снятия раны
    local modifier = DoF.Stats:GetTotal("Spirit")
    local roll = DoF.Utils:Roll(1, 20)
    local total = roll + modifier
    local threshold = 16
    
    local isSuccess = false
    local resultText = ""
    
    if roll == 1 then
        isSuccess = false
        resultText = DoF.L["combat.result.crit_fail"]

    elseif roll == 20 then
        isSuccess = true
        resultText = DoF.L["combat.result.crit_success"]

    else
        isSuccess = self:IsSuccess(total, threshold)
        resultText = isSuccess and DoF.L["combat.result.success"] or DoF.L["combat.result.fail"]
    end
    
    -- Форматируем вывод
    local playerName = UnitName("player")
    local color = DoF.Config.StatColors["Spirit"]
    
    local line1 = string.format(DoF.L["combat.tries_remove_wound"],
        playerName,
        name)
    
    local compareSign = isSuccess and ">=" or "<"
    local resultColor = isSuccess and "00FF00" or "FF6666"
    
    local line2 = string.format(DoF.L["combat.roll_line"],
        DoF.Utils:Color(color, DoF.L["stats.spirit.label"]),
        DoF.Utils:Color("FFFF00", total),
        roll, modifier,
        compareSign,
        threshold,
        DoF.Utils:Color(resultColor, resultText))
    
    -- Лог боя (CombatLog:Add сам решает: записать в журнал или вывести в чат)
    DoF.Sync:BroadcastCombatLog(line1 .. " " .. line2)

    -- Применяем снятие раны
    if isSuccess then
        if UnitIsUnit("target", "player") then
            -- Себя
            if DoF.Stats:GetWounds() > 0 then
                DoF.Stats:RemoveWound()
                DoF.Utils:Info(DoF.L["combat.wound_removed_success"])
            else
                DoF.Utils:Info(DoF.L["combat.no_wounds_self"])
            end
            
            if DoF.Sync then
                DoF.Sync:BroadcastPlayerData()
            end
        else
            -- Другого игрока
            DoF.Sync:Send("REMOVEWOUND", name)
            DoF.Utils:Info(DoF.Locale:Format("combat.wound_removed_name", name))
        end
    else
        DoF.Utils:Error(DoF.L["errors.wound_remove_failed"])
    end
    
    -- Оповещаем о действии в пошаговом режиме
    if DoF.TurnSystem and DoF.TurnSystem:IsActive() then
        DoF.TurnSystem:OnActionPerformed()
    end
    

end

-- ═══════════════════════════════════════════════════════════
-- ДИСПЕЛ (СНЯТИЕ ДЕБАФФА С СОЮЗНИКА)
-- ═══════════════════════════════════════════════════════════

function DoF.Combat:DispelTarget()
    if not RequireRole() then return end

    if not DoF.Utils:RequireTurn(DoF.L["combat.action.dispel"]) then return end

    -- Проверка специализации
    if DoF.Stats:GetRole() ~= "healer" then
        DoF.Utils:Error(DoF.L["errors.healer_only_dispel"])
        return
    end

    local guid, name = DoF.Utils:GetTargetGUID()
    if not guid then
        DoF.Utils:Error(DoF.L["errors.no_target"])
        return
    end

    -- Только для игроков
    if not DoF.Utils:IsTargetPlayer() then
        DoF.Utils:Error(DoF.L["errors.dispel_players_only"])
        return
    end

    -- Проверяем наличие дебаффов
    local effects = DoF.Effects:GetAll("player", name)
    local hasDebuff = false
    for effectId, _ in pairs(effects) do
        local def = DoF.Effects.Definitions[effectId]
        if def and def.category ~= "system" and (def.type == "debuff" or (def.type == "dot" and def.category == "master")) then
            hasDebuff = true
            break
        end
    end
    if not hasDebuff then
        DoF.Utils:Warn(DoF.L["combat.no_debuffs_to_remove"])
        return
    end

    -- Бросок диспела
    local modifier = DoF.Stats:GetTotal("Spirit")
    local roll = DoF.Utils:Roll(1, 20)
    local total = roll + modifier
    local threshold = 14

    local isSuccess = false
    local resultText = ""

    if roll == 1 then
        isSuccess = false
        resultText = DoF.L["combat.result.crit_fail"]
    elseif roll == 20 then
        isSuccess = true
        resultText = DoF.L["combat.result.crit_success"]
    else
        isSuccess = self:IsSuccess(total, threshold)
        resultText = isSuccess and DoF.L["combat.result.success"] or DoF.L["combat.result.fail"]
    end

    -- Форматируем вывод
    local playerName = UnitName("player")
    local color = DoF.Config.StatColors["Spirit"]

    local line1 = string.format(DoF.L["combat.tries_dispel"],
        playerName, name)

    local compareSign = isSuccess and ">=" or "<"
    local resultColor = isSuccess and "00FF00" or "FF6666"

    local line2 = string.format(DoF.L["combat.roll_line"],
        DoF.Utils:Color(color, DoF.L["stats.spirit.label"]),
        DoF.Utils:Color("FFFF00", total),
        roll, modifier,
        compareSign,
        threshold,
        DoF.Utils:Color(resultColor, resultText))

    DoF.Sync:BroadcastCombatLog(line1 .. " " .. line2)

    -- Применяем диспел
    if isSuccess then
        -- Тратим энергию сразу
        DoF.Stats:SpendEnergy(1)
        -- Даём выбрать конкретный дебафф (persistent — нельзя закрыть случайно)
        DoF.Dialogs:ShowEffectSelectionMenu("player", name, "debuff", function(effectId, def)
            DoF.Effects:Remove("player", name, effectId)
            -- Если снимаем усталость лечения — сбрасываем внутренние стаки
            if effectId == "healing_fatigue" and DoF.Combat.HealingFatigue then
                DoF.Combat.HealingFatigue[name] = nil
            end
            DoF.Sync:BroadcastCombatLog(DoF.Locale:Format("combat.dispel_log", playerName, DoF.Utils:Color("00FF00", def.name), name))
        end, nil, true)
    else
        DoF.Utils:Error(DoF.L["errors.dispel_failed"])
    end

    -- Оповещаем о действии в пошаговом режиме
    if DoF.TurnSystem and DoF.TurnSystem:IsActive() then
        DoF.TurnSystem:OnActionPerformed()
    end
end

-- ═══════════════════════════════════════════════════════════
-- ПУРЖ (СНЯТИЕ БАФФА С НПЦ)
-- ═══════════════════════════════════════════════════════════

function DoF.Combat:PurgeTarget()
    if not RequireRole() then return end

    if not DoF.Utils:RequireTurn(DoF.L["combat.action.purge"]) then return end

    -- Проверка специализации
    if DoF.Stats:GetRole() ~= "healer" then
        DoF.Utils:Error(DoF.L["errors.healer_only_purge"])
        return
    end

    local guid = UnitGUID("target")
    if not guid then
        DoF.Utils:Error(DoF.L["errors.no_target"])
        return
    end

    -- Только для НПЦ
    local npcData = DoF.Units:Get(guid)
    if not npcData then
        DoF.Utils:Error(DoF.L["errors.purge_npc_only_strict"])
        return
    end

    -- Проверяем наличие баффов или пассивок для снятия
    local effects = DoF.Effects:GetAll("npc", guid)
    local hasBuff = false
    for effectId, _ in pairs(effects) do
        local def = DoF.Effects.Definitions[effectId]
        if def and def.type == "buff" then
            hasBuff = true
            break
        end
    end
    if not hasBuff and npcData.passives then
        for _, passiveCfg in pairs(npcData.passives) do
            if not passiveCfg.unpurgeable then
                hasBuff = true
                break
            end
        end
    end
    if not hasBuff then
        DoF.Utils:Warn(DoF.L["combat.no_buffs_to_remove"])
        return
    end

    if not DoF.Utils:RequireEnergy(1, DoF.L["combat.action.purge"]) then return end

    -- Бросок пурджа
    local modifier = DoF.Stats:GetTotal("Spirit")
    local roll = DoF.Utils:Roll(1, 20)
    local total = roll + modifier
    local threshold = 14
    local npcName = npcData.name or DoF.L["combat.npc_fallback"]

    local isSuccess = false
    local resultText = ""

    if roll == 1 then
        isSuccess = false
        resultText = DoF.L["combat.result.crit_fail"]
    elseif roll == 20 then
        isSuccess = true
        resultText = DoF.L["combat.result.crit_success"]
    else
        isSuccess = self:IsSuccess(total, threshold)
        resultText = isSuccess and DoF.L["combat.result.success"] or DoF.L["combat.result.fail"]
    end

    -- Форматируем вывод
    local playerName = UnitName("player")
    local color = DoF.Config.StatColors["Spirit"]

    local line1 = string.format(DoF.L["combat.tries_purge"],
        playerName, npcName)

    local compareSign = isSuccess and ">=" or "<"
    local resultColor = isSuccess and "00FF00" or "FF6666"

    local line2 = string.format(DoF.L["combat.roll_line"],
        DoF.Utils:Color(color, DoF.L["stats.spirit.label"]),
        DoF.Utils:Color("FFFF00", total),
        roll, modifier,
        compareSign,
        threshold,
        DoF.Utils:Color(resultColor, resultText))

    DoF.Sync:BroadcastCombatLog(line1 .. " " .. line2)

    -- Применяем пурж
    if isSuccess then
        DoF.Stats:SpendEnergy(1)
        -- Даём выбрать конкретный бафф
        DoF.Dialogs:ShowEffectSelectionMenu("npc", guid, "buff", function(effectId, def, isPassive)
            if isPassive then
                DoF.Passives:Remove(guid, effectId)
                if DoF.Sync then DoF.Sync:BroadcastUnit(guid, DoF.Units:Get(guid)) end
                DoF.Sync:BroadcastCombatLog(DoF.Locale:Format("combat.purge_passive_log", playerName, DoF.Utils:Color("FF8800", def.name), npcName))
            else
                DoF.Effects:Remove("npc", guid, effectId)
                DoF.Sync:BroadcastCombatLog(DoF.Locale:Format("combat.dispel_log", playerName, DoF.Utils:Color("00FF00", def.name), npcName))
            end
        end, nil, true)
    else
        DoF.Utils:Error(DoF.L["errors.purge_failed"])
    end

    -- Оповещаем о действии в пошаговом режиме
    if DoF.TurnSystem and DoF.TurnSystem:IsActive() then
        DoF.TurnSystem:OnActionPerformed()
    end
end

-- ═══════════════════════════════════════════════════════════
-- ПРОВЕРКА ХАРАКТЕРИСТИКИ
-- ═══════════════════════════════════════════════════════════

function DoF.Combat:Check(stat)
    -- Блокируем при ожидании выбора крит-бонуса
    if self.CritChoicePending then
        DoF.Utils:Error(DoF.L["errors.choose_crit_bonus_first"])
        return
    end
    -- Проверки доступны всегда (не тратят ход)
    local modifier = DoF.Stats:GetTotal(stat)
    local roll = DoF.Utils:Roll(1, 20)
    local total = roll + modifier
    
    local color = DoF.Config.StatColors[stat] or "FFFFFF"
    local playerName = UnitName("player")
    
    local line1 = string.format(DoF.L["combat.check_line"],
        playerName,
        DoF.Utils:Color(color, DoF.Config.StatNames[stat]))
    
    local line2 = string.format(DoF.L["combat.roll_result_simple"],
        DoF.Utils:Color("FFFF00", total),
        roll, modifier)
    
    DoF.Sync:BroadcastCombatLog(line1 .. " " .. line2)
end

-- Защита, контратака, мастер-команды вынесены в Combat/Defense.lua
