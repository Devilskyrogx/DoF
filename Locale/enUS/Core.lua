-- DoF/Locale/enUS/Core.lua
-- Common strings: addon name, character stats, service labels.
--
-- Stat names live here rather than in UI: they surface in the interface,
-- in combat messages, and in the NPC library alike.

local ADDON_NAME, DoF = ...

DoF.Locale:Register("enUS", {
    ["locale.name"] = "English",

    -- ══════════════════════════════════════════════════════
    -- STATS (UI/MainFrame.lua, STAT_CONFIG)
    -- ══════════════════════════════════════════════════════
    ["stats.strength.label"] = "Strength",
    ["stats.strength.desc"] = "Offensive, opposed by Fortitude. Raw might, the ability to crush a defense by sheer force. Warriors, paladins, melee fighters. Outside combat — physical dominance: breaking a door, shifting a boulder, impressing by scale.",

    ["stats.dexterity.label"] = "Dexterity",
    ["stats.dexterity.desc"] = "Offensive, opposed by Reflex. Speed, precision, an eye for the gap. Archers, rogues, duelists. Outside combat — reaction, coordination, slipping by unnoticed.",

    ["stats.intelligence.label"] = "Intelligence",
    ["stats.intelligence.desc"] = "Offensive, opposed by Will. The mind turned into a weapon: spells, mental pressure, tactics. Mages, warlocks. Outside combat — erudition, cunning, winning an argument.",

    ["stats.spirit.label"] = "Spirit",
    ["stats.spirit.desc"] = "The healer's stat, never opposed. A bond with faith, light and life. Determines healing power. Outside combat — spiritual authority, persuasion, closeness to a deity.",

    ["stats.fortitude.label"] = "Fortitude",
    ["stats.fortitude.desc"] = "Defensive, opposed by Strength. The ability to take a hit and stay standing. A sturdy body, endurance. Outside combat — health, tolerance of pain, poison and cold.",

    ["stats.reflex.label"] = "Reflex",
    ["stats.reflex.desc"] = "Defensive, opposed by Dexterity. Muscle memory, a nose for danger. Dodging, parrying, stepping aside before the blow lands. Outside combat — vigilance, sensing an ambush.",

    ["stats.will.label"] = "Will",
    ["stats.will.desc"] = "Defensive, opposed by Intelligence. A fortress of the mind, a shield of thought. Resistance to magic, illusion and fear. Outside combat — resolve, standing firm against manipulation and pressure.",

    -- ══════════════════════════════════════════════════════
    -- ROLES (Core/Config.lua)
    -- ══════════════════════════════════════════════════════
    ["roles.tank.name"] = "Tank",
    ["roles.tank.desc"] = "High survivability. HP = Base + Fortitude/2. Below-average damage and healing. A streak of 2 successful defenses grants +1 to that defense stat (up to +3). A failure clears the buff for the failed stat. A streak of 2 consecutive successful attacks on one target shreds the enemy's defense by 2 (down to -6). Redirects an ally's damage (once every 2 turns). Taunt (1 energy, once every 2 turns). AoE taunt (2 energy, once every 3 turns).",
    ["roles.dd.name"] = "Fighter",
    ["roles.dd.desc"] = "Increased damage in combat. Below-average healing. 15% chance to counterattack on a successful defense. Defense crit: +3 counterattack damage.",
    ["roles.healer.name"] = "Healer",
    ["roles.healer.desc"] = "Enhanced healing, wound removal. Below-average damage. Shield (absorbs 1 hit, CD 2 turns). AoE shield (up to 4 targets, 2 energy, CD 3 turns).",

    -- Action type names (Core/Config.lua, ActionTypeNames)
    ["core.action.simple_roll"] = "Simple roll",
    ["core.action.buff"] = "Buff",
    ["core.action.aoe_buff"] = "AoE Buff",
    ["core.action.attack"] = "Attack",
    ["core.action.aoe_attack"] = "AoE Attack",
    ["core.action.wound_removal"] = "Wound removal",
    ["core.action.dispel"] = "Dispel",
    ["core.action.purge"] = "Purge",

    -- ══════════════════════════════════════════════════════
    -- SHARED CHECKS (Core/Utils.lua)
    -- The prefix is an action name, so it is passed as its own %s.
    -- ══════════════════════════════════════════════════════
    ["core.util.not_your_turn_action"] = "%s: it is not your turn!",
    ["core.util.not_enough_energy_detail"] = "%sNot enough energy! (need %s, have %s)",
    ["core.util.select_player_prefixed"] = "%sSelect a player!",
    ["core.util.ui_scale_set"] = "UI scale set: %s",
    ["core.util.ui_scale_reset"] = "UI scale reset to automatic",

    -- ══════════════════════════════════════════════════════
    -- NPC DATABASE (Data/Units.lua)
    -- ══════════════════════════════════════════════════════
    ["core.units.removed_log"] = "Removed NPC '%s'",
    ["core.units.cleared_log"] = "Cleared the entire NPC database",
    ["core.units.cleared"] = "NPC database cleared",
    ["core.units.clear_confirm"] = "Delete ALL NPC data?",
    ["core.units.dead"] = "|cFFFF0000Dead|r",
    ["core.units.stat_line"] = " |cFF888888[Frt:%s Rfl:%s Wil:%s]|r",
    ["core.units.list_empty"] = "The list is empty",
    ["core.units.import_removed"] = "Import: removed NPC '%s' — it was absent from the received dump",

    -- ══════════════════════════════════════════════════════
    -- SLASH ALIASES (Core/Aliases.lua)
    -- ══════════════════════════════════════════════════════
    ["core.alias.removed"] = "Removed: %s",
    ["core.alias.queue_with_leader"] = "With a queue leader",
    ["core.alias.extra_turn_cancelled"] = "Extra turn cancelled.",
    ["core.alias.passive_removed"] = "Passive removed: %s from %s",
    ["core.alias.buff_removed"] = "Buff removed: %s from %s",
    ["core.alias.debuff_removed"] = "Debuff removed: %s from %s",
    ["core.alias.all_effects_removed"] = "All effects removed from %s",

    -- ══════════════════════════════════════════════════════
    -- STATS AND STATE (Data/Stats.lua)
    -- ══════════════════════════════════════════════════════
    ["core.stats.points_gained"] = "+%d stat %s!",
    ["core.stats.hp_gained"] = "+%s maximum health!",
    ["core.stats.energy_gained"] = "+%s maximum energy!",
    ["core.stats.level_up"] = "═══ LEVEL %s! ═══",
    -- Neutral wording on purpose: the GM can lower a level, not only raise it.
    ["core.stats.level_reached_log"] = "%s is now level %s",
    ["core.stats.level_down"] = "═══ Level lowered to %s ═══",
    ["core.stats.points_trimmed"] = "Stat points removed: %s — the new level gives fewer of them.",
    ["core.stats.role_set"] = "Role: %s",
    ["core.stats.role_reset"] = "Role reset",
    ["core.stats.already_critical"] = "You are already in a critical state! The GM decides your fate.",
    ["core.stats.critical_wound"] = "CRITICAL WOUND! You are unconscious. The GM decides your fate.",
    -- %% — escaped percent: the string goes through string.format
    ["core.stats.wound_received"] = "Wound received! Penalty: %s to all stats. HP restored to %s%%",
    ["core.stats.no_wounds"] = "No wounds to remove",
    ["core.stats.critical_wound_healed"] = "Critical wound removed! A normal wound remains (penalty %s).",
    ["core.stats.wound_healed"] = "Wound healed!",
    ["core.stats.all_wounds_healed"] = "All wounds healed!",
    ["core.stats.shield_absorbed"] = "The shield absorbed all damage (%s)!",
    ["core.stats.shield_broken"] = "The shield broke!",
    ["core.stats.distributed"] = "Stats distributed!",
    ["core.stats.hp_max"] = "Health is at maximum!",
    ["core.stats.hp_min"] = "Health is at minimum!",
    ["core.stats.hp_line"] = "Health: %s",
    ["core.stats.value_change"] = "%s/%s (%s%s)",
    ["core.stats.hp_change_log"] = "%s changed health: %d → %d (%+d)",
    ["core.stats.reset"] = "Stats reset",
    ["core.stats.full_reset"] = "Character fully reset",
    ["core.stats.energy_gained_amount"] = "+%s energy (%s/%s)",
    ["core.stats.energy_restored"] = "Energy restored: %s/%s",
    ["core.stats.energy_max"] = "Energy is at maximum!",
    ["core.stats.energy_min"] = "Energy is at minimum!",
    ["core.stats.energy_line"] = "Energy: %s",

    -- Character sheet (/dof stats)
    ["core.stats.sheet_header"] = "|cFFFFD700=== DoF Character ===|r",
    ["core.stats.sheet_level"] = "Level: |cFFFFD700%s/%s|r",
    ["core.stats.sheet_role"] = "Role: |cFF%s%s|r",
    ["core.stats.sheet_critical"] = "|cFFFF0000CRITICAL WOUND|r (unconscious, the GM decides your fate)",
    ["core.stats.sheet_wound"] = "Wound: |cFFFF6666penalty %s to all stats|r",
    ["core.stats.sheet_shield"] = "Shield: |cFF66CCFF%s|r",
    ["core.stats.sheet_energy"] = "Energy: %s/%s",
    ["core.stats.sheet_points"] = "Points: |cFFFFD700%s/%s|r",
    ["core.stats.sheet_next_point"] = "Next point at level: |cFF66CCFF%s|r",

    -- ══════════════════════════════════════════════════════
    -- LOADING AND MAINTENANCE (Core/Init.lua)
    -- ══════════════════════════════════════════════════════
    ["core.init.pruned_npcs"] = "|cFFAAAAAA[DoF]|r Stale NPCs pruned from the database: %s",
    ["core.init.prefix_failed"] = "|cFFFF3333[DoF]|r ERROR: could not register the prefix '%s'. Synchronization will not work. Try /reload, or disable some other addons.",
    ["core.init.loaded"] = "v%s loaded! /dof for help",
    ["core.init.stale_data_confirm"] = "NPC data from a previous session was found (%s entries).\nClear the NPC data?",
    ["core.init.clear"] = "Clear",
    ["core.init.keep"] = "Keep",
    ["core.init.stale_data_cleared"] = "NPC data from the previous session was cleared",
    ["core.init.data_sent"] = "Data sent",
    ["core.init.request_sent"] = "Request sent",
    ["core.init.frames_reset"] = "Unit Frame positions reset",
    ["core.init.system_messages"] = "System messages: %s",
    ["core.init.on"] = "ON",
    ["core.init.off"] = "OFF",
    ["core.init.version_request_sent"] = "Version request sent...",
    ["core.init.versions_header"] = "|cFFFFD700[DoF]|r |cFF66CCFF=== Addon versions ===|r",
    ["core.init.no_response"] = "|cFF888888  No response (addon missing?): %s|r",

    -- About window
    ["core.init.about_version"] = "Version: %s",
    ["core.init.about_author"] = "Developer: %s",
    ["core.init.about_tagline"] = "A turn-based combat system for RP",

    -- /dofxplevel output
    ["core.init.level_header"] = "|cFFFFD700=== DoF Level ===|r",
    ["core.init.level_line"] = "Level: |cFFFFD700%s/%s|r",
    ["core.init.points_line"] = "Points: |cFFFFD700%s/%s|r",
    ["core.init.base_hp_line"] = "Base HP: |cFF66FF66%s|r",
    ["core.init.max_energy_line"] = "Max energy: |cFF66CCFF%s|r",

    -- /dofframes and /dofbar help
    ["core.init.help_frames"] = "  |cFF00FF00/dofframes|r — show/hide the player frame\n  |cFF00FF00/dofframes player|r — show/hide the player frame\n  |cFF00FF00/dofframes target|r — show/hide the target frame\n  |cFF00FF00/dofframes reset|r — reset positions\n  |cFF00FF00/dofframes lock|r — lock movement",
    ["core.init.help_bar"] = "  |cFF00FF00/dofbar|r — show/hide the bar\n  |cFF00FF00/dofbar lock|r — lock movement\n  |cFF00FF00/dofbar reset|r — reset the position",
    ["core.init.help_combat"] = "|cFFFFD700=== Turn-based combat ===|r\n  |cFF00FF00/dofcombat start [sec]|r — start combat (default timer 60s)\n  |cFF00FF00/dofcombat end|r — end combat\n  |cFF00FF00/dofcombat skip|r — skip the turn\n  |cFF00FF00/dofcombat npc|r — NPC phase (GM)\n  |cFF00FF00/dofcombat players|r — player phase (GM)\n  |cFF00FF00/dofcombat add <name>|r — add to combat (GM)\n  |cFF00FF00/dofcombat remove <name>|r — remove from combat (GM)\n  |cFF00FF00/dofcombat free <name>|r — extra turn (GM)\n  |cFF00FF00/dofcombat queue|r — queue window",

    -- ══════════════════════════════════════════════════════
    -- SLASH COMMAND USAGE HINTS
    -- The "Usage: ..." lines describe command syntax — command and parameter
    -- names stay as they are, only the surrounding words are translated.
    -- ══════════════════════════════════════════════════════
    ["core.usage.role"] = "Usage: /dofrole <player> tank|dd|healer|none",
    ["core.usage.roles_list"] = "Roles: tank, dd, healer, none",
    ["core.usage.wound"] = "Select a player or give a name: /dofwound <player>",
    ["core.usage.healwound"] = "Select a player or give a name: /dofhealwound <player>",
    ["core.usage.setrole"] = "Select a player or give a name: /dofsetrole <player>",
    ["core.usage.resetstats"] = "Select a player or give a name: /dofresetstats <player>",
    ["core.usage.setlevel"] = "Select a player or give a name: /dofsetlevel <player> <level 1-20>",
    ["core.usage.giveenergy"] = "Select a player or give a name: /dofgiveenergy <player>",
    ["core.usage.restoreenergy"] = "Select a player or give a name: /dofrestoreenergy <player>",
    ["core.usage.aoebuff"] = "Usage: /dofaoebuff <effect_id>",
    ["core.usage.aoebuff_example"] = "Example: /dofaoebuff empower_strength",
    ["core.usage.hp"] = "Usage: /dofhp [current/max]",
    ["core.usage.attack"] = "Usage: /dofattack str|dex|int",
    ["core.usage.check"] = "Usage: /dofcheck str|dex|int|spi",
    ["core.usage.aoeattack"] = "Usage: /dofaoeattack str|dex|int",
    ["core.usage.combat_add"] = "Usage: /dofcombat add <name>",
    ["core.usage.combat_remove"] = "Usage: /dofcombat remove <name>",
    ["core.usage.combat_free"] = "Usage: /dofcombat free <name>",
    ["core.usage.sethp"] = "Usage: /dofsethp <number>",
    ["core.usage.defense"] = "Usage: /dofdefense <fort> <refl> <will>",
    ["core.usage.modifynpchp"] = "Usage: /dofmodifynpchp +number or -number",
    ["core.usage.npcattack"] = "Usage: /dofnpcattack <player|%%t> <damage|min-max> <threshold> <defense> [debuff] [value] [rounds]",
    ["core.usage.npcattack_example"] = "Example: /dofnpcattack %%t 5-10 12 Fort",
    ["core.usage.npcattack_debuff"] = "With a debuff: /dofnpcattack %%t 5-10 12 Fort stun 0 2",
    ["core.usage.npcattack_defense"] = "Defense: Fort(F), Ref(R), Will(W), Hybrid(H)",
    ["core.usage.modifyplayerhp"] = "Usage: /dofmodifyplayerhp <player|%%t> +number or -number",
    ["core.usage.giveshield"] = "Usage: /dofgiveshield <player>",
    ["core.usage.buff"] = "Usage: /dofbuff <player|%%t> <effect> [value] [rounds]",
    ["core.usage.buff_effects"] = "Effects: empower, fortify_fortitude, fortify_reflex, fortify_will, regeneration, blessing",
    ["core.usage.debuff"] = "Usage: /dofdebuff <player|%%t> <effect> [value] [rounds]",
    ["core.usage.debuff_effects"] = "Effects: stun, weakness_damage, weakness_healing, vulnerability_fortitude, vulnerability_reflex, vulnerability_will, dot_master",
    ["core.usage.npceffect"] = "Usage: /dofnpceffect <effect> [value] [rounds]",
    ["core.usage.npceffect_effects"] = "Effects: stun, weakness_fortitude, weakness_reflex, weakness_will, bleeding",

    -- ══════════════════════════════════════════════════════
    -- GM COMMAND RESULTS (Core/Init.lua)
    -- ══════════════════════════════════════════════════════
    ["core.cmd.npc_line"] = "%s: HP %s/%s [Frt:%s Rfl:%s Wil:%s]",
    ["core.cmd.npc_no_hp"] = "%s: HP is not set",
    ["core.cmd.npc_data_removed"] = "Data for %s was removed",
    ["core.cmd.defense_set"] = "%s: Frt=%s, Rfl=%s, Will=%s",
    ["core.cmd.buff_applied"] = "Buff |cFF00FF00%s|r applied to |cFFFFFFFF%s|r",
    ["core.cmd.debuff_applied"] = "Debuff |cFFFF6666%s|r applied to |cFFFFFFFF%s|r",
    ["core.cmd.effect_applied"] = "Effect |cFFFFD700%s|r applied to |cFFFF6666%s|r",
    ["core.cmd.master_applies_log"] = "The GM applies %s to %s (%s, %s rnd)",
    ["core.cmd.npc_stunned"] = "|cFFFF6666%s|r is stunned for |cFFFFD700%s|r rnd.",
    ["core.cmd.npc_stunned_log"] = "The GM stuns %s for %s rnd.",
    ["locale.short"] = "EN",
})
