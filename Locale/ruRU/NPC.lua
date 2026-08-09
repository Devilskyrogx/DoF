-- DoF/Locale/ruRU/NPC.lua
-- Библиотека NPC: категории, шаблоны, подписи редактора.

local ADDON_NAME, DoF = ...

DoF.Locale:Register("ruRU", {

    -- ══════════════════════════════════════════════════════
    -- БИБЛИОТЕКА NPC (Data/NPCLibrary.lua, UI/NPCLibrary*.lua)
    -- ══════════════════════════════════════════════════════
    ["npc.new_template"] = "Новый NPC",
    ["npc.copy_suffix"] = "%s (копия)",
    ["npc.attack_default"] = "Атака",
    ["npc.attack_numbered"] = "Атака %s",
    ["npc.template_applied"] = "Шаблон '%s' применён к %s",
    ["npc.template_applied_log"] = "Применён шаблон '%s' к %s (HP:%s Ст:%s Сн:%s В:%s)",
    ["npc.template_updated"] = "Шаблон '%s' обновлён",
    ["npc.template_created"] = "Шаблон '%s' создан",

    -- Короткие подписи статов и дебаффов в списке шаблонов
    ["npc.stat.fort_short"] = "Ст",
    ["npc.stat.reflex_short"] = "Сн",
    ["npc.stat.will_short"] = "В",
    ["npc.stat.hybrid_short"] = "Гб",
    ["npc.debuff.stun"] = "Оглуш.",
    ["npc.debuff.weakness_damage"] = "Осл.урона",
    ["npc.debuff.weakness_healing"] = "Осл.леч.",
    ["npc.debuff.vuln_fortitude"] = "Уязв.Ст",
    ["npc.debuff.vuln_reflex"] = "Уязв.Сн",
    ["npc.debuff.vuln_will"] = "Уязв.В",
    ["npc.debuff.dot"] = "Пер.урон",
    ["npc.debuff.generic"] = "дебафф",

    -- Окно библиотеки
    ["npc.ui.search"] = "Поиск...",
    ["npc.ui.create"] = "+ Создать",
    ["npc.ui.attacks_divider"] = "--- Атаки ---",
    ["npc.ui.apply_to_target"] = "Применить к цели",
    ["npc.ui.edit"] = "Редакт.",
    ["npc.ui.duplicate"] = "Копия",
    ["npc.ui.delete"] = "Удалить",
    ["npc.ui.delete_confirm"] = "Точно?",
    ["npc.ui.no_templates"] = "Нет шаблонов",
    ["npc.ui.no_category"] = "Без категории",
    ["npc.ui.choose_template"] = "Выберите шаблон",
    ["npc.ui.stat_line"] = "   |cFF88CC88Ст:|r %s   |cFFFFCC66Сн:|r %s   |cFF8888FFВ:|r %s",
    ["npc.ui.attack_line"] = "%s: %s / %s / %s",

    -- Редактор шаблона
    ["npc.edit.title_edit"] = "Редактировать шаблон",
    ["npc.edit.title_new"] = "Новый шаблон",
    ["npc.edit.name_label"] = "Название:",
    ["npc.edit.category_label"] = "Категория:",
    ["npc.edit.fort_label"] = "Ст:",
    ["npc.edit.reflex_label"] = "Сн:",
    ["npc.edit.will_label"] = "В:",
    ["npc.edit.damage_label"] = "Урон:",
    ["npc.edit.threshold_label"] = "Порог:",
    ["npc.edit.defense_label"] = "Защ:",
    ["npc.edit.debuff_label"] = "Деб:",
    ["npc.edit.debuff_value_label"] = "Зн:",
    ["npc.edit.debuff_duration_label"] = "Р:",
    ["npc.edit.attacks_header"] = "Атаки",
    ["npc.edit.passives_header"] = "Пассивки",
    ["npc.edit.add"] = "+ Добавить",
    ["npc.edit.save"] = "Сохранить",
    ["npc.edit.mode_guaranteed"] = "Гарант.",
    ["npc.edit.mode_chance"] = "Шанс",
    ["npc.edit.check_normal"] = "Обычный",
    ["npc.edit.instant_on"] = "Мгн. урон: ВКЛ",
    ["npc.edit.instant_off"] = "Мгн. урон: выкл",

    -- Подписи полей пассивок в редакторе (короткие, для узких кнопок)
    ["npc.field.mode"] = "Режим",
    ["npc.field.chance"] = "Шанс%",
    ["npc.field.damageMin"] = "Мин",
    ["npc.field.damageMax"] = "Макс",
    ["npc.field.threshold"] = "Порог",
    ["npc.field.dotValue"] = "Урон/р",
    ["npc.field.dotDuration"] = "Раунды",
    ["npc.field.value"] = "Значение",
    ["npc.field.stunDuration"] = "Стан(р)",
    ["npc.field.defenseStat"] = "Защита",
    ["npc.field.instantDamage"] = "Мгн. урон",
})
