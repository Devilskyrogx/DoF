-- DoF/Locale/ruRU/Effects.lua
-- Названия и описания статус-эффектов (Data/Effects.lua).

local ADDON_NAME, DoF = ...

DoF.Locale:Register("ruRU", {
    -- ══════════ DoT ══════════
    ["effects.bleeding.name"] = "Периодический урон",
    ["effects.bleeding.desc"] = "Урон каждый раунд",
    ["effects.dot_master.name"] = "Периодический урон",
    ["effects.dot_master.desc"] = "Урон от NPC каждый раунд",

    -- ══════════ Дебаффы (мастер → игрок) ══════════
    ["effects.stun.name"] = "Оглушение",
    ["effects.stun.desc"] = "Пропуск хода",

    -- ══════════ Ослабление защитных статов NPC ══════════
    ["effects.weakness_fortitude.name"] = "Ослабление (Стойкость)",
    ["effects.weakness_fortitude.desc"] = "Снижает Стойкость NPC",
    ["effects.weakness_reflex.name"] = "Ослабление (Сноровка)",
    ["effects.weakness_reflex.desc"] = "Снижает Сноровку NPC",
    ["effects.weakness_will.name"] = "Ослабление (Воля)",
    ["effects.weakness_will.desc"] = "Снижает Волю NPC",

    -- ══════════ Ослабление игрока ══════════
    ["effects.weakness_damage.name"] = "Ослабление (урон)",
    ["effects.weakness_damage.desc"] = "Снижает наносимый урон игрока",
    ["effects.weakness_healing.name"] = "Ослабление (лечение)",
    ["effects.weakness_healing.desc"] = "Снижает исцеление игрока",

    -- ══════════ Уязвимость защитных статов игрока ══════════
    ["effects.vulnerability_fortitude.name"] = "Уязвимость (Стойкость)",
    ["effects.vulnerability_fortitude.desc"] = "Снижает Стойкость игрока",
    ["effects.vulnerability_reflex.name"] = "Уязвимость (Сноровка)",
    ["effects.vulnerability_reflex.desc"] = "Снижает Сноровку игрока",
    ["effects.vulnerability_will.name"] = "Уязвимость (Воля)",
    ["effects.vulnerability_will.desc"] = "Снижает Волю игрока",

    -- ══════════ Усиление ══════════
    ["effects.empower_strength.name"] = "Усиление (Сила)",
    ["effects.empower_strength.desc"] = "+2 к Силе (AoE: +4)",
    ["effects.empower_dexterity.name"] = "Усиление (Ловкость)",
    ["effects.empower_dexterity.desc"] = "+2 к Ловкости (AoE: +4)",
    ["effects.empower_intelligence.name"] = "Усиление (Интеллект)",
    ["effects.empower_intelligence.desc"] = "+2 к Интеллекту (AoE: +4)",
    ["effects.empower_spirit.name"] = "Усиление (Дух)",
    ["effects.empower_spirit.desc"] = "+2 к Духу (AoE: +4)",
    ["effects.empower_damage.name"] = "Усиление (Урон)",
    ["effects.empower_damage.desc"] = "+1 к Урону (AoE: +2)",
    ["effects.empower_healing.name"] = "Усиление (Исцеление)",
    ["effects.empower_healing.desc"] = "+1 к Исцелению (AoE: +2, игнорирует лимит 50%)",

    -- ══════════ Укрепление ══════════
    ["effects.fortify_fortitude.name"] = "Укрепление (Стойкость)",
    ["effects.fortify_fortitude.desc"] = "+2 к Стойкости (AoE: +4)",
    ["effects.fortify_reflex.name"] = "Укрепление (Сноровка)",
    ["effects.fortify_reflex.desc"] = "+2 к Сноровке (AoE: +4)",
    ["effects.fortify_will.name"] = "Укрепление (Воля)",
    ["effects.fortify_will.desc"] = "+2 к Воле (AoE: +4)",
    ["effects.fortify_hp.name"] = "Укрепление (HP)",
    ["effects.fortify_hp.desc"] = "+2 к макс. HP (AoE: +4)",

    -- ══════════ Танк ══════════
    ["effects.tank_fort_streak.name"] = "Стойкая защита (Стойкость)",
    ["effects.tank_fort_streak.desc"] = "Бонус к Стойкости за серию успешных защит",
    ["effects.tank_reflex_streak.name"] = "Стойкая защита (Сноровка)",
    ["effects.tank_reflex_streak.desc"] = "Бонус к Сноровке за серию успешных защит",
    ["effects.tank_will_streak.name"] = "Стойкая защита (Воля)",
    ["effects.tank_will_streak.desc"] = "Бонус к Воле за серию успешных защит",
    ["effects.tank_shred_fortitude.name"] = "Пробитие (Стойкость)",
    ["effects.tank_shred_fortitude.desc"] = "Снижает Стойкость NPC (-2 за стак, макс 3 стака)",
    ["effects.tank_shred_reflex.name"] = "Пробитие (Сноровка)",
    ["effects.tank_shred_reflex.desc"] = "Снижает Сноровку NPC (-2 за стак, макс 3 стака)",
    ["effects.tank_redirect.name"] = "Перехват урона",
    ["effects.tank_redirect.desc"] = "Следующая атака NPC по цели перенаправляется на танка",
    ["effects.tank_taunt.name"] = "Провокация",
    ["effects.tank_taunt.desc"] = "NPC обязан атаковать танка",

    -- ══════════ Лечение ══════════
    ["effects.healing_fatigue.name"] = "Усталость лечения",
    ["effects.healing_fatigue.desc"] = "Повышает порог для успешного исцеления (+2 за стак)",
    ["effects.shield_exhaustion.name"] = "Истощение щита",
    ["effects.shield_exhaustion.desc"] = "Щит недавно разрушен. Невозможно наложить новый щит.",

    -- ══════════ Перезарядки ══════════
    ["effects.cooldown_tank_redirect.name"] = "Перезарядка (Перехват)",
    ["effects.cooldown_tank_redirect.desc"] = "Перехват урона перезаряжается",
    ["effects.cooldown_tank_taunt.name"] = "Перезарядка (Провокация)",
    ["effects.cooldown_tank_taunt.desc"] = "Провокация перезаряжается",
    ["effects.cooldown_tank_taunt_aoe.name"] = "Перезарядка (Масс. провокация)",
    ["effects.cooldown_tank_taunt_aoe.desc"] = "Массовая провокация перезаряжается",
    ["effects.cooldown_special_action.name"] = "Перезарядка (Особое)",
    ["effects.cooldown_special_action.desc"] = "Особое действие перезаряжается",
    ["effects.cooldown_aoe.name"] = "Перезарядка (AoE)",
    ["effects.cooldown_aoe.desc"] = "AoE атака и исцеление перезаряжаются",
    ["effects.cooldown_shield.name"] = "Перезарядка (Щит)",
    ["effects.cooldown_shield.desc"] = "Щит перезаряжается",
    ["effects.cooldown_aoe_shield.name"] = "Перезарядка (AoE Щит)",
    ["effects.cooldown_aoe_shield.desc"] = "AoE щит перезаряжается",

    -- ══════════════════════════════════════════════════════
    -- СООБЩЕНИЯ О НАЛОЖЕНИИ И СНЯТИИ (Data/Effects.lua)
    -- ══════════════════════════════════════════════════════
    ["effects.msg.applies"] = "%s накладывает %s на %s",
    ["effects.msg.applies_aoe"] = "%s [AoE] накладывает %s на %s",
    ["effects.msg.applied_aoe"] = "[AoE] %s наложен на %s",
    ["effects.msg.applies_weakness"] = "%s накладывает |cFF%s%s|r (-%d) на %s на %d раунда",
    ["effects.msg.stacked"] = "%s усилен на %s (стаки: %d)",
    ["effects.msg.starts_on"] = "%s начинает действовать на %s",
    ["effects.msg.removed_from"] = "%s снят с %s",
    ["effects.msg.already_applied_here"] = "%s уже наложен вами на эту цель",
    ["effects.msg.already_applied_on"] = "%s уже наложен вами на %s",
    ["effects.msg.max_stacks"] = "%s — максимум %s стаков!",
    ["effects.msg.dot_damage_hp"] = "%s получает %d урона от %s. HP: %d/%d",
    ["effects.msg.dot_damage"] = "%s получает %d урона от %s",
    ["effects.msg.hot_heal"] = "%s восстанавливает %d HP",
    ["effects.msg.stun_over"] = "|cFFFFFF00%s|r больше не оглушен!",
    ["effects.msg.debuff_removed"] = "Снят дебафф с %s",
    ["effects.msg.debuff_removed_log"] = "%s снимает дебафф с %s",
    ["effects.msg.buff_removed"] = "Снят бафф с %s",
    ["effects.msg.no_debuffs"] = "Нет дебаффов для снятия",
    ["effects.msg.no_buffs"] = "Нет баффов для снятия",
    ["effects.msg.npc_fallback"] = "НПЦ",

    -- Причины отказа (возвращаются вторым значением из проверки доступа)
    ["effects.deny.unknown"] = "Неизвестный эффект",
    ["effects.deny.master_only"] = "Только мастер может использовать этот эффект",
    ["effects.deny.cooldown"] = "Кулдаун: %s %s",
    ["effects.deny.not_enough_energy"] = "Недостаточно энергии (нужно %s)",
    ["effects.deny.role_required"] = "Требуется роль: %s",

    ["effects.action.apply"] = "Применение эффекта",
})
