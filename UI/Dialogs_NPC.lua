-- DoF/UI/Dialogs_NPC.lua
-- Диалоги мастера: настройка NPC, атака NPC, HP игрока

local ADDON_NAME, DoF = ...

-- Кэширование глобальных функций
local CreateFrame = CreateFrame
local tonumber = tonumber
local tostring = tostring


-- ═══════════════════════════════════════════════════════════
-- ДИАЛОГ НАСТРОЙКИ NPC (HP + Защита)
-- ═══════════════════════════════════════════════════════════

function DoF.Dialogs:ShowNPCSetupDialog()
    if not DoF.Utils:RequireMaster(false) then return end

    local guid, name = DoF.Utils:GetTargetGUID()

    if guid then
        if DoF.Utils:IsTargetPlayer() then
            DoF_NPCSetupDialog_TargetName:SetText(DoF.Locale:Format("ui.npcdlg.target_player", name))
        else
            local data = DoF.Units:Get(guid) or {}
            DoF_NPCSetupDialog_TargetName:SetText(name)
            -- Заполняем если поля пустые (первое открытие)
            if DoF_NPCSetupDialog_HPInput:GetText() == "" then
                if data.maxHp then
                    DoF_NPCSetupDialog_HPInput:SetText(tostring(data.maxHp))
                end
                DoF_NPCSetupDialog_FortInput:SetText(tostring(data.fort or 10))
                DoF_NPCSetupDialog_ReflexInput:SetText(tostring(data.reflex or 10))
                DoF_NPCSetupDialog_WillInput:SetText(tostring(data.will or 10))
            end
        end
    else
        DoF_NPCSetupDialog_TargetName:SetText(DoF.L["ui.npcdlg.no_target"])
        if DoF_NPCSetupDialog_FortInput:GetText() == "" then
            DoF_NPCSetupDialog_FortInput:SetText("10")
            DoF_NPCSetupDialog_ReflexInput:SetText("10")
            DoF_NPCSetupDialog_WillInput:SetText("10")
        end
    end

    DoF_NPCSetupDialog:Show()
    -- Снимаем фокус со всех полей, чтобы WASD работало
    DoF_NPCSetupDialog_HPInput:ClearFocus()
    DoF_NPCSetupDialog_FortInput:ClearFocus()
    DoF_NPCSetupDialog_ReflexInput:ClearFocus()
    DoF_NPCSetupDialog_WillInput:ClearFocus()
end

function DoF.Dialogs:ApplyNPCSetup()
    local guid, name = DoF.Utils:GetTargetGUID()
    if not guid then
        DoF.Utils:Error(DoF.L["errors.select_target"])
        return
    end

    if DoF.Utils:IsTargetPlayer() then
        DoF.Utils:Error(DoF.L["errors.cannot_setup_player"])
        return
    end

    local hp = tonumber(DoF_NPCSetupDialog_HPInput:GetText())
    if not hp or hp <= 0 then
        DoF.Utils:Error(DoF.L["errors.invalid_hp"])
        return
    end

    local fort = tonumber(DoF_NPCSetupDialog_FortInput:GetText()) or 10
    local reflex = tonumber(DoF_NPCSetupDialog_ReflexInput:GetText()) or 10
    local will = tonumber(DoF_NPCSetupDialog_WillInput:GetText()) or 10

    if DoF.Units:Set(guid, name, hp, hp, fort, reflex, will) then
        DoF.Utils:Info(DoF.Locale:Format("ui.npcdlg.setup_summary",
            DoF.Utils:Color("FFFFFF", name), DoF.Utils:Color("FF0000", hp), fort, reflex, will))
        if DoF.CombatLog then
            DoF.CombatLog:AddMasterLog(
                DoF.Locale:Format("ui.npcdlg.setup_log", name, hp, fort, reflex, will), "master_action")
        end
        DoF_NPCSetupDialog_TargetName:SetText(name)
    end
end

-- ═══════════════════════════════════════════════════════════
-- ДИАЛОГ ИЗМЕНЕНИЯ HP NPC
-- ═══════════════════════════════════════════════════════════

function DoF.Dialogs:ShowModifyNPCHPDialog()
    if not DoF.Utils:RequireMaster(false) then return end

    local guid, name = DoF.Utils:GetTargetGUID()

    -- Если есть цель, показываем её данные
    if guid then
        if DoF.Utils:IsTargetPlayer() then
            DoF_ModifyNPCHPDialog_TargetName:SetText(DoF.Locale:Format("ui.npcdlg.target_player", name))
        else
            local data = DoF.Units:Get(guid)
            if data then
                DoF_ModifyNPCHPDialog_TargetName:SetText(name .. " (" .. data.hp .. "/" .. data.maxHp .. ")")
            else
                DoF_ModifyNPCHPDialog_TargetName:SetText(DoF.Locale:Format("ui.npcdlg.hp_not_set", name))
            end
        end
    else
        DoF_ModifyNPCHPDialog_TargetName:SetText(DoF.L["ui.npcdlg.no_target"])
    end

    DoF_ModifyNPCHPDialog:Show()
end

function DoF.Dialogs:ApplyModifyNPCHP(direction)
    -- Берём ТЕКУЩУЮ цель, а не сохранённую при открытии
    local guid, name = DoF.Utils:GetTargetGUID()
    if not guid then
        DoF.Utils:Error(DoF.L["errors.select_target"])
        return
    end

    -- Только для NPC, не для игроков
    if DoF.Utils:IsTargetPlayer() then
        DoF.Utils:Error(DoF.L["errors.is_player_use_player_hp"])
        return
    end

    local amount = tonumber(DoF_ModifyNPCHPDialog_Input:GetText())
    if not amount or amount <= 0 then
        DoF.Utils:Error(DoF.L["errors.invalid_value"])
        return
    end

    local data = DoF.Units:Get(guid)
    if not data then
        DoF.Utils:Error(DoF.Locale:Format("errors.hp_not_set_for", name))
        return
    end

    local val = amount * direction
    local result
    if val < 0 then
        result = DoF.Units:Damage(guid, -val)
    else
        result = DoF.Units:Heal(guid, val)
    end
    if result then
        local txt = val > 0 and DoF.Utils:Color("00FF00", "+" .. amount) or DoF.Utils:Color("FF0000", "-" .. amount)
        DoF.Utils:Info(name .. ": " .. txt .. " HP (" .. data.hp .. "/" .. data.maxHp .. ")")
        if DoF.CombatLog then
            DoF.CombatLog:AddMasterLog(DoF.Locale:Format("ui.npcdlg.modify_log", name, val, data.hp, data.maxHp), "master_action")
        end

        if data.hp <= 0 then
            DoF.Utils:Print("FF0000", DoF.Locale:Format("ui.npcdlg.target_dead_msg", name))
        end

        -- Обновляем отображение в диалоге, значение НЕ очищаем
        DoF_ModifyNPCHPDialog_TargetName:SetText(name .. " (" .. data.hp .. "/" .. data.maxHp .. ")")
    end
end

-- ═══════════════════════════════════════════════════════════
-- ДИАЛОГ АТАКИ NPC
-- ═══════════════════════════════════════════════════════════

function DoF.Dialogs:ShowNPCAttackDialog()
    if not DoF.Utils:RequireMaster(false) then return end

    local name = DoF.Utils:RequirePlayerTarget(DoF.L["ui.npcdlg.attack_action"])
    if not name then return end

    DoF_NPCAttackDialog_TargetName:SetText(name)
    DoF_NPCAttackDialog_NPCNameInput:SetText(DoF_NPCAttackDialog.lastNPCName or "")
    DoF_NPCAttackDialog_DamageMinInput:SetText("1")
    DoF_NPCAttackDialog_DamageMaxInput:SetText("5")
    DoF_NPCAttackDialog_ThresholdInput:SetText("10")
    DoF_NPCAttackDialog.targetName = name
    DoF_NPCAttackDialog.targetGUID = guid
    DoF_NPCAttackDialog.selectedDefense = "Fortitude"
    DoF_NPCAttackDialog_DefenseDropdown:SetText(DoF.L["stats.fortitude.label"])
    -- Инициализация дебаффа
    DoF_NPCAttackDialog.selectedDebuff = nil
    DoF_NPCAttackDialog_DebuffDropdown:SetText(DoF.L["ui.common.none"])
    DoF_NPCAttackDialog_DebuffValueInput:SetText("")
    DoF_NPCAttackDialog_DebuffDurationInput:SetText("")
    DoF_NPCAttackDialog_DebuffValueInput:Hide()
    DoF_NPCAttackDialog_DebuffDurationInput:Hide()
    DoF_NPCAttackDialog_DebuffValueLabel:Hide()
    DoF_NPCAttackDialog_DebuffDurationLabel:Hide()
    DoF_NPCAttackDialog:Show()
    -- Снимаем фокус со всех полей, чтобы WASD работало
    DoF_NPCAttackDialog_NPCNameInput:ClearFocus()
    DoF_NPCAttackDialog_DamageMinInput:ClearFocus()
    DoF_NPCAttackDialog_DamageMaxInput:ClearFocus()
    DoF_NPCAttackDialog_ThresholdInput:ClearFocus()
    DoF_NPCAttackDialog_DebuffValueInput:ClearFocus()
    DoF_NPCAttackDialog_DebuffDurationInput:ClearFocus()

    -- Регистрируем событие смены таргета
    DoF_NPCAttackDialog:RegisterEvent("PLAYER_TARGET_CHANGED")
    DoF_NPCAttackDialog:SetScript("OnEvent", function(self, event)
        if event == "PLAYER_TARGET_CHANGED" and self:IsShown() then
            local newGuid, newName = DoF.Utils:GetTargetGUID()
            if newName and DoF.Utils:IsTargetPlayer() then
                self.targetName = newName
                self.targetGUID = newGuid
                DoF_NPCAttackDialog_TargetName:SetText(newName)
            end
        end
    end)

    -- При закрытии - отписываемся от события
    DoF_NPCAttackDialog:SetScript("OnHide", function(self)
        self:UnregisterEvent("PLAYER_TARGET_CHANGED")
    end)
end

local cachedDefenseMenu = nil

function DoF.Dialogs:ShowNPCAttackDefenseMenu(button)
    if not cachedDefenseMenu then
        cachedDefenseMenu = CreateFrame("Frame", "DoF_CustomDefenseMenu", UIParent, "TooltipBackdropTemplate")
        cachedDefenseMenu:SetSize(140, 105)
        cachedDefenseMenu:SetFrameStrata("TOOLTIP")
        cachedDefenseMenu:EnableMouse(true)

        local defenses = {
            {"Fortitude", DoF.L["stats.fortitude.label"]},
            {"Reflex",    DoF.L["stats.reflex.label"]},
            {"Will",      DoF.L["stats.will.label"]},
            {"Hybrid",    DoF.L["ui.dlg.hybrid"]},
        }

        local y = -6
        for _, def in ipairs(defenses) do
            local btn = CreateFrame("Button", nil, cachedDefenseMenu)
            btn:SetSize(130, 22)
            btn:SetPoint("TOPLEFT", cachedDefenseMenu, "TOPLEFT", 5, y)

            local hl = btn:CreateTexture(nil, "HIGHLIGHT")
            hl:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
            hl:SetBlendMode("ADD")
            hl:SetAllPoints(btn)

            btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            btn.text:SetPoint("LEFT", 8, 0)
            btn.text:SetText(def[2])

            btn:SetScript("OnClick", function()
                DoF_NPCAttackDialog.selectedDefense = def[1]
                DoF_NPCAttackDialog_DefenseDropdown:SetText(def[2])
                cachedDefenseMenu:Hide()
            end)
            y = y - 24
        end

        cachedDefenseMenu:SetScript("OnUpdate", function(self)
            if not self:IsMouseOver() and IsMouseButtonDown("LeftButton") then
                self:Hide()
            end
        end)
    end

    cachedDefenseMenu:ClearAllPoints()
    cachedDefenseMenu:SetPoint("TOPLEFT", button, "BOTTOMLEFT", 0, -2)
    cachedDefenseMenu:Show()
end

local cachedDebuffMenu = nil

function DoF.Dialogs:ShowNPCAttackDebuffMenu(button)
    if not cachedDebuffMenu then
        cachedDebuffMenu = CreateFrame("Frame", "DoF_CustomDebuffMenu", UIParent, "TooltipBackdropTemplate")
        cachedDebuffMenu:SetSize(170, 220)
        cachedDebuffMenu:SetFrameStrata("TOOLTIP")
        cachedDebuffMenu:EnableMouse(true)

        local debuffs = {
            { nil,                       DoF.L["ui.common.none"] },
            { "stun",                    DoF.L["effects.stun.name"] },
            { "weakness_damage",         DoF.L["ui.npcdlg.debuff_weakness_damage"] },
            { "weakness_healing",        DoF.L["ui.npcdlg.debuff_weakness_healing"] },
            { "vulnerability_fortitude", DoF.L["ui.npcdlg.debuff_vuln_fortitude"] },
            { "vulnerability_reflex",    DoF.L["ui.npcdlg.debuff_vuln_reflex"] },
            { "vulnerability_will",      DoF.L["ui.npcdlg.debuff_vuln_will"] },
            { "dot_master",              DoF.L["ui.npcdlg.debuff_dot"] },
        }

        local y = -6
        for _, def in ipairs(debuffs) do
            local btn = CreateFrame("Button", nil, cachedDebuffMenu)
            btn:SetSize(160, 22)
            btn:SetPoint("TOPLEFT", cachedDebuffMenu, "TOPLEFT", 5, y)

            local hl = btn:CreateTexture(nil, "HIGHLIGHT")
            hl:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
            hl:SetBlendMode("ADD")
            hl:SetAllPoints(btn)

            btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            btn.text:SetPoint("LEFT", 8, 0)
            btn.text:SetText(def[2])

            btn:SetScript("OnClick", function()
                DoF_NPCAttackDialog.selectedDebuff = def[1]
                DoF_NPCAttackDialog_DebuffDropdown:SetText(def[2])
                cachedDebuffMenu:Hide()
                -- Показать/скрыть поля значения и длительности
                if def[1] == nil then
                    DoF_NPCAttackDialog_DebuffValueInput:Hide()
                    DoF_NPCAttackDialog_DebuffDurationInput:Hide()
                    DoF_NPCAttackDialog_DebuffValueLabel:Hide()
                    DoF_NPCAttackDialog_DebuffDurationLabel:Hide()
                elseif def[1] == "stun" then
                    DoF_NPCAttackDialog_DebuffValueInput:Hide()
                    DoF_NPCAttackDialog_DebuffValueLabel:Hide()
                    DoF_NPCAttackDialog_DebuffDurationInput:Show()
                    DoF_NPCAttackDialog_DebuffDurationLabel:Show()
                else
                    DoF_NPCAttackDialog_DebuffValueInput:Show()
                    DoF_NPCAttackDialog_DebuffValueLabel:Show()
                    DoF_NPCAttackDialog_DebuffDurationInput:Show()
                    DoF_NPCAttackDialog_DebuffDurationLabel:Show()
                end
            end)
            y = y - 24
        end

        cachedDebuffMenu:SetScript("OnUpdate", function(self)
            if not self:IsMouseOver() and IsMouseButtonDown("LeftButton") then
                self:Hide()
            end
        end)
    end

    cachedDebuffMenu:ClearAllPoints()
    cachedDebuffMenu:SetPoint("TOPLEFT", button, "BOTTOMLEFT", 0, -2)
    cachedDebuffMenu:Show()
end

function DoF.Dialogs:ApplyNPCAttack()
    local target = DoF_NPCAttackDialog.targetName
    local npcName = DoF_NPCAttackDialog_NPCNameInput:GetText() or ""
    local damageMin = tonumber(DoF_NPCAttackDialog_DamageMinInput:GetText())
    local damageMax = tonumber(DoF_NPCAttackDialog_DamageMaxInput:GetText())
    local threshold = tonumber(DoF_NPCAttackDialog_ThresholdInput:GetText())
    local defense = DoF_NPCAttackDialog.selectedDefense or "Fortitude"

    if not target or not damageMin or not damageMax or not threshold or damageMin <= 0 or damageMax <= 0 then
        DoF.Utils:Error(DoF.L["errors.invalid_values"])
        return
    end

    if damageMin > damageMax then
        damageMin, damageMax = damageMax, damageMin
    end

    local debuffId = DoF_NPCAttackDialog.selectedDebuff  -- nil если "Нет"
    local debuffValue = tonumber(DoF_NPCAttackDialog_DebuffValueInput:GetText()) or 0
    local debuffDuration = tonumber(DoF_NPCAttackDialog_DebuffDurationInput:GetText()) or 0

    -- Запоминаем имя для повторных атак
    if npcName ~= "" then
        DoF_NPCAttackDialog.lastNPCName = npcName
    end

    DoF.Combat:NPCAttack(target, damageMin, damageMax, threshold, defense, npcName, debuffId, debuffValue, debuffDuration)
    -- Окно остаётся открытым для быстрых повторных атак
end

-- ═══════════════════════════════════════════════════════════
-- ДИАЛОГ HP ИГРОКА (мастер)
-- ═══════════════════════════════════════════════════════════

function DoF.Dialogs:ShowModifyPlayerHPDialog()
    if not DoF.Utils:RequireMaster(false) then return end

    local guid, name = DoF.Utils:GetTargetGUID()

    -- Если есть цель, проверяем что это игрок
    if guid then
        if DoF.Utils:IsTargetPlayer() then
            DoF_ModifyPlayerHPDialog_TargetName:SetText(name)
        else
            DoF_ModifyPlayerHPDialog_TargetName:SetText("|cFFFF6666" .. name .. " (NPC)|r")
        end
    else
        DoF_ModifyPlayerHPDialog_TargetName:SetText(DoF.L["ui.npcdlg.no_player"])
    end

    DoF_ModifyPlayerHPDialog:Show()
end

function DoF.Dialogs:ApplyModifyPlayerHP(direction)
    -- Берём ТЕКУЩУЮ цель, а не сохранённую при открытии
    local guid, name = DoF.Utils:GetTargetGUID()
    if not guid then
        DoF.Utils:Error(DoF.L["errors.select_player"])
        return
    end

    -- Только для игроков, не для NPC
    if not DoF.Utils:IsTargetPlayer() then
        DoF.Utils:Error(DoF.L["errors.is_npc_use_npc_hp"])
        return
    end

    local amount = tonumber(DoF_ModifyPlayerHPDialog_Input:GetText())
    if not amount or amount <= 0 then
        DoF.Utils:Error(DoF.L["errors.invalid_value"])
        return
    end

    local value = amount * direction
    DoF.Combat:ModifyPlayerHP(name, value)

    -- Обновляем имя цели в заголовке, значение НЕ очищаем
    DoF_ModifyPlayerHPDialog_TargetName:SetText(name)
end

-- ═══════════════════════════════════════════════════════════
-- МЕНЮ ДЕЙСТВИЙ МАСТЕРА НАД ИГРОКОМ
-- ═══════════════════════════════════════════════════════════

function DoF.Dialogs:ShowPlayerActionsMenu(button)
    if not DoF.Utils:RequireMaster(false) then return end

    local name = DoF.Utils:RequirePlayerTarget()
    if not name then return end

    local items = {
        { text = DoF.Locale:Format("ui.npcdlg.actions_for", name), isTitle = true, notCheckable = true },
        { text = " ", isTitle = true, notCheckable = true },

        -- HP
        { text = DoF.L["ui.npcdlg.change_hp"], notCheckable = true,
          func = function() self:ShowModifyPlayerHPDialog() end },

        { text = " ", isTitle = true, notCheckable = true },

        -- Роль
        { text = DoF.L["ui.npcdlg.change_role"], notCheckable = true,
          func = function() self:ShowSetSpecMenu(name) end },

        { text = " ", isTitle = true, notCheckable = true },

        -- Ранения
        { text = DoF.L["ui.npcdlg.add_wound"], notCheckable = true,
          func = function() DoF.Sync:AddWound(name) end },
        { text = DoF.L["ui.npcdlg.remove_wound"], notCheckable = true,
          func = function() DoF.Sync:RemoveWound(name) end },
    }

    if not self.cachedPlayerActionsFrame then
        self.cachedPlayerActionsFrame = CreateFrame("Frame", "DoF_PlayerActionsMenu", UIParent, "UIDropDownMenuTemplate")
    end
    EasyMenu(items, self.cachedPlayerActionsFrame, button, 0, 0, "MENU")
end
