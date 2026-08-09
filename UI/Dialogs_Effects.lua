-- DoF/UI/Dialogs_Effects.lua
-- Диалоги мастера: применение эффектов, баффы, ослабления, уязвимости

local ADDON_NAME, DoF = ...

-- Кэширование глобальных функций
local CreateFrame = CreateFrame
local pairs = pairs
local ipairs = ipairs
local tonumber = tonumber
local tostring = tostring
local math_min = math.min
local table_insert = table.insert
local PlaySound = PlaySound

-- ═══════════════════════════════════════════════════════════
-- ДИАЛОГ МАСТЕРА: ПРИМЕНЕНИЕ ЭФФЕКТА
-- ═══════════════════════════════════════════════════════════

local MasterEffectDialog = nil

function DoF.Dialogs:ShowMasterEffectDialog(effectId, targetType, targetId)
    if not DoF.Sync:IsMaster() then
        DoF.Utils:Error(DoF.L["errors.gm_only_function"])
        return
    end

    local def = DoF.Effects.Definitions[effectId]
    if not def then
        DoF.Utils:Error(DoF.Locale:Format("errors.unknown_effect", effectId))
        return
    end

    -- Закрываем старый диалог
    if MasterEffectDialog then
        MasterEffectDialog:Hide()
    end

    -- Для stun не нужно поле "Значение"
    local needsValue = (effectId ~= "stun")
    local dialogHeight = needsValue and 200 or 170

    -- Создаём диалог
    local f = CreateFrame("Frame", "DoF_MasterEffectDialog", UIParent, "DoF_DialogTemplate")
    f:SetSize(240, dialogHeight)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f.Header:Setup(def.name)

    -- Имя цели
    local targetName = targetType == "npc"
        and (DoF.Units:Get(targetId) and DoF.Units:Get(targetId).name or "NPC")
        or targetId
    local targetText = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    targetText:SetPoint("TOP", 0, -38)
    targetText:SetText(DoF.Locale:Format("ui.buff.target", targetName))

    local valueInput = nil
    local nextY = -70

    -- Поле "Значение" (только если нужно)
    if needsValue then
        local valueLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        valueLabel:SetPoint("TOPLEFT", 25, nextY)
        valueLabel:SetText(DoF.L["ui.dlg.value_label"])

        valueInput = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
        valueInput:SetSize(60, 20)
        valueInput:SetPoint("TOPRIGHT", -25, nextY + 3)
        valueInput:SetJustifyH("CENTER")
        valueInput:SetAutoFocus(false)
        valueInput:SetNumeric(true)
        valueInput:SetText("3")
        valueInput:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        valueInput:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)

        nextY = nextY - 27
    end

    -- Поле "Раунды"
    local durationLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    durationLabel:SetPoint("TOPLEFT", 25, nextY)
    durationLabel:SetText(DoF.L["ui.dlg.rounds_label"])

    local durationInput = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
    durationInput:SetSize(60, 20)
    durationInput:SetPoint("TOPRIGHT", -25, nextY + 3)
    durationInput:SetJustifyH("CENTER")
    durationInput:SetAutoFocus(false)
    durationInput:SetNumeric(true)
    durationInput:SetText("2")
    durationInput:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    durationInput:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)

    -- Кнопка "Применить"
    local applyBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    applyBtn:SetSize(90, 24)
    applyBtn:SetPoint("BOTTOMLEFT", 20, 16)
    applyBtn:SetText(DoF.L["ui.common.apply"])
    applyBtn:SetScript("OnClick", function()
        local value = needsValue and (tonumber(valueInput:GetText()) or 0) or 0
        local duration = tonumber(durationInput:GetText()) or 0

        if needsValue and value <= 0 then
            DoF.Utils:Error(DoF.L["errors.value_must_be_positive"])
            return
        end
        if duration <= 0 then
            DoF.Utils:Error(DoF.L["errors.duration_must_be_positive"])
            return
        end

        DoF.Effects:MasterApply(targetType, targetId, effectId, value, duration)
        f:Hide()
    end)

    -- Кнопка "Отмена"
    local cancelBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    cancelBtn:SetSize(90, 24)
    cancelBtn:SetPoint("BOTTOMRIGHT", -20, 16)
    cancelBtn:SetText(DoF.L["ui.common.cancel"])
    cancelBtn:SetScript("OnClick", function() f:Hide() end)

    MasterEffectDialog = f
    f:Show()
    if valueInput then
        valueInput:SetFocus()
    else
        durationInput:SetFocus()
    end
end

-- ═══════════════════════════════════════════════════════════
-- ДИАЛОГ БАФФОВ МАСТЕРА
-- ═══════════════════════════════════════════════════════════

local MasterBuffDialog = nil

function DoF.Dialogs:ShowMasterBuffDialog(targetName)
    if not DoF.Sync:IsMaster() then
        DoF.Utils:Error(DoF.L["errors.gm_only_function"])
        return
    end

    -- Закрываем старый диалог
    if MasterBuffDialog then
        MasterBuffDialog:Hide()
    end

    local f = CreateFrame("Frame", "DoF_MasterBuffDialog", UIParent, "DoF_DialogTemplate")
    f:SetSize(290, 420)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f.Header:Setup(DoF.L["ui.dlg.apply_buff_title"])

    -- Имя цели
    local targetText = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    targetText:SetPoint("TOP", 0, -30)
    targetText:SetText(DoF.Locale:Format("ui.buff.target", targetName))

    -- Список баффов
    local buffs = {
        { id = "empower_strength", name = DoF.L["ui.buff.empower_strength.name"], desc = DoF.L["ui.buff.empower_strength.desc"], color = "FF6666" },
        { id = "empower_dexterity", name = DoF.L["ui.buff.empower_dexterity.name"], desc = DoF.L["ui.buff.empower_dexterity.desc"], color = "66FF66" },
        { id = "empower_intelligence", name = DoF.L["ui.buff.empower_intelligence.name"], desc = DoF.L["ui.buff.empower_intelligence.desc"], color = "66CCFF" },
        { id = "empower_spirit", name = DoF.L["ui.buff.empower_spirit.name"], desc = DoF.L["ui.buff.empower_spirit.desc"], color = "FFE066" },
        { id = "empower_damage", name = DoF.L["ui.buff.empower_damage.name"], desc = DoF.L["ui.buff.empower_damage.desc"], color = "FF9933" },
        { id = "empower_healing", name = DoF.L["ui.buff.empower_healing.name"], desc = DoF.L["ui.buff.empower_healing.desc"], color = "33E666" },
        { id = "fortify_fortitude", name = DoF.L["ui.buff.fortify_fortitude.name"], desc = DoF.L["ui.buff.fortify_fortitude.desc"], color = "A330C9" },
        { id = "fortify_reflex", name = DoF.L["ui.buff.fortify_reflex.name"], desc = DoF.L["ui.buff.fortify_reflex.desc"], color = "FF7D0A" },
        { id = "fortify_will", name = DoF.L["ui.buff.fortify_will.name"], desc = DoF.L["ui.buff.fortify_will.desc"], color = "8787ED" },
        { id = "fortify_hp", name = DoF.L["ui.buff.fortify_hp.name"], desc = DoF.L["ui.buff.fortify_hp.desc"], color = "33CC33" },
    }

    local yOffset = -55
    for _, buff in ipairs(buffs) do
        local btn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        btn:SetSize(250, 24)
        btn:SetPoint("TOP", 0, yOffset)

        local txt = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        txt:SetPoint("LEFT", 10, 0)
        txt:SetText(buff.name)

        local desc = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        desc:SetPoint("RIGHT", -10, 0)
        desc:SetTextColor(0.6, 0.6, 0.6)
        desc:SetText(buff.desc)

        btn:SetScript("OnClick", function()
            local def = DoF.Effects.Definitions[buff.id]
            if def then
                DoF.Effects:MasterApply("player", targetName, buff.id, def.fixedValue, def.fixedDuration)
            end
            f:Hide()
        end)

        yOffset = yOffset - 28
    end

    -- Кнопка "Отмена"
    local cancelBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    cancelBtn:SetSize(100, 24)
    cancelBtn:SetPoint("BOTTOM", 0, 15)
    cancelBtn:SetText(DoF.L["ui.common.cancel"])
    cancelBtn:SetScript("OnClick", function() f:Hide() end)

    MasterBuffDialog = f
    f:Show()
end

-- ═══════════════════════════════════════════════════════════
-- ДИАЛОГ ОСЛАБЛЕНИЯ (Weakness) - разные варианты для NPC/Игрока
-- ═══════════════════════════════════════════════════════════

local WeaknessDialog = nil

function DoF.Dialogs:ShowWeaknessDialog(targetType, targetId, targetName)
    if not DoF.Sync:IsMaster() then
        DoF.Utils:Error(DoF.L["errors.gm_only_function"])
        return
    end

    -- Закрываем старый диалог
    if WeaknessDialog then
        WeaknessDialog:Hide()
    end

    local isNPC = targetType == "npc"
    local dialogHeight = isNPC and 180 or 200

    -- Создаём диалог
    local f = CreateFrame("Frame", "DoF_WeaknessDialog", UIParent, "DoF_DialogTemplate")
    f:SetSize(260, dialogHeight + 30)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f.Header:Setup(DoF.L["ui.action.weaken"])

    -- Имя цели
    local targetText = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    targetText:SetPoint("TOP", 0, -30)
    targetText:SetText(DoF.Locale:Format("ui.buff.target", targetName))

    local selectedStat = nil
    local statButtons = {}

    if isNPC then
        -- Для NPC: выбор защитного стата
        local statLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        statLabel:SetPoint("TOPLEFT", 15, -55)
        statLabel:SetText(DoF.L["ui.dlg.weaken_defense_label"])

        local stats = {
            { id = "fortitude", name = DoF.L["stats.fortitude.label"], color = "A330C9" },
            { id = "reflex", name = DoF.L["stats.reflex.label"], color = "FF7D0A" },
            { id = "will", name = DoF.L["stats.will.label"], color = "8787ED" },
        }

        local function UpdateWeakStats()
            for _, b in ipairs(statButtons) do
                if b.statId == selectedStat then b:LockHighlight() else b:UnlockHighlight() end
            end
        end

        for i, stat in ipairs(stats) do
            local btn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
            btn:SetSize(70, 22)
            btn:SetPoint("TOPLEFT", 20 + (i-1) * 74, -68)
            btn:SetText(stat.name)
            btn.statId = stat.id
            btn:SetScript("OnClick", function()
                selectedStat = stat.id
                UpdateWeakStats()
            end)
            table.insert(statButtons, btn)
        end
        selectedStat = "fortitude"
        UpdateWeakStats()
    else
        -- Для Игрока: выбор урон/исцеление
        local typeLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        typeLabel:SetPoint("TOPLEFT", 20, -55)
        typeLabel:SetText(DoF.L["ui.dlg.reduce_label"])

        local types = {
            { id = "damage", name = DoF.L["ui.common.damage"] },
            { id = "healing", name = DoF.L["ui.common.healing"] },
        }

        local function UpdateWeakTypes()
            for _, b in ipairs(statButtons) do
                if b.typeId == selectedStat then b:LockHighlight() else b:UnlockHighlight() end
            end
        end

        for i, t in ipairs(types) do
            local btn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
            btn:SetSize(100, 22)
            btn:SetPoint("TOPLEFT", 20 + (i-1) * 108, -68)
            btn:SetText(t.name)
            btn.typeId = t.id
            btn:SetScript("OnClick", function()
                selectedStat = t.id
                UpdateWeakTypes()
            end)
            table.insert(statButtons, btn)
        end
        selectedStat = "damage"
        UpdateWeakTypes()
    end

    -- Поле "Значение"
    local valueLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    valueLabel:SetPoint("TOPLEFT", 20, -102)
    valueLabel:SetText(DoF.L["ui.dlg.penalty_label"])

    local valueInput = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
    valueInput:SetSize(60, 20)
    valueInput:SetPoint("TOPRIGHT", -20, -100)
    valueInput:SetJustifyH("CENTER")
    valueInput:SetAutoFocus(false)
    valueInput:SetNumeric(true)
    valueInput:SetText("2")
    valueInput:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    valueInput:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)

    -- Поле "Раунды"
    local durationLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    durationLabel:SetPoint("TOPLEFT", 20, -128)
    durationLabel:SetText(DoF.L["ui.dlg.rounds_label"])

    local durationInput = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
    durationInput:SetSize(60, 20)
    durationInput:SetPoint("TOPRIGHT", -20, -126)
    durationInput:SetJustifyH("CENTER")
    durationInput:SetAutoFocus(false)
    durationInput:SetNumeric(true)
    durationInput:SetText("2")
    durationInput:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    durationInput:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)

    -- Кнопка "Применить"
    local applyBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    applyBtn:SetSize(100, 24)
    applyBtn:SetPoint("BOTTOMLEFT", 20, 15)
    applyBtn:SetText(DoF.L["ui.common.apply"])
    applyBtn:SetScript("OnClick", function()
        local value = tonumber(valueInput:GetText()) or 0
        local duration = tonumber(durationInput:GetText()) or 0

        if value <= 0 then
            DoF.Utils:Error(DoF.L["errors.value_must_be_positive"])
            return
        end
        if duration <= 0 then
            DoF.Utils:Error(DoF.L["errors.duration_must_be_positive"])
            return
        end
        if not selectedStat then
            DoF.Utils:Error(DoF.L["errors.select_weaken_type"])
            return
        end

        -- Определяем эффект на основе выбора
        local effectId = "weakness_" .. selectedStat

        DoF.Effects:MasterApply(targetType, targetId, effectId, value, duration)
        f:Hide()
    end)

    -- Кнопка "Отмена"
    local cancelBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    cancelBtn:SetSize(100, 24)
    cancelBtn:SetPoint("BOTTOMRIGHT", -20, 15)
    cancelBtn:SetText(DoF.L["ui.common.cancel"])
    cancelBtn:SetScript("OnClick", function() f:Hide() end)

    WeaknessDialog = f
    f:Show()
end

-- ═══════════════════════════════════════════════════════════
-- ДИАЛОГ УЯЗВИМОСТИ (Vulnerability) - выбор защитного стата
-- ═══════════════════════════════════════════════════════════

local VulnerabilityDialog = nil

function DoF.Dialogs:ShowVulnerabilityDialog(targetType, targetId, targetName)
    if not DoF.Sync:IsMaster() then
        DoF.Utils:Error(DoF.L["errors.gm_only_function"])
        return
    end

    -- Закрываем старый диалог
    if VulnerabilityDialog then
        VulnerabilityDialog:Hide()
    end

    -- Создаём диалог
    local f = CreateFrame("Frame", "DoF_VulnerabilityDialog", UIParent, "DoF_DialogTemplate")
    f:SetSize(260, 215)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f.Header:Setup(DoF.L["ui.dlg.vulnerability_title"])

    -- Имя цели
    local targetText = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    targetText:SetPoint("TOP", 0, -30)
    targetText:SetText(DoF.Locale:Format("ui.buff.target", targetName))

    -- Выбор защитного стата
    local statLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    statLabel:SetPoint("TOPLEFT", 15, -55)
    statLabel:SetText(DoF.L["ui.dlg.defense_stat_label"])

    local selectedStat = "fortitude"
    local statButtons = {}

    local stats = {
        { id = "fortitude", name = DoF.L["stats.fortitude.label"], color = "A330C9" },
        { id = "reflex", name = DoF.L["stats.reflex.label"], color = "FF7D0A" },
        { id = "will", name = DoF.L["stats.will.label"], color = "8787ED" },
    }

    local function UpdateVulnStats()
        for _, b in ipairs(statButtons) do
            if b.statId == selectedStat then b:LockHighlight() else b:UnlockHighlight() end
        end
    end

    for i, stat in ipairs(stats) do
        local btn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        btn:SetSize(70, 22)
        btn:SetPoint("TOPLEFT", 20 + (i-1) * 74, -68)
        btn:SetText(stat.name)
        btn.statId = stat.id
        btn:SetScript("OnClick", function()
            selectedStat = stat.id
            UpdateVulnStats()
        end)
        table.insert(statButtons, btn)
    end
    UpdateVulnStats()

    -- Поле "Значение"
    local valueLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    valueLabel:SetPoint("TOPLEFT", 20, -102)
    valueLabel:SetText(DoF.L["ui.dlg.penalty_label"])

    local valueInput = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
    valueInput:SetSize(60, 20)
    valueInput:SetPoint("TOPRIGHT", -20, -100)
    valueInput:SetJustifyH("CENTER")
    valueInput:SetAutoFocus(false)
    valueInput:SetNumeric(true)
    valueInput:SetText("2")
    valueInput:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    valueInput:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)

    -- Поле "Раунды"
    local durationLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    durationLabel:SetPoint("TOPLEFT", 20, -128)
    durationLabel:SetText(DoF.L["ui.dlg.rounds_label"])

    local durationInput = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
    durationInput:SetSize(60, 20)
    durationInput:SetPoint("TOPRIGHT", -20, -126)
    durationInput:SetJustifyH("CENTER")
    durationInput:SetAutoFocus(false)
    durationInput:SetNumeric(true)
    durationInput:SetText("2")
    durationInput:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    durationInput:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)

    -- Кнопка "Применить"
    local applyBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    applyBtn:SetSize(100, 24)
    applyBtn:SetPoint("BOTTOMLEFT", 20, 15)
    applyBtn:SetText(DoF.L["ui.common.apply"])
    applyBtn:SetScript("OnClick", function()
        local value = tonumber(valueInput:GetText()) or 0
        local duration = tonumber(durationInput:GetText()) or 0

        if value <= 0 then
            DoF.Utils:Error(DoF.L["errors.value_must_be_positive"])
            return
        end
        if duration <= 0 then
            DoF.Utils:Error(DoF.L["errors.duration_must_be_positive"])
            return
        end

        local effectId = "vulnerability_" .. selectedStat
        DoF.Effects:MasterApply(targetType, targetId, effectId, value, duration)
        f:Hide()
    end)

    -- Кнопка "Отмена"
    local cancelBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    cancelBtn:SetSize(100, 24)
    cancelBtn:SetPoint("BOTTOMRIGHT", -20, 15)
    cancelBtn:SetText(DoF.L["ui.common.cancel"])
    cancelBtn:SetScript("OnClick", function() f:Hide() end)

    VulnerabilityDialog = f
    f:Show()
end

-- ═══════════════════════════════════════════════════════════
-- ДИАЛОГ ОСЛАБЛЕНИЯ NPC ИГРОКОМ (выбор защитного стата)
-- ═══════════════════════════════════════════════════════════

local PlayerWeakenDialog = nil

function DoF.Dialogs:ShowPlayerWeakenNPCDialog(npcGuid, npcName)
    -- Закрываем старый диалог
    if PlayerWeakenDialog then
        PlayerWeakenDialog:Hide()
    end

    if not DoF.Utils:RequireEnergy(1, DoF.L["ui.action.weaken"]) then return end

    if not DoF.Utils:RequireTurn(DoF.L["ui.action.weaken"]) then return end

    -- Создаём диалог
    local f = CreateFrame("Frame", "DoF_PlayerWeakenDialog", UIParent, "DoF_DialogTemplate")
    f:SetSize(240, 140)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f.Header:Setup(DoF.L["ui.dlg.weaken_defense_title"])

    -- Имя цели
    local targetText = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    targetText:SetPoint("TOP", 0, -30)
    targetText:SetText(DoF.Locale:Format("ui.buff.target", npcName or "NPC"))

    -- Подсказка
    local hintText = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hintText:SetPoint("TOP", 0, -48)
    hintText:SetTextColor(0.7, 0.7, 0.7)
    hintText:SetText(DoF.L["ui.dlg.weaken_hint"])

    -- Кнопки выбора стата
    local stats = {
        { id = "fortitude", name = DoF.L["stats.fortitude.label"] },
        { id = "reflex",    name = DoF.L["stats.reflex.label"] },
        { id = "will",      name = DoF.L["stats.will.label"] },
    }

    for i, stat in ipairs(stats) do
        local btn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        btn:SetSize(75, 24)
        btn:SetPoint("BOTTOM", (i - 2) * 80, 14)

        local weakDef = DoF.Effects.Definitions["weakness_" .. stat.id]
        if weakDef then
            local icon = btn:CreateTexture(nil, "OVERLAY")
            icon:SetSize(14, 14)
            icon:SetPoint("LEFT", 4, 0)
            icon:SetTexture(weakDef.icon)
        end

        btn:SetText(stat.name)

        btn:SetScript("OnClick", function()
            -- Применяем ослабление
            local effectId = "weakness_" .. stat.id
            local randomValue = math.random(1, 3)
            local duration = 3

            DoF.Effects:PlayerApplyWeaken(npcGuid, effectId, randomValue, duration)
            f:Hide()
        end)
    end

    PlayerWeakenDialog = f
    f:Show()
end

-- ═══════════════════════════════════════════════════════════
-- ДИАЛОГ БРОСКА ОСОБОГО ДЕЙСТВИЯ
-- ═══════════════════════════════════════════════════════════

local cachedSpecialActionDialog = nil

function DoF.Dialogs:ShowSpecialActionRollDialog(threshold, stat, description, requireEnergy, energyAmount, actionType, actionParams, noRoll)
    actionType = actionType or "simple_roll"
    actionParams = actionParams or ""

    -- Используем названия и цвета из конфига
    local statName = DoF.Config.StatNames[stat] or stat
    local statColor = DoF.Config.StatColors[stat] or "FFFFFF"
    local modifier = DoF.Stats and DoF.Stats:GetTotal(stat) or 0

    if not cachedSpecialActionDialog then
        local f = CreateFrame("Frame", "DoF_SpecialActionRollDialog", UIParent, "DoF_DialogTemplate")
        f:SetSize(420, 310)
        f:SetPoint("CENTER", 0, 100)
        f:SetFrameStrata("DIALOG")
        f.Header:Setup(DoF.L["ui.dlg.special_approved"])

        f.descContainer = CreateFrame("Frame", nil, f, "InsetFrameTemplate")
        f.descContainer:SetPoint("TOPLEFT", 15, -45)
        f.descContainer:SetPoint("TOPRIGHT", -15, -45)
        f.descContainer:SetHeight(80)

        f.scrollFrame = CreateFrame("ScrollFrame", nil, f.descContainer, "UIPanelScrollFrameTemplate")
        f.scrollFrame:SetPoint("TOPLEFT", 5, -5)
        f.scrollFrame:SetPoint("BOTTOMRIGHT", -25, 5)

        f.scrollContent = CreateFrame("Frame", nil, f.scrollFrame)
        f.scrollContent:SetSize(330, 1)
        f.scrollFrame:SetScrollChild(f.scrollContent)

        f.desc = f.scrollContent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        f.desc:SetPoint("TOPLEFT", 5, 0)
        f.desc:SetWidth(320)
        f.desc:SetWordWrap(true)
        f.desc:SetJustifyH("LEFT")
        f.desc:SetJustifyV("TOP")
        f.desc:SetTextColor(0.9, 0.9, 0.9)

        -- Строка типа действия
        f.actionInfo = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        f.actionInfo:SetPoint("TOP", 0, -140)

        f.rollInfo = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        f.rollInfo:SetPoint("TOP", 0, -160)

        f.rollBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        f.rollBtn:SetSize(180, 30)
        f.rollBtn:SetPoint("BOTTOM", 0, 18)
        f.rollBtn:SetText(DoF.L["ui.dlg.roll_dice"])
        f.rollBtn.text = f.rollBtn:GetFontString()  -- алиас для старого кода

        cachedSpecialActionDialog = f
    end

    -- Обновляем динамический контент
    local f = cachedSpecialActionDialog
    f.desc:SetText(description or "")
    f.scrollContent:SetHeight(math.max(50, f.desc:GetStringHeight() + 10))

    -- Строка типа действия
    local actionTypeName = DoF.Config.SpecialActionTypes[actionType] or actionType
    local actionDetail = ""
    if actionType == "buff" or actionType == "aoe_buff" then
        local effectId = actionParams:match("([^|]+)")
        if effectId and DoF.Effects and DoF.Effects.Definitions and DoF.Effects.Definitions[effectId] then
            actionDetail = " (" .. DoF.Effects.Definitions[effectId].name .. ")"
        end
        local _, tc = actionParams:match("([^|]+)|(%d+)")
        if tc and tonumber(tc) > 1 then actionDetail = actionDetail .. " x" .. tc end
    elseif actionType == "attack" then
        local dmgMin, dmgMax = actionParams:match("(%d+)|(%d+)")
        if dmgMin then actionDetail = DoF.Locale:Format("ui.dlg.damage_detail", dmgMin, dmgMax) end
    elseif actionType == "aoe_attack" then
        local dmgMin, dmgMax, tc = actionParams:match("(%d+)|(%d+)|(%d+)")
        if dmgMin then actionDetail = DoF.Locale:Format("ui.dlg.damage_detail_multi", dmgMin, dmgMax, tc) end
    end

    if actionType ~= "simple_roll" then
        f.actionInfo:SetText(DoF.Locale:Format("ui.dlg.action_line", actionTypeName, actionDetail))
        f.actionInfo:Show()
    else
        f.actionInfo:SetText("")
        f.actionInfo:Hide()
    end

    -- Строка броска
    if noRoll then
        f.rollInfo:SetText(DoF.L["ui.dlg.no_roll"])
        f.rollBtn.text:SetText(DoF.L["ui.dlg.perform_action"])
    else
        local rollText = DoF.Locale:Format("ui.dlg.roll_line", statColor, statName, threshold)
        if requireEnergy and energyAmount and energyAmount > 0 then
            rollText = rollText .. DoF.Locale:Format("ui.dlg.energy_line", energyAmount)
        end
        f.rollInfo:SetText(rollText)
        f.rollBtn.text:SetText(DoF.L["ui.dlg.roll_dice_colored"])
    end

    f.rollBtn:SetScript("OnClick", function()
        f:Hide()
        DoF.Combat:ProcessSpecialActionRoll(threshold, stat, description, requireEnergy, energyAmount, actionType, actionParams, noRoll)
    end)

    f:Show()
    PlaySound(8959, "SFX")
end

-- ═══════════════════════════════════════════════════════════
-- МЕНЮ ВЫБОРА КОНКРЕТНОГО ЭФФЕКТА (для диспела/пуржа)
-- ═══════════════════════════════════════════════════════════

local EffectSelectionMenu = nil
local MAX_EFFECT_ITEMS = 10

function DoF.Dialogs:ShowEffectSelectionMenu(targetType, targetId, filterType, callback, anchorFrame, persistent)
    -- filterType: "debuff" (debuffs + master dots) или "buff" (баффы + пассивки NPC)
    -- callback(effectId, effectDef, isPassive) — вызывается при выборе
    -- persistent: если true — меню нельзя закрыть кликом вне окна (после ролла)

    local effects = DoF.Effects:GetAll(targetType, targetId)
    local items = {}
    for effectId, effectData in pairs(effects) do
        local def = DoF.Effects.Definitions[effectId]
        if def then
            local match = false
            if filterType == "debuff" then
                match = def.category ~= "system" and (def.type == "debuff" or (def.type == "dot" and def.category == "master"))
            elseif filterType == "buff" then
                match = def.type == "buff"
            end
            if match then
                local durText = ""
                if effectData.duration and effectData.duration > 0 then
                    durText = DoF.Locale:Format("ui.dlg.duration_short", effectData.duration)
                end
                table_insert(items, {
                    id = effectId,
                    def = def,
                    name = def.name .. durText,
                    color = def.color or {1, 1, 1},
                    isPassive = false,
                })
            end
        end
    end

    -- Для баффов NPC: также включаем пассивки, которые можно снять
    if filterType == "buff" and targetType == "npc" and DoF.Passives then
        local npcData = DoF.Units:Get(targetId)
        if npcData and npcData.passives then
            for passiveId, passiveCfg in pairs(npcData.passives) do
                if not passiveCfg.unpurgeable then
                    local pDef = DoF.Passives.Definitions[passiveId]
                    if pDef then
                        table_insert(items, {
                            id = passiveId,
                            def = pDef,
                            name = pDef.name .. DoF.L["ui.dlg.passive_suffix"],
                            color = pDef.color or {0.8, 0.6, 0.2},
                            isPassive = true,
                        })
                    end
                end
            end
        end
    end

    if #items == 0 then
        local msg = filterType == "buff" and DoF.L["ui.dlg.no_buffs"] or DoF.L["ui.dlg.no_debuffs"]
        DoF.Utils:Error(msg)
        return
    end

    -- Если только 1 эффект — сразу выбираем его
    if #items == 1 then
        callback(items[1].id, items[1].def, items[1].isPassive)
        return
    end

    -- Создаём или переиспользуем меню
    if not EffectSelectionMenu then
        EffectSelectionMenu = CreateFrame("Frame", "DoF_EffectSelectionMenu", UIParent, "TooltipBackdropTemplate")
        EffectSelectionMenu:SetFrameStrata("TOOLTIP")
        EffectSelectionMenu:EnableMouse(true)

        EffectSelectionMenu.buttons = {}
        for i = 1, MAX_EFFECT_ITEMS do
            local btn = CreateFrame("Button", nil, EffectSelectionMenu)
            btn:SetSize(180, 22)

            local hl = btn:CreateTexture(nil, "HIGHLIGHT")
            hl:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
            hl:SetBlendMode("ADD")
            hl:SetAllPoints(btn)

            btn.icon = btn:CreateTexture(nil, "ARTWORK")
            btn.icon:SetSize(16, 16)
            btn.icon:SetPoint("LEFT", 6, 0)

            btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            btn.text:SetPoint("LEFT", btn.icon, "RIGHT", 4, 0)
            btn.text:SetPoint("RIGHT", -4, 0)
            btn.text:SetJustifyH("LEFT")

            btn:Hide()
            EffectSelectionMenu.buttons[i] = btn
        end

    end

    EffectSelectionMenu.persistent = persistent or false

    -- Persistent: страта DIALOG + без авто-закрытия (только выбор закрывает)
    -- Обычный: страта TOOLTIP + клик вне окна закрывает
    if persistent then
        EffectSelectionMenu:SetFrameStrata("DIALOG")
        EffectSelectionMenu:SetScript("OnUpdate", nil)
    else
        EffectSelectionMenu:SetFrameStrata("TOOLTIP")
        EffectSelectionMenu:SetScript("OnUpdate", function(self)
            if not self:IsMouseOver() and IsMouseButtonDown("LeftButton") then
                self:Hide()
            end
        end)
    end

    -- Заполняем кнопки
    local count = math_min(#items, MAX_EFFECT_ITEMS)
    for i = 1, MAX_EFFECT_ITEMS do
        local btn = EffectSelectionMenu.buttons[i]
        if i <= count then
            local item = items[i]
            btn.text:SetText(item.name)
            btn.text:SetTextColor(item.color[1], item.color[2], item.color[3])
            if item.def.icon then
                btn.icon:SetTexture(item.def.icon)
                btn.icon:Show()
            else
                btn.icon:Hide()
            end
            btn:ClearAllPoints()
            btn:SetPoint("TOPLEFT", EffectSelectionMenu, "TOPLEFT", 4, -4 - (i - 1) * 24)
            btn:SetScript("OnClick", function()
                EffectSelectionMenu:Hide()
                callback(item.id, item.def, item.isPassive)
            end)
            btn:Show()
        else
            btn:Hide()
        end
    end

    EffectSelectionMenu:SetSize(188, 8 + count * 24)

    EffectSelectionMenu:ClearAllPoints()
    if anchorFrame then
        EffectSelectionMenu:SetPoint("TOPLEFT", anchorFrame, "BOTTOMLEFT", 0, -2)
    else
        EffectSelectionMenu:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end
    EffectSelectionMenu:Show()
end

-- ═══════════════════════════════════════════════════════════
-- ДИАЛОГ НАСТРОЙКИ ПАССИВКИ NPC
-- ═══════════════════════════════════════════════════════════

local PassiveConfigDialog = nil
local MAX_PASSIVE_FIELDS = 6

-- Маппинг dropdown-значений на русские названия
local DROPDOWN_LABELS = {
    mode = { guaranteed = DoF.L["ui.dlg.mode_guaranteed"], chance = DoF.L["ui.dlg.mode_chance"] },
    defenseStat = { Fortitude = DoF.L["stats.fortitude.label"], Reflex = DoF.L["stats.reflex.label"], Will = DoF.L["stats.will.label"], Hybrid = DoF.L["ui.dlg.hybrid"] },
}

local function GetDropdownLabel(key, value)
    return DROPDOWN_LABELS[key] and DROPDOWN_LABELS[key][value] or tostring(value)
end

-- Создать фрейм диалога один раз
local function EnsurePassiveConfigDialog()
    if PassiveConfigDialog then return PassiveConfigDialog end

    local f = CreateFrame("Frame", "DoF_PassiveConfigDialog", UIParent, "DoF_DialogTemplate")
    f:SetSize(290, 280)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")

    -- Цель (заголовок задаётся через f.Header:Setup в ShowPassiveConfigDialog)
    f.target = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.target:SetPoint("TOP", 0, -30)

    -- Описание
    f.desc = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.desc:SetPoint("TOPLEFT", 20, -54)
    f.desc:SetWidth(250)
    f.desc:SetJustifyH("LEFT")
    f.desc:SetWordWrap(true)
    f.desc:SetTextColor(0.6, 0.6, 0.6)

    -- Пул полей (6 строк)
    f.fieldRows = {}
    for i = 1, MAX_PASSIVE_FIELDS do
        local row = {}

        -- Label
        row.label = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        row.label:SetJustifyH("LEFT")

        -- EditBox (для number)
        row.editBox = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
        row.editBox:SetSize(70, 20)
        row.editBox:SetJustifyH("CENTER")
        row.editBox:SetAutoFocus(false)
        row.editBox:SetNumeric(true)
        row.editBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        row.editBox:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)

        -- Toggle Button (для dropdown/checkbox)
        row.toggleBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        row.toggleBtn:SetSize(100, 20)
        row.toggleBtn.text = row.toggleBtn:GetFontString()

        -- Скрываем всё по умолчанию
        row.label:Hide()
        row.editBox:Hide()
        row.toggleBtn:Hide()

        f.fieldRows[i] = row
    end

    -- Переключатель "Не снимаемая"
    f.unpurgeBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    f.unpurgeBtn:SetSize(140, 20)
    f.unpurgeBtn.text = f.unpurgeBtn:GetFontString()
    f.unpurgeBtn:SetScript("OnClick", function()
        f._config.unpurgeable = not f._config.unpurgeable
        local isUp = f._config.unpurgeable
        f.unpurgeBtn:SetText(isUp and DoF.L["ui.dlg.unpurgeable"] or DoF.L["ui.dlg.purgeable"])
    end)

    -- Кнопка "Применить"
    f.applyBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    f.applyBtn:SetSize(110, 24)
    f.applyBtn:SetPoint("BOTTOMLEFT", 20, 16)
    f.applyBtn:SetText(DoF.L["ui.common.apply"])

    -- Кнопка "Отмена"
    f.cancelBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    f.cancelBtn:SetSize(110, 24)
    f.cancelBtn:SetPoint("BOTTOMRIGHT", -20, 16)
    f.cancelBtn:SetText(DoF.L["ui.common.cancel"])
    f.cancelBtn:SetScript("OnClick", function() f:Hide() end)

    PassiveConfigDialog = f
    return f
end

-- Расставить поля по определению пассивки, вернуть высоту диалога
local function LayoutPassiveConfigFields(f)
    local pdef = DoF.Passives.Definitions[f._passiveId]
    if not pdef or not pdef.fields then return end

    -- Скрываем все строки
    for i = 1, MAX_PASSIVE_FIELDS do
        f.fieldRows[i].label:Hide()
        f.fieldRows[i].editBox:Hide()
        f.fieldRows[i].toggleBtn:Hide()
    end

    -- Вычисляем Y начала полей: после описания
    local descBottom = f.desc:GetStringHeight() or 30
    local fieldsStartY = -(54 + descBottom + 10)
    local rowIndex = 0

    for _, fieldDef in ipairs(pdef.fields) do
        -- showIf: пропускаем скрытые поля
        if fieldDef.showIf and f._config.mode ~= fieldDef.showIf then
            -- поле скрыто
        else
            rowIndex = rowIndex + 1
            if rowIndex > MAX_PASSIVE_FIELDS then break end

            local row = f.fieldRows[rowIndex]
            local rowY = fieldsStartY - (rowIndex - 1) * 30

            -- Label
            row.label:SetText(fieldDef.name)
            row.label:ClearAllPoints()
            row.label:SetPoint("TOPLEFT", f, "TOPLEFT", 15, rowY)
            row.label:Show()

            if fieldDef.type == "number" then
                row.editBox:SetText(tostring(f._config[fieldDef.key] or fieldDef.default or 0))
                row.editBox:ClearAllPoints()
                row.editBox:SetPoint("TOPRIGHT", f, "TOPRIGHT", -15, rowY + 1)
                row.editBox._fieldKey = fieldDef.key
                row.editBox._min = fieldDef.min
                row.editBox._max = fieldDef.max
                row.editBox:Show()
                row.toggleBtn:Hide()

            elseif fieldDef.type == "dropdown" then
                local currentVal = f._config[fieldDef.key] or fieldDef.default
                row.toggleBtn.text:SetText(GetDropdownLabel(fieldDef.key, currentVal))
                row.toggleBtn:ClearAllPoints()
                row.toggleBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -15, rowY)
                row.toggleBtn:SetScript("OnClick", function()
                    -- Циклический переключатель
                    local opts = fieldDef.options
                    local cur = f._config[fieldDef.key] or fieldDef.default
                    local idx = 1
                    for oi, ov in ipairs(opts) do
                        if ov == cur then idx = oi break end
                    end
                    idx = (idx % #opts) + 1
                    f._config[fieldDef.key] = opts[idx]
                    row.toggleBtn.text:SetText(GetDropdownLabel(fieldDef.key, opts[idx]))
                    -- Если сменился mode — перестроить видимость полей
                    if fieldDef.key == "mode" then
                        LayoutPassiveConfigFields(f)
                    end
                end)
                row.toggleBtn:Show()
                row.editBox:Hide()

            elseif fieldDef.type == "checkbox" then
                local isOn = f._config[fieldDef.key]
                local onText = DoF.L["ui.dlg.on"]
                local offText = DoF.L["ui.dlg.off"]
                row.toggleBtn.text:SetText(isOn and onText or offText)
                row.toggleBtn:ClearAllPoints()
                row.toggleBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -15, rowY)
                row.toggleBtn:SetScript("OnClick", function()
                    f._config[fieldDef.key] = not f._config[fieldDef.key]
                    row.toggleBtn.text:SetText(f._config[fieldDef.key] and onText or offText)
                end)
                row.toggleBtn:Show()
                row.editBox:Hide()
            end
        end
    end

    -- Переключатель "Не снимаемая"
    local unpurgeY = fieldsStartY - rowIndex * 30 - 10
    f.unpurgeBtn:ClearAllPoints()
    f.unpurgeBtn:SetPoint("TOPLEFT", f, "TOPLEFT", 15, unpurgeY)
    local isUp = f._config.unpurgeable
    f.unpurgeBtn.text:SetText(isUp and DoF.L["ui.dlg.unpurgeable_colored"] or DoF.L["ui.dlg.purgeable_colored"])
    f.unpurgeBtn:Show()

    -- Высота = от верха до кнопок (15px от низа + 26px кнопка + 15px зазор)
    local totalHeight = math.abs(unpurgeY) + 20 + 15 + 26 + 15
    f:SetHeight(totalHeight)
end

function DoF.Dialogs:ShowPassiveConfigDialog(passiveId, guid, existingConfig)
    local pdef = DoF.Passives.Definitions[passiveId]
    if not pdef then return end

    local data = DoF.Units:Get(guid)
    if not data then
        DoF.Utils:Error(DoF.L["errors.npc_not_found"])
        return
    end

    local f = EnsurePassiveConfigDialog()
    f:Hide()

    -- Сохраняем контекст
    f._passiveId = passiveId
    f._guid = guid

    -- Собираем конфиг: из существующего или из дефолтов
    local config = {}
    if pdef.fields then
        for _, field in ipairs(pdef.fields) do
            if existingConfig and existingConfig[field.key] ~= nil then
                config[field.key] = existingConfig[field.key]
            else
                config[field.key] = field.default
            end
        end
    end
    if existingConfig and existingConfig.unpurgeable then
        config.unpurgeable = true
    end
    f._config = config

    f.Header:Setup(pdef.name)
    f.target:SetText(DoF.Locale:Format("ui.buff.target", data.name or "NPC"))

    -- Описание
    f.desc:SetText("|cFF888888" .. (pdef.description or "") .. "|r")

    -- Расставляем поля и вычисляем высоту
    LayoutPassiveConfigFields(f)

    -- Обработчик "Применить"
    f.applyBtn:SetScript("OnClick", function()
        -- Перепроверка NPC
        local unitData = DoF.Units:Get(f._guid)
        if not unitData then
            DoF.Utils:Error(DoF.L["errors.npc_no_longer_exists"])
            f:Hide()
            return
        end

        -- Собираем значения из полей
        local finalConfig = {}
        local curDef = DoF.Passives.Definitions[f._passiveId]
        if curDef and curDef.fields then
            for _, fieldDef in ipairs(curDef.fields) do
                if fieldDef.type == "number" then
                    -- Ищем EditBox с этим ключом
                    local val = f._config[fieldDef.key]
                    for ri = 1, MAX_PASSIVE_FIELDS do
                        local row = f.fieldRows[ri]
                        if row.editBox:IsShown() and row.editBox._fieldKey == fieldDef.key then
                            val = row.editBox:GetNumber()
                            break
                        end
                    end
                    -- Клэмп по min/max
                    if fieldDef.min and val < fieldDef.min then val = fieldDef.min end
                    if fieldDef.max and val > fieldDef.max then val = fieldDef.max end
                    finalConfig[fieldDef.key] = val
                else
                    -- dropdown/checkbox — уже в f._config
                    finalConfig[fieldDef.key] = f._config[fieldDef.key]
                end
            end
        end
        finalConfig.unpurgeable = f._config.unpurgeable or nil

        DoF.Passives:Add(f._guid, f._passiveId, finalConfig)
        DoF.Utils:Info(DoF.Locale:Format("ui.dlg.passive_added", DoF.Utils:Color("FFD700", curDef.name), unitData.name or "NPC"))

        if DoF.Sync and IsInGroup() then
            DoF.Sync:BroadcastUnit(f._guid, unitData)
        end
        DoF.Events:Fire("UNIT_CREATED", f._guid, unitData)

        f:Hide()
    end)

    f:Show()
end
