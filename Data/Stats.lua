-- DoF/Data/Stats.lua
-- Управление характеристиками игрока, уровнем, ролью

local ADDON_NAME, DoF = ...

-- Кэширование глобальных функций
local pairs = pairs
local ipairs = ipairs
local tonumber = tonumber
local math_max = math.max
local math_min = math.min
local math_floor = math.floor
local string_format = string.format
local UnitName = UnitName
local IsInGroup = IsInGroup
local UnitIsGroupLeader = UnitIsGroupLeader

DoF.Stats = {}

-- ═══════════════════════════════════════════════════════════
-- ИНИЦИАЛИЗАЦИЯ
-- ═══════════════════════════════════════════════════════════

function DoF.Stats:Init()
    -- Игровой уровень аддон не слушает: своя шкала живёт в db.char.level

    -- Миграция: старая 3-уровневая система ран → новая 2-уровневая (v1.2)
    if DoF.db.char.wounds and DoF.db.char.wounds > DoF.Config.MAX_WOUNDS then
        DoF.db.char.wounds = DoF.Config.MAX_WOUNDS
    end

    -- Проверяем что текущее HP не больше максимума
    local currentHP = self:GetCurrentHP()
    local maxHP = self:GetMaxHP()
    if currentHP > maxHP then
        self:SetCurrentHP(maxHP)
    end

    -- Проверяем что текущая энергия не больше максимума
    local currentEnergy = self:GetEnergy()
    local maxEnergy = self:GetMaxEnergy()
    if currentEnergy > maxEnergy then
        self:SetEnergy(maxEnergy)
    end
end

-- ═══════════════════════════════════════════════════════════
-- УРОВЕНЬ (собственный, 1-20)
-- ═══════════════════════════════════════════════════════════
--
-- Уровень DoF никак не связан с игровым — сервер зафиксирован на 60, а своя
-- прогрессия живёт в db.char.level. Повышает мастер (SETLEVEL / /dofsetlevel),
-- сам игрок изменить его не может.

function DoF.Stats:GetLevel()
    local level = tonumber(DoF.db.char.level) or DoF.Config.MIN_LEVEL
    -- Клампим на чтении: значение лежит в SavedVariables, где его правят
    -- руками, и приходит по сети от мастера с любой версией аддона.
    return math_max(DoF.Config.MIN_LEVEL, math_min(DoF.Config.MAX_LEVEL, math_floor(level)))
end

-- Возвращает true, если уровень действительно изменился.
function DoF.Stats:SetLevel(newLevel)
    newLevel = tonumber(newLevel)
    if not newLevel then return false end
    newLevel = math_max(DoF.Config.MIN_LEVEL, math_min(DoF.Config.MAX_LEVEL, math_floor(newLevel)))

    local oldLevel = self:GetLevel()
    if newLevel == oldLevel then return false end

    DoF.db.char.level = newLevel
    self:OnLevelChanged(newLevel, oldLevel)
    return true
end

-- ═══════════════════════════════════════════════════════════
-- ОБРАБОТКА СМЕНЫ УРОВНЯ
-- ═══════════════════════════════════════════════════════════

-- Уровень выдаёт мастер, поэтому он может и понизиться (в том числе опечаткой
-- в /dofsetlevel). Обрабатываем обе стороны: повышение сообщает о наградах,
-- понижение приводит раскладку статов в соответствие с новым бюджетом.
function DoF.Stats:OnLevelChanged(newLevel, oldLevel)
    if newLevel > oldLevel then
        -- Progression хранит накопительное число очков, поэтому приращение за
        -- скачок через несколько уровней — это разница итогов, а не сумма шагов.
        local pointsGained = DoF.Config:GetPointsForLevel(newLevel) - DoF.Config:GetPointsForLevel(oldLevel)
        if pointsGained > 0 then
            DoF.Utils:Print("FFD700", DoF.Locale:Format("core.stats.points_gained", pointsGained, DoF.Locale:Plural(pointsGained, DoF.L["ui.sidebar.points_one"], DoF.L["ui.sidebar.points_few"], DoF.L["ui.sidebar.points_many"])))
        end

        local hpDiff = DoF.Config:GetBaseHPForLevel(newLevel) - DoF.Config:GetBaseHPForLevel(oldLevel)
        if hpDiff > 0 then
            self:SetCurrentHP(math_min(self:GetCurrentHP() + hpDiff, self:GetMaxHP()))
            DoF.Utils:Info(DoF.Locale:Format("core.stats.hp_gained", hpDiff))
        end

        local energyDiff = DoF.Config:GetMaxEnergyForLevel(newLevel) - DoF.Config:GetMaxEnergyForLevel(oldLevel)
        if energyDiff > 0 then
            DoF.Utils:Info(DoF.Locale:Format("core.stats.energy_gained", energyDiff))
        end

        DoF.Utils:Print("FFD700", DoF.Locale:Format("core.stats.level_up", newLevel))
    else
        DoF.Utils:Warn(DoF.Locale:Format("core.stats.level_down", newLevel))
        self:RecalculatePoints()
    end

    -- В обе стороны: максимумы изменились, текущие значения могли оказаться
    -- выше новых потолков. Оба сеттера клампят сами.
    self:SetCurrentHP(self:GetCurrentHP())
    self:SetEnergy(self:GetEnergy())

    DoF.Events:Fire("PLAYER_LEVEL_CHANGED", newLevel, oldLevel)

    if DoF.CombatLog then
        DoF.CombatLog:Add(DoF.Locale:Format("core.stats.level_reached_log", UnitName("player"), newLevel), UnitName("player"))
    end

    if DoF.Sync then
        DoF.Sync:BroadcastPlayerData()
    end
end

-- Срезает излишек очков, если распределено больше, чем даёт текущий уровень.
-- Раньше уровень мог только расти, и здесь стоял полный ResetStats. Теперь
-- уровень понижает мастер, и терять всю раскладку из-за одной опечатки слишком
-- дорого — снимаем по очку с самого прокачанного стата, сохраняя форму билда.
-- Возвращает количество снятых очков.
function DoF.Stats:TrimStatsToBudget()
    local budget = DoF.Config:GetPointsForLevel(self:GetLevel())
    local used = self:GetUsedPoints()
    local removed = 0

    while used > budget do
        local top, topValue = nil, 0
        for _, stat in ipairs(DoF.Config.AllStats) do
            local value = DoF.db.char.stats[stat] or 0
            if value > topValue then top, topValue = stat, value end
        end
        -- Защита от вечного цикла: если снимать больше не с чего, а бюджет всё
        -- ещё превышен, значит used разъехался с реальными статами.
        if not top then break end

        DoF.db.char.stats[top] = topValue - 1
        used = used - 1
        removed = removed + 1
    end

    return removed
end

-- Пересчёт очков после смены уровня или сброса
function DoF.Stats:RecalculatePoints()
    local removed = self:TrimStatsToBudget()
    if removed > 0 then
        DoF.Utils:Warn(DoF.Locale:Format("core.stats.points_trimmed", removed))
    end
end

-- ═══════════════════════════════════════════════════════════
-- РОЛЬ (бывшая специализация)
-- ═══════════════════════════════════════════════════════════

function DoF.Stats:GetRole()
    return DoF.db.char.role
end

function DoF.Stats:SetRole(role)
    if role and not DoF.Config.Roles[role] then
        DoF.Utils:Error(DoF.Locale:Format("errors.unknown_role", tostring(role)))
        return false
    end
    
    DoF.db.char.role = role

    if role then
        local roleData = DoF.Config.Roles[role]
        DoF.Utils:Print(roleData.color, DoF.Locale:Format("core.stats.role_set", roleData.name))
    else
        DoF.Utils:Info(DoF.L["core.stats.role_reset"])
    end
    
    -- Пересчитываем HP (для танка)
    self:SetCurrentHP(math.min(self:GetCurrentHP(), self:GetMaxHP()))
    
    if DoF.Sync then
        DoF.Sync:BroadcastPlayerData()
    end
    
    DoF.Events:Fire("PLAYER_SPEC_CHANGED", role, nil)
    return true
end

-- Алиасы для совместимости
function DoF.Stats:GetSpecialization()
    return self:GetRole()
end

function DoF.Stats:SetSpecialization(spec)
    return self:SetRole(spec)
end

function DoF.Stats:GetRoleName()
    local role = self:GetRole()
    if not role then return DoF.L["ui.common.none"] end
    return DoF.Config.Roles[role].name
end

function DoF.Stats:GetRoleColor()
    local role = self:GetRole()
    if not role then return "888888" end
    return DoF.Config.Roles[role].color
end

-- Алиасы для совместимости
function DoF.Stats:GetSpecName()
    return self:GetRoleName()
end

function DoF.Stats:GetSpecColor()
    return self:GetRoleColor()
end

function DoF.Stats:CanChooseRole()
    return self:GetLevel() >= DoF.Config.ROLE_REQUIRED_LEVEL
end

function DoF.Stats:CanChooseSpec()
    return self:CanChooseRole()
end

-- ═══════════════════════════════════════════════════════════
-- РАНЕНИЯ
-- ═══════════════════════════════════════════════════════════

function DoF.Stats:GetWounds()
    return DoF.db.char.wounds or 0
end

function DoF.Stats:SetWounds(wounds)
    DoF.db.char.wounds = DoF.Utils:Clamp(wounds, 0, DoF.Config.MAX_WOUNDS)
end

function DoF.Stats:AddWound()
    local wounds = self:GetWounds()
    if wounds >= DoF.Config.MAX_WOUNDS then
        DoF.Utils:Print("FF0000", DoF.L["core.stats.already_critical"])
        return false
    end

    wounds = wounds + 1
    self:SetWounds(wounds)

    local penalty = DoF.Config:GetWoundPenalty(wounds)

    if wounds >= DoF.Config.MAX_WOUNDS then
        -- Критическое ранение: HP=0, игрок без сознания
        self:SetCurrentHP(0)
        DoF.Utils:Print("FF0000", DoF.L["core.stats.critical_wound"])

        DoF.Events:Fire("PLAYER_WOUND_CHANGED", wounds)

        if DoF.Sync then
            DoF.Sync:BroadcastPlayerData()
            -- Уведомить мастера (в группе) — хэндлер CRITICAL_WOUND откроет ShowCriticalWoundMasterDialog
            DoF.Sync:Send("CRITICAL_WOUND", UnitName("player"))
        end

        -- Соло-режим: Sync:Send вне группы не уходит, поэтому локально открываем диалог мастеру у себя
        if not IsInGroup() and DoF.Dialogs and DoF.Dialogs.ShowCriticalWoundMasterDialog then
            DoF.Dialogs:ShowCriticalWoundMasterDialog(UnitName("player"))
        end
    else
        -- Обычное ранение: HP восстанавливается частично (maxHP уже учитывает штраф)
        local restorePct = DoF.Config.WoundHPRestore[wounds] or 0.25
        local restoreLabel = math.floor(restorePct * 100)
        DoF.Utils:Print("FF6666", DoF.Locale:Format("core.stats.wound_received", penalty, restoreLabel))

        local newMaxHP = self:GetMaxHP()
        local restoreHP = math.max(1, math.floor(newMaxHP * restorePct))
        self:SetCurrentHP(restoreHP)

        DoF.Events:Fire("PLAYER_WOUND_CHANGED", wounds)

        if DoF.Sync then
            DoF.Sync:BroadcastPlayerData()
        end
    end

    return true
end

function DoF.Stats:RemoveWound()
    local wounds = self:GetWounds()
    if wounds <= 0 then
        DoF.Utils:Warn(DoF.L["core.stats.no_wounds"])
        return false
    end

    local wasCritical = wounds >= DoF.Config.MAX_WOUNDS
    wounds = wounds - 1
    self:SetWounds(wounds)

    if wasCritical then
        DoF.Utils:Print("66FF66", DoF.Locale:Format("core.stats.critical_wound_healed",
            DoF.Config:GetWoundPenalty(wounds)))
    elseif wounds > 0 then
        DoF.Utils:Print("66FF66", DoF.L["core.stats.wound_healed"])
    else
        DoF.Utils:Print("66FF66", DoF.L["core.stats.all_wounds_healed"])
    end

    -- Событие
    DoF.Events:Fire("PLAYER_WOUND_CHANGED", wounds)

    if DoF.Sync then
        DoF.Sync:BroadcastPlayerData()
    end

    return true
end

function DoF.Stats:GetWoundPenalty()
    return DoF.Config:GetWoundPenalty(self:GetWounds())
end

-- Игрок в критическом состоянии (без сознания): все действия кроме "Проверки" и "Пропуска" заблокированы
function DoF.Stats:IsIncapacitated()
    return (self:GetWounds() or 0) >= DoF.Config.MAX_WOUNDS
end

-- Проверка состояния чужого игрока по RaidData (для TurnSystem и UI других клиентов)
function DoF.Stats:IsPlayerIncapacitated(name)
    if not name then return false end
    if name == UnitName("player") then
        return self:IsIncapacitated()
    end
    if DoF.Sync and DoF.Sync.RaidData and DoF.Sync.RaidData[name] then
        local w = DoF.Sync.RaidData[name].wounds or 0
        return w >= DoF.Config.MAX_WOUNDS
    end
    return false
end

-- ═══════════════════════════════════════════════════════════
-- ЩИТ
-- ═══════════════════════════════════════════════════════════

function DoF.Stats:GetShield()
    return DoF.db.char.shield or 0
end

function DoF.Stats:SetShield(value)
    DoF.db.char.shield = (value > 0) and 1 or 0
end

function DoF.Stats:HasShield()
    return self:GetShield() > 0
end

function DoF.Stats:ApplyShield()
    if self:HasShield() then
        DoF.Utils:Warn(DoF.L["combat.shield_already_active"])
        return false
    end

    -- Проверка дебаффа истощения
    local playerName = UnitName("player")
    if DoF.Effects and DoF.Effects:HasEffect("player", playerName, "shield_exhaustion") then
        DoF.Utils:Error(DoF.L["errors.shield_recently_broken"])
        return false
    end

    self:SetShield(1)

    if DoF.Sync then
        DoF.Sync:BroadcastPlayerData()
    end

    DoF.Events:Fire("PLAYER_SHIELD_CHANGED", 1)
    return true
end

function DoF.Stats:AbsorbDamage(damage)
    local shield = self:GetShield()
    if shield <= 0 then
        return damage, 0  -- Нет щита, весь урон проходит
    end

    -- Бинарный щит: поглощает ВЕСЬ урон от 1 удара
    self:SetShield(0)
    DoF.Utils:Print("66CCFF", DoF.Locale:Format("core.stats.shield_absorbed", damage))
    DoF.Utils:Print("888888", DoF.L["core.stats.shield_broken"])
    DoF.Events:Fire("PLAYER_SHIELD_CHANGED", 0)

    -- Дебафф: нельзя наложить щит 3 хода
    if DoF.Effects then
        local playerName = UnitName("player")
        DoF.Effects:ApplyInternal("player", playerName, "shield_exhaustion", 0, 3)
    end

    return 0, damage
end

-- ═══════════════════════════════════════════════════════════
-- ХАРАКТЕРИСТИКИ
-- ═══════════════════════════════════════════════════════════

function DoF.Stats:Get(stat)
    return DoF.db.char.stats[stat] or 0
end

function DoF.Stats:GetTotal(stat)
    local base = self:Get(stat)
    local wound = self:GetWoundPenalty()

    -- Модификатор от эффектов (баффы/дебаффы на статы)
    local effectMod = 0
    if DoF.Effects then
        local statKey = string.lower(stat)
        effectMod = DoF.Effects:GetModifier("player", UnitName("player"), statKey)
    end

    local total = base + wound + effectMod
    -- Абсолютный потолок с баффами
    total = math.min(total, DoF.Config.MAX_STAT_TOTAL)
    return total
end

function DoF.Stats:GetMaxStat()
    return DoF.Config:GetMaxStat()
end

function DoF.Stats:GetPointsLeft()
    local total = DoF.Config:GetPointsForLevel(self:GetLevel())
    local used = 0
    for _, stat in ipairs(DoF.Config.AllStats) do
        used = used + (DoF.db.char.stats[stat] or 0)
    end
    return math.max(0, total - used)
end

function DoF.Stats:GetTotalPoints()
    return DoF.Config:GetPointsForLevel(self:GetLevel())
end

function DoF.Stats:GetUsedPoints()
    local used = 0
    for _, stat in ipairs(DoF.Config.AllStats) do
        used = used + self:Get(stat)
    end
    return used
end

function DoF.Stats:Set(stat, value)
    DoF.db.char.stats[stat] = value
end

function DoF.Stats:Modify(stat, delta)
    local current = self:Get(stat)
    local newValue = current + delta
    local pointsLeft = self:GetPointsLeft()
    local maxStat = self:GetMaxStat()
    
    -- Проверки
    if delta > 0 and pointsLeft < delta then
        DoF.Utils:Error(DoF.L["errors.not_enough_points"])
        return false
    end
    
    if newValue < 0 then
        DoF.Utils:Error(DoF.L["errors.stat_negative"])
        return false
    end
    
    -- Проверка лимита характеристики
    if newValue > maxStat then
        DoF.Utils:Error(DoF.Locale:Format("errors.stat_max", maxStat))
        return false
    end
    
    -- Применяем изменения
    self:Set(stat, newValue)

    DoF.Events:Fire("PLAYER_STATS_CHANGED")
    
    return true
end

function DoF.Stats:AddPoint(stat)
    return self:Modify(stat, 1)
end

function DoF.Stats:RemovePoint(stat)
    local current = self:Get(stat)
    if current <= 0 then
        DoF.Utils:Error(DoF.L["errors.stat_at_minimum"])
        return false
    end

    self:Set(stat, current - 1)

    DoF.Events:Fire("PLAYER_STATS_CHANGED")

    return true
end

-- ═══════════════════════════════════════════════════════════
-- СТЕЙДЖИНГ ХАРАКТЕРИСТИК (промежуточное распределение)
-- ═══════════════════════════════════════════════════════════

-- Staged хранит дельты: { Strength = 1, Dexterity = -1, ... }
-- Реальные значения не меняются до CommitStaged()
DoF.Stats.Staged = {}
DoF.Stats.StagingActive = false

function DoF.Stats:InitStaged()
    self.Staged = {}
    self.StagingActive = true
end

function DoF.Stats:IsStagingActive()
    return self.StagingActive
end

function DoF.Stats:StagedAdd(stat)
    if not self.StagingActive then
        self:InitStaged()
    end

    local currentBase = self:Get(stat)
    local delta = self.Staged[stat] or 0
    local newValue = currentBase + delta + 1
    local maxStat = self:GetMaxStat()

    if newValue > maxStat then
        DoF.Utils:Error(DoF.Locale:Format("errors.stat_max", maxStat))
        return false
    end

    if self:GetStagedPointsLeft() <= 0 then
        DoF.Utils:Error(DoF.L["errors.not_enough_points"])
        return false
    end

    self.Staged[stat] = delta + 1
    DoF.Events:Fire("PLAYER_STATS_CHANGED")
    return true
end

function DoF.Stats:StagedRemove(stat)
    if not self.StagingActive then
        self:InitStaged()
    end

    local delta = self.Staged[stat] or 0

    if delta <= 0 then
        DoF.Utils:Error(DoF.L["errors.cannot_remove_points"])
        return false
    end

    self.Staged[stat] = delta - 1
    DoF.Events:Fire("PLAYER_STATS_CHANGED")
    return true
end

function DoF.Stats:GetStagedValue(stat)
    local base = self:Get(stat)
    local delta = self.Staged[stat] or 0
    return base + delta
end

function DoF.Stats:GetStagedDelta(stat)
    return self.Staged[stat] or 0
end

function DoF.Stats:GetStagedPointsLeft()
    local pointsLeft = self:GetPointsLeft()
    local totalDelta = 0
    for _, d in pairs(self.Staged) do
        totalDelta = totalDelta + d
    end
    return pointsLeft - totalDelta
end

function DoF.Stats:HasPendingChanges()
    if not self.StagingActive then return false end
    for _, d in pairs(self.Staged) do
        if d ~= 0 then return true end
    end
    return false
end

function DoF.Stats:CommitStaged()
    if not self.StagingActive then return end

    -- Применяем все дельты в db
    local pointsUsed = 0
    for stat, delta in pairs(self.Staged) do
        if delta ~= 0 then
            local current = self:Get(stat)
            self:Set(stat, current + delta)
            pointsUsed = pointsUsed + delta
        end
    end

    -- Очистить staged
    self.Staged = {}
    self.StagingActive = false

    DoF.Events:Fire("PLAYER_STATS_CHANGED")

    -- Синхронизация
    if DoF.Sync then
        DoF.Sync:BroadcastPlayerData()
    end

    DoF.Utils:Info(DoF.L["core.stats.distributed"])
end

function DoF.Stats:CancelStaged()
    self.Staged = {}
    self.StagingActive = false
    DoF.Events:Fire("PLAYER_STATS_CHANGED")
end

-- ═══════════════════════════════════════════════════════════
-- ЗДОРОВЬЕ
-- ═══════════════════════════════════════════════════════════

function DoF.Stats:GetCurrentHP()
    return DoF.db.char.currentHP or 1
end

function DoF.Stats:GetBaseHP()
    return DoF.Config:GetBaseHPForLevel(self:GetLevel())
end

function DoF.Stats:GetMaxHP()
    local baseHP = self:GetBaseHP()
    local role = self:GetRole()
    local wound = self:GetWoundPenalty()
    
    -- Бонус танка: +floor(Стойкость/2)
    local tankBonus = 0
    if role == "tank" then
        local fort = self:GetTotal("Fortitude")
        tankBonus = math.floor(fort / 2)
    end
    
    -- Бонус от баффа HP (Укрепление HP)
    local hpBuff = 0
    if DoF.Effects then
        hpBuff = DoF.Effects:GetHPBuffBonus("player", UnitName("player"))
    end

    return math.max(1, baseHP + tankBonus + wound + hpBuff)
end

function DoF.Stats:SetCurrentHP(value)
    local maxHP = self:GetMaxHP()
    DoF.db.char.currentHP = DoF.Utils:Clamp(value, 0, maxHP)
end

function DoF.Stats:ModifyHP(delta, silent)
    local oldHP = self:GetCurrentHP()
    local maxHP = self:GetMaxHP()

    -- Если получаем урон, сначала щит
    if delta < 0 then
        local damage = math.abs(delta)
        local remaining, absorbed = self:AbsorbDamage(damage)
        delta = -remaining

        if remaining == 0 then
            -- Весь урон поглощён щитом
            DoF.Events:Fire("PLAYER_SHIELD_CHANGED", self:GetShield())
            if DoF.Sync then
                DoF.Sync:BroadcastPlayerData()
            end
            return true
        end
    end

    local newHP = DoF.Utils:Clamp(oldHP + delta, 0, maxHP)

    if newHP == oldHP then
        if not silent then
            DoF.Utils:Warn(DoF.L[delta > 0 and "core.stats.hp_max" or "core.stats.hp_min"])
        end
        return false
    end

    self:SetCurrentHP(newHP)

    -- Сообщение (пропускаем если silent — вызывающий код выведет своё)
    if not silent then
        local color = delta > 0 and "00FF00" or "FF0000"
        local sign = delta > 0 and "+" or ""
        DoF.Utils:Info(DoF.Locale:Format("core.stats.hp_line", DoF.Utils:Color(color, DoF.Locale:Format("core.stats.value_change", newHP, maxHP, sign, delta))))
    end

    -- Событие HP
    DoF.Events:Fire("PLAYER_HP_CHANGED", newHP, maxHP)
    
    -- Проверка смерти -> ранение
    if newHP <= 0 then
        DoF.Events:Fire("PLAYER_DIED")
        self:AddWound()

        -- Танк умер: снять бафф перехвата урона со всех союзников
        if DoF.Effects and self:GetRole() == "tank" then
            local myName = UnitName("player")
            local toRemove = {}
            for pName, effects in pairs(DoF.Effects.PlayerEffects) do
                if effects["tank_redirect"] then
                    local eff = effects["tank_redirect"]
                    if eff.casters and eff.casters[1] == myName then
                        toRemove[#toRemove + 1] = pName
                    end
                end
            end
            for _, pName in ipairs(toRemove) do
                DoF.Effects:Remove("player", pName, "tank_redirect")
            end
        end
    end
    
    -- Синхронизация
    if DoF.Sync then
        DoF.Sync:Send("PLAYERHPCHANGE", string.format("%s;%d;%d;%d", UnitName("player"), oldHP, newHP, maxHP))
        DoF.Sync:BroadcastPlayerData()
    end
    
    -- Лог мастера
    if DoF.Sync and DoF.Sync:IsMaster() and DoF.CombatLog then
        DoF.CombatLog:AddMasterLog(string.format(DoF.L["core.stats.hp_change_log"], 
            UnitName("player"), oldHP, newHP, delta), "hp_change")
    end
    
    return true
end

-- ═══════════════════════════════════════════════════════════
-- СБРОС
-- ═══════════════════════════════════════════════════════════

function DoF.Stats:ResetStats()
    -- Сбрасываем все статы
    for _, stat in ipairs(DoF.Config.AllStats) do
        DoF.db.char.stats[stat] = 0
    end

    -- Восстанавливаем HP
    self:SetCurrentHP(self:GetMaxHP())

    -- Синхронизация
    if DoF.Sync then
        DoF.Sync:BroadcastPlayerData()
    end

    DoF.Events:Fire("PLAYER_STATS_CHANGED")

    DoF.Utils:Info(DoF.L["core.stats.reset"])
end

function DoF.Stats:FullReset()
    -- Полный сброс (роль, ранения, щит)
    DoF.db.char.role = nil
    DoF.db.char.wounds = 0
    DoF.db.char.shield = 0

    self:ResetStats()

    DoF.Utils:Print("FFD700", DoF.L["core.stats.full_reset"])
end

-- ═══════════════════════════════════════════════════════════
-- УТИЛИТЫ
-- ═══════════════════════════════════════════════════════════

function DoF.Stats:PrintStats()
    local level = self:GetLevel()

    print(DoF.L["core.stats.sheet_header"])
    print(DoF.Locale:Format("core.stats.sheet_level", level, DoF.Config.MAX_LEVEL))
    print(DoF.Locale:Format("core.stats.sheet_role", self:GetRoleColor(), self:GetRoleName()))

    local wounds = self:GetWounds()
    if wounds > 0 then
        if wounds >= DoF.Config.MAX_WOUNDS then
            print(DoF.L["core.stats.sheet_critical"])
        else
            print(DoF.Locale:Format("core.stats.sheet_wound", self:GetWoundPenalty()))
        end
    end

    local shield = self:GetShield()
    if shield > 0 then
        print(DoF.Locale:Format("core.stats.sheet_shield", shield))
    end

    print("HP: " .. self:GetCurrentHP() .. "/" .. self:GetMaxHP())
    print(DoF.Locale:Format("core.stats.sheet_energy", self:GetEnergy(), self:GetMaxEnergy()))

    for _, stat in ipairs(DoF.Config.AllStats) do
        local base = self:Get(stat)
        local wound = self:GetWoundPenalty()
        local total = self:GetTotal(stat)

        local suffix = ""
        if wound < 0 then
            suffix = " (|cFFFF6666" .. wound .. "|r)"
        end

        print("  " .. DoF.Config.StatNames[stat] .. ": " .. total .. suffix)
    end

    print(DoF.Locale:Format("core.stats.sheet_points", self:GetPointsLeft(), self:GetTotalPoints()))

    -- Показываем следующий уровень с очком
    local nextPointLevel = DoF.Config:GetNextPointLevel(level)
    if nextPointLevel then
        print(DoF.Locale:Format("core.stats.sheet_next_point", nextPointLevel))
    end
end

-- ═══════════════════════════════════════════════════════════
-- СИСТЕМА ЭНЕРГИИ
-- ═══════════════════════════════════════════════════════════

-- Получить текущую энергию
function DoF.Stats:GetEnergy()
    return DoF.db.char.energy or 0
end

-- Получить максимум энергии
function DoF.Stats:GetMaxEnergy()
    local level = self:GetLevel()
    return DoF.Config:GetMaxEnergyForLevel(level)
end

-- Установить энергию
function DoF.Stats:SetEnergy(value)
    local maxEnergy = self:GetMaxEnergy()
    local newEnergy = math.max(0, math.min(value, maxEnergy))
    DoF.db.char.energy = newEnergy

    -- Событие
    DoF.Events:Fire("PLAYER_ENERGY_CHANGED", newEnergy, maxEnergy)

    -- Синхронизация
    if DoF.Sync then
        DoF.Sync:BroadcastPlayerData()
    end

end

-- Добавить энергию
function DoF.Stats:AddEnergy(amount)
    local current = self:GetEnergy()
    local maxEnergy = self:GetMaxEnergy()
    local newEnergy = math.min(current + amount, maxEnergy)
    self:SetEnergy(newEnergy)
    
    if newEnergy > current then
        DoF.Utils:Info(DoF.Locale:Format("core.stats.energy_gained_amount", newEnergy - current, newEnergy, maxEnergy))
    end
    
    return newEnergy - current  -- Сколько реально добавлено
end

-- Потратить энергию
function DoF.Stats:SpendEnergy(amount)
    local current = self:GetEnergy()
    if current < amount then
        return false, DoF.L["errors.not_enough_energy"]
    end
    
    self:SetEnergy(current - amount)
    return true
end

-- Проверить, достаточно ли энергии
function DoF.Stats:HasEnergy(amount)
    return self:GetEnergy() >= amount
end

-- Восстановить энергию до максимума
function DoF.Stats:RestoreEnergy()
    local maxEnergy = self:GetMaxEnergy()
    self:SetEnergy(maxEnergy)
    DoF.Utils:Info(DoF.Locale:Format("core.stats.energy_restored", maxEnergy, maxEnergy))
end

-- Изменить энергию (аналогично ModifyHP)
function DoF.Stats:ModifyEnergy(delta)
    local oldEnergy = self:GetEnergy()
    local maxEnergy = self:GetMaxEnergy()
    local newEnergy = math.max(0, math.min(oldEnergy + delta, maxEnergy))

    if newEnergy == oldEnergy then
        DoF.Utils:Warn(DoF.L[delta > 0 and "core.stats.energy_max" or "core.stats.energy_min"])
        return false
    end

    self:SetEnergy(newEnergy)

    -- Сообщение
    local color = delta > 0 and "66CCFF" or "FF6666"
    local sign = delta > 0 and "+" or ""
    DoF.Utils:Info(DoF.Locale:Format("core.stats.energy_line", DoF.Utils:Color(color, DoF.Locale:Format("core.stats.value_change", newEnergy, maxEnergy, sign, delta))))

    -- Событие
    DoF.Events:Fire("PLAYER_ENERGY_CHANGED", newEnergy, maxEnergy)

    -- Синхронизация
    if DoF.Sync then
        DoF.Sync:BroadcastPlayerData()
    end

    return true
end

-- Проверить, можно ли восстановить энергию (не в группе/рейде с лидером)
function DoF.Stats:CanRestoreEnergy()
    -- Если не в группе - можно
    if not IsInGroup() then
        return true
    end
    
    -- Если сам лидер - можно
    if UnitIsGroupLeader("player") then
        return true
    end
    
    -- В группе/рейде с другим лидером - нельзя
    return false
end

-- Проверить, можно ли изменять HP (не в группе/рейде с лидером)
function DoF.Stats:CanModifyHP()
    -- Если не в группе - можно
    if not IsInGroup() then
        return true
    end
    
    -- Если сам лидер - можно
    if UnitIsGroupLeader("player") then
        return true
    end
    
    -- В группе/рейде с другим лидером - нельзя
    return false
end

-- Получить наивысшую атакующую характеристику для особого действия
function DoF.Stats:GetHighestAttackStat()
    local stats = DoF.db.char.stats
    return DoF.Config:GetHighestAttackStat(stats)
end

-- ═══════════════════════════════════════════════════════════
-- АЛИАСЫ ДЛЯ XML (вызываются из Frames.xml, не определены в Aliases.lua)
-- ═══════════════════════════════════════════════════════════

function DoF:DistributeStats()
    DoF.Stats:CommitStaged()
end

function DoF:SpendEnergy(amount)
    return DoF.Stats:SpendEnergy(amount)
end

function DoF:AddEnergy(amount)
    return DoF.Stats:AddEnergy(amount)
end
