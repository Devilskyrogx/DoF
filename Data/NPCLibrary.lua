-- DoF/Data/NPCLibrary.lua
-- Библиотека шаблонов NPC: CRUD, поиск, применение к цели, атака от лица

local ADDON_NAME, DoF = ...

local pairs = pairs
local ipairs = ipairs
local tonumber = tonumber
local tostring = tostring
local table_insert = table.insert
local table_remove = table.remove
local table_sort = table.sort
local GetTime = GetTime
local UnitName = UnitName

DoF.NPCLibrary = {}

local idCounter = 0

-- ═══════════════════════════════════════════════════════════
-- ИНИЦИАЛИЗАЦИЯ
-- ═══════════════════════════════════════════════════════════

function DoF.NPCLibrary:Init()
    -- Данные уже в DoF.db.global.npcTemplates
end

-- ═══════════════════════════════════════════════════════════
-- УТИЛИТЫ
-- ═══════════════════════════════════════════════════════════

function DoF.NPCLibrary:CopyAttacks(attacks)
    local copy = {}
    for i, atk in ipairs(attacks) do
        copy[i] = {
            name = atk.name,
            damageMin = atk.damageMin,
            damageMax = atk.damageMax,
            threshold = atk.threshold,
            defenseStat = atk.defenseStat,
            debuffId = atk.debuffId,
            debuffValue = atk.debuffValue,
            debuffDuration = atk.debuffDuration,
        }
    end
    return copy
end

-- ═══════════════════════════════════════════════════════════
-- ГЕНЕРАЦИЯ ID
-- ═══════════════════════════════════════════════════════════

function DoF.NPCLibrary:GenerateID()
    idCounter = idCounter + 1
    return "tmpl_" .. time() .. "_" .. idCounter
end

-- ═══════════════════════════════════════════════════════════
-- CRUD
-- ═══════════════════════════════════════════════════════════

function DoF.NPCLibrary:Create(data)
    local id = self:GenerateID()
    local template = {
        id = id,
        name = data.name or DoF.L["npc.new_template"],
        category = data.category or "",
        hp = tonumber(data.hp) or 10,
        fort = tonumber(data.fort) or 10,
        reflex = tonumber(data.reflex) or 10,
        will = tonumber(data.will) or 10,
        attacks = self:CopyAttacks(data.attacks or {}),
        passives = DoF.Passives and DoF.Passives:CopyPassives(data.passives) or nil,
        sortOrder = data.sortOrder or self:GetNextSortOrder(),
    }
    DoF.db.global.npcTemplates[id] = template
    DoF.Events:Fire("NPC_LIBRARY_CHANGED")
    return id
end

function DoF.NPCLibrary:Update(templateId, data)
    local tmpl = DoF.db.global.npcTemplates[templateId]
    if not tmpl then return false end

    if data.name ~= nil then tmpl.name = data.name end
    if data.category ~= nil then tmpl.category = data.category end
    if data.hp ~= nil then tmpl.hp = tonumber(data.hp) or tmpl.hp end
    if data.fort ~= nil then tmpl.fort = tonumber(data.fort) or tmpl.fort end
    if data.reflex ~= nil then tmpl.reflex = tonumber(data.reflex) or tmpl.reflex end
    if data.will ~= nil then tmpl.will = tonumber(data.will) or tmpl.will end
    if data.attacks ~= nil then tmpl.attacks = self:CopyAttacks(data.attacks) end
    if data.passives ~= nil then
        tmpl.passives = DoF.Passives and DoF.Passives:CopyPassives(data.passives) or data.passives
    end
    if data.sortOrder ~= nil then tmpl.sortOrder = data.sortOrder end

    DoF.Events:Fire("NPC_LIBRARY_CHANGED")
    return true
end

function DoF.NPCLibrary:Delete(templateId)
    if not DoF.db.global.npcTemplates[templateId] then return false end
    DoF.db.global.npcTemplates[templateId] = nil
    DoF.Events:Fire("NPC_LIBRARY_CHANGED")
    return true
end

function DoF.NPCLibrary:Duplicate(templateId)
    local tmpl = DoF.db.global.npcTemplates[templateId]
    if not tmpl then return nil end

    return self:Create({
        name = DoF.Locale:Format("npc.copy_suffix", tmpl.name),
        category = tmpl.category,
        hp = tmpl.hp,
        fort = tmpl.fort,
        reflex = tmpl.reflex,
        will = tmpl.will,
        attacks = tmpl.attacks,
        passives = tmpl.passives,
    })
end

-- ═══════════════════════════════════════════════════════════
-- ГЕТТЕРЫ
-- ═══════════════════════════════════════════════════════════

function DoF.NPCLibrary:Get(templateId)
    return DoF.db.global.npcTemplates[templateId]
end

function DoF.NPCLibrary:GetAll()
    return DoF.db.global.npcTemplates
end

function DoF.NPCLibrary:GetSorted()
    local list = {}
    for id, tmpl in pairs(DoF.db.global.npcTemplates) do
        table_insert(list, tmpl)
    end
    table_sort(list, function(a, b)
        if (a.category or "") ~= (b.category or "") then
            return (a.category or "") < (b.category or "")
        end
        if (a.sortOrder or 0) ~= (b.sortOrder or 0) then
            return (a.sortOrder or 0) < (b.sortOrder or 0)
        end
        return (a.name or "") < (b.name or "")
    end)
    return list
end

function DoF.NPCLibrary:GetCategories()
    local cats = {}
    local seen = {}
    for _, tmpl in pairs(DoF.db.global.npcTemplates) do
        local cat = tmpl.category or ""
        if not seen[cat] then
            seen[cat] = true
            table_insert(cats, cat)
        end
    end
    table_sort(cats)
    return cats
end

function DoF.NPCLibrary:GetByCategory(category)
    local list = {}
    for _, tmpl in pairs(DoF.db.global.npcTemplates) do
        if (tmpl.category or "") == (category or "") then
            table_insert(list, tmpl)
        end
    end
    table_sort(list, function(a, b)
        if (a.sortOrder or 0) ~= (b.sortOrder or 0) then
            return (a.sortOrder or 0) < (b.sortOrder or 0)
        end
        return (a.name or "") < (b.name or "")
    end)
    return list
end

function DoF.NPCLibrary:Search(query)
    if not query or query == "" then return self:GetSorted() end
    local q = query:lower()
    local list = {}
    for _, tmpl in pairs(DoF.db.global.npcTemplates) do
        if (tmpl.name or ""):lower():find(q, 1, true) or
           (tmpl.category or ""):lower():find(q, 1, true) then
            table_insert(list, tmpl)
        end
    end
    table_sort(list, function(a, b) return (a.name or "") < (b.name or "") end)
    return list
end

function DoF.NPCLibrary:GetNextSortOrder()
    local maxOrder = 0
    for _, tmpl in pairs(DoF.db.global.npcTemplates) do
        if (tmpl.sortOrder or 0) > maxOrder then
            maxOrder = tmpl.sortOrder or 0
        end
    end
    return maxOrder + 1
end

-- ═══════════════════════════════════════════════════════════
-- АТАКИ (CRUD внутри шаблона)
-- ═══════════════════════════════════════════════════════════

function DoF.NPCLibrary:AddAttack(templateId, attackData)
    local tmpl = DoF.db.global.npcTemplates[templateId]
    if not tmpl then return nil end

    local attack = {
        name = attackData.name or DoF.L["npc.attack_default"],
        damageMin = tonumber(attackData.damageMin) or 1,
        damageMax = tonumber(attackData.damageMax) or 5,
        threshold = tonumber(attackData.threshold) or 10,
        defenseStat = attackData.defenseStat or "Fortitude",
        debuffId = attackData.debuffId,
        debuffValue = tonumber(attackData.debuffValue) or 0,
        debuffDuration = tonumber(attackData.debuffDuration) or 0,
    }
    table_insert(tmpl.attacks, attack)
    DoF.Events:Fire("NPC_LIBRARY_CHANGED")
    return #tmpl.attacks
end

function DoF.NPCLibrary:UpdateAttack(templateId, attackIndex, attackData)
    local tmpl = DoF.db.global.npcTemplates[templateId]
    if not tmpl or not tmpl.attacks[attackIndex] then return false end

    local atk = tmpl.attacks[attackIndex]
    if attackData.name ~= nil then atk.name = attackData.name end
    if attackData.damageMin ~= nil then atk.damageMin = tonumber(attackData.damageMin) or atk.damageMin end
    if attackData.damageMax ~= nil then atk.damageMax = tonumber(attackData.damageMax) or atk.damageMax end
    if attackData.threshold ~= nil then atk.threshold = tonumber(attackData.threshold) or atk.threshold end
    if attackData.defenseStat ~= nil then atk.defenseStat = attackData.defenseStat end
    if attackData.debuffId ~= nil then atk.debuffId = attackData.debuffId end
    if attackData.debuffValue ~= nil then atk.debuffValue = tonumber(attackData.debuffValue) or 0 end
    if attackData.debuffDuration ~= nil then atk.debuffDuration = tonumber(attackData.debuffDuration) or 0 end

    DoF.Events:Fire("NPC_LIBRARY_CHANGED")
    return true
end

function DoF.NPCLibrary:RemoveAttack(templateId, attackIndex)
    local tmpl = DoF.db.global.npcTemplates[templateId]
    if not tmpl or not tmpl.attacks[attackIndex] then return false end

    table_remove(tmpl.attacks, attackIndex)
    DoF.Events:Fire("NPC_LIBRARY_CHANGED")
    return true
end

-- ═══════════════════════════════════════════════════════════
-- ДЕЙСТВИЯ
-- ═══════════════════════════════════════════════════════════

-- Применить статы шаблона к NPC-цели по GUID
function DoF.NPCLibrary:ApplyToTarget(templateId)
    if not DoF.Utils:RequireMaster(false) then return false end

    local tmpl = DoF.db.global.npcTemplates[templateId]
    if not tmpl then
        DoF.Utils:Error(DoF.L["errors.template_not_found"])
        return false
    end

    local guid, name = DoF.Utils:GetTargetGUID()
    if not guid then
        DoF.Utils:Error(DoF.L["errors.select_target"])
        return false
    end

    if DoF.Utils:IsTargetPlayer() then
        DoF.Utils:Error(DoF.L["errors.select_npc_not_player"])
        return false
    end

    DoF.Units:Set(guid, name, tmpl.hp, tmpl.hp, tmpl.fort, tmpl.reflex, tmpl.will)

    -- Применяем пассивки из шаблона
    if tmpl.passives and DoF.Passives then
        DoF.Passives:Set(guid, DoF.Passives:CopyPassives(tmpl.passives))
    end

    DoF.Sync:BroadcastUnit(guid, DoF.Units:Get(guid))

    DoF.Utils:Info(DoF.Locale:Format("npc.template_applied", tmpl.name, DoF.Utils:Color("FFCC00", name)))

    if DoF.CombatLog then
        DoF.CombatLog:AddMasterLog(
            DoF.Locale:Format("npc.template_applied_log", tmpl.name, name,
                tmpl.hp, tmpl.fort, tmpl.reflex, tmpl.will),
            "master_action"
        )
    end

    DoF.Events:Fire("NPC_TEMPLATE_APPLIED", templateId, guid)
    return true
end

-- Атаковать от лица NPC по пресету из шаблона
function DoF.NPCLibrary:AttackFromTemplate(templateId, attackIndex)
    if not DoF.Utils:RequireMaster(false) then return false end

    local tmpl = DoF.db.global.npcTemplates[templateId]
    if not tmpl then
        DoF.Utils:Error(DoF.L["errors.template_not_found"])
        return false
    end

    local atk = tmpl.attacks[attackIndex]
    if not atk then
        DoF.Utils:Error(DoF.L["errors.attack_not_found"])
        return false
    end

    -- Цель должна быть игроком
    local guid, name = DoF.Utils:GetTargetGUID()
    if not guid then
        DoF.Utils:Error(DoF.L["errors.select_player_target"])
        return false
    end

    if not DoF.Utils:IsTargetPlayer() then
        DoF.Utils:Error(DoF.L["errors.attack_players_only"])
        return false
    end

    DoF.Combat:NPCAttack(
        name,
        atk.damageMin, atk.damageMax,
        atk.threshold, atk.defenseStat,
        tmpl.name,
        atk.debuffId, atk.debuffValue, atk.debuffDuration
    )
    return true
end
