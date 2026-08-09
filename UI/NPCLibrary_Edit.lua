-- DoF/UI/NPCLibrary_Edit.lua
-- Диалог создания/редактирования шаблона NPC

local ADDON_NAME, DoF = ...

DoF.UI = DoF.UI or {}

local ipairs = ipairs
local tonumber = tonumber
local table_insert = table.insert
local table_remove = table.remove

local DIALOG_W = 380
local MAX_EDIT_ATTACKS = 6
local ATTACK_BLOCK_H_BASE = 76    -- 3 строки (без дебаффа)
local ATTACK_BLOCK_H_DEBUFF = 100 -- 4 строки (с дебаффом)
local MAX_EDIT_PASSIVES = 6
local PASSIVE_BLOCK_H = 50
local PASSIVE_BLOCK_H_EXT = 68   -- с доп. строкой (defenseStat)
local SECTION_HEADER_H = 20
local MAX_SCROLL_H = 360

local editFrame = nil
local editTemplateId = nil -- nil = создание, иначе редактирование
local editAttacks = {}     -- рабочая копия атак
local editPassives = {}    -- рабочая копия пассивок: { { id = "thorns", ... }, ... }
local CollectEditAttacks   -- forward declaration

-- Справочники
local DEFENSES = {
    { "Fortitude", DoF.L["stats.fortitude.label"], { r = 0.64, g = 0.19, b = 0.79 } },
    { "Reflex",    DoF.L["stats.reflex.label"],  { r = 1, g = 0.49, b = 0.04 } },
    { "Will",      DoF.L["stats.will.label"],      { r = 0.53, g = 0.53, b = 0.93 } },
    { "Hybrid",    DoF.L["ui.dlg.hybrid"],    { r = 0.2, g = 0.8, b = 0.8 } },
}

local DEBUFFS = {
    { nil,                       DoF.L["ui.common.none"],             { r = 0.5, g = 0.5, b = 0.5 } },
    { "stun",                    DoF.L["effects.stun.name"],       { r = 1, g = 1, b = 0 } },
    { "weakness_damage",         DoF.L["ui.npcdlg.debuff_weakness_damage"],   { r = 0.8, g = 0.4, b = 0.4 } },
    { "weakness_healing",        DoF.L["ui.npcdlg.debuff_weakness_healing"], { r = 0.6, g = 0.8, b = 0.5 } },
    { "vulnerability_fortitude", DoF.L["ui.npcdlg.debuff_vuln_fortitude"],  { r = 0.64, g = 0.19, b = 0.79 } },
    { "vulnerability_reflex",    DoF.L["ui.npcdlg.debuff_vuln_reflex"],   { r = 1, g = 0.49, b = 0.04 } },
    { "vulnerability_will",      DoF.L["ui.npcdlg.debuff_vuln_will"],    { r = 0.53, g = 0.53, b = 0.93 } },
    { "dot_master",              DoF.L["ui.npcdlg.debuff_dot"],    { r = 0.8, g = 0.2, b = 0.2 } },
}

-- ===========================================================
-- ВСПОМОГАТЕЛЬНЫЕ
-- ===========================================================

-- Кнопка в игровом стиле UIPanelButtonTemplate с уменьшенным шрифтом.
-- Алиас btn.text = font string, чтобы старый код btn.text:SetText(...) работал.
local function CreateSmallButton(parent, w, h, text, onClick)
    local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    btn:SetSize(w, h)
    btn:SetNormalFontObject("GameFontNormalSmall")
    btn:SetHighlightFontObject("GameFontHighlightSmall")
    btn:SetText(text or "")
    btn.text = btn:GetFontString()
    if onClick then btn:SetScript("OnClick", onClick) end
    return btn
end

local function CreateEditBox(parent, width, numeric)
    local eb = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    eb:SetSize(width, 20)
    eb:SetAutoFocus(false)
    if numeric then eb:SetNumeric(true) end
    eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    eb:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    return eb
end

-- GetNumber() возвращает 0 при пустом поле, а 0 в Lua — truthy,
-- поэтому "GetNumber() or default" не работает. Эта функция корректно подставляет default.
local function numOrDefault(editBox, default, minVal)
    local val = editBox:GetNumber()
    if val < (minVal or 1) then return default end
    return val
end

local function CreateLabel(parent, text)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fs:SetText(text)
    fs:SetTextColor(0.7, 0.7, 0.7)
    return fs
end

local function GetDefenseName(stat)
    for _, d in ipairs(DEFENSES) do
        if d[1] == stat then return d[2] end
    end
    return DoF.L["stats.fortitude.label"]
end

local function GetDebuffName(id)
    for _, d in ipairs(DEBUFFS) do
        if d[1] == id then return d[2] end
    end
    return DoF.L["ui.common.none"]
end

-- ===========================================================
-- СОЗДАНИЕ ДРОПДАУН-МЕНЮ (с callback)
-- ===========================================================

local function ShowDropdownMenu(items, anchorBtn, onSelect)
    -- Переиспользуем один общий фрейм дропдауна (стиль tooltip)
    if not DoF._libraryDropdown then
        local dd = CreateFrame("Frame", "DoF_LibraryDropdown", UIParent, "TooltipBackdropTemplate")
        dd:SetFrameStrata("TOOLTIP")
        dd:EnableMouse(true)
        dd.buttons = {}
        dd:SetScript("OnUpdate", function(self)
            if not self:IsMouseOver() and IsMouseButtonDown("LeftButton") then
                self:Hide()
            end
        end)
        DoF._libraryDropdown = dd
    end

    local dd = DoF._libraryDropdown
    -- Скрываем старые кнопки
    for _, btn in ipairs(dd.buttons) do btn:Hide() end

    local h = #items * 24 + 12
    dd:SetSize(170, h)

    local y = -6
    for i, item in ipairs(items) do
        local btn = dd.buttons[i]
        if not btn then
            btn = CreateFrame("Button", nil, dd)
            btn:SetSize(160, 22)
            local hl = btn:CreateTexture(nil, "HIGHLIGHT")
            hl:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
            hl:SetBlendMode("ADD")
            hl:SetAllPoints(btn)
            btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            btn.text:SetPoint("LEFT", 8, 0)
            dd.buttons[i] = btn
        end

        btn:SetPoint("TOPLEFT", dd, "TOPLEFT", 5, y)
        btn.text:SetText(item[2])
        btn.text:SetTextColor(1, 0.82, 0)  -- золотой стандарт
        btn:SetScript("OnClick", function()
            dd:Hide()
            onSelect(item[1], item[2])
        end)
        btn:Show()
        y = y - 24
    end

    dd:ClearAllPoints()
    dd:SetPoint("TOPLEFT", anchorBtn, "BOTTOMLEFT", 0, -2)
    dd:Show()
end

-- ===========================================================
-- ЗАГОЛОВОК СЕКЦИИ (линия — текст — линия)
-- ===========================================================

local function CreateSectionHeader(parent, text, contentW)
    local header = CreateFrame("Frame", nil, parent)
    header:SetSize(contentW, SECTION_HEADER_H)

    header.leftLine = header:CreateTexture(nil, "ARTWORK")
    header.leftLine:SetColorTexture(0.25, 0.25, 0.25, 1)
    header.leftLine:SetSize(30, 1)
    header.leftLine:SetPoint("LEFT", 4, 0)

    header.label = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    header.label:SetText(text)
    header.label:SetTextColor(0.8, 0.8, 0.8)
    header.label:SetPoint("LEFT", header.leftLine, "RIGHT", 6, 0)

    header.rightLine = header:CreateTexture(nil, "ARTWORK")
    header.rightLine:SetColorTexture(0.25, 0.25, 0.25, 1)
    header.rightLine:SetHeight(1)
    header.rightLine:SetPoint("LEFT", header.label, "RIGHT", 6, 0)
    header.rightLine:SetPoint("RIGHT", header, "RIGHT", -4, 0)

    return header
end

-- ===========================================================
-- БЛОК АТАКИ (пул внутри editFrame)
-- ===========================================================

local attackBlocks = {}

local function EnsureAttackBlock(parent, index)
    if attackBlocks[index] then
        attackBlocks[index]:SetParent(parent)
        return attackBlocks[index]
    end

    local block = CreateFrame("Frame", nil, parent, "InsetFrameTemplate")
    block:SetSize(DIALOG_W - 50, ATTACK_BLOCK_H_DEBUFF)

    -- Имя атаки
    block.nameInput = CreateEditBox(block, 140, false)
    block.nameInput:SetPoint("TOPLEFT", 14, -8)

    -- Кнопка удаления (стандартный крестик)
    block.removeBtn = CreateFrame("Button", nil, block, "UIPanelCloseButtonNoScripts")
    block.removeBtn:SetSize(18, 18)
    block.removeBtn:SetPoint("TOPRIGHT", -2, -2)

    -- Урон: мин-макс
    block.dmgLabel = CreateLabel(block, DoF.L["npc.edit.damage_label"])
    block.dmgLabel:SetPoint("TOPLEFT", 8, -30)
    block.dmgMinInput = CreateEditBox(block, 35, true)
    block.dmgMinInput:SetPoint("LEFT", block.dmgLabel, "RIGHT", 4, 0)
    block.dmgDash = CreateLabel(block, "-")
    block.dmgDash:SetPoint("LEFT", block.dmgMinInput, "RIGHT", 2, 0)
    block.dmgMaxInput = CreateEditBox(block, 35, true)
    block.dmgMaxInput:SetPoint("LEFT", block.dmgDash, "RIGHT", 2, 0)

    -- Порог
    block.threshLabel = CreateLabel(block, DoF.L["npc.edit.threshold_label"])
    block.threshLabel:SetPoint("LEFT", block.dmgMaxInput, "RIGHT", 10, 0)
    block.threshInput = CreateEditBox(block, 35, true)
    block.threshInput:SetPoint("LEFT", block.threshLabel, "RIGHT", 4, 0)

    -- Защита + Дебафф на одной строке
    block.defLabel = CreateLabel(block, DoF.L["npc.edit.defense_label"])
    block.defLabel:SetPoint("TOPLEFT", 8, -54)
    block.defBtn = CreateSmallButton(block, 80, 20, DoF.L["stats.fortitude.label"], nil)
    block.defBtn:SetPoint("LEFT", block.defLabel, "RIGHT", 4, 0)

    block.debuffLabel = CreateLabel(block, DoF.L["npc.edit.debuff_label"])
    block.debuffLabel:SetPoint("LEFT", block.defBtn, "RIGHT", 6, 0)
    block.debuffBtn = CreateSmallButton(block, 80, 20, DoF.L["ui.common.none"], nil)
    block.debuffBtn:SetPoint("LEFT", block.debuffLabel, "RIGHT", 4, 0)

    -- Значение и раунды дебаффа (строка 4, условная)
    block.debuffValLabel = CreateLabel(block, DoF.L["npc.edit.debuff_value_label"])
    block.debuffValLabel:SetPoint("TOPLEFT", 8, -78)
    block.debuffValInput = CreateEditBox(block, 30, true)
    block.debuffValInput:SetPoint("LEFT", block.debuffValLabel, "RIGHT", 2, 0)
    block.debuffDurLabel = CreateLabel(block, DoF.L["npc.edit.debuff_duration_label"])
    block.debuffDurLabel:SetPoint("LEFT", block.debuffValInput, "RIGHT", 4, 0)
    block.debuffDurInput = CreateEditBox(block, 30, true)
    block.debuffDurInput:SetPoint("LEFT", block.debuffDurLabel, "RIGHT", 2, 0)

    attackBlocks[index] = block
    return block
end

local function UpdateDebuffFieldsVisibility(block, debuffId)
    if debuffId == nil then
        block.debuffValLabel:Hide()
        block.debuffValInput:Hide()
        block.debuffDurLabel:Hide()
        block.debuffDurInput:Hide()
        block:SetHeight(ATTACK_BLOCK_H_BASE)
    elseif debuffId == "stun" then
        block.debuffValLabel:Hide()
        block.debuffValInput:Hide()
        block.debuffDurLabel:Show()
        block.debuffDurInput:Show()
        block:SetHeight(ATTACK_BLOCK_H_DEBUFF)
    else
        block.debuffValLabel:Show()
        block.debuffValInput:Show()
        block.debuffDurLabel:Show()
        block.debuffDurInput:Show()
        block:SetHeight(ATTACK_BLOCK_H_DEBUFF)
    end
end

-- ===========================================================
-- БЛОК ПАССИВКИ (пул внутри editFrame)
-- ===========================================================

local passiveBlocks = {}

local function GetPassiveFieldLabel(key)
    local labels = {
        mode = DoF.L["npc.field.mode"], chance = DoF.L["npc.field.chance"], damageMin = DoF.L["npc.field.damageMin"], damageMax = DoF.L["npc.field.damageMax"],
        threshold = DoF.L["npc.field.threshold"], dotValue = DoF.L["npc.field.dotValue"], dotDuration = DoF.L["npc.field.dotDuration"],
        value = DoF.L["npc.field.value"], stunDuration = DoF.L["npc.field.stunDuration"], defenseStat = DoF.L["npc.field.defenseStat"],
        instantDamage = DoF.L["npc.field.instantDamage"],
    }
    return labels[key] or key
end

local function EnsurePassiveBlock(parent, index)
    if passiveBlocks[index] then
        passiveBlocks[index]:SetParent(parent)
        return passiveBlocks[index]
    end

    local block = CreateFrame("Frame", nil, parent, "InsetFrameTemplate")
    block:SetSize(DIALOG_W - 50, PASSIVE_BLOCK_H)

    -- Иконка
    block.icon = block:CreateTexture(nil, "ARTWORK")
    block.icon:SetSize(18, 18)
    block.icon:SetPoint("TOPLEFT", 12, -6)

    -- Название пассивки
    block.nameLabel = block:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    block.nameLabel:SetPoint("LEFT", block.icon, "RIGHT", 4, 0)

    -- Кнопка удаления (стандартный крестик)
    block.removeBtn = CreateFrame("Button", nil, block, "UIPanelCloseButtonNoScripts")
    block.removeBtn:SetSize(18, 18)
    block.removeBtn:SetPoint("TOPRIGHT", -2, -2)

    -- Динамические поля ввода (до 5 полей)
    block.fields = {}
    for fi = 1, 5 do
        local flabel = CreateLabel(block, "")
        local finput = CreateEditBox(block, 32, true)
        flabel:Hide()
        finput:Hide()
        block.fields[fi] = { label = flabel, input = finput }
    end

    -- Спец. кнопка для mode-дропдауна (Шипы: guaranteed/chance)
    block.modeBtn = CreateSmallButton(block, 75, 18, DoF.L["npc.edit.mode_guaranteed"], nil)
    block.modeBtn:Hide()

    -- Спец. кнопка для defenseStat (Контратака) с лейблом
    block.defStatLabel = CreateLabel(block, DoF.L["npc.edit.defense_label"])
    block.defStatLabel:Hide()
    block.defStatBtn = CreateSmallButton(block, 75, 18, DoF.L["ui.dlg.hybrid"], nil)
    block.defStatBtn:Hide()

    -- Кнопка-переключатель для checkbox-полей (instantDamage)
    block.checkBtn = CreateSmallButton(block, 120, 18, DoF.L["npc.edit.check_normal"], nil)
    block.checkBtn:Hide()

    -- Кнопка "Не снимаемая" (unpurgeable) — для всех пассивок
    block.unpurgeBtn = CreateSmallButton(block, 100, 18, DoF.L["ui.dlg.purgeable"], nil)
    block.unpurgeBtn:Hide()

    passiveBlocks[index] = block
    return block
end

-- Возвращает true, если пассивка использует доп. строку (defenseStat)
local function LayoutPassiveFields(block, passiveId, passiveData)
    -- Скрываем все поля
    for fi = 1, 5 do
        block.fields[fi].label:Hide()
        block.fields[fi].input:Hide()
    end
    block.modeBtn:Hide()
    block.defStatLabel:Hide()
    block.defStatBtn:Hide()
    block.checkBtn:Hide()
    block.unpurgeBtn:Hide()

    local hasExtraRow = false

    if not DoF.Passives or not DoF.Passives.Definitions[passiveId] then
        block:SetHeight(PASSIVE_BLOCK_H)
        return
    end
    local def = DoF.Passives.Definitions[passiveId]
    if not def.fields then
        block:SetHeight(PASSIVE_BLOCK_H)
        return
    end

    local x = 6
    local y = -26
    local fi = 0

    for _, fieldDef in ipairs(def.fields) do
        if fieldDef.type == "number" then
            -- Пропускаем chance если mode == guaranteed (для шипов)
            if fieldDef.showIf and passiveData.mode ~= fieldDef.showIf then
                -- Скрываем
            else
                fi = fi + 1
                if fi <= 5 then
                    local f = block.fields[fi]
                    f.label:SetText(GetPassiveFieldLabel(fieldDef.key))
                    f.label:ClearAllPoints()
                    f.label:SetPoint("TOPLEFT", block, "TOPLEFT", x, y)
                    f.label:Show()
                    f.input:ClearAllPoints()
                    f.input:SetPoint("LEFT", f.label, "RIGHT", 2, 0)
                    f.input:SetText(tostring(passiveData[fieldDef.key] or fieldDef.default or 0))
                    f.input:Show()
                    f.input._fieldKey = fieldDef.key
                    x = x + 70
                end
            end
        elseif fieldDef.type == "dropdown" and fieldDef.key == "mode" then
            block.modeBtn:ClearAllPoints()
            block.modeBtn:SetPoint("TOPLEFT", block, "TOPLEFT", x, y)
            local modeText = passiveData.mode == "chance" and DoF.L["npc.edit.mode_chance"] or DoF.L["npc.edit.mode_guaranteed"]
            block.modeBtn.text:SetText(modeText)
            block.modeBtn:Show()
            x = x + 80
        elseif fieldDef.type == "dropdown" and fieldDef.key == "defenseStat" then
            -- Отдельная строка под полями ввода
            hasExtraRow = true
            block.defStatLabel:ClearAllPoints()
            block.defStatLabel:SetPoint("TOPLEFT", block, "TOPLEFT", 6, -46)
            block.defStatLabel:Show()
            block.defStatBtn:ClearAllPoints()
            block.defStatBtn:SetPoint("LEFT", block.defStatLabel, "RIGHT", 2, 0)
            block.defStatBtn.text:SetText(GetDefenseName(passiveData.defenseStat or "Hybrid"))
            block.defStatBtn:Show()
        elseif fieldDef.type == "checkbox" then
            -- Кнопка-переключатель на отдельной строке
            hasExtraRow = true
            block.checkBtn:ClearAllPoints()
            block.checkBtn:SetPoint("TOPLEFT", block, "TOPLEFT", 6, -46)
            local isOn = passiveData[fieldDef.key]
            local text = isOn and DoF.L["npc.edit.instant_on"] or DoF.L["npc.edit.instant_off"]
            block.checkBtn.text:SetText(text)
            block.checkBtn._fieldKey = fieldDef.key
            block.checkBtn:Show()
        end
    end

    -- Кнопка "Не снимаемая" — всегда на доп. строке
    hasExtraRow = true
    local unpurgeX = 6
    if block.checkBtn:IsShown() then unpurgeX = 130 end
    if block.defStatBtn:IsShown() then unpurgeX = 130 end
    block.unpurgeBtn:ClearAllPoints()
    block.unpurgeBtn:SetPoint("TOPLEFT", block, "TOPLEFT", unpurgeX, -46)
    local isUnpurgeable = passiveData.unpurgeable
    local upText = isUnpurgeable and DoF.L["ui.dlg.unpurgeable"] or DoF.L["ui.dlg.purgeable"]
    block.unpurgeBtn.text:SetText(upText)
    block.unpurgeBtn:Show()

    block:SetHeight(hasExtraRow and PASSIVE_BLOCK_H_EXT or PASSIVE_BLOCK_H)
end

local function CollectPassiveFields(block, passiveData)
    for fi = 1, 5 do
        local f = block.fields[fi]
        if f.input:IsShown() and f.input._fieldKey then
            passiveData[f.input._fieldKey] = f.input:GetNumber()
        end
    end
end

-- ===========================================================
-- СОЗДАНИЕ ФРЕЙМА РЕДАКТИРОВАНИЯ (create-once)
-- ===========================================================

local function EnsureEditFrame()
    if editFrame then return end

    editFrame = CreateFrame("Frame", "DoF_NPCLibraryEditFrame", UIParent, "DoF_DialogTemplate")
    editFrame:SetSize(DIALOG_W, 300) -- высота пересчитывается динамически
    editFrame:SetPoint("CENTER")
    editFrame:SetFrameStrata("FULLSCREEN_DIALOG")
    editFrame:SetFrameLevel(200)
    editFrame:Hide()

    -- Название
    local nameLabel = CreateLabel(editFrame, DoF.L["npc.edit.name_label"])
    nameLabel:SetPoint("TOPLEFT", 18, -42)
    editFrame.nameInput = CreateEditBox(editFrame, 200, false)
    editFrame.nameInput:SetPoint("LEFT", nameLabel, "RIGHT", 6, 0)

    -- Категория
    local catLabel = CreateLabel(editFrame, DoF.L["npc.edit.category_label"])
    catLabel:SetPoint("TOPLEFT", 18, -66)
    editFrame.catInput = CreateEditBox(editFrame, 200, false)
    editFrame.catInput:SetPoint("LEFT", catLabel, "RIGHT", 6, 0)

    -- Статы в одну строку
    local statsY = -90
    local hpLabel = CreateLabel(editFrame, "HP:")
    hpLabel:SetPoint("TOPLEFT", 18, statsY)
    editFrame.hpInput = CreateEditBox(editFrame, 40, true)
    editFrame.hpInput:SetPoint("LEFT", hpLabel, "RIGHT", 4, 0)

    local fortLabel = CreateLabel(editFrame, DoF.L["npc.edit.fort_label"])
    fortLabel:SetPoint("LEFT", editFrame.hpInput, "RIGHT", 10, 0)
    editFrame.fortInput = CreateEditBox(editFrame, 35, true)
    editFrame.fortInput:SetPoint("LEFT", fortLabel, "RIGHT", 4, 0)

    local refLabel = CreateLabel(editFrame, DoF.L["npc.edit.reflex_label"])
    refLabel:SetPoint("LEFT", editFrame.fortInput, "RIGHT", 10, 0)
    editFrame.reflexInput = CreateEditBox(editFrame, 35, true)
    editFrame.reflexInput:SetPoint("LEFT", refLabel, "RIGHT", 4, 0)

    local willLabel = CreateLabel(editFrame, DoF.L["npc.edit.will_label"])
    willLabel:SetPoint("LEFT", editFrame.reflexInput, "RIGHT", 10, 0)
    editFrame.willInput = CreateEditBox(editFrame, 35, true)
    editFrame.willInput:SetPoint("LEFT", willLabel, "RIGHT", 4, 0)

    -- Единый ScrollFrame для атак и пассивок (штатный UIPanelScrollFrameTemplate).
    -- Ширина = DIALOG_W - 14 (left padding) - 32 (scrollbar) = DIALOG_W - 46.
    local SCROLL_W = DIALOG_W - 46
    local editScroll = CreateFrame("ScrollFrame", nil, editFrame, "UIPanelScrollFrameTemplate")
    editScroll:SetPoint("TOPLEFT", editFrame, "TOPLEFT", 14, -116)
    editScroll:SetWidth(SCROLL_W)
    editFrame.editScroll = editScroll

    local editContent = CreateFrame("Frame", nil, editScroll)
    editContent:SetWidth(SCROLL_W)
    editContent:SetHeight(1)
    editScroll:SetScrollChild(editContent)
    editFrame.editContent = editContent
    editFrame._scrollW = SCROLL_W

    -- Заглушка для совместимости со старым API (UpdateScrollBar — больше не нужен)
    editScroll.UpdateScrollBar = function() end

    local contentW = SCROLL_W

    -- Заголовок секции атак (внутри скролла)
    editFrame.attackHeader = CreateSectionHeader(editContent, DoF.L["npc.edit.attacks_header"], contentW)

    editFrame.addAttackBtn = CreateSmallButton(editContent, 90, 20, DoF.L["npc.edit.add"], function()
        if #editAttacks < MAX_EDIT_ATTACKS then
            CollectEditAttacks()
            table_insert(editAttacks, {
                name = DoF.Locale:Format("npc.attack_numbered", #editAttacks + 1),
                damageMin = 1, damageMax = 5,
                threshold = 10, defenseStat = "Fortitude",
                debuffId = nil, debuffValue = 0, debuffDuration = 0,
            })
            DoF.UI:RefreshEditAttacks()
        end
    end)

    -- Заголовок секции пассивок (внутри скролла)
    editFrame.passiveHeader = CreateSectionHeader(editContent, DoF.L["npc.edit.passives_header"], contentW)

    editFrame.addPassiveBtn = CreateSmallButton(editContent, 90, 20, DoF.L["npc.edit.add"], function()
        if #editPassives < MAX_EDIT_PASSIVES and DoF.Passives then
            -- Показываем меню выбора пассивки
            local items = {}
            for _, pid in ipairs(DoF.Passives.DisplayOrder) do
                local def = DoF.Passives.Definitions[pid]
                -- Проверяем, не добавлена ли уже
                local alreadyAdded = false
                for _, ep in ipairs(editPassives) do
                    if ep.id == pid then alreadyAdded = true; break end
                end
                if not alreadyAdded then
                    table_insert(items, { pid, def.name, { r = def.color[1], g = def.color[2], b = def.color[3] } })
                end
            end
            if #items > 0 then
                ShowDropdownMenu(items, editFrame.addPassiveBtn, function(pid)
                    local def = DoF.Passives.Definitions[pid]
                    local newPassive = { id = pid }
                    -- Заполняем значениями по умолчанию
                    if def.fields then
                        for _, f in ipairs(def.fields) do
                            if f.default then newPassive[f.key] = f.default end
                        end
                    end
                    -- Собираем текущие значения из UI перед перерисовкой
                    for pj, pd in ipairs(editPassives) do
                        if pj <= MAX_EDIT_PASSIVES then
                            local pb = passiveBlocks[pj]
                            if pb and pb:IsShown() then
                                CollectPassiveFields(pb, pd)
                            end
                        end
                    end
                    CollectEditAttacks()
                    table_insert(editPassives, newPassive)
                    DoF.UI:RefreshEditAttacks()
                end)
            end
        end
    end)

    -- Кнопки Сохранить / Отмена
    editFrame.saveBtn = CreateSmallButton(editFrame, 100, 26, DoF.L["npc.edit.save"], function()
        DoF.UI:SaveNPCLibraryEdit()
    end)
    -- Позиция пересчитывается в RefreshEditAttacks

    editFrame.cancelBtn = CreateSmallButton(editFrame, 100, 26, DoF.L["ui.common.cancel"], function()
        editFrame:Hide()
    end)
end

-- ===========================================================
-- СБОР ТЕКУЩИХ ЗНАЧЕНИЙ ИЗ UI В editAttacks
-- ===========================================================

CollectEditAttacks = function()
    for i, atk in ipairs(editAttacks) do
        if i > MAX_EDIT_ATTACKS then break end
        local block = attackBlocks[i]
        if block and block:IsShown() then
            atk.name = block.nameInput:GetText() or DoF.L["npc.attack_default"]
            atk.damageMin = numOrDefault(block.dmgMinInput, 1, 1)
            atk.damageMax = numOrDefault(block.dmgMaxInput, 5, 1)
            atk.threshold = numOrDefault(block.threshInput, 10, 1)
            atk.debuffValue = block.debuffValInput:GetNumber()
            atk.debuffDuration = block.debuffDurInput:GetNumber()
            -- defenseStat и debuffId обновляются дропдаунами напрямую
        end
    end
end

-- ===========================================================
-- ОБНОВЛЕНИЕ БЛОКОВ АТАК И ПАССИВОК (единый скролл)
-- ===========================================================

function DoF.UI:RefreshEditAttacks()
    if not editFrame then return end

    local content = editFrame.editContent
    local savedScroll = editFrame.editScroll:GetVerticalScroll()

    -- Скрываем все блоки
    for _, b in ipairs(attackBlocks) do b:Hide() end
    for _, b in ipairs(passiveBlocks) do b:Hide() end

    local yOff = 0

    -- ─── Секция атак ──────────────────────────────────────

    editFrame.attackHeader:ClearAllPoints()
    editFrame.attackHeader:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -yOff)
    editFrame.attackHeader:Show()

    editFrame.addAttackBtn:ClearAllPoints()
    editFrame.addAttackBtn:SetPoint("LEFT", editFrame.attackHeader.label, "RIGHT", 10, 0)
    if #editAttacks >= MAX_EDIT_ATTACKS then
        editFrame.addAttackBtn:Hide()
        editFrame.attackHeader.rightLine:Show()
    else
        editFrame.addAttackBtn:Show()
        editFrame.attackHeader.rightLine:Hide()
    end

    yOff = yOff + SECTION_HEADER_H + 2

    for i, atk in ipairs(editAttacks) do
        if i > MAX_EDIT_ATTACKS then break end
        local block = EnsureAttackBlock(content, i)
        block:ClearAllPoints()
        block:SetPoint("TOPLEFT", content, "TOPLEFT", 4, -yOff)

        UpdateDebuffFieldsVisibility(block, atk.debuffId)
        block:Show()

        -- Заполняем поля
        block.nameInput:SetText(atk.name or DoF.L["npc.attack_default"])
        block.dmgMinInput:SetText(tostring(atk.damageMin or 1))
        block.dmgMaxInput:SetText(tostring(atk.damageMax or 5))
        block.threshInput:SetText(tostring(atk.threshold or 10))
        block.defBtn.text:SetText(GetDefenseName(atk.defenseStat))
        block.debuffBtn.text:SetText(GetDebuffName(atk.debuffId))
        block.debuffValInput:SetText(tostring(atk.debuffValue or 0))
        block.debuffDurInput:SetText(tostring(atk.debuffDuration or 0))

        -- Привязка дропдаунов
        local capturedI = i
        block.defBtn:SetScript("OnClick", function(self)
            ShowDropdownMenu(DEFENSES, self, function(val, name)
                editAttacks[capturedI].defenseStat = val
                block.defBtn.text:SetText(name)
            end)
        end)

        block.debuffBtn:SetScript("OnClick", function(self)
            ShowDropdownMenu(DEBUFFS, self, function(val, name)
                CollectEditAttacks()
                editAttacks[capturedI].debuffId = val
                block.debuffBtn.text:SetText(name)
                DoF.UI:RefreshEditAttacks()
            end)
        end)

        -- Кнопка удаления атаки
        block.removeBtn:SetScript("OnClick", function()
            CollectEditAttacks()
            table_remove(editAttacks, capturedI)
            DoF.UI:RefreshEditAttacks()
        end)

        local blockH = (atk.debuffId ~= nil) and ATTACK_BLOCK_H_DEBUFF or ATTACK_BLOCK_H_BASE
        yOff = yOff + blockH + 4
    end

    -- ─── Секция пассивок ──────────────────────────────────

    yOff = yOff + 6

    editFrame.passiveHeader:ClearAllPoints()
    editFrame.passiveHeader:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -yOff)
    editFrame.passiveHeader:Show()

    editFrame.addPassiveBtn:ClearAllPoints()
    editFrame.addPassiveBtn:SetPoint("LEFT", editFrame.passiveHeader.label, "RIGHT", 10, 0)
    if #editPassives >= MAX_EDIT_PASSIVES or not DoF.Passives then
        editFrame.addPassiveBtn:Hide()
        editFrame.passiveHeader.rightLine:Show()
    else
        editFrame.addPassiveBtn:Show()
        editFrame.passiveHeader.rightLine:Hide()
    end

    yOff = yOff + SECTION_HEADER_H + 2

    for pi, pdata in ipairs(editPassives) do
        if pi > MAX_EDIT_PASSIVES then break end
        local pblock = EnsurePassiveBlock(content, pi)
        pblock:ClearAllPoints()
        pblock:SetPoint("TOPLEFT", content, "TOPLEFT", 4, -yOff)
        pblock:Show()

        -- Иконка и название
        local def = DoF.Passives and DoF.Passives.Definitions[pdata.id]
        if def then
            pblock.icon:SetTexture(def.icon)
            pblock.nameLabel:SetText(def.name)
        else
            pblock.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
            pblock.nameLabel:SetText(pdata.id or "???")
        end

        -- Поля ввода
        LayoutPassiveFields(pblock, pdata.id, pdata)

        -- Привязка кнопок
        local capturedPI = pi

        -- Режим (шипы: guaranteed/chance)
        pblock.modeBtn:SetScript("OnClick", function(self)
            local MODE_ITEMS = {
                { "guaranteed", DoF.L["npc.edit.mode_guaranteed"] },
                { "chance",     DoF.L["npc.edit.mode_chance"] },
            }
            ShowDropdownMenu(MODE_ITEMS, self, function(val, name)
                editPassives[capturedPI].mode = val
                pblock.modeBtn.text:SetText(name)
                LayoutPassiveFields(pblock, editPassives[capturedPI].id, editPassives[capturedPI])
            end)
        end)

        -- Стат защиты (контратака)
        pblock.defStatBtn:SetScript("OnClick", function(self)
            ShowDropdownMenu(DEFENSES, self, function(val, name)
                editPassives[capturedPI].defenseStat = val
                pblock.defStatBtn.text:SetText(name)
            end)
        end)

        -- Переключатель checkbox-полей (instantDamage)
        pblock.checkBtn:SetScript("OnClick", function(self)
            local key = self._fieldKey
            if not key then return end
            local cur = editPassives[capturedPI][key]
            editPassives[capturedPI][key] = not cur
            local isOn = editPassives[capturedPI][key]
            local text = isOn and DoF.L["npc.edit.instant_on"] or DoF.L["npc.edit.instant_off"]
            self.text:SetText(text)
        end)

        -- Переключатель "Не снимаемая" (unpurgeable)
        pblock.unpurgeBtn:SetScript("OnClick", function(self)
            local cur = editPassives[capturedPI].unpurgeable
            editPassives[capturedPI].unpurgeable = not cur
            local isUp = editPassives[capturedPI].unpurgeable
            local text = isUp and DoF.L["ui.dlg.unpurgeable"] or DoF.L["ui.dlg.purgeable"]
            self.text:SetText(text)
        end)

        -- Удаление
        pblock.removeBtn:SetScript("OnClick", function()
            -- Собираем значения перед удалением
            for pj, pd in ipairs(editPassives) do
                if pj <= MAX_EDIT_PASSIVES then
                    local pb = passiveBlocks[pj]
                    if pb and pb:IsShown() then
                        CollectPassiveFields(pb, pd)
                    end
                end
            end
            table_remove(editPassives, capturedPI)
            DoF.UI:RefreshEditAttacks()
        end)

        yOff = yOff + pblock:GetHeight() + 4
    end

    -- ─── Пересчёт высоты контента и скролла ──────────────

    content:SetHeight(math.max(1, yOff))

    local headerH = 116  -- diamond-header + название + категория + статы
    local footerH = 50   -- кнопки Сохранить/Отмена
    local actualScrollH = math.min(yOff, MAX_SCROLL_H)
    editFrame.editScroll:SetHeight(math.max(1, actualScrollH))

    -- Высота диалога
    local totalH = headerH + actualScrollH + footerH
    totalH = math.max(totalH, 200)
    editFrame:SetHeight(totalH)

    editFrame.saveBtn:ClearAllPoints()
    editFrame.saveBtn:SetPoint("BOTTOMLEFT", 30, 10)
    editFrame.cancelBtn:ClearAllPoints()
    editFrame.cancelBtn:SetPoint("BOTTOMRIGHT", -30, 10)

    -- Обновляем скроллбар с задержкой в 1 кадр (WoW откладывает пересчёт layout)
    C_Timer.After(0, function()
        if editFrame and editFrame:IsShown() then
            -- Восстанавливаем позицию скролла
            local maxScroll = editFrame.editScroll:GetVerticalScrollRange()
            editFrame.editScroll:SetVerticalScroll(math.min(savedScroll, maxScroll))
            editFrame.editScroll:UpdateScrollBar()
        end
    end)
end

-- ===========================================================
-- ПОКАЗАТЬ ДИАЛОГ
-- ===========================================================

function DoF.UI:ShowNPCLibraryEdit(templateId)
    EnsureEditFrame()
    editTemplateId = templateId

    if templateId then
        -- Редактирование существующего
        local tmpl = DoF.NPCLibrary:Get(templateId)
        if not tmpl then
            DoF.Utils:Error(DoF.L["errors.template_not_found"])
            return
        end
        editFrame.Header:Setup(DoF.L["npc.edit.title_edit"])
        editFrame.nameInput:SetText(tmpl.name or "")
        editFrame.catInput:SetText(tmpl.category or "")
        editFrame.hpInput:SetText(tostring(tmpl.hp or 10))
        editFrame.fortInput:SetText(tostring(tmpl.fort or 10))
        editFrame.reflexInput:SetText(tostring(tmpl.reflex or 10))
        editFrame.willInput:SetText(tostring(tmpl.will or 10))

        -- Глубокая копия атак для редактирования
        editAttacks = {}
        for _, atk in ipairs(tmpl.attacks or {}) do
            table_insert(editAttacks, {
                name = atk.name,
                damageMin = atk.damageMin,
                damageMax = atk.damageMax,
                threshold = atk.threshold,
                defenseStat = atk.defenseStat,
                debuffId = atk.debuffId,
                debuffValue = atk.debuffValue,
                debuffDuration = atk.debuffDuration,
            })
        end

        -- Глубокая копия пассивок
        editPassives = {}
        if tmpl.passives then
            for pid, pcfg in pairs(tmpl.passives) do
                local entry = { id = pid }
                for k, v in pairs(pcfg) do
                    entry[k] = v
                end
                table_insert(editPassives, entry)
            end
        end
    else
        -- Создание нового
        editFrame.Header:Setup(DoF.L["npc.edit.title_new"])
        editFrame.nameInput:SetText("")
        editFrame.catInput:SetText("")
        editFrame.hpInput:SetText("10")
        editFrame.fortInput:SetText("10")
        editFrame.reflexInput:SetText("10")
        editFrame.willInput:SetText("10")
        editAttacks = {}
        editPassives = {}
    end

    self:RefreshEditAttacks()
    editFrame:Show()
end

-- ===========================================================
-- СОХРАНЕНИЕ
-- ===========================================================

function DoF.UI:SaveNPCLibraryEdit()
    if not editFrame then return end

    local name = editFrame.nameInput:GetText()
    if not name or name == "" then
        DoF.Utils:Error(DoF.L["errors.enter_template_name"])
        return
    end

    local hp = numOrDefault(editFrame.hpInput, 10, 1)

    -- Считываем актуальные значения из полей ввода атак
    local attacks = {}
    for i, atk in ipairs(editAttacks) do
        if i > MAX_EDIT_ATTACKS then break end
        local block = attackBlocks[i]
        if block then
            table_insert(attacks, {
                name = block.nameInput:GetText() or DoF.L["npc.attack_default"],
                damageMin = numOrDefault(block.dmgMinInput, 1, 1),
                damageMax = numOrDefault(block.dmgMaxInput, 5, 1),
                threshold = numOrDefault(block.threshInput, 10, 1),
                defenseStat = atk.defenseStat or "Fortitude",
                debuffId = atk.debuffId,
                debuffValue = block.debuffValInput:GetNumber(),
                debuffDuration = block.debuffDurInput:GetNumber(),
            })
        end
    end

    -- Собираем пассивки
    local passives = nil
    if #editPassives > 0 then
        passives = {}
        for pi, pdata in ipairs(editPassives) do
            if pi > MAX_EDIT_PASSIVES then break end
            local pblock = passiveBlocks[pi]
            if pblock and pblock:IsShown() then
                CollectPassiveFields(pblock, pdata)
            end
            -- Конвертируем из массива { id = "thorns", value = 3, ... } в хэш-таблицу
            local pid = pdata.id
            if pid then
                local cfg = {}
                for k, v in pairs(pdata) do
                    if k ~= "id" then
                        cfg[k] = v
                    end
                end
                passives[pid] = cfg
            end
        end
        if not next(passives) then passives = nil end
    end

    local data = {
        name = name,
        category = editFrame.catInput:GetText() or "",
        hp = hp,
        fort = numOrDefault(editFrame.fortInput, 10, 1),
        reflex = numOrDefault(editFrame.reflexInput, 10, 1),
        will = numOrDefault(editFrame.willInput, 10, 1),
        attacks = attacks,
        passives = passives,
    }

    if editTemplateId then
        DoF.NPCLibrary:Update(editTemplateId, data)
        DoF.Utils:Info(DoF.Locale:Format("npc.template_updated", name))
    else
        editTemplateId = DoF.NPCLibrary:Create(data)
        DoF.Utils:Info(DoF.Locale:Format("npc.template_created", name))
    end

    editFrame:Hide()

    -- Обновляем главное окно
    if DoF.UI.RefreshNPCLibrary then
        DoF.UI:RefreshNPCLibrary()
    end
end
