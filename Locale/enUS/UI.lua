-- DoF/Locale/enUS/UI.lua
-- Interface: buttons, window titles, field labels, tooltips.
-- Keys prefixed "xml." become DoF_L_* globals for UI/Frames.xml
-- (see Locale/Globals.lua).

local ADDON_NAME, DoF = ...

DoF.Locale:Register("enUS", {
    -- ══════════════════════════════════════════════════════
    -- XML: UI/Frames.xml
    -- ══════════════════════════════════════════════════════
    ["xml.attack"] = "Attack",
    ["xml.by_initiative"] = "By initiative order",
    ["xml.check_versions"] = "Check Versions",
    ["xml.clear_all_npcs"] = "Clear All NPCs",
    ["xml.combat_control_caps"] = "COMBAT CONTROL",
    ["xml.combat_settings_caps"] = "COMBAT SETTINGS",
    ["xml.damage"] = "Damage",
    ["xml.debuff"] = "Debuff",
    ["xml.defense_short"] = "Def.",
    ["xml.energy_caps"] = "ENERGY",
    ["xml.energy_minus_1"] = "-1 Energy",
    ["xml.energy_plus_1"] = "+1 Energy",
    ["xml.level_minus_1"] = "-1 Level",
    ["xml.level_plus_1"] = "+1 Level",
    ["xml.enemy_turn"] = "Enemy Turn",
    ["xml.extra_turn"] = "Extra Turn",
    ["xml.fortitude_caps"] = "FORT",
    ["xml.fortitude_short"] = "Fort.",
    ["xml.free_queue"] = "Free Order",
    ["xml.full_energy"] = "Full Energy",
    ["xml.give_shield"] = "Give Shield",
    ["xml.instant_defense"] = "Instant Defense",
    ["xml.name"] = "Name",
    ["xml.no"] = "No",
    ["xml.npc_attack"] = "NPC Attack",
    ["xml.npc_library"] = "NPC Library",
    ["xml.npc_setup"] = "NPC Setup",
    ["xml.gm_panel_title"] = "GM PANEL",
    ["xml.player_hp_title"] = "Player HP",
    ["xml.tab_npc"] = "NPC",
    ["xml.tab_player"] = "Player",
    ["xml.tab_combat"] = "Combat",
    ["xml.tab_effects"] = "Effects",
    ["xml.player_control_caps"] = "PLAYER CONTROL",
    ["xml.player_role_caps"] = "PLAYER ROLE",
    ["xml.queue_no_leader"] = "No queue leader",
    ["xml.reflex_caps"] = "REFL",
    ["xml.remove"] = "Remove",
    ["xml.reset_stats"] = "Reset Stats",
    ["xml.round_short"] = "Rnd.",
    ["xml.seconds_short"] = "sec",
    ["xml.set_role"] = "Set Role",
    ["xml.set_level"] = "Set Level",
    ["xml.skip"] = "Skip",
    ["xml.start_combat"] = "Start Combat",
    ["xml.sync"] = "Sync",
    ["xml.threshold"] = "Threshold",
    ["xml.use_timer"] = "Use timer",
    ["xml.utilities_caps"] = "UTILITIES",
    ["xml.value_short"] = "Val.",
    ["xml.will_caps"] = "WILL",
    ["xml.wound_add"] = "+Wound",
    ["xml.wound_remove"] = "-Wound",

    -- ══════════════════════════════════════════════════════
    -- Nameplate floating text (UI/Nameplates.lua)
    -- ══════════════════════════════════════════════════════
    ["ui.nameplate.crit_fail"] = "Critical fail!",
    ["ui.nameplate.crit_damage"] = "Crit! -%d",
    ["ui.nameplate.crit_heal"] = "Crit! +%d HP",
    ["ui.nameplate.hit"] = "Hit! -%d",
    ["ui.nameplate.miss"] = "Miss!",

    -- ══════════════════════════════════════════════════════
    -- SHARED VOCABULARY
    -- Words that repeat across windows. One key per word — otherwise the
    -- translation drifts: "Buff" in one window, "Empower" in the next.
    -- ══════════════════════════════════════════════════════
    ["ui.common.buff"] = "Buff",
    ["ui.common.debuff"] = "Debuff",
    ["ui.common.damage"] = "Damage",
    ["ui.common.healing"] = "Healing",
    ["ui.common.shield"] = "Shield",
    ["ui.common.skip"] = "Skip",
    ["ui.common.dot"] = "Damage over Time",
    ["ui.common.target_dead"] = "Target is dead",
    ["ui.common.cancel"] = "Cancel",
    ["ui.common.cancel_colored"] = "|cFF888888Cancel|r",
    ["ui.common.cancel_verb"] = "Cancel",
    ["ui.common.finish"] = "Finish",
    ["ui.common.apply"] = "Apply",
    ["ui.common.none"] = "None",
    ["ui.common.yes"] = "Yes",
    ["ui.common.no"] = "No",

    -- ══════════════════════════════════════════════════════
    -- Action menu: section headers (UI/Dialogs.lua)
    -- ══════════════════════════════════════════════════════
    ["ui.menu.attack_header"] = "- Attack -",
    ["ui.menu.special_header"] = "- Special Action -",
    ["ui.menu.heal_header"] = "- Healing -",
    ["ui.menu.shield_header"] = "- Shield -",
    ["ui.menu.wounds_header"] = "- Wounds -",
    ["ui.menu.dispel_header"] = "- Dispel -",
    ["ui.menu.offensive_header"] = "- Offensive -",
    ["ui.menu.defensive_header"] = "- Defensive -",
    ["ui.menu.aoe_header_short"] = "- AoE (%d en.) -",
    ["ui.menu.aoe_attack_header"] = "- AoE Attack (%d energy) -",
    ["ui.menu.aoe_heal_header"] = "- AoE Healing (%d energy) -",
    ["ui.menu.effects_header_short"] = "- Effects (%d en.) -",
    ["ui.menu.effects_header"] = "- Effects (%d energy) -",
    ["ui.menu.effects_on"] = "- Effects on %s -",
    ["ui.menu.no_actions"] = "No actions available",
    ["ui.menu.no_effects"] = "|cFF666666No effects available|r",
    -- The suffix is appended to an action name, hence the leading space
    ["ui.menu.no_energy_suffix"] = " |cFF666666(not enough energy)|r",

    -- ══════════════════════════════════════════════════════
    -- Player actions (UI/Dialogs.lua)
    -- ══════════════════════════════════════════════════════
    ["ui.action.attack_of"] = "Attack: %s",
    ["ui.action.attack_str_desc"] = "d20 roll + Strength. A powerful melee attack.",
    ["ui.action.attack_dex_desc"] = "d20 roll + Dexterity. A precise strike or shot.",
    ["ui.action.attack_int_desc"] = "d20 roll + Intelligence. A magic attack.",
    ["ui.action.special"] = "Special Action",
    ["ui.action.special_colored"] = "|cFF9966FFSpecial Action|r",
    ["ui.action.special_desc"] = "d20 roll + a stat chosen by the GM.\nThe GM sets the threshold.\nEnergy: at the GM's discretion.",
    ["ui.action.heal_desc"] = "d20 roll + Spirit. Restores an ally's HP.",
    ["ui.action.shield"] = "Apply Shield",
    ["ui.action.shield_desc"] = "d20 roll + Spirit. Creates a shield that absorbs damage.",
    ["ui.action.remove_wound"] = "Remove Wound",
    ["ui.action.remove_wound_title"] = "Remove Wound (Healer)",
    ["ui.action.remove_wound_desc"] = "d20 roll + Spirit against a threshold of 16. On success removes one wound from the target.",
    ["ui.action.apply_dot"] = "Apply DoT",
    ["ui.action.apply_dot_desc"] = "Applies a damage effect to the NPC.\nDamage each round for several rounds.",
    ["ui.action.weaken_npc"] = "Weaken NPC",
    ["ui.action.weaken"] = "Weakness",
    ["ui.action.weaken_desc"] = "Lowers an NPC defensive stat by 1-3 (random) for 3 rounds.\nChoose: Fortitude, Reflex or Will.\nCost: 1 energy",
    ["ui.action.dispel"] = "Remove Debuff",
    ["ui.action.dispel_title"] = "Dispel",
    ["ui.action.dispel_desc"] = "Removes one debuff from an ally.\nCost: 1 energy",

    -- ══════════════════════════════════════════════════════
    -- AoE modes (UI/Dialogs.lua)
    -- ══════════════════════════════════════════════════════
    ["ui.aoe.remaining"] = "Remaining: %d",
    ["ui.aoe.attack_desc"] = "From %d to %d targets. Damage x0.5.\nCost: %d energy",
    ["ui.aoe.hit_target"] = "Strike Target",
    ["ui.aoe.hit_title"] = "AoE Strike",
    ["ui.aoe.hit_desc"] = "Deals damage to the chosen target.\nA target cannot be attacked twice.",
    ["ui.aoe.finish_attack"] = "Finish AoE",
    ["ui.aoe.finish_attack_desc"] = "Ends the AoE attack early.",
    ["ui.aoe.heal_header"] = "- AoE Healing -",
    ["ui.aoe.heal_label"] = "AoE Healing",
    ["ui.aoe.heal_target"] = "Heal Target",
    ["ui.aoe.heal_title"] = "AoE Healing",
    ["ui.aoe.heal_desc"] = "Heals the chosen ally.\nAn ally cannot be healed twice.",
    ["ui.aoe.heal_desc_full"] = "From %d to %d allies. Healing x0.5.\nCost: %d energy",
    ["ui.aoe.finish_heal_desc"] = "Ends the AoE healing early.",
    ["ui.aoe.buff_target"] = "Buff Target",
    ["ui.aoe.buff_title"] = "AoE Buff",
    ["ui.aoe.buff_desc"] = "Applies %s to the chosen ally.\nAn ally cannot be buffed twice.",
    ["ui.aoe.finish_buff_desc"] = "Ends the AoE buff early.",
    ["ui.aoe.buff_hint"] = "%d energy, up to %d targets",

    -- ══════════════════════════════════════════════════════
    -- Buff application window (UI/Dialogs.lua)
    -- ══════════════════════════════════════════════════════
    ["ui.buff.section_empower"] = "Empower",
    ["ui.buff.section_fortify"] = "Fortify",
    ["ui.buff.section_healer"] = "Healer",
    ["ui.buff.target"] = "Target: %s",
    ["ui.buff.hint"] = "3 rounds, 1 energy",

    -- Short buff names for narrow buttons — kept apart from the full
    -- effects.*.name, whose wording is longer.
    ["ui.buff.empower_strength.name"] = "Empower (Str)",
    ["ui.buff.empower_strength.desc"] = "+2 Strength",
    ["ui.buff.empower_dexterity.name"] = "Empower (Dex)",
    ["ui.buff.empower_dexterity.desc"] = "+2 Dexterity",
    ["ui.buff.empower_intelligence.name"] = "Empower (Int)",
    ["ui.buff.empower_intelligence.desc"] = "+2 Intelligence",
    ["ui.buff.empower_spirit.name"] = "Empower (Spr)",
    ["ui.buff.empower_spirit.desc"] = "+2 Spirit",
    ["ui.buff.empower_damage.name"] = "Empower (Dmg)",
    ["ui.buff.empower_damage.desc"] = "+1 Damage",
    ["ui.buff.empower_healing.name"] = "Empower (Heal)",
    ["ui.buff.empower_healing.desc"] = "+1 Healing",
    ["ui.buff.fortify_fortitude.name"] = "Fortify (Fort)",
    ["ui.buff.fortify_fortitude.desc"] = "+2 Fortitude",
    ["ui.buff.fortify_reflex.name"] = "Fortify (Refl)",
    ["ui.buff.fortify_reflex.desc"] = "+2 Reflex",
    ["ui.buff.fortify_will.name"] = "Fortify (Will)",
    ["ui.buff.fortify_will.desc"] = "+2 Will",
    ["ui.buff.fortify_hp.name"] = "Fortify (HP)",
    ["ui.buff.fortify_hp.desc"] = "+2 max HP",

    -- ══════════════════════════════════════════════════════
    -- GM dialogs (UI/Dialogs_Effects.lua)
    -- ══════════════════════════════════════════════════════
    ["ui.dlg.apply_buff_title"] = "Apply Buff",
    ["ui.dlg.vulnerability_title"] = "Vulnerability",
    ["ui.dlg.weaken_defense_title"] = "Weaken Defense",
    ["ui.dlg.weaken_hint"] = "-1..3 for 3 rounds, 1 energy",
    ["ui.dlg.value_label"] = "Value:",
    ["ui.dlg.rounds_label"] = "Rounds:",
    ["ui.dlg.penalty_label"] = "Penalty (-N):",
    ["ui.dlg.weaken_defense_label"] = "Weaken defense:",
    ["ui.dlg.reduce_label"] = "Reduce:",
    ["ui.dlg.defense_stat_label"] = "Defense stat:",
    ["ui.dlg.hybrid"] = "Hybrid",
    ["ui.dlg.mode_guaranteed"] = "Guaranteed",
    ["ui.dlg.mode_chance"] = "Chance",
    ["ui.dlg.special_approved"] = "Special action approved",
    ["ui.dlg.roll_dice"] = "Roll the dice!",
    ["ui.dlg.roll_dice_colored"] = "|cFFFFFFFFRoll the dice!|r",
    ["ui.dlg.no_roll"] = "|cFF00FF00No roll (auto-success)|r",
    ["ui.dlg.perform_action"] = "|cFFFFFFFFPerform the action!|r",
    ["ui.dlg.action_line"] = "|cFFFFD700Action:|r |cFF66CCFF%s%s|r",
    ["ui.dlg.roll_line"] = "Roll |cFF%s%s|r threshold %d",
    ["ui.dlg.energy_line"] = "  |  |cFF9966FFEnergy: %d|r",
    ["ui.dlg.damage_detail"] = " (damage %s-%s)",
    ["ui.dlg.damage_detail_multi"] = " (damage %s-%s x%s)",
    ["ui.dlg.duration_short"] = " (%s rnd)",
    ["ui.dlg.passive_suffix"] = " |cFF888888(passive)|r",
    ["ui.dlg.no_buffs"] = "The target has no buffs!",
    ["ui.dlg.no_debuffs"] = "The target has no debuffs!",
    ["ui.dlg.unpurgeable"] = "Unpurgeable",
    ["ui.dlg.purgeable"] = "Purgeable",
    ["ui.dlg.unpurgeable_colored"] = "|cFFFF4444Unpurgeable|r",
    ["ui.dlg.purgeable_colored"] = "|cFF66FF66Purgeable|r",
    ["ui.dlg.on"] = "|cFFFF6600ON|r",
    ["ui.dlg.off"] = "|cFF888888OFF|r",
    ["ui.dlg.passive_added"] = "Passive added: %s on %s",

    -- ══════════════════════════════════════════════════════
    -- Misc windows (UI/Dialogs_Misc.lua)
    -- ══════════════════════════════════════════════════════
    -- ══════════════════════════════════════════════════════
    -- Phase and mode banners (UI/TurnQueue_Panels.lua)
    -- ══════════════════════════════════════════════════════
    ["ui.panel.players_turn"] = "|cFFFFD700Players' turn!|r",
    ["ui.panel.your_turn"] = "|cFF00FF00YOUR TURN!|r\n|cFFAAAAAA(take an action or skip the turn)|r",
    ["ui.panel.enemy_turn_alert"] = "|cFFFF3333Enemy turn!|r",
    ["ui.panel.combat_over"] = "|cFFFFFFFFCOMBAT OVER|r",
    ["ui.panel.extra_turn_title"] = "|cFFFFD700EXTRA TURN|r",
    ["ui.panel.extra_turn_sub"] = "|cFFAAAAAA(take an action)|r",
    ["ui.panel.critical_wound_title"] = "|cFFFF0000CRITICAL WOUND!|r",
    ["ui.panel.critical_wound_sub"] = "|cFFFFCC00%s|r\n|cFFAAAAAAunconscious — decide their fate manually|r",
    ["ui.panel.aoe_attack_title"] = "AoE ATTACK",
    ["ui.panel.aoe_heal_title"] = "AoE HEALING",
    ["ui.panel.aoe_shield_title"] = "AoE SHIELD",
    ["ui.panel.counterattack_title"] = "COUNTERATTACK",
    ["ui.panel.tank_hp_buff_title"] = "+2 HP TO AN ALLY",
    ["ui.panel.mass_taunt_title"] = "Mass Taunt",
    ["ui.panel.hit"] = "Strike",
    ["ui.panel.heal"] = "Heal",
    ["ui.panel.buff"] = "Buff",
    ["ui.panel.apply"] = "Apply",
    ["ui.panel.taunt"] = "Taunt",
    ["ui.panel.done"] = "Done",
    ["ui.panel.choose_ally"] = "Choose an ally (target)",
    ["ui.panel.choose_target"] = "Choose a target",
    ["ui.panel.choose_npc_target"] = "Choose an NPC target",
    ["ui.panel.choose_player"] = "Choose a player",
    ["ui.panel.hits_left"] = "Strikes left: |cFFFFD700%s|r",
    ["ui.panel.shields_left"] = "Shields left: |cFFFFD700%s|r",
    ["ui.panel.left"] = "Left: |cFFFFD700%s|r",
    ["ui.panel.targets_left"] = "Targets left: |cFFFFD700%s|r",
    ["ui.panel.counter_damage"] = "Damage: |cFFFF0000%s|r — choose an NPC target",
    ["ui.panel.special_title"] = "SPECIAL: %s",

    -- Queue tracker header
    ["ui.queue.header"] = "Queue: |cFFFFD700%s|r%s",
    ["ui.queue.phase_enemy"] = "Enemy turn",
    ["ui.queue.phase_players"] = "Players' turn",
    ["ui.queue.waiting_count"] = " — |cFFFFFFFF%s waiting|r",
    ["ui.queue.mode_queue"] = "|cFFAAAAAAQueue|r",
    ["ui.queue.mode_free"] = "|cFFAAAAAAFree|r",
    ["ui.queue.round_enemy"] = "|cFFFFD700Round %s|r — |cFFFF3333Enemy turn|r",
    ["ui.queue.round_players"] = "|cFFFFD700Round %s — Players' turn|r",
    ["ui.queue.label_turn"] = "Turn: ",
    ["ui.queue.label_round"] = "Round: ",
    ["ui.queue.timer"] = "|cFF999999%s|r|cFF%s%d:%02d|r",

    -- ══════════════════════════════════════════════════════
    -- NPC dialogs for the GM (UI/Dialogs_NPC.lua)
    -- ══════════════════════════════════════════════════════
    ["ui.npcdlg.target_player"] = "|cFFFF6666%s (player)|r",
    ["ui.npcdlg.no_target"] = "|cFF888888No target|r",
    ["ui.npcdlg.no_player"] = "|cFF888888No player|r",
    ["ui.npcdlg.hp_not_set"] = "%s |cFFFF6666(HP not set)|r",
    ["ui.npcdlg.setup_summary"] = "%s: HP %s | Fort:%s Refl:%s Will:%s",
    ["ui.npcdlg.setup_log"] = "Configured NPC '%s': HP=%s, Fort=%s, Refl=%s, Will=%s",
    ["ui.npcdlg.modify_log"] = "Changed NPC HP '%s': %+d (HP: %d/%d)",
    ["ui.npcdlg.target_dead_msg"] = "%s - target is dead!",
    ["ui.npcdlg.attack_action"] = "NPC Attack",
    ["ui.npcdlg.actions_for"] = "Actions: %s",
    ["ui.npcdlg.change_hp"] = "|cFF66CCFFChange HP|r",
    ["ui.npcdlg.change_role"] = "|cFFA06AF1Change role|r",
    ["ui.npcdlg.add_wound"] = "|cFFFF6666Add wound|r",
    ["ui.npcdlg.remove_wound"] = "|cFF66FF66Remove wound|r",
    ["ui.npcdlg.debuff_weakness_damage"] = "Weak. damage",
    ["ui.npcdlg.debuff_weakness_healing"] = "Weak. healing",
    ["ui.npcdlg.debuff_vuln_fortitude"] = "Vuln. (Fort)",
    ["ui.npcdlg.debuff_vuln_reflex"] = "Vuln. (Refl)",
    ["ui.npcdlg.debuff_vuln_will"] = "Vuln. (Will)",
    ["ui.npcdlg.debuff_dot"] = "DoT",

    -- ══════════════════════════════════════════════════════
    -- Player and GM combat windows (UI/Dialogs_Combat.lua)
    -- ══════════════════════════════════════════════════════
    ["ui.combat.attacked_title"] = "You Are Attacked",
    ["ui.combat.check_title"] = "Check",
    ["ui.combat.defend_btn"] = "DEFEND",
    ["ui.combat.roll_btn"] = "ROLL",
    ["ui.combat.timer_sec"] = "|cFF%s%.1f sec|r",
    ["ui.combat.against_your"] = "Against your %s",
    ["ui.combat.choose_defense"] = "Choose a defense",
    ["ui.combat.crit_hit_title"] = "Critical Hit",
    ["ui.combat.crit_heal_title"] = "Critical Heal",
    ["ui.combat.crit_defense_title"] = "Critical Defense",
    ["ui.combat.choose_bonus"] = "Choose a bonus:",
    ["ui.combat.bonus_damage"] = "+%s damage",
    ["ui.combat.bonus_energy"] = "+1 energy",
    ["ui.combat.bonus_full_heal"] = "Full heal",
    ["ui.combat.bonus_shield"] = "Shield (1 hit)",
    ["ui.combat.bonus_counterattack"] = "Counterattack",
    ["ui.combat.bonus_ally_hp"] = "+2 HP to an ally",
    ["ui.combat.shield_activated"] = "Shield activated!",
    ["ui.combat.time_up_crit"] = "Time is up! The crit bonus was chosen at random.",
    ["ui.combat.time_up_defense"] = "Time is up! The defense bonus was chosen at random.",
    ["ui.combat.special_request_title"] = "Special Action Request",
    ["ui.combat.special_request_desc"] = "Describe your special action (up to 1000 characters)",
    ["ui.combat.send_request"] = "Send Request",
    ["ui.combat.you_are_gm_approve"] = "You are the GM - approve or reject your own action.",
    ["ui.combat.request_sent"] = "The special action request was sent to the GM. Await approval...",
    ["ui.combat.player_label"] = "|cFFFFFFFFPlayer:|r |cFF66CCFF%s|r",
    ["ui.combat.action_type_label"] = "Action type:",
    ["ui.combat.simple_action_label"] = "|cFFAAAAAAAction: %s (the target is chosen after the roll)|r",
    ["ui.combat.choose_effect"] = "Choose an effect:",
    ["ui.combat.target_count"] = "Target count:",
    ["ui.combat.damage_min"] = "Damage min:",
    ["ui.combat.damage_max"] = "max:",
    ["ui.combat.no_roll_label"] = "No roll (auto-success)",
    ["ui.combat.threshold_label"] = "Threshold:",
    ["ui.combat.stat_label"] = "Stat:",
    ["ui.combat.request_energy"] = "Request energy",
    ["ui.combat.approve"] = "Approve",
    ["ui.combat.reject"] = "Reject",
    ["ui.combat.special_approved_msg"] = "%s's special action was |cFF00FF00approved|r (%s).",
    ["ui.combat.special_rejected_msg"] = "%s's special action was |cFFFF6666rejected|r.",
    ["ui.combat.shred_title"] = "Defense Shred",
    ["ui.combat.shred_desc"] = "Lower %s's defense:",

    -- ══════════════════════════════════════════════════════
    -- Options panel in the game menu (UI/Settings.lua)
    -- ══════════════════════════════════════════════════════
    ["ui.opt.version"] = "|cFF888888Version %s|r",
    ["ui.opt.desc"] = "Combat system addon settings",
    ["ui.opt.log_header"] = "|cFFFFD700Combat Log|r",
    ["ui.opt.log_enable"] = "Enable the combat log",
    ["ui.opt.log_tooltip"] = "When enabled: all combat messages go to the log window.\nWhen disabled: combat messages go to chat and the log is unavailable.",
    ["ui.opt.log_desc"] = "Enabled: all combat logs appear in the log window (nothing in chat).\nDisabled: the log is unavailable, everything goes to chat only.",
    ["ui.opt.log_on"] = "Combat log enabled",
    ["ui.opt.log_off"] = "Combat log disabled, messages will go to chat",
    ["ui.opt.scale_header"] = "|cFFFFD700Window Scale|r",
    ["ui.opt.scale_slider"] = "Interface scale",
    ["ui.opt.scale_desc"] = "Changes the size of the main DoF window. A UI reload is required to apply it fully.",
    ["ui.opt.frames_header"] = "|cFFFFD700Compact Frames|r",
    ["ui.opt.player_frame"] = "Show the player frame",
    ["ui.opt.player_frame_tooltip"] = "Shows a compact frame with the player's HP, energy and effects.",
    ["ui.opt.target_frame"] = "Show the target frame (NPC)",
    ["ui.opt.target_frame_tooltip"] = "Shows a compact frame with the selected NPC's HP and defenses.",
    ["ui.opt.lock_frames"] = "Lock movement",
    ["ui.opt.lock_frames_tooltip"] = "Prevents dragging the frames with the mouse.",
    ["ui.opt.frames_scale"] = "Frame scale",
    ["ui.opt.reset_positions"] = "Reset positions",
    ["ui.opt.positions_reset"] = "Frame positions reset",
    ["ui.opt.actionbar_header"] = "|cFFFFD700Action Bar|r",
    ["ui.opt.actionbar_show"] = "Show the action bar",
    ["ui.opt.actionbar_tooltip"] = "Shows a floating bar with action buttons (attack, heal, etc.)",
    ["ui.opt.reset_settings"] = "Reset settings",
    ["ui.opt.reset_confirm"] = "Reset all DoF settings to their defaults?",
    ["ui.opt.settings_reset"] = "Settings reset to defaults",

    -- ══════════════════════════════════════════════════════
    -- Compact frames (UI/UnitFrames.lua)
    -- ══════════════════════════════════════════════════════
    ["ui.uf.no_data"] = "|cFF888888No data|r",
    ["ui.uf.loading"] = "Loading data...",
    ["ui.uf.fort_short"] = "Frt:",
    ["ui.uf.reflex_short"] = "Rfl:",
    ["ui.uf.will_short"] = "Wil:",
    ["ui.uf.fort_desc"] = "Defense against physical attacks (Strength)",
    ["ui.uf.reflex_desc"] = "Defense against precise attacks (Dexterity)",
    ["ui.uf.will_desc"] = "Defense against magic attacks (Intelligence)",
    ["ui.uf.wound"] = "Wound",
    ["ui.uf.critical_wound"] = "Critical Wound",
    ["ui.uf.critical_wound_desc_full"] = "Unconscious. All actions are blocked. Turns are skipped automatically. The GM decides their fate.",
    ["ui.uf.critical_wound_desc_short"] = "Unconscious. All actions are blocked. The GM decides their fate.",
    ["ui.uf.wound_penalty"] = "%s penalty to all stats",
    ["ui.uf.wound_penalty_generic"] = "Penalty to all stats",
    ["ui.uf.critical_wound_line"] = "CRITICAL WOUND (unconscious)",
    ["ui.uf.wound_line"] = "Wound (penalty %s)",
    ["ui.uf.role"] = "Role: %s",
    ["ui.uf.damage_range"] = "Damage: %s-%s",
    ["ui.uf.healing_range"] = "Healing: %s-%s",
    ["ui.uf.fatigue_threshold"] = " (threshold %s)",
    ["ui.uf.effect"] = "Effect",
    ["ui.uf.hp_bonus"] = "HP bonus: +%s",
    ["ui.uf.tank"] = "Tank: %s",
    -- %s — the plural form of "turn", picked by DoF.Locale:Plural
    ["ui.uf.remaining_turns"] = "Remaining: %d %s",
    ["ui.turns_one"] = "turn",
    ["ui.turns_few"] = "turns",
    ["ui.turns_many"] = "turns",
    ["ui.uf.frames_locked"] = "Frames locked",
    ["ui.uf.frames_unlocked"] = "Frames unlocked",

    -- ══════════════════════════════════════════════════════
    -- GM panel (UI/MainFrame_GM.lua)
    -- ══════════════════════════════════════════════════════
    ["ui.gm.shield_already"] = "A shield is already active on %s!",
    ["ui.gm.shield_given"] = "Shield given to NPC %s",
    ["ui.gm.shield_given_log"] = "Gave a shield to NPC '%s'",
    ["ui.gm.full_sync_done"] = "Full synchronization complete",
    ["ui.gm.energy_restored"] = "%s's energy was restored to maximum.",
    ["ui.gm.debuff_removed"] = "Debuff removed: %s from %s",
    ["ui.gm.all_effects_removed"] = "All effects removed from %s",
    ["ui.gm.passive_removed"] = "Passive removed: %s from %s",
    ["ui.gm.weakness_dialog"] = "Weakness...",
    ["ui.gm.vulnerability_dialog"] = "Vulnerability...",
    ["ui.gm.buff_dialog"] = "Empower...",
    ["ui.gm.cat_effects"] = "EFFECTS",
    ["ui.gm.cat_passives"] = "NPC PASSIVES",
    ["ui.gm.cat_utils"] = "UTILITIES",
    ["ui.gm.util_purge"] = "Purge (remove a buff)",
    ["ui.gm.util_dispel"] = "Dispel (remove a debuff)",
    ["ui.gm.util_clear_all"] = "Remove ALL effects",
    ["ui.gm.start_combat"] = "Start Combat",
    ["ui.gm.end_combat"] = "End Combat",

    -- ══════════════════════════════════════════════════════
    -- Critical wound and survival roll (UI/Dialogs_Wound.lua)
    -- ══════════════════════════════════════════════════════
    ["ui.wound.master_title"] = "Critical Wound",
    ["ui.wound.master_desc"] = "The player went down a second time and took a critical wound.\nGrant a survival roll or leave them wounded?",
    ["ui.wound.give_roll"] = "Grant a roll",
    ["ui.wound.leave_wounded"] = "Leave them wounded",
    ["ui.wound.left_wounded_log"] = "%s was left with a critical wound (the GM denied the survival roll).",
    ["ui.wound.setup_title"] = "Survival Roll",
    ["ui.wound.dc_label"] = "Threshold (DC):",
    ["ui.wound.hint"] = "On success the player survives but stays in a critical state. On failure the character dies.",
    ["ui.wound.send_roll"] = "Send the roll",
    ["ui.wound.player_label"] = "Player: %s",
    ["ui.wound.request_log"] = "The GM requires a survival roll from %s: %s against DC %s",
    ["ui.wound.player_hint"] = "Success — you survive, but stay in a critical state.\nFailure — your character dies.",
    ["ui.wound.roll_btn"] = "Roll the dice",
    ["ui.wound.player_desc"] = "The GM requires a %s check (your modifier: %s)\nagainst threshold DC %s",

    ["ui.settings.title"] = "DoF Settings",
    ["ui.settings.ui_scale"] = "Interface scale:",
    ["ui.settings.reset_100"] = "Reset (100%)",
    ["ui.help.title"] = "DoF — Command Reference",
    ["ui.help.header"] = "|cFFFFD700=== DoF (Dice of Fate) v%s ===|r",
    -- The help body is NOT passed through string.format: it contains "%t".
    ["ui.help.body"] = [[|cFF66CCFF— Main windows —|r
  |cFF00FF00/dof|r — main window
  |cFF00FF00/dof log|r — combat log
  |cFF00FF00/dof master|r — GM panel
  |cFF00FF00/dof settings|r — settings (UI scale)
  |cFF00FF00/dof stats|r — character info

|cFF66CCFF— Roles —|r
  |cFF00FF00/dofrole|r — choose a role
  |cFF00FF00/dofrole <player> tank|dd|healer|none|r — set one (GM)

|cFF66CCFF— Wounds —|r
  |cFF00FF00/dofwound <player>|r — add a wound (GM)
  |cFF00FF00/dofhealwound <player>|r — remove a wound (GM)

|cFF66CCFF— Player management (GM) —|r
  |cFF00FF00/dofsetlevel <player> <1-20>|r — set a player's level
  |cFF00FF00/dofsetrole <player>|r — set a player's role
  |cFF00FF00/dofresetstats <player>|r — reset a player's stats
  |cFF00FF00/dofgiveenergy <player>|r — give +1 energy
  |cFF00FF00/dofrestoreenergy <player>|r — restore full energy
  |cFF00FF00/dofmodifyplayerhp <player> ±number|r — change a player's HP
  |cFF00FF00/dofgiveshield <player> <number>|r — give a shield to a player
  |cFF00FF00/dofaddwound|r — add a wound (target)
  |cFF00FF00/dofremwound|r — remove a wound (target)

|cFF66CCFF— NPC management (GM) —|r
  |cFF00FF00/dofhp|r — show the target's HP
  |cFF00FF00/dofhp <number>|r — set the target's HP
  |cFF00FF00/dofsethp <number>|r — set the target's HP
  |cFF00FF00/dofdefense <fort> <refl> <will>|r — set NPC defenses
  |cFF00FF00/dofmodifynpchp ±number|r — change NPC HP
  |cFF00FF00/dofremovenpc|r — remove the target from the database
  |cFF00FF00/dofnpcattack <player|%t> <min-max> <threshold> <defense> [debuff] [value] [rounds]|r
     Example: /dofnpcattack %t 5-10 12 Fort stun 0 2
  |cFF00FF00/dofnpceffect <effect> [value] [rounds]|r — effect on an NPC
  |cFF00FF00/dofnpcstun [rounds]|r — stun an NPC
  |cFF00FF00/dofbuff <player|%t> <effect> [value] [rounds]|r — buff
  |cFF00FF00/dofdebuff <player|%t> <effect> [value] [rounds]|r — debuff
  |cFF00FF00/dofpurge|r — remove a buff from the target
  |cFF00FF00/dofdispel|r — remove a debuff from the target
  |cFF00FF00/dofcleareffects|r — remove all effects from the target
  |cFF00FF00/dofhplist|r — list NPCs
  |cFF00FF00/dofhpclear|r — clear the NPC database

|cFF66CCFF— Combat actions —|r
  |cFF00FF00/dofattack str|dex|int|r — attack
  |cFF00FF00/dofheal|r — heal (healer)
  |cFF00FF00/dofcheck str|dex|int|spi|r — stat check
  |cFF00FF00/dofshield|r — apply a shield (healer)
  |cFF00FF00/dofaoeattack str|dex|int|r — AoE attack
  |cFF00FF00/dofaoeheal|r — AoE healing
  |cFF00FF00/dofaoebuff <effect>|r — AoE buff

|cFF66CCFF— Turn-based combat (GM) —|r
  |cFF00FF00/dofcombat start [sec]|r — start combat
  |cFF00FF00/dofcombat end|r — end combat
  |cFF00FF00/dofcombat help|r — all combat commands

|cFF66CCFF— Other (GM) —|r
  |cFF00FF00/dofversion|r — check versions in the group

|cFF888888The DoF level (1-20) is separate from the in-game one — the GM grants it|r]],

    -- ══════════════════════════════════════════════════════
    -- Effect tooltips in the apply menu (UI/Dialogs.lua)
    -- ══════════════════════════════════════════════════════
    ["ui.effect.already_active"] = "The effect is already active on the target",
    ["ui.effect.active_suffix"] = " |cFF666666(active)|r",
    ["ui.effect.cd_suffix"] = " |cFF666666(CD: %d)|r",
    ["ui.effect.cooldown"] = "Cooldown: %d %s",
    ["ui.effect.dot_value"] = "%d damage/round, %d %s",
    ["ui.effect.hot_value"] = "+%d HP/round, %d %s",
    ["ui.effect.stat_damage"] = "damage",
    ["ui.effect.stat_mod_value"] = "%s%d to %s, %d %s",
    ["ui.effect.tooltip_desc"] = "%s\n%s\nCost: %d energy",

    -- ══════════════════════════════════════════════════════
    -- Ability bar: buttons (UI/ActionBar.lua)
    -- ══════════════════════════════════════════════════════
    ["ui.bar.title"] = "Ability Bar",
    ["ui.bar.attack"] = "Attack",
    ["ui.bar.heal"] = "Heal",
    ["ui.bar.restore_energy"] = "Restore Energy",
    ["ui.bar.support"] = "Support",
    ["ui.bar.wound"] = "Wound",
    ["ui.bar.purge"] = "Purge",
    ["ui.bar.effect"] = "Effect",
    ["ui.bar.special"] = "Special",
    ["ui.bar.tank"] = "Tank",
    ["ui.bar.redirect"] = "Redirect",
    ["ui.bar.taunt"] = "Taunt",
    ["ui.bar.taunt_aoe"] = "Mass Taunt",
    ["ui.bar.check"] = "Check",
    ["ui.bar.refresh"] = "Refresh",
    ["ui.bar.shield_tooltip"] = "Left-click: Shield on target (CD: 2 turns)\nRight-click: AoE shield (up to 4 targets, CD: 3 turns, 2 energy)\nAbsorbs all damage from one hit",
    ["ui.bar.effect_tooltip"] = "Apply an effect (DoT / debuff)\nOpens the selection menu",
    ["ui.bar.special_tooltip"] = "Special action\nSends a request to the GM for approval\nEnergy cost is set by the GM",
    ["ui.bar.skip_tooltip"] = "Skip the turn (+1 energy)",
    ["ui.bar.refresh_tooltip"] = "Request NPC data from the GM\n\nIf an NPC shows \"No data\" or lost its template,\nclick to request a resync.\n\nIf an NPC without data is selected — a targeted request.\nOtherwise — a full resync of all NPCs.\n\nCD: 5 seconds",
    ["ui.bar.position_reset"] = "Action bar position reset",
    ["ui.bar.enabled"] = "Action bar enabled",
    ["ui.bar.disabled"] = "Action bar disabled",
    -- Two separate messages rather than "Action bar " + a word: neither Russian
    -- case agreement nor English word order survives the concatenation.
    ["ui.bar.locked"] = "Action bar locked",
    ["ui.bar.unlocked"] = "Action bar unlocked",

    -- ══════════════════════════════════════════════════════
    -- Ability bar: tooltips (UI/ActionBar.lua)
    -- ══════════════════════════════════════════════════════
    ["ui.tip.attack_roll"] = "d20 roll + %s against the NPC's %s",
    ["ui.tip.your_roll"] = "Your roll: d20 + %s",
    ["ui.tip.attack_hint"] = "Left-click - attack | Right-click - stat",
    ["ui.tip.restore_energy_title"] = "Restore Energy",
    ["ui.tip.restore_energy_desc"] = "Gives 1 energy to an ally",
    ["ui.tip.cost_1_energy"] = "Cost: 1 energy",
    ["ui.tip.not_on_self"] = "Cannot be used on yourself",
    ["ui.tip.restore_hint"] = "Left-click - give | Right-click - choose",
    ["ui.tip.heal_roll"] = "d20 roll + Spirit",
    ["ui.tip.heal_hint"] = "Left-click - heal | Right-click - choose",
    ["ui.tip.support_of"] = "Support: %s",
    ["ui.tip.wound_desc"] = "Removes 1 wound from an ally",
    ["ui.tip.roll_spirit_16"] = "d20 roll + Spirit, threshold: 16",
    ["ui.tip.dispel_desc"] = "Removes a debuff from an ally",
    ["ui.tip.roll_spirit_14"] = "d20 roll + Spirit, threshold: 14",
    ["ui.tip.purge_desc"] = "Removes a buff from an NPC",
    ["ui.tip.support_hint"] = "Left-click - use | Right-click - choose",
    ["ui.tip.aoe_heal_title"] = "AoE: Healing",
    ["ui.tip.aoe_heal_desc"] = "Heals 2-4 allies",
    ["ui.tip.aoe_heal_roll"] = "d20 roll + Spirit, 20 = crit",
    ["ui.tip.aoe_damage_desc"] = "Damage to 2-4 targets",
    ["ui.tip.aoe_auto_hit"] = "Auto-hit, 20 = crit",
    ["ui.tip.aoe_hint"] = "Left-click - AoE | Right-click - stat",
    ["ui.tip.check_roll"] = "d20 roll + %s",
    ["ui.tip.no_turn_cost"] = "Does not use the turn",
    ["ui.tip.tank_of"] = "Tank: %s",
    ["ui.tip.taunt_desc"] = "The NPC must attack the tank (2 rnd)",
    ["ui.tip.taunt_cost"] = "1 energy | CD: 2 turns",
    ["ui.tip.taunt_aoe_desc"] = "Taunts several NPCs (2 rnd)",
    ["ui.tip.taunt_aoe_cost"] = "2 energy | CD: 3 turns",
    ["ui.tip.redirect_desc"] = "The next hit on an ally goes to the tank",
    ["ui.tip.redirect_cost"] = "Free | CD: 2 turns",
    ["ui.tip.tank_hint"] = "Left-click - use | Right-click - choose",
    ["ui.tip.empower_choose"] = "Empower (choose a stat)",
    ["ui.tip.fortify_choose"] = "Fortify (choose a stat)",
    ["ui.tip.empower_fortify"] = "Empower / Fortify",
    ["ui.tip.aoe_buff_hint"] = "Right-click - AoE buff",
    ["ui.tip.buff_choose"] = "Choose a buff",
    ["ui.tip.energy_required"] = "Energy required: %s",

    -- ══════════════════════════════════════════════════════
    -- Stat checks (UI/Dialogs.lua)
    -- ══════════════════════════════════════════════════════
    ["ui.check.of"] = "Check: %s",
    ["ui.check.strength"] = "Physical power, melee, heavy lifting.",
    ["ui.check.dexterity"] = "Agility, speed, dodging, marksmanship.",
    ["ui.check.intelligence"] = "Intellect, magic, knowledge, logic.",
    ["ui.check.spirit"] = "Willpower, charisma, healing.",
    ["ui.check.fortitude"] = "Resistance to poison, disease, physical effects.",
    ["ui.check.reflex"] = "Dodging traps and AoE attacks.",
    ["ui.check.will"] = "Resistance to mental attacks and fear.",

    -- ══════════════════════════════════════════════════════
    -- Effect tooltips (UI/Effects.lua)
    -- ══════════════════════════════════════════════════════
    ["ui.effect.heals"] = "Heals",
    ["ui.effect.per_round"] = "%s: %s per round",
    ["ui.effect.modifier"] = "Modifier: %s",
    ["ui.effect.caster_one"] = "Applied by: %s",
    ["ui.effect.caster_many"] = "Applied by: %s",
    -- %s — the plural form of "round", picked by DoF.Locale:Plural
    ["ui.effect.remaining"] = "Remaining: %d %s",

    -- Plural forms of "round" — shared across interface tooltips
    ["ui.rounds_one"] = "round",
    ["ui.rounds_few"] = "rounds",
    ["ui.rounds_many"] = "rounds",

    -- ══════════════════════════════════════════════════════
    -- Combat log (UI/CombatLog.lua)
    -- ══════════════════════════════════════════════════════
    ["ui.combatlog.title_battle"] = "Combat Log",
    ["ui.combatlog.title_master"] = "GM Log",
    ["ui.combatlog.tab_battle"] = "Combat",
    ["ui.combatlog.tab_master"] = "GM",
    ["ui.combatlog.clear"] = "Clear",
    ["ui.combatlog.result_marker"] = "Result:",
    ["ui.combatlog.empty"] = "|cFF666666Log is empty|r",

    -- ══════════════════════════════════════════════════════
    -- Main window (UI/MainFrame.lua)
    -- ══════════════════════════════════════════════════════
    ["ui.role.choose_title"] = "Choose a Role",
    ["ui.role.choose_hint"] = "Click to choose a role",
    ["ui.role.select"] = "Choose a role",
    ["ui.role.of"] = "Role: %s",
    ["ui.level.of"] = "Level: %s",
    ["ui.level.current_mark"] = "|cFF888888(current)|r",
    ["ui.level.tooltip_title"] = "Level %s",
    ["ui.level.tooltip_desc"] = "Stat points: %s\nBase health: %s\nEnergy: %s",
    ["ui.role.reset"] = "Reset",
    ["ui.role.reset_title"] = "Reset role",
    ["ui.role.reset_desc"] = "Removes the player's role",

    -- ══════════════════════════════════════════════════════
    -- Character sidebar (UI/CharacterSidebar.lua)
    -- ══════════════════════════════════════════════════════
    ["ui.sidebar.health_energy"] = "Health/Energy",
    ["ui.sidebar.stats"] = "Stats",
    ["ui.sidebar.damage_healing"] = "Damage/Healing",
    ["ui.sidebar.distribute"] = "Distribute",
    ["ui.sidebar.gm_menu"] = "GM Menu",
    ["ui.sidebar.gm_menu_hint"] = "Open the combat control panel",
    -- %s — the plural form of "point", picked by DoF.Locale:Plural
    ["ui.sidebar.level"] = "Level %d",
    ["ui.sidebar.level_points"] = "Level %d | %d %s",
    ["ui.sidebar.points_one"] = "point",
    ["ui.sidebar.points_few"] = "points",
    ["ui.sidebar.points_many"] = "points",
    ["ui.sidebar.max_level"] = "MAX LEVEL (%d)",
    ["ui.sidebar.points_badge"] = "+ %d %s",

    -- ══════════════════════════════════════════════════════
    -- Turn queue (UI/TurnQueue.lua)
    -- ══════════════════════════════════════════════════════
    ["ui.queue.turn_progress"] = "Turn %d of %d",
    ["ui.queue.acted_progress"] = "%d/%d acted",
    ["ui.queue.add_player"] = "|cFF66FF66+Player|r",
    ["ui.queue.extra_turn_short"] = "Extra",
    ["ui.queue.level_short"] = "Lv.%s",
    ["ui.queue.skip_turn"] = "Skip turn",
    ["ui.queue.remove_from_combat"] = "Remove from combat",
    ["ui.queue.rounds_left"] = "Rounds left: %s",
    ["ui.queue.value"] = "Value: %s",

    -- ══════════════════════════════════════════════════════
    -- Minimap button (UI/MinimapButton.lua)
    -- ══════════════════════════════════════════════════════
    ["ui.minimap.settings"] = "DoF: Settings",
    ["ui.minimap.tooltip_left"] = "Left-click - open the DoF panel",
    ["ui.minimap.tooltip_shift_left"] = "Shift+Left-click - GM panel",
    ["ui.minimap.tooltip_right"] = "Right-click - settings menu",
    ["ui.minimap.you_are_gm"] = "You are the GM",
    ["ui.minimap.gm_is"] = "GM: %s",
    ["ui.minimap.action_bar"] = "Action Bar",
    ["ui.minimap.player_frame"] = "Player Frame",
    ["ui.minimap.target_frame"] = "Target Frame (NPC)",
    ["ui.minimap.lock_frames"] = "Lock frames",
    ["ui.minimap.unlock_frames"] = "Unlock frames",
    ["ui.minimap.close"] = "Close",
    ["ui.opt.lang_header"] = "|cFFFFD700Language|r",
    ["ui.opt.lang_label"] = "Addon language",
    ["ui.opt.lang_desc"] = "Language of the interface and combat messages. Defaults to the game client's language.\nThe change applies after a UI reload.",
    ["ui.opt.lang_reload_confirm"] = "Addon language changed to \"%s\".\nReload the interface to apply it?",
    ["ui.opt.lang_reload_now"] = "Reload",
    ["ui.opt.lang_reload_later"] = "Later",
    ["ui.sidebar.lang_tooltip"] = "Addon language: %s",
    ["ui.sidebar.lang_hint"] = "Left-click — switch",
})
