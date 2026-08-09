-- DoF/UI/TurnQueue_Panels.lua
-- Панели уведомлений: алерты фаз, AoE панели, контратака, танк

local ADDON_NAME, DoF = ...

-- Кэширование глобальных функций
local CreateFrame = CreateFrame
local pairs = pairs
local ipairs = ipairs
local tonumber = tonumber
local string_format = string.format
local math_max = math.max
local math_min = math.min
local UnitGUID = UnitGUID
local UnitName = UnitName
local UnitExists = UnitExists
local UnitIsUnit = UnitIsUnit
local PlaySound = PlaySound
local C_Timer = C_Timer

DoF.UI = DoF.UI or {}

-- ═══════════════════════════════════════════════════════════
-- УВЕДОМЛЕНИЯ О ФАЗАХ
-- ═══════════════════════════════════════════════════════════

local PhaseAlertFrame = nil

-- Позиции для слайда (от TOP, отрицательные значения = вниз)
local ALERT_REST_Y = -80   -- финальная позиция (от верха экрана)
local ALERT_START_Y = -40  -- стартовая (выше, ближе к краю)
local ALERT_EXIT_Y = -20   -- выход (уезжает вверх за край)

-- Ease Out Quad: быстрый старт, плавное торможение
local function EaseOutQuad(t)
    return 1 - (1 - t) * (1 - t)
end

local function CreatePhaseAlertFrame()
    if PhaseAlertFrame then return PhaseAlertFrame end

    local f = CreateFrame("Frame", "DoF_PhaseAlertFrame", UIParent)
    f:SetSize(400, 120)
    f:SetPoint("TOP", UIParent, "TOP", 0, ALERT_REST_Y)
    f:SetFrameStrata("DIALOG")
    f:Hide()

    -- Фоновая текстура баннера (атлас)
    f.bgTexture = f:CreateTexture(nil, "BACKGROUND")
    f.bgTexture:SetAtlas("AllianceScenario-TitleBG", true)
    f.bgTexture:SetPoint("CENTER", 0, 0)

    -- Подгоняем размер фрейма под текстуру
    local texW, texH = f.bgTexture:GetSize()
    if texW and texW > 0 then
        f:SetSize(texW, texH + 30)
    end

    -- Заголовок — по центру текстуры, шрифт Morpheus кириллица
    f.titleText = f:CreateFontString(nil, "OVERLAY")
    f.titleText:SetFont(DoF.Config.FONT_TITLE, 24)
    f.titleText:SetShadowOffset(2, -2)
    f.titleText:SetShadowColor(0, 0, 0, 1)
    f.titleText:SetPoint("CENTER", f.bgTexture, "CENTER", 0, 0)
    f.titleText:SetText("")

    -- Подзаголовок — под текстурой
    f.subtitleText = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.subtitleText:SetPoint("TOP", f.bgTexture, "BOTTOM", 0, -4)
    f.subtitleText:SetText("")

    -- ═══ Alpha-анимации (без Translation — слайд через OnUpdate) ═══

    -- Появление альфы текста (с задержкой)
    f.textFadeIn = f.titleText:CreateAnimationGroup()
    local textAlphaIn = f.textFadeIn:CreateAnimation("Alpha")
    textAlphaIn:SetFromAlpha(0)
    textAlphaIn:SetToAlpha(1)
    textAlphaIn:SetDuration(0.3)
    textAlphaIn:SetStartDelay(0.15)
    f.textFadeIn:SetScript("OnFinished", function()
        f.titleText:SetAlpha(1)
    end)

    -- Подзаголовок появляется ещё чуть позже
    f.subtitleFadeIn = f.subtitleText:CreateAnimationGroup()
    local subAlphaIn = f.subtitleFadeIn:CreateAnimation("Alpha")
    subAlphaIn:SetFromAlpha(0)
    subAlphaIn:SetToAlpha(1)
    subAlphaIn:SetDuration(0.3)
    subAlphaIn:SetStartDelay(0.25)
    f.subtitleFadeIn:SetScript("OnFinished", function()
        f.subtitleText:SetAlpha(1)
    end)

    PhaseAlertFrame = f
    return f
end

-- Ручной слайд через OnUpdate — полный контроль без скачков
local function StartSlide(f, fromY, toY, duration, alphaFrom, alphaTo, onFinish)
    local elapsed = 0
    f:SetScript("OnUpdate", function(self, dt)
        elapsed = elapsed + dt
        local progress = math.min(elapsed / duration, 1)
        local eased = EaseOutQuad(progress)

        -- Позиция
        local y = fromY + (toY - fromY) * eased
        self:ClearAllPoints()
        self:SetPoint("TOP", UIParent, "TOP", 0, y)

        -- Альфа
        if alphaFrom and alphaTo then
            self:SetAlpha(alphaFrom + (alphaTo - alphaFrom) * eased)
        end

        if progress >= 1 then
            self:SetScript("OnUpdate", nil)
            if onFinish then onFinish() end
        end
    end)
end

-- Вспомогательная функция запуска анимации
local function PlayPhaseAlert(f, title, subtitle)
    -- Останавливаем предыдущее
    f:SetScript("OnUpdate", nil)
    f.textFadeIn:Stop()
    f.subtitleFadeIn:Stop()
    if f.fadeOutTimer then
        f.fadeOutTimer:Cancel()
        f.fadeOutTimer = nil
    end

    f.titleText:SetText(title or "")
    f.subtitleText:SetText(subtitle or "")

    f:Show()
    f:SetAlpha(0)
    f.titleText:SetAlpha(0)
    f.subtitleText:SetAlpha(0)

    -- Слайд снизу → центр + появление (0.5с)
    StartSlide(f, ALERT_START_Y, ALERT_REST_Y, 0.5, 0, 1, function()
        f:SetAlpha(1)
        f.titleText:SetAlpha(1)
        f.subtitleText:SetAlpha(1)
    end)

    -- Текст появляется чуть позже
    f.textFadeIn:Play()
    if subtitle and subtitle ~= "" then
        f.subtitleFadeIn:Play()
    end

    -- Через 3с — слайд вверх + исчезновение (0.8с)
    f.fadeOutTimer = C_Timer.NewTimer(3, function()
        StartSlide(f, ALERT_REST_Y, ALERT_EXIT_Y, 0.8, 1, 0, function()
            f:Hide()
            f:ClearAllPoints()
            f:SetPoint("TOP", UIParent, "TOP", 0, ALERT_REST_Y)
        end)
    end)
end

function DoF.UI:ShowYourTurnAlert()
    local f = CreatePhaseAlertFrame()
    PlayPhaseAlert(f,
        DoF.L["ui.panel.players_turn"],
        DoF.L["ui.panel.your_turn"]
    )
    PlaySound(8960, "SFX") -- READY_CHECK
end

function DoF.UI:ShowPlayersPhaseAlert()
    local f = CreatePhaseAlertFrame()
    PlayPhaseAlert(f, DoF.L["ui.panel.players_turn"])
end

function DoF.UI:ShowNPCPhaseAlert()
    local f = CreatePhaseAlertFrame()
    PlayPhaseAlert(f, DoF.L["ui.panel.enemy_turn_alert"])
    PlaySound(37666, "SFX") -- UI_RAID_BOSS_WHISPER_WARNING
end

function DoF.UI:ShowCombatEndAlert()
    local f = CreatePhaseAlertFrame()
    PlayPhaseAlert(f, DoF.L["ui.panel.combat_over"])
    PlaySound(8959, "SFX") -- PVP_THROUGH_QUEUE
end

function DoF.UI:ShowFreeActionAlert()
    local f = CreatePhaseAlertFrame()
    PlayPhaseAlert(f,
        DoF.L["ui.panel.extra_turn_title"],
        DoF.L["ui.panel.extra_turn_sub"]
    )
end

function DoF.UI:ShowCriticalWoundAlert(playerName)
    local f = CreatePhaseAlertFrame()
    PlayPhaseAlert(f,
        DoF.L["ui.panel.critical_wound_title"],
        DoF.Locale:Format("ui.panel.critical_wound_sub", playerName or "?")
    )
end

-- ═══════════════════════════════════════════════════════════
-- AoE ПАНЕЛЬ
-- ═══════════════════════════════════════════════════════════

local aoePanel = nil

function DoF.UI:ShowAoEPanel()
    local stat = DoF.Combat:GetAoEStat()
    local hitsLeft = DoF.Combat:GetAoEHitsLeft()
    local statColor = DoF.Config.StatColors[stat] or "FFFFFF"
    local statName = DoF.Config.StatNames[stat] or stat

    if not aoePanel then
        aoePanel = CreateFrame("Frame", "DoF_AoEPanel", UIParent, "TooltipBackdropTemplate")
        aoePanel:SetSize(220, 110)
        aoePanel:SetPoint("TOP", 0, -150)
        aoePanel:SetFrameStrata("FULLSCREEN_DIALOG")

        aoePanel.titleText = aoePanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        aoePanel.titleText:SetPoint("TOP", 0, -10)
        aoePanel.titleText:SetText(DoF.L["ui.panel.aoe_attack_title"])
        aoePanel.titleText:SetTextColor(1, 0.6, 0.1)

        aoePanel.statText = aoePanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        aoePanel.statText:SetPoint("TOP", 0, -32)

        aoePanel.counterText = aoePanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        aoePanel.counterText:SetPoint("CENTER", 0, 4)

        local hitBtn = CreateFrame("Button", nil, aoePanel, "UIPanelButtonTemplate")
        hitBtn:SetSize(95, 24)
        hitBtn:SetPoint("BOTTOMLEFT", 10, 12)
        hitBtn:SetText(DoF.L["ui.panel.hit"])
        hitBtn:SetScript("OnClick", function() DoF.Combat:AoEHit() end)

        local cancelBtn = CreateFrame("Button", nil, aoePanel, "UIPanelButtonTemplate")
        cancelBtn:SetSize(95, 24)
        cancelBtn:SetPoint("BOTTOMRIGHT", -10, 12)
        cancelBtn:SetText(DoF.L["ui.common.cancel"])
        cancelBtn:SetScript("OnClick", function() DoF.Combat:CancelAoE() end)
    end

    -- Обновляем динамический контент
    aoePanel.statText:SetText(DoF.Utils:Color(statColor, statName))
    aoePanel.counterText:SetText(DoF.Locale:Format("ui.panel.hits_left", hitsLeft))
    aoePanel:Show()
end

function DoF.UI:HideAoEPanel()
    if aoePanel then
        aoePanel:Hide()
    end
end

function DoF.UI:UpdateAoEPanel()
    if not aoePanel or not aoePanel:IsShown() then return end

    local hitsLeft = DoF.Combat:GetAoEHitsLeft()
    if aoePanel.counterText then
        aoePanel.counterText:SetText(DoF.Locale:Format("ui.panel.hits_left", hitsLeft))
    end
end

-- ═══════════════════════════════════════════════════════════
-- AoE ИСЦЕЛЕНИЕ ПАНЕЛЬ
-- ═══════════════════════════════════════════════════════════

local aoeHealPanel = nil

function DoF.UI:ShowAoEHealPanel()
    local healsLeft = DoF.Combat:GetAoEHealsLeft()

    if not aoeHealPanel then
        aoeHealPanel = CreateFrame("Frame", "DoF_AoEHealPanel", UIParent, "TooltipBackdropTemplate")
        aoeHealPanel:SetSize(220, 110)
        aoeHealPanel:SetPoint("TOP", 0, -150)
        aoeHealPanel:SetFrameStrata("FULLSCREEN_DIALOG")

        aoeHealPanel.titleText = aoeHealPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        aoeHealPanel.titleText:SetPoint("TOP", 0, -10)
        aoeHealPanel.titleText:SetText(DoF.L["ui.panel.aoe_heal_title"])
        aoeHealPanel.titleText:SetTextColor(0.4, 1, 0.4)

        aoeHealPanel.statText = aoeHealPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        aoeHealPanel.statText:SetPoint("TOP", 0, -32)
        aoeHealPanel.statText:SetText(DoF.Utils:Color(DoF.Config.StatColors["Spirit"] or "FFE066", DoF.Config.StatNames["Spirit"] or DoF.L["stats.spirit.label"]))

        aoeHealPanel.counterText = aoeHealPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        aoeHealPanel.counterText:SetPoint("CENTER", 0, 4)

        local healBtn = CreateFrame("Button", nil, aoeHealPanel, "UIPanelButtonTemplate")
        healBtn:SetSize(95, 24)
        healBtn:SetPoint("BOTTOMLEFT", 10, 12)
        healBtn:SetText(DoF.L["ui.panel.heal"])
        healBtn:SetScript("OnClick", function() DoF.Combat:AoEHealTarget() end)

        local cancelBtn = CreateFrame("Button", nil, aoeHealPanel, "UIPanelButtonTemplate")
        cancelBtn:SetSize(95, 24)
        cancelBtn:SetPoint("BOTTOMRIGHT", -10, 12)
        cancelBtn:SetText(DoF.L["ui.common.cancel"])
        cancelBtn:SetScript("OnClick", function() DoF.Combat:CancelAoEHeal() end)
    end

    -- Обновляем динамический контент
    aoeHealPanel.counterText:SetText(DoF.Locale:Format("ui.panel.left", healsLeft))
    aoeHealPanel:Show()
end

function DoF.UI:HideAoEHealPanel()
    if aoeHealPanel then
        aoeHealPanel:Hide()
    end
end

function DoF.UI:UpdateAoEHealPanel()
    if not aoeHealPanel or not aoeHealPanel:IsShown() then return end

    local healsLeft = DoF.Combat:GetAoEHealsLeft()
    if aoeHealPanel.counterText then
        aoeHealPanel.counterText:SetText(DoF.Locale:Format("ui.panel.left", healsLeft))
    end
end

-- ═══════════════════════════════════════════════════════════
-- AoE БАФФ ПАНЕЛЬ
-- ═══════════════════════════════════════════════════════════

local aoeBuffPanel = nil

function DoF.UI:ShowAoEBuffPanel()
    local buffsLeft = DoF.Combat:GetAoEBuffsLeft()
    local effectId = DoF.Combat:GetAoEBuffEffectId()
    local def = DoF.Effects.Definitions[effectId]
    local buffName = def and def.name or DoF.L["ui.common.buff"]
    local buffColorHex = def and DoF.Effects:GetColorHex(def.color) or "66FF66"
    local r, g, b = 0.2, 0.7, 0.3
    if def and def.color then
        r, g, b = def.color[1] * 0.5, def.color[2] * 0.5, def.color[3] * 0.5
    end

    if not aoeBuffPanel then
        aoeBuffPanel = CreateFrame("Frame", "DoF_AoEBuffPanel", UIParent, "TooltipBackdropTemplate")
        aoeBuffPanel:SetSize(220, 110)
        aoeBuffPanel:SetPoint("TOP", 0, -150)
        aoeBuffPanel:SetFrameStrata("FULLSCREEN_DIALOG")

        aoeBuffPanel.titleText = aoeBuffPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        aoeBuffPanel.titleText:SetPoint("TOP", 0, -10)

        aoeBuffPanel.statText = aoeBuffPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        aoeBuffPanel.statText:SetPoint("TOP", 0, -32)
        aoeBuffPanel.statText:SetText(DoF.Utils:Color(DoF.Config.StatColors["Spirit"] or "FFE066", DoF.Config.StatNames["Spirit"] or DoF.L["stats.spirit.label"]))

        aoeBuffPanel.counterText = aoeBuffPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        aoeBuffPanel.counterText:SetPoint("CENTER", 0, 4)

        aoeBuffPanel.buffBtn = CreateFrame("Button", nil, aoeBuffPanel, "UIPanelButtonTemplate")
        aoeBuffPanel.buffBtn:SetSize(95, 24)
        aoeBuffPanel.buffBtn:SetPoint("BOTTOMLEFT", 10, 12)
        aoeBuffPanel.buffBtn:SetText(DoF.L["ui.panel.buff"])
        aoeBuffPanel.buffBtn:SetScript("OnClick", function() DoF.Combat:AoEBuffTarget() end)

        local cancelBtn = CreateFrame("Button", nil, aoeBuffPanel, "UIPanelButtonTemplate")
        cancelBtn:SetSize(95, 24)
        cancelBtn:SetPoint("BOTTOMRIGHT", -10, 12)
        cancelBtn:SetText(DoF.L["ui.common.cancel"])
        cancelBtn:SetScript("OnClick", function() DoF.Combat:CancelAoEBuff() end)
    end

    -- Обновляем заголовок (цвет — по типу баффа через FontString)
    aoeBuffPanel.titleText:SetText("AoE " .. buffName)
    aoeBuffPanel.titleText:SetTextColor(r, g, b)
    aoeBuffPanel.counterText:SetText(DoF.Locale:Format("ui.panel.left", buffsLeft))
    aoeBuffPanel:Show()
end

function DoF.UI:HideAoEBuffPanel()
    if aoeBuffPanel then
        aoeBuffPanel:Hide()
    end
end

function DoF.UI:UpdateAoEBuffPanel()
    if not aoeBuffPanel or not aoeBuffPanel:IsShown() then return end

    local buffsLeft = DoF.Combat:GetAoEBuffsLeft()
    if aoeBuffPanel.counterText then
        aoeBuffPanel.counterText:SetText(DoF.Locale:Format("ui.panel.left", buffsLeft))
    end
end

-- ═══════════════════════════════════════════════════════════
-- AoE ЩИТ ПАНЕЛЬ
-- ═══════════════════════════════════════════════════════════

local aoeShieldPanel = nil

function DoF.UI:ShowAoEShieldPanel()
    local shieldsLeft = DoF.Combat:GetAoEShieldsLeft()

    if not aoeShieldPanel then
        aoeShieldPanel = CreateFrame("Frame", "DoF_AoEShieldPanel", UIParent, "TooltipBackdropTemplate")
        aoeShieldPanel:SetSize(220, 100)
        aoeShieldPanel:SetPoint("TOP", 0, -150)
        aoeShieldPanel:SetFrameStrata("FULLSCREEN_DIALOG")

        aoeShieldPanel.titleText = aoeShieldPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        aoeShieldPanel.titleText:SetPoint("TOP", 0, -10)
        aoeShieldPanel.titleText:SetText(DoF.L["ui.panel.aoe_shield_title"])
        aoeShieldPanel.titleText:SetTextColor(0.4, 0.8, 1)

        aoeShieldPanel.counterText = aoeShieldPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        aoeShieldPanel.counterText:SetPoint("CENTER", 0, 4)

        local hitBtn = CreateFrame("Button", nil, aoeShieldPanel, "UIPanelButtonTemplate")
        hitBtn:SetSize(95, 24)
        hitBtn:SetPoint("BOTTOMLEFT", 10, 12)
        hitBtn:SetText(DoF.L["ui.panel.apply"])
        hitBtn:SetScript("OnClick", function() DoF.Combat:AoEShieldHit() end)

        local cancelBtn = CreateFrame("Button", nil, aoeShieldPanel, "UIPanelButtonTemplate")
        cancelBtn:SetSize(95, 24)
        cancelBtn:SetPoint("BOTTOMRIGHT", -10, 12)
        cancelBtn:SetText(DoF.L["ui.common.cancel"])
        cancelBtn:SetScript("OnClick", function() DoF.Combat:CancelAoEShield() end)
    end

    -- Обновляем счётчик
    aoeShieldPanel.counterText:SetText(DoF.Locale:Format("ui.panel.shields_left", shieldsLeft))
    aoeShieldPanel:Show()
end

function DoF.UI:HideAoEShieldPanel()
    if aoeShieldPanel then
        aoeShieldPanel:Hide()
    end
end

function DoF.UI:UpdateAoEShieldPanel()
    if not aoeShieldPanel or not aoeShieldPanel:IsShown() then return end

    local shieldsLeft = DoF.Combat:GetAoEShieldsLeft()
    if aoeShieldPanel.counterText then
        aoeShieldPanel.counterText:SetText(DoF.Locale:Format("ui.panel.shields_left", shieldsLeft))
    end
end

-- ═══════════════════════════════════════════════════════════
-- КОНТРАТАКА ПАНЕЛЬ
-- ═══════════════════════════════════════════════════════════

local counterattackPanel = nil

function DoF.UI:ShowCounterattackPanel(damage)
    if not counterattackPanel then
        counterattackPanel = CreateFrame("Frame", "DoF_CounterattackPanel", UIParent, "TooltipBackdropTemplate")
        counterattackPanel:SetSize(220, 100)
        counterattackPanel:SetPoint("TOP", 0, -150)
        counterattackPanel:SetFrameStrata("FULLSCREEN_DIALOG")

        counterattackPanel.titleText = counterattackPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        counterattackPanel.titleText:SetPoint("TOP", 0, -10)
        counterattackPanel.titleText:SetText(DoF.L["ui.panel.counterattack_title"])
        counterattackPanel.titleText:SetTextColor(1, 0.4, 0.4)

        counterattackPanel.dmgText = counterattackPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        counterattackPanel.dmgText:SetPoint("TOP", 0, -34)

        local hitBtn = CreateFrame("Button", nil, counterattackPanel, "UIPanelButtonTemplate")
        hitBtn:SetSize(95, 24)
        hitBtn:SetPoint("BOTTOMLEFT", 10, 12)
        hitBtn:SetText(DoF.L["ui.panel.hit"])
        hitBtn:SetScript("OnClick", function() DoF.Combat:CounterattackSelectTarget() end)

        local cancelBtn = CreateFrame("Button", nil, counterattackPanel, "UIPanelButtonTemplate")
        cancelBtn:SetSize(95, 24)
        cancelBtn:SetPoint("BOTTOMRIGHT", -10, 12)
        cancelBtn:SetText(DoF.L["ui.common.cancel"])
        cancelBtn:SetScript("OnClick", function() DoF.Combat:CounterattackCancel() end)
    end

    -- Обновляем динамический контент
    counterattackPanel.dmgText:SetText(DoF.Locale:Format("ui.panel.counter_damage", damage))
    counterattackPanel:Show()
end

function DoF.UI:HideCounterattackPanel()
    if counterattackPanel then
        counterattackPanel:Hide()
    end
end

-- ═══════════════════════════════════════════════════════════
-- ПАНЕЛЬ БАФФА +2 HP СОЮЗНИКУ (ТАНК)
-- ═══════════════════════════════════════════════════════════
local tankHPBuffPanel = nil

function DoF.UI:ShowTankHPBuffPanel()
    if not tankHPBuffPanel then
        tankHPBuffPanel = CreateFrame("Frame", "DoF_TankHPBuffPanel", UIParent, "TooltipBackdropTemplate")
        tankHPBuffPanel:SetSize(240, 100)
        tankHPBuffPanel:SetPoint("TOP", 0, -150)
        tankHPBuffPanel:SetFrameStrata("FULLSCREEN_DIALOG")

        tankHPBuffPanel.titleText = tankHPBuffPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        tankHPBuffPanel.titleText:SetPoint("TOP", 0, -10)
        tankHPBuffPanel.titleText:SetText(DoF.L["ui.panel.tank_hp_buff_title"])
        tankHPBuffPanel.titleText:SetTextColor(0.4, 1, 0.4)

        tankHPBuffPanel.descText = tankHPBuffPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        tankHPBuffPanel.descText:SetPoint("TOP", 0, -34)
        tankHPBuffPanel.descText:SetText(DoF.L["ui.panel.choose_ally"])

        local buffBtn = CreateFrame("Button", nil, tankHPBuffPanel, "UIPanelButtonTemplate")
        buffBtn:SetSize(105, 24)
        buffBtn:SetPoint("BOTTOMLEFT", 10, 12)
        buffBtn:SetText(DoF.L["ui.common.buff"])
        buffBtn:SetScript("OnClick", function() DoF.Combat:TankHPBuffApply() end)

        local cancelBtn = CreateFrame("Button", nil, tankHPBuffPanel, "UIPanelButtonTemplate")
        cancelBtn:SetSize(105, 24)
        cancelBtn:SetPoint("BOTTOMRIGHT", -10, 12)
        cancelBtn:SetText(DoF.L["ui.common.cancel"])
        cancelBtn:SetScript("OnClick", function() DoF.Combat:TankHPBuffCancel() end)
    end

    tankHPBuffPanel:Show()
end

function DoF.UI:HideTankHPBuffPanel()
    if tankHPBuffPanel then
        tankHPBuffPanel:Hide()
    end
end

-- ═══════════════════════════════════════════════════════════
-- ХЕДЕР НАД СПИСКОМ ЗАДАНИЙ (ObjectiveTrackerFrame)
-- ═══════════════════════════════════════════════════════════

local TrackerHeader = nil

local function CreateTrackerHeader()
    if TrackerHeader then return TrackerHeader end

    local f = CreateFrame("Frame", "DoF_TrackerHeader", UIParent)
    f:SetFrameStrata("BACKGROUND")

    -- Текстура атласа (растягиваем под увеличенный размер)
    f.bg = f:CreateTexture(nil, "ARTWORK")
    f.bg:SetAtlas("AllianceScenario-TrackerHeader")
    f.bg:SetAllPoints()

    -- Увеличенный размер: ширина = окно очереди (300), высота для 3 строк
    local frameW = 300
    local frameH = 80  -- Увеличенная высота: режим + раунд + таймер-бар
    f:SetSize(frameW, frameH)

    -- Привязка: как квест-трекер, но сдвинуто влево
    local point, relativeTo, relativePoint, xOfs, yOfs = ObjectiveTrackerFrame:GetPoint(1)
    if point then
        f:SetPoint(point, relativeTo, relativePoint, (xOfs or 0) - 50, yOfs)
    else
        f:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -150, -200)
    end

    -- Строка 1 (верх): Режим — "Очередь" / "Свободный"
    f.modeText = f:CreateFontString(nil, "OVERLAY")
    f.modeText:SetFont(DoF.Config.FONT, 10, "")
    f.modeText:SetShadowOffset(1, -1)
    f.modeText:SetShadowColor(0, 0, 0, 1)
    f.modeText:SetPoint("TOP", 0, -6)
    f.modeText:SetTextColor(0.6, 0.6, 0.6)

    -- Строка 2 (центр): Раунд + Фаза
    f.text = f:CreateFontString(nil, "OVERLAY")
    f.text:SetFont(DoF.Config.FONT_TITLE, 16)
    f.text:SetShadowOffset(1, -1)
    f.text:SetShadowColor(0, 0, 0, 1)
    f.text:SetPoint("CENTER", 0, 0)

    -- Строка 3 (низ): Таймер — StatusBar ПОД рамкой widgetstatusbar
    local timerFrame = CreateFrame("Frame", nil, f)
    timerFrame:SetSize(frameW - 20, 20)
    timerFrame:SetPoint("BOTTOM", 0, 4)
    f.timerFrame = timerFrame

    -- StatusBar заполнения (слой BACKGROUND — ПОД рамкой, обрезается ею)
    local timerBar = CreateFrame("StatusBar", nil, timerFrame)
    timerBar:SetPoint("TOPLEFT", 6, -3)
    timerBar:SetPoint("BOTTOMRIGHT", -6, 3)
    timerBar:SetMinMaxValues(0, 60)
    timerBar:SetValue(60)
    timerBar:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
    timerBar:SetStatusBarColor(0.3, 0.7, 0.3, 0.8)
    timerBar:SetFrameLevel(timerFrame:GetFrameLevel())
    f.timerBar = timerBar

    -- Рамка из 3 частей атласа (OVERLAY — поверх StatusBar)
    local borderLeft = timerFrame:CreateTexture(nil, "OVERLAY")
    borderLeft:SetAtlas("widgetstatusbar-borderleft", true)
    borderLeft:SetPoint("LEFT", 0, 0)
    borderLeft:SetHeight(timerFrame:GetHeight())

    local borderRight = timerFrame:CreateTexture(nil, "OVERLAY")
    borderRight:SetAtlas("widgetstatusbar-borderright", true)
    borderRight:SetPoint("RIGHT", 0, 0)
    borderRight:SetHeight(timerFrame:GetHeight())

    local borderCenter = timerFrame:CreateTexture(nil, "OVERLAY")
    borderCenter:SetAtlas("widgetstatusbar-bordercenter")
    borderCenter:SetPoint("LEFT", borderLeft, "RIGHT", 0, 0)
    borderCenter:SetPoint("RIGHT", borderRight, "LEFT", 0, 0)
    borderCenter:SetHeight(timerFrame:GetHeight())
    borderCenter:SetHorizTile(true)

    -- Разделители (тики) поверх рамки — 4 штуки равномерно
    local NUM_TICKS = 4
    for t = 1, NUM_TICKS do
        local tick = timerFrame:CreateTexture(nil, "OVERLAY", nil, 2)
        tick:SetAtlas("UI-Frame-Bar-BorderTick", true)
        local tickX = (t / (NUM_TICKS + 1))  -- 0.2, 0.4, 0.6, 0.8
        tick:SetPoint("CENTER", timerFrame, "LEFT", timerFrame:GetWidth() * tickX, 0)
    end

    -- Glow мигание (3 части — скрыты по умолчанию, включаются при <=10 сек)
    local glowLeft = timerFrame:CreateTexture(nil, "ARTWORK", nil, 1)
    glowLeft:SetAtlas("UI-Frame-Bar-GlowLeft", true)
    glowLeft:SetPoint("LEFT", 0, 0)
    glowLeft:SetHeight(timerFrame:GetHeight() + 8)
    glowLeft:SetAlpha(0)

    local glowRight = timerFrame:CreateTexture(nil, "ARTWORK", nil, 1)
    glowRight:SetAtlas("UI-Frame-Bar-GlowRight", true)
    glowRight:SetPoint("RIGHT", 0, 0)
    glowRight:SetHeight(timerFrame:GetHeight() + 8)
    glowRight:SetAlpha(0)

    local glowCenter = timerFrame:CreateTexture(nil, "ARTWORK", nil, 1)
    glowCenter:SetAtlas("UI-Frame-Bar-GlowCenter")
    glowCenter:SetPoint("LEFT", glowLeft, "RIGHT", 0, 0)
    glowCenter:SetPoint("RIGHT", glowRight, "LEFT", 0, 0)
    glowCenter:SetHeight(timerFrame:GetHeight() + 8)
    glowCenter:SetHorizTile(true)
    glowCenter:SetAlpha(0)

    f.timerGlow = { glowLeft, glowCenter, glowRight }
    f.timerGlowActive = false

    -- OnUpdate для покадровой пульсации glow
    local glowPhase = 0
    timerFrame:SetScript("OnUpdate", function(self, elapsed)
        if not f.timerGlowActive then return end
        glowPhase = glowPhase + elapsed * 4  -- Скорость пульсации
        local alpha = 0.3 + 0.5 * (0.5 + 0.5 * math.sin(glowPhase))
        for _, glow in ipairs(f.timerGlow) do
            glow:SetAlpha(alpha)
        end
    end)

    -- Текст таймера поверх всего
    f.timerText = timerFrame:CreateFontString(nil, "OVERLAY", nil, 7)
    f.timerText:SetFont(DoF.Config.FONT, 10, "OUTLINE")
    f.timerText:SetPoint("CENTER")
    f.timerText:SetTextColor(1, 1, 1)
    f.timerText:SetShadowOffset(1, -1)
    f.timerText:SetShadowColor(0, 0, 0, 1)

    timerFrame:Hide()

    -- Индикатор свёрнутой очереди (кнопка с числом не сходивших)
    local collapseIndicator = CreateFrame("Button", nil, f, "TooltipBackdropTemplate")
    collapseIndicator:SetHeight(22)
    collapseIndicator:SetPoint("TOPLEFT", f, "BOTTOMLEFT", 0, -2)
    collapseIndicator:SetPoint("TOPRIGHT", f, "BOTTOMRIGHT", 0, -2)

    collapseIndicator.text = collapseIndicator:CreateFontString(nil, "OVERLAY")
    collapseIndicator.text:SetFont(DoF.Config.FONT, 10, "OUTLINE")
    collapseIndicator.text:SetPoint("CENTER")
    collapseIndicator.text:SetTextColor(0.8, 0.8, 0.8)

    collapseIndicator.hl = collapseIndicator:CreateTexture(nil, "HIGHLIGHT")
    collapseIndicator.hl:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
    collapseIndicator.hl:SetBlendMode("ADD")
    collapseIndicator.hl:SetAllPoints(collapseIndicator)
    collapseIndicator:SetScript("OnClick", function()
        -- Развернуть очередь
        if DoF.UI and DoF.UI.ShowTurnQueue then
            local qf = _G["DoF_TurnQueueFrame"]
            if qf then
                qf.isCollapsed = false
                qf:Show()
                DoF.UI:UpdateTurnQueue()
            end
        end
        collapseIndicator:Hide()
    end)
    collapseIndicator:Hide()
    f.collapseIndicator = collapseIndicator

    f:SetClampedToScreen(true)

    -- Применить сохранённый масштаб
    local savedScale = DoF.db and DoF.db.profile and DoF.db.profile.turnQueueScale or 1.0
    f:SetScale(savedScale)

    f:Hide()
    TrackerHeader = f
    return f
end

function DoF.UI:ShowTrackerHeader()
    local f = CreateTrackerHeader()

    -- Скрываем стандартный список заданий
    ObjectiveTrackerFrame:Hide()

    f:Show()
end

function DoF.UI:HideTrackerHeader()
    if TrackerHeader then
        TrackerHeader:Hide()
    end

    -- Возвращаем стандартный список заданий
    ObjectiveTrackerFrame:Show()
end

-- Индикатор свёрнутой очереди на трекере
function DoF.UI:ShowTrackerCollapseIndicator(notActed, phase)
    if not TrackerHeader or not TrackerHeader.collapseIndicator then return end
    local phaseText = (phase == "npc") and DoF.L["ui.queue.phase_enemy"] or DoF.L["ui.queue.phase_players"]
    local countText = (notActed and notActed > 0) and DoF.Locale:Format("ui.queue.waiting_count", notActed) or ""
    TrackerHeader.collapseIndicator.text:SetText(DoF.Locale:Format("ui.queue.header", phaseText, countText))
    TrackerHeader.collapseIndicator:Show()
end

function DoF.UI:HideTrackerCollapseIndicator()
    if TrackerHeader and TrackerHeader.collapseIndicator then
        TrackerHeader.collapseIndicator:Hide()
    end
end

function DoF.UI:UpdateTrackerHeader(round, isNPCPhase, mode)
    if not TrackerHeader or not TrackerHeader:IsShown() then return end

    -- Строка 1: Режим
    if mode then
        if mode == "queue" then
            TrackerHeader.modeText:SetText(DoF.L["ui.queue.mode_queue"])
        else
            TrackerHeader.modeText:SetText(DoF.L["ui.queue.mode_free"])
        end
        TrackerHeader.modeText:Show()
    else
        TrackerHeader.modeText:Hide()
    end

    -- Строка 2: Раунд + Фаза
    if isNPCPhase then
        TrackerHeader.text:SetText(DoF.Locale:Format("ui.queue.round_enemy", round))
    else
        TrackerHeader.text:SetText(DoF.Locale:Format("ui.queue.round_players", round))
    end
end

-- Обновление таймера на трекере (вызывается из TurnQueue.lua)
function DoF.UI:UpdateTrackerTimer(remaining, mode)
    if not TrackerHeader or not TrackerHeader:IsShown() then return end

    if remaining and remaining > 0 then
        -- Дедупликация: не перерисовываем если секунда не изменилась
        local ceiled = math.ceil(remaining)
        if ceiled == TrackerHeader.lastTimerSecs then
            -- Обновляем только StatusBar (он плавный)
            local ts = DoF.TurnSystem
            local duration = (ts and ts.turnDuration) or 60
            if duration > 0 then
                TrackerHeader.timerBar:SetMinMaxValues(0, duration)
                TrackerHeader.timerBar:SetValue(remaining)
            end
            TrackerHeader.timerFrame:Show()
            return
        end
        TrackerHeader.lastTimerSecs = ceiled

        -- Текст (на основе ceiled — целые секунды без флуктуаций)
        local mins = math.floor(ceiled / 60)
        local secs = ceiled % 60
        local timerColor = ceiled <= 10 and "FF6666" or (ceiled <= 30 and "FFFF00" or "FFFFFF")
        local label = (mode == "queue") and DoF.L["ui.queue.label_turn"] or DoF.L["ui.queue.label_round"]
        TrackerHeader.timerText:SetText(DoF.Locale:Format("ui.queue.timer", label, timerColor, mins, secs))

        -- StatusBar заполнение + цвет по времени
        local ts = DoF.TurnSystem
        local duration = (ts and ts.turnDuration) or 60
        if duration > 0 then
            TrackerHeader.timerBar:SetMinMaxValues(0, duration)
            TrackerHeader.timerBar:SetValue(remaining)

            if remaining <= 10 then
                TrackerHeader.timerBar:SetStatusBarColor(0.7, 0.2, 0.2, 0.8)
            elseif remaining <= 30 then
                TrackerHeader.timerBar:SetStatusBarColor(0.7, 0.7, 0.2, 0.8)
            else
                TrackerHeader.timerBar:SetStatusBarColor(0.3, 0.7, 0.3, 0.8)
            end
        end

        -- Glow мигание при <=10 сек (пульсация через OnUpdate)
        if TrackerHeader.timerGlow then
            if remaining <= 10 then
                if not TrackerHeader.timerGlowActive then
                    TrackerHeader.timerGlowActive = true
                    for _, glow in ipairs(TrackerHeader.timerGlow) do
                        glow:SetVertexColor(0.8, 0.2, 0.2)
                    end
                end
            else
                TrackerHeader.timerGlowActive = false
                for _, glow in ipairs(TrackerHeader.timerGlow) do
                    glow:SetAlpha(0)
                end
            end
        end

        TrackerHeader.timerFrame:Show()
    else
        if TrackerHeader.timerFrame then
            TrackerHeader.timerFrame:Hide()
            TrackerHeader.timerGlowActive = false
            TrackerHeader.lastTimerSecs = nil
            if TrackerHeader.timerGlow then
                for _, glow in ipairs(TrackerHeader.timerGlow) do
                    glow:SetAlpha(0)
                end
            end
        end
    end
end

-- Обновляем очередь при изменении данных игроков (HP/Energy/Эффекты)
if DoF.Events then
    local pendingQueueRefresh = false
    local function RefreshQueue()
        if pendingQueueRefresh then return end
        pendingQueueRefresh = true
        C_Timer.After(0, function()
            pendingQueueRefresh = false
            DoF.UI:UpdateTurnQueue()
        end)
    end

    -- Синхронизация от других игроков
    DoF.Events:Register("PLAYER_DATA_RECEIVED", RefreshQueue, DoF.UI)
    -- Эффекты (дебаффы/баффы)
    DoF.Events:Register("EFFECT_APPLIED", RefreshQueue, DoF.UI)
    DoF.Events:Register("EFFECT_REMOVED", RefreshQueue, DoF.UI)
    DoF.Events:Register("EFFECTS_SYNCED", RefreshQueue, DoF.UI)
    -- Локальные изменения HP и энергии (свои, без задержки синхронизации)
    DoF.Events:Register("PLAYER_HP_CHANGED", RefreshQueue, DoF.UI)
    DoF.Events:Register("PLAYER_ENERGY_CHANGED", RefreshQueue, DoF.UI)
    -- НПЦ HP и щиты
    DoF.Events:Register("UNIT_HP_CHANGED", RefreshQueue, DoF.UI)
    DoF.Events:Register("UNIT_SHIELD_CHANGED", RefreshQueue, DoF.UI)
    -- Щит и раны игрока
    DoF.Events:Register("PLAYER_SHIELD_CHANGED", RefreshQueue, DoF.UI)
    DoF.Events:Register("PLAYER_WOUND_CHANGED", RefreshQueue, DoF.UI)

    -- Показываем хедер при начале боя
    DoF.Events:Register("COMBAT_STARTED", function()
        DoF.UI:ShowTrackerHeader()
    end, DoF.UI)

    -- Скрываем очередь и хедер при окончании боя
    DoF.Events:Register("COMBAT_ENDED", function()
        DoF.UI:HideTurnQueue()
        DoF.UI:HideCounterattackPanel()
        DoF.UI:HideTankHPBuffPanel()
        DoF.UI:HideAoETauntPanel()
        DoF.UI:HideSpecialActionPanel()
        DoF.UI:HideTrackerHeader()
    end, DoF.UI)
end

-- ═══════════════════════════════════════════════════════════
-- ПАНЕЛЬ АОЕ ПРОВОКАЦИИ (ТАНК)
-- ═══════════════════════════════════════════════════════════

local aoeTauntPanel = nil

function DoF.UI:ShowAoETauntPanel()
    local tauntsLeft = DoF.Combat.AoETauntState.tauntsLeft

    if not aoeTauntPanel then
        aoeTauntPanel = CreateFrame("Frame", "DoF_AoETauntPanel", UIParent, "TooltipBackdropTemplate")
        aoeTauntPanel:SetSize(240, 110)
        aoeTauntPanel:SetPoint("TOP", 0, -150)
        aoeTauntPanel:SetFrameStrata("FULLSCREEN_DIALOG")

        aoeTauntPanel.titleText = aoeTauntPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        aoeTauntPanel.titleText:SetPoint("TOP", 0, -10)
        aoeTauntPanel.titleText:SetText(DoF.L["ui.panel.mass_taunt_title"])
        aoeTauntPanel.titleText:SetTextColor(1, 0.5, 0.2)

        aoeTauntPanel.counterText = aoeTauntPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        aoeTauntPanel.counterText:SetPoint("CENTER", 0, 4)

        local applyBtn = CreateFrame("Button", nil, aoeTauntPanel, "UIPanelButtonTemplate")
        applyBtn:SetSize(105, 24)
        applyBtn:SetPoint("BOTTOMLEFT", 10, 12)
        applyBtn:SetText(DoF.L["ui.panel.taunt"])
        applyBtn:SetScript("OnClick", function() DoF.Combat:TankTauntTarget() end)

        local doneBtn = CreateFrame("Button", nil, aoeTauntPanel, "UIPanelButtonTemplate")
        doneBtn:SetSize(105, 24)
        doneBtn:SetPoint("BOTTOMRIGHT", -10, 12)
        doneBtn:SetText(DoF.L["ui.panel.done"])
        doneBtn:SetScript("OnClick", function() DoF.Combat:EndTauntAoE() end)
    end

    aoeTauntPanel.counterText:SetText(DoF.Locale:Format("ui.panel.left", tauntsLeft))
    aoeTauntPanel:Show()
end

function DoF.UI:UpdateAoETauntPanel()
    if aoeTauntPanel and aoeTauntPanel:IsShown() then
        local tauntsLeft = DoF.Combat.AoETauntState.tauntsLeft
        aoeTauntPanel.counterText:SetText(DoF.Locale:Format("ui.panel.left", tauntsLeft))
    end
end

function DoF.UI:HideAoETauntPanel()
    if aoeTauntPanel then
        aoeTauntPanel:Hide()
    end
end

-- ═══════════════════════════════════════════════════════════
-- ПАНЕЛЬ ОСОБОГО ДЕЙСТВИЯ (выбор целей)
-- ═══════════════════════════════════════════════════════════

local specialActionPanel = nil

function DoF.UI:ShowSpecialActionPanel()
    local mode = DoF.Combat:GetSpecialActionMode()
    local targetsLeft = DoF.Combat:GetSpecialActionTargetsLeft()
    local actionTypeName = DoF.Config.SpecialActionTypes[mode] or mode

    -- Определяем цвет и текст кнопки по типу действия
    local btnLabel, titleColor, bgR, bgG, bgB, borderR, borderG, borderB
    if mode == "buff" or mode == "aoe_buff" then
        btnLabel = DoF.L["ui.panel.apply"]
        titleColor = "66FF66"
        bgR, bgG, bgB = 0.05, 0.1, 0.05
        borderR, borderG, borderB = 0.2, 0.7, 0.3
    elseif mode == "attack" or mode == "aoe_attack" then
        btnLabel = DoF.L["ui.panel.hit"]
        titleColor = "FF9900"
        bgR, bgG, bgB = 0.1, 0.05, 0.05
        borderR, borderG, borderB = 0.8, 0.4, 0.1
    elseif mode == "wound_removal" then
        btnLabel = DoF.L["ui.action.remove_wound"]
        titleColor = "66CCFF"
        bgR, bgG, bgB = 0.05, 0.05, 0.1
        borderR, borderG, borderB = 0.3, 0.5, 0.8
    elseif mode == "dispel" then
        btnLabel = DoF.L["ui.action.dispel_title"]
        titleColor = "9966FF"
        bgR, bgG, bgB = 0.08, 0.05, 0.1
        borderR, borderG, borderB = 0.5, 0.3, 0.8
    elseif mode == "purge" then
        btnLabel = DoF.L["ui.bar.purge"]
        titleColor = "FF66FF"
        bgR, bgG, bgB = 0.1, 0.05, 0.08
        borderR, borderG, borderB = 0.8, 0.3, 0.6
    else
        btnLabel = DoF.L["ui.common.apply"]
        titleColor = "FFFFFF"
        bgR, bgG, bgB = 0.1, 0.1, 0.1
        borderR, borderG, borderB = 0.5, 0.5, 0.5
    end

    if not specialActionPanel then
        specialActionPanel = CreateFrame("Frame", "DoF_SpecialActionPanel", UIParent, "TooltipBackdropTemplate")
        specialActionPanel:SetSize(240, 120)
        specialActionPanel:SetPoint("TOP", 0, -150)
        specialActionPanel:SetFrameStrata("FULLSCREEN_DIALOG")

        specialActionPanel.titleText = specialActionPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        specialActionPanel.titleText:SetPoint("TOP", 0, -10)

        specialActionPanel.hintText = specialActionPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        specialActionPanel.hintText:SetPoint("TOP", 0, -32)
        specialActionPanel.hintText:SetTextColor(0.7, 0.7, 0.7)

        specialActionPanel.counterText = specialActionPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        specialActionPanel.counterText:SetPoint("CENTER", 0, 4)

        specialActionPanel.applyBtn = CreateFrame("Button", nil, specialActionPanel, "UIPanelButtonTemplate")
        specialActionPanel.applyBtn:SetSize(105, 24)
        specialActionPanel.applyBtn:SetPoint("BOTTOMLEFT", 10, 12)
        specialActionPanel.applyBtn.text = specialActionPanel.applyBtn:GetFontString()  -- алиас
        specialActionPanel.applyBtn:SetScript("OnClick", function()
            DoF.Combat:SpecialActionApplyTarget()
        end)

        specialActionPanel.cancelBtn = CreateFrame("Button", nil, specialActionPanel, "UIPanelButtonTemplate")
        specialActionPanel.cancelBtn:SetSize(105, 24)
        specialActionPanel.cancelBtn:SetPoint("BOTTOMRIGHT", -10, 12)
        specialActionPanel.cancelBtn:SetText(DoF.L["ui.common.cancel"])
        specialActionPanel.cancelBtn:SetScript("OnClick", function() DoF.Combat:CancelSpecialAction() end)
    end

    -- Обновляем заголовок (цвет — через FontString-color)
    specialActionPanel.titleText:SetText(DoF.Locale:Format("ui.panel.special_title", actionTypeName:upper()))
    specialActionPanel.titleText:SetTextColor(borderR, borderG, borderB)

    -- Подсказка по типу цели
    local hintText = DoF.L["ui.panel.choose_target"]
    if mode == "attack" or mode == "aoe_attack" or mode == "purge" then
        hintText = DoF.L["ui.panel.choose_npc_target"]
    elseif mode == "buff" or mode == "aoe_buff" or mode == "wound_removal" or mode == "dispel" then
        hintText = DoF.L["ui.panel.choose_player"]
    end
    specialActionPanel.hintText:SetText(hintText)

    specialActionPanel.counterText:SetText(DoF.Locale:Format("ui.panel.targets_left", targetsLeft))

    -- Текст кнопки применения зависит от режима
    specialActionPanel.applyBtn:SetText(btnLabel)

    specialActionPanel:Show()
end

function DoF.UI:UpdateSpecialActionPanel()
    if not specialActionPanel or not specialActionPanel:IsShown() then return end
    local targetsLeft = DoF.Combat:GetSpecialActionTargetsLeft()
    specialActionPanel.counterText:SetText(DoF.Locale:Format("ui.panel.targets_left", targetsLeft))
end

function DoF.UI:HideSpecialActionPanel()
    if specialActionPanel then
        specialActionPanel:Hide()
    end
end
