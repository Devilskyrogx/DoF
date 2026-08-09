-- DoF/Data/Passives.lua
-- Пассивные способности NPC

local ADDON_NAME, DoF = ...

-- Кэширование глобальных функций
local pairs = pairs
local ipairs = ipairs
local tonumber = tonumber
local tostring = tostring
local string_format = string.format
local string_match = string.match
local math_max = math.max
local math_min = math.min
local math_floor = math.floor
local table_insert = table.insert
local table_concat = table.concat

DoF.Passives = {}

-- ═══════════════════════════════════════════════════════════
-- ОПРЕДЕЛЕНИЯ ПАССИВОК
-- ═══════════════════════════════════════════════════════════

DoF.Passives.Definitions = {
    -- ─── РЕАКТИВНЫЕ ───────────────────────────────────────
    thorns = {
        id = "thorns",
        name = DoF.L["passives.thorns.name"],
        icon = "Interface\\Icons\\Spell_Nature_Thorns",
        category = "reactive",
        description = DoF.L["passives.thorns.desc"],
        color = {0.8, 0.4, 0.1},
        -- Поля конфигурации: mode (guaranteed/chance), chance, damageMin, damageMax, threshold, instantDamage
        fields = {
            { key = "mode", name = DoF.L["passives.thorns.field.mode"], type = "dropdown", options = {"guaranteed", "chance"}, default = "guaranteed" },
            { key = "chance", name = DoF.L["passives.thorns.field.chance"], type = "number", min = 1, max = 100, default = 30, showIf = "chance" },
            { key = "damageMin", name = DoF.L["passives.thorns.field.damageMin"], type = "number", min = 1, max = 50, default = 1 },
            { key = "damageMax", name = DoF.L["passives.thorns.field.damageMax"], type = "number", min = 1, max = 50, default = 3 },
            { key = "threshold", name = DoF.L["passives.thorns.field.threshold"], type = "number", min = 1, max = 30, default = 10 },
            { key = "instantDamage", name = DoF.L["passives.thorns.field.instantDamage"], type = "checkbox", default = false },
        },
    },

    npc_counterattack = {
        id = "npc_counterattack",
        name = DoF.L["passives.npc_counterattack.name"],
        icon = "Interface\\Icons\\Ability_Warrior_Revenge",
        category = "reactive",
        description = DoF.L["passives.npc_counterattack.desc"],
        color = {0.9, 0.3, 0.2},
        fields = {
            { key = "chance", name = DoF.L["passives.npc_counterattack.field.chance"], type = "number", min = 1, max = 100, default = 20 },
            { key = "damageMin", name = DoF.L["passives.npc_counterattack.field.damageMin"], type = "number", min = 1, max = 50, default = 1 },
            { key = "damageMax", name = DoF.L["passives.npc_counterattack.field.damageMax"], type = "number", min = 1, max = 50, default = 5 },
            { key = "threshold", name = DoF.L["passives.npc_counterattack.field.threshold"], type = "number", min = 1, max = 30, default = 12 },
            { key = "defenseStat", name = DoF.L["passives.npc_counterattack.field.defenseStat"], type = "dropdown", options = {"Fortitude", "Reflex", "Will", "Hybrid"}, default = "Hybrid" },
        },
    },

    poisonous = {
        id = "poisonous",
        name = DoF.L["passives.poisonous.name"],
        icon = "Interface\\Icons\\Ability_Creature_Poison_03",
        category = "reactive",
        description = DoF.L["passives.poisonous.desc"],
        color = {0.2, 0.8, 0.1},
        fields = {
            { key = "chance", name = DoF.L["passives.poisonous.field.chance"], type = "number", min = 1, max = 100, default = 25 },
            { key = "dotValue", name = DoF.L["passives.poisonous.field.dotValue"], type = "number", min = 1, max = 10, default = 2 },
            { key = "dotDuration", name = DoF.L["passives.poisonous.field.dotDuration"], type = "number", min = 1, max = 10, default = 3 },
            { key = "instantDamage", name = DoF.L["passives.poisonous.field.instantDamage"], type = "checkbox", default = false },
        },
    },

    spell_reflection = {
        id = "spell_reflection",
        name = DoF.L["passives.spell_reflection.name"],
        icon = "Interface\\Icons\\Ability_Warrior_ShieldReflection",
        category = "reactive",
        description = DoF.L["passives.spell_reflection.desc"],
        color = {0.4, 0.6, 1.0},
        fields = {
            { key = "chance", name = DoF.L["passives.spell_reflection.field.chance"], type = "number", min = 1, max = 100, default = 20 },
        },
    },

    death_explosion = {
        id = "death_explosion",
        name = DoF.L["passives.death_explosion.name"],
        icon = "Interface\\Icons\\Spell_Fire_SelfDestruct",
        category = "reactive",
        description = DoF.L["passives.death_explosion.desc"],
        color = {1.0, 0.5, 0.0},
        fields = {
            { key = "damageMin", name = DoF.L["passives.death_explosion.field.damageMin"], type = "number", min = 1, max = 50, default = 2 },
            { key = "damageMax", name = DoF.L["passives.death_explosion.field.damageMax"], type = "number", min = 1, max = 50, default = 5 },
        },
    },

    -- ─── САМОБАФФЫ ────────────────────────────────────────
    regeneration = {
        id = "regeneration",
        name = DoF.L["passives.regeneration.name"],
        icon = "Interface\\Icons\\Spell_Nature_Rejuvenation",
        category = "self",
        description = DoF.L["passives.regeneration.desc"],
        color = {0.1, 0.9, 0.3},
        fields = {
            { key = "value", name = DoF.L["passives.regeneration.field.value"], type = "number", min = 1, max = 20, default = 2 },
        },
    },

    evasion = {
        id = "evasion",
        name = DoF.L["passives.evasion.name"],
        icon = "Interface\\Icons\\Ability_Rogue_Evasion",
        category = "self",
        description = DoF.L["passives.evasion.desc"],
        color = {0.7, 0.7, 0.7},
        fields = {
            { key = "chance", name = DoF.L["passives.evasion.field.chance"], type = "number", min = 1, max = 50, default = 15 },
        },
    },

    resistance = {
        id = "resistance",
        name = DoF.L["passives.resistance.name"],
        icon = "Interface\\Icons\\Spell_Holy_SealOfProtection",
        category = "self",
        description = DoF.L["passives.resistance.desc"],
        color = {0.8, 0.7, 0.2},
        fields = {
            { key = "value", name = DoF.L["passives.resistance.field.value"], type = "number", min = 1, max = 10, default = 2 },
        },
    },

    adaptation = {
        id = "adaptation",
        name = DoF.L["passives.adaptation.name"],
        icon = "Interface\\Icons\\Spell_Nature_WispHeal",
        category = "self",
        description = DoF.L["passives.adaptation.desc"],
        color = {0.5, 0.8, 0.9},
        fields = {
            { key = "value", name = DoF.L["passives.adaptation.field.value"], type = "number", min = 1, max = 10, default = 2 },
        },
    },

    berserk = {
        id = "berserk",
        name = DoF.L["passives.berserk.name"],
        icon = "Interface\\Icons\\Ability_Warrior_InnerRage",
        category = "self",
        description = DoF.L["passives.berserk.desc"],
        color = {0.9, 0.1, 0.1},
        fields = {
            { key = "damageMin", name = DoF.L["passives.berserk.field.damageMin"], type = "number", min = 1, max = 50, default = 3 },
            { key = "damageMax", name = DoF.L["passives.berserk.field.damageMax"], type = "number", min = 1, max = 50, default = 6 },
            { key = "threshold", name = DoF.L["passives.berserk.field.threshold"], type = "number", min = 1, max = 30, default = 14 },
            { key = "stunDuration", name = DoF.L["passives.berserk.field.stunDuration"], type = "number", min = 1, max = 5, default = 1 },
        },
    },
}

-- Порядок отображения в UI
DoF.Passives.DisplayOrder = {
    "thorns", "npc_counterattack", "poisonous", "spell_reflection", "death_explosion",
    "regeneration", "evasion", "resistance", "adaptation", "berserk",
}

-- ═══════════════════════════════════════════════════════════
-- РАНТАЙМ СОСТОЯНИЕ
-- ═══════════════════════════════════════════════════════════

-- Адаптация хранится в unitData[guid].adaptTracker = { lastStat = "Strength", count = 0 }
-- и синхронизируется через команду ADAPT

-- ═══════════════════════════════════════════════════════════
-- ГЕТТЕРЫ
-- ═══════════════════════════════════════════════════════════

function DoF.Passives:Has(guid, passiveId)
    local data = DoF.Units:Get(guid)
    if not data or not data.passives then return false end
    return data.passives[passiveId] ~= nil
end

function DoF.Passives:Get(guid, passiveId)
    local data = DoF.Units:Get(guid)
    if not data or not data.passives then return nil end
    return data.passives[passiveId]
end

function DoF.Passives:GetAll(guid)
    local data = DoF.Units:Get(guid)
    if not data then return {} end
    return data.passives or {}
end

-- ═══════════════════════════════════════════════════════════
-- СЕТТЕРЫ
-- ═══════════════════════════════════════════════════════════

function DoF.Passives:Set(guid, passives)
    local data = DoF.Units:Get(guid)
    if not data then return end
    data.passives = passives
end

function DoF.Passives:Add(guid, passiveId, config)
    local data = DoF.Units:Get(guid)
    if not data then return end
    if not data.passives then data.passives = {} end
    data.passives[passiveId] = config
end

function DoF.Passives:Remove(guid, passiveId)
    local data = DoF.Units:Get(guid)
    if not data or not data.passives then return end
    data.passives[passiveId] = nil
    if not next(data.passives) then
        data.passives = nil
    end
end

-- Глубокая копия таблицы пассивок (для шаблонов)
function DoF.Passives:CopyPassives(passives)
    if not passives then return nil end
    local copy = {}
    for id, cfg in pairs(passives) do
        local cfgCopy = {}
        for k, v in pairs(cfg) do
            cfgCopy[k] = v
        end
        copy[id] = cfgCopy
    end
    return copy
end

-- ═══════════════════════════════════════════════════════════
-- СЕРИАЛИЗАЦИЯ (для синхронизации)
-- ═══════════════════════════════════════════════════════════

-- Префиксы для кодирования полей:
-- m = mode (0=guaranteed, 1=chance)
-- c = chance
-- mn = damageMin, mx = damageMax
-- t = threshold
-- dv = dotValue, dd = dotDuration
-- sd = stunDuration
-- ds = defenseStat (0=Fort, 1=Reflex, 2=Will, 3=Hybrid)
-- v = value

local DEFENSE_STAT_TO_NUM = {
    Fortitude = 0, Reflex = 1, Will = 2, Hybrid = 3,
}
local NUM_TO_DEFENSE_STAT = {
    [0] = "Fortitude", [1] = "Reflex", [2] = "Will", [3] = "Hybrid",
}

function DoF.Passives:Encode(passives, adaptTracker)
    if (not passives or not next(passives)) and not adaptTracker then return "" end
    local parts = {}
    if passives then
        for id, cfg in pairs(passives) do
            local vals = {}
            if cfg.mode then
                table_insert(vals, "m" .. (cfg.mode == "guaranteed" and "0" or "1"))
            end
            if cfg.chance then table_insert(vals, "c" .. cfg.chance) end
            if cfg.damageMin then table_insert(vals, "mn" .. cfg.damageMin) end
            if cfg.damageMax then table_insert(vals, "mx" .. cfg.damageMax) end
            if cfg.threshold then table_insert(vals, "t" .. cfg.threshold) end
            if cfg.dotValue then table_insert(vals, "dv" .. cfg.dotValue) end
            if cfg.dotDuration then table_insert(vals, "dd" .. cfg.dotDuration) end
            if cfg.stunDuration then table_insert(vals, "sd" .. cfg.stunDuration) end
            if cfg.defenseStat then
                table_insert(vals, "ds" .. (DEFENSE_STAT_TO_NUM[cfg.defenseStat] or 3))
            end
            if cfg.value then table_insert(vals, "v" .. cfg.value) end
            if cfg.instantDamage then table_insert(vals, "id1") end
            if cfg.unpurgeable then table_insert(vals, "up1") end
            table_insert(parts, id .. "=" .. table_concat(vals, ","))
        end
    end
    -- Кодируем трекер адаптации как специальную запись _at=stat,count
    if adaptTracker and adaptTracker.lastStat and adaptTracker.count and adaptTracker.count > 0 then
        table_insert(parts, "_at=" .. adaptTracker.lastStat .. "," .. adaptTracker.count)
    end
    return table_concat(parts, "~")
end

-- Возвращает passives, adaptTracker
function DoF.Passives:Decode(str)
    if not str or str == "" then return nil, nil end
    local passives = {}
    local adaptTracker = nil
    for entry in str:gmatch("[^~]+") do
        local id, valsStr = entry:match("^([^=]+)=(.*)")
        if id == "_at" then
            -- Трекер адаптации: _at=Strength,2
            local stat, count = valsStr:match("^([^,]+),(%d+)")
            if stat and count then
                adaptTracker = { lastStat = stat, count = tonumber(count) }
            end
        elseif id and self.Definitions[id] then
            local cfg = {}
            for val in valsStr:gmatch("[^,]+") do
                local prefix2 = val:sub(1, 2)
                local prefix1 = val:sub(1, 1)
                if prefix2 == "mn" then
                    cfg.damageMin = tonumber(val:sub(3))
                elseif prefix2 == "mx" then
                    cfg.damageMax = tonumber(val:sub(3))
                elseif prefix2 == "dv" then
                    cfg.dotValue = tonumber(val:sub(3))
                elseif prefix2 == "dd" then
                    cfg.dotDuration = tonumber(val:sub(3))
                elseif prefix2 == "sd" then
                    cfg.stunDuration = tonumber(val:sub(3))
                elseif prefix2 == "ds" then
                    cfg.defenseStat = NUM_TO_DEFENSE_STAT[tonumber(val:sub(3))] or "Hybrid"
                elseif prefix1 == "m" then
                    cfg.mode = (val:sub(2) == "0") and "guaranteed" or "chance"
                elseif prefix1 == "c" then
                    cfg.chance = tonumber(val:sub(2))
                elseif prefix1 == "t" then
                    cfg.threshold = tonumber(val:sub(2))
                elseif prefix2 == "id" then
                    cfg.instantDamage = (val:sub(3) == "1")
                elseif prefix2 == "up" then
                    cfg.unpurgeable = (val:sub(3) == "1")
                elseif prefix1 == "v" then
                    cfg.value = tonumber(val:sub(2))
                end
            end
            passives[id] = cfg
        end
    end
    local result = next(passives) and passives or nil
    return result, adaptTracker
end

-- ═══════════════════════════════════════════════════════════
-- ОБРАБОТКА ПАССИВОК ЗА РАУНД
-- ═══════════════════════════════════════════════════════════

-- Вызывается в начале каждого раунда (только мастером)
function DoF.Passives:ProcessRoundPassives()
    if not DoF.Sync:IsMaster() then return end

    for guid, data in pairs(DoF.db.global.unitData) do
        if data and data.hp and data.hp > 0 and data.passives then
            -- Регенерация
            if data.passives.regeneration then
                local regenValue = data.passives.regeneration.value or 0
                if regenValue > 0 and data.hp < (data.maxHp or 0) then
                    local newHP = math_min(data.maxHp, data.hp + regenValue)
                    local healed = newHP - data.hp
                    if healed > 0 then
                        DoF.Units:ModifyHP(guid, newHP)
                        DoF.Sync:BroadcastCombatLog(string_format(
                            DoF.L["passives.msg.regenerates"],
                            DoF.Utils:Color("FFCC00", data.name),
                            DoF.Utils:Color("66FF66", healed),
                            newHP, data.maxHp))
                    end
                end
            end
        end
    end
end

-- ═══════════════════════════════════════════════════════════
-- АДАПТАЦИЯ
-- ═══════════════════════════════════════════════════════════

function DoF.Passives:TrackAdaptation(guid, attackStat)
    local adaptData = self:Get(guid, "adaptation")
    if not adaptData then return end

    local data = DoF.Units:Get(guid)
    if not data then return end

    if not data.adaptTracker then
        data.adaptTracker = { lastStat = nil, count = 0 }
    end
    local tracker = data.adaptTracker

    if tracker.lastStat == attackStat then
        tracker.count = tracker.count + 1
    else
        tracker.lastStat = attackStat
        tracker.count = 1
    end

    -- Уведомление при достижении порога
    if tracker.count == 2 then
        local npcName = data.name or "NPC"
        local defenseStat = DoF.Config.AttackVsDefense[attackStat]
        DoF.Sync:BroadcastCombatLog(string_format(
            DoF.L["passives.msg.adapts"],
            DoF.Utils:Color("66CCFF", npcName),
            DoF.Utils:Color("FFCC00", DoF.Config.StatNames[attackStat] or attackStat),
            adaptData.value or 2,
            DoF.Config.StatNames[defenseStat] or defenseStat))
    end

    -- Синхронизация трекера всем игрокам
    if DoF.Sync then
        DoF.Sync:Send("ADAPT", guid .. ";" .. attackStat .. ";" .. tracker.count)
    end
end

function DoF.Passives:GetAdaptationBonus(guid, defenseStat)
    local adaptData = self:Get(guid, "adaptation")
    if not adaptData then return 0 end

    local data = DoF.Units:Get(guid)
    if not data or not data.adaptTracker then return 0 end

    local tracker = data.adaptTracker
    if not tracker.lastStat or tracker.count < 2 then return 0 end

    -- Проверяем, что стат атаки соответствует стату защиты
    local expectedDefense = DoF.Config.AttackVsDefense[tracker.lastStat]
    if expectedDefense == defenseStat then
        return adaptData.value or 2
    end
    return 0
end

-- Очистка трекера (конец боя)
function DoF.Passives:ClearAdaptationTracker()
    for guid, data in pairs(DoF.db.global.unitData) do
        if data then
            data.adaptTracker = nil
        end
    end
end

-- ═══════════════════════════════════════════════════════════
-- ВЗРЫВ ПРИ СМЕРТИ
-- ═══════════════════════════════════════════════════════════

local deathExplosionFrame = nil

function DoF.Passives:ShowDeathExplosionDialog(npcName, damageMin, damageMax)
    if not deathExplosionFrame then
        local f = CreateFrame("Frame", "DoF_DeathExplosionDialog", UIParent, "BackdropTemplate")
        f:SetSize(260, 300)
        f:SetPoint("CENTER")
        f:SetFrameStrata("FULLSCREEN_DIALOG")
        f:SetFrameLevel(210)
        f:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
        f:SetBackdropColor(0.08, 0.02, 0.02, 0.97)
        f:SetBackdropBorderColor(0.8, 0.2, 0.0, 1)
        f:SetMovable(true)
        f:EnableMouse(true)
        f:SetScript("OnMouseDown", function(self) self:StartMoving() end)
        f:SetScript("OnMouseUp", function(self) self:StopMovingOrSizing() end)
        f:Hide()

        f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        f.title:SetPoint("TOP", 0, -8)

        f.info = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        f.info:SetPoint("TOPLEFT", 12, -30)

        f.checkboxes = {}
        f.pendingDmgMin = 0
        f.pendingDmgMax = 0

        -- Кнопки
        f.applyBtn = CreateFrame("Button", nil, f, "BackdropTemplate")
        f.applyBtn:SetSize(100, 24)
        f.applyBtn:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
        f.applyBtn:SetBackdropColor(0.15, 0.05, 0.05, 1)
        f.applyBtn:SetBackdropBorderColor(0.3, 0.1, 0.1, 1)
        f.applyBtn.text = f.applyBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        f.applyBtn.text:SetPoint("CENTER")
        f.applyBtn.text:SetText(DoF.L["passives.dlg.explode_btn"])
        f.applyBtn:SetPoint("BOTTOMLEFT", 20, 10)
        f.applyBtn:SetScript("OnClick", function()
            DoF.Passives:ApplyDeathExplosion(f)
        end)

        f.cancelBtn = CreateFrame("Button", nil, f, "BackdropTemplate")
        f.cancelBtn:SetSize(100, 24)
        f.cancelBtn:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
        f.cancelBtn:SetBackdropColor(0.1, 0.1, 0.1, 1)
        f.cancelBtn:SetBackdropBorderColor(0.2, 0.2, 0.2, 1)
        f.cancelBtn.text = f.cancelBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        f.cancelBtn.text:SetPoint("CENTER")
        f.cancelBtn.text:SetText(DoF.L["ui.common.cancel"])
        f.cancelBtn:SetPoint("BOTTOMRIGHT", -20, 10)
        f.cancelBtn:SetScript("OnClick", function() f:Hide() end)

        deathExplosionFrame = f
    end

    local f = deathExplosionFrame
    f.title:SetText(DoF.Locale:Format("passives.dlg.title", npcName))
    f.info:SetText(DoF.Locale:Format("passives.dlg.info", damageMin, damageMax))
    f.pendingDmgMin = damageMin
    f.pendingDmgMax = damageMax

    -- Скрываем старые чекбоксы
    for _, cb in ipairs(f.checkboxes) do cb:Hide() end

    -- Создаём чекбоксы для участников боя
    local participants = {}
    if DoF.TurnSystem and DoF.TurnSystem.participants then
        for _, p in ipairs(DoF.TurnSystem.participants) do
            if p.type == "player" then
                table_insert(participants, p.name)
            end
        end
    end
    -- Если нет участников, используем группу
    if #participants == 0 and DoF.Sync and DoF.Sync.RaidData then
        for pName in pairs(DoF.Sync.RaidData) do
            table_insert(participants, pName)
        end
    end

    local y = -50
    for i, pName in ipairs(participants) do
        local cb = f.checkboxes[i]
        if not cb then
            cb = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
            cb:SetSize(22, 22)
            cb.label = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            cb.label:SetPoint("LEFT", cb, "RIGHT", 4, 0)
            f.checkboxes[i] = cb
        end
        cb:ClearAllPoints()
        cb:SetPoint("TOPLEFT", 16, y)
        cb.label:SetText(pName)
        cb._playerName = pName
        cb:SetChecked(false)
        cb:Show()
        cb.label:Show()
        y = y - 24
    end

    f:SetHeight(math.max(150, -y + 60))
    f:Show()
end

function DoF.Passives:ApplyDeathExplosion(frame)
    local targets = {}
    for _, cb in ipairs(frame.checkboxes) do
        if cb:IsShown() and cb:GetChecked() and cb._playerName then
            table_insert(targets, cb._playerName)
        end
    end

    if #targets == 0 then
        DoF.Utils:Error(DoF.L["passives.dlg.select_target"])
        return
    end

    -- Отправляем DEATH_EXPLOSION каждому
    local dmgMin = frame.pendingDmgMin or 1
    local dmgMax = frame.pendingDmgMax or 5
    for _, targetName in ipairs(targets) do
        local dmg = math.random(dmgMin, dmgMax)
        DoF.Sync:ModifyPlayerHP(targetName, -dmg)
        DoF.Sync:BroadcastCombatLog(string_format(
            DoF.L["passives.msg.explosion"],
            targetName,
            DoF.Utils:Color("FF0000", dmg)))
    end

    frame:Hide()
end

-- ═══════════════════════════════════════════════════════════
-- ИНИЦИАЛИЗАЦИЯ
-- ═══════════════════════════════════════════════════════════

function DoF.Passives:Init()
    DoF.Events:Register("COMBAT_ENDED", function()
        DoF.Passives:ClearAdaptationTracker()
    end, "Passives_CombatEnd")

    -- Взрыв при смерти — только мастер обрабатывает
    DoF.Events:Register("UNIT_DIED", function(guid, npcName)
        if not DoF.Sync:IsMaster() then return end
        -- Получаем данные NPC (они уже могут быть частично очищены, поэтому проверяем db напрямую)
        local data = DoF.db.global.unitData[guid]
        if not data or not data.passives or not data.passives.death_explosion then return end

        local explosion = data.passives.death_explosion
        local dmgMin = explosion.damageMin or 1
        local dmgMax = explosion.damageMax or 5

        -- Показываем диалог мастеру для выбора целей
        C_Timer.After(0.1, function()
            DoF.Passives:ShowDeathExplosionDialog(npcName or "NPC", dmgMin, dmgMax)
        end)
    end, "Passives_DeathExplosion")
end

-- ═══════════════════════════════════════════════════════════
-- ПОВТОРНОЕ ПРИМЕНЕНИЕ ЯЗЫКА
-- ═══════════════════════════════════════════════════════════

-- См. комментарий в Data/Effects.lua: определения собираются до того, как
-- становится известен сохранённый язык. Подписи полей ключуются по владельцу
-- и по key самого поля — так же, как в файлах локали.
DoF.Locale:RegisterRelocalizer(function()
    for id, def in pairs(DoF.Passives.Definitions) do
        def.name = DoF.L["passives." .. id .. ".name"]
        def.description = DoF.L["passives." .. id .. ".desc"]

        if def.fields then
            for _, field in ipairs(def.fields) do
                if field.key then
                    field.name = DoF.L["passives." .. id .. ".field." .. field.key]
                end
            end
        end
    end
end)
