-- DoF/UI/Dialogs_Wound.lua
-- Диалоги для системы ранений: мастерский диалог при критическом ранении,
-- настройка броска на выживание (стата + DC), бросок у игрока.

local ADDON_NAME, DoF = ...

DoF.Dialogs = DoF.Dialogs or {}

-- ═══════════════════════════════════════════════════════════
-- ОБЩИЙ ХЕЛПЕР: базовая рамка диалога на DoF_DialogTemplate
-- ═══════════════════════════════════════════════════════════

local function MakeBaseFrame(name, w, h, title)
    local f = CreateFrame("Frame", name, UIParent, "DoF_DialogTemplate")
    f:SetSize(w, h)
    f:SetPoint("CENTER")
    f.Header:Setup(title)
    return f
end

-- ═══════════════════════════════════════════════════════════
-- 1) МАСТЕР: окно при критическом ранении игрока
--    Две кнопки: «Дать бросок» / «Оставить с ранением»
-- ═══════════════════════════════════════════════════════════

local masterFrame = nil

function DoF.Dialogs:ShowCriticalWoundMasterDialog(playerName)
    if not masterFrame then
        masterFrame = MakeBaseFrame("DoF_CritWoundMasterDialog", 380, 200, DoF.L["ui.wound.master_title"])

        masterFrame.playerLabel = masterFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        masterFrame.playerLabel:SetPoint("TOP", 0, -28)

        masterFrame.desc = masterFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        masterFrame.desc:SetPoint("TOP", 0, -58)
        masterFrame.desc:SetPoint("LEFT", 20, 0)
        masterFrame.desc:SetPoint("RIGHT", -20, 0)
        masterFrame.desc:SetJustifyH("CENTER")
        masterFrame.desc:SetWordWrap(true)
        masterFrame.desc:SetText(DoF.L["ui.wound.master_desc"])

        masterFrame.rollBtn = CreateFrame("Button", nil, masterFrame, "UIPanelButtonTemplate")
        masterFrame.rollBtn:SetSize(140, 26)
        masterFrame.rollBtn:SetPoint("BOTTOMLEFT", 30, 20)
        masterFrame.rollBtn:SetText(DoF.L["ui.wound.give_roll"])

        masterFrame.leaveBtn = CreateFrame("Button", nil, masterFrame, "UIPanelButtonTemplate")
        masterFrame.leaveBtn:SetSize(160, 26)
        masterFrame.leaveBtn:SetPoint("BOTTOMRIGHT", -30, 20)
        masterFrame.leaveBtn:SetText(DoF.L["ui.wound.leave_wounded"])
    end

    masterFrame.playerLabel:SetText(playerName)

    masterFrame.rollBtn:SetScript("OnClick", function()
        masterFrame:Hide()
        DoF.Dialogs:ShowSurvivalRollSetup(playerName)
    end)
    masterFrame.leaveBtn:SetScript("OnClick", function()
        masterFrame:Hide()
        if DoF.Sync then
            DoF.Sync:BroadcastCombatLogKey("ui.wound.left_wounded_log", playerName)
        end
    end)

    masterFrame:Show()
    masterFrame:Raise()
    PlaySound(8959, "Master") -- RAID_WARNING
end

-- ═══════════════════════════════════════════════════════════
-- 2) МАСТЕР: настройка броска — выбор статы + DC
-- ═══════════════════════════════════════════════════════════

local setupFrame = nil
local selectedStat = nil
local statButtons = {}

local function UpdateStatButtons()
    for _, btn in ipairs(statButtons) do
        if btn.stat == selectedStat then
            btn:LockHighlight()
        else
            btn:UnlockHighlight()
        end
    end
end

function DoF.Dialogs:ShowSurvivalRollSetup(playerName)
    if not setupFrame then
        setupFrame = MakeBaseFrame("DoF_SurvivalRollSetup", 440, 240, DoF.L["ui.wound.setup_title"])

        setupFrame.playerLabel = setupFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        setupFrame.playerLabel:SetPoint("TOP", 0, -28)

        setupFrame.statLabel = setupFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        setupFrame.statLabel:SetPoint("TOPLEFT", 20, -60)
        setupFrame.statLabel:SetText(DoF.L["ui.combat.stat_label"])

        -- Ряд из 7 кнопок со статами
        local allStats = DoF.Config.AllStats
        local xOff = 20
        for i, stat in ipairs(allStats) do
            local btn = CreateFrame("Button", nil, setupFrame, "UIPanelButtonTemplate")
            btn:SetSize(56, 22)
            btn:SetPoint("TOPLEFT", xOff, -82)
            btn:SetText(DoF.Config.StatShortNames[stat] or stat)
            btn.stat = stat
            btn:SetScript("OnClick", function()
                selectedStat = stat
                UpdateStatButtons()
            end)
            statButtons[#statButtons + 1] = btn
            xOff = xOff + 58
        end

        -- Поле ввода DC
        setupFrame.dcLabel = setupFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        setupFrame.dcLabel:SetPoint("TOPLEFT", 20, -120)
        setupFrame.dcLabel:SetText(DoF.L["ui.wound.dc_label"])

        setupFrame.dcInput = CreateFrame("EditBox", nil, setupFrame, "InputBoxTemplate")
        setupFrame.dcInput:SetSize(60, 22)
        setupFrame.dcInput:SetPoint("TOPLEFT", 110, -118)
        setupFrame.dcInput:SetAutoFocus(false)
        setupFrame.dcInput:SetNumeric(true)
        setupFrame.dcInput:SetMaxLetters(3)
        setupFrame.dcInput:SetText("14")

        setupFrame.hint = setupFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        setupFrame.hint:SetPoint("TOPLEFT", 20, -150)
        setupFrame.hint:SetPoint("TOPRIGHT", -20, -150)
        setupFrame.hint:SetJustifyH("LEFT")
        setupFrame.hint:SetWordWrap(true)
        setupFrame.hint:SetTextColor(0.7, 0.7, 0.7)
        setupFrame.hint:SetText(DoF.L["ui.wound.hint"])

        setupFrame.sendBtn = CreateFrame("Button", nil, setupFrame, "UIPanelButtonTemplate")
        setupFrame.sendBtn:SetSize(150, 26)
        setupFrame.sendBtn:SetPoint("BOTTOMLEFT", 30, 20)
        setupFrame.sendBtn:SetText(DoF.L["ui.wound.send_roll"])

        setupFrame.cancelBtn = CreateFrame("Button", nil, setupFrame, "UIPanelButtonTemplate")
        setupFrame.cancelBtn:SetSize(100, 26)
        setupFrame.cancelBtn:SetPoint("BOTTOMRIGHT", -30, 20)
        setupFrame.cancelBtn:SetText(DoF.L["ui.common.cancel"])
    end

    -- Сброс состояния для нового открытия
    selectedStat = DoF.Config.AllStats[5] -- Fortitude по умолчанию (логично для «выживания»)
    UpdateStatButtons()
    setupFrame.dcInput:SetText("14")
    setupFrame.playerLabel:SetText(DoF.Locale:Format("ui.wound.player_label", playerName))

    setupFrame.sendBtn:SetScript("OnClick", function()
        if not selectedStat then
            DoF.Utils:Warn(DoF.L["errors.select_stat"])
            return
        end
        local dc = tonumber(setupFrame.dcInput:GetText()) or 14
        if dc < 1 then dc = 1 end
        if dc > 40 then dc = 40 end

        setupFrame:Hide()

        -- Если мастер сам попал в крит — показываем диалог себе локально
        if playerName == UnitName("player") then
            DoF.Dialogs:ShowSurvivalRollPlayer(UnitName("player"), selectedStat, dc)
        else
            DoF.Sync:Send("SURVIVAL_ROLL_REQUEST", playerName .. ";" .. selectedStat .. ";" .. dc)
        end

        if DoF.Sync then
            DoF.Sync:BroadcastCombatLogKey("ui.wound.request_log",
                playerName,
                DoF.Sync.Arg.stat(selectedStat),
                dc)
        end
    end)
    setupFrame.cancelBtn:SetScript("OnClick", function() setupFrame:Hide() end)

    setupFrame:Show()
    setupFrame:Raise()
end

-- ═══════════════════════════════════════════════════════════
-- 3) ИГРОК: окно броска на выживание
-- ═══════════════════════════════════════════════════════════

local playerFrame = nil

function DoF.Dialogs:ShowSurvivalRollPlayer(targetName, stat, dc)
    if targetName ~= UnitName("player") then return end -- показываем только цели

    if not playerFrame then
        playerFrame = MakeBaseFrame("DoF_SurvivalRollPlayer", 400, 210, DoF.L["ui.wound.setup_title"])
        -- Forced action: игрок обязан бросить кубик, крестик скрыт
        if playerFrame.CloseButton then playerFrame.CloseButton:Hide() end

        playerFrame.info = playerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        playerFrame.info:SetPoint("TOP", 0, -32)
        playerFrame.info:SetPoint("LEFT", 20, 0)
        playerFrame.info:SetPoint("RIGHT", -20, 0)
        playerFrame.info:SetJustifyH("CENTER")
        playerFrame.info:SetWordWrap(true)

        playerFrame.hint = playerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        playerFrame.hint:SetPoint("TOP", 0, -100)
        playerFrame.hint:SetPoint("LEFT", 20, 0)
        playerFrame.hint:SetPoint("RIGHT", -20, 0)
        playerFrame.hint:SetJustifyH("CENTER")
        playerFrame.hint:SetWordWrap(true)
        playerFrame.hint:SetTextColor(0.7, 0.7, 0.7)
        playerFrame.hint:SetText(DoF.L["ui.wound.player_hint"])

        playerFrame.rollBtn = CreateFrame("Button", nil, playerFrame, "UIPanelButtonTemplate")
        playerFrame.rollBtn:SetSize(160, 30)
        playerFrame.rollBtn:SetPoint("BOTTOM", 0, 20)
        playerFrame.rollBtn:SetText(DoF.L["ui.wound.roll_btn"])
    end

    playerFrame.currentStat = stat
    playerFrame.currentDC = dc

    local color = DoF.Config.StatColors[stat] or "FFFFFF"
    local statName = DoF.Config.StatNames[stat] or stat
    local mod = DoF.Stats:GetTotal(stat)
    playerFrame.info:SetText(DoF.Locale:Format("ui.wound.player_desc",
        DoF.Utils:Color(color, statName),
        DoF.Utils:Color("FFFF00", (mod >= 0 and "+" or "") .. mod),
        DoF.Utils:Color("FF6666", tostring(dc))))

    playerFrame.rollBtn:SetScript("OnClick", function()
        local roll = DoF.Utils:Roll(1, 20)
        local modifier = DoF.Stats:GetTotal(stat)
        local total = roll + modifier
        local success = total >= dc
        playerFrame:Hide()

        local payload = string.format(
            "%s;%s;%d;%d;%d;%d;%d",
            UnitName("player"), stat, dc, roll, modifier, total, success and 1 or 0
        )

        if IsInGroup() and DoF.Sync then
            -- player;stat;dc;roll;mod;total;success(0|1)
            DoF.Sync:Send("SURVIVAL_ROLL_RESULT", payload)
        else
            -- Соло: Sync:Send не уходит — обрабатываем локально
            if DoF.Sync and DoF.Sync.Handlers and DoF.Sync.Handlers.SURVIVAL_ROLL_RESULT then
                DoF.Sync.Handlers.SURVIVAL_ROLL_RESULT(DoF.Sync, payload, UnitName("player"))
            end
        end
    end)

    playerFrame:Show()
    playerFrame:Raise()
    PlaySound(8959, "Master")
end
