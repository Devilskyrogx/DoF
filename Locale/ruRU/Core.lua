-- DoF/Locale/ruRU/Core.lua
-- Общие строки: название аддона, характеристики, служебные подписи.
--
-- Названия характеристик живут здесь, а не в UI: они всплывают и в интерфейсе,
-- и в боевых сообщениях, и в библиотеке NPC.

local ADDON_NAME, DoF = ...

DoF.Locale:Register("ruRU", {
    ["locale.name"] = "Русский",

    -- ══════════════════════════════════════════════════════
    -- ХАРАКТЕРИСТИКИ (UI/MainFrame.lua, STAT_CONFIG)
    -- ══════════════════════════════════════════════════════
    ["stats.strength.label"] = "Сила",
    ["stats.strength.desc"] = "Атакующая, против стойкости. Грубая мощь, способность сокрушить защиту напором. Воины, паладины, бойцы ближнего боя. Вне боя — физическое превосходство: сломать дверь, сдвинуть валун, впечатлить размахом.",

    ["stats.dexterity.label"] = "Ловкость",
    ["stats.dexterity.desc"] = "Атакующая, против сноровки. Скорость, точность, умение найти брешь. Лучники, разбойники, дуэлянты. Вне боя — реакция, координация, умение проскользнуть незамеченным.",

    ["stats.intelligence.label"] = "Интеллект",
    ["stats.intelligence.desc"] = "Атакующий, против воли. Сила разума, обращённая в оружие: заклинания, ментальное давление, тактика. Маги, чернокнижники. Вне боя — эрудиция, хитрость, умение убедить аргументом.",

    ["stats.spirit.label"] = "Дух",
    ["stats.spirit.desc"] = "Характеристика целителя, без противоборства. Связь с верой, светом, жизнью. Определяет силу исцеления. Вне боя — духовный авторитет, сила убеждения, близость к божеству.",

    ["stats.fortitude.label"] = "Стойкость",
    ["stats.fortitude.desc"] = "Защитная, против силы. Способность принять удар и устоять. Крепкое тело, выносливость. Вне боя — здоровье, терпение к боли, яду, холоду.",

    ["stats.reflex.label"] = "Сноровка",
    ["stats.reflex.desc"] = "Защитная, против ловкости. Мышечная память, чутьё на опасность. Уклонение, парирование, шаг в сторону до того, как прилетело. Вне боя — бдительность, умение почуять засаду.",

    ["stats.will.label"] = "Воля",
    ["stats.will.desc"] = "Защитная, против интеллекта. Ментальная крепость, щит разума. Сопротивление магии, иллюзиям, страху. Вне боя — решимость, стойкость к манипуляциям и давлению.",

    -- ══════════════════════════════════════════════════════
    -- РОЛИ (Core/Config.lua)
    -- ══════════════════════════════════════════════════════
    ["roles.tank.name"] = "Танк",
    ["roles.tank.desc"] = "Высокая выживаемость. HP = Базовое + Стойкость/2. Ниже среднего урон и исцеление. Серия из 2 успешных защит даёт +1 к стату защиты (до +3). Неудача сбрасывает бафф проваленного стата. Серия из 2 подряд успешных атак по одной цели срезает защиту врага на 2 (до -6). Перехват урона союзника (раз в 2 хода). Провокация (1 энергия, раз в 2 хода). АоЕ провокация (2 энергии, раз в 3 хода).",
    ["roles.dd.name"] = "Боец",
    ["roles.dd.desc"] = "Повышенный урон в бою. Ниже среднего исцеление. 15% шанс контратаки при успешной защите. Крит защиты: +3 к урону контратаки.",
    ["roles.healer.name"] = "Целитель",
    ["roles.healer.desc"] = "Усиленное исцеление, снятие ран. Ниже среднего урон. Щит (поглощает 1 удар, кд 2 хода). AoE щит (до 4 целей, 2 энергии, кд 3 хода).",

    -- Названия типов действий (Core/Config.lua, ActionTypeNames)
    ["core.action.simple_roll"] = "Простой бросок",
    ["core.action.buff"] = "Бафф",
    ["core.action.aoe_buff"] = "АоЕ Бафф",
    ["core.action.attack"] = "Атака",
    ["core.action.aoe_attack"] = "АоЕ Атака",
    ["core.action.wound_removal"] = "Снятие раны",
    ["core.action.dispel"] = "Диспел",
    ["core.action.purge"] = "Пурж",

    -- ══════════════════════════════════════════════════════
    -- ОБЩИЕ ПРОВЕРКИ (Core/Utils.lua)
    -- Префикс — название действия, поэтому подставляется отдельным %s.
    -- ══════════════════════════════════════════════════════
    ["core.util.not_your_turn_action"] = "%s: сейчас не ваш ход!",
    ["core.util.not_enough_energy_detail"] = "%sНедостаточно энергии! (нужно %s, есть %s)",
    ["core.util.select_player_prefixed"] = "%sВыберите игрока!",
    ["core.util.ui_scale_set"] = "Масштаб UI установлен: %s",
    ["core.util.ui_scale_reset"] = "Масштаб UI сброшен на автоматический",

    -- ══════════════════════════════════════════════════════
    -- БАЗА NPC (Data/Units.lua)
    -- ══════════════════════════════════════════════════════
    ["core.units.removed_log"] = "Удалил NPC '%s'",
    ["core.units.cleared_log"] = "Очистил базу всех NPC",
    ["core.units.cleared"] = "База NPC очищена",
    ["core.units.clear_confirm"] = "Удалить ВСЕ данные о NPC?",
    ["core.units.dead"] = "|cFFFF0000Мёртв|r",
    ["core.units.stat_line"] = " |cFF888888[С:%s Сн:%s В:%s]|r",
    ["core.units.list_empty"] = "Список пуст",
    ["core.units.import_removed"] = "Импорт: удалён NPC '%s' — отсутствовал в полученном дампе",

    -- ══════════════════════════════════════════════════════
    -- СЛЭШ-АЛИАСЫ (Core/Aliases.lua)
    -- ══════════════════════════════════════════════════════
    ["core.alias.removed"] = "Удалено: %s",
    ["core.alias.queue_with_leader"] = "С ведущим в очереди",
    ["core.alias.extra_turn_cancelled"] = "Внеочередной ход отменён.",
    ["core.alias.passive_removed"] = "Снята пассивка: %s с %s",
    ["core.alias.buff_removed"] = "Снят бафф: %s с %s",
    ["core.alias.debuff_removed"] = "Снят дебафф: %s с %s",
    ["core.alias.all_effects_removed"] = "Все эффекты сняты с %s",

    -- ══════════════════════════════════════════════════════
    -- ХАРАКТЕРИСТИКИ И СОСТОЯНИЕ (Data/Stats.lua)
    -- ══════════════════════════════════════════════════════
    ["core.stats.points_gained"] = "+%d %s характеристик!",
    ["core.stats.hp_gained"] = "+%s к максимальному здоровью!",
    ["core.stats.energy_gained"] = "+%s к максимальной энергии!",
    ["core.stats.level_up"] = "═══ УРОВЕНЬ %s! ═══",
    -- Формулировка намеренно нейтральная: мастер может и понизить уровень.
    ["core.stats.level_reached_log"] = "%s — теперь уровень %s",
    ["core.stats.level_down"] = "═══ Уровень понижен до %s ═══",
    ["core.stats.points_trimmed"] = "Снято очков характеристик: %s — новый уровень даёт меньше.",
    ["core.stats.role_set"] = "Роль: %s",
    ["core.stats.role_reset"] = "Роль сброшена",
    ["core.stats.already_critical"] = "Вы уже в критическом состоянии! Судьба решается мастером.",
    ["core.stats.critical_wound"] = "КРИТИЧЕСКОЕ РАНЕНИЕ! Вы без сознания. Судьбу решает мастер.",
    -- %% — экранированный процент: строка идёт через string.format
    ["core.stats.wound_received"] = "Получено ранение! Штраф: %s ко всем характеристикам. HP восстановлено на %s%%",
    ["core.stats.no_wounds"] = "Нет ранений для снятия",
    ["core.stats.critical_wound_healed"] = "Критическое ранение снято! Осталось обычное ранение (штраф %s).",
    ["core.stats.wound_healed"] = "Ранение исцелено!",
    ["core.stats.all_wounds_healed"] = "Все ранения исцелены!",
    ["core.stats.shield_absorbed"] = "Щит поглотил весь урон (%s)!",
    ["core.stats.shield_broken"] = "Щит разрушен!",
    ["core.stats.distributed"] = "Характеристики распределены!",
    ["core.stats.hp_max"] = "Здоровье на максимуме!",
    ["core.stats.hp_min"] = "Здоровье на минимуме!",
    ["core.stats.hp_line"] = "Здоровье: %s",
    ["core.stats.value_change"] = "%s/%s (%s%s)",
    ["core.stats.hp_change_log"] = "%s изменил здоровье: %d → %d (%+d)",
    ["core.stats.reset"] = "Характеристики сброшены",
    ["core.stats.full_reset"] = "Персонаж полностью сброшен",
    ["core.stats.energy_gained_amount"] = "+%s энергии (%s/%s)",
    ["core.stats.energy_restored"] = "Энергия восстановлена: %s/%s",
    ["core.stats.energy_max"] = "Энергия на максимуме!",
    ["core.stats.energy_min"] = "Энергия на минимуме!",
    ["core.stats.energy_line"] = "Энергия: %s",

    -- Лист персонажа (/dof stats)
    ["core.stats.sheet_header"] = "|cFFFFD700=== DoF Персонаж ===|r",
    ["core.stats.sheet_level"] = "Уровень: |cFFFFD700%s/%s|r",
    ["core.stats.sheet_role"] = "Роль: |cFF%s%s|r",
    ["core.stats.sheet_critical"] = "|cFFFF0000КРИТИЧЕСКОЕ РАНЕНИЕ|r (без сознания, судьбу решает мастер)",
    ["core.stats.sheet_wound"] = "Ранение: |cFFFF6666штраф %s ко всем характеристикам|r",
    ["core.stats.sheet_shield"] = "Щит: |cFF66CCFF%s|r",
    ["core.stats.sheet_energy"] = "Энергия: %s/%s",
    ["core.stats.sheet_points"] = "Очков: |cFFFFD700%s/%s|r",
    ["core.stats.sheet_next_point"] = "След. очко на уровне: |cFF66CCFF%s|r",

    -- ══════════════════════════════════════════════════════
    -- ЗАГРУЗКА И ОБСЛУЖИВАНИЕ (Core/Init.lua)
    -- ══════════════════════════════════════════════════════
    ["core.init.pruned_npcs"] = "|cFFAAAAAA[DoF]|r Удалено устаревших NPC из базы: %s",
    ["core.init.prefix_failed"] = "|cFFFF3333[DoF]|r ОШИБКА: не удалось зарегистрировать префикс '%s'. Синхронизация не будет работать. Попробуйте /reload, либо отключите часть других аддонов.",
    ["core.init.loaded"] = "v%s загружен! /dof для справки",
    ["core.init.stale_data_confirm"] = "Обнаружены данные NPC от прошлой сессии (%s шт.).\nОчистить данные NPC?",
    ["core.init.clear"] = "Очистить",
    ["core.init.keep"] = "Оставить",
    ["core.init.stale_data_cleared"] = "Данные NPC от прошлой сессии очищены",
    ["core.init.data_sent"] = "Данные отправлены",
    ["core.init.request_sent"] = "Запрос отправлен",
    ["core.init.frames_reset"] = "Позиции Unit Frames сброшены",
    ["core.init.system_messages"] = "Системные сообщения: %s",
    ["core.init.on"] = "ВКЛ",
    ["core.init.off"] = "ВЫКЛ",
    ["core.init.version_request_sent"] = "Запрос версий отправлен...",
    ["core.init.versions_header"] = "|cFFFFD700[DoF]|r |cFF66CCFF=== Версии аддона ===|r",
    ["core.init.no_response"] = "|cFF888888  Не ответили (нет аддона?): %s|r",

    -- Окно «о аддоне»
    ["core.init.about_version"] = "Версия: %s",
    ["core.init.about_author"] = "Разработчик: %s",
    ["core.init.about_tagline"] = "Система пошагового боя для RP",

    -- Справка /dofxplevel
    ["core.init.level_header"] = "|cFFFFD700=== Уровень DoF ===|r",
    ["core.init.level_line"] = "Уровень: |cFFFFD700%s/%s|r",
    ["core.init.points_line"] = "Очки: |cFFFFD700%s/%s|r",
    ["core.init.base_hp_line"] = "Базовое HP: |cFF66FF66%s|r",
    ["core.init.max_energy_line"] = "Макс. энергия: |cFF66CCFF%s|r",

    -- Справка /dofframes и /dofbar
    ["core.init.help_frames"] = "  |cFF00FF00/dofframes|r — показать/скрыть фрейм игрока\n  |cFF00FF00/dofframes player|r — показать/скрыть фрейм игрока\n  |cFF00FF00/dofframes target|r — показать/скрыть фрейм цели\n  |cFF00FF00/dofframes reset|r — сбросить позиции\n  |cFF00FF00/dofframes lock|r — заблокировать перемещение",
    ["core.init.help_bar"] = "  |cFF00FF00/dofbar|r — показать/скрыть панель\n  |cFF00FF00/dofbar lock|r — заблокировать перемещение\n  |cFF00FF00/dofbar reset|r — сбросить позицию",
    ["core.init.help_combat"] = "|cFFFFD700=== Пошаговый бой ===|r\n  |cFF00FF00/dofcombat start [сек]|r — начать бой (таймер по умолчанию 60с)\n  |cFF00FF00/dofcombat end|r — окончить бой\n  |cFF00FF00/dofcombat skip|r — пропустить ход\n  |cFF00FF00/dofcombat npc|r — фаза NPC (мастер)\n  |cFF00FF00/dofcombat players|r — фаза игроков (мастер)\n  |cFF00FF00/dofcombat add <имя>|r — добавить в бой (мастер)\n  |cFF00FF00/dofcombat remove <имя>|r — убрать из боя (мастер)\n  |cFF00FF00/dofcombat free <имя>|r — внеочередной ход (мастер)\n  |cFF00FF00/dofcombat queue|r — окно очереди",

    -- ══════════════════════════════════════════════════════
    -- ПОДСКАЗКИ ПО СЛЭШ-КОМАНДАМ
    -- Строки «Использование: ...» — синтаксис команды, не переводятся дословно:
    -- сами имена команд и параметров остаются как есть.
    -- ══════════════════════════════════════════════════════
    ["core.usage.role"] = "Использование: /dofrole <игрок> tank|dd|healer|none",
    ["core.usage.roles_list"] = "Роли: tank, dd, healer, none",
    ["core.usage.wound"] = "Выберите игрока или укажите имя: /dofwound <игрок>",
    ["core.usage.healwound"] = "Выберите игрока или укажите имя: /dofhealwound <игрок>",
    ["core.usage.setrole"] = "Выберите игрока или укажите имя: /dofsetrole <игрок>",
    ["core.usage.resetstats"] = "Выберите игрока или укажите имя: /dofresetstats <игрок>",
    ["core.usage.setlevel"] = "Выберите игрока или укажите имя: /dofsetlevel <игрок> <уровень 1-20>",
    ["core.usage.giveenergy"] = "Выберите игрока или укажите имя: /dofgiveenergy <игрок>",
    ["core.usage.restoreenergy"] = "Выберите игрока или укажите имя: /dofrestoreenergy <игрок>",
    ["core.usage.aoebuff"] = "Использование: /dofaoebuff <effect_id>",
    ["core.usage.aoebuff_example"] = "Пример: /dofaoebuff empower_strength",
    ["core.usage.hp"] = "Использование: /dofhp [текущий/макс]",
    ["core.usage.attack"] = "Использование: /dofattack str|dex|int",
    ["core.usage.check"] = "Использование: /dofcheck str|dex|int|spi",
    ["core.usage.aoeattack"] = "Использование: /dofaoeattack str|dex|int",
    ["core.usage.combat_add"] = "Использование: /dofcombat add <имя>",
    ["core.usage.combat_remove"] = "Использование: /dofcombat remove <имя>",
    ["core.usage.combat_free"] = "Использование: /dofcombat free <имя>",
    ["core.usage.sethp"] = "Использование: /dofsethp <число>",
    ["core.usage.defense"] = "Использование: /dofdefense <стойк> <снор> <воля>",
    ["core.usage.modifynpchp"] = "Использование: /dofmodifynpchp +число или -число",
    ["core.usage.npcattack"] = "Использование: /dofnpcattack <игрок|%%t> <урон|мин-макс> <порог> <защита> [дебафф] [значение] [раунды]",
    ["core.usage.npcattack_example"] = "Пример: /dofnpcattack %%t 5-10 12 Fort",
    ["core.usage.npcattack_debuff"] = "С дебаффом: /dofnpcattack %%t 5-10 12 Fort stun 0 2",
    ["core.usage.npcattack_defense"] = "Защита: Fort(F), Ref(R), Will(W), Hybrid(H)",
    ["core.usage.modifyplayerhp"] = "Использование: /dofmodifyplayerhp <игрок|%%t> +число или -число",
    ["core.usage.giveshield"] = "Использование: /dofgiveshield <игрок>",
    ["core.usage.buff"] = "Использование: /dofbuff <игрок|%%t> <эффект> [значение] [раунды]",
    ["core.usage.buff_effects"] = "Эффекты: empower, fortify_fortitude, fortify_reflex, fortify_will, regeneration, blessing",
    ["core.usage.debuff"] = "Использование: /dofdebuff <игрок|%%t> <эффект> [значение] [раунды]",
    ["core.usage.debuff_effects"] = "Эффекты: stun, weakness_damage, weakness_healing, vulnerability_fortitude, vulnerability_reflex, vulnerability_will, dot_master",
    ["core.usage.npceffect"] = "Использование: /dofnpceffect <эффект> [значение] [раунды]",
    ["core.usage.npceffect_effects"] = "Эффекты: stun, weakness_fortitude, weakness_reflex, weakness_will, bleeding",

    -- ══════════════════════════════════════════════════════
    -- РЕЗУЛЬТАТЫ КОМАНД МАСТЕРА (Core/Init.lua)
    -- ══════════════════════════════════════════════════════
    ["core.cmd.npc_line"] = "%s: HP %s/%s [С:%s Сн:%s В:%s]",
    ["core.cmd.npc_no_hp"] = "%s: HP не задан",
    ["core.cmd.npc_data_removed"] = "Данные для %s удалены",
    ["core.cmd.defense_set"] = "%s: Стойк=%s, Снор=%s, Воля=%s",
    ["core.cmd.buff_applied"] = "Бафф |cFF00FF00%s|r наложен на |cFFFFFFFF%s|r",
    ["core.cmd.debuff_applied"] = "Дебафф |cFFFF6666%s|r наложен на |cFFFFFFFF%s|r",
    ["core.cmd.effect_applied"] = "Эффект |cFFFFD700%s|r наложен на |cFFFF6666%s|r",
    ["core.cmd.master_applies_log"] = "Мастер накладывает %s на %s (%s, %s р.)",
    ["core.cmd.npc_stunned"] = "|cFFFF6666%s|r оглушен на |cFFFFD700%s|r р.",
    ["core.cmd.npc_stunned_log"] = "Мастер оглушает %s на %s р.",
    ["locale.short"] = "RU",
})
