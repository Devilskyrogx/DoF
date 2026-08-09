-- DoF/Locale/ruRU/Combat.lua
-- Боевые сообщения: журнал боя, чат, результаты бросков.
--
-- ВАЖНО: эти строки рассылаются по сети уже отрендеренными
-- (Sync/Core.lua:BroadcastCombatLog принимает готовый текст). Пока протокол
-- не переведён на «ключ + аргументы», получатель видит язык отправителя.

local ADDON_NAME, DoF = ...

DoF.Locale:Register("ruRU", {
    -- ══════════════════════════════════════════════════════
    -- ИСХОДЫ БРОСКА
    -- Короткие слова, подставляются в строки результата ниже.
    -- ══════════════════════════════════════════════════════
    ["combat.result.crit_fail"] = "крит. провал",
    ["combat.result.crit_success"] = "крит. успех",
    ["combat.result.dodge"] = "уклонение",
    ["combat.result.success"] = "удачно",
    ["combat.result.fail"] = "неудачно",
    ["combat.result.fail_fatigue"] = "неудачно (усталость)",
    ["combat.result.reflected"] = "отражено",
    ["combat.result.crit_fail_excl"] = "крит. провал!",
    ["combat.result.crit_success_excl"] = "крит. успех!",
    ["combat.result.success_excl"] = "успех!",
    ["combat.result.failure"] = "неудача",

    -- ══════════════════════════════════════════════════════
    -- НАЗВАНИЯ ДЕЙСТВИЙ
    -- Подставляются в проверки «сейчас не ваш ход» и «не хватает энергии».
    -- ══════════════════════════════════════════════════════
    ["combat.action.attack"] = "Атака",
    ["combat.action.special"] = "Особое действие",
    ["combat.action.heal"] = "Лечение",
    ["combat.action.shield"] = "Щит",
    ["combat.action.remove_wound"] = "Снятие раны",
    ["combat.action.dispel"] = "Диспел",
    ["combat.action.purge"] = "Пурж",
    ["combat.action.restore_energy"] = "Восстановление энергии",

    -- ══════════════════════════════════════════════════════
    -- СТРОКИ БРОСКА И РЕЗУЛЬТАТА
    -- ══════════════════════════════════════════════════════
    ["combat.uses"] = "%s использует %s против %s.",
    ["combat.roll_result"] = "Результат: %s (%d+%d) %s %d - %s",
    ["combat.roll_result_simple"] = "Результат: %s (%d+%d)",
    ["combat.roll_line"] = "Бросок %s: %s (%d+%d) %s %d - %s",
    ["combat.roll_short"] = "Бросок: %s (%d+%d) %s %d - %s",
    ["combat.roll_short_no_threshold"] = "Бросок: %s (%d+%d) - %s",
    ["combat.reflected_damage"] = " |cFF66CCFFОтражённый урон: %s|r",
    ["combat.damage_suffix"] = " Урон: %s",
    ["combat.heal_suffix"] = " Лечение: %s",
    ["combat.check_line"] = "%s совершает проверку %s.",

    -- ══════════════════════════════════════════════════════
    -- УРОН, СМЕРТЬ, РЕАКТИВНЫЕ ЭФФЕКТЫ
    -- ══════════════════════════════════════════════════════
    ["combat.target_dead_msg"] = "%s — цель мертва!",
    ["combat.takes_damage"] = "%s получает %s урона! HP: %s",
    ["combat.poisoned_instant"] = "%s отравлен %s! Мгновенный урон: |cFFFF0000%d|r",
    ["combat.poisoned"] = "%s отравлен %s! (урон %d, %d р.)",
    ["combat.poison_log"] = "Яд %s → %s: -%d HP",
    ["combat.thorns_damage"] = "|cFFFF8800Шипы|r %s наносят |cFFFF0000%d|r урона %s!",
    ["combat.thorns_log"] = "Шипы %s → %s: -%d HP",
    ["combat.thorns_trigger"] = "|cFFFF8800Шипы|r %s срабатывают! Защищайтесь!",
    ["combat.berserk"] = "|cFFFF0000Берсерк!|r %s в ярости контратакует! Защищайтесь!",
    ["combat.counterattack"] = "|cFFFF6666Контратака!|r %s наносит ответный удар! Защищайтесь!",

    -- ══════════════════════════════════════════════════════
    -- КРИТ-БОНУСЫ
    -- ══════════════════════════════════════════════════════
    ["combat.crit_bonus"] = "%s выбирает крит-бонус: %s",
    ["combat.crit_bonus_target"] = "%s выбирает крит-бонус: %s %s",
    ["combat.crit_bonus_damage"] = "%s выбирает крит-бонус: %s (урон %s -> %s)",
    ["combat.bonus_damage_label"] = "+%s к урону",
    ["combat.bonus_energy"] = "+1 энергия",
    ["combat.bonus_full_heal"] = "Полное исцеление",
    ["combat.bonus_shield_3"] = "+3 щита",
    ["combat.bonus_shield_1"] = "Щит (1 удар)",

    -- ══════════════════════════════════════════════════════
    -- ОСОБОЕ ДЕЙСТВИЕ
    -- ══════════════════════════════════════════════════════
    ["combat.special_performs"] = "%s совершает: %s (%s) - %s",
    ["combat.special_approved_by_gm"] = "одобрено мастером",
    ["combat.special_crit_fail_line"] = "%s пытается: %s (%s). Результат: %s (%d+%d) - %s",
    ["combat.special_success_line"] = "%s совершает: %s (%s). Результат: %s (%d+%d) >= %d - %s",
    ["combat.special_fail_line"] = "%s пытается: %s (%s). Результат: %s (%d+%d) < %d - %s",
    ["combat.special_damage_log"] = "%s [Особое] -> %s: Урон %s",
    ["combat.special_done"] = "Особое действие (%s) завершено! Целей: %s",
    ["combat.special_cancelled"] = "Особое действие отменено!",
    ["combat.targets_left"] = "Осталось целей: %s",

    -- Подсказки выбора цели
    ["combat.choose_n_buff_targets"] = "Выберите %s целей для баффа.",
    ["combat.choose_buff_target"] = "Выберите цель для баффа и нажмите кнопку применения.",
    ["combat.choose_npc_target"] = "Выберите NPC-цель для атаки.",
    ["combat.choose_n_npc_targets"] = "Выберите %s NPC-целей для атаки.",
    ["combat.choose_wound_target"] = "Выберите игрока для снятия раны.",
    ["combat.choose_dispel_target"] = "Выберите игрока для диспела.",
    ["combat.choose_purge_target"] = "Выберите NPC-цель для пуржа.",

    -- ══════════════════════════════════════════════════════
    -- БАФФЫ, РАНЫ, ДИСПЕЛ, ПУРЖ
    -- ══════════════════════════════════════════════════════
    ["combat.buff_applied"] = "Бафф %s наложен на %s",
    ["combat.buff_applied_log"] = "%s накладывает %s на %s (особое действие)",
    ["combat.no_wounds_target"] = "У %s нет ран для снятия.",
    ["combat.no_wounds_self"] = "У вас нет ранений.",
    ["combat.wound_removed_from"] = "Рана снята с %s",
    ["combat.wound_removed_name"] = "Рана снята с %s!",
    ["combat.wound_removed_success"] = "Рана успешно снята!",
    ["combat.wound_removed_log"] = "%s снимает рану с %s (особое действие)",
    ["combat.tries_remove_wound"] = "%s пытается снять рану с %s.",
    ["combat.no_debuffs_to_remove"] = "На цели нет дебаффов для снятия.",
    ["combat.tries_dispel"] = "%s пытается снять дебафф с %s.",
    ["combat.dispel_log"] = "%s снимает %s с %s!",
    ["combat.no_buffs_to_remove"] = "На цели нет баффов для снятия.",
    ["combat.tries_purge"] = "%s пытается снять бафф с %s.",
    ["combat.purge_passive_log"] = "%s снимает пассивку %s с %s!",
    ["combat.purge_log"] = "%s снимает бафф с %s (особое действие)",

    -- ══════════════════════════════════════════════════════
    -- ЛЕЧЕНИЕ, ЭНЕРГИЯ, ЩИТ
    -- ══════════════════════════════════════════════════════
    ["combat.heals"] = "%s исцеляет %s (%s).",
    ["combat.you_healed"] = "Вы восстановили %s HP! (%s/%s)",
    ["combat.target_healed"] = "%s восстановил %s HP! (%s/%s)",
    ["combat.target_healed_short"] = "%s восстановил %s HP!",
    ["combat.full_heal_hp"] = "Полное исцеление! HP: %s/%s",
    ["combat.full_heal_target"] = "Полное исцеление %s!",
    -- %s — форма слова «стак», выбирается через DoF.Locale:Plural
    ["combat.healing_fatigue"] = "Усталость лечения: %d %s. Порог хила: %s",
    ["combat.stacks_one"] = "стак",
    ["combat.stacks_few"] = "стака",
    ["combat.stacks_many"] = "стаков",
    ["combat.npc_fallback"] = "НПЦ",
    ["combat.energy_restored_log"] = "%s восстанавливает 1 энергию для %s",
    ["combat.shield_recently_broken_warn"] = "Щит %s недавно разрушен!",
    ["combat.shield_already_active"] = "Щит уже активен!",
    ["combat.shield_already_active_on"] = "Щит уже активен на %s!",
    ["combat.shield_applied_log"] = "%s накладывает щит на %s. Следующий урон будет полностью поглощён.",
    ["combat.shield_applied_you"] = "Вы наложили щит на %s. Следующий урон будет полностью поглощён.",

    -- ══════════════════════════════════════════════════════
    -- ЗАЩИТА, ТАНК, ПРОВОКАЦИЯ (Combat/Defense.lua)
    -- ══════════════════════════════════════════════════════
    ["combat.result.crit_defense"] = "крит. защита",
    ["combat.action.taunt"] = "Провокация",
    ["combat.action.mass_taunt"] = "Массовая провокация",
    ["combat.action.redirect"] = "Перехват урона",

    ["combat.label.counterattack"] = "Контратака",
    ["combat.label.taunt"] = "Провокация",
    ["combat.label.mass_taunt_acc"] = "Массовую провокацию",
    ["combat.label.redirect"] = "Перехват урона",
    ["combat.label.tank_hp"] = "+2 HP",
    ["combat.label.hybrid"] = "Гибрид",
    ["combat.label.gm"] = "Мастер",
    ["combat.label.gained"] = "получил",
    ["combat.label.lost"] = "потерял",
    ["combat.label.hp_added"] = "Добавлено",
    ["combat.label.hp_removed"] = "Отнято",
    ["combat.label.auto_fail"] = "автонеудача",

    ["combat.def.attacks"] = "%s атакует %s.",
    ["combat.def.defends_line"] = "%s защищается %s: %s (%d+%d) %s %d - %s",
    ["combat.def.debuff_suffix"] = "%s на %s р.",
    -- Тот же суффикс, но как отдельный кусок записи журнала: цвет и ведущий
    -- пробел внутри строки, потому что склейку делает получатель.
    ["combat.def.debuff_suffix_log"] = " |cFFCC8833%s на %s р.|r",
    ["combat.def.no_defense_line"] = "%s не успел защититься - %s!",
    ["combat.def.time_up_damage"] = "Время вышло! Получен урон: %s",
    ["combat.def.crit_defense_bonus"] = "%s выбирает крит защиты: %s",
    ["combat.def.crit_defense_bonus_damage"] = "%s выбирает крит защиты: %s (урон: %s)",
    ["combat.def.counter_damage_taken"] = "%s получает %s контратаки! HP: %s",
    ["combat.def.counter_prompt"] = "Контратака! Выберите цель NPC и нажмите |cFFFF6666Ударить|r. Урон: %s",
    ["combat.def.counter_timeout"] = "Время на контратаку истекло!",
    ["combat.def.counter_log"] = "%s [Контратака] -> %s: %s HP: %s",
    -- %% — экранированный процент: строка идёт через string.format
    ["combat.def.fighter_counter"] = "Боец: %s! (15%% шанс)",

    ["combat.def.tank_streak_broken"] = "Танк: серия защит прервана! Бафф %s снят.",
    ["combat.def.tank_streak_max"] = "Танк: максимальный уровень Стойкой защиты (%s) достигнут (3)",
    ["combat.def.tank_streak"] = "Танк: серия защит! %s (3 раунда)",
    ["combat.def.tank_streak_label"] = "Стойкая защита (%s) +%s",
    ["combat.def.tank_streak_log"] = "%s получает бафф Стойкая защита (%s) +%s",
    ["combat.def.shred_max_both"] = "Танк: пробитие защиты %s — максимум стаков достигнут на обоих статах!",
    ["combat.def.shred_max_stat"] = "Танк: максимум стаков пробития (%s) уже достигнут!",
    ["combat.def.shred_applied"] = "Танк: пробитие защиты! %s (%s/%s стаков)",
    ["combat.def.shred_label"] = "%s -%s",
    ["combat.def.shred_log"] = "%s пробивает защиту %s: %s",
    ["combat.def.tank_choose_ally"] = "Танк: выберите союзника для баффа %s!",
    ["combat.def.tank_hp_buff_applied"] = "Танк: %s получает %s (3 раунда)",
    ["combat.def.tank_hp_buff_log"] = "%s укрепляет %s (+2 HP)",

    ["combat.def.gm_hp_log"] = "%s %s %d HP (мастер). HP: %d/%d",
    ["combat.def.healed_log"] = "%s получил исцеление от %s. HP: %d/%d",
    ["combat.def.hp_change_msg"] = "%s %s HP игроку %s",
    ["combat.def.hp_change_log"] = "Изменил HP игрока '%s': %+d",
    ["combat.def.shield_already"] = "Щит уже активен! Новый щит не наложен.",
    ["combat.def.shield_broken"] = "Щит недавно разрушен! Новый щит не наложен.",
    ["combat.def.not_defended_yet"] = "%s ещё не защитился от предыдущей атаки!",
    ["combat.def.npc_attack_log"] = "%s атакует '%s': урон %s, порог %d, защита: %s",
    ["combat.def.debuff_log_suffix"] = ", дебафф: %s",

    ["combat.def.taunt_applied"] = "Танк: %s на %s!",
    ["combat.def.taunt_log"] = "%s провоцирует %s! NPC обязан атаковать танка (%d р.)",
    ["combat.def.mass_taunt_prompt"] = "Танк: %s! Выберите NPC (осталось: %s)",
    ["combat.def.taunt_progress"] = "Провокация: %s (осталось: %s)",
    ["combat.def.mass_taunt_log"] = "%s использует %s! (%d целей)",
    ["combat.def.mass_taunt_cancelled"] = "Массовая провокация отменена.",
    ["combat.def.redirect_log"] = "%s перехватывает следующую атаку за %s!",
    ["combat.def.redirect_absorb_log"] = "%s перехватывает урон за %s!",

    -- ══════════════════════════════════════════════════════
    -- AoE-РЕЖИМЫ (Combat/AoE.lua)
    -- ══════════════════════════════════════════════════════
    ["combat.action.aoe_attack"] = "AoE атака",
    ["combat.action.aoe_heal"] = "AoE лечение",
    ["combat.action.aoe_buff"] = "AoE бафф",
    ["combat.action.aoe_shield"] = "AoE щит",

    ["combat.result.crit_short"] = "крит!",
    ["combat.result.hit_short"] = "удар!",

    ["combat.aoe.activates"] = "%s активирует AoE %s!",
    ["combat.aoe.activates_heal"] = "%s активирует AoE исцеление!",
    ["combat.aoe.activates_shield"] = "%s активирует AoE щит! Целей: %s",
    ["combat.aoe.roll_crit"] = "Бросок: %s - %s! Целей: %s",
    ["combat.aoe.roll_success"] = "Бросок: %s - %s Целей: %s",
    ["combat.aoe.targets_line"] = "Целей: %s",
    ["combat.aoe.attack_log"] = "%s [AoE %s] -> %s: %s Урон: %s",
    ["combat.aoe.heal_log"] = "%s [AoE Исцеление] -> %s: %s Лечение: %s",

    ["combat.aoe.mode_active"] = "AoE режим активен! Выберите %s целей.",
    ["combat.aoe.heal_active"] = "AoE исцеление активно! Выберите %s союзников.",
    ["combat.aoe.buff_choose"] = "Выберите %s союзников для %s",
    ["combat.aoe.shield_active"] = "AoE щит активен! Выберите %s целей.",

    ["combat.aoe.hits_left"] = "Осталось ударов: %s",
    ["combat.aoe.heals_left"] = "Осталось исцелений: %s",
    ["combat.aoe.buffs_left"] = "Осталось баффов: %s",
    ["combat.aoe.shields_left"] = "Осталось щитов: %s",

    ["combat.aoe.attack_done"] = "AoE атака завершена! Поражено целей: %s",
    ["combat.aoe.heal_done"] = "AoE исцеление завершено! Исцелено союзников: %s",
    ["combat.aoe.buff_done"] = "AoE бафф завершён! Усилено союзников: %s",
    ["combat.aoe.shield_done"] = "AoE щит завершён! Защищено целей: %s",

    ["combat.aoe.attack_cancelled"] = "AoE атака отменена!",
    ["combat.aoe.heal_cancelled"] = "AoE исцеление отменено!",
    ["combat.aoe.buff_cancelled"] = "AoE бафф отменён!",
    ["combat.aoe.shield_cancelled"] = "AoE щит отменён!",

    ["combat.aoe.shield_applied"] = "Щит наложен на %s",
    ["combat.aoe.shield_already_here"] = "Щит уже активен! Выберите другую цель.",
    ["combat.aoe.shield_already_on"] = "Щит уже активен на %s! Выберите другую цель.",

    -- ══════════════════════════════════════════════════════
    -- ПОШАГОВЫЙ БОЙ (Combat/TurnSystem*.lua)
    -- ══════════════════════════════════════════════════════
    ["combat.turn.round_header"] = "|cFFFFD700══ Раунд %s ══|r",
    ["combat.turn.stun_starts"] = "%s начинает действовать на %s",
    ["combat.turn.all_incapacitated"] = "Все участники небоеспособны — переход к фазе NPC",
    ["combat.turn.all_stunned"] = "Все участники оглушены — переход к фазе NPC",
    ["combat.turn.skip_critical"] = "%s пропускает ход (критическое ранение)",
    ["combat.turn.skip_stun"] = "%s пропускает ход (оглушение, осталось: %s)",
    ["combat.turn.you_unconscious"] = "Вы без сознания — ход пропущен. Ждите решения мастера.",
    -- %s — форма слова «раунд», выбирается через DoF.Locale:Rounds
    ["combat.turn.you_stunned"] = "Вы оглушены и пропускаете ход! Осталось %d %s",
    ["combat.turn.fatigue_cleared"] = "Усталость лечения полностью снята!",
    ["combat.turn.fatigue_reduced"] = "Усталость лечения снижена до %d %s. Порог: %s",
    ["combat.turn.state_synced"] = "Состояние боя синхронизировано: раунд %s, фаза: %s",
    ["combat.turn.unknown_player"] = "неизвестный игрок",
    ["combat.turn.extra_turn_self"] = "|cFFFFD700Вы назначили себе внеочередной ход.|r Выполните действие.",
    ["combat.turn.extra_turn_you"] = "|cFFFFD700Вам дан внеочередной ход!|r Выполните действие.",
    ["combat.turn.extra_turn_given"] = "|cFFFFD700Внеочередной ход|r дан игроку %s.",
    ["combat.turn.extra_turn_log"] = "Внеочередной ход дан игроку %s.",

    -- ══════════════════════════════════════════════════════
    -- БЕЗОПАСНОСТЬ СИНХРОНИЗАЦИИ (Sync/Security.lua)
    -- ══════════════════════════════════════════════════════
    ["combat.sec.blocked"] = "Заблокировано: %s от %s (%s)",
    ["combat.sec.not_in_group"] = "не в группе",
    ["combat.sec.not_master"] = "не является мастером",
    ["combat.sec.confirm"] = "|cFFFFFFFFПодтвердить|r",
    ["combat.sec.decline"] = "|cFFFFFFFFОтклонить|r",
    ["combat.sec.from"] = "От: |cFFA06AF1%s|r",
    ["combat.sec.declined"] = "Действие отклонено",
    ["combat.sec.timeout"] = "Время на подтверждение истекло — действие отклонено",

    -- ══════════════════════════════════════════════════════
    -- СИНХРОНИЗАЦИЯ (Sync/Core.lua, Sync/Handlers.lua)
    -- ══════════════════════════════════════════════════════
    ["combat.sync.no_npc_data"] = "DoF: данные NPC не получены — нажмите «Обновить» на панели действий",
    ["combat.sync.timeout_retry"] = "Таймаут данных NPC, повтор (%s/%s)...",
    ["combat.sync.not_in_group"] = "Вы не в группе — данные брать не у кого.",
    ["combat.sync.wait_before_retry"] = "Подождите %sс перед повторным запросом...",
    ["combat.sync.requested_target"] = "Запрошены данные текущей цели...",
    ["combat.sync.requested_all"] = "Запрошены данные всех NPC у ведущего...",
    ["combat.sync.you_are_master"] = "Вы стали ведущим сессии",
    ["combat.sync.recovery_failed"] = "Не удалось получить данные восстановления ни от одного игрока",
    ["combat.sync.recovery_no_candidates"] = "Восстановление: нет доступных кандидатов",
    ["combat.sync.recovery_request"] = "Запрос восстановления от %s (попытка %s)",
    ["combat.sync.message_too_big"] = "Sync: сообщение %s = %s байт (> %s). AceComm чанкирует, но проверьте payload.",
    ["combat.sync.turn_change_no_ack"] = "TURN_CHANGE не подтверждён после %s попыток",
    ["combat.sync.action_done_no_ack"] = "ACTION_DONE не подтверждён — мастер мог не получить",
    ["combat.sync.in_reliable"] = "%s (в RELIABLE)",
    ["combat.sync.master_silent"] = "Ведущий '%s' не отвечает %sс. Возможно, ему нужен /reload или /promote новому ведущему.",
    ["combat.sync.master_is"] = "Мастер: %s",
    ["combat.sync.data_from_master"] = "Данные от мастера: %s NPC",
    ["combat.sync.data_from_group"] = "Восстановлено от группы: %s NPC",
    ["combat.sync.format_unsupported"] = "FULLDATA3 формат v%s не поддерживается — обновите аддон",
    ["combat.sync.hpchange_rejected"] = "HPCHANGE отклонён: ver %s < %s от %s",
    ["combat.sync.no_role_chosen"] = "[DoF] Игрок %s не выбрал роль!",
    ["combat.sync.desync_resync"] = "Рассинхрон NPC-данных, запрос ресинка...",

    -- Действия мастера над игроком
    ["combat.sync.spec_set"] = "Специализация игрока %s: %s",
    ["combat.sync.level_set"] = "Уровень игрока %s: %s",
    ["combat.sync.spec_removed"] = "снята",
    ["combat.sync.spec_log"] = "Установил спек '%s' игроку '%s'",
    ["combat.sync.wound_added"] = "Добавлено ранение игроку %s",
    ["combat.sync.wound_added_log"] = "Добавил ранение игроку '%s'",
    ["combat.sync.wound_removed"] = "Снято ранение с игрока %s",
    ["combat.sync.wound_removed_log"] = "Снял ранение с игрока '%s'",
    ["combat.sync.stats_reset"] = "Сброшены статы игрока %s",
    ["combat.sync.stats_reset_log"] = "Сбросил статы игрока '%s'",
    ["combat.sync.shield_given"] = "Дан щит игроку %s",
    ["combat.sync.shield_given_log"] = "Дал щит игроку '%s'",
    ["combat.sync.energy_given"] = "Дано %s игроку %s",
    ["combat.sync.energy_taken"] = "Отнято %s у игрока %s",
    ["combat.sync.energy_amount"] = "%s энергии",
    ["combat.sync.energy_received"] = "Получено %s от %s",
    ["combat.sync.energy_removed_by_master"] = "Мастер отнял %s",
    ["combat.sync.energy_from_healer"] = "Получено %s от целителя %s",

    -- Сообщения игроку
    ["combat.sync.special_rejected"] = "|cFFFF6666Особое действие отклонено.|r",
    ["combat.sync.special_rejected_by_master"] = "|cFFFF6666Мастер отклонил ваше особое действие.|r",
    ["combat.sync.hp_changed_log"] = "%s изменил здоровье: %s → %s (%s%d)",
    ["combat.sync.full_heal_from"] = "Полное исцеление от %s! HP: %s/%s",
    ["combat.sync.role_removal_title"] = "Снятие роли",
    ["combat.sync.role_removal_text"] = "%s хочет снять вашу роль |cFFA06AF1%s|r.\n\nПодтвердить?",
    ["combat.sync.role_removed_by"] = "Роль снята мастером %s",
    ["combat.sync.role_changed_by"] = "Роль изменена на %s мастером %s",
    ["combat.sync.level_raised_by"] = "Уровень повышен до %s мастером %s",
    ["combat.sync.level_lowered_by"] = "Уровень понижен до %s мастером %s",
    ["combat.sync.wound_from"] = "Получено ранение от %s",
    ["combat.sync.wound_removed_by"] = "%s снял с вас рану!",
    ["combat.sync.stats_reset_title"] = "Сброс характеристик",
    ["combat.sync.stats_reset_text"] = "%s хочет |cFFFF0000СБРОСИТЬ|r ваши характеристики!\n\n|cFFFF6666Это удалит:|r\n- Роль\n- Распределённые очки\n\nПодтвердить?",
    ["combat.sync.stats_reset_by"] = "Характеристики сброшены мастером %s",
    ["combat.sync.shield_from_master"] = "Получен щит от мастера!",

    -- Подтверждения
    ["combat.sync.confirmed"] = "%s |cFF66FF66подтвердил|r: %s",
    ["combat.sync.confirmed_log"] = "%s подтвердил: %s",
    ["combat.sync.declined"] = "%s |cFFFF6666отклонил|r: %s",
    ["combat.sync.declined_log"] = "%s отклонил: %s",
    ["combat.sync.no_answer"] = "%s не ответил вовремя: %s",
    ["combat.sync.no_answer_log"] = "%s не ответил: %s",

    -- Бросок на выживание
    ["combat.sync.survival_line"] = "%s — бросок на выживание (%s): %s (%d%s) против DC %d → %s",
    ["combat.sync.survival_success"] = "УСПЕХ",
    ["combat.sync.survival_fail"] = "ПРОВАЛ",
    ["combat.sync.death_line"] = "%s не пережил ранения. Персонаж погибает.",
})
