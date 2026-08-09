-- DoF/Locale/ruRU/UI.lua
-- Интерфейс: кнопки, заголовки окон, подписи полей, подсказки.
-- Ключи с префиксом "xml." превращаются в глобалы DoF_L_* для UI/Frames.xml
-- (см. Locale/Globals.lua).

local ADDON_NAME, DoF = ...

DoF.Locale:Register("ruRU", {
    -- ══════════════════════════════════════════════════════
    -- XML: UI/Frames.xml
    -- ══════════════════════════════════════════════════════
    ["xml.attack"] = "Атака",
    ["xml.by_initiative"] = "По порядку инициативы",
    ["xml.check_versions"] = "Проверить версии",
    ["xml.clear_all_npcs"] = "Очистить всех NPC",
    ["xml.combat_control_caps"] = "УПРАВЛЕНИЕ БОЕМ",
    ["xml.combat_settings_caps"] = "НАСТРОЙКИ БОЯ",
    ["xml.damage"] = "Урон",
    ["xml.debuff"] = "Дебафф",
    ["xml.defense_short"] = "Защ.",
    ["xml.energy_caps"] = "ЭНЕРГИЯ",
    ["xml.energy_minus_1"] = "-1 энергия",
    ["xml.energy_plus_1"] = "+1 энергия",
    ["xml.level_minus_1"] = "-1 уровень",
    ["xml.level_plus_1"] = "+1 уровень",
    ["xml.enemy_turn"] = "Ход противника",
    ["xml.extra_turn"] = "Внеочередной ход",
    ["xml.fortitude_caps"] = "СТОЙК",
    ["xml.fortitude_short"] = "Стойк.",
    ["xml.free_queue"] = "Свободная очередь",
    ["xml.full_energy"] = "Полная энергия",
    ["xml.give_shield"] = "Дать щит",
    ["xml.instant_defense"] = "Мгновенная защита",
    ["xml.name"] = "Имя",
    ["xml.no"] = "Нет",
    ["xml.npc_attack"] = "Атака NPC",
    ["xml.npc_library"] = "Библиотека NPC",
    ["xml.npc_setup"] = "Настройка NPC",
    ["xml.gm_panel_title"] = "ПАНЕЛЬ ВЕДУЩЕГО",
    ["xml.player_hp_title"] = "HP Игрока",
    ["xml.tab_npc"] = "НПС",
    ["xml.tab_player"] = "Игрок",
    ["xml.tab_combat"] = "Бой",
    ["xml.tab_effects"] = "Эффекты",
    ["xml.player_control_caps"] = "УПРАВЛЕНИЕ ИГРОКОМ",
    ["xml.player_role_caps"] = "РОЛЬ ИГРОКА",
    ["xml.queue_no_leader"] = "Без ведущего в очереди",
    ["xml.reflex_caps"] = "СНОР",
    ["xml.remove"] = "Удалить",
    ["xml.reset_stats"] = "Сброс статов",
    ["xml.round_short"] = "Раунд.",
    ["xml.seconds_short"] = "сек",
    ["xml.set_role"] = "Задать роль",
    ["xml.set_level"] = "Уровень",
    ["xml.skip"] = "Пропустить",
    ["xml.start_combat"] = "Начать бой",
    ["xml.sync"] = "Синхронизация",
    ["xml.threshold"] = "Порог",
    ["xml.use_timer"] = "Использовать таймер",
    ["xml.utilities_caps"] = "УТИЛИТЫ",
    ["xml.value_short"] = "Знач.",
    ["xml.will_caps"] = "ВОЛЯ",
    ["xml.wound_add"] = "+Ранение",
    ["xml.wound_remove"] = "-Ранение",

    -- ══════════════════════════════════════════════════════
    -- Всплывающий текст на неймплейтах (UI/Nameplates.lua)
    -- ══════════════════════════════════════════════════════
    ["ui.nameplate.crit_fail"] = "Крит. провал!",
    ["ui.nameplate.crit_damage"] = "Крит! -%d",
    ["ui.nameplate.crit_heal"] = "Крит! +%d HP",
    ["ui.nameplate.hit"] = "Попадание! -%d",
    ["ui.nameplate.miss"] = "Промах!",

    -- ══════════════════════════════════════════════════════
    -- ОБЩАЯ ЛЕКСИКА
    -- Слова, повторяющиеся в разных окнах. Один ключ на слово, иначе перевод
    -- разъезжается: в одном окне «Бафф», в соседнем «Усиление».
    -- ══════════════════════════════════════════════════════
    ["ui.common.buff"] = "Бафф",
    ["ui.common.debuff"] = "Дебафф",
    ["ui.common.damage"] = "Урон",
    ["ui.common.healing"] = "Исцеление",
    ["ui.common.shield"] = "Щит",
    ["ui.common.skip"] = "Пропуск",
    ["ui.common.dot"] = "Периодический урон",
    ["ui.common.target_dead"] = "Цель мертва",
    ["ui.common.cancel"] = "Отмена",
    ["ui.common.cancel_colored"] = "|cFF888888Отмена|r",
    ["ui.common.cancel_verb"] = "Отменить",
    ["ui.common.finish"] = "Завершить",
    ["ui.common.apply"] = "Применить",
    ["ui.common.none"] = "Нет",
    ["ui.common.yes"] = "Да",
    ["ui.common.no"] = "Нет",

    -- ══════════════════════════════════════════════════════
    -- Меню действий: заголовки разделов (UI/Dialogs.lua)
    -- ══════════════════════════════════════════════════════
    ["ui.menu.attack_header"] = "- Атака -",
    ["ui.menu.special_header"] = "- Особое действие -",
    ["ui.menu.heal_header"] = "- Исцеление -",
    ["ui.menu.shield_header"] = "- Щит -",
    ["ui.menu.wounds_header"] = "- Раны -",
    ["ui.menu.dispel_header"] = "- Диспел -",
    ["ui.menu.offensive_header"] = "- Атакующие -",
    ["ui.menu.defensive_header"] = "- Защитные -",
    ["ui.menu.aoe_header_short"] = "- AoE (%d эн.) -",
    ["ui.menu.aoe_attack_header"] = "- AoE атака (%d энергии) -",
    ["ui.menu.aoe_heal_header"] = "- AoE Исцеление (%d энергии) -",
    ["ui.menu.effects_header_short"] = "- Эффекты (%d эн.) -",
    ["ui.menu.effects_header"] = "- Эффекты (%d энергии) -",
    ["ui.menu.effects_on"] = "- Эффекты на %s -",
    ["ui.menu.no_actions"] = "Нет доступных действий",
    ["ui.menu.no_effects"] = "|cFF666666Нет доступных эффектов|r",
    -- Суффикс приписывается к названию действия, поэтому начинается с пробела
    ["ui.menu.no_energy_suffix"] = " |cFF666666(нет энергии)|r",

    -- ══════════════════════════════════════════════════════
    -- Действия игрока (UI/Dialogs.lua)
    -- ══════════════════════════════════════════════════════
    ["ui.action.attack_of"] = "Атака: %s",
    ["ui.action.attack_str_desc"] = "Бросок d20 + Сила. Мощная атака ближнего боя.",
    ["ui.action.attack_dex_desc"] = "Бросок d20 + Ловкость. Точный удар или выстрел.",
    ["ui.action.attack_int_desc"] = "Бросок d20 + Интеллект. Магическая атака.",
    ["ui.action.special"] = "Особое действие",
    ["ui.action.special_colored"] = "|cFF9966FFОсобое действие|r",
    ["ui.action.special_desc"] = "Бросок d20 + характеристика по выбору мастера.\nПорог задаёт мастер.\nЭнергия: по решению мастера.",
    ["ui.action.heal_desc"] = "Бросок d20 + Дух. Восстанавливает HP союзнику.",
    ["ui.action.shield"] = "Наложить щит",
    ["ui.action.shield_desc"] = "Бросок d20 + Дух. Создаёт щит, поглощающий урон.",
    ["ui.action.remove_wound"] = "Снять рану",
    ["ui.action.remove_wound_title"] = "Снять рану (Лекарь)",
    ["ui.action.remove_wound_desc"] = "Бросок d20 + Дух против порога 16. При успехе снимает одно ранение с цели.",
    ["ui.action.apply_dot"] = "Наложить DoT",
    ["ui.action.apply_dot_desc"] = "Наложить эффект урона на NPC.\nУрон каждый раунд в течение нескольких раундов.",
    ["ui.action.weaken_npc"] = "Ослабить NPC",
    ["ui.action.weaken"] = "Ослабление",
    ["ui.action.weaken_desc"] = "Снижает защитный стат NPC на 1-3 (случ.) на 3 раунда.\nВыберите: Стойкость, Сноровка или Воля.\nСтоимость: 1 энергия",
    ["ui.action.dispel"] = "Снять дебафф",
    ["ui.action.dispel_title"] = "Диспел",
    ["ui.action.dispel_desc"] = "Снимает один дебафф с союзника.\nСтоимость: 1 энергия",

    -- ══════════════════════════════════════════════════════
    -- AoE-режимы (UI/Dialogs.lua)
    -- ══════════════════════════════════════════════════════
    ["ui.aoe.remaining"] = "Осталось: %d",
    ["ui.aoe.attack_desc"] = "От %d до %d целей. Урон x0.5.\nСтоимость: %d энергии",
    ["ui.aoe.hit_target"] = "Ударить цель",
    ["ui.aoe.hit_title"] = "AoE удар",
    ["ui.aoe.hit_desc"] = "Нанести урон выбранной цели.\nЦель нельзя атаковать повторно.",
    ["ui.aoe.finish_attack"] = "Завершить AoE",
    ["ui.aoe.finish_attack_desc"] = "Завершить AoE атаку досрочно.",
    ["ui.aoe.heal_header"] = "- AoE Исцеление -",
    ["ui.aoe.heal_label"] = "AoE Исцеление",
    ["ui.aoe.heal_target"] = "Исцелить цель",
    ["ui.aoe.heal_title"] = "AoE исцеление",
    ["ui.aoe.heal_desc"] = "Исцелить выбранного союзника.\nОдного союзника нельзя исцелить дважды.",
    ["ui.aoe.heal_desc_full"] = "От %d до %d союзников. Хил x0.5.\nСтоимость: %d энергии",
    ["ui.aoe.finish_heal_desc"] = "Завершить AoE исцеление досрочно.",
    ["ui.aoe.buff_target"] = "Бафнуть цель",
    ["ui.aoe.buff_title"] = "AoE бафф",
    ["ui.aoe.buff_desc"] = "Наложить %s на выбранного союзника.\nОдного союзника нельзя бафнуть дважды.",
    ["ui.aoe.finish_buff_desc"] = "Завершить AoE бафф досрочно.",
    ["ui.aoe.buff_hint"] = "%d энергии, макс. %d целей",

    -- ══════════════════════════════════════════════════════
    -- Окно наложения баффов (UI/Dialogs.lua)
    -- ══════════════════════════════════════════════════════
    ["ui.buff.section_empower"] = "Усиление",
    ["ui.buff.section_fortify"] = "Укрепление",
    ["ui.buff.section_healer"] = "Целитель",
    ["ui.buff.target"] = "Цель: %s",
    ["ui.buff.hint"] = "3 раунда, 1 энергия",

    -- Короткие названия баффов для узких кнопок — отдельно от полных
    -- effects.*.name, там формулировки длиннее.
    ["ui.buff.empower_strength.name"] = "Усиление (Сила)",
    ["ui.buff.empower_strength.desc"] = "+2 к Силе",
    ["ui.buff.empower_dexterity.name"] = "Усиление (Ловк.)",
    ["ui.buff.empower_dexterity.desc"] = "+2 к Ловкости",
    ["ui.buff.empower_intelligence.name"] = "Усиление (Инт.)",
    ["ui.buff.empower_intelligence.desc"] = "+2 к Интеллекту",
    ["ui.buff.empower_spirit.name"] = "Усиление (Дух)",
    ["ui.buff.empower_spirit.desc"] = "+2 к Духу",
    ["ui.buff.empower_damage.name"] = "Усиление (Урон)",
    ["ui.buff.empower_damage.desc"] = "+1 к Урону",
    ["ui.buff.empower_healing.name"] = "Усиление (Исц.)",
    ["ui.buff.empower_healing.desc"] = "+1 к Исцелению",
    ["ui.buff.fortify_fortitude.name"] = "Укрепление (Стойк.)",
    ["ui.buff.fortify_fortitude.desc"] = "+2 к Стойкости",
    ["ui.buff.fortify_reflex.name"] = "Укрепление (Снор.)",
    ["ui.buff.fortify_reflex.desc"] = "+2 к Сноровке",
    ["ui.buff.fortify_will.name"] = "Укрепление (Воля)",
    ["ui.buff.fortify_will.desc"] = "+2 к Воле",
    ["ui.buff.fortify_hp.name"] = "Укрепление (HP)",
    ["ui.buff.fortify_hp.desc"] = "+2 к макс. HP",

    -- ══════════════════════════════════════════════════════
    -- Диалоги мастера (UI/Dialogs_Effects.lua)
    -- ══════════════════════════════════════════════════════
    ["ui.dlg.apply_buff_title"] = "Наложить бафф",
    ["ui.dlg.vulnerability_title"] = "Уязвимость",
    ["ui.dlg.weaken_defense_title"] = "Ослабить защиту",
    ["ui.dlg.weaken_hint"] = "-1..3 на 3 раунда, 1 энергия",
    ["ui.dlg.value_label"] = "Значение:",
    ["ui.dlg.rounds_label"] = "Раундов:",
    ["ui.dlg.penalty_label"] = "Штраф (-N):",
    ["ui.dlg.weaken_defense_label"] = "Ослабить защиту:",
    ["ui.dlg.reduce_label"] = "Снизить:",
    ["ui.dlg.defense_stat_label"] = "Защитный стат:",
    ["ui.dlg.hybrid"] = "Гибрид",
    ["ui.dlg.mode_guaranteed"] = "Гарантир.",
    ["ui.dlg.mode_chance"] = "Шанс",
    ["ui.dlg.special_approved"] = "Особое действие одобрено",
    ["ui.dlg.roll_dice"] = "Бросить кубик!",
    ["ui.dlg.roll_dice_colored"] = "|cFFFFFFFFБросить кубик!|r",
    ["ui.dlg.no_roll"] = "|cFF00FF00Без броска (автоуспех)|r",
    ["ui.dlg.perform_action"] = "|cFFFFFFFFВыполнить действие!|r",
    ["ui.dlg.action_line"] = "|cFFFFD700Действие:|r |cFF66CCFF%s%s|r",
    ["ui.dlg.roll_line"] = "Бросок |cFF%s%s|r порог %d",
    ["ui.dlg.energy_line"] = "  |  |cFF9966FFЭнергия: %d|r",
    ["ui.dlg.damage_detail"] = " (урон %s-%s)",
    ["ui.dlg.damage_detail_multi"] = " (урон %s-%s x%s)",
    ["ui.dlg.duration_short"] = " (%s р.)",
    ["ui.dlg.passive_suffix"] = " |cFF888888(пассивка)|r",
    ["ui.dlg.no_buffs"] = "На цели нет баффов!",
    ["ui.dlg.no_debuffs"] = "На цели нет дебаффов!",
    ["ui.dlg.unpurgeable"] = "Не снимаемая",
    ["ui.dlg.purgeable"] = "Снимаемая",
    ["ui.dlg.unpurgeable_colored"] = "|cFFFF4444Не снимаемая|r",
    ["ui.dlg.purgeable_colored"] = "|cFF66FF66Снимаемая|r",
    ["ui.dlg.on"] = "|cFFFF6600ВКЛ|r",
    ["ui.dlg.off"] = "|cFF888888ВЫКЛ|r",
    ["ui.dlg.passive_added"] = "Добавлена пассивка: %s на %s",

    -- ══════════════════════════════════════════════════════
    -- Прочие окна (UI/Dialogs_Misc.lua)
    -- ══════════════════════════════════════════════════════
    -- ══════════════════════════════════════════════════════
    -- Плашки фаз и режимов (UI/TurnQueue_Panels.lua)
    -- ══════════════════════════════════════════════════════
    ["ui.panel.players_turn"] = "|cFFFFD700Ход игроков!|r",
    ["ui.panel.your_turn"] = "|cFF00FF00ВАШ ХОД!|r\n|cFFAAAAAA(выполните действие или пропустите ход)|r",
    ["ui.panel.enemy_turn_alert"] = "|cFFFF3333Ход противника!|r",
    ["ui.panel.combat_over"] = "|cFFFFFFFFБОЙ ОКОНЧЕН|r",
    ["ui.panel.extra_turn_title"] = "|cFFFFD700ВНЕОЧЕРЕДНОЙ ХОД|r",
    ["ui.panel.extra_turn_sub"] = "|cFFAAAAAA(выполните действие)|r",
    ["ui.panel.critical_wound_title"] = "|cFFFF0000КРИТИЧЕСКОЕ РАНЕНИЕ!|r",
    ["ui.panel.critical_wound_sub"] = "|cFFFFCC00%s|r\n|cFFAAAAAAбез сознания — решите судьбу вручную|r",
    ["ui.panel.aoe_attack_title"] = "AoE АТАКА",
    ["ui.panel.aoe_heal_title"] = "AoE ИСЦЕЛЕНИЕ",
    ["ui.panel.aoe_shield_title"] = "AoE ЩИТ",
    ["ui.panel.counterattack_title"] = "КОНТРАТАКА",
    ["ui.panel.tank_hp_buff_title"] = "+2 HP СОЮЗНИКУ",
    ["ui.panel.mass_taunt_title"] = "Массовая провокация",
    ["ui.panel.hit"] = "Ударить",
    ["ui.panel.heal"] = "Исцелить",
    ["ui.panel.buff"] = "Бафнуть",
    ["ui.panel.apply"] = "Наложить",
    ["ui.panel.taunt"] = "Провоцировать",
    ["ui.panel.done"] = "Готово",
    ["ui.panel.choose_ally"] = "Выберите союзника (таргет)",
    ["ui.panel.choose_target"] = "Выберите цель",
    ["ui.panel.choose_npc_target"] = "Выберите NPC-цель",
    ["ui.panel.choose_player"] = "Выберите игрока",
    ["ui.panel.hits_left"] = "Осталось ударов: |cFFFFD700%s|r",
    ["ui.panel.shields_left"] = "Осталось щитов: |cFFFFD700%s|r",
    ["ui.panel.left"] = "Осталось: |cFFFFD700%s|r",
    ["ui.panel.targets_left"] = "Осталось целей: |cFFFFD700%s|r",
    ["ui.panel.counter_damage"] = "Урон: |cFFFF0000%s|r — выберите цель NPC",
    ["ui.panel.special_title"] = "ОСОБОЕ: %s",

    -- Шапка трекера очереди
    ["ui.queue.header"] = "Очередь: |cFFFFD700%s|r%s",
    ["ui.queue.phase_enemy"] = "Ход противника",
    ["ui.queue.phase_players"] = "Ход игроков",
    ["ui.queue.waiting_count"] = " — |cFFFFFFFF%s ожид.|r",
    ["ui.queue.mode_queue"] = "|cFFAAAAAAОчередь|r",
    ["ui.queue.mode_free"] = "|cFFAAAAAAСвободный|r",
    ["ui.queue.round_enemy"] = "|cFFFFD700Раунд %s|r — |cFFFF3333Ход противника|r",
    ["ui.queue.round_players"] = "|cFFFFD700Раунд %s — Ход игроков|r",
    ["ui.queue.label_turn"] = "Ход: ",
    ["ui.queue.label_round"] = "Раунд: ",
    ["ui.queue.timer"] = "|cFF999999%s|r|cFF%s%d:%02d|r",

    -- ══════════════════════════════════════════════════════
    -- Диалоги NPC для мастера (UI/Dialogs_NPC.lua)
    -- ══════════════════════════════════════════════════════
    ["ui.npcdlg.target_player"] = "|cFFFF6666%s (игрок)|r",
    ["ui.npcdlg.no_target"] = "|cFF888888Нет цели|r",
    ["ui.npcdlg.no_player"] = "|cFF888888Нет игрока|r",
    ["ui.npcdlg.hp_not_set"] = "%s |cFFFF6666(HP не задан)|r",
    ["ui.npcdlg.setup_summary"] = "%s: HP %s | С:%s Сн:%s В:%s",
    ["ui.npcdlg.setup_log"] = "Настроил NPC '%s': HP=%s, С=%s, Сн=%s, В=%s",
    ["ui.npcdlg.modify_log"] = "Изменил HP NPC '%s': %+d (HP: %d/%d)",
    ["ui.npcdlg.target_dead_msg"] = "%s - цель мертва!",
    ["ui.npcdlg.attack_action"] = "Атака НПЦ",
    ["ui.npcdlg.actions_for"] = "Действия: %s",
    ["ui.npcdlg.change_hp"] = "|cFF66CCFFИзменить HP|r",
    ["ui.npcdlg.change_role"] = "|cFFA06AF1Сменить роль|r",
    ["ui.npcdlg.add_wound"] = "|cFFFF6666Добавить ранение|r",
    ["ui.npcdlg.remove_wound"] = "|cFF66FF66Снять ранение|r",
    ["ui.npcdlg.debuff_weakness_damage"] = "Ослабл. урона",
    ["ui.npcdlg.debuff_weakness_healing"] = "Ослабл. лечения",
    ["ui.npcdlg.debuff_vuln_fortitude"] = "Уязв. (Стойк.)",
    ["ui.npcdlg.debuff_vuln_reflex"] = "Уязв. (Снор.)",
    ["ui.npcdlg.debuff_vuln_will"] = "Уязв. (Воля)",
    ["ui.npcdlg.debuff_dot"] = "Период. урон",

    -- ══════════════════════════════════════════════════════
    -- Боевые окна игрока и мастера (UI/Dialogs_Combat.lua)
    -- ══════════════════════════════════════════════════════
    ["ui.combat.attacked_title"] = "Вас атакуют",
    ["ui.combat.check_title"] = "Проверка",
    ["ui.combat.defend_btn"] = "ЗАЩИТА",
    ["ui.combat.roll_btn"] = "БРОСОК",
    ["ui.combat.timer_sec"] = "|cFF%s%.1f сек|r",
    ["ui.combat.against_your"] = "Против вашей %s",
    ["ui.combat.choose_defense"] = "Выберите защиту",
    ["ui.combat.crit_hit_title"] = "Критический удар",
    ["ui.combat.crit_heal_title"] = "Критическое исцеление",
    ["ui.combat.crit_defense_title"] = "Крит защиты",
    ["ui.combat.choose_bonus"] = "Выберите бонус:",
    ["ui.combat.bonus_damage"] = "+%s к урону",
    ["ui.combat.bonus_energy"] = "+1 энергия",
    ["ui.combat.bonus_full_heal"] = "Полное исцеление",
    ["ui.combat.bonus_shield"] = "Щит (1 удар)",
    ["ui.combat.bonus_counterattack"] = "Контратака",
    ["ui.combat.bonus_ally_hp"] = "+2 HP союзнику",
    ["ui.combat.shield_activated"] = "Щит активирован!",
    ["ui.combat.time_up_crit"] = "Время истекло! Случайный выбор крит-бонуса.",
    ["ui.combat.time_up_defense"] = "Время истекло! Случайный выбор бонуса защиты.",
    ["ui.combat.special_request_title"] = "Запрос на особое действие",
    ["ui.combat.special_request_desc"] = "Опишите ваше особое действие (до 1000 символов)",
    ["ui.combat.send_request"] = "Отправить запрос",
    ["ui.combat.you_are_gm_approve"] = "Вы мастер - одобрите или отклоните своё действие.",
    ["ui.combat.request_sent"] = "Запрос на особое действие отправлен мастеру. Ожидайте одобрения...",
    ["ui.combat.player_label"] = "|cFFFFFFFFИгрок:|r |cFF66CCFF%s|r",
    ["ui.combat.action_type_label"] = "Тип действия:",
    ["ui.combat.simple_action_label"] = "|cFFAAAAAAДействие: %s (цель выбирается после броска)|r",
    ["ui.combat.choose_effect"] = "Выберите эффект:",
    ["ui.combat.target_count"] = "Кол-во целей:",
    ["ui.combat.damage_min"] = "Урон мин:",
    ["ui.combat.damage_max"] = "макс:",
    ["ui.combat.no_roll_label"] = "Без броска (автоуспех)",
    ["ui.combat.threshold_label"] = "Порог:",
    ["ui.combat.stat_label"] = "Характеристика:",
    ["ui.combat.request_energy"] = "Запросить энергию",
    ["ui.combat.approve"] = "Одобрить",
    ["ui.combat.reject"] = "Отклонить",
    ["ui.combat.special_approved_msg"] = "Особое действие игрока %s |cFF00FF00одобрено|r (%s).",
    ["ui.combat.special_rejected_msg"] = "Особое действие игрока %s |cFFFF6666отклонено|r.",
    ["ui.combat.shred_title"] = "Пробитие защиты",
    ["ui.combat.shred_desc"] = "Снизить защиту %s:",

    -- ══════════════════════════════════════════════════════
    -- Панель настроек в меню игры (UI/Settings.lua)
    -- ══════════════════════════════════════════════════════
    ["ui.opt.version"] = "|cFF888888Версия %s|r",
    ["ui.opt.desc"] = "Настройки аддона боевой системы",
    ["ui.opt.log_header"] = "|cFFFFD700Журнал боя|r",
    ["ui.opt.log_enable"] = "Включить журнал боя",
    ["ui.opt.log_tooltip"] = "Когда включено: все сообщения боя отображаются в журнале.\nКогда выключено: сообщения боя отображаются в чате, журнал недоступен.",
    ["ui.opt.log_desc"] = "Включено: все логи боя отображаются в окне журнала (ничего в чат).\nВыключено: журнал недоступен, все логи идут только в чат.",
    ["ui.opt.log_on"] = "Журнал боя включен",
    ["ui.opt.log_off"] = "Журнал боя выключен, сообщения будут в чате",
    ["ui.opt.scale_header"] = "|cFFFFD700Масштаб окна|r",
    ["ui.opt.scale_slider"] = "Масштаб интерфейса",
    ["ui.opt.scale_desc"] = "Изменяет размер главного окна DoF. Требуется перезагрузка UI для полного применения.",
    ["ui.opt.frames_header"] = "|cFFFFD700Компактные фреймы|r",
    ["ui.opt.player_frame"] = "Показывать фрейм игрока",
    ["ui.opt.player_frame_tooltip"] = "Отображать компактный фрейм с HP, энергией и эффектами игрока.",
    ["ui.opt.target_frame"] = "Показывать фрейм цели (NPC)",
    ["ui.opt.target_frame_tooltip"] = "Отображать компактный фрейм с HP и защитой выбранного NPC.",
    ["ui.opt.lock_frames"] = "Заблокировать перемещение",
    ["ui.opt.lock_frames_tooltip"] = "Запретить перемещение фреймов мышью.",
    ["ui.opt.frames_scale"] = "Масштаб фреймов",
    ["ui.opt.reset_positions"] = "Сбросить позиции",
    ["ui.opt.positions_reset"] = "Позиции фреймов сброшены",
    ["ui.opt.actionbar_header"] = "|cFFFFD700Панель действий|r",
    ["ui.opt.actionbar_show"] = "Показывать панель действий",
    ["ui.opt.actionbar_tooltip"] = "Отображать плавающую панель с кнопками действий (атака, лечение и т.д.)",
    ["ui.opt.reset_settings"] = "Сбросить настройки",
    ["ui.opt.reset_confirm"] = "Сбросить все настройки DoF к значениям по умолчанию?",
    ["ui.opt.settings_reset"] = "Настройки сброшены к значениям по умолчанию",

    -- ══════════════════════════════════════════════════════
    -- Компактные фреймы (UI/UnitFrames.lua)
    -- ══════════════════════════════════════════════════════
    ["ui.uf.no_data"] = "|cFF888888Нет данных|r",
    ["ui.uf.loading"] = "Данные загружаются...",
    ["ui.uf.fort_short"] = "Сто:",
    ["ui.uf.reflex_short"] = "Сно:",
    ["ui.uf.will_short"] = "Вол:",
    ["ui.uf.fort_desc"] = "Защита от физических атак (Сила)",
    ["ui.uf.reflex_desc"] = "Защита от точных атак (Ловкость)",
    ["ui.uf.will_desc"] = "Защита от магических атак (Интеллект)",
    ["ui.uf.wound"] = "Ранение",
    ["ui.uf.critical_wound"] = "Критическое ранение",
    ["ui.uf.critical_wound_desc_full"] = "Без сознания. Все действия заблокированы. Ходы пропускаются автоматически. Судьбу решает мастер.",
    ["ui.uf.critical_wound_desc_short"] = "Без сознания. Все действия заблокированы. Судьбу решает мастер.",
    ["ui.uf.wound_penalty"] = "Штраф %s ко всем характеристикам",
    ["ui.uf.wound_penalty_generic"] = "Штраф ко всем характеристикам",
    ["ui.uf.critical_wound_line"] = "КРИТИЧЕСКОЕ РАНЕНИЕ (без сознания)",
    ["ui.uf.wound_line"] = "Ранение (штраф %s)",
    ["ui.uf.role"] = "Роль: %s",
    ["ui.uf.damage_range"] = "Урон: %s-%s",
    ["ui.uf.healing_range"] = "Исцеление: %s-%s",
    ["ui.uf.fatigue_threshold"] = " (порог %s)",
    ["ui.uf.effect"] = "Эффект",
    ["ui.uf.hp_bonus"] = "Бонус HP: +%s",
    ["ui.uf.tank"] = "Танк: %s",
    -- %s — форма слова "ход", выбирается через DoF.Locale:Plural
    ["ui.uf.remaining_turns"] = "Осталось: %d %s",
    ["ui.turns_one"] = "ход",
    ["ui.turns_few"] = "хода",
    ["ui.turns_many"] = "ходов",
    ["ui.uf.frames_locked"] = "Фреймы заблокированы",
    ["ui.uf.frames_unlocked"] = "Фреймы разблокированы",

    -- ══════════════════════════════════════════════════════
    -- Панель мастера (UI/MainFrame_GM.lua)
    -- ══════════════════════════════════════════════════════
    ["ui.gm.shield_already"] = "Щит уже активен на %s!",
    ["ui.gm.shield_given"] = "Дан щит NPC %s",
    ["ui.gm.shield_given_log"] = "Дал щит NPC '%s'",
    ["ui.gm.full_sync_done"] = "Полная синхронизация выполнена",
    ["ui.gm.energy_restored"] = "Энергия игрока %s восстановлена до максимума.",
    ["ui.gm.debuff_removed"] = "Снят дебафф: %s с %s",
    ["ui.gm.all_effects_removed"] = "Сняты все эффекты с %s",
    ["ui.gm.passive_removed"] = "Снята пассивка: %s с %s",
    ["ui.gm.weakness_dialog"] = "Ослабление...",
    ["ui.gm.vulnerability_dialog"] = "Уязвимость...",
    ["ui.gm.buff_dialog"] = "Усиление...",
    ["ui.gm.cat_effects"] = "ЭФФЕКТЫ",
    ["ui.gm.cat_passives"] = "ПАССИВКИ NPC",
    ["ui.gm.cat_utils"] = "УТИЛИТЫ",
    ["ui.gm.util_purge"] = "Пурж (снять бафф)",
    ["ui.gm.util_dispel"] = "Диспел (снять дебафф)",
    ["ui.gm.util_clear_all"] = "Снять ВСЕ эффекты",
    ["ui.gm.start_combat"] = "Начать бой",
    ["ui.gm.end_combat"] = "Окончить бой",

    -- ══════════════════════════════════════════════════════
    -- Критическое ранение и бросок на выживание (UI/Dialogs_Wound.lua)
    -- ══════════════════════════════════════════════════════
    ["ui.wound.master_title"] = "Критическое ранение",
    ["ui.wound.master_desc"] = "Игрок упал во второй раз и получил критическое ранение.\nДать бросок на выживание или оставить с ранением?",
    ["ui.wound.give_roll"] = "Дать бросок",
    ["ui.wound.leave_wounded"] = "Оставить с ранением",
    ["ui.wound.left_wounded_log"] = "%s оставлен с критическим ранением (мастер отказал в броске на выживание).",
    ["ui.wound.setup_title"] = "Бросок на выживание",
    ["ui.wound.dc_label"] = "Порог (DC):",
    ["ui.wound.hint"] = "При успехе игрок выживает, но остаётся в критическом состоянии. При провале персонаж погибает.",
    ["ui.wound.send_roll"] = "Отправить бросок",
    ["ui.wound.player_label"] = "Игрок: %s",
    ["ui.wound.request_log"] = "Мастер требует от %s бросок на выживание: %s против DC %s",
    ["ui.wound.player_hint"] = "Успех — вы выживаете, но остаётесь в критическом состоянии.\nПровал — ваш персонаж погибает.",
    ["ui.wound.roll_btn"] = "Бросить кубик",
    ["ui.wound.player_desc"] = "Мастер требует проверку %s (ваш модификатор: %s)\nпротив порога DC %s",

    ["ui.settings.title"] = "Настройки DoF",
    ["ui.settings.ui_scale"] = "Масштаб интерфейса:",
    ["ui.settings.reset_100"] = "Сбросить (100%)",
    ["ui.help.title"] = "DoF — Справка команд",
    ["ui.help.header"] = "|cFFFFD700=== DoF (Dice of Fate) v%s ===|r",
    -- Тело справки. Через string.format НЕ прогоняется: внутри есть "%t".
    ["ui.help.body"] = [[|cFF66CCFF— Основные окна —|r
  |cFF00FF00/dof|r — главное окно
  |cFF00FF00/dof log|r — журнал боя
  |cFF00FF00/dof master|r — панель мастера
  |cFF00FF00/dof settings|r — настройки (масштаб UI)
  |cFF00FF00/dof stats|r — инфо о персонаже

|cFF66CCFF— Роли —|r
  |cFF00FF00/dofrole|r — выбрать роль
  |cFF00FF00/dofrole <игрок> tank|dd|healer|none|r — установить (мастер)

|cFF66CCFF— Ранения —|r
  |cFF00FF00/dofwound <игрок>|r — добавить ранение (мастер)
  |cFF00FF00/dofhealwound <игрок>|r — снять ранение (мастер)

|cFF66CCFF— Управление игроками (мастер) —|r
  |cFF00FF00/dofsetlevel <игрок> <1-20>|r — задать уровень игроку
  |cFF00FF00/dofsetrole <игрок>|r — задать роль игроку
  |cFF00FF00/dofresetstats <игрок>|r — сбросить статы игрока
  |cFF00FF00/dofgiveenergy <игрок>|r — дать +1 энергию
  |cFF00FF00/dofrestoreenergy <игрок>|r — восстановить полную энергию
  |cFF00FF00/dofmodifyplayerhp <игрок> ±число|r — изменить HP игрока
  |cFF00FF00/dofgiveshield <игрок> <число>|r — дать щит игроку
  |cFF00FF00/dofaddwound|r — добавить ранение (цель)
  |cFF00FF00/dofremwound|r — снять ранение (цель)

|cFF66CCFF— Управление NPC (мастер) —|r
  |cFF00FF00/dofhp|r — показать HP цели
  |cFF00FF00/dofhp <число>|r — задать HP цели
  |cFF00FF00/dofsethp <число>|r — задать HP цели
  |cFF00FF00/dofdefense <с> <сн> <в>|r — задать защиту NPC
  |cFF00FF00/dofmodifynpchp ±число|r — изменить HP NPC
  |cFF00FF00/dofremovenpc|r — удалить цель из базы
  |cFF00FF00/dofnpcattack <игрок|%t> <мин-макс> <порог> <защита> [дебафф] [значение] [раунды]|r
     Пример: /dofnpcattack %t 5-10 12 Fort stun 0 2
  |cFF00FF00/dofnpceffect <эффект> [значение] [раунды]|r — эффект на НПЦ
  |cFF00FF00/dofnpcstun [раунды]|r — оглушить НПЦ
  |cFF00FF00/dofbuff <игрок|%t> <эффект> [значение] [раунды]|r — бафф
  |cFF00FF00/dofdebuff <игрок|%t> <эффект> [значение] [раунды]|r — дебафф
  |cFF00FF00/dofpurge|r — снять бафф с цели
  |cFF00FF00/dofdispel|r — снять дебафф с цели
  |cFF00FF00/dofcleareffects|r — снять все эффекты с цели
  |cFF00FF00/dofhplist|r — список NPC
  |cFF00FF00/dofhpclear|r — очистить базу NPC

|cFF66CCFF— Боевые действия —|r
  |cFF00FF00/dofattack str|dex|int|r — атака
  |cFF00FF00/dofheal|r — исцеление (целитель)
  |cFF00FF00/dofcheck str|dex|int|spi|r — проверка характеристики
  |cFF00FF00/dofshield|r — наложить щит (целитель)
  |cFF00FF00/dofaoeattack str|dex|int|r — AoE атака
  |cFF00FF00/dofaoeheal|r — AoE исцеление
  |cFF00FF00/dofaoebuff <эффект>|r — AoE бафф

|cFF66CCFF— Пошаговый бой (мастер) —|r
  |cFF00FF00/dofcombat start [сек]|r — начать бой
  |cFF00FF00/dofcombat end|r — окончить бой
  |cFF00FF00/dofcombat help|r — все команды боя

|cFF66CCFF— Прочее (мастер) —|r
  |cFF00FF00/dofversion|r — проверить версии в группе

|cFF888888Уровень DoF (1-20) не связан с игровым — его выдаёт ведущий|r]],

    -- ══════════════════════════════════════════════════════
    -- Подсказки эффектов в меню наложения (UI/Dialogs.lua)
    -- ══════════════════════════════════════════════════════
    ["ui.effect.already_active"] = "Эффект уже активен на цели",
    ["ui.effect.active_suffix"] = " |cFF666666(активен)|r",
    ["ui.effect.cd_suffix"] = " |cFF666666(КД: %d)|r",
    ["ui.effect.cooldown"] = "Кулдаун: %d %s",
    ["ui.effect.dot_value"] = "%d урона/раунд, %d %s",
    ["ui.effect.hot_value"] = "+%d HP/раунд, %d %s",
    ["ui.effect.stat_damage"] = "урон",
    ["ui.effect.stat_mod_value"] = "%s%d к %s, %d %s",
    ["ui.effect.tooltip_desc"] = "%s\n%s\nСтоимость: %d энергии",

    -- ══════════════════════════════════════════════════════
    -- Панель способностей: кнопки (UI/ActionBar.lua)
    -- ══════════════════════════════════════════════════════
    ["ui.bar.title"] = "Панель способностей",
    ["ui.bar.attack"] = "Атака",
    ["ui.bar.heal"] = "Лечение",
    ["ui.bar.restore_energy"] = "Восст. энергии",
    ["ui.bar.support"] = "Помощь",
    ["ui.bar.wound"] = "Рана",
    ["ui.bar.purge"] = "Пурж",
    ["ui.bar.effect"] = "Эффект",
    ["ui.bar.special"] = "Особое",
    ["ui.bar.tank"] = "Танк",
    ["ui.bar.redirect"] = "Перехват",
    ["ui.bar.taunt"] = "Провокация",
    ["ui.bar.taunt_aoe"] = "Масс. пров.",
    ["ui.bar.check"] = "Проверка",
    ["ui.bar.refresh"] = "Обновить",
    ["ui.bar.shield_tooltip"] = "ЛКМ: Щит на цель (кд: 2 хода)\nПКМ: AoE щит (до 4 целей, кд: 3 хода, 2 энергии)\nПоглощает весь урон от 1 удара",
    ["ui.bar.effect_tooltip"] = "Наложить эффект (DoT / дебафф)\nОткрывает меню выбора",
    ["ui.bar.special_tooltip"] = "Особое действие\nОтправляет запрос мастеру на одобрение\nЗатраты энергии по запросу мастера",
    ["ui.bar.skip_tooltip"] = "Пропустить ход (+1 энергия)",
    ["ui.bar.refresh_tooltip"] = "Запросить данные NPC у ведущего\n\nЕсли у NPC «Нет данных» или слетел шаблон —\nнажмите, чтобы запросить ресинк.\n\nЕсли выбран NPC без данных — точечный запрос.\nИначе — полный ресинк всех NPC.\n\nКД: 5 секунд",
    ["ui.bar.position_reset"] = "Позиция панели действий сброшена",
    ["ui.bar.enabled"] = "Панель действий включена",
    ["ui.bar.disabled"] = "Панель действий выключена",
    -- Два отдельных сообщения, а не «Панель действий » + слово: иначе не собрать
    -- ни падеж, ни английский порядок слов.
    ["ui.bar.locked"] = "Панель действий заблокирована",
    ["ui.bar.unlocked"] = "Панель действий разблокирована",

    -- ══════════════════════════════════════════════════════
    -- Панель способностей: подсказки (UI/ActionBar.lua)
    -- ══════════════════════════════════════════════════════
    ["ui.tip.attack_roll"] = "Бросок d20 + %s против %s НПЦ",
    ["ui.tip.your_roll"] = "Ваш бросок: d20 + %s",
    ["ui.tip.attack_hint"] = "ЛКМ - атака | ПКМ - стата",
    ["ui.tip.restore_energy_title"] = "Восстановление энергии",
    ["ui.tip.restore_energy_desc"] = "Передаёт 1 энергию союзнику",
    ["ui.tip.cost_1_energy"] = "Стоимость: 1 энергия",
    ["ui.tip.not_on_self"] = "Не работает на себя",
    ["ui.tip.restore_hint"] = "ЛКМ - передать | ПКМ - выбор",
    ["ui.tip.heal_roll"] = "Бросок d20 + Дух",
    ["ui.tip.heal_hint"] = "ЛКМ - лечить | ПКМ - выбор",
    ["ui.tip.support_of"] = "Помощь: %s",
    ["ui.tip.wound_desc"] = "Снимает 1 рану с союзника",
    ["ui.tip.roll_spirit_16"] = "Бросок d20 + Дух, порог: 16",
    ["ui.tip.dispel_desc"] = "Снимает дебафф с союзника",
    ["ui.tip.roll_spirit_14"] = "Бросок d20 + Дух, порог: 14",
    ["ui.tip.purge_desc"] = "Снимает бафф с НПЦ",
    ["ui.tip.support_hint"] = "ЛКМ - действие | ПКМ - выбор",
    ["ui.tip.aoe_heal_title"] = "AoE: Исцеление",
    ["ui.tip.aoe_heal_desc"] = "Лечит 2-4 союзника",
    ["ui.tip.aoe_heal_roll"] = "Бросок d20 + Дух, 20 = крит",
    ["ui.tip.aoe_damage_desc"] = "Урон по 2-4 целям",
    ["ui.tip.aoe_auto_hit"] = "Авто-попадание, 20 = крит",
    ["ui.tip.aoe_hint"] = "ЛКМ - AoE | ПКМ - стата",
    ["ui.tip.check_roll"] = "Бросок d20 + %s",
    ["ui.tip.no_turn_cost"] = "Не тратит ход",
    ["ui.tip.tank_of"] = "Танк: %s",
    ["ui.tip.taunt_desc"] = "NPC обязан атаковать танка (2 р.)",
    ["ui.tip.taunt_cost"] = "1 энергии | КД: 2 хода",
    ["ui.tip.taunt_aoe_desc"] = "Провокация нескольких NPC (2 р.)",
    ["ui.tip.taunt_aoe_cost"] = "2 энергии | КД: 3 хода",
    ["ui.tip.redirect_desc"] = "Следующий удар по союзнику идет на танка",
    ["ui.tip.redirect_cost"] = "Бесплатно | КД: 2 хода",
    ["ui.tip.tank_hint"] = "ЛКМ - использовать | ПКМ - выбор",
    ["ui.tip.empower_choose"] = "Усиление (выбор стата)",
    ["ui.tip.fortify_choose"] = "Укрепление (выбор стата)",
    ["ui.tip.empower_fortify"] = "Усиление / Укрепление",
    ["ui.tip.aoe_buff_hint"] = "ПКМ - AoE бафф",
    ["ui.tip.buff_choose"] = "Выбор баффа",
    ["ui.tip.energy_required"] = "Требует энергии: %s",

    -- ══════════════════════════════════════════════════════
    -- Проверки характеристик (UI/Dialogs.lua)
    -- ══════════════════════════════════════════════════════
    ["ui.check.of"] = "Проверка: %s",
    ["ui.check.strength"] = "Физическая сила, ближний бой, поднятие тяжестей.",
    ["ui.check.dexterity"] = "Ловкость, скорость, уклонение, стрельба.",
    ["ui.check.intelligence"] = "Интеллект, магия, знания, логика.",
    ["ui.check.spirit"] = "Сила воли, харизма, исцеление.",
    ["ui.check.fortitude"] = "Сопротивление яду, болезням, физ. эффектам.",
    ["ui.check.reflex"] = "Уклонение от ловушек, AoE-атак.",
    ["ui.check.will"] = "Сопротивление ментальным атакам, страху.",

    -- ══════════════════════════════════════════════════════
    -- Подсказки эффектов (UI/Effects.lua)
    -- ══════════════════════════════════════════════════════
    ["ui.effect.heals"] = "Лечит",
    ["ui.effect.per_round"] = "%s: %s за раунд",
    ["ui.effect.modifier"] = "Модификатор: %s",
    ["ui.effect.caster_one"] = "Наложил: %s",
    ["ui.effect.caster_many"] = "Наложили: %s",
    -- %s — форма слова "раунд", выбирается через DoF.Locale:Plural
    ["ui.effect.remaining"] = "Осталось: %d %s",

    -- Формы слова "раунд" — общие для подсказок интерфейса
    ["ui.rounds_one"] = "раунд",
    ["ui.rounds_few"] = "раунда",
    ["ui.rounds_many"] = "раундов",

    -- ══════════════════════════════════════════════════════
    -- Журнал боя (UI/CombatLog.lua)
    -- ══════════════════════════════════════════════════════
    ["ui.combatlog.title_battle"] = "Журнал боя",
    ["ui.combatlog.title_master"] = "Журнал мастера",
    ["ui.combatlog.tab_battle"] = "Бой",
    ["ui.combatlog.tab_master"] = "Мастер",
    ["ui.combatlog.clear"] = "Очистить",
    ["ui.combatlog.result_marker"] = "Результат:",
    ["ui.combatlog.empty"] = "|cFF666666Журнал пуст|r",

    -- ══════════════════════════════════════════════════════
    -- Главное окно (UI/MainFrame.lua)
    -- ══════════════════════════════════════════════════════
    ["ui.role.choose_title"] = "Выбор роли",
    ["ui.role.choose_hint"] = "Нажмите, чтобы выбрать роль",
    ["ui.role.select"] = "Выберите роль",
    ["ui.role.of"] = "Роль: %s",
    ["ui.level.of"] = "Уровень: %s",
    ["ui.level.current_mark"] = "|cFF888888(текущий)|r",
    ["ui.level.tooltip_title"] = "Уровень %s",
    ["ui.level.tooltip_desc"] = "Очков характеристик: %s\nБазовое здоровье: %s\nЭнергия: %s",
    ["ui.role.reset"] = "Сбросить",
    ["ui.role.reset_title"] = "Сбросить роль",
    ["ui.role.reset_desc"] = "Убирает роль у игрока",

    -- ══════════════════════════════════════════════════════
    -- Боковая панель персонажа (UI/CharacterSidebar.lua)
    -- ══════════════════════════════════════════════════════
    ["ui.sidebar.health_energy"] = "Здоровье/Энергия",
    ["ui.sidebar.stats"] = "Характеристики",
    ["ui.sidebar.damage_healing"] = "Урон/Исцеление",
    ["ui.sidebar.distribute"] = "Распределить",
    ["ui.sidebar.gm_menu"] = "Меню ведущего",
    ["ui.sidebar.gm_menu_hint"] = "Открыть панель управления боем",
    -- %s — форма слова "очко", выбирается через DoF.Locale:Plural
    ["ui.sidebar.level"] = "Уровень %d",
    ["ui.sidebar.level_points"] = "Уровень %d | %d %s",
    ["ui.sidebar.points_one"] = "очко",
    ["ui.sidebar.points_few"] = "очка",
    ["ui.sidebar.points_many"] = "очков",
    ["ui.sidebar.max_level"] = "МАКС. УРОВЕНЬ (%d)",
    ["ui.sidebar.points_badge"] = "+ %d %s",

    -- ══════════════════════════════════════════════════════
    -- Очередь ходов (UI/TurnQueue.lua)
    -- ══════════════════════════════════════════════════════
    ["ui.queue.turn_progress"] = "Ход %d из %d",
    ["ui.queue.acted_progress"] = "%d/%d сходили",
    ["ui.queue.add_player"] = "|cFF66FF66+Игрок|r",
    ["ui.queue.extra_turn_short"] = "Вн.ход",
    ["ui.queue.level_short"] = "Ур.%s",
    ["ui.queue.skip_turn"] = "Пропустить ход",
    ["ui.queue.remove_from_combat"] = "Убрать из боя",
    ["ui.queue.rounds_left"] = "Осталось раундов: %s",
    ["ui.queue.value"] = "Значение: %s",

    -- ══════════════════════════════════════════════════════
    -- Кнопка на миникарте (UI/MinimapButton.lua)
    -- ══════════════════════════════════════════════════════
    ["ui.minimap.settings"] = "DoF: настройки",
    ["ui.minimap.tooltip_left"] = "ЛКМ - открыть панель DoF",
    ["ui.minimap.tooltip_shift_left"] = "Shift+ЛКМ - панель ведущего",
    ["ui.minimap.tooltip_right"] = "ПКМ - меню настроек",
    ["ui.minimap.you_are_gm"] = "Вы мастер",
    ["ui.minimap.gm_is"] = "Мастер: %s",
    ["ui.minimap.action_bar"] = "Панель действий",
    ["ui.minimap.player_frame"] = "Фрейм игрока",
    ["ui.minimap.target_frame"] = "Фрейм цели (NPC)",
    ["ui.minimap.lock_frames"] = "Заблокировать фреймы",
    ["ui.minimap.unlock_frames"] = "Разблокировать фреймы",
    ["ui.minimap.close"] = "Закрыть",
    ["ui.opt.lang_header"] = "|cFFFFD700Язык|r",
    ["ui.opt.lang_label"] = "Язык аддона",
    ["ui.opt.lang_desc"] = "Язык интерфейса и боевых сообщений. По умолчанию берётся из языка клиента игры.\nСмена применяется после перезагрузки интерфейса.",
    ["ui.opt.lang_reload_confirm"] = "Язык аддона изменён на «%s».\nПерезагрузить интерфейс, чтобы применить?",
    ["ui.opt.lang_reload_now"] = "Перезагрузить",
    ["ui.opt.lang_reload_later"] = "Позже",
    ["ui.sidebar.lang_tooltip"] = "Язык аддона: %s",
    ["ui.sidebar.lang_hint"] = "ЛКМ — переключить",
})
