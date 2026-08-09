-- DoF/UI/Dialogs_Combat.lua
-- Боевые диалоги: защита от NPC, выбор крита, особое действие

local ADDON_NAME, DoF = ...

-- Кэширование глобальных функций
local CreateFrame = CreateFrame
local pairs = pairs
local ipairs = ipairs
local tonumber = tonumber
local string_format = string.format
local math_random = math.random
local math_min = math.min
local table_insert = table.insert
local UnitName = UnitName
local PlaySound = PlaySound
local C_Timer = C_Timer


-- ═══════════════════════════════════════════════════════════
-- ОКНО ЗАЩИТЫ ОТ АТАКИ NPC (для игрока)
-- ═══════════════════════════════════════════════════════════

local DefenseFrame = nil
local defenseTimer = nil

local function CreateDefenseFrame()
    if DefenseFrame then return DefenseFrame end

    local f = CreateFrame("Frame", "DoF_DefenseFrame", UIParent, "DoF_DialogTemplate")
    f:SetSize(320, 200)
    f:SetPoint("CENTER", 0, 100)
    f:SetFrameStrata("DIALOG")
    f:Hide()
    -- Forced action: закрыть нельзя — только нажать «ЗАЩИТА» или ждать таймер
    if f.CloseButton then f.CloseButton:Hide() end
    f.Header:Setup(DoF.L["ui.combat.attacked_title"])

    -- Имя NPC
    f.npcName = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    f.npcName:SetPoint("TOP", 0, -50)
    f.npcName:SetText("")

    -- Против какой защиты
    f.defenseText = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.defenseText:SetPoint("TOP", 0, -80)
    f.defenseText:SetText("")

    -- Таймер
    f.timerText = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    f.timerText:SetPoint("TOP", 0, -108)
    f.timerText:SetText("")

    -- Кнопка защиты
    f.defendBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    f.defendBtn:SetSize(180, 32)
    f.defendBtn:SetPoint("BOTTOM", 0, 18)
    f.defendBtn:SetText(DoF.L["ui.combat.defend_btn"])
    f.defendBtn:SetScript("OnClick", function()
        DoF.Dialogs:OnDefenseClicked()
    end)

    DefenseFrame = f
    return f
end

local function StopDefenseTimer()
    if defenseTimer then
        defenseTimer:Cancel()
        defenseTimer = nil
    end
end

local function StartDefenseTimer(duration, onTimeout)
    StopDefenseTimer()

    local f = DefenseFrame
    if not f then return end

    local endTime = GetTime() + duration

    defenseTimer = C_Timer.NewTicker(0.1, function()
        local remaining = endTime - GetTime()
        if remaining <= 0 then
            StopDefenseTimer()
            if onTimeout then onTimeout() end
            return
        end

        local color = remaining > 10 and "FFFFFF" or (remaining > 5 and "FFFF00" or "FF0000")
        f.timerText:SetText(DoF.Locale:Format("ui.combat.timer_sec", color, remaining))
    end)
end

function DoF.Dialogs:ShowNPCAttackAlert(npcName, defenseStat, damageMin, damageMax, threshold, debuffId, debuffValue, debuffDuration)
    -- Если диалог защиты уже показан — не перезаписываем данные
    if DefenseFrame and DefenseFrame:IsShown() then
        DoF.Utils:Error(DoF.L["errors.new_attack_while_open"])
        return
    end

    local f = CreateDefenseFrame()

    local statNames = {
        Fortitude = DoF.L["stats.fortitude.label"],
        Reflex    = DoF.L["stats.reflex.label"],
        Will      = DoF.L["stats.will.label"],
    }

    f.npcName:SetText(npcName)
    f.defenseText:SetText(DoF.Locale:Format("ui.combat.against_your", statNames[defenseStat] or defenseStat))
    f.defenseText:Show()

    -- Если урон == 0, это проверка, а не атака
    if damageMin == 0 and damageMax == 0 then
        f.Header:Setup(DoF.L["ui.combat.check_title"])
        f.defendBtn:SetText(DoF.L["ui.combat.roll_btn"])
    else
        f.Header:Setup(DoF.L["ui.combat.attacked_title"])
        f.defendBtn:SetText(DoF.L["ui.combat.defend_btn"])
    end

    -- Сохраняем данные
    f.pendingDamageMin = damageMin
    f.pendingDamageMax = damageMax
    f.pendingThreshold = threshold
    f.pendingDefense = defenseStat
    f.pendingNPCName = npcName
    f.isHybrid = false
    f.pendingDebuffId = debuffId
    f.pendingDebuffValue = debuffValue
    f.pendingDebuffDuration = debuffDuration

    f:Show()
    PlaySound(8959, "SFX") -- RAID_WARNING

    -- Запускаем таймер 30 сек
    StartDefenseTimer(30, function()
        -- Автонеудача
        DoF.Dialogs:OnDefenseTimeout()
    end)
end

function DoF.Dialogs:ShowHybridDefenseChoice(npcName, damageMin, damageMax, threshold, debuffId, debuffValue, debuffDuration)
    -- Если диалог защиты уже показан — не перезаписываем данные
    if DefenseFrame and DefenseFrame:IsShown() then
        DoF.Utils:Error(DoF.L["errors.new_attack_while_open"])
        return
    end

    local f = CreateDefenseFrame()

    f.npcName:SetText(npcName)
    f.defenseText:SetText(DoF.L["ui.combat.choose_defense"])
    f.defenseText:Show()
    f.defendBtn:SetText(DoF.L["ui.combat.defend_btn"])
    f.Header:Setup(DoF.L["ui.combat.attacked_title"])

    -- Сохраняем данные
    f.pendingDamageMin = damageMin
    f.pendingDamageMax = damageMax
    f.pendingThreshold = threshold
    f.pendingDefense = nil
    f.pendingNPCName = npcName
    f.isHybrid = true
    f.pendingDebuffId = debuffId
    f.pendingDebuffValue = debuffValue
    f.pendingDebuffDuration = debuffDuration

    f:Show()
    PlaySound(8959, "SFX") -- RAID_WARNING

    -- Запускаем таймер 30 сек
    StartDefenseTimer(30, function()
        DoF.Dialogs:OnDefenseTimeout()
    end)
end

function DoF.Dialogs:OnDefenseClicked()
    local f = DefenseFrame
    if not f then return end

    if f.isHybrid then
        -- Показываем выпадающее меню выбора защиты
        DoF.Dialogs:ShowDefenseDropdown(f.defendBtn)
    else
        -- Обычная защита - сразу бросаем
        StopDefenseTimer()
        f:Hide()

        if DoF.Combat and DoF.Combat.ProcessNPCAttack then
            DoF.Combat:ProcessNPCAttack(f.pendingDamageMin, f.pendingDamageMax, f.pendingThreshold, f.pendingDefense, f.pendingNPCName, f.pendingDebuffId, f.pendingDebuffValue, f.pendingDebuffDuration)
        end
    end
end

local cachedDefenseDropdown = nil

function DoF.Dialogs:ShowDefenseDropdown(button)
    if not cachedDefenseDropdown then
        cachedDefenseDropdown = CreateFrame("Frame", "DoF_DefenseDropdownMenu", UIParent, "TooltipBackdropTemplate")
        cachedDefenseDropdown:SetSize(180, 80)
        cachedDefenseDropdown:SetFrameStrata("FULLSCREEN_DIALOG")

        local defenses = {
            { "Fortitude", DoF.L["stats.fortitude.label"] },
            { "Reflex",    DoF.L["stats.reflex.label"] },
            { "Will",      DoF.L["stats.will.label"] },
        }

        local y = -5
        for _, def in ipairs(defenses) do
            local btn = CreateFrame("Button", nil, cachedDefenseDropdown)
            btn:SetSize(170, 24)
            btn:SetPoint("TOP", 0, y)

            local hl = btn:CreateTexture(nil, "HIGHLIGHT")
            hl:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
            hl:SetBlendMode("ADD")
            hl:SetAllPoints(btn)

            btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            btn.text:SetPoint("CENTER")
            btn.text:SetText(def[2])

            btn:SetScript("OnClick", function()
                cachedDefenseDropdown:Hide()
                DoF.Dialogs:OnHybridDefenseSelected(def[1])
            end)

            y = y - 25
        end
    end

    -- Обновляем OnUpdate с текущей кнопкой для проверки hover
    cachedDefenseDropdown:SetScript("OnUpdate", function(self)
        if not self:IsMouseOver() and not button:IsMouseOver() and IsMouseButtonDown("LeftButton") then
            self:Hide()
        end
    end)

    cachedDefenseDropdown:ClearAllPoints()
    cachedDefenseDropdown:SetPoint("BOTTOM", button, "TOP", 0, 5)
    cachedDefenseDropdown:Show()
end

function DoF.Dialogs:OnHybridDefenseSelected(defenseStat)
    local f = DefenseFrame
    if not f then return end

    StopDefenseTimer()
    f:Hide()

    -- Выполняем бросок защиты с выбранной статой
    if DoF.Combat and DoF.Combat.ProcessNPCAttack then
        DoF.Combat:ProcessNPCAttack(f.pendingDamageMin, f.pendingDamageMax, f.pendingThreshold, defenseStat, f.pendingNPCName, f.pendingDebuffId, f.pendingDebuffValue, f.pendingDebuffDuration)
    end
end

function DoF.Dialogs:OnDefenseTimeout()
    local f = DefenseFrame
    if not f or not f:IsShown() then return end

    local npcName = f.pendingNPCName or "NPC"
    local damageMin = f.pendingDamageMin or 0
    local damageMax = f.pendingDamageMax or damageMin

    f:Hide()

    -- Автонеудача - получаем полный урон (бросок в диапазоне) + дебафф
    if DoF.Combat then
        DoF.Combat:ProcessDefenseFailure(damageMin, damageMax, npcName, f.pendingDebuffId, f.pendingDebuffValue, f.pendingDebuffDuration)
    end
end

-- ═══════════════════════════════════════════════════════════
-- ДИАЛОГ ВЫБОРА КРИТА (по аналогии с DefenseFrame)
-- ═══════════════════════════════════════════════════════════

local CritChoiceFrame = nil
local critChoiceTimer = nil
local CRIT_CHOICE_TIMEOUT = 20  -- секунд

local function StopCritChoiceTimer()
    if critChoiceTimer then
        critChoiceTimer:Cancel()
        critChoiceTimer = nil
    end
end

local function StartCritChoiceTimer(duration, onTimeout)
    StopCritChoiceTimer()
    local f = CritChoiceFrame
    if not f then return end
    local endTime = GetTime() + duration
    critChoiceTimer = C_Timer.NewTicker(0.1, function()
        local remaining = endTime - GetTime()
        if remaining <= 0 then
            StopCritChoiceTimer()
            if onTimeout then onTimeout() end
            return
        end
        local color = remaining > 10 and "FFFFFF" or (remaining > 5 and "FFFF00" or "FF0000")
        f.timerText:SetText(DoF.Locale:Format("ui.combat.timer_sec", color, remaining))
    end)
end

local function CreateCritChoiceFrame()
    if CritChoiceFrame then return CritChoiceFrame end

    local f = CreateFrame("Frame", "DoF_CritChoiceFrame", UIParent, "DoF_DialogTemplate")
    f:SetSize(320, 240)
    f:SetPoint("CENTER", 0, 100)
    f:SetFrameStrata("DIALOG")
    f:Hide()
    -- Forced action: только выбор бонуса или таймер, крестик скрыт
    if f.CloseButton then f.CloseButton:Hide() end
    f.Header:Setup(DoF.L["ui.combat.crit_hit_title"])

    -- Описание
    f.desc = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.desc:SetPoint("TOP", 0, -50)
    f.desc:SetText(DoF.L["ui.combat.choose_bonus"])

    -- Таймер
    f.timerText = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    f.timerText:SetPoint("TOP", 0, -72)
    f.timerText:SetText("")

    -- Контейнер для кнопок
    f.btnContainer = CreateFrame("Frame", nil, f)
    f.btnContainer:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -100)
    f.btnContainer:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -20, 20)

    f.buttons = {}
    for i = 1, 4 do
        local btn = CreateFrame("Button", nil, f.btnContainer, "UIPanelButtonTemplate")
        btn:SetSize(280, 26)
        btn.text = btn:GetFontString()  -- алиас для btn.text:SetText
        btn:Hide()
        f.buttons[i] = btn
    end

    CritChoiceFrame = f
    return f
end

-- Показать диалог выбора при крите атаки
function DoF.Dialogs:ShowCritChoiceMenu(actionType, callback, baseDamage, targetGuid, targetName)
    local f = CreateCritChoiceFrame()
    local role = DoF.Stats:GetRole()

    DoF.Combat.CritChoicePending = true

    f.Header:Setup(DoF.L["ui.combat.crit_hit_title"])
    f.desc:SetText(DoF.L["ui.combat.choose_bonus"])

    -- Собираем варианты
    local choices = {}

    -- 1. Бонус к урону
    local range = DoF.Config:GetDamageRange(DoF.Stats:GetLevel(), role)
    local critBonus = math_min(range.max, DoF.Config.CRIT_BONUS_CAP)
    table_insert(choices, {
        text = DoF.Locale:Format("ui.combat.bonus_damage", critBonus),
        action = function()
            callback("bonus_damage", baseDamage, targetGuid, targetName)
        end
    })

    -- 2. +1 энергия
    table_insert(choices, {
        text = DoF.L["ui.combat.bonus_energy"],
        action = function()
            DoF.Stats:AddEnergy(1)
            callback("energy", baseDamage, targetGuid, targetName)
        end
    })

    -- 3. Полное исцеление (только Целитель)
    if role == "healer" then
        table_insert(choices, {
            text = DoF.L["ui.combat.bonus_full_heal"],
            action = function()
                callback("full_heal", baseDamage, targetGuid, targetName)
            end
        })
    end

    -- 4. Щит (1 удар) (только Танк)
    if role == "tank" then
        table_insert(choices, {
            text = DoF.L["ui.combat.bonus_shield"],
            action = function()
                DoF.Stats:ApplyShield()
                DoF.Utils:Info(DoF.L["ui.combat.shield_activated"])
                callback("shield", baseDamage, targetGuid, targetName)
            end
        })
    end

    -- Настраиваем кнопки
    for i, btn in ipairs(f.buttons) do
        if choices[i] then
            btn:SetPoint("TOPLEFT", f.btnContainer, "TOPLEFT", 0, -(i - 1) * 32)
            btn.text:SetText(choices[i].text)
            btn:SetScript("OnClick", function()
                StopCritChoiceTimer()
                DoF.Combat.CritChoicePending = false
                f:Hide()
                choices[i].action()
            end)
            btn:Show()
        else
            btn:Hide()
        end
    end

    -- Подгоняем высоту фрейма
    local totalHeight = 90 + #choices * 32 + 15
    f:SetSize(320, totalHeight)

    f:Show()
    PlaySound(8960, "SFX")  -- READY_CHECK

    -- Таймер 20 сек, при таймауте — случайный выбор
    StartCritChoiceTimer(CRIT_CHOICE_TIMEOUT, function()
        if not f:IsShown() then return end
        DoF.Combat.CritChoicePending = false
        f:Hide()
        local randomChoice = choices[math_random(1, #choices)]
        DoF.Utils:Warn(DoF.L["ui.combat.time_up_crit"])
        randomChoice.action()
    end)
end

-- Показать диалог выбора при крите исцеления
function DoF.Dialogs:ShowHealCritChoiceMenu(callback)
    local f = CreateCritChoiceFrame()

    DoF.Combat.CritChoicePending = true

    f.Header:Setup(DoF.L["ui.combat.crit_heal_title"])
    f.desc:SetText(DoF.L["ui.combat.choose_bonus"])

    local choices = {}

    -- 1. Полное исцеление
    table_insert(choices, {
        text = DoF.L["ui.combat.bonus_full_heal"],
        action = function()
            callback("full_heal")
        end
    })

    -- 2. +1 энергия
    table_insert(choices, {
        text = DoF.L["ui.combat.bonus_energy"],
        action = function()
            DoF.Stats:AddEnergy(1)
            callback("energy")
        end
    })

    -- 3. Щит на цель хила
    table_insert(choices, {
        text = DoF.L["ui.combat.bonus_shield"],
        action = function()
            callback("shield")
        end
    })

    -- Настраиваем кнопки
    for i, btn in ipairs(f.buttons) do
        if choices[i] then
            btn:SetPoint("TOPLEFT", f.btnContainer, "TOPLEFT", 0, -(i - 1) * 32)
            btn.text:SetText(choices[i].text)
            btn:SetScript("OnClick", function()
                StopCritChoiceTimer()
                DoF.Combat.CritChoicePending = false
                f:Hide()
                choices[i].action()
            end)
            btn:Show()
        else
            btn:Hide()
        end
    end

    local totalHeight = 90 + #choices * 32 + 15
    f:SetSize(320, totalHeight)

    f:Show()
    PlaySound(8960, "SFX")

    StartCritChoiceTimer(CRIT_CHOICE_TIMEOUT, function()
        if not f:IsShown() then return end
        DoF.Combat.CritChoicePending = false
        f:Hide()
        local randomChoice = choices[math_random(1, #choices)]
        DoF.Utils:Warn(DoF.L["ui.combat.time_up_crit"])
        randomChoice.action()
    end)
end

-- Показать диалог выбора при крите защиты
function DoF.Dialogs:ShowDefenseCritChoiceMenu(callback, attackerName, attackerGuid)
    local f = CreateCritChoiceFrame()
    local role = DoF.Stats:GetRole()

    DoF.Combat.CritChoicePending = true

    f.Header:Setup(DoF.L["ui.combat.crit_defense_title"])
    f.desc:SetText(DoF.L["ui.combat.choose_bonus"])

    local choices = {}

    -- 1. Контратака
    table_insert(choices, {
        text = DoF.L["ui.combat.bonus_counterattack"],
        action = function()
            callback("counterattack", attackerName, attackerGuid)
        end
    })

    -- 2. +1 энергия
    table_insert(choices, {
        text = DoF.L["ui.combat.bonus_energy"],
        action = function()
            DoF.Stats:AddEnergy(1)
            callback("energy", attackerName, attackerGuid)
        end
    })

    -- 3. +2 HP союзнику (Танк)
    if role == "tank" then
        table_insert(choices, {
            text = DoF.L["ui.combat.bonus_ally_hp"],
            action = function()
                callback("tank_hp_buff", attackerName, attackerGuid)
            end
        })
    end

    for i, btn in ipairs(f.buttons) do
        if choices[i] then
            btn:SetPoint("TOPLEFT", f.btnContainer, "TOPLEFT", 0, -(i - 1) * 32)
            btn.text:SetText(choices[i].text)
            btn:SetScript("OnClick", function()
                StopCritChoiceTimer()
                DoF.Combat.CritChoicePending = false
                f:Hide()
                choices[i].action()
            end)
            btn:Show()
        else
            btn:Hide()
        end
    end

    local totalHeight = 90 + #choices * 32 + 15
    f:SetSize(320, totalHeight)

    f:Show()
    PlaySound(8960, "SFX")

    StartCritChoiceTimer(CRIT_CHOICE_TIMEOUT, function()
        if not f:IsShown() then return end
        DoF.Combat.CritChoicePending = false
        f:Hide()
        local randomChoice = choices[math_random(1, #choices)]
        DoF.Utils:Warn(DoF.L["ui.combat.time_up_defense"])
        randomChoice.action()
    end)
end


-- ═══════════════════════════════════════════════════════════
-- ОСОБОЕ ДЕЙСТВИЕ
-- ═══════════════════════════════════════════════════════════

local SpecialActionFrame = nil

local function CreateSpecialActionFrame()
    if SpecialActionFrame then return SpecialActionFrame end

    local f = CreateFrame("Frame", "DoF_SpecialActionFrame", UIParent, "DoF_DialogTemplate")
    f:SetSize(420, 300)
    f:SetPoint("CENTER", 0, 50)
    f:SetFrameStrata("DIALOG")
    f:Hide()
    f.Header:Setup(DoF.L["ui.combat.special_request_title"])

    -- Описание
    f.desc = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.desc:SetPoint("TOP", 0, -40)
    f.desc:SetText(DoF.L["ui.combat.special_request_desc"])
    f.desc:SetTextColor(0.7, 0.7, 0.7)

    -- Контейнер для поля ввода с видимой рамкой
    f.inputContainer = CreateFrame("Frame", nil, f, "InsetFrameTemplate")
    f.inputContainer:SetPoint("TOPLEFT", 15, -65)
    f.inputContainer:SetPoint("BOTTOMRIGHT", -15, 55)

    -- Клик по контейнеру активирует EditBox
    f.inputContainer:EnableMouse(true)
    f.inputContainer:SetScript("OnMouseDown", function()
        f.editBox:SetFocus()
    end)

    -- Поле ввода (внутри контейнера)
    f.scrollFrame = CreateFrame("ScrollFrame", nil, f.inputContainer, "UIPanelScrollFrameTemplate")
    f.scrollFrame:SetPoint("TOPLEFT", 8, -8)
    f.scrollFrame:SetPoint("BOTTOMRIGHT", -28, 8)

    -- Клик по ScrollFrame тоже активирует EditBox
    f.scrollFrame:EnableMouse(true)
    f.scrollFrame:SetScript("OnMouseDown", function()
        f.editBox:SetFocus()
    end)

    f.editBox = CreateFrame("EditBox", nil, f.scrollFrame)
    f.editBox:SetMultiLine(true)
    f.editBox:SetAutoFocus(false)
    f.editBox:SetFontObject(ChatFontNormal)
    f.editBox:SetWidth(320)
    f.editBox:SetScript("OnEscapePressed", function() f:Hide() end)
    f.editBox:SetScript("OnTextChanged", function(self)
        local text = self:GetText()
        local len = #text
        f.charCount:SetText(len .. "/" .. DoF.Config.SPECIAL_ACTION_MAX_TEXT)
        if len > DoF.Config.SPECIAL_ACTION_MAX_TEXT then
            f.charCount:SetTextColor(1, 0.3, 0.3)
            f.sendBtn:Disable()
        else
            f.charCount:SetTextColor(0.6, 0.6, 0.6)
            f.sendBtn:Enable()
        end
    end)

    f.scrollFrame:SetScrollChild(f.editBox)

    -- Счётчик символов (справа от кнопки Отмена)
    f.charCount = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    f.charCount:SetPoint("BOTTOM", 0, 18)
    f.charCount:SetText("0/" .. DoF.Config.SPECIAL_ACTION_MAX_TEXT)
    f.charCount:SetTextColor(0.6, 0.6, 0.6)

    -- Кнопка отправки
    f.sendBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    f.sendBtn:SetSize(140, 26)
    f.sendBtn:SetPoint("BOTTOMRIGHT", -15, 12)
    f.sendBtn:SetText(DoF.L["ui.combat.send_request"])
    f.sendBtn.text = f.sendBtn:GetFontString()  -- алиас
    f.sendBtn:SetScript("OnClick", function()
        DoF.Dialogs:SubmitSpecialAction()
    end)

    -- Кнопка отмены
    f.cancelBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    f.cancelBtn:SetSize(90, 26)
    f.cancelBtn:SetPoint("BOTTOMLEFT", 15, 12)
    f.cancelBtn:SetText(DoF.L["ui.common.cancel"])
    f.cancelBtn:SetScript("OnClick", function() f:Hide() end)

    -- Крестик уже есть в DoF_DialogTemplate (self.CloseButton)

    SpecialActionFrame = f
    return f
end

function DoF.Dialogs:ShowSpecialActionInput()
    local f = CreateSpecialActionFrame()
    f.editBox:SetText("")
    f.charCount:SetText("0/" .. DoF.Config.SPECIAL_ACTION_MAX_TEXT)
    f:Show()
    f.editBox:SetFocus()
end

-- Алиас для нового процесса запроса особого действия
function DoF.Dialogs:ShowSpecialActionRequestDialog()
    self:ShowSpecialActionInput()
end

function DoF.Dialogs:SubmitSpecialAction()
    local f = SpecialActionFrame
    if not f then return end

    local text = f.editBox:GetText()
    if #text == 0 then
        DoF.Utils:Error(DoF.L["errors.enter_action_desc"])
        return
    end

    if #text > DoF.Config.SPECIAL_ACTION_MAX_TEXT then
        DoF.Utils:Error(DoF.L["errors.text_too_long"])
        return
    end

    f:Hide()

    -- Сохраняем ожидающий запрос
    local playerName = UnitName("player")
    DoF.Combat.PendingSpecialAction = {
        playerName = playerName,
        description = text,
        timestamp = GetTime()
    }

    -- Если мы сами мастер - показать окно одобрения напрямую
    if DoF.Sync:IsMaster() then
        DoF.Dialogs:ShowMasterSpecialActionApproval(playerName, text)
        DoF.Utils:Info(DoF.L["ui.combat.you_are_gm_approve"])
    else
        -- Отправляем запрос мастеру
        DoF.Sync:SendSpecialActionRequest(text)
        DoF.Utils:Info(DoF.L["ui.combat.request_sent"])
    end
end

-- ═══════════════════════════════════════════════════════════
-- ОКНО МАСТЕРА ДЛЯ ОСОБЫХ ДЕЙСТВИЙ
-- ═══════════════════════════════════════════════════════════

-- Множественные окна одобрения для каждого игрока
local SpecialActionApprovalFrames = {}  -- {[playerName] = {frame=frame, timestamp=time}}
local FrameOffsetCounter = 0

function DoF.Dialogs:ShowMasterSpecialActionApproval(playerName, description)
    -- Если окно для этого игрока уже открыто, показать и поднять на передний план
    if SpecialActionApprovalFrames[playerName] then
        local data = SpecialActionApprovalFrames[playerName]
        data.frame:Show()
        data.frame:Raise()
        return
    end

    -- Создать уникальный фрейм для этого игрока
    local frameName = "DoF_MasterSpecialAction_" .. playerName:gsub(" ", "_")
    local f = CreateFrame("Frame", frameName, UIParent, "DoF_DialogTemplate")

    local LayoutApprovalDialog  -- forward declaration для динамической раскладки

    f:SetSize(420, 700)
    f:SetFrameStrata("FULLSCREEN_DIALOG")
    f.Header:Setup(DoF.L["ui.combat.special_request_title"])

    -- Расположить с смещением (каскадом)
    FrameOffsetCounter = FrameOffsetCounter + 40
    if FrameOffsetCounter > 200 then FrameOffsetCounter = 0 end
    f:SetPoint("CENTER", UIParent, "CENTER", FrameOffsetCounter, -FrameOffsetCounter)

    -- Имя игрока
    f.playerLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.playerLabel:SetPoint("TOPLEFT", 20, -45)
    f.playerLabel:SetText(DoF.Locale:Format("ui.combat.player_label", playerName))

    -- Контейнер для текста описания
    f.descContainer = CreateFrame("Frame", nil, f, "InsetFrameTemplate")
    f.descContainer:SetPoint("TOPLEFT", 15, -70)
    f.descContainer:SetPoint("TOPRIGHT", -15, -70)
    f.descContainer:SetHeight(80)

    -- ScrollFrame для текста
    f.scrollFrame = CreateFrame("ScrollFrame", nil, f.descContainer, "UIPanelScrollFrameTemplate")
    f.scrollFrame:SetPoint("TOPLEFT", 5, -5)
    f.scrollFrame:SetPoint("BOTTOMRIGHT", -25, 5)

    -- Контент для скролла
    f.scrollContent = CreateFrame("Frame", nil, f.scrollFrame)
    f.scrollContent:SetSize(330, 1)
    f.scrollFrame:SetScrollChild(f.scrollContent)

    -- Текст описания действия
    f.descText = f.scrollContent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.descText:SetPoint("TOPLEFT", 5, 0)
    f.descText:SetWidth(320)
    f.descText:SetWordWrap(true)
    f.descText:SetJustifyH("LEFT")
    f.descText:SetJustifyV("TOP")
    f.descText:SetText(description or "")
    f.descText:SetTextColor(0.9, 0.9, 0.9)

    -- Подгоняем высоту контента под текст
    f.scrollContent:SetHeight(math.max(70, f.descText:GetStringHeight() + 10))

    -- ═══════════════════════════════════════════════════════════
    -- ТИП ДЕЙСТВИЯ (новая секция)
    -- ═══════════════════════════════════════════════════════════
    f.actionTypeLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.actionTypeLabel:SetPoint("TOPLEFT", 20, -160)
    f.actionTypeLabel:SetText(DoF.L["ui.combat.action_type_label"])

    f.selectedActionType = "simple_roll"

    local actionTypeButtons = {}
    local actionTypeOrder = DoF.Config.SpecialActionTypeOrder
    local actionTypeNames = DoF.Config.SpecialActionTypes

    -- Функция обновления кнопок типа действия (через штатный LockHighlight)
    local function UpdateActionTypeButtons()
        for _, b in ipairs(actionTypeButtons) do
            if b.actionType == f.selectedActionType then
                b:LockHighlight()
            else
                b:UnlockHighlight()
            end
        end
    end

    -- Функция показа/скрытия условных панелей
    local function UpdateActionPanels()
        local at = f.selectedActionType
        -- Скрыть все панели
        if f.buffPanel then f.buffPanel:Hide() end
        if f.attackPanel then f.attackPanel:Hide() end
        if f.simpleLabel then f.simpleLabel:Hide() end
        -- Показать нужную
        if at == "buff" or at == "aoe_buff" then
            if f.buffPanel then f.buffPanel:Show() end
            if f.targetCountContainer then
                f.targetCountContainer:Show()
                if at == "buff" then
                    f.targetCountInput:SetText("1")
                elseif at == "aoe_buff" then
                    if f.targetCountInput:GetText() == "1" then f.targetCountInput:SetText("2") end
                end
            end
        elseif at == "attack" or at == "aoe_attack" then
            if f.attackPanel then f.attackPanel:Show() end
            if f.atkTargetCountContainer then
                if at == "aoe_attack" then f.atkTargetCountContainer:Show() else f.atkTargetCountContainer:Hide() end
            end
        elseif at == "wound_removal" or at == "dispel" or at == "purge" then
            if f.simpleLabel then
                f.simpleLabel:SetText(DoF.Locale:Format("ui.combat.simple_action_label", actionTypeNames[at] or at))
                f.simpleLabel:Show()
            end
        end
    end

    -- Ряд 1: 4 кнопки
    local row1Types = { "simple_roll", "buff", "aoe_buff", "attack" }
    local row2Types = { "aoe_attack", "wound_removal", "dispel", "purge" }

    local function CreateActionTypeRow(types, yOff)
        local xOff = 20
        for _, at in ipairs(types) do
            local atName = actionTypeNames[at] or at
            local btn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
            btn:SetSize(85, 22)
            btn:SetPoint("TOPLEFT", xOff, yOff)
            btn:SetNormalFontObject("GameFontNormalSmall")
            btn:SetHighlightFontObject("GameFontHighlightSmall")
            btn:SetText(atName)
            btn.text = btn:GetFontString()  -- алиас
            btn.actionType = at

            btn:SetScript("OnClick", function()
                f.selectedActionType = at
                UpdateActionTypeButtons()
                UpdateActionPanels()
                if LayoutApprovalDialog then LayoutApprovalDialog() end
            end)

            table.insert(actionTypeButtons, btn)
            xOff = xOff + 90
        end
    end

    CreateActionTypeRow(row1Types, -180)
    CreateActionTypeRow(row2Types, -207)
    UpdateActionTypeButtons()

    -- ═══════════════════════════════════════════════════════════
    -- УСЛОВНЫЕ ПАНЕЛИ ПАРАМЕТРОВ ДЕЙСТВИЯ
    -- ═══════════════════════════════════════════════════════════

    -- --- Панель бафов ---
    f.buffPanel = CreateFrame("Frame", nil, f)
    f.buffPanel:SetPoint("TOPLEFT", 15, -240)
    f.buffPanel:SetPoint("TOPRIGHT", -15, -240)
    f.buffPanel:SetHeight(150)
    f.buffPanel:Hide()

    local buffLabel = f.buffPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    buffLabel:SetPoint("TOPLEFT", 5, 0)
    buffLabel:SetText(DoF.L["ui.combat.choose_effect"])

    f.selectedEffectId = nil
    local buffButtons = {}

    -- Собираем бафы из Definitions
    local buffEffects = {}
    if DoF.Effects and DoF.Effects.Definitions then
        for id, def in pairs(DoF.Effects.Definitions) do
            if def.type == "buff" and def.category == "basic" and def.targetType == "player" then
                table.insert(buffEffects, { id = id, name = def.name, color = def.color })
            end
        end
    end
    -- Сортируем по имени
    table.sort(buffEffects, function(a, b) return a.name < b.name end)

    local function UpdateBuffButtons()
        for _, b in ipairs(buffButtons) do
            if b.effectId == f.selectedEffectId then
                b:LockHighlight()
            else
                b:UnlockHighlight()
            end
        end
    end

    local bxOff, byOff = 5, -18
    for i, eff in ipairs(buffEffects) do
        local btn = CreateFrame("Button", nil, f.buffPanel, "UIPanelButtonTemplate")
        btn:SetSize(115, 20)
        btn:SetPoint("TOPLEFT", bxOff, byOff)
        btn:SetNormalFontObject("GameFontNormalSmall")
        btn:SetHighlightFontObject("GameFontHighlightSmall")
        -- Кнопка узкая, поэтому нужен короткий вариант названия. Раньше префикс
        -- срезался через gsub("Усиление ", "") — на любом другом языке этот gsub
        -- просто не сработал бы, и текст не влез бы в кнопку. Теперь короткое
        -- название берётся из локали по id эффекта, с откатом на полное.
        local shortKey = "ui.buff." .. eff.id .. ".name"
        btn:SetText(DoF.Locale:Has(shortKey) and DoF.L[shortKey] or eff.name)
        btn.text = btn:GetFontString()
        btn.effectId = eff.id

        btn:SetScript("OnClick", function()
            f.selectedEffectId = eff.id
            UpdateBuffButtons()
        end)

        table.insert(buffButtons, btn)
        bxOff = bxOff + 120
        if bxOff > 300 then
            bxOff = 5
            byOff = byOff - 24
        end
    end

    -- Выбираем первый бафф по умолчанию
    if buffEffects[1] then
        f.selectedEffectId = buffEffects[1].id
        UpdateBuffButtons()
    end

    -- Контейнер кол-ва целей для АоЕ баффа
    f.targetCountContainer = CreateFrame("Frame", nil, f.buffPanel)
    f.targetCountContainer:SetPoint("TOPLEFT", 5, -120)
    f.targetCountContainer:SetSize(200, 24)
    f.targetCountContainer:Hide()

    local tcLabel = f.targetCountContainer:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    tcLabel:SetPoint("LEFT", 0, 0)
    tcLabel:SetText(DoF.L["ui.combat.target_count"])

    f.targetCountInput = CreateFrame("EditBox", nil, f.targetCountContainer, "InputBoxTemplate")
    f.targetCountInput:SetPoint("LEFT", tcLabel, "RIGHT", 12, 0)
    f.targetCountInput:SetSize(35, 20)
    f.targetCountInput:SetText("2")
    f.targetCountInput:SetAutoFocus(false)
    f.targetCountInput:SetNumeric(true)
    f.targetCountInput:SetMaxLetters(1)
    f.targetCountInput:SetTextInsets(5, 5, 0, 0)
    f.targetCountInput:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    f.targetCountInput:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)

    -- --- Панель атаки ---
    f.attackPanel = CreateFrame("Frame", nil, f)
    f.attackPanel:SetPoint("TOPLEFT", 15, -240)
    f.attackPanel:SetPoint("TOPRIGHT", -15, -240)
    f.attackPanel:SetHeight(50)
    f.attackPanel:Hide()

    local dmgLabel = f.attackPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    dmgLabel:SetPoint("TOPLEFT", 5, 0)
    dmgLabel:SetText(DoF.L["ui.combat.damage_min"])

    f.damageMinInput = CreateFrame("EditBox", nil, f.attackPanel, "InputBoxTemplate")
    f.damageMinInput:SetPoint("LEFT", dmgLabel, "RIGHT", 12, 0)
    f.damageMinInput:SetSize(40, 20)
    f.damageMinInput:SetText("1")
    f.damageMinInput:SetAutoFocus(false)
    f.damageMinInput:SetNumeric(true)
    f.damageMinInput:SetMaxLetters(3)
    f.damageMinInput:SetTextInsets(5, 5, 0, 0)
    f.damageMinInput:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    f.damageMinInput:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)

    local dmgMaxLabel = f.attackPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    dmgMaxLabel:SetPoint("LEFT", f.damageMinInput, "RIGHT", 10, 0)
    dmgMaxLabel:SetText(DoF.L["ui.combat.damage_max"])

    f.damageMaxInput = CreateFrame("EditBox", nil, f.attackPanel, "InputBoxTemplate")
    f.damageMaxInput:SetPoint("LEFT", dmgMaxLabel, "RIGHT", 12, 0)
    f.damageMaxInput:SetSize(40, 20)
    f.damageMaxInput:SetText("3")
    f.damageMaxInput:SetAutoFocus(false)
    f.damageMaxInput:SetNumeric(true)
    f.damageMaxInput:SetMaxLetters(3)
    f.damageMaxInput:SetTextInsets(5, 5, 0, 0)
    f.damageMaxInput:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    f.damageMaxInput:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)

    -- Контейнер кол-ва целей для АоЕ атаки
    f.atkTargetCountContainer = CreateFrame("Frame", nil, f.attackPanel)
    f.atkTargetCountContainer:SetPoint("TOPLEFT", 5, -28)
    f.atkTargetCountContainer:SetSize(200, 24)
    f.atkTargetCountContainer:Hide()

    local atkTcLabel = f.atkTargetCountContainer:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    atkTcLabel:SetPoint("LEFT", 0, 0)
    atkTcLabel:SetText(DoF.L["ui.combat.target_count"])

    f.atkTargetCountInput = CreateFrame("EditBox", nil, f.atkTargetCountContainer, "InputBoxTemplate")
    f.atkTargetCountInput:SetPoint("LEFT", atkTcLabel, "RIGHT", 12, 0)
    f.atkTargetCountInput:SetSize(35, 20)
    f.atkTargetCountInput:SetText("2")
    f.atkTargetCountInput:SetAutoFocus(false)
    f.atkTargetCountInput:SetNumeric(true)
    f.atkTargetCountInput:SetMaxLetters(1)
    f.atkTargetCountInput:SetTextInsets(5, 5, 0, 0)
    f.atkTargetCountInput:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    f.atkTargetCountInput:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)

    -- --- Простой лейбл для wound_removal/dispel/purge ---
    f.simpleLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    f.simpleLabel:SetPoint("TOPLEFT", 20, -240)
    f.simpleLabel:SetText("")
    f.simpleLabel:Hide()

    -- Начальное состояние панелей
    UpdateActionPanels()

    -- ═══════════════════════════════════════════════════════════
    -- ПОРОГ И ХАРАКТЕРИСТИКА (сдвинуты ниже)
    -- ═══════════════════════════════════════════════════════════

    -- Чекбокс "Без броска"
    f.noRollCheckbox = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
    f.noRollCheckbox:SetPoint("TOPLEFT", 18, -400)
    f.noRollCheckbox:SetSize(26, 26)
    f.noRollCheckbox:SetChecked(false)
    f.noRollCheckboxLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.noRollCheckboxLabel:SetPoint("LEFT", f.noRollCheckbox, "RIGHT", 4, 0)
    f.noRollCheckboxLabel:SetText(DoF.L["ui.combat.no_roll_label"])

    -- Поле ввода порога
    f.thresholdLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.thresholdLabel:SetPoint("TOPLEFT", 20, -435)
    f.thresholdLabel:SetText(DoF.L["ui.combat.threshold_label"])

    f.thresholdInput = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
    f.thresholdInput:SetPoint("LEFT", f.thresholdLabel, "RIGHT", 14, 0)
    f.thresholdInput:SetSize(50, 22)
    f.thresholdInput:SetText("14")
    f.thresholdInput:SetAutoFocus(false)
    f.thresholdInput:SetNumeric(true)
    f.thresholdInput:SetTextInsets(5, 5, 0, 0)
    f.thresholdInput:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    f.thresholdInput:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)

    -- Выбор характеристики (кнопки - две строки)
    f.statLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.statLabel:SetPoint("TOPLEFT", 20, -465)
    f.statLabel:SetText(DoF.L["ui.combat.stat_label"])

    f.selectedStat = "Strength"  -- По умолчанию

    f.statButtons = {}
    local row1Stats = { "Strength", "Dexterity", "Intelligence", "Spirit" }
    local row2Stats = { "Fortitude", "Reflex", "Will" }

    local function UpdateStatButtons()
        for _, b in ipairs(f.statButtons) do
            if b.stat == f.selectedStat then
                b:LockHighlight()
            else
                b:UnlockHighlight()
            end
        end
    end

    local function CreateStatRow(stats, yOff)
        local xOff = 20
        for _, stat in ipairs(stats) do
            local statName = DoF.Config.StatNames[stat] or stat

            local btn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
            btn:SetSize(85, 22)
            btn:SetPoint("TOPLEFT", xOff, yOff)
            btn:SetNormalFontObject("GameFontNormalSmall")
            btn:SetHighlightFontObject("GameFontHighlightSmall")
            btn:SetText(statName)
            btn.text = btn:GetFontString()
            btn.stat = stat

            btn:SetScript("OnClick", function()
                f.selectedStat = stat
                UpdateStatButtons()
            end)

            table.insert(f.statButtons, btn)
            xOff = xOff + 90
        end
    end

    CreateStatRow(row1Stats, -485)
    CreateStatRow(row2Stats, -512)
    UpdateStatButtons()

    -- Привязка видимости порога/стата к чекбоксу "Без броска"
    f.noRollCheckbox:SetScript("OnClick", function(self)
        local noRoll = self:GetChecked()
        if noRoll then
            f.thresholdLabel:Hide()
            f.thresholdInput:Hide()
            f.statLabel:Hide()
            for _, b in ipairs(f.statButtons) do b:Hide() end
        else
            f.thresholdLabel:Show()
            f.thresholdInput:Show()
            f.statLabel:Show()
            for _, b in ipairs(f.statButtons) do b:Show() end
        end
        if LayoutApprovalDialog then LayoutApprovalDialog() end
    end)

    -- ═══════════════════════════════════════════════════════════
    -- ЭНЕРГИЯ
    -- ═══════════════════════════════════════════════════════════

    -- Чекбокс "Запросить энергию"
    f.energyCheckbox = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
    f.energyCheckbox:SetPoint("TOPLEFT", 18, -545)
    f.energyCheckbox:SetSize(26, 26)
    f.energyCheckbox:SetChecked(true)
    f.energyCheckboxLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.energyCheckboxLabel:SetPoint("LEFT", f.energyCheckbox, "RIGHT", 4, 0)
    f.energyCheckboxLabel:SetText(DoF.L["ui.combat.request_energy"])

    -- Поле ввода количества энергии
    f.energyInput = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
    f.energyInput:SetPoint("LEFT", f.energyCheckboxLabel, "RIGHT", 14, 0)
    f.energyInput:SetSize(40, 20)
    f.energyInput:SetText("1")
    f.energyInput:SetAutoFocus(false)
    f.energyInput:SetNumeric(true)
    f.energyInput:SetMaxLetters(2)
    f.energyInput:SetTextInsets(5, 5, 0, 0)
    f.energyInput:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    f.energyInput:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)

    -- Привязка видимости поля к чекбоксу
    f.energyCheckbox:SetScript("OnClick", function(self)
        if self:GetChecked() then
            f.energyInput:Show()
        else
            f.energyInput:Hide()
        end
    end)

    -- ═══════════════════════════════════════════════════════════
    -- ДИНАМИЧЕСКАЯ РАСКЛАДКА
    -- ═══════════════════════════════════════════════════════════

    LayoutApprovalDialog = function()
        local at = f.selectedActionType or "simple_roll"

        -- Высота условной панели зависит от типа действия
        local panelH = 0
        if at == "buff" or at == "aoe_buff" then
            panelH = 155
        elseif at == "aoe_attack" then
            panelH = 58
        elseif at == "attack" then
            panelH = 28
        elseif at == "wound_removal" or at == "dispel" or at == "purge" then
            panelH = 20
        end

        -- yOff начинается после кнопок типа (заканчиваются на ~-231) + зазор + панель
        local yOff = -240 - panelH

        -- Чекбокс "Без броска"
        yOff = yOff - 10
        f.noRollCheckbox:ClearAllPoints()
        f.noRollCheckbox:SetPoint("TOPLEFT", 18, yOff)

        local noRoll = f.noRollCheckbox:GetChecked()

        if not noRoll then
            -- Порог
            yOff = yOff - 35
            f.thresholdLabel:ClearAllPoints()
            f.thresholdLabel:SetPoint("TOPLEFT", 20, yOff)
            f.thresholdInput:ClearAllPoints()
            f.thresholdInput:SetPoint("LEFT", f.thresholdLabel, "RIGHT", 10, 0)

            -- Лейбл "Характеристика"
            yOff = yOff - 30
            f.statLabel:ClearAllPoints()
            f.statLabel:SetPoint("TOPLEFT", 20, yOff)

            -- Кнопки статов ряд 1 (индексы 1-4)
            yOff = yOff - 20
            local xPos = 20
            for i = 1, math.min(4, #f.statButtons) do
                f.statButtons[i]:ClearAllPoints()
                f.statButtons[i]:SetPoint("TOPLEFT", xPos, yOff)
                xPos = xPos + 90
            end

            -- Кнопки статов ряд 2 (индексы 5+)
            yOff = yOff - 27
            xPos = 20
            for i = 5, #f.statButtons do
                f.statButtons[i]:ClearAllPoints()
                f.statButtons[i]:SetPoint("TOPLEFT", xPos, yOff)
                xPos = xPos + 90
            end
        else
            yOff = yOff - 4
        end

        -- Чекбокс "Запросить энергию"
        yOff = yOff - 33
        f.energyCheckbox:ClearAllPoints()
        f.energyCheckbox:SetPoint("TOPLEFT", 18, yOff)

        -- Итоговая высота: |yOff| + чекбокс энергии (26) + зазор (12) + кнопки (32) + отступ (15)
        local totalH = math.abs(yOff) + 85
        f:SetHeight(totalH)
    end

    -- ═══════════════════════════════════════════════════════════
    -- КНОПКИ ОДОБРИТЬ / ОТКЛОНИТЬ
    -- ═══════════════════════════════════════════════════════════

    -- Кнопка Одобрить
    f.approveBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    f.approveBtn:SetSize(150, 26)
    f.approveBtn:SetPoint("BOTTOMLEFT", 30, 18)
    f.approveBtn:SetText(DoF.L["ui.combat.approve"])
    f.approveBtn.text = f.approveBtn:GetFontString()  -- алиас для совместимости
    f.approveBtn:SetScript("OnClick", function()
        local threshold = tonumber(f.thresholdInput:GetText()) or 14
        local stat = f.selectedStat or "Strength"
        local desc = f.descText:GetText() or ""
        local requireEnergy = f.energyCheckbox:GetChecked()
        local energyAmount = requireEnergy and (tonumber(f.energyInput:GetText()) or 1) or 0
        local actionType = f.selectedActionType or "simple_roll"
        local noRoll = f.noRollCheckbox:GetChecked()

        -- Собираем actionParams в зависимости от типа
        local actionParams = ""
        if actionType == "buff" then
            if not f.selectedEffectId then
                DoF.Utils:Error(DoF.L["errors.select_buff_effect"])
                return
            end
            local tc = tonumber(f.targetCountInput:GetText()) or 1
            tc = math.max(1, math.min(4, tc))
            actionParams = f.selectedEffectId .. "|" .. tc
        elseif actionType == "aoe_buff" then
            if not f.selectedEffectId then
                DoF.Utils:Error(DoF.L["errors.select_buff_effect"])
                return
            end
            local tc = tonumber(f.targetCountInput:GetText()) or 2
            tc = math.max(2, math.min(4, tc))
            actionParams = f.selectedEffectId .. "|" .. tc
        elseif actionType == "attack" then
            local dmgMin = tonumber(f.damageMinInput:GetText()) or 1
            local dmgMax = tonumber(f.damageMaxInput:GetText()) or 3
            if dmgMin > dmgMax then dmgMin, dmgMax = dmgMax, dmgMin end
            actionParams = dmgMin .. "|" .. dmgMax
        elseif actionType == "aoe_attack" then
            local dmgMin = tonumber(f.damageMinInput:GetText()) or 1
            local dmgMax = tonumber(f.damageMaxInput:GetText()) or 3
            if dmgMin > dmgMax then dmgMin, dmgMax = dmgMax, dmgMin end
            local tc = tonumber(f.atkTargetCountInput:GetText()) or 2
            tc = math.max(2, math.min(4, tc))
            actionParams = dmgMin .. "|" .. dmgMax .. "|" .. tc
        end

        DoF.Sync:SendSpecialActionApproved(playerName, threshold, stat, desc, requireEnergy, energyAmount, actionType, actionParams, noRoll)
        SpecialActionApprovalFrames[playerName] = nil
        f:Hide()

        local typeName = actionTypeNames[actionType] or actionType
        DoF.Utils:Info(DoF.Locale:Format("ui.combat.special_approved_msg", playerName, typeName))
    end)

    -- Кнопка Отклонить
    f.rejectBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    f.rejectBtn:SetSize(150, 26)
    f.rejectBtn:SetPoint("BOTTOMRIGHT", -30, 18)
    f.rejectBtn:SetText(DoF.L["ui.combat.reject"])
    f.rejectBtn.text = f.rejectBtn:GetFontString()
    f.rejectBtn:SetScript("OnClick", function()
        DoF.Sync:SendSpecialActionRejected(playerName)
        SpecialActionApprovalFrames[playerName] = nil
        f:Hide()

        DoF.Utils:Info(DoF.Locale:Format("ui.combat.special_rejected_msg", playerName))
    end)

    -- Перехватываем встроенный CloseButton темплейта — добавляем очистку таблицы
    if f.CloseButton then
        f.CloseButton:SetScript("OnClick", function()
            SpecialActionApprovalFrames[playerName] = nil
            f:Hide()
        end)
    end

    -- Сохранить в таблице активных окон
    SpecialActionApprovalFrames[playerName] = {
        frame = f,
        timestamp = GetTime()
    }

    -- Начальная раскладка — ужимает окно под выбранный тип
    LayoutApprovalDialog()

    f:Show()
    PlaySound(8959, "SFX")
end

-- ═══════════════════════════════════════════════════════════
-- АЛИАСЫ ДЛЯ XML
-- ═══════════════════════════════════════════════════════════

-- Алиасы перенесены в Core/Aliases.lua

-- ═══════════════════════════════════════════════════════════
-- ОЧИСТКА ПРИ ОКОНЧАНИИ БОЯ
-- ═══════════════════════════════════════════════════════════

C_Timer.After(0.5, function()
    if DoF.Events then
        DoF.Events:Register("COMBAT_ENDED", function()
            -- Скрываем диалог защиты
            if DefenseFrame and DefenseFrame:IsShown() then
                StopDefenseTimer()
                DefenseFrame:Hide()
            end
            -- Скрываем диалог крит-выбора
            if CritChoiceFrame and CritChoiceFrame:IsShown() then
                StopCritChoiceTimer()
                CritChoiceFrame:Hide()
            end
            -- Скрываем диалог пробития защиты
            if TankShredFrame and TankShredFrame:IsShown() then
                TankShredFrame:Hide()
            end
        end, DoF.Dialogs)
    end
end)

-- ═══════════════════════════════════════════════════════════
-- ДИАЛОГ ВЫБОРА СТАТА ДЛЯ ПРОБИТИЯ ЗАЩИТЫ (ТАНК)
-- ═══════════════════════════════════════════════════════════

local TankShredFrame = nil

function DoF.Dialogs:ShowTankShredChoiceMenu(callback, npcGuid, npcName, fortMaxed, reflexMaxed)
    if not TankShredFrame then
        local f = CreateFrame("Frame", "DoF_TankShredChoice", UIParent, "DoF_DialogTemplate")
        f:SetSize(280, 160)
        f:SetPoint("CENTER", UIParent, "CENTER", 0, 100)
        f:SetFrameStrata("DIALOG")
        -- Forced action: танк должен выбрать стат, крестик скрыт
        if f.CloseButton then f.CloseButton:Hide() end
        f.Header:Setup(DoF.L["ui.combat.shred_title"])

        f.desc = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        f.desc:SetPoint("TOP", 0, -36)

        -- Кнопка Стойкость
        f.btnFort = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        f.btnFort:SetSize(110, 26)
        f.btnFort:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 14, 14)
        f.btnFort:SetText(DoF.L["stats.fortitude.label"])
        f.btnFort.text = f.btnFort:GetFontString()  -- алиас для старого кода

        -- Кнопка Сноровка
        f.btnReflex = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        f.btnReflex:SetSize(110, 26)
        f.btnReflex:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -14, 14)
        f.btnReflex:SetText(DoF.L["stats.reflex.label"])
        f.btnReflex.text = f.btnReflex:GetFontString()

        TankShredFrame = f
    end

    local f = TankShredFrame

    f.desc:SetText(DoF.Locale:Format("ui.combat.shred_desc", npcName or "NPC"))

    -- Обновить состояние кнопок (заблокировать если макс стаков)
    if fortMaxed then
        f.btnFort:Disable()
    else
        f.btnFort:Enable()
    end

    if reflexMaxed then
        f.btnReflex:Disable()
    else
        f.btnReflex:Enable()
    end

    f.btnFort:SetScript("OnClick", function()
        f:Hide()
        callback("fort")
    end)

    f.btnReflex:SetScript("OnClick", function()
        f:Hide()
        callback("reflex")
    end)

    f:Show()
    PlaySound(8960, "SFX")
end
