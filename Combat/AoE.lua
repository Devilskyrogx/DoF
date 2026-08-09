-- DoF/Combat/AoE.lua
-- AoE механики: массовая атака, массовое исцеление, массовый бафф

local ADDON_NAME, DoF = ...

-- Кэширование глобальных функций
local math_max = math.max
local math_floor = math.floor
local math_random = math.random
local UnitName = UnitName
local UnitIsUnit = UnitIsUnit
local string_format = string.format

-- Проверка наличия роли (обязательна для боевых действий)
local function RequireRole()
    if not DoF.Stats:GetRole() then
        DoF.Utils:Error(DoF.L["errors.choose_role"])
        return false
    end
    return true
end

-- ═══════════════════════════════════════════════════════════
-- AoE АТАКА
-- ═══════════════════════════════════════════════════════════

function DoF.Combat:StartAoEAttack(stat)
    if not RequireRole() then return end

    if not DoF.Utils:RequireTurn(DoF.L["combat.action.aoe_attack"]) then return end

    -- Нельзя начать AoE если уже в режиме AoE
    if self.AoEState.active then
        DoF.Utils:Error(DoF.L["errors.aoe_attack_active"])
        return
    end
    if self.AoEHealState.active then
        DoF.Utils:Error(DoF.L["errors.finish_aoe_heal"])
        return
    end
    if self.AoEBuffState.active then
        DoF.Utils:Error(DoF.L["errors.finish_aoe_buff"])
        return
    end
    if self.AoEShieldState.active then
        DoF.Utils:Error(DoF.L["errors.finish_aoe_shield"])
        return
    end
    if self.SpecialActionState.active then
        DoF.Utils:Error(DoF.L["errors.finish_special"])
        return
    end

    -- Проверка кулдауна AoE (общий для атаки и хила)
    local playerName = UnitName("player")
    if DoF.Effects then
        local cd = DoF.Effects:Get("player", playerName, "cooldown_aoe")
        if cd then
            DoF.Utils:Error(DoF.Locale:Format("errors.aoe_cooldown", cd.remainingRounds or "?", DoF.Locale:Rounds(cd.remainingRounds or 0)))
            return
        end
    end

    local energyCost = DoF.Config.ENERGY_COST_AOE
    if not DoF.Utils:RequireEnergy(energyCost, DoF.L["combat.action.aoe_attack"]) then return end

    -- Тратим энергию
    DoF.Stats:SpendEnergy(energyCost)

    -- AoE всегда проходит (без порога), бросок d20 только для крита
    local roll = DoF.Utils:Roll(1, 20)
    local maxTargets = DoF.Config.AOE_MAX_TARGETS
    local targets = math_random(DoF.Config.AOE_MIN_TARGETS, maxTargets)
    local statColor = DoF.Config.StatColors[stat] or "FFFFFF"
    local statName = DoF.Config.StatNames[stat] or stat

    -- Крит (20) — возвращаем энергию
    if roll == 20 then

        local line1 = string_format(DoF.L["combat.aoe.activates"],
            playerName, DoF.Utils:Color(statColor, statName))
        local line2 = string_format(DoF.L["combat.aoe.roll_crit"],
            DoF.Utils:Color("FFFF00", roll),
            DoF.Utils:Color("00FF00", DoF.L["combat.result.crit_success"]),
            DoF.Utils:Color("FFD700", targets))

        DoF.Sync:BroadcastCombatLog(line1 .. " " .. line2)

        -- Возвращаем энергию за крит
        DoF.Stats:AddEnergy(DoF.Config.ENERGY_GAIN_CRIT_CHOICE)
    else
        local line1 = string_format(DoF.L["combat.aoe.activates"],
            playerName, DoF.Utils:Color(statColor, statName))
        local line2 = string_format(DoF.L["combat.aoe.roll_success"],
            DoF.Utils:Color("FFFF00", roll),
            DoF.Utils:Color("00FF00", DoF.L["combat.result.success_excl"]),
            DoF.Utils:Color("FFD700", targets))

        DoF.Sync:BroadcastCombatLog(line1 .. " " .. line2)
    end

    -- Активируем режим AoE
    self.AoEState.active = true
    self.AoEState.stat = stat
    self.AoEState.hitsLeft = targets
    self.AoEState.hitTargets = {}

    DoF.Utils:Info(DoF.Locale:Format("combat.aoe.mode_active", DoF.Utils:Color("FFD700", targets)))

    -- Показываем окно AoE
    if DoF.UI and DoF.UI.ShowAoEPanel then
        DoF.UI:ShowAoEPanel()
    end
end

function DoF.Combat:AoEHit()
    -- Проверка режима AoE
    if not self.AoEState.active then
        DoF.Utils:Error(DoF.L["errors.aoe_mode_inactive"])
        return
    end

    if self.AoEState.hitsLeft <= 0 then
        DoF.Utils:Error(DoF.L["errors.all_hits_used"])
        return
    end

    local guid, name = DoF.Utils:GetTargetGUID()

    if not guid then
        DoF.Utils:Error(DoF.L["errors.select_target"])
        return
    end

    if DoF.Utils:IsTargetPlayer() then
        DoF.Utils:Error(DoF.L["errors.cannot_attack_players"])
        return
    end

    -- Проверка на повторную атаку
    if self.AoEState.hitTargets[guid] then
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

    -- AoE удар автоматически успешен, но бросаем на крит и урон
    local stat = self.AoEState.stat
    local roll = DoF.Utils:Roll(1, 20)
    local isCrit = (roll == 20)

    local damage = self:CalculateDamage(isCrit)

    local playerName = UnitName("player")
    local statColor = DoF.Config.StatColors[stat] or "FFFFFF"
    local statName = DoF.Config.StatNames[stat] or stat

    local resultText = isCrit and DoF.Utils:Color("00FF00", DoF.L["combat.result.crit_short"]) or DoF.Utils:Color("00FF00", DoF.L["combat.result.hit_short"])
    local line = string_format(DoF.L["combat.aoe.attack_log"],
        playerName,
        DoF.Utils:Color(statColor, statName),
        name,
        resultText,
        DoF.Utils:Color("FF6666", damage))

    DoF.Sync:BroadcastCombatLog(line)

    -- Всплывающий текст
    local floatType = isCrit and "crit_success" or "hit"
    if DoF.UI then
        DoF.UI:ShowAttackResult(name, floatType, damage)
    end

    -- Применяем урон (Damage учитывает щит)
    DoF.Units:Damage(guid, damage)

    DoF.Utils:Warn(DoF.Locale:Format("combat.takes_damage", name,
        DoF.Utils:Color("FF0000", damage),
        DoF.Utils:Color("FF0000", data.hp .. "/" .. data.maxHp)))

    if data.hp <= 0 then
        DoF.Utils:Print("FF0000", DoF.Locale:Format("combat.target_dead_msg", name))
    end

    -- Запоминаем цель и уменьшаем счётчик
    self.AoEState.hitTargets[guid] = true
    self.AoEState.hitsLeft = self.AoEState.hitsLeft - 1

    DoF.Utils:Info(DoF.Locale:Format("combat.aoe.hits_left", DoF.Utils:Color("FFD700", self.AoEState.hitsLeft)))

    -- Обновляем панель AoE
    if DoF.UI and DoF.UI.UpdateAoEPanel then
        DoF.UI:UpdateAoEPanel()
    end

    -- Проверяем окончание AoE
    if self.AoEState.hitsLeft <= 0 then
        self:EndAoE()
    end
end

function DoF.Combat:EndAoE()
    if not self.AoEState.active then return end

    local usedHits = 0
    for _ in pairs(self.AoEState.hitTargets) do
        usedHits = usedHits + 1
    end

    DoF.Utils:Info(DoF.Locale:Format("combat.aoe.attack_done", DoF.Utils:Color("FFD700", usedHits)))

    -- Общий кулдаун AoE (только если были поражены цели)
    if usedHits > 0 and DoF.Effects then
        local playerName = UnitName("player")
        DoF.Effects:ApplyInternal("player", playerName, "cooldown_aoe", 0, DoF.Config.AOE_COOLDOWN_ROUNDS)
    end

    -- Сбрасываем состояние
    self.AoEState.active = false
    self.AoEState.stat = nil
    self.AoEState.hitsLeft = 0
    self.AoEState.hitTargets = {}

    -- Скрываем панель AoE
    if DoF.UI and DoF.UI.HideAoEPanel then
        DoF.UI:HideAoEPanel()
    end

    -- Оповещаем пошаговую систему
    if DoF.TurnSystem then
        DoF.TurnSystem:OnActionPerformed()
    end
end

function DoF.Combat:CancelAoE()
    if not self.AoEState.active then return end

    DoF.Utils:Warn(DoF.L["combat.aoe.attack_cancelled"])
    self:EndAoE()
end

function DoF.Combat:IsAoEActive()
    return self.AoEState.active
end

function DoF.Combat:GetAoEHitsLeft()
    return self.AoEState.hitsLeft
end

function DoF.Combat:GetAoEStat()
    return self.AoEState.stat
end

-- ═══════════════════════════════════════════════════════════
-- AoE ИСЦЕЛЕНИЕ (для целителей)
-- ═══════════════════════════════════════════════════════════

function DoF.Combat:StartAoEHeal()
    if not RequireRole() then return end

    if not DoF.Utils:RequireTurn(DoF.L["combat.action.aoe_heal"]) then return end

    -- Нельзя начать AoE хил если уже в режиме AoE
    if self.AoEState.active then
        DoF.Utils:Error(DoF.L["errors.finish_aoe_first"])
        return
    end

    if self.AoEHealState.active then
        DoF.Utils:Error(DoF.L["errors.aoe_heal_active"])
        return
    end

    if self.AoEBuffState.active then
        DoF.Utils:Error(DoF.L["errors.finish_aoe_buff"])
        return
    end

    if self.AoEShieldState.active then
        DoF.Utils:Error(DoF.L["errors.finish_aoe_shield"])
        return
    end
    if self.SpecialActionState.active then
        DoF.Utils:Error(DoF.L["errors.finish_special"])
        return
    end

    -- Проверка кулдауна AoE (общий для атаки и хила)
    local playerName = UnitName("player")
    if DoF.Effects then
        local cd = DoF.Effects:Get("player", playerName, "cooldown_aoe")
        if cd then
            DoF.Utils:Error(DoF.Locale:Format("errors.aoe_cooldown", cd.remainingRounds or "?", DoF.Locale:Rounds(cd.remainingRounds or 0)))
            return
        end
    end

    local energyCost = DoF.Config.ENERGY_COST_AOE
    if not DoF.Utils:RequireEnergy(energyCost, DoF.L["combat.action.aoe_heal"]) then return end

    -- Тратим энергию
    DoF.Stats:SpendEnergy(energyCost)

    -- AoE хил всегда проходит (без порога), бросок d20 только для крита
    local roll = DoF.Utils:Roll(1, 20)
    local maxTargets = DoF.Config.AOE_MAX_TARGETS
    local targets = math_random(DoF.Config.AOE_MIN_TARGETS, maxTargets)

    -- Крит (20) — возвращаем энергию
    if roll == 20 then

        local line1 = string_format(DoF.L["combat.aoe.activates_heal"],
            playerName)
        local line2 = string_format(DoF.L["combat.aoe.roll_crit"],
            DoF.Utils:Color("FFFF00", roll),
            DoF.Utils:Color("00FF00", DoF.L["combat.result.crit_success"]),
            DoF.Utils:Color("FFD700", targets))

        DoF.Sync:BroadcastCombatLog(line1 .. " " .. line2)

        -- Возвращаем энергию за крит
        DoF.Stats:AddEnergy(DoF.Config.ENERGY_GAIN_CRIT_CHOICE)
    else
        local line1 = string_format(DoF.L["combat.aoe.activates_heal"],
            playerName)
        local line2 = string_format(DoF.L["combat.aoe.roll_success"],
            DoF.Utils:Color("FFFF00", roll),
            DoF.Utils:Color("00FF00", DoF.L["combat.result.success_excl"]),
            DoF.Utils:Color("FFD700", targets))

        DoF.Sync:BroadcastCombatLog(line1 .. " " .. line2)
    end

    -- Активируем режим AoE хила
    self.AoEHealState.active = true
    self.AoEHealState.healsLeft = targets
    self.AoEHealState.healedTargets = {}

    DoF.Utils:Info(DoF.Locale:Format("combat.aoe.heal_active", DoF.Utils:Color("FFD700", targets)))

    -- Показываем панель AoE хила
    if DoF.UI and DoF.UI.ShowAoEHealPanel then
        DoF.UI:ShowAoEHealPanel()
    end
end

function DoF.Combat:AoEHealTarget()
    if not self.AoEHealState.active then
        DoF.Utils:Error(DoF.L["errors.aoe_heal_inactive"])
        return
    end

    if self.AoEHealState.healsLeft <= 0 then
        DoF.Utils:Error(DoF.L["errors.all_heals_used"])
        return
    end

    local guid, name = DoF.Utils:GetTargetGUID()

    if not guid then
        DoF.Utils:Error(DoF.L["errors.select_target"])
        return
    end

    local isPlayer = DoF.Utils:IsTargetPlayer()
    local data = DoF.Units:Get(guid)

    if not isPlayer and not data then
        DoF.Utils:Error(DoF.L["errors.target_hp_not_set"])
        return
    end

    -- Проверка на повторное исцеление (по GUID для корректности NPC)
    if self.AoEHealState.healedTargets[guid] then
        DoF.Utils:Error(DoF.L["errors.target_already_healed"])
        return
    end

    -- AoE хил автоматически успешен, бросаем на крит и количество
    local roll = DoF.Utils:Roll(1, 20)
    local isCrit = (roll == 20)

    local heal = self:CalculateHealing(isCrit)
    local removeWound = false

    -- Хилер при крите снимает ранение
    if isCrit and DoF.Stats:GetRole() == "healer" then
        removeWound = true
    end

    local playerName = UnitName("player")
    local statColor = DoF.Config.StatColors["Spirit"] or "FFE066"

    local resultText = isCrit and DoF.Utils:Color("00FF00", DoF.L["combat.result.crit_short"]) or DoF.Utils:Color("00FF00", DoF.L["combat.result.success_excl"])
    local line = string_format(DoF.L["combat.aoe.heal_log"],
        playerName, name, resultText,
        DoF.Utils:Color("66FF66", heal))

    DoF.Sync:BroadcastCombatLog(line)

    -- Всплывающий текст
    local floatType = isCrit and "crit_heal" or "heal"
    if DoF.UI then
        DoF.UI:ShowAttackResult(name, floatType, heal)
    end

    -- Применяем исцеление
    if isPlayer then
        if UnitIsUnit("target", "player") then
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
            DoF.Sync:Send("HEAL", name .. ";" .. heal .. ";" .. (removeWound and "1" or "0"))
            DoF.Utils:Info(DoF.Locale:Format("combat.target_healed_short", name, DoF.Utils:Color("00FF00", heal)))
        end
    else
        -- NPC
        local newHP = math.min(data.maxHp, data.hp + heal)
        DoF.Units:ModifyHP(guid, newHP)
        DoF.Utils:Info(DoF.Locale:Format("combat.target_healed", name,
            DoF.Utils:Color("00FF00", heal), newHP, data.maxHp))
    end

    -- Запоминаем цель и уменьшаем счётчик
    self.AoEHealState.healedTargets[guid] = true
    self.AoEHealState.healsLeft = self.AoEHealState.healsLeft - 1

    DoF.Utils:Info(DoF.Locale:Format("combat.aoe.heals_left", DoF.Utils:Color("FFD700", self.AoEHealState.healsLeft)))

    -- Обновляем панель
    if DoF.UI and DoF.UI.UpdateAoEHealPanel then
        DoF.UI:UpdateAoEHealPanel()
    end

    -- Проверяем окончание AoE хила
    if self.AoEHealState.healsLeft <= 0 then
        self:EndAoEHeal()
    end
end

function DoF.Combat:EndAoEHeal()
    if not self.AoEHealState.active then return end

    local healed = 0
    for _ in pairs(self.AoEHealState.healedTargets) do
        healed = healed + 1
    end

    DoF.Utils:Info(DoF.Locale:Format("combat.aoe.heal_done", DoF.Utils:Color("FFD700", healed)))

    -- Общий кулдаун AoE (только если были исцелены цели)
    if healed > 0 and DoF.Effects then
        local playerName = UnitName("player")
        DoF.Effects:ApplyInternal("player", playerName, "cooldown_aoe", 0, DoF.Config.AOE_COOLDOWN_ROUNDS)
    end

    -- Усталость лечения: AoE хил = ОДНО исцеление для счётчика
    if healed > 0 then
        local healerName = UnitName("player")
        if not self.HealingFatigue[healerName] then
            self.HealingFatigue[healerName] = { count = 0 }
        end
        local fatigue = self.HealingFatigue[healerName]
        fatigue.count = fatigue.count + 1
        if fatigue.count >= DoF.Config.HEALING_FATIGUE_EVERY_N then
            fatigue.count = 0
            local currentStacks = 0
            if DoF.Effects then
                local eff = DoF.Effects:Get("player", healerName, "healing_fatigue")
                if eff then currentStacks = eff.stacks or 0 end
            end
            if currentStacks < DoF.Config.HEALING_FATIGUE_MAX_STACKS then
                local newStacks = currentStacks + 1
                local newThreshold = newStacks * DoF.Config.HEALING_FATIGUE_THRESHOLD_PER_STACK
                DoF.Utils:Warn(DoF.Locale:Format("combat.healing_fatigue", newStacks, DoF.Locale:Plural(newStacks, DoF.L["combat.stacks_one"], DoF.L["combat.stacks_few"], DoF.L["combat.stacks_many"]), newThreshold))
                if DoF.Effects then
                    DoF.Effects:ApplyInternal("player", healerName, "healing_fatigue", newStacks, 999)
                end
            end
        end
        self:SaveHealingFatigue()
    end

    -- Сбрасываем состояние
    self.AoEHealState.active = false
    self.AoEHealState.healsLeft = 0
    self.AoEHealState.healedTargets = {}

    -- Скрываем панель
    if DoF.UI and DoF.UI.HideAoEHealPanel then
        DoF.UI:HideAoEHealPanel()
    end

    -- Оповещаем пошаговую систему
    if DoF.TurnSystem then
        DoF.TurnSystem:OnActionPerformed()
    end
end

function DoF.Combat:CancelAoEHeal()
    if not self.AoEHealState.active then return end

    DoF.Utils:Warn(DoF.L["combat.aoe.heal_cancelled"])
    self:EndAoEHeal()
end

function DoF.Combat:IsAoEHealActive()
    return self.AoEHealState.active
end

function DoF.Combat:GetAoEHealsLeft()
    return self.AoEHealState.healsLeft
end

-- ═══════════════════════════════════════════════════════════
-- AoE БАФФ
-- ═══════════════════════════════════════════════════════════

function DoF.Combat:StartAoEBuff(effectId)
    if not RequireRole() then return end

    if not DoF.Utils:RequireTurn(DoF.L["combat.action.aoe_buff"]) then return end

    -- Нельзя начать AoE бафф если уже в другом AoE режиме
    if self.AoEState.active then
        DoF.Utils:Error(DoF.L["errors.finish_aoe_first"])
        return
    end
    if self.AoEHealState.active then
        DoF.Utils:Error(DoF.L["errors.finish_aoe_heal"])
        return
    end
    if self.AoEBuffState.active then
        DoF.Utils:Error(DoF.L["errors.aoe_buff_active"])
        return
    end
    if self.AoEShieldState.active then
        DoF.Utils:Error(DoF.L["errors.finish_aoe_shield"])
        return
    end
    if self.SpecialActionState.active then
        DoF.Utils:Error(DoF.L["errors.finish_special"])
        return
    end

    local def = DoF.Effects.Definitions[effectId]
    if not def then
        DoF.Utils:Error(DoF.L["errors.unknown_effect_short"])
        return
    end

    local energyCost = DoF.Config.ENERGY_COST_AOE_BUFF
    if not DoF.Utils:RequireEnergy(energyCost, DoF.L["combat.action.aoe_buff"]) then return end

    -- Проверка кулдауна
    local casterName = UnitName("player")
    local cdKey = DoF.Effects:GetCooldownKey(def, effectId)
    if DoF.Effects:IsOnCooldown(casterName, cdKey) then
        local cd = DoF.Effects:GetCooldown(casterName, cdKey)
        DoF.Utils:Error(DoF.Locale:Format("errors.cooldown_rounds", cd, DoF.Locale:Rounds(cd)))
        return
    end

    -- Тратим энергию
    DoF.Stats:SpendEnergy(energyCost)

    -- AoE бафф — гарантированный успех (без броска)
    local targets = DoF.Config.AOE_MAX_TARGETS
    local playerName = UnitName("player")
    local buffColor = DoF.Effects:GetColorHex(def.color)

    local line1 = string_format(DoF.L["combat.aoe.activates"], playerName, DoF.Utils:Color(buffColor, def.name))
    local line2 = string_format(DoF.L["combat.aoe.targets_line"], DoF.Utils:Color("FFD700", targets))

    DoF.Sync:BroadcastCombatLog(line1 .. " " .. line2)

    -- Ставим кулдаун
    local cooldownRounds = def.aoeCooldownDuration or def.cooldownDuration or 5
    DoF.Effects:SetCooldown(casterName, cdKey, cooldownRounds)

    -- Входим в режим AoE баффа
    self.AoEBuffState.active = true
    self.AoEBuffState.effectId = effectId
    self.AoEBuffState.buffsLeft = targets
    self.AoEBuffState.buffedTargets = {}

    DoF.Utils:Info(DoF.Locale:Format("combat.aoe.buff_choose", targets, DoF.Utils:Color(buffColor, def.name)))

    -- Показываем панель
    if DoF.UI and DoF.UI.ShowAoEBuffPanel then
        DoF.UI:ShowAoEBuffPanel()
    end
end

function DoF.Combat:AoEBuffTarget()
    if not self.AoEBuffState.active then
        DoF.Utils:Error(DoF.L["errors.aoe_buff_inactive"])
        return
    end

    if self.AoEBuffState.buffsLeft <= 0 then
        DoF.Utils:Error(DoF.L["errors.all_buffs_used"])
        return
    end

    local guid, name = DoF.Utils:GetTargetGUID()

    if not guid then
        DoF.Utils:Error(DoF.L["errors.select_target"])
        return
    end

    if not DoF.Utils:IsTargetPlayer() then
        DoF.Utils:Error(DoF.L["errors.buff_players_only_short"])
        return
    end

    -- Проверка на повторный бафф
    if self.AoEBuffState.buffedTargets[name] then
        DoF.Utils:Error(DoF.L["errors.player_already_buffed"])
        return
    end

    local effectId = self.AoEBuffState.effectId

    -- Применяем бафф через AoE-применение (без энергии/кулдауна)
    local success = DoF.Effects:PlayerApplyAoE(name, effectId)

    if not success then
        return
    end

    -- Запоминаем цель и уменьшаем счётчик
    self.AoEBuffState.buffedTargets[name] = true
    self.AoEBuffState.buffsLeft = self.AoEBuffState.buffsLeft - 1

    DoF.Utils:Info(DoF.Locale:Format("combat.aoe.buffs_left", DoF.Utils:Color("FFD700", self.AoEBuffState.buffsLeft)))

    -- Обновляем панель
    if DoF.UI and DoF.UI.UpdateAoEBuffPanel then
        DoF.UI:UpdateAoEBuffPanel()
    end

    -- Проверяем окончание AoE баффа
    if self.AoEBuffState.buffsLeft <= 0 then
        self:EndAoEBuff()
    end
end

function DoF.Combat:EndAoEBuff()
    if not self.AoEBuffState.active then return end

    local buffed = 0
    for _ in pairs(self.AoEBuffState.buffedTargets) do
        buffed = buffed + 1
    end

    DoF.Utils:Info(DoF.Locale:Format("combat.aoe.buff_done", DoF.Utils:Color("FFD700", buffed)))

    -- Сбрасываем состояние
    self.AoEBuffState.active = false
    self.AoEBuffState.effectId = nil
    self.AoEBuffState.buffsLeft = 0
    self.AoEBuffState.buffedTargets = {}

    -- Скрываем панель
    if DoF.UI and DoF.UI.HideAoEBuffPanel then
        DoF.UI:HideAoEBuffPanel()
    end

    -- Оповещаем пошаговую систему
    if DoF.TurnSystem then
        DoF.TurnSystem:OnActionPerformed()
    end
end

function DoF.Combat:CancelAoEBuff()
    if not self.AoEBuffState.active then return end
    DoF.Utils:Warn(DoF.L["combat.aoe.buff_cancelled"])
    self:EndAoEBuff()
end

function DoF.Combat:IsAoEBuffActive()
    return self.AoEBuffState.active
end

function DoF.Combat:GetAoEBuffsLeft()
    return self.AoEBuffState.buffsLeft
end

function DoF.Combat:GetAoEBuffEffectId()
    return self.AoEBuffState.effectId
end

-- ═══════════════════════════════════════════════════════════
-- AoE ЩИТ (только целитель)
-- ═══════════════════════════════════════════════════════════

function DoF.Combat:StartAoEShield()
    if not RequireRole() then return end

    if not DoF.Utils:RequireTurn(DoF.L["combat.action.aoe_shield"]) then return end

    -- Только целитель
    local role = DoF.Stats:GetRole()
    if role ~= "healer" then
        DoF.Utils:Error(DoF.L["errors.healer_only_aoe_shield"])
        return
    end

    -- Нельзя начать если уже в другом AoE режиме
    if self.AoEState.active then
        DoF.Utils:Error(DoF.L["errors.finish_aoe_first"])
        return
    end
    if self.AoEHealState.active then
        DoF.Utils:Error(DoF.L["errors.finish_aoe_heal"])
        return
    end
    if self.AoEBuffState.active then
        DoF.Utils:Error(DoF.L["errors.finish_aoe_buff"])
        return
    end
    if self.AoEShieldState.active then
        DoF.Utils:Error(DoF.L["errors.aoe_shield_active"])
        return
    end
    if self.SpecialActionState.active then
        DoF.Utils:Error(DoF.L["errors.finish_special"])
        return
    end

    -- Проверка кулдауна
    local playerName = UnitName("player")
    if DoF.Effects then
        local cd = DoF.Effects:Get("player", playerName, "cooldown_aoe_shield")
        if cd then
            DoF.Utils:Error(DoF.Locale:Format("errors.aoe_shield_cooldown", cd.remainingRounds or "?", DoF.Locale:Plural(cd.remainingRounds or 0, DoF.L["ui.turns_one"], DoF.L["ui.turns_few"], DoF.L["ui.turns_many"])))
            return
        end
    end

    local energyCost = DoF.Config.ENERGY_COST_AOE_SHIELD
    if not DoF.Utils:RequireEnergy(energyCost, DoF.L["combat.action.aoe_shield"]) then return end

    -- Тратим энергию
    DoF.Stats:SpendEnergy(energyCost)

    local targets = DoF.Config.SHIELD_AOE_MAX_TARGETS

    local logLine = string_format(DoF.L["combat.aoe.activates_shield"],
        playerName, DoF.Utils:Color("FFD700", targets))
    DoF.Sync:BroadcastCombatLog(logLine)

    -- Активируем режим AoE щита
    self.AoEShieldState.active = true
    self.AoEShieldState.shieldsLeft = targets
    self.AoEShieldState.shieldedTargets = {}

    DoF.Utils:Info(DoF.Locale:Format("combat.aoe.shield_active", DoF.Utils:Color("FFD700", targets)))

    -- Показываем панель AoE щита
    if DoF.UI and DoF.UI.ShowAoEShieldPanel then
        DoF.UI:ShowAoEShieldPanel()
    end
end

function DoF.Combat:AoEShieldHit()
    if not self.AoEShieldState.active then
        DoF.Utils:Error(DoF.L["errors.aoe_shield_inactive"])
        return
    end

    if self.AoEShieldState.shieldsLeft <= 0 then
        DoF.Utils:Error(DoF.L["errors.all_shields_used"])
        return
    end

    local guid, name = DoF.Utils:GetTargetGUID()
    if not guid then
        DoF.Utils:Error(DoF.L["errors.select_target"])
        return
    end

    -- Проверка дубликата
    if self.AoEShieldState.shieldedTargets[guid] then
        DoF.Utils:Error(DoF.Locale:Format("errors.already_shielded", name))
        return
    end

    local isPlayer = DoF.Utils:IsTargetPlayer()
    local playerName = UnitName("player")

    if isPlayer then
        if UnitIsUnit("target", "player") then
            -- Себя
            if DoF.Stats:HasShield() then
                DoF.Utils:Warn(DoF.L["combat.aoe.shield_already_here"])
                return
            end
            DoF.Stats:ApplyShield()
            DoF.Events:Fire("PLAYER_SHIELD_CHANGED", 1)
            if DoF.Sync then
                DoF.Sync:BroadcastPlayerData()
            end
        else
            -- Другого игрока
            DoF.Sync:Send("SHIELD", name)
        end
    else
        -- NPC
        if DoF.Units:HasShield(guid) then
            DoF.Utils:Warn(DoF.Locale:Format("combat.aoe.shield_already_on", name))
            return
        end
        DoF.Units:ApplyShield(guid)
    end

    DoF.Utils:Info(DoF.Locale:Format("combat.aoe.shield_applied", name))

    -- Запоминаем цель
    self.AoEShieldState.shieldedTargets[guid] = true
    self.AoEShieldState.shieldsLeft = self.AoEShieldState.shieldsLeft - 1

    DoF.Utils:Info(DoF.Locale:Format("combat.aoe.shields_left", DoF.Utils:Color("FFD700", self.AoEShieldState.shieldsLeft)))

    -- Обновляем панель
    if DoF.UI and DoF.UI.UpdateAoEShieldPanel then
        DoF.UI:UpdateAoEShieldPanel()
    end

    -- Проверяем окончание
    if self.AoEShieldState.shieldsLeft <= 0 then
        self:EndAoEShield()
    end
end

function DoF.Combat:EndAoEShield()
    if not self.AoEShieldState.active then return end

    local shielded = 0
    for _ in pairs(self.AoEShieldState.shieldedTargets) do
        shielded = shielded + 1
    end

    DoF.Utils:Info(DoF.Locale:Format("combat.aoe.shield_done", DoF.Utils:Color("FFD700", shielded)))

    -- Кулдаун (только если были наложены щиты)
    if shielded > 0 and DoF.Effects then
        local playerName = UnitName("player")
        DoF.Effects:ApplyInternal("player", playerName, "cooldown_aoe_shield", 0, DoF.Config.SHIELD_AOE_COOLDOWN_TURNS)
    end

    -- Сбрасываем состояние
    self.AoEShieldState.active = false
    self.AoEShieldState.shieldsLeft = 0
    self.AoEShieldState.shieldedTargets = {}

    -- Скрываем панель
    if DoF.UI and DoF.UI.HideAoEShieldPanel then
        DoF.UI:HideAoEShieldPanel()
    end

    -- Оповещаем пошаговую систему
    if DoF.TurnSystem then
        DoF.TurnSystem:OnActionPerformed()
    end
end

function DoF.Combat:CancelAoEShield()
    if not self.AoEShieldState.active then return end
    DoF.Utils:Warn(DoF.L["combat.aoe.shield_cancelled"])
    self:EndAoEShield()
end

function DoF.Combat:IsAoEShieldActive()
    return self.AoEShieldState.active
end

function DoF.Combat:GetAoEShieldsLeft()
    return self.AoEShieldState.shieldsLeft
end
