-- DoF/Locale/ruRU/Passives.lua
-- Названия пассивных способностей и подписи их параметров (Data/Passives.lua).
--
-- Подписи параметров именуются как passives.<пассивка>.field.<ключ>, а не общим
-- словарём по ключу: одно и то же поле value значит разное у разных пассивок
-- (HP/раунд у регенерации, снижение урона у сопротивления).

local ADDON_NAME, DoF = ...

DoF.Locale:Register("ruRU", {
    -- ─── РЕАКТИВНЫЕ ───────────────────────────────────────
    ["passives.thorns.name"] = "Шипы",
    ["passives.thorns.desc"] = "При атаке по NPC — автоматическая контратака. Игрок защищается Стойкостью или Рефлексом на выбор",
    ["passives.thorns.field.mode"] = "Режим",
    ["passives.thorns.field.chance"] = "Шанс %",
    ["passives.thorns.field.damageMin"] = "Урон мин",
    ["passives.thorns.field.damageMax"] = "Урон макс",
    ["passives.thorns.field.threshold"] = "Порог защиты",
    ["passives.thorns.field.instantDamage"] = "Мгновенный урон",

    ["passives.npc_counterattack.name"] = "Контратака",
    ["passives.npc_counterattack.desc"] = "Шанс контрудара после любой атаки по NPC",
    ["passives.npc_counterattack.field.chance"] = "Шанс %",
    ["passives.npc_counterattack.field.damageMin"] = "Урон мин",
    ["passives.npc_counterattack.field.damageMax"] = "Урон макс",
    ["passives.npc_counterattack.field.threshold"] = "Порог защиты",
    ["passives.npc_counterattack.field.defenseStat"] = "Стат защиты",

    ["passives.poisonous.name"] = "Ядовитый",
    ["passives.poisonous.desc"] = "Шанс отравления при атаке Силой (ближний бой)",
    ["passives.poisonous.field.chance"] = "Шанс %",
    ["passives.poisonous.field.dotValue"] = "Урон/раунд",
    ["passives.poisonous.field.dotDuration"] = "Длительность",
    ["passives.poisonous.field.instantDamage"] = "Мгновенный урон",

    ["passives.spell_reflection.name"] = "Отражение магии",
    ["passives.spell_reflection.desc"] = "Шанс отразить магическую атаку (Интеллект) обратно на атакующего",
    ["passives.spell_reflection.field.chance"] = "Шанс %",

    ["passives.death_explosion.name"] = "Взрыв при смерти",
    ["passives.death_explosion.desc"] = "При смерти NPC мастер выбирает, кто получит урон",
    ["passives.death_explosion.field.damageMin"] = "Урон мин",
    ["passives.death_explosion.field.damageMax"] = "Урон макс",

    -- ─── САМОБАФФЫ ────────────────────────────────────────
    ["passives.regeneration.name"] = "Регенерация",
    ["passives.regeneration.desc"] = "NPC восстанавливает HP каждый раунд",
    ["passives.regeneration.field.value"] = "HP/раунд",

    ["passives.evasion.name"] = "Уклонение",
    ["passives.evasion.desc"] = "Шанс полностью уклониться от атаки",
    ["passives.evasion.field.chance"] = "Шанс %",

    ["passives.resistance.name"] = "Сопротивление",
    ["passives.resistance.desc"] = "Снижает весь входящий урон (минимум 1 проходит)",
    ["passives.resistance.field.value"] = "Снижение урона",

    ["passives.adaptation.name"] = "Адаптация",
    ["passives.adaptation.desc"] = "После 2+ атак одним типом стата — бонус к защите от этого стата",
    ["passives.adaptation.field.value"] = "Бонус к защите",

    ["passives.berserk.name"] = "Берсерк",
    ["passives.berserk.desc"] = "Ниже 50% HP — гарантированная контратака со станом при провале защиты",
    ["passives.berserk.field.damageMin"] = "Урон мин",
    ["passives.berserk.field.damageMax"] = "Урон макс",
    ["passives.berserk.field.threshold"] = "Порог защиты",
    ["passives.berserk.field.stunDuration"] = "Длительность стана",

    -- ══════════════════════════════════════════════════════
    -- СРАБАТЫВАНИЕ ПАССИВОК (Data/Passives.lua)
    -- ══════════════════════════════════════════════════════
    ["passives.msg.regenerates"] = "%s регенерирует %s HP (%d/%d)",
    ["passives.msg.adapts"] = "%s адаптируется к атакам %s! +%d к %s",
    ["passives.msg.explosion"] = "|cFFFF6600Взрыв!|r %s получает %s урона!",
    ["passives.dlg.explode_btn"] = "|cFFFF6666Взорвать|r",
    ["passives.dlg.title"] = "|cFFFF6600Взрыв при смерти: %s|r",
    ["passives.dlg.info"] = "|cFF888888Урон: %s-%s. Выберите цели:|r",
    ["passives.dlg.select_target"] = "Выберите хотя бы одну цель!",
})
