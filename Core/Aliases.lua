-- DoF/Core/Aliases.lua
-- Алиасы функций для вызова из XML и совместимости
-- Компактная версия с автогенерацией

local ADDON_NAME, DoF = ...

-- ═══════════════════════════════════════════════════════════
-- АВТОГЕНЕРАЦИЯ АЛИАСОВ
-- ═══════════════════════════════════════════════════════════

-- Формат: { "DoF:Method", "Module", "ModuleMethod" }
-- Если ModuleMethod не указан, используется Method
local aliases = {
    -- Combat
    { "Attack", "Combat" },
    { "Heal", "Combat" },
    { "Shield", "Combat" },
    { "StartAoEShield", "Combat" },
    { "AoEShieldHit", "Combat" },
    { "EndAoEShield", "Combat" },
    { "CancelAoEShield", "Combat" },
    { "DoCheck", "Combat", "Check" },
    { "ProcessNPCAttack", "Combat" },
    { "ProcessModifyHP", "Combat" },
    { "ProcessHeal", "Combat" },
    { "ProcessShield", "Combat" },

    -- UI
    { "ToggleGMPanel", "UI" },
    { "SetGMPanelTab", "UI" },
    { "ToggleMasterFrame", "UI", "ToggleGMPanel" },
    { "MasterAddWound", "UI" },
    { "MasterRemoveWound", "UI" },
    { "MasterSetSpec", "UI" },
    { "MasterSetLevel", "UI" },
    { "MasterLevelUp", "UI" },
    { "MasterLevelDown", "UI" },
    { "MasterResetStats", "UI" },
    { "MasterGiveShield", "UI" },
    { "MasterSync", "UI" },
    { "MasterGiveEnergy", "UI" },
    { "MasterTakeEnergy", "UI" },
    { "MasterRestoreEnergy", "UI" },

    -- NPCLibrary
    { "ToggleNPCLibrary", "UI" },
    { "ShowNPCLibrary", "UI" },

    -- Dialogs
    { "ShowAttackMenu", "Dialogs" },
    { "ShowCheckMenu", "Dialogs" },
    { "ShowNPCSetupDialog", "Dialogs" },
    { "ApplyNPCSetup", "Dialogs" },
    { "ShowHelpWindow", "Dialogs" },
    { "ShowModifyNPCHPDialog", "Dialogs" },
    { "ApplyModifyNPCHP", "Dialogs" },
    { "ShowNPCAttackDialog", "Dialogs" },
    { "ShowNPCAttackDefenseMenu", "Dialogs" },
    { "ShowNPCAttackDebuffMenu", "Dialogs" },
    { "ApplyNPCAttack", "Dialogs" },
    { "ShowModifyPlayerHPDialog", "Dialogs" },
    { "ApplyModifyPlayerHP", "Dialogs" },
    { "ShowPlayerActionsMenu", "Dialogs" },
    { "ShowSpecDialog", "Dialogs" },
    -- CombatLog
    { "AddToCombatLog", "CombatLog", "Add" },
    { "AddToMasterLog", "CombatLog", "AddMasterLog" },
    { "ToggleCombatLog", "CombatLog", "Toggle" },
    
    -- Танк: бонусные способности
    { "TankTaunt", "Combat" },
    { "TankTauntAoE", "Combat" },
    { "TankTauntTarget", "Combat" },
    { "TankRedirect", "Combat" },
    { "EndTauntAoE", "Combat" },
    { "CancelTauntAoE", "Combat" },

    -- TurnSystem
    { "StartCombat", "TurnSystem" },
    { "EndCombat", "TurnSystem" },
    { "NPCTurn", "TurnSystem", "StartNPCTurn" },
    { "PlayersTurn", "TurnSystem", "StartPlayersTurn" },
    { "AddToCombat", "TurnSystem", "AddParticipant" },
    { "RemoveFromCombat", "TurnSystem", "RemoveParticipant" },
    { "GiveFreeAction", "TurnSystem" },
    { "CanAct", "TurnSystem" },
    { "IsMyTurn", "TurnSystem" },
    { "IsCombatActive", "TurnSystem", "IsActive" },
    { "OnActionPerformed", "TurnSystem" },
}

-- Генерируем алиасы
for _, alias in ipairs(aliases) do
    local method, module, target = alias[1], alias[2], alias[3] or alias[1]
    DoF[method] = function(self, ...)
        local mod = DoF[module]
        if mod and mod[target] then
            return mod[target](mod, ...)
        end
    end
end

-- ═══════════════════════════════════════════════════════════
-- СПЕЦИАЛЬНЫЕ АЛИАСЫ (с логикой)
-- ═══════════════════════════════════════════════════════════

function DoF:ShowTooltip(frame, title, desc)
    DoF.UI:ShowModernTooltip(frame, title, desc)
end

function DoF:ModifyPlayerHealth(amount)
    -- Блокируем изменение HP когда в группе с мастером
    if not DoF.Stats:CanModifyHP() then
        DoF.Utils:Error(DoF.L["errors.hp_change_blocked"])
        return
    end
    DoF.Stats:ModifyHP(amount)
    if DoF.Sync then DoF.Sync:BroadcastPlayerData() end
end

function DoF:RemoveTargetHP()
    local guid, name = DoF.Utils:GetTargetGUID()
    if not guid then
        DoF.Utils:Error(DoF.L["errors.no_target"])
        return
    end
    if DoF.Units then
        DoF.Units:Remove(guid)
        DoF.Utils:Info(DoF.Locale:Format("core.alias.removed", name))
    end
end

function DoF:ClearAllNPCConfirm()
    if DoF.Units then DoF.Units:ClearAllConfirm() end
end

function DoF:SkipTurn()
    if DoF.Sync:IsMaster() then
        DoF.TurnSystem:SkipTurn()
    else
        DoF.TurnSystem:PlayerSkipTurn()
    end
end

function DoF:ToggleTurnQueue()
    if DoF.UI and DoF.UI.ToggleTurnQueue then
        DoF.UI:ToggleTurnQueue()
    end
end


-- ═══════════════════════════════════════════════════════════
-- GM ПАНЕЛЬ - ПОШАГОВЫЙ БОЙ
-- ═══════════════════════════════════════════════════════════

function DoF:UpdateExcludeMasterButton()
    local btn = DoF_GMPanel_ExcludeMasterBtn
    if not btn then return end

    if btn.excludeMaster then
        btn:SetText(DoF.L["xml.queue_no_leader"])
    else
        btn:SetText(DoF.L["core.alias.queue_with_leader"])
    end
end

-- Переключение режима боя (радиокнопки)
function DoF:GMToggleModeCheckbox(checkbox, mode)
    local freeBtn = DoF_GMPanel_ModeFreeCheckBtn
    local queueBtn = DoF_GMPanel_ModeQueueCheckBtn

    if mode == "free" then
        freeBtn:SetChecked(true)
        queueBtn:SetChecked(false)
    else
        freeBtn:SetChecked(false)
        queueBtn:SetChecked(true)
    end
end

-- Переключение использования таймера
function DoF:GMToggleTimerCheckbox()
    local timerCheckbox = DoF_GMPanel_UseTimerCheckBtn
    local timerFrame = DoF_GMPanel_TimerFrame

    if timerCheckbox:GetChecked() then
        timerFrame:Show()
    else
        timerFrame:Hide()
    end
end

-- Переключение мгновенной защиты
function DoF:GMToggleInstantDefense()
    local cb = DoF_GMPanel_InstantDefenseCheckBtn
    if not cb then return end
    DoF.Combat.instantDefense = cb:GetChecked() and true or false
end

-- Получить выбранный режим
function DoF:GMGetSelectedMode()
    local freeBtn = DoF_GMPanel_ModeFreeCheckBtn
    if freeBtn and freeBtn:GetChecked() then
        return "free"
    else
        return "queue"
    end
end

-- Получить настройку таймера
function DoF:GMGetUseTimer()
    local timerCheckbox = DoF_GMPanel_UseTimerCheckBtn
    return timerCheckbox and timerCheckbox:GetChecked() or false
end

function DoF:GMStartCombat()
    if DoF.TurnSystem:IsActive() then
        DoF.TurnSystem:EndCombat()
    else
        -- Получаем режим боя
        local mode = self:GMGetSelectedMode()

        -- Получаем настройку таймера
        local useTimer = self:GMGetUseTimer()

        -- Получаем длительность (только если таймер включен)
        local duration = 60
        if useTimer then
            local timerInput = DoF_GMPanel_TimerFrame_Input
            duration = timerInput and tonumber(timerInput:GetText()) or 60
            duration = math.max(10, math.min(300, duration))
        end

        local btn = DoF_GMPanel_ExcludeMasterBtn
        local excludeMaster = btn and btn.excludeMaster or false

        -- Запускаем бой с новой сигнатурой
        DoF.TurnSystem:StartCombat(mode, useTimer, duration, excludeMaster)
    end
    DoF.UI:UpdateGMCombatButtons()
end

function DoF:GMSkipTurn()
    if not DoF.TurnSystem:IsActive() then
        DoF.Utils:Error(DoF.L["errors.combat_not_started"])
        return
    end
    DoF.TurnSystem:SkipTurn()
end

function DoF:GMToggleNPCTurn()
    if not DoF.TurnSystem:IsActive() then
        DoF.Utils:Error(DoF.L["errors.combat_not_started"])
        return
    end
    
    if DoF.TurnSystem.phase == "npc" then
        DoF.TurnSystem:StartPlayersTurn()
    else
        DoF.TurnSystem:StartNPCTurn()
    end
    DoF.UI:UpdateGMCombatButtons()
end

function DoF:GMFreeAction()
    if not DoF.TurnSystem:IsActive() then
        DoF.Utils:Error(DoF.L["errors.combat_not_started"])
        return
    end

    -- Если уже есть freeAction — отменить
    if DoF.TurnSystem.freeActionGUID then
        DoF.TurnSystem.freeActionGUID = nil
        DoF.TurnSystem:BroadcastFreeAction(nil)
        DoF.Utils:Info(DoF.L["core.alias.extra_turn_cancelled"])
        if DoF.UI and DoF.UI.UpdateTurnQueue then
            DoF.UI:UpdateTurnQueue()
        end
        return
    end

    local target = UnitName("target")
    if not target then
        DoF.Utils:Error(DoF.L["errors.select_player"])
        return
    end

    if not UnitIsPlayer("target") then
        DoF.Utils:Error(DoF.L["errors.target_must_be_player"])
        return
    end

    DoF.TurnSystem:GiveFreeAction(target)
end

-- ═══════════════════════════════════════════════════════════
-- КНОПКИ ЭФФЕКТОВ МАСТЕРА (GM Panel)
-- ═══════════════════════════════════════════════════════════

function DoF:MasterApplyStun()
    if not DoF.Utils:RequireMaster(false) then return end
    local guid, name = DoF.Utils:GetTargetGUID()
    if not guid then
        DoF.Utils:Error(DoF.L["errors.select_target"])
        return
    end
    local isPlayer = DoF.Utils:IsTargetPlayer()
    local targetType = isPlayer and "player" or "npc"
    local targetId = isPlayer and name or guid
    DoF.Dialogs:ShowMasterEffectDialog("stun", targetType, targetId)
end

function DoF:MasterApplyDot()
    if not DoF.Utils:RequireMaster(false) then return end
    local guid, name = DoF.Utils:GetTargetGUID()
    if not guid then
        DoF.Utils:Error(DoF.L["errors.select_target"])
        return
    end
    local isPlayer = DoF.Utils:IsTargetPlayer()
    local targetType = isPlayer and "player" or "npc"
    local targetId = isPlayer and name or guid
    DoF.Dialogs:ShowMasterEffectDialog("dot_master", targetType, targetId)
end

function DoF:MasterApplyVulnerability()
    if not DoF.Utils:RequireMaster(false) then return end
    local guid, name = DoF.Utils:GetTargetGUID()
    if not guid then
        DoF.Utils:Error(DoF.L["errors.select_target"])
        return
    end
    local isPlayer = DoF.Utils:IsTargetPlayer()
    local targetType = isPlayer and "player" or "npc"
    local targetId = isPlayer and name or guid
    local targetName = isPlayer and name or (DoF.Units:Get(guid) and DoF.Units:Get(guid).name or "NPC")
    DoF.Dialogs:ShowVulnerabilityDialog(targetType, targetId, targetName)
end

function DoF:MasterApplyWeakness()
    if not DoF.Utils:RequireMaster(false) then return end
    local guid, name = DoF.Utils:GetTargetGUID()
    if not guid then
        DoF.Utils:Error(DoF.L["errors.select_target"])
        return
    end
    
    local targetType = UnitIsPlayer("target") and "player" or "npc"
    local targetId = targetType == "player" and name or guid
    
    DoF.Dialogs:ShowWeaknessDialog(targetType, targetId, name)
end

function DoF:MasterApplyBuff()
    if not DoF.Utils:RequireMaster(false) then return end
    local name = DoF.Utils:RequirePlayerTarget()
    if not name then return end
    DoF.Dialogs:ShowMasterBuffDialog(name)
end

function DoF:MasterPurge()
    if not DoF.Utils:RequireMaster(false) then return end
    local guid, name = DoF.Utils:GetTargetGUID()
    if not guid then
        DoF.Utils:Error(DoF.L["errors.select_target"])
        return
    end

    local targetType = UnitIsPlayer("target") and "player" or "npc"
    local targetId = targetType == "player" and name or guid

    DoF.Dialogs:ShowEffectSelectionMenu(targetType, targetId, "buff", function(effectId, def, isPassive)
        if isPassive then
            DoF.Passives:Remove(targetId, effectId)
            -- Синхронизируем NPC данные после удаления пассивки
            if DoF.Sync then DoF.Sync:BroadcastUnit(targetId, DoF.Units:Get(targetId)) end
            DoF.Utils:Info(DoF.Locale:Format("core.alias.passive_removed", def.name, name))
        else
            DoF.Effects:Remove(targetType, targetId, effectId)
            DoF.Utils:Info(DoF.Locale:Format("core.alias.buff_removed", def.name, name))
        end
    end)
end

function DoF:MasterDispel()
    if not DoF.Utils:RequireMaster(false) then return end
    local guid, name = DoF.Utils:GetTargetGUID()
    if not guid then
        DoF.Utils:Error(DoF.L["errors.select_target"])
        return
    end

    local targetType = UnitIsPlayer("target") and "player" or "npc"
    local targetId = targetType == "player" and name or guid

    DoF.Dialogs:ShowEffectSelectionMenu(targetType, targetId, "debuff", function(effectId, def)
        DoF.Effects:Remove(targetType, targetId, effectId)
        -- Если снимаем усталость лечения — сбрасываем внутренние стаки
        if effectId == "healing_fatigue" and DoF.Combat and DoF.Combat.HealingFatigue then
            DoF.Combat.HealingFatigue[targetId] = nil
        end
        DoF.Utils:Info(DoF.Locale:Format("core.alias.debuff_removed", def.name, name))
    end)
end

function DoF:MasterClearAllEffects()
    if not DoF.Utils:RequireMaster(false) then return end
    local guid, name = DoF.Utils:GetTargetGUID()
    if not guid then
        DoF.Utils:Error(DoF.L["errors.select_target"])
        return
    end
    
    local targetType = UnitIsPlayer("target") and "player" or "npc"
    local targetId = targetType == "player" and name or guid
    
    DoF.Effects:ClearTarget(targetType, targetId)
    -- Сбрасываем внутренние данные усталости лечения
    if targetType == "player" and DoF.Combat and DoF.Combat.HealingFatigue then
        DoF.Combat.HealingFatigue[targetId] = nil
    end
    DoF.Utils:Info(DoF.Locale:Format("core.alias.all_effects_removed", name))
end
