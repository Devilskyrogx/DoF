-- DoF/UI/MinimapButton.lua
-- Кнопка на миникарте (WoW 11.0.2+)

local ADDON_NAME, DoF = ...

DoF.UI = DoF.UI or {}

-- Ленивая инициализация — UIDropDownMenuTemplate доступен только после полной
-- загрузки FrameXML. Создаём один раз при первом ПКМ и переиспользуем.
local minimapMenuFrame

local function buildMinimapMenu(_, level)
    if level ~= 1 then return end
    local info

    -- Заголовок
    info = UIDropDownMenu_CreateInfo()
    info.text = DoF.L["ui.minimap.settings"]
    info.isTitle = true
    info.notCheckable = true
    UIDropDownMenu_AddButton(info, level)

    -- Фрейм игрока
    info = UIDropDownMenu_CreateInfo()
    info.text = DoF.L["ui.minimap.player_frame"]
    info.isNotRadio = true
    info.keepShownOnClick = true
    info.checked = function()
        return DoF.db and DoF.db.profile.unitFrames and DoF.db.profile.unitFrames.player.enabled
    end
    info.func = function()
        if DoF.UI and DoF.UI.UnitFrames and DoF.UI.UnitFrames.TogglePlayerFrame then
            DoF.UI.UnitFrames:TogglePlayerFrame()
        end
    end
    UIDropDownMenu_AddButton(info, level)

    -- Фрейм цели
    info = UIDropDownMenu_CreateInfo()
    info.text = DoF.L["ui.minimap.target_frame"]
    info.isNotRadio = true
    info.keepShownOnClick = true
    info.checked = function()
        return DoF.db and DoF.db.profile.unitFrames and DoF.db.profile.unitFrames.target.enabled
    end
    info.func = function()
        if DoF.UI and DoF.UI.UnitFrames and DoF.UI.UnitFrames.ToggleTargetFrame then
            DoF.UI.UnitFrames:ToggleTargetFrame()
        end
    end
    UIDropDownMenu_AddButton(info, level)

    -- Панель действий
    info = UIDropDownMenu_CreateInfo()
    info.text = DoF.L["ui.minimap.action_bar"]
    info.isNotRadio = true
    info.keepShownOnClick = true
    info.checked = function()
        return DoF.db and DoF.db.profile.actionBar and DoF.db.profile.actionBar.enabled
    end
    info.func = function()
        if DoF.ActionBar and DoF.ActionBar.Toggle then
            DoF.ActionBar:Toggle()
        end
    end
    UIDropDownMenu_AddButton(info, level)

    -- Журнал боя — показать/скрыть окно (feature-toggle живёт в Settings.lua)
    info = UIDropDownMenu_CreateInfo()
    info.text = DoF.L["ui.combatlog.title_battle"]
    info.isNotRadio = true
    info.keepShownOnClick = true
    info.checked = function()
        return DoF.CombatLog and DoF.CombatLog.Frame and DoF.CombatLog.Frame:IsShown()
    end
    info.func = function()
        if DoF.CombatLog and DoF.CombatLog.Toggle then
            DoF.CombatLog:Toggle()
        end
    end
    UIDropDownMenu_AddButton(info, level)

    -- Разделитель
    info = UIDropDownMenu_CreateInfo()
    info.text = ""
    info.isTitle = true
    info.notCheckable = true
    info.disabled = true
    UIDropDownMenu_AddButton(info, level)

    -- Кнопка «Заблокировать фреймы» — действие, не чекбокс
    info = UIDropDownMenu_CreateInfo()
    info.notCheckable = true
    local locked = DoF.db and DoF.db.profile.unitFrames and DoF.db.profile.unitFrames.player.locked
    info.text = locked and DoF.L["ui.minimap.unlock_frames"] or DoF.L["ui.minimap.lock_frames"]
    info.func = function()
        if DoF.UI and DoF.UI.UnitFrames and DoF.UI.UnitFrames.ToggleLock then
            DoF.UI.UnitFrames:ToggleLock()
        end
    end
    UIDropDownMenu_AddButton(info, level)

    -- Закрыть
    info = UIDropDownMenu_CreateInfo()
    info.text = CLOSE or DoF.L["ui.minimap.close"]
    info.notCheckable = true
    info.func = function() CloseDropDownMenus() end
    UIDropDownMenu_AddButton(info, level)
end

local function showMinimapMenu()
    if not minimapMenuFrame then
        minimapMenuFrame = CreateFrame("Frame", "DoF_MinimapDropDown", UIParent, "UIDropDownMenuTemplate")
    end
    UIDropDownMenu_Initialize(minimapMenuFrame, buildMinimapMenu, "MENU")
    ToggleDropDownMenu(1, nil, minimapMenuFrame, "cursor", 0, 0)
end

function DoF.UI:CreateMinimapButton()
    local ok, LDB = pcall(LibStub, "LibDataBroker-1.1")
    if not ok or not LDB then return end
    local ok2, LDBIcon = pcall(LibStub, "LibDBIcon-1.0")
    if not ok2 or not LDBIcon then return end

    -- Создаём Data Broker объект
    local dataBroker = LDB:NewDataObject("DoF", {
        type = "launcher",
        text = "DoF",
        icon = "Interface\\Buttons\\UI-GroupLoot-Dice-Up",
        OnClick = function(_, button)
            if button == "LeftButton" then
                if IsShiftKeyDown() then
                    DoF.UI:ToggleGMPanel()
                else
                    DoF.UI:ToggleCharacterSidebar()
                end
            elseif button == "RightButton" then
                showMinimapMenu()
            end
        end,
        OnTooltipShow = function(tooltip)
            tooltip:AddLine("DoF - Dice of Fate", 1, 0.85, 0)
            tooltip:AddLine(DoF.L["ui.minimap.tooltip_left"], 1, 1, 1)
            tooltip:AddLine(DoF.L["ui.minimap.tooltip_shift_left"], 1, 1, 1)
            tooltip:AddLine(DoF.L["ui.minimap.tooltip_right"], 1, 1, 1)
            if DoF.Sync:IsMaster() then
                tooltip:AddLine(DoF.Utils:Color("A06AF1", DoF.L["ui.minimap.you_are_gm"]))
            elseif DoF.Sync:GetMasterName() then
                tooltip:AddLine(DoF.Locale:Format("ui.minimap.gm_is", DoF.Sync:GetMasterName()), 0.7, 0.7, 0.7)
            end
        end,
    })
    
    -- Инициализируем настройки для иконки
    if not DoF.db.profile.minimap then
        DoF.db.profile.minimap = { hide = false }
    end
    
    -- Регистрируем иконку
    LDBIcon:Register("DoF", dataBroker, DoF.db.profile.minimap)
end
