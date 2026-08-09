-- DoF/UI/MainFrame_GM.lua
-- Функции мастера и GM-панель

local ADDON_NAME, DoF = ...

-- Кэширование глобальных функций
local pairs = pairs
local ipairs = ipairs
local tonumber = tonumber
local math_max = math.max
local UnitGUID = UnitGUID
local UnitName = UnitName
local UnitExists = UnitExists
local UnitIsPlayer = UnitIsPlayer
local C_Timer = C_Timer

DoF.UI = DoF.UI or {}

-- ═══════════════════════════════════════════════════════════
-- ФУНКЦИИ МАСТЕРА
-- ═══════════════════════════════════════════════════════════

function DoF.UI:MasterAddWound()
    local name = DoF.Utils:RequirePlayerTarget()
    if not name then return end
    DoF.Sync:AddWound(name)
end

function DoF.UI:MasterRemoveWound()
    local name = DoF.Utils:RequirePlayerTarget()
    if not name then return end
    DoF.Sync:RemoveWound(name)
end

function DoF.UI:MasterSetSpec()
    local name = DoF.Utils:RequirePlayerTarget()
    if not name then return end
    DoF.Dialogs:ShowSetSpecMenu(name)
end

function DoF.UI:MasterSetLevel()
    local name = DoF.Utils:RequirePlayerTarget()
    if not name then return end
    DoF.Dialogs:ShowSetLevelMenu(name)
end

-- Шаг на ±1 уровень. Отдельно от меню: в игре чаще нужно «поднять всех на
-- один», а не выбирать конкретную ступень из двадцати.
local function StepLevel(delta)
    local name = DoF.Utils:RequirePlayerTarget()
    if not name then return end

    local current = DoF.Sync and DoF.Sync:GetPlayerLevel(name)
    if not current then
        -- Данные приходят с PLAYERDATA; до первой синхронизации шагать не от чего,
        -- иначе мы бы молча выставили уровень от balloon-значения MIN_LEVEL.
        DoF.Utils:Error(DoF.Locale:Format("errors.no_player_data", name))
        return
    end

    local target = current + delta
    if target < DoF.Config.MIN_LEVEL or target > DoF.Config.MAX_LEVEL then
        DoF.Utils:Error(DoF.Locale:Format("errors.level_out_of_range",
            DoF.Config.MIN_LEVEL, DoF.Config.MAX_LEVEL))
        return
    end

    DoF.Sync:SetPlayerLevel(name, target)
end

function DoF.UI:MasterLevelUp()   StepLevel(1)  end
function DoF.UI:MasterLevelDown() StepLevel(-1) end

function DoF.UI:MasterResetStats()
    local name = DoF.Utils:RequirePlayerTarget()
    if not name then return end
    DoF.Sync:ResetPlayerStats(name)
end

function DoF.UI:MasterGiveShield()
    local guid, name = DoF.Utils:GetTargetGUID()
    if not guid then DoF.Utils:Error(DoF.L["errors.select_target"]) return end
    local isPlayer = DoF.Utils:IsTargetPlayer()

    -- Бинарный щит — не нужен ввод количества, сразу применяем
    if isPlayer then
        DoF.Sync:GiveShield(name)
    else
        -- NPC
        if DoF.Units:HasShield(guid) then
            DoF.Utils:Warn(DoF.Locale:Format("ui.gm.shield_already", name))
        else
            DoF.Units:ApplyShield(guid)
            DoF.Utils:Info(DoF.Locale:Format("ui.gm.shield_given", DoF.Utils:Color("FFFFFF", name)))
            if DoF.CombatLog then
                DoF.CombatLog:AddMasterLog(DoF.Locale:Format("ui.gm.shield_given_log", name), "master_action")
            end
        end
    end
end

function DoF.UI:MasterSync()
    if not DoF.Sync then return end

    -- NPC данные (всегда)
    DoF.Sync:BroadcastFullData()

    -- Боевое состояние и эффекты (только во время боя)
    if DoF.TurnSystem and DoF.TurnSystem.phase ~= "idle" then
        DoF.Sync:SendCombatState()
        if DoF.Effects then
            DoF.Effects:BroadcastAllEffects()
        end
    end

    DoF.Utils:Info(DoF.L["ui.gm.full_sync_done"])
end

-- Мастер: +1 энергия выбранному игроку
function DoF.UI:MasterGiveEnergy()
    local name = DoF.Utils:RequirePlayerTarget()
    if not name then return end
    DoF.Sync:GiveEnergy(name, 1)
end

-- Мастер: -1 энергия выбранному игроку
function DoF.UI:MasterTakeEnergy()
    local name = DoF.Utils:RequirePlayerTarget()
    if not name then return end
    DoF.Sync:TakeEnergy(name, 1)
end

-- Мастер: Полное восстановление энергии выбранному игроку
function DoF.UI:MasterRestoreEnergy()
    local name = DoF.Utils:RequirePlayerTarget()
    if not name then return end

    -- В соло режиме или если цель — мы сами, обрабатываем локально
    if name == UnitName("player") then
        DoF.Stats:RestoreEnergy()
    end

    -- Отправляем команду в группу (если есть)
    if IsInGroup() then
        DoF.Sync:Send("RESTOREENERGY", name)
    end

    DoF.Utils:Info(DoF.Locale:Format("ui.gm.energy_restored", DoF.Utils:Color("FFFFFF", name)))
end

-- ═══════════════════════════════════════════════════════════
-- ФУНКЦИИ МАСТЕРА: ЭФФЕКТЫ
-- ═══════════════════════════════════════════════════════════

-- Мастер: Оглушение (на NPC или игрока)
function DoF.UI:MasterApplyStun()
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

-- Мастер: Периодический урон (на NPC или игрока)
function DoF.UI:MasterApplyDot()
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

-- Мастер: Уязвимость (на NPC или игрока)
function DoF.UI:MasterApplyVulnerability()
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

-- Мастер: Ослабление (на NPC или игрока)
function DoF.UI:MasterApplyWeakness()
    local guid, name = DoF.Utils:GetTargetGUID()
    if not guid then
        DoF.Utils:Error(DoF.L["errors.select_target"])
        return
    end

    local isPlayer = DoF.Utils:IsTargetPlayer()
    local targetType = isPlayer and "player" or "npc"
    local targetId = isPlayer and name or guid
    local targetName = isPlayer and name or (DoF.Units:Get(guid) and DoF.Units:Get(guid).name or "NPC")

    DoF.Dialogs:ShowWeaknessDialog(targetType, targetId, targetName)
end

-- Мастер: Бафф игрока
function DoF.UI:MasterApplyBuff()
    local name = DoF.Utils:RequirePlayerTarget()
    if not name then return end
    DoF.Dialogs:ShowMasterBuffDialog(name)
end

-- Мастер: Пурж (снять бафф)
function DoF.UI:MasterPurge()
    local name = DoF.Utils:RequirePlayerTarget()
    if not name then return end
    DoF.Effects:Purge("player", name)
end

-- Мастер: Диспел (снять дебафф) — через меню выбора
function DoF.UI:MasterDispel()
    local name = DoF.Utils:RequirePlayerTarget()
    if not name then return end

    DoF.Dialogs:ShowEffectSelectionMenu("player", name, "debuff", function(effectId, def)
        DoF.Effects:Remove("player", name, effectId)
        -- Если снимаем усталость лечения — сбрасываем внутренние стаки
        if effectId == "healing_fatigue" and DoF.Combat and DoF.Combat.HealingFatigue then
            DoF.Combat.HealingFatigue[name] = nil
        end
        DoF.Utils:Info(DoF.Locale:Format("ui.gm.debuff_removed", def.name, DoF.Utils:Color("FFFFFF", name)))
    end)
end

-- Мастер: Снять ВСЕ эффекты
function DoF.UI:MasterClearAllEffects()
    local guid, name = DoF.Utils:GetTargetGUID()
    if not guid then
        DoF.Utils:Error(DoF.L["errors.select_target"])
        return
    end

    local isPlayer = DoF.Utils:IsTargetPlayer()
    local targetType = isPlayer and "player" or "npc"
    local targetId = isPlayer and name or guid

    DoF.Effects:ClearAll(targetType, targetId)
    -- Сбрасываем внутренние данные усталости лечения
    if targetType == "player" and DoF.Combat and DoF.Combat.HealingFatigue then
        DoF.Combat.HealingFatigue[targetId] = nil
    end
    DoF.Utils:Info(DoF.Locale:Format("ui.gm.all_effects_removed", DoF.Utils:Color("FFFFFF", isPlayer and name or "NPC")))
end

-- ═══════════════════════════════════════════════════════════
-- ДИНАМИЧЕСКАЯ ГЕНЕРАЦИЯ ВКЛАДКИ 4 (ЭФФЕКТЫ)
-- ═══════════════════════════════════════════════════════════

local Tab4Built = false
local Tab4Categories = {}  -- { [catKey] = { expanded = bool, headerBtn, buttons = {} } }

local TAB4_BTN_W = 210
local TAB4_BTN_H = 22
local TAB4_HEADER_H = 22

-- Кнопка эффекта (стандартный UIPanelButtonTemplate — золотой игровой стиль)
local function CreateEffectButton(parent, text, onClick)
    local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    btn:SetSize(TAB4_BTN_W, TAB4_BTN_H)
    btn:SetText(text)
    btn:SetNormalFontObject("GameFontNormalSmall")
    btn:SetHighlightFontObject("GameFontHighlightSmall")
    btn:SetScript("OnClick", onClick)
    return btn
end

-- Заголовок категории — кликабельный divider с текстом и стрелкой [+]/[−]
-- Заголовок категории — статичный (как в Tab2/Tab3):
-- тусклый лейбл по центру + подчёркивающий divider снизу.
local function CreateCategoryHeader(parent, title)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetSize(TAB4_BTN_W, TAB4_HEADER_H)

    frame.label = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    frame.label:SetPoint("TOP", 0, 0)
    frame.label:SetText(title)

    local divider = frame:CreateTexture(nil, "OVERLAY")
    divider:SetTexture("Interface\\Common\\UI-TooltipDivider-Transparent")
    divider:SetPoint("TOP", frame.label, "BOTTOM", 0, -2)
    divider:SetSize(TAB4_BTN_W, 8)
    frame.divider = divider

    frame.UpdateLabel = function() end  -- совместимость со старым API
    return frame
end

-- Обработчик клика по эффекту (мастер применяет на цель)
local function OnEffectButtonClick(effectId)
    local def = DoF.Effects.Definitions[effectId]
    if not def then return end

    local guid, name = DoF.Utils:GetTargetGUID()
    if not guid then
        DoF.Utils:Error(DoF.L["errors.select_target"])
        return
    end

    local isPlayer = DoF.Utils:IsTargetPlayer()
    local targetType = isPlayer and "player" or "npc"
    local targetId = isPlayer and name or guid
    local targetName = isPlayer and name or (DoF.Units:Get(guid) and DoF.Units:Get(guid).name or "NPC")

    -- Эффекты типа vulnerability/weakness имеют свои диалоги
    if effectId:find("^vulnerability_") then
        DoF.Dialogs:ShowVulnerabilityDialog(targetType, targetId, targetName)
    elseif effectId:find("^weakness_") then
        DoF.Dialogs:ShowWeaknessDialog(targetType, targetId, targetName)
    elseif effectId:find("^empower_") or effectId:find("^fortify_") then
        -- Баффы: мастер задаёт значение и длительность через общий диалог
        DoF.Dialogs:ShowMasterEffectDialog(effectId, targetType, targetId)
    else
        -- Общий диалог для остальных (stun, dot_master, bleeding и т.д.)
        DoF.Dialogs:ShowMasterEffectDialog(effectId, targetType, targetId)
    end
end

-- Обработчик клика по пассивке NPC
local function OnPassiveButtonClick(passiveId)
    local guid, name = DoF.Utils:GetTargetGUID()
    if not guid or DoF.Utils:IsTargetPlayer() then
        DoF.Utils:Error(DoF.L["errors.select_npc"])
        return
    end

    local data = DoF.Units:Get(guid)
    if not data then
        DoF.Utils:Error(DoF.L["errors.npc_hp_not_set"])
        return
    end

    local pdef = DoF.Passives.Definitions[passiveId]
    if not pdef then return end

    local existing = DoF.Passives:Get(guid, passiveId)
    if existing then
        if IsShiftKeyDown() then
            -- Shift+клик = редактировать существующую пассивку
            DoF.Dialogs:ShowPassiveConfigDialog(passiveId, guid, existing)
        else
            -- Обычный клик = снять пассивку
            DoF.Passives:Remove(guid, passiveId)
            DoF.Utils:Info(DoF.Locale:Format("ui.gm.passive_removed", DoF.Utils:Color("FFD700", pdef.name), data.name or "NPC"))

            if DoF.Sync and IsInGroup() then
                DoF.Sync:BroadcastUnit(guid, data)
            end
            DoF.Events:Fire("UNIT_CREATED", guid, data)
        end
    else
        -- Открыть диалог настройки пассивки
        DoF.Dialogs:ShowPassiveConfigDialog(passiveId, guid)
    end
end

-- Определяем категории и их содержимое
local function GetTab4Categories()
    local categories = {}

    -- 1. Эффекты (баффы + дебаффы в одной категории)
    local effects = {
        {id = "stun", name = DoF.L["effects.stun.name"], color = {1, 1, 0}, type = "effect"},
        {id = "dot_master", name = DoF.L["ui.common.dot"], color = {0.8, 0.1, 0.1}, type = "effect"},
        {id = "_weakness", name = DoF.L["ui.gm.weakness_dialog"], color = {0.6, 0.4, 0.4}, type = "dialog_weakness"},
        {id = "_vulnerability", name = DoF.L["ui.gm.vulnerability_dialog"], color = {0.6, 0.4, 0.8}, type = "dialog_vulnerability"},
        {id = "_buff", name = DoF.L["ui.gm.buff_dialog"], color = {0.4, 1, 0.6}, type = "dialog_buff"},
    }
    categories[1] = {key = "effects", title = DoF.L["ui.gm.cat_effects"], items = effects, expanded = true}

    -- 3. Пассивки NPC
    if DoF.Passives and DoF.Passives.Definitions then
        local passives = {}
        local passiveOrder = {"thorns", "npc_counterattack", "poisonous", "spell_reflection", "death_explosion", "regeneration", "evasion", "resistance", "adaptation", "berserk"}
        for _, pid in ipairs(passiveOrder) do
            local pdef = DoF.Passives.Definitions[pid]
            if pdef then
                table.insert(passives, {id = pid, name = pdef.name, color = pdef.color, type = "passive"})
            end
        end
        categories[2] = {key = "passives", title = DoF.L["ui.gm.cat_passives"], items = passives, expanded = false, twoColumns = true}
    end

    -- 3. Утилиты
    local utils = {
        {id = "purge", name = DoF.L["ui.gm.util_purge"], type = "util"},
        {id = "dispel", name = DoF.L["ui.gm.util_dispel"], type = "util"},
        {id = "clear_all", name = DoF.L["ui.gm.util_clear_all"], type = "util"},
    }
    categories[3] = {key = "utils", title = DoF.L["ui.gm.cat_utils"], items = utils, expanded = true}

    return categories
end

-- Построить Tab4
-- Контент кладётся прямо в TabContent4 — скролл обеспечивает общий
-- DoF_GMPanel.Scroll из Frames.xml, отдельный ScrollFrame здесь не нужен.
function DoF.UI:BuildTab4()
    if Tab4Built then return end
    Tab4Built = true

    local parent = DoF_GMPanel_TabContent4
    if not parent then return end

    -- Создаём элементы категорий прямо внутри parent
    local catDefs = GetTab4Categories()

    for _, catDef in ipairs(catDefs) do
        local cat = {
            buttons = {},
            twoColumns = catDef.twoColumns or false,
        }

        cat.headerBtn = CreateCategoryHeader(parent, catDef.title)

        for _, item in ipairs(catDef.items) do
            local text = item.name
            local onClick

            if item.type == "effect" then
                local eid = item.id
                onClick = function() OnEffectButtonClick(eid) end
            elseif item.type == "dialog_buff" then
                onClick = function()
                    local guid, name = DoF.Utils:GetTargetGUID()
                    if not guid or not DoF.Utils:IsTargetPlayer() then
                        DoF.Utils:Error(DoF.L["errors.select_player"])
                        return
                    end
                    DoF.Dialogs:ShowMasterBuffDialog(name)
                end
            elseif item.type == "dialog_weakness" then
                onClick = function()
                    local guid, name = DoF.Utils:GetTargetGUID()
                    if not guid then DoF.Utils:Error(DoF.L["errors.select_target"]); return end
                    local isPlayer = DoF.Utils:IsTargetPlayer()
                    local targetType = isPlayer and "player" or "npc"
                    local targetId = isPlayer and name or guid
                    local targetName = isPlayer and name or (DoF.Units:Get(guid) and DoF.Units:Get(guid).name or "NPC")
                    DoF.Dialogs:ShowWeaknessDialog(targetType, targetId, targetName)
                end
            elseif item.type == "dialog_vulnerability" then
                onClick = function()
                    local guid, name = DoF.Utils:GetTargetGUID()
                    if not guid then DoF.Utils:Error(DoF.L["errors.select_target"]); return end
                    local isPlayer = DoF.Utils:IsTargetPlayer()
                    local targetType = isPlayer and "player" or "npc"
                    local targetId = isPlayer and name or guid
                    local targetName = isPlayer and name or (DoF.Units:Get(guid) and DoF.Units:Get(guid).name or "NPC")
                    DoF.Dialogs:ShowVulnerabilityDialog(targetType, targetId, targetName)
                end
            elseif item.type == "passive" then
                local pid = item.id
                onClick = function() OnPassiveButtonClick(pid) end
            elseif item.type == "util" then
                local uid = item.id
                onClick = function()
                    if uid == "purge" then DoF.UI:MasterPurge()
                    elseif uid == "dispel" then DoF.UI:MasterDispel()
                    elseif uid == "clear_all" then DoF.UI:MasterClearAllEffects()
                    end
                end
            end

            local btn = CreateEffectButton(parent, text, onClick)
            table.insert(cat.buttons, btn)
        end

        Tab4Categories[catDef.key] = cat
    end

    self:LayoutTab4()
end

-- Разложить элементы Tab4 (плоская раскладка, всё всегда видно;
-- скролл обеспечивает общий DoF_GMPanel.Scroll).
function DoF.UI:LayoutTab4()
    local parent = DoF_GMPanel_TabContent4
    if not parent then return end

    local y = 4
    local catOrder = {"effects", "passives", "utils"}

    for _, catKey in ipairs(catOrder) do
        local cat = Tab4Categories[catKey]
        if cat then
            cat.headerBtn:ClearAllPoints()
            cat.headerBtn:SetPoint("TOP", parent, "TOP", 0, -y)
            cat.headerBtn:Show()
            y = y + TAB4_HEADER_H + 6

            if cat.twoColumns then
                local colW = (TAB4_BTN_W - 4) / 2
                local halfGap = (colW + 4) / 2
                for i, btn in ipairs(cat.buttons) do
                    btn:SetWidth(colW)
                    btn:ClearAllPoints()
                    local col = (i - 1) % 2
                    local row = math.floor((i - 1) / 2)
                    local x = (col == 0) and -halfGap or halfGap
                    btn:SetPoint("TOP", parent, "TOP", x, -(y + row * (TAB4_BTN_H + 2)))
                    btn:Show()
                end
                local totalRows = math.ceil(#cat.buttons / 2)
                y = y + totalRows * (TAB4_BTN_H + 2)
            else
                for _, btn in ipairs(cat.buttons) do
                    btn:SetWidth(TAB4_BTN_W)
                    btn:ClearAllPoints()
                    btn:SetPoint("TOP", parent, "TOP", 0, -y)
                    btn:Show()
                    y = y + TAB4_BTN_H + 2
                end
            end

            y = y + 10
        end
    end

    parent:SetHeight(math_max(1, y))

    if DoF_GMPanel and DoF_GMPanel.currentTab == 4 and DoF.UI.UpdateGMPanelSize then
        DoF.UI:UpdateGMPanelSize()
    end
end

-- ═══════════════════════════════════════════════════════════
-- ОБНОВЛЕНИЕ КНОПОК ПОШАГОВОГО БОЯ В GM ПАНЕЛИ
-- ═══════════════════════════════════════════════════════════

function DoF.UI:UpdateGMCombatButtons()
    local startBtn = DoF_GMPanel_StartCombatBtn
    local skipBtn = DoF_GMPanel_SkipTurnBtn
    local npcBtn = DoF_GMPanel_NPCTurnBtn
    local freeBtn = DoF_GMPanel_FreeActionBtn
    local timerFrame = DoF_GMPanel_TimerFrame
    local excludeBtn = DoF_GMPanel_ExcludeMasterBtn
    local modeFreeCheckBtn = DoF_GMPanel_ModeFreeCheckBtn
    local modeQueueCheckBtn = DoF_GMPanel_ModeQueueCheckBtn
    local useTimerCheckBtn = DoF_GMPanel_UseTimerCheckBtn
    local tab3 = DoF_GMPanel_TabContent3
    local modeFreeLabel = tab3 and tab3.modeFreeLabel
    local modeQueueLabel = tab3 and tab3.modeQueueLabel
    local useTimerLabel = tab3 and tab3.useTimerLabel
    local instantDefenseCheckBtn = DoF_GMPanel_InstantDefenseCheckBtn
    local instantDefenseLabel = tab3 and tab3.instantDefenseLabel
    local utilitiesLabel = tab3 and tab3.utilitiesLabel
    local clearAllBtn = DoF_GMPanel_ClearAllBtn
    local syncBtn = DoF_GMPanel_SyncBtn
    local versionCheckBtn = DoF_GMPanel_VersionCheckBtn
    local debugSecurityBtn = DoF_GMPanel_DebugSecurityBtn

    if not startBtn then return end

    local ts = DoF.TurnSystem
    local isActive = ts and ts:IsActive()

    -- Меняем высоту TabContent3, чтобы окно подстраивалось через UpdateGMPanelSize
    if tab3 then
        if isActive then
            tab3:SetHeight(238)  -- сжатая: только управление боем + утилиты
        else
            tab3:SetHeight(362)  -- полная: настройки + управление + утилиты
        end
    end

    if isActive then
        -- Бой активен
        startBtn:SetText(DoF.L["ui.gm.end_combat"])

        -- Скрываем контролы настроек боя
        if timerFrame then timerFrame:Hide() end
        if excludeBtn then excludeBtn:Hide() end
        if modeFreeCheckBtn then modeFreeCheckBtn:Hide() end
        if modeQueueCheckBtn then modeQueueCheckBtn:Hide() end
        if useTimerCheckBtn then useTimerCheckBtn:Hide() end
        if instantDefenseCheckBtn then instantDefenseCheckBtn:Hide() end
        if modeFreeLabel then modeFreeLabel:Hide() end
        if modeQueueLabel then modeQueueLabel:Hide() end
        if useTimerLabel then useTimerLabel:Hide() end
        if instantDefenseLabel then instantDefenseLabel:Hide() end

        -- Сжатая раскладка: управление боем сверху, утилиты ниже
        if startBtn then
            startBtn:ClearAllPoints()
            startBtn:SetPoint("TOP", 0, -16)
        end
        if skipBtn then
            skipBtn:ClearAllPoints()
            skipBtn:SetPoint("TOP", -46, -48)
        end
        if npcBtn then
            npcBtn:ClearAllPoints()
            npcBtn:SetPoint("TOP", 46, -48)
        end
        if freeBtn then
            freeBtn:ClearAllPoints()
            freeBtn:SetPoint("TOP", 0, -74)
        end
        if utilitiesLabel then
            utilitiesLabel:ClearAllPoints()
            utilitiesLabel:SetPoint("TOP", 0, -110)
        end
        if clearAllBtn then
            clearAllBtn:ClearAllPoints()
            clearAllBtn:SetPoint("TOP", 0, -134)
        end
        if syncBtn then
            syncBtn:ClearAllPoints()
            syncBtn:SetPoint("TOP", 0, -160)
        end
        if versionCheckBtn then
            versionCheckBtn:ClearAllPoints()
            versionCheckBtn:SetPoint("TOP", 0, -186)
        end
        if debugSecurityBtn then
            debugSecurityBtn:ClearAllPoints()
            debugSecurityBtn:SetPoint("TOP", 0, -212)
        end

        -- Кнопка пропуска
        if skipBtn then
            if ts.phase == "players" then
                skipBtn:Enable()
                skipBtn:SetAlpha(1)
            else
                skipBtn:Disable()
                skipBtn:SetAlpha(0.5)
            end
        end

        -- Кнопка фазы NPC (всегда активна во время боя)
        if npcBtn then
            npcBtn:Enable()
            npcBtn:SetAlpha(1)
            if ts.phase == "npc" then
                npcBtn:SetText(DoF.L["ui.queue.phase_players"])
            else
                npcBtn:SetText(DoF.L["ui.queue.phase_enemy"])
            end
        end

        -- Кнопка внеочередного хода
        if freeBtn then
            if ts.phase == "players" then
                freeBtn:Enable()
                freeBtn:SetAlpha(1)
            else
                freeBtn:Disable()
                freeBtn:SetAlpha(0.5)
            end
        end
    else
        -- Бой не активен
        startBtn:SetText(DoF.L["ui.gm.start_combat"])

        -- Показываем контролы настроек боя
        if excludeBtn then excludeBtn:Show() end
        if modeFreeCheckBtn then modeFreeCheckBtn:Show() end
        if modeQueueCheckBtn then modeQueueCheckBtn:Show() end
        if useTimerCheckBtn then useTimerCheckBtn:Show() end
        if instantDefenseCheckBtn then instantDefenseCheckBtn:Show() end
        if modeFreeLabel then modeFreeLabel:Show() end
        if modeQueueLabel then modeQueueLabel:Show() end
        if useTimerLabel then useTimerLabel:Show() end
        if instantDefenseLabel then instantDefenseLabel:Show() end

        -- Полная раскладка по XML (настройки + управление + утилиты)
        if startBtn then
            startBtn:ClearAllPoints()
            startBtn:SetPoint("TOP", 34, -168)
        end
        if timerFrame then
            timerFrame:ClearAllPoints()
            timerFrame:SetPoint("TOP", -60, -168)
        end
        if skipBtn then
            skipBtn:ClearAllPoints()
            skipBtn:SetPoint("TOP", -46, -196)
        end
        if npcBtn then
            npcBtn:ClearAllPoints()
            npcBtn:SetPoint("TOP", 46, -196)
        end
        if freeBtn then
            freeBtn:ClearAllPoints()
            freeBtn:SetPoint("TOP", 0, -222)
        end
        if utilitiesLabel then
            utilitiesLabel:ClearAllPoints()
            utilitiesLabel:SetPoint("TOP", 0, -254)
        end
        if clearAllBtn then
            clearAllBtn:ClearAllPoints()
            clearAllBtn:SetPoint("TOP", 0, -278)
        end
        if syncBtn then
            syncBtn:ClearAllPoints()
            syncBtn:SetPoint("TOP", 0, -304)
        end
        if versionCheckBtn then
            versionCheckBtn:ClearAllPoints()
            versionCheckBtn:SetPoint("TOP", 0, -330)
        end
        if debugSecurityBtn then
            debugSecurityBtn:ClearAllPoints()
            debugSecurityBtn:SetPoint("TOP", 0, -356)
        end

        -- Синхронизируем чекбоксы с текущим состоянием TurnSystem
        if modeFreeCheckBtn and modeQueueCheckBtn then
            if ts.mode == "free" then
                modeFreeCheckBtn:SetChecked(true)
                modeQueueCheckBtn:SetChecked(false)
            else
                modeFreeCheckBtn:SetChecked(false)
                modeQueueCheckBtn:SetChecked(true)
            end
        end

        if useTimerCheckBtn then
            useTimerCheckBtn:SetChecked(ts.useTimer)
        end

        -- TimerFrame показываем только если чекбокс таймера включен
        if timerFrame and useTimerCheckBtn then
            if useTimerCheckBtn:GetChecked() then
                timerFrame:Show()
            else
                timerFrame:Hide()
            end
        end

        -- Деактивируем кнопки
        if skipBtn then
            skipBtn:Disable()
            skipBtn:SetAlpha(0.5)
        end
        if npcBtn then
            npcBtn:SetText(DoF.L["ui.queue.phase_enemy"])
            npcBtn:Disable()
            npcBtn:SetAlpha(0.5)
        end
        if freeBtn then
            freeBtn:Disable()
            freeBtn:SetAlpha(0.5)
        end
    end

    -- Обновить высоту окна + видимость скроллбара (если Tab3 активен)
    if DoF_GMPanel and DoF_GMPanel.currentTab == 3 and self.UpdateGMPanelSize then
        self:UpdateGMPanelSize()
    end
end

function DoF.UI:ToggleMasterFrame()
    self:ToggleGMPanel()
    self:UpdateGMCombatButtons()
    if self.UpdateGMPanelSize then self:UpdateGMPanelSize() end
end

-- ═══════════════════════════════════════════════════════════
-- СКРЫТИЕ/ПОКАЗ ЭЛЕМЕНТОВ ГМ-ПАНЕЛИ ДЛЯ ПОМОЩНИКА
-- ═══════════════════════════════════════════════════════════

-- Хелпер: включить/выключить кнопку (серая + неактивная вместо скрытия)
local function SetButtonEnabled(name, enabled)
    local btn = _G[name]
    if not btn then return end
    btn:Show()
    if enabled then
        btn:Enable()
        btn:SetAlpha(1)
    else
        btn:Disable()
        btn:SetAlpha(0.4)
    end
end

-- Хелпер: включить/выключить вкладку
local function SetTabEnabled(tabIndex, enabled)
    local tab = _G["DoF_GMPanel_Tab" .. tabIndex]
    if not tab then return end
    tab:Show()
    if enabled then
        tab:Enable()
        tab:SetAlpha(1)
    else
        tab:Disable()
        tab:SetAlpha(0.5)
    end
end

-- Алиасы перенесены в Core/Aliases.lua
