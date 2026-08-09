-- DoF/UI/ActionBar.lua
-- Плавающая панель действий (Action Bar) — стилистика DiceMaster

local ADDON_NAME, DoF = ...

-- Кэширование
local CreateFrame = CreateFrame
local pairs = pairs
local ipairs = ipairs
local UnitName = UnitName

local C_Timer = C_Timer

DoF.ActionBar = {}
local AB = DoF.ActionBar

-- ═══════════════════════════════════════════════════════════
-- ТЕКСТУРЫ
-- ═══════════════════════════════════════════════════════════

local TEXTURE_PATH = "Interface/AddOns/DoF/texture/actionbar/"
local TEX_BORDER       = TEXTURE_PATH .. "btn-border"
local TEX_BORDER_ELITE = TEXTURE_PATH .. "btn-border-elite"
local TEX_HIGHLIGHT    = TEXTURE_PATH .. "btn-highlight"
local TEX_SELECTED     = TEXTURE_PATH .. "btn-selected"

-- ═══════════════════════════════════════════════════════════
-- ДАННЫЕ КНОПОК
-- ═══════════════════════════════════════════════════════════

-- Таблица собирается функцией, а не литералом на уровне файла: подписи здесь
-- «запекаются» при загрузке, когда сохранённый язык ещё неизвестен. Ключи у
-- кнопок произвольные и из id не выводятся, поэтому вместо таблицы соответствий
-- проще пересобрать литерал целиком. Присваивание идёт в ту же локальную
-- переменную, так что все замыкания, ссылающиеся на неё, видят новую таблицу.
local ACTION_BUTTONS

local function BuildActionButtons()
ACTION_BUTTONS = {
    { id = "attack", label = DoF.L["ui.bar.attack"], icon = "Interface/Icons/ability_warrior_offensiveStance", hasSubMenu = true,
      subItems = {
          { id = "Strength", label = DoF.L["stats.strength.label"], colorHex = "FF6666", icon = "Interface/Icons/ability_warrior_savageblow" },
          { id = "Dexterity", label = DoF.L["stats.dexterity.label"], colorHex = "66FF66", icon = "Interface/Icons/ability_rogue_focusedattacks" },
          { id = "Intelligence", label = DoF.L["stats.intelligence.label"], colorHex = "66CCFF", icon = "Interface/Icons/spell_arcane_focusedpower" },
      },
      defaultSub = "Strength",
      dynamicTooltip = true,
    },
    { id = "heal", label = DoF.L["ui.bar.heal"], icon = "Interface/Icons/spell_holy_flashheal",
      hasSubMenu = true, dynamicTooltip = true,
      subItems = {
          { id = "heal", label = DoF.L["ui.bar.heal"], colorHex = "66FF66", icon = "Interface/Icons/spell_holy_flashheal" },
          { id = "restore_energy", label = DoF.L["ui.bar.restore_energy"], colorHex = "66CCFF", roleFilter = { healer = true }, icon = "Interface/Icons/spell_arcane_arcane04" },
      },
      defaultSub = "heal",
    },
    { id = "sep1", separator = true },
    { id = "shield", label = DoF.L["ui.common.shield"], icon = "Interface/Icons/spell_holy_powerwordshield",
      roleFilter = { healer = true },
      tooltip = DoF.L["ui.bar.shield_tooltip"],
    },
    { id = "support", label = DoF.L["ui.bar.support"], icon = "Interface/Icons/spell_holy_dispelmagic", hasSubMenu = true,
      roleFilter = { healer = true },
      subItems = {
          { id = "wound",  label = DoF.L["ui.bar.wound"],   colorHex = "FF6666", icon = "Interface/Icons/ability_rogue_recuperate" },
          { id = "dispel", label = DoF.L["ui.action.dispel_title"], colorHex = "66FF99", icon = "Interface/Icons/spell_holy_dispelmagic" },
          { id = "purge",  label = DoF.L["ui.bar.purge"],   colorHex = "FFAA66", icon = "Interface/Icons/spell_nature_purge" },
      },
      defaultSub = "wound",
      dynamicTooltip = true,
    },
    { id = "sep2", separator = true },
    { id = "aoe", label = "AoE", icon = "Interface/Icons/spell_fire_sealoffire", hasSubMenu = true, energyCost = 1,
      subItems = {
          { id = "Strength", label = DoF.L["stats.strength.label"], colorHex = "FF6666", icon = "Interface/Icons/ability_warrior_bladestorm" },
          { id = "Dexterity", label = DoF.L["stats.dexterity.label"], colorHex = "66FF66", icon = "Interface/Icons/ability_rogue_fanofknives" },
          { id = "Intelligence", label = DoF.L["stats.intelligence.label"], colorHex = "66CCFF", icon = "Interface/Icons/ability_mage_missilebarrage" },
          { id = "Heal", label = DoF.L["ui.common.healing"], colorHex = "66FF66", roleFilter = { healer = true }, icon = "Interface/Icons/spell_holy_blindingheal" },
      },
      defaultSub = "Strength",
      dynamicTooltip = true,
    },
    { id = "effect", label = DoF.L["ui.bar.effect"], icon = "Interface/Icons/spell_shadow_curseofsargeras", energyCost = 1,
      tooltip = DoF.L["ui.bar.effect_tooltip"],
    },
    { id = "buff", label = DoF.L["ui.common.buff"], icon = "Interface/Icons/spell_holy_greaterblessingofkings", energyCost = 1,
      dynamicTooltip = true,
    },
    { id = "special", label = DoF.L["ui.bar.special"], icon = "Interface/Icons/inv_misc_questionmark",
      tooltip = DoF.L["ui.bar.special_tooltip"],
    },
    { id = "tank_ability", label = DoF.L["ui.bar.tank"], icon = "Interface/Icons/ability_warrior_shieldwall",
      hasSubMenu = true, roleFilter = { tank = true },
      subItems = {
          { id = "redirect",  label = DoF.L["ui.bar.redirect"],    colorHex = "FFD700" },
          { id = "taunt",     label = DoF.L["ui.bar.taunt"],  colorHex = "CC8040" },
          { id = "taunt_aoe", label = DoF.L["ui.bar.taunt_aoe"], colorHex = "FF6633" },
      },
      defaultSub = "taunt",
      dynamicTooltip = true,
    },
    { id = "sep3", separator = true },
    { id = "check", label = DoF.L["ui.bar.check"], icon = "Interface/Icons/inv_misc_dice_02", hasSubMenu = true,
      subItems = "allstats",
      defaultSub = "Strength",
      dynamicTooltip = true,
    },
    { id = "skip", label = DoF.L["ui.common.skip"], icon = "Interface/Icons/spell_holy_borrowedtime",
      tooltip = DoF.L["ui.bar.skip_tooltip"],
    },
    { id = "sep4", separator = true },
    -- Аварийный ресинк данных NPC. Активна вне очереди и при критическом
    -- ранении — это утилитарная кнопка, не боевое действие.
    -- Иконка: голубая сфера-портал — символизирует синхронизацию/связь с мастером.
    { id = "request_npc", label = DoF.L["ui.bar.refresh"], icon = "Interface/Icons/spell_arcane_portalstormwind",
      tooltip = DoF.L["ui.bar.refresh_tooltip"],
    },
}
end

BuildActionButtons()

-- Runtime state
local ActionBarState = {
    selections = {},  -- btnId -> selected subItem id
}

-- Frame references
local barFrame = nil
local subMenuFrame = nil
local buttonWidgets = {}  -- btnId -> { frame, selectGlow, badge, def }

-- ═══════════════════════════════════════════════════════════
-- ОБРАБОТЧИКИ ДЕЙСТВИЙ
-- ═══════════════════════════════════════════════════════════

local function ExecuteAction(btnId, sub)
    if btnId == "attack" then
        DoF.Combat:Attack(sub or "Strength")
    elseif btnId == "heal" then
        local sel = sub or "heal"
        if sel == "restore_energy" then
            DoF.Combat:RestoreTargetEnergy()
        else
            DoF.Combat:Heal()
        end
    elseif btnId == "shield" then
        DoF.Combat:Shield()
    elseif btnId == "support" then
        local sel = sub or "wound"
        if sel == "wound" then
            DoF.Combat:RemoveWound()
        elseif sel == "dispel" then
            DoF.Combat:DispelTarget()
        elseif sel == "purge" then
            DoF.Combat:PurgeTarget()
        end
    elseif btnId == "aoe" then
        local sel = sub or "Strength"
        if sel == "Heal" then
            DoF.Combat:StartAoEHeal()
        else
            DoF.Combat:StartAoEAttack(sel)
        end
    elseif btnId == "effect" then
        DoF.Dialogs:ShowEffectsMenu(buttonWidgets[btnId] and buttonWidgets[btnId].frame)
    elseif btnId == "buff" then
        DoF.Dialogs:ShowBuffSelectMenu(buttonWidgets[btnId] and buttonWidgets[btnId].frame)
    elseif btnId == "special" then
        DoF.Combat:SpecialAction()
    elseif btnId == "tank_ability" then
        local sel = sub or "taunt"
        if sel == "redirect" then
            DoF.Combat:TankRedirect()
        elseif sel == "taunt" then
            DoF.Combat:TankTaunt()
        elseif sel == "taunt_aoe" then
            DoF.Combat:TankTauntAoE()
        end
    elseif btnId == "check" then
        DoF.Combat:Check(sub or "Strength")
    elseif btnId == "skip" then
        if DoF.Sync:IsMaster() then
            DoF.TurnSystem:SkipTurn()
        else
            DoF.TurnSystem:PlayerSkipTurn()
        end
    elseif btnId == "request_npc" then
        if DoF.Sync and DoF.Sync.RequestNPCDataManual then
            DoF.Sync:RequestNPCDataManual()
        end
    end
end

-- ═══════════════════════════════════════════════════════════
-- ПОДМЕНЮ (переиспользуемый фрейм)
-- ═══════════════════════════════════════════════════════════

local SUB_MENU_BTN_HEIGHT = 22
local SUB_MENU_BTN_WIDTH = 124
local subMenuButtons = {}
local subMenuOwner = nil

local function GetSubItemIcon(btnId, subId)
    for _, def in ipairs(ACTION_BUTTONS) do
        if def.id == btnId and def.hasSubMenu then
            if def.subItems == "allstats" then
                return DoF.Config.StatIcons[subId]
            elseif type(def.subItems) == "table" then
                for _, item in ipairs(def.subItems) do
                    if item.id == subId and item.icon then
                        return item.icon
                    end
                end
            end
        end
    end
    return nil
end

local function UpdateMainButtonIcon(btnId)
    local widget = buttonWidgets[btnId]
    if not widget or not widget.frame then return end
    local sel = ActionBarState.selections[btnId]
    if not sel then return end
    local icon = GetSubItemIcon(btnId, sel)
    if icon then
        widget.frame.icon:SetTexture(icon)
    end
end

local function HideSubMenu()
    if subMenuFrame then
        subMenuFrame:Hide()
    end
    subMenuOwner = nil
end

local function ShowSubMenu(btnId, anchorFrame)
    if not subMenuFrame then
        subMenuFrame = CreateFrame("Frame", "DoF_ActionBar_SubMenu", UIParent, "BackdropTemplate")
        subMenuFrame:SetBackdrop(DoF.Utils.Backdrops.Standard)
        subMenuFrame:SetBackdropColor(0.08, 0.08, 0.08, 0.95)
        subMenuFrame:SetBackdropBorderColor(0.25, 0.25, 0.25, 1)
        subMenuFrame:SetFrameStrata("FULLSCREEN_DIALOG")
        subMenuFrame:EnableMouse(true)
        subMenuFrame:Hide()
    end

    if subMenuOwner == btnId and subMenuFrame:IsShown() then
        HideSubMenu()
        return
    end

    for _, btn in ipairs(subMenuButtons) do
        btn:Hide()
    end

    local def = nil
    for _, d in ipairs(ACTION_BUTTONS) do
        if d.id == btnId then def = d break end
    end
    if not def or not def.hasSubMenu then return end

    local items = {}
    if def.subItems == "allstats" then
        for _, stat in ipairs(DoF.Config.AllStats) do
            items[#items + 1] = {
                id = stat,
                label = DoF.Config.StatNames[stat] or stat,
                colorHex = DoF.Config.StatColors[stat] or "FFFFFF",
                icon = DoF.Config.StatIcons[stat],
            }
        end
    elseif type(def.subItems) == "table" then
        local role = DoF.Stats and DoF.Stats:GetRole()
        for _, item in ipairs(def.subItems) do
            if not item.roleFilter or item.roleFilter[role] then
                items[#items + 1] = item
            end
        end
    end

    if #items == 0 then return end

    local menuWidth = SUB_MENU_BTN_WIDTH + 8
    local menuHeight = #items * (SUB_MENU_BTN_HEIGHT + 2) + 6

    subMenuFrame:SetSize(menuWidth, menuHeight)
    subMenuFrame:ClearAllPoints()
    subMenuFrame:SetPoint("BOTTOM", anchorFrame, "TOP", 0, 8)

    local currentSelection = ActionBarState.selections[btnId]

    for i, item in ipairs(items) do
        local btn = subMenuButtons[i]
        if not btn then
            btn = CreateFrame("Button", nil, subMenuFrame, "BackdropTemplate")
            btn:SetBackdrop({
                bgFile = "Interface\\Buttons\\WHITE8x8",
                edgeFile = nil,
                edgeSize = 0,
            })
            btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            btn.icon = btn:CreateTexture(nil, "OVERLAY")
            btn.icon:SetSize(16, 16)
            btn.icon:SetPoint("LEFT", 4, 0)
            subMenuButtons[i] = btn
        end

        btn:SetParent(subMenuFrame)
        btn:SetSize(SUB_MENU_BTN_WIDTH, SUB_MENU_BTN_HEIGHT)
        btn:ClearAllPoints()
        btn:SetPoint("TOP", subMenuFrame, "TOP", 0, -(i - 1) * (SUB_MENU_BTN_HEIGHT + 2) - 3)

        -- Динамическое позиционирование иконки и текста
        btn.text:ClearAllPoints()
        if item.icon then
            btn.icon:SetTexture(item.icon)
            btn.icon:Show()
            btn.text:SetPoint("LEFT", btn.icon, "RIGHT", 4, 0)
            btn.text:SetPoint("RIGHT", -4, 0)
            btn.text:SetJustifyH("LEFT")
        else
            btn.icon:Hide()
            btn.text:SetPoint("CENTER")
            btn.text:SetJustifyH("CENTER")
        end

        local isSelected = (currentSelection == item.id)
        local hex = item.colorHex or "FFFFFF"

        if isSelected then
            btn:SetBackdropColor(0.25, 0.22, 0.1, 1)
            btn.text:SetText("|cFF" .. hex .. "> " .. item.label .. "|r")
        else
            btn:SetBackdropColor(0.12, 0.12, 0.12, 1)
            btn.text:SetText("|cFF" .. hex .. item.label .. "|r")
        end

        local capturedId = item.id
        local capturedBtnId = btnId
        btn:SetScript("OnEnter", function(self)
            self:SetBackdropColor(0.2, 0.2, 0.2, 1)
        end)
        btn:SetScript("OnLeave", function(self)
            if ActionBarState.selections[capturedBtnId] == capturedId then
                self:SetBackdropColor(0.25, 0.22, 0.1, 1)
            else
                self:SetBackdropColor(0.12, 0.12, 0.12, 1)
            end
        end)
        btn:SetScript("OnClick", function()
            ActionBarState.selections[capturedBtnId] = capturedId
            UpdateMainButtonIcon(capturedBtnId)
            HideSubMenu()
            AB:UpdateIndicators()
        end)
        btn:Show()
    end

    subMenuOwner = btnId
    subMenuFrame:Show()
end

-- ═══════════════════════════════════════════════════════════
-- СОЗДАНИЕ ПАНЕЛИ (стиль DiceMaster)
-- ═══════════════════════════════════════════════════════════

local ICON_SIZE = 32
local BORDER_SIZE = 48
local BTN_GAP = 8
local SEP_GAP = 14
local PANEL_PAD_X = 10
local PANEL_PAD_TOP = 20
local PANEL_PAD_BOTTOM = 10

local function CreateActionButton(parent, def)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(ICON_SIZE, ICON_SIZE)
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    -- Icon (BACKGROUND layer)
    btn.icon = btn:CreateTexture(nil, "BACKGROUND")
    btn.icon:SetAllPoints()
    btn.icon:SetTexture(def.icon or "Interface/Icons/inv_misc_questionmark")

    -- Border (BORDER layer)
    btn.border = btn:CreateTexture(nil, "BORDER")
    btn.border:SetSize(BORDER_SIZE, BORDER_SIZE)
    btn.border:SetPoint("CENTER")
    btn.border:SetTexture(TEX_BORDER)

    -- Highlight on hover (OVERLAY layer)
    btn.highlight = btn:CreateTexture(nil, "OVERLAY")
    btn.highlight:SetSize(BORDER_SIZE, BORDER_SIZE)
    btn.highlight:SetPoint("CENTER")
    btn.highlight:SetTexture(TEX_HIGHLIGHT)
    btn.highlight:Hide()

    -- Selection glow (ARTWORK layer)
    local selectGlow = btn:CreateTexture(nil, "ARTWORK")
    selectGlow:SetSize(BORDER_SIZE, BORDER_SIZE)
    selectGlow:SetPoint("CENTER")
    selectGlow:SetTexture(TEX_SELECTED)
    selectGlow:Hide()

    -- Energy cost badge
    local badge = nil
    local showBadge = (def.energyCost and def.energyCost > 0) or def.id == "tank_ability" or def.id == "heal"
    if showBadge then
        badge = CreateFrame("Frame", nil, btn, "BackdropTemplate")
        badge:SetSize(16, 14)
        badge:SetPoint("TOPRIGHT", 2, 2)
        badge:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
        })
        badge:SetBackdropColor(0.15, 0.08, 0.25, 0.9)
        badge:SetBackdropBorderColor(0.3, 0.15, 0.5, 0.8)
        badge:SetFrameLevel(btn:GetFrameLevel() + 2)

        badge.text = badge:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        badge.text:SetPoint("CENTER", 0, 0)
        badge.text:SetFont(DoF.Config.FONT, 8, "OUTLINE")
        badge.text:SetText(def.energyCost or 1)
        badge.text:SetTextColor(0.8, 0.6, 1)

        -- Скрываем бейдж для кнопок с динамической стоимостью (по умолчанию = 0)
        if not def.energyCost and (def.id == "tank_ability" or def.id == "heal") then
            badge:Hide()
        end
    end

    -- Cooldown frame (for future use)
    btn.cooldown = CreateFrame("Cooldown", nil, btn, "CooldownFrameTemplate")
    btn.cooldown:SetAllPoints()
    btn.cooldown:SetDrawEdge(false)

    -- Hover effects
    btn:SetScript("OnEnter", function(self)
        self.highlight:Show()

        if not def.tooltip and not def.dynamicTooltip then return end

        local lines = {}

        if def.dynamicTooltip and def.id == "attack" then
            local sel = ActionBarState.selections[def.id] or "Strength"
            local statName = DoF.Config.StatNames[sel] or sel
            local defStat = DoF.Config.AttackVsDefense[sel]
            local defName = DoF.Config.StatNames[defStat] or defStat
            local total = DoF.Stats and DoF.Stats:GetTotal(sel) or 0
            lines[#lines + 1] = { text = DoF.Locale:Format("ui.action.attack_of", statName), r = 1, g = 0.82, b = 0, size = 14 }
            lines[#lines + 1] = { text = DoF.Locale:Format("ui.tip.attack_roll", statName, defName), r = 0.8, g = 0.8, b = 0.8 }
            lines[#lines + 1] = { text = DoF.Locale:Format("ui.tip.your_roll", total), r = 1, g = 1, b = 1 }
            lines[#lines + 1] = { text = DoF.L["ui.tip.attack_hint"], r = 0.5, g = 0.5, b = 0.5, size = 11 }

        elseif def.dynamicTooltip and def.id == "heal" then
            local sel = ActionBarState.selections[def.id] or "heal"
            if sel == "restore_energy" then
                lines[#lines + 1] = { text = DoF.L["ui.tip.restore_energy_title"], r = 1, g = 0.82, b = 0, size = 14 }
                lines[#lines + 1] = { text = DoF.L["ui.tip.restore_energy_desc"], r = 0.8, g = 0.8, b = 0.8 }
                lines[#lines + 1] = { text = DoF.L["ui.tip.cost_1_energy"], r = 0.4, g = 0.8, b = 1 }
                lines[#lines + 1] = { text = DoF.L["ui.tip.not_on_self"], r = 1, g = 0.4, b = 0.4 }
                lines[#lines + 1] = { text = DoF.L["ui.tip.restore_hint"], r = 0.5, g = 0.5, b = 0.5, size = 11 }
            else
                local total = DoF.Stats and DoF.Stats:GetTotal("Spirit") or 0
                lines[#lines + 1] = { text = DoF.L["ui.bar.heal"], r = 1, g = 0.82, b = 0, size = 14 }
                lines[#lines + 1] = { text = DoF.L["ui.tip.heal_roll"], r = 0.8, g = 0.8, b = 0.8 }
                lines[#lines + 1] = { text = DoF.Locale:Format("ui.tip.your_roll", total), r = 1, g = 1, b = 1 }
                lines[#lines + 1] = { text = DoF.L["ui.tip.heal_hint"], r = 0.5, g = 0.5, b = 0.5, size = 11 }
            end

        elseif def.dynamicTooltip and def.id == "support" then
            local sel = ActionBarState.selections[def.id] or "wound"
            local selLabel = sel
            for _, item in ipairs(def.subItems) do
                if item.id == sel then selLabel = item.label break end
            end
            local total = DoF.Stats and DoF.Stats:GetTotal("Spirit") or 0
            lines[#lines + 1] = { text = DoF.Locale:Format("ui.tip.support_of", selLabel), r = 1, g = 0.82, b = 0, size = 14 }
            if sel == "wound" then
                lines[#lines + 1] = { text = DoF.L["ui.tip.wound_desc"], r = 0.8, g = 0.8, b = 0.8 }
                lines[#lines + 1] = { text = DoF.L["ui.tip.roll_spirit_16"], r = 1, g = 1, b = 1 }
            elseif sel == "dispel" then
                lines[#lines + 1] = { text = DoF.L["ui.tip.dispel_desc"], r = 0.8, g = 0.8, b = 0.8 }
                lines[#lines + 1] = { text = DoF.L["ui.tip.roll_spirit_14"], r = 1, g = 1, b = 1 }
            elseif sel == "purge" then
                lines[#lines + 1] = { text = DoF.L["ui.tip.purge_desc"], r = 0.8, g = 0.8, b = 0.8 }
                lines[#lines + 1] = { text = DoF.L["ui.tip.roll_spirit_14"], r = 1, g = 1, b = 1 }
            end
            lines[#lines + 1] = { text = DoF.Locale:Format("ui.tip.your_roll", total), r = 0.7, g = 0.7, b = 0.7 }
            lines[#lines + 1] = { text = DoF.L["ui.tip.support_hint"], r = 0.5, g = 0.5, b = 0.5, size = 11 }

        elseif def.dynamicTooltip and def.id == "aoe" then
            local sel = ActionBarState.selections[def.id] or "Strength"
            if sel == "Heal" then
                local total = DoF.Stats and DoF.Stats:GetTotal("Spirit") or 0
                lines[#lines + 1] = { text = DoF.L["ui.tip.aoe_heal_title"], r = 1, g = 0.82, b = 0, size = 14 }
                lines[#lines + 1] = { text = DoF.L["ui.tip.aoe_heal_desc"], r = 0.8, g = 0.8, b = 0.8 }
                lines[#lines + 1] = { text = DoF.L["ui.tip.aoe_heal_roll"], r = 0.8, g = 0.8, b = 0.8 }
                lines[#lines + 1] = { text = DoF.Locale:Format("ui.tip.your_roll", total), r = 1, g = 1, b = 1 }
            else
                local statName = DoF.Config.StatNames[sel] or sel
                local total = DoF.Stats and DoF.Stats:GetTotal(sel) or 0
                lines[#lines + 1] = { text = "AoE: " .. statName, r = 1, g = 0.82, b = 0, size = 14 }
                lines[#lines + 1] = { text = DoF.L["ui.tip.aoe_damage_desc"], r = 0.8, g = 0.8, b = 0.8 }
                lines[#lines + 1] = { text = DoF.L["ui.tip.aoe_auto_hit"], r = 0.8, g = 0.8, b = 0.8 }
                lines[#lines + 1] = { text = DoF.Locale:Format("ui.tip.your_roll", total), r = 1, g = 1, b = 1 }
            end
            lines[#lines + 1] = { text = DoF.L["ui.tip.aoe_hint"], r = 0.5, g = 0.5, b = 0.5, size = 11 }

        elseif def.dynamicTooltip and def.id == "check" then
            local sel = ActionBarState.selections[def.id] or "Strength"
            local statName = DoF.Config.StatNames[sel] or sel
            local total = DoF.Stats and DoF.Stats:GetTotal(sel) or 0
            lines[#lines + 1] = { text = DoF.Locale:Format("ui.check.of", statName), r = 1, g = 0.82, b = 0, size = 14 }
            lines[#lines + 1] = { text = DoF.Locale:Format("ui.tip.check_roll", statName), r = 0.8, g = 0.8, b = 0.8 }
            lines[#lines + 1] = { text = DoF.Locale:Format("ui.tip.your_roll", total), r = 1, g = 1, b = 1 }
            lines[#lines + 1] = { text = DoF.L["ui.tip.no_turn_cost"], r = 0.5, g = 0.5, b = 0.5, size = 11 }

        elseif def.dynamicTooltip and def.id == "tank_ability" then
            local sel = ActionBarState.selections[def.id] or "taunt"
            local selLabel = sel
            for _, item in ipairs(def.subItems) do
                if item.id == sel then selLabel = item.label break end
            end
            lines[#lines + 1] = { text = DoF.Locale:Format("ui.tip.tank_of", selLabel), r = 1, g = 0.82, b = 0, size = 14 }
            if sel == "taunt" then
                lines[#lines + 1] = { text = DoF.L["ui.tip.taunt_desc"], r = 0.8, g = 0.8, b = 0.8 }
                lines[#lines + 1] = { text = DoF.L["ui.tip.taunt_cost"], r = 0.6, g = 0.4, b = 0.9 }
            elseif sel == "taunt_aoe" then
                lines[#lines + 1] = { text = DoF.L["ui.tip.taunt_aoe_desc"], r = 0.8, g = 0.8, b = 0.8 }
                lines[#lines + 1] = { text = DoF.L["ui.tip.taunt_aoe_cost"], r = 0.6, g = 0.4, b = 0.9 }
            elseif sel == "redirect" then
                lines[#lines + 1] = { text = DoF.L["ui.tip.redirect_desc"], r = 0.8, g = 0.8, b = 0.8 }
                lines[#lines + 1] = { text = DoF.L["ui.tip.redirect_cost"], r = 0.6, g = 0.4, b = 0.9 }
            end
            lines[#lines + 1] = { text = DoF.L["ui.tip.tank_hint"], r = 0.5, g = 0.5, b = 0.5, size = 11 }

        elseif def.dynamicTooltip and def.id == "buff" then
            local role = DoF.Stats and DoF.Stats:GetRole()
            lines[#lines + 1] = { text = DoF.L["ui.common.buff"], r = 1, g = 0.82, b = 0, size = 14 }
            if role == "dd" then
                lines[#lines + 1] = { text = DoF.L["ui.tip.empower_choose"], r = 0.8, g = 0.8, b = 0.8 }
            elseif role == "tank" then
                lines[#lines + 1] = { text = DoF.L["ui.tip.fortify_choose"], r = 0.8, g = 0.8, b = 0.8 }
            elseif role == "healer" then
                lines[#lines + 1] = { text = DoF.L["ui.tip.empower_fortify"], r = 0.8, g = 0.8, b = 0.8 }
                lines[#lines + 1] = { text = DoF.L["ui.tip.aoe_buff_hint"], r = 0.8, g = 0.8, b = 0.8 }
            else
                lines[#lines + 1] = { text = DoF.L["ui.tip.buff_choose"], r = 0.8, g = 0.8, b = 0.8 }
            end

        elseif def.tooltip then
            local sel = ActionBarState.selections[def.id]
            local title = def.label
            if sel and def.hasSubMenu then
                local selLabel = sel
                if def.subItems == "allstats" then
                    selLabel = DoF.Config.StatNames[sel] or sel
                elseif type(def.subItems) == "table" then
                    for _, item in ipairs(def.subItems) do
                        if item.id == sel then selLabel = item.label break end
                    end
                end
                title = title .. ": " .. selLabel
            end
            lines[#lines + 1] = { text = title, r = 1, g = 0.82, b = 0, size = 14 }
            for line in def.tooltip:gmatch("[^\n]+") do
                lines[#lines + 1] = { text = line, r = 0.8, g = 0.8, b = 0.8 }
            end
        end

        if def.energyCost then
            lines[#lines + 1] = { text = DoF.Locale:Format("ui.tip.energy_required", def.energyCost), r = 0.6, g = 0.4, b = 0.9, size = 11 }
        end

        if #lines > 0 then
            DoF.Utils:ShowTooltip(self, lines)
        end
    end)
    btn:SetScript("OnLeave", function(self)
        self.highlight:Hide()
        DoF.Utils:HideTooltip()
    end)

    -- Click handler
    btn:SetScript("OnClick", function(self, mouseBtn)
        if mouseBtn == "RightButton" then
            if def.hasSubMenu then
                ShowSubMenu(def.id, self)
            elseif def.id == "shield" then
                HideSubMenu()
                DoF.Combat:StartAoEShield()
            elseif def.id == "buff" then
                HideSubMenu()
                local role = DoF.Stats and DoF.Stats:GetRole()
                if role == "healer" then
                    DoF.Dialogs:ShowAoEBuffSelectMenu(self)
                else
                    DoF.Utils:Error(DoF.L["errors.aoe_buff_healer_only"])
                end
            end
        else
            HideSubMenu()
            if def.hasSubMenu then
                local sel = ActionBarState.selections[def.id]
                if sel then
                    -- Если нельзя действовать — открыть подменю для смены выбора
                    local canAct = not DoF.TurnSystem or not DoF.TurnSystem.CanAct or DoF.TurnSystem:CanAct()
                    if canAct then
                        ExecuteAction(def.id, sel)
                    else
                        ShowSubMenu(def.id, self)
                    end
                else
                    ShowSubMenu(def.id, self)
                end
            else
                ExecuteAction(def.id)
            end
        end
    end)

    return btn, selectGlow, badge
end

function AB:CreateFrame()
    if barFrame then return barFrame end

    local f = CreateFrame("Frame", "DoF_ActionBarFrame", UIParent, "BackdropTemplate")
    f:SetBackdrop(DoF.Utils.Backdrops.Standard)
    f:SetBackdropColor(0.05, 0.05, 0.05, 0.85)
    f:SetBackdropBorderColor(0.2, 0.2, 0.2, 0.8)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:SetClampedToScreen(true)
    f:SetFrameStrata("DIALOG")
    f:SetToplevel(true)
    f:RegisterForDrag("LeftButton")

    f:SetScript("OnDragStart", function(self)
        local locked = DoF.db and DoF.db.profile.actionBar and DoF.db.profile.actionBar.locked
        if not locked then
            self:StartMoving()
        end
    end)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        AB:SavePosition()
    end)

    -- Header
    local header = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    header:SetPoint("TOP", 0, -4)
    header:SetText(DoF.L["ui.bar.title"])
    header:SetTextColor(0.5, 0.5, 0.5)

    -- Button container
    f.buttonContainer = CreateFrame("Frame", nil, f)
    f.buttonContainer:SetPoint("TOPLEFT", PANEL_PAD_X, -PANEL_PAD_TOP)

    barFrame = f
    return f
end

-- ═══════════════════════════════════════════════════════════
-- ПОСТРОЕНИЕ КНОПОК (с фильтрацией по роли)
-- ═══════════════════════════════════════════════════════════

function AB:BuildButtons()
    if not barFrame then return end

    -- Скрываем старые кнопки
    for _, w in pairs(buttonWidgets) do
        if w.frame then w.frame:Hide() end
    end
    buttonWidgets = {}

    -- Убираем старую подложку
    local container = barFrame.buttonContainer
    if container.bg then
        container.bg:Hide()
    end

    local role = DoF.Stats and DoF.Stats:GetRole()
    local xOffset = 0
    local btnCount = 0

    for _, def in ipairs(ACTION_BUTTONS) do
        if def.separator then
            xOffset = xOffset + SEP_GAP - BTN_GAP
        elseif not def.roleFilter or def.roleFilter[role] then
            local btn, selectGlow, badge = CreateActionButton(container, def)
            btn:SetPoint("LEFT", container, "LEFT", xOffset, 0)

            if def.hasSubMenu and def.defaultSub and not ActionBarState.selections[def.id] then
                ActionBarState.selections[def.id] = def.defaultSub
            end

            buttonWidgets[def.id] = {
                frame = btn,
                selectGlow = selectGlow,
                badge = badge,
                def = def,
            }

            xOffset = xOffset + ICON_SIZE + BTN_GAP
            btnCount = btnCount + 1
        end
    end

    -- Container and bar sizing
    local totalWidth = xOffset - BTN_GAP
    container:SetSize(totalWidth, ICON_SIZE)

    -- Фоновая подложка под иконками (тёмная "канавка")
    if not container.bg then
        container.bg = CreateFrame("Frame", nil, container, "BackdropTemplate")
        container.bg:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
        })
        container.bg:SetBackdropColor(0.03, 0.03, 0.03, 0.7)
        container.bg:SetBackdropBorderColor(0.15, 0.15, 0.15, 0.5)
        container.bg:SetFrameLevel(container:GetFrameLevel())
    end
    container.bg:ClearAllPoints()
    container.bg:SetPoint("TOPLEFT", -4, 4)
    container.bg:SetPoint("BOTTOMRIGHT", 4, -4)
    container.bg:Show()

    local barWidth = totalWidth + PANEL_PAD_X * 2
    local barHeight = ICON_SIZE + PANEL_PAD_TOP + PANEL_PAD_BOTTOM
    barFrame:SetSize(barWidth, barHeight)

    self:UpdateIndicators()
    self:Update()
end

-- ═══════════════════════════════════════════════════════════
-- ОБНОВЛЕНИЕ ИНДИКАТОРОВ ВЫБОРА
-- ═══════════════════════════════════════════════════════════

function AB:UpdateIndicators()
    for btnId, widget in pairs(buttonWidgets) do
        local sel = ActionBarState.selections[btnId]
        if widget.selectGlow then
            if sel and widget.def.hasSubMenu then
                widget.selectGlow:Show()
            else
                widget.selectGlow:Hide()
            end
        end
        -- Обновляем иконку основной кнопки по выбранному подпункту
        if sel and widget.def.hasSubMenu then
            local subIcon = GetSubItemIcon(btnId, sel)
            if subIcon then
                widget.frame.icon:SetTexture(subIcon)
            end
        end
    end
end

-- ═══════════════════════════════════════════════════════════
-- ОБНОВЛЕНИЕ СОСТОЯНИЯ КНОПОК (enabled/disabled)
-- ═══════════════════════════════════════════════════════════

function AB:Update()
    if not barFrame or not barFrame:IsShown() then return end

    local ts = DoF.TurnSystem
    local canAct = ts and ts:CanAct() or false
    local energy = DoF.Stats and DoF.Stats:GetEnergy() or 0
    local isIncap = DoF.Stats and DoF.Stats:IsIncapacitated() or false

    for btnId, widget in pairs(buttonWidgets) do
        local btn = widget.frame
        local def = widget.def
        if btn then
            -- Критическое ранение: все кнопки кроме «Проверки» и «Обновить» заблокированы
            if isIncap and btnId ~= "check" and btnId ~= "request_npc" then
                btn:Disable()
                btn:SetAlpha(0.4)
                btn.icon:SetDesaturated(true)
                if widget.badge then widget.badge:Hide() end
            elseif btnId == "check" or btnId == "request_npc" then
                -- Утилитарные кнопки (не боевые действия) — всегда активны
                btn:Enable()
                btn:SetAlpha(1)
                btn.icon:SetDesaturated(false)
            elseif btnId == "skip" then
                local inCombat = ts and ts:IsActive()
                if inCombat and canAct then
                    btn:Enable()
                    btn:SetAlpha(1)
                    btn.icon:SetDesaturated(false)
                else
                    btn:Disable()
                    btn:SetAlpha(0.4)
                    btn.icon:SetDesaturated(true)
                end
            else
                local hasEnergy = true
                if def.energyCost and def.energyCost > 0 then
                    hasEnergy = energy >= def.energyCost
                end

                local onCooldown = false
                if btnId == "special" and DoF.Effects then
                    local cd = DoF.Effects:Get("player", UnitName("player"), "cooldown_special_action")
                    if cd then onCooldown = true end
                end
                if btnId == "aoe" and DoF.Effects then
                    local cd = DoF.Effects:Get("player", UnitName("player"), "cooldown_aoe")
                    if cd then onCooldown = true end
                end

                -- Лечение: динамическая стоимость энергии по выбранному подпункту
                if btnId == "heal" then
                    local sel = ActionBarState.selections[btnId] or "heal"
                    local cost = 0
                    if sel == "restore_energy" then
                        cost = 1
                    end
                    hasEnergy = cost == 0 or energy >= cost
                    if widget.badge then
                        if cost > 0 then
                            widget.badge.text:SetText(cost)
                            widget.badge:Show()
                        else
                            widget.badge:Hide()
                        end
                    end
                end

                -- Танк: динамическая стоимость энергии и кулдаун по выбранному подпункту
                if btnId == "tank_ability" and DoF.Effects then
                    local sel = ActionBarState.selections[btnId] or "taunt"
                    local cdId, cost
                    if sel == "taunt" then
                        cdId = "cooldown_tank_taunt"
                        cost = DoF.Config.ENERGY_COST_TAUNT
                    elseif sel == "taunt_aoe" then
                        cdId = "cooldown_tank_taunt_aoe"
                        cost = DoF.Config.ENERGY_COST_TAUNT_AOE
                    elseif sel == "redirect" then
                        cdId = "cooldown_tank_redirect"
                        cost = 0
                    end
                    if cdId then
                        local cd = DoF.Effects:Get("player", UnitName("player"), cdId)
                        if cd then onCooldown = true end
                    end
                    hasEnergy = cost == 0 or energy >= cost
                    -- Обновляем бейдж энергии
                    if widget.badge then
                        if cost and cost > 0 then
                            widget.badge.text:SetText(cost)
                            widget.badge:Show()
                        else
                            widget.badge:Hide()
                        end
                    end
                end

                if canAct and hasEnergy and not onCooldown then
                    btn:Enable()
                    btn:SetAlpha(1)
                    btn.icon:SetDesaturated(false)
                elseif def.hasSubMenu and not canAct then
                    -- Кнопки с подменю остаются кликабельными для предвыбора стата
                    btn:Enable()
                    btn:SetAlpha(0.6)
                    btn.icon:SetDesaturated(true)
                else
                    btn:Disable()
                    btn:SetAlpha(0.4)
                    btn.icon:SetDesaturated(true)
                end

                if widget.badge then
                    if hasEnergy then
                        widget.badge:SetBackdropColor(0.15, 0.08, 0.25, 0.9)
                        widget.badge:SetBackdropBorderColor(0.3, 0.15, 0.5, 0.8)
                        widget.badge.text:SetTextColor(0.8, 0.6, 1)
                    else
                        widget.badge:SetBackdropColor(0.25, 0.05, 0.05, 0.9)
                        widget.badge:SetBackdropBorderColor(0.5, 0.1, 0.1, 0.8)
                        widget.badge.text:SetTextColor(1, 0.3, 0.3)
                    end
                end
            end
        end
    end

end

-- ═══════════════════════════════════════════════════════════
-- ПОЗИЦИЯ И МАСШТАБ
-- ═══════════════════════════════════════════════════════════

function AB:SavePosition()
    if not barFrame or not DoF.db then return end
    local point, _, relPoint, x, y = barFrame:GetPoint()
    DoF.db.profile.actionBar.position = {
        point = point,
        relPoint = relPoint or point,
        x = x,
        y = y,
    }
end

function AB:LoadPosition()
    if not barFrame or not DoF.db then return end
    local pos = DoF.db.profile.actionBar.position
    if pos then
        barFrame:ClearAllPoints()
        barFrame:SetPoint(pos.point, UIParent, pos.relPoint or pos.point, pos.x, pos.y)
    end
end

function AB:ResetPosition()
    if not DoF.db then return end
    DoF.db.profile.actionBar.position = { point = "BOTTOM", relPoint = "BOTTOM", x = 0, y = 120 }
    self:LoadPosition()
    DoF.Utils:Info(DoF.L["ui.bar.position_reset"])
end

function AB:ApplyScale()
    if not barFrame or not DoF.db then return end
    local scale = DoF.db.profile.actionBar.scale or 1.0
    barFrame:SetScale(scale)
end

-- ═══════════════════════════════════════════════════════════
-- TOGGLE / LOCK
-- ═══════════════════════════════════════════════════════════

function AB:Toggle()
    if not DoF.db then return end
    local enabled = DoF.db.profile.actionBar.enabled
    DoF.db.profile.actionBar.enabled = not enabled

    if not enabled then
        self:Show()
        DoF.Utils:Info(DoF.L["ui.bar.enabled"])
    else
        self:Hide()
        DoF.Utils:Info(DoF.L["ui.bar.disabled"])
    end
end

function AB:ToggleLock()
    if not DoF.db then return end
    local locked = DoF.db.profile.actionBar.locked
    DoF.db.profile.actionBar.locked = not locked
    DoF.Utils:Info(DoF.L[not locked and "ui.bar.locked" or "ui.bar.unlocked"])
end

function AB:Show()
    if not barFrame then
        self:CreateFrame()
        self:BuildButtons()
        self:LoadPosition()
        self:ApplyScale()
    end
    barFrame:Show()
    self:Update()
end

function AB:Hide()
    HideSubMenu()
    if barFrame then
        barFrame:Hide()
    end
end

-- ═══════════════════════════════════════════════════════════
-- ИНИЦИАЛИЗАЦИЯ
-- ═══════════════════════════════════════════════════════════

function AB:Init()
    if not DoF.db or not DoF.db.profile.actionBar then return end
    if not DoF.db.profile.actionBar.enabled then return end

    self:CreateFrame()
    self:BuildButtons()
    self:LoadPosition()
    self:ApplyScale()
    barFrame:Show()
    self:Update()

    C_Timer.After(0.5, function()
        if DoF.Events then
            DoF.Events:Register("PLAYER_SPEC_CHANGED", function()
                AB:BuildButtons()
            end, AB)

            DoF.Events:Register("PLAYER_ENERGY_CHANGED", function()
                AB:Update()
            end, AB)

            DoF.Events:Register("COMBAT_ENDED", function()
                AB:Update()
            end, AB)
        end
    end)
end

-- Хук для обновления из UpdateTurnQueue
local origUpdateTurnQueue = DoF.UI.UpdateTurnQueue
if origUpdateTurnQueue then
    DoF.UI.UpdateTurnQueue = function(self, ...)
        origUpdateTurnQueue(self, ...)
        if barFrame and barFrame:IsShown() then
            AB:Update()
        end
    end
end

-- ═══════════════════════════════════════════════════════════
-- ПОВТОРНОЕ ПРИМЕНЕНИЕ ЯЗЫКА
-- ═══════════════════════════════════════════════════════════

-- Пересобираем описания кнопок и перерисовываем панель, если она уже создана:
-- подписи попадают в виджеты при построении, сами по себе они не обновятся.
DoF.Locale:RegisterRelocalizer(function()
    BuildActionButtons()

    -- Кнопки уже созданы с прежними подписями, поэтому пересоздаём их:
    -- BuildButtons переносит текст из ACTION_BUTTONS в виджеты.
    if AB.BuildButtons and barFrame then
        AB:BuildButtons()
        AB:Update()
    end
end)
