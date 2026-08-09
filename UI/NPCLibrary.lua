-- DoF/UI/NPCLibrary.lua
-- Главное окно библиотеки шаблонов NPC

local ADDON_NAME, DoF = ...

DoF.UI = DoF.UI or {}

local ipairs = ipairs
local table_insert = table.insert

local WINDOW_W, WINDOW_H = 460, 450
local LEFT_W = 160
local MAX_ATTACKS_SHOWN = 6
local ITEM_HEIGHT = 20
local CAT_HEIGHT = 22

local frame = nil
local selectedTemplateId = nil
local searchQuery = ""
local collapsedCategories = {}

-- Пул виджетов для списка
local listItems = {}
local attackButtons = {}

-- ===========================================================
-- ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ
-- ===========================================================

-- Короткое название защиты
local function DefenseShort(stat)
    if stat == "Fortitude" then return DoF.L["npc.stat.fort_short"]
    elseif stat == "Reflex" then return DoF.L["npc.stat.reflex_short"]
    elseif stat == "Will" then return DoF.L["npc.stat.will_short"]
    elseif stat == "Hybrid" then return DoF.L["npc.stat.hybrid_short"]
    else return "?" end
end

-- Короткое название дебаффа
local function DebuffShort(debuffId)
    if debuffId == "stun" then return DoF.L["npc.debuff.stun"]
    elseif debuffId == "weakness_damage" then return DoF.L["npc.debuff.weakness_damage"]
    elseif debuffId == "weakness_healing" then return DoF.L["npc.debuff.weakness_healing"]
    elseif debuffId == "vulnerability_fortitude" then return DoF.L["npc.debuff.vuln_fortitude"]
    elseif debuffId == "vulnerability_reflex" then return DoF.L["npc.debuff.vuln_reflex"]
    elseif debuffId == "vulnerability_will" then return DoF.L["npc.debuff.vuln_will"]
    elseif debuffId == "dot_master" then return DoF.L["npc.debuff.dot"]
    else return DoF.L["npc.debuff.generic"] end
end

-- ===========================================================
-- СОЗДАНИЕ ФРЕЙМА (create-once)
-- ===========================================================

local function EnsureFrame()
    if frame then return end

    frame = CreateFrame("Frame", "DoF_NPCLibraryFrame", UIParent, "DoF_DialogTemplate")
    frame:SetSize(WINDOW_W, WINDOW_H)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:Hide()
    frame.Header:Setup(DoF.L["xml.npc_library"])

    -- ---------------------------------------------------
    -- Верхняя панель: поиск + создать
    -- ---------------------------------------------------
    frame.searchBox = CreateFrame("EditBox", "DoF_NPCLibrary_Search", frame, "InputBoxTemplate")
    frame.searchBox:SetSize(LEFT_W - 15, 20)
    frame.searchBox:SetPoint("TOPLEFT", 16, -42)
    frame.searchBox:SetAutoFocus(false)
    frame.searchBox:SetScript("OnTextChanged", function(self)
        searchQuery = self:GetText() or ""
        DoF.UI:RefreshNPCLibraryList()
    end)
    frame.searchBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

    frame.searchLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    frame.searchLabel:SetPoint("LEFT", frame.searchBox, "LEFT", 4, 0)
    frame.searchLabel:SetText(DoF.L["npc.ui.search"])
    frame.searchBox:SetScript("OnEditFocusGained", function() frame.searchLabel:Hide() end)
    frame.searchBox:SetScript("OnEditFocusLost", function()
        if (frame.searchBox:GetText() or "") == "" then frame.searchLabel:Show() end
    end)

    frame.createBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    frame.createBtn:SetSize(80, 22)
    frame.createBtn:SetPoint("TOPRIGHT", -16, -42)
    frame.createBtn:SetNormalFontObject("GameFontNormalSmall")
    frame.createBtn:SetHighlightFontObject("GameFontHighlightSmall")
    frame.createBtn:SetText(DoF.L["npc.ui.create"])
    frame.createBtn:SetScript("OnClick", function()
        if DoF.UI.ShowNPCLibraryEdit then
            DoF.UI:ShowNPCLibraryEdit(nil) -- nil = новый шаблон
        end
    end)

    -- ---------------------------------------------------
    -- Разделитель
    -- ---------------------------------------------------
    frame.divider = frame:CreateTexture(nil, "ARTWORK")
    frame.divider:SetColorTexture(0.25, 0.25, 0.25, 1)
    frame.divider:SetSize(1, WINDOW_H - 80)
    frame.divider:SetPoint("TOPLEFT", LEFT_W + 10, -68)

    -- ---------------------------------------------------
    -- Левая панель: штатный ScrollFrame (UIPanelScrollFrameTemplate)
    -- ---------------------------------------------------
    frame.listScroll = CreateFrame("ScrollFrame", "DoF_NPCLibrary_ListScroll", frame, "UIPanelScrollFrameTemplate")
    frame.listScroll:SetPoint("TOPLEFT", 10, -68)
    frame.listScroll:SetPoint("BOTTOMLEFT", 10, 16)
    frame.listScroll:SetWidth(LEFT_W - 20)

    frame.listChild = CreateFrame("Frame", nil, frame.listScroll)
    frame.listChild:SetSize(LEFT_W - 20, 1)
    frame.listScroll:SetScrollChild(frame.listChild)

    -- ---------------------------------------------------
    -- Правая панель
    -- ---------------------------------------------------
    local rightX = LEFT_W + 18
    local rightW = WINDOW_W - rightX - 16

    frame.detailName = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.detailName:SetPoint("TOPLEFT", rightX, -72)
    frame.detailName:SetWidth(rightW)
    frame.detailName:SetJustifyH("LEFT")

    frame.detailStats = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    frame.detailStats:SetPoint("TOPLEFT", rightX, -94)
    frame.detailStats:SetWidth(rightW)
    frame.detailStats:SetJustifyH("LEFT")

    frame.detailAttacksLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    frame.detailAttacksLabel:SetPoint("TOPLEFT", rightX, -124)
    frame.detailAttacksLabel:SetText(DoF.L["npc.ui.attacks_divider"])
    frame.detailAttacksLabel:SetTextColor(0.6, 0.6, 0.6)

    -- Кнопки атак (пул)
    for i = 1, MAX_ATTACKS_SHOWN do
        local btn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        btn:SetSize(rightW, 22)
        btn:SetPoint("TOPLEFT", rightX, -124 - i * 24)
        btn:SetNormalFontObject("GameFontNormalSmall")
        btn:SetHighlightFontObject("GameFontHighlightSmall")
        btn:Hide()
        local fs = btn:GetFontString()
        if fs then
            fs:ClearAllPoints()
            fs:SetPoint("LEFT", 8, 0)
            fs:SetPoint("RIGHT", -8, 0)
            fs:SetJustifyH("LEFT")
        end
        btn.text = fs  -- алиас для совместимости
        attackButtons[i] = btn
    end

    -- Кнопки действий внизу правой панели
    frame.applyBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    frame.applyBtn:SetSize(rightW, 24)
    frame.applyBtn:SetPoint("BOTTOMLEFT", rightX, 74)
    frame.applyBtn:SetNormalFontObject("GameFontNormalSmall")
    frame.applyBtn:SetHighlightFontObject("GameFontHighlightSmall")
    frame.applyBtn:SetText(DoF.L["npc.ui.apply_to_target"])
    frame.applyBtn:SetScript("OnClick", function()
        if selectedTemplateId then
            DoF.NPCLibrary:ApplyToTarget(selectedTemplateId)
        end
    end)

    -- Нижний ряд: Редакт. / Копия / Удалить
    local btnW = math.floor((rightW - 10) / 3)

    frame.editBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    frame.editBtn:SetSize(btnW, 22)
    frame.editBtn:SetPoint("BOTTOMLEFT", rightX, 46)
    frame.editBtn:SetNormalFontObject("GameFontNormalSmall")
    frame.editBtn:SetHighlightFontObject("GameFontHighlightSmall")
    frame.editBtn:SetText(DoF.L["npc.ui.edit"])
    frame.editBtn:SetScript("OnClick", function()
        if selectedTemplateId and DoF.UI.ShowNPCLibraryEdit then
            DoF.UI:ShowNPCLibraryEdit(selectedTemplateId)
        end
    end)

    frame.dupeBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    frame.dupeBtn:SetSize(btnW, 22)
    frame.dupeBtn:SetPoint("LEFT", frame.editBtn, "RIGHT", 5, 0)
    frame.dupeBtn:SetNormalFontObject("GameFontNormalSmall")
    frame.dupeBtn:SetHighlightFontObject("GameFontHighlightSmall")
    frame.dupeBtn:SetText(DoF.L["npc.ui.duplicate"])
    frame.dupeBtn:SetScript("OnClick", function()
        if selectedTemplateId then
            local newId = DoF.NPCLibrary:Duplicate(selectedTemplateId)
            if newId then
                selectedTemplateId = newId
                DoF.UI:RefreshNPCLibrary()
            end
        end
    end)

    frame.deleteBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    frame.deleteBtn:SetSize(btnW, 22)
    frame.deleteBtn:SetPoint("LEFT", frame.dupeBtn, "RIGHT", 5, 0)
    frame.deleteBtn:SetNormalFontObject("GameFontNormalSmall")
    frame.deleteBtn:SetHighlightFontObject("GameFontHighlightSmall")
    frame.deleteBtn:SetText(DoF.L["npc.ui.delete"])
    frame.deleteBtn.text = frame.deleteBtn:GetFontString()  -- алиас
    frame.deleteBtn:SetScript("OnClick", function()
        if selectedTemplateId then
            -- Простое подтверждение через повторный клик (для простоты)
            if frame.deleteBtn._confirmId == selectedTemplateId then
                DoF.NPCLibrary:Delete(selectedTemplateId)
                selectedTemplateId = nil
                frame.deleteBtn._confirmId = nil
                DoF.UI:RefreshNPCLibrary()
            else
                frame.deleteBtn._confirmId = selectedTemplateId
                frame.deleteBtn:SetText(DoF.L["npc.ui.delete_confirm"])
                C_Timer.After(3, function()
                    if frame.deleteBtn then
                        frame.deleteBtn._confirmId = nil
                        frame.deleteBtn:SetText(DoF.L["npc.ui.delete"])
                    end
                end)
            end
        end
    end)

    -- Сообщение "Нет шаблонов"
    frame.emptyText = frame:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    frame.emptyText:SetPoint("CENTER", frame.listChild, "TOP", 0, -40)
    frame.emptyText:SetText(DoF.L["npc.ui.no_templates"])

    -- Подписка на обновления
    DoF.Events:Register("NPC_LIBRARY_CHANGED", function()
        if frame:IsShown() then DoF.UI:RefreshNPCLibrary() end
    end, "NPCLibraryUI")
end

-- ===========================================================
-- ОБНОВЛЕНИЕ СПИСКА (левая панель)
-- ===========================================================

-- Создать кнопку-строку списка (без backdrop, с HIGHLIGHT-текстурой для hover)
local function EnsureListItem(idx, height)
    local item = listItems[idx]
    if item then
        item:SetHeight(height)
        return item
    end
    item = CreateFrame("Button", nil, frame.listChild)
    item:SetSize(LEFT_W - 24, height)

    -- Highlight texture для hover
    item.hl = item:CreateTexture(nil, "HIGHLIGHT")
    item.hl:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
    item.hl:SetBlendMode("ADD")
    item.hl:SetAllPoints(item)

    -- Подложка выделения (для активного шаблона)
    item.sel = item:CreateTexture(nil, "BACKGROUND")
    item.sel:SetTexture("Interface\\Buttons\\WHITE8x8")
    item.sel:SetVertexColor(0.3, 0.3, 0.5, 0.5)
    item.sel:SetAllPoints(item)
    item.sel:Hide()

    item.text = item:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    item.text:SetPoint("LEFT", 12, 0)
    item.text:SetPoint("RIGHT", -4, 0)
    item.text:SetJustifyH("LEFT")

    listItems[idx] = item
    return item
end

function DoF.UI:RefreshNPCLibraryList()
    if not frame then return end

    -- Скрываем все существующие элементы
    for _, item in ipairs(listItems) do
        item:Hide()
        if item.sel then item.sel:Hide() end
    end

    local templates
    if searchQuery ~= "" then
        templates = DoF.NPCLibrary:Search(searchQuery)
    else
        templates = DoF.NPCLibrary:GetSorted()
    end

    -- Группировка по категориям
    local categories = {}
    local catOrder = {}
    for _, tmpl in ipairs(templates) do
        local cat = tmpl.category or ""
        if cat == "" then cat = DoF.L["npc.ui.no_category"] end
        if not categories[cat] then
            categories[cat] = {}
            table_insert(catOrder, cat)
        end
        table_insert(categories[cat], tmpl)
    end

    local yOff = 0
    local itemIdx = 0
    local hasItems = false

    for _, cat in ipairs(catOrder) do
        hasItems = true
        itemIdx = itemIdx + 1

        -- Заголовок категории
        local catItem = EnsureListItem(itemIdx, CAT_HEIGHT)
        catItem.text:ClearAllPoints()
        catItem.text:SetPoint("LEFT", 2, 0)
        catItem.text:SetPoint("RIGHT", -4, 0)
        local isCollapsed = collapsedCategories[cat]
        catItem.text:SetText((isCollapsed and "> " or "v ") .. cat)
        catItem.text:SetTextColor(0.7, 0.6, 0.2)
        catItem:SetPoint("TOPLEFT", 0, -yOff)
        catItem:SetScript("OnClick", function()
            collapsedCategories[cat] = not collapsedCategories[cat]
            DoF.UI:RefreshNPCLibraryList()
        end)
        catItem.isCategoryHeader = true
        catItem.templateId = nil
        if catItem.sel then catItem.sel:Hide() end
        catItem:Show()
        yOff = yOff + CAT_HEIGHT

        if not isCollapsed then
            for _, tmpl in ipairs(categories[cat]) do
                itemIdx = itemIdx + 1
                local item = EnsureListItem(itemIdx, ITEM_HEIGHT)
                item.text:ClearAllPoints()
                item.text:SetPoint("LEFT", 12, 0)
                item.text:SetPoint("RIGHT", -4, 0)
                item.text:SetText(tmpl.name or "?")
                item.text:SetTextColor(1, 1, 1)

                item.templateId = tmpl.id
                item.isCategoryHeader = false
                item:SetPoint("TOPLEFT", 0, -yOff)

                if tmpl.id == selectedTemplateId and item.sel then
                    item.sel:Show()
                elseif item.sel then
                    item.sel:Hide()
                end

                item:SetScript("OnClick", function(self)
                    selectedTemplateId = self.templateId
                    DoF.UI:RefreshNPCLibrary()
                end)

                item:Show()
                yOff = yOff + ITEM_HEIGHT
            end
        end
    end

    frame.listChild:SetHeight(math.max(yOff, 1))
    frame.emptyText:SetShown(not hasItems)
end

-- ===========================================================
-- ОБНОВЛЕНИЕ ДЕТАЛЕЙ (правая панель)
-- ===========================================================

function DoF.UI:RefreshNPCLibraryDetail()
    if not frame then return end

    -- Скрываем кнопки атак
    for i = 1, MAX_ATTACKS_SHOWN do
        attackButtons[i]:Hide()
    end

    local tmpl = selectedTemplateId and DoF.NPCLibrary:Get(selectedTemplateId)

    if not tmpl then
        frame.detailName:SetText(DoF.L["npc.ui.choose_template"])
        frame.detailName:SetTextColor(0.5, 0.5, 0.5)
        frame.detailStats:SetText("")
        frame.detailAttacksLabel:Hide()
        frame.applyBtn:Disable()
        frame.editBtn:Disable()
        frame.dupeBtn:Disable()
        frame.deleteBtn:Disable()
        return
    end

    frame.detailName:SetText(tmpl.name or "?")
    frame.detailName:SetTextColor(1, 0.82, 0)
    frame.detailStats:SetText(
        "|cFFFF6666HP:|r " .. (tmpl.hp or 10) ..
        DoF.Locale:Format("npc.ui.stat_line", tmpl.fort or 10, tmpl.reflex or 10, tmpl.will or 10)
    )

    -- Кнопки атак
    local attacks = tmpl.attacks or {}
    if #attacks > 0 then
        frame.detailAttacksLabel:Show()
        for i, atk in ipairs(attacks) do
            if i > MAX_ATTACKS_SHOWN then break end
            local btn = attackButtons[i]
            local dmgStr = atk.damageMin .. "-" .. atk.damageMax
            local defStr = DefenseShort(atk.defenseStat)
            local label = DoF.Locale:Format("npc.ui.attack_line", atk.name or DoF.L["npc.attack_default"], dmgStr, atk.threshold, defStr)
            if atk.debuffId and atk.debuffId ~= "" then
                label = label .. " +" .. DebuffShort(atk.debuffId)
            end
            btn:SetText(label)

            local capturedIdx = i
            btn:SetScript("OnClick", function()
                DoF.NPCLibrary:AttackFromTemplate(selectedTemplateId, capturedIdx)
            end)
            btn:Show()
        end
    else
        frame.detailAttacksLabel:Hide()
    end

    -- Кнопки действий
    frame.applyBtn:Enable()
    frame.editBtn:Enable()
    frame.dupeBtn:Enable()
    frame.deleteBtn:Enable()
    frame.deleteBtn._confirmId = nil
    frame.deleteBtn:SetText(DoF.L["npc.ui.delete"])
end

-- ===========================================================
-- ОБНОВЛЕНИЕ ПОЛНОГО ОКНА
-- ===========================================================

function DoF.UI:RefreshNPCLibrary()
    if not frame then return end
    self:RefreshNPCLibraryList()
    self:RefreshNPCLibraryDetail()
end

-- ===========================================================
-- ПОКАЗАТЬ / СКРЫТЬ / ПЕРЕКЛЮЧИТЬ
-- ===========================================================

function DoF.UI:ShowNPCLibrary()
    EnsureFrame()
    self:RefreshNPCLibrary()
    frame:Show()
end

function DoF.UI:HideNPCLibrary()
    if frame then frame:Hide() end
end

function DoF.UI:ToggleNPCLibrary()
    EnsureFrame()
    if frame:IsShown() then
        frame:Hide()
    else
        self:RefreshNPCLibrary()
        frame:Show()
    end
end
