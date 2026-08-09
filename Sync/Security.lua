-- DoF/Sync/Security.lua
-- Система безопасности: валидация команд, подтверждения

local ADDON_NAME, DoF = ...

-- ═══════════════════════════════════════════════════════════
-- КЛАССИФИКАЦИЯ КОМАНД
-- ═══════════════════════════════════════════════════════════

-- Команды только для мастера
local MASTER_ONLY_COMMANDS = {
    UNIT = true,
    REMOVE = true,
    CLEAR = true,
    SETSPEC = true,
    SETLEVEL = true,
    ADDWOUND = true,
    RESETSTATS = true,
    GIVESHIELD = true,
    MODIFYHP = true,
    NPCATTACK = true,
    COMBAT_START = true,
    COMBAT_END = true,
    COMBAT_STATE = true,
    ROUND_START = true,
    TURN_CHANGE = true,
    PHASE_CHANGE = true,
    FREE_ACTION = true,
    EFFECT_TICK = true,
    EFFECT_SYNC = true,
    EFFECTS_CLEAR_TARGET = true,
    GIVEENERGY = true,
    TAKEENERGY = true,
    RESTOREENERGY = true,
    SPECIALACTION_APPROVED = true,
    SPECIALACTION_REJECTED = true,
    SURVIVAL_ROLL_REQUEST = true,  -- Мастер запрашивает у игрока бросок на выживание: target;stat;dc
}

-- Безопасные команды (от любого в группе)
local SAFE_COMMANDS = {
    RELIABLE = true,          -- Обёртка надёжной доставки (содержит любую команду внутри)
    ACK = true,               -- Подтверждение получения RELIABLE-сообщения
    PLAYERDATA = true,
    PLAYERHP = true,
    REQUESTHP = true,
    COMBATLOG = true,
    MASTER = true,
    HEAL = true,
    SHIELD = true,
    REMOVEWOUND = true,
    ACTION_DONE = true,
    PLAYER_SKIP = true,
    PLAYERHPCHANGE = true,
    CONFIRM_RESPONSE = true,
    REQUEST = true,
    REQUEST_UNIT = true,        -- Точечный запрос данных одного NPC (кнопка "🔄"): args = guid
    FULLDATA = true,
    FULLDATA3 = true,          -- AceSerializer формат
    COMBAT_STATE_REQUEST = true,
    RECOVERY_REQUEST = true,
    PARTICIPANT_ADD = true,
    PARTICIPANT_REMOVE = true,
    PLAYER_ACTED = true,
    EFFECT_APPLY = true,        -- Применение эффекта
    TANK_SHRED_APPLY = true,    -- Пробитие защиты танка
    EFFECT_REMOVE = true,  -- Снятие эффекта
    HPCHANGE = true,       -- Изменение HP НПЦ (от любого игрока в бою)
    NPC_SHIELD = true,     -- Изменение щита НПЦ (от любого игрока в бою)
    HEALER_RESTORE_ENERGY = true,  -- Целитель передаёт энергию другому игроку
    COMBAT_STATE_RECOVERY = true,  -- Восстановление состояния боя (не-мастер → мастеру)
    EFFECT_SYNC_RECOVERY = true,   -- Восстановление эффектов (не-мастер → мастеру)
    HEARTBEAT = true,              -- Heartbeat мастера с хешем NPC-данных
    FATIGUE = true,                -- Усталость лечения (healer → все): count;stacks
    TANK_SHRED_TRACKER = true,     -- Трекер серии ударов танка (tank → все)
    CRITICAL_WOUND = true,         -- Игрок получил критическое ранение (для алерта мастеру)
    SURVIVAL_ROLL_RESULT = true,   -- Результат броска игрока на выживание: player;stat;dc;roll;mod;total;success
}

-- ═══════════════════════════════════════════════════════════
-- ПРОВЕРКА ГРУППЫ
-- ═══════════════════════════════════════════════════════════

local function IsInMyGroup(senderName)
    if not IsInGroup() then return false end
    
    if senderName == UnitName("player") then return true end
    
    if IsInRaid() then
        for i = 1, 40 do
            local name = GetRaidRosterInfo(i)
            if name and name == senderName then
                return true
            end
        end
    else
        for i = 1, 4 do
            local name = UnitName("party" .. i)
            if name and name == senderName then
                return true
            end
        end
    end
    
    return false
end

local function IsSenderMaster(senderName)
    return DoF.Sync:HasMasterAuth(senderName)
end

-- ═══════════════════════════════════════════════════════════
-- ВАЛИДАЦИЯ
-- ═══════════════════════════════════════════════════════════

function DoF.Sync:ValidateCommand(cmd, sender)
    -- Свои команды всегда разрешены
    if sender == UnitName("player") then
        return true
    end
    
    -- Вне группы — блокируем всё от других
    if not IsInGroup() then
        return false, "not_in_group"
    end
    
    -- Отправитель не в группе
    if not IsInMyGroup(sender) then
        return false, "not_in_group"
    end
    
    -- Мастер-команда от не-мастера
    if MASTER_ONLY_COMMANDS[cmd] then
        if not IsSenderMaster(sender) then
            return false, "not_master"
        end
    end
    
    return true
end

function DoF.Sync:LogSecurityEvent(cmd, sender, reason)
    if not self._showSystemMessages then return end
    local reasonText = {
        not_in_group = DoF.L["combat.sec.not_in_group"],
        not_master = DoF.L["combat.sec.not_master"],
    }
    DoF.Utils:Warn(DoF.Locale:Format("combat.sec.blocked", cmd, sender, reasonText[reason] or reason))
end

-- ═══════════════════════════════════════════════════════════
-- ДИАЛОГ ПОДТВЕРЖДЕНИЯ
-- ═══════════════════════════════════════════════════════════

local confirmDialog = nil

function DoF.Sync:ShowConfirmDialog(cmdType, sender, title, message, onAccept)
    if not confirmDialog then
        confirmDialog = CreateFrame("Frame", "DoF_ConfirmDialog", UIParent, "BackdropTemplate")
        confirmDialog:SetSize(320, 180)
        confirmDialog:SetPoint("CENTER")
        confirmDialog:SetFrameStrata("FULLSCREEN_DIALOG")
        confirmDialog:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 2,
        })
        confirmDialog:SetBackdropColor(0.1, 0.05, 0.05, 0.95)
        confirmDialog:SetBackdropBorderColor(0.8, 0.2, 0.2, 1)

        -- Заголовок
        confirmDialog.titleText = confirmDialog:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        confirmDialog.titleText:SetPoint("TOP", 0, -15)

        -- Отправитель
        confirmDialog.senderText = confirmDialog:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        confirmDialog.senderText:SetPoint("TOP", 0, -40)

        -- Сообщение
        confirmDialog.msgText = confirmDialog:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        confirmDialog.msgText:SetPoint("TOP", 0, -65)
        confirmDialog.msgText:SetPoint("LEFT", 20, 0)
        confirmDialog.msgText:SetPoint("RIGHT", -20, 0)
        confirmDialog.msgText:SetJustifyH("CENTER")
        confirmDialog.msgText:SetWordWrap(true)

        -- Кнопка Подтвердить
        confirmDialog.acceptBtn = CreateFrame("Button", nil, confirmDialog, "BackdropTemplate")
        confirmDialog.acceptBtn:SetSize(100, 28)
        confirmDialog.acceptBtn:SetPoint("BOTTOMLEFT", 30, 15)
        confirmDialog.acceptBtn:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
        })
        confirmDialog.acceptBtn:SetBackdropColor(0.2, 0.5, 0.2, 1)
        confirmDialog.acceptBtn:SetBackdropBorderColor(0.3, 0.7, 0.3, 1)

        confirmDialog.acceptBtn.text = confirmDialog.acceptBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        confirmDialog.acceptBtn.text:SetPoint("CENTER")
        confirmDialog.acceptBtn.text:SetText(DoF.L["combat.sec.confirm"])

        confirmDialog.acceptBtn:SetScript("OnEnter", function(self)
            self:SetBackdropColor(0.3, 0.6, 0.3, 1)
        end)
        confirmDialog.acceptBtn:SetScript("OnLeave", function(self)
            self:SetBackdropColor(0.2, 0.5, 0.2, 1)
        end)

        -- Кнопка Отклонить
        confirmDialog.declineBtn = CreateFrame("Button", nil, confirmDialog, "BackdropTemplate")
        confirmDialog.declineBtn:SetSize(100, 28)
        confirmDialog.declineBtn:SetPoint("BOTTOMRIGHT", -30, 15)
        confirmDialog.declineBtn:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
        })
        confirmDialog.declineBtn:SetBackdropColor(0.5, 0.2, 0.2, 1)
        confirmDialog.declineBtn:SetBackdropBorderColor(0.7, 0.3, 0.3, 1)

        confirmDialog.declineBtn.text = confirmDialog.declineBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        confirmDialog.declineBtn.text:SetPoint("CENTER")
        confirmDialog.declineBtn.text:SetText(DoF.L["combat.sec.decline"])

        confirmDialog.declineBtn:SetScript("OnEnter", function(self)
            self:SetBackdropColor(0.6, 0.3, 0.3, 1)
        end)
        confirmDialog.declineBtn:SetScript("OnLeave", function(self)
            self:SetBackdropColor(0.5, 0.2, 0.2, 1)
        end)
    end

    -- Обновляем динамический контент
    confirmDialog.titleText:SetText("|cFFFF6666" .. title .. "|r")
    confirmDialog.senderText:SetText(DoF.Locale:Format("combat.sec.from", sender))
    confirmDialog.msgText:SetText(message)

    -- Обновляем обработчики кнопок (cmdType, sender, onAccept меняются)
    confirmDialog.acceptBtn:SetScript("OnClick", function()
        confirmDialog:Hide()
        if onAccept then onAccept() end
        DoF.Sync:Send("CONFIRM_RESPONSE", cmdType .. ";ACCEPTED;" .. sender)
    end)
    confirmDialog.declineBtn:SetScript("OnClick", function()
        confirmDialog:Hide()
        DoF.Utils:Info(DoF.L["combat.sec.declined"])
        DoF.Sync:Send("CONFIRM_RESPONSE", cmdType .. ";DECLINED;" .. sender)
    end)

    -- Звук предупреждения
    PlaySound(8959, "SFX") -- RAID_WARNING

    confirmDialog:Show()

    -- Автоматическое закрытие через 30 секунд
    DoF.Addon:ScheduleTimer(function()
        if confirmDialog and confirmDialog:IsShown() then
            confirmDialog:Hide()
            DoF.Utils:Warn(DoF.L["combat.sec.timeout"])
            DoF.Sync:Send("CONFIRM_RESPONSE", cmdType .. ";TIMEOUT;" .. sender)
        end
    end, 30)
end
