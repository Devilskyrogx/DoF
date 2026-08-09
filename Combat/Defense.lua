-- DoF/Combat/Defense.lua
-- Защита от атак NPC, контратака, механики танка/бойца, мастер-команды

local ADDON_NAME, DoF = ...

-- Кэширование глобальных функций
local math_max = math.max
local math_min = math.min
local math_abs = math.abs
local string_format = string.format
local tostring = tostring
local UnitName = UnitName
local UnitGUID = UnitGUID
local GetTime = GetTime
local IsInGroup = IsInGroup
local C_Timer = C_Timer

-- ═══════════════════════════════════════════════════════════
-- АВТО-ВЫБОР ЛУЧШЕГО СТАТА ЗАЩИТЫ (для мгновенной защиты)
-- ═══════════════════════════════════════════════════════════

function DoF.Combat:GetBestDefenseStat()
    local best = "Fortitude"
    local bestVal = -999
    for _, stat in ipairs({"Fortitude", "Reflex", "Will"}) do
        local val = DoF.Stats:GetTotal(stat)
        if val > bestVal then
            bestVal = val
            best = stat
        end
    end
    return best
end

-- ═══════════════════════════════════════════════════════════
-- ЗАЩИТА ОТ АТАКИ NPC (обработка входящей атаки)
-- ═══════════════════════════════════════════════════════════

function DoF.Combat:ProcessNPCAttack(damageMin, damageMax, threshold, defenseStat, npcName, debuffId, debuffValue, debuffDuration, isInstant)
    -- Проверка перехвата урона: танк забирает атаку на себя
    local playerName = UnitName("player")
    if DoF.Effects then
        local redirectEffect = DoF.Effects:Get("player", playerName, "tank_redirect")
        if redirectEffect and redirectEffect.casters and redirectEffect.casters[1] then
            local tankName = redirectEffect.casters[1]
            if tankName ~= playerName then
                -- Снимаем бафф перехвата (одноразовый)
                DoF.Effects:Remove("player", playerName, "tank_redirect")

                -- Перенаправляем атаку на танка через синк
                DoF.Sync:BroadcastCombatLog(string_format(DoF.L["combat.def.redirect_absorb_log"],
                    DoF.Utils:Color("CC8040", tankName),
                    DoF.Utils:Color("FFFFFF", playerName)))

                local npc = (npcName and npcName ~= "") and npcName or "NPC"
                local instantRedirect = isInstant and 1 or 0
                DoF.Sync:Send("REDIRECT_DAMAGE", string_format("%s;%d;%d;%d;%s;%s;%s;%d;%d;%d",
                    tankName, damageMin, damageMax, threshold, defenseStat, npc,
                    debuffId or "", debuffValue or 0, debuffDuration or 0, instantRedirect))

                -- Если танк — это мы (маловероятно, но проверим)
                if tankName == playerName then
                    -- Не должно случиться, но на всякий случай — продолжаем обычную защиту
                else
                    -- Отправляем мастеру что защита этого игрока завершена
                    if DoF.Sync:IsMaster() then
                        DoF.Combat.PendingAttacks[playerName] = nil
                    else
                        DoF.Sync:Send("DEFENSE_DONE", playerName)
                    end
                    DoF.Sync:BroadcastPlayerData()
                    return -- Пропускаем обычный бросок защиты
                end
            end
        end
    end

    local modifier = DoF.Stats:GetTotal(defenseStat)
    local roll = DoF.Utils:Roll(1, 20)
    local total = roll + modifier

    local dmg = 0
    local resultText = ""
    local isSuccess = false
    local isCrit = false

    if roll == 1 then
        isSuccess = false
        -- Бросок урона в диапазоне
        dmg = DoF.Utils:Roll(damageMin, damageMax)
        resultText = DoF.L["combat.result.crit_fail"]

    elseif roll == 20 then
        isSuccess = true
        isCrit = true
        resultText = DoF.L["combat.result.crit_defense"]
    else
        isSuccess = self:IsSuccess(total, threshold)
        if isSuccess then
            resultText = DoF.L["combat.result.success"]
        else
            -- Бросок урона в диапазоне
            dmg = DoF.Utils:Roll(damageMin, damageMax)
            resultText = DoF.L["combat.result.fail"]
        end
    end

    -- Форматируем вывод
    local playerName = UnitName("player")
    local attackerName = npcName or "NPC"

    local color = DoF.Config.StatColors[defenseStat] or "FFFFFF"

    local line1 = string_format(DoF.L["combat.def.attacks"],
        DoF.Utils:Color("FF6666", attackerName),
        playerName)

    local compareSign = isSuccess and ">=" or "<="
    local resultColor = isSuccess and "00FF00" or "FF6666"

    local line2 = string_format(DoF.L["combat.def.defends_line"],
        playerName,
        DoF.Utils:Color(color, DoF.Config.StatNames[defenseStat] or defenseStat),
        DoF.Utils:Color("FFFF00", total),
        roll, modifier,
        compareSign,
        threshold,
        DoF.Utils:Color(resultColor, resultText))

    local logText = line1 .. " " .. line2

    if dmg > 0 then
        -- Используем ModifyHP который учитывает щит и ранения
        DoF.Stats:ModifyHP(-dmg)
        local dmgText = tostring(dmg)
        if damageMin ~= damageMax then
            dmgText = dmg .. " (" .. damageMin .. "-" .. damageMax .. ")"
        end
        logText = logText .. DoF.Locale:Format("combat.damage_suffix", DoF.Utils:Color("FF0000", dmgText))
    end

    -- Применяем дебафф при неудачной защите
    if not isSuccess and debuffId and debuffId ~= "" and debuffDuration and debuffDuration > 0 then
        if DoF.Effects then
            DoF.Effects:ApplyInternal("player", playerName, debuffId, debuffValue or 0, debuffDuration)
            local debuffDef = DoF.Effects.Definitions[debuffId]
            local debuffName = debuffDef and debuffDef.name or debuffId
            logText = logText .. " " .. DoF.Utils:Color("CC8833", DoF.Locale:Format("combat.def.debuff_suffix", debuffName, debuffDuration))
            -- BroadcastAllEffects только для мастера (ApplyInternal уже отправляет EFFECT_APPLY)
            if DoF.Sync and DoF.Sync:IsMaster() and IsInGroup() then
                DoF.Effects:BroadcastAllEffects()
            end
        end
    end

    DoF.Sync:BroadcastCombatLog(logText)

    -- Отправляем мастеру что защита завершена
    if DoF.Sync then
        -- Если мы сами мастер, очищаем флаг напрямую
        if DoF.Sync:IsMaster() then
            DoF.Combat.PendingAttacks[playerName] = nil
        else
            -- Если мы не мастер, отправляем сообщение мастеру
            DoF.Sync:Send("DEFENSE_DONE", playerName)
        end
        DoF.Sync:BroadcastPlayerData()
    end

    local role = DoF.Stats:GetRole()

    -- Танк: отслеживание серии защит (бафф зависит от стата защиты)
    if role == "tank" then
        self:ProcessTankDefenseStreak(isSuccess, defenseStat)
    end

    -- При крите защиты - показываем меню выбора
    if isCrit then
        DoF.Dialogs:ShowDefenseCritChoiceMenu(function(choice, attackerNameArg, attackerGuidArg)
            self:ApplyCritDefenseChoice(choice, attackerNameArg, attackerGuidArg)
        end, attackerName, nil)
    -- Боец: 15% шанс контратаки при обычной успешной защите
    elseif isSuccess and not isCrit and role == "dd" then
        self:ProcessDDDefenseBonus()
    end

end

-- Применить выбор крита при защите
function DoF.Combat:ApplyCritDefenseChoice(choice, attackerName, attackerGuid)
    local playerName = UnitName("player")

    if choice == "counterattack" then
        local damage = self:CalculateDamage(false)
        -- Боец при крит-защите получает +3 к урону контратаки
        local role = DoF.Stats:GetRole()
        if role == "dd" then
            damage = damage + 3
        end
        DoF.Sync:BroadcastCombatLog(string_format(DoF.L["combat.def.crit_defense_bonus_damage"],
            playerName, DoF.Utils:Color("FF6666", DoF.L["combat.label.counterattack"]), DoF.Utils:Color("FF0000", damage)))
        if attackerGuid then
            local data = DoF.Units:Get(attackerGuid)
            if data then
                DoF.Units:Damage(attackerGuid, damage)
                DoF.Utils:Warn(DoF.Locale:Format("combat.def.counter_damage_taken", attackerName, DoF.Utils:Color("FF0000", damage), DoF.Utils:Color("FF0000", data.hp .. "/" .. data.maxHp)))
            end
        else
            self:StartCounterattackTargetSelection(damage)
        end
    elseif choice == "energy" then
        DoF.Sync:BroadcastCombatLog(string_format(DoF.L["combat.def.crit_defense_bonus"],
            playerName, DoF.Utils:Color("9966FF", DoF.L["combat.bonus_energy"])))
    elseif choice == "tank_hp_buff" then
        DoF.Sync:BroadcastCombatLog(string_format(DoF.L["combat.def.crit_defense_bonus"],
            playerName, DoF.Utils:Color("66FF66", DoF.L["ui.combat.bonus_ally_hp"])))
        -- Танк: бесплатный бафф +2 HP на союзника — активируем выбор цели
        self:StartTankHPBuffSelection()
    end
end

-- ═══════════════════════════════════════════════════════════
-- МЕХАНИКА ТАНКА: СЕРИЯ ЗАЩИТ → БАФФ К СТАТУ ЗАЩИТЫ
-- ═══════════════════════════════════════════════════════════

local TANK_STREAK_EFFECT_MAP = {
    Fortitude = "tank_fort_streak",
    Reflex    = "tank_reflex_streak",
    Will      = "tank_will_streak",
}

function DoF.Combat:ProcessTankDefenseStreak(isSuccess, defenseStat)
    local playerName = UnitName("player")

    if not self.TankDefenseStreak[playerName] then
        self.TankDefenseStreak[playerName] = { count = 0 }
    end

    local streak = self.TankDefenseStreak[playerName]
    local effectId = TANK_STREAK_EFFECT_MAP[defenseStat]

    if not effectId then return end

    if not isSuccess then
        -- Неудача: удалить бафф только проваленного стата, сбросить счётчик
        local storage = DoF.Effects.PlayerEffects
        if storage[playerName] and storage[playerName][effectId] then
            DoF.Effects:Remove("player", playerName, effectId)
            local color = DoF.Config.StatColors[defenseStat] or "FFFFFF"
            local statName = DoF.Config.StatNames[defenseStat] or defenseStat
            DoF.Utils:Warn(DoF.Locale:Format("combat.def.tank_streak_broken", DoF.Utils:Color(color, statName)))
        end
        streak.count = 0
        return
    end

    -- Успех: увеличить глобальный счётчик
    streak.count = streak.count + 1

    -- Каждые 2 успешных защиты → +1 к стату, которым защитился
    if streak.count >= 2 then
        streak.count = 0

        -- Читаем текущий уровень баффа из системы эффектов
        local storage = DoF.Effects.PlayerEffects
        local currentLevel = 0
        if storage[playerName] and storage[playerName][effectId] then
            currentLevel = storage[playerName][effectId].value or 0
        end

        local color = DoF.Config.StatColors[defenseStat] or "FFFFFF"
        local statName = DoF.Config.StatNames[defenseStat] or defenseStat

        -- Кап на 3
        if currentLevel >= 3 then
            DoF.Utils:Info(DoF.Locale:Format("combat.def.tank_streak_max", DoF.Utils:Color(color, statName)))
            return
        end

        local newLevel = currentLevel + 1

        -- Применяем/обновляем бафф (независимый таймер 3 раунда)
        DoF.Effects:ApplyInternal("player", playerName, effectId, newLevel, 3)

        DoF.Utils:Info(DoF.Locale:Format("combat.def.tank_streak", DoF.Utils:Color(color, DoF.Locale:Format("combat.def.tank_streak_label", statName, newLevel))))
        DoF.Sync:BroadcastCombatLog(DoF.Locale:Format("combat.def.tank_streak_log", playerName, statName, newLevel))
    end
end

-- ═══════════════════════════════════════════════════════════
-- МЕХАНИКА ТАНКА: ПРОБИТИЕ ЗАЩИТЫ ВРАГА
-- ═══════════════════════════════════════════════════════════

function DoF.Combat:ProcessTankShred(npcGuid, npcName)
    local playerName = UnitName("player")
    local cfg = DoF.Config

    if not self.TankShredTracker[playerName] then
        self.TankShredTracker[playerName] = {}
    end
    local tracker = self.TankShredTracker[playerName]

    tracker[npcGuid] = (tracker[npcGuid] or 0) + 1

    -- Broadcast: остальные клиенты видят актуальный счётчик ударов танка по NPC.
    if DoF.Sync and IsInGroup() then
        DoF.Sync:Send("TANK_SHRED_TRACKER", playerName .. ";" .. npcGuid .. ";" .. tracker[npcGuid])
    end

    if tracker[npcGuid] < cfg.TANK_SHRED_HITS_REQUIRED then
        return
    end

    -- Достигнут порог — сбросить счётчик и показать выбор
    tracker[npcGuid] = 0
    -- Broadcast сброса, чтобы клиенты тоже увидели 0
    if DoF.Sync and IsInGroup() then
        DoF.Sync:Send("TANK_SHRED_TRACKER", playerName .. ";" .. npcGuid .. ";0")
    end

    -- Проверяем есть ли место для стаков хотя бы на одном стате
    local fortEffect = DoF.Effects:Get("npc", npcGuid, "tank_shred_fortitude")
    local reflexEffect = DoF.Effects:Get("npc", npcGuid, "tank_shred_reflex")
    local fortStacks = fortEffect and (fortEffect.value / cfg.TANK_SHRED_PER_STACK) or 0
    local reflexStacks = reflexEffect and (reflexEffect.value / cfg.TANK_SHRED_PER_STACK) or 0

    if fortStacks >= cfg.TANK_SHRED_MAX_STACKS and reflexStacks >= cfg.TANK_SHRED_MAX_STACKS then
        DoF.Utils:Info(DoF.Locale:Format("combat.def.shred_max_both", DoF.Utils:Color("FF6666", npcName)))
        return
    end

    DoF.Dialogs:ShowTankShredChoiceMenu(function(statChoice)
        local effectId
        if statChoice == "fort" then
            effectId = "tank_shred_fortitude"
        else
            effectId = "tank_shred_reflex"
        end

        local existing = DoF.Effects:Get("npc", npcGuid, effectId)
        local currentValue = existing and existing.value or 0
        local currentStacks = currentValue / cfg.TANK_SHRED_PER_STACK

        if currentStacks >= cfg.TANK_SHRED_MAX_STACKS then
            local statName = statChoice == "fort" and DoF.L["stats.fortitude.label"] or DoF.L["stats.reflex.label"]
            DoF.Utils:Warn(DoF.Locale:Format("combat.def.shred_max_stat", statName))
            return
        end

        local newValue = currentValue + cfg.TANK_SHRED_PER_STACK
        local newStacks = math.min(newValue / cfg.TANK_SHRED_PER_STACK, cfg.TANK_SHRED_MAX_STACKS)

        -- Прямое обновление эффекта (без ApplyInternal, который теряет casters/stacks)
        local storage = DoF.Effects.NPCEffects
        if not storage[npcGuid] then storage[npcGuid] = {} end

        local eff = storage[npcGuid][effectId]
        if eff then
            eff.value = newValue
            eff.stacks = newStacks
            eff.remainingRounds = 3
            eff.duration = 3
            eff.appliedAt = GetTime()
            -- Добавляем кастера если его ещё нет
            local found = false
            for _, c in ipairs(eff.casters) do
                if c == playerName then found = true; break end
            end
            if not found then
                table.insert(eff.casters, playerName)
            end
        else
            storage[npcGuid][effectId] = {
                id = effectId,
                value = newValue,
                stacks = newStacks,
                duration = 3,
                remainingRounds = 3,
                casters = { playerName },
                appliedAt = GetTime(),
            }
        end

        -- Синхронизация: отправляем авторитетное состояние
        if DoF.Sync and IsInGroup() then
            DoF.Sync:Send("TANK_SHRED_APPLY", string_format("%s;%s;%d;%d;%s",
                npcGuid, effectId, newValue, newStacks, playerName))
        end

        DoF.Events:Fire("EFFECT_APPLIED", "npc", npcGuid, effectId)
        if DoF.UI.Effects then DoF.UI.Effects:UpdateAll() end
        local statName = statChoice == "fort" and DoF.L["stats.fortitude.label"] or DoF.L["stats.reflex.label"]
        local color = statChoice == "fort" and "FF8844" or "FFAA44"
        DoF.Utils:Info(DoF.Locale:Format("combat.def.shred_applied", DoF.Utils:Color(color, DoF.Locale:Format("combat.def.shred_label", statName, newValue)), newStacks, cfg.TANK_SHRED_MAX_STACKS))
        DoF.Sync:BroadcastCombatLog(string_format(DoF.L["combat.def.shred_log"],
            playerName, DoF.Utils:Color("FF6666", npcName),
            DoF.Utils:Color(color, statName .. " -" .. newValue .. " (" .. newStacks .. "/" .. cfg.TANK_SHRED_MAX_STACKS .. ")")))
    end, npcGuid, npcName, fortStacks >= cfg.TANK_SHRED_MAX_STACKS, reflexStacks >= cfg.TANK_SHRED_MAX_STACKS)
end

-- ═══════════════════════════════════════════════════════════
-- МЕХАНИКА БОЙЦА: 15% КОНТРАТАКА ПРИ УСПЕШНОЙ ЗАЩИТЕ
-- ═══════════════════════════════════════════════════════════

function DoF.Combat:ProcessDDDefenseBonus()
    if DoF.Utils:Roll(1, 100) > 15 then return end

    local damage = self:CalculateDamage(false)
    DoF.Utils:Info(DoF.Locale:Format("combat.def.fighter_counter", DoF.Utils:Color("FF6666", DoF.L["combat.label.counterattack"])))
    self:StartCounterattackTargetSelection(damage)
end

-- ═══════════════════════════════════════════════════════════
-- МЕХАНИКА ТАНКА: КРИТ ЗАЩИТЫ → +2 HP БАФФ СОЮЗНИКУ
-- ═══════════════════════════════════════════════════════════

function DoF.Combat:StartTankHPBuffSelection()
    DoF.Utils:Info(DoF.Locale:Format("combat.def.tank_choose_ally", DoF.Utils:Color("66FF66", DoF.L["combat.label.tank_hp"])))
    -- Используем режим AoE хила для выбора одной цели
    self.TankHPBuffActive = true
    if DoF.UI and DoF.UI.ShowTankHPBuffPanel then
        DoF.UI:ShowTankHPBuffPanel()
    end
end

function DoF.Combat:TankHPBuffApply()
    if not self.TankHPBuffActive then
        DoF.Utils:Error(DoF.L["errors.buff_not_active"])
        return
    end

    local guid, name = DoF.Utils:GetTargetGUID()
    if not guid then
        DoF.Utils:Error(DoF.L["errors.select_target"])
        return
    end

    if not DoF.Utils:IsTargetPlayer() then
        DoF.Utils:Error(DoF.L["errors.buff_players_only"])
        return
    end

    -- Применяем fortify_hp бесплатно (без энергии/кулдауна)
    DoF.Effects:ApplyInternal("player", name, "fortify_hp", 2, 3)

    local playerName = UnitName("player")
    DoF.Utils:Info(DoF.Locale:Format("combat.def.tank_hp_buff_applied", name, DoF.Utils:Color("66FF66", DoF.L["combat.label.tank_hp"])))
    DoF.Sync:BroadcastCombatLog(DoF.Locale:Format("combat.def.tank_hp_buff_log", playerName, name))

    self.TankHPBuffActive = false
    if DoF.UI and DoF.UI.HideTankHPBuffPanel then
        DoF.UI:HideTankHPBuffPanel()
    end
end

function DoF.Combat:TankHPBuffCancel()
    self.TankHPBuffActive = false
    if DoF.UI and DoF.UI.HideTankHPBuffPanel then
        DoF.UI:HideTankHPBuffPanel()
    end
end

-- ═══════════════════════════════════════════════════════════
-- КОНТРАТАКА: ВЫБОР ЦЕЛИ
-- ═══════════════════════════════════════════════════════════

function DoF.Combat:StartCounterattackTargetSelection(damage)
    -- Если контратака уже активна — игнорируем
    if self.CounterattackState.active then return end

    self.CounterattackState.active = true
    self.CounterattackState.damage = damage
    self.CounterattackState.playerName = UnitName("player")

    DoF.Utils:Info(DoF.Locale:Format("combat.def.counter_prompt", DoF.Utils:Color("FF0000", damage)))

    if DoF.UI and DoF.UI.ShowCounterattackPanel then
        DoF.UI:ShowCounterattackPanel(damage)
    end

    -- Таймаут: автоотмена через 20 секунд
    self.CounterattackState.timer = C_Timer.NewTimer(20, function()
        if self.CounterattackState.active then
            DoF.Utils:Warn(DoF.L["combat.def.counter_timeout"])
            self:CounterattackCancel()
        end
    end)
end

function DoF.Combat:CounterattackSelectTarget()
    if not self.CounterattackState.active then
        DoF.Utils:Error(DoF.L["errors.counter_inactive"])
        return
    end

    -- Проверка что бой ещё идёт
    if DoF.TurnSystem and DoF.TurnSystem.phase == "idle" then
        DoF.Utils:Error(DoF.L["errors.combat_finished"])
        self:CounterattackCancel()
        return
    end

    local guid, name = DoF.Utils:GetTargetGUID()

    if not guid then
        DoF.Utils:Error(DoF.L["errors.select_target"])
        return
    end

    if DoF.Utils:IsTargetPlayer() then
        DoF.Utils:Error(DoF.L["errors.cannot_counter_players"])
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

    local damage = self.CounterattackState.damage
    DoF.Units:Damage(guid, damage)

    local playerName = self.CounterattackState.playerName or UnitName("player")
    DoF.Utils:Warn(DoF.Locale:Format("combat.def.counter_damage_taken", name, DoF.Utils:Color("FF0000", damage), DoF.Utils:Color("FF0000", data.hp .. "/" .. data.maxHp)))

    local logText = string_format(DoF.L["combat.def.counter_log"],
        playerName, name,
        DoF.Utils:Color("FF0000", damage),
        DoF.Utils:Color("FF0000", data.hp .. "/" .. data.maxHp))
    DoF.Sync:BroadcastCombatLog(logText)

    -- Сброс состояния
    self:CounterattackCancel()
end

function DoF.Combat:CounterattackCancel()
    if self.CounterattackState.timer then
        self.CounterattackState.timer:Cancel()
        self.CounterattackState.timer = nil
    end
    self.CounterattackState.active = false
    self.CounterattackState.damage = 0
    self.CounterattackState.playerName = nil

    if DoF.UI and DoF.UI.HideCounterattackPanel then
        DoF.UI:HideCounterattackPanel()
    end
end

function DoF.Combat:IsCounterattackActive()
    return self.CounterattackState.active
end

-- Автонеудача при истечении времени на защиту
function DoF.Combat:ProcessDefenseFailure(damageMin, damageMax, npcName, debuffId, debuffValue, debuffDuration)
    local playerName = UnitName("player")
    local attackerName = npcName or "NPC"

    local line1 = string_format(DoF.L["combat.def.attacks"],
        DoF.Utils:Color("FF6666", attackerName),
        playerName)

    local line2 = string_format(DoF.L["combat.def.no_defense_line"],
        playerName,
        DoF.Utils:Color("FF0000", DoF.L["combat.label.auto_fail"]))

    local logText = line1 .. " " .. line2

    -- Бросок урона в диапазоне
    local damage = DoF.Utils:Roll(damageMin, damageMax)
    if damage > 0 then
        DoF.Stats:ModifyHP(-damage)
        local dmgText = tostring(damage)
        if damageMin ~= damageMax then
            dmgText = damage .. " (" .. damageMin .. "-" .. damageMax .. ")"
        end
        logText = logText .. DoF.Locale:Format("combat.damage_suffix", DoF.Utils:Color("FF0000", dmgText))
        DoF.Utils:Error(DoF.Locale:Format("combat.def.time_up_damage", damage))
    end

    -- Применяем дебафф при автонеудаче
    if debuffId and debuffId ~= "" and debuffDuration and debuffDuration > 0 then
        if DoF.Effects then
            DoF.Effects:ApplyInternal("player", playerName, debuffId, debuffValue or 0, debuffDuration)
            local debuffDef = DoF.Effects.Definitions[debuffId]
            local debuffName = debuffDef and debuffDef.name or debuffId
            logText = logText .. " " .. DoF.Utils:Color("CC8833", DoF.Locale:Format("combat.def.debuff_suffix", debuffName, debuffDuration))
            -- BroadcastAllEffects только для мастера (ApplyInternal уже отправляет EFFECT_APPLY)
            if DoF.Sync and DoF.Sync:IsMaster() and IsInGroup() then
                DoF.Effects:BroadcastAllEffects()
            end
        end
    end

    DoF.Sync:BroadcastCombatLog(logText)

    if DoF.Sync then
        -- Если мы сами мастер, очищаем флаг напрямую
        if DoF.Sync:IsMaster() then
            DoF.Combat.PendingAttacks[playerName] = nil
        else
            -- Если мы не мастер, отправляем сообщение мастеру
            DoF.Sync:Send("DEFENSE_DONE", playerName)
        end
        DoF.Sync:BroadcastPlayerData()
    end

    -- Очищаем флаг ожидающей атаки локально (на всякий случай)
    if not DoF.Sync or not DoF.Sync:IsMaster() then
        DoF.Combat.PendingAttacks[playerName] = nil
    end
end

-- ═══════════════════════════════════════════════════════════
-- ИЗМЕНЕНИЕ HP ИГРОКА МАСТЕРОМ
-- ═══════════════════════════════════════════════════════════

function DoF.Combat:ProcessModifyHP(value, source)
    local currentHP = DoF.Stats:GetCurrentHP()
    local maxHP = DoF.Stats:GetMaxHP()

    if value < 0 then
        -- Урон через ModifyHP (учитывает щит), silent — сообщение будет в боевом логе
        DoF.Stats:ModifyHP(value, true)
    else
        -- Исцеление напрямую
        local newHP = DoF.Utils:Clamp(currentHP + value, 0, maxHP)
        DoF.Stats:SetCurrentHP(newHP)
        DoF.Events:Fire("PLAYER_HP_CHANGED", newHP, maxHP)
    end

    local logText = string_format(DoF.L["combat.def.gm_hp_log"],
        UnitName("player"), value > 0 and DoF.L["combat.label.gained"] or DoF.L["combat.label.lost"],
        math_abs(value), DoF.Stats:GetCurrentHP(), DoF.Stats:GetMaxHP())

    DoF.Sync:BroadcastCombatLog(logText)

    if DoF.Sync then
        DoF.Sync:BroadcastPlayerData()
    end
end

-- ═══════════════════════════════════════════════════════════
-- ПОЛУЧЕНИЕ ИСЦЕЛЕНИЯ ОТ ДРУГОГО ИГРОКА
-- ═══════════════════════════════════════════════════════════

function DoF.Combat:ProcessHeal(heal, healer, removeWound)
    local currentHP = DoF.Stats:GetCurrentHP()
    local maxHP = DoF.Stats:GetMaxHP()
    local newHP = math.min(maxHP, currentHP + heal)
    DoF.Stats:SetCurrentHP(newHP)
    DoF.Events:Fire("PLAYER_HP_CHANGED", newHP, maxHP)

    -- Снятие ранения при крите хила
    if removeWound and DoF.Stats:GetWounds() > 0 then
        DoF.Stats:RemoveWound()
    end

    DoF.Sync:BroadcastCombatLog(string_format(DoF.L["combat.def.healed_log"],
        UnitName("player"), healer, newHP, maxHP))

    if DoF.Sync then
        DoF.Sync:BroadcastPlayerData()
    end
end

-- ═══════════════════════════════════════════════════════════
-- ПОЛУЧЕНИЕ ЩИТА ОТ ДРУГОГО ИГРОКА
-- ═══════════════════════════════════════════════════════════

function DoF.Combat:ProcessShield(caster)
    if DoF.Stats:HasShield() then
        DoF.Utils:Warn(DoF.L["combat.def.shield_already"])
        return
    end

    local playerName = UnitName("player")
    if DoF.Effects and DoF.Effects:HasEffect("player", playerName, "shield_exhaustion") then
        DoF.Utils:Warn(DoF.L["combat.def.shield_broken"])
        return
    end

    DoF.Stats:ApplyShield()

    DoF.Events:Fire("PLAYER_SHIELD_CHANGED", 1)

    if DoF.Sync then
        DoF.Sync:BroadcastPlayerData()
    end
end

-- ═══════════════════════════════════════════════════════════
-- АТАКА NPC ПО ИГРОКУ (мастер)
-- ═══════════════════════════════════════════════════════════

function DoF.Combat:NPCAttack(targetName, damageMin, damageMax, threshold, defenseStat, npcName, debuffId, debuffValue, debuffDuration)
    if not DoF.Utils:RequireMaster(false) then return end

    npcName = (npcName and npcName ~= "") and npcName or "NPC"

    -- Проверяем нет ли уже ожидающей атаки на этого игрока
    local pendingTime = self.PendingAttacks[targetName]
    if pendingTime then
        local elapsed = GetTime() - pendingTime
        if elapsed < self.PENDING_TIMEOUT then
            DoF.Utils:Error(DoF.Locale:Format("combat.def.not_defended_yet", targetName))
            return
        else
            -- Таймаут истёк, очищаем
            self.PendingAttacks[targetName] = nil
        end
    end

    -- Отмечаем что атака отправлена
    self.PendingAttacks[targetName] = GetTime()

    local instantFlag = self.instantDefense and 1 or 0
    local npcAttackPayload = string_format("%s;%d;%d;%d;%s;%s;%s;%d;%d;%d",
        targetName, damageMin, damageMax, threshold, defenseStat, npcName,
        debuffId or "", debuffValue or 0, debuffDuration or 0, instantFlag)

    -- Если цель - мы сами: обрабатываем напрямую (без сетевой отправки)
    if targetName == UnitName("player") then
        if self.instantDefense then
            -- Мгновенная защита: авто-бросок без окна
            local defStat = defenseStat
            if defStat == "Hybrid" then
                defStat = DoF.Combat:GetBestDefenseStat()
            end
            self:ProcessNPCAttack(damageMin, damageMax, threshold, defStat, npcName, debuffId, debuffValue, debuffDuration, true)
        elseif defenseStat == "Hybrid" then
            DoF.Dialogs:ShowHybridDefenseChoice(npcName, damageMin, damageMax, threshold, debuffId, debuffValue, debuffDuration)
        else
            DoF.Dialogs:ShowNPCAttackAlert(npcName, defenseStat, damageMin, damageMax, threshold, debuffId, debuffValue, debuffDuration)
        end
    else
        -- Рассылаем по RAID/PARTY — клиенты фильтруют по targetName (первое поле payload).
        -- Широковещание вместо 30 WHISPER'ов снимает перегрузку ChatThrottleLib при больших группах.
        DoF.Sync:Send("NPCATTACK", npcAttackPayload)
    end

    -- Лог мастера
    if DoF.CombatLog then
        local defName = defenseStat == "Hybrid" and DoF.L["combat.label.hybrid"] or DoF.Config.StatNames[defenseStat]
        local dmgStr = damageMin == damageMax and tostring(damageMin) or (damageMin .. "-" .. damageMax)
        local logMsg = string_format(DoF.L["combat.def.npc_attack_log"],
            npcName, targetName, dmgStr, threshold, defName)
        if debuffId and debuffId ~= "" then
            local debuffDef = DoF.Effects and DoF.Effects.Definitions[debuffId]
            local debuffName = debuffDef and debuffDef.name or debuffId
            logMsg = logMsg .. DoF.Locale:Format("combat.def.debuff_log_suffix", debuffName)
        end
        DoF.CombatLog:AddMasterLog(logMsg, "master_action")
    end
end

-- ═══════════════════════════════════════════════════════════
-- ИЗМЕНЕНИЕ HP ИГРОКА (мастер)
-- ═══════════════════════════════════════════════════════════

function DoF.Combat:ModifyPlayerHP(targetName, value)
    if not DoF.Utils:RequireMaster(false) then return end

    DoF.Sync:Send("MODIFYHP", targetName .. ";" .. value)

    if targetName == UnitName("player") then
        self:ProcessModifyHP(value, DoF.L["combat.label.gm"])
    elseif DoF.Sync.RaidData[targetName] then
        -- Оптимистичное обновление: мастер видит результат сразу, не дожидаясь round-trip.
        -- hpVersion = GetServerTime() — общий масштаб, см. комментарий в Sync:ModifyPlayerHP.
        local data = DoF.Sync.RaidData[targetName]
        data.hp = DoF.Utils:Clamp((data.hp or 0) + value, 0, data.maxHp or 10)
        data.hpVersion = GetServerTime()
        DoF.Events:Fire("PLAYER_DATA_RECEIVED", targetName, data)
    end

    local action = value > 0 and DoF.L["combat.label.hp_added"] or DoF.L["combat.label.hp_removed"]
    local color = value > 0 and "00FF00" or "FF0000"

    DoF.Utils:Info(DoF.Locale:Format("combat.def.hp_change_msg", action,
        DoF.Utils:Color(color, math_abs(value)), DoF.Utils:Color("FFFFFF", targetName)))

    if DoF.CombatLog then
        DoF.CombatLog:AddMasterLog(string_format(DoF.L["combat.def.hp_change_log"],
            targetName, value), "master_action")
    end
end

-- ═══════════════════════════════════════════════════════════
-- МЕХАНИКА ТАНКА: ПРОВОКАЦИЯ
-- ═══════════════════════════════════════════════════════════

function DoF.Combat:TankTaunt()
    if DoF.Stats:GetRole() ~= "tank" then
        DoF.Utils:Error(DoF.L["errors.tank_only_taunt"])
        return
    end

    if not DoF.Utils:RequireTurn(DoF.L["combat.action.taunt"]) then return end

    if self:IsAoEActive() or self:IsAoEHealActive() or self:IsAoEBuffActive() or self:IsTauntAoEActive() then
        DoF.Utils:Error(DoF.L["errors.finish_current_aoe"])
        return
    end

    local playerName = UnitName("player")

    -- Проверка кулдауна
    if DoF.Effects:Get("player", playerName, "cooldown_tank_taunt") then
        local cd = DoF.Effects:Get("player", playerName, "cooldown_tank_taunt")
        DoF.Utils:Error(DoF.Locale:Format("errors.taunt_cooldown", cd.remainingRounds or "?", DoF.Locale:Rounds(cd.remainingRounds or 0)))
        return
    end

    local cost = DoF.Config.ENERGY_COST_TAUNT
    if not DoF.Utils:RequireEnergy(cost, DoF.L["combat.action.taunt"]) then return end

    -- Проверка цели — NPC
    local guid, name = DoF.Utils:GetTargetGUID()
    if not guid then
        DoF.Utils:Error(DoF.L["errors.select_npc_target_short"])
        return
    end
    if DoF.Utils:IsTargetPlayer() then
        DoF.Utils:Error(DoF.L["errors.taunt_npc_only"])
        return
    end
    local data = DoF.Units:Get(guid)
    if not data or data.hp <= 0 then
        DoF.Utils:Error(DoF.L["errors.target_dead_or_missing"])
        return
    end

    -- Проверка: уже спровоцирован другим танком
    local existingTaunt = DoF.Effects:Get("npc", guid, "tank_taunt")
    if existingTaunt then
        local existingCaster = existingTaunt.casters and existingTaunt.casters[1]
        if existingCaster and existingCaster ~= playerName then
            DoF.Utils:Error(DoF.Locale:Format("errors.already_taunted_by", name, existingCaster))
            return
        end
    end

    -- Траты
    DoF.Stats:SpendEnergy(cost)

    -- Применить дебафф провокации на NPC
    local duration = DoF.Config.TANK_TAUNT_DURATION
    DoF.Effects:ApplyInternal("npc", guid, "tank_taunt", 0, duration, playerName)

    -- Кулдаун
    DoF.Effects:ApplyInternal("player", playerName, "cooldown_tank_taunt", 0, 2)

    DoF.Utils:Info(DoF.Locale:Format("combat.def.taunt_applied", DoF.Utils:Color("CC8040", DoF.L["combat.label.taunt"]), DoF.Utils:Color("FF6666", name)))
    DoF.Sync:BroadcastCombatLog(string_format(DoF.L["combat.def.taunt_log"],
        DoF.Utils:Color("CC8040", playerName),
        DoF.Utils:Color("FF6666", name),
        duration))

    if DoF.TurnSystem then
        DoF.TurnSystem:OnActionPerformed()
    end
end

-- ═══════════════════════════════════════════════════════════
-- МЕХАНИКА ТАНКА: AOE ПРОВОКАЦИЯ
-- ═══════════════════════════════════════════════════════════

function DoF.Combat:TankTauntAoE()
    if DoF.Stats:GetRole() ~= "tank" then
        DoF.Utils:Error(DoF.L["errors.tank_only_mass_taunt"])
        return
    end

    if not DoF.Utils:RequireTurn(DoF.L["combat.action.mass_taunt"]) then return end

    if self:IsAoEActive() or self:IsAoEHealActive() or self:IsAoEBuffActive() or self:IsTauntAoEActive() then
        DoF.Utils:Error(DoF.L["errors.finish_current_aoe"])
        return
    end

    local playerName = UnitName("player")

    -- Проверка кулдауна
    if DoF.Effects:Get("player", playerName, "cooldown_tank_taunt_aoe") then
        local cd = DoF.Effects:Get("player", playerName, "cooldown_tank_taunt_aoe")
        DoF.Utils:Error(DoF.Locale:Format("errors.mass_taunt_cooldown", cd.remainingRounds or "?", DoF.Locale:Rounds(cd.remainingRounds or 0)))
        return
    end

    local cost = DoF.Config.ENERGY_COST_TAUNT_AOE
    if not DoF.Utils:RequireEnergy(cost, DoF.L["combat.action.mass_taunt"]) then return end

    -- Траты
    DoF.Stats:SpendEnergy(cost)

    -- Активируем AoE режим
    self.AoETauntState = {
        active = true,
        tauntsLeft = DoF.Config.AOE_MAX_TARGETS,
        tauntedTargets = {},
        casterName = playerName,
    }

    -- Кулдаун
    DoF.Effects:ApplyInternal("player", playerName, "cooldown_tank_taunt_aoe", 0, 3)

    DoF.Utils:Info(DoF.Locale:Format("combat.def.mass_taunt_prompt", DoF.Utils:Color("FF6633", DoF.L["combat.label.mass_taunt_acc"]), self.AoETauntState.tauntsLeft))

    if DoF.UI and DoF.UI.ShowAoETauntPanel then
        DoF.UI:ShowAoETauntPanel()
    end
end

function DoF.Combat:TankTauntTarget()
    if not self.AoETauntState.active then
        DoF.Utils:Error(DoF.L["errors.aoe_taunt_inactive"])
        return
    end

    local guid, name = DoF.Utils:GetTargetGUID()
    if not guid then
        DoF.Utils:Error(DoF.L["errors.select_npc_target_short"])
        return
    end
    if DoF.Utils:IsTargetPlayer() then
        DoF.Utils:Error(DoF.L["errors.taunt_npc_only"])
        return
    end
    local data = DoF.Units:Get(guid)
    if not data or data.hp <= 0 then
        DoF.Utils:Error(DoF.L["errors.target_dead_or_missing"])
        return
    end

    -- Проверка дубликата
    if self.AoETauntState.tauntedTargets[guid] then
        DoF.Utils:Error(DoF.Locale:Format("errors.already_taunted", name))
        return
    end

    local playerName = self.AoETauntState.casterName
    local duration = DoF.Config.TANK_TAUNT_DURATION

    -- Проверка: уже спровоцирован другим танком
    local existingTaunt = DoF.Effects:Get("npc", guid, "tank_taunt")
    if existingTaunt then
        local existingCaster = existingTaunt.casters and existingTaunt.casters[1]
        if existingCaster and existingCaster ~= playerName then
            DoF.Utils:Error(DoF.Locale:Format("errors.already_taunted_by", name, existingCaster))
            return
        end
    end

    -- Применить дебафф
    DoF.Effects:ApplyInternal("npc", guid, "tank_taunt", 0, duration, playerName)
    self.AoETauntState.tauntedTargets[guid] = true
    self.AoETauntState.tauntsLeft = self.AoETauntState.tauntsLeft - 1

    DoF.Utils:Info(DoF.Locale:Format("combat.def.taunt_progress", DoF.Utils:Color("FF6666", name), self.AoETauntState.tauntsLeft))

    if DoF.UI and DoF.UI.UpdateAoETauntPanel then
        DoF.UI:UpdateAoETauntPanel()
    end

    if self.AoETauntState.tauntsLeft <= 0 then
        self:EndTauntAoE()
    end
end

function DoF.Combat:EndTauntAoE()
    if not self.AoETauntState.active then return end

    local count = 0
    for _ in pairs(self.AoETauntState.tauntedTargets) do
        count = count + 1
    end

    local playerName = self.AoETauntState.casterName
    self.AoETauntState = { active = false, tauntsLeft = 0, tauntedTargets = {} }

    if DoF.UI and DoF.UI.HideAoETauntPanel then
        DoF.UI:HideAoETauntPanel()
    end

    DoF.Sync:BroadcastCombatLog(string_format(DoF.L["combat.def.mass_taunt_log"],
        DoF.Utils:Color("CC8040", playerName),
        DoF.Utils:Color("FF6633", DoF.L["combat.label.mass_taunt_acc"]),
        count))

    if DoF.TurnSystem then
        DoF.TurnSystem:OnActionPerformed()
    end
end

function DoF.Combat:CancelTauntAoE()
    if not self.AoETauntState.active then return end

    self.AoETauntState = { active = false, tauntsLeft = 0, tauntedTargets = {} }

    if DoF.UI and DoF.UI.HideAoETauntPanel then
        DoF.UI:HideAoETauntPanel()
    end

    DoF.Utils:Warn(DoF.L["combat.def.mass_taunt_cancelled"])

    if DoF.TurnSystem then
        DoF.TurnSystem:OnActionPerformed()
    end
end

function DoF.Combat:IsTauntAoEActive()
    return self.AoETauntState and self.AoETauntState.active
end

-- ═══════════════════════════════════════════════════════════
-- МЕХАНИКА ТАНКА: ПЕРЕХВАТ УРОНА
-- ═══════════════════════════════════════════════════════════

function DoF.Combat:TankRedirect()
    if DoF.Stats:GetRole() ~= "tank" then
        DoF.Utils:Error(DoF.L["errors.tank_only_redirect"])
        return
    end

    if not DoF.Utils:RequireTurn(DoF.L["combat.action.redirect"]) then return end

    if self:IsAoEActive() or self:IsAoEHealActive() or self:IsAoEBuffActive() or self:IsTauntAoEActive() then
        DoF.Utils:Error(DoF.L["errors.finish_current_aoe"])
        return
    end

    local playerName = UnitName("player")

    -- Проверка кулдауна
    if DoF.Effects:Get("player", playerName, "cooldown_tank_redirect") then
        local cd = DoF.Effects:Get("player", playerName, "cooldown_tank_redirect")
        DoF.Utils:Error(DoF.Locale:Format("errors.redirect_cooldown", cd.remainingRounds or "?", DoF.Locale:Rounds(cd.remainingRounds or 0)))
        return
    end

    -- Проверка цели — союзник-игрок
    local guid, name = DoF.Utils:GetTargetGUID()
    if not guid then
        DoF.Utils:Error(DoF.L["errors.select_ally_target"])
        return
    end
    if not DoF.Utils:IsTargetPlayer() then
        DoF.Utils:Error(DoF.L["errors.redirect_players_only"])
        return
    end
    if name == playerName then
        DoF.Utils:Error(DoF.L["errors.redirect_not_self"])
        return
    end

    -- Применить бафф на союзника
    DoF.Effects:ApplyInternal("player", name, "tank_redirect", 0, 999, playerName)

    -- Кулдаун на танка
    DoF.Effects:ApplyInternal("player", playerName, "cooldown_tank_redirect", 0, 2)

    DoF.Utils:Info(DoF.Locale:Format("combat.def.taunt_applied", DoF.Utils:Color("FFD700", DoF.L["combat.label.redirect"]), DoF.Utils:Color("FFFFFF", name)))
    DoF.Sync:BroadcastCombatLog(string_format(DoF.L["combat.def.redirect_log"],
        DoF.Utils:Color("CC8040", playerName),
        DoF.Utils:Color("FFFFFF", name)))

    if DoF.TurnSystem then
        DoF.TurnSystem:OnActionPerformed()
    end
end
